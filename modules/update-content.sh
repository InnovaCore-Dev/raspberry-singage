#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# ACTUALIZACIÓN DE CONTENIDO - Sistema Digital Signage
# ═══════════════════════════════════════════════════════════════════════════

# Cargar dependencias
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
source "${SCRIPT_DIR}/lib/validators.sh"
source "${SCRIPT_DIR}/lib/cache-clean.sh"
source "${SCRIPT_DIR}/lib/chromium-restart.sh"
source "${SCRIPT_DIR}/lib/telegram-notify.sh"

# ───────────────────────────────────────────────────────────────────────────
# Actualizar URL
# ───────────────────────────────────────────────────────────────────────────

update_url() {
    clear
    print_header "ACTUALIZAR URL DEL KIOSCO"

    # Verificar que exista configuración
    if [[ ! -f /etc/signage/kiosk.conf ]]; then
        print_error "El sistema no está configurado"
        print_info "Ejecuta primero la instalación inicial"
        return 1
    fi

    # Cargar configuración actual
    source /etc/signage/kiosk.conf

    print_info "URL actual: ${KIOSK_URL}"
    echo
    print_separator
    echo

    # Pedir nueva URL
    local new_url
    while true; do
        new_url=$(ask_input "Nueva URL" "$KIOSK_URL")

        if [[ "$new_url" == "$KIOSK_URL" ]]; then
            print_warning "La URL no ha cambiado"
            return 0
        fi

        if ! validate_url "$new_url"; then
            print_error "URL inválida (debe comenzar con http:// o https://)"
            continue
        fi

        # Verificar accesibilidad
        print_step "Verificando accesibilidad de la URL..."

        if test_url_accessibility "$new_url" 10; then
            print_success "URL accesible"
            break
        else
            print_warning "No se pudo acceder a la URL"

            if ask_yes_no "¿Deseas usar esta URL de todas formas?" "y"; then
                break
            fi
        fi
    done

    # Actualizar configuración
    save_config "/etc/signage/kiosk.conf" "KIOSK_URL" "$new_url"

    print_success "URL actualizada: ${new_url}"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Limpiar Caché
# ───────────────────────────────────────────────────────────────────────────

clean_cache_menu() {
    clear
    print_header "LIMPIAR CACHÉ DE CHROMIUM"

    # Cargar configuración
    if [[ ! -f /etc/signage/kiosk.conf ]]; then
        print_error "El sistema no está configurado"
        return 1
    fi

    source /etc/signage/kiosk.conf

    # Mostrar estadísticas actuales
    print_info "Caché actual: $(get_cache_stats "$KIOSK_USER")"
    echo

    if ask_yes_no "¿Deseas limpiar la caché?" "y"; then
        clean_chromium_cache "$KIOSK_USER"
        echo
        print_info "Caché después de limpiar: $(get_cache_stats "$KIOSK_USER")"
    fi

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Actualizar Contenido (URL + Caché + Reinicio)
# ───────────────────────────────────────────────────────────────────────────

update_content() {
    clear
    print_header "ACTUALIZAR CONTENIDO"

    echo "Este proceso te permite:"
    echo "  1. Cambiar la URL que se muestra"
    echo "  2. Limpiar la caché de Chromium"
    echo "  3. Reiniciar el navegador con la nueva configuración"
    echo
    print_separator
    echo

    press_any_key

    # PASO 1: Actualizar URL
    if ! update_url; then
        print_error "Error al actualizar URL"
        return 1
    fi

    echo
    press_any_key

    # PASO 2: Limpiar caché
    print_section "LIMPIEZA DE CACHÉ"

    if ask_yes_no "¿Deseas limpiar la caché de Chromium?" "y"; then
        source /etc/signage/kiosk.conf
        clean_chromium_cache "$KIOSK_USER"
    else
        print_info "Saltando limpieza de caché"
    fi

    echo
    press_any_key

    # PASO 3: Reiniciar Chromium
    print_section "REINICIO DE CHROMIUM"

    if ask_yes_no "¿Deseas reiniciar Chromium ahora?" "y"; then
        source /etc/signage/kiosk.conf
        restart_chromium "$KIOSK_USER"

        # Enviar alerta si está configurado
        if is_telegram_configured; then
            source /etc/signage/kiosk.conf
            alert_manual_intervention "$SUDO_USER" "Actualización de contenido (URL: ${KIOSK_URL})"
        fi
    else
        print_warning "Debes reiniciar Chromium manualmente o reiniciar el sistema"
        print_info "Para reiniciar Chromium: systemctl restart lightdm"
        print_info "Para reiniciar sistema: sudo reboot"
    fi

    echo
    print_success "Actualización de contenido completada"

    return 0
}

# Si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_root
    update_content
fi
