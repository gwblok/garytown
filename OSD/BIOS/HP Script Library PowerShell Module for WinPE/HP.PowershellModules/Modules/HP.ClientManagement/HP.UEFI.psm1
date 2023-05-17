#
#  Copyright 2018-2021 HP Development Company, L.P.
#  All Rights Reserved.
#
# NOTICE:  All information contained herein is, and remains the property of HP Development Company, L.P.
#
# The intellectual and technical concepts contained herein are proprietary to HP Development Company, L.P
# and may be covered by U.S. and Foreign Patents, patents in process, and are protected by
# trade secret or copyright law. Dissemination of this information or reproduction of this material
# is strictly forbidden unless prior written permission is obtained from HP Development Company, L.P.
#

Set-StrictMode -Version Latest

$interop = @'
using System;
using System.Runtime.InteropServices;

public enum PrivilegeState {
    Enabled,
    Disabled
};

public class Native
{
    [DllImport("kernel32.dll", ExactSpelling = true,  SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern UInt32 GetFirmwareEnvironmentVariableExW(string Name, string NamespaceGuid, [Out] Byte[] Buffer, UInt32 bufferSize, [Out] out UInt32 Attributes);

    [DllImport("kernel32.dll", ExactSpelling = true,  SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern UInt32 SetFirmwareEnvironmentVariableExW(string Name, string NamespaceGuid, Byte[] Buffer, UInt32 bufferSize, UInt32 Attributes);

    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    internal static extern bool AdjustTokenPrivileges(IntPtr TokenHandle, bool DisableAllPrivileges, ref TokenPrivileges NewState, int BufferLength, ref TokenPrivileges PreviousState, ref int ReturnLength);

    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    internal static extern bool OpenProcessToken(IntPtr ProcessHandle, int DesiredAccess, ref IntPtr TokenHandle);

    [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)]
    internal static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, IntPtr pid);

    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true,  CharSet = CharSet.Unicode)]
    internal static extern bool LookupPrivilegeValueW(string SystemName, string PrivilegeName, ref long LUID);

    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool CloseHandle(IntPtr ObjectHandle);

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    internal struct TokenPrivileges
    {
        public int PrivilegeCount; // always 1 here, we do one at a time
        public long LUID;
        public int Attributes;
    }

    internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
    internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
    internal const int TOKEN_QUERY = 0x00000008;
    internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
    internal const int PROCESS_QUERY_INFORMATION = 0x00000400;

    public static int EnablePrivilege(long Pid, string Privilege, out PrivilegeState PreviousState, PrivilegeState NewState)
    {
        bool ret;
        TokenPrivileges newTokenPriv;
        TokenPrivileges previousTokenPriv = new TokenPrivileges();
        int previousTokenPrivSize = 0;
        IntPtr ProcHandle = new IntPtr(Pid);
        IntPtr TokenHandle = IntPtr.Zero;

        PreviousState = PrivilegeState.Disabled;

        ProcHandle = OpenProcess(PROCESS_QUERY_INFORMATION, false, ProcHandle);
        if (ProcHandle == null) {
            return Marshal.GetLastWin32Error();
        }

        ret = OpenProcessToken(ProcHandle, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref TokenHandle);
        if (!ret) {
            return Marshal.GetLastWin32Error();
        }

        newTokenPriv.PrivilegeCount = 1;
        newTokenPriv.LUID = 0;
        newTokenPriv.Attributes = (NewState == PrivilegeState.Disabled) ? SE_PRIVILEGE_DISABLED : SE_PRIVILEGE_ENABLED;

        ret = LookupPrivilegeValueW(null, Privilege, ref newTokenPriv.LUID);
        if (!ret) {
            CloseHandle(TokenHandle);
            return Marshal.GetLastWin32Error();
        }

        ret = AdjustTokenPrivileges(TokenHandle, false, ref newTokenPriv, 256, ref previousTokenPriv, ref previousTokenPrivSize);
        if (!ret) {
            CloseHandle(TokenHandle);
            return Marshal.GetLastWin32Error();
        } else {
            PreviousState = (previousTokenPriv.Attributes == SE_PRIVILEGE_ENABLED) ? PrivilegeState.Enabled : PrivilegeState.Disabled;
        }

        CloseHandle(TokenHandle);
        return 0;
    }
}

