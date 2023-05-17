<#Office 365 Installer Script
2022.08.04 - Stole Script & Modified - https://github.com/gwblok/garytown/blob/master/Office365/o365_install.ps1
 - Modified for Clean Installs only
 - Modified to use with Intune instead of CM

Channels: https://docs.microsoft.com/en-us/mem/configmgr/sum/deploy-use/manage-office-365-proplus-updates
#>
[CmdletBinding(DefaultParameterSetName="Office Options")] 
param (
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $Access,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $ProjectPro,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $VisioPro,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $ProjectStd,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $VisioStd,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $AccessRuntime,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $ExcludePublisher,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $ExcludeOneNote,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $ExcludeSkype,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $ExcludeOutlook,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $ExcludePowerPoint,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $ExcludeBing,        
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $SharedComputerLicensing,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $AUTOACTIVATE,  
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $PinIconsToTaskbar,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $DeviceBasedLicensing,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $Update,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][ValidateSet("BetaChannel", "CurrentPreview", "Current", "MonthlyEnterprise", "SemiAnnualPreview", "SemiAnnual", "Broad", "Targeted")][string]$Channel,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][ValidateSet("en-us", "fr-fr", "zh-cn", "zh-tw", "de-de", "it-it")][string]$Language,
        [Parameter(Mandatory=$false)][switch]$SetLanguageDefault,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$CompanyValue,
        [Parameter(Mandatory=$false)][switch]$BuildConfigXMLOnly
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
$O365Cache = "C:\ProgramData\M365_Cache"
if (!(Test-Path -Path $O365Cache)){New-Item -Path $O365Cache -ItemType Directory -Force | Out-Null}
$RegistryPath = "HKLM:\SOFTWARE\SWD\M365" #Sets Registry Location used for Toast Notification
$ScriptVer = "22.08.04.01"
$ComputerModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model
$LicenseShare = '\\src\src$\Office365_Shared_license'

$M365Staging = "$env:TEMP\M365Temp"
if (!(Test-Path -Path $M365Staging)){New-Item -Path $M365Staging -ItemType Directory -Force | Out-Null}
$ODTURL = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_15330-20230.exe"
Invoke-WebRequest -UseBasicParsing -Uri $ODTURL -OutFile "$env:TEMP\ODT.exe"
Start-Process -FilePath "$env:TEMP\ODT.exe" -ArgumentList "/extract:$($M365Staging) /quiet" -wait

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


Write-CMTraceLog -Message "Running Script in Install Mode" -Type 1 -Component "o365script"


$CurrentPreview = "http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be"
$Current = "http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60"
$MonthlyEnterprise = "http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6"
$SemiAnnualPreview = "http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf"
$SemiAnnual = "http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114"


#Create XML (Configuration.XML) if Install Mode (Not PreCache Mode)

    [XML]$XML = @"
<Configuration Host="cm">
    <Info Description="Customized Office 365" />
    <Add OfficeClientEdition="64" Channel="SemiAnnual" ForceUpgrade="TRUE">
    <Product ID="O365ProPlusRetail">
    <Language ID="en-us" />
    <ExcludeApp ID="Groove" />
    <ExcludeApp ID="OneDrive" />
    <ExcludeApp ID="Teams" />
    </Product>
    </Add>
    <Property Name="SharedComputerLicensing" Value="0" />
    <Property Name="PinIconsToTaskbar" Value="FALSE" />
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

#Temporary until the Channel names are all figured out
if ($Channel -eq "SemiAnnual"){$Channel = "Broad"}
if ($Channel -eq "SemiAnnualPreview"){$Channel = "Targeted"} 


#Change Channel
$xml.Configuration.Add.SetAttribute("Channel","$Channel")
Write-CMTraceLog -Message "Setting Office Channel to $Channel" -Type 1 -Component "o365script"

$XML.Configuration.AppSettings.Setup.SetAttribute("Value", "$CompanyValue")
Write-CMTraceLog -Message "Setting Setup Company name to $CompanyValue" -Type 1 -Component "o365script"
        
