
# Function to create a new location
function Add-Location($LocationName, $LocationDescription) {
    $class = "Locations"
    $method = "AddLocation"
    if ($verbose) { Write-Verbose -message "Processing $method" }
    $params = @{ Name = $LocationName; Description = $LocationDescription };
    
    $result = Compare-StifleRMethodParameters $class $method $params
    
    if ($result -ne 0) {
        Write-Error "Failed to verify Parameters to $class"
        return 1
    }
    else {
        #Add out location
        if ($verbose) { Write-Verbose -message "Calling Invoke-CimMethod to $class $method" }
        $ret = Invoke-CimMethod -Namespace root\StifleR -ClassName $class -Name $method -Arguments $params
        
        $locationid = $ret.ReturnValue
        #Dont be this guy! This calls the enumerator for each call, if we have the ID, whe dont need to query!
        #$Location = Get-CimInstance -Namespace root\StifleR -Query "Select * from $class where id like '$locationid'"
        
        #This is MUCH faster, and does not slow down with larget lists. Key here is the -ClientOnly
        $x = New-CimInstance -ClassName $class -Namespace root\stifler -Property @{ "Id" = $locationid } -Key Id -ClientOnly
        $Location = Get-CimInstance -CimInstance $x

        return , $Location
    }
}

Function Compare-StifleRMethodParameters($WMIClass, $Method, $CALLINGParams) {

    $Class = Get-CimClass -Namespace root\StifleR -ClassName "$WMIClass"
    $Class_Params = $Class.CimClassMethods[$Method].Parameters

    ForEach ($entry in $Class_Params) {
        if ($verbose) { Write-Verbose -message "Processing $($entry.Name) of type: $($entry.CimType)" }
        if ($CALLINGParams.ContainsKey($entry.Name)) {
            if ($verbose) { Write-Verbose -message "Found valid parameter: $($entry.Name) of type: $($entry.CimType)" }
        
            $othertype = $CALLINGParams[$entry.Name].GetType()

            if ($othertype.Name -ne $entry.CimType) {
                Write-Verbose -Message "$($CALLINGParams[$entry.Name].GetType())  does not match  $($entry.CimType)" -LogLevel 3 -Verbose
                return 1
            }
            else {
                if ($verbose) { Write-Verbose -message "Input matches the parameter type!" }
            }
        }
        else {
            if ($verbose) { Write-Verbose -message $entry.Name }
            Write-Verbose -Message "Missing valid parameter $($entry.Name) on call to $Method on $WMIClass" -LogLevel 3 -Verbose
            return 1
        }
    }
    return 0
}

# Function to add a network group to a location
function Add-NetworkGroupToLocation([System.Object]$Location, $NetworkGroupName, $NetworkGroupDescription) {
    write-debug "incoming object is type ($Location.GetType())"

    write-debug "##########################"
    $method = "AddNetworkGroupToLocation"
    $class = "NetworkGroups"
    write-debug "Processing $method"
    $params = @{ Name = $NetworkGroupName ; Description = $NetworkGroupDescription }
    $result = Compare-StifleRMethodParameters $class $method $params
    if ($result -ne 0) {
        Write-Error "Failed to verify Parameters to $class"
        return 1
    }
    else {
    
        #Add location on the actual object in the location object just created using non static method
        write-debug "Calling Invoke-CimMethod on LocationInstance $Location.id"
        $ret = Invoke-CimMethod -InputObject $Location -MethodName $method -Arguments $params

        $netGrpId = $ret.ReturnValue
        #$netGrp = Get-CimInstance -Namespace root\StifleR -Query "Select * from $class where id like '$netGrpId'"
        
        $x = New-CimInstance -ClassName $class -Namespace root\stifler -Property @{ "Id" = $netGrpId } -Key Id -ClientOnly
        Start-Sleep -Seconds 1
        $netGrp = Get-CimInstance -CimInstance $x
		
        return $netGrp

        #You can also call the static methods to add on the class NetworkGroups
        #write-debug "Calling Invoke-CimMethod to $class $method"
        #$args = @{ Name = 'Name' ; Description = 'Description'; LocationId=<guid>}
        #$netGrp = Invoke-CimMethod -Namespace root\StifleR -ClassName $class -Name $method -Arguments $args
    }
}

