# Video Wall en Raspberry Pi — Setup Multi-Monitor con Sway

Documentación de referencia para configurar Raspberry Pi 5 como kiosco signage con
**dos salidas HDMI mostrando contenido distinto** (cada HDMI = un navegador chromium con su URL).

Caso de uso real: SuperGloria horizontal (`100.121.82.48`) — HDMI-1 muestra
`/supergloria/pantalla-1`, HDMI-2 muestra `/supergloria/pantalla-2`.

---

## ¿Por qué Sway y no labwc?

Raspberry Pi OS Trixie viene con **labwc** por default. Funciona bien para single-monitor,
pero tiene limitaciones documentadas para video wall:

- `windowRules` con `MoveToOutput` sólo soporta direcciones (`left`, `right`), no nombre absoluto.
- Las reglas no se aplican a ventanas **fullscreen/kiosk** — y chromium kiosk es exactamente eso.
- Resultado: ambos browsers terminan en el mismo HDMI por más reglas que pongas.

**Sway** soporta `workspace N output HDMI-A-X` + `assign [app_id="..."] workspace N`,
que sí funciona con kiosks fullscreen. Es la solución limpia y soportada.

> **Recomendación:** Sway sólo para multi-monitor. Single-monitor seguir con labwc (default RPi).

---

## Hardware y supuestos

- Raspberry Pi 5 (4GB+ RAM recomendado)
- 2 HDMI conectados (los puertos de la Pi se exponen como `HDMI-A-1` y `HDMI-A-2`)
- Raspberry Pi OS Trixie 64-bit (o superior)
- Usuario `mpeirano` con sudo
- Tailscale instalado para acceso remoto

---

## 1. Instalar paquetes

```bash
sudo apt update
sudo apt install -y sway swaybg wayvnc grim slurp wlr-randr xdg-utils chromium
```

> No hace falta desinstalar labwc — coexisten. Cambiamos vía `lightdm` qué sesión arranca.

---

## 2. Config de Sway

`~/.config/sway/config` (usuario `mpeirano`):

```
# Outputs y workspaces
output HDMI-A-1 mode 1920x1080@60Hz position 0 0
output HDMI-A-2 mode 1920x1080@60Hz position 1920 0

workspace 1 output HDMI-A-1
workspace 2 output HDMI-A-2

# Sin bordes ni decoración
default_border none
hide_edge_borders --i3 both

# Asignación de cada chromium a su workspace (= su monitor)
assign [app_id="signage-screen1"] workspace 1
assign [app_id="signage-screen2"] workspace 2

for_window [app_id="signage-screen1"] fullscreen enable, border none
for_window [app_id="signage-screen2"] fullscreen enable, border none

# Sin input (kiosko)
input * { events disabled }

# Atajos para mantenimiento (Mod = Super/Win)
bindsym Mod4+Shift+Right move container to output right
bindsym Mod4+Shift+Left  move container to output left
bindsym Mod4+f           fullscreen toggle
bindsym Mod4+Shift+r     reload
bindsym Mod4+Shift+e     exit

# Limpiar sesiones previas de chromium para evitar tabs duplicadas
exec rm -rf /home/mpeirano/.chromium-screen1/Default/Sessions /home/mpeirano/.chromium-screen1/Default/"Last Session" /home/mpeirano/.chromium-screen1/Default/"Current Session"
exec rm -rf /home/mpeirano/.chromium-screen2/Default/Sessions /home/mpeirano/.chromium-screen2/Default/"Last Session" /home/mpeirano/.chromium-screen2/Default/"Current Session"

# Lanzar chromium #1 (HDMI-A-1)
exec chromium \
    --kiosk \
    --noerrdialogs --disable-infobars --no-first-run \
    --disable-features=TranslateUI \
    --disable-pinch --overscroll-history-navigation=0 \
    --disable-session-crashed-bubble --hide-crash-restore-bubble \
    --autoplay-policy=no-user-gesture-required \
    --enable-features=OverlayScrollbar \
    --class=signage-screen1 \
    --user-data-dir=/home/mpeirano/.chromium-screen1 \
    --remote-debugging-port=9222 \
    https://pantallas.innovacore.ar/supergloria/pantalla-1

# Lanzar chromium #2 (HDMI-A-2) con delay para que sway termine de mapear el primero
exec sleep 4 && chromium \
    --kiosk \
    --noerrdialogs --disable-infobars --no-first-run \
    --disable-features=TranslateUI \
    --disable-pinch --overscroll-history-navigation=0 \
    --disable-session-crashed-bubble --hide-crash-restore-bubble \
    --autoplay-policy=no-user-gesture-required \
    --enable-features=OverlayScrollbar \
    --class=signage-screen2 \
    --user-data-dir=/home/mpeirano/.chromium-screen2 \
    --remote-debugging-port=9223 \
    https://pantallas.innovacore.ar/supergloria/pantalla-2

# Wallpaper negro (evita que se vea logo de Pi durante boot)
exec swaybg -c '#000000'
```

