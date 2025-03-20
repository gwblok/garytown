
###############
## FUNCTIONS ##
###############
#region Functions


function Reset-WindowsUpdateRegistry {

#Setting Details: https://docs.microsoft.com/en-us/windows/deployment/update/waas-wu-settings

$WindowsUpdateRegPathLegacy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

if (Test-Path -Path $WindowsUpdateRegPathLegacy){
    Remove-Item -Path $WindowsUpdateRegPathLegacy -Recurse -Force | Out-Null
    Write-Output "Removed Legacy Path"

}
else {
    Write-Output "No Windows Update Legacy Path in Registry"
}

Write-Output "Resetting Registry Values"

New-item -Path $WindowsUpdateRegPathLegacy | Out-Null
New-ItemProperty -Path "$WindowsUpdateRegPathLegacy" -Name ExcludeWUDriversInQualityUpdate -PropertyType dword -Value 0  | Out-Null
New-ItemProperty -Path "$WindowsUpdateRegPathLegacy" -Name ElevateNonAdmins -PropertyType dword -Value 1  | Out-Null
New-ItemProperty -Path "$WindowsUpdateRegPathLegacy" -Name AcceptTrustedPublisherCerts -PropertyType dword -Value 1  | Out-Null

#This is added because it is the detection method on the App being deployed:
New-ItemProperty -Path "$WindowsUpdateRegPathLegacy" -Name DeferQualityUpdatesPeriodInDays -PropertyType dword -Value 10  | Out-Null

New-Item -Path "$WindowsUpdateRegPathLegacy\AU" | Out-Null
New-ItemProperty -Path "$WindowsUpdateRegPathLegacy\AU" -Name AllowMUUpdateService -PropertyType dword -Value 1  | Out-Null
New-ItemProperty -Path "$WindowsUpdateRegPathLegacy\AU" -Name AutoInstallMinorUpdates -PropertyType dword -Value 1  | Out-Null
New-ItemProperty -Path "$WindowsUpdateRegPathLegacy\AU" -Name AUOptions -PropertyType dword -Value 4  | Out-Null
New-ItemProperty -Path "$WindowsUpdateRegPathLegacy\AU" -Name NoAutoUpdate -PropertyType dword -Value 0  | Out-Null
New-ItemProperty -Path "$WindowsUpdateRegPathLegacy\AU" -Name IncludeRecommendedUpdates -PropertyType dword -Value 1  | Out-Null

}
Function Reset-WindowsUpdate {

<# 
.SYNOPSIS 
Reset-WindowsUpdate.ps1 - Resets the Windows Update components 
 
.DESCRIPTION  
This script will reset all of the Windows Updates components to DEFAULT SETTINGS. 
 
.OUTPUTS 
Results are printed to the console. Future releases will support outputting to a log file.  
 
.NOTES 
https://docs.microsoft.com/en-us/windows/deployment/update/windows-update-resources
 
#> 
 
 
$arch = Get-WMIObject -Class Win32_Processor -ComputerName LocalHost | Select-Object AddressWidth 
 
Write-Output "1. Stopping Windows Update Services..." 
Stop-Service -Name BITS | Out-Null
Stop-Service -Name wuauserv | Out-Null
Stop-Service -Name appidsvc | Out-Null
Stop-Service -Name cryptsvc | Out-Null
 
Write-Output "2. Remove QMGR Data file..." 
Remove-Item "$env:allusersprofile\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -ErrorAction SilentlyContinue 
 
Write-Output "3. Renaming the Software Distribution and CatRoot Folder..." 
Rename-Item $env:systemroot\SoftwareDistribution\DataStore DataStore.bak -ErrorAction SilentlyContinue
Rename-Item $env:systemroot\SoftwareDistribution\Download Download.bak -ErrorAction SilentlyContinue 
Rename-Item $env:systemroot\System32\Catroot2 catroot2.bak -ErrorAction SilentlyContinue 
 
Write-Output "4. Removing old Windows Update log..." 
Remove-Item $env:systemroot\WindowsUpdate.log -ErrorAction SilentlyContinue 
 
Write-Output "5. Resetting the Windows Update Services to default settings..." 
Start-Process -FilePath "$env:systemroot\system32\sc.exe" -ArgumentList "sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)" -Wait
Start-Process -FilePath "$env:systemroot\system32\sc.exe" -ArgumentList "sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)" -Wait

 
Set-Location $env:systemroot\system32 
 
Write-Output "6. Registering some DLLs..." 
regsvr32.exe /s atl.dll 
regsvr32.exe /s urlmon.dll 
regsvr32.exe /s mshtml.dll 
regsvr32.exe /s shdocvw.dll 
regsvr32.exe /s browseui.dll 
regsvr32.exe /s jscript.dll 
regsvr32.exe /s vbscript.dll 
regsvr32.exe /s scrrun.dll 
regsvr32.exe /s msxml.dll 
regsvr32.exe /s msxml3.dll 
regsvr32.exe /s msxml6.dll 
regsvr32.exe /s actxprxy.dll 
regsvr32.exe /s softpub.dll 
regsvr32.exe /s wintrust.dll 
regsvr32.exe /s dssenh.dll 
regsvr32.exe /s rsaenh.dll 
regsvr32.exe /s gpkcsp.dll 
regsvr32.exe /s sccbase.dll 
regsvr32.exe /s slbcsp.dll 
regsvr32.exe /s cryptdlg.dll 
regsvr32.exe /s oleaut32.dll 
regsvr32.exe /s ole32.dll 
regsvr32.exe /s shell32.dll 
regsvr32.exe /s initpki.dll 
regsvr32.exe /s wuapi.dll 
regsvr32.exe /s wuaueng.dll 
regsvr32.exe /s wuaueng1.dll 
regsvr32.exe /s wucltui.dll 
regsvr32.exe /s wups.dll 
regsvr32.exe /s wups2.dll 
regsvr32.exe /s wuweb.dll 
regsvr32.exe /s qmgr.dll 
regsvr32.exe /s qmgrprxy.dll 
regsvr32.exe /s wucltux.dll 
regsvr32.exe /s muweb.dll 
regsvr32.exe /s wuwebv.dll 
 
Write-Output "7) Resetting the WinSock..." 
netsh winsock reset | Out-Null
netsh winhttp reset proxy  | Out-Null
 
Write-Output "8) Delete all BITS jobs..." 
Get-BitsTransfer | Remove-BitsTransfer 
 
 
Write-Output "9) Starting Windows Update Services..." 
Start-Service -Name BITS | Out-Null
Start-Service -Name wuauserv | Out-Null
Start-Service -Name appidsvc | Out-Null
Start-Service -Name cryptsvc | Out-Null
 
Write-Output "10) Forcing discovery..." 
wuauclt /resetauthorization /detectnow 

}

