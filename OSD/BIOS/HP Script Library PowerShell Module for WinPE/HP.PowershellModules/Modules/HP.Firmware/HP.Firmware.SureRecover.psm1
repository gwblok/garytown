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


[Flags()] enum DeprovisioningTarget{
  AgentProvisioning = 1
  OSImageProvisioning = 2
  ConfigurationData = 4
  TriggerRecoveryData = 8
  ScheduleRecoveryData = 16
}


# Convert a BIOS value to a boolean
function ConvertValue {
  param($value)
  if ($value -eq "Enable" -or $value -eq "Yes") { return $true }
  $false
}


<#
.SYNOPSIS
    Get the current state of the HP Sure Recover feature

.DESCRIPTION
  This function returns the current state of the HP Sure Recover feature
  
.NOTES
  - Requires HP BIOS with HP Sure Recover support.
  - This command requires elevated privileges.

.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK 
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)

.EXAMPLE
  Get-HPSureRecoverState
#>
function Get-HPSureRecoverState
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPSureRecoverState")]
  param([switch]$All)
  $mi_result = 0
  $data = New-Object -TypeName surerecover_state_t
  $c = '[DfmNativeSureRecover]::get_surerecover_state' + (Test-OSBitness) + '([ref]$data,[ref]$mi_result);'
  $result = Invoke-Expression -Command $c
  Test-HPPrivateCustomResult -result 0x80000711 -mi_result $mi_result -Category 0x04 -Verbose:$VerbosePreference

  $fixed_version = "$($data.subsystem_version[0]).$($data.subsystem_version[1])"
  if ($fixed_version -eq "0.0") {
    Write-Verbose "Patched SURERECOVER version 0.0 to 1.0"
    $fixed_version = "1.0"
  }
  $SchedulerIsDisabled = ($data.schedule.window_size -eq 0)

  $RecoveryTimeBetweenRetries = ([uint32]$data.os_flags -shr 8) -band 0x0f
  $RecoveryNumberOfRetries = ([uint32]$data.os_flags -shr 12) -band 0x07
  if ($RecoveryNumberOfRetries -eq 0)
  {
    $RecoveryNumberOfRetries = "Infinite"
  }

  $obj = [ordered]@{
    Version = $fixed_version
    Nonce = $data.Nonce
    BIOSFlags = ($data.os_flags -band 0xff)
    ImageIsProvisioned = (($data.flags -band 2) -ne 0)
    AgentFlags = ($data.re_flags -band 0xff)
    AgentIsProvisioned = (($data.flags -band 1) -ne 0)
    RecoveryTimeBetweenRetries = $RecoveryTimeBetweenRetries
    RecoveryNumberOfRetries = $RecoveryNumberOfRetries
    schedule = New-Object -TypeName PSObject -Property @{
      DayOfWeek = $data.schedule.day_of_week
      hour = [uint32]$data.schedule.hour
      minute = [uint32]$data.schedule.minute
      WindowSize = [uint32]$data.schedule.window_size
    }
    ConfigurationDataIsProvisioned = (($data.flags -band 4) -ne 0)
    TriggerRecoveryDataIsProvisioned = (($data.flags -band 8) -ne 0)
    ScheduleRecoveryDataIsProvisioned = (($data.flags -band 16) -ne 0)
    SchedulerIsDisabled = $SchedulerIsDisabled
  }

  if ($all.IsPresent)
  {
    $ia = [ordered]@{
      url = (Get-HPBIOSSettingValue -Name "OS Recovery Image URL")
      UserName = (Get-HPBIOSSettingValue -Name "OS Recovery Image Username")
      #PublicKey = (Get-HPBiosSettingValue -name "OS Recovery Image Public Key")
      ProvisioningVersion = (Get-HPBIOSSettingValue -Name "OS Recovery Image Provisioning Version")
    }

    $aa = [ordered]@{
      url = (Get-HPBIOSSettingValue -Name "OS Recovery Agent URL")
      UserName = (Get-HPBIOSSettingValue -Name "OS Recovery Agent Username")
      #PublicKey = (Get-HPBiosSettingValue -name "OS Recovery Agent Public Key")
      ProvisioningVersion = (Get-HPBIOSSettingValue -Name "OS Recovery Agent Provisioning Version")
    }

    $Image = New-Object -TypeName PSObject -Property $ia
    $Agent = New-Object -TypeName PSObject -Property $aa

    $obj.Add("Image",$Image)
    $obj.Add("Agent",$Agent)
  }
  return New-Object -TypeName PSCustomObject -Property $obj
}

