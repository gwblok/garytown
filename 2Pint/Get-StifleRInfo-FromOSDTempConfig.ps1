function Get-StifleRURLsFromTempInstallConfig {

    # Define the path to the config file
    $configFilePath = "C:\Windows\Temp\StifleR\StifleR.ClientApp.exe.Config"

    # Check if the config file exists
    if (-Not (Test-Path -Path $configFilePath)) {
        Write-Debug "Config file not found at path: $configFilePath"
        return
    }

    # Load the XML content from the config file
    [xml]$configContent = Get-Content -Path $configFilePath

    # Extract the values for StiflerServers and StifleRulezURL
    $stiflerServers = $configContent.configuration.appSettings.add | Where-Object { $_.key -eq "StiflerServers" } | Select-Object -ExpandProperty value
    $stifleRulezURL = $configContent.configuration.appSettings.add | Where-Object { $_.key -eq "StifleRulezURL" } | Select-Object -ExpandProperty value

    # Output the values

    $Output = New-Object -TypeName PSObject
    $Output | Add-Member -MemberType NoteProperty -Name "StiflerServers" -Value "$stiflerServers" -Force
    $Output | Add-Member -MemberType NoteProperty -Name "StifleRulezURL" -Value "$stifleRulezURL"  -Force

    return $Output
}