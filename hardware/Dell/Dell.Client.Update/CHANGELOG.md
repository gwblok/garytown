# Changelog

All notable changes to `Dell.Client.Update` are documented here.

The format follows Keep a Changelog conventions. The module currently uses semantic-style version numbers while the API is still evolving.

## [Unreleased]

### Added

- Added `Get-DellUpdate -Details` and concise default output with `WhyApplicable` evidence.
- Added `Get-DellUpdate -HonorDCUPolicy` to honor DCU release-delay, update-type, device-category, and severity filters.
- Added `Get-DellUpdate -DelayDays` with a supported range of 1 through 45 days.

### Changed

- Downloads now use Background Intelligent Transfer Service (BITS).
- Catalog and update payload downloads are retained under `C:\ProgramData\DellPSUpdate\Downloads`.
- DCH base, component, and extension inventory matching now preserves Dell INF roles to avoid false-positive updates.

## [0.5.0] - 2026-09-27

### Added in 0.5.0

- Added `Get-DellUpdateHist`.
- Added automatic JSON history for every non-`WhatIf` installation session that attempts at least one package.
- Added history filters for status, Dell category, Dell component type, and result count.
- Added append-only history records with package IDs, release IDs, Dell version, result, reboot state, user/computer identity, hash, message, and runtime.
- Added centralized module storage helpers.
- Added detailed module README and operational guidance.
- Added an offline Pester regression suite for packaging, pipeline, trust, `WhatIf`, and history behavior.

### Changed in 0.5.0

- Persistent module data now uses `C:\ProgramData\DellPSUpdate`:
  - `Catalogs`
  - `History`
  - `Logs`
- Downloaded catalog CABs and package payloads use `C:\ProgramData\DellPSUpdate\Downloads`.
- History filenames now include a GUID to prevent collisions.
- Malformed history records are skipped individually instead of hiding every valid record in the same file.
- Removed the obsolete global WSUS-style catalog engine and its unused module state.
- Hardened missing XML-node handling and multi-value hardware ID ingestion.
- Tightened model catalog host and SHA-256 validation.
- Tightened package signer validation to Dell Inc. or Dell Technologies Inc.

## [0.4.0] - 2026-09-27

### Added in 0.4.0

- Added `-SaveBIOSUpdateInfoToRegistry` to `Install-DellUpdate`.
- Added Dell BIOS result reporting under `HKLM:\SOFTWARE\Dell\ClientUpdate\BIOSUpdate`.
- Added `-ExportToWMI` to `Install-DellUpdate`.
- Added append-only `root\DellClientUpdate:Dell_UpdateHistory` records for installation auditing and compliance.
- Added structured reporting for successful and failed package attempts.

### Security in 0.4.0

- Registry and WMI reporting require an elevated PowerShell session.
- Reporting failures do not alter package installation outcomes.
- `-WhatIf` suppresses registry and WMI writes.

## [0.3.0] - 2026-09-27

### Added in 0.3.0

- Added Panasonic-inspired package selection:
  - `-PackageIds`
  - pipeline/`-Packages`
  - `-ExcludePackageIds`
  - `-Force`
  - `-NoLog`
- Added Dell-native `-Category`, `-Type`, and `-Severities` filters.
- Added Lenovo-inspired `-Package` alias, reusable `-Path` cache, proxy support, Authenticode verification, and structured `FailureReason` output.
- Added `RebootRequired` and `PendingAction` installation result fields.
- Added per-package failure handling so one failed package does not terminate the entire selected batch.

### Changed in 0.3.0

- Omitting category, type, or severity filters includes all values.
- Dell categories and criticalities are based on model catalog values rather than Panasonic or Lenovo taxonomy.
- Package SHA-256 and Dell Authenticode validation are mandatory.
- Removed license-acceptance and signature-bypass switches that were not appropriate for this module.

## [0.2.0] - 2026-09-26

### Added in 0.2.0

- Added model-specific Dell catalog discovery through `CatalogIndexPC.cab`.
- Added SHA-256 validation of model catalog CABs.
- Added native inventory from `Win32_PnPSignedDriver` and installed OEM extension INF files.
- Added Dell PCI, PnP, generic, DCH, OS, architecture, BIOS, and component-version matching.
- Added model-catalog payload metadata to update objects.
- Added model-catalog Dell Update Package installation support.

### Changed in 0.2.0

- Replaced the 168 MB global `DellSDPCatalogPC.xml` scan with the approximately 9 MB model-specific catalog.
- Excluded Dell OpenManage Inventory Agent packages.
- Selected only the newest applicable package per Dell component family.
- Corrected duplicate historical Realtek Audio results.
- Matched the tested Dell Command Update result set without a runtime dependency on Dell Command Update.

## [0.1.0] - 2026-09-25

### Added in 0.1.0

- Initial `Get-DellUpdate` and `Install-DellUpdate` functions.
- Initial Dell global catalog download and WSUS applicability-rule evaluation.
- Initial native fallback for Dell inventory rules.

### Deprecated in 0.1.0

- The global catalog/rule-engine approach was replaced in version 0.2.0 because it was slower and produced false-positive historical packages when Dell-specific inventory identities could not be reconstructed exactly.
