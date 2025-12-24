#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# VERIFICACIÓN DE RED - Sistema Digital Signage
# ═══════════════════════════════════════════════════════════════════════════

# Cargar funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"

# ───────────────────────────────────────────────────────────────────────────
# Verificación de Internet
# ───────────────────────────────────────────────────────────────────────────

check_internet() {
    local required="${1:-false}"
    local retries="${2:-3}"
    local timeout="${3:-2}"

    for i in $(seq 1 $retries); do
        # Probar con Google DNS
        if ping -c 1 -W "$timeout" 8.8.8.8 &>/dev/null; then
            return 0
        fi

        # Probar con Cloudflare DNS
        if ping -c 1 -W "$timeout" 1.1.1.1 &>/dev/null; then
            return 0
        fi

        sleep 1
    done

    # No hay internet
    if [[ "$required" == "true" ]]; then
        return 1
    else
        # No es requerido, retornar éxito pero con warning
        return 0
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Verificación de Conectividad
# ───────────────────────────────────────────────────────────────────────────

check_connectivity() {
    local mode="${1:-silent}" # silent, verbose

    local has_ethernet=false
    local has_wifi=false
    local has_internet=false

    # Verificar interfaces de red
    if ip link show eth0 up &>/dev/null; then
        has_ethernet=true
        [[ "$mode" == "verbose" ]] && print_success "Ethernet conectado"
    fi

    if ip link show wlan0 up &>/dev/null; then
        has_wifi=true
        [[ "$mode" == "verbose" ]] && print_success "Wi-Fi conectado"
    fi

    # Verificar internet
    if check_internet false 2 2; then
        has_internet=true
        [[ "$mode" == "verbose" ]] && print_success "Internet disponible"
    else
        [[ "$mode" == "verbose" ]] && print_warning "Sin conexión a internet"
    fi

    # Retornar estado
    if $has_internet; then
        return 0
    elif $has_ethernet || $has_wifi; then
        return 1 # Conectado a red local pero sin internet
    else
        return 2 # Sin conexión de red
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Configuración de Wi-Fi
# ───────────────────────────────────────────────────────────────────────────

list_wifi_networks() {
    print_step "Escaneando redes Wi-Fi disponibles..."

    # Escanear redes
    nmcli device wifi rescan 2>/dev/null
    sleep 2

    # Listar redes
    nmcli -t -f SSID,SIGNAL,SECURITY device wifi list | sort -t: -k2 -rn
}

connect_wifi() {
    local ssid="$1"
    local password="$2"

    print_step "Conectando a red Wi-Fi: ${ssid}..."

    # Intentar conectar
    if nmcli device wifi connect "$ssid" password "$password" &>/dev/null; then
        print_success "Conectado a ${ssid}"

        # Verificar internet
        sleep 3
        if check_internet false 3 2; then
            print_success "Internet disponible"
            return 0
        else
            print_warning "Conectado pero sin internet"
            return 1
        fi
    else
        print_error "Error al conectar a ${ssid}"
        return 1
    fi
}

show_wifi_menu() {
    clear
    print_header "CONFIGURACIÓN WI-FI"

    echo "Redes disponibles:"
    echo

    # Obtener lista de redes
    local networks=$(list_wifi_networks)

    if [[ -z "$networks" ]]; then
        print_error "No se encontraron redes Wi-Fi"
        return 1
    fi

    # Mostrar redes numeradas
    local counter=1
    local ssid_list=()

    while IFS=: read -r ssid signal security; do
        if [[ -n "$ssid" ]] && [[ ! " ${ssid_list[@]} " =~ " ${ssid} " ]]; then
            ssid_list+=("$ssid")

            # Determinar icono de señal
            local signal_icon="▂▄▆█"
            if [[ $signal -lt 30 ]]; then
                signal_icon="▂___"
            elif [[ $signal -lt 50 ]]; then
                signal_icon="▂▄__"
            elif [[ $signal -lt 70 ]]; then
                signal_icon="▂▄▆_"
            fi

            # Determinar icono de seguridad
            local security_icon="🔓"
            [[ "$security" != "--" ]] && security_icon="🔒"

            printf "  [%2d] %s %s %-30s (%d%%)\n" \
                "$counter" "$security_icon" "$signal_icon" "$ssid" "$signal"

            ((counter++))
        fi
    done <<< "$networks"

    echo
    print_separator
    echo

    # Pedir selección
    read -p "Selecciona una red [1-${#ssid_list[@]}] o [0] para cancelar: " selection

    if [[ "$selection" == "0" ]] || [[ -z "$selection" ]]; then
        return 1
    fi

    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ $selection -lt 1 ]] || [[ $selection -gt ${#ssid_list[@]} ]]; then
        print_error "Selección inválida"
        return 1
    fi

    # Obtener SSID seleccionado
    local selected_ssid="${ssid_list[$((selection-1))]}"

    # Pedir contraseña
    read -sp "Contraseña para ${selected_ssid}: " wifi_password
    echo

    # Conectar
    connect_wifi "$selected_ssid" "$wifi_password"
}

# ───────────────────────────────────────────────────────────────────────────
# Estado de Red
# ───────────────────────────────────────────────────────────────────────────

get_network_info() {
    local interface="$1"

    if [[ -z "$interface" ]]; then
        # Detectar interfaz activa
        if ip link show eth0 up &>/dev/null; then
            interface="eth0"
        elif ip link show wlan0 up &>/dev/null; then
            interface="wlan0"
        else
            echo "No hay interfaz de red activa"
            return 1
        fi
    fi

    # Obtener información
    local ip_addr=$(ip -4 addr show "$interface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    local mac_addr=$(ip link show "$interface" 2>/dev/null | grep -oP '(?<=link/ether\s)[0-9a-f:]+')

    echo "Interfaz: $interface"
    echo "IP: ${ip_addr:-N/A}"
    echo "MAC: ${mac_addr:-N/A}"

    if [[ "$interface" == "wlan0" ]]; then
        local ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
        local signal=$(nmcli -t -f active,signal dev wifi | grep '^yes' | cut -d: -f2)
        echo "SSID: ${ssid:-N/A}"
        echo "Señal: ${signal:-N/A}%"
    fi
}
