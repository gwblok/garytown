
<# Gary Blok @gwblok @recastsoftware
Dell Driver Pack Download Script
Leverages the Dell Catalog Cab

Requires that CM Packages are setup in specific way with specific metadata.
I have another script on GitHub for onboarding models which will create the CM Package Placeholders for your Models... all of my other processes hinge off of that script.

Assumptions, you used that script and have Pre-Prod (For Testing) and Prod (For Production Deployments) Packages.

This will grab the required data from the Package and reach out to dell to see if an updated Driver Pack is available, if it is, it downloads and updates the Content and CM Package Info.


2021.09.17 - Updated for Creating WIM files 
 Folder Structure of Package
  - WIM
    - Online
      - Any Setup Based Driver installers
        - Driver Setup Contents
        - CustomInstall.cmd (This you make with the silent command for install)
    - Offline
      - Contains the Extract Dell Cab
  - Version.txt (This is the Version of the Cab File and contains extra information, this script creates that file)

 We then have other processes that Mount the WIM during OSD or IPU to be used, then unmounted again.  These will all be in the WaaS Download on GARYTOWN, scripts will be on github as well


#> 
[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true,Position=1,HelpMessage="Stage")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("Pre-Prod", "Prod")]
		    $Stage = "Prod"
 	    )


$scriptName = $MyInvocation.MyCommand.Name
$CabPath = "$env:TEMP\DriverCatalog.cab"
$DellCabExtractPath = "$PSScriptRoot\DellCabExtract"
$SiteCode = "PS2"
$ScatchLocation = "D:\DedupExclude"
$DismScratchPath = "$ScatchLocation\DISM"


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 


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
#$DellModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq "Dell" -and $_.MIFName -eq $Stage -and $_.Name -match "7280"}

