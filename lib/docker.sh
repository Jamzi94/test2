#!/bin/bash
# ==============================================================================
#      JAMZI AI STACK - MODULE DOCKER
# ==============================================================================
# Fonctions de gestion Docker et conteneurs

# --- GESTION DOCKER ---
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

# Lance la stack Docker avec les services sélectionnés
launch_stack() {
    log_header "PHASE 4 : LANCEMENT DE LA STACK DOCKER"
    
    if [[ -z "${SELECTED_SERVICES:-}" ]]; then
        log_error "Aucun service sélectionné."
    fi
    
    # Construction de la commande Docker Compose avec les profils
    local profile_args=""
    local profile_list=""
    local profiles_used=""
    
    # Mapping des services vers leurs profils
    for service in $SELECTED_SERVICES; do
        local service_profiles=""
        case "$service" in
            "ollama"|"open-webui"|"comfyui")
                service_profiles="core"
                ;;
            "n8n"|"postgres"|"redis")
                service_profiles="automation"
                ;;
            *)
                service_profiles="$service"  # fallback au nom du service
                ;;
        esac
        
        # Ajouter les profils (éviter les doublons)
        for profile in $service_profiles; do
            if [[ ! " $profiles_used " =~ " $profile " ]]; then
                profiles_used="$profiles_used $profile"
                if [[ -n "$profile_args" ]]; then
                    profile_args="$profile_args --profile $profile"
                    profile_list="$profile_list, $profile"
                else
                    profile_args="--profile $profile"
                    profile_list="$profile"
                fi
            fi
        done
    done
    
    log INFO "DOCKER" "Construction et démarrage des conteneurs en arrière-plan..."
    log INFO "DOCKER" "Cette opération peut prendre plusieurs minutes lors du premier lancement."
    log INFO "DOCKER" "Profils activés: $profile_list"
    
    # Lancer Docker Compose avec les profils appropriés
    cd "$BASE_DIR"
    if [[ -n "$profile_args" ]]; then
        docker compose $profile_args up --build -d
    else
        docker compose up --build -d
    fi
    
    log_ok "Tous les services sélectionnés sont en cours de démarrage."
}



