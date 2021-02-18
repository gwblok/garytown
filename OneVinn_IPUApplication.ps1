<#
.SYNOPSIS
    --.Setup the CM Application & Collections for the ONEVinn IPUApplication
.DESCRIPTION

This will Download the OneVinn IPU Application "kit" and setup
 - Creates Source Files on your CM Source
 - Creates the CM Application
 - Creates the Collections
    - Query Based:
      - Windows 10 Build < Release ID
      - IPU Success
      - IPU PendingReboot
      - IPU Failed
    - Direct Members
      - IPU Windows 10 Release ID
        - Also creates Daily MW on this collection

REQUIREMENTS, You need to setup hardware inventory items (Section 7 in the docs), edits to the configuration.mof & import of the sms.mof provided in the download.

The first time you run this, it will download and create the apps, then exit saying you need to update the hardware inventory, once you do that, after you run again, it will continue and build collections

You'll need to update several varaibles, for both your environment, and for the build you're deploying.

This does NOT setup and leverage the "Deployment Advanced" features, (Section 13 in the docs) 

.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by @gwblok
.LINK
    https://garytown.com
.LINK
    https://www.recastsoftware.com
.COMPONENT
    --
.FUNCTIONALITY
    --
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

$ScriptVersion = "21.1.11.1"

# Site configuration
$SiteCode = "PS2" # Site code 
$ProviderMachineName = "CM.corp.viamonstra.com" # SMS Provider machine name

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams


#Source Server
$SourceServer = "\\SRC.corp.viamonstra.com\src$"
$Release = "20H2" #Used for Collection Names & App Names
$Build = "19042" #Used In Query, need to update the Detection Method below as well

#App Names (Used for Names & AppDT Names)
$IPUAppName = "Windows 10 $Release Upgrade"
$IPUAppSourceLocation = "$SourceServer\Apps\IPUApplication\$Release\" #This will be the App Source on your Server
$IPUAppImageIconURL = "https://upload.wikimedia.org/wikipedia/commons/0/08/Windows_logo_-_2012_%28dark_blue%29.png"
$IPUAppDownloadURL = "https://onevinn.schrewelius.it/Files/IPUInstaller/IPUInstaller.zip"
$IPUAppExtractPath = "$SourceServer\Apps\OneVinn\IPUApplicationExtract" #Where you want to keep the extracted Source (NOT THE APP ITSELF)
$UpgradeMediaPath = "$SourceServer\OSD\OSImages\Win10x64-Enterprise\20H2\Pre-Prod"  #Where you keep your Upgrade Media currently
$CollectionFolderName = "OneVinn IPU"
$DeadlineDateTime = '12/25/2021 20:00:00'

## Get script path and name
[string]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[string]$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)

$DetectionMethod = {

    $BuildNumber = "19042"

    $statusOk = $false

    try {
        $statusOk = (Get-ItemProperty -Path HKLM:\SOFTWARE\Onevinn\IPUStatus -Name 'IPURestartPending' -ErrorAction Stop).IPURestartPending -eq "True"
    }
    catch {}

    if ($statusOk) {
        Set-ItemProperty -Path HKLM:\SOFTWARE\Onevinn\IPUStatus -Name 'IPURestartPending' -Value "False" -Force | Out-Null
    }
    else {
        $statusOk = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name 'CurrentBuild').CurrentBuild -eq $BuildNumber
    }

    if ($statusOk) {
        Write-Output "Installed"
    }
}




#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings



#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================

#region ScriptBody - Build Application


#Test Extract Path
Write-Host "Starting Build of OneVinn IPUApplication Build" -ForegroundColor Magenta
Set-Location -Path "c:\"
if (!(Test-Path $IPUAppExtractPath))
    {
    Write-Host "Creating Folder $IPUAppExtractPath" -ForegroundColor Green
    $NewFolder = New-Item -Path $IPUAppExtractPath -ItemType directory -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host " Downloading Requirements from Internet" -ForegroundColor Green
    #Download IPUApplication from OneVinn
    Invoke-WebRequest -Uri $IPUAppDownloadURL -UseBasicParsing -OutFile "$env:TEMP\IPUApp.zip"
    #Download Icon for Application in Software Center
    Invoke-WebRequest -Uri $IPUAppImageIconURL -OutFile "$IPUAppExtractPath\AppIcon.png"
    Unblock-File "$env:TEMP\IPUApp.zip"
    Write-Host " Extract Download" -ForegroundColor Green
    Expand-Archive -Path "$env:TEMP\IPUApp.zip" -DestinationPath $IPUAppExtractPath
    }