function Invoke-WindowsUpdate{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [ValidateSet("Software","Driver","All")]
        [string]$Type = 'Software',
        [Parameter(Mandatory=$false)]
        [bool]$IsInstalled = $false,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Install","List")]
        [string]$Action = 'List',
        [switch]$FullDetails

    )

    $Results = @(
        @{ ResultCode = '0'; Meaning = "Not Started"}
        @{ ResultCode = '1'; Meaning = "In Progress"}
        @{ ResultCode = '2'; Meaning = "Succeeded"}
        @{ ResultCode = '3'; Meaning = "Succeeded With Errors"}
        @{ ResultCode = '4'; Meaning = "Failed"}
        @{ ResultCode = '5'; Meaning = "Aborted"}
        @{ ResultCode = '6'; Meaning = "No Updates Found"}
    )

    if ($IsInstalled -eq $true){[string]$IsInstalledArg = 1}
    else {[string]$IsInstalledArg = 0}
    if ($Type -eq 'All'){$TypeArg = ""}
    else {$TypeArg = "and Type=`'$($Type)`'"}

    $WUDownloader=(New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
    $WUInstaller=(New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
    $WUUpdates=New-Object -ComObject Microsoft.Update.UpdateColl
    #Write-Output "IsInstalled=$IsInstalledArg $TypeArg"
    ((New-Object -ComObject Microsoft.Update.Session).CreateupdateSearcher().Search("IsInstalled=$IsInstalledArg $TypeArg")).Updates|%{
        if(!$_.EulaAccepted){$_.EulaAccepted=$true}
        if ($_.Title -notmatch "Preview"){[void]$WUUpdates.Add($_)}
    }


    if ($WUUpdates.Count -ge 1){
        if ($FullDetails){return $WUUpdates}
        if ($Action -eq 'List'){
            $WUUpdates | Select-Object Title
            
        }
        else {
            $WUInstaller.ForceQuiet=$true
            $WUInstaller.Updates=$WUUpdates
            $WUDownloader.Updates=$WUUpdates
            $UpdateCount = $WUDownloader.Updates.count
            if ($UpdateCount -ge 1){
                Write-Output "Downloading $UpdateCount Updates"
                foreach ($update in $WUUpdates){
                    Write-Output "$($update.Title)"
                }
                $Download = $WUDownloader.Download()
            }
            $InstallUpdateCount = $WUInstaller.Updates.count
            if ($InstallUpdateCount -ge 1){
                $Install = $WUInstaller.Install()
                $ResultMeaning = ($Results | Where-Object {$_.ResultCode -eq $Install.ResultCode}).Meaning
                Write-Output $ResultMeaning
            }
        }
    }

    else {Write-Output "No Updates Found"} 
}

#endregion
