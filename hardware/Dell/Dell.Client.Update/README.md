# Dell.Client.Update

`Dell.Client.Update` is a PowerShell 5.1 module for discovering and installing Dell updates without requiring Dell Command Update, Dell OpenManage Inventory Agent, or the Dell `dcu-cli.exe` executable.

The module downloads Dell's public catalog index, selects the model-specific catalog for the local computer, evaluates that catalog against native Windows device and driver inventory, and returns PowerShell objects that can be piped directly into the installer.

## Requirements

- Windows PowerShell 5.1 or newer
- A Dell client computer
- Internet access to `https://downloads.dell.com`
- Administrator rights for package installation, registry reporting, and WMI export
- Windows CIM, Authenticode, and `expand.exe` support

Discovery does not depend on Dell Command Update. Installation invokes only the Dell Update Package executables selected from the public model catalog.

## Import

```powershell
Import-Module .\Dell.Client.Update.psd1 -Force
```

When developing or updating the module in an existing PowerShell session, remove the old in-memory copy first:

```powershell
Remove-Module Dell.Client.Update -Force -ErrorAction SilentlyContinue
Import-Module .\Dell.Client.Update.psd1 -Force
```

Confirm the loaded version and path:

```powershell
Get-Module Dell.Client.Update | Select-Object Name, Version, Path
```

## Storage Layout

Downloaded files and persistent module data are intentionally separated.

| Purpose | Location | Retention |
| --- | --- | --- |
| Downloaded catalog CABs | `C:\Windows\Temp\Dell` | Retained for troubleshooting |
| Temporary update payloads | `C:\Windows\Temp\Dell\<session-guid>` | Removed after installation when `-Path` is omitted |
| Extracted model catalogs | `C:\ProgramData\DellPSUpdate\Catalogs` | Retained |
| Installation logs | `C:\ProgramData\DellPSUpdate\Logs` | Retained unless `-NoLog` is used |
| JSON installation history | `C:\ProgramData\DellPSUpdate\History` | Retained |

When `Install-DellUpdate -Path <directory>` is used, that directory is treated as a reusable package cache and is not removed automatically.

## Commands

The module exports:

- `Get-DellUpdate`
- `Install-DellUpdate`
- `Get-DellUpdateHist`

## Get-DellUpdate

Discovers updates needed by the local Dell computer.

```powershell
Get-DellUpdate
```

By default, only the newest applicable packages that are not fully installed are returned. Dell OpenManage Inventory Agent packages are always excluded.

Common usage:

```powershell
# Discover needed updates
$updates = Get-DellUpdate

# Show useful fields
$updates | Format-Table ReleaseID, Name, Version, Type, Category, Severity

# Include matched packages that are already current
Get-DellUpdate -All

# Reuse the extracted model catalog
Get-DellUpdate -UseCachedCatalog

# Include detailed device/version matching in verbose output
Get-DellUpdate -ExplainRules -Verbose
```

### Discovery Process

1. Read the Dell system ID from `Win32_ComputerSystem.SystemSKUNumber`.
2. Download Dell's public `CatalogIndexPC.cab` to `C:\Windows\Temp\Dell`.
3. Resolve the model-specific catalog CAB.
4. Validate the model catalog CAB using Dell's published SHA-256 digest.
5. Extract the model XML under `C:\ProgramData\DellPSUpdate\Catalogs`.
6. Build native inventory from `Win32_PnPSignedDriver` and installed OEM extension INF files.
7. Match Dell PCI, PnP, generic, DCH, BIOS, OS, and architecture metadata.
8. Select the newest package for each Dell component family.
9. Exclude OpenManage Inventory Agent and packages already considered current.

### Update Object

Returned objects use the type name `Dell.Client.Update.DellUpdate` and include:

