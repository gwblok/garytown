function Test-DellUpdatePackage {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256
    )

    $actualDigest = (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
    if ($actualDigest -ine $ExpectedSha256) {
        throw "Catalog SHA-256 validation failed for '$Path'."
    }

    $signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
    $trustedDellSigner = $signature.SignerCertificate -and $signature.SignerCertificate.Subject -match '(?i)(?:^|,\s*)O=Dell(?: Technologies)? Inc\.(?:,|$)'
    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or -not $trustedDellSigner) {
        throw "Authenticode signature validation failed for '$Path': $($signature.StatusMessage)"
    }
    return $true
}