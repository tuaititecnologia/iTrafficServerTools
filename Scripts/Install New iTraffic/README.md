# Install New iTraffic - Script de Instalación para Servidores Windows

Scripts de PowerShell para automatizar la instalación y configuración de un servidor Windows para iTraffic.

## ⚠️ Problema de Seguridad de PowerShell

En servidores Windows recién instalados, PowerShell bloquea la ejecución de scripts por defecto. **Solución: usar el comando de bypass al ejecutar.**

## 🚀 Procedimiento de Instalación

### Paso 1: Abrir PowerShell como Administrador

1. Presionar `Win + X`
2. Seleccionar "Windows PowerShell (Administrador)" o "Terminal (Administrador)"

### Paso 2: Navegar a la carpeta del proyecto

```powershell
cd "C:\ruta\a\Install New iTraffic"
```

### Paso 3: Ejecutar el script principal

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Main.ps1
```

Este comando evita el problema de la política de ejecución.

### Paso 4: Seleccionar opción en el menú

- **A** - Ejecutar TODOS los módulos (recomendado para instalación inicial)
- **U** - Update (actualizaciones de Windows)
- **1-7** - Ejecutar módulos individuales

### Paso 5: Ingresar datos del cliente

Cuando se solicite, ingresar:
- **Código del cliente**: 3 letras o números en MAYÚSCULA (ej: ABC)
- **Nombre de carpeta**: minúsculas y números, sin espacios (ej: cliente123)
- **Nombre del cliente**: Nombre completo

Los datos se guardan en `client_config.json` para uso futuro.

### Paso 6: Reiniciar el equipo

Al finalizar, el script preguntará si deseas reiniciar. Se recomienda reiniciar después de:
- Instalación de SQL Server
- Renombrado del equipo
- Instalación de actualizaciones

## 📋 Módulos del Proyecto

- **Utilities.ps1** - Instala 7zip, Notepad++, SQL Server Management Studio
- **Sql.ps1** - Instala y configura SQL Server Express (puerto 1433)
- **Firewall.ps1** - Configura reglas de firewall
- **IIS.ps1** - Instala y configura IIS
- **Users.ps1** - Crea usuarios locales softur y softur2
- **ComputerRename.ps1** - Renombra el equipo como `[CODIGO]-iTraffic`
- **Activate.ps1** - Activa Windows

## ⚙️ Requisitos

- Windows Server 2016+ o Windows 10/11
- Ejecutar como Administrador
- Conexión a Internet
- Mínimo 4GB RAM y 10GB espacio en disco

## 📝 Contraseñas Generadas

Después de la instalación, buscar en el Escritorio:
- `sql-sa-password.txt` - Contraseña del usuario SA de SQL Server
- `usuarios-softur.txt` - Contraseñas de usuarios softur y softur2

⚠️ **IMPORTANTE**: Guardar estas contraseñas de forma segura. Son generadas automáticamente.

## 🔧 Solución de Problemas

### Error: "No se puede cargar el archivo porque la ejecución de scripts está deshabilitada"

**Solución**: Usar siempre el comando con bypass:
```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Main.ps1
```

### Error: "Winget no está disponible"

Winget requiere Windows 10 1809+ o Windows Server con App Installer actualizado. El módulo Utilities.ps1 no funcionará sin Winget.

### Error al instalar SQL Server

- Verificar conexión a Internet
- Asegurar al menos 4GB de RAM disponible
- Verificar que no haya otra instancia de SQL Server instalada

## 🔒 Consideraciones de Seguridad

- Las contraseñas generadas se guardan en el escritorio. Eliminar estos archivos después de guardarlos en un lugar seguro.
- El script abre el puerto 1433 para SQL Server. Verificar que esto sea apropiado para tu entorno.
- Los usuarios `softur` y `softur2` se crean con privilegios de administrador.
