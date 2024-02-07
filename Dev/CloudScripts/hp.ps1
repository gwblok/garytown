##=============================================================================
#region SCRIPT DETAILS - Dev
#=============================================================================

<#
.SYNOPSIS
Runs a menu on OSDCloud allowing techs to deploy a machine with Chosen Enterprise image
.EXAMPLE
PS C:\> Invoke-OSDCloudDev.ps1
#>

#=============================================================================
#endregion
#=============================================================================
#=============================================================================
#Varibles
#=============================================================================

$Machine = Get-MyComputerModel #Needed for $SupportedModels Check
$SupportedModels =
### HP Laptops Models ###
'HP EliteBook 845 G8 Notebook PC',
'HP EliteBook x360 1040 G6',
'HP Elite x360 1040 14 inch G9 2-in-1 Notebook PC',
'HP Elite x360 1040 14 inch G10 2-in-1 Notebook PC',
'HP ZBook Fury 15 G7 Mobile Workstation',
'HP ZBook Fury 16 G10 Mobile Workstation PC',
### HP Towers ###
'HP EliteDesk 800 G5 SFF',
'HP EliteDesk 800 G6 Desktop Mini PC',
'HP Z2 Tower G5 Workstation',
'HP Z2 Tower G9 Workstation Desktop PC',
### Virtual Machines ###
'Virtual Machine',
'VMware7,1'

#=============================================================================
#region FUNCTIONS
#=============================================================================
function Format-OSDCloudGUI {
    <#
    .SYNOPSIS
    Synopsis

    .EXAMPLE
    Format-OSDCloudGUI

    .INPUTS
    None
    You cannot pipe objects to Format-OSDCloudGUI.

    .OUTPUTS
    None
    The cmdlet does not return any output.
    #>

    [CmdletBinding()]
    Param()
    Import-Module OSD -Force


    #Set OSDCloud Vars

    #Customize the OSDCloud Defaults
    $OSDModuleResource.OSDCloud.Default.Activation = 'Volume'
    $OSDModuleResource.OSDCloud.Default.Edition = 'Enterprise'
    $OSDModuleResource.OSDCloud.Default.ImageIndex = '6'
    $OSDModuleResource.OSDCloud.Default.Language = 'en-us'
    $OSDModuleResource.OSDCloud.Default.Name = 'Windows 10 22H2 x64'
    $OSDModuleResource.OSDCloud.Default.ReleaseID = '22H2'
    $OSDModuleResource.OSDCloud.Default.Version = 'Windows 10'
    #Customize the OSDCloud Values
    $OSDModuleResource.OSDCloud.Values.Activation = 'Volume'
    $OSDModuleResource.OSDCloud.Values.Edition = 'Enterprise'
    $OSDModuleResource.OSDCloud.Values.Language = 'en-us'
    $OSDModuleResource.OSDCloud.Values.Name = 'Windows 10 22H2 x64','Windows 11 22H2 x64','Windows 11 23H2 x64'
    #Customize the OSDCloudGUI Branding
    $OSDModuleResource.StartOSDCloudGUI.BrandColor = 'Blue'
    $OSDModuleResource.StartOSDCloudGUI.BrandName = 'OSDCloudGUIDev'
    #Customize the OSDCloud Preferences
    $OSDModuleResource.StartOSDCloudGUI.ClearDiskConfirm = $false
    $OSDModuleResource.StartOSDCloudGUI.restartComputer = $false
    $OSDModuleResource.StartOSDCloudGUI.updateDiskDrivers = $true
    $OSDModuleResource.StartOSDCloudGUI.updateFirmware = $false
    $OSDModuleResource.StartOSDCloudGUI.updateSCSIDrivers = $true
    #Newer Options to Test
    $OSDModuleResource.StartOSDCloudGUI.WindowsUpdate = $true
    $OSDModuleResource.StartOSDCloudGUI.WindowsUpdateDrivers = $true
    $OSDModuleResource.StartOSDCloudGUI.HPIADrivers = $true
    $OSDModuleResource.StartOSDCloudGUI.HPIAFirmware = $true


    #Start OSDCloudGUI
    Start-OSDCloudGUIDev

}
function Invoke-OSDCloud {
    <#
    .SYNOPSIS
    Synopsis
    .EXAMPLE
    Invoke-OSDCloud
    .INPUTS
    None
    You cannot pipe objects to Invoke-OSDCloud.
    .OUTPUTS
    None
    The cmdlet does not return any output.
    #>

    [CmdletBinding()]
    Param()

    if ($SupportedModels -ccontains $Machine  ) {
        #Starting the Custom Gui
        if ($Machine -eq 'VMware7,1' ) {
            $Cmdlet = 'Start-OSDCloud'
            $Argus = "-OSName 'Windows 11 22H2 x64' -OSEdition Enterprise -Manufacturer 'VMware, Inc.' -Product 'VMware7,1' -Firmware -SkipAutopilot -OSActivation Volume -SkipODT -OSLanguage 'en-us' -ZTI -Verbose"
            Start-Process powershell "-noprofile -executionpolicy Bypass -Command $Cmdlet $Argus" -Wait
        } else {
            #Starting the Custom Gui
            Format-OSDCloudGUI
        }
    }
}

#=============================================================================
#endregion
#=============================================================================
#region EXECUTION
#=============================================================================

#Invoking the GUI
Invoke-OSDCloud

#Restart from WinPE
Write-Host -ForegroundColor Cyan 'Restarting in 20 seconds!'
Start-Sleep -Seconds 20
#wpeutil reboot

#=============================================================================
#endregion
#=============================================================================
