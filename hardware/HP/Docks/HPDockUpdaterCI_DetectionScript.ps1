#ConfigMgr Detection Script for CI
# NOT DISCOVERY SCRIPT

function Get-HPDockInfo {
        [CmdletBinding()]
        param($pPnpSignedDrivers)

        #######################################################################################
        $Dock_Attached = 0      # default: no dock found
        $Dock_ProductName = $null
        $Dock_Url = $null   
        # Find out if a Dock is connected - assume a single dock, so stop at first find
        foreach ( $iDriver in $pPnpSignedDrivers ) {
            $f_InstalledDeviceID = "$($iDriver.DeviceID)"   # analyzing current device
            if ( ($f_InstalledDeviceID -match "HID\\VID_03F0") -or ($f_InstalledDeviceID -match "USB\\VID_17E9") ) {
                switch -Wildcard ( $f_InstalledDeviceID ) {
                    '*PID_0488*' { $Dock_Attached = 1 ; $Dock_ProductName = 'HP Thunderbolt Dock G4' }
                    '*PID_0667*' { $Dock_Attached = 2 ; $Dock_ProductName = 'HP Thunderbolt Dock G2' }
                    '*PID_484A*' { $Dock_Attached = 3 ; $Dock_ProductName = 'HP USB-C Dock G4' }
                    '*PID_046B*' { $Dock_Attached = 4 ; $Dock_ProductName = 'HP USB-C Dock G5' }
                    #'*PID_600A*' { $Dock_Attached = 5 ; $Dock_ProductName = 'HP USB-C Universal Dock' }
                    '*PID_0A6B*' { $Dock_Attached = 6 ; $Dock_ProductName = 'HP USB-C Universal Dock G2' }
                    '*PID_056D*' { $Dock_Attached = 7 ; $Dock_ProductName = 'HP E24d G4 FHD Docking Monitor' }
                    '*PID_016E*' { $Dock_Attached = 8 ; $Dock_ProductName = 'HP E27d G4 QHD Docking Monitor' }
                    '*PID_379D*' { $Dock_Attached = 9 ; $Dock_ProductName = 'HP USB-C G5 Essential Dock' }
                } # switch -Wildcard ( $f_InstalledDeviceID )
            } # if ( $f_InstalledDeviceID -match "VID_03F0")
            if ( $Dock_Attached -gt 0 ) { break }
        } # foreach ( $iDriver in $gh_PnpSignedDrivers )
        #######################################################################################

        return @(
            @{Dock_Attached = $Dock_Attached ;  Dock_ProductName = $Dock_ProductName}
        )
    }

#'-- Reading signed drivers list - use to scan for attached HP docks'
$PnpSignedDrivers = Get-CimInstance win32_PnpSignedDriver 

$Dock = Get-HPDockInfo $PnpSignedDrivers

if ($Dock.Dock_Attached -ne 0){
    Write-Output "$($Dock.Dock_ProductName )"
}
