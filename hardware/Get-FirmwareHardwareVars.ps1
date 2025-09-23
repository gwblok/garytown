Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class FirmwareUtils
{
    public const uint FW_FLAGS_DEFAULT = 0x00000000;
    
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetFirmwareEnvironmentVariableExW(
        [MarshalAs(UnmanagedType.LPWStr)] string lpName, 
        [MarshalAs(UnmanagedType.LPWStr)] string lpGuid, 
        [MarshalAs(UnmanagedType.LPWStr)] StringBuilder lpBuffer, 
        [In, Out] ref uint nSize, 
        uint dwFlags);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint GetLastError();
    
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetFirmwareEnvironmentVariableExW(
        [MarshalAs(UnmanagedType.LPWStr)] string lpName, 
        [MarshalAs(UnmanagedType.LPWStr)] string lpGuid, 
        [MarshalAs(UnmanagedType.LPWStr)] string lpValue, 
        uint nSize, 
        uint dwFlags);
}
"@

class FirmwareVariable {
    [string]$Name
    [string]$Guid
    [string]$Value
    [uint]$Size
    [bool]$Success
    [uint]$ErrorCode
    [string]$ErrorMessage
    
    FirmwareVariable([string]$name, [string]$guid, [string]$value, [uint]$size, [bool]$success, [uint]$errorCode, [string]$errorMsg) {
        $this.Name = $name
        $this.Guid = $guid
        $this.Value = $value
        $this.Size = $size
        $this.Success = $success
        $this.ErrorCode = $errorCode
        $this.ErrorMessage = $errorMsg
    }
}

