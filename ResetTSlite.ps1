#2019.12.24 - Help Reset TS's that are having issues starting. "Stuck at Installing..."

        if (Get-WmiObject -Namespace Root\CCM\SoftMgmtAgent -Class CCM_TSExecutionRequest)
            {
            Write-output "Removing TS Excustion Request from WMI"
            Get-WmiObject -Namespace Root\CCM\SoftMgmtAgent -Class CCM_TSExecutionRequest | Remove-WmiObject
            Get-CimInstance -Namespace root/ccm -ClassName SMS_MaintenanceTaskRequests | Remove-CimInstance
            Set-Service smstsmgr -StartupType manual
            Start-Service smstsmgr
            Start-Sleep -Seconds 5
            if ((Get-Process CcmExec -ea SilentlyContinue) -ne $Null) {Get-Process CcmExec | Stop-Process -Force}
            if ((Get-Process TSManager -ea SilentlyContinue) -ne $Null) {Get-Process TSManager| Stop-Process -Force}
            Start-Sleep -Seconds 5
            Start-Service ccmexec
            Start-Sleep -Seconds 5
            Start-Service smstsmgr
            restart-service ccmexec -force -ErrorAction SilentlyContinue
            Start-Process -FilePath C:\windows\ccm\CcmEval.exe
            start-sleep -Seconds 15
            #Invoke Machine Policy
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000021}" |Out-Null
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000022}" |Out-Null

            }
        Else {Write-output "No TS Excustion Request in WMI"}
