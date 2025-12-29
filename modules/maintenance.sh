#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# MANTENIMIENTO - Sistema Digital Signage
# ═══════════════════════════════════════════════════════════════════════════

# Cargar dependencias
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
source "${SCRIPT_DIR}/lib/cache-clean.sh"
source "${SCRIPT_DIR}/lib/chromium-restart.sh"
source "${SCRIPT_DIR}/lib/network-check.sh"
source "${SCRIPT_DIR}/lib/telegram-notify.sh"
source "${SCRIPT_DIR}/modules/info.sh"

# ───────────────────────────────────────────────────────────────────────────
# Reiniciar Chromium
# ───────────────────────────────────────────────────────────────────────────

maintenance_restart_chromium() {
    clear
    print_header "REINICIAR CHROMIUM"

    if [[ ! -f /etc/signage/kiosk.conf ]]; then
        print_error "El sistema no está configurado"
        return 1
    fi

    source /etc/signage/kiosk.conf

    echo "Esto reiniciará el navegador Chromium."
    echo

    if ask_yes_no "¿Continuar?" "y"; then
        restart_chromium "$KIOSK_USER"

        # Enviar alerta
        if is_telegram_configured; then
            alert_manual_intervention "$SUDO_USER" "Reinicio manual de Chromium"
        fi
    fi

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Reiniciar Sistema
# ───────────────────────────────────────────────────────────────────────────

maintenance_restart_system() {
    clear
    print_header "REINICIAR SISTEMA"

    echo "Esto reiniciará completamente la Raspberry Pi."
    echo

    if ask_yes_no "¿Estás seguro?" "n"; then
        # Enviar alerta antes de reiniciar
        if is_telegram_configured; then
            alert_reboot "Reinicio manual del sistema"
        fi

        print_info "Reiniciando en 3 segundos..."
        sleep 3
        reboot
    fi

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Limpiar Caché Completa
# ───────────────────────────────────────────────────────────────────────────

maintenance_clean_cache() {
    clear
    print_header "LIMPIEZA COMPLETA DE CACHÉ"

    if [[ ! -f /etc/signage/kiosk.conf ]]; then
        print_error "El sistema no está configurado"
        return 1
    fi

    source /etc/signage/kiosk.conf

    print_info "Caché actual: $(get_cache_stats "$KIOSK_USER")"
    echo

    if ask_yes_no "¿Limpiar caché completa?" "y"; then
        clean_all "$KIOSK_USER"
        echo
        print_info "Caché después de limpiar: $(get_cache_stats "$KIOSK_USER")"
    fi

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Limpiar Logs
# ───────────────────────────────────────────────────────────────────────────

maintenance_clean_logs() {
    clear
    print_header "LIMPIEZA DE LOGS"

    echo "Esto eliminará logs antiguos del sistema."
    echo

    if ask_yes_no "¿Continuar?" "y"; then
        clean_system_logs

        print_success "Logs limpiados"
    fi

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Ver Logs del Watchdog
# ───────────────────────────────────────────────────────────────────────────

maintenance_view_logs() {
    clear
    print_header "LOGS DEL WATCHDOG"

    echo "Mostrando últimas 50 líneas del watchdog:"
    echo
    print_separator
    echo

    journalctl -u signage-watchdog -n 50 --no-pager

    echo
    print_separator
    echo

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Verificar Estado de Servicios
# ───────────────────────────────────────────────────────────────────────────

maintenance_check_services() {
    clear
    print_header "ESTADO DE SERVICIOS"

    echo "═══ WATCHDOG ═══"
    systemctl status signage-watchdog --no-pager
    echo

    echo "═══ LIGHTDM ═══"
    systemctl status lightdm --no-pager
    echo

    print_separator
    echo

    # Opciones de gestión
    echo "Opciones:"
    echo "  [1] Reiniciar watchdog"
    echo "  [2] Reiniciar LightDM"
    echo "  [0] Volver"
    echo

    read -p "Opción: " option

    case "$option" in
        1)
            print_step "Reiniciando watchdog..."
            restart_service "signage-watchdog"
            ;;
        2)
            print_step "Reiniciando LightDM..."
            restart_service "lightdm"
            ;;
        0)
            return 0
            ;;
    esac

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Actualizar Sistema
# ───────────────────────────────────────────────────────────────────────────

maintenance_update_system() {
    clear
    print_header "ACTUALIZAR SISTEMA OPERATIVO"

    echo "Esto actualizará todos los paquetes del sistema."
    echo "ADVERTENCIA: Puede tardar mucho tiempo."
    echo

    if ! ask_yes_no "¿Continuar?" "n"; then
        return 0
    fi

    # Verificar internet
    if ! check_internet true 3 2; then
        print_error "Se requiere conexión a internet"
        return 1
    fi

    # Actualizar lista de paquetes
    print_step "Actualizando lista de paquetes..."
    apt-get update -qq

    # Actualizar paquetes
    print_step "Actualizando paquetes (esto puede tardar varios minutos)..."

    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold"

    print_success "Sistema actualizado"

    echo
    if ask_yes_no "¿Reiniciar sistema ahora?" "n"; then
        reboot
    fi

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Configurar Red
# ───────────────────────────────────────────────────────────────────────────

maintenance_configure_network() {
    clear
    print_header "CONFIGURACIÓN DE RED"

    echo "Red actual:"
    echo
    get_network_info
    echo
    print_separator
    echo

    if ask_yes_no "¿Deseas configurar Wi-Fi?" "y"; then
        show_wifi_menu
    fi

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Exportar Información de Diagnóstico
# ───────────────────────────────────────────────────────────────────────────

maintenance_export_diagnostics() {
    clear
    print_header "EXPORTAR INFORMACIÓN DE DIAGNÓSTICO"

    echo "Esto generará un archivo con información completa del sistema."
    echo

    if ask_yes_no "¿Continuar?" "y"; then
        local output_file=$(export_system_info)

        print_success "Información exportada a: ${output_file}"
        echo
        print_info "Puedes enviar este archivo para soporte técnico"
    fi

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Verificación y Reparación Automática
# ───────────────────────────────────────────────────────────────────────────

maintenance_verify_and_fix() {
    clear

    # Ejecutar script de verificación
    if [[ -x "${SCRIPT_DIR}/verify-and-fix.sh" ]]; then
        "${SCRIPT_DIR}/verify-and-fix.sh"
    else
        print_error "Script de verificación no encontrado"
        print_info "Ruta esperada: ${SCRIPT_DIR}/verify-and-fix.sh"
    fi

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Menú de Mantenimiento
# ───────────────────────────────────────────────────────────────────────────

maintenance_menu() {
    while true; do
        clear
        print_header "MANTENIMIENTO Y DIAGNÓSTICO"

        echo "  [1] 🔄 Reiniciar Chromium"
        echo "  [2] 🔄 Reiniciar Sistema"
        echo "  [3] 🧹 Limpiar caché completa"
        echo "  [4] 🗑️  Limpiar logs antiguos"
        echo "  [5] 📋 Ver logs del watchdog"
        echo "  [6] ⚙️  Verificar servicios"
        echo "  [7] 📦 Actualizar sistema operativo"
        echo "  [8] 🌐 Configurar red"
        echo "  [9] 📊 Exportar información de diagnóstico"
        echo "  [A] 🔧 Verificar y reparar sistema automáticamente"
        echo "  [0] ↩️  Volver"
        echo
        print_separator
        echo

        read -p "Opción: " option

        case "$option" in
            1)
                maintenance_restart_chromium
                press_any_key
                ;;
            2)
                maintenance_restart_system
                # No press_any_key porque reinicia
                ;;
            3)
                maintenance_clean_cache
                press_any_key
                ;;
            4)
                maintenance_clean_logs
                press_any_key
                ;;
            5)
                maintenance_view_logs
                press_any_key
                ;;
            6)
                maintenance_check_services
                press_any_key
                ;;
            7)
                maintenance_update_system
                press_any_key
                ;;
            8)
                maintenance_configure_network
                press_any_key
                ;;
            9)
                maintenance_export_diagnostics
                press_any_key
                ;;
            [aA])
                maintenance_verify_and_fix
                press_any_key
                ;;
            0)
                return 0
                ;;
            *)
                print_error "Opción inválida"
                sleep 1
                ;;
        esac
    done
}

# Si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_root
    maintenance_menu
fi
