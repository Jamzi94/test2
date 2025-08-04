#!/bin/bash
# ==============================================================================
#      JAMZI AI STACK - MODULE INTERFACE
# ==============================================================================
# Fonctions d'interface utilisateur et menus interactifs

# --- INTERFACE UTILISATEUR ---



# Affiche le menu principal
display_main_menu() {
    echo -e "${C_BLUE}${C_BOLD}"
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                     J.A.M.Z.I. AI STACK v52.0                              ║
    ║               🚀 DÉPLOYEMENT INTELLIGENT & MODULAIRE 🚀                     ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${C_RESET}"
    
    # Affiche le menu des packs dynamiquement depuis le JSON
    display_pack_menu

    log INFO "INTERFACE" "OPTIONS AVANCÉES:"
    log INFO "INTERFACE" "  🔧 88. Installation personnalisée interactive"
    log INFO "INTERFACE" "  🔄 89. Mise à jour des assets (plugins + modèles)"
    log INFO "INTERFACE" "  🧹 90. Nettoyage intelligent du système"
    log INFO "INTERFACE" "  📊 91. Vérification de l'état du système"
    log INFO "INTERFACE" "  💾 92. Installation des pilotes CUDA WSL"
    log INFO "INTERFACE" "  📋 93. Générer rapport de session"
    log INFO "INTERFACE" "  ❌ 99. Quitter"
    
    log INFO "INTERFACE" "LÉGENDE:"
    log INFO "INTERFACE" "  ✅ Compatible avec votre GPU"
    log INFO "INTERFACE" "  ⚠️  Fonctionne mais performances limitées"
    log INFO "INTERFACE" "  ❌ Nécessite plus de VRAM (mode CPU)"
    
    if [[ -n "${DETECTED_GPU_NAME:-}" ]]; then
        log INFO "INTERFACE" "🎯 GPU Détecté: ${DETECTED_GPU_NAME} (${DETECTED_VRAM_GB}GB VRAM)"
    else
        log WARN "INTERFACE" "⚠️  Aucun GPU détecté - Mode CPU uniquement"
    fi
}


# Affiche les recommandations alternatives en cas de VRAM insuffisante
show_alternative_recommendations() {
    local selected_pack="$1"
    local required_vram="$2"
    local current_vram="${DETECTED_VRAM_GB:-0}"
    
    if [[ $current_vram -lt $required_vram ]]; then
        log WARN "INTERFACE" "RECOMMANDATIONS ALTERNATIVES:"
        log INFO "INTERFACE" "Votre GPU (${current_vram}GB VRAM) est insuffisant pour le pack sélectionné (${required_vram}GB requis)."
        
        case "$selected_pack" in
            10) log INFO "INTERFACE" "→ Essayez le Pack 9 (Wan 2.2 Quantifié) ou Pack 8 (Wan 2.2 Lite)" ;;
            9)  log INFO "INTERFACE" "→ Essayez le Pack 8 (Wan 2.2 Lite)" ;;
            7)  log INFO "INTERFACE" "→ Essayez un pack plus petit (1-6) selon vos besoins" ;;
            6)  log INFO "INTERFACE" "→ Essayez le Pack 4 (Video Advanced SFW) ou Pack 3 (Creative Base)" ;;
            5)  log INFO "INTERFACE" "→ Essayez le Pack 3 (Creative Base)" ;;
            4)  log INFO "INTERFACE" "→ Essayez le Pack 3 (Creative Base)" ;;
        esac
        
        log INFO "INTERFACE" "Vous pouvez également continuer en mode CPU (plus lent)."
        
        read -p "  Continuer quand même avec ce pack ? (y/N) : " proceed
        if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    return 0
}

# Gère le récapitulatif et la confirmation de l'installation
display_installation_summary() {
    log_header "RÉCAPITULATIF DE L'INSTALLATION"
    log INFO "INSTALLATION_SUMMARY" "Services : ${SELECTED_SERVICES:-aucun}"
    log INFO "INSTALLATION_SUMMARY" "Plugins : ${SELECTED_PLUGINS:-aucun}"
    log INFO "INSTALLATION_SUMMARY" "Modèles Ollama : ${SELECTED_MODELS_OLLAMA:-aucun}"
    log INFO "INSTALLATION_SUMMARY" "Checkpoints : ${SELECTED_MODELS_CHECKPOINTS:-aucun}"
    log INFO "INSTALLATION_SUMMARY" "VAE : ${SELECTED_MODELS_VAE:-aucun}"
    log INFO "INSTALLATION_SUMMARY" "ControlNet : ${SELECTED_MODELS_CONTROLNET:-aucun}"
    log INFO "INSTALLATION_SUMMARY" "Upscale : ${SELECTED_MODELS_UPSCALE:-aucun}"
    log INFO "INSTALLATION_SUMMARY" "GFPGAN : ${SELECTED_MODELS_GFPGAN:-aucun}"
    log INFO "INSTALLATION_SUMMARY" "Wav2Lip : ${SELECTED_MODELS_WAV2LIP:-aucun}"
    log INFO "INSTALLATION_SUMMARY" "LoRAs : ${SELECTED_MODELS_LORAS:-aucun}"
    log INFO "INSTALLATION_SUMMARY" "CLIP : ${SELECTED_MODELS_CLIP:-aucun}"
    log INFO "INSTALLATION_SUMMARY" "UNET : ${SELECTED_MODELS_UNET:-aucun}"
    log INFO "INSTALLATION_SUMMARY" "Workflows ComfyUI : ${SELECTED_WORKFLOWS_COMFYUI:-aucun}"
    log INFO "INSTALLATION_SUMMARY" "Workflows n8n : ${SELECTED_WORKFLOWS_N8N:-aucun}"
    log INFO "INSTALLATION_SUMMARY" "Chemin Modèles ComfyUI (Hôte) : ${SELECTED_COMFYUI_MODELS_HOST_PATH:-Défaut}"
    log INFO "INSTALLATION_SUMMARY" "Chemin Données Ollama (Hôte) : ${SELECTED_OLLAMA_HOST_PATH:-Défaut}"
    log INFO "INSTALLATION_SUMMARY" "Chemin Données n8n (Hôte) : ${SELECTED_N8N_HOST_PATH:-Défaut}"

    read -p "Lancer le déploiement avec cette configuration ? (y/n) " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then 
        echo -e "\n${C_YELLOW}Opération annulée par l'utilisateur.${C_RESET}"
        return 1
    fi
    
    return 0
}