if ($SharedComputerLicensing)
    {
    #Change SharedComputerLicensing to 1
    ($xml.Configuration.Property | Where-Object {$_.Name -eq "SharedComputerLicensing"}).SetAttribute("Value","1")
    }
    
if ($AUTOACTIVATE)
    {
    #Change AUTOACTIVATE to 1
    ($xml.Configuration.Property | Where-Object {$_.Name -eq "AUTOACTIVATE"}).SetAttribute("Value","1")
    }
    
if ($PinIconsToTaskbar)
    {
    #Change PinIconsToTaskbar to TRUE
    ($xml.Configuration.Property | Where-Object {$_.Name -eq "PinIconsToTaskbar"}).SetAttribute("Value","TRUE")
    }

if ($DeviceBasedLicensing)
    {
    #Change DeviceBasedLicensing to 1
    ($xml.Configuration.Property | Where-Object {$_.Name -eq "DeviceBasedLicensing"}).SetAttribute("Value","1")
    }

#Add Project Pro to XML if Previously Installed or Called from Param
if ($PP -or $ProjectPro)
    {
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Add.AppendChild($newProductElement)
    $newProductApp.SetAttribute("ID","ProjectPro2019Volume")
    $newProductApp.SetAttribute("PIDKEY","B4NPR-3FKK7-T2MBV-FRQ4W-PKD2B")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Groove")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","OneDrive")    
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Teams")  
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
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Groove")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","OneDrive")     
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Teams")  
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
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Groove")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","OneDrive")   
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Teams")  
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
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Groove")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","OneDrive")   
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Teams")  
    Write-CMTraceLog -Message "Adding Visio Standard to Install XML" -Type 1 -Component "o365script"
    }

#Add Access Runtime if Called from Param - Changed to ALWAYS append this.
if ($AccessRuntime)
    {
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Add.AppendChild($newProductElement)
    $newProductApp.SetAttribute("ID","AccessRuntimeRetail")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Groove")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","OneDrive")    
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("ExcludeApp"))
    $newXmlNameElement.SetAttribute("ID","Teams")    
    Write-CMTraceLog -Message "Adding Access Runtime to Install XML" -Type 1 -Component "o365script"
    }  
    
#Don't Remove Access from XML if Previously Installed or Called from Param
if (!($Access))
    {
    $newProductAttributes = $xml.Configuration.Add.Product
    foreach ($newproduct in $newProductAttributes)
        {
        $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("ExcludeApp"))
        $newXmlNameElement.SetAttribute("ID","Access")
        }
    Write-CMTraceLog -Message "Removing Access from Install XML" -Type 1 -Component "o365script"
    }
else{Write-CMTraceLog -Message "Adding Access To Install XML" -Type 1 -Component "o365script"}

#If Exclude OneNote
if ($ExcludeOneNote)
    {
    $newProductAttributes = $xml.Configuration.Add.Product
    foreach ($newproduct in $newProductAttributes)
        {
        $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("ExcludeApp"))
        $newXmlNameElement.SetAttribute("ID","OneNote")
        }
    Write-CMTraceLog -Message "Removing OneNote from Install XML" -Type 1 -Component "o365script"
    }

#If Exclude Skype
if ($ExcludeSkype)
    {
    $newProductAttributes = $xml.Configuration.Add.Product
    foreach ($newproduct in $newProductAttributes)
        {
        $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("ExcludeApp"))
        $newXmlNameElement.SetAttribute("ID","lync")
        }
    Write-CMTraceLog -Message "Removing Skype from Install XML" -Type 1 -Component "o365script"
    }
#If Exclude Publisher
if ($ExcludePublisher)
    {
    $newProductAttributes = $xml.Configuration.Add.Product
    foreach ($newproduct in $newProductAttributes)
        {
        $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("ExcludeApp"))
        $newXmlNameElement.SetAttribute("ID","Publisher")
        }
    Write-CMTraceLog -Message "Removing Publisher from Install XML" -Type 1 -Component "o365script"
    }

    #If Exclude Outlook