# Synchronise les modèles Ollama après le démarrage du service
sync_ollama_models() {
    # Vérifier si ollama est dans la liste des services sélectionnés
    if [[ " $SELECTED_SERVICES " =~ " ollama " && -n "$SELECTED_MODELS_OLLAMA" ]]; then
        log_header "PHASE 5 : SYNCHRONISATION DES MODÈLES OLLAMA"
        log INFO "OLLAMA" "Attente de la disponibilité du service Ollama..."
        
        local spinner_chars=("-" \\ "|" "/")
        local i=0
        TIMEOUT=300; SECONDS=0
        while [[ "$(docker inspect -f '{{.State.Health.Status}}' ollama 2>/dev/null)" != "healthy" ]]; do
            if [ $SECONDS -ge $TIMEOUT ]; then 
                log_error "Timeout atteint en attendant Ollama. Vérifiez les logs: docker logs ollama"
                return 1
            fi
            printf "\r  ${C_YELLOW}%s${C_RESET} Attente... (%ds)" "${spinner_chars[$((i++ % 4))]}" "$SECONDS"
            sleep 1; SECONDS=$((SECONDS + 1))
        done
        printf "\r"; log_ok "Service Ollama opérationnel.                      "

        # Assurer que les dossiers existent avec bonnes permissions
        mkdir -p "$BASE_DIR/data/ollama"
        docker exec ollama mkdir -p /root/.ollama/models/blobs
        
        for model_key in $SELECTED_MODELS_OLLAMA; do
            local model_source=$(get_asset_info "ollama_models" "$model_key")
            
            # Sanitisation du nom de modèle (enlever caractères spéciaux)
            local clean_model_name=$(echo "$model_key" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]//g')
            
            if [[ "$model_source" == http* ]]; then # C'est une URL directe (GGUF)
                local gguf_filename=$(basename "$model_source")
                local host_gguf_path="$BASE_DIR/data/ollama/$gguf_filename"
                local container_gguf_path="/root/.ollama/models/$gguf_filename"
                
                if [[ ! -f "$host_gguf_path" ]]; then
                    log_error "Fichier GGUF '$gguf_filename' non trouvé. Il aurait dû être téléchargé par le script principal."
                    continue
                fi

                log INFO "OLLAMA" "Importation du modèle GGUF '$model_key' dans Ollama..."
                
                # Créer le Modelfile avec le bon chemin (volume mappé)
                local modelfile_content="FROM $container_gguf_path"
                
                # Créer le Modelfile temporaire dans le conteneur
                if ! docker exec ollama bash -c "echo '$modelfile_content' > /tmp/modelfile_$clean_model_name"; then
                    log_error "Impossible de créer le Modelfile pour '$model_key'"
                    continue
                fi
                
                # Créer le modèle dans Ollama avec gestion d'erreur améliorée
                if docker exec ollama ollama create "$clean_model_name" -f "/tmp/modelfile_$clean_model_name" 2>&1; then
                    log_ok "$ICON_BRAIN Modèle GGUF '$model_key' → '$clean_model_name' importé avec succès"
                    # Nettoyer le Modelfile temporaire
                    docker exec ollama rm -f "/tmp/modelfile_$clean_model_name"
                else
                    log_error "Échec création modèle Ollama '$clean_model_name' depuis '$gguf_filename'"
                    log_info "Vérifiez les logs: docker exec ollama ollama create $clean_model_name -f /tmp/modelfile_$clean_model_name"
                    # Conserver le Modelfile pour debug
                fi
                
            else # C'est un nom de modèle Ollama standard
                if ! docker exec ollama ollama list 2>/dev/null | grep -q "^${model_source%%:*}"; then
                    log INFO "OLLAMA" "Téléchargement du modèle Ollama: $model_key ($model_source)"
                    if docker exec ollama ollama pull "$model_source" 2>&1; then
                        log_ok "$ICON_BRAIN Modèle '$model_key' installé avec succès"
                    else
                        log_error "Échec du téléchargement de '$model_key' ($model_source)"
                        log_info "Vérifiez les logs: docker exec ollama ollama pull $model_source"
                    fi
                else
                    log_ok "$ICON_BRAIN Modèle '$model_key' déjà présent"
                fi
            fi
        done
        
        # Afficher la liste finale des modèles installés
        log INFO "OLLAMA" "Modèles Ollama disponibles :"
        if docker exec ollama ollama list 2>/dev/null | tail -n +2 | grep -v "^$"; then
            docker exec ollama ollama list 2>/dev/null | tail -n +2 | while IFS= read -r line; do
                [[ -n "$line" ]] && log INFO "OLLAMA" "    ✓ $line"
            done
        else
            log_warn "Aucun modèle Ollama détecté. Vérifiez les logs de déploiement."
        fi
    fi
}



# Vérifie les dépendances de ComfyUI après le démarrage du service
verify_comfyui_dependencies() {
    # Vérifier si comfyui est dans la liste des services sélectionnés
    if [[ " $SELECTED_SERVICES " =~ " comfyui " ]]; then
        log_header "PHASE 6 : VÉRIFICATION POST-DÉMARRAGE DE COMFYUI"
        log INFO "COMFYUI" "Attente que ComfyUI soit pleinement opérationnel..."
        local spinner_chars=("-" "\\" "|" "/")
        local i=0
        TIMEOUT=300; SECONDS=0
        while [[ "$(docker inspect -f '{{.State.Health.Status}}' comfyui 2>/dev/null)" != "healthy" ]]; do
            if [ $SECONDS -ge $TIMEOUT ]; then log_error "Timeout atteint en attendant ComfyUI."; fi
            printf "\r  ${C_YELLOW}%s${C_RESET} Attente... (%ds)" "${spinner_chars[$((i++ % 4))]}" "$SECONDS"
            sleep 1; SECONDS=$((SECONDS + 1))
        done
        printf "\r"; log_ok "Service ComfyUI opérationnel.                      "

        log INFO "COMFYUI" "--- Informations PyTorch dans ComfyUI ---"
        docker exec comfyui python -c 'import torch; print(f"Torch: {torch.__version__}, CUDA: {torch.cuda.is_available()}")'
        log_ok "Vérification des dépendances ComfyUI terminée."
    fi
}

# --- NETTOYAGE DOCKER AVANCÉ ---