# Affiche les informations d'accès aux services
display_access_information() {
    log INFO "ACCESS" "L'ENVIRONNEMENT EST DÉPLOYÉ ET OPÉRATIONNEL"
    log INFO "ACCESS" "ACCÈS À VOS SERVICES :"
    if [[ " $SELECTED_SERVICES " =~ " comfyui " ]]; then 
        log INFO "ACCESS" "→ ComfyUI (Image/Vidéo): http://localhost:${COMFYUI_PORT}"
    fi
    if [[ " $SELECTED_SERVICES " =~ " n8n " ]]; then 
        log INFO "ACCESS" "→ n8n (Automatisation): http://localhost:${N8N_PORT}"
    fi
    if [[ " $SELECTED_SERVICES " =~ " open-webui " ]]; then 
        log INFO "ACCESS" "→ Open WebUI (Langage): http://localhost:${OPEN_WEBUI_PORT}"
    fi
    if [[ " $SELECTED_SERVICES " =~ " postgres " ]]; then 
        log INFO "ACCESS" "→ PostgreSQL: Accessible via n8n (utilisateur: ${POSTGRES_USER})"
    fi
    if [[ " $SELECTED_SERVICES " =~ " redis " ]]; then 
        log INFO "ACCESS" "→ Redis: Accessible via n8n (port interne 6379)"
    fi
    
    log INFO "ACCESS" "COMMANDES UTILES :"
    log INFO "ACCESS" "• Arrêter tous les services: docker compose down"
    log INFO "ACCESS" "• Redémarrer les services: docker compose up -d"
    log INFO "ACCESS" "• Voir les logs: docker compose logs -f [service]"
    log INFO "ACCESS" "• Relancer le script: ./deploy.sh"
    
    if [[ -n "${DETECTED_GPU_NAME:-}" ]]; then
        log INFO "ACCESS" "✅ GPU Support activé: ${DETECTED_GPU_NAME}"
    else
        log WARN "ACCESS" "⚠️  Mode CPU activé (pas de GPU détecté)"
    fi
    
    log INFO "ACCESS" "Profitez bien de votre stack IA ! 🚀"
}

# Fonction de sélection générique pour les listes
_select_from_map() {
    local map_name="$1"
    local item_type="$2"
    local selected_var_name="$3"
    
    declare -n map_ref="$map_name"
    declare -n selected_ref="$selected_var_name"
    
    log INFO "INTERFACE" "Sélection des $item_type :"
    log INFO "INTERFACE" "Tapez les numéros des $item_type souhaités (ex: 1 3 5), ou 0 pour tout sélectionner :"
    
    local counter=1
    local keys=()
    for key in "${!map_ref[@]}"; do
        keys+=("$key")
        log INFO "INTERFACE" "  $counter. $key"
        ((counter++))
    done
    
    read -p "Votre choix : " choices
    
    if [[ "$choices" == "0" ]]; then
        selected_ref="${keys[*]}"
        log INFO "INTERFACE" "Tous les $item_type sélectionnés."
    else
        local selected_items=()
        for choice in $choices; do
            if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "${#keys[@]}" ]]; then
                selected_items+=("${keys[$((choice-1))]}")
            fi
        done
        selected_ref="${selected_items[*]}"
        log INFO "INTERFACE" "${#selected_items[@]} $item_type sélectionné(s)."
    fi
}

# Fonctions de sélection spécialisées pour chaque type d'asset
select_services() {
    _select_from_map "AVAILABLE_SERVICES" "services" "SELECTED_SERVICES"
}

select_ollama_models() {
    _select_from_map "OLLAMA_MODELS" "modèles Ollama" "SELECTED_MODELS_OLLAMA"
}

select_comfyui_checkpoints() {
    _select_from_map "MODELS_CHECKPOINTS" "checkpoints ComfyUI" "SELECTED_MODELS_CHECKPOINTS"
}

select_comfyui_vae() {
    _select_from_map "MODELS_VAE" "modèles VAE" "SELECTED_MODELS_VAE"
}

select_comfyui_controlnet() {
    _select_from_map "MODELS_CONTROLNET" "modèles ControlNet" "SELECTED_MODELS_CONTROLNET"
}

