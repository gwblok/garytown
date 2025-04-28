Function Get-DOInformation {
    [CmdletBinding()]
    param (
        [switch]$DODownloadModeFriendlyName,
        [switch]$DODownloadModeDetails
    )
    $NameSpace = "root\cimv2\mdm\dmmap"
    $MDMDOClass = Get-CimClass -Namespace $NameSpace | Where-Object {$_.CimClassName -like "MDM_Policy_Result01_DeliveryOptimization*"} | Select-Object -Property CimClassName
    $MDMDOInstance = Get-CimInstance -Namespace $NameSpace -ClassName $MDMDOClass.CimClassName
    if ($DODownloadModeFriendlyName) {
        #https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference#download-mode
        $MDMDOInstance.DODownloadMode | ForEach-Object {
            switch ($_) {
                0 {Write-Output "DO Mode: HTTP Only"}
                1 {Write-Output "DO Mode: LAN "}
                2 {Write-Output "DO Mode: Group "}
                3 {Write-Output "DO Mode: Internet "}
                99 {Write-Output "DO Mode: Simple"}
                100 {Write-Output "DO Mode: Bypass"}
                default {Write-Output "DO Mode: Unknown"}
            }
        }
    }
    elseif ($DODownloadModeDetails) {
        #https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference#download-mode
        $MDMDOInstance.DODownloadMode | ForEach-Object {
            switch ($_) {
                0 {Write-Output "DO Mode: HTTP Only - This setting disables peer-to-peer caching but still allows Delivery Optimization to download content over HTTP from the download's original source or a Microsoft Connected Cache server. This mode uses additional metadata provided by the Delivery Optimization cloud services for a peerless, reliable and efficient download experience."}
                1 {Write-Output "DO Mode: LAN - This default operating mode for Delivery Optimization enables peer sharing on the same network. The Delivery Optimization cloud service finds other clients that connect to the Internet using the same public IP as the target client. These clients then try to connect to other peers on the same network by using their private subnet IP."}
                2 {Write-Output "DO Mode: Group - When group mode is set, the group is automatically selected based on the device's Active Directory Domain Services (AD DS) site (Windows 10, version 1607) or the domain the device is authenticated to (Windows 10, version 1511). In group mode, peering occurs across internal subnets, between devices that belong to the same group, including devices in remote offices. You can use GroupID option to create your own custom group independently of domains and AD DS sites. Starting with Windows 10, version 1803, you can use the GroupIDSource parameter to take advantage of other method to create groups dynamically. Group download mode is the recommended option for most organizations looking to achieve the best bandwidth optimization with Delivery Optimization."}
                3 {Write-Output "DO Mode: Internet - 	Enable Internet peer sources for Delivery Optimization."}
                99 {Write-Output "DO Mode: Simple - Simple mode disables the use of Delivery Optimization cloud services completely (for offline environments). Delivery Optimization switches to this mode automatically when the Delivery Optimization cloud services are unavailable, unreachable, or when the content file size is less than 10 MB. In this mode, Delivery Optimization provides a reliable download experience over HTTP from the download's original source or a Microsoft Connected Cache server, with no peer-to-peer caching."}
                100 {Write-Output "DO Mode: Bypass - Starting in Windows 11, this option is deprecated. Don't configure Download mode to '100' (Bypass), which can cause some content to fail to download. If you want to disable peer-to-peer functionality, configure DownloadMode to (0). If your device doesn't have internet access, configure Download Mode to (99). When you configure Bypass (100), the download bypasses Delivery Optimization and uses BITS instead. You don't need to configure this option if you're using Configuration Manager."}
                default {Write-Output "DO Mode: Unknown"}
            }
        }
    }
    else {
        return $MDMDOInstance
    }
}

<#
$NameSpace = "root\cimv2\mdm\dmmap"
$MDMDOClass = Get-CimClass -Namespace $NameSpace | Where-Object {$_.CimClassName -like "MDM_Policy_Result01_DeliveryOptimization*"} | Select-Object -Property CimClassName
$MDMDOInstance = Get-CimInstance -Namespace $NameSpace -ClassName $MDMDOClass.CimClassName
$MDMDOInstance
#>
