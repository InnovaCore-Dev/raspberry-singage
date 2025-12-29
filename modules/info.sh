#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# INFORMACIÓN DEL SISTEMA - Sistema Digital Signage
# ═══════════════════════════════════════════════════════════════════════════

# Cargar dependencias
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
source "${SCRIPT_DIR}/lib/network-check.sh"
source "${SCRIPT_DIR}/lib/cache-clean.sh"
source "${SCRIPT_DIR}/lib/chromium-restart.sh"
source "${SCRIPT_DIR}/lib/telegram-notify.sh"

# ───────────────────────────────────────────────────────────────────────────
# Mostrar Información del Sistema
# ───────────────────────────────────────────────────────────────────────────

show_system_info() {
    clear
    print_header "INFORMACIÓN DEL SISTEMA"

    # ─────────────────────────────────────────────────────────────────────
    # INFORMACIÓN DEL HARDWARE
    # ─────────────────────────────────────────────────────────────────────

    echo -e "${BOLD}═══ HARDWARE ═══${NC}"
    echo

    # Modelo de Raspberry Pi
    if [[ -f /proc/device-tree/model ]]; then
        local model=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')
        echo "  Modelo: ${model}"
    fi

    # Temperatura
    local temp=$(get_temperature)
    local temp_color="${GREEN}"
    if [[ "$temp" != "N/A" ]]; then
        if [[ $temp -gt 75 ]]; then
            temp_color="${RED}"
        elif [[ $temp -gt 60 ]]; then
            temp_color="${YELLOW}"
        fi
    fi
    echo -e "  Temperatura: ${temp_color}${temp}°C${NC}"

    # Memoria
    echo "  Memoria: $(get_memory_usage)"

    # Disco
    echo "  Disco: $(get_disk_usage)"

    # Uptime
    echo "  Uptime: $(get_uptime)"

    echo

    # ─────────────────────────────────────────────────────────────────────
    # INFORMACIÓN DEL DISPOSITIVO
    # ─────────────────────────────────────────────────────────────────────

    echo -e "${BOLD}═══ DISPOSITIVO ═══${NC}"
    echo

    if [[ -f /etc/signage/device.conf ]]; then
        source /etc/signage/device.conf
        echo "  Empresa: ${DEVICE_COMPANY}"
        echo "  Pantalla: ${DEVICE_ID}"
    else
        echo "  ${YELLOW}⚠ No configurado${NC}"
    fi

    echo

    # ─────────────────────────────────────────────────────────────────────
    # INFORMACIÓN DEL KIOSCO
    # ─────────────────────────────────────────────────────────────────────

    echo -e "${BOLD}═══ KIOSCO ═══${NC}"
    echo

    if [[ -f /etc/signage/kiosk.conf ]]; then
        source /etc/signage/kiosk.conf
        echo "  URL: ${KIOSK_URL}"
        echo "  Usuario: ${KIOSK_USER}"

        # Estado de Chromium
        local chromium_status=$(check_chromium_status "$KIOSK_USER")
        if [[ "$chromium_status" == "running" ]]; then
            local chromium_uptime=$(get_chromium_uptime "$KIOSK_USER")
            echo -e "  Estado: ${GREEN}● Corriendo${NC} (${chromium_uptime})"
        else
            echo -e "  Estado: ${RED}○ Detenido${NC}"
        fi

        # Caché
        echo "  Caché: $(get_cache_stats "$KIOSK_USER")"
    else
        echo "  ${YELLOW}⚠ No configurado${NC}"
    fi

    echo

    # ─────────────────────────────────────────────────────────────────────
    # INFORMACIÓN DE RED
    # ─────────────────────────────────────────────────────────────────────

    echo -e "${BOLD}═══ RED ═══${NC}"
    echo

    # Verificar conectividad
    if check_internet false 2 2; then
        echo -e "  Internet: ${GREEN}✓ Conectado${NC}"
    else
        echo -e "  Internet: ${YELLOW}✗ Sin conexión${NC}"
    fi

    # Información de red
    if ip link show eth0 up &>/dev/null; then
        local eth_ip=$(ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        echo "  Ethernet: ${eth_ip:-Conectado sin IP}"
    fi

    if ip link show wlan0 up &>/dev/null; then
        local wifi_ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)
        local wifi_ip=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        if [[ -n "$wifi_ssid" ]]; then
            echo "  Wi-Fi: ${wifi_ssid} (${wifi_ip})"
        fi
    fi

    echo

    # ─────────────────────────────────────────────────────────────────────
    # INFORMACIÓN DE ALERTAS
    # ─────────────────────────────────────────────────────────────────────

    echo -e "${BOLD}═══ ALERTAS ═══${NC}"
    echo

    local telegram_status=$(get_telegram_status)

    if [[ "$telegram_status" == "ACTIVO" ]]; then
        echo -e "  Estado: ${GREEN}✓ Activas${NC}"

        # Eventos configurados
        if [[ -f /etc/signage/telegram-events.conf ]]; then
            source /etc/signage/telegram-events.conf

            local active_events=0
            [[ "$ALERT_REBOOT" == "true" ]] && ((active_events++))
            [[ "$ALERT_CHROMIUM_CRASH" == "true" ]] && ((active_events++))
            [[ "$ALERT_HIGH_TEMP" == "true" ]] && ((active_events++))
            [[ "$ALERT_INTERNET_DOWN" == "true" ]] && ((active_events++))
            [[ "$ALERT_URL_ERROR" == "true" ]] && ((active_events++))
            [[ "$ALERT_DAILY_START" == "true" ]] && ((active_events++))
            [[ "$ALERT_MANUAL_INTERVENTION" == "true" ]] && ((active_events++))

            echo "  Eventos: ${active_events}/7 habilitados"
        fi

        # Cola de mensajes
        if [[ -f /var/log/signage-telegram-queue.log ]] && [[ -s /var/log/signage-telegram-queue.log ]]; then
            local queue_count=$(wc -l < /var/log/signage-telegram-queue.log)
            echo -e "  Cola: ${YELLOW}${queue_count} mensajes pendientes${NC}"
        fi
    else
        echo -e "  Estado: ${YELLOW}✗ Inactivas${NC}"
    fi

    echo

    # ─────────────────────────────────────────────────────────────────────
    # INFORMACIÓN DE SERVICIOS
    # ─────────────────────────────────────────────────────────────────────

    echo -e "${BOLD}═══ SERVICIOS ═══${NC}"
    echo

    # Watchdog
    local watchdog_status=$(service_status "signage-watchdog")
    if [[ "$watchdog_status" == "running" ]]; then
        echo -e "  Watchdog: ${GREEN}● Corriendo${NC}"
    else
        echo -e "  Watchdog: ${RED}○ Detenido${NC}"
    fi

    # LightDM
    local lightdm_status=$(service_status "lightdm")
    if [[ "$lightdm_status" == "running" ]]; then
        echo -e "  LightDM: ${GREEN}● Corriendo${NC}"
    else
        echo -e "  LightDM: ${RED}○ Detenido${NC}"
    fi

    echo
    print_separator
    echo
}

