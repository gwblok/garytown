<#  Addon Enhancement for HP Devices using MSEndpointMgr's Enhanced Inventory
https://msendpointmgr.com/2022/01/17/securing-intune-enhanced-inventory-with-azure-function/

I ASSUME you already set that up and have it working, if not, this will not work.  Once you have that setup, you can implement this ADD ON.


.Requirements
Internet Connection

.ChangeLog
      23.10.09.01 - Intial Release
#>

###############################
## HP DRIVER UPDATE ANALYZER ##
###############################


$CollectHPIARecommendationsInventory = $true 
$HPIARecommendationsLogName = "HPIARecommendationsInventory"

################
## Parameters ##
################
# WorkspaceID of the Log Analytics workspace
$script:WorkspaceID = "<YourWorkspaceID>" 
# Primary Key of the Log Analytics workspace
$script:PrimaryKey = "<YourPrimaryKey>" 
# The name of the table to create/use in the Log Analytics workspace
$script:LogName = "HPDriverUpdates" 
#registry Key 
$ParentRegKeyName = "IntelligentUpdate" 
# The name of the parent folder and registry key that we'll work with, eg your company or IT dept name
$ParentFoldersName = "HP\IntelligentUpdateService"
#  The name of the child folder and registry key that we'll work with
$ChildFolderName = "IUSAnalysisReporting" 
# The minimum number of hours in between each run of this script
[int]$MinimumFrequency = 5
# Static web page of the HP Image Assistant
$HPIAWebUrl = "https://ftp.hp.com/pub/caps-softpaq/cmit/HPIA.html" 
# Set the security protocol. Must include Tls1.2.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12,[Net.SecurityProtocolType]::Tls13
# to speed up web requests
$ProgressPreference = 'SilentlyContinue' 

$HPIAInstallParentPath = $env:ProgramFiles

#[String[]]$DesiredCategories = @("Drivers","BIOS","Firmware","Software")
[String[]]$DesiredCategories = @("Drivers","BIOS")

###############
## Functions ##
###############
#region 
# Function write to a log file in ccmtrace format
Function script:Write-Log {

    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
		
        [Parameter()]
        [ValidateSet(1, 2, 3)] # 1-Info, 2-Warning, 3-Error
        [int]$LogLevel = 1,

        [Parameter(Mandatory = $true)]
        [string]$Component,

        [Parameter(Mandatory = $false)]
        [object]$Exception
    )
   
    If ($Exception)
    {
        [String]$Message = "$Message" + "$Exception"
    }

    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
    $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), $Component, $LogLevel
    $Line = $Line -f $LineFormat
    
    # Write to log
    Add-Content -Value $Line -Path $LogFile -ErrorAction SilentlyContinue

}

# Function to do a log rollover
Function Rollover-Log {
   
    # Create the log file
    If (!(Test-Path $LogFile))
	{
	    $null = New-Item $LogFile -Type File
	}
    
    # Log rollover
    If ([math]::Round((Get-Item $LogFile).Length / 1KB) -gt 2000)
    {
        Write-Log "Log has reached 2MB. Rolling over..."
        Rename-Item -Path $LogFile -NewName "HP_Driver_Analysis-$(Get-Date -Format "yyyyMMdd-hhmmss").log"
        $null = New-Item $LogFile -Type File
    } 

    # Remove oldest log
    If ((Get-ChildItem $ParentDirectory -Name "HP_Driver_Analysis*.log").Count -eq 3)
    {
        (Get-ChildItem -Path $ParentDirectory -Filter "HP_Driver_Analysis*.log" | 
            select FullName,LastWriteTime | 
            Sort LastWriteTime | 
            Select -First 1).FullName | Remove-Item  
    }
		
}

# Create the function to create the authorization signature
# ref https://docs.microsoft.com/en-us/azure/azure-monitor/logs/data-collector-api
Function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
    return $authorization
}

