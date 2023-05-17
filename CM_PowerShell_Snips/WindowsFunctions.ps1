function Get-WindowsRelease {
    $CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $WindowsRelease = $CurrentOSInfo.GetValue('ReleaseId')
    if ($WindowsRelease -eq "2009"){$WindowsRelease = $CurrentOSInfo.GetValue('DisplayVersion')}

    return $WindowsRelease
}

function Get-WindowsUBR {
    $CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $BuildUBR_CurrentOS = $($CurrentOSInfo.GetValue('CurrentBuild'))+"."+$($CurrentOSInfo.GetValue('UBR'))

    return $BuildUBR_CurrentOS
}

function Get-WindowsBuild {
    $CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    return $($CurrentOSInfo.GetValue('CurrentBuild'))
}
