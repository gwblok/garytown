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

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
#requires -Modules "HP.Private"
#requires -Modules "HP.ClientManagement"

$MSALReferencedAssemblies = New-Object Collections.Generic.List[string]
$MSALReferencedAssemblies.Add('System.Runtime')
$MSALReferencedAssemblies.Add('System.IO.FileSystem')
$MSALReferencedAssemblies.Add('System.Security')
if ($PSEdition -eq "Core") {
  $MSALReferencedAssemblies.Add("$PSScriptRoot\MSAL_4.36.2\netcoreapp2.1\Microsoft.Identity.Client.dll")
  $MSALReferencedAssemblies.Add('netstandard')
  $MSALReferencedAssemblies.Add('System.Security.Cryptography.ProtectedData')
  $MSALReferencedAssemblies.Add('System.Threading')
}
else {
  $MSALReferencedAssemblies.Add("$PSScriptRoot\MSAL_4.36.2\net45\Microsoft.Identity.Client.dll")
}

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
using Microsoft.Identity.Client;

public static class TokenCacheHelper
{
  public static void EnableSerialization(ITokenCache tokenCache)
  {
    tokenCache.SetBeforeAccess(BeforeAccessNotification);
    tokenCache.SetAfterAccess(AfterAccessNotification);
  }
  public static readonly string CacheFilePath = Path.GetTempPath() + "hp/msalcache.dat";
  private static readonly object FileLock = new object();
  private static void BeforeAccessNotification(TokenCacheNotificationArgs args)
  {
    lock (FileLock)
    {
      args.TokenCache.DeserializeMsalV3(File.Exists(CacheFilePath) ? System.Security.Cryptography.ProtectedData.Unprotect(File.ReadAllBytes(CacheFilePath), null, DataProtectionScope.CurrentUser) : null);
    }
  }

  private static void AfterAccessNotification(TokenCacheNotificationArgs args)
  {
    if (args.HasStateChanged)
    {
      lock (FileLock)
      {
        Directory.CreateDirectory(Path.GetDirectoryName(CacheFilePath));
        File.WriteAllBytes(CacheFilePath, System.Security.Cryptography.ProtectedData.Protect(args.TokenCache.SerializeMsalV3(), null, DataProtectionScope.CurrentUser));
      }
    }
  }
}
'@ -ReferencedAssemblies $MSALReferencedAssemblies -WarningAction Ignore -IgnoreWarnings

<#
.SYNOPSIS
  Get the current state of the HP Sure Admin feature

.DESCRIPTION
  This function returns the current state of the HP Sure Admin feature

.NOTES
  - Requires HP P21 enabled.
  - Requires HP BIOS with HP Sure Admin support.
  - This command requires elevated privileges.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.EXAMPLE
  Get-HPSureAdminState
#>
function Get-HPSureAdminState
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/get%e2%80%90hpsureadminstate")]
  param()

  $mode = "Disable"
  $sk = ""
  $signingKeyID = ""
  $ver = ""
  $lak1 = ""
  $sarc = 0
  $aarc = 0
  $local_access = ""
  $lak1_keyID = ""
  $lak1_key_enrollment_data = ""

  if ((Get-HPPrivateIsSureAdminSupported) -eq $true) {
    try { $mode = Get-HPBIOSSettingValue -Name "Enhanced BIOS Authentication Mode" } catch {}
    try { $sk = Get-HPBIOSSettingValue -Name "Secure Platform Management Signing Key" } catch {}
    try { $ver = Get-HPBIOSSettingValue -Name "Enhanced BIOS Authentication Mode Version" } catch {}
    try { $lak1 = Get-HPBIOSSettingValue -Name "Enhanced BIOS Authentication Mode Local Access Key 1" } catch {}
    try { $sarc = Get-HPBIOSSettingValue -Name "Enhanced BIOS Authentication Mode Settings Anti-Replay Counter" } catch {}
    try { $aarc = Get-HPBIOSSettingValue -Name "Enhanced BIOS Authentication Mode Actions Anti-Replay Counter" } catch {}

    #modify signingKeyID
    if ($sk) {
      #decode the base64 encoded string
      $sk_decoded = [Convert]::FromBase64String($sk)
      # hash the decoded string
      $sk_hash = Get-HPPrivateHash -Data $sk_decoded
      #encode the hashed value
      $signingKeyID = [System.Convert]::ToBase64String($sk_hash)
    }

    #calculate local access, lak1_keyID and lak1_key_enrollment_data values from lak1
    if ((-not $lak1) -and ((Get-HPBIOSSetupPasswordIsSet) -eq $true) -and ($mode -eq "Enable")) {
      $local_access = "BIOS Password Protection only"
      $lak1_keyID = "Not Configured"
    }
    elseif ((-not $lak1) -and ((Get-HPBIOSSetupPasswordIsSet) -eq $false) -and ($mode -eq "Enable")) {
      $local_access = "Not Protected"
      $lak1_keyID = "Not Configured"
    }
    elseif ($lak1 -and ($mode -eq "Enable")) {
      $local_access = "Configured"

      try {
        $lak1_length = $lak1.Length
        $lak1_substring = $lak1.substring(0,344)

        #decode the base64 encoded string
        $lak1_decoded = [Convert]::FromBase64String($lak1_substring)
        # hash the decoded string
        $lak1_hash = Get-HPPrivateHash -Data $lak1_decoded
        #encode the hashed value
        $lak1_keyID = [System.Convert]::ToBase64String($lak1_hash)

        if ($lak1_length -gt 344) {
          $pos = $lak1.IndexOf("==")
          $ked_substring = $lak1.substring($pos + 2)
          if ($ked_substring) {
            $lak1_key_enrollment_data = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($ked_substring))
          }
        }
      }
      catch {
        $lak1_keyID = ""
        $lak1_key_enrollment_data = ""
      }
    }
    else {
      $local_access = ""
      $lak1_keyID = ""
      $lak1_key_enrollment_data = ""
    }

    $result = [ordered]@{
      SureAdminMode = if ($mode -eq "Enable") { "On" } else { "Off" }
      SigningKeyID = $signingKeyID
      EnhancedAuthenticationVersion = $ver
      SettingsCounter = $sarc
      ActionsCounter = $aarc
      LocalAccess = $local_access
      LocalAccessKey1 = $lak1
      LAK1_KeyID = $lak1_keyID
      LAK1_KeyEnrollmentData = $lak1_key_enrollment_data
    }

    New-Object -TypeName PSObject -Property $result
  }
}

function Get-HPSecurePlatformIsProvisioned
{
  [boolean]$status = $false

  try {
    $c = 'Get-HPSecurePlatformState'
    $result = Invoke-Expression -Command $c

    if ($result.State -eq "Provisioned") {
      $status = $true
    }
  }
  catch {}

  return $status
}

<#
.SYNOPSIS
  Generate a payload for authorizing a firmware update

.DESCRIPTION
  This function uses the provided key to sign and authorize a firmware update only to the specified file.

  On return, the function writes the created payload to the pipeline, or to the file specified in the OutputFile parameter.
  This payload can then be passed to the Update-HPFirmware function.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Update-HPFirmware.

.PARAMETER File
  The firmware update binary (.BIN) file.

.PARAMETER SigningKeyFile
  The path to the secure platform signing key, as a PFX file. If the PFX file is protected by a password (recommended),
  the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  The secure platform signing key file password, if required.

.PARAMETER SigningKeyCertificate
  The secure platform signing key certificate, as an X509Certificate object.

.PARAMETER Nonce
  The operation nonce. In order to prevent replay attacks, the secure platform subsystem will only accept commands with a nonce greater or equal to the last nonce sent.
  If not specified, the nonce is inferred from the current local time. This works okay in most cases, however this approach has a resolution of seconds, so when doing high volume or parallel operations, it is possible to infer the same counter for two or more commands. In those cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER TargetUUID
  The computer UUID on which to perform this operation. If not specified the payload generated will work on any computer.

.PARAMETER SingleUse
  If specified, the payload cannot be replayed. This happens because the nonce must be higher than ActionsCounter and this counter is updated and incremented every time a command generated with SingleUse flag is accepted by the BIOS.
  If not specified, the payload can be replayed as many times as desired until a payload generated with a nonce higher than
  SettingsCounter is received. This happens because SettingsCounter is not incremented by the BIOS when accepting commands.

.PARAMETER OutputFile
  Write the resulting output to the specified file, instead of writing it to the pipeline.

.PARAMETER Quiet
  Suppress non-essential messages

.PARAMETER Bitlocker
  Provide an answer to the Bitlocker check prompt (if any). The value may be one of:
   stop - stop if Bitlocker is detected but not suspended, and prompt.
   stop is default when Bitlocker switch is provided.
   ignore - skip the Bitlocker check
   suspend - suspend Bitlocker if active, and continue

.PARAMETER Force
  Force the BIOS update, even if the target BIOS is already installed.

.PARAMETER RemoteSigningServiceKeyID
  The Signing Key ID to be used.

.PARAMETER RemoteSigningServiceURL
  The KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/).

.PARAMETER CacheAccessToken
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server, if not cached user have to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and user's credentials won't be asked again until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - An HP BIOS with HP Sure Admin support is required for applying the payloads generated by this function.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.EXAMPLE
  New-HPSureAdminFirmwareUpdatePayload -File bios.bin -SigningKeyFile "$path\signing_key.pfx" -SigningKeyPassword "s3cr3t" -OutputFile PayloadFile.dat
  Update-HPFirmware -File bios.bin -PayloadFile PayloadFile.dat
#>
function New-HPSureAdminFirmwareUpdatePayload {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/new%e2%80%90hpsureadminfirmwareupdatepayload")]
  param(
    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$File,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $true,Position = 2)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 3)]
    [string]$SigningKeyPassword,

    [Parameter(ValueFromPipeline = $true,ParameterSetName = "SigningKeyCert",Mandatory = $true,Position = 2)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [guid]$TargetUUID = 'ffffffff-ffff-ffff-ffff-ffffffffffff',

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 3)]
    [switch]$SingleUse,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 4)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 5)]
    [switch]$Quiet,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 6)]
    [ValidateSet('stop','ignore','suspend')]
    [string]$Bitlocker = 'stop',

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 7)]
    [switch]$Force,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 8)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 9)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 10)]
    [switch]$CacheAccessToken
  )

  $params = @{
    file = $File
    SingleUse = $SingleUse
    Nonce = $Nonce
    TargetUUID = $TargetUUID
  }

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    $params.RemoteSigningServiceKeyID = $RemoteSigningServiceKeyID
    $params.RemoteSigningServiceURL = $RemoteSigningServiceURL
    $params.CacheAccessToken = $CacheAccessToken
  }
  else {
    $params.SigningKey = (Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeycertificate -Verbose:$VerbosePreference).Full
  }

  [byte[]]$authorization = New-HPPrivateSureAdminFirmwareUpdateAuthorization @params
  $data = @{
    Authorization = $authorization
    FileName = $File.Name
    Quiet = $Quiet.IsPresent
    bitlocker = $Bitlocker
    Force = $Force.IsPresent
  } | ConvertTo-Json -Compress
  New-HPPrivatePortablePayload -Data $data -Purpose "hp:sureadmin:firmwareupdate" -OutputFile $OutputFile -Verbose:$VerbosePreference
}

function New-HPPrivateSureAdminFirmwareUpdateAuthorization
{
  [CmdletBinding()]
  param(
    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$File,

    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $true,Position = 1)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKey,

    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [guid]$TargetUUID = 'ffffffff-ffff-ffff-ffff-ffffffffffff',

    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 3)]
    [switch]$SingleUse,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 5)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 6)]
    [switch]$CacheAccessToken,

    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 7)]
    [switch]$SignatureInBase64
  )

  Write-Verbose "Creating authentication payload"

  $name = "Allowed BIOS Update Hash"
  $fileHash = (Get-FileHash -Path $File -Algorithm SHA256).Hash

  # set value using raw bytes
  [byte[]]$valuebytes = [byte[]] -split ($fileHash -replace '..','0x$& ')

  $setting = New-Object -TypeName SureAdminSetting
  $setting.Name = $Name
  $setting.Value = $fileHash

  $nameLen = [System.Text.Encoding]::Unicode.GetByteCount($Name)
  $valueLen = $valuebytes.Length

  $params = @{
    NameLen = $nameLen
    ValueLen = $valueLen
    SingleUse = $SingleUse
    Nonce = $Nonce
    TargetUUID = $TargetUUID
  }
  [byte[]]$header = Invoke-HPPrivateConstructHeader @params -Verbose:$VerbosePreference
  [byte[]]$payload = New-Object byte[] ($Header.Count + $nameLen + $valueLen)

  $namebytes = [System.Text.Encoding]::Unicode.GetBytes($Name)
  [System.Array]::Copy($Header,0,$payload,0,$Header.Length)
  [System.Array]::Copy($namebytes,0,$payload,$Header.Length,$namebytes.Length)
  [System.Array]::Copy($valuebytes,0,$payload,$Header.Length + $namebytes.Length,$valuebytes.Length)

  if ($PSCmdlet.ParameterSetName -eq "LocalSigning") {
    [byte[]]$signature = Invoke-HPPrivateSignData -Data $payload -Certificate $SigningKey -Verbose:$VerbosePreference
  }
  else {
    [byte[]]$signature = Invoke-HPPrivateRemoteSignData -Data $payload -CertificateId $RemoteSigningServiceKeyID -KMSUri $RemoteSigningServiceURL -CacheAccessToken:$CacheAccessToken -Verbose:$VerbosePreference
  }

  $tag = "<BEAM/>"
  if ($SignatureInBase64.IsPresent) {
    return $tag + [Convert]::ToBase64String($signature)
  }
  $tagBytes = [System.Text.Encoding]::Unicode.GetBytes($tag)
  [byte[]]$authorization = New-Object byte[] ($namebytes.Length + $valuebytes.Length + $tagBytes.Length + $Header.Length + $Signature.Length)
  $offset = 0
  [System.Array]::Copy($namebytes,0,$authorization,$offset,$namebytes.Length)
  $offset += $namebytes.Length
  [System.Array]::Copy($valuebytes,0,$authorization,$offset,$valuebytes.Length)
  $offset += $valuebytes.Length
  [System.Array]::Copy($tagBytes,0,$authorization,$offset,$tagBytes.Length)
  $offset += $tagBytes.Length
  [System.Array]::Copy($Header,0,$authorization,$offset,$Header.Length)
  $offset += $Header.Length
  [System.Array]::Copy($Signature,0,$authorization,$offset,$Signature.Length)

  #($authorization | Format-Hex)
  return $authorization
}

<#
.SYNOPSIS
  Generate a payload for authorizing multiple BIOS setting changes

.DESCRIPTION
  This function uses the provided key to sign and authorize multiple BIOS setting changes.

  On return, the function writes the created payload to the pipeline, or to the file specified in the OutputFile parameter.
  This payload can then be passed to the Set-HPSecurePlatformPayload function.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload. Creating the payload and passing it to the Set-HPSecurePlatformPayload function via the pipeline is not a recommended production pattern.

.PARAMETER SigningKeyFile
  The path to the secure platform signing key, as a PFX file. If the PFX file is protected by a password (recommended),
  the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  The secure platform signing key file password, if required.

.PARAMETER SigningKeyCertificate
  The secure platform signing key certificate, as an X509Certificate object.