**Clave:** `--class=signage-screenN` setea el `app_id` Wayland que usan los `assign`.
Si chromium corre vía Xwayland el class va a WM_CLASS y no matchea — verificar con
`swaymsg -t get_tree | grep app_id` que diga `signage-screenN`, no `Chromium`.

---

## 3. Cambiar sesión de autologin a Sway

`/etc/lightdm/lightdm.conf` — buscar `autologin-session` y dejar:

```ini
autologin-user=mpeirano
autologin-session=sway
```

Reiniciar lightdm o la Pi.

### Script para alternar Sway/labwc

Útil si necesitás revertir remoto sin SSH a sesión gráfica:

`/usr/local/bin/wm-switch.sh`:

```bash
#!/bin/bash
case "$1" in
    sway)   sudo sed -i "s|^autologin-session=.*|autologin-session=sway|" /etc/lightdm/lightdm.conf ;;
    labwc)  sudo sed -i "s|^autologin-session=.*|autologin-session=rpd-labwc|" /etc/lightdm/lightdm.conf ;;
    status) grep "^autologin-session" /etc/lightdm/lightdm.conf; exit 0 ;;
    *)      echo "Usage: $0 {sway|labwc|status}"; exit 1 ;;
esac
sudo systemd-run --no-block --unit=wm-switch-$(date +%s) systemctl restart lightdm
```

`chmod +x /usr/local/bin/wm-switch.sh`

---

## 4. VNC (wayvnc) — un solo puerto, switch entre HDMI

wayvnc captura **un output a la vez**. La estrategia: dejar un único `wayvnc` en :5900
y rotar entre HDMI-A-1 y HDMI-A-2 vía IPC cuando lo necesitemos.

`/etc/systemd/system/wayvnc.service`:

```ini
[Unit]
Description=wayvnc for sway
After=graphical.target

[Service]
User=vnc
Environment=WAYLAND_DISPLAY=wayland-1
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStart=/usr/bin/wayvnc --socket=/tmp/wayvnc/wayvncctl.sock 0.0.0.0 5900
Restart=always

[Install]
WantedBy=graphical.target
```

> Usuario `vnc` debe tener permisos a `/run/user/1000` (mismo grupo). Auth PAM con
> el password del usuario Linux.

`/usr/local/bin/vnc-switch.sh`:

```bash
#!/bin/bash
SOCK=/tmp/wayvnc/wayvncctl.sock
case "$1" in
    1|HDMI-A-1) sudo -u vnc wayvncctl --socket=$SOCK output-set HDMI-A-1 ;;
    2|HDMI-A-2) sudo -u vnc wayvncctl --socket=$SOCK output-set HDMI-A-2 ;;
    cycle)      sudo -u vnc wayvncctl --socket=$SOCK output-cycle ;;
    list|*)     sudo -u vnc wayvncctl --socket=$SOCK output-list ;;
esac
```

Uso: `sudo /usr/local/bin/vnc-switch.sh 2` para ver HDMI-2.

---

## 5. Healthcheck + Telegram

Reusa el mismo `kiosk-healthcheck.py` que las single-monitor. Diferencia: detectar
que **ambos** ports DevTools (9222 + 9223) responden.

`/etc/signage/kiosk.conf` (el healthcheck lo lee):

```bash
KIOSK_URL_1="https://pantallas.innovacore.ar/supergloria/pantalla-1"
KIOSK_URL_2="https://pantallas.innovacore.ar/supergloria/pantalla-2"
KIOSK_USER="mpeirano"
DEVTOOLS_PORT_1=9222
DEVTOOLS_PORT_2=9223
```

`/etc/signage/telegram.conf`:

```bash
TELEGRAM_ENABLED=true
TELEGRAM_TOKEN=<bot-token>
TELEGRAM_CHAT_ID=-5037648796
```

`kiosk-healthcheck.timer` corre cada 2 min. Si un port no responde o el DOM está
en error → manda alerta a Telegram.

---

## 6. Watchdog hardware

`/etc/systemd/system.conf.d/watchdog.conf`:

```ini
[Manager]
RuntimeWatchdogSec=15s
RebootWatchdogSec=2min
```

`/boot/firmware/config.txt`:

