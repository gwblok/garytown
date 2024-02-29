<#
Entire Thing was based on https://z-nerd.com/blog/2019/01/15-band-practice/
Thanks Nathan Ziehnert for explaining to this to me.


#>

# https://learn.microsoft.com/en-us/previous-versions/system-center/developer/cc144361(v=msdn.10)
[flags()]enum ProgramFlags {
    UNKNOWN = 0x00000000
    AUTHORIZED_DYNAMIC_INSTALL = 0x00000001
    USECUSTOMPROGRESSMSG = 0x00000002
    DEFAULT_PROGRAM = 0x00000010
    DISABLEMOMALERTONRUNNING = 0x00000020
    MOMALERTONFAIL = 0x00000040
    RUN_DEPENDANT_ALWAYS = 0x00000080
    WINDOWS_CE = 0x00000100
    NOT_USED = 0x00000200
    COUNTDOWN = 0x00000400
    FORCERERUN = 0x00000800
    DISABLED = 0x00001000
    UNATTENDED = 0x00002000
    USERCONTEXT = 0x00004000
    ADMINRIGHTS = 0x00008000
    EVERYUSER = 0x00010000
    NOUSERLOGGEDIN = 0x00020000
    OKTOQUIT = 0x00040000
    OKTOREBOOT = 0x00080000
    USEUNCPATH = 0x00100000
    PERSISTCONNECTION = 0x00200000
    RUNMINIMIZED = 0x00400000
    RUNMAXIMIZED = 0x00800000
    HIDEWINDOW = 0x01000000
    OKTOLOGOFF = 0x02000000
    RUNACCOUNT = 0x04000000
    ANY_PLATFORM = 0x08000000
    STILL_RUNNING = 0x10000000
    SUPPORT_UNINSTALL = 0x20000000
    UNSUPPORTED = 0x40000000
    SHOW_IN_ARP = 0x80000000
}


#Package ID for the Package with the Program you wish to test.
#$PackageID = 'MCM0004A'
#Assumes you have the CM Module available
#$Program = Get-CMProgram -PackageId $PackageID

#Test if Program is set to "Any Platform"
#https://learn.microsoft.com/en-us/mem/configmgr/develop/core/servers/configure/how-to-modify-the-supported-platforms-for-a-program
#([ProgramFlags]($Program.ProgramFlags) -band [ProgramFlags]::ANY_PLATFORM) -eq [ProgramFlags]::ANY_PLATFORM


#Test All CM Packages:
$AllCMPackages = Get-CMPackage -Fast
$AnyPlatform = '0x08000000'
ForEach ($Package in $AllCMPackages){
    if ($Package.NumOfPrograms -gt 0){
        $Programs = Get-CMProgram -PackageId $Package.PackageID
        foreach ($Program in $Programs){
            if (!([ProgramFlags]($Program.ProgramFlags) -band [ProgramFlags]::ANY_PLATFORM) -eq [ProgramFlags]::ANY_PLATFORM){
                Write-Output "$($Program.PackageName) | Is not set to Any Platform"
                Write-Output "Fixing....."
                #Fix It
                $newFlags = $Program.ProgramFlags -bxor $AnyPlatform
                $Program.ProgramFlags = $newFlags
                $Program.Put()

                #Test
                $Test = Get-CMProgram -PackageId $Package.PackageID -ProgramName $Program.ProgramName
                $TestResult = ([ProgramFlags]($Test.ProgramFlags) -band [ProgramFlags]::ANY_PLATFORM) -eq [ProgramFlags]::ANY_PLATFORM
                if ($TestResult -eq $true){ Write-Output "$($Test.PackageName) Successfully Update"}
                else {Write-Output "$($Test.PackageName) Failed to Update"}  

            }
        }
    }
}
