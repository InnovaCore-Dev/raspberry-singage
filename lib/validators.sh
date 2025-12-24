#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# VALIDADORES - Sistema Digital Signage
# ═══════════════════════════════════════════════════════════════════════════

# Cargar funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"

# ───────────────────────────────────────────────────────────────────────────
# Validación de URL
# ───────────────────────────────────────────────────────────────────────────

validate_url() {
    local url="$1"

    # Verificar que no esté vacía
    if [[ -z "$url" ]]; then
        return 1
    fi

    # Verificar formato básico de URL
    if [[ ! "$url" =~ ^https?:// ]]; then
        return 1
    fi

    # Verificar que no contenga espacios
    if [[ "$url" =~ [[:space:]] ]]; then
        return 1
    fi

    return 0
}

test_url_accessibility() {
    local url="$1"
    local timeout="${2:-10}"

    # Intentar hacer una petición HTTP HEAD
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)

    if [[ "$http_code" =~ ^[23] ]]; then
        return 0
    else
        return 1
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Validación de Telegram
# ───────────────────────────────────────────────────────────────────────────

validate_telegram_token() {
    local token="$1"

    # Formato: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz
    if [[ -z "$token" ]]; then
        return 1
    fi

    if [[ ! "$token" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
        return 1
    fi

    return 0
}

validate_telegram_chat_id() {
    local chat_id="$1"

    # Puede ser positivo (usuario) o negativo (grupo)
    if [[ -z "$chat_id" ]]; then
        return 1
    fi

    if [[ ! "$chat_id" =~ ^-?[0-9]+$ ]]; then
        return 1
    fi

    return 0
}

test_telegram_connection() {
    local token="$1"
    local chat_id="$2"

    # Verificar que tenemos internet
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo "NO_INTERNET"
        return 1
    fi

    # Intentar enviar un mensaje de prueba
    local response=$(curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -d chat_id="${chat_id}" \
        -d text="✓ Configuración de Telegram correcta - Sistema Digital Signage" \
        -d parse_mode="Markdown" 2>&1)

    # Verificar si fue exitoso
    if echo "$response" | grep -q '"ok":true'; then
        return 0
    else
        # Extraer mensaje de error
        local error_msg=$(echo "$response" | grep -o '"description":"[^"]*"' | cut -d'"' -f4)
        echo "${error_msg:-ERROR_DESCONOCIDO}"
        return 1
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Validación de Nombres
# ───────────────────────────────────────────────────────────────────────────

validate_company_name() {
    local name="$1"

    # No vacío y longitud razonable
    if [[ -z "$name" ]] || [[ ${#name} -gt 50 ]]; then
        return 1
    fi

    return 0
}

validate_device_id() {
    local id="$1"

    # Solo números
    if [[ ! "$id" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    # Entre 1 y 999
    if [[ $id -lt 1 ]] || [[ $id -gt 999 ]]; then
        return 1
    fi

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Validación de Configuración
# ───────────────────────────────────────────────────────────────────────────

validate_config_file() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        return 1
    fi

    # Verificar que sea un archivo bash válido
    if ! bash -n "$config_file" 2>/dev/null; then
        return 1
    fi

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Validación de Usuario
# ───────────────────────────────────────────────────────────────────────────

validate_user_exists() {
    local username="$1"

    if id "$username" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Validación de Temperatura
# ───────────────────────────────────────────────────────────────────────────

validate_temperature_threshold() {
    local temp="$1"

    # Solo números
    if [[ ! "$temp" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    # Entre 50 y 90 grados
    if [[ $temp -lt 50 ]] || [[ $temp -gt 90 ]]; then
        return 1
    fi

    return 0
}

# ───────────────────────────────────────────────────────────────────────────
# Validación de Tiempo
# ───────────────────────────────────────────────────────────────────────────

validate_minutes() {
    local minutes="$1"

    # Solo números
    if [[ ! "$minutes" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    # Entre 1 y 1440 (24 horas)
    if [[ $minutes -lt 1 ]] || [[ $minutes -gt 1440 ]]; then
        return 1
    fi

    return 0
}