# Function to add a network to a network group
function Add-NetworkToNetworkGroup([System.Object]$NetGrp, $NetworkId, $NetworkMask, $GatewayMAC) {
    
    write-debug "##########################"
    $class = "Networks"
    $method = "AddNetworkToNetworkGroup"
    write-debug "Processing $method"
    $params = @{ Network = $NetworkId ; NetworkMask = $NetworkMask; GatewayMAC = $GatewayMAC };
    $result = Compare-StifleRMethodParameters $class $method $params
    if ($result -ne 0) {
        Write-Error "Failed to verify Parameters to $class"
        return 1
    }
    else {
        #Add out location
        write-debug "Calling Invoke-CimMethod on newly create network group"
    

        #Add location on the actual object in the location object just created using non static method
        $ret = Invoke-CimMethod -InputObject $NetGrp -MethodName AddNetworkToNetworkGroup -Arguments $params

        $NetworkId = $ret.ReturnValue
        #$Network = Get-CimInstance -Namespace root\StifleR -Query "Select * from $class where id like '$NetworkId'"
        
        $x = New-CimInstance -ClassName $class -Namespace root\stifler -Property @{ "Id" = $NetworkId } -Key Id -ClientOnly
        $Network = Get-CimInstance -CimInstance $x
		
        return $Network
    }
}
#Create a new network group using the static method on the class NetworkGroups
function Add-StifleRNetwork {
    <#
    AddNetwork method of the Networks class
        

    GatewayMAC - string
    The gateways MAC address, can be used to script/bundle multiple subnets together. Set to N/A if not known. Otherise in 00-11 or 00:11 or 0011 etc format.

    NetworkGroupId - string
    The Guid of the network group to add the network do.

    NetworkId - string
    The Network ID of the new Subnet to add. Like 192.167.1.0 for a 24bit subnet mask.

    NetworkMask - string
    The Subnet ID of the new Subnet to add. Like 192.167.1.0 for a 24bit subnet mask.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        $NetworkID,
        [Parameter(Mandatory=$true)]
        $NetworkMask,
        [Parameter(Mandatory=$false)]
        $NetworkGroupID,
        [Parameter(Mandatory=$false)]
        $GatewayMAC
    )
    if ($null -eq $NetworkGroupID){
        $NetworkGroupID = Get-StifleRNetworkGroups | Select-Object -Property Name, id, Description, ActiveClients | Out-GridView -PassThru -Title "Select the Network Group to add the network to" | Select-Object -ExpandProperty id
    }
    $namespace = "ROOT\StifleR"
    $classname = "Networks"
    Invoke-CimMethod -Namespace $namespace -ClassName $classname -MethodName "AddNetwork" -Arguments @{
        NetworkID = $NetworkID
        NetworkMask = $NetworkMask
        NetworkGroupID = $NetworkGroupID
        GatewayMAC = $GatewayMAC
    }
}

#basic functions to get information from the stifler database
function Get-StifleRNetworkGroups {
    $class = "NetworkGroups"
    $NetworkGroups = Get-CimInstance -Namespace root\stifler -Query "Select * FROM $class"
    return $NetworkGroups
}
function Get-StifleRLocations{
    $class = "Locations"
    $Locations = Get-CimInstance -Namespace root\StifleR -Query "SELECT * FROM $class"
    return $Locations
}

