<#
.SYNOPSIS
    Manage Intune device categories via Microsoft Graph API.

.DESCRIPTION
    This script connects to Microsoft Graph, retrieves available device categories,
    finds devices without assigned categories, and offers interactive assignment.
    
    Features:
    - Connect to Microsoft Graph with appropriate permissions
    - List all available device categories
    - Find devices without assigned categories
    - Interactive category assignment
    - Bulk category assignment support
    
.PARAMETER TenantId
    Optional Azure AD Tenant ID. If not provided, will use default/interactive login.

.PARAMETER ClientId
    Optional Application (client) ID for app-based authentication.

.PARAMETER CertificateThumbprint
    Optional certificate thumbprint for app-based authentication.

.PARAMETER UseDeviceCode
    Use device code flow for authentication (useful for headless environments).

.EXAMPLE
    .\Set-IntuneDeviceCategories.ps1
    # Interactive login, shows menu to manage categories

.EXAMPLE
    .\Set-IntuneDeviceCategories.ps1 -TenantId "contoso.onmicrosoft.com" -UseDeviceCode
    # Use device code flow for specific tenant

.NOTES
    Author: Created for garytown
    Date: October 30, 2025
    
    Requirements:
    - Microsoft.Graph.DeviceManagement module
    - Microsoft.Graph.Authentication module
    - Permissions required: DeviceManagementManagedDevices.ReadWrite.All
    
    Install modules:
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
    Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$false)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$false)]
    [string]$CertificateThumbprint,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseDeviceCode
)

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ===== Helper Functions =====

function Connect-MgGraphWithPermissions {
    <#
    .SYNOPSIS
        Connect to Microsoft Graph with required permissions.
    #>
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$CertificateThumbprint,
        [switch]$UseDeviceCode
    )
    
    $requiredScopes = @(
        'DeviceManagementManagedDevices.ReadWrite.All'
    )
    
    Write-Host "`n=== Connecting to Microsoft Graph ===" -ForegroundColor Cyan
    
    try {
        # Check if already connected with sufficient permissions
        $context = Get-MgContext
        if ($context) {
            $hasPermissions = $true
            foreach ($scope in $requiredScopes) {
                if ($context.Scopes -notcontains $scope) {
                    $hasPermissions = $false
                    break
                }
            }
            
            if ($hasPermissions) {
                Write-Host "Already connected to tenant: $($context.TenantId)" -ForegroundColor Green
                Write-Host "Account: $($context.Account)" -ForegroundColor Green
                return $true
            } else {
                Write-Host "Current connection lacks required permissions. Reconnecting..." -ForegroundColor Yellow
                Disconnect-MgGraph | Out-Null
            }
        }
        
        # Build connection parameters
        $connectParams = @{
            Scopes = $requiredScopes
            NoWelcome = $true
        }
        
        if ($TenantId) { $connectParams['TenantId'] = $TenantId }
        if ($ClientId) { $connectParams['ClientId'] = $ClientId }
        if ($CertificateThumbprint) { $connectParams['CertificateThumbprint'] = $CertificateThumbprint }
        if ($UseDeviceCode) { $connectParams['UseDeviceCode'] = $true }
        
        # Connect
        Connect-MgGraph @connectParams
        
        $context = Get-MgContext
        Write-Host "Successfully connected to tenant: $($context.TenantId)" -ForegroundColor Green
        Write-Host "Account: $($context.Account)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $_"
        return $false
    }
}

function Get-IntuneDeviceCategories {
    <#
    .SYNOPSIS
        Get all available device categories from Intune.
    #>
    try {
        Write-Host "`nRetrieving device categories..." -ForegroundColor Cyan
        $categories = Get-MgDeviceManagementDeviceCategory -All
        
        if ($categories) {
            Write-Host "Found $($categories.Count) device categories" -ForegroundColor Green
            return $categories
        } else {
            Write-Host "No device categories found" -ForegroundColor Yellow
            return @()
        }
    }
    catch {
        Write-Error "Failed to retrieve device categories: $_"
        return @()
    }
}

