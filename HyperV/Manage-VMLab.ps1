<#
In the notes of the VM, make sure you set the Environment to the following: GTIntune, 2PIntune, or CMLAB
This was to allow to run different labs on different days of the week, keeping clients active enough to be useful, creating data, and allowing for a host to host more than one lab.

Each lab gets to run 2 days a week, but the host gets Sunday off to rest, as any good Christian host should try. :-)
#>

#Monday = GARYTOWN Intue
#Tueday = CM LAB
#Wednesday = 2Pint Intune Lab

#Thursday = GARYTOWN Intue
#Friday = CM LAB
#Saturday = 2Pint Intune Lab

#Return day of the week
$DayofWeek = Get-Date -Format dddd


#Day of Week Mapping

$DayofWeekMapping = @(
    @{DayOfWeek = "Monday"; Lab2Run = "GTIntune"},
    @{DayOfWeek = "Tuesday"; Lab2Run = "CMLAB"},
    @{DayOfWeek = "Wednesday"; Lab2Run = "2PIntune"},
    @{DayOfWeek = "Thursday"; Lab2Run = "GTIntune"},
    @{DayOfWeek = "Friday"; Lab2Run = "CMLAB"},
    @{DayOfWeek = "Saturday"; Lab2Run = "2PIntune"}
)

$Lab2Run = ($DayofWeekMapping | Where-Object {$_.DayOfWeek -match $DayofWeek}).Lab2Run

$VMs = Get-VM

#Make sure all VMs are off before starting to turn things on.
Foreach ($VM in $VMs){
    $WorkingVM = Get-VM -Name $VM.Name
    Stop-VM -VM $WorkingVM -Force -ErrorAction SilentlyContinue
    
}

#Start the VMs based on the day of the week
Foreach ($VM in $VMs){
    $WorkingVM = Get-VM -Name $VM.Name
    $Notes = $WorkingVM.Notes -split "`n"
    #Write-Output $Notes
    $Environment = $Notes | Where-Object {$_ -match "Environment"}
    if ($Environment){
        $Environment = ($Environment -split "=")[1].trim()
        Write-Host "Environment: $Environment" -ForegroundColor Cyan
        
    }
    else{
        $Environment = "Unknown"
    }
    if ($Environment -eq $Lab2Run){
        Write-Host "Starting VM: $($WorkingVM.Name)" -ForegroundColor Green
        Start-VM -VM $WorkingVM
        Start-Sleep -Seconds 30
    }
    else{
        Write-Host "Shutting down VM: $($WorkingVM.Name)" -ForegroundColor Red
        Stop-VM -VM $WorkingVM -Force
    }
}

