<#
.SYNOPSIS
    Enables the Secure Boot Update scheduled task.

.DESCRIPTION
    This script ensures the Windows Secure Boot Update scheduled task 
    (\Microsoft\Windows\PI\Secure-Boot-Update) is enabled. If disabled,
    it enables it. If the task was deleted, it can recreate it.

.PARAMETER Action
    The action to perform. Valid values: check, enable, create
    - check:  Only check the task status
    - enable: (default) Enable the task if disabled. If task is missing, prompts to create.
    - create: Create the task if it doesn't exist

.PARAMETER ComputerName
    Optional. Array of computer names to check/enable the task on.
    If not specified, runs on the local machine.

.PARAMETER Credential
    Optional. Credentials for remote computer access.

.PARAMETER Quiet
    Suppresses prompts and automatically answers Yes. Useful for automation.

.EXAMPLE
    .\Enable-SecureBootTask.ps1
    # Enables the task status on local machine

.EXAMPLE
    .\Check-SecureBootScheduledTask.ps1 enable
    # Enables the task if disabled. Prompts to create if missing.

.EXAMPLE
    .\Check-SecureBootScheduledTask.ps1 create
    # Creates the task if it was deleted, then checks its status

.EXAMPLE
    .\Check-SecureBootScheduledTask.ps1 check -ComputerName "PC1", "PC2"
    # Checks the task on remote machines

.NOTES
    Requires administrator privileges to enable or create the task.
    Task Path: \Microsoft\Windows\PI\Secure-Boot-Update
    Task runs taskhostw.exe every 12 hours with elevated privileges.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position=0)]
    [ValidateSet('check', 'enable', 'create', '')]
    [string]$Action = 'enable',

    [Parameter()]
    [string[]]$ComputerName,

    [Parameter()]
    [PSCredential]$Credential,

    [Parameter()]
    [Alias('Force', 'Silent')]
    [switch]$Quiet
)

# Convert Action to switches for backward compatibility
$Enable = $Action -eq 'enable'
$Create = $Action -eq 'create'

# Download URL: https://aka.ms/getsecureboot -> "Deployment and Monitoring Samples"
# Note: This script runs on endpoints to enable the Secure Boot Update task.

$TaskPath = "\Microsoft\Windows\PI\"
$TaskName = "Secure-Boot-Update"

