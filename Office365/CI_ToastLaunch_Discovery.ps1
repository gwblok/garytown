#Display Office 365 Toast Notification Discovery Script
$registryPath = "HKLM:\SOFTWARE\SWD\O365" #Sets Registry Location

#Get Enable O365 Toast Notification Value
$Enable_O365_Toast = Get-ItemPropertyValue $registryPath Enable_O365_Toast -erroraction SilentlyContinue

$logfile = "$env:TEMP\o365_Baseline.log"

#region: CMTraceLog Function formats logging in CMTrace style
        function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "365 Toast Discovery",
 
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

CMTraceLog -Message  "-------------------------------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Starting Office 365 Toast Notification Discovery" -Type 2 -LogFile $LogFile
CMTraceLog -Message  "-------------------------------------------------" -Type 1 -LogFile $LogFile

if ($Enable_O365_Toast -eq "True")
   {
   #Display Toast Notification
   Write-Output "Non-compliant"
   CMTraceLog -Message  "Toast Discovery = Non-Compliant" -Type 1 -LogFile $LogFile
   CMTraceLog -Message  "Launch Remediation Script to Launch Toast" -Type 1 -LogFile $LogFile
}
Else
{
   #Do not display Toast Notification
   Write-Output "Compliant"
   CMTraceLog -Message  "Toast Discovery = Compliant" -Type 1 -LogFile $LogFile
   CMTraceLog -Message  "Do Nothing, System not ready for Toast Notification" -Type 1 -LogFile $LogFile
}


CMTraceLog -Message  "-------------------------------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Completed Office 365 Toast Notification Discovery" -Type 2 -LogFile $LogFile
CMTraceLog -Message  "-------------------------------------------------" -Type 1 -LogFile $LogFile
