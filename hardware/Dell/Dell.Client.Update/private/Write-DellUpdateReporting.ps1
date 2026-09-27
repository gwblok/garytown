function Save-DellBiosUpdateInfoToRegistry {
    param(
        [Parameter(Mandatory)][psobject]$Package,
        [Parameter(Mandatory)][psobject]$Result,
        [string]$RegistryPath = 'HKLM:\SOFTWARE\Dell\ClientUpdate\BIOSUpdate'
    )

    $null = New-Item -Path $RegistryPath -ItemType Directory -Force
    $values = [ordered]@{
        InstallDate = (Get-Date).ToUniversalTime().ToString('o')
        ActionNeeded = [string]$Result.PendingAction
        PackageID = [string]$Package.PackageID
        ReleaseID = [string]$Package.ReleaseID
        PackageHash = [string]$Package.Sha256
        Title = [string]$Package.Title
        Version = [string]$Package.Version
        DellVersion = [string]$Package.DellVersion
        Status = if ($Result.Success) { 'Success' } else { 'Failed' }
        ExitCode = if ($null -eq $Result.ExitCode) { '' } else { [string]$Result.ExitCode }
        Message = [string]$Result.FailureReason
    }
    foreach ($entry in $values.GetEnumerator()) {
        $null = New-ItemProperty -Path $RegistryPath -Name $entry.Key -Value $entry.Value -PropertyType String -Force
    }
}

function Get-DellUpdateWmiClass {
    param(
        [string]$Namespace = 'root\DellClientUpdate',
        [string]$ClassName = 'Dell_UpdateHistory'
    )

    if ($Namespace -notmatch '^root\\(?<name>[A-Za-z_][A-Za-z0-9_]*)$') {
        throw "WMI namespace '$Namespace' must be a direct child of root."
    }

    $namespaceName = $Matches.name
    $rootClass = New-Object System.Management.ManagementClass
    $rootClass.Scope = New-Object System.Management.ManagementScope('\\.\root')
    $rootClass.Path = New-Object System.Management.ManagementPath('__namespace')
    $namespaceExists = [bool]($rootClass.GetInstances() | Where-Object { $_['Name'] -eq $namespaceName } | Select-Object -First 1)
    if (-not $namespaceExists) {
        $namespaceInstance = $rootClass.CreateInstance()
        $namespaceInstance['Name'] = $namespaceName
        $null = $namespaceInstance.Put()
    }

    $scope = New-Object System.Management.ManagementScope("\\.\$Namespace")
    $scope.Connect()
    try {
        $class = New-Object System.Management.ManagementClass($scope, (New-Object System.Management.ManagementPath($ClassName)), $null)
        $null = $class.Get()
        return $class
    }
    catch [System.Management.ManagementException] {
        if ($_.Exception.ErrorCode -ne [System.Management.ManagementStatus]::NotFound) { throw }
    }

    $class = New-Object System.Management.ManagementClass
    $class.Scope = $scope
    $class.Path = New-Object System.Management.ManagementPath
    $class['__CLASS'] = $ClassName
    $class.Properties.Add('RecordId', [System.Management.CimType]::String, $false)
    $class.Properties['RecordId'].Qualifiers.Add('Key', $true)
    foreach ($propertyName in @('UpdateID', 'PackageID', 'ReleaseID', 'Title', 'Version', 'DellVersion', 'Status', 'Severity', 'Category', 'Type', 'InstallDate', 'Message', 'ComputerName', 'UserName', 'PackageHash', 'PendingAction')) {
        $class.Properties.Add($propertyName, [System.Management.CimType]::String, $false)
    }
    $class.Properties.Add('Size', [System.Management.CimType]::UInt64, $false)
    $class.Properties.Add('Success', [System.Management.CimType]::Boolean, $false)
    $class.Properties.Add('RebootRequired', [System.Management.CimType]::Boolean, $false)
    $class.Properties.Add('ExitCode', [System.Management.CimType]::SInt32, $false)
    $null = $class.Put()
    return $class
}

function Export-DellUpdateResultToWmi {
    param(
        [Parameter(Mandatory)][psobject]$Package,
        [Parameter(Mandatory)][psobject]$Result,
        [string]$Namespace = 'root\DellClientUpdate',
        [string]$ClassName = 'Dell_UpdateHistory'
    )

    $class = Get-DellUpdateWmiClass -Namespace $Namespace -ClassName $ClassName
    $instance = $class.CreateInstance()
    $instance['RecordId'] = [guid]::NewGuid().ToString()
    $instance['UpdateID'] = [string]$Package.ID
    $instance['PackageID'] = [string]$Package.PackageID
    $instance['ReleaseID'] = [string]$Package.ReleaseID
    $instance['Title'] = [string]$Package.Title
    $instance['Version'] = [string]$Package.Version
    $instance['DellVersion'] = [string]$Package.DellVersion
    $instance['Status'] = if ($Result.Success) { 'Installed' } else { 'Failed' }
    $instance['Severity'] = [string]$Package.Severity
    $instance['Category'] = [string]$Package.Category
    $instance['Type'] = [string]$Package.Type
    $instance['Size'] = [uint64]$Package.FileSize
    $instance['InstallDate'] = (Get-Date).ToUniversalTime().ToString('o')
    $instance['Message'] = [string]$Result.FailureReason
    $instance['ComputerName'] = [Environment]::MachineName
    $instance['UserName'] = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $instance['PackageHash'] = [string]$Package.Sha256
    $instance['PendingAction'] = [string]$Result.PendingAction
    $instance['Success'] = [bool]$Result.Success
    $instance['RebootRequired'] = [bool]$Result.RebootRequired
    if ($null -ne $Result.ExitCode) { $instance['ExitCode'] = [int]$Result.ExitCode }
    $null = $instance.Put()
}

function New-DellUpdateHistoryRecord {
    param(
        [Parameter(Mandatory)][psobject]$Package,
        [Parameter(Mandatory)][psobject]$Result
    )

    [pscustomobject]@{
        Timestamp = (Get-Date).ToUniversalTime().ToString('o')
        Status = if ($Result.Success) { 'Success' } else { 'Failed' }
        Title = [string]$Package.Title
        Version = [string]$Package.Version
        DellVersion = [string]$Package.DellVersion
        Category = [string]$Package.Category
        Type = [string]$Package.Type
        Severity = [string]$Package.Severity
        ExitCode = $Result.ExitCode
        RebootRequired = [bool]$Result.RebootRequired
        PendingAction = [string]$Result.PendingAction
        ComputerName = [Environment]::MachineName
        UserName = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        Message = [string]$Result.FailureReason
        UpdateID = [string]$Package.ID
        PackageID = [string]$Package.PackageID
        ReleaseID = [string]$Package.ReleaseID
        PackageHash = [string]$Package.Sha256
        RuntimeSeconds = [math]::Round(([timespan]$Result.Runtime).TotalSeconds, 3)
    }
}

function Write-DellUpdateHistorySession {
    param(
        [Parameter(Mandatory)][object[]]$Records,
        [string]$HistoryPath = (Get-DellPSUpdatePath -Name History)
    )

    if (-not $Records.Count) { return $null }
    $null = New-Item -Path $HistoryPath -ItemType Directory -Force
    $historyFile = Join-Path $HistoryPath "InstallHist-$(Get-Date -Format 'yyyyMMdd_HHmmss_fff')-$([guid]::NewGuid().ToString('N')).json"
    @($Records) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $historyFile -Encoding UTF8
    return $historyFile
}