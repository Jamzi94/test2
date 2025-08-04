#!/bin/bash
# ==============================================================================
#      JAMZI AI STACK - MODULE ENVIRONNEMENT
# ==============================================================================
# Fonctions de vérification et préparation de l'environnement

# --- DÉTECTION ENVIRONNEMENT TERMINAL ---
detect_terminal_capabilities() {
    # Détection de l'environnement terminal
    local terminal_type=""
    
    # Forcer la désactivation des couleurs pour Git Bash/MSYS même si WT_SESSION est défini
    if [[ "$OSTYPE" == "msys" || -n "${MSYSCON:-}" || "${MSYSTEM:-}" == "MINGW"* ]]; then
        terminal_type="Git Bash/MSYS2"
        TERMINAL_SUPPORTS_ANSI=false
        echo "⚠️ Terminal Git Bash détecté - support couleurs désactivé"
        echo "ℹ️ Recommandation: Utilisez Windows Terminal pour un meilleur affichage"
    elif [[ -n "${WT_SESSION:-}" ]]; then
        terminal_type="Windows Terminal"
        TERMINAL_SUPPORTS_ANSI=true
    elif [[ -n "${WSLENV:-}" ]]; then
        terminal_type="WSL"
        TERMINAL_SUPPORTS_ANSI=true
    elif [[ "${TERM:-}" == *"256color"* ]]; then
        terminal_type="256 Color Terminal"
        TERMINAL_SUPPORTS_ANSI=true
    elif [[ "${TERM:-}" == "xterm-color" || "${TERM:-}" == "screen" ]]; then
        terminal_type="Color Terminal"
        TERMINAL_SUPPORTS_ANSI=true
    else
        terminal_type="Terminal Basique"
        TERMINAL_SUPPORTS_ANSI=false
    fi
    
    export TERMINAL_SUPPORTS_ANSI
    
    # Adaptation des couleurs si nécessaire
    if [[ "$TERMINAL_SUPPORTS_ANSI" == "false" ]]; then
        # Désactiver les couleurs complexes pour Git Bash
        export C_RESET="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_CYAN="" C_WHITE="" C_BOLD="" C_DIM=""
    fi
}

# --- VÉRIFICATION ENVIRONNEMENT ---
check_environment() {
    detect_terminal_capabilities
    source "$BASE_DIR/detect_gpu.sh"
    detect_gpu_info
    log_header "PHASE 1 : VÉRIFICATION DE L'ENVIRONNEMENT"
    
    if [ ! -f "$BASE_DIR/.env" ]; then 
        log_error "'.env' introuvable dans $BASE_DIR."
    fi
    
    log_ok "Fichiers de configuration chargés."

    # Vérifie la présence des commandes critiques (docker, git)
    for cmd in docker git; do
      if ! command -v $cmd &>/dev/null; then 
          log_error "Commande requise '$cmd' introuvable. Veuillez l'installer manuellement."
      fi
    done
    
    # Vérifier et installer aria2c si manquant
    if ! command -v aria2c &>/dev/null; then
        log_warn "aria2c manquant. Installation automatique..."
        install_aria2c
    fi
    
    log_ok "Dépendances logicielles (docker, git, aria2c) présentes."
    
    # Affichage des informations GPU si détectées
    if [[ -n "${DETECTED_GPU_NAME:-}" && -n "${DETECTED_VRAM_GB:-}" ]]; then
        log INFO "ENVIRONMENT" "🎯 GPU Détecté: ${DETECTED_GPU_NAME} (${DETECTED_VRAM_GB}GB VRAM)"
    else
        log WARN "ENVIRONMENT" "⚠️  GPU: Non détecté ou mode CPU"
    fi
}

