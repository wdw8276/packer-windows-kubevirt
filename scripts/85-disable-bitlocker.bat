REM Disable BitLocker on C: before sysprep
REM Windows 11 LTSC 2024 auto-enables Device Encryption on UEFI systems

where manage-bde >nul 2>&1
if %errorlevel% neq 0 (
    echo manage-bde not found, BitLocker not available, skipping.
    exit /b 0
)

manage-bde -off C:

:waitbitlocker
manage-bde -status C: | findstr /i "Conversion Status:" | findstr /i "Fully Decrypted"
if %errorlevel% neq 0 (
    echo Waiting for BitLocker decryption to complete...
    timeout /t 30 /nobreak >NUL
    goto waitbitlocker
)
echo BitLocker is fully disabled.
exit /b 0
