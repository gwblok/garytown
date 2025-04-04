Function Invoke-ScriptNewJob {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [int]$timeoutSeconds = 600, # Default timeout of 10 minutes
        [switch]$wait
    )
    #Start the Job
    if ($ScriptPath -eq $null) {
        Write-Host -ForegroundColor Red "Script Path is null, exiting."
        return
    }
    if (!(Test-Path -Path $ScriptPath)) {
        Write-Host -ForegroundColor Red "Script Path does not exist, exiting."
        return
    }
    $Code = Get-Content -Path $ScriptPath -Raw
    $Installing = Start-Job -ScriptBlock $code
    # Report the job ID (for diagnostic purposes)
    "Job ID: $($Installing.Id)"
    
    # Wait for the job to complete or time out
    if ($wait) {
        Write-Host -ForegroundColor Green "Waiting for job to complete..."
        Wait-Job $Installing -Timeout $timeoutSeconds | Out-Null
        Receive-Job -Job $Installing
        # Check the job state
        if ($Installing.State -eq "Completed") {
            # Job completed successfully
            "Done!"
        } elseif ($Installing.State -eq "Running") {
            # Job was interrupted due to timeout
            "Interrupted"
        } else {
            # Unexpected job state
            "???"
        }
    
        # Clean up the job
        Remove-Job -Force $Installing
    
        #Start-sleep
        Start-sleep -seconds 10
    } else {
        Write-Host -ForegroundColor Green "Job is running in the background. You can check its status later."
        Write-Host -ForegroundColor Yellow "This will bypass the timeout and run in the background, never stopping, even if it should"
    }

}