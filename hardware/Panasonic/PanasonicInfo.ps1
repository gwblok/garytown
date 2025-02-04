<#
Driver Pack XML: https://us.panasonic.com/business/iframes/xml/cabs.xml


#>

function Get-ApiData {
    param (
        [string]$url = "https://global-pc-support.connect.panasonic.com/dl/api/v1/search",
        [string]$query = ""
    )

    # Create the request URL
    $requestUrl = "$($url)?q=$($query)"

    # Send the HTTP GET request
    try {
        $response = Invoke-RestMethod -Uri $requestUrl -Method Get -ContentType "application/json"
        return $response
    }
    catch {
        Write-Error "Failed to get data from API: $_"
    }
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

function  Get-PanasonicDLCategoriesFromModel {
    param (
        [string]$SeriesID,
        [string]$ModelId
    )
    [string]$url = "https://global-pc-support.connect.panasonic.com/ccm/pc_support/api/categories"
    $apiUrl = "$($url)?series=$($ModelId)&model=$($ModelId)"
    $response = Get-ApiData -url $apiUrl
    $JSONResponse = $response.data | ConvertTo-Json -Depth 5 | ConvertFrom-Json
    return $JSONResponse 
}

Function Get-PanasonicDeviceDetails {
    [CmdletBinding(DefaultParameterSetName = 'Set2')]
    param (
        [Parameter( ParameterSetName = 'Set1')]    
        [validateSet("239", "232", "194", "223", "235", "199", "210", "208", "221", "198", "237", "231", "205", "220", "219", "224", "217", "236", "230", "209", "216", "206", "207", "111", "218", "116", "117", "225", "126", "185", "211", "197", "200", "135", "196", "187", "137", "240", "10300552", "138", "186", "234", "203", "229", "215", "157", "183", "241", "238", "233", "190", "192", "214", "227", "164", "228", "195", "175", "179")]
        [string]$SeriesID,
        [Parameter( ParameterSetName = 'Set2')]
        [validateSet("FZ-40", "FZ-55", "FZ-A1", "FZ-A2", "FZ-A3", "JT-B1", "FZ-B2", "FZ-E1", "FZ-F1", "FZ-G1", "FZ-G2", "FZ-L1", "FZ-M1", "FZ-N1", "FZ-Q1", "FZ-Q2", "FZ-R1", "FZ-S1", "FZ-T1", "FZ-X1", "FZ-Y1", "UT-MB5", "UT-MA6", "CF-19", "CF-20", "CF-30", "CF-31", "CF-33", "CF-52", "CF-53", "CF-54", "CF-AX2", "CF-AX3", "CF-C1", "CF-C2", "CF-D1", "CF-F9", "CF-FV3", "CF-FV4", "CF-H1", "CF-H2", "CF-LV8", "CF-LX3", "CF-LX6", "CF-MX4", "CF-S9", "CF-S10", "CF-SR4", "CF-SV1", "CF-SV8", "CF-SX1", "CF-SX2", "CF-SX4", "CF-SZ6", "CF-U1", "CF-XZ6", "Option (FZ series)", "Option (CF series)", "All Model")]
        [string]$ModelId
    )
    $SeriesInfo = @(
        @{SeriesID = "239";  Model = "FZ-40"}
        @{SeriesID = "232";  Model = "FZ-55"}
        @{SeriesID = "194";  Model = "FZ-A1"}
        @{SeriesID = "223";  Model = "FZ-A2"}
        @{SeriesID = "235";  Model = "FZ-A3"}
        @{SeriesID = "199";  Model = "JT-B1"}
        @{SeriesID = "210";  Model = "FZ-B2"}
        @{SeriesID = "208";  Model = "FZ-E1"}
        @{SeriesID = "221";  Model = "FZ-F1"}
        @{SeriesID = "198";  Model = "FZ-G1"}
        @{SeriesID = "237";  Model = "FZ-G2"}
        @{SeriesID = "231";  Model = "FZ-L1"}
        @{SeriesID = "205";  Model = "FZ-M1"}
        @{SeriesID = "220";  Model = "FZ-N1"}
        @{SeriesID = "219";  Model = "FZ-Q1"}
        @{SeriesID = "224";  Model = "FZ-Q2"}
        @{SeriesID = "217";  Model = "FZ-R1"}
        @{SeriesID = "236";  Model = "FZ-S1"}
        @{SeriesID = "230";  Model = "FZ-T1"}
        @{SeriesID = "209";  Model = "FZ-X1"}
        @{SeriesID = "216";  Model = "FZ-Y1"}
        @{SeriesID = "206";  Model = "UT-MB5"}
        @{SeriesID = "207";  Model = "UT-MA6"}
        @{SeriesID = "111";  Model = "CF-19"}
        @{SeriesID = "218";  Model = "CF-20"}
        @{SeriesID = "116";  Model = "CF-30"}
        @{SeriesID = "117";  Model = "CF-31"}
        @{SeriesID = "225";  Model = "CF-33"}
        @{SeriesID = "126";  Model = "CF-52"}
        @{SeriesID = "185";  Model = "CF-53"}
        @{SeriesID = "211";  Model = "CF-54"}
        @{SeriesID = "197";  Model = "CF-AX2"}
        @{SeriesID = "200";  Model = "CF-AX3"}
        @{SeriesID = "135";  Model = "CF-C1"}
        @{SeriesID = "196";  Model = "CF-C2"}
        @{SeriesID = "187";  Model = "CF-D1"}
        @{SeriesID = "137";  Model = "CF-F9"}
        @{SeriesID = "240";  Model = "CF-FV3"}
        @{SeriesID = "10300552";  Model = "CF-FV4"}
        @{SeriesID = "138";  Model = "CF-H1"}
        @{SeriesID = "186";  Model = "CF-H2"}
        @{SeriesID = "234";  Model = "CF-LV8"}
        @{SeriesID = "203";  Model = "CF-LX3"}
        @{SeriesID = "229";  Model = "CF-LX6"}
        @{SeriesID = "215";  Model = "CF-MX4"}
        @{SeriesID = "157";  Model = "CF-S9"}
        @{SeriesID = "183";  Model = "CF-S10"}
        @{SeriesID = "241";  Model = "CF-SR4"}
        @{SeriesID = "238";  Model = "CF-SV1"}
        @{SeriesID = "233";  Model = "CF-SV8"}
        @{SeriesID = "190";  Model = "CF-SX1"}
        @{SeriesID = "192";  Model = "CF-SX2"}
        @{SeriesID = "214";  Model = "CF-SX4"}
        @{SeriesID = "227";  Model = "CF-SZ6"}
        @{SeriesID = "164";  Model = "CF-U1"}
        @{SeriesID = "228";  Model = "CF-XZ6"}
        @{SeriesID = "195";  Model = "Option (FZ series)"}
        @{SeriesID = "175";  Model = "Option (CF series)"}
        @{SeriesID = "179";  Model = "All Model"}
    )
    $DeviceInfo = $SeriesInfo | Where-Object { $_.SeriesID -eq $SeriesID -or $_.Model -eq $ModelId }

    $SeriesModels = Get-PanasonicModelsFromSeries -SeriesID $DeviceInfo.SeriesID
    $DLs = ""
    return $SeriesModels
}

$SeriesInfo = @(
@{SeriesID = "239";  Model = "FZ-40"}
@{SeriesID = "232";  Model = "FZ-55"}
@{SeriesID = "194";  Model = "FZ-A1"}
@{SeriesID = "223";  Model = "FZ-A2"}
@{SeriesID = "235";  Model = "FZ-A3"}
@{SeriesID = "199";  Model = "JT-B1"}
@{SeriesID = "210";  Model = "FZ-B2"}
@{SeriesID = "208";  Model = "FZ-E1"}
@{SeriesID = "221";  Model = "FZ-F1"}
@{SeriesID = "198";  Model = "FZ-G1"}
@{SeriesID = "237";  Model = "FZ-G2"}
@{SeriesID = "231";  Model = "FZ-L1"}
@{SeriesID = "205";  Model = "FZ-M1"}
@{SeriesID = "220";  Model = "FZ-N1"}
@{SeriesID = "219";  Model = "FZ-Q1"}
@{SeriesID = "224";  Model = "FZ-Q2"}
@{SeriesID = "217";  Model = "FZ-R1"}
@{SeriesID = "236";  Model = "FZ-S1"}
@{SeriesID = "230";  Model = "FZ-T1"}
@{SeriesID = "209";  Model = "FZ-X1"}
@{SeriesID = "216";  Model = "FZ-Y1"}
@{SeriesID = "206";  Model = "UT-MB5"}
@{SeriesID = "207";  Model = "UT-MA6"}
@{SeriesID = "111";  Model = "CF-19"}
@{SeriesID = "218";  Model = "CF-20"}
@{SeriesID = "116";  Model = "CF-30"}
@{SeriesID = "117";  Model = "CF-31"}
@{SeriesID = "225";  Model = "CF-33"}
@{SeriesID = "126";  Model = "CF-52"}
@{SeriesID = "185";  Model = "CF-53"}
@{SeriesID = "211";  Model = "CF-54"}
@{SeriesID = "197";  Model = "CF-AX2"}
@{SeriesID = "200";  Model = "CF-AX3"}
@{SeriesID = "135";  Model = "CF-C1"}
@{SeriesID = "196";  Model = "CF-C2"}
@{SeriesID = "187";  Model = "CF-D1"}
@{SeriesID = "137";  Model = "CF-F9"}
@{SeriesID = "240";  Model = "CF-FV3"}
@{SeriesID = "10300552";  Model = "CF-FV4"}
@{SeriesID = "138";  Model = "CF-H1"}
@{SeriesID = "186";  Model = "CF-H2"}
@{SeriesID = "234";  Model = "CF-LV8"}
@{SeriesID = "203";  Model = "CF-LX3"}
@{SeriesID = "229";  Model = "CF-LX6"}
@{SeriesID = "215";  Model = "CF-MX4"}
@{SeriesID = "157";  Model = "CF-S9"}
@{SeriesID = "183";  Model = "CF-S10"}
@{SeriesID = "241";  Model = "CF-SR4"}
@{SeriesID = "238";  Model = "CF-SV1"}
@{SeriesID = "233";  Model = "CF-SV8"}
@{SeriesID = "190";  Model = "CF-SX1"}
@{SeriesID = "192";  Model = "CF-SX2"}
@{SeriesID = "214";  Model = "CF-SX4"}
@{SeriesID = "227";  Model = "CF-SZ6"}
@{SeriesID = "164";  Model = "CF-U1"}
@{SeriesID = "228";  Model = "CF-XZ6"}
@{SeriesID = "195";  Model = "Option (FZ series)"}
@{SeriesID = "175";  Model = "Option (CF series)"}
@{SeriesID = "179";  Model = "All Model"}

)

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

#>