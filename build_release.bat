@echo off
echo =======================================================
echo   Athan & Quran London Pro - Release Build Tool
echo =======================================================
echo.

where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter SDK is not found in your PATH.
    echo.
    echo Please make sure Flutter is installed and added to your PATH.
    echo Example: set PATH=C:\src\flutter\bin;%%PATH%%
    echo.
    pause
    exit /b 1
)

echo [1/4] Running flutter clean...
call flutter clean

echo [2/4] Fetching dependencies (flutter pub get)...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] flutter pub get failed.
    pause
    exit /b 1
)

echo [3/4] Running automated tests (flutter test)...
call flutter test
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Some tests failed. Proceeding with build...
)

echo [4/4] Building Release APK (flutter build apk --release)...
call flutter build apk --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo =======================================================
    echo   BUILD SUCCESSFUL!
    echo   Your Release APK is ready at:
    echo   build\app\outputs\flutter-apk\app-release.apk
    echo =======================================================
    echo.
    explorer build\app\outputs\flutter-apk
) else (
    echo.
    echo [ERROR] Release build failed. Please inspect the log above.
)

pause
