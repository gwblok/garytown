
<#Version 2020.04.08 - @GWBLOK
adapted from a different script, so there are big chunks commented out, and yes, it's a bit "interesting", but it works with little effort
 
#>

function Confirm-TSProgressUISetup()
{
    if ($Script:TaskSequenceProgressUi -eq $null)
    {
        try
        {
            $Script:TaskSequenceProgressUi = New-Object -ComObject Microsoft.SMS.TSProgressUI
        }
        catch
        {
            throw "Unable to connect to the Task Sequence Progress UI! Please verify you are in a running Task Sequence Environment. Please note: TSProgressUI cannot be loaded during a prestart command.`n`nErrorDetails:`n$_"
        }
    }
}

function Confirm-TSEnvironmentSetup()
{

    if ($Script:TaskSequenceEnvironment -eq $null)
    {
        try
        {
            $Script:TaskSequenceEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment
        }
        catch
        {
            throw "Unable to connect to the Task Sequence Environment! Please verify you are in a running Task Sequence Environment.`n`nErrorDetails:`n$_"
        }
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

$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
#$DellModelsTable = "Latitude E7470"
$DellModelsTable = (Get-CimInstance -ClassName Win32_ComputerSystem).model

$scriptName = $MyInvocation.MyCommand.Name
$env:TEMP
$CabPath = "$env:TEMP\DriverCatalog.cab"
$DellCabExtractPath = "$env:TEMP\DellCabExtract"


$DriverURL = "https://downloads.dell.com/catalog/DriverPackCatalog.cab"
if (!(test-path -path $CabPath)-or $SkipDownload) 
    {
    Write-Host "Downloading Dell Cab" -ForegroundColor Yellow
    Invoke-WebRequest -Uri $DriverURL -OutFile $CabPath -UseBasicParsing -Verbose -Proxy $ProxyServer
    [int32]$n=1
    While(!(Test-Path $CabPath) -and $n -lt '3')
        {
        Invoke-WebRequest -Uri $DriverURL -OutFile $CabPath -UseBasicParsing -Verbose -Proxy $ProxyServer
        $n++
        }
    If(Test-Path "$env:TEMP\DellSDPCatalogPC.xml"){Remove-Item -Path "$env:TEMP\DellSDPCatalogPC.xml" -Force -Verbose}
    Start-Sleep -Seconds 1
    if (test-path $DellCabExtractPath){Remove-Item -Path $DellCabExtractPath -Force -Recurse}
    New-Item -Path $DellCabExtractPath -ItemType Directory
    Write-Host "Expanding the Cab File...." -ForegroundColor Yellow
    $Expand = expand $CabPath "$DellCabExtractPath\DriverPackCatalog.xml"
    }


write-host "Loading Dell Catalog XML.... can take awhile" -ForegroundColor Yellow
[xml]$XML = Get-Content "$DellCabExtractPath\DriverPackCatalog.xml" -Verbose
$DriverPacks = $Xml.DriverPackManifest.DriverPackage | Where-Object -FilterScript {$_.SupportedOperatingSystems.OperatingSystem.osCode -match "Windows10"}
#$DriverPacks.SupportedSystems.Brand.Model.Name | Sort-Object
$DriverPacksModelSupport = $DriverPacks.SupportedSystems.Brand.Model.Name | Sort-Object
#$DriverPath = "$env:ProgramData\DriverCache"
#$ExpandPath = "$($DriverPath)\Expanded"
$DriverPath = $tsenv.value('DriverPath')
$ExpandPath = $tsenv.value('DriverExpandPath')


foreach ($Model in $DellModelsTable)#{}
    {
    Write-Host "----------------------------" -ForegroundColor DarkGray
    Write-Host "Starting to Process Model: $Model" -ForegroundColor Green
    Show-TSActionProgress -Message "Processing Model $Model" -Step 1 -MaxStep 10
    #Get Info about Driver Package from XML
    $ModelDriverPackInfo = $DriverPacks | Where-Object -FilterScript {$_.SupportedSystems.Brand.Model.Name -eq $Model}
    $TargetVersion = "$($ModelDriverPackInfo.dellVersion)"
    Write-Output "$TargetVersion"
    $TargetLink = "https://downloads.dell.com/$($ModelDriverPackInfo.path)"
    Write-Output "$TargetLink"
    #$TargetFileName = $ModelDriverPackInfo.name.Display."#cdata-section"
    #$TargetFileName = $TargetFileName.Trim()
    $TargetFileName = $ModelDriverPackInfo.path.Split("/") | Where-Object {$_ -match ".CAB"}
    Write-Output "$TargetFileName"
    #$ReleaseDate = Get-Date $ModelDriverPackInfo.dateTime -Format 'yyyy-MM-dd'
    #$TargetInfo = $ModelDriverPackInfo.ImportantInfo.URL
    if (($ModelDriverPackInfo.SupportedSystems.Brand.Model.systemID).count -gt 1){$DellSystemID = ($ModelDriverPackInfo.SupportedSystems.Brand.Model.systemID)[0]}
    else{$DellSystemID = ($ModelDriverPackInfo.SupportedSystems.Brand.Model.systemID)}
   
    $TargetFilePathName = "$($DriverPath)\$($TargetFileName)"
    #Check for Previous Download and see if Current
    if ((Test-Path $TargetFilePathName) -and (Test-Path "$DriverPath\Expanded"))
        {
        Write-Output "Aleady Contains Latest Driver Expanded Folder"
        }
    Else #Start Download Process
        {
        Write-Output "Starting Download Process"
        if (!(test-path "$DriverPath")){New-Item -Path $DriverPath -ItemType Directory | Out-Null}
 
            Remove-Item -path $DriverPath -Recurse -Force
            New-Item -Path $DriverPath -ItemType Directory | Out-Null
            if (test-path "$ExpandPath"){Remove-Item -Path $ExpandPath -Force -Recurse}
            New-Item -Path $ExpandPath -ItemType Directory | Out-Null
            Show-TSActionProgress -Message "Downloading $Model Drivers" -Step 3 -MaxStep 10
            Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing

            Write-Output "Starting Expand Process"
            Show-TSActionProgress -Message "Expanding Drivers for $Model" -Step 6 -MaxStep 10
            $Expand = expand $TargetFilePathName -F:* $ExpandPath
            Write-Output "Completed Expand Process"
            Show-TSActionProgress -Message "Complete with $Model Drivers" -Step 10 -MaxStep 10

        }
    }
   
   #Double Check & Set TS Var
if ((Test-Path $TargetFilePathName) -and (Test-Path "$DriverPath\Expanded"))
    {
    Write-Output "Confirmed Download and setting TSVar DRIVERS01"
    Show-TSActionProgress -Message "Complete with $Model Drivers" -Step 10 -MaxStep 10
    $tsenv.value('DRIVERS01') = $ExpandPath
    }

Write-Output "___________________________________________________"
