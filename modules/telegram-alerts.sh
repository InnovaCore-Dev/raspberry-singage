#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN DE ALERTAS TELEGRAM - Sistema Digital Signage
# ═══════════════════════════════════════════════════════════════════════════

# Cargar dependencias
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
source "${SCRIPT_DIR}/lib/validators.sh"
source "${SCRIPT_DIR}/lib/network-check.sh"
source "${SCRIPT_DIR}/lib/telegram-notify.sh"

# Archivos de configuración
TELEGRAM_CONF="/etc/signage/telegram.conf"
TELEGRAM_EVENTS_CONF="/etc/signage/telegram-events.conf"

# ───────────────────────────────────────────────────────────────────────────
# Configurar Telegram Bot
# ───────────────────────────────────────────────────────────────────────────

configure_telegram_bot() {
    clear
    print_header "CONFIGURACIÓN DE TELEGRAM BOT"

    echo "Para recibir alertas necesitas:"
    echo
    echo "1. Crear un bot con @BotFather en Telegram"
    echo "2. Obtener el TOKEN del bot"
    echo "3. Obtener el CHAT_ID (individual o grupo)"
    echo
    print_separator
    echo
    echo "📖 Guía rápida:"
    echo "   • Habla con @BotFather"
    echo "   • Envía: /newbot"
    echo "   • Sigue instrucciones"
    echo "   • Copia el TOKEN"
    echo
    echo "   • Para CHAT_ID de grupo:"
    echo "     - Agrega el bot al grupo"
    echo "     - Envía un mensaje"
    echo "     - Visita: https://api.telegram.org/bot[TOKEN]/getUpdates"
    echo "     - Busca \"chat\":{\"id\": en el JSON"
    echo
    print_separator
    echo

    # Pedir token
    local token
    while true; do
        read -p "Token del Bot: " token

        if [[ -z "$token" ]]; then
            print_error "El token no puede estar vacío"
            continue
        fi

        if ! validate_telegram_token "$token"; then
            print_error "Formato de token inválido (debe ser: 123456789:ABCdef...)"
            continue
        fi

        break
    done

    echo

    # Pedir chat ID
    local chat_id
    while true; do
        read -p "Chat ID (grupo o personal): " chat_id

        if [[ -z "$chat_id" ]]; then
            print_error "El Chat ID no puede estar vacío"
            continue
        fi

        if ! validate_telegram_chat_id "$chat_id"; then
            print_error "Formato de Chat ID inválido (debe ser un número)"
            continue
        fi

        break
    done

    echo
    print_separator
    echo

    # Validar configuración
    print_step "Validando configuración..."

    # Verificar internet
    if ! check_internet false 3 2; then
        print_error "No hay conexión a internet. No se puede validar la configuración."
        echo
        if ask_yes_no "¿Guardar configuración de todas formas?" "n"; then
            save_telegram_config "$token" "$chat_id"
            return 0
        else
            return 1
        fi
    fi

    print_step "Enviando mensaje de prueba..."

    # Probar conexión
    local test_result=$(test_telegram_connection "$token" "$chat_id")
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        print_success "Configuración correcta - Mensaje enviado"
        echo

        if ask_yes_no "¿Guardar configuración?" "y"; then
            save_telegram_config "$token" "$chat_id"
            print_success "Configuración guardada"
            return 0
        else
            return 1
        fi
    else
        print_error "Error: ${test_result}"
        echo
        if ask_yes_no "¿Guardar configuración de todas formas?" "n"; then
            save_telegram_config "$token" "$chat_id"
            return 0
        else
            return 1
        fi
    fi
}

save_telegram_config() {
    local token="$1"
    local chat_id="$2"

    # Crear directorio si no existe
    mkdir -p /etc/signage

    # Guardar configuración
    cat > "$TELEGRAM_CONF" <<EOF
# Configuración de Telegram - Sistema Digital Signage
TELEGRAM_ENABLED="true"
TELEGRAM_TOKEN="${token}"
TELEGRAM_CHAT_ID="${chat_id}"
ALERT_QUEUE="/var/log/signage-telegram-queue.log"
EOF

    # Permisos restrictivos (contiene token sensible)
    chmod 600 "$TELEGRAM_CONF"

    # Crear archivo de cola si no existe
    touch /var/log/signage-telegram-queue.log
    chmod 644 /var/log/signage-telegram-queue.log
}

