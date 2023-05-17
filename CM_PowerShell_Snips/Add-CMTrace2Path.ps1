New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths" -Name 'cmtrace.exe' -ItemType Registry -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\cmtrace.exe" -Name '(Default)' -Value "c:\windows\ccm\cmtrace.exe" -ErrorAction SilentlyContinue
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\cmtrace.exe" -Name 'Path' -PropertyType string -Value "c:\windows\ccm" -ErrorAction SilentlyContinue
