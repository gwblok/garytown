<#  Gary Blok | HP Inc | @gwblok | GARYTOWN.COM

HP USB-C G5 Essential Dock Updater Script

This script will test for Dock connected, if HP USB-C G5 Essential Dock then it will update the firmware based on the $URL specified below
If newer Firmware is released for this dock, you will need to manually update that that info


You can set the UI experience so the end user sees the update happening or completely hidden by setting the "$UIExperience" Parameter when you call this file, but default it will use Non-Interactive


HPFirmwareUpdater.exe Options:
		Non-Interactive		        -ni
		Silent mode			        -s		    		
		Force				        -f	
		Check 				        -C	


This will ONLY create a transcription log IF the dock is attached and it starts the process to test firmware.  If no dock is detected, no logging is created.
Logging created by this line: Start-Transcript -Path "$OutFilePath\$SPNumber.txt" - which should be: "C:\swsetup\dockfirmware\sp144502.txt"


Usage:
Update-HPDockFirmware.ps1 -UIExperience Silent
#>


[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('NonInteractive', 'Silent', 'Check')]
    [String]$UIExperience
) # param

if (!($UIExperience)){$UIExperience = 'NonInteractive'}

$Mode = switch ($UIExperience)
{
    "NonInteractive" {"-ni"}
    "Silent" {"-s"}
    "Check" {"-C"}
}


[int]$WaitTimer = 120 #Time in Seconds to keep checking for Dock connected.

function Get-HPDockInfo {
    <#
        Dock f/w checker
        Dan Felman/HP Inc
        March 24, 2023
        Version 01.00.00 Reports if an HP Dock is attached
                01.00.01 Add PID for Universal DOck, USB-C Dock G4

        Supports the follwing docks:
            USB-C G4 - VID_03F0&PID_484A
            USB-C G5 - VID_03F0&PID_046B - Adicora A
            USB-C G5 Essential Dock - VID_03F0&PID_379D -  Adicora R
            USB-C Universal - VID_17E9&PID_600A
            USB-C Universal G2 - VID_03F0&PID_0A6B - Adicora D
            TB G2 Dock - VID_03F0&PID_0667 - Hook    
            TB G4 Dock - VID_03F0&PID_0488 - Hook2
            HP E24d G4 FHD Docking Monitor - VID_03F0&PID_056D - Hughes /24
            HP E27d G4 QHD Docking Monitor - VID_03F0&PID_016E - Hughes /27
        Returns
            0 - NO HP dock found attached
            1 - 'HP Thunderbolt Dock G4'
            2 - 'HP Thunderbolt Dock G2' 
            3 - 'HP USB-C Dock G4' 
            4 - 'HP USB-C Dock G5' 
            5 - 'HP USB-C Universal Dock' 
            6 - 'HP USB-C Universal Dock G2' 
            7 - 'HP E24d G4 FHD Docking Monitor'
            8 - 'HP E27d G4 QHD Docking Monitor'
            9 - 'HP USB-C G5 Essential Dock'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$DebugOutput
    ) # param

    $ScriptVersion = '01.00.01 - Mar 30, 2023'
    #'Script Version: '+$ScriptVersion | Out-Host
    $CurrLoc = Get-Location
    #$ScriptPath = Split-Path $MyInvocation.MyCommand.Path

    #Set-Location $ScriptPath'\'$OCI_Path        # path to FW OCI updater folder

    #######################################################################################

        #'-- Reading signed drivers list - use to scan for attached HP docks'
        $PnpSignedDrivers = Get-CimInstance win32_PnpSignedDriver 
        $Dock_ProductName = 'none'
        $Dock_Attached = 0
        #'-- Searching for attached HP docks'
        # Find out if a Dock is connected - assume a single dock, so stop at first find
        foreach ( $iDriver in $PnpSignedDrivers ) {
            $f_InstalledDeviceID = "$($iDriver.DeviceID)"   # analyzing current device
            $Dock_ProductName = $null
            if ( ($f_InstalledDeviceID -match "HID\\VID_03F0") -or ($f_InstalledDeviceID -match "USB\\VID_17E9") ) {
                $DockDriver = $iDriver
                switch -Wildcard ( $f_InstalledDeviceID ) {
                    '*PID_0488*' { $Dock_Attached = 1 ; $Dock_ProductName = 'HP Thunderbolt Dock G4'}
                    '*PID_0667*' { $Dock_Attached = 2 ; $Dock_ProductName = 'HP Thunderbolt Dock G2' }
                    '*PID_484A*' { $Dock_Attached = 3 ; $Dock_ProductName = 'HP USB-C Dock G4' }
                    '*PID_046B*' { $Dock_Attached = 4 ; $Dock_ProductName = 'HP USB-C Dock G5' }
                    '*PID_600A*' { $Dock_Attached = 5 ; $Dock_ProductName = 'HP USB-C Universal Dock' }
                    '*PID_0A6B*' { $Dock_Attached = 6 ; $Dock_ProductName = 'HP USB-C Universal Dock G2' }
                    '*PID_056D*' { $Dock_Attached = 7 ; $Dock_ProductName = 'HP E24d G4 FHD Docking Monitor' }
                    '*PID_016E*' { $Dock_Attached = 8 ; $Dock_ProductName = 'HP E27d G4 QHD Docking Monitor' }
                    '*PID_379D*' { $Dock_Attached = 9 ; $Dock_ProductName = 'HP USB-C G5 Essential Dock' }

                } # switch -Wildcard ( $f_InstalledDeviceID )
            } # if ( $f_InstalledDeviceID -match "VID_03F0")
            if ( $Dock_Attached -gt 0 ) { break }

        } # foreach ( $iDriver in $PnpSignedDrivers )

    #######################################################################################

    Set-Location $CurrLoc

    $Return = @(
        @{Dock_Attached = $Dock_Attached ;  Dock_ProductName = $Dock_ProductName}
    )
    return $Return

}

