<#Office 365 UNINSTALL Script
Mike Terrill & Gary Blok

CM App DT Program: powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\o365_Uninstall.ps1
CM App DT Program: powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\o365_Uninstall.ps1 -ProjectPro
CM App DT User Experience: Install for System, Whether or Not, Normal, NO CHECK on Allow users to view and interact, Determine behavior based on return codes.

Based on Params or Perviously Installed Access / Visio / Project, it will remove the 

Assumes content is already in c:\programdata\o365_content (from the PreCache App)

Version 2020.04.27.1
#>

[CmdletBinding(DefaultParameterSetName="Office Options")] 
param (

        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $ProjectPro,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $ProjectStd,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $VisioPro,
        [Parameter(Mandatory=$false, ParameterSetName='Office Options')][switch] $VisioStd
    ) 
$SourceDir = Get-Location
$O365Cache = "C:\ProgramData\O365_Cache"

#Get Currently Installed Office Apps

#$Edge = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Edge'"
$2016 = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Office Professional Plus 2016'"
$O365 = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Office 365 ProPlus%'"
$A = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Access 20%'"
$PP = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Project Professional%'"
$PS = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Project Standard%'"
$VP = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Visio Professional%'"
$VS = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Visio Standard%'"


#Full Install of all Office 365 including Visio & Project apps if installed

[XML]$XML = @"
<Configuration>
<Display Level="None" AcceptEULA="TRUE" />
<Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
<Remove>
<Product ID="O365ProPlusRetail">
<Language ID="en-us" />
</Product>
</Remove>
</Configuration>
"@



#Add Project Pro to XML if Previously Installed or Called from Param
if ($PP)
    {
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Remove.AppendChild($newProductElement)
    $newProductApp.SetAttribute("ID","ProjectPro2019Volume")
    #$newProductApp.SetAttribute("PIDKEY","WGT24-HCNMF-FQ7XH-6M8K7-DRTW9")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")  
    }  

#Add Visio Pro to XML if Previously Installed or Called from Param
if ($VP)
    {
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Remove.AppendChild($newProductElement)
    $newProductApp.SetAttribute("ID","VisioPro2019Volume")
    #$newProductApp.SetAttribute("PIDKEY","69WXN-MBYV6-22PQG-3WGHK-RM6XC")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")  
    }

#Add Project Std to XML if Previously Installed or Called from Param
if ($PS)
    {
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Remove.AppendChild($newProductElement)
    $newProductApp.SetAttribute("ID","ProjectStd2019Volume")
    #$newProductApp.SetAttribute("PIDKEY","WGT24-HCNMF-FQ7XH-6M8K7-DRTW9")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")  
    }  

#Add Visio Std to XML if Previously Installed or Called from Param
if ($VS)
    {
    $newProductElement = $xml.CreateElement("Product")
    $newProductApp = $xml.Configuration.Remove.AppendChild($newProductElement)
    $newProductApp.SetAttribute("ID","VisioStd2019Volume")
    #$newProductApp.SetAttribute("PIDKEY","69WXN-MBYV6-22PQG-3WGHK-RM6XC")
    $newXmlNameElement = $newProductElement.AppendChild($xml.CreateElement("Language"))
    $newXmlNameElement.SetAttribute("ID","en-us")  
    }



 #Seperate Uninstalls based on Params (completely seperate from the above code)

 if ($ProjectPro)
    {
    [XML]$XML = @"
<Configuration>
<Remove>
<Product ID="ProjectPro2019Volume">
</Product>
</Remove>
<Display Level="None" AcceptEULA="TRUE" /> 
<Logging Path ="C:\Windows\SYSWOW64\PKG_LOGS"/>
</Configuration>
"@
    }

 if ($VisioPro)
    {
    [XML]$XML = @"
<Configuration>
<Remove>
<Product ID="VisioPro2019Volume">
</Product>
</Remove>
<Display Level="None" AcceptEULA="TRUE" /> 
<Logging Path ="C:\Windows\SYSWOW64\PKG_LOGS"/>
</Configuration>
"@
    }
 if ($ProjectStd)
    {
    [XML]$XML = @"
<Configuration>
<Remove>
<Product ID="ProjectStd2019Volume">
</Product>
</Remove>
<Display Level="None" AcceptEULA="TRUE" /> 
<Logging Path ="C:\Windows\SYSWOW64\PKG_LOGS"/>
</Configuration>
"@
    }

 if ($VisioStd)
    {
    [XML]$XML = @"
<Configuration>
<Remove>
<Product ID="VisioStd2019Volume">
</Product>
</Remove>
<Display Level="None" AcceptEULA="TRUE" /> 
<Logging Path ="C:\Windows\SYSWOW64\PKG_LOGS"/>
</Configuration>
"@
    }



$xml.Save("$O365Cache\configuration.xml")


If (-not $Precache) {
    #If Office 365 is not installed then run the Office 365 Prep Utility before installing Office 365
    If (-not $O365)
        {
        $ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
        Invoke-Expression -Command "$ScriptDir\O365_Prep.ps1"
        }
    $exitcode = Start-Process -FilePath $O365Cache\setup.exe -ArgumentList "/configure $O365Cache\configuration.xml" -Wait -WindowStyle Hidden
    #$exitcode = Start-Process -FilePath $O365Cache\setup.exe -ArgumentList "/configure Install_O365$Install_Access$Install_Project$Install_Visio.xml" -Wait -WindowStyle Hidden
    
    return $exitcode
}
