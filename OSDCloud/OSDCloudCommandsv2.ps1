<#
.SYNOPSIS
    This script contains a set of commands for managing and deploying OSD (Operating System Deployment) using OSDCloud.

.DESCRIPTION
    The script provides various functions and commands to facilitate the building of an OSDCloud Workspace (USB Drive)


.NOTES
    Author: Gary Blok
    Date: 25.3.3
    This script is part of the OSDCloud project and is intended for use in automated operating system deployments.


    You can run the script, it will build out the folder structure, you can then populate it with CU's to apply that match your ADK
    I'd suggest looking through the script to see how it works, and then running it manually to see what it does.
    The script is designed to be run in parts, and you can run each part manually as needed, but it should still work if you run the entire thing, there is a break at the end to stop it from running everything.

    This script was designed for my personal needs, I'm just making it available for others to use as an example, but it's not supported by me, or anyone else.
#>


#region Functions
Function Remove-OSDCloudMediaLanguageExtras {
    # Clean up Language extras in the WorkSpace (Shouldn't be there if this ran on the template)
    if (Test-Path -Path "$(Get-OSDCloudWorkspace)\Media"){
        $Folders = get-childitem -path "$(Get-OSDCloudWorkspace)\Media"-Recurse | where-object {$_.Attributes -match "Directory" -and $_.Name -match "-" -and $_.Name -notmatch "en-us"}
        $Folders | Remove-Item -Force -Recurse
    }
    # Clean up Language extras in the Template
    if (Test-Path -path "$(Get-OSDCloudTemplate)\Media"){
        $Folders = get-childitem -path "$(Get-OSDCloudTemplate)\Media" -Recurse | where-object {$_.Attributes -match "Directory" -and $_.Name -match "-" -and $_.Name -notmatch "en-us"}
        $Folders | Remove-Item -Force -Recurse
    }
}


Function Set-WiFi {
    #https://www.cyberdrain.com/automating-with-powershell-deploying-wifi-profiles/
    param(
        [string]$SSID,
        [string]$PSK,
        [string]$SaveProfilePath
    )
    $guid = New-Guid
    $HexArray = $ssid.ToCharArray() | foreach-object { [System.String]::Format("{0:X}", [System.Convert]::ToUInt32($_)) }
    $HexSSID = $HexArray -join ""
@"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$($SSID)</name>
    <SSIDConfig>
        <SSID>
            <hex>$($HexSSID)</hex>
            <name>$($SSID)</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$($PSK)</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
    <MacRandomization xmlns="http://www.microsoft.com/networking/WLAN/profile/v3">
        <enableRandomization>false</enableRandomization>
        <randomizationSeed>1451755948</randomizationSeed>
    </MacRandomization>
</WLANProfile>
"@ | out-file "$($ENV:TEMP)\$guid.SSID"
    
    
    if ($SaveProfilePath){
        Copy-Item "$($ENV:TEMP)\$guid.SSID" -Destination $SaveProfilePath -Force
    }
    else{
        netsh wlan add profile filename="$($ENV:TEMP)\$guid.SSID" user=all
    }
    remove-item "$($ENV:TEMP)\$guid.SSID" -Force
}

