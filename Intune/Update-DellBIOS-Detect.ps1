<#
Gary Blok | @gwblok | recastsoftware.com
Updates Bios on DELL machines by finding latest version avialble in Dell Command Update XML, Downloading and installing, then triggers a Restart
Remediation & Detection Scripts are the same, just change the variable $Remediate. ($false = Detect | $true = Remediate)

#>


$ScriptVersion = "21.4.7.1"
$whoami = $env:USERNAME
$IntuneFolder = "$env:ProgramData\Intune"
$LogFilePath = "$IntuneFolder\Logs"
$LogFile = "$LogFilePath\Dell-Updates.log"
$scriptName = "Dell BIOS Update - From Cloud"
$BIOS = Get-WmiObject -Class 'Win32_Bios'
$SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
$CabPath = "$env:temp\DellCabDownloads\DellSDPCatalogPC.cab"
$CabPathIndex = "$env:temp\DellCabDownloads\CatalogIndexPC.cab"
$CabPathIndexModel = "$env:temp\DellCabDownloads\CatalogIndexModel.cab"
$DellCabExtractPath = "$env:temp\DellCabDownloads\DellCabExtract"
$ProxyConnection = "proxy-recastsoftware.com"
$ProxyConnectionPort = "8080"
$Remediate = $true
if ($Remediate -eq $false)
    {$ComponentText = "Intune - Remediation"}
else {$ComponentText = "Intune - Detection"}

if (!(Test-Path -Path $LogFilePath)){$NewFolder = New-Item -Path $LogFilePath -ItemType Directory -Force}


function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = $ComponentText,
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
		    $LogFile = "$env:ProgramData\Intune\Logs\IForgotToNameTheLogVar.log"
	    )
    <#
    Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
	    $Time = Get-Date -Format "HH:mm:ss.ffffff"
	    $Date = Get-Date -Format "MM-dd-yyyy"
 
	    if ($ErrorMessage -ne $null) {$Type = 3}
	    if ($Component -eq $null) {$Component = " "}
	    if ($Type -eq $null) {$Type = 1}
 
	    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
	    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
    }

Function Restart-ByPassComputer {

#Add Logic for Bitlocker
#Add Toast Notification
#Add Shutdown in 2 hours

#Assuming if Process "Explorer" Exist, that a user is logged on.
$Session = Get-Process -Name "Explorer" -ErrorAction SilentlyContinue
CMTraceLog -Message  "User Session: $Session" -Type 1 -LogFile $LogFile
Suspend-BitLocker -MountPoint $env:SystemDrive
If ($Session -ne $null){
    CMTraceLog -Message  "User Session: $Session, Restarting in 90 minutes" -Type 1 -LogFile $LogFile
    Start-Process shutdown.exe -ArgumentList '/r /f /t 300 /c "Updating Bios, please save your work, Computer will reboot in 5 minutes"'
    #Start-Process shutdown.exe -ArgumentList '/r /f /t 5400 /c "Updating Bios, please save your work, Computer will reboot in 90 minutes"'

    }
else {
    CMTraceLog -Message  "No User Session Found, Restarting in 5 Seconds" -Type 1 -LogFile $LogFile
    Start-Process shutdown.exe -ArgumentList '/r /f /t 5 /c "Updating Bios, Computer will reboot in 5 seconds"'
    }

}  



CMTraceLog -Message  "---------------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Starting $ScriptName, $ScriptVersion | Remediation Mode $Remediate" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Running as $whoami" -Type 1 -LogFile $LogFile




# Test Proxy ############################
if ((Test-NetConnection $ProxyConnection -Port $ProxyConnectionPort).PingSucceeded -eq $true)
    {
    $UseProxy = $true
    $ProxyServer = "http://proxy-recastsoftware.com:8080"
    $BitsProxyList = @("10.1.1.5:8080, 10.2.2.5:8080, 10.3.3.5:8080")
    Write-Output "Found Proxy Server, using for Downloads"
    [system.net.webrequest]::DefaultWebProxy = new-object system.net.webproxy("$ProxyServer")
    }
Else 
    {
    $UseProxy = $False
    $ProxyServer = $null
    $BitsProxyList = $null
    Write-Output "No Proxy Server Found, continuing without"
    }


# Get Dell BIOS Info ##########################
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