#Create App
    
    Set-Location "$($SiteCode):\"
    if (Get-CMApplication -Fast -Name $IPUAppName)
        {
        Write-Host "Application: $IPUAppName already exist" -ForegroundColor Green
        }
    else
        {
        Write-Host "Creating Application: $IPUAppName" -ForegroundColor Green
        $NewIPUApp = New-CMApplication -Name $IPUAppName -Publisher "OneVinn" -LocalizedName $IPUAppName -LocalizedDescription "Upgrades PC to $Release.  There will be several reboots, but you will be prompted.  It is still recommended you save your work before installing."
        if (!($IPUAppUserCat = Get-CMCategory -Name "IPUApplication" -CategoryType CatalogCategories))
            {
            $IPUAppUserCat = New-CMCategory -CategoryType CatalogCategories -Name "IPUApplication"
            }
        Set-CMApplication -InputObject $NewIPUApp -AddUserCategory $IPUAppUserCat
        Set-CMApplication -InputObject $NewIPUApp -SoftwareVersion $Release
        Write-Host " Completed" -ForegroundColor Gray
         #Set Icon for Software Center
        Set-Location "$($SiteCode):\"
        Set-CMApplication -InputObject $NewIPUApp -IconLocationFile $IPUAppExtractPath\AppIcon.png
        Write-Host " Set App SC Icon on: $IPUAppName" -ForegroundColor Green
        }

#Create AppDT Base
    Set-Location -Path "C:"
    if (Test-Path $IPUAppSourceLocation){}
    else 
        {               
        Write-host " Creating Source Folder Structure: $IPUAppSourceLocation" -ForegroundColor Green
        $NewFolder = New-Item -Path $IPUAppSourceLocation -ItemType directory -ErrorAction SilentlyContinue      
        Write-Host " Starting Copy of Content, App & Media" -ForegroundColor Green
        Copy-Item -Path "$IPUAppExtractPath\IPUApplication\*" -Destination $IPUAppSourceLocation -Recurse -Force
        Copy-Item -Path "$UpgradeMediaPath\*" -Destination "$IPUAppSourceLocation\Media" -Recurse -Force
        }
    Set-Location -Path "$($SiteCode):"
    if (Get-CMDeploymentType -ApplicationName $IPUAppName -DeploymentTypeName $IPUAppName)
        {
        Write-Host " AppDT already Created" -ForegroundColor Green
        }
    else
        {
        Write-Host " Starting AppDT Creation" -ForegroundColor Green
        $NewIPUAppDT = Add-CMScriptDeploymentType -ApplicationName $IPUAppName -DeploymentTypeName $IPUAppName -ContentLocation $IPUAppSourceLocation -InstallCommand "IPUInstaller.exe" -InstallationBehaviorType InstallForSystem -Force32Bit:$true -EstimatedRuntimeMins "60" -MaximumRuntimeMins "120" -ScriptLanguage PowerShell -ScriptText $DetectionMethod
        Write-Host "  Created AppDT: $IPUAppName" -ForegroundColor Green
        #Distribute Content
        Get-CMDistributionPointGroup | foreach { Start-CMContentDistribution -ApplicationName $IPUAppName -DistributionPointGroupName $_.Name}
        }

#endregion


<#

write code to add information to hardware inventory... ideas:
https://trevorsullivan.net/2011/07/05/extreme-powershell-configmgr-extending-hardware-inventory/
#>


#region ScriptBody - Build Collections - REQUIRES YOU ALREADY EXTENDED HARWARE INVENTORY (MOF FILES)

<# Collections
Windows 10 Build < 20H2
IPU Success
IPU PendingReboot
IPU Failed
#>

#Create Test Collection and QUery, if Fails, Exit Script asking for Hardware Inv to be Extended
New-CMDeviceCollection -Name "TestHWInvQuery" -Comment "Used to test if Hardware Inv Settings have been added yet, See Section 7 in PDF Doc" -LimitingCollectionName "All Systems" -RefreshSchedule $Schedule -RefreshType 2 |Out-Null
$TestQuery = @" 
select
SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from
SMS_R_System inner join SMS_G_System_IpuResult on SMS_G_System_IpuResult.ResourceId = SMS_R_System.ResourceId where SMS_G_System_IpuResult.LastStatus = "Test"
"@
Add-CMDeviceCollectionQueryMembershipRule -RuleName "Query TestHWInvQuery" -CollectionName "TestHWInvQuery" -QueryExpression $TestQuery -ErrorAction SilentlyContinue | Out-Null
$TestQueryResult = Get-CMCollectionQueryMembershipRule -CollectionName "TestHWInvQuery"

