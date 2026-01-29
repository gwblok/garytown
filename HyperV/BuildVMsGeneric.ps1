<# @GWBLOK | 2Pint Software

This Script needs to run on the HYPERV Host you want to create the VMs
Make sure you have at least 1 External Switch created in HyperV Manager named "External"
Copy your ISO to the HyperV Folder which you pre-create or this script will create, usually C:\HyperV, D:\HyperV, or E:\HyperV depending on available drives.
- This script will check that location for ISO files to pick from if you select the ISO Boot Method.


This script will...
- Uses the provided information below to...
- Create folder structure on C,D, or E drive (wherever HyperVLab-Clients folder is found or created in order of D, E, C)
- Check if available names are available in HyperV
- Find the numbers of Names you want based on your Desired VMs, leveraging the Starting Number & EndNumber
- Create VMs in $VMPath
- Memory, 4096 Static (not Dynamic)
- 4 Logical Processors
- Adds Network of $VMSwitch
- Adds Boot ISO
- Will set the Boot Order to ISO (I currently have commented out so It will PXE Boot)
- Create 100GB HD 
- Start VM for 10 Seconds and Turn off
- Wait $TimeBetweenKickoff to start each VM for imaging.

#>


# REQUIRED INPUT VARIABLES:
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter()]
    [int]
    $DesiredVMs = 2,

    [Parameter()]
    [int]
    $WaitBetweenNext = 1,

    [Parameter()]
    [int64]
    $StartingMemory = 4 * 1024 * 1024 * 1024,

    [Parameter()]
    [int64]
    $DriveSize = 100 * 1024 * 1024 * 1024,

    [Parameter()]
    [int]
    $ProcessorCount = 4,

    [Parameter()]
    [int]
    $StartNumber = 1,

    [Parameter()]
    [int]
    $EndNumber = 20,

    [Parameter()]
    [string]
    $VMNamePreFix = "VM-OSD-",

    [Parameter()]
    [switch]
    $Interactive,

    [Parameter()]
    [ValidateSet('iPXE','ISO')]
    [string]
    $BootMethod = 'ISO'
)

Set-StrictMode -Version Latest

# Container for created VM info
$CreatedVMs = @()

# Search for HyperVLab-Clients folder across all available volumes
$availableVolumes = Get-Volume | Where-Object {$_.DriveLetter -and $_.DriveType -eq 'Fixed'} | Sort-Object DriveLetter
$foundPaths = @()

foreach ($volume in $availableVolumes) {
    $testPath = "$($volume.DriveLetter):\HyperVLab-Clients"
    if (Test-Path -Path $testPath) {
        $foundPaths += [PSCustomObject]@{
            DriveLetter = $volume.DriveLetter
            VMPath = $testPath
            HyperVHostRootPath = "$($volume.DriveLetter):\HyperV"
        }
    }
}

if ($foundPaths.Count -gt 1) {
    # Check if only C and D drives exist
    $driveLetters = ($availableVolumes | Select-Object -ExpandProperty DriveLetter) | Sort-Object
    if (($driveLetters.Count -eq 2) -and ($driveLetters -contains 'C') -and ($driveLetters -contains 'D')) {
        # Auto-default to D drive
        $selectedPath = $foundPaths | Where-Object {$_.DriveLetter -eq 'D'}
        Write-Host "Auto-selecting D:\HyperVLab-Clients (C & D drives detected)" -ForegroundColor Yellow
    }
    else {
        # Prompt user to select
        Write-Host "Multiple HyperVLab-Clients folders found:" -ForegroundColor Yellow
        $selectedPath = $foundPaths | Out-GridView -Title "Select HyperVLab-Clients Location" -PassThru
    }
    $VMPath = $selectedPath.VMPath
    $HyperVHostRootPath = $selectedPath.HyperVHostRootPath
}
elseif ($foundPaths.Count -eq 1) {
    # Only one found, use it
    $VMPath = $foundPaths[0].VMPath
    $HyperVHostRootPath = $foundPaths[0].HyperVHostRootPath
}
else {
    # No existing folders found, create default based on available drives
    if (Test-Path -Path "D:\") {
        $VMPath = "D:\HyperVLab-Clients"
        $HyperVHostRootPath = "D:\HyperV"
    }
    elseif (Test-Path -Path "E:\") {
        $VMPath = "E:\HyperVLab-Clients"
        $HyperVHostRootPath = "E:\HyperV"
    }
    else {
        $VMPath = "C:\HyperVLab-Clients"
        $HyperVHostRootPath = "C:\HyperV"
    }
}