# Create the function to create and post the request
# ref https://docs.microsoft.com/en-us/azure/azure-monitor/logs/data-collector-api
Function Post-LogAnalyticsData($customerId, $sharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $TimeStampField = ""
    $signature = Build-Signature `
        -customerId $customerId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }

    try {
        $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    }
    catch {
        $response = $_#.Exception.Response
    }
    
    return $response
}

Function Get-HPIALatestVersion{
    $script:TempWorkFolder = "$env:windir\Temp\HPIA"
    $ProgressPreference = 'SilentlyContinue' # to speed up web requests
    $HPIACABUrl = "https://hpia.hpcloud.hp.com/HPIAMsg.cab"
    $HPIACABUrlFallback = "https://ftp.hp.com/pub/caps-softpaq/cmit/imagepal/HPIAMsg.cab"
    try {
        [void][System.IO.Directory]::CreateDirectory($TempWorkFolder)
    }
    catch {throw}
    $OutFile = "$TempWorkFolder\HPIAMsg.cab"
    
    try {Invoke-WebRequest -Uri $HPIACABUrl -UseBasicParsing -OutFile $OutFile}
    catch {}
    if (!(test-path $OutFile)){
        try {Invoke-WebRequest -Uri $HPIACABUrlFallback -UseBasicParsing -OutFile $OutFile}
        catch {}
    }
    if (test-path $OutFile){
        if(test-path "$env:windir\System32\expand.exe"){
            try { cmd.exe /c "C:\Windows\System32\expand.exe -F:* $OutFile $TempWorkFolder\HPIAMsg.xml" | Out-Null}
            catch {}
        }
        if (Test-Path -Path "$TempWorkFolder\HPIAMsg.xml"){
            [XML]$HPIAXML = Get-Content -Path "$TempWorkFolder\HPIAMsg.xml"
            $HPIADownloadURL = $HPIAXML.ImagePal.HPIALatest.SoftpaqURL
            $HPIAVersion = $HPIAXML.ImagePal.HPIALatest.Version
            $HPIAFileName = $HPIADownloadURL.Split('/')[-1]
        }
    }

    else { #Falling back to Static Web Page Scrapping if Cab File wasn't available... highly unlikely
        $HPIAWebUrl = "https://ftp.hp.com/pub/caps-softpaq/cmit/HPIA.html" # Static web page of the HP Image Assistant
        try {$HTML = Invoke-WebRequest –Uri $HPIAWebUrl –ErrorAction Stop }
        catch {Write-Output "Failed to download the HPIA web page. $($_.Exception.Message)" ;throw}
        $HPIASoftPaqNumber = ($HTML.Links | Where {$_.href -match "hp-hpia-"}).outerText
        $HPIADownloadURL = ($HTML.Links | Where {$_.href -match "hp-hpia-"}).href
        $HPIAFileName = $HPIADownloadURL.Split('/')[-1]
        $HPIAVersion = ($HPIAFileName.Split("-") | Select-Object -Last 1).replace(".exe","")
    }
    $Return = @(
    @{HPIAVersion = "$($HPIAVersion)"; HPIADownloadURL = $HPIADownloadURL ; HPIAFileName = $HPIAFileName}
    )
    return $Return
} 
Function Install-HPIA{
[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        $HPIAInstallPath = "$env:ProgramFiles\HP\HPIA\bin"
        )
    $script:TempWorkFolder = "$env:windir\Temp\HPIA"
    $ProgressPreference = 'SilentlyContinue' # to speed up web requests
    $HPIACABUrl = "https://hpia.hpcloud.hp.com/HPIAMsg.cab"
    
    try {
        [void][System.IO.Directory]::CreateDirectory($HPIAInstallPath)
        [void][System.IO.Directory]::CreateDirectory($TempWorkFolder)
    }
    catch {throw}
    $OutFile = "$TempWorkFolder\HPIAMsg.cab"
    Invoke-WebRequest -Uri $HPIACABUrl -UseBasicParsing -OutFile $OutFile
    if(test-path "$env:windir\System32\expand.exe"){
        try { cmd.exe /c "C:\Windows\System32\expand.exe -F:* $OutFile $TempWorkFolder\HPIAMsg.xml"}
        catch { Write-host "Nope, don't have that."}
    }
    if (Test-Path -Path "$TempWorkFolder\HPIAMsg.xml"){
        [XML]$HPIAXML = Get-Content -Path "$TempWorkFolder\HPIAMsg.xml"
        $HPIADownloadURL = $HPIAXML.ImagePal.HPIALatest.SoftpaqURL
        $HPIAVersion = $HPIAXML.ImagePal.HPIALatest.Version
        $HPIAFileName = $HPIADownloadURL.Split('/')[-1]
        
    }
    else {
        $HPIAWebUrl = "https://ftp.hp.com/pub/caps-softpaq/cmit/HPIA.html" # Static web page of the HP Image Assistant
        try {$HTML = Invoke-WebRequest –Uri $HPIAWebUrl –ErrorAction Stop }
        catch {Write-Output "Failed to download the HPIA web page. $($_.Exception.Message)" ;throw}
        $HPIASoftPaqNumber = ($HTML.Links | Where {$_.href -match "hp-hpia-"}).outerText
        $HPIADownloadURL = ($HTML.Links | Where {$_.href -match "hp-hpia-"}).href
        $HPIAFileName = $HPIADownloadURL.Split('/')[-1]
        $HPIAVersion = ($HPIAFileName.Split("-") | Select-Object -Last 1).replace(".exe","")
    }

    Write-Output "HPIA Download URL is $HPIADownloadURL | Verison: $HPIAVersion"
    If (Test-Path $HPIAInstallPath\HPImageAssistant.exe){
        $HPIA = get-item -Path $HPIAInstallPath\HPImageAssistant.exe
        $HPIAExtractedVersion = $HPIA.VersionInfo.FileVersion
        if ($HPIAExtractedVersion -match $HPIAVersion){
            Write-Host "HPIA $HPIAVersion already on Machine, Skipping Download" -ForegroundColor Green
            $HPIAIsCurrent = $true
        }
        else{$HPIAIsCurrent = $false}
    }
    else{$HPIAIsCurrent = $false}
    #Download HPIA
    if ($HPIAIsCurrent -eq $false){
        Write-Host "Downloading HPIA" -ForegroundColor Green
        if (!(Test-Path -Path "$TempWorkFolder\$HPIAFileName")){
            try 
            {
                $ExistingBitsJob = Get-BitsTransfer –Name "$HPIAFileName" –AllUsers –ErrorAction SilentlyContinue
                If ($ExistingBitsJob)
                {
                    Write-Output "An existing BITS tranfer was found. Cleaning it up."
                    Remove-BitsTransfer –BitsJob $ExistingBitsJob
                }
                $BitsJob = Start-BitsTransfer –Source $HPIADownloadURL –Destination $TempWorkFolder\$HPIAFileName –Asynchronous –DisplayName "$HPIAFileName" –Description "HPIA download" –RetryInterval 60 –ErrorAction Stop 
                do {
                    Start-Sleep –Seconds 5
                    $Progress = [Math]::Round((100 * ($BitsJob.BytesTransferred / $BitsJob.BytesTotal)),2)
                    Write-Output "Downloaded $Progress`%"
                } until ($BitsJob.JobState -in ("Transferred","Error"))
                If ($BitsJob.JobState -eq "Error")
                {
                    Write-Output "BITS tranfer failed: $($BitsJob.ErrorDescription)"
                    throw
                }
                Complete-BitsTransfer –BitsJob $BitsJob
                Write-Host "BITS transfer is complete" -ForegroundColor Green
            }
            catch 
            {
                Write-Host "Failed to start a BITS transfer for the HPIA: $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
        }
        else
            {
            Write-Host "$HPIAFileName already downloaded, skipping step" -ForegroundColor Green
            }

        #Extract HPIA
        Write-Host "Extracting HPIA" -ForegroundColor Green
        try 
        {
            $Process = Start-Process –FilePath $TempWorkFolder\$HPIAFileName –WorkingDirectory $HPIAInstallPath –ArgumentList "/s /f .\ /e" –NoNewWindow –PassThru –Wait –ErrorAction Stop
            Start-Sleep –Seconds 5
            If (Test-Path $HPIAInstallPath\HPImageAssistant.exe)
            {
                Write-Host "Extraction complete" -ForegroundColor Green
            }
            Else  
            {
                Write-Host "HPImageAssistant not found!" -ForegroundColor Red
                Stop-Transcript
                throw
            }
        }
        catch 
        {
            Write-Host "Failed to extract the HPIA: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }
}

