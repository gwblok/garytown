<# Gary Blok -GARYTOWN.COM - @gwblok
    This script will create a scheduled task that will run HPIA on a device.
    It will create the HPIA Script to the endpoint and create a scheduled task that run as SYSTEM
    HPIA will be loaded onto the machine when the scheduled task run the HPIA Script
    For more details, see the embedded script that runs HPIA


    USAGE
    Update the $trigger to when you want the scheduled task to trigger the HPIA Script.

#>

<#  Change Log
23.03.04 - Intial Script

#>

#Setup Folders
$ScriptStagingFolder = "$env:ProgramFiles\HP\HPIA"
[String]$TaskName = "HP Image Assistant Update Service"
try {
    [void][System.IO.Directory]::CreateDirectory($ScriptStagingFolder)
}
catch {throw}



#Create Scheduled task:
#Script to Trigger:
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ep bypass -file `"$ScriptStagingFolder\HPIAUpdateService.ps1`""
#When it runs: Wednesdays at 7:15 PM w/ 6 hour random delay
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Wednesday -At '7:15 PM' -RandomDelay "06:00"
#Run as System
$Prin = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
#Stop Task if runs more than 60 minutes
$Timeout = (New-TimeSpan -Minutes 60)
#Other Settings on the Task:
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -StartWhenAvailable -DontStopIfGoingOnBatteries -ExecutionTimeLimit $Timeout
#Create the Task
$task = New-ScheduledTask -Action $action -principal $Prin -Trigger $trigger -Settings $settings
#Register Task with Windows
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force -ErrorAction SilentlyContinue


$UpdaterScript = @'
<#  GARY BLOK | GARYTOWN.COM | @GWBLOK
Used for HPIA Update Service

Logging goes to ProgramData\HP\HPIAUpdateService

This script will 
 - grab the latest version of HPIA to use
 - Run HPIA based on the parameters you've listed
 - Log Process & Create Native HPIA Report files
#>



$HPIAStagingFolder = "$env:ProgramData\HP\HPIAUpdateService"
$HPIAStagingLogfFiles = "$HPIAStagingFolder\LogFiles"
$HPIAStagingReports = "$HPIAStagingFolder\Reports"
$HPIAStagingProgram = "$env:ProgramFiles\HPIA"
$HPIAUpdateServiceLog = "$HPIAStagingLogfFiles\HPIAUpdateService.log"
try {
    [void][System.IO.Directory]::CreateDirectory($HPIAStagingFolder)
    [void][System.IO.Directory]::CreateDirectory($HPIAStagingLogfFiles)
    [void][System.IO.Directory]::CreateDirectory($HPIAStagingReports)
    [void][System.IO.Directory]::CreateDirectory($HPIAStagingProgram)
}
catch {throw}



