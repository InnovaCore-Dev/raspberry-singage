#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# NOTIFICACIONES TELEGRAM - Sistema Digital Signage
# ═══════════════════════════════════════════════════════════════════════════

# Cargar funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"

# Archivos de configuración
TELEGRAM_CONF="/etc/signage/telegram.conf"
TELEGRAM_EVENTS_CONF="/etc/signage/telegram-events.conf"
DEVICE_CONF="/etc/signage/device.conf"
ALERT_QUEUE="/var/log/signage-telegram-queue.log"

# ───────────────────────────────────────────────────────────────────────────
# Envío de Mensajes
# ───────────────────────────────────────────────────────────────────────────

send_telegram() {
    local message="$1"
    local parse_mode="${2:-Markdown}"

    # Cargar configuración
    if [[ ! -f "$TELEGRAM_CONF" ]]; then
        return 1
    fi

    source "$TELEGRAM_CONF"

    if [[ "$TELEGRAM_ENABLED" != "true" ]]; then
        return 0
    fi

    # Verificar que tenemos token y chat_id
    if [[ -z "$TELEGRAM_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        return 1
    fi

    # Verificar internet
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        # Sin internet, guardar en cola
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${message}" >> "$ALERT_QUEUE"
        return 1
    fi

    # Enviar mensaje
    local response=$(curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="${parse_mode}" \
        2>&1)

    # Verificar éxito
    if echo "$response" | grep -q '"ok":true'; then
        return 0
    else
        # Error al enviar, guardar en cola
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${message}" >> "$ALERT_QUEUE"
        return 1
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Sistema de Alertas
# ───────────────────────────────────────────────────────────────────────────

send_alert() {
    local event_type="$1"
    local details="$2"

    # Cargar configuraciones
    [[ -f "$TELEGRAM_EVENTS_CONF" ]] && source "$TELEGRAM_EVENTS_CONF"
    [[ -f "$DEVICE_CONF" ]] && source "$DEVICE_CONF"

    # Verificar si este tipo de evento está habilitado
    local enabled_var="ALERT_${event_type}"
    if [[ "${!enabled_var}" != "true" ]]; then
        return 0
    fi

    # Mapeo de emojis por tipo de evento
    local emoji
    case "$event_type" in
        REBOOT) emoji="🔄" ;;
        CHROMIUM_CRASH) emoji="❌" ;;
        HIGH_TEMP) emoji="🌡️" ;;
        INTERNET_DOWN) emoji="🌐" ;;
        URL_ERROR) emoji="⚠️" ;;
        DAILY_START) emoji="ℹ️" ;;
        MANUAL_INTERVENTION) emoji="🔧" ;;
        *) emoji="📢" ;;
    esac

    # Obtener información del dispositivo
    local device_name="${DEVICE_COMPANY:-Sin configurar} - Pantalla ${DEVICE_ID:-?}"

    # Construir mensaje
    local message="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${emoji} *ALERTA - Sistema Digital Signage*

*Pantalla:* ${device_name}
*Hora:* $(date '+%Y-%m-%d %H:%M:%S')
*Evento:* ${event_type}

${details}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Enviar alerta
    send_telegram "$message"
}

# ───────────────────────────────────────────────────────────────────────────
# Procesar Cola de Mensajes Pendientes
# ───────────────────────────────────────────────────────────────────────────

process_queue() {
    if [[ ! -f "$ALERT_QUEUE" ]] || [[ ! -s "$ALERT_QUEUE" ]]; then
        return 0
    fi

    # Verificar internet
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        return 1
    fi

    # Cargar configuración
    if [[ ! -f "$TELEGRAM_CONF" ]]; then
        return 1
    fi

    source "$TELEGRAM_CONF"

    if [[ "$TELEGRAM_ENABLED" != "true" ]]; then
        return 0
    fi

    # Contar mensajes en cola
    local queue_count=$(wc -l < "$ALERT_QUEUE")

    if [[ $queue_count -eq 0 ]]; then
        return 0
    fi

    # Enviar resumen de cola
    local queue_message="📬 *Mensajes en cola* (${queue_count})

_Estos mensajes no pudieron enviarse por falta de internet:_

"

    # Agregar primeros 10 mensajes
    local counter=0
    while IFS= read -r line && [[ $counter -lt 10 ]]; do
        queue_message+="${line}"$'\n'
        ((counter++))
    done < "$ALERT_QUEUE"

    if [[ $queue_count -gt 10 ]]; then
        queue_message+=$'\n'"_...y $((queue_count - 10)) mensajes más_"
    fi

    # Enviar resumen
    if send_telegram "$queue_message"; then
        # Limpiar cola si se envió exitosamente
        > "$ALERT_QUEUE"
        return 0
    else
        return 1
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Alertas Específicas
# ───────────────────────────────────────────────────────────────────────────

alert_reboot() {
    local reason="${1:-manual}"

    local details="Sistema reiniciándose.

*Motivo:* ${reason}
*Uptime anterior:* $(uptime -p | sed 's/up //')"

    send_alert "REBOOT" "$details"
}

alert_chromium_crash() {
    local crash_count="$1"
    local max_crashes="$2"

    local details="Chromium cerrado inesperadamente.

*Intentos de recuperación:* ${crash_count}/${max_crashes}
*Acción:* Reiniciando servicio..."

    send_alert "CHROMIUM_CRASH" "$details"
}

alert_high_temp() {
    local current_temp="$1"
    local threshold="$2"

    local details="⚠️ *Temperatura alta detectada*

*Temperatura actual:* ${current_temp}°C
*Umbral configurado:* ${threshold}°C

_Verifica la ventilación del dispositivo._"

    send_alert "HIGH_TEMP" "$details"
}

alert_internet_down() {
    local down_minutes="$1"

    local details="Sin conexión a internet por *${down_minutes} minutos*.

_El sistema funciona en modo caché._"

    send_alert "INTERNET_DOWN" "$details"
}

alert_internet_restored() {
    local down_minutes="$1"

    local details="✓ Conexión a internet recuperada.

*Tiempo sin internet:* ${down_minutes} minutos"

    send_alert "INTERNET_DOWN" "$details"
}

alert_url_error() {
    local url="$1"
    local http_code="$2"

    local details="⚠️ *Error al cargar URL*

*URL:* ${url}
*Código HTTP:* ${http_code}

_Verifica que el servidor web esté funcionando._"

    send_alert "URL_ERROR" "$details"
}

alert_daily_start() {
    local details="Sistema iniciado correctamente.

*Tipo:* Reinicio programado
*Temperatura:* $(get_temperature)°C
*Estado:* ✓ Operativo"

    send_alert "DAILY_START" "$details"
}

alert_manual_intervention() {
    local user="${1:-root}"
    local action="${2:-acceso al sistema}"

    local details="Usuario accedió al sistema de configuración.

*Usuario:* ${user}
*Acción:* ${action}"

    send_alert "MANUAL_INTERVENTION" "$details"
}

# ───────────────────────────────────────────────────────────────────────────
# Utilidades
# ───────────────────────────────────────────────────────────────────────────

is_telegram_configured() {
    if [[ ! -f "$TELEGRAM_CONF" ]]; then
        return 1
    fi

    source "$TELEGRAM_CONF"

    if [[ "$TELEGRAM_ENABLED" != "true" ]]; then
        return 1
    fi

    if [[ -z "$TELEGRAM_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        return 1
    fi

    return 0
}

get_telegram_status() {
    if is_telegram_configured; then
        echo "ACTIVO"
    else
        echo "INACTIVO"
    fi
}
