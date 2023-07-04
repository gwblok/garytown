# https://learn.microsoft.com/en-us/microsoft-edge/extensions-chromium/developer-guide/alternate-distribution-options

$EdgeUpdateURL =  "https://edge.microsoft.com/extensionwebstorebase/v1/crx"
$GoogleUpdateURL =  "https://clients2.google.com/service/update2/crx"


$Extensions = @(
@{ Name = 'FoxFilter'; GUID = "pfbgokdillfdcimbbbbmlhpdinmmmogf"; Browser = "Edge"; UpdateURL = $EdgeUpdateURL}
@{ Name = 'FoxFilter'; GUID = "nopeodilnmhhlfageeohjojginlgeljk"; Browser = "Chrome"; UpdateURL = $GoogleUpdateURL}
@{ Name = 'BlockAge'; GUID = "dphfbpphnlnghbkipnplnklaajipjbfk"; Browser = "Edge"; UpdateURL = $EdgeUpdateURL}
@{ Name = 'HP Support Assist'; GUID = "alnedpmllcfpgldkagbfbjkloonjlfjb"; Browser = "Edge"; UpdateURL = $GoogleUpdateURL}
@{ Name = 'HP Support Assist'; GUID = "alnedpmllcfpgldkagbfbjkloonjlfjb"; Browser = "Chrome"; UpdateURL = $GoogleUpdateURL}
@{ Name = 'PorNo'; GUID = "fnfchnplgejcfmphhboehhlpcjnjkomp"; Browser = "Chrome"; UpdateURL = $GoogleUpdateURL}
@{ Name = 'NSFW Filter'; GUID = "kmgagnlkckiamnenbpigfaljmanlbbhh"; Browser = "Edge"; UpdateURL = $GoogleUpdateURL}
@{ Name = 'NSFW Filter'; GUID = "kmgagnlkckiamnenbpigfaljmanlbbhh"; Browser = "Chrome"; UpdateURL = $GoogleUpdateURL}
@{ Name = 'Defender'; GUID = "bkbeeeffjjeopflfhgeknacdieedcoml"; Browser = "Chrome"; UpdateURL = $GoogleUpdateURL}
@{ Name = 'Microsoft Editor: Spelling & Grammar Checker'; GUID = "gpaiobkfhnonedkhhfjpmhdalgeoebfa"; Browser = "Chrome"; UpdateURL = $GoogleUpdateURL}
@{ Name = 'Microsoft Editor: Spelling & Grammar Checker'; GUID = "hokifickgkhplphjiodbggjmoafhignh"; Browser = "Edge"; UpdateURL = $EdgeUpdateURL}

)


#Edge Create Extension Registry Key
$EdgeRegPath = "HKLM:Software\Wow6432Node\Microsoft\Edge\Extensions"
if (!(Test-Path -Path $EdgeRegPath)){
    New-Item -Path $EdgeRegPath | Out-Null
}

# Chrome Create Extension Registry Key
$ChromeRegPath = "HKLM:Software\Wow6432Node\Google\Chrome\Extensions"
if (!(Test-Path -Path $ChromeRegPath)){
    New-Item -Path $ChromeRegPath | Out-Null
}


#Create Extensions for in Regsitry For Browsers
foreach ($Extension in $Extensions){
    if ($Extension.Browser -eq 'Chrome'){$RegPath = $ChromeRegPath}
    if ($Extension.Browser -eq 'Edge'){$RegPath = $EdgeRegPath}
    Write-Host "Adding Extension $($Extension.Name) to $($Extension.Browser) Browser" -ForegroundColor Green
    New-Item -Path "$RegPath\$($Extension.GUID)" -Force | Out-Null
    New-ItemProperty -Path "$RegPath\$($Extension.GUID)" -Name "update_url" -PropertyType STRING -Value $Extension.UpdateURL | Out-Null
}
