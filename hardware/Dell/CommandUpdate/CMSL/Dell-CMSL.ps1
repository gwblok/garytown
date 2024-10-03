<#Gary Blok - @gwblok - GARYTOWN.COM
#https://dl.dell.com/content/manual13608255-dell-command-update-version-5-x-reference-guide.pdf?language=en-us

# Summary of Functions:

# 1. Get-DellSupportedModels:
#    - Retrieves a list of supported Dell models from the Dell Command Update XML catalog.
#    - Returns an array of objects containing system ID, model name, URL, and date.

# 2. Get-DCUVersion:
#    - Retrieves the version of Dell Command Update (DCU) installed on the system.
#    - Returns the DCU version as a string or $false if DCU is not installed.

# 3. Get-DCUInstallDetails:
#    - Retrieves installation details of Dell Command Update (DCU) from the registry.
#    - Returns an object containing version, app type (Universal or Classic), and DCU path.

# 4. Get-DCUExitInfo:
#    - Retrieves information about Dell Command Update (DCU) exit codes.
#    - Takes an optional parameter for the DCU exit code to get specific information.
#    - Returns an array of objects containing exit code, description, and resolution.

# 5. Install-DCU: 
#    - Downloads and installs the latest version of Dell Command Update (DCU) for the system.
#    - Checks for the latest DCU version available for the system model.
#    - Downloads the DCU installer and installs it silently.
#    - Displays information about the update if a new version is available.

# 6. Set-DCUSettings:
#    - Configures settings for Dell Command Update (DCU) using the dcu-cli.exe utility.
#    - Supports settings like advancedDriverRestore, autoSuspendBitLocker, installationDeferral, systemRestartDeferral, scheduleAction, and scheduleAuto.
#    - Writes logs for each configuration change.

# 7. Invoke-DCU:
#    - Invokes Dell Command Update (DCU) actions like scanning for updates or applying updates.
#    - Supports parameters for updateSeverity, updateType, updateDeviceCategory, autoSuspendBitLocker, reboot, forceupdate, scan, and applyUpdates.
#    - Builds the argument list based on the selected parameters and executes the DCU action.

# 8. Get-DCUUpdateList:
#    - Retrieves a list of available updates from Dell Command Update (DCU) for the system.
#    - Supports filtering by updateType, and updateDeviceCategory.
#    - Returns an array of objects containing update details like severity, type, category, name, and release date.

# 9. Get-DellDeviceDetails:
#    - Retrieves details of the Dell device like model, systemID.
#    - Supports filtering by systemID and model name


# Change Log

24.9.9.1 - Modified logic in Get-DellDeviceDetails to allow it to work on non-dell devices when you provide a SKU or Model Name

