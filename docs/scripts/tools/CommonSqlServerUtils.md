# 🔧 CommonSqlServerUtils.ps1

Librería de funciones compartidas para trabajar con SQL Server usando `sqlcmd`.

## 📋 Descripción

**NO es un script ejecutable directamente.** Contiene funciones de utilidad que son importadas por otros scripts del proyecto.

## ⚠️ Importante

**NO ejecutes este archivo directamente.** Es una librería que debe ser importada por otros scripts.

## 🎯 Funciones Disponibles

### Get-SQLServerInstances

Detecta automáticamente todas las instancias de SQL Server instaladas y en ejecución.

**Uso:**
```powershell
$instances = Get-SQLServerInstances
```

**Retorna:** Array con nombres de instancias (ej: `SERVIDOR01`, `SERVIDOR01\SQLEXPRESS`)

### Invoke-SqlcmdQuery

Ejecuta consultas SQL de forma segura usando `sqlcmd`.

**Uso:**
```powershell
$query = "SELECT name FROM sys.databases"
$resultado = Invoke-SqlcmdQuery -ServerInstance "SERVIDOR01" -Query $query
```

**Parámetros:**
- `ServerInstance`: Nombre de la instancia de SQL Server
- `Query`: Consulta SQL a ejecutar

## 💻 Cómo Usar Esta Librería

### Importar la Librería

```powershell
# Método recomendado (desde el mismo directorio del script)
$libraryPath = Join-Path -Path $PSScriptRoot -ChildPath 'CommonSqlServerUtils.ps1'
if (-not (Test-Path $libraryPath)) {
    Write-Host "Librería no encontrada: $libraryPath" -ForegroundColor Red
    exit
}
. $libraryPath
```

### Ejemplo Completo de Uso

```powershell
# Importar librería
. C:\Scripts\iTraffic\CommonSqlServerUtils.ps1

# Detectar instancias
$instances = Get-SQLServerInstances
if ($instances.Count -eq 0) {
    Write-Host "No se encontraron instancias de SQL Server" -ForegroundColor Red
    exit
}

# Usar la primera instancia encontrada
$instance = $instances[0]
Write-Host "Usando instancia: $instance" -ForegroundColor Green

# Ejecutar consulta
$query = "SELECT name FROM sys.databases WHERE name NOT IN ('master','tempdb','model','msdb')"
$databases = Invoke-SqlcmdQuery -ServerInstance $instance -Query $query

# Mostrar resultados
foreach ($db in $databases) {
    Write-Host "Base de datos: $db"
}
```

## 📚 Scripts que Usan Esta Librería

- [SetAllDatabasesToFullRecovery.ps1](./SetAllDatabasesToFullRecovery.md)
- [ShrinkLogFiles.ps1](./ShrinkLogFiles.md)

## 🔍 Requisitos

- **sqlcmd** instalado y disponible en el PATH
- **PowerShell** 3.0 o superior
- Al menos una instancia de SQL Server instalada y en ejecución

### Verificar sqlcmd
```powershell
if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    Write-Host "sqlcmd no encontrado" -ForegroundColor Red
}
```

## 🐛 Solución de Problemas

### "sqlcmd utility not found"
Instala [SQL Server Command Line Utilities](https://docs.microsoft.com/en-us/sql/tools/sqlcmd-utility)

### "No SQL Server instances found"
```powershell
# Verificar servicios
Get-Service -Name "MSSQL*" | Select-Object Name, Status

# Iniciar servicio si está detenido
Start-Service -Name "MSSQLSERVER"
```

### "Error executing sqlcmd"
- Verifica la sintaxis SQL
- Comprueba permisos en SQL Server
- Asegúrate de que la instancia esté disponible

## 📚 Ver También

- [SetAllDatabasesToFullRecovery.ps1](./SetAllDatabasesToFullRecovery.md)
- [ShrinkLogFiles.ps1](./ShrinkLogFiles.md)
- [Guía de Instalación](../../installation.md)

---

[← Volver al índice](../../README.md)
