<#  GARYTOWN.COM / @gwblok
Custom Actions in the Setup Process
    This script creates each of the 6 batch files, along with associated powershell files.
    It then populates the Batch file to call the PS File
    It then populates the PS File with the command to create a time stamp.
    Note, assumes several task sequence variables (SMSTS_BUILD & RegistryPath) as the location to write the data to
    Goal: Confirm when the Scripts run and compare to other logs
    Docs: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-setup-enable-custom-actions
    
#>


$registryPath = "HKLM:\SOFTWARE\OSDCloud"
if (!(Test-Path -Path $registryPath)){New-Item -Path $registryPath} 

$RunOncePath = "C:\Windows\System32\update\runonce"
$RunPath = "C:\Windows\System32\update\run"
$ScriptsPath = "C:\Windows\Setup\Scripts"
if (!(Test-Path -Path $RunOncePath)){New-Item -Path $RunOncePath -ItemType Directory -Force }
if (!(Test-Path -Path $RunPath)){New-Item -Path $RunPath -ItemType Directory -Force }
if (!(Test-Path -Path $ScriptsPath)){New-Item -Path $ScriptsPath -ItemType Directory -Force }

#Custom Action Table (CA = CustomAction)
$RunScriptTable = @(
    @{ Script = "CA_PreInstall"; BatFile = 'preinstall.cmd'; ps1file = 'preinstall.ps1';Type = 'RunOnce'; Path = "$RunOncePath"}
    @{ Script = "CA_PreCommit"; BatFile = 'precommit.cmd'; ps1file = 'precommit.ps1'; Type = 'RunOnce'; Path = "$RunOncePath"}
    @{ Script = "CA_Failure"; BatFile = 'failure.cmd'; ps1file = 'failure.ps1'; Type = 'RunOnce'; Path = "$RunOncePath"}
    @{ Script = "CA_Success"; BatFile = 'success.cmd'; ps1file = 'success.ps1'; Type = 'RunOnce'; Path = "$RunOncePath"}
    @{ Script = "CA_PreInstall"; BatFile = 'preinstall.cmd'; ps1file = 'preinstall.ps1'; Type = 'Run'; Path = "$RunPath"}
    @{ Script = "CA_PreCommit"; BatFile = 'precommit.cmd'; ps1file = 'precommit.ps1'; Type = 'Run'; Path = "$RunPath"}
    @{ Script = "CA_Failure"; BatFile = 'failure.cmd'; ps1file = 'failure.ps1'; Type = 'Run'; Path = "$RunPath"}
    @{ Script = "CA_Success"; BatFile = 'success.cmd'; ps1file = 'success.ps1'; Type = 'Run'; Path = "$RunPath"}
    @{ Script = "CA_SetupComplete"; BatFile = 'SetupComplete.cmd'; ps1file = 'SetupComplete.ps1'; Type = 'Legacy'; Path = "$ScriptsPath"}
)


$ScriptGUID = New-Guid

ForEach ($RunScript in $RunScriptTable)
    {
    Write-Output $RunScript.Script

    $BatFilePath = "$($RunScript.Path)\$($ScriptGUID)\$($RunScript.batFile)"
    $PSFilePath = "$($RunScript.Path)\$($ScriptGUID)\$($RunScript.ps1File)"
        
    #Create Batch File to Call PowerShell File
        
    New-Item -Path $BatFilePath -ItemType File -Force
    $CustomActionContent = New-Object system.text.stringbuilder
    [void]$CustomActionContent.Append('%windir%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy ByPass -File')
    [void]$CustomActionContent.Append(" $PSFilePath")
    Add-Content -Path $BatFilePath -Value $CustomActionContent.ToString()

    #Create PowerShell File to do actions
        
    New-Item -Path $PSFilePath -ItemType File -Force
    Add-Content -Path $PSFilePath  '$TimeStamp = Get-Date -f s'
    $CustomActionContentPS = New-Object system.text.stringbuilder
    [void]$CustomActionContentPS.Append('$RegistryPath = ') 
    [void]$CustomActionContentPS.Append("""$RegistryPath""")
    Add-Content -Path $PSFilePath -Value $CustomActionContentPS.ToString()
    $CustomActionContentPS = New-Object system.text.stringbuilder
    [void]$CustomActionContentPS.Append('$keyname = ') 
    [void]$CustomActionContentPS.Append("""$($RunScript.Script)_$($RunScript.Type)""")
    Add-Content -Path $PSFilePath -Value $CustomActionContentPS.ToString()
    Add-Content -Path $PSFilePath -Value 'New-ItemProperty -Path $registryPath -Name $keyname -Value $TimeStamp -Force'
    }
