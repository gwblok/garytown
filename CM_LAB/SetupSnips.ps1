$Domain = "LAB.GARYTOWN.COM"

if ($env:COMPUTERNAME -eq "CM"){
    $Features = @("FS-Data-Deduplication", "BranchCache", "NET-Framework-Core", "BITS", "BITS-IIS-Ext", "BITS-Compact-Server", "RDC", "WAS-Process-Model", "WAS-Config-APIs", "WAS-Net-Environment", "Web-Server", "Web-ISAPI-Ext", "Web-ISAPI-Filter", "Web-Net-Ext", "Web-Net-Ext45", "Web-ASP-Net", "Web-ASP-Net45", "Web-ASP", "Web-Windows-Auth", "Web-Basic-Auth", "Web-URL-Auth", "Web-IP-Security", "Web-Scripting-Tools", "Web-Mgmt-Service", "Web-Stat-Compression", "Web-Dyn-Compression", "Web-Metabase", "Web-WMI", "Web-HTTP-Redirect", "Web-Log-Libraries", "Web-HTTP-Tracing", "UpdateServices-RSAT", "UpdateServices-API", "UpdateServices-UI")
    ForEach ($Feature in $Features){
        write-host "Starting $Feature" -ForegroundColor Green
        Install-WindowsFeature -Name $Feature -IncludeAllSubFeature -IncludeManagementTools
    }

    #Inbound
    $DescriptionInbound = "CM SQL & SQL Service Broker (1433 & 4022) Inbound Rule"
    New-NetFirewallRule -DisplayName "CM SQL Inbound" -Direction Inbound -Profile Domain -Action Allow -LocalPort 1433,4022 -Protocol TCP -Description $DescriptionInbound

    #Outbound
    $DescriptionOutbound = "CM SQL & SQL Service Broker (1433 & 4022) Outbound Rule"
    New-NetFirewallRule -DisplayName "CM SQL Outbound" -Direction Outbound -Profile Domain -Action Allow -LocalPort 1433,4022 -Protocol TCP -Description $DescriptionOutbound
}

if ($env:COMPUTERNAME -eq "DC"){
    <#Manual
    Install C++ Runtime (to allow CM to Extend Schema
    Make Sure you named the machine "DC"
    Run the SetupAD PowerShell Script after you Setup Active Directory
    Setup the 3 Certs needed for ConfigMgr (Client, Web, DP)

    #>
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
    Install-ADDSForest -DomainName $Domain -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) -InstallDns -Force
    Install-WindowsFeature AD-Certificate -IncludeManagementTools
    Install-AdcsCertificationAuthority -Force

    #Grab Root CA for ConfigMgr Site Properties | Communication Security
    $process = "C:\windows\System32\certutil.exe"
    $arg = "-ca.cert C:\RootCA_$($Domain).cer"
    Start-Process $process -ArgumentList $arg

}
