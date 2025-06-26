<# GARY BLOK - GARYTOWN.COM - @GWBLOK

Group of functions I've written for working with HPIA via PowerShell
Note, some of these funtions rely on function Write-CMTraceLog for extra logging, so I've added that here too.

Functions
 - Write-CMTraceLog: Adds information into a Log File that is optimized for CMTrace.exe
 - Get-HPIALatestVersion: Checks HP and returns the information about the latest version of HPIA
 - Install-HPIA: Installs HPIA to Program Files, or Updates if newer version available
 - Run-HPIA: Runs HP based on Parameters, and calls Install-HPIA to make sure HPIA is available.
 	- Can use to Scan system for Recommendations
	- Can use to Install Drivers, Software, BIOS, Firmware

#>

### Write-CMTraceLog
Function Write-CMTraceLog {
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
        $LogFile = "$($env:ProgramData)\logs\Cmtracelog.log"
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

####  Get-HPIALatestVersion
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
        try {$HTML = Invoke-WebRequest -Uri $HPIAWebUrl -ErrorAction Stop }
        catch {Write-Output "Failed to download the HPIA web page. $($_.Exception.Message)" ;throw}
        #$HPIASoftPaqNumber = ($HTML.Links | Where {$_.href -match "hp-hpia-"}).outerText
        $HPIADownloadURL = ($HTML.Links | Where-Object {$_.href -match "hp-hpia-"}).href
        $HPIAFileName = $HPIADownloadURL.Split('/')[-1]
        $HPIAVersion = ($HPIAFileName.Split("-") | Select-Object -Last 1).replace(".exe","")
    }
    $Return = @(
    @{HPIAVersion = "$($HPIAVersion)"; HPIADownloadURL = $HPIADownloadURL ; HPIAFileName = $HPIAFileName}
    )
    return $Return
} 


<#  Install-HPIA
Future updates will be to incorporate Get-HPIALatestVersion to cleanup the code a bit
Perhaps leverage Install-HPImageAssistant function in HPCMSL

#>
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
            try {$HTML = Invoke-WebRequest -Uri $HPIAWebUrl -ErrorAction Stop }
            catch {Write-Output "Failed to download the HPIA web page. $($_.Exception.Message)" ;throw}
            #$HPIASoftPaqNumber = ($HTML.Links | Where-Object {$_.href -match "hp-hpia-"}).outerText
            $HPIADownloadURL = ($HTML.Links | Where-Object {$_.href -match "hp-hpia-"}).href
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
                Invoke-WebRequest -UseBasicParsing -Uri $HPIADownloadURL -OutFile "$TempWorkFolder\$HPIAFileName"
            }
            else{
                Write-Host "$HPIAFileName already downloaded, skipping step" -ForegroundColor Green
            }
    
            #Extract HPIA
            Write-Host "Extracting HPIA" -ForegroundColor Green
            try {
                $Process = Start-Process -FilePath $TempWorkFolder\$HPIAFileName -WorkingDirectory $HPIAInstallPath -ArgumentList '/s /f .\ /e' -NoNewWindow -PassThru -Wait -ErrorAction Stop
                Start-Sleep -Seconds 5
                $null = $Process
                If (Test-Path "$HPIAInstallPath\HPImageAssistant.exe"){
                    Write-Host "Extraction complete" -ForegroundColor Green
                }
                Else{
                    Write-Host "HPImageAssistant not found!" -ForegroundColor Red
                    throw
                }
            }
            catch {
                Write-Host "Failed to extract the HPIA: $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
        }
    }

