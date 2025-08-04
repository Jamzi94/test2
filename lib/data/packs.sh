#!/bin/bash
# ==============================================================================
#      JAMZI AI STACK - MODULE PACKS DATA-DRIVEN
# ==============================================================================
# Système de gestion des packs basé sur configuration JSON

PACK_REGISTRY_FILE="$BASE_DIR/data/pack-registry.json"
ASSET_CATALOGUE_FILE="$BASE_DIR/data/asset-catalogue.json"

# --- FONCTIONS DE LECTURE PACK REGISTRY ---

# Obtenir les informations d'un asset
get_asset_info() {
    local asset_category="$1"
    local asset_name="$2"

    check_json_parser

    if [[ ! -f "$ASSET_CATALOGUE_FILE" ]]; then
        log_error "Fichier asset-catalogue.json introuvable : $ASSET_CATALOGUE_FILE"
        return 1
    fi

    parse_json ".$asset_category.\"$asset_name\"" "$ASSET_CATALOGUE_FILE"
}


# Vérifier si yq est disponible
check_json_parser() {
    # Vérifier yq (local ou système)
    if [[ -f "$BASE_DIR/yq.exe" ]]; then
        export YQ_CMD="$BASE_DIR/yq.exe"
    elif command -v yq >/dev/null 2>&1; then
        export YQ_CMD="yq"
    else
        log_error "PACKS" "yq n'est pas installé. Veuillez l'installer pour continuer."
        return 1
    fi
    
    # Vérifier jq (local ou système)
    if [[ -f "$BASE_DIR/jq.exe" ]]; then
        export JQ_CMD="$BASE_DIR/jq.exe"
    elif command -v jq >/dev/null 2>&1; then
        export JQ_CMD="jq"
    else
        log_error "PACKS" "jq n'est pas installé. Veuillez l'installer pour continuer."
        return 1
    fi
}

# Parser JSON avec yq
parse_json() {
    local query="$1"
    local file="$2"
    
    # Timeout pour éviter les blocages
    timeout 10 "$YQ_CMD" e "$query" "$file" -r 2>/dev/null || echo "null"
}

# Obtenir les informations d'un pack par ID ou nom
get_pack_info() {
    local pack_identifier="$1"
    local field="$2"
    
    check_json_parser
    
    if [[ ! -f "$PACK_REGISTRY_FILE" ]]; then
        log_error "Fichier pack-registry.json introuvable : $PACK_REGISTRY_FILE"
        return 1
    fi
    
    # Chercher par ID numérique
    if [[ "$pack_identifier" =~ ^[0-9]+$ ]]; then
        local pack_key=$(parse_json '.packs | to_entries[] | select(.value.id == '$pack_identifier') | .key' "$PACK_REGISTRY_FILE")
    else
        # Chercher par nom de clé
        local pack_key="$pack_identifier"
    fi
    
    if [[ -z "$pack_key" || "$pack_key" == "null" ]]; then
        log_error "Pack non trouvé : $pack_identifier"
        return 1
    fi
    
    if [[ -n "$field" ]]; then
        parse_json ".packs.\"$pack_key\".$field" "$PACK_REGISTRY_FILE"
    else
        parse_json ".packs.\"$pack_key\"" "$PACK_REGISTRY_FILE"
    fi
}

# Lister tous les packs disponibles
list_available_packs() {
    check_json_parser
    parse_json '.packs | keys[]' "$PACK_REGISTRY_FILE"
}

# Obtenir les services d'un pack
get_pack_services() {
    local pack_id="$1"
    get_pack_info "$pack_id" "services"
}

# Obtenir les assets d'un pack
get_pack_assets() {
    local pack_id="$1"
    local asset_type="$2"
    
    if [[ -n "$asset_type" ]]; then
        get_pack_info "$pack_id" "assets.$asset_type"
    else
        get_pack_info "$pack_id" "assets"
    fi
}

# Obtenir les exigences d'un pack
get_pack_requirements() {
    local pack_id="$1"
    local requirement="$2"
    
    if [[ -n "$requirement" ]]; then
        get_pack_info "$pack_id" "requirements.$requirement"
    else
        get_pack_info "$pack_id" "requirements"
    fi
}