function Get-FirmwareEnvironmentVariableRaw {
    param(
        [string]$VariableName,
        [string]$Guid,
        [int]$MaxBufferSize = 4096
    )
    
    # Step 1: Determine required buffer size
    $requiredSize = [uint]0
    $tempBuffer = New-Object System.Text.StringBuilder(1)
    
    # Clear any previous error
    [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    
    $sizeCheck = [FirmwareUtils]::GetFirmwareEnvironmentVariableExW(
        $VariableName,
        $Guid,
        $tempBuffer,
        [ref]$requiredSize,
        [FirmwareUtils]::FW_FLAGS_DEFAULT
    )
    
    $sizeErrorCode = [FirmwareUtils]::GetLastError()
    
    Write-Verbose "Size check - Name: '$VariableName', Guid: '$Guid', RequiredSize: $requiredSize, Error: $sizeErrorCode"
    
    # If size is 0 and no error, variable doesn't exist
    if ($requiredSize -eq 0 -and $sizeErrorCode -eq 0) {
        return [FirmwareVariable]::new($VariableName, $Guid, $null, 0, $false, 0, "Variable does not exist")
    }
    
    # If we got an actual error, return it
    if ($sizeErrorCode -ne 0) {
        return [FirmwareVariable]::new($VariableName, $Guid, $null, 0, $false, $sizeErrorCode, "Size check failed: $sizeErrorCode")
    }
    
    # Step 2: Allocate buffer and read value
    if ($requiredSize -gt 0 -and $requiredSize -le $MaxBufferSize) {
        $buffer = New-Object System.Text.StringBuilder([int]$requiredSize)
        $bufferSize = $requiredSize
        
        # Clear error again
        [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        
        $readSuccess = [FirmwareUtils]::GetFirmwareEnvironmentVariableExW(
            $VariableName,
            $Guid,
            $buffer,
            [ref]$bufferSize,
            [FirmwareUtils]::FW_FLAGS_DEFAULT
        )
        
        $readErrorCode = [FirmwareUtils]::GetLastError()
        
        Write-Verbose "Read attempt - Success: $readSuccess, BufferSize: $bufferSize, Error: $readErrorCode"
        
        if ($readSuccess -and $bufferSize -gt 0) {
            $value = $buffer.ToString()
            # Remove null terminators and trim
            $cleanValue = $value -replace "[\x00]+$", ""
            return [FirmwareVariable]::new($VariableName, $Guid, $cleanValue, $bufferSize, $true, 0, $null)
        }
        else {
            return [FirmwareVariable]::new($VariableName, $Guid, $null, $bufferSize, $false, $readErrorCode, "Read failed: $readErrorCode")
        }
    }
    
    # Buffer too large
    return [FirmwareVariable]::new($VariableName, $Guid, $null, $requiredSize, $false, 0, "Buffer size $requiredSize exceeds max $MaxBufferSize")
}

function Test-FirmwareAPI {
    Write-Host "=== Pure API Firmware Test ===" -ForegroundColor Cyan
    Write-Host "System: $env:COMPUTERNAME" -ForegroundColor White
    Write-Host "Admin: $([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] ""Administrator"")" -ForegroundColor White
    Write-Host "=" * 40 -ForegroundColor Cyan
    
    # Test 1: Basic API functionality with known variable
    Write-Host "`n[1] Testing basic API with SecureBoot..." -ForegroundColor Yellow
    $secureBoot = Get-FirmwareEnvironmentVariableRaw -VariableName "SecureBoot" -Guid "{00000000-0000-0000-0000-000000000000}" -Verbose
    if ($secureBoot.Success) {
        Write-Host "  ✓ SecureBoot found: $($secureBoot.Value)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ SecureBoot: $($secureBoot.ErrorMessage) (Code: $($secureBoot.ErrorCode))" -ForegroundColor Red
    }
    
    # Test 2: Try Microsoft-specific GUIDs from the article
    Write-Host "`n[2] Testing Microsoft UEFI GUIDs..." -ForegroundColor Yellow
    $msGuids = @(
        "{F0ACCCF1-A331-4F48-9EA0-646D71703B2A}",  # Microsoft UEFI CA 2023
        "{77FA9ABD-0359-4D32-BD60-28F4E78F784B}",  # Microsoft Windows UEFI CA
        "{A5C13B10-30E6-11D0-A7E3-00C04FD7BA7B}"   # Microsoft Corporation UEFI CA
    )
    
    $foundMsVars = @()
    foreach ($guid in $msGuids) {
        $testVar = Get-FirmwareEnvironmentVariableRaw -VariableName "db" -Guid $guid -Verbose
        if ($testVar.Success) {
            Write-Host "  ✓ Microsoft GUID [$guid]: db = $($testVar.Value.Substring(0,50))..." -ForegroundColor Green
            $foundMsVars += $testVar
        } else {
            Write-Host "  - Microsoft GUID [$guid]: $($testVar.ErrorMessage)" -ForegroundColor Gray
        }
    }
    
    # Test 3: Standard UEFI variables with different GUIDs
    Write-Host "`n[3] Testing standard UEFI variables..." -ForegroundColor Yellow
    $standardVars = @("PK", "KEK", "db", "dbx", "SecureBoot", "SetupMode")
    $uefiGuid = "{00000000-0000-0000-0000-000000000000}"
    
    foreach ($var in $standardVars) {
        $result = Get-FirmwareEnvironmentVariableRaw -VariableName $var -Guid $uefiGuid -Verbose
        if ($result.Success) {
            $displayValue = if ($result.Value.Length -gt 30) { $result.Value.Substring(0,30) + "..." } else { $result.Value }
            Write-Host "  ✓ $var [$uefiGuid]: $displayValue (Size: $($result.Size))" -ForegroundColor Green
        } else {
            Write-Host "  - $var [$uefiGuid]: $($result.ErrorMessage)" -ForegroundColor Gray
        }
    }
    
    # Test 4: HP-specific variables
    Write-Host "`n[4] Testing HP ZBook variables..." -ForegroundColor Yellow
    $hpVars = @("HP-SureStart", "HP-SecureBoot", "HP-PK", "HP-KEK", "HP-db", "HP-dbx")
    $hpGuids = @(
        "{00000000-0000-0000-0000-000000000000}",  # Global
        "{FAF365C8-89B9-4502-B9B9-5A7D6D4C4C4C}",  # HP-specific (guessing)
        "{A3B5576E-7F4E-11E0-9D45-0C04FD7D62F3}"   # HP Sure Start
    )
    
    foreach ($var in $hpVars) {
        foreach ($guid in $hpGuids) {
            $result = Get-FirmwareEnvironmentVariableRaw -VariableName $var -Guid $guid -Verbose
            if ($result.Success) {
                $displayValue = if ($result.Value.Length -gt 30) { $result.Value.Substring(0,30) + "..." } else { $result.Value }
                Write-Host "  ✓ HP $var [$guid]: $displayValue (Size: $($result.Size))" -ForegroundColor Green
                break  # Found it, no need to test other GUIDs
            }
        }
    }
    
    # Test 5: Brute force enumeration of common variable names
    Write-Host "`n[5] Enumerating common certificate variables..." -ForegroundColor Yellow
    $certVars = @("MicrosoftCorporationUEFICA2011", "MicrosoftWindowsUEFICA2011", 
                  "MicrosoftUEFICA2011", "MicrosoftWindowsProductionPCA2011")
    
    foreach ($var in $certVars) {
        $result = Get-FirmwareEnvironmentVariableRaw -VariableName $var -Guid "{00000000-0000-0000-0000-000000000000}" -Verbose
        if ($result.Success) {
            $displayValue = if ($result.Value.Length -gt 50) { $result.Value.Substring(0,50) + "..." } else { $result.Value }
            Write-Host "  ✓ CERT $var $displayValue (Size: $($result.Size))" -ForegroundColor Green
        }
    }
    
    return @{
        SecureBoot = $secureBoot
        MicrosoftVars = $foundMsVars
        StandardVars = $standardVars | ForEach-Object { Get-FirmwareEnvironmentVariableRaw -VariableName $_ -Guid $uefiGuid }
        AllResults = @($secureBoot) + $foundMsVars
    }
}

function Get-FirmwareCertificateChain {
    Write-Host "`n[6] Testing 2023 Microsoft UEFI Certificates..." -ForegroundColor Yellow
    
    # Variables mentioned in the Microsoft article
    $certVariables = @(
        # 2023 certificates
        "MicrosoftWindowsUEFICA2023",
        "MicrosoftCorporationUEFICA2023",
        "MicrosoftWindowsProductionPCA2023",
        
        # Legacy certificates (for comparison)
        "MicrosoftWindowsUEFICA2011", 
        "MicrosoftCorporationUEFICA2011",
        "MicrosoftWindowsProductionPCA2011"
    )
    
    $results = @()
    foreach ($certVar in $certVariables) {
        # Try multiple GUIDs that might contain these certificates
        $testGuids = @(
            "{00000000-0000-0000-0000-000000000000}",      # Global namespace
            "{F0ACCCF1-A331-4F48-9EA0-646D71703B2A}",      # Microsoft UEFI 2023
            "{77FA9ABD-0359-4D32-BD60-28F4E78F784B}",      # Microsoft Windows UEFI
            "{A5C13B10-30E6-11D0-A7E3-00C04FD7BA7B}"       # Microsoft Corporation UEFI
        )
        
        foreach ($guid in $testGuids) {
            $result = Get-FirmwareEnvironmentVariableRaw -VariableName $certVar -Guid $guid
            if ($result.Success) {
                $results += $result
                $displayValue = if ($result.Value.Length -gt 100) { 
                    "Binary Certificate Data (" + $result.Size + " bytes)" 
                } else { 
                    $result.Value 
                }
                Write-Host "  ✓ $certVar [$guid]: $displayValue" -ForegroundColor Green
                break
            }
        }
    }
    
    return $results
}

# Main execution - PURE API ONLY
Clear-Host
Write-Host "=== Windows API Firmware Variable Scanner ===" -ForegroundColor Cyan
Write-Host "Target: 2023 Microsoft UEFI Certificates" -ForegroundColor Magenta
Write-Host "System: $env:COMPUTERNAME" -ForegroundColor White
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "=" * 50 -ForegroundColor Cyan

# Verify admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Warning "⚠ NOT RUNNING AS ADMINISTRATOR - Firmware access will fail!"
    Write-Host "   Right-click PowerShell → 'Run as administrator'" -ForegroundColor Yellow
}

# Run the comprehensive API test
$apiResults = Test-FirmwareAPI

# Test specifically for the 2023 certificates
$certResults = Get-FirmwareCertificateChain

# Combine all results
$allResults = $apiResults.AllResults + $certResults

# Display summary table
Write-Host "`n=== API RESULTS SUMMARY ===" -ForegroundColor Cyan
$allResults | Where-Object Success -eq $true | Format-Table Name, Guid, @{Label="Value Preview"; Expression={
    if ($_.Value.Length -gt 40) { 
        $_.Value.Substring(0,40) + "..." 
    } elseif ($_.Value) { 
        $_.Value 
    } else { 
        "Binary (" + $_.Size + " bytes)" 
    }
}}, Size -AutoSize -Wrap

# Export raw results
$exportPath = "FirmwareAPI_Scan_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$allResults | Export-Csv -Path $exportPath -NoTypeInformation
Write-Host "`n📄 Raw API results exported: $exportPath" -ForegroundColor Green

# Check for 2023 certificates specifically
$has2023Certs = $allResults | Where-Object { 
    $_.Name -match "2023" -and $_.Success 
}
if ($has2023Certs) {
    Write-Host "`n🎉 2023 MICROSOFT UEFI CERTIFICATES FOUND!" -ForegroundColor Green
    $has2023Certs | ForEach-Object { 
        Write-Host "   ✓ $($_.Name) [$($_.Guid)] - $($_.Size) bytes" -ForegroundColor Green 
    }
} else {
    Write-Host "`nℹ No 2023 certificates found via API" -ForegroundColor Yellow
    Write-Host "   This could mean:" -ForegroundColor Gray
    Write-Host "   • Certificates stored under different names" -ForegroundColor Gray
    Write-Host "   • HP firmware uses custom GUIDs/namespaces" -ForegroundColor Gray
    Write-Host "   • Direct API access restricted by OEM" -ForegroundColor Gray
}

Write-Host "`n=== NEXT STEPS ===" -ForegroundColor Cyan
Write-Host "1. Check the exported CSV for any binary data (certificates)" -ForegroundColor White
Write-Host "2. If no results, HP may be using non-standard variable names" -ForegroundColor White
Write-Host "3. Consider using 'efibootmgr' or 'mokutil' from Linux live USB" -ForegroundColor White
Write-Host "4. Check HP Sure Start logs for certificate information" -ForegroundColor White

Write-Host "`nAPI scan complete!" -ForegroundColor Green