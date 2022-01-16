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

$StartingMemory = "2048MB"
$DynamicMemoryLow = "1024MB"
$DynamicMemoryHigh = "2048MB"
$DriveSize = "100GB"

$VMPath = "E:\HyperVLab-Clients" #The location on the Host you want the VMs to be created and stored
$VMNamePreFix = "RECAST-"  #The VM will start with this name
$BootISO = "D:\HyperVLab\x64.iso"  #If you're booting to an ISO, put the location here.
#$VirtualNameAdapterName = "192.168.1.X Lab Network" #The Actual Name of the Hyper-V Virtual Network you want to assign to the VM.
$RequiredDeploymentCollectionName = "OSD Required Deployment" #Whatever Collection you deployed the Task Sequence too
[int]$StartNumber = 10
[int]$EndNumber = 20
[int]$TimeBetweenKickoff = 300 #Time between each VM being turned on by Hyper-V, helps prevent host from being overwhelmed.
$SiteCode = "MEM" #ConfigMgr Site Code
$ProviderMachineName = "memcm.dev.recastsoftware.dev" #ConfigMgr Provider Machine
$CMModulePath = "D:\HyperVLab\CMConsolePosh\ConfigurationManager.psd1"
$CMConnected = $null

if (!(Test-Path -Path $VMPath))
    {
    Write-Host "HyperV Path not Set correctly!" -ForegroundColor Red
    }

elseif (!(Test-Path -Path $BootISO))
    {
    Write-Host "Boot ISO Path not Set correctly!"  -ForegroundColor Red
    }

elseif (!(Test-Path -Path $CMModulePath))
    {
    Write-Host "CM Module Path not Set correctly!"  -ForegroundColor Red
    }

else
    {
    Write-Host "All Pre-Req Paths are Set to something that appears ok"  -ForegroundColor Green
    Import-Module $CMModulePath  #Where you have access to the CM Commandlets

    }

#SCRIPT FUNCTIONS BELOW
$Usable = $null
$NameTable = @()
if (!(Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue)){New-PSDrive -PSProvider CMSite -Name $SiteCode -Root $ProviderMachineName -ErrorAction SilentlyContinue}
if (!(Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue))
    {
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
        if ("$($VMNamePreFix)$($StartNumberPad)" -in ($CurrentVMS.name))
            {
            Write-Host "Name $($VMNamePreFix)$($StartNumberPad) Exist on HyperV Host" -ForegroundColor Yellow
            }
        #If Machine not on HyperV Host, Check if in CM
        else
            {
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
        $NewVM = New-VM -Name $VMName -Path $VMPath -MemorystartupBytes $StartingMemory  -BootDevice CD -SwitchName $VMSwitch.Name -Generation 2
        Write-Host "  Setting Memory to Dynamic, $DynamicMemoryLow - $DynamicMemoryHigh" -ForegroundColor Green
        set-vm -Name $VMName -DynamicMemory -MemoryMinimumBytes $DynamicMemoryLow -MemoryMaximumBytes $DynamicMemoryHigh
        Write-Host "  Setting VHDx to Dynamic, $DriveSize located here: $VHDxFile" -ForegroundColor Green
        $NewVHD = New-VHD -Path $VHDxFile  -SizeBytes $DriveSize -Dynamic
        Add-VMHardDiskDrive -VMName $VMName -Path $VHDxFile

        #If Host is able, then set TPM on VM
        if ((Get-TPM).TpmPresent -eq $true -and (Get-TPM).TpmReady -eq $true){
        Write-Host "  Enabling TPM on VM" -ForegroundColor Green
        Set-VMSecurity -VMName $VMName -VirtualizationBasedSecurityOptOut:$false
        Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
        Enable-VMTPM -VMName $VMName}
        Write-Host "  Setting Processors to Two" -ForegroundColor Green
        Set-VMProcessor -VMName $VMName -Count 2        
        Write-Host "  Setting Boot ISO to $BootISO" -ForegroundColor Green
        Set-VMVideo -VMName $VMName -ComputerName $env:COMPUTERNAME -ResolutionType Single -HorizontalResolution 1280 -VerticalResolution 800


        #THis line below is commented out because I'm skipping adding the ISO and just having it boot to Network Adapter
        Set-VMDvdDrive -VMName $VMName -Path $BootISO
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

        Set-location $SiteCode":"
        if ($CMDevice = Get-CMDevice -Name $VMName -Resource)
            {
            Write-Host "Device Already in CM, Deleting Object to Recreate with Correct Info"
            Remove-CMResource -ResourceId $CMDevice.ResourceId -Force
            }
        Else
            {
            
            $ImportDevice = Import-CMComputerInformation -ComputerName $VMName -CollectionName $RequiredDeploymentCollectionName -MacAddress $MAC
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

        }

    Write-Host "Waiting 10 Seconds, then triggering Collection Eval" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Write-Host "Triggering Collection Eval on All Systems"
    $AllSystemCollection = Get-CMCollection -Name "All Systems"
    $AllSystemCollection.ExecuteMethod("RequestRefresh", $null)
    #$AllSystemCollection = Get-WmiObject -ComputerName $ProviderMachineName -ClassName SMS_Collection -Namespace root\SMS\site_PS2 | Where-Object {$_.Name -eq "All Systems"}
    #$AllSystemCollection.InvokeMethod("RequestRefresh",$null)
    Start-Sleep -Seconds 15
    Write-Host "Triggering Collection Eval on $RequiredDeploymentCollectionName"
    $OSDCollection = Get-CMCollection -Name "$RequiredDeploymentCollectionName"
    $OSDCollection.ExecuteMethod("RequestRefresh", $null)
    #$OSDCollection = Get-WmiObject -ComputerName $ProviderMachineName -ClassName SMS_Collection -Namespace root\SMS\site_PS2 | Where-Object {$_.Name -eq "OSD Required Deployment"}
    #$OSDCollection.InvokeMethod("RequestRefresh",$null)

    Write-Host "Waiting 90 Seconds, For Eval to Finish" -ForegroundColor Yellow
    Write-Host "Starting Each Machine Slowly to Start Automatic Imaging" -ForegroundColor Yellow
    Start-Sleep -Seconds 90
    foreach ($VMName in $NameTable)
        {
        Write-Host "Starting VM $VMName" -ForegroundColor cyan
        start-vm -Name $VMName
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
