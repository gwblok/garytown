<#  Version 2022.02.06 - Creator @gwblok - GARYTOWN.COM
    Used to download Drivers Updates from Lenovo
    Grabs Drivers Files based on your CM Package Structure... based on this: https://github.com/gwblok/garytown/blob/master/hardware/CreateCMPackages_BIOS_Drivers.ps1

    Extracts the Lenovo EXE and places them into a WIM

    Usage... Stage Prod or Pre-Prod.
    If you don't do Pre-Prod... just delete that Param section out and set $Stage = Prod or remove all Stage references complete, do whatever you want I guess.

    If you have a Proxy, you'll have to modify for that.


#>

[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false,Position=1,HelpMessage="Stage")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("Pre-Prod", "Prod")]
		    $Stage = "Prod"

 	    )

$Manufacturer = "LENOVO"
$DownloadPath = "$env:TEMP\$Manufacturer"
$CapturePath = "$DownloadPath\Extract"
$ScatchLocation = "E:\DedupExclude"
$DismScratchPath = "$ScatchLocation\DISM"



# Site configuration
$SiteCode = "MEM" # Site code 
$ProviderMachineName = "MEMCM.dev.recastsoftware.dev" # SMS Provider machine name

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" 

if (Test-Path -Path $CapturePath){Remove-Item -Path $CapturePath -Recurse -Force}
$NUll = New-Item -Path $CapturePath -ItemType Directory -Force



#To Select
$ModelsSelectTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq $Manufacturer -and $_.Mifname -eq $Stage} |Select-Object -Property "Name","MIFFilename","PackageID", "Version" | Sort-Object $_.MIFFilename | Out-GridView -Title "Select the Models you want to Update" -PassThru
$ModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.PackageID -in $ModelsSelectTable.PackageID}
Set-Location -Path "C:"

$systemFamily = (Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty SystemFamily).trim()
$DriverURL = "https://download.lenovo.com/cdrt/td/catalogv2.xml"


Write-Host "Loading Lenovo Catalog XML...." -ForegroundColor Yellow

if (($DriverURL.StartsWith("https://")) -OR ($DriverURL.StartsWith("http://"))) {
    try { $testOnlineConfig = Invoke-WebRequest -Uri $DriverURL -UseBasicParsing } catch { <# nothing to see here. Used to make webrequest silent #> }
    if ($testOnlineConfig.StatusDescription -eq "OK") {
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.Encoding = [System.Text.Encoding]::UTF8
            $Xml = [xml]$webClient.DownloadString($DriverURL)
            Write-host "Successfully loaded $DriverURL"
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            Write-Host "Error, could not read $DriverURL" 
            Write-Host "Error message: $ErrorMessage"
            #Exit 1
        }
    }
    else {
        Write-Host "The provided URL to the config does not reply or does not come back OK"
        #Exit 1
    }
}