# --- VÉRIFICATION DISTRIBUTION DOCKER DESKTOP WSL ---
ensure_docker_desktop_distro(){
  log_header "VÉRIFICATION DE LA DISTRIBUTION docker-desktop (WSL)"
  if wsl.exe -l -v 2>/dev/null | grep -q "docker-desktop"; then
    log_ok "Distribution 'docker-desktop' déjà présente."
    return 0
  fi
  log_warn "Distribution 'docker-desktop' absente ou corrompue."
  local default_path
  default_path="$(cmd.exe /c "echo %LOCALAPPDATA%" | tr -d '\r')\\Docker\\wsl\\main"
  log INFO "WSL" "Chemin proposé : $default_path"
  read -p "  Chemin d'import (Entrée = défaut) : " docker_path
  [[ -z "$docker_path" ]] && docker_path="$default_path"
  powershell.exe -NoLogo -Command "if (-not (Test-Path -Path \"${docker_path//\\/\\\\}\")) { New-Item -ItemType Directory -Force -Path \"${docker_path//\\/\\\\}\" | Out-Null }"
  local tarball="C:\\Program Files\\Docker\\Docker\\resources\\wsl\\wsl-bootstrap.tar"
  log INFO "WSL" "Import de docker-desktop…"
  if ! wsl.exe --import docker-desktop "$docker_path" "$tarball" --version 2; then
    log_error "Échec de l'import docker-desktop. Vérifiez le chemin."
  fi
  log_ok "Distribution 'docker-desktop' importée avec succès."
}

# --- VÉRIFICATION DOCKER ---
check_docker_status() {
    log_header "PHASE 2 : VÉRIFICATION DE DOCKER"
    
    if ! docker info &>/dev/null; then
        log_warn "Docker Engine non démarré. Tentative de démarrage..."
        ensure_docker_desktop_distro
        sleep 5
        if ! docker info &>/dev/null; then
            log_error "Impossible de démarrer Docker. Redémarrez Docker Desktop manuellement."
        fi
    fi
    
    log_ok "Docker Engine opérationnel."
    
    # Vérification de la prise en charge GPU si disponible
    if command -v nvidia-smi >/dev/null 2>&1; then
        # Vérifier si Docker a le runtime NVIDIA disponible
        if docker info | grep -q "nvidia" 2>/dev/null; then
            log_ok "Support GPU Docker fonctionnel (runtime NVIDIA détecté)."
        else
            log_warn "Runtime NVIDIA Docker non configuré - Mode CPU uniquement."
        fi
    fi
}

# --- GESTION WSL/VHDX AVANCÉE ---

