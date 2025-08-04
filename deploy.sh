#!/bin/bash
# set -x  # Debug désactivé pour un affichage propre
# ==============================================================================
#      J.A.M.Z.I. AI STACK - DEPLOYMENT & MANAGEMENT FRAMEWORK v52.0 DATA-DRIVEN
# ==============================================================================
#      Orchestrateur interactif data-driven avec architecture modulaire complète
#      ➜ v52.0 : Refactoring complet vers architecture data-driven avec logging centralisé
#                et configuration JSON dynamique des packs

# --- SETUP INITIAL & ROBUSTESSE ---------------------------------------------
set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charge les variables d'environnement et de configuration globalement
set -o allexport
if [ -f "$BASE_DIR/.env" ]; then
    source "$BASE_DIR/.env"
else
    echo "⚠️  AVERTISSEMENT: Fichier .env manquant, utilisation des valeurs par défaut"
    # Variables par défaut
    OPEN_WEBUI_PORT=8080
    COMFYUI_PORT=8188
    OLLAMA_PORT=11434
    N8N_PORT=5678
    WAV2LIP_PORT=8000
    POSTGRES_USER=postgres
    POSTGRES_DB=postgres
    POSTGRES_PASSWORD=changeme
    PIXABAY_API_KEY=your_pixabay_api_key_here
    COMFYUI_ARGS=
    DETECTED_VRAM_GB=0
    DETECTED_GPU_NAME=Inconnue
fi
source "$BASE_DIR/parallel_downloader.sh"

# --- CHARGEMENT DES MODULES MODULAIRES ---
source "$BASE_DIR/lib/environment.sh"        # Validation environnement & WSL (pour détection terminal)
detect_terminal_capabilities                  # Détecter les capacités du terminal AVANT logging
source "$BASE_DIR/lib/core/logging.sh"       # Logging centralisé (après détection terminal)
init_logging                                  # Initialiser le système de logging
source "$BASE_DIR/lib/data/packs.sh"         # Configuration data-driven des packs
source "$BASE_DIR/lib/docker.sh"             # Gestion Docker & conteneurs
source "$BASE_DIR/lib/validation.sh"         # Génération configs & validation
source "$BASE_DIR/lib/interface.sh"          # Menus & interface utilisateur
source "$BASE_DIR/lib/deployment.sh"         # Déploiement packs & installation

# --- Initialisation des variables optionnelles (important pour set -u) ---
: "${SELECTED_COMFYUI_MODELS_HOST_PATH:=}"
: "${SELECTED_OLLAMA_HOST_PATH:=}"
: "${SELECTED_N8N_HOST_PATH:=}"

# --- UI & LOGGING (DOIT ÊTRE AVANT LE CHARGEMENT DES MODULES) ---
C_RESET=$'\033[0m' C_RED=$'\033[0;31m' C_GREEN=$'\033[0;32m' C_YELLOW=$'\033[0;33m' C_BLUE=$'\033[0;34m' C_CYAN=$'\033[0;36m' C_WHITE=$'\033[0;37m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m'
ICON_OK="${C_GREEN}✔${C_RESET}" ICON_WARN="${C_YELLOW}⚠${C_RESET}" ICON_ERROR="${C_RED}❌${C_RESET}" ICON_DOWNLOAD="${C_YELLOW}📥${C_RESET}" ICON_UPDATE="${C_GREEN}🔄${C_RESET}" ICON_BRAIN="${C_GREEN}🧠${C_RESET}" ICON_GEAR="${C_BLUE}⚙️${C_RESET}"

# --- SUPPORT ARGUMENTS LIGNE DE COMMANDE ---
# Gestion des arguments de ligne de commande
case "${1:-}" in
    --help|-h)
        echo "J.A.M.Z.I. AI Stack v52.0 - Deployment Framework"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "OPTIONS:"
        echo "  -h, --help           Show this help message"
        echo "  --version            Show version information"
        echo "  pack_<N>             Install pack number N directly"
        echo ""
        echo "Interactive mode is used when no arguments are provided."
        exit 0
        ;;
    --version)
        echo "J.A.M.Z.I. AI Stack v52.0 Data-Driven"
        exit 0
        ;;
    pack_[0-9]*)
        PACK_NUMBER="${1#pack_}"
        DIRECT_PACK_INSTALL=true
        ;; 
    "")
        DIRECT_PACK_INSTALL=false
        ;; 
    *)
        echo "Unknown option: $1"
        echo "Use --help for available options."
        exit 1
        ;; 
esac

# --- FONCTIONS LOGGING RAPIDES (DÉFINIES LOCALEMENT) ---
log_header(){ echo -e "\n${C_BLUE}${C_BOLD}┃ $1${C_RESET}"; }
log_ok()    { echo -e "  ${C_GREEN}✔${C_RESET} $1"; }
log_warn()  { echo -e "  ${C_YELLOW}⚠${C_RESET} ${C_YELLOW}AVERTISSEMENT:${C_RESET} $1"; }
log_error() { echo -e "\n${C_RED}❌ ERREUR:${C_RESET} $1\n" >&2; exit 1; }

