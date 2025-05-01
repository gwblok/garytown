if (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
    $Applicable = $true
}
else {
    #Write-Output "Secure Boot is not enabled."
    #exit 5
    $Applicable = $false
}
return $Applicable