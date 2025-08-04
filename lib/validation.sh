#!/bin/bash
# ==============================================================================
#      JAMZI AI STACK - MODULE VALIDATION
# ==============================================================================
# Fonctions de validation et génération de fichiers

# --- VALIDATION ET GÉNÉRATION ---

# Génère les fichiers de configuration essentiels (docker-compose, Dockerfiles, etc.)
generate_all_files() {
    
    log_header "PHASE 2 : GÉNÉRATION DES FICHIERS DE CONFIGURATION"
    log DEBUG "VALIDATION" "Début de generate_all_files"
    
    # Vérification SELECTED_SERVICES non vide
    if [[ -z "${SELECTED_SERVICES:-}" ]]; then
        log_error "Aucun service sélectionné. Impossible de continuer."
        return 1
    fi
    
    # Ajouter postgres et redis automatiquement si n8n est présent
    if [[ " $SELECTED_SERVICES " =~ " n8n " ]]; then
        if [[ ! " $SELECTED_SERVICES " =~ " postgres " ]]; then
            log DEBUG "VALIDATION" "Ajout automatique de postgres pour n8n"
            SELECTED_SERVICES="$SELECTED_SERVICES postgres"
        fi
        if [[ ! " $SELECTED_SERVICES " =~ " redis " ]]; then
            log DEBUG "VALIDATION" "Ajout automatique de redis pour n8n"
            SELECTED_SERVICES="$SELECTED_SERVICES redis"
        fi
    fi
    
    log DEBUG "VALIDATION" "Services sélectionnés: $SELECTED_SERVICES"
    
    # --- Génération docker-compose.yml ---
    log INFO "VALIDATION" "Assemblage du fichier docker-compose.yml..."
    log DEBUG "VALIDATION" "Génération de docker-compose.yml"
    
    # Fusionner les fichiers de service avec yq
    local service_files=()
    for service in $SELECTED_SERVICES; do
        service_files+=("$BASE_DIR/templates/services/${service}.yml")
        log DEBUG "VALIDATION" "Ajout du service template: $BASE_DIR/templates/services/${service}.yml"
    done

    # Méthode de fusion simple avec cat
    cat "$BASE_DIR/templates/docker-compose.header.yml" > "$BASE_DIR/docker-compose.yml"
    for service_file in "${service_files[@]}"; do
        cat "$service_file" >> "$BASE_DIR/docker-compose.yml"
    done
    cat "$BASE_DIR/templates/docker-compose.footer.yml" >> "$BASE_DIR/docker-compose.yml"
    log DEBUG "VALIDATION" "docker-compose.yml généré initialement"

    # Appliquer les personnalisations de chemins
    if [[ -n "$SELECTED_COMFYUI_MODELS_HOST_PATH" ]]; then
        log DEBUG "VALIDATION" "Personnalisation du chemin ComfyUI"
        "$YQ_CMD" e -i '.services.comfyui.volumes = ["$SELECTED_COMFYUI_MODELS_HOST_PATH:/app/models"]' "$BASE_DIR/docker-compose.yml"
    fi
    if [[ -n "$SELECTED_OLLAMA_HOST_PATH" ]]; then
        log DEBUG "VALIDATION" "Personnalisation du chemin Ollama"
        "$YQ_CMD" e -i '.services.ollama.volumes = ["$SELECTED_OLLAMA_HOST_PATH:/root/.ollama"]' "$BASE_DIR/docker-compose.yml"
    fi
    if [[ -n "$SELECTED_N8N_HOST_PATH" ]]; then
        log DEBUG "VALIDATION" "Personnalisation du chemin n8n"
        "$YQ_CMD" e -i '.services.n8n.volumes = ["$SELECTED_N8N_HOST_PATH:/home/node/.n8n"]' "$BASE_DIR/docker-compose.yml"
    fi

    # Nettoyer les dépendances vers des services non sélectionnés
    if [[ " $SELECTED_SERVICES " =~ " n8n " ]]; then
        if [[ ! " $SELECTED_SERVICES " =~ " ollama " ]]; then
            log DEBUG "VALIDATION" "Nettoyage dépendance Ollama pour n8n"
            "$YQ_CMD" e -i 'del(.services.n8n.depends_on.ollama)' "$BASE_DIR/docker-compose.yml"
            "$YQ_CMD" e -i 'del(.services.n8n.environment.OLLAMA_API_URL)' "$BASE_DIR/docker-compose.yml"
        fi
        if [[ ! " $SELECTED_SERVICES " =~ " comfyui " ]]; then
            log DEBUG "VALIDATION" "Nettoyage dépendance ComfyUI pour n8n"
            "$YQ_CMD" e -i 'del(.services.n8n.depends_on.comfyui)' "$BASE_DIR/docker-compose.yml"
            "$YQ_CMD" e -i 'del(.services.n8n.environment.COMFYUI_API_URL)' "$BASE_DIR/docker-compose.yml"
        fi
    fi

    log INFO "VALIDATION" "docker-compose.yml généré pour les services : $SELECTED_SERVICES"
    log INFO "VALIDATION" "docker-compose.yml finalisé"

    # --- Génération .gitignore ---
    log INFO "VALIDATION" "Génération du .gitignore..."
    log INFO "VALIDATION" "Génération de .gitignore"
    cp "$BASE_DIR/templates/gitignore.template" "$BASE_DIR/.gitignore"
    log INFO "VALIDATION" ".gitignore généré."
    log INFO "VALIDATION" ".gitignore finalisé"

    # --- Génération config.ini pour ComfyUI Manager ---
    log INFO "VALIDATION" "Génération du config.ini pour ComfyUI Manager..."
    log INFO "VALIDATION" "Génération de config.ini"
    mkdir -p "$BASE_DIR/builders/comfyui"
    cp "$BASE_DIR/templates/config.ini.template" "$BASE_DIR/builders/comfyui/config.ini"
    log INFO "VALIDATION" "config.ini pour ComfyUI Manager généré."
    log INFO "VALIDATION" "config.ini finalisé"

    # --- Génération Dockerfiles ---
    log INFO "VALIDATION" "Génération des Dockerfiles pour les services activés..."
    log INFO "VALIDATION" "Génération des Dockerfiles"
    for service in $SELECTED_SERVICES; do
                                        local dockerfile_template="$BASE_DIR/templates/${service}.Dockerfile.template"
        local dockerfile_target="$BASE_DIR/builders/$service/Dockerfile"
        
        if [[ -f "$dockerfile_template" ]]; then
            mkdir -p "$(dirname "$dockerfile_target")"
            cp "$dockerfile_template" "$dockerfile_target"
            log INFO "VALIDATION" "Dockerfile pour '$service' généré."
        else
            log DEBUG "VALIDATION" "Dockerfile template non trouvé pour $service: $dockerfile_template"
        fi
    done
    log INFO "VALIDATION" "Tous les Dockerfiles générés."
        log INFO "VALIDATION" "Dockerfiles finalisé"
    
}

