# 📦 Guía de Instalación

Esta guía detalla los diferentes métodos para instalar iTraffic Server Tools en tu servidor.

## 🚀 Método 1: Instalación Automática (Recomendado)

### Prerrequisitos
- PowerShell con permisos de **Administrador**
- Conexión a Internet
- PowerShell 3.0 o superior

### Pasos

1. **Abre PowerShell como Administrador**  
   - Haz clic derecho en el ícono de PowerShell
   - Selecciona "Ejecutar como administrador"

2. **Ejecuta el instalador remoto**

   **Opción A - Desde tuaiti.com.ar (Recomendado):**
   ```powershell
   irm https://tuaiti.com.ar/scripts/itraffic | iex
   ```

   **Opción B - Directamente desde GitHub:**
   ```powershell
   irm https://raw.githubusercontent.com/tuaititecnologia/iTrafficServerTools/main/web/install.ps1 | iex
   ```

3. **Confirma la instalación**
   - El script solicitará confirmación
   - Escribe `y` y presiona Enter

4. **Espera a que se descarguen los archivos**
   - Los scripts se instalarán en `C:\Scripts\iTraffic`
   - Se abrirá automáticamente el Explorador de Windows en la carpeta

### ¿Qué hace el instalador?

- ✅ Verifica permisos de administrador
- ✅ Crea la estructura de directorios en `C:\Scripts`
- ✅ Descarga todos los scripts desde GitHub
- ✅ Mantiene la estructura de carpetas original
- ✅ Abre el Explorador en la carpeta de instalación

---

## 🔧 Método 2: Instalación Manual

### Prerrequisitos
- Acceso al repositorio de GitHub
- Permisos de escritura en `C:\Scripts`

### Pasos

1. **Descarga el repositorio**
   
   **Opción A - Con Git:**
   ```powershell
   cd C:\
   git clone https://github.com/tuaititecnologia/iTrafficServerTools.git
   ```

   **Opción B - Descarga directa:**
   - Visita: https://github.com/tuaititecnologia/iTrafficServerTools
   - Haz clic en "Code" → "Download ZIP"
   - Extrae el archivo ZIP

2. **Copia los scripts a la ubicación de instalación**
   ```powershell
   # Crear la carpeta destino
   New-Item -ItemType Directory -Path "C:\Scripts\iTraffic" -Force
   
   # Copiar scripts de iTraffic
   Copy-Item -Path ".\iTrafficServerTools\Scripts\iTraffic\*" -Destination "C:\Scripts\iTraffic" -Recurse -Force
   
   # Copiar Update.ps1
   Copy-Item -Path ".\iTrafficServerTools\Scripts\Update.ps1" -Destination "C:\Scripts\Update.ps1" -Force
   ```

3. **Verifica la instalación**
   ```powershell
   Get-ChildItem "C:\Scripts\iTraffic"
   ```

   Deberías ver los siguientes archivos:
   - `CleanUp.ps1`
   - `CommonSqlServerUtils.ps1`
   - `SetAllDatabasesToFullRecovery.ps1`
   - `ShrinkLogFiles.ps1`

---

## 🔍 Verificación de Requisitos

### Verificar PowerShell
```powershell
$PSVersionTable.PSVersion
```
Debe ser versión 3.0 o superior.

### Verificar sqlcmd
```powershell
sqlcmd -?
```
Si se muestra la ayuda de `sqlcmd`, está instalado correctamente.

### Instalar sqlcmd (si es necesario)

**Opción 1 - SQL Server Command Line Utilities:**
- Descarga desde: [Microsoft SQL Server Command Line Utilities](https://docs.microsoft.com/en-us/sql/tools/sqlcmd-utility)

**Opción 2 - Con Chocolatey:**
```powershell
choco install sqlserver-cmdlineutils
```

### Verificar Permisos de Administrador
```powershell
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```
Debe devolver `True`.

---

## 📂 Estructura de Instalación

Después de la instalación, la estructura de archivos será:

```
C:\Scripts\
├── iTraffic\
│   ├── CleanUp.ps1
│   ├── CommonSqlServerUtils.ps1
│   ├── SetAllDatabasesToFullRecovery.ps1
│   └── ShrinkLogFiles.ps1
└── Update.ps1
```

---

## 🔄 Actualización

Para actualizar a la última versión de los scripts:

```powershell
& C:\Scripts\Update.ps1
```

O ejecuta nuevamente el instalador automático, que sobrescribirá los archivos existentes.

---

## 🐛 Solución de Problemas

### Error: "No se puede ejecutar porque está deshabilitado el ejecutar scripts en este sistema"

**Solución:** Cambiar la política de ejecución de PowerShell
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Error: "Administrator privileges required"

**Solución:** Ejecuta PowerShell como Administrador
- Haz clic derecho en PowerShell → "Ejecutar como administrador"

### Error: "No se puede descargar el archivo"

**Solución 1:** Verifica tu conexión a Internet

**Solución 2:** Verifica que no haya un firewall bloqueando la descarga

**Solución 3:** Usa la instalación manual

### Error: "sqlcmd utility not found"

**Solución:** Instala SQL Server Command Line Utilities
- Ver sección "Instalar sqlcmd" arriba

---

## ✅ Siguiente Paso

Una vez instalado, consulta la documentación de cada script:
- [CleanUp.ps1](./scripts/itraffic/CleanUp.md)
- [SetAllDatabasesToFullRecovery.ps1](./scripts/itraffic/SetAllDatabasesToFullRecovery.md)
- [ShrinkLogFiles.ps1](./scripts/itraffic/ShrinkLogFiles.md)

---

[← Volver al índice](./README.md)