.PARAMETER Nonce
  The operation nonce. In order to prevent replay attacks, the secure platform subsystem will only accept commands with a nonce greater or equal to the last nonce sent.
  If not specified, the nonce is inferred from the current local time. This works okay in most cases, however this approach has a resolution of seconds, so when doing high volume or parallel operations, it is possible to infer the same counter for two or more commands. In those cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER InputFile
  The file (relative or absolute path) to the file to process containing one or more BIOS settings.

.PARAMETER InputFormat
  The input file format (XML, Json, CSV, or BCU).

.PARAMETER TargetUUID
  The computer UUID on which to perform this operation. If not specified the payload generated will work on any computer.

.PARAMETER OutputFile
  Write the resulting output to the specified file, instead of writing it to the pipeline.

.PARAMETER OutputFormat
  The output file format (default or BCU).

.PARAMETER RemoteSigningServiceKeyID
  The Signing Key ID to be used.

.PARAMETER RemoteSigningServiceURL
  The KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/).

.PARAMETER CacheAccessToken
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server, if not cached user have to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and user's credentials won't be asked again until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - An HP BIOS with HP Sure Admin support is required for applying the payloads generated by this function.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.EXAMPLE
  $payload = New-HPSureAdminBIOSSettingsListPayload -SigningKeyFile "$path\signing_key.pfx" -InputFile "settings.BCU" -Format BCU
  $payload | Set-HPSecurePlatformPayload

.EXAMPLE
  New-HPSureAdminBIOSSettingsListPayload -SigningKeyFile "$path\signing_key.pfx" -SigningKeyPassword "s3cr3t" -InputFile "settings.BCU" -Format BCU -OutputFile PayloadFile.dat
  Set-HPSecurePlatformPayload -PayloadFile PayloadFile.dat
#>
function New-HPSureAdminBIOSSettingsListPayload
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/new%e2%80%90hpsureadminbiossettingslistpayload")]
  param(
    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$InputFile,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 1)]
    [ValidateSet('Xml','Json','BCU','CSV')]
    [Alias('Format')]
    [string]$InputFormat = $null,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $true,Position = 2)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 3)]
    [string]$SigningKeyPassword,

    [Parameter(ValueFromPipeline = $true,ParameterSetName = "SigningKeyCert",Mandatory = $true,Position = 3)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 3)]
    [guid]$TargetUUID = 'ffffffff-ffff-ffff-ffff-ffffffffffff',

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 4)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 5)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 6)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 7)]
    [switch]$CacheAccessToken,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 8)]
    [ValidateSet('default','BCU')]
    [string]$OutputFormat = 'default'
  )

  Write-Verbose "InputFormat specified: '$InputFormat'. Reading file..."
  [System.Collections.Generic.List[SureAdminSetting]]$settingsList = $null
  $settingsList = Get-HPPrivateSettingsFromFile -FileName $InputFile -Format $InputFormat

  $params = @{
    SettingsList = $settingsList
    Nonce = $Nonce
    TargetUUID = $TargetUUID
  }

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    $params.RemoteSigningServiceKeyID = $RemoteSigningServiceKeyID
    $params.RemoteSigningServiceURL = $RemoteSigningServiceURL
    $params.CacheAccessToken = $CacheAccessToken
  }
  else {
    $params.SigningKey = (Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeycertificate -Verbose:$VerbosePreference).Full
  }

  $settingsList = New-HPPrivateSureAdminBIOSSettingsObject @params

  if ($OutputFormat -eq 'default') {
    $data = $settingsList | ConvertTo-Json
    New-HPPrivatePortablePayload -Data $data -Purpose "hp:sureadmin:biossettingslist" -OutputFile $OutputFile
  }
  elseif ($OutputFormat -eq 'bcu') {
    $dict = New-HPPrivateBIOSSettingsDefinition -SettingsDefinitionFile $InputFile -Format $InputFormat
    New-HPPrivateSureAdminSettingsBCU -settingsList $settingsList -SettingsDefinition $dict -OutputFile $OutputFile
  }
}

function New-HPPrivateBIOSSettingsDefinition
{
  [CmdletBinding()]
  param(
    $SettingsDefinitionFile,
    $Format
  )

  $dict = @{}
  switch ($format) {
    { $_ -eq 'xml' } {
      Write-Verbose "Reading XML settings definition $settingsDefinitionFile"
      [xml]$settingsDefinitionXml = Get-Content $SettingsDefinitionFile
      $entries = ([xml]$settingsDefinitionXml).ImagePal.BIOSSettings.BIOSSetting
      foreach ($entry in $entries) {
        [string[]]$valueList = @()
        foreach ($v in $entry.SelectNodes("ValueList/Value/text()"))
        {
          $valueList += $v.Value
        }
        if ($valueList -le 1) {
          [string[]]$valueList = @()
        }
        $dict[$entry.Name] = [pscustomobject]@{
          Name = $entry.Name
          Value = $entry.Value
          ValueList = $valueList
        }
      }
    }

    { $_ -eq 'bcu' } {
      Write-Verbose "Reading BCU settings definition $settingsDefinitionFile"

      $list = [ordered]@{}
      $currset = ""

      switch -regex -File $settingsDefinitionFile {
        '^\S.*$' {
          $currset = $matches[0].trim()
          if ($currset -ne "BIOSConfig 1.0" -and -not $currset.StartsWith(";")) {
            $list[$currset] = New-Object System.Collections.Generic.List[System.String]
          }
        }

        '^\s.*$' {
          # value (indented)
          $c = $matches[0].trim()
          $list[$currset].Add($c)
        }
      }

      foreach ($s in $list.keys) {
        [string[]]$valueList = @()
        if ($list[$s].Count -gt 1) {
          $valueList = $list[$s]
        }

        $dict[$s] = [pscustomobject]@{
          Name = $s
          Value = Get-HPPrivateDesiredValue -Value $list[$s]
          ValueList = $valueList
        }
      }
    }

    { $_ -eq 'csv' } {
      Write-Verbose "Reading CSV settings definition $settingsDefinitionFile"
      $content = Get-HPPrivateFileContent $settingsDefinitionFile
      $items = $content | ConvertFrom-Csv

      foreach ($item in $items) {

        [string[]]$valueList = @()
        if ($item.CURRENT_VALUE.contains(',')) {
          foreach ($v in $item.CURRENT_VALUE -split ',')
          {
            if ($v.StartsWith("*")) {
              $valueList += $v.substring(1)
            }
            else {
              $valueList += $v
            }
          }
        }

        $dict[$item.Name] = [pscustomobject]@{
          Name = $item.Name
          Value = (Get-HPPrivateDesiredValue $item.CURRENT_VALUE)
          ValueList = $valueList
        }
      }
    }

    { $_ -eq 'json' } {
      Write-Verbose "Reading JSON settings definition $settingsDefinitionFile"
      [string]$content = Get-HPPrivateFileContent $settingsDefinitionFile
      $list = $Content | ConvertFrom-Json

      foreach ($item in $list) {

        [string[]]$valueList = @()
        if ($item.PSObject.Properties.Name -match 'Elements') {
          [string[]]$valueList = $item.Elements
        }
        elseif ($item.PSObject.Properties.Name -match 'PossibleValues') {
          [string[]]$valueList = $item.PossibleValues
        }

        $dict[$item.Name] = [pscustomobject]@{
          Name = $item.Name
          Value = $item.Value
          ValueList = $valueList
        }
      }
    }
  }

  $dict['SetSystemDefaults'] = [pscustomobject]@{
    Name = 'SetSystemDefaults'
    Value = ''
    ValueList = @()
  }

  $dict['Allowed BIOS Update Hash'] = [pscustomobject]@{
    Name = 'Allowed BIOS Update Hash'
    Value = ''
    ValueList = @()
  }

  return $dict
}

function New-HPPrivateSureAdminSettingsBCU
{
  [CmdletBinding()]
  param(
    $SettingsList,
    $SettingsDefinition,
    $Platform,
    [System.IO.FileInfo]$OutputFile,
    [switch]$SkipSettingDefinition
  )

  Write-Verbose "Found $($SettingsList.Count) settings"
  $now = Get-Date
  $output += "BIOSConfig 1.0`n"
  $output += ";`n"
  $output += ";     Created by CMSL function $((Get-PSCallStack)[1].Command)`n"
  $output += ";     Date=$now`n"
  $output += ";`n"
  $output += ";     Found $($SettingsList.Count) settings`n"
  $output += ";`n"
  foreach ($entry in $SettingsList) {
    $output += "$($entry.Name)`n"
    if ($SkipSettingDefinition.IsPresent) {
      $output += "`t$($entry.Value)`n"
    }
    else {
      if (-not $SettingsDefinition -or -not $SettingsDefinition.ContainsKey($entry.Name)) {
        throw "Setting definition not found: $($entry.Name)"
      }
      $definition = $SettingsDefinition[$entry.Name]
      if ($entry.Value.contains(",") -and $definition.ValueList.Count -gt 0) {
        $entry.Value.Split(",") | ForEach-Object {
          $c = $_.trim()
          $output += "`t$c`n"
        }
      }
      elseif ($definition.ValueList.Count -gt 0) {
        foreach ($v in $definition.ValueList) {
          if ($v -eq $entry.Value) {
            $output += "`t*$($v)`n"
          }
          else {
            $output += "`t$($v)`n"
          }
        }
      }
      else {
        $output += "`t$($entry.Value)`n"
      }
    }
    $output += ";Signature=$($entry.AuthString)`n"
  }

  if ($OutputFile) {
    Write-Verbose "Will output to file $OutputFile"
    $f = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
    Out-File -FilePath $f -Encoding utf8 -InputObject $output
  }
  else {
    Write-Verbose 'Will output to console'
    $output
  }
}

function New-HPPrivatePortablePayload {
  param(
    [string]$Data,
    [string]$Purpose,
    [System.IO.FileInfo]$OutputFile
  )

  $output = New-Object -TypeName PortableFileFormat
  $output.timestamp = Get-Date
  $output.purpose = $Purpose
  $output.Data = [System.Text.Encoding]::UTF8.GetBytes($Data)

  if ($OutputFile) {
    Write-Verbose 'Will output to file $OutputFile'
    $f = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
    $output | ConvertTo-Json -Compress | Out-File -FilePath $f -Encoding utf8
  }
  else {
    $output | ConvertTo-Json -Compress
  }
}

function New-HPPrivateSureAdminBIOSSettingsObject {
  [CmdletBinding()]
  param(
    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 0)]
    [System.Collections.Generic.List[SureAdminSetting]]$SettingsList,

    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [switch]$SingleUse,

    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 3)]
    [guid]$TargetUUID = 'ffffffff-ffff-ffff-ffff-ffffffffffff',

    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $true,Position = 4)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKey,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 5)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 6)]
    [switch]$CacheAccessToken
  )

  Write-Verbose "Signing settings list"

  $params = @{
    Nonce = $Nonce
    TargetUUID = $TargetUUID
  }

  if ($PSCmdlet.ParameterSetName -eq "LocalSigning") {
    $params.SigningKey = $SigningKey
    for ($i = 0; $i -lt $SettingsList.Count; $i++) {
      $setting = $SettingsList[$i]
      $params.Name = $setting.Name
      $params.Value = $setting.Value

      if ($setting.AuthString -eq $null) {
        $SettingsList[$i] = New-HPPrivateSureAdminBIOSSettingObject @params -Verbose:$VerbosePreference
      }
    }
  }
  else {
    $params.CertificateId = $RemoteSigningServiceKeyID
    $params.KMSUri = $RemoteSigningServiceURL
    $params.CacheAccessToken = $CacheAccessToken
    $params.SettingsList = $SettingsList
    $SettingsList = Invoke-HPPrivateRemoteSignSureAdminSettings @params -Verbose:$VerbosePreference
  }

  return $SettingsList
}

function Invoke-HPPrivateRemoteSignSureAdminSettings {
  [CmdletBinding()]
  param(
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 0)]
    [guid]$TargetUUID = 'ffffffff-ffff-ffff-ffff-ffffffffffff',

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 2)]
    [System.Collections.Generic.List[SureAdminSetting]]$SettingsList,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 3)]
    [string]$CertificateId,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [string]$KMSUri,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 5)]
    [switch]$CacheAccessToken,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 6)]
    [switch]$SingleUse
  )

  if (-not $KMSUri.EndsWith('/')) {
    $KMSUri += '/'
  }
  $KMSUri += 'api/commands/sureadminauth'

  $jsonPayload = New-HPPrivateSureAdminRemoteSigningSettingsJson -settingsList $SettingsList -nonce $Nonce -TargetUUID $TargetUUID -CertificateId $CertificateId -SingleUse:$SingleUse
  $accessToken = Get-HPPrivateSureAdminKMSAccessToken -CacheAccessToken:$CacheAccessToken
  $response,$responseContent = Send-HPPrivateKMSRequest -KMSUri $KMSUri -JsonPayload $jsonPayload -AccessToken $accessToken

  if ($response -eq "OK") {
    $responseObject = $responseContent | ConvertFrom-Json

    $settings = New-Object System.Collections.Generic.List[SureAdminSetting]
    for ($i = 0; $i -lt $responseObject.settings.Count; $i++) {
      $settings.Add([SureAdminSetting]@{
          Name = $responseObject.settings[$i].Name
          Value = $responseObject.settings[$i].Value
          AuthString = $responseObject.settings[$i].AuthString
        }) | Out-Null
    }
    # Return a list of [SureAdminSetting]
    $settings
  }
  else {
    Invoke-HPPrivateKMSErrorHandle -ApiResponseContent $responseContent -Status $response
  }
}

function New-HPPrivateSureAdminBIOSSettingObject {
  [CmdletBinding()]
  param(
    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 0)]
    [string]$Name,

    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 1)]
    [AllowEmptyString()]
    [string]$Value,

    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [switch]$SingleUse,

    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 3)]
    [uint32]$Nonce,

    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [guid]$TargetUUID,

    [Parameter(ParameterSetName = "LocalSigning",Mandatory = $true,Position = 5)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKey,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 5)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 6)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 7)]
    [switch]$CacheAccessToken
  )

  [SureAdminSetting]$setting = New-Object -TypeName SureAdminSetting
  $setting.Name = $Name
  $setting.Value = $Value

  if ($PSCmdlet.ParameterSetName -eq "LocalSigning") {
    if ($Name -eq "Setup Password" -or $Name -eq "Power-On Password") {
      $SettingValueForSigning = "<utf-16/>" + $Value
    }
    else {
      $SettingValueForSigning = $Value
    }

    $nameLen = [System.Text.Encoding]::Unicode.GetByteCount($setting.Name)
    $valueLen = [System.Text.Encoding]::Unicode.GetByteCount($SettingValueForSigning)

    $params = @{
      NameLen = $nameLen
      ValueLen = $valueLen
      SingleUse = $SingleUse
      Nonce = $Nonce
      TargetUUID = $TargetUUID
    }
    [byte[]]$header = Invoke-HPPrivateConstructHeader @params -Verbose:$VerbosePreference
    [byte[]]$payload = Invoke-HPPrivateConstructPayload -Header $header -Name $setting.Name -Value $SettingValueForSigning -Verbose:$VerbosePreference
    [byte[]]$signature = Invoke-HPPrivateSignData -Data $payload -Certificate $SigningKey -Verbose:$VerbosePreference
    $setting.AuthString = Invoke-HPPrivateConstructAuthorization -Header $header -Signature $signature -Verbose:$VerbosePreference
  }
  else {
    $settings = New-Object System.Collections.Generic.List[SureAdminSetting]
    $settings.Add($setting)
    $setting = (Invoke-HPPrivateRemoteSignSureAdminSettings -TargetUUID $TargetUUID -Nonce $Nonce -CertificateId $RemoteSigningServiceKeyID -KMSUri $RemoteSigningServiceURL -CacheAccessToken:$CacheAccessToken -SingleUse:$SingleUse -SettingsList $settings)[0]
  }

  return $setting
}

