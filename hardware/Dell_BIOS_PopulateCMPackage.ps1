
<# 
Version 2020.06.22 - @GWBLOK
Downloads BIOS Updates for Packages in CM (Requires specific Package Structure).. see here:https://github.com/gwblok/garytown/blob/master/hardware/CreateCMPackages_BIOS_Drivers.ps1
Downloads the Dell SCUP Catalog Cab File, Extracts XML, Loads XML, finds BIOS downloads for corrisponding Models, downloads them if update is available (compared to the CM Package), then updates the CM Package

Not Setup for PRoxy, you'll have to add PRoxy support yourself.

Update the SITECODE

Usage... Stage Prod or Pre-Prod.
If you don't do Pre-Prod... just delete that Param section out and set $Stage = Prod or remove all Stage references complete, do whatever you want I guess.

#> 
[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false,Position=1,HelpMessage="Stage")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("Pre-Prod", "Prod")]
		    $Stage
 	    )




$scriptName = $MyInvocation.MyCommand.Name
$CabPath = "$PSScriptRoot\DriverBIOSCatalog.cab"
$DellCabExtractPath = "$PSScriptRoot\DellCabExtract"
$SiteCode = "PS2"


Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"
#$DellModelsTable = Get-CMPackage -Fast -Name "*BIOS*" | Where-Object {$_.Manufacturer -eq "Dell" -and $_.Mifname -eq $Stage}

#Pick Stage
if (!($Stage)){$Stage = "Prod", "Pre-Prod" | Out-GridView -Title "Select the Stage you want to update" -PassThru}

#To Select
$DellModelsSelectTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.Manufacturer -eq "Dell" -and $_.Mifname -eq $Stage} |Select-Object -Property "Name","MIFFilename","PackageID", "Version" | Sort-Object $_.MIFFilename | Out-GridView -Title "Select the Models you want to Update" -PassThru
$DellModelsTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.PackageID -in $DellModelsSelectTable.PackageID}


#Testing Specific Model
#$DellModelsTable = Get-CMPackage -Fast -Id "PS20041A"
Set-Location -Path "C:"

#Check for the last time we downloaded the Dell Cab & if it is recent, go with it, if not, download and start from scratch
if (test-path -path $CabPath) 
    {
    If(Test-Path "$DellCabExtractPath\DellSDPCatalogPC.xml") 
        {
        If(Test-Path "$DellCabExtractPath\v3")
            {
            Write-Host "Found Dell Cab File Downloaded" -ForegroundColor Green
            $PreviousDownload = (Get-ChildItem -Path $CabPath).LastWriteTime
            $15daysAgo = (get-date).AddDays(-1)
            if ($PreviousDownload -gt $15daysAgo)
                {
                Write-Host "Previous Cab from $PreviousDownload, will skip redownloading data"
                $SkipDownload = $true
                }
            else
                {
                Write-Host "Previous Cab too old: $PreviousDownload, will download again"
                Remove-Item $CabPath -Force
                $SkipDownload = $false
                }
            }
        }
    }

if ((test-path -path $CabPath)-or $SkipDownload) {Write-Host "Skipped Downloading Cab" -ForegroundColor Green}
else   
    {
    Write-Host "Downloading Dell Cab" -ForegroundColor Yellow
    Invoke-WebRequest -Uri "http://downloads.dell.com/catalog/DellSDPCatalogPC.cab" -OutFile $CabPath -UseBasicParsing -Verbose -Proxy $ProxyServer
    [int32]$n=1
    While(!(Test-Path $CabPath) -and $n -lt '3')
        {
        Invoke-WebRequest -Uri "http://downloads.dell.com/catalog/DellSDPCatalogPC.cab" -OutFile $CabPath -UseBasicParsing -Verbose -Proxy $ProxyServer
        $n++
        }
    If(Test-Path "$PSScriptRoot\DellSDPCatalogPC.xml"){Remove-Item -Path "$PSScriptRoot\DellSDPCatalogPC.xml" -Force -Verbose}
    Start-Sleep -Seconds 1
    if (test-path $DellCabExtractPath){Remove-Item -Path $DellCabExtractPath -Force -Recurse}
    New-Item -Path $DellCabExtractPath -ItemType Directory
    #This Takes FOREVER!!!!! 
    Write-Host "!!!!!!!...............................!!!!!!!" -ForegroundColor Cyan
    Write-Host "Expanding the Cab File..... takes FOREVER...." -ForegroundColor Yellow
    Write-Host "!!!!!!!...............................!!!!!!!" -ForegroundColor Cyan
    $Expand = expand $CabPath -F:DellSDPCatalogPC.xml $DellCabExtractPath
    
    }
