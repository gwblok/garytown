<# GARY BLOK - @GWBLOK - GARYTOWN.COM
https://garytown.com/atlassian-confluence-updating-tables-with-powershell

Thanks to https://twitter.com/AndrewZtrhgf
For this Post that got me started: https://doitpsway.com/how-to-createupdateread-html-table-on-confluence-wiki-page-using-powershell

You'll need to update your Atlassian Information (URL, Username, Token, etc)
You'll need to update your Confluence Page infomration ($PageToUpdate)


#>

#Setup PowerShell
if (!((Get-PackageProvider -ListAvailable).Name -contains "NuGet")){
    Install-PackageProvider -Name NuGet -MinimumVersion '2.8.5.201' -Force -Scope AllUsers
    }

if (!((Get-Module -ListAvailable).Name -contains "ConfluencePS")){
    Install-Module -Name ConfluencePS -AllowClobber -SkipPublisherCheck -Force -Confirm:$false
    }



#Connection Creds to Atlassian Cloud
#https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/
$AtlassianName = "YOUR ACCOUNT EMAIL HERE"
$AtlassianToken = 'YOUR TOKEN HERE' | ConvertTo-SecureString -Force -AsPlainText 
if (!($Credential)){$Credential = New-Object System.Management.Automation.PsCredential("$AtlassianName",$AtlassianToken)}
$AtlassianConfigServer = "https://garytown.atlassian.net" #YOUR SERVER THERE
Import-Module ConfluencePS -ErrorAction Stop
# authenticate to your Confluence space
$baseUri = "$AtlassianConfigServer/wiki"
Set-ConfluenceInfo -BaseURi "$baseUri" -Credential $Credential

Add-Type -AssemblyName System.Web
function _convertFromHTMLTable {
    # function convert html object to PS object
    # expects object returned by (Invoke-WebRequest).parsedHtml as input
    param ([System.__ComObject]$table)

    $columnName = $table.getElementsByTagName("th") | % { $_.innerText -replace "^\s*|\s*$" }

    $table.getElementsByTagName("tr") | % {
        # per row I read cell content and returns object
        $columnValue = $_.getElementsByTagName("td") | % { $_.innerText -replace "^\s*|\s*$" }
        if ($columnValue) {
            $property = [ordered]@{ }
            $i = 0
            $columnName | % {
                $property.$_ = $columnValue[$i]
                ++$i
            }

            New-Object -TypeName PSObject -Property $property
        } else {
            # row doesn't contain <td>, its probably headline
        }
    }
}


$PageToUpdate = Get-ConfluencePage -SpaceKey 'MEMCM' | Where-Object {$_.Title -match "WaaS 20H2 Regression Testing"}
$pageID = $PageToUpdate.ID

$Headers = @{"Authorization" = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($Credential.UserName + ":" + [System.Runtime.InteropServices.marshal]::PtrToStringAuto([System.Runtime.InteropServices.marshal]::SecureStringToBSTR($Credential.Password)) ))) }

# Invoke-WebRequest instead of Get-ConfluencePage to be able to use ParsedHtml
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    $confluencePageContent = Invoke-WebRequest -Method GET -Headers $Headers -Uri "$baseUri/rest/api/content/$pageID`?expand=body.storage" -ea stop
} catch {
    if ($_.exception -match "The response content cannot be parsed because the Internet Explorer engine is not available") {
        throw "Error was: $($_.exception)`n Run following command on $env:COMPUTERNAME to solve this:`nSet-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main' -Name DisableFirstRunCustomize -Value 2"
    } else {
        throw $_
    }
}

# from confluence page get content of the first html table
$table = $confluencePageContent.ParsedHtml.GetElementsByTagName('table')[0]

# convert HTML table to PS object
$confluenceContent = @(_convertFromHTMLTable $table)
#endregion get data from confluence page (table)

<# Sample
$modifyContent = $confluenceContent | where-object {$_.Model -eq "Test Model"}
$modifyContent.'BIOS Version' = "1.3.1"
$modifyContent.Notes = "Testing Notes"
#>
#AddContent


