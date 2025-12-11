# 📉 ShrinkLogFiles.ps1

Script para reducir archivos LDF (logs de transacciones) excesivos en SQL Server.

## 📋 Descripción

Detecta automáticamente bases de datos con archivos LDF excesivamente grandes y los reduce cambiando temporalmente a modo SIMPLE, ejecutando DBCC SHRINKFILE, y restaurando el modo FULL.

## 🎯 ¿Qué Hace el Script?

1. Analiza el tamaño de archivos MDF (datos) y LDF (logs)
2. Identifica bases de datos con logs excesivos
3. Para cada base de datos que requiere reducción:
   - Cambia a modo `RECOVERY SIMPLE`
   - Ejecuta `DBCC SHRINKFILE`
   - Restaura el modo `RECOVERY FULL`
   - Muestra el espacio liberado

### Criterios de Reducción

Una base de datos se marca para reducción si cumple **AMBOS** criterios:
1. **Tamaño LDF > 100 MB**
2. **Porcentaje LDF/MDF > 10%**

**Puedes modificar estos umbrales en el script:**
```powershell
$ldfRatioThreshold = 0.10   # 10%
$ldfSizeThresholdMB = 100   # 100 MB
```

## 💻 Uso

```powershell
& C:\Scripts\iTraffic\ShrinkLogFiles.ps1
```

### Ejecución Programada

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\iTraffic\ShrinkLogFiles.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -WeeksInterval 4 -At 2am
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "iTraffic-ShrinkLogs" -Action $action `
    -Trigger $trigger -Principal $principal `
    -Description "Reducción mensual de archivos LDF excesivos"
```

## ⚠️ Advertencias Importantes

### Impacto Durante la Reducción
- ⚠️ La base de datos queda temporalmente en modo SIMPLE
- ⚠️ No se pueden hacer backups de transacciones durante el proceso
- ⚠️ Proceso I/O intensivo (puede tardar minutos en bases grandes)
- ⚠️ Pérdida temporal de recuperación point-in-time

### Cuándo NO Ejecutar
❌ **NO ejecutar** en estos casos:
- Durante horarios de alta actividad
- Si hay procesos de backup en ejecución
- Si hay replicación activa
- Si hay log shipping configurado
- En bases Always On sin planificación

### Recomendación
**Hacer backup completo inmediatamente después de ejecutar el script**

## 💡 Casos de Uso

### Emergencia por Falta de Espacio
```powershell
# 1. Ejecutar script
& C:\Scripts\iTraffic\ShrinkLogFiles.ps1

# 2. Verificar espacio liberado
Get-PSDrive C | Select-Object Used, Free
```

### Después de Migraciones o Cargas Masivas
```powershell
# Los logs crecen mucho durante estas operaciones
& C:\Scripts\iTraffic\ShrinkLogFiles.ps1

# Hacer backup completo después
sqlcmd -S SERVIDOR01 -Q "BACKUP DATABASE [MiBaseDatos] TO DISK = 'C:\Backups\MiBaseDatos.bak'"
```

## 🔄 Mantenimiento Preventivo

### Después de Usar Este Script

**1. Implementar backups de log regulares:**
```sql
-- Ejemplo: Backup de log cada hora
BACKUP LOG [NombreBaseDatos] TO DISK = 'C:\Backups\NombreBaseDatos_log.trn'
```

**2. Monitorear el crecimiento del log:**
```sql
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    name AS LogicalFileName,
    size * 8.0 / 1024 AS CurrentSizeMB
FROM sys.master_files
WHERE type_desc = 'LOG'
ORDER BY size DESC
```

**3. Ajustar el crecimiento automático:**
```sql
-- Usar crecimiento fijo en lugar de porcentaje
ALTER DATABASE [NombreBaseDatos] 
MODIFY FILE (NAME = LogicalFileName, FILEGROWTH = 512MB)
```

## 🔍 Requisitos

- `CommonSqlServerUtils.ps1` (en el mismo directorio)
- `sqlcmd` instalado y disponible
- Permisos de administrador en Windows
- Permisos ALTER DATABASE y DBCC en SQL Server (rol sysadmin)

## 🐛 Solución de Problemas

### "No se encontraron bases de datos con archivos LDF excesivos"
Todas las bases de datos están dentro de los umbrales. Esto es bueno.

### Error durante la ejecución
```sql
-- Verificar transacciones activas
DBCC OPENTRAN([NombreBaseDatos])

-- Verificar replicación
SELECT * FROM sys.databases WHERE is_published = 1 OR is_subscribed = 1
```

### El log no se reduce significativamente
Puede deberse a:
- Transacciones activas
- Replicación pendiente
- VLFs (Virtual Log Files) activos

```sql
-- Ver uso del log
DBCC SQLPERF(LOGSPACE)

-- Ver detalles
DBCC LOGINFO([NombreBaseDatos])
```

## 📚 Ver También

- [CommonSqlServerUtils.ps1](./CommonSqlServerUtils.md)
- [SetAllDatabasesToFullRecovery.ps1](./SetAllDatabasesToFullRecovery.md)
- [CleanUp.ps1](./CleanUp.md)

## 🔗 Referencias

- [DBCC SHRINKFILE - Microsoft Docs](https://docs.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-shrinkfile-transact-sql)
- [Transaction Log Management - Microsoft Docs](https://docs.microsoft.com/en-us/sql/relational-databases/logs/the-transaction-log-sql-server)

---

[← Volver al índice](../../README.md)
