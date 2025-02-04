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


https://global-pc-support.connect.panasonic.com/search?q=&s=239&m=&c=&o=&l=&per_page=25#search_result

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

#>