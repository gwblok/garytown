
# Set network to move (subnet)
$NetworkIdToMove = "192.168.29.0"  # Change this to the network you want to move (subnet)

# Define new location settings
$LocationName = "VPN MN"  #Change this to the name of the location you want to create - You can delete it later after you move your newly created group to the desired location in the console.
$LocationDescription = "TEMP LOCATION - USING for a way to get a new Group created"  #Create a useful description for the location

# Define new network group settings
$NetworkGroupName = "VPN" #Change this to the name of the group you want to create - I used "VPN" just to confirm it worked
$NetworkGroupDescription = "VPNs" #Create a useful description for the group
$TemplateName = "Test-PowerShellTemplate"  #Change this to the name of the template you want associated with the group - I copied one and named it "Test-PowerShellTemplate" just to confirm it worked

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

function Get-StifleRLocation{
    $class = "Locations"
    $Locations = Get-CimInstance -Namespace root\StifleR -Query "SELECT * FROM $class"
}
#-----------------------------------------------------------[Execution]------------------------------------------------------------

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

