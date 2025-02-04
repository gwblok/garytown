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

<##>
https://global-pc-support.connect.panasonic.com/search?q=&s=239&m=&c=&o=&l=&per_page=25#search_result
https://global-pc-support.connect.panasonic.com/search?q=&s=239&m=1030693&c=&o=&l=&per_page=25#search_result
#>
function  Get-PanasonicModels {
    param (
        [string]$Product,
        [string]$ModelNumber
    )
    [string]$url = "https://global-pc-support.connect.panasonic.com/ccm/pc_support/api/products"
    $apiUrl = "$($url)?parent=$($product)"

    $response = Get-ApiData -url $apiUrl
    $JSONResponse = $response.data| ConvertTo-Json -Depth 5

    return $JSONResponse | ConvertFrom-Json | Select-Object id, name | Where-Object { $_.name -ne 'Tough' }
}

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