$HPFIrmwareUpdateReturnValues = @(
        @{Code = "0" ;  Message = "Success"}
        @{Code = "101" ;  Message = "Install or stage failed. One or more firmware failed to install."}
        @{Code = "102" ;  Message = "Configuration file failed to be loaded.This may be because it could not be found or that it was not properly formatted."}
        @{Code = "103" ;  Message = "One or more firmware packages specified in the configuration file could not be loaded."}
        @{Code = "104" ;  Message = "No devices could be communicated with.This could be because necessary drivers are missing to detect the device."}
        @{Code = "105" ;  Message = "Out - of - date firmware detected when running with 'check' flag."}
        @{Code = "106" ;  Message = "An instance of HP Firmware Installer is already running"}
        @{Code = "107" ;  Message = "Device not connected.This could be because PID or VID is not detected."}
        @{Code = "108" ;  Message = "Force option disabled.Firmware downgrade or re - flash not possible on this device."}
        @{Code = "109" ;  Message = "The host is not able to update firmware"}
    )
$Dock = Get-HPDockInfo
[int]$Counter = 0
[int]$StepAmt = 30
if ($Dock.Dock_Attached -eq "0"){
    Write-Host "Waiting for Dock to be fully attached up to $WaitTimer seconds" -ForegroundColor Green
    do {
        
        Write-Host " Waited $Counter Seconds Total.. waiting additional $StepAmt" -ForegroundColor Gray
        $counter += $StepAmt
        Start-Sleep -Seconds $StepAmt
        $Dock = Get-HPDockInfo
        if ($counter -eq $WaitTimer){
            Write-Host "Waited $WaitTimer Seconds, no dock found yet..." -ForegroundColor Red
            
        }
    }
    while (($counter -lt $WaitTimer) -and ($Dock.Dock_Attached -eq "0"))
}

