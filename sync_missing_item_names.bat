@echo off
setlocal
cd /d "%~dp0"

echo ========================================
echo Harbi2 Drop Wiki - Eksik Item Isim Sync
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File ".\sync_missing_item_names.ps1"
if errorlevel 1 (
    echo.
    echo HATA: Eksik item isim senkronu basarisiz oldu.
    pause
    exit /b 1
)

echo.
echo Wiki yeniden olusturuluyor...
powershell -NoProfile -ExecutionPolicy Bypass -File ".\generate_wiki.ps1"
if errorlevel 1 (
    echo.
    echo HATA: Wiki olusturma basarisiz oldu.
    pause
    exit /b 1
)

echo.
echo Tamamlandi. Tarayicida Ctrl+F5 ile yenileyebilirsin.
echo Canli site icin degisiklikleri git push yapman gerekir.
pause
