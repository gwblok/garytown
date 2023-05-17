<#PSScriptInfo
.VERSION 22.5.19.1
.GUID 57f30acf-8336-4519-9971-1d71d261f197
.AUTHOR David Segura @SeguraOSD
.COMPANYNAME osdcloud.com
.COPYRIGHT (c) 2022 David Segura osdcloud.com. All rights reserved.
.TAGS OSDeploy OSDCloud WinPE OOBE Windows AutoPilot
.LICENSEURI 
.PROJECTURI https://github.com/OSDeploy/OSD
.ICONURI 
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
Script should be executed in a Command Prompt using the following command
powershell Invoke-Expression -Command (Invoke-RestMethod -Uri https://raw.githubusercontent.com/gwblok/garytown/master/Dev/CloudScripts/lightaria.ps1)
This is abbreviated as
powershell iex(irm go.osdcloud.com/enterprise)
#>
<#
.SYNOPSIS
    PSCloudScript at go.osdcloud.com/enterprise
.DESCRIPTION
    PSCloudScript at go.osdcloud.com/enterprise
.NOTES
    Version 22.5.19.1
.LINK
    https://raw.githubusercontent.com/gwblok/garytown/master/Dev/CloudScripts/lightaria.ps1
.EXAMPLE
    powershell iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/Dev/CloudScripts/lightaria.ps1)
#>
[CmdletBinding()]
param()
#=================================================
#Script Information
$ScriptName = 'go.osdcloud.com/enterprise'
$ScriptVersion = '22.5.19.1'
#=================================================

function Get-HyperVName {
    [CmdletBinding()]
    param ()
    if ($WindowsPhase -eq 'WinPE'){
        Write-host "Unable to get HyperV Name in WinPE"
    }
    else{
        if (((Get-CimInstance Win32_ComputerSystem).Model -eq "Virtual Machine") -and ((Get-CimInstance Win32_ComputerSystem).Manufacturer -eq "Microsoft Corporation")){
            $HyperVName = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters' -Name "VirtualMachineName" -ErrorAction SilentlyContinue
        }
    return $HyperVName
    }
}


#region Initialize

#Start the Transcript
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-OSDCloud.log"
$null = Start-Transcript -Path (Join-Path "$env:SystemRoot\Temp" $Transcript) -ErrorAction Ignore

#Determine the proper Windows environment
if ($env:SystemDrive -eq 'X:') {$WindowsPhase = 'WinPE'}
else {
    $ImageState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Ignore).ImageState
    if ($env:UserName -eq 'defaultuser0') {$WindowsPhase = 'OOBE'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE') {$WindowsPhase = 'Specialize'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT') {$WindowsPhase = 'AuditMode'}
    else {$WindowsPhase = 'Windows'}
}

#Finish initialization
Write-Host -ForegroundColor DarkGray "$ScriptName $ScriptVersion $WindowsPhase"

#Load OSDCloud Functions
Invoke-Expression -Command (Invoke-RestMethod -Uri functions.osdcloud.com)

#endregion
#=================================================
#region WinPE
if ($WindowsPhase -eq 'WinPE') {

    #Process OSDCloud startup and load Azure KeyVault dependencies
    osdcloud-StartWinPE -OSDCloud -KeyVault

    #Write-Host -ForegroundColor Cyan "To start a new PowerShell session, type 'start powershell' and press enter"
    #Write-Host -ForegroundColor Cyan "Start-OSDCloud or Start-OSDCloudGUI can be run in the new PowerShell session"
    #Stop the startup Transcript.  OSDCloud will create its own
    $null = Stop-Transcript -ErrorAction Ignore

    #Start OSDCloud and pass all the parameters except the Language to allow for prompting
    Start-OSDCloud -OSVersion 'Windows 10' -OSBuild 21H2 -OSEdition Enterprise -OSLicense Volume -SkipAutopilot -SkipODT -Restart
}
#endregion
#=================================================
#region Specialize
if ($WindowsPhase -eq 'Specialize') {
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion
#=================================================
#region AuditMode
if ($WindowsPhase -eq 'AuditMode') {
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion
#=================================================
#region OOBE
if ($WindowsPhase -eq 'OOBE') {

    #Load everything needed to run AutoPilot and Azure KeyVault
    osdcloud-StartOOBE -Display -Language -DateTime -Autopilot -KeyVault

    #Get Autopilot information from the device
    $TestAutopilotProfile = osdcloud-TestAutopilotProfile

    #If the device has an Autopilot Profile
    if ($TestAutopilotProfile -eq $true) {
        #osdcloud-ShowAutopilotProfile
    }
    #If not, need to register the device using the Enterprise GroupTag and Assign it
    elseif ($TestAutopilotProfile -eq $false) {
        if (((Get-CimInstance Win32_ComputerSystem).Model -eq "Virtual Machine") -and ((Get-CimInstance Win32_ComputerSystem).Manufacturer -eq "Microsoft Corporation")){
            write-host "This is a HyperV VM, Attempting to retrieve HyperV VM Name from Host"  -ForegroundColor Cyan
            $HyperVName = Get-HyperVName
            if ($HyperVName){
            Write-Host "Setting Name to $HyperVName" -ForegroundColor Gray
                rename-computer -NewName $HyperVName -Force
                $AutopilotRegisterCommand = 'Get-WindowsAutopilotInfo -Online -GroupTag HPAEMProd -Assign -AssignedComputerName $HyperVName'
                write-host -ForegroundColor Gray '$AutopilotRegisterCommand'" = Get-WindowsAutopilotInfo -Online -GroupTag HPAEMPRod -Assign -AssignedComputerName $HyperVName"
            }
        }
        
        else{
            $AutopilotRegisterCommand = 'Get-WindowsAutopilotInfo -Online -GroupTag HPAEMProd -Assign'
            write-host -ForegroundColor Gray '$AutopilotRegisterCommand = Get-WindowsAutopilotInfo -Online -GroupTag HPAEMProd -Assign'
            }
        $AutopilotRegisterProcess = osdcloud-AutopilotRegisterCommand -Command $AutopilotRegisterCommand;Start-Sleep -Seconds 30
    }
    #Or maybe we just can't figure it out
    else {
        Write-Warning 'Unable to determine if device is Autopilot registered'
    }
    osdcloud-RemoveAppx -Basic
    #osdcloud-Rsat -Basic
    osdcloud-NetFX
    osdcloud-UpdateDrivers
    osdcloud-UpdateDefenderStack
    osdcloud-UpdateWindows
    if ($AutopilotRegisterProcess) {
        Write-Host -ForegroundColor Cyan 'Waiting for Autopilot Registration to complete'
        #$AutopilotRegisterProcess.WaitForExit()
        if (Get-Process -Id $AutopilotRegisterProcess.Id -ErrorAction Ignore) {
            Wait-Process -Id $AutopilotRegisterProcess.Id
        }
    }
    $null = Stop-Transcript -ErrorAction Ignore
    osdcloud-RestartComputer
}
#endregion
#=================================================
#region Windows
if ($WindowsPhase -eq 'Windows') {

    #Load OSD and Azure stuff

    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_oobe.psm1')
    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_anywhere.psm1')
    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_oobewin.psm1')
    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/autopilot.psm1')
    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/defender.psm1')
     
    osdcloud-SetExecutionPolicy
    osdcloud-InstallPackageManagement
    osdcloud-InstallModuleKeyVault
    osdcloud-InstallModuleOSD
    osdcloud-InstallModuleAzureAD
    
    osdcloud-RemoveAppx -Basic
    osdcloud-UpdateDefenderStack
    osdcloud-NetFX
    
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion
#=================================================