#>
$ScriptVersion = '24.10.3.2'
Write-Output "Dell Command Update Functions Loaded - Version $ScriptVersion"
function Get-DellSupportedModels {
    [CmdletBinding()]
    
    $CabPathIndex = "$env:ProgramData\CMSL\DellCabDownloads\CatalogIndexPC.cab"
    $DellCabExtractPath = "$env:ProgramData\CMSL\DellCabDownloads\DellCabExtract"
    
    # Pull down Dell XML CAB used in Dell Command Update ,extract and Load
    if (!(Test-Path $DellCabExtractPath)){$null = New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
    Write-Verbose "Downloading Dell Cab"
    Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/CatalogIndexPC.cab" -OutFile $CabPathIndex -UseBasicParsing -Proxy $ProxyServer
    If(Test-Path "$DellCabExtractPath\DellSDPCatalogPC.xml"){Remove-Item -Path "$DellCabExtractPath\DellSDPCatalogPC.xml" -Force}
    Start-Sleep -Seconds 1
    if (test-path $DellCabExtractPath){Remove-Item -Path $DellCabExtractPath -Force -Recurse}
    $null = New-Item -Path $DellCabExtractPath -ItemType Directory
    Write-Verbose "Expanding the Cab File..." 
    $null = expand $CabPathIndex $DellCabExtractPath\CatalogIndexPC.xml
    
    Write-Verbose "Loading Dell Catalog XML.... can take awhile"
    [xml]$XMLIndex = Get-Content "$DellCabExtractPath\CatalogIndexPC.xml"
    
    
    $SupportedModels = $XMLIndex.ManifestIndex.GroupManifest
    $SupportedModelsObject = @()
    foreach ($SupportedModel in $SupportedModels){
        $SPInventory = New-Object -TypeName PSObject
        $SPInventory | Add-Member -MemberType NoteProperty -Name "SystemID" -Value "$($SupportedModel.SupportedSystems.Brand.Model.systemID)" -Force
        $SPInventory | Add-Member -MemberType NoteProperty -Name "Model" -Value "$($SupportedModel.SupportedSystems.Brand.Model.Display.'#cdata-section')"  -Force
        $SPInventory | Add-Member -MemberType NoteProperty -Name "URL" -Value "$($SupportedModel.ManifestInformation.path)" -Force
        $SPInventory | Add-Member -MemberType NoteProperty -Name "Date" -Value "$($SupportedModel.ManifestInformation.version)" -Force		
        $SupportedModelsObject += $SPInventory 
    }
    return $SupportedModelsObject
}

Function Get-DCUVersion {
    $DCU=(Get-ItemProperty "HKLM:\SOFTWARE\Dell\UpdateService\Clients\CommandUpdate\Preferences\Settings" -ErrorVariable err -ErrorAction SilentlyContinue)
    if ($err.Count -eq 0) {
        $DCU = $DCU.ProductVersion
    }else{
        $DCU = $false
    }
    return $DCU
}
Function Get-DCUInstallDetails {
    #Declare Variables for Universal app if RegKey AppCode is Universal or if Regkey AppCode is Classic and declares their variables otherwise reports not installed
    If((Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name AppCode -ErrorAction SilentlyContinue) -eq "Universal"){
        $Version = Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name ProductVersion -ErrorAction SilentlyContinue
        $AppType = Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name AppCode -ErrorAction SilentlyContinue
        #Add DCU-CLI.exe as Environment Variable for Universal app type
        $DCUPath = 'C:\Program Files\Dell\CommandUpdate\'
    }
    ElseIf((Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name AppCode -ErrorAction SilentlyContinue) -eq "Classic"){
        
        $Version = Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name ProductVersion
        $AppType = Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name AppCode
        #Add DCU-CLI.exe as Environment Variable for Classic app type
        $DCUPath = 'C:\Program Files (x86)\Dell\CommandUpdate\'
    }
    Else{
        $DCU =  "DCU is not installed"
    }
    if ($Version){
        $DCU = [PSCustomObject]@{
            Version = $Version
            AppType = $AppType
            DCUPath = $DCUPath
        }
    }
    return $DCU
}

#https://www.dell.com/support/manuals/en-us/command-update/dellcommandupdate_rg/command-line-interface-error-codes?guid=guid-fbb96b06-4603-423a-baec-cbf5963d8948&lang=en-us
Function Get-DCUExitInfo {
    [CmdletBinding()]
    param(
        [ValidateRange(0,4000)]
        [int]$DCUExit
    )
    $DCUExitInfo = @(
        @{ExitCode = 2; Description = "None"; Resolution = "None"}
        # Generic application return codes
        @{ExitCode = 0; Description = "Success"; Resolution = "The operation completed successfully."}
        @{ExitCode = 1; Description = "A reboot was required from the execution of an operation."; Resolution = "Reboot the system to complete the operation."}
        @{ExitCode = 2; Description = "An unknown application error has occurred."; Resolution = "None"}
        @{ExitCode = 3; Description = "The current system manufacturer is not Dell."; Resolution = "Dell Command | Update can only be run on Dell systems."}
        @{ExitCode = 4; Description = "The CLI was not launched with administrative privilege"; Resolution = "Invoke the Dell Command | Update CLI with administrative privileges"}
        @{ExitCode = 5; Description = "A reboot was pending from a previous operation."; Resolution = "Reboot the system to complete the operation."}
        @{ExitCode = 6; Description = "Another instance of the same application (UI or CLI) is already running."; Resolution = "Close any running instance of Dell Command | Update UI or CLI and retry the operation."}
        @{ExitCode = 7; Description = "The application does not support the current system model."; Resolution = "Contact your administrator if the current system model in not supported by the catalog."}
        @{ExitCode = 8; Description = "No update filters have been applied or configured."; Resolution = "Supply at least one update filter."}
        # Return codes while evaluating various input validations
        @{ExitCode = 100; Description = "While evaluating the command line parameters, no parameters were detected."; Resolution = "A command must be specified on the command line."}
        @{ExitCode = 101; Description = "While evaluating the command line parameters, no commands were detected."; Resolution = "Provide a valid command and options."}
        @{ExitCode = 102; Description = "While evaluating the command line parameters, invalid commands were detected."; Resolution = "Provide a command along with the supported options for that command"}
        @{ExitCode = 103; Description = "While evaluating the command line parameters, duplicate commands were detected."; Resolution = "Remove any duplicate commands and rerun the command."}
        @{ExitCode = 104; Description = "While evaluating the command line parameters, the command syntax was incorrect."; Resolution = "Ensure that you follow the command syntax: /<command name>. "}
        @{ExitCode = 105; Description = "While evaluating the command line parameters, the option syntax was incorrect."; Resolution = "Ensure that you follow the option syntax: -<option name>."}
        @{ExitCode = 106; Description = "While evaluating the command line parameters, invalid options were detected."; Resolution = "Ensure to provide all required or only supported options."}
        @{ExitCode = 107; Description = "While evaluating the command line parameters, one or more values provided to the specific option was invalid."; Resolution = "Provide an acceptable value."}
        @{ExitCode = 108; Description = "While evaluating the command line parameters, all mandatory options were not detected."; Resolution = "If a command requires mandatory options to run, provide them."}
        @{ExitCode = 109; Description = "While evaluating the command line parameters, invalid combination of options were detected."; Resolution = "Remove any mutually exclusive options and rerun the command."}
        @{ExitCode = 110; Description = "While evaluating the command line parameters, multiple commands were detected."; Resolution = "Except for /help and /version, only one command can be specified in the command line."}
        @{ExitCode = 111; Description = "While evaluating the command line parameters, duplicate options were detected."; Resolution = "Remove any duplicate options and rerun the command"}
        @{ExitCode = 112; Description = "An invalid catalog was detected."; Resolution = "Ensure that the file path provided exists, has a valid extension type, is a valid SMB, UNC, or URL, does not have invalid characters, does not exceed 255 characters and has required permissions. "}
        @{ExitCode = 113; Description = "While evaluating the command line parameters, one or more values provided exceeds the length limit."; Resolution = "Ensure to provide the values of the options within the length limit."}
        # Return codes while running the /scan command
        @{ExitCode = 500; Description = "No updates were found for the system when a scan operation was performed."; Resolution = "The system is up to date or no updates were found for the provided filters. Modify the filters and rerun the commands."}
        @{ExitCode = 501; Description = "An error occurred while determining the available updates for the system, when a scan operation was performed."; Resolution = "Retry the operation."}
        @{ExitCode = 502; Description = "The cancellation was initiated, Hence, the scan operation is canceled."; Resolution = "Retry the operation."}
        @{ExitCode = 503; Description = "An error occurred while downloading a file during the scan operation."; Resolution = "Check your network connection, ensure there is Internet connectivity and Retry the command."}
        # Return codes while running the /applyUpdates command
        @{ExitCode = 1000; Description = "An error occurred when retrieving the result of the apply updates operation."; Resolution = "Retry the operation."}
        @{ExitCode = 1001; Description = "The cancellation was initiated, Hence, the apply updates operation is canceled."; Resolution = "Retry the operation."}
        @{ExitCode = 1002; Description = "An error occurred while downloading a file during the apply updates operation."; Resolution = "Check your network connection, ensure there is Internet connectivity, and retry the command."}
        # Return codes while running the /configure command
        @{ExitCode = 1505; Description = "An error occurred while exporting the application settings."; Resolution = "Verify that the folder exists or have permissions to write to the folder."}
        @{ExitCode = 1506; Description = "An error occurred while importing the application settings."; Resolution = "Verify that the imported file is valid."}
        # Return codes while running the /driverInstall command
        @{ExitCode = 2000; Description = "An error occurred when retrieving the result of the Advanced Driver Restore operation."; Resolution = "Retry the operation."}
        @{ExitCode = 2001; Description = "The Advanced Driver Restore process failed."; Resolution = "Retry the operation."}
        @{ExitCode = 2002; Description = "Multiple driver CABs were provided for the Advanced Driver Restore operation."; Resolution = "Ensure that you provide only one driver CAB file."}
        @{ExitCode = 2003; Description = "An invalid path for the driver CAB was provided as in input for the driver install command."; Resolution = "Ensure that the file path provided exists, has a valid extension type, is a valid SMB, UNC, or URL, does not have invalid characters, does not exceed 255 characters and has required permissions"}
        @{ExitCode = 2004; Description = "The cancellation was initiated, Hence, the driver install operation is canceled."; Resolution = "Retry the operation."}
        @{ExitCode = 2005; Description = "An error occurred while downloading a file during the driver install operation."; Resolution = "Check your network connection, ensure there is Internet connectivity, and retry the command."}
        @{ExitCode = 2006; Description = "Indicates that the Advanced Driver Restore feature is disabled."; Resolution = "Enable the feature using /configure -advancedDriverRestore=enable"}
        @{ExitCode = 2007; Description = "Indicates that the Advanced Diver Restore feature is not supported."; Resolution = "Disable FIPS mode on the system."}
        # Return codes while evaluating the inputs for password encryption
        @{ExitCode = 2500; Description = "An error occurred while encrypting the password during the generate encrypted password operation."; Resolution = "Retry the operation."}
        @{ExitCode = 2501; Description = "An error occurred while encrypting the password with the encryption key provided."; Resolution = "Provide a valid encryption key and Retry the operation. "}
        @{ExitCode = 2502; Description = "The encrypted password provided does not match the current encryption method."; Resolution = "The provided encrypted password used an older encryption method. Reencrypt the password."}
        # Return codes if there are issues with the Dell Client Management Service
        @{ExitCode = 3000; Description = "The Dell Client Management Service is not running."; Resolution = "Start the Dell Client Management Service in the Windows services if stopped."}
        @{ExitCode = 3001; Description = "The Dell Client Management Service is not installed."; Resolution = "Download and install the Dell Client Management Service from the Dell support site."}
        @{ExitCode = 3002; Description = "The Dell Client Management Service is disabled."; Resolution = "Enable the Dell Client Management Service from Windows services if disabled."}
        @{ExitCode = 3003; Description = "The Dell Client Management Service is busy."; Resolution = "Wait until the service is available to process new requests."}
        @{ExitCode = 3004; Description = "The Dell Client Management Service has initiated a self-update install of the application."; Resolution = "Wait until the service is available to process new requests."}
        @{ExitCode = 3005; Description = "The Dell Client Management Service is installing pending updates."; Resolution = "Wait until the service is available to process new requests."}
    )
    $DCUExitInfo | Where-Object {$_.ExitCode -eq $DCUExit}
}
Function Install-DCU {
    [CmdletBinding()]
    param()
    $temproot = "$env:windir\temp"
    
    $LogFilePath = "$env:ProgramData\CMSL\Logs"
    #$LogFile = "$LogFilePath\DCU-Install.log"
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    #$CabPathIndex = "$temproot\DellCabDownloads\CatalogIndexPC.cab"
    $CabPathIndexModel = "$temproot\DellCabDownloads\CatalogIndexModel.cab"
    $DellCabExtractPath = "$temproot\DellCabDownloads\DellCabExtract"
    if (!(Test-Path $DellCabExtractPath)){$null = New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
    $DCUVersionInstalled = Get-DCUVersion
    
    if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems"}
    
    #Create Folders
    Write-Verbose "Creating Folders"
    if (!(Test-Path -Path $LogFilePath)){New-Item -Path $LogFilePath -ItemType Directory -Force | Out-Null}        
    if (!(Test-Path -Path $DellCabExtractPath)){New-Item -Path $DellCabExtractPath -ItemType Directory -Force | Out-Null}  
    
    #Write-Verbose "Using Dell Catalog to get Latest DCU Version - Generic"
    #$DellSKU = Get-DellSupportedModels | Where-Object {$_.URL -match "Latitude"} |  Sort-Object -Descending -Property Date | Select-Object -first 1
    
    $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    Write-Verbose "Using Dell Catalog to get Latest DCU Version - $SystemSKUNumber"
    $DellSKU = Get-DellSupportedModels | Where-Object {$_.systemID -match $SystemSKUNumber} | Select-Object -First 1
    Write-Verbose "Using Catalog from $($DellSKU.Model)"
    if (Test-Path $CabPathIndexModel){Remove-Item -Path $CabPathIndexModel -Force}
    Invoke-WebRequest -Uri "http://downloads.dell.com/$($DellSKU.URL)" -OutFile $CabPathIndexModel -UseBasicParsing

    if (Test-Path $CabPathIndexModel){
        Write-Verbose "Extracting Dell Catalog"
        $null = expand $CabPathIndexModel $DellCabExtractPath\CatalogIndexPCModel.xml
        [xml]$XMLIndexCAB = Get-Content "$DellCabExtractPath\CatalogIndexPCModel.xml"
        
        $DCUAppsAvailable = $XMLIndexCAB.Manifest.SoftwareComponent | Where-Object {$_.ComponentType.value -eq "APAC"}
        #$AppNames = $DCUAppsAvailable.name.display.'#cdata-section' | Select-Object -Unique
        
        #Using Universal Version:
        $AppDCUVersion = ([Version[]]$Version = ($DCUAppsAvailable | Where-Object {$_.path -match 'command-update' -and $_.SupportedOperatingSystems.OperatingSystem.osArch -match "x64" -and $_.path -match 'universal'}).vendorVersion) | Sort-Object | Select-Object -Last 1
        $AppDCU = $DCUAppsAvailable | Where-Object {$_.path -match 'command-update' -and $_.SupportedOperatingSystems.OperatingSystem.osArch -match "x64" -and $_.path -match 'universal' -and $_.vendorVersion -eq $AppDCUVersion}
        if ($AppDCU.Count -gt 1){
            $AppDCU = $AppDCU | Select-Object -First 1
        }
        if ($AppDCU){
            Write-Verbose $AppDCU
            $DellItem = $AppDCU
            If ($DCUVersionInstalled -ne $false){[Version]$CurrentVersion = $DCUVersionInstalled.Version}
            Else {[Version]$CurrentVersion = 0.0.0.0}
            [Version]$DCUVersion = $DellItem.vendorVersion
            #$DCUReleaseDate = $(Get-Date $DellItem.releaseDate -Format 'yyyy-MM-dd')
            $DCUReleaseDate = $($DellItem.releaseDate)              
            $TargetLink = "http://downloads.dell.com/$($DellItem.path)"
            $TargetFileName = ($DellItem.path).Split("/") | Select-Object -Last 1
            if ($DCUVersion -gt $CurrentVersion){
                if ($CurrentVersion -eq 0.0.0.0){[String]$CurrentVersion = "Not Installed"}
                Write-Output "New Update available: Installed = $CurrentVersion DCU = $DCUVersion"
                Write-Output "Title: $($DellItem.Name.Display.'#cdata-section')"
                Write-Output "----------------------------"
                Write-Output "Severity: $($DellItem.Criticality.Display.'#cdata-section')"
                Write-Output "FileName: $TargetFileName"
                Write-Output "Release Date: $DCUReleaseDate"
                Write-Output "KB: $($DellItem.releaseID)"
                Write-Output "Link: $TargetLink"
                Write-Output "Info: $($DellItem.ImportantInfo.URL)"
                Write-Output "Version: $DCUVersion "
                
                #Build Required Info to Download and Update CM Package
                $TargetFilePathName = "$($DellCabExtractPath)\$($TargetFileName)"
                #Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Verbose
                Start-BitsTransfer -Source $TargetLink -Destination $TargetFilePathName -DisplayName $TargetFileName -Description "Downloading Dell Command Update" -Priority Low -ErrorVariable err -ErrorAction SilentlyContinue
                if (!(Test-Path $TargetFilePathName)){
                    Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Verbose
                }
                #Confirm Download
                if (Test-Path $TargetFilePathName){
                    $LogFileName = $TargetFilePathName.replace(".exe",".log")
                    $Arguments = "/s /l=$LogFileName"
                    Write-Output "Starting Update"
                    write-output "Log file = $LogFileName"
                    $Process = Start-Process "$TargetFilePathName" $Arguments -Wait -PassThru
                    write-output "Update Complete with Exitcode: $($Process.ExitCode)"
                    If($Process -ne $null -and $Process.ExitCode -eq '2'){
                        Write-Verbose "Reboot Required"
                    }
                }
                else{
                    Write-Verbose " FAILED TO DOWNLOAD DCU"
                }
            }
        }
        else {
            Write-Verbose "No DCU Update Available"
        }
    }
}

function Set-DCUSettings {
    [CmdletBinding()]
    
    param (
    [ValidateSet('Enable','Disable')]
    [string]$advancedDriverRestore,
    [ValidateSet('Enable','Disable')]
    [string]$autoSuspendBitLocker = 'Enable',
    [ValidateSet('Enable','Disable')]
    [string]$installationDeferral,
    [ValidateRange(0,99)]
    [int]$deferralInstallInterval = 3,
    [ValidateRange(0,9)]
    [int]$deferralInstallCount = 5,

    [ValidateSet('Enable','Disable')]
    [string]$systemRestartDeferral,
    [ValidateRange(0,99)]
    [int]$deferralRestartInterval = 3,
    [ValidateRange(0,9)]
    [int]$deferralRestartCount = 5,


    #[ValidateSet('Enable','Disable')]
    #[string]$reboot = 'Disable',
    [ValidateSet('NotifyAvailableUpdates','DownloadAndNotify','DownloadInstallAndNotify')]
    [string]$scheduleAction = 'DownloadInstallAndNotify',
    [switch]$scheduleAuto    
    )
    
    $DCUPath = (Get-DCUInstallDetails).DCUPath
    Write-Verbose "DCU Path: $DCUPath"
    $LogPath = "$env:SystemDrive\Users\Dell\CMSL\Logs"
    Write-Verbose "Log Path: $LogPath"
    $DateTimeStamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $ArgList = "$ActionVar $updateSeverityVar $updateTypeVar $updateDeviceCategoryVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-$Action.log`""

    if ($advancedDriverRestore){
        $advancedDriverRestoreVar = "-advancedDriverRestore=$advancedDriverRestore -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-advancedDriverRestore.log`""
        $ArgList = "/configure $advancedDriverRestoreVar"
        Write-Verbose $ArgList
        $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
        if ($DCUConfig.ExitCode -ne 0){
            $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
            Write-Verbose "Exit: $($DCUConfig.ExitCode)"
            Write-Verbose "Description: $($ExitInfo.Description)"
            Write-Verbose "Resolution: $($ExitInfo.Resolution)"
        }
    }
    if ($autoSuspendBitLocker){ 
        $autoSuspendBitLockerVar = "-autoSuspendBitLocker=$autoSuspendBitLocker -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-autoSuspendBitLocker.log`""
        $ArgList = "/configure $autoSuspendBitLockerVar"
        Write-Verbose $ArgList
        $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
        if ($DCUConfig.ExitCode -ne 0){
            $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
            Write-Verbose "Exit: $($DCUConfig.ExitCode)"
            Write-Verbose "Description: $($ExitInfo.Description)"
            Write-Verbose "Resolution: $($ExitInfo.Resolution)"
        }
    }
    if ($scheduleAction){
        $scheduleActionVar = "-scheduleAction=$scheduleAction"
        $ArgList = "/configure $scheduleActionVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-scheduleAction.log`""
        Write-Verbose $ArgList
        $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
        if ($DCUConfig.ExitCode -ne 0){
            $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
            Write-Verbose "Exit: $($DCUConfig.ExitCode)"
            Write-Verbose "Description: $($ExitInfo.Description)"
            Write-Verbose "Resolution: $($ExitInfo.Resolution)"
        }
    }
    if ($scheduleAuto){
        $scheduleAutoVar = "-scheduleAuto"
        $ArgList = "/configure $scheduleAutoVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-scheduleAuto.log`""
        Write-Verbose $ArgList
        $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
        if ($DCUConfig.ExitCode -ne 0){
            $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
            Write-Verbose "Exit: $($DCUConfig.ExitCode)"
            Write-Verbose "Description: $($ExitInfo.Description)"
            Write-Verbose "Resolution: $($ExitInfo.Resolution)"
        }
    }
    #Installation Deferral
    if ($installationDeferral){
        if ($installationDeferral -eq 'Enable'){
            $installationDeferralVar = "-installationDeferral=$installationDeferral"
            if ($deferralInstallInterval){
                [string]$deferralInstallIntervalVar = "-deferralInstallInterval=$deferralInstallInterval"
            }
            else {
                [string]$deferralInstallIntervalVar = "-deferralInstallInterval=5"
            }
            if ($deferralInstallCount){
                [string]$deferralInstallCountVar = "-deferralInstallCount=$deferralInstallCount"
            }
            else {
                [string]$deferralInstallCountVar = "-deferralInstallCount=5"
            }
            $ArgList = "/configure $installationDeferralVar $deferralInstallIntervalVar $deferralInstallCountVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-installationDeferral.log`""
            Write-Verbose $ArgList
            $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
            if ($DCUConfig.ExitCode -ne 0){
                $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
                Write-Verbose "Exit: $($DCUConfig.ExitCode)"
                Write-Verbose "Description: $($ExitInfo.Description)"
                Write-Verbose "Resolution: $($ExitInfo.Resolution)"
            }
            
        }
        else {
            [string]$installationDeferralVar = "-installationDeferral=$installationDeferral"
            $ArgList = "/configure $installationDeferralVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-installationDeferral.log`""
            Write-Verbose $ArgList
            $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
            if ($DCUConfig.ExitCode -ne 0){
                $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
                Write-Verbose "Exit: $($DCUConfig.ExitCode)"
                Write-Verbose "Description: $($ExitInfo.Description)"
                Write-Verbose "Resolution: $($ExitInfo.Resolution)"
            }
        }
    }
    #System Reboot Deferral
    if ($systemRestartDeferral){
        if ($systemRestartDeferral -eq 'Enable'){
            $systemRestartDeferralVar = "-systemRestartDeferral=$systemRestartDeferral"
            if ($deferralRestartInterval){
                [string]$deferralRestartIntervalVar = "-deferralRestartInterval=$deferralRestartInterval"
            }
            else {
                [string]$deferralRestartIntervalVar = "-deferralRestartInterval=5"
            }
            if ($deferralRestartCount){
                [string]$deferralRestartCountVar = "-deferralRestartCount=$deferralRestartCount"
            }
            else {
                [string]$deferralRestartCountVar = "-deferralRestartCount=5"
            }
            $ArgList = "/configure $systemRestartDeferralVar $deferralRestartIntervalVar $deferralRestartCountVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-RestartDeferral.log`""
            Write-Verbose $ArgList
            $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
            if ($DCUConfig.ExitCode -ne 0){
                $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
                Write-Verbose "Exit: $($DCUConfig.ExitCode)"
                Write-Verbose "Description: $($ExitInfo.Description)"
                Write-Verbose "Resolution: $($ExitInfo.Resolution)"
            }
            
        }
        else {
            [string]$systemRestartDeferralVar = "-systemRestartDeferral=$systemRestartDeferral"
            $ArgList = "/configure $systemRestartDeferralVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-RestartDeferral.log`""
            Write-Verbose $ArgList
            $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
            if ($DCUConfig.ExitCode -ne 0){
                $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
                Write-Verbose "Exit: $($DCUConfig.ExitCode)"
                Write-Verbose "Description: $($ExitInfo.Description)"
                Write-Verbose "Resolution: $($ExitInfo.Resolution)"
            }
        }
    }

}

function Invoke-DCU {
    [CmdletBinding()]
    
    param (
    [ValidateSet('security','critical','recommended','optional')]
    [String[]]$updateSeverity,
    [ValidateSet('bios','firmware','driver','application','others')]
    [String[]]$updateType,
    [ValidateSet('audio','video','network','chipset','storage','input','others')]
    [String[]]$updateDeviceCategory,
    [ValidateSet('Enable','Disable')]
    [string]$autoSuspendBitLocker = 'Enable',
    [ValidateSet('Enable','Disable')]
    [string]$reboot = 'Disable',
    [ValidateSet('Enable','Disable')]
    [string]$forceupdate = 'Disable',
    [switch]$scan,
    [switch]$applyUpdates
    )
    $DCUPath = (Get-DCUInstallDetails).DCUPath
    $LogPath = "$env:SystemDrive\Users\Dell\CMSL\Logs"
    #Build Argument Strings for each parameter
    if ($updateSeverity){
        [String]$updateSeverity = $($updateSeverity -join ",").ToString()
        $updateSeverityVar = "-updateSeverity=$updateSeverity"
    }
    if ($updateType){
        [String]$updateType = $($updateType -join ",").ToString()
        $updateTypeVar = "-updateType=$updateType"
    }
    if ($updateDeviceCategory){
        [String]$updateDeviceCategory = $($updateDeviceCategory -join ",").ToString()
        $updateDeviceCategoryVar = "-updateDeviceCategory=$updateDeviceCategory"
    }

    #Pick Action, Scan or ApplyUpdates if both are selected, ApplyUpdates will be the action, if neither are selected, Scan will be the action
    $DateTimeStamp = Get-Date -Format "yyyyMMdd-HHmmss"
    if ($scan){$ActionVar = "/scan"}
    if ($applyUpdates){$ActionVar = "/applyUpdates"}
    else {$ActionVar = "/scan"}
    $Action = $ActionVar -replace "/",""

    #Create Arugment List for Dell Command Update CLI
    $ArgList = "$ActionVar $updateSeverityVar $updateTypeVar $updateDeviceCategoryVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-$Action.log`" -report=$LogPath"
    Write-Verbose $ArgList
    $DCUApply = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
    if ($DCUApply.ExitCode -ne 0){
        $ExitInfo = Get-DCUExitInfo -DCUExit $DCUApply.ExitCode
        Write-Verbose "Exit: $($DCUApply.ExitCode)"
        Write-Verbose "Description: $($ExitInfo.Description)"
        Write-Verbose "Resolution: $($ExitInfo.Resolution)"
    }
}

function Invoke-DCUBITS {
    [CmdletBinding()]
    
    param (
    [ValidateSet('security','critical','recommended','optional')]
    [String[]]$updateSeverity,
    [ValidateSet('bios','firmware','driver','application','others')]
    [String[]]$updateType,
    [ValidateSet('audio','video','network','chipset','storage','input','others')]
    [String[]]$updateDeviceCategory,
    [ValidateSet('Enable','Disable')]
    [string]$autoSuspendBitLocker = 'Enable',
    [ValidateSet('Enable','Disable')]
    [string]$reboot = 'Disable',
    [ValidateSet('Enable','Disable')]
    [string]$forceupdate = 'Disable',
    [switch]$scan,
    [switch]$applyUpdates,
    [switch]$DownloadOnly
    )
    $DCUPath = (Get-DCUInstallDetails).DCUPath
    $LogPath = "$env:SystemDrive\Users\Dell\CMSL\Logs"
    $DownloadPath = "$env:SystemDrive\Users\Dell\CMSL\Downloads"
    $DellDLRootURL = "https://dl.dell.com"
    [void][System.IO.Directory]::CreateDirectory($LogPath)
    [void][System.IO.Directory]::CreateDirectory($DownloadPath)

    #Build Argument Strings for each parameter
    if ($updateSeverity){
        [String]$updateSeverity = $($updateSeverity -join ",").ToString()
        $updateSeverityVar = "-updateSeverity=$updateSeverity"
    }
    if ($updateType){
        [String]$updateType = $($updateType -join ",").ToString()
        $updateTypeVar = "-updateType=$updateType"
    }
    if ($updateDeviceCategory){
        [String]$updateDeviceCategory = $($updateDeviceCategory -join ",").ToString()
        $updateDeviceCategoryVar = "-updateDeviceCategory=$updateDeviceCategory"
    }

    #Pick Action, Scan or ApplyUpdates if both are selected, ApplyUpdates will be the action, if neither are selected, Scan will be the action
    $DateTimeStamp = Get-Date -Format "yyyyMMdd-HHmmss"
    #Set Everything to SCAN so DCU will scan and create the report which we'll then go through and download the updates or install them
    if ($scan){$ActionVar = "/scan"}
    if ($DownloadOnly){$ActionVar = "/scan"}
    if ($applyUpdates){$ActionVar = "/scan"}
    else {$ActionVar = "/scan"}
    $Action = $ActionVar -replace "/",""

    #Create Arugment List for Dell Command Update CLI
    $ArgList = "$ActionVar $updateSeverityVar $updateTypeVar $updateDeviceCategoryVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-$Action.log`" -report=$LogPath"
    Write-Verbose $ArgList
    $DCUApply = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
    if ($DCUApply.ExitCode -ne 0){
        $ExitInfo = Get-DCUExitInfo -DCUExit $DCUApply.ExitCode
        Write-Verbose "Exit: $($DCUApply.ExitCode)"
        Write-Verbose "Description: $($ExitInfo.Description)"
        Write-Verbose "Resolution: $($ExitInfo.Resolution)"
    }
    #If DCU was to SCAN, then we're done!
    if ($scan){return}

    #Start to download
    if (Test-Path -Path $LogPath\DCUApplicableUpdates.xml){
        [xml]$DCUApplicableUpdates = Get-Content -Path $LogPath\DCUApplicableUpdates.xml
        $Updates = $DCUApplicableUpdates.updates.update
        foreach ($Update in $Updates){
            $URL = "$DellDLRootURL/$($Update.file)"
            $Description = "$($Update.version) from $($update.date) | Type: $($Update.type) | Category: $($update.category) | Severity: $($Update.urgency)"
            Write-Host "Downloading $URL"
            $Transfer = Start-BitsTransfer -DisplayName $Update.name -Source $URL -Destination $DownloadPath -Description $Description  -RetryInterval 60  -Verbose #-CustomHeaders "User-Agent:Bob"
        }

    }
    else {
        Write-Verbose "No Applicable Updates Found"
        return
    }
}

function  Get-DCUUpdateList {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False)]
        [ValidateLength(4,4)]    
        [string]$SystemSKUNumber,
        [ValidateSet('bios','firmware','driver','application')]
        [String[]]$updateType,
        [ValidateSet('audio','video','network','chipset','storage','BIOS','Application')]
        [String[]]$updateDeviceCategory,
        [switch]$RAWXML,
        [switch]$Latest,
        [switch]$TLDR
    )

    
    $temproot = "$env:windir\temp"
    #$SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    $CabPathIndexModel = "$temproot\DellCabDownloads\CatalogIndexModel.cab"
    $DellCabExtractPath = "$temproot\DellCabDownloads\DellCabExtract"
    if (!(Test-Path $DellCabExtractPath)){$null = New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
    
    
    if (!($SystemSKUNumber)) {
        if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems"}
        $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    }
    $DellSKU = Get-DellSupportedModels | Where-Object {$_.systemID -match $SystemSKUNumber} | Select-Object -First 1
    if (!($DellSKU)){
        return "System SKU not found"
    }
    if (Test-Path $CabPathIndexModel){Remove-Item -Path $CabPathIndexModel -Force}
    

    Invoke-WebRequest -Uri "http://downloads.dell.com/$($DellSKU.URL)" -OutFile $CabPathIndexModel -UseBasicParsing
    if (Test-Path $CabPathIndexModel){
        $null = expand $CabPathIndexModel $DellCabExtractPath\CatalogIndexPCModel.xml
        [xml]$XMLIndexCAB = Get-Content "$DellCabExtractPath\CatalogIndexPCModel.xml"
        
        #DCUAppsAvailable = $XMLIndexCAB.Manifest.SoftwareComponent | Where-Object {$_.ComponentType.value -eq "APAC"}
        #$AppNames = $DCUAppsAvailable.name.display.'#cdata-section' | Select-Object -Unique
        $BaseURL = "https://$($XMLIndexCAB.Manifest.baseLocation)"
        $Components = $XMLIndexCAB.Manifest.SoftwareComponent
        if ($RAWXML){
            return $Components
        }
        $ComponentsObject = @()
        foreach ($Component in $Components){
            $Item = New-Object -TypeName PSObject
            $Item | Add-Member -MemberType NoteProperty -Name "PackageID" -Value "$($Component.packageID)"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "Category" -Value "$($Component.Category.Display.'#cdata-section')"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "Type" -Value "$($component.ComponentType.Display.'#cdata-section')"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "Name" -Value "$($Component.Name.Display.'#cdata-section')" -Force
            $Item | Add-Member -MemberType NoteProperty -Name "ReleaseDate" -Value $([DateTime]($Component.releaseDate)) -Force
            $Item | Add-Member -MemberType NoteProperty -Name "DellVersion" -Value "$($Component.dellVersion)"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "VendorVersion" -Value "$($Component.vendorVersion)"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "PackageType" -Value "$($Component.packageType)"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "Path" -Value "$BaseURL/$($Component.path)" -Force		
            $Item | Add-Member -MemberType NoteProperty -Name "Description" -Value "$($component.Description.Display.'#cdata-section')" -Force		
            $ComponentsObject += $Item 
        }
        if ($updateType){
            $ComponentsObject = $ComponentsObject | Where-Object {$_.Type -in $updateType}
        }
        if ($updateDeviceCategory){
            $ComponentsObject = $ComponentsObject | Where-Object {$_.Category -in $updateDeviceCategory}
        }
        if ($TLDR) {
            $ComponentsObject = $ComponentsObject | Select-Object -Property Name,ReleaseDate,DellVersion,Path
        }
        if ($Latest){
            $ComponentsObject = $ComponentsObject | Sort-Object -Property ReleaseDate -Descending
            $hash = @{}
            foreach ($ComponentObject in $ComponentsObject) {
                if (-not $hash.ContainsKey($ComponentObject.Name)) {
                    $hash[$ComponentObject.Name] = $ComponentObject
                }
            }
            $ComponentsObject = $hash.Values 
        }
        return $ComponentsObject
    }
}

function Get-DellDeviceDetails {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False)]
        [ValidateLength(4,4)]    
        [string]$SystemSKUNumber,
        [string]$ModelLike
    )
    
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    
    if ((!($SystemSKUNumber)) -and (!($ModelLike))) {
        if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems"}
        $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    }

    if (!($ModelLike)){
        $DellSKU = Get-DellSupportedModels | Where-Object {$_.systemID -match $SystemSKUNumber} | Select-Object -First 1
    }
    else {
        $DellSKU = Get-DellSupportedModels | Where-Object { $_.Model -match $ModelLike}
    }
    return $DellSKU | Select-Object -Property SystemID,Model
}
