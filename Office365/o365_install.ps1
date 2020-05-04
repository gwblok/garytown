<#Office 365 Installer Script
Mike Terrill & Gary Blok

CM App DT Program (PreCache App): powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\o365_Install.ps1 -precache -Channel Broad
 - Deployed to office 365 User Collection as Required ASAP HIDDEN! Not shown in Software Center
CM App DT Program (Install App): powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\o365_Install.ps1 -Channel Broad -CompanyValue GARYTOWN
 - App DT has Requirement of Office PreCache App
 - Deployed to office 365 User Collection as Available ASAP Shown in Software Center  

CM App DT Program (Install App): powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\o365_Install.ps1 -Access -Channel Broad -CompanyValue GARYTOWN
CM App DT Program (Install App): powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\o365_Install.ps1 -ProjectPro -Channel Broad -CompanyValue 'Big Bank'
CM App DT Program (Install App): powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\o365_Install.ps1 -ProjectStd -Channel Broad -CompanyValue AZSMUG
CM App DT Program (Install App): powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\o365_Install.ps1 -VisioPro -Channel Broad -CompanyValue MIKETERRILL.COM
CM App DT Program (Install App): powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\o365_Install.ps1 -VisioStd -Channel Broad -CompanyValue 'Recast Software'



CM App DT User Experience: Install for System, Whether or Not, Normal, NO CHECK on Allow users to view and interact, Determine behavior based on return codes.

Based on Params or Previously Installed Access / Visio / Project, it will install those along with the Base.
Copies the Installer Media to Cache location (HARD LINKS) and installs from there.


Notes:
Semi Annual Channel = Broad
Semi Annual Channel Targeted = Targeted


CHANGE LOG:
2020.04.07 - Added Exit Code 3010 if Office 2016 previously installed (added detection for previous installed, using $2016)
2020.04.07 - Changed "FORCEAPPSHUTDOWN" from TRUE to FALSE
2020.04.08 - Changed "FORCEAPPSHUTDOWN" from FALSE to TRUE because it hangs the installer if a user doesn't close apps, even at deadline.
2020.04.09 - Added Logging, Having issues with Exit Codes
2020.04.10 - Added Logging for if a user cancels, notes that in log.
2020.04.21 - Added logic to detect if Access was installed with 365 to make sure it doesn't get removed when you install Visio or Projects
2020.04.22 - Added additional logging around Access
2020.04.23 - Force PowerShell to run in 64-bit mode 
2020.04.24 - Added options for installing Visio Standard & Project Standard from commandline ($VisioStd & $ProjectStd)
2020.04.24 - Renamed $Project to $ProjectPro & $Visio to $VisioPro
2020.04.27 - Changed Method for Deployment
 - Now PreCache will be a separate Application, and will contain the installer bits.  It will be a pre-req for 
 - Install Script is now it's own Application.  Content = 3 scripts, nothing more. It leverages the c:\programdata\o365_cache folder that is setup in PreCache
2020.04.27 - Added logging for PreCache Process
2020.05.01 - Updated script to allow the ability to switch from Visio / Project Pro to Standard and vs Versa.
 - Added "Removal XML section which will automatically add the <remove> section of XML if you want to switch from Std to Pro or otherwise.
2020.05.01 - Added Param for Company Name ($CompanyValue)

 - Note, 
#>
[CmdletBinding(DefaultParameterSetName="Office Options")] 
param (
        [Parameter(Mandatory=$false, ParameterSetName='PreCache')][switch]$PreCache,

        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $Access,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $ProjectPro,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $VisioPro,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $ProjectStd,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $VisioStd,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][ValidateSet("Monthly", "Broad", "Targeted")][string]$Channel,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$CompanyValue
    ) 

#############################################################################
#If Powershell is running the 32-bit version on a 64-bit machine, we 
#need to force powershell to run in 64-bit mode .
#############################################################################
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    write-warning "Y'arg Matey, we're off to 64-bit land....."
    if ($myInvocation.Line) {
        &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile $myInvocation.Line
    }else{
        &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -file "$($myInvocation.InvocationName)" $args
    }
