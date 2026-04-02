<#
.SYNOPSIS
    Detects the status of the "Allow Microsoft 3rd Party UEFI CA" BIOS setting across vendors.
.DESCRIPTION
    Uses two approaches:
    1. Vendor-agnostic: Checks the Secure Boot DB for the Microsoft Corporation UEFI CA 2011
       certificate, which is what "Allow Microsoft 3rd Party UEFI CA" controls at the firmware level.
    2. Vendor-specific WMI: Queries HP, Dell, Lenovo, or Surface BIOS settings for the exact
       toggle, using the same WMI patterns from GatherInfo.ps1.
.NOTES
    Based on the multi-vendor BIOS query approach from MMS\2026-MOA\GatherInfo.ps1
    The "Microsoft Corporation UEFI CA 2011" cert in the Secure Boot Allowed Signature Database (db)
    is what authorises 3rd-party UEFI drivers / option ROMs.
    The 2023 version of this cert is "Microsoft UEFI CA 2023".
.OUTPUTS
    PSCustomObject with Manufacturer, BIOSSettingName, BIOSSettingValue, SecureBootDBCertPresent
#>

#Requires -RunAsAdministrator

function Get-3rdPartyUEFICAStatus {
    [CmdletBinding()]
    param()

    $manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    $model = (Get-CimInstance -ClassName Win32_ComputerSystem).Model

    # ── Vendor-Agnostic: Check Secure Boot DB for 3rd Party UEFI CA certs ──
    $secureBootDBCheck = $null
    $cert2011Present = $false
    $cert2023Present = $false

    try {
        if (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
            $dbBytes = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db -ErrorAction Stop).bytes)
            $cert2011Present = $dbBytes -match 'Microsoft Corporation UEFI CA 2011'
            $cert2023Present = $dbBytes -match 'Microsoft UEFI CA 2023'
            $secureBootDBCheck = $true
        }
        else {
            Write-Warning "Secure Boot is not enabled on this device."
            $secureBootDBCheck = $false
        }
    }
    catch {
        Write-Warning "Could not query Secure Boot DB: $($_.Exception.Message)"
        $secureBootDBCheck = $false
    }

    # ── Vendor-Specific: Query BIOS setting via WMI ──
    $biosSettingName  = $null
    $biosSettingValue = $null
    $vendorLabel      = $null

    # Known BIOS setting name patterns for the 3rd-party UEFI CA toggle across vendors
    $settingPatterns = @(
        '*Allow3rdParty*',          # Lenovo: Allow3rdPartyUEFICA
        '*3rdPartyUEFI*',           # Lenovo variant
        '*3rd*Party*UEFI*',         # HP / generic with spaces
        '*3rd*Party*Option*ROM*',   # HP variant
        '*Third*Party*UEFI*',       # Dell / generic
        '*ThirdParty*',             # Dell variant
        '*Allow*3rd*Party*',        # Generic allow pattern
        '*Microsoft*3rd*Party*'     # Microsoft Surface variant
    )

    switch -Wildcard ($manufacturer) {

        { $_ -like '*HP*' -or $_ -like '*Hewlett*' } {
            $vendorLabel = 'HP'
            Write-Verbose "Detected HP device - querying root\HP\InstrumentedBIOS"
            try {
                $settings = Get-CimInstance -Namespace 'root\HP\InstrumentedBIOS' -ClassName HP_BIOSEnumeration -ErrorAction Stop
                foreach ($pattern in $settingPatterns) {
                    $match = $settings | Where-Object { $_.Name -like $pattern }
                    if ($match) {
                        $biosSettingName  = $match.Name
                        $biosSettingValue = $match.CurrentValue
                        break
                    }
                }
                # HP may also expose it under HP_BIOSSetting (non-enumeration)
                if (-not $biosSettingName) {
                    $allSettings = Get-CimInstance -Namespace 'root\HP\InstrumentedBIOS' -ClassName HP_BIOSSetting -ErrorAction SilentlyContinue
                    foreach ($pattern in $settingPatterns) {
                        $match = $allSettings | Where-Object { $_.Name -like $pattern }
                        if ($match) {
                            $biosSettingName  = $match.Name
                            $biosSettingValue = $match.CurrentValue
                            break
                        }
                    }
                }
            }
            catch {
                Write-Warning "HP: Failed to query BIOS WMI: $($_.Exception.Message)"
            }
        }

        '*Dell*' {
            $vendorLabel = 'Dell'
            Write-Verbose "Detected Dell device - querying root\dcim\sysman\biosattributes"
            try {
                $enumSettings = Get-CimInstance -Namespace 'root\dcim\sysman\biosattributes' -ClassName EnumerationAttribute -ErrorAction SilentlyContinue
                foreach ($pattern in $settingPatterns) {
                    $match = $enumSettings | Where-Object { $_.AttributeName -like $pattern }
                    if ($match) {
                        $biosSettingName  = $match.AttributeName
                        $biosSettingValue = $match.CurrentValue
                        break
                    }
                }
            }
            catch {
                Write-Warning "Dell: Failed to query BIOS WMI: $($_.Exception.Message)"
            }
        }

        '*Lenovo*' {
            $vendorLabel = 'Lenovo'
            Write-Verbose "Detected Lenovo device - querying root\wmi Lenovo_BiosSetting"
            try {
                $settings = Get-CimInstance -Namespace 'root\wmi' -ClassName Lenovo_BiosSetting -ErrorAction Stop
                foreach ($s in $settings) {
                    if (-not [string]::IsNullOrWhiteSpace($s.CurrentSetting)) {
                        $parts = $s.CurrentSetting -split ',', 2
                        $settName = $parts[0]
                        $settValue = if ($parts.Count -gt 1) { $parts[1] } else { '' }

                        foreach ($pattern in $settingPatterns) {
                            if ($settName -like $pattern) {
                                $biosSettingName  = $settName
                                $biosSettingValue = $settValue
                                break
                            }
                        }
                        if ($biosSettingName) { break }
                    }
                }
            }
            catch {
                Write-Warning "Lenovo: Failed to query BIOS WMI: $($_.Exception.Message)"
            }
        }

        { $_ -like '*Microsoft*' } {
            # Surface devices use UEFI settings via Surface UEFI Manager or registry
            $vendorLabel = 'Microsoft (Surface)'
            Write-Verbose "Detected Microsoft/Surface device"
            try {
                # Surface devices may expose UEFI settings via the Surface UEFI namespace
                $surfaceSettings = Get-CimInstance -Namespace 'root\wmi' -ClassName SurfaceUefiManager -ErrorAction SilentlyContinue
                if ($surfaceSettings) {
                    # On Surface, the 3rd party UEFI CA toggle is typically tied to Secure Boot
                    # and exposed as a setting.
                    Write-Verbose "Surface UEFI Manager detected"
                }
            }
            catch {
                Write-Verbose "Surface UEFI WMI not available"
            }
        }

        default {
            $vendorLabel = $manufacturer
            Write-Warning "Unsupported manufacturer '$manufacturer'. Falling back to Secure Boot DB check only."
        }
    }

    # ── Determine overall status ──
    # The 3rd-party UEFI CA is "enabled" if either:
    #   - The vendor BIOS setting says enabled/on
    #   - The Microsoft Corporation UEFI CA 2011 (or 2023) cert is in the Secure Boot DB
    $isEnabled = $null
    if ($biosSettingValue) {
        $isEnabled = $biosSettingValue -in @('Enable', 'Enabled', 'On', 'True', '1')
    }
    elseif ($secureBootDBCheck) {
        $isEnabled = $cert2011Present -or $cert2023Present
    }

    # ── Output ──
    [PSCustomObject]@{
        Manufacturer              = $vendorLabel
        Model                     = $model
        BIOSSettingName           = if ($biosSettingName) { $biosSettingName } else { 'N/A (no vendor WMI match)' }
        BIOSSettingValue          = if ($biosSettingValue) { $biosSettingValue } else { 'N/A' }
        ThirdPartyUEFICAEnabled   = $isEnabled
        SecureBootEnabled         = (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue)
        MSCorpUEFICA2011InDB      = $cert2011Present
        MSUEFICA2023InDB          = $cert2023Present
    }
}

# Run and display results
$result = Get-3rdPartyUEFICAStatus -Verbose
$result | Format-List