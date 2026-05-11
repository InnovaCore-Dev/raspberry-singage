# 🖥️ Sistema de Pantallas Digitales para Raspberry Pi

Sistema completo de **Digital Signage** para Raspberry Pi basado en **Chromium en modo kiosco**, con monitoreo 24/7, alertas por Telegram y recuperación automática ante cortes de luz.

## 📋 Características

✅ **Instalación con un solo script** - Todo automatizado, sin interacción manual
✅ **Chromium en modo kiosco** - Pantalla completa sin distracciones
✅ **Autorecuperación ante cortes de luz** - La Pi arranca sola al recibir corriente
✅ **Watchdog inteligente** - Monitoreo continuo y reinicio automático
✅ **Alertas por Telegram** - Notificaciones en tiempo real de eventos
✅ **Funciona sin internet** - Usa caché cuando no hay conexión
✅ **Fácil actualización de contenido** - Cambia la URL sin reinstalar

---

## 🚀 Inicio Rápido

### 1. Clonar o descargar el sistema

```bash
cd ~
# Si tienes git instalado:
git clone https://github.com/tu-usuario/signage-system.git

# O descarga y descomprime el ZIP
```

### 2. Dar permisos de ejecución

```bash
cd signage-system
chmod +x signage-setup.sh
chmod +x modules/*.sh
chmod +x lib/*.sh
chmod +x watchdog.sh
```

### 3. Ejecutar instalación

```bash
sudo ./signage-setup.sh
```

Selecciona la opción **[1] Instalación Inicial** y sigue el asistente.

### 4. Listo

Después del reinicio, tu Raspberry Pi mostrará la URL configurada en pantalla completa 24/7.

---

## 📦 Requisitos

### Hardware

- **Raspberry Pi 4 o 5** (recomendado Pi 5 para mejor rendimiento)
- Tarjeta microSD de 16GB o más
- Fuente de alimentación oficial
- Monitor/TV con HDMI
- (Opcional) Ventilador o disipador para temperaturas altas

### Software

- **Raspberry Pi OS Lite o Desktop** (versión actualizada)
- **LightDM** como display manager (viene por defecto)
- **Conexión a internet** durante la instalación inicial

---

## 🔧 Instalación Detallada

### Paso a Paso

El asistente de instalación te guiará por 14 pasos:

1. **Verificación de requisitos** - Confirma que es una Raspberry Pi
2. **Verificación de internet** - Opción de configurar Wi-Fi si es necesario
3. **Información del dispositivo** - Nombre de empresa y número de pantalla
4. **Actualización de paquetes** - Descarga la lista actualizada
5. **Instalación de paquetes** - Chromium, unclutter, curl, jq, etc.
6. **Configuración de URL** - Especifica qué URL mostrar
7. **Configuración de autologin** - Inicio automático sin contraseña
8. **Creación del script de kiosco** - Script que inicia Chromium
9. **Configuración de autostart** - Ejecuta el kiosco al iniciar sesión
10. **Creación del watchdog** - Sistema de monitoreo
11. **Configuración de arranque automático** - Recovery ante cortes de luz
12. **Configuración de alertas** _(opcional)_ - Telegram
13. **Creación del servicio watchdog** - Systemd service
14. **Resumen y reinicio** - Finalización

### Instalación No Interactiva

Todos los paquetes se instalan con `DEBIAN_FRONTEND=noninteractive` para evitar cualquier prompt.

---

## 🔌 Recuperación ante Cortes de Luz

La Raspberry Pi está configurada para:

- ✅ **Arrancar automáticamente al recibir corriente**
- ✅ **Iniciar sesión gráfica sin intervención**
- ✅ **Abrir Chromium en modo kiosco automáticamente**
- ✅ **Funcionar con contenido en caché si no hay internet**

**Tiempo de recuperación:** ~60 segundos desde corte hasta pantalla operativa

### Cómo Funciona

1. **Arranque automático:** Por defecto, Raspberry Pi 4/5 arrancan al recibir corriente
2. **Autologin:** LightDM configurado para login automático sin contraseña
3. **Autostart:** Script del kiosco se ejecuta al iniciar sesión
4. **Watchdog:** Monitorea y reinicia Chromium si se cierra