#endregion




#################
## Preparation ##
#################
#region
# Custom class and list
class Recommendation {
    [string]$TargetComponent
    [string]$TargetVersion
    [string]$ReferenceVersion
    [string]$Comments
    [string]$SoftPaqId
    [string]$Name
    [string]$Type
    [string]$Model
    [string]$ManagedDeviceID
    [string]$AzureADDeviceID
    [string]$ManagedDeviceName
    [string]$ComputerName
    [string]$InventoryDate
}
$Recommendations = [System.Collections.Generic.List[Recommendation]]::new()



# Safeguard to prevent execution on non-HP workstations
$Manufacturer = Get-CimInstance -ClassName Win32_ComputerSystem -Property Manufacturer -ErrorAction SilentlyContinue | Select -ExpandProperty Manufacturer
If ($Manufacturer -notin ('HP','Hewlett-Packard'))
{
    Write-Output "Not an HP workstation"
    $CollectHPIARecommendationsInventory = $false
    Return
}
#endregion


##########################
## Create Registry Keys ##
##########################
#region
$RegRoot = "HKLM:\SOFTWARE\HP"
$FullRegPath = "$RegRoot\$ParentRegKeyName\$ChildFolderName"
If (!(Test-Path $RegRoot\$ParentRegKeyName))
{
    $null = New-Item -Path $RegRoot -Name $ParentFolderName -Force
}
If (!(Test-Path $FullRegPath))
{
    $null = New-Item -Path $RegRoot\$ParentRegKeyName -Name $ChildFolderName -Force
}
#endregion


