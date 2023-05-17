<#  Creator @gwblok - GARYTOWN.COM
    Used to download BIOS Updates from HP
    This Script was created to build a BIOS Update Package. 
    Future Scripts based on this will be one that gets the Model / Product info from the machine it's running on and pull down the correct BIOS and run the Updater

    REQUIREMENTS:  HP Client Management Script Library
    Download / Installer: https://ftp.hp.com/pub/caps-softpaq/cmit/hp-cmsl.html  
    Docs: https://developers.hp.com/hp-client-management/doc/client-management-script-library-0
    This Script was created using version 1.2.1

    2020.12.13 - Minor Cleanup, still need to do more cleanup, but that's for another day, it does work as is.
#>


[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false,Position=1,HelpMessage="Method")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("Download","Force")]
		    $RunMethod,
		    [Parameter(Mandatory=$false,Position=1,HelpMessage="Stage")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("Pre-Prod", "Prod")]
		    $Stage
         
 	    )


if (!($Stage)){$Stage = "Prod", "Pre-Prod" | Out-GridView -Title "Select the Stage you want to update" -PassThru}
if (!($RunMethod)){$RunMethod = "Download", "Force" | Out-GridView -Title "Select the Stage you want to update" -PassThru}

#Script Vars
$EmailArray = @()
$scriptName = $MyInvocation.MyCommand.Name
$OS = "Win10"
$Category = "bios"
$DownloadDir = "C:\HPContent\Downloads"
$ExtractedDir = "C:\HPContent\Packages\HP"
$SiteCode = "PS2"
$FileServerName = "src"
$ShareName = "src$"

#Reset Vars
$BIOS = ""
$Model = ""



#Load CM PowerShell
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"


#For doing all HP Models at once:
#$HPModelsTable = Get-CMPackage -Fast -Name "$PackageNamePreFix BIOS*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.Mifname -eq $Stage}

#To Select
$HPModelsSelectTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.Mifname -eq $Stage} | Select-Object -Property "Name","MIFFilename","PackageID", "Version" | Out-GridView -Title "Select the Models you want to Update" -PassThru 
$HPModelsTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.PackageID -in $HPModelsSelectTable.PackageID}

#For Doing 1 Model at a time:
#$HPModelsTable = Get-CMPackage -Fast -Id "MEM0093E"


Set-Location -Path "C:"

Write-Output "Starting Script: $scriptName"



