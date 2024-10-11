<# 
    2Pint functions to Manage CM Objects
    Version:        1.0
    Author:         @ 2Pint Software
    Creation Date:  2023-02-03
    Purpose/Change: Initial script development
    
#>

# https://stackoverflow.com/questions/41897114/unexpected-error-occurred-running-a-simple-unauthorized-rest-query
#C# class to create callback
$SSLHandlercode = @"
public class SSLHandler
{
    public static System.Net.Security.RemoteCertificateValidationCallback GetSSLHandler()
    {

        return new System.Net.Security.RemoteCertificateValidationCallback((sender, certificate, chain, policyErrors) => { return true; });
    }
}
"@

#compile the class
Add-Type -TypeDefinition $SSLHandlercode

Function Invoke-SQLCommand {
    <#
.SYNOPSIS
  Queries a SQL database and returs the result

.DESCRIPTION
  Queries a SQL database and returs the result

.PARAMETER SQLServerFQDN
    FQDN for the CM SQL server
    cmsql.contoso.org
    If not specified the value in CMServerFQDN will be used for SQL queries.

.PARAMETER SiteDB
    Name of the site DB
    
.INPUTS
    SQL Query

.OUTPUTS
    Returns a Dataset table from SQL query

.NOTES
  Version:        1.0
  Author:         @ 2Pint Software
  Creation Date:  2023-02-03
  Purpose/Change: Initial script development

.EXAMPLE
  Remove-CMObject -KeyIdentifier MACAddress -Value "00:11:22:33:AA" -CMServerFQDN "cm01.contoso.org" -SiteDB "CM_CEN" -SiteCode "CEN"

#>
    Param(
        [Parameter(Mandatory = $true)][string]$Query,
        [Parameter(Mandatory = $true)][string]$SQLServerFQDN,
        [Parameter(Mandatory = $true)][string]$SiteDB
    )
    Process {
        $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
        $SqlConnection.ConnectionString = "Data Source=$SQLServerFQDN;Initial Catalog=$SiteDB;Integrated Security=true"
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlCmd.CommandText = $Query
        $SqlCmd.Connection = $SqlConnection

        try {
            $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
            $SqlAdapter.SelectCommand = $SqlCmd
            $DataSet = New-Object System.Data.DataSet
            $SqlAdapter.Fill($DataSet) | Out-Null
            $SqlConnection.Close()
        }
        catch [Exception] {
            Write-Warning $_.Exception.Message
        }
        finally {
            $SqlConnection.Dispose()
            $SqlCmd.Dispose()
        }
        return $DataSet.Tables[0]
    }
}

