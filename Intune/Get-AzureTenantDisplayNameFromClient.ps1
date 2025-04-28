Function Get-AzureTenantDisplayNameFromClient {
    $Items = Get-ChildItem -path HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo
    foreach ($Item in $Items){
        $Item.GetValue("DisplayName") 
    }
}