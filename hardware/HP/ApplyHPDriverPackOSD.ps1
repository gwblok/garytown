<# Gary Blok @GWBLOK

Much of script borrowed form SMSAgent's Blog: https://smsagent.blog/2021/03/30/deploying-hp-bios-updates-a-real-world-example/
Parts used are for downloading and extracting HPIA - Thank you Trevor!

Leveraging this with custom driver package:
/Offlinemode:<path to offline repository>

Assumes you created the driver pack using with this script: https://github.com/gwblok/garytown/blob/master/hardware/HP/HP_UpdateDriverPacks_Online_Offline.ps1

The script needs to know where your Package of the Offline Repo is located
$DriverPath (Location to CM Package with your Custom Driver pack)
$HPIAPath (Location to the Package you have HPIA in)
$Offlinefolder = "$DriverPath\Online" (This is the actual folder in your CMPackage with your HPIA Offline Repo sync'd)


!!!!! If it can't find your Offline Repo, falls back to using the internet !!!!
#>


# HPIA User Guide: https://ftp.ext.hp.com/pub/caps-softpaq/cmit/whitepapers/HPIAUserGuide.pdf


# Params
$HPIAWebUrl = "https://ftp.hp.com/pub/caps-softpaq/cmit/HPIA.html" # Static web page of the HP Image Assistant
$script:FolderPath = "HPIA" # the subfolder to put logs into in the storage container
$ProgressPreference = 'SilentlyContinue' # to speed up web requests

$LogFolder = "$env:ProgramData\RecastSoftwareIT\Logs"
try{[void][System.IO.Directory]::CreateDirectory($LogFolder)}
catch{throw}

# HPIA Arguments
$Operation = "Analyze" #/Operation:[Analyze|DownloadSoftPaqs] 
$Category = "All" #/Category:[All,BIOS,Drivers,Software,Firmware,Accessories]
$Selection = "All" #/Selection:[All,Critical,Recommended,Routine]
$Action = "Install" #/Action:[List|Download|Extract|Install|UpdateCVA]

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

    $LogFile = "$env:ProgramData\RecastSoftwareIT\Logs\HPIA.log"
    
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





try {
    $tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment


    }
catch{
    Write-Output "!NOT Running in Task Sequence!"

    }

if ($tsenv)
    {
    Write-Output "Running in Task Sequence"
    $DriverPath = $($tsenv.Value('DRIVERS01'))
    $HPIAPath = $($tsenv.Value('HPIA01'))
    $script:WorkingDirectory = $HPIAPath
    $Offlinefolder = "$DriverPath\Online"
    $ReportFolder = "$env:TEMP\HPReport"
    if ((Test-Path $WorkingDirectory) -and (Test-Path $Offlinefolder)){
        Write-Output "HPIA Path = $HPIAPath"
        Write-Output "HPIA Repo Path = $Offlinefolder"
        $HPIAArgList = "/Offlinemode:$Offlinefolder /Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /ReportFolder:$ReportFolder"
        Write-Log -Message "#######################" -Component "Preparation"
        Write-Log -Message "## Starting HPIA update run in TS Offline Repo Mode ##" -Component "Preparation"
        Write-Log -Message "## HPIA Path = $HPIAPath ##" -Component "Preparation"
        Write-Log -Message "## HPIA Repo Path = $Offlinefolder ##" -Component "Preparation"
        Write-Log -Message "#######################" -Component "Preparation"
        }
    else {
        Write-Output "Failed to find HPIA or Repo Folders"
        Write-Output "HPIA Path = $HPIAPath"
        Write-Output "HPIA Repo Path = $Offlinefolder"
        Write-Output "Will attempt to Download and apply updates from HP.COM"
        $HPIAArgList = "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /ReportFolder:$ReportFolder"
        Write-Log -Message "#######################" -Component "Preparation"
        Write-Log -Message "## Starting HPIA update run in Online Mode ##" -Component "Preparation"
        Write-Log -Message "## HPIA Path = $HPIAPath ##" -Component "Preparation"
        Write-Log -Message "## HPIA Repo Path = $Offlinefolder ##" -Component "Preparation"
        Write-Log -Message "#######################" -Component "Preparation"
        }
    }
else {
    Write-Output "Will attempt to Download and apply updates from HP.COM"
    $RootFolder = $env:ProgramData
    $ParentFolderName = "RecastSoftwareIT"
    $ChildFolderName = "HPIA"
    $script:WorkingDirectory = "$RootFolder\$ParentFolderName\$ChildFolderName\"
    $ReportFolder = "$WorkingDirectory\Report" 
    $HPIAArgList = "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /ReportFolder:$ReportFolder"
    Write-Log -Message "#######################" -Component "Preparation"
    Write-Log -Message "## Starting HPIA update run in Online ##" -Component "Preparation"
    Write-Log -Message "#######################" -Component "Preparation"
    }

if (!($tsenv)){
    ################################
    ## Create Directory Structure ##
    ################################
    try{[void][System.IO.Directory]::CreateDirectory($WorkingDirectory)}
    catch{throw}

    #################################
    ## Disable IE First Run Wizard ##
    #################################
    # This prevents an error running Invoke-WebRequest when IE has not yet been run in the current context
    Write-Log -Message "Disabling IE first run wizard" -Component "Preparation"
    $null = New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft" -Name "Internet Explorer" -Force
    $null = New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer" -Name "Main" -Force
    $null = New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -PropertyType DWORD -Value 1 -Force


    ##########################
    ## Get latest HPIA Info ##
    ##########################
    Write-Log -Message "Finding info for latest version of HP Image Assistant (HPIA)" -Component "DownloadHPIA"
    try
    {
        $HTML = Invoke-WebRequest -Uri $HPIAWebUrl -ErrorAction Stop
    }
    catch 
    {
        Write-Log -Message "Failed to download the HPIA web page. $($_.Exception.Message)" -Component "DownloadHPIA" -LogLevel 3
        Upload-LogFilesToAzure
        throw
    }
    $HPIASoftPaqNumber = ($HTML.Links | Where {$_.href -match "hp-hpia-"}).outerText
    $HPIADownloadURL = ($HTML.Links | Where {$_.href -match "hp-hpia-"}).href
    $HPIAFileName = $HPIADownloadURL.Split('/')[-1]
    Write-Log -Message "SoftPaq number is $HPIASoftPaqNumber" -Component "DownloadHPIA"
    Write-Log -Message "Download URL is $HPIADownloadURL" -Component "DownloadHPIA"


    ###################
    ## Download HPIA ##
    ###################
    Write-Log -Message "Downloading the HPIA" -Component "DownloadHPIA"
    try 
    {
        $ExistingBitsJob = Get-BitsTransfer -Name "$HPIAFileName" -AllUsers -ErrorAction SilentlyContinue
        If ($ExistingBitsJob)
        {
            Write-Log -Message "An existing BITS tranfer was found. Cleaning it up." -Component "DownloadHPIA" -LogLevel 2
            Remove-BitsTransfer -BitsJob $ExistingBitsJob
        }
        $BitsJob = Start-BitsTransfer -Source $HPIADownloadURL -Destination $WorkingDirectory\$HPIAFileName -Asynchronous -DisplayName "$HPIAFileName" -Description "HPIA download" -RetryInterval 60 -ErrorAction Stop 
        do {
            Start-Sleep -Seconds 5
            $Progress = [Math]::Round((100 * ($BitsJob.BytesTransferred / $BitsJob.BytesTotal)),2)
            Write-Log -Message "Downloaded $Progress`%" -Component "DownloadHPIA"
        } until ($BitsJob.JobState -in ("Transferred","Error"))
        If ($BitsJob.JobState -eq "Error")
        {
            Write-Log -Message "BITS tranfer failed: $($BitsJob.ErrorDescription)" -Component "DownloadHPIA" -LogLevel 3
            Upload-LogFilesToAzure
            throw
        }
        Write-Log -Message "Download is finished" -Component "DownloadHPIA"
        Complete-BitsTransfer -BitsJob $BitsJob
        Write-Log -Message "BITS transfer is complete $WorkingDirectory\$HPIAFileName" -Component "DownloadHPIA"
    }
    catch 
    {
        Write-Log -Message "Failed to start a BITS transfer for the HPIA: $($_.Exception.Message)" -Component "DownloadHPIA" -LogLevel 3
        Upload-LogFilesToAzure
        throw
    }


    ##################
    ## Extract HPIA ##
    ##################
    Write-Log -Message "Extracting the HPIA" -Component "Analyze"
    try 
    {
        $Process = Start-Process -FilePath $WorkingDirectory\$HPIAFileName -WorkingDirectory $WorkingDirectory -ArgumentList "/s /f .\HPIA\ /e" -NoNewWindow -PassThru -Wait -ErrorAction Stop
        Start-Sleep -Seconds 5
        If (Test-Path $WorkingDirectory\HPIA\HPImageAssistant.exe)
        {
            Write-Log -Message "Extraction complete" -Component "Analyze"
        }
        Else  
        {
            Write-Log -Message "HPImageAssistant not found!" -Component "Analyze" -LogLevel 3
            Upload-LogFilesToAzure
            throw
        }
    }
    catch 
    {
        Write-Log -Message "Failed to extract the HPIA: $($_.Exception.Message)" -Component "Analyze" -LogLevel 3
        Upload-LogFilesToAzure
        throw
    }

    }

##############################################
## Install Updates from Drivers WIM via HPIA ##
##############################################
Write-Log -Message "Installing Updates for HP" -Component "Analyze"
try 
{
    $Process = Start-Process -FilePath $WorkingDirectory\HPIA\HPImageAssistant.exe -WorkingDirectory $WorkingDirectory -ArgumentList $HPIAArgList -NoNewWindow -PassThru -Wait -ErrorAction Stop
    If ($Process.ExitCode -eq 0)
    {
        Write-Log -Message "Analysis complete" -Component "Analyze"
    }
    elseif ($Process.ExitCode -eq 256) 
    {
        Write-Log -Message "The analysis returned no recommendation. No BIOS update is available at this time" -Component "Analyze" -LogLevel 2
        Exit 0
    }
    elseif ($Process.ExitCode -eq 4096) 
    {
        Write-Log -Message "This platform is not supported!" -Component "Analyze" -LogLevel 2
        throw
    }
    elseif ($Process.ExitCode -eq 3010) 
    {
        Write-Log -Message "This system requires a restart!" -Component "Analyze" -LogLevel 2
    }
    Else
    {
        Write-Log -Message "Process exited with code $($Process.ExitCode). Expecting 0." -Component "Analyze" -LogLevel 3
        throw
    }
}
catch 
{
    Write-Log -Message "Failed to start the HPImageAssistant.exe: $($_.Exception.Message)" -Component "Analyze" -LogLevel 3
    throw
}

exit $Process.ExitCode
