<#
    .Synopsis
        Installs or uninstalls the StifleR Client software with the following steps:
        - Validates system architecture (x64/x86) and selects appropriate MSI
        - Handles service management (stop/start/cleanup)
        - Performs clean installation or upgrade
        - Configures client settings via INI file
        - Provides detailed logging and debugging options
        - Supports command-line parameters for automation

    .REQUIREMENTS
       Must be run from the same folder as the .MSI(s) that you want to install

    .USAGE
       Set the server name etc in the #Optional MSIEXEC params section below

    .PARAMETER Defaults
        Path to the configuration INI file containing default settings for installation

    .PARAMETER Uninstall
        [Boolean] When set to true, uninstalls the StifleR Client
        Default: False

    .PARAMETER FullDebugMode
        [Boolean] Enables detailed debug logging for troubleshooting
        Default: False

    .PARAMETER Logfile
        [String] Path to the log file for installation logging
        Default: C:\Windows\Temp\StifleRInstaller.log

    .PARAMETER EnableSiteDetection
        [Boolean] Enables new features defined in the defaults INI file
        Default: False

    .PARAMETER DebugPreference
        [String] Sets PowerShell debug output preference
        Valid values: "SilentlyContinue", "Continue"
        Default: Not set

   .NOTES
    AUTHOR: 2Pint Software
    EMAIL: support@2pintsoftware.com
    VERSION: 2.2.0.0
    DATE:04/10/2025
    
    CHANGE LOG: 
    See GitHub for full change log
    https://github.com/2pintsoftware/2Pint-StifleR/tree/master/InstallerScripts/Client

   EXAMPLE: .\StifleR_Client_Installer.ps1 -Defaults .\StifleRDefaults.ini -FullDebugMode 1 -ForceVPN 1 -Logfile "C:\Windows\Temp\StifleRInstaller.log" -DebugPreference Continue
   

   .LINK
    https://2pintsoftware.com
#>
param (
    [string]$Defaults,
    [bool] $Uninstall = $false, #set to true for uninstall only
    [bool]$FullDebugMode = $false, #set to $true to turn on all debug logging to the max
    [string]$Logfile = "C:\Windows\Temp\StifleRInstaller.log", # File that script will log to by default
    [bool]$EnableSiteDetection = $false, # Set to $true to turn on any new features (added in the defaults .ini) 
    [Parameter(Mandatory = $false)][ValidateSet("SilentlyContinue", "Continue")][string]$DebugPreference
)
Function TimeStamp { $(Get-Date -UFormat "%D %T ") }
Function Get-IniContent {
    <#
    .Synopsis
        Gets the content of an INI file
        
    .Description
        Gets the content of an INI file and returns it as a hashtable
        
    .Notes
        Author    : Oliver Lipkau <oliver@lipkau.net>
        Blog      : http://oliver.lipkau.net/blog/
        Date      : 2010/03/12
        Version   : 1.0
        
      #>
    
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ (Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini") })]
        [Parameter(ValueFromPipeline = $True, Mandatory = $True)]
        [string]$FilePath
    )
    
    Begin
    { Write-Debug "$($MyInvocation.MyCommand.Name):: Function started" }
        
    Process {
        Write-Debug "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath"
            
        $ini = @{}
        switch -regex -file $FilePath {
            "^\[(.+)\]$" {
                # Section
                $section = $matches[1]
                $ini[$section] = @{}
                $CommentCount = 0
            }
            "^(;.*)$" {
                # Comment
                if (!($section)) {
                    $section = "No-Section"
                    $ini[$section] = @{}
                }
                $value = $matches[1]
                $CommentCount = $CommentCount + 1
                $name = "Comment" + $CommentCount
                # Do not return comments
                # $ini[$section][$name] = $value
            } 
            "^\s*([^#;].+?)=(.*)" {
                # Key
                if (!($section)) {
                    $section = "No-Section"
                    $ini[$section] = @{}
                }
                $name, $value = $matches[1..2]
                $ini[$section][$name] = $value
            }
        }
        Write-Debug "$($MyInvocation.MyCommand.Name):: Finished Processing file: $path"
        Return $ini
    }
        
    End
    { Write-Debug "$($MyInvocation.MyCommand.Name):: Function ended" }
}

function Stop-ServiceWithTimeout ([string] $name, [int] $timeoutSeconds, [switch] $Force) {
    $timespan = New-Object -TypeName System.Timespan -ArgumentList 0, 0, $timeoutSeconds
    $svc = Get-Service -Name $name
    if ($null -eq $svc) { return $false }
    if ($svc.Status -eq [ServiceProcess.ServiceControllerStatus]::Stopped) { return $true }
    
    $svc.Stop()
    $startTime = Get-Date
    $loopCounter = 0
    
    while ((Get-Date) - $startTime -lt $timespan) {
        $svc.Refresh()
        if ($svc.Status -eq [ServiceProcess.ServiceControllerStatus]::Stopped) {
            return $true
        }
        
        if ($loopCounter % 5 -eq 0) {
            Write-Debug "Waiting for Service to stop: $($loopCounter) Seconds Elapsed"
        }
        
        Start-Sleep -Seconds 1
        $loopCounter++
    }
    Write-Debug "Waiting for Service to stop: $($loopCounter) Seconds Elapsed"
 
    if ($Force) {
        Write-Debug "Force stopping service"
        Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 5
        return $true
    }
    else {
        Write-Verbose "Timeout stopping service $($svc.Name)"
    }
    
    return $false
}

