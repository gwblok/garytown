#Gary Blok | @gwblok | RecastSoftware.com
#Created for Run Script in CM, hense very little Write-Out and pretty streamlined.
#This same code can be slightly changed to Install Drivers, or other Dell Software
#This script leverages the Dell Command Update XML to determine available updates for the machine the script is running on

Function Restart-ByPassComputerCM {

#https://sccmf12twice.com/2019/05/sccm-reboot-decoded-how-to-make-a-pc-cancel-start-extend-or-change-mandatory-reboot-to-non-mandatory-on-the-fly/
$time = [DateTimeOffset]::Now.ToUnixTimeSeconds()
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootBy' -Value $time -PropertyType QWord -Force -ea SilentlyContinue;
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootValueInUTC' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'NotifyUI' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'HardReboot' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindowTime' -Value 0 -PropertyType QWord -Force -ea SilentlyContinue;
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindow' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'PreferredRebootWindowTypes' -Value @("4") -PropertyType MultiString -Force -ea SilentlyContinue;
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'GraceSeconds' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;


if (Get-BitLockerVolume)
    {
    if ((Get-BitLockerVolume).mountpoint -eq $env:SystemDrive)
        {
        if ((Get-BitLockerVolume -MountPoint $env:SystemDrive).ProtectionStatus -eq "On") 
            {
            $null = Suspend-BitLocker -MountPoint $env:SystemDrive -RebootCount 2
            }
        }
    }
start-process -FilePath C:\windows\ccm\CcmRestart.exe

}  

$Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
$ComputerModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model

