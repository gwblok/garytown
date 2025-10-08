#to Run, boot OSDCloudUSB, at the PS Prompt: iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Dev/CloudScripts/TyDoneRight.ps1)


#https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Dev/CloudScripts/TyDoneRight.ps1
$ScriptName = 'OSDCloudWrapperDemo'
$ScriptVersion = '25.2.3.1'


#Only Run this section from in WinPE
if ($env:SystemDrive -eq 'X:') {
    $LogName = "OSDCloudDemo-$((Get-Date).ToString('yyyy-MM-dd-HHmmss')).log"
    Start-Transcript -Path $env:TEMP\$LogName -Append -Force

    Write-Host "Starting $ScriptName $ScriptVersion"
    write-host "Added Function New-SetupCompleteOSDCloudFiles" -ForegroundColor Green


    #Variables to define the Windows OS / Edition etc to be applied during OSDCloud
    $Product = (Get-MyComputerProduct)
    $Model = (Get-MyComputerModel)
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    $OSVersion = 'Windows 11' #Used to Determine Driver Pack
    $OSReleaseID = '24H2' #Used to Determine Driver Pack
    $OSName = 'Windows 11 24H2 x64'
    $OSEdition = 'Pro'
    $OSActivation = 'Retail'
    $OSLanguage = 'en-us'


    #Set OSDCloud Vars
    $Global:MyOSDCloud = [ordered]@{
        Restart = [bool]$False
        RecoveryPartition = [bool]$true
        OEMActivation = [bool]$True
        WindowsUpdate = [bool]$true
        WindowsUpdateDrivers = [bool]$true
        WindowsDefenderUpdate = [bool]$true
        SetTimeZone = [bool]$true
        ClearDiskConfirm = [bool]$False
        ShutdownSetupComplete = [bool]$false
        SyncMSUpCatDriverUSB = [bool]$true
        CheckSHA1 = [bool]$true
    }

    #Testing MS Update Catalog Driver Sync
    #$Global:MyOSDCloud.DriverPackName = 'Microsoft Update Catalog'

    #Used to Determine Driver Pack
    $DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

    if ($DriverPack){
        $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
    }
    #$Global:MyOSDCloud.DriverPackName = "None"


    #Enable HPIA | Update HP BIOS | Update HP TPM
    
    if (Test-HPIASupport){
        Write-Host "Detected HP Device, Enabling HPIA, HP BIOS and HP TPM Updates"
        #$Global:MyOSDCloud.DevMode = [bool]$True
        $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
        if ($Product -ne '83B2' -and $Model -notmatch "zbook"){$Global:MyOSDCloud.HPIAALL = [bool]$true} #I've had issues with this device and HPIA
        #{$Global:MyOSDCloud.HPIAALL = [bool]$true}
        $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true
        #$Global:MyOSDCloud.HPCMSLDriverPackLatest = [bool]$true #In Test 
    }



    #write variables to console
    Write-Host "OSDCloud Variables"
    Write-Output $Global:MyOSDCloud

    #Update Files in Module that have been updated since last PowerShell Gallery Build (Testing Only)
    #$ModulePath = (Get-ChildItem -Path "$($Env:ProgramFiles)\WindowsPowerShell\Modules\osd" | Where-Object {$_.Attributes -match "Directory"} | Select-Object -Last 1).fullname
    #import-module "$ModulePath\OSD.psd1" -Force

    #Launch OSDCloud
    Write-Host "Starting OSDCloud"
    write-host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage"

    Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

    
    function New-SetupCompleteOSDCloudFiles{
        
        $SetupCompletePath = "C:\OSDCloud\Scripts\SetupComplete"
        $ScriptsPath = $SetupCompletePath

        if (!(Test-Path -Path $ScriptsPath)){New-Item -Path $ScriptsPath -ItemType Directory -Force | Out-Null}

        $RunScript = @(@{ Script = "SetupComplete"; BatFile = 'SetupComplete.cmd'; ps1file = 'SetupComplete.ps1';Type = 'Setup'; Path = "$ScriptsPath"})

        Write-Output "Creating $($RunScript.Script) Files in $SetupCompletePath"

        $BatFilePath = "$($RunScript.Path)\$($RunScript.batFile)"
        $PSFilePath = "$($RunScript.Path)\$($RunScript.ps1File)"
                
        #Create Batch File to Call PowerShell File
        if (Test-Path -Path $PSFilePath){
            copy-item $PSFilePath -Destination "$ScriptsPath\SetupComplete.ps1.bak"
        }        
        New-Item -Path $BatFilePath -ItemType File -Force
        $CustomActionContent = New-Object system.text.stringbuilder
        [void]$CustomActionContent.Append('%windir%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy ByPass -File C:\OSDCloud\Scripts\SetupComplete\SetupComplete.ps1')
        Add-Content -Path $BatFilePath -Value $CustomActionContent.ToString()

        #Create PowerShell File to do actions

        New-Item -Path $PSFilePath -ItemType File -Force
        Add-Content -path $PSFilePath "Write-Output 'Starting SetupComplete OSDCloudWrapperDemo Script Process'"
        Add-Content -path $PSFilePath "Write-Output 'iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Dev/CloudScripts/OSDCloudWrapperDemo.ps1)'"
        Add-Content -path $PSFilePath 'if ((Test-WebConnection) -ne $true){Write-error "No Internet, Sleeping 2 Minutes" ; start-sleep -seconds 120}'
        Add-Content -path $PSFilePath 'iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Dev/CloudScripts/OSDCloudWrapperDemo.ps1)'
    }
    Write-Host "==================================================" -ForegroundColor DarkGray
    Write-Host "OSDCloud Process Complete, Running Custom Actions From Script Before Reboot" -ForegroundColor Magenta
    Write-Host "Creating Custom SetupComplete Files for Hope" -ForegroundColor Cyan
    
    New-SetupCompleteOSDCloudFiles

    #Copy CMTrace Local if in WinPE Media
    if (Test-path -path "x:\windows\system32\cmtrace.exe"){
        copy-item "x:\windows\system32\cmtrace.exe" -Destination "C:\Windows\System\cmtrace.exe" -verbose
    }

    #Copy LSUClient Module to Program Files if Lenovo Device
    #This is needed for the LenovoBIOSUpdate to work in Windows
    if ($Manufacturer -match "Lenovo") {
        $PowerShellSavePath = 'C:\Program Files\WindowsPowerShell'
        Write-Host "Copy-PSModuleToFolder -Name LSUClient to $PowerShellSavePath\Modules"
        Copy-PSModuleToFolder -Name LSUClient -Destination "$PowerShellSavePath\Modules"
    }
    #Copy Logs if available
    if (Test-Path -Path $env:TEMP\$LogName){
        Write-Host -ForegroundColor DarkGray "Copying Log to C:\OSDCloud\Logs"
        Stop-Transcript
        Copy-Item -Path $env:TEMP\$LogName -Destination C:\OSDCloud\Logs -Force
    }
    #Restart
    #restart-computer
}
else {
    <# This will happen from inside Setup Complete #>
    Write-Host "Starting $ScriptName $ScriptVersion"
    Write-Output "If you see this, then it worked! (Wrapper Script injected into SetupComplete)"
    #IF you want to add more things to do inside of Setup Complete, add them here!
}

