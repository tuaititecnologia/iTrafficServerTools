# iTraffic Server Tools

Herramientas de PowerShell para administración de servidores **iTraffic de Softur** ([www.softur.com.ar](https://www.softur.com.ar)).

Scripts de mantenimiento y optimización para SQL Server, compatibles con Windows Server 2012 R2 y versiones posteriores, usando `sqlcmd` para máxima compatibilidad.

## 📦 Instalación

### Método 1 - Instalación Automática (Recomendado)

Abre PowerShell como **Administrador** y ejecuta:

```powershell
irm https://tuaiti.com.ar/scripts/itraffic | iex
```

Si el dominio está bloqueado, puedes usar directamente desde GitHub:

```powershell
irm https://raw.githubusercontent.com/tuaititecnologia/iTrafficServerTools/main/web/install.ps1 | iex
```

### Método 2 - Instalación Manual

1. Clona o descarga este repositorio
2. Copia todos los archivos de la carpeta `scripts/iTraffic/` a `%SystemDrive%\Scripts\iTraffic`
3. Asegúrate de que `sqlcmd` esté disponible en el sistema

## 📋 Scripts Incluidos

### `SetAllDatabasesToFullRecovery.ps1`
Establece todas las bases de datos de usuario en modo de recuperación FULL.

**Características:**
- Detecta automáticamente instancias de SQL Server
- Muestra el estado actual de recuperación de cada base de datos
- Permite confirmación antes de realizar cambios
- Usa `sqlcmd` para máxima compatibilidad

**Uso:**
```powershell
& "$env:SystemDrive\Scripts\iTraffic\SetAllDatabasesToFullRecovery.ps1"
```

### `ShrinkLogFiles.ps1`
Reduce archivos LDF (archivos de log) excesivos en SQL Server.

**Características:**
- Detecta bases de datos con archivos LDF > 100 MB y > 10% del tamaño MDF
- Cambia temporalmente a modo SIMPLE para reducir el log
- Restaura el modo FULL después de la reducción
- Muestra estadísticas antes y después de la operación

**Uso:**
```powershell
& "$env:SystemDrive\Scripts\iTraffic\ShrinkLogFiles.ps1"
```

### `CleanUp.ps1`
Script de limpieza de logs y archivos temporales específico para entornos iTraffic.

**Uso:**
```powershell
& "$env:SystemDrive\Scripts\iTraffic\CleanUp.ps1"
```

### `CommonSqlServerUtils.ps1`
Librería común con funciones compartidas:
- `Get-SQLServerInstances`: Detecta instancias de SQL Server en el sistema
- `Invoke-SqlcmdQuery`: Ejecuta consultas SQL usando `sqlcmd`

Este archivo se carga automáticamente por los otros scripts.

## 🔧 Requisitos

- Windows Server 2012 R2 o superior
- PowerShell 3.0 o superior
- SQL Server con `sqlcmd` instalado
- Permisos de administrador para ejecutar los scripts

## 📁 Estructura del Proyecto

```
iTrafficServerTools/
├── scripts/              # Scripts organizados por categoría
│   └── iTraffic/         # Scripts de iTraffic (se instalan en %SystemDrive%\Scripts\iTraffic)
│       ├── CommonSqlServerUtils.ps1
│       ├── SetAllDatabasesToFullRecovery.ps1
│       ├── ShrinkLogFiles.ps1
│       └── CleanUp.ps1
├── web/                  # Archivos para el servidor web
│   ├── install.ps1      # Instalador (se sube a tuaiti.com.ar/scripts/itraffic)
│   └── index.php        # Endpoint PHP que sirve install.ps1
└── README.md
```

## 📝 Notas

- Todos los scripts requieren ejecutarse como **Administrador**
- Los scripts usan `sqlcmd` en lugar de módulos de PowerShell para máxima compatibilidad
- Los scripts detectan automáticamente las instancias de SQL Server disponibles
- Se excluyen automáticamente las bases de datos del sistema (master, tempdb, model, msdb)
- El instalador detecta automáticamente todos los scripts disponibles en el repositorio

## 🔗 Enlaces

- Repositorio: [https://github.com/tuaititecnologia/iTrafficServerTools](https://github.com/tuaititecnologia/iTrafficServerTools)
- Instalador: [https://tuaiti.com.ar/scripts/itraffic](https://tuaiti.com.ar/scripts/itraffic)

## 📄 Licencia

Este proyecto está bajo licencia MIT (o la licencia que corresponda).

## ℹ️ Acerca de iTraffic

**iTraffic** es un sistema de gestión de tránsito desarrollado por [Softur](https://www.softur.com.ar). Estas herramientas han sido diseñadas específicamente para facilitar el mantenimiento y administración de servidores que ejecutan iTraffic.

## ⚠️ Advertencia

- Siempre realiza backups antes de ejecutar scripts que modifican bases de datos
- Prueba los scripts en un entorno de desarrollo antes de usarlos en producción
- Verifica que tienes los permisos necesarios antes de ejecutar los scripts

