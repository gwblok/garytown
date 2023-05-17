/*  
GARY BLOK - @gwblok - GARYTOWN.COM

First off... I'm not a SQL Person, I can cobble stuff together that works in my lab, so I have no idea how this performs at scale.
There are probably better ways to do this...

This Query ASSUMES you are collecting HP BIOS Data:
  v_GS_HPBIOS_BIOSENUMERATION
  v_GS_HPBIOS_BIOSSTRING

https://garytown.com/hp-devices-inventory-bios-settings-in-configmgr

*/  
SELECT SYS.Netbios_Name0 as 'Computer Name'
,WS.LastHWScan
,DATEDIFF(day,WS.LastHWScan,GETDATE()) as 'Days Since HWScan'
,HPBS.Name0
,HPBS.Value0
FROM v_GS_WORKSTATION_STATUS WS 
INNER JOIN v_R_System SYS ON WS.ResourceID = SYS.ResourceID
INNER JOIN v_GS_HPBIOS_BIOSSTRING HPBS on HPBS.ResourceID = SYS.ResourceID

where HPBS.Name0 like 'Preboot Wi-Fi Profile %'
and HPBS.Name0 <> 'Preboot Wi-Fi Profile Set Status'
and HPBS.Value0 <> '{"SSID":null,"Type":null}'
