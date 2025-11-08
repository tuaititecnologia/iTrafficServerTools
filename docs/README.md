# 📚 Documentación de iTraffic Server Tools

Bienvenido a la documentación completa de iTraffic Server Tools. Esta colección de scripts de PowerShell está diseñada para facilitar la administración de SQL Server y tareas de mantenimiento del servidor.

## 📖 Índice General

### 🚀 Inicio Rápido
- [Guía de Instalación](./installation.md)

### 📜 Scripts de iTraffic

Scripts principales para administración de SQL Server y limpieza del sistema:

1. **[CleanUp.ps1](./scripts/itraffic/CleanUp.md)**  
   Script de limpieza automática de logs y archivos temporales
   
2. **[SetAllDatabasesToFullRecovery.ps1](./scripts/itraffic/SetAllDatabasesToFullRecovery.md)**  
   Establece todas las bases de datos en modo de recuperación FULL
   
3. **[ShrinkLogFiles.ps1](./scripts/itraffic/ShrinkLogFiles.md)**  
   Reduce archivos LDF excesivos en SQL Server
   
4. **[CommonSqlServerUtils.ps1](./scripts/itraffic/CommonSqlServerUtils.md)**  
   Librería común con funciones compartidas para SQL Server

### 🔄 Scripts de Actualización

1. **[Update.ps1](./scripts/Update.md)**  
   Script de actualización de herramientas

### 🌐 Instalador Web

1. **[install.ps1](./scripts/web/install.md)**  
   Instalador automático desde repositorio remoto

## 🔧 Requisitos del Sistema

- **Sistema Operativo:** Windows Server 2012 R2 o superior
- **PowerShell:** Versión 3.0 o superior
- **SQL Server:** Con `sqlcmd` instalado
- **Permisos:** Administrador

## 📁 Estructura del Proyecto

```
iTrafficServerTools/
├── Scripts/
│   ├── iTraffic/          # Scripts principales de administración
│   │   ├── CleanUp.ps1
│   │   ├── CommonSqlServerUtils.ps1
│   │   ├── SetAllDatabasesToFullRecovery.ps1
│   │   └── ShrinkLogFiles.ps1
│   └── Update.ps1
├── web/                    # Scripts de distribución web
│   ├── install.ps1
│   └── index.php
└── docs/                   # Documentación (este directorio)
    ├── README.md
    ├── installation.md
    └── scripts/
```

## 💡 Casos de Uso Comunes

### Mantenimiento Rutinario
1. Ejecutar `CleanUp.ps1` para liberar espacio en disco
2. Ejecutar `ShrinkLogFiles.ps1` para reducir archivos de log excesivos
3. Verificar que las bases de datos estén en modo FULL con `SetAllDatabasesToFullRecovery.ps1`

### Instalación en Nuevo Servidor
1. Ejecutar el instalador remoto:
   ```powershell
   irm https://tuaiti.com.ar/scripts/itraffic | iex
   ```
2. Los scripts se instalan automáticamente en `C:\Scripts\iTraffic`

### Actualización de Scripts
1. Ejecutar `Update.ps1` para obtener la última versión

## ⚠️ Advertencias Importantes

- **Siempre realiza backups** antes de ejecutar scripts que modifican bases de datos
- **Prueba en desarrollo** antes de usar en producción
- **Ejecuta como Administrador** todos los scripts
- **Verifica permisos** antes de ejecutar operaciones críticas

## 🔗 Enlaces Útiles

- [Repositorio GitHub](https://github.com/tuaititecnologia/iTrafficServerTools)
- [Instalador Web](https://tuaiti.com.ar/scripts/itraffic)

## 📞 Soporte

Para problemas, sugerencias o contribuciones, visita el repositorio en GitHub.

---

**Última actualización:** Noviembre 2025  
**Versión de Documentación:** 1.0