if ($Manufacturer -match "Dell")
    {
    $BIOS = Get-WmiObject -Class 'Win32_Bios'
    $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    
    if ((Test-NetConnection proxy-recastsoftware.com -Port 8080 -WarningAction SilentlyContinue).PingSucceeded -eq $true)
        {
        $UseProxy = $true
        $ProxyServer = "http://proxy-recastsoftware.com:8080"
        $BitsProxyList = @("192.168.1.45:8080, 192.168.1.145:8080, 192.168.1.145:8080")
        [system.net.webrequest]::DefaultWebProxy = new-object system.net.webproxy('http://proxy-recastsoftware.com:8080')
        }
    Else 
        {
        $UseProxy = $False
        $ProxyServer = $null
        $BitsProxyList = $null
        }
    try {
        if ($BIOS.SMBIOSBIOSVersion -match "A") #Deal with Versions with A
            {
            [String]$CurrentBIOSVersion = $BIOS.SMBIOSBIOSVersion
            }
        else
            {
            [System.Version]$CurrentBIOSVersion = $BIOS.SMBIOSBIOSVersion
            }   
        }
    catch {$CurrentBIOSVersion = $null}
    $scriptName = $MyInvocation.MyCommand.Name
    $CabPath = "$env:temp\DellCabDownloads\DellSDPCatalogPC.cab"
    $CabPathIndex = "$env:temp\DellCabDownloads\CatalogIndexPC.cab"
    $CabPathIndexModel = "$env:temp\DellCabDownloads\CatalogIndexModel.cab"
    $DellCabExtractPath = "$env:temp\DellCabDownloads\DellCabExtract"

    if (!(Test-Path $DellCabExtractPath)){$newfolder = New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
    Set-Location -Path "C:"
    Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/CatalogIndexPC.cab" -OutFile $CabPathIndex -UseBasicParsing -Proxy $ProxyServer
    [int32]$n=1
    While(!(Test-Path $CabPathIndex) -and $n -lt '3')
        {
        Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/CatalogIndexPC.cab" -OutFile $CabPathIndex -UseBasicParsing -Proxy $ProxyServer
        $n++
        }
    If(Test-Path "$PSScriptRoot\DellSDPCatalogPC.xml"){Remove-Item -Path "$PSScriptRoot\DellSDPCatalogPC.xml" -Force}
    Start-Sleep -Seconds 1
    if (test-path $DellCabExtractPath){Remove-Item -Path $DellCabExtractPath -Force -Recurse}
    $Null = New-Item -Path $DellCabExtractPath -ItemType Directory
    $Expand = expand $CabPathIndex $DellCabExtractPath\CatalogIndexPC.xml
    [xml]$XMLIndex = Get-Content "$DellCabExtractPath\CatalogIndexPC.xml" -Verbose
    $XMLModel = $XMLIndex.ManifestIndex.GroupManifest | Where-Object {$_.SupportedSystems.Brand.Model.systemID -match $SystemSKUNumber}
    if ($XMLModel)
        {
        Invoke-WebRequest -Uri "http://downloads.dell.com/$($XMLModel.ManifestInformation.path)" -OutFile $CabPathIndexModel -UseBasicParsing -Proxy $ProxyServer
        if (Test-Path $CabPathIndexModel)
            {
            $Expand = expand $CabPathIndexModel $DellCabExtractPath\CatalogIndexPCModel.xml
            [xml]$XMLIndexCAB = Get-Content "$DellCabExtractPath\CatalogIndexPCModel.xml" -Verbose
            $DCUBIOSAvailable = $XMLIndexCAB.Manifest.SoftwareComponent | Where-Object {$_.ComponentType.value -eq "BIOS"}
            $DCUDRIVERSAvailable = $XMLIndexCAB.Manifest.SoftwareComponent | Where-Object {$_.ComponentType.value -eq "DRVR"}
            $DCUDRIVERSAudioAvailable = $DCUDRIVERSAvailable | Where-Object {$_.category.display.'#cdata-section' -eq "Audio"}
            $DCUDRIVERSAudioLatestVersion = $DCUDRIVERSAudioAvailable | Sort-Object | Select-Object -Last 1
            $DCUDRIVERSNetworkAvailable = $DCUDRIVERSAvailable | Where-Object {$_.category.display.'#cdata-section' -eq "Network"}
            $DCUDRIVERSChipsetAvailable = $DCUDRIVERSAvailable | Where-Object {$_.category.display.'#cdata-section' -eq "Chipset"}
            $DCUBIOSAvailableVersionsRAW = $DCUBIOSAvailable.dellversion
            if ($DCUBIOSAvailableVersionsRAW[0] -match "A")
                {
                [String[]]$DCUBIOSAvailableVersions = $DCUBIOSAvailableVersionsRAW
                $DCUBIOSLatestVersion = $DCUBIOSAvailableVersions | Sort-Object | Select-Object -Last 1
                $DCUBIOSLatest = $DCUBIOSAvailable | Where-Object {$_.dellversion -eq $DCUBIOSLatestVersion}
                [String]$DCUBIOSVersion = $DCUBIOSLatest.dellVersion
                }

            if ($DCUBIOSAvailableVersionsRAW[0] -ne $null -and $DCUBIOSAvailableVersionsRAW[0] -ne "" -and $DCUBIOSAvailableVersionsRAW[0] -notmatch "A")
                {
                [System.Version[]]$DCUBIOSAvailableVersions = $DCUBIOSAvailableVersionsRAW
                $DCUBIOSLatestVersion = $DCUBIOSAvailableVersions | Sort-Object | Select-Object -Last 1
                $DCUBIOSLatest = $DCUBIOSAvailable | Where-Object {$_.dellversion -eq $DCUBIOSLatestVersion}
                [System.Version]$DCUBIOSVersion = $DCUBIOSLatest.dellVersion
                }              
            $DCUBIOSLatestVersion = $DCUBIOSAvailableVersions | Sort-Object | Select-Object -Last 1
            $DCUBIOSLatest = $DCUBIOSAvailable | Where-Object {$_.dellversion -eq $DCUBIOSLatestVersion}
            $DCUBIOSVersion = $DCUBIOSLatest.dellVersion
            $DCUBIOSReleaseDate = $(Get-Date $DCUBIOSLatest.releaseDate -Format 'yyyy-MM-dd')               
            $TargetLink = "http://downloads.dell.com/$($DCUBIOSLatest.path)"
            $TargetFileName = ($DCUBIOSLatest.path).Split("/") | Select-Object -Last 1
            if ($DCUBIOSVersion -gt $CurrentBIOSVersion)
                {
                Write-Output "Update To $DCUBIOSVersion from $CurrentBIOSVersion for $ComputerModel"
                $TargetFilePathName = "$($DellCabExtractPath)\$($TargetFileName)"
                Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Proxy $ProxyServer
                #Confirm Download
                if (Test-Path $TargetFilePathName)
                    {
                    $BiosLogFileName = $TargetFilePathName.replace(".exe",".log")
                    $BiosArguments = "/s /l=$BiosLogFileName"
                    $Process = Start-Process "$TargetFilePathName" $BiosArguments -Wait -PassThru
                    write-output "| Exitcode: $($Process.ExitCode)"
                    If($Process -ne $null -and $Process.ExitCode -eq '2')
                        {
                        Write-Output " Requires Restart"
                        Restart-ByPassComputerCM
                        }
                    }
                else
                    {
                    Write-Output "| FAILED TO DOWNLOAD BIOS"
                    }
                }
            else
                {
                Write-Output "No Update, Current: $CurrentBIOSVersion for $ComputerModel"
                }
            }
        else
            {
            Write-Output "No Model Cab Downloaded for $ComputerModel"
            }
        }
    else
        {
        Write-Output "No Match in XML for $SystemSKUNumber for $ComputerModel"
       } 
    }
else
    {
    Write-Output "This is not a Dell Device | $Manufacturer $ComputerModel"
    }
