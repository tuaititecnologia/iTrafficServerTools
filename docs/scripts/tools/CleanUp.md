# 🧹 CleanUp.ps1

Script de limpieza automática para liberar espacio en disco eliminando logs antiguos y archivos temporales.

## 📋 Descripción

Realiza tareas de mantenimiento rutinario eliminando archivos antiguos en:
- Aplicaciones web en IIS
- Logs de IIS
- Logs de SpoolfisNet
- Archivos de backup temporales
- Papelera de reciclaje

## 🎯 Qué Limpia

### Logs de Aplicaciones Web
- **Ubicación:** `C:\inetpub\wwwroot\*\App_Data\Log`
- **Elimina:** Archivos con más de 3 días

### Archivos ZIP Temporales
- **Ubicación:** `C:\inetpub\wwwroot\*`
- **Elimina:** Archivos con formato `yyyy.m.d.h.m.s.zip`
- **Ejemplo:** `2024.11.5.14.30.22.zip`

### Logs de IIS
- **Ubicación:** `C:\inetpub\logs\LogFiles\*`
- **Elimina:** Archivos con más de 3 días

### Logs de SpoolfisNet
- **Ubicaciones:** `C:\Program Files` y `C:\Program Files (x86)`
- **Elimina:** Archivos `*.txt.*` (excepto `log-file.txt`)
- **⚠️ Reinicia servicios:** `SpoolfisNet` y `SpoolfisNetV2Service`

### Otros
- Vacía la carpeta `C:\inetpub\barcode`
- Vacía la papelera de reciclaje de C:
- Muestra reporte final del espacio en disco

## 💻 Uso

### Ejecución Manual
```powershell
& C:\Scripts\iTraffic\CleanUp.ps1
```

### Ejecución Programada (Recomendado)

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\iTraffic\CleanUp.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "iTraffic-CleanUp" -Action $action -Trigger $trigger `
    -Principal $principal -Description "Limpieza automática semanal"
```

## ⚠️ Advertencias

### Permisos
- Requiere ejecutarse como **Administrador**
- Necesario para acceso a carpetas del sistema y reinicio de servicios

### Interrupciones
- Reinicia servicios SpoolfisNet (puede causar interrupciones breves)
- Programa la ejecución fuera del horario laboral

### Archivos Eliminados Permanentemente
- Los archivos NO van a la papelera, se eliminan permanentemente
- La papelera de reciclaje se vacía al final

## 📈 Recomendaciones

### Frecuencia de Ejecución
- **Producción:** Semanal (domingos 3:00 AM)
- **Desarrollo:** Mensual
- **Bajo Espacio en Disco:** Diario (temporalmente)

### Antes de Ejecutar
- Asegúrate de que no hay procesos críticos ejecutándose
- Si es la primera vez, considera hacer un backup

## 🐛 Solución de Problemas

### "No se pudo eliminar el archivo"
El archivo está en uso. Cierra la aplicación que lo está usando y ejecuta el script nuevamente.

### "No se pudo vaciar la papelera"
El script intentará un método alternativo automáticamente.

### "No se encontraron archivos para eliminar"
Normal si el script se ejecuta con frecuencia. No requiere acción.

## 📚 Ver También

- [ShrinkLogFiles.ps1](./ShrinkLogFiles.md) - Limpieza de logs de SQL Server
- [Guía de Instalación](../../installation.md)

---

[← Volver al índice](../../README.md)