# Analyse l'espace Docker récupérable avec détails
analyze_docker_space() {
    log_info "DOCKER" "Analyse de l'espace Docker récupérable"
    
    # Collecter les informations système Docker
    local system_df_output
    system_df_output=$(docker system df 2>/dev/null) || {
        log_error "DOCKER" "Impossible d'analyser l'espace Docker"
        return 1
    }
    
    # Parser les différents types d'éléments
    local images_size=$(echo "$system_df_output" | grep "Images" | awk '{print $4}' || echo "0B")
    local containers_size=$(echo "$system_df_output" | grep "Containers" | awk '{print $4}' || echo "0B")
    local volumes_size=$(echo "$system_df_output" | grep "Local Volumes" | awk '{print $4}' || echo "0B")
    local build_cache_size=$(echo "$system_df_output" | grep "Build Cache" | awk '{print $4}' || echo "0B")
    
    # Compter les éléments récupérables
    local dangling_images=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l)
    local unused_images=$(docker images --filter "reference=*" --format "table {{.Repository}}:{{.Tag}}" 2>/dev/null | grep -v "REPOSITORY" | wc -l)
    local stopped_containers=$(docker ps -a -f "status=exited" -q 2>/dev/null | wc -l)
    local unused_volumes=$(docker volume ls -f "dangling=true" -q 2>/dev/null | wc -l)
    local unused_networks=$(docker network ls --filter "scope=local" --format "{{.Name}}" 2>/dev/null | grep -v -E "bridge|host|none" | wc -l)
    
    # Afficher le résumé d'analyse
    log INFO "DOCKER" "📊 ANALYSE DE L'ESPACE DOCKER"
    log INFO "DOCKER" "────────────────────────────────────────"
    log INFO "DOCKER" "Images:        $images_size ($dangling_images images orphelines)"
    log INFO "DOCKER" "Conteneurs:    $containers_size ($stopped_containers arrêtés)"
    log INFO "DOCKER" "Volumes:       $volumes_size ($unused_volumes orphelins)"
    log INFO "DOCKER" "Cache Build:   $build_cache_size"
    log INFO "DOCKER" "Réseaux:       $unused_networks réseaux personnalisés inutilisés"
    log INFO "DOCKER" "────────────────────────────────────────"
    
    # Estimer l'espace récupérable
    local reclaimable_estimate="Calcul en cours..."
    if command -v bc >/dev/null 2>&1; then
        # Conversion approximative (simplifiée) 
        local total_mb=0
        [[ "$build_cache_size" =~ ([0-9.]+)([KMGT]?)B ]] && {
            local size=${BASH_REMATCH[1]}
            local unit=${BASH_REMATCH[2]}
            case "$unit" in
                "G") total_mb=$(echo "$size * 1024" | bc 2>/dev/null || echo "0") ;;
                "M") total_mb=$size ;;
                "K") total_mb=$(echo "$size / 1024" | bc 2>/dev/null || echo "0") ;;
                *) total_mb=$(echo "$size / 1048576" | bc 2>/dev/null || echo "0") ;;
            esac
        }
        
        if (( $(echo "$total_mb > 100" | bc -l) )); then
            reclaimable_estimate="${total_mb%.*}MB estimés récupérables"
        else
            reclaimable_estimate="< 100MB récupérables"
        fi
    fi
    
    log INFO "DOCKER" "Espace récupérable: ~$reclaimable_estimate"
    
    # Stocker les résultats pour utilisation ultérieure
    export DOCKER_ANALYSIS_DANGLING_IMAGES=$dangling_images
    export DOCKER_ANALYSIS_STOPPED_CONTAINERS=$stopped_containers  
    export DOCKER_ANALYSIS_UNUSED_VOLUMES=$unused_volumes
    export DOCKER_ANALYSIS_BUILD_CACHE_SIZE=$build_cache_size
    export DOCKER_ANALYSIS_UNUSED_NETWORKS=$unused_networks
}

