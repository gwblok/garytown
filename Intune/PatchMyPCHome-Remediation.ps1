<#
.SYNOPSIS
    Remediation Script
    Installs Patch My PC Home app... and configures
.DESCRIPTION
    Checks for Patch My PC Home app in C:\ProgramFiles\PMPC and 'Installs' if not there.
    Adds Scheduled task to run daily
    Configures the App to install specific applications I like in my lab but creating the PMPC ini file.
    
    Modify the ConfigFileContents to adjust for what you want.  
    Config will update anything already installed &...
    It will automatically install the apps you "uncomment" if they are not already installed
    
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Script Created by @gwblok
    Home Updater by Patch My PC | Justin Chalfant | @SetupConfigMgr
.LINK
    https://garytown.com
    https://patchmypc.com/home-updater
.COMPONENT
    --
.FUNCTIONALITY
    --
#>

$ScriptVersion = "22.12.30.1"
$ScriptName = "Install Patch My PC Home"
$whoami = $env:USERNAME
$IntuneFolder = "$env:ProgramData\Intune"
$LogFilePath = "$IntuneFolder\Logs"
$LogFile = "$LogFilePath\PatchMyPCHome.log"
$URL = "https://patchmypc.com/freeupdater/PatchMyPC.exe"
$ProgramFolder = "$env:ProgramFiles\PMPC"
$EXE =  "$env:ProgramFiles\PMPC\PatchMyPC.exe"
$TaskName = "PatchMyPC"
if (!(Test-Path -Path $LogFilePath)){$NewFolder = New-Item -Path $LogFilePath -ItemType Directory -Force}

