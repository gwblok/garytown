#Gary Blok | GARYTOWN.COM
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

#Location to store the DISM Log
$LogPath = $Script:TaskSequenceEnvironment.Value("_SMSTSLogPath")
if (!($OSDisk)){
    $OSDisk = $Script:TaskSequenceEnvironment.Value("OSDisk")
}
#Source Path for the Driver Pack Contents, if not provided, defaulting to DRIVERS01 variable.
if (!($SourcePath)){
    $SourcePath = $Script:TaskSequenceEnvironment.Value("DRIVERS01")
}
if (Test-Path $SourcePath)
    {
    Write-Output "Confirmed SourcePath of Drivers downloaded to $SourcePath"
    Write-Output "OSDisk set to $OSDisk"

    $Output = "$LogPath\DISMDriversOutput.txt"

    #Start the DISM Process, but redirect the output from the console to a logfile which we can read to provide the info
    Write-Output 'Start-Process DISM.EXE -ArgumentList '"/image:$($OSDisk)\ /Add-Driver /driver:$SourcePath /recurse"' -PassThru -NoNewWindow -RedirectStandardOutput $Output'
    $DISM = Start-Process DISM.EXE -ArgumentList "/image:$($OSDisk)\ /Add-Driver /driver:$SourcePath /recurse" -PassThru -NoNewWindow -RedirectStandardOutput $Output
    $SameLastLine = $null
    do {  #Continous loop while DISM is running
        Start-Sleep -Milliseconds 300

        #Read in the DISM Logfile
        $Content = Get-Content -Path $Output -ReadCount 1
        $LastLine = $Content | Select-Object -Last 1
        if ($LastLine){
            if ($SameLastLine -ne $LastLine){ #Only continue if DISM log has changed
                $SameLastLine = $LastLine
                Write-Output $LastLine
                if ($LastLine -match "Searching for driver packages to install..."){
                    #Write-Output $LastLine
                    Show-TSActionProgress -Message $LastLine -Step 1 -MaxStep 100 -ErrorAction SilentlyContinue
                }
                elseif ($LastLine -match "Installing"){
                    #Write-Output $LastLine
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
                elseif ($LastLine -match "The operation completed successfully."){
                    Show-TSActionProgress -Message $LastLine -Step 1 -MaxStep 1 -ErrorAction SilentlyContinue
                }
                else{
                    Show-TSActionProgress -Message $LastLine -Step 1 -MaxStep 100 -ErrorAction SilentlyContinue
                }
            }
        }
        
    }
    until (!(Get-Process -Name DISM -ErrorAction SilentlyContinue))

    Write-Output "Dism Step Complete"
    Write-Output "See DISM log for more Details: $Output"

    }
else
    {
    Write-Output "Drivers Not Found, exiting out"
    }
Write-Output "--------------------------------------"