#############################
## Check the run frequency ##
#############################
#region
# This is to ensure that the script does not attempt to run more frequently than the defined schedule in the MinimumFrequency value
$LatestRunStartTime = Get-ItemProperty -Path $FullRegPath -Name LatestRunStartTime -ErrorAction SilentlyContinue | Select -ExpandProperty LatestRunStartTime | Get-Date -ErrorAction SilentlyContinue
if ($null -ne $LatestRunStartTime)
{
    If (((Get-Date) - $LatestRunStartTime).TotalHours -le $MinimumFrequency)
    {
        Write-Output "Minimum threshold for script re-run has not yet been met"
        $CollectHPIARecommendationsInventory = $false
        Return
    }
}
Set-ItemProperty -Path $FullRegPath -Name LatestRunStartTime -Value (Get-Date -Format "s") -Force
#endregion


################################################################################
## Check if an inventory is already running to avoid simultaneous executions  ##
################################################################################
#region
# This is necessary due to the fact that proactive remediations can run in multiple contexts
$ExecutionStatus = Get-ItemProperty -Path $FullRegPath -Name ExecutionStatus -ErrorAction SilentlyContinue | Select -ExpandProperty ExecutionStatus | Get-Date -ErrorAction SilentlyContinue
If ($ExecutionStatus -eq "Running")
{
    Write-Output "Another execution is currently running"
    Return
}
else 
{
    Set-ItemProperty -Path $FullRegPath -Name ExecutionStatus -Value "Running" -Force
}
#endregion


################################
## Create Directory Structure ##
################################
#region
$RootFolder = $env:ProgramData

$ChildFolderName2 = Get-Date -Format "yyyy-MMM-dd_HH.mm.ss"
$script:ParentDirectory = "$RootFolder\$ParentFoldersName\$ChildFolderName"
$script:WorkingDirectory = "$RootFolder\$ParentFoldersName\$ChildFolderName\$ChildFolderName2"
try 
{
    [void][System.IO.Directory]::CreateDirectory($WorkingDirectory)
}
catch 
{
    throw $_.Exception.Message
}
$script:LogFile = "$ParentDirectory\HP_Driver_Analysis.log"
Rollover-Log
Write-Log -Message "#########################" -Component "Preparation"
Write-Log -Message "## Starting HP Driver Analysis ##" -Component "Preparation"
Write-Log -Message "#########################" -Component "Preparation"
#endregion


#################################
## Disable IE First Run Wizard ##
#################################
#region
# This prevents an error running Invoke-WebRequest when IE has not yet been run in the current context
Write-Log -Message "Disabling IE first run wizard" -Component "Preparation"
$null = New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft" -Name "Internet Explorer" -Force
$null = New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer" -Name "Main" -Force
$null = New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -PropertyType DWORD -Value 1 -Force
#endregion


##########################
## Get latest HPIA Info ##
##########################
#region

