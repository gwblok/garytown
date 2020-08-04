<#
GARY BLOK
This script will go through the task sequence variables and grab any that are related to the CM Check Readiness Step (2002 or higher).
It then populates anything that failed into an array that can be used for reporting in the Task Sequnece

#>
try{$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment}
catch{Write-Verbose "Not running in a task sequence."}
$CheckReadiness = (New-Object -COMObject Microsoft.SMS.TSEnvironment).GetVariables() | Where-Object {$_ -Like "_TS_CR*"}
$LogPath = $tsenv.Value('_SMSTSLogPath')
$LogFile = "$LogPath\SMSTS_CheckReadiness.log"
$registryPath = "HKLM:\$($tsenv.Value('RegistryPath'))\$($tsenv.Value('SMSTS_BUILD'))"
$CheckReadinessDatabase = @()
foreach ($Check in $CheckReadiness)
    {
    $Value = $tsenv.value($Check)
    $Friendly = ($Check.ToString()).replace("_TS_CR", "")
    $CheckReadinessDatabaseObject = New-Object PSObject -Property @{
        Variable     = $check
        Value        = $Value
        Friendly     = $Friendly
        }
    #Take the PS Object and append the Database Array    
    $CheckReadinessDatabase += $CheckReadinessDatabaseObject
    }

$CheckReadinessFails = $CheckReadinessDatabase | Where-Object {$_.Value -eq 0}
if ($CheckReadinessFails -ne $null)
    {
    Write-Host "Check Readiness Fails" -ForegroundColor Red
    Write-Output $CheckReadinessFails
    if ($CheckReadinessFails.Count -gt 1) 
        {
        $CRFailString = $CheckReadinessFails.Friendly -join ", "
        $tsenv.Value('ErrorMessage') = "Failed Check Readiness Tests: $CRFailString"
        }
    else 
        {
        $CRFailString = $CheckReadinessFails.Friendly
        $tsenv.Value('ErrorMessage') = "Failed Check Readiness Test: $CRFailString"
        }
    $tsenv.Value('CRFailString') = $CRFailString
    }

