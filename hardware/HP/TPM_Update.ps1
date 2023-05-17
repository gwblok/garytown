<# GARY BLOK - GARYTOWN.COM
Script to Update HP TPM Chips
Process currently does NOT support BIOS with a Password Set

This is a MVP of a script that I threw together after supper, during putting kids to bed, and listening to whatever shows my wife has on in the background, all together about 3 hours"


Requires HPCMSL Module installed on Machine

Checks TPM Status, then looks for the available update from HP (if available).  
Sets BIOS settings to support flashing TPM.. you'll want to continue to run until it no longer finds a TPM Update and sets the BIOS settings back.

VERY LITTLE TESTING DONE.. like 2 computers, since that's all I have at home.

Version: 22.05.16.1


#>


#This does NOT support BIOS Password.

if ($env:SystemDrive -eq 'X:') {$WindowsPhase = 'WinPE'}
else {
    $ImageState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Ignore).ImageState
    if ($env:UserName -eq 'defaultuser0') {$WindowsPhase = 'OOBE'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE') {$WindowsPhase = 'Specialize'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT') {$WindowsPhase = 'AuditMode'}
    else {$WindowsPhase = 'Windows'}
}

$PowerShellModuleName = "HPCMSL"
$Import = Import-Module -Name $PowerShellModuleName -PassThru
if ($Import.Name -eq "HPCMSL")
    {
    Write-Host "Successfully Import $PowerShellModuleName PowerShell Version $($Import.Version)"
    }
else {
    Write-Host "Failed to Import Required Module $PowerShellModuleName"
    break
    }

$BIOSSettingTable= @(
@{ Stage = 'Static'; Name = 'TPM Device'; Value = "Available"}
@{ Stage = 'Static'; Name = 'TPM State'; Value = "Enable"}
@{ Stage = 'Static'; Name = 'TPM Activation Policy'; Value = "No Prompts"}
@{ Stage = 'PreUpdate'; Name = 'Virtualization Technology (VTx)'; Value = "Disable"}
@{ Stage = 'PreUpdate'; Name = 'Virtualization Technology (AMD-V)' ; Value = "Disable"}
@{ Stage = 'PreUpdate'; Name = 'Trusted Execution Technology (TXT)'; Value = "Disable"}
@{ Stage = 'PreUpdate'; Name = 'SVM CPU Virtualization' ; Value = "Disable"}
#@{ Stage = 'PreUpdate'; Name = 'Intel Software Guard Extensions (SGX)'; Value = "Disable"} #Initial tests show I don't need to disable this
@{ Stage = 'PostUpdate'; Name = 'Virtualization Technology (VTx)'; Value = "Enable"}
@{ Stage = 'PostUpdate'; Name = 'Virtualization Technology (AMD-V)' ; Value = "Enable"}
@{ Stage = 'PostUpdate'; Name = 'Trusted Execution Technology (TXT)'; Value = "Enable"}
@{ Stage = 'PostUpdate'; Name = 'SVM CPU Virtualization' ; Value = "Enable"}
@{ Stage = 'PostUpdate'; Name = 'Intel Software Guard Extensions (SGX)'; Value = "Software control"}
)


#Detect BIOS Password

Write-Output "Using HP CMSL to determine if a BIOS password is set."

$BIOSPWSet = Get-HPBIOSSetupPasswordIsSet
Write-Output "BIOS Password Set: $($BIOSPWSet)"

if ($BIOSPWSet -eq $True){
    Write-Host "Currently NO Support for BIOS Passwords, remove Password and Try again" -ForegroundColor Red
    break
    }
elseif ($BIOSPWSet -eq $False) {
    }

#Test TPM Device in BIOS.. needs to be set to Available for rest of script to work.
if ((Get-HPBIOSSettingValue -Name 'TPM Device') -eq "Available"){

    $SP87753 = Get-CimInstance  -Namespace "root\cimv2\security\MicrosoftTPM" -query "select * from win32_tpm where IsEnabled_InitialValue = 'True' and ((ManufacturerVersion like '7.%' and ManufacturerVersion < '7.63.3353') or (ManufacturerVersion like '5.1%') or (ManufacturerVersion like '5.60%') or (ManufacturerVersion like '5.61%') or (ManufacturerVersion like '4.4%') or (ManufacturerVersion like '6.40%') or (ManufacturerVersion like '6.41%') or (ManufacturerVersion like '6.43.243.0') or (ManufacturerVersion like '6.43.244.0'))"
    $SP94937 = Get-CimInstance  -Namespace "root\cimv2\security\MicrosoftTPM" -query "select * from win32_tpm where IsEnabled_InitialValue = 'True' and ((ManufacturerVersion like '7.62%') or (ManufacturerVersion like '7.63%') or (ManufacturerVersion like '7.83%') or (ManufacturerVersion like '6.43%') )"
    }
else
    {
    Set-HPBIOSSettingValue  -Name 'TPM Device' -eq "Available"
    Write-Host "TPM Device was Hidden, Enabling now and Restarting Machine.  TPM needs to be available to check for updates.  Once Rebooted, start Process again"
    write-host "Reboot in 120 Seconds...." -ForegroundColor Green
    Start-Sleep -Seconds 30
    write-host "Reboot in 90 Seconds...." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    write-host "Reboot in 60 Seconds...." -ForegroundColor Magenta
    Start-Sleep -Seconds 30
    write-host "Reboot in 30 Seconds...." -ForegroundColor Red
    Start-Sleep -Seconds 30
    if ($WindowsPhase -eq "WinPE"){
        Wpeutil Reboot
        }
    else
        {
        Restart-Computer -Force
        }
    }