# ───────────────────────────────────────────────────────────────────────────
# Exportar Información (para depuración)
# ───────────────────────────────────────────────────────────────────────────

export_system_info() {
    local output_file="/tmp/signage-info-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "═══════════════════════════════════════════════════════════"
        echo "  INFORMACIÓN DEL SISTEMA - Digital Signage"
        echo "  Generado: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "═══════════════════════════════════════════════════════════"
        echo

        # Hardware
        echo "═══ HARDWARE ═══"
        cat /proc/device-tree/model 2>/dev/null | tr -d '\0'
        echo
        echo "Temperatura: $(get_temperature)°C"
        echo "Memoria: $(get_memory_usage)"
        echo "Disco: $(get_disk_usage)"
        echo "Uptime: $(get_uptime)"
        echo

        # Dispositivo
        echo "═══ DISPOSITIVO ═══"
        if [[ -f /etc/signage/device.conf ]]; then
            cat /etc/signage/device.conf
        else
            echo "No configurado"
        fi
        echo

        # Kiosco
        echo "═══ KIOSCO ═══"
        if [[ -f /etc/signage/kiosk.conf ]]; then
            cat /etc/signage/kiosk.conf
        else
            echo "No configurado"
        fi
        echo

        # Red
        echo "═══ RED ═══"
        ip addr show
        echo

        # Servicios
        echo "═══ SERVICIOS ═══"

        # Verificar si existe signage-watchdog
        if systemctl list-unit-files signage-watchdog.service &>/dev/null && \
           systemctl cat signage-watchdog.service &>/dev/null; then
            systemctl status signage-watchdog --no-pager 2>&1
        else
            echo "signage-watchdog.service - No instalado"
            echo "   Loaded: not-found (El servicio no está configurado)"
            echo "   Nota: El watchdog puede ejecutarse manualmente con watchdog.sh"
        fi
        echo

        systemctl status lightdm --no-pager 2>&1
        echo

        # Logs recientes
        echo "═══ LOGS RECIENTES ═══"

        if systemctl list-unit-files signage-watchdog.service &>/dev/null && \
           systemctl cat signage-watchdog.service &>/dev/null; then
            journalctl -u signage-watchdog -n 50 --no-pager 2>&1
        else
            echo "No hay logs del watchdog (servicio no configurado)"
            echo
            # Mostrar logs del archivo si existe
            if [[ -f /var/log/signage/watchdog.log ]]; then
                echo "Logs del archivo /var/log/signage/watchdog.log:"
                tail -n 20 /var/log/signage/watchdog.log 2>&1
            fi
        fi
        echo

    } > "$output_file"

    echo "$output_file"
}

# Si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_system_info
    echo
    press_any_key
fi
