#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# VERIFICACIÓN DE INSTALACIÓN - Sistema Digital Signage
# ═══════════════════════════════════════════════════════════════════════════

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_check() {
    local status="$1"
    local message="$2"

    if [[ "$status" == "ok" ]]; then
        echo -e "${GREEN}✓${NC} ${message}"
    elif [[ "$status" == "warn" ]]; then
        echo -e "${YELLOW}⚠${NC} ${message}"
    else
        echo -e "${RED}✗${NC} ${message}"
    fi
}

echo "═══════════════════════════════════════════════════════════════"
echo "  VERIFICACIÓN DE INSTALACIÓN - Sistema Digital Signage"
echo "═══════════════════════════════════════════════════════════════"
echo

# ───────────────────────────────────────────────────────────────────────────
# 1. Verificar archivos de configuración
# ───────────────────────────────────────────────────────────────────────────

echo "1. Archivos de Configuración:"
echo

if [[ -f /etc/signage/kiosk.conf ]]; then
    print_check "ok" "/etc/signage/kiosk.conf existe"
else
    print_check "error" "/etc/signage/kiosk.conf NO EXISTE"
fi

if [[ -f /etc/signage/device.conf ]]; then
    print_check "ok" "/etc/signage/device.conf existe"
else
    print_check "warn" "/etc/signage/device.conf no existe (opcional)"
fi

if [[ -f /etc/signage/telegram.conf ]]; then
    print_check "ok" "/etc/signage/telegram.conf existe"
else
    print_check "warn" "/etc/signage/telegram.conf no existe (opcional)"
fi

echo

# ───────────────────────────────────────────────────────────────────────────
# 2. Verificar scripts instalados
# ───────────────────────────────────────────────────────────────────────────

echo "2. Scripts del Sistema:"
echo

if [[ -f /usr/local/bin/start-kiosk.sh ]] && [[ -x /usr/local/bin/start-kiosk.sh ]]; then
    print_check "ok" "Script de kiosco instalado y ejecutable"
else
    print_check "error" "Script de kiosco NO INSTALADO o sin permisos"
fi

if [[ -f /usr/local/bin/signage-watchdog.sh ]] && [[ -x /usr/local/bin/signage-watchdog.sh ]]; then
    print_check "ok" "Watchdog instalado y ejecutable"
else
    print_check "error" "Watchdog NO INSTALADO o sin permisos"
fi

echo

# ───────────────────────────────────────────────────────────────────────────
# 3. Verificar servicios
# ───────────────────────────────────────────────────────────────────────────

echo "3. Servicios:"
echo

if systemctl is-active --quiet signage-watchdog; then
    print_check "ok" "Servicio watchdog: CORRIENDO"
else
    print_check "error" "Servicio watchdog: DETENIDO"
fi

if systemctl is-enabled --quiet signage-watchdog; then
    print_check "ok" "Servicio watchdog: HABILITADO en arranque"
else
    print_check "error" "Servicio watchdog: NO HABILITADO en arranque"
fi

if systemctl is-active --quiet lightdm; then
    print_check "ok" "Servicio LightDM: CORRIENDO"
else
    print_check "warn" "Servicio LightDM: DETENIDO (normal si estás en consola)"
fi

echo

# ───────────────────────────────────────────────────────────────────────────
# 4. Verificar autologin
# ───────────────────────────────────────────────────────────────────────────

echo "4. Autologin:"
echo

if [[ -f /etc/signage/kiosk.conf ]]; then
    source /etc/signage/kiosk.conf

    if grep -q "^autologin-user=${KIOSK_USER}" /etc/lightdm/lightdm.conf 2>/dev/null; then
        print_check "ok" "Autologin configurado en LightDM para: ${KIOSK_USER}"
    else
        print_check "warn" "Autologin NO configurado en LightDM"
    fi

    if [[ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]]; then
        print_check "ok" "Autologin configurado en consola (TTY)"
    else
        print_check "warn" "Autologin NO configurado en consola"
    fi
fi

echo

# ───────────────────────────────────────────────────────────────────────────
# 5. Verificar autostart
# ───────────────────────────────────────────────────────────────────────────

echo "5. Autostart:"
echo

if [[ -f /etc/signage/kiosk.conf ]]; then
    source /etc/signage/kiosk.conf
    USER_HOME=$(eval echo "~${KIOSK_USER}")

    if [[ -f "${USER_HOME}/.config/autostart/kiosk.desktop" ]]; then
        print_check "ok" "Archivo autostart existe para: ${KIOSK_USER}"

        if [[ -x "${USER_HOME}/.config/autostart/kiosk.desktop" ]]; then
            print_check "ok" "Archivo autostart tiene permisos de ejecución"
        else
            print_check "warn" "Archivo autostart sin permisos de ejecución"
        fi
    else
        print_check "error" "Archivo autostart NO EXISTE"
    fi
