<#
    Name: TSVarsSafeDump.ps1
    Version: 1.0
    Author: Johan Schrewelius, Onevinn AB
    Date: 2016-11-24
    Command: powershell.exe -executionpolicy bypass -file TSVarsSafeDump.ps1
    Usage:  Run in SCCM Task Sequence to Dump TS-Varibles to disk ("_SMSTSLogPath").
            Variables known to contain sensitive information will be excluded.
    Config: List of variables to exclude, edit as needed:
            $ExcludeVariables = @('_OSDOAF','_SMSTSReserved','_SMSTSTaskSequence')
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [String]$logPath = "C:\Windows\Temp"
)

# Config Start

$ExcludeVariables = @('_OSDOAF','_SMSTSReserved','_SMSTSTaskSequence')

# Config End

$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
#$logPath = $tsenv.Value("_SMSTSLogPath")
$now = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$logFile = "TSVariables-$now.log"
$logFileFullName = Join-Path -Path $logPath -ChildPath $logFile

function MatchArrayItem {
    param (
        [array]$Arr,
        [string]$Item
        )

    $result = ($null -ne ($Arr | ? { $Item -match $_ }))
    return $result
}

$tsenv.GetVariables() | % {
    if(!(MatchArrayItem -Arr $ExcludeVariables -Item $_)) {
        "$_ = $($tsenv.Value($_))" | Out-File -FilePath $logFileFullName -Append
    }
}
