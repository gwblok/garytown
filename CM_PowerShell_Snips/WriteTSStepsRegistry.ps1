# @gwblok & @theznerd 
# 2020.10.26
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
[xml]$tsxml = $tsenv.Value("_SMSTSTaskSequence")
$sequence = $tsxml.SelectNodes("//sequence")
$TSName = $tsenv.Value("_SMSTSPackageName")
$RegPath = "HKLM:\SOFTWARE\ConfigMgr\TaskSequence"
Function Get-NodeTree
{
    param(
        [System.Xml.XmlElement]$parentNode,
        [string]$rootPath = "root"
    )
    $nodeTree = @()

    if($parentNode.LocalName -ne "sequence")
    {
        $node = [PSCustomObject]@{
            Type = $parentNode.LocalName
            Path = $rootPath
            Name = $parentNode.name
        }
        $nodeTree += $node
        $rootPath = "$rootPath\$($node.Name)"
    }

    if($parentNode.LocalName -eq "subtasksequence")
    {
        $subTSID = ($parentNode.defaultVarList.variable | where {$_.name -eq "OSDSubTasksequencePackageID"}).'#text'
       [xml]$subxml = $tsenv.Value("_TSSub-$subTSID")
        $subsequence = $subxml.SelectNodes("//sequence")
        $nodeTree += Get-NodeTree -parentNode $subsequence[0] -rootPath "$rootPath"
        #TEST
    }
    elseif($parentNode.SelectNodes("step|group|subtasksequence").Count -gt 0)
    {
        foreach($childNode in $parentNode.SelectNodes("step|group|subtasksequence"))
        {
            if(-not ($childNode.disable -eq "true"))
            {
                $nodeTree += Get-NodeTree -parentNode $childNode -rootPath "$rootPath"
            }
        }
    }
    return $nodeTree
}

$TSStepInfo = Get-NodeTree -parentNode $sequence[0]  
if (!(Test-Path $RegPath)){New-Item -Path $RegPath -Force}
if (Test-Path $RegPath\$TSName){Remove-Item -Path $RegPath\$TSName -Force;New-Item -Path $RegPath\$TSName -Force} 
else{New-Item -Path $RegPath\$TSName -Force}

$StepNumber = 0
foreach ($Step in $TSStepInfo)#{}
    {
    if ($Step.Type -ne "Group")
        {
        Write-Host "----------------" -ForegroundColor Cyan
        $StepNumber = $StepNumber + 1
        $StepNumberPad = "{0:0000}" -f $StepNumber
    
        
        Write-Output "$($StepNumberPad) $($Step.Type) | Path: $($Step.Path) | Name: $($Step.name)"
        New-ItemProperty -Path $RegPath\$TSName -Name "$($StepNumberPad) $($Step.Type)" -Value "Path: $($Step.Path) | Name: $($Step.name)" | Out-Null
        }

    }
