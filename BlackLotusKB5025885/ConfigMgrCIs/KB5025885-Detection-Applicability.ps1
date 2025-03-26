
#Test if Remediation is applicable
#Region Applicability
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$Build = $CurrentOSInfo.GetValue('CurrentBuild')
[int]$UBR = $CurrentOSInfo.GetValue('UBR')

#April 2024 UBRs
$AprilPatch = @('19044.4291','19045.4291','22631.3447','22621.3447','22000.2899', '26100.1150','26120.1')
$MatchedPatch = $AprilPatch | Where-Object {$_ -match $Build}
[int]$MatchedUBR = $MatchedPatch.split(".")[1]

$Applicable = $true

if ($UBR -ge $MatchedUBR){
}
else {
    #$OSSupported = $false
    #Write-Output "The OS ($Build.$UBR) is not supported for this remediation."
    $Applicable = $false
}
if (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
    #This is required for remediation to work
}
else {
    #Write-Output "Secure Boot is not enabled."
    #exit 5
    $Applicable = $false
}

if ($Applicable -eq $true){
    write-output "The OS ($Build.$UBR) is supported for this remediation."
}
#endregion Applicability

