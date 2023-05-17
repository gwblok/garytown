<# Gary Blok | @gwblok | GARYTOWN.COM

Just a small snip to check for updated Firmware for the HP Docks using HPCMSL
Not all Docks show up in HPCMSL, so the WebURLs are listed for each dock for manual lookups too.

#>

$HPDockInfo = @(
    @{Name = 'HP Thunderbolt Dock G4' ;  WebURL = "https://support.hp.com/us-en/drivers/selfservice/hp-thunderbolt-dock-120w-g4/2101085529" ; Softpaq = 'sp143669'}
    @{Name = 'HP Thunderbolt Dock G2' ;  WebURL = "https://support.hp.com/us-en/drivers/selfservice/hp-thunderbolt-dock/20075223/model/20075224" ; Softpaq = 'sp143977'}
    @{Name = 'HP USB-C Dock G4' ;  WebURL = "https://support.hp.com/us-en/drivers/selfservice/hp-usb-c-docking-station/17032707/model/20092244" ; Softpaq = 'sp88999'}
    @{Name = 'HP USB-C Dock G5' ;  WebURL = "https://support.hp.com/us-en/drivers/selfservice/hp-usb-c-dock-g5/27767205" ; Softpaq = 'sp143343'}
    @{Name = 'HP USB-C/A Universal Dock G2' ;  WebURL = "https://support.hp.com/us-en/drivers/selfservice/hp-usb-c-a-universal-dock-g2/27767208" ; Softpaq = 'sp143451'}
    @{Name = 'HP USB-C G5 Essential Dock' ;  WebURL = "https://support.hp.com/us-en/drivers/selfservice/hp-usb-c-g5-essential-dock/2101469887" ; Softpaq = 'sp144502'}

)

foreach ($HPDock in $HPDockInfo){
    Write-Host "Dock $($HPDock.Name)" -ForegroundColor Magenta
    $MetaData = Get-SoftpaqMetadata -Number $HPDock.Softpaq
    $Version = $MetaData.General.Version
    $Firmware = Get-SoftpaqList -Category Dock | Where-Object { $_.Name -match $HPDock.Name -and ($_.Name -match 'firmware') }
    if ($Firmware){
        if ($Firmware.id -match $HPDock.Softpaq){
            Write-Host "No Change in Firmware Softpaq" -ForegroundColor Green
        }
        else {
            Write-Host "New Firmware Softpaq Available" -ForegroundColor Cyan
            Write-Host "Information on File: $($HPDock.Softpaq) | Version: $Version"
            Write-Host "Updated Softpaq: $($Firmware.id) | Version: $($Firmware.Version)"
        }
    }
    else {
        Write-Host "HPCSML does not list Firmware for this Dock" -ForegroundColor Yellow
    }
}
