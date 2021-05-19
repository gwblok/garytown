<#  Gary Blok @GWBLOK RecastSoftware.com
Used for Logging during the Task Sequence - Run PowerShell Step

-Message 'Running Software Updates' -Type 1 -Component 'Software Updates' -logfile %_SMSTSLogPath%\%LogFileName%
-Message 'Failed Installing M365' -Type 3 -Component 'App Installations' -logfile 'C:\Windows\Temp\TSApps.log'

#>

[CmdletBinding()]
Param (
        [Parameter(Mandatory=$true)]
        $Message,
        [Parameter(Mandatory=$false)]
        $ErrorMessage,
        [Parameter(Mandatory=$true)]
        $Component,
        [Parameter(Mandatory=$true)]
        [int]$Type,
        [Parameter(Mandatory=$false)]
        $LogFile
                )

function CMTraceLog {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        $Message,
        [Parameter(Mandatory=$false)]
        $ErrorMessage,
        [Parameter(Mandatory=$false)]
        $Component,
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

CMTraceLog -Message  "$Message" -Type $type -Component $Component -LogFile $LogFile