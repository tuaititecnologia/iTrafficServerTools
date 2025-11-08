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

**[iTraffic](https://softur.com.ar/productos/itraffic)** es un sistema integral de gestión turística desarrollado por [Softur](https://www.softur.com.ar), diseñado específicamente para agencias de viajes y operadores turísticos.

### ¿Qué hace iTraffic?

iTraffic proporciona una solución completa para gestionar todos los aspectos de una empresa turística:

- **Gestión de Reservas y Ventas** - Excursiones, traslados, hotelería, paquetes y servicios
- **Operaciones** - Control de cupos, vouchers, pedidos a proveedores y despachos
- **Mesa de Tráfico** - Asignación de guías, vehículos y planificación de servicios
- **Administración** - Facturación electrónica, cobros, pagos, estados de cuenta
- **Tarifarios** - Gestión completa de precios, cupos y productos propios y de terceros
- **Informes y Estadísticas** - Más de 250 tipos de reportes para análisis y control

### Estas Herramientas

Los scripts de este repositorio han sido diseñados específicamente para facilitar el **mantenimiento y administración de los servidores SQL Server** que ejecutan iTraffic, optimizando el rendimiento y liberando espacio en disco.

## ⚠️ Advertencia

> ⚠️ **IMPORTANTE: DESCARGO DE RESPONSABILIDAD**

> El uso de estos scripts es bajo tu propia responsabilidad. Ni los autores, Ni Alejandro Ismael Sanchez (Tuaiti Tecnología) ni Softur S.A. se hacen responsables por la pérdida de información, daños, borrado de archivos o cualquier consecuencia resultante del uso de estas herramientas.  
> **Asegúrate siempre de realizar backups actualizados antes de ejecutar cualquier script. Testea en entornos de desarrollo cuando sea posible.**