<#Driver Cabs Only
Invoke-WebRequest -Uri "http://downloads.dell.com/catalog/DriverPackCatalog.cab" -OutFile "$DellCabExtractPath\DriverPackCatalog.cab" -UseBasicParsing -Verbose -Proxy $ProxyServer
$Expand = expand "$DellCabExtractPath\DriverPackCatalog.cab" -F:DriverPackCatalog.xml $DellCabExtractPath\DriverPackCatalog.xml
[XML]$XML = Get-Content "$DellCabExtractPath\DriverPackCatalog.xml"
$items = $XML.DriverPackManifest.DriverPackage
#>

write-host "Loading Dell Catalog XML.... can take awhile" -ForegroundColor Yellow
[xml]$XML = Get-Content "$DellCabExtractPath\DellSDPCatalogPC.xml" -Verbose
#$JsonData = Get-Content -Path "$DellCabExtractPath\V3\*.json"
#$ListOfDevices = ($JsonData | ConvertFrom-Json).DisplayName | Sort-Object #This will be a list of supported devices in this JSON

foreach ($Model in $DellModelsTable)#{} #{Write-Host "Starting to Process Model: $($Model.MifFileName)" -ForegroundColor Green}
    {
    Write-Host "----------------------------" -ForegroundColor DarkGray
    Write-Host "Starting to Package: $($Model.Name)" -ForegroundColor Green
    Write-Host " Current BIOS Version: $($Model.Version) from $($Model.MIFPublisher)" -ForegroundColor Green
    $PackageVersion = $null
    $LatestFileVersionFromName = $null
    $CurrentMatchBiosVersionFromFileName = $null
    $LatestVersionFromName = $null
    $BIOSModifiedDate = $null
    $TargetLink = $null
    $TargetFileName = $null
    $Version = $null
    $SourceSharePackageLocation = $null
    $TargetFilePathName = $null

    
    if ($Model.Version -match "A"){[String]$PackageVersion = $Model.Version}
    if ($Model.Version -ne $null -and $Model.Version -ne "" -and $Model.Version -notmatch "A"){[System.Version]$PackageVersion = $Model.Version}
    $PublishedBIOS = $XML.SystemsManagementCatalog.SoftwareDistributionPackage | Where-Object {$_.Properties.ProductName -match "Bios"-and $_.Properties.PublicationState -match "Published"}
    
    $DeviceMatches = $PublishedBIOS | Where-Object {$_.InstallableItem.ApplicabilityRules.IsInstallable.And.WmiQuery.WqlQuery -match $Model.Language}
    $WQLQueries =  $DeviceMatches.InstallableItem.ApplicabilityRules.IsInstallable.and.WmiQuery.WqlQuery
    $WQLQueries = $WQLQueries | Where-Object { $_ -match "VersionString"}
    $WQLQueryVersion = @()
    foreach ($WQLQuery in $WQLQueries)
        {
        $Count = ((($WQLQuery).split("VersionString < ")).Count - 1)
        $WQLQueryVersion += ((($WQLQuery).split("VersionString < "))[$Count]).replace("'","")
        }
    $WQLQueryVersionLatestVersion = $WQLQueryVersion | Sort-Object | Select-Object -Last 1
    Write-Host "Latest Version found in WQLQuery = $WQLQueryVersionLatestVersion" -ForegroundColor Green
    $WQLBIOSMatch = $DeviceMatches | Where-Object {$_.InstallableItem.ApplicabilityRules.IsInstallable.and.WmiQuery.WqlQuery -match $WQLQueryVersionLatestVersion}
    if ($WQLBIOSMatch.Count -gt 1){$WQLBIOSMatch = $WQLBIOSMatch | Where-Object {$_.LocalizedProperties.Title -match $model.MIFFilename}}

    if ($WQLBIOSMatch)
        {
        $BIOSModifiedDate =  $(Get-Date $WQLBIOSMatch.InstallableItem.OriginFile.Modified -Format 'yyyy-MM-dd')
        $TitleNames = $WQLBIOSMatch.LocalizedProperties.Title 
        $FileNames = $WQLBIOSMatch.InstallableItem.OriginFile.FileName
        
        $TargetLink = $($WQLBIOSMatch.InstallableItem.OriginFile.OriginUri)
        $TargetFileName = $($WQLBIOSMatch.InstallableItem.OriginFile.FileName)
        if ($WQLQueryVersionLatestVersion -match "A")
            {
            $Version = $WQLQueryVersionLatestVersion
            }
        else
            {
            $Version = [System.Version]$WQLQueryVersionLatestVersion
            }
        $SourceSharePackageLocation = $model.PkgSourcePath
        $TargetFilePathName = "$($SourceSharePackageLocation)\$($TargetFileName)" 
        Write-Host "Most Updated BIOS in XML: $TitleNames from $BIOSModifiedDate" -ForegroundColor Yellow
        if ($WQLQueryVersionLatestVersion -gt $PackageVersion)
            {
            Set-Location -Path "C:" 
            Remove-Item -Path "$($SourceSharePackageLocation)\*.exe" -Force -ErrorAction SilentlyContinue #Clear out old BIOS
            Write-Host " New BIOS Update available: Package = $($Model.Version), Web = $version" -ForegroundColor Yellow 
            Write-Output " Title: $($WQLBIOSMatch.LocalizedProperties.Title) | $Member"
            Write-Host " ----------------------------" -ForegroundColor Cyan
            Write-Output "  Title: $($WQLBIOSMatch.LocalizedProperties.Title)"
            #Write-Output "  CreationDate: $($WQLBIOSMatch.Properties.CreationDate)"
            Write-Output "  ProductName: $($WQLBIOSMatch.Properties.ProductName)"
            Write-Output "  Severity: $($WQLBIOSMatch.UpdateSpecificData.MsrcSeverity)"
            Write-Output "  FileName: $TargetFileName"
            Write-Output "  BIOSModifiedDate: $BIOSModifiedDate"
            Write-Output "  KB: $($WQLBIOSMatch.UpdateSpecificData.KBArticleID)"
            Write-Output "  Link: $TargetLink"
            Write-Output "  Info: $($WQLBIOSMatch.Properties.MoreInfoUrl)"
            Write-Output "  BIOS Version: $Version "
            #Download BIOS
            Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Verbose -Proxy $ProxyServer
            Write-Host " Confirming Package $($Model.Name) with updated Info" -ForegroundColor Yellow
            Set-Location -Path "$($SiteCode):"
            Set-CMPackage -Id $Model.PackageID -Version $Version
            Set-CMPackage -Id $Model.PackageID -MifPublisher $BIOSModifiedDate
            Set-CMPackage -Id $Model.PackageID -Description $($WQLBIOSMatch.Properties.MoreInfoUrl)
            #Dump MIFVersion (WMI DATE) - This has to be done manually
            Set-CMPackage -Id $Model.PackageID -MifVersion ""
            Update-CMDistributionPoint -PackageId $Model.PackageID
            Write-Host " Completed Process for $($Model.MIFFilename) with updated BIOS $Version" -ForegroundColor Green
            }
        else
            {
            Write-Host "BIOS in CM the Same or Newer than Dell.com" -ForegroundColor Yellow
            Write-Host " CM: $PackageVersion | Dell: $Version" -ForegroundColor Yellow
            }
        #This will run if newer package available or not.  It updates info based on Dell XML
            
        }
    else
        {Write-Host "XML did not have a match for $($Model.MIFFilename)" -ForegroundColor Red}
    }