function Get-DevicesWithoutCategory {
    <#
    .SYNOPSIS
        Get all managed devices that don't have a category assigned.
    #>
    try {
        Write-Host "`nRetrieving devices without categories..." -ForegroundColor Cyan
        
        # Get all managed devices
        $allDevices = Get-MgDeviceManagementManagedDevice -All -Property Id,DeviceName,UserPrincipalName,OperatingSystem,Model,SerialNumber,DeviceCategoryDisplayName
        
        # Filter devices without categories
        $devicesWithoutCategory = $allDevices | Where-Object { 
            [string]::IsNullOrWhiteSpace($_.DeviceCategoryDisplayName) 
        }
        
        if ($devicesWithoutCategory) {
            Write-Host "Found $($devicesWithoutCategory.Count) devices without categories" -ForegroundColor Yellow
            return $devicesWithoutCategory
        } else {
            Write-Host "All devices have categories assigned" -ForegroundColor Green
            return @()
        }
    }
    catch {
        Write-Error "Failed to retrieve devices: $_"
        return @()
    }
}

function Get-DevicesByCategory {
    <#
    .SYNOPSIS
        Get all managed devices with a specific category assigned.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$CategoryName
    )
    
    try {
        Write-Host "`nRetrieving devices with category '$CategoryName'..." -ForegroundColor Cyan
        
        # Get all managed devices
        $allDevices = Get-MgDeviceManagementManagedDevice -All -Property Id,DeviceName,UserPrincipalName,OperatingSystem,Model,SerialNumber,DeviceCategoryDisplayName
        
        # Filter devices by category (case-insensitive)
        $devicesWithCategory = $allDevices | Where-Object { 
            $_.DeviceCategoryDisplayName -eq $CategoryName
        }
        
        if ($devicesWithCategory) {
            Write-Host "Found $($devicesWithCategory.Count) devices with category '$CategoryName'" -ForegroundColor Yellow
            return $devicesWithCategory
        } else {
            Write-Host "No devices found with category '$CategoryName'" -ForegroundColor Green
            return @()
        }
    }
    catch {
        Write-Error "Failed to retrieve devices: $_"
        return @()
    }
}

function Get-AllDevicesGroupedByCategory {
    <#
    .SYNOPSIS
        Get all devices grouped by their assigned category.
    #>
    try {
        Write-Host "`nRetrieving all devices and grouping by category..." -ForegroundColor Cyan
        
        $allDevices = Get-MgDeviceManagementManagedDevice -All -Property Id,DeviceName,UserPrincipalName,OperatingSystem,Model,DeviceCategoryDisplayName
        
        $grouped = $allDevices | Group-Object -Property DeviceCategoryDisplayName
        
        Write-Host "Found $($allDevices.Count) total devices" -ForegroundColor Green
        return $grouped
    }
    catch {
        Write-Error "Failed to retrieve devices: $_"
        return @()
    }
}

function Set-DeviceCategory {
    <#
    .SYNOPSIS
        Set category for a specific device.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DeviceId,
        
        [Parameter(Mandatory=$true)]
        [string]$CategoryId,
        
        [Parameter(Mandatory=$false)]
        [string]$DeviceName
    )
    
    try {
        $displayName = if ($DeviceName) { $DeviceName } else { $DeviceId }
        Write-Host "Setting category for device: $displayName" -ForegroundColor Cyan
        
        # Create category reference body
        $body = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/deviceManagement/deviceCategories/$CategoryId"
        } | ConvertTo-Json
        
        # Use Invoke-MgGraphRequest to set the category reference
        $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$DeviceId/deviceCategory/`$ref"
        Invoke-MgGraphRequest -Method PUT -Uri $uri -Body $body -ContentType "application/json"
        
        Write-Host "  ✓ Category set successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  ✗ Failed to set category: $_" -ForegroundColor Red
        return $false
    }
}

function Show-DeviceList {
    <#
    .SYNOPSIS
        Display a formatted list of devices.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$Devices,
        
        [Parameter(Mandatory=$false)]
        [switch]$NumberedList
    )
    
    if (-not $Devices -or $Devices.Count -eq 0) {
        Write-Host "No devices to display" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n" -NoNewline
    $index = 1
    foreach ($device in $Devices) {
        $prefix = if ($NumberedList) { "[$index] " } else { "  - " }
        $category = if ($device.DeviceCategoryDisplayName) { $device.DeviceCategoryDisplayName } else { "<None>" }
        
        Write-Host $prefix -NoNewline -ForegroundColor Cyan
        Write-Host "$($device.DeviceName)" -NoNewline -ForegroundColor White
        Write-Host " | " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($device.OperatingSystem)" -NoNewline -ForegroundColor Gray
        Write-Host " | User: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($device.UserPrincipalName)" -NoNewline -ForegroundColor Gray
        Write-Host " | Category: " -NoNewline -ForegroundColor DarkGray
        Write-Host $category -ForegroundColor $(if ($device.DeviceCategoryDisplayName) { 'Green' } else { 'Yellow' })
        
        $index++
    }
}

function Show-CategorySelectionMenu {
    <#
    .SYNOPSIS
        Show interactive menu to select a category.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$Categories
    )
    
    Write-Host "`n=== Select a Category ===" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Categories.Count; $i++) {
        Write-Host "[$($i + 1)] $($Categories[$i].DisplayName)" -ForegroundColor White
    }
    Write-Host "[0] Cancel" -ForegroundColor Yellow
    
    do {
        $selection = Read-Host "`nEnter selection"
        $selectionNum = 0
        $validInput = [int]::TryParse($selection, [ref]$selectionNum)
    } while (-not $validInput -or $selectionNum -lt 0 -or $selectionNum -gt $Categories.Count)
    
    if ($selectionNum -eq 0) {
        return $null
    }
    
    return $Categories[$selectionNum - 1]
}

