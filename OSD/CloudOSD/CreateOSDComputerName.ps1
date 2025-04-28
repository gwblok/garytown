<# Gary Blok @gwblok
Generate Generic Computer Name based on Model Name... doesn't work well in Production as it names the machine after the model, so if you have more than one model.. it will get the same name.
This is used in my lab to name the PCs after the model, which makes life easier for me.

It creates randomly generated names for VMs following the the pattern "VM-CompanyName-Random 5 digit Number" - You would need to change how many digits this is if you have a longer company name.

NOTES.. Computer name can NOT be longer than 15 charaters.  There is no checking to ensure the name is under that limit.


#>

try {
    $tsenv = new-object -comobject Microsoft.SMS.TSEnvironment
}
catch{
    #Write-Output "Not in TS"
}

function Build-ComputerName {
    [CmdletBinding()]
    param(
        [switch]$Apply
    )

    $ComputerSystem = Get-Ciminstance -ClassName Win32_ComputerSystem
    $Manufacturer = $ComputerSystem.Manufacturer
    $Model = $ComputerSystem.Model
    $CompanyName = "GARYTOWN"
    $Serial = (Get-WmiObject -class:win32_bios).SerialNumber
    
    if ($Manufacturer -match "Lenovo"){
        $Model = ((Get-CimInstance -ClassName Win32_ComputerSystemProduct).Version).split(" ")[1]
        $ComputerName = "$($Manufacturer)-$($Model)"
    }
    elseif (($Manufacturer -match "HP") -or ($Manufacturer -match "Hew")){
        $Manufacturer = "HP"
        $Generation = $Model.split(" ") | Where-Object {$_ -match "G"}
        $Extra = $Model.split(" ") | Where-Object {$_ -like "(*)"}
        if ($Extra){$Model = $Model.replace("$Extra","")}
        if ($Model-match " DM"){$Model = $Model.replace(" DM","")}
        if ($Model-match " Desktop PC"){$Model = $Model.replace(" Desktop PC","")}
        if ($Model-match " Notebook PC"){$Model = $Model.replace(" Notebook PC","")}
        if ($Model-match " Desktop Mini PC"){$Model = $Model.replace(" Desktop Mini PC","")}
        if ($Model-match " Desktop Mini"){$Model = $Model.replace(" Desktop Mini","")}
        if ($Model-match "EliteDesk"){$Model = $Model.replace("EliteDesk","ED")}
        elseif($Model-match "EliteBook"){$Model = $Model.replace("EliteBook","EB")}
        elseif($Model-match "Elite Mini"){$Model = $Model.replace("Elite Mini","EM")}
        elseif($Model-match "Elite x360"){
            $Model = $Model.replace("Elite x360","EBX")
            $Size = $Model.Split(" ")[2]
            $Model = "$($Model.Substring(0,7))$($Size) $($Generation)"
        }
        elseif($Model-match "ProDesk"){$Model = $Model.replace("ProDesk","PD")}
        elseif($Model-match "ProBook"){$Model = $Model.replace("ProBook","PB")}
        elseif($Model-match "ZBook"){$Model = $Model.replace("ZBook","ZB")}
        if ($Model -match "inch"){
            $Split = ($Model.Split('inch')[0])
            $inch = $Split.TrimEnd().Split(" ") | Select-Object -Last 1
            $Model = $Model.replace("$inch inch","")
        }
        if($Model-match "Fury"){$Model = "$($Model.Substring(0,11))$Generation"}
        $Model = $model.replace(" ","")
        if ($Model.Length -gt 15){$ComputerName = $Model.Substring(0,15)}
        else {$ComputerName = $Model}
        if ($ComputerName.Length -lt 15){
            [int]$Extra = 15 - $ComputerName.Length -1
            $LastXofSerial = $Serial.Substring($Serial.Length - $Extra, $Extra)
            $ComputerName = "$($ComputerName)-$($LastXofSerial)"
        }
    }
    elseif($Manufacturer -match "Dell"){
        $Manufacturer = "Dell"
        $Model = (Get-WmiObject -Class:Win32_ComputerSystem).Model
        $ModelNumber = $Model -replace "[^0-9]" , ''
        if ($Model-match "Latitude"){$Model = "DL-$($ModelNumber)"}#{$Model = $Model.replace("Latitude","L")}
        elseif($Model-match "OptiPlex"){$Model = "DO-$($ModelNumber)"}#{$Model = $Model.replace("OptiPlex","O")}
        elseif($Model-match "Precision"){$Model = "DP-$($ModelNumber)"}#{$Model = $Model.replace("Precision","P")}
        $Model = $model.replace(" ","-")
        $ComputerName = "$($Model)-$($Serial)"
    }
    elseif ($Manufacturer -match "Microsoft"){
        if ($Model -match "Virtual"){
            $Random = Get-Random -Maximum 99999
            $ComputerName = "VM-$($CompanyName)-$($Random )"
            if ($ComputerName.Length -gt 15){
                $ComputerName = $ComputerName.Substring(0,15)
            }
        }
    }
    elseif ($Manufacturer -match "Intel"){
        $ComputerName = "$($Model)-$($Serial)"
        $ComputerName = $ComputerName.Substring(0,15)
    }
    else {
        if ($Serial.Length -ge 15){
            $ComputerName = $Serial.substring(0,15)
        }
        else{
            $ComputerName = $Serial 
        }
    }
    if ($ComputerName.Length -gt 15){
        Write-Output "-------------------------------------------------------------------------------------------------------------------------------"
        Write-Output "Computer Name is too long, can only be 15 characters."
        Write-Output "Current Computer name is set to: $ComputerName, trimming to....."
        $ComputerName = $ComputerName.Substring(0,15)
        Write-Output "New Name = $ComputerName"
        Write-Output "Your LOGIC Failed, you need to see why it was coming up longer than 15, so you can fix it, instead of having it use the bandaid"
        Write-Output "-------------------------------------------------------------------------------------------------------------------------------"
    }
    if ($Apply){
        rename-computer -NewName $ComputerName -Force -Verbose
    }
    return $ComputerName
}
if ($tsenv){
    $ComputerName = Build-ComputerName
    Write-Output "====================================================="
    Write-Output "Setting OSDComputerName to $ComputerName"
    $tsenv.value('OSDComputerName') = $ComputerName
    Write-Output "====================================================="
}