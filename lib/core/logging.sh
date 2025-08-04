#!/bin/bash
# ==============================================================================
#      JAMZI AI STACK - MODULE LOGGING CENTRALISÉ
# ==============================================================================
# Système de logging structuré et centralisé

# --- CONFIGURATION LOGGING ---
LOG_LEVELS=("DEBUG" "INFO" "WARN" "ERROR" "FATAL")
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/deployment-$(date +%Y%m%d-%H%M%S).log"
LOG_LEVEL_FILTER="${LOG_LEVEL:-INFO}"  # Variable d'environnement pour filtrer les logs

# Couleurs pour l'affichage console (palette moderne étendue)
: "${C_RESET:=$'\033[0m'}"
: "${C_RED:=$'\033[0;31m'}"
: "${C_GREEN:=$'\033[0;32m'}"
: "${C_YELLOW:=$'\033[0;33m'}"
: "${C_BLUE:=$'\033[0;34m'}"
: "${C_MAGENTA:=$'\033[0;35m'}"
: "${C_CYAN:=$'\033[0;36m'}"
: "${C_WHITE:=$'\033[0;37m'}"
: "${C_BOLD:=$'\033[1m'}"
: "${C_DIM:=$'\033[2m'}"
: "${C_ITALIC:=$'\033[3m'}"
: "${C_UNDERLINE:=$'\033[4m'}"
: "${C_BLINK:=$'\033[5m'}"

# Couleurs modernes (256 colors)
: "${C_PURPLE:=$'\033[38;5;129m'}"
: "${C_ORANGE:=$'\033[38;5;214m'}"
: "${C_PINK:=$'\033[38;5;213m'}"
: "${C_LIME:=$'\033[38;5;154m'}"
: "${C_AQUA:=$'\033[38;5;87m'}"
: "${C_GOLD:=$'\033[38;5;220m'}"

# Couleurs de fond
: "${C_BG_BLACK:=$'\033[40m'}"
: "${C_BG_RED:=$'\033[41m'}"
: "${C_BG_GREEN:=$'\033[42m'}"
: "${C_BG_YELLOW:=$'\033[43m'}"
: "${C_BG_BLUE:=$'\033[44m'}"
: "${C_BG_MAGENTA:=$'\033[45m'}"
: "${C_BG_CYAN:=$'\033[46m'}"
: "${C_BG_WHITE:=$'\033[47m'}"

declare -A LOG_COLORS=(
    ["DEBUG"]="${C_DIM}"
    ["INFO"]="${C_AQUA}"
    ["WARN"]="${C_ORANGE}"
    ["ERROR"]="${C_RED}${C_BOLD}"
    ["FATAL"]="${C_RED}${C_BOLD}${C_BG_WHITE}"
    ["SUCCESS"]="${C_LIME}${C_BOLD}"
    ["PROGRESS"]="${C_PURPLE}"
    ["TITLE"]="${C_CYAN}${C_BOLD}"
)

# Icônes modernes pour l'affichage console
declare -A LOG_ICONS=(
    ["DEBUG"]="🔍"
    ["INFO"]="ℹ️"
    ["WARN"]="⚠️"
    ["ERROR"]="❌"
    ["FATAL"]="💥"
    ["SUCCESS"]="✅"
    ["PROGRESS"]="🔄"
    ["DOWNLOAD"]="⬇️"
    ["UPLOAD"]="⬆️"
    ["DOCKER"]="🐳"
    ["GPU"]="🎮"
    ["CPU"]="💻"
    ["NETWORK"]="🌐"
    ["FILE"]="📁"
    ["SECURITY"]="🔒"
    ["ROCKET"]="🚀"
    ["SPARKLES"]="✨"
    ["FIRE"]="🔥"
    ["LIGHTNING"]="⚡"
    ["GEAR"]="⚙️"
    ["WRENCH"]="🔧"
    ["HAMMER"]="🔨"
    ["TARGET"]="🎯"
)

