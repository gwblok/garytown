<#
   .Synopsis
        WinPE Builder will generate a patched WinPE with Optional Components
        and also optionally add BranchCache and StifleR

   .REQUIREMENTS
       OSD Module
       Windows ADK for WinPE source
       Windows install ISO/media for install.wim source for the BranchCache binaries
        - This it can grab using the OSD Module, it will grab the OS that matches your ADK (if available)
       Latest/recent Windows patch that matches the Windows install.wim version
       Optionally: OSD Toolkit for injecting BranchCache and StifleR
       Optionally: A copy of an installed StifleR Client folder

   .USAGE
       Set the parameters to match your environment in the parameters region

   .NOTES
    AUTHOR: 2Pint Software
    EMAIL: support@2pintsoftware.com
    VERSION: 23.10.01
    DATE:10/01/2023 
    
    CHANGE LOG: 
    23.10.01  : Initial version of script 
    24.04.15  : Tax day version - updated build paths
    24.08.14  : GWB Version - Incorporate OSD Module (OSDCloud) to use to grab Windows directly from internet & also automate some folder directories
                - YES, that means you need to install OSD Module - "Install Module -Name OSD"

   .LINK
    https://2pintsoftware.com


    WHAT YOU NEED TO DO
    Manage the script with some variables below, look for:
    - $StifleR = $true #this will add the content from your StifleRSource folder and enable that awesome 2Pint Magic
       - if you set it to false, you just get BC, which is still something.
    - $SkipOptionalComponents = $false #you'll typically want to leave this false unless you're doing some random testing
    - $WinPEBuilderPath = Path for where everything happens, this is set automatically based on where the script is running from
#>

#Random Notes
# ADK 24H2 doesn't patch well, last good patch = 2024-06 Cumulative Update for Windows 11 Version 24H2 for x64-based Systems (KB5039239)
#   - https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/a4531812-78f3-4028-8d1a-ea4381a49c48/public/windows11.0-kb5039239-x64_cd369cfc3ecd2e67c715dc28e563ca7ac1515f79.msu


$StifleR = $true
$BranchCache = $true
$SkipOptionalComponents = $false
$WinPEBuilderPath = 'D:\WinPEBuilder'

#region functions

<#
.SYNOPSIS
Gets many Windows ADK Paths into a hash to easily use in your code

.DESCRIPTION
Gets many Windows ADK Paths into a hash to easily use in your code

.LINK
https://github.com/OSDeploy/OSD/tree/master/Docs

