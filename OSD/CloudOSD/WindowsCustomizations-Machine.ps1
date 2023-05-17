<#
Gary Blok | gwblok | Recast Software

This script will do a bunch of things.

Still a work in progress...

#>


try {$tsenv = new-object -comobject Microsoft.SMS.TSEnvironment}
catch{Write-Output "Not in TS"}




#Enable or Disable Customizations
$CMTracePath = $True
$PSTranscription = $True
$WinRM = $True
$DisableCortana = $True
$PreventFirstRunPage = $True
$AllowClipboardHistory = $True
$DisableConsumerFeatures = $True
$ShowRunasDifferentuserinStart = $True
$EnableRDP = $True
$PSTranscriptionMode = "Enable"




#Script Vars:
$ScriptVersion = "22.03.07.01"
if ($tsenv){
    $LogFolder = $tsenv.value('CompanyFolder')#Company Folder is set during the TS Var at start of TS.
    $CompanyName = $tsenv.value('CompanyName')
    }
if (!($CompanyName)){$CompanyName = "RecastSoftwareIT"}#If CompanyName / CompanyFolder info not found in TS Var, use this.
if (!($LogFolder)){$LogFolder = "$env:ProgramData\$CompanyName"}
$LogFilePath = "$LogFolder\Logs"
$LogFile = "$LogFilePath\MachineCustomizations.log"
$PSTranscriptsFolder = "$LogFolder\PSTranscripts"


if (!(Test-Path -path $LogFilePath)){$Null = new-item -Path $LogFilePath -ItemType Directory -Force}
if (!(Test-Path -path $PSTranscriptsFolder)){$Null = new-item -Path $PSTranscriptsFolder -ItemType Directory -Force}



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
CMTraceLog -Message  "Starting OSD Customization Script" -Type 1 -LogFile $LogFile
#Script Below
Write-Output "Company Name: $CompanyName"
Write-Output "Log Folder: $LogFolder"
Write-Output "Log File Path: $LogFilePath"
Write-Output "PS Transcripts Folder: $PSTranscriptsFolder"



#Add CMTrace to Path 
if ($CMTracePath -eq $True){
    Write-Output "Setting CMTrace in the Path"
    CMTraceLog -Message  "Setting CMTrace in the Path" -Type 1 -LogFile $LogFile
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths" -Name 'cmtrace.exe' -ItemType Registry -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\cmtrace.exe" -Name '(Default)' -Value "c:\windows\ccm\cmtrace.exe" -ErrorAction SilentlyContinue
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\cmtrace.exe" -Name 'Path' -PropertyType string -Value "c:\windows\ccm" -ErrorAction SilentlyContinue
    }

#Enable PS Transcription
if ($PSTranscription -eq $True)
    { 
    CMTraceLog -Message  "Enable PowerShell Transcripts" -Type 1 -LogFile $LogFile
    if (!(Test-Path $PSTranscriptsFolder)){$NewFolder = new-item -Path $PSTranscriptsFolder -ItemType Directory -Force}
    Set-PSTranscriptionLogging -OutputDirectory $PSTranscriptsFolder -Mode $PSTranscriptionMode -Verbose
    Write-Output "Set PSTranscription to $PSTranscriptionMode"
    }

#Enable WinRM
if ($WinRM -eq $True)
    {
    Write-Output "Enable WinRM"
    CMTraceLog -Message  "Enable WinRM" -Type 1 -LogFile $LogFile
    $Process = "cmd.exe"
    $ProcessArgs = "/c WinRM quickconfig -q -force"
    $EnableWinRM = Start-Process -FilePath $Process -ArgumentList $ProcessArgs -PassThru -Wait
    Write-Output "WinRM Proces Exit $($Process.exitcode)"
    }

#Disable Cortana
if ($DisableCortana -eq $True){
    Write-Output "Disable Cortana"
    CMTraceLog -Message  "Disable Cortana" -Type 1 -LogFile $LogFile
    if (!(Test-Path -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search")){New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"}
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -PropertyType DWORD -Value 0 -Force -Verbose
    }

#Allow Clipboard History
if ($AllowClipboardHistory -eq $True){
    Write-Output "Allow Clipboard History"
    CMTraceLog -Message  "Allow Clipboard History" -Type 1 -LogFile $LogFile
    if (!(Test-Path -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System")){New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"}
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "AllowClipboardHistory" -PropertyType DWORD -Value 1 -Force -Verbose
    }

#Prevent Edge First Run Page
if ($PreventFirstRunPage -eq $True){
    Write-Output "Prevent Edge First Run Page"
    CMTraceLog -Message  "Prevent Edge First Run Page" -Type 1 -LogFile $LogFile
    if (!(Test-Path -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge")){New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge"}
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "HideFirstRunExperience" -PropertyType DWORD -Value 1 -Force -Verbose
    }

#Disable Consumer Features
if ($DisableConsumerFeatures -eq $True){
    Write-Output "Disable Consumer Features"
    CMTraceLog -Message  "Disable Consumer Features" -Type 1 -LogFile $LogFile
    if (!(Test-Path -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent")){New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"}
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -PropertyType DWORD -Value 1 -Force -Verbose
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableSoftLanding" -PropertyType DWORD -Value 1 -Force -Verbose

    }

#Enable Remote Desktop
if ($EnableRDP -eq $True){
    Write-Output "Enable Remote Desktop"
    CMTraceLog -Message  "Enable Remote Desktop" -Type 1 -LogFile $LogFile
    if (!(Test-Path -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server")){New-Item -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server"}
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0 -Verbose
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -Verbose
    }


#Show Runas Different user in Start Menu
if ($ShowRunasDifferentuserinStart -eq $True){
    Write-Output "Show Runas Different user in Start Menu"
    CMTraceLog -Message  "Show Runas Different user in Start Menu" -Type 1 -LogFile $LogFile
    if (!(Test-Path -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer")){New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"}
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "ShowRunasDifferentuserinStart" -PropertyType DWORD -Value 1 -Force -Verbose
    }
