#@gwblok @theznerd @recastsoftware
#Grabs Info from MS Website and makes into PSOBject

$KB = Invoke-WebRequest -Uri https://support.microsoft.com/en-us/help/5008339
$KBs = $KB.Links.innerText | Where-Object {$_ -match "KB\d{7,}"}

$KBData = @()

ForEach ($KBInfo in $KBs)
{
    if($KBData.KBNumber -notcontains [regex]::Match($KBInfo, "KB\d{7,}").Value)
    {
        $KBData += [PSCustomObject]@{
            Date = [datetime]::Parse([regex]::Match($KBInfo, "^.*?(?=[—|-])").Value) # matches everything from the start of the string to the first -, assuming the format stays the same)
            KBNumber = [regex]::Match($KBInfo, "KB\d{7,}").Value # matches KB + 7+ digits (assuming that the KB is always at least 7 digits)
            Build = [regex]::Matches($KBInfo, "\d{5,5}\.\d{1,}").Value # matches 5 digits "." 1+ digits (assuming that the build is always XXXXX.Y..Y)
        }
    }
}  
