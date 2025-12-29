#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# SISTEMA DE PANTALLAS DIGITALES - MENÚ PRINCIPAL
# InnovaCore - v1.0.0
# ═══════════════════════════════════════════════════════════════════════════

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar módulos
source "${SCRIPT_DIR}/modules/common.sh"
source "${SCRIPT_DIR}/lib/telegram-notify.sh"
source "${SCRIPT_DIR}/modules/install.sh"
source "${SCRIPT_DIR}/modules/update-content.sh"
source "${SCRIPT_DIR}/modules/info.sh"
source "${SCRIPT_DIR}/modules/maintenance.sh"
source "${SCRIPT_DIR}/modules/telegram-alerts.sh"

# ───────────────────────────────────────────────────────────────────────────
# Funciones de Menú
# ───────────────────────────────────────────────────────────────────────────

show_main_menu() {
    clear

    # Obtener información del dispositivo
    local device_info="No configurado"
    local alerts_status="✗ Inactivas"

    if [[ -f /etc/signage/device.conf ]]; then
        source /etc/signage/device.conf
        device_info="${DEVICE_COMPANY} - Pantalla ${DEVICE_ID}"
    fi

    if [[ "$(get_telegram_status)" == "ACTIVO" ]]; then
        alerts_status="✓ Activas"
    fi

    # Mostrar encabezado
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║     SISTEMA DE PANTALLAS DIGITALES - MENÚ PRINCIPAL          ║"
    echo "║                    InnovaCore - v${VERSION}                        ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo
    echo "Dispositivo configurado: ${device_info}"
    echo "Alertas: ${alerts_status}"
    echo
    echo "Seleccione una opción:"
    echo
    echo "  [1] 🆕 INSTALACIÓN INICIAL"
    echo "      └─ Configurar nueva Raspberry Pi desde cero"
    echo "      └─ Tiempo estimado: 15 minutos"
    echo
    echo "  [2] 🔄 ACTUALIZAR CONTENIDO"
    echo "      └─ Cambiar URL y limpiar caché"
    echo "      └─ Tiempo estimado: 2 minutos"
    echo
    echo "  [3] ℹ️  INFORMACIÓN DEL SISTEMA"
    echo "      └─ Ver configuración y estado actual"
    echo
    echo "  [4] 🔧 MANTENIMIENTO"
    echo "      └─ Herramientas de diagnóstico y mantenimiento"
    echo
    echo "  [5] 📱 CONFIGURAR ALERTAS"
    echo "      └─ Notificaciones por Telegram"
    echo
    echo "  [0] ❌ Salir"
    echo
    print_separator
    echo
}

# ───────────────────────────────────────────────────────────────────────────
# Opción 1: Instalación Inicial
# ───────────────────────────────────────────────────────────────────────────

option_install() {
    # Verificar si ya está instalado
    if [[ -f /etc/signage/kiosk.conf ]]; then
        clear
        print_header "ADVERTENCIA"

        echo "El sistema ya está instalado."
        echo

        if ask_yes_no "¿Deseas reinstalar? (Se perderá la configuración actual)" "n"; then
            run_installation
        fi
    else
        run_installation
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Opción 2: Actualizar Contenido
# ───────────────────────────────────────────────────────────────────────────

option_update_content() {
    # Verificar que esté instalado
    if [[ ! -f /etc/signage/kiosk.conf ]]; then
        clear
        print_header "ERROR"

        echo "El sistema no está instalado."
        echo
        print_info "Ejecuta primero la opción 1: Instalación Inicial"
        echo
        press_any_key
        return 1
    fi

    update_content
}

# ───────────────────────────────────────────────────────────────────────────
# Opción 3: Información del Sistema
# ───────────────────────────────────────────────────────────────────────────

option_show_info() {
    show_system_info
    press_any_key
}

# ───────────────────────────────────────────────────────────────────────────
# Opción 4: Mantenimiento
# ───────────────────────────────────────────────────────────────────────────

option_maintenance() {
    maintenance_menu
}

# ───────────────────────────────────────────────────────────────────────────
# Opción 5: Configurar Alertas
# ───────────────────────────────────────────────────────────────────────────

option_alerts() {
    telegram_alerts_menu
}

# ───────────────────────────────────────────────────────────────────────────
# Loop Principal del Menú
# ───────────────────────────────────────────────────────────────────────────

main_menu_loop() {
    # Enviar alerta de intervención manual si está configurado
    if is_telegram_configured; then
        local current_user="${SUDO_USER:-$USER}"
        alert_manual_intervention "$current_user" "Acceso al menú de configuración"
    fi

    while true; do
        show_main_menu

        read -p "Opción [0-5]: " option

        case "$option" in
            1)
                # Ejecutar instalación
                if run_installation; then
                    echo
                    print_success "Instalación completada"
                else
                    echo
                    print_warning "La instalación terminó con algunos avisos o errores menores."
                    print_info "Ejecutando verificación y reparación final de seguridad..."
                    # Ejecutar el script de verificación y reparación automáticamente
                    if [[ -f "${SCRIPT_DIR}/verify-and-fix.sh" ]]; then
                        sudo bash "${SCRIPT_DIR}/verify-and-fix.sh"
                    fi
                fi
                press_any_key
                ;;
            2)
                option_update_content
                press_any_key
                ;;
            3)
                option_show_info
                ;;
            4)
                option_maintenance
                ;;
            5)
                option_alerts
                ;;
            0)
                clear
                print_info "Gracias por usar el Sistema de Pantallas Digitales"
                echo
                exit 0
                ;;
            *)
                print_error "Opción inválida"
                sleep 1
                ;;
        esac
    done
}

# ───────────────────────────────────────────────────────────────────────────
# Inicio del Script
# ───────────────────────────────────────────────────────────────────────────

# Verificar que sea root
if [[ $EUID -ne 0 ]]; then
    echo
    print_error "Este script debe ejecutarse con privilegios de root"
    echo
    print_info "Ejecuta: sudo $0"
    echo
    exit 1
fi

# Verificar que sea Raspberry Pi
if [[ ! -f /proc/device-tree/model ]]; then
    echo
    print_error "Este script está diseñado para ejecutarse en Raspberry Pi"
    echo
    exit 1
fi

# Iniciar menú principal
main_menu_loop