# Vérifier si un pack est NSFW
is_pack_nsfw() {
    local pack_id="$1"
    local nsfw_flag=$(get_pack_info "$pack_id" "nsfw")
    [[ "$nsfw_flag" == "true" ]]
}

# --- FONCTIONS DE CONFIGURATION DYNAMIQUE ---

# Charger la configuration d'un pack dans les variables globales
load_pack_configuration() {
    local pack_id="$1"
    
    # Vérifier et configurer les outils JSON
    check_json_parser
    
    log_header "CHARGEMENT CONFIGURATION PACK $pack_id"
    
    # Obtenir les informations du pack
    local pack_name=$(get_pack_info "$pack_id" "name")
    local pack_description=$(get_pack_info "$pack_id" "description")
    
    if [[ -z "$pack_name" || "$pack_name" == "null" ]]; then
        log_error "Pack $pack_id non trouvé dans la registry"
        return 1
    fi
    
    log INFO "PACKS" "Pack: $pack_name"
    log INFO "PACKS" "Description: $pack_description"
    
    # Charger les services
    local raw_services=$(get_pack_services "$pack_id")
    if [[ "$raw_services" == "null" || -z "$raw_services" ]]; then
        SELECTED_SERVICES=""
    else
        SELECTED_SERVICES=$(echo "$raw_services" | "$YQ_CMD" e '.[]' -r | tr '\n' ' ' | sed 's/ *$//')
    fi
    
    # Charger les assets
    local raw_ollama_models=$(get_pack_assets "$pack_id" "ollama_models")
    if [[ "$raw_ollama_models" == "null" || -z "$raw_ollama_models" ]]; then
        SELECTED_MODELS_OLLAMA=""
    else
        SELECTED_MODELS_OLLAMA=$(echo "$raw_ollama_models" | "$YQ_CMD" e '.[]' -r | tr '\n' ' ' | sed 's/ *$//')
    fi
    local raw_checkpoints=$(get_pack_assets "$pack_id" "comfyui_checkpoints")
    if [[ "$raw_checkpoints" == "null" || -z "$raw_checkpoints" ]]; then
        SELECTED_MODELS_CHECKPOINTS=""
    else
        SELECTED_MODELS_CHECKPOINTS=$(echo "$raw_checkpoints" | "$YQ_CMD" e '.[]' -r | tr '\n' ' ' | sed 's/ *$//')
    fi
    local raw_vae=$(get_pack_assets "$pack_id" "comfyui_vae")
    if [[ "$raw_vae" == "null" || -z "$raw_vae" ]]; then
        SELECTED_MODELS_VAE=""
    else
        SELECTED_MODELS_VAE=$(echo "$raw_vae" | "$YQ_CMD" e '.[]' -r | tr '\n' ' ' | sed 's/ *$//')
    fi
    local raw_controlnet=$(get_pack_assets "$pack_id" "comfyui_controlnet")
    if [[ "$raw_controlnet" == "null" || -z "$raw_controlnet" ]]; then
        SELECTED_MODELS_CONTROLNET=""
    else
        SELECTED_MODELS_CONTROLNET=$(echo "$raw_controlnet" | "$YQ_CMD" e '.[]' -r | tr '\n' ' ' | sed 's/ *$//')
    fi
    local raw_upscale=$(get_pack_assets "$pack_id" "comfyui_upscale")
    if [[ "$raw_upscale" == "null" || -z "$raw_upscale" ]]; then
        SELECTED_MODELS_UPSCALE=""
    else
        SELECTED_MODELS_UPSCALE=$(echo "$raw_upscale" | "$YQ_CMD" e '.[]' -r | tr '\n' ' ' | sed 's/ *$//')
    fi
    local raw_gfpgan=$(get_pack_assets "$pack_id" "comfyui_gfpgan")
    if [[ "$raw_gfpgan" == "null" || -z "$raw_gfpgan" ]]; then
        SELECTED_MODELS_GFPGAN=""
    else
        SELECTED_MODELS_GFPGAN=$(echo "$raw_gfpgan" | "$YQ_CMD" e '.[]' -r | tr '\n' ' ' | sed 's/ *$//')
    fi
    local raw_wav2lip=$(get_pack_assets "$pack_id" "comfyui_wav2lip")
    if [[ "$raw_wav2lip" == "null" || -z "$raw_wav2lip" ]]; then
        SELECTED_MODELS_WAV2LIP=""
    else
        SELECTED_MODELS_WAV2LIP=$(echo "$raw_wav2lip" | "$YQ_CMD" e '.[]' -r | tr '\n' ' ' | sed 's/ *$//')
    fi
    local raw_loras=$(get_pack_assets "$pack_id" "comfyui_loras")
    if [[ "$raw_loras" == "null" || -z "$raw_loras" ]]; then
        SELECTED_MODELS_LORAS=""
    else
        SELECTED_MODELS_LORAS=$(echo "$raw_loras" | "$YQ_CMD" e '.[]' -r | tr '\n' ' ' | sed 's/ *$//')
    fi
    local raw_clip=$(get_pack_assets "$pack_id" "comfyui_clip")
    if [[ "$raw_clip" == "null" || -z "$raw_clip" ]]; then
        SELECTED_MODELS_CLIP=""
    else
        SELECTED_MODELS_CLIP=$(echo "$raw_clip" | "$YQ_CMD" e '.[]' -r | tr '\n' ' ' | sed 's/ *$//')
    fi
    local raw_unet=$(get_pack_assets "$pack_id" "comfyui_unet")
    if [[ "$raw_unet" == "null" || -z "$raw_unet" ]]; then
        SELECTED_MODELS_UNET=""
    else
        SELECTED_MODELS_UNET=$(echo "$raw_unet" | "$YQ_CMD" e '.[]' -r | tr '\n' ' ' | sed 's/ *$//')
    fi
    local raw_plugins_comfyui=$(get_pack_assets "$pack_id" "comfyui_plugins")
    if [[ "$raw_plugins_comfyui" == "null" || -z "$raw_plugins_comfyui" ]]; then
        SELECTED_PLUGINS_COMFYUI=""
    else
        SELECTED_PLUGINS_COMFYUI=$(echo "$raw_plugins_comfyui" | "$YQ_CMD" e '.[]' -r | tr '\n' ' ' | sed 's/ *$//')
    fi
    local raw_workflows_comfyui=$(get_pack_assets "$pack_id" "comfyui_workflows")
    if [[ "$raw_workflows_comfyui" == "null" || -z "$raw_workflows_comfyui" ]]; then
        SELECTED_WORKFLOWS_COMFYUI=""
    else
        SELECTED_WORKFLOWS_COMFYUI=$(echo "$raw_workflows_comfyui" | "$YQ_CMD" e '.[]' -r | tr '\n' ' ' | sed 's/ *$//')
    fi
    local raw_workflows_n8n=$(get_pack_assets "$pack_id" "n8n_workflows")
    if [[ "$raw_workflows_n8n" == "null" || -z "$raw_workflows_n8n" ]]; then
        SELECTED_WORKFLOWS_N8N=""
    else
        SELECTED_WORKFLOWS_N8N=$(echo "$raw_workflows_n8n" | "$YQ_CMD" e '.[]' -r | tr '\n' ' ' | sed 's/ *$//')
    fi

    log INFO "PACKS" "Services: $SELECTED_SERVICES"
    
    # Debug: Afficher toutes les variables d'assets chargées
    echo "DEBUG: SELECTED_MODELS_CHECKPOINTS: $SELECTED_MODELS_CHECKPOINTS"
    echo "DEBUG: SELECTED_MODELS_VAE: $SELECTED_MODELS_VAE"
    echo "DEBUG: SELECTED_MODELS_CLIP: $SELECTED_MODELS_CLIP"
    echo "DEBUG: SELECTED_MODELS_UNET: $SELECTED_MODELS_UNET"
    echo "DEBUG: SELECTED_MODELS_UPSCALE: $SELECTED_MODELS_UPSCALE"
    echo "DEBUG: SELECTED_MODELS_GFPGAN: $SELECTED_MODELS_GFPGAN"
    echo "DEBUG: SELECTED_WORKFLOWS_COMFYUI: $SELECTED_WORKFLOWS_COMFYUI"
    
    # Vérification NSFW
    if is_pack_nsfw "$pack_id"; then
        log_warn "Ce pack contient du contenu potentiellement NSFW."
        read -p "Confirmez-vous le téléchargement de contenu NSFW ? (y/n) " -n 1 -r; echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warn "Déploiement du pack NSFW annulé."
            return 1
        fi
    fi
    
    # Afficher un résumé des assets chargés
    local asset_count=0
    [[ -n "$SELECTED_MODELS_OLLAMA" && "$SELECTED_MODELS_OLLAMA" != "null" ]] && ((asset_count++))
    [[ -n "$SELECTED_MODELS_CHECKPOINTS" && "$SELECTED_MODELS_CHECKPOINTS" != "null" ]] && ((asset_count++))
    [[ -n "$SELECTED_PLUGINS_COMFYUI" && "$SELECTED_PLUGINS_COMFYUI" != "null" ]] && ((asset_count++))
    
    log INFO "PACKS" "Assets configurés: $asset_count types d'assets"
    
    log_ok "Configuration du pack $pack_id chargée avec succès"
    return 0
}