<#
.SYNOPSIS
    Get information about the HP Sure Recover embedded reimaging device.

.DESCRIPTION
  This function returns information about the embedded reimaging device for HP Sure Recover.

.NOTES
  The embedded reimaging device is an optional hardware feature, and if not present, the field Embedded Reimaging Device will be false.

.NOTES
  - Requires HP BIOS with HP Sure Recover support
  - Requires Embedded Reimaging device hardware option
  - This command requires elevated privileges.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)

.EXAMPLE
  Get-HPSureRecoverReimagingDeviceDetails
#>
function Get-HPSureRecoverReimagingDeviceDetails
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPSureRecoverReimagingDeviceDetails")]
  param()
  $result = @{}

  try {
    [int]$ImageVersion = Get-HPBIOSSettingValue -Name "OS Recovery Image Version"
    $result.Add("ImageVersion",$ImageVersion)

  }
  catch {}

  try {
    [int]$DriverVersion = Get-HPBIOSSettingValue -Name "OS Recovery Driver Version"
    $result.Add("DriverVersion",$DriverVersion)
  }
  catch {}

  $result.Add("Embedded Reimaging Device",(Test-Path variable:ImageVersion) -and (Test-Path variable:DriverVersion))
  $result
}

<#
.SYNOPSIS
  Configure the HP Sure Recover OS or Recovery image

.DESCRIPTION
  This function defines a custom HP Sure Recover OS or Recovery image.

  On return, the function writes the created payload to the pipeline, or to the file specified in the OutputFile parameter.
  This payload can then be passed to the Set-HPSecurePlatformPayload function.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload. Creating the payload and passing it to the Set-HPSecurePlatformPayload function via the pipeline is not a recommended production pattern.

.PARAMETER Image
  This controls whether this command will create a configuration payload for a Recovery Agent image or a Recovery OS  image. The parameter value may be 'agent' or 'os'.

.PARAMETER SigningKeyFile
  The path to the secure platform signing key, as a PFX file. If the PFX file is protected by a password (recommended), the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  The secure platform signing key file password, if required.

.PARAMETER SigningKeyCertificate
  The secure platform signing key certificate, as an X509Certificate object.

.PARAMETER ImageCertificateFile
  The path to the image signing certificate, as a PFX file. If the PFX file is protected by a password (recommended), the ImageCertificatePassword parameter should also be provided. Depending on the Image switch, this will be either the signing key file for the Agent or the OS image.
  ImageCertificateFile and PublicKeyFile are mutually exclusive.

.PARAMETER ImageCertificatePassword
  The image signing key file password, if required.

.PARAMETER ImageCertificate
  The image signing key certificate, as an X509Certificate object.  Depending on the Image switch, this will be either the signing key certificate for the Agent or the OS image.

.PARAMETER PublicKeyFile
  The image signing key, as the path to a base64-encoded RSA key (a PEM file).
  ImageCertificateFile and PublicKeyFile are mutually exclusive.

.PARAMETER PublicKey
  The image signing key, as an array of bytes, including modulus and exponent.
  This option is currently reserved for internal use.

.PARAMETER Nonce
  The operation nonce. In order to prevent replay attacks, the secure platform subsystem will only accept commands with a nonce greater or equal to the last nonce sent.
  If not specified, the nonce is inferred from the current local time. This works okay in most cases, however this approach has a resolution of seconds, so when doing high volume or parallel operations, it is possible to infer the same counter for two or more commands. In those cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER Version
  The operation version. Each new configuration payload must increment the last operation payload version, as available in the public WMI setting 'OS Recovery Image Provisioning Version'. If this switch is not provided, the function will read this public wmi setting and increment it, automatically.

