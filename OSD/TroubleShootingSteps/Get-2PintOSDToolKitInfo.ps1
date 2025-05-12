#Get 2Pint OSDToolkit Software Information

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [String]$logPath = "C:\Windows\Temp",
    [Parameter(Mandatory = $false)]
    [String]$logFile = "OSDToolKit.log"
)
Function Get-2PintOSDToolkitInfo {


    $Tools = @(
        [PSCustomObject]@{
            ToolName = "BITSACP"
            Path     = "C:\windows\System32\BITSACP.EXE"
            Latest   = "3.1.9.0"
        },
        [PSCustomObject]@{
            ToolName = "HASHGEN"
            Path     = "C:\windows\system32\HashGen.exe"
            Latest   = "3.1.8.0"
        },
        [PSCustomObject]@{
            ToolName = "BCENabler"
            Path     = "C:\windows\system32\BCENabler.exe"
            Latest   = "3.1.8.0"
        },
        [PSCustomObject]@{
            ToolName = "BranchCacheTool"
            Path     = "C:\windows\system32\BranchCacheTool.exe"
            Latest   = "3.0.3.0"
        }
    )
    $Tools | ForEach-Object {
        $tool = $_
        if (Test-Path -Path $tool.Path) {
            #Write-Output "$($tool.ToolName) is present at $($tool.Path)"
            $tool | Add-Member -MemberType NoteProperty -Name Found -Value $true
            $versionInfo = (Get-Item $tool.Path).VersionInfo
            $tool | Add-Member -MemberType NoteProperty -Name InstalledVersion -Value $versionInfo.FileVersion
            if ($versionInfo.FileVersion -eq $tool.Latest) {
                #Write-Output "$($tool.ToolName) is up to date."
                $tool | Add-Member -MemberType NoteProperty -Name Status -Value "Current"
            } else {
                #Write-Output "$($tool.ToolName) is NOT up to date. Current version: $($versionInfo.FileVersion), Latest version: $($tool.Latest)"
                $tool | Add-Member -MemberType NoteProperty -Name Status -Value "OLD"
            }
        } else {
            #Write-Output "$($tool.ToolName) is NOT present at $($tool.Path)"
            $tool | Add-Member -MemberType NoteProperty -Name Found -Value $false
        }
    }

    return $Tools
}

$Info = Get-2PintOSDToolkitInfo
if ($env:SystemDrive -eq "C:") {
    $Info | Out-File -FilePath "$logPath\Garther-FullOS-$logFile" -Append -Force
}
else{
    $Info | Out-File -FilePath "$logPath\Gather-BootMedia-$logFile" -Append -Force
}