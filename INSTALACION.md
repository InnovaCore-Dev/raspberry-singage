# 📋 Sistema de Logs de Instalación

## Sistema Mejorado con Logging Completo

El script de instalación ahora registra **TODO** lo que hace en archivos de log detallados.

---

## 🚀 Cómo Instalar

```bash
cd ~/signage-system
sudo ./signage-setup.sh
```

**Al iniciar la instalación verás:**
```
📋 Log de instalación: /var/log/signage-install-20251224-190000.log
```

---

## 📊 Ver los Logs

### Opción 1: Script interactivo (Recomendado)
```bash
./view-install-log.sh
```

Este script te permite:
- Ver todos los logs disponibles
- Ver estadísticas (errores, advertencias, éxitos)
- Filtrar por tipo (solo errores, solo advertencias)
- Ver las últimas/primeras líneas

### Opción 2: Ver directamente
```bash
# Ver el log más reciente
sudo tail -f /var/log/signage-install-*.log

# Ver todos los logs disponibles
ls -lh /var/log/signage-install-*.log

# Ver un log específico
sudo cat /var/log/signage-install-20251224-190000.log

# Ver solo errores
sudo grep ERROR /var/log/signage-install-*.log
```

---

## 🔍 Qué se Registra

El sistema registra:

- ✅ **Inicio/Fin de cada paso** con timestamp
- ✅ **Decisiones del usuario** (qué opciones eligió)
- ✅ **Configuración guardada** (empresa, pantalla, URL, usuario)
- ✅ **Paquetes instalados**
- ✅ **Éxitos y fallos** de cada operación
- ✅ **Advertencias** de problemas no críticos
- ✅ **Errores** que causan fallos

### Formato del Log
```
[2025-12-24 19:00:00] [INFO] Iniciando paso X
[2025-12-24 19:00:05] [SUCCESS] Operación completada
[2025-12-24 19:00:10] [WARNING] Archivo no encontrado, recreando
[2025-12-24 19:00:15] [ERROR] Falló la operación
```

---

## 🛠️ Si la Instalación Falla

1. **Revisa el log** para ver en qué paso falló:
   ```bash
   ./view-install-log.sh
   ```

2. **Busca la línea con ERROR**:
   ```bash
   sudo grep ERROR /var/log/signage-install-*.log
   ```

3. **Verifica el contexto** (líneas anteriores al error):
   ```bash
   sudo grep -B 5 ERROR /var/log/signage-install-*.log
   ```

4. **Ejecuta verificación automática**:
   ```bash
   sudo ./verify-and-fix.sh
   ```

5. **Intenta reinstalar** con los problemas corregidos

---

## 📁 Ubicación de Archivos

- **Logs de instalación:** `/var/log/signage-install-YYYYMMDD-HHMMSS.log`
- **Logs del watchdog:** `/var/log/signage/watchdog.log`
- **Configuración:** `/etc/signage/*.conf`
- **Scripts:** `/usr/local/bin/`

---

## 💡 Consejos

- Los logs se guardan **automáticamente** cada vez que instalas
- Cada instalación crea un **nuevo archivo de log** con timestamp
- Los logs **persisten** incluso después de reiniciar
- Puedes compartir el log para soporte técnico
- El log incluye información **completa** para debugging

---

## 🎯 Ejemplo de Uso Completo

```bash
# 1. Ejecutar instalación
cd ~/signage-system
sudo ./signage-setup.sh

# 2. Si algo falla, ver el log
./view-install-log.sh

# 3. Copiar el log para análisis
sudo cp /var/log/signage-install-$(ls -t /var/log/signage-install-*.log | head -1 | xargs basename) ~/
```