# Analyse de l'utilisation WSL et VHDX
analyze_wsl_usage() {
    log_info "WSL" "Analyse de l'utilisation WSL et VHDX"
    
    # Lister toutes les distributions WSL
    local wsl_distros
    wsl_distros=$(wsl.exe -l -v 2>/dev/null) || {
        log_error "WSL" "Impossible d'analyser les distributions WSL"
        return 1
    }
    
    log INFO "WSL" "📊 ANALYSE WSL & VHDX"
    log INFO "WSL" "────────────────────────────────────────"
    
    # Parser et analyser chaque distribution
    local total_distros=0
    local running_distros=0
    local docker_distros=0
    local stopped_distros=0
    
    while IFS= read -r line; do
        if [[ "$line" =~ [[:space:]]*([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([0-9]+) ]]; then
            local name="${BASH_REMATCH[1]}"
            local state="${BASH_REMATCH[2]}"
            local version="${BASH_REMATCH[3]}"
            
            # Nettoyer le nom (enlever l'astérisque par défaut)
            name=${name#\*}
            name=${name// /}
            
            if [[ -n "$name" && "$name" != "NAME" ]]; then
                ((total_distros++))
                
                # Catégoriser par état
                case "$state" in
                    "Running") ((running_distros++)) ;;
                    "Stopped") ((stopped_distros++)) ;;
                esac
                
                # Catégoriser par type
                if [[ "$name" =~ docker ]]; then
                    ((docker_distros++))
                fi
                
                # Afficher les informations de la distribution
                local state_icon="❓"
                local state_color="$C_DIM"
                case "$state" in
                    "Running") state_icon="🟢"; state_color="$C_GREEN" ;;
                    "Stopped") state_icon="🔴"; state_color="$C_RED" ;;
                esac
                
                log INFO "WSL" "${state_icon} ${name} (${state}, v$version)"
                
                # Essayer de déterminer la taille VHDX si possible
                if command -v powershell.exe >/dev/null 2>&1; then
                    local vhdx_info=$(powershell.exe -Command "
                        try {
                            \$localAppData = [Environment]::GetFolderPath('LocalApplicationData')
                            \$wslPath = Join-Path \$localAppData 'Packages\\MicrosoftCorporationII.WindowsSubsystemForLinux_*\\LocalState\\ext4.vhdx'
                            \$dockerPath = Join-Path \$localAppData 'Docker\\wsl\\data\\ext4.vhdx'
                            \$customPath = 'C:\\wsl\\$name\\ext4.vhdx'
                            
                            \$paths = @(\$wslPath, \$dockerPath, \$customPath)
                            foreach (\$path in \$paths) {
                                if (Test-Path \$path) {
                                    \$size = (Get-Item \$path).Length
                                    \$sizeMB = [math]::Round(\$size / 1MB, 1)
                                    Write-Output \"\$sizeMB MB\"
                                    break
                                }
                            }
                        } catch { Write-Output 'N/A' }
                    " 2>/dev/null | tr -d '\r' | head -1)
                    
                    if [[ -n "$vhdx_info" && "$vhdx_info" != "N/A" ]]; then
                        log INFO "WSL" "VHDX: ~${vhdx_info}"
                    fi
                fi
            fi
        fi
    done <<< "$wsl_distros"
    
    log INFO "WSL" "────────────────────────────────────────"
    log INFO "WSL" "Total: $total_distros distributions"
    log INFO "WSL" "En cours: $running_distros | Arrêtées: $stopped_distros"
    log INFO "WSL" "Docker: $docker_distros distributions"
    
    # Stocker les résultats pour utilisation ultérieure
    export WSL_ANALYSIS_TOTAL_DISTROS=$total_distros
    export WSL_ANALYSIS_RUNNING_DISTROS=$running_distros
    export WSL_ANALYSIS_STOPPED_DISTROS=$stopped_distros
    export WSL_ANALYSIS_DOCKER_DISTROS=$docker_distros
}

# Optimisation WSL avancée
optimize_wsl_performance() {
    log_header "OPTIMISATION PERFORMANCE WSL"
    
    # Analyser d'abord l'utilisation
    analyze_wsl_usage
    
    log INFO "WSL" "OPTIONS D'OPTIMISATION WSL:"
    log INFO "WSL" "  1) Compactage VHDX (récupère l'espace disque inutilisé)"
    log INFO "WSL" "  2) Redémarrage WSL (ferme toutes les distributions)"
    log INFO "WSL" "  3) Nettoyage des distributions arrêtées (supprime les distributions inutiles)"
    log INFO "WSL" "  4) Configuration de la mémoire WSL (ajuste .wslconfig)"
    log INFO "WSL" "  5) Optimisation complète (combine toutes les options)"
    log INFO "WSL" "  0) Annuler"
    
    echo ""
    read -p "Votre choix (0-5): " wsl_choice
    
    case "$wsl_choice" in
        1)
            log_info "WSL" "Compactage VHDX sélectionné"
            compact_vhdx_files
            ;;
        2)
            log_info "WSL" "Redémarrage WSL sélectionné"
            restart_wsl_completely
            ;;
        3)
            log_info "WSL" "Nettoyage distributions arrêtées sélectionné"
            cleanup_stopped_wsl_distros
            ;;
        4)
            log_info "WSL" "Configuration mémoire WSL sélectionnée"
            configure_wsl_memory
            ;;
        5)
            log_info "WSL" "Optimisation complète sélectionnée"
            optimize_wsl_complete
            ;;
        0)
            log_info "WSL" "Optimisation WSL annulée par l'utilisateur"
            ;;
        *)
            log_warn "WSL" "Choix invalide: $wsl_choice"
            echo -e "${C_RED}Choix invalide.${C_RESET}"
            ;;
    esac
}

