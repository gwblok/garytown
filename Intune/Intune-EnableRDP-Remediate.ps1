#Gary Blok | GARYTOWN.COM | @GWBLOK
#Enable RDP Remediation Script

#Enable RDP
(Get-WmiObject -Class "Win32_TerminalServiceSetting" -Namespace root\CIMV2\TerminalServices).SetAllowTSConnections(1,1)

#Disable NLA
(Get-WmiObject -class "Win32_TSGeneralSetting" -Namespace root\CIMV2\TerminalServices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0)

#Restart Service
Enable-NetFirewallRule -DisplayGroup “Remote Desktop”
Restart-Service -Force -Name "TermService"
