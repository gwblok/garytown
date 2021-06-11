#2020.04.20 - @gwblok - GARYTOWN.COM
#Remediation Script

$LogFile = "$($env:Temp)\HP_Configuration_Items.log"
$password = "P@ssw0rd"

function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 		    [Parameter(Mandatory=$false)]
		    $Component = $ModuleName,
 		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		    [Parameter(Mandatory=$true)]
		    $LogFile
	    )
    #  Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
	    $Time = Get-Date -Format "HH:mm:ss.ffffff"
	    $Date = Get-Date -Format "MM-dd-yyyy"
	    if ($ErrorMessage -ne $null) {$Type = 3}
	    if ($Component -eq $null) {$Component = " "}
	    if ($Type -eq $null) {$Type = 1}
	    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
	    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
    }

function IsUEFI {
try 
    {
    $SecureBootStatus = Confirm-SecureBootUEFI
    }
   catch {}
    if ($SecureBootStatus -eq $false)
        {
        return "TRUE"
        }
    elseif ($SecureBootStatus -eq $true)
        {
        return "TRUE"
        }
    else
        {
        Return "FALSE"
        }

}
#Check if HP Bios is Current

[version]$BIOSVersionInstalled = Get-HPBIOSVersion
[version]$BIOSVersionAvailableOnline = (Get-HPBIOSUpdates -latest).Ver

CMTraceLog -Message "----- Starting Remediation for Module $ModuleName -----" -Type 2 -LogFile $LogFile

if ($BIOSVersionInstalled -lt $BIOSVersionAvailableOnline)
    {
    CMTraceLog -Message "Has $($BIOSVersionInstalled), Needs: $($BIOSVersionAvailableOnline)" -Type 1 -LogFile $LogFile
    Write-Output "Has $($BIOSVersionInstalled), Needs: $($BIOSVersionAvailableOnline)"

    if ((IsUEFI) -eq $True)
        {
        if ((Get-HPBIOSSetupPasswordIsSet) -eq "TRUE"){
            CMTraceLog -Message "Has Password, Running Command to Update BIOS" -Type 1 -LogFile $LogFile
            $UpdateBIOS = Get-HPBIOSUpdates -Flash -BitLocker Suspend -Force -Password $password -Yes
            CMTraceLog -Message "Completed Process, Requires Reboot" -Type 1 -LogFile $LogFile
            }
        else{
            CMTraceLog -Message "No Password, Running Command to Update BIOS" -Type 1 -LogFile $LogFile
            $UpdateBIOS = Get-HPBIOSUpdates -Flash -BitLocker Suspend -Force -Yes
            CMTraceLog -Message "Completed Process, Requires Reboot" -Type 1 -LogFile $LogFile
            }
        }

    else
        {
        CMTraceLog -Message "System in Legacy BIOS, requires UEFI - Exiting" -Type 3 -LogFile $LogFile
        CMTraceLog -Message "Perhaps only target UEFI Devices" -Type 1 -LogFile $LogFile
        }

    }

else {Write-Output "Compliant"}