# --- INITIALISATION ---
init_logging() {
    # Éviter la double initialisation
    if [[ "${LOGGING_INITIALIZED:-false}" == "true" ]]; then
        return 0
    fi
    
    # Créer le répertoire de logs
    mkdir -p "$LOG_DIR"
    
    # Nettoyer les anciens logs (garder seulement les 10 derniers)
    find "$LOG_DIR" -name "deployment-*.log" -type f | sort | head -n -10 | xargs rm -f 2>/dev/null || true
    
    # Initialiser le fichier de log
    echo "# J.A.M.Z.I. AI STACK - Deployment Log" > "$LOG_FILE"
    echo "# Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo "# User: $(whoami)" >> "$LOG_FILE"
    echo "# Working Directory: $BASE_DIR" >> "$LOG_FILE"
    echo "# ================================================" >> "$LOG_FILE"
    
    export LOGGING_INITIALIZED=true
    log_info "LOGGING" "Logging system initialized - Log file: $LOG_FILE"
}

# --- FONCTIONS DE LOGGING ---

# Fonction de log principale
log() {
    local level="$1"
    local component="${2:-MAIN}"
    local message="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Vérifier le niveau de log
    if ! should_log_level "$level"; then
        return 0
    fi
    
    # Format pour le fichier (structuré)
    local file_entry="[$timestamp] $level [$component] $message"
    echo "$file_entry" >> "$LOG_FILE"
    
    # Format pour la console (colorisé si supporté)
    if [[ "${TERMINAL_SUPPORTS_ANSI:-true}" == "true" ]]; then
        local color="${LOG_COLORS[$level]:-$C_RESET}"
        local icon="${LOG_ICONS[$level]:-•}"
        local console_entry="${color}$icon [$component] $message${C_RESET}"
    else
        local icon="${level:0:1}"  # Première lettre du niveau (I, W, E, etc.)
        local console_entry="$icon [$component] $message"
    fi
    
    # Afficher selon le niveau
    case "$level" in
        "ERROR"|"FATAL")
            printf "%b\n" "$console_entry" >&2
            ;;
        *)
            printf "%b\n" "$console_entry"
            ;;
    esac
}

# Fonctions de log par niveau
log_debug() { log "DEBUG" "$1" "${2:-}"; }
log_info() { log "INFO" "$1" "${2:-}"; }
log_warn() { log "WARN" "$1" "${2:-}"; }
log_error() { log "ERROR" "$1" "${2:-}"; }
log_fatal() { log "FATAL" "$1" "${2:-}"; exit 1; }

# Vérifier si un niveau doit être loggé
should_log_level() {
    local level="$1"
    local filter_index=0
    local level_index=0
    
    # Trouver l'index du niveau de filtre
    for i in "${!LOG_LEVELS[@]}"; do
        [[ "${LOG_LEVELS[$i]}" == "$LOG_LEVEL_FILTER" ]] && filter_index=$i
        [[ "${LOG_LEVELS[$i]}" == "$level" ]] && level_index=$i
    done
    
    # Logger si le niveau est >= au filtre
    [[ $level_index -ge $filter_index ]]
}

# --- LOGGING SPÉCIALISÉ ---

# Logging de commandes avec leur output
log_command() {
    local component="$1"
    local command="$2"
    shift 2
    
    log_info "$component" "Executing: $command $*"
    
    # Capturer stdout et stderr
    local temp_dir="$BASE_DIR/tmp/log_command_$_${RANDOM}"
    mkdir -p "$temp_dir"
    local temp_stdout="$temp_dir/stdout"
    local temp_stderr="$temp_dir/stderr"
    
    if "$command" "$@" >"$temp_stdout" 2>"$temp_stderr"; then
        local exit_code=0
        log_info "$component" "Command succeeded: $command"
        
        # Logger stdout si non vide
        if [[ -s "$temp_stdout" ]]; then
            log_debug "$component" "STDOUT: $(cat "$temp_stdout")"
        fi
    else
        local exit_code=$?
        log_error "$component" "Command failed (exit $exit_code): $command"
        
        # Logger stderr en cas d'erreur
        if [[ -s "$temp_stderr" ]]; then
            log_error "$component" "STDERR: $(cat "$temp_stderr")"
        fi
    fi
    
    # Nettoyer les fichiers temporaires
    rm -rf "$temp_dir"
    return $exit_code
}