if (!($TestQueryResult))
    {
    Remove-CMCollection -Name "TestHWInvQuery" -Force
    Clear-Host
    Write-Host "========================================================================================================================================================================" -ForegroundColor Cyan
    Write-Host "Hardware Inv not setup properly to allow creation of query based collections, please read the docs, section 7, and finish the setup of the inventory, then re-run script" -ForegroundColor Yellow
    Write-Host "========================================================================================================================================================================" -ForegroundColor Cyan

    }
else
    {
    Write-Host "Hardware INV appears to be setup, continuing..." -ForegroundColor Green
    Remove-CMCollection -Name "TestHWInvQuery" -Force
    Write-Host "Starting Collection Creation" -ForegroundColor Magenta
$LimitingCollection = "All Workstations"  #Creates this later if does not exist

#Create Collection Folder
If (-not (Test-Path -Path ($SiteCode +":\DeviceCollection\$CollectionFolderName")))
    {
    Write-host "Device collection folder name $CollectionFolderName was not found. Creating folder..." -ForegroundColor Green
    New-Item -Name $CollectionFolderName -Path ($SiteCode +":\DeviceCollection")
    $FolderPath = ($SiteCode +":\DeviceCollection\$CollectionFolderName")
    Write-host "Device collection folder $CollectionFolderName created." -ForegroundColor Green
    Write-host "You will need to Close and Open your Console to see the Folder & Collections!!!" -ForegroundColor Yellow
    }
elseif ((Test-Path -Path ($SiteCode.Name +":\DeviceCollection\$CollectionFolderName")) -and ($CreateCollectionFolder))
    {
    Write-host "Device collection folder name $CollectionFolderName already exists...will move newly created collections to this folder." -ForegroundColor Yellow
    $FolderPath = ($SiteCode +":\DeviceCollection\$CollectionFolderName")
    }

    #Confirm All Workstation Collection, or create it if needed
    $AllWorkstationCollection = Get-CMCollection -Name $LimitingCollection
    if ($AllWorkstationCollection -eq $Null)
        {
$CollectionQueryAllWorkstations = @"
select SMS_R_System.Name from  SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT Workstation%"
"@     
    
    New-CMDeviceCollection -Name $LimitingCollection -Comment "Collection of all workstation machines" -LimitingCollectionName "All Systems" -RefreshSchedule $Schedule -RefreshType 2 |Out-Null
    Add-CMDeviceCollectionQueryMembershipRule -RuleName "All Workstations" -CollectionName $LimitingCollection -QueryExpression $CollectionQueryAllWorkstations | Out-Null
    $AllWorkstationCollection = Get-CMCollection -Name $LimitingCollection
    Write-Host " Created All Workstations Collection ID: $($AllWorkstationCollection.CollectionID), which will be used as the limiting collections moving forward" -ForegroundColor Green
    }
    else {Write-Host " Found All Workstations Collection ID: $($AllWorkstationCollection.CollectionID), which will be used as the limiting collections moving forward" -ForegroundColor Green}

    #Set Schedule to Evaluate Weekly (from the time you run the script)
    $Schedule = New-CMSchedule -Start (Get-Date).DateTime -RecurInterval Days -RecurCount 7

    $CollectionName = "Windows 10 Build < $Release"
    Write-Host " Creating Collection $CollectionName" -ForegroundColor Green
$BuildLessThanReleaseIDQuery = @"
select
SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from
SMS_R_System inner join SMS_G_System_OPERATING_SYSTEM on
SMS_G_System_OPERATING_SYSTEM.ResourceId = SMS_R_System.ResourceId where
SMS_G_System_OPERATING_SYSTEM.BuildNumber < "19042" and
SMS_G_System_OPERATING_SYSTEM.Caption = "Microsoft Windows 10 Enterprise"
"@
    New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName $LimitingCollection -RefreshSchedule $Schedule -RefreshType Periodic -Comment "Workstations running less than 20H2" | Out-Null
    $Collection_Build = Get-CMCollection -Name $CollectionName
    Add-CMDeviceCollectionQueryMembershipRule -RuleName "Query $CollectionName" -CollectionName $CollectionName -QueryExpression $BuildLessThanReleaseIDQuery | Out-Null
    Move-CMObject -FolderPath $FolderPath -InputObject $(Get-CMDeviceCollection -Name $CollectionName)

    $CollectionName = "IPU Success"
    $Comment = "Machines that Successfully Upgraded using the $IPUAppName"
    Write-Host " Creating Collection $CollectionName" -ForegroundColor Green
$IPUSuccessQuery = @" 
select
SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from
SMS_R_System inner join SMS_G_System_IpuResult on SMS_G_System_IpuResult.ResourceId = SMS_R_System.ResourceId where SMS_G_System_IpuResult.LastStatus = "Success"
"@
    New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName $LimitingCollection -RefreshSchedule $Schedule -RefreshType Periodic -Comment $Comment | Out-Null
    $Collection_Success  = Get-CMCollection -Name $CollectionName
    Add-CMDeviceCollectionQueryMembershipRule -RuleName "Query $CollectionName" -CollectionName $CollectionName -QueryExpression $IPUSuccessQuery | Out-Null
    Move-CMObject -FolderPath $FolderPath -InputObject $(Get-CMDeviceCollection -Name $CollectionName)

    $CollectionName = "IPU PendingReboot"
    $Comment = "Machines that are Pending a Reboot"
    Write-Host " Creating Collection $CollectionName" -ForegroundColor Green
$IPUPendingRebootQuery = @" 
select
SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from
SMS_R_System inner join SMS_G_System_IpuResult on SMS_G_System_IpuResult.ResourceId = SMS_R_System.ResourceId where SMS_G_System_IpuResult.LastStatus = "PendingReboot"
"@
    New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName $LimitingCollection -RefreshSchedule $Schedule -RefreshType Periodic -Comment $Comment | Out-Null
    $Collection_Pending = Get-CMCollection -Name $CollectionName
    Add-CMDeviceCollectionQueryMembershipRule -RuleName "Query $CollectionName" -CollectionName $CollectionName -QueryExpression $IPUPendingRebootQuery | Out-Null
    Move-CMObject -FolderPath $FolderPath -InputObject $(Get-CMDeviceCollection -Name $CollectionName)

    $CollectionName = "IPU Failed"
    $Comment = "Machines that Failed Upgraded using the $IPUAppName"
    Write-Host " Creating Collection $CollectionName" -ForegroundColor Green
$IPUFailedQuery = @" 
select
SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.
SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from
SMS_R_System inner join SMS_G_System_IpuResult on SMS_G_System_IpuResult.ResourceId = SMS_R_System.ResourceId where SMS_G_System_IpuResult.LastStatus = "Failed"
"@
    New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName $LimitingCollection -RefreshSchedule $Schedule -RefreshType Periodic -Comment $Comment | Out-Null
    $Collection_Failed = Get-CMCollection -Name $CollectionName
    Add-CMDeviceCollectionQueryMembershipRule -RuleName "Query $CollectionName" -CollectionName $CollectionName -QueryExpression $IPUFailedQuery | Out-Null
    Move-CMObject -FolderPath $FolderPath -InputObject $(Get-CMDeviceCollection -Name $CollectionName)
    }


    $CollectionName = "IPU Windows 10 $Release"
    $Comment = "Machines You want to have the Upgrade Available to $IPUAppName"
    Write-Host " Creating Collection $CollectionName" -ForegroundColor Green
    New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName $Collection_Build.Name -RefreshSchedule $Schedule -RefreshType Periodic -Comment $Comment | Out-Null
    $Collection_IPUDeployment = Get-CMCollection -Name $CollectionName
    Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $CollectionName -ExcludeCollectionId $Collection_Success.CollectionID
    Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $CollectionName -ExcludeCollectionId $Collection_Pending.CollectionID
    Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $CollectionName -ExcludeCollectionId $Collection_Failed.CollectionID
    Move-CMObject -FolderPath $FolderPath -InputObject $(Get-CMDeviceCollection -Name $CollectionName)