exit $lastexitcode
}


$SourceDir = Get-Location
$O365Cache = "C:\ProgramData\O365_Cache"
$ScriptVer = "2020.04.27.1"

#region: CMTraceLog Function formats logging in CMTrace style
        function Write-CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "Office365",
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$false)]
		    $LogFile = "C:\Windows\Temp\Office365_Install.log"
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

#Used to set Exit Code in way that CM registers
function ExitWithCode
{
    param
    (
        $exitcode
    )

    $host.SetShouldExit($exitcode)
    exit
}

Write-CMTraceLog -Message "=====================================================" -Type 1 -Component "o365script"
Write-CMTraceLog -Message "Starting Script version $ScriptVer..." -Type 1 -Component "o365script"
Write-CMTraceLog -Message "=====================================================" -Type 1 -Component "o365script"



#Get Currently Installed Office Apps
If (-not $Precache) {
    Write-CMTraceLog -Message "Running Script in Install Mode" -Type 1 -Component "o365script"
    #$Edge = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Edge'"
    $2016 = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Office Professional Plus 2016'"
    $O365 = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Office 365 ProPlus%'"
    $A = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Access 20%'"
    If (-not $ProjectStd) {$PP = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Project Professional%'"}
    If (-not $ProjectPro) {$PS = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Project Standard%'"}
    If (-not $VisioStd) {$VP = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Visio Professional%'"}
    If (-not $VisioPro) {$VS = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Visio Standard%'"}

    #If Office 365 is already installed, grab the Channel it is using to apply to the additional installs.
    if ($O365)
        {
        Write-CMTraceLog -Message "Detected Office 365 Already Installed" -Type 1 -Component "o365script"
        $Configuration = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
 
        $CurrentChannel = (Get-ItemProperty $Configuration).CDNBaseUrl
        $Insiders = "http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be"
        $Monthly = "http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60"
        $Targeted = "http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf"
        $Broad = "http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114"
        if ($CurrentChannel -eq $Insiders){$Channel = "Insiders"}
        if ($CurrentChannel -eq $Monthly){$Channel = "Monthly"}
        if ($CurrentChannel -eq $Targeted){$Channel = "Targeted"}
        if ($CurrentChannel -eq $Broad){$Channel = "Broad"}
        Write-CMTraceLog -Message "Current Office 365 Channel = $Channel" -Type 1 -Component "o365script"

        if (Test-Path -Path "$env:ProgramFiles\Microsoft Office\root\Office16\MSACCESS.EXE")
            {
            $A = $true
            Write-CMTraceLog -Message "Found Access Already Installed" -Type 1 -Component "o365script"
            }
        }
    }

If ($Precache) {
    Write-CMTraceLog -Message "Running Script in PreCache Mode" -Type 1 -Component "o365_PreCache"
    If (-not (Test-Path $O365Cache)) {
        try {
            New-Item -Path $O365Cache -ItemType Directory -ErrorAction Stop | Out-Null
            }
        catch {
            #Write-Error -Message "Unable to create '$O365Cache'. Error was: $_" -ErrorAction Stop
        }
        #Write-Output "Successfully created directory '$O365Cache'."
        Write-CMTraceLog -Message "Successfully created directory '$O365Cache'." -Type 1 -Component "o365_PreCache"
    }

    If (Test-Path "$O365Cache\*") {
        Remove-Item -Recurse -Force "$O365Cache\*"
        Write-CMTraceLog -Message "Cleared out previous content in cache." -Type 1 -Component "o365_PreCache"
    }
    Write-CMTraceLog -Message "Starting Copy of o365 Media from CCMCache to o365_cache location'." -Type 1 -Component "o365_PreCache"
    Get-ChildItem $SourceDir -Recurse -directory | Copy-Item -Destination {$_.FullName.Replace($SourceDir, $O365Cache)}  -Force

    $Files = Get-ChildItem $SourceDir -Recurse -File
    Foreach ($File in $Files) {
        New-Item -ItemType HardLink -Path (Join-Path $O365Cache $File.FullName.Replace($SourceDir,"")) -Target $File.FullName
    }

    Remove-Item "$O365Cache\O365_Install.ps1" -Force -ErrorAction SilentlyContinue
    Remove-Item "$O365Cache\O365_Prep.ps1" -Force -ErrorAction SilentlyContinue
    Remove-Item "$O365Cache\O365_Uninstall.ps1" -Force -ErrorAction SilentlyContinue
    Write-CMTraceLog -Message "Finished Coping of o365 Media from CCMCache to o365_cache location'." -Type 1 -Component "o365_PreCache"
    Write-CMTraceLog -Message "Completed PreCache Mode'." -Type 1 -Component "o365_PreCache"
}

#Create XML (Configuration.XML) if Install Mode (Not PreCache Mode)
If (-not $Precache) {
    [XML]$XML = @"
<Configuration ID="83d58100-fefb-4cb2-802c-cbbdf19f61f9" Host="cm">
    <Info Description="Customized Office 365" />
    <Add OfficeClientEdition="64" Channel="Monthly" OfficeMgmtCOM="TRUE" ForceUpgrade="TRUE">
    <Product ID="O365ProPlusRetail">
    <Language ID="en-us" />
    <ExcludeApp ID="Groove" />
    <ExcludeApp ID="OneDrive" />
    <ExcludeApp ID="Teams" />
    </Product>
    </Add>
    <Property Name="SharedComputerLicensing" Value="0" />
    <Property Name="PinIconsToTaskbar" Value="TRUE" />
    <Property Name="SCLCacheOverride" Value="0" />
    <Property Name="AUTOACTIVATE" Value="1" />
    <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
    <Property Name="DeviceBasedLicensing" Value="0" />
    <RemoveMSI />
    <AppSettings>
    <Setup Name="Company" Value="Your Company Here" />
    <User Key="software\microsoft\office\16.0\excel\options" Name="defaultformat" Value="51" Type="REG_DWORD" App="excel16" Id="L_SaveExcelfilesas" />
    <User Key="software\microsoft\office\16.0\powerpoint\options" Name="defaultformat" Value="27" Type="REG_DWORD" App="ppt16" Id="L_SavePowerPointfilesas" />
    <User Key="software\microsoft\office\16.0\word\options" Name="defaultformat" Value="" Type="REG_SZ" App="word16" Id="L_SaveWordfilesas" />
    </AppSettings>
    <Display Level="Full" AcceptEULA="TRUE" />
</Configuration>
"@


    #Change Channel
    $xml.Configuration.Add.SetAttribute("Channel","$Channel")
    Write-CMTraceLog -Message "Setting Office Channel to $Channel" -Type 1 -Component "o365script"

    $XML.Configuration.AppSettings.Setup.SetAttribute("Value", "$CompanyValue")
    Write-CMTraceLog -Message "Setting Setup Company name to $CompanyValue" -Type 1 -Component "o365script"

    #Don't Remove Access from XML if Previously Installed or Called from Param
    if (!($A) -and !($Access))
        {
        $newExcludeElement = $xml.CreateElement("ExcludeApp")
        $newExcludeApp = $xml.Configuration.Add.Product.AppendChild($newExcludeElement)
        $newExcludeApp.SetAttribute("ID","Access")
        Write-CMTraceLog -Message "Removing Access from Install XML" -Type 1 -Component "o365script"
        }
    else{Write-CMTraceLog -Message "Adding Access To Install XML" -Type 1 -Component "o365script"}


    #Add Project Pro to XML if Previously Installed or Called from Param
    if ($PP -or $ProjectPro)
        {
        $newProductElement = $xml.CreateElement("Product")
        $newProductApp = $xml.Configuration.Add.AppendChild($newProductElement)
        $newProductApp.SetAttribute("ID","ProjectPro2019Volume")
        $newProductApp.SetAttribute("PIDKEY","B4NPR-3FKK7-T2MBV-FRQ4W-PKD2B")
        $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
        $newXmlNameElement.SetAttribute("ID","en-us")  
        Write-CMTraceLog -Message "Adding Project Pro to Install XML" -Type 1 -Component "o365script"
        }  

    #Add Visio Pro to XML if Previously Installed or Called from Param
    if ($VP -or $VisioPro)
        {
        $newProductElement = $xml.CreateElement("Product")
        $newProductApp = $xml.Configuration.Add.AppendChild($newProductElement)
        $newProductApp.SetAttribute("ID","VisioPro2019Volume")
        $newProductApp.SetAttribute("PIDKEY","9BGNQ-K37YR-RQHF2-38RQ3-7VCBB")
        $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
        $newXmlNameElement.SetAttribute("ID","en-us")  
        Write-CMTraceLog -Message "Adding Visio Pro to Install XML" -Type 1 -Component "o365script"
        }
    #Add Project Standard to XML if Previously Installed or Called from Param
    if ($PS -or $ProjectStd)
        {
        $newProductElement = $xml.CreateElement("Product")
        $newProductApp = $xml.Configuration.Add.AppendChild($newProductElement)
        $newProductApp.SetAttribute("ID","ProjectStd2019Volume")
        $newProductApp.SetAttribute("PIDKEY","C4F7P-NCP8C-6CQPT-MQHV9-JXD2M")
        $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
        $newXmlNameElement.SetAttribute("ID","en-us")  
        Write-CMTraceLog -Message "Adding Project Standard to Install XML" -Type 1 -Component "o365script"
        }  

    #Add Visio Standard to XML if Previously Installed or Called from Param
    if ($VS -or $VisioStd)
        {
        $newProductElement = $xml.CreateElement("Product")
        $newProductApp = $xml.Configuration.Add.AppendChild($newProductElement)
        $newProductApp.SetAttribute("ID","VisioStd2019Volume")
        $newProductApp.SetAttribute("PIDKEY","7TQNQ-K3YQQ-3PFH7-CCPPM-X4VQ2")
        $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
        $newXmlNameElement.SetAttribute("ID","en-us")  
        Write-CMTraceLog -Message "Adding Visio Standard to Install XML" -Type 1 -Component "o365script"
        }


    
    #Adds Uninstall for other Versions of Visio & Project if triggering Visio / Project
    if ($ProjectStd) #If Choosing to Install Project Standard, Added XML to Remove Project Pro
        {
        $XMLRemove=$XML.CreateElement("Remove")
        $XML.Configuration.appendChild($XMLRemove)
        $XMLProduct=$XMLRemove.appendChild($XML.CreateElement("Product"))
        $newProductElement = $xml.CreateElement("Product")
        $newProductApp = $xml.Configuration.Remove.AppendChild($XMLProduct)
        $newProductApp.SetAttribute("ID","ProjectPro2019Volume")
        #$newProductApp.SetAttribute("PIDKEY","WGT24-HCNMF-FQ7XH-6M8K7-DRTW9")
        $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
        $newXmlNameElement.SetAttribute("ID","en-us")  
        }  

    #Adds Uninstall for other Versions of Visio & Project if triggering Visio / Project
    if ($VisioStd) #If Choosing to Install Visio Standard, Added XML to Remove Visio Pro
        {
        $XMLRemove=$XML.CreateElement("Remove")
        $XML.Configuration.appendChild($XMLRemove)
        $XMLProduct=$XMLRemove.appendChild($XML.CreateElement("Product"))
        $newProductElement = $xml.CreateElement("Product")
        $newProductApp = $xml.Configuration.Remove.AppendChild($XMLProduct)
        $newProductApp.SetAttribute("ID","VisioPro2019Volume")
        #$newProductApp.SetAttribute("PIDKEY","69WXN-MBYV6-22PQG-3WGHK-RM6XC")
        $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
        $newXmlNameElement.SetAttribute("ID","en-us")  
        }

    #Adds Uninstall for other Versions of Visio & Project if triggering Visio / Project
    if ($ProjectPro) #If Choosing to Install Project Pro, Added XML to Remove Project Standard
        {
        $XMLRemove=$XML.CreateElement("Remove")
        $XML.Configuration.appendChild($XMLRemove)
        $XMLProduct=$XMLRemove.appendChild($XML.CreateElement("Product"))
        $newProductElement = $xml.CreateElement("Product")
        $newProductApp = $xml.Configuration.Remove.AppendChild($XMLProduct)
        $newProductApp.SetAttribute("ID","ProjectStd2019Volume")
        #$newProductApp.SetAttribute("PIDKEY","WGT24-HCNMF-FQ7XH-6M8K7-DRTW9")
        $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
        $newXmlNameElement.SetAttribute("ID","en-us")  
        }  

    #Adds Uninstall for other Versions of Visio & Project if triggering Visio / Project
    if ($VisioPro) #If Choosing to Install Visio Pro, Added XML to Remove Visio 
        {
        $XMLRemove=$XML.CreateElement("Remove")
        $XML.Configuration.appendChild($XMLRemove)
        $XMLProduct=$XMLRemove.appendChild($XML.CreateElement("Product"))
        $newProductElement = $xml.CreateElement("Product")
        $newProductApp = $xml.Configuration.Remove.AppendChild($XMLProduct)
        $newProductApp.SetAttribute("ID","VisioStd2019Volume")
        #$newProductApp.SetAttribute("PIDKEY","69WXN-MBYV6-22PQG-3WGHK-RM6XC")
        $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
        $newXmlNameElement.SetAttribute("ID","en-us")  
        }

    Write-CMTraceLog -Message "Creating XML file: $("$O365Cache\configuration.xml")" -Type 1 -Component "o365script"
    $xml.Save("$O365Cache\configuration.xml")

    #If Office 365 is not installed then run the Office 365 Prep Utility before installing Office 365
    If (-not $O365)
        {
        $ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
        Write-CMTraceLog -Message "Starting Office Prep Process" -Type 1 -Component "o365script"
        Invoke-Expression -Command "$ScriptDir\O365_Prep.ps1"
        Write-CMTraceLog -Message "Finished Office Prep Process" -Type 1 -Component "o365script"
        }
    Write-CMTraceLog -Message "Starting Office 365 Install" -Type 1 -Component "o365script"
    $InstallOffice = Start-Process -FilePath $O365Cache\setup.exe -ArgumentList "/configure $O365Cache\configuration.xml" -Wait -PassThru -WindowStyle Hidden
    $OfficeInstallCode = $InstallOffice.ExitCode
    Write-CMTraceLog -Message "Finished Office Install with code: $OfficeInstallCode" -Type 1 -Component "o365script"
    #$exitcode = Start-Process -FilePath $O365Cache\setup.exe -ArgumentList "/configure Install_O365$Install_Access$Install_Project$Install_Visio.xml" -Wait -WindowStyle Hidden

    if ($OfficeInstallCode -eq "-2147023294")
        {
        Write-CMTraceLog -Message "End User Clicked Cancel when prompted to close applications" -Type 1 -Component "o365script"
        Write-CMTraceLog -Message "Exit Script with code: $OfficeInstallCode" -Type 1 -Component "o365script"
        Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000123}"
        ExitWithCode -exitcode $OfficeInstallCode
        } 


    if ($2016)
        {
        Write-CMTraceLog -Message "Office 2016 was Previously Installed" -Type 1 -Component "o365script"
        if($OfficeInstallCode -eq "0")
            {
            Write-CMTraceLog -Message "Office Setup Finished with Exit Code: $OfficeInstallCode" -Type 1 -Component "o365script"
            Write-CMTraceLog -Message "Exit Script with code: 3010" -Type 1 -Component "o365script"
            ExitWithCode -exitcode 3010
            }
        else
            {
            Write-CMTraceLog -Message "Office Setup Finished with Exit Code: $OfficeInstallCode" -Type 1 -Component "o365script"
            Write-CMTraceLog -Message "Exit Script with code: $OfficeInstallCode" -Type 1 -Component "o365script"
            ExitWithCode -exitcode $OfficeInstallCode
            }
        }
    else 
        {
        Write-CMTraceLog -Message "Exit Script with code: $OfficeInstallCode" -Type 1 -Component "o365script"
        ExitWithCode -exitcode $OfficeInstallCode
        }
    }
