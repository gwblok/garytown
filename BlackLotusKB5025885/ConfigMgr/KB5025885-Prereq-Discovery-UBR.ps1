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
$MatchedPatch = $JulyPatch | Where-Object {$_.Split(".")[0] -eq $Build} | Select-Object -First 1
#Builds 26300 (26H2) and newer are approved without a UBR check
if ($null -ne $MatchedPatch) {[int]$MatchedUBR = $MatchedPatch.Split(".")[1]}
elseif ([int]$Build -ge 26300) {[int]$MatchedUBR = 0}
else {[int]$MatchedUBR = [int]::MaxValue}

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