#!/bin/bash
# ==============================================================================
#      JAMZI AI STACK - MODULE DEPLOYMENT
# ==============================================================================
# Fonctions de déploiement des packs et installation automatisée

# --- DÉPLOIEMENT DES PACKS ---



# Exécute le déploiement complet (version data-driven)
execute_deployment_data_driven() {
    local pack_id="$1"
    
    log_info "DEPLOYMENT" "Démarrage du déploiement data-driven pour le pack $pack_id"
    
    # Vérification préalable
    if [[ -z "${SELECTED_SERVICES:-}" ]]; then
        log_error "DEPLOYMENT" "Aucun service sélectionné. Impossible de continuer."
        return 1
    fi
    
    # Séquence de déploiement avec logging centralisé
    # log_progress "DEPLOYMENT" 1 6 "Génération des fichiers de configuration"
    generate_all_files
    
    log_progress "DEPLOYMENT" 2 6 "Synchronisation des assets"
    sync_all_assets_parallel
    
    log_progress "DEPLOYMENT" 3 6 "Lancement de la stack Docker"
    launch_stack
    
    log_progress "DEPLOYMENT" 4 6 "Synchronisation des modèles Ollama"
    sync_ollama_models
    
    log_progress "DEPLOYMENT" 5 6 "Vérification des dépendances ComfyUI"
    verify_comfyui_dependencies
    
    log_progress "DEPLOYMENT" 6 6 "Validation post-déploiement"
    
    # Validation post-déploiement
    if validate_deployment; then
        log_info "DEPLOYMENT" "Déploiement réussi pour le pack $pack_id"
        display_access_information
        return 0
    else
        log_error "DEPLOYMENT" "Le déploiement n'est pas complètement opérationnel"
        return 1
    fi
}



# Installation personnalisée interactive
custom_interactive_installation() {
    log_header "INSTALLATION PERSONNALISÉE INTERACTIVE"
    
    # Sélection des services
    select_services
    if [[ -z "${SELECTED_SERVICES:-}" ]]; then
        log_error "Aucun service sélectionné."
        return 1
    fi
    
    # Sélection des assets selon les services choisis
    if [[ " $SELECTED_SERVICES " =~ " ollama " ]]; then
        select_ollama_models
    fi
    
    if [[ " $SELECTED_SERVICES " =~ " comfyui " ]]; then
        select_comfyui_plugins
        select_comfyui_checkpoints
        select_comfyui_vae
        
        # Assets optionnels
        echo -e "\n${C_BOLD}Assets optionnels ComfyUI:${C_RESET}"
        read -p "Ajouter des modèles ControlNet ? (y/N) : " add_controlnet
        if [[ "$add_controlnet" =~ ^[Yy]$ ]]; then
            select_comfyui_controlnet
        fi
        
        read -p "Ajouter des modèles Upscale ? (y/N) : " add_upscale
        if [[ "$add_upscale" =~ ^[Yy]$ ]]; then
            select_comfyui_upscale
        fi
        
        read -p "Ajouter des modèles GFPGAN ? (y/N) : " add_gfpgan
        if [[ "$add_gfpgan" =~ ^[Yy]$ ]]; then
            select_comfyui_gfpgan
        fi
        
        read -p "Ajouter des modèles Wav2Lip ? (y/N) : " add_wav2lip
        if [[ "$add_wav2lip" =~ ^[Yy]$ ]]; then
            select_comfyui_wav2lip
        fi
        
        read -p "Ajouter des modèles LoRA ? (y/N) : " add_loras
        if [[ "$add_loras" =~ ^[Yy]$ ]]; then
            select_comfyui_loras
        fi
        
        read -p "Ajouter des modèles CLIP ? (y/N) : " add_clip
        if [[ "$add_clip" =~ ^[Yy]$ ]]; then
            select_comfyui_clip
        fi
        
        read -p "Ajouter des modèles UNET ? (y/N) : " add_unet
        if [[ "$add_unet" =~ ^[Yy]$ ]]; then
            select_comfyui_unet
        fi
        
        select_comfyui_workflows
    fi
    
    if [[ " $SELECTED_SERVICES " =~ " n8n " ]]; then
        select_n8n_workflows
    fi
    
    # Configuration des chemins personnalisés
    select_custom_host_paths
    
    # Affichage du récapitulatif et exécution
    if display_installation_summary; then
        execute_deployment_data_driven "custom_install"
    fi
}