# ───────────────────────────────────────────────────────────────────────────
# Configurar Eventos
# ───────────────────────────────────────────────────────────────────────────

configure_events() {
    clear
    print_header "CONFIGURACIÓN DE EVENTOS"

    echo "Marca los eventos que deseas recibir:"
    echo

    # Cargar configuración actual si existe
    local event_reboot="true"
    local event_crash="true"
    local event_temp="true"
    local event_internet="false"
    local event_url="true"
    local event_daily="false"
    local event_manual="true"
    local temp_threshold="75"
    local internet_minutes="30"

    if [[ -f "$TELEGRAM_EVENTS_CONF" ]]; then
        source "$TELEGRAM_EVENTS_CONF"
        event_reboot="${ALERT_REBOOT}"
        event_crash="${ALERT_CHROMIUM_CRASH}"
        event_temp="${ALERT_HIGH_TEMP}"
        event_internet="${ALERT_INTERNET_DOWN}"
        event_url="${ALERT_URL_ERROR}"
        event_daily="${ALERT_DAILY_START}"
        event_manual="${ALERT_MANUAL_INTERVENTION}"
        temp_threshold="${TEMP_THRESHOLD:-75}"
        internet_minutes="${INTERNET_DOWN_MINUTES:-30}"
    fi

    # Mostrar opciones con selección actual
    echo "  [1] 🔄 Reinicio del sistema [$( [[ "$event_reboot" == "true" ]] && echo "X" || echo " " )]"
    echo "  [2] ❌ Chromium cerrado inesperadamente [$( [[ "$event_crash" == "true" ]] && echo "X" || echo " " )]"
    echo "  [3] 🌡️ Temperatura alta (>${temp_threshold}°C) [$( [[ "$event_temp" == "true" ]] && echo "X" || echo " " )]"
    echo "  [4] 🌐 Pérdida de internet (después de ${internet_minutes} min) [$( [[ "$event_internet" == "true" ]] && echo "X" || echo " " )]"
    echo "  [5] ⚠️ Error al cargar URL [$( [[ "$event_url" == "true" ]] && echo "X" || echo " " )]"
    echo "  [6] ℹ️ Inicio diario programado [$( [[ "$event_daily" == "true" ]] && echo "X" || echo " " )]"
    echo "  [7] 🔧 Intervención manual en el sistema [$( [[ "$event_manual" == "true" ]] && echo "X" || echo " " )]"
    echo
    print_separator
    echo

    # Pedir selección
    read -p "Ingresar números separados por coma (ej: 1,2,3,5): " selection

    if [[ -z "$selection" ]]; then
        print_warning "No se realizaron cambios"
        return 1
    fi

    # Resetear todos a false
    event_reboot="false"
    event_crash="false"
    event_temp="false"
    event_internet="false"
    event_url="false"
    event_daily="false"
    event_manual="false"

    # Procesar selección
    IFS=',' read -ra EVENTS <<< "$selection"
    for event in "${EVENTS[@]}"; do
        event=$(echo "$event" | tr -d ' ')
        case "$event" in
            1) event_reboot="true" ;;
            2) event_crash="true" ;;
            3) event_temp="true" ;;
            4) event_internet="true" ;;
            5) event_url="true" ;;
            6) event_daily="true" ;;
            7) event_manual="true" ;;
        esac
    done

    echo

    # Configurar umbrales si están habilitados
    if [[ "$event_temp" == "true" ]]; then
        read -p "Umbral de temperatura (°C) [${temp_threshold}]: " new_temp
        temp_threshold="${new_temp:-$temp_threshold}"
    fi

    if [[ "$event_internet" == "true" ]]; then
        read -p "Minutos sin internet antes de alertar [${internet_minutes}]: " new_minutes
        internet_minutes="${new_minutes:-$internet_minutes}"
    fi

    # Guardar configuración
    save_events_config "$event_reboot" "$event_crash" "$event_temp" \
                       "$event_internet" "$event_url" "$event_daily" \
                       "$event_manual" "$temp_threshold" "$internet_minutes"

    print_success "Configuración de eventos guardada"

    return 0
}

