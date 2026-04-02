<#
    Gary Blok & Mike Terrill
    Cert Status Monitor Script-Intune - Deploy as a remediation script, detect only
    Version: 26.04.01

https://support.microsoft.com/en-us/topic/registry-key-updates-for-secure-boot-windows-devices-with-it-managed-updates-a7be69c9-4634-42e1-9ca1-df06f43f360d
https://support.microsoft.com/en-us/topic/how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d

#>

#Individual Cert Results Confirmation - Applying the DB updates
$Win2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
if ($Win2023Present -eq $false){$Step1Compliance = $false}
$MSKEKPresent = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI kek).bytes) -match 'Microsoft Corporation KEK 2K CA 2023'
if ($MSKEKPresent -eq $false){$Step1Compliance = $false}
$MSCA2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Microsoft UEFI CA 2023'
if ($MSCA2023Present -eq $false){$Step1Compliance = $false}
$OptionROM2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Microsoft Option ROM UEFI CA 2023'
if ($OptionROM2023Present -eq $false){$Step1Compliance = $false}


$MSCA2011Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Microsoft Corporation UEFI CA 2011'
#$Win2011Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2011'


$MissingCerts = @()
if (-not $MSKEKPresent)        { $MissingCerts += "MSKEK" }
if (-not $MSCA2023Present)     { $MissingCerts += "MSCA2023" }
if (-not $OptionROM2023Present){ $MissingCerts += "OptionROM2023" }
if (-not $Win2023Present)      { $MissingCerts += "Win2023" }

if ($MissingCerts.Count -gt 0) {
    Write-Output "Missing Certs: $($MissingCerts -join ', ')"
}
else {
    Write-Output "All Certs Present"
}

if ($Step1Compliance -eq $false){
    exit 1
}