Write-Log -Message "Finding info for latest version of HP Image Assistant (HPIA)" -Component "DownloadHPIA"
try
{
    $LatestHPIA = Get-HPIALatestVersion
}
catch 
{
    Write-Log -Message "Failed to download the HPIA web page. $($_.Exception.Message)" -Component "DownloadHPIA" -LogLevel 3
    Set-ItemProperty -Path $FullRegPath -Name ExecutionStatus -Value "Failed" -Force
    Remove-Item -Path $WorkingDirectory -Recurse -Force -ErrorAction SilentlyContinue
    throw "Failed to download the HPIA web page. $($_.Exception.Message)"
}
$HPIASoftPaqNumber = $LatestHPIA.HPIAVersion
$HPIADownloadURL = $LatestHPIA.HPIADownloadURL
$HPIAFileName = $LatestHPIA.HPIAFileName
Write-Log -Message "HPIA SoftPaq number is $HPIASoftPaqNumber" -Component "DownloadHPIA"
Write-Log -Message "HPIA download URL is $HPIADownloadURL" -Component "DownloadHPIA"
#endregion


##########################################################
## Check if the current HPIA version is already present ##
##########################################################
#region
$File = Get-Item -Path $HPIAInstallParentPath\HPIA\HPImageAssistant.exe -ErrorAction SilentlyContinue
If ($null -eq $File)
{
    Write-Log -Message "HP Image Assistant not found locally. Proceed with download" -Component "DownloadHPIA"
    $DownloadHPIA = $true
}
else 
{
    $FileVersion = $HPIAFileName.Split('-')[-1].TrimEnd('.exe')
    $ProductVersion = $File.VersionInfo.ProductVersion
    If ($ProductVersion -match $FileVersion)
    {
        Write-Log -Message "HP Image Assistant was found locally at the current version. No need to download" -Component "DownloadHPIA"
    }
    else 
    {
        Write-Log -Message "HP Image Assistant was found locally but not at the current version. Proceed to download" -Component "DownloadHPIA"
        $DownloadHPIA = $true
    }
}
#endregion



#############################
## Download & Extract HPIA ##
#############################

if ($DownloadHPIA -eq $true){
    Write-Log -Message "Downloading & Extracting the HPIA" -Component "DownloadHPIA"
    Write-Log -Message "Extracting to $HPIAInstallParentPath\HPIA" -Component "Analyze"

    Install-HPIA -HPIAInstallPath "$HPIAInstallParentPath\HPIA"
}

#########################################
## Analyze available updates with HPIA ##
#########################################
#region
Write-Log -Message "Analyzing system for available updates" -Component "Analyze"

