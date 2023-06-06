<#  Gary Blok | @Gwblok | GARYTOWN.COM

Discovery Script for ConfigMgr CI

Checks for:
 - HP MIK Version
 - HPIA Version

 - Test for HPCMSL - Installs specialized version based on HP Connect if HPCMSL is not already loaded on device.
   - This happens even in Discovery Script, as the Discovery relies on HPCMSL
   - Installs to: C:\Program Files\HPConnect\hp-cmsl-wl



Make sure to keep the $MIKSoftpaqID information current
https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HPMIK.html
#>



#MIK Variables, make sure you update the Softpaq ID to the latest if it updates.
$MIKPath = 'C:\Program Files (x86)\HP\HP MIK Client'
$MIKSoftpaqID = "sp143059" #5.1.1.37 - 10/21/2022
$Compliance = "Compliant"


#region Functions
Function Get-HPIALatestVersion{
    $script:TempWorkFolder = "$env:windir\Temp\HPIA"
    $ProgressPreference = 'SilentlyContinue' # to speed up web requests
    $HPIACABUrl = "https://hpia.hpcloud.hp.com/HPIAMsg.cab"
    $HPIACABUrlFallback = "https://ftp.hp.com/pub/caps-softpaq/cmit/imagepal/HPIAMsg.cab"
    try {
        [void][System.IO.Directory]::CreateDirectory($TempWorkFolder)
    }
    catch {throw}
    $OutFile = "$TempWorkFolder\HPIAMsg.cab"
    
    try {Invoke-WebRequest -Uri $HPIACABUrl -UseBasicParsing -OutFile $OutFile}
    catch {}
    if (!(test-path $OutFile)){
        try {Invoke-WebRequest -Uri $HPIACABUrlFallback -UseBasicParsing -OutFile $OutFile}
        catch {}
    }
    if (test-path $OutFile){
        if(test-path "$env:windir\System32\expand.exe"){
            try { cmd.exe /c "C:\Windows\System32\expand.exe -F:* $OutFile $TempWorkFolder\HPIAMsg.xml" | Out-Null}
            catch {}
        }
        if (Test-Path -Path "$TempWorkFolder\HPIAMsg.xml"){
            [XML]$HPIAXML = Get-Content -Path "$TempWorkFolder\HPIAMsg.xml"
            $HPIADownloadURL = $HPIAXML.ImagePal.HPIALatest.SoftpaqURL
            $HPIAVersion = $HPIAXML.ImagePal.HPIALatest.Version
            $HPIAFileName = $HPIADownloadURL.Split('/')[-1]
        }
    }

    else { #Falling back to Static Web Page Scrapping if Cab File wasn't available... highly unlikely
        $HPIAWebUrl = "https://ftp.hp.com/pub/caps-softpaq/cmit/HPIA.html" # Static web page of the HP Image Assistant
        try {$HTML = Invoke-WebRequest –Uri $HPIAWebUrl –ErrorAction Stop }
        catch {Write-Output "Failed to download the HPIA web page. $($_.Exception.Message)" ;throw}
        $HPIASoftPaqNumber = ($HTML.Links | Where {$_.href -match "hp-hpia-"}).outerText
        $HPIADownloadURL = ($HTML.Links | Where {$_.href -match "hp-hpia-"}).href
        $HPIAFileName = $HPIADownloadURL.Split('/')[-1]
        $HPIAVersion = ($HPIAFileName.Split("-") | Select-Object -Last 1).replace(".exe","")
    }
    $Return = @(
    @{HPIAVersion = "$($HPIAVersion)"; HPIADownloadURL = $HPIADownloadURL ; HPIAFileName = $HPIAFileName}
    )
    return $Return
} 
Function Test-HPCMSL {
    #HPConnect Code
    $needReboot = $false # This value may be modified in the authentication policy
    $enableSureAdmin = $false # This value may be modified in the authentication policy
    $logFolder = "$($Env:LocalAppData)\HPConnect\Logs"
    $logFile = "6ff3ffbc-1fd7-4410-95aa-fd59efeed7d7"
    $logPathDir = [System.IO.Path]::GetDirectoryName($logFolder)

    try
    {
      if ((Test-Path $logPathDir) -eq $false) {
        New-Item -ItemType Directory -Force -Path $logPathDir | Out-Null
      }
      if ((Test-Path -Path $logFolder) -eq $false) {
        New-Item -ItemType directory -Force -Path $logFolder | Out-Null
      }
      $date = Get-Date
      $logFile = $logFolder + "\" +  $logFile
      echo "====================== Remediation Script ======================" | Out-File $logFile -Append
      echo $date | Out-File $logFile -Append
      echo ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) | Out-File $logFile -Append
      echo $PSVersionTable | Out-File $logFile -Append

      # Pre-requisites, i.e: HP-CMSL instalation
      function Get-LastestCMSLFromCatalog {
        Param([string]$catalog)

        $json = $catalog | ConvertFrom-Json
        $filter = $json."hp-cmsl" | Where-Object { $_.isLatest -eq $true }
        $sort = @($filter | Sort-Object -Property version -Descending)
        $sort[0]
    }

    # URI to get last HP-CMSL version approved for HP Connect
    $preReqUri = 'https://hpia.hpcloud.hp.com/downloads/cmsl/wl/hp-mem-client-prereq.json'
    $localDir = "$($Env:LocalAppData)\HPConnect\Tools"
    $sharedTools = "$($Env:ProgramFiles)\HPConnect"
    $maxTries = 3
    $triesInterval = 10

    # Download CMSL to the new location
    $updateSharedToolsLocation = $false
    if ([System.IO.Directory]::Exists("$localDir\hp-cmsl-wl")) {
        if (-not [System.IO.Directory]::Exists("$sharedTools\hp-cmsl-wl")) {
            Out-File $logFile -Append -InputObject "Moving HP-CMSL tool to Program Files"
            $updateSharedToolsLocation = $true
        }
    }

    # Read local metadata
    $localCatalog = "$localDir\hp-mem-client-prereq.json"
    $isLocalLocked = $false
    if ([System.IO.File]::Exists($localCatalog) -and [System.IO.Directory]::Exists("$sharedTools\hp-cmsl-wl")) {
        $local = Get-LastestCMSLFromCatalog(Get-Content -Path $localCatalog)
        $isLocalLocked = $local.isLocalLocked -eq $true
        Out-File $logFile -Append -InputObject "Current version of HP-CMSL-WL is $($local.version)"
    }
    else {
        $new = $true
        New-Item -ItemType Directory -Force -Path $localDir | Out-Null
        New-Item -ItemType Directory -Force -Path $sharedTools | Out-Null
    }

    if (-not $isLocalLocked) {
        $continueWithCurrent = $false
        # Download remote metadata
        $userAgent = "hpconnect-script"
        # Removing obsolete protocols SSL 3.0, TLS 1.0 and TLS 1.1
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]([System.Net.SecurityProtocolType].GetEnumNames() | Where-Object { $_ -ne "Ssl3" -and $_ -ne "Tls" -and $_ -ne "Tls11" })
        $tries = 0
        while ($tries -lt $maxTries) {
            try {
                $data = Invoke-WebRequest -Uri $preReqUri -UserAgent $userAgent -UseBasicParsing -ErrorAction Stop -Verbose 4>> $logFile
                break
            }
            catch {
                Out-File $logFile -Append -InputObject "Failed to retrieve HP-CMSL-WL catalog ($($tries+1)/$maxTries) : $($_.Exception.Message)"
                if ($tries -lt $maxTries-1) {
                    if ($tries -lt $maxTries-1) {
                        # Wait some interval between tries
                        Start-Sleep -Seconds $triesInterval
                    }
                }
                else {
                    if ($new -and -not $updateSharedToolsLocation) {
                        throw "Unable to retrieve HP-CMSL-WL catalog"
                    }
                    else {
                        Out-File $logFile -Append -InputObject "Unable to retrieve HP-CMSL-WL catalog. The script will continue with the local version"
                        $continueWithCurrent = $true
                    }
                }
            }
            $tries = $tries + 1
        }

        if (-not $continueWithCurrent) {
            $catalog = [System.IO.StreamReader]::new($data.RawContentStream).ReadToEnd()
            $remote = Get-LastestCMSLFromCatalog($catalog)
        
            if ($new -or $remote.version -gt $local.version) {
                # Download and unpack new version
                $tmpDir = "$env:windir\TEMP"
                $tmpFile = "$tmpDir\h.exe"
                Remove-Item -Path $tmpFile -Force -ErrorAction Ignore
                $tries = 0
                Out-File $logFile -Append -InputObject "Download HP-CMSL-WL $($remote.version) from $($remote.url)"
                while ($tries -lt $maxTries) {
                    try {
                        Invoke-WebRequest -Uri $remote.url -UserAgent $userAgent -UseBasicParsing -ErrorAction Stop -OutFile $tmpFile -Verbose 4>> $logFile
                        break
                    }
                    catch {
                        Out-File $logFile -Append -InputObject "Failed to retrieve HP-CMSL-WL installer ($($tries+1)/$maxTries) : $($_.Exception.Message)"
                        if ($tries -lt $maxTries-1) {
                            if ($tries -lt $maxTries-1) {
                                # Wait some interval between tries
                                Start-Sleep -Seconds $triesInterval
                            }
                        }
                        else {
                            if ($new -and -not $updateSharedToolsLocation) {
                                throw "Unable to download the HP-CMSL-WL installer"
                            }
                            else {
                                Out-File $logFile -Append -InputObject "Unable to download the HP-CMSL-WL installer. The script will continue with the local version"
                                $continueWithCurrent = $true
                            }
                        }
                    }
                    $tries = $tries + 1
                }

                if (-not $continueWithCurrent) {
                    if (-not $new -and -not $updateSharedToolsLocation) {
                        Out-File $logFile -Append -InputObject "Remove current HP-CMSL-WL $($local.version) from $sharedTools\hp-cmsl-wl"
                        Remove-Item -Force -Path "$sharedTools\hp-cmsl-wl" -Recurse
                    }
        
                    if ($updateSharedToolsLocation) {
                        Out-File $logFile -Append -InputObject "Remove HP-CMSL from previous location $localDir\hp-cmsl-wl"
                        Remove-Item -Force -Path "$localDir\hp-cmsl-wl" -Recurse
                    }
        
                    Out-File $logFile -Append -InputObject "Unpack CMSL from $tmpFile to $sharedTools\hp-cmsl-wl"
                    # Wait for the CMSL extraction to complete
                    $arguments = '/LOG="', $tmpDir, '\hp-cmsl-wl.log" /VERYSILENT /SILENT /SP- /NORESTART /UnpackOnly="True" /DestDir="', $sharedTools, '\hp-cmsl-wl"' -Join ''
                    Start-Process -Wait -LoadUserProfile -FilePath $tmpFile -ArgumentList $arguments
                    Move-Item -Path "$tmpDir\hp-cmsl-wl.log" -Destination "$logFolder\hp-cmsl-wl" -Force -ErrorAction Stop
        
                    # Update local metadata
                    $catalog | Set-Content -Path $localCatalog -Force
        
                    # Delete installer
                    Remove-Item -Path $tmpFile -Force -ErrorAction Ignore
                }
            }
        }

        if ($continueWithCurrent) {
            if ($updateSharedToolsLocation) {
                $sharedTools = $localDir
            }
        }
    }
    else {
        Out-File $logFile -Append -InputObject "Using a local locked version of HP-CMSL-WL"
    }

    # Import CMSL modules from local folder
    Out-File $logFile -Append -InputObject "Import CMSL from $sharedTools\hp-cmsl-wl"
    $modules = @(
        'HP.Private',
        'HP.Utility',
        'HP.ClientManagement',
        'HP.Firmware',
        'HP.Softpaq',
        'HP.Notifications'
    )
    foreach ($m in $modules) {
        if (Get-Module -Name $m) { Remove-Module -Force $m }
    }
    foreach ($m in $modules) {
        try {
            Import-Module -Force "$sharedTools\hp-cmsl-wl\modules\$m\$m.psd1" -ErrorAction Stop
        }
        catch {
            $exception = $_.Exception
            Out-File $logFile -Append -InputObject "Failed to import module $m"
            # Script will try to download and import CMSL again on the next execution
            #Remove-Item "$sharedTools\hp-cmsl-wl" -Recurse -Force -ErrorAction Stop
            #Remove-Item "$localCatalog" -Force -ErrorAction Stop
            throw $exception
        }
    }
    }
    catch {
      Out-File $logFile -Append -InputObject "Pre-Requisite failed: $($_.Exception.Message)"
      # If a pre-requisite fails
      throw $_.Exception
    }
}
Function Get-InstalledApplication {
  [CmdletBinding()]
  Param(
    [Parameter(
      Position=0,
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true
    )]
    [String[]]$ComputerName=$ENV:COMPUTERNAME,

    [Parameter(Position=1)]
    [String[]]$Properties,

    [Parameter(Position=2)]
    [String]$IdentifyingNumber,

    [Parameter(Position=3)]
    [String]$Name,

    [Parameter(Position=4)]
    [String]$Publisher
  )
  Begin{
    Function IsCpuX86 ([Microsoft.Win32.RegistryKey]$hklmHive){
      $regPath='SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
      $key=$hklmHive.OpenSubKey($regPath)

      $cpuArch=$key.GetValue('PROCESSOR_ARCHITECTURE')

      if($cpuArch -eq 'x86'){
        return $true
      }else{
        return $false
      }
    }
  }
  Process{
    foreach($computer in $computerName){
      $regPath = @(
        'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
      )

      Try{
        $hive=[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(
          [Microsoft.Win32.RegistryHive]::LocalMachine, 
          $computer
        )
        if(!$hive){
          continue
        }
        
        # if CPU is x86 do not query for Wow6432Node
        if($IsCpuX86){
          $regPath=$regPath[0]
        }

        foreach($path in $regPath){
          $key=$hive.OpenSubKey($path)
          if(!$key){
            continue
          }
          foreach($subKey in $key.GetSubKeyNames()){
            $subKeyObj=$null
            if($PSBoundParameters.ContainsKey('IdentifyingNumber')){
              if($subKey -ne $IdentifyingNumber -and 
                $subkey.TrimStart('{').TrimEnd('}') -ne $IdentifyingNumber){
                continue
              }
            }
            $subKeyObj=$key.OpenSubKey($subKey)
            if(!$subKeyObj){
              continue
            }
            $outHash=New-Object -TypeName Collections.Hashtable
            $appName=[String]::Empty
            $appName=($subKeyObj.GetValue('DisplayName'))
            if($PSBoundParameters.ContainsKey('Name')){
              if($appName -notlike $name){
                continue
              }
            }
            if($appName){
              if($PSBoundParameters.ContainsKey('Properties')){
                if($Properties -eq '*'){
                  foreach($keyName in ($hive.OpenSubKey("$path\$subKey")).GetValueNames()){
                    Try{
                      $value=$subKeyObj.GetValue($keyName)
                      if($value){
                        $outHash.$keyName=$value
                      }
                    }Catch{
                      Write-Warning "Subkey: [$subkey]: $($_.Exception.Message)"
                      continue
                    }
                  }
                }else{
                  foreach ($prop in $Properties){
                    $outHash.$prop=($hive.OpenSubKey("$path\$subKey")).GetValue($prop)
                  }
                }
              }
              $outHash.Name=$appName
              $outHash.IdentifyingNumber=$subKey
              $outHash.Publisher=$subKeyObj.GetValue('Publisher')
              if($PSBoundParameters.ContainsKey('Publisher')){
                if($outHash.Publisher -notlike $Publisher){
                  continue
                }
              }
              $outHash.ComputerName=$computer
              $outHash.Version=$subKeyObj.GetValue('DisplayVersion')
              $outHash.Path=$subKeyObj.ToString()
              New-Object -TypeName PSObject -Property $outHash
            }
          }
        }
      }Catch{
        Write-Error $_
      }
    }
  }
  End{}
}
#endregion Functions

#Test if MIK is installed
if (Test-Path -Path $MIKPath ){
    #Get Version of MIK Client based on Softpaq ID in Variable above
    $MIKMeta = Get-SoftpaqMetadata -Number $MIKSoftpaqID
    if ($MIKMeta){
        [Version]$MIKLatestVersion = $MIKMeta.General.Version
    }
    else {
        Write-Host "Failed to Get MIK Metadata for Softpaq $MIKSoftpaqID"
        Exit 5 #Exit with Error as script was unable to detect version properly
    }
    #Get Version of installed MIK Client from Registry
    $InstalledApps = Get-InstalledApplication
    $InstalledMIK = $InstalledApps | Where-Object {$_.Name -eq 'HP MIK Client'}
    if ($InstalledMIK){
        [Version]$MIKInstalledVersion = $InstalledMIK.Version
    }
    #Compare versions
    if ($MIKInstalledVersion -and $MIKLatestVersion){ #Confirm both Variables are created
        if ($MIKInstalledVersion -eq $MIKLatestVersion){ #Compare Versions
        }
        else {
            $Compliance = "Non-Compliant"
        }
    }
}
else {
    $Compliance = "Non-Compliant"
}

#Get HPIA Latest Version
$HPIALatest = Get-HPIALatestVersion
$HPIAVersion = $HPIALatest.HPIAVersion
$HPIAInstallPath = "$MIKPath\HPIA"
#Get HPIA Installed Version
if (Test-Path -Path $HPIAInstallPath){
    $HPIA = get-item -Path $HPIAInstallPath\HPImageAssistant.exe
    $HPIAExtractedVersion = $HPIA.VersionInfo.FileVersion
    #Compare Versions
    if ($HPIAExtractedVersion -match $HPIAVersion){
    }
    else{
        $Compliance = "Non-Compliant"
        }
}
$Compliance
