#This is the detection Method for the Content Application
#It looks for the Application Name, then checks to confirm it is in the CCM Cache, and that setup.exe is in the O365_Cache folder.

$O365ContentAssignmentName = "Office 365 ProPlus Content" #This is the App Deployment Type Name, not the actual app Name
$O365_CacheLocation = "$env:ProgramData\O365_Cache\setup.exe"
$CIModel = Get-CimInstance -Namespace root/ccm/CIModels -ClassName CCM_AppDeliveryTypeSynclet | Where-Object {$_.AppDeliveryTypeName -match $O365ContentAssignmentName}
$ContentID = $CIModel.InstallAction.Content.ContentId | Sort-Object -Unique
$Cache = Get-CimInstance -Namespace root/ccm/SoftMgmtAgent -ClassName CacheInfoEx | Where-Object {$_.ContentID -eq $ContentID}
$CacheComplete = $Cache.ContentComplete
if ($CacheComplete -eq "TRUE" -and (Test-Path -Path $O365_CacheLocation)){Write-Output "True"}
else{}
