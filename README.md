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


📖 **[Ver documentación completa](./docs/README.md)**

## 🔧 Requisitos

- Windows Server 2012 R2 o superior
- PowerShell 3.0 o superior
- SQL Server con `sqlcmd` instalado
- Permisos de administrador para ejecutar los scripts

## 📁 Estructura del Proyecto

```
iTrafficServerTools/
├── Scripts/iTraffic/    # Scripts principales
├── web/                 # Instalador web
├── docs/                # Documentación completa
└── README.md
```

## 📝 Uso Rápido

```powershell
# Ejecutar cualquier script
& C:\Scripts\iTraffic\NombreDelScript.ps1
```

**Nota:** Todos los scripts requieren ejecutarse como **Administrador**

## 📚 Documentación

Para información detallada sobre cada script, casos de uso y solución de problemas, consulta la **[documentación completa](./docs/README.md)**.

## 🔗 Enlaces

- **Documentación:** [./docs/README.md](./docs/README.md)
- **Repositorio:** [https://github.com/tuaititecnologia/iTrafficServerTools](https://github.com/tuaititecnologia/iTrafficServerTools)
- **Instalador:** [https://tuaiti.com.ar/scripts/itraffic](https://tuaiti.com.ar/scripts/itraffic)
- **iTraffic:** [https://www.softur.com.ar](https://www.softur.com.ar)

## 📄 Licencia

Este proyecto está bajo licencia MIT (o la licencia que corresponda).

## ℹ️ Acerca de iTraffic

**iTraffic** es un sistema de gestión de tránsito desarrollado por [Softur](https://www.softur.com.ar). Estas herramientas han sido diseñadas específicamente para facilitar el mantenimiento y administración de servidores que ejecutan iTraffic.

## ⚠️ Advertencia

- Siempre realiza backups antes de ejecutar scripts que modifican bases de datos
- Prueba los scripts en un entorno de desarrollo antes de usarlos en producción
- Verifica que tienes los permisos necesarios antes de ejecutar los scripts

