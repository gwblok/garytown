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




enum TelemetryManagedBy
{
  User = 0
  Organization = 1
}

enum TelemetryPurpose
{
  Marketing = 1
  Support = 2
  ProductEnhancement = 3

}


$ConsentPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\HP\Consent'


<#
.SYNOPSIS
    Retrieve the current configured HP Analytics reporting configuration

.DESCRIPTION
    This commands retrieves the configuration of the HP Analytics client. The returned object contains the following fields:
    
    - **ManagedBy** - May be 'User' (self-managed) or 'Organization' (IT managed)
    - **AllowedCollectionPurposes** - A collection of allowed purposes, one or more of:
        * Marketing - Analytics are allowed for Marketing purposes
        * Support - Analytics are allowed for Support purposes
        * ProductEnhancement - Analytics are allowed for Product Enhancement purposes
    - *TenantID* - An organization-configured tenant ID. This is an optional GUID, defined by the IT Administrator. If not defined, it will default to the value "Individual"

.EXAMPLE
    PS C:\> Get-HPAnalyticsConsentConfiguration

    Name                           Value
    ----                           -----
    ManagedBy                      User
    AllowedCollectionPurposes      {Marketing}
    TenantID                       Individual


.LINK
  [Set-HPAnalyticsConsentTenantID](Set-HPAnalyticsConsentTenantID)

.LINK
    [Set-HPAnalyticsConsentAllowedPurposes](Set-HPAnalyticsConsentAllowedPurposes)

.LINK
  [Set-HPAnalyticsConsentDeviceOwnership](Set-HPAnalyticsConsentDeviceOwnership)

.LINK
  For a discussion of these settings, see [https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf](https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf) 
#>
function Get-HPAnalyticsConsentConfiguration
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPAnalyticsConsentConfiguration")]
  param()

  $obj = [ordered]@{
    ManagedBy = [TelemetryManagedBy]"User"
    AllowedCollectionPurposes = [TelemetryPurpose[]]@()
    TenantID = "Individual"
  }

  if (Test-Path $ConsentPath)
  {
    $key = Get-ItemProperty $ConsentPath
    if ($key) {
      if ($key.Managed -eq "True") { $obj.ManagedBy = "Organization" }

      [TelemetryPurpose[]]$purpose = @()
      if ($key.AllowMarketing -eq "Accepted") { $purpose += "Marketing" }
      if ($key.AllowSupport -eq "Accepted") { $purpose += "Support" }
      if ($key.AllowProductEnhancement -eq "Accepted") { $purpose += "ProductEnhancement" }

      ([TelemetryPurpose[]]$obj.AllowedCollectionPurposes) = $purpose
      if ($key.TenantID) {
        $obj.TenantID = $key.TenantID
      }

    }


  }
  else {
    Write-Verbose 'Consent registry key does not exist.'
  }
  $obj
}

<#
.SYNOPSIS
    Sets the ManagedBy (ownership) of a device, for the purpose of HP Analytics reporting.
 
.DESCRIPTION
    This command configures HP Analytics ownership value to either 'User' or 'Organization'.

    - *User* - This device is managed by the end user
    - *Organization* - This device is managed by an organization's IT administrator

.PARAMETER Owner
  Specify User or Organization as the owner of the device.

.EXAMPLE
    # Set the device to be owned by a User
    PS C:\> Set-HPAnalyticsDeviceOwnership -Owner User

.EXAMPLE
    # Set the device to be owned by an Organization
    PS C:\> Set-HPAnalyticsDeviceOwnership -Owner Organization


.LINK
  [Get-HPAnalyticsConsentConfiguration](Get-HPAnalyticsConsentConfiguration)

.LINK
  [Set-HPAnalyticsConsentTenantID](Set-HPAnalyticsConsentTenantID)

.LINK
    [Set-HPAnalyticsConsentAllowedPurposes](Set-HPAnalyticsConsentAllowedPurposes)


.LINK
  For a discussion of these settings, see [https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf](https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf) 
#>
function Set-HPAnalyticsConsentDeviceOwnership
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Set%E2%80%90HPAnalyticsConsentDeviceOwnership")]
  param(
    [Parameter(Mandatory = $true,Position = 0)]
    [TelemetryManagedBy]$Owner
  )

  $Managed = ($Owner -eq "Organization")
  New-ItemProperty -Path $ConsentPath -Name "Managed" -Value $Managed -Force | Out-Null

}


<#
.SYNOPSIS
  Sets the Tenant ID of a device, for the purpose of HP Analytics reporting.

.DESCRIPTION
  This command configures HP Analytics Tenant ID. This value is optional, and defined by the organization. A valid value must be a GUID value.

  If the Tenant ID is not set, the default value is the fixed string 'Individual'

.PARAMETER UUID
  Set the UUID to the specified GUID. If a value is already configured, the operation will fail unless the -Force parameter is also specified.

.PARAMETER NewUUID
  Set the UUID to an auto-generated UUID. If a value is already configured, the operation will fail unless the -Force parameter is also specified.

