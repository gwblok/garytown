#Req - Provide Source path to the driver files

param(
    [Parameter(Mandatory=$false)]
    [string]$SourcePath,
    [Parameter(Mandatory=$false)]
    [string]$OSDisk

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

Confirm-TSProgressUISetup
Confirm-TSEnvironmentSetup

Write-Output "--------------------------------------"
Write-Output "Starting DISM Driver Install"

$LogPath = $Script:TaskSequenceEnvironment.Value("_SMSTSLogPath")
if (!($OSDisk)){
    $OSDisk = $Script:TaskSequenceEnvironment.Value("OSDisk")
}
if (!($SourcePath)){
    $SourcePath = $Script:TaskSequenceEnvironment.Value("DRIVERS01")
}
if (Test-Path $SourcePath)
    {
    Write-Output "Confirmed SourcePath of Drivers downloaded to $SourcePath"
    Write-Output "OSDisk set to $OSDisk"

    $Output = "$LogPath\DISMDriversOutput.txt"

    Write-Output 'Start-Process DISM.EXE -ArgumentList '"/image:$($OSDisk)\ /Add-Driver /driver:$SourcePath /recurse"' -PassThru -NoNewWindow -RedirectStandardOutput $Output'
    $DISM = Start-Process DISM.EXE -ArgumentList "/image:$($OSDisk)\ /Add-Driver /driver:$SourcePath /recurse" -PassThru -NoNewWindow -RedirectStandardOutput $Output

    do {
        Start-Sleep -Milliseconds 500
        
        $Content = Get-Content -Path $Output -ReadCount 1
        $LastLine = $Content | Select-Object -Last 1
        if ($LastLine -match "Searching for driver packages to install..."){
            #Write-Output $LastLine
            Show-TSActionProgress -Message $LastLine -Step 1 -MaxStep 100 -ErrorAction SilentlyContinue
        }
        $Message = $Content | Where-Object {$_ -match "Installing"} | Select-Object -Last 1
        if ($Message){
            $ToRemove = $Message.Split(':') | Select-Object -Last 1
            $Message = $Message.Replace(":$($ToRemove)","")
            $Message = $Message.Replace($SourcePath,"")
            $Message = $Message.Replace("\offline","")
            $Total = (($Message.Split("-")[0]).Split("of") | Select-Object -Last 1).replace(" ","")
            $Counter = ((($Message.Split("-")[0]).Split("of") | Select-Object -First 1).replace(" ","")).replace("Installing","")
            #Write-Output $Message
            Show-TSActionProgress -Message $Message -Step $Counter -MaxStep $Total -ErrorAction SilentlyContinue
        }
        
    }
    until (!(Get-Process -Name DISM -ErrorAction SilentlyContinue))

    Write-Output "Dism Complete with Code: $($DISM.ExitCode)"
    Write-Output "See DISM log for more Details: $Output"

    }
else
    {
    Write-Output "Drivers Not Found, exiting out"
    }
Write-Output "--------------------------------------"
