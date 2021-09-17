<# @gwblok
This will look at CM, grabs the DELL BIOS Packages, then update them (if needed) based on the Dell Command Update XML it downloads.
Packages in CM Must be setup to follow this process: https://github.com/gwblok/garytown/blob/master/hardware/CreateCMPackages_BIOS_Drivers.ps1
If you used that script to create the packages, then this script will work.

Basically, this script grabs XML from Dell, find the Model for the BIOS you're looking for, then it grabs the Model Specific XML and looks through that to find the latest BIOS to download
This script still contains some of the code from the old method of using the Enterprise Cab XML to find BIOS, but that XML is very stale and is way behind the website.
#>

[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false,Position=1,HelpMessage="Stage")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("Pre-Prod", "Prod")]
		    $Stage
 	    )



$scriptName = $MyInvocation.MyCommand.Name
$CabPath = "$PSScriptRoot\DellCabDownloads\DellSDPCatalogPC.cab"
$CabPathIndex = "$PSScriptRoot\DellCabDownloads\CatalogIndexPC.cab"
$CabPathIndexModel = "$PSScriptRoot\DellCabDownloads\CatalogIndexModel.cab"
$DellCabExtractPath = "$PSScriptRoot\DellCabDownloads\DellCabExtract"
$SiteCode = "PS2"


Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"

#Pick Stage
if (!($Stage)){$Stage = "Prod", "Pre-Prod" | Out-GridView -Title "Select the Stage you want to update" -PassThru}


#To Select
$DellModelsSelectTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.Manufacturer -eq "Dell" -and $_.Mifname -eq $Stage} |Select-Object -Property "Name","MIFFilename","PackageID", "Version" | Sort-Object $_.MIFFilename | Out-GridView -Title "Select the Models you want to Update" -PassThru
$DellModelsTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.PackageID -in $DellModelsSelectTable.PackageID}


#Testing Specific Model
#$DellModelsTable = Get-CMPackage -Fast -Id "PS20041A"
Set-Location -Path "C:"

Write-Host "Downloading Dell Cab" -ForegroundColor Yellow
#Invoke-WebRequest -Uri "http://downloads.dell.com/catalog/DellSDPCatalogPC.cab" -OutFile $CabPath -UseBasicParsing -Verbose -Proxy $ProxyServer
Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/CatalogIndexPC.cab" -OutFile $CabPathIndex -UseBasicParsing -Verbose -Proxy $ProxyServer
[int32]$n=1
While(!(Test-Path $CabPathIndex) -and $n -lt '3')
    {
    #Invoke-WebRequest -Uri "http://downloads.dell.com/catalog/DellSDPCatalogPC.cab" -OutFile $CabPath -UseBasicParsing -Verbose -Proxy $ProxyServer
    Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/CatalogIndexPC.cab" -OutFile $CabPathIndex -UseBasicParsing -Verbose -Proxy $ProxyServer
    $n++
    }
If(Test-Path "$PSScriptRoot\DellSDPCatalogPC.xml"){Remove-Item -Path "$PSScriptRoot\DellSDPCatalogPC.xml" -Force -Verbose}
Start-Sleep -Seconds 1
if (test-path $DellCabExtractPath){Remove-Item -Path $DellCabExtractPath -Force -Recurse}
New-Item -Path $DellCabExtractPath -ItemType Directory
Write-Host "Expanding the Cab File....." -ForegroundColor Yellow
#$Expand = expand $CabPath -F:DellSDPCatalogPC.xml $DellCabExtractPath
$Expand = expand $CabPathIndex $DellCabExtractPath\CatalogIndexPC.xml

write-host "Loading Dell Catalog XML.... can take awhile" -ForegroundColor Yellow
#[xml]$XML = Get-Content "$DellCabExtractPath\DellSDPCatalogPC.xml" -Verbose
[xml]$XMLIndex = Get-Content "$DellCabExtractPath\CatalogIndexPC.xml" -Verbose


