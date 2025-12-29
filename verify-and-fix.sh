#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# VERIFICACIÓN Y REPARACIÓN AUTOMÁTICA - Sistema Digital Signage
# ═══════════════════════════════════════════════════════════════════════════

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar módulos
source "${SCRIPT_DIR}/modules/common.sh"

# ───────────────────────────────────────────────────────────────────────────
# Verificar que sea root
# ───────────────────────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
    echo
    print_error "Este script debe ejecutarse con privilegios de root"
    echo
    print_info "Ejecuta: sudo $0"
    echo
    exit 1
fi

# ───────────────────────────────────────────────────────────────────────────
# Inicio
# ───────────────────────────────────────────────────────────────────────────

clear
print_header "VERIFICACIÓN Y REPARACIÓN AUTOMÁTICA"

echo "Este script detectará y corregirá problemas comunes del sistema."
echo
print_separator
echo

issues_found=0
issues_fixed=0

# ───────────────────────────────────────────────────────────────────────────
# 1. Verificar archivos de sesión del sistema (utmp/wtmp)
# ───────────────────────────────────────────────────────────────────────────

print_step "1. Verificando archivos de sesión del sistema..."

# Crear grupo utmp si no existe
if ! getent group utmp > /dev/null 2>&1; then
    print_warning "Grupo utmp no existe, creando..."
    groupadd -r utmp
    ((issues_found++))
    ((issues_fixed++))
fi

# Verificar y crear archivos necesarios
session_files_ok=true

if [[ ! -f /var/log/wtmp ]]; then
    print_warning "Archivo /var/log/wtmp faltante"
    touch /var/log/wtmp
    chmod 664 /var/log/wtmp
    chgrp utmp /var/log/wtmp
    session_files_ok=false
    ((issues_found++))
    ((issues_fixed++))
fi

if [[ ! -f /var/log/btmp ]]; then
    print_warning "Archivo /var/log/btmp faltante"
    touch /var/log/btmp
    chmod 600 /var/log/btmp
    session_files_ok=false
    ((issues_found++))
    ((issues_fixed++))
fi

if [[ ! -f /var/log/lastlog ]]; then
    print_warning "Archivo /var/log/lastlog faltante"
    touch /var/log/lastlog
    chmod 664 /var/log/lastlog
    chgrp utmp /var/log/lastlog
    session_files_ok=false
    ((issues_found++))
    ((issues_fixed++))
fi

if [[ ! -f /run/utmp ]]; then
    print_warning "Archivo /run/utmp faltante"
    touch /run/utmp
    chmod 664 /run/utmp
    chgrp utmp /run/utmp
    session_files_ok=false
    ((issues_found++))
    ((issues_fixed++))
fi

if [[ ! -e /var/run/utmp ]]; then
    print_warning "Enlace simbólico /var/run/utmp faltante"
    ln -sf /run/utmp /var/run/utmp
    session_files_ok=false
    ((issues_found++))
    ((issues_fixed++))
fi

# Verificar permisos correctos
chmod 664 /var/log/wtmp /run/utmp /var/log/lastlog 2>/dev/null
chmod 600 /var/log/btmp 2>/dev/null
chgrp utmp /var/log/wtmp /run/utmp /var/log/lastlog 2>/dev/null

if $session_files_ok; then
    print_success "Archivos de sesión OK"
else
    print_success "Archivos de sesión corregidos"
fi

# ───────────────────────────────────────────────────────────────────────────
# 2. Verificar archivos de configuración
# ───────────────────────────────────────────────────────────────────────────

print_step "2. Verificando archivos de configuración..."

if [[ ! -d /etc/signage ]]; then
    print_warning "Directorio /etc/signage no existe, creando..."
    mkdir -p /etc/signage
    chmod 755 /etc/signage
    ((issues_found++))
    ((issues_fixed++))
fi

if [[ ! -d /var/log/signage ]]; then
    print_warning "Directorio /var/log/signage no existe, creando..."
    mkdir -p /var/log/signage
    chmod 755 /var/log/signage
    ((issues_found++))
    ((issues_fixed++))
fi

