#Fix BranchCache Peering in Server 2022, 2025 +

#Disable Elipical Curve Diffie Hillman
New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\ECDH' -ItemType directory -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\ECDH' -Name 'Enabled' -PropertyType dword -Value 0 -Force



#Disable TLS 1.3
New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server' -ItemType directory -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server' -Name 'DisabledByDefault' -PropertyType dword -Value 1 -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server' -Name 'Enabled' -PropertyType dword -Value 0 -Force




<#
New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman' -ItemType directory -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman' -Name 'Enabled' -PropertyType dword -Value 0 -Force
#>


<#
Import-Module WebAdministration

# Specify the website name
$siteName = "Default Web Site"

# Define the path to the applicationHost.config file
$configPath = "$env:SystemRoot\System32\inetsrv\config\applicationHost.config"

# Load the configuration file as XML
$config = [xml](Get-Content $configPath)

# Find the specific site and binding
$site = $config.configuration["system.applicationHost"].sites.site | Where-Object { $_.name -eq $siteName }
$binding = $site.bindings.binding | Where-Object { $_.protocol -eq "https" -and $_.bindingInformation -like "*:443:*" }

if ($binding) {
    # Set the sslFlags attribute to 32 (disable TLS 1.3 over TCP)
    $binding.sslFlags = "32"

    # Save the modified configuration
    $config.Save($configPath)

    Write-Host "TLS 1.3 over TCP has been disabled for the $siteName binding on port 443."
} else {
    Write-Host "No HTTPS binding found for $siteName on port 443."
}
#>