foreach ($Model in $ModelsTable)#{}
    {
    Write-Host "----------------------------" -ForegroundColor DarkGray
    Write-Host "Starting to Process Model: $($Model.MifFileName)" -ForegroundColor Green
    
    #Get Info about Driver Package from XML
    $ModelDriverPackInfo = $Xml.ModelList.Model | Where-Object -FilterScript {$_.Types.Type -match $Model.Language} 
    if($ModelDriverPackInfo.SCCM.Version -eq '*')
    {
    Write-Host "SCCM Version starts with *"
    $Downloadurl = $ModelDriverPackInfo.SCCM  | Where-Object -FilterScript {($_.'#text' -match 'w1064')} |select  -ExpandProperty '#text'
    }
    else{
    $Win10version = ($ModelDriverPackInfo.SCCM.Version | measure -Maximum).Maximum
    Write-Host "SCCM Version starts with ReleaseID $Win10version"
    $TargetLink = $ModelDriverPackInfo.SCCM  | Where-Object -FilterScript {($_.Version -eq $Win10version)} |select  -ExpandProperty '#text'
    }


    #Get Info about Driver Package from XML
    $TargetVersion = ($TargetLink.Split("_")| Select-Object -Last 1).replace(".exe","")
    $TargetFileName = $TargetLink.Split("/") | Where-Object {$_ -match ".exe"}
    $ReleaseDate = $TargetVersion.Substring(0,4) + "-" + $TargetVersion.Substring(4,2)
    $TargetFilePathName = "$DownloadPath\$TargetFileName" 

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
            #Expand Download
            if (Test-Path -Path $CapturePath){Remove-Item -Path $CapturePath -Recurse -Force}
            $Null = New-Item -Path $CapturePath -ItemType Directory -Force
            $OfflineFolder = "$CapturePath\Offline"
            $OnlineFolder = "$CapturePath\Online"
            $Null = New-Item -Path $OfflineFolder -ItemType Directory -Force
            $Null = New-Item -Path $OnlineFolder -ItemType Directory -Force


            $LenovoSilentSwitches = "/VERYSILENT /DIR=" + '"' + $OfflineFolder + '"'
			$Expand = Start-Process -FilePath $TargetFilePathName -ArgumentList $LenovoSilentSwitches -Verb RunAs -PassThru -Wait

            #WIM Expanded Files
            # Cleanup Previous Runs (Deletes the files)
            if (Test-Path $dismscratchpath) {Remove-Item $DismScratchPath -Force -Recurse -ErrorAction SilentlyContinue}
            if (Test-Path $($Model.PkgSourcePath)) {Remove-Item $($Model.PkgSourcePath) -Force -Recurse -ErrorAction SilentlyContinue}       
            $Null = New-Item -Path $($Model.PkgSourcePath) -ItemType Directory -Force
            $DismScratch = New-Item -Path $DismScratchPath -ItemType Directory -Force
            New-WindowsImage -ImagePath "$($Model.PkgSourcePath)\Drivers.wim" -CapturePath "$CapturePath" -Name "$($Model.MIFFilename) - $($Model.Language)"  -LogPath "$env:TEMP\dism-$($Model.MIFFilename).log" -ScratchDirectory $dismscratchpath
            $ReadmeContents = "Model: $($Model.Name) | Pack Version: $TargetVersion | CM PackageID: $($Model.PackageID)"
            $ReadmeContents | Out-File -FilePath "$($Model.PkgSourcePath)\$($TargetVersion).txt"
            Set-Location -Path "$($SiteCode):"
            Update-CMDistributionPoint -PackageId $Model.PackageID
            Set-Location -Path "C:"
            [int]$DriverWIMSize = "{0:N2}" -f ((Get-ChildItem $($Model.PkgSourcePath) -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum / 1MB)
            [int]$DriverExtractSize = "{0:N2}" -f ((Get-ChildItem $CapturePath -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum / 1MB)

            Write-Host " Finished Expand & WIM Process, WIM size: $DriverWIMSize vs Expaneded: $DriverExtractSize" -ForegroundColor Green
            Write-Host " WIM Savings: $($DriverExtractSize - $DriverWIMSize) MB | $(100 - $([MATH]::Round($($DriverWIMSize / $DriverExtractSize)*100))) %" -ForegroundColor Green
            
            Write-Host " Confirming Package $($Model.Name) with updated Info" -ForegroundColor Yellow
            Set-Location -Path "$($SiteCode):"
            Set-CMPackage -Id $Model.PackageID -Version $TargetVersion
            Set-CMPackage -Id $Model.PackageID -MifVersion $ReleaseDate
            Set-CMPackage -Id $Model.PackageID -Description $TargetLink
            Set-Location -Path "C:"
            }
        else{ Write-Host "  Failed to Download: $TargetLink" -ForegroundColor red}
        }
    else {Write-Host " No Update Available: Current CM Version:$($Model.Version) | $Manufacturer Online version $TargetVersion" -ForegroundColor Green}
    }