select_comfyui_upscale() {
    _select_from_map "MODELS_UPSCALE" "modèles Upscale" "SELECTED_MODELS_UPSCALE"
}

select_comfyui_gfpgan() {
    _select_from_map "MODELS_GFPGAN" "modèles GFPGAN" "SELECTED_MODELS_GFPGAN"
}

select_comfyui_wav2lip() {
    _select_from_map "MODELS_WAV2LIP" "modèles Wav2Lip" "SELECTED_MODELS_WAV2LIP"
}

select_comfyui_loras() {
    _select_from_map "MODELS_LORAS" "modèles LoRA" "SELECTED_MODELS_LORAS"
}

select_comfyui_plugins() {
    _select_from_map "PLUGINS_GIT" "plugins ComfyUI" "SELECTED_PLUGINS_COMFYUI"
}

select_comfyui_workflows() {
    _select_from_map "WORKFLOWS_COMFYUI" "workflows ComfyUI" "SELECTED_WORKFLOWS_COMFYUI"
}

select_comfyui_clip() {
    _select_from_map "MODELS_CLIP" "modèles CLIP" "SELECTED_MODELS_CLIP"
}

select_comfyui_unet() {
    _select_from_map "MODELS_UNET" "modèles UNET" "SELECTED_MODELS_UNET"
}

select_n8n_workflows() {
    _select_from_map "WORKFLOWS_N8N" "workflows n8n" "SELECTED_WORKFLOWS_N8N"
}

# Demande les chemins d'hôte personnalisés
select_custom_host_paths() {
    log INFO "INTERFACE" "Configuration des chemins d'hôte personnalisés (optionnel) :"
    log INFO "INTERFACE" "Laissez vide pour utiliser les chemins par défaut dans ./data/"
    
    if [[ " $SELECTED_SERVICES " =~ " comfyui " ]]; then
        read -p "Chemin pour les modèles ComfyUI (défaut: ./data/comfyui/models) : " SELECTED_COMFYUI_MODELS_HOST_PATH
    fi
    
    if [[ " $SELECTED_SERVICES " =~ " ollama " ]]; then
        read -p "Chemin pour les données Ollama (défaut: ./data/ollama) : " SELECTED_OLLAMA_HOST_PATH
    fi
    
    if [[ " $SELECTED_SERVICES " =~ " n8n " ]]; then
        read -p "Chemin pour les données n8n (défaut: ./data/n8n) : " SELECTED_N8N_HOST_PATH
    fi
}

# --- INTERFACE AMÉLIORÉE AVEC PROGRESS FEEDBACK ---

# Afficheur de progression amélioré avec estimation de temps
show_deployment_progress() {
    local total_steps="$1"
    local current_step="$2"
    local step_name="$3"
    local start_time="${4:-$(date +%s)}"
    
    # Calculer le pourcentage
    local percentage=$((current_step * 100 / total_steps))
    
    # Calculer le temps écoulé et estimer le temps restant
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    local estimated_total=$((elapsed * total_steps / current_step))
    local remaining=$((estimated_total - elapsed))
    
    # Formater les temps
    local elapsed_formatted=$(format_duration $elapsed)
    local remaining_formatted=$(format_duration $remaining)
    
    # Construire la barre de progression
    local bar_length=30
    local filled_length=$((percentage * bar_length / 100))
    local bar=""
    
    for ((i=0; i<filled_length; i++)); do bar+="█"; done
    for ((i=filled_length; i<bar_length; i++)); do bar+="░"; done
    
    # Afficher la progression
    printf "\r[DÉPLOIEMENT] [%s] %3d%% (%d/%d) %s (⏱️ %s | ⏳ %s)" "$bar" "$percentage" "$current_step" "$total_steps" "$step_name" "$elapsed_formatted" "$remaining_formatted"
    
    # Nouvelle ligne si terminé
    [[ $current_step -eq $total_steps ]] && echo
}

# Formater la durée en format lisible
format_duration() {
    local seconds="$1"
    
    if [[ $seconds -lt 60 ]]; then
        echo "${seconds}s"
    elif [[ $seconds -lt 3600 ]]; then
        local minutes=$((seconds / 60))
        local remaining_seconds=$((seconds % 60))
        printf "%dm %02ds" "$minutes" "$remaining_seconds"
    else
        local hours=$((seconds / 3600))
        local remaining_minutes=$(((seconds % 3600) / 60))
        printf "%dh %02dm" "$hours" "$remaining_minutes"
    fi
}

