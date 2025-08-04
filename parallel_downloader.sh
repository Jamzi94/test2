#!/bin/bash
# ==============================================================================
#      JAMZI AI STACK - TÉLÉCHARGEUR PARALLÈLE OPTIMISÉ v3.0
# ==============================================================================
# Système de téléchargement en parallèle avec aria2c et gestion d'erreurs

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- CONFIGURATION TÉLÉCHARGEMENT OPTIMISÉE ---
MAX_CONCURRENT_DOWNLOADS="${MAX_CONCURRENT_DOWNLOADS:-16}"  # Nombre de téléchargements simultanés (doublé)
ARIA2C_CONNECTIONS="${ARIA2C_CONNECTIONS:-32}"            # Connexions par fichier (doublé)
ARIA2C_SPLIT="${ARIA2C_SPLIT:-32}"                        # Segments par fichier (doublé)
MAX_CONNECTION_PER_SERVER="${MAX_CONNECTION_PER_SERVER:-16}" # Connexions par serveur (doublé)
DOWNLOAD_TIMEOUT="${DOWNLOAD_TIMEOUT:-300}"               # Timeout en secondes (augmenté pour gros fichiers)
MAX_RETRIES="${MAX_RETRIES:-5}"                           # Nombre de tentatives (augmenté)
MIN_SPLIT_SIZE="${MIN_SPLIT_SIZE:-20M}"                   # Taille minimale des segments (optimisé pour gros modèles)

# --- TÉLÉCHARGEMENT PARALLÈLE OPTIMISÉ ---

