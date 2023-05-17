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


Add-Type -AssemblyName System.Web
Set-StrictMode -Version 5.0
#requires -Modules "HP.Private"

Add-Type -TypeDefinition @'
  public enum BiosUpdateCriticality
  {
    Recommended=0,
    Critical=1
  }
'@

<#
.SYNOPSIS
  Retrieve an HP BIOS Setting object by name

.DESCRIPTION
  Read an HP-specific BIOS setting, identified by the specified name.

.PARAMETER Name
  The name of the setting to retrieve. This parameter is mandatory, and has no default.

.PARAMETER Format
  This parameter allows to specify the formatting of the result. Possible values are:

    * bcu: format as HP Bios Config Utility input format
    * csv: format as a comma-separated values list
    * xml: format as XML
    * json: format as Json

  If not specified, the default PowerShell formatting is used.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.NOTES
  Required HP BIOS.

.EXAMPLE
  Get-HPBIOSSetting -Name "Serial Number" -Format BCU
#>
function Get-HPBIOSSetting {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPBIOSSetting")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $true)]
    [Parameter(ParameterSetName = 'ReuseSession',Position = 0,Mandatory = $true)]
    $Name,
    [Parameter(ParameterSetName = 'NewSession',Position = 1,Mandatory = $false)]
    [Parameter(ParameterSetName = 'ReuseSession',Position = 1,Mandatory = $false)]
    [ValidateSet('Xml','JSon','BCU','CSV')]
    $Format,
    [Parameter(ParameterSetName = 'NewSession',Position = 2,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 3,Mandatory = $true)]
    [CimSession]$CimSession
  )

  $ns = getNamespace
  Write-Verbose "Reading HP BIOS Setting '$Name' from $ns on '$ComputerName'"
  $result = $null

  $params = @{
    Class = "HP_BIOSSetting"
    Namespace = $ns
    Filter = "Name='$name'"
  }

  if ($PSCmdlet.ParameterSetName -eq 'NewSession') {
    $params.CimSession = newCimSession -Target $ComputerName
  }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') {
    $params.CimSession = $CimSession
  }

  try {
    $result = Get-CimInstance @params -ErrorAction stop
  } catch [Microsoft.Management.Infrastructure.CimException]
  {
    if ($_.Exception.Message.trim() -eq "Access denied")
    {
      throw [System.UnauthorizedAccessException]"Access denied: Please ensure you have the rights to perform this operation."
    }
    throw [System.NotSupportedException]"$($_.Exception.Message): Please ensure this is a supported HP device."
  }


  if (-not $result) {
    $Err = "Setting not found: '" + $name + "'"
    throw [System.Management.Automation.ItemNotFoundException]$Err
  }
  Add-Member -InputObject $result -Force -NotePropertyName "Class" -NotePropertyValue $result.CimClass.CimClassName | Out-Null
  Write-Verbose "Retrieved HP BIOS Setting '$name' ok."

  switch ($format) {
    { $_ -eq 'csv' } { return convertSettingToCSV ($result) }
    { $_ -eq 'xml' } { return convertSettingToXML ($result) }
    { $_ -eq 'bcu' } { return convertSettingToBCU ($result) }
    { $_ -eq 'json' } { return convertSettingToJSON ($result) }
    default { return $result }
  }
}


<#
 .SYNOPSIS
  Get device UUID

.DESCRIPTION
  This function gets the system UUID via standard OS providers. This should normally match the result from Get-HPBIOSUUID.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Get-HPDeviceUUID
#>
function Get-HPDeviceUUID () {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPDeviceUUID")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 1,Mandatory = $true)]
    [CimSession]$CimSession
  )
  $params = @{
    ClassName = 'Win32_ComputerSystemProduct'
    Namespace = 'root\cimv2'
  }
  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }
  $obj = Get-CimInstance @params -ErrorAction stop
  ([string](getWmiField $obj "UUID")).trim().ToUpper()
}


<#
 .SYNOPSIS
  Get BIOS UUID

.DESCRIPTION
  This function gets the system UUID from the BIOS. This should normally match the result from Get-HPDeviceUUID.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Get-HPBIOSUUID
#>
function Get-HPBIOSUUID {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPBIOSUUID")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 1,Mandatory = $true)]
    [CimSession]$CimSession
  )

  $params = @{ Name = 'Universally Unique Identifier (UUID)' }
  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }

  $obj = Get-HPBIOSSetting @params -ErrorAction stop
  if ($obj.Value -match '-') {
    return (getFormattedBiosSettingValue $obj)
  }
  else {
    $raw = ([guid]::new($obj.Value)).ToByteArray()
    $raw[0],$raw[3] = $raw[3],$raw[0]
    $raw[1],$raw[2] = $raw[2],$raw[1]
    $raw[4],$raw[5] = $raw[5],$raw[4]
    $raw[6],$raw[7] = $raw[7],$raw[6]
    return ([guid]::new($raw)).ToString().ToUpper().trim()
  }
}


<#
.SYNOPSIS
  Get the current BIOS version

.DESCRIPTION
  This function gets the current BIOS version. If available, and the -includeFamily switch is specified, the BIOS family is also included.

.PARAMETER IncludeFamily
  Include BIOS family in the result

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Get-HPBIOSVersion
#>
function Get-HPBIOSVersion {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPBIOSVersion")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $false)]
    [Parameter(ParameterSetName = 'ReuseSession',Position = 0,Mandatory = $false)]
    [switch]$IncludeFamily,
    [Parameter(ParameterSetName = 'NewSession',Position = 1,Mandatory = $false)]
    [Parameter(Position = 1,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 2,Mandatory = $true)]
    [CimSession]$CimSession
  )

  $params = @{
    ClassName = 'Win32_BIOS'
    Namespace = 'root\cimv2'
  }
  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }
  $obj = Get-CimInstance @params -ErrorAction stop
  $verfield = getWmiField $obj "SMBIOSBIOSVersion"
  $ver = $null

  Write-Verbose "Received object with $verfield"
  try {
    $ver = extractBIOSVersion $verfield
  }
  catch { throw [System.InvalidOperationException]"The BIOS version on this system could not be parsed. This BIOS may not be supported." }
  if ($includeFamily.IsPresent) { $result = $ver + " " + $verfield.Split()[0] }
  else { $result = $ver }
  $result.TrimStart("0").trim()
}

<#
.SYNOPSIS
  Get the BIOS author (manufacturer)

.DESCRIPTION
  This function gets the BIOS manufacturer via the Win32_BIOS WMI class. In some cases, the BIOS manufacturer may be different than the device manufacturer.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Get-HPBIOSAuthor
#>
function Get-HPBIOSAuthor {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPBIOSAuthor")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 1,Mandatory = $true)]
    [CimSession]$CimSession
  )
  $params = @{
    ClassName = 'Win32_BIOS'
    Namespace = 'root\cimv2'
  }
  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }
  $obj = Get-CimInstance @params -ErrorAction stop
  ([string](getWmiField $obj "Manufacturer")).trim()

}

<#
.SYNOPSIS
  Get the Device manufacturer

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.DESCRIPTION
  This function gets the device manufacturer via standard Windows WMI providers. In some cases, the BIOS manufacturer may be different than the device manufacturer.

.EXAMPLE
  Get-HPDeviceManufacturer
#>
function Get-HPDeviceManufacturer {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPDeviceManufacturer")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 1,Mandatory = $true)]
    [CimSession]$CimSession
  )
  $params = @{
    ClassName = 'Win32_ComputerSystem'
    Namespace = 'root\cimv2'
  }
  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }
  $obj = Get-CimInstance @params -ErrorAction stop
  ([string](getWmiField $obj "Manufacturer")).trim()
}

<#
.SYNOPSIS
  Get the device serial number

.DESCRIPTION
  Get the system serial number via Windows WMI. This command is equivalent to reading the SerialNumber property in the Win32_BIOS WMI class.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Get-HPDeviceSerialNumber
#>
function Get-HPDeviceSerialNumber {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPDeviceSerialNumber")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 1,Mandatory = $true)]
    [CimSession]$CimSession
  )
  $params = @{
    ClassName = 'Win32_BIOS'
    Namespace = 'root\cimv2'
  }
  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }
  $obj = Get-CimInstance @params -ErrorAction stop

  ([string](getWmiField $obj "SerialNumber")).trim()
}

<#
.SYNOPSIS
  Get the device model string, which is the marketing name of the device.

.DESCRIPTION
  Get the device model string, which is the marketing name of the device.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Get-HPDeviceModel
#>
function Get-HPDeviceModel {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPDeviceModel")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 1,Mandatory = $true)]
    [CimSession]$CimSession
  )
  $params = @{
    ClassName = 'Win32_ComputerSystem'
    Namespace = 'root\cimv2'
  }

  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }
  $obj = Get-CimInstance @params -ErrorAction stop

  ([string](getWmiField $obj "Model")).trim()
}




<#
.SYNOPSIS
  Get the device PartNumber (or SKU)

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.DESCRIPTION
  Get the device part number for the current device. This function is equivalent to reading the field SystemSKUNumber from the WMI class Win32_ComputerSystem.

.EXAMPLE
  Get-HPDevicePartNumber
#>
function Get-HPDevicePartNumber {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPDevicePartNumber")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 1,Mandatory = $true)]
    [CimSession]$CimSession
  )
  $params = @{
    ClassName = 'Win32_ComputerSystem'
    Namespace = 'root\cimv2'
  }

  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }
  $obj = Get-CimInstance @params -ErrorAction stop

  ([string](getWmiField $obj "SystemSKUNumber")).trim().ToUpper()
}


<#
.SYNOPSIS
  Get the product ID

.DESCRIPTION
  This product ID  (Platform ID) is a 4-character hexadecimal string. It corresponds to the Product field in the Win32_BaseBoard WMI class.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Get-HPDeviceProductID
#>
function Get-HPDeviceProductID {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPDeviceProductID")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 1,Mandatory = $true)]
    [CimSession]$CimSession
  )
  $params = @{
    ClassName = 'Win32_BaseBoard'
    Namespace = 'root\cimv2'
  }

  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }

  $obj = Get-CimInstance @params -ErrorAction stop
  ([string](getWmiField $obj "Product")).trim().ToUpper()
}


<#
.SYNOPSIS
  Get the device asset tag

.DESCRIPTION
  Retrieves the asset tag for a device (also called the Asset Tracking Number).
  Some computers may have a blank asset tag, others may have the asset tag pre-populated with the serial number value.

.PARAMETER ComputerName
  Alias -Target. Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Get-HPDeviceAssetTag
#>
function Get-HPDeviceAssetTag {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPDeviceAssetTag")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 1,Mandatory = $true)]
    [CimSession]$CimSession
  )

  $params = @{
    Name = 'Asset Tracking Number'
  }
  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }

  $obj = Get-HPBIOSSetting @params -ErrorAction stop
  getFormattedBiosSettingValue $obj
}


<#
.SYNOPSIS
  Get the value of a BIOS setting.

.DESCRIPTION
  This function retrieves the value of a BIOS setting. Whereas the Get-HPBIOSSetting retrieves all setting fields, Get-HPBIOSSettingValue retrieves only the setting's value.

.NOTES
  Requires HP BIOS.

.PARAMETER name
  The name of the setting to retrieve

.PARAMETER ComputerName
  Alias -Target. Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Get-HPBIOSSettingValue -Name 'Asset Tracking Number'
#>
function Get-HPBIOSSettingValue {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPBIOSSettingValue")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $true)]
    [Parameter(ParameterSetName = 'ReuseSession',Position = 0,Mandatory = $true)]
    [string]$Name,
    [Parameter(ParameterSetName = 'NewSession',Position = 1,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 2,Mandatory = $false)]
    [CimSession]$CimSession
  )
  $params = @{
    Name = $Name
  }
  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }

  $obj = Get-HPBIOSSetting @params
  if ($obj) {
    getFormattedBiosSettingValue $obj
  }


}


<#
.SYNOPSIS
  Retrieve all BIOS settings

.DESCRIPTION
  Retrieve all BIOS settings on a machine, either as native objects, or as a specified format.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER Format
  This parameter allows to specify the formatting of the result. Possible values are:

    * bcu: format as HP Bios Config Utility input format
    * csv: format as a comma-separated values list
    * xml: format as XML
    * brief: (default) format as a list of names

.PARAMETER NoReadonly
  When true, don't include read-only settings into the response. Default is false.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Get-HPBIOSSettingsList -Format BCU

.NOTES
  - Although the function supports BCU, note that redirecting the function's output to a file will not be usable by BCU, because PowerShell will insert a unicode BOM in the file. To obtain a compatible file, either remove the BOM manually or consider using bios-cli.ps1.
  - BIOS settings of type 'password' are not output when using XML, JSON, BCU, or CSV formats.
  - By convention, when representing multiple values in an enumeration as a single string, the value with an asterisk in front is the currently active value. For example, given the string "One,*Two,Three" representing three possible enumeration choices, the current active value is "Two".
  - Requires HP BIOS.
