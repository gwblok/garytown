<#Gary Blok

Script creates Collections based on the Pre-Assesment CIs
 - Looks for CIs based on WaaS & Build Number
 - Creates Collections based on the NAME of those CIs
 - Creates Non-Compliant Query based on the SCOPE ID
    - The SCOPE ID Changes everytime you modify the CI, so you can re-run script if needed.

#>

$Build = "1909"
$AppsCIs = Get-CMConfigurationItem -Fast | Where-Object {$_.LocalizedCategoryInstanceNames -contains "WaaS" -and $_.LocalizedCategoryInstanceNames -contains $Build -and $_.CIType_ID -eq "5" -and $_.LocalizedDisplayName -notmatch "Hardware" } #Type 5 = App / Type 3 = OS
$CollectionNamePreFix = "IPU_W10_PreAssessment_NonCompliant_"
$LimitingCollection = Get-CMCollection -Name "01 - IPU  W10 Pre-Assessment Baseline"

foreach ($AppCI in $AppsCIs)
{
    Write-Host "---------------------------------------" -ForegroundColor DarkGray
    $DisplayName = $AppCI.LocalizedDisplayName
    $CI_UniqueID = $AppCI.CI_UniqueID
    Write-Host "Starting $DisplayName" -ForegroundColor Cyan
    $CollectionNameSuffix = $DisplayName.Replace(" Version Mismatch","")
    $CollectionName = "$CollectionNamePreFix$CollectionNameSuffix"
    $CollectionName = $CollectionName.Replace(" ","_")
    #Test Collection
    if ($CMCollection = Get-CMCollection -Name $CollectionName -ErrorAction SilentlyContinue)
        {
        Write-Host " Collection $CollectionName already exist" -ForegroundColor Green
        }
    Else
        {
        Write-Host " Creating Collection $CollectionName" -ForegroundColor Green
        $CMCollection = New-CMCollection -CollectionType Device -Name $CollectionName -Comment "PreAssessment Query Auto Generated" -LimitingCollectionId $LimitingCollection.CollectionID
        
        }
 $CollectionQueryNonCompliant = @"
select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_CI_ComplianceState on SMS_G_System_CI_ComplianceState.ResourceId = SMS_R_System.ResourceId where SMS_G_System_CI_ComplianceState.ComplianceState = 2 and SMS_G_System_CI_ComplianceState.CI_UniqueID = "$CI_UniqueID"
"@     
    if ($CMCollectionQuery = Get-CMCollectionQueryMembershipRule -CollectionName $CollectionName)
        {
        Write-Host " Removing Old Collection Query" -ForegroundColor Green
        Remove-CMCollectionQueryMembershipRule -CollectionName $CollectionName -RuleName $CMCollectionQuery.RuleName -Force
        }
    Write-Host " Adding Query based on $CI_UniqueID " -ForegroundColor Green
    Add-CMDeviceCollectionQueryMembershipRule -RuleName "Query $DisplayName" -CollectionName $CollectionName -QueryExpression $CollectionQueryNonCompliant | Out-Null

    }