# Spinner d'attente avec message dynamique
show_spinner() {
    local pid="$1"
    local message="$2"
    local delay="${3:-0.1}"
    
    local spin_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local temp_file=$(mktemp)
    
    # Fonction pour nettoyer le spinner
    cleanup_spinner() {
        printf "\r%*s\r" "${#message}" ""
        rm -f "$temp_file"
    }
    
    trap cleanup_spinner EXIT
    
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r%s %s" "${spin_chars[i]}" "$message"
        i=$(((i + 1) % ${#spin_chars[@]}))
        sleep "$delay"
    done
    
    cleanup_spinner
}

# Confirmation interactive améliorée avec détails
enhanced_confirmation_dialog() {
    local title="$1"
    local pack_id="$2"
    
    clear
    log INFO "CONFIRMATION" "╔══════════════════════════════════════════════════════════════════════════════╗"
    log INFO "CONFIRMATION" "║                    CONFIRMATION D'INSTALLATION                              ║"
    log INFO "CONFIRMATION" "╚══════════════════════════════════════════════════════════════════════════════╝"
    
    # Afficher les informations du pack
    local pack_name=$(get_pack_info "$pack_id" "name")
    local pack_description=$(get_pack_info "$pack_id" "description")
    local vram_required=$(get_pack_requirements "$pack_id" "vram_gb")
    local disk_required=$(get_pack_requirements "$pack_id" "disk_gb")
    
    log INFO "CONFIRMATION" "Pack sélectionné: $pack_name"
    log INFO "CONFIRMATION" "Description: $pack_description"
    
    # Afficher les exigences système
    log INFO "CONFIRMATION" "EXIGENCES SYSTÈME:"
    if [[ -n "$vram_required" && "$vram_required" != "null" ]]; then
        local vram_status_icon="❌"
        [[ ${DETECTED_VRAM_GB:-0} -ge $vram_required ]] && vram_status_icon="✅"
        log INFO "CONFIRMATION" "  $vram_status_icon VRAM: ${vram_required}GB requis (${DETECTED_VRAM_GB:-0}GB détecté)"
    fi
    
    if [[ -n "$disk_required" && "$disk_required" != "null" ]]; then
        local disk_available=$(df "$BASE_DIR" | tail -1 | awk '{print int($4/1024/1024)}')
        local disk_status_icon="❌"
        [[ $disk_available -ge $disk_required ]] && disk_status_icon="✅"
        log INFO "CONFIRMATION" "  $disk_status_icon Espace disque: ${disk_required}GB requis (${disk_available}GB disponible)"
    fi
    
    # Afficher les services et assets
    log INFO "CONFIRMATION" "SERVICES À DÉPLOYER:"
    local services=$(get_pack_services "$pack_id")
    for service in $services; do
        log INFO "CONFIRMATION" "• $service"
    done
    
    # Estimer le temps d'installation
    local estimated_time=$(estimate_installation_time "$pack_id")
    log INFO "CONFIRMATION" "ESTIMATION:"
    log INFO "CONFIRMATION" "  ⏱️  Temps d'installation: ~$estimated_time"
    log INFO "CONFIRMATION" "  🌐 Connexion internet requise pour le téléchargement"
    
    # Vérification NSFW si nécessaire
    if is_pack_nsfw "$pack_id"; then
        log WARN "CONFIRMATION" "⚠️  ATTENTION - CONTENU NSFW"
        log WARN "CONFIRMATION" "Ce pack contient du contenu potentiellement inapproprié (18+)."
        log WARN "CONFIRMATION" "Confirmez-vous avoir 18+ ans et accepter ce contenu ?"
        
        read -p "Confirmation NSFW (y/N): " nsfw_confirm
        if [[ ! "$nsfw_confirm" =~ ^[Yy]$ ]]; then
            log_warn "Installation NSFW refusée par l'utilisateur"
            return 1
        fi
    fi
    
    log INFO "CONFIRMATION" "OPTIONS:"
    log INFO "CONFIRMATION" "  [Y] Confirmer l'installation"
    log INFO "CONFIRMATION" "  [D] Afficher les détails complets"
    log INFO "CONFIRMATION" "  [N] Annuler et retourner au menu"
    
    while true; do
        read -p "Votre choix (Y/d/N): " choice
        case "${choice,,}" in
            y|yes|oui)
                return 0
                ;;
            d|details)
                show_detailed_pack_info "$pack_id"
                read -p "Appuyez sur Entrée pour continuer..."
                enhanced_confirmation_dialog "$title" "$pack_id"
                return $?
                ;;
            n|no|non|"")
                return 1
                ;;
            *)
                log ERROR "CONFIRMATION" "Choix invalide. Utilisez Y, D ou N."
                ;;
        esac
    done
}

