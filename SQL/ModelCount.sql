SELECT
cs.Model0 AS Model,
COUNT(*) AS Count
,bb.Product0
FROM
v_GS_COMPUTER_SYSTEM cs
 join v_GS_BASEBOARD bb on bb.ResourceID = cs.ResourceID
where cs.Model0 not like 'Virt%'
and cs.Model0 not like 'HVM%'

GROUP BY cs.Model0,bb.Product0

--HAVING COUNT(*) > 50

order by Count(*) DESC;
