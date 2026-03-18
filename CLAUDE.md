# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**iTraffic Server Tools** is a PowerShell automation framework for provisioning and maintaining Windows Server environments running **iTraffic** (a tourism management system by Softur/Tuaiti). Targets Windows Server 2012 R2+ and Windows 10/11. All scripts require Administrator privileges.

## Running Scripts

```powershell
# Remote install (one-liner for customer deployment)
irm https://tuaiti.com.ar/scripts/itraffic | iex

# Run the main installer locally
powershell.exe -ExecutionPolicy Bypass -File ".\Scripts\Install New iTraffic\Main.ps1"

# Update existing installation from GitHub
& C:\Scripts\Update.ps1

# Run individual maintenance tools
& C:\Scripts\Tools\CleanUp.ps1
& C:\Scripts\Tools\ShrinkLogFiles.ps1
& C:\Scripts\Tools\SetAllDatabasesToFullRecovery.ps1
& C:\Scripts\Tools\SetAllDatabasesToSimpleRecovery.ps1
```

There is no build system or test suite — scripts are executed directly on Windows targets.

## Architecture

### Installation Suite (`Scripts/Install New iTraffic/`)

**Main.ps1** is the menu-driven orchestrator. It dot-sources `ClientData.ps1` on startup to load or prompt for client configuration, then presents a menu for running all modules (A), updating scripts (U), or individual modules (1–9).

**ClientData.ps1** manages persistent client configuration stored at `%ProgramData%\iTrafficServerTools\client_config.json` (outside the script folder so it survives updates). Stores three fields:
- `client_code`: 3 uppercase alphanumeric chars (used as hostname prefix)
- `client_string`: lowercase alphanumeric, no spaces (used as folder/DB name)
- `client_name`: free text (used in IIS welcome page)

Each installation module is a standalone `.ps1` file that can be run independently or via Main.ps1. The nine modules in menu order: Utilities → SQL → Firewall → IIS → Users → ComputerRename → Activate → AntivirusConfig → Backup.

### Maintenance Tools (`Scripts/Tools/`)

**CommonSqlServerUtils.ps1** is a shared library that must be dot-sourced, not executed directly. It provides:
- `Get-SQLServerInstances`: Reads registry at `HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL` to discover running instances
- `Invoke-SqlcmdQuery`: Executes T-SQL via the `sqlcmd` utility, writing scripts to temp files and parsing `|`-delimited output

Scripts that require SQL access dot-source CommonSqlServerUtils.ps1 at the top. When multiple SQL instances are detected, these scripts present a selection menu.

**CleanUp.ps1** auto-registers itself as a Windows scheduled task (`iTraffic-CleanUp`, daily at 2:00 AM) on first run. It behaves non-interactively when running as a scheduled task.

### Remote Deployment (`web/install.ps1`)

Uses the GitHub API (`api.github.com`) to recursively enumerate all files in `/Scripts`, then downloads each from `raw.githubusercontent.com` to `C:\Scripts`. The top-level `Scripts/Update.ps1` simply re-runs this installer. TLS 1.2 is explicitly set for Windows Server 2016 compatibility.

### NetBird Standalone (`Install-NetBird-Standalone.ps1`)

Independent script (not yet in the main installer menu) that fetches the latest NetBird MSI from GitHub releases and registers it with the Tuaiti management server. Accepts `-SkipRegistration` flag.

## Key Conventions

- **Library dot-sourcing**: Shared code (CommonSqlServerUtils.ps1) is dot-sourced with `. "$PSScriptRoot\CommonSqlServerUtils.ps1"`. Never execute library files directly.
- **T-SQL via sqlcmd**: All SQL execution goes through `Invoke-SqlcmdQuery` in CommonSqlServerUtils.ps1, which handles temp file creation and `|`-delimited output parsing.
- **Credentials saved to Desktop**: SQL SA passwords and user credentials are written to text files on the logged-in user's Desktop after creation.
- **Winget for software**: Utilities.ps1 uses `winget install --source winget` for package installation. This requires Windows Package Manager (built into Windows 10 1809+; must be installed separately on Server).
- **Network share for backup**: Backup.ps1 connects to `\\172.21.15.130\TuaitiBackup` — this is the internal Tuaiti backup NAS.