```ini
dtparam=watchdog=on
```

Si la Pi se cuelga >15s, el BCM2835 watchdog resetea por hardware.

---

## 7. Validar el setup

Después de reboot:

```bash
# 1. Sway corriendo
pgrep -x sway

# 2. Cada chromium en su workspace
SP=$(pgrep -x sway | head -1)
SWAYSOCK=/run/user/1000/sway-ipc.1000.${SP}.sock \
WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 \
swaymsg -t get_workspaces | python3 -c "
import json,sys
for w in json.load(sys.stdin):
    print(w['name'], '->', w['output'], 'rep:', w.get('representation'))
"
# Esperado:
#   1 -> HDMI-A-1 rep: H[signage-screen1]
#   2 -> HDMI-A-2 rep: H[signage-screen2]

# 3. Screenshot de cada output (verificación visual)
WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 grim -o HDMI-A-1 /tmp/p1.png
WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 grim -o HDMI-A-2 /tmp/p2.png
# Bajar y ver

# 4. DevTools por ambos puertos
curl -s http://127.0.0.1:9222/json | python3 -m json.tool | grep -E '"url"|"title"'
curl -s http://127.0.0.1:9223/json | python3 -m json.tool | grep -E '"url"|"title"'
```

---

## Troubleshooting

### Ambos chromium aparecen en el mismo HDMI

- `swaymsg -t get_tree | grep app_id` — si ves `Chromium` en vez de `signage-screenN`,
  chromium está en Xwayland. Forzar Wayland nativo: ya viene por default en chromium 147+,
  pero verificar con `chromium --enable-features=UseOzonePlatform --ozone-platform=wayland`
  si es necesario.
- `assign` aplica al **crear** la ventana. Si la ventana ya existe y se mueve sola,
  reemplazar `assign` por `for_window [...] move container to workspace N`.

### `swaymsg` desde SSH dice "Unable to retrieve socket path"

```bash
SP=$(pgrep -x sway | head -1)
export SWAYSOCK=/run/user/1000/sway-ipc.1000.${SP}.sock
export WAYLAND_DISPLAY=wayland-1
export XDG_RUNTIME_DIR=/run/user/1000
swaymsg -t get_outputs
```

El nombre del socket lleva el PID de sway, por eso cambia tras cada reboot.

### VNC se ve gris al rotar

wayvnc no puede capturar Xwayland. Asegurarse que chromium corra en Wayland nativo
(ver troubleshooting anterior). Si persiste: `systemctl restart wayvnc` y luego
`vnc-switch.sh <output>`.

### El logo de Pi aparece durante el arranque

Es el splash. Para esconderlo:

`/boot/firmware/cmdline.txt` — agregar al final de la línea (sin newline):
`quiet splash plymouth.ignore-serial-consoles logo.nologo vt.global_cursor_default=0 console=tty3`

`/boot/firmware/config.txt`:

```ini
disable_splash=1
```

### Tabs duplicadas en chromium tras reboot

Chromium recupera la sesión anterior y duplica pestañas. La config de sway ya tiene
`exec rm -rf .../Sessions ...` antes de lanzar — verificar que se ejecute (no debe
haber error en `~/.xsession-errors` o equivalente).

### Carga (`uptime`) muy alta tras boot

Normal: 2 chromium + 2 video decode levantando a la vez. Pi 5 (4 cores) puede llegar
a load 7-8 en el primer minuto y bajar a 1-2 en 5 min. Si **persiste** alto:
verificar `vcgencmd measure_temp` (>80°C → throttle) y `vcgencmd get_throttled`.

---

## Inventario actual signage Innovacore

| IP | Cliente | Layout | WM |
|---|---|---|---|
| 100.105.54.24 | Carniceria pantalla 1 | single | labwc |
| 100.86.154.92 | Carniceria pantalla 2 | single | labwc |
| 100.95.148.51 | Carniceria pantalla 3 | single | labwc |
| 100.121.82.48 | SuperGloria horizontal | **dual** | **sway** |
| ... | ... | single | labwc |

> Cuando agregues una pantalla single-monitor: copiá la receta labwc estándar.
> Cuando agregues otro video wall dual: seguir esta doc.

---

## Referencias

- Sway wiki — Multi-monitor: https://github.com/swaywm/sway/wiki
- wayvnc IPC: https://github.com/any1/wayvnc/blob/master/doc/wayvncctl.scd
- Chromium DevTools Protocol: https://chromedevtools.github.io/devtools-protocol/

---

_Última actualización: 2026-05-09 — basado en setup probado en `100.121.82.48`._
