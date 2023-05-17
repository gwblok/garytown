$WindowsSafeguardOverridePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
Write-Output "Setting SafeguardHold Override Registry Value"
New-item -Path $WindowsSafeguardOverridePath -Force | Out-Null
New-ItemProperty -Path "$WindowsSafeguardOverridePath" -Name "DisableWUfBSafeguards" -PropertyType dword -Value 1 -Force  | Out-Null
