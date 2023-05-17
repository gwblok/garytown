#Functions Based on Windows Update Information - @GWBLOK - GARY BLOK - GARYTOWN.COM


function Get-InLastWinReleases {
    Param(
        [Parameter(Mandatory=$true)][int]$releases
    )
    $OSEditionsJSONURL = 'https://raw.githubusercontent.com/gwblok/garytown/master/Azure/Automation/WinUpdates/OSEditionsTableData.json'
    $OSEditionsData = (Invoke-WebRequest -URI $OSEditionsJSONURL).content | ConvertFrom-Json

    $CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $WindowsRelease = $CurrentOSInfo.GetValue('ReleaseId')
    if ($WindowsRelease -eq "2009"){$WindowsRelease = $CurrentOSInfo.GetValue('DisplayVersion')}
    if ($CurrentOSInfo.GetValue('CurrentBuild') -ge "22000") {$OS = "11.0"}
    else {$OS = "10.0"}
    $EditionID = $CurrentOSInfo.GetValue('EditionID')

    $Win10Versions = ($OSEditionsData | Where-Object {$_."Windows Release" -match "10"}).Version | Select-Object -Unique | Select-Object -First $releases
    $Win11Versions = ($OSEditionsData | Where-Object {$_."Windows Release" -match "11"}).Version | Select-Object -Unique | Select-Object -First $releases

    $InLastReleases = $false
    if ($OS -eq "10.0"){
        if ($WindowsRelease -in $Win10Versions){
            $InLastReleases = $true   
        }
    }

    if ($OS -eq "11.0"){
        if ($WindowsRelease -in $Win11Versions){
            $InLastReleases = $true   
        }
    }

    return $InLastReleases

}

function Get-InWinSupport { 
    param (
    [switch]$DayRemaining
    )

    $OSEditionsJSONURL = 'https://raw.githubusercontent.com/gwblok/garytown/master/Azure/Automation/WinUpdates/OSEditionsTableData.json'
    $OSEditionsData = (Invoke-WebRequest -URI $OSEditionsJSONURL).content | ConvertFrom-Json

    $CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $WindowsRelease = $CurrentOSInfo.GetValue('ReleaseId')
    if ($WindowsRelease -eq "2009"){$WindowsRelease = $CurrentOSInfo.GetValue('DisplayVersion')}
    if ($CurrentOSInfo.GetValue('CurrentBuild') -ge "22000") {$OS = "11.0"}
    else {$OS = "10.0"}
    $EditionID = $CurrentOSInfo.GetValue('EditionID')

    $WinVersions = $OSEditionsData | Where-Object {$_.Version -match $WindowsRelease}

    if ($OS -eq "10.0"){
        $WinVersions = $WinVersions | Where-Object {$_."Windows Release" -match "10"}
    }
    if ($OS -eq "11.0"){
        $WinVersions = $WinVersions | Where-Object {$_."Windows Release" -match "11"}
    }
    $WinVersions = $WinVersions | Where-Object {$_.EditionFamily -match $EditionID}
    if ($WinVersions.Count -gt 1){$WinVersions = $WinVersions | Select-Object -First 1}
    [DATETIME]$EndDate = $WinVersions.EndDate
    if ($DayRemaining){
        $Today = Get-Date
        $DaysLeft = [math]::Round(($EndDate - $Today).TotalDays)
        if ($DaysLeft -lt 0){$DaysLeft = 0}
        return $DaysLeft

    }
    else {
        
        if ($EndDate -gt (Get-Date)){
            $InSupport = $true
        }
        else {$InSupport = $false}
        return $InSupport
    }
}