# Compactage des fichiers VHDX
compact_vhdx_files() {
    log_info "WSL" "Démarrage du compactage VHDX"
    
    log INFO "WSL" "💽 COMPACTAGE VHDX"
    log INFO "WSL" "Recherche et compactage des fichiers VHDX..."
    
    # D'abord arrêter toutes les distributions WSL
    log_info "WSL" "Arrêt de toutes les distributions WSL"
    wsl.exe --shutdown
    sleep 3
    
    # Script PowerShell pour compacter les VHDX
    local compact_script=$(cat <<'EOF'
$VhdxPaths = @()

# Chemins WSL standard
$localAppData = [Environment]::GetFolderPath('LocalApplicationData')
$wslPaths = Get-ChildItem -Path (Join-Path $localAppData "Packages\MicrosoftCorporationII.WindowsSubsystemForLinux_*\LocalState") -Filter "ext4.vhdx" -Recurse -ErrorAction SilentlyContinue
$VhdxPaths += $wslPaths

# Chemins Docker Desktop
$dockerPaths = Get-ChildItem -Path (Join-Path $localAppData "Docker\wsl") -Filter "*.vhdx" -Recurse -ErrorAction SilentlyContinue
$VhdxPaths += $dockerPaths

$totalCompacted = 0
$totalSpaceSaved = 0

foreach ($vhdx in $VhdxPaths) {
    try {
        $sizeBefore = $vhdx.Length
        $sizeBeforeMB = [math]::Round($sizeBefore / 1MB, 1)
        
        Write-Host "Compactage: $($vhdx.Name) ($sizeBeforeMB MB)" -ForegroundColor Yellow
        
        # Utiliser diskpart pour compacter
        $diskpartScript = @"
select vdisk file="$($vhdx.FullName)"
attach vdisk readonly
compact vdisk
detach vdisk
"@
        
        $diskpartScript | diskpart.exe > $null 2>&1
        
        # Vérifier la nouvelle taille
        $vhdxRefresh = Get-Item $vhdx.FullName
        $sizeAfter = $vhdxRefresh.Length
        $sizeAfterMB = [math]::Round($sizeAfter / 1MB, 1)
        $spaceSaved = $sizeBefore - $sizeAfter
        $spaceSavedMB = [math]::Round($spaceSaved / 1MB, 1)
        
        if ($spaceSaved -gt 0) {
            Write-Host "  Compacté: $sizeAfterMB MB (économisé: $spaceSavedMB MB)" -ForegroundColor Green
            $totalSpaceSaved += $spaceSaved
        } else {
            Write-Host "  Déjà optimal: $sizeAfterMB MB" -ForegroundColor Gray
        }
        
        $totalCompacted++
    } catch {
        Write-Host "  Erreur lors du compactage: $($_.Exception.Message)" -ForegroundColor Red
    }
}

$totalSpaceSavedMB = [math]::Round($totalSpaceSaved / 1MB, 1)
Write-Host "Compactage terminé: $totalCompacted fichiers traités, $totalSpaceSavedMB MB récupérés" -ForegroundColor Cyan
EOF
    )
    
    # Exécuter le script de compactage
    if powershell.exe -ExecutionPolicy Bypass -Command "$compact_script"; then
        log_ok "Compactage VHDX terminé avec succès."
    else
        log_warn "Le compactage VHDX a rencontré des erreurs."
    fi
}

# Redémarrage complet de WSL
restart_wsl_completely() {
    log_info "WSL" "Redémarrage complet de WSL"
    
    log INFO "WSL" "🔄 REDÉMARRAGE WSL"
    log INFO "WSL" "Arrêt de toutes les distributions..."
    
    # Arrêter toutes les distributions
    wsl.exe --shutdown
    sleep 2
    
    # Redémarrer le service WSL
    if command -v powershell.exe >/dev/null 2>&1; then
        log_info "WSL" "Redémarrage du service WSL"
        powershell.exe -Command "Restart-Service LxssManager -Force" 2>/dev/null || true
        sleep 3
    fi
    
    log_ok "WSL redémarré avec succès."
}

