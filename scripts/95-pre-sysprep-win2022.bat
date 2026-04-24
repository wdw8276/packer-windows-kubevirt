REM Pre-sysprep cleanup for Windows Server 2022
REM Fixes issues specific to Server 2022 that block or hang sysprep

REM Disable Windows Defender via Group Policy (bypasses Tamper Protection)
REM Prevents MsMpEng from blocking the sysprep generalize phase
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f
taskkill /f /im MsMpEng.exe >nul 2>&1

REM Clear all pending reboot flags
REM CBS (Component Based Servicing) sets RebootPending after driver/component installs
REM sysprep refuses to run if any of these keys exist
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting" /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations /f >nul 2>&1

echo Pre-sysprep cleanup done.
