<# Gary Blok w/ Help of Nathan Ziehnert

ConfigMgr Package Program's ProgramFlag decoder ring
https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_program-server-wmi-class


#>

#Update this line for your Package & Program
$variable = (Get-CMProgram -PackageId 'MEM00027' -ProgramName "MPAM-FE").ProgramFlags

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

[ProgramFlags]$variable = $variable
foreach ($Flag in [ProgramFlags].GetEnumValues()){
    Write-Host -ForegroundColor Cyan "$Flag : "  -NoNewline
    
    if($Flag -eq [ProgramFlags]::UNKNOWN -and $variable -ne 0) { # Handle the UNKNOWN Case
        Write-Host -ForegroundColor Green "False"
    } else {
        Write-Host -ForegroundColor Green $variable.HasFlag($Flag)
    }
}