$ISOFolderPath = $HyperVHostRootPath
Write-Host "HyperV Lab Clients Path: $VMPath" -ForegroundColor Green
Write-Host "HyperV Root Tools Path: $HyperVHostRootPath" -ForegroundColor Green
Write-Host "ISO Path: $ISOFolderPath" -ForegroundColor Green
try {
    [void][System.IO.Directory]::CreateDirectory($VMPath)
    [void][System.IO.Directory]::CreateDirectory($HyperVHostRootPath)
}
catch {throw}

# Get Boot Method of VM Creation
if ($Interactive) {
    $BootMethod = ("iPXE","ISO" | Out-GridView -Title "Select the Boot Process you plan to use" -PassThru)
}

if ($BootMethod -eq 'ISO') {
    Write-Host "ISO Boot Method selected" -ForegroundColor Green
    if (Test-Path -Path $ISOFolderPath) {
        Write-Host "ISO Folder Path Found: $ISOFolderPath" -ForegroundColor Green
        if ($Interactive) {
            $ISList = Get-ChildItem -Path $ISOFolderPath -Filter *.iso | Out-GridView -Title "Pick Boot Media ISO" -PassThru
            if ($ISList) { $BootISO = $ISList[0].FullName }
            else { Write-Warning "No ISO selected. Continuing without boot ISO."; $BootISO = $null }
        }
        else {
            # non-interactive: pick first ISO if present
            $BootISO = (Get-ChildItem -Path $ISOFolderPath -Filter *.iso | Select-Object -First 1).FullName
            if (-not $BootISO) { Write-Warning "No ISO found in $ISOFolderPath; switching to iPXE"; $BootMethod = 'iPXE' }
        }
    }
    else {
        Write-Warning "ISO Folder Path NOT Found: $ISOFolderPath - switching to iPXE"
        $BootMethod = 'iPXE'
    }
}
else {
    Write-Host "iPXE Boot Method selected" -ForegroundColor Green
}


## note: $StartNumber, $EndNumber and $VMNamePreFix moved into param() block

$VMNamePreFix = $VMNamePreFix
if (!(Test-Path -Path $VMPath))
{
    Write-Host "HyperV Path not Set correctly!" -ForegroundColor Red
    Throw "Stopping"
}

#Get Name of VMs Currently in HyperV
$CurrentVMS = (Get-VM -ErrorAction SilentlyContinue | Where-Object {$_.Name -match $VMNamePreFix}) #Grab all VMs on host that match the PreFix
$Usable = 0
$NameTable = @()

# Get VM Switches (Make sure you have at least 1 External Switch created in HyperV Manager)
$VMSwitches = @(Get-VMSwitch | Where-Object { $_.SwitchType -eq 'External' })

switch ($VMSwitches.Count) {
    0 {
        Write-Host "No external Virtual Switch found. Check Hyper-V network configuration." -ForegroundColor Red
        Throw "Stopping"
        break
    }
    1 {
        $VMSwitch = $VMSwitches[0]
        Write-Host "Found single External Virtual Switch: $($VMSwitch.Name)" -ForegroundColor Green
        break
    }
    default {
        Write-Host "Multiple External Virtual Switches found; prompting for selection" -ForegroundColor Yellow
        if ($Interactive) {
            $VMSwitch = $VMSwitches | Out-GridView -Title 'Select Virtual Switch' -PassThru
        }
        else {
            Write-Host "Non-interactive mode: selecting first External switch: $($VMSwitches[0].Name)" -ForegroundColor Yellow
            $VMSwitch = $VMSwitches[0]
        }
        break
    }
}

