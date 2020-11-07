[int]$DesiredVMs = 10
$VMPath = "d:"
$VMNamePreFix = "RECAST-DEMO-"
$BootISO = "D:\BootMedia_DEMO.iso"
$PreFix = "PC"
$NameTable = @()
$CurrentVMS = (Get-VM | Where-Object {$_.Name -match $VMNamePreFix})
$VMSwitch = (Get-VMSwitch | Where-Object {$_.Name -match "Internal 192.168.1.X"}).Name
$RequiredDeploymentCollectionName = "OSD Required Deployment"
[int]$StartNumber = 60
[int]$EndNumber = 90
[int]$TimeBetweenKickoff = 300


$SiteCode = "RCT"
$ProviderMachineName = "DEMO-MEMCM.demo.recastsoftware.com"
Import-Module "d:\CMConsoleBin\bin\ConfigurationManager.psd1"
#Get SiteCode

$Usable = $null


if (!(Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue)){$NewDrive = New-PSDrive -PSProvider CMSite -Name $SiteCode -Root $ProviderMachineName -ErrorAction SilentlyContinue}
if (!(Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue))
    {
    if (!($Creds)){$Creds = Get-Credential}
    New-PSDrive -PSProvider CMSite -Name $SiteCode -Root $ProviderMachineName -Credential $Creds
    }
Set-location $SiteCode":"
Set-location c:

do
    {
    $StartNumberPad = "{0:00}" -f $StartNumber
    if ("$($VMNamePreFix)$($StartNumberPad)" -in ($CurrentVMS.name))
        {
        Write-Host "Name $($VMNamePreFix)$($StartNumberPad) Exist"
        }
    else
        {
        Write-Host "No $($VMNamePreFix)$($StartNumberPad) VM"
        $Usable++
        $NameTable += "$($VMNamePreFix)$($StartNumberPad)"
        }
    
    $StartNumber = $StartNumber + 1

    if ($Usable -eq $DesiredVMs){break}
    }
while ($EndNumber -gt $StartNumber)


#$VMName = "Recast-08"

foreach ($VMName in $NameTable)

    {

    Set-location c:
    #Create VM
    $VHDxFile = "$VMPath\$VMName\$VMName.vhdx"
    Write-Host "Creating VM $VMName" -ForegroundColor Cyan
    $NewVM = New-VM -Name $VMName -Path $VMPath -MemorystartupBytes 1024MB  -BootDevice NetworkAdapter  -SwitchName $VMSwitch -Generation 2
    Write-Host "  Setting Memory to Dynamic, 512MB - 2048MB" -ForegroundColor Green
    set-vm -Name $VMName -DynamicMemory -MemoryMinimumBytes 512MB -MemoryMaximumBytes 2048MB
    Write-Host "  Setting VHDx to Dynamic, 100GB located here: $VHDxFile" -ForegroundColor Green
    $NewVHD = New-VHD -Path $VHDxFile  -SizeBytes 100GB -Dynamic
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
    #Set-VMDvdDrive -VMName $VMName -Path $BootISO
    Write-Host "  Setting CheckPoints to Standard" -ForegroundColor Green
    set-vm -Name $VMName -AutomaticCheckpointsEnabled $false
    set-vm -Name $VMName -CheckpointType Standard
    Write-Host "  Starting VM to Populate the Dynamic MAC Address" -ForegroundColor Yellow
    Write-Host "   Starting VM...." -ForegroundColor DarkGray
    #Start & Stop VM To build Dynamic MAC Address
    $Start = Start-VM -Name $VMName
    Start-Sleep -Seconds 10
    Write-Host "   Stopping VM...." -ForegroundColor DarkGray
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

Write-Host "Waiting 60 Seconds, For Eval to Finish" -ForegroundColor Yellow
Write-Host "Starting Each Machine Slowly to Start Automatic Imaging" -ForegroundColor Yellow
Start-Sleep -Seconds 60
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