# Pull down Dell XML CAB used in Dell Command Update ,extract and Load
if (!(Test-Path $DellCabExtractPath)){$newfolder = New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
Write-Host "Downloading Dell Cab" -ForegroundColor Yellow
Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/CatalogIndexPC.cab" -OutFile $CabPathIndex -UseBasicParsing -Verbose -Proxy $ProxyServer
[int32]$n=1
While(!(Test-Path $CabPathIndex) -and $n -lt '3')
    {
    Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/CatalogIndexPC.cab" -OutFile $CabPathIndex -UseBasicParsing -Verbose -Proxy $ProxyServer
    $n++
    }
If(Test-Path "$DellCabExtractPath\DellSDPCatalogPC.xml"){Remove-Item -Path "$DellCabExtractPath\DellSDPCatalogPC.xml" -Force}
Start-Sleep -Seconds 1
if (test-path $DellCabExtractPath){Remove-Item -Path $DellCabExtractPath -Force -Recurse}
$NewFolder = New-Item -Path $DellCabExtractPath -ItemType Directory
Write-Host "Expanding the Cab File..... takes FOREVER...." -ForegroundColor Yellow
$Expand = expand $CabPathIndex $DellCabExtractPath\CatalogIndexPC.xml

write-host "Loading Dell Catalog XML.... can take awhile" -ForegroundColor Yellow
[xml]$XMLIndex = Get-Content "$DellCabExtractPath\CatalogIndexPC.xml" -Verbose


#Dig Through Dell XML to find Model of THIS Computer (Based on System SKU)
$XMLModel = $XMLIndex.ManifestIndex.GroupManifest | Where-Object {$_.SupportedSystems.Brand.Model.systemID -match $SystemSKUNumber}
if ($XMLModel)
    {
    CMTraceLog -Message  "Downloaded Dell DCU XML, now looking for Model Updates" -Type 1 -LogFile $LogFile
    Invoke-WebRequest -Uri "http://downloads.dell.com/$($XMLModel.ManifestInformation.path)" -OutFile $CabPathIndexModel -UseBasicParsing -Verbose -Proxy $ProxyServer
    if (Test-Path $CabPathIndexModel)
        {
        $Expand = expand $CabPathIndexModel $DellCabExtractPath\CatalogIndexPCModel.xml
        [xml]$XMLIndexCAB = Get-Content "$DellCabExtractPath\CatalogIndexPCModel.xml" -Verbose
        $DCUBIOSAvailable = $XMLIndexCAB.Manifest.SoftwareComponent | Where-Object {$_.ComponentType.value -eq "BIOS"}
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
        $DCUBIOSN1Version = $DCUBIOSAvailableVersions | Sort-Object | Select-Object -Last 2 | Select-Object -First 1
        $DCUBIOSLatest = $DCUBIOSAvailable | Where-Object {$_.dellversion -eq $DCUBIOSLatestVersion}
        $DCUBIOSVersion = $DCUBIOSLatest.dellVersion
        $DCUBIOSReleaseDate = $(Get-Date $DCUBIOSLatest.releaseDate -Format 'yyyy-MM-dd')               
        $TargetLink = "http://downloads.dell.com/$($DCUBIOSLatest.path)"
        $TargetFileName = ($DCUBIOSLatest.path).Split("/") | Select-Object -Last 1

        if ($DCUBIOSVersion -gt $CurrentBIOSVersion)
            {
            
            if ($Remediate -eq $true)
                {
                CMTraceLog -Message  "New BIOS Update available: Installed = $CurrentBIOSVersion DCU = $DCUBIOSVersion" -Type 1 -LogFile $LogFile
                Write-Host " New BIOS Update available: Installed = $CurrentBIOSVersion DCU = $DCUBIOSVersion" -ForegroundColor Yellow 
                CMTraceLog -Message  "  Title: $($DCUBIOSLatest.Name.Display.'#cdata-section')" -Type 1 -LogFile $LogFile
                Write-Output "  Title: $($DCUBIOSLatest.Name.Display.'#cdata-section')"
                CMTraceLog -Message  "  ----------------------------" -Type 1 -LogFile $LogFile
                Write-Host "  ----------------------------" -ForegroundColor Cyan
                CMTraceLog -Message  "   Severity: $($DCUBIOSLatest.Criticality.Display.'#cdata-section')" -Type 1 -LogFile $LogFile
                Write-Output "   Severity: $($DCUBIOSLatest.Criticality.Display.'#cdata-section')"
                CMTraceLog -Message  "   FileName: $TargetFileName" -Type 1 -LogFile $LogFile
                Write-Output "   FileName: $TargetFileName"
                CMTraceLog -Message  "   BIOS Release Date: $DCUBIOSReleaseDate" -Type 1 -LogFile $LogFile
                Write-Output "   BIOS Release Date: $DCUBIOSReleaseDate"
                CMTraceLog -Message  "   KB: $($DCUBIOSLatest.releaseID)" -Type 1 -LogFile $LogFile
                Write-Output "   KB: $($DCUBIOSLatest.releaseID)"
                CMTraceLog -Message  "   Link: $TargetLink" -Type 1 -LogFile $LogFile
                Write-Output "   Link: $TargetLink"
                CMTraceLog -Message  "   Info: $($DCUBIOSLatest.ImportantInfo.URL)" -Type 1 -LogFile $LogFile
                Write-Output "   Info: $($DCUBIOSLatest.ImportantInfo.URL)"
                CMTraceLog -Message  "   BIOS Version: $DCUBIOSVersion " -Type 1 -LogFile $LogFile
                Write-Output "   BIOS Version: $DCUBIOSVersion "

                #Build Required Info to Download and Update CM Package
                $TargetFilePathName = "$($DellCabExtractPath)\$($TargetFileName)"
                CMTraceLog -Message  "   Running Command: Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Verbose -Proxy $ProxyServer " -Type 1 -LogFile $LogFile
                Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Verbose -Proxy $ProxyServer

                #Confirm Download
                if (Test-Path $TargetFilePathName)
                    {
                    CMTraceLog -Message  "   Download Complete " -Type 1 -LogFile $LogFile
                    if ((Get-BitLockerVolume -MountPoint $env:SystemDrive).ProtectionStatus -eq "On" )
                        {
                        CMTraceLog -Message  "Bitlocker Status: On - Suspending before Update" -Type 1 -LogFile $LogFile
                        Suspend-BitLocker -MountPoint $env:SystemDrive
                        if ((Get-BitLockerVolume -MountPoint $env:SystemDrive).ProtectionStatus -eq "On" )
                            {
                            CMTraceLog -Message  "Bitlocker Status Still On, unable to Suspend, exiting Script" -Type 1 -LogFile $LogFile
                            exit 1
                            }
                        else
                            {
                            CMTraceLog -Message  "Bitlocker Status: Off" -Type 1 -LogFile $LogFile
                            }
                        }
                    else
                        {
                        CMTraceLog -Message  "Bitlocker Status: Off" -Type 1 -LogFile $LogFile
                        }                  
                    $BiosLogFileName = $TargetFilePathName.replace(".exe",".log")
                    $BiosArguments = "/s /l=$BiosLogFileName"
                    Write-Output "Starting BIOS Update"
                    write-output "Log file = $BiosLogFileName"
                    CMTraceLog -Message  " Running Command: Start-Process $TargetFilePathName $BiosArguments -Wait -PassThru " -Type 1 -LogFile $LogFile
                    $Process = Start-Process "$TargetFilePathName" $BiosArguments -Wait -PassThru
                    CMTraceLog -Message  " Update Complete with Exitcode: $($Process.ExitCode)" -Type 1 -LogFile $LogFile
                    write-output "Update Complete with Exitcode: $($Process.ExitCode)"
                    
                    If($Process -ne $null -and $Process.ExitCode -eq '2')
                        {
                        Restart-ByPassComputer
                        }
                    }
                else
                    {
                    CMTraceLog -Message  " FAILED TO DOWNLOAD BIOS" -Type 3 -LogFile $LogFile
                    Write-Host " FAILED TO DOWNLOAD BIOS" -ForegroundColor Red
                    exit 1
                    }
                }
            else
                {
                #Needs Remediation
                CMTraceLog -Message  "New BIOS Update available: Installed = $CurrentBIOSVersion DCU = $DCUBIOSVersion | Remediation Required" -Type 1 -LogFile $LogFile
                Exit 1
                }
            
            }
        else
            {
            #Compliant
            Write-Host " BIOS in DCU XML same as BIOS in CM: $CurrentBIOSVersion" -ForegroundColor Yellow
            CMTraceLog -Message  " BIOS in DCU XML same as BIOS in CM: $CurrentBIOSVersion" -Type 1 -LogFile $LogFile
            exit 0
            }
        }
    else
        {
        #No Cab with XML was able to download
        Write-Host "No Model Cab Downloaded"
        CMTraceLog -Message  "No Model Cab Downloaded" -Type 2 -LogFile $LogFile
        }
    }
else
    {
    #No Match in the DCU XML for this Model (SKUNumber)
    Write-Host "No Match in XML for $SystemSKUNumber"
    CMTraceLog -Message  "No Match in XML for $SystemSKUNumber" -Type 2 -LogFile $LogFile
    }    
