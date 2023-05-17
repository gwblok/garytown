/*  
GARY BLOK - @gwblok - GARYTOWN.COM

First off... I'm not a SQL Person, I can cobble stuff together that works in my lab, so I have no idea how this performs at scale.
There are probably better ways to do this...

This Query ASSUMES you are collecting HP BIOS Data:
  v_GS_HPBIOS_BIOSENUMERATION
  v_GS_HPBIOS_BIOSSTRING

https://garytown.com/hp-devices-inventory-bios-settings-in-configmgr

*/  


CREATE TABLE TempBIOSTable
(
    ResourceID NVARCHAR(255),
    Name0 NVARCHAR(255),
    Path0 NVARCHAR(255),
	CurrentValue0 NVARCHAR(255),
	PossibleValues0 NVARCHAR(255)
)
GO
INSERT INTO TempBIOSTable(ResourceID, Name0, Path0,CurrentValue0, PossibleValues0)
   SELECT ResourceID, Name0, Path0, Value0 as CurrentValue0, NULL as PossibleValues0 FROM v_GS_HPBIOS_BIOSSTRING
   UNION
   SELECT ResourceID, Name0, Path0, CurrentValue0, PossibleValues0 FROM v_GS_HPBIOS_BIOSENUMERATION; 

SELECT SYS.Netbios_Name0 as 'Computer Name'
,WS.LastHWScan
,DATEDIFF(day,WS.LastHWScan,GETDATE()) as 'Days Since HWScan'
,TT.Name0 as 'Setting Name'
,TT.Path0 as 'Path'
,TT.CurrentValue0 as 'Current'
,TT.PossibleValues0 as 'Possible'

FROM v_GS_WORKSTATION_STATUS WS 
INNER JOIN v_R_System SYS ON WS.ResourceID = SYS.ResourceID
INNER JOIN TempBIOSTable TT ON WS.ResourceID = TT.ResourceID
where SYS.Netbios_Name0 = 'HP-ED-800-G6'
and 
(
TT.Name0 = 'Secure Platform Management Current State'
or TT.Name0 = 'OS Recovery'
or TT.Name0 = 'Recover OS from Network'
or TT.Name0 = 'OS Recovery Agent URL'
or TT.Name0 = 'OS Recovery Agent Provisioning Version'
or TT.Name0 = 'OS Recovery Image URL'
or TT.Name0 = 'OS Recovery Image Provisioning Version'
or TT.Name0 = 'Intel Active Management Technology (AMT)'
or TT.Name0 = 'Physical Presence Interface'
or TT.Name0 = 'Fast Boot'
or TT.Name0 = 'LAN / WLAN Auto Switching'
or TT.Name0 = 'TPM Device'
or TT.Name0 = 'TPM State'
or TT.Name0 = 'TPM Activation Policy'
)

DROP TABLE TempBIOSTable