# Logging de progression avec barre
log_progress() {
    local component="$1"
    local step="$2"
    local total="$3"
    local message="$4"
    
    local percentage=$((step * 100 / total))
    
    # Limiter le pourcentage à 100 pour éviter les erreurs de cut
    if [ $percentage -gt 100 ]; then
        percentage=100
    fi
    
    # Version simplifiée sans boucles Unicode problématiques
    local bar="████████████████████"
    local empty="░░░░░░░░░░░░░░░░░░░░"
    local filled_chars=$((percentage/5))
    local remaining_chars=$((20-filled_chars))
    
    # Sécuriser les valeurs pour cut
    if [ $filled_chars -gt 20 ]; then filled_chars=20; fi
    if [ $filled_chars -lt 0 ]; then filled_chars=0; fi
    if [ $remaining_chars -gt 20 ]; then remaining_chars=20; fi
    if [ $remaining_chars -lt 0 ]; then remaining_chars=0; fi
    
    # Gérer le cas où filled_chars ou remaining_chars est 0
    local filled=""
    if [ $filled_chars -gt 0 ]; then
        filled=$(echo "$bar" | cut -c1-$filled_chars)
    fi
    
    local remaining=""
    if [ $remaining_chars -gt 0 ]; then
        remaining=$(echo "$empty" | cut -c1-$remaining_chars)
    fi
    
    # Afficher la progression de façon sécurisée
    echo -e "${C_BLUE}[$component]${C_RESET} [$filled$remaining] $percentage% ($step/$total) $message"
    
    # Logger dans le fichier
    log "INFO" "$component" "Progress: $step/$total ($percentage%) - $message"
}

