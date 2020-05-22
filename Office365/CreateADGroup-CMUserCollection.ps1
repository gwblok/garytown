<#GARYTOWN - @gwblok 
Creates AD Groups based on the Names of CM Apps
Adds a security group to that for easy testing
Creates CM User Collections
Creates Avaialble Deployments of the associated apps.
Adds the new AD Group to that User Collection


Change Log initial release: 2020.05.21
2020.05.22 - Added available Deployment Creation and better detection if things exsit first, as well as logging

#>

#OU where the AD Groups are going to be Created
$ADGroupOU = "OU=Applications,OU=GARYTOWN,DC=corp,DC=viamonstra,DC=Com"

#Get Apps you want to create Matching AD Groups and CM User Collections for
$M365Apps = Get-CMApplication | Where-Object {$_.LocalizedDisplayName -match "Microsoft 365" -and $_.LocalizedDisplayName -notmatch "Content"}

#LImiting Collection for the User Collections you're creating
$LimitingCollection = Get-CMCollection -Name "All User Groups"

foreach ($App in $M365Apps)
    {
    #Grab Name of Apps
    $GroupName = $app.LocalizedDisplayName
    Write-Host "Starting to Process $GroupName" -ForegroundColor Green
    
    #Creating Active Directory Group
    $GetADGroup = $Null
    $GetADGroup = Get-ADGroup -Identity $GroupName
    if (!($GetADGroup))
        {
        Write-Host "  Creating AD Group $GroupName" -ForegroundColor Green
        $NewAdGroup = New-ADGroup -Name $GroupName -GroupCategory Security -GroupScope Global -DisplayName $GroupName -Path $ADGroupOU -Description "Created by Script and added DeployApps AD Group"
        Start-Sleep -Seconds 2
        Add-ADGroupMember -Identity $GroupName -Members 'SoftwareCenter-DeployApps'
        }
    else{Write-Host "  AD Group $GroupName already exist, skipping" -ForegroundColor Gray}
    $GetCMCollection = $Null
    $GetCMCollection = Get-CMCollection -Name "$($GroupName) - User"
    if (!($GetCMCollection))
        {
        Write-Host "  Creating CM User Collection $($GroupName) - User" -ForegroundColor Green
        $NewCollection = New-CMCollection -CollectionType User -Name "$($GroupName) - User" -LimitingCollectionId $LimitingCollection.CollectionID -RefreshType None
        }
    else {Write-Host "  CM User Collection $($GroupName) - User already exist, skipping" -ForegroundColor Gray}  
    $GetCMAppDeployment = $Null
    $GetCMAppDeployment = Get-CMDeployment -CollectionName "$($GroupName) - User" -SoftwareName $GroupName
    if (!($GetCMAppDeployment))
        {
        Write-Host "  Setting up Available Deployment for $($App.LocalizedDisplayName)" -ForegroundColor Cyan
        $NewCMAppDeployment = New-CMApplicationDeployment -Name $App.LocalizedDisplayName -DeployAction Install -DeployPurpose Available -CollectionName "$($GroupName) - User"
        }
    else{Write-Host "  $($App.LocalizedDisplayName), already deployed to this Collection, skipping" -ForegroundColor Gray}

    }
Write-Host "Completed creating AD Groups, Triggering AD Sync" -ForegroundColor Cyan
#Trigger AD Sync to pull in the new Groups from AD into CM
Invoke-CMGroupDiscovery
Start-Sleep -Seconds 120

#Add AD User Group (CM User Group Resource) Into the User Collection
foreach ($App in $M365Apps)
    {
    $GroupName = $app.LocalizedDisplayName
    Write-Host "Starting to Process User Collection $GroupName" -ForegroundColor Green
    $CMUserCollection = Get-CMCollection -Name "$($GroupName) - User"    
    $GetCMUserCollectionMemberShipRule = Get-CMUserCollectionDirectMembershipRule -CollectionId $CMUserCollection.CollectionID | Where-Object {$_.RuleName -match $GroupName}
    if (!($GetCMUserCollectionMemberShipRule))
        {
        $UserGroupResource = $null
        do {
            $UserGroupResource = Get-CMResource -ResourceType UserGroup -Fast | Where-Object {$_.UserGroupName -eq $GroupName}      
            if ($UserGroupResource -eq $Null)
                {
                Write-Host "AD Group Resource still not in CM, triggering Sync and waiting 1 minute before retry" -ForegroundColor Cyan
                Start-Sleep -Seconds 60
                }
            }
        while ($UserGroupResource -eq $null)
        Add-CMUserCollectionDirectMembershipRule -CollectionId $CMUserCollection.CollectionID -ResourceId $UserGroupResource.ResourceId
        }
    else {Write-Host "  CM User Collection $($GroupName) - User already has associated group, skipping" -ForegroundColor Gray} 
        
    }
