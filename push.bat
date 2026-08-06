@echo off
echo ========================================================
echo   🚀 Video Platform - One-Click Git Push ^& APK Release
echo ========================================================
cd /d "C:\Users\anjin\Downloads\video-final app\video-platform"

echo.
echo [1/3] Staging changes...
git add .

echo.
echo [2/3] Committing updates...
git commit -m "release: automated build and APK release update"

echo.
echo [3/3] Pushing to GitHub main branch...
git push origin main

echo.
echo ========================================================
echo   ✅ SUCCESS! GitHub Actions is now building your APK.
echo   🔗 Track Build: https://github.com/pittaanji9390-afk/video-platform/actions
echo   📦 Download APK: https://github.com/pittaanji9390-afk/video-platform/releases
echo ========================================================
pause
