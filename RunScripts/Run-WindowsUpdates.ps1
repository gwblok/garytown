<# Control Windows Update via PowerShell
Gary Blok - GARYTOWN.COM
NOTE: I'm using this in a RUN SCRIPT, so I hav the Parameters set to STRING, and in the RUN SCRIPT, I Create a list of options (TRUE & FALSE).
In a normal script, you wouldn't do this... so modify for your deployment method.

This was also intended to be used with ConfigMgr, if you're not, feel free to remove the $CMReboot & Corrisponding Function

Installing Updates using this Method does NOT notify the user, and does NOT let the user know that updates need to be applied at the next reboot.  It's 100% hidden.

HResult Lookup: https://docs.microsoft.com/en-us/windows/win32/wua_sdk/wua-success-and-error-codes-

#>
[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)][string]$CMReboot = "FALSE",
            [Parameter(Mandatory=$false)][string]$RestartNow = "FALSE",
            [Parameter(Mandatory=$false)][string]$InstallUpdates = "FALSE",
            [Parameter(Mandatory=$false)][string]$ClearTargetReleaseVersion = "FALSE"
	    )

Function Restart-ComputerCM {
    if (Test-Path -Path "C:\windows\ccm\CcmRestart.exe"){

        $time = [DateTimeOffset]::Now.ToUnixTimeSeconds()
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootBy' -Value $time -PropertyType QWord -Force -ea SilentlyContinue;
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootValueInUTC' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'NotifyUI' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'HardReboot' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindowTime' -Value 0 -PropertyType QWord -Force -ea SilentlyContinue;
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindow' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'PreferredRebootWindowTypes' -Value @("4") -PropertyType MultiString -Force -ea SilentlyContinue;
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'GraceSeconds' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;

        $CCMRestart = start-process -FilePath C:\windows\ccm\CcmRestart.exe -NoNewWindow -PassThru
    }
    else {
        Write-Output "No CM Client Found"
    }
}

$Results = @(
@{ ResultCode = '0'; Meaning = "Not Started"}
@{ ResultCode = '1'; Meaning = "In Progress"}
@{ ResultCode = '2'; Meaning = "Succeeded"}
@{ ResultCode = '3'; Meaning = "Succeeded With Errors"}
@{ ResultCode = '4'; Meaning = "Failed"}
@{ ResultCode = '5'; Meaning = "Aborted"}
)

$WindowsUpdateRegPathLegacy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$WindowsUpdateRegPathMDM = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update"
$WUDownloader=(New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
$WUInstaller=(New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
$WUUpdates=New-Object -ComObject Microsoft.Update.UpdateColl
((New-Object -ComObject Microsoft.Update.Session).CreateupdateSearcher().Search("IsInstalled=0 and Type='Software'")).Updates|%{
    if(!$_.EulaAccepted){$_.EulaAccepted=$true}
    if ($_.Title -notmatch "Preview"){[void]$WUUpdates.Add($_)}
}

if ($WUUpdates.Count -ge 1){
    if ($InstallUpdates -eq "TRUE"){
        if ($ClearTargetReleaseVersion -eq "TRUE"){
            if (Test-Path -Path $WindowsUpdateRegPathLegacy){
                $WUReg = Get-Item -Path $WindowsUpdateRegPathLegacy 
                if ($WUReg.GetValue('TargetReleaseVersionInfo') -ne $null){
                Remove-ItemProperty -Path $WindowsUpdateRegPathLegacy -Name TargetReleaseVersionInfo -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $WindowsUpdateRegPathLegacy -Name TargetReleaseVersion -Force -ErrorAction SilentlyContinue
                $WUUpdates=New-Object -ComObject Microsoft.Update.UpdateColl
                }
            }
        }
        $WUInstaller.ForceQuiet=$true
        $WUInstaller.Updates=$WUUpdates
        $WUDownloader.Updates=$WUUpdates
        $UpdateCount = $WUDownloader.Updates.count
        Write-Output "Downloading $UpdateCount Updates"
        foreach ($update in $WUInstaller.Updates){Write-Output "$($update.Title)"}
        $Download = $WUDownloader.Download()
        if ($Download.HResult -ne 0){
            $Convert = $Install.HResult
            $Hex = [System.Convert]::ToString($Convert, 16)
            $Hex = $Hex.Replace("ffffffff","0x")
            Write-Output "Download HResult HEX: $Hex"

        }
        $InstallUpdateCount = $WUInstaller.Updates.count
        Write-Output "Installing $InstallUpdateCount Updates"
        $Install = $WUInstaller.Install()
        $ResultMeaning = ($Results | Where-Object {$_.ResultCode -eq $Install.ResultCode}).Meaning
        Write-Output "Result: $ResultMeaning"
        if ($Install.HResult -ne 0){
            $Convert = $Install.HResult
            $Hex = [System.Convert]::ToString($Convert, 16)
            $Hex = $Hex.Replace("ffffffff","0x")
            Write-Output "Install HResult HEX: $Hex"

        }
        if ($Install.RebootRequired -eq $true){
            Write-Output "Updates Require Restart"
            if ($CMReboot -eq "TRUE"){Write-Output "Triggering CM Restart"; Restart-ComputerCM}
            if ($RestartNow -eq "TRUE") {Restart-Computer -Force}
        }
    }
    else
        {
        Write-Output "Available Updates:"
        foreach ($update in $WUUpdates){Write-Output "$($update.Title)"}
     }
} 
else {
    write-Output "No updates detected"
}
