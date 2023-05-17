<# GARY BLOK | @gwblok | RecastSoftware.com

Updated the Edge Pre-Prod & Edge BETA Apps in CM.
Requires 4 Apps Setup in CM, Edge, Edge Pre-Prod, Edge BETA, Edge Go Back
Future Blog Post to explain.

#>


# Site configuration
$SiteCode = "PS2" # Site code 
$ProviderMachineName = "CM.corp.viamonstra.com" # SMS Provider machine name

# Customizations
$initParams = @{}



Function Get-MSIVersion
    {
     Param([string]$path) 
if (!($path)){return "No Path Provided"}
if ($path -notmatch ".MSI"){return "Not MSI File"}
$windowsInstaller = New-Object -ComObject WindowsInstaller.Installer
function Get-Property ($Object, $PropertyName, [object[]]$ArgumentList) {
return $Object.GetType().InvokeMember($PropertyName, 'Public, Instance, GetProperty', $null, $Object, $ArgumentList)
}
$MSI = $windowsInstaller.OpenDatabase("$path", 0)
$PropertiesView = $MSI.OpenView("select * from Property")
$PropertiesView.Execute()
do
{
$Properties = $PropertiesView.Fetch()
$PropertyName = (Get-Property $Properties StringData 1)
[String]$Value = (Get-Property $Properties StringData 2)
}
until ($PropertyName -eq "ProductVersion")

$PropertiesView.Close()
$MSI.Commit()
$MSI = $null

[system.gc]::Collect()
[System.gc]::waitforpendingfinalizers()

return [string]$Value
}


#region: CMTraceLog Function formats logging in CMTrace style
        function Write-CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "SchTask",
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$false)]
		    $LogFile = "D:\ScheduledTaskScripts\MSEdgeCMAppUpdater.log"
	    )
    <#
    Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
	    $Time = Get-Date -Format "HH:mm:ss.ffffff"
	    $Date = Get-Date -Format "MM-dd-yyyy"
 
	    if ($ErrorMessage -ne $null) {$Type = 3}
	    if ($Component -eq $null) {$Component = " "}
	    if ($Type -eq $null) {$Type = 1}
 
	    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
	    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
    }

$ScriptVer = "2021.01.26.1"
$whoami = whoami

Write-CMTraceLog -Message "=====================================================" -Type 1
Write-CMTraceLog -Message "Starting DOWNLOAD & UPDATE PREPROD Script version $ScriptVer..." -Type 1
Write-CMTraceLog -Message "=====================================================" -Type 1
Write-CMTraceLog -Message "Running Script as $whoami" -Type 1

try {
# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}
$GetModule = Get-Module ConfigurationManager
if(($GetModule) -eq $null) {
    Write-CMTraceLog -Message "Failed to Import ConfigMgr PowerShell Module" -Type 3
    }
else
    {
    Write-CMTraceLog -Message "ConfigMgr PowerShell Module Ver: $($GetModule.Version)" -Type 1
    }


# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
    }

if(($PSDrive = Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    Write-CMTraceLog -Message "Failed to create PSDrive to ConfigMgr" -Type 3
    }
else
    {
    Write-CMTraceLog -Message "CMSite Provider: $($PSDrive.Name) | $($PSDrive.Root) " -Type 1
    }

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams

$CurrentLocation = Get-Location
if ($CurrentLocation -match $SiteCode)
    {
    Write-CMTraceLog -Message "Confirmed ConfigMgr Connection: $($CurrentLocation.ProviderPath)" -Type 1
    }
else
    {
    Write-CMTraceLog -Message "Current Path: $($CurrentLocation.ProviderPath)" -Type 1
    Write-CMTraceLog -Message "Failed to Connect to $SiteCode, exiting Script" -Type 3    
    Exit
    }
}

catch{
$CurrentLocation = Get-Location
Write-CMTraceLog -Message "Location: $($CurrentLocation.ProviderPath)" -Type 2
exit 2
}


Set-Location "c:\"
#App Names
$EdgeProd = "Edge"
$EdgePreProd = "Edge Pre-Prod"
$EdgeN1 = "Edge Go Back"
$EdgeBeta = "Edge BETA"

$EdgePreProdURL = "http://go.microsoft.com/fwlink/?LinkID=2093437"
$EdgeBETAURL = "https://go.microsoft.com/fwlink/?linkid=2093376"
$EdgeDEVURL = "https://go.microsoft.com/fwlink/?linkid=2093291"