## Run-HPIA
Function Invoke-HPIA {

    [CmdletBinding()]
        Param (
            [Parameter(Mandatory=$false)]
            [ValidateSet("Analyze", "DownloadSoftPaqs")]
            $Operation = "Analyze",
            [Parameter(Mandatory=$false)]
            [ValidateSet("All", "BIOS", "Drivers", "Software", "Firmware", "Accessories")]
            [String[]]$Category = @("Drivers"),
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
            $ReferenceFile,
            [Parameter(Mandatory=$false)]
            [switch]$SilentMode,
            [Parameter(Mandatory=$false)]
            [switch]$NoninteractiveMode
            )
    $DateTime = Get-Date -Format "yyyyMMdd-HHmm"
    $ReportsFolder = "$($ReportsFolder)\$($DateTime)"
    $CMTraceLog = "$ReportsFolder\HPIACustomLog.log"
    $script:TempWorkFolder = 'C:\windows\temp\HP\HPIA\TempWorkFolder'
    [String]$Category = $($Category -join ",").ToString()
    try{
        [void][System.IO.Directory]::CreateDirectory($LogFolder)
        [void][System.IO.Directory]::CreateDirectory($TempWorkFolder)
        [void][System.IO.Directory]::CreateDirectory($ReportsFolder)
        [void][System.IO.Directory]::CreateDirectory($HPIAInstallPath)
    }
    catch{
        throw
    }
    
    if ($NoninteractiveMode -eq $true){$Noninteractive = "/Noninteractive"}
    else {$Noninteractive = ""} 
    if ($silentMode -eq $true){$Silent = "/Silent"; $Noninteractive = ""}
    else {$Silent = ""}

    Install-HPIA -HPIAInstallPath $HPIAInstallPath
    if ($Action -eq "List"){$LogComp = "Scanning"}
    else {$LogComp = "Updating"}

    try {

        if ($ReferenceFile){
            Write-CMTraceLog -LogFile $CMTraceLog -Message "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action $Silent $Noninteractive /Debug /ReportFolder:$ReportsFolder /ReferenceFile:$ReferenceFile" -Component $LogComp
            Write-Host "Running HPIA With Args: /Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action $Silent $Noninteractive /Debug /ReportFolder:$ReportsFolder /ReferenceFile:$ReferenceFile" -ForegroundColor Green
            $Process = Start-Process -FilePath $HPIAInstallPath\HPImageAssistant.exe -WorkingDirectory $TempWorkFolder -ArgumentList "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action $Silent $Noninteractive /Debug /ReportFolder:$ReportsFolder /ReferenceFile:$ReferenceFile /IgnoreGenericOsError" -NoNewWindow -PassThru -Wait -ErrorAction Stop
        }
        else {
            Write-CMTraceLog -LogFile $CMTraceLog -Message "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action $Silent $Noninteractive /Debug /ReportFolder:$ReportsFolder" -Component $LogComp
            Write-Host "Running HPIA With Args: /Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action $Silent $Noninteractive /Debug /ReportFolder:$ReportsFolder" -ForegroundColor Green
            $Process = Start-Process -FilePath $HPIAInstallPath\HPImageAssistant.exe -WorkingDirectory $TempWorkFolder -ArgumentList "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action $Silent $Noninteractive /Debug /ReportFolder:$ReportsFolder /IgnoreGenericOsError" -NoNewWindow -PassThru -Wait -ErrorAction Stop
        }

        
        If ($Process.ExitCode -eq 0){
            Write-CMTraceLog -LogFile $CMTraceLog -Message "HPIA Analysis complete" -Component $LogComp
            Write-Host "HPIA Analysis complete" -ForegroundColor Green
        }
        elseif ($Process.ExitCode -eq 256){
            Write-CMTraceLog -LogFile $CMTraceLog -Message "Exit $($Process.ExitCode) - The analysis returned no recommendation." -Component "Update" -Type 2
            Write-Host "Exit $($Process.ExitCode) - The analysis returned no recommendation." -ForegroundColor Green
            Write-CMTraceLog -LogFile $CMTraceLog -Message "########################################" -Component "Complete"
            #Exit 0
        }
        elseif ($Process.ExitCode -eq 257){
            Write-CMTraceLog -LogFile $CMTraceLog -Message "Exit $($Process.ExitCode) - There were no recommendations selected for the analysis." -Component "Update" -Type 2
            Write-Host "Exit $($Process.ExitCode) - There were no recommendations selected for the analysis." -ForegroundColor Green
            Write-CMTraceLog -LogFile $CMTraceLog -Message "########################################" -Component "Complete"
            #Exit 0
        }
        elseif ($Process.ExitCode -eq 3010){
            Write-CMTraceLog -LogFile $CMTraceLog -Message "Exit $($Process.ExitCode) - HPIA Complete, requires Restart" -Component "Update" -Type 2
            Write-Host "Exit $($Process.ExitCode) - HPIA Complete, requires Restart" -ForegroundColor Yellow
            $script:RebootRequired = $true
        }
        elseif ($Process.ExitCode -eq 3020){
            Write-CMTraceLog -LogFile $CMTraceLog -Message "Exit $($Process.ExitCode) - Install failed. One or more SoftPaq installations failed." -Component "Update" -Type 2
            Write-Host "Exit $($Process.ExitCode) - Install failed. One or more SoftPaq installations failed." -ForegroundColor Yellow
        }
        elseif ($Process.ExitCode -eq 4096){
            Write-CMTraceLog -LogFile $CMTraceLog -Message "Exit $($Process.ExitCode) - This platform is not supported!" -Component "Update" -Type 2
            Write-Host "Exit $($Process.ExitCode) - This platform is not supported!" -ForegroundColor Yellow
        }
        elseif ($Process.ExitCode -eq 4104){
            Write-CMTraceLog -LogFile $CMTraceLog -Message "Exit $($Process.ExitCode) - HPIA used a generic reference file to make the recommendation" -Component "Update" -Type 2
            Write-Host "Exit $($Process.ExitCode) - HPIA used a generic reference file to make the recommendation" -ForegroundColor Yellow
        }
        elseif ($Process.ExitCode -eq 16386){
            Write-CMTraceLog -LogFile $CMTraceLog -Message "Exit $($Process.ExitCode) - This platform is not supported!" -Component "Update" -Type 2
            Write-Output "Exit $($Process.ExitCode) - The reference file is not supported on platforms running this operating system!"
            Write-Output "You can Manually Run Non-Supported Method to Update Drivers using PowerShell Function [Invoke-HPDriverUpdate -OSVerOverride]"
        }
        elseif ($Process.ExitCode -eq 16385){
            Write-CMTraceLog -LogFile $CMTraceLog -Message "Exit $($Process.ExitCode) - The reference file is invalid" -Component "Update" -Type 2
            Write-Output "Exit $($Process.ExitCode) - The reference file is invalid"
            Write-Output "You can Manually Run Non-Supported Method to Update Drivers using PowerShell Function [Invoke-HPDriverUpdate -OSVerOverride]"
        }
        elseif ($Process.ExitCode -eq 16387){
            Write-CMTraceLog -LogFile $CMTraceLog -Message "Exit $($Process.ExitCode) - The reference file given explicitly on the command line does not match the target System ID or OS version." -Component "Update" -Type 2
            Write-Output "Exit $($Process.ExitCode) - The reference file given explicitly on the command line does not match the target System ID or OS version." 
            Write-Output "You can Manually Run Non-Supported Method to Update Drivers using PowerShell Function [Invoke-HPDriverUpdate -OSVerOverride]"
        }
        elseif ($Process.ExitCode -eq 16388){
            Write-CMTraceLog -LogFile $CMTraceLog -Message "Exit $($Process.ExitCode) - HPIA encountered an error processing the reference file provided on the command line." -Component "Update" -Type 2
            Write-Output "Exit $($Process.ExitCode) - HPIA encountered an error processing the reference file provided on the command line." 
        }
        elseif ($Process.ExitCode -eq 16389){
            Write-CMTraceLog -LogFile $CMTraceLog -Message "Exit $($Process.ExitCode) - HPIA could not find the reference file specified in the command line reference file parameter" -Component "Update" -Type 2
            Write-Output "Exit $($Process.ExitCode) - HPIA could not find the reference file specified in the command line reference file parameter" 
        }
        Else{
            #Write-CMTraceLog -LogFile $CMTraceLog -Message "Exit $($Process.ExitCode) - Expecting 0" -Component "Update" -Type 3
            Write-Output "Exit $($Process.ExitCode) - Expecting 0" 
        }
    }
    catch {
        #Write-CMTraceLog -LogFile $CMTraceLog -Message "Exit $($Process.ExitCode) - Expecting 0" -Component "Update" -Type 3
        Write-Output "Failed to run HPIA Commands in Try/Catch Block: $($_.Exception.Message)" 
    }
    if ($Action -eq 'List'){
        Get-HPIAXMLResult -Category $Category
    }

}
Function Get-HPIAXMLResult {
<#  
Grabs the output from a recent run of HPIA and parses the XML to find recommendations.
#>
[CmdletBinding()]
    Param (
        [ValidateSet("All", "BIOS", "Drivers", "Software", "Firmware", "Accessories")]
        [String[]]$Category = @("Drivers"),
        [Parameter(Mandatory=$false)]
        $ReportsFolder = "$env:systemdrive\ProgramData\HP\HPIA",
	$CMTraceLog = "$env:systemdrive\ProgramData\HP\Logs\HPIACustomLog.log"
        )
    $LatestReportFolder = (Get-ChildItem -Path $ReportsFolder | Where-Object {$_.Attributes -match 'Directory'} | Select-Object -Last 1).FullName
    try {
        $XMLFile = Get-ChildItem -Path $LatestReportFolder -Recurse -Include *.xml -ErrorAction Stop
        If ($XMLFile){
            Write-Output "Report located at $($XMLFile.FullName)"
            try {
                [xml]$XML = Get-Content -Path "$($XMLFile.FullName)" -ErrorAction Stop
                
                if ($Category -eq "BIOS" -or $Category -eq "All" -or $Category -eq "BIOS,Drivers"){
                    Write-CMTraceLog -LogFile $CMTraceLog -Message "Checking BIOS Recommendations" -Component "Report"
                    Write-Host "Checking BIOS Recommendations" -ForegroundColor Green 
                    $null = $Recommendation
                    $Recommendation = $xml.HPIA.Recommendations.BIOS.Recommendation
                    If ($Recommendation){
                        $ItemName = $Recommendation.TargetComponent
                        $CurrentBIOSVersion = $Recommendation.TargetVersion
                        $ReferenceBIOSVersion = $Recommendation.ReferenceVersion
                        $DownloadURL = "https://" + $Recommendation.Solution.Softpaq.Url
                        $SoftpaqFileName = $DownloadURL.Split('/')[-1]
                        Write-Host "Component: $ItemName" -ForegroundColor Gray
                        Write-CMTraceLog -LogFile $CMTraceLog -Message "Component: $ItemName" -Component "Report"                        
                        Write-Host " Current version is $CurrentBIOSVersion" -ForegroundColor Gray
                        Write-CMTraceLog -LogFile $CMTraceLog -Message " Current version is $CurrentBIOSVersion" -Component "Report"    
                        Write-Host " Recommended version is $ReferenceBIOSVersion" -ForegroundColor Gray
                        Write-CMTraceLog -LogFile $CMTraceLog -Message " Recommended version is $ReferenceBIOSVersion" -Component "Report"    
                        Write-Host " Softpaq download URL is $DownloadURL" -ForegroundColor Gray
                        Write-CMTraceLog -LogFile $CMTraceLog -Message " Softpaq download URL is $DownloadURL" -Component "Report"    
                        $Script:BIOSReboot = $true
                        $Script:HPIABIOSUpdateAvailable = $true
                    }
                    Else {
                        Write-Host "No BIOS recommendation in XML" -ForegroundColor Gray
                    }
                }
                if ($Category -eq "drivers" -or $Category -eq "All" -or $Category -eq "BIOS,Drivers"){
                    Write-CMTraceLog -LogFile $CMTraceLog -Message "Checking Driver Recommendations" -Component "Report"
                    Write-Host "Checking Driver Recommendations" -ForegroundColor Green                
                    $null = $Recommendation
                    $Recommendation = $xml.HPIA.Recommendations.drivers.Recommendation
                    If ($Recommendation){
                        $Script:HPIADriverUpdatesAvailable = $true
                        Foreach ($item in $Recommendation){
                            $ItemName = $item.TargetComponent
                            $CurrentBIOSVersion = $item.TargetVersion
                            $ReferenceBIOSVersion = $item.ReferenceVersion
                            $DownloadURL = "https://" + $item.Solution.Softpaq.Url
                            $SoftpaqFileName = $DownloadURL.Split('/')[-1]
                            Write-Host "Component: $ItemName" -ForegroundColor Gray   
                            Write-CMTraceLog -LogFile $CMTraceLog -Message "Component: $ItemName" -Component "Report"                        
                            Write-Host " Current version is $CurrentBIOSVersion" -ForegroundColor Gray
                            Write-CMTraceLog -LogFile $CMTraceLog -Message " Current version is $CurrentBIOSVersion" -Component "Report"
                            Write-Host " Recommended version is $ReferenceBIOSVersion" -ForegroundColor Gray
                            Write-CMTraceLog -LogFile $CMTraceLog -Message " Recommended version is $ReferenceBIOSVersion" -Component "Report"
                            Write-Host " Softpaq download URL is $DownloadURL" -ForegroundColor Gray
                            Write-CMTraceLog -LogFile $CMTraceLog -Message " Softpaq download URL is $DownloadURL" -Component "Report"
                            }
                        }
                    Else {
                        Write-Host "No Driver recommendation in XML" -ForegroundColor Gray
                        Write-CMTraceLog -LogFile $CMTraceLog -Message "No Driver recommendation in XML" -Component "Report"
                    }
                }
                if ($Category -eq "Software" -or $Category -eq "All"){
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
                            Write-Host "Component: $ItemName" -ForegroundColor Gray                           
                            Write-Host " Current version is $CurrentBIOSVersion" -ForegroundColor Gray
                            Write-Host " Recommended version is $ReferenceBIOSVersion" -ForegroundColor Gray
                            Write-Host " Softpaq download URL is $DownloadURL" -ForegroundColor Gray
                        }
                    }
                    Else {
                        Write-Host "No Software recommendation in XML" -ForegroundColor Gray
                    }
                }
            }
            catch {
                Write-Host "Failed to parse the XML file: $($_.Exception.Message)"
                Write-CMTraceLog -LogFile $CMTraceLog -Message "Failed to parse the XML file: $($_.Exception.Message)" -Component "Report"
            }
        }
        Else {
            Write-Host "Failed to find an XML report."
            Write-CMTraceLog -LogFile $CMTraceLog -Message "Failed to find an XML report." -Component "Report"
        }
    }
    catch {
        Write-Host "Failed to find an XML report: $($_.Exception.Message)"
        Write-CMTraceLog -LogFile $CMTraceLog -Message "Failed to find an XML report: $($_.Exception.Message)" -Component "Report"
    }
}

