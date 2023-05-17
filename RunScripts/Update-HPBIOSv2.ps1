<# Run-HPIA Run Script
Gary Blok - GARYTOWN.COM

When you create the Run Script, add a List for the variables and populate them with the validateset you see below.

Please note, you will get A LOT of data returned in the Run Script Dialog.  Feel free to remove some of the Write-Hosts.  This was orginally written for other deployment methods.
#>

[CmdletBinding()]
    Param (
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
        [String]$DebugLog = "FALSE",		    
        [Parameter(Mandatory=$false)][string]$CMReboot = "FALSE",
        [Parameter(Mandatory=$false)][string]$RestartNow = "FALSE"
        )


Function Run-HPIA {

<#
Update HP Drivers via HPIA - Gary Blok - @gwblok
Several Code Snips taken from: https://smsagent.blog/2021/03/30/deploying-hp-bios-updates-a-real-world-example/

HPIA User Guide: https://ftp.ext.hp.com/pub/caps-softpaq/cmit/whitepapers/HPIAUserGuide.pdf

Notes about Severity:
Routine – For new hardware support and feature enhancements.
Recommended – For minor bug fixes. HP recommends this SoftPaq be installed.
Critical – For major bug fixes, specific problem resolutions, to enable new OS or Service Pack. Essentially the SoftPaq is required to receive support from HP.
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
        [Switch]$DebugLog = $false
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
    Write-Output "Starting HPIA to Update HP Drivers" 
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
    Write-Output "Download URL is $HPIADownloadURL" 
    ###################
    ## Download HPIA ##
    ###################
    CMTraceLog –Message "Downloading HPIA" –Component "DownloadHPIA"
    Write-Output "Downloading HPIA" 
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
                
            }
            
            if (!(Test-Path -Path "$TempWorkFolder\$HPIAFileName")){
                $HPIA = Invoke-WebRequest -UseBasicParsing -Uri $HPIADownloadURL -OutFile $TempWorkFolder\$HPIAFileName
            } 
            CMTraceLog –Message "Download is finished" –Component "Download"
            Complete-BitsTransfer –BitsJob $BitsJob -ErrorAction SilentlyContinue
            CMTraceLog –Message "Transfer is complete" –Component "Download"
            Write-Output "Transfer is complete" 
        }
        catch 
        {
            CMTraceLog –Message "Failed to start a BITS transfer for the HPIA: $($_.Exception.Message)" –Component "Download" –Type 3
            Write-Output "Failed to start a BITS transfer for the HPIA: $($_.Exception.Message)" 
            throw
        }
    }
    else
        {
        CMTraceLog –Message "$HPIAFileName already downloaded, skipping step" –Component "Download"
        Write-Output "$HPIAFileName already downloaded, skipping step" 
        }
    ##################
    ## Extract HPIA ##
    ##################
    CMTraceLog –Message "Extracting HPIA" –Component "Extract"
    Write-Output "Extracting HPIA" 
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
            Write-Output "HPImageAssistant not found!" 
            throw
        }
    }
    catch 
    {
        CMTraceLog –Message "Failed to extract the HPIA: $($_.Exception.Message)" –Component "Extract" –Type 3
        Write-Output "Failed to extract the HPIA: $($_.Exception.Message)" 
        throw
    }
    ##############################################
    ## Install Updates with HPIA ##
    ##############################################
    try 
    {
        if ($DebugLog -eq $false){
            CMTraceLog –Message "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /ReportFolder:$ReportsFolder" –Component "Update"
            Write-Output "Running HPIA With Args: /Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /ReportFolder:$ReportsFolder" 
            $Process = Start-Process –FilePath $TempWorkFolder\HPIA\HPImageAssistant.exe –WorkingDirectory $TempWorkFolder –ArgumentList "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /ReportFolder:$ReportsFolder" –NoNewWindow –PassThru –Wait –ErrorAction Stop
        }
        else {
            CMTraceLog –Message "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder" –Component "Update"
            Write-Output "Running HPIA With Args: /Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder" 
            $Process = Start-Process –FilePath $TempWorkFolder\HPIA\HPImageAssistant.exe –WorkingDirectory $TempWorkFolder –ArgumentList "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder" –NoNewWindow –PassThru –Wait –ErrorAction Stop
        }
        
        If ($Process.ExitCode -eq 0)
        {
            CMTraceLog –Message "Analysis complete" –Component "Update"
            Write-Output "Analysis complete" 
        }
        elseif ($Process.ExitCode -eq 256) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - The analysis returned no recommendation." –Component "Update" –Type 2
            Write-Output "Exit $($Process.ExitCode) - The analysis returned no recommendation." 
            Exit 0
        }
         elseif ($Process.ExitCode -eq 257) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - There were no recommendations selected for the analysis." –Component "Update" –Type 2
            Write-Output "Exit $($Process.ExitCode) - There were no recommendations selected for the analysis." 
            Exit 0
        }
        elseif ($Process.ExitCode -eq 3010) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - HPIA Complete, requires Restart" –Component "Update" –Type 2
            Write-Output "Exit $($Process.ExitCode) - HPIA Complete, requires Restart" 
        }
        elseif ($Process.ExitCode -eq 3020) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - Install failed — One or more SoftPaq installations failed." –Component "Update" –Type 2
            Write-Output "Exit $($Process.ExitCode) - Install failed — One or more SoftPaq installations failed." 
        }
        elseif ($Process.ExitCode -eq 4096) 
        {
            CMTraceLog –Message "Exit $($Process.ExitCode) - This platform is not supported!" –Component "Update" –Type 2
            Write-Output "Exit $($Process.ExitCode) - This platform is not supported!" 
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
            Write-Output "Process exited with code $($Process.ExitCode). Expecting 0." 
            throw
        }
    }
    catch 
    {
        CMTraceLog –Message "Failed to start the HPImageAssistant.exe: $($_.Exception.Message)" –Component "Update" –Type 3
        Write-Output "Failed to start the HPImageAssistant.exe: $($_.Exception.Message)" 
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
                    Write-Output "Checking BIOS Recommendations"  
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
                        Write-Output "Component: $ItemName"                            
                        CMTraceLog –Message " Current version is $CurrentBIOSVersion" –Component "Report"
                        Write-Output " Current version is $CurrentBIOSVersion" 
                        CMTraceLog –Message " Recommended version is $ReferenceBIOSVersion" –Component "Report"
                        Write-Output " Recommended version is $ReferenceBIOSVersion" 
                        CMTraceLog –Message " Softpaq download URL is $DownloadURL" –Component "Report"
                        Write-Output " Softpaq download URL is $DownloadURL"
                        if ($Action -eq "Install"){$Script:BIOSReboot = $true}
                    }
                    Else  
                    {
                        CMTraceLog –Message "No BIOS recommendation in the XML report" –Component "Report" –Type 2
                        Write-Output "No BIOS recommendation in XML" 
                    }
                }
                if ($Category -eq "drivers" -or $Category -eq "All"){
                    CMTraceLog –Message "Checking Driver Recommendations" –Component "Report"
                    Write-Output "Checking Driver Recommendations"                 
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
                            Write-Output "Component: $ItemName"                            
                            CMTraceLog –Message " Current version is $CurrentBIOSVersion" –Component "Report"
                            Write-Output " Current version is $CurrentBIOSVersion" 
                            CMTraceLog –Message " Recommended version is $ReferenceBIOSVersion" –Component "Report"
                            Write-Output " Recommended version is $ReferenceBIOSVersion" 
                            CMTraceLog –Message " Softpaq download URL is $DownloadURL" –Component "Report"
                            Write-Output " Softpaq download URL is $DownloadURL" 
                            }
                        }
                    Else  
                        {
                        CMTraceLog –Message "No Driver recommendation in the XML report" –Component "Report" –Type 2
                        Write-Output "No Driver recommendation in XML" 
                        }
                    }
                 if ($Category -eq "Software" -or $Category -eq "All"){
                    CMTraceLog –Message "Checking Software Recommendations" –Component "Report"
                    Write-Output "Checking Software Recommendations"  
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
                            Write-Output "Component: $ItemName"                            
                            CMTraceLog –Message "Current version is $CurrentBIOSVersion" –Component "Report"
                            Write-Output " Current version is $CurrentBIOSVersion" 
                            CMTraceLog –Message "Recommended version is $ReferenceBIOSVersion" –Component "Report"
                            Write-Output " Recommended version is $ReferenceBIOSVersion" 
                            CMTraceLog –Message "Softpaq download URL is $DownloadURL" –Component "Report"
                            Write-Output " Softpaq download URL is $DownloadURL" 
                        }
                    }
                    Else  
                        {
                        CMTraceLog –Message "No Software recommendation in the XML report" –Component "Report" –Type 2
                        Write-Output "No Software recommendation in XML" 
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
            Write-Output "Reporting Full HPIA Results" 
            CMTraceLog –Message "JSON located at $($JSONFile.FullName)" –Component "Report"
            try 
            {
            $JSON = Get-Content –Path $JSONFile.FullName  –ErrorAction Stop | ConvertFrom-Json
            CMTraceLog –Message "HPIAOpertaion: $($JSON.HPIA.HPIAOperation)" –Component "Report"
            Write-Output " HPIAOpertaion: $($JSON.HPIA.HPIAOperation)" 
            CMTraceLog –Message "ExitCode: $($JSON.HPIA.ExitCode)" –Component "Report"
            Write-Output " ExitCode: $($JSON.HPIA.ExitCode)" 
            CMTraceLog –Message "LastOperation: $($JSON.HPIA.LastOperation)" –Component "Report"
            Write-Output " LastOperation: $($JSON.HPIA.LastOperation)" 
            CMTraceLog –Message "LastOperationStatus: $($JSON.HPIA.LastOperationStatus)" –Component "Report"
            Write-Output " LastOperationStatus: $($JSON.HPIA.LastOperationStatus)" 
            $Recommendations = $JSON.HPIA.Recommendations
            if ($Recommendations) {
                Write-Output "HPIA Item Results" 
                foreach ($item in $Recommendations){
                    $ItemName = $Item.Name
                    $ItemRecommendationValue = $Item.RecommendationValue
                    $ItemSoftPaqID = $Item.SoftPaqID
                    CMTraceLog –Message " $ItemName $ItemRecommendationValue | $ItemSoftPaqID" –Component "Report"
                    Write-Output " $ItemName $ItemRecommendationValue | $ItemSoftPaqID" 
                    CMTraceLog –Message "  URL: $($Item.ReleaseNotesUrl)" –Component "Report"
                    Write-Output "  URL: $($Item.ReleaseNotesUrl)" 
                    CMTraceLog –Message "  Status: $($item.Remediation.Status)" –Component "Report"
                    Write-Output "  Status: $($item.Remediation.Status)" 
                    CMTraceLog –Message "  ReturnCode: $($item.Remediation.ReturnCode)" –Component "Report"
                    Write-Output "  ReturnCode: $($item.Remediation.ReturnCode)" 
                    CMTraceLog –Message "  ReturnDescription: $($item.Remediation.ReturnDescription)" –Component "Report"
                    Write-Output "  ReturnDescription: $($item.Remediation.ReturnDescription)"
                    if ($($item.Remediation.ReturnCode) -eq '3010'){$script:RebootRequired = $true}
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
            $Status = (Get-BitLockerVolume).ProtectionStatus
            Write-Host "Bitlocker Status: $Status"

        }
        catch{}
    }
}
Function Convert-FromUnixDate ($UnixDate) {
    [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($UnixDate))
}
    Function Restart-ComputerCM {
        if (Test-Path -Path "C:\windows\ccm\CcmRestart.exe"){

            $time = [DateTimeOffset]::Now.ToUnixTimeSeconds()
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootBy' -Value $time -PropertyType QWord -Force -ea SilentlyContinue;
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootValueInUTC' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'NotifyUI' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'HardReboot' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindowTime' -Value 0 -PropertyType QWord -Force -ea SilentlyContinue;
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindow' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'PreferredRebootWindowTypes' -Value @("4") -PropertyType MultiString -Force -ea SilentlyContinue;
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'GraceSeconds' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;

            $CCMRestart = start-process -FilePath C:\windows\ccm\CcmRestart.exe -NoNewWindow -PassThru
        }
        else {
            Write-Output "No CM Client Found"
        }
    }


$BIOSInfo = Get-WmiObject -Class 'Win32_Bios'

# Get the current BIOS release date and format it to datetime
$CurrentBIOSDate = [System.Management.ManagementDateTimeConverter]::ToDatetime($BIOSInfo.ReleaseDate).ToUniversalTime()

$Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
$ManufacturerBaseBoard = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Manufacturer
$ComputerModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model
if ($ManufacturerBaseBoard -eq "Intel Corporation")
    {
    $ComputerModel = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
    }
$HPProdCode = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$InstallDate_CurrentOS = Convert-FromUnixDate $CurrentOSInfo.GetValue('InstallDate')
$WindowsRelease = $CurrentOSInfo.GetValue('ReleaseId')
$WindowsDisplayVersion = $CurrentOSInfo.GetValue('DisplayVersion')
if (($WindowsRelease -eq "2009") -and ($WindowsDisplayVersion -ne "")){$WindowsRelease = $WindowsDisplayVersion}
$BuildUBR_CurrentOS = $($CurrentOSInfo.GetValue('CurrentBuild'))+"."+$($CurrentOSInfo.GetValue('UBR'))

# Write Information
Write-Output "Computer Name: $env:computername"
Write-Output "Windows $WindowsRelease | $BuildUBR_CurrentOS | Installed: $InstallDate_CurrentOS"

if ($Manufacturer -like "H*"){Write-Output "Computer Model: $ComputerModel | Platform: $HPProdCode"}
else {Write-Output "Computer Model: $ComputerModel"}

Write-Output "Current BIOS Level: $($BIOSInfo.SMBIOSBIOSVersion) From Date: $CurrentBIOSDate"
if ($Manufacturer -like "H*"){
    if ($DebugLog -eq "FALSE") {Run-HPIA -Operation Analyze -Category $Category -Selection $Selection -Action $Action}
    else {Run-HPIA -Operation Analyze -Category $Category -Selection $Selection -Action $Action -DebugLog}

    if ($script:RebootRequired -eq $true)
        {Write-Output "!!!!! ----- REBOOT REQUIRED ----- !!!!!"
        if ($CMReboot -eq "TRUE"){Restart-ComputerCM}
        if ($RestartNow -eq "TRUE") {Restart-Computer -Force}
        }
    else {Write-Output "Success, No Reboot"}
}
else { Write-Output "Not Running HPIA - Not HP Device"}
    
