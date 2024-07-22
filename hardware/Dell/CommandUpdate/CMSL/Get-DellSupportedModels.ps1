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

Function Install-DCU {
    
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
                Write-Output "----------------------------" -ForegroundColor Cyan
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
    

    param (
        [ValidateSet('Enable','Disable')]
        [string]$advancedDriverRestore,
        [ValidateSet('Enable','Disable')]
        [string]$autoSuspendBitLocker = 'Enable',
        [ValidateSet('Enable','Disable')]
        [string]$installationDeferral = 'Enable',
        [ValidateRange(0,99)]
        [int]$deferralInstallInterval = 3,
        [ValidateRange(0,9)]
        [int]$deferralInstallCount = 5,
        #[ValidateSet('Enable','Disable')]
        #[string]$reboot = 'Disable',
        [ValidateSet('NotifyAvailableUpdates','DownloadAndNotify','DownloadInstallAndNotify')]
        [string]$scheduleAction = 'DownloadInstallAndNotify',
        [switch]$scheduleAuto    
    )
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
        (Write-Output ("DCU is not installed"))
}

if ($advancedDriverRestore){
    $advancedDriverRestoreVar = "-advancedDriverRestore=$advancedDriverRestore -outputlog=$env:systemdrive\CMSL\Logs\DCU-CLI.log "
    $ArgList = "/configure $advancedDriverRestoreVar"
    $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru
}
if ($autoSuspendBitLocker){ 
    $autoSuspendBitLockerVar = "-autoSuspendBitLocker=$autoSuspendBitLocker -outputlog=$env:systemdrive\CMSL\Logs\DCU-CLI.log "
    $ArgList = "/configure $autoSuspendBitLockerVar"
    $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru
}
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
    $ArgList = "/configure $installationDeferralVar $deferralInstallIntervalVar $deferralInstallCountVar -outputlog=$env:systemdrive\CMSL\Logs\DCU-CLI.log "
    $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru
    
}
else {
    $installationDeferralVar = "-installationDeferral=$installationDeferral"
}

if ($reboot){
    $rebootVar = "-reboot=$reboot"
}
if ($scheduleAction){
    $scheduleActionVar = "-scheduleAction=$scheduleAction"
}
if ($scheduleAuto){
    $scheduleAutoVar = "-scheduleAuto"
}


$ArgList = "/configure $advancedDriverRestoreVar $autoSuspendBitLockerVar $installationDeferralVar $deferralInstallIntervalVar $deferralInstallCountVar  -outputlog=$env:systemdrive\CMSL\Logs\DCU-CLI.log "
Write-Host $ArgList
#$DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru


#dcu-cli.exe /configure -autoSuspendBitLocker=enable -scheduledReboot=60 -silent

}