.NOTES
21.3.15.2   Renamed to make it easier to understand what it does
21.3.10     Initial Release
#>
function Get-AdkPaths {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('amd64','x86','arm64')]
        [string]$Arch = $Env:PROCESSOR_ARCHITECTURE
    )
    
    #=================================================
    #   Get-AdkPaths AdkRoot
    #=================================================
    $InstalledRoots32 = 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots'
    $InstalledRoots64 = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
    if (Test-Path $InstalledRoots64) {
        $KitsRoot10 = Get-ItemPropertyValue -Path $InstalledRoots64 -Name 'KitsRoot10'
    }
    elseif (Test-Path $InstalledRoots32) {
        $KitsRoot10 = Get-ItemPropertyValue -Path $InstalledRoots64 -Name 'KitsRoot10'
    }
    else {
        Write-Warning "Unable to determine ADK Path"
        Break
    }
    $AdkRoot = Join-Path $KitsRoot10 'Assessment and Deployment Kit'
    #=================================================
    #   WinPERoot
    #=================================================
    $WinPERoot = Join-Path $AdkRoot 'Windows Preinstallation Environment'
    if (-NOT (Test-Path $WinPERoot -PathType Container)) {
        Write-Warning "Cannot find WinPERoot: $WinPERoot"
        $WinPERoot = $null
    }
    #=================================================
    #   PathDeploymentTools
    #=================================================
    $PathDeploymentTools = Join-Path $AdkRoot (Join-Path 'Deployment Tools' $Arch)
    $PathWinPE = Join-Path $WinPERoot $Arch
    #=================================================
    #   Create Object
    #=================================================
    $Results = [PSCustomObject] @{
        #KitsRoot           = $KitsRoot10
        AdkRoot             = $AdkRoot
        PathBCDBoot         = Join-Path $PathDeploymentTools 'BCDBoot'
        PathDeploymentTools = $PathDeploymentTools
        PathDISM            = Join-Path $PathDeploymentTools 'DISM'
        PathOscdimg         = Join-Path $PathDeploymentTools 'Oscdimg'
        PathUsmt            = Join-Path $AdkRoot (Join-Path 'User State Migration Tool' $Arch)
        PathWinPE           = Join-Path $WinPERoot $Arch
        PathWinPEMedia      = Join-Path $PathWinPE 'Media'
        PathWinSetup        = Join-Path $AdkRoot (Join-Path 'Windows Setup' $Arch)
        WinPEOCs            = Join-Path $PathWinPE 'WinPE_OCs'
        WinPERoot           = $WinPERoot
        WimSourcePath       = Join-Path $PathWinPE 'en-us\winpe.wim'

        bcdbootexe          = Join-Path $PathDeploymentTools (Join-Path 'BCDBoot' 'bcdboot.exe')
        bcdeditexe          = Join-Path $PathDeploymentTools (Join-Path 'BCDBoot' 'bcdedit.exe')
        bootsectexe         = Join-Path $PathDeploymentTools (Join-Path 'BCDBoot' 'bootsect.exe')
        dismexe             = Join-Path $PathDeploymentTools (Join-Path 'DISM' 'dism.exe')
        efisysbin           = Join-Path $PathDeploymentTools (Join-Path 'Oscdimg' 'efisys.bin')
        efisysnopromptbin   = Join-Path $PathDeploymentTools (Join-Path 'Oscdimg' 'efisys_noprompt.bin')
        etfsbootcom         = Join-Path $PathDeploymentTools (Join-Path 'Oscdimg' 'etfsboot.com')
        imagexexe           = Join-Path $PathDeploymentTools (Join-Path 'DISM' 'imagex.exe')
        oa3toolexe          = Join-Path $PathDeploymentTools (Join-Path 'Licensing\OA30' 'oa3tool.exe')
        oscdimgexe          = Join-Path $PathDeploymentTools (Join-Path 'Oscdimg' 'oscdimg.exe')
        pkgmgrexe           = Join-Path $PathDeploymentTools (Join-Path 'DISM' 'pkgmgr.exe')
    }
    Return $Results
}

#endregion 


#region Readme Files
$BuildsReadme = "This is where WinPE builds will get staged once they are built."

$OSDToolKitReadme = "For release changes please go to: https://docs.2pintsoftware.com/osd-toolkit/release-notes

For documentation please go to: https://docs.2pintsoftware.com/osd-toolkit/
	
Note: 	The binaries in the Tools in this folder is already included in the WinPEGen.exe binary, 
	but are available here for your convenience when distributing to full OS machines. 
	Please review the documentation for guidance on that.
"

$PatchesReadme = "Place the patch(es) you would like to apply to WinPE in this directory. Make sure they match the OS and architecture of the WinPE you are building."


$StifleRSourceReadme = "Place the StifleR source directory in this folder if incorporating the StifleR client into the WinPE build."

#endregion



# Check for elevation (admin rights)
If ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    # All OK, script is running with admin rights
}
else
{
    Write-Warning "This script needs to be run with admin rights..."
    Exit 1
}

#
# Parameters region BEGIN
#

#WinPEBuilder directory  - THIS IS WHERE EVERYTHING WILL BE BUILT.  Feel Free to customize, or it will use the folder based on where you saved the script.. which might not be the best, so plan ahead
#AKA, create a folder c:\WinPEBuilder\ and save this script to that location, then run it.
if (!($WinPEBuilderPath)){
    If ($psISE)
    {
        $WinPEBuilderPath = Split-Path -Path $psISE.CurrentFile.FullPath        
    }
    else
    {
        $WinPEBuilderPath = $global:PSScriptRoot
    }
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

@{ Build = '10.0.26100.1'; OSName = "Windows 11 24H2 x64"}  #Not supported by OSD Module Yet
@{ Build = '10.0.22621.1'; OSName = "Windows 11 22H2 x64"}  #Able to download via OSD Module
@{ Build = '10.0.19045.1'; OSName = "Windows 10 22H2 x64"}  #Able to download via OSD Module

)
$OSNameNeeded = ($Mappings | Where-Object {$_.Build -match $ADKWinPEInfo.Version}).OSName
$Lang = ($ADKWinPE.FullName | Split-Path) | Split-Path -Leaf