'@

Add-Type $interop -Passthru

[Flags()] enum UEFIVariableAttributes{
  VARIABLE_ATTRIBUTE_NON_VOLATILE = 0x00000001
  VARIABLE_ATTRIBUTE_BOOTSERVICE_ACCESS = 0x00000002
  VARIABLE_ATTRIBUTE_RUNTIME_ACCESS = 0x00000004
  VARIABLE_ATTRIBUTE_HARDWARE_ERROR_RECORD = 0x00000008
  VARIABLE_ATTRIBUTE_AUTHENTICATED_WRITE_ACCESS = 0x00000010
  VARIABLE_ATTRIBUTE_TIME_BASED_AUTHENTICATED_WRITE_ACCESS = 0x00000020
  VARIABLE_ATTRIBUTE_APPEND_WRITE = 0x00000040
}


<#
    .SYNOPSIS
    Read a UEFI variable value. 

    .DESCRIPTION
    This function reads the value of a UEFI variable. 

    .PARAMETER Name
    The name of the UEFI variable to read

    .PARAMETER Namespace
    Look for the variable in the specified custom namespace. The namespace must be in the format of a UUID, surrounded by curly brackets.

    .PARAMETER AsString
    Return the value as a string rather than a byte array. Note that the functions in this library support UTF-8 compatible strings. Other applications may store strings that are not compatible with this translation, in which
    case the caller should retrieve the value as an array (default) and post-process it as needed.

    .EXAMPLE
    PS>  Get-UEFIVariable -GlobalNamespace -Name MyVariable

    .EXAMPLE
    PS>  Get-UEFIVariable -Namespace "{21969aa8-681f-46be-90f0-6019ce9b0ee7}"  -Name MyVariable

    .NOTES
    The process calling these functions must be able to acquire 'SeSystemEnvironmentPrivilege' privileges for the operation to succeed. For more information, refer to "Modify firmware environment values" in the linked documentation below.

    .OUTPUTS
    This function returns a custom object that contains the variable value and its attributes.

    .LINK
    [UEFI Specification 2.3.1 Section 7.2](https://www.uefi.org/specifications)

    .LINK
    [Modify firmware environment values](https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/modify-firmware-environment-values)
#>
function Get-UEFIVariable
{
  [CmdletBinding(DefaultParameterSetName = 'NsCustom',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90UEFIVariable")]
  param(
    [Parameter(Position = 0,Mandatory = $true,ParameterSetName = "NsCustom")]
    [string]$Name,

    [Parameter(Position = 1,Mandatory = $true,ParameterSetName = "NsCustom")]
    [string]$Namespace,

    [Parameter(Position = 2,Mandatory = $false,ParameterSetName = "NsCustom")]
    [switch]$AsString
  )

  $PreviousState = [PrivilegeState]::Enabled;
  $enablePrivilege = [Native]::EnablePrivilege($PID,"SeSystemEnvironmentPrivilege",[ref]$PreviousState,[PrivilegeState]::Enabled)
  if ($enablePrivilege -ne 0) {
    $err = [System.ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error();
    throw [UnauthorizedAccessException]"Current user cannot acquire UEFI variable access permissions: $err ($enablePrivilege)"
  }
  else {
    $prevStateStr = if ($PreviousState -eq [PrivilegeState]::Enabled) { "enabled" } else { "disabled" }
    Write-Verbose "Enabling application privilege, it was $prevStateStr before"
  }

  # todo - note fixed max size
  $size = 1024
  $result = New-Object Byte[] (1024)
  [uint32]$attr = 0

  Write-Verbose "Querying UEFI variable $Namespace/$Name"
  if ([Native]::GetFirmwareEnvironmentVariableExW($Name,$Namespace,$result,$size,[ref]$attr) -eq 0)
  {
    $err = [System.ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error();
    Write-Verbose "Found error: $err"
    throw "Could not read UEFI variable: $err";
  }

  $r = [pscustomobject]@{
    Value = ''
    Attributes = [UEFIVariableAttributes]$attr
  }
  if ($asString.IsPresent) {
    $enc = [System.Text.Encoding]::UTF8
    $r.Value = $enc.GetString($result)
  }
  else {
    $r.Value = [array]$result
  }

  if ($PreviousState -eq [PrivilegeState]::Disabled)
  {
    Write-Verbose "Disabling application privilege"
    [void][Native]::EnablePrivilege($PID,"SeSystemEnvironmentPrivilege",[ref]$PreviousState,[PrivilegeState]::Disabled)
  }
  $r
}

<#
    .SYNOPSIS
    Set a UEFI variable value. 

    .DESCRIPTION
    This function sets the value of a UEFI variable. If the variable does not exist, it is created.

    .PARAMETER Name
    The name of the UEFI variable to update or create.

    .PARAMETER Namespace
    Look for the variable in the specified custom namespace. The namespace must be in the format of a UUID, surrounded by curly brackets.

    .PARAMETER Value
    The  new value for the variable. Note that a NULL value will delete the variable.

    The value may be a byte array (type byte[],  recommended), or a string which will be converted to UTF8 and stored as a byte array.

    .PARAMETER Attributes
    The attributes for the variable. For more information, see the UEFI specification linked below.

    Attributes may be:

    - VARIABLE_ATTRIBUTE_NON_VOLATILE: The firmware environment variable is stored in non-volatile memory (e.g. NVRAM). 
    - VARIABLE_ATTRIBUTE_BOOTSERVICE_ACCESS: The firmware environment variable can be accessed during boot service. 
    - VARIABLE_ATTRIBUTE_RUNTIME_ACCESS:  The firmware environment variable can be accessed at runtime. Note  Variables with this attribute set, must also have VARIABLE_ATTRIBUTE_BOOTSERVICE_ACCESS set. 
    - VARIABLE_ATTRIBUTE_HARDWARE_ERROR_RECORD:  Indicates hardware related errors encountered at runtime. 
    - VARIABLE_ATTRIBUTE_AUTHENTICATED_WRITE_ACCESS: Indicates an authentication requirement that must be met before writing to this firmware environment variable. 
    - VARIABLE_ATTRIBUTE_TIME_BASED_AUTHENTICATED_WRITE_ACCESS: Indicates authentication and time stamp requirements that must be met before writing to this firmware environment variable. When this attribute is set, the buffer, represented by pValue, will begin with an instance of a complete (and serialized) EFI_VARIABLE_AUTHENTICATION_2 descriptor. 
    - VARIABLE_ATTRIBUTE_APPEND_WRITE: Append an existing environment variable with the value of pValue. If the firmware does not support the operation, then SetFirmwareEnvironmentVariableEx will return ERROR_INVALID_FUNCTION.

    .EXAMPLE
    PS>  Set-UEFIVariable -Namespace "{21969aa8-681f-46be-90f0-6019ce9b0ee7}" -Name MyVariable -Value [byte[]]1,2,3

    .EXAMPLE
    PS>  Set-UEFIVariable -Namespace "{21969aa8-681f-46be-90f0-6019ce9b0ee7}" -Name MyVariable -Value "ABC"

    .NOTES
    It is not recommended that the attributes of an existing variable are updated. If new attributes are required, the value should be deleted and re-created.

    The process calling these functions must be able to acquire 'SeSystemEnvironmentPrivilege' privileges for the operation to succeed. For more information, refer to "Modify firmware environment values" in the linked documentation below.

    .LINK
    [UEFI Specification 2.3.1 Section 7.2](https://www.uefi.org/specifications)

    .LINK
    [Modify firmware environment values](https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/modify-firmware-environment-values)
#>

function Set-UEFIVariable
{

  [CmdletBinding(DefaultParameterSetName = 'NsCustom',HelpUri = "https://developers.hp.com/hp-client-management/doc/Set%E2%80%90UEFIVariable")]
  param(
    [Parameter(Position = 0,Mandatory = $true,ParameterSetName = "NsCustom")]
    [string]$Name,

    [Parameter(Position = 1,Mandatory = $true,ParameterSetName = "NsCustom")]
    $Value,

    [Parameter(Position = 2,Mandatory = $true,ParameterSetName = "NsCustom")]
    [string]$Namespace,

    [Parameter(Position = 3,Mandatory = $false,ParameterSetName = "NsCustom")]
    [UEFIVariableAttributes]$Attributes = 7
  )

  $err = "The Value must be derived from base types 'String' or 'Byte[]'"

  $rawvalue = switch ($Value.GetType().Name) {
    "String" {
      $enc = [System.Text.Encoding]::UTF8
      $v = $enc.GetBytes($Value)
      Write-Verbose "String value representation is $v"
      $v
    }
    "Object[]" {
      try {
        $v = [byte[]]$Value
        Write-Verbose "Byte array value representation is $v"
        $v
      }
      catch {
        throw $err
      }
    }
    default {
      throw $err
    }
  }


  $PreviousState = [PrivilegeState]::Enabled;
  $enablePrivilege = [Native]::EnablePrivilege($PID,"SeSystemEnvironmentPrivilege",[ref]$PreviousState,[PrivilegeState]::Enabled)
  if ($enablePrivilege -ne 0) {
    $err = [System.ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error();
    throw [UnauthorizedAccessException]"Current user cannot acquire UEFI variable access permissions: $err ($enablePrivilege)"
  }
  else {
    $prevStateStr = if ($PreviousState -eq [PrivilegeState]::Enabled) { "enabled" } else { "disabled" }
    Write-Verbose "Enabling application privilege, it was $prevStateStr before"
  }

  $len = 0
  if ($rawvalue) { $len = $rawvalue.Length }

  if (-not $len -and -not ($Attributes -band [UEFIVariableAttributes]::VARIABLE_ATTRIBUTE_AUTHENTICATED_WRITE_ACCESS -or
      $Attributes -band [UEFIVariableAttributes]::VARIABLE_ATTRIBUTE_TIME_BASED_AUTHENTICATED_WRITE_ACCESS -or
      $Attributes -band [UEFIVariableAttributes]::VARIABLE_ATTRIBUTE_APPEND_WRITE)) {
    # Any attribute different from 0x40, 0x10 and 0x20 combined with a value size of zero removes the UEFI variable.
    # Note that zero is not a valid attribute, see [UEFIVariableAttributes] enum
    Write-Verbose "Deleting UEFI variable $Namespace/$Name"
  }
  else {
    Write-Verbose "Setting UEFI variable $Namespace/$Name to value $rawvalue (length = $len)"
  }

  if ([Native]::SetFirmwareEnvironmentVariableExW($Name,$Namespace,$rawvalue,$len,$Attributes) -eq 0)
  {
    $err = [System.ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error();
    Write-Verbose "Found error: $err"
    throw "Could not write UEFI variable: $err";
  }


  if ($PreviousState -eq [PrivilegeState]::Disabled)
  {
    Write-Verbose "Disabling application privilege"
    [void][Native]::EnablePrivilege($PID,"SeSystemEnvironmentPrivilege",[ref]$PreviousState,[PrivilegeState]::Disabled)
  }
}

<#
    .SYNOPSIS
    Remove a UEFI variable

    .DESCRIPTION
    This function removes a UEFI variable from a well-known or user-supplied namespace. 

    .PARAMETER Name
    The name of the UEFI variable to remove

    .PARAMETER Namespace
    Look for the variable in the specified custom namespace. The namespace must be in the format of a UUID, surrounded by curly brackets.
    
    .EXAMPLE
    PS>  Remove-UEFIVariable -Namespace "{21969aa8-681f-46be-90f0-6019ce9b0ee7}" -Name MyVariable

    .NOTES
    The process calling these functions must be able to acquire 'SeSystemEnvironmentPrivilege' privileges for the operation to succeed. For more information, refer to "Modify firmware environment values" in the linked documentation below.

    .LINK
    [Modify firmware environment values](https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/modify-firmware-environment-values)

#>
function Remove-UEFIVariable
{
  [CmdletBinding(DefaultParameterSetName = 'NsCustom',HelpUri = "https://developers.hp.com/hp-client-management/doc/Remove%E2%80%90UEFIVariable")]
  param(
    [Parameter(Position = 0,Mandatory = $true,ParameterSetName = "NsCustom")]
    [string]$Name,

    [Parameter(Position = 1,Mandatory = $true,ParameterSetName = "NsCustom")]
    [string]$Namespace
  )
  Set-UEFIVariable @PSBoundParameters -Value "" -Attributes 7
}

# SIG # Begin signature block
# MIIaywYJKoZIhvcNAQcCoIIavDCCGrgCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDN836vbSJJEKuV
# AryotMvgaLW9MPJnqg1+EJhgf2AUraCCCm8wggUwMIIEGKADAgECAhAECRgbX9W7
# ZnVTQ7VvlVAIMA0GCSqGSIb3DQEBCwUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMzEwMjIxMjAwMDBa
# Fw0yODEwMjIxMjAwMDBaMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lD
# ZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQD407Mcfw4Rr2d3B9MLMUkZz9D7RZmxOttE9X/l
# qJ3bMtdx6nadBS63j/qSQ8Cl+YnUNxnXtqrwnIal2CWsDnkoOn7p0WfTxvspJ8fT
# eyOU5JEjlpB3gvmhhCNmElQzUHSxKCa7JGnCwlLyFGeKiUXULaGj6YgsIJWuHEqH
# CN8M9eJNYBi+qsSyrnAxZjNxPqxwoqvOf+l8y5Kh5TsxHM/q8grkV7tKtel05iv+
# bMt+dDk2DZDv5LVOpKnqagqrhPOsZ061xPeM0SAlI+sIZD5SlsHyDxL0xY4PwaLo
# LFH3c7y9hbFig3NBggfkOItqcyDQD2RzPJ6fpjOp/RnfJZPRAgMBAAGjggHNMIIB
# yTASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAK
# BggrBgEFBQcDAzB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHow
# eDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJl
# ZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBPBgNVHSAESDBGMDgGCmCGSAGG/WwA
# AgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAK
# BghghkgBhv1sAzAdBgNVHQ4EFgQUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHwYDVR0j
# BBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDQYJKoZIhvcNAQELBQADggEBAD7s
# DVoks/Mi0RXILHwlKXaoHV0cLToaxO8wYdd+C2D9wz0PxK+L/e8q3yBVN7Dh9tGS
# dQ9RtG6ljlriXiSBThCk7j9xjmMOE0ut119EefM2FAaK95xGTlz/kLEbBw6RFfu6
# r7VRwo0kriTGxycqoSkoGjpxKAI8LpGjwCUR4pwUR6F6aGivm6dcIFzZcbEMj7uo
# +MUSaJ/PQMtARKUT8OZkDCUIQjKyNookAv4vcn4c10lFluhZHen6dGRrsutmQ9qz
# sIzV6Q3d9gEgzpkxYz0IGhizgZtPxpMQBvwHgfqL2vmCSfdibqFT+hKUGIUukpHq
# aGxEMrJmoecYpJpkUe8wggU3MIIEH6ADAgECAhAFUi3UAAgCGeslOwtVg52XMA0G
# CSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0
# IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwHhcNMjEwMzIyMDAwMDAw
# WhcNMjIwMzMwMjM1OTU5WjB1MQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZv
# cm5pYTESMBAGA1UEBxMJUGFsbyBBbHRvMRAwDgYDVQQKEwdIUCBJbmMuMRkwFwYD
# VQQLExBIUCBDeWJlcnNlY3VyaXR5MRAwDgYDVQQDEwdIUCBJbmMuMIIBIjANBgkq
# hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtJ+rYUkseHcrB2M/GyomCEyKn9tCyfb+
# pByq/Jyf5kd3BGh+/ULRY7eWmR2cjXHa3qBAEHQQ1R7sX85kZ5sl2ukINGZv5jEM
# 04ERNfPoO9+pDndLWnaGYxxZP9Y+Icla09VqE/jfunhpLYMgb2CuTJkY2tT2isWM
# EMrKtKPKR5v6sfhsW6WOTtZZK+7dQ9aVrDqaIu+wQm/v4hjBYtqgrXT4cNZSPfcj
# 8W/d7lFgF/UvUnZaLU5Z/+lYbPf+449tx+raR6GD1WJBAzHcOpV6tDOI5tQcwHTo
# jJklvqBkPbL+XuS04IUK/Zqgh32YZvDnDohg0AEGilrKNiMes5wuAQIDAQABo4IB
# xDCCAcAwHwYDVR0jBBgwFoAUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHQYDVR0OBBYE
# FD4tECf7wE2l8kA6HTvOgkbo33MvMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAK
# BggrBgEFBQcDAzB3BgNVHR8EcDBuMDWgM6Axhi9odHRwOi8vY3JsMy5kaWdpY2Vy
# dC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDA1oDOgMYYvaHR0cDovL2NybDQu
# ZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwSwYDVR0gBEQwQjA2
# BglghkgBhv1sAwEwKTAnBggrBgEFBQcCARYbaHR0cDovL3d3dy5kaWdpY2VydC5j
# b20vQ1BTMAgGBmeBDAEEATCBhAYIKwYBBQUHAQEEeDB2MCQGCCsGAQUFBzABhhho
# dHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTgYIKwYBBQUHMAKGQmh0dHA6Ly9jYWNl
# cnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURDb2RlU2lnbmlu
# Z0NBLmNydDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IBAQBZca1CZfgn
# DucOwEDZk0RXqb8ECXukFiih/rPQ+T5Xvl3bZppGgPnyMyQXXC0fb94p1socJzJZ
# fn7rEQ4tHxL1vpBvCepB3Jq+i3A8nnJFHSjY7aujglIphfGND97U8OUJKt2jwnni
# EgsWZnFHRI9alEvfGEFyFrAuSo+uBz5oyZeOAF0lRqaRht6MtGTma4AEgq6Mk/iP
# LYIIZ5hXmsGYWtIPyM8Yjf//kLNPRn2WeUFROlboU6EH4ZC0rLTMbSK5DV+xL/e8
# cRfWL76gd/qj7OzyJR7EsRPg92RQUC4RJhCrQqFFnmI/K84lPyHRgoctAMb8ie/4
# X6KaoyX0Z93PMYIPsjCCD64CAQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoT
# DERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UE
# AxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQQIQBVIt
# 1AAIAhnrJTsLVYOdlzANBglghkgBZQMEAgEFAKB8MBAGCisGAQQBgjcCAQwxAjAA
# MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
# BgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCAEhk4Lgk8Fr/QxnP+nOFNwDwy9Lx8H
# bGV+vv0i41GqeDANBgkqhkiG9w0BAQEFAASCAQCfa4NZa/WjSJ+s4iQPbBs9F6mo
# 8VNNOm+Lrdclf5NcvW8b+DQep9mBNgfiGGdmcOP2Cm9skSK19odeCVLTAvqVKYHV
# e+jkyS32nKEfYu+t4EvIT4c2goYXrdTF3EcZJ/2GIgOO2BvuYBgTaEJpw9ZaD/Tj
# hFrueJ8R5tw/zA24Ft8AHi7daYJ/Nl8y0NtWML4KRm8GgrChWYmBttCPebAvKmXY
# x7lectBbo6E5tu9EtkJ2zM2hjVU3tDaiSNA0LfVhGNRenJ/8GtZ50DDFup+rYuVj
# LPtN4qQijb7gNsuFDrB8+JtzBdLd2eQUppe3puNgRHHiycHF3EPO4qQ3M2IAoYIN
# fjCCDXoGCisGAQQBgjcDAwExgg1qMIINZgYJKoZIhvcNAQcCoIINVzCCDVMCAQMx
# DzANBglghkgBZQMEAgEFADB4BgsqhkiG9w0BCRABBKBpBGcwZQIBAQYJYIZIAYb9
# bAcBMDEwDQYJYIZIAWUDBAIBBQAEIEw9u0cdYnzCzXGLLubPQnwaHXWEJy9B1fiu
# uBH16QNBAhEAkFt68/pw2sCkKBIQML6yYRgPMjAyMTExMjIxOTE5MDNaoIIKNzCC
# BP4wggPmoAMCAQICEA1CSuC+Ooj/YEAhzhQA8N0wDQYJKoZIhvcNAQELBQAwcjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElE
# IFRpbWVzdGFtcGluZyBDQTAeFw0yMTAxMDEwMDAwMDBaFw0zMTAxMDYwMDAwMDBa
# MEgxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjEgMB4GA1UE
# AxMXRGlnaUNlcnQgVGltZXN0YW1wIDIwMjEwggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDC5mGEZ8WK9Q0IpEXKY2tR1zoRQr0KdXVNlLQMULUmEP4dyG+R
# awyW5xpcSO9E5b+bYc0VkWJauP9nC5xj/TZqgfop+N0rcIXeAhjzeG28ffnHbQk9
# vmp2h+mKvfiEXR52yeTGdnY6U9HR01o2j8aj4S8bOrdh1nPsTm0zinxdRS1LsVDm
# QTo3VobckyON91Al6GTm3dOPL1e1hyDrDo4s1SPa9E14RuMDgzEpSlwMMYpKjIjF
# 9zBa+RSvFV9sQ0kJ/SYjU/aNY+gaq1uxHTDCm2mCtNv8VlS8H6GHq756WwogL0sJ
# yZWnjbL61mOLTqVyHO6fegFz+BnW/g1JhL0BAgMBAAGjggG4MIIBtDAOBgNVHQ8B
# Af8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDBB
# BgNVHSAEOjA4MDYGCWCGSAGG/WwHATApMCcGCCsGAQUFBwIBFhtodHRwOi8vd3d3
# LmRpZ2ljZXJ0LmNvbS9DUFMwHwYDVR0jBBgwFoAU9LbhIB3+Ka7S5GGlsqIlssgX
# NW4wHQYDVR0OBBYEFDZEho6kurBmvrwoLR1ENt3janq8MHEGA1UdHwRqMGgwMqAw
# oC6GLGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtdHMuY3Js
# MDKgMKAuhixodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLXRz
# LmNybDCBhQYIKwYBBQUHAQEEeTB3MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5k
# aWdpY2VydC5jb20wTwYIKwYBBQUHMAKGQ2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURUaW1lc3RhbXBpbmdDQS5jcnQwDQYJ
# KoZIhvcNAQELBQADggEBAEgc3LXpmiO85xrnIA6OZ0b9QnJRdAojR6OrktIlxHBZ
# vhSg5SeBpU0UFRkHefDRBMOG2Tu9/kQCZk3taaQP9rhwz2Lo9VFKeHk2eie38+dS
# n5On7UOee+e03UEiifuHokYDTvz0/rdkd2NfI1Jpg4L6GlPtkMyNoRdzDfTzZTlw
# S/Oc1np72gy8PTLQG8v1Yfx1CAB2vIEO+MDhXM/EEXLnG2RJ2CKadRVC9S0yOIHa
# 9GCiurRS+1zgYSQlT7LfySmoc0NR2r1j1h9bm/cuG08THfdKDXF+l7f0P4TrweOj
# SaH6zqe/Vs+6WXZhiV9+p7SOZ3j5NpjhyyjaW4emii8wggUxMIIEGaADAgECAhAK
# oSXW1jIbfkHkBdo2l8IVMA0GCSqGSIb3DQEBCwUAMGUxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# JDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xNjAxMDcx
# MjAwMDBaFw0zMTAxMDcxMjAwMDBaMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxE
# aWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMT
# KERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBpbmcgQ0EwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC90DLuS82Pf92puoKZxTlUKFe2I0rE
# DgdFM1EQfdD5fU1ofue2oPSNs4jkl79jIZCYvxO8V9PD4X4I1moUADj3Lh477sym
# 9jJZ/l9lP+Cb6+NGRwYaVX4LJ37AovWg4N4iPw7/fpX786O6Ij4YrBHk8JkDbTuF
# fAnT7l3ImgtU46gJcWvgzyIQD3XPcXJOCq3fQDpct1HhoXkUxk0kIzBdvOw8YGqs
# LwfM/fDqR9mIUF79Zm5WYScpiYRR5oLnRlD9lCosp+R1PrqYD4R/nzEU1q3V8mTL
# ex4F0IQZchfxFwbvPc3WTe8GQv2iUypPhR3EHTyvz9qsEPXdrKzpVv+TAgMBAAGj
# ggHOMIIByjAdBgNVHQ4EFgQU9LbhIB3+Ka7S5GGlsqIlssgXNW4wHwYDVR0jBBgw
# FoAUReuir/SSy4IxLVGLp6chnfNtyA8wEgYDVR0TAQH/BAgwBgEB/wIBADAOBgNV
# HQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgweQYIKwYBBQUHAQEEbTBr
# MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUH
# MAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJ
# RFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0LmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaGNGh0dHA6
# Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmww
# UAYDVR0gBEkwRzA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8v
# d3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUA
# A4IBAQBxlRLpUYdWac3v3dp8qmN6s3jPBjdAhO9LhL/KzwMC/cWnww4gQiyvd/Mr
# HwwhWiq3BTQdaq6Z+CeiZr8JqmDfdqQ6kw/4stHYfBli6F6CJR7Euhx7LCHi1lss
# FDVDBGiy23UC4HLHmNY8ZOUfSBAYX4k4YU1iRiSHY4yRUiyvKYnleB/WCxSlgNcS
# R3CzddWThZN+tpJn+1Nhiaj1a5bA9FhpDXzIAbG5KHW3mWOFIoxhynmUfln8jA/j
# b7UBJrZspe6HUSHkWGCbugwtK22ixH67xCUrRwIIfEmuE7bhfEJCKMYYVs9BNLZm
# XbZ0e/VWMyIvIjayS6JKldj1po5SMYIChjCCAoICAQEwgYYwcjELMAkGA1UEBhMC
# VVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0
# LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIFRpbWVzdGFt
# cGluZyBDQQIQDUJK4L46iP9gQCHOFADw3TANBglghkgBZQMEAgEFAKCB0TAaBgkq
# hkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTIxMTEyMjE5
# MTkwM1owKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQU4deCqOGRvu9ryhaRtaq0lKYk
# m/MwLwYJKoZIhvcNAQkEMSIEID1T4m9EmOEQbYzIpVJf2nUVkl9NOB9q+WLGLa1A
# qdxJMDcGCyqGSIb3DQEJEAIvMSgwJjAkMCIEILMQkAa8CtmDB5FXKeBEA0Fcg+Mp
# K2FPJpZMjTVx7PWpMA0GCSqGSIb3DQEBAQUABIIBAKVPz4looCsLT3Tbh4yY4bLi
# GJnQo5HBBfKuedJZyZm9VfkTuSBufvbq8tigQsFKO5ppA28LwR2/UZ6nVk1s+EoH
# c/uLZyA32dECwqFhtAaH4DNfLmBaaPq9I3fmAh6orRO3dxpjTX67hMcbEKrhZe41
# flNkYS+xbvxdMEo95TjfUm8VuNSd4mIZmJdirUtus6SXeqZhitty7yfysYJyAuoZ
# BWKIja5XgsLq1gNhz3gv4U0+lkoB87mwn+UHbYmvF96y2Lv+m2/PMOQ2WCy+hEb3
# sOVDcBgCXA02GtENnOlho6/ZvZPhJly6DfvhxfEa7jMMx5YemPv1l+uW7/72g88=
# SIG # End signature block
