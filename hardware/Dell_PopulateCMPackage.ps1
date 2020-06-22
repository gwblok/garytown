
<# 
Version 2020.04.08 - @GWBLOK
Downloads BIOS Updates for Packages in CM (Requires specific Package Structure).. see here:https://github.com/gwblok/garytown/blob/master/hardware/CreateCMPackages_BIOS_Drivers.ps1
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
		    $Stage = "Pre-Prod"
 	    )


$scriptName = $MyInvocation.MyCommand.Name
$CabPath = "$PSScriptRoot\DriverBIOSCatalog.cab"
$DellCabExtractPath = "$PSScriptRoot\DellCabExtract"
$SiteCode = "PS2"
<#
function Get-ObjectMembers {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [PSCustomObject]$obj
    )
    $obj | Get-Member -MemberType NoteProperty | ForEach-Object {
        $key = $_.Name
        [PSCustomObject]@{Key = $key; Value = $obj."$key"}
    }
}
#>

Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"
$DellModelsTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.Manufacturer -eq "Dell" -and $_.Mifname -eq $Stage}

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

if (!(test-path -path $CabPath)-or $SkipDownload) 
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
    $Expand = expand $CabPath -F:* $DellCabExtractPath
    }


write-host "Loading Dell Catalog XML.... can take awhile" -ForegroundColor Yellow
[xml]$XML = Get-Content "$DellCabExtractPath\DellSDPCatalogPC.xml" -Verbose
$JsonData = Get-Content -Path "$DellCabExtractPath\V3\*.json"
$ListOfDevices = ($JsonData | ConvertFrom-Json).DisplayName | Sort-Object #This will be a list of supported devices in this JSON


foreach ($Model in $DellModelsTable)
    {
    Write-Host "----------------------------" -ForegroundColor DarkGray
    Write-Host "Starting to Process Model: $($Model.MifFileName)" -ForegroundColor Green
    $DeviceMatches = @()
    $CurrentDeviceItem = $null
    $LastMatch = $null
    $CurrentDeviceItem = $JsonData | ConvertFrom-Json | Where-Object {$_.DisplayName -eq "$($Model.MifFileName)"}
    if (!($CurrentDeviceItem))
        {
        write-host "No Json Data for Model: $($Model.MifFileName)" -ForegroundColor Red
        Set-Location -Path "$($SiteCode):"
        Set-CMPackage -Id $Model.PackageID -Description "No Json Data for Model: $($Model.MifFileName)"
        Set-Location -Path "C:" 
        }
    #$DeviceItems += $JsonData
    foreach ($Member in $CurrentDeviceItem.Members) #{write-host "$($Member.MifFileName)"}
        {
        $CurrentMatch = $XML.SystemsManagementCatalog.SoftwareDistributionPackage | Where-Object {$_.Properties.PackageID -eq $Member -and $_.Properties.PublicationState -match "Published" -and $_.Properties.ProductName -match "Bios"}
        
        if ($CurrentMatch)
            {
            Write-Host "Found Match in XML" -ForegroundColor Gray
            $DeviceMatches += $CurrentMatch 
            if ($CurrentMatch -ne $LastMatch){$RunStep = $true}
            else {$RunStep = $false}
            if ($RunStep)
                {
                $LastMatch = $CurrentMatch
                $VersionArray = ($($CurrentMatch.LocalizedProperties.Title).split(","))
                $Version = $VersionArray[-1]
                $CreationDate =  $(Get-Date $CurrentMatch.InstallableItem.OriginFile.Modified -Format 'yyyy-MM-dd')
                $TargetLink = $($CurrentMatch.InstallableItem.OriginFile.OriginUri)
                $TargetFileName = $($CurrentMatch.InstallableItem.OriginFile.FileName)
                $SourceSharePackageLocation = $model.PkgSourcePath
                $TargetFilePathName = "$($SourceSharePackageLocation)\$($BIOSFileName)"
                if ($Version -eq $Model.Version){Write-Host " Package already Current with $Version" -ForegroundColor Green}
                else {
                    Remove-Item -Path "$($SourceSharePackageLocation)\*.exe" -Force #Clear out old BIOS
                    Write-Host " New BIOS Update available: Package = $($Model.Version), Web = $version" -ForegroundColor Yellow 
                    Write-Output " Title: $($CurrentMatch.LocalizedProperties.Title) | $Member"
                    Write-Host " ----------------------------" -ForegroundColor Cyan
                    Write-Output "  Title: $($CurrentMatch.LocalizedProperties.Title)"
                    Write-Output "  CreationDate: $($CurrentMatch.Properties.CreationDate)"
                    Write-Output "  ProductName: $($CurrentMatch.Properties.ProductName)"
                    Write-Output "  Severity: $($CurrentMatch.UpdateSpecificData.MsrcSeverity)"
                    Write-Output "  FileName: $TargetFileName"
                    Write-Output "  CreationDate: $CreationDate"
                    Write-Output "  KB: $($CurrentMatch.UpdateSpecificData.KBArticleID)"
                    Write-Output "  Link: $TargetLink"
                    Write-Output "  Info: $($CurrentMatch.Properties.MoreInfoUrl)"
                    Write-Output "  BIOS Version: $Version "
                    #Download BIOS
                    Import-Module BitsTransfer
                    $DownloadAttempts = 0
                    if ($UseProxy -eq $true) 
                        {Start-BitsTransfer -Source $TargetLink -Destination $TargetFilePathName -ProxyUsage Override -ProxyList $BitsProxyList -DisplayName $TargetFileName -Asynchronous}
                    else 
                        {Start-BitsTransfer -Source $TargetLink -Destination $TargetFilePathName -DisplayName $TargetFileName -Asynchronous}
                    do
                        {
                        $DownloadAttempts++
                        Get-BitsTransfer -Name $TargetFileName | Resume-BitsTransfer
                        }
                    while
                        ((test-path "$TargetFilePathName") -ne $true -and $DownloadAttempts -lt 15)
                    }
                #This will run if newer package available or not.  It updates info based on Dell XML
                Write-Host " Confirming Package $($Model.Name) with updated Info" -ForegroundColor Yellow
                Set-Location -Path "$($SiteCode):"
                Set-CMPackage -Id $Model.PackageID -Version $Version
                Set-CMPackage -Id $Model.PackageID -MifPublisher $CreationDate
                Set-CMPackage -Id $Model.PackageID -Description $($CurrentMatch.Properties.MoreInfoUrl)
                Update-CMDistributionPoint -PackageId $Model.PackageID
                Write-Host " Completed Process for $($Model.MIFFilename) with updated BIOS $Version" -ForegroundColor Green
                Set-Location -Path "C:" 
                }
            }
        }
    if (!($DeviceMatches))
        {
        write-host "No Json Data for Model: $($Model.MifFileName)" -ForegroundColor Red
        Set-Location -Path "$($SiteCode):"
        Set-CMPackage -Id $Model.PackageID -Description "No Json Data for Model: $($Model.MifFileName)"
        Set-Location -Path "C:" 
        }
    }


