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
EMAIL: support@2pintsoftware.com (or reach out to Gary Blok)
VERSION: 23.10.01
DATE:10/01/2023 

CHANGE LOG: 
23.10.01  : Initial version of script 
24.04.15  : Tax day version - updated build paths
24.08.14  : GWB Version - Incorporate OSD Module (OSDCloud) to use to grab Windows directly from internet & also automate some folder directories
- YES, that means you need to install OSD Module - "Install Module -Name OSD"
25.02.25  : Added WinRE Support to build WinRE with WiFi Support
25.02.28  : Added SMSTS.ini file to ExtraFiles\Windows folder

.LINK
https://2pintsoftware.com


WHAT YOU NEED TO DO
Manage the script with some variables below, look for:
- $StifleR = $true #this will add the content from your StifleRSource folder and enable that awesome 2Pint Magic
- if you set it to false, you just get BC, which is still something.
- $SkipOptionalComponents = $false #you'll typically want to leave this false unless you're doing some random testing
- $WinPEBuilderPath = Path for where everything happens, this is set automatically based on where the script is running from
#>

<#Random Notes
ADK 24H2 requires a hop step to patch... 
If you got to the MS Catalog and look for the latest Windows 11 24H2 Cumulative Update, when you click on Download, you will see there are 2 files, windows11.0-kb5043080-x64, which is an older CU, and the newest one
You will need to download the older one, and then download the newer one, and then use the older one to patch the WinPE, then use the newer one to patch the OS.
This script will automatically install anything in that CU folder based on the name, so oldest CU to newest.  I keep the KB5043080 in that folder, and replace the other CU with the monthly released CU.
So moral of the story, when you see multiple things in that Download Dialog, grab all of the, and place in the CU folder.

I've had odd behavior with WinRE 24H2, I've been unsuccessful in getting it to patch to the latest CU.  I'd recommend going to Visual Studio Downloads, grabbing the latest release of 24H2 Enterprise, and using that as your source for WinRE.
- Note, I'm still just using the WinRE from the install WIM that this script will automatically download (via the OSD Module), and it's been working, but I haven't tested it with Black Lotus remedated machines, I'd assume it would fail 
I'm not going to explain anymore, read the code, it's all there, if you have questions, hit me up on WinAdmins Discord.
#>

Push-Location

#!!!!!Update these to fit your Needs!!!!!!
$StifleR = $true
$BranchCache = $true
$SkipOptionalComponents = $false
$WinPEBuilderPath = 'D:\WinPEBuilder'
$Drivers = "$WinPEBuilderPath\Drivers"
$ExtraFiles = "$WinPEBuilderPath\ExtraFiles"
$UseWinRE = $false
$AddSMSTSiniFile = $true
$AddDellProvider = $false
$AddHPCMSL = $false
$Add7Zip = $false
$AddOSDModule = $false

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
24.12.25    Reworked a ton of things, will now automtically download the Windows OS needed to grab files from
25.2.25     Added WinRE support for WiFi
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
$SMSTSini = "[Logging]
LOGLEVEL=1
LOGMAXSIZE=5242880
LOGMAXHISTORY=10
DEBUGLOGGING=0
"
$BuildsReadme = "This is where WinPE builds will get staged once they are built."

$OSDToolKitReadme = "For release changes please go to: https://docs.2pintsoftware.com/osd-toolkit/release-notes

For documentation please go to: https://docs.2pintsoftware.com/osd-toolkit/
	
Note: 	The binaries in the Tools in this folder is already included in the WinPEGen.exe binary, 
	but are available here for your convenience when distributing to full OS machines. 
	Please review the documentation for guidance on that.
"

$PatchesReadme = "Place the patch(es) you would like to apply to WinPE in this directory. Make sure they match the OS and architecture of the WinPE you are building."


$StifleRSourceReadme = "Place the StifleR source directory in this folder if incorporating the StifleR client into the WinPE build."

$WiFiSupportReadme = "Place the WiFi support files in this folder if incorporating WiFi support into the WinPE build.
    WiFiConnection.ps1 
    DefaultWiFiProfile.xml (Optional)
    dmcmnutils.dll
    mdmpostprocessevaluator.dll
    mdmregistration.dll

    dll files will get copied automatically from the mounted OS source WIM if needed

