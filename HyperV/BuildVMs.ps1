<# @GWBLOK | Recast Software | GARYTOWN

This Script needs to run on the HYPERV Host you want to create the VMs

This script will...
- Uses the provided information below to...
  - Check if available names are available in HyperV
  - Check if available names are available in CM
  - Find the numbers of Names you want based on your Desired VMs, leveraging the Starting Number & EndNumber
  - Create VMs in $VMPath
    - Starting RAM = 2048 - Changed from 1024 after Memory issues during OSD
    - Dynamic Memory, 1024 - 2048
    - Two Logical Processors
    - Adds Network of $VMSwitch
    - Adds Boot ISO
    - Will set the Boot Order to ISO (I currently have commented out so It will PXE Boot)
    - Create 100GB HD 
    - Start VM for 10 Seconds and Turn off
    - Grab Mac Address from machine (which reguired the machine being turned on for HyperV to generate)
    - Create a CM Object using the a Name in the available list and assigning the MAC Address to it
    - Add the Machine to Collection $RequiredDeploymentCollectionName
    - Trigger Collection Eval on All Systems & $RequiredDeploymentCollectionName
    - Wait $TimeBetweenKickoff to start each VM for imaging.

#>


# REQUIRED INPUT VARIABLES:
[int]$DesiredVMs = 1  #The Number of VMs that are going to be created this run.
[int]$WaitBetweenNext = 15 #Time in Minutes before starting the next VM - works nice if you don't want to kill your WAN while creating OSDCloud machines.

[int64]$StartingMemory = 4 * 1024 * 1024 * 1024  #4GB - Static Memory (not dynamic)
#[int64]$DynamicMemoryLow = 4 * 1024 * 1024 * 1024 #4GB - Not used (static memory)
#[int64]$DynamicMemoryHigh = 4 * 1024 * 1024 * 1024 #6GB - Not used (static memory)
[int64]$DriveSize = 100 * 1024 * 1024 * 1024 #100GB
[int]$ProcessorCount = 4

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

#Set the CMModule Path, I have it copied to my local machine:
$CMModulePath = "$HyperVHostRootPath\CMConsolePosh\ConfigurationManager.psd1"

#Test My Personal Server to see if the Module is there:
if (Test-Path "\\src\src$\Apps\Microsoft\ConfigurationManager\CMConsolePosh\ConfigurationManager.psd1")
    {
    $CMModulePath = "\\src\src$\Apps\Microsoft\ConfigurationManager\CMConsolePosh\ConfigurationManager.psd1"
}

$VMNamePreFix = "VM-CM-"  #The VM will start with this name



#$BootISO = "C:\HyperV\StifleR_24H2_x64_Automated.iso"  #If you're booting to an ISO, put the location here.
$ISList = Get-ChildItem -Path $ISOFolderPath -Filter *.iso | Out-GridView -Title "Pick Boot Media ISO" -PassThru

if ($ISList) {
    $BootISO = $ISList[0].FullName
}
else {
    Write-Host "No ISO selected or found. Continuing without boot ISO." -ForegroundColor Yellow
    $BootISO = $null
}

#Get Sitecode from ISO name
#$ProviderMachineName = ($BootISO.Split("_")[5]).replace("iso","2p.garytown.com")
$ProviderMachineName = "2CM.2p.garytown.com"

if ($BootISO) {
    $SiteCode = $BootISO.Split("_")[3]
}
if (!($sitecode)){
    $SiteCode = "2CM" #ConfigMgr Site Code
}


Write-Host "CM Server: $ProviderMachineName" -ForegroundColor Green
Write-Host "SiteCode:  $SiteCode" -ForegroundColor Green

#$VirtualNameAdapterName = "192.168.1.X Lab Network" #The Actual Name of the Hyper-V Virtual Network you want to assign to the VM.
$RequiredDeploymentCollectionName = "OSD Required Deployment" #Whatever Collection you deployed the Task Sequence too
$AvailableDeploymentCollectionName = "OSD Available Deployment Client"

[int]$StartNumber = 1
[int]$EndNumber = 20
[int]$TimeBetweenKickoff = 300 #Time between each VM being turned on by Hyper-V, helps prevent host from being overwhelmed.



$CMConnected = $null

$Purpose = "AutoPilot", "ConfigMgr", "MikesLab", "Other" | Out-GridView -Title "Select the Build you want to update" -PassThru #Automated includes SMSTSPreferredAdvertID, and AllowUnattended

