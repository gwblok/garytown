<#
.SYNOPSIS
--.Updates VM Name to match "Shell" Name
.DESCRIPTION
Grabs Hyper-V Shell Name from Registry and ensures it matches the Machine Name.

Detection & Remediation = Same Script.  Change $Remediate = $true to $false for Detection Script
.INPUTS
None.
.OUTPUTS
None.
.NOTES
Created by @gwblok
.LINK
https://garytown.com
.LINK
https://www.recastsoftware.com
.COMPONENT
--
.FUNCTIONALITY
--
#>

Function Get-AzureTenantDisplayNameFromClient {
    $Items = Get-ChildItem -path HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo
    foreach ($Item in $Items){
        $Item.GetValue("DisplayName") 
    }
}
$CompanyName = Get-AzureTenantDisplayNameFromClient
$CompanyName = $CompanyName -replace " ",""
$LogFolder = "$env:ProgramData\$CompanyName"
$LogFilePath = "$LogFolder\Logs"
$ScriptVersion = "21.4.6.1"
$ScriptName = "Set HyperV Name to Shell Name"
$whoami = $env:USERNAME
$LogFile = "$LogFilePath\SetComputerName.log"

if (!(Test-Path -Path $LogFilePath)){$NewFolder = New-Item -Path $LogFilePath -ItemType Directory -Force}
$Remediate = $true

function CMTraceLog {
    [CmdletBinding()]
    Param (
    [Parameter(Mandatory=$false)]
    $Message,
    
    [Parameter(Mandatory=$false)]
    $ErrorMessage,
    
    [Parameter(Mandatory=$false)]
    $Component = "Intune",
    
    [Parameter(Mandatory=$false)]
    [int]$Type,
    
    [Parameter(Mandatory=$true)]
    $LogFile = "$env:ProgramData\Intune\Logs\IForgotToName.log"
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

CMTraceLog -Message  "Running Script: $ScriptName | Version: $ScriptVersion" -Type 1 -LogFile $LogFile
if ($Remediate)
{
    CMTraceLog -Message  "Running Script in Remediation Mode" -Type 1 -LogFile $LogFile
}
else
{
    CMTraceLog -Message  "Running Script in Detection Mode" -Type 1 -LogFile $LogFile
}
if (((Get-CimInstance Win32_ComputerSystem).Model -eq "Virtual Machine") -and ((Get-CimInstance Win32_ComputerSystem).Manufacturer -eq "Microsoft Corporation"))
{
    CMTraceLog -Message  "Confirmed this is HyperV VM" -Type 1 -LogFile $LogFile
    $ComputerName = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters' -Name "VirtualMachineName" -ErrorAction SilentlyContinue
    CMTraceLog -Message  "HyperV Shell Name = $ComputerName" -Type 1 -LogFile $LogFile
    if ($env:COMPUTERNAME -ne $ComputerName)
    {
        if ($Remediate){
            CMTraceLog -Message  "Renaming Device to Match Shell Name" -Type 1 -LogFile $LogFile
            Rename-Computer -NewName $ComputerName
        }
        else {
            CMTraceLog -Message  "Device is Non-Compliant - Needs to be Renamed" -Type 1 -LogFile $LogFile
            CMTraceLog -Message  "Current: $ComputerName - Needs to be $env:COMPUTERNAME" -Type 1 -LogFile $LogFile
        }
    }
    else
    {
        CMTraceLog -Message  "Machine already named properly | $ComputerName " -Type 1 -LogFile $LogFile
    }
}
else
{
    CMTraceLog -Message  "This is Not a HyperV VM - Exiting" -Type 1 -LogFile $LogFile
}