if (Test-Path -Path "$RootFolder\$ParentFoldersName\RefFiles"){
    $RefFile = Get-ChildItem -Path "$RootFolder\$ParentFoldersName\RefFiles" -Filter *.xml
    $ReferenceFile = $RefFile.FullName
     Write-Log -Message "Found HPIA Reference File: $ReferenceFile" -Component "Analyze"
}
try {
    [String]$Category = $($DesiredCategories -join ",").ToString()
    Write-Log -Message "Analysis Started, Categories: $Category" -Component "Analyze"

    if ($RefFile){
        $Process = Start-Process -FilePath $HPIAInstallParentPath\HPIA\HPImageAssistant.exe -WorkingDirectory $HPIAInstallParentPath -ArgumentList "/Operation:Analyze /Category:$Category /Selection:All /Action:List /Silent /ReferenceFile:$ReferenceFile /ReportFolder:$WorkingDirectory\Report" -NoNewWindow -PassThru -Wait -ErrorAction Stop
    }
    else {
        $Process = Start-Process -FilePath $HPIAInstallParentPath\HPIA\HPImageAssistant.exe -WorkingDirectory $HPIAInstallParentPath -ArgumentList "/Operation:Analyze /Category:$Category /Selection:All /Action:List /Silent /ReportFolder:$WorkingDirectory\Report" -NoNewWindow -PassThru -Wait -ErrorAction Stop
    }
    If ($Process.ExitCode -eq 0)
    {
        Write-Log -Message "Analysis complete" -Component "Analyze"
    }
    elseif ($Process.ExitCode -eq 256) 
    {
        Write-Log -Message "The analysis returned no recommendation. No updates are available at this time" -Component "Analyze" -LogLevel 2
        Set-ItemProperty -Path $FullRegPath -Name ExecutionStatus -Value "Complete" -Force
        Remove-Item -Path $WorkingDirectory -Recurse -Force -ErrorAction SilentlyContinue
        Return
    }
    elseif ($Process.ExitCode -eq 4096) 
    {
        Write-Log -Message "This platform is not supported!" -Component "Analyze" -LogLevel 2
        Set-ItemProperty -Path $FullRegPath -Name ExecutionStatus -Value "Not supported" -Force
        Remove-Item -Path $WorkingDirectory -Recurse -Force -ErrorAction SilentlyContinue
        Return
    }
    elseif ($Process.ExitCode -eq 16386) 
    {
        Write-Log -Message "OS version not supported!" -Component "Analyze" -LogLevel 2
        Set-ItemProperty -Path $FullRegPath -Name ExecutionStatus -Value "Not supported" -Force
        Remove-Item -Path $WorkingDirectory -Recurse -Force -ErrorAction SilentlyContinue
        Return
    }
    Else
    {
        Switch ($Process.ExitCode)
        {   
            #1 {$ErrorDescription = "The /VerifySoftPaq command returns that the SoftPaq binary verification could not be found."}
            #2 {$ErrorDescription = "The /VerifySoftPaq command returns that an exception occurred."}
            #3 {$ErrorDescription = "The /VerifySoftPaq command returns that the SoftPaq binary verification was signed by an invalid company."}
            #4 {$ErrorDescription = "The /VerifySoftPaq command returns that the SoftPaq binary verification authenticode failed."}
            #5 {$ErrorDescription = "The /VerifySoftPaq command returns that the SoftPaq binary verification certificate chain failed."}
            #256 {$ErrorDescription = "The analysis returned no recommendations."}
            257 {$ErrorDescription = "There were no recommendations selected for the analysis."}
            #3010 {$ErrorDescription = "Install Reboot Required — SoftPaq installations are successful, and at least one requires a reboot."}
            #3020 {$ErrorDescription = "Install failed — One or more SoftPaq installations failed."}
            4096 {$ErrorDescription = "The platform is not supported."}
            4097 {$ErrorDescription = "The parameters are invalid."}
            4098 {$ErrorDescription = "There is no Internet connection."}
            #4099 {$ErrorDescription = "Invalid SoftPaq number in SPList file."}
            4100 {$ErrorDescription = "SoftPaq My Product List is empty, so no data was processed."}
            4101 {$ErrorDescription = "The parameter is no longer supported."}
            8192 {$ErrorDescription = "The operation failed"}
            8193 {$ErrorDescription = "The image capture failed."}
            8194 {$ErrorDescription = "The output folder was not created."}
            8195 {$ErrorDescription = "The download folder was not created."}
            8196 {$ErrorDescription = "The supported platforms list download failed."}
            8197 {$ErrorDescription = "The KB download failed."}
            8198 {$ErrorDescription = "The extract folder was not created."}
            #8199 {$ErrorDescription = "The SoftPaq download failed."}
            #8200 {$ErrorDescription = "The SoftPaq extraction failed."}
            12288 {$ErrorDescription = "The target file failed to open."}
            12289 {$ErrorDescription = "The target file is invalid."}
            16384 {$ErrorDescription = "The reference file failed to open."}
            16385 {$ErrorDescription = "The reference file is invalid."}
            #16386 {$ErrorDescription = "The reference file is not supported on platforms running the Windows 10 operating system."}
            20480 {$ErrorDescription = "The operating system migration cannot be performed because the operating system architecture is not supported."}
            default {$ErrorDescription = "Unknown error"}
        }
        Write-Log -Message "Process exited with code $($Process.ExitCode) ($ErrorDescription). Expecting 0." -Component "Analyze" -LogLevel 3
        Set-ItemProperty -Path $FullRegPath -Name ExecutionStatus -Value "Failed" -Force
        Remove-Item -Path $WorkingDirectory -Recurse -Force -ErrorAction SilentlyContinue
        throw "Process exited with code $($Process.ExitCode) ($ErrorDescription). Expecting 0."
    }
}
catch 
{
    Write-Log -Message "Failed to start the HPImageAssistant.exe: $($_.Exception.Message)" -Component "Analyze" -LogLevel 3
    Set-ItemProperty -Path $FullRegPath -Name ExecutionStatus -Value "Failed" -Force
    Remove-Item -Path $WorkingDirectory -Recurse -Force -ErrorAction SilentlyContinue
    throw "Failed to start the HPImageAssistant.exe: $($_.Exception.Message)"
}
#endregion


