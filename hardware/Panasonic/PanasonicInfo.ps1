<#
Driver Pack XML: https://us.panasonic.com/business/iframes/xml/cabs.xml


#>

using namespace System.Management.Automation

class ValidCatGenerator : IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        $Values = (Get-PanasonicDLCategories).Name
        return $Values
    }
}

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


<#
# Example usage
$response = Get-ApiData -query $query
$JSONResponse = $response.search_results | ConvertTo-Json -Depth 5
($JSONResponse | ConvertFrom-Json).count

$s_Product = '239' #FZ-40
$m_ModelNumber
$c_Category
$o_OperatingSystem
$l_Language
$query = "&s=$s_Product&m=$m_ModelNumber&c=$c_Category&o=$o_OperatingSystem&l=$l_Language"


https://global-pc-support.connect.panasonic.com/search?q=&s=239&m=&c=&o=&l=&per_page=25#search_result
https://global-pc-support.connect.panasonic.com/search?q=&s=239&m=1030693&c=&o=&l=&per_page=25#search_result
#>
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

<#
function  Get-PanasonicDLCategories {

    [string]$url = "https://global-pc-support.connect.panasonic.com/dl/api/v1/categories"
    $apiUrl = "$($url)"
    $response = Get-ApiData -url $apiUrl
    return $response 
}
#>
<#
    searchParams.set('parent', 200);
    searchParams.set('series', seriesSelect.value);
    searchParams.set('model', modelSelect.value);
    searchParams.set('os', osSelect.value);
    searchParams.set('language', languageSelect.value);
    const apiUrl = 'https://global-pc-support.connect.panasonic.com/ccm/pc_support/api/categories' + '?' + searchParams.toString();
#>

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
    if ($SeriesID -or $Series){
        $SeriesInfo = Get-PanasonicSeriesInfo
        $DeviceInfo = $SeriesInfo | Where-Object { $_.SeriesID -eq $SeriesID -or $_.Series -eq $Series }

        $SeriesModels = Get-PanasonicModelsFromSeries -SeriesID $DeviceInfo.SeriesID

        return $SeriesModels
    }
    else {
        $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
        if ($Manufacturer -match "Panasonic") {
            $Model = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
            $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
            $Product = (Get-CimInstance -className Win32_BaseBoard).Product
        }
        else {
            Write-Error "This function is only for Panasonic Devices"
            Write-Error "Specify a SeriesID or Series if this isn't a Panasonic Device"
        }

    }
}




