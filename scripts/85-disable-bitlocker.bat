REM Disable BitLocker on C: before sysprep
REM Windows 11 LTSC 2024 auto-enables Device Encryption on UEFI systems

manage-bde -off C:

:waitbitlocker
manage-bde -status C: | findstr /i "Conversion Status:" | findstr /i "Fully Decrypted"
if %errorlevel% neq 0 (
    echo Waiting for BitLocker decryption to complete...
    timeout /t 30 /nobreak >NUL
    goto waitbitlocker
)
echo BitLocker is fully disabled.
