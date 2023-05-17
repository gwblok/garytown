#
#  Copyright 2018-2021 HP Development Company, L.P.
#  All Rights Reserved.
#
# NOTICE:  All information contained herein is, and remains the property of HP Inc.
#
# The intellectual and technical concepts contained herein are proprietary to HP Inc
# and may be covered by U.S. and Foreign Patents, patents in process, and are protected by
# trade secret or copyright law. Dissemination of this information or reproduction of this material
# is strictly forbidden unless prior written permission is obtained from HP Inc.

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"
#requires -Modules "HP.Private"


<#
.SYNOPSIS
  Get the HP Secure Platform state

.DESCRIPTION
  This function returns the state of the HP Secure Platform.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with secure platform support.
  - This command requires elevated privileges.

.EXAMPLE
  Get-HPSecurePlatformState
#>
function Get-HPSecurePlatformState {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPSecurePlatformState")]
  param()
  $mi_result = 0
  $data = New-Object -TypeName provisioning_data_t
  $c = '[DfmNativeSecurePlatform]::get_secureplatform_provisioning' + (Test-OSBitness) + '([ref]$data,[ref]$mi_result);'
  $result = Invoke-Expression -Command $c
  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x04

  $kek_mod = $data.kek_mod
  [array]::Reverse($kek_mod)

  $sk_mod = $data.sk_mod
  [array]::Reverse($sk_mod)

  # calculating EndorsementKeyID
  $kek_encoded = [System.Convert]::ToBase64String($kek_mod)
  # $kek_decoded = [Convert]::FromBase64String($kek_encoded)
  # $kek_hash = Get-HPPrivateHash -Data $kek_decoded
  # $kek_Id = [System.Convert]::ToBase64String($kek_hash)

  # calculating SigningKeyID
  $sk_encoded = [System.Convert]::ToBase64String($sk_mod)
  # $sk_decoded = [Convert]::FromBase64String($sk_encoded)
  # $sk_hash = Get-HPPrivateHash -Data $sk_decoded
  # $sk_Id = [System.Convert]::ToBase64String($sk_hash)

  # get Sure Admin Mode and Local Access values
  $sure_admin_mode = ""
  $local_access = ""
  if ((Get-HPPrivateIsSureAdminSupported) -eq $true) {
    $sure_admin_state = Get-HPSureAdminState
    $sure_admin_mode = $sure_admin_state.SureAdminMode
    $local_access = $sure_admin_state.LocalAccess
  }

  # calculate FeaturesInUse
  $featuresInUse = ""
  if ($data.features_in_use -eq "SureAdmin") {
    $featuresInUse = "SureAdmin ($sure_admin_mode, Local Access - $local_access)"
  }
  else {
    $featuresInUse = $data.features_in_use
  }

  $obj = [ordered]@{
    State = $data.State
    Version = "$($data.subsystem_version[0]).$($data.subsystem_version[1])"
    Nonce = $($data.arp_counter)
    FeaturesInUse = $featuresInUse
    EndorsementKeyMod = $kek_mod
    SigningKeyMod = $sk_mod
    EndorsementKeyID = $kek_encoded
    SigningKeyID = $sk_encoded
  }
  return New-Object -TypeName PSCustomObject -Property $obj
}


<#
.SYNOPSIS
    Create an HP Secure Platform payload to provision a _Key Endorsement_ key.

.DESCRIPTION
  The purpose of the endorsement key is to protect the signing key against unauthorized changes.
  Only holders of the key endorsement private key may change the signing key.

  On return, the function writes the created payload to the pipeline, or to the file specified in the OutputFile parameter.
  This payload can then be passed to the Set-HPSecurePlatformPayload function.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload. Creating the payload and passing it to the Set-HPSecurePlatformPayload function via the pipeline is not a recommended production pattern.

.PARAMETER EndorsementKeyFile
  The _Key Endorsement_ key certificate, as a PFX (PKCS #12) file.

.PARAMETER EndorsementKeyPassword
  The password for the _Endorsement Key_ PFX file. If no password was used when the PFX was created (which is not recommended), this parameter may be omitted.

.PARAMETER EndorsementKeyCertificate
  This parameter is currently reserved for internal use only.

.PARAMETER EndorsementKeyCertificatePassword
  This parameter is currently reserved for internal use only.

.PARAMETER BIOSPassword
  The active BIOS Setup password, if any. Note that the password will be in the clear in the generated payload.

.PARAMETER OutputFile
     Write the resulting output to the specified file, instead of writing it to the pipeline.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.NOTES
  The Key Endorsement private key must never leave a secure server. The payload must be created on a secure server, then may be transferred to a client.

  - Requires HP BIOS with secure platform support.

.EXAMPLE
   $payload = New-HPSecurePlatformEndorsementKeyProvisioningPayload -EndorsementKeyFile "$path\endorsement_key.pfx"
   ...
   $payload | Set-HPSecurePlatformPayload

#>
function New-HPSecurePlatformEndorsementKeyProvisioningPayload {
  [CmdletBinding(DefaultParameterSetName = "EK_FromFile",HelpUri = "https://developers.hp.com/hp-client-management/doc/New%E2%80%90HPSecurePlatformEndorsementKeyProvisioningPayload")]
  param(
    [Parameter(ParameterSetName = "EK_FromFile",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$EndorsementKeyFile,

    [Parameter(ParameterSetName = "EK_FromFile",Mandatory = $false,Position = 1)]
    [string]$EndorsementKeyPassword,

    [Parameter(ParameterSetName = "EK_FromBytes",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$EndorsementKeyCertificate,

    [Parameter(ParameterSetName = "EK_FromFile",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "EK_FromBytes",Mandatory = $false,Position = 2)]
    [string]$BIOSPassword,

    [Parameter(ParameterSetName = "EK_FromFile",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "EK_FromBytes",Mandatory = $false,Position = 3)]
    [System.IO.FileInfo]$OutputFile
  )

  $crt = (Get-HPPrivateX509CertCoalesce -File $EndorsementKeyFile -cert $EndorsementKeyCertificate -password $EndorsementKeyPassword -Verbose:$VerbosePreference).Certificate
  Write-Verbose "Creating EK provisioning payload"

  if ($BIOSPassword) {
    $passwordLength = $BIOSPassword.Length
  }
  else {
    $passwordLength = 0
  }

  $opaque = New-Object opaque4096_t
  $opaqueLength = 4096
  $mi_result = 0
  $cmd = '[DfmNativeSecurePlatform]::get_ek_provisioning_data' + (Test-OSBitness) + '($crt,$($crt.Count),$BIOSPassword, $passwordLength, [ref]$opaque, [ref]$opaqueLength,  [ref]$mi_result);'
  $result = Invoke-Expression -Command $cmd
  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x04

  $output = New-Object -TypeName PortableFileFormat
  $output.Data = $opaque.raw[0..($opaqueLength - 1)]
  $output.purpose = "hp:provision:endorsementkey"
  $output.timestamp = Get-Date

  if ($OutputFile) {
    Write-Verbose 'Will output to file $OutputFile'
    $f = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
    $output | ConvertTo-Json -Compress | Out-File $f -Encoding utf8
  }
  else {
    $output | ConvertTo-Json -Compress
  }
}


<#
.SYNOPSIS
    Create an HP Secure Platform payload to provision a _Signing Key_ key.

.DESCRIPTION
  The purpose of the signing key is to sign commands for the secure platform. The Signing key is protected
  by the endorsement key, therefore the endorsement key private key must be available when provisioning or
  changing the signing key.

  On return, the function writes the created payload to the pipeline, or to the file specified in the OutputFile parameter.
  This payload can then be passed to the Set-HPSecurePlatformPayload function.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload. Creating the payload and passing it to the Set-HPSecurePlatformPayload function via the pipeline is not a recommended production pattern.

.PARAMETER EndorsementKeyFile
  The _Key Endorsement_ key certificate, as a PFX (PKCS #12) file. The endorsement key protects the signing key.

.PARAMETER EndorsementKeyPassword
  The password for the _Endorsement Key_ PFX file. If no password was used when the PFX was created (which is not recommended), this parameter may be omitted.

.PARAMETER EndorsementKeyCertificate
  The endorsement key certificate, as an X509Certificate object.

.PARAMETER SigningKeyFile
  The signing key certificate, as a PFX (PKCS #12) file. The endorsement key protects the signing key.

.PARAMETER SigningKeyCertificate
  The signing key certificate, as an X509Certificate object.

.PARAMETER SigningKeyCertificate
  This parameter is currently reserved for internal use only.

.PARAMETER SigningKeyPassword
  The signing key certificate, as an X509Certificate object.

.PARAMETER Nonce
  The operation nonce. In order to prevent replay attacks, the secure platform subsystem will only accept commands with a nonce greater or equal to the last nonce sent.
  If not specified, the nonce is inferred from the current local time. This works okay in most cases, however this approach has a resolution of seconds, so when doing high volume or parallel operations, it is possible to infer the same counter for two or more commands. In those cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER OutputFile
     Write the resulting output to the specified file, instead of writing it to the pipeline.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with secure platform support.

.EXAMPLE
  $payload = New-HPSecurePlatformSigningKeyProvisioningPayload -EndorsementKeyFile "$path\endorsement_key.pfx"  `
               -SigningKeyFile "$path\signing_key.pfx"
  ...
  $payload | Set-HPSecurePlatformPayload

#>
function New-HPSecurePlatformSigningKeyProvisioningPayload {
  [CmdletBinding(DefaultParameterSetName = "EF_SF",HelpUri = "https://developers.hp.com/hp-client-management/doc/New%E2%80%90HPSecurePlatformSigningKeyProvisioningPayload")]
  param(
    [Parameter(ParameterSetName = "EF_SF",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "EF_SB",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$EndorsementKeyFile,

    [Parameter(ParameterSetName = "EF_SF",Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = "EF_SB",Mandatory = $false,Position = 1)]
    [string]$EndorsementKeyPassword,

    [Parameter(ParameterSetName = "EF_SF",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "EB_SF",Mandatory = $false,Position = 2)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ParameterSetName = "EF_SF",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "EB_SF",Mandatory = $false,Position = 3)]
    [string]$SigningKeyPassword,

    [Parameter(ParameterSetName = "EB_SF",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "EB_SB",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$EndorsementKeyCertificate,

    [Parameter(ValueFromPipeline = $true,ParameterSetName = "EB_SB",Mandatory = $false,Position = 2)]
    [Parameter(ValueFromPipeline = $true,ParameterSetName = "EF_SB",Mandatory = $false,Position = 2)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "EF_SF",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "EB_SF",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "EF_SB",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "EB_SB",Mandatory = $false,Position = 4)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "EF_SF",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "EB_SF",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "EF_SB",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "EB_SB",Mandatory = $false,Position = 5)]
    [System.IO.FileInfo]$OutputFile
  )

  $ek = Get-HPPrivateX509CertCoalesce -File $EndorsementKeyFile -password $EndorsementKeyPassword -cert $EndorsementKeyCertificate -Verbose:$VerbosePreference

  $sk = $null

  if ($SigningKeyFile -or $SigningKeyCertificate) {
    $sk = Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeyCertificate -Verbose:$VerbosePreference
  }

  Write-Verbose "Creating SK provisioning payload"

  $payload = New-Object sk_provisioning_t
  $sub = New-Object sk_provisioning_payload_t

  $sub.Counter = $nonce
  if ($sk) {
    $sub.mod = $Sk.Modulus
  }
  else {
    Write-Verbose "Assuming deprovisioning due to missing signing key update"
    $sub.mod = New-Object byte[] 256
  }
  $payload.Data = $sub
  Write-Verbose "Using counter value of $($sub.Counter)"
  $out = Convert-HPPrivateObjectToBytes -obj $sub -Verbose:$VerbosePreference
  $payload.sig = Invoke-HPPrivateSignData -Data $out[0] -Certificate $ek.Full -Verbose:$VerbosePreference


  Write-Verbose "Serializing payload"
  $out = Convert-HPPrivateObjectToBytes -obj $payload -Verbose:$VerbosePreference

  $output = New-Object -TypeName PortableFileFormat
  $output.Data = ($out[0])[0..($out[1] - 1)];
  $output.purpose = "hp:provision:signingkey"
  $output.timestamp = Get-Date

  if ($OutputFile) {
    Write-Verbose 'Will output to file $OutputFile'
    $f = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
    $output | ConvertTo-Json -Compress | Out-File -FilePath $f -Encoding utf8
  }
  else {
    $output | ConvertTo-Json -Compress
  }
}



<#
.SYNOPSIS
    Create a deprovisioning payload

.DESCRIPTION
  This function creates a payload to deprovision the HP Secure Platform. The caller must have access to the  Endorsement Key private key in order
  to create this payload.

  On return, the function writes the created payload to the pipeline, or to the file specified in the OutputFile parameter.
  This payload can then be passed to the Set-HPSecurePlatformPayload function.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload. Creating the payload and passing it to the Set-HPSecurePlatformPayload function via the pipeline is not a recommended production pattern.

.PARAMETER EndorsementKeyFile
    The _Key Endorsement_ key certificate, as a PFX (PKCS #12) file.

.PARAMETER EndorsementKeyPassword
  The password for the endorsement key certificate file. If no password was used when the PFX was created (which is not recommended), this parameter may be omitted.

.PARAMETER EndorsementKeyCertificate
  The endorsement key certificate, as an X509Certificate object.

.PARAMETER Nonce
  The operation nonce. In order to prevent replay attacks, the secure platform subsystem will only accept commands with a nonce greater or equal to the last nonce sent.
  If not specified, the nonce is inferred from the current local time. This works okay in most cases, however this approach has a resolution of seconds, so when doing high volume or parallel operations, it is possible to infer the same counter for two or more commands. In those cases, the caller should use its own nonce derivation and provide it through this parameter.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.PARAMETER OutputFile
   Write the resulting output to the specified file, instead of writing it to the pipeline.

.NOTES
  - Requires HP BIOS with secure platform support.

.EXAMPLE
  New-HPSecurePlatformDeprovisioningPayload -EndorsementKeyFile kek.pfx | Set-HPSecurePlatformPayload

.EXAMPLE
  New-HPSecurePlatformDeprovisioningPayload -EndorsementKeyFile kek.pfx -OutputFile deprovisioning_payload.dat
#>
function New-HPSecurePlatformDeprovisioningPayload {
  [CmdletBinding(DefaultParameterSetName = "EF",HelpUri = "https://developers.hp.com/hp-client-management/doc/New%E2%80%90HPSecurePlatformDeprovisioningPayload")]
  param(
    [Parameter(ParameterSetName = "EF",Mandatory = $true,Position = 0)]
    [string]$EndorsementKeyFile,

    [Parameter(ParameterSetName = "EF",Mandatory = $false,Position = 1)]
    [string]$EndorsementKeyPassword,

    [Parameter(ParameterSetName = "EF",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "EB",Mandatory = $false,Position = 2)]
    [uint32]$nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "EB",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$EndorsementKeyCertificate,

    [Parameter(ParameterSetName = "EB",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "EF",Mandatory = $false,Position = 4)]
    [System.IO.FileInfo]$OutputFile
  )
  New-HPSecurePlatformSigningKeyProvisioningPayload @PSBoundParameters
}

<#
.SYNOPSIS
  Apply a payload to the HP Secure Platform

.DESCRIPTION
  This function applies a properly encoded payload created by one of the New-HPSecurePlatform*, New-HPSureRun*, New-HPSureAdmin*, or New-HPSureRecover* functions to the BIOS.

  For all purposes, payload objects should be considered to be opaque. Payloads created by means other than the functions mentioned above are not supported.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload. Creating the payload and passing it to the Set-HPSecurePlatformPayload function via the pipeline is not a recommended production pattern.

.PARAMETER Payload
  The payload to apply. This parameter can also be specified via the pipeline.

.PARAMETER PayloadFile
  The payload file to apply. This file must contain a properly encoded payload.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with secure platform support.
  - This command requires elevated privileges.

.EXAMPLE
  Set-HPSecurePlatformPayload -Payload $payload

.EXAMPLE
  Set-HPSecurePlatformPayload -PayloadFile .\payload.dat

.EXAMPLE
  $payload | Set-HPSecurePlatformPayload
#>
function Set-HPSecurePlatformPayload {

  [CmdletBinding(DefaultParameterSetName = "FB",HelpUri = "https://developers.hp.com/hp-client-management/doc/Set%E2%80%90HPSecurePlatformPayload")]
  param(
    [Parameter(ParameterSetName = "FB",ValueFromPipeline = $true,Position = 0,Mandatory = $True)] [string]$Payload,
    [Parameter(ParameterSetName = "FF",ValueFromPipeline = $true,Position = 0,Mandatory = $True)] [System.IO.FileInfo]$PayloadFile
  )

  if ($PSCmdlet.ParameterSetName -eq "FB") {
    Write-Verbose "Setting payload string"
    [PortableFileFormat]$type = ConvertFrom-Json -InputObject $Payload
  }
  else {
    Write-Verbose "Setting from file $PayloadFile"
    $Payload = Get-Content -Path $PayloadFile -Encoding UTF8
    [PortableFileFormat]$type = ConvertFrom-Json -InputObject $Payload
  }

  $mi_result = 0
  $pbytes = $type.Data
  Write-Verbose "Setting payload from document with type $($type.purpose)"

  $cmd = $null
  switch ($type.purpose) {
    "hp:provision:endorsementkey" {
      $cmd = '[DfmNativeSecurePlatform]::set_ek_provisioning' + (Test-OSBitness) + '($pbytes,$pbytes.length, [ref]$mi_result);'
    }
    "hp:provision:signingkey" {
      $cmd = '[DfmNativeSecurePlatform]::set_sk_provisioning' + (Test-OSBitness) + '($pbytes,$pbytes.length, [ref]$mi_result);'
    }
    "hp:surerecover:provision:os_image" {
      $cmd = '[DfmNativeSureRecover]::set_surerecover_osr_provisioning' + (Test-OSBitness) + '($pbytes,$pbytes.length, [ref]$mi_result);'
    }
    "hp:surerecover:provision:recovery_image" {
      $cmd = '[DfmNativeSureRecover]::set_surerecover_re_provisioning' + (Test-OSBitness) + '($pbytes,$pbytes.length, [ref]$mi_result);'
    }
    "hp:surerecover:deprovision" {
      $cmd = '[DfmNativeSureRecover]::set_surerecover_deprovision_opaque' + (Test-OSBitness) + '($pbytes,$pbytes.length, [ref]$mi_result);'
    }
    "hp:surerecover:scheduler" {
      $cmd = '[DfmNativeSureRecover]::set_surerecover_schedule' + (Test-OSBitness) + '($pbytes,$pbytes.length, [ref]$mi_result);'
    }
    "hp:surerecover:configure" {
      $cmd = '[DfmNativeSureRecover]::set_surerecover_configuration' + (Test-OSBitness) + '($pbytes,$pbytes.length, [ref]$mi_result);'
    }
    "hp:surerecover:trigger" {
      $cmd = '[DfmNativeSureRecover]::set_surerecover_trigger' + (Test-OSBitness) + '($pbytes,$pbytes.length, [ref]$mi_result);'
    }
    "hp:surerecover:service_event" {
      $cmd = '[DfmNativeSureRecover]::raise_surerecover_service_event_opaque' + (Test-OSBitness) + '($null,0, [ref]$mi_result);'
    }
    "hp:surerrun:manifest" {
      $mbytes = $type.Meta1
      $cmd = '[DfmNativeSureRun]::set_surererun_manifest' + (Test-OSBitness) + '($pbytes,$pbytes.length, $mbytes, $mbytes.length, [ref]$mi_result);'
    }
    "hp:sureadmin:biossetting" {
      $Payload | Set-HPPrivateBIOSSettingValuePayload -Verbose:$VerbosePreference
    }
    "hp:sureadmin:biossettingslist" {
      $Payload | Set-HPPrivateBIOSSettingsListPayload -Verbose:$VerbosePreference
    }
    "hp:sureadmin:resetsettings" {
      $Payload | Set-HPPrivateBIOSSettingDefaultsPayload -Verbose:$VerbosePreference
    }
    "hp:sureadmin:firmwareupdate" {
      $Payload | Set-HPPrivateFirmwareUpdatePayload -Verbose:$VerbosePreference
    }
    default {
      throw [System.IO.InvalidDataException]"Document type $($type.purpose) not recognized"
    }
  }
  if ($cmd) {
    $result = Invoke-Expression -Command $cmd
    Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x04
  }
}

# SIG # Begin signature block
# MIIaygYJKoZIhvcNAQcCoIIauzCCGrcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBfp8uIIjI8VBCH
# kOdilwitm+BGxffxoeCXM5tpmuO2saCCCm8wggUwMIIEGKADAgECAhAECRgbX9W7
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
# X6KaoyX0Z93PMYIPsTCCD60CAQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoT
# DERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UE
# AxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQQIQBVIt
# 1AAIAhnrJTsLVYOdlzANBglghkgBZQMEAgEFAKB8MBAGCisGAQQBgjcCAQwxAjAA
# MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
# BgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCCWNf5LlC7R9jq2nz1NJuc8bEarEmdX
# kYzy2axazDYVqDANBgkqhkiG9w0BAQEFAASCAQBoTyqq7KvItneTGExR4IVQanUU
# cVo6C34YKxgO4d6nTXjxpl2UXvH+ZMrpQ0VB1C43tI5lPahfETFCRIIAh7jIDLEn
# ZzOb5LJJKjB2ZCOkHmKHekUnTxGB26IUkie7BZIBuiwkPwpRKzRwuUTCf7bMzPJh
# 4zJtsm7XmbNtpByUtso+uk5eZFlI9SL/z6/cGkAju8wf/brIxZXrAW2cgZobJPXc
# p3GdVmR+h2K/38r1NVrmuuPwTbsHbneMw820cQa95dr1lDbDTmmB/S6oqwQNP6u8
# r1AoW+Us5sQsZ4HwiOLTTFmVOCM6tQKWe/S8NN+usj/QzVlBdQuwjp3bimd7oYIN
# fTCCDXkGCisGAQQBgjcDAwExgg1pMIINZQYJKoZIhvcNAQcCoIINVjCCDVICAQMx
# DzANBglghkgBZQMEAgEFADB3BgsqhkiG9w0BCRABBKBoBGYwZAIBAQYJYIZIAYb9
# bAcBMDEwDQYJYIZIAWUDBAIBBQAEIP7Tn29SeyH8pwEFsttrsRAIA5yti6liaqND
# SVqKPFQPAhA2MRW8Aqmhu78AqMUIfsYYGA8yMDIxMTEyMjE5MTkwM1qgggo3MIIE
# /jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG9w0BAQsFADByMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQg
# VGltZXN0YW1waW5nIENBMB4XDTIxMDEwMTAwMDAwMFoXDTMxMDEwNjAwMDAwMFow
# SDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMSAwHgYDVQQD
# ExdEaWdpQ2VydCBUaW1lc3RhbXAgMjAyMTCCASIwDQYJKoZIhvcNAQEBBQADggEP
# ADCCAQoCggEBAMLmYYRnxYr1DQikRcpja1HXOhFCvQp1dU2UtAxQtSYQ/h3Ib5Fr
# DJbnGlxI70Tlv5thzRWRYlq4/2cLnGP9NmqB+in43Stwhd4CGPN4bbx9+cdtCT2+
# anaH6Yq9+IRdHnbJ5MZ2djpT0dHTWjaPxqPhLxs6t2HWc+xObTOKfF1FLUuxUOZB
# OjdWhtyTI433UCXoZObd048vV7WHIOsOjizVI9r0TXhG4wODMSlKXAwxikqMiMX3
# MFr5FK8VX2xDSQn9JiNT9o1j6BqrW7EdMMKbaYK02/xWVLwfoYervnpbCiAvSwnJ
# laeNsvrWY4tOpXIc7p96AXP4Gdb+DUmEvQECAwEAAaOCAbgwggG0MA4GA1UdDwEB
# /wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEEG
# A1UdIAQ6MDgwNgYJYIZIAYb9bAcBMCkwJwYIKwYBBQUHAgEWG2h0dHA6Ly93d3cu
# ZGlnaWNlcnQuY29tL0NQUzAfBgNVHSMEGDAWgBT0tuEgHf4prtLkYaWyoiWyyBc1
# bjAdBgNVHQ4EFgQUNkSGjqS6sGa+vCgtHUQ23eNqerwwcQYDVR0fBGowaDAyoDCg
# LoYsaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC10cy5jcmww
# MqAwoC6GLGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtdHMu
# Y3JsMIGFBggrBgEFBQcBAQR5MHcwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBPBggrBgEFBQcwAoZDaHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0U0hBMkFzc3VyZWRJRFRpbWVzdGFtcGluZ0NBLmNydDANBgkq
# hkiG9w0BAQsFAAOCAQEASBzctemaI7znGucgDo5nRv1CclF0CiNHo6uS0iXEcFm+
# FKDlJ4GlTRQVGQd58NEEw4bZO73+RAJmTe1ppA/2uHDPYuj1UUp4eTZ6J7fz51Kf
# k6ftQ55757TdQSKJ+4eiRgNO/PT+t2R3Y18jUmmDgvoaU+2QzI2hF3MN9PNlOXBL
# 85zWenvaDLw9MtAby/Vh/HUIAHa8gQ74wOFcz8QRcucbZEnYIpp1FUL1LTI4gdr0
# YKK6tFL7XOBhJCVPst/JKahzQ1HavWPWH1ub9y4bTxMd90oNcX6Xt/Q/hOvB46NJ
# ofrOp79Wz7pZdmGJX36ntI5nePk2mOHLKNpbh6aKLzCCBTEwggQZoAMCAQICEAqh
# JdbWMht+QeQF2jaXwhUwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEk
# MCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTE2MDEwNzEy
# MDAwMFoXDTMxMDEwNzEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERp
# Z2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMo
# RGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIFRpbWVzdGFtcGluZyBDQTCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBAL3QMu5LzY9/3am6gpnFOVQoV7YjSsQO
# B0UzURB90Pl9TWh+57ag9I2ziOSXv2MhkJi/E7xX08PhfgjWahQAOPcuHjvuzKb2
# Mln+X2U/4Jvr40ZHBhpVfgsnfsCi9aDg3iI/Dv9+lfvzo7oiPhisEeTwmQNtO4V8
# CdPuXciaC1TjqAlxa+DPIhAPdc9xck4Krd9AOly3UeGheRTGTSQjMF287Dxgaqwv
# B8z98OpH2YhQXv1mblZhJymJhFHmgudGUP2UKiyn5HU+upgPhH+fMRTWrdXyZMt7
# HgXQhBlyF/EXBu89zdZN7wZC/aJTKk+FHcQdPK/P2qwQ9d2srOlW/5MCAwEAAaOC
# Ac4wggHKMB0GA1UdDgQWBBT0tuEgHf4prtLkYaWyoiWyyBc1bjAfBgNVHSMEGDAW
# gBRF66Kv9JLLgjEtUYunpyGd823IDzASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1Ud
# DwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB5BggrBgEFBQcBAQRtMGsw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcw
# AoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBQ
# BgNVHSAESTBHMDgGCmCGSAGG/WwAAgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93
# d3cuZGlnaWNlcnQuY29tL0NQUzALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQAD
# ggEBAHGVEulRh1Zpze/d2nyqY3qzeM8GN0CE70uEv8rPAwL9xafDDiBCLK938ysf
# DCFaKrcFNB1qrpn4J6JmvwmqYN92pDqTD/iy0dh8GWLoXoIlHsS6HHssIeLWWywU
# NUMEaLLbdQLgcseY1jxk5R9IEBhfiThhTWJGJIdjjJFSLK8pieV4H9YLFKWA1xJH
# cLN11ZOFk362kmf7U2GJqPVrlsD0WGkNfMgBsbkodbeZY4UijGHKeZR+WfyMD+Nv
# tQEmtmyl7odRIeRYYJu6DC0rbaLEfrvEJStHAgh8Sa4TtuF8QkIoxhhWz0E0tmZd
# tnR79VYzIi8iNrJLokqV2PWmjlIxggKGMIICggIBATCBhjByMQswCQYDVQQGEwJV
# UzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
# Y29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgVGltZXN0YW1w
# aW5nIENBAhANQkrgvjqI/2BAIc4UAPDdMA0GCWCGSAFlAwQCAQUAoIHRMBoGCSqG
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjExMTIyMTkx
# OTAzWjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTh14Ko4ZG+72vKFpG1qrSUpiSb
# 8zAvBgkqhkiG9w0BCQQxIgQgVVIr8LrZDIvN6bc1g+HD/SIg37oYmxrcUunA8yuX
# GdMwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgsxCQBrwK2YMHkVcp4EQDQVyD4ykr
# YU8mlkyNNXHs9akwDQYJKoZIhvcNAQEBBQAEggEAY0mbY3q6r3qoRFhE8pud8fai
# 5aIdbVLBX1zqvw1nTzsK9/ys08aweEyMSKr8JRakr99f4EgB6x2GfDe3MR5qKhU4
# hA+EFt1U66gMbOU8IcyURoyeB5jAXgyROfu14hVP2CHN0rjyvxM2ESWnRKQUTCgI
# otIC6x6QEqSLpHucO+/woPv0aHvXz52q/kae9Oww3jHCWVvnfIc8wg6qZ4ffZdbJ
# L84HwoL2QlGASQvCE5S+bUcdvmcMeZDu802kXCP486AelH9APuauQnybHDl/ZIui
# q2DWEhlw7WDJgxXpCuJni6lrWRkO4TIf5cCrtx+I7ttGv6NdJStxKmMch4XqyA==
# SIG # End signature block
