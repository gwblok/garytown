<#
V2020.12.04 by @gwblok


#>

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" 
}

#Get SiteCode
$SiteCode = Get-PSDrive -PSProvider CMSITE
$ProviderMachineName = (Get-PSDrive -PSProvider CMSITE).Root
Set-location $SiteCode":"

#Start Custom Script Vars
$LimitingCollection = "All Workstations"  #Creates this later if does not exist

#Create Collection Folder
If ((-not (Test-Path -Path ($SiteCode.Name +":\DeviceCollection\$CollectionFolderName"))) -and ($CreateCollectionFolder))
    {
    Write-host "Device collection folder name $CollectionFolderName was not found. Creating folder..." -ForegroundColor Green
    New-Item -Name $CollectionFolderName -Path ($SiteCode.Name +":\DeviceCollection")
    $FolderPath = ($SiteCode.Name +":\DeviceCollection\$CollectionFolderName")
    Write-host "Device collection folder $CollectionFolderName created." -ForegroundColor Green
    }
elseif ((Test-Path -Path ($SiteCode.Name +":\DeviceCollection\$CollectionFolderName")) -and ($CreateCollectionFolder))
    {
    Write-host "Device collection folder name $CollectionFolderName already exists...will move newly created collections to this folder." -ForegroundColor Yellow
    $FolderPath = ($SiteCode.Name +":\DeviceCollection\$CollectionFolderName")
    }

#Set Schedule to Evaluate Weekly (from the time you run the script)
$Schedule = New-CMSchedule -Start (Get-Date).DateTime -RecurInterval Days -RecurCount 7

#Confirm All Workstation Collection, or create it if needed
$AllWorkstationCollection = Get-CMCollection -Name $LimitingCollection
if ($AllWorkstationCollection -eq $Null)
    {
$CollectionQueryAllWorkstations = @"
select SMS_R_System.Name from  SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT Workstation%"
"@     
    
    New-CMDeviceCollection -Name $LimitingCollection -Comment "Collection of all workstation machines" -LimitingCollectionName "All Systems" -RefreshSchedule $Schedule -RefreshType 2 |Out-Null
    Add-CMDeviceCollectionQueryMembershipRule -RuleName "All Workstations" -CollectionName $LimitingCollection -QueryExpression $CollectionQueryAllWorkstations | Out-Null
    $AllWorkstationCollection = Get-CMCollection -Name $LimitingCollection
    Write-Host "Created All Workstations Collection ID: $($AllWorkstationCollection.CollectionID), which will be used as the limiting collections moving forward" -ForegroundColor Green
    }
else {Write-Host "Found All Workstations Collection ID: $($AllWorkstationCollection.CollectionID), which will be used as the limiting collections moving forward" -ForegroundColor Green}


$Manufs = @("HP","Dell","Lenovo","Microsoft")


foreach ($Manuf in $Manufs)
    {
    #Set Manufacturer for use in Query
    $ColManufacturer = $Manuf
    if ($ColManufacturer -like "H*"){$ColManufacturer = "H"}
    if ($ColManufacturer -like "Dell*"){$ColManufacturer = "Dell"}
    if ($ColManufacturer -like "Mic*"){$ColManufacturer = "Microsoft"}
    if ($ColManufacturer -like "VMw*"){$ColManufacturer = "VMware"}
    else {$ColManufacturer = $Manuf.Substring(0,$Manuf.Length-1)}

$CollectionQueryManufacturer = @"
select SMS_R_SYSTEM.Name from SMS_R_System inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.Manufacturer like "$($ColManufacturer)%"
"@ 
        
    #Set Manufacturer for use in Collection Name
    $ColManufacturer = $Manuf
    if ($ColManufacturer -like "H*"){$ColManufacturer = "HP"}
    if ($ColManufacturer -like "Dell*"){$ColManufacturer = "Dell"}
    if ($ColManufacturer -like "LEN*"){$ColManufacturer = "Lenovo"}
    if ($ColManufacturer -like "Mic*"){$ColManufacturer = "Microsoft"}
    if ($ColManufacturer -like "VMw*"){$ColManufacturer = "VMware"}

    #Start Creation of ManufacturerCollection
    $CollectionName = "$ManufacturerColPreFix$ColManufacturer Systems"
    $CurrentCollectionID = (Get-CMCollection -Name $CollectionName).CollectionID
    if ($CurrentCollectionID -eq $null)
        {
        Write-Host "Creating Collection: $CollectionName" -ForegroundColor Green
        New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName $LimitingCollection -RefreshSchedule $Schedule -RefreshType Periodic | Out-Null
        Add-CMDeviceCollectionQueryMembershipRule -RuleName "Query $ColManufacturer" -CollectionName "$CollectionName" -QueryExpression $CollectionQueryManufacturer | Out-Null
        Write-Host "New Collection Created with Name: $CollectionName & ID: $((Get-CMCollection -Name $CollectionName).CollectionID)" -ForegroundColor Green
        If ($CreateCollectionFolder) 
            {
            Move-CMObject -FolderPath $FolderPath -InputObject $(Get-CMDeviceCollection -Name $CollectionName)
            Write-host *** Collection $CollectionName moved to $CollectionFolder.Name folder***
            }
        }
    Else{Write-Host "Collection: $CollectionName already exsit with ID: $CurrentCollectionID" -ForegroundColor Yellow}
    Write-Host "-----" -ForegroundColor DarkGray
    }