download_files_parallel() {
    local -n download_list_ref="$1"
    local base_dir="$2"
    
    if [[ ${#download_list_ref[@]} -eq 0 ]]; then
        log INFO "DOWNLOAD" "Aucun fichier à télécharger"
        return 0
    fi
    
    log INFO "DOWNLOAD" "🚀 TÉLÉCHARGEMENT PARALLÈLE OPTIMISÉ"
    log INFO "DOWNLOAD" "📊 ${#download_list_ref[@]} fichiers | 🔗 $MAX_CONCURRENT_DOWNLOADS simultanés | ⚡ ${ARIA2C_CONNECTIONS}x${ARIA2C_SPLIT} par fichier"
    
    # Créer fichier d'input pour aria2c avec chemins absolus
    local input_file="$(realpath "$base_dir")/temp_download_list.txt"
    local download_dir="$(realpath "$base_dir")/temp_downloads"
    mkdir -p "$download_dir"
    
    log INFO "DOWNLOAD" "Répertoire de téléchargement: $download_dir"
    
    > "$input_file"  # Vider le fichier
    
    # Préparer la liste des téléchargements
    local files_to_process=()
    
    log INFO "DOWNLOAD" "Préparation de la liste des téléchargements..."
    for download_info in "${download_list_ref[@]}"; do
        IFS='|' read -r url dest_path file_type <<< "$download_info"
        local full_dest_path="$base_dir/data/$dest_path"
        local file_basename="$(basename "$dest_path")"
        
        # Vérifier si le fichier existe déjà (vérification simple mais efficace)
        if [[ -f "$full_dest_path" ]]; then
            local file_size=$(stat -c%s "$full_dest_path" 2>/dev/null || echo "0")
            if [[ $file_size -gt 1024 ]]; then  # Plus d'1KB = fichier valide
                log_status "SUCCESS" "Déjà présent et valide: $file_basename (${file_size} bytes)" "DOWNLOAD"
                continue
            else
                log_status "WARN" "Fichier existant trop petit, re-téléchargement: $file_basename" "DOWNLOAD"
                rm -f "$full_dest_path"
            fi
        fi
        
        # Ignorer les fichiers locaux (file://)
        if [[ "$url" == file://* ]]; then
            local_file_path="${url#file://}"
            mkdir -p "$(dirname "$full_dest_path")"
            if cp "$local_file_path" "$full_dest_path"; then
                log INFO "DOWNLOAD" "Copié: $file_basename"
            else
                log WARN "DOWNLOAD" "Échec copie: $file_basename"
            fi
            continue
        fi
        
        # Ajouter à la liste aria2c
        local temp_path="$download_dir/$file_basename"
        echo "$url" >> "$input_file"
        echo "  out=$file_basename" >> "$input_file"
        echo "  dir=$download_dir" >> "$input_file"
        echo "" >> "$input_file"
        
        files_to_process+=("$temp_path|$full_dest_path|$file_basename|$file_type")
    done
    
    # Si aucun fichier à télécharger
    if [[ ! -s "$input_file" ]]; then
        log INFO "DOWNLOAD" "Tous les fichiers sont déjà présents"
        rm -f "$input_file"
        return 0
    fi
    
    # Configuration aria2c ultra-optimisée - FORCER NOUVEAUX TÉLÉCHARGEMENTS
    local aria2c_cmd="aria2c \
        --input-file=\"$input_file\" \
        --max-concurrent-downloads=$MAX_CONCURRENT_DOWNLOADS \
        --max-connection-per-server=$MAX_CONNECTION_PER_SERVER \
        --split=$ARIA2C_SPLIT \
        --min-split-size=$MIN_SPLIT_SIZE \
        --max-tries=$MAX_RETRIES \
        --retry-wait=1 \
        --timeout=$DOWNLOAD_TIMEOUT \
        --connect-timeout=10 \
        --lowest-speed-limit=1K \
        --max-overall-download-limit=0 \
        --max-download-limit=0 \
        --continue=false \
        --auto-file-renaming=false \
        --allow-overwrite=true \
        --summary-interval=2 \
        --force-save=true \
        --always-resume=false \
        --check-integrity=false \
        --user-agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' \
        --check-certificate=false \
        --http-accept-gzip=true \
        --http-no-cache=true \
        --disable-ipv6=true \
        --reuse-uri=false \
        --max-file-not-found=3 \
        --max-resume-failure-tries=3 \
        --piece-length=1M \
        --stream-piece-selector=inorder"
    
    # Lancer le téléchargement parallèle
    log INFO "DOWNLOAD" "🔽 Démarrage téléchargements..."
    
    local start_time=$(date +%s)
    local aria2c_log="$base_dir/aria2c_output.log"
    if eval "$aria2c_cmd" > "$aria2c_log" 2>&1; then
        cat "$aria2c_log"
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log INFO "DOWNLOAD" "✅ Téléchargements aria2c terminés en ${duration}s"
        
        # Debug: Vérifier le contenu du répertoire temporaire immédiatement après téléchargement
        log INFO "DOWNLOAD" "Contenu du répertoire temporaire $download_dir:"
        ls -la "$download_dir" || log WARN "DOWNLOAD" "Impossible de lister $download_dir"
        
        # Debug: Vérifier chaque fichier spécifiquement
        log INFO "DOWNLOAD" "Vérification détaillée des fichiers attendus:"
        for file_info in "${files_to_process[@]}"; do
            IFS='|' read -r temp_path full_dest_path file_basename file_type <<< "$file_info"
            if [[ -f "$temp_path" ]]; then
                local fsize=$(stat -c%s "$temp_path" 2>/dev/null || echo "0")
                log INFO "DOWNLOAD" "✓ Trouvé: $file_basename (${fsize} bytes) à $temp_path"
            else
                log WARN "DOWNLOAD" "✗ Manquant: $file_basename à $temp_path"
            fi
        done
        
        # Vérifier et déplacer les fichiers téléchargés
        local move_errors=0
        local files_processed=0
        
        # Debug: afficher le contenu du tableau
        log INFO "DOWNLOAD" "Traitement de ${#files_to_process[@]} fichiers téléchargés..."
        
        for file_info in "${files_to_process[@]}"; do
            IFS='|' read -r temp_path full_dest_path file_basename file_type <<< "$file_info"
            ((files_processed++))
            
            log INFO "DOWNLOAD" "Vérification fichier $files_processed: $file_basename"
            
            if [[ -f "$temp_path" ]]; then
                # Vérifier l'intégrité du fichier téléchargé
                if verify_file_exists "$temp_path" 1024; then  # Minimum 1KB
                    # Créer le répertoire de destination
                    mkdir -p "$(dirname "$full_dest_path")"
                    
                    # Déplacer le fichier vers sa destination finale
                    if mv "$temp_path" "$full_dest_path"; then
                        log_status "SUCCESS" "Installé: $file_basename" "DOWNLOAD"
                    else
                        log_status "ERROR" "Échec déplacement: $file_basename" "DOWNLOAD"
                        ((move_errors++))
                    fi
                else
                    log_status "ERROR" "Fichier téléchargé invalide: $file_basename" "DOWNLOAD"
                    rm -f "$temp_path"  # Nettoyer le fichier invalide
                    ((move_errors++))
                fi
            else
                log_status "ERROR" "Fichier non téléchargé: $file_basename" "DOWNLOAD"
                log INFO "DOWNLOAD" "Recherche alternative dans $download_dir..."
                
                # Chercher le fichier avec une extension différente ou nom similaire
                local found_file=$(find "$download_dir" -name "*$file_basename*" -type f 2>/dev/null | head -1)
                if [[ -n "$found_file" && -f "$found_file" ]]; then
                    log INFO "DOWNLOAD" "Fichier trouvé: $found_file"
                    mkdir -p "$(dirname "$full_dest_path")"
                    if mv "$found_file" "$full_dest_path"; then
                        log_status "SUCCESS" "Installé (récupéré): $file_basename" "DOWNLOAD"
                    else
                        ((move_errors++))
                    fi
                else
                    ((move_errors++))
                fi
            fi
        done
        
        if [[ $move_errors -gt 0 ]]; then
            log_status "ERROR" "$move_errors erreurs lors de l'installation des fichiers" "DOWNLOAD"
            # Garder les fichiers temporaires pour debug en cas d'erreur
            log INFO "DOWNLOAD" "Fichiers temporaires conservés dans $download_dir pour debug"
            rm -f "$input_file"  # Nettoyer seulement le fichier de config
            return 1
        fi
        
        log_status "SUCCESS" "Tous les fichiers installés avec succès" "DOWNLOAD"
        # Nettoyer les fichiers temporaires seulement en cas de succès
        rm -f "$input_file"
        rm -rf "$download_dir"
    else
        log ERROR "DOWNLOAD" "Échec des téléchargements parallèles"
        cat "$aria2c_log"
        # Nettoyer et retourner une erreur
        rm -f "$input_file"
        rm -rf "$download_dir"
        return 1
    fi
}

# --- DÉTECTION BANDE PASSANTE ---

detect_bandwidth() {
    log INFO "BANDWIDTH" "📡 Détection bande passante..."
    
    # Skip bandwidth test if aria2c not available
    if ! command -v aria2c &>/dev/null; then
        log WARN "BANDWIDTH" "Aria2c non disponible - configuration par défaut"
        return 0
    fi
    
    # Test simple avec un petit fichier
    local test_url="https://httpbin.org/bytes/1048576"  # 1MB
        local test_file="$BASE_DIR/tmp/bandwidth_test"
    
    mkdir -p "$BASE_DIR/tmp"
    local start_time=$(date +%s.%N)
    if aria2c --quiet --out="bandwidth_test" --dir="$BASE_DIR/tmp" --timeout=10 "$test_url"; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
        
        if [[ -f "$test_file" ]]; then
            local file_size=$(stat -c%s "$test_file" 2>/dev/null || echo "1048576")
            local speed_mbps=$(echo "scale=1; ($file_size * 8) / ($duration * 1000000)" | bc -l 2>/dev/null || echo "10")
            
            rm -f "$test_file"
            
            # Ajuster le nombre de téléchargements simultanés selon la bande passante
            local speed_int=$(printf "%.0f" "$speed_mbps" 2>/dev/null || echo "10")
            
            if [[ $speed_int -ge 200 ]]; then
                MAX_CONCURRENT_DOWNLOADS=24
                ARIA2C_SPLIT=48
                log INFO "BANDWIDTH" "🚀 Connexion très rapide (${speed_mbps}Mbps) - 24 téléchargements simultanés"
            elif [[ $speed_int -ge 100 ]]; then
                MAX_CONCURRENT_DOWNLOADS=20
                ARIA2C_SPLIT=40
                log INFO "BANDWIDTH" "🚀 Connexion rapide (${speed_mbps}Mbps) - 20 téléchargements simultanés"
            elif [[ $speed_int -ge 50 ]]; then
                MAX_CONCURRENT_DOWNLOADS=16
                ARIA2C_SPLIT=32
                log INFO "BANDWIDTH" "⚡ Connexion moyenne (${speed_mbps}Mbps) - 16 téléchargements simultanés"
            elif [[ $speed_int -ge 25 ]]; then
                MAX_CONCURRENT_DOWNLOADS=12
                ARIA2C_SPLIT=24
                log INFO "BANDWIDTH" "📶 Connexion normale (${speed_mbps}Mbps) - 12 téléchargements simultanés"
            else
                MAX_CONCURRENT_DOWNLOADS=8
                ARIA2C_SPLIT=16
                log INFO "BANDWIDTH" "📶 Connexion lente (${speed_mbps}Mbps) - 8 téléchargements simultanés"
            fi
        else
            log WARN "BANDWIDTH" "📶 Test échoué - Configuration par défaut (6 simultanés)"
        fi
    else
        log WARN "BANDWIDTH" "📶 Test réseau échoué - Configuration conservatrice (4 simultanés)"
        MAX_CONCURRENT_DOWNLOADS=4
    fi
    rm -rf "$BASE_DIR/tmp"
}

# --- FONCTIONS D'UTILITÉ ---

# Vérifier si un fichier existe déjà dans sa destination finale
verify_file_exists() {
    local dest_path="$1"
    local min_size="${2:-1024}"  # Taille minimale attendue (défaut: 1KB)
    
    if [[ ! -f "$dest_path" ]]; then
        return 1  # Fichier n'existe pas
    fi
    
    # Vérifier la taille du fichier (éviter les fichiers corrompus/partiels)
    local file_size=$(stat -c%s "$dest_path" 2>/dev/null || echo "0")
    if [[ $file_size -lt $min_size ]]; then
        log WARN "VERIFICATION" "Fichier trop petit (${file_size}B < ${min_size}B): $(basename "$dest_path")"
        return 1  # Fichier trop petit, probablement corrompu
    fi
    
    # Vérifications supplémentaires selon l'extension
    local file_ext="${dest_path##*.}"
    case "$file_ext" in
        "safetensors"|"ckpt"|"pth"|"bin")
            # Pour les modèles, vérifier que la taille est > 100MB
            if [[ $file_size -lt 104857600 ]]; then
                log WARN "VERIFICATION" "Modèle trop petit (${file_size}B): $(basename "$dest_path")"
                return 1
            fi
            ;;
        "json"|"yaml"|"yml")
            # Pour les configs/workflows, quelques KB suffisent
            if [[ $file_size -lt 10 ]]; then
                log WARN "VERIFICATION" "Fichier config vide: $(basename "$dest_path")"
                return 1
            fi
            ;;
        "gguf")
            # Pour les modèles GGUF, vérifier > 500MB
            if [[ $file_size -lt 524288000 ]]; then
                log WARN "VERIFICATION" "Modèle GGUF trop petit (${file_size}B): $(basename "$dest_path")"
                return 1
            fi
            ;;
    esac
    
    return 0  # Fichier existe et semble valide
}

# Vérifier et nettoyer les fichiers partiels/corrompus
cleanup_partial_files() {
    local base_dir="$1"
    
    log INFO "VERIFICATION" "🧹 Nettoyage des fichiers partiels..."
    
    # Nettoyer les fichiers aria2c partiels
    find "$base_dir" -name "*.aria2" -delete 2>/dev/null || true
    
    # Nettoyer seulement les anciens fichiers temporaires, pas le répertoire de téléchargement actuel
    rm -f "$base_dir/temp_download_list.txt" 2>/dev/null || true
    rm -f "$base_dir/aria2c_output.log" 2>/dev/null || true
    
    # Nettoyer les anciens téléchargements partiels mais garder le répertoire
    if [[ -d "$base_dir/temp_downloads" ]]; then
        find "$base_dir/temp_downloads" -name "*.part" -delete 2>/dev/null || true
        find "$base_dir/temp_downloads" -name "*.tmp" -delete 2>/dev/null || true
    fi
    
    log INFO "VERIFICATION" "✅ Nettoyage terminé"
}

# Préparer une liste de téléchargement depuis les assets sélectionnés
prepare_download_list() {
    local -n result_list="$1"
    shift
    local asset_types=("$@")
    
    result_list=()
    
    # Mapping entre les types d'assets et les catégories du catalogue
    declare -A asset_category_map=(
        ["MODELS_CHECKPOINTS"]="comfyui_checkpoints"
        ["MODELS_VAE"]="comfyui_vae"
        ["MODELS_CONTROLNET"]="comfyui_controlnet"
        ["MODELS_UPSCALE"]="comfyui_upscale"
        ["MODELS_GFPGAN"]="comfyui_gfpgan"
        ["MODELS_WAV2LIP"]="comfyui_wav2lip"
        ["MODELS_LORAS"]="comfyui_loras"
        ["MODELS_CLIP"]="comfyui_clip"
        ["MODELS_UNET"]="comfyui_unet"
        ["WORKFLOWS_COMFYUI"]="comfyui_workflows"
        ["WORKFLOWS_N8N"]="n8n_workflows"
    )
    
    for asset_type in "${asset_types[@]}"; do
        local selected_var="SELECTED_${asset_type}"
        local catalogue_category="${asset_category_map[$asset_type]:-$asset_type}"
        
        if [[ -n "${!selected_var:-}" ]]; then
            for asset_name in ${!selected_var}; do
                local asset_info=$(get_asset_info "$catalogue_category" "$asset_name")
                if [[ -n "$asset_info" && "$asset_info" != "null" ]]; then
                    IFS='|' read -r asset_url asset_dest_path <<< "$asset_info"
                    result_list+=("$asset_url|$asset_dest_path|$asset_type")
                fi
            done
        fi
    done
}

# Fonction principale pour remplacer sync_all_assets
sync_all_assets_parallel() {
    # TEMPORAIRE: Forcer le fallback curl pour éviter les problèmes aria2c
    log_status "INFO" "Utilisation du mode fallback curl (plus fiable)" "ASSETS"
    sync_all_assets_fallback
    return $?
    
    if ! command -v aria2c &>/dev/null; then
        log WARN "ASSETS" "aria2c non disponible - Utilisation de curl/wget"
        # Fallback: utiliser curl ou wget
        sync_all_assets_fallback
        return $?
    fi
    log_section "Synchronisation Parallèle des Assets" "${LOG_ICONS[ROCKET]}"
    
    # Nettoyer les fichiers partiels/corrompus avant de commencer
    log_status "INFO" "Nettoyage des fichiers temporaires..." "CLEANUP"
    cleanup_partial_files "$BASE_DIR"
    
    # Détecter la bande passante pour optimiser
    log_status "INFO" "Détection de la bande passante réseau..." "NETWORK"
    detect_bandwidth
    
    # Préparer la liste de tous les téléchargements
    local download_list=()
    
    # Assets à traiter
    local asset_types=(
        "MODELS_CHECKPOINTS"
        "MODELS_VAE" 
        "MODELS_CONTROLNET"
        "MODELS_UPSCALE"
        "MODELS_GFPGAN"
        "MODELS_WAV2LIP"
        "MODELS_LORAS"
        "MODELS_CLIP"
        "MODELS_UNET"
        "WORKFLOWS_COMFYUI"
        "WORKFLOWS_N8N"
    )
    
    prepare_download_list download_list "${asset_types[@]}"
    
    # Si aucun téléchargement, passer directement
    if [[ ${#download_list[@]} -eq 0 ]]; then
        log_status "INFO" "Aucun asset à télécharger - Skip" "ASSETS"
        # Traiter les plugins git seulement
        if [[ -n "${SELECTED_PLUGINS_COMFYUI:-}" ]]; then
            log_section "Installation Plugins Git" "${LOG_ICONS[FILE]}"
            install_git_plugins_parallel
        fi
        log_status "SUCCESS" "Synchronisation terminée (aucun téléchargement)" "ASSETS"
        log_section_end
        return 0
    fi
    
    # Traiter les plugins git séparément (ils nécessitent git clone)
    if [[ -n "${SELECTED_PLUGINS_COMFYUI:-}" ]]; then
        log_section "Installation Plugins Git" "${LOG_ICONS[FILE]}"
        install_git_plugins_parallel
    fi
    
    # Lancer les téléchargements parallèles
    log_status "INFO" "Démarrage des téléchargements parallèles (${#download_list[@]} fichiers)..." "DOWNLOAD"
    if download_files_parallel download_list "$BASE_DIR"; then
        log_status "SUCCESS" "Synchronisation parallèle terminée avec succès" "ASSETS"
        log_section_end
        return 0
    else
        log_status "ERROR" "Échec de la synchronisation parallèle" "ASSETS"
        log_section_end
        return 1
    fi
}


# Installation parallèle des plugins Git
install_git_plugins_parallel() {
    local git_pids=()
    local max_git_jobs=4
    local active_jobs=0
    
    # Initialiser PLUGINS_GIT comme tableau associatif vide si pas défini
    if ! declare -p PLUGINS_GIT >/dev/null 2>&1; then
        declare -gA PLUGINS_GIT=()
    fi
    
    for plugin_name in ${SELECTED_PLUGINS_COMFYUI:-}; do
        if [[ -v "PLUGINS_GIT[$plugin_name]" ]]; then
            local plugin_url="${PLUGINS_GIT[$plugin_name]}"
            local target_dir="$BASE_DIR/data/comfyui/custom_nodes/$plugin_name"
            
            if [[ -d "$target_dir" ]]; then
                log INFO "GIT_PLUGINS" "Plugin déjà présent: $plugin_name"
                continue
            fi
            
            # Attendre si trop de jobs actifs
            while [[ $active_jobs -ge $max_git_jobs ]]; do
                wait -n  # Attendre qu'un job se termine
                ((active_jobs--))
            done
            
            # Lancer clone en arrière-plan
            {
                log INFO "GIT_PLUGINS" "Clonage: $plugin_name"
                if git clone --depth=1 --quiet "$plugin_url" "$target_dir" 2>/dev/null; then
                    log INFO "GIT_PLUGINS" "✅ Plugin cloné: $plugin_name"
                else
                    log WARN "GIT_PLUGINS" "❌ Échec clone: $plugin_name"
                    rm -rf "$target_dir"
                fi
            } &
            
            git_pids+=($!)
            ((active_jobs++))
        fi
    done
    
    # Attendre tous les clones
    for pid in "${git_pids[@]}"; do
        wait "$pid"
    done
    
    log INFO "GIT_PLUGINS" "✅ Installation plugins Git terminée"
}

# Fonction fallback robuste avec curl
sync_all_assets_fallback() {
    log_section "Synchronisation Assets (Fallback Curl)" "${LOG_ICONS[DOWNLOAD]}"
    
    # Préparer la liste des téléchargements
    local download_list=()
    local asset_types=(
        "MODELS_CHECKPOINTS"
        "MODELS_VAE" 
        "MODELS_CONTROLNET"
        "MODELS_UPSCALE"
        "MODELS_GFPGAN"
        "MODELS_WAV2LIP"
        "MODELS_LORAS"
        "MODELS_CLIP"
        "MODELS_UNET"
        "WORKFLOWS_COMFYUI"
        "WORKFLOWS_N8N"
    )
    
    prepare_download_list download_list "${asset_types[@]}"
    
    local success_count=0
    local total_files=${#download_list[@]}
    
    log_status "INFO" "Téléchargement de $total_files fichiers avec curl..." "DOWNLOAD"
    
    # DEBUG: Afficher la liste des téléchargements
    log_status "DEBUG" "Liste des téléchargements:" "DOWNLOAD"
    local file_count=0
    for download_info in "${download_list[@]}"; do
        ((file_count++))
        log_status "DEBUG" "Fichier $file_count: $download_info" "DOWNLOAD"
    done
    
    # Traitement des téléchargements
    local file_count=0
    for download_info in "${download_list[@]}"; do
        ((file_count++))
        log_status "DEBUG" "Traitement fichier $file_count/$total_files..." "DOWNLOAD"
        IFS='|' read -r url dest_path file_type <<< "$download_info"
        local full_dest_path="$BASE_DIR/data/$dest_path"
        local file_basename="$(basename "$dest_path")"
        
        # Vérifier si le fichier existe déjà
        log_status "DEBUG" "Vérification: $file_basename -> $full_dest_path" "DOWNLOAD"
        if [[ -f "$full_dest_path" ]]; then
            local file_size=$(stat -c%s "$full_dest_path" 2>/dev/null || echo "0")
            log_status "DEBUG" "Fichier existant trouvé, taille: ${file_size} bytes" "DOWNLOAD"
            if [[ $file_size -gt 1024 ]]; then
                log_status "SUCCESS" "Déjà présent: $file_basename (${file_size} bytes)" "DOWNLOAD"
                ((success_count++))
                log_status "DEBUG" "Continue vers fichier suivant..." "DOWNLOAD"
                continue
            fi
        else
            log_status "DEBUG" "Fichier inexistant, téléchargement nécessaire" "DOWNLOAD"
        fi
        
        # Créer le répertoire de destination
        mkdir -p "$(dirname "$full_dest_path")"
        
        # Télécharger avec curl
        log_status "INFO" "Téléchargement: $file_basename..." "DOWNLOAD"
        if curl -L -o "$full_dest_path" "$url" --connect-timeout 30 --max-time 300 -s; then
            local new_size=$(stat -c%s "$full_dest_path" 2>/dev/null || echo "0")
            if [[ $new_size -gt 1024 ]]; then
                log_status "SUCCESS" "Téléchargé: $file_basename (${new_size} bytes)" "DOWNLOAD"
                ((success_count++))
            else
                log_status "ERROR" "Fichier téléchargé invalide: $file_basename" "DOWNLOAD"
                rm -f "$full_dest_path"
            fi
        else
            log_status "ERROR" "Échec téléchargement: $file_basename" "DOWNLOAD"
        fi
    done
    
    # Traiter les plugins git
    if [[ -n "${SELECTED_PLUGINS_COMFYUI:-}" ]]; then
        log_section "Installation Plugins Git" "${LOG_ICONS[FILE]}"
        install_git_plugins_parallel
    fi
    
    log_status "SUCCESS" "Synchronisation terminée: $success_count/$total_files fichiers" "ASSETS"
    log_section_end
    return 0
}

# Export des fonctions
export -f download_files_parallel detect_bandwidth sync_all_assets_parallel sync_all_assets_fallback
