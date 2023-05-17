<# GARY BLOK - @GWBLOK - Recast Software
#>
#region: CMTraceLog Function formats logging in CMTrace style
Function Write-CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "CloudOSD",
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$false)]
		    $LogFile = "$LogFolder\CloudOSD.log"
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

# Configuration ##################################################################

try {
$tsenv = new-object -comobject Microsoft.SMS.TSEnvironment
$SMSTSLogsPath = $tsenv.value('_SMSTSLogPath')
$LogFolder = $tsenv.value('LogFolder')
if (!($LogFolder)){$LogFolder = $SMSTSLogsPath}
    }
catch{
Write-Output "Not in TS"
if (!($LogFolder)){$LogFolder = $env:TEMP}
    }
if (!(Test-Path -path $LogFolder)){$Null = new-item -Path $LogFolder -ItemType Directory -Force}

$ScriptVer = "2022.02.22.1"
$Component = "Unattend"
$LogFile = "$LogFolder\CloudOSD.log"

Write-Output "Starting script to create unattend file & create TS Varaibles"
Write-CMTraceLog -Message "=====================================================" -Type 1
Write-CMTraceLog -Message "TS Variables & Unattend.XML creation: Script version $ScriptVer..." -Type 1
Write-CMTraceLog -Message "=====================================================" -Type 1
Write-CMTraceLog -Message "Running Script as $env:USERNAME" -Type 1 
Write-CMTraceLog -Message "Running MDT 2nd Phase - Resealing" -Type 1 



   
[XML]$xmldoc = @"
<?xml version="1.0"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend"><settings xmlns="urn:schemas-microsoft-com:unattend" pass="oobeSystem"><component name="Microsoft-Windows-Shell-Setup" language="neutral" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<OOBE>
				<NetworkLocation>Work</NetworkLocation>
				<ProtectYourPC>1</ProtectYourPC>
				<HideEULAPage>true</HideEULAPage>
			</OOBE>
		</component>
		<component name="Microsoft-Windows-International-Core" language="neutral" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<SystemLocale>en-US</SystemLocale>
		</component>
	</settings><settings xmlns="urn:schemas-microsoft-com:unattend" pass="specialize"><component name="Microsoft-Windows-Deployment" language="neutral" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<RunSynchronous>
				<RunSynchronousCommand><Order>1</Order>
					<Description>Remove TS Folder</Description>
					<Path>cmd.exe /c rd c:\_SMSTaskSequence /S /Q</Path>
				</RunSynchronousCommand>
				<RunSynchronousCommand><Order>2</Order>
					<Description>Remove MININT</Description>
					<Path>cmd.exe /c rd c:\MININT /S /Q</Path>
				</RunSynchronousCommand>
				<RunSynchronousCommand><Order>3</Order>
					<Description>Remove Drivers Folder</Description>
					<Path>cmd.exe /c rd c:\Drivers /S /Q</Path>
				</RunSynchronousCommand>
				<RunSynchronousCommand><Order>4</Order>
					<Description>Remove Drivers Folder</Description>
					<Path>>cmd /c reg add HKLM\SOFTWARE\RecastSoftwareIT /v OSDCloud /t REG_DWORD /d 1 /f</Path>
				</RunSynchronousCommand>
            </RunSynchronous>
		</component>
	</settings></unattend>
"@



$UnattendFolderPath = "C:\WINDOWS\panther\unattend"

Write-Output "Create unattend folder: $UnattendFolderPath"
Write-CMTraceLog -Message "Create unattend folder: $UnattendFolderPath" -Type 1
$null = New-Item -ItemType directory -Path $UnattendFolderPath -Force
$xmldoc.Save("$UnattendFolderPath\unattend.tmp")
$enc = New-Object System.Text.UTF8Encoding($false)

Write-Output "Creating $UnattendFolderPath\unattend.xml"
Write-CMTraceLog -Message "Creating $UnattendFolderPath\unattend.xml" -Type 1
$wrt = New-Object System.XML.XMLTextWriter("$UnattendFolderPath\unattend.xml",$enc)
$wrt.Formatting = 'Indented'
$xmldoc.Save($wrt)
$wrt.Close()

if (Test-Path -Path "$UnattendFolderPath\unattend.xml"){
    Write-CMTraceLog -Message "Successfully Created Unattend.XML File" -Type 1
    }
