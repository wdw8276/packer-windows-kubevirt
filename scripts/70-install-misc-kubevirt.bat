REM Installs Chocolatey from local package, spice-agent via choco, and creates sysprep lock file

REM Install chocolatey from local package
powershell -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "$env:ChocolateyDownloadUrl='file:///E:/chocolatey.nupkg'; iex (Get-Content 'E:\install-choco.ps1' -Raw)"

REM Install spice-agent
C:\ProgramData\chocolatey\bin\choco.exe install spice-agent -y

REM Create file indicating system is not yet sysprepped
REM This is deleted using the Firstboot-Autounattend file
copy C:\windows\system32\cmd.exe C:\not-yet-finished
