# 🔄 Update.ps1

Script para actualizar todos los scripts de iTraffic Server Tools a la última versión disponible.

## 📋 Descripción

Ejecuta el instalador remoto para descargar y actualizar automáticamente todos los scripts del proyecto. Proporciona una forma rápida de obtener las últimas mejoras y correcciones sin tener que recordar URLs.

## 💻 Uso

### Ejecución Básica

```powershell
& C:\Scripts\Update.ps1
```

### Ejecución Remota

```powershell
Invoke-Command -ComputerName SERVIDOR01 -FilePath C:\Scripts\Update.ps1
```

## 🔄 Actualización Automática

### Programar Actualización Semanal

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Update.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 1am
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "iTraffic-AutoUpdate" -Action $action -Trigger $trigger `
    -Principal $principal -Description "Actualización automática semanal de iTraffic Server Tools"
```

### Actualización Silenciosa (Sin Confirmación)

```powershell
irm https://tuaiti.com.ar/scripts/itraffic | iex
```

## ⚠️ Advertencias

### Archivos Personalizados
⚠️ **La actualización sobrescribe TODOS los archivos en `C:\Scripts`**

Si has personalizado scripts:
1. Haz backup antes de actualizar
2. Usa un directorio separado para personalizaciones
3. Usa Git para controlar tus cambios

### Requisitos
- Permisos de administrador
- Conexión a Internet
- Acceso a `tuaiti.com.ar` y `raw.githubusercontent.com`

## 🐛 Solución de Problemas

### Error: "No se puede ejecutar scripts"
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Error: "No se puede conectar a tuaiti.com.ar"
Usa la URL de GitHub directamente:
```powershell
irm https://raw.githubusercontent.com/tuaititecnologia/iTrafficServerTools/main/web/install.ps1 | iex
```

### Los archivos no se actualizan
Ejecuta PowerShell como Administrador.

## 📚 Ver También

- [install.ps1](./web/install.md) - Instalador automático
- [Guía de Instalación](../installation.md)

---

[← Volver al índice](../README.md)