# Afficher les détails complets du pack
show_detailed_pack_info() {
    local pack_id="$1"
    
    clear
    log INFO "DETAILS" "DÉTAILS COMPLETS DU PACK"
    log INFO "DETAILS" "$(printf '%.80s' $(printf '%*s' 80 '' | tr ' ' '─'))"
    
    # Informations générales
    local pack_name=$(get_pack_info "$pack_id" "name")
    local pack_description=$(get_pack_info "$pack_id" "description")
    log INFO "DETAILS" "Nom: $pack_name"
    log INFO "DETAILS" "Description: $pack_description"
    
    # Services détaillés
    log INFO "DETAILS" "SERVICES INCLUS:"
    local services=$(get_pack_services "$pack_id")
    for service in $services; do
        case "$service" in
            "comfyui")
                log INFO "DETAILS" "  🎨 ComfyUI - Interface de génération d'images/vidéos avec nodes"
            log INFO "DETAILS" "    Port: 8188 | Interface web pour création visuelle"
                ;;
            "ollama")
                log INFO "DETAILS" "  🧠 Ollama - Serveur de modèles de langage local"
            log INFO "DETAILS" "    Port: 11434 | API REST pour l'IA conversationnelle"
                ;;
            "open-webui")
                log INFO "DETAILS" "  💬 Open WebUI - Interface chat pour les LLMs"
            log INFO "DETAILS" "    Port: 3000 | Interface utilisateur pour Ollama"
                ;;
            "n8n")
                log INFO "DETAILS" "  🔧 n8n - Plateforme d'automatisation workflow"
            log INFO "DETAILS" "    Port: 5678 | Automatisation no-code"
                ;;
            "postgres")
                log INFO "DETAILS" "  🗄️  PostgreSQL - Base de données relationnelle"
            log INFO "DETAILS" "    Port: 5432 | Stockage pour n8n et données"
                ;;
            "redis")
                log INFO "DETAILS" "  ⚡ Redis - Cache et file d'attente en mémoire"
            log INFO "DETAILS" "    Port: 6379 | Cache haute performance"
                ;;
        esac
    done
    
    # Assets détaillés par catégorie
    local categories=("ollama_models" "comfyui_checkpoints" "comfyui_plugins" "comfyui_workflows")
    for category in "${categories[@]}"; do
        local assets=$(get_pack_assets "$pack_id" "$category")
        if [[ -n "$assets" && "$assets" != "null" ]]; then
            log INFO "DETAILS" "$(echo $category | tr '_' ' ' | tr '[:lower:]' '[:upper:]'):"
            for asset in $assets; do
                log INFO "DETAILS" "  • $asset"
            done
        fi
    done
    
    # Estimation de la bande passante requise
    log INFO "DETAILS" "ESTIMATION TÉLÉCHARGEMENTS:"
    log INFO "DETAILS" "  📦 Taille totale: ~${download_size}GB"
    log INFO "DETAILS" "  🌐 Temps (100 Mbps): ~$((download_size * 80 / 100))s"
    log INFO "DETAILS" "  🌐 Temps (10 Mbps): ~$((download_size * 800 / 100))s"
}

# Estimer le temps d'installation
estimate_installation_time() {
    local pack_id="$1"
    local vram_gb=${DETECTED_VRAM_GB:-0}
    
    # Facteurs de temps basés sur la complexité du pack
    local base_time=0
    local services=$(get_pack_services "$pack_id")
    local service_count=$(echo $services | wc -w)
    
    # Temps de base par service (en minutes)
    base_time=$((service_count * 3))
    
    # Ajuster selon les assets
    local assets_count=0
    local categories=("ollama_models" "comfyui_checkpoints" "comfyui_plugins")
    for category in "${categories[@]}"; do
        local assets=$(get_pack_assets "$pack_id" "$category")
        if [[ -n "$assets" && "$assets" != "null" ]]; then
            assets_count=$((assets_count + $(echo $assets | wc -w)))
        fi
    done
    
    # Temps additionnel pour les assets (1min par asset en moyenne)
    base_time=$((base_time + assets_count))
    
    # Ajuster selon la performance GPU (GPU = plus rapide)
    if [[ $vram_gb -gt 8 ]]; then
        base_time=$((base_time * 80 / 100))  # 20% plus rapide avec bon GPU
    fi
    
    # Formater le temps
    if [[ $base_time -lt 60 ]]; then
        echo "${base_time} minutes"
    else
        local hours=$((base_time / 60))
        local minutes=$((base_time % 60))
        echo "${hours}h ${minutes}min"
    fi
}

# Estimer la taille de téléchargement
estimate_download_size() {
    local pack_id="$1"
    local total_size=0
    
    # Tailles approximatives par type de service (en GB)
    local services=$(get_pack_services "$pack_id")
    for service in $services; do
        case "$service" in
            "comfyui") total_size=$((total_size + 5)) ;;  # Images Docker + base
            "ollama") total_size=$((total_size + 2)) ;;   # Runtime
            "open-webui") total_size=$((total_size + 1)) ;;
            "n8n") total_size=$((total_size + 1)) ;;
            "postgres") total_size=$((total_size + 1)) ;;
            "redis") total_size=$((total_size + 1)) ;;
        esac
    done
    
    # Ajouter les tailles des modèles Ollama (approximatives)
    local ollama_models=$(get_pack_assets "$pack_id" "ollama_models")
    if [[ -n "$ollama_models" && "$ollama_models" != "null" ]]; then
        local model_count=$(echo $ollama_models | wc -w)
        total_size=$((total_size + model_count * 4))  # ~4GB par modèle en moyenne
    fi
    
    # Ajouter les tailles des checkpoints ComfyUI
    local checkpoints=$(get_pack_assets "$pack_id" "comfyui_checkpoints")
    if [[ -n "$checkpoints" && "$checkpoints" != "null" ]]; then
        local checkpoint_count=$(echo $checkpoints | wc -w)
        total_size=$((total_size + checkpoint_count * 3))  # ~3GB par checkpoint
    fi
    
    echo "$total_size"
}

# Interface de suivi en temps réel des téléchargements
show_download_monitor() {
    local log_file="$1"
    local total_assets="$2"
    
    log INFO "DOWNLOAD_MONITOR" "📥 SUIVI DES TÉLÉCHARGEMENTS"
    log INFO "DOWNLOAD_MONITOR" "$(printf '%.50s' $(printf '%*s' 50 '' | tr ' ' '─'))"
    
    local completed=0
    local start_time=$(date +%s)
    
    while [[ $completed -lt $total_assets ]]; do
        # Analyser le fichier de log pour les téléchargements terminés
        local new_completed=$(grep -c "Asset.*téléchargé\|Asset.*déjà présent" "$log_file" 2>/dev/null || echo "0")
        
        if [[ $new_completed -gt $completed ]]; then
            completed=$new_completed
            show_deployment_progress "$total_assets" "$completed" "Téléchargement des assets" "$start_time"
        fi
        
        sleep 1
    done
    
    log INFO "DOWNLOAD_MONITOR" "✅ Tous les téléchargements terminés"
}

