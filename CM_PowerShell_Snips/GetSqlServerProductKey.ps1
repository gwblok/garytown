function GetSqlServerProductKey {
    ## function to retrieve the license key of a SQL 2014+ Server.
    #Code From: https://www.ryadel.com/en/sql-server-retrieve-product-key-from-an-existing-installation/
    param ($targets = ".")
    $hklm = 2147483650
    $regPath = "SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL15.MSSQLSERVER\Setup"
    $regValue1 = "DigitalProductId"
    $regValue2 = "PatchLevel"
    $regValue3 = "Edition"
    Foreach ($target in $targets) {
        $productKey = $null
        $win32os = $null
        $wmi = [WMIClass]"\\$target\root\default:stdRegProv"
        $data = $wmi.GetBinaryValue($hklm,$regPath,$regValue1)
        [string]$SQLver = $wmi.GetstringValue($hklm,$regPath,$regValue2).svalue
        [string]$SQLedition = $wmi.GetstringValue($hklm,$regPath,$regValue3).svalue
        $binArray = ($data.uValue)[0..16]
        $charsArray = "B","C","D","F","G","H","J","K","M","P","Q","R","T","V","W","X","Y","2","3","4","6","7","8","9"
        ## decrypt base24 encoded binary data
        For ($i = 24; $i -ge 0; $i--) {
            $k = 0
            For ($j = 14; $j -ge 0; $j--) {
                $k = $k * 256 -bxor $binArray[$j]
                $binArray[$j] = [math]::truncate($k / 24)
                $k = $k % 24
         }
            $productKey = $charsArray[$k] + $productKey
            If (($i % 5 -eq 0) -and ($i -ne 0)) {
                $productKey = "-" + $productKey
            }
        }
        $win32os = Get-WmiObject Win32_OperatingSystem -computer $target
        $obj = New-Object Object
        $obj | Add-Member Noteproperty Computer -value $target
        $obj | Add-Member Noteproperty OSCaption -value $win32os.Caption
        $obj | Add-Member Noteproperty OSArch -value $win32os.OSArchitecture
        $obj | Add-Member Noteproperty SQLver -value $SQLver
        $obj | Add-Member Noteproperty SQLedition -value $SQLedition
        $obj | Add-Member Noteproperty ProductKey -value $productkey
        $obj
    }
}
