# Configuraciones post-instalación

Después de correr `./signage-setup.sh` o `./quick-install.sh`, podés sumar estas
configuraciones según lo que necesite la pantalla.

---

## 1. Ocultar el cursor del mouse (recomendado para todas las pantallas)

`unclutter` solo funciona en X11. En Pi OS Bookworm/Trixie el escritorio es
**Wayland (labwc)** y el cursor del compositor se ve en la pantalla y vía VNC.
La solución es un theme de cursor 1x1 transparente.

```bash
sudo ./modules/cursor-blank.sh
sudo systemctl restart lightdm   # para aplicar
```

---

## 2. Acceso remoto por VNC

Pi OS con Wayland usa **wayvnc** (no `vncserver-x11-serviced`). El siguiente
script lo configura para compartir el HDMI físico con autenticación fija:

```bash
sudo ./modules/install-vnc.sh                       # user=admin pass=Claude202
sudo ./modules/install-vnc.sh tecnico MiPass#123    # user/pass custom
```

Conectarse con cualquier cliente VNC a `IP_DE_LA_PI:5900`.

> **Nota**: si querés en cambio un escritorio VNC virtual (sesión X11 paralela
> al HDMI), usar `vncserver-virtual :1 -Authentication VncAuth` + `vncpasswd
> -virtual` y agregar al crontab `@reboot`.

---

## 3. Modo vertical (OPCIONAL)

Solo correr en pantallas montadas en vertical. **No** se aplica por defecto.

```bash
# 270 = parte superior a la derecha (más común en TVs colgados verticales)
sudo ./extras/vertical-mode.sh

# 90 = parte superior a la izquierda
sudo ./extras/vertical-mode.sh mpeirano 90

# Volver a horizontal
sudo ./extras/vertical-mode.sh mpeirano normal

sudo systemctl restart lightdm   # aplicar
```

> En Pi OS Wayland NO sirve `display_rotate=1` en `config.txt` — eso era para
> el modo Legacy. La rotación persistente se hace con **kanshi**.

---

## Orden recomendado para una Pi nueva

```bash
# 1. Instalar el sistema signage
cd ~/raspberry-singage
chmod +x signage-setup.sh modules/*.sh extras/*.sh
sudo ./signage-setup.sh                    # asistente: empresa, pantalla, URL

# 2. Cursor invisible
sudo ./modules/cursor-blank.sh

# 3. VNC para acceso remoto
sudo ./modules/install-vnc.sh

# 4. (opcional) Pantalla vertical
sudo ./extras/vertical-mode.sh

# 5. Reiniciar
sudo reboot
```