if [[ -f /etc/signage/device.conf ]] && [[ -f /etc/signage/kiosk.conf ]]; then
    chmod 644 /etc/signage/*.conf 2>/dev/null
    print_success "Archivos de configuración OK"
else
    print_warning "Sistema no configurado completamente"
    print_info "Ejecuta la instalación inicial desde el menú principal"
fi

# ───────────────────────────────────────────────────────────────────────────
# 3. Verificar scripts del sistema
# ───────────────────────────────────────────────────────────────────────────

print_step "3. Verificando scripts del sistema..."

scripts_ok=true

if [[ -f /usr/local/bin/start-kiosk.sh ]]; then
    if [[ ! -x /usr/local/bin/start-kiosk.sh ]]; then
        print_warning "Script start-kiosk.sh no es ejecutable, corrigiendo..."
        chmod +x /usr/local/bin/start-kiosk.sh
        scripts_ok=false
        ((issues_found++))
        ((issues_fixed++))
    fi
    
    # Verificar binario de Chromium
    if grep -q "chromium-browser" /usr/local/bin/start-kiosk.sh && ! command -v chromium-browser >/dev/null; then
        if command -v chromium >/dev/null; then
            print_warning "start-kiosk.sh usa chromium-browser pero solo existe chromium. Corrigiendo..."
            sed -i 's/chromium-browser/chromium/g' /usr/local/bin/start-kiosk.sh
            ((issues_found++))
            ((issues_fixed++))
        fi
    fi
fi

if [[ -f /usr/local/bin/signage-watchdog.sh ]]; then
    if [[ ! -x /usr/local/bin/signage-watchdog.sh ]]; then
        print_warning "Script watchdog no es ejecutable, corrigiendo..."
        chmod +x /usr/local/bin/signage-watchdog.sh
        scripts_ok=false
        ((issues_found++))
        ((issues_fixed++))
    fi
fi

if $scripts_ok; then
    print_success "Scripts del sistema OK"
else
    print_success "Scripts corregidos"
fi

# ───────────────────────────────────────────────────────────────────────────
# 4. Verificar autostart
# ───────────────────────────────────────────────────────────────────────────

print_step "4. Verificando autostart..."

if [[ -f /etc/signage/kiosk.conf ]]; then
    source /etc/signage/kiosk.conf

    if [[ -f "${HOME}/.config/autostart/kiosk.desktop" ]]; then
        chmod +x "${HOME}/.config/autostart/kiosk.desktop" 2>/dev/null
        chown ${KIOSK_USER}:${KIOSK_USER} "${HOME}/.config/autostart/kiosk.desktop" 2>/dev/null
        print_success "Autostart OK"
    else
        print_warning "Autostart no configurado"
    fi
else
    print_info "Sistema no configurado - Saltando verificación"
fi

# ───────────────────────────────────────────────────────────────────────────
# 5. Verificar servicios systemd
# ───────────────────────────────────────────────────────────────────────────

print_step "5. Verificando servicios systemd..."

services_ok=true

if [[ -f /etc/systemd/system/signage-watchdog.service ]]; then
    if ! systemctl is-enabled signage-watchdog.service &>/dev/null; then
        print_warning "Servicio watchdog no habilitado, corrigiendo..."
        systemctl daemon-reload
        systemctl enable signage-watchdog.service &>/dev/null
        services_ok=false
        ((issues_found++))
        ((issues_fixed++))
    fi

    if systemctl is-enabled signage-watchdog.service &>/dev/null; then
        print_success "Servicio watchdog OK"
    fi
else
    print_info "Servicio watchdog no instalado"
fi

# ───────────────────────────────────────────────────────────────────────────
# 6. Verificar LightDM
# ───────────────────────────────────────────────────────────────────────────

print_step "6. Verificando LightDM..."

if [[ -f /etc/lightdm/lightdm.conf ]]; then
    if systemctl is-active lightdm &>/dev/null; then
        print_success "LightDM funcionando correctamente"
    else
        print_warning "LightDM no está activo"
        print_info "Considera reiniciar LightDM: sudo systemctl restart lightdm"
    fi
else
    print_info "LightDM no configurado"
fi

# ───────────────────────────────────────────────────────────────────────────
# Resumen
# ───────────────────────────────────────────────────────────────────────────

echo
print_separator
echo

print_header "RESUMEN DE VERIFICACIÓN"

echo "Problemas encontrados: ${issues_found}"
echo "Problemas corregidos: ${issues_fixed}"
echo

if [[ $issues_found -eq 0 ]]; then
    print_success "No se encontraron problemas - El sistema está funcionando correctamente"
elif [[ $issues_fixed -eq $issues_found ]]; then
    print_success "Todos los problemas fueron corregidos automáticamente"
    echo
    print_info "Se recomienda reiniciar el sistema para aplicar todos los cambios"
    echo

    if ask_yes_no "¿Deseas reiniciar ahora?" "n"; then
        print_info "Reiniciando en 5 segundos..."
        sleep 5
        reboot
    fi
else
    print_warning "Se corrigieron ${issues_fixed} de ${issues_found} problemas"
    print_info "Algunos problemas pueden requerir atención manual"
fi

echo
print_info "Verificación completada"
echo
