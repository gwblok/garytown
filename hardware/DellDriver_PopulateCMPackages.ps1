
<# 
Version 2020.04.15 - @GWBLOK
Downloads Driver Updates for Packages in CM (Requires specific Package Structure).. see here:https://github.com/gwblok/garytown/blob/master/hardware/CreateCMPackages_BIOS_Drivers.ps1
Downloads the Dell SCUP Catalog Cab File, Extracts XML, Loads XML, finds BIOS downloads for corrisponding Models, downloads them if update is available (compared to the CM Package), then updates the CM Package

Not Setup for PRoxy, you'll have to add PRoxy support yourself.

Update the SITECODE

Usage... Stage Prod or Pre-Prod.
If you don't do Pre-Prod... just delete that Param section out and set $Stage = Prod or remove all Stage references complete, do whatever you want I guess.

#> 
[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true,Position=1,HelpMessage="Stage")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("Pre-Prod", "Prod")]
		    $Stage = "Prod"
 	    )


$scriptName = $MyInvocation.MyCommand.Name
$CabPath = "$PSScriptRoot\DriverCatalog.cab"
$DellCabExtractPath = "$PSScriptRoot\DellCabExtract"
$SiteCode = "PS2"



function Get-FolderSize {
[CmdletBinding()]
Param (
[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
$Path,
[ValidateSet("KB","MB","GB")]
$Units = "MB"
)
  if ( (Test-Path $Path) -and (Get-Item $Path).PSIsContainer ) {
    $Measure = Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
    $Sum = $Measure.Sum / "1$Units"
    [PSCustomObject]@{
      "Path" = $Path
      "Size($Units)" = $Sum
    }
  }
}

Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"
$DellModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq "Dell" -and $_.Mifname -eq $Stage}

#Testing Specific Model
#$DellModelsTable = Get-CMPackage -Fast -Id "PS20047E"
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
            $15daysAgo = (get-date).AddDays(-15)
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

$DriverURL = "https://downloads.dell.com/catalog/DriverPackCatalog.cab"
if (!(test-path -path $CabPath)-or $SkipDownload) 
    {
    Write-Host "Downloading Dell Cab" -ForegroundColor Yellow
    Invoke-WebRequest -Uri $DriverURL -OutFile $CabPath -UseBasicParsing -Verbose -Proxy $ProxyServer
    [int32]$n=1
    While(!(Test-Path $CabPath) -and $n -lt '3')
        {
        Invoke-WebRequest -Uri $DriverURL -OutFile $CabPath -UseBasicParsing -Verbose -Proxy $ProxyServer
        $n++
        }
    If(Test-Path "$PSScriptRoot\DellSDPCatalogPC.xml"){Remove-Item -Path "$PSScriptRoot\DellSDPCatalogPC.xml" -Force -Verbose}
    Start-Sleep -Seconds 1
    if (test-path $DellCabExtractPath){Remove-Item -Path $DellCabExtractPath -Force -Recurse}
    New-Item -Path $DellCabExtractPath -ItemType Directory
    Write-Host "Expanding the Cab File..... takes FOREVER...." -ForegroundColor Yellow
    $Expand = expand $CabPath "$DellCabExtractPath\DriverPackCatalog.xml"
    }


write-host "Loading Dell Catalog XML.... can take awhile" -ForegroundColor Yellow
[xml]$XML = Get-Content "$DellCabExtractPath\DriverPackCatalog.xml" -Verbose
$DriverPacks = $Xml.DriverPackManifest.DriverPackage | Where-Object -FilterScript {$_.SupportedOperatingSystems.OperatingSystem.osCode -match "Windows10"}
$DriverPacks.SupportedSystems.Brand.Model.Name | Sort-Object
$DriverPacksModelSupport = $DriverPacks.SupportedSystems.Brand.Model.Name | Sort-Object

#Quick Check of the Supported Models
Write-Host "-------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Dell Model Support in this XML Chcek" -ForegroundColor Yellow
foreach ($Model in $DellModelsTable)
    {
    Write-Host "------------------------" -ForegroundColor DarkGray
    if ($DriverPacksModelSupport-contains $Model.MIFFilename)
        {
        Write-host "  Dell XML Supports: $($Model.MIFFilename)" -ForegroundColor Green
        $ModelDriverPackInfo = $DriverPacks | Where-Object -FilterScript {$_.SupportedSystems.Brand.Model.Name -eq $($Model.MIFFilename)}
        Write-host "  Name in XML: $($ModelDriverPackInfo.SupportedSystems.Brand.Model.Name) " -ForegroundColor Green
        Write-host "  Cab Available: $($ModelDriverPackInfo.name.Display.'#cdata-section')" -ForegroundColor Green
        }
    else
        {
        Write-host "  Dell XML does NOT Contain $($Model.MIFFilename) - Might be Name inconsistency" -ForegroundColor Red
        }
    }