function New-HPPrivateSureAdminRemoteSigningJson {
  [CmdletBinding()]
  param(
    [string]$CertificateId,
    [byte[]]$Data
  )

  $blob = [Convert]::ToBase64String($Data)
  $payload = [ordered]@{
    keyId = $CertificateId
    commandBlob = $blob
  }

  $payload | ConvertTo-Json -Compress
}

function New-HPPrivateSureAdminRemoteSigningSettingsJson {
  [CmdletBinding()]
  param(
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 0)]
    [guid]$TargetUUID = 'ffffffff-ffff-ffff-ffff-ffffffffffff',

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 2)]
    [System.Collections.Generic.List[SureAdminSetting]]$SettingsList,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 3)]
    [string]$CertificateId,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 4)]
    [switch]$SingleUse
  )

  $settings = New-Object System.Collections.ArrayList
  for ($i = 0; $i -lt $SettingsList.Count; $i++) {
    $settings.Add([pscustomobject]@{
        Name = $SettingsList[$i].Name
        Value = $SettingsList[$i].Value
        Nonce = $Nonce
        TargetUUID = $TargetUUID
        isSingleUse = $SingleUse.IsPresent
      }) | Out-Null
  }

  $payload = [ordered]@{
    keyId = $CertificateId
    settings = $settings
  }

  $payload | ConvertTo-Json -Compress
}

function Invoke-HPPrivateRemoteSignData {
  [CmdletBinding()]
  param(
    [byte[]]$Data,
    [string]$CertificateId,
    [string]$KMSUri,
    [switch]$CacheAccessToken
  )

  if (-not $KMSUri.EndsWith('/')) {
    $KMSUri += '/'
  }
  $KMSUri += 'api/commands/p21signature'

  $jsonPayload = New-HPPrivateSureAdminRemoteSigningJson -CertificateId $CertificateId -Data $Data
  $accessToken = Get-HPPrivateSureAdminKMSAccessToken -CacheAccessToken:$CacheAccessToken
  $response,$responseContent = Send-HPPrivateKMSRequest -KMSUri $KMSUri -JsonPayload $jsonPayload -AccessToken $accessToken

  if ($response -eq "OK") {
    $responseObject = $responseContent | ConvertFrom-Json
    [System.Convert]::FromBase64String($responseObject.signature)
  }
  else {
    Invoke-HPPrivateKMSErrorHandle -ApiResponseContent $responseContent -Status $response
  }
}

<#
.SYNOPSIS
  Generate a payload for resetting BIOS settings to default values

.DESCRIPTION
  This function uses the provided key to sign and authorize resetting BIOS settings to default values.

  On return, the function writes the created payload to the pipeline, or to the file specified in the OutputFile parameter.
  This payload can then be passed to the Set-HPSecurePlatformPayload function.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload. Creating the payload and passing it to the Set-HPSecurePlatformPayload function via the pipeline is not a recommended production pattern.

.PARAMETER SigningKeyFile
  The path to the secure platform signing key, as a PFX file. If the PFX file is protected by a password (recommended),
  the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  The secure platform signing key file password, if required.

.PARAMETER SigningKeyCertificate
  The secure platform signing key certificate, as an X509Certificate object.

.PARAMETER Nonce
  The operation nonce. In order to prevent replay attacks, the secure platform subsystem will only accept commands with a nonce greater or equal to the last nonce sent.
  If not specified, the nonce is inferred from the current local time. This works okay in most cases, however this approach has a resolution of seconds, so when doing high volume or parallel operations, it is possible to infer the same counter for two or more commands. In those cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER TargetUUID
  The computer UUID on which to perform this operation. If not specified the payload generated will work on any computer.

.PARAMETER OutputFile
  Write the resulting output to the specified file, instead of writing it to the pipeline.

.PARAMETER RemoteSigningServiceKeyID
  The Signing Key ID to be used.

.PARAMETER RemoteSigningServiceURL
  The KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/).

.PARAMETER CacheAccessToken
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server, if not cached user have to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and user's credentials won't be asked again until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - An HP BIOS with HP Sure Admin support is required for applying the payloads generated by this function.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.EXAMPLE
  $payload = New-HPSureAdminSettingDefaultsPayload -SigningKeyFile "$path\signing_key.pfx"
  $payload | Set-HPSecurePlatformPayload

.EXAMPLE
  New-HPSureAdminSettingDefaultsPayload -SigningKeyFile "$path\signing_key.pfx" -SigningKeyPassword "s3cr3t" -OutputFile PayloadFile.dat
  Set-HPSecurePlatformPayload -PayloadFile PayloadFile.dat
#>
function New-HPSureAdminSettingDefaultsPayload
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/new%e2%80%90hpsureadminsettingdefaultspayload")]
  param(
    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 1)]
    [string]$SigningKeyPassword,

    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 0)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [guid]$TargetUUID = 'ffffffff-ffff-ffff-ffff-ffffffffffff',

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 3)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 5)]
    [switch]$CacheAccessToken
  )

  $params = @{
    Name = "SetSystemDefaults"
    Value = ""
    Nonce = $Nonce
    TargetUUID = $TargetUUID
  }

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    $params.RemoteSigningServiceKeyID = $RemoteSigningServiceKeyID
    $params.RemoteSigningServiceURL = $RemoteSigningServiceURL
    $params.CacheAccessToken = $CacheAccessToken
  }
  else {
    $params.SigningKey = (Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeycertificate -Verbose:$VerbosePreference).Full
  }

  [SureAdminSetting]$setting = New-HPPrivateSureAdminBIOSSettingObject @params -Verbose:$VerbosePreference
  $data = $setting | ConvertTo-Json
  New-HPPrivatePortablePayload -Data $data -Purpose "hp:sureadmin:resetsettings" -OutputFile $OutputFile
}

<#
.SYNOPSIS
  Generate a payload for enabling the HP Sure Admin feature

.DESCRIPTION
  This function uses the provided key to sign and authorize the operation of enabling HP Sure Admin.

  On return, the function writes the created payload to the pipeline, or to the file specified in the OutputFile parameter.
  This payload can then be passed to the Set-HPSecurePlatformPayload function.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload. Creating the payload and passing it to the Set-HPSecurePlatformPayload function via the pipeline is not a recommended production pattern.

.PARAMETER SigningKeyFile
  The path to the secure platform signing key, as a PFX file. If the PFX file is protected by a password (recommended),
  the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  The secure platform signing key file password, if required.

.PARAMETER SigningKeyCertificate
  The secure platform signing key certificate, as an X509Certificate object.

.PARAMETER Nonce
  The operation nonce. In order to prevent replay attacks, the secure platform subsystem will only accept commands with a nonce greater or equal to the last nonce sent.
  If not specified, the nonce is inferred from the current local time. This works okay in most cases, however this approach has a resolution of seconds, so when doing high volume or parallel operations, it is possible to infer the same counter for two or more commands. In those cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER TargetUUID
  The computer UUID on which to perform this operation. If not specified the payload generated will work on any computer.

.PARAMETER SingleUse
  If specified, the payload cannot be replayed. This happens because the nonce must be higher than ActionsCounter and this counter is updated and incremented every time a command generated with SingleUse flag is accepted by the BIOS.
  If not specified, the payload can be replayed as many times as desired until a payload generated with a nonce higher than
  SettingsCounter is received. This happens because SettingsCounter is not incremented by the BIOS when accepting commands.

.PARAMETER OutputFile
  Write the resulting output to the specified file, instead of writing it to the pipeline.

.PARAMETER RemoteSigningServiceKeyID
  The Signing Key ID to be used.

.PARAMETER RemoteSigningServiceURL
  The KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/).

.PARAMETER CacheAccessToken
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server, if not cached user have to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and user's credentials won't be asked again until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - An HP BIOS with HP Sure Admin support is required for applying the payloads generated by this function.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.EXAMPLE
  $payload = New-HPSureAdminEnablePayload -SigningKeyFile "$path\signing_key.pfx"
  $payload | Set-HPSecurePlatformPayload

.EXAMPLE
  New-HPSureAdminEnablePayload -SigningKeyFile "$path\signing_key.pfx" -SigningKeyPassword "s3cr3t" -OutputFile PayloadFile.dat
  Set-HPSecurePlatformPayload -PayloadFile PayloadFile.dat
#>
function New-HPSureAdminEnablePayload
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/new%e2%80%90hpsureadminenablepayload")]
  param(
    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $true,Position = 1)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 2)]
    [string]$SigningKeyPassword,

    [Parameter(ValueFromPipeline = $true,ParameterSetName = "SigningKeyCert",Mandatory = $true,Position = 1)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 0)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [guid]$TargetUUID = 'ffffffff-ffff-ffff-ffff-ffffffffffff',

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [switch]$SingleUse,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 3)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 5)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 6)]
    [switch]$CacheAccessToken
  )

  $params = @{
    Name = "Enhanced BIOS Authentication Mode"
    Value = "Enable"
    SingleUse = $SingleUse
    Nonce = $Nonce
    TargetUUID = $TargetUUID
    OutputFile = $OutputFile
  }

  if ($PSCmdlet.ParameterSetName -eq "SigningKeyFile") {
    $params.SigningKeyFile = $SigningKeyFile
    $params.SigningKeyPassword = $SigningKeyPassword
  }
  elseif ($PSCmdlet.ParameterSetName -eq "SigningKeyCert") {
    $params.SigningKeyCertificate = $SigningKeyCertificate
  }
  elseif ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    $params.RemoteSigningServiceKeyID = $RemoteSigningServiceKeyID
    $params.RemoteSigningServiceURL = $RemoteSigningServiceURL
    $params.CacheAccessToken = $CacheAccessToken
  }

  New-HPSureAdminBIOSSettingValuePayload @params -Verbose:$VerbosePreference
}

<#
.SYNOPSIS
  Generate a payload for disabling the HP Sure Admin feature

.DESCRIPTION
  This function uses the provided key to sign and authorize the operation of disabling HP Sure Admin.

  On return, the function writes the created payload to the pipeline, or to the file specified in the OutputFile parameter.
  This payload can then be passed to the Set-HPSecurePlatformPayload function.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload. Creating the payload and passing it to the Set-HPSecurePlatformPayload function via the pipeline is not a recommended production pattern.

.PARAMETER SigningKeyFile
  The path to the secure platform signing key, as a PFX file. If the PFX file is protected by a password (recommended),
  the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  The secure platform signing key file password, if required.

.PARAMETER SigningKeyCertificate
  The secure platform signing key certificate, as an X509Certificate object.

.PARAMETER Nonce
  The operation nonce. In order to prevent replay attacks, the secure platform subsystem will only accept commands with a nonce greater or equal to the last nonce sent.
  If not specified, the nonce is inferred from the current local time. This works okay in most cases, however this approach has a resolution of seconds, so when doing high volume or parallel operations, it is possible to infer the same counter for two or more commands. In those cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER TargetUUID
  The computer UUID on which to perform this operation. If not specified the payload generated will work on any computer.

.PARAMETER SingleUse
  If specified, the payload cannot be replayed. This happens because the nonce must be higher than ActionsCounter and this counter is updated and incremented every time a command generated with SingleUse flag is accepted by the BIOS.
  If not specified, the payload can be replayed as many times as desired until a payload generated with a nonce higher than
  SettingsCounter is received. This happens because SettingsCounter is not incremented by the BIOS when accepting commands.

.PARAMETER OutputFile
  Write the resulting output to the specified file, instead of writing it to the pipeline.

.PARAMETER RemoteSigningServiceKeyID
  The Signing Key ID to be used.

.PARAMETER RemoteSigningServiceURL
  The KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/).

.PARAMETER CacheAccessToken
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server, if not cached user have to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and user's credentials won't be asked again until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - An HP BIOS with HP Sure Admin support is required for applying the payloads generated by this function.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.EXAMPLE
  $payload = New-HPSureAdminDisablePayload -SigningKeyFile "$path\signing_key.pfx"
  $payload | Set-HPSecurePlatformPayload

.EXAMPLE
  New-HPSureAdminDisablePayload -SigningKeyFile "$path\signing_key.pfx" -SigningKeyPassword "s3cr3t" -OutputFile PayloadFile.dat
  Set-HPSecurePlatformPayload -PayloadFile PayloadFile.dat
#>
function New-HPSureAdminDisablePayload
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/new%e2%80%90hpsureadmindisablepayload")]
  param(
    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $true,Position = 1)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 2)]
    [string]$SigningKeyPassword,

    [Parameter(ValueFromPipeline = $true,ParameterSetName = "SigningKeyCert",Mandatory = $true,Position = 1)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 0)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [guid]$TargetUUID = 'ffffffff-ffff-ffff-ffff-ffffffffffff',

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [switch]$SingleUse,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 3)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 5)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 6)]
    [switch]$CacheAccessToken
  )

  $params = @{
    Name = "Enhanced BIOS Authentication Mode"
    Value = "Disable"
    SingleUse = $SingleUse
    Nonce = $Nonce
    TargetUUID = $TargetUUID
    OutputFile = $OutputFile
  }

  if ($PSCmdlet.ParameterSetName -eq "SigningKeyFile") {
    $params.SigningKeyFile = $SigningKeyFile
    $params.SigningKeyPassword = $SigningKeyPassword
  }
  elseif ($PSCmdlet.ParameterSetName -eq "SigningKeyCert") {
    $params.SigningKeyCertificate = $SigningKeyCertificate
  }
  elseif ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    $params.RemoteSigningServiceKeyID = $RemoteSigningServiceKeyID
    $params.RemoteSigningServiceURL = $RemoteSigningServiceURL
    $params.CacheAccessToken = $CacheAccessToken
  }

  New-HPSureAdminBIOSSettingValuePayload @params -Verbose:$VerbosePreference
}

<#
.SYNOPSIS
  Generate a payload for provisioning a local access key

.DESCRIPTION
  This function uses the provided key to sign and authorize updating HP Sure Admin local access keys.
  Setting a local access key allows system administrators to authorize commands locally with the HP Sure Admin phone app.

  Check the function Convert-HPSureAdminCertToQRCode to know how to transferring a local access key to the HP Sure Admin phone app.

  On return, the function writes the created payload to the pipeline, or to the file specified in the OutputFile parameter.
  This payload can then be passed to the Set-HPSecurePlatformPayload function.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload. Creating the payload and passing it to the Set-HPSecurePlatformPayload function via the pipeline is not a recommended production pattern.

.PARAMETER SigningKeyFile
  The path to the secure platform signing key, as a PFX file. If the PFX file is protected by a password (recommended),
  the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  The secure platform signing key file password, if required.

.PARAMETER LocalAccessKeyFile
  The path to the local access key, as a PFX file. If the PFX file is protected by a password (recommended),
  the LocalAccessKeyPassword parameter should also be provided.

