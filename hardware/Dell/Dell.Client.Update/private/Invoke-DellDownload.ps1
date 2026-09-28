function Invoke-DellDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [uri]$Proxy,
        [pscredential]$ProxyCredential,
        [switch]$ProxyUseDefaultCredentials
    )

    Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    $bitsParameters = @{
        Source = $Source.AbsoluteUri
        Destination = $Destination
        TransferType = 'Download'
        Priority = 'Foreground'
        ErrorAction = 'Stop'
    }
    if ($Proxy) {
        $bitsParameters.ProxyUsage = 'Override'
        $bitsParameters.ProxyList = @($Proxy)
    }
    if ($ProxyCredential -and -not $ProxyUseDefaultCredentials) {
        $bitsParameters.ProxyCredential = $ProxyCredential
    }

    Start-BitsTransfer @bitsParameters
}