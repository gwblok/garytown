#Mike Terrill
$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
$TSCACHE = "_SMSTSPackageCacheLocation" + $tsenv.Value('BIOSPACKAGE')
$CCMCACHE = "_SMSTS" + $tsenv.Value('BIOSPACKAGE')
if ($tsenv.Value($TSCACHE)) {$tsenv.Value('BIOS01') = $tsenv.Value($TSCACHE)}
if ($tsenv.Value($CCMCACHE)) {$tsenv.Value('BIOS01') = $tsenv.Value($CCMCACHE)}
write-output "BIOS01:$($tsenv.Value('BIOS01'))"
