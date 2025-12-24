#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# INSTALACIÓN RÁPIDA - Sistema Digital Signage
# Completa la instalación automáticamente sin preguntas
# ═══════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"

# Configuración
KIOSK_URL="https://pantallas.innovacore.ar/carniceria01/carniceria01-pantalla01"
KIOSK_USER="mpeirano"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         INSTALACIÓN RÁPIDA - Sistema Digital Signage         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo

# Verificar que sea root
if [[ $EUID -ne 0 ]]; then
    print_error "Este script debe ejecutarse con sudo"
    exit 1
fi

# Verificar que device.conf existe
if [[ ! -f /etc/signage/device.conf ]]; then
    print_error "No existe /etc/signage/device.conf"
    print_info "Ejecuta primero: sudo ./signage-setup.sh y completa el paso 3"
    exit 1
fi

source /etc/signage/device.conf
print_info "Dispositivo: ${DEVICE_COMPANY} - Pantalla ${DEVICE_ID}"
print_info "URL: ${KIOSK_URL}"
print_info "Usuario: ${KIOSK_USER}"
echo

# ═══════════════════════════════════════════════════════════════════════════
# PASO 1: Crear kiosk.conf
# ═══════════════════════════════════════════════════════════════════════════

print_section "PASO 1/8 - CONFIGURACIÓN DEL KIOSCO"

mkdir -p /etc/signage
cat > /etc/signage/kiosk.conf <<EOF
# Configuración del kiosco
KIOSK_URL="${KIOSK_URL}"
KIOSK_USER="${KIOSK_USER}"
EOF

chmod 644 /etc/signage/kiosk.conf
print_success "Configuración guardada"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 2: Configurar Autologin
# ═══════════════════════════════════════════════════════════════════════════

print_section "PASO 2/8 - CONFIGURACIÓN DE AUTOLOGIN"

# LightDM
if [[ -f /etc/lightdm/lightdm.conf ]]; then
    if grep -q "^autologin-user=${KIOSK_USER}" /etc/lightdm/lightdm.conf 2>/dev/null; then
        print_info "Autologin ya configurado en LightDM"
    else
        sed -i "s/^#*autologin-user=.*/autologin-user=${KIOSK_USER}/" /etc/lightdm/lightdm.conf
        sed -i "s/^#*autologin-user-timeout=.*/autologin-user-timeout=0/" /etc/lightdm/lightdm.conf
        print_success "Autologin configurado en LightDM"
    fi
fi

# TTY
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${KIOSK_USER} --noclear %I \$TERM
EOF

print_success "Autologin configurado"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 3: Crear Script de Kiosco
# ═══════════════════════════════════════════════════════════════════════════

print_section "PASO 3/8 - CREACIÓN DE SCRIPT DE KIOSCO"

cat > /usr/local/bin/start-kiosk.sh <<'EOF'
#!/bin/bash

# Esperar a que el entorno gráfico esté listo
sleep 5

# Ocultar cursor
unclutter -idle 0.1 -root &

# Deshabilitar protector de pantalla y ahorro de energía
xset s off
xset -dpms
xset s noblank

# Cargar configuración
source /etc/signage/kiosk.conf

# Detectar nombre del ejecutable de Chromium
CHROMIUM_CMD="chromium-browser"
if ! command -v chromium-browser &>/dev/null; then
    if command -v chromium &>/dev/null; then
        CHROMIUM_CMD="chromium"
    fi
fi

# Iniciar Chromium en modo kiosco
$CHROMIUM_CMD \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --no-first-run \
    --password-store=basic \
    --check-for-update-interval=31536000 \
    --disable-session-crashed-bubble \
    --disable-features=TranslateUI \
    --disable-component-update \
    --start-maximized \
    "${KIOSK_URL}"
EOF

chmod +x /usr/local/bin/start-kiosk.sh
print_success "Script de kiosco creado"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 4: Configurar Autostart
# ═══════════════════════════════════════════════════════════════════════════

print_section "PASO 4/8 - CONFIGURACIÓN DE AUTOSTART"