fi

echo

# ───────────────────────────────────────────────────────────────────────────
# 6. Verificar Chromium
# ───────────────────────────────────────────────────────────────────────────

echo "6. Chromium:"
echo

if command -v chromium-browser &>/dev/null; then
    print_check "ok" "Chromium instalado: $(chromium-browser --version 2>/dev/null | head -1)"
else
    print_check "error" "Chromium NO INSTALADO"
fi

if [[ -f /etc/signage/kiosk.conf ]]; then
    source /etc/signage/kiosk.conf

    if pgrep -u "${KIOSK_USER}" chromium >/dev/null; then
        print_check "ok" "Chromium está CORRIENDO para usuario: ${KIOSK_USER}"

        # Obtener PID y uptime
        local pid=$(pgrep -u "${KIOSK_USER}" chromium | head -1)
        local start_time=$(ps -o lstart= -p "$pid" 2>/dev/null)

        if [[ -n "$start_time" ]]; then
            echo "   Iniciado: ${start_time}"
        fi
    else
        print_check "warn" "Chromium NO está corriendo (normal si acabas de instalar)"
    fi
fi

echo

# ───────────────────────────────────────────────────────────────────────────
# 7. Verificar paquetes necesarios
# ───────────────────────────────────────────────────────────────────────────

echo "7. Paquetes Necesarios:"
echo

packages=("chromium-browser" "unclutter" "xdotool" "curl" "jq" "bc")

for package in "${packages[@]}"; do
    if dpkg -l 2>/dev/null | grep -q "^ii  $package "; then
        print_check "ok" "${package} instalado"
    else
        print_check "error" "${package} NO INSTALADO"
    fi
done

echo

# ───────────────────────────────────────────────────────────────────────────
# 8. Verificar conectividad
# ───────────────────────────────────────────────────────────────────────────

echo "8. Conectividad:"
echo

if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    print_check "ok" "Internet: CONECTADO"
else
    print_check "warn" "Internet: SIN CONEXIÓN (funciona con caché)"
fi

if [[ -f /etc/signage/kiosk.conf ]]; then
    source /etc/signage/kiosk.conf

    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${KIOSK_URL}" 2>/dev/null)

    if [[ "$http_code" =~ ^[23] ]]; then
        print_check "ok" "URL accesible: ${KIOSK_URL} (HTTP ${http_code})"
    else
        print_check "warn" "URL no accesible: ${KIOSK_URL} (HTTP ${http_code})"
    fi
fi

echo

# ───────────────────────────────────────────────────────────────────────────
# 9. Verificar alertas de Telegram
# ───────────────────────────────────────────────────────────────────────────

echo "9. Alertas de Telegram:"
echo

if [[ -f /etc/signage/telegram.conf ]]; then
    source /etc/signage/telegram.conf

    if [[ "$TELEGRAM_ENABLED" == "true" ]]; then
        print_check "ok" "Alertas: HABILITADAS"

        if [[ -n "$TELEGRAM_TOKEN" ]] && [[ -n "$TELEGRAM_CHAT_ID" ]]; then
            print_check "ok" "Token y Chat ID configurados"
        else
            print_check "error" "Token o Chat ID vacíos"
        fi
    else
        print_check "warn" "Alertas: DESHABILITADAS"
    fi
else
    print_check "warn" "Alertas: NO CONFIGURADAS"
fi

echo

# ───────────────────────────────────────────────────────────────────────────
# 10. Resumen
# ───────────────────────────────────────────────────────────────────────────

echo "═══════════════════════════════════════════════════════════════"
echo "  RESUMEN"
echo "═══════════════════════════════════════════════════════════════"
echo

if [[ -f /etc/signage/kiosk.conf ]]; then
    source /etc/signage/kiosk.conf
    echo "URL Configurada: ${KIOSK_URL}"
    echo "Usuario Kiosco: ${KIOSK_USER}"
fi

if [[ -f /etc/signage/device.conf ]]; then
    source /etc/signage/device.conf
    echo "Dispositivo: ${DEVICE_COMPANY} - Pantalla ${DEVICE_ID}"
fi

echo
echo "Para ver logs en tiempo real:"
echo "  sudo journalctl -u signage-watchdog -f"
echo
echo "Para reiniciar Chromium:"
echo "  sudo systemctl restart lightdm"
echo
echo "Para acceder al menú principal:"
echo "  sudo ./signage-setup.sh"
echo

echo "═══════════════════════════════════════════════════════════════"