#>
function Get-HPBIOSSettingsList {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPBIOSSettingsList")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $false)]
    [Parameter(ParameterSetName = 'ReuseSession',Position = 0,Mandatory = $false)]
    [Parameter(Position = 0,Mandatory = $false)]
    [ValidateSet('Xml','Json','BCU','CSV','brief')]
    [string]$Format,
    [Parameter(ParameterSetName = 'NewSession',Position = 1,Mandatory = $false)]
    [Parameter(ParameterSetName = 'ReuseSession',Position = 1,Mandatory = $false)]
    [Parameter(Position = 1,Mandatory = $false)] [switch]$NoReadonly,
    [Parameter(ParameterSetName = 'NewSession',Position = 2,Mandatory = $false)]
    [Alias('Target')]
    [Parameter(Position = 2,Mandatory = $false)] [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 3,Mandatory = $false)]
    [Parameter(Position = 3,Mandatory = $false)] [CimSession]$CimSession
  )
  $ns = getNamespace

  Write-Verbose "Getting all BIOS settings from '$ComputerName'"
  $params = @{
    ClassName = 'HP_BIOSSetting'
    Namespace = $ns
  }

  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }

  try {
    $cs = Get-CimInstance @params -ErrorAction stop
  }
  catch [Microsoft.Management.Infrastructure.CimException]{
    if ($_.Exception.Message.trim() -eq "Access denied")
    {
      throw [System.UnauthorizedAccessException]"Access denied: Please ensure you have the rights to perform this operation."
    }
    throw [System.NotSupportedException]"$($_.Exception.Message): Please ensure this is a supported HP device."
  }

  switch ($format) {
    { $_ -eq 'bcu' } {
      # to BCU format
      $now = Get-Date
      Write-Output "BIOSConfig 1.0"
      Write-Output ";"
      Write-Output ";     Created by CMSL function Get-HPBIOSSettingsList"
      Write-Output ";     Date=$now"
      Write-Output ";"
      Write-Output ";     Found $($cs.count) settings"
      Write-Output ";"
      foreach ($c in $cs) {
        if ($c.CimClass.CimClassName -ne "HPBIOS_BIOSPassword") {
          if ((-not $noreadonly.IsPresent) -or ($c.IsReadOnly -eq 0)) {
            convertSettingToBCU ($c)
          }
        }
      }
      return
    }

    { $_ -eq 'xml' } {
      # to IA format
      Write-Output "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes"" ?>"
      Write-Output "<ImagePal>"
      Write-Output "  <BIOSSettings>"

      foreach ($c in $cs) {
        if ($c.CimClass.CimClassName -ne "HPBIOS_BIOSPassword") {
          if ((-not $noreadonly.IsPresent) -or ($c.IsReadOnly -eq 0)) {
            convertSettingToXML ($c)
          }
        }
      }
      Write-Output "  </BIOSSettings>"
      Write-Output "</ImagePal>"
      return
    }

    { $_ -eq 'json' } {
      # to JSON format
      $first = $true
      "[" | Write-Output


      foreach ($c in $cs) {
        Add-Member -InputObject $c -Force -NotePropertyName "Class" -NotePropertyValue $c.CimClass.CimClassName | Out-Null

        if ($c.CimClass.CimClassName -ne "HPBIOS_BIOSPassword") {
          if ((-not $noreadonly.IsPresent) -or ($c.IsReadOnly -eq 0)) {
            if ($first -ne $true) {
              Write-Output ","
            }
            convertSettingToJSON ($c)
            $first = $false
          }
        }

      }
      "]" | Write-Output

    }

    { $_ -eq 'csv' } {
      # to CSV format
      Write-Output ("NAME,CURRENT_VALUE,READONLY,TYPE,PHYSICAL_PRESENCE_REQUIRED,MIN,MAX,");
      foreach ($c in $cs) {
        if ($c.CimClass.CimClassName -ne "HPBIOS_BIOSPassword") {
          if ((-not $noreadonly.IsPresent) -or ($c.IsReadOnly -eq 0)) {
            convertSettingToCSV ($c)
          }
        }
      }
      return
    }
    { $_ -eq 'brief' } {
      foreach ($c in $cs) {
        if ((-not $noreadonly.IsPresent) -or ($c.IsReadOnly -eq 0)) {
          Write-Output $c.Name
        }
      }
      return
    }
    default {
      if (-not $noreadonly.IsPresent) {
        return $cs
      }
      else {
        return $cs | Where-Object IsReadOnly -EQ 0
      }
    }
  }
}

function Set-HPPrivateBIOSSettingValuePayload {
  param(
    [Parameter(ParameterSetName = 'Payload',Position = 0,Mandatory = $true,ValueFromPipeline = $true)]
    [string]$Payload
  )

  $portable = $Payload | ConvertFrom-Json

  if ($portable.purpose -ne "hp:sureadmin:biossetting") {
    throw "The payload should be generated by New-HPSureAdminBIOSSettingValuePayload function"
  }

  [SureAdminSetting]$setting = [System.Text.Encoding]::UTF8.GetString($portable.Data) | ConvertFrom-Json

  Set-HPPrivateBIOSSetting -Setting $setting
}

<#
.SYNOPSIS
  Set the value of a BIOS setting

.DESCRIPTION
  This function sets the value of an HP BIOS setting. Note that the setting may have various constraints restricting the input that can be provided.

.PARAMETER Name
  The name of a setting. Note that the setting name is usually case sensitive.

.PARAMETER Value
  The new value of a setting

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER Password
  The setup password, if a password is active

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.PARAMETER SkipPrecheck
  Skip reading the setting value from the BIOS, before applying it. This is useful as an optimization when the setting is guaranteed to exist on the system, or when preparing an HP Sure Admin platform for a remote platform which may contain settings not present on the local platform.

.NOTES
  - Requires HP BIOS.
  - Use single quotes around the password to prevent PowerShell from interpreting special characters in the string.
  - By convention, when representing multiple values in an enumeration as a single string, the value with an asterisk in front is the currently active value. For example, given the string "One,*Two,Three" representing three possible enumeration choices, the current active value is "Two".

.EXAMPLE
  Set-HPBIOSSettingValue -Name "Asset Tracking Number" -Value "Hello World" -password 's3cr3t'
#>
function Set-HPBIOSSettingValue {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Set%E2%80%90HPBIOSSettingValue")]
  param(
    [Parameter(ParameterSetName = "NewSession",Position = 0,Mandatory = $false)]
    [Parameter(ParameterSetName = "ReuseSession",Position = 0,Mandatory = $false)]
    [AllowEmptyString()]
    [string]$Password,

    [Parameter(ParameterSetName = "NewSession",Position = 1,Mandatory = $true)]
    [Parameter(ParameterSetName = "ReuseSession",Position = 1,Mandatory = $true)]
    [string]$Name,

    [Parameter(ParameterSetName = "NewSession",Position = 2,Mandatory = $true)]
    [Parameter(ParameterSetName = "ReuseSession",Position = 2,Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Value,

    [Parameter(ParameterSetName = "NewSession",Position = 3,Mandatory = $false)]
    [Parameter(ParameterSetName = "ReuseSession",Position = 3,Mandatory = $false)]
    [switch]$SkipPrecheck,

    [Parameter(ParameterSetName = 'NewSession',Position = 4,Mandatory = $false)]
    [Alias('Target')]
    $ComputerName = ".",

    [Parameter(ParameterSetName = 'ReuseSession',Position = 4,Mandatory = $true)]
    [CimSession]$CimSession
  )

  [SureAdminSetting]$setting = New-Object -TypeName SureAdminSetting
  $setting.Name = $Name
  $setting.Value = $Value

  $params = @{
    Setting = $setting
    Password = $Password
    CimSession = $CimSession
    ComputerName = $ComputerName
    SkipPrecheck = $SkipPrecheck
  }
  Set-HPPrivateBIOSSetting @params
}

<#
.SYNOPSIS
  Check if the BIOS Setup password is set

.DESCRIPTION
  This function returns $true if a BIOS password is currently active, or $false otherwise.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.NOTES
  Requires HP BIOS.

.EXAMPLE
  Get-HPBIOSSetupPasswordIsSet

.LINK
  [Set-HPBIOSSetupPassword](Set-HPBIOSSetupPassword)

.LINK
  [Get-HPBIOSSetupPasswordIsSet](Get-HPBIOSSetupPasswordIsSet)
#>
function Get-HPBIOSSetupPasswordIsSet () {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPBIOSSetupPasswordIsSet")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 1,Mandatory = $true)]
    [CimSession]$CimSession

  )
  $params = @{ Name = "Setup Password" }
  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }

  $obj = Get-HPBIOSSetting @params
  return [boolean]$obj.IsSet
}

<#
.SYNOPSIS
  Set the BIOS Setup password

.DESCRIPTION
  Set the BIOS Setup password to the specific value. The password must comply with the current active security policy.

.PARAMETER NewPassword
  The new password to set. A value is required. To clear the password, use Clear-HPBIOSSetupPassword

.PARAMETER Password
  The existing setup password, if any. If there is no password set, this parameter may be omitted. Use Get-HPBIOSSetupPasswordIsSet to determine if a password is currently set.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Set-HPBIOSSetupPassword -NewPassword 'newpw' -Password 'oldpw'

.LINK
  [Clear-HPBIOSSetupPassword](Clear-HPBIOSSetupPassword)

.LINK
  [Get-HPBIOSSetupPasswordIsSet](Get-HPBIOSSetupPasswordIsSet)

.NOTES
  - Requires HP BIOS.
  - Use single quotes around the password to prevent PowerShell from interpreting special characters in the string.
  - Multiple attempts to change the password with an incorrect existing password may trigger BIOS lockout mode, which can be cleared by rebooting the system.