foreach ($Model in $DellModelsTable) #{Write-Host "Starting to Process Model: $($Model.MifFileName)" -ForegroundColor Green}
    {
    #Reset Vars
    $PackageVersion = $null
    $TargetLink = $null
    $TargetFileName = $null
    $SourceSharePackageLocation = $null
    $TargetFilePathName = $null
    $DCUBIOSVersion = $null
    $DCUBIOSLatestVersion = $null
    $DCUBIOSAvailable = $null
    $DCUBIOSAvailableVersions = $null
    $DCUBIOSReleaseDate = $null
    $SystemTypeID = $null
    $SystemSKU = $null
    $SystemTypeID = ($Model.Language).split("-")[0]
    $SystemSKU = ($Model.Language).split("-")[1]

    Write-Host "----------------------------" -ForegroundColor DarkGray
    Write-Host "Starting to Package: $($Model.Name)" -ForegroundColor Green
    Write-Host " Current BIOS Version: $($Model.Version) from $($Model.MIFPublisher)" -ForegroundColor Green
    
    if ($Model.Version -match "A"){$PackageVersion = $Model.Version}
    if ($Model.Version -ne $null -and $Model.Version -ne "" -and $Model.Version -notmatch "A"){[System.Version]$PackageVersion = $Model.Version}
        
    $XMLModel = $XMLIndex.ManifestIndex.GroupManifest | Where-Object {$_.SupportedSystems.Brand.Model.systemID -match $SystemSKU}
    if ($XMLModel)
        {
        Invoke-WebRequest -Uri "http://downloads.dell.com/$($XMLModel.ManifestInformation.path)" -OutFile $CabPathIndexModel -UseBasicParsing -Verbose -Proxy $ProxyServer
        if (Test-Path $CabPathIndexModel)
            {
            $Expand = expand $CabPathIndexModel $DellCabExtractPath\CatalogIndexPCModel.xml
            [xml]$XMLIndexCAB = Get-Content "$DellCabExtractPath\CatalogIndexPCModel.xml" -Verbose
            $DCUBIOSAvailable = $XMLIndexCAB.Manifest.SoftwareComponent | Where-Object {$_.ComponentType.value -eq "BIOS"}
            $DCUBIOSAvailableVersionsRAW = $DCUBIOSAvailable.dellversion

            if ($DCUBIOSAvailableVersionsRAW[0] -match "A")
                {
                [String[]]$DCUBIOSAvailableVersions = $DCUBIOSAvailableVersionsRAW
                $DCUBIOSLatestVersion = $DCUBIOSAvailableVersions | Sort-Object | Select-Object -Last 1
                $DCUBIOSLatest = $DCUBIOSAvailable | Where-Object {$_.dellversion -eq $DCUBIOSLatestVersion}
                [String]$DCUBIOSVersion = $DCUBIOSLatest.dellVersion
                }

            if ($DCUBIOSAvailableVersionsRAW[0] -ne $null -and $DCUBIOSAvailableVersionsRAW[0] -ne "" -and $DCUBIOSAvailableVersionsRAW[0] -notmatch "A")
                {
                [System.Version[]]$DCUBIOSAvailableVersions = $DCUBIOSAvailableVersionsRAW
                $DCUBIOSLatestVersion = $DCUBIOSAvailableVersions | Sort-Object | Select-Object -Last 1
                $DCUBIOSLatest = $DCUBIOSAvailable | Where-Object {$_.dellversion -eq $DCUBIOSLatestVersion}
                [System.Version]$DCUBIOSVersion = $DCUBIOSLatest.dellVersion
                }              
                
            $DCUBIOSLatestVersion = $DCUBIOSAvailableVersions | Sort-Object | Select-Object -Last 1
            $DCUBIOSLatest = $DCUBIOSAvailable | Where-Object {$_.dellversion -eq $DCUBIOSLatestVersion}
            $DCUBIOSVersion = $DCUBIOSLatest.dellVersion
            $DCUBIOSReleaseDate = $(Get-Date $DCUBIOSLatest.releaseDate -Format 'yyyy-MM-dd')               
            $TargetLink = "http://downloads.dell.com/$($DCUBIOSLatest.path)"
            $TargetFileName = ($DCUBIOSLatest.path).Split("/") | Select-Object -Last 1
            if ($DCUBIOSVersion -gt $PackageVersion)
                {
                Write-Host " New BIOS Update available: Package = $($Model.Version), DCU = $DCUBIOSVersion" -ForegroundColor Yellow 
                Write-Output "  Title: $($DCUBIOSLatest.Name.Display.'#cdata-section')"
                Write-Host "  ----------------------------" -ForegroundColor Cyan
                Write-Output "   Severity: $($DCUBIOSLatest.Criticality.Display.'#cdata-section')"
                Write-Output "   FileName: $TargetFileName"
                Write-Output "   BIOS Release Date: $DCUBIOSReleaseDate"
                Write-Output "   KB: $($DCUBIOSLatest.releaseID)"
                Write-Output "   Link: $TargetLink"
                Write-Output "   Info: $($DCUBIOSLatest.ImportantInfo.URL)"
                Write-Output "   BIOS Version: $DCUBIOSVersion "

                #Build Required Info to Download and Update CM Package
                $SourceSharePackageLocation = $model.PkgSourcePath
                $TargetFilePathName = "$($SourceSharePackageLocation)\$($TargetFileName)"

                #Clear Current Package Contents:
                $RemoveOldPackageContents = Remove-Item -Path "$($SourceSharePackageLocation)\*" -Force -ErrorAction SilentlyContinue
                #Download BIOS
                Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Verbose -Proxy $ProxyServer

                #Confirm Download
                if (Test-Path $TargetFilePathName)
                    {
                    Write-Host " Confirming Package $($Model.Name) with updated Info" -ForegroundColor Yellow
                    Set-Location -Path "$($SiteCode):"
                    Set-CMPackage -Id $Model.PackageID -Version $DCUBIOSVersion
                    Set-CMPackage -Id $Model.PackageID -MifPublisher $DCUBIOSReleaseDate
                    Set-CMPackage -Id $Model.PackageID -Description $($DCUBIOSLatest.ImportantInfo.URL)
                    Set-CMPackage -Id $Model.PackageID -MifVersion ""
                    Update-CMDistributionPoint -PackageId $Model.PackageID
                    Write-Host " Completed Process for $($Model.MIFFilename) with updated BIOS $DCUBIOSVersion" -ForegroundColor Green
                    }
                else
                    {
                    Write-Host " FAILED TO DOWNLOAD BIOS" -ForegroundColor Red
                    }
            
                }
            else
                {
                Write-Host " BIOS in DCU XML same as BIOS in CM: $PackageVersion" -ForegroundColor Yellow
                }
            }
        else
            {
            Write-Host "No Model Cab Downloaded"
            }
        }
    else
        {
        Write-Host "No Match in XML for $($Model.MIFFilename)"
        }    
     Set-Location -Path "C:"   
    }
        
    

    