# Affichage des métriques de performance en temps réel
show_performance_metrics() {
    log INFO "PERFORMANCE_METRICS" "📊 MÉTRIQUES DE PERFORMANCE"
    
    # CPU et mémoire
    if command -v top >/dev/null 2>&1; then
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        log INFO "PERFORMANCE_METRICS" "💻 CPU: ${cpu_usage}%"
    fi
    
    # Utilisation Docker
    if docker info >/dev/null 2>&1; then
        local containers_running=$(docker ps -q | wc -l)
        local containers_total=$(docker ps -aq | wc -l)
        echo -e "  🐳 Conteneurs: $containers_running/$containers_total actifs"
        
        # Utilisation réseau Docker
        local network_usage=$(docker stats --no-stream --format "table {{.NetIO}}" 2>/dev/null | tail -n +2 | head -1)
        if [[ -n "$network_usage" ]]; then
            echo -e "  🌐 Réseau: $network_usage"
        fi
    fi
    
    # GPU si disponible
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1)
        local gpu_memory=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | head -1)
        echo -e "  🎮 GPU: ${gpu_usage}% utilisation"
        echo -e "  🎮 VRAM: $gpu_memory"
    fi
}

# --- SYSTÈME DE RAPPORTS DE SESSION ---

# Génère un rapport complet de session d'installation
generate_session_report() {
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    local report_file="$BASE_DIR/logs/session-report-${timestamp}.md"
    
    # Créer le dossier logs s'il n'existe pas
    mkdir -p "$BASE_DIR/logs"
    
    log_info "REPORT" "Génération du rapport de session"
    
    # En-tête du rapport
    cat > "$report_file" << EOF
# J.A.M.Z.I. AI Stack - Rapport de Session

**Date:** $(date)
**Version:** v52.0 Data-Driven
**Machine:** $(hostname)
**Utilisateur:** $(whoami)

---

## 📊 Configuration Système

### Environnement
- **OS:** $(uname -s) $(uname -r)
- **Architecture:** $(uname -m)
- **WSL Version:** $(wsl.exe --version 2>/dev/null | head -1 || echo "N/A")

### Docker
EOF

    # Informations Docker
    if docker info >/dev/null 2>&1; then
        local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        local compose_version=$(docker compose version --short 2>/dev/null || echo "N/A")
        
        cat >> "$report_file" << EOF
- **Docker Engine:** $docker_version ✅
- **Docker Compose:** $compose_version ✅
- **Status:** Opérationnel
EOF
    else
        cat >> "$report_file" << EOF
- **Docker Engine:** Non accessible ❌
- **Status:** Non opérationnel
EOF
    fi

    # GPU Information
    cat >> "$report_file" << EOF

### GPU & Accélération
EOF

    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -1)
        local gpu_driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1)
        local gpu_memory=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
        local gpu_memory_gb=$((gpu_memory / 1024))
        
        cat >> "$report_file" << EOF
- **GPU:** $gpu_name
- **Driver NVIDIA:** $gpu_driver
- **VRAM:** ${gpu_memory_gb}GB
- **CUDA Support:** $(docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi >/dev/null 2>&1 && echo "✅" || echo "❌")
EOF
    else
        cat >> "$report_file" << EOF
- **GPU:** Non détecté (Mode CPU)
- **CUDA Support:** N/A
EOF
    fi

    # Services déployés
    cat >> "$report_file" << EOF

---

## 🚀 Services Déployés

EOF

    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" >/dev/null 2>&1; then
        local running_services=$(docker ps --format "{{.Names}}" | sort)
        if [[ -n "$running_services" ]]; then
            echo "### Services Actifs" >> "$report_file"
            echo "" >> "$report_file"
            while IFS= read -r service; do
                local status=$(docker inspect --format='{{.State.Status}}' "$service" 2>/dev/null || echo "unknown")
                local health=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "none")
                local ports=$(docker port "$service" 2>/dev/null | tr '\n' ', ' | sed 's/,$//' || echo "N/A")
                
                local status_icon="❓"
                case "$status" in
                    "running") status_icon="🟢" ;;
                    "exited") status_icon="🔴" ;;
                    "paused") status_icon="⏸️" ;;
                esac
                
                local health_info=""
                if [[ "$health" != "none" ]]; then
                    case "$health" in
                        "healthy") health_info=" (✅ Healthy)" ;;
                        "unhealthy") health_info=" (❌ Unhealthy)" ;;
                        "starting") health_info=" (🔄 Starting)" ;;
                    esac
                fi
                
                echo "- $status_icon **$service** - $status$health_info" >> "$report_file"
                [[ "$ports" != "N/A" ]] && echo "  - Ports: \`$ports\`" >> "$report_file"
            done <<< "$running_services"
        else
            echo "Aucun service actif." >> "$report_file"
        fi
    fi

    # Assets et modèles
    cat >> "$report_file" << EOF