#>
function Set-HPBIOSSetupPassword {
  [CmdletBinding(DefaultParameterSetName = 'NoPassthruNewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/set%E2%80%90HPBIOSSetupPassword")]
  param(
    [Parameter(ParameterSetName = 'NoPassthruNewSession',Position = 0,Mandatory = $true)]
    [Parameter(ParameterSetName = 'NoPassthruReuseSession',Position = 0,Mandatory = $true)]
    [string]$NewPassword,

    [Parameter(ParameterSetName = 'NoPassthruNewSession',Position = 1,Mandatory = $false)]
    [Parameter(ParameterSetName = 'NoPassthruReuseSession',Position = 1,Mandatory = $false)]
    [string]$Password,


    [Parameter(ParameterSetName = 'NoPassthruNewSession',Position = 2,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",

    [Parameter(ParameterSetName = 'NoPassthruReuseSession',Position = 3,Mandatory = $true)]
    [CimSession]$CimSession
  )
  $params = @{}
  $settingName = 'Setup Password'


  if ($PSCmdlet.ParameterSetName -eq 'NoPassthruNewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'NoPassthruReuseSession') { $params.CimSession = $CimSession }

  $iface = getBiosSettingInterface @params

  $r = $iface | Invoke-CimMethod -ErrorAction Stop -MethodName 'SetBIOSSetting' -Arguments @{
    Name = $settingName
    Password = '<utf-16/>' + $Password
    Value = '<utf-16/>' + $newPassword
  }

  if ($r.Return -ne 0) {
    $Err = "$(biosErrorCodesToString($r.Return))"
    throw [System.InvalidOperationException]$Err
  }
}

<#
.SYNOPSIS
  Clear the BIOS Setup password

.DESCRIPTION
  This function clears the BIOS setup password. To set the password, use Set-HPBIOSSetupPassword

.PARAMETER Password
  The existing setup password. Use Get-HPBIOSSetupPasswordIsSet to determine if a password is currently set.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Clear-HPBIOSSetupPassword  -Password 'oldpw'

.NOTES
  - Requires HP BIOS.
  - Use single quotes around the password to prevent PowerShell from interpreting special characters in the string.
  - Multiple attempts to change the password with an incorrect existing password may trigger BIOS lockout mode, which can be cleared by rebooting the system.

.LINK
  [Set-HPBIOSSetupPassword](Set-HPBIOSSetupPassword)

.LINK
  [Get-HPBIOSSetupPasswordIsSet](Get-HPBIOSSetupPasswordIsSet)
#>
function Clear-HPBIOSSetupPassword {
  [CmdletBinding(DefaultParameterSetName = 'NoPassthruNewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Clear%E2%80%90HPBIOSSetupPassword")]
  param(
    [Parameter(ParameterSetName = 'NoPassthruNewSession',Position = 0,Mandatory = $true)]
    [Parameter(ParameterSetName = 'NoPassthruReuseSession',Position = 0,Mandatory = $true)]
    [string]$Password,

    [Parameter(ParameterSetName = 'NoPassthruNewSession',Position = 1,Mandatory = $false)]
    [Alias('Target')]
    $ComputerName = ".",
    [Parameter(ParameterSetName = 'NoPassthruReuseSession',Position = 2,Mandatory = $true)]
    [CimSession]$CimSession
  )
  $settingName = 'Setup Password'


  $params = @{}
  if ($PSCmdlet.ParameterSetName -eq 'NoPassthruNewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'NoPassthruReuseSession') { $params.CimSession = $CimSession }

  $iface = getBiosSettingInterface @params
  $r = $iface | Invoke-CimMethod -MethodName SetBiosSetting -Arguments @{ Name = "Setup Password"; Value = "<utf-16/>"; Password = "<utf-16/>" + $Password; }
  if ($r.Return -ne 0) {
    $Err = "$(biosErrorCodesToString($r.Return))"
    throw [System.InvalidOperationException]$Err
  }
}


<#
.SYNOPSIS
  Check if the BIOS Power-On password is set

.DESCRIPTION
  This function returns $true if a BIOS power-on password is currently active, or $false otherwise.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.NOTES
  Changes in the state of the BIOS Power-On Password may not be visible until the system is rebooted and the POST prompt is accepted to enable the BIOS Power-On password.

.EXAMPLE
  Get-HPBIOSPowerOnPasswordIsSet

.LINK
  [Set-HPBIOSPowerOnPassword](Set-HPBIOSPowerOnPassword)

.LINK
  [Clear-HPBIOSPowerOnPassword](Clear-HPBIOSPowerOnPassword)
#>
function Get-HPBIOSPowerOnPasswordIsSet () {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPBIOSPowerOnPasswordIsSet")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 1,Mandatory = $true)]
    [CimSession]$CimSession

  )
  $params = @{ Name = "Power-On Password" }
  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }

  $obj = Get-HPBIOSSetting @params
  return [boolean]$obj.IsSet
}

<#
.SYNOPSIS
  Set the BIOS Power-On password

.DESCRIPTION
  This function clears any active power-on password. The Password must comply with password complexity requirements active on the system.

.PARAMETER NewPassword
  The password to set. A value is required. To clear the password, use Clear-HPBIOSPowerOnPassword

.PARAMETER Password
  The existing setup password (not power-on password), if any. If there is no setup password set, this parameter may be omitted. Use Get-HPBIOSSetupPasswordIsSet to determine if a setup password is currently set.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.NOTES
  Changes in the state of the BIOS Power-On Password may not be visible until the system is rebooted and the POST prompt is accepted to enable the BIOS Power-On password.

.EXAMPLE
  Set-HPBIOSPowerOnPassword -NewPassword 'newpw' -Password 'setuppw'

.LINK
  [Clear-HPBIOSPowerOnPassword](Clear-HPBIOSPowerOnPassword)

.LINK
  [Get-HPBIOSPowerOnPasswordIsSet](Get-HPBIOSPower\OnPasswordIsSet)

.NOTES
  - Requires HP BIOS.
  - Use single quotes around the password to prevent PowerShell from interpreting special characters in the string.
  - On many platform families, changing the Power-On password requires that a BIOS password is active.

#>
function Set-HPBIOSPowerOnPassword {
  [CmdletBinding(DefaultParameterSetName = 'NoPassthruNewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Set%E2%80%90HPBIOSPowerOnPassword")]
  param(
    [Parameter(ParameterSetName = 'NoPassthruNewSession',Position = 0,Mandatory = $true)]
    [Parameter(ParameterSetName = 'NoPassthruReuseSession',Position = 0,Mandatory = $true)]
    [string]$NewPassword,
    [Parameter(ParameterSetName = 'NoPassthruNewSession',Position = 1,Mandatory = $false)]
    [Parameter(ParameterSetName = 'NoPassthruReuseSession',Position = 1,Mandatory = $false)]
    [string]$Password,

    [Parameter(ParameterSetName = 'NoPassthruNewSession',Position = 3,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'NoPassthruReuseSession',Position = 4,Mandatory = $true)]
    [CimSession]$CimSession
  )
  $settingName = 'Power-On Password'

  $params = @{}
  if ($PSCmdlet.ParameterSetName -eq 'NoPassthruNewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'NoPassthruReuseSession') { $params.CimSession = $CimSession }

  $iface = getBiosSettingInterface @params
  $r = $iface | Invoke-CimMethod -MethodName SetBiosSetting -Arguments @{ Name = $settingName; Value = "<utf-16/>" + $newPassword; Password = "<utf-16/>" + $Password; }
  if ($r.Return -ne 0) {
    $Err = "$(biosErrorCodesToString($r.Return))"
    throw $Err
  }
}

<#
.SYNOPSIS
  Clear the BIOS Power-On password

.DESCRIPTION
  This function clears any active power-on password.

.PARAMETER Password
  The existing setup (not power-on) password. Use Get-HPBIOSSetupPasswordIsSet to determine if a password is currently set. See important note regarding the BIOS Setup Password prerequisite below.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Clear-HPBIOSPowerOnPassword -Password 's3cr3t'

.LINK
  [Set-HPBIOSPowerOnPassword](Set-HPBIOSPowerOnPassword)

.LINK
  [Get-HPBIOSPowerOnPasswordIsSet](Get-HPBIOSPowerOnPasswordIsSet)

.LINK
  [Get-HPBIOSSetupPasswordIsSet](Get-HPBIOSSetupPasswordIsSet)

.NOTES
  - Requires HP BIOS.
  - Use single quotes around the password to prevent PowerShell from interpreting special characters in the string.
  - On many platform families, changing the Power-On password requires that a BIOS password is active.
  - If BIOS Setup Password is not set, it's required to be first set in order to clear the Power-On password.

#>
function Clear-HPBIOSPowerOnPassword {
  [CmdletBinding(DefaultParameterSetName = 'NoPassthruNewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Clear%E2%80%90HPBIOSPowerOnPassword")]
  param(
    [Parameter(ParameterSetName = 'NoPassthruNewSession',Position = 0,Mandatory = $false)]
    [Parameter(ParameterSetName = 'NoPassthruReuseSession',Position = 0,Mandatory = $false)]
    [string]$Password,


    [Parameter(ParameterSetName = 'NoPassthruNewSession',Position = 1,Mandatory = $false)]
    [Alias('Target')]
    $ComputerName = ".",
    [Parameter(ParameterSetName = 'NoPassthruReuseSession',Position = 2,Mandatory = $true)]
    [CimSession]$CimSession
  )

  $settingName = 'Power-On Password'


  $params = @{}
  if ($PSCmdlet.ParameterSetName -eq 'NoPassthruNewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'NoPassthruReuseSession') { $params.CimSession = $CimSession }

  $iface = getBiosSettingInterface @params
  $r = $iface | Invoke-CimMethod -MethodName SetBiosSetting -Arguments @{
    Name = "Power-On Password"
    Value = "<utf-16/>"
    Password = ("<utf-16/>" + $Password)
  }
  if ($r.Return -ne 0) {
    $Err = "$(biosErrorCodesToString($r.Return))"
    throw [System.InvalidOperationException]$Err
  }
}

<#
.SYNOPSIS
  Set one or more BIOS settings from a file

.DESCRIPTION
  This function sets multiple BIOS settings from a file. The file format may be specified via the -format parameter, however the function will try to infer the format from the file extension.

.PARAMETER File
  The settings file (relative or absolute path) to process
  - Note that BIOS passwords are not encrypted in this file, so it is essential to protect its content until applied to the target system.

.PARAMETER Format
  The file format (xml, json, csv, or bcu).

.PARAMETER Password
  The current BIOS setup password, if any.

.PARAMETER NoSummary
  Suppress the one line summary at the end of the import

.PARAMETER ErrorHandling
  This value is used by wrapping scripts to prevent this function from raising exceptions or warnings.
    0 - operate normally
    1 - raise exceptions as warnings
    2 - no warnings or exceptions, fail silently

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Set-HPBIOSSettingValuesFromFile -File .\file.bcu -NoSummary

.NOTES
  - Requires HP BIOS.
  - Use single quotes around the password to prevent PowerShell from interpreting special characters in the string.
#>
function Set-HPBIOSSettingValuesFromFile {
  [CmdletBinding(DefaultParameterSetName = "NotPassThruNewSession",
    HelpUri = "https://developers.hp.com/hp-client-management/doc/Set%E2%80%90HPBIOSSettingValuesFromFile")]
  param(
    [Parameter(ParameterSetName = "NotPassThruNewSession",Position = 0,Mandatory = $true)]
    [Parameter(ParameterSetName = "NotPassThruReuseSession",Position = 0,Mandatory = $true)]
    [System.IO.FileInfo]$File,

    [Parameter(ParameterSetName = "NotPassThruNewSession",Position = 1,Mandatory = $false)]
    [Parameter(ParameterSetName = "NotPassThruReuseSession",Position = 1,Mandatory = $false)]
    [ValidateSet('Xml','Json','BCU','CSV')]
    [string]$Format = $null,

    [Parameter(ParameterSetName = "NotPassThruNewSession",Position = 2,Mandatory = $false)]
    [Parameter(ParameterSetName = "NotPassThruReuseSession",Position = 2,Mandatory = $false)]
    [string]$Password,

    [Parameter(ParameterSetName = "NotPassThruNewSession",Position = 3,Mandatory = $false)]
    [Parameter(ParameterSetName = "NotPassThruReuseSession",Position = 3,Mandatory = $false)]
    [switch]$NoSummary,

    [Parameter(ParameterSetName = "NotPassThruNewSession",Position = 4,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",

    [Parameter(ParameterSetName = "NotPassThruNewSession",Position = 5,Mandatory = $false)]
    [Parameter(ParameterSetName = "NotPassThruReuseSession",Position = 5,Mandatory = $false)]
    $ErrorHandling = 2,

    [Parameter(ParameterSetName = "NotPassThruReuseSession",Position = 6,Mandatory = $true)]
    [CimSession]$CimSession
  )

  if (-not $Format) {
    $Format = (Split-Path -Path $File -Leaf).Split(".")[1].ToLower()
    Write-Verbose "Format from file extension: $Format"
  }

  Write-Verbose "Format specified: '$Format'. Reading file..."
  [System.Collections.Generic.List[SureAdminSetting]]$settingsList = Get-HPPrivateSettingsFromFile -FileName $File -Format $Format

  $params = @{
    SettingsList = $settingsList
    ErrorHandling = $ErrorHandling
    ComputerName = $ComputerName
    CimSession = $CimSession
    Password = $Password
    NoSummary = $NoSummary
  }
  Set-HPPrivateBIOSSettingsList @params -Verbose:$VerbosePreference
}

<#
.SYNOPSIS
  Reset BIOS settings to shipping defaults

.DESCRIPTION
  Reset BIOS to shipping defaults. The actual defaults are platform specific.

.PARAMETER Password
  The current BIOS setup password, if any.

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  Set-HPBIOSSettingDefaults -Password 's3cr3t'

.NOTES
  - Requires HP BIOS.
  - Use single quotes around the password to prevent PowerShell from interpreting special characters in the string.

#>
function Set-HPBIOSSettingDefaults {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Set%E2%80%90HPBIOSSettingDefaults")]
  param(
    [Parameter(ParameterSetName = "NewSession",Position = 0,Mandatory = $false)]
    [Parameter(ParameterSetName = "ReuseSession",Position = 0,Mandatory = $false)]
    [AllowEmptyString()]
    [string]$Password,

    [Parameter(ParameterSetName = 'NewSession',Position = 1,Mandatory = $false)]
    [Alias('Target')]
    $ComputerName = ".",

    [Parameter(ParameterSetName = 'ReuseSession',Position = 2,Mandatory = $true)]
    [CimSession]$CimSession
  )

  $authorization = "<utf-16/>" + $Password
  Set-HPPrivateBIOSSettingDefaultsAuthorization -ComputerName $ComputerName -CimSession $CimSession -Authorization $authorization -Verbose:$VerbosePreference
}

function Set-HPPrivateBIOSSettingDefaultsAuthorization {
  param(
    [string]$Authorization,
    [string]$ComputerName,
    [CimSession]$CimSession
  )

  Write-Verbose "Calling SetSystemDefaults() on $ComputerName"
  $params = @{}
  if ($CimSession) {
    $params.CimSession = $CimSession
  }
  else {
    $params.CimSession = newCimSession -Target $ComputerName
  }
  $iface = getBiosSettingInterface @params
  $r = $iface | Invoke-CimMethod -MethodName SetSystemDefaults -Arguments @{ Password = $Authorization; }

  if ($r.Return -ne 0) {
    $Err = "$(biosErrorCodesToString($r.Return))"
    throw $Err
  }
}

function Set-HPPrivateBIOSSettingDefaultsPayload {
  param(
    [Parameter(ParameterSetName = 'Payload',Position = 0,Mandatory = $true,ValueFromPipeline = $true)]
    [string]$Payload
  )

  $portable = $Payload | ConvertFrom-Json

  if ($portable.purpose -ne "hp:sureadmin:resetsettings") {
    throw "The payload should be generated by New-HPSureAdminSettingDefaultsPayload function"
  }

  [SureAdminSetting]$setting = [System.Text.Encoding]::UTF8.GetString($portable.Data) | ConvertFrom-Json

  Set-HPPrivateBIOSSettingDefaultsAuthorization -Authorization $setting.AuthString
}

<#
.SYNOPSIS
  Get system uptime

.DESCRIPTION
  Get the system boot time and uptime

.PARAMETER ComputerName
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER CimSession
  A pre-established CIM Session (as created by [New-CIMSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsessionoption?view=powershell-5.1) cmdlet). Use this to pass a preconfigured session object to optimize remote connections or specify the connection protocol (Wsman or DCOM). If not specified, the function will create its own one-time use CIM Session object, and default to DCOM protocol.

.EXAMPLE
  (Get-HPDeviceUptime).BootTime

#>
function Get-HPDeviceUptime {
  [CmdletBinding(DefaultParameterSetName = 'NewSession',HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPDeviceUptime")]
  param(
    [Parameter(ParameterSetName = 'NewSession',Position = 0,Mandatory = $false)]
    [Alias('Target')]
    [string]$ComputerName = ".",
    [Parameter(ParameterSetName = 'ReuseSession',Position = 1,Mandatory = $true)]
    [CimSession]$CimSession
  )
  $params = @{
    ClassName = 'Win32_OperatingSystem'
    Namespace = 'root\cimv2'
  }
  if ($PSCmdlet.ParameterSetName -eq 'NewSession') { $params.CimSession = newCimSession -Target $ComputerName }
  if ($PSCmdlet.ParameterSetName -eq 'ReuseSession') { $params.CimSession = $CimSession }

  $result = Get-CimInstance @params -ErrorAction stop
  $resultobject = @{}
  $resultobject.BootTime = $result.LastBootUpTime

  $span = (Get-Date) - ($resultobject.BootTime)
  $resultobject.Uptime = "$($span.days) days, $($span.hours) hours, $($span.minutes) minutes, $($span.seconds) seconds"
  $resultobject
}



<#
.SYNOPSIS
    Get current boot mode and uptime

.DESCRIPTION
  Returns an object containing system uptime, last boot time, whether secure boot is enabled, and whether the system was booted in UEFI or Legacy mode.


.EXAMPLE
    $IsUefi = (Get-HPDeviceBootInformation).Mode -eq "UEFI"

#>
function Get-HPDeviceBootInformation {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPDeviceBootInformation")]
  param()

  $mode = @{}

  try {
    $sb = Confirm-SecureBootUEFI
    $mode.Mode = "UEFI"
    $mode.SecureBoot = $sb
  }
  catch {
    $mode.Mode = "Legacy"
    $mode.SecureBoot = $false
  }

  try {
    $uptime = Get-HPDeviceUptime
    $mode.Uptime = $uptime.Uptime
    $mode.BootTime = $uptime.BootTime
  }
  catch {
    $mode.Uptime = "N/A"
    $mode.BootTime = "N/A"
  }

  $mode
}



<#
.SYNOPSIS
  Check and apply available BIOS updates (or downgrades)

.DESCRIPTION
  This function uses an internet service to retrieve the list of BIOS updates available for a platform, and optionally checks it against the current system.

  The result is a series of records, with the following definition:

    * Ver - the BIOS update version
    * Date - the BIOS release date
    * Bin - the BIOS update binary file

.PARAMETER Platform
  The Platform ID to check. It can be obtained via Get-HPDeviceProductID. The Platform ID cannot be specified for a flash operation. If not specified, current Platform ID is checked.

.PARAMETER Target
  Execute the command on specified target computer. If not specified, the command is executed on the local computer.

.PARAMETER Format
  The file format (xml, json, csv, list) to output. If not specified, a list of PowerShell objects is returned.

.PARAMETER Latest
  If specified, only return or download the latest available BIOS version between remote and local. If -Platform is specified, local BIOS will not be read and the latest BIOS version available remotely will be returned.

.PARAMETER Check
  If specified, return true if the latest version corresponds to the installed version or installed version is higher, false otherwise. This check is only valid when comparing against current platform.

.PARAMETER All
  Include all known BIOS update information. This may include additional data such as dependencies, rollback support, and criticality.

.PARAMETER Download
  Download the BIOS file to the current directory or a path specified by SaveAs.

.PARAMETER Flash
  Apply the BIOS update to the current system.

.PARAMETER Password
  Specify the BIOS password, if a password is active. This switch is only used when -flash is specified.
  - Use single quotes around the password to prevent PowerShell from interpreting special characters in the string.

.PARAMETER Version
  The BIOS version to download. If not specified, the latest version available will be downloaded.

.PARAMETER SaveAs
  The filename for the downloaded BIOS file. If not specified, the remote file name will be used.

.PARAMETER Quiet
  Do not display a progress bar during BIOS file download.

.PARAMETER Overwrite
  Force overwriting any existing file with the same name during BIOS file download. This switch is only used when -download is specified.

.PARAMETER Yes
  Answer 'yes' to the 'Are you sure you want to flash' prompt.

.PARAMETER Force
  Force the BIOS to update, even if the target BIOS is already installed.

.PARAMETER BitLocker
  Provide an answer to the BitLocker check prompt (if any). The value may be one of:
    stop - stop if BitLocker is detected but not suspended, and prompt.
    stop is default when BitLocker switch is provided.
    ignore - skip the BitLocker check
    suspend - suspend BitLocker if active, and continue

.PARAMETER Url
  Alternate Url source to provide platform's BIOS update catalog (xml)

.NOTES
  - Flash is only supported on Windows 10 1709 (Fall Creators Updated) and later.
  - UEFI boot mode is required for flashing, legacy mode is not supported.
  - The flash operation requires 64-bit PowerShell (not supported under 32-bit PowerShell)

  **WinPE notes**

  - Use '-BitLocker ignore' when using this function in WinPE, as BitLocker checks are not applicable in Windows PE.
  - Requires that the WInPE image is built with the WinPE-SecureBootCmdlets.cab component.

.EXAMPLE
  Get-HPBIOSUpdates
#>
function Get-HPBIOSUpdates {

  [CmdletBinding(DefaultParameterSetName = "ViewSet",
    HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPBIOSUpdates")]
  param(
    [Parameter(ParameterSetName = "DownloadSet",Position = 0,Mandatory = $false)]
    [Parameter(ParameterSetName = "ViewSet",Position = 0,Mandatory = $false)]
    [Parameter(Position = 0,Mandatory = $false)]
    [ValidatePattern("^[a-fA-F0-9]{4}$")]
    [string]$Platform,

    [ValidateSet('Xml','Json','CSV','List')]
    [Parameter(ParameterSetName = "ViewSet",Position = 1,Mandatory = $false)]
    [string]$Format,

    [Parameter(ParameterSetName = "ViewSet",Position = 2,Mandatory = $false)]
    [switch]$Latest,

    [Parameter(ParameterSetName = "CheckSet",Position = 3,Mandatory = $false)]
    [switch]$Check,

    [Parameter(ParameterSetName = "FlashSetPassword",Position = 4,Mandatory = $false)]
    [Parameter(ParameterSetName = "DownloadSet",Position = 4,Mandatory = $false)]
    [Parameter(ParameterSetName = "ViewSet",Position = 4,Mandatory = $false)]
    [string]$Target = ".",

    [Parameter(ParameterSetName = "ViewSet",Position = 5,Mandatory = $false)]
    [switch]$All,

    [Parameter(ParameterSetName = "DownloadSet",Position = 6,Mandatory = $true)]
    [switch]$Download,

    [Parameter(ParameterSetName = "FlashSetPassword",Position = 7,Mandatory = $true)]
    [switch]$Flash,

    [Parameter(ParameterSetName = 'FlashSetPassword',Position = 8,Mandatory = $false)]
    [string]$Password,

    [Parameter(ParameterSetName = "FlashSetPassword",Position = 9,Mandatory = $false)]
    [Parameter(ParameterSetName = "DownloadSet",Position = 9,Mandatory = $false)]
    [string]$Version,

    [Parameter(ParameterSetName = "FlashSetPassword",Position = 10,Mandatory = $false)]
    [Parameter(ParameterSetName = "DownloadSet",Position = 10,Mandatory = $false)]
    [string]$SaveAs,

    [Parameter(ParameterSetName = "FlashSetPassword",Position = 11,Mandatory = $false)]
    [Parameter(ParameterSetName = "DownloadSet",Position = 11,Mandatory = $false)]
    [switch]$Quiet,

    [Parameter(ParameterSetName = "FlashSetPassword",Position = 12,Mandatory = $false)]
    [Parameter(ParameterSetName = "DownloadSet",Position = 12,Mandatory = $false)]
    [switch]$Overwrite,

    [Parameter(ParameterSetName = 'FlashSetPassword',Position = 13,Mandatory = $false)]
    [switch]$Yes,

    [Parameter(ParameterSetName = 'FlashSetPassword',Position = 14,Mandatory = $false)]
    [ValidateSet('Stop','Ignore','Suspend')]
    [string]$BitLocker = 'Stop',

    [Parameter(ParameterSetName = 'FlashSetPassword',Position = 15,Mandatory = $false)]
    [switch]$Force,

    [Parameter(ParameterSetName = 'FlashSetPassword',Position = 16,Mandatory = $false)]
    [string]$Url = "https://ftp.hp.com/pub/pcbios"
  )

  if ($PSCmdlet.ParameterSetName -eq "FlashSetPassword") {
    Test-HPFirmwareFlashSupported -CheckPlatform

    if ((Get-HPPrivateIsSureAdminEnabled) -eq $true) {
      throw "Sure Admin is enabled, you must use Update-HPFirmware with a payload instead of a password"
    }
  }

  if (-not $platform) {
    # if platform is not provided, $platform is current platform
    $platform = Get-HPDeviceProductID -Target $target
  }

  $platform = $platform.ToUpper()
  Write-Verbose "Using platform ID $platform"


  $uri = [string]"$Url/{0}/{0}.xml" -f $platform.ToUpper()
  Write-Verbose "Retrieving catalog file $uri"
  $ua = Get-HPPrivateUserAgent
  try {
    [System.Net.ServicePointManager]::SecurityProtocol = Get-HPPrivateAllowedHttpsProtocols
    $data = Invoke-WebRequest -Uri $uri -UserAgent $ua -UseBasicParsing -ErrorAction Stop
  }
  catch [System.Net.WebException]{
    if ($_.Exception.Message.contains("(404) Not Found"))
    {
      throw [System.Management.Automation.ItemNotFoundException]"Unable to retrieve BIOS data for a platform with ID $platform (data file not found)."
    }
    throw $_.Exception
  }

  [xml]$doc = [System.IO.StreamReader]::new($data.RawContentStream).ReadToEnd()
  if ((-not $doc) -or (-not (Get-Member -InputObject $doc -Type Property -Name "BIOS")) -or (-not (Get-Member -InputObject $doc.bios -Type Property -Name "Rel")))
  {
    throw [System.FormatException]"Source data file is unsupported or corrupt"
  }

  #reach to Rel nodes to find Bin entries in xml
  #ignore any entry not ending in *.bin e.g. *.tgz, *.cab
  $unwanted_nodes = $doc.SelectNodes("//BIOS/Rel") | Where-Object { -not ($_.Bin -like "*.bin") }
  $unwanted_nodes | Where-Object {
    $ignore = $_.ParentNode.RemoveChild($_)
  }

  #trim the 0 from the start of the version and then sort on the version value
  $refined_doc = $doc.SelectNodes("//BIOS/Rel") | Select-Object -Property @{ Name = 'Ver'; expr = { $_.Ver.TrimStart("0") } },'Date','Bin','RB','L','DP' `
     | Sort-Object -Property Ver -Descending

  #latest version
  $latestVer = $refined_doc[0]

  if (($PSCmdlet.ParameterSetName -eq "ViewSet") -or ($PSCmdlet.ParameterSetName -eq "CheckSet")) {
    Write-Verbose "Proceeding with parameter set => view"
    if ($check.IsPresent -eq $true) {
      [string]$haveVer = Get-HPBIOSVersion -Target $target
      #check should return true if local BIOS is same or newer than the latest available remote BIOS.
      return ([string]$haveVer.TrimStart("0") -ge [string]$latestVer[0].Ver)
    }

    $args = @{}
    if ($all.IsPresent) {
      $args.Property = (@{ Name = 'Ver'; expr = { $_.Ver.TrimStart("0") } },"Date","Bin",`
           (@{ Name = 'RollbackAllowed'; expr = { [bool][int]$_.RB.trim() } }),`
           (@{ Name = 'Importance'; expr = { [Enum]::ToObject([BiosUpdateCriticality],[int]$_.L.trim()) } }),`
           (@{ Name = 'Dependency'; expr = { [string]$_.DP.trim() } }))
    }
    else {
      $args.Property = (@{ Name = 'Ver'; expr = { $_.Ver.TrimStart("0") } },"Date","Bin")
    }

    # for current platform: latest should return whichever is latest, between local and remote.
    # for any other platform specified: latest should return latest entry from SystemID.XML since we don't know local BIOSVersion
    if ($latest)
    {
      if ($PSBoundParameters.ContainsKey('Platform'))
      {
        # platform specified, do not read information from local system and return latest platform published
        $args.First = 1
      }
      else {
        $retrieved = 0
        # determine the local BIOS version
        [string]$haveVer = Get-HPBIOSVersion -Target $target
        # latest should return whichever is latest, between local and remote for current system.
        if ([string]$haveVer -ge [string]$latestVer[0].Ver)
        {
          # local is the latest. So, retrieve attributes other than BIOSVersion to print for latest
          for ($i = 0; $i -lt $refined_doc.Length; $i++) {
            if ($refined_doc[$i].Ver -eq $haveVer) {
              $haveVerFromDoc = $refined_doc[$i]
              $pso = [pscustomobject]@{
                Ver = $haveVerFromDoc.Ver
                Date = $haveVerFromDoc.Date
                Bin = $haveVerFromDoc.Bin
              }
              if ($all) {
                $pso | Add-Member -MemberType ScriptProperty -Name RollbackAllowed -Value { [bool][int]$haveVerFromDoc.RB.trim() }
                $pso | Add-Member -MemberType ScriptProperty -Name Importance -Value { [Enum]::ToObject([BiosUpdateCriticality],[int]$haveVerFromDoc.L.trim()) }
                $pso | Add-Member -MemberType ScriptProperty -Name Dependency -Value { [string]$haveVerFromDoc.DP.trim }
              }
              $retrieved = 1
              if ($pso) {
                formatBiosVersionsOutputList ($pso)
                return
              }
            }
          }
          if ($retrieved -eq 0) {
            Write-Verbose "retrieving entry from xml failed, get the information from CIM class."
            # calculating date from Win32_BIOS
            $year = (Get-CimInstance Win32_BIOS).ReleaseDate.Year
            $month = (Get-CimInstance Win32_BIOS).ReleaseDate.Month
            $day = (Get-CimInstance Win32_BIOS).ReleaseDate.Day
            $date = $year.ToString() + '-' + $month.ToString() + '-' + $day.ToString()
            Write-Verbose "date calculated from CIM Class is: $date"

            $currentVer = Get-HPBIOSVersion
            $pso = [pscustomobject]@{
              Ver = $currentVer
              Date = $date
              Bin = $null
            }
            if ($all) {
              $pso | Add-Member -MemberType ScriptProperty -Name RollbackAllowed -Value { $null }
              $pso | Add-Member -MemberType ScriptProperty -Name Importance -Value { $null }
              $pso | Add-Member -MemberType ScriptProperty -Name Dependency -Value { $null }
            }
            if ($pso) {
              $retrieved = 1
              formatBiosVersionsOutputList ($pso)
              return
            }
          }
        }
        else {
          # remote is the latest
          $args.First = 1
        }
      }
    }
    formatBiosVersionsOutputList ($refined_doc | Sort-Object -Property ver -Descending | Select-Object @args)
  }
  else {
    $download_params = @{}

    if ($version) {
      $latestVer = $refined_doc `
         | Where-Object { $_.Ver.TrimStart("0") -eq $version } `
         | Select-Object -Property Ver,Bin -First 1
    }

    if (-not $latestVer) { throw [System.ArgumentOutOfRangeException]"Version $version was not found." }

    if (($flash.IsPresent) -and (-not $saveAs)) {
      $saveAs = Get-HPPrivateTemporaryFileName -FileName $latestVer.Bin
      $download_params.NoClobber = "yes"
      Write-Verbose "Temporary file name for download is $saveAs"
    }
    else { $download_params.NoClobber = if ($overwrite.IsPresent) { "yes" } else { "no" } }

    Write-Verbose "Proceeding with parameter set => download, overwrite=$($download_params.NoClobber)"


    $remote_file = $latestVer.Bin
    $local_file = $latestVer.Bin
    $remote_ver = $latestVer.Ver

    if ($PSCmdlet.ParameterSetName -eq "FlashSetPassword" -or
      $PSCmdlet.ParameterSetName -eq "FlashSetSigningKeyFile" -or
      $PSCmdlet.ParameterSetName -eq "FlashSetSigningKeyCert") {
      $running = Get-HPBIOSVersion
      if ((-not $Force.IsPresent) -and ($running.TrimStart("0").trim() -ge $remote_ver.TrimStart("0").trim())) {
        Write-Host "This system is already running BIOS version $($remote_ver.TrimStart(`"0`").Trim()) or newer."
        Write-Host -ForegroundColor Cyan "You can specify -Force on the command line to proceed anyway."
        return
      }
    }

    if ($saveAs) {
      $local_file = $saveAs
    }

    [Environment]::CurrentDirectory = $pwd
    #if (-not [System.IO.Path]::IsPathRooted($to)) { $to = ".\$to" }

    $download_params.url = [string]"$Url/{0}/{1}" -f $platform,$remote_file
    $download_params.Target = [IO.Path]::GetFullPath($local_file)
    $download_params.progress = ($quiet.IsPresent -eq $false)
    Invoke-HPPrivateDownloadFile @download_params -panic

    if ($PSCmdlet.ParameterSetName -eq "FlashSetPassword" -or
      $PSCmdlet.ParameterSetName -eq "FlashSetSigningKeyFile" -or
      $PSCmdlet.ParameterSetName -eq "FlashSetSigningKeyCert") {
      if (-not $yes) {
        Write-Host -ForegroundColor Cyan "Are you sure you want to flash this system with version '$remote_ver'?"
        Write-Host -ForegroundColor Cyan "Current BIOS version is $(Get-HPBIOSVersion)."
        Write-Host -ForegroundColor Cyan "A reboot will be required for the operation to complete."
        $response = Read-Host -Prompt "Type 'Y' to continue and anything else to abort. Or specify -Yes on the command line to skip this prompt"
        if ($response -ne "Y") {
          Write-Verbose "User did not confirm and did not disable confirmation, aborting."
          return
        }
      }

      Write-Verbose "Passing to flash process with file $($download_params.target)"

      $update_params = @{
        file = $download_params.Target
        bitlocker = $bitlocker
        Force = $Force
        Password = $password
      }

      Update-HPFirmware @update_params -Verbose:$VerbosePreference
    }
  }

}

function Get-HPPrivateBIOSFamilyNameAndVersion {
  [CmdletBinding()]
  param(
  )

  $params = @{
    ClassName = 'Win32_BIOS'
    Namespace = 'root\cimv2'
  }
  $params.CimSession = newCimSession -Target "."
  $obj = Get-CimInstance @params -ErrorAction stop
  $verfield = (getWmiField $obj "SMBIOSBIOSVersion").Split()

  return $verfield[0],$verfield[2]
}


<#
.SYNOPSIS
  Check and apply available BIOS updates using Windows Update images (subject to change)

.DESCRIPTION
  This function uses an internet service to get the list of BIOS capsule updates available for a platform family, and optionally install the update in the current system. The versions available through this function may differ from Get-HPBIOSUpdate since this relies on the Microsoft capsules availability.

.PARAMETER family
  the Platform Family to check. If not specified, check the current platform family.

.PARAMETER severity
  If specified, returns the available BIOS for the specified severity: Latest or LatestCritical.

.PARAMETER download
  Download the BIOS file to the current directory or a path specified by saveAs.

.PARAMETER flash
  Apply the BIOS update to the current system.

.PARAMETER version
  The BIOS version to download. If not specified, the latest version available will be downloaded.

.PARAMETER saveAs
  The filename for the downloaded BIOS file. If not specified, the remote file name will be used.

.PARAMETER yes
  Answer 'yes' to the 'Are you sure you want to flash' prompt.

.PARAMETER Force
  Force the BIOS to update, even if the target BIOS is already installed.

.PARAMETER Url
  Alternate Url source to provide platform's BIOS update catalog(xml)

.NOTES
  - Requires Windows group policy support

.EXAMPLE
  Get-HPBIOSWindowsUpdate

.EXAMPLE
  Get-HPBIOSWindowsUpdate -List -Family R70

.EXAMPLE
  Get-HPBIOSWindowsUpdate -Flash -Severity Latest

.EXAMPLE
  Get-HPBIOSWindowsUpdate -Flash -Severity LatestCritical

.EXAMPLE
  Get-HPBIOSWindowsUpdate -Flash -Severity LatestCritical -Family R70

.EXAMPLE
  Get-HPBIOSWindowsUpdate -Flash -Severity LatestCritical -Family R70 -Version "01.09.00"
#>
function Get-HPBIOSWindowsUpdate {
  [CmdletBinding(DefaultParameterSetName = "Severity",HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPBIOSWindowsUpdate")]
  param(
    [Parameter(Mandatory = $false,Position = 0,ParameterSetName = "Severity")]
    [ValidateSet('Latest','LatestCritical')]
    [string]$Severity = 'Latest',

    [Parameter(Mandatory = $true,Position = 0,ParameterSetName = "Specific")]
    [string]$Version,

    [Parameter(Mandatory = $false,Position = 1,ParameterSetName = "Severity")]
    [Parameter(Mandatory = $false,Position = 1,ParameterSetName = "Specific")]
    [Parameter(Mandatory = $false,Position = 0,ParameterSetName = "List")]
    [string]$Family,

    [Parameter(Mandatory = $false,Position = 2,ParameterSetName = "Severity")]
    [Parameter(Mandatory = $false,Position = 2,ParameterSetName = "Specific")]
    [Parameter(Mandatory = $false,Position = 1,ParameterSetName = "List")]
    [string]$Url = "https://hpia.hpcloud.hp.com/downloads/capsule",

    [Parameter(Mandatory = $false,Position = 3,ParameterSetName = "Severity")]
    [Parameter(Mandatory = $false,Position = 3,ParameterSetName = "Specific")]
    [switch]$Quiet,

    [Parameter(Mandatory = $false,Position = 4,ParameterSetName = "Severity")]
    [Parameter(Mandatory = $false,Position = 4,ParameterSetName = "Specific")]
    [string]$SaveAs,

    [Parameter(Mandatory = $false,Position = 5,ParameterSetName = "Severity")]
    [Parameter(Mandatory = $false,Position = 5,ParameterSetName = "Specific")]
    [switch]$Download,

    [Parameter(Mandatory = $false,Position = 6,ParameterSetName = "Severity")]
    [Parameter(Mandatory = $false,Position = 6,ParameterSetName = "Specific")]
    [switch]$Flash,

    [Parameter(Mandatory = $false,Position = 7,ParameterSetName = "Severity")]
    [Parameter(Mandatory = $false,Position = 7,ParameterSetName = "Specific")]
    [switch]$Yes,

    [Parameter(Mandatory = $false,Position = 8,ParameterSetName = "Severity")]
    [Parameter(Mandatory = $false,Position = 8,ParameterSetName = "Specific")]
    [switch]$Force,

    [Parameter(Mandatory = $true,Position = 2,ParameterSetName = "List")]
    [switch]$List
  )

  if ($Family -and -not $Version) {
    $_,$biosVersion = Get-HPPrivateBIOSFamilyNameAndVersion
    $biosFamily = $Family
  }
  elseif (-not $Family -and $Version) {
    $biosFamily,$_ = Get-HPPrivateBIOSFamilyNameAndVersion
    $biosVersion = $Version
  }
  elseif (-not $Version -and -not $Family) {
    $biosFamily,$biosVersion = Get-HPPrivateBIOSFamilyNameAndVersion
  } else {
    $biosFamily = $Family
    $biosVersion = $Version
  }

  [string]$uri = [string]"$Url/{0}/{0}.json" -f $biosFamily.ToUpper()
  Write-Verbose "Retrieving $biosFamily catalog $uri"
  Write-Verbose "BIOS Version: $biosVersion"

  $ua = Get-HPPrivateUserAgent
  [System.Net.ServicePointManager]::SecurityProtocol = Get-HPPrivateAllowedHttpsProtocols
  try {
    $data = Invoke-WebRequest -Uri $uri -UserAgent $ua -UseBasicParsing -ErrorAction Stop
  }
  catch {
    Write-Verbose $_.Exception
    Write-Host "Platform $biosFamily is not supported yet"
    throw [System.Management.Automation.ItemNotFoundException]"Unable to retrieve the BIOS update catalog for platform family $biosFamily."
  }

  $doc = [System.IO.StreamReader]::new($data.RawContentStream).ReadToEnd() | ConvertFrom-Json

  if ($List.IsPresent) {
    $data = $doc | Sort-Object -Property biosVersion -Descending
    return $data | Format-Table -Property biosFamily,biosVersion,severity,isLatest,IsLatestCritical
  }

  if ($PSCmdlet.ParameterSetName -eq "Specific") {
    $filter = $doc | Where-Object { $_.BiosVersion -eq $biosVersion } # specific
    Write-Verbose "Locating a specific version"
    if ($null -eq $filter) {
      throw "The version specified is not available on the $biosFamily catalog"
    }
  }
  elseif ($Severity -eq "LatestCritical") {
    $filter = $doc | Where-Object { $_.isLatestCritical -eq $true } # latest critical
    Write-Verbose "Locating the latest critical version available"
  }
  else {
    $filter = $doc | Where-Object { $_.isLatest -eq $true } # latest
    Write-Verbose "Locating the latest version available"
  }

  $sort = $filter | Sort-Object -Property biosVersion -Descending
  @{
    Family = $sort[0].biosFamily
    Version = $sort[0].BiosVersion
  }

  if ($Flash.IsPresent) {
    $running = Get-HPBIOSVersion
    if (-not $Yes.IsPresent) {
      Write-Host -ForegroundColor Cyan "Are you sure you want to flash this system with version '$($sort[0].biosVersion)'?"
      Write-Host -ForegroundColor Cyan "Current BIOS version is $running."
      Write-Host -ForegroundColor Cyan "A reboot will be required for the operation to complete."
      $response = Read-Host -Prompt "Type 'Y' to continue and anything else to abort. Or specify -Yes on the command line to skip this prompt"
      if ($response -ne "Y") {
        Write-Verbose "User did not confirm and did not disable confirmation, aborting."
        return
      }
    }
    if ((-not $Force.IsPresent) -and $running.TrimStart("0").trim() -ge $sort[0].BiosVersion.TrimStart("0").trim()) {
      Write-Host "This system is already running BIOS version $($sort[0].biosVersion) or newer."
      Write-Host -ForegroundColor Cyan "You can specify -Force on the command line to proceed anyway."
      return
    }
  }

  if ($Download.IsPresent -or $Flash.IsPresent) {
    Write-Verbose "Download from $($sort[0].url)"
    if ($SaveAs) {
      $localFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SaveAs)
    } else {
      $extension = ($sort[0].url -split '\.')[-1]
      $SaveAs = Get-HPPrivateTemporaryFileName -FileName "$($sort[0].biosFamily)_$($sort[0].biosVersion -Replace '\.').$extension"
      $localFile = [IO.Path]::GetFullPath($SaveAs)
    }
    Write-Verbose "LocalFile: $localFile"

    $download_params = @{
      NoClobber = "yes"
      url = $sort[0].url
      Target = $localFile
      progress = ($Quiet.IsPresent -eq $false)
    }
    try {
      Invoke-HPPrivateDownloadFile @download_params
    }
    catch {
      Write-Verbose $_.Exception
      throw [System.Management.Automation.ItemNotFoundException]"Unable to download the BIOS update archive from $($download_params.url)."
    }
    Write-Host "Saved as $localFile"

    $hash = (Get-FileHash $localFile -Algorithm SHA1).Hash
    $bytes = [byte[]] -split ($hash -replace '..','0x$& ')
    $base64 = [System.Convert]::ToBase64String($bytes)
    if ($base64 -eq $sort[0].digest) {
      Write-Verbose "Integrity check passed"
    }
    else {
      throw "Cab file integrity check failed"
    }
  }

  if ($Flash.IsPresent) {
    Add-HPBIOSWindowsUpdateScripts -WindowsUpdateFile $localFile
  }
}

function Get-HPPrivatePSScriptsEntries {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,Position = 0)]
    [string]$Path = "${env:SystemRoot}\System32\GroupPolicy\Machine\Scripts\psscripts.ini"
  )

  $types = '[Logon]','[Logoff]','[Startup]','[Shutdown]'
  $cmdLinesSet = @{}
  $parametersSet = @{}

  if ([System.IO.File]::Exists($Path)) {
    $contents = Get-Content $Path
    if ($contents) {
      for ($i = 0; $i -lt $contents.Length; $i++) {
        if ($types.contains($contents[$i])) {
          $t = $contents[$i]
          $cmdLinesSet[$t] = [System.Collections.ArrayList]@()
          $parametersSet[$t] = [System.Collections.ArrayList]@()
          continue
        }
        if ($contents[$i].Length -gt 0) {
          $cmdLinesSet[$t].Add($contents[$i].substring(1)) | Out-Null
          $parametersSet[$t].Add($contents[$i + 1].substring(1)) | Out-Null
          $i++
        }
      }
    }
  }

  $cmdLinesSet,$parametersSet
}

function Set-HPPrivatePSScriptsEntries {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,Position = 0)]
    $CmdLines,

    [Parameter(Mandatory = $true,Position = 1)]
    $Parameters,

    [Parameter(Mandatory = $false,Position = 2)]
    [string]$Path = "${env:SystemRoot}\System32\GroupPolicy\Machine\Scripts\psscripts.ini"
  )

  $types = '[Logon]','[Logoff]','[Startup]','[Shutdown]'
  $contents = ""
  foreach ($type in $types) {
    if ($CmdLines.contains($type)) {
      for ($i = 0; $i -lt $CmdLines[$type].Count; $i++) {
        if ($i -eq 0) {
          $contents += "$type`n"
        }
        $contents += "$($i)$($CmdLines[$type][$i])`n"
        $contents += "$($i)$($Parameters[$type][$i])`n"
      }
      $contents += "`n"
    }
  }

  if (-not [System.IO.File]::Exists($Path)) {
    New-Item -Force -Path $Path -Type File
  }
  $contents | Set-Content -Path $Path -Force
}

<#
.SYNOPSIS
  Add a PowerShell script to the group policy

.DESCRIPTION
  This function adds a PowerShell script to the group policy that runs at Startup or Shutdown. This function is invoked by Add-HPBIOSWindowsUpdateScripts.

.PARAMETER Type
  Type of the script, if it runs at Startup or Shutdown.

.PARAMETER CmdLine
  The command line, it is also possible to specify as CmdLine a path to a PowerShell script.

.PARAMETER Parameters
  The parameters to be passed to the script at the execution time.

.PARAMETER Path
  If needed, a custom path can be specified.

.EXAMPLE
  Add-PSScriptsEntry -Type 'Shutdown' -CmdLine 'myscript.ps1'

.EXAMPLE
  Add-PSScriptsEntry -Type 'Startup' -CmdLine 'myscript.ps1'

.EXAMPLE
  Add-PSScriptsEntry -Type 'Startup' -CmdLine 'myscript.ps1' -Parameters 'myparam'
#>
function Add-PSScriptsEntry
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Add%E2%80%90PSScriptsEntry")]
  param(
    [ValidateSet('Startup','Shutdown')]
    [Parameter(Mandatory = $true,Position = 0)]
    [string]$Type,

    [Parameter(Mandatory = $true,Position = 1)]
    [string]$CmdLine,

    [Parameter(Mandatory = $false,Position = 2)]
    [string]$Parameters,

    [Parameter(Mandatory = $false,Position = 3)]
    [string]$Path = "${env:SystemRoot}\System32\GroupPolicy\Machine\Scripts\psscripts.ini"
  )

  $cmdLinesSet,$parametersSet = Get-HPPrivatePSScriptsEntries -Path $Path

  if (-not $cmdLinesSet.ContainsKey("[$Type]")) {
    $cmdLinesSet["[$Type]"] = [System.Collections.ArrayList]@()
  }
  if (-not $parametersSet.ContainsKey("[$Type]")) {
    $parametersSet["[$Type]"] = [System.Collections.ArrayList]@()
  }

  if (-not $cmdLinesSet["[$Type]"].contains("CmdLine=$CmdLine")) {
    $cmdLinesSet["[$Type]"].Add("CmdLine=$CmdLine") | Out-Null
    $parametersSet["[$Type]"].Add("Parameters=$Parameters") | Out-Null
  }

  Set-HPPrivatePSScriptsEntries -CmdLines $cmdLinesSet -Parameters $parametersSet -Path $Path
}

<#
.SYNOPSIS
  Remove a PowerShell script from the group policy

.DESCRIPTION
  This function removes a PowerShell script from the group policy that runs at Startup or Shutdown. Returns true if some entry was removed. This function is invoked by Add-HPBIOSWindowsUpdateScripts.

.PARAMETER Type
  Type of the script, if it runs at Startup or Shutdown.

.PARAMETER CmdLine
  The command line, it is also possible to specify as CmdLine a path to a PowerShell script.

.PARAMETER Parameters
  The parameters to be passed to the script at the execution time.

.PARAMETER Path
  If needed, a custom path can be specified.

.EXAMPLE
  Remove-PSScriptsEntry -Type 'Shutdown' -CmdLine 'myscript.ps1'

.EXAMPLE
  Remove-PSScriptsEntry -Type 'Startup' -CmdLine 'myscript.ps1'

.EXAMPLE
  Remove-PSScriptsEntry -Type 'Startup' -CmdLine 'myscript.ps1' -Parameters 'myparam'
#>
function Remove-PSScriptsEntry
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Remove%E2%80%90PSScriptsEntry")]
  param(
    [ValidateSet('Startup','Shutdown')]
    [Parameter(Mandatory = $true,Position = 0)]
    [string]$Type,

    [Parameter(Mandatory = $true,Position = 1)]
    [string]$CmdLine,

    [Parameter(Mandatory = $false,Position = 2)]
    [string]$Parameters,

    [Parameter(Mandatory = $false,Position = 3)]
    [string]$Path = "${env:SystemRoot}\System32\GroupPolicy\Machine\Scripts\psscripts.ini"
  )

  $cmdLinesSet,$parametersSet = Get-HPPrivatePSScriptsEntries -Path $Path

  if (-not $cmdLinesSet.ContainsKey("[$Type]") -and -not $parametersSet.ContainsKey("[$Type]")) {
    # File doesn't contain the type specified. There is nothing to be removed
    return
  }

  $removed = $false
  # If a parameter is specified we remove only the scripts with the specified parameter from the file
  while ($cmdLinesSet["[$Type]"].contains("CmdLine=$CmdLine") -and
    (-not $Parameters -or $parametersSet["[$Type]"].item($cmdLinesSet["[$Type]"].IndexOf("CmdLine=$CmdLine")) -eq "Parameters=$Parameters")
  ) {
    $index = $cmdLinesSet["[$Type]"].IndexOf("CmdLine=$CmdLine")
    $cmdLinesSet["[$Type]"].RemoveAt($index) | Out-Null
    $parametersSet["[$Type]"].RemoveAt($index) | Out-Null
    $removed = $true
  }

  Set-HPPrivatePSScriptsEntries -CmdLines $cmdLinesSet -Parameters $parametersSet -Path $Path
  return $removed
}

<#
.SYNOPSIS
  Apply BIOS updates using a Windows Update image (subject to change)

.DESCRIPTION
  This function extracts the Windows Update file and prepares the system to receive a BIOS update. This function is invoked by Get-HPBIOSWindowsUpdate.

.PARAMETER WindowsUpdateFile
  A compressed file downloaded from the HP catalog using Get-HPBIOSWindowsUpdate function to be installed on the current system.

.NOTES
  Requires Windows group policy support

.EXAMPLE
  Add-HPBIOSWindowsUpdateScripts -WindowsUpdateFile .\zipFile.zip
#>
function Add-HPBIOSWindowsUpdateScripts {
  [CmdletBinding(DefaultParameterSetName = "Default",HelpUri = "https://developers.hp.com/hp-client-management/doc/Add%E2%80%90HPBIOSWindowsUpdateScripts")]
  param(
    [Parameter(Mandatory = $true,Position = 0,ParameterSetName = "Default")]
    [string]$WindowsUpdateFile
  )

  $gpt = "${env:SystemRoot}\System32\GroupPolicy\gpt.ini"
  $scripts = "${env:SystemRoot}\System32\GroupPolicy\Machine"

  New-Item -ItemType Directory -Force -Path "$scripts\Scripts" | Out-Null
  New-Item -ItemType Directory -Force -Path "$scripts\Scripts\Startup" | Out-Null
  New-Item -ItemType Directory -Force -Path "$scripts\Scripts\Shutdown" | Out-Null

  $fileName = ($WindowsUpdateFile -split '\\')[-1]
  $directory = $WindowsUpdateFile -replace $fileName,''
  $fileName = $fileName.substring(0,$fileName.Length - 4)
  $expectedDir = "$directory$fileName.cab.dir"
  Invoke-HPPrivateExpandCAB -cab $WindowsUpdateFile -expectedFile $WindowsUpdateFile
  $inf = Get-ChildItem -Path $expectedDir -File -Filter "$fileName*.inf" -Name
  if (-not $inf) {
    Remove-Item $expectedDir -Force -Recurse
    throw "Invalid cab file, did not find .inf in contents"
  }
  $infFileName = $inf.substring(0,$inf.Length - 4)
  Remove-Item $WindowsUpdateFile -Force
  Remove-Item -Recurse -Force "$scripts\Scripts\Shutdown\wu_image" -ErrorAction Ignore
  Move-Item $expectedDir "$scripts\Scripts\Shutdown\wu_image" -Force
  $log = ".\wu_bios_update.log"

  # CMSL modules should be included at startup to use Remove-PSScriptsEntry function
  $clientManagementModulePath = (Get-Module -Name HP.ClientManagement).Path
  $privateModulePath = (Get-Module -Name HP.Private).Path

  # Move DeviceInstall service to be notified after the Group Policy shutdown script
  $preshutdownOrder = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "PreshutdownOrder").PreshutdownOrder | Where-Object { $_ -ne "DeviceInstall" }
  $preshutdownOrder += "DeviceInstall"
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "PreshutdownOrder" -Value $preshutdownOrder -Force -ErrorAction SilentlyContinue | Out-Null

  # Startup script
  '$driver = Get-WmiObject Win32_PnPSignedDriver | ? DeviceClass -eq "Firmware" | Where Manufacturer -eq "HP Inc."
$infName = $driver.InfName
if ($infName) {
  Write-Host "INF name: $infName" *>> ' + $log + '
  ' + ${env:SystemRoot} + '\System32\pnputil.exe  /delete-driver $infName /uninstall /force *>> ' + $log + '
} else {
  Write-Host "No device to clean up" *>> ' + $log + '
}

Write-Host "Clean EFI partition" *>> ' + $log + '
$volumes = Get-Volume | Select-Object `
  @{ Name = "Path"; Expression = { $_.Path } },`
  @{ Name = "Mount"; Expression = { $_.DriveType } },`
  @{ Name = "Type"; Expression = { (Get-Partition -Volume $_).type } },`
  @{ Name = "Disk"; Expression = { (Get-Partition -Volume $_).DiskNumber } }
$volumes = $volumes | Where-Object Mount -EQ "Fixed"
[array]$efi = $volumes | Where-Object { $_.type -eq "System" }
[array]$efi = $efi | Where-Object { (Get-Disk -Number $_.Disk).OperationalStatus -eq "Online" }
[array]$efi = $efi | Where-Object { (Get-Disk -Number $_.Disk).IsBoot -eq $true }
Remove-Item "$($efi[0].Path)EFI\HP\DEVFW\*" -Recurse -Force -ErrorAction Ignore *>> ' + $log + '

Remove-Item -Force ' + ${env:SystemRoot} + '\System32\GroupPolicy\Machine\Scripts\Startup\wu_startup.ps1 *>> ' + $log + '
Remove-Item -Force ' + ${env:SystemRoot} + '\System32\GroupPolicy\Machine\Scripts\Shutdown\wu_shutdown.ps1 *>> ' + $log + '
Remove-Item -Recurse -Force ' + ${env:SystemRoot} + '\System32\GroupPolicy\Machine\Scripts\Shutdown\wu_image *>> ' + $log + '

if (Get-Module -Name HP.Private) {remove-module -force HP.Private }
if (Get-Module -Name HP.ClientManagement) {remove-module -force HP.ClientManagement }
Import-Module -Force ' + $privateModulePath + ' *>> ' + $log + '
Import-Module -Force ' + $clientManagementModulePath + ' -Function Remove-PSScriptsEntry *>> ' + $log + '
Remove-PSScriptsEntry -Type "Startup" -CmdLine wu_startup.ps1 *>> ' + $log + '
Remove-PSScriptsEntry -Type "Shutdown" -CmdLine wu_shutdown.ps1 *>> ' + $log + '
gpupdate /wait:0 /force /target:computer *>> ' + $log + '
' | Out-File "$scripts\Scripts\Startup\wu_startup.ps1"

  # Shutdown script
  'param($wu_inf_name)

net start DeviceInstall *>> ' + $log + '
$driver = Get-WmiObject Win32_PnPSignedDriver | ? DeviceClass -eq "Firmware" | Where Manufacturer -eq "HP Inc."
$infName = $driver.InfName
if ($infName) {
  Write-Host "INF name: $infName" *>> ' + $log + '
  ' + ${env:SystemRoot} + '\System32\pnputil.exe  /delete-driver $infName /uninstall /force *>> ' + $log + '
} else {
  Write-Host "No device to clean up" *>> ' + $log + '
}

Write-Host "Clean EFI partition" *>> ' + $log + '
$volumes = Get-Volume | Select-Object `
  @{ Name = "Path"; Expression = { $_.Path } },`
  @{ Name = "Mount"; Expression = { $_.DriveType } },`
  @{ Name = "Type"; Expression = { (Get-Partition -Volume $_).type } },`
  @{ Name = "Disk"; Expression = { (Get-Partition -Volume $_).DiskNumber } }
$volumes = $volumes | Where-Object Mount -EQ "Fixed"
[array]$efi = $volumes | Where-Object { $_.type -eq "System" }
[array]$efi = $efi | Where-Object { (Get-Disk -Number $_.Disk).OperationalStatus -eq "Online" }
[array]$efi = $efi | Where-Object { (Get-Disk -Number $_.Disk).IsBoot -eq $true }
Remove-Item "$($efi[0].Path)EFI\HP\DEVFW\*" -Recurse -Force -ErrorAction Ignore *>> ' + $log + '

$volume = Get-BitLockerVolume | Where-Object VolumeType -EQ "OperatingSystem"
if ($volume.ProtectionStatus -ne "Off") {
  Suspend-BitLocker -MountPoint $volume.MountPoint -RebootCount 1 *>> ' + $log + '
}

Write-Host "Invoke pnputil to update the BIOS" *>> ' + $log + '
' + ${env:SystemRoot} + '\System32\pnputil.exe /add-driver ' + ${env:SystemRoot} + '\System32\GroupPolicy\Machine\Scripts\Shutdown\wu_image\$wu_inf_name.inf /install *>> ' + $log + '
Write-Host "WU driver installed" *>> ' + $log + '

$volume = Get-BitLockerVolume | Where-Object VolumeType -EQ "OperatingSystem"
if ($volume.ProtectionStatus -ne "Off") {
  Suspend-BitLocker -MountPoint $volume.MountPoint -RebootCount 1 *>> ' + $log + '
}
' | Out-File "$scripts\Scripts\Shutdown\wu_shutdown.ps1"

  "[General]`ngPCMachineExtensionNames=[{42B5FAAE-6536-11D2-AE5A-0000F87571E3}{40B6664F-4972-11D1-A7CA-0000F87571E3}]`nVersion=65537" | Set-Content -Path $gpt -Force

  Remove-PSScriptsEntry -Type "Startup" -CmdLine "wu_startup.ps1" | Out-Null
  Remove-PSScriptsEntry -Type "Shutdown" -CmdLine "wu_shutdown.ps1" | Out-Null
  Add-PSScriptsEntry -Type "Startup" -CmdLine "wu_startup.ps1"
  Add-PSScriptsEntry -Type "Shutdown" -CmdLine "wu_shutdown.ps1" -Parameters "$infFileName"
  gpupdate /wait:0 /force /target:computer
  Write-Host -ForegroundColor Cyan "Firmware image has been deployed. The process will continue after reboot."
}

<#
 .SYNOPSIS
  Get platform name, system ID, or operating system support using either the platform name or its system ID.

.DESCRIPTION
  This function retrieves information about the platform, given a platform name or system id. It can be used to convert between platform name and system IDs. Note that a platform may have multiple system IDs, or a system ID may map to multiple platforms.

  Currently returns the following information:

  - SystemID - the system iD for this platform
  - FamilyID - the platform family ID
  - Name - the name of the platform
  - DriverPackSupport - this platform supports driver packs

  Get-HPDeviceDetails functionality is not supported in WinPE.

.PARAMETER Platform
  Query by platform id (a 4-digit hexadecimal number).

.PARAMETER Name
  Query  by platform name. The name must match exactly, unless the -match parameter is also specified.

.PARAMETER Like
  Relax the match to a substring match. if the platform contains the substring defined by the -Name parameter, it will be included in the return. This parameter can also be specified as Match, for backwards compatibility.

  This parameter is now obsolete and may be removed at a future time. You can simply pass wildcards in the name field instead of using the like parameter.
  The following two examples are identical:

    Get-HPDeviceDetails -name '\*EliteBook\*'

  is the same as:

    Get-HPDeviceDetails -like -name 'EliteBook'

.PARAMETER OSList
  Return the list of supported operating systems for the specified platform.

.EXAMPLE
  Get-HPDeviceDetails -Platform 8100

.EXAMPLE
  Get-HPDeviceDetails -Name 'HP ProOne 400 G3 20-inch Touch All-in-One PC'

.EXAMPLE
  Get-HPDeviceDetails -Like -Name '840 G5'

#>
function Get-HPDeviceDetails {
  [CmdletBinding(
    DefaultParameterSetName = "FromID",
    HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPDeviceDetails")
  ]
  param(
    [ValidatePattern("^[a-fA-F0-9]{4}$")]
    [Parameter(Mandatory = $false,Position = 0,ParameterSetName = "FromID")]
    [string]$Platform,

    [Parameter(Mandatory = $true,Position = 1,ParameterSetName = "FromName")]
    [string]$Name,

    [Parameter(Mandatory = $false,Position = 1,ParameterSetName = "FromName")]
    [Alias('Match')]
    [switch]$Like,

    [switch][Parameter(Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "FromName")]
    [Parameter(ParameterSetName = "FromID")]
    $OSList
  )

  if (Test-WinPE -Verbose:$VerbosePreference) { throw "Getting HP Device details is not supported in WinPE" }

  $url = "https://hpia.hpcloud.hp.com/ref/platformList.cab"
  $filename = "platformList.cab"
  $try_on_ftp = $false

  try {
    $file = Get-HPPrivateOfflineCacheFiles -url $url -FileName $filename -Expand -Verbose:$VerbosePreference
  }
  catch {
    # platformList is not reachable on AWS, try to get it from FTP
    $try_on_ftp = $true
  }

  if ($try_on_ftp)
  {
    try {
      $url = "https://ftp.hp.com/pub/caps-softpaq/cmit/imagepal/ref/platformList.cab"
      $file = Get-HPPrivateOfflineCacheFiles -url $url -FileName $filename -Expand -Verbose:$VerbosePreference
    }
    catch {
      Write-Host -ForegroundColor Magenta "platformList is not available on AWS or FTP."
      throw [System.Net.WebException]"Could not find platformList."
    }
  }

  if (-not $platform -and -not $Name) {
    try { $platform = Get-HPDeviceProductID -Verbose:$VerbosePreference }
    catch { Write-Verbose "No platform found." }
  }
  if ($platform) {
    $platform = $platform.ToLower()
  }
  if ($PSCmdlet.ParameterSetName -eq "FromID") {
    $data = Select-Xml -Path "$file" -XPath "/ImagePal/Platform/SystemID[normalize-space(.)=`"$platform`"]/parent::*"
  }
  else {
    $data = Select-Xml -Path "$file" -XPath "/ImagePal/Platform/ProductName[translate(substring(`"$($name.ToLower())`",0), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')]/parent::*"
  }

  if (-not $data) { return }

  $searchName = $Name
  if ($Like.IsPresent)
  {
    if (-not ($searchName).StartsWith('*')) { $searchName = ("*$searchName") }
    if (-not ($searchName).EndsWith('*')) { $searchName = ("$searchName*") }
  }

  $data.Node | ForEach-Object {
    $__ = $_
    $pn = $_.ProductName. "#text"

    if ($oslist.IsPresent) {
      [array]$r = ($__.OS | ForEach-Object {
          if (($PSCmdlet.ParameterSetName -eq "FromID") -or ($pn -like $searchName)) {
            $rid = $Null
            if ("OSReleaseId" -in $_.PSObject.Properties.Name) { $rid = $_.OSReleaseId }

            [string]$osv = $_.OSVersion
            if ("OSReleaseIdDisplay" -in $_.PSObject.Properties.Name -and $_.OSReleaseIdDisplay -ne '20H2') {
              $rid = $_.OSReleaseIdDisplay
            }

            $obj = New-Object -TypeName PSCustomObject -Property @{
              SystemID = $__.SystemID.ToUpper()
              OperatingSystem = $_.OSDescription
              OperatingSystemVersion = $osv
              Architecture = $_.OSArchitecture
            }
            if ($rid) {
              $obj | Add-Member -NotePropertyName OperatingSystemRelease -NotePropertyValue $rid
            }
            if ("OSBuildId" -in $_.PSObject.Properties.Name) {
              $obj | Add-Member -NotePropertyName BuildNumber -NotePropertyValue $_.OSBuildId
            }
            $obj
          }
        })
    }
    else {

      [array]$r = ($__.ProductName | ForEach-Object {
          if (($PSCmdlet.ParameterSetName -eq "FromID") -or ($_. "#text" -like $searchName)) {
            New-Object -TypeName PSCustomObject -Property @{
              SystemID = $__.SystemID.ToUpper()
              Name = $_. "#text"
              DriverPackSupport = $result = [System.Convert]::ToBoolean($_.DPBCompliant)
            }
          }
        })
    }
    return $r
  }
}



function getFormattedBiosSettingValue {
  [CmdletBinding()]
  param($obj)
  switch ($obj.CimClass.CimClassName) {
    { $_ -eq 'HPBIOS_BIOSString' } {
      $result = $obj.Value

    }
    { $_ -eq 'HPBIOS_BIOSInteger' } {
      $result = $obj.Value
    }
    { $_ -eq 'HPBIOS_BIOSEnumeration' } {
      $result = $obj.CurrentValue
    }
    { $_ -eq 'HPBIOS_BIOSPassword' } {
      throw [System.InvalidOperationException]"Password values cannot be retrieved, it will always result in an empty string"
    }
    { $_ -eq 'HPBIOS_BIOSOrderedList' } {
      $result = $obj.Value
    }
  }
  return $result
}

function getWmiField ($obj,$fn) { $obj.$fn }


# format a setting using BCU (custom) format
function convertSettingToBCU ($setting) {
  #if ($setting.DisplayInUI -eq 0) { return }
  switch ($setting.CimClass.CimClassName) {
    { $_ -eq 'HPBIOS_BIOSString' } {
      Write-Output $setting.Name

      if ($setting.Value.contains("`n")) {
        $setting.Value.Split("`n") | ForEach-Object {
          $c = $_.trim()
          Write-Output "`t$c" }
      }
      else {
        Write-Output "`t$($setting.Value)"
      }

    }
    { $_ -eq 'HPBIOS_BIOSInteger' } {
      Write-Output $setting.Name
      Write-Output "`t$($setting.Value)"
    }
    { $_ -eq 'HPBIOS_BIOSPassword' } {
      Write-Output $setting.Name
      Write-Output ""
    }
    { $_ -eq 'HPBIOS_BIOSEnumeration' } {
      Write-Output $setting.Name
      $fields = $setting.Value.Split(",")
      foreach ($f in $fields) {
        Write-Output "`t$f"
      }
    }
    { $_ -eq 'HPBIOS_BIOSOrderedList' } {
      Write-Output $setting.Name
      if ($null -ne $setting.Value) {
        $fields = $setting.Value.Split(",")
        foreach ($f in $fields) {
          Write-Output "`t$f"
        }
      }
      else {
        Write-Output "`t$($setting.Value)"
      }
    }
  }
}

function formatBiosVersionsOutputList ($doc) {
  switch ($format) {
    "json" { return $doc | ConvertTo-Json }
    "xml" {
      Write-Output "<bios id=`"$platform`">"
      if ($all)
      {
        $doc | ForEach-Object { Write-Output "<item><ver>$($_.Ver)</ver><bin>$($_.bin)</bin><date>$($_.date)</date><rollback_allowed>$($_.RollbackAllowed)</rollback_allowed><importance>$($_.Importance)</importance></item>" }
      }
      else {
        $doc | ForEach-Object { Write-Output "<item><ver>$($_.Ver)</ver><bin>$($_.bin)</bin><date>$($_.date)</date></item>" }
      }
      Write-Output "</bios>"
      return
    }
    "csv" {
      return $doc | ConvertTo-Csv -NoTypeInformation
    }
    "list" { $doc | ForEach-Object { Write-Output "$($_.Bin) version $($_.Ver.TrimStart("0")), released $($_.Date)" } }
    default { return $doc }
  }
}


# format a setting using HPIA (xml) format
function convertSettingToXML ($setting) {
  #if ($setting.DIsplayInUI -eq 0) { return }
  Write-Output "     <BIOSSetting>"
  Write-Output "        <Name>$([System.Web.HttpUtility]::HtmlEncode($setting.Name))</Name>"
  Write-Output "        <Class>$($setting.CimClass.CimClassName)</Class>"
  Write-Output "        <DisplayInUI>$($setting.DisplayInUI)</DisplayInUI>"
  Write-Output "        <IsReadOnly>$($setting.IsReadOnly)</IsReadOnly>"
  Write-Output "        <RequiresPhysicalPresence>$($setting.RequiresPhysicalPresence)</RequiresPhysicalPresence>"
  Write-Output "        <Sequence>$($setting.Sequence)</Sequence>"

  switch ($setting.CimClass.CimClassName) {
    { $_ -eq 'HPBIOS_BIOSPassword' } {
      Write-Output "        <Value></Value>"
      Write-Output "        <Min>$($setting.MinLength)</Min>"
      Write-Output "        <Max>$($setting.MaxLength)</Max>"

      Write-Output "        <SupportedEncodings Count=""$($setting.SupportedEncoding.Count)"">"
      foreach ($e in $setting.SupportedEncoding) {
        Write-Output "          <Encoding>$e</Encoding>"
      }
      Write-Output "        </SupportedEncodings>"
    }

    { $_ -eq 'HPBIOS_BIOSString' } {
      Write-Output "        <Value>$([System.Web.HttpUtility]::HtmlEncode($setting.Value))</Value>"
      Write-Output "        <Min>$($setting.MinLength)</Min>"
      Write-Output "        <Max>$($setting.MaxLength)</Max>"
    }

    { $_ -eq 'HPBIOS_BIOSInteger' } {
      Write-Output "        <Value>$($setting.Value)</Value>"
      #Write-Output "        <DisplayInUI>$($setting.DisplayInUI)</DisplayInUI>"
      Write-Output "        <Min>$($setting.LowerBound)</Min>"
      Write-Output "        <Max>$($setting.UpperBound)</Max>"
    }

    { $_ -eq 'HPBIOS_BIOSEnumeration' } {
      Write-Output "        <Value>$([System.Web.HttpUtility]::HtmlEncode($setting.CurrentValue))</Value>"
      Write-Output "        <ValueList Count=""$($setting.Size)"">"
      foreach ($e in $setting.PossibleValues) {
        Write-Output "          <Value>$([System.Web.HttpUtility]::HtmlEncode($e))</Value>"
      }
      Write-Output "        </ValueList>"
    }

    { $_ -eq 'HPBIOS_BIOSOrderedList' } {
      Write-Output "        <Value>$([System.Web.HttpUtility]::HtmlEncode($setting.Value))</Value>"
      Write-Output "        <ValueList Count=""$($setting.Size)"">"
      foreach ($e in $setting.Elements) {
        Write-Output "          <Value>$([System.Web.HttpUtility]::HtmlEncode($e))</Value>"
      }
      Write-Output "        </ValueList>"
    }
  }
  Write-Output "     </BIOSSetting>"
}

function convertSettingToJSON ($original_setting) {

  $setting = $original_setting | Select-Object *

  if ($setting.CimClass.CimClassName -eq "HPBIOS_BIOSInteger") {
    $min = $setting.LowerBound
    $max = $setting.UpperBound
    Add-Member -InputObject $setting -Name "Min" -Value $min -MemberType NoteProperty
    Add-Member -InputObject $setting -Name "Max" -Value $max -MemberType NoteProperty

    $d = $setting | Select-Object -Property Class,DisplayInUI,InstanceName,IsReadOnly,Min,Max,Name,Path,Prerequisites,PrerequisiteSize,RequiresPhysicalPresence,SecurityLevel,Sequence,Value
  }

  if (($setting.CimClass.CimClassName -eq "HPBIOS_BIOSString") -or ($setting.CimClass.CimClassName -eq "HPBIOS_BIOSPassword")) {
    $min = $setting.MinLength
    $max = $setting.MaxLength
    Add-Member -InputObject $setting -Name "Min" -Value $min -MemberType NoteProperty -Force
    Add-Member -InputObject $setting -Name "Max" -Value $max -MemberType NoteProperty -Force
    $d = $setting | Select-Object -Property Class,DisplayInUI,InstanceName,IsReadOnly,Min,Max,Name,Path,Prerequisites,PrerequisiteSize,RequiresPhysicalPresence,SecurityLevel,Sequence,Value
  }

  if ($setting.CimClass.CimClassName -eq "HPBIOS_BIOSEnumeration") {
    $min = $setting.Size
    $max = $setting.Size
    #Add-Member -InputObject $setting -Name "Min" -Value $min -MemberType NoteProperty
    #Add-Member -InputObject $setting -Name "Max" -Value $max -MemberType NoteProperty
    $setting.Value = $setting.CurrentValue
    $d = $setting | Select-Object -Property Class,DisplayInUI,InstanceName,IsReadOnly,Min,Max,Name,Path,Prerequisites,PrerequisiteSize,RequiresPhysicalPresence,SecurityLevel,Sequence,Value,PossibleValues
  }

  if ($setting.CimClass.CimClassName -eq "HPBIOS_BIOSOrderedList") {
    #if Elements is null, initialize it as an empty array else select the first object
    $Elements = $setting.Elements,@() | Select-Object -First 1
    $min = $Elements.Count
    $max = $Elements.Count
    Add-Member -InputObject $setting -Name "Min" -Value $min -MemberType NoteProperty
    Add-Member -InputObject $setting -Name "Max" -Value $max -MemberType NoteProperty
    Add-Member -InputObject $setting -Name "PossibleValues" -Value $Elements -MemberType NoteProperty
    $d = $setting | Select-Object -Property Class,DisplayInUI,InstanceName,IsReadOnly,Min,Max,Name,Path,Prerequisites,PrerequisiteSize,RequiresPhysicalPresence,SecurityLevel,Sequence,Value,Elements
  }



  $d | ConvertTo-Json -Depth 5 | Write-Output
}

# format a setting as a CSV entry
function convertSettingToCSV ($setting) {
  switch ($setting.CimClass.CimClassName) {
    { $_ -eq 'HPBIOS_BIOSEnumeration' } {
      Write-Output "`"$($setting.Name)`",`"$($setting.value)`",$($setting.IsReadOnly),`"picklist`",$($setting.RequiresPhysicalPresence),$($setting.Size),$($setting.Size)"
    }
    { $_ -eq 'HPBIOS_BIOSString' } {
      Write-Output "`"$($setting.Name)`",`"$($setting.value)`",$($setting.IsReadOnly),`"string`",$($setting.RequiresPhysicalPresence),$($setting.MinLength),$($setting.MaxLength)"
    }
    { $_ -eq 'HPBIOS_BIOSPassword' } {
      Write-Output "`"$($setting.Name)`",`"`",$($setting.IsReadOnly),`"password`",$($setting.RequiresPhysicalPresence),$($setting.MinLength),$($setting.MaxLength)"
    }
    { $_ -eq 'HPBIOS_BIOSInteger' } {
      Write-Output "`"$($setting.Name)`",`"$($setting.value)`",$($setting.IsReadOnly),`"integer`",$($setting.RequiresPhysicalPresence),$($setting.LowerBound),$($setting.UpperBound)"
    }
    { $_ -eq 'HPBIOS_BIOSOrderedList' } {
      Write-Output "`"$($setting.Name)`",`"$($setting.value)`",$($setting.IsReadOnly),`"orderedlist`",$($setting.RequiresPhysicalPresence),$($setting.Size),$($setting.Size)"
    }
  }
}

function extractBIOSVersion {
  [CmdletBinding()]
  param
  (
    [Parameter(Position = 0,Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$BIOSVersion

  )
  [string]$ver = $null

  # Does the BIOS version string contains x.xx[.xx]?
  [bool]$found = $BIOSVersion -match '(\d+(\.\d+){1,2})'
  if ($found) {
    $ver = $matches[1]
    Write-Verbose "BIOS version extracted=[$ver]"
  }

  $ver
}




# SIG # Begin signature block
# MIIaygYJKoZIhvcNAQcCoIIauzCCGrcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA69MQXmIVjx9dg
# ZRr6LqxPx1NbCRee8PYbEnfHimPBq6CCCm8wggUwMIIEGKADAgECAhAECRgbX9W7
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
# BgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCCtek46s7TH2lkIRyLU+1QhMiF38JPA
# AdeQxBjNiV5c3zANBgkqhkiG9w0BAQEFAASCAQB4FihnUr0fUJrRmcC41m6mN/Yc
# 7R2MbTHNAla8FUsHS6cf5v9j8UY9PuzWrRqXCNlxSO0Xvbswpb0Mh4YI5+ldh8c8
# BJ8QC7LzEui8S8El2LPiDq3YmwOJ2QhSxl4n8wwqmqvNrnIqjvbwILE1ROEfDlSk
# SfRjk8yHAzn8qu869t6B7OPckmKJx3sov3oqRziGOPdxrDPW7BHw3ZFodoWySZ/9
# lsoHgDW0K92iBDKFdMgd5czq9QThhDvmIDpEKdKfV0oVb9xI+U6xiOzcPzQXc75M
# 0DyrdWilFEWGXrU+984kM9m0uSM6lS+HLEIdKOTJoq01Knxuk2kh+LJgkZhVoYIN
# fTCCDXkGCisGAQQBgjcDAwExgg1pMIINZQYJKoZIhvcNAQcCoIINVjCCDVICAQMx
# DzANBglghkgBZQMEAgEFADB3BgsqhkiG9w0BCRABBKBoBGYwZAIBAQYJYIZIAYb9
# bAcBMDEwDQYJYIZIAWUDBAIBBQAEIIwrzIPF2mYNcYVfQICz3jDXpgdLXPTqu5kx
# E7PWI0r3AhA5v26BdZXVpGViHz35cMRLGA8yMDIxMTEyMjE5MTkwM1qgggo3MIIE
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
# 8zAvBgkqhkiG9w0BCQQxIgQg2+m5o1f5PIIKMBxCIxQPtuemLjZbwCHtQ5K12zyZ
# +2AwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgsxCQBrwK2YMHkVcp4EQDQVyD4ykr
# YU8mlkyNNXHs9akwDQYJKoZIhvcNAQEBBQAEggEAD/Iu9Qo/qSG0qg5mzcuu/Uy7
# t5x1BTgt1LPWtJp6mKYAJvjVCjW1dgS4UYY/f/Dhq9MrcxziaeDNiTHzdygHrfsK
# MvQ3RVCj4Rn7YhSEuxclJQ7ZlzF8SdlLa9lswF84cmkAdzO9lx0dY1LqdeJ14caU
# D/U6vLepSOqnem0R5nfOp8LBMdCob0x6QqzeQ0+kiUz8/bzAxi5OmHxYA17RkB+A
# znfkFvW5T6TN1BhisA3Vt+5s/UNuhYeJ2GCHlfptslTiyKrM2xyP6qWrU906iIBv
# 41E9NXu+4MXFRpDcfAFG6lZAHT1lWrV+Xt3GQXf/6RVMfdQUJ1fXx7hkMp7w8Q==
# SIG # End signature block
