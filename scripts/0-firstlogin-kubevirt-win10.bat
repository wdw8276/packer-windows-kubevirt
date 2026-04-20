REM This is ran *first* by our Autounattendxml
REM See FirstLogonCommands/SynchronousCommand
REM Win10-specific version: OpenSSH setup is handled in init-kubevirt-win10.ps1 (provisioner stage)
REM to avoid Add-WindowsCapability -Online hanging and blocking WinRM startup.

REM Prevent Windows 11 from auto-enabling Device Encryption / BitLocker on UEFI systems
reg add "HKLM\SYSTEM\CurrentControlSet\Control\BitLocker" /v PreventDeviceEncryption /t REG_DWORD /d 1 /f

REM Set high performance mode
powercfg /SETACTIVE 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

REM Copy our sysprep Autounattend for our post-packer first boot
copy "A:/Firstboot-Autounattend-kubevirt.xml" "C:/Windows/Temp/Autounattend.xml"
REM Copy the enable-winrm script, relied on by our post-packer autounattend script
copy "A:/50-enable-winrm.ps1" "C:/Windows/Temp/enable-winrm.ps1"

REM Set PowerShell Execution Policy 64 Bit
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force"

REM Set PowerShell Execution Policy 32 Bit
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force"

REM Disable network location prompt
reg add /f "HKLM\System\CurrentControlSet\Control\Network\NewNetworkWindowOff"

REM Zero the hiberfile
%SystemRoot%\System32\reg.exe ADD HKLM\SYSTEM\CurrentControlSet\Control\Power\ /v HibernateFileSizePercent /t REG_DWORD /d 0 /f

REM Disable hibernation support
%SystemRoot%\System32\reg.exe ADD HKLM\SYSTEM\CurrentControlSet\Control\Power\ /v HibernateEnabled /t REG_DWORD /d 0 /f

REM Remove hibernation file
powercfg /h off

REM Disable password expiration for vagrant user</Description>
wmic useraccount where "name='vagrant'" set PasswordExpires=FALSE

REM Installs the code signing cert for RedHat
REM which is needed to trust the driver installation for QEMU related hardware
REM Install redhat cert for trust
certutil -addstore -f "TrustedPublisher" a:/redhat-cert.cer
REM Install the old redhat cert, used for most of their kvm drivers
certutil -addstore -f "TrustedPublisher" a:/redhat-cert-old.cer

REM WSUS / Updates
REM When upgrading packages, we'd normally have to wait for Tiworker to exit
REM This will not exit if sharing is enabled, as it will be waiting for connections
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f
REM https://github.com/rgl/packer-plugin-windows-update/issues/49#issuecomment-1295325179
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config\" /v DODownloadMode /t REG_DWORD /d 0 /f
REM Also disable auto updates, make them on-demand so our update step has an easy "Tiworker no longer executing" case
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 2 /f
REM Disable a bunch of other things
REM Stop AppX packages from auto-updating from the store (see https://blogs.technet.microsoft.com/swisspfe/2018/04/13/win10-updates-store-gpos-dualscandisabled-sup-wsus/)
reg add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v AutoDownload /t REG_DWORD /d 2
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" /v AutoDownload /t REG_DWORD /d 2
REM Stop third-party "promoted" apps from installing in the current user (see https://blogs.technet.microsoft.com/mniehaus/2015/11/23/seeing-extra-apps-turn-them-off/)
reg add "HKLM\Software\Policies\Microsoft\Windows\CloudContent /v DisableWindowsConsumerFeatures" /t REG_DWORD /d 1

REM OpenSSH: NOT installed here - handled in init-kubevirt-win10.ps1 (provisioner stage after WinRM connects)
REM On Win10 LTSC 2019, Add-WindowsCapability -Online downloads from Microsoft and can hang,
REM blocking WinRM startup. Win11 is unaffected as OpenSSH is built-in.

REM Enable RDP / Create FW rules
netsh advfirewall firewall add rule name="Open Port 3389" dir=in action=allow protocol=TCP localport=3389
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