#Create Folder Structure - ASSUMES everything based on the location you're running this script from.
try {
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\Builds") #This is where WinPE builds will get staged once they are built.
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\Drivers") #Future Version with DISM these in automatically.
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\ExtraFiles") #Files get copied into the boot WIM (Folder Structure Matters)
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\ExtraFiles\ProgramData") #Files get copied into the boot WIM (Folder Structure Matters)
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\ExtraFiles\Windows\System32") #Files get copied into the boot WIM (Folder Structure Matters)
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\OSSource\$OSNameNeeded") #Location for the Install.wim file from the Full OS
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\Patches\CU\$OSNameNeeded") #Location to save your .msu CU files
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\Scratch") #Temp location, has nothing to do with scratching of the itchy kind
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\StifleRSource") #Place the StifleR source directory in this folder if incorporating the StifleR client into the WinPE build.
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\OSDToolkit") #Place OSDToolkit extract here
}
catch {throw}
#Build Readme Files
if (!(Test-Path "$WinPEBuilderPath\Builds\Readme.txt")){
    $BuildsReadme | Out-File -FilePath "$WinPEBuilderPath\Builds\Readme.txt" -Encoding utf8
}
if (!(Test-Path "$WinPEBuilderPath\OSDToolkit\Readme.txt")){
    $OSDToolKitReadme | Out-File -FilePath "$WinPEBuilderPath\OSDToolkit\Readme.txt" -Encoding utf8
}
if (!(Test-Path "$WinPEBuilderPath\Patches\Readme.txt")){
    $PatchesReadme | Out-File -FilePath "$WinPEBuilderPath\Patches\Readme.txt" -Encoding utf8
}
if (!(Test-Path "$WinPEBuilderPath\StifleRSource\Readme.txt")){
    $StifleRSourceReadme | Out-File -FilePath "$WinPEBuilderPath\StifleRSource\Readme.txt" -Encoding utf8
}


#Check for Install.WIM, make sure one is already there, if not, it will try to download / build one for you
if (Test-Path -Path "$WinPEBuilderPath\OSSource\install.wim"){
    $WinInfo = Get-WindowsImage -ImagePath "$WinPEBuilderPath\OSSource\$OSNameNeeded\install.wim"
    $Index = ($WinInfo | Where-Object {$_.ImageName -eq "Windows 11 Enterprise"}).ImageIndex
    if ($Index){
        $IndexInfo = Get-WindowsImage -ImagePath "$WinPEBuilderPath\OSSource\$OSNameNeeded\install.wim" -Index $Index
        #Confirm the Install WIM we have matches the ADK Version
        
        if ($IndexInfo.Version -match  ($ADKWinPEInfo.Version).Replace(".1","")){
            $WimDownload = $false
            $ImageIndexNumber = $Index
            Write-Host "ADK Version: $($ADKWinPEInfo.Version) matches install.wim Version: $($IndexInfo.Version)" -ForegroundColor green
        }
        else {
            $WimDownload = $true
            #Current install.wim file does not match ADK
            Write-Host "Removing $WinPEBuilderPath\OSSource\$OSNameNeeded\install.wim" -ForegroundColor Yellow
            Write-Host "ADK Version: $($ADKWinPEInfo.Version) vs install.wim Version: $($IndexInfo.Version)" -ForegroundColor Yellow
            remove-item -path "$WinPEBuilderPath\OSSource\$OSNameNeeded\install.wim" -Verbose
        }
    }
    else {$WimDownload = $true}
}
else {$WimDownload = $true}

#Leverages the OSD Module to download an ESD File that machines the OS Version of the ADK Installed
#It will download the ESD File, then extract the indexes needed and create a a WIM to place into the correct WInPEBuilderPath Location

