
Write-Host "Start Initialization"

Write-Host "Allow ICMP"
netsh advfirewall firewall add rule name="All ICMP V4" dir=in action=allow protocol=icmpv4
Start-Sleep -Seconds 5

Write-Host "Install vcredist"
Start-Process -FilePath "E:\vcredist_x86.exe" -ArgumentList "/passive /norestart" -Wait
Start-Sleep -Seconds 10
Start-Process -FilePath "E:\vcredist_x64.exe" -ArgumentList "/passive /norestart" -Wait
Start-Sleep -Seconds 10

Write-Host "Install qemu-ga"
Start-Process msiexec -ArgumentList "/i `"E:\qemu-ga-x86_64.msi`" /passive /norestart" -Wait
Start-Sleep -Seconds 30

Write-Host "Disable Windows Update driver search"
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" /v SearchOrderConfig /t REG_DWORD /d 0 /f

Write-Host "Install netkvm"
PnPutil.exe /add-driver 'E:\drivers\amd64\w10\NetKVM\netkvm.inf'
Copy-Item -Path 'E:\drivers\amd64\w10\NetKVM\netkvmp.exe' -Destination 'C:\Windows\System32\netkvmp.exe'
Copy-Item -Path 'E:\drivers\amd64\w10\NetKVM\netkvmco.exe' -Destination 'C:\Windows\System32\netkvmco.exe'
Start-Sleep -Seconds 20

Write-Host "Install vioscsi"
PnPutil.exe /add-driver 'E:\drivers\amd64\w10\vioscsi\vioscsi.inf'
Start-Sleep -Seconds 20

Write-Host "Install vioserial"
PnPutil.exe /add-driver 'E:\drivers\amd64\w10\vioserial\vioser.inf'
Start-Sleep -Seconds 20

Write-Host "Install viostor"
PnPutil.exe /add-driver 'E:\drivers\amd64\w10\viostor\viostor.inf'
Start-Sleep -Seconds 20

Write-Host "Install viorng"
PnPutil.exe /add-driver 'E:\drivers\amd64\w10\viorng\viorng.inf'
Start-Sleep -Seconds 20

Write-Host "Install blnsvr (Balloon)"
PnPutil.exe /add-driver 'E:\drivers\amd64\w10\Balloon\balloon.inf'
New-Item -Path 'C:\Program Files\Balloon' -ItemType Directory -Force
Copy-Item -Path 'E:\drivers\amd64\w10\Balloon\blnsvr.exe' -Destination 'C:\Program Files\Balloon\blnsvr.exe'
& 'C:\Program Files\Balloon\blnsvr.exe' -i
Start-Sleep -Seconds 20

Write-Host "Install telnet"
dism /online /Enable-Feature /FeatureName:TelnetClient
Start-Sleep -Seconds 5

Write-Host "Set time zone"
Set-TimeZone -Id "China Standard Time"
net start w32time
Start-Sleep -Seconds 30
w32tm /resync /force
Start-Sleep -Seconds 30

Write-Host "Enable Remote Desktop"
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
Start-Sleep -Seconds 5

Write-Host "Allow incoming RDP on firewall"
netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes
netsh advfirewall firewall set rule group="远程桌面" new enable=yes
Start-Sleep -Seconds 5

Write-Host "Enable secure RDP authentication"
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "UserAuthentication" /t REG_DWORD /d 0 /f
Start-Sleep -Seconds 10

Write-Host "Install CloudbaseInit"
Start-Process msiexec -ArgumentList "/i `"E:\CloudbaseInitSetup_1_1_2_x64.msi`" /passive /norestart" -Wait
Start-Sleep -Seconds 30

Copy-Item -Path "E:\cloudbase-init_kubevirt.conf" -Destination "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf"
Start-Sleep -Seconds 5

Write-Host "Disable Automatic Updates"
# Already set in 0-firstlogin-kubevirt.bat, kept here for reference
# New-Item HKLM:\SOFTWARE\Policies\Microsoft\Windows -Name WindowsUpdate -Force
# New-Item HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name AU -Force
# New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name NoAutoUpdate -Value 1 -PropertyType DWORD
# Start-Sleep -Seconds 20

Write-Host "Install viofs"
PnPutil.exe -i -a 'E:\drivers\amd64\w10\viofs\viofs.inf'
New-Item -Path 'C:\Program Files\viofs' -ItemType Directory -Force
Copy-Item -Path 'E:\drivers\amd64\w10\viofs\virtiofs.exe' -Destination 'C:\Program Files\viofs\virtiofs.exe'
Start-Sleep -Seconds 20

Write-Host "Install WinFsp"
Start-Process msiexec -ArgumentList "/i `"E:\winfsp-2.0.23075.msi`" /passive /norestart" -Wait
Start-Sleep -Seconds 30

cmd /c 'sc create VirtioFsSvc binpath="C:\Program Files\viofs\virtiofs.exe" start=auto depend="WinFsp.Launcher/VirtioFsDrv" DisplayName="Virtio FS Service"'
# sc.exe start VirtioFsSvc
Start-Sleep -Seconds 10

Write-Host "Enable Administrator account"
net user Administrator /active:yes

Write-Host "Install OpenSSH Server"
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Set-Service -Name sshd -StartupType 'Automatic'
Start-Service sshd
if (!(Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
}
Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' | Format-List Name, Enabled, Direction, Action
Start-Sleep -Seconds 10

Write-Host "Register startup task to keep wuauserv disabled"
$action1 = New-ScheduledTaskAction -Execute 'sc.exe' -Argument 'config WaaSMedicSvc start= disabled'
$action2 = New-ScheduledTaskAction -Execute 'sc.exe' -Argument 'stop WaaSMedicSvc'
$action3 = New-ScheduledTaskAction -Execute 'sc.exe' -Argument 'config wuauserv start= disabled'
$action4 = New-ScheduledTaskAction -Execute 'sc.exe' -Argument 'stop wuauserv'
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName 'DisableWindowsUpdate' -Action $action1,$action2,$action3,$action4 -Trigger $trigger -Principal $principal -Force

Function Cleanup {
  Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
  Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 5
  Get-ChildItem "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
  Get-ChildItem "C:\users\*\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
  Get-ChildItem "C:\users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
}

Cleanup

Write-Host "Initialization is complete"
