/*  
GARY BLOK - @gwblok - GARYTOWN.COM
ComputerName
LastHWScan
Days Since HW Scan
Serial Number
Product
Model

Limit by Collection

*/  



SELECT DISTINCT SYS.Netbios_Name0 as 'Computer Name'
,WS.LastHWScan
,DATEDIFF(day,WS.LastHWScan,GETDATE()) as 'Days Since HWScan'
,SE.SerialNumber0 AS [Serial Number]
,bb.Product0
,cs.Model0 AS Model

FROM v_GS_WORKSTATION_STATUS WS 
LEFT JOIN v_R_System SYS ON WS.ResourceID = SYS.ResourceID
LEFT JOIN v_GS_COMPUTER_SYSTEM cs ON CS.ResourceID = SYS.ResourceID
LEFT JOIN dbo.v_GS_SYSTEM_ENCLOSURE SE ON SE.ResourceID = SYS.ResourceID
Join v_GS_BASEBOARD bb on bb.ResourceID = SYS.ResourceID
join dbo.v_FullCollectionMembership FCM on FCM.ResourceID = SYS.ResourceID

Where
FCM.CollectionId = 'MCM00035'
