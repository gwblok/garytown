
$RemediationRegPath = 'HKLM:\SOFTWARE\Remediations'

if (Test-Path -Path $RemediationRegPath){
    Remove-Item -Path $RemediationRegPath -Recurse -Force | Out-Null
    
}