Function Remove-CMObject {
    <#
.SYNOPSIS
  Removes a CMObject

.DESCRIPTION
  Using AdminSvc/WMI the function removes the Object and then it also executes a storepocedure on the database to clean up any old inventory data for that object.

.PARAMETER KeyIdentifier
    Determins what will be used to identify the client, valid options are:
    Name, MACAddress, SMBIOS and UUID

.PARAMETER Value
    The value that will be used for the Key Identifier

.PARAMETER CMServerFQDN
    FQDN for the CM server
    cm01.contoso.org

.PARAMETER SQLServerFQDN
    FQDN for the CM SQL server
    cmsql.contoso.org
    If not specified the value in CMServerFQDN will be used for SQL queries.

.PARAMETER SiteDB
    Name of the site DB

.PARAMETER SiteCode
    The sitecode of the CM server

.PARAMETER UseWMI
    If specified the script will use a remote WMI query instead of the Admin Service

.OUTPUTS
  None

.NOTES
  Version:        1.0
  Author:         @ 2Pint Software
  Creation Date:  2023-02-03
  Purpose/Change: Initial script development

.EXAMPLE
  Remove-CMObject -KeyIdentifier MACAddress -Value "00:11:22:33:AA" -CMServerFQDN "cm01.contoso.org" -SiteDB "CM_CEN" -SiteCode "CEN"

#>

    #---------------------------------------------------------[Script Parameters]------------------------------------------------------
    Param (
        [parameter(Mandatory = $true)]
        [ValidateSet("Name", "MACAddress", "SMBIOS", "UUID")]
        [string]$KeyIdentifier,
        [parameter(Mandatory = $true)]
        [string]$Value,
        [parameter(Mandatory = $true)]
        [string]$CMServerFQDN,
        [string]$SQLServerFQDN,
        [parameter(Mandatory = $true)]
        [string]$SiteDB,
        [parameter(Mandatory = $true)]
        [string]$SiteCode,
        [switch]$UseWMI
    )

    #---------------------------------------------------------[Initialisations]--------------------------------------------------------

    # If SQL server has not been specified we will assume that it is on the same server as CM.
    If (-not $SQLServerFQDN) { $SQLServerFQDN = $CMServerFQDN }
    $AdminService = "https://$CMServerFQDN/AdminService"

    #-----------------------------------------------------------[Execution]------------------------------------------------------------

    # SQL https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/os-deployment/unknown-computer-object-guid-stolen
    # https://techcommunity.microsoft.com/t5/configuration-manager-archive/configmgr-cb-delete-aged-discovery-data-internals-with-case/ba-p/339957
    # spRemoveResourceDataForDeletion

    If ($KeyIdentifier -eq "MACAddress") {
        $resourceQuery = "select *
From vSMS_R_System SRS
JOIN System_MAC_Addres_ARR SMAC on SRS.ItemKey = SMAC.ItemKey
WHERE SMAC.MAC_Addresses0 = '$value'"
        [array]$SQLresult = Invoke-SQLCommand -Query $resourceQuery -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB
    }
    else {
        Switch ($KeyIdentifier) {
            "SMBIOS" { $key = "SMBIOS_GUID0" }
            "UUID" {
                $key = "SMS_Unique_Identifier0"
                If (-not $value -match "^GUID:*") { $value = "GUID:$value" } 
            }
            Default { $Key = "Name0" }
        }
        $resourceQuery = "select *
From vSMS_R_System
WHERE $Key = '$value'"
        [array]$SQLresult = Invoke-SQLCommand -Query $resourceQuery -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB
    }

    If ($SQLresult) {
        If ($SQLresult.Count -eq 1) {
            $ResourceID = $SQLresult.ItemKey
        }
        else {
            Write-Debug "More that one resource matching the $KeyIdentifier = $Value what found. Select a Unique KeyIdentifier an rerun the script."
            If ($KeyIdentifier -eq "MACAddress") {
                return [Array]$($SQLresult | Select-Object -Property ItemKey, Name0, SMS_Unique_Identifier0, SMBIOS_GUID0, MAC_Addresses0)
            }
            else {
                return [Array]$($SQLresult | Select-Object -Property ItemKey, Name0, SMS_Unique_Identifier0, SMBIOS_GUID0)
            }
        }
    
    }
    else {
        Write-Debug "No computer object found with $KeyIdentifier = $value"
        return $false
    }

    if ($UseWMI) {
        $resource = $null
        [array]$resource = Get-WmiObject -ComputerName $CMServerFQDN -Namespace "ROOT\SMS\Site_$SiteCode" -ClassName SMS_R_System -Filter "ResourceID = $ResourceID"
        if ($resource) {    
            $Result = $resource | Remove-WmiObject -confirm:$false 
            
            #Verify it has been removed
            $resource = $null
            [array]$resource = Get-WmiObject -ComputerName $CMServerFQDN -Namespace "ROOT\SMS\Site_$SiteCode" -ClassName SMS_R_System -Filter "ResourceID = $ResourceID"
            if ($resource) {  
                return $resource
            }
        }
        
    }
    else {
        # Default into using the ConfigMgr Adminservice

        #Disable checks using SSLHandler class
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [SSLHandler]::GetSSLHandler()
        $Result = $null
        #do the request
        try {
   
            $URI = "$AdminService/wmi/SMS_R_System($ResourceID)" #&`$select=ResourceID,Name,NetBiosName,SMBIOSGUID,MACAddresses"
            $Params = @{
                Method               = "DELETE" # Method = "GET" DELETE
                ContentType          = "application/json"
                URI                  = $URI
                UseDefaultCredential = $True
            }
            $Result = Invoke-RestMethod @Params

            #Verify Object has been deleted
            $Result = $null
            $URI = "$AdminService/wmi/SMS_R_System($ResourceID)" #&`$select=ResourceID,Name,NetBiosName,SMBIOSGUID,MACAddresses"
            $Params = @{
                Method               = "GET" # Method = "GET" DELETE
                ContentType          = "application/json"
                URI                  = $URI
                UseDefaultCredential = $True
            }
            $Result = Invoke-RestMethod @Params
        }
        catch {
            # do something
            Write-host $error[0].Exception.Message
        }
        finally {
            #enable checks again
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
        if($($result.value))
        {
            return [array]$result.value
        } 
    }

    # Use the built in Store prodcedure to delete the resource and clean it up
    Invoke-SQLCommand -Query "Exec spRemoveResourceDataForDeletion '$ResourceID'" -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB

    # Delete from System_DISC table, last resort. Is this needed?
    [Array]$SysDISCResult = Invoke-SQLCommand -Query "Select * FROM System_DISC WHERE ItemKey = '$ResourceID'" -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB
    if($SysDISCResult) {
        Invoke-SQLCommand -Query "DELETE FROM System_DISC WHERE ItemKey = '$ResourceID'" -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB
    }
    return $true
}

Function Get-CMObject {
    <#
.SYNOPSIS
    Gets an object from CM based on a Key identifier

.DESCRIPTION
    Gets an object from CM based on a Key identifier

.PARAMETER KeyIdentifier

    Determins what will be used to identify the client, valid options are:
    Name, MACAddress, SMBIOS and UUID

.PARAMETER Value

    The value that will be used for the Key Identifier

.PARAMETER CMServerFQDN

    FQDN for the CM server
    cm01.contoso.org

.PARAMETER SQLServerFQDN

    FQDN for the CM SQL server
    cmsql.contoso.org
    If not specified the value in CMServerFQDN will be used for SQL queries.

.PARAMETER SiteDB

    Name of the site DB

.PARAMETER SiteCode

    The sitecode of the CM server

.PARAMETER UseWMI

    If specified the script will use a remote WMI query instead of the Admin Service

.OUTPUTS
    Returns the CM Object if found

.NOTES
    Version:        1.0
    Author:         @ 2Pint Software
    Creation Date:  2023-02-03
    Purpose/Change: Initial script development

.EXAMPLE
    Get-CMObject -KeyIdentifier MACAddress -Value "00:11:22:33:AA" -CMServerFQDN "cm01.contoso.org" -SiteDB "CM_CEN" -SiteCode "CEN"

#>
    
#---------------------------------------------------------[Script Parameters]------------------------------------------------------
Param (
    [parameter(Mandatory = $true)]
    [ValidateSet("Name", "MACAddress", "SMBIOS", "UUID")]
    [string]$KeyIdentifier,
    [parameter(Mandatory = $true)]
    [string]$Value,
    [parameter(Mandatory = $true)]
    [string]$CMServerFQDN,
    [string]$SQLServerFQDN,
    [parameter(Mandatory = $true)]
    [string]$SiteDB,
    [parameter(Mandatory = $true)]
    [string]$SiteCode,
    [switch]$UseWMI
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

# If SQL server has not been specified we will assume that it is on the same server as CM.
    If (-not $SQLServerFQDN) { $SQLServerFQDN = $CMServerFQDN }
    $AdminService = "https://$CMServerFQDN/AdminService"

#-----------------------------------------------------------[Execution]------------------------------------------------------------

    If ($KeyIdentifier -eq "MACAddress") {
        $resourceQuery = "select *
From vSMS_R_System SRS
JOIN System_MAC_Addres_ARR SMAC on SRS.ItemKey = SMAC.ItemKey
WHERE SMAC.MAC_Addresses0 = '$value'"
        [array]$SQLresult = Invoke-SQLCommand -Query $resourceQuery -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB
    }
    else {
        Switch ($KeyIdentifier) {
            "SMBIOS" { $key = "SMBIOS_GUID0" }
            "UUID" {
                $key = "SMS_Unique_Identifier0"
                If (-not $value -match "^GUID:*") { $value = "GUID:$value" } 
            }
            Default { $Key = "Name0" }
        }
        $resourceQuery = "select *
From vSMS_R_System
WHERE $Key = '$value'"
        [array]$SQLresult = Invoke-SQLCommand -Query $resourceQuery -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB
    }

    If ($SQLresult) {
        If ($SQLresult.Count -eq 1) {
            $ResourceID = $SQLresult.ItemKey
        }
        elseif ($SQLresult.Count -gt 1) {
            Write-Debug "More that one resource matching the $KeyIdentifier = $Value what found. Select a Unique KeyIdentifier an rerun the script."
            If ($KeyIdentifier -eq "MACAddress") {
                return [Array]$($SQLresult | Select-Object -Property ItemKey, Name0, SMS_Unique_Identifier0, SMBIOS_GUID0, MAC_Addresses0)
            }
            else {
                return [Array]$($SQLresult | Select-Object -Property ItemKey, Name0, SMS_Unique_Identifier0, SMBIOS_GUID0)
            }
        }
    }
    else {
        Write-Debug "No computer object found with $KeyIdentifier = $value"
        return $false
    }

    if ($UseWMI) {
        $resource = $null
        $resource = Get-WmiObject -ComputerName $CMServerFQDN -Namespace "ROOT\SMS\Site_$SiteCode" -ClassName SMS_R_System -Filter "ResourceID = $ResourceID"
        if($resource -eq $null)
        {
            return $false
        }

        return $resource
    }
    else {
        # Default into using the ConfigMgr Adminservice

        #Disable checks using SSLHandler class
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [SSLHandler]::GetSSLHandler()
        $Result = $false
        #do the request
        try {
    
            $URI = "$AdminService/wmi/SMS_R_System($ResourceID)" #&`$select=ResourceID,Name,NetBiosName,SMBIOSGUID,MACAddresses"
            $Params = @{
                Method               = "GET" # Method = "GET" DELETE
                ContentType          = "application/json"
                URI                  = $URI
                UseDefaultCredential = $True
            }
            $Result = Invoke-RestMethod @Params
        }
        catch {
            # do something
            Write-Error $error[0].Exception.Message
        }
        finally {
            #enable checks again
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
            
        }
        return [array]$Result.Value
    }
}
