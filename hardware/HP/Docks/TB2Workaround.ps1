#TB2 Workaround created for George

$DockInfo = Get-HPDockUpdateDetails
if ($DockInfo){
    $SPPath = "C:\SWSetup\dockfirmware\$($DockInfo.SoftpaqNumber)"
    if (Test-Path -Path $SPPath){
        $UpdaterPath = "$SPPath\Firmware\Cypress\Dependency\ezpd_dockupdatefw.exe"
        if (Test-Path -Path $UpdaterPath){
            Write-Host -ForegroundColor Cyan "Starting Updater $UpdaterPath"
            $UpdateArgs = "-i $SPPath\Firmware\Cypress\Dependency\hp_hook_secure_cy_sign.bin -vid 03F0 -pid 0667 -rescan 5 -t 240000"
            $UpdateProcess = Start-Process -FilePath $UpdaterPath -ArgumentList $UpdateArgs -PassThru -Wait -NoNewWindow
            Start-Sleep -Seconds 1
            $IntelTBUpdater = "$SPPath\Firmware\Intel\ThunderboltUpdaterDevice.CMD.exe"
            Write-Host -ForegroundColor Cyan "Starting Updater $UpdaterPath"
            $UpdateProcess2 = Start-Process -FilePath $IntelTBUpdater -ArgumentList "-u" -PassThru -Wait -NoNewWindow

        }
        else {
            Write-Host -ForegroundColor Red "Unable to find Updater Tool $UpdaterPath"
        }
    }
    else {
        Write-Host "Unable to find Extracted Softpaq $($DockInfo.SoftpaqNumber)"
    }
}
else {
    Write-Host -ForegroundColor Red "Unable to find Dock Info"
}
