<# GARY BLOK - @gwblok - GARYTOWN.COM

Download Office Content (Office w/ Visio 2019 & Project 2019 Bits)
Requires the office "Setup.exe" from the Office Deployment Toolkit: https://www.microsoft.com/en-us/download/details.aspx?id=49117
Setup.exe needs to be in the same folder as the script.

Example:
.\o365_download.ps1 -Channel MonthlyEnterprise
.\o365_download.ps1 -Channel SemiAnnual -DownloadOnly
.\o365_download.ps1 -Channel SemiAnnual -ContentOverRideLocation "C:\Temp\o365"
 (when using the -ContentOverRideLocation, it automatically enables -DownloadOnly

This script will lookup your office application, grab the Source Location from the App, back up your current copy, recreate the folder, download office content, copy the o365_Install.ps1 script from the backup folder.
It then will update the detection method (as it is based on the cab name and that it is copied down to the local cache)
It also updates the content on the DPs


THINGS YOU NEED TO UPDATE FOR YOUR ENVIRONEMENT:
$OfficeContentAppName
$OfficeContentAppDTName
$SiteCode
$ProviderMachineName
$Channel - https://docs.microsoft.com/en-us/DeployOffice/update-channels-changes

Future ideas for script: Create Parameters for: Channel, Office App Name & DT, Override Download Location, Skip Updating Application in CM, others..

Change Log
2020.05.07 - Initial Release
2020.05.12 - changed the download.xml to go to env:temp, which resolved an issue when there was a space in the path if the download.xml location was in a folder with a space.
2020.05.12 - replaced hardcode with variable for DT, and added more notes above.
2020.05.12 - added variable for Channel
2020.05.12 - added parameters
 - DownloadOnly: This will skip updating the CM Application's detection method & skip updating the DP
 - Channel: This sets the channel of the office you want to download, updated for the new names
 - ContentOverRideLocation: This lets you pick the location you want the content to download to.
2020.05.18 -Add Language Support.  Still Rough, just downloads to content, and supports 1 language at a time.

2022.01.04 - Added portion for it to download updated Setup.exe file.


#>

[CmdletBinding()] 
param (

        [Parameter(Mandatory=$false)][switch] $DownloadOnly,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][ValidateSet("BetaChannel", "CurrentPreview", "Current", "MonthlyEnterprise", "SemiAnnualPreview", "SemiAnnual", "Broad")][string]$Channel,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][ValidateSet("en-us", "fr-fr", "zh-cn", "zh-tw", "de-de", "it-it")][string]$Language,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$ContentOverRideLocation
    ) 

#Set Office App Name & DT Name - I have them both set to the same thing in my lab, but if you don't you have the option.
$OfficeContentAppName = "Microsoft 365 Content"
$OfficeContentAppDTName = "Microsoft 365 Content"
#Set Cache Location on local host - Used for Detection Method when updating the app
$O365Cache = "C:\ProgramData\O365_Cache"
$SetupPath = "\\src\src$\Apps\Microsoft\Microsoft 365\Microsoft 365 Downloader Script\Setup.exe"
$InstallerScripts = "\\src\src$\Apps\Microsoft\Microsoft 365\Microsoft 365 Installers" #This will be the same folder as the M365 App's Content folder. (just the 3 scripts)

# Site configuration
$SiteCode = "MEM" # Site code 
$ProviderMachineName = "MEMCM.dev.recastsoftware.dev" # SMS Provider machine name

$ODTURL = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=49117"
$ODTURLInfo = Invoke-WebRequest -UseBasicParsing -Uri $ODTURL
$ODTDownloadURL = ($ODTURLInfo.Links | Where-Object {$_.'data-bi-cN' -match "click here"}).href

$ODTDownloadFile = "$env:temp\ODT.exe"
$ODTExtractPath = "$env:temp\ODTExtract"
if (Test-Path $ODTExtractPath){Remove-Item -Path $ODTExtractPath -Force -Recurse}
$NewFolder = New-Item -Path $ODTExtractPath -ItemType Directory -Force

Invoke-WebRequest -UseBasicParsing -Uri $ODTDownloadURL -OutFile $ODTDownloadFile
Start-Process -FilePath $ODTDownloadFile -ArgumentList "/extract:$ODTExtractPath /log:$env:temp\ODT.log /quiet" -wait

$SetupEXEVersion = (Get-Item -Path "$ODTExtractPath\setup.exe").VersionInfo.FileVersion