# Menu de nettoyage Docker avancé
cleanup_system() {
    log_header "NETTOYAGE INTELLIGENT DU SYSTÈME"
    
    # D'abord analyser l'espace disponible
    analyze_docker_space
    
    log INFO "DOCKER" "OPTIONS DE NETTOYAGE:"
    log INFO "DOCKER" "  1) Nettoyage conservateur (images orphelines + conteneurs arrêtés)"
    log INFO "DOCKER" "  2) Nettoyage standard (+ volumes orphelins + cache build)"
    log INFO "DOCKER" "  3) Nettoyage avancé (+ réseaux inutilisés + images non utilisées)"
    log INFO "DOCKER" "  4) Nettoyage complet (⚠️ TOUT sauf volumes actifs)"
    log INFO "DOCKER" "  5) Nettoyage personnalisé (choix sélectif)"
    log INFO "DOCKER" "  6) Analyser uniquement (pas de nettoyage)"
    log INFO "DOCKER" "  0) Annuler"
    
    echo ""
    read -p "Votre choix (0-6): " cleanup_choice
    
    case "$cleanup_choice" in
        1)
            log_info "DOCKER" "Nettoyage conservateur sélectionné"
            cleanup_conservative
            ;;
        2)
            log_info "DOCKER" "Nettoyage standard sélectionné"
            cleanup_standard
            ;;
        3)
            log_info "DOCKER" "Nettoyage avancé sélectionné" 
            cleanup_advanced
            ;;
        4)
            log_info "DOCKER" "Nettoyage complet sélectionné"
            cleanup_complete
            ;;
        5)
            log_info "DOCKER" "Nettoyage personnalisé sélectionné"
            cleanup_custom
            ;;
        6)
            log_info "DOCKER" "Analyse uniquement - pas de nettoyage"
            log INFO "DOCKER" "Analyse terminée. Aucun nettoyage effectué."
            ;;
        0)
            log_info "DOCKER" "Nettoyage annulé par l'utilisateur"
            ;;
        *)
            log_warn "DOCKER" "Choix invalide: $cleanup_choice"
            echo -e "${C_RED}Choix invalide.${C_RESET}"
            ;;
    esac
}

# Nettoyage conservateur - éléments sûrs uniquement
cleanup_conservative() {
    log_info "DOCKER" "Démarrage du nettoyage conservateur"
    
    log INFO "DOCKER" "🧹 NETTOYAGE CONSERVATEUR"
    log INFO "DOCKER" "Suppression des éléments sûrs uniquement..."
    
    # Images orphelines (dangling)
    if [[ ${DOCKER_ANALYSIS_DANGLING_IMAGES:-0} -gt 0 ]]; then
        log_info "DOCKER" "Suppression des images orphelines"
        docker image prune -f >/dev/null 2>&1
        log_docker_service "cleanup" "PRUNE_IMAGES" "SUCCESS" "${DOCKER_ANALYSIS_DANGLING_IMAGES} images orphelines supprimées"
    fi
    
    # Conteneurs arrêtés
    if [[ ${DOCKER_ANALYSIS_STOPPED_CONTAINERS:-0} -gt 0 ]]; then
        log_info "DOCKER" "Suppression des conteneurs arrêtés"
        docker container prune -f >/dev/null 2>&1
        log_docker_service "cleanup" "PRUNE_CONTAINERS" "SUCCESS" "${DOCKER_ANALYSIS_STOPPED_CONTAINERS} conteneurs arrêtés supprimés"
    fi
    
    log_ok "Nettoyage conservateur terminé avec succès."
}

# Nettoyage standard - éléments courants
cleanup_standard() {
    log_info "DOCKER" "Démarrage du nettoyage standard"
    
    log INFO "DOCKER" "🧽 NETTOYAGE STANDARD"
    log INFO "DOCKER" "Suppression des éléments couramment inutilisés..."
    
    # Effectuer d'abord le nettoyage conservateur
    cleanup_conservative
    
    # Volumes orphelins
    if [[ ${DOCKER_ANALYSIS_UNUSED_VOLUMES:-0} -gt 0 ]]; then
        log_info "DOCKER" "Suppression des volumes orphelins"
        docker volume prune -f >/dev/null 2>&1
        log_docker_service "cleanup" "PRUNE_VOLUMES" "SUCCESS" "${DOCKER_ANALYSIS_UNUSED_VOLUMES} volumes orphelins supprimés"
    fi
    
    # Cache de build
    if [[ "${DOCKER_ANALYSIS_BUILD_CACHE_SIZE:-0B}" != "0B" ]]; then
        log_info "DOCKER" "Nettoyage du cache de build"
        docker builder prune -f >/dev/null 2>&1
        log_docker_service "cleanup" "PRUNE_BUILD_CACHE" "SUCCESS" "Cache de build supprimé (${DOCKER_ANALYSIS_BUILD_CACHE_SIZE})"
    fi
    
    log_ok "Nettoyage standard terminé avec succès."
}

