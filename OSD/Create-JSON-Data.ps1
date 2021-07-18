[cmdletbinding()]
param(

    [string] $TargetRoot = '\\src.corp.viamonstra.com\Logs$',
    [string] $LogID = "Regression\$env:ComputerName"
)

Write-Output "==================================================="
Write-Output "Capturing JSON Data"
#Setup TS Environment
try{$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment}
catch{Write-Verbose "Not running in a task sequence."}

 Function Get-BIOSStatus {
    try {
        $SecureBootStatus = Confirm-SecureBootUEFI
        if ($SecureBootStatus -eq $true){Write-output "SecureBoot Enabled"}
        if ($SecureBootStatus -eq $false){Write-Output "SecureBoot Disabled"}
        }
    Catch
        {
        Write-Output "LEGACY Mode"
        }
    } 


$tsBuild = $tsenv.Value("SMSTS_Build") #Get Build Number from TS Variable.
$registryPath = "HKLM:\$($tsenv.Value("RegistryPath"))\$($tsenv.Value("SMSTS_Build"))" #Sets Registry Location

$ComputerName = $env:COMPUTERNAME
$BIOSInfo = Get-WmiObject -Class 'Win32_Bios'
$BIOSVersion = $BIOSInfo.SMBIOSBIOSVersion
$BIOSStatus = Get-BIOSStatus
$Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
if ($Manufacturer -like "H*"){$ID = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product}
else{$ID = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber}
$Model = (Get-WmiObject -Class:Win32_ComputerSystem).Model

$TSStart = $TSEnv.Value('SMSTS_StartTSTime')
$WaaSKeyCurrent = get-item $registryPath
if ($WaaSKeyCurrent.GetValue('WaaS_Stage') -ne $null){$WaaS_Stage = Get-ItemPropertyValue "$registryPath" 'WaaS_Stage' -ErrorAction SilentlyContinue}
if ($WaaSKeyCurrent.GetValue('IPUBuild') -ne $null){$IPUBuild = Get-ItemPropertyValue "$registryPath" 'IPUBuild' -ErrorAction SilentlyContinue}
if ($WaaSKeyCurrent.GetValue('IPUUserAccount') -ne $null){$IPUUserAccount = Get-ItemPropertyValue "$registryPath" 'IPUUserAccount' -ErrorAction SilentlyContinue}
if ($WaaSKeyCurrent.GetValue('IPUDriverLocation') -ne $null){$IPUDriverLocation = Get-ItemPropertyValue "$registryPath" 'IPUDriverLocation' -ErrorAction SilentlyContinue}

#Get Driver Pack Version
$DriverPackPath = $IPUDriverLocation
if (Test-Path $DriverPackPath){
    $Name = (Get-ChildItem -Path $DriverPackPath | Where-Object {$_.Name -match "txt"}).Name
    if (!($Name)){
        $ChildItem = Get-ChildItem -Path $DriverPackPath
        Write-Output "No txt file found"
        Write-Output $ChildItem
        $DriverPackVersion = "No Version File"
        }
    else {
        if ($Name.count -gt 1){$Name = $Name | Select-Object -Last 1}
        $DriverPackVersion = $Name.replace("`.txt","")
        }
    }
else{$DriverPackVersion = "No Driver Pack Downloaded"}

#Get Encryption Info
$Encryption = "NA"
#Check for Bitlocker
$BitlockerStatus = Get-BitLockerVolume
if ($BitlockerStatus.ProtectionStatus -eq "on"){$Encryption = "BitLocker"}


$JsonVariable = @"
{
    "Name":"$ComputerName",
    "LoggedON":"$IPUUserAccount",
    "Tested":"$TimeStamp",
    "ID":"$ID",
    "BIOS Version":"$BIOSVersion",
    "BIOS Mode":"$BIOSStatus",
    "DriverPack":"$DriverPackVersion",
    "TS Start":"$TSStart",
    "Manufacturer":"$Manufacturer",
    "Model":"$Model",
    "Encryption":"$Encryption",
    "WaaS_Stage":"$WaaS_Stage",
    "IPUBuild":"$IPUBuild"
}
"@


$JsonVariable = $JsonVariable | ConvertFrom-JSON
Write-Output $JsonVariable
new-item -itemtype Directory -Path $TargetRoot\$LogID -force -erroraction SilentlyContinue | out-null 
$TagFile = "$TargetRoot\$LogID\$($LogID.Replace('\','_'))"
$NetworkFileSharePath = "$TargetRoot\$LogID"
$LogNamePreFix = "$($LogID.Replace('\','_'))-$([datetime]::now.Tostring('s').Replace(':','-'))"
Write-Output "Creating File $($LogNamePreFix.Json) here $NetworkFileSharePath"
$JsonVariable | ConvertTo-Json | Out-File "$($NetworkFileSharePath)\$($LogNamePreFix).Json"
Write-Output "==================================================="