#To Select
$DellModelsSelectTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq "Dell" -and $_.Mifname -eq $Stage} |Select-Object -Property "Name","MIFFilename","PackageID", "Version" | Sort-Object $_.MIFFilename | Out-GridView -Title "Select the Models you want to Update" -PassThru
$DellModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.PackageID -in $DellModelsSelectTable.PackageID}

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
        $ModelDriverPackInfo = $DriverPacks | Where-Object -FilterScript {$_.SupportedSystems.Brand.Model.Name -eq $($Model.MIFFilename)} | Select-Object -first 1

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
    $ModelDriverPackInfo = $DriverPacks | Where-Object -FilterScript {$_.SupportedSystems.Brand.Model.systemID -eq $($Model.Language)} | Select-Object -first 1
    $TargetVersion = "$($ModelDriverPackInfo.dellVersion)"
    $TargetLink = "https://downloads.dell.com/$($ModelDriverPackInfo.path)"
    $TargetFileName = ($ModelDriverPackInfo.name.Display.'#cdata-section').Trim()
    $ReleaseDate = Get-Date $ModelDriverPackInfo.dateTime -Format 'yyyy-MM-dd'
    $TargetInfo = $ModelDriverPackInfo.ImportantInfo.URL
    #if (($ModelDriverPackInfo.SupportedSystems.Brand.Model.systemID).count -gt 1){$DellSystemID = ($ModelDriverPackInfo.SupportedSystems.Brand.Model.systemID)[0]}
    #else{$DellSystemID = ($ModelDriverPackInfo.SupportedSystems.Brand.Model.systemID)}
    #Temporary Storage for Cab
    $TempCabPath = "$env:TEMP\DellCab"
    if (test-path "$TempCabPath"){Remove-Item -Path $TempCabPath -Force -Recurse}
    New-Item -Path $TempCabPath -ItemType Directory | Out-Null
    $TargetFilePathName = "$($TempCabPath)\$($TargetFileName)"

    #Determine if XML has newer Package than ConfigMgr Then Download
    if ($Model.Version -Lt $TargetVersion)
        {
        Write-Host " New Update Available: $TargetVersion, Previous: $($Model.Version)" -ForegroundColor yellow
        Write-Host "  Starting Download with BITS: $TargetFilePathName" -ForegroundColor Green
        if ($UseProxy -eq $true) 
            {$Download = Start-BitsTransfer -Source $TargetLink -Destination $TargetFilePathName -ProxyUsage Override -ProxyList $BitsProxyList -DisplayName $TargetFileName -Asynchronous}
        else 
            {$Download = Start-BitsTransfer -Source $TargetLink -Destination $TargetFilePathName -DisplayName $TargetFileName -Asynchronous}
        do
            {
            $DownloadAttempts++
            $GetTransfer = Get-BitsTransfer -Name $TargetFileName -ErrorAction SilentlyContinue | Select-Object -Last 1
            Resume-BitsTransfer -BitsJob $GetTransfer.JobID
            }
        while
            ((test-path "$TargetFilePathName") -ne $true -and $DownloadAttempts -lt 15)
        
        if (!(test-path "$TargetFilePathName")){
            write-host "Failed to download with BITS, trying with Invoke WebRequest"
            Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Verbose -Proxy $ProxyServer
            }
        if (test-path "$TargetFilePathName"){
            Write-Host "  Download Complete: $TargetFilePathName" -ForegroundColor Green
            #Expand Dell Cab
            Write-Host " Starting Expand Process for $($DellModel.Model) file $TargetFileName" -ForegroundColor Green
            $ExpandFolder = "$env:TEMP\DellTemp\$($Model.MIFFilename)"
            if (Test-Path -Path $ExpandFolder){Remove-Item -Path $ExpandFolder -Recurse -Force}
            $Null = New-Item -Path $ExpandFolder -ItemType Directory -Force
            $OfflineFolder = "$ExpandFolder\Offline"
            $OnlineFolder = "$ExpandFolder\Online"
            $Null = New-Item -Path $OfflineFolder -ItemType Directory -Force
            $Null = New-Item -Path $OnlineFolder -ItemType Directory -Force

            $Expand = expand $TargetFilePathName -F:* $OfflineFolder

            #WIM Expanded Files
            # Cleanup Previous Runs (Deletes the files)
            if (Test-Path $dismscratchpath) {Remove-Item $DismScratchPath -Force -Recurse -ErrorAction SilentlyContinue}
            if (Test-Path $($Model.PkgSourcePath)) {Remove-Item $($Model.PkgSourcePath) -Force -Recurse -ErrorAction SilentlyContinue}       
            $Null = New-Item -Path $($Model.PkgSourcePath) -ItemType Directory -Force
            $DismScratch = New-Item -Path $DismScratchPath -ItemType Directory -Force
            New-WindowsImage -ImagePath "$($Model.PkgSourcePath)\Drivers.wim" -CapturePath "$ExpandFolder" -Name "$($Model.MIFFilename) - $($Model.Language)"  -LogPath "$env:TEMP\dism-$($Model.MIFFilename).log" -ScratchDirectory $dismscratchpath
            $ReadmeContents = "Model: $($Model.Name) | Pack Version: $TargetVersion | CM PackageID: $($Model.PackageID)"
            $ReadmeContents | Out-File -FilePath "$($Model.PkgSourcePath)\$($TargetVersion).txt"
            Set-Location -Path "$($SiteCode):"
            Update-CMDistributionPoint -PackageId $Model.PackageID
            Set-Location -Path "C:"
            $FolderSize = (Get-FolderSize $ExpandFolder)
            $FolderSize = [math]::Round($FolderSize.'Size(MB)') 
            Write-Host " Finished Expand & WIM Process for $ExpandFolder, size: $FolderSize" -ForegroundColor Green
            Remove-Item -Path $ExpandFolder -Force -Recurse
            
            Write-Host " Confirming Package $($Model.Name) with updated Info" -ForegroundColor Yellow
            Set-Location -Path "$($SiteCode):"
            Set-CMPackage -Id $Model.PackageID -Version $TargetVersion
            Set-CMPackage -Id $Model.PackageID -MifVersion $ReleaseDate
            Set-CMPackage -Id $Model.PackageID -Description $TargetInfo
            #Set-CMPackage -Id $Model.PackageID -Language $DellSystemID 
            Set-Location -Path "C:"
            }
        else{ Write-Host "  Failed to Download: $TargetLink" -ForegroundColor red}
        }
    else {Write-Host " No Update Available: Current CM Version:$($Model.Version) | Dell Online version $TargetVersion" -ForegroundColor Green}
    }