---

## 📦 Assets et Modèles

### ComfyUI
EOF

    if [[ -d "$BASE_DIR/data/comfyui/models" ]]; then
        # Compter les modèles par catégorie
        local checkpoints=$(find "$BASE_DIR/data/comfyui/models/checkpoints" -name "*.safetensors" -o -name "*.ckpt" 2>/dev/null | wc -l)
        local vae=$(find "$BASE_DIR/data/comfyui/models/vae" -name "*.safetensors" -o -name "*.ckpt" 2>/dev/null | wc -l)
        local loras=$(find "$BASE_DIR/data/comfyui/models/loras" -name "*.safetensors" 2>/dev/null | wc -l)
        local controlnet=$(find "$BASE_DIR/data/comfyui/models/controlnet" -name "*.safetensors" 2>/dev/null | wc -l)
        local upscale=$(find "$BASE_DIR/data/comfyui/models/upscale_models" -name "*.pth" 2>/dev/null | wc -l)
        
        cat >> "$report_file" << EOF
- **Checkpoints:** $checkpoints modèles
- **VAE:** $vae modèles
- **LoRAs:** $loras modèles
- **ControlNet:** $controlnet modèles
- **Upscale:** $upscale modèles
EOF

        # Plugins ComfyUI
        if [[ -d "$BASE_DIR/data/comfyui/custom_nodes" ]]; then
            local plugins=$(find "$BASE_DIR/data/comfyui/custom_nodes" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
            echo "- **Plugins/Nodes:** $plugins installés" >> "$report_file"
        fi
    else
        echo "- ComfyUI non configuré" >> "$report_file"
    fi

    # Modèles Ollama
    cat >> "$report_file" << EOF

### Ollama
EOF

    if docker ps --format "{{.Names}}" | grep -q "ollama"; then
        local ollama_models=$(docker exec ollama ollama list 2>/dev/null | grep -v "NAME" | wc -l || echo "0")
        echo "- **Modèles LLM:** $ollama_models installés" >> "$report_file"
        
        if [[ $ollama_models -gt 0 ]]; then
            echo "" >> "$report_file"
            echo "**Liste des modèles:**" >> "$report_file"
            docker exec ollama ollama list 2>/dev/null | tail -n +2 | while IFS= read -r line; do
                local model_name=$(echo "$line" | awk '{print $1}')
                local model_size=$(echo "$line" | awk '{print $2}')
                echo "- \`$model_name\` ($model_size)" >> "$report_file"
            done
        fi
    else
        echo "- Ollama non actif" >> "$report_file"
    fi

    # Utilisation de l'espace disque
    cat >> "$report_file" << EOF

---

## 💾 Utilisation de l'Espace

### Espace Disque
EOF

    local total_space=$(df -h "$BASE_DIR" | tail -1 | awk '{print $2}')
    local used_space=$(df -h "$BASE_DIR" | tail -1 | awk '{print $3}')
    local available_space=$(df -h "$BASE_DIR" | tail -1 | awk '{print $4}')
    local use_percent=$(df -h "$BASE_DIR" | tail -1 | awk '{print $5}')

    cat >> "$report_file" << EOF
- **Total:** $total_space
- **Utilisé:** $used_space ($use_percent)
- **Disponible:** $available_space
EOF

    # Espace Docker
    if docker system df >/dev/null 2>&1; then
        cat >> "$report_file" << EOF

### Espace Docker
EOF
        local docker_df_output=$(docker system df 2>/dev/null)
        echo "\`\`\`" >> "$report_file"
        echo "$docker_df_output" >> "$report_file"
        echo "\`\`\`" >> "$report_file"
    fi

    # Logs récents
    cat >> "$report_file" << EOF

---

## 📋 Logs et Historique

### Logs de Session
EOF

    if [[ -d "$BASE_DIR/logs" ]]; then
        local log_count=$(find "$BASE_DIR/logs" -name "*.log" -type f | wc -l)
        echo "- **Fichiers de logs:** $log_count" >> "$report_file"
        
        # Derniers logs d'erreur
        local recent_errors=$(find "$BASE_DIR/logs" -name "*.log" -type f -exec grep -l "ERROR\|FAIL" {} \; 2>/dev/null | wc -l)
        if [[ $recent_errors -gt 0 ]]; then
            echo "- **Logs avec erreurs:** $recent_errors fichiers" >> "$report_file"
        fi
    else
        echo "- Aucun système de logs configuré" >> "$report_file"
    fi

    # Configuration actuelle
    cat >> "$report_file" << EOF

### Configuration Active
EOF

    if [[ -f "$BASE_DIR/data/pack-registry.json" ]]; then
        echo "- **Configuration packs:** Data-driven JSON ✅" >> "$report_file"
    else
        echo "- **Configuration packs:** Configuration manuelle" >> "$report_file"
    fi

    if [[ -f "$BASE_DIR/docker-compose.yml" ]]; then
        local services_count=$(grep -c "^  [a-zA-Z]" "$BASE_DIR/docker-compose.yml" || echo "0")
        echo "- **Services Docker Compose:** $services_count définis" >> "$report_file"
    fi

    # Recommandations
    cat >> "$report_file" << EOF

---

## 🎯 Recommandations

EOF

    # Analyser et donner des recommandations
    local recommendations=()
    
    # Vérification GPU
    if ! command -v nvidia-smi >/dev/null 2>&1; then
        recommendations+=("🎮 **GPU Support:** Installer les drivers NVIDIA pour de meilleures performances")
    fi
    
    # Vérification espace disque
    local disk_usage=$(df "$BASE_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 80 ]]; then
        recommendations+=("💾 **Espace disque:** Espace disque faible ($disk_usage% utilisé) - considérer un nettoyage")
    fi
    
    # Services arrêtés
    local stopped_containers=$(docker ps -a -f "status=exited" -q 2>/dev/null | wc -l)
    if [[ $stopped_containers -gt 0 ]]; then
        recommendations+=("🐳 **Docker:** $stopped_containers conteneurs arrêtés peuvent être nettoyés")
    fi
    
    # Afficher les recommandations
    if [[ ${#recommendations[@]} -gt 0 ]]; then
        for rec in "${recommendations[@]}"; do
            echo "- $rec" >> "$report_file"
        done
    else
        echo "- ✅ Système optimalement configuré" >> "$report_file"
    fi

    # Actions rapides
    cat >> "$report_file" << EOF

---

## ⚡ Actions Rapides

### Commandes Utiles
\`\`\`bash
# Voir les services actifs
docker ps

# Arrêter tous les services
docker compose down

# Redémarrer les services
docker compose up -d

# Voir les logs d'un service
docker compose logs -f [service]

# Nettoyer Docker
./deploy.sh (option 90)

# Validation complète
./verify_deployment.sh
\`\`\`

### URLs d'Accès
EOF

    # URLs des services actifs
    local service_urls=()
    if docker ps --format "{{.Names}}" | grep -q "comfyui"; then
        service_urls+=("- **ComfyUI:** http://localhost:8188")
    fi
    if docker ps --format "{{.Names}}" | grep -q "open-webui"; then
        service_urls+=("- **Open WebUI:** http://localhost:3000")
    fi
    if docker ps --format "{{.Names}}" | grep -q "n8n"; then
        service_urls+=("- **n8n:** http://localhost:5678")
    fi
    
    if [[ ${#service_urls[@]} -gt 0 ]]; then
        for url in "${service_urls[@]}"; do
            echo "$url" >> "$report_file"
        done
    else
        echo "- Aucun service web actif" >> "$report_file"
    fi

    # Pied de page
    cat >> "$report_file" << EOF

---

**Rapport généré automatiquement par J.A.M.Z.I. AI Stack v52.0**
*Pour plus d'informations: ./deploy.sh*
EOF

    log_ok "Rapport de session généré: $report_file"
    echo "$report_file"
}

# Génère un rapport rapide en mode console
generate_quick_status_report() {
    echo -e "\n${C_CYAN}${C_BOLD}📊 RAPPORT D'ÉTAT RAPIDE${C_RESET}"
    echo -e "${C_DIM}$(printf '%.50s' $(printf '%*s' 50 '' | tr ' ' '─'))${C_RESET}"
    
    # Services Docker
    local running_services=$(docker ps --format "{{.Names}}" 2>/dev/null | wc -l)
    local total_containers=$(docker ps -a -q 2>/dev/null | wc -l)
    echo -e "  🐳 Services: ${C_BOLD}$running_services/$total_containers${C_RESET} actifs"
    
    # GPU
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -1 | cut -c1-30)
        local gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1)
        echo -e "  🎮 GPU: ${C_BOLD}$gpu_name${C_RESET} (${gpu_usage}% utilisé)"
    else
        echo -e "  🎮 GPU: ${C_DIM}Mode CPU${C_RESET}"
    fi
    
    # Espace disque
    local disk_usage=$(df -h "$BASE_DIR" | tail -1 | awk '{print $5}')
    local disk_available=$(df -h "$BASE_DIR" | tail -1 | awk '{print $4}')
    echo -e "  💾 Disque: ${C_BOLD}$disk_usage${C_RESET} utilisé, $disk_available disponible"
    
    # Modèles
    local comfyui_models=0
    local ollama_models=0
    
    if [[ -d "$BASE_DIR/data/comfyui/models" ]]; then
        comfyui_models=$(find "$BASE_DIR/data/comfyui/models" -name "*.safetensors" -o -name "*.ckpt" 2>/dev/null | wc -l)
    fi
    
    if docker ps --format "{{.Names}}" | grep -q "ollama"; then
        ollama_models=$(docker exec ollama ollama list 2>/dev/null | grep -v "NAME" | wc -l || echo "0")
    fi
    
    echo -e "  📦 Modèles: ${C_BOLD}$comfyui_models${C_RESET} ComfyUI, ${C_BOLD}$ollama_models${C_RESET} Ollama"
    
    # Status global
    local status_color="$C_GREEN"
    local status_message="Opérationnel"
    
    if [[ $running_services -eq 0 ]]; then
        status_color="$C_RED"
        status_message="Aucun service actif"
    elif [[ $running_services -lt $((total_containers / 2)) ]]; then
        status_color="$C_YELLOW"
        status_message="Partiellement actif"
    fi
    
    echo -e "${C_DIM}$(printf '%.50s' $(printf '%*s' 50 '' | tr ' ' '─'))${C_RESET}"
    echo -e "  ${status_color}Status: $status_message${C_RESET}"
}