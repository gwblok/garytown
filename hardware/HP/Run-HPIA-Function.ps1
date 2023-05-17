Function Run-HPIA {

<#
Update HP Drivers via HPIA - Gary Blok - @gwblok
Several Code Snips taken from: https://smsagent.blog/2021/03/30/deploying-hp-bios-updates-a-real-world-example/

HPIA User Guide: https://ftp.ext.hp.com/pub/caps-softpaq/cmit/whitepapers/HPIAUserGuide.pdf

Notes about Severity:
Routine – For new hardware support and feature enhancements.
Recommended – For minor bug fixes. HP recommends this SoftPaq be installed.
Critical – For major bug fixes, specific problem resolutions, to enable new OS or Service Pack. Essentially the SoftPaq is required to receive support from HP.

Chamges: 
22.06.09 - Added Debug Parameter (DebugLog) for HPIA.  Log goes to the Report Folder.
22.10.11 - Added Reboot Parameter
22.10.12 - Added Logic to suspend Bitlocker if BIOS Updated
22.10.13 - Added additional Exit Codes
#>

[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [ValidateSet("Analyze", "DownloadSoftPaqs")]
        $Operation = "Analyze",
        [Parameter(Mandatory=$false)]
        [ValidateSet("All", "BIOS", "Drivers", "Software", "Firmware", "Accessories")]
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
        [Switch]$DebugLog = $false,
        [Switch]$RebootIfNeeded = $false
        )

    # Params
    $HPIAWebUrl = "https://ftp.hp.com/pub/caps-softpaq/cmit/HPIA.html" # Static web page of the HP Image Assistant
    $script:FolderPath = "HP_Updates" # the subfolder to put logs into in the storage container
    $ProgressPreference = 'SilentlyContinue' # to speed up web requests

    ################################
    ## Create Directory Structure ##
    ################################
    #$RootFolder = $env:systemdrive
    #$ParentFolderName = "OSDCloud"
    #$ChildFolderName = "HP_Updates"
    $DateTime = Get-Date –Format "yyyyMMdd-HHmmss"
    $ReportsFolder = "$ReportsFolder\$DateTime"
    $HPIALogFile = "$LogFolder\Run-HPIA.log"
    #$script:WorkingDirectory = "$RootFolder\$ParentFolderName\$ChildFolderName\$ChildFolderName2"
    $script:TempWorkFolder = "$env:temp\HPIA"
    try 
    {
        [void][System.IO.Directory]::CreateDirectory($LogFolder)
        [void][System.IO.Directory]::CreateDirectory($TempWorkFolder)
        [void][System.IO.Directory]::CreateDirectory($ReportsFolder)
    }
    catch 
    {
        throw
    }


    # Function write to a log file in ccmtrace format
    function CMTraceLog {
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
		    $LogFile = $HPIALogFile
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
    CMTraceLog –Message "#######################" –Component "Preparation"
    CMTraceLog –Message "## Starting HPIA  ##" –Component "Preparation"
    CMTraceLog –Message "#######################" –Component "Preparation"
    Write-Host "Starting HPIA to Update HP Drivers" -ForegroundColor Magenta
    #################################
    ## Disable IE First Run Wizard ##
    #################################
    # This prevents an error running Invoke-WebRequest when IE has not yet been run in the current context
    CMTraceLog –Message "Disabling IE first run wizard" –Component "Preparation"
    $null = New-Item –Path "HKLM:\SOFTWARE\Policies\Microsoft" –Name "Internet Explorer" –Force
    $null = New-Item –Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer" –Name "Main" –Force
    $null = New-ItemProperty –Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" –Name "DisableFirstRunCustomize" –PropertyType DWORD –Value 1 –Force
    ##########################
    ## Get latest HPIA Info ##
    ##########################
    CMTraceLog –Message "Finding info for latest version of HP Image Assistant (HPIA)" –Component "Download"
    try
    {
        $HTML = Invoke-WebRequest –Uri $HPIAWebUrl –ErrorAction Stop
    }
    catch 
    {
        CMTraceLog –Message "Failed to download the HPIA web page. $($_.Exception.Message)" –Component "Download" -Type 3
        throw
    }
    $HPIASoftPaqNumber = ($HTML.Links | Where {$_.href -match "hp-hpia-"}).outerText
    $HPIADownloadURL = ($HTML.Links | Where {$_.href -match "hp-hpia-"}).href
    $HPIAFileName = $HPIADownloadURL.Split('/')[-1]
    CMTraceLog –Message "SoftPaq number is $HPIASoftPaqNumber" –Component "Download"
    CMTraceLog –Message "Download URL is $HPIADownloadURL" –Component "Download"
    Write-Host "Download URL is $HPIADownloadURL" -ForegroundColor Green
    ###################
    ## Download HPIA ##
    ###################
    CMTraceLog –Message "Downloading HPIA" –Component "DownloadHPIA"
    Write-Host "Downloading HPIA" -ForegroundColor Green
    if (!(Test-Path -Path "$TempWorkFolder\$HPIAFileName")){
        try 
        {
            $ExistingBitsJob = Get-BitsTransfer –Name "$HPIAFileName" –AllUsers –ErrorAction SilentlyContinue
            If ($ExistingBitsJob)
            {
                CMTraceLog –Message "An existing BITS tranfer was found. Cleaning it up." –Component "Download" –Type 2
                Remove-BitsTransfer –BitsJob $ExistingBitsJob
            }
            $BitsJob = Start-BitsTransfer –Source $HPIADownloadURL –Destination $TempWorkFolder\$HPIAFileName –Asynchronous –DisplayName "$HPIAFileName" –Description "HPIA download" –RetryInterval 60 –ErrorAction Stop 
            do {
                Start-Sleep –Seconds 5
                $Progress = [Math]::Round((100 * ($BitsJob.BytesTransferred / $BitsJob.BytesTotal)),2)
                CMTraceLog –Message "Downloaded $Progress`%" –Component "Download"
            } until ($BitsJob.JobState -in ("Transferred","Error"))
            If ($BitsJob.JobState -eq "Error")
            {
                CMTraceLog –Message "BITS tranfer failed: $($BitsJob.ErrorDescription)" –Component "Download" –Type 3
                throw
            }
            CMTraceLog –Message "Download is finished" –Component "Download"
            Complete-BitsTransfer –BitsJob $BitsJob
            CMTraceLog –Message "BITS transfer is complete" –Component "Download"
            Write-Host "BITS transfer is complete" -ForegroundColor Green
        }
        catch 
        {
            CMTraceLog –Message "Failed to start a BITS transfer for the HPIA: $($_.Exception.Message)" –Component "Download" –Type 3
            Write-Host "Failed to start a BITS transfer for the HPIA: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }
    else
        {
        CMTraceLog –Message "$HPIAFileName already downloaded, skipping step" –Component "Download"
        Write-Host "$HPIAFileName already downloaded, skipping step" -ForegroundColor Green
        }
    ##################
    ## Extract HPIA ##
    ##################
    CMTraceLog –Message "Extracting HPIA" –Component "Extract"
    Write-Host "Extracting HPIA" -ForegroundColor Green
    try 
    {
        $Process = Start-Process –FilePath $TempWorkFolder\$HPIAFileName –WorkingDirectory $TempWorkFolder –ArgumentList "/s /f .\HPIA\ /e" –NoNewWindow –PassThru –Wait –ErrorAction Stop
        Start-Sleep –Seconds 5
        If (Test-Path $TempWorkFolder\HPIA\HPImageAssistant.exe)
        {
            CMTraceLog –Message "Extraction complete" –Component "Extract"
        }
        Else  
        {
            CMTraceLog –Message "HPImageAssistant not found!" –Component "Extract" –Type 3
            Write-Host "HPImageAssistant not found!" -ForegroundColor Red
            throw
        }
    }
    catch 
    {
        CMTraceLog –Message "Failed to extract the HPIA: $($_.Exception.Message)" –Component "Extract" –Type 3
        Write-Host "Failed to extract the HPIA: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
    ##############################################
    ## Install Updates with HPIA ##
    ##############################################
    try 
    {
        if ($DebugLog -eq $false){
            CMTraceLog –Message "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /ReportFolder:$ReportsFolder" –Component "Update"
            Write-Host "Running HPIA With Args: /Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /ReportFolder:$ReportsFolder" -ForegroundColor Green
            $Process = Start-Process –FilePath $TempWorkFolder\HPIA\HPImageAssistant.exe –WorkingDirectory $TempWorkFolder –ArgumentList "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /ReportFolder:$ReportsFolder" –NoNewWindow –PassThru –Wait –ErrorAction Stop
        }
        else {
            CMTraceLog –Message "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder" –Component "Update"
            Write-Host "Running HPIA With Args: /Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder" -ForegroundColor Green
            $Process = Start-Process –FilePath $TempWorkFolder\HPIA\HPImageAssistant.exe –WorkingDirectory $TempWorkFolder –ArgumentList "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder" –NoNewWindow –PassThru –Wait –ErrorAction Stop
        }
        
        If ($Process.ExitCode -eq 0)
        {
            CMTraceLog –Message "Analysis complete" –Component "Update"
            Write-Host "Analysis complete" -ForegroundColor Green
        }
        elseif ($Process.ExitCode -eq 256) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - The analysis returned no recommendation." –Component "Update" –Type 2
            Write-Host "Exit $($Process.ExitCode) - The analysis returned no recommendation." -ForegroundColor Green
            Exit 0
        }
         elseif ($Process.ExitCode -eq 257) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - There were no recommendations selected for the analysis." –Component "Update" –Type 2
            Write-Host "Exit $($Process.ExitCode) - There were no recommendations selected for the analysis." -ForegroundColor Green
            Exit 0
        }
        elseif ($Process.ExitCode -eq 3010) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - HPIA Complete, requires Restart" –Component "Update" –Type 2
            Write-Host "Exit $($Process.ExitCode) - HPIA Complete, requires Restart" -ForegroundColor Yellow
            $script:RebootRequired = $true
        }
        elseif ($Process.ExitCode -eq 3020) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - Install failed — One or more SoftPaq installations failed." –Component "Update" –Type 2
            Write-Host "Exit $($Process.ExitCode) - Install failed — One or more SoftPaq installations failed." -ForegroundColor Yellow
        }
        elseif ($Process.ExitCode -eq 4096) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - This platform is not supported!" –Component "Update" –Type 2
            Write-Host "Exit $($Process.ExitCode) - This platform is not supported!" -ForegroundColor Yellow
            throw
        }
        elseif ($Process.ExitCode -eq 16386) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - This platform is not supported!" –Component "Update" –Type 2
            Write-Output "Exit $($Process.ExitCode) - The reference file is not supported on platforms running the Windows 10 operating system!" 
            throw
        }
        elseif ($Process.ExitCode -eq 16385) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - The reference file is invalid" –Component "Update" –Type 2
            Write-Output "Exit $($Process.ExitCode) - The reference file is invalid" 
            throw
        }
        elseif ($Process.ExitCode -eq 16387) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - The reference file given explicitly on the command line does not match the target System ID or OS version." –Component "Update" –Type 2
            Write-Output "Exit $($Process.ExitCode) - The reference file given explicitly on the command line does not match the target System ID or OS version." 
            throw
        }
        elseif ($Process.ExitCode -eq 16388) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - HPIA encountered an error processing the reference file provided on the command line." –Component "Update" –Type 2
            Write-Output "Exit $($Process.ExitCode) - HPIA encountered an error processing the reference file provided on the command line." 
            throw
        }
        elseif ($Process.ExitCode -eq 16389) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - HPIA could not find the reference file specified in the command line reference file parameter" –Component "Update" –Type 2
            Write-Output "Exit $($Process.ExitCode) - HPIA could not find the reference file specified in the command line reference file parameter" 
            throw
        }
        Else
        {
            CMTraceLog –Message "Process exited with code $($Process.ExitCode). Expecting 0." –Component "Update" –Type 3
            Write-Host "Process exited with code $($Process.ExitCode). Expecting 0." -ForegroundColor Yellow
            throw
        }
    }
    catch 
    {
        CMTraceLog –Message "Failed to start the HPImageAssistant.exe: $($_.Exception.Message)" –Component "Update" –Type 3
        Write-Host "Failed to start the HPImageAssistant.exe: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }

    ##############################################
    ## Gathering Addtional Information ##
    ##############################################
    CMTraceLog –Message "Reading xml report" –Component "Report"    
    try 
    {
        $XMLFile = Get-ChildItem –Path $ReportsFolder –Recurse –Include *.xml –ErrorAction Stop
        If ($XMLFile)
        {
            CMTraceLog –Message "Report located at $($XMLFile.FullName)" –Component "Report"
            try 
            {
                [xml]$XML = Get-Content –Path $XMLFile.FullName –ErrorAction Stop
                
                if ($Category -eq "BIOS" -or $Category -eq "All"){
                    CMTraceLog –Message "Checking BIOS Recommendations" –Component "Report"
                    Write-Host "Checking BIOS Recommendations" -ForegroundColor Green 
                    $null = $Recommendation
                    $Recommendation = $xml.HPIA.Recommendations.BIOS.Recommendation
                    If ($Recommendation)
                    {
                        $ItemName = $Recommendation.TargetComponent
                        $CurrentBIOSVersion = $Recommendation.TargetVersion
                        $ReferenceBIOSVersion = $Recommendation.ReferenceVersion
                        $DownloadURL = "https://" + $Recommendation.Solution.Softpaq.Url
                        $SoftpaqFileName = $DownloadURL.Split('/')[-1]
                        CMTraceLog –Message "Component: $ItemName" –Component "Report"
                        Write-Host "Component: $ItemName" -ForegroundColor Gray                           
                        CMTraceLog –Message " Current version is $CurrentBIOSVersion" –Component "Report"
                        Write-Host " Current version is $CurrentBIOSVersion" -ForegroundColor Gray
                        CMTraceLog –Message " Recommended version is $ReferenceBIOSVersion" –Component "Report"
                        Write-Host " Recommended version is $ReferenceBIOSVersion" -ForegroundColor Gray
                        CMTraceLog –Message " Softpaq download URL is $DownloadURL" –Component "Report"
                        Write-Host " Softpaq download URL is $DownloadURL" -ForegroundColor Gray
                        $Script:BIOSReboot = $true
                    }
                    Else  
                    {
                        CMTraceLog –Message "No BIOS recommendation in the XML report" –Component "Report" –Type 2
                        Write-Host "No BIOS recommendation in XML" -ForegroundColor Gray
                    }
                }
                if ($Category -eq "drivers" -or $Category -eq "All"){
                    CMTraceLog –Message "Checking Driver Recommendations" –Component "Report"
                    Write-Host "Checking Driver Recommendations" -ForegroundColor Green                
                    $null = $Recommendation
                    $Recommendation = $xml.HPIA.Recommendations.drivers.Recommendation
                    If ($Recommendation){
                        Foreach ($item in $Recommendation){
                            $ItemName = $item.TargetComponent
                            $CurrentBIOSVersion = $item.TargetVersion
                            $ReferenceBIOSVersion = $item.ReferenceVersion
                            $DownloadURL = "https://" + $item.Solution.Softpaq.Url
                            $SoftpaqFileName = $DownloadURL.Split('/')[-1]
                            CMTraceLog –Message "Component: $ItemName" –Component "Report"
                            Write-Host "Component: $ItemName" -ForegroundColor Gray                           
                            CMTraceLog –Message " Current version is $CurrentBIOSVersion" –Component "Report"
                            Write-Host " Current version is $CurrentBIOSVersion" -ForegroundColor Gray
                            CMTraceLog –Message " Recommended version is $ReferenceBIOSVersion" –Component "Report"
                            Write-Host " Recommended version is $ReferenceBIOSVersion" -ForegroundColor Gray
                            CMTraceLog –Message " Softpaq download URL is $DownloadURL" –Component "Report"
                            Write-Host " Softpaq download URL is $DownloadURL" -ForegroundColor Gray
                            }
                        }
                    Else  
                        {
                        CMTraceLog –Message "No Driver recommendation in the XML report" –Component "Report" –Type 2
                        Write-Host "No Driver recommendation in XML" -ForegroundColor Gray
                        }
                    }
                 if ($Category -eq "Software" -or $Category -eq "All"){
                    CMTraceLog –Message "Checking Software Recommendations" –Component "Report"
                    Write-Host "Checking Software Recommendations" -ForegroundColor Green 
                    $null = $Recommendation
                    $Recommendation = $xml.HPIA.Recommendations.software.Recommendation
                    If ($Recommendation){
                        Foreach ($item in $Recommendation){
                            $ItemName = $item.TargetComponent
                            $CurrentBIOSVersion = $item.TargetVersion
                            $ReferenceBIOSVersion = $item.ReferenceVersion
                            $DownloadURL = "https://" + $item.Solution.Softpaq.Url
                            $SoftpaqFileName = $DownloadURL.Split('/')[-1]
                            CMTraceLog –Message "Component: $ItemName" –Component "Report"
                            Write-Host "Component: $ItemName" -ForegroundColor Gray                           
                            CMTraceLog –Message "Current version is $CurrentBIOSVersion" –Component "Report"
                            Write-Host " Current version is $CurrentBIOSVersion" -ForegroundColor Gray
                            CMTraceLog –Message "Recommended version is $ReferenceBIOSVersion" –Component "Report"
                            Write-Host " Recommended version is $ReferenceBIOSVersion" -ForegroundColor Gray
                            CMTraceLog –Message "Softpaq download URL is $DownloadURL" –Component "Report"
                            Write-Host " Softpaq download URL is $DownloadURL" -ForegroundColor Gray
                        }
                    }
                    Else  
                        {
                        CMTraceLog –Message "No Software recommendation in the XML report" –Component "Report" –Type 2
                        Write-Host "No Software recommendation in XML" -ForegroundColor Gray
                        }
                }
            }
            catch 
            {
                CMTraceLog –Message "Failed to parse the XML file: $($_.Exception.Message)" –Component "Report" –Type 3
            }
        }
        Else  
        {
            CMTraceLog –Message "Failed to find an XML report." –Component "Report" –Type 3
            }
    }
    catch 
    {
        CMTraceLog –Message "Failed to find an XML report: $($_.Exception.Message)" –Component "Report" –Type 3
    }
    
    ## Overview History of HPIA
    try 
    {
        $JSONFile = Get-ChildItem –Path $ReportsFolder –Recurse –Include *.JSON –ErrorAction Stop
        If ($JSONFile)
        {
            Write-Host "Reporting Full HPIA Results" -ForegroundColor Green
            CMTraceLog –Message "JSON located at $($JSONFile.FullName)" –Component "Report"
            try 
            {
            $JSON = Get-Content –Path $JSONFile.FullName  –ErrorAction Stop | ConvertFrom-Json
            CMTraceLog –Message "HPIAOpertaion: $($JSON.HPIA.HPIAOperation)" –Component "Report"
            Write-Host " HPIAOpertaion: $($JSON.HPIA.HPIAOperation)" -ForegroundColor Gray
            CMTraceLog –Message "ExitCode: $($JSON.HPIA.ExitCode)" –Component "Report"
            Write-Host " ExitCode: $($JSON.HPIA.ExitCode)" -ForegroundColor Gray
            CMTraceLog –Message "LastOperation: $($JSON.HPIA.LastOperation)" –Component "Report"
            Write-Host " LastOperation: $($JSON.HPIA.LastOperation)" -ForegroundColor Gray
            CMTraceLog –Message "LastOperationStatus: $($JSON.HPIA.LastOperationStatus)" –Component "Report"
            Write-Host " LastOperationStatus: $($JSON.HPIA.LastOperationStatus)" -ForegroundColor Gray
            $Recommendations = $JSON.HPIA.Recommendations
            if ($Recommendations) {
                Write-Host "HPIA Item Results" -ForegroundColor Green
                foreach ($item in $Recommendations){
                    $ItemName = $Item.Name
                    $ItemRecommendationValue = $Item.RecommendationValue
                    $ItemSoftPaqID = $Item.SoftPaqID
                    CMTraceLog –Message " $ItemName $ItemRecommendationValue | $ItemSoftPaqID" –Component "Report"
                    Write-Host " $ItemName $ItemRecommendationValue | $ItemSoftPaqID" -ForegroundColor Gray
                    CMTraceLog –Message "  URL: $($Item.ReleaseNotesUrl)" –Component "Report"
                    write-host "  URL: $($Item.ReleaseNotesUrl)" -ForegroundColor Gray
                    CMTraceLog –Message "  Status: $($item.Remediation.Status)" –Component "Report"
                    Write-Host "  Status: $($item.Remediation.Status)" -ForegroundColor Gray
                    CMTraceLog –Message "  ReturnCode: $($item.Remediation.ReturnCode)" –Component "Report"
                    Write-Host "  ReturnCode: $($item.Remediation.ReturnCode)" -ForegroundColor Gray
                    CMTraceLog –Message "  ReturnDescription: $($item.Remediation.ReturnDescription)" –Component "Report"
                    Write-Host "  ReturnDescription: $($item.Remediation.ReturnDescription)" -ForegroundColor Gray
                    }
                }
            }
            catch {
            CMTraceLog –Message "Failed to parse the JSON file: $($_.Exception.Message)" –Component "Report" –Type 3
            }
        }
    }
    catch
    {
    CMTraceLog –Message "NO JSON report." –Component "Report" –Type 1
    }

    if ($Script:BIOSReboot -eq $true){
        try {
            Get-BitLockerVolume | Where-Object {$_.ProtectionStatus -eq "On"} | Suspend-BitLocker
        }
        catch{}
        }
    if ($script:RebootRequired ){
        if ($RebootIfNeeded) {
            Restart-Computer -Force
        }
    }
}