# Affichage moderne d'une bannière de titre
log_banner() {
    local title="$1"
    local subtitle="${2:-}"
    local width=70
    
    echo
    echo -e "${C_CYAN}${C_BOLD}╔$(printf '═%.0s' $(seq 1 $((width-2))))╗${C_RESET}"
    
    # Centrer le titre
    local title_len=${#title}
    local padding=$(( (width - title_len - 4) / 2 ))
    printf -v title_padded "%*s%s%*s" $padding "" "$title" $padding ""
    echo -e "${C_CYAN}${C_BOLD}║${C_AQUA}${C_BOLD} $title_padded ${C_CYAN}${C_BOLD}║${C_RESET}"
    
    if [[ -n "$subtitle" ]]; then
        local subtitle_len=${#subtitle}
        local sub_padding=$(( (width - subtitle_len - 4) / 2 ))
        printf -v subtitle_padded "%*s%s%*s" $sub_padding "" "$subtitle" $sub_padding ""
        echo -e "${C_CYAN}${C_BOLD}║${C_DIM} $subtitle_padded ${C_CYAN}${C_BOLD}║${C_RESET}"
    fi
    
    echo -e "${C_CYAN}${C_BOLD}╚$(printf '═%.0s' $(seq 1 $((width-2))))╝${C_RESET}"
    echo
}

# Affichage moderne d'une section
log_section() {
    local title="$1"
    local icon="${2:-${LOG_ICONS[GEAR]}}"
    
    echo
    echo -e "${C_PURPLE}${C_BOLD}┌─── $icon $title ───${C_RESET}"
}

# Fermeture d'une section
log_section_end() {
    echo -e "${C_PURPLE}${C_BOLD}└───────────────────────${C_RESET}"
    echo
}

# Affichage d'un statut avec icône
log_status() {
    local status="$1"
    local message="$2"
    local component="${3:-MAIN}"
    
    local color="${LOG_COLORS[$status]:-$C_RESET}"
    local icon="${LOG_ICONS[$status]:-${LOG_ICONS[INFO]}}"
    
    printf "\033[2m│\033[0m %s %b%s\033[0m\n" "$icon" "$color" "$message"
    log "$status" "$component" "$message"
}

# Progress bar moderne avec estimation de temps
log_progress_modern() {
    local component="$1"
    local step="$2"
    local total="$3"
    local message="$4"
    local start_time="${5:-$(date +%s)}"
    
    local percentage=$((step * 100 / total))
    [[ $percentage -gt 100 ]] && percentage=100
    
    # Calcul du temps restant
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    local eta="--:--"
    
    if [[ $step -gt 0 && $elapsed -gt 0 ]]; then
        local time_per_step=$((elapsed / step))
        local remaining_steps=$((total - step))
        local eta_seconds=$((remaining_steps * time_per_step))
        eta=$(printf "%02d:%02d" $((eta_seconds / 60)) $((eta_seconds % 60)))
    fi
    
    # Barre de progression moderne
    local bar_width=25
    local filled=$((percentage * bar_width / 100))
    local empty=$((bar_width - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    printf "\r${C_PURPLE}${LOG_ICONS[PROGRESS]} [$component]${C_RESET} ${C_AQUA}[$bar]${C_RESET} ${C_BOLD}%3d%%${C_RESET} (%d/%d) ETA: %s - %s" \
           "$percentage" "$step" "$total" "$eta" "$message"
    
    # Nouvelle ligne si terminé
    [[ $step -eq $total ]] && echo
    
    log "INFO" "$component" "Progress: $step/$total ($percentage%) ETA: $eta - $message"
}

# Affichage d'une alerte/notification importante
log_alert() {
    local type="$1"  # INFO, WARN, ERROR, SUCCESS
    local title="$2"
    local message="$3"
    local component="${4:-ALERT}"
    
    local color="${LOG_COLORS[$type]:-$C_RESET}"
    local icon="${LOG_ICONS[$type]:-${LOG_ICONS[INFO]}}"
    
    echo
    echo -e "${color}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${C_RESET}"
    echo -e "${color}┃${C_RESET} $icon ${C_BOLD}$title${C_RESET} $(printf "%*s" $((65 - ${#title})) "") ${color}┃${C_RESET}"
    
    # Découper le message en lignes si nécessaire
    while IFS= read -r line; do
        local line_len=${#line}
        local padding=$((67 - line_len))
        echo -e "${color}┃${C_RESET} $line$(printf "%*s" $padding "")${color}┃${C_RESET}"
    done <<< "$message"
    
    echo -e "${color}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${C_RESET}"
    echo
    
    log "$type" "$component" "$title: $message"
}

# Affichage d'un tableau de statuts
log_status_table() {
    local title="$1"
    shift
    local -a items=("$@")
    
    echo
    echo -e "${C_CYAN}${C_BOLD}$title${C_RESET}"
    echo -e "${C_DIM}$(printf '─%.0s' $(seq 1 50))${C_RESET}"
    
    for item in "${items[@]}"; do
        IFS='|' read -r status name desc <<< "$item"
        local color="${LOG_COLORS[$status]:-$C_RESET}"
        local icon="${LOG_ICONS[$status]:-•}"
        printf " $icon %-20s ${color}%-20s${C_RESET}\n" "$name" "$desc"
    done
    
    echo -e "${C_DIM}$(printf '─%.0s' $(seq 1 50))${C_RESET}"
    echo
}


# Logging d'installation d'assets
log_asset_download() {
    local asset_type="$1"
    local asset_name="$2"
    local status="$3"  # START|SUCCESS|FAILED|SKIPPED
    local size="${4:-}"
    
    local component="ASSETS"
    
    case "$status" in
        "START")
            log_info "$component" "Downloading $asset_type: $asset_name"
            ;;
        "SUCCESS")
            local size_info=""
            [[ -n "$size" ]] && size_info=" ($size)"
            log_info "$component" "✅ Downloaded $asset_type: $asset_name$size_info"
            ;;
        "FAILED")
            log_error "$component" "❌ Failed to download $asset_type: $asset_name"
            ;;
        "SKIPPED")
            log_info "$component" "⏭️ Skipped $asset_type: $asset_name (already exists)"
            ;;
    esac
}

# Logging des services Docker
log_docker_service() {
    local service="$1"
    local action="$2"  # START|STOP|RESTART|STATUS
    local status="$3"   # SUCCESS|FAILED|HEALTHY|UNHEALTHY
    local details="${4:-}"
    
    local component="DOCKER"
    
    case "$action" in
        "START")
            case "$status" in
                "SUCCESS") log_info "$component" "🐳 Service started: $service" ;;
                "FAILED") log_error "$component" "🐳 Failed to start service: $service - $details" ;;
            esac
            ;;
        "STOP")
            case "$status" in
                "SUCCESS") log_info "$component" "🛑 Service stopped: $service" ;;
                "FAILED") log_error "$component" "🛑 Failed to stop service: $service - $details" ;;
            esac
            ;;
        "STATUS")
            case "$status" in
                "HEALTHY") log_info "$component" "✅ Service healthy: $service" ;;
                "UNHEALTHY") log_warn "$component" "⚠️ Service unhealthy: $service - $details" ;;
                "MISSING") log_error "$component" "❌ Service not found: $service" ;;
            esac
            ;;
    esac
}