- `ID`, `PackageID`, and `ReleaseID`
- `Name`, `Title`, `Version`, and `DellVersion`
- `Type`, `Category`, and `Severity`
- `ReleaseDate`, `Size`, and `FileSize`
- `DownloadUri` and `URL`
- `Sha256`
- `Installer.Program`, `Installer.Arguments`, and `Installer.Unattended`
- `IsApplicable` and `IsInstalled`
- `MatchedDevices`

## Install-DellUpdate

Installs package objects returned by `Get-DellUpdate`, or discovers packages by ID.

### Pipeline Installation

```powershell
Get-DellUpdate | Install-DellUpdate
```

Without `-Force`, the command displays the selected packages and asks for confirmation. Use `-WhatIf` to verify selection without downloading or executing update payloads:

```powershell
Get-DellUpdate | Install-DellUpdate -WhatIf
```

### Package Selection

```powershell
# Install by Dell release/package ID
Install-DellUpdate -PackageIds G896W, 4YHV8

# Consume an explicit package object
$update = Get-DellUpdate | Where-Object ReleaseID -eq 'G896W'
Install-DellUpdate -Package $update

# Exclude one package
Get-DellUpdate | Install-DellUpdate -ExcludePackageIds 4YHV8

# Skip the confirmation prompt
Get-DellUpdate | Install-DellUpdate -Force
```

`-PackageIds` and `-Packages` are separate parameter sets and cannot be used together.

### Dell Filters

Filters are optional. Omitting a filter includes every value in that dimension.

Dell component types:

```text
Application, BIOS, Driver, Firmware
```

Dell categories currently represented in the model catalog:

```text
Application, Audio, BIOS, Chipset, Communications, Docks/Stands,
Input, Network, Security, Serial ATA, Storage, Systems Management, Video
```

Dell criticalities:

```text
Urgent, Recommended
```

Examples:

```powershell
# All applicable Driver packages
Get-DellUpdate | Install-DellUpdate -Type Driver

# Recommended chipset drivers
Get-DellUpdate |
    Install-DellUpdate -Type Driver -Category Chipset -Severities Recommended

# BIOS packages only
Get-DellUpdate | Install-DellUpdate -Type BIOS
```

### Download and Trust Validation

Before execution, every package must pass all of these checks:

1. The download URI uses HTTPS.
2. The downloaded SHA-256 digest matches the model catalog.
3. The Authenticode signature is valid.
4. The signer organization is Dell Inc. or Dell Technologies Inc.

There is intentionally no signature-bypass switch.

Packages are invoked with Dell Update Package silent arguments (`/s`). Exit code `0` is treated as success without a reboot. Exit code `2` is treated as success with a mandatory reboot. Other exit codes are returned as failures.

### Installation Result

Each attempted package returns a `Dell.Client.Update.DellInstallResult` object containing:

- `ID`, `PackageID`, and `ReleaseID`
- `Title`
- `Success`
- `ExitCode`
- `FailureReason`
- `RebootRequired`
- `PendingAction`
- `LogPath`
- `Runtime`

A failure for one package is returned as a structured result and does not prevent remaining selected packages from being attempted.

### Logging

Text logging is enabled by default. Logs are written to:

```text
C:\ProgramData\DellPSUpdate\Logs
```

Use `-NoLog` to disable text logs. JSON history is still recorded for actual installation attempts.

### Proxy Support

```powershell
Install-DellUpdate -PackageIds G896W `
    -Proxy 'http://proxy.contoso.com:8080' `
    -ProxyUseDefaultCredentials
```

Use `-ProxyCredential` when explicit proxy credentials are required.

## Installation Reporting

### JSON History

Every non-`WhatIf` installation session that attempts at least one package writes an append-only JSON file under:

```text
C:\ProgramData\DellPSUpdate\History\InstallHist-<timestamp>-<guid>.json
```

History includes successful and failed attempts, package identity, type/category/severity, exit code, reboot state, computer/user identity, package hash, message, and runtime.

### BIOS Registry Reporting

Use `-SaveBIOSUpdateInfoToRegistry` to write the latest attempted BIOS result to:

