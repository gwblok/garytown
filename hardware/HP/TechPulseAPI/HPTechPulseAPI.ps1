<# Gary Blok | @gwblok | GARYTOWN.COM

Information to build taken from:
https://developers.hp.com/hp-proactive-management/api/hp-techpulse-analytics-api

Please watch this video first and make sure you've created a Developer Account, gained access to the Tech Pulse API, created your API App, and have all of the pre-reqs done.
https://wexlearning.hosted.panopto.com/Panopto/Pages/Embed.aspx?id=7f4d7576-1597-464b-8896-b01a0155da23&autoplay

Region 1 = Defining Variables.
- Update the variables from you HP Developer portal
  - ClientID
  - Secret
  - Redirect URL - You can make this anything, I used http://localhost:5000/ - for PowerShell, it is not used, but still required to be part of the process.
- Find a safe place to store your AccessToken information. | I recommend storing it in an Azure KeyVault Secret.. which I'll probably blog later.

Region 2 = Getting the Access CODE needed to get the Access Token - Will launch Edge to get your intial Access Code, once you have that, you won't need to launch the browser for 365 days, when the refresh token expires.
 - First time it runs, it will launch the browser, you need to get the "Code" from the URL and place it into the varaible.

Region 3 = Section you run to open or create your Access Token - Make sure you update the $Code variable from the previous section

Region 4 = Getting Refresh Token and updating the Access Token. - After the first time you run this (Regions 1 - 3), you'll only need to run Region 1 & 4, skipping 2 & 3.

Other Regions are examples

------

Quick Start... - First Time
Update Variables: $BaseURL to your Region, $ClientID, $Secret, $redirect_uri

Get Code from Browser URL when Edge Launches and you Authenticate
Update $Code Varaible in Region 3 & Run Region 3.


I'd highly recommend against running the entire script at once, as it's not designed for that.  There are different regions with examples and various functions.
This "Script" is meant to be a starting point for you to build your own powershell processes.

Detailed Info on how to build Queries: https://developers.hp.com/hp-proactive-management/api/hp-techpulse-analytics-api

#>

#region 1

#Run this section after you update the variables $BaseURL to your Region, and the ClientID & Secret to your specific API's.

$BaseURL_US = "https://daas.api.hp.com"
$BaseURL_EU = "https://eu.daas.api.hp.com"

#Update for your Region
$BaseURL = $BaseURL_US

$ClientID = "AppClientID"
$Secret = "AppSecret"

$TokenURI = "$($BaseURL)/oauth/v1/token"
$redirect_uri = "https://localhost:5000/"

#Where you want to back up your access token
#$AccessTokenXMLPath = "\\nas\OpenShare\TechPulse\AccessTokenHP.xml"
$AccessTokenXMLPath = "$env:HOMEPATH\Documents\AccessToken.xml"
#endregion 1

#region 2 - Getting the Code for getting the Access Token - Launch Browser if doesn't find a saved Access Token in the path.

if (Test-path -Path $AccessTokenXMLPath){
    $AccessToken = Import-Clixml -Path $AccessTokenXMLPath
}
else {
    #Launch this to get the "code" you need:
    start "microsoft-edge:$($BaseURL)/oauth/v1/authorize?client_id=$($ClientID)&redirect_uri=$($redirect_uri)&response_type=code&scope=Read&state=DCEeFWf45A53sdfKef424"
    #This will then go to a blank screen after you authenicate, look at the URL and grab the Code ex: http://localhost:5000/?state=DCEeFWf45A53sdfKef424&code=SHoKvCOY
    #Code from Example: SHoKvCOY
    #Update the Variable with the Code:
     
}
#endregion 2

#region 3 - Getting the Access token using the Code you got from the Browser - if doesn't find a saved Access Token in the Path
if (Test-path -Path $AccessTokenXMLPath){
    $AccessToken = Import-Clixml -Path $AccessTokenXMLPath
}
else {

    $Code = "7klDTi8p"

    $Body = @{
        "grant_type" = "authorization_code"
        "code" = "$code"
        "redirect_uri" = $redirect_uri
        "client_id" = "$ClientID"
        "client_secret" = "$Secret"
    }

    $AccessToken = Invoke-RestMethod -Method Post -Body $Body -Uri $TokenURI
    $AccessToken | Export-Clixml -Path $AccessTokenXMLPath -Force # Save Token for future, to skip having to launch a browser to get Code.

}
#endregion 3