$HostName = $env:COMPUTERNAME
if ($HostName -match "HPED800G6-HOST"){
    $HostName = '800G6'
}
elseif ($HostName -eq "D-P-5810-VMHOST"){
    $HostName = 'P5180'
}
elseif ($HostName -eq "HP-Z2-SFF-G5"){
    $HostName = 'Z2G5'
}
elseif ($HostName -eq "UGREEN"){
    $HostName = 'UGNAS'
}
elseif ($HostName -eq "BEELINK-HOST"){
    $HostName = 'BLink'
}
elseif ($HostName -eq "MS01"){
    $HostName = 'MS01'
}
elseif ($HostName -eq "HPZbookSG10GARY"){
    $HostName = 'ZBG10'
}
elseif ($HostName -eq "HPZBStudiox360G"){
    $HostName = 'ZBSG5'
}
elseif ($HostName -match "AURA"){
    $HostName = 'AURA'
}
elseif ($HostName -match "R640"){
    $HostName = 'R640'
}
elseif ($HostName -match "HPZBSG10-GWB"){
    $HostName = 'ZBG10'
}
elseif ($HostName -eq "DELL-P7920"){
    $HostName = 'P7920'
}
else{
    $HostName = 'HVHst'
}

if ($Purpose -eq "AutoPilot"){
    $Tenant = "GARYTOWN", "2PintLab" | Out-GridView -Title "Select the Tenant you want to Join" -PassThru
    if ($Tenant -eq "GARYTOWN"){$VMNamePreFix = "VM-$HostName-GT-"; $ExtraNotes = "Environment = GTIntune"}
    elseif ($Tenant -eq "2PintLab"){$VMNamePreFix = "VM-$HostName-2P-"; $ExtraNotes = "Environment = 2PIntune"}
    }
if ($Purpose -eq "Other"){
    $VMNamePreFix = "VM-$HostName-"

    }
if (!(Test-Path -Path $VMPath))
    {
    Write-Host "HyperV Path not Set correctly!" -ForegroundColor Red
    Throw "Stopping"
    }
<#
elseif (!(Test-Path -Path $BootISO))
    {
    Write-Host "Boot ISO Path not Set correctly!"  -ForegroundColor Red
    Throw "Stopping"
    }
#>
elseif ((!(Test-Path -Path $CMModulePath)) -and $Purpose -eq "ConfigMgr")
    {
    if ($Purpose -eq "ConfigMgr"){
        Write-Host "CM Module Path not Set correctly!"  -ForegroundColor Red
        Throw "Stopping"}
    else
        {}
    }

else
    {
    Write-Host "All Pre-Req Paths are Set to something that appears ok"  -ForegroundColor Green
    if ($Purpose -eq "ConfigMgr"){
        $Files = Get-ChildItem -Path ($CMModulePath |Split-Path)  -Recurse
        foreach ($File in $Files){
            Unblock-File -Path $File.FullName
        }
        Import-Module $CMModulePath  #Where you have access to the CM Commandlets
    }
}

#SCRIPT FUNCTIONS BELOW
$Usable = $null
$NameTable = @()



if ($Purpose -eq "ConfigMgr"){


    $VMNamePreFix = "VM-$($SiteCode)-$($HostName)-"
    if (!(Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue)){New-PSDrive -PSProvider CMSite -Name $SiteCode -Root $ProviderMachineName -ErrorAction SilentlyContinue}
    if (!(Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue)){
        if (!($Creds)){$Creds = Get-Credential}
            New-PSDrive -PSProvider CMSite -Name $SiteCode -Root $ProviderMachineName -Credential $Creds
    }
    if (!(Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue)){$CMConnected = $false}

    Set-location $SiteCode":"
    if (!(Get-CMCollection -Name $RequiredDeploymentCollectionName))
        {
        Write-Host "No Collection Named $RequiredDeploymentCollectionName" -ForegroundColor Red
        $RequiredDeploymentCollection = Get-CMCollection -Name "OSD*" | Select-Object -Property Name, CollectionID| Out-GridView -PassThru -Title "Select the OSD Collection"
        $RequiredDeploymentCollectionName = $RequiredDeploymentCollection.name
    }
}
elseif ($Purpose -eq "AutoPilot"){

}
elseif ($Purpose -eq "MikesLab"){
    $VMNamePreFix = "VM-MT-$($HostName)-"
}
  
Set-location "c:"     

