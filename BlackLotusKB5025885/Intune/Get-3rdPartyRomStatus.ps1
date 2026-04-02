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
    # Collect all matching settings as an array of @{ Name; Value } hashtables
    $biosMatches = [System.Collections.Generic.List[hashtable]]::new()
    $vendorLabel = $null

    # Known BIOS setting name patterns for the 3rd-party UEFI CA toggle across vendors
    $settingPatterns = @(
        '*Allow3rdParty*',          # Lenovo: Allow3rdPartyUEFICA
        '*3rdPartyUEFI*',           # Lenovo variant
        '*3rd*Party*UEFI*',         # HP / generic with spaces
        '*3rd*Party*Option*ROM*',   # HP variant
        '*Third*Party*UEFI*',       # Dell / generic
        '*ThirdParty*',             # Dell variant
        '*Allow*3rd*Party*',        # Generic allow pattern
        '*Microsoft*3rd*Party*',    # Microsoft Surface variant
        '*MS UEFI CA*',             # HP: "Enable MS UEFI CA key" / "Ready to disable MS UEFI CA Key"
        '*Enable*UEFI CA*'          # HP variant
    )

    # Helper: add unique matches from a collection to $biosMatches
    function Add-MatchedSettings {
        param(
            [object[]]$Settings,
            [string]$NameProperty,
            [string]$ValueProperty
        )
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($pattern in $settingPatterns) {
            foreach ($s in $Settings) {
                $sName  = $s.$NameProperty
                $sValue = $s.$ValueProperty
                if ($sName -like $pattern -and $seen.Add($sName)) {
                    $biosMatches.Add(@{ Name = $sName; Value = $sValue })
                }
            }
        }
    }

    switch -Wildcard ($manufacturer) {

        { $_ -like '*HP*' -or $_ -like '*Hewlett*' } {
            $vendorLabel = 'HP'
            Write-Verbose "Detected HP device - querying root\HP\InstrumentedBIOS"
            try {
                $settings = Get-CimInstance -Namespace 'root\HP\InstrumentedBIOS' -ClassName HP_BIOSEnumeration -ErrorAction Stop
                Add-MatchedSettings -Settings $settings -NameProperty 'Name' -ValueProperty 'CurrentValue'

                # HP may also expose it under HP_BIOSSetting (non-enumeration)
                if ($biosMatches.Count -eq 0) {
                    $allSettings = Get-CimInstance -Namespace 'root\HP\InstrumentedBIOS' -ClassName HP_BIOSSetting -ErrorAction SilentlyContinue
                    if ($allSettings) {
                        Add-MatchedSettings -Settings $allSettings -NameProperty 'Name' -ValueProperty 'CurrentValue'
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
                if ($enumSettings) {
                    Add-MatchedSettings -Settings $enumSettings -NameProperty 'AttributeName' -ValueProperty 'CurrentValue'
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
                $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($s in $settings) {
                    if (-not [string]::IsNullOrWhiteSpace($s.CurrentSetting)) {
                        $parts = $s.CurrentSetting -split ',', 2
                        $settName = $parts[0]
                        $settValue = if ($parts.Count -gt 1) { $parts[1] } else { '' }

                        foreach ($pattern in $settingPatterns) {
                            if ($settName -like $pattern -and $seen.Add($settName)) {
                                $biosMatches.Add(@{ Name = $settName; Value = $settValue })
                            }
                        }
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
                $surfaceSettings = Get-CimInstance -Namespace 'root\wmi' -ClassName SurfaceUefiManager -ErrorAction SilentlyContinue
                if ($surfaceSettings) {
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

    # ── Determine overall ThirdPartyUEFICAEnabled status ──
    # Enabled if any vendor BIOS setting says enabled/on, or certs are in Secure Boot DB
    $isEnabled = $null
    $enabledValues = @('Enable', 'Enabled', 'On', 'True', '1', 'Yes')
    if ($biosMatches.Count -gt 0) {
        $isEnabled = ($biosMatches | Where-Object { $_.Value -in $enabledValues }).Count -gt 0
    }
    elseif ($secureBootDBCheck) {
        $isEnabled = $cert2011Present -or $cert2023Present
    }

    $secureBootEnabled = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue

    # ── Output: one object per matched BIOS setting ──
    if ($biosMatches.Count -gt 0) {
        foreach ($bios in $biosMatches) {
            [PSCustomObject]@{
                Manufacturer            = $vendorLabel
                Model                   = $model
                BIOSSettingName         = $bios.Name
                BIOSSettingValue        = $bios.Value
                ThirdPartyUEFICAEnabled = $isEnabled
                SecureBootEnabled       = $secureBootEnabled
                MSCorpUEFICA2011InDB    = $cert2011Present
                MSUEFICA2023InDB        = $cert2023Present
            }
        }
    }
    else {
        # No vendor BIOS settings matched - still output Secure Boot DB info
        [PSCustomObject]@{
            Manufacturer            = $vendorLabel
            Model                   = $model
            BIOSSettingName         = 'N/A (no vendor WMI match)'
            BIOSSettingValue        = 'N/A'
            ThirdPartyUEFICAEnabled = $isEnabled
            SecureBootEnabled       = $secureBootEnabled
            MSCorpUEFICA2011InDB    = $cert2011Present
            MSUEFICA2023InDB        = $cert2023Present
        }
    }
}

# Run and display results
$results = Get-3rdPartyUEFICAStatus -Verbose
$results | Format-Table -AutoSize