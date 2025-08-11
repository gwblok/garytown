<#
#CI Name: "CVE-2023-24932 - KB5025885 - Black Lotus PreReq UBR"
#Detection Method on CI = "Always assume application is installed"
#>


#Discovery Script:
<# 
    Gary Blok & Mike Terrill
    KB5025885 Detection Script
    PreReq UBR
    Version: 25.05.10
#>

$Compliant = $false

#Test if Remediation is applicable
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$Build = $CurrentOSInfo.GetValue('CurrentBuild')
[int]$UBR = $CurrentOSInfo.GetValue('UBR')

#July 2025 UBRs
$JulyPatch = @('19045.6093','22621.5624','22631.5624','26100.4652','26200.4652')
$MatchedPatch = $JulyPatch | Where-Object {$_ -match $Build}
[int]$MatchedUBR = $MatchedPatch.split(".")[1]

if ($UBR -ge $MatchedUBR){
    $Compliant = $true
}
else {
    $Compliant = $false
}
$Compliant

<#
Compliance Rule
"The value returned by the specified script: Equals"
"the following values:  True"
#>