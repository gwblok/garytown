Write-Output "---------------------------------------"
write-OutPut "Staring Script in TS Step: Setting Path to FlashBIN"
$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
$UEFI = $tsenv.Value("_SMSTSBootUEFI")
$path = $tsenv.Value("BIOS01")

if ($UEFI -eq "TRUE"){
    Write-Output "Detected running in UEFI"
    }
else{
    Write-Output "Detected running in LEGACY BIOS MODE"
    }


$cs = gwmi -Class 'Win32_ComputerSystem'
If ($cs.Manufacturer -eq 'HP' -or $cs.Manufacturer -eq 'Hewlett-Packard') {
    Write-Output "Detected Manufacturer is HP"
    $biosfile = Get-Item -Path "$path\*.bin"
    $tsenv.Value('FLASHLOG') = "$($biosfile.name).log"
    }
elseif ($cs.Manufacturer -eq 'Dell Inc.') {
    Write-Output "Detected Manufacturer is DELL"
    $biosfile = Get-Item -Path "$path\*.exe" | Where-Object {$_.Name -ne 'Flash64W.exe'}
    $tsenv.Value('FLASHLOG') = "$($biosfile.name).log"
    }
$tsenv.Value("FLASHBIN") = $biosfile.fullname
Write-Output "Set FLASHBIN to $($biosfile.fullname)"
Write-Output "---------------------------------------"