"
$DriversWinREReadme = "Place the WinRE drivers in this folder if incorporating WinRE into the WinRE build.
This will typically be the Intel WiFi Drivers (for Adminsitrators) that you'd extract here
Also check driver packs for the models you support and look through the network folder, you might need to support Realtek too"

$DriversWinPEReadme = "Place the WinRE drivers in this folder if incorporating WinRE into the WinRE build
This will be your stardard OEM WinPE Driver Pack"

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
$ADKBuild = $ADKWinPEInfo.Version
$OSNameNeeded = ($Mappings | Where-Object {$_.Build -match $ADKBuild}).OSName
$Lang = ($ADKWinPE.FullName | Split-Path) | Split-Path -Leaf

#Create Folder Structure - ASSUMES everything based on the location you're running this script from.
try {
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\Builds") #This is where WinPE builds will get staged once they are built.
    [void][System.IO.Directory]::CreateDirectory("$Drivers") #Future Version with DISM these in automatically.
    [void][System.IO.Directory]::CreateDirectory("$ExtraFiles") #Files get copied into the boot WIM (Folder Structure Matters)
    [void][System.IO.Directory]::CreateDirectory("$ExtraFiles\ProgramData") #Files get copied into the boot WIM (Folder Structure Matters)
    [void][System.IO.Directory]::CreateDirectory("$ExtraFiles\Windows\System32") #Files get copied into the boot WIM (Folder Structure Matters)
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\OSSource\$OSNameNeeded") #Location for the Install.wim file from the Full OS
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\Patches\CU\$OSNameNeeded") #Location to save your .msu CU files
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\Scratch") #Temp location, has nothing to do with scratching of the itchy kind
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\StifleRSource") #Place the StifleR source directory in this folder if incorporating the StifleR client into the WinPE build.
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\OSDToolkit") #Place OSDToolkit extract here
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\WinRE") #Place OSDToolkit extract here
    [void][System.IO.Directory]::CreateDirectory("$WinPEBuilderPath\WiFiSupport") #Place OSDToolkit extract here
}
catch {throw}
#Build  Files
if ($AddSMSTSiniFile -eq $true){
    if (!(Test-Path "$WinPEBuilderPath\ExtraFiles\Windows\smsts.ini")){
        $SMSTSini | Out-File -FilePath "$WinPEBuilderPath\ExtraFiles\Windows\smsts.ini" -Encoding utf8
    }
}
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
if (!(Test-Path "$WinPEBuilderPath\WiFiSupport\Readme.txt")){
    $WiFiSupportReadme | Out-File -FilePath "$WinPEBuilderPath\WiFiSupport\Readme.txt" -Encoding utf8
}
if (Test-Path -Path "$WinPEBuilderPath"){
    $Files = Get-ChildItem -Path "$WinPEBuilderPath" -Recurse | Where-Object {$_.Attributes -ne "Directory"}
    foreach ($File in $files){
        Unblock-File -Path $File.FullName
    }
}

