#@gwblok - 2020.04.14
Import-Module "HPCMSL" -Force
#Connect to TS and pull in the Build we're upgrading to
Write-Output "___________________________________________________"
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
if ($tsenv.value('SMSTS_BUILD') -ne $null -and $tsenv.value('SMSTS_BUILD') -ne "")
    {$MaxBuild = $tsenv.value('SMSTS_BUILD')}
else {$MaxBuild = ((Get-HPDeviceDetails  -oslist | Where-Object {$_.OperatingSystem -eq "Microsoft Windows 10"}).OperatingSystemRelease | measure -Maximum).Maximum}

#Find the Driver Softpaq from HP
$DriverInfo = Get-SoftpaqList -Category Driverpack -OsVer $MaxBuild -ErrorAction SilentlyContinue
if (!($DriverInfo))
    {
    Write-Output "No Driver Pack for $MaxBuild, going to grab the latest version available"
    $MaxBuild = ((Get-HPDeviceDetails  -oslist | Where-Object {$_.OperatingSystem -eq "Microsoft Windows 10"}).OperatingSystemRelease | measure -Maximum).Maximum
    $DriverInfo = Get-SoftpaqList -Category Driverpack -OsVer $MaxBuild
    }
$DriverInfo = $DriverInfo | Where-Object {$_.Name -notmatch "Windows PE"}

#Create Driver Path Cache Location
$DriverPath = "$env:ProgramData\DriverCache"
$ExpandPath = "$($DriverPath)\Expanded"
$SaveAs = "$($DriverPath)\$($DriverInfo.Id).exe"


#Check for Previous Download and see if Current
if ((Test-Path "$DriverPath\$($DriverInfo.Id).exe") -and (Test-Path "$DriverPath\Expanded"))
    {
    Write-Output "Aleady Contains Latest Driver Expanded Folder"
    }
Else #Start Download Process
    {
    if (!(test-path "$DriverPath")){New-Item -Path $DriverPath -ItemType Directory | Out-Null}
    else {
        Remove-Item -path $DriverPath -Recurse -Force
        New-Item -Path $DriverPath -ItemType Directory | Out-Null
        }
    
    #Downoad
    Write-Output "Downloading $($DriverInfo.Name) & Extracting"
    Get-Softpaq -Number $DriverInfo.Id -SaveAs $SaveAs -Extract -DestinationPath $ExpandPath
    Write-Output "Finished Downloading $($DriverInfo.Name)"
    Write-Output $DriverInfo
    
    }

#Double Check & Set TS Var
if ((Test-Path "$DriverPath\$($DriverInfo.Id).exe") -and (Test-Path "$DriverPath\Expanded"))
    {
    Write-Output "Confirmed Download and setting TSVar DRIVERS01"
    $tsenv.value('DRIVERS01') = $ExpandPath
    }

Write-Output "___________________________________________________"
