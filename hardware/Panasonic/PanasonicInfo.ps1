<#
Gary Blok - Playing with Panasonic APIs
This script is a collection of functions to interact with Panasonic's API to get information on their devices and drivers.
Driver Pack XML: https://us.panasonic.com/business/iframes/xml/cabs.xml


TODO:
Incorporate OS Version and Release ID into the Get-PanasonicDeviceDownloads function
Create function Get-PanasonicBIOSUpdates (I think Panasonic might already provide this, I need to check)

Create Functions to install the Panasonic PowerShell Modules

Other?

#Usable Functions
Get-PanasonicDeviceDetails
Get-PanasonicDeviceDownloads

#>
#PreReqs - PowerShell 7.0 or higher
using namespace System.Management.Automation
$PSVersion = $PSVersionTable.PSVersion.Major
if ($PSVersion -ge 7) {
    class ValidCatGenerator : IValidateSetValuesGenerator {
        [string[]] GetValidValues() {
            $Values = (Get-PanasonicDLCategories).Name
            return $Values
        }
    }
}
#This is used to dynamically generate the ValidateSet for the Category Parameter

#>

# Get PowerShell Version


Write-Host "Functions for Panasonic Device Management" -ForegroundColor Cyan
$Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
if ($Manufacturer -match "Panasonic") {
    $Model = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
    Write-Host "Manufacturer: $Manufacturer" -ForegroundColor Green
    Write-Host "Model: $Model" -ForegroundColor Green
    write-host "--------------------------------------------------"
    Write-Host -ForegroundColor Green "[+] Function Invoke-MMSDemo2025"
    function Invoke-MMSDemo2025 {
        Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/hardware/Panasonic/PanasonicMMSDemo.ps1')
    }
    write-host "--------------------------------------------------"
    write-host "Notes - Panasonic Command Update requires PowerShell 5 (Not higher)" -ForegroundColor Yellow
    write-host "Panasonic URL: https://global-pc-support.connect.panasonic.com/driver/deployment-support-tools" -ForegroundColor Magenta
}

#region Functions
#Private
function Get-ApiData {
    param (
        [string]$url = "https://global-pc-support.connect.panasonic.com/dl/api/v1/search",
        [string]$query = ""
    )

    # Create the request URL
    if ($query -ne "") {
        $requestUrl = "$($url)?q=$($query)"
    }
    else {
        $requestUrl = $url
    }
    Write-Verbose "Request URL: $requestUrl"
    # Send the HTTP GET request
    try {
        $response = Invoke-RestMethod -Uri $requestUrl -Method Get -ContentType "application/json"
        return $response
    }
    catch {
        Write-Error "Failed to get data from API: $_"
    }
}

#Development
Write-Host "+ Function Get-PanasonicUpdateCatalog" -ForegroundColor Green
function Get-PanasonicUpdateCatalog {
    [CmdletBinding()]
    param (
        [validateSet("Drivers and Applications","BIOS and Firmware")]
        [string]$Category
    )
    $CabPathIndex = "$env:ProgramData\EMPS\CabDownloads\CatalogIndexPC.cab"
    $CabExtractPath = "$env:ProgramData\EMPS\CabDownloads\CabExtract"
    
    # Pull down  XML CAB  ,extract and Load
    if (!(Test-Path $CabExtractPath)){$null = New-Item -Path $CabExtractPath -ItemType Directory -Force}
    Write-Verbose "Downloading Cab"
    Invoke-WebRequest -Uri "https://pc-dl.panasonic.co.jp/public/sccmcatalog/PanasonicUpdateCatalog.cab" -OutFile $CabPathIndex -UseBasicParsing -Proxy $ProxyServer
    If(Test-Path "$CabExtractPath\DellSDPCatalogPC.xml"){Remove-Item -Path "$CabExtractPath\DellSDPCatalogPC.xml" -Force}
    Start-Sleep -Seconds 1
    if (test-path $CabExtractPath){Remove-Item -Path $CabExtractPath -Force -Recurse}
    $null = New-Item -Path $CabExtractPath -ItemType Directory
    Write-Verbose "Expanding the Cab File..." 
    $null = expand -r $CabPathIndex -f:PanasonicUpdateCatalog.xml $CabExtractPath
    Write-Verbose "Loading Catalog XML.... can take awhile"
    $Catalog = Get-ChildItem -Path $CabExtractPath -Filter *.xml -Recurse 
    [xml]$XMLIndex = Get-Content $Catalog.FullName
    $Updates = $XMLIndex.SystemsManagementCatalog.softwareDistributionPackage
    if ($Category) {
        $Updates = $Updates | Where-Object { $_.Properties.ProductName -eq $Category}
    }
    return $Updates
}
#Private
function  Get-PanasonicModelsFromSeries {
    param (
        [string]$SeriesID
    )
    [string]$url = "https://global-pc-support.connect.panasonic.com/ccm/pc_support/api/products"
    $apiUrl = "$($url)?parent=$($SeriesID)"
    $response = Get-ApiData -url $apiUrl
    $JSONResponse = $response.data | ConvertTo-Json -Depth 5 | ConvertFrom-Json

    return $JSONResponse  | Select-Object "id", "name" | Where-Object { $_.name -ne 'Tough' }
}

