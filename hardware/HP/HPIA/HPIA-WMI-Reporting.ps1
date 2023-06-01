<# GARY BLOK - GARYTOWN.COM - @GWBLOK

BUGS = If no recommendations, XML file doesn't have data for stuff in the Compliance Class..> Fix

#>


#region Functions
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
    Function Run-HPIA {
    
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
       $ReferenceFile
       )
    $DateTime = Get-Date –Format "yyyyMMdd-HHmmss"
    $ReportsFolder = "$ReportsFolder\$DateTime"
    $script:TempWorkFolder = "$env:temp\HPIA"
    [String]$Category = $($Category -join ",").ToString()
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
           Write-Host "Running HPIA With Args: /Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder /ReferenceFile:$ReferenceFile" -ForegroundColor Green
           $Process = Start-Process –FilePath $HPIAInstallPath\HPImageAssistant.exe –WorkingDirectory $TempWorkFolder –ArgumentList "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder /ReferenceFile:$ReferenceFile" –NoNewWindow –PassThru –Wait –ErrorAction Stop
       }
       else {
           Write-Host "Running HPIA With Args: /Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder" -ForegroundColor Green
           $Process = Start-Process –FilePath $HPIAInstallPath\HPImageAssistant.exe –WorkingDirectory $TempWorkFolder –ArgumentList "/Operation:$Operation /Category:$Category /Selection:$Selection /Action:$Action /Silent /Debug /ReportFolder:$ReportsFolder" –NoNewWindow –PassThru –Wait –ErrorAction Stop
       }
    
       
       If ($Process.ExitCode -eq 0)
       {
           Write-Host "HPIA Analysis complete" -ForegroundColor Green
       }
       elseif ($Process.ExitCode -eq 256) 
       {
           Write-Host "Exit $($Process.ExitCode) - The analysis returned no recommendation." -ForegroundColor Green
           Stop-Transcript
           Exit 0
       }
        elseif ($Process.ExitCode -eq 257) 
       {
           Write-Host "Exit $($Process.ExitCode) - There were no recommendations selected for the analysis." -ForegroundColor Green      
           Stop-Transcript
           Exit 0
       }
       elseif ($Process.ExitCode -eq 3010) 
       {
           Write-Host "Exit $($Process.ExitCode) - HPIA Complete, requires Restart" -ForegroundColor Yellow
           $script:RebootRequired = $true
       }
       elseif ($Process.ExitCode -eq 3020) 
       {
           Write-Host "Exit $($Process.ExitCode) - Install failed — One or more SoftPaq installations failed." -ForegroundColor Yellow
       }
       elseif ($Process.ExitCode -eq 4096) 
       {
           Write-Host "Exit $($Process.ExitCode) - This platform is not supported!" -ForegroundColor Yellow
           Stop-Transcript
           throw
       }
       elseif ($Process.ExitCode -eq 16386) 
       {
           Write-Output "Exit $($Process.ExitCode) - The reference file is not supported on platforms running the Windows 10 operating system!"
           Stop-Transcript 
           throw
       }
       elseif ($Process.ExitCode -eq 16385) 
       {
           Write-Output "Exit $($Process.ExitCode) - The reference file is invalid"
           Stop-Transcript 
           throw
       }
       elseif ($Process.ExitCode -eq 16387) 
       {
           Write-Output "Exit $($Process.ExitCode) - The reference file given explicitly on the command line does not match the target System ID or OS version." 
           throw
       }
       elseif ($Process.ExitCode -eq 16388) 
       {
           Write-Output "Exit $($Process.ExitCode) - HPIA encountered an error processing the reference file provided on the command line." 
           Stop-Transcript
           throw
       }
       elseif ($Process.ExitCode -eq 16389) 
       {
           Write-Output "Exit $($Process.ExitCode) - HPIA could not find the reference file specified in the command line reference file parameter" 
           Stop-Transcript
           throw
       }
       Else
       {
           Write-Host "Process exited with code $($Process.ExitCode). Expecting 0." -ForegroundColor Yellow
           Stop-Transcript
           throw
       }
    }
    catch {
       Write-Host "Failed to start the HPImageAssistant.exe: $($_.Exception.Message)" -ForegroundColor Red
       Stop-Transcript
       throw
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
       $ReportsFolder = "$env:systemdrive\ProgramData\HP\HPIA"
    
       )
    [String]$Category = $($Category -join ",").ToString()
    $LatestReportFolder = (Get-ChildItem -Path $ReportsFolder | Where-Object {$_.Attributes -match 'Directory'} | Select-Object -Last 1).FullName
    try 
    {
       $XMLFile = Get-ChildItem –Path $LatestReportFolder –Recurse –Include *.xml –ErrorAction Stop
       If ($XMLFile)
       {
           Write-Output "Report located at $($XMLFile.FullName)"
           $Script:XMLReportPath = $($XMLFile.FullName)
           try 
           {
               [xml]$XML = Get-Content –Path $XMLFile.FullName –ErrorAction Stop
               
               if ($Category -match "BIOS" -or $Category -eq "All"){
                   Write-Host "Checking BIOS Recommendations" -ForegroundColor Green 
                   $null = $Recommendation
                   $Recommendation = $xml.HPIA.Recommendations.BIOS.Recommendation
                   If ($Recommendation)
                   {
                       $script:BIOSRecommendation = $Recommendation
                       $ItemName = $Recommendation.TargetComponent
                       $Script:CurrentBIOSVersion = $Recommendation.TargetVersion
                       $Script:ReferenceBIOSVersion = $Recommendation.ReferenceVersion
                       $DownloadURL = "https://" + $Recommendation.Solution.Softpaq.Url
                       $SoftpaqFileName = $DownloadURL.Split('/')[-1]
                       Write-Host "Component: $ItemName" -ForegroundColor Gray
                       Write-Host " Current version is $CurrentBIOSVersion" -ForegroundColor Gray
                       Write-Host " Recommended version is $ReferenceBIOSVersion" -ForegroundColor Gray
                       Write-Host " Softpaq download URL is $DownloadURL" -ForegroundColor Gray
                       $Script:BIOSReboot = $true
                       $Script:HPIABIOSUpdateAvailable = $true
                       $Script:HPIAUpdatesAvailable = $true
                   }
                   Else  
                   {
                       Write-Host "No BIOS recommendation in XML" -ForegroundColor Gray
                       $Script:HPIABIOSUpdateAvailable = $false
                       $Script:HPIAUpdatesAvailable = $false
                   }
               }
               if ($Category -match "drivers" -or $Category -eq "All"){
                   Write-Host "Checking Driver Recommendations" -ForegroundColor Green                
                   $null = $Recommendation
                   $Recommendation = $xml.HPIA.Recommendations.drivers.Recommendation
                   If ($Recommendation){
                       $Script:DriverRecommendation = $Recommendation
                       $Script:HPIADriverUpdatesAvailable = $true
                       $Script:HPIAUpdatesAvailable = $true
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
                   Else  
                       {
                       Write-Host "No Driver recommendation in XML" -ForegroundColor Gray
                       $Script:HPIADriverUpdatesAvailable = $false
                       $Script:HPIAUpdatesAvailable = $false
                    }
                   }
               if ($Category -match "Software" -or $Category -eq "All"){
                   Write-Host "Checking Software Recommendations" -ForegroundColor Green 
                   $null = $Recommendation
                   $Recommendation = $xml.HPIA.Recommendations.software.Recommendation
                   If ($Recommendation){
                       $Script:SoftwareRecommendation = $Recommendation
                       $Script:HPIAUpdatesAvailable = $true
                       $Script:HPIASoftwareUpdatesAvailable = $true
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
                   Else  
                       {
                       Write-Host "No Software recommendation in XML" -ForegroundColor Gray
                       $Script:HPIASoftwarepdatesAvailable = $false
                       $Script:HPIAUpdatesAvailable = $false
                    }
               }
               if ($Category -match "Firmware" -or $Category -eq "All"){
                    Write-Host "Checking Firmware Recommendations" -ForegroundColor Green
                    $null = $Recommendation
                    $Recommendation = $xml.HPIA.Recommendations.Firmware.Recommendation
                    If ($Recommendation){
                        $Script:FirmwareRecommendation = $Recommendation
                        $Script:HPIAFirmwareUpdatesAvailable = $true
                        $Script:HPIAUpdatesAvailable = $true
                        Foreach ($item in $Recommendation){
                            $ItemName = $item.TargetComponent
                            $CurrentVersion = $item.TargetVersion
                            $ReferenceVersion = $item.ReferenceVersion
                            $DownloadURL = "https://" + $item.Solution.Softpaq.Url
                            $SoftpaqFileName = $DownloadURL.Split('/')[-1]
                            Write-Host "Component: $ItemName" -ForegroundColor Gray   
                            Write-Host " Current version is $CurrentVersion" -ForegroundColor Gray
                            Write-Host " Recommended version is $ReferenceVersion" -ForegroundColor Gray
                            Write-Host " Softpaq download URL is $DownloadURL" -ForegroundColor Gray
                        }
                    }
                    Else  
                        {
                        Write-Host "No Firmware recommendation in XML" -ForegroundColor Gray
                        $Script:HPIAFirmwareUpdatesAvailable = $false
                        $Script:HPIAUpdatesAvailable = $false
                    }
                }
           }
           catch 
           {
               Write-Host "Failed to parse the XML file: $($_.Exception.Message)"
           }
       }
       Else  
       {
           Write-Host "Failed to find an XML report."
           }
    }
    catch 
    {
       Write-Host "Failed to find an XML report: $($_.Exception.Message)"
    }
    }
    Function New-WMIHPCompliance {
        Param (
           [Parameter(Mandatory=$false)]
           [String]$Namespace = "HP\HPIA",
           [Parameter(Mandatory=$false)]
           [String]$Class = "HPIA_Compliance"
           )
    
    
        # Does Namespace Already Exist?
        Write-Verbose "Getting WMI namespace $Namespace"
        $Root = $Namespace | Split-Path
        $filterNameSpace = $Namespace.Replace("$Root\","")
        $NSfilter = "Name = '$filterNameSpace'"
        $NSExist = Get-WmiObject -Namespace "Root\$Root" -Class "__namespace" -filter $NSfilter
    
        # Namespace Does Not Exist
        If(!($NSExist)){
            Write-Verbose "$Namespace namespace does not exist. Creating new namespace . . ."
            # Create Namespace
            $rootNamespace = [wmiclass]'root/HP:__namespace'
            $NewNamespace = $rootNamespace.CreateInstance()
            $NewNamespace.Name = $filterNameSpace
            $NewNamespace.Put()
        }
        Write-Verbose "Getting $Class Class"
        $ClassExist = Get-CimClass -Namespace root/$Namespace -ClassName $Class -ErrorAction SilentlyContinue    
        If(!($ClassExist)){
            Write-Verbose "$Class class does not exist. Creating new class . . ."
            # Create Class
            $NewClass = New-Object System.Management.ManagementClass("root\$namespace", [string]::Empty, $null)
            $NewClass.name = $Class
            $NewClass.Qualifiers.Add("Static",$true)
            $NewClass.Qualifiers.Add("Description","HPIA Compliance Info")
            $NewClass.Properties.Add("Compliance",[System.Management.CimType]::Boolean, $false)
            $NewClass.Properties.Add("ReferenceFileDate",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("ReferencePlatform",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("ReferenceOS",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("RecommendedDrivers",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("RecommendedSoftware",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("RecommendedFirmware",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("RecommendedBIOS",[System.Management.CimType]::Boolean, $false)
            $NewClass.Properties.Add("RecommendedBIOSTargetVer",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("RecommendedBIOSCurrentVer",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("DateTime",[System.Management.CimType]::DateTime, $false)
            $NewClass.Properties.Add("ID",[System.Management.CimType]::String, $false)
            $NewClass.Properties["ID"].Qualifiers.Add("Key",$true)
            $NewClass.Put()
        } 
    
    }
    Function New-WMIHPRecommendations {
        Param (
           [Parameter(Mandatory=$false)]
           [String]$Namespace = "HP\HPIA",
           [Parameter(Mandatory=$false)]
           [String]$Class = "HPIA_Recommendations"
           )
        
        # Does Namespace Already Exist?
        Write-Verbose "Getting WMI namespace $Namespace"
        $Root = $Namespace | Split-Path
        $filterNameSpace = $Namespace.Replace("$Root\","")
        $NSfilter = "Name = '$filterNameSpace'"
        $NSExist = Get-WmiObject -Namespace "Root\$Root" -Class "__namespace" -filter $NSfilter
    
        # Namespace Does Not Exist
        If(!($NSExist)){
            Write-Verbose "$Namespace namespace does not exist. Creating new namespace . . ."
            # Create Namespace
            $rootNamespace = [wmiclass]'root/HP:__namespace'
            $NewNamespace = $rootNamespace.CreateInstance()
            $NewNamespace.Name = $filterNameSpace
            $NewNamespace.Put()
        }
        Write-Verbose "Getting $Class Class"
        $ClassExist = Get-CimClass -Namespace root/$Namespace -ClassName $Class -ErrorAction SilentlyContinue    
        If(!($ClassExist)){
            Write-Verbose "$Class class does not exist. Creating new class . . ."
            # Create Class
            $NewClass = New-Object System.Management.ManagementClass("root\$namespace", [string]::Empty, $null)
            $NewClass.name = $Class
            $NewClass.Qualifiers.Add("Static",$true)
            $NewClass.Qualifiers.Add("Description","HPIA Softpaq Recommendations")
            $NewClass.Properties.Add("Softpaq_ID",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("Softpaq_Name",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("Softpaq_Version",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("Softpaq_Url",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("TargetComponent",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("TargetVersion",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("ReferenceVersion",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("Comments",[System.Management.CimType]::String, $false)
            $NewClass.Properties.Add("ID",[System.Management.CimType]::String, $false)
            $NewClass.Properties["ID"].Qualifiers.Add("Key",$true)
            $NewClass.Put()
        } 
    
    }
    
    #endregion Functions
    
    
    #Start Script
    
    [String[]]$DesiredCategories = @("Drivers","BIOS")
    
    #Confirm WMI Namespace & Class Setup:
    # Set Vars for WMI Info
    [String]$Namespace = "HP\HPIA"
    [String]$Class = "HPIA_Compliance"
    New-WMIHPCompliance -Namespace $Namespace -Class $Class
    
    [String]$Namespace = "HP\HPIA"
    [String]$Class = "HPIA_Recommendations"
    New-WMIHPRecommendations -Namespace $Namespace -Class $Class
    
    
    #File Locations:
    $HPIAStagingFolder = "$env:ProgramData\HP\HPIAUpdateService"
    $HPIAStagingLogFiles = "$HPIAStagingFolder\LogFiles"
    $HPIAStagingReports = "$HPIAStagingFolder\Reports"
    $HPIAStagingProgram = "$env:ProgramFiles\HPIA"
    try {
        [void][System.IO.Directory]::CreateDirectory($HPIAStagingFolder)
        [void][System.IO.Directory]::CreateDirectory($HPIAStagingLogFiles)
        [void][System.IO.Directory]::CreateDirectory($HPIAStagingReports)
        [void][System.IO.Directory]::CreateDirectory($HPIAStagingProgram)
    }
    catch {throw}
    
    Run-HPIA -Operation Analyze -Category $DesiredCategories -Selection All -Action List -LogFolder $HPIAStagingLogFiles -ReportsFolder $HPIAStagingReports -Debug
    
    #Get HPIA XML Results from Last Run
    Get-HPIAXMLResult -ReportsFolder $HPIAStagingReports  -Category $DesiredCategories
    
    
    #region Populate WMI Compliance Class
    #Get Reference File Information
    if (Test-Path -Path $XMLReportPath){
        [XML]$XML = Get-Content -Path $XMLReportPath
        $Platform = $XML.hpia.SystemInfo.System.SystemID
        $OSBuildNumber = $XML.hpia.SystemInfo.System.OSVersion
        $RefDate = $XML.hpia.ReferenceImageLastModified
        $RecommendedDrivers = ([int]$XML.hpia.Summary.Drivers.OutOfDate) + ([int]$XML.hpia.Summary.Drivers.Recommended)
        $RecommendedSoftware = ([int]$XML.hpia.Summary.Software.OutOfDate) + ([int]$XML.hpia.Summary.Software.Recommended)
        $RecommendedFirmware = ([int]$XML.hpia.Summary.Firmware.OutOfDate) + ([int]$XML.hpia.Summary.Firmware.Recommended)
        if ($HPIABIOSUpdateAvailable -eq $true){
            $RecommendedBIOS = $true
            $RecommendedBIOSTargetVer = $ReferenceBIOSVersion
            $RecommendedBIOSCurrentVer = $CurrentBIOSVersion
        }
        else {
            $RecommendedBIOS = $false
            $RecommendedBIOSTargetVer = $XML.hpia.SystemInfo.System.BIOSVersion
            $RecommendedBIOSCurrentVer = $XML.hpia.SystemInfo.System.BIOSVersion
        }
    }
    else {
        Write-Output "Failed to find Reference File"
    }
    
    if ($HPIAUpdatesAvailable -eq $true){
        $HPIACompliance = $false
    
    }
    else {
        $HPIACompliance = $true
    
    }
    
    #HP Compliance WMI Class
    [String]$Class = "HPIA_Compliance"
    [String]$ID = "HPIA_ComplianceData"
        
    #Get Time for CIM Format
    $time = (Get-Date)
    $objScriptTime = New-Object -ComObject WbemScripting.SWbemDateTime
    $objScriptTime.SetVarDate($time)
    $cimTime = $objScriptTime.Value
    
    #Create Instance in WMI Class
    $wmipath = 'root\'+$Namespace+':'+$class
    $WMIInstance = ([wmiclass]$wmipath).CreateInstance()
    $WMIInstance.Compliance = $HPIACompliance
    $WMIInstance.ReferenceFileDate = $RefDate
    $WMIInstance.ReferencePlatform = $Platform
    $WMIInstance.ReferenceOS = $OSBuildNumber
    $WMIInstance.RecommendedDrivers = $RecommendedDrivers
    $WMIInstance.RecommendedSoftware = $RecommendedSoftware
    $WMIInstance.RecommendedFirmware = $RecommendedFirmware
    $WMIInstance.RecommendedBIOS = $RecommendedBIOS
    $WMIInstance.RecommendedBIOSTargetVer = $RecommendedBIOSTargetVer
    $WMIInstance.RecommendedBIOSCurrentVer = $RecommendedBIOSCurrentVer
    $WMIInstance.DateTime = ($cimTime)
    $WMIInstance.ID = $ID
    $WMIInstance.Put()
    Clear-Variable -Name WMIInstance
    
    #endregion 
    
    #HP Softpaq Recommendation WMI Class
    
    #Clear Previous Instances
    $PreviousInstances = Get-CimInstance -Namespace root/HP/HPIA -ClassName HPIA_Recommendations
    if ($PreviousInstances){
        Get-CimInstance -Namespace root/HP/HPIA -ClassName HPIA_Recommendations | Remove-CimInstance
    }
    
    if ($BIOSRecommendation){
    
        #HP Compliance WMI Class
        [String]$Class = "HPIA_Recommendations"
        [String]$ID = "HPIA_$($BIOSRecommendation.Solution.Softpaq.id)"
        
        #Create Instance in WMI Class
        $wmipath = 'root\'+$Namespace+':'+$class
        $WMIInstance = ([wmiclass]$wmipath).CreateInstance()
        $WMIInstance.Softpaq_ID = $BIOSRecommendation.Solution.Softpaq.id
        $WMIInstance.Softpaq_Name = $BIOSRecommendation.Solution.Softpaq.Name
        $WMIInstance.Softpaq_Version = $BIOSRecommendation.Solution.Softpaq.Version
        $WMIInstance.Softpaq_Url = $BIOSRecommendation.Solution.Softpaq.Url
        $WMIInstance.TargetComponent = $BIOSRecommendation.TargetComponent
        $WMIInstance.TargetVersion = $BIOSRecommendation.TargetVersion
        $WMIInstance.ReferenceVersion = $BIOSRecommendation.ReferenceVersion
        $WMIInstance.Comments = $BIOSRecommendation.Comments
        $WMIInstance.ID = $ID
        $WMIInstance.Put()
        Clear-Variable -Name WMIInstance
    }
    
    if ($DriverRecommendation){
        foreach ($item in $DriverRecommendation){
            #HP Compliance WMI Class
            [String]$Class = "HPIA_Recommendations"
            [String]$ID = "HPIA_$($item.Solution.Softpaq.id)"
        
            #Create Instance in WMI Class
            $wmipath = 'root\'+$Namespace+':'+$class
            $WMIInstance = ([wmiclass]$wmipath).CreateInstance()
            $WMIInstance.Softpaq_ID = $item.Solution.Softpaq.id
            $WMIInstance.Softpaq_Name = $item.Solution.Softpaq.Name
            $WMIInstance.Softpaq_Version = $item.Solution.Softpaq.Version
            $WMIInstance.Softpaq_Url = $item.Solution.Softpaq.Url
            $WMIInstance.TargetComponent = $item.TargetComponent
            $WMIInstance.TargetVersion = $item.TargetVersion
            $WMIInstance.ReferenceVersion = $item.ReferenceVersion
            $WMIInstance.Comments = $item.Comments
            $WMIInstance.ID = $ID
            $WMIInstance.Put()
            Clear-Variable -Name WMIInstance
    
        }
    }
    
    if ($SoftwareRecommendation){
        foreach ($item in $SoftwareRecommendation){
            #HP Compliance WMI Class
            [String]$Class = "HPIA_Recommendations"
            [String]$ID = "HPIA_$($item.Solution.Softpaq.id)"
        
            #Create Instance in WMI Class
            $wmipath = 'root\'+$Namespace+':'+$class
            $WMIInstance = ([wmiclass]$wmipath).CreateInstance()
            $WMIInstance.Softpaq_ID = $item.Solution.Softpaq.id
            $WMIInstance.Softpaq_Name = $item.Solution.Softpaq.Name
            $WMIInstance.Softpaq_Version = $item.Solution.Softpaq.Version
            $WMIInstance.Softpaq_Url = $item.Solution.Softpaq.Url
            $WMIInstance.TargetComponent = $item.TargetComponent
            $WMIInstance.TargetVersion = $item.TargetVersion
            $WMIInstance.ReferenceVersion = $item.ReferenceVersion
            $WMIInstance.Comments = $item.Comments
            $WMIInstance.ID = $ID
            $WMIInstance.Put()
            Clear-Variable -Name WMIInstance
        }
    }
    
    if ($FirmwareRecommendation){
        foreach ($item in $FirmwareRecommendation){
            #HP Compliance WMI Class
            [String]$Class = "HPIA_Recommendations"
            [String]$ID = "HPIA_$($item.Solution.Softpaq.id)"
        
            #Create Instance in WMI Class
            $wmipath = 'root\'+$Namespace+':'+$class
            $WMIInstance = ([wmiclass]$wmipath).CreateInstance()
            $WMIInstance.Softpaq_ID = $item.Solution.Softpaq.id
            $WMIInstance.Softpaq_Name = $item.Solution.Softpaq.Name
            $WMIInstance.Softpaq_Version = $item.Solution.Softpaq.Version
            $WMIInstance.Softpaq_Url = $item.Solution.Softpaq.Url
            $WMIInstance.TargetComponent = $item.TargetComponent
            $WMIInstance.TargetVersion = $item.TargetVersion
            $WMIInstance.ReferenceVersion = $item.ReferenceVersion
            $WMIInstance.Comments = $item.Comments
            $WMIInstance.ID = $ID
            $WMIInstance.Put()
            Clear-Variable -Name WMIInstance
        }
    }
    
    #$ItemName = $item.TargetComponent
    #$CurrentVersion = $item.TargetVersion
    #$ReferenceVersion = $item.ReferenceVersion
    #$DownloadURL = "https://" + $item.Solution.Softpaq.Url