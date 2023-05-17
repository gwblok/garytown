<#Notes: 
        Assumptions:
         !!Your Source folder has a subfolder called 3rdPartyTools with PsExec & Explorer++ in them... if you don't you'll need to Remove some lines in the script.

        This Assumes you have Enterprise & The Enterprise Server... I'll have a Difference Script Created for Enterprise Standalone & Community Tools
        
        Logs Script to "C:\ProgramData\Recast Software\RecastRCT_AppModel_Installer.log"
         
        Configuration Items Not Currenlty Modified via this Script (You can still modify them in your custom configuration.xml that is copied during intial load.
            General Tab
            Tools List
                  
        Configuration Items you can Modify
            Interactive Command Prompt (Replace a Blank Value with your custom value, not currently setup to replace if already set)
              Defaults it to C:\ProgramData\Recast Software\3rdPartyTools\PsExec.exe
            Alternate Explorer Tab (Replace a Blank Value with your custom value, not currently setup to replace if already set)
              Defaults it to C:\ProgramData\Recast Software\3rdPartyTools\Explorer++.exe
            System Information Tab (Modify any of the settings to enable them to show or not show in the System Information Action Tool)
         
        Created by Gary Blok (@gwblok)  Hit me up on Twitter if you have Questions.
#>


$RecastProgData = "C:\ProgramData\Recast Software"
$LogFile = "$RecastProgData\RecastRCT_AppModel_Installer.log"
#if (Test-Path $LogFile){remove-item $LogFile -Force}  #Useful when testing.. clears out log before each run

#Get RCT Installer MSI Info
$Installer = "$($PSScriptRoot)\$((Get-ChildItem $PSScriptRoot\*.msi).Name)"
$InstallerVersion = $Installer.Split("-")[1]

#region: CMTraceLog Function formats logging in CMTrace style
function CMTraceLog {
Param (
		[Parameter(Mandatory=$false)]
		$Message,
 
		[Parameter(Mandatory=$false)]
		$ErrorMessage,
 
		[Parameter(Mandatory=$false)]
		$Component = "RecastRCT-$InstallerVersion",
 
		[Parameter(Mandatory=$false)]
		[int]$Type,
		
		[Parameter(Mandatory=$true)]
		$LogFile
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


CMTraceLog -Message "Starting Recast Right Click Tools AppModel Deployment Script" -Type 2 -LogFile $LogFile
CMTraceLog -Message "Installer: $Installer" -Type 1 -LogFile $LogFile

#Run the Installer:  
CMTraceLog -Message "Starting Command: msiexec.exe /I ""$($installer)"" RCTENTERPRISESERVER=https://recastms.corp.viamonstra.com:444 /passive" -Type 1 -LogFile $LogFile
$InstallProcess = Start-Process msiexec.exe -Wait -ArgumentList "/I ""$($installer)"" RCTENTERPRISESERVER=https://recastms.corp.viamonstra.com:444 /passive" -Passthru

<#Uninstall for Testing
$UninstallProcess = Start-Process msiexec.exe -Wait -ArgumentList "/X ""$($installer)"" /passive" -Passthru

#>

if ($InstallProcess.ExitCode -eq "0")
    {
    CMTraceLog -Message "Recast Right Click Tools Successfully Installed, continue Script" -Type 1 -LogFile $LogFile
    #OPTINAL COPY OF 3rd Party Tools (Must be downloaded and in your source directory in a subfolder called 3rdPartyTools)
        #Setup 3rd Party Tools Dir in Recast ProgramData
        $RecastProgData = "C:\ProgramData\Recast Software"
        $Recast3rdParty = "$RecastProgData\3rdPartyTools"
        if (!(Test-Path -Path $Recast3rdParty))
            {
            New-Item -Path $RecastProgData  -Name "3rdPartyTools" -ItemType Directory -ErrorAction SilentlyContinue
            CMTraceLog -Message "New Folder $RecastProgData\3rdPartyTools created" -Type 1 -LogFile $LogFile
            }


        #Copy PsExec to C:\ProgramData\Recast Software\3rdPartyTools
        $SourcePsExec = "$PSScriptRoot\3rdPartyTools\PsExec.exe"
        if (Test-Path $Recast3rdParty)
            {
            Copy-Item -Path $SourcePsExec -Destination $Recast3rdParty -Verbose -Force
            CMTraceLog -Message "$SourcePsExec to $Recast3rdParty" -Type 1 -LogFile $LogFile
            }

        #Copy Explorer++ to C:\ProgramData\Recast Software\3rdPartyTools
        $SourceExplorer = "$PSScriptRoot\3rdPartyTools\Explorer++.exe"
        if (Test-Path $Recast3rdParty)
            {
            Copy-Item -Path $SourceExplorer -Destination $Recast3rdParty -Verbose -Force
            CMTraceLog -Message "$SourceExplorer to $Recast3rdParty" -Type 1 -LogFile $LogFile
            }


    #Copy / Update RCT Config File
    $SourceConfig = "$PSScriptRoot\configuration.xml"

    #Gets all of the User Profiles currently on the machine
    $DestinationParent = 'C:\users\*\AppData\Roaming\'

    #Create the RecastRCT Folder in each user Profile's "Appdata"
    New-Item -Path $DestinationParent -Name "RecastRCT" -ItemType Directory -ErrorAction SilentlyContinue
    
    #Get all of the RecastRCT Folders in all Profiles
    $DestinationRecastRCT = "$DestinationParent\RecastRCT"
    $RecastRCTDIRs = Get-ChildItem $DestinationRecastRCT

    #ForEach Profile, copy or update the Recast RCT Config File.
    ForEach ($RecastRCTDir in $RecastRCTDIRs)
        {
        CMTraceLog -Message " " -Type 1 -LogFile $LogFile
        CMTraceLog -Message "Starting Update to $RecastRCTDir" -Type 1 -LogFile $LogFile
        
        #IF No config File, Copy the one into place
        if (!(Test-Path -Path "$RecastRCTDir\configuration.xml"))
            {
            Copy-Item -Path $SourceConfig -Destination $RecastRCTDir -Verbose
            CMTraceLog -Message " $SourceConfig to $RecastRCTDir" -Type 1 -LogFile $LogFile
            }
        #Else if there is a COnfigFile, Set Custom Settings
        else
            {
        
            #Configure the "Interactive Command Prompt" Tab (PsExec) - Simple Replace of the String if currently Null.  THis will NOT Change the setting if already set on a machine.
            if (Test-Path "$Recast3rdParty\PsExec.exe")
                {
                ((Get-Content -path "$RecastRCTDir\configuration.xml" -Raw) -replace '<PsExecPath i:nil="true"/>',"<PsExecPath>$($Recast3rdParty)\PsExec.exe</PsExecPath>") | Set-Content -Path "$RecastRCTDir\configuration.xml"
                CMTraceLog -Message " Set Interactive Command Prompt to $Recast3rdParty\PsExec.exe" -Type 1 -LogFile $LogFile
                }      

            #Configure the "Alternate Explorer" Tab (PsExec) - Simple Replace of the String if currently Null.  THis will NOT Change the setting if already set on a machine.
            if (Test-Path "$Recast3rdParty\Explorer++.exe")
                {
                ((Get-Content -path "$RecastRCTDir\configuration.xml" -Raw) -replace '<AlternateExplorerPath i:nil="true"/>',"<AlternateExplorerPath>$($Recast3rdParty)\Explorer++.exe</AlternateExplorerPath>") | Set-Content -Path "$RecastRCTDir\configuration.xml"
                CMTraceLog -Message " Set Alternate Explorer to $Recast3rdParty\Explorer++.exe" -Type 1 -LogFile $LogFile
                }      

        
            #Modifty the settings in the Config File (These will Modify User Settings if already Set and change to what you specify below)
            #Load the XML File
            [XML]$XML = Get-Content "$RecastRCTDir\configuration.xml"
        
            #Recast Configuration Settings for the System Information Area
                CMTraceLog -Message " Starting to Update System Information Tab" -Type 1 -LogFile $LogFile
                #Get the CacheSize Setting & Set to True
                $CacheSizeValue = $XML.Settings.SystemInformationSettings.items.'KeyValueOfstringSystemInformationSettings.VisibleIndexPairpdLyUujP' | ?{$PSItem.Key -eq 'CacheSize'}
                $CacheSizeValue.Value.Visible = "true"
                CMTraceLog -Message "  Set CacheSize to True" -Type 1 -LogFile $LogFile

                #Get the CacheAvailableSize Setting & Set to True
                $CacheAvailableSizeValue = $XML.Settings.SystemInformationSettings.items.'KeyValueOfstringSystemInformationSettings.VisibleIndexPairpdLyUujP' | ?{$PSItem.Key -eq 'CacheAvailableSize'}
                $CacheAvailableSizeValue.Value.Visible = "true"
                CMTraceLog -Message "  Set CacheAvailableSize to True" -Type 1 -LogFile $LogFile
                
                #Get the Domain Setting & Set to True
                $DomainValue = $XML.Settings.SystemInformationSettings.items.'KeyValueOfstringSystemInformationSettings.VisibleIndexPairpdLyUujP' | ?{$PSItem.Key -eq 'Domain'}
                $DomainValue.Value.Visible = "true"
                CMTraceLog -Message "  Set Domain to True" -Type 1 -LogFile $LogFile

                #Get the LastHardwareInventoryCycle Setting & Set to True
                $LastHardwareInventoryCycleValue = $XML.Settings.SystemInformationSettings.items.'KeyValueOfstringSystemInformationSettings.VisibleIndexPairpdLyUujP' | ?{$PSItem.Key -eq 'LastHardwareInventoryCycle'}
                $LastHardwareInventoryCycleValue.Value.Visible = "true"
                CMTraceLog -Message "  Set LastHardwareInventoryCycle to True" -Type 1 -LogFile $LogFile

                <# Other SYSTEM INFORMATION Settings as of 4.0
        
                To Change a Setting Copy this Code & Change the String: SettingName in the 3 places (Like Example above for CacheSize)
                    $SettingNameValue = $XML.Settings.SystemInformationSettings.items.'KeyValueOfstringSystemInformationSettings.VisibleIndexPairpdLyUujP' | ?{$PSItem.Key -eq 'SettingName'}
                    $SettingNameValue.Value.Visible = "true"
                    CMTraceLog -Message "  Set SettingNameValue to True" -Type 1 -LogFile $LogFile
        
                #Default is set to True
                    #ComputerName       :Device Name, should show up in FQDN format
                    #OnOff              :Machine Status, Or or Off
                    #ConsoleUser        :Current User logged onto the Console Session (NOT RDP Users)
                    #LastRestartTime    :Last Time the Machine was Restared (Turned ON)
                    #PendingRestart     :Is the Machine Pending a Reboot (Due to Updates etc)
                    #Model              :Computers Model (Latitude E7450, Virtual Machine, HP 840 G3)
                    #OperatingSystem    :Microsoft Windows Version (Microsoft WIndows 10 Enterprise)

                #Default is set to False
                    #CacheAvailablePercent               :This is the % of the CM Cache that is still available to be used (CCMCache Size - CCMCache Used in % form)"             
                    #CacheAvailableSize                  :This is the amount of "Free Space" in MB that is unsued in your CM Cache (CCMCache Size - CCMCache Used)
                    #CachePath                           :Location of your CCMCache Folder, will typically always be c:\windows\ccmache, if not, you might want to look into it.
                    #CacheUsedPercent                    :This is the % of your CM Cache that is used
                    #CacheUsedSize                       :This is the amount of storage used in your CCMCache in MB
                    #ClientVersion                       :ConfigMgr Client Version.  More info: https://www.systemcenterdudes.com/sccm-2012-version-numbers/
                    #Domain                              :Computer's Domain in FQDN format
                    #IpAddress                           :Computer's IP Address
                    #LastHardwareInventoryCycle          :Last time the Computer ran a Hardware Inventory Cycle
                    #LastHardwareInventoryReport         :Last time the Computer ran a Hardware Inventory Report
                    #LastSoftwareInventoryScanCycle      :Last time the Computer ran a Software Inventory Report
                    #LastSoftwareInventoryReport         :Last time the Computer ran a Software Inventory Report
                    #MacAddress                          :List of MAC Address for Computer
                    #SiteCode                            :Computers ConfigMgr Site Code (Useful in large environments when you have several site codes)
                #>
            #Save the XML File
            $xml.Save("$RecastRCTDir\configuration.xml")
            CMTraceLog -Message "Finished updating Configuration.xml File" -Type 1 -LogFile $LogFile
            }
        }
        CMTraceLog -Message "Finished With Installing Recast Right Click Tools" -Type 2 -LogFile $LogFile
    }
Else
    {CMTraceLog -Message "Recast Right Click Tools Failed Installing with Exitcode: $($InstallProcess).exitcode " -Type 3 -LogFile $LogFile}