function Get-SecureBootTaskStatus {
    [CmdletBinding()]
    param(
        [string]$Computer = $env:COMPUTERNAME
    )

    $result = [PSCustomObject]@{
        ComputerName = $Computer
        TaskExists   = $false
        TaskState    = $null
        IsEnabled    = $false
        LastRunTime  = $null
        NextRunTime  = $null
        Error        = $null
    }

    try {
        if ($Computer -eq $env:COMPUTERNAME -or $Computer -eq "localhost" -or $Computer -eq ".") {
            # Use schtasks.exe for more reliable task detection
            $schtasksOutput = schtasks.exe /Query /TN "$TaskPath$TaskName" /FO CSV 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                # Task not found is not an error - just means task doesn't exist
                $result.TaskExists = $false
                return $result
            }
            
            # Parse CSV output
            $taskData = $schtasksOutput | ConvertFrom-Csv
            if ($taskData) {
                $result.TaskExists = $true
                $result.TaskState = $taskData.Status
                $result.IsEnabled = ($taskData.Status -eq 'Ready' -or $taskData.Status -eq 'Running')
                
                # Try to get next run time from the data
                if ($taskData.'Next Run Time' -and $taskData.'Next Run Time' -ne 'N/A') {
                    try {
                        $result.NextRunTime = [DateTime]::Parse($taskData.'Next Run Time')
                    } catch { }
                }
            }
        }
        else {
            # Remote computer - use Invoke-Command with schtasks
            $remoteResult = Invoke-Command -ComputerName $Computer -ScriptBlock {
                param($fullTaskName)
                $output = schtasks.exe /Query /TN $fullTaskName /FO CSV 2>&1
                @{
                    ExitCode = $LASTEXITCODE
                    Output = $output
                }
            } -ArgumentList "$TaskPath$TaskName" -ErrorAction Stop

            if ($remoteResult.ExitCode -ne 0) {
                # Task not found is not an error - just means task doesn't exist
                $result.TaskExists = $false
                return $result
            }

            $taskData = $remoteResult.Output | ConvertFrom-Csv
            if ($taskData) {
                $result.TaskExists = $true
                $result.TaskState = $taskData.Status
                $result.IsEnabled = ($taskData.Status -eq 'Ready' -or $taskData.Status -eq 'Running')
            }
        }
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

function New-SecureBootTask {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Computer = $env:COMPUTERNAME
    )

    $success = $false
    $errorMsg = $null

    # Task definition - matches the original Windows Secure Boot Update task
    # Uses ComHandler with SBServicing class, runs as LocalSystem
    $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.6" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2012-02-07T16:39:20</Date>
    <SecurityDescriptor>O:BAG:BAD:P(A;;FA;;;BA)(A;;FA;;;SY)(A;;FRFX;;;LS)</SecurityDescriptor>
    <Source>`$(@%SystemRoot%\system32\TpmTasks.dll,-601)</Source>
    <Author>`$(@%SystemRoot%\system32\TpmTasks.dll,-600)</Author>
    <Description>`$(@%SystemRoot%\system32\TpmTasks.dll,-604)</Description>
    <URI>\Microsoft\Windows\PI\Secure-Boot-Update</URI>
  </RegistrationInfo>
  <Principals>
    <Principal id="LocalSystem">
      <UserId>S-1-5-18</UserId>
    </Principal>
  </Principals>
  <Settings>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <StartWhenAvailable>true</StartWhenAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
  </Settings>
  <Triggers>
    <BootTrigger>
      <Delay>PT5M</Delay>
      <Repetition>
        <Interval>PT12H</Interval>
      </Repetition>
    </BootTrigger>
  </Triggers>
  <Actions Context="LocalSystem">
    <ComHandler>
      <ClassId>{5014B7C8-934E-4262-9816-887FA745A6C4}</ClassId>
      <Data><![CDATA[SBServicing]]></Data>
    </ComHandler>
  </Actions>
</Task>
"@

    try {
        if ($Computer -eq $env:COMPUTERNAME -or $Computer -eq "localhost" -or $Computer -eq ".") {
            if ($PSCmdlet.ShouldProcess("$TaskPath$TaskName", "Create scheduled task")) {
                # Save XML to temp file and import
                $tempFile = [System.IO.Path]::GetTempFileName()
                $taskXml | Out-File -FilePath $tempFile -Encoding Unicode -Force
                
                $output = schtasks.exe /Create /TN "$TaskPath$TaskName" /XML $tempFile /F 2>&1
                
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                
                if ($LASTEXITCODE -eq 0) {
                    $success = $true
                } else {
                    $errorMsg = $output -join " "
                }
            }
        }
        else {
            if ($PSCmdlet.ShouldProcess("$Computer\$TaskPath$TaskName", "Create scheduled task")) {
                $result = Invoke-Command -ComputerName $Computer -ScriptBlock {
                    param($taskPath, $taskName, $xml)
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    $xml | Out-File -FilePath $tempFile -Encoding Unicode -Force
                    $output = schtasks.exe /Create /TN "$taskPath$taskName" /XML $tempFile /F 2>&1
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    @{ ExitCode = $LASTEXITCODE; Output = $output }
                } -ArgumentList $TaskPath, $TaskName, $taskXml -ErrorAction Stop
                
                if ($result.ExitCode -eq 0) {
                    $success = $true
                } else {
                    $errorMsg = $result.Output -join " "
                }
            }
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
    }

    return @{
        Success = $success
        Error   = $errorMsg
    }
}

function Enable-SecureBootTask {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Computer = $env:COMPUTERNAME
    )

    $success = $false
    $errorMsg = $null

    try {
        if ($Computer -eq $env:COMPUTERNAME -or $Computer -eq "localhost" -or $Computer -eq ".") {
            if ($PSCmdlet.ShouldProcess("$TaskPath$TaskName", "Enable scheduled task")) {
                $output = schtasks.exe /Change /TN "$TaskPath$TaskName" /ENABLE 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $success = $true
                } else {
                    $errorMsg = $output -join " "
                }
            }
        }
        else {
            if ($PSCmdlet.ShouldProcess("$Computer\$TaskPath$TaskName", "Enable scheduled task")) {
                $result = Invoke-Command -ComputerName $Computer -ScriptBlock {
                    param($fullTaskName)
                    $output = schtasks.exe /Change /TN $fullTaskName /ENABLE 2>&1
                    @{ ExitCode = $LASTEXITCODE; Output = $output }
                } -ArgumentList "$TaskPath$TaskName" -ErrorAction Stop
                
                if ($result.ExitCode -eq 0) {
                    $success = $true
                } else {
                    $errorMsg = $result.Output -join " "
                }
            }
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
    }

    return @{
        Success = $success
        Error   = $errorMsg
    }
}

# Main execution
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Secure Boot Update Task Enabler" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Task: $TaskPath$TaskName" -ForegroundColor Gray
Write-Host ""

# Determine target computers
$targets = if ($ComputerName) { $ComputerName } else { @($env:COMPUTERNAME) }

$results = @()

foreach ($computer in $targets) {
    Write-Host "Checking: $computer" -ForegroundColor Yellow
    
    $status = Get-SecureBootTaskStatus -Computer $computer
    
    if ($status.Error) {
        Write-Host "  Error: $($status.Error)" -ForegroundColor Red
    }
    elseif (-not $status.TaskExists) {
        Write-Host "  Task does not exist on this system" -ForegroundColor Red
        
        # Create if requested, or prompt if Enable was specified
        $shouldCreate = $Create
        if (-not $shouldCreate -and $Enable) {
            Write-Host ""
            Write-Host "  The task may have been deleted." -ForegroundColor Yellow
            if ($Quiet) {
                Write-Host "  Auto-creating task (Quiet mode)" -ForegroundColor Cyan
                $shouldCreate = $true
            } else {
                $confirm = Read-Host "  Do you want to recreate the task? (Y/N)"
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    $shouldCreate = $true
                }
            }
        }
        
        if ($shouldCreate) {
            Write-Host "  Creating task..." -ForegroundColor Yellow
            $createResult = New-SecureBootTask -Computer $computer
            
            if ($createResult.Success) {
                Write-Host "  Task created successfully" -ForegroundColor Green
                # Re-check status
                $status = Get-SecureBootTaskStatus -Computer $computer
                
                if ($status.TaskExists) {
                    $stateColor = if ($status.IsEnabled) { "Green" } else { "Red" }
                    Write-Host "  State: $($status.TaskState)" -ForegroundColor $stateColor
                }
            }
            else {
                Write-Host "  Failed to create: $($createResult.Error)" -ForegroundColor Red
            }
        }
    }
    else {
        $stateColor = if ($status.IsEnabled) { "Green" } else { "Red" }
        Write-Host "  State: $($status.TaskState)" -ForegroundColor $stateColor
        
        if ($status.LastRunTime -and $status.LastRunTime -ne [DateTime]::MinValue) {
            Write-Host "  Last Run: $($status.LastRunTime)" -ForegroundColor Gray
        }
        if ($status.NextRunTime -and $status.NextRunTime -ne [DateTime]::MinValue) {
            Write-Host "  Next Run: $($status.NextRunTime)" -ForegroundColor Gray
        }

        # Enable if requested and currently disabled
        if ($Enable -and -not $status.IsEnabled) {
            Write-Host "  Enabling task..." -ForegroundColor Yellow
            $enableResult = Enable-SecureBootTask -Computer $computer
            
            if ($enableResult.Success) {
                Write-Host "  Task enabled successfully" -ForegroundColor Green
                # Re-check status
                $status = Get-SecureBootTaskStatus -Computer $computer
            }
            else {
                Write-Host "  Failed to enable: $($enableResult.Error)" -ForegroundColor Red
            }
        }
        elseif ($Enable -and $status.IsEnabled) {
            Write-Host "  Task is already enabled" -ForegroundColor Green
        }
    }
    
    $results += $status
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$enabled = ($results | Where-Object { $_.IsEnabled }).Count
$disabled = ($results | Where-Object { $_.TaskExists -and -not $_.IsEnabled }).Count
$notFound = ($results | Where-Object { -not $_.TaskExists }).Count
$errors = ($results | Where-Object { $_.Error }).Count

Write-Host "Total Checked: $($results.Count)"
Write-Host "Enabled: $enabled" -ForegroundColor Green
if ($disabled -gt 0) { Write-Host "Disabled: $disabled" -ForegroundColor Red }
if ($notFound -gt 0) { Write-Host "Not Found: $notFound" -ForegroundColor Yellow }
if ($errors -gt 0) { Write-Host "Errors: $errors" -ForegroundColor Red }

# Return results for pipeline
$results