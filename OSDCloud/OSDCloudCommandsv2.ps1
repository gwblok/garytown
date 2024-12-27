#region Functions
Function Remove-OSDCloudWorkSpaceMediaLanguageExtras {
    if (Test-Path -Path "$(Get-OSDCloudWorkspace)\Media"){
        $Folders = get-childitem -path "$(Get-OSDCloudWorkspace)\Media"-Recurse | where-object {$_.Attributes -match "Directory" -and $_.Name -match "-" -and $_.Name -notmatch "en-us"}
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

#endregion


$IsTemplateWinRE = $false
$OSDCloudRootPath = "C:\OSDCloud-ROOT"


$CurrentModule = Get-InstalledModule -name OSD -ErrorAction SilentlyContinue
if ($CurrentModule){
    $AvailbleModule = Find-Module -Name "OSD"
    if ([VERSION]$CurrentModule.Version -lt [VERSION]$AvailbleModule.Version){
        Update-Module -name OSD -Force
        
        #Restart PowerShell after OSD has been updated (if it needed to be updated)

    }

}
else{
        Install-Module -name OSD -Force
}

$ADKPaths = Get-AdkPaths -ErrorAction SilentlyContinue
if (!($ADKPaths)){
    Write-Host "NO ADK Found, resolve and try again" -ForegroundColor Red
    break
}
$ADKPath = $ADKPaths.PathWinPE
$ADKWinPE = Get-ChildItem -Path $ADKPaths.PathWinPE -Filter *.wim -Recurse
$ADKWinPEInfo = Get-WindowsImage -ImagePath $ADKWinPE.FullName -Index 1

Write-Host "ADK WinPE Version:       " -ForegroundColor Cyan -NoNewline
Write-Host "$($ADKWinPEInfo.Version)" -ForegroundColor Green
Write-Host "ADK WinPE Architecture:  " -ForegroundColor Cyan -NoNewline
Write-Host "$($ADKWinPEInfo.ImageName)" -ForegroundColor Green


$Mappings = @(

@{ Build = '10.0.26100.1'; OSName = "Windows 11 24H2 x64" ; OSDisplay="Win1124H2"}
@{ Build = '10.0.22621.1'; OSName = "Windows 11 22H2 x64" ; OSDisplay="Win1122H2"}
@{ Build = '10.0.19045.1'; OSName = "Windows 10 22H2 x64" ; OSDisplay="Win1022H2"}

)
$OSNameNeeded = ($Mappings | Where-Object {$_.Build -match $ADKWinPEInfo.Version}).OSName
$OSDisplayNeeded = ($Mappings | Where-Object {$_.Build -match $ADKWinPEInfo.Version}).OSDisplay
$Lang = ($ADKWinPE.FullName | Split-Path) | Split-Path -Leaf


try {
    [void][System.IO.Directory]::CreateDirectory("$OSDCloudRootPath\Patches\CU\$OSNameNeeded")
    [void][System.IO.Directory]::CreateDirectory("$OSDCloudRootPath\AKDWinPEWIM")
    
}
catch {throw}

$CU_MSU = Get-ChildItem -Path "$OSDCloudRootPath\Patches\CU\$OSNameNeeded" -Filter *.msu -ErrorAction SilentlyContinue
if ($CU_MSU){
    if ($CU_MSU.count -gt 1){
        $CU_MSU = $CU_MSU | Sort-Object -Property Name | Select-Object -Last 1
    }
    $PatchPath = $CU_MSU.FullName
    If ($PatchPath) {
        $AvailableCU = $PatchPath
        Write-Host -ForegroundColor Green "Available CU Found: $AvailableCU"
        #Write-Host -ForegroundColor DarkGray "Applying CU $PatchPath"
        #Add-WindowsPackage -Path $MountPath -PackagePath $PatchPath -Verbose
    }
}
else {
    write-host "No CU's found to apply to OS $OSNameNeeded"
}

<#
$GitHubFolder = "C:\Users\GaryBlok\OneDrive - garytown\Documents\GitHub - ZBook"
$LocalModuleFolder = Get-ChildItem 'C:\Program Files\WindowsPowerShell\Modules\OSD'
$OSDLocalModule = "$($LocalModuleFolder.FullName)"
copy-item "$GitHubFolder\OSD\*"   "$OSDLocalModule" -Force -Verbose -Recurse
#>




<#
#Setup WorkSpace Location
Import-Module -name OSD -force
$OSDCloudWorkspace = "C:\OSDCloudWinPE"
$OSDCloudWorkspaceWinRE = "C:\OSDCloudWinRE"
$OSDCloudWorkspaceARM64 = "C:\OSDCloudARM64"
[void][System.IO.Directory]::CreateDirectory($OSDCloudWorkspace)
[void][System.IO.Directory]::CreateDirectory($OSDCloudWorkspaceWinRE)
[void][System.IO.Directory]::CreateDirectory($OSDCloudWorkspaceARM64)

#New Template (After you've updated ADK to lastest Version)
New-OSDCloudTemplate -Name "OSDCloudWinPE"
New-OSDCloudTemplate -Name "OSDCloudWinRE" -WinRE
New-OSDCloudTemplate -Name "OSDCloudARM64" -ARM64

#New WorkSpace x64
Set-OSDCloudTemplate -Name OSDCloudWinPE
New-OSDCloudWorkspace -WorkspacePath $WorkSpacePath
New-OSDCloudWorkSpaceSetupCompleteTemplate

#>


if ($IsTemplateWinRE){
    $templateName = "OSDCloud-$($OSDisplayNeeded)-WinRE"
    $WinRE = $True
}
else{
    $templateName = "OSDCloud-$($OSDisplayNeeded)-WinPE"
    $WinRE = $false
}

$WorkSpacePath = "C:\$TemplateName"
$MountPath = "C:\Mount"
# Clean up and create Mount directory
If (Test-Path $MountPath) {
    Write-Host "Cleaning up previous run: $MountPath" -ForegroundColor DarkGray
    Remove-Item $MountPath -Force -Verbose -Recurse | Out-Null    
}
Write-Host "Creating New Folder: $MountPath" -ForegroundColor DarkGray
New-Item $MountPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null


#$DisplayLinkDriverPath = "C:\Users\GaryBlok\Downloads\DisplayLink USB Graphics Software for Windows11.4 M0-INF\x64"

if ($AvailableCU){
    if ($WinRE){
        New-OSDCloudTemplate -Name $templateName -CumulativeUpdate "$AvailableCU" -Add7Zip -WinRE:$WinRE
    }
    else{
        New-OSDCloudTemplate -Name $templateName -CumulativeUpdate "$AvailableCU" -Add7Zip
    }
}
else {
    if ($WinRE){
        New-OSDCloudTemplate -Name $templateName -Add7Zip -WinRE:$WinRE
    }
    else{
        New-OSDCloudTemplate -Name $templateName -Add7Zip
    }
}

New-OSDCloudWorkspace -WorkspacePath $WorkSpacePath
Set-OSDCloudWorkspace -WorkspacePath $WorkSpacePath
Remove-OSDCloudWorkSpaceMediaLanguageExtras



#Edit-OSDCloudWinPE -CloudDriver HP,USB -Add7Zip -PSModuleInstall HPCMSL #7Zip is already in template now


#Added HPCMSL into WinPE
if ($WinRE){
    Edit-OSDCloudWinPE -CloudDriver HP,USB -PSModuleInstall HPCMSL -DriverPath "C:\WinPEBuilder\Drivers\WiFi"
    #Edit-OSDCloudWinPE -PSModuleInstall HPCMSL -WirelessConnect
    Set-WiFi -SSID PXE -PSK 6122500648 -SaveProfilePath C:\OSDCloud-ROOT\Lab-WifiProfile.xml
    Edit-OSDCloudWinPE -PSModuleInstall HPCMSL -WifiProfile C:\OSDCloud-ROOT\Lab-WifiProfile.xml
}
else{
    Edit-OSDCloudWinPE -CloudDriver HP,USB -PSModuleInstall HPCMSL
    Edit-OSDCloudWinPE -StartURL 'https://hope.garytown.com'
}
New-OSDCloudISO


#New WorkSpace ARM64

Set-OSDCloudTemplate -Name OSDCloudARM64
New-OSDCloudWorkspace -WorkspacePath $OSDCloudWorkspaceARM64


#Cleanup Languages
Remove-OSDCloudWorkSpaceMediaLanguageExtras


#Cleanup Languages - Different Method
<#
$KeepTheseDirs = @('boot','efi','en-us','sources','fonts','resources')
Get-ChildItem "$(Get-OSDCloudWorkspace)\Media" | Where {$_.PSIsContainer} | Where {$_.Name -notin $KeepTheseDirs} | Remove-Item -Recurse -Force
Get-ChildItem "$(Get-OSDCloudWorkspace)\Media\Boot" | Where {$_.PSIsContainer} | Where {$_.Name -notin $KeepTheseDirs} | Remove-Item -Recurse -Force
Get-ChildItem "$(Get-OSDCloudWorkspace)\Media\EFI\Microsoft\Boot" | Where {$_.PSIsContainer} | Where {$_.Name -notin $KeepTheseDirs} | Remove-Item -Recurse -Force
#>

New-OSDCloudWorkSpaceSetupCompleteTemplate
Edit-OSDCloudWinPE -DriverPath "C:\OSDCloudARM64\WinPEDrivers\SurfaceProX\FileRepository"
Edit-OSDCloudWinPE -DriverPath "C:\swsetup\Dock"
#Create Cloud USB
New-OSDCloudUSB

#Update the Cloud USB drive
#Note, I found I need to add some parameters for it to sync over everything properly.
Update-OSDCloudUSB -PSUpdate



#Custom Changes to Boot.Wim
write-host "Mounting: $(Get-OSDCloudWorkspace)\Media\sources\boot.wim"  -ForegroundColor Green
Mount-WindowsImage -Path $MountPath -ImagePath "$(Get-OSDCloudWorkspace)\Media\sources\boot.wim" -Index 1


Add-Opera -MountPath "$MountPath" -BuildPath "c:\windows\temp\Opera"

#Copy Development Files - Overwrite production
$GitHubFolder = "C:\Users\GaryBlok\OneDrive - garytown\Documents\GitHub - ZBook"
$OSDMountedModuleFolder = Get-ChildItem "$MountPath\Program Files\WindowsPowerShell\Modules\OSD"
$OSDMountedModule = "$($OSDMountedModuleFolder.FullName)"

#Update Boot WIM
write-host "Updating Module in Boot WIM from Dev Source" -ForegroundColor Green
if (($GitHubFolder) -and ($OSDMountedModule) -and ($MountPath)){
    copy-item "$GitHubFolder\OSD\*"   "$OSDMountedModule" -Force -Recurse
    Copy-Item "C:\OSDCloudWinPE\Config\cmtrace.exe" "$MountPath\Windows\System32\cmtrace.exe" -Force
}
#Update Local Module

#Dismount - Save
Dismount-WindowsImage -Path $MountPath -Save

#Update Flash Drive
Update-OSDCloudUSB


#Troubleshooting

#Copy the default WinPE & Apply the CU
Copy-Item -Path $ADKWinPE.FullName -Destination "$OSDCloudRootPath\AKDWinPEWIM\winpe.wim" -Force
Mount-WindowsImage -Path $MountPath -ImagePath "$OSDCloudRootPath\AKDWinPEWIM\winpe.wim" -Index 1
Add-WindowsPackage -PackagePath $PatchPath -Path $MountPath -LogLevel Debug -Verbose
Dismount-WindowsImage -Path $MountPath -Save

Get-WindowsImage -ImagePath "$OSDCloudRootPath\AKDWinPEWIM\winpe.wim" -Index 1
