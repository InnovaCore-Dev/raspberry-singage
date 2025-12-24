# 🚀 Instalación Rápida

## Requisitos Previos

- Raspberry Pi 4 o 5
- Raspberry Pi OS instalado
- Conexión a internet (durante la instalación)

## Pasos de Instalación

### 1. Descargar o clonar el proyecto

```bash
cd ~
# Descargar el proyecto (si ya lo tienes, saltar este paso)
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

Selecciona la opción **[1] Instalación Inicial**

### 4. Seguir el asistente

El asistente te pedirá:

1. **Configurar Wi-Fi** (si no tienes Ethernet)
2. **Nombre de empresa/local** (ej: "Paladini")
3. **Número de pantalla** (ej: "1")
4. **URL a mostrar** (ej: "https://ejemplo.com")
5. **(Opcional)** **Token de Telegram** y **Chat ID** para alertas

### 5. Reiniciar

Al finalizar, el sistema te preguntará si deseas reiniciar. Acepta.

### 6. ¡Listo!

Después del reinicio, la pantalla mostrará la URL configurada automáticamente.

---

## Verificación Post-Instalación

### Verificar que Chromium está corriendo

```bash
ps aux | grep chromium
```

Deberías ver varios procesos de chromium.

### Verificar que el watchdog está activo

```bash
sudo systemctl status signage-watchdog
```

Debe mostrar: `Active: active (running)`

### Ver logs en tiempo real

```bash
sudo journalctl -u signage-watchdog -f
```

---

## Cambiar URL después de instalar

```bash
sudo ./signage-setup.sh
```

Selecciona **[2] Actualizar Contenido**

---

## ¿Problemas?

Consulta el archivo [README.md](README.md) sección "Solución de Problemas"

O exporta información de diagnóstico:

```bash
sudo ./signage-setup.sh
# [4] Mantenimiento
# [9] Exportar información de diagnóstico
```