#Get Regression Testing JSON Files & build Array
$RegressionFolder = "\\src.corp.viamonstra.com\logs$\Regression"
$JSONFiles = Get-ChildItem -Path $RegressionFolder -Recurse -Filter "*.json"
$JSONArray = @()
Foreach ($JSONFile in $JSONFiles)
    {
    $JSONRaw = Get-Content -Path $JSONFile.fullname | ConvertFrom-Json
    $JSONArray += $JSONRaw
    }

#Update Confluence Table Object with Data from Regression Testing
$UpdateRequired = $false
Foreach ($JSONItem in $JSONArray)#{}
    {
    $UpdateContent = $confluenceContent | Where-Object {$_.Name -match $JSONItem.Name}
    if ($UpdateContent){
        if ($UpdateContent.'Test Date' -eq $JSONItem.'TS Start')
            {
            Write-Output "Duplicate, Skipping update of Record: $($JSONItem.Name) on $($JSONItem.'TS Start')"
            }
        else
            {
            UpdateRequired = $true
            Write-Output "Updating Record for $($JSONItem.Name) on $($JSONItem.'TS Start')"
            $UpdateContent.Make = $JSONItem.Manufacturer
            $UpdateContent.Model = $JSONItem.Model
            $UpdateContent.'Product / Type ID' = $JSONItem.ID
            $UpdateContent.Name = $JSONItem.Name
            $UpdateContent.User = $JSONItem.LoggedON
            $UpdateContent.'BIOS Version' = $JSONitem.'BIOS Version'
            $UpdateContent.'BIOS Mode' = $JSONItem.'BIOS Mode'
            $UpdateContent.'Driver Version' = $JSONItem.DriverPack
            $UpdateContent.Encryption = $JSONItem.Encryption
            $UpdateContent.'Win Build' = $JSONItem.IPUBuild
            $UpdateContent.Status = $JSONItem.WaaS_Stage
            $UpdateContent.'Test Date' = $JSONItem.'TS Start'

            }
        }   
    Else{
        $UpdateRequired = $true        
        Write-Output "Creating new Record for $($JSONItem.Name) on $($JSONItem.'TS Start')"
        $NewContent = New-Object PSObject
        $TemplateRecord = $confluenceContent | Select-Object -First 1
        $TemplateRecord.psobject.properties | % {
            $NewContent | Add-Member -MemberType $_.MemberType -Name $_.Name -Value $_.Value
            }
        $NewContent.Make = $JSONItem.Manufacturer
        $NewContent.Model = $JSONItem.Model
        $NewContent.'Product / Type ID' = $JSONItem.ID
        $NewContent.Name = $JSONItem.Name
        $NewContent.User = $JSONItem.LoggedON
        $NewContent.'BIOS Version' = $JSONitem.'BIOS Version'
        $NewContent.'BIOS Mode' = $JSONItem.'BIOS Mode'
        $NewContent.'Driver Version' = $JSONItem.DriverPack
        $NewContent.Encryption = $JSONItem.Encryption
        $NewContent.'Win Build' = $JSONItem.IPUBuild
        $NewContent.Status = $JSONItem.WaaS_Stage
        $NewContent.'Test Date' = $JSONItem.'TS Start'
        $confluenceContent = $confluenceContent + $NewContent
        }
    }

if ($UpdateRequired -eq $true){
    #Update Confluence Page
    $BodyHeader = ($($PageToUpdate.Body) -Split('<table'))[0]
    $BodyFooter = ($($PageToUpdate.Body) -Split('</table>'))[-1]
    $Tablebody = $confluenceContent | ConvertTo-ConfluenceTable | ConvertTo-ConfluenceStorageFormat
    $UpdatedBody = $BodyHeader + $Tablebody + $BodyFooter
    Set-ConfluencePage -PageID $pageID -Body $UpdatedBody
    }
