#Get a list of all Platforms
Get-HPDeviceDetails -Match *

#Find information based on Model Name
Get-HPDeviceDetails -Match "HP Z2 Mini G4"

#Find driver pack for your specific platform & OS Build
Get-SoftpaqList -Platform 8458 -Os win11 -OsVer 21H2 -Category Driverpack


function Get-HPDeviceFamilyPlatformDetails {
    [CmdletBinding(DefaultParameterSetName='Family')]
    param (
        [parameter(Mandatory=$false,
        ParameterSetName="Family")]
        [String]
        $biosFamily,

        [parameter(Mandatory=$false,
        ParameterSetName="SystemID")]
        [String]
        $platform    

    )
    #$PSCmdlet.ParameterSetName
    $ConnectPlatformsURL = 'https://hpconnectformem-prod.hpbp.io/platforms'
    if (Test-WebConnection){
        $content = (invoke-webrequest -Uri $ConnectPlatformsURL).content | Convertfrom-Json

        if ($biosFamily){
            
            $Content | Where-Object {$_.biosFamily -eq $biosFamily}
        }
        elseif ($platform){
            $Content | Where-Object {$_.systemId -eq $platform}
        }
        else{
            $content
        }
    }
    else {
        Write-Output "This function requires internet connection"
    }
}