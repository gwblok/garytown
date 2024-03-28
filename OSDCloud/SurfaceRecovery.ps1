$SurfaceProXWin1122H2URL = 'https://surface.downloads.prss.microsoft.com/dbazure/SurfaceProX_2021_BMR_16020_11.4.1.zip'


$MSIPath = "C:\Users\GaryBlok\Downloads\SurfacePro9-5G_Win11_22621_24.033.36032.0.msi"
msiexec /a $MSIPath /qb TARGETDIR='C:\OSDCloudARM64\WinPEDrivers'