#endregion


#region ScriptBody - Deploy App to IPU Collection & MW Window

if ($TestQueryResult)
    {
    #New-CMClientSetting -Name "IPUApplication"
    Write-Host "Deployment & Maintenece Window" -ForegroundColor Magenta
    write-host " Creating Deployment for $IPUAppName to Collection $($Collection_IPUDeployment.name)" -ForegroundColor Green
    $Deployment = New-CMApplicationDeployment -Name $IPUAppName -CollectionId $Collection_IPUDeployment.CollectionID -DeployAction Install -DeployPurpose Required -UserNotification DisplayAll -DeadlineDateTime $DeadlineDateTime
    # Example - Every Monday @ 8PM for 8 Hours
    #$MWSchedule = New-CMSchedule -DayOfWeek Monday -DurationCount 8 -DurationInterval Hours -RecurCount 1 -Start "10/12/2013 20:00:00"
    # Set to Daily @ 8PM for 8 hours
    write-host " Creating MW for $($Collection_IPUDeployment.name) that runs daily @ 8PM" -ForegroundColor Green
    $MWSchedule = New-CMSchedule -DurationCount 8 -DurationInterval Hours -RecurCount 1 -Start "10/12/2013 20:00:00" -RecurInterval Days
    $DeploymentMW = New-CMMaintenanceWindow  -CollectionId $Collection_IPUDeployment.CollectionID -IsEnabled:$true -Schedule $MWSchedule -Name "Windows Upgrades"
    }
#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