if (!($Dock.Dock_Attached -eq "0")){  #Only runs if there is a dock attached
    Write-Host "Found Dock: $($Dock.Dock_ProductName)" -ForegroundColor Green
    if ($Dock.Dock_Attached -eq "9"){ #Runs if HP USB-C G5 Essential Dock
        
        #WebPage: https://support.hp.com/us-en/drivers/selfservice/swdetails/hp-usb-c-g5-essential-dock/2101469887/swItemId/ob-303496-1

        #$URL = "https://ftp.hp.com/pub/softpaq/sp143001-143500/sp143198.exe" # Previous Version 01.00.05.00
        $URL = "https://ftp.hp.com/pub/softpaq/sp144501-145000/sp144502.exe" #01.00.06.00 Rev.A | Jan 10, 2023
        
        $SPEXE = ($URL.Split("/") | Select-Object -Last 1)
        $SPNumber = ($URL.Split("/") | Select-Object -Last 1).replace(".exe","")
    }
    #Create Required Folders
    $OutFilePath = "$env:SystemDrive\swsetup\dockfirmware"
    $ExtractPath = "$OutFilePath\$SPNumber"
    try {
        [void][System.IO.Directory]::CreateDirectory($OutFilePath)
        [void][System.IO.Directory]::CreateDirectory($ExtractPath)
        }
    catch {throw}
    Start-Transcript -Path "$OutFilePath\$SPNumber.txt"
    if (!(Test-Path "$OutFilePath\$SPEXE")){ #Download Softpaq EXE
        try {
        Write-Host "  Starting Download of $URL to $OutFilePath\$SPEXE" -ForegroundColor Magenta
        Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile "$OutFilePath\$SPEXE"
        }
        catch {
            Write-Host "!!!Failed to download Softpaq!!!" -ForegroundColor red
        }
    }
    else {
        Write-Host "  Softpaq already downloaded to $OutFilePath\$SPEXE" -ForegroundColor Gray
    }
    if (Test-Path "$OutFilePath\$SPEXE"){ #Extract Softpaq EXE
        if (!(Test-Path "$OutFilePath\$SPNumber\HPFirmwareInstaller.exe")){
            Write-Host "  Extracting to $ExtractPath" -ForegroundColor Magenta
            $Extract = Start-Process -FilePath "$OutFilePath\$SPEXE" -ArgumentList "/s /e /f $ExtractPath" -NoNewWindow -PassThru -Wait
        }
        else {
            `Write-Host "  Softpaq already Extracted  to $ExtractPath" -ForegroundColor Gray
        }

    }
    else {
        Write-Host "  Failed to find $OutFilePath\$SPEXE" -ForegroundColor Red

    }
    if (Test-Path "$OutFilePath\$SPNumber\config.ini"){
        $ConfigInfo = Get-Content -Path "$OutFilePath\$SPNumber\config.ini"
        [String]$PackageVersion = $ConfigInfo | Select-String -Pattern 'PackageVersion' -CaseSensitive -SimpleMatch
        $PackageVersion = $PackageVersion.Split("=") | Select-Object -Last 1
        [String]$ModelName = $ConfigInfo | Select-String -Pattern 'ModelName' -CaseSensitive -SimpleMatch
        $ModelName = $ModelName.Split("=") | Select-Object -Last 1
        Write-Host "Extracted Softpaq Info: $OutFilePath\$SPNumber\config.ini" -ForegroundColor Cyan
        Write-Host " Device: $ModelName" -ForegroundColor Gray
        Write-Host " Version: $PackageVersion" -ForegroundColor Gray
        }

    if (Test-Path "$OutFilePath\$SPNumber\HPFirmwareInstaller.exe"){ #Run Test only - Check if Update Required
        Write-Host " Running HP Firmware Check" -ForegroundColor Magenta
        $HPFirmwareTest = Start-Process -FilePath "$OutFilePath\$SPNumber\HPFirmwareInstaller.exe" -ArgumentList "-C" -PassThru -Wait -NoNewWindow


        if ($HPFirmwareTest.ExitCode -eq "0"){
            Write-Host " Dock Firmware already Current" -ForegroundColor Green
            $TestInfo = Get-Content -Path "$OutFilePath\$SPNumber\HPFI_Version_Check.txt"
            [String]$InstalledVersion = $TestInfo | Select-String -Pattern 'Installed' -SimpleMatch
            $InstalledVersion = $InstalledVersion.Split(":") | Select-Object -Last 1
            Write-Host " Installed Version: $InstalledVersion" -ForegroundColor Green
        }
        elseif ($HPFirmwareTest.ExitCode -eq "105"){ #Update required
            Write-Host "Update Required" -ForegroundColor Yellow
            $TestInfo = Get-Content -Path "$OutFilePath\$SPNumber\HPFI_Version_Check.txt"
            [String]$InstalledVersion = $TestInfo | Select-String -Pattern 'Installed' -SimpleMatch
            $InstalledVersion = $InstalledVersion.Split(":") | Select-Object -Last 1

            Write-Host " Installed Version: $InstalledVersion" -ForegroundColor Yellow
            Write-Host " Starting Dock Firmware Update" -ForegroundColor Magenta
            $HPFirmwareUpdate = Start-Process -FilePath "$OutFilePath\$SPNumber\HPFirmwareInstaller.exe" -ArgumentList "$mode" -PassThru -Wait -NoNewWindow
            $ExitInfo = $HPFIrmwareUpdateReturnValues | Where-Object {$_.Code -eq $HPFirmwareUpdate.ExitCode}
            if ($ExitInfo.Code -eq "0"){
                Write-Host "Update Successful!" -ForegroundColor Green
            }
            else {
                Write-Host "Update Failed" -ForegroundColor Red
                Write-Host " Exit Code: $($ExitInfo.Code)" -ForegroundColor Gray
                Write-Host " $($ExitInfo.Message)" -ForegroundColor Gray
            }
        }
    }
    Stop-Transcript
}
else {
    Write-Host "No Dock Attached Currently" -ForegroundColor Gray
}
