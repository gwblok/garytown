$Compliance = "Compliant"
if (!(Get-Module -Name PowerShellGet)){Import-Module -Name PowerShellGet}
if((Get-Module -Name PowerShellGet).Version -ge "2.2.5"){
    if (Test-Path "C:\Program Files\WindowsPowerShell\Modules\PowerShellGet\1.0.0.1"){
        $Compliance = "Non-Compliant"
    }
}
else{
    $Compliance ="Non-Compliant"
}

if (!(Get-Module -Name PackageManagement)){Import-Module -Name PackageManagement}
if ((Get-Module -Name PackageManagement).Version -ge "1.4.7"){
    if (Test-Path "C:\Program Files\WindowsPowerShell\Modules\PackageManagement\1.0.0.1"){
        $Compliance = "Non-Compliant"
    }
}
else{
    $Compliance = "Non-Compliant"
}

Write-Output $Compliance
