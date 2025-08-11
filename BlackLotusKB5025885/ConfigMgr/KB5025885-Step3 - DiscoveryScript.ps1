#For Remediation, change $Remediate to $true

<#
CI Name: Black Lotus Step 3
#>

<# 
    Gary Blok & Mike Terrill
    KB5025885 Discovery and Remediation Script
    Step 3 of 4
    Version: 25.05.10
#>

$Remediate = $false
$Compliant = $true

#Test if Remediation is applicable
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$Build = $CurrentOSInfo.GetValue('CurrentBuild')
[int]$UBR = $CurrentOSInfo.GetValue('UBR')

#July 2025 UBRs
$JulyPatch = @('19045.6093','22621.5624','22631.5624','26100.4652','26200.4652')
$MatchedPatch = $JulyPatch | Where-Object {$_ -match $Build}
[int]$MatchedUBR = $MatchedPatch.split(".")[1]

if ($UBR -ge $MatchedUBR){
    $OSPatch = "Compliant"
}
else {
    #$OSSupported = $false
    #Write-Output "The OS ($Build.$UBR) is not supported for this remediation."
    $OSPatch = "Non-compliant"
}
if (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
    #This is required for remediation to work
    $SecureBoot = "Compliant"
}
else {
    #Write-Output "Secure Boot is not enabled."
    #exit 5
    $SecureBoot = "Non-compliant"
}

#Check to see if Steps 1 and 2 have been completed
try {
    $SecureBootServicing = Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing' -ErrorAction Stop
    $WindowsUEFICA2023Capable = $SecureBootServicing.GetValue('WindowsUEFICA2023Capable')
    if ($null -eq $WindowsUEFICA2023Capable) {
        $Step1 = "Non-compliant"
    }
}
catch {
    $Step1 = "Non-compliant"
}

if ($WindowsUEFICA2023Capable -eq 0) {
    $Step1 = "Non-compliant"
}
elseif ($WindowsUEFICA2023Capable -eq 1) {
    $Step1 = "Compliant"
    $Step2 = "Non-compliant"
}
elseif ($WindowsUEFICA2023Capable -eq 2) {
    $Step1 = "Compliant"
    $Step2 = "Compliant"
}

#Check to see if Step 3 has been completed
$Step3dbx = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes) -match 'Microsoft Windows Production PCA 2011'
if ($Step3dbx -eq $true) {
    $Step3 = "Compliant"
}
elseif ($Step3dbx -eq $false) {
    $Step3 = "Non-compliant"
}

if ($Step1 -eq "Compliant" -and $Step2 -eq "Compliant" -and $Step3 -eq "Non-compliant" -and $OSPatch -eq "Compliant" -and $SecureBoot -eq "Compliant") {
    $Compliant = $false
    if ($Remediate) {
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot' -Name 'AvailableUpdates' -Type DWord -Value 0x80 -Force | Out-Null
        Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
    }
    else {$Compliant}
}

<#
Compliance Rule
"The value returned by the specified script: Equals"
"the following values:  True"
#>
