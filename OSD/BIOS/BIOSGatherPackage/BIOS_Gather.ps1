<#
    Name: BIOS_Gather.ps1
    Version: 21.01.26
    Date: 2020-01-26
    Author: Mike Terrill/@miketerrill
    
    Command: powershell.exe -executionpolicy bypass -file BIOS_Gather.ps1 [-debug]
    Usage: Run in CM Task Sequence to gather BIOS information during OSD, IPU or existing deployed systems
    Remark: Creates and sets number of BIOS Task Sequence variables, currently only covers Dell and HP
    Requirements: Include the Dell CCTK binaries in the same package
    
    2019-04-20 v. 1.0.0: Initial Release
    2019-06-24 v. 1.1.0: Replaced Dell WMI (OMCI) dependencies with CCTK for Full OS and WinPE support
    2020-06-20 v. 20.06.20: Changed from Invoke-Expression to Start-Process
    2020-06-27 v. 20.06.27: Added BIOS TARGETBIOSDATE/TARGETBIOSVERSION(Dell) check - sets TS var FLASHBIOS
    2020-07-01 v. 20.07.01: Added a check for the HP.Firmware PowerShell module - sets TS var HPCMSL
    2020-07-04 v. 20.07.04: Moved CCTK and CMSL downloads to individual packages
    2020-07-10 v. 20.07.10: Fixed a path issue with the CCTK variable
    2020-12-02 v. 20.12.02: Added support for older Dells with "A" BIOS Version Names (@gwblok)
    2021-01-26 v. 21.01.26: Added Gary's Get-BIOSVerion function for cleaner HP BIOS versions
    2021-06-11 v. 21.06.11: Added a Write-Output for CurrentBIOSDate
#>

param (
[switch]$Debug
)

# Grab Target BIOS Update Date from Task Sequence Var
$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
try {[datetime]$TARGETBIOSDATE = $tsenv.Value("TARGETBIOSDATE")}
catch {$TARGETBIOSDATE = $null}

# Grab Target BIOS Update Version from Task Sequence Var
try {
     if ($tsenv.Value("TARGETBIOSVERSION") -match "A") #Deal with Versions with A
        {
        [String]$TARGETBIOSVERSION = $tsenv.Value("TARGETBIOSVERSION")
        }
    else
        {
        [System.Version]$TARGETBIOSVERSION = $tsenv.Value("TARGETBIOSVERSION")
        }
    }
catch {$TARGETBIOSVERSION = $null}


try {$HPFirmwareModule = Get-Module -Name HP.Firmware}
Catch{}

$TSvars = @{}

#Grab Info about Current BIOS State
$BIOS = Get-WmiObject -Class 'Win32_Bios'

# Get the current BIOS release date and format it to datetime
$CurrentBIOSDate = [System.Management.ManagementDateTimeConverter]::ToDatetime($BIOS.ReleaseDate).ToUniversalTime()
Write-Output "Current BIOS Date: $CurrentBIOSDate"
$TSvars.Add("CURRENTBIOSDATE", "$CurrentBIOSDate")

# Get path to the Dell CCTK download
# Requies a separate package containing the CCTK to be downloaded prior using the Download Package Content step
$CCTK = $tsenv.Value("CCTK01")

# Get path to HP CMSL download
# Requies a separate package containing the CMSL to be downloaded prior using the Download Package Content step
$CMSL = $tsenv.Value("CMSL01")


function Get-Manufacturer {

    $cs = gwmi -Class 'Win32_ComputerSystem'

    If ($cs.Manufacturer -eq 'HP' -or $cs.Manufacturer -eq 'Hewlett-Packard') {
        $Manufacturer = 'HP'
    }
    elseif ($cs.Manufacturer -eq 'Dell Inc.') {
        $Manufacturer = 'Dell'
    }
    else {
        $Manufacturer = $cs.Manufacturer
    }
    return $Manufacturer
}

function Get-Product {

    $bb = gwmi -Class 'Win32_BaseBoard'
    $TSvars.Add("Product", $bb.Product)
}

function Get-HPBIOS {

    $HPBIOS = Get-CimInstance -Namespace root -Class __Namespace | where-object Name -eq HP
    if ($HPBIOS) {
        return $True
        }
    else {
        return $False
        }
}