### Verificación

Para verificar la configuración EEPROM:

```bash
sudo rpi-eeprom-config
```

Debe contener:
```
POWER_OFF_ON_HALT=0
WAKE_ON_GPIO=0
```

---

## 📱 Alertas por Telegram

Configura notificaciones para recibir alertas en tiempo real de eventos del sistema.

### Configuración Rápida

1. Ejecuta `sudo ./signage-setup.sh`
2. Selecciona **[5] Configurar Alertas**
3. Crea un bot con [@BotFather](https://t.me/BotFather)
4. Obtén el **Token** del bot
5. Obtén el **Chat ID** (individual o de grupo)
6. Ingresa Token y Chat ID en el sistema
7. Selecciona qué eventos deseas recibir

### Eventos Disponibles

- 🔄 **Reinicio del sistema**
- ❌ **Chromium cerrado inesperadamente**
- 🌡️ **Temperatura alta** (>75°C por defecto)
- 🌐 **Pérdida de internet** _(opcional, después de X minutos)_
- ⚠️ **Error al cargar URL** (código HTTP diferente de 200)
- ℹ️ **Inicio diario programado** _(opcional)_
- 🔧 **Intervención manual** en el sistema

### Obtener Chat ID de un Grupo

1. Agrega tu bot al grupo de Telegram
2. Envía un mensaje en el grupo
3. Visita: `https://api.telegram.org/bot<TOKEN>/getUpdates`
4. Busca `"chat":{"id":` en el JSON
5. El ID de grupo es un número negativo (ej: `-1001234567890`)

### Cola de Mensajes

Si no hay internet, las alertas se guardan en cola y se envían cuando se recupera la conexión.

---

## 🔄 Actualizar Contenido

Para cambiar la URL que se muestra:

```bash
sudo ./signage-setup.sh
```

Selecciona **[2] Actualizar Contenido**

Esto te permite:
1. Cambiar la URL
2. Limpiar la caché de Chromium
3. Reiniciar el navegador automáticamente

---

## ℹ️ Información del Sistema

Ver el estado actual del sistema:

```bash
sudo ./signage-setup.sh
```

Selecciona **[3] Información del Sistema**

Muestra:
- **Hardware:** Modelo, temperatura, memoria, disco, uptime
- **Dispositivo:** Empresa y número de pantalla
- **Kiosco:** URL, usuario, estado de Chromium, caché
- **Red:** Conectividad, IP, Wi-Fi
- **Alertas:** Estado de Telegram, eventos habilitados
- **Servicios:** Estado del watchdog y LightDM

---

## 🔧 Mantenimiento

Herramientas de diagnóstico y mantenimiento:

```bash
sudo ./signage-setup.sh
```

Selecciona **[4] Mantenimiento**

### Opciones Disponibles

1. **Reiniciar Chromium** - Sin reiniciar el sistema
2. **Reiniciar Sistema** - Reinicio completo
3. **Limpiar caché completa** - Libera espacio
4. **Limpiar logs antiguos** - Elimina logs de más de 7 días
5. **Ver logs del watchdog** - Últimas 50 líneas
6. **Verificar servicios** - Estado y gestión de servicios
7. **Actualizar sistema operativo** - `apt upgrade`
8. **Configurar red** - Cambiar Wi-Fi
9. **Exportar información de diagnóstico** - Para soporte

---

## 📁 Estructura del Proyecto

```
signage-system/
├── signage-setup.sh              # Script principal (menú interactivo)
├── watchdog.sh                   # Script de monitoreo continuo
├── modules/
│   ├── common.sh                 # Funciones compartidas
│   ├── install.sh                # Instalación completa
│   ├── update-content.sh         # Actualización de contenido
│   ├── info.sh                   # Información del sistema
│   ├── maintenance.sh            # Mantenimiento
│   └── telegram-alerts.sh        # Configuración de alertas
├── lib/
│   ├── cache-clean.sh            # Limpieza de caché
│   ├── chromium-restart.sh       # Reinicio del navegador
│   ├── validators.sh             # Validaciones
│   ├── network-check.sh          # Verificación de red
│   └── telegram-notify.sh        # Envío de notificaciones
└── README.md                     # Este archivo
```

---

## 🤖 Watchdog

El watchdog es un script que monitorea el sistema continuamente (cada 30 segundos).

### Funciones

1. **Monitoreo de Chromium:**
   - Detecta si Chromium se cerró inesperadamente
   - Reinicia LightDM automáticamente
   - Después de 3 crashes consecutivos, reinicia el sistema

2. **Monitoreo de Temperatura:**
   - Alerta cuando la temperatura supera el umbral configurado
   - Por defecto: 75°C

3. **Monitoreo de Internet:**
   - Detecta pérdida de conexión
   - Alerta después de X minutos sin internet (configurable)
   - Envía notificación cuando se recupera

4. **Verificación de URL:**
   - Cada 5 minutos verifica que la URL cargue correctamente
   - Alerta si el código HTTP no es 2xx o 3xx

5. **Procesamiento de Cola:**
   - Cada 10 minutos intenta enviar mensajes pendientes
   - Si no había internet, los envía cuando se recupera

### Logs

Ver logs del watchdog:

```bash
sudo journalctl -u signage-watchdog -f
```

O desde el archivo:

```bash
tail -f /var/log/signage/watchdog.log
```

---

## 🔐 Archivos de Configuración

Los archivos de configuración se guardan en `/etc/signage/`:

### `/etc/signage/kiosk.conf`

```bash
KIOSK_URL="https://ejemplo.com"
KIOSK_USER="mpeirano"
```

### `/etc/signage/device.conf`

```bash
DEVICE_COMPANY="Paladini"
DEVICE_ID="1"
```

### `/etc/signage/telegram.conf`

```bash
TELEGRAM_ENABLED="true"
TELEGRAM_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
TELEGRAM_CHAT_ID="-1001234567890"
ALERT_QUEUE="/var/log/signage-telegram-queue.log"
```

**⚠️ Permisos:** Este archivo tiene permisos `600` (solo root puede leerlo) porque contiene el token del bot.

### `/etc/signage/telegram-events.conf`

```bash
ALERT_REBOOT="true"
ALERT_CHROMIUM_CRASH="true"
ALERT_HIGH_TEMP="true"
ALERT_INTERNET_DOWN="false"
ALERT_URL_ERROR="true"
ALERT_DAILY_START="false"
ALERT_MANUAL_INTERVENTION="true"

TEMP_THRESHOLD="75"
INTERNET_DOWN_MINUTES="30"
```

---

## 🛠️ Solución de Problemas

### Chromium no inicia

1. Verifica que el servicio watchdog esté corriendo:
   ```bash
   sudo systemctl status signage-watchdog
   ```

2. Revisa los logs:
   ```bash
   sudo journalctl -u signage-watchdog -n 50
   ```

3. Reinicia LightDM manualmente:
   ```bash
   sudo systemctl restart lightdm
   ```

### No hay internet

El sistema funciona **sin internet** usando la caché de Chromium. Si la página requiere internet:

1. Configura Wi-Fi desde el menú de mantenimiento
2. O conecta un cable Ethernet

### Temperatura alta

Si recibes alertas de temperatura alta:

1. Verifica la ventilación de la Raspberry Pi
2. Instala un ventilador o disipador
3. Reduce el overclock (si está configurado)

### Pantalla en blanco

1. Verifica que la URL sea accesible
2. Revisa que Chromium esté corriendo:
   ```bash
   ps aux | grep chromium
   ```

3. Revisa los logs de LightDM:
   ```bash
   cat ~/.xsession-errors
   ```

### Alertas no llegan

1. Verifica la configuración de Telegram:
   ```bash
   cat /etc/signage/telegram.conf
   ```

2. Envía una alerta de prueba desde el menú

3. Verifica que haya internet

4. Revisa la cola de mensajes:
   ```bash
   cat /var/log/signage-telegram-queue.log
   ```

---

## 📊 Monitoreo Remoto

### Ver estado desde SSH

```bash
# Conectarse a la Raspberry Pi
ssh usuario@ip-de-la-raspberry

# Ver información del sistema
sudo ./signage-setup.sh
# Seleccionar opción [3]

# Ver logs en tiempo real
sudo journalctl -u signage-watchdog -f
```

### Reiniciar remotamente

```bash
# Reiniciar Chromium
sudo systemctl restart lightdm

# Reiniciar sistema completo
sudo reboot
```

---

## 🔒 Seguridad

### Recomendaciones

1. **Cambiar contraseña por defecto** de Raspberry Pi OS
2. **Configurar firewall** si es necesario
3. **Mantener el sistema actualizado:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```
4. **Proteger el token de Telegram** (ya tiene permisos 600)
5. **Usar HTTPS** en la URL que muestras

---

## 🚀 Optimizaciones

### Deshabilitar servicios innecesarios

Para mejorar el rendimiento:

```bash
sudo systemctl disable bluetooth
sudo systemctl disable cups
```

### Configurar overscan (si ves bordes negros)

Edita `/boot/firmware/config.txt`:

```bash
disable_overscan=1
```

### Rotación de pantalla

Si necesitas rotar la pantalla, edita `/boot/firmware/config.txt`:

```bash
# Rotar 90 grados
display_rotate=1

# Rotar 180 grados
display_rotate=2

# Rotar 270 grados
display_rotate=3
```

---

## 📝 Notas Importantes

### Instalación de Paquetes

Todos los paquetes se instalan con:

```bash
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    [paquete]
```

Esto garantiza **CERO interacción** durante la instalación.

### Funcionamiento sin Internet

El sistema está diseñado para funcionar **sin internet** después de la primera carga de la página. Chromium cachea el contenido automáticamente.

**Limitaciones:**
- Contenido dinámico no se actualizará
- APIs externas no funcionarán
- Videos en streaming no cargarán

### Actualizaciones del Sistema

El script NO ejecuta `apt upgrade` durante la instalación inicial para no demorar el proceso. Puedes actualizar después desde:

- Menú de Mantenimiento → Opción 7
- O manualmente: `sudo apt upgrade -y`

---

## 🙏 Soporte

### Generar información de diagnóstico

Si necesitas ayuda, genera un archivo de diagnóstico:

```bash
sudo ./signage-setup.sh
# Seleccionar [4] Mantenimiento
# Seleccionar [9] Exportar información de diagnóstico
```

Esto genera un archivo en `/tmp/signage-info-YYYYMMDD-HHMMSS.txt` con toda la información del sistema.

### Logs útiles

```bash
# Logs del watchdog
sudo journalctl -u signage-watchdog -n 100

# Logs de LightDM
cat ~/.xsession-errors

# Logs del sistema
sudo journalctl -xe

# Cola de mensajes de Telegram
cat /var/log/signage-telegram-queue.log
```

---

## 📄 Licencia

Este proyecto es de código abierto. Úsalo libremente para tus proyectos.

---

## 🖥️🖥️ Video Wall (Dual HDMI)

Para setups con **dos monitores HDMI** mostrando contenido distinto en cada uno (ej: SuperGloria horizontal con `/pantalla-1` y `/pantalla-2`), seguí la guía dedicada:

📖 **[docs/videowall-raspberry-pi.md](docs/videowall-raspberry-pi.md)**

Esa guía cubre:
- Por qué Sway en lugar de labwc para multi-monitor
- Configuración completa de Sway + Chromium kiosk en cada output
- VNC con switch entre HDMI-A-1 y HDMI-A-2
- Script para alternar entre Sway y labwc sin reinstalar
- Troubleshooting (Xwayland, app_id mismatch, tabs duplicadas)

Probado en Raspberry Pi 5 con Pi OS Trixie.

---

## 🎉 ¡Listo!

Tu Raspberry Pi ahora funciona como una pantalla digital profesional 24/7.

**Características principales:**
- ✅ Arranque automático ante cortes de luz
- ✅ Monitoreo continuo con watchdog
- ✅ Alertas en tiempo real por Telegram
- ✅ Fácil actualización de contenido
- ✅ Funciona con o sin internet

**¡Disfruta de tu sistema de digital signage!**