if (Test-Path $SetupPath){
    $CurrentSetupEXEVersion = (Get-Item -Path $SetupPath).VersionInfo.FileVersion
    if ($CurrentSetupEXEVersion -lt $SetupEXEVersion){
        Set-Location -Path "c:"
        Copy-Item "$ODTExtractPath\setup.exe" -Destination $SetupPath -Force
        }
    }
else
    {
    Set-Location -Path "c:"
    Copy-Item "$ODTExtractPath\setup.exe" -Destination $SetupPath -Force
    }


$LanguageTable= @(
@{ Language = 'French - France'; Number = "1036"; Code = "fr-fr"; AppName = "Microsoft 365 French Content"; AppNameDT ="Microsoft 365 French Content"}
@{ Language = 'Chinese - China'; Number = "2052"; Code = "zh-cn"; AppName = "Microsoft 365 China Content"; AppNameDT ="Microsoft 365 China Content"}
@{ Language = 'Chinese - Taiwan'; Number = "1028"; Code = "zh-cn"; AppName = "Microsoft 365 Taiwan Content"; AppNameDT ="Microsoft 365 Taiwan Content"}
@{ Language = 'German - Germany'; Number = "1031"; Code = "de-de"; AppName = "Microsoft 365 Germany Content"; AppNameDT ="Microsoft 365 Germany Content"}
@{ Language = 'Italian - Italy'; Number = "1040"; Code = "it-it"; AppName = "Microsoft 365 Italy Content"; AppNameDT ="Microsoft 365 Italy Content"}
)




# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}
# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName
}

if ($ContentOverRideLocation)
    {
    $DownloadOnly = $true
    Write-Host "Content Download Over Ride Location enabled"
    Write-Host "Setting Download location to $ContentOverRideLocation"
    $ContentTempDownloadLocation = $ContentOverRideLocation
    }
else 
    {
    $ContentTempDownloadLocation = "$env:temp\MS365Download"
    if (Test-Path $ContentTempDownloadLocation){Remove-Item $ContentTempDownloadLocation -Force -Recurse}
    New-Item -Path $ContentTempDownloadLocation -ItemType Directory -Force
    Write-Host "Content Download to default temp location $ContentTempDownloadLocation"  
    }





#Create Office Download XML File
   [XML]$XML = @"
<Configuration ID="d14f105f-0e82-42c4-b7c5-466a53724c29">
  <Add OfficeClientEdition="64" Channel="Broad">
    <Product ID="O365ProPlusRetail">
      <Language ID="en-us" />
    </Product>
    <Product ID="VisioPro2019Volume" PIDKEY="9BGNQ-K37YR-RQHF2-38RQ3-7VCBB">
      <Language ID="en-us" />
    </Product>
    <Product ID="ProjectPro2019Volume" PIDKEY="B4NPR-3FKK7-T2MBV-FRQ4W-PKD2B">
      <Language ID="en-us" />
    </Product>
  </Add>