# --- RAPPORT DE SESSION ---

# Générer un rapport de session
generate_session_report() {
    local session_file="$LOG_DIR/session-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$session_file" << EOF
# J.A.M.Z.I. AI STACK - Session Report

**Date**: $(date '+%Y-%m-%d %H:%M:%S')  
**User**: $(whoami)  
**Directory**: $BASE_DIR  
**Log File**: $LOG_FILE  

## System Information
- **OS**: $(uname -s) $(uname -r)
- **GPU**: ${DETECTED_GPU_NAME:-None detected}
- **VRAM**: ${DETECTED_VRAM_GB:-0}GB
- **Available Disk**: $(df -h "$BASE_DIR" | tail -1 | awk '{print $4}')

## Session Summary
EOF

    # Analyser les logs pour générer des statistiques
    if [[ -f "$LOG_FILE" ]]; then
        local total_info=$(grep -c "\[INFO\]" "$LOG_FILE" 2>/dev/null || echo 0)
        local total_warn=$(grep -c "\[WARN\]" "$LOG_FILE" 2>/dev/null || echo 0)
        local total_error=$(grep -c "\[ERROR\]" "$LOG_FILE" 2>/dev/null || echo 0)
        
        cat >> "$session_file" << EOF
- **Total Info Messages**: $total_info
- **Total Warnings**: $total_warn
- **Total Errors**: $total_error

## Recent Actions
\`\`\`
$(tail -20 "$LOG_FILE" 2>/dev/null || echo "No log entries found")
\`\`\`
EOF
    fi
    
    log_info "LOGGING" "Session report generated: $session_file"
    echo "$session_file"
}

# Rotation des logs
rotate_logs() {
    local max_logs="${1:-10}"
    
    log_info "LOGGING" "Rotating logs (keeping last $max_logs files)"
    
    # Compresser les anciens logs
    find "$LOG_DIR" -name "deployment-*.log" -type f -mtime +1 | while read -r old_log; do
        if [[ ! -f "${old_log}.gz" ]]; then
            gzip "$old_log" 2>/dev/null || true
            log_debug "LOGGING" "Compressed: $(basename "$old_log")"
        fi
    done
    
    # Supprimer les très anciens logs compressés
    find "$LOG_DIR" -name "deployment-*.log.gz" -type f | sort | head -n -"$max_logs" | xargs rm -f 2>/dev/null || true
}

# Initialiser le logging au chargement du module
init_logging