#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# FUNCIONES COMPARTIDAS - Sistema Digital Signage
# ═══════════════════════════════════════════════════════════════════════════

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Versión del sistema
VERSION="1.0.0"

# ───────────────────────────────────────────────────────────────────────────
# Funciones de Output
# ───────────────────────────────────────────────────────────────────────────

print_header() {
    local title="$1"
    echo -e "\n${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    printf "${BOLD}║%-63s║${NC}\n" "  $title"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}\n"
}

print_section() {
    local title="$1"
    echo -e "\n${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $title${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}\n"
}

print_separator() {
    echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_step() {
    echo -e "${CYAN}▶${NC} $1"
}

# ───────────────────────────────────────────────────────────────────────────
# Funciones de Verificación
# ───────────────────────────────────────────────────────────────────────────

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este script debe ejecutarse con privilegios de root (sudo)"
        exit 1
    fi
}

check_raspberry_pi() {
    if [[ ! -f /proc/device-tree/model ]]; then
        print_error "Este script está diseñado para ejecutarse en Raspberry Pi"
        exit 1
    fi

    local model=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')
    print_info "Detectado: ${model}"
}

# ───────────────────────────────────────────────────────────────────────────
# Funciones de Instalación de Paquetes
# ───────────────────────────────────────────────────────────────────────────

install_package() {
    local package="$1"
    local max_retries=2
    local retry_count=0

    print_step "Verificando ${package}..."

    # Log para debugging
    if type -t log_info &>/dev/null; then
        log_info "Verificando paquete: ${package}"
    fi

    if dpkg -l 2>/dev/null | grep -q "^ii  $package "; then
        print_success "${package} ya está instalado"
        if type -t log_success &>/dev/null; then
            log_success "Paquete ${package} ya está instalado"
        fi
        return 0
    fi

    # Manejar bloqueos de APT
    while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/lib/dpkg/lock >/dev/null 2>&1; do
        print_warning "Esperando a que se liberen los bloqueos de APT (otro proceso está actualizando)..."
        sleep 5
    done

    while [ $retry_count -le $max_retries ]; do
        print_step "Instalando ${package}..."
        if type -t log_info &>/dev/null; then
            log_info "Instalando paquete: ${package} (Intento $((retry_count + 1)))"
        fi

        # Guardar salida en archivo temporal para logging
        local apt_output=$(mktemp)

        if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            "$package" >"$apt_output" 2>&1; then

            if dpkg -l 2>/dev/null | grep -q "^ii  $package "; then
                print_success "${package} instalado correctamente"
                if type -t log_success &>/dev/null; then
                    log_success "Paquete ${package} instalado correctamente"
                fi
                rm -f "$apt_output"
                return 0
            fi
        fi

        # Si falla, intentar reparar el sistema antes de reintentar
        print_warning "Fallo en la instalación de ${package}. Intentando reparar dependencias..."
        if type -t log_warning &>/dev/null; then
            log_warning "Fallo instalación de ${package}. Ejecutando reparación automática..."
        fi
        
        dpkg --configure -a >/dev/null 2>&1
        apt-get install -f -y -qq >/dev/null 2>&1
        
        ((retry_count++))
        rm -f "$apt_output"
        
        if [ $retry_count -le $max_retries ]; then
            print_info "Reintentando instalación de ${package}..."
            sleep 2
        fi
    done

    # Si después de los reintentos sigue fallando
    print_error "Error persistente al instalar ${package}"
    if type -t log_error &>/dev/null; then
        log_error "Error persistente al instalar ${package} después de $max_retries reintentos"
    fi

    return 1
}