Function Get-HPIAJSONResult {
<#  
Grabs the JSON output from a recent run of HPIA to see what was installed and Exit Codes per item
#>
[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        $ReportsFolder = "$env:systemdrive\ProgramData\HP\HPIA"

        )
    try 
    {
    $LatestReportFolder = (Get-ChildItem -Path $ReportsFolder | Where-Object {$_.Attributes -match 'Directory'} | Select-Object -Last 1).FullName
    $JSONFile = Get-ChildItem -Path $LatestReportFolder -Recurse -Include *.JSON -ErrorAction Stop
        If ($JSONFile)
        {
            Write-Host "Reporting Full HPIA Results" -ForegroundColor Green
            Write-CMTraceLog -LogFile $CMTraceLog -Message "JSON located at $($JSONFile.FullName)" -Component "Report"
            try 
            {
            $JSON = Get-Content -Path "$($JSONFile.FullName)"  -ErrorAction Stop | ConvertFrom-Json
            Write-CMTraceLog -LogFile $CMTraceLog -Message "HPIAOpertaion: $($JSON.HPIA.HPIAOperation)" -Component "Report"
            Write-Host " HPIAOpertaion: $($JSON.HPIA.HPIAOperation)" -ForegroundColor Gray
            Write-CMTraceLog -LogFile $CMTraceLog -Message "ExitCode: $($JSON.HPIA.ExitCode)" -Component "Report"
            Write-Host " ExitCode: $($JSON.HPIA.ExitCode)" -ForegroundColor Gray
            Write-CMTraceLog -LogFile $CMTraceLog -Message "LastOperation: $($JSON.HPIA.LastOperation)" -Component "Report"
            Write-Host " LastOperation: $($JSON.HPIA.LastOperation)" -ForegroundColor Gray
            Write-CMTraceLog -LogFile $CMTraceLog -Message "LastOperationStatus: $($JSON.HPIA.LastOperationStatus)" -Component "Report"
            Write-Host " LastOperationStatus: $($JSON.HPIA.LastOperationStatus)" -ForegroundColor Gray
            $Recommendations = $JSON.HPIA.Recommendations
            if ($Recommendations) {
                Write-Host "HPIA Item Results" -ForegroundColor Green
                foreach ($item in $Recommendations){
                    $ItemName = $Item.Name
                    $ItemRecommendationValue = $Item.RecommendationValue
                    $ItemSoftPaqID = $Item.SoftPaqID
                    #Write-CMTraceLog -LogFile $CMTraceLog -Message " $ItemName $ItemRecommendationValue | $ItemSoftPaqID" -Component "Report"
                    Write-Host " $ItemName $ItemRecommendationValue | $ItemSoftPaqID" -ForegroundColor Gray
                    Write-CMTraceLog -LogFile $CMTraceLog -Message "  URL: $($Item.ReleaseNotesUrl)" -Component "Report"
                    write-host "  URL: $($Item.ReleaseNotesUrl)" -ForegroundColor Gray
                    Write-CMTraceLog -LogFile $CMTraceLog -Message "  Status: $($item.Remediation.Status)" -Component "Report"
                    Write-Host "  Status: $($item.Remediation.Status)" -ForegroundColor Gray
                    Write-CMTraceLog -LogFile $CMTraceLog -Message "  ReturnCode: $($item.Remediation.ReturnCode)" -Component "Report"
                    Write-Host "  ReturnCode: $($item.Remediation.ReturnCode)" -ForegroundColor Gray
                    Write-CMTraceLog -LogFile $CMTraceLog -Message "  ReturnDescription: $($item.Remediation.ReturnDescription)" -Component "Report"
                    Write-Host "  ReturnDescription: $($item.Remediation.ReturnDescription)" -ForegroundColor Gray
                    if ($($item.Remediation.ReturnCode) -eq 3010){$script:RebootRequired = $true}
                    }
                }
            }
            catch {
            Write-CMTraceLog -LogFile $CMTraceLog -Message "Failed to parse the JSON file: $($_.Exception.Message)" -Component "Report" -Type 3
            }
        }
    }
    catch
    {
    Write-CMTraceLog -LogFile $CMTraceLog -Message "NO JSON report." -Component "Report" -Type 1
    }
}