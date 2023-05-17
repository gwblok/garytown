$DesktopChassisTypes = @("3","4","5","6","7","13","15","16","35")
$LatopChassisTypes = @("8","9","10","11","12","14","18","21","30","31")

$chassi = gwmi -Class 'Win32_SystemEnclosure'
if ($chassi.ChassisTypes -in $LatopChassisTypes){
    $IsLaptop = $true
}
else {
    $IsLaptop = $false
}
if ($chassi.ChassisTypes -in $DesktopChassisTypes){
    $IsDesktop = $true
}
else {
    $IsDesktop = $false
}
