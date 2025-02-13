# Install the Microsoft.Graph module if not already installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force
}

# Import the Microsoft.Graph module
Import-Module Microsoft.Graph

# Define the required scopes
$scopes = @("https://graph.microsoft.com/.default")

# Authenticate and get the access token
$tenantId = "YOUR_TENANT_ID"
$clientId = "YOUR_CLIENT_ID"
$clientSecret = "YOUR_CLIENT_SECRET"

$body = @{
    grant_type    = "client_credentials"
    scope         = $scopes -join " "
    client_id     = $clientId
    client_secret = $clientSecret
}

$response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -ContentType "application/x-www-form-urlencoded" -Body $body
$accessToken = $response.access_token

# Set the authorization header
$headers = @{
    Authorization = "Bearer $accessToken"
}

# Search for Windows release information
$uri = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeploymentProfiles"
$response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers

# Output the response
$response.value | ForEach-Object {
    Write-Output "Name: $_.displayName"
    Write-Output "Description: $_.description"
    Write-Output "Assigned Devices: $_.assignedDevicesCount"
    Write-Output "-----------------------------"
}