#region 4 - Refresh Token
$AccessToken = Import-Clixml -Path $AccessTokenXMLPath
$Auth = "$($ClientID):$($Secret)"
$encodedBytes = [System.Text.Encoding]::UTF8.GetBytes($Auth)
$encodedText = [System.Convert]::ToBase64String($encodedBytes)


$Headers = @{
    "Content-Type" = "application/x-www-form-urlencoded"
    "Authorization" = "Basic $encodedText"
}

$Body = @{
    "grant_type" = "refresh_token"
    "redirect_uri" = $redirect_uri
    "refresh_token" = $AccessToken.refresh_token
}

$Refresh = Invoke-RestMethod -Method Post -Headers $Headers -Body $Body -Uri $TokenURI

$Headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $($Refresh.access_token)"
}

#endregion 4




#Examples - Getting BIOS Info, which includes the Platform information
#https://developers.hp.com/hp-proactive-management/api/hp-techpulse-analytics-api#BIOS_Inventory
#$BIOS = Invoke-RestMethod -Method Post -Headers $Headers -Uri "$($BaseURL)/analytics/v1/reports/biosinventory/biosInventorySummary/type/graph"
#$HardwareInvDetails = Invoke-RestMethod -Method Post -Headers $Headers -Uri "$($BaseURL)/analytics/v1/reports/hwinv/details/type/grid"
#$HardwareInvAllData = Invoke-RestMethod -Method Post -Headers $Headers -Uri "$($BaseURL)/analytics/v1/reports/hwinv/allData/type/grid"


#=======================================================================================================
#region functions

#Test if specific platform of HP Device is supported by HP Image Assistant
function Test-HPIASupport ([string]$PlatformID){

    $CabPath = "$env:TEMP\platformList.cab"
    $XMLPath = "$env:TEMP\platformList.xml"
    $PlatformListCabURL = "https://hpia.hpcloud.hp.com/ref/platformList.cab"
    if (!(Test-Path $CabPath)){
        Invoke-WebRequest -Uri $PlatformListCabURL -OutFile $CabPath -UseBasicParsing
    }
    if (!(Test-Path $XMLPath)){
        $Expand = expand $CabPath $XMLPath
    }
    [xml]$XML = Get-Content $XMLPath
    $Platforms = $XML.ImagePal.Platform.SystemID
    if ($PlatformID){
        $MachinePlatform = $PlatformID
        }
    else {
        $MachinePlatform = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
    }
    if ($MachinePlatform -in $Platforms){$HPIASupport = $true}
    else {$HPIASupport = $false}

    return $HPIASupport
    }

#endregion
#=======================================================================================================

#region Get Unique Platform & Compare to HPIA Support
#Get Platforms from BIOS Data
$BIOS = Invoke-RestMethod -Method Post -Headers $Headers -Uri "$($BaseURL)/analytics/v1/reports/biosinventory/biosInventorySummary/type/graph"
$Devices = $BIOS.resources.summaryData
$Platforms = $devices.drilldownData.PlatformID.split(",").trim() | Select-Object  -Unique | Where-Object {$_.length -lt 5}

$PlatformHPIA = @()
#Check if supported by HPIA
foreach ($ID in $Platforms){  #Note, this takes awhile to loop through if you have a lot of unique platforms.
    #Get-HPDeviceDetails -Platform $ID
    Write-Host "-------------------------------------" -ForegroundColor DarkCyan
    $Details = Get-HPDeviceDetails -Platform $ID
    $HPIASupport = Test-HPIASupport -PlatformID $ID
    if ($HPIASupport -eq $true){$Color = 'Green'}
    else {$Color = 'Red'}
    write-host "Platform $ID HPIA Support: $($HPIASupport)" -ForegroundColor $Color
    #details.name
    if ($details){
        foreach ($detail in $details){
            $PlatformHPIA += New-Object psobject -Property @{
                Platform = $ID
                HPIA = $HPIASupport
                Model = $detail.name
            }
            Write-Host "$ID : $($Detail.name)"
        }
    }
    else {
        $PlatformHPIA += New-Object psobject -Property @{
            Platform = $ID
            HPIA = $HPIASupport
            Model = "NA"
        }
    }
}
#endregion

