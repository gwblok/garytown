#powershell Invoke-Expression -Command (Invoke-RestMethod -Uri https://raw.githubusercontent.com/gwblok/garytown/master/Dev/CloudScripts/StartOSDCloudPreStart.ps1)
Invoke-Expression (Invoke-RestMethod 'sandbox.osdcloud.com')
$Global:MyOSDCloud = [ordered]@{
        Restart = [bool]$False
        RecoveryPartition = [bool]$True
        DriverPackName = "None"
    }

#Launch OSDCloud
osdcloud-UpdateModuleFilesManually -DevMode $true
Start-OSDCloudGUIDev
