#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# VER LOGS DE INSTALACIÓN - Sistema Digital Signage
# ═══════════════════════════════════════════════════════════════════════════

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           LOGS DE INSTALACIÓN DISPONIBLES                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo

# Buscar logs de instalación
logs=$(ls -t /var/log/signage-install-*.log 2>/dev/null)

if [[ -z "$logs" ]]; then
    echo "❌ No se encontraron logs de instalación"
    echo
    echo "Los logs se guardan en: /var/log/signage-install-YYYYMMDD-HHMMSS.log"
    exit 1
fi

echo "Logs encontrados:"
echo

# Listar logs
count=1
declare -A log_map

while IFS= read -r log; do
    timestamp=$(basename "$log" | sed 's/signage-install-\(.*\)\.log/\1/')
    size=$(du -h "$log" | cut -f1)
    echo "  [$count] $(basename "$log") (${size})"
    log_map[$count]="$log"
    ((count++))
done <<< "$logs"

echo
echo "  [A] Ver el log más reciente"
echo "  [0] Salir"
echo

read -p "Selecciona una opción: " option

if [[ "$option" == "0" ]]; then
    exit 0
elif [[ "$option" =~ ^[Aa]$ ]]; then
    selected_log=$(echo "$logs" | head -1)
elif [[ "$option" =~ ^[0-9]+$ ]] && [[ -n "${log_map[$option]}" ]]; then
    selected_log="${log_map[$option]}"
else
    echo "❌ Opción inválida"
    exit 1
fi

clear
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    LOG DE INSTALACIÓN                         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo
echo "Archivo: $selected_log"
echo

# Mostrar estadísticas
total_lines=$(wc -l < "$selected_log")
errors=$(grep -c "\[ERROR\]" "$selected_log" 2>/dev/null || echo "0")
warnings=$(grep -c "\[WARNING\]" "$selected_log" 2>/dev/null || echo "0")
success=$(grep -c "\[SUCCESS\]" "$selected_log" 2>/dev/null || echo "0")

echo "📊 Estadísticas:"
echo "  Total líneas: $total_lines"
echo "  Éxitos: $success"
echo "  Advertencias: $warnings"
echo "  Errores: $errors"
echo
echo "───────────────────────────────────────────────────────────────"
echo

# Opciones de visualización
echo "[1] Ver log completo"
echo "[2] Ver solo errores"
echo "[3] Ver solo advertencias"
echo "[4] Ver últimas 50 líneas"
echo "[5] Ver primeras 50 líneas"
echo "[0] Volver"
echo

read -p "Opción: " view_option

case "$view_option" in
    1)
        less "$selected_log"
        ;;
    2)
        grep --color=always "\[ERROR\]" "$selected_log" | less -R
        ;;
    3)
        grep --color=always "\[WARNING\]" "$selected_log" | less -R
        ;;
    4)
        tail -50 "$selected_log" | less
        ;;
    5)
        head -50 "$selected_log" | less
        ;;
    0)
        exit 0
        ;;
    *)
        echo "❌ Opción inválida"
        exit 1
        ;;
esac