if ($ExcludeOutlook)
    {
    $newProductAttributes = $xml.Configuration.Add.Product
    foreach ($newproduct in $newProductAttributes)
        {
        $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("ExcludeApp"))
        $newXmlNameElement.SetAttribute("ID","Outlook")
        }
    Write-CMTraceLog -Message "Removing Outlook from Install XML" -Type 1 -Component "o365script"
    }
#If Exclude PowerPoint
if ($ExcludePowerPoint)
    {
    $newProductAttributes = $xml.Configuration.Add.Product
    foreach ($newproduct in $newProductAttributes)
        {
        $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("ExcludeApp"))
        $newXmlNameElement.SetAttribute("ID","PowerPoint")
        }
    Write-CMTraceLog -Message "Removing PowerPoint from Install XML" -Type 1 -Component "o365script"
    }
#If Exclude Bing
if ($ExcludeBing)
    {
    $newProductAttributes = $xml.Configuration.Add.Product
    foreach ($newproduct in $newProductAttributes)
        {
        $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("ExcludeApp"))
        $newXmlNameElement.SetAttribute("ID","Bing")
        }
    Write-CMTraceLog -Message "Removing BIng from Install XML" -Type 1 -Component "o365script"
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

    
<#add additional languages to download
In the install command, if you leave out -Language, it will default to en-us
If you pick a different language like fr-fr, it will set that as default, but still include en-us
#>
if ($Language)
    {
    Write-CMTraceLog -Message "Language Param detected, added $Language to XML" -Type 1 -Component "o365script"
    if ($SetLanguageDefault)#Set Default language to the Language Specified
        {
        Write-CMTraceLog -Message " LanguageDefault Param detected, set $Language to Default" -Type 1 -Component "o365script"
        $CurrentProductAttributeLang = $xml.Configuration.Add.Product
        foreach ($currentproduct in $CurrentProductAttributeLang)
            {
            $newXmlNameElement = $currentproduct.Language
            $newXmlNameElement.SetAttribute("ID","$Language")
            }
        #Include English in the install if you picked a different language as your default
        if (!($Language -eq "en-us"))
            {
            Write-CMTraceLog -Message " LanguageDefault Param detected, appending en-us to XML" -Type 1 -Component "o365script"
            $newProductAttributeLang = $xml.Configuration.Add.Product
            foreach ($newproduct in $newProductAttributeLang)
                {
                $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("Language"))
                $newXmlNameElement.SetAttribute("ID","en-us")
                }
                }
        }
    else #Append Language, leaving English as Default
        {
        Write-CMTraceLog -Message " LanguageDefault Param NOT detected, appending $Language to XML" -Type 1 -Component "o365script"
        $newProductAttributeLang = $xml.Configuration.Add.Product
            foreach ($newproduct in $newProductAttributeLang)
                {
                $newXmlNameElement = $newproduct.AppendChild($xml.CreateElement("Language"))
                $newXmlNameElement.SetAttribute("ID","$Language")
                }
            }
        }


Write-CMTraceLog -Message "Creating XML file: $("$O365Cache\configuration.xml")" -Type 1 -Component "o365script"
$xml.Save("$O365Cache\configuration.xml")

if (!($BuildConfigXMLOnly))
    {
    Write-CMTraceLog -Message "Starting Office 365 Install" -Type 1 -Component "o365script"
    $InstallOffice = Start-Process -FilePath $M365Staging\setup.exe -ArgumentList "/configure $O365Cache\configuration.xml" -Wait -PassThru -WindowStyle Hidden
    $OfficeInstallCode = $InstallOffice.ExitCode
    Write-CMTraceLog -Message "Finished Office Install with code: $OfficeInstallCode" -Type 1 -Component "o365script"
    


    if ($OfficeInstallCode -eq "-2147023294")
        {
        Write-CMTraceLog -Message "End User Clicked Cancel when prompted to close applications" -Type 1 -Component "o365script"
        Write-CMTraceLog -Message "Exit Script with code: $OfficeInstallCode" -Type 1 -Component "o365script"
        ExitWithCode -exitcode $OfficeInstallCode
        } 
    Write-CMTraceLog -Message "Exit Script with code: $OfficeInstallCode" -Type 1 -Component "o365script"
    ExitWithCode -exitcode $OfficeInstallCode

    }