function Get-HPBIOSPWSET {
    [cmdletbinding()]
    param (
        $CMSL
        )
    # Get the file path to HP.Firmware.psm1
    if ($HPFirmwareModule)
        {
        Write-Output "HPCMSL Already installed, Don't need to copy over module"
        }
    else
        {
        # If the HP.Firmware module PowerShell module is not found set HPCMSL to Unknown in order
        # to prevent attempting to flashing the BIOS since the module is required
        $File = Get-ChildItem $CMSL -Filter 'HP.Firmware.psd1' -Recurse
        if (!$File) {
            $TSvars.Add("HPCMSL", "Unknown")
            Write-Output "Unable to detect HP CMSL. Setting HPCMSL to Unknown"
            return
            }
        else {
            # Copy HP CMSL PowerShell module to PowerShell Module directory
            Write-Output "Copying $CMSL directory to $env:ProgramFiles\WindowsPowerShell"
            #Copy-Item -Path "$CMSL\*" -Destination $env:ProgramFiles\WindowsPowerShell\Modules -Recurse -Force
            #$PSPath = $env:PSModulePath.Split(";")
            #$PSPath = $PSPath | Where-Object {$_ -like "*:\Program Files\WindowsPowerShell*"}
            #$CopyDestination = $PSPath.Substring(0,$PSPath.Length-8)
            $CopyDestination = "$env:ProgramFiles\WindowsPowerShell"
            Copy-Item "$CMSL\HP.PowershellModules\Modules" -Destination $CopyDestination -Recurse -Force -Verbose
            Copy-Item "$CMSL\HP.PowershellModules\Scripts" -Destination $CopyDestination -Recurse -Force -Verbose
            }
        }
    
    $BIOSSetting = gwmi -class hp_biossetting -Namespace "root\hp\instrumentedbios"
    Write-Output "Using HP WMI to determine if a BIOS password is set."

    if (!$BIOSSetting) {
        $TSvars.Add("BIOSPWSET", "Unknown")
        Write-Output "Unable to detect HP WMI. Setting BIOSPWSET to Unknown"
        return
    }
    else {
        
        If (($BIOSSetting | ?{ $_.Name -eq 'Setup Password' }).IsSet -eq 0)
            {
                $TSvars.Add("BIOSPWSET", $False)
                Write-Output "BIOS password is not set. Setting BIOSPWSET to False"
                return
            }
        else
            {
                $TSvars.Add("BIOSPWSET", $True)
                Write-Output "BIOS password is set. Setting BIOSPWSET to True"
                return
            }
        }
}

function Get-DELLBIOSPWSET {
    [cmdletbinding()]
    param (
        $CCTK
        )
    # Get the file path to the cctk
    $File = Get-ChildItem $CCTK -Filter cctk.exe -Recurse
    Write-Output "Using the CCTK to determine if a BIOS password is set."

    # If the cctk is not found set BIOSPWSET to Unknown in order to prevent
    # flashing the BIOS if a PW is set
    if (!$File) {
        $TSvars.Add("BIOSPWSET", "Unknown")
        Write-Output "Unable to detect CCTK. Setting BIOSPWSET to Unknown"
        return
    }
    else {
        # Set location of CCTK path in a TSVar for later use in the TS
        $TSvars.Add("CCTK", "$($File.FullName)")

        # Test for BIOS PW
        $Result = (Start-Process -FilePath $File.FullName -ArgumentList "--SetupPwd=" -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue).ExitCode
        
        # BIOS PW is set
        # 41. The old password must be provided to set a new password using --ValSetupPwd.
        If ($Result -eq "41") {
            $TSvars.Add("BIOSPWSET", $True)
            Write-Output "BIOS password is set. Setting BIOSPWSET to True"
            return
        }
        # BIOS PW not set
        # 60. Password not changed, new password does not meet criteria. 
        If ($Result -eq "60") {
            $TSvars.Add("BIOSPWSET", $False)
            Write-Output "BIOS password is not set. Setting BIOSPWSET to False"
            return
        }
    }
}

function Compare-BIOS {
    [cmdletbinding()]
    param (
        $CurrentBIOSDate,
        $TARGETBIOSDATE,
        $CurrentBIOSVersion,
        $TARGETBIOSVERSION
        )

    # Compare the Current BIOS Release Date to the Target BIOS Date
    If (!($TARGETBIOSDATE -eq $null)) {
        Write-Output "Using Target BIOS Date for comparison"
        Write-Output "Current BIOS Date: $CurrentBIOSDate"
        Write-Output "Target BIOS Date: $TARGETBIOSDATE"
        If ($CurrentBIOSDate -lt $TARGETBIOSDATE) {
            $TSvars.Add("FLASHBIOS", "$True")
            Write-Output "BIOS level is not compliant. Setting FLASHBIOS to True"
            return
            }
        Elseif ($CurrentBIOSDate -ge $TARGETBIOSDATE) {
            $TSvars.Add("FLASHBIOS", "$False")
            Write-Output "BIOS level is compliant. Setting FLASHBIOS to False"
            return
            }
    }
    # On Dell machines-if the Target BIOS Date is empty try using the Targer BIOS Version instead
    Elseif ($TARGETBIOSDATE -eq $null -and $BIOS.Manufacturer -match "Dell" -and !($TARGETBIOSVERSION -eq $null)) {
        Write-Output "Using Target BIOS Version for comparison"
        Write-Output "Current BIOS Version:"
        Write-Output $CurrentBIOSVersion
        Write-Output "Target BIOS Version:"
        Write-Output $TARGETBIOSVERSION
        If (!($CurrentBIOSVersion -eq $null)) {
            If ($CurrentBIOSVersion -lt $TARGETBIOSVERSION) {
                $TSvars.Add("FLASHBIOS", "$True")
                Write-Output "BIOS level is not compliant. Setting FLASHBIOS to True"
                return
                }
            Elseif ($CurrentBIOSVersion -ge $TARGETBIOSVERSION) {
                $TSvars.Add("FLASHBIOS", "$False")
                Write-Output "BIOS level is compliant. Setting FLASHBIOS to False"
                return
                }
            }
    }
    Else {
        $TSvars.Add("FLASHBIOS", "Unknown")
        Write-Output "Unable to detect BIOS state"
        return "Unknown"
        }
}

