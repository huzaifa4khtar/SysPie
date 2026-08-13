@echo off
setlocal

REM ===== SysPie EXE release build =====
REM 1) Build the native DLL
REM 2) Build the Flutter Windows release bundle
REM 3) Compile the Inno Setup installer into setup\

REM Resolve project root (parent of this script's directory)
set "BAT_DIR=%~dp0"
pushd "%BAT_DIR%.."
set "ROOT=%CD%\"
popd

echo Project root: %ROOT%

echo ===== Step 1/3: Native DLL =====
if exist "%ROOT%native\build_native.bat" (
    pushd "%ROOT%native"
    call build_native.bat
    if errorlevel 1 (
        echo [ERROR] Native build failed
        exit /b 1
    )
    popd
) else (
    echo [SKIP] native\build_native.bat not found
)

echo.
echo ===== Step 2/3: Flutter Windows build =====
pushd "%ROOT%app"
call flutter build windows --release
if errorlevel 1 (
    echo [ERROR] Flutter build failed
    popd
    exit /b 1
)
popd

echo.
echo ===== Step 3/3: Inno Setup installer =====
set ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe
if not exist "%ISCC%" set ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
if not exist "%ISCC%" set ISCC=C:\Program Files\Inno Setup 6\ISCC.exe

if not exist "%ISCC%" (
    echo [ERROR] ISCC.exe not found. Install Inno Setup 6.
    exit /b 1
)

"%ISCC%" "%BAT_DIR%syspie.iss"
if errorlevel 1 (
    echo [ERROR] Inno Setup compilation failed
    exit /b 1
)

echo.
echo ===== Done. Installer written to %BAT_DIR% =====
endlocal