foreach ($HPModel in $HPModelsTable)#{}
    {
    Write-Host "Starting Process for $($HPModel.Name)" -ForegroundColor Cyan
    $AlreadyCurrent = $null
    $BIOSInfo = $null
    $Prodcode = $HPModel.Language
    Set-Location -Path "$($SiteCode):"
    $PackageInfo = Get-CMPackage -Id $HPModel.PackageID -Fast
    Set-Location -Path "C:"
    $PackageInfoVersion = $PackageInfo.Version
    #$Prodcode = "82B4"
    #$Name = (($HPModel.Name).Replace("ACME BIOS ","")).Replace(" - $Stage","")
    $MaxBuild = ((Get-HPDeviceDetails -platform $Prodcode -oslist | Where-Object {$_.OperatingSystem -eq "Microsoft Windows 10"}).OperatingSystemRelease | measure -Maximum).Maximum
    if ($MaxBuild -ge 1909){$MaxBuild = "1909"}
    $BIOS = Get-HPBiosUpdates -platform $Prodcode -latest
    $BIOSInfo = Get-SoftpaqList -Platform $Prodcode -Category BIOS -os $os -OsVer $MaxBuild | Where-Object {$_.Version -match $BIOS.Ver}
    #$BIOSInfo = Get-SoftpaqList -Platform $Prodcode -Category BIOS -os $os | Where-Object {$_.Version -match $BIOS.Ver}
    if (!($BIOSInfo))
        {
        Write-Host "  BIOS in Get-SoftpaqList does NOT match Get-HPBiosUpdates" -ForegroundColor Yellow
        $BIOSInfo = Get-SoftpaqList -Platform $Prodcode -Category BIOS -os $os -OsVer $MaxBuild # -OsVer $MaxBuild
        Write-Host "  Get-HPBiosUpdate BIOS Version: $($BIOS.Ver) vs Get-SoftpqaList BIOS Version: $($BIOSInfo.Version)" -ForegroundColor Yellow
        $BIOSInfo = $null
        }
    else
        {
        Write-Host "  BIOS in Get-SoftpaqList matches Get-HPBiosUpdates Version: $($BIOSInfo.Version)" -ForegroundColor Green
        }
    if ($BIOS.Ver -ne $HPModel.Version)
        {
        Write-Host "  BIOS in CM not Match HP Website" -ForegroundColor Magenta
        Write-Host "  CM Version: $($HPModel.Version) & Date: $($HPModel.MIFVersion) vs Get-HPBiosUpdates Version: $($BIOS.Ver) & Date: $($BIOS.Date)" -ForegroundColor Magenta
        $DownloadBIOSRootPackageFullPath = $HPModel.PkgSourcePath 
        #Get Current Driver CMPackage Version from CM
        if ($PackageInfoVersion -eq $Null -or $PackageInfoVersion -eq ""){$PackageInfoVersion = "N/A"}
        Set-Location -Path "C:"
        }
    else
        {
        Write-Host "  BIOS in CM matches Get-HPBiosUpdates Version: $($BIOS.Ver)" -ForegroundColor Green
        $AlreadyCurrent = $true
        $DownloadBIOSRootPackageFullPath = $HPModel.PkgSourcePath 
        }


    if ($PackageInfoVersion -eq $Bios.ver -and $RunMethod -ne "Force")
        {
        Write-Host "  $($HPModel.MIFFilename) already current with version $($PackageInfoVersion)" -ForegroundColor Yellow
        $AlreadyCurrent = $true
        }
    else
        {
        Write-host "  $($HPModel.MIFFilename) package is version $($PackageInfoVersion), new version available $($BIOS.ver)" -ForegroundColor Magenta
        
        
        $tempstorage = "$env:TEMP\BIOSDownload"
        if (Test-Path $tempstorage) {Remove-Item -Path $tempstorage -Recurse -Force }
        $NewFolder = New-Item $tempstorage -ItemType Directory -Force -ErrorAction SilentlyContinue
        $tempSaveAs = "$($tempstorage)\$($Bios.Bin)"
        Write-Host " Downloading BIOS for $($HPModel.MIFFilename)" -ForegroundColor Green
        }
        if ($AlreadyCurrent -ne $true -or $RunMethod -eq "Force")
            {
            try {
                $GetUpdate = Get-HPBIOSUpdates -Download -Overwrite -Platform $ProdCode -SaveAs $tempSaveAs -ErrorAction SilentlyContinue
                }
            catch{}

            if(Test-Path $tempSaveAs)
                {
                Write-Host "  Successfully Downloaded $($Bios.Bin)" -ForegroundColor Green
                Write-Host "  Replacing Old Content" -ForegroundColor Green
                $DownloadSuccess = $true
                $SaveAs = "$($DownloadBIOSRootPackageFullPath)\$($Bios.Bin)"
                if (Test-Path $DownloadBIOSRootPackageFullPath) {Remove-Item -Path $DownloadBIOSRootPackageFullPath -Recurse -Force }
                $NewFolder = New-Item $DownloadBIOSRootPackageFullPath -ItemType Directory -Force -ErrorAction SilentlyContinue
                Copy-Item -Path $tempSaveAs -Destination $SaveAs -Force
                }
            else
                {
                Write-Host "  Failed to Download $SaveAs" -ForegroundColor Red
                $DownloadSuccess = $false
                }
            }
    
        if (($RunMethod -eq "Download" -and $AlreadyCurrent -ne $true) -or $RunMethod -eq "UpdateCMPackageOnly" -or $RunMethod -eq "Force")
            {
            if ($DownloadSuccess -eq $true -or $AlreadyCurrent -eq $true)
                {
                write-host "  Updating Package Info in ConfigMgr $($PackageInfo.Name) ID: $($HPModel.PackageID)" -ForegroundColor Green
                Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
                Set-Location -Path "$($SiteCode):"         
        
                Set-CMPackage -Id $HPModel.PackageID -Version "$($BIOS.Ver)"
                Write-Host "   Set Version to $($BIOS.Ver)" -ForegroundColor Magenta
        
                Set-CMPackage -Id $HPModel.PackageID -MIFVersion $BIOS.Date
                Write-Host "   Set MIFVersion to $($BIOS.Date)" -ForegroundColor Magenta

                if ($BIOSInfo.ReleaseNotes)
                    {
                    Set-CMPackage -Id $HPModel.PackageID -MIFPublisher $BIOSInfo.ReleaseDate
                    Write-Host "   Set MIFPublisher to $($BIOSInfo.ReleaseDate)" -ForegroundColor Magenta
                    }
                else
                    {
                    Set-CMPackage -Id $HPModel.PackageID -MIFPublisher ""
                    Write-Host "   MIFPublisher: No Softpaq Data Available" -ForegroundColor Yellow
                    }        

                if ($BIOSInfo.ReleaseNotes)
                    {
                    Set-CMPackage -Id $HPModel.PackageID -Description $BIOSInfo.ReleaseNotes
                    Write-Host "   Set Description to $($BIOSInfo.ReleaseNotes)" -ForegroundColor Magenta
                    }
                else
                    {
                    Set-CMPackage -Id $HPModel.PackageID -Description "No Softpaq Data Available"
                    Write-Host "   Description: No Softpaq Data Available" -ForegroundColor Yellow
                    }

                $PackageInfo = Get-CMPackage -Id $HPModel.PackageID -Fast
                
                if ($AlreadyCurrent -ne $true)
                    {
                    write-host "  Triggering Package Content Update on DPs" -ForegroundColor Magenta
                    Update-CMDistributionPoint -PackageId $HPModel.PackageID
                    }

                Set-Location -Path "C:"
                Write-Host " Updated Package $($PackageInfo.Name), ID $($HPModel.PackageID) to $($PackageInfo.Version)" -ForegroundColor Green
                }
            else 
                {
                Write-Host " Failed to download, no updates to Package performed" -ForegroundColor Red
                }
            }
        
    }