#region Functions
Function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
		    [Parameter(Mandatory=$false)]
		    $Component = "Script",
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		    [Parameter(Mandatory=$false)]
		    $LogFile = $HPIAUpdateServiceLog
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
	    $LogMessage.Replace("`0","") | Out-File -Append -Encoding UTF8 -FilePath $LogFile
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
        try { $Expand = start-process cmd.exe -ArgumentList "/c C:\Windows\System32\expand.exe -F:* $OutFile $TempWorkFolder\HPIAMsg.xml" -Wait}
        catch { Write-host "Nope, don't have that, soz."}
    }
    if (Test-Path -Path "$TempWorkFolder\HPIAMsg.xml"){
        [XML]$HPIAXML = Get-Content -Path "$TempWorkFolder\HPIAMsg.xml"
        $HPIADownloadURL = $HPIAXML.ImagePal.HPIALatest.SoftpaqURL
        $HPIAVersion = $HPIAXML.ImagePal.HPIALatest.Version
        $HPIAFileName = $HPIADownloadURL.Split('/')[-1]
        
    }
    else {
        $HPIAWebUrl = "https://ftp.hp.com/pub/caps-softpaq/cmit/HPIA.html" # Static web page of the HP Image Assistant
        try {$HTML = Invoke-WebRequest -Uri $HPIAWebUrl -ErrorAction Stop }
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
                $ExistingBitsJob = Get-BitsTransfer -Name "$HPIAFileName" -AllUsers -ErrorAction SilentlyContinue
                If ($ExistingBitsJob)
                {
                    Write-Output "An existing BITS tranfer was found. Cleaning it up."
                    Remove-BitsTransfer -BitsJob $ExistingBitsJob
                }
                $BitsJob = Start-BitsTransfer -Source $HPIADownloadURL -Destination $TempWorkFolder\$HPIAFileName -Asynchronous -DisplayName "$HPIAFileName" -Description "HPIA download" -RetryInterval 60 -ErrorAction Stop 
                do {
                    Start-Sleep -Seconds 5
                    $Progress = [Math]::Round((100 * ($BitsJob.BytesTransferred / $BitsJob.BytesTotal)),2)
                    Write-Output "Downloaded $Progress`%"
                } until ($BitsJob.JobState -in ("Transferred","Error"))
                If ($BitsJob.JobState -eq "Error")
                {
                    Write-Output "BITS tranfer failed: $($BitsJob.ErrorDescription)"
                    throw
                }
                Complete-BitsTransfer -BitsJob $BitsJob
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
            $Process = Start-Process -FilePath $TempWorkFolder\$HPIAFileName -WorkingDirectory $HPIAInstallPath -ArgumentList "/s /f .\ /e" -NoNewWindow -PassThru -Wait -ErrorAction Stop
            Start-Sleep -Seconds 5
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
Function Run-HPIA {

[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [ValidateSet("Analyze", "DownloadSoftPaqs")]
        $Operation = "Analyze",
        [Parameter(Mandatory=$false)]
        [ValidateSet("All", "BIOS", "Drivers", "Software", "Firmware", "Accessories","BIOS,Drivers")]
        $Category = "Drivers",
        [Parameter(Mandatory=$false)]
        [ValidateSet("All", "Critical", "Recommended", "Routine")]
        $Selection = "All",
        [Parameter(Mandatory=$false)]
        [ValidateSet("List", "Download", "Extract", "Install", "UpdateCVA")]
        $Action = "List",
        [Parameter(Mandatory=$false)]
        $LogFolder = "$env:systemdrive\ProgramData\HP\Logs",
        [Parameter(Mandatory=$false)]
        $ReportsFolder = "$env:systemdrive\ProgramData\HP\HPIA",
        [Parameter(Mandatory=$false)]
        $HPIAInstallPath = "$env:ProgramFiles\HP\HPIA\bin",
        [Parameter(Mandatory=$false)]
        $ReferenceFile
        )
    $DateTime = Get-Date -Format "yyyyMMdd-HHmmss"
    $ReportsFolder = "$ReportsFolder\$DateTime"
    $script:TempWorkFolder = "$env:temp\HPIA"
    try 
    {
        [void][System.IO.Directory]::CreateDirectory($LogFolder)
        [void][System.IO.Directory]::CreateDirectory($TempWorkFolder)
        [void][System.IO.Directory]::CreateDirectory($ReportsFolder)
        [void][System.IO.Directory]::CreateDirectory($HPIAInstallPath)
    }
    catch 
    {
        throw
    }
    
    Install-HPIA -HPIAInstallPath $HPIAInstallPath
    if ($Action -eq "List"){$LogComp = "Scanning"}
    else {$LogComp = "Updating"}
    try {

        if ($ReferenceFile){
            CMTraceLog -Message "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder /ReferenceFile:$ReferenceFile" -Component $LogComp
            Write-Host "Running HPIA With Args: /Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder /ReferenceFile:$ReferenceFile" -ForegroundColor Green
            $Process = Start-Process -FilePath $HPIAInstallPath\HPImageAssistant.exe -WorkingDirectory $TempWorkFolder -ArgumentList "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder /ReferenceFile:$ReferenceFile" -NoNewWindow -PassThru -Wait -ErrorAction Stop
        }
        else {
            CMTraceLog -Message "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder" -Component $LogComp
            Write-Host "Running HPIA With Args: /Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder" -ForegroundColor Green
            $Process = Start-Process -FilePath $HPIAInstallPath\HPImageAssistant.exe -WorkingDirectory $TempWorkFolder -ArgumentList "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder" -NoNewWindow -PassThru -Wait -ErrorAction Stop
        }

        
        If ($Process.ExitCode -eq 0)
        {
            CMTraceLog -Message "HPIA Analysis complete" -Component $LogComp
            Write-Host "HPIA Analysis complete" -ForegroundColor Green
        }
        elseif ($Process.ExitCode -eq 256) 
        {
            CMTraceLog -Message "Exit $($Process.ExitCode) - The analysis returned no recommendation." -Component "Update" -Type 2
            Write-Host "Exit $($Process.ExitCode) - The analysis returned no recommendation." -ForegroundColor Green
            CMTraceLog -Message "########################################" -Component "Complete"
            #Exit 0
        }
         elseif ($Process.ExitCode -eq 257) 
        {
            CMTraceLog -Message "Exit $($Process.ExitCode) - There were no recommendations selected for the analysis." -Component "Update" -Type 2
            Write-Host "Exit $($Process.ExitCode) - There were no recommendations selected for the analysis." -ForegroundColor Green
            CMTraceLog -Message "########################################" -Component "Complete"
            #Exit 0
        }
        elseif ($Process.ExitCode -eq 3010) 
        {
            CMTraceLog -Message "Exit $($Process.ExitCode) - HPIA Complete, requires Restart" -Component "Update" -Type 2
            Write-Host "Exit $($Process.ExitCode) - HPIA Complete, requires Restart" -ForegroundColor Yellow
            $script:RebootRequired = $true
        }
        elseif ($Process.ExitCode -eq 3020) 
        {
            CMTraceLog -Message "Exit $($Process.ExitCode) - Install failed — One or more SoftPaq installations failed." -Component "Update" -Type 2
            Write-Host "Exit $($Process.ExitCode) - Install failed — One or more SoftPaq installations failed." -ForegroundColor Yellow
        }
        elseif ($Process.ExitCode -eq 4096) 
        {
            CMTraceLog -Message "Exit $($Process.ExitCode) - This platform is not supported!" -Component "Update" -Type 2
            Write-Host "Exit $($Process.ExitCode) - This platform is not supported!" -ForegroundColor Yellow
            #throw
        }
        elseif ($Process.ExitCode -eq 16386) 
        {
            CMTraceLog -Message "Exit $($Process.ExitCode) - This platform is not supported!" -Component "Update" -Type 2
            Write-Output "Exit $($Process.ExitCode) - The reference file is not supported on platforms running the Windows 10 operating system!"
            #throw
        }
        elseif ($Process.ExitCode -eq 16385) 
        {
            CMTraceLog -Message "Exit $($Process.ExitCode) - The reference file is invalid" -Component "Update" -Type 2
            Write-Output "Exit $($Process.ExitCode) - The reference file is invalid"
            #throw
        }
        elseif ($Process.ExitCode -eq 16387) 
        {
            CMTraceLog -Message "Exit $($Process.ExitCode) - The reference file given explicitly on the command line does not match the target System ID or OS version." -Component "Update" -Type 2
            Write-Output "Exit $($Process.ExitCode) - The reference file given explicitly on the command line does not match the target System ID or OS version." 
            #throw
        }
        elseif ($Process.ExitCode -eq 16388) 
        {
            CMTraceLog -Message "Exit $($Process.ExitCode) - HPIA encountered an error processing the reference file provided on the command line." -Component "Update" -Type 2
            Write-Output "Exit $($Process.ExitCode) - HPIA encountered an error processing the reference file provided on the command line." 
            #throw
        }
        elseif ($Process.ExitCode -eq 16389) 
        {
            CMTraceLog -Message "Exit $($Process.ExitCode) - HPIA could not find the reference file specified in the command line reference file parameter" -Component "Update" -Type 2
            Write-Output "Exit $($Process.ExitCode) - HPIA could not find the reference file specified in the command line reference file parameter" 
            #throw
        }
        Else
        {
            CMTraceLog -Message "Process exited with code $($Process.ExitCode). Expecting 0." -Component "Update" -Type 3
            Write-Host "Process exited with code $($Process.ExitCode). Expecting 0." -ForegroundColor Yellow
            #throw
        }
    }
    catch {
        CMTraceLog -Message "Failed to start the HPImageAssistant.exe: $($_.Exception.Message)" -Component "Update" -Type 3
        Write-Host "Failed to start the HPImageAssistant.exe: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }


}

#endregion

# SCRIPT START:
#Start Transcription Log
$Date = Get-Date -Format yyyyMMddhhmmss
#Start-Transcript -Path "$HPIAStagingLogfFiles\HPIA-$($Date).log"



CMTraceLog -Message "########################################" -Component "Preparation"
CMTraceLog -Message "## Starting HPIA Process  ##" -Component "Preparation"

# Disable IE First Run Wizard - This prevents an error running Invoke-WebRequest when IE has not yet been run in the current context
if (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main"){
    $IEMainKey = Get-Item "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main"
    if (!($IEMainKey.GetValue('DisableFirstRunCustomize') -eq 1)){
        CMTraceLog -Message "Disabling IE first run wizard" -Component "Preparation"
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft" -Name "Internet Explorer" -Force | Out-Null
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer" -Name "Main" -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -PropertyType DWORD -Value 1 -Force | Out-Null
    }
}
else {
    CMTraceLog -Message "Disabling IE first run wizard" -Component "Preparation"
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft" -Name "Internet Explorer" -Force | Out-Null
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer" -Name "Main" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -PropertyType DWORD -Value 1 -Force | Out-Null
}



Run-HPIA -Operation Analyze -Category 'Drivers' -Selection All -Action Install -LogFolder $HPIAStagingLogfFiles -ReportsFolder $HPIAStagingReports -HPIAInstallPath $HPIAStagingProgram
#Stop-Transcript

'@


$UpdaterScript | Out-File -FilePath "$ScriptStagingFolder\HPIAUpdateService.ps1" -Force
