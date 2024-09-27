<# Gary Blok - GARYTOWN.COM
    24.09.24 - Gary Blok Initial Version
    This script will take a Dell Tech Direct Catalog and update the CM Package with the latest drivers in WIM Format

    Variables to Update:
    $SiteCode - Your ConfigMgr Site Code

    This assumes you've created the CM Packages using my method
    https://github.com/gwblok/garytown/blob/master/hardware/CreateCMPackages_BIOS_Drivers.ps1



#>

$CatalogVersion = "Windows 11" #This is what you set in Dell Tech Direct Portal
$ScatchLocation = "E:\DedupExclude"
$DismScratchPath = "$ScatchLocation\DISM"
$SiteCode = "2CM"
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)

Set-Location -Path $env:SystemDrive
#Point to the Catalog Zip File Downloaded - File you created from Dell Tech Direct Portal and downloaded (zip file)
$ZipFilePath = "C:\Users\gary.blok\Downloads\b8492d9e-2d39-4166-af01-32e53d87f0f0.zip"
$ZipFileItem = Get-Item -Path $ZipFilePath

#Create Temp Working area and extract Zip File
$TempWorkingPath = "c:\windows\temp\Dell\$($($ZipFileItem.Name).Split(".")[0])"
if (!(Test-Path -Path $TempWorkingPath)){New-Item -Path $TempWorkingPath -ItemType Directory -Force | Out-Null}
Expand-Archive -Path $ZipFilePath -DestinationPath $TempWorkingPath -Force

#Find SystemID for the Model supported by this Catalog - MAKE SURE YOU HAVE A BIOS IN THE CATALOG when you create it on Dell Tech Direct Portal
$XMLFile = Get-ChildItem -Path $TempWorkingPath -Filter *.xml
[XML]$XML = Get-Content -Path $XMLFile.FullName 
$BIOS = $XML.Manifest.SoftwareComponent | Where-Object {$_.Category.Display.'#cdata-section' -eq "BIOS"}
$SystemID = $BIOS.SupportedSystems.Brand.Model.systemID


#Connect to CM and find Package to Update
Set-Location -Path "$($SiteCode):"
#$CMPackage = Get-CMPackage -Fast -Name *Dell* | Where-Object {$_.Language -eq $SystemID}
$Package2Update = Get-CMPackage -Fast -Name "*Repo*" | Where-Object {$_.Manufacturer -eq "Dell" -and $_.Language -in $SystemID} | Select-Object -Property "Name","MIFFilename","PackageID", "Version", "MifVersion" | Out-GridView -Title "Select the Package you want to Update" -PassThru 
$CMPackage = Get-CMPackage -Fast -Id $Package2Update.PackageID

#Find Repo Builder & Build Argument List
Set-Location -Path $env:SystemDrive
$RepoBuilderExe = Get-ChildItem -Path $TempWorkingPath -Filter *.exe
$Process = $RepoBuilderExe.FullName
$RepoArgs = "-c `"$($XMLFile.FullName)`" -b C:\Drivers\UpdateRepo"

#Run Repo Builder
Set-Location -Path $TempWorkingPath
$RunRepoBuild = Start-Process -FilePath $Process -ArgumentList $RepoArgs -Wait -PassThru

#GetRepoSourcePath
$PackageSourcePath = $CMPackage.PkgSourcePath

#WIM Expanded Files
# Cleanup Previous Runs (Deletes the files)
if (Test-Path $dismscratchpath) {Remove-Item $DismScratchPath -Force -Recurse -ErrorAction SilentlyContinue}
$DismScratch = New-Item -Path $DismScratchPath -ItemType Directory -Force
if (Test-Path -Path "$PackageSourcePath\Drivers.wim"){
    Remove-Item -Path "$PackageSourcePath\Drivers.wim"
}
New-WindowsImage -ImagePath "$PackageSourcePath\Drivers.wim" -CapturePath "$TempWorkingPath" -Name "$($CMPackage.MIFFilename) - $($CMPackage.Language)"  -LogPath "$env:TEMP\dism-$($CMPackage.MIFFilename).log" -ScratchDirectory $dismscratchpath
Copy-Item -Path $XMLFile.FullName -Destination $PackageSourcePath

Set-Location -Path "$($SiteCode):"
Set-CMPackage -Id $CMPackage.PackageID -Version $CatalogVersion 
Set-CMPackage -Id $CMPackage.PackageID -MifPublisher ($env:USERNAME)
Set-CMPackage -Id $CMPackage.PackageID -Description "Tech Direct Portal"
Set-CMPackage -Id $CMPackage.PackageID -MifVersion (Get-Date -Format yyyy-MM-dd)
Update-CMDistributionPoint -PackageId $CMPackage.PackageID