function Show-MainMenu {
    <#
    .SYNOPSIS
        Show main interactive menu.
    #>
    Write-Host "`n=== Intune Device Category Management ===" -ForegroundColor Cyan
    Write-Host "[1] View all device categories" -ForegroundColor White
    Write-Host "[2] View devices without categories" -ForegroundColor White
    Write-Host "[3] View all devices grouped by category" -ForegroundColor White
    Write-Host "[4] Search and assign category to specific device" -ForegroundColor White
    Write-Host "[5] Reassign devices from 'Unknown' category to another category" -ForegroundColor White
    Write-Host "[0] Exit" -ForegroundColor Yellow
    
    do {
        $selection = Read-Host "`nEnter selection"
        $selectionNum = 0
        $validInput = [int]::TryParse($selection, [ref]$selectionNum)
    } while (-not $validInput -or $selectionNum -lt 0 -or $selectionNum -gt 5)
    
    return $selectionNum
}

# ===== Main Script Logic =====

function Invoke-MainScript {
    # Connect to Microsoft Graph
    $connected = Connect-MgGraphWithPermissions -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -UseDeviceCode:$UseDeviceCode
    
    if (-not $connected) {
        Write-Host "Failed to connect to Microsoft Graph. Exiting." -ForegroundColor Red
        return
    }
    
    # Main loop
    do {
        $selection = Show-MainMenu
        
        switch ($selection) {
            1 {
                # View all categories
                $categories = Get-IntuneDeviceCategories
                if ($categories) {
                    Write-Host "`n=== Available Categories ===" -ForegroundColor Cyan
                    foreach ($cat in $categories) {
                        Write-Host "  - $($cat.DisplayName)" -NoNewline -ForegroundColor White
                        Write-Host " (ID: $($cat.Id))" -ForegroundColor Gray
                        if ($cat.Description) {
                            Write-Host "    Description: $($cat.Description)" -ForegroundColor DarkGray
                        }
                    }
                }
            }
            
            2 {
                # View devices without categories
                $devicesWithoutCategory = Get-DevicesWithoutCategory
                if ($devicesWithoutCategory) {
                    Show-DeviceList -Devices $devicesWithoutCategory
                }
            }
            
            3 {
                # View all devices grouped by category
                $grouped = Get-AllDevicesGroupedByCategory
                if ($grouped) {
                    Write-Host "`n=== Devices by Category ===" -ForegroundColor Cyan
                    foreach ($group in $grouped | Sort-Object Name) {
                        $categoryName = if ($group.Name) { $group.Name } else { "<No Category>" }
                        Write-Host "`n[$($group.Count) devices] $categoryName" -ForegroundColor Yellow
                        Show-DeviceList -Devices $group.Group
                    }
                }
            }
            
            4 {
                # Search and assign category to specific device
                $categories = Get-IntuneDeviceCategories
                if (-not $categories -or $categories.Count -eq 0) {
                    Write-Host "No categories available. Please create categories in Intune first." -ForegroundColor Red
                    continue
                }
                
                $searchTerm = Read-Host "`nEnter device name to search"
                if ([string]::IsNullOrWhiteSpace($searchTerm)) {
                    Write-Host "Search cancelled" -ForegroundColor Yellow
                    continue
                }
                
                Write-Host "Searching for devices matching: $searchTerm" -ForegroundColor Cyan
                $allDevices = Get-MgDeviceManagementManagedDevice -All -Property Id,DeviceName,UserPrincipalName,OperatingSystem,Model,DeviceCategoryDisplayName
                $matchingDevices = $allDevices | Where-Object { $_.DeviceName -like "*$searchTerm*" }
                
                if (-not $matchingDevices -or $matchingDevices.Count -eq 0) {
                    Write-Host "No devices found matching: $searchTerm" -ForegroundColor Yellow
                    continue
                }
                
                Write-Host "`nFound $($matchingDevices.Count) matching device(s):" -ForegroundColor Green
                Show-DeviceList -Devices $matchingDevices -NumberedList
                
                $deviceSelection = Read-Host "`nSelect device number (or 0 to cancel)"
                $deviceNum = 0
                if (-not [int]::TryParse($deviceSelection, [ref]$deviceNum) -or $deviceNum -lt 0 -or $deviceNum -gt $matchingDevices.Count) {
                    Write-Host "Invalid selection" -ForegroundColor Yellow
                    continue
                }
                
                if ($deviceNum -eq 0) {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                    continue
                }
                
                $selectedDevice = $matchingDevices[$deviceNum - 1]
                
                # Select category
                $selectedCategory = Show-CategorySelectionMenu -Categories $categories
                if (-not $selectedCategory) {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                    continue
                }
                
                Write-Host "`nAssigning category '$($selectedCategory.DisplayName)' to device '$($selectedDevice.DeviceName)'" -ForegroundColor Cyan
                $result = Set-DeviceCategory -DeviceId $selectedDevice.Id -CategoryId $selectedCategory.Id -DeviceName $selectedDevice.DeviceName
                
                if ($result) {
                    Write-Host "Category assigned successfully!" -ForegroundColor Green
                }
            }
            
            6 {
                # Reassign devices from 'Unknown' category
                $categories = Get-IntuneDeviceCategories
                if (-not $categories -or $categories.Count -eq 0) {
                    Write-Host "No categories available. Please create categories in Intune first." -ForegroundColor Red
                    continue
                }
                
                # Get devices with Unknown category
                $unknownDevices = Get-DevicesByCategory -CategoryName "Unknown"
                if (-not $unknownDevices -or $unknownDevices.Count -eq 0) {
                    Write-Host "No devices found with 'Unknown' category." -ForegroundColor Green
                    continue
                }
                
                Write-Host "`nDevices with 'Unknown' category:" -ForegroundColor Yellow
                Show-DeviceList -Devices $unknownDevices
                
                # Select new category (exclude Unknown from options if it exists)
                Write-Host "`nSelect new category to assign:" -ForegroundColor Cyan
                $targetCategories = $categories | Where-Object { $_.DisplayName -ne "Unknown" }
                
                if (-not $targetCategories -or $targetCategories.Count -eq 0) {
                    Write-Host "No other categories available besides 'Unknown'." -ForegroundColor Red
                    continue
                }
                
                $selectedCategory = Show-CategorySelectionMenu -Categories $targetCategories
                if (-not $selectedCategory) {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                    continue
                }
                
                Write-Host "`nSelected category: $($selectedCategory.DisplayName)" -ForegroundColor Green
                $confirm = Read-Host "Reassign ALL $($unknownDevices.Count) devices from 'Unknown' to '$($selectedCategory.DisplayName)'? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host "`nReassigning category for devices..." -ForegroundColor Cyan
                    $successCount = 0
                    $failCount = 0
                    
                    foreach ($device in $unknownDevices) {
                        $result = Set-DeviceCategory -DeviceId $device.Id -CategoryId $selectedCategory.Id -DeviceName $device.DeviceName
                        if ($result) { $successCount++ } else { $failCount++ }
                    }
                    
                    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
                    Write-Host "Successfully reassigned: $successCount" -ForegroundColor Green
                    if ($failCount -gt 0) {
                        Write-Host "Failed: $failCount" -ForegroundColor Red
                    }
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            
            0 {
                Write-Host "`nDisconnecting from Microsoft Graph..." -ForegroundColor Cyan
                Disconnect-MgGraph | Out-Null
                Write-Host "Goodbye!" -ForegroundColor Green
            }
        }
        
        if ($selection -ne 0) {
            Read-Host "`nPress Enter to continue"
        }
        
    } while ($selection -ne 0)
}

# Run main script
Invoke-MainScript
