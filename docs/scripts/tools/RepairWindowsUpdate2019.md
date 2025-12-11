# 🔧 RepairWindowsUpdate2019.ps1

Script para reparar Windows Update en Windows Server 2019.

## 📋 ¿Qué Hace?

1. Detiene servicios de Windows Update
2. Limpia carpetas corruptas (`SoftwareDistribution` y `catroot2`)
3. Reinicia los servicios
4. Programa un reinicio automático entre las 00:00 y 08:00

## 💻 Procedimiento

### 1. Conectarse al servidor
Accede mediante Remote Desktop.

### 2. Abrir PowerShell como Administrador y ejecutar el script
```powershell
cd C:\Scripts\iTraffic
.\RepairWindowsUpdate2019.ps1
```

### 3. Abrir Configuración
Presiona `Win + I`

### 4. Iniciar Actualizaciones
- Ve a **Update & Security**
- Haz clic en **Check for updates**

## ⚠️ Importante

- ⚠️ El servidor se reiniciará automáticamente entre las 00:00 y 08:00
- ⚠️ El script solo se puede ejecutar **una vez** por servidor

## 🔄 Cancelar el Reinicio

Si es necesario cancelar el reinicio programado:
```powershell
Unregister-ScheduledTask -TaskName "WindowsUpdateReboot" -Confirm:$false
```

---

[← Volver al índice](../../README.md)