.PARAMETER LocalAccessKeyPassword
  The local access key file password, if required.

.PARAMETER SigningKeyCertificate
  The secure platform signing key certificate, as an X509Certificate object.

.PARAMETER Nonce
  The operation nonce. In order to prevent replay attacks, the secure platform subsystem will only accept commands with a nonce greater or equal to the last nonce sent.
  If not specified, the nonce is inferred from the current local time. This works okay in most cases, however this approach has a resolution of seconds, so when doing high volume or parallel operations, it is possible to infer the same counter for two or more commands. In those cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER TargetUUID
  The computer UUID on which to perform this operation. If not specified the payload generated will work on any computer.

.PARAMETER SingleUse
  If specified, the payload cannot be replayed. This happens because the nonce must be higher than ActionsCounter and this counter is updated and incremented every time a command generated with SingleUse flag is accepted by the BIOS.
  If not specified, the payload can be replayed as many times as desired until a payload generated with a nonce higher than
  SettingsCounter is received. This happens because SettingsCounter is not incremented by the BIOS when accepting commands.

.PARAMETER OutputFile
  Write the resulting output to the specified file, instead of writing it to the pipeline.

.PARAMETER Id
  Int Id from 1,2 or 3 that gets appended to the setting name.

.PARAMETER KeyEnrollmentData
  KeyEnrollmentData to use to get Sure Admin Local Access key from certificate

.PARAMETER RemoteSigningServiceKeyID
  The Signing Key ID to be used.

.PARAMETER RemoteSigningServiceURL
  The KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/).

.PARAMETER CacheAccessToken
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server, if not cached user have to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and user's credentials won't be asked again until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - An HP BIOS with HP Sure Admin support is required for applying the payloads generated by this function.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.EXAMPLE
  $payload = New-HPSureAdminLocalAccessKeyProvisioningPayload -SigningKeyFile "$path\signing_key.pfx" -LocalAccessKeyFile "$path\local_access_key.pfx"
  $payload | Set-HPSecurePlatformPayload

.EXAMPLE
  New-HPSureAdminLocalAccessKeyProvisioningPayload -SigningKeyFile "$path\signing_key.pfx" -SigningKeyPassword "s3cr3t" -LocalAccessKeyFile "$path\local_access_key.pfx" -LocalAccessKeyPassword "lak_s3cr3t" -OutputFile PayloadFile.dat
  Set-HPSecurePlatformPayload -PayloadFile PayloadFile.dat
#>
function New-HPSureAdminLocalAccessKeyProvisioningPayload
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/new%e2%80%90hpsureadminlocalaccesskeyprovisioningpayload")]
  param(
    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $true,Position = 1)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 2)]
    [string]$SigningKeyPassword,

    [Parameter(ValueFromPipeline = $true,ParameterSetName = "SigningKeyCert",Mandatory = $true,Position = 1)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 0)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [guid]$TargetUUID = 'ffffffff-ffff-ffff-ffff-ffffffffffff',

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [switch]$SingleUse,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $true,Position = 6)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $true,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 3)]
    [System.IO.FileInfo]$LocalAccessKeyFile,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 4)]
    [string]$LocalAccessKeyPassword,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 5)]
    [ValidateSet(1,2,3)]
    [int]$Id = 1,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 6)]
    [string]$KeyEnrollmentData,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 7)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 8)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 9)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 10)]
    [switch]$CacheAccessToken
  )

  $localAccessKey = (Get-HPPrivateX509CertCoalesce -File $LocalAccessKeyFile -password $LocalAccessKeyPassword -cert $null -Verbose:$VerbosePreference).Full
  [string]$pubKeyBase64 = Get-HPPrivateSureAdminLocalAccessKeyFromCert -LocalAccessKey $localAccessKey -KeyEnrollmentData $KeyEnrollmentData

  $params = @{
    Name = "Enhanced BIOS Authentication Mode Local Access Key " + $Id
    Value = $pubKeyBase64
    SingleUse = $SingleUse
    Nonce = $Nonce
    TargetUUID = $TargetUUID
    OutputFile = $OutputFile
  }
  if ($PSCmdlet.ParameterSetName -eq "SigningKeyFile") {
    $params.SigningKeyFile = $SigningKeyFile
    $params.SigningKeyPassword = $SigningKeyPassword
  }
  elseif ($PSCmdlet.ParameterSetName -eq "SigningKeyCert") {
    $params.SigningKeyCertificate = $SigningKeyCertificate
  }
  elseif ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    $params.RemoteSigningServiceKeyID = $RemoteSigningServiceKeyID
    $params.RemoteSigningServiceURL = $RemoteSigningServiceURL
    $params.CacheAccessToken = $CacheAccessToken
  }

  New-HPSureAdminBIOSSettingValuePayload @params -Verbose:$VerbosePreference
}

<#
.SYNOPSIS
  Generate a payload for authorizing a single BIOS setting change

.DESCRIPTION
  This function uses the provided key to sign and authorize a single BIOS setting change.

  On return, the function writes the created payload to the pipeline, or to the file specified in the OutputFile parameter.
  This payload can then be passed to the Set-HPSecurePlatformPayload function.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload. Creating the payload and passing it to the Set-HPSecurePlatformPayload function via the pipeline is not a recommended production pattern.

.PARAMETER Name
  The name of a setting. Note that the setting name is usually case sensitive.

.PARAMETER Value
  The new value of a setting

.PARAMETER SigningKeyFile
  The path to the secure platform signing key, as a PFX file. If the PFX file is protected by a password (recommended),
  the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  The secure platform signing key file password, if required.

.PARAMETER SigningKeyCertificate
  The secure platform signing key certificate, as an X509Certificate object.

.PARAMETER Nonce
  The operation nonce. In order to prevent replay attacks, the secure platform subsystem will only accept commands with a nonce greater or equal to the last nonce sent.
  If not specified, the nonce is inferred from the current local time. This works okay in most cases, however this approach has a resolution of seconds, so when doing high volume or parallel operations, it is possible to infer the same counter for two or more commands. In those cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER TargetUUID
  The computer UUID on which to perform this operation. If not specified the payload generated will work on any computer.

.PARAMETER SingleUse
  If specified, the payload cannot be replayed. This happens because the nonce must be higher than ActionsCounter and this counter is updated and incremented every time a command generated with SingleUse flag is accepted by the BIOS.
  If not specified, the payload can be replayed as many times as desired until a payload generated with a nonce higher than
  SettingsCounter is received. This happens because SettingsCounter is not incremented by the BIOS when accepting commands.

.PARAMETER OutputFile
  Write the resulting output to the specified file, instead of writing it to the pipeline.

.PARAMETER RemoteSigningServiceKeyID
  The Signing Key ID to be used.

.PARAMETER RemoteSigningServiceURL
  The KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/).

.PARAMETER CacheAccessToken
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server, if not cached user have to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and user's credentials won't be asked again until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - An HP BIOS with HP Sure Admin support is required for applying the payloads generated by this function.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.EXAMPLE
  $payload = New-HPSureAdminBIOSSettingValuePayload -Name "Setting Name" -Value "New Setting Value" -SigningKeyFile "$path\signing_key.pfx"
  $payload | Set-HPSecurePlatformPayload

.EXAMPLE
  New-HPSureAdminBIOSSettingValuePayload -Name "Setting Name" -Value "New Setting Value" -SigningKeyFile "$path\signing_key.pfx" -SigningKeyPassword "s3cr3t" -OutputFile PayloadFile.dat
  Set-HPSecurePlatformPayload -PayloadFile PayloadFile.dat
#>
function New-HPSureAdminBIOSSettingValuePayload
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/new%e2%80%90hpsureadminbiossettingvaluepayload")]
  param(
    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 0)]
    [string]$Name,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 1)]
    [AllowEmptyString()]
    [string]$Value,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $true,Position = 2)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 3)]
    [string]$SigningKeyPassword,

    [Parameter(ValueFromPipeline = $true,ParameterSetName = "SigningKeyCert",Mandatory = $true,Position = 2)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 3)]
    [guid]$TargetUUID = 'ffffffff-ffff-ffff-ffff-ffffffffffff',

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 4)]
    [switch]$SingleUse,

    [Parameter(ParameterSetName = "SigningKeyFile",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "SigningKeyCert",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 5)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 6)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 7)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 8)]
    [switch]$CacheAccessToken
  )

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    $params = @{
      Name = $Name
      Value = $Value
      SingleUse = $SingleUse
      Nonce = $Nonce
      TargetUUID = $TargetUUID
      RemoteSigningServiceKeyID = $RemoteSigningServiceKeyID
      RemoteSigningServiceURL = $RemoteSigningServiceURL
      CacheAccessToken = $CacheAccessToken
    }
  }
  else {
    $signingKey = (Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeycertificate -Verbose:$VerbosePreference).Full
    $params = @{
      Name = $Name
      Value = $Value
      SingleUse = $SingleUse
      Nonce = $Nonce
      TargetUUID = $TargetUUID
      SigningKey = $signingKey
    }
  }

  [SureAdminSetting]$setting = New-HPPrivateSureAdminBIOSSettingObject @params -Verbose:$VerbosePreference
  $data = $setting | ConvertTo-Json
  New-HPPrivatePortablePayload -Data $data -Purpose "hp:sureadmin:biossetting" -OutputFile $OutputFile -Verbose:$VerbosePreference
}

function Invoke-HPPrivateConstructHeader {
  [CmdletBinding()]
  param(
    [uint32]$NameLen,
    [uint32]$ValueLen,
    [switch]$SingleUse,
    [uint32]$Nonce,
    [guid]$TargetUUID
  )

  $data = New-Object -TypeName SureAdminSignatureBlockHeader

  $data.Version = 1
  $data.NameLength = $NameLen
  $data.ValueLength = $ValueLen
  $data.OneTimeUse = [byte]($SingleUse.IsPresent)
  $data.Nonce = $Nonce
  $data.Reserved = 1
  $data.Target = $TargetUUID.ToByteArray()

  [byte[]]$header = (Convert-HPPrivateObjectToBytes -obj $data -Verbose:$VerbosePreference)[0]
  return $header
}

function Invoke-HPPrivateConstructPayload {
  [CmdletBinding()]
  param(
    [byte[]]$Header,
    [string]$Name,
    [string]$Value
  )

  $nameLen = [System.Text.Encoding]::Unicode.GetByteCount($Name)
  $valueLen = [System.Text.Encoding]::Unicode.GetByteCount($Value)
  [byte[]]$payload = New-Object byte[] ($Header.Count + $nameLen + $valueLen)

  $namebytes = [System.Text.Encoding]::Unicode.GetBytes($Name)
  [System.Array]::Copy($Header,0,$payload,0,$Header.Length)
  [System.Array]::Copy($namebytes,0,$payload,$Header.Length,$namebytes.Length)
  if ($valueLen -ne 0) {
    Write-Verbose "Copying value to payload"
    $valuebytes = [System.Text.Encoding]::Unicode.GetBytes($Value)
    [System.Array]::Copy($valuebytes,0,$payload,$Header.Length + $namebytes.Length,$valuebytes.Length)
  }
  else {
    Write-Verbose "No value was specified for this setting"
  }

  return $payload
}

function Invoke-HPPrivateConstructAuthorization {
  [CmdletBinding()]
  param(
    [byte[]]$Header,
    [byte[]]$Signature
  )

  [byte[]]$authorization = New-Object byte[] ($Header.Length + $Signature.Length)
  [System.Array]::Copy($Header,0,$authorization,0,$Header.Length)
  [System.Array]::Copy($Signature,0,$authorization,$Header.Length,$Signature.Length)

  [string]$encodedAuth = "<BEAM/>" + [Convert]::ToBase64String($authorization)
  return $encodedAuth
}

function Get-HPPrivatePublicKeyModulus ($cert)
{
  $key = $cert.PublicKey.key
  $parameters = $key.ExportParameters($false);
  return $parameters.Modulus
}

function Get-HPPrivateKeyNameFromCert ($cert)
{
  return $cert.Subject -replace "(CN=)(.*?),.*",'$2'
}

function Get-HPPrivatePrimesFromCert ($Certificate)
{
  $rsaPrivate = [xml]$Certificate.PrivateKey.ToXmlString($true)

  $p = [System.Convert]::FromBase64String($rsaPrivate.RSAKeyValue.P)
  $q = [System.Convert]::FromBase64String($rsaPrivate.RSAKeyValue.Q)

  $primes = [System.Byte[]]::new(256)

  for ($i = 0; $i -lt 128; $i++)
  {
    $primes[$i] = $p[$i]
  }

  for ($i = 0; $i -lt 128; $i++)
  {
    $primes[128 + $i] = $q[$i]
  }

  return $primes
}

function Get-HPPrivateRandomByteArray ($Length)
{
  $RandomBytes = New-Object Byte[] ($Length)

  $RNG = [Security.Cryptography.RNGCryptoServiceProvider]::Create()
  $RNG.GetBytes($RandomBytes)

  return $RandomBytes
}

function Get-HPPrivateRandomIV ()
{
  return Get-HPPrivateRandomByteArray 16
}

function Get-HPPrivateRandomSalt ()
{
  return Get-HPPrivateRandomByteArray 8
}

function Get-HPPrivatePbkdf2Bytes ($Passphrase,$Salt,$Iterations,$Length,$Metadata = $null)
{
  $Passphrase += $Metadata
  $PBKDF2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes ($Passphrase,$Salt,$Iterations)
  return $PBKDF2.GetBytes($Length)
}

function Get-HPPrivateDataEncryption ([byte[]]$AESKey,[byte[]]$Data,[byte[]]$IV)
{
  $aesManaged = New-Object System.Security.Cryptography.AesManaged
  $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
  $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
  $aesManaged.KeySize = 256
  $aesManaged.IV = $IV
  $aesManaged.key = $AESKey

  $encryptor = $aesManaged.CreateEncryptor()
  [byte[]]$encryptedData = $encryptor.TransformFinalBlock($Data,0,$Data.Length);
  $aesManaged.Dispose()

  return $encryptedData
}

function Get-HPPrivateKeyFromCert {
  [CmdletBinding()]
  param(
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
    [string]$Metadata,
    [string]$Passphrase
  )

  $iv = Get-HPPrivateRandomIV
  $salt = Get-HPPrivateRandomSalt
  $iterations = 100000
  $keysize = 32
  $aesKey = Get-HPPrivatePbkdf2Bytes $Passphrase $salt $iterations $keysize $Metadata

  $primes = Get-HPPrivatePrimesFromCert $Certificate
  $cipher = Get-HPPrivateDataEncryption $aesKey $primes $iv

  $encryptedPrimes = $salt + $iv + $cipher

  return [System.Convert]::ToBase64String($encryptedPrimes)
}

function Get-HPPrivateSureAdminLocalAccessKeyFromCert {
  [CmdletBinding()]
  param(
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$LocalAccessKey,
    [string]$KeyEnrollmentData
  )
  $modulus = Get-HPPrivatePublicKeyModulus $LocalAccessKey
  $pubKeyBase64 = [System.Convert]::ToBase64String($modulus)

  if ($KeyEnrollmentData) {
    $KeyEnrollmentDataBytes = [System.Text.Encoding]::UTF8.GetBytes($KeyEnrollmentData)
    $pubKeyBase64 += [System.Convert]::ToBase64String($KeyEnrollmentDataBytes)
  }

  return $pubKeyBase64
}