# Run this loop until it finds enough names to use to create the desired amount of VMs you want
# (unless you run out of available values - EndNumber)
    do {
        $StartNumberPad = "{0:00}" -f $StartNumber
        #Checks for if Machine Name already exist in HyperV Host
        if (("$($VMNamePreFix)$($StartNumberPad)" -in ($CurrentVMS.name)) -or ("$($VMNamePreFix)$($StartNumberPad)A" -in ($CurrentVMS.name)))
        {
            if ("$($VMNamePreFix)$($StartNumberPad)" -in ($CurrentVMS.name)){ 
                Write-Host "Name $($VMNamePreFix)$($StartNumberPad) Exist on HyperV Host" -ForegroundColor Yellow
            }
            if ("$($VMNamePreFix)$($StartNumberPad)A" -in ($CurrentVMS.name)){ 
                Write-Host "Name $($VMNamePreFix)$($StartNumberPad)A Exist on HyperV Host" -ForegroundColor Yellow
            }
        }
        else{
            $Usable++
            $NameTable += "$($VMNamePreFix)$($StartNumberPad)"
        }
        $StartNumber = $StartNumber + 1

        if ($Usable -eq $DesiredVMs){ break }
    }
    while ($StartNumber -le $EndNumber)
    
    
    # Create the VMs on this HYPER V Hosts
    foreach ($VMName in $NameTable) {
        # Build paths safely
        $VMFolder = Join-Path -Path $VMPath -ChildPath $VMName
        $VHDxFile = Join-Path -Path $VMFolder -ChildPath "$VMName.vhdx"

        Write-Host "Creating VM $VMName" -ForegroundColor Cyan

        if ($PSCmdlet.ShouldProcess("VM: $VMName", "Create VM and VHD")) {
            try {
                New-Item -ItemType Directory -Path $VMFolder -Force | Out-Null

                # Create VM
                $NewVM = New-VM -Name $VMName -Path $VMPath -MemoryStartupBytes $StartingMemory -BootDevice CD -SwitchName $VMSwitch.Name -Generation 2 -ErrorAction Stop

                Write-Host "  Setting Memory to Static $($StartingMemory/1MB) MB" -ForegroundColor Green
                Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false -StartupBytes $StartingMemory -ErrorAction Stop

                Write-Host "  Creating VHDx ($($DriveSize/1GB) GB) at $VHDxFile" -ForegroundColor Green
                $NewVHD = New-VHD -Path $VHDxFile -SizeBytes $DriveSize -Dynamic -ErrorAction Stop
                Add-VMHardDiskDrive -VMName $VMName -Path $VHDxFile -ErrorAction Stop

                $vmSerial = (Get-CimInstance -Namespace root\virtualization\v2 -class Msvm_VirtualSystemSettingData | ? { ($_.VirtualSystemType -eq "Microsoft:Hyper-V:System:Realized") -and ($_.elementname -eq $VMName )} | Select-Object -First 1).BIOSSerialNumber
                if ($vmSerial) { Get-VM -Name $VMName | Set-VM -Notes "Serial# $vmSerial" -ErrorAction SilentlyContinue }
            }
            catch {
                Write-Warning "Failed to create VM or VHD for $VMName $($_.Exception.Message)"
                continue
            }
        }
        else {
            Write-Host "Skipping creation of $VMName due to WhatIf/ShouldProcess" -ForegroundColor Yellow
            continue
        }
        
        #If Host is able, then set TPM on VM (cache result)
        $tpm = Get-Command Get-TPM -ErrorAction SilentlyContinue
        if ($tpm) {
            $tpmStatus = Get-TPM -ErrorAction SilentlyContinue
            if ($tpmStatus -and $tpmStatus.TpmPresent -and $tpmStatus.TpmReady) {
                Write-Host "  Enabling TPM on VM" -ForegroundColor Green
                try { Set-VMSecurity -VMName $VMName -VirtualizationBasedSecurityOptOut:$false -ErrorAction Stop }
                catch { Write-Warning "Set-VMSecurity failed for $VMName $($_.Exception.Message)" }
                try { Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector -ErrorAction Stop }
                catch { Write-Warning "Set-VMKeyProtector failed for $VMName $($_.Exception.Message)" }
                try { Enable-VMTPM -VMName $VMName -ErrorAction Stop }
                catch { Write-Warning "Enable-VMTPM failed for $VMName $($_.Exception.Message)" }
            }
        }

        Write-Host "  Setting Processors to $ProcessorCount" -ForegroundColor Green
        try { Set-VMProcessor -VMName $VMName -Count $ProcessorCount -ErrorAction Stop }
        catch { Write-Warning "Set-VMProcessor failed for $VMName $($_.Exception.Message)" }

        Write-Host "  Setting Video Resolution to 1600x900 (16:9)" -ForegroundColor Green
        try { Set-VMVideo -VMName $VMName -ComputerName $env:COMPUTERNAME -ResolutionType Single -HorizontalResolution 1600 -VerticalResolution 900 -ErrorAction Stop }
        catch { Write-Warning "Set-VMVideo failed for $VMName $($_.Exception.Message)" }
        
        if ($BootMethod -eq 'iPXE'){
            Write-Host "  Setting Secure Boot to Off" -ForegroundColor Green
            try { Set-VMFirmware -EnableSecureBoot Off -VMName $VMName -ErrorAction Stop }
            catch { Write-Warning "Set-VMFirmware failed for $VMName $($_.Exception.Message)" }

            Write-Host "  Setting First Boot Device to Network Adapter" -ForegroundColor Green
            $vmNetworkAdapter = Get-VMNetworkAdapter -VMName $VMName -ErrorAction SilentlyContinue
            if ($vmNetworkAdapter) {
                try { Set-VMFirmware -FirstBootDevice $vmNetworkAdapter -VMName $VMName -ErrorAction Stop }
                catch { Write-Warning "Set-VMFirmware FirstBootDevice failed: $($_.Exception.Message)" }
            }
        }
        else {
            Write-Host "  Setting Boot ISO to $BootISO" -ForegroundColor Green
            if ($BootISO) {
                try { Set-VMDvdDrive -VMName $VMName -Path $BootISO -ErrorAction Stop }
                catch { Write-Warning "Set-VMDvdDrive failed for $VMName $($_.Exception.Message)" }
            }
            else { Write-Warning "No Boot ISO specified for $VMName" }
        }

        # Add Notes
        $DateCreated = "Date Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $MemoryInfo = "Memory: $($StartingMemory / 1MB) MB"
        $CPUInfo = "Processors: $ProcessorCount"
        $StorageInfo = "Storage: $($DriveSize / 1GB) GB"
        $ExtraNotes = $DateCreated + "`n" + $MemoryInfo + "`n" + $CPUInfo + "`n" + $StorageInfo

        if ($ExtraNotes) {
            $CurrentNotes = (Get-VM -Name $VMName | Select-Object -ExpandProperty Notes) -join ""
            if (-not $CurrentNotes) { $CurrentNotes = '' }
            $NewNotes = $CurrentNotes + "`n" + $ExtraNotes
            try { Get-VM -Name $VMName | Set-VM -Notes $NewNotes -ErrorAction Stop }
            catch { Write-Warning "Failed to set Notes for $VMName $($_.Exception.Message)" }
        }
        #THis line below is commented out because I'm skipping adding the ISO and just having it boot to Network Adapter
        
        Write-Host "  Setting CheckPoints to Standard" -ForegroundColor Green
        try { Set-VM -Name $VMName -AutomaticCheckpointsEnabled $false -ErrorAction Stop }
        catch { Write-Warning "Set-VM AutomaticCheckpointsEnabled failed: $($_.Exception.Message)" }
        try { Set-VM -Name $VMName -CheckpointType Standard -ErrorAction Stop }
        catch { Write-Warning "Set-VM CheckpointType failed: $($_.Exception.Message)" }
        Write-Host "  Starting VM to Populate the Dynamic MAC Address" -ForegroundColor Yellow
        try {
            Start-VM -Name $VMName -ErrorAction Stop | Out-Null
            Start-Sleep -Seconds 10
            Stop-VM -Name $VMName -TurnOff -Force -ErrorAction Stop
            $MAC = (Get-VMNetworkAdapter -VMName $VMName -ErrorAction SilentlyContinue).MacAddress
            Write-Host "  MAC: $MAC" -ForegroundColor Green
        }
        catch { Write-Warning "Start/Stop sequence failed for $VMName $($_.Exception.Message)" }

        try { Start-VM -Name $VMName -ErrorAction Stop ; Write-Host "  Started VM $VMName" -ForegroundColor Cyan }
        catch { Write-Warning "Failed to start $VMName $($_.Exception.Message)" }

        if ($NameTable.count -gt 1 -and $VMName -ne $NameTable[-1]){
            if ($WaitBetweenNext){
                Write-Host  "  Waiting $WaitBetweenNext minute(s) before starting next VM..." -ForegroundColor DarkGray
                Start-Sleep -Seconds ($WaitBetweenNext * 60)
            }
        }

        # Record created VM details for output
        $CreatedVMs += [PSCustomObject]@{
            Name = $VMName
            VHDPath = $VHDxFile
            Serial = $vmSerial
            MAC = $MAC
            BootMethod = $BootMethod
        }
    }

# Output created VMs
if ($CreatedVMs.Count -gt 0) { $CreatedVMs }