USER_HOME=$(eval echo "~${KIOSK_USER}")
AUTOSTART_DIR="${USER_HOME}/.config/autostart"

mkdir -p "$AUTOSTART_DIR"

cat > "${AUTOSTART_DIR}/kiosk.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Kiosk
Exec=/usr/local/bin/start-kiosk.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

chown -R ${KIOSK_USER}:${KIOSK_USER} "$AUTOSTART_DIR"
chmod +x "${AUTOSTART_DIR}/kiosk.desktop"

print_success "Autostart configurado"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 5: Instalar Watchdog
# ═══════════════════════════════════════════════════════════════════════════

print_section "PASO 5/8 - INSTALACIÓN DE WATCHDOG"

mkdir -p /var/log/signage

if [[ -f "${SCRIPT_DIR}/watchdog.sh" ]]; then
    cp "${SCRIPT_DIR}/watchdog.sh" /usr/local/bin/signage-watchdog.sh
    chmod +x /usr/local/bin/signage-watchdog.sh
    print_success "Watchdog instalado"
else
    print_error "No se encontró watchdog.sh"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════
# PASO 6: Crear Servicio Watchdog
# ═══════════════════════════════════════════════════════════════════════════

print_section "PASO 6/8 - CREACIÓN DE SERVICIO WATCHDOG"

cat > /etc/systemd/system/signage-watchdog.service <<EOF
[Unit]
Description=Sistema de Monitoreo - Digital Signage
After=lightdm.service

[Service]
Type=simple
ExecStart=/usr/local/bin/signage-watchdog.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable signage-watchdog.service >/dev/null 2>&1

print_success "Servicio watchdog creado y habilitado"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 7: Configurar Arranque Automático
# ═══════════════════════════════════════════════════════════════════════════

print_section "PASO 7/8 - CONFIGURACIÓN DE ARRANQUE AUTOMÁTICO"

if [[ -f /boot/firmware/config.txt ]]; then
    if ! grep -q "# Arranque automático" /boot/firmware/config.txt; then
        echo "" >> /boot/firmware/config.txt
        echo "# Arranque automático después de corte de luz" >> /boot/firmware/config.txt
        echo "# La Pi arrancará automáticamente al recibir corriente" >> /boot/firmware/config.txt
    fi
fi

print_success "Configuración de arranque automático lista"
print_info "Por defecto, Raspberry Pi 4/5 arranca automáticamente al recibir corriente"

# ═══════════════════════════════════════════════════════════════════════════
# PASO 8: Configurar Telegram (Deshabilitado)
# ═══════════════════════════════════════════════════════════════════════════

print_section "PASO 8/8 - CONFIGURACIÓN DE ALERTAS"

cat > /etc/signage/telegram.conf <<EOF
# Configuración de Telegram - Sistema Digital Signage
TELEGRAM_ENABLED="false"
TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""
ALERT_QUEUE="/var/log/signage-telegram-queue.log"
EOF

chmod 600 /etc/signage/telegram.conf
touch /var/log/signage-telegram-queue.log

print_info "Alertas deshabilitadas (puedes configurarlas después)"

# ═══════════════════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════════════════════════════════════

echo
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║               INSTALACIÓN COMPLETADA EXITOSAMENTE             ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo

print_info "Configuración:"
echo "  • Dispositivo: ${DEVICE_COMPANY} - Pantalla ${DEVICE_ID}"
echo "  • URL: ${KIOSK_URL}"
echo "  • Usuario: ${KIOSK_USER}"
echo "  • Alertas: INACTIVO"
echo

print_separator
echo

print_warning "IMPORTANTE:"
echo "  1. El sistema se activará después del reinicio"
echo "  2. Chromium se abrirá automáticamente en modo kiosco"
echo "  3. El watchdog monitoreará el sistema 24/7"
echo "  4. Ante cortes de luz, la Pi arrancará automáticamente"
echo

if ask_yes_no "¿Deseas reiniciar ahora?" "y"; then
    print_info "Reiniciando en 5 segundos..."
    sleep 5
    reboot
else
    print_info "Reinicia manualmente cuando estés listo: sudo reboot"
fi