if (Test-NetConnection http://proxy.recastsoftware.com -Port 8080) 
    {
    $UseProxy = $true
    Write-CMTraceLog -Message "Found Proxy Server, using for Downloads" -Type 1 -LogFile $LogFile
    Write-Output "Found Proxy Server, using for Downloads"
    $ProxyServer = "http://proxy.recastsoftware.com:8080"
    $BitsProxyList = @("192.168.1.15:8080, 192.168.1.115:8080, 192.168.1.215:8080")
    }
Else 
    {
    Write-CMTraceLog -Message "No Proxy Server Found, continuing without" -Type 1 -LogFile $LogFile
    Write-Output "No Proxy Server Found, continuing without"
    }

#Get CM Versions of Apps:
Write-CMTraceLog -Message "-- Edge Apps Summary Currently in ConfigMgr --"  -Type 1


#Get CM Pre-Prod Edge Info
Set-Location "$($SiteCode):\"
$EdgePreProdApp = Get-CMApplication -Fast -Name $EdgePreProd
$EdgePreProdAppDT = Get-CMDeploymentType -ApplicationName $EdgePreProd | Where-Object {$_.LocalizedDisplayName -match "X64"}
Set-Location "c:\"
[XML]$AppXML = $EdgePreProdAppDT.SDMPackageXML
$PreProdContentLocation = 	$AppXML.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location 
$PreProdContentLocation = $PreProdContentLocation.Substring(0,$PreProdContentLocation.Length-1)
$PreProdContentLocationParent = $PreProdContentLocation.Replace("$(($PreProdContentLocation.Split("\"))[$PreProdContentLocation.Split("\").Count –1])","")
Write-Host "Checking MSI File: $PreProdContentLocation\MicrosoftEdgeEnterpriseX64.msi" -ForegroundColor Gray
Write-CMTraceLog -Message " Checking MSI File: $PreProdContentLocation\MicrosoftEdgeEnterpriseX64.msi"  -Type 1
if (!(Test-Path "$PreProdContentLocation\MicrosoftEdgeEnterpriseX64.msi"))
    {
    Write-Host "Failed to access: $PreProdContentLocation\MicrosoftEdgeEnterpriseX64.msi" -ForegroundColor red
    Write-CMTraceLog -Message " Failed to Access: $PreProdContentLocation\MicrosoftEdgeEnterpriseX64.msi - EXITING" -Type 3
    Exit
    }
[Version]$PreProdFileVersion = [string](Get-MSIVersion -path "$PreProdContentLocation\MicrosoftEdgeEnterpriseX64.msi")
Write-Host "Current CM PreProd Version = $PreProdFileVersion" -ForegroundColor Gray
Write-CMTraceLog -Message " Current CM PreProd Version = $PreProdFileVersion"  -Type 1

#Get CM BETA Edge Info
Set-Location "$($SiteCode):\"
$EdgeBETAApp = Get-CMApplication -Fast -Name $EdgeBeta
$EdgeBETAAppDT = Get-CMDeploymentType -ApplicationName $EdgeBETA | Where-Object {$_.LocalizedDisplayName -match "X64"}
Set-Location "c:\"
[XML]$AppXML = $EdgeBETAAppDT.SDMPackageXML
$BETAContentLocation = 	$AppXML.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location 
$BETAContentLocation = $BETAContentLocation.Substring(0,$BETAContentLocation.Length-1)
$BETAContentLocationParent = $BETAContentLocation.Replace("$(($BETAContentLocation.Split("\"))[$BETAContentLocation.Split("\").Count –1])","")
Write-Host "Checking MSI File: $BETAContentLocation\MicrosoftEdgeEnterpriseX64.msi" -ForegroundColor Gray
Write-CMTraceLog -Message " Checking MSI File: $BETAContentLocation\MicrosoftEdgeEnterpriseX64.msi" -Type 1
if (!(Test-Path "$BETAContentLocation\MicrosoftEdgeEnterpriseX64.msi"))
    {
    Write-Host "Failed to access: $BETAContentLocation\MicrosoftEdgeEnterpriseX64.msi" -ForegroundColor red
    Write-CMTraceLog -Message " Failed to Access: $BETAContentLocation\MicrosoftEdgeEnterpriseX64.msi - EXITING" -Type 3
    EXIT
    }
[Version]$BETAFileVersion = [string](Get-MSIVersion -path "$BETAContentLocation\MicrosoftEdgeEnterpriseX64.msi")
Write-Host "Current CM BETA Version = $BETAFileVersion" -ForegroundColor Gray
Write-CMTraceLog -Message " Current CM BETA Version = $BETAFileVersion" -Type 1

#Get CM Prod Edge Info
Set-Location "$($SiteCode):\"
$EdgeProdApp = Get-CMApplication -Fast -Name $EdgeProd
$EdgeProdAppDT = Get-CMDeploymentType -ApplicationName $EdgeProd | Where-Object {$_.LocalizedDisplayName -match "X64"}
Set-Location "c:\"
[XML]$AppXML = $EdgeProdAppDT.SDMPackageXML
$ProdContentLocation = 	$AppXML.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location 
$ProdContentLocation = $ProdContentLocation.Substring(0,$ProdContentLocation.Length-1)
$ProdContentLocationParent = $ProdContentLocation.Replace("$(($ProdContentLocation.Split("\"))[$ProdContentLocation.Split("\").Count –1])","")
Write-Host "Checking MSI File: $ProdContentLocation\MicrosoftEdgeEnterpriseX64.msi" -ForegroundColor Gray
Write-CMTraceLog -Message " Checking MSI File: $ProdContentLocation\MicrosoftEdgeEnterpriseX64.msi" -Type 1
if (!(Test-Path "$ProdContentLocation\MicrosoftEdgeEnterpriseX64.msi"))
    {
    Write-Host "Failed to access: $ProdContentLocation\MicrosoftEdgeEnterpriseX64.msi" -ForegroundColor red
    Write-CMTraceLog -Message " Failed to Access: $ProdContentLocation\MicrosoftEdgeEnterpriseX64.msi - EXITING" -Type 3
    Exit
    }
[Version]$ProdFileVersion = [string](Get-MSIVersion -path "$ProdContentLocation\MicrosoftEdgeEnterpriseX64.msi")
Write-Host "Current CM Prod Version = $ProdFileVersion" -ForegroundColor Gray
Write-CMTraceLog -Message " Current CM Prod Version = $ProdFileVersion" -Type 1

#Get CM N-1 Edge Info
Set-Location "$($SiteCode):\"
$EdgeN1App = Get-CMApplication -Fast -Name $EdgeN1
$EdgeN1AppDT = Get-CMDeploymentType -ApplicationName $EdgeN1 | Where-Object {$_.LocalizedDisplayName -match "X64"}
Set-Location "c:\"
[XML]$AppXML = $EdgeN1AppDT.SDMPackageXML
$N1ContentLocation = 	$AppXML.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location 
$N1ContentLocation = $N1ContentLocation.Substring(0,$N1ContentLocation.Length-1)
$N1ContentLocationParent = $N1ContentLocation.Replace("$(($N1ContentLocation.Split("\"))[$N1ContentLocation.Split("\").Count –1])","")
Write-Host "Checking MSI File: $N1ContentLocation\MicrosoftEdgeEnterpriseX64.msi" -ForegroundColor Gray
Write-CMTraceLog -Message " Checking MSI File: $N1ContentLocation\MicrosoftEdgeEnterpriseX64.msi" -Type 1
if (!(Test-Path "$N1ContentLocation\MicrosoftEdgeEnterpriseX64.msi"))
    {
    Write-Host "Unable to access: $N1ContentLocation\MicrosoftEdgeEnterpriseX64.msi" -ForegroundColor red
    Write-CMTraceLog -Message " Failed to Access: $N1ContentLocation\MicrosoftEdgeEnterpriseX64.msi - EXITING" -Type 3
    Exit
    }
[Version]$N1FileVersion = [string](Get-MSIVersion -path "$N1ContentLocation\MicrosoftEdgeEnterpriseX64.msi")
Write-Host "Current CM N-1 Version = $N1FileVersion" -ForegroundColor Gray
Write-CMTraceLog -Message " Current CM Go Back Version = $N1FileVersion" -Type 1



#Download Installer Files:
Write-CMTraceLog -Message "-- Download & Compare Phase --" -Type 1

#Get latest Edge Installer File:
[system.net.webrequest]::DefaultWebProxy = new-object system.net.webproxy('http://proxy.recastsoftwarecom:8080')
Write-CMTraceLog -Message "-- Starting Download Process of Edge Stable --" -Type 1
$DownloadPreProdPath = "$env:TEMP\Edge"
$DownloadPreProdFile = "$DownloadPreProdPath\MicrosoftEdgeEnterpriseX64.msi"
if (test-path $DownloadPreProdPath){Remove-Item -Path $DownloadPreProdPath -Force -Recurse}
$NewFolder = New-Item -Path $DownloadPreProdPath -ItemType Directory
if (Test-Path -Path $DownloadPreProdPath)
    {
    Write-CMTraceLog -Message " Created Temp Storage for Download $DownloadPreProdPath" -Type 1
    }
else
    {
    Write-CMTraceLog -Message " Failed to Create Temp Storage: $DownloadPreProdPath" -Type 3
    }
Write-CMTraceLog -Message " Starting Download of Edge Stable ($($EdgePreProdURL))" -Type 1
Invoke-WebRequest -Uri $EdgePreProdURL -OutFile $DownloadPreProdFile -UseBasicParsing -Verbose -Proxy $ProxyServer
[Version]$DownloadPreProdFileVersion = [string](Get-MSIVersion -path $DownloadPreProdFile)
if ($DownloadPreProdFileVersion)
    {
    Write-Host " Current MS Web Version = $DownloadPreProdFileVersion" -ForegroundColor Gray
    Write-CMTraceLog -Message " Current STABLE Web Version = $DownloadPreProdFileVersion" -Type 1
    }
else
    {
    Write-CMTraceLog -Message " Unable to get MetaData from File: $DownloadPreProdFile" -Type 3
    exit
    }
    


#Get latest Edge BETA Installer File:
[system.net.webrequest]::DefaultWebProxy = new-object system.net.webproxy('http://proxy.recastsoftwarecom:8080')
Write-CMTraceLog -Message "-- Starting Download Process of Edge BETA --" -Type 1
$DownloadBETAPath = "$env:TEMP\EdgeBETA"
$DownloadBETAFile = "$DownloadBETAPath\MicrosoftEdgeEnterpriseX64.msi"
if (test-path $DownloadBETAPath){Remove-Item -Path $DownloadBETAPath -Force -Recurse}
$NewFolder = New-Item -Path $DownloadBETAPath -ItemType Directory
if (Test-Path -Path $DownloadBETAPath)
    {
    Write-CMTraceLog -Message " Created Temp Storage for Download $DownloadBETAPath" -Type 1
    }
else
    {
    Write-CMTraceLog -Message " Failed to Create Temp Storage: $DownloadBETAPath" -Type 3
    }

Write-CMTraceLog -Message " Starting Download of Edge BETA ($($EdgeBETAURL))" -Type 1
Invoke-WebRequest -Uri $EdgeBETAURL -OutFile $DownloadBETAFile -UseBasicParsing -Verbose -Proxy $ProxyServer
[Version]$DownloadBETAFileVersion = [string](Get-MSIVersion -path $DownloadBETAFile)
if ($DownloadBETAFileVersion)
    {
    Write-Host " Current BETA MS Web Version = $DownloadBETAFileVersion" -ForegroundColor Gray
    Write-CMTraceLog -Message " Current BETA MS Web Version = $DownloadBETAFileVersion" -Type 1
    }
else
    {
    Write-CMTraceLog -Message " Unable to get MetaData from File: $DownloadBETAFile" -Type 3
    exit
    }

if (($DownloadPreProdFileVersion -gt $PreProdFileVersion) -or ($DownloadBETAFileVersion -gt $BETAFileVersion))
    {
    Write-CMTraceLog -Message "-- Update ConfigMgr Source & Apps Phase --" -Type 1
    }


#Update PreProd App in CM
if ($DownloadPreProdFileVersion -gt $PreProdFileVersion)
    {
    Write-CMTraceLog -Message "Updating Pre-Prod: $PreProdFileVersion to match MS Web: $DownloadPreProdFileVersion" -Type 1
    Write-Host "Updating Pre-Prod: $PreProdFileVersion to match MS Web: $DownloadPreProdFileVersion" -ForegroundColor cyan
    #Create Backup and Replace PreProd w/ New Downloaded Version
    Set-Location "c:\"
    if (Test-Path "$($PreProdContentLocation)-Backup"){Remove-Item "$($PreProdContentLocation)-Backup" -Force -Recurse}
    Rename-Item -path $PreProdContentLocation -NewName "$($PreProdContentLocation)-Backup"
    $Folder = New-Item -Path $PreProdContentLocation -ItemType Directory -Force
    Copy-Item -Path $DownloadPreProdFile -Destination $PreProdContentLocation -Force
    Copy-Item -Path "$($PreProdContentLocation)-Backup\Install-Edge.ps1" -Destination $PreProdContentLocation -Force
    Write-Host " File Copy Complete" -ForegroundColor Green

    #Update CM PreProd App
    Set-Location -Path "$($SiteCode):"
    #Get DeploymentType Info
    $CMDeploymentType = get-CMDeploymentType -ApplicationName $EdgePreProd -DeploymentTypeName $EdgePreProdAppDT.LocalizedDisplayName
    [XML]$AppDTXML = $CMDeploymentType.SDMPackageXML
    [XML]$AppDTDXML = $AppDTXML.AppMgmtDigest.DeploymentType.Installer.DetectAction.args.Arg[1].'#text'    
    #Get Detection Information from Current DT
    $DetectionRegKey = $AppDTDXML.EnhancedDetectionMethod.Settings.SimpleSetting.RegistryDiscoverySource.key
    $DetectionRegKeyValueName = $AppDTDXML.EnhancedDetectionMethod.Settings.SimpleSetting.RegistryDiscoverySource.ValueName
    #Get the LogicalName of the Current DT Detection Method (so we can remove later)
    $OrigLogicalName = $AppDTDXML.EnhancedDetectionMethod.Rule.Expression.Operands.SettingReference.SettingLogicalName
    
    #Create Updated Detection Method
    $UpdatedRegistryDetection = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName $DetectionRegKey -PropertyType Version -ValueName $DetectionRegKeyValueName -ExpressionOperator GreaterEquals -Value -ExpectedValue $DownloadPreProdFileVersion
    Write-Host " Created Detection Method for Key: $DetectionRegKey Property: $DetectionRegKeyValueName Value: $DownloadPreProdFileVersion" -ForegroundColor Green
    Write-CMTraceLog -Message " Created Detection Method for Key: $DetectionRegKey Property: $DetectionRegKeyValueName Value: $DownloadPreProdFileVersion" -Type 1
    #Add Newly Created Detection Method
    Write-Host " Adding Detection Method to App" -ForegroundColor Green
    Write-CMTraceLog -Message " Adding Detection Method to App $EdgePreProd" -Type 1
    $SetDetection = Set-CMScriptDeploymentType -ApplicationName $EdgePreProd -DeploymentTypeName $EdgePreProdAppDT.LocalizedDisplayName -AddDetectionClause $UpdatedRegistryDetection
    #Remove Old Detection Method
    Write-Host " Removing old Detection Method from App" -ForegroundColor Green
    Write-CMTraceLog -Message " Removing old Detection Method from Ap" -Type 1
    $CMDeploymentType | Set-CMScriptDeploymentType -RemoveDetectionClause $OrigLogicalName

    #Update Software Version Field in App
    Write-Host " Updating Software Version on App from $PreProdFileVersion to $DownloadPreProdFileVersion" -ForegroundColor Green
    Write-CMTraceLog -Message " Updating Software Version on App from $PreProdFileVersion to $DownloadPreProdFileVersion" -Type 1
    Set-CMApplication -InputObject $EdgePreProdApp -SoftwareVersion $DownloadPreProdFileVersion
    #Update Distribution Points
    Write-Host " Updating Distribution Points" -ForegroundColor Green
    Write-CMTraceLog -Message " Updating Distribution Points" -Type 1
    Update-CMDistributionPoint -ApplicationName $EdgePreProd -DeploymentTypeName $EdgePreProdAppDT.LocalizedDisplayName
 }
else
    {
    Write-Host "No need to Update, PreProd: $PreProdFileVersion & MS Web: $DownloadPreProdFileVersion " -ForegroundColor Yellow
    Write-CMTraceLog -Message "No need to Update, PreProd: $PreProdFileVersion & MS Web: $DownloadPreProdFileVersion" -Type 1
    }

#Update BETA App in CM
if ($DownloadBETAFileVersion -gt $BETAFileVersion)
    {
    Write-Host "Updating BETA: $BETAFileVersion to match MS Web: $DownloadBETAFileVersion" -ForegroundColor cyan
    Write-CMTraceLog -Message "Updating BETA: $BETAFileVersion to match MS Web: $DownloadBETAFileVersion" -Type 1
    #Create Backup and Replace BETA w/ New Downloaded Version
    Set-Location "c:\"
    if (Test-Path "$($BETAContentLocation)-Backup"){Remove-Item "$($BETAContentLocation)-Backup" -Force -Recurse}
    Rename-Item -path $BETAContentLocation -NewName "$($BETAContentLocation)-Backup"
    $Folder = New-Item -Path $BETAContentLocation -ItemType Directory -Force
    Copy-Item -Path $DownloadBETAFile -Destination $BETAContentLocation -Force
    Copy-Item -Path "$($BETAContentLocation)-Backup\Install-Edge.ps1" -Destination $BETAContentLocation -Force
    Write-Host " File Copy Complete" -ForegroundColor Green

    #Update CM BETA App
    Set-Location -Path "$($SiteCode):"
    #Get DeploymentType Info
    $CMDeploymentType = get-CMDeploymentType -ApplicationName $EdgeBETA -DeploymentTypeName $EdgeBETAAppDT.LocalizedDisplayName
    [XML]$AppDTXML = $CMDeploymentType.SDMPackageXML
    [XML]$AppDTDXML = $AppDTXML.AppMgmtDigest.DeploymentType.Installer.DetectAction.args.Arg[1].'#text'    
    #Get Detection Information from Current DT
    $DetectionRegKey = $AppDTDXML.EnhancedDetectionMethod.Settings.SimpleSetting.RegistryDiscoverySource.key
    $DetectionRegKeyValueName = $AppDTDXML.EnhancedDetectionMethod.Settings.SimpleSetting.RegistryDiscoverySource.ValueName
    #Get the LogicalName of the Current DT Detection Method (so we can remove later)
    $OrigLogicalName = $AppDTDXML.EnhancedDetectionMethod.Rule.Expression.Operands.SettingReference.SettingLogicalName
    
    #Create Updated Detection Method
    $UpdatedRegistryDetection = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName $DetectionRegKey -PropertyType Version -ValueName $DetectionRegKeyValueName -ExpressionOperator GreaterEquals -Value -ExpectedValue $DownloadBETAFileVersion
    Write-Host " Created Detection Method for Key: $DetectionRegKey Property: $DetectionRegKeyValueName Value: $DownloadBETAFileVersion" -ForegroundColor Green
    Write-CMTraceLog -Message " Created Detection Method for Key: $DetectionRegKey Property: $DetectionRegKeyValueName Value: $DownloadBETAFileVersion" -Type 1
    #Add Newly Created Detection Method
    Write-Host " Adding Detection Method to App" -ForegroundColor Green
    Write-CMTraceLog -Message " Adding Detection Method to App to $EdgeBETA" -Type 1
    $SetDetection = Set-CMScriptDeploymentType -ApplicationName $EdgeBETA -DeploymentTypeName $EdgeBETAAppDT.LocalizedDisplayName -AddDetectionClause $UpdatedRegistryDetection
    #Remove Old Detection Method
    Write-Host " Removing old Detection Method from App" -ForegroundColor Green
    Write-CMTraceLog -Message " Removing old Detection Method from App" -Type 1
    $CMDeploymentType | Set-CMScriptDeploymentType -RemoveDetectionClause $OrigLogicalName

    #Update Software Version Field in App
    Write-Host " Updating Software Version on App from $BETAFileVersion to $DownloadBETAFileVersion" -ForegroundColor Green
    Write-CMTraceLog -Message " Updating Software Version on App from $BETAFileVersion to $DownloadBETAFileVersion" -Type 1
    Set-CMApplication -InputObject $EdgeBETAApp -SoftwareVersion $DownloadBETAFileVersion
    #Update Distribution Points
    Write-Host " Updating Distribution Points" -ForegroundColor Green
    Write-CMTraceLog -Message "Updating Distribution Points" -Type 1
    Update-CMDistributionPoint -ApplicationName $EdgeBETA -DeploymentTypeName $EdgeBETAAppDT.LocalizedDisplayName
 }
else
    {
    Write-Host "No need to Update, BETA: $BETAFileVersion & MS Web: $DownloadBETAFileVersion" -ForegroundColor Yellow
    Write-CMTraceLog -Message "No need to Update, BETA: $BETAFileVersion & MS Web: $DownloadBETAFileVersion" -Type 1
    }

Write-CMTraceLog -Message "-- Edge App Updater Script Complete --" -Type 1