# Validation de compatibilité GPU
get_compatibility_icon() {
    local required_vram="$1"
    local detected_vram="${DETECTED_VRAM_GB:-0}"
    
    if [[ -z "$DETECTED_GPU_NAME" ]]; then
        echo "❌" # Pas de GPU détecté
    elif [[ "$detected_vram" -ge "$required_vram" ]]; then
        echo "✅" # Compatible
    else
        echo "⚠️" # Limite
    fi
}

# Validation système complète


# Validation post-déploiement
validate_deployment() {
    log_header "VALIDATION POST-DÉPLOIEMENT"
    
    local healthy_services=0
    local total_services=0
    
    for service in $SELECTED_SERVICES; do
        ((total_services++))
        
        local status=$(docker compose ps --format "table {{.Service}}\t{{.Status}}" | grep "^$service" | awk '{print $2}' || echo "absent")
        
        case "$status" in
            "running"|"Up")
                log_ok "Service '$service': opérationnel"
                ((healthy_services++))
                ;;
            "exited"|"unhealthy")
                log_error "Service '$service': défaillant ($status)"
                ;;
            "starting")
                log_warn "Service '$service': en cours de démarrage"
                ;;
            *)
                log_warn "Service '$service': statut inconnu ($status)"
                ;;
        esac
    done
    
    echo -e "\n${C_BLUE}${C_BOLD}RÉSUMÉ DU DÉPLOIEMENT:${C_RESET}"
    echo -e "  Services opérationnels: ${C_GREEN}$healthy_services${C_RESET}/$total_services"
    
    if [[ $healthy_services -eq $total_services ]]; then
        echo -e "  ${C_GREEN}✅ Déploiement réussi${C_RESET}"
        return 0
    else
        echo -e "  ${C_YELLOW}⚠️  Déploiement partiel${C_RESET}"
        return 1
    fi
}