# Nettoyage des distributions WSL arrêtées
cleanup_stopped_wsl_distros() {
    log_warn "WSL" "ATTENTION: Nettoyage des distributions arrêtées"
    
    log INFO "WSL" "⚠️  NETTOYAGE DISTRIBUTIONS ARRÊTÉES"
    log INFO "WSL" "Cette option supprime définitivement les distributions WSL arrêtées"
    log INFO "WSL" "Les distributions Docker seront préservées."
    
    # Lister les distributions arrêtées (non Docker)
    local stopped_distros=()
    while IFS= read -r line; do
        if [[ "$line" =~ [[:space:]]*([^[:space:]]+)[[:space:]]+Stopped ]]; then
            local name="${BASH_REMATCH[1]}"
            name=${name#\*}
            name=${name// /}
            
            # Exclure les distributions Docker
            if [[ -n "$name" && ! "$name" =~ docker ]]; then
                stopped_distros+=("$name")
            fi
        fi
    done <<< "$(wsl.exe -l -v 2>/dev/null)"
    
    if [[ ${#stopped_distros[@]} -eq 0 ]]; then
        log_ok "Aucune distribution arrêtée non-Docker trouvée."
        return 0
    fi
    
    log INFO "WSL" "Distributions arrêtées trouvées:"
    for distro in "${stopped_distros[@]}"; do
        log INFO "WSL" "    • $distro"
    done
    
    echo ""
    read -p "  Confirmez-vous la suppression ? (y/N): " confirm_cleanup
    
    if [[ ! "$confirm_cleanup" =~ ^[Yy]$ ]]; then
        log_info "WSL" "Nettoyage distributions annulé par l'utilisateur"
        return 0
    fi
    
    echo -e "\n${C_RED}🗑️ SUPPRESSION EN COURS${C_RESET}"
    for distro in "${stopped_distros[@]}"; do
        log_info "WSL" "Suppression de la distribution: $distro"
        if wsl.exe --unregister "$distro" 2>/dev/null; then
            echo -e "    ${C_GREEN}✅ $distro supprimée${C_RESET}"
        else
            echo -e "    ${C_RED}❌ Échec suppression $distro${C_RESET}"
        fi
    done
    
    log_ok "Nettoyage des distributions terminé."
}

# Configuration de la mémoire WSL  
configure_wsl_memory() {
    log_info "WSL" "Configuration de la mémoire WSL"
    
    log INFO "WSL" "🧠 CONFIGURATION MÉMOIRE WSL"
    
    # Détecter la RAM totale du système
    local total_ram_gb=8
    if command -v powershell.exe >/dev/null 2>&1; then
        total_ram_gb=$(powershell.exe -Command "(Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB" 2>/dev/null | tr -d '\r' | head -1)
        total_ram_gb=${total_ram_gb%.*}  # Enlever les décimales
    fi
    
    log INFO "WSL" "RAM système détectée: ${total_ram_gb}GB"
    
    # Calculer les recommandations
    local recommended_memory=$((total_ram_gb * 75 / 100))
    local recommended_swap=$((recommended_memory / 4))
    
    log INFO "WSL" "Configuration recommandée:"
    log INFO "WSL" "    Mémoire WSL: ${recommended_memory}GB (75% du système)"
    log INFO "WSL" "    Swap: ${recommended_swap}GB"
    log INFO "WSL" "    Processeurs: $(nproc 2>/dev/null || echo "4")"
    
    echo ""
    read -p "  Appliquer la configuration recommandée ? (Y/n): " apply_config
    
    if [[ ! "$apply_config" =~ ^[Nn]$ ]]; then
        # Créer le fichier .wslconfig
        local wsl_config_path
        wsl_config_path=$(powershell.exe -Command "[Environment]::GetFolderPath('UserProfile')" 2>/dev/null | tr -d '\r')
        wsl_config_path="${wsl_config_path}\\.wslconfig"
        
        local wsl_config_content="[wsl2]
memory=${recommended_memory}GB
swap=${recommended_swap}GB
processors=$(nproc 2>/dev/null || echo "4")
localhostForwarding=true

[experimental]
sparseVhd=true
"
        
        log_info "WSL" "Création du fichier .wslconfig"
        if powershell.exe -Command "Set-Content -Path '$wsl_config_path' -Value '$wsl_config_content' -Encoding UTF8"; then
            log_ok "Configuration WSL appliquée: $wsl_config_path"
            log INFO "WSL" "Redémarrage WSL requis pour appliquer les changements."
            log INFO "WSL" "Redémarrer WSL maintenant ? (y/N): "
            if [[ "$restart_now" =~ ^[Yy]$ ]]; then
                restart_wsl_completely
            fi
        else
            log_error "WSL" "Échec de la création du fichier .wslconfig"
        fi
    else
        log_info "WSL" "Configuration WSL annulée par l'utilisateur"
    fi
}

# Optimisation WSL complète
optimize_wsl_complete() {
    log_info "WSL" "Démarrage de l'optimisation WSL complète"
    
    log INFO "WSL" "🚀 OPTIMISATION WSL COMPLÈTE"
    log INFO "WSL" "Exécution de toutes les optimisations..."
    
    # 1. Configuration mémoire
    log INFO "WSL" "1/4 Configuration mémoire..."
    configure_wsl_memory
    
    # 2. Nettoyage distributions
    log INFO "WSL" "2/4 Nettoyage distributions..."
    cleanup_stopped_wsl_distros
    
    # 3. Redémarrage WSL
    log INFO "WSL" "3/4 Redémarrage WSL..."
    restart_wsl_completely
    
    # 4. Compactage VHDX
    log INFO "WSL" "4/4 Compactage VHDX..."
    compact_vhdx_files
    
    log_ok "Optimisation WSL complète terminée avec succès."
}

# --- INSTALLATION ARIA2C ---
install_aria2c() {
    log_info "ARIA2C" "Installation automatique d'aria2c"
    
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        # Windows/Git Bash - télécharger binaire
        local aria2_url="https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0-win-64bit-build1.zip"
        local temp_dir="$BASE_DIR/temp_aria2"
        
        mkdir -p "$temp_dir"
        
        log_info "ARIA2C" "Téléchargement aria2c pour Windows..."
        if curl -L -o "$temp_dir/aria2.zip" "$aria2_url" 2>/dev/null; then
            log_info "ARIA2C" "Extraction..."
            if command -v unzip &>/dev/null; then
                unzip -o -q "$temp_dir/aria2.zip" -d "$temp_dir" 2>/dev/null
                cp "$temp_dir"/aria2-*/aria2c.exe "$BASE_DIR/" 2>/dev/null || cp "$temp_dir"/aria2*/aria2c.exe "$BASE_DIR/"
                rm -rf "$temp_dir"
                export PATH="$BASE_DIR:$PATH"
                log_ok "aria2c installé avec succès"
            else
                log_error "unzip manquant - installation aria2c échouée"
            fi
        else
            log_error "Téléchargement aria2c échoué"
        fi
    else
        log_error "Installation automatique aria2c non supportée sur cet OS"
    fi
}

# --- VALIDATION SYSTÈME ---
validate_system() {
    log_header "VALIDATION COMPLÈTE DU SYSTÈME"
    
    log INFO "SYSTEM_VALIDATION" "🔍 VALIDATION EN COURS..."
    
    local validation_errors=0
    local validation_warnings=0
    
    # Validation Docker
    log INFO "SYSTEM_VALIDATION" "Docker:"
    if docker info >/dev/null 2>&1; then
        log INFO "SYSTEM_VALIDATION" "✅ Docker Engine"
        
        # Tester l'accès GPU
        if command -v nvidia-smi >/dev/null 2>&1; then
            if docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi >/dev/null 2>&1; then
                log INFO "SYSTEM_VALIDATION" "✅ Support GPU Docker"
            else
                log WARN "SYSTEM_VALIDATION" "⚠️ Support GPU Docker non configuré"
                ((validation_warnings++))
            fi
        else
            log WARN "SYSTEM_VALIDATION" "⚠️ NVIDIA drivers non détectés"
            ((validation_warnings++))
        fi
    else
        log ERROR "SYSTEM_VALIDATION" "❌ Docker Engine non accessible"
        ((validation_errors++))
    fi
    
    # Validation WSL
    log INFO "SYSTEM_VALIDATION" "WSL:"
    if command -v wsl.exe >/dev/null 2>&1; then
        log INFO "SYSTEM_VALIDATION" "✅ WSL disponible"
        
        local wsl_distros=$(wsl.exe -l -v 2>/dev/null | grep -c -v "NAME" || echo "0")
        if [[ $wsl_distros -gt 0 ]]; then
            log INFO "SYSTEM_VALIDATION" "✅ $wsl_distros distributions WSL"
        else
            log WARN "SYSTEM_VALIDATION" "⚠️ Aucune distribution WSL"
            ((validation_warnings++))
        fi
    else
        log ERROR "SYSTEM_VALIDATION" "❌ WSL non disponible"
        ((validation_errors++))
    fi
    
    # Validation des dépendances
    log INFO "SYSTEM_VALIDATION" "Dépendances:"
    local required_commands=("git" "aria2c")
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log INFO "SYSTEM_VALIDATION" "✅ $cmd"
        else
            log ERROR "SYSTEM_VALIDATION" "❌ $cmd manquant"
            ((validation_errors++))
        fi
    done
    
    # Résumé de validation
    log INFO "SYSTEM_VALIDATION" "RÉSUMÉ DE VALIDATION:"
    if [[ $validation_errors -eq 0 && $validation_warnings -eq 0 ]]; then
        log INFO "SYSTEM_VALIDATION" "🎉 Système entièrement opérationnel !"
    elif [[ $validation_errors -eq 0 ]]; then
        log WARN "SYSTEM_VALIDATION" "⚠️ Système opérationnel avec $validation_warnings avertissement(s)"
    else
        log ERROR "SYSTEM_VALIDATION" "❌ $validation_errors erreur(s) et $validation_warnings avertissement(s) détecté(s)"
        log ERROR "SYSTEM_VALIDATION" "Le système nécessite des corrections avant déploiement."
    fi
    
    return $validation_errors
}