$ConfigFile = "$ProgramFolder\PatchMyPC.ini"
$ConfigFileContent = @("

; Options

;Chk_Options_AppendComputerNameToLog
Chk_Options_AutoCloseAppsBeforeUpdate
Chk_Options_AutoStartUpdateOnOpen
;Chk_Options_CreateDesktopShortcuts
;Chk_Options_CreateRestorePoint
;Chk_Options_DisableAutoUpdatingAllApps
;Chk_Options_DisableLogFile
;Chk_Options_DisablePatchMyPCSelfUpdater
;Chk_Options_DisableSilentInstallOfApps
Chk_Options_DontDeleteAppInstallers
;Chk_Options_DownloadOnlyMode
;Chk_Options_EnablePatchMyPCBetas
;Chk_Options_EnableVerboseLogging
;Chk_Options_Install32BitWhenAvailable
;Chk_Options_MinimizeToTrayWhenClosed
;Chk_Options_MinimizeToTrayWhenMinimized
;Chk_Options_MinimizeWhenPerformingUpdates
;Chk_Options_RestartAfterUpdateProcess
;Chk_Options_ShutdownAfterUpdateProcess

; Plugins and Runtimes

;Chk_ADBLockIE
;Chk_AdobeAir
;Chk_AdobeFlashActiveX
;Chk_AdobeFlashPlugin
;Chk_AdobeShockwave
;Chk_Java8x64
;Chk_Java8x86
;Chk_Java9x64
;Chk_NETFramework
;Chk_Silverlight

; Browsers

;Chk_Brave
;Chk_GoogleChrome
;Chk_Maxthon
;Chk_MozillaFirefox
;Chk_MozillaFirefoxESR
;Chk_Opera
;Chk_PaleMoon
;Chk_Vivaldi
;Chk_Waterfox

;Multimedia

;Chk_AIMP
;Chk_AmazonMusic
;Chk_AppleiTunes
;Chk_Audacity
;Chk_Foobar2000
;Chk_GOMPlayer
;Chk_jetAudioBasic
;Chk_Klite
;Chk_MediaInfo
;Chk_MediaMonkey
;Chk_MP3Tag
;Chk_MPC
;Chk_MPCBE
;Chk_MusicBee
;Chk_PotPlayer
;Chk_RealPlayer
;Chk_SMPlayer
;Chk_StereoscopicPlayer
Chk_VLCPlayer
;Chk_WinAMP

; File Archivers

;Chk_7Zip
;Chk_Bandizip
;Chk_PeaZip
;Chk_Winrar
;Chk_WinZIP

; Utilities

;Chk_8GadgetPack
;Chk_AdvancedIPScanner
;Chk_AdvancedSystemCare
;Chk_AdvancedUninstallerPRO
;Chk_AngryIPScanner
;Chk_AuslogicsDiskDefrag
;Chk_autohotkey
;Chk_AutoRunOrganizer
;Chk_BleachBit
;Chk_BOINC
;Chk_CamStudio
;Chk_CCleaner
;Chk_ClassicShell
;Chk_CopyHandler
;Chk_DoNotSpy10
;Chk_Eraser
;Chk_Everything
;Chk_Fiddler
;Chk_GlaryUtilities
Chk_Greenshot
;Chk_HashTab
;Chk_HostsMan
;Chk_HotspotShield
;Chk_IObitUninstaller
;Chk_IoloSystemMechanic
;Chk_LogitechSetPoint
;Chk_MultiCommander
;Chk_Nmap
;Chk_NVDAScreenReader
;Chk_OpenVPN
;Chk_PicPick
;Chk_PrivacyEraser
;Chk_PrivaZer
;Chk_ProcessHacker
;Chk_ProcessLasso
;Chk_ProtonVPN
;Chk_PureSync
;Chk_RDCMan
;Chk_RegistryLife
;Chk_RegOrganizer
;Chk_Revo
;Chk_SABnzbd
;Chk_SFXMaker
;Chk_ShareX
;Chk_SimpleSystemTweaker
;Chk_SmartDefrag
;Chk_SoftOrganizer
;Chk_StartupDelayer
;Chk_SubtitleEdit
;Chk_SUMo
;Chk_SyncBackFree
;Chk_TeraCopy
Chk_TreeSizeFree
;Chk_UltraDefrag
;Chk_UltraSearch
;Chk_Unchecky
;Chk_Unlocker
;Chk_WhoCrashed
;Chk_WinaeroTweaker
;Chk_WindowsRepair
Chk_WinMerge
;Chk_WinUAE
;Chk_WiseCare365
;Chk_WiseDiskCleaner
;Chk_WiseDriverCare
;Chk_WiseFolderHider
;Chk_WiseProgramUninstall
;Chk_WiseRegistryCleaner
;Chk_Zotero

; Hardware Tools

;Chk_CoreTemp
;Chk_CPUZ
;Chk_CrystalDiskInfo
;Chk_CrystalDiskMark
;Chk_DiskCheckup
;Chk_DriverBooster
;Chk_DriverEasy
;Chk_HWiNFO32
;Chk_HWiNFO64
;Chk_HWMonitor
;Chk_MSIAfterburner

; Documents

;Chk_AdobeReader
;Chk_Calibre
;Chk_ComicRack
;Chk_CutePDFWriter
;Chk_Evernote
;Chk_FoxitReader
;Chk_LibreOffice
;Chk_OpenOffice
;Chk_PDFCreator
;Chk_PDFedit
;Chk_PDFSamBasic
;Chk_PDFViewer
;Chk_PDFXChangeEditor
;Chk_PNotes
;Chk_SumatraPDF
;Chk_WPSOffice

; Media Tools

;Chk_Avidemux
;Chk_CDBurnerXP
;Chk_Etcher
;Chk_ExactAudioCopy
;Chk_ForMatFactory
;Chk_FreemakeVideoConverter
;Chk_FreeStudio
;Chk_HandBrake
;Chk_Imgburn
;Chk_Lightworks
;Chk_LMMS
;Chk_MagicISOCHK
;Chk_MKVToolNix
;Chk_MusicBrainzPicard
;Chk_OBSStudio
;Chk_OpenShot
;Chk_XMediaRecode
;Chk_XnView
;Chk_XnViewMP

; Messaging

;Chk_DavMail
;Chk_Discord
;Chk_eMClient
;Chk_Gpg4win
;Chk_Mailbird
;Chk_Mumble
;Chk_Pidgin
;Chk_Skype
;Chk_TeamSpeak
;Chk_Telegram
;Chk_Thunderbird
;Chk_Viber
;Chk_WhatsApp
;Chk_YahooMessenger

; Developer

;Chk_Atom
;Chk_Brackets
;Chk_CMake
;Chk_Codeblocks
;Chk_CoreFTP
;Chk_EditPadLite
;Chk_FileZilla
;Chk_Freeplane
;Chk_Frhed
;Chk_Git
;Chk_GitHubDesktop
;Chk_JAVAJDK8
;Chk_JAVAJDK8x64
;Chk_JAVAJDK9x64
;Chk_NotePad
;chk_NoteTabLight
;Chk_Putty
;Chk_RStudio
;Chk_SanBoxie
;Chk_SpeedCrunch
;Chk_TortoiseSVN
;Chk_VisualStudioCode
;Chk_WinDirStat
;Chk_WinSCP
;Chk_Wireshark

; Microsoft Visual C++ Runtimes

;Chk_Redist2005x64
;Chk_Redist2005x86
;Chk_Redist2008x64
;Chk_Redist2008x86
;Chk_Redist2010x64
;Chk_Redist2010x86
;Chk_Redist2012x64
;Chk_Redist2012x86
;Chk_Redist2013x64
;Chk_Redist2013x86
;Chk_Redist2017x64
;Chk_Redist2017x86

; Sharing

;Chk_AnyDesk
;Chk_Ares
;Chk_BitTorrent
;Chk_Dropbox
;Chk_eMule
;Chk_GoogleDrive
;Chk_Icloud
;Chk_mRemoteNG
;Chk_Nextcloud
;Chk_OneDrive
;Chk_OwnCloud
;Chk_QBTorrent
;Chk_ResilioSync
;Chk_TeamViewer
;Chk_Utorrent
;Chk_VirtualBox
;Chk_VMwareHC
;Chk_VNCServer
;Chk_VNCViewer
;Chk_Vuze
;Chk_Windscribe

; Graphics

;Chk_Blender
;Chk_FastStoneImageViewer
;Chk_Gimp
;Chk_ImageGlass
;Chk_Inkscape
;Chk_IrFanView
;Chk_LibreCAD
Chk_Paint
;Chk_Zoner

; Security

;Chk_360TotalSecurity
;Chk_AvastAntivirus
;Chk_AVG
;Chk_BitdefenderAR
;Chk_Cybereason
;Chk_EMET
;Chk_GlassWire
;Chk_IObitMalwareFighter
;Chk_KasperskyFree
;Chk_KeePass
;Chk_Malwarebytes
;Chk_MalwareBytesAntiExploit
;Chk_MSEAntivirus
;Chk_Panda
;Chk_RogueKiller
;Chk_Spybot
;Chk_SUPERAntiSpyware


; Miscellaneous

;Chk_GoogleEarth
;Chk_MyPhoneExplorer
;Chk_SamsungKies
;Chk_SonyPC
;Chk_WorldWideTelescope

; Gaming

;Chk_GOGGalaxy
;Chk_NvidiaPhysX
;Chk_Orgin
;Chk_RazerCortex
;Chk_Steam
;Chk_Uplay

; Portable Apps

;Chk_PortableAdwCleaner
;Chk_PortableAeroAdmin
;Chk_PortableAnyDeskPortable
;Chk_PortableASSSDBenchmark
;Chk_PortableBitdefenderUSB
;Chk_PortableCCleaner
;Chk_PortableChromeCleanup
;Chk_PortableComboFix
;Chk_PortableDDU
;Chk_PortableDefraggler
;Chk_PortableDesktopOK
;Chk_PortableDesktopOKx64
;Chk_PortableDOSBox
;Chk_PortableDShutdown
;Chk_PortableGeekUninstaller
;Chk_PortableGPUZ
;Chk_PortableInSpectre
;Chk_PortableKasperskyTDSSKiller
;Chk_PortableNETFrameworkRepairTool
;Chk_PortableOOShutUp
;Chk_PortableRecuva
;Chk_PortableRKill
;Chk_PortableRogueKillerx64
;Chk_PortableRogueKillerx86
;Chk_PortableRufus
;Chk_PortableSpeccy
;Chk_PortableSpeedyFox
;Chk_PortableSubtitleWorkshop
;Chk_PortableSysinternalsSuite
;Chk_PortableTorBrowser
;Chk_PortableUltimateWindowsTweaker
;Chk_PortableWindowsRepair
;Chk_PortableWindowsUpdateMiniTool
;Chk_PortableWSUSOfflineUpdates






")


function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "Intune",
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
		    $LogFile = "$env:ProgramData\Intune\Logs\IForgotToName.log"
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

CMTraceLog -Message  "-----------------------------------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Running Script: $ScriptName | Version: $ScriptVersion" -Type 1 -LogFile $LogFile

$Tasks = Get-ScheduledTask | Where-Object {$_.TaskName -match $TaskName}
if ((Test-Path -Path $EXE) -and ($Tasks)){
    CMTraceLog -Message "Patch My PC Home App Already Installed, Exiting" -Type 1 -LogFile $LogFile
    }
else{
    CMTraceLog -Message "Patch My PC Home App not found to be running, starting install process" -Type 1 -LogFile $LogFile
    if (!(Test-Path -Path $ProgramFolder)){
        CMTraceLog -Message "Creating $ProgramFolder for Installation" -Type 1 -LogFile $LogFile
        New-Item -Path $ProgramFolder -ItemType Directory | Out-Null
    }
    if (!(Test-Path -Path $EXE)){
        CMTraceLog -Message "Downloading Patch My PC Home App to $ProgramFolder" -Type 1 -LogFile $LogFile            
        Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $EXE
    }

    if (Test-Path -Path $EXE){
        CMTraceLog -Message "Creating Scheduled task Patch My PC" -Type 1 -LogFile $LogFile  
        CMTraceLog -Message " Runs daily at 9:15PM if Network Connection" -Type 1 -LogFile $LogFile                     
        $action = New-ScheduledTaskAction -Execute "C:\Program Files\PMPC\PatchMyPC.exe" -Argument "/silent"
        $trigger = New-ScheduledTaskTrigger -Daily -At '9:15 PM'
        $STPrin = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
        $Timeout = (New-TimeSpan -Minutes 30)
        $settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -AllowStartIfOnBatteries -StartWhenAvailable -DontStopIfGoingOnBatteries -ExecutionTimeLimit $Timeout
        $task = New-ScheduledTask -Action $action -principal $STPrin -Trigger $trigger -Settings $settings
        Register-ScheduledTask $TaskName -InputObject $task -Force
    }
    $ConfigFileContent | Out-File -FilePath $ConfigFile -Encoding utf8 -Force 
}

