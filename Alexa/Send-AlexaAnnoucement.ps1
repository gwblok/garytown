# Configuration - Get these from your Alexa Developer Console
$clientId = "amzn1.application-oa2-client."
$clientSecret = "amzn1.oa2-cs.v1."
$uri = "https://api.amazon.com/auth/o2/token"
$proactiveUri = "https://api.amazonalexa.com/v1/proactiveEvents"

# Get Access Token
$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = "alexa::proactive_events"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json"
$accessToken = $response.access_token

# Create Announcement
$announcementPayload = @{
    timestamp = (Get-Date -Format "o")
    referenceId = "unique-id-$(Get-Random)"
    expiryTime = (Get-Date).AddDays(1).ToString("o")
    event = @{
        name = "AMAZON.MessageAlert.Activated"
        payload = @{
            state = @{
                status = "UNREAD"
                freshness = "NEW"
            }
            message = @{
                creator = @{
                    name = "PowerShellApp"
                }
                content = "Hello from PowerShell!"
            }
        }
    }
    relevantAudience = @{
        type = "Multicast"
        payload = @{}
    }
} | ConvertTo-Json -Depth 5

# Send Announcement
$headers = @{
    Authorization = "Bearer $accessToken"
    "Content-Type" = "application/json"
}
Invoke-RestMethod -Uri $proactiveUri -Method Post -Headers $headers -Body $announcementPayload