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


function Run-WindowsUpdate{
    <# Control Windows Update via PowerShell
    Gary Blok - GARYTOWN.COM
    NOTE: I'm using this in a RUN SCRIPT, so I hav the Parameters set to STRING, and in the RUN SCRIPT, I Create a list of options (TRUE & FALSE).
    In a normal script, you wouldn't do this... so modify for your deployment method.

    This was also intended to be used with ConfigMgr, if you're not, feel free to remove the $CMReboot & Corrisponding Function

    Installing Updates using this Method does NOT notify the user, and does NOT let the user know that updates need to be applied at the next reboot.  It's 100% hidden.

    HResult Lookup: https://docs.microsoft.com/en-us/windows/win32/wua_sdk/wua-success-and-error-codes-

    #>

    $Results = @(
    @{ ResultCode = '0'; Meaning = "Not Started"}
    @{ ResultCode = '1'; Meaning = "In Progress"}
    @{ ResultCode = '2'; Meaning = "Succeeded"}
    @{ ResultCode = '3'; Meaning = "Succeeded With Errors"}
    @{ ResultCode = '4'; Meaning = "Failed"}
    @{ ResultCode = '5'; Meaning = "Aborted"}
    @{ ResultCode = '6'; Meaning = "No Updates Found"}
    )


    $WUDownloader=(New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
    $WUInstaller=(New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
    $WUUpdates=New-Object -ComObject Microsoft.Update.UpdateColl
    ((New-Object -ComObject Microsoft.Update.Session).CreateupdateSearcher().Search("IsInstalled=0 and Type='Software'")).Updates|%{
        if(!$_.EulaAccepted){$_.EulaAccepted=$true}
        if ($_.Title -notmatch "Preview"){[void]$WUUpdates.Add($_)}
    }

    if ($WUUpdates.Count -ge 1){
        $WUInstaller.ForceQuiet=$true
        $WUInstaller.Updates=$WUUpdates
        $WUDownloader.Updates=$WUUpdates
        $UpdateCount = $WUDownloader.Updates.count
        if ($UpdateCount -ge 1){
            $Download = $WUDownloader.Download()
        }
        $InstallUpdateCount = $WUInstaller.Updates.count
        if ($InstallUpdateCount -ge 1){
            $Install = $WUInstaller.Install()
            $ResultMeaning = ($Results | Where-Object {$_.ResultCode -eq $Install.ResultCode}).Meaning
            Write-Output $ResultMeaning
            #if ($Install.RebootRequired -eq $true){Restart-ComputerCM}
        } 
    }
    else {Write-Output "No Updates Found"} 
}