#Get Name of VMs Currently in HyperV
$CurrentVMS = (Get-VM | Where-Object {$_.Name -match $VMNamePreFix}) #Grab all VMs on host that match the PreFix
$VMSwitchs = Get-VMSwitch | Where-Object {$_.SwitchType -eq "External"}
if ($VMSwitchs.Count -gt 1)
    {
    Write-Host "More than 1 Virtual Switch matches External, Prompting for correct one"
    $VMSwitch = $VMSwitchs | Out-GridView -PassThru
    }
else
    {
    $VMSwitch = $VMSwitchs
    }

#$VMSwitch = (Get-VMSwitch | Where-Object {$_.Name -match $VirtualNameAdapterName}).Name  #Grab the VMSwitch that matches the name you specified above.

#Makes sure you have a Virtual Switch and CM Connection or exit out.
if (!($VMSwitch) -or ($CMConnected -eq $false))
    {
    if (!($VMSwitch)){Write-Host "No Virtual Network Found, Check Name or VM Networks" -ForegroundColor Red}
    if ($CMConnected -eq $false){Write-Host "No Connection to ConfigMgr" -ForegroundColor Red}
    }
else
    {
    #Run this loop until it finds enough names to use to create the dsired amount of VMs you want ... UNLESS... you run out of available values (end number)
    do
        {
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
        #If Machine not on HyperV Host, Check if in CM
        else
            {
            if ($Purpose -eq "ConfigMgr"){
                #Write-Host "No $($VMNamePreFix)$($StartNumberPad) VM"
                Set-location $SiteCode":"
                $TestCMDeviceName = $null
                $TestCMDeviceName = Get-CMDevice -Name "$($VMNamePreFix)$($StartNumberPad)"
                #IF machine name not in CM, add it to the list of machines to create
                if (!($TestCMDeviceName))
                    {
                    $Usable++
                    $NameTable += "$($VMNamePreFix)$($StartNumberPad)"
                    Write-Host "Adding $($VMNamePreFix)$($StartNumberPad) to Build List" -ForegroundColor Green
                    }
                #If machine was in CM, skip
                else
                    {
                    Write-Host "Name $($VMNamePreFix)$($StartNumberPad) Exist in CM" -ForegroundColor Yellow
                    }
                }
            else
                {
                $Usable++
                if ($Tenant -eq "Lightaria"){
                    $NameTable += "$($VMNamePreFix)$($StartNumberPad)A"
                    Write-Host "Adding $($VMNamePreFix)$($StartNumberPad)A to Build List" -ForegroundColor Green
                    }
                else {
                    $NameTable += "$($VMNamePreFix)$($StartNumberPad)"
                    Write-Host "Adding $($VMNamePreFix)$($StartNumberPad) to Build List" -ForegroundColor Green
                    }
                
                }
            }
    
        $StartNumber = $StartNumber + 1

        if ($Usable -eq $DesiredVMs){break}
        }
    while ($EndNumber -gt $StartNumber)


    # Create the VMs on this HYPER V Hosts
    Set-location c:
    foreach ($VMName in $NameTable)

        {

        Set-location c:
        #Create VM
        $VHDxFile = "$VMPath\$VMName\$VMName.vhdx"
        Write-Host "Creating VM $VMName" -ForegroundColor Cyan
        
        #If you want this to boot from ISO, change "NetworkAdapter to CD"
        #$NewVM = New-VM -Name $VMName -Path $VMPath -MemorystartupBytes 1024MB  -BootDevice NetworkAdapter  -SwitchName $VMSwitch.Name -Generation 2
        $NewVM = New-VM -Name $VMName -Path $VMPath -MemorystartupBytes $StartingMemory   -BootDevice CD -SwitchName $VMSwitch.Name -Generation 2
        Write-Host "  Setting Memory to Static 4GB" -ForegroundColor Green
        Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false -StartupBytes $StartingMemory
        Write-Host "  Setting VHDx to Dynamic, $DriveSize located here: $VHDxFile" -ForegroundColor Green
        $NewVHD = New-VHD -Path $VHDxFile  -SizeBytes $DriveSize -Dynamic
        Add-VMHardDiskDrive -VMName $VMName -Path $VHDxFile
        $vmSerial = (Get-CimInstance -Namespace root\virtualization\v2 -class Msvm_VirtualSystemSettingData | ? { ($_.VirtualSystemType -eq "Microsoft:Hyper-V:System:Realized") -and ($_.elementname -eq $VMName )}).BIOSSerialNumber
        Get-VM -Name $VMname | Set-VM -Notes "Serial# $vmSerial"

        #If Host is able, then set TPM on VM
        if ((Get-TPM).TpmPresent -eq $true -and (Get-TPM).TpmReady -eq $true){
            Write-Host "  Enabling TPM on VM" -ForegroundColor Green
            Set-VMSecurity -VMName $VMName -VirtualizationBasedSecurityOptOut:$false
            Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
            Enable-VMTPM -VMName $VMName
        }
        Write-Host "  Setting Processors to $ProcessorCount" -ForegroundColor Green
        Set-VMProcessor -VMName $VMName -Count $ProcessorCount        
        write-host "  Setting Video Resolution to 1600x900 (16:9)" -ForegroundColor Green
        Set-VMVideo -VMName $VMName -ComputerName $env:COMPUTERNAME -ResolutionType Single -HorizontalResolution 1600 -VerticalResolution 900

        if ($Purpose -eq "ConfigMgr"){
            Write-Host "  Setting Secure Boot to Off" -ForegroundColor Green
            Set-VMFirmware -EnableSecureBoot Off -VMName $VMName
            #Set-VMFirmware -VMName $VMName -FirstBootDevice $vmNetworkAdapter
            $vmNetworkAdapter = Get-VMNetworkAdapter -VMName $VMName
            Set-VMFirmware -FirstBootDevice  $vmNetworkAdapter -VMName $VMName
            $CurrentNotes = Get-VM -Name $VMname | Select-Object -ExpandProperty Notes
            $AddNotes = "Environment = CMLAB"
            $NewNotes = $CurrentNotes + "`n" + $AddNotes
            Get-VM -Name $VMname | Set-VM -Notes $NewNotes
        }
        elseif ($Purpose -eq "AutoPilot"){ 
            Write-Host "  Setting Secure Boot to Off, with Microsoft UEFI Certificate Authority" -ForegroundColor Green
            Set-VMFirmware -EnableSecureBoot Off -VMName $VMName
            Write-Host "  Setting Test Lab Specific Configurations" -ForegroundColor Green
            Write-Host " Setting First Boot Device to Network Adapter" -ForegroundColor Green
            $vmNetworkAdapter = Get-VMNetworkAdapter -VMName $VMName
            Set-VMFirmware -FirstBootDevice  $vmNetworkAdapter -VMName $VMName
            # Add any Test Lab specific configurations here
        }
        else{
            Write-Host "  Setting Boot ISO to $BootISO" -ForegroundColor Green
            Set-VMDvdDrive -VMName $VMName -Path $BootISO
            
            if ($ExtraNotes){
                $CurrentNotes = Get-VM -Name $VMname | Select-Object -ExpandProperty Notes
                $NewNotes = $CurrentNotes + "`n" + $ExtraNotes
                Get-VM -Name $VMname | Set-VM -Notes $NewNotes
            }


        }
        #THis line below is commented out because I'm skipping adding the ISO and just having it boot to Network Adapter
        
        Write-Host "  Setting CheckPoints to Standard" -ForegroundColor Green
        set-vm -Name $VMName -AutomaticCheckpointsEnabled $false
        set-vm -Name $VMName -CheckpointType Standard
        Write-Host "  Starting VM to Populate the Dynamic MAC Address" -ForegroundColor Yellow
        Write-Host "   Starting VM...." -ForegroundColor DarkGray
        #Start & Stop VM To build Dynamic MAC Address
        $Start = Start-VM -Name $VMName
        Start-Sleep -Seconds 10
        Write-Host "   Stoping VM...." -ForegroundColor DarkGray
        $Stop = Stop-VM -Name $VMName -TurnOff -Force
        $MAC = (Get-VMNetworkAdapter -VMName $VMName).MacAddress
        Write-Host "  MAC: $MAC" -ForegroundColor Green

        if ($Purpose -eq "ConfigMgr"){
            Set-location $SiteCode":"
            if ($CMDevice = Get-CMDevice -Name $VMName -Resource)
                {
                Write-Host "Device Already in CM, Deleting Object to Recreate with Correct Info"
                Remove-CMResource -ResourceId $CMDevice.ResourceId -Force
                }
            Else
                {
            
                $ImportDevice = Import-CMComputerInformation -ComputerName $VMName -CollectionName $AvailableDeploymentCollectionName -MacAddress $MAC
                $CMDevice = Get-CMDevice -Name $VMName -Resource

                if (($CMDevice.MACAddresses).replace(":","") -eq $MAC)
                    {
                    $NewVar = New-CMDeviceVariable -InputObject $CMDevice -VariableName "SMSTS_KnownComputer" -VariableValue "TRUE"
                    }
                Else
                    {
                    Write-Host "Failed to Set MAC Address"
                    }
                }
            Write-Host "Waiting 10 Seconds, then triggering Collection Eval" -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            Write-Host "Triggering Collection Eval on All Systems"
            $AllSystemCollection = Get-CMCollection -Name "All Systems"
            $AllSystemCollection.ExecuteMethod("RequestRefresh", $null)
            #$AllSystemCollection = Get-WmiObject -ComputerName $ProviderMachineName -ClassName SMS_Collection -Namespace root\SMS\site_PS2 | Where-Object {$_.Name -eq "All Systems"}
            #$AllSystemCollection.InvokeMethod("RequestRefresh",$null)
            Start-Sleep -Seconds 15
            #Write-Host "Triggering Collection Eval on $RequiredDeploymentCollectionName"
            #$OSDCollection = Get-CMCollection -Name "$RequiredDeploymentCollectionName"
            #$OSDCollection.ExecuteMethod("RequestRefresh", $null)
            Write-Host "Triggering Collection Eval on $AvailableDeploymentCollectionName"
            $OSDCollection = Get-CMCollection -Name "$AvailableDeploymentCollectionName"
            $OSDCollection.ExecuteMethod("RequestRefresh", $null)

            #$OSDCollection = Get-WmiObject -ComputerName $ProviderMachineName -ClassName SMS_Collection -Namespace root\SMS\site_PS2 | Where-Object {$_.Name -eq "OSD Required Deployment"}
            #$OSDCollection.InvokeMethod("RequestRefresh",$null)

            Write-Host "Waiting 90 Seconds, For Eval to Finish" -ForegroundColor Yellow
            Write-Host "Starting Each Machine Slowly to Start Automatic Imaging" -ForegroundColor Yellow
            Start-Sleep -Seconds 90
            start-vm -Name $VMName
            }
        else{
            start-vm -Name $VMName
            if ($WaitBetweenNext){
                Start-Sleep -Seconds ($WaitBetweenNext * 60)
            }
        }

        <#
        foreach ($VMName in $NameTable)
            {
            Write-Host "Starting VM $VMName" -ForegroundColor cyan
            start-vm -Name $VMName
            if ($DesiredVMs -gt 1){
                Write-Host " Waiting $TimeBetweenKickoff Minutes before starting the next one" -ForegroundColor Gray
                $Counting = 0
                do
                    {
                    $Counting += 30
                    Start-Sleep -Seconds 30
                    Write-Host "  You've waited $Counting Seconds" -ForegroundColor Gray
                    }
                while ($Counting -lt $TimeBetweenKickoff)
                }
            }
            #>
        }
    }