```text
HKLM:\SOFTWARE\Dell\ClientUpdate\BIOSUpdate
```

Recorded values include install date, package and release IDs, target versions, package hash, status, exit code, message, and pending action. Non-BIOS packages do not update this key.

```powershell
Get-DellUpdate |
    Where-Object Type -eq BIOS |
    Install-DellUpdate -SaveBIOSUpdateInfoToRegistry
```

### WMI Reporting

Use `-ExportToWMI` to append every attempted package result to:

```text
Namespace: root\DellClientUpdate
Class:     Dell_UpdateHistory
```

```powershell
Get-DellUpdate | Install-DellUpdate -ExportToWMI
Get-CimInstance -Namespace root\DellClientUpdate -ClassName Dell_UpdateHistory
```

Registry or WMI reporting failures are logged and emitted as warnings. They do not change the actual package installation result.

`-WhatIf` creates no registry, WMI, JSON history, text log, or payload files. Catalog discovery can still refresh Dell's public catalog when `Install-DellUpdate -PackageIds ... -WhatIf` must determine current applicability.

## Get-DellUpdateHist

Reads JSON history and returns `Dell.Client.Update.DellUpdateHistory` objects newest first.

```powershell
# Complete history
Get-DellUpdateHist

# Failed attempts
Get-DellUpdateHist -Status Failed

# Recent BIOS attempts
Get-DellUpdateHist -Type BIOS -Last 10

# Chipset driver attempts
Get-DellUpdateHist -Category Chipset -Type Driver
```

Available filters:

- `-Status Success, Failed`
- `-Category <Dell category[]>`
- `-Type Application, BIOS, Driver, Firmware`
- `-Last <count>`

Malformed files or records generate warnings while other valid history remains available.

## Operational Notes

- Run installation from an elevated PowerShell session.
- Review and suspend BitLocker protectors according to organizational policy before BIOS or firmware updates. The module does not change BitLocker state.
- Ensure AC power and required battery charge before BIOS or firmware updates.
- The module does not automatically reboot the computer. Inspect `RebootRequired` or `PendingAction`.
- A second discovery/install pass may identify updates that become applicable after dependencies are installed.
- `-Force` suppresses the module's package-list confirmation; standard PowerShell `-Confirm` and `-WhatIf` behavior remains available.
- Static filter validation reflects Dell values observed in the supported model catalog. Update the module if Dell introduces a new taxonomy value.

## Troubleshooting

### Old Function Still Runs

If output mentions `DellSDPCatalogPC.cab` or OpenManage Inventory Agent, an older module is still loaded:

```powershell
Remove-Module Dell.Client.Update -Force -ErrorAction SilentlyContinue
Import-Module .\Dell.Client.Update.psd1 -Force
Get-Module Dell.Client.Update | Select-Object Name, Version, Path
```

Current discovery uses `CatalogIndexPC.cab` and a model-specific catalog.

### No Updates Returned

```powershell
Get-DellUpdate -All -UseCachedCatalog | Format-Table Name, Version, IsInstalled
Get-DellUpdate -UseCachedCatalog -ExplainRules -Verbose
```

### Inspect Stored State

```powershell
Get-ChildItem C:\ProgramData\DellPSUpdate -Recurse
Get-DellUpdateHist -Last 20
Get-CimInstance -Namespace root\DellClientUpdate -ClassName Dell_UpdateHistory
```

## Development Validation

```powershell
# Manifest and import
Test-ModuleManifest .\Dell.Client.Update.psd1
Remove-Module Dell.Client.Update -Force -ErrorAction SilentlyContinue
Import-Module .\Dell.Client.Update.psd1 -Force

# Safe behavior tests
Get-DellUpdate -UseCachedCatalog
Get-DellUpdate | Install-DellUpdate -WhatIf
Get-DellUpdateHist -Last 10

# Pester tests
Invoke-Pester .\tests\Dell.Client.Update.Tests.ps1
```

See [CHANGELOG.md](CHANGELOG.md) for release history.