function Get-StifleRNetworkGroupSupportServers {
    $NetworkGroups = Get-CimInstance -Namespace root\stifler -Query "Select * From NetworkGroups" 
    #Create table to hold the results
    
    $ReturnData = New-Object System.Collections.ArrayList
    
    foreach ($ng in $NetworkGroups)
    {
        $Result = Invoke-CimMethod -InputObject $ng -MethodName GetSupportServers -Arguments @{Filter = [int]0}
        if ('{}' -eq $Result.ReturnValue){
            # NO Servers Listed
        }
        else {
            $Data = New-Object -TypeName PSObject
            $Data | Add-Member -MemberType NoteProperty -Name "SupportServers" -Value $Result.ReturnValue -Force
	        $Data | Add-Member -MemberType NoteProperty -Name "NetworkGroupName" -Value $ng.Name -Force
	        $Data | Add-Member -MemberType NoteProperty -Name "NetworkGroupID" -Value $ng.id -Force
            $ReturnData += $Data
            #Write-Host "Network Group $($ng.Name) | $($ng.id)" -ForegroundColor Cyan
            #write-Host " Found Support Server: $($Result.ReturnValue)" -ForegroundColor Yellow
        }
    }
    $ReturnData
}

function Clear-RoamingForeverFlag {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )
    <#
    Clear the RoamingForever flag on all clients in the StifleR database.
    This is useful when you want to reset the roaming status of clients.
    #>
    $clients = Get-CimInstance -Namespace root\stifler -Query "Select * From Connections"
    $roamingForever = 0;

    foreach ($client in $clients) {
        if ($client.ClientFlags -band 4294967296) {
            $roamingForever++
            if ($WhatIf) {
                Write-Verbose "WhatIf: Would reset RoamingForever flag on client with ConnectionId: $($client.ConnectionId)"
                continue
            }
            else{
                Write-Verbose "Resetting RoamingForever flag on client with ConnectionId: $($client.ConnectionId)"
                $conn = [wmi]"\root\StifleR:Connections.ConnectionID='$($client.ConnectionId)'"
                $conn.ResetRoamingForeverFlag();
                Start-Sleep -Milliseconds 20
            }
        }
    }
    Write-Host "Total RoamingForever flags on clients: $roamingForever" -ForegroundColor Green
}


#-----------------------------------------------------------[Execution]------------------------------------------------------------
<#
# Get network settings from the network to move, needed later
# Abort if the network does not exist, no point in continuing
$NetworkToMove = Get-CimInstance -Namespace root\StifleR -ClassName Networks -Filter "NetworkId = '$NetworkIdToMove'"
If ($NetworkToMove){
    $NetworkMask = $NetworkToMove.SubnetMask
    $NetworkGatewayMAC = $NetworkToMove.GatewayMAC
    $Id = $NetworkToMove.id
    Write-Host "Found Network $($NetworkToMove.NetworkID)"
}
Else {
    Write-Warning "Network with NetworkId: $NetworkIdToMove can not be found, aborting script..."
    Break
}

# Create new location
[System.Object]$NewLocation = Add-Location $LocationName $LocationDescription

# Create new network group
[System.Object]$NewNetworkGroup = Add-NetworkGroupToLocation $NewLocation $NetworkGroupName $NetworkGroupDescription

# Assign a template to the new network group
$Arguments = @{
    TemplateId = (Get-CimInstance -Namespace root\StifleR -ClassName NetworkGroupTemplates -Filter "Name = '$TemplateName'").id
}
$ret = Invoke-CimMethod -InputObject $NewNetworkGroup -MethodName SetTemplate -Arguments $Arguments

# Delete the existing network (requirement in 2.10)
$Arguments = @{
    Force = $true
    NetworkId = $id # The GUID id
}
$RemoveNetworkusingIdResult = Invoke-CimMethod -InputObject $NetworkToMove -MethodName RemoveNetworkusingId -Arguments $Arguments

# Create the new network 
If ($RemoveNetworkusingIdResult.ReturnValue -eq 0){
    # Deletion successful, creating the new network
    [System.Object]$Network = Add-NetworkToNetworkGroup $NewNetworkGroup $NetworkIdToMove $NetworkMask $NetworkGatewayMAC
    If ($Network) {
        Write-Host "========================================================================"
        Write-Host "Network created. Re-configure the server config file to create networks "
        Write-Host "automatically (via script or via AutoAddLocations), and restart the service."
    }
    Else {
        Write-Warning "Could not create the network. Script failed..."
    }
}
Else {
    Write-Warning "Could not delete the network. Script failed..."
}

#>