###########################
## Review the XML report ##
###########################
#region
Write-Log -Message "Reading xml report" -Component "Analyze"
try 
{
    $XMLFile = Get-ChildItem -Path "$WorkingDirectory\Report" -Recurse -Include *.xml -ErrorAction Stop
    If ($XMLFile)
    {
        try 
        {
            [xml]$XML = Get-Content -Path $XMLFile.FullName -ErrorAction Stop
            [array]$SoftwareRecommendations = $xml.HPIA.Recommendations.Software.Recommendation
            [array]$DriverRecommendations = $xml.HPIA.Recommendations.Drivers.Recommendation
            [array]$BIOSRecommendations = $xml.HPIA.Recommendations.BIOS.Recommendation
            [array]$FirmwareRecommendations = $xml.HPIA.Recommendations.Firmware.Recommendation
            
            Set-ItemProperty -Path $FullRegPath -Name SoftwareRecommendations -Value $SoftwareRecommendations.Count -Force
            If (($SoftwareRecommendations.Count -ge 1) -and (($Category -match "Software") -or ($Category -match "All")))
            {
                $SoftwareReqs = $true
                Write-Log -Message "Found $($SoftwareRecommendations.Count) software recommendations" -Component "Analyze"
                foreach ($Item in $SoftwareRecommendations)
                {
                    $Recommendation = [Recommendation]::new()
                    $Recommendation.TargetComponent = $item.TargetComponent
                    $Recommendation.TargetVersion = $item.TargetVersion
                    $Recommendation.ReferenceVersion = $item.ReferenceVersion
                    $Recommendation.Comments = $item.Comments
                    $Recommendation.SoftPaqId = $item.Solution.Softpaq.Id
                    $Recommendation.Name = $item.Solution.Softpaq.Name
                    $Recommendation.Type = "Software"
                    $Recommendations.Add($Recommendation)
                    Write-Log -Message ">> $($Recommendation.SoftPaqId): $($Recommendation.Name) ($($Recommendation.ReferenceVersion))" -Component "Analyze"
                }
            }
            else {
                $SoftwareReqs = $false
            }
            
            Set-ItemProperty -Path $FullRegPath -Name DriverRecommendations -Value $DriverRecommendations.Count -Force
            If (($DriverRecommendations.Count -ge 1) -and (($Category -match "Driver") -or ($Category -match "All")))
            {
                $DriverReqs = $true
                Write-Log -Message "Found $($DriverRecommendations.Count) driver recommendations" -Component "Analyze"
                foreach ($Item in $DriverRecommendations)
                {
                    $Recommendation = [Recommendation]::new()
                    $Recommendation.TargetComponent = $item.TargetComponent
                    $Recommendation.TargetVersion = $item.TargetVersion
                    $Recommendation.ReferenceVersion = $item.ReferenceVersion
                    $Recommendation.Comments = $item.Comments
                    $Recommendation.SoftPaqId = $item.Solution.Softpaq.Id
                    $Recommendation.Name = $item.Solution.Softpaq.Name
                    $Recommendation.Type = "Driver"
                    $Recommendations.Add($Recommendation)
                    Write-Log -Message ">> $($Recommendation.SoftPaqId): $($Recommendation.Name) ($($Recommendation.ReferenceVersion))" -Component "Analyze"
                }
            }
            else {
                $DriverReqs = $False
            }

            Set-ItemProperty -Path $FullRegPath -Name BIOSRecommendations -Value $BIOSRecommendations.Count -Force
            If (($BIOSRecommendations.Count -ge 1) -and (($Category -match "BIOS") -or ($Category -match "All")))
            {
                $BIOSReqs = $true
                Write-Log -Message "Found $($BIOSRecommendations.Count) BIOS recommendations" -Component "Analyze"
                foreach ($Item in $BIOSRecommendations)
                
                {
                    $Recommendation = [Recommendation]::new()
                    $Recommendation.TargetComponent = $item.TargetComponent
                    $Recommendation.TargetVersion = $item.TargetVersion
                    $Recommendation.ReferenceVersion = $item.ReferenceVersion
                    $Recommendation.Comments = $item.Comments
                    $Recommendation.SoftPaqId = $item.Solution.Softpaq.Id
                    $Recommendation.Name = $item.Solution.Softpaq.Name
                    $Recommendation.Type = "BIOS"
                    $Recommendations.Add($Recommendation)
                    Write-Log -Message ">> $($Recommendation.SoftPaqId): $($Recommendation.Name) ($($Recommendation.ReferenceVersion))" -Component "Analyze"
                }
            }
            else {
                $BIOSReqs = $false
            }
            
            Set-ItemProperty -Path $FullRegPath -Name FirmwareRecommendations -Value $FirmwareRecommendations.Count -Force
            If (($FirmwareRecommendations.Count -ge 1) -and (($Category -match "Firmware") -or ($Category -match "All")))
            {
                $FirmwareReqs = $true
                Write-Log -Message "Found $($FirmwareRecommendations.Count) firmware recommendations" -Component "Analyze"
                foreach ($Item in $FirmwareRecommendations)
                
                {
                    $Recommendation = [Recommendation]::new()
                    $Recommendation.TargetComponent = $item.TargetComponent
                    $Recommendation.TargetVersion = $item.TargetVersion
                    $Recommendation.ReferenceVersion = $item.ReferenceVersion
                    $Recommendation.Comments = $item.Comments
                    $Recommendation.SoftPaqId = $item.Solution.Softpaq.Id
                    $Recommendation.Name = $item.Solution.Softpaq.Name
                    $Recommendation.Type = "Firmware"
                    $Recommendations.Add($Recommendation)
                    Write-Log -Message ">> $($Recommendation.SoftPaqId): $($Recommendation.Name) ($($Recommendation.ReferenceVersion))" -Component "Analyze"
                }
            }
            else {
                $FirmwareReqs = $false
            }
            If ($FirmwareReqs -eq $false -and $DriverReqs -eq $false -and $BIOSReqs -eq $false -and $SoftwareReqs -eq $false)
            {
                Write-Log -Message "No recommendations found at this time" -Component "Analyze"
                Set-ItemProperty -Path $FullRegPath -Name Compliance -Value $true -Force
                Write-Log -Message "This driver analysis is complete. Have a nice day!" -Component "Completion"
                Set-ItemProperty -Path $FullRegPath -Name ExecutionStatus -Value "Complete" -Force
                Remove-Item -Path $WorkingDirectory -Recurse -Force -ErrorAction SilentlyContinue
                Return
            }
            else {
                Set-ItemProperty -Path $FullRegPath -Name Compliance -Value $false -Force
            }
        }
        catch 
        {
            Write-Log -Message "Failed to parse the XML file: $($_.Exception.Message)" -Component "Analyze" -LogLevel 3
            Set-ItemProperty -Path $FullRegPath -Name ExecutionStatus -Value "Failed" -Force
            Remove-Item -Path $WorkingDirectory -Recurse -Force -ErrorAction SilentlyContinue
            throw "Failed to parse the XML file: $($_.Exception.Message)" 
        }
    }
    Else  
    {
        Write-Log -Message "Failed to find an XML report." -Component "Analyze" -LogLevel 3
        Set-ItemProperty -Path $FullRegPath -Name ExecutionStatus -Value "Failed" -Force
        Remove-Item -Path $WorkingDirectory -Recurse -Force -ErrorAction SilentlyContinue
        throw "Failed to find an XML report."
    }
}
catch 
{
    Write-Log -Message "Failed to find an XML report: $($_.Exception.Message)" -Component "Analyze" -LogLevel 3
    Set-ItemProperty -Path $FullRegPath -Name ExecutionStatus -Value "Failed" -Force
    Remove-Item -Path $WorkingDirectory -Recurse -Force -ErrorAction SilentlyContinue
    throw "Failed to find an XML report: $($_.Exception.Message)"
}
#endregion



#########################################
## Build Inventory Object for LA       ##
#########################################
#region

$InventoryDate = Get-Date ([DateTime]::UtcNow) -Format "s"
foreach ($item in $Recommendations)
{
    $item.ManagedDeviceName = $ManagedDeviceName
    $item.ManagedDeviceID = $ManagedDeviceID
    $item.AzureADDeviceID = $AzureADDeviceID
    $item.ComputerName = $ComputerName
    $item.InventoryDate = $InventoryDate
    $item.Model = $ComputerModel
}


if ($CollectHPIARecommendationsInventory) {
	$LogPayLoad | Add-Member -NotePropertyMembers @{$HPIARecommendationsLogName = $Recommendations}
}

#endregion


###############
## Finish up ##
###############
#region
Write-Log -Message "This driver analysis is complete. Have a nice day!" -Component "Completion"
Set-ItemProperty -Path $FullRegPath -Name ExecutionStatus -Value "Complete" -Force
Remove-Item -Path $WorkingDirectory -Recurse -Force -ErrorAction SilentlyContinue
#endregion