Function Add-Opera {

    #Builds Custom Opera Install and sets things how I want them to be
    [CmdletBinding()]
        param (
            [string]$MountPath,
            [string]$BuildPath
        )

    #$BuildPath = 'c:\OperaBuild'
    $CustomConfigsPath = "$BuildPath\CustomConfigs"
    $InstallPath = "$BuildPath\Opera"
    $OperaInstallerPath = "$BuildPath\OperaInstaller.exe"
    $URL = "https://net.geo.opera.com/opera_portable/stable/windows"

    $ConfigFiles = @(
    @{FileName = 'installer_prefs.json' ;URL = 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/AppCustomizations/Opera/W365/installer_prefs.json'; InstallPath = "$InstallPath"}
    @{FileName = 'Local State' ;URL = 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/AppCustomizations/Opera/W365/Local%20State'; InstallPath = "$InstallPath\profile\data"}
    @{FileName = 'Preferences' ;URL = 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/AppCustomizations/Opera/W365/Preferences'; InstallPath = "$InstallPath\profile\data\Default"}
    )

    try {
        [void][System.IO.Directory]::CreateDirectory($BuildPath)
        [void][System.IO.Directory]::CreateDirectory($CustomConfigsPath)
    }
    catch {throw}

    write-host "Adding Opera Browser to Boot Media" -ForegroundColor Cyan
    Write-Host " Starting Download..."
    Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $OperaInstallerPath

    Write-Host " Starting creation of Portable Setup"
    $OperaArgs = "/singleprofile=1 /copyonly=1 /enable-stats=0 /enable-installer-stats=0 /launchbrowser=0 /installfolder=$InstallPath /allusers=0 /run-at-startup=0 /import-browser-data=0 /setdefaultbrowser=0 /language=en /personalized-ads=0 /personalized-content=0 /general-location=0 /consent-given=0 /silent"
    $InstallOpera = Start-Process -FilePath $OperaInstallerPath -ArgumentList $OperaArgs -PassThru -Wait -NoNewWindow
    $InstallOpera.WaitForExit()
    Start-Sleep -Seconds 30

    #Confirm Opera Path for Install is there
    if (Test-Path -Path $InstallPath){
    
        #Cleanup Localizations
        $OperaInfo = Get-Item -Path "$InstallPath\opera.exe"
        Get-ChildItem -path "$InstallPath\$($OperaInfo.VersionInfo.ProductVersion)\localization" | Where-Object {$_.name -ne "en-US.pak"} | Remove-Item

        #Cleanup AutoUpdater
        Remove-Item -Path "$InstallPath\autoupdate" -Force -Recurse
    
    }

    #Setup Config Files
    foreach ($ConfigFile in $ConfigFiles){
    
        #Download ConfigFile to ConfigFiles Staging
        Invoke-WebRequest -UseBasicParsing -Uri $ConfigFile.URL -OutFile "$CustomConfigsPath\$($ConfigFile.FileName)"

        #Copy Config File to proper Location
        Copy-Item -Path "$CustomConfigsPath\$($ConfigFile.FileName)" -Destination $ConfigFile.InstallPath -Force
    }
    Write-Host " Copying Opera Portable to $MountPath"
    Copy-Item -Path $InstallPath -Destination $MountPath -Recurse
}

Function Remove-OldOSDModulesLocalMachine {
    #Clean Up OSD Modules - Non-Current on Local Machine
    $Folder = Get-ChildItem 'C:\Program Files\WindowsPowerShell\Modules\OSD'
    if ($Folder.Count -gt 1){
        $LatestFolderVer = [VERSION[]]($Folder).Name | Sort-Object | Select-Object -Last 1
        $LatestFolder = $Folder | Where-Object {$_.Name -match $LatestFolderVer.ToString()}

        write-host "Latest Module: $($LatestFolder.Name)" -ForegroundColor Green
        Foreach ($Item in $Folder){
         if ( $Item.Name -ne $LatestFolder.Name){
            write-host "Removing $($Item.FullName)" -ForegroundColor Yellow
            Remove-item -Path $Item.FullName -Force -Recurse
            }        
        }
    }
    else {
        write-host "Latest Module: $($Folder.Name)" -ForegroundColor Green
    }
}
Function Get-7ZipIntoPE {
    param (
        $MountPath = 'C:\mount'
    )
    write-host "Mounting: $(Get-OSDCloudWorkspace)\Media\sources\boot.wim to $MountPath"  -ForegroundColor Green
    Mount-WindowsImage -Path $MountPath -ImagePath "$(Get-OSDCloudWorkspace)\Media\sources\boot.wim" -Index 1 -Verbose

    Write-Host -ForegroundColor Yellow "7Zip for Extracting Driver Packs in WinPE"
    $Latest = Invoke-WebRequest -Uri https://github.com/ip7z/7zip/releases/latest -UseBasicParsing
    $NextLink = ($Latest.Links | Where-Object {$_.href -match "releases/tag"}).href
    $Version = $NextLink.Split("/")[-1]
    $VersionClean = ($Version).Replace(".","")
    $FileName = "7z$VersionClean-extra.7z"
    # Example: https://github.com/ip7z/7zip/releases/download/24.07/7z2407-extra.7z
    $Download7zrURL = "https://github.com/ip7z/7zip/releases/download/$Version/7zr.exe"
    $DownloadURL ="https://github.com/ip7z/7zip/releases/download/$Version/$fileName"

    Write-Host -ForegroundColor DarkGray "Downloading $DownloadURL"
    Invoke-WebRequest -Uri $Download7zrURL -OutFile "$env:TEMP\7zr.exe" -UseBasicParsing
    Invoke-WebRequest -Uri $DownloadURL -OutFile "$env:TEMP\$FileName" -UseBasicParsing
    if (Test-Path -Path $env:TEMP\$FileName){
        Write-Host -ForegroundColor DarkGray "Extracting $env:TEMP\$FileName"
        #$null = & "$env:temp\7zr.exe" x "$env:TEMP\$FileName" -o"$MountPath\Windows\System32" -y
        $null = & "$env:temp\7zr.exe" x "$env:TEMP\$FileName" -o"$env:temp\7zip" -y
        Copy-Item -Path "$env:temp\7zip\x64\*" -Destination "$MountPath\Windows\System32" -Recurse -Force -verbose
    }
    else {
        Write-Warning "Could not find $env:TEMP\$FileName"
    }
    
    #Dismount - Save
    Dismount-WindowsImage -Path $MountPath -Save
}
Function Remove-OldOSDModulesInWinPE {
#Custom Changes to Boot.Wim
    param (
        $MountPath = 'C:\mount'
    )
    write-host "Mounting: $(Get-OSDCloudWorkspace)\Media\sources\boot.wim to $MountPath"  -ForegroundColor Green
    Mount-WindowsImage -Path $MountPath -ImagePath "$(Get-OSDCloudWorkspace)\Media\sources\boot.wim" -Index 1 -Verbose

    #Clear out Extra OSD modules
    $Folder = Get-ChildItem "$MountPath\Program Files\WindowsPowerShell\Modules\OSD"
    if ($Folder.Count -gt 1){
        $Versions = @()
        foreach ($Item in $Folder.Name){
            $Versions += [Version]$Item
        }
        $LatestVersion = $Versions | Sort-Object | Select-Object -Last 1
        $LatestFolder = $Folder | Where-Object {$_.Name -match $LatestVersion.ToString()}
        write-host "Latest Module: $($LatestFolder.Name)" -ForegroundColor Green
        Foreach ($Item in $Folder){
         if ( $Item.Name -ne $LatestFolder.Name){
            write-host "Removing $($Item.FullName)" -ForegroundColor Yellow
            Remove-item -Path $Item.FullName -Force -Recurse
            }        
        }
    }
    else {
        write-host "Latest Module: $($Folder.Name)" -ForegroundColor Green
    }
    #Dismount - Save
    Dismount-WindowsImage -Path $MountPath -Save
}
#This needs to be run when the WIM is mounted.
function Get-WinPEMSUpdates {
    param (
        [switch]$Apply,
        [string]$MountPath = 'C:\Mount'
    )
    $CU_MSU = Get-ChildItem -Path "$OSDCloudRootPath\Patches\CU\$OSNameNeeded" -Filter *.msu -ErrorAction SilentlyContinue
    if ($CU_MSU){
        if ($CU_MSU.count -gt 1){
            $CU_MSU = $CU_MSU | Sort-Object -Property Name #| Select-Object -Last 1
        }
        foreach ($CU in $CU_MSU){
            Write-Host -ForegroundColor Yellow "Found CU: $($CU.Name)"
            $PatchPath = $CU.FullName
            If ($PatchPath) {
                $AvailableCU = $PatchPath
                Write-Host -ForegroundColor Green "Available CU Found: $AvailableCU"
                Write-Host -ForegroundColor DarkGray "Applying CU $PatchPath"
                if ($Apply){Add-WindowsPackage -Path $MountPath -PackagePath $PatchPath -Verbose}
            }
        }
        if ($Apply){
            Write-Host "Cleaning up after CU's (DISM /Cleanup-image /StartComponentCleanup /Resetbase)" -ForegroundColor DarkGray
            Start-Process "dism" -ArgumentList " /Image:$MountPath /Cleanup-image /StartComponentCleanup /Resetbase" -Wait -LoadUserProfile
        }
        return $true
    }
    else {
        write-host "No CU's found to apply to OS $OSNameNeeded"
        return $false
    }
}
# Clean up and create Mount directory
function Reset-MountPath {
    param (
        $MountPath
    )
    If (Test-Path $MountPath) {
        Write-Host "Cleaning up previous run: $MountPath" -ForegroundColor DarkGray
        Remove-Item $MountPath -Force -Verbose -Recurse | Out-Null    
    }
    Write-Host "Creating New Folder: $MountPath" -ForegroundColor DarkGray
    New-Item $MountPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
}
#endregion

#Default = AMD64 (x64) WinPE.  Change these variables to give different results.  Note that ARM64 is broken due to ARM64 being removed from OSDCloud recently.
$IsTemplateWinRE = $false
$IsTemplateARM64 = $false
$OSDCloudRootPath = "C:\OSDCloud-ROOT"
$MountPath = "C:\Mount"
$WorkSpaceRootDrive = "C:"
$DriversPath = "C:\OSDCloud-ROOT\Drivers"

#Build Additional Variables based on the ones above - This will be used more later with OSDCloud V2.
if ($IsTemplateARM64){$Arch = 'ARM64'}
else{$Arch = 'AMD64'}



$CurrentModule = Get-InstalledModule -name OSD -ErrorAction SilentlyContinue
if ($CurrentModule){
    $availableModule = Find-Module -Name "OSD"
    if ([VERSION]$CurrentModule.Version -lt [VERSION]$availableModule.Version){
        Update-Module -name OSD -Force -Scope AllUsers
        #Restart PowerShell after OSD has been updated (if it needed to be updated)
    }
}
else{Install-Module -name OSD -Force -Scope AllUsers}

$ADKPaths = Get-AdkPaths -Architecture $Arch -ErrorAction SilentlyContinue
if (!($ADKPaths)){
    Write-Host "NO ADK Found, resolve and try again" -ForegroundColor Red
    break
}
#$ADKPath = $ADKPaths.PathWinPE
$ADKWinPE = Get-ChildItem -Path $ADKPaths.PathWinPE -Filter *.wim -Recurse
$ADKWinPEInfo = Get-WindowsImage -ImagePath $ADKWinPE.FullName -Index 1

Write-Host "ADK WinPE Version:       " -ForegroundColor Cyan -NoNewline
Write-Host "$($ADKWinPEInfo.Version)" -ForegroundColor Green
Write-Host "ADK WinPE Architecture:  " -ForegroundColor Cyan -NoNewline
Write-Host "$($ADKWinPEInfo.ImageName)" -ForegroundColor Green


$Mappings = @(
@{ Build = '10.0.26100.1'; OSName = "Windows 11 24H2 $Arch" ; OSDisplay="Win1124H2"}
@{ Build = '10.0.22621.1'; OSName = "Windows 11 22H2 $Arch" ; OSDisplay="Win1122H2"}
@{ Build = '10.0.19045.1'; OSName = "Windows 10 22H2 $Arch" ; OSDisplay="Win1022H2"}
)
$OSNameNeeded = ($Mappings | Where-Object {$_.Build -match $ADKWinPEInfo.Version}).OSName
$OSDisplayNeeded = ($Mappings | Where-Object {$_.Build -match $ADKWinPEInfo.Version}).OSDisplay
#$Lang = ($ADKWinPE.FullName | Split-Path) | Split-Path -Leaf


try {
    [void][System.IO.Directory]::CreateDirectory("$OSDCloudRootPath\Patches\CU\$OSNameNeeded")
    [void][System.IO.Directory]::CreateDirectory("$OSDCloudRootPath\AKDWinPEWIM")
    [void][System.IO.Directory]::CreateDirectory("$DriversPath")
    [void][System.IO.Directory]::CreateDirectory("$DriversPath\WinPE")
    [void][System.IO.Directory]::CreateDirectory("$DriversPath\WinREAddons")
}
catch {throw}


#Build Template Name
if ($IsTemplateWinRE){
    $templateName = "OSDCloud-$($OSDisplayNeeded)-$($Arch)-WinRE"
    $WinRE = $True
}
else{
    $templateName = "OSDCloud-$($OSDisplayNeeded)-$($Arch)-WinPE"
    $WinRE = $false
}
Write-Host -ForegroundColor Magenta "Template Name: $templateName"
$WorkSpacePath = "$WorkSpaceRootDrive\$TemplateName"

#Test For Current Templates
$CurrentTemplates = Get-OSDCloudTemplateNames
if ($CurrentTemplates -contains $templateName){
    Write-Host "Template Already Exists: $templateName" -ForegroundColor Yellow
    
}
else{
    #Build the Template
    Write-Host -ForegroundColor Magenta "Creating OSDCloud Template for $OSNameNeeded"
    Write-Host "  Including 7Zip in Boot Media" -ForegroundColor Cyan
    if ($WinRE){
        New-OSDCloudTemplate -Name $templateName -Add7Zip -WinRE:$WinRE
    }
    else{
        #New-OSDCloudTemplate -Name $templateName -Add7Zip -OSArch $ArchDisplay
        New-OSDCloudTemplate -Name $templateName -Add7Zip
    }
    #Cleanup Languages
    #Remove-OSDCloudMediaLanguageExtras

    #Update the Template with the CU (if available)
    $AvailableCU = Get-WinPEMSUpdates

    if ($AvailableCU -or (Test-Path $DriversPath\WinPE\*)){
        $Path = Get-OSDCloudTemplate
        $Path = Get-OSDCloudWorkspace
        $BootWIM = (Get-ChildItem -Path $Path -Recurse -Filter *.wim).FullName
        Reset-MountPath -MountPath $MountPath
        Write-Host "Updating $BootWIM in $MountPath" -ForegroundColor Magenta
        Mount-WindowsImage -Path $MountPath -ImagePath $BootWIM -Index 1
        Get-WinPEMSUpdates -Apply -MountPath $MountPath
        #Add CMTrace while I have the template mounted.
        if (Test-Path -Path "C:\windows\system32\cmtrace.exe"){
            if (!(Test-Path -Path "$MountPath\Windows\System32\cmtrace.exe")){
                Write-Host "Adding CMTrace to Boot Image" -ForegroundColor DarkGray
                Copy-Item "C:\windows\system32\cmtrace.exe" "$MountPath\Windows\System32\cmtrace.exe" -Force
            }
            else{
                Write-Host "CMTrace is currently in Boot Image" -ForegroundColor DarkGray
            }
        }
        #Add Drivers into Template Which will be used in Boot Media regularly.  If one off, do it in the workspace instead using Edit-OSDCloudWinPE
        If (Test-Path $DriversPath\WinPE\*) {
            Write-Host "Injecting drivers from $DriversPath\WinPE"
            Add-WindowsDriver -Path $MountPath -Driver "$DriversPath\WinPE" -Recurse
        }
        if ($WinRE){
            If (Test-Path $DriversPath\WinREAddons\*) {
                Write-Host "Injecting drivers from $DriversPath\WinREAddons"
                Add-WindowsDriver -Path $MountPath -Driver "$DriversPath\WinREAddons" -Recurse
            }
        }
        dismount-WindowsImage -Path $MountPath -Save
        Get-WindowsImage -ImagePath "$BootWIM" -Index 1
        $WinPEVersion = (Get-WindowsImage -ImagePath "$BootWIM" -Index 1).Version
    }
    else{
        $CUPath = "$OSDCloudRootPath\Patches\CU\$OSNameNeeded"
        write-Host ""
        write-Host "============================================================================================="
        Write-Host "No CU's found to update the Boot Media, you might want to double check" -ForegroundColor Magenta
        write-Host "To add updates, place them here: $CUPath"
        write-Host "If you don't want to update your boot media, you don't have it, it's just what cool people do"
        write-Host "============================================================================================="
        write-Host ""
    }
}

if ($WinPEVersion){
    $WorkSpacePath = "$WorkSpacePath-$WinPEVersion"
}

#Create the WorkSpace
Write-Host "Creating OSDCloud WorkSpace: $WorkSpacePath" -ForegroundColor Magenta
New-OSDCloudWorkspace -WorkspacePath $WorkSpacePath
Set-OSDCloudWorkspace -WorkspacePath $WorkSpacePath

#Add Drivers:
#Common Drivers are now added into the Template.
#Edit-OSDCloudWinPE -CloudDriver HP,USB

#Added HPCMSL into WinPE & WiFi Info if WinRE
if ($WinRE){
    Edit-OSDCloudWinPE -PSModuleInstall HPCMSL -DriverPath "$WorkSpaceRootDrive\WinPEBuilder\Drivers\WiFi"
    #Edit-OSDCloudWinPE -PSModuleInstall HPCMSL -WirelessConnect
    Set-WiFi -SSID WinRE -PSK WinREWiFi! -SaveProfilePath "$OSDCloudRootPath\Lab-WifiProfile.xml"
    Edit-OSDCloudWinPE -PSModuleInstall HPCMSL -WifiProfile "$OSDCloudRootPath\Lab-WifiProfile.xml"
}
else{
    Edit-OSDCloudWinPE -PSModuleInstall HPCMSL -DriverPath "C:\OSDCloud-ROOT\WinPEDrivers\"
    #Edit-OSDCloudWinPE -StartURL 'https://hope.garytown.com'
    Edit-OSDCloudWinPE -StartURL 'https://intunelab.garytown.com'
}
New-OSDCloudISO

#Everything Below should be run manually when needed
break

#Extra Items Optional
New-OSDCloudWorkSpaceSetupCompleteTemplate
#Edit-OSDCloudWinPE -DriverPath "C:\OSDCloudARM64\WinPEDrivers\SurfaceProX\FileRepository"
#Edit-OSDCloudWinPE -DriverPath "C:\swsetup\Dock"

#Create Cloud USB
New-OSDCloudUSB

#Update the Cloud USB drive
#Note, I found I need to add some parameters for it to sync over everything properly.
Update-OSDCloudUSB -PSUpdate


$UpdateModuleDev = $false #Gary uses for testing unreleased module updates
#Custom Changes to Boot.Wim
write-host "Mounting: $(Get-OSDCloudWorkspace)\Media\sources\boot.wim"  -ForegroundColor Green
Mount-WindowsImage -Path $MountPath -ImagePath "$(Get-OSDCloudWorkspace)\Media\sources\boot.wim" -Index 1

#Add-Opera -MountPath "$MountPath" -BuildPath "c:\windows\temp\Opera"

#Update Boot WIM
if ($UpdateModuleDev -eq $true){
    #Copy Development Files - Overwrite production
    #This allows me to make changes to the module in my Local VSCode GitHub Folder, and sync it over to the Boot WIM to test things before it's released to public.
    $GitHubFolder = "C:\Users\GaryBlok\OneDrive - garytown\GitHub"
    $OSDMountedModuleFolder = Get-ChildItem "$MountPath\Program Files\WindowsPowerShell\Modules\OSD"
    $OSDMountedModule = "$($OSDMountedModuleFolder.FullName)"
    write-host "Updating Module in Boot WIM from Dev Source" -ForegroundColor Green
    if (($GitHubFolder) -and ($OSDMountedModule) -and ($MountPath)){
        copy-item "$GitHubFolder\OSD\Public\*"   "$OSDMountedModule\Public\" -Force -Recurse
        copy-item "$GitHubFolder\OSD\Catalogs\*"   "$OSDMountedModule\Catalogs\" -Force -Recurse
        copy-item "$GitHubFolder\OSD\Projects\*"   "$OSDMountedModule\Projects\" -Force -Recurse

    }
}
#Add CMTrace while I have the template mounted.
if (Test-Path -Path "C:\windows\system32\cmtrace.exe"){
    if (!(Test-Path -Path "$MountPath\Windows\System32\cmtrace.exe")){
        Write-Host "Adding CMTrace to Boot Image" -ForegroundColor Dark Gray
        Copy-Item "C:\windows\system32\cmtrace.exe" "$MountPath\Windows\System32\cmtrace.exe" -Force
    }
    else{
        Write-Host "CMTrace is currently in Boot Image" -ForegroundColor Dark Gray
    }
}
#Dismount - Save
Dismount-WindowsImage -Path $MountPath -Save

New-OSDCloudISO

#Update Flash Drive
Update-OSDCloudUSB


#Troubleshooting

#Copy the default WinPE & Apply the CU
Copy-Item -Path $ADKWinPE.FullName -Destination "$OSDCloudRootPath\AKDWinPEWIM\winpe.wim" -Force
Mount-WindowsImage -Path $MountPath -ImagePath "$OSDCloudRootPath\AKDWinPEWIM\winpe.wim" -Index 1
Add-WindowsPackage -PackagePath $PatchPath -Path $MountPath -LogLevel Debug -Verbose
Dismount-WindowsImage -Path $MountPath -Save

Get-WindowsImage -ImagePath "$OSDCloudRootPath\AKDWinPEWIM\winpe.wim" -Index 1


#Update Flash Drive for 2023 Certs

$OSDCloudUSBFileSystemLabel = 'WINPE'
$USBBootVolume = Get-Volume | Where-Object {$_.DriveType -eq "Removable" -and $_.FileSystemType -eq "FAT32" -and $_.FileSystemLabel -eq $OSDCloudUSBFileSystemLabel} | Select-Object -First 1
$USBBootVolumeLetter = $USBBootVolume.DriveLetter
#https://support.microsoft.com/en-us/topic/how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d#bkmk_windows_install_media
copy-item "$($USBBootVolumeLetter):\EFI\MICROSOFT\BOOT\BCD" "$($USBBootVolumeLetter):\EFI\MICROSOFT\BOOT\BCD.BAK" -Force -Verbose
Start-Process -FilePath C:\windows\system32\bcdboot.exe -ArgumentList "c:\windows /f UEFI /s $($USBBootVolumeLetter): /bootex" -Wait -NoNewWindow -PassThru
copy-item "$($USBBootVolumeLetter):\EFI\MICROSOFT\BOOT\BCD.BAK" "$($USBBootVolumeLetter):\EFI\MICROSOFT\BOOT\BCD" -Force -Verbose