if ($SP87753){
    Write-Host "TPM Update SP87753 is available, Will continue with settings BIOS settings to allow TPM Update"
    }

elseif ($SP94937){
    Write-Host "TPM Update SP94937 is available, Will continue with settings BIOS settings to allow TPM Update"
    }
else
    {
    Write-Host "NO TPM Updates Available, will confirm BIOS settings are optimized for normal operations"
    foreach ($BIOSSetting in $BIOSSettingTable){
    if (($BIOSSetting.Stage -eq "Static") -or ($BIOSSetting.Stage -eq "PostUpdate")){
        Write-Output "Starting Setting $($BIOSSetting.name)"
        $null = $CurrentValue
        $CurrentValue = Get-HPBIOSSettingValue -Name $BIOSSetting.Name -ErrorAction SilentlyContinue
        if ($CurrentValue){
            if ($CurrentValue -eq $BIOSSetting.Value){
             Write-Host "Current Value: $CurrentValue, Already Configured" -ForegroundColor Green}
             else {
                Write-Host "Current Value: $CurrentValue, Updating for Post TPM Updates" -ForegroundColor Yellow
                if ($BIOSPWSet){ Set-HPBIOSSettingValue -Name $BIOSSetting.Name -Value $BIOSSetting.Value -Password $BIOSPassword}
                else{Set-HPBIOSSettingValue -Name $BIOSSetting.Name -Value $BIOSSetting.Value}
                }
            }
            else {Write-Host "Setting not available" -ForegroundColor Yellow}
            } 
        }
        Write-Host "TPM Process Complete" -ForegroundColor Green
        break
    }

$cs = Get-WmiObject Win32_ComputerSystem
$WorkingFolder = "$env:TEMP\HP\TPM"
New-Item -Path $WorkingFolder -ItemType Directory -Force | Out-Null




FUNCTION Start-HPTPMUpdate {
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$true)]
	$path,
	[Parameter(Mandatory=$false)]
	$filename,
	[Parameter(Mandatory=$false)]
	$spec,
	[Parameter(Mandatory=$false)]
	$logsuffix
	)

try{$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment}
catch{Write-Verbose "Not running in a task sequence."}

$Process = "$path\TPMConfig64.exe"
#Create Argument List
if ($filename -and $spec){$TPMArg = "-s -f$filename -a$spec -l$($env:temp)\TPMConfig_$($logsuffix).log"}
elseif ($filename -and !($spec)) { $TPMArg = "-s -f$filename -l$($env:temp)\TPMConfig_$($logsuffix).log"}
elseif (!($filename) -and $spec) { $TPMArg = "-s -a$spec -l$($env:temp)\TPMConfig_$($logsuffix).log"}
elseif (!($filename) -and !($spec)) { $TPMArg = "-s -l$($env:temp)\TPMConfig_$($logsuffix).log"}

Write-Output "Running Command: Start-Process -FilePath $Process -ArgumentList $TPMArg -PassThru -Wait"

$TPMUpdate = Start-Process -FilePath $Process -ArgumentList $TPMArg -PassThru -Wait
write-output "TPMUpdate Exit Code: $($TPMUpdate.exitcode)"
}

if ((Get-BitLockerVolume).ProtectionStatus -eq "On"){$Suspend = Suspend-BitLocker -MountPoint $env:SystemDrive -RebootCount 5}

foreach ($BIOSSetting in $BIOSSettingTable){
    if (($BIOSSetting.Stage -eq "Static") -or ($BIOSSetting.Stage -eq "PreUpdate")){
        Write-Output "Starting Setting $($BIOSSetting.name)"
        $null = $CurrentValue
        $CurrentValue = Get-HPBIOSSettingValue -Name $BIOSSetting.Name -ErrorAction SilentlyContinue
        if ($CurrentValue){
            if ($CurrentValue -eq $BIOSSetting.Value){
             Write-Host "Current Value: $CurrentValue, Already Configured" -ForegroundColor Green}
             else {
                Write-Host "Current Value: $CurrentValue, Need to Configure for TPM Update" -ForegroundColor Yellow
                if ($BIOSPWSet){ Set-HPBIOSSettingValue -Name $BIOSSetting.Name -Value $BIOSSetting.Value -Password $BIOSPassword}
                else{Set-HPBIOSSettingValue -Name $BIOSSetting.Name -Value $BIOSSetting.Value}
                }
            }
        else {Write-Host "Setting not available" -ForegroundColor Yellow}
        } 

    }

if ($SP87753){
    $UpdatePath = "$WorkingFolder\SP87753.exe"
    $extractPath = "$WorkingFolder\SP87753"
    Write-Host "Starting downlaod & Install of TPM Update SP87753"
    Get-Softpaq -Number "SP87753" -SaveAs $UpdatePath -Overwrite yes
    $logsuffix = "SP87753"
    }

if ($SP94937){
    $UpdatePath = "$WorkingFolder\SP94937.exe"
    $extractPath = "$WorkingFolder\SP94937"
    Write-Host "Starting downlaod & Install of TPM Update SP94937"
    Get-Softpaq -Number "SP94937" -SaveAs $UpdatePath -Overwrite yes
    $logsuffix = "SP94937"

    }

if ($UpdatePath){
    if (Test-Path -Path $UpdatePath){
        Start-Process -FilePath $UpdatePath -ArgumentList "/s /e /f $extractPath" -Wait
        Start-Sleep -Seconds 1
        Start-HPTPMUpdate -path $extractPath -logsuffix $logsuffix
        }
    }
