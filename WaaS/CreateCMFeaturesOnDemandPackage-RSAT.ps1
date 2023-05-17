<#
@gwblok @recastsoftware

This script will mount the Features on Demand ISO, copy the RSAT Required Files to your CM Source Share (You update the $PackageSource Variable),
Then Creates the CM Package and Pre-cache Program (which is needed for dynamic downloads in a TS removing the need to have a direct reference)

Grabbing Cabs from FoD ISO Script adapted from: https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/rsat-on-windows-10-1809-in-disconnected-environments/ba-p/570833

Feature On Demand Info: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-non-language-fod

#>

# Site configuration
$SiteCode = "PS2" # Site code 
$ProviderMachineName = "CM.corp.viamonstra.com" # SMS Provider machine name

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName
}

Set-Location "c:\"

#Windows Build
$Build = '20H2'

#Language desired
$lang = "en-US"

#Source Folder for RSAT Package
$PackageSource = "\\src\src$\OSD\Packages\FeaturesOnDemand\$Build\RSAT"

#Specify ISO Source location
$FoD_Source = "\\src\src$\LanguageSupport\2004\ISOs\en_windows_10_features_on_demand_part_1_version_2004_x64_dvd_7669fc91.iso"

#Mount ISO
Write-host "Mounting Disc $FoD_Source" -ForegroundColor Green
Mount-DiskImage -ImagePath "$FoD_Source"
$path = (Get-DiskImage "$FoD_Source" | Get-Volume).DriveLetter

#Create RSAT folder Source
$dest = New-Item -ItemType Directory -Path $PackageSource -force
Write-Host "Creating $PackageSource Folder to copy files to" -ForegroundColor Green

#Get RSAT files from Mounted ISO and Copy to Package Source Folder
Write-Host "Gathering Features on Demand Files into Array" -ForegroundColor Green
$RSATFiles = Get-ChildItem ($path+":\") -name -recurse -include *~amd64~~.cab,*~wow64~~.cab,*~amd64~$lang~.cab,*~wow64~$lang~.cab -exclude *languagefeatures*,*Holographic*,*NetFx3*,*OpenSSH*,*Msix*,*XPS*,*WirelessDisplay*,*TabletPCMath*,*UserExperience*,*StepsRecorder*,*Noteapad*,*PowerShell*,*MSPaint*,*InternetExplorer*,*WebDriver*,*OneCore*,*WordPad*
ForEach ($RSATFile in $RSATFiles){
    copy-item -Path ($path+":\"+$RSATFile) -Destination $dest.FullName -Force -Container -Verbose
    }

#Get metadata files and copy to Package Source
Write-Host "Copy MetaData to Package Source" -ForegroundColor Green
copy-item ($path+":\metadata") -Destination $dest.FullName -Recurse -Force -Verbose
copy-item ($path +":\"+“FoDMetadata_Client.cab") -Destination $dest.FullName -Force -Container -Verbose

#Dismount ISO
Write-host "Dismounting Disc $FoD_Source" -ForegroundColor Green
Dismount-DiskImage -ImagePath "$FOD_Source"

#Start CM Package Creation
Set-Location "$($SiteCode):\"
$DPGroups = (Get-CMDistributionPointGroup).Name #Currently this is setup to Distribute to ALL DP Groups

if ($TestPackage = Get-CMPackage -Name "$Build Features on Demand - RSAT" -Fast){
    write-host " Found Package: $($TestPackage.Name), Confirming Settings" 
    if ($TestPackage.PkgSourcePath -ne $PackageSource)
        {
        write-host "  Updating Path to: $PackageSource" -ForegroundColor Yellow
        Set-CMPackage -InputObject $TestPackage -Path $PackageSource
        }
    else{write-host "  Path Set Correctly: $PackageSource" -ForegroundColor Green}
    if ($TestPackage.Version -ne $Build)
        {
        write-host "  Updating Version to: $Build" -ForegroundColor Yellow
        Set-CMPackage -InputObject $TestPackage -Version $Build
        }
        if ($TestPackage.Language -ne $Lang)
        {
        write-host "  Updating Language to: $lang" -ForegroundColor Yellow
        Set-CMPackage -InputObject $TestPackage -Language $lang
        }
    }
else
    {
    Write-Host " Creating: $Build Features on Demand RSAT Package" -ForegroundColor Magenta
        
    #Create Package Content
    $Readme = {Feature on Demand CABS for RSAT}
    Set-Location "c:\"
    New-Item -Path $PackageSource -Name "Readme.txt" -ItemType file -Value $Readme -Force |Out-Null
    Set-Location "$($SiteCode):\"

    #Create CM Package
    $NewPackage = New-CMPackage -Name "$Build Features on Demand - RSAT" -Version $Build -Language $Lang -Path $PackageSource -Description "Features on Demand Cabs for RSAT"
    foreach ($Group in $DPGroups) #Distribute Content
        {
        Write-host " Starting Distribution to DP Group $Group" -ForegroundColor Magenta
        Start-CMContentDistribution -InputObject $NewPackage -DistributionPointGroupName $Group
        }
    #Create Program for Package
    Write-Host "Creating Pre-cache Program on Package" -ForegroundColor Green
    $NewProgram = New-CMProgram -PackageName $NewPackage.Name -CommandLine "cmd.exe /c" -StandardProgramName "Pre-cache" -RunType Hidden -DiskSpaceRequirement "50" -ProgramRunType WhetherOrNotUserIsLoggedOn -RunMode RunWithAdministrativeRights
    Set-CMProgram -InputObject $NewProgram -StandardProgram -ProgramName "Pre-cache" -EnableTaskSequence $true
       
    }

