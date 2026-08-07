@echo off
echo Packaging Video Platform project into ZIP...
powershell -ExecutionPolicy Bypass -File "%~dp0create_zip.ps1"
echo.
echo Zip file created in: C:\Users\anjin\Downloads\video-platform-updated.zip
pause
