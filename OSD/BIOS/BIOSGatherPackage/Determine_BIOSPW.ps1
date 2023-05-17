#Mike Terrill
$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
$cs = Get-WmiObject Win32_ComputerSystem
$PWMATCH = $False

$BIOSPW = $tsenv.Value('BIOSPW')
$BIOSPW1 = $tsenv.Value('BIOSPW1')
$BIOSPW2 = $tsenv.Value('BIOSPW2')
$BIOSPW3 = $tsenv.Value('BIOSPW3')
$passwords = @($BIOSPW1,$BIOSPW2,$BIOSPW3)

If ($cs.Manufacturer -eq 'HP' -or $cs.Manufacturer -eq 'Hewlett-Packard') {
    $BIOS= gwmi -class hp_biossettinginterface -Namespace "root\hp\instrumentedbios"
    foreach ($password in $passwords)
    {
      $Result = $BIOS.SetBIOSSetting("Setup Password","<utf-16/>" + $password,"<utf-16/>" + $password)
      if ($Result.Return -eq '0') {
          $PWMATCH = $True
          break
          }
      }
}
ElseIf ($cs.Manufacturer -eq 'Dell Inc.') {
    #Set path to the CCTK that was previously set from BIOS Gather
    $CCTK = $tsenv.Value('CCTK')
      Write-Output "CCTK location: $CCTK"
    foreach ($password in $passwords)
    {
      $Result = (Start-Process -FilePath $CCTK -ArgumentList "--SetupPwd=$password --ValSetupPwd=$password" -Wait -PassThru -WindowStyle Hidden).ExitCode

      # CCTK Return Codes:
      # 0  = Password is changed successfully/Password is cleared successfully
      # 41 = The old password must be provided to set a new password using --ValSetupPwd
      # 58 = The setup password provided is incorrect. Please try again
      # 60 = Password not changed, new password does not meet criteria
      
      if ($Result -eq '0') {
          $PWMATCH = $True
          break
          }
    }
}

If ($PWMATCH) {
    If ($cs.Manufacturer -eq 'HP' -or $cs.Manufacturer -eq 'Hewlett-Packard') {
        #HP requires a space and the TS Editor trims trailing spaces
        $BIOSPW = $BIOSPW + " " + $password
    }
    ElseIf ($cs.Manufacturer -eq 'Dell Inc.') {
        $BIOSPW = $BIOSPW + $password
    }
}

$tsenv.Value('BIOSPW') = $BIOSPW
$tsenv.Value('PWMATCH') = $PWMATCH
