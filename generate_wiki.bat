@echo off
chcp 65001 >nul
echo Mob Drop Wiki olusturuluyor...
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File "%~dp0generate_wiki.ps1"
echo.
echo Tamamlandi! index.html dosyasini tarayicinizda acin.
pause
