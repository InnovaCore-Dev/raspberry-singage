#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# WATCHDOG - Sistema Digital Signage
# Monitoreo continuo del sistema y alertas
# ═══════════════════════════════════════════════════════════════════════════

# Configuración
SCRIPT_DIR="/home/mpeirano/signage-system"
KIOSK_CONF="/etc/signage/kiosk.conf"
TELEGRAM_CONF="/etc/signage/telegram.conf"
TELEGRAM_EVENTS_CONF="/etc/signage/telegram-events.conf"
DEVICE_CONF="/etc/signage/device.conf"

# Variables de estado
CHROMIUM_CRASHES=0
MAX_CRASHES=3
INTERNET_DOWN_SINCE=0
LAST_URL_CHECK=0
LAST_QUEUE_PROCESS=0
TEMP_ALERT_SENT=false

# ───────────────────────────────────────────────────────────────────────────
# Funciones de Utilidad
# ───────────────────────────────────────────────────────────────────────────

log_message() {
    local message="$1"
    logger "KIOSK-WATCHDOG: ${message}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${message}" >> /var/log/signage/watchdog.log
}

get_temperature() {
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        echo $((temp / 1000))
    else
        echo "0"
    fi
}

check_internet() {
    ping -c 1 -W 2 8.8.8.8 &>/dev/null || ping -c 1 -W 2 1.1.1.1 &>/dev/null
}

# ───────────────────────────────────────────────────────────────────────────
# Funciones de Telegram
# ───────────────────────────────────────────────────────────────────────────

send_telegram() {
    local message="$1"

    # Cargar configuración
    [[ ! -f "$TELEGRAM_CONF" ]] && return 1
    source "$TELEGRAM_CONF"

    [[ "$TELEGRAM_ENABLED" != "true" ]] && return 0
    [[ -z "$TELEGRAM_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]] && return 1

    # Verificar internet
    if ! check_internet; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${message}" >> "$ALERT_QUEUE"
        return 1
    fi

    # Enviar mensaje
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="Markdown" >/dev/null 2>&1
}

send_alert() {
    local event_type="$1"
    local details="$2"

    # Cargar configuraciones
    [[ -f "$TELEGRAM_EVENTS_CONF" ]] && source "$TELEGRAM_EVENTS_CONF"
    [[ -f "$DEVICE_CONF" ]] && source "$DEVICE_CONF"

    # Verificar si este tipo de evento está habilitado
    local enabled_var="ALERT_${event_type}"
    [[ "${!enabled_var}" != "true" ]] && return 0

    # Mapeo de emojis
    local emoji
    case "$event_type" in
        REBOOT) emoji="🔄" ;;
        CHROMIUM_CRASH) emoji="❌" ;;
        HIGH_TEMP) emoji="🌡️" ;;
        INTERNET_DOWN) emoji="🌐" ;;
        URL_ERROR) emoji="⚠️" ;;
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

    send_telegram "$message"
}

process_queue() {
    local queue_file="${ALERT_QUEUE:-/var/log/signage-telegram-queue.log}"

    [[ ! -f "$queue_file" ]] || [[ ! -s "$queue_file" ]] && return 0
    check_internet || return 1

    source "$TELEGRAM_CONF" 2>/dev/null
    [[ "$TELEGRAM_ENABLED" != "true" ]] && return 0

    local queue_count=$(wc -l < "$queue_file")
    [[ $queue_count -eq 0 ]] && return 0

    local queue_message="📬 *Mensajes en cola* (${queue_count})

_Estos mensajes no pudieron enviarse por falta de internet:_

"

    local counter=0
    while IFS= read -r line && [[ $counter -lt 10 ]]; do
        queue_message+="${line}"$'\n'
        ((counter++))
    done < "$queue_file"

    [[ $queue_count -gt 10 ]] && queue_message+=$'\n'"_...y $((queue_count - 10)) mensajes más_"

    if send_telegram "$queue_message"; then
        > "$queue_file"
        return 0
    fi

    return 1
}

# ───────────────────────────────────────────────────────────────────────────
# Monitoreo de Chromium
# ───────────────────────────────────────────────────────────────────────────

