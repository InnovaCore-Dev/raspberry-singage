#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# MODO VERTICAL (PORTRAIT) - OPCIONAL - Pi OS Wayland (labwc + kanshi)
# ═══════════════════════════════════════════════════════════════════════════
#
# Rota la salida HDMI a vertical de forma persistente vía kanshi.
# NO es por defecto: solo correr este script en pantallas que se montan en
# orientación vertical.
#
# Pi OS con labwc/Wayland NO usa display_rotate del config.txt — eso es para
# el modo Legacy/X11. Aquí se usa kanshi, que persiste la rotación entre
# arranques.
#
# Uso:
#   sudo ./vertical-mode.sh [USUARIO_KIOSK] [TRANSFORM]
#
#   TRANSFORM:
#     90       = girar 90° anti-horario (vertical, parte superior a la izquierda)
#     270      = girar 90° horario (vertical, parte superior a la derecha) ← más común
#     180      = invertir (cabeza abajo)
#     normal   = volver a horizontal
#
# Default: USUARIO_KIOSK=mpeirano  TRANSFORM=270

set -e

TARGET_USER="${1:-mpeirano}"
TRANSFORM="${2:-270}"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo"
    exit 1
fi

if ! id -u "$TARGET_USER" >/dev/null 2>&1; then
    echo "ERROR: el usuario $TARGET_USER no existe"
    exit 1
fi

# Validar TRANSFORM
case "$TRANSFORM" in
    normal|90|180|270|flipped|flipped-90|flipped-180|flipped-270) ;;
    *)
        echo "ERROR: TRANSFORM inválido: $TRANSFORM"
        echo "Valores válidos: normal, 90, 180, 270"
        exit 1
        ;;
esac

USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
KANSHI_DIR="$USER_HOME/.config/kanshi"

echo "=== Detectando output HDMI activo ==="
OUTPUT=""
if command -v wlr-randr >/dev/null && [[ -S "/run/user/$(id -u $TARGET_USER)/wayland-0" ]]; then
    OUTPUT=$(sudo -u "$TARGET_USER" \
        XDG_RUNTIME_DIR="/run/user/$(id -u $TARGET_USER)" \
        WAYLAND_DISPLAY=wayland-0 \
        wlr-randr 2>/dev/null | awk '/^[A-Z]/{print $1; exit}')
fi
if [[ -z "$OUTPUT" ]]; then
    echo "AVISO: no pude detectar el output activo. Uso HDMI-A-1 como fallback."
    echo "       Si no es el correcto, editá $KANSHI_DIR/config a mano."
    OUTPUT="HDMI-A-1"
else
    echo "Output detectado: $OUTPUT"
fi

echo "=== Escribiendo $KANSHI_DIR/config (transform=$TRANSFORM) ==="
sudo -u "$TARGET_USER" mkdir -p "$KANSHI_DIR"
cat > "$KANSHI_DIR/config" <<EOF
# Generado por vertical-mode.sh
profile {
    output $OUTPUT enable transform $TRANSFORM
}
EOF
chown "$TARGET_USER:$TARGET_USER" "$KANSHI_DIR/config"

echo
echo "Listo. Reiniciar la sesión gráfica para aplicar:"
echo "  sudo systemctl restart lightdm"
echo
echo "Para volver a horizontal:"
echo "  sudo $0 $TARGET_USER normal"
