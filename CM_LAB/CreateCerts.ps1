#Script to Create the 3 Certs Needed - Run on your DC (Certificate Authority)

#Only have the code for Client Cert so far, and still need to code the permissions... so this is still mostly manual


#Had issues with this cert, ended up creating a new one and deploying..


#ConfigMgr Client Auth Cert Creation
$ConfigContext = ([ADSI]"LDAP://RootDSE").ConfigurationNamingContext 
$ADSI = [ADSI]"LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext" 

$NewTempl = $ADSI.Create("pKICertificateTemplate", "CN=ConfigMgrClientCert") 
$NewTempl.put("distinguishedName","CN=ConfigMgrClientCert,CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext") 
# and put other atributes that you need 

$NewTempl.put("flags","131680")
$NewTempl.put("displayName","ConfigMgr Client Certificate")
$NewTempl.put("revision","100")
$NewTempl.put("pKIDefaultKeySpec","1")
$NewTempl.SetInfo()

$NewTempl.put("pKIMaxIssuingDepth","0")
$NewTempl.put("pKICriticalExtensions","2.5.29.15")
$NewTempl.put("pKIExtendedKeyUsage","1.3.6.1.4.1.311.47.1.1, 1.3.6.1.5.5.7.3.2")
$NewTempl.put("pKIDefaultCSPs","1,Microsoft RSA SChannel Cryptographic Provider")
$NewTempl.put("msPKI-RA-Signature","0")
$NewTempl.put("msPKI-Enrollment-Flag","32")
$NewTempl.put("msPKI-Private-Key-Flag","67371264")
$NewTempl.put("msPKI-Certificate-Name-Flag","134217728")
$NewTempl.put("msPKI-Minimal-Key-Size","2048")
$NewTempl.put("msPKI-Template-Schema-Version","2")
$NewTempl.put("msPKI-Template-Minor-Revision","0") 
$NewTempl.put("msPKI-Cert-Template-OID","1.3.6.1.4.1.311.21.8.7638725.13898300.1985460.3383425.7519116.119.16408497.1716 293")
$NewTempl.put("msPKI-Certificate-Application-Policy","1.3.6.1.4.1.311.47.1.1, 1.3.6.1.5.5.7.3.2")
$NewTempl.SetInfo()
$WATempl = $ADSI.psbase.children | where {$_.displayName -match "Workstation Authentication"}
$NewTempl.pKIKeyUsage = $WATempl.pKIKeyUsage
$NewTempl.pKIExpirationPeriod = $WATempl.pKIExpirationPeriod
$NewTempl.pKIOverlapPeriod = $WATempl.pKIOverlapPeriod
$NewTempl.SetInfo()