if ($WimDownload -eq $true){

    #Check if previously downloaded and available
    if (Test-Path -Path "C:\OSDCloud\IPU\Media\$OSNameNeeded\sources\install.wim"){
        #Double check that there is no install.wim file there, if there isn't copy it there.
        if (!(Test-Path -Path "$WinPEBuilderPath\OSSource\$OSNameNeeded\install.wim")){
            Write-Host "Found correct Install.wim file, copying to to OSSource\$OSNameNeeded" -ForegroundColor Green
            Copy-Item "C:\OSDCloud\IPU\Media\$OSNameNeeded\sources\install.wim" -Destination "$WinPEBuilderPath\OSSource\$OSNameNeeded" -Verbose
        }
    }
    else {
        #Get Windows that matches the ADK
        New-OSDCloudOSWimFile -OSName $OSNameNeeded -OSEdition Enterprise -OSLanguage $Lang -OSActivation Volume
        if (Test-Path -Path "C:\OSDCloud\IPU\Media\$OSNameNeeded\sources\install.wim"){
            Copy-Item "C:\OSDCloud\IPU\Media\$OSNameNeeded\sources\install.wim" -Destination "$WinPEBuilderPath\OSSource\$OSNameNeeded"
        }
        else {
            Write-Host "Failed to download Required files" -ForegroundColor Red
            break
        }
    }
    #Grab Index Info for Enterprise to pass along later into 
    if (Test-Path -Path "$WinPEBuilderPath\OSSource\$OSNameNeeded\install.wim"){
        $WinInfo = Get-WindowsImage -ImagePath "C:\OSDCloud\IPU\Media\$OSNameNeeded\sources\install.wim"
        $Index = ($WinInfo | Where-Object {$_.ImageName -eq "Windows 11 Enterprise"}).ImageIndex
        if ($Index){
            $WimDownload = $false
            $ImageIndexNumber = $Index
        }
        else {
        Write-Host "Unable to get OSSourceIndex Info for Enterprise" -ForegroundColor Red
        break
        }
    }
}







$Scratch = "$WinPEBuilderPath\Scratch"
$WinPEScratch = "$Scratch\winpe.wim"

#Clean up Scratch directory
If (Test-Path $Scratch) {
    Write-Host "Cleaning up previous run: $Scratch" -ForegroundColor DarkGray
    Remove-Item $Scratch -Force -Verbose -Recurse | Out-Null
}
Write-Host "Creating New Folder: $Scratch" -ForegroundColor DarkGray
New-Item $Scratch -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null



# Set OS Image to get BranchCache binaries from. The OS version (build number, e.g. patch-level) must match boot image version.
# If using a newer Windows 10 image, patch the boot media to same level
$OSSource = "$WinPEBuilderPath\OSSource\$OSNameNeeded\install.wim"

$WinPESource = $ADKWinPE.FullName

# Get the StifleR Client files from a full Windows StifleR client install (copy entire folder)
$StifleRSource = "$WinPEBuilderPath\StifleRSource"

# Get the StifleR Client config file from a full Windows client 
$StifleRClientRules = "$StifleRSource\StifleR.ClientApp.exe.Config"

# List indexes in WIM Image
# Get-WindowsImage -ImagePath $Windows11Media

# Set other parameters
$ExportPath = "$WinPEBuilderPath\Builds"
$ExtraFiles = "$WinPEBuilderPath\ExtraFiles"
$WinPEIndex = "1"
#if ($ImageIndexNumber){[String]$OSSourceIndex = $ImageIndexNumber}
#else {$OSSourceIndex = "3"} #  Index 3 is Enterprise if using the WIM from a Microsoft ISO
$OSSourceIndex = $ImageIndexNumber
write-host "Using Index Number: $OSSourceIndex" -ForegroundColor Green
try {
    Get-WindowsImage -ImagePath "$WinPEBuilderPath\OSSource\$OSNameNeeded\install.wim" -Index $OSSourceIndex
}
catch {}

$OSDToolkitPath = "$WinPEBuilderPath\OSDToolkit"
$MountPath = "$WinPEBuilderPath\mount"
#$SSUPath = "$WinPEBuilderPath\Patches\ssu-19041.1704-x64_70e350118b85fdae082ab7fde8165a947341ba1a.msu"
#$PatchPath = "$WinPEBuilderPath\Patches\windows11.0-kb5036893-x64_f8c0bdc5888eb65b1d68b220b0b87535735f1795.msu"

#Set the path to the currently installed ADK
#$env:path = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM;$env:path"
#Import-Module "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM"