$SupportedPlatforms = ($PlatformHPIA | Where-Object {$_.HPIA -eq $true}).Platform | Select-Object -Unique
$SupportedDevices = $Devices | Where-Object {$_.drilldownData.PlatformID -in $SupportedPlatforms}
foreach ($SupportedDevice in $SupportedDevices){
    Write-Host "Supported Devices Platform: $($SupportedDevice.drilldownData.PlatformID) | Model: $($SupportedDevice.model)" -ForegroundColor Green
}


#=======================================================================================================

#region Get Model Counts (Based on Hardware Inventory Details)
$HardwareInv = Invoke-RestMethod -Method Post -Headers $Headers -Uri "$($BaseURL)/analytics/v1/reports/hwinv/details/type/grid"
$TotalResults = $HardwareInv.totalResults
$Pages = [math]::ceiling($TotalResults / 1000)
$PageCount = 1
$HardwareInvArray = @()
do {
    $HardwareInv = Invoke-RestMethod -Method Post -Headers $Headers -Uri "$($BaseURL)/analytics/v1/reports/hwinv/details/type/grid?startIndex=$($PageCount)&count=1000"
    $HardwareInvArray += $HardwareInv.resources
    $PageCount ++
} until (
    $PageCount -gt $Pages
)

$ModelsByCount = $hardwareinvarray.devicemodel | group-object | Where-Object {$_.Name -match "HP"} | Select-Object -Property Count, Name
#Display Models sorted by count:
$ModelsByCount | Sort-Object -Property count
#endregion

#=======================================================================================================
#region Get Hardware Inventory for specifc device
$DeviceName = "$env:ComputerName"
$HardwareInvDeviceDetail = Invoke-RestMethod -Method Post -Headers $Headers -Uri "$($BaseURL)/analytics/v1/reports/hwinv/details/type/grid?filter=devicename%20eq%20`"$($DeviceName)`""
#endregion

#=======================================================================================================

#region Get Warranty Info
#Expired Warranty Numbers
$WarrantyInv = Invoke-RestMethod -Method Post -Headers $Headers -Uri "$($BaseURL)/analytics/v1/reports/hwwarV2/details/type/graph"
$Expired = $WarrantyInv.resources[0].byDeviceWarranty | Where-Object {$_.warranty -match "Expired"}
$ExpiredCount = ($expired.data | Where-Object {$_.warStatusOverall -match "Out"}).noOfDevices

#Warranty Details
$WarrantyInvDetail = Invoke-RestMethod -Method Post -Headers $Headers -Uri "$($BaseURL)/analytics/v1/reports/hwwarV2/details/type/grid"
$TotalResults = $WarrantyInvDetail.totalResults
$Pages = [math]::ceiling($TotalResults / 1000)
$PageCount = 1
$HardwareInvArray = @()
do {
    $WarrantyInvDetail = Invoke-RestMethod -Method Post -Headers $Headers -Uri "$($BaseURL)/analytics/v1/reports/hwwarV2/details/type/grid?startIndex=$($PageCount)&count=1000"
    $WarrantyInvDetailArray += $WarrantyInvDetail.resources
    $PageCount ++
} until (
    $PageCount -gt $Pages
)
#note, this number will probably be much higher than your device count, as each device can have several warranty options
$WarrantyInvDetailArray.count

#Warranty by Device Name
#Example 1 Via Query for Device Name
$DeviceName = "$env:ComputerName"
$WarrantyInvDeviceDetail = Invoke-RestMethod -Method Post -Headers $Headers -Uri "$($BaseURL)/analytics/v1/reports/hwwarV2/details/type/grid?filter=devicename%20eq%20`"$($DeviceName)`""

#Example 2 Via BODY Tag & Only selecting specific attributes from the data.
$Body = @{
    "filter" = "devicename eq `"$DeviceName`""
    "selectedAttributes" = @("warStatusOverall","warRemainingOverall")
}
$WarrantyInvDeviceDetail = Invoke-RestMethod -Method Post -Headers $Headers -Uri "$($BaseURL)/analytics/v1/reports/hwwarV2/details/type/grid" -Body ($Body | ConvertTo-Json)

#endregion
#=======================================================================================================