# Valider les exigences d'un pack par rapport au système
validate_pack_requirements() {
    local pack_id="$1"
    local vram_required=$(get_pack_requirements "$pack_id" "vram_gb")
    local disk_required=$(get_pack_requirements "$pack_id" "disk_gb")
    
    log_header "VALIDATION DES EXIGENCES PACK $pack_id"
    
    local validation_errors=0
    
    # Vérification VRAM
    if [[ -n "$vram_required" && "$vram_required" != "null" ]]; then
        local vram_available="${DETECTED_VRAM_GB:-0}"
        if [[ $vram_available -lt $vram_required ]]; then
            log_warn "VRAM insuffisante: ${vram_available}GB disponible, ${vram_required}GB requis"
            log INFO "PACKS" "Le pack fonctionnera en mode CPU (plus lent)"
        else
            log_ok "VRAM suffisante: ${vram_available}GB >= ${vram_required}GB"
        fi
    fi
    
    # Vérification espace disque
    if [[ -n "$disk_required" && "$disk_required" != "null" ]]; then
        local disk_available=$(df "$BASE_DIR" | tail -1 | awk '{print int($4/1024/1024)}')
        if [[ $disk_available -lt $disk_required ]]; then
            log ERROR "PACKS" "Espace disque insuffisant: ${disk_available}GB disponible, ${disk_required}GB requis"
            ((validation_errors++))
        else
            log INFO "PACKS" "Espace disque suffisant: ${disk_available}GB >= ${disk_required}GB"
        fi
    fi
    
    if [[ $validation_errors -gt 0 ]]; then
        log_error "Validation échouée pour le pack $pack_id"
        return 1
    fi
    
    log_ok "Toutes les exigences du pack $pack_id sont satisfaites"
    return 0
}