#Check for Install.WIM, make sure one is already there, if not, it will try to download / build one for you
if (Test-Path -Path "$WinPEBuilderPath\OSSource\$OSNameNeeded\install.wim"){
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




# Set OS Image to get BranchCache binaries from. The OS version (build number, e.g. patch-level) must match boot image version.
# If using a newer Windows 10 image, patch the boot media to same level
$OSSource = "$WinPEBuilderPath\OSSource\$OSNameNeeded\install.wim"

#Build Scratch Area & WinPE / WinRE Area
$Scratch = "$WinPEBuilderPath\Scratch"
$WinPEScratch = "$Scratch\winpe.wim"


#Create Mount Directory and Rebuild if needed
$MountPath = "$WinPEBuilderPath\mount"
# Clean up and create Mount directory
If (Test-Path $MountPath) {
    Write-Host "Cleaning up previous run: $MountPath" -ForegroundColor DarkGray
    Remove-Item $MountPath -Force -Verbose -Recurse | Out-Null    
}
Write-Host "Creating New Folder: $MountPath" -ForegroundColor DarkGray
New-Item $MountPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null


#Clean up Scratch directory
If (Test-Path $Scratch) {
    Write-Host "Cleaning up previous run: $Scratch" -ForegroundColor DarkGray
    Remove-Item $Scratch -Force -Verbose -Recurse | Out-Null
}
Write-Host "Creating New Folder: $Scratch" -ForegroundColor DarkGray
New-Item $Scratch -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

#region WinRE WiFi Stuff
#Building out WinRE for WiFi stuff
if ($UseWinRE){
    $FileSuffix = 'WinRE'
    Write-Host "Building WinRE for WiFi" -ForegroundColor Green
    $WiFiFolder = "$WinPEBuilderPath\WiFiSupport"
    $WinREFolderPath = "$WinPEBuilderPath\WinRE"
    $WinRESourceOriginal = "$WinREFolderPath\WinREOrginial.WIM" #This should never be modified, this will be the one we use as a baseline to update again and again as changes are made
    $WinRESource = "$WinREFolderPath\WinRE.wim" #This is the one that will be created based on the $FixWinRE section
    If (!(Test-path -Path "$WinRESourceOriginal")){
        $FixWinRE = $true
        Mount-WindowsImage -ImagePath $OSSource -Index $ImageIndexNumber -Path $MountPath
        $WinRESourceMounted = Get-Childitem -Path $MountPath\Windows\System32\Recovery -Filter *.wim
        Copy-Item -Path $WinRESourceMounted.FullName -Destination $WinRESourceOriginal -Force
        if (!(Test-Path "$WinPEBuilderPath\WiFiSupport\mdmregistration.dll")){
            Copy-Item -path "$MountPath\Windows\System32\mdmregistration.dll" -Destination "$WinPEBuilderPath\WiFiSupport" -Force
        }
        if (!(Test-Path "$WinPEBuilderPath\WiFiSupport\mdmpostprocessevaluator.dll")){
            Copy-Item -path "$MountPath\Windows\System32\mdmpostprocessevaluator.dll" -Destination "$WinPEBuilderPath\WiFiSupport" -Force
        }
        if (!(Test-Path "$WinPEBuilderPath\WiFiSupport\dmcmnutils.dll")){
            Copy-Item -path "$MountPath\Windows\System32\dmcmnutils.dll" -Destination "$WinPEBuilderPath\WiFiSupport" -Force
        }
        Dismount-WindowsImage -Path $MountPath -Discard
    }
    if (Test-Path -Path "$WinPEBuilderPath\WiFiSupport\DefaultWiFiProfile.xml"){
        $DefaultWifiProfile = "$WinPEBuilderPath\WiFiSupport\DefaultWiFiProfile.xml"
    }
}
else {
    $FileSuffix = 'WinPE'
    $FixWinRE = $false
}
if ($FixWinRE) {
    # Restore boot image from backup copy
    If (Test-Path $WinRESourceOriginal){
        If (Test-Path $WinPEScratch) {Remove-Item $WinPEScratch -Force}
        Copy-item $WinRESourceOriginal $WinPEScratch
    }
    
    Write-Host "Mounting boot image to do some cleanup"
    Mount-WindowsImage -ImagePath $WinPEScratch -Index 1 -Path $MountPath
    
    if (Test-Path "$MountPath\Windows\System32\winpeshl.ini") {
        Write-Host "Removing winpeshl.ini to avoid going in to recovery menu"
        Remove-Item "$MountPath\Windows\System32\winpeshl.ini"
    }
    
    
    # Path to the external registry hive
    Write-Host "Cleaning registry to be able to successfully run WinPEGen"
    $RegistryFilePath = "$MountPath\Windows\System32\config\SOFTWARE"
    
    # Keys to take ownership of and delete
    $KeysToDelete = @(
    "Classes\AppID\BITS",
    "Classes\AppID\{69AD4AEE-51BE-439b-A92C-86AE490E8B30}",
    "Classes\CLSID\{1ecca34c-e88a-44e3-8d6a-8921bde9e452}",
    "Classes\CLSID\{4bd3e4e1-7bd4-4a2b-9964-496400de5193}",
    "Classes\CLSID\{4d233817-b456-4e75-83d2-b17dec544d12}",
    "Classes\CLSID\{4991d34b-80a1-4291-83b6-3328366b9097}",
    "Classes\CLSID\{5CE34C0D-0DC9-4C1F-897C-DAA1B78CEE7C}",
    "Classes\CLSID\{6d18ad12-bde3-4393-b311-099c346e6df9}",
    "Classes\CLSID\{659cdea7-489e-11d9-a9cd-000d56965251}",
    "Classes\CLSID\{69AD4AEE-51BE-439b-A92C-86AE490E8B30}",
    "Classes\CLSID\{03ca98d6-ff5d-49b8-abc6-03dd84127020}",
    "Classes\CLSID\{bb6df56b-cace-11dc-9992-0019b93a3a84}",
    "Classes\CLSID\{F087771F-D74F-4C1A-BB8A-E16ACA9124EA}",
    "Classes\Interface\{37668D37-507E-4160-9316-26306D150B12}",
    "Classes\Interface\{54B50739-686F-45EB-9DFF-D6A9A0FAA9AF}",
    "Classes\Interface\{5CE34C0D-0DC9-4C1F-897C-DAA1B78CEE7C}",
    "Classes\Interface\{1AF4F612-3B71-466F-8F58-7B6F73AC57AD}",
    "Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\Microsoft-OneCore-BITS-Client-Package~31bf3856ad364e35~amd64~~$($ADKBuild)\Owners",
    "Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\Microsoft-OneCore-BITS-Client-Package~31bf3856ad364e35~amd64~en-US~$($ADKBuild)\Owners"
    )
    
    # Keys to modify
    $KeysToModify = @(
    "Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\Microsoft-OneCore-BITS-Client-Package~31bf3856ad364e35~amd64~en-US~$($ADKBuild)",
    "Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\Microsoft-OneCore-BITS-Client-Package~31bf3856ad364e35~amd64~~$($ADKBuild)"
    )
    
    # Temporary mount point for the registry hive
    $TempKey = "HKLM\TempHive"
    
    # Get SeTakeOwnership, SeBackup and SeRestore privileges before executes next lines, script needs Admin privilege
    $import = '[DllImport("ntdll.dll")] public static extern int RtlAdjustPrivilege(ulong a, bool b, bool c, ref bool d);'
    $ntdll = Add-Type -Member $import -Name NtDll -PassThru
    $privileges = @{ SeTakeOwnership = 9; SeBackup =  17; SeRestore = 18 }
    foreach ($i in $privileges.Values) {
        $null = $ntdll::RtlAdjustPrivilege($i, 1, 0, [ref]0)
    }
    
    
    function Set-RegistryKeyOwnership {
        param (
        [Parameter(Mandatory)]
        [string]$RegistryKeyPath
        )
        
        # Set current user as owner
        $Owner = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        # Apply new security descriptor
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($RegistryKeyPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::takeownership)
        $acl = New-Object System.Security.AccessControl.RegistrySecurity
        $acl.SetOwner([System.Security.Principal.NTAccount]"$Owner")
        $key.SetAccessControl($acl)
        
        $acl = $key.GetAccessControl()
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule ("$Owner","FullControl","Allow")
        $acl.AddAccessRule($rule)
        $key.SetAccessControl($acl)
        $key.Close()
        
        # Now handle subkeys recursively
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($RegistryKeyPath, $true)
        
        # Get the list of subkeys under the current registry key
        $subKeys = $key.GetSubKeyNames()
        
        if ($subKeys) {
            # Loop through each subkey and apply the same process
            foreach ($subKey in $subKeys) {
                # Recursively call the function to take ownership of the subkey
                Set-RegistryKeyOwnership -RegistryKeyPath "$RegistryKeyPath\$subKey"
            }
            
            # Close the key after processing subkeys
            $key.Close()
        }
        
    }
    
    try {
        # Mount the registry hive
        Write-Host "Loading registry hive..."
        reg.exe load $TempKey $RegistryFilePath
        
        # Loop through each key to take ownership and delete
        foreach ($Key in $KeysToDelete) {
            $FullKeyPath = "$TempKey\$Key"
            $ShortKey = $FullKeyPath -replace '^HKLM\\', ''
            Write-Host "Processing key: $FullKeyPath"
            
            if (-not (Test-Path "Registry::$FullKeyPath")) {
                Write-Host "Key does not exist: $FullKeyPath" -ForegroundColor Green
                continue
            }
            
            if ((Test-Path "Registry::$FullKeyPath")) {
                # Take ownership
                Write-Host "Taking ownership of $FullKeyPath..."
                Set-RegistryKeyOwnership -RegistryKeyPath $ShortKey
                
                
                # Delete the key
                Write-Host "Deleting key: $FullKeyPath..."
                Remove-Item -Path "Registry::$FullKeyPath" -Recurse -Force
            }
        }
        # Loop through each key to modify
        foreach ($Key in $KeysToModify) {
            $FullKeyPath = "$TempKey\$Key"
            $ShortKey = $FullKeyPath -replace '^HKLM\\', ''
            
            $ValueName = "Visibility" 
            $NewValue = 1
            
            if ((Test-Path "Registry::$FullKeyPath")) {
                Write-Host "Processing key: $FullKeyPath"
                $CheckValue = (Get-ItemProperty -Path HKLM:\$ShortKey -Name $ValueName).Visibility
                if ($CheckValue -ne $NewValue) {
                    Write-Host "Seems like it has the wrong value. Lets fix it"
                    Set-ItemProperty -Path HKLM:\$ShortKey -Name $ValueName -Value $NewValue
                }
                else {
                    Write-Host "Value correct. Nothing to do here"
                }
            }
        }
    }
    catch {
        Write-Error "An error occurred: $_"
    }
    finally {
        # Unmount the registry hive
        Write-Host "Unloading registry hive..."
        [gc]::Collect()
        Start-Sleep -Seconds 2
        reg.exe unload $TempKey
        Write-Host "Registry hive processing completed."
    }
    
    
    # Set the features to disable to save some space
    $featuresToDisable = @(
    "Microsoft-Windows-WinPE-Speech-TTS-Package",
    "Microsoft-Windows-WinPE-ATBroker-Package",
    "Microsoft-Windows-WinPE-Narrator-Package",
    "Microsoft-Windows-WinPE-AudioDrivers-Package",
    "Microsoft-Windows-WinPE-AudioCore-Package",
    "Microsoft-Windows-WinPE-SRH-Package"
    )
    
    
    if ($featuresToDisable.Count -gt 0) {
        Write-Host "Removing unnecessary features"
        foreach ($feature in $featuresToDisable) {
            Write-Host "Removing $feature"
            & DISM /Image:$MountPath /Disable-Feature /FeatureName:$feature /Remove > $null 2>&1
        }
    }
    
    #Perform cleanup
    Write-Host "Cleaning up bootimage"
    & DISM /Image:$MountPath /Cleanup-Image /RestoreHealth /StartComponentCleanup /ResetBase > $null 2>&1
    #>
    
    if ($DefaultWifiProfile) {
        Write-Host "Copying default wifi profile"
        Copy-Item -Path $DefaultWifiProfile -Destination "$MountPath\Windows\System32" -Force
    }
    
    if ($Cert) {
        Write-Host "Copying root certificate"
        Copy-Item -Path $Cert -Destination "$MountPath\Windows\System32" -Force
    }
    
    #DLLs needed to support wifi
    $DLLs = Get-ChildItem -Path $WifiFolder -Filter *.dll
    foreach ($DLL in $DLLs) {
        Write-Host "Copying $($DLL)"
        Copy-Item -Path $DLL.FullName -Destination "$MountPath\Windows\System32" -Force
    }
    
    #iPXEinjectfile seems to be broken for 26100. Otherwise the injection of this script would be handled from there
    #Copy-Item -Path "F:\2Pint-WinRE Builder\WifiSupport\WifiConnection.ps1" -Destination "$MountPath\Windows\System32" -Force
    
    Dismount-WindowsImage -Path $MountPath -Save
    $TempWim = "$($WinPEScratch).temp"
    Export-WindowsImage -SourceImagePath $WinPEScratch -SourceIndex 1 -DestinationImagePath $TempWim -CompressionType Maximum
    Move-Item -Path $TempWim -Destination $WinPEScratch -Force
    Copy-Item -Path $WinPEScratch -Destination "$WinRESource" -Force
    
}

#endregion WinRE WiFi Stuff

#Set the Source for the WinPE(RE) being used
$WinPESource = $ADKWinPE.FullName
if ($UseWinRE){$WinPESource = $WinRESource}

# Get the StifleR Client files from a full Windows StifleR client install (copy entire folder)
$StifleRSource = "$WinPEBuilderPath\StifleRSource"

# Get the StifleR Client config file from a full Windows client 
$StifleRClientRules = "$StifleRSource\StifleR.ClientApp.exe.Config"

# List indexes in WIM Image
# Get-WindowsImage -ImagePath $Windows11Media

# Set other parameters
$ExportPath = "$WinPEBuilderPath\Builds"
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

#Confirm Clean up
If (Test-Path $Scratch) {
    Write-Host "Cleaning up previous run: $Scratch" -ForegroundColor DarkGray
    Remove-Item $Scratch -Force -Verbose -Recurse | Out-Null
}
Write-Host "Creating New Folder: $Scratch" -ForegroundColor DarkGray
New-Item $Scratch -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

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





Mount-WindowsImage -ImagePath $WinPEScratch -Index $WinPEIndex -Path $MountPath

#Add Optional Components
#Configuration Manager boot image required components

if ((Test-Path "$ADKPath\WinPE_OCs\WinPE-Scripting.cab") -and ($SkipOptionalComponents -ne $true)){
    #Scripting (WinPE-Scripting)
    try {
        Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\WinPE-Scripting.cab" -Path $MountPath -Verbose
        Add-WindowsPackage -PackagePath "$ADKPath\WinPE_OCs\en-us\WinPE-Scripting_en-us.cab" -Path $MountPath -Verbose
    }
    catch {
        Write-Host "Failed to add WinPE Components" -ForegroundColor Red
        dismount-WindowsImage -Path "D:\WinPEBuilder\mount" -Discard
        Exit 1
    }
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
$SSUPath = "D:\WinPEBuilder\Patches\SSU\SSU-26100.1738-x64.cab"
If ($SSUPath) {Add-WindowsPackage -Path $MountPath -PackagePath $SSUPath -Verbose}

#Apply LCU
$CU_MSU = Get-ChildItem -Path "$WinPEBuilderPath\Patches\CU\$OSNameNeeded" -Filter *.msu -ErrorAction SilentlyContinue

if ($CU_MSU){
    if ($CU_MSU.count -gt 1){
        $CU_MSU = $CU_MSU | Sort-Object -Property Name #| Select-Object -Last 1
    }
    Write-Host -ForegroundColor DarkGray "-----------------------------------------------------"
    foreach ($CU in $CU_MSU){
        $AVailableCU = ($CU.Name).split("_")[0]
        Write-Host -ForegroundColor Green "Available CU Found: $AvailableCU"
    }
    Write-Host -ForegroundColor DarkGray "-----------------------------------------------------"
    foreach ($CU in $CU_MSU){
        Write-Host -ForegroundColor Yellow "Found CU: $($CU.Name)"
        $PatchPath = $CU.FullName
        If ($PatchPath) {
            $AvailableCU = $PatchPath
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
If (Test-Path -Path $Drivers\*){
    if (Test-Path -Path "$Drivers\WinPE"){
        $DriverPath = "$Drivers\WinPE"
        Write-Host "Injecting Drivers from $DriverPath"
        #Apply-WindowsDriver -Path $MountPath -Driver $DriverPath -Recurse -Verbose
        & DISM /Image:$MountPath /Add-Driver /Driver:$DriverPath /Recurse /ForceUnsigned /LogPath:$WinPEBuilderPath\Drivers.log
    }
    if ($UseWinRE){
        Write-Host "Adding additional drivers for WinRE Builds (WiFi)"
        if (Test-Path -Path "$Drivers\WinRE"){
            $DriverPath = "$Drivers\WinRE"
            Write-Host "Injecting Drivers from $DriverPath"
            #Apply-WindowsDriver -Path $MountPath -Driver $DriverPath -Recurse -Verbose
            & DISM /Image:$MountPath /Add-Driver /Driver:$DriverPath /Recurse /ForceUnsigned /LogPath:$WinPEBuilderPath\Drivers.log
        }
    }

    
}
#Verify added packages
Get-WindowsPackage -Path $MountPath

if ($Add7Zip -eq $true){
    #region Do more stuff here leveraging OSDCloud Stuff - Requires OSD Module
    Write-Host -ForegroundColor DarkGray "========================================================================="
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
}
if ($AddOSDModule -eq $true){
    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor Yellow "Saving OSD Module to $MountPath\Program Files\WindowsPowerShell\Modules"
    Save-Module -Name OSD -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
}
if ($AddHPCMSL -eq $true){
    Write-Host -ForegroundColor DarkGray "========================================================================="
    $Module = 'HPCMSL'
    Write-Host -ForegroundColor Yellow "Saving $Module to $MountPath\Program Files\WindowsPowerShell\Modules"
    Save-Module -Name $Module -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force -AcceptLicense
}
if ($AddDellProvider -eq $true){
    Write-Host -ForegroundColor DarkGray "========================================================================="
    $Module = 'DellBiosProvider'
    Write-Host -ForegroundColor Yellow "Saving $Module to $MountPath\Program Files\WindowsPowerShell\Modules"
    if ($Module -eq 'DellBiosProvider') {
        if (Test-Path "$env:SystemRoot\System32\msvcp140.dll") {
            Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Copying $env:SystemRoot\System32\msvcp140.dll to WinPE"
            Copy-Item -Path "$env:SystemRoot\System32\msvcp140.dll" -Destination "$MountPath\Windows\System32\msvcp140.dll" -Force | Out-Null
        }
        if (Test-Path "$env:SystemRoot\System32\vcruntime140.dll") {
            Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Copying $env:SystemRoot\System32\vcruntime140.dll to WinPE"
            Copy-Item -Path "$env:SystemRoot\System32\vcruntime140.dll" -Destination "$MountPath\Windows\System32\vcruntime140.dll" -Force | Out-Null
        }
        if (Test-Path "$env:SystemRoot\System32\vcruntime140_1.dll") {
            Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Copying $env:SystemRoot\System32\vcruntime140_1.dll to WinPE"
            Copy-Item -Path "$env:SystemRoot\System32\vcruntime140_1.dll" -Destination "$MountPath\Windows\System32\vcruntime140_1.dll" -Force | Out-Null
        }
        Save-Module -Name $Module -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
    }
}
if ($UseWinRE){
    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor Yellow "Downloading https://github.com/okieselbach/Helpers/raw/master/WirelessConnect/WirelessConnect/bin/Release/WirelessConnect.exe"
    Save-WebFile -SourceUrl 'https://github.com/okieselbach/Helpers/raw/master/WirelessConnect/WirelessConnect/bin/Release/WirelessConnect.exe' -DestinationDirectory "$MountPath\Windows" | Out-Null
}
# Set PowerShell Execution Policy
Write-Host -ForegroundColor DarkGray "========================================================================="
Write-Host -ForegroundColor Yellow "OSD Function: Set-WindowsImageExecutionPolicy"
Set-WindowsImageExecutionPolicy -Path $MountPath -ExecutionPolicy Bypass | Out-Null
# Enable PowerShell Gallery
Write-Host -ForegroundColor DarkGray "========================================================================="
Write-Host -ForegroundColor Yellow "OSD Function: Enable-PEWindowsImagePSGallery"
Enable-PEWindowsImagePSGallery -Path $MountPath | Out-Null
#endregion



#Unmount boot image
Write-Host -ForegroundColor DarkGray "========================================================================="
Write-Host -ForegroundColor Yellow "Process: Dismount-WindowsImage -Path $MountPath -Save"
Dismount-WindowsImage -Path $MountPath -Save

#Get build info
$BuildNumber = (Get-WindowsImage -ImagePath $WinPEScratch -Index 1).Version
write-output "Build Number: $BuildNumber"



#Export boot image to reduce the size
If ($StifleR) {
    Export-WindowsImage -SourceImagePath $WinPEScratch -SourceIndex 1 -DestinationImagePath "$ExportPath\winpe.$($BuildNumber)_$(get-date -format "yy.MM.dd")_StifleR_$($FileSuffix).wim" -Verbose
}
Elseif ($BranchCache) {
    Export-WindowsImage -SourceImagePath $WinPEScratch -SourceIndex 1 -DestinationImagePath "$ExportPath\winpe.$($BuildNumber)_$(get-date -format "yy.MM.dd")_BC_$($FileSuffix).wim" -Verbose
}
Else {
    Export-WindowsImage -SourceImagePath $WinPEScratch -SourceIndex 1 -DestinationImagePath "$ExportPath\winpe.$($BuildNumber)_$(get-date -format "yy.MM.dd")_$($FileSuffix).wim" -Verbose
}
Pop-Location