function Get-BIOSVersion {
    [cmdletbinding()]
    param (
        $CMSL
        )
    $BIOS = Get-WmiObject -Class 'Win32_Bios'
    $Manufacturer = Get-Manufacturer
    if ($Manufacturer -eq "Dell")
        {
        # BIOS Versions with characters (like A23) will not format to a version so use out-null
        try {
            if ($BIOS.SMBIOSBIOSVersion -match "A") #Deal with Versions with A
                {
                [String]$CurrentBIOSVersion = $BIOS.SMBIOSBIOSVersion
                }
            else
                {
                [System.Version]$CurrentBIOSVersion = $BIOS.SMBIOSBIOSVersion
                }   
            }
        catch {$CurrentBIOSVersion = $null}
        return $CurrentBIOSVersion
        }

    if ($Manufacturer -eq "HP")
        {
        # Get the file path to HP.Firmware.psm1
        try {$HPBiosVersion = get-hpbiosversion}
        catch {$HPBiosVersion = $null}

        if ($HPBiosVersion)
            {
            return $HPBiosVersion
            }
        else
            {
            # If the HP.Firmware module PowerShell module is not found set HPCMSL to Unknown in order
            # to prevent attempting to flashing the BIOS since the module is required
            $File = Get-ChildItem $CMSL -Filter 'HP.Firmware.psd1' -Recurse
            if (!$File) {
                $TSvars.Add("HPCMSL", "Unknown")
                #Write-Output "Unable to detect HP CMSL. Setting HPCMSL to Unknown"
                #return
                }
            else {
                # Copy HP CMSL PowerShell module to PowerShell Module directory
                Write-Output "Copying $CMSL directory to $env:ProgramFiles\WindowsPowerShell"
                $CopyDestination = "$env:ProgramFiles\WindowsPowerShell"
                Copy-Item "$CMSL\HP.PowershellModules\Modules" -Destination $CopyDestination -Recurse -Force -Verbose
                Copy-Item "$CMSL\HP.PowershellModules\Scripts" -Destination $CopyDestination -Recurse -Force -Verbose
                }
            try {$HPBiosVersion = get-hpbiosversion}
            catch {$HPBiosVersion = $null}
            if ($HPBiosVersion)
                {
                return $HPBiosVersion
                }
            else
                {
                $BIOS = Get-WmiObject -Class 'Win32_Bios'
                $CurrentBIOSVersion = $BIOS.SMBIOSBIOSVersion
                return $CurrentBIOSVersion
                }
           }
        }
    }

If ((Get-Manufacturer -eq "HP") -and (Get-HPBIOS)) {
    Get-HPBIOSPWSET -CMSL $CMSL
    }

elseif (Get-Manufacturer -eq "Dell") {
    Get-DELLBIOSPWSET -CCTK $CCTK
    }

else {
    $TSvars.Add("BIOSPWSET", "Unknown")
    }

$CurrentBIOSVersion = Get-BIOSVersion
Compare-BIOS -CurrentBIOSDate $CurrentBIOSDate -TARGETBIOSDATE $TARGETBIOSDATE -CurrentBIOSVersion $CurrentBIOSVersion -TARGETBIOSVERSION $TARGETBIOSVERSION

$TSvars.Add("CURRENTBIOSVERSION", "$CurrentBIOSVersion")

if($Debug) {
    $TSvars.Keys | Sort-Object |% {
        Write-Output "$($_) = $($TSvars[$_])"
    }
}
else {
    $tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
    $temp = $tsenv.Value("OSDComputerName")
    
    if(!$temp) {
        $TSvars.Add("OSDComputerName", $tsenv.Value("_SMSTSMachineName"))
    }

    $TSvars.Keys |% {
        $tsenv.Value($_) = $TSvars[$_]
    }
}
