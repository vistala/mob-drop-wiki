@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"

set "HARBI_ROOT=%REPO_ROOT%\Harbi2_Files"
set "SRC_CONF=%HARBI_ROOT%\srv1\share\conf"
set "SRC_LOCALE=%HARBI_ROOT%\srv1\share\locale\germany"
set "DST=%SCRIPT_DIR:~0,-1%"

echo ========================================
echo Harbi2 Mob Drop Wiki Guncelle
echo ========================================
echo.
echo Kaynak: %HARBI_ROOT%
echo Hedef : %DST%
echo.

if not exist "%HARBI_ROOT%\" (
    echo HATA: Harbi2_Files klasoru bulunamadi.
    echo Beklenen yol: %HARBI_ROOT%
    pause
    exit /b 1
)

if not exist "%SRC_CONF%\" (
    echo HATA: conf klasoru bulunamadi: %SRC_CONF%
    pause
    exit /b 1
)

if not exist "%SRC_LOCALE%\" (
    echo HATA: locale germany klasoru bulunamadi: %SRC_LOCALE%
    pause
    exit /b 1
)

if not exist "%SRC_LOCALE%\mob_drop_item.txt" (
    echo HATA: Gerekli dosya bulunamadi: %SRC_LOCALE%\mob_drop_item.txt
    pause
    exit /b 1
)
copy /Y "%SRC_LOCALE%\mob_drop_item.txt" "%DST%\mob_drop_item.txt" >nul
if errorlevel 1 exit /b 1
echo Kopyalandi: mob_drop_item.txt

if not exist "%SRC_LOCALE%\special_item_group.txt" (
    echo HATA: Gerekli dosya bulunamadi: %SRC_LOCALE%\special_item_group.txt
    pause
    exit /b 1
)
copy /Y "%SRC_LOCALE%\special_item_group.txt" "%DST%\special_item_group.txt" >nul
if errorlevel 1 exit /b 1
echo Kopyalandi: special_item_group.txt

if exist "%SRC_LOCALE%\set_item_table.txt" copy /Y "%SRC_LOCALE%\set_item_table.txt" "%DST%\set_item_table.txt" >nul && echo Kopyalandi: set_item_table.txt
if exist "%SRC_LOCALE%\group.txt" copy /Y "%SRC_LOCALE%\group.txt" "%DST%\group.txt" >nul && echo Kopyalandi: group.txt
if exist "%SRC_LOCALE%\group_group.txt" copy /Y "%SRC_LOCALE%\group_group.txt" "%DST%\group_group.txt" >nul && echo Kopyalandi: group_group.txt

if not exist "%SRC_CONF%\item_names.txt" (
    echo HATA: Gerekli dosya bulunamadi: %SRC_CONF%\item_names.txt
    pause
    exit /b 1
)
copy /Y "%SRC_CONF%\item_names.txt" "%DST%\item_names.txt" >nul
if errorlevel 1 exit /b 1
echo Kopyalandi: item_names.txt

if not exist "%SRC_CONF%\item_proto.txt" (
    echo HATA: Gerekli dosya bulunamadi: %SRC_CONF%\item_proto.txt
    pause
    exit /b 1
)
copy /Y "%SRC_CONF%\item_proto.txt" "%DST%\item_proto.txt" >nul
if errorlevel 1 exit /b 1
echo Kopyalandi: item_proto.txt

if exist "%SRC_CONF%\global_item_names.txt" copy /Y "%SRC_CONF%\global_item_names.txt" "%DST%\global_item_names.txt" >nul && echo Kopyalandi: global_item_names.txt
if exist "%SRC_CONF%\global_item_proto.txt" copy /Y "%SRC_CONF%\global_item_proto.txt" "%DST%\global_item_proto.txt" >nul && echo Kopyalandi: global_item_proto.txt
if exist "%SRC_CONF%\mob_names.txt" copy /Y "%SRC_CONF%\mob_names.txt" "%DST%\mob_names.txt" >nul && echo Kopyalandi: mob_names.txt
if exist "%SRC_CONF%\mob_proto.txt" copy /Y "%SRC_CONF%\mob_proto.txt" "%DST%\mob_proto.txt" >nul && echo Kopyalandi: mob_proto.txt

echo.
echo Wiki uretiliyor...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%generate_wiki.ps1"
if errorlevel 1 (
    echo.
    echo HATA: generate_wiki.ps1 basarisiz oldu.
    pause
    exit /b 1
)

if exist "%SCRIPT_DIR%sync_missing_item_names.ps1" (
    echo.
    echo Eksik item isimleri senkronize ediliyor...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%sync_missing_item_names.ps1"
    if errorlevel 1 (
        echo.
        echo UYARI: sync_missing_item_names.ps1 basarisiz oldu, wiki yine de uretildi.
    ) else (
        echo.
        echo Item isimleri guncellendi, wiki tekrar uretiliyor...
        powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%generate_wiki.ps1"
        if errorlevel 1 (
            echo.
            echo HATA: ikinci wiki uretimi basarisiz oldu.
            pause
            exit /b 1
        )
    )
)

if exist "%SCRIPT_DIR%sync_missing_icons.py" (
    echo.
    echo Eksik ikonlar senkronize ediliyor...
    python "%SCRIPT_DIR%sync_missing_icons.py"
    if errorlevel 1 (
        echo.
        echo UYARI: sync_missing_icons.py basarisiz oldu, devam ediliyor.
    )
)

echo.
echo Tamamlandi.
echo Cikti: %SCRIPT_DIR%index.html
echo Tarayicida aciksa Ctrl+F5 ile yenileyebilirsin.
pause
exit /b 0