.PARAMETER Username
  The username for accessing the url specified in the Url parameter, if any.

.PARAMETER Password
  The password for accessing the url specified in the Url parameter, if any.

.PARAMETER Url
  The url from where to download the image. If not specified, the default HP.COM location will be used. 

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
  - Requires HP BIOS with HP Sure Recover support 

.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)  

.EXAMPLE
   $payload = New-HPSureRecoverImageConfigurationPayload -SigningKeyFile "$path\signing_key.pfx" -Image OS -ImageKeyFile  `
                 "$path\os.pfx" -username my_http_user -password `s3cr3t`  -url "http://my.company.com"
   ...
   $payload | Set-HPSecurePlatformPayload
#>
function New-HPSureRecoverImageConfigurationPayload
{
  [CmdletBinding(DefaultParameterSetName = "SKFileCert_OSFilePem",HelpUri = "https://developers.hp.com/hp-client-management/doc/New%E2%80%90HPSureRecoverImageConfigurationPayload")]
  param(
    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $true,Position = 0)]
    [ValidateSet("os","agent")]
    [string]$Image,

    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $true,Position = 1)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $false,Position = 2)]
    [string]$SigningKeyPassword,

    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $true,Position = 3)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,


    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $true,Position = 1)]
    [Alias("ImageKeyFile")]
    [System.IO.FileInfo]$ImageCertificateFile,

    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 2)]
    [Alias("ImageKeyPassword")]
    [string]$ImageCertificatePassword,

    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $true,Position = 6)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $true,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $true,Position = 1)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$ImageCertificate,


    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $true,Position = 7)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $true,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $true,Position = 1)]
    [System.IO.FileInfo]$PublicKeyFile,


    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $true,Position = 8)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $true,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $true,Position = 1)]
    [byte[]]$PublicKey,


    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $false,Position = 2)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),


    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $false,Position = 3)]
    [uint16]$Version,

    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $false,Position = 4)]
    [string]$Username,

    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $false,Position = 5)]
    [string]$Password,

    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $false,Position = 6)]
    [uri]$Url = "",

    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $false,Position = 7)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $true,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $true,Position = 9)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $true,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $true,Position = 8)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $true,Position = 9)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $true,Position = 10)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $true,Position = 9)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $true,Position = 9)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $false,Position = 10)]
    [switch]$CacheAccessToken
  )

  Write-Verbose "Creating SureRecover Image provisioning payload"


  if ($PublicKeyFile -or $PublicKey) {
    $osk = Get-HPPrivatePublicKeyCoalesce -File $PublicKeyFile -key $PublicKey -Verbose:$VerbosePreference
  }
  else {
    $osk = Get-HPPrivateX509CertCoalesce -File $ImageCertificateFile -password $ImageCertificatePassword -cert $ImageCertificate -Verbose:$VerbosePreference
  }

  $OKBytes = $osk.Modulus

  $opaque = New-Object opaque4096_t
  $opaqueLength = 4096
  $mi_result = 0

  if (-not $Version) {
    if ($image -eq "os")
    {
      $Version = [uint16](Get-HPBIOSSettingValue "OS Recovery Image Provisioning Version") + 1
    }
    else {
      $Version = [uint16](Get-HPBIOSSettingValue "OS Recovery Agent Provisioning Version") + 1
    }
    Write-Verbose "New version number is $version"
  }

  $cmd = '[DfmNativeSureRecover]::get_surerecover_provisioning_opaque' + (Test-OSBitness) + '($Nonce, $Version, $OKBytes,$($OKBytes.Count),$Username, $Password, $($Url.ToString()), [ref]$opaque, [ref]$opaqueLength,  [ref]$mi_result);'
  $result = Invoke-Expression -Command $cmd
  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x04

  $payload = $opaque.raw[0..($opaqueLength - 1)]

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning_OSBytesCert" -or $PSCmdlet.ParameterSetName -eq "RemoteSigning_OSFileCert" -or $PSCmdlet.ParameterSetName -eq "RemoteSigning_OSBytesPem" -or $PSCmdlet.ParameterSetName -eq "RemoteSigning_OSFilePem") {
    $sig = Invoke-HPPrivateRemoteSignData -Data $payload -CertificateId $RemoteSigningServiceKeyID -KMSUri $RemoteSigningServiceURL -CacheAccessToken:$CacheAccessToken -Verbose:$VerbosePreference
  }
  else {
    $sk = Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeycertificate -Verbose:$VerbosePreference
    $sig = Invoke-HPPrivateSignData -Data $payload -Certificate $sk.Full -Verbose:$VerbosePreference
  }

  [byte[]]$out = $sig + $payload

  Write-Verbose "Building output document"
  $output = New-Object -TypeName PortableFileFormat
  $output.Data = $out

  if ($Image -eq "os") {
    $output.purpose = "hp:surerecover:provision:os_image"
  }
  else {
    $output.purpose = "hp:surerecover:provision:recovery_image"
  }

  Write-Verbose "Provisioning version will be $version"
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
  Deprovision HP Sure Recover

.DESCRIPTION
  This function create a payload to deprovision the HP Sure Recover feature, or parts thereof.

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

.PARAMETER RemoveOnly
     This parameter allows deprovisioning only specific parts of the Sure Recover subsystem. If not specified, the entire SureRecover is deprovisoned. Possible values are one or more of the following:

     - AgentProvisioning   - remove the Agent provisioning
     - OSImageProvisioning - remove the OS Image provisioning
     - ConfigurationData - remove HP SureRecover configuration data 
     - TriggerRecoveryData - remove the HP Sure Recover trigger definition
     - ScheduleRecoveryData - remove the HP Sure Recover schedule definition

.PARAMETER OutputFile
     Write the resulting output to the specified file, instead of writing it to the pipeline.

.PARAMETER RemoteSigningServiceKeyID
  The Signing Key ID to be used.

.PARAMETER RemoteSigningServiceURL
  The KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/).

.PARAMETER CacheAccessToken
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server, if not cached user have to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and user's credentials won't be asked again until it expires.

.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with HP Sure Recover support

.EXAMPLE
  New-HPSureRecoverDeprovisionPayload -SigningKeyFile sk.pfx
#>
function New-HPSureRecoverDeprovisionPayload
{
  [CmdletBinding(DefaultParameterSetName = "SF",HelpUri = "https://developers.hp.com/hp-client-management/doc/New%E2%80%90HPSureRecoverDeprovisionPayload")]
  param(
    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 0)]
    [string]$SigningKeyFile,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 1)]
    [string]$SigningKeyPassword,

    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 0)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [DeprovisioningTarget[]]$RemoveOnly,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 3)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 5)]
    [switch]$CacheAccessToken
  )

  Write-Verbose "Creating SureRecover deprovisioning payload"
  if ($RemoveOnly) {
    [byte]$target = 0
    $RemoveOnly | ForEach-Object { $target = $target -bor $_ }
    Write-Verbose "Will deprovision only $([string]$RemoveOnly)"
  }
  else
  {
    [byte]$target = 31 # all five bits
    Write-Verbose "No deprovisioning filter specified, will deprovision all SureRecover"
  }

  $payload = [BitConverter]::GetBytes($nonce) + $target

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    $sig = Invoke-HPPrivateRemoteSignData -Data $payload -CertificateId $RemoteSigningServiceKeyID -KMSUri $RemoteSigningServiceURL -CacheAccessToken:$CacheAccessToken -Verbose:$VerbosePreference
  }
  else {
    $sk = Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeycertificate -Verbose:$VerbosePreference
    $sig = Invoke-HPPrivateSignData -Data $payload -Certificate $sk.Full -Verbose:$VerbosePreference
  }

  Write-Verbose "Building output document"
  $output = New-Object -TypeName PortableFileFormat
  $output.Data = $sig + $payload
  $output.purpose = "hp:surerecover:deprovision"
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
    Set HP Sure Recover schedule

.DESCRIPTION
  This function create a payload to set a HP Sure Recover schedule.

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

.PARAMETER DayOfWeek
     Defines the day of the week for the schedule

.PARAMETER Hour
     Defines the hour value for the schedule

.PARAMETER Minute
     Defines the minute of the schedule

.PARAMETER WindowSize
     Defines a windows size for the schedule activation (in minutes), in case the exact configured schedule is
     missed. By default, the window is zero. The value may not be larger than 4 hours (240 minutes).
   
.PARAMETER OutputFile
     Write the resulting output to the specified file, instead of writing it to the pipeline.

.PARAMETER RemoteSigningServiceKeyID
  The Signing Key ID to be used.

.PARAMETER RemoteSigningServiceURL
  The KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/).

.PARAMETER CacheAccessToken
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server, if not cached user have to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and user's credentials won't be asked again until it expires.

.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with HP Sure Recover support

.EXAMPLE
  New-HPSureRecoverSchedulePayload -SigningKeyFile sk.pfx -DayOfWeek Sunday -Hour 2
#>
function New-HPSureRecoverSchedulePayload
{
  [CmdletBinding(DefaultParameterSetName = "SF",HelpUri = "https://developers.hp.com/hp-client-management/doc/New%E2%80%90HPSureRecoverSchedulePayload")]
  param(

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 0)]
    [string]$SigningKeyFile,

    [Parameter(ValueFromPipeline,ParameterSetName = "SB",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 1)]
    [string]$SigningKeyPassword,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 0)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 1)]
    [surerecover_day_of_week]$DayOfWeek,

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 2)]
    [ValidateRange(0,23)]
    [uint32]$Hour,

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 5)]
    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 3)]
    [ValidateRange(0,59)]
    [uint32]$Minute,

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 6)]
    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [ValidateRange(1,240)]
    [uint32]$WindowSize,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 5)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 6)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 7)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 8)]
    [switch]$CacheAccessToken
  )

  Write-Verbose "Creating SureRecover scheduling payload"
  $schedule_data = New-Object -TypeName surerecover_schedule_data_t

  Write-Verbose "Will set the SureRecover scheduler"
  $schedule_data.day_of_week = $DayOfWeek
  $schedule_data.hour = $Hour
  $schedule_data.minute = $Minute
  $schedule_data.window_size = $WindowSize

  $schedule = New-Object -TypeName surerecover_schedule_data_payload_t
  $schedule.schedule = $schedule_data
  $schedule.Nonce = $Nonce

  $cmd = New-Object -TypeName surerecover_schedule_payload_t
  $cmd.Data = $schedule
  [byte[]]$payload = (Convert-HPPrivateObjectToBytes -obj $schedule -Verbose:$VerbosePreference)[0]

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    $cmd.sig = Invoke-HPPrivateRemoteSignData -Data $payload -CertificateId $RemoteSigningServiceKeyID -KMSUri $RemoteSigningServiceURL -CacheAccessToken:$CacheAccessToken -Verbose:$VerbosePreference
  }
  else {
    $sk = Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeycertificate -Verbose:$VerbosePreference
    $cmd.sig = Invoke-HPPrivateSignData -Data $payload -Certificate $sk.Full -Verbose:$VerbosePreference
  }

  Write-Verbose "Building output document"
  $output = New-Object -TypeName PortableFileFormat

  $output.Data = (Convert-HPPrivateObjectToBytes -obj $cmd -Verbose:$VerbosePreference)[0]
  $output.purpose = "hp:surerecover:scheduler"
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
    Configure HP Sure Recover

.DESCRIPTION
  This function create a payload to configure HP Sure Recover

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

.PARAMETER SigningKeyModulus
     The secure platform signing key modulus

.PARAMETER Nonce
  The operation nonce. In order to prevent replay attacks, the secure platform subsystem will only accept commands with a nonce greater or equal to the last nonce sent.
  If not specified, the nonce is inferred from the current local time. This works okay in most cases, however this approach has a resolution of seconds, so when doing high volume or parallel operations, it is possible to infer the same counter for two or more commands. In those cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER BIOSFlags
      Defines the imaging flags to set. This parameter was previously named OSImageFlags, 

.PARAMETER AgentFlags
    Defines the agent flags to set
   
.PARAMETER OutputFile
     Write the resulting output to the specified file, instead of writing it to the pipeline.

.PARAMETER RemoteSigningServiceKeyID
  The Signing Key ID to be used.

.PARAMETER RemoteSigningServiceURL
  The KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/).

.PARAMETER CacheAccessToken
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server, if not cached user have to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and user's credentials won't be asked again until it expires.

.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with HP Sure Recover support

.EXAMPLE
  New-HPSureRecoverConfigurationPayload -SigningKeyFile sk.pfx -BIOSFlags WiFi -AgentFlags DRDVD
#>
function New-HPSureRecoverConfigurationPayload
{
  [CmdletBinding(DefaultParameterSetName = "SF",HelpUri = "https://developers.hp.com/hp-client-management/doc/New%E2%80%90HPSureRecoverConfigurationPayload")]
  param(

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 0)]
    [string]$SigningKeyFile,

    [Parameter(ValueFromPipeline,ParameterSetName = "SB",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 1)]
    [string]$SigningKeyPassword,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 0)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 1)]
    [Alias("OSImageFlags")]
    [surerecover_os_flags]$BIOSFlags,

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 5)]
    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 2)]
    [surerecover_re_flags]$AgentFlags,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 3)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 5)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 6)]
    [switch]$CacheAccessToken
  )

  $data = New-Object -TypeName surerecover_configuration_payload_t
  $data.os_flags = [uint32]$BIOSFlags
  $data.re_flags = [uint32]$AgentFlags
  $data.arp_counter = $Nonce

  $cmd = New-Object -TypeName surerecover_configuration_t
  $cmd.Data = $data

  [byte[]]$payload = (Convert-HPPrivateObjectToBytes -obj $data -Verbose:$VerbosePreference)[0]

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    $cmd.sig = Invoke-HPPrivateRemoteSignData -Data $payload -CertificateId $RemoteSigningServiceKeyID -KMSUri $RemoteSigningServiceURL -CacheAccessToken:$CacheAccessToken -Verbose:$VerbosePreference
  }
  else {
    $sk = Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeycertificate
    $cmd.sig = Invoke-HPPrivateSignData -Data $payload -Certificate $sk.Full -Verbose:$VerbosePreference
  }

  Write-Verbose "Building output document"
  $output = New-Object -TypeName PortableFileFormat
  $output.Data = (Convert-HPPrivateObjectToBytes -obj $cmd -Verbose:$VerbosePreference)[0]
  $output.purpose = "hp:surerecover:configure"
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
    Trigger HP Sure Recover events

.DESCRIPTION
  This function create a payload to trigger HP Sure Recover

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

.PARAMETER Set
    Indicates this is an operation to set the trigger information. This switch is default, and optional.

.PARAMETER Cancel
    Indicates this is an operation to cancel any existing trigger definition.


.PARAMETER ForceAfterReboot
    Defines how many reboots to count before applying the trigger. If not specified, defaults to 1 (next reboot).    

.PARAMETER PromptPolicy
    Defines the prompting policy. If not defined, it will default to prompt before recovery, and on error.

.PARAMETER ErasePolicy
    Defines the erase policy for the imaging process.

.PARAMETER OutputFile
     Write the resulting output to the specified file, instead of writing it to the pipeline.

.PARAMETER RemoteSigningServiceKeyID
  The Signing Key ID to be used.

.PARAMETER RemoteSigningServiceURL
  The KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/).

.PARAMETER CacheAccessToken
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server, if not cached user have to re-enter credentials on each call of this function.
  If specified, the access token is cached in msalcache.dat file and user's credentials won't be asked again until it expires.

.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with HP Sure Recover support

.EXAMPLE
  New-HPSureRecoverTriggerRecoveryPayload -SigningKeyFile sk.pfx
#>
function New-HPSureRecoverTriggerRecoveryPayload
{
  [CmdletBinding(DefaultParameterSetName = "SF_Schedule",HelpUri = "https://developers.hp.com/hp-client-management/doc/New%E2%80%90HPSureRecoverTriggerRecoveryPayload")]
  param(

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SF_Cancel",Mandatory = $true,Position = 0)]
    [string]$SigningKeyFile,

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = "SF_Cancel",Mandatory = $false,Position = 1)]
    [string]$SigningKeyPassword,

    [Parameter(ValueFromPipeline,ParameterSetName = "SB_Schedule",Mandatory = $true,Position = 0)]
    [Parameter(ValueFromPipeline,ParameterSetName = "SB_Cancel",Mandatory = $true,Position = 0)]
    [byte[]]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SF_Cancel",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SB_Schedule",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SB_Cancel",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $false,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning_Cancel",Mandatory = $false,Position = 0)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "SB_Schedule",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $false,Position = 1)]
    [switch]$Set,

    [Parameter(ParameterSetName = "SF_Cancel",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "SB_Cancel",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning_Cancel",Mandatory = $true,Position = 1)]
    [switch]$Cancel,

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "SB_Schedule",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $false,Position = 2)]
    [ValidateRange(1,7)]
    [byte]$ForceAfterReboot = 1,

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "SB_Schedule",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $false,Position = 3)]
    [surerecover_prompt_policy]$PromptPolicy = "PromptBeforeRecovery,PromptOnError",

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "SB_Schedule",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $false,Position = 4)]
    [surerecover_erase_policy]$ErasePolicy = "None",

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SB_Schedule",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SF_Cancel",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SB_Cancel",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning_Cancel",Mandatory = $false,Position = 2)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $true,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning_Cancel",Mandatory = $true,Position = 3)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $true,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning_Cancel",Mandatory = $true,Position = 4)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning_Cancel",Mandatory = $false,Position = 5)]
    [switch]$CacheAccessToken
  )

  $data = New-Object -TypeName surerecover_trigger_payload_t
  $data.arp_counter = $Nonce
  $data.bios_trigger_flags = 0

  $output = New-Object -TypeName PortableFileFormat

  if ($Cancel.IsPresent)
  {
    Write-Verbose "Creating payload to cancel trigger"
    $output.purpose = "hp:surerecover:trigger"
    $data.bios_trigger_flags = 0
    $data.re_trigger_flags = 0
  }
  else {
    Write-Verbose ("Creating payload to set trigger")
    $output.purpose = "hp:surerecover:trigger"
    $data.bios_trigger_flags = [uint32]$ForceAfterReboot
    $data.re_trigger_flags = [uint32]$PromptPolicy
    $data.re_trigger_flags = ([uint32]$ErasePolicy -shl 4) -bor $data.re_trigger_flags
  }

  $cmd = New-Object -TypeName surerecover_trigger_t
  $cmd.Data = $data

  [byte[]]$payload = (Convert-HPPrivateObjectToBytes -obj $data -Verbose:$VerbosePreference)[0]

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning_Schedule" -or $PSCmdlet.ParameterSetName -eq "RemoteSigning_Cancel") {
    $cmd.sig = Invoke-HPPrivateRemoteSignData -Data $payload -CertificateId $RemoteSigningServiceKeyID -KMSUri $RemoteSigningServiceURL -CacheAccessToken:$CacheAccessToken -Verbose:$VerbosePreference
  }
  else {
    $sk = Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SIgningKeyPassword -cert $SigningKeycertificate -Verbose:$VerbosePreference
    $cmd.sig = Invoke-HPPrivateSignData -Data $payload -Certificate $sk.Full -Verbose:$VerbosePreference
  }
  Write-Verbose "Building output document with nonce $([BitConverter]::GetBytes($nonce))"

  $output.Data = (Convert-HPPrivateObjectToBytes -obj $cmd -Verbose:$VerbosePreference)[0]
  Write-Verbose "Sending document of size $($output.data.length)"
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
    Flag an embedded device for update, where available.

.DESCRIPTION
    This triggers the embedded reimaging device for update. If the hardware option is not present, the
    function will throw a NotSupportedException.


.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)
  
  
.NOTES
  - Requires HP BIOS with HP Sure Recover support
  - Requires Embedded Reimaging device hardware option

.EXAMPLE
  Invoke-HPSureRecoverTriggerUpdate
#>
function Invoke-HPSureRecoverTriggerUpdate
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Invoke%E2%80%90HPSureRecoverTriggerUpdate")]
  param()

  $mi_result = 0
  $cmd = '[DfmNativeSureRecover]::raise_surerecover_service_event_opaque' + (Test-OSBitness) + '($null, $null, [ref]$mi_result);'
  $result = Invoke-Expression -Command $cmd
  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x04
}


# SIG # Begin signature block
# MIIaygYJKoZIhvcNAQcCoIIauzCCGrcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCKLLgRkpbxECfG
# U1RQI6m+12VY9G88jLuxzQ1+vMpL0aCCCm8wggUwMIIEGKADAgECAhAECRgbX9W7
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
# BgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCCU0lAnIyPf8CVlYKZNizMknhAkRTB2
# LAme7q2baAPtpzANBgkqhkiG9w0BAQEFAASCAQAAavKY/9DiIXEr6GtUF/PVCvG/
# XY4aeSVQSIWk7cyJr5c+IzLU8zyq1hB2uqn3Ls8mtKDcZ5Ul9aWVdLGdZOJ/4ADc
# +rTCDv3syuDAGUZ4EvsJQb9xzYI0EmOvKLoqvLN/1egd22R+xwQs2pbDgAkJptB/
# JSS4iJtbXVYk5KTN47VkTVGTGDSmjHu4spmTclIcKJtMMLrisZ8blF/MWwvbzBmL
# P1SxYzf4F4C6dSRcoD+tKVvr8DLLUSvxEcYmu4ejK/AP2ujcp3RVmZg7W0oP0rmZ
# bdsvFZwefrYmpkzkWtMcAKxoCdVjrF5cRGyXBMldbI6Lw8xurJzIzWh4tK0loYIN
# fTCCDXkGCisGAQQBgjcDAwExgg1pMIINZQYJKoZIhvcNAQcCoIINVjCCDVICAQMx
# DzANBglghkgBZQMEAgEFADB3BgsqhkiG9w0BCRABBKBoBGYwZAIBAQYJYIZIAYb9
# bAcBMDEwDQYJYIZIAWUDBAIBBQAEIGBSKW0FyKENE6aGYBVzQhpVL1BPEFwnDx98
# vkss8dhUAhBt83AHHF8+mIe4WVDviZgWGA8yMDIxMTEyMjE5MTkwM1qgggo3MIIE
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
# 8zAvBgkqhkiG9w0BCQQxIgQgyn3FctD8DjLqKFDpwu4DA/lt5W9g/a4ijJ5CWlgI
# Sh8wNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgsxCQBrwK2YMHkVcp4EQDQVyD4ykr
# YU8mlkyNNXHs9akwDQYJKoZIhvcNAQEBBQAEggEADDayg16WsR52BFSp9C3IZrFu
# EPVS2Hfo2H1ElV1HtRbehQat114sM1i32E2uTAcy/WhoaFt6Te4dBGKEwJx9ULSQ
# bSVg8oHE+cGvi9oztgZDJdpb/HAtjpZ5XbGcZigGY6p5iz3Dew4piMf3tsToKrDh
# NfE6eolK3/fgamXqgAoLbZXT0Orj7Vu7qGGMPWzqJBd2fq43Li1wS/6COlEr6EJh
# RlUbDoWk1RNZ3dK7Yz7HQYy219o0Rrd/Oj79hlgdYYqNuU+F7CerN6vuzax8cCp3
# b0YDjjPOUtNWGRt1sHRQnyzSN/Ymc+soxKvz7pqEJ/1pbKGEUjPZ4S/BCyGzfw==
# SIG # End signature block