# Nettoyage avancé - éléments non utilisés
cleanup_advanced() {
    log_info "DOCKER" "Démarrage du nettoyage avancé"
    
    log INFO "DOCKER" "🔥 NETTOYAGE AVANCÉ"
    log INFO "DOCKER" "Suppression des éléments non utilisés (plus agressif)..."
    
    # Effectuer d'abord le nettoyage standard  
    cleanup_standard
    
    # Images non utilisées (pas seulement orphelines)
    log_info "DOCKER" "Suppression des images non utilisées"
    docker image prune -a -f >/dev/null 2>&1
    log_docker_service "cleanup" "PRUNE_ALL_IMAGES" "SUCCESS" "Images non utilisées supprimées"
    
    # Réseaux personnalisés inutilisés
    if [[ ${DOCKER_ANALYSIS_UNUSED_NETWORKS:-0} -gt 0 ]]; then
        log_info "DOCKER" "Suppression des réseaux inutilisés"
        docker network prune -f >/dev/null 2>&1
        log_docker_service "cleanup" "PRUNE_NETWORKS" "SUCCESS" "${DOCKER_ANALYSIS_UNUSED_NETWORKS} réseaux supprimés"
    fi
    
    log_ok "Nettoyage avancé terminé avec succès."
}

# Nettoyage complet - ATTENTION !
cleanup_complete() {
    log_warn "DOCKER" "ATTENTION: Nettoyage complet demandé"
    
    log INFO "DOCKER" "⚠️  NETTOYAGE COMPLET - ATTENTION"
    log INFO "DOCKER" "Cette option supprime TOUT ce qui n'est pas actuellement utilisé,"
    log INFO "DOCKER" "y compris les images qui pourraient être utiles."
    log INFO "DOCKER" "Les volumes de données seront préservés."
    
    echo ""
    read -p "  Confirmez-vous ce nettoyage complet ? (y/N): " confirm_complete
    
    if [[ ! "$confirm_complete" =~ ^[Yy]$ ]]; then
        log_info "DOCKER" "Nettoyage complet annulé par l'utilisateur"
        return 0
    fi
    
    log INFO "DOCKER" "💥 NETTOYAGE COMPLET EN COURS"
    log_info "DOCKER" "Exécution du nettoyage complet système"
    
    # Utiliser la commande système complète (sans volumes)
    docker system prune -a -f >/dev/null 2>&1
    log_docker_service "cleanup" "SYSTEM_PRUNE_ALL" "SUCCESS" "Nettoyage complet système effectué"
    
    log_ok "Nettoyage complet terminé avec succès."
}

