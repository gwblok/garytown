/*SQL to Grab Applications in CM with attempts to grab information about how it was constructed

Gary Blok - @gwblok
Used Guide here to start from: https://eskonr.com/2015/05/sccm-configmgr-2012-how-to-extract-information-from-xml-file-stored-in-sql-db-for-application-properties/

The idea here is to get enough information about the app to determine if it is still needed and should be migrated, and if migrated enough info to rebuild.
NOTE... If you're migrating, I'd highly recommend reviewing the app and not just rebuilding it the same.  Take migrating as an opportunity to do things better.

*/

;WITH XMLNAMESPACES ( 
DEFAULT 'http://schemas.microsoft.com/SystemsCenterConfigurationManager/2009/06/14/Rules', 
'http://schemas.microsoft.com/SystemCenterConfigurationManager/2009/AppMgmtDigest' as p1,
'http://schemas.microsoft.com/SystemsCenterConfigurationManager/2009/07/10/DesiredConfiguration' AS dc
)

SELECT
A.[App Name],max(A.[DT Name])[DT Title],A.Type
,A.IsDeployed
,A.DateCreated
,A.DateLastModified
,A.CreatedBy
,A.LastModifiedBy
,A.ContentLocation 
,A.InstallCommandLine
,A.UninstallCommandLine
,A.ExecutionContext
,A.RequiresLogOn
,A.UserInteractionMode
,A.OnFastNetwork
,A.OnSlowNetwork
,A.DetectAction
,A.DetectionMethod
,A.MSICode
--,A.MSICode2
,A.RegKey
,A.RegKeyValueName
,A.Operator
,A.ConstantValue
,A.DetectionScript
from (
SELECT LPC.DisplayName [App Name]
,CI.IsDeployed as IsDeployed
,CI.DateCreated as DateCreated
,CI.DateLastModified as DateLastModified
,CI.CreatedBy as CreatedBy
,CI.LastModifiedBy as LastModifiedBy
,(LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Title)[1]', 'nvarchar(max)')) AS [DT Name]
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/@Technology)[1]', 'nvarchar(max)') AS [Type]
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:Contents/p1:Content/p1:Location)[1]', 'nvarchar(max)') AS [ContentLocation]
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:InstallAction/p1:Args/p1:Arg)[1]', 'nvarchar(max)') AS [InstallCommandLine]
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:UninstallAction/p1:Args/p1:Arg)[1]', 'nvarchar(max)') AS [UninstallCommandLine]
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:InstallAction/p1:Args/p1:Arg)[3]', 'nvarchar(max)') AS [ExecutionContext]
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:InstallAction/p1:Args/p1:Arg)[4]', 'nvarchar(max)') AS [RequiresLogOn]
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:InstallAction/p1:Args/p1:Arg)[8]', 'nvarchar(max)') AS [UserInteractionMode]
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:Contents/p1:Content/p1:OnFastNetwork)[1]', 'nvarchar(max)') AS [OnFastNetwork]
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:Contents/p1:Content/p1:OnSlowNetwork)[1]', 'nvarchar(max)') AS [OnSlowNetwork]
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:DetectAction/p1:Provider)[1]', 'nvarchar(max)') AS DetectAction
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:CustomData/p1:DetectionMethod)[1]', 'nvarchar(max)') AS DetectionMethod
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:CustomData/p1:EnhancedDetectionMethod/p1:Settings/dc:MSI/dc:ProductCode)[1]', 'nvarchar(max)') AS MSICode
--,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:CustomData/p1:ProductCode)[1]', 'nvarchar(max)') AS MSICode2
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:CustomData/p1:EnhancedDetectionMethod/p1:Settings/dc:SimpleSetting/dc:RegistryDiscoverySource/dc:Key)[1]', 'nvarchar(max)') AS RegKey
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:CustomData/p1:EnhancedDetectionMethod/p1:Settings/dc:SimpleSetting/dc:RegistryDiscoverySource/dc:ValueName)[1]', 'nvarchar(max)') AS RegKeyValueName
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:CustomData/p1:EnhancedDetectionMethod/Rule/Expression/Operator)[1]', 'nvarchar(max)') AS Operator
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:CustomData/p1:EnhancedDetectionMethod/Rule/Expression/Operands/ConstantValue/@Value)[1]', 'nvarchar(max)') AS ConstantValue
,LDT.SDMPackageDigest.value('(/p1:AppMgmtDigest/p1:DeploymentType/p1:Installer/p1:CustomData/p1:DetectionScript)[1]', 'nvarchar(max)') AS DetectionScript

FROM
dbo.fn_ListApplicationCIs(1033) LPC
RIGHT Join fn_ListDeploymentTypeCIs(1033) LDT ON LDT.AppModelName = LPC.ModelName
Join v_ConfigurationItems CI on CI.ModelName = LPC.ModelName
where LDT.CIType_ID = 21 AND LDT.IsLatest = 1
) A
GROUP BY A.[App Name],A.Type,A.ContentLocation
,A.IsDeployed
,A.DateCreated
,A.DateLastModified
,A.CreatedBy
,A.LastModifiedBy
,A.InstallCommandLine
,A.UninstallCommandLine
,A.ExecutionContext
,A.RequiresLogOn
,A.UserInteractionMode,
A.OnFastNetwork
,A.OnSlowNetwork
,A.DetectAction
,A.DetectionMethod
,A.MSICode
--,A.MSICode2
,A.RegKey
,A.RegKeyValueName
,A.Operator
,A.ConstantValue
,A.DetectionScript