# Add the ViaMonstra Root CA
#$Cert = "E:\Setup\Cert\ViaMonstraRootCA.cer"
#
# Parameters region END
#


# Validation
If (!(Test-Path $OSSource)){Write-Warning "$Windows Media missing, aborting script...";Break}
If (!(Test-Path $WinPESource)){Write-Warning "$WinPESource missing, aborting script...";Break}
If ($BranchCache -or $StifleR) {
    $WinPEGenVersion=(Get-ItemProperty "$OSDToolkitPath\x64\WinPEGen.exe").VersionInfo.FileVersion
    If ([Version]$WinPEGenVersion -lt [Version]"3.1.3.0"){Write-Warning "WinPEGen version too old. Aborting script...";Break}
    If (!(Test-Path $OSDToolkitPath)){Write-Warning "$OSDToolkitPath missing, aborting script...";Break}
}
If ($StifleR) {
    If (!(Test-Path $StifleRSource)){Write-Warning "$StifleRSource missing, aborting script...";Break}
    If (!(Test-Path $StifleRClientRules)){Write-Warning "$StifleRClientRules missing, aborting script...";Break}
    $StifleRClientVersion=(Get-ItemProperty "$StifleRSource\StifleR.ClientApp.exe").VersionInfo.FileVersion
    If ([version]$StifleRClientVersion -lt [version]"2.2.4.1"){Write-Warning "StifleR Client version too old. Aborting script...";Break}
}

# Set working directory to OSDToolkitPath, and start Running WinPEGen.exe
Set-Location "$OSDToolkitPath\x64"

Copy-Item $WinPESource $WinPEScratch -Force -Verbose

If ($StifleR) {
Write-Output "Adding BranchCache and StifleR to WinPE..."
.\WinPEGen.exe $OSSource $OSSourceIndex $WinPEScratch $WinPEIndex /Add-StifleR /StifleRConfig:$StifleRClientRules /StifleRSource:$StifleRSource
    }
Elseif ($BranchCache) {
Write-Output "Adding BranchCache to WinPE..."
.\WinPEGen.exe $OSSource $OSSourceIndex $WinPEScratch $WinPEIndex 
    }


# Clean up and create Mount directory
If (Test-Path $MountPath) {
    Write-Host "Cleaning up previous run: $MountPath" -ForegroundColor DarkGray
    Remove-Item $MountPath -Force -Verbose -Recurse | Out-Null    
}
Write-Host "Creating New Folder: $MountPath" -ForegroundColor DarkGray
New-Item $MountPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null



Mount-WindowsImage -ImagePath $WinPEScratch -Index $WinPEIndex -Path $MountPath

#Add Optional Components
#Configuration Manager boot image required components

