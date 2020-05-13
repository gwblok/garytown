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


#>

[CmdletBinding()] 
param (

        [Parameter(Mandatory=$false)][switch] $DownloadOnly,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][ValidateSet("BetaChannel", "CurrentPreview", "Current", "MonthlyEnterprise", "SemiAnnualPreview", "SemiAnnual")][string]$Channel,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$ContentOverRideLocation
    ) 

#Set Office App Name & DT Name - I have them both set to the same thing in my lab, but if you don't you have the option.
$OfficeContentAppName = "Microsoft 365 Content"
$OfficeContentAppDTName = "Microsoft 365 Content"
#Set Cache Location on local host - Used for Detection Method when updating the app
$O365Cache = "C:\ProgramData\O365_Cache"

# Site configuration
$SiteCode = "PS2" # Site code 
$ProviderMachineName = "cm.corp.viamonstra.com" # SMS Provider machine name
# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}
# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName
}

if ($ContentOverRideLocation){$DownloadOnly = $true}

#Grab CM Application information to get Source Path location of Office Content
Set-Location -Path "$($SiteCode):"
if (!($ContentOverRideLocation))
    {
    $CMApplication = Get-CMApplication -Name $OfficeContentAppName
    if ($CMApplication)
        {
        $CMDeploymentType = get-CMDeploymentType -ApplicationName $OfficeContentAppName -DeploymentTypeName $OfficeContentAppDTName
        [XML]$AppXML = $CMApplication.SDMPackageXML
        $ContentLocation = 	$AppXML.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location
        Set-Location -Path "c:"
        }
    else
        {
        Write-Host "No Application for $OfficeContentAppName found"
        #exit
        }
    }
else
    {
    Write-Host "Content Download Over Ride Location enabled"
    Write-Host "Setting Download location to $ContentOverRideLocation"
    $ContentLocation = $ContentOverRideLocation
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
    $newAddAttributeSourcePath.SetAttribute("SourcePath","$ContentLocation")

    #Save the XML to the path that this script is running in.
    $xml.Save("$env:temp\download.xml")
    #Define Setup Engine & Command line to run
    $SetupProcess = "$PSScriptRoot\setup.exe"
    $DownloadArgs = "/Download $env:temp\download.xml"

    #Backup Current Content to "Backup" and Create Folder Structure to Download in (Matches the Connent Location in the CMApplication)
    if (!($ContentOverRideLocation))
        {
        $ContentLocation = $ContentLocation.Substring(0,$ContentLocation.Length-1)
        $ContentLocationParent = $ContentLocation.Replace("$(($ContentLocation.Split("\"))[$ContentLocation.Split("\").Count –1])","")
        $PreviousCabName = (Get-ChildItem -Path "$ContentLocation\Office\Data\v64_*.cab").Name
        if (Test-Path "$ContentLocationParent\o365_ContentBackup"){Remove-Item "$ContentLocationParent\o365_ContentBackup" -Force -Recurse}
        Rename-Item -path $ContentLocation -NewName "$ContentLocationParent\o365_ContentBackup"
        }
    New-Item -Path $ContentLocation -ItemType Directory -Force

    #Start the Office Download
    Start-Process $SetupProcess -ArgumentList $DownloadArgs -Wait
    #Copy the Install Script from the backup location & Setup.exe from the working directory into the Content Folder for the Application
    if (!($ContentOverRideLocation))
        {
        Copy-Item -Path "$ContentLocationParent\o365_ContentBackup\o365_Install.ps1" -Destination $ContentLocation -Force
        Copy-Item -Path $SetupProcess -Destination $ContentLocation -Force
        
        if (!($DownloadOnly))
            {
            #Get the Cab Name of the updated download and use it for the Detection Method.
            $CabName = (Get-ChildItem -Path "$ContentLocation\Office\Data\v64_*.cab").Name

            if ($CabName -ne $PreviousCabName) #If the Cab name Changed, Update Detection Method and update content on DPs
                {
                Set-Location -Path "$($SiteCode):"
    
                #Create the new Detection Method (File -> Cache Folder \ OfficeFile.Cab -> exist)
                $DetectionFilePath = "$O365Cache\Office\Data"
                $DetectionTypeUpdate = New-CMDetectionClauseFile -FileName $CabName -Path $DetectionFilePath -Existence
    
                #Add New Detection Method to AppDT
                Get-CMDeploymentType -ApplicationName $OfficeContentAppName -DeploymentTypeName $OfficeContentAppDTName | Set-CMScriptDeploymentType -AddDetectionClause $DetectionTypeUpdate
    
                #Get App Info after updating, then Remove the old Detection
                $CMDeploymentType = get-CMDeploymentType -ApplicationName $OfficeContentAppName -DeploymentTypeName $OfficeContentAppDTName
                [XML]$AppDTXML = $CMDeploymentType.SDMPackageXML
                [XML]$AppDTDXML = $AppDTXML.AppMgmtDigest.DeploymentType.Installer.DetectAction.args.Arg[1].'#text'
                $DetectionMethods = $AppDTDXML.EnhancedDetectionMethod.Settings.File
                $LogicalName = ($DetectionMethods | Where-Object {$_.Filter -ne $CabName}).LogicalName
                Get-CMDeploymentType -ApplicationName $OfficeContentAppName -DeploymentTypeName $OfficeContentAppDTName | Set-CMScriptDeploymentType -RemoveDetectionClause $LogicalName

                #Update the DPs
                Update-CMDistributionPoint -ApplicationName $OfficeContentAppName -DeploymentTypeName $OfficeContentAppDTName
                }
            }
        }
Set-Location -Path "c:"

