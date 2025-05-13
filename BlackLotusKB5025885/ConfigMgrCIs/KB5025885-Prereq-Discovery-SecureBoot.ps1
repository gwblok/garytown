<#
#CI Name: "CVE-2023-24932 - KB5025885 - Black Lotus PreReq Secure Boot"
#Detection Method on CI = "Always assume application is installed"
#>


#Discovery Script:
<# 
    Gary Blok & Mike Terrill
    KB5025885 Detection Script
    PreReq Secure Boot
    Version: 25.05.10
#>

$Compliant = $false

if (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
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