function Get-StifleRURLsFromTempInstallConfig {

    # Define the path to the config file
    $configFilePath = "C:\Windows\Temp\StifleR\StifleR.ClientApp.exe.Config"

    # Check if the config file exists
    if (-Not (Test-Path -Path $configFilePath)) {
        Write-Debug "Config file not found at path: $configFilePath"
        return
    }

    # Load the XML content from the config file
    [xml]$configContent = Get-Content -Path $configFilePath

    # Extract the values for StiflerServers and StifleRulezURL
    $stiflerServers = $configContent.configuration.appSettings.add | Where-Object { $_.key -eq "StiflerServers" } | Select-Object -ExpandProperty value
    $stifleRulezURL = $configContent.configuration.appSettings.add | Where-Object { $_.key -eq "StifleRulezURL" } | Select-Object -ExpandProperty value

    # Output the values

    $Output = New-Object -TypeName PSObject
    $Output | Add-Member -MemberType NoteProperty -Name "StiflerServers" -Value "$stiflerServers" -Force
    $Output | Add-Member -MemberType NoteProperty -Name "StifleRulezURL" -Value "$stifleRulezURL"  -Force

    return $Output
}

Write-Debug "Starting Install"
if (!$PSScriptRoot) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
#if the stifler version is 2.7 or higher we need a slightly different evt log query
If (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\StifleRClient"-ErrorAction SilentlyContinue) {
    $ClientAppPath = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\StifleRClient").ImagePath -replace """", ""
    if ($ClientAppPath -eq "C:\Windows\Temp\StifleR\StifleR.ClientApp.exe") { 
        $StifleRClientTempInstallation = $true 
        Write-Debug "`$StifleRClientTempInstallation = $StifleRClientTempInstallation"
    }
    $VerMajor = (Get-Command $ClientAppPath ).FileVersionInfo.FileMajorPart
    $VerMinor = (Get-Command $ClientAppPath ).FileVersionInfo.FileMinorPart
}
Write-Debug "Getting .INI file content"
If (($Uninstall -eq $false) -and (!$Defaults)) {
    Write-Error "No Default .ini file specified - exiting"
    Exit 1
}
If ($Defaults) {
    $FileContent = Get-IniContent $Defaults

    #MSI Defaults
    $INSTALLFOLDER = $FileContent["MSIPARAMS"]["INSTALLFOLDER"]
    $STIFLERSERVERS = $FileContent["MSIPARAMS"]["STIFLERSERVERS"]
    $STIFLERULEZURL = $FileContent["MSIPARAMS"]["STIFLERULEZURL"]
    $DEBUGLOG = $FileContent["MSIPARAMS"]["DEBUGLOG"]
    $RULESTIMER = $FileContent["MSIPARAMS"]["RULESTIMER"]
    $MSILOGFILE = $FileContent["MSIPARAMS"]["MSILOGFILE"]


    #Config defaults from ini file
    $filecontent["CONFIG"].GetEnumerator() | ForEach-Object {
        Write-Debug "Setting Config_$($_.Key) to $($_.Value)"
        Set-Variable -Name "Config_$($_.Key)" -Value $_.Value
    }   

    # Read Prod and PreProd Servers if EnableSiteDetection is set to true
    If ($EnableSiteDetection -eq $true) {
        $EnableSiteDetectionDomain = $FileContent["CUSTOM"]["DOMAIN"]
        Write-Debug "EnableSiteDetectionDomain is set to true and using: $EnableSiteDetectionDomain"
        $ProductionStifleRServers = $FileContent["CUSTOM"]["ProductionStifleRServers"]
        $ProductionStifleRulezUrl = $FileContent["CUSTOM"]["ProductionStifleRulezUrl"]
        $PreProductionStifleRServers = $FileContent["CUSTOM"]["PreProductionStifleRServers"]
        $PreProductionStifleRulezUrl = $FileContent["CUSTOM"]["PreProductionStifleRServers"]
        $ProductionSMSSiteCode = $FileContent["CUSTOM"]["ProductionSMSSiteCode"]

        # ---------------------------
        # BEGIN CUSTOM SITE DETECTION
        # --------------------------- 
        $Domain = (Get-ChildItem env:USERDOMAIN).value

        if ($Domain -eq $EnableSiteDetectionDomain) {
            $Production = $true
            Write-Debug "Production variable set to true"
        }
        Else {
            $Production = $false
            Write-Debug "Production variable set to false"
        } 

        # ---------------------------
        # END CUSTOM SITE DETECTION
        # --------------------------- 

        If ($Production -eq $true) {
            $STIFLERSERVERS = $ProductionStifleRServers 
            $STIFLERULEZURL = $ProductionStifleRulezUrl
        }
        Else {
            $STIFLERSERVERS = $PreProductionStifleRServers
            $STIFLERULEZURL = $PreProductionStifleRulezUrl
        }
        

    }
    try {
        $tsenv = new-object -comobject Microsoft.SMS.TSEnvironment
    }
    catch {
        Write-Debug  "Not in ConfigMgr Task Sequence"
    }
    if ($tsenv){
        $StifleRInfo = Get-StifleRURLsFromTempInstallConfig
        #If no StifleR Config File is found (because it wasn't integrated into WinPE), then fall back to SMSSiteCode using the StifleRDefaults.ini file
        if ($null -eq $StifleRInfo) {
            Write-Debug "No StifleR Info found in Temp Config - Exiting"
            #Gets the SiteCode from the Active TS Environment, the compares to the one in the StifleRDefaults INI file.
            $SiteCode = ($tsenv.Value("_SMSTSPackageID")).substring(0,3)
            #If Matches, it sets to Production
            If ($ProductionSMSSiteCode -eq $SiteCode) {  
                Write-Debug "Production Site Code: $ProductionSMSSiteCode"
                $STIFLERSERVERS = $ProductionStifleRServers
                $STIFLERULEZURL = $ProductionStifleRulezUrl
            }
            #If No Machine, go to Pre-Production URLs
            Else {
                Write-Debug "Pre-Production Site Code: $SiteCode"
                $STIFLERSERVERS = $PreProductionStifleRServers
                $STIFLERULEZURL = $PreProductionStifleRulezUrl
            }
        }
        else{
            #Uses the Servers found in the StifleR Config File WinPE (When StifleR is integrated into WinPE)
            $STIFLERSERVERS = $StifleRInfo.StiflerServers
            $STIFLERULEZURL = $StifleRInfo.StifleRulezURL
        }
    }

    Write-Debug "This script logs to: $Logfile"
    Write-Debug "Installation Folder: $INSTALLFOLDER"
    Write-Debug "StifleR Server(s): $STIFLERSERVERS"
    Write-Debug "StifleR Rules URL: $STIFLERULEZURL"
    Write-Debug "StifleR Debug Level: $DEBUGLOG"
    Write-Debug "StifleR Rules download timer: $RULESTIMER"
    Write-Debug "MSI Logfile: $MSILOGFILE"
    Get-Variable -Name Config_* | ForEach-Object {
        Write-Debug "$($_.Name): $($_.Value)"
    }
}

# Check for elevation (admin rights)
if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Debug "Running elevated - PASS"
}
else {
    Write-Warning "This script needs to be run with admin rights..."
    $(TimeStamp) +  "This script needs to be run with admin rights..." | Out-File -FilePath $Logfile -Append -Encoding ascii
    Exit 1
}

#Check .NET Framework version is 4.6.2 or higher - if not - exit
If ((Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release -ge 394802 -eq $False) {
    Write-Error "This System does not have .NET Framework 4.6.2 or higher installed. Exiting"
    $(TimeStamp) + "This script needs to be run with admin rights..." | Out-File -FilePath $Logfile -Append -Encoding ascii
    Exit 1
}

#----------------------------------------------------------- 
#Setup some variables
#-----------------------------------------------------------
if (!$PSScriptRoot) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
If ($env:PROCESSOR_ARCHITECTURE -eq "x86") { $msifile = "$PSScriptRoot\StifleR.ClientApp.Installer.msi" } 
Else {
    $msifile = "$PSScriptRoot\StifleR.ClientApp.Installer64.msi"
}

$SName = "StifleRClient"
$EventLogName = "StifleR"
$StifleRConfig = "$INSTALLFOLDER\StifleR.ClientApp.exe.Config"
Write-Debug "StifleR app config file: $StifleRConfig" 
Write-Debug "MSI installer File: $msifile"

#-----------------------------------------------------------
#Check if service is marked for deletion and exit if it is
#-----------------------------------------------------------
If (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\StifleRClient"-ErrorAction SilentlyContinue) {
    If ((Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\StifleRClient").DeleteFlag -eq 1 -eq $True) {
        Write-Error "StifleR Client Service is marked for deletion so can't proceed. Exiting"
        $(TimeStamp) + "StifleR Client Service is marked for deletion so can't proceed. Exiting" | Out-File -FilePath $Logfile -Append -Encoding ascii
        Exit 1
    }
}
#----------------------------------------------------------- 
#FUNCTIONS
#-----------------------------------------------------------

Function Uninstall-App ($SearchString) {
    $path = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
                    
    $StifCli = Get-ChildItem $path -ErrorAction SilentlyContinue -Force |
    Get-ItemProperty |
    Where-Object { $_.DisplayName -match $SearchString } |
    Select-Object -Property DisplayName, UninstallString, Displayversion

    ForEach ($ver in $StifCli) {

        If ($ver.UninstallString) {                                
                                    
            $uninstallString = ([string]$ver.UninstallString).ToLower().Replace("/i", "").Replace("msiexec.exe", "")
            $(TimeStamp) + "Uninstalling StifleR Client Version:" + $ver.Displayversion | Out-File -FilePath $Logfile -Append -Encoding ascii
                                    
            start-process "msiexec.exe" -arg "$uninstallString /qn" -Wait 
            Return $True
        }
        Else { Return $False }
    }
}

function New-AppSetting	
([string]$PathToConfig = $(throw 'Configuration file is required'), [string]$Key = $(throw 'No Key Specified'), [string]$Value = $(throw 'No Value Specified')) {
    try {
        $xmlDoc = [xml](Get-Content $PathToConfig)
        $newElement = $xmlDoc.CreateElement("add")
                
        $keyAttribute = $xmlDoc.CreateAttribute("key")
        $keyAttribute.Value = $Key
                
        $valueAttribute = $xmlDoc.CreateAttribute("value")
        $valueAttribute.Value = $Value
                
        $newElement.SetAttributeNode($keyAttribute)
        $newElement.SetAttributeNode($valueAttribute)
                
        $xmlDoc.configuration.appSettings.AppendChild($newElement)
        $xmlDoc.Save($PathToConfig) | Out-Null
    }
    catch {
        Write-Error "Failed to update config file: $_"
    }
}

function Get-AppSetting #returns app settings from the .xml config
([string]$PathToConfig = $(throw 'Configuration file is required')) {
    if (Test-Path $PathToConfig) {
        $xmlDoc = [Xml](Get-Content $PathToConfig)
        $xmlDoc.configuration.appSettings.add
    }
    else {
        throw "Configuration File $PathToConfig Not Found"
    }
}

function Set-AppSetting
    ([string]$PathToConfig = $(throw 'Configuration file is required'),
[string]$Key = $(throw 'No Key Specified'),
[string]$Value = $(throw 'No Value Specified')) {
    if (Test-Path $PathToConfig) {
        $xmlDoc = [xml] (Get-Content $PathToConfig)
        $node = $xmlDoc.configuration.SelectSingleNode("appSettings/add[@key='$Key']") 
        $node.value = $Value
        $xmlDoc.Save($PathToConfig) | Out-Null
    }
}

#----------------------------------------------------------- 
# END Functions
#-----------------------------------------------------------   
If (Test-Path $Logfile) { Remove-Item $Logfile -Force -ErrorAction SilentlyContinue -Confirm:$false } 
else { New-Item -Path $Logfile -ItemType File -Force }

$(TimeStamp) + "Running on: " + $env:PROCESSOR_ARCHITECTURE | Out-File -FilePath $Logfile -Append -Encoding ascii
Write-Debug "Running on:    $env:PROCESSOR_ARCHITECTURE"
#-----------------------------------------------------------
#     Check that we got a valid MSI to install - or exit
#----------------------------------------------------------- 
If (!(Test-Path $msiFile)) {
    $(TimeStamp) + "No MSI file found - Exiting" | Out-File -FilePath $Logfile -Append -Encoding ascii
    write-error " No MSI file found - Exiting"
    Exit 1
}
#-----------------------------------------------------------
#     Check if StifleR Server is installed
#----------------------------------------------------------- 

$IsStifleRServer = ((Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*).DisplayName -Match "Stifler Server").Length -gt 0

$(TimeStamp) + "StifleR Server Installed? =" + $IsStifleRServer | Out-File -FilePath $Logfile -Append -Encoding ascii
Write-Debug "StifleR Server Installed? = $IsStifleRServer"

#-----------------------------------------------------------
#     # Try to get the current path (for backup etc)
#----------------------------------------------------------- 

$svcpath = (Get-CimInstance -ClassName Win32_service -Filter "Name = 'StifleRClient'").PathName

If ($svcpath) {
    $svcpath = (Split-Path -Path $svcpath).Trim('"')
    Write-Debug "Found an existing installation"
    #Then we can get the datapath/DeguglogPath from the .config
    $Configpath = "$svcpath\StifleR.ClientApp.exe.Config"
    $xml = [xml](Get-Content $Configpath)
    $DataPath = ($xml.Configuration.appsettings.add | Where-Object { $_.key -eq "DataPath" }).Value
    If ($datapath.StartsWith("%")) { $datapath = [System.Environment]::ExpandEnvironmentVariables($datapath) }

    $DebugLogPath = ($xml.Configuration.appsettings.add | Where-Object { $_.key -eq "DebugLogPath" }).Value
    If ($DebugLogPath.StartsWith("%")) { $DebugLogPath = [System.Environment]::ExpandEnvironmentVariables($DebugLogPath) }

    #-----------------------------------------------------------
    #        Check for other MSI Installs in progress
    #        and wait for up to 10 mins
    #-----------------------------------------------------------

    $(TimeStamp) + "Checking for other MSI Installs in progress" | Out-File -FilePath $Logfile -Append -Encoding ascii
    Write-Debug "Checking for other MSI Installs in progress"
    $LoopCounter = 0
    $MSIInProgress = $True
    do {
        try {
            $Mutex = [System.Threading.Mutex]::OpenExisting("Global\_MSIExecute");
            $Mutex.Dispose();
            Write-Debug "Another installer is currently running!"
            Write-Debug "sleeping for 5 secs - We have been waiting for $($loopcounter * 5) Seconds"
            start-sleep -seconds 5
            $MSIInProgress = $True
            $LoopCounter++
            If ($loopcounter -eq 120) {
                write-warning "Timeout waiting for MSI Mutex - Exiting"
                Exit 1
            }
        }
        catch {
            Write-Debug "No other MSI running - Continue"
            $(TimeStamp) + "No other MSI running - Continue" | Out-File -FilePath $Logfile -Append -Encoding ascii
            $MSIInProgress = $False
        }
    } until(($MSIInProgress -eq $False) -or $LoopCounter -eq 120)
    # quit after 10 mins
    #-----------------------------------------------------------
    #        END - Check for MSI Installs
    #-----------------------------------------------------------

    #-----------------------------------------------------------
    #        Remove the StifleR Client by running the Uninstall
    #----------------------------------------------------------- 
    #First - Stop the Service as this can cause the uninstall to fail on occasion if it takes too long
    $(TimeStamp) + "Stopping Existing Services" | Out-File -FilePath $Logfile -Append -Encoding ascii
    Write-Debug "Stopping Existing Services"
    
    # Get initial service status
    $Service = Get-Service -Name $Sname -ErrorAction SilentlyContinue
    
    if ($Service.Status -eq 'Stopped') {
        Write-Debug "Service was already stopped"
        $(TimeStamp) + "Service was already stopped" | Out-File -FilePath $Logfile -Append -Encoding ascii
    }
    else {
        $null = Stop-ServiceWithTimeout -name $Sname -timeoutSeconds 60
     
        if ($StifleRClientTempInstallation) {
            $(TimeStamp) + "Client is installed under c:\Windows\Temp there will be no eventlog so waiting some extra time to make sure." | Out-File -FilePath $Logfile -Append -Encoding ascii
            Start-Sleep -Seconds 15
        }
        else {
            $Service = Get-Service -Name $Sname -ErrorAction SilentlyContinue
            if ($Service.Status -eq 'Stopped') {
                $loopcounter = 0
                $TSpan = (Get-Date).AddSeconds(-20).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z")
    
                # Keep existing event log query logic
                if (($vermajor -eq 2) -and ($verminor -ge 7)) {
                    $query = @"
<QueryList>
    <Query Id="0" Path="TwoPintSoftware-StifleR.ClientApp-Program/Operational">
        <Select Path="TwoPintSoftware-StifleR.ClientApp-Program/Operational">
            *[System[(EventID=295) and TimeCreated[@SystemTime&gt;='$TSpan']]]
        </Select>
    </Query>
</QueryList>
"@
                }
                else {
                    $query = @"
<QueryList>
    <Query Id="0" Path="StifleR">
        <Select Path="StifleR">
            *[System[(EventID=0) and TimeCreated[@SystemTime&gt;='$TSpan']]] and 
            *[EventData[Data='Service Shutdown Completed.']]
        </Select>
    </Query>
</QueryList>
"@
                }
                
                do {
                    $evt = Get-WinEvent -FilterXml $query -ErrorAction SilentlyContinue | Select-Object -First 1
                    Write-Debug "Waiting for shutdown event: $loopcounter"
                    Start-Sleep -Seconds 2
                    $loopCounter++
                } until (($evt) -or $loopcounter -eq 15)
    
                if (!$evt) {
                    Write-Error "StifleR Service Stop Timed out - Continue to second check"
                    $(TimeStamp) + "StifleR Service Stop Timed out - Continue to second check" | Out-File -FilePath $Logfile -Append -Encoding ascii
                }
                else {
                    Write-Debug "Shutdown Event detected - safe to continue"
                    $(TimeStamp) + "Shutdown Event detected - safe to continue" | Out-File -FilePath $Logfile -Append -Encoding ascii
                }
            }
            else {
                Write-Error "StifleR Service Stop Timed out - Continue to second check"
                $(TimeStamp) + "StifleR Service Stop Timed out - Continue to second check" | Out-File -FilePath $Logfile -Append -Encoding ascii
            }
        }
    }
    
    # Second check - Stop the service
    $Service = Get-Service -Name $Sname
    Write-Debug "The current state of the service is: $($Service.Status)"
    $(TimeStamp) + "The current state of the service is: $($Service.Status)" | Out-File -FilePath $Logfile -Append -Encoding ascii
    
    if ($Service.Status -eq 'Stopped') {
        Write-Debug "Service is already stopped, continue to next section."
        $(TimeStamp) + "Service is already stopped, continue to next section." | Out-File -FilePath $Logfile -Append -Encoding ascii
    }
    else {
        Write-Debug "Service is running, trying to stop it."
        $(TimeStamp) + "Service is running, trying to stop it." | Out-File -FilePath $Logfile -Append -Encoding ascii
        $null = Stop-ServiceWithTimeout -name $Sname -timeoutSeconds 60 -Force
    }
    
    # Final Check
    $Service = Get-Service -Name $Sname
    if ($Service.Status -eq 'Stopped') {
        Write-Debug "Final Check: Service is already stopped, continue to next section."
        $(TimeStamp) + "Final Check: Service is already stopped, continue to next section." | Out-File -FilePath $Logfile -Append -Encoding ascii
    }
    else {
        Write-Debug "Service could not be stopped, aborting script." 
        $(TimeStamp) + "Service could not be stopped, aborting script." | Out-File -FilePath $Logfile -Append -Encoding ascii
        exit 1
    }

    #-------------------------------------------
    #   END - Service shutdown
    #-------------------------------------------

}
Else {
    Write-Debug "StifleR Service not found, possible new install"
    $(TimeStamp) + "StifleR Service not found, possible new install" | Out-File -FilePath $Logfile -Append -Encoding ascii
}

#-------------------------------------------
#DETECT EXISTING INSTALL(s) AND REMOVE
#-------------------------------------------
$(TimeStamp) + "Checking for existing Installation" | Out-File -FilePath $Logfile -Append -Encoding ascii


If ((Uninstall-App "StifleR Client") -eq $True) {
    $(TimeStamp) + "Successfully removed old version" | Out-File -FilePath $Logfile -Append -Encoding ascii;
    Write-Debug "Successfully removed old version" 

    #-------------------------------------------
    #Remove the Logs and Client data folders
    #-------------------------------------------

    $(TimeStamp) + "Removing Logs folders" | Out-File -FilePath $Logfile -Append -Encoding ascii
    Write-Debug "Removing Logs folders"
    If (Test-Path $DebugLogPath) { Remove-Item $DebugLogPath -Recurse -Force -ErrorAction SilentlyContinue -Confirm:$false }

    $(TimeStamp) + "Removing Client Data folders" | Out-File -FilePath $Logfile -Append -Encoding ascii
    Write-Debug "Removing Client Data folders"
    If (Test-Path $DataPath) { Remove-Item $DataPath -Recurse -Force -ErrorAction SilentlyContinue -Confirm:$false }
    #-------------------------------------------
    #clear the event log if not running on a StifleR Server
    #-------------------------------------------
    If ($IsStifleRServer = "False") {

        $(TimeStamp) + "Removing old event log" | Out-File -FilePath $Logfile -Append -Encoding ascii
        Write-Debug "Removing the old Event log"
        $log = try {
            Get-WinEvent -Log $EventLogName -ErrorAction Stop
        }
        catch [Exception] {
            if ($_.Exception -match "There is not an event log") {
                $(TimeStamp) + "No event log found to remove" | Out-File -FilePath $Logfile -Append -Encoding ascii;
                Write-Debug " No event log found to remove"
            }
        }

        if ($log) { Remove-EventLog -LogName $EventLogName }
        #-------------------------------------------
    } # End Clear evt log
    #-------------------------------------------
    #-------------------------------------------
    #If Uninstall only specified - Exit here
    #-------------------------------------------

    If ($Uninstall -eq $true) {
        Write-Debug "Uninstall Complete - exiting"
        $(TimeStamp) + "Uninstall Complete - exiting" | Out-File -FilePath $Logfile -Append -Encoding ascii;
        Exit 0
    }




}
Else {
    $(TimeStamp) + "Failed to remove old version - or it wasn't installed" | Out-File -FilePath $Logfile -Append -Encoding ascii;
    Write-Debug " Failed to remove old version - or it wasn't installed?"
    If ($Uninstall -eq $true) {
        Write-Debug "Uninstall Complete - exiting"
        $(TimeStamp) + "Uninstall Complete - exiting" | Out-File -FilePath $Logfile -Append -Encoding ascii;
        Exit 0
    } 
}


$(TimeStamp) + "Installing New Version" | Out-File -FilePath $Logfile -Append -Encoding ascii
Write-Debug "Installing New Version"

#-----------------------------------------------------------
#Check if service is marked for deletion and exit if it is
#-----------------------------------------------------------

If (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\StifleRClient"-ErrorAction SilentlyContinue) {
    If ((Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\StifleRClient").DeleteFlag -eq 1 -eq $True) {
        Write-Error "StifleR Client Service is marked for deletion so can't proceed. Exiting"
        $(TimeStamp) + "StifleR Client Service is marked for deletion so can't proceed. Exiting" | Out-File -FilePath $Logfile -Append -Encoding ascii
        Exit 1
    }
}
#-----------------------------------------------------------
#END check for service deletion
#-----------------------------------------------------------


#-----------------------------------------------------------
#        Check for other MSI Installs in progress
#        and wait for up to 10 mins
#-----------------------------------------------------------

$(TimeStamp) + "Checking for other MSI Installs in progress" | Out-File -FilePath $Logfile -Append -Encoding ascii
Write-Debug "Checking for other MSI Installs in progress"
$LoopCounter = 0
$MSIInProgress = $True
do {
    try {
        $Mutex = [System.Threading.Mutex]::OpenExisting("Global\_MSIExecute");
        $Mutex.Dispose();
        Write-Debug "Another installer is currently running!"
        Write-Debug "sleeping for 5 secs - We have been waiting for $($loopcounter * 5) Seconds"
        start-sleep -seconds 5
        $MSIInProgress = $True
        $LoopCounter++
        If ($loopcounter -eq 120) {
            write-warning "Timeout waiting for MSI Mutex - Exiting"
            Exit 1
        }
    }
    catch {
        Write-Debug "Still No other  MSI running - Cleared for takeoff"
        $(TimeStamp) + "Still No other  MSI running - Cleared for takeoff" | Out-File -FilePath $Logfile -Append -Encoding ascii
        $MSIInProgress = $False
    }
} until(($MSIInProgress -eq $False) -or $LoopCounter -eq 120)
#quit after 10 mins
#-----------------------------------------------------------
#        END - Check for MSI Installs
#-----------------------------------------------------------


$msiArgumentList = @(
    #--------------------------------
    #Mandatory msiexec Arguments - DO NOT CHANGE
    #--------------------------------

    "/i"

    "`"$msiFile`""

    #--------------------------------
    #Optional MSIEXEC params
    #--------------------------------
    "/qn" #Quiet - /qb with basic interface - for NO interface use /qn instead

    # "/norestart"

    "/l*v `"$MSILOGFILE`""    #Optional logging for the MSI install

    "INSTALLFOLDER=`"$INSTALLFOLDER`""

    "DEBUGLOG=`"$DEBUGLOG`"" #Set to 1-6 to enable logging

    "STIFLERSERVERS=`"$STIFLERSERVERS`"" 

    "STIFLERULEZURL=`"$STIFLERULEZURL`"" 

    "UPDATERULESTIMERINSEC=$RULESTIMER" 

    #--------------------------------
    #END Optional MSIEXEC params
    #--------------------------------
)

write-Debug "MSI Cmd line Arguments: $arguments" 
write-Debug "$msiArgumentList" 
#--------------------------------
#Execute the Install
#--------------------------------

$return = Start-Process msiexec -ArgumentList $msiArgumentList -Wait -passthru
If (@(0, 3010) -contains $return.exitcode) {

    #--------------------------------
    #Update the log before we do any .config edits
    #--------------------------------

    $path = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
                    
    $StifCli = Get-ChildItem $path -ErrorAction SilentlyContinue -Force |
    Get-ItemProperty |
    Where-Object { $_.DisplayName -match "StifleR Client" } |
    Select-Object -Property DisplayName, UninstallString, Displayversion

    ForEach ($ver in $StifCli) {                  
        $(TimeStamp) + "Installed StifleR Client Version:" + $ver.Displayversion | Out-File -FilePath $Logfile -Append -Encoding ascii
        Write-Debug "Installed StifleR Client Version: $($ver.Displayversion)"
    }
}# END MSI Install

else {
    $(TimeStamp) + "MSI failed with Error" + $return.exitcode | Out-File -FilePath $Logfile -Append -Encoding ascii
    Write-Error "MSI install failed with Error  $($return.exitcode) "
    Exit 1
}

#Finally, edit the .Config with any custom VPNStrings or debug settings
#First we need to stop the service
#if we updated any VPN stuff we will restart so that the connection can be updated with that info
If (((Get-Variable -Name "Config_*").Value) -or ($EnableBetaFeatures -eq $true) -or ($FullDebugMode -eq $true)) {
    Write-Debug "Sleeping 30 secs please wait..."
    $(TimeStamp) + "Sleeping 30 secs please wait...:" | Out-File -FilePath $Logfile -Append -Encoding ascii
    Start-Sleep -s 30 #wait for 30 secs to let the svc start correctly before restarting
    Write-Debug "Stopping the service for .config file changes"
    $(TimeStamp) + "Stopping the service for .config file changes:" | Out-File -FilePath $Logfile -Append -Encoding ascii

    #----------------------------------------------------------
    #       Attempt to stop the StifleRClient service
    #----------------------------------------------------------
    #get the current svc state
    $Service = Get-Service -Name $Sname -ErrorAction SilentlyContinue

    if ($Service.Status -eq 'Stopped') {
        Write-Debug "Service was already stopped"
        $(TimeStamp) + "Service was already stopped" | Out-File -FilePath $Logfile -Append -Encoding ascii
    }
    else {
        Stop-Service -Name $Sname -Force -ErrorAction SilentlyContinue
        $loopcounter = 0
        do { 
            $Service = Get-Service -Name $Sname
            Write-Debug "Waiting for Service to stop: $($loopcounter * 5) Seconds Elapsed"
            $(TimeStamp) + "Waiting for Service to stop: $($loopcounter * 5) Seconds Elapsed" | Out-File -FilePath $Logfile -Append -Encoding ascii
            Write-Debug "Service Status: $($Service.Status)"
            Start-Sleep -Seconds 5
            $loopCounter++
        } until ($Service.Status -eq 'Stopped' -or $loopcounter -eq 12)
    
        if ($Service.Status -eq 'Stopped') {
            $loopcounter = 0
            $TSpan = (Get-Date).AddSeconds(-20).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z")
            
            if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\StifleRClient" -ErrorAction SilentlyContinue) {
                $VerMajor = (Get-Command 'C:\Program Files\2Pint Software\StifleR Client\stifler.clientapp.exe').FileVersionInfo.FileMajorPart
                $VerMinor = (Get-Command 'C:\Program Files\2Pint Software\StifleR Client\stifler.clientapp.exe').FileVersionInfo.FileMinorPart
            }
    
            if (($vermajor -eq 2) -and ($verminor -ge 7)) {
                $query = @"
<QueryList>
    <Query Id="0" Path="TwoPintSoftware-StifleR.ClientApp-Program/Operational">
        <Select Path="TwoPintSoftware-StifleR.ClientApp-Program/Operational">
            *[System[(EventID=295) and TimeCreated[@SystemTime&gt;='$TSpan']]]
        </Select>
    </Query>
</QueryList>
"@
            }
            else {
                $query = @"
<QueryList>
    <Query Id="0" Path="StifleR">
        <Select Path="StifleR">
            *[System[(EventID=0) and TimeCreated[@SystemTime&gt;='$TSpan']]] and 
            *[EventData[Data='Service Shutdown Completed.']]
        </Select>
    </Query>
</QueryList>
"@
            }
            
            do {
                $evt = Get-WinEvent -FilterXml $query -ErrorAction SilentlyContinue | Select-Object -First 1
                Write-Debug "Waiting for shutdown event: $loopcounter"
                Start-Sleep -Seconds 2
                $loopCounter++
            } until (($evt) -or $loopcounter -eq 15)
    
            if (!$evt) {
                Write-Error "StifleR Service Stop Timed out - Exiting"
                $(TimeStamp) + "StifleR Service Stop Timed out - Exiting" | Out-File -FilePath $Logfile -Append -Encoding ascii
                Exit 1
            }
            else {
                Write-Debug "Shutdown Event detected - safe to continue"
                $(TimeStamp) + "Shutdown Event detected - safe to continue" | Out-File -FilePath $Logfile -Append -Encoding ascii
            }
        }
        else {
            Write-Error "StifleR Service Stop Timed out - Exiting"
            $(TimeStamp) + "StifleR Service Stop Timed out - Exiting" | Out-File -FilePath $Logfile -Append -Encoding ascii
            Exit 1
        }
    }
    #-------------------------------------------
    #   END - Service shutdown
    #-------------------------------------------

    #Backup the .config file before we fiddle with it
    $xml = $null
    $StiflerConfigItems = 0
    $xml = [xml](Get-Content $StifleRConfig -ErrorAction SilentlyContinue)
    $StiflerConfigItems = ($xml.Configuration.appsettings.add ).count

    write-debug "Number of Config Items in the App Config is $StiflerConfigItems"

    #backup the .config XML
    $svcpath = (Get-CimInstance -ClassName Win32_service -Filter "Name = 'StifleRClient'").PathName
    If ($svcpath) { $svcpath = (Split-Path -Path $svcpath).Trim('"') }
    If (Test-Path $svcpath\StifleR.ClientApp.exe.Config) { copy-item $svcpath\StifleR.ClientApp.exe.Config C:\Windows\temp\StifleRConfigdata.bak -Force }


    Try {
        $error.clear()
        #Edits the Stifler App.Config XML

        Foreach ($configItem in Get-Variable -Name "Config_*") {
            If ($configItem.Value) { 
                if ((Get-Appsetting $StifleRConfig | Where-Object { $_.key -eq $(($configItem.Name -split "_")[1]) }).key) {
                    Set-AppSetting $StifleRConfig "$(($configItem.Name -split "_")[1])" "$($configItem.Value)" | Out-Null   
                    Write-Debug "Setting custom $(($configItem.Name -split "_")[1]) = $($configItem.Value) to the app config"
                    $(TimeStamp) + "Setting custom $(($configItem.Name -split "_")[1]) = $($configItem.Value) to the app config:" | Out-File -FilePath $Logfile -Append -Encoding ascii
                }
                else {
                    New-AppSetting $StifleRConfig "$(($configItem.Name -split "_")[1])" "$($configItem.Value)" | Out-Null      
                    Write-Debug "Adding custom $(($configItem.Name -split "_")[1]) = $($configItem.Value) to the app config"
                    $(TimeStamp) + "Adding custom $(($configItem.Name -split "_")[1]) = $($configItem.Value) to the app config:" | Out-File -FilePath $Logfile -Append -Encoding ascii
                }
            }   
        }

        #enable all debug logging if that switch is $true
        If ($FullDebugMode -eq $true) {
            $xml = [xml](Get-Content $StifleRConfig)
            Write-Debug "Enabling all debug options in the app config"
            $(TimeStamp) + "Enabling all debug options in the app config:" | Out-File -FilePath $Logfile -Append -Encoding ascii
            $node2 = $xml.Configuration.appsettings.add | Where-Object { $_.key -eq "EnableDebugLog" }
            $node2.Value = "6"
            $node3 = $xml.Configuration.appsettings.add | Where-Object { $_.key -eq "EnableDebugTelemetry" }
            $node3.Value = "1"
            $node4 = $xml.Configuration.appsettings.add | Where-Object { $_.key -eq "SignalRLogging" }
            $node4.Value = "1"
            $xml.Save($StifleRConfig) #save the config

        }




        Write-Debug "Updated and saved the App.Config"
        $(TimeStamp) + "Updated and saved the App.Config:" | Out-File -FilePath $Logfile -Append -Encoding ascii
        #pause for debug if required
        # [void](Read-Host 'Press Enter to continue.')
    }
    Catch {
        $(TimeStamp) + "Failed to edit the StifleR.Config:" + $_.Exception | Out-File -FilePath $Logfile -Append -Encoding ascii
        Write-Error "Failed to Configure the App.Config"
        Write-Error $_.Exception 
        throw  $_.Exception
        Exit 1
    }

    #If we made it to here - we just need to restart the service
    #----------------------------------------------------------
    #       Attempt to start the StifleRClient service
    #----------------------------------------------------------
    $(TimeStamp) + "Service Startup" | Out-File -FilePath $Logfile -Append -Encoding ascii

    # Get initial service status
    $Service = Get-Service -Name $Sname -ErrorAction SilentlyContinue
    
    if ($Service.Status -eq 'Running') {
        $(TimeStamp) + "Service was already started" | Out-File -FilePath $Logfile -Append -Encoding ascii
        Write-Debug "Service was already started"
        Exit 0
    }
    else {
        Start-Service -Name $Sname -ErrorAction SilentlyContinue | Out-File -FilePath $Logfile -Append -Encoding ascii
    }
    
    # Wait for service to start
    $loopcounter = 0
    do {
        $Service = Get-Service -Name $Sname
        Write-Debug "Waiting for Service to start: $($loopcounter * 2) Seconds Elapsed"
        $(TimeStamp) + "Waiting for Service to start: $($loopcounter * 2) Seconds Elapsed" | Out-File -FilePath $Logfile -Append -Encoding ascii
        Write-Debug "Service Status: $($Service.Status)"
        Start-Sleep -Seconds 2
        $loopcounter++
    } until ($Service.Status -eq 'Running' -or $loopcounter -eq 15)
    
    if ($Service.Status -eq 'Running') {
        Write-Debug "StifleR Client service started - Install Completed"
        $(TimeStamp) + "StifleR Client service started - Install Completed" | Out-File -FilePath $Logfile -Append -Encoding ascii
    }
    else {
        Write-Warning "StifleR Service Start Timed out - Retry"
        $(TimeStamp) + "StifleR Service Start Timed out - Retry" | Out-File -FilePath $Logfile -Append -Encoding ascii
    
        try {
            Start-Service -Name $Sname -ErrorAction Stop
        }
        catch {
            try {
                # Try to load the XML and if it throws an error we will assume it's corrupt
                $xml = $null
                $StiflerConfigItems = 0
                $xml = [xml](Get-Content $StifleRConfig -ErrorAction SilentlyContinue)
                $StiflerConfigItems = ($xml.Configuration.appsettings.add).count
                Write-Debug "Number of config items in the App Config is:$StiflerConfigItems"
                $(TimeStamp) + "Number of config items in the App Config is:$StiflerConfigItems" | Out-File -FilePath $Logfile -Append -Encoding ascii
            }
            catch {
                # Restore the .config in case it was corrupted
                Write-Warning "Number of config items in the App Config is:$StiflerConfigItems"
                $(TimeStamp) + "Number of config items in the App Config is:$StiflerConfigItems" | Out-File -FilePath $Logfile -Append -Encoding ascii
                Write-Warning "Looks like the config XML is corrupt - restoring"
                $(TimeStamp) + "Looks like the config XML is corrupt - restoring" | Out-File -FilePath $Logfile -Append -Encoding ascii
                
                if (Test-Path C:\Windows\temp\StifleRConfigdata.bak) {
                    Copy-Item C:\Windows\temp\StifleRConfigdata.bak $svcpath\StifleR.ClientApp.exe.Config -Force
                }
                
                $xml = $null
                $StiflerConfigItems = 0
                $xml = [xml](Get-Content $StifleRConfig -ErrorAction SilentlyContinue)
                $StiflerConfigItems = ($xml.Configuration.appsettings.add).count
                Write-Debug "Number of config items in the App Config is now:$StiflerConfigItems"
                $(TimeStamp) + "Number of config items in the App Config is now:$StiflerConfigItems" | Out-File -FilePath $Logfile -Append -Encoding ascii
                Write-Debug "Will attempt to start the service again"
                $(TimeStamp) + "Will attempt to start the service again" | Out-File -FilePath $Logfile -Append -Encoding ascii
                
                if ($StiflerConfigItems -ge 35) {
                    # Don't restart for now - early testing
                    # Start-Service -Name $Sname -ErrorAction SilentlyContinue
                }
            }
        }
    
        Write-Warning "Exiting with an error as the .config edit failed"
        $(TimeStamp) + "Exiting with an error as the .config edit failed" | Out-File -FilePath $Logfile -Append -Encoding ascii
        Write-Debug "Service status is: $($Service.Status)"
        $(TimeStamp) + "Service status is: $($Service.Status)" | Out-File -FilePath $Logfile -Append -Encoding ascii
    
        Exit 1
    }
}
#--------------------------------
#Install Stifler ETW - REMOVED as client installs ETW by default
#--------------------------------


write-debug "Exiting - install complete"
$(TimeStamp) + "Exiting - install complete" | Out-File -FilePath $Logfile -Append -Encoding ascii
Exit 0
                                  
#--------------------------------
#END
#--------------------------------