update_package_list() {
    print_step "Actualizando lista de paquetes..."

    if apt-get update -qq >/dev/null 2>&1; then
        print_success "Lista de paquetes actualizada"
        return 0
    else
        print_error "Error al actualizar lista de paquetes"
        return 1
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Funciones de Configuración
# ───────────────────────────────────────────────────────────────────────────

get_current_user() {
    # Obtener el usuario real (no root) que ejecutó sudo
    if [[ -n "$SUDO_USER" ]]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
    fi
}

get_user_home() {
    local username="$1"
    eval echo "~$username"
}

# ───────────────────────────────────────────────────────────────────────────
# Funciones de Archivos de Configuración
# ───────────────────────────────────────────────────────────────────────────

load_config() {
    local config_file="$1"

    if [[ -f "$config_file" ]]; then
        source "$config_file"
        return 0
    else
        return 1
    fi
}

save_config() {
    local config_file="$1"
    local key="$2"
    local value="$3"

    # Crear directorio si no existe
    mkdir -p "$(dirname "$config_file")"

    # Si el archivo no existe, crearlo
    touch "$config_file"

    # Actualizar o agregar la clave
    if grep -q "^${key}=" "$config_file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$config_file"
    else
        echo "${key}=\"${value}\"" >> "$config_file"
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Funciones de Entrada de Usuario
# ───────────────────────────────────────────────────────────────────────────

ask_yes_no() {
    local question="$1"
    local default="${2:-n}"
    local response

    if [[ "$default" == "y" ]]; then
        read -p "$question (S/n): " response
        response=${response:-s}
    else
        read -p "$question (s/N): " response
        response=${response:-n}
    fi

    case "$response" in
        [sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

ask_input() {
    local question="$1"
    local default="$2"
    local response

    if [[ -n "$default" ]]; then
        read -p "$question [$default]: " response
        echo "${response:-$default}"
    else
        read -p "$question: " response
        echo "$response"
    fi
}

press_any_key() {
    local message="${1:-Presiona cualquier tecla para continuar...}"
    read -n 1 -s -r -p "$message"
    echo
}

# ───────────────────────────────────────────────────────────────────────────
# Funciones de Sistema
# ───────────────────────────────────────────────────────────────────────────

get_temperature() {
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        echo $((temp / 1000))
    else
        echo "N/A"
    fi
}

get_uptime() {
    uptime -p | sed 's/up //'
}

get_memory_usage() {
    free -h | awk '/^Mem:/ {print $3 "/" $2}'
}

get_disk_usage() {
    df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}'
}

# ───────────────────────────────────────────────────────────────────────────
# Funciones de Servicio Systemd
# ───────────────────────────────────────────────────────────────────────────

create_systemd_service() {
    local service_name="$1"
    local service_file="/etc/systemd/system/${service_name}.service"
    local service_content="$2"

    echo "$service_content" > "$service_file"

    systemctl daemon-reload
    systemctl enable "$service_name" >/dev/null 2>&1

    print_success "Servicio ${service_name} creado y habilitado"
}

start_service() {
    local service_name="$1"

    if systemctl start "$service_name" >/dev/null 2>&1; then
        print_success "Servicio ${service_name} iniciado"
        return 0
    else
        print_error "Error al iniciar servicio ${service_name}"
        return 1
    fi
}

stop_service() {
    local service_name="$1"

    if systemctl stop "$service_name" >/dev/null 2>&1; then
        print_success "Servicio ${service_name} detenido"
        return 0
    else
        print_error "Error al detener servicio ${service_name}"
        return 1
    fi
}

restart_service() {
    local service_name="$1"

    if systemctl restart "$service_name" >/dev/null 2>&1; then
        print_success "Servicio ${service_name} reiniciado"
        return 0
    else
        print_error "Error al reiniciar servicio ${service_name}"
        return 1
    fi
}

service_status() {
    local service_name="$1"

    if systemctl is-active --quiet "$service_name"; then
        echo "running"
    else
        echo "stopped"
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Funciones de Progreso
# ───────────────────────────────────────────────────────────────────────────

show_progress() {
    local current="$1"
    local total="$2"
    local text="$3"

    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))

    printf "\r${CYAN}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "]${NC} ${percent}%% - ${text}    "
}

clear_progress() {
    echo -e "\r\033[K"
}

# ───────────────────────────────────────────────────────────────────────────
# Funciones de Log
# ───────────────────────────────────────────────────────────────────────────

log_message() {
    local level="$1"
    local message="$2"
    local log_file="${3:-/var/log/signage-system.log}"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "$log_file"
}

log_info() {
    log_message "INFO" "$1" "$2"
}

log_error() {
    log_message "ERROR" "$1" "$2"
}

log_warning() {
    log_message "WARNING" "$1" "$2"
}