if ((Test-Path "$ADKPath\WinPE_OCs\WinPE-Scripting.cab") -and ($SkipOptionalComponents -ne $true)){
    #Scripting (WinPE-Scripting)
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\WinPE-Scripting.cab" -Path $MountPath -Verbose
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\en-us\WinPE-Scripting_en-us.cab" -Path $MountPath -Verbose

    #Scripting (WinPE-WMI)
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\WinPE-WMI.cab" -Path $MountPath -Verbose
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\en-us\WinPE-WMI_en-us.cab" -Path $MountPath -Verbose

    #Network (WinPE-WDS-Tools) 
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\WinPE-WDS-Tools.cab" -Path $MountPath -Verbose
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\en-us\WinPE-WDS-Tools_en-us.cab" -Path $MountPath -Verbose

    #Startup (WinPE-SecureStartup) Requires WinPE-WMI
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\WinPE-SecureStartup.cab" -Path $MountPath -Verbose
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\en-us\WinPE-SecureStartup_en-us.cab" -Path $MountPath -Verbose

    #Configuration Manager boot image additional components
    #Microsoft .NET (WinPE-NetFx) Requires WinPE-WMI
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\WinPE-NetFx.cab" -Path $MountPath -Verbose
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\en-us\WinPE-NetFx_en-us.cab" -Path $MountPath -Verbose
    #
    #Windows PowerShell (WinPE-PowerShell) Requires WinPE-WMI, WinPE-NetFx, WinPE-Scripting
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\WinPE-PowerShell.cab" -Path $MountPath -Verbose
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\en-us\WinPE-PowerShell_en-us.cab" -Path $MountPath -Verbose

    #Windows PowerShell (WinPE-DismCmdlets) Requires WinPE-WMI, WinPE-NetFx, WinPE-Scripting, WinPE-PowerShell
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\WinPE-DismCmdlets.cab" -Path $MountPath -Verbose
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\en-us\WinPE-DismCmdlets_en-us.cab" -Path $MountPath -Verbose

    #Microsoft Secure Boot Cmdlets (WinPE-SecureBootCmdlets) Requires WinPE-WMI, WinPE-NetFx, WinPE-Scripting, WinPE-PowerShell
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\WinPE-SecureBootCmdlets.cab" -Path $MountPath -Verbose

    #Windows PowerShell (WinPE-StorageWMI) Requires WinPE-WMI, WinPE-NetFx, WinPE-Scripting, WinPE-PowerShell
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\WinPE-StorageWMI.cab" -Path $MountPath -Verbose
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\en-us\WinPE-StorageWMI_en-us.cab" -Path $MountPath -Verbose

    #Storage (WinPE-EnhancedStorage) 
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\WinPE-EnhancedStorage.cab" -Path $MountPath -Verbose
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\en-us\WinPE-EnhancedStorage_en-us.cab" -Path $MountPath -Verbose

    #HTML (WinPE-HTA) Requires WinPE-Scripting
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\WinPE-HTA.cab" -Path $MountPath -Verbose
    Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\en-us\WinPE-HTA_en-us.cab" -Path $MountPath -Verbose

}
else {
    if (Test-Path "$ADKPath\WinPE_OCs\WinPE-Scripting.cab"){
        write-host "Failed to find ADK Path for the OCs"
    }
    if ($SkipOptionalComponents -ne $true){
        write-host "Option to skip the OCs was enabled"
    }
}
#Apply SSU - only required for WinPE 10 19041
If ($SSUPath) {Add-WindowsPackage -Path $MountPath -PackagePath $SSUPath -Verbose}

#Apply LCU
$CU_MSU = Get-ChildItem -Path "$WinPEBuilderPath\Patches\CU\$OSNameNeeded" -Filter *.msu -ErrorAction SilentlyContinue

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
            Add-WindowsPackage -Path $MountPath -PackagePath $PatchPath -Verbose
        }
    }
}


#$Update = Start-Process "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe" -ArgumentList " /Image:$MountPath /Add-Package /PackagePath:`"$PatchPath`"" -Wait -PassThru # -NoNewWindow


#Perform component cleanup

Start-Process "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe" -ArgumentList " /Image:$MountPath /Cleanup-image /StartComponentCleanup /Resetbase" -Wait -LoadUserProfile

#Add ExtraFiles
#Place the files in the corresponding directory in the ExtraFiles directory
#Example: Create a directory called Windows and add smsts.ini
#SDClean, devcon, smsts.ini, makeiPXEUSB, iPXEEFI, etc.
If (Test-Path $ExtraFiles\*) {
    Copy-Item -Path $ExtraFiles\* -Destination "$MountPath\" -Force -Recurse -Verbose
    }

#Inject Drivers

#Verify added packages
Get-WindowsPackage -Path $MountPath

#Unmount boot image
Dismount-WindowsImage -Path $MountPath -Save

#Get build info
$BuildNumber = (Get-WindowsImage -ImagePath $WinPEScratch -Index 1).Version
write-output "Build Number: $BuildNumber"

#Export boot image to reduce the size
If ($StifleR) {
    Export-WindowsImage -SourceImagePath $WinPEScratch -SourceIndex 1 -DestinationImagePath "$ExportPath\winpe.$($BuildNumber)_$(get-date -format "yy.MM.dd")_StifleR.wim" -Verbose
    }
Elseif ($BranchCache) {
    Export-WindowsImage -SourceImagePath $WinPEScratch -SourceIndex 1 -DestinationImagePath "$ExportPath\winpe.$($BuildNumber)_$(get-date -format "yy.MM.dd")_BC.wim" -Verbose
    }
Else {
    Export-WindowsImage -SourceImagePath $WinPEScratch -SourceIndex 1 -DestinationImagePath "$ExportPath\winpe.$($BuildNumber)_$(get-date -format "yy.MM.dd").wim" -Verbose
    }