check_chromium() {
    if ! pgrep -u "${KIOSK_USER}" chromium >/dev/null; then
        CHROMIUM_CRASHES=$((CHROMIUM_CRASHES + 1))

        log_message "Chromium no está corriendo (crash #${CHROMIUM_CRASHES})"

        send_alert "CHROMIUM_CRASH" "Chromium cerrado inesperadamente.
*Intentos de recuperación:* ${CHROMIUM_CRASHES}/${MAX_CRASHES}"

        if [[ $CHROMIUM_CRASHES -ge $MAX_CRASHES ]]; then
            log_message "Demasiados crashes. Reiniciando sistema..."
            send_alert "REBOOT" "Sistema reiniciándose por crashes repetidos de Chromium."
            sleep 5
            reboot
        else
            log_message "Reiniciando LightDM..."
            systemctl restart lightdm
            sleep 10
            CHROMIUM_CRASHES=0
        fi
    else
        # Chromium está corriendo, reset contador
        CHROMIUM_CRASHES=0
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Monitoreo de Temperatura
# ───────────────────────────────────────────────────────────────────────────

check_temperature() {
    local temp=$(get_temperature)
    [[ $temp -eq 0 ]] && return 0

    # Cargar umbral configurado
    local threshold=75
    [[ -f "$TELEGRAM_EVENTS_CONF" ]] && source "$TELEGRAM_EVENTS_CONF"
    threshold="${TEMP_THRESHOLD:-75}"

    if [[ $temp -gt $threshold ]]; then
        if [[ "$TEMP_ALERT_SENT" == "false" ]]; then
            log_message "Temperatura alta: ${temp}°C"
            send_alert "HIGH_TEMP" "⚠️ *Temperatura alta detectada*

*Temperatura actual:* ${temp}°C
*Umbral configurado:* ${threshold}°C

_Verifica la ventilación del dispositivo._"
            TEMP_ALERT_SENT=true
        fi
    else
        # Temperatura normal, reset flag
        TEMP_ALERT_SENT=false
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Monitoreo de Internet
# ───────────────────────────────────────────────────────────────────────────

check_internet_status() {
    # Verificar si esta alerta está habilitada
    [[ -f "$TELEGRAM_EVENTS_CONF" ]] && source "$TELEGRAM_EVENTS_CONF"
    [[ "$ALERT_INTERNET_DOWN" != "true" ]] && return 0

    local now=$(date +%s)
    local threshold_minutes="${INTERNET_DOWN_MINUTES:-30}"

    if ! check_internet; then
        if [[ $INTERNET_DOWN_SINCE -eq 0 ]]; then
            INTERNET_DOWN_SINCE=$now
            log_message "Internet caído detectado"
        fi

        # Calcular minutos sin internet
        local down_minutes=$(( (now - INTERNET_DOWN_SINCE) / 60 ))

        if [[ $down_minutes -ge $threshold_minutes ]]; then
            send_alert "INTERNET_DOWN" "Sin conexión a internet por *${down_minutes} minutos*.

_El sistema funciona en modo caché._"
            # Resetear para evitar spam (enviar cada X minutos)
            INTERNET_DOWN_SINCE=$((now - (threshold_minutes - 1) * 60))
        fi
    else
        # Internet recuperado
        if [[ $INTERNET_DOWN_SINCE -ne 0 ]]; then
            local down_minutes=$(( (now - INTERNET_DOWN_SINCE) / 60 ))
            log_message "Internet recuperado después de ${down_minutes} minutos"
            send_alert "INTERNET_DOWN" "✓ Conexión a internet recuperada.

*Tiempo sin internet:* ${down_minutes} minutos"
            INTERNET_DOWN_SINCE=0

            # Procesar cola de mensajes
            process_queue
        fi
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Verificación de URL
# ───────────────────────────────────────────────────────────────────────────

check_url_accessibility() {
    local now=$(date +%s)

    # Verificar cada 5 minutos
    [[ $((now - LAST_URL_CHECK)) -lt 300 ]] && return 0

    LAST_URL_CHECK=$now

    # Verificar que tengamos internet primero
    check_internet || return 0

    # Verificar URL
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${KIOSK_URL}" 2>/dev/null)

    if [[ -n "$http_code" ]] && [[ ! "$http_code" =~ ^[23] ]]; then
        log_message "Error al acceder a URL: HTTP ${http_code}"
        send_alert "URL_ERROR" "⚠️ *Error al cargar URL*

*URL:* ${KIOSK_URL}
*Código HTTP:* ${http_code}

_Verifica que el servidor web esté funcionando._"
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Procesamiento periódico de cola
# ───────────────────────────────────────────────────────────────────────────

periodic_queue_process() {
    local now=$(date +%s)

    # Procesar cola cada 10 minutos
    [[ $((now - LAST_QUEUE_PROCESS)) -lt 600 ]] && return 0

    LAST_QUEUE_PROCESS=$now

    if check_internet; then
        process_queue
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Loop Principal
# ───────────────────────────────────────────────────────────────────────────

main_loop() {
    # Cargar configuración
    if [[ ! -f "$KIOSK_CONF" ]]; then
        log_message "ERROR: Archivo de configuración no encontrado: $KIOSK_CONF"
        sleep 60
        return 1
    fi

    source "$KIOSK_CONF"

    # Crear directorio de logs si no existe
    mkdir -p /var/log/signage

    log_message "Watchdog iniciado - Monitoreando usuario: ${KIOSK_USER}"

    while true; do
        sleep 30

        # 1. Verificar Chromium
        check_chromium

        # 2. Verificar temperatura
        check_temperature

        # 3. Verificar estado de internet
        check_internet_status

        # 4. Verificar accesibilidad de URL
        check_url_accessibility

        # 5. Procesar cola de mensajes pendientes
        periodic_queue_process
    done
}

# ───────────────────────────────────────────────────────────────────────────
# Inicio
# ───────────────────────────────────────────────────────────────────────────

# Esperar a que el sistema esté completamente iniciado
sleep 15

# Iniciar loop principal
main_loop