<#
.SYNOPSIS
  Extract key id from a certificate

.DESCRIPTION
  The key id is used by HP Sure Admin Key Management Service (KMS) for remote signing

.PARAMETER Certificate
  The X509Certificate2 certificate

.PARAMETER CertificateFile
  The certificate in PFX file

.PARAMETER CertificateFilePassword
  The password for the PFX file

.EXAMPLE
  Get-HPSureAdminKeyId -Certificate X509Certificate2

.EXAMPLE
  Get-HPSureAdminKeyId -CertificateFile mypfxcert.pfx
#>
function Get-HPSureAdminKeyId {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/get%e2%80%90hpsureadminkeyid")]
  param(
    [Parameter(ParameterSetName = "Cert",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

    [Parameter(ParameterSetName = "File",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$CertificateFile,

    [Parameter(ParameterSetName = "File",Mandatory = $false,Position = 1)]
    [string]$CertificateFilePassword
  )

  if ($PSCmdlet.ParameterSetName -eq "File") {
    if ($CertificateFilePassword) {
      [securestring]$CertificateFilePassword = ConvertTo-SecureString -AsPlainText -Force $CertificateFilePassword
      $Certificate = (Get-HPPrivatePublicKeyCertificateFromPFX -FileName $CertificateFile -password $CertificateFilePassword).Full
    }
    else {
      $Certificate = (Get-HPPrivatePublicKeyCertificateFromPFX -FileName $CertificateFile).Full
    }
  }

  $modulus = Get-HPPrivatePublicKeyModulus $Certificate
  $hashMod = Get-HPPrivateHash -Data $modulus
  return [System.Convert]::ToBase64String($hashMod)
}

function New-HPPrivateSureAdminEnrollmentJsonVer4 {
  [CmdletBinding()]
  param(
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
    [string]$AADRevocation,
    [string]$KeyName
  )

  # Get the pub key
  $hashModBase64 = Get-HPSureAdminKeyId -Certificate $Certificate

  # Get full cert
  $rawBytes = $Certificate.Export("Pfx","")
  $pvtKeyBase64 = [System.Convert]::ToBase64String($rawBytes)

  $data = [ordered]@{
    KeyEnrollmentData = $null
    Ver = "002"
    Type = "004"
    KeyId = $hashModBase64
    KeyAlgo = "06"
    PvtKey = $pvtKeyBase64
    KeyExp = "00000000"
    KeyName = $KeyName
    KeyBkupEn = "0"
    CanModKeyBkup = "0"
    CanExport = "0"
    AADRevocation = $AADRevocation
  }

  $json = $data | ConvertTo-Json -Compress
  return $json
}

function New-HPPrivateSureAdminEnrollmentJson {
  [CmdletBinding()]
  param(
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
    [string]$Model,
    [string]$SerialNumber,
    [string]$Passphrase,
    [string]$AADRevocation,
    [string]$KeyName
  )

  # Get the pub key
  $modulus = Get-HPPrivatePublicKeyModulus $Certificate
  $hashMod = Get-HPPrivateHash -Data $modulus
  $hashModBase64 = [System.Convert]::ToBase64String($hashMod)

  if (-not $KeyName) {
    # Get the private key
    $KeyName = Get-HPPrivateKeyNameFromCert $Certificate
  }
  if (-not $KeyName) {
    throw 'Certificate subject or parameter KeyName is required to identify the key in KMS server'
  }

  if ("" -eq $Passphrase) {
    $keyAlgo = "006"
    $ver = "002"
  }
  else {
    $keyAlgo = "007"
    $ver = "002"
  }

  $data = [ordered]@{
    Ver = $ver
    Type = "001"
    KeyId = $hashModBase64
    KeyAlgo = $keyAlgo
    PvtKey = $null
    KeyExp = "00000000"
    KeyName = $KeyName
    KeyBkupEn = "0"
    CanModKeyBkup = "0"
    CanExport = "0"
    AADRevocation = $AADRevocation
  }

  if ($Model) {
    $data.Model = $Model
  }
  if ($SerialNumber) {
    $data.SerNum = $SerialNumber
  }

  $json = $data | ConvertTo-Json -Compress
  $pvtKeyBase64 = Get-HPPrivateKeyFromCert -Certificate $Certificate -Metadata $json -Passphrase $Passphrase
  $data.PvtKey = $pvtKeyBase64

  $json = $data | ConvertTo-Json -Compress
  return $json
}

<#
.SYNOPSIS
  Generate a QR-Code for transferring the private key from a certificate file to the HP Sure Admin phone app

.DESCRIPTION
  This function extracts a private key from the provided certificate file and presents it in a form of QR-Code, which can be scanned with the HP Sure Admin phone app. Once scanned the app can be used for authorizing commands and BIOS setting changes.

  Security note: It is recommended to delete the QR-Code file once it is scanned with the app. Keeping the QR-Code stored locally in your computer is not a recommended production pattern since it contains sensitive information that can be used to authorize commands.

.PARAMETER LocalAccessKeyFile
  The path to the local access key, as a PFX file. If the PFX file is protected by a password (recommended), the LocalAccessKeyPassword parameter should also be provided.

.PARAMETER LocalAccessKeyPassword
  The local access key file password, if required.

.PARAMETER Model
  The computer model to be stored with the key in the phone app.

.PARAMETER SerialNumber
  The serial number to be stored with the key in the phone app.

.PARAMETER OutputFile
  Write the image to a specific file.
  If not specified a temporary file will be created.

.PARAMETER Format
  The format of your preference to save the QR-Code image file: Jpeg, Bmp, Png, Svg.

.PARAMETER ViewAs
  The 'Default' option creates a local file in your system and starts the default image viewer for presenting the QR-Code image.
  If 'Text' is provided, the QR-Code is displayed by using text characters in your console.
  If 'Image' is provided, the QR-Code image is displayed in the console temporary and once enter is pressed it disappears.
  If 'None' is provided, the QR-Code is not presented to the user. You may want to specify an OutputFile when using this option.

.PARAMETER Passphrase
  The password to protect QR-Code content.

.NOTES
  - Supported on Windows Power Shell v5.
  - An HP BIOS with HP Sure Admin support is required for applying the payloads generated by this function.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.EXAMPLE
  Convert-HPSureAdminCertToQRCode -LocalAccessKeyFile "$path\signing_key.pfx"

.EXAMPLE
  Convert-HPSureAdminCertToQRCode -Model "PC-Model" -SerialNumber "SN-1234" -LocalAccessKeyFile "$path\signing_key.pfx" -LocalAccessKeyPassword "s3cr3t"

.EXAMPLE
  Convert-HPSureAdminCertToQRCode -Model "PC-Model" -SerialNumber "SN-1234" -LocalAccessKeyFile "$path\signing_key.pfx" -Passphrase "s3cr3t" -ViewAs Image

.EXAMPLE
  Convert-HPSureAdminCertToQRCode -LocalAccessKeyFile "$path\signing_key.pfx" -Passphrase "s3cr3t" -Format "Svg"
#>
function Convert-HPSureAdminCertToQRCode {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/convert%e2%80%90hpsureadmincerttoqrcode")]
  param(
    [Parameter(Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$LocalAccessKeyFile,

    [Parameter(Mandatory = $false,Position = 1)]
    [string]$LocalAccessKeyPassword,

    [Parameter(Mandatory = $false,Position = 2)]
    [string]$Model,

    [Parameter(Mandatory = $false,Position = 3)]
    [string]$SerialNumber,

    [Parameter(Mandatory = $false,Position = 4)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(Mandatory = $false,Position = 5)]
    [ValidateSet('Jpeg','Bmp','Png','Svg')]
    [string]$Format = "Jpeg",

    [Parameter(Mandatory = $false,Position = 6)]
    [ValidateSet('None','Text','Image','Default')]
    [string]$ViewAs = "Default",

    [Parameter(Mandatory = $false,Position = 7)]
    [string]$Passphrase
  )

  if (-not $Model)
  {
    $Model = Get-HPBIOSSettingValue -Name "Product Name"
  }

  if (-not $SerialNumber)
  {
    $SerialNumber = Get-HPBIOSSettingValue -Name "Serial Number"
  }

  if ($LocalAccessKeyPassword) {
    [securestring]$LocalAccessKeyPassword = ConvertTo-SecureString -AsPlainText -Force $LocalAccessKeyPassword
    $cert = (Get-HPPrivatePublicKeyCertificateFromPFX -FileName $LocalAccessKeyFile -password $LocalAccessKeyPassword).Full
  }
  else {
    $cert = (Get-HPPrivatePublicKeyCertificateFromPFX -FileName $LocalAccessKeyFile).Full
  }

  $data = New-HPPrivateSureAdminEnrollmentJson -Certificate $cert -Model $Model -SerialNumber $SerialNumber -Passphrase $Passphrase
  New-HPPrivateQRCode -Data $data -OutputFile $OutputFile -Format $Format -ViewAs $ViewAs
}

<#
.SYNOPSIS
  Send a local access key in PFX format to HP Sure Admin Key Management Service (KMS)

.DESCRIPTION
  This function extracts a private key from the provided certificate file, generates a json for
  the central-managed enrollment process and sends it to the HP Sure Admin Key Management Service (KMS).
  The connection with KMS server requires to the user to authenticate with a valid Microsoft account.

.PARAMETER LocalAccessKeyFile
  The path to the local access key, as a PFX file. If the PFX file is protected by a password (recommended),
  the LocalAccessKeyPassword parameter should also be provided.

.PARAMETER LocalAccessKeyPassword
  The local access key file password, if required.

.PARAMETER KMSAppName
  The application name on Azure KMS server that will be used to compose the URI for uploading the key

.PARAMETER KMSUri
  The complete URI for uploading the key (I.e.: https://<KMSAppName>.azurewebsites.net/)

.PARAMETER AADGroup
  The group name in Azure Active Directory that will have access to the key

.PARAMETER KeyName
  Key name to identify the certificate, if not specified it will use the certificate subject

.PARAMETER CacheAccessToken
  This parameter should be specified when uploading multiple keys if the user don't want to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and won't be asked until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - An HP Sure Admin KMS server is required for using this feature.

.EXAMPLE
  Send-HPSureAdminLocalAccessKeyToKMS -LocalAccessKeyFile "$path\signing_key.pfx" -KMSUri "https://MyKMSURI.azurewebsites.net/" -AADGroup "MyAADGroupName"

.EXAMPLE
  Send-HPSureAdminLocalAccessKeyToKMS -LocalAccessKeyFile "$path\signing_key.pfx" -LocalAccessKeyPassword "pass" -KMSAppName "MyAppName" -AADGroup "MyAADGroupName"
#>
function Send-HPSureAdminLocalAccessKeyToKMS {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/send%e2%80%90hpsureadminlocalaccesskeytokms")]
  param(
    [Parameter(ParameterSetName = "KMSUri",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$LocalAccessKeyFile,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $false,Position = 1)]
    [string]$LocalAccessKeyPassword,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $true,Position = 2)]
    [string]$KMSUri,

    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $true,Position = 2)]
    [string]$KMSAppName,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $true,Position = 3)]
    [string]$AADGroup,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $false,Position = 4)]
    [switch]$CacheAccessToken,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $false,Position = 5)]
    [string]$KeyName
  )

  if (-not $KMSUri) {
    $KMSUri = "https://$KMSAppName.azurewebsites.net/"
  }

  if (-not $KMSUri.contains('api/uploadkey')) {
    if (-not $KMSUri.EndsWith('/')) {
      $KMSUri += '/'
    }
    $KMSUri += 'api/uploadkey'
  }

  if ($LocalAccessKeyPassword) {
    [securestring]$LocalAccessKeyPassword = ConvertTo-SecureString -AsPlainText -Force $LocalAccessKeyPassword
    $cert = (Get-HPPrivatePublicKeyCertificateFromPFX -FileName $LocalAccessKeyFile -password $LocalAccessKeyPassword).Full
  }
  else {
    $cert = (Get-HPPrivatePublicKeyCertificateFromPFX -FileName $LocalAccessKeyFile).Full
  }

  $jsonPayload = New-HPPrivateSureAdminEnrollmentJson -Certificate $cert -AADRevocation $AADGroup -KeyName $KeyName
  $accessToken = Get-HPPrivateSureAdminKMSAccessToken -CacheAccessToken:$CacheAccessToken
  $response,$responseContent = Send-HPPrivateKMSRequest -KMSUri $KMSUri -JsonPayload $jsonPayload -AccessToken $accessToken

  if ($response -ne "OK") {
    Invoke-HPPrivateKMSErrorHandle -ApiResponseContent $responseContent -Status $response
  }
}

<#
.SYNOPSIS
  Add a signing key in PFX format to HP Sure Admin Key Management Service (KMS)

.DESCRIPTION
  This function extracts a private key from the provided certificate file, generates a json for
  the central-managed enrollment process and sends it to the HP Sure Admin Key Management Service (KMS).
  The connection with KMS server requires to the user to authenticate with a valid Microsoft account.

.PARAMETER SigningKeyFile
  The path to the signing key, as a PFX file. If the PFX file is protected by a password (recommended),
  the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  The signing key file password, if required.

.PARAMETER Model
  The computer model to be stored with the key in the phone app.

.PARAMETER SerialNumber
  The serial number to be stored with the key in the phone app.

.PARAMETER KMSAppName
  The application name on Azure KMS server that will be used to compose the URI for uploading the key

.PARAMETER KMSUri
  The complete URI for uploading the key (I.e.: https://<KMSAppName>.azurewebsites.net/)

.PARAMETER AADGroup
  The group name in Azure Active Directory that will have access to the key

.PARAMETER CacheAccessToken
  This parameter should be specified when uploading multiple keys if the user don't want to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and won't be asked until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - An HP Sure Admin KMS server is required for using this feature.

.EXAMPLE
  Add-HPSureAdminSigningKeyToKMS -SigningKeyFile "$path\signing_key.pfx" -KMSUri "https://MyKMSURI.azurewebsites.net/" -AADGroup "MyAADGroupName"

.EXAMPLE
  Add-HPSureAdminSigningKeyToKMS -SigningKeyFile "$path\signing_key.pfx" -SigningKeyPassword "pass" -KMSAppName "MyAppName" -AADGroup "MyAADGroupName"
#>
function Add-HPSureAdminSigningKeyToKMS {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/add%e2%80%90hpsureadminsigningkeytokms")]
  param(
    [Parameter(ParameterSetName = "KMSUri",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $false,Position = 1)]
    [string]$SigningKeyPassword,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $true,Position = 3)]
    [string]$KMSUri,

    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $true,Position = 3)]
    [string]$KMSAppName,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $true,Position = 4)]
    [string]$AADGroup,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $true,Position = 5)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $true,Position = 5)]
    [string]$KeyName,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $false,Position = 6)]
    [switch]$CacheAccessToken
  )

  if (-not $KMSUri) {
    $KMSUri = "https://$KMSAppName.azurewebsites.net/"
  }
  if (-not $KMSUri.EndsWith('/')) {
    $KMSUri += '/'
  }
  $KMSUri += 'api/signingkeys'

  if ($SigningKeyPassword) {
    [securestring]$SigningKeyPassword = ConvertTo-SecureString -AsPlainText -Force $SigningKeyPassword
    $cert = (Get-HPPrivatePublicKeyCertificateFromPFX -FileName $SigningKeyFile -password $SigningKeyPassword).Full
  }
  else {
    $cert = (Get-HPPrivatePublicKeyCertificateFromPFX -FileName $SigningKeyFile).Full
  }

  $jsonPayload = New-HPPrivateSureAdminEnrollmentJsonVer4 -Certificate $cert -AADRevocation $AADGroup -KeyName $KeyName
  $accessToken = Get-HPPrivateSureAdminKMSAccessToken -CacheAccessToken:$CacheAccessToken
  $response,$responseContent = Send-HPPrivateKMSRequest -KMSUri $KMSUri -JsonPayload $jsonPayload -AccessToken $accessToken

  if ($response -ne "OK") {
    Invoke-HPPrivateKMSErrorHandle -ApiResponseContent $responseContent -Status $response
  }
}


