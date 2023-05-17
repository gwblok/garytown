/*  
GARY BLOK - @gwblok - GARYTOWN.COM

First off... I'm not a SQL Person, I can cobble stuff together that works in my lab, so I have no idea how this performs at scale.
There are probably better ways to do this...

This Query ASSUMES you are collecting HP BIOS Data:
  v_GS_HPBIOS_BIOSENUMERATION
  v_GS_HPBIOS_BIOSSTRING

https://garytown.com/hp-devices-inventory-bios-settings-in-configmgr

*/  



SELECT DISTINCT SYS.Netbios_Name0 as 'Computer Name'
,WS.LastHWScan
,DATEDIFF(day,WS.LastHWScan,GETDATE()) as 'Days Since HWScan'
,HPBE.ResourceID
,HPBE.Name0
,HPBE.CurrentValue0

FROM v_GS_WORKSTATION_STATUS WS 
INNER JOIN v_R_System SYS ON WS.ResourceID = SYS.ResourceID
INNER JOIN v_GS_HPBIOS_BIOSENUMERATION HPBE ON HPBE.ResourceID = SYS.ResourceID

where HPBE.Name0 = 'Intel Active Management Technology (AMT)'
and HPBE.CurrentValue0 = 'Enable'
