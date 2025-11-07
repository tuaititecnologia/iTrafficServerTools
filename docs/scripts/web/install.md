# 🌐 install.ps1 (Web)

Instalador automático que descarga e instala los scripts de iTraffic Server Tools desde GitHub.

## 📋 Descripción

Este instalador permite instalar o actualizar todos los scripts con un solo comando. Se ejecuta remotamente y no requiere descargas manuales.

## 💻 Uso

### Instalación desde tuaiti.com.ar
```powershell
irm https://tuaiti.com.ar/scripts/itraffic | iex
```

### Instalación directa desde GitHub
```powershell
irm https://raw.githubusercontent.com/tuaititecnologia/iTrafficServerTools/main/web/install.ps1 | iex
```

## 📁 Resultado de la Instalación

Los scripts se instalan en:

```
C:\Scripts\
├── iTraffic\
│   ├── CleanUp.ps1
│   ├── CommonSqlServerUtils.ps1
│   ├── SetAllDatabasesToFullRecovery.ps1
│   └── ShrinkLogFiles.ps1
└── Update.ps1
```

## 🔄 Actualización

Para actualizar, ejecuta el mismo comando nuevamente. Los archivos existentes serán sobrescritos.

## ⚠️ Consideraciones de Seguridad

⚠️ **Este script ejecuta código descargado de Internet**

**Buenas prácticas:**
1. Verifica el dominio antes de ejecutar
2. Inspecciona el contenido primero:
   ```powershell
   irm https://tuaiti.com.ar/scripts/itraffic
   ```
3. Prueba primero en un servidor de desarrollo

### Política de Ejecución

Si encuentras errores de política de ejecución:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 🐛 Solución de Problemas

### Error: "Administrator privileges required"
Ejecuta PowerShell como Administrador:
```powershell
Start-Process PowerShell -Verb RunAs
```

### Error: "Failed to get files list"
- Verifica tu conexión a Internet
- Comprueba que el firewall no bloquee GitHub
- Usa la URL directa de GitHub como alternativa

### Error: TLS/SSL
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

## 📚 Ver También

- [Update.ps1](../Update.md) - Script de actualización
- [Guía de Instalación](../../installation.md)

---

[← Volver al índice](../../README.md)
