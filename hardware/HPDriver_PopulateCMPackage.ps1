<#  Version 2020.04.08 - Creator @gwblok - GARYTOWN.COM
    Used to download BIOS Updates from HP
    Grabs BIOS Files based on your CM Package Structure... based on this: https://github.com/gwblok/garytown/blob/master/hardware/CreateCMPackages_BIOS_Drivers.ps1

    REQUIREMENTS:  HP Client Management Script Library
    Download / Installer: https://ftp.hp.com/pub/caps-softpaq/cmit/hp-cmsl.html  
    Docs: https://developers.hp.com/hp-client-management/doc/client-management-script-library-0
    
    Usage... Stage Prod or Pre-Prod.
    If you don't do Pre-Prod... just delete that Param section out and set $Stage = Prod or remove all Stage references complete, do whatever you want I guess.

    If you have a Proxy, you'll have to modify for that.
#>
[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true,Position=1,HelpMessage="Stage")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("Pre-Prod", "Prod")]
		    $Stage = "Prod"

 	    )


#Script Vars
$OS = "Win10"
$Category = "bios"
$SiteCode = "PS2"

#Reset Vars
$Driver = ""
$Model = ""



#Load CM PowerShell
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"
$HPModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.Mifname -eq $Stage}

#$HPModelsTable = Get-CMPackage -Fast -Id "PS2004AA"

Set-Location -Path "C:"
Write-Output "Starting Script: $scriptName"




foreach ($HPModel in $HPModelsTable) #{Write-Host "$($HPModel.Name)"}
    {
    Write-Host "Starting Process for $($HPModel.MIFFilename)" -ForegroundColor Green
    $DriverInfo = $null
    $Prodcode = $HPModel.Language
    $Name = $HPModel.MIFFilename
    $MaxBuild = ((Get-HPDeviceDetails -platform $Prodcode -oslist | Where-Object {$_.OperatingSystem -eq "Microsoft Windows 10"}).OperatingSystemRelease | measure -Maximum).Maximum
    #$Driver = Get-HPBiosUpdates -platform $Prodcode -latest
    $DriverInfo = Get-SoftpaqList -Platform $Prodcode -Category Driverpack -OsVer $MaxBuild 
    $DriverInfo = $DriverInfo | Where-Object {$_.Name -notmatch "Windows PE"}
    if ($DriverInfo.Count -gt 1)
        {
        $Description = "Had More than 1 Driver Pack for this Product ID, made best Guess"
        $DriverInfo = $DriverInfo[0]
        }
    elseif (!($DriverInfo)){$Description = "NO SOFTPAQ DATA available for this ProductCode" }
    else{$Description = $DriverInfo.ReleaseNotes}
     

       #Get Current Driver CMPackage Version from CM & Setup Download Location

        Set-Location -Path "$($SiteCode):"
        $PackageInfo = $HPModel
        $PackageInfoVersion = $null
        $PackageInfoVersion = $PackageInfo.Version
        $PackageSource = $PackageInfo.PkgSourcePath
        Set-Location -Path "C:"
        


    if ($PackageInfoVersion -eq $DriverInfo.Id -and $RunMethod -ne "Force")
        {Write-host "  $Name already current with version $($PackageInfoVersion)" -ForegroundColor Green
        $AlreadyCurrent = $true
        }
    else #Download & Extract
        {
        #Temporary Place to download the softpaq EXE
        $TempCabPath = "$env:TEMP\HPCab"
        if (test-path "$TempCabPath"){Remove-Item -Path $TempCabPath -Force -Recurse}
        New-Item -Path $TempCabPath -ItemType Directory | Out-Null
        $SaveAs = "$($TempCabPath)\$($DriverInfo.Id).exe"
        $ExpandPath = "$($TempCabPath)\Expanded"
        #Location to Expand The files (Package Source)
        $CopyPathExpanded = "$($PackageSource)\Expanded"
        if (test-path "$CopyPathExpanded"){Remove-Item -Path $CopyPathExpanded -Force -Recurse}
        New-Item -Path $CopyPathExpanded -ItemType Directory | Out-Null
        if (test-path "$($PackageSource)\*.xml"){Remove-Item "$($PackageSource)\*.xml" -Force}
        if (test-path "$CopyPathExpanded"){Remove-Item -Path $CopyPathExpanded -Force -Recurse}

        if (!($PackageInfoVersion)){write-host "  $Name package has no previous downloads, downloading: $($DriverInfo.Id)" -ForegroundColor Yellow}
        else{Write-Host "  $Name package is version $($PackageInfoVersion), new version available $($DriverInfo.Id)" -ForegroundColor Yellow}
        Get-Softpaq -Number $($DriverInfo.Id) -SaveAs $saveAs -Extract -DestinationPath $ExpandPath
        copy-item -Path $ExpandPath -Destination $PackageSource -Force -Recurse
        $DriverInfo | Export-Clixml -Path  "$PackageSource\$($DriverInfo.Id).xml"
        $AlreadyCurrent = $false
        }
   
    Write-Host "  Confirming Package Info in ConfigMgr $($PackageInfo.Name) ID: $($HPModel.PackageID)" -ForegroundColor yellow
    Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
    Set-Location -Path "$($SiteCode):"         
    Set-CMPackage -Id $HPModel.PackageID -Version $DriverInfo.Id
    Set-CMPackage -Id $HPModel.PackageID -MIFVersion $DriverInfo.ReleaseDate
    Set-CMPackage -Id $HPModel.PackageID -Description $Description
    $PackageInfo = Get-CMPackage -Id $HPModel.PackageID -Fast
    Update-CMDistributionPoint -PackageId $HPModel.PackageID
    Set-Location -Path "C:"
    Write-Host "Updated Package $($PackageInfo.Name), ID $($HPModel.PackageID) to $($DriverInfo.Id) which was released $($DriverInfo.ReleaseDate)" -ForegroundColor Gray
     Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    }  


Write-Output "Finished Script: $scriptName"