# Afficher le menu des packs basé sur le JSON
display_pack_menu() {
    check_json_parser
    
    log_header "PACKS DISPONIBLES"
    
    # Lire tous les packs depuis le JSON
    local pack_keys=($(list_available_packs))
    
    for pack_key in "${pack_keys[@]}"; do
        local pack_id=$(get_pack_info "$pack_key" "id")
        local pack_name=$(get_pack_info "$pack_key" "name")
        local pack_description=$(get_pack_info "$pack_key" "description")
        local vram_required=$(get_pack_requirements "$pack_key" "vram_gb")
        local nsfw_flag=$(get_pack_info "$pack_key" "nsfw")
        
        # Icône de compatibilité
        local compat_icon=$(get_compatibility_icon "$vram_required")
        
        # Indicateur NSFW
        local nsfw_indicator=""
        [[ "$nsfw_flag" == "true" ]] && nsfw_indicator=" ${C_RED}(NSFW)${C_RESET}"
        
        local compat_icon_colored=""
        case "$compat_icon" in
            "✅") compat_icon_colored="${C_GREEN}✅${C_RESET}" ;;
            "⚠️") compat_icon_colored="${C_YELLOW}⚠️${C_RESET}" ;;
            "❌") compat_icon_colored="${C_RED}❌${C_RESET}" ;;
            *)
                compat_icon_colored="$compat_icon"
                ;;
        esac
        
        printf "  $compat_icon_colored %2s. %s %s%s\n" "$pack_id" "$pack_name" "${C_DIM}$pack_description${C_RESET}" "$nsfw_indicator"
    done
}