.PARAMETER None
  Set the UUID to an auto-generated UUID. If a value is already configured, the operation will fail unless the -Force parameter is also specified.

.PARAMETER Force
  Force setting the Tenant ID, even if the Tenant ID is already set.

.EXAMPLE
  # Set the tenant ID to a specific UUID
  PS C:\> Set-HPAnalyticsConsentTenantID -UUID 'd34da70b-9d64-47e3-8b3f-9c561df32b98'

.EXAMPLE
  # Set the tenant ID to an auto-generated UUID
  PS C:\> Set-HPAnalyticsConsentTenantID -NewUUID

.EXAMPLE
  # Remove a configured UUID
  PS C:\> Set-HPAnalyticsConsentTenantID -None

.EXAMPLE
  # Set (and overwrite) an existing UUID with a new one:
  PS C:\> Set-HPAnalyticsConsentTenantID -NewUUID -Force

.LINK
  [Get-HPAnalyticsConsentConfiguration](Get-HPAnalyticsConsentConfiguration)

.LINK
  [Set-HPAnalyticsConsentAllowedPurposes](Set-HPAnalyticsConsentAllowedPurposes)

.LINK
  [Set-HPAnalyticsConsentDeviceOwnership](Set-HPAnalyticsConsentDeviceOwnership)

.LINK
  For a discussion of these settings, see [https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf](https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf) 
#>
function Set-HPAnalyticsConsentTenantID
{
  [CmdletBinding(DefaultParameterSetName = "SpecificUUID",HelpUri = "https://developers.hp.com/hp-client-management/doc/Set%E2%80%90HPAnalyticsConsentTenantID")]
  param(
    [Parameter(ParameterSetName = 'SpecificUUID',Mandatory = $true,Position = 0)]
    [guid]$UUID,
    [Parameter(ParameterSetName = 'NewUUID',Mandatory = $true,Position = 0)]
    [switch]$NewUUID,
    [Parameter(ParameterSetName = 'None',Mandatory = $true,Position = 0)]
    [switch]$None,
    [Parameter(ParameterSetName = 'SpecificUUID',Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = 'NewUUID',Mandatory = $false,Position = 1)]
    [switch]$Force

  )

  if ($NewUUID.IsPresent)
  {
    $uid = [guid]::NewGuid()
  }
  elseif ($None.IsPresent) {
    $uid = "Individual"
  }
  else {
    $uid = $UUID
  }



  if ((-not $Force.IsPresent) -and (-not $None.IsPresent))
  {

    $config = Get-HPAnalyticsConsentConfiguration -Verbose:$VerbosePreference
    if ($config.TenantID -and $config.TenantID -ne "Individual" -and $config.TenantID -ne $uid)
    {

      Write-Verbose "Tenant ID $($config.TenantID) is already configured"
      throw [ArgumentException]"A Tenant ID is already configured for this device. Use -Force to overwrite it."
    }
  }
  New-ItemProperty -Path $ConsentPath -Name "TenantID" -Value $uid -Force | Out-Null
}



<#
.SYNOPSIS
    Set allowed reporting purposes for HP Analytics
 
.DESCRIPTION
    This command configures how HP may use the data reported.

    - *Marketing* - The data may be used for marketing purposes.
    - *Support* - The data may be used for support purposes.
    - *ProductEnhancement* - The data may be used for product enhancement purposes

    Note that you may supply any combination of the above purpose in a single command. Any of the purposes not included
    in the list will be explicitly rejected.


.PARAMETER AllowedPurposes
    A list of allowed purposes for the reported data. This may be one or more of Marketing, Support or ProductEnhancement.

    The purposes included in this list will be explicitly accepted. Those not included in this list will be explicitly rejected.

.PARAMETER None
    Clear (Reject) all purposes


.EXAMPLE
    # Accept all purposes
    PS C:\> Set-HPAnalyticsConsentAllowedPurposes  -AllowedPurposes Marketing,Support,ProductEnhancement

.EXAMPLE
    # Set ProductEnhancement, reject everything else
    PS C:\> Set-HPAnalyticsConsentAllowedPurposes  -AllowedPurposes ProductEnhancement

.EXAMPLE
    # Reject everything
    PS C:\> Set-HPAnalyticsConsentAllowedPurposes  -None
    

.LINK
  [Get-HPAnalyticsConsentConfiguration](Get-HPAnalyticsConsentConfiguration)

.LINK
  [Set-HPAnalyticsConsentTenantID](Set-HPAnalyticsConsentTenantID)

.LINK
  [Set-HPAnalyticsConsentDeviceOwnership](Set-HPAnalyticsConsentDeviceOwnership)

.LINK
  For a discussion of these settings, see [https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf](https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf) 
