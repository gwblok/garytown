<# @gwblok | GARYTOWN | RECAST SOFTWARE
Captures information about the machine and the TS that's running and stamps it to the SMSTS log for easy review later. Helps with Troubleshooting

#>

Function Convert-FromUnixDate ($UnixDate) {
   [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($UnixDate))
}

try
{
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
}
catch
{
                Write-Output "Not running in a task sequence."
}
if ($tsenv)
    {
# Capture Info about the Machine and Current Running TS
    $TSPackageID = $tsenv.Value('_SMSTSPackageID')
    $TSAdvertID = $tsenv.Value('_SMSTSAdvertID')
    $TSName = $tsenv.Value('_SMSTSPackageName')
    $UserStarted = $tsenv.Value('_SMSTSUserStarted')
    $Manufacturer = ((Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer)
    $HPProdCode = (Get-CimInstance -ClassName Win32_BaseBoard).Product
    Get-WmiObject win32_LogicalDisk -Filter "DeviceID='C:'" | % { $FreeSpace = $_.FreeSpace/1GB -as [int] ; $DiskSize = $_.Size/1GB -as [int] }
    if ($tsenv.Value('_SMSTSPackageName') -ne "TRUE")
        {
        $CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $InstallDate_CurrentOS = Convert-FromUnixDate $CurrentOSInfo.GetValue('InstallDate')
        $ReleaseID_CurrentOS = $CurrentOSInfo.GetValue('ReleaseId')
        $BuildUBR_CurrentOS = $($CurrentOSInfo.GetValue('CurrentBuild'))+"."+$($CurrentOSInfo.GetValue('UBR'))

        #Grabs User Name of the user Logged on.
        if ($tsenv.Value("_SMSTSUserStarted") -eq "True")
            {
            $regexa = '.+Domain="(.+)",Name="(.+)"$' 
            $regexd = '.+LogonId="(\d+)"$' 
 
            $logon_sessions = @(gwmi win32_logonsession -ComputerName $env:COMPUTERNAME) 
            $logon_users = @(gwmi win32_loggedonuser -ComputerName $env:COMPUTERNAME) 
 
            $session_user = @{} 
 
            $logon_users |% { $_.antecedent -match $regexa > $nul ;$username = $matches[2] ;$_.dependent -match $regexd > $nul ;$session = $matches[1] ;$session_user[$session] += $username } 
 
 
            $currentUser = $logon_sessions |%{ 
                $loggedonuser = New-Object -TypeName psobject 
                $loggedonuser | Add-Member -MemberType NoteProperty -Name "User" -Value $session_user[$_.logonid] 
                $loggedonuser | Add-Member -MemberType NoteProperty -Name "Type" -Value $_.logontype
                $loggedonuser | Add-Member -MemberType NoteProperty -Name "Auth" -Value $_.authenticationpackage 

                ($loggedonuser  | where {$_.Type -eq "2" -and $_.Auth -eq "Kerberos"}).User 
                } 
            $currentUser = $currentUser | select -Unique
            }
        }

# Start Writing Info to SMSTSLog
    Write-Output "________________________________________________________________________________________"
    Write-OUtput "This is in red because I typed FAIL_____________________________________________________"
    Write-OUtput "This is in red because I typed FAIL_____________________________________________________"
    Write-Output ""
    Write-Output "Started $TSName"
    Write-Output "TSID: $TSPackageID | DeployID: $TSAdvertID"
    if ($UserStarted -eq "TRUE")
        {
        Write-Output "Task Sequence Triggered by User:"
        $currentUser
        }
    Else{Write-Output "Task Sequence Not Triggered by End User"}
    Write-Output ""
    Write-Output "GENERAL INFO ABOUT THIS PC $env:COMPUTERNAME"
    Write-Output "Current Client Time: $(get-date)"
    Write-Output "Current Client UTC: $([System.DateTime]::UtcNow)"
    if ($tsenv.Value('_SMSTSPackageName') -ne "TRUE")
        {
        Write-Output "Pending Reboot: $((Invoke-WmiMethod -Namespace 'root\ccm\ClientSDK' -Class CCM_ClientUtilities -Name DetermineIfRebootPending).RebootPending)"
        Write-Output "Last Reboot: $((Get-CimInstance -ClassName win32_operatingsystem).lastbootuptime)"
        Write-Output "IP Address: $((Get-NetIPAddress | Where-Object -FilterScript {$_.AddressState -eq "Preferred" -and $_.AddressFamily -eq "IPv4" -and $_.IPAddress -ne "127.0.0.1"}).IPAddress)"
        Write-Output "Current OS: $ReleaseID_CurrentOS - UBR: $BuildUBR_CurrentOS"
        Write-Output "Orginial Install Date: $InstallDate_CurrentOS"
        #Get CM Cache Info
        $UIResourceMgr = $null
        $CacheSize = $null
        try
            {
            $UIResourceMgr = New-Object -ComObject UIResource.UIResourceMgr
            if ($UIResourceMgr -ne $null)
                {
                $Cache = $UIResourceMgr.GetCacheInfo()
                Write-Output "CCMCache Size = $($Cache.TotalSize)"
        
                }
            }
        catch {}
        }
    Write-Output "Computer Model: $((Get-WmiObject -Class:Win32_ComputerSystem).Model)"
    if ($Manufacturer -like "H*"){Write-Output " Computer Product Code: $HPProdCode"}
    #Provide Feedback about Cache Size        



    #Provide Information about Disk FreeSpace & Try to clear up space if Less than 20GB Free, but don't bother if machine is already upgraded
    if ($Freespace -ne $null)
        {
        Write-Output "DiskSize = $DiskSize, FreeSpace = $Freespace"
        }

    $MemorySize = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory/1MB)
    Write-Output "Memory size = $MemorySize MB"
    Write-Output ""
    Write-OUtput "This is in red because I typed FAIL_____________________________________________________"
    Write-OUtput "This is in red because I typed FAIL_____________________________________________________"
    Write-Output "________________________________________________________________________________________"
    
    Write-Output ""
    }
