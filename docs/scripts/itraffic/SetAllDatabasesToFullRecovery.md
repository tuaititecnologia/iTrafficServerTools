# 🔄 SetAllDatabasesToFullRecovery.ps1

Script para establecer todas las bases de datos de usuario en modo de recuperación FULL en SQL Server.

## 📋 Descripción

Detecta automáticamente las instancias de SQL Server y cambia el modo de recuperación de todas las bases de datos de usuario (excluyendo las del sistema) a FULL. Útil para asegurar backups completos de transacciones.

## 🎯 Funcionalidades

- Detecta instancias de SQL Server automáticamente
- Permite seleccionar la instancia si hay más de una
- Lista el modo de recuperación actual de cada base de datos
- Cambia solo las bases de datos que no están en modo FULL
- Solicita confirmación antes de realizar cambios
- Muestra resumen de cambios realizados

**Bases de datos excluidas automáticamente:** `master`, `tempdb`, `model`, `msdb`

## 💻 Uso

```powershell
& C:\Scripts\iTraffic\SetAllDatabasesToFullRecovery.ps1
```

## 📊 Modos de Recuperación en SQL Server

### SIMPLE
- ❌ No permite backups de transacciones
- ✅ El log se trunca automáticamente
- ❌ Pérdida de datos desde el último backup completo

### FULL
- ✅ Permite backups de transacciones
- ✅ Recuperación point-in-time
- ⚠️ Los logs crecen más rápido
- ⚠️ Requiere backups de log regulares

### BULK_LOGGED
- Similar a FULL pero con operaciones masivas mínimamente registradas

## ⚠️ Importante

### Después de Cambiar a FULL

**Debes configurar backups de log regulares:**
```sql
-- Ejemplo: Backup de log cada hora
BACKUP LOG [NombreBaseDatos] TO DISK = 'C:\Backups\NombreBaseDatos_log.bak'
```

**Monitorear el crecimiento del log:**
```sql
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    name AS LogicalFileName,
    size * 8.0 / 1024 AS SizeMB
FROM sys.master_files
WHERE type_desc = 'LOG'
```

Si los logs crecen excesivamente, usa [ShrinkLogFiles.ps1](./ShrinkLogFiles.md)

## 💡 Casos de Uso

### Preparación para Backups de Producción
```powershell
# 1. Cambiar a FULL
& C:\Scripts\iTraffic\SetAllDatabasesToFullRecovery.ps1

# 2. Hacer backup completo inmediatamente
sqlcmd -S SERVIDOR01 -Q "BACKUP DATABASE [MiBaseDatos] TO DISK = 'C:\Backups\MiBaseDatos.bak'"
```

### Auditoría de Configuración
Ejecuta el script y responde 'N' cuando pregunte. Verás el estado actual sin cambiar nada.

### Reversión a SIMPLE
```powershell
sqlcmd -S SERVIDOR01 -Q "ALTER DATABASE [NombreBaseDatos] SET RECOVERY SIMPLE"
```

## 🔍 Requisitos

- `CommonSqlServerUtils.ps1` (en el mismo directorio)
- `sqlcmd` instalado y disponible
- Permisos de administrador en Windows
- Permisos ALTER DATABASE en SQL Server (rol sysadmin o dbcreator)

## 🐛 Solución de Problemas

### "sqlcmd utility not found"
Ver [Guía de Instalación](../../installation.md#instalar-sqlcmd-si-es-necesario)

### "No SQL Server instances found"
```powershell
# Verificar y arrancar servicios
Get-Service -Name "MSSQL*" | Select-Object Name, Status
Start-Service -Name "MSSQLSERVER"
```

### "ALTER DATABASE permission denied"
Ejecuta con una cuenta que tenga rol `sysadmin` o `dbcreator`

### Error al cambiar una base de datos específica
```sql
-- Verificar estado
SELECT name, state_desc FROM sys.databases WHERE name = 'NombreBaseDatos'
```

## 📚 Ver También

- [CommonSqlServerUtils.ps1](./CommonSqlServerUtils.md)
- [ShrinkLogFiles.ps1](./ShrinkLogFiles.md)
- [Guía de Instalación](../../installation.md)

## 🔗 Referencias

- [SQL Server Recovery Models - Microsoft Docs](https://docs.microsoft.com/en-us/sql/relational-databases/backup-restore/recovery-models-sql-server)

---

[← Volver al índice](../../README.md)