save_events_config() {
    local reboot="$1"
    local crash="$2"
    local temp="$3"
    local internet="$4"
    local url="$5"
    local daily="$6"
    local manual="$7"
    local temp_threshold="$8"
    local internet_minutes="$9"

    # Crear directorio si no existe
    mkdir -p /etc/signage

    # Guardar configuración
    cat > "$TELEGRAM_EVENTS_CONF" <<EOF
# Configuración de eventos - Sistema Digital Signage
ALERT_REBOOT="${reboot}"
ALERT_CHROMIUM_CRASH="${crash}"
ALERT_HIGH_TEMP="${temp}"
ALERT_INTERNET_DOWN="${internet}"
ALERT_URL_ERROR="${url}"
ALERT_DAILY_START="${daily}"
ALERT_MANUAL_INTERVENTION="${manual}"

# Umbrales
TEMP_THRESHOLD="${temp_threshold}"
INTERNET_DOWN_MINUTES="${internet_minutes}"
EOF

    chmod 644 "$TELEGRAM_EVENTS_CONF"
}

# ───────────────────────────────────────────────────────────────────────────
# Enviar Alerta de Prueba
# ───────────────────────────────────────────────────────────────────────────

send_test_alert() {
    clear
    print_header "ENVIAR ALERTA DE PRUEBA"

    # Verificar que Telegram esté configurado
    if ! is_telegram_configured; then
        print_error "Telegram no está configurado"
        echo
        print_info "Configura Telegram primero desde la opción 1"
        return 1
    fi

    # Verificar internet
    if ! check_internet false 3 2; then
        print_error "No hay conexión a internet"
        return 1
    fi

    print_step "Enviando alerta de prueba..."
    echo

    # Cargar configuración del dispositivo
    local device_name="Sin configurar"
    if [[ -f /etc/signage/device.conf ]]; then
        source /etc/signage/device.conf
        device_name="${DEVICE_COMPANY} - Pantalla ${DEVICE_ID}"
    fi

    # Construir mensaje
    local message="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧪 *TEST - Sistema de Alertas*

*Pantalla:* ${device_name}
*Hora:* $(date '+%Y-%m-%d %H:%M:%S')
*Estado:* ✓ Operativo

Este es un mensaje de prueba.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo "$message"
    echo
    print_separator
    echo

    # Enviar mensaje
    if send_telegram "$message"; then
        print_success "Mensaje enviado correctamente"
        return 0
    else
        print_error "Error al enviar mensaje"
        return 1
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Desactivar Alertas
# ───────────────────────────────────────────────────────────────────────────

disable_alerts() {
    clear
    print_header "DESACTIVAR ALERTAS"

    if ! is_telegram_configured; then
        print_warning "Las alertas ya están desactivadas"
        return 0
    fi

    echo "¿Estás seguro de que deseas desactivar las alertas?"
    echo

    if ask_yes_no "Desactivar alertas" "n"; then
        # Deshabilitar en configuración
        if [[ -f "$TELEGRAM_CONF" ]]; then
            sed -i 's/^TELEGRAM_ENABLED=.*/TELEGRAM_ENABLED="false"/' "$TELEGRAM_CONF"
            print_success "Alertas desactivadas"
            return 0
        fi
    else
        print_info "Operación cancelada"
        return 1
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Menú Principal de Alertas
# ───────────────────────────────────────────────────────────────────────────

telegram_alerts_menu() {
    while true; do
        clear
        print_header "CONFIGURACIÓN DE ALERTAS POR TELEGRAM"

        # Obtener estado actual
        local status=$(get_telegram_status)
        local status_icon=$( [[ "$status" == "ACTIVO" ]] && echo "✓" || echo "✗" )

        echo "Estado actual: ${status} ${status_icon}"
        echo
        print_separator
        echo
        echo "  [1] ⚙️  Configurar Telegram"
        echo "  [2] 🔔 Configurar qué eventos alertar"
        echo "  [3] 🧪 Enviar alerta de prueba"
        echo "  [4] ❌ Desactivar alertas"
        echo "  [0] ↩️  Volver"
        echo
        print_separator
        echo

        read -p "Opción: " option

        case "$option" in
            1)
                configure_telegram_bot
                press_any_key
                ;;
            2)
                configure_events
                press_any_key
                ;;
            3)
                send_test_alert
                press_any_key
                ;;
            4)
                disable_alerts
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
    telegram_alerts_menu
fi