#Private
function  Get-PanasonicDLCategories {

    [string]$url = 'https://global-pc-support.connect.panasonic.com/ccm/pc_support/api/categories'
    [string]$url2 = 'https://global-pc-support.connect.panasonic.com/dl/api/v1/categories'
    $apiUrl = "$($url)?parent=200)"
    $response = Get-ApiData -url $apiUrl
    $JSONResponse = $response.data | ConvertTo-Json -Depth 5 | ConvertFrom-Json
    
    $apiUrl2 = $url2
    $response2 = Get-ApiData -url $apiUrl2
    $JSONResponse2 = $response2

    $Combo = @()
    $JSONResponse2 | ForEach-Object {
        $Category = $_
        $CategoryInfo = $JSONResponse | Where-Object { $_.name -eq $Category.text }
        $Combo += [PSCustomObject]@{
            value = $Category.value
            name = $Category.text
            id = $CategoryInfo.id
        }
    }
    $JSONResponse | Where-Object {$_.id -match "30" -and $_.name -match "-"} | ForEach-Object {
        $Category = $_ 
        [string]$value = ([string]$Category.id).replace("30","00200100")
        $Combo += [PSCustomObject]@{
            value = $value
            name = ($Category.name).replace(" - ","")
            id = $Category.id
        }
    }


    return $Combo
}
#Private
Function Get-PanasonicSeriesInfo {
    $SeriesInfo = @(
        @{SeriesID = "239";  Series = "FZ-40"}
        @{SeriesID = "232";  Series = "FZ-55"}
        @{SeriesID = "194";  Series = "FZ-A1"}
        @{SeriesID = "223";  Series = "FZ-A2"}
        @{SeriesID = "235";  Series = "FZ-A3"}
        @{SeriesID = "199";  Series = "JT-B1"}
        @{SeriesID = "210";  Series = "FZ-B2"}
        @{SeriesID = "208";  Series = "FZ-E1"}
        @{SeriesID = "221";  Series = "FZ-F1"}
        @{SeriesID = "198";  Series = "FZ-G1"}
        @{SeriesID = "237";  Series = "FZ-G2"}
        @{SeriesID = "231";  Series = "FZ-L1"}
        @{SeriesID = "205";  Series = "FZ-M1"}
        @{SeriesID = "220";  Series = "FZ-N1"}
        @{SeriesID = "219";  Series = "FZ-Q1"}
        @{SeriesID = "224";  Series = "FZ-Q2"}
        @{SeriesID = "217";  Series = "FZ-R1"}
        @{SeriesID = "236";  Series = "FZ-S1"}
        @{SeriesID = "230";  Series = "FZ-T1"}
        @{SeriesID = "209";  Series = "FZ-X1"}
        @{SeriesID = "216";  Series = "FZ-Y1"}
        @{SeriesID = "206";  Series = "UT-MB5"}
        @{SeriesID = "207";  Series = "UT-MA6"}
        @{SeriesID = "111";  Series = "CF-19"}
        @{SeriesID = "218";  Series = "CF-20"}
        @{SeriesID = "116";  Series = "CF-30"}
        @{SeriesID = "117";  Series = "CF-31"}
        @{SeriesID = "225";  Series = "CF-33"}
        @{SeriesID = "126";  Series = "CF-52"}
        @{SeriesID = "185";  Series = "CF-53"}
        @{SeriesID = "211";  Series = "CF-54"}
        @{SeriesID = "197";  Series = "CF-AX2"}
        @{SeriesID = "200";  Series = "CF-AX3"}
        @{SeriesID = "135";  Series = "CF-C1"}
        @{SeriesID = "196";  Series = "CF-C2"}
        @{SeriesID = "187";  Series = "CF-D1"}
        @{SeriesID = "137";  Series = "CF-F9"}
        @{SeriesID = "240";  Series = "CF-FV3"}
        @{SeriesID = "10300552";  Series = "CF-FV4"}
        @{SeriesID = "138";  Series = "CF-H1"}
        @{SeriesID = "186";  Series = "CF-H2"}
        @{SeriesID = "234";  Series = "CF-LV8"}
        @{SeriesID = "203";  Series = "CF-LX3"}
        @{SeriesID = "229";  Series = "CF-LX6"}
        @{SeriesID = "215";  Series = "CF-MX4"}
        @{SeriesID = "157";  Series = "CF-S9"}
        @{SeriesID = "183";  Series = "CF-S10"}
        @{SeriesID = "241";  Series = "CF-SR4"}
        @{SeriesID = "238";  Series = "CF-SV1"}
        @{SeriesID = "233";  Series = "CF-SV8"}
        @{SeriesID = "190";  Series = "CF-SX1"}
        @{SeriesID = "192";  Series = "CF-SX2"}
        @{SeriesID = "214";  Series = "CF-SX4"}
        @{SeriesID = "227";  Series = "CF-SZ6"}
        @{SeriesID = "164";  Series = "CF-U1"}
        @{SeriesID = "228";  Series = "CF-XZ6"}
        @{SeriesID = "195";  Series = "Option (FZ series)"}
        @{SeriesID = "175";  Series = "Option (CF series)"}
        @{SeriesID = "179";  Series = "All Model"}
    )
    return $SeriesInfo 
}
write-host "+ Function Get-PanasonicDeviceDetails" -ForegroundColor Green
Function Get-PanasonicDeviceDetails {
    [CmdletBinding(DefaultParameterSetName = 'Set2')]
    param (
        [Parameter( ParameterSetName = 'Set1')]    
        [validateSet("239", "232", "194", "223", "235", "199", "210", "208", "221", "198", "237", "231", "205", "220", "219", "224", "217", "236", "230", "209", "216", "206", "207", "111", "218", "116", "117", "225", "126", "185", "211", "197", "200", "135", "196", "187", "137", "240", "10300552", "138", "186", "234", "203", "229", "215", "157", "183", "241", "238", "233", "190", "192", "214", "227", "164", "228", "195", "175", "179")]
        [string]$SeriesID,
        [Parameter( ParameterSetName = 'Set2')]
        [validateSet("FZ-40", "FZ-55", "FZ-A1", "FZ-A2", "FZ-A3", "JT-B1", "FZ-B2", "FZ-E1", "FZ-F1", "FZ-G1", "FZ-G2", "FZ-L1", "FZ-M1", "FZ-N1", "FZ-Q1", "FZ-Q2", "FZ-R1", "FZ-S1", "FZ-T1", "FZ-X1", "FZ-Y1", "UT-MB5", "UT-MA6", "CF-19", "CF-20", "CF-30", "CF-31", "CF-33", "CF-52", "CF-53", "CF-54", "CF-AX2", "CF-AX3", "CF-C1", "CF-C2", "CF-D1", "CF-F9", "CF-FV3", "CF-FV4", "CF-H1", "CF-H2", "CF-LV8", "CF-LX3", "CF-LX6", "CF-MX4", "CF-S9", "CF-S10", "CF-SR4", "CF-SV1", "CF-SV8", "CF-SX1", "CF-SX2", "CF-SX4", "CF-SZ6", "CF-U1", "CF-XZ6", "Option (FZ series)", "Option (CF series)", "All Model")]
        [string]$Series
    )
    $SeriesInfo = Get-PanasonicSeriesInfo
    if ($SeriesID -or $Series){
        $DeviceInfo = $SeriesInfo | Where-Object { $_.SeriesID -eq $SeriesID -or $_.Series -eq $Series }
        $SeriesModels = Get-PanasonicModelsFromSeries -SeriesID $DeviceInfo.SeriesID

        if ($SeriesModels){
            $DeviceDetailsObjectArray = @()
            foreach ($Model in $SeriesModels){
                [String]$SeriesID = $DeviceInfo.SeriesID
                [String]$ModelID = $Model.id
                $WebID = $SeriesID + ($ModelID.substring($ModelID.length - 4, 4))
                $DeviceDetailsObject = New-Object PSObject -Property @{
                    SeriesID = $DeviceInfo.SeriesID
                    ModelID = $Model.id
                    Model = $Model.name
                    WebID = $WebID

                }
                $DeviceDetailsObjectArray += $DeviceDetailsObject
            }
            return $DeviceDetailsObjectArray
        }
        #return $SeriesModels
    }
    else {
        $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
        if ($Manufacturer -match "Panasonic") {
            $Model = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
            #$SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
            #$Product = (Get-CimInstance -className Win32_BaseBoard).Product
            #Convert Model into Series Name
            $SeriesNamePrefix = ($Model.split("-")[0]).substring(0,2)
            $SeriesNameSuffix = ($Model.Split("-")[0]).Replace($SeriesNamePrefix,"")
            $SeriesName = $SeriesNamePrefix + "-" + $SeriesNameSuffix
            $DeviceInfo = $SeriesInfo | Where-Object { $_.Series -eq $SeriesName }
            $SeriesModels = Get-PanasonicModelsFromSeries -SeriesID $DeviceInfo.SeriesID
            $MKNumber = $Model.Split("-")[1]
            $MKString = "mk" + $MKNumber
            $DeviceDetails = $SeriesModels | Where-Object { $_.name -match $MKString }
            #Get the Last 4 characters of the ID
            [String]$SeriesID = $DeviceInfo.SeriesID
            [String]$ModelID = $DeviceDetails.id
            $WebID = $SeriesID + ($ModelID.substring($ModelID.length - 4, 4))
            $DeviceDetailsObject = New-Object PSObject -Property @{
                SeriesID = $DeviceInfo.SeriesID
                Series = $DeviceInfo.Series
                ModelID = $ModelID
                Model = $DeviceDetails.name
                WebID = $WebID
            }
            return $DeviceDetailsObject
        }
        else {
            Write-Error "This function is only for Panasonic Devices"
            Write-Error "Specify a SeriesID or Series if this isn't a Panasonic Device"
        }
    }
}
Write-Host "+ Function Get-PanasonicDeviceDownloads" -ForegroundColor Green
function Get-PanasonicDeviceDownloads{
    [CmdletBinding()]
    param (
        [validateSet("FZ-40", "FZ-55", "FZ-A1", "FZ-A2", "FZ-A3", "JT-B1", "FZ-B2", "FZ-E1", "FZ-F1", "FZ-G1", "FZ-G2", "FZ-L1", "FZ-M1", "FZ-N1", "FZ-Q1", "FZ-Q2", "FZ-R1", "FZ-S1", "FZ-T1", "FZ-X1", "FZ-Y1", "UT-MB5", "UT-MA6", "CF-19", "CF-20", "CF-30", "CF-31", "CF-33", "CF-52", "CF-53", "CF-54", "CF-AX2", "CF-AX3", "CF-C1", "CF-C2", "CF-D1", "CF-F9", "CF-FV3", "CF-FV4", "CF-H1", "CF-H2", "CF-LV8", "CF-LX3", "CF-LX6", "CF-MX4", "CF-S9", "CF-S10", "CF-SR4", "CF-SV1", "CF-SV8", "CF-SX1", "CF-SX2", "CF-SX4", "CF-SZ6", "CF-U1", "CF-XZ6", "Option (FZ series)", "Option (CF series)", "All Model")]
        [string]$Series,
        [string]$ModelWebID,
        [Parameter(Mandatory=$true)]
        [ValidateSet( [ValidCatGenerator] )]
        [string]$Category,
        [switch]$Details
    )
    $Categories = Get-PanasonicDLCategories
    $CategoryInfo = $Categories | Where-Object { $_.name -match $Category }
    $CategoryValue = $CategoryInfo.value
    Write-Verbose "RequestedCategory: $Category"
    Write-Verbose "CategoryInfo: $CategoryInfo"
    #Get-PanasonicDeviceDetails -Series $Series
    $SeriesInfo = Get-PanasonicSeriesInfo
    $SeriesID = ($SeriesInfo | Where-Object { $_.Series -eq $Series }).SeriesID
    write-verbose "Requested Series: $Series"
    write-verbose "Series Info: $SeriesID"
    [string]$url = "https://global-pc-support.connect.panasonic.com/dl/api/v1/search"
    [string]$query = "&dc%5B%5D=$($CategoryValue)&p1=$($SeriesID)"
    $apiurl = "https://global-pc-support.connect.panasonic.com/dl/api/v1/search?q=&dc%5B%5D=$($CategoryValue)&p1=$($SeriesID)&p2=$($ModelWebID)"
    Write-Verbose "Url: $url"
    Write-Verbose "query: $query"
    write-verbose "API URL: $apiurl"
    $response = Get-ApiData -url $apiurl
    $JSONResponse = $response.search_results | ConvertTo-Json -Depth 5 | ConvertFrom-Json

    if ($Details){
        $DownloadDetailsObjectArray = @()
        foreach ($Download in $JSONResponse){
            $DetailResponseRAW = Get-ApiData -url $Download.detail_url
            $DetailResponse = $DetailResponseRAW
            $DownloadDetailsObject = New-Object PSObject -Property @{
                Category = $Category
                Series = $Series
                ModelWebID = $ModelWebID
                Title = $Download.title
                DocumentNumber = $Download.doc_no
                Updated = $Download.doc_updated_on
                DocumentURL = $Download.detail_url
                Path = $DetailResponse.files.Path
            }
            $DownloadDetailsObjectArray += $DownloadDetailsObject
        }
    }
    else{
        $DownloadDetailsObjectArray = @()
        foreach ($Download in $JSONResponse){
            $DownloadDetailsObject = New-Object PSObject -Property @{
                Category = $Category
                Series = $Series
                ModelWebID = $ModelWebID
                Title = $Download.title
                DocumentNumber = $Download.doc_no
                Updated = $Download.doc_updated_on
                DocumentURL = $Download.detail_url
            }
            $DownloadDetailsObjectArray += $DownloadDetailsObject
        }
    }
    return $DownloadDetailsObjectArray

    #return $JSONResponse | Select-Object -Property "title","doc_updated_on","doc_no","detail_url" 
}
write-host "+ Function Install-AllPanasonicModules" -ForegroundColor Green
Function Install-AllPanasonicModules {
    $Modules = @(
        "PanasonicCommandUpdate",
        "PanasonicCommandPCSettings",
        "PanasonicCommandBIOSSettings"
    )
    foreach ($Module in $Modules) {
        Write-Host "Installing Module: $Module" -ForegroundColor Cyan
        try {
            Install-Module -Name $Module -Scope AllUsers -Force -AllowClobber -Repository PSGallery
            Write-Host "Successfully installed $Module" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to install $Module - $_"
        }
    }
}


#endregion