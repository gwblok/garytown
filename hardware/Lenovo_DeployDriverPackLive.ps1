
<#Version 2020.12.04
Sources : @GWBLOK and @Modaly_IT & @MadhuSunke

2020.11.12 - Version from @MadhuSunke
2020.12.04 - @GWBLOK
 - Added TSProgressUI for monitoring in TS
 - Added TS Integration
#>

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
function Show-TSActionProgress(){

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

$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
$Model = ((Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Model).SubString(0, 4)).Trim() 
#test
#$Model = '10MQ'

$systemFamily = (Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty SystemFamily).trim()

$DriverURL = "https://download.lenovo.com/cdrt/td/catalogv2.xml"
Test-NetConnection -
Write-Host "Loading Lenovo Catalog XML...." -ForegroundColor Yellow
Show-TSActionProgress -Message "Loading Lenovo Catalog XML...." -Step 1 -MaxStep 10

if (($DriverURL.StartsWith("https://")) -OR ($DriverURL.StartsWith("http://"))) {
    try { $testOnlineConfig = Invoke-WebRequest -Uri $DriverURL -UseBasicParsing } catch { <# nothing to see here. Used to make webrequest silent #> }
    if ($testOnlineConfig.StatusDescription -eq "OK") {
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.Encoding = [System.Text.Encoding]::UTF8
            $Xml = [xml]$webClient.DownloadString($DriverURL)
            Write-host "Successfully loaded $DriverURL"
            Show-TSActionProgress -Message "Successfully loaded $DriverURL" -Step 2 -MaxStep 10
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            Write-Host "Error, could not read $DriverURL" 
            Write-Host "Error message: $ErrorMessage"
            Exit 1
        }
    }
    else {
        Write-Host "The provided URL to the config does not reply or does not come back OK"
        Exit 1
    }
}

#$DriverPath = "$env:ProgramData\DriverCache"
#$ExpandPath = "$($DriverPath)\Expanded"
$DriverPath = $tsenv.value('DriverPath')
$ExpandPath = $tsenv.value('DriverExpandPath')

    Write-Host "----------------------------" -ForegroundColor DarkGray
    Write-Host "Starting to Process Model: $systemFamily - $Model" -ForegroundColor Green
    
    #Get Info about Driver Package from XML
    $ModelDriverPackInfo = $Xml.ModelList.Model | Where-Object -FilterScript {$_.Types.Type -match $Model} 
    if($ModelDriverPackInfo.SCCM.Version -eq '*')
    {
    Write-Host "SCCM Version starts with *"
    $Downloadurl = $ModelDriverPackInfo.SCCM  | Where-Object -FilterScript {($_.'#text' -match 'w1064')} |select  -ExpandProperty '#text'
    }
    else{
    $Win10version = ($ModelDriverPackInfo.SCCM.Version | measure -Maximum).Maximum
    Write-Host "SCCM Version starts with ReleaseID $Win10version"
    $Downloadurl = $ModelDriverPackInfo.SCCM  | Where-Object -FilterScript {($_.Version -eq $Win10version)} |select  -ExpandProperty '#text'
    }
    Write-Output "$Downloadurl"

    $TargetFileName = $Downloadurl.Split("/") | Where-Object {$_ -match ".exe"}
    Write-Output "$TargetFileName"

    $TargetFilePathName = "$($DriverPath)\$($TargetFileName)"
    #Check for Previous Download and see if Current
    if ((Test-Path $TargetFilePathName) -and (Test-Path "$DriverPath\Expanded"))
        {
        Write-Output "Aleady Contains Latest Driver Expanded Folder"
        Write-Host "----------------------------" -ForegroundColor DarkGray
        }
    Else #Start Download Process
        {
        Write-Output "Starting Download Process"
        Show-TSActionProgress -Message "Downloading $TargetFileName | Takes awhile!" -Step 3 -MaxStep 10
        if (-NOT(test-path "$DriverPath")){New-Item -Path $DriverPath -ItemType Directory | Out-Null}
            Remove-Item -path $DriverPath -Recurse -Force
            New-Item -Path $DriverPath -ItemType Directory | Out-Null
            if (test-path "$ExpandPath"){Remove-Item -Path $ExpandPath -Force -Recurse}
            #New-Item -Path $ExpandPath -ItemType Directory | Out-Null
            Invoke-WebRequest -Uri $Downloadurl -OutFile $TargetFilePathName -UseBasicParsing
            Write-Output "Starting Expand Process"
            Show-TSActionProgress -Message "Starting Expand Process" -Step 4 -MaxStep 10
				# Driver Silent Extract Switches
				$LenovoSilentSwitches = "/VERYSILENT /DIR=" + '"' + $ExpandPath + '"'
				Start-Process -FilePath $TargetFilePathName -ArgumentList $LenovoSilentSwitches -Verb RunAs
				# Wait for Lenovo Driver Process To Finish
                $Step = 1
				While ((Get-Process) | where {$_.Name -eq $TargetFileName.Split(".")[0]}) {
					#Write-Host "Waiting for extract process (Process: $TargetFileName) to complete..  Next check in 10 seconds"
                    $step += 1
                    Show-TSActionProgress -Message "Extracting $TargetFilePathName" -Step $step -MaxStep 20
					Start-Sleep -seconds 10
				}
            Write-Host "Completed Expand Process" -ForegroundColor Green
            Show-TSActionProgress -Message "Completed Expand Process" -Step 1 -MaxStep 1
            Write-Host "----------------------------" -ForegroundColor DarkGray
        }
    

   #Double Check & Set TS Var
if ((Test-Path $TargetFilePathName) -and (Test-Path "$ExpandPath"))
    {
    Write-Output "Confirmed Download and setting TSVar DRIVERS01"
    $tsenv.value('DRIVERS01') = $ExpandPath
    }

Write-Output "___________________________________________________"
