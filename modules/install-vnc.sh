#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# INSTALAR Y CONFIGURAR VNC (wayvnc) - Pi OS Bookworm/Trixie con Wayland
# ═══════════════════════════════════════════════════════════════════════════
#
# Configura wayvnc para compartir el HDMI físico (no escritorio virtual),
# con autenticación username+password y sin renderizar el cursor del cliente
# duplicado en pantalla.
#
# Uso:
#   sudo ./install-vnc.sh [USERNAME] [PASSWORD]
#
# Default: USERNAME=admin PASSWORD=Claude202

set -e

USERNAME="${1:-admin}"
PASSWORD="${2:-Claude202}"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo"
    exit 1
fi

echo "=== Instalando wayvnc (si no está) ==="
apt-get update -qq
apt-get install -y wayvnc >/dev/null

echo "=== Habilitando servicio wayvnc ==="
systemctl enable wayvnc-control.service 2>/dev/null || true
systemctl enable wayvnc.service

echo "=== Generando claves TLS/RSA si faltan ==="
systemctl start wayvnc-generate-keys.service 2>/dev/null || true

echo "=== Quitando --render-cursor del wrapper ==="
# wayvnc envía el cursor del compositor al cliente VNC; con --render-cursor
# además lo dibuja en el framebuffer compartido, lo que hace que se vea
# duplicado en pantalla. Lo removemos.
sed -i 's| --render-cursor||g' /usr/sbin/wayvnc-run.sh

echo "=== Escribiendo /etc/wayvnc/config con auth fija ==="
cat > /etc/wayvnc/config <<EOF
# Configuración generada por install-vnc.sh
address=0.0.0.0
enable_auth=true
enable_pam=false
username=$USERNAME
password=$PASSWORD
private_key_file=/etc/wayvnc/tls_key.pem
certificate_file=/etc/wayvnc/tls_cert.pem
rsa_private_key_file=/etc/wayvnc/rsa_key.pem
EOF
chmod 600 /etc/wayvnc/config

echo "=== Reiniciando wayvnc ==="
systemctl restart wayvnc.service
sleep 2

echo
echo "VNC listo:"
echo "  Host  : $(ip route get 1.1.1.1 2>/dev/null | grep -Po 'src \K\S+' | head -1)"
echo "  Puerto: 5900"
echo "  User  : $USERNAME"
echo "  Pass  : $PASSWORD"
echo
echo "Estado:"
systemctl is-active wayvnc.service
