
#Test if Remediation is applicable
#Region Applicability
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$Build = $CurrentOSInfo.GetValue('CurrentBuild')
[int]$UBR = $CurrentOSInfo.GetValue('UBR')

#July 2024 UBRs
$JulyPatch = @('19045.4651','22621.3880','22631.3880','26100.1150','26120.1')
$MatchedPatch = $JulyPatch | Where-Object {$_ -match $Build}
[int]$MatchedUBR = $MatchedPatch.split(".")[1]

$Applicable = $true

if ($UBR -ge $MatchedUBR){
    
}
else {
    #$OSSupported = $false
    $Applicable = $false
}

return $Applicable