</Configuration>
"@

    #Update Channel
    $xml.Configuration.Add.SetAttribute("Channel","$Channel")

    #Update XML to use the Content location of the CM Application
    $newAddAttributeSourcePath = $XML.Configuration.Add
    $newAddAttributeSourcePath.SetAttribute("SourcePath","$ContentTempDownloadLocation")
    
    if ($Language)
        {
        #add additional languages to download
        $newProductAttributeLang = $xml.Configuration.Add.Product
        foreach ($newproduct in $newProductAttributeLang)
            {
            $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("Language"))
            $newXmlNameElement.SetAttribute("ID","$Language")
            }
        }

    #Save the XML to the path that this script is running in.
    $xml.Save("$env:temp\download.xml")
    #Define Setup Engine & Command line to run
    $SetupProcess = "$PSScriptRoot\setup.exe"
    $DownloadArgs = "/Download $env:temp\download.xml"

    
    #Start the Office Download
    Start-Process $SetupProcess -ArgumentList $DownloadArgs -Wait


    
    #Backup Current Content to "Backup" and Create Folder Structure to Download in (Matches the Connent Location in the CMApplication)
    if (!($ContentOverRideLocation))
        {
        #Grab CM Application information to get Source Path location of Office Content
        Set-Location -Path "$($SiteCode):"
        $CMApplication = Get-CMApplication -Name $OfficeContentAppName
        if ($CMApplication)
            {
            $CMDeploymentType = get-CMDeploymentType -ApplicationName $OfficeContentAppName -DeploymentTypeName $OfficeContentAppDTName
            [XML]$AppXML = $CMApplication.SDMPackageXML
            $ContentLocation = 	$AppXML.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location 
            $ContentLocation = $ContentLocation.Substring(0,$ContentLocation.Length-1)
            $ContentLocationParent = $ContentLocation.Replace("$(($ContentLocation.Split("\"))[$ContentLocation.Split("\").Count –1])","")

            }
        else
            {
            Write-Host "No Application for $OfficeContentAppName found"
            }
        if ($Language)
            {
            $LangInfo = $LanguageTable | Where-Object {$_.Code -eq $Language}
            $CMLangDeploymentType = get-CMDeploymentType -ApplicationName $LangInfo.AppName -DeploymentTypeName $LangInfo.AppNameDT
            [XML]$AppLangXML = $CMLangDeploymentType.SDMPackageXML
            $ContentLangLocation = $AppLangXML.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location
            $ContentLangLocation = $ContentLangLocation.Substring(0,$ContentLangLocation.Length-1)
            $ContentLangLocationParent = $ContentLangLocation.Replace("$(($ContentLangLocation.Split("\"))[$ContentLangLocation.Split("\").Count –1])","")
            }
        else
            {
            Write-Host "No Language Application for $($LangInfo.AppName) found"
            }
        Set-Location -Path "c:"
   


        $PreviousCabName = (Get-ChildItem -Path "$ContentLocation\Office\Data\v64_*.cab").Name
        $NewCabName = (Get-ChildItem -Path "$ContentTempDownloadLocation\Office\Data\v64_*.cab").Name


        #Copy the Install Script from the backup location & Setup.exe from the working directory into the Content Folder for the Application

        #Copy-Item -Path "$ContentLocationParent\o365_ContentBackup\o365_Install.ps1" -Destination $ContentLocation -Force
        #Copy-Item -Path $SetupProcess -Destination $ContentLocation -Force
        
        if ($NewCabName -ne $PreviousCabName) #If the Cab name Changed, Update Detection Method and update content on DPs
            {
            Write-Host "Downloaded Version is newer, starting Content Update Process" -ForegroundColor Green
            write-host "Old Version = $PreviousCabName | New = $NewCabName"
            if (!($DownloadOnly))
                {
                #Deal with Language Files.  MOVE Them to the Language Content
                if ($Language)
                    {
                    Write-Host "Language Requested $($LangInfo.Language)"
                    $DownloadedFiles = Get-ChildItem -Path $ContentTempDownloadLocation\* -Recurse
                    $LangFiles = $DownloadedFiles | Where-Object {$_.Name -Match $LangInfo.Number -or $_.Name -Match $Language}
                    if ($LangFiles)
                        {
                        #Delete previous Backups of Language Content and create New Language Content Backup
                        if (Test-Path "$($ContentLangLocation)_Backup"){Remove-Item "$($ContentLangLocation)_Backup" -Force -Recurse}
                        Rename-Item -path $ContentLangLocation -NewName "$($ContentLangLocation)_Backup"
                        New-Item -Path $ContentLangLocation -ItemType Directory -Force
                        #Create the Folder Structure in the Content
                        $FolderPath = (($LangFiles[0].FullName).Replace($ContentTempDownloadLocation, $ContentLangLocation)).Replace($LangFiles[0].Name,"")
                        if (!(test-path -path $FolderPath)){New-Item -Path $FolderPath -ItemType Directory -Force}
                        #Move the Language Files to the Content Source
                        foreach ($File in $LangFiles)
                            {
                            Move-Item -Path $File.Fullname -Destination ($File.FullName).Replace($ContentTempDownloadLocation, $ContentLangLocation) -Force -Verbose
                            }
                        Copy-Item -Path "$InstallerScripts\o365_Install.ps1" -Destination $ContentLangLocation -Force
                        #Used for Detection Method
                        $ConfirmedLangFile = (Get-ChildItem -Path $FolderPath\* -Recurse)[0]
                        if ($ConfirmedLangFile)
                            {
                            Set-Location -Path "$($SiteCode):"
    
                            #Create the new Detection Method (File -> Cache Folder \ OfficeFile.Cab -> exist)
                            $DetectionFilePathLang = ($ConfirmedLangFile.DirectoryName).Replace($ContentLangLocation, "")
                            $DetectionTypeUpdateLang = New-CMDetectionClauseFile -FileName $ConfirmedLangFile.Name -Path "$O365Cache$DetectionFilePathLang" -Existence
                            $ContentVersion = $DetectionFilePathLang.Split("\") | select -Last 1
                            Set-CMApplication -Name $LangInfo.AppName -SoftwareVersion $ContentVersion
    
                            #Add New Detection Method to App
                            Get-CMDeploymentType -ApplicationName $LangInfo.AppName -DeploymentTypeName $LangInfo.AppNameDT | Set-CMScriptDeploymentType -AddDetectionClause $DetectionTypeUpdateLang
    
                            #Get App Info after updating, then Remove the old Detection
                            $CMDeploymentType = Get-CMDeploymentType -ApplicationName $LangInfo.AppName -DeploymentTypeName $LangInfo.AppNameDT
                            [XML]$AppDTXML = $CMDeploymentType.SDMPackageXML
                            [XML]$AppDTDXML = $AppDTXML.AppMgmtDigest.DeploymentType.Installer.DetectAction.args.Arg[1].'#text'
                            $DetectionMethods = $AppDTDXML.EnhancedDetectionMethod.Settings.File
                            $LogicalName = ($DetectionMethods | Where-Object {$_.Filter -ne $ConfirmedLangFile.Name}).LogicalName
                            foreach ($Detection in $LogicalName){$CMDeploymentType | Set-CMScriptDeploymentType -RemoveDetectionClause $Detection}
                            Write-Host "Updated Detection Method for $Language M365 AppDT, now Triggering Content Update" -ForegroundColor Green
                            #Update the DPs
                            Update-CMDistributionPoint -ApplicationName $LangInfo.AppName -DeploymentTypeName $LangInfo.AppNameDT

                            }
                        }
                    else {Write-Output "No Language Files Downloaded"}             
                    }
                #Replace Source with new Media
                Set-Location -Path "c:"
                if (Test-Path "$($ContentLocation)_Backup"){Remove-Item "$($ContentLocation)_Backup" -Force -Recurse}
                Rename-Item -path $ContentLocation -NewName "$($ContentLocation)_Backup"
                New-Item -Path $ContentLocation -ItemType Directory -Force
                Write-Host "Copying Content to Source Location" -ForegroundColor Green
                Copy-Item -Path "$ContentTempDownloadLocation\Office" -Destination $ContentLocation -Force -Recurse
                Copy-Item -Path "$InstallerScripts\o365_Install.ps1" -Destination $ContentLocation -Force
                Copy-Item -Path $SetupProcess -Destination $ContentLocation -Force
                Write-Host "  Completed Copying Content to Source Location" -ForegroundColor Green
            #Get the Cab Name of the updated download and use it for the Detection Method.

                Set-Location -Path "$($SiteCode):"
    
                #Create the new Detection Method (File -> Cache Folder \ OfficeFile.Cab -> exist)
                $DetectionFilePath = "$O365Cache\Office\Data"
                $DetectionTypeUpdate = New-CMDetectionClauseFile -FileName $NewCabName -Path $DetectionFilePath -Existence
                Write-Host "Setting Detection Method to $NewCabName"
                
                #Update CM Application Version
                $VersionNumber = (($NewCabName).replace("v64_","")).replace(".cab","")
                Set-CMApplication -InputObject $CMApplication -SoftwareVersion $VersionNumber

                #Add New Detection Method to AppDT
                Get-CMDeploymentType -ApplicationName $OfficeContentAppName -DeploymentTypeName $OfficeContentAppDTName | Set-CMScriptDeploymentType -AddDetectionClause $DetectionTypeUpdate
    
                #Get App Info after updating, then Remove the old Detection
                $CMDeploymentType = get-CMDeploymentType -ApplicationName $OfficeContentAppName -DeploymentTypeName $OfficeContentAppDTName
                [XML]$AppDTXML = $CMDeploymentType.SDMPackageXML
                [XML]$AppDTDXML = $AppDTXML.AppMgmtDigest.DeploymentType.Installer.DetectAction.args.Arg[1].'#text'
                $DetectionMethods = $AppDTDXML.EnhancedDetectionMethod.Settings.File
                $LogicalName = ($DetectionMethods | Where-Object {$_.Filter -ne $NewCabName}).LogicalName
                foreach ($Detection in $LogicalName){$CMDeploymentType | Set-CMScriptDeploymentType -RemoveDetectionClause $Detection}
                Write-Host "Updated Detection Method for M365 AppDT, now Triggering Content Update" -ForegroundColor Green
                #Update the DPs
                Update-CMDistributionPoint -ApplicationName $OfficeContentAppName -DeploymentTypeName $OfficeContentAppDTName
                }
            }
        }
Set-Location -Path "c:"
