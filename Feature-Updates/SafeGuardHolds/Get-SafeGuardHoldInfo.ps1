#Gary Blok
#Function used to get SafeGuard Hold information from Endpoint
function Get-SafeGuardHoldInfo {
    $UX = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators"
    foreach ($U in $UX){
        $GatedBlockId = $U.GetValue('GatedBlockId')
        if ($GatedBlockId){
            if ($GatedBlockId -ne "None"){
                $SafeGuardID  = $GatedBlockId
                $ALTERNATEDATALINK = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\windows\CurrentVersion\OneSettings\compat\appraiser\Settings' -Name 'ALTERNATEDATALINK'
                $ALTERNATEDATAVERSION = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\windows\CurrentVersion\OneSettings\compat\appraiser\Settings' -Name 'ALTERNATEDATAVERSION'
                $SafeGuardInfo = New-Object -TypeName psobject
                $SafeGuardInfo | Add-Member -MemberType NoteProperty -Name "SafeGuardID" -Value "$SafeGuardID" -Force
                $SafeGuardInfo | Add-Member -MemberType NoteProperty -Name "ALTERNATEDATALINK" -Value "$ALTERNATEDATALINK" -Force
                $SafeGuardInfo | Add-Member -MemberType NoteProperty -Name "ALTERNATEDATAVERSION" -Value "$ALTERNATEDATAVERSION" -Force
            }             
        }
    }
    if (!($SafeGuardID)){
        $SafeGuardID = "NONE"
        $SafeGuardInfo = New-Object -TypeName psobject
        $SafeGuardInfo | Add-Member -MemberType NoteProperty -Name "SafeGuardID" -Value "$SafeGuardID" -Force
    }
    return $SafeGuardInfo
}
