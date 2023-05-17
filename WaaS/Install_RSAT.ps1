<# @Gwblok - https://garytown.com/waas-1909-ts-download
This script will reinstall the RSAT files along with adding an extra progress bar keeping track of which item is being installed.

#>
param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath
)

function Confirm-TSProgressUISetup(){
    if ($Script:TaskSequenceProgressUi -eq $null){
        try{$Script:TaskSequenceProgressUi = New-Object -ComObject Microsoft.SMS.TSProgressUI}
        catch{throw "Unable to connect to the Task Sequence Progress UI! Please verify you are in a running Task Sequence Environment. Please note: TSProgressUI cannot be loaded during a prestart command.`n`nErrorDetails:`n$_"}
        }
    }

function Confirm-TSEnvironmentSetup(){
    if ($Script:TaskSequenceEnvironment -eq $null){
        try{$Script:TaskSequenceEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment}
        catch{throw "Unable to connect to the Task Sequence Environment! Please verify you are in a running Task Sequence Environment.`n`nErrorDetails:`n$_"}
        }
    }

function Show-TSActionProgress()
{

    param(
        [Parameter(Mandatory=$true)]
        [string] $Message,
        [Parameter(Mandatory=$true)]
        [long] $Step,
        [Parameter(Mandatory=$true)]
        [long] $MaxStep
    )

    Confirm-TSProgressUISetup
    Confirm-TSEnvironmentSetup

    $Script:TaskSequenceProgressUi.ShowActionProgress(`
        $Script:TaskSequenceEnvironment.Value("_SMSTSOrgName"),`
        $Script:TaskSequenceEnvironment.Value("_SMSTSPackageName"),`
        $Script:TaskSequenceEnvironment.Value("_SMSTSCustomProgressDialogMessage"),`
        $Script:TaskSequenceEnvironment.Value("_SMSTSCurrentActionName"),`
        [Convert]::ToUInt32($Script:TaskSequenceEnvironment.Value("_SMSTSNextInstructionPointer")),`
        [Convert]::ToUInt32($Script:TaskSequenceEnvironment.Value("_SMSTSInstructionTableSize")),`
        $Message,`
        $Step,`
        $MaxStep)
}

Write-Output "--------------------------------------"
Write-Output "Starting RSAT Install"

if (Test-Path $SourcePath)
    {
    Write-Output "Confirmed Feature on Demand Cabs downloaded to $SourcePath"
    $RSAT_FoD = Get-WindowsCapability -Online | Where-Object Name -like 'RSAT*'
    $Counter = 0
    Foreach ($RSAT_FoD_Item in $RSAT_FoD)
        {
        $Counter ++
        Write-Output "Adding $($RSAT_FoD_Item.name)"
        Write-Output "Running Command: Add-WindowsCapability -Online -Name $($RSAT_FoD_Item.name) -Source $SourcePath -LimitAccess"
        Show-TSActionProgress -Message "Installing $($RSAT_FoD_Item.name)" -Step $Counter -MaxStep $RSAT_FoD.Count -ErrorAction SilentlyContinue
        Add-WindowsCapability -Online -Name $RSAT_FoD_Item.name -Source "$SourcePath" -LimitAccess
        }

    }
else
    {
    Write-Output "Feature on Demand Cabs Not Found, exiting out, will have to install manually later"
    }
Write-Output "--------------------------------------"
