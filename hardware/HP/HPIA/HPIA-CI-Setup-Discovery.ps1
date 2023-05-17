<# CI Detection - Tests if Script is there and the Scheduled Task is there...
If not.. it reports non-compliance.

Remediation Script: https://github.com/gwblok/garytown/blob/master/hardware/HP/HPIA/HPIA-AutoUpdate-Setup.ps1



#>
$Compliance = "Compliant"
$ScriptStagingFolder = "$env:ProgramFiles\HP\HPIA"

[String]$TaskName = "HP Image Assistant Update Service"
if (!(Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)){
    $Compliance = "Non-Compliant"
}
  
if (!(Test-Path "$ScriptStagingFolder\HPIAUpdateService.ps1")){
    $Compliance = "Non-Compliant"
}

 Return $Compliance 
