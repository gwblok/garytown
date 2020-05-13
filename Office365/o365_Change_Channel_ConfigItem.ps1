
<# Change Office Channel Baseline / CI Script
Gary Blok @gwblok - GARYTOWN.COM

ConfigItem Detection: Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Office 365 ProPlus%'"

Use Same Script for Discovery & Remediation, just change $RunMode

Set the $TargetChannelName to Broad / Monthly / Targeted and create 3 Baselines deployed to the 3 collections.  No need to bother with Collection Variables.
#>
$RunMode = "Remediate"
$TargetChannelName = "MonthlyEnterprise" 


#Get Information about how Office is currently setup.
$Configuration = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
$CurrentCDNBaseUrlValue = (Get-ItemProperty $Configuration).CDNBaseUrl
$CurrentUpdateChannelValue = (Get-ItemProperty $Configuration).UpdateChannel
$CurrentPreview = "http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be"
$Current = "http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60"
$MonthlyEnterprise = "http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6"
$SemiAnnualPreview = "http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf"
$SemiAnnual = "http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114"
if ($CurrentCDNBaseUrlValue -eq $CurrentPreview){$CurrentCDNBaseUrlName = "CurrentPreview"}
if ($CurrentCDNBaseUrlValue -eq $Current){$CurrentCDNBaseUrlName = "Current"}
if ($CurrentCDNBaseUrlValue -eq $MonthlyEnterprise){$CurrentCDNBaseUrlName = "MonthlyEnterprise"}
if ($CurrentCDNBaseUrlValue -eq $SemiAnnualPreview){$CurrentCDNBaseUrlName = "SemiAnnualPreview"}
if ($CurrentCDNBaseUrlValue -eq $SemiAnnual){$CurrentCDNBaseUrlName = "SemiAnnual"}

#Checks both Registry Keys, if even one of the two are not set to the correct Channel, it will run the remdiation (if set to remediation) otherwise Discovery will return non-compliant status.
if ($CurrentUpdateChannelValue -ne $TargetChannelValue -or $CurrentCDNBaseUrlValue -ne $TargetChannelValue)
    {
    # Set new update channel
    if ($RunMode -eq "Remediate")
        {
        Set-ItemProperty -Path $Configuration -Name "CDNBaseUrl" -Value $TargetChannelValue -Force
        Set-ItemProperty -Path $Configuration -Name "UpdateChannel" -Value $TargetChannelValue -Force
        $ProcessName = "$env:ProgramFiles\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe"
        $Click2RunArg1 =  "/changesetting Channel=$TargetChannelName"
        $Click2RunArg2 = "/update user updateprompt=false forceappshutdown=true displaylevel=true"
        Start-Process -FilePath $ProcessName -ArgumentList $Click2RunArg1
        Start-Sleep -Seconds 5
        #Start-Process -FilePath $ProcessName -ArgumentList $Click2RunArg2  #Use this if you're not using CM for patching but instead going right to CDN on internet
        #Start-Sleep -Seconds 2
        # Trigger CM Client Actions
        [Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000001}') #Hardware Inventory to report up new channel to CM
        Start-Sleep -Seconds 5
        [Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000113}') #Update Scan
        Start-Sleep -Seconds 5
        [Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000108}') #Update Eval
        Start-Sleep -Seconds 5
        [Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000108}') #Update Eval
        Start-Sleep -Seconds 5
        [Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000113}') #Update Scan
        }
    else {Write-Output "Current Channel: $CurrentCDNBaseUrlName"}
    }
else {Write-Output "Compliant"}
   