<# Add Record to CM Only

foreach ($VMName in $CurrentVMS)
    {
    $VMName = $VMName.Name
    Set-location c:
    #$VHDxFile = "$VMPath\$VMName\$VMName.vhdx"

    #New-VM -Name $VMName -Path $VMPath -MemorystartupBytes 2048MB  -BootDevice CD  -SwitchName $VMSwitch -Generation 2 
    #New-VHD -Path $VHDxFile  -SizeBytes 100GB -Dynamic
    #Add-VMHardDiskDrive -VMName $VMName -Path $VHDxFile
    #Set-VMSecurity -VMName $VMName -VirtualizationBasedSecurityOptOut:$false
    #Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
    #Enable-VMTPM -VMName $VMName
    #Set-VMProcessor -VMName $VMName -Count 2
    #Set-VMDvdDrive -VMName $VMName -Path $BootISO
    #set-vm -Name $VMName -AutomaticCheckpointsEnabled $false
    #set-vm -Name $VMName -CheckpointType Standard
    #Start & Stop VM To build Dynamic MAC Address
    #Start-VM -Name $VMName
    #Start-Sleep -Seconds 10
    #Stop-VM -Name $VMName -TurnOff -Force
    $MAC = (Get-VMNetworkAdapter -VMName $VMName).MacAddress

    Set-location $SiteCode":"
    Import-CMComputerInformation -ComputerName $VMName -CollectionName "OSD Required Deployment" -MacAddress $MAC
    $CMDevice = Get-CMDevice -Name $VMName -Resource

    if (($CMDevice.MACAddresses).replace(":","") -eq $MAC)
        {
        New-CMDeviceVariable -InputObject $CMDevice -VariableName "SMSTS_KnownComputer" -VariableValue "TRUE"
        }
    Else
        {
        Write-Host "Failed to Set MAC Address"
        }
    }

#>