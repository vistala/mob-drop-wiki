@echo off
setlocal
cd /d "%~dp0"

echo ========================================
echo Harbi2 Drop Wiki - Eksik Icon Sync
echo ========================================
echo.

python ".\sync_missing_icons.py"
if errorlevel 1 (
    echo.
    echo HATA: Eksik icon senkronu basarisiz oldu.
    pause
    exit /b 1
)

echo.
echo Tamamlandi. Rapor: missing_icons_report.txt
echo Siteyi yeniden uretmek istersen generate_wiki.bat calistir.
pause
