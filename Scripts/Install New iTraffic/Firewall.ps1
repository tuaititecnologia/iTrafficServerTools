Enable-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)"
Enable-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv6-In)"
New-NetFirewallRule -DisplayName "SQL Server Express TCP 1433" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow -Profile Domain,Private,Public
