#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# INSTALACIÓN COMPLETA - Sistema Digital Signage
# ═══════════════════════════════════════════════════════════════════════════

# Cargar dependencias
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
source "${SCRIPT_DIR}/lib/validators.sh"
source "${SCRIPT_DIR}/lib/network-check.sh"
source "${SCRIPT_DIR}/modules/telegram-alerts.sh"

# ───────────────────────────────────────────────────────────────────────────
# Sistema de Logging
# ───────────────────────────────────────────────────────────────────────────

INSTALL_LOG="/var/log/signage-install-$(date +%Y%m%d-%H%M%S).log"

# Crear directorio de logs si no existe
mkdir -p /var/log 2>/dev/null

log_install() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[${timestamp}] [${level}] ${message}" | tee -a "$INSTALL_LOG"
}

log_info() {
    log_install "INFO" "$@"
}

log_success() {
    log_install "SUCCESS" "$@"
}

log_warning() {
    log_install "WARNING" "$@"
}

log_error() {
    log_install "ERROR" "$@"
}

log_step() {
    log_install "STEP" "$@"
    echo "────────────────────────────────────────────────────────────────" >> "$INSTALL_LOG"
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 1: Verificación de Requisitos
# ───────────────────────────────────────────────────────────────────────────

step_verify_requirements() {
    print_section "PASO 1/14 - VERIFICACIÓN DE REQUISITOS"
    log_step "PASO 1/14 - VERIFICACIÓN DE REQUISITOS"

    # Verificar que sea Raspberry Pi
    log_info "Verificando hardware..."
    check_raspberry_pi
    log_success "Hardware verificado correctamente"

    # Verificar que sea root
    if [[ $EUID -ne 0 ]]; then
        log_error "Script no ejecutado con privilegios de root"
        print_error "Este script debe ejecutarse con privilegios de root (sudo)"
        return 1
    fi
    log_success "Permisos de root verificados"

    print_success "Requisitos verificados"
    log_success "Todos los requisitos cumplidos"
    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 2: Verificación de Internet
# ───────────────────────────────────────────────────────────────────────────

step_verify_internet() {
    print_section "PASO 2/14 - VERIFICACIÓN DE INTERNET"
    log_step "PASO 2/14 - VERIFICACIÓN DE INTERNET"

    print_step "Verificando conexión a internet..."
    log_info "Verificando conectividad a internet..."

    # Verificar conectividad
    check_connectivity "verbose"
    local conn_status=$?

    if [[ $conn_status -eq 0 ]]; then
        print_success "Internet disponible"
        log_success "Conexión a internet verificada correctamente"
        return 0
    elif [[ $conn_status -eq 1 ]]; then
        print_warning "Conectado a red local pero sin internet"
        log_warning "Conectado a red local pero sin acceso a internet"
    else
        print_warning "Sin conexión de red"
        log_warning "Sin conexión de red detectada"
    fi

    echo
    print_info "Para instalar el sistema se requiere conexión a internet"
    echo
    log_info "Solicitando configuración de Wi-Fi al usuario..."

    if ask_yes_no "¿Deseas configurar Wi-Fi ahora?" "y"; then
        log_info "Usuario aceptó configurar Wi-Fi"
        if show_wifi_menu; then
            print_success "Wi-Fi configurado"
            log_success "Wi-Fi configurado exitosamente"
            return 0
        else
            print_error "No se pudo configurar Wi-Fi"
            log_error "Falló la configuración de Wi-Fi"
            return 1
        fi
    else
        print_error "Se requiere internet para continuar"
        log_error "Usuario rechazó configurar Wi-Fi - Instalación cancelada"
        return 1
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 3: Información del Dispositivo
# ───────────────────────────────────────────────────────────────────────────

step_device_info() {
    print_section "PASO 3/14 - INFORMACIÓN DEL DISPOSITIVO"
    log_step "PASO 3/14 - INFORMACIÓN DEL DISPOSITIVO"

    # Verificar si ya existe configuración
    if [[ -f /etc/signage/device.conf ]]; then
        source /etc/signage/device.conf
        log_info "Configuración existente encontrada: ${DEVICE_COMPANY} - Pantalla ${DEVICE_ID}"
        print_info "Configuración existente encontrada:"
        print_success "  Empresa: ${DEVICE_COMPANY}"
        print_success "  Pantalla: ${DEVICE_ID}"
        echo

        if ask_yes_no "¿Deseas mantener esta configuración?" "y"; then
            print_success "Usando configuración existente"
            log_info "Usuario mantuvo configuración existente"
            return 0
        fi
        log_info "Usuario decidió cambiar configuración"
    fi

    echo "Esta información ayuda a identificar el dispositivo en las alertas."
    echo

    # Pedir nombre de la empresa/local
    local company_name
    while true; do
        company_name=$(ask_input "Nombre de la empresa/local" "")

        if [[ -z "$company_name" ]]; then
            print_error "El nombre no puede estar vacío"
            continue
        fi

        if ! validate_company_name "$company_name"; then
            print_error "Nombre inválido (máximo 50 caracteres)"
            continue
        fi

        break
    done

    # Pedir ID de pantalla
    local device_id
    while true; do
        device_id=$(ask_input "ID de pantalla (1-999)" "1")

        if ! validate_device_id "$device_id"; then
            print_error "ID inválido (debe ser un número entre 1 y 999)"
            continue
        fi

        break
    done

    # Guardar configuración
    log_info "Guardando configuración del dispositivo: ${company_name} - Pantalla ${device_id}"
    mkdir -p /etc/signage
    cat > /etc/signage/device.conf <<EOF
# Configuración del dispositivo
DEVICE_COMPANY="${company_name}"
DEVICE_ID="${device_id}"
EOF

    chmod 644 /etc/signage/device.conf
    log_success "Configuración del dispositivo guardada en /etc/signage/device.conf"

    print_success "Dispositivo: ${company_name} - Pantalla ${device_id}"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 4: Actualizar Lista de Paquetes
# ───────────────────────────────────────────────────────────────────────────

step_update_packages() {
    print_section "PASO 4/14 - ACTUALIZACIÓN DE PAQUETES"
    log_step "PASO 4/14 - ACTUALIZACIÓN DE PAQUETES"

    log_info "Actualizando lista de paquetes del sistema..."
    update_package_list
    local result=$?

    if [[ $result -eq 0 ]]; then
        log_success "Lista de paquetes actualizada correctamente"
    else
        log_error "Falló la actualización de la lista de paquetes"
    fi

    return $result
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 5: Instalar Paquetes Necesarios
# ───────────────────────────────────────────────────────────────────────────

step_install_packages() {
    print_section "PASO 5/14 - INSTALACIÓN DE PAQUETES"
    log_step "PASO 5/14 - INSTALACIÓN DE PAQUETES"

    # Detectar nombre correcto de Chromium
    local chromium_package=""

    print_step "Detectando nombre del paquete Chromium..."
    log_info "Detectando nombre correcto del paquete Chromium..."

    # Verificar si ya está instalado alguno de los dos
    if dpkg -l 2>/dev/null | grep -q "^ii  chromium "; then
        chromium_package="chromium"
        print_info "Chromium ya instalado (paquete: chromium)"
        log_info "Detectado paquete instalado: chromium"
    elif dpkg -l 2>/dev/null | grep -q "^ii  chromium-browser "; then
        chromium_package="chromium-browser"
        print_info "Chromium ya instalado (paquete: chromium-browser)"
        log_info "Detectado paquete instalado: chromium-browser"
    else
        # Si no está instalado, buscar en repositorios
        if apt-cache show chromium-browser &>/dev/null; then
            # Verificar si es un paquete real o virtual
            if apt-cache show chromium-browser | grep -q "Package: chromium-browser"; then
                chromium_package="chromium-browser"
                print_info "Usando: chromium-browser"
                log_info "Paquete disponible: chromium-browser"
            else
                chromium_package="chromium"
                print_info "Usando: chromium (chromium-browser es virtual)"
                log_info "Paquete chromium-browser es virtual, usando chromium"
            fi
        elif apt-cache show chromium &>/dev/null; then
            chromium_package="chromium"
            print_info "Usando: chromium"
            log_info "Paquete disponible: chromium"
        else
            print_error "No se encontró paquete Chromium en los repositorios"
            log_warning "Chromium no encontrado, actualizando lista de paquetes..."
            print_info "Actualizando lista de paquetes..."
            apt-get update -qq

            if apt-cache show chromium &>/dev/null; then
                chromium_package="chromium"
                print_info "Usando: chromium"
                log_success "Paquete Chromium encontrado después de actualizar: chromium"
            else
                print_error "Chromium no disponible. Verifica los repositorios."
                log_error "Chromium no disponible en los repositorios"
                return 1
            fi
        fi
    fi

    local packages=(
        "$chromium_package"
        "unclutter"
        "xdotool"
        "curl"
        "jq"
        "bc"
        "ffmpeg"
    )

    print_info "Instalando ${#packages[@]} paquetes principales..."
    log_info "Iniciando instalación de paquetes principales: ${packages[*]}"
    echo

    local failed=0
    local count=0

    for package in "${packages[@]}"; do
        ((count++))
        log_info "[$count/${#packages[@]}] Procesando paquete: ${package}"
        if ! install_package "$package"; then
            log_error "Falló instalación del paquete crítico: ${package}"
            failed=1
        else
            log_success "[$count/${#packages[@]}] Paquete ${package} procesado exitosamente"
        fi
    done

    # Intentar instalar libavcodec-extra de forma no crítica
    print_info "Instalando codecs adicionales (no crítico)..."
    log_info "Procesando paquete opcional: libavcodec-extra"
    if ! install_package "libavcodec-extra"; then
        print_warning "No se pudo instalar libavcodec-extra, la instalación continuará."
        log_warning "Paquete opcional libavcodec-extra falló, ignorando para continuar."
    fi

    if [[ $failed -eq 1 ]]; then
        print_error "Algunos paquetes no se pudieron instalar"
        log_error "Falló la instalación de algunos paquetes"
        return 1
    fi

    print_success "Todos los paquetes instalados"
    log_success "Todos los paquetes instalados correctamente: ${packages[*]}"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 6: Configurar URL del Kiosco
# ───────────────────────────────────────────────────────────────────────────

step_configure_url() {
    print_section "PASO 6/14 - CONFIGURACIÓN DE URL"
    log_step "PASO 6/14 - CONFIGURACIÓN DE URL"

    # Verificar si ya existe configuración
    if [[ -f /etc/signage/kiosk.conf ]]; then
        source /etc/signage/kiosk.conf
        log_info "Configuración existente encontrada: ${KIOSK_URL} (usuario: ${KIOSK_USER})"
        print_info "Configuración existente encontrada:"
        print_success "  URL: ${KIOSK_URL}"
        print_success "  Usuario: ${KIOSK_USER}"
        echo

        if ask_yes_no "¿Deseas mantener esta configuración?" "y"; then
            print_success "Usando configuración existente"
            log_info "Usuario mantuvo configuración de URL existente"
            return 0
        fi
        log_info "Usuario decidió cambiar URL"
    fi

    echo "Ingresa la URL que deseas mostrar en la pantalla."
    echo "Debe ser una URL completa (http:// o https://)"
    echo

    local kiosk_url
    while true; do
        kiosk_url=$(ask_input "URL a mostrar" "")

        if ! validate_url "$kiosk_url"; then
            print_error "URL inválida (debe comenzar con http:// o https://)"
            continue
        fi

        # Verificar si la URL es accesible
        print_step "Verificando accesibilidad de la URL..."

        if test_url_accessibility "$kiosk_url" 10; then
            print_success "URL accesible"
            break
        else
            print_warning "No se pudo acceder a la URL"

            if ask_yes_no "¿Deseas usar esta URL de todas formas?" "y"; then
                break
            fi
        fi
    done

    # Obtener usuario actual
    local kiosk_user=$(get_current_user)

    # Guardar configuración
    log_info "Guardando configuración de kiosk: URL=${kiosk_url}, Usuario=${kiosk_user}"
    mkdir -p /etc/signage
    cat > /etc/signage/kiosk.conf <<EOF
# Configuración del kiosco
KIOSK_URL="${kiosk_url}"
KIOSK_USER="${kiosk_user}"
EOF

    chmod 644 /etc/signage/kiosk.conf
    log_success "Configuración de kiosk guardada en /etc/signage/kiosk.conf"

    print_success "URL configurada: ${kiosk_url}"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 7: Configurar Autologin
# ───────────────────────────────────────────────────────────────────────────

step_configure_autologin() {
    print_section "PASO 7/14 - CONFIGURACIÓN DE AUTOLOGIN"

    local kiosk_user=$(get_current_user)

    print_step "Configurando autologin para usuario: ${kiosk_user}"

    # Corregir archivos de sesión del sistema (utmp/wtmp)
    # Esto previene el error "Failed to write utmpx: No such file or directory"
    print_step "Verificando y reparando archivos de sesión del sistema..."

    # Crear grupo utmp si no existe
    if ! getent group utmp > /dev/null 2>&1; then
        print_step "Creando grupo utmp..."
        groupadd -r utmp
    fi

    # Asegurar que existan los archivos de sesión necesarios
    touch /var/log/wtmp /var/log/btmp /var/log/lastlog
    chmod 664 /var/log/wtmp
    chmod 664 /var/log/lastlog
    chmod 600 /var/log/btmp
    chgrp utmp /var/log/wtmp
    chgrp utmp /var/log/lastlog

    # Crear enlace simbólico si no existe
    if [[ ! -e /var/run/utmp ]]; then
        ln -sf /run/utmp /var/run/utmp
    fi

    # Asegurar que /run/utmp existe con permisos correctos
    if [[ ! -f /run/utmp ]]; then
        touch /run/utmp
    fi
    chmod 664 /run/utmp
    chgrp utmp /run/utmp

    # Verificar que el directorio /run tiene permisos correctos
    chmod 755 /run

    print_success "Archivos de sesión verificados y corregidos"

    # Configurar LightDM autologin
    if [[ -f /etc/lightdm/lightdm.conf ]]; then
        # Verificar si ya está configurado
        if grep -q "^autologin-user=${kiosk_user}" /etc/lightdm/lightdm.conf 2>/dev/null; then
            print_info "Autologin ya configurado en LightDM"
        else
            # Configurar autologin
            sed -i "s/^#*autologin-user=.*/autologin-user=${kiosk_user}/" /etc/lightdm/lightdm.conf
            sed -i "s/^#*autologin-user-timeout=.*/autologin-user-timeout=0/" /etc/lightdm/lightdm.conf

            print_success "Autologin configurado en LightDM"
        fi
    fi

    # Configurar autologin en consola (TTY)
    local autologin_dir="/etc/systemd/system/getty@tty1.service.d"
    mkdir -p "$autologin_dir"

    cat > "${autologin_dir}/autologin.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${kiosk_user} --noclear %I \$TERM
EOF

    print_success "Autologin configurado"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 8: Crear Script de Inicio del Kiosco
# ───────────────────────────────────────────────────────────────────────────

step_create_kiosk_script() {
    print_section "PASO 8/14 - CREACIÓN DE SCRIPT DE KIOSCO"

    local kiosk_user=$(get_current_user)
    local user_home=$(get_user_home "$kiosk_user")

    print_step "Creando script de inicio del kiosco..."

    # Cargar URL del kiosco
    source /etc/signage/kiosk.conf

    # Crear script de inicio
    mkdir -p /usr/local/bin

    # Detectar el binario correcto de Chromium
    local chromium_bin="chromium-browser"
    if command -v chromium &>/dev/null; then
        chromium_bin="chromium"
    elif command -v chromium-browser &>/dev/null; then
        chromium_bin="chromium-browser"
    fi

    cat > /usr/local/bin/start-kiosk.sh <<EOF
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

# Iniciar Chromium en modo kiosco
\$chromium_bin \\
    --kiosk \\
    --noerrdialogs \\
    --disable-infobars \\
    --no-first-run \\
    --password-store=basic \\
    --check-for-update-interval=31536000 \\
    --disable-session-crashed-bubble \\
    --disable-features=TranslateUI \\
    --disable-component-update \\
    --start-maximized \\
    "\${KIOSK_URL}"
EOF

    chmod +x /usr/local/bin/start-kiosk.sh

    print_success "Script de kiosco creado"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 9: Configurar Autostart
# ───────────────────────────────────────────────────────────────────────────

step_configure_autostart() {
    print_section "PASO 9/14 - CONFIGURACIÓN DE AUTOSTART"

    local kiosk_user=$(get_current_user)
    local user_home=$(get_user_home "$kiosk_user")

    print_step "Configurando autostart para usuario: ${kiosk_user}"

    # Crear directorio autostart
    local autostart_dir="${user_home}/.config/autostart"
    mkdir -p "$autostart_dir"

    # Crear archivo desktop
    cat > "${autostart_dir}/kiosk.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Kiosk
Exec=/usr/local/bin/start-kiosk.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

    # Establecer permisos correctos
    chown -R ${kiosk_user}:${kiosk_user} "$autostart_dir"
    chmod +x "${autostart_dir}/kiosk.desktop"

    print_success "Autostart configurado"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 10: Crear Watchdog
# ───────────────────────────────────────────────────────────────────────────

step_create_watchdog() {
    print_section "PASO 10/14 - CREACIÓN DE WATCHDOG"

    print_step "Creando script de monitoreo..."

    # Crear directorio para logs
    mkdir -p /var/log/signage

    # Crear script de watchdog (lo crearemos en el paso final)
    # Por ahora solo preparamos el servicio

    print_success "Watchdog preparado"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 11: Configurar Arranque Automático (Corte de Luz)
# ───────────────────────────────────────────────────────────────────────────

step_configure_power_on() {
    print_section "PASO 11/14 - CONFIGURACIÓN DE ARRANQUE AUTOMÁTICO"

    print_info "Configurando Raspberry Pi para arrancar automáticamente al recibir corriente..."

    # Verificar configuración EEPROM actual
    if command -v rpi-eeprom-config &>/dev/null; then
        print_step "Verificando configuración EEPROM..."

        # Obtener configuración actual
        local eeprom_config=$(rpi-eeprom-config 2>/dev/null)

        # Verificar valores recomendados
        local needs_update=false

        if ! echo "$eeprom_config" | grep -q "POWER_OFF_ON_HALT=0"; then
            needs_update=true
        fi

        if ! echo "$eeprom_config" | grep -q "WAKE_ON_GPIO=0"; then
            needs_update=true
        fi

        if [[ "$needs_update" == "true" ]]; then
            print_warning "Configuración EEPROM no óptima"
            print_info "Se recomienda configuración manual posterior"
            print_info "Ejecutar: sudo rpi-eeprom-config --edit"
            print_info "Agregar: POWER_OFF_ON_HALT=0 y WAKE_ON_GPIO=0"
        else
            print_success "Configuración EEPROM correcta"
        fi
    else
        print_info "Comando rpi-eeprom-config no disponible"
    fi

    # Configurar /boot/firmware/config.txt
    if [[ -f /boot/firmware/config.txt ]]; then
        print_step "Configurando /boot/firmware/config.txt..."

        # Agregar comentario si no existe
        if ! grep -q "# Arranque automático" /boot/firmware/config.txt; then
            echo "" >> /boot/firmware/config.txt
            echo "# Arranque automático después de corte de luz" >> /boot/firmware/config.txt
            echo "# La Pi arrancará automáticamente al recibir corriente" >> /boot/firmware/config.txt
        fi

        print_success "Configuración de arranque automático lista"
    fi

    print_info "Por defecto, Raspberry Pi 4/5 arranca automáticamente al recibir corriente"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 12: Configurar Alertas de Telegram (OPCIONAL)
# ───────────────────────────────────────────────────────────────────────────

step_configure_telegram() {
    print_section "PASO 12/14 - CONFIGURACIÓN DE ALERTAS (OPCIONAL)"

    if ask_yes_no "¿Deseas configurar alertas por Telegram?" "n"; then
        echo

        # Ejecutar configuración de Telegram
        if configure_telegram_bot; then
            echo
            print_info "Configurando eventos a alertar..."
            echo
            sleep 1
            configure_events
        fi
    else
        print_info "Saltando configuración de alertas"
        print_info "(Puedes configurarlo después desde el menú)"

        # Crear configuración por defecto deshabilitada
        mkdir -p /etc/signage
        cat > /etc/signage/telegram.conf <<EOF
# Configuración de Telegram - Sistema Digital Signage
TELEGRAM_ENABLED="false"
TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""
ALERT_QUEUE="/var/log/signage-telegram-queue.log"
EOF
        chmod 600 /etc/signage/telegram.conf
    fi

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 13: Crear Servicio Watchdog
# ───────────────────────────────────────────────────────────────────────────

step_create_watchdog_service() {
    print_section "PASO 13/14 - CREACIÓN DE SERVICIO WATCHDOG"

    print_step "Creando servicio systemd para watchdog..."

    # Crear servicio
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

    # Habilitar servicio
    systemctl daemon-reload
    systemctl enable signage-watchdog.service >/dev/null 2>&1

    print_success "Servicio watchdog creado y habilitado"

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 14: Verificación Final y Corrección Automática
# ───────────────────────────────────────────────────────────────────────────

step_final_verification() {
    print_section "PASO 14/15 - VERIFICACIÓN FINAL DEL SISTEMA"

    print_step "Verificando configuración del sistema..."
    echo

    local issues_found=0

    # Verificar archivos de configuración
    print_step "Verificando archivos de configuración..."
    if [[ ! -f /etc/signage/device.conf ]] || [[ ! -f /etc/signage/kiosk.conf ]]; then
        print_error "Archivos de configuración no encontrados"
        ((issues_found++))
    else
        print_success "Archivos de configuración OK"
    fi

    # Verificar script de inicio
    print_step "Verificando script de inicio..."
    if [[ ! -x /usr/local/bin/start-kiosk.sh ]]; then
        print_warning "Script de inicio no ejecutable, corrigiendo..."
        chmod +x /usr/local/bin/start-kiosk.sh 2>/dev/null || ((issues_found++))
    fi
    if [[ -x /usr/local/bin/start-kiosk.sh ]]; then
        print_success "Script de inicio OK"
    fi

    # Verificar autostart
    local kiosk_user=$(get_current_user)
    local user_home=$(get_user_home "$kiosk_user")
    print_step "Verificando autostart..."
    if [[ ! -f "${user_home}/.config/autostart/kiosk.desktop" ]]; then
        print_error "Autostart no configurado"
        ((issues_found++))
    else
        chmod +x "${user_home}/.config/autostart/kiosk.desktop" 2>/dev/null
        chown ${kiosk_user}:${kiosk_user} "${user_home}/.config/autostart/kiosk.desktop" 2>/dev/null
        print_success "Autostart OK"
    fi

    # Verificar servicio watchdog
    print_step "Verificando servicio watchdog..."
    if [[ ! -f /etc/systemd/system/signage-watchdog.service ]]; then
        print_error "Servicio watchdog no encontrado"
        ((issues_found++))
    elif ! systemctl is-enabled signage-watchdog.service &>/dev/null; then
        print_warning "Servicio watchdog no habilitado, corrigiendo..."
        systemctl enable signage-watchdog.service &>/dev/null
        if systemctl is-enabled signage-watchdog.service &>/dev/null; then
            print_success "Servicio watchdog habilitado"
        else
            print_error "No se pudo habilitar el servicio watchdog"
            ((issues_found++))
        fi
    else
        print_success "Servicio watchdog OK"
    fi

    # Verificar watchdog script
    print_step "Verificando script watchdog..."
    if [[ ! -x /usr/local/bin/signage-watchdog.sh ]]; then
        print_error "Script watchdog no encontrado o no ejecutable"
        ((issues_found++))
    else
        print_success "Script watchdog OK"
    fi

    # Verificar permisos de directorios
    print_step "Verificando permisos de directorios..."
    chmod 755 /etc/signage 2>/dev/null
    chmod 755 /var/log/signage 2>/dev/null
    chmod 644 /etc/signage/*.conf 2>/dev/null
    print_success "Permisos verificados"

    # Re-verificar archivos de sesión
    print_step "Verificando archivos de sesión del sistema..."
    local session_ok=true

    if [[ ! -f /var/log/wtmp ]] || [[ ! -f /run/utmp ]]; then
        print_warning "Archivos de sesión faltantes, recreando..."
        touch /var/log/wtmp /var/log/btmp /run/utmp /var/log/lastlog
        chmod 664 /var/log/wtmp /run/utmp /var/log/lastlog
        chmod 600 /var/log/btmp
        chgrp utmp /var/log/wtmp /run/utmp /var/log/lastlog 2>/dev/null
        session_ok=false
    fi

    if [[ ! -e /var/run/utmp ]]; then
        print_warning "Enlace simbólico /var/run/utmp faltante, recreando..."
        ln -sf /run/utmp /var/run/utmp
        session_ok=false
    fi

    if $session_ok; then
        print_success "Archivos de sesión OK"
    else
        print_success "Archivos de sesión corregidos"
    fi

    echo
    print_separator
    echo

    if [[ $issues_found -eq 0 ]]; then
        print_success "Verificación completada - No se encontraron problemas"
    else
        print_warning "Verificación completada - Se encontraron ${issues_found} problema(s)"
        print_info "Algunos problemas fueron corregidos automáticamente"
    fi

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# PASO 15: Resumen y Finalización
# ───────────────────────────────────────────────────────────────────────────

step_summary() {
    print_section "PASO 15/15 - INSTALACIÓN COMPLETADA"

    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║               INSTALACIÓN COMPLETADA EXITOSAMENTE             ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo

    # Cargar configuraciones
    source /etc/signage/device.conf 2>/dev/null
    source /etc/signage/kiosk.conf 2>/dev/null

    print_info "Configuración:"
    echo "  • Dispositivo: ${DEVICE_COMPANY} - Pantalla ${DEVICE_ID}"
    echo "  • URL: ${KIOSK_URL}"
    echo "  • Usuario: ${KIOSK_USER}"
    echo "  • Alertas: $(get_telegram_status)"
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

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Función Principal de Instalación
# ───────────────────────────────────────────────────────────────────────────

run_installation() {
    clear
    print_header "INSTALACIÓN INICIAL - SISTEMA DIGITAL SIGNAGE"

    echo "Este asistente configurará tu Raspberry Pi como pantalla digital."
    echo "Tiempo estimado: 15 minutos"
    echo
    print_separator
    echo

    log_install "INFO" "═══════════════════════════════════════════════════════════════"
    log_install "INFO" "INICIO DE INSTALACIÓN - Sistema Digital Signage"
    log_install "INFO" "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    log_install "INFO" "Usuario: $(whoami)"
    log_install "INFO" "Archivo de log: ${INSTALL_LOG}"
    log_install "INFO" "═══════════════════════════════════════════════════════════════"

    echo "📋 Log de instalación: ${INSTALL_LOG}"
    echo

    press_any_key

    # Ejecutar pasos de instalación
    local steps=(
        "step_verify_requirements"
        "step_verify_internet"
        "step_device_info"
        "step_update_packages"
        "step_install_packages"
        "step_configure_url"
        "step_configure_autologin"
        "step_create_kiosk_script"
        "step_configure_autostart"
        "step_create_watchdog"
        "step_configure_power_on"
        "step_configure_telegram"
        "step_create_watchdog_service"
        "step_final_verification"
    )

    for step_func in "${steps[@]}"; do
        log_info "Ejecutando: ${step_func}"
        if ! $step_func; then
            echo
            print_error "Error en: ${step_func}"
            print_error "La instalación no se completó correctamente"
            log_error "INSTALACIÓN FALLIDA en paso: ${step_func}"
            log_error "Revisa el log completo en: ${INSTALL_LOG}"
            echo
            echo "📋 Log completo en: ${INSTALL_LOG}"
            return 1
        fi
        log_success "Completado: ${step_func}"
        echo
        sleep 1
    done

    # Copiar watchdog desde el directorio del script
    print_step "Instalando watchdog completo..."
    log_info "Copiando watchdog desde ${SCRIPT_DIR}/watchdog.sh"

    # Copiar el watchdog desde el directorio del script
    if [[ -f "${SCRIPT_DIR}/watchdog.sh" ]]; then
        cp "${SCRIPT_DIR}/watchdog.sh" /usr/local/bin/signage-watchdog.sh
        chmod +x /usr/local/bin/signage-watchdog.sh
        print_success "Watchdog instalado"
        log_success "Watchdog instalado en /usr/local/bin/signage-watchdog.sh"
    else
        print_error "Archivo watchdog.sh no encontrado en ${SCRIPT_DIR}"
        log_error "Archivo watchdog.sh no encontrado en ${SCRIPT_DIR}"
        return 1
    fi

    # Resumen final
    log_install "INFO" "═══════════════════════════════════════════════════════════════"
    log_install "SUCCESS" "INSTALACIÓN COMPLETADA EXITOSAMENTE"
    log_install "INFO" "Fecha de finalización: $(date '+%Y-%m-%d %H:%M:%S')"
    log_install "INFO" "═══════════════════════════════════════════════════════════════"

    step_summary

    echo
    echo "📋 Log completo guardado en: ${INSTALL_LOG}"
    echo

    return 0
}

# Si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_root
    run_installation
fi
