<# 
    Gary Blok & Mike Terrill
    KB5025885 Detection Script
    Step 1 of 4
    Version: 25.05.10
#>

$Applicable = $false

#Test if Remediation is applicable
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$Build = $CurrentOSInfo.GetValue('CurrentBuild')
[int]$UBR = $CurrentOSInfo.GetValue('UBR')

#July 2024 UBRs
$JulyPatch = @('19045.4651','22621.3880','22631.3880','26100.1150','26120.1')
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

#Check to see if Steps 1 and 2 are compliant
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

#Check to see if Step 3 is compliant
$Step3dbx = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes) -match 'Microsoft Windows Production PCA 2011'
if ($Step3dbx -eq $true) {
    $Step3 = "Compliant"
}
elseif ($Step3dbx -eq $false) {
    $Step3 = "Non-compliant"
}

#Determine if Step 1 is applicable
if ($OSPatch -eq "Compliant" -and $SecureBoot -eq "Compliant" -and $Step1 -eq "Non-compliant"){
    $Applicable = $true
}

$Applicable