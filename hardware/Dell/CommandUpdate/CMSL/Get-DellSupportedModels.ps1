#https://dl.dell.com/content/manual13608255-dell-command-update-version-5-x-reference-guide.pdf?language=en-us


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
    $temproot = "$env:windir\temp"
    $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    $LogFilePath = "$env:ProgramData\CMSL\Logs"
    #$LogFile = "$LogFilePath\DCU-Install.log"
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    #$CabPathIndex = "$temproot\DellCabDownloads\CatalogIndexPC.cab"
    $CabPathIndexModel = "$temproot\DellCabDownloads\CatalogIndexModel.cab"
    $DellCabExtractPath = "$temproot\DellCabDownloads\DellCabExtract"
    $DCUVersionInstalled = Get-DCUVersion
    
    if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems"}
    
    #Create Folders
    if (!(Test-Path -Path $LogFilePath)){New-Item -Path $LogFilePath -ItemType Directory -Force | Out-Null}        
    if (!(Test-Path -Path $DellCabExtractPath)){New-Item -Path $DellCabExtractPath -ItemType Directory -Force | Out-Null}  
    
    $DellModelLatest = Get-DellSupportedModels | Where-Object {$_.URL -match "Latitude"} |  Sort-Object -Descending -Property Date | Select-Object -first 1 
    $DellSKU = Get-DellSupportedModels | Where-Object {$_.systemID -match $SystemSKUNumber} | Select-Object -First 1
    if (Test-Path $CabPathIndexModel){Remove-Item -Path $CabPathIndexModel -Force}
    Invoke-WebRequest -Uri "http://downloads.dell.com/$($DellModelLatest.URL)" -OutFile $CabPathIndexModel -UseBasicParsing
    if (Test-Path $CabPathIndexModel){
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
    $LogPath = "$env:SystemDrive\Users\Dell\CMSL\Logs"
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
    #Installation Deferral
    if ($installationDeferral){
        if ($installationDeferral -eq 'Enable'){
            $installationDeferralVar = "-installationDeferral=$installationDeferral"
            if ($deferralInstallInterval){
                $deferralInstallIntervalVar = "-deferralInstallInterval=$deferralInstallInterval"
            }
            else {
                $deferralInstallIntervalVar = "-deferralInstallInterval=5"
            }
            if ($deferralInstallCount){
                $deferralInstallCountVar = "-deferralInstallCount=$deferralInstallCount"
            }
            else {
                $deferralInstallCountVar = "-deferralInstallCount=5"
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
            $installationDeferralVar = "-installationDeferral=$installationDeferral"
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
                $deferralRestartIntervalVar = "-deferralRestartInterval=$deferralRestartInterval"
            }
            else {
                $deferralRestartIntervalVar = "-deferralRestartInterval=5"
            }
            if ($deferralRestartCount){
                $deferralRestartCountVar = "-deferralRestartCount=$deferralRestartCount"
            }
            else {
                $deferralRestartCountVar = "-deferralRestartCount=5"
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
            $systemRestartDeferralVar = "-systemRestartDeferral=$systemRestartDeferral"
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
}

function Invoke-DCU {
    [CmdletBinding()]
    
    param (

    [switch]$scan,
    [switch]$applyUpdates,
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
    [string]$forceupdate = 'Disable'
    
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
    if ($scan){$ActionVar = "/scan"}
    if ($applyUpdates){$ActionVar = "/applyUpdates"}
    else {$ActionVar = "/scan"}
    $Action = $ActionVar -replace "/",""



    $DateTimeStamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $ArgList = "$ActionVar $updateSeverityVar $updateTypeVar $updateDeviceCategoryVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-$Action.log`""
    Write-Verbose $ArgList
    $DCUApply = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
    if ($DCUApply.ExitCode -ne 0){
        $ExitInfo = Get-DCUExitInfo -DCUExit $DCUApply.ExitCode
        Write-Verbose "Exit: $($DCUApply.ExitCode)"
        Write-Verbose "Description: $($ExitInfo.Description)"
        Write-Verbose "Resolution: $($ExitInfo.Resolution)"
    }
}