Write-Host "-------------------------------------------------------" -ForegroundColor Cyan


foreach ($Model in $DellModelsTable)#{}
    {
    Write-Host "----------------------------" -ForegroundColor DarkGray
    Write-Host "Starting to Process Model: $($Model.MifFileName)" -ForegroundColor Green
    
    #Get Info about Driver Package from XML
    $ModelDriverPackInfo = $DriverPacks | Where-Object -FilterScript {$_.SupportedSystems.Brand.Model.Name -eq $($Model.MIFFilename)}
    $TargetVersion = "$($ModelDriverPackInfo.dellVersion)"
    $TargetLink = "https://downloads.dell.com/$($ModelDriverPackInfo.path)"
    $TargetFileName = ($ModelDriverPackInfo.name.Display.'#cdata-section').Trim()
    $ReleaseDate = Get-Date $ModelDriverPackInfo.dateTime -Format 'yyyy-MM-dd'
    $TargetInfo = $ModelDriverPackInfo.ImportantInfo.URL
    if (($ModelDriverPackInfo.SupportedSystems.Brand.Model.systemID).count -gt 1){$DellSystemID = ($ModelDriverPackInfo.SupportedSystems.Brand.Model.systemID)[0]}
    else{$DellSystemID = ($ModelDriverPackInfo.SupportedSystems.Brand.Model.systemID)}
    #Temporary Storage for Cab
    $TempCabPath = "$env:TEMP\DellCab"
    if (test-path "$TempCabPath"){Remove-Item -Path $TempCabPath -Force -Recurse}
    New-Item -Path $TempCabPath -ItemType Directory | Out-Null
    $TargetFilePathName = "$($TempCabPath)\$($TargetFileName)"

    #Determine if XML has newer Package than ConfigMgr Then Download
    if ($Model.Version -Lt $TargetVersion)
        {
        Write-Host " New Update Available: $TargetVersion, Previous: $($Model.Version)" -ForegroundColor yellow
        Write-Host "  Starting Download: $TargetFilePathName" -ForegroundColor Green
        if ($UseProxy -eq $true) 
            {$Download = Start-BitsTransfer -Source $TargetLink -Destination $TargetFilePathName -ProxyUsage Override -ProxyList $BitsProxyList -DisplayName $TargetFileName -Asynchronous}
        else 
            {$Download = Start-BitsTransfer -Source $TargetLink -Destination $TargetFilePathName -DisplayName $TargetFileName -Asynchronous}
        do
            {
            $DownloadAttempts++
            Get-BitsTransfer -Name $TargetFileName | Resume-BitsTransfer
            }
        while
            ((test-path "$TargetFilePathName") -ne $true -and $DownloadAttempts -lt 15)
        
        Write-Host "  Download Complete: $TargetFilePathName" -ForegroundColor Green
        Write-Host " Starting Expand Process for $($DellModel.Model) file $TargetFileName" -ForegroundColor Green
        $ExpandFolder = "$($Model.PkgSourcePath)\Expanded"
        if (test-path "$ExpandFolder"){Remove-Item -Path $ExpandFolder -Force -Recurse}
        New-Item -Path $ExpandFolder -ItemType Directory | Out-Null
        $Expand = expand $TargetFilePathName -F:* $ExpandFolder
        Set-Location -Path "$($SiteCode):"
        Update-CMDistributionPoint -PackageId $Model.PackageID
        Set-Location -Path "C:"
        $FolderSize = (Get-FolderSize $ExpandFolder)
        $FolderSize = [math]::Round($FolderSize.'Size(MB)') 
        Write-Host " Finished Expand Process for $ExpandFolder, size: $FolderSize" -ForegroundColor Green
        }
    Else {Write-Host " No Update Available: Current CM Version:$($Model.Version) | Dell Online version $TargetVersion" -ForegroundColor Green}

    #Confirm Package Properties
    if ($Model.Version -le $TargetVersion)
        {
        Write-Host " Confirming Package $($Model.Name) with updated Info" -ForegroundColor Yellow
        Set-Location -Path "$($SiteCode):"
        Set-CMPackage -Id $Model.PackageID -Version $TargetVersion
        Set-CMPackage -Id $Model.PackageID -MifVersion $ReleaseDate
        Set-CMPackage -Id $Model.PackageID -Description $TargetInfo
        Set-CMPackage -Id $Model.PackageID -Language $DellSystemID 
        Set-Location -Path "C:"
        }

    }
