<#
    
    Taken from: https://github.com/Ccmexec/PowerShell/blob/master/Customize%20TaskBar%20and%20Start%20Windows%2011/CustomizeTaskbar%20v1.1.ps1
    https://ccmexec.com/2022/10/customizing-taskbar-and-start-in-windows-11-22h2-with-powershell/
    Customize Taskbar in Windows 11
    Sassan Fanai / Jörgen Nilsson
    Version 1.1
    Added Option to remove CoPIlot and updated remove Search
#>
function Set-TaskBarStartMenu {
    param (
        [switch]$RemoveTaskView,    
        [switch]$RemoveCopilot,
        [switch]$RemoveWidgets,
        [switch]$RemoveChat,
        [switch]$MoveStartLeft,
        [switch]$RemoveSearch,    
        [switch]$StartMorePins,
        [switch]$StartMoreRecommendations,
        [switch]$RunForExistingUsers
    )

    [string]$RegValueName = "CustomizeTaskbar"
    [string]$FullRegKeyName = "HKLM:\SOFTWARE\OSD\" 

    # Create registry value if it doesn't exist
    If (!(Test-Path $FullRegKeyName)) {
        New-Item -Path $FullRegKeyName -type Directory -force 
        }

    New-itemproperty $FullRegKeyName -Name $RegValueName -Value "1" -Type STRING -Force

    REG LOAD HKLM\DefUser C:\Users\Default\NTUSER.DAT

    switch ($PSBoundParameters.Keys) {
        # Removes Task View from the Taskbar
        'RemoveTaskView' {
            Write-Host "Attempting to run: $PSItem"
            $reg = New-ItemProperty "HKLM:\DefUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value "0" -PropertyType Dword -Force
            try { $reg.Handle.Close() } catch {}

        }
        # Removes Widgets from the Taskbar
        'RemoveWidgets' {
            Write-Host "Attempting to run: $PSItem"
            $reg = New-ItemProperty "HKLM:\DefUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value "0" -PropertyType Dword -Force
            try { $reg.Handle.Close() } catch {}
        }
            # Removes Copilot from the Taskbar
        'RemoveCopilot' {
            Write-Host "Attempting to run: $PSItem"
            $reg = New-ItemProperty "HKLM:\DefUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value "0" -PropertyType Dword -Force
            try { $reg.Handle.Close() } catch {}
        }
        # Removes Chat from the Taskbar
        'RemoveChat' {
            Write-Host "Attempting to run: $PSItem"
            $reg = New-ItemProperty "HKLM:\DefUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value "0" -PropertyType Dword -Force
            try { $reg.Handle.Close() } catch {}
        }
        # DefUser StartMenu alignment 0=Left
        'MoveStartLeft' {
            Write-Host "Attempting to run: $PSItem"
            $reg = New-ItemProperty "HKLM:\DefUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value "0" -PropertyType Dword -Force
            try { $reg.Handle.Close() } catch {}
        }
        # Default StartMenu pins layout 0=Default, 1=More Pins, 2=More Recommendations (requires Windows 11 22H2)
        'StartMorePins' {
            Write-Host "Attempting to run: $PSItem"
            $reg = New-ItemProperty "HKLM:\DefUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_Layout" -Value "1" -PropertyType Dword -Force
            try { $reg.Handle.Close() } catch {}
        }
        # Default StartMenu pins layout 0=Default, 1=More Pins, 2=More Recommendations (requires Windows 11 22H2)
        'StartMoreRecommendations' {
            Write-Host "Attempting to run: $PSItem"
            $reg = New-ItemProperty "HKLM:\DefUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_Layout" -Value "2" -PropertyType Dword -Force
            try { $reg.Handle.Close() } catch {}

        }    # Removes search from the Taskbar
        'RemoveSearch' {
            Write-Host "Attempting to run: $PSItem"
            $RegKey = "HKLM:\DefUser\Software\Microsoft\Windows\CurrentVersion\RunOnce"
            if (-not(Test-Path $RegKey )) {
                $reg = New-Item $RegKey -Force | Out-Null
                try { $reg.Handle.Close() } catch {}
            }
            $reg = New-ItemProperty $RegKey -Name "RemoveSearch"  -Value "reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Search /t REG_DWORD /v SearchboxTaskbarMode /d 0 /f" -PropertyType String -Force
            try { $reg.Handle.Close() } catch {}
        }
        Default { 'No parameters were specified' }
    }
    [GC]::Collect()
    REG UNLOAD HKLM\Default

    if ($PSBoundParameters.ContainsKey('RunForExistingUsers')) {
        Write-Host "RunForExistingUsers parameter specified."
        $UserProfiles = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" |
        Where-Object { $_.PSChildName -match "S-1-5-21-(\d+-?){4}$" } |
        Select-Object @{Name = "SID"; Expression = { $_.PSChildName } }, @{Name = "UserHive"; Expression = { "$($_.ProfileImagePath)\NTuser.dat" } }

        # Loop through each profile on the machine
        foreach ($UserProfile in $UserProfiles) {
            Write-Host "Running for profile: $($UserProfile.UserHive)"
            # Load User NTUser.dat if it's not already loaded
            if (($ProfileWasLoaded = Test-Path Registry::HKEY_USERS\$($UserProfile.SID)) -eq $false) {
                Start-Process -FilePath "CMD.EXE" -ArgumentList "/C REG.EXE LOAD HKU\$($UserProfile.SID) $($UserProfile.UserHive)" -Wait -WindowStyle Hidden
            }
            switch ($PSBoundParameters.Keys) {
                # Removes Task View from the Taskbar
                'RemoveTaskView' {
                    Write-Host "Attempting to run: $PSItem"
                    $reg = New-ItemProperty "registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value "0" -PropertyType Dword -Force
                    try { $reg.Handle.Close() } catch {}

                }
                # Removes Widgets from the Taskbar
                'RemoveWidgets' {
                    Write-Host "Attempting to run: $PSItem"
                    $reg = New-ItemProperty "registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value "0" -PropertyType Dword -Force
                    try { $reg.Handle.Close() } catch {}
                }            
                # Removes Copilot from the Taskbar
                'RemoveCopilot' {
                    Write-Host "Attempting to run: $PSItem"
                    $reg = New-ItemProperty "registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value "0" -PropertyType Dword -Force
                    try { $reg.Handle.Close() } catch {}
                }
                # Removes Chat from the Taskbar
                'RemoveChat' {
                    Write-Host "Attempting to run: $PSItem"
                    $reg = New-ItemProperty "registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value "0" -PropertyType Dword -Force
                    try { $reg.Handle.Close() } catch {}
                }
                # Default StartMenu alignment 0=Left
                'MoveStartLeft' {
                    Write-Host "Attempting to run: $PSItem"
                    $reg = New-ItemProperty "registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value "0" -PropertyType Dword -Force
                    try { $reg.Handle.Close() } catch {}
                }
                # Default StartMenu pins layout 0=Default, 1=More Pins, 2=More Recommendations (requires Windows 11 22H2)
                'StartMorePins' {
                    Write-Host "Attempting to run: $PSItem"
                    $reg = New-ItemProperty "registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_Layout" -Value "1" -PropertyType Dword -Force
                    try { $reg.Handle.Close() } catch {}
                }
                # Default StartMenu pins layout 0=Default, 1=More Pins, 2=More Recommendations (requires Windows 11 22H2)
                'StartMoreRecommendations' {
                    Write-Host "Attempting to run: $PSItem"
                    $reg = New-ItemProperty "registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_Layout" -Value "2" -PropertyType Dword -Force
                    try { $reg.Handle.Close() } catch {}
                }
                # Removes search from the Taskbar
                'RemoveSearch' {
                    Write-Host "Attempting to run: $PSItem"
                    $RegKey = "registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Search"
                    if (-not(Test-Path $RegKey )) {
                        $reg = New-Item $RegKey -Force | Out-Null
                        try { $reg.Handle.Close() } catch {}
                    }
                    $reg = New-ItemProperty $RegKey -Name "SearchboxTaskbarMode"  -Value "0" -PropertyType Dword -Force
                    try { $reg.Handle.Close() } catch {}
                }
                Default { 'No parameters were specified' }
            }
            # Unload NTUser.dat
            if ($ProfileWasLoaded -eq $false) {
                [GC]::Collect()
                Start-Sleep 1
                Start-Process -FilePath "CMD.EXE" -ArgumentList "/C REG.EXE UNLOAD HKU\$($UserProfile.SID)" -Wait -WindowStyle Hidden
            }
        }
    }
}