function Get-PanasonicDeviceDownloads{
    [CmdletBinding()]
    param (
        [validateSet("FZ-40", "FZ-55", "FZ-A1", "FZ-A2", "FZ-A3", "JT-B1", "FZ-B2", "FZ-E1", "FZ-F1", "FZ-G1", "FZ-G2", "FZ-L1", "FZ-M1", "FZ-N1", "FZ-Q1", "FZ-Q2", "FZ-R1", "FZ-S1", "FZ-T1", "FZ-X1", "FZ-Y1", "UT-MB5", "UT-MA6", "CF-19", "CF-20", "CF-30", "CF-31", "CF-33", "CF-52", "CF-53", "CF-54", "CF-AX2", "CF-AX3", "CF-C1", "CF-C2", "CF-D1", "CF-F9", "CF-FV3", "CF-FV4", "CF-H1", "CF-H2", "CF-LV8", "CF-LX3", "CF-LX6", "CF-MX4", "CF-S9", "CF-S10", "CF-SR4", "CF-SV1", "CF-SV8", "CF-SX1", "CF-SX2", "CF-SX4", "CF-SZ6", "CF-U1", "CF-XZ6", "Option (FZ series)", "Option (CF series)", "All Model")]
        [string]$Series,

        [Parameter(Mandatory=$true)]
        [ValidateSet( [ValidCatGenerator] )]
        [string]$Category
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
    $apiurl = "https://global-pc-support.connect.panasonic.com/dl/api/v1/search?q=&dc%5B%5D=$($CategoryValue)&p1=$($SeriesID)"
    Write-Verbose "Url: $url"
    Write-Verbose "query: $query"
    write-verbose "API URL: $apiurl"

    #$response = Get-ApiData -url $url -query $query
    $response = Get-ApiData -url $apiurl
    $JSONResponse = $response.search_results | ConvertTo-Json -Depth 5 | ConvertFrom-Json

    
    return $JSONResponse | Select-Object -Property "title","doc_updated_on","doc_no","detail_url" 
}
#$url = 'https://global-pc-support.connect.panasonic.com/dl/api/v1/search?p1=239&p2=1030693'
#$url ='https://pc-dl.panasonic.co.jp/dl/api/v1/search?q=&p1=232&p2=1020703'
# https://global-pc-support.connect.panasonic.com/search?q=&s=232&m=1020703&c=10400&o=&l=&per_page=25#search_result
#https://pc-dl.panasonic.co.jp/dl/api/v1/search?q=&button=&dc%5B%5D=002001&p1=135&


<#

 <select id="seriesSelect" name="s" class="form_sel form-select">
    <option value="">All</option>
    <option value="239" selected="selected">FZ-40</option>
    <option value="232">FZ-55</option>
    <option value="194">FZ-A1</option>

    <option value="223">FZ-A2</option>
    <option value="235">FZ-A3</option>
    <option value="199">JT-B1</option>
    <option value="210">FZ-B2</option>
    <option value="208">FZ-E1</option>
    <option value="221">FZ-F1</option>
    <option value="198">FZ-G1</option>
    <option value="237">FZ-G2</option>
    <option value="231">FZ-L1</option>
    <option value="205">FZ-M1</option>
    <option value="220">FZ-N1</option>
    <option value="219">FZ-Q1</option>
    <option value="224">FZ-Q2</option>
    <option value="217">FZ-R1</option>
    <option value="236">FZ-S1</option>
    <option value="230">FZ-T1</option>
    <option value="209">FZ-X1</option>
    <option value="216">FZ-Y1</option>
    <option value="206">UT-MB5</option>
    <option value="207">UT-MA6</option>
    <option value="111">CF-19</option>
    <option value="218">CF-20</option>
    <option value="116">CF-30</option>
    <option value="117">CF-31</option>
    <option value="225">CF-33</option>
    <option value="126">CF-52</option>
    <option value="185">CF-53</option>
    <option value="211">CF-54</option>
    <option value="197">CF-AX2</option>
    <option value="200">CF-AX3</option>
    <option value="135">CF-C1</option>
    <option value="196">CF-C2</option>
    <option value="187">CF-D1</option>
    <option value="137">CF-F9</option>
    <option value="240">CF-FV3</option>
    <option value="10300552">CF-FV4</option>
    <option value="138">CF-H1</option>
    <option value="186">CF-H2</option>
    <option value="234">CF-LV8</option>
    <option value="203">CF-LX3</option>
    <option value="229">CF-LX6</option>
    <option value="215">CF-MX4</option>
    <option value="157">CF-S9</option>
    <option value="183">CF-S10</option>
    <option value="241">CF-SR4</option>
    <option value="238">CF-SV1</option>
    <option value="233">CF-SV8</option>
    <option value="190">CF-SX1</option>
    <option value="192">CF-SX2</option>
    <option value="214">CF-SX4</option>
    <option value="227">CF-SZ6</option>
    <option value="164">CF-U1</option>
    <option value="228">CF-XZ6</option>
    <option value="195">Option (FZ series)</option>
    <option value="175">Option (CF series)</option>
    <option value="179">All Model</option>
</select>

const fetchModels = function(parentId, selectedId='') {
    const searchParams = new URLSearchParams();
    searchParams.set('parent', parentId);
    searchParams.set('limit', '100');
    const apiUrl = 'https://global-pc-support.connect.panasonic.com/ccm/pc_support/api/products' + '?' + searchParams.toString();
    fetch(apiUrl).then(response => {
        if (!response.ok) {
            throw new Error('Network response was not ok');
        }
        return response.json();
    }
    ).then(responseObject => {
        responseObject.data.forEach(function(item) {
            const option = new Option(item.name,item.id,false,item.id === parseInt(selectedId));
            modelSelect.add(option);
        });
    }
    ).catch( (error) => {
        console.error('Error:', error);
    }
    );
};

const fetchCategories = function(selectedId='') {
    const searchParams = new URLSearchParams();
    searchParams.set('parent', 200);
    searchParams.set('series', seriesSelect.value);
    searchParams.set('model', modelSelect.value);
    searchParams.set('os', osSelect.value);
    searchParams.set('language', languageSelect.value);
    const apiUrl = 'https://global-pc-support.connect.panasonic.com/ccm/pc_support/api/categories' + '?' + searchParams.toString();
    fetch(apiUrl).then(response => {
        if (!response.ok) {
            throw new Error('Network response was not ok');
        }
        return response.json();
    }
    ).then(responseObject => {
        responseObject.data.forEach(function(item) {
            const option = new Option(item.name,item.id,false,item.id === parseInt(selectedId));
            categorySelect.add(option);
        });
    }
    ).catch( (error) => {
        console.error('Error:', error);
    }
    );
}

const fetchOses = function(selectedId='') {
    const searchParams = new URLSearchParams();
    searchParams.set('parent', 100);
    searchParams.set('series', seriesSelect.value);
    searchParams.set('model', modelSelect.value);
    searchParams.set('category', categorySelect.value);
    searchParams.set('language', languageSelect.value);
    const apiUrl = 'https://global-pc-support.connect.panasonic.com/ccm/pc_support/api/categories' + '?' + searchParams.toString();
    fetch(apiUrl).then(response => {
        if (!response.ok) {
            throw new Error('Network response was not ok');
        }
        return response.json();
    }
    ).then(responseObject => {
        responseObject.data.forEach(function(item) {
            const option = new Option(item.name,item.id,false,item.id === parseInt(selectedId));
            osSelect.add(option);
        });
    }
    ).catch( (error) => {
        console.error('Error:', error);
    }
    );
}

const fetchLanguages = function(selectedId='') {
    const searchParams = new URLSearchParams();
    searchParams.set('series', seriesSelect.value);
    searchParams.set('model', modelSelect.value);
    searchParams.set('category', categorySelect.value);
    searchParams.set('os', osSelect.value);
    const apiUrl = 'https://global-pc-support.connect.panasonic.com/ccm/pc_support/api/languages' + '?' + searchParams.toString();
    fetch(apiUrl).then(response => {
        if (!response.ok) {
            throw new Error('Network response was not ok');
        }
        return response.json();
    }
    ).then(responseObject => {
        responseObject.data.forEach(function(item) {
            const option = new Option(item.name,item.id,false,item.id === parseInt(selectedId));
            languageSelect.add(option);
        });
    }
    ).catch( (error) => {
        console.error('Error:', error);
    }
    );
}

<option value="10861">Windows 11 Ver.24H2</option>
<option value="10840">Windows 11 Ver.23H2</option>
<option value="10760">Windows 11 Ver.22H2</option>
<option value="10700">Windows 11 Ver.21H2</option>
<option value="10780">Windows 10 64bit Ver.22H2</option>

<option value="10260">All languages</option>
<option value="3">English</option>
#>