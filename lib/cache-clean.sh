#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# LIMPIEZA DE CACHÉ - Sistema Digital Signage
# ═══════════════════════════════════════════════════════════════════════════

# Cargar funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"

# ───────────────────────────────────────────────────────────────────────────
# Limpieza de Caché de Chromium
# ───────────────────────────────────────────────────────────────────────────

clean_chromium_cache() {
    local username="${1:-$(get_current_user)}"
    local user_home=$(get_user_home "$username")

    print_step "Limpiando caché de Chromium para usuario: ${username}"

    # Verificar que Chromium no esté corriendo
    if pgrep -u "$username" chromium >/dev/null; then
        print_warning "Chromium está corriendo. Deteniendo..."
        pkill -u "$username" chromium
        sleep 2
    fi

    # Rutas de caché de Chromium
    local cache_paths=(
        "${user_home}/.cache/chromium"
        "${user_home}/.config/chromium/Default/Cache"
        "${user_home}/.config/chromium/Default/Code Cache"
        "${user_home}/.config/chromium/Default/GPUCache"
        "${user_home}/.config/chromium/Default/Service Worker"
        "${user_home}/.config/chromium/ShaderCache"
    )

    local total_size=0
    local total_files=0

    # Calcular tamaño total antes de limpiar
    for path in "${cache_paths[@]}"; do
        if [[ -d "$path" ]]; then
            local size=$(du -sb "$path" 2>/dev/null | awk '{print $1}')
            local files=$(find "$path" -type f 2>/dev/null | wc -l)
            total_size=$((total_size + size))
            total_files=$((total_files + files))
        fi
    done

    if [[ $total_size -eq 0 ]]; then
        print_info "No hay caché para limpiar"
        return 0
    fi

    # Convertir bytes a formato legible
    local size_mb=$((total_size / 1024 / 1024))

    print_info "Caché encontrada: ${size_mb} MB (${total_files} archivos)"

    # Limpiar cada ruta
    for path in "${cache_paths[@]}"; do
        if [[ -d "$path" ]]; then
            rm -rf "$path"/* 2>/dev/null
        fi
    done

    print_success "Caché limpiada exitosamente (${size_mb} MB liberados)"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Limpieza de Cookies y Datos de Sesión
# ───────────────────────────────────────────────────────────────────────────

clean_chromium_cookies() {
    local username="${1:-$(get_current_user)}"
    local user_home=$(get_user_home "$username")

    print_step "Limpiando cookies y datos de sesión..."

    # Verificar que Chromium no esté corriendo
    if pgrep -u "$username" chromium >/dev/null; then
        print_warning "Chromium está corriendo. Deteniendo..."
        pkill -u "$username" chromium
        sleep 2
    fi

    # Rutas de cookies y sesión
    local data_paths=(
        "${user_home}/.config/chromium/Default/Cookies"
        "${user_home}/.config/chromium/Default/Cookies-journal"
        "${user_home}/.config/chromium/Default/Session Storage"
        "${user_home}/.config/chromium/Default/Local Storage"
    )

    # Limpiar cada ruta
    for path in "${data_paths[@]}"; do
        if [[ -e "$path" ]]; then
            rm -rf "$path" 2>/dev/null
        fi
    done

    print_success "Cookies y datos de sesión limpiados"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Limpieza Completa (Caché + Cookies)
# ───────────────────────────────────────────────────────────────────────────

clean_all() {
    local username="${1:-$(get_current_user)}"

    print_section "LIMPIEZA COMPLETA DE CHROMIUM"

    clean_chromium_cache "$username"
    clean_chromium_cookies "$username"

    print_success "Limpieza completa finalizada"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Limpieza de Logs del Sistema
# ───────────────────────────────────────────────────────────────────────────

clean_system_logs() {
    print_step "Limpiando logs antiguos del sistema..."

    # Limpiar logs de más de 7 días
    if [[ -d /var/log/signage ]]; then
        find /var/log/signage -name "*.log" -type f -mtime +7 -delete 2>/dev/null
    fi

    # Rotar journal de systemd (mantener solo 3 días)
    journalctl --vacuum-time=3d >/dev/null 2>&1

    print_success "Logs del sistema limpiados"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Obtener Estadísticas de Caché
# ───────────────────────────────────────────────────────────────────────────

get_cache_stats() {
    local username="${1:-$(get_current_user)}"
    local user_home=$(get_user_home "$username")

    # Rutas de caché de Chromium
    local cache_paths=(
        "${user_home}/.cache/chromium"
        "${user_home}/.config/chromium/Default/Cache"
        "${user_home}/.config/chromium/Default/Code Cache"
    )

    local total_size=0
    local total_files=0

    # Calcular tamaño total
    for path in "${cache_paths[@]}"; do
        if [[ -d "$path" ]]; then
            local size=$(du -sb "$path" 2>/dev/null | awk '{print $1}')
            local files=$(find "$path" -type f 2>/dev/null | wc -l)
            total_size=$((total_size + size))
            total_files=$((total_files + files))
        fi
    done

    # Convertir bytes a formato legible
    local size_mb=$((total_size / 1024 / 1024))

    echo "${size_mb} MB (${total_files} archivos)"
}
