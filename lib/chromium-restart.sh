#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# REINICIO DE CHROMIUM - Sistema Digital Signage
# ═══════════════════════════════════════════════════════════════════════════

# Cargar funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"

# ───────────────────────────────────────────────────────────────────────────
# Detener Chromium
# ───────────────────────────────────────────────────────────────────────────

stop_chromium() {
    local username="${1:-$(get_current_user)}"

    print_step "Deteniendo Chromium para usuario: ${username}"

    # Verificar si Chromium está corriendo
    if ! pgrep -u "$username" chromium >/dev/null; then
        print_info "Chromium no está corriendo"
        return 0
    fi

    # Detener Chromium gracefully
    pkill -u "$username" chromium

    # Esperar hasta 5 segundos
    local counter=0
    while pgrep -u "$username" chromium >/dev/null && [[ $counter -lt 5 ]]; do
        sleep 1
        ((counter++))
    done

    # Si todavía está corriendo, forzar detención
    if pgrep -u "$username" chromium >/dev/null; then
        print_warning "Forzando detención de Chromium..."
        pkill -9 -u "$username" chromium
        sleep 1
    fi

    if ! pgrep -u "$username" chromium >/dev/null; then
        print_success "Chromium detenido"
        return 0
    else
        print_error "No se pudo detener Chromium"
        return 1
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Iniciar Chromium
# ───────────────────────────────────────────────────────────────────────────

start_chromium() {
    local username="${1:-$(get_current_user)}"

    # Cargar configuración
    if [[ ! -f /etc/signage/kiosk.conf ]]; then
        print_error "Archivo de configuración no encontrado: /etc/signage/kiosk.conf"
        return 1
    fi

    source /etc/signage/kiosk.conf

    print_step "Iniciando Chromium en modo kiosco..."

    # Verificar si Chromium ya está corriendo
    if pgrep -u "$username" chromium >/dev/null; then
        print_warning "Chromium ya está corriendo"
        return 0
    fi

    # Obtener DISPLAY correcto
    local display_var=$(who | grep "$username" | awk '{print $2}' | head -1)
    if [[ -z "$display_var" ]]; then
        display_var=":0"
    else
        display_var=":0"
    fi

    # Iniciar Chromium como el usuario correcto
    su - "$username" -c "DISPLAY=${display_var} chromium-browser \
        --kiosk \
        --noerrdialogs \
        --disable-infobars \
        --no-first-run \
        --check-for-update-interval=31536000 \
        --disable-session-crashed-bubble \
        --disable-features=TranslateUI \
        --disable-component-update \
        --start-maximized \
        '${KIOSK_URL}' >/dev/null 2>&1 &"

    # Esperar a que Chromium inicie
    sleep 3

    # Verificar que Chromium esté corriendo
    if pgrep -u "$username" chromium >/dev/null; then
        print_success "Chromium iniciado correctamente"
        return 0
    else
        print_error "Error al iniciar Chromium"
        return 1
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Reiniciar Chromium
# ───────────────────────────────────────────────────────────────────────────

restart_chromium() {
    local username="${1:-$(get_current_user)}"

    print_section "REINICIO DE CHROMIUM"

    # Detener Chromium
    if ! stop_chromium "$username"; then
        print_error "Error al detener Chromium"
        return 1
    fi

    # Esperar un momento
    sleep 2

    # Iniciar Chromium
    if ! start_chromium "$username"; then
        print_error "Error al iniciar Chromium"
        return 1
    fi

    print_success "Chromium reiniciado correctamente"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Reiniciar con Limpieza de Caché
# ───────────────────────────────────────────────────────────────────────────

restart_chromium_clean() {
    local username="${1:-$(get_current_user)}"

    print_section "REINICIO DE CHROMIUM CON LIMPIEZA DE CACHÉ"

    # Detener Chromium
    if ! stop_chromium "$username"; then
        print_error "Error al detener Chromium"
        return 1
    fi

    # Limpiar caché
    source "${SCRIPT_DIR}/lib/cache-clean.sh"
    clean_chromium_cache "$username"

    # Esperar un momento
    sleep 2

    # Iniciar Chromium
    if ! start_chromium "$username"; then
        print_error "Error al iniciar Chromium"
        return 1
    fi

    print_success "Chromium reiniciado con caché limpia"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Verificar Estado de Chromium
# ───────────────────────────────────────────────────────────────────────────

check_chromium_status() {
    local username="${1:-$(get_current_user)}"

    if pgrep -u "$username" chromium >/dev/null; then
        echo "running"
        return 0
    else
        echo "stopped"
        return 1
    fi
}

get_chromium_pid() {
    local username="${1:-$(get_current_user)}"

    pgrep -u "$username" chromium | head -1
}

get_chromium_uptime() {
    local username="${1:-$(get_current_user)}"

    local pid=$(get_chromium_pid "$username")

    if [[ -z "$pid" ]]; then
        echo "N/A"
        return 1
    fi

    # Obtener tiempo de inicio del proceso
    local start_time=$(ps -o lstart= -p "$pid" 2>/dev/null)

    if [[ -z "$start_time" ]]; then
        echo "N/A"
        return 1
    fi

    # Calcular uptime
    local start_epoch=$(date -d "$start_time" +%s 2>/dev/null)
    local now_epoch=$(date +%s)
    local uptime_seconds=$((now_epoch - start_epoch))

    # Convertir a formato legible
    local days=$((uptime_seconds / 86400))
    local hours=$(( (uptime_seconds % 86400) / 3600 ))
    local minutes=$(( (uptime_seconds % 3600) / 60 ))

    if [[ $days -gt 0 ]]; then
        echo "${days}d ${hours}h ${minutes}m"
    elif [[ $hours -gt 0 ]]; then
        echo "${hours}h ${minutes}m"
    else
        echo "${minutes}m"
    fi
}