#>
function Set-HPAnalyticsConsentAllowedPurposes
{
  [CmdletBinding(DefaultParameterSetName = "SpecificPurposes",HelpUri = "https://developers.hp.com/hp-client-management/doc/Set%E2%80%90HPAnalyticsConsentAllowedPurposes")]
  param(
    [Parameter(ParameterSetName = 'SpecificPurposes',Mandatory = $true,Position = 0)]
    [TelemetryPurpose[]]$AllowedPurposes,
    [Parameter(ParameterSetName = 'NoPurpose',Mandatory = $true,Position = 0)]
    [switch]$None
  )

  if ($None.IsPresent)
  {
    Write-Verbose "Clearing all opt-in telemetry purposes"
    New-ItemProperty -Path $ConsentPath -Name "AllowMarketing" -Value "Rejected" -Force | Out-Null
    New-ItemProperty -Path $ConsentPath -Name "AllowSupport" -Value "Rejected" -Force | Out-Null
    New-ItemProperty -Path $ConsentPath -Name "AllowProductEnhancement" -Value "Rejected" -Force | Out-Null

  }
  else {
    $allowed = $AllowedPurposes | ForEach-Object {
      New-ItemProperty -Path $ConsentPath -Name "Allow$_" -Value 'Accepted' -Force | Out-Null
      $_
    }

    if ($allowed -notcontains 'Marketing') {
      New-ItemProperty -Path $ConsentPath -Name "AllowMarketing" -Value "Rejected" -Force | Out-Null
    }
    if ($allowed -notcontains 'Support') {
      New-ItemProperty -Path $ConsentPath -Name "AllowSupport" -Value "Rejected" -Force | Out-Null
    }
    if ($allowed -notcontains 'ProductEnhancement') {
      New-ItemProperty -Path $ConsentPath -Name "AllowProductEnhancement" -Value "Rejected" -Force | Out-Null
    }

  }

}


# SIG # Begin signature block
# MIIaywYJKoZIhvcNAQcCoIIavDCCGrgCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCZJtfbnXa2qbbB
# mq9G79VFe1idUFSsWIAO+qg/aJQDPaCCCm8wggUwMIIEGKADAgECAhAECRgbX9W7
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
# BgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCAySVNKIxym2QUYrgC9WELe/YsVeDVN
# 0x9Xywab4IueuDANBgkqhkiG9w0BAQEFAASCAQCcqswZtHPzepEbds0U4xrEENeb
# qkNZgEHuU0rhegeQslTbCHm0ggvhJJ8UKhAWA3cYtArs4A3A3GgOB6s5qucLn+M2
# DWfDSZs8QcaPVV70/Y4FZVxZPpThETDZd136oQhaXD6cY+1JGPtNRyZqinvvg+BC
# KTjxNE/x4LWn77DYbrCzWg12Qz13inoWgv3fCpt8Hqk4EFP7zDVKjProrzs2ikAF
# BnE0zZcLRFs11FdXE0DNYcUS3HnwYfSnTJmHHVCIi9DYlyAa/h2VM0w5s9mMuVXR
# laETMAZGsxclqZkc9U/T5r1kZofFL0zhpL/bEocoEjx3cl6yfS2PwKP2MLPaoYIN
# fjCCDXoGCisGAQQBgjcDAwExgg1qMIINZgYJKoZIhvcNAQcCoIINVzCCDVMCAQMx
# DzANBglghkgBZQMEAgEFADB4BgsqhkiG9w0BCRABBKBpBGcwZQIBAQYJYIZIAYb9
# bAcBMDEwDQYJYIZIAWUDBAIBBQAEIC1ayGNfFg+X1qyYNYRqZVl7yziBmZ7GIRtu
# /Gt0HY3EAhEA1P9rQ1TP2xcu8kMCP/ryeBgPMjAyMTExMjIxOTE5MDNaoIIKNzCC
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
# m/MwLwYJKoZIhvcNAQkEMSIEICekZ7y9CNld5oXj+QE4V9+WyKwvkXyplpjb0BwT
# 43KbMDcGCyqGSIb3DQEJEAIvMSgwJjAkMCIEILMQkAa8CtmDB5FXKeBEA0Fcg+Mp
# K2FPJpZMjTVx7PWpMA0GCSqGSIb3DQEBAQUABIIBAARUXiNnZKBBLF5i/8jEmWQD
# heaJ0YT2xjIQnPKX7zE77mG9R1oCygPsPxkkZ5M/w3Loq0664/SsUFp1nNaezcxZ
# FO2Gq3TFtZbLjjYMac4AZscXVrQXIg73k5Dvg2sd3ABrAugKszIs8mcoOf5Qcci0
# S3+2ZOUtLMysf+Jhd9HrOSUkozPqdTHMWS2DGhLpTCXW0XfIX//3I6ITm8U/9H0a
# bvgAy7/penw/8LUGvSUwXWduJprDZlXKgBM/I4NT6ovwRR/K6V0lYrp3ExP/H0Gx
# xa4wSdU+V2jEb6DANBMe2HcWGird5My7NH0RKwiNLxWT95ybJQJGQThv1GIm0cI=
# SIG # End signature block
