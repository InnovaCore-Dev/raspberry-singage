#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# OCULTAR EL CURSOR DEL MOUSE (theme blank) - Pi OS Wayland (labwc)
# ═══════════════════════════════════════════════════════════════════════════
#
# unclutter no funciona en Wayland. Para que NO se vea ningún cursor en la
# pantalla del kiosco (incluido por VNC), creamos un theme de cursor 1x1
# transparente y lo aplicamos system-wide y al usuario.
#
# Uso:
#   sudo ./cursor-blank.sh [USUARIO_KIOSK]
#
# Default: USUARIO_KIOSK=mpeirano

set -e

TARGET_USER="${1:-mpeirano}"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo"
    exit 1
fi

if ! id -u "$TARGET_USER" >/dev/null 2>&1; then
    echo "ERROR: el usuario $TARGET_USER no existe"
    exit 1
fi

echo "=== Instalando dependencias (xcursorgen + imagemagick) ==="
apt-get update -qq
apt-get install -y x11-apps imagemagick >/dev/null

echo "=== Generando cursor 1x1 transparente ==="
convert -size 1x1 xc:none /tmp/blank-cursor.png
echo "1 0 0 /tmp/blank-cursor.png" > /tmp/blank-cursor.cfg
xcursorgen /tmp/blank-cursor.cfg /tmp/blank-cursor

echo "=== Creando theme /usr/share/icons/blank ==="
mkdir -p /usr/share/icons/blank/cursors
cp /tmp/blank-cursor /usr/share/icons/blank/cursors/cursor

cat > /usr/share/icons/blank/index.theme <<EOF
[Icon Theme]
Name=blank
Comment=Invisible cursor
Inherits=
EOF
cat > /usr/share/icons/blank/cursor.theme <<EOF
[Icon Theme]
Name=blank
Inherits=blank
EOF

# Symlinks para todos los nombres comunes de cursor (Xcursor)
cd /usr/share/icons/blank/cursors
for n in default left_ptr arrow hand1 hand2 pointer pointing_hand xterm text \
         crosshair sb_h_double_arrow sb_v_double_arrow watch wait progress \
         all-scroll move grab grabbing not-allowed help question_arrow \
         context-menu cell copy alias zoom-in zoom-out zoom_in zoom_out \
         v_double_arrow h_double_arrow X_cursor n-resize ne-resize nw-resize \
         s-resize se-resize sw-resize w-resize e-resize ew-resize ns-resize \
         nesw-resize nwse-resize col-resize row-resize size_all size_bdiag \
         size_fdiag size_hor size_ver top_left_arrow center_ptr fleur \
         openhand closedhand bottom_left_corner bottom_right_corner \
         top_left_corner top_right_corner bottom_side top_side left_side \
         right_side dotbox draped_box icon link; do
    ln -sf cursor "$n"
done
cd - >/dev/null

echo "=== Aplicando XCURSOR_THEME=blank en /etc/xdg/labwc/environment ==="
if [[ -f /etc/xdg/labwc/environment ]]; then
    if grep -q "^XCURSOR_THEME=" /etc/xdg/labwc/environment; then
        sed -i -E "s|^XCURSOR_THEME=.*|XCURSOR_THEME=blank|" /etc/xdg/labwc/environment
    else
        echo "XCURSOR_THEME=blank" >> /etc/xdg/labwc/environment
    fi
    if grep -q "^XCURSOR_SIZE=" /etc/xdg/labwc/environment; then
        sed -i -E "s|^XCURSOR_SIZE=.*|XCURSOR_SIZE=1|" /etc/xdg/labwc/environment
    else
        echo "XCURSOR_SIZE=1" >> /etc/xdg/labwc/environment
    fi
fi

echo "=== Aplicando también al usuario $TARGET_USER ==="
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.config/labwc"
sudo -u "$TARGET_USER" touch "$USER_HOME/.config/labwc/environment"
sed -i "/^XCURSOR_/d" "$USER_HOME/.config/labwc/environment"
echo "XCURSOR_THEME=blank" >> "$USER_HOME/.config/labwc/environment"
echo "XCURSOR_SIZE=1" >> "$USER_HOME/.config/labwc/environment"
chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/.config/labwc/environment"

# GTK fallback (apps GTK leen de aquí)
sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.config/gtk-3.0"
GTK_INI="$USER_HOME/.config/gtk-3.0/settings.ini"
if [[ ! -f "$GTK_INI" ]]; then
    cat > "$GTK_INI" <<EOF
[Settings]
gtk-cursor-theme-name=blank
gtk-cursor-theme-size=1
EOF
    chown "$TARGET_USER:$TARGET_USER" "$GTK_INI"
fi

echo
echo "Cursor blank configurado."
echo "Para que tome efecto en la sesión actual:"
echo "  sudo systemctl restart lightdm"
echo "(o esperar al próximo reboot)"