# --- GESTION DES INTERRUPTIONS ----------------------------------------------
cleanup(){
  log_warn "MAIN" "Opération annulée. Nettoyage..."
  if [ -f "$BASE_DIR/docker-compose.yml" ]; then
    cd "$BASE_DIR" && docker compose down --remove-orphans &>/dev/null
    log_ok "Conteneurs Docker arrêtés."
  fi
  exit 1
}

trap cleanup SIGINT SIGTERM ERR

# --- FONCTION PRINCIPALE DATA-DRIVEN ---
function main() {
    # Initialisation du système de logging et des variables
    log_info "MAIN" "J.A.M.Z.I. AI Stack v52.0 Data-Driven - Démarrage"
    
    # Initialisation des variables GPU par défaut pour éviter les erreurs
    export DETECTED_GPU_NAME="${DETECTED_GPU_NAME:-Inconnue}"
    export DETECTED_VRAM_GB="${DETECTED_VRAM_GB:-0}"
    
    # Validation de l'environnement avec logging centralisé
    check_environment
    check_docker_status

    # Installation directe de pack si argument fourni
    if [[ "$DIRECT_PACK_INSTALL" == "true" ]]; then
        log_info "MAIN" "Installation directe du pack $PACK_NUMBER"
        
        # Charger la configuration depuis JSON
        if load_pack_configuration "$PACK_NUMBER"; then
            echo "DEBUG: SELECTED_SERVICES: $SELECTED_SERVICES"
            echo "DEBUG: SELECTED_MODELS_OLLAMA: $SELECTED_MODELS_OLLAMA"
            echo "DEBUG: SELECTED_PLUGINS_COMFYUI: $SELECTED_PLUGINS_COMFYUI"
            # Valider les exigences du pack
            if validate_pack_requirements "$PACK_NUMBER"; then
                # Exécuter le déploiement
                execute_deployment_data_driven "$PACK_NUMBER"
            else
                log_error "MAIN" "Les exigences du pack $PACK_NUMBER ne sont pas satisfaites"
                exit 1
            fi
        else
            log_error "MAIN" "Impossible de charger la configuration du pack $PACK_NUMBER"
            exit 1
        fi
        return $?
    fi

    # Menu interactif principal
    while true; do
        display_main_menu
        
        echo ""
        read -p "Votre choix : " main_choice
        
        case "$main_choice" in
            
            # Gérer la sélection d'un pack par son ID (1-10 seulement)
            [1-9]|10)
                log_info "MAIN" "Pack sélectionné: $main_choice"
                
                # Charger la configuration depuis JSON
                if load_pack_configuration "$main_choice"; then
                    # Valider les exigences du pack
                    if validate_pack_requirements "$main_choice"; then
                        # Demander confirmation
                        display_installation_summary
                        if [[ $? -eq 0 ]]; then
                            # Exécuter le déploiement
                            execute_deployment_data_driven "$main_choice"
                            break
                        fi
                    else
                        echo -e "\nContinuer malgré les avertissements ? (y/N) : "
                        read -r proceed
                        if [[ "$proceed" =~ ^[Yy]$ ]]; then
                            execute_deployment_data_driven "$main_choice"
                            break
                        fi
                    fi
                else
                    log_error "MAIN" "Impossible de charger la configuration du pack $main_choice"
                fi
                ;; 
                 
            88) 
                log_info "MAIN" "Installation personnalisée interactive"
                custom_interactive_installation
                break
                ;; 
            89)
                log_info "MAIN" "Mise à jour des assets"
                echo "⚠️ Fonction de mise à jour des assets non encore implémentée"
                echo "🔄 Utilisez le déploiement d'un pack pour télécharger de nouveaux assets"
                read -p "Appuyez sur Entrée pour continuer..."
                ;; 
            90)
                log_info "MAIN" "Nettoyage intelligent du système"
                cleanup_system
                ;; 
            91)
                log_info "MAIN" "Vérification de l'état du système"
                validate_system
                ;; 
            92)
                log_info "MAIN" "Installation des pilotes CUDA WSL"
                install_wsl_cuda
                ;; 
            93)
                log_info "MAIN" "Génération du rapport de session"
                local report_file=$(generate_session_report)
                echo -e "\nRapport généré: $report_file"
                ;; 
            99)
                log_info "MAIN" "Arrêt demandé par l'utilisateur"
                echo -e "\nAu revoir ! 👋"
                exit 0
                ;; 
            *)
                log_warn "MAIN" "Choix invalide: $main_choice"
                echo -e "\nChoix invalide. Veuillez sélectionner un numéro valide."
                read -p "Appuyez sur Entrée pour continuer..."
                ;; 
esac
    done
}

# --- EXÉCUTION DU SCRIPT PRINCIPAL ---
main "$@"