<#
.SYNOPSIS
  Remove a signing key from HP Sure Admin Key Management Service (KMS)

.DESCRIPTION
  This function sends a HTTP request to remove the signing key from the HP Sure Admin Key Management Service (KMS).
  The connection with KMS server requires to the user to authenticate with a valid Microsoft account.

.PARAMETER SigningKeyId
  The key id encoded in base64 that is used in the server to locate the key.
  Use Get-HPSureAdminKeyId to extract the key id from a pfx certificate.

.PARAMETER KMSUri
  The complete URI for uploading the key (I.e.: https://<KMSAppName>.azurewebsites.net/)

.PARAMETER CacheAccessToken
  This parameter should be specified when uploading multiple keys if the user don't want to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and won't be asked until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - An HP Sure Admin KMS server is required for using this feature.

.EXAMPLE
  Remove-HPSureAdminSigningKeyFromKMS -SigningKeyId "<IdInBase64>" -KMSUri "https://MyKMSURI.azurewebsites.net/"
#>
function Remove-HPSureAdminSigningKeyFromKMS {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/remove%e2%80%90hpsureadminsigningkeyfromkms")]
  param(
    [Parameter(ParameterSetName = "KMSUri",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $true,Position = 0)]
    [string]$SigningKeyId,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $true,Position = 1)]
    [string]$KMSUri,

    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $true,Position = 1)]
    [string]$KMSAppName,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $false,Position = 2)]
    [switch]$CacheAccessToken
  )

  if (-not $KMSUri) {
    $KMSUri = "https://$KMSAppName.azurewebsites.net/"
  }
  if (-not $KMSUri.EndsWith('/')) {
    $KMSUri += '/'
  }
  $KMSUri += 'api/signingkeys'
  $KMSUri = "$KMSUri/$SigningKeyId"

  $accessToken = Get-HPPrivateSureAdminKMSAccessToken -CacheAccessToken:$CacheAccessToken
  $response,$responseContent = Send-HPPrivateKMSRequest -Method 'DELETE' -KMSUri $KMSUri -AccessToken $accessToken

  if ($response -ne "OK") {
    Invoke-HPPrivateKMSErrorHandle -ApiResponseContent $responseContent -Status $response
  }
}

function Invoke-HPPrivateKMSErrorHandle {
  [CmdletBinding()]
  param(
    [string]$ApiResponseContent,
    [string]$Status
  )

  if ($Status -eq 'Not Found') {
    throw "URL not found"
  }

  try {
    $response = $ApiResponseContent | ConvertFrom-Json
  }
  catch {
    Write-Verbose $ApiResponseContent
    throw 'Error code malformed'
  }

  if ($response -and $response.PSObject.Properties.Name -contains 'errorCode') {
    switch ($response.errorCode) {
      # Internal errors codes are suppressed
      default { throw "Error code ($_)" }
    }
  }

  Write-Verbose $ApiResponseContent
  throw "Wrong URL or error code malformed"
}

function Set-HPPrivateSureAdminKMSAccessToken {
  param(
    [string]$AccessToken
  )

  $path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("msalcache.dat")
  $AccessToken | Out-File -FilePath $path -Encoding utf8
  Write-Verbose "Access token saved to cache"
}

<#
.SYNOPSIS
  Clear the KMS access token

.DESCRIPTION
  This function clears the access token that is used for sending keys to HP Sure Admin Key Management Service (KMS).
  The token is stored locally in msalcache.dat file when -CacheAccessToken parameter is specified in KMS functions such as Send-HPSureAdminLocalAccessKeyToKMS

.EXAMPLE
  Clear-HPSureAdminKMSAccessToken
#>
function Clear-HPSureAdminKMSAccessToken {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/clear%e2%80%90hpsureadminkmsaccesstoken")]
  param(
  )

  $path = [System.IO.Path]::GetTempPath() + "hp/msalcache.dat"
  Remove-Item -Path $path -ErrorAction Ignore -Force
}

function Get-HPPrivateSureAdminKMSAccessToken {
  [CmdletBinding()]
  param(
    [switch]$CacheAccessToken
  )

  [string]$clientId = "40ef700f-b021-4fe4-81fe-b2536e9701c3"
  [string]$redirectUri = "http://localhost"
  [string[]]$scopes = ("https://graph.microsoft.com/User.Read", "https://graph.microsoft.com/GroupMember.Read.All")

  $clientApplicationBuilder = [Microsoft.Identity.Client.PublicClientApplicationBuilder]::Create($clientId)
  [void]$clientApplicationBuilder.WithRedirectUri($redirectUri)
  [void]$clientApplicationBuilder.WithClientId($clientId)
  $clientApplication = $clientApplicationBuilder.Build()

  if ($CacheAccessToken.IsPresent) {
    [TokenCacheHelper]::EnableSerialization($clientApplication.UserTokenCache)
    $authenticationResult = $null
    try {
      Write-Verbose "Trying to acquire token silently"
      [Microsoft.Identity.Client.IAccount[]]$accounts = $clientApplication.GetAccountsAsync().GetAwaiter().GetResult()
      if ($accounts -and $accounts.Count -gt 0) {
        $authenticationResult = $clientApplication.AcquireTokenSilent($scopes,$accounts[0]).ExecuteAsync().GetAwaiter().GetResult()
      }
    }
    catch {
      Write-Verbose "AcquireTokenSilent Exception: $($_.Exception)"
    }

    if ($authenticationResult) {
      return $authenticationResult.AccessToken
    }
  }
  else {
    Clear-HPSureAdminKMSAccessToken
  }

  # Aquire the access token using the interactive mode
  $aquireToken = $clientApplication.AcquireTokenInteractive($scopes)
  $parentWindow = [System.Diagnostics.Process]::GetCurrentProcess().MainWindowHandle
  [void]$aquireToken.WithParentActivityOrWindow($parentWindow)

  try {
    if ($PSEdition -eq 'Core') {
      # A timeout of two minutes is defined because netcore version of MSAL cannot detect if the user navigates away or simply closes the browser
      $timeout = New-TimeSpan -Minutes 2
      $tokenSource = New-Object System.Threading.CancellationTokenSource
      $taskAuthenticationResult = $aquireToken.ExecuteAsync($tokenSource.Token)
      $endTime = [datetime]::Now.Add($timeout)
      while (!$taskAuthenticationResult.IsCompleted) {
        if ([datetime]::Now -lt $endTime) {
          Start-Sleep -Seconds 1
        }
        else {
          $tokenSource.Cancel()
          throw [System.TimeoutException]"GetMsalTokenFailureOperationTimeout"
        }
      }
      $authenticationResult = $taskAuthenticationResult.Result
    }
    else {
      $authenticationResult = $aquireToken.ExecuteAsync().GetAwaiter().GetResult()
    }
  }
  catch {
    Write-Verbose $_.Exception
    if ($_.Exception.innerException -and $_.Exception.innerException.Message) {
      throw "Could not retrieve a valid access token: " + $_.Exception.innerException.Message
    }
    throw "Could not retrieve a valid access token: " + $_.Exception
  }

  if (-not $authenticationResult) {
    throw "Could not retrieve a valid access token"
  }

  return $authenticationResult.AccessToken
}

function Send-HPPrivateKMSRequest
{
  [CmdletBinding()]
  param(
    [string]$KMSUri,
    [string]$JsonPayload,
    [string]$AccessToken,
    [string]$Method = "POST"
  )

  Write-Verbose "HTTP Request $KMSUri : $Method => $jsonPayload"
  $request = [System.Net.HttpWebRequest]::Create($KMSUri)
  $request.Method = $Method
  $request.Timeout = -1
  $request.KeepAlive = $true
  $request.ReadWriteTimeout = -1
  $request.Headers.Add("Authorization","Bearer $AccessToken")
  if ($JsonPayload) {
    $content = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload)
    $request.ContentType = "application/json"
    $request.ContentLength = $content.Length
    $stream = $request.GetRequestStream()
    $stream.Write($content,0,$content.Length)
    $stream.Flush()
    $stream.Close()
  }

  try {
    [System.Net.WebResponse]$response = $request.GetResponse()
  }
  catch [System.Net.WebException]{
    Write-Verbose $_.Exception.Message
    $response = $_.Exception.Response
  }

  if ($response.PSObject.Properties.Name -match 'StatusDescription') {
    $statusDescription = $response.StatusDescription
    $receiveStream = $response.GetResponseStream()
    $streamReader = New-Object System.IO.StreamReader $receiveStream
    $responseContent = $streamReader.ReadToEnd()
    $streamReader.Close()
    $streamReader.Dispose()
    Write-Verbose $responseContent
  }

  $response.Close()
  return $statusDescription,$responseContent
}

<#
.SYNOPSIS
  Set one or multiple device permissions on the HP Sure Admin Key Management Service (KMS)

.DESCRIPTION
  Device permissions allow IT administrators to manage local access of specific devices without having to provision a unique LAK key for each one.
  This function sends an HTTP request for mapping a device serial number to a user email, or to an AAD group.
  The connection with the KMS server requires the user to authenticate with a valid Microsoft account.
  Existing mappings are modified by the last configuration uploaded.

.PARAMETER JsonFile
  The path to the Json file containing multiple device permissions.

.PARAMETER KMSAppName
  The application name on Azure KMS server that will be used to compose the URI for uploading the key

.PARAMETER KMSUri
  The complete URI for uploading the permissions (I.e.: https://<KMSAppName>.azurewebsites.net/)

.PARAMETER CacheAccessToken
  This parameter should be specified when uploading multiple keys if the user don't want to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and won't be asked until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - Supported on Windows Power Shell v7.
  - An HP Sure Admin KMS server is required for using this feature.

.EXAMPLE
  Set-HPSureAdminDevicePermissions -SerialNumber "XYZ123" -KMSAppName "MyAppName" -UserEmail "myuser@myappname.onmicrosoft.com"

.EXAMPLE
  Set-HPSureAdminDevicePermissions -SerialNumber "XYZ123" -KMSUri "https://MyKMSURI.azurewebsites.net/" -AADGroup "MyAADGroupName"

.EXAMPLE
  Set-HPSureAdminDevicePermissions -JsonFile MyJsonFile.json -KMSAppName "MyAppName" -CacheAccessToken
#>
function Set-HPSureAdminDevicePermissions {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/set%e2%80%90hpsureadmindevicepermissions")]
  param(
    [Parameter(ParameterSetName = "KMSUriJsonFile",Mandatory = $true,Position = 1)]
    [string]$KMSUri,

    [Parameter(ParameterSetName = "KMSAppNameJsonFile",Mandatory = $true,Position = 1)]
    [string]$KMSAppName,

    [Parameter(ParameterSetName = "KMSAppNameJsonFile",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "KMSUriJsonFile",Mandatory = $true,Position = 2)]
    [System.IO.FileInfo]$JsonFile,

    [Parameter(ParameterSetName = "KMSAppNameJsonFile",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "KMSUriJsonFile",Mandatory = $false,Position = 3)]
    [switch]$CacheAccessToken
  )

  if (-not $KMSUri) {
    $KMSUri = "https://$KMSAppName.azurewebsites.net/"
  }

  if (-not $KMSUri.EndsWith('/')) {
    $KMSUri += '/'
  }
  $KMSUri += 'api/devicekeymappings/upload'

  if ($JsonFile) {
    $f = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($JsonFile)
    [string]$jsonPayload = Get-Content -Raw -Path $f -ErrorAction Stop
  }

  $entries = ($jsonPayload | ConvertFrom-Json)
  foreach ($entry in $entries) {
    if (($entry.PSObject.Properties.Name -match 'userEmailAddress')) {
      if ($entry.userEmailAddress -ne '') {
        Invoke-HPPrivateValidateEmail -EmailAddress $entry.userEmailAddress
      }
    }
  }

  $accessToken = Get-HPPrivateSureAdminKMSAccessToken -CacheAccessToken:$CacheAccessToken
  if ($entries.Count -gt 1) {
    $jsonPayload = $entries | ConvertTo-Json -Compress
  }
  $response,$responseContent = Send-HPPrivateKMSRequest -KMSUri $KMSUri -JsonPayload $jsonPayload -AccessToken $accessToken

  if ($response -ne "OK") {
    Invoke-HPPrivateKMSErrorHandle -ApiResponseContent $responseContent -Status $response
  }
}

<#
.SYNOPSIS
  Add one device permissions to HP Sure Admin Key Management Service (KMS)

.DESCRIPTION
  Device permissions allow IT administrators to manage local access of specific devices without having to provision a unique LAK key for each one.
  This function sends an HTTP request for mapping a device serial number to a user email, or to an AAD group.
  The connection with the KMS server requires the user to authenticate with a valid Microsoft account.
  Existing mappings are modified by the last configuration uploaded.

.PARAMETER SerialNumber
  The serial number that identifies the device.

.PARAMETER KMSAppName
  The application name on Azure KMS server that will be used to compose the URI for uploading the key

.PARAMETER KMSUri
  The complete URI for uploading the permissions (I.e.: https://<KMSAppName>.azurewebsites.net/)

.PARAMETER AADGroup
  The group name in Azure Active Directory that will have access to the key

.PARAMETER UserEmail
  The user email in Azure Active Directory that will have access to the key

.PARAMETER CacheAccessToken
  This parameter should be specified when uploading multiple keys if the user don't want to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and won't be asked until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - Supported on Windows Power Shell v7.
  - An HP Sure Admin KMS server is required for using this feature.

.EXAMPLE
  Add-HPSureAdminDevicePermissions -SerialNumber "XYZ123" -KMSAppName "MyAppName" -UserEmail "myuser@myappname.onmicrosoft.com"

.EXAMPLE
  Add-HPSureAdminDevicePermissions -SerialNumber "XYZ123" -KMSUri "https://MyKMSURI.azurewebsites.net/" -AADGroup "MyAADGroupName"
#>
function Add-HPSureAdminDevicePermissions {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/add%e2%80%90hpsureadmindevicepermissions")]
  param(
    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "KMSUriAADGroup",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "KMSUriUserEmail",Mandatory = $true,Position = 1)]
    [string]$KMSUri,

    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "KMSAppNameAADGroup",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "KMSAppNameUserEmail",Mandatory = $true,Position = 1)]
    [string]$KMSAppName,

    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "KMSUriAADGroup",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "KMSAppNameAADGroup",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "KMSUriUserEmail",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "KMSAppNameUserEmail",Mandatory = $true,Position = 2)]
    [string]$SerialNumber,

    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "KMSUriAADGroup",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "KMSAppNameAADGroup",Mandatory = $true,Position = 3)]
    [string]$AADGroup,

    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "KMSUriUserEmail",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "KMSAppNameUserEmail",Mandatory = $true,Position = 3)]
    [string]$UserEmail,

    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "KMSUriAADGroup",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "KMSAppNameAADGroup",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "KMSUriUserEmail",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "KMSAppNameUserEmail",Mandatory = $false,Position = 4)]
    [switch]$CacheAccessToken
  )

  if (-not $KMSUri) {
    $KMSUri = "https://$KMSAppName.azurewebsites.net/"
  }

  if (-not $KMSUri.EndsWith('/')) {
    $KMSUri += '/'
  }
  $KMSUri += 'api/devicekeymappings'

  $params = @{
    SerialNumber = $SerialNumber
  }
  if ($UserEmail) {
    Invoke-HPPrivateValidateEmail -EmailAddress $UserEmail
    $params.UserEmail = $UserEmail
  }
  if ($AADGroup) {
    $params.AADGroup = $AADGroup
  }
  [string]$jsonPayload = New-HPPrivateSureAdminDeviceKeyMappingJson @params

  $accessToken = Get-HPPrivateSureAdminKMSAccessToken -CacheAccessToken:$CacheAccessToken
  $response,$responseContent = Send-HPPrivateKMSRequest -Method 'POST' -KMSUri $KMSUri -JsonPayload $jsonPayload -AccessToken $accessToken

  if ($response -ne "OK") {
    Invoke-HPPrivateKMSErrorHandle -ApiResponseContent $responseContent -Status $response
  }
}

<#
.SYNOPSIS
  Edit one existing device permissions to HP Sure Admin Key Management Service (KMS)

.DESCRIPTION
  Device permissions allow IT administrators to manage local access of specific devices without having to provision a unique LAK key for each one.
  This function sends an HTTP request for mapping a device serial number to a user email, or to an AAD group.
  The connection with the KMS server requires the user to authenticate with a valid Microsoft account.
  Existing mappings are modified by the last configuration uploaded.

.PARAMETER SerialNumber
  The serial number that identifies the device.

.PARAMETER KMSAppName
  The application name on Azure KMS server that will be used to compose the URI for uploading the key

.PARAMETER KMSUri
  The complete URI for uploading the permissions (I.e.: https://<KMSAppName>.azurewebsites.net/)

.PARAMETER AADGroup
  The group name in Azure Active Directory that will have access to the key

.PARAMETER UserEmail
  The user email in Azure Active Directory that will have access to the key

.PARAMETER eTag
  The eTag informed by the function Get-HPSureAdminDevicePermissions (see examples)

.PARAMETER CacheAccessToken
  This parameter should be specified when uploading multiple keys if the user don't want to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and won't be asked until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - Supported on Windows Power Shell v7.
  - An HP Sure Admin KMS server is required for using this feature.

.EXAMPLE
  Edit-HPSureAdminDevicePermissions -SerialNumber "XYZ123" -KMSAppName "MyAppName" -UserEmail "myuser@myappname.onmicrosoft.com" -eTag 'W/"datetime''2021-10-22T15%3A17%3A48.9645833Z''"'

.EXAMPLE
  $entry = Get-HPSureAdminDevicePermissions -KMSAppName 'MyAppName' -SerialNumber 'XYZ123'
  Edit-HPSureAdminDevicePermissions -SerialNumber "XYZ123" -KMSUri "https://MyKMSURI.azurewebsites.net/" -AADGroup "MyAADGroupName" -eTag $entry.eTag
#>
function Edit-HPSureAdminDevicePermissions {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/edit%e2%80%90hpsureadmindevicepermissions")]
  param(
    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "KMSUriAADGroup",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "KMSUriUserEmail",Mandatory = $true,Position = 1)]
    [string]$KMSUri,

    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "KMSAppNameAADGroup",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "KMSAppNameUserEmail",Mandatory = $true,Position = 1)]
    [string]$KMSAppName,

    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "KMSUriAADGroup",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "KMSAppNameAADGroup",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "KMSUriUserEmail",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "KMSAppNameUserEmail",Mandatory = $true,Position = 2)]
    [string]$SerialNumber,

    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "KMSUriAADGroup",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "KMSAppNameAADGroup",Mandatory = $true,Position = 3)]
    [AllowEmptyString()]
    [string]$AADGroup,

    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "KMSUriUserEmail",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "KMSAppNameUserEmail",Mandatory = $true,Position = 3)]
    [AllowEmptyString()]
    [string]$UserEmail,

    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $true,Position = 5)]
    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $true,Position = 5)]
    [Parameter(ParameterSetName = "KMSUriAADGroup",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "KMSAppNameAADGroup",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "KMSUriUserEmail",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "KMSAppNameUserEmail",Mandatory = $true,Position = 4)]
    [string]$eTag,

    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "KMSUriAADGroup",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "KMSAppNameAADGroup",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "KMSUriUserEmail",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "KMSAppNameUserEmail",Mandatory = $false,Position = 5)]
    [switch]$CacheAccessToken
  )

  if (-not $KMSUri) {
    $KMSUri = "https://$KMSAppName.azurewebsites.net/"
  }

  if (-not $KMSUri.EndsWith('/')) {
    $KMSUri += '/'
  }
  $KMSUri += 'api/devicekeymappings'
  $KMSUri = "$KMSUri/$SerialNumber"

  $params = @{
    eTag = $eTag
  }
  if ($PSBoundParameters.ContainsKey('UserEmail')) {
    if ($UserEmail -ne '') {
      Invoke-HPPrivateValidateEmail -EmailAddress $UserEmail
    }
    $params.UserEmail = $UserEmail
  }
  if ($PSBoundParameters.ContainsKey('AADGroup')) {
    $params.AADGroup = $AADGroup
  }
  [string]$jsonPayload = New-HPPrivateSureAdminDeviceKeyMappingJson @params

  $accessToken = Get-HPPrivateSureAdminKMSAccessToken -CacheAccessToken:$CacheAccessToken
  $response,$responseContent = Send-HPPrivateKMSRequest -Method 'PUT' -KMSUri $KMSUri -JsonPayload $jsonPayload -AccessToken $accessToken

  if ($response -ne "OK") {
    Invoke-HPPrivateKMSErrorHandle -ApiResponseContent $responseContent -Status $response
  }
}

function Invoke-HPPrivateValidateEmail {
  [CmdletBinding()]
  param(
    [string]$EmailAddress
  )

  try {
    New-Object System.Net.Mail.MailAddress ($EmailAddress) | Out-Null
  }
  catch {
    throw "Invalid user email address: $EmailAddress"
  }

  if (-not ($EmailAddress -match '^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')) {
    throw "Invalid user email address: $EmailAddress"
  }

  return
}

function New-HPPrivateSureAdminDeviceKeyMappingJson {
  [CmdletBinding()]
  param(
    [string]$SerialNumber,
    [string]$UserEmail,
    [string]$AADGroup,
    $ContinuationToken,
    [string]$eTag
  )

  $data = [ordered]@{}

  if ($SerialNumber) {
    $data.deviceId = $SerialNumber
  }

  if ($PSBoundParameters.ContainsKey('UserEmail')) {
    $data.userEmailAddress = $UserEmail
  }

  if ($PSBoundParameters.ContainsKey('AADGroup')) {
    $data.adGroupName = $AADGroup
  }

  if ($eTag) {
    $data.eTag = $eTag
  }

  if ($ContinuationToken) {
    $data.continuationToken = $ContinuationToken
  }

  $json = $data | ConvertTo-Json -Compress
  return $json
}

<#
.SYNOPSIS
  Get device permissions from the HP Sure Admin Key Management Service (KMS)

.DESCRIPTION
  Device permissions allow IT administrators to manage local access of specific devices without having to provision a unique LAK key for each one.
  This function retrieves from KMS the permissions set for the specified device serial number.
  The connection with the KMS server requires the user to authenticate with a valid Microsoft account.

.PARAMETER SerialNumber
  The serial number that identifies the device.

.PARAMETER KMSAppName
  The application name on Azure KMS server that will be used to compose the URI for uploading the key

.PARAMETER KMSUri
  The complete URI for uploading the permissions (I.e.: https://<KMSAppName>.azurewebsites.net/)

.PARAMETER CacheAccessToken
  This parameter should be specified when uploading multiple keys if the user don't want to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and won't be asked until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - Supported on Windows Power Shell v7.
  - An HP Sure Admin KMS server is required for using this feature.

.EXAMPLE
  Get-HPSureAdminDevicePermissions -SerialNumber "XYZ123" -KMSAppName "MyAppName"

.EXAMPLE
  Get-HPSureAdminDevicePermissions -SerialNumber "XYZ123" -KMSAppName "MyAppName" -CacheAccessToken
#>
function Get-HPSureAdminDevicePermissions {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/get%e2%80%90hpsureadmindevicepermissions")]
  param(
    [Parameter(ParameterSetName = "KMSUri",Mandatory = $true,Position = 1)]
    [string]$KMSUri,

    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $true,Position = 1)]
    [string]$KMSAppName,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $true,Position = 2)]
    [string]$SerialNumber,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $false,Position = 3)]
    [switch]$CacheAccessToken
  )

  if (-not $KMSUri) {
    $KMSUri = "https://$KMSAppName.azurewebsites.net/"
  }

  if (-not $KMSUri.EndsWith('/')) {
    $KMSUri += '/'
  }
  $KMSUri += 'api/devicekeymappings'
  $KMSUri = "$KMSUri/$SerialNumber"

  $accessToken = Get-HPPrivateSureAdminKMSAccessToken -CacheAccessToken:$CacheAccessToken
  $response,$responseContent = Send-HPPrivateKMSRequest -KMSUri $KMSUri -Method "GET" -AccessToken $accessToken

  if ($response -ne "OK") {
    Invoke-HPPrivateKMSErrorHandle -ApiResponseContent $responseContent -Status $response
  }

  $responseContent | ConvertFrom-Json
}

<#
.SYNOPSIS
  Search device permissions on HP Sure Admin Key Management Service (KMS)

.DESCRIPTION
  Device permissions allow IT administrators to manage local access of specific devices without having to provision a unique LAK key for each one.
  This function retrieves from KMS the permissions set for the specified device serial number.
  The connection with the KMS server requires the user to authenticate with a valid Microsoft account.

.PARAMETER SerialNumber
  The serial number that identifies the device.

.PARAMETER KMSAppName
  The application name on Azure KMS server that will be used to compose the URI for uploading the key

.PARAMETER KMSUri
  The complete URI for uploading the permissions (I.e.: https://<KMSAppName>.azurewebsites.net/)

.PARAMETER AADGroup
  The group name in Azure Active Directory that will have access to the key

.PARAMETER UserEmail
  The user email in Azure Active Directory that will have access to the key

.PARAMETER CacheAccessToken
  This parameter should be specified when uploading multiple keys if the user don't want to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and won't be asked until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - Supported on Windows Power Shell v7.
  - An HP Sure Admin KMS server is required for using this feature.

.EXAMPLE
  Search-HPSureAdminDevicePermissions -SerialNumber "XYZ123" -KMSAppName "MyAppName"

.EXAMPLE
  Search-HPSureAdminDevicePermissions -SerialNumber "XYZ123" -KMSAppName "MyAppName" -CacheAccessToken
#>
function Search-HPSureAdminDevicePermissions {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/search%e2%80%90hpsureadmindevicepermissions")]
  param(
    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "KMSUriAADGroup",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "KMSUriUserEmail",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "KMSUriSerialNumber",Mandatory = $true,Position = 1)]
    [string]$KMSUri,

    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "KMSAppNameAADGroup",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "KMSAppNameUserEmail",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "KMSAppNameSerialNumber",Mandatory = $true,Position = 1)]
    [string]$KMSAppName,

    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "KMSUriAADGroup",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "KMSAppNameAADGroup",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "KMSUriUserEmail",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "KMSAppNameUserEmail",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "KMSUriSerialNumber",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "KMSAppNameSerialNumber",Mandatory = $true,Position = 2)]
    [string]$SerialNumber,

    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "KMSUriAADGroup",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "KMSAppNameAADGroup",Mandatory = $true,Position = 3)]
    [string]$AADGroup,

    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "KMSUriUserEmail",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "KMSAppNameUserEmail",Mandatory = $true,Position = 3)]
    [string]$UserEmail,

    [Parameter(ParameterSetName = "KMSUriBoth",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "KMSAppNameBoth",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "KMSUriAADGroup",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "KMSAppNameAADGroup",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "KMSUriUserEmail",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "KMSAppNameUserEmail",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "KMSUriSerialNumber",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "KMSAppNameSerialNumber",Mandatory = $true,Position = 3)]
    [switch]$CacheAccessToken
  )

  if (-not $KMSUri) {
    $KMSUri = "https://$KMSAppName.azurewebsites.net/"
  }

  if (-not $KMSUri.EndsWith('/')) {
    $KMSUri += '/'
  }
  $KMSUri += 'api/devicekeymappings/search'

  $params = @{}
  if ($SerialNumber) {
    $params.SerialNumber = $SerialNumber
  }
  if ($UserEmail) {
    $params.UserEmail = $UserEmail
  }
  if ($AADGroup) {
    $params.AADGroup = $AADGroup
  }

  do {
    [string]$jsonPayload = New-HPPrivateSureAdminDeviceKeyMappingJson @params
    $accessToken = Get-HPPrivateSureAdminKMSAccessToken -CacheAccessToken:$CacheAccessToken
    $response,$responseContent = Send-HPPrivateKMSRequest -Method 'POST' -KMSUri $KMSUri -JsonPayload $jsonPayload -AccessToken $accessToken

    if ($response -ne "OK") {
      Invoke-HPPrivateKMSErrorHandle -ApiResponseContent $responseContent -Status $response
    }

    $response = ($responseContent | ConvertFrom-Json)
    $response.deviceKeyMappings

    $params.continuationToken = $response.continuationToken
  } while ($response.continuationToken)
}

<#
.SYNOPSIS
  Remove a device permission from the HP Sure Admin Key Management Service (KMS)

.DESCRIPTION
  Device permissions allow IT administrators to manage local access of specific devices without having to provision a unique LAK key for each one.
  This function removes from KMS the permissions set for the specified device serial number.
  The connection with the KMS server requires the user to authenticate with a valid Microsoft account.

.PARAMETER SerialNumber
  The serial number that identifies the device.

.PARAMETER KMSAppName
  The application name on Azure KMS server that will be used to compose the URI for uploading the key

