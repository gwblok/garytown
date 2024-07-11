function Get-HPDockUpdateDetails {

  <#
   .Author 
    Gary Blok | HP Inc | @gwblok | GARYTOWN.COM
    Dan Felman | HP Inc | @dan_felman 

   .Synopsis
    HP Dock Updater Script

   .Description
    Script will use HPCMSL / Hard coded URLS to get the latest URL for the firmware
    Script will download the Latest Firmware for the Dock from HP or if using CMPackage Parameter, look for the contents in CCMCache
    If you want to Bypass HPCMSL manually, because you want manually control which version is being deployed, use the parameter "BypassHPCMSL" in the command line AND
    - make sure you set the $URL to the version of the firmware you want... as the of the day I write this, it's the latest one.

   .Requirements
    PowerShell must have access to the interent to download the Firmware

   .Parameter UIExperience
    Sets the UI experience for the end user.  
    Options: 
      NonInteractive - Shows the Dialog box with progress to the end user
      Silent - completely hidden to the end user

   .Parameter WaitTimer [int]
    Value from 60 to 600 (seconds) to wait for a dock to be connected if one isn't connected at the start of the function.  Useful if triggering script via scheduled task that is triggered via event viewer logs
    Event Viewer info to use with Scheduled Task: Log: System | Source: nhi | Event ID: 9008
    If time runs out, the function with exit with "No Dock Connected"
   
   .Parameter Transcript [Switch]
    Creates a transcript of the process, and enables write-host commands in function to provide more information.
   
   .Parameter CMPackage [Switch]
    Skips using HPCMSL or downloading the Firmware.  Looks for the Firmware Package Content in CCMCache when using a Task Sequence - HPDOCK TS variable
   
   .Parameter Update [Switch]
    by default, the script does a Check of the installed firmware. The -Update switch enables the script to execute
    a firmware update if one is needed

   .Parameter stage [Switch]
    when the dock supports the staging option, if you choose this parameter, the Update will be staged to install on disconnect instead of running immediately.
    If the dock doesn't support -stage, it will ignore this switch and install immediately

   .ChangeLog
    23.04.06.01 - First Release as DockUpdater.ps1
    23.04.07.01 - change -C so scripts defaults to Check, added -Update option to enable firmware update.
    23.04.07.02 - Added fix for Thunderbolt dock lookups, requires checking registry to get current information vs txt file
    23.04.08.01 - Added syntax to only have Write-Hosts when debugging or logging | Added Return as PowerShell Object
    23.04.08.02 - Minor fixes to WaitTimer & Mode Variables
    23.04.12.01 - Fix WaitTimer Loop
    23.04.12.02 - Added Softpaq Number into the Return output
    23.04.18.01 - Added a lot of support around the USB-C Dock G4 as it has a completely different update process.
    23.04.18.02 - Added Registry Values for the G4 Dock to match the other docks, so it can be more easily inventory via CM
    23.04.18.03 - Added CM Package Support.  You can now keep the Softpaqs in a CM Package for use with TASK SEQUENCE
    23.04.19.01 - Added Registry Values for the Essential G5 Dock to match the other docks, so it can be more easily inventory via CM
    23.04.19.02 - Lots of minor bug fixes for the Thunderbolt G2 Dock and other Registry Based Docks
    23.05.22.01 - Added -stage parameter which supports USB-C Dock G5 & HP USB-C Universal Dock G2 & HP Thunderbolt Dock G4
    23.06.06.01 - Updated SoftPaq for USB-C Dock G5 from sp143343 (1.0.16.0) to sp146273 (1.0.18.0)
    23.06.06.02 - Updated SoftPaq for USB-C/A Universal Dock G2 from sp143343 (1.1.16.0) to sp146273 (1.1.18.0)
    23.06.08.01 - Fixed issue with Thunderbolt Dock detection if another Dock had been connected and updated on device in past, leaving Registry Info Behind.
    23.09.07.01 - Added fallback if current HP Device doesn't have softpaq list, falls back to pre-determined model.(Get-SoftpaqList -Category Dock -Platform 8870 )
    23.09.07.02 - Added additional support for HP E24d G4 Docking Monitor
    23.09.07.03 - updated firmware URLs for Docks: TB G4 & USB-C G5 Essential
    23.12.06.01 - updated firmware URLs for Docks: TB G4 & USB-C G5 Essential
    23.12.06.02 - cleaned up the firmware link area, added more notes
    24.04.01.01 - updated firmware URLs for Docks: TB G4 & USB-C G5 Essential & USB-C G5 & HP USB-C Universal Dock G2
    24.07.01.01 - added logic for CMSL to find latest supported OS to be able to better find softpaqs
    24.07.01.02 - now also looks for Thunderbolt Contoller driver info in Windows and compares to Softpaq Driver and recommends update if found
    24.07.01.03 - added UpdateControllerDriver switch, which will also update the controller driver using CMSL
    24.07.11.01 - modified the process for the USB-C G4 docks, cleaned it up a bit.
    24.07.11.02 - added a few write-hosts around the TB Controller driver update process.

   .Notes
    This will ONLY create a transcription log IF the dock is attached and it starts the process to test firmware.  If no dock is detected, no logging is created.
    Logging created by this line: Start-Transcript -Path "$OutFilePath\$SPNumber.txt" - which should be like: "C:\swsetup\dockfirmware\sp144502-DATE.txt"

   DockUpdaterNotes
    HPFirmwareUpdater.exe Options:
      Non-Interactive		-ni
      Silent mode			  -s		    		
      Force				      -f	

   DocksTested:
    1) HP USB-C G5 Essential Dock
    2) HP Thunderbolt Dock G4
    3) Waiting on HP USB-C Dock G5 & HP USB-C Universal Dock G2 docks for additional testing
    4) HP USB-C Dock G4 - See notes below
    4) PLEASE report your findings to me @gwblok
    
    Docks that are Unique and a lot of custom code was added to make this work....
    1) HP USB-C Dock G4, this is an older dock, and the file structure of the softpaq is different than the newer ones.
       There is NO check option on the Firmware Updater, if you trigger the updater, it just goes
       I have no WAY to lookup the current version of the Firmware Installed, so basically I just try to run the updater and update it to the latest
       If you update the Firmware with this script and it was successful (exit code 0). it stamps that to registry for future consideration, and this function will not try to update it again.

   .Example
     # Update the Dock's firmware to the latest version HPCMSL (if installed) will find completely silent to end user
     Get-HPDockUpdateDetails -Update -UIExperience Silent

   .Example
     # Updates the Dock's firmware while making the UI visable to the enduser but not interactive (Read only)
     Get-HPDockUpdateDetails -Update -UIExperience NonInteractive -BypassHPCMSL        # no CMSL on device
     Get-HPDockUpdateDetails -Update -UIExperience NonInteractive                      # use CMSL to find latest f/w Softpaq

   .Example
     # Check the Dock's firmware version without CMSL (SOftpaqs URL hardcoded), or with CMSL and will create a transcript log
     Get-HPDockUpdateDetails -UIExperience Silent -Transcript -BypassHPCMSL # no CMSL on device, use hardcoded 
     Get-HPDockUpdateDetails -UIExperience Silent -Transcript              # use CMSL to find latest f/w Softpaq

   .Example
     # Use Script with Task Sequence
     Get-HPDockUpdateDetails -CMPackage -Update - This will look for a Package that was downloaded and stored in Varaible HPDOCK

   .Example
     # Update the Dock's firmware to the latest version HPCMSL (if installed) will find completely silent to end user - Stage the content on the dock to install at disconnect
     Get-HPDockUpdateDetails -Update -stage -UIExperience Silent
  #>
  [CmdletBinding()]
  param(
      [Parameter(Mandatory = $false, HelpMessage="Only matters when used with -Update, determine if user will see dialog or not")][ValidateSet('NonInteractive', 'Silent')][String]$UIExperience,
      [Parameter(Mandatory = $false, HelpMessage="Number between 60 and 600 for seconds to wait for a dock to be connected before exiting automatically")][ValidateRange(60,600)][int]$WaitTimer,
      [switch]$CMPackage, #This requires that you have a download step in the TS that downloads the Dock Firmware Softpaqs and places in variable HPDOCK (%HPDOCK01%)
      [switch]$BypassHPCMSL,
      [switch]$Transcript,
      [switch]$Update,
      [switch]$Stage,
      [switch]$DebugOut,
      [switch]$UpdateControllerDriver
      
  ) # param

  $ScriptVersion = '23.09.07.03'

  # check for CMSL
  if ($CMPackage -ne $true){
      Try {
          $HPDeviceDetails = Get-HPDeviceDetails -ErrorAction SilentlyContinue 
          $CMSL = $true
        }
      catch {
          $BypassHPCMSL = $true }

      $AdminRights = ([Security.Principal.WindowsPrincipal] `
                  [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
      if ( $DebugOut ) { Write-Host "--Admin rights:"$AdminRights }
  }
  if ($CMSL){
      #Get the Max OS & OSVer Supported OS for a Device (Plaform = 8549 - HP EliteBook 840 G6):

    $MaxOSSupported = ((Get-HPDeviceDetails -oslist).OperatingSystem | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| Measure-Object -Maximum).Maximum
    $MaxOSVer = ((Get-HPDeviceDetails -oslist | Where-Object {$_.OperatingSystem -eq "$MaxOSSupported"}).OperatingSystemRelease | Measure-Object -Maximum).Maximum
    if ($MaxOSSupported -Match "11"){$MaxOS = "Win11"}
    else {$MaxOS = "Win10"}
    #Write-Output "Max OS Supported: $MaxOSSupported $MaxOSVer"
    $ThunderBoltDriver = Get-SoftpaqList -Category Driver -Os $MaxOS -OsVer $MaxOSVer | Where-Object { $_.Name -match 'Thunderbolt' -and $_.Name -notmatch "Audio" }
    $InstalledTBDriver = Get-CimInstance -ClassName Win32_PnPSignedDriver | Where-Object { $_.Description -like "*Thunderbolt*Controller*"  }
    if (($Null -ne $ThunderBoltDriver) -and ($Null -ne $InstalledTBDriver)){
        if ($ThunderBoltDriver.Version -eq $InstalledTBDriver.DriverVersion){
          if (($DebugOut) -or ($Transcript)){write-host -ForegroundColor Green "TB Driver is Updated: Availble Softpaq: $($ThunderBoltDriver.Version) | Installed: $($InstalledTBDriver.DriverVersion)"}
          if ($UpdateControllerDriver){
            write-host -ForegroundColor Yellow " Skipping Requested Update of Drivers, already current"
          }
        }
        else {
          #Driver Update Needed
          write-host -ForegroundColor Yellow "TB Driver Update Available: $($ThunderBoltDriver.Version) | Installed: $($InstalledTBDriver.DriverVersion)"
          write-host -ForegroundColor Yellow "Recommend updating with $($ThunderBoltDriver.Name) | $($ThunderBoltDriver.id)"
          $DriverUpdateAvailable = $ThunderBoltDriver.id
          if ($UpdateControllerDriver){
            Write-Host -ForegroundColor Green " UpdateControllerDriver Switch Enabled... Updating driver now..."
            Get-Softpaq -Number $ThunderBoltDriver.id -SaveAs "c:\swsetup\$($ThunderBoltDriver.id).exe" -Action silentinstall -Overwrite yes
          }
        }
    }

  }
  function Get-HPDockInfo {
      [CmdletBinding()]
      param($pPnpSignedDrivers)

      # **** Hardcode URLs in case of no CMSL installed: ****
      #USB-C G5 Essential Dock
      $Url_EssG5 = 'https://ftp.hp.com/pub/softpaq/sp151501-152000/sp151760.exe'  #  01.00.10.00 | Mar 14, 2024
      
      #Thunderbolt G4
      $Url_TBG4 = 'https://ftp.hp.com/pub/softpaq/sp151501-152000/sp151762.exe'   #  1.5.22.0 | Mar 14, 2024

      #Thunderbolt G2
      $Url_TBG2 = 'ftp.hp.com/pub/softpaq/sp143501-144000/sp143977.exe'   #  1.0.71.1 | Dec 15, 2022

      #USB-C Dock G5
      $Url_UsbG5 = 'https://ftp.hp.com/pub/softpaq/sp150001-150500/sp150455.exe'  #  1.0.20.0 | Dec 20, 2023

      #USB-C Universal Dock G2
      $Url_UniG2 = 'https://ftp.hp.com/pub/softpaq/sp150001-150500/sp150473.exe'  #  1.0.20.0 | Dec 4, 2023

      #USB-C Dock G4
      $Url_UsbG4 = 'ftp.hp.com/pub/softpaq/sp88501-89000/sp88999.exe'     #  F.37 | Jul 15, 2018

      #Elite USB-C Dock
      $Url_UsbElite = 'https://ftp.hp.com/pub/softpaq/sp83501-84000/sp83851.exe'     #  1.00 Rev.B | Dec 12, 2017

      #E24d G4 FHD Docking Monitor
      $Url_E24D = 'ftp.hp.com/pub/softpaq/sp145501-146000/sp145577.exe'   #  1.0.17.0 | Mar 28, 2023

      
      #######################################################################################
      $Dock_Attached = 0      # default: no dock found
      $Dock_ProductName = $null
      $Dock_Url = $null   
      # Find out if a Dock is connected - assume a single dock, so stop at first find
      foreach ( $iDriver in $pPnpSignedDrivers ) {
          $f_InstalledDeviceID = "$($iDriver.DeviceID)"   # analyzing current device
          if ( ($f_InstalledDeviceID -match "HID\\VID_03F0") -or ($f_InstalledDeviceID -match "USB\\VID_17E9") ) {
              switch -Wildcard ( $f_InstalledDeviceID ) {
                  '*PID_0488*' { $Dock_Attached = 1 ; $Dock_ProductName = 'HP Thunderbolt Dock G4' ; $Dock_Url = $Url_TBG4 ; $FirmwareInstaller = 'HPFirmwareInstaller.exe'}
                  '*PID_0667*' { $Dock_Attached = 2 ; $Dock_ProductName = 'HP Thunderbolt Dock G2' ; $Dock_Url = $Url_TBG2 ; $FirmwareInstaller = 'HPFirmwareInstaller.exe' }
                  '*PID_484A*' { $Dock_Attached = 3 ; $Dock_ProductName = 'HP USB-C Dock G4' ; $Dock_Url = $Url_UsbG4 ; $FirmwareInstaller = 'HP_USB-C_Dock_G4_FW_Update_Tool_Console.exe' }
                  '*PID_046A*' { $Dock_Attached = 3 ; $Dock_ProductName = 'HP Elite USB-C Dock' ; $Dock_Url = $Url_UsbElite ; $FirmwareInstaller = 'HP Elite USB-C Dock FW Update Tool.exe' }
                  '*PID_046B*' { $Dock_Attached = 4 ; $Dock_ProductName = 'HP USB-C Dock G5' ; $Dock_Url = $Url_UsbG5  ; $FirmwareInstaller = 'HPFirmwareInstaller.exe'}
                  #'*PID_600A*' { $Dock_Attached = 5 ; $Dock_ProductName = 'HP USB-C Universal Dock' }
                  '*PID_0A6B*' { $Dock_Attached = 6 ; $Dock_ProductName = 'HP USB-C Universal Dock G2' ; $Dock_Url = $Url_UniG2 ; $FirmwareInstaller = 'HPFirmwareInstaller.exe' }
                  '*PID_056D*' { $Dock_Attached = 7 ; $Dock_ProductName = 'HP E24d G4 FHD Docking Monitor'; $Dock_Url = $Url_E24D ; $FirmwareInstaller = 'HPFirmwareInstaller.exe' }
                  '*PID_016E*' { $Dock_Attached = 8 ; $Dock_ProductName = 'HP E27d G4 QHD Docking Monitor' }
                  '*PID_379D*' { $Dock_Attached = 9 ; $Dock_ProductName = 'HP USB-C G5 Essential Dock' ; $Dock_Url =  $Url_EssG5 ; $FirmwareInstaller = 'HPFirmwareInstaller.exe' }
              } # switch -Wildcard ( $f_InstalledDeviceID )
          } # if ( $f_InstalledDeviceID -match "VID_03F0")
          if ( $Dock_Attached -gt 0 ) { break }
      } # foreach ( $iDriver in $gh_PnpSignedDrivers )
      #######################################################################################

      return @(
          @{Dock_Attached = $Dock_Attached ;  Dock_ProductName = $Dock_ProductName  ;  Dock_Url = $Dock_Url;  Dock_InstallerName = $FirmwareInstaller}
      )
  } # function Get-HPDockInfo

  function Get-PackageVersion {
      [CmdletBinding()]param( $pDocknum, $pCheckFile ) # param

      if (Test-Path -Path $pCheckFile){
          $TestInfo = Get-Content -Path $pCheckFile
      }
      if ( $pDocknum -eq 9 ) {       
          [String]$InstalledVersion = $TestInfo | Select-String -Pattern 'installed' -SimpleMatch
          $InstalledVersion = $InstalledVersion.Split(":") | Select-Object -Last 1            
      } 
      elseif ( $pDocknum -in (1,2)){
          $TBDockPath = "HKLM:\SOFTWARE\HP\HP Firmware Installer"
          if (Test-Path -Path $TBDockPath) {
              $TBDockKeyChildren = Get-ChildItem -Path $TBDockPath -Recurse
              foreach ($Children in $TBDockKeyChildren){
                  if ($Children.Name -match "Thunder"){
                      $InstalledPackageVersion = $Children.GetValue('InstalledPackageVersion')    
                      if ($InstalledPackageVersion){$InstalledVersion = $InstalledPackageVersion}
                  }
              }
          }
      }
      else {
          [String]$InstalledVersion = $TestInfo | Select-String -Pattern 'Package' -SimpleMatch
          $InstalledVersion = $InstalledVersion.Split(":") | Select-Object -Last 1
      }
      return $InstalledVersion
  } # function Get-PackageVersion

  #########################################################################################

  #'-- Reading signed drivers list - use to scan for attached HP docks'
  $PnpSignedDrivers = Get-CimInstance win32_PnpSignedDriver 

  $Dock = Get-HPDockInfo $PnpSignedDrivers
  if ( $DebugOut ) { Write-Host "--Dock detected:"$Dock.Dock_ProductName }
  $HPFIrmwareUpdateReturnValues = @(
          @{Code = "0" ;  Message = "Success"}
          @{Code = "101" ;  Message = "Install or stage failed. One or more firmware failed to install."}
          @{Code = "102" ;  Message = "Configuration file failed to be loaded.This may be because it could not be found or that it was not properly formatted."}
          @{Code = "103" ;  Message = "One or more firmware packages specified in the configuration file could not be loaded."}
          @{Code = "104" ;  Message = "No devices could be communicated with.This could be because necessary drivers are missing to detect the device."}
          @{Code = "105" ;  Message = "Out - of - date firmware detected when running with 'check' flag."}
          @{Code = "106" ;  Message = "An instance of HP Firmware Installer is already running"}
          @{Code = "107" ;  Message = "Device not connected.This could be because PID or VID is not detected."}
          @{Code = "108" ;  Message = "Force option disabled.Firmware downgrade or re - flash not possible on this device."}
          @{Code = "109" ;  Message = "The host is not able to update firmware"}
      )
  # lop for up to 10 secs in case we just powered-on, or Dock detection takes a bit of time
  [int]$Counter = 0
  [int]$StepAmt = 20
  if ( $Dock.Dock_Attached -eq 0 ) {
      if ( $DebugOut ) { Write-Host "Waiting for Dock to be fully attached up to $WaitTimer seconds" -ForegroundColor Green }
      do {
          if ( $DebugOut ) { Write-Host " Waited $Counter Seconds Total.. waiting additional $StepAmt" -ForegroundColor Gray}
          $counter += $StepAmt
          Start-Sleep -Seconds $StepAmt
    $PnpSignedDrivers = Get-CimInstance win32_PnpSignedDriver
          $Dock = Get-HPDockInfo $PnpSignedDrivers
          if ( $counter -eq $WaitTimer ) {
              if ( $DebugOut ) { Write-Host "Waited $WaitTimer Seconds, no dock found yet..." -ForegroundColor Red}
          }
      }
      while ( ($counter -lt $WaitTimer) -and ($Dock.Dock_Attached -eq "0") )
  } # if ( $Dock.Dock_Attached -eq "0" )

  if ( $Dock.Dock_Attached -eq 0 ) {
      Write-Host " No dock attached" -ForegroundColor Green
  } else {
      # NOW, let's get to work on the dock, if found
      if ( ($BypassHPCMSL -eq $true) -or ($CMPackage -eq $true) ) {
          $URL = $Dock.Dock_Url
          if ( $DebugOut ) { Write-Host "--Dock detected Url - hardcoded:"$Dock.Dock_Url }
      } else {
          try {
              $URL = (Get-SoftpaqList -Os $MaxOS -OsVer $MaxOSVer -Category Dock -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $dock.Dock_ProductName -and ($_.Name -match 'firmware') }).Url
          }
          catch {
              $URL = (Get-SoftpaqList -Category Dock -Platform 8870 -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $dock.Dock_ProductName -and ($_.Name -match 'firmware') }).Url
          }
          if ((!($URL))-or ($URL -eq "")){ #Fall back
              $URL = $Dock.Dock_Url
              if ( $DebugOut ) { Write-Host "--Dock detected Url - hardcoded:"$Dock.Dock_Url }
          }
      } # else if ( $BypassHPCMSL )

      $SPEXE = ($URL.Split("/") | Select-Object -Last 1)
      $SPNumber = ($URL.Split("/") | Select-Object -Last 1).replace(".exe","")
      if ( $DebugOut ) { Write-Host "--Dock detected firmware Softpaq:"$SPEXE }

      # Create Required Folders
      $OutFilePath = "$env:SystemDrive\swsetup\dockfirmware"
      $ExtractPath = "$OutFilePath\$SPNumber"
  
      
      if ($Transcript) {
          $Date = Get-Date -Format yyyyMMdd
          Start-Transcript -Path "$OutFilePath\$($SPNumber)-$($Date).txt"
      }
      if (($DebugOut) -or ($Transcript)) {write-Host $ScriptVersion}
      if (!($CMPackage)){ if (($DebugOut) -or ($Transcript)) {write-Host "  Running script with CMSL ="(-not $BypassHPCMSL) -ForegroundColor Gray}}
      if ( $Update ) {
          if (($DebugOut) -or ($Transcript)) {write-Host "  Executing a dock firmware update" -ForegroundColor Cyan}
      } else {
          if (($DebugOut) -or ($Transcript)) {write-Host "  Executing a check of the dock firmware version. Use -Update to update the firmware" -ForegroundColor Cyan}
      }
      try {
          [void][System.IO.Directory]::CreateDirectory($OutFilePath)
          [void][System.IO.Directory]::CreateDirectory($ExtractPath)
      } catch { 
          if ( $DebugOut ) { Write-Host "--Error creating folder"$ExtractPath }
          throw 
      }
      # Download Softpaq EXE
      if ($CMPackage){ #USE CM PACKAGE
          try { #Connect to TS Environment
              $tsenv = new-object -comobject Microsoft.SMS.TSEnvironment
              }

          catch{Write-Output "Not in TS"}
          if ($tsenv) {
              $CMPackagePath = $tsenv.value("HPDOCK01") #Make sure you have a step to download the package into the CCMCache before you run this... store the patch in HPDOCK variable
              Copy-Item -Path "$CMPackagePath\$SPEXE" -Destination "$OutFilePath\$SPEXE"
              if (!(Test-Path "$OutFilePath\$SPEXE")){
                  if (($DebugOut) -or ($Transcript)) {write-Host "  Failed to Copy $SPEXE to $OutFilePath from CCMCache: $CMPackagePath" -ForegroundColor Red}
              }
              else {
                  if (($DebugOut) -or ($Transcript)) {write-Host "  Successfully Copied $SPEXE to $OutFilePath from CCMCache: $CMPackagePath" -ForegroundColor Cyan}
              }
          }
      }
      else {
          if ( !(Test-Path "$OutFilePath\$SPEXE") ) { 
              try {
                  $Error.Clear()
                  if (($DebugOut) -or ($Transcript)) {Write-Host "  Starting Download of $URL to $OutFilePath\$SPEXE" -ForegroundColor Magenta}
                  Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile "$OutFilePath\$SPEXE"
              } catch {
                  if (($DebugOut) -or ($Transcript)) {Write-Host "!!!Failed to download Softpaq!!!" -ForegroundColor red}
                  if ($Transcript){ Stop-Transcript}
                  return -1
              }
          } else {
              if (($DebugOut) -or ($Transcript)) {Write-Host "  Softpaq already downloaded to $OutFilePath\$SPEXE" -ForegroundColor Gray}
          }
      }
      # Extract Softpaq EXE
      $FirmwareInstallerName = $Dock.Dock_InstallerName
      if ( Test-Path "$OutFilePath\$SPEXE" ) {     
          if (!(Test-Path "$OutFilePath\$SPNumber\$FirmwareInstallerName")){
              if (($DebugOut) -or ($Transcript)) {Write-Host "  Extracting to $ExtractPath" -ForegroundColor Magenta}
              if ( $AdminRights -or $CMPackage ) {
                  $Extract = Start-Process -FilePath $OutFilePath\$SPEXE -ArgumentList "/s /e /f $ExtractPath" -NoNewWindow -PassThru -Wait
              } else {
                  if (($DebugOut) -or ($Transcript)) {Write-Host "  Admin rights require to extract to $ExtractPath" -ForegroundColor Red}
                  Stop-Transcript
                  return -1
              }           
          } else {
              if (($DebugOut) -or ($Transcript)) {Write-Host "  Softpaq already Extracted to $ExtractPath" -ForegroundColor Gray}
          }
      } else {
          if (($DebugOut) -or ($Transcript)) {Write-Host "  Failed to find $OutFilePath\$SPEXE" -ForegroundColor Red}
          if ($Transcript){ Stop-Transcript}
          return -1
      }

      # Get package version from downloaded Softpaq configuration file
      $ConfigFile = "$OutFilePath\$SPNumber\HPFIConfig.xml"       # All docks except Essential
      $ConfigFileEssential = "$OutFilePath\$SPNumber\config.ini"  # Essential dock
      $ReadmeFileUSBCGen4 = "$OutFilePath\$SPNumber\HP_USB-C_Dock_G4_FW_Update_Tool_readme.txt"
      if ( Test-Path $ConfigFile ) {
          $xmlConfigContent = [xml](Get-Content -Path $ConfigFile)
          $PackageVersion = $xmlConfigContent.SelectNodes("FirmwareCollectionPackage/PackageVersion").'#Text'
          $ModelName = $xmlConfigContent.SelectNodes("FirmwareCollectionPackage/Name").'#Text'
          if (($DebugOut) -or ($Transcript)) {Write-Host "  Extracted Softpaq Info file: $ConfigFile" -ForegroundColor Cyan}
      } elseif ( Test-Path $ConfigFileEssential ) {    
          $ConfigInfo = Get-Content -Path $ConfigFileEssential
          [String]$PackageVersion = $ConfigInfo | Select-String -Pattern 'PackageVersion' -CaseSensitive -SimpleMatch
          [String]$ToolVersion = $ConfigInfo | Select-String -Pattern 'ToolVersion' -CaseSensitive -SimpleMatch
          if($PackageVersion){$PackageVersion = $PackageVersion.Split("=") | Select-Object -Last 1}
          if ($ToolVersion){$PackageVersion = $ToolVersion.Split("=") | Select-Object -Last 1}
          [String]$ModelName = $ConfigInfo | Select-String -Pattern 'ModelName' -CaseSensitive -SimpleMatch
          $ModelName = $ModelName.Split("=") | Select-Object -Last 1
          if (($DebugOut) -or ($Transcript)) {Write-Host "  Extracted Softpaq Info file: $ConfigFileEssential" -ForegroundColor Cyan}
      } # elseif ( Test-Path $ConfigFileEssential )
  
      if (($DebugOut) -or ($Transcript)) {Write-Host "  Softpaq for Device: $ModelName" -ForegroundColor Gray}
      if (($DebugOut) -or ($Transcript)) {Write-Host "  Softpaq Version: $PackageVersion" -ForegroundColor Gray}
      $script:SoftpaqSupportedDevice = $ModelName
      $script:SoftPaqVersion = $PackageVersion
      $DockRegPath = 'HKLM:\SOFTWARE\HP\HP Firmware Installer'
      [string]$MACAddress = (Get-WmiObject win32_networkadapterconfiguration | Where-Object {$_.Description -match "Realtek USB GbE Family Controller"}).MACAddress
      $MACAddress = $MACAddress.Trim()
      if (Test-Path "$OutFilePath\$SPNumber\$FirmwareInstallerName") { # Run Test only - Check if Update Required
          Set-Location -Path "$OutFilePath\$SPNumber"
          if (($DebugOut) -or ($Transcript)) {Write-Host " Running HP Firmware Check... please, wait" -ForegroundColor Magenta}
          # HP USB-C Dock G4 Special Process
          if ($Dock.Dock_ProductName -eq "HP USB-C Dock G4"){
              $DockG4RegPath = "$DockRegPath\HP USB-C Dock G4"
              if (!(Test-Path -path $DockG4RegPath)){
                  if (($DebugOut) -or ($Transcript)) {Write-Host " Creating $DockG4RegPath Key" -ForegroundColor green}
                  New-Item -Path $DockG4RegPath -Force | Out-Null
                  }
              New-ItemProperty -Path $DockG4RegPath -Name 'AvailablePackageVersion' -Value $PackageVersion -PropertyType string -Force | Out-Null
              New-ItemProperty -Path $DockG4RegPath -Name 'LastChecked' -Value $(Get-Date -Format "yyyy/MM/dd HH:mm:ss") -PropertyType string -Force | Out-Null
              
              New-ItemProperty -Path $DockG4RegPath -Name 'MACAddress' -Value $MACAddress -PropertyType string -Force | Out-Null
              $DockG4RegItem = Get-Item -Path $DockG4RegPath
              if ($DockG4RegItem.GetValue('InstalledPackageVersion') -eq $PackageVersion){
                  $script:UpdateRequired = $false
                  if (($DebugOut) -or ($Transcript)) {Write-Host " Firmware Already Current (according to the Registry): $PackageVersion" -ForegroundColor Green}
              }
              else {
                  if ($Update){
                      if (($DebugOut) -or ($Transcript)) {Write-Host " Update Needed (according to the Registry): $PackageVersion" -ForegroundColor Magenta}
                      Try {
                          $Error.Clear()
                          $Output = "$OutFilePath\$SPNumber\FirmwareUpdateLog.txt"
                          $HPFirmwareTest = Start-Process -FilePath "$OutFilePath\$SPNumber\$FirmwareInstallerName" -PassThru -Wait -NoNewWindow -RedirectStandardOutput $OutPut
                          New-ItemProperty -Path $DockG4RegPath -Name 'LastUpdateRun' -Value $(Get-Date -Format "yyyy/MM/dd HH:mm:ss") -PropertyType string -Force | Out-Null
                      } 
                      Catch {
                          if (($DebugOut) -or ($Transcript)) {write-Host $error[0].exception}
                          Stop-Transcript
                          return -5
                      }
                      $LogContent = Get-Content -Path $Output -ReadCount 1 -Tail 2
                      if ($LogContent -match "Current firmware is the latest one"){
                          New-ItemProperty -Path $DockG4RegPath -Name 'InstalledPackageVersion' -Value $PackageVersion -PropertyType string -Force | Out-Null
                          New-ItemProperty -Path $DockG4RegPath -Name 'ErrorCode' -Value $HPFirmwareTest.ExitCode -PropertyType dword -Force | Out-Null
                          New-ItemProperty -Path $DockG4RegPath -Name 'LastUpdateStatus' -Value "Success" -PropertyType string -Force | Out-Null
                          if (($DebugOut) -or ($Transcript)) {Write-Host " Firmware is already current" -ForegroundColor Green}
                          if (($DebugOut) -or ($Transcript)) {Write-Host " Installed Version: $PackageVersion" -ForegroundColor Green}
                          $script:UpdateRequired = $false
                          $script:InstalledFirmwareVersion = $PackageVersion
                          if (($DebugOut) -or ($Transcript)) {Write-Host " No Update Needed: Exit 1" -ForegroundColor Green}
                      }
                      else {
                          if ($HPFirmwareTest.ExitCode -eq 0){
                              New-ItemProperty -Path $DockG4RegPath -Name 'InstalledPackageVersion' -Value $PackageVersion -PropertyType string -Force | Out-Null
                              New-ItemProperty -Path $DockG4RegPath -Name 'ErrorCode' -Value $HPFirmwareTest.ExitCode -PropertyType dword -Force | Out-Null
                              New-ItemProperty -Path $DockG4RegPath -Name 'LastUpdateStatus' -Value "Success" -PropertyType string -Force | Out-Null
                              if (($DebugOut) -or ($Transcript)) {Write-Host " Firmware is now updated" -ForegroundColor Green}
                              if (($DebugOut) -or ($Transcript)) {Write-Host " Installed Version: $PackageVersion" -ForegroundColor Green}
                              $script:UpdateRequired = $false
                              $script:InstalledFirmwareVersion = $PackageVersion
                              if (($DebugOut) -or ($Transcript)) {Write-Host " Update Successful: Exit 0" -ForegroundColor Green}
                          }
                          elseif ($HPFirmwareTest.ExitCode -eq 1){
                              New-ItemProperty -Path $DockG4RegPath -Name 'InstalledPackageVersion' -Value "NA" -PropertyType string -Force | Out-Null
                              New-ItemProperty -Path $DockG4RegPath -Name 'ErrorCode' -Value $HPFirmwareTest.ExitCode -PropertyType dword -Force | Out-Null
                              New-ItemProperty -Path $DockG4RegPath -Name 'LastUpdateStatus' -Value "NA" -PropertyType string -Force | Out-Null
                              if (($DebugOut) -or ($Transcript)) {Write-Host " Update Status Unknown: Exit $($HPFirmwareTest.ExitCode)" -ForegroundColor Red}
                          }
                          else {
                              New-ItemProperty -Path $DockG4RegPath -Name 'InstalledPackageVersion' -Value "NA" -PropertyType string -Force | Out-Null
                              New-ItemProperty -Path $DockG4RegPath -Name 'ErrorCode' -Value $HPFirmwareTest.ExitCode -PropertyType dword -Force | Out-Null
                              New-ItemProperty -Path $DockG4RegPath -Name 'LastUpdateStatus' -Value "Fail" -PropertyType string -Force | Out-Null
                              if (($DebugOut) -or ($Transcript)) {Write-Host " Update Failed: Exit $($HPFirmwareTest.ExitCode)" -ForegroundColor Red}
                          }
                    }

                  }
                  else {
                      $script:UpdateRequired = $true
                  }
              }
          } #IF "HP USB-C Dock G4"

          else {
              Try {
                  $Error.Clear()
                  $HPFirmwareTest = Start-Process -FilePath "$OutFilePath\$SPNumber\$FirmwareInstallerName" -ArgumentList "-C" -PassThru -Wait -NoNewWindow
              } Catch {
                  if (($DebugOut) -or ($Transcript)) {write-Host $error[0].exception}
                  Stop-Transcript
                  return -5
              }
              if ( $Dock.Dock_Attached -eq 9 ) {  # Essential dock found
                  $VersionFile = "$OutFilePath\$SPNumber\HPFI_Version_Check.txt"
              } else {
                  $VersionFile = ".\HPFI_Version_Check.txt"
              }


      
              switch ( $HPFirmwareTest.ExitCode ) {
                  0   { 
                          if (($DebugOut) -or ($Transcript)) {Write-Host " Firmware is up to date" -ForegroundColor Green}
                          $InstalledVersion = Get-PackageVersion $Dock.Dock_Attached $VersionFile
                          if (($DebugOut) -or ($Transcript)) {Write-Host " Installed Version: $InstalledVersion" -ForegroundColor Green}
                          $script:UpdateRequired = $false
                          $script:InstalledFirmwareVersion = $InstalledVersion
                      } # 0
                  105 {
                          if (!($UIExperience)){$UIExperience = 'NonInteractive'}
                          $Mode = switch ($UIExperience)
                          {
                              "NonInteractive" {"-ni"}
                              "Silent" {"-s"}
                              "Check" {"-C"}
                              "Force" {"-f"}
                          }
                          if (($DebugOut) -or ($Transcript)) {Write-Host " Update Required" -ForegroundColor Yellow}
                          $InstalledVersion = Get-PackageVersion $Dock.Dock_Attached $VersionFile
                          if (($DebugOut) -or ($Transcript)) {Write-Host " Installed Version: $InstalledVersion" -ForegroundColor Yellow}
                          
                          $script:InstalledFirmwareVersion = $InstalledVersion
                          if ($InstalledVersion -eq $PackageVersion){
                              if (($DebugOut) -or ($Transcript)) {Write-Host " Exit Code 105, but Versions already match, skipping Update" -ForegroundColor Yellow}
                              $script:UpdateRequired = $false
                          }
                          else {
                              $script:UpdateRequired = $true
                              if ( $Update ) {          
                                  $FirmwareArgList = "$Mode"
                                  if (($Dock.Dock_ProductName -eq "HP Thunderbolt Dock G4") -or ($Dock.Dock_ProductName -eq "HP USB-C Dock G5") -or ($Dock.Dock_ProductName -eq "HP USB-C Universal Dock G2")){
                                       if ($stage){
                                          $FirmwareArgList = "$Mode -stage"
                                       }
                                  }
                                  if (($DebugOut) -or ($Transcript)) {Write-Host " Starting Dock Firmware Update" -ForegroundColor Magenta}
                                  
                                  $HPFirmwareUpdate = Start-Process -FilePath "$OutFilePath\$SPNumber\HPFirmwareInstaller.exe" -ArgumentList "$FirmwareArgList" -PassThru -Wait -NoNewWindow
                                  $ExitInfo = $HPFIrmwareUpdateReturnValues | Where-Object { $_.Code -eq $HPFirmwareUpdate.ExitCode }
                                  if ($ExitInfo.Code -eq "0"){
                                      if (($DebugOut) -or ($Transcript)) {Write-Host " Update Successful!" -ForegroundColor Green}
                                  } else {
                                      if (($DebugOut) -or ($Transcript)) {Write-Host " Update Failed" -ForegroundColor Red}
                                      if (($DebugOut) -or ($Transcript)) {Write-Host " Exit Code: $($ExitInfo.Code)" -ForegroundColor Gray}
                                      if (($DebugOut) -or ($Transcript)) {Write-Host " $($ExitInfo.Message)" -ForegroundColor Gray}
                                  }
                              }
                          } # if ( $Update )
                      } # 105
              }
          } # Not HP USB-C Dock G4
          # HP USB-C G5 Essential Dock Registry Items
          if ($Dock.Dock_ProductName -eq "HP USB-C G5 Essential Dock"){
              $DockEssentialRegPath = "$DockRegPath\HP USB-C G5 Essential Dock"
              if (!(Test-Path -path $DockEssentialRegPath)){
                  if (($DebugOut) -or ($Transcript)) {Write-Host " Creating $DockEssentialRegPath Key" -ForegroundColor green}
                  New-Item -Path $DockEssentialRegPath -Force | Out-Null
              }
              New-ItemProperty -Path $DockEssentialRegPath -Name 'AvailablePackageVersion' -Value $PackageVersion -PropertyType string -Force | Out-Null
              New-ItemProperty -Path $DockEssentialRegPath -Name 'LastChecked' -Value $(Get-Date -Format "yyyy/MM/dd HH:mm:ss") -PropertyType string -Force | Out-Null
              New-ItemProperty -Path $DockEssentialRegPath -Name 'InstalledPackageVersion' -Value $InstalledVersion -PropertyType string -Force | Out-Null
              New-ItemProperty -Path $DockEssentialRegPath -Name 'ErrorCode' -Value $HPFirmwareTest.ExitCode -PropertyType dword -Force | Out-Null
              New-ItemProperty -Path $DockEssentialRegPath -Name 'MACAddress' -Value $MACAddress -PropertyType string -Force | Out-Null
              if ($HPFirmwareTest.ExitCode -eq "0"){
                  New-ItemProperty -Path $DockEssentialRegPath -Name 'LastUpdateStatus' -Value "Success" -PropertyType string -Force | Out-Null
              }
              elseif ($HPFirmwareTest.ExitCode -eq "105"){
                  if ($update) {
                      New-ItemProperty -Path $DockEssentialRegPath -Name 'LastUpdateRun' -Value $(Get-Date -Format "yyyy/MM/dd HH:mm:ss") -PropertyType string -Force | Out-Null
                      if ($ExitInfo.Code -eq "0"){
                          New-ItemProperty -Path $DockEssentialRegPath -Name 'ErrorCode' -Value $ExitInfo.Code -PropertyType dword -Force | Out-Null
                          New-ItemProperty -Path $DockEssentialRegPath -Name 'LastUpdateStatus' -Value "Success" -PropertyType string -Force | Out-Null
                          New-ItemProperty -Path $DockEssentialRegPath -Name 'InstalledPackageVersion' -Value $PackageVersion -PropertyType string -Force | Out-Null
                      }
                      else {
                          New-ItemProperty -Path $DockEssentialRegPath -Name 'ErrorCode' -Value $ExitInfo.Code -PropertyType dword -Force | Out-Null
                          New-ItemProperty -Path $DockEssentialRegPath -Name 'LastUpdateStatus' -Value "Fail" -PropertyType string -Force | Out-Null
                      }
                  }
                  else {
                      New-ItemProperty -Path $DockEssentialRegPath -Name 'LastUpdateStatus' -Value "UpdateRequired" -PropertyType string -Force | Out-Null

                  }
              }

          } #HP USB-C G5 Essential Dock

          #HP E24d G4 FHD Docking Monitor
          if ($Dock.Dock_ProductName -eq "HP E24d G4 FHD Docking Monitor"){
               [version]$Installed = $script:InstalledFirmwareVersion
               [version]$Available = $script:SoftPaqVersion
               if ($Available -gt $Installed){
                  $script:UpdateRequired = $true
               }
          } #HP E24d G4 FHD Docking Monitor

          # HP Thunderbolt Dock G2 Registry Items
          if ($Dock.Dock_ProductName -eq "HP Thunderbolt Dock G2"){
          $DockTB2RegPath = "$DockRegPath\HP Thunderbolt Dock G2"
              if (!(Test-Path -path $DockTB2RegPath)){
                  if (($DebugOut) -or ($Transcript)) {Write-Host " Creating $DockTB2RegPath Key" -ForegroundColor green}
                  New-Item -Path $DockTB2RegPath -Force | Out-Null
              }
              New-ItemProperty -Path $DockTB2RegPath -Name 'MACAddress' -Value $MACAddress -PropertyType string -Force | Out-Null
              if ($HPFirmwareTest.ExitCode -eq "0"){
                  New-ItemProperty -Path $DockTB2RegPath -Name 'LastUpdateStatus' -Value "Success" -PropertyType string -Force | Out-Null
              }
              elseif ($HPFirmwareTest.ExitCode -eq "105"){
                  if ($update) {
                      New-ItemProperty -Path $DockTB2RegPath -Name 'LastUpdateRun' -Value $(Get-Date -Format "yyyy/MM/dd HH:mm:ss") -PropertyType string -Force | Out-Null
                      if ($ExitInfo.Code -eq "0"){
                          New-ItemProperty -Path $DockTB2RegPath -Name 'LastUpdateStatus' -Value "Success" -PropertyType string -Force | Out-Null
                          #Run Check to update Current Registry Values
                          $HPFirmwareTest = Start-Process -FilePath "$OutFilePath\$SPNumber\$FirmwareInstallerName" -ArgumentList "-C" -PassThru -Wait -NoNewWindow
                      }
                      else {
                          New-ItemProperty -Path $DockTB2RegPath -Name 'LastUpdateStatus' -Value "Fail" -PropertyType string -Force | Out-Null
                      }
                  }
                  else {
                      if ($script:UpdateRequired -eq $true){
                          New-ItemProperty -Path $DockTB2RegPath -Name 'LastUpdateStatus' -Value "UpdateRequired" -PropertyType string -Force | Out-Null
                      }
                      else {
                          New-ItemProperty -Path $DockTB2RegPath -Name 'LastUpdateStatus' -Value "Success" -PropertyType string -Force | Out-Null
                          New-ItemProperty -Path $DockTB2RegPath -Name 'ErrorCode' -Value 0 -PropertyType dword -Force | Out-Null
                      }

                  }
              }
          }#HP Thunderbolt Dock G2
      } # if (Test-Path "$OutFilePath\$SPNumber\HPFirmwareInstaller.exe")
      if ($Transcript) {Stop-Transcript}
       $Return = @(
      @{Dock = "$($Dock.Dock_ProductName)"; InstalledFirmware = $script:InstalledFirmwareVersion ; SoftpaqFirmware = $script:SoftPaqVersion ; UpdateRequired = $script:UpdateRequired ; SoftpaqNumber = $SPNumber}
      )
      if (!($Update)){Return $Return}
      else {
          if (!(($DebugOut) -or ($Transcript))){Write-Output "$($ExitInfo.Message)"}
      }   
  }
}
