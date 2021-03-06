#Gary Blok | @gwblok | Recast Software
[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true)]
		    [ValidateSet("Enable","Disable")]
            [String] $Mode
    )
$ScriptVersion = "21.3.24.1"
$whoami = (whoami).split("\") | Select-Object -Last 1
$ExtraLoggingPath = "$env:ProgramData\ExtraLogging"
$LogFilePath = "$ExtraLoggingPath\Logs"
$LogFile = "$LogFilePath\PSTranscriptionLoggingEnable.log"
$PSTranscriptsFolder = "$ExtraLoggingPath\PSTranscripts"
if (!(Test-Path -Path $LogFilePath)){$NewFolder = New-Item -Path $LogFilePath -ItemType Directory -Force}

function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "Run Scripts",
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
		    $LogFile = "$env:ProgramData\Log.log"
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


#https://adamtheautomator.com/powershell-logging-recording-and-auditing-all-the-things/
#useful when Troubleshooting the PowerShell Scripts
function Set-PSTranscriptionLogging {
	param(
		[Parameter(Mandatory)]
		[string]$OutputDirectory,
        [Parameter(Mandatory)]		
        [ValidateNotNullOrEmpty()][ValidateSet("Enable", "Disable")][string]$Mode
	)

     # Registry path
     $basePath = 'HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\Windows\PowerShell\Transcription'

     # Create the key if it does not exist
     if ($Mode -eq "Enable")
        {
         if(-not (Test-Path $basePath))
         {
             $null = New-Item $basePath -Force -ErrorAction SilentlyContinue

             # Create the correct properties
             New-ItemProperty $basePath -Name "EnableInvocationHeader" -PropertyType Dword -ErrorAction SilentlyContinue
             New-ItemProperty $basePath -Name "EnableTranscripting" -PropertyType Dword -ErrorAction SilentlyContinue
             New-ItemProperty $basePath -Name "OutputDirectory" -PropertyType String -ErrorAction SilentlyContinue
         }

         # These can be enabled (1) or disabled (0) by changing the value
         Set-ItemProperty $basePath -Name "EnableInvocationHeader" -Value "1" -Force -ErrorAction SilentlyContinue
         Set-ItemProperty $basePath -Name "EnableTranscripting" -Value "1" -Force -ErrorAction SilentlyContinue
         Set-ItemProperty $basePath -Name "OutputDirectory" -Value $OutputDirectory -Force -ErrorAction SilentlyContinue
         }
    elseif ($Mode -eq "Disable")
        {
        if(-not (Test-Path $basePath))
            {
             $null = New-Item $basePath -Force -ErrorAction SilentlyContinue

             # Create the correct properties
             New-ItemProperty $basePath -Name "EnableInvocationHeader" -PropertyType Dword -ErrorAction SilentlyContinue
             New-ItemProperty $basePath -Name "EnableTranscripting" -PropertyType Dword -ErrorAction SilentlyContinue
            }

        # These can be enabled (1) or disabled (0) by changing the value
         Set-ItemProperty $basePath -Name "EnableInvocationHeader" -Value "0" -Force -ErrorAction SilentlyContinue
         Set-ItemProperty $basePath -Name "EnableTranscripting" -Value "0" -Force -ErrorAction SilentlyContinue

        }

}


CMTraceLog -Message  "---------------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Starting PSTranscription Logging $Mode Script" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Running as $whoami" -Type 1 -LogFile $LogFile


CMTraceLog -Message  "Enable PowerShell Transcripts" -Type 1 -LogFile $LogFile

if (!(Test-Path $PSTranscriptsFolder)){$NewFolder = new-item -Path $PSTranscriptsFolder -ItemType Directory -Force}
Set-PSTranscriptionLogging -OutputDirectory $PSTranscriptsFolder -Mode $Mode
Write-Output "Set PSTranscription to $Mode"

CMTraceLog -Message  "Complete PSTranscription Logging $Mode Script" -Type 1 -LogFile $LogFile