.PARAMETER KMSUri
  The complete URI for uploading the permissions (I.e.: https://<KMSAppName>.azurewebsites.net/)

.PARAMETER CacheAccessToken
  This parameter should be specified when uploading multiple keys if the user don't want to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and won't be asked until it expires.

.NOTES
  - Supported on Windows Power Shell v5.
  - Supported on Windows Power Shell v7.
  - An HP Sure Admin KMS server is required for using this feature.

.EXAMPLE
  Remove-HPSureAdminDevicePermissions -SerialNumber "XYZ123" -KMSAppName "MyAppName"

.EXAMPLE
  Remove-HPSureAdminDevicePermissions -SerialNumber "XYZ123" -KMSAppName "MyAppName" -CacheAccessToken
#>
function Remove-HPSureAdminDevicePermissions {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/remove%e2%80%90hpsureadmindevicepermissions")]
  param(
    [Parameter(ParameterSetName = "KMSUri",Mandatory = $true,Position = 1)]
    [string]$KMSUri,

    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $true,Position = 1)]
    [string]$KMSAppName,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $true,Position = 2)]
    [string]$SerialNumber,

    [Parameter(ParameterSetName = "KMSUri",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "KMSAppName",Mandatory = $false,Position = 3)]
    [switch]$CacheAccessToken
  )

  if (-not $KMSUri) {
    $KMSUri = "https://$KMSAppName.azurewebsites.net/"
  }

  if (-not $KMSUri.EndsWith('/')) {
    $KMSUri += '/'
  }
  $KMSUri += 'api/devicekeymappings'
  $KMSUri = "$KMSUri/$SerialNumber"

  $accessToken = Get-HPPrivateSureAdminKMSAccessToken -CacheAccessToken:$CacheAccessToken
  $response,$responseContent = Send-HPPrivateKMSRequest -KMSUri $KMSUri -Method "DELETE" -AccessToken $accessToken

  if ($response -ne "OK") {
    Invoke-HPPrivateKMSErrorHandle -ApiResponseContent $responseContent -Status $response
  }
}

function New-HPPrivateQRCode {
  param(
    [string]$Data,
    [System.IO.FileInfo]$OutputFile,
    [ValidateSet('Jpeg','Bmp','Png','Svg')]
    [string]$Format = "Jpeg",
    [ValidateSet('None','Text','Image','Default')]
    [string]$ViewAs = "Default"
  )

  [void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

  $QRCode = [System.Byte[]]::CreateInstance([System.Byte],3918)
  switch (Test-OSBitness) {
    32 { $result = [DfmNativeQRCode]::create_qrcode32($data,$QRCode) }
    64 { $result = [DfmNativeQRCode]::create_qrcode64($data,$QRCode) }
  }

  $width = $height = $QRCode[0]
  $RGBBuffer = Convert-HPPrivateQRCodeToRGBBuffer -QRCode $QRCode

  [System.Drawing.Image]$img = New-HPPrivateImageFromRGBBuffer -RGBBuffer $RGBBuffer -Width $width -Height $height
  [System.Drawing.Image]$newImg = New-HPPrivateImageScale -Image $img -Width 250 -Height 250 -Border 10
  $img.Dispose()

  $path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
  if ($ViewAs -eq "Default" -and $OutputFile -eq $null)
  {
    $temp = [string][math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s")) + "." + $Format
    $path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($temp)
  }

  if ($OutputFile -or $ViewAs -eq "Default") {
    if ($Format -eq "Svg") {
      Invoke-HPPrivateWriteQRCodeToSvgFile -QRCode $QRCode -Path $path
    }
    else {
      $newImg.Save($path,[System.Drawing.Imaging.ImageFormat]::$Format)
    }
  }

  if ($ViewAs) {
    if ($ViewAs -eq "Text") {
      Invoke-HPPrivateWriteSmallQRCodeToConsole -QRCode $QRCode
    }
    elseif ($ViewAs -eq "Image") {
      Invoke-HPPrivateDisplayQRCodeForm -Image $newImg -Width $newImg.Width -Height $newImg.Height
    }
    elseif ($ViewAs -eq "Default") {
      Start-Process $path
      Write-Host "The file $path contains sensitive information, please delete it once you have scanned with HP Sure Admin phone app"
      if ($OutputFile -eq $null) {
        Start-Sleep -Seconds 5
        Remove-Item -Path $path -ErrorAction Ignore -Force
        Write-Host "The file was deleted, please specify an -OutputFile to keep it"
      }
    }
  }

  $newImg.Dispose()
}

function Get-HPPrivateQRCodeModule {
  param(
    [byte[]]$QRCode,
    [int]$X,
    [int]$Y
  )

  $size = $QRCode[0]
  if (0 -le $X -and $X -lt $size -and 0 -le $Y -and $Y -lt $size) {
    $index = $Y * $size + $X;
    $k = $QRCode[(($index -shr 3) + 1)]
    $i = $index -band 7
    if ((($k -shr $i) -band 1) -ne 0) {
      return $true
    }
  }

  return $false
}

function Convert-HPPrivateQRCodeToRGBBuffer {
  param(
    [byte[]]$QRCode
  )

  $len = $QRCode[0]
  $channels = 3
  $size = $len * $len * $channels #RGB color channels
  [byte[]]$RGBBuffer = [byte[]]::CreateInstance([byte],$size)
  for ($y = 0; $y -lt $len; $y++) {
    for ($x = 0; $x -lt $len; $x++) {
      $index = (($x * $len) + $y) * $channels
      if ((Get-HPPrivateQRCodeModule -QRCode $QRCode -X $x -Y $y) -eq $false) {
        $RGBBuffer[$index + 0] = 0xFF
        $RGBBuffer[$index + 1] = 0xFF
        $RGBBuffer[$index + 2] = 0xFF
      }
    }
  }

  return $RGBBuffer
}

function Invoke-HPPrivateWriteSmallQRCodeToConsole {
  param(
    [byte[]]$QRCode
  )

  $white = ([char]0x2588)
  $black = ' '
  $whiteBlack = ([char]0x2580)
  $blackWhite = ([char]0x2584)

  $size = $QRCode[0]
  Write-Host "`n"

  Write-Host -NoNewline "  "
  for ($x = 0; $x -lt $size + 2; $x++) {
    Write-Host -NoNewline $blackWhite
  }
  Write-Host ""

  for ($y = 0; $y -lt $size; $y += 2) {
    Write-Host -NoNewline "  "
    for ($x = -1; $x -lt $size + 1; $x++) {
      if (-not (Get-HPPrivateQRCodeModule -QRCode $QRCode -X $x -Y $y) -and
        -not (Get-HPPrivateQRCodeModule -QRCode $QRCode -X $x -Y ($y + 1))) {
        Write-Host -NoNewline $white
      }
      elseif (-not (Get-HPPrivateQRCodeModule -QRCode $QRCode -X $x -Y $y) -and
        (Get-HPPrivateQRCodeModule -QRCode $QRCode -X $x -Y ($y + 1))) {
        Write-Host -NoNewline $whiteBlack
      }
      elseif ((Get-HPPrivateQRCodeModule -QRCode $QRCode -X $x -Y $y) -and
        -not (Get-HPPrivateQRCodeModule -QRCode $QRCode -X $x -Y ($y + 1))) {
        Write-Host -NoNewline $blackWhite
      }
      else {
        Write-Host -NoNewline $black
      }
    }
    Write-Host ""
  }
  Write-Host "`n"
}

function Invoke-HPPrivateWriteQRCodeToSvgFile {
  param(
    [byte[]]$QRCode,
    [string]$Path
  )

  $border = 2
  $size = $QRCode[0]
  $content = ('<?xml version="1.0" encoding="UTF-8"?>' +
    '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">' +
    '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="-' + $border + ' -' + $border + ' ' + ($size + $border * 2) + ' ' + ($size + $border * 2) + '" stroke="none">' +
    '<rect width="90%" height="90%" fill="#FFFFFF" dominant-baseline="central" />' +
    '<path d="')

  for ($y = 0; $y -lt $size; $y++) {
    for ($x = 0; $x -lt $size; $x++) {
      if ((Get-HPPrivateQRCodeModule -QRCode $QRCode -X $x -Y $y) -eq $true) {
        if ($x -ne 0 -or $y -ne 0) {
          $content += ' '
        }
        $content += 'M' + $x + ',' + $y + 'h1v1h-1z'
      }
    }
  }
  $content += ('" fill="#000000" />' +
    '</svg>')

  $content | Out-File -FilePath $Path -Encoding utf8
}

function New-HPPrivateImageScale {
  param(
    [System.Drawing.Image]$Image,
    [int]$Width,
    [int]$Height,
    [int]$Border = 10
  )

  $newImage = New-Object System.Drawing.Bitmap (($Width + $border * 2),($Height + $border * 2),[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $graphics = [System.Drawing.Graphics]::FromImage($newImage)
  $graphics.Clear([System.Drawing.Color]::White)
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $graphics.DrawImage($Image,$border,$border,$Width,$Height)
  $graphics.Flush()
  $graphics.Dispose()

  return $newImage
}

function New-HPPrivateImageFromRGBBuffer {
  param(
    [byte[]]$RGBBuffer,
    [int]$Width,
    [int]$Height,
    [int]$Border = 10
  )

  $img = New-Object System.Drawing.Bitmap ($Width,$Height,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $rect = New-Object System.Drawing.Rectangle (0,0,$img.Width,$img.Height)
  $bmpData = $img.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::ReadWrite,$img.PixelFormat)
  $bufferStride = $img.Width * 3
  $targetStride = $bmpData.Stride
  $imgPtr = $bmpData.Scan0.ToInt64()

  for ($y = 0; $y -lt $img.Height; $y++) {
    [System.Runtime.InteropServices.Marshal]::Copy($RGBBuffer,$y * $bufferStride,[IntPtr]($imgPtr + $y * $targetStride),$bufferStride)
  }
  $img.UnlockBits($bmpData)

  return $img
}

function Get-HPPrivateConsoleFontSize {
  param()

  $width = 0
  switch (Test-OSBitness) {
    32 { $width = [DfmNativeQRCode]::get_console_font_width32() }
    64 { $width = [DfmNativeQRCode]::get_console_font_width64() }
  }

  $height = 0
  switch (Test-OSBitness) {
    32 { $height = [DfmNativeQRCode]::get_console_font_height32() }
    64 { $height = [DfmNativeQRCode]::get_console_font_height64() }
  }

  return $width,$height
}

function Get-HPPrivateScreenScale {
  param()

  $result = 0
  switch (Test-OSBitness) {
    32 { $result = [DfmNativeQRCode]::get_screen_scale32() }
    64 { $result = [DfmNativeQRCode]::get_screen_scale64() }
  }

  return $result
}

function Invoke-HPPrivateDisplayQRCodeForm {
  param(
    [System.Drawing.Image]$Image,
    [int]$Width,
    [int]$Height
  )
  [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

  $screenScale = Get-HPPrivateScreenScale
  $fontWidth,$fontHeight = (Get-HPPrivateConsoleFontSize)
  $cursorPosition = $host.UI.RawUI.CursorPosition.Y
  $windowHandle = [System.Diagnostics.Process]::GetCurrentProcess()[0].MainWindowHandle

  $imgSpace = $Height / $fontHeight
  for ($i = 0; $i -lt $imgSpace + 3; $i++) { Write-Host "" }
  Write-Host "Press enter once you have scanned the QR-Code..."
  #Write-Host "Screen Scale:" $screenScale, "Width:" $Width, "Height:" $Height, "fontHeight:" $fontHeight
  $newWindowPosition = $host.UI.RawUI.WindowPosition.Y

  [System.Windows.Forms.Application]::EnableVisualStyles()
  $form = New-Object System.Windows.Forms.Form
  $form.ControlBox = $false
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
  $form.ShowInTaskbar = $false
  $form.Width = $Width
  $form.Height = $Height
  $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
  $form.Add_KeyDown({
      if ($_.KeyCode -eq 'Escape' -or $_.KeyCode -eq 'Enter') {
        $form.Close()
      }
    })

  $pictureBox = New-Object System.Windows.Forms.PictureBox
  $pictureBox.Width = $Width
  $pictureBox.Height = $Height
  $pictureBox.Image = $Image
  $pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom

  $form.controls.Add($pictureBox);

  $rect = New-Object RECT
  $status = [Win32Window]::GetWindowRect($windowHandle,[ref]$rect)
  $windowWidth = $host.UI.RawUI.WindowSize.Width * $fontWidth
  $windowHeight = $host.UI.RawUI.WindowSize.Height * $fontHeight

  $topMargin = $fontHeight * (4 + ($cursorPosition - $newWindowPosition))
  $leftMargin = $fontWidth * $screenScale
  if (($Width + $leftMargin) -gt $windowWidth)
  {
    $form.Width = $windowWidth
  }

  $top = [int]($rect.Top + $topMargin)
  $left = [int]($rect.Left + $leftMargin)
  $form.Location = New-Object System.Drawing.Point ($left,$top)

  $caller = New-Object Win32Window -ArgumentList $windowHandle
  [void]$form.ShowDialog($caller)
}

# SIG # Begin signature block
# MIIaywYJKoZIhvcNAQcCoIIavDCCGrgCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCKqcKezr58qv0r
# ZyM2QIdPapiIYy6FzH4CYSPJ3DDvaqCCCm8wggUwMIIEGKADAgECAhAECRgbX9W7
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
# BgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCCAHEnV1up4qnLmzTA8HHM1Rst90E6+
# TLsjNAUaaKvd2zANBgkqhkiG9w0BAQEFAASCAQBeyqmeSF00hbAI79uXM66LbJJQ
# jBoVgYS7sFL14iKT73njHUvbHc1pbsmz8hteoD7zo4MkI7QfdlTojO8c7oap3Xfa
# 7z3fEy9Fz9uwdmXIBoPqyqebfBSAG5qsRecgoN/4D0BYFtgf/G36LgfhXPWGKD/u
# 2KQNan2Z4a5HsNFps6ngVQe0SG6s4DkJT95ENSiLGmBcd1ceBj3R2QGR+Igkjcav
# VFyj+BtR5hBAO3+/Ap3AcISmkTaoDbUvBEI+LonGmKmFhOBgFamZrB7dyUqNE8Ba
# /CXG+pLOFF9eNXewIqmTvh10zJTo4ILIyONHLKQK+Qf2/jjwdVR7DSUkVRc6oYIN
# fjCCDXoGCisGAQQBgjcDAwExgg1qMIINZgYJKoZIhvcNAQcCoIINVzCCDVMCAQMx
# DzANBglghkgBZQMEAgEFADB4BgsqhkiG9w0BCRABBKBpBGcwZQIBAQYJYIZIAYb9
# bAcBMDEwDQYJYIZIAWUDBAIBBQAEIIkUnitiDtox0glaHg8IMvVnfU+N2YF8SetP
# 8xoWcCkPAhEAqoncY+CmZ+VKTEJVdXtAwBgPMjAyMTExMjIxOTE5MDNaoIIKNzCC
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
# m/MwLwYJKoZIhvcNAQkEMSIEIN1mIknFwQ+/4gSKv2L+zuy1RRax6/gnijPPYdVw
# zWNmMDcGCyqGSIb3DQEJEAIvMSgwJjAkMCIEILMQkAa8CtmDB5FXKeBEA0Fcg+Mp
# K2FPJpZMjTVx7PWpMA0GCSqGSIb3DQEBAQUABIIBAAKXOG5Q6rhbo6mXVgoonkbD
# CrazqLGebDwB8dUiEDUR53rF4AS3OonFR1JnRdUj6d+LhRY0/2oBd2ZHeFZlOpzc
# bIUXXbfNkBuPh/YaBPzirbWctM0CEN2oaFE5OjdUFN982l5nq7+eaA+XPVD7g6nH
# L/7h0Vg+x7YCCqMtQjn5TqG3UXMig9uJ1J165uf/A5R8Ww0vzrwdhfs17WXhmctC
# aFeaYfIEIQVdPfLdvV+5I5+hmfAgpXg6MNNZi+5YVK9EleZMDJD440Rny5QwqsUy
# C7WLDxBxqYvaruoSY1SUg53TmuPmCzH6Bv1T3VJQQlH6E5CWCYvOq1b74MZSQk4=
# SIG # End signature block
