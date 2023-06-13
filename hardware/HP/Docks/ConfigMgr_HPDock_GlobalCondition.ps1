<#Used as a global condition to detect if a Dock is attached.
Used for Application Model when deploying Firmware to Devices with Dock.
Can set the global condition on the device to ensure a specific dock is attached to device.

https://garytown.com/hp-docks-update-via-configmgr-app-model
https://garytown.com/hp-dock-configmgr-global-condition
#>
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

$DockInfo = Get-HPDockInfo
$DockInfo.Dock_Attached
