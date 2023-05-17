# Calls the script that creates the OS upgrade background into a runspace, one per detected screen

Add-Type -AssemblyName System.Windows.Forms
$Screens = [System.Windows.Forms.Screen]::AllScreens
$PSInstances = New-Object System.Collections.ArrayList
Foreach ($Screen in $screens) { 
    $PowerShell = [Powershell]::Create()
    [void]$PowerShell.AddScript({Param($ScriptLocation, $DeviceName); powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "$ScriptLocation\Create-FullScreenBackground-Variable.ps1" -DeviceName $DeviceName})
    [void]$PowerShell.AddArgument($PSScriptRoot)
    [void]$PowerShell.AddArgument($Screen.DeviceName)
    [void]$PSInstances.Add($PowerShell)
    [void]$PowerShell.BeginInvoke()
}
# Wait for runspace execution
Start-Sleep -Seconds 10

# Keep the process alive until each splash screen is closed
Do {
    Start-Sleep -Seconds 5
}
Until ($PSInstances.InvocationStateInfo.State -notcontains "Running")