# Nettoyage personnalisé - choix sélectif
cleanup_custom() {
    log_info "DOCKER" "Mode de nettoyage personnalisé"
    
    log INFO "DOCKER" "🎛️  NETTOYAGE PERSONNALISÉ"
    log INFO "DOCKER" "Sélectionnez les éléments à nettoyer:"
    
    local cleanup_options=()
    
    # Images orphelines
    if [[ ${DOCKER_ANALYSIS_DANGLING_IMAGES:-0} -gt 0 ]]; then
        log INFO "DOCKER" "  1) Images orphelines ($DOCKER_ANALYSIS_DANGLING_IMAGES éléments)"
        cleanup_options[1]="dangling_images"
    fi
    
    # Conteneurs arrêtés  
    if [[ ${DOCKER_ANALYSIS_STOPPED_CONTAINERS:-0} -gt 0 ]]; then
        log INFO "DOCKER" "  2) Conteneurs arrêtés ($DOCKER_ANALYSIS_STOPPED_CONTAINERS éléments)"
        cleanup_options[2]="stopped_containers"
    fi
    
    # Volumes orphelins
    if [[ ${DOCKER_ANALYSIS_UNUSED_VOLUMES:-0} -gt 0 ]]; then
        log INFO "DOCKER" "  3) Volumes orphelins ($DOCKER_ANALYSIS_UNUSED_VOLUMES éléments)"
        cleanup_options[3]="unused_volumes"
    fi
    
    # Cache de build
    if [[ "${DOCKER_ANALYSIS_BUILD_CACHE_SIZE:-0B}" != "0B" ]]; then
        log INFO "DOCKER" "  4) Cache de build ($DOCKER_ANALYSIS_BUILD_CACHE_SIZE)"
        cleanup_options[4]="build_cache"
    fi
    
    # Réseaux
    if [[ ${DOCKER_ANALYSIS_UNUSED_NETWORKS:-0} -gt 0 ]]; then
        log INFO "DOCKER" "  5) Réseaux inutilisés ($DOCKER_ANALYSIS_UNUSED_NETWORKS éléments)"
        cleanup_options[5]="unused_networks"
    fi
    
    # Images non utilisées
    log INFO "DOCKER" "  6) Toutes les images non utilisées (agressif)"
    cleanup_options[6]="all_unused_images"
    
    echo ""
    read -p "  Sélectionnez les options à nettoyer (ex: 1 3 4) ou 'all': " custom_selection
    
    if [[ -z "$custom_selection" ]]; then
        log_info "DOCKER" "Aucune sélection - nettoyage annulé"
        return 0
    fi
    
    log INFO "DOCKER" "🔧 NETTOYAGE PERSONNALISÉ EN COURS"
    
    if [[ "$custom_selection" == "all" ]]; then
        custom_selection="1 2 3 4 5 6"
    fi
    
    for option in $custom_selection; do
        case "${cleanup_options[$option]:-}" in
            "dangling_images")
                log_info "DOCKER" "Nettoyage des images orphelines"
                docker image prune -f >/dev/null 2>&1
                log_docker_service "cleanup" "CUSTOM_DANGLING_IMAGES" "SUCCESS"
                ;;
            "stopped_containers")
                log_info "DOCKER" "Nettoyage des conteneurs arrêtés"
                docker container prune -f >/dev/null 2>&1
                log_docker_service "cleanup" "CUSTOM_STOPPED_CONTAINERS" "SUCCESS"
                ;;
            "unused_volumes")
                log_info "DOCKER" "Nettoyage des volumes orphelins"
                docker volume prune -f >/dev/null 2>&1
                log_docker_service "cleanup" "CUSTOM_UNUSED_VOLUMES" "SUCCESS"
                ;;
            "build_cache")
                log_info "DOCKER" "Nettoyage du cache de build"
                docker builder prune -f >/dev/null 2>&1
                log_docker_service "cleanup" "CUSTOM_BUILD_CACHE" "SUCCESS"
                ;;
            "unused_networks")
                log_info "DOCKER" "Nettoyage des réseaux inutilisés"
                docker network prune -f >/dev/null 2>&1
                log_docker_service "cleanup" "CUSTOM_UNUSED_NETWORKS" "SUCCESS"
                ;;
            "all_unused_images")
                log_info "DOCKER" "Nettoyage de toutes les images non utilisées"
                docker image prune -a -f >/dev/null 2>&1
                log_docker_service "cleanup" "CUSTOM_ALL_UNUSED_IMAGES" "SUCCESS"
                ;;
            *)
                log_warn "DOCKER" "Option invalide ignorée: $option"
                ;;
        esac
    done
    
    log_ok "Nettoyage personnalisé terminé avec succès."
}

# Installation WSL CUDA
install_wsl_cuda() {
    log_header "INSTALLATION DU SUPPORT CUDA WSL"
    log INFO "WSL" "Installation des pilotes CUDA pour WSL..."
    
    # Vérifier si CUDA WSL est déjà installé
    if nvidia-smi >/dev/null 2>&1; then
        log_ok "Support CUDA WSL déjà installé."
        return 0
    fi
    
    log WARN "WSL" "Le support CUDA WSL n'est pas détecté."
    log INFO "WSL" "Veuillez installer les pilotes CUDA WSL depuis :"
    log INFO "WSL" "https://developer.nvidia.com/cuda/wsl"
    
    read -p "  Continuer sans support GPU ? (y/N) : " continue_cpu
    if [[ ! "$continue_cpu" =~ ^[Yy]$ ]]; then
        log_error "Installation interrompue."
    fi
    
    log_warn "Continuation en mode CPU uniquement."
}