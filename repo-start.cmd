@echo off
setlocal

set "TARGET_ROOT=%~1"
if not defined TARGET_ROOT set "TARGET_ROOT=%~dp0."
set "LOG_FILE=%~dp0repo-start.log"
set "PS_EXE=powershell.exe"

where pwsh.exe >nul 2>nul
if %ERRORLEVEL%==0 set "PS_EXE=pwsh.exe"

break > "%LOG_FILE%"
echo repo-start launched at %DATE% %TIME%>> "%LOG_FILE%"
echo target root: %TARGET_ROOT%>> "%LOG_FILE%"
echo powershell: %PS_EXE%>> "%LOG_FILE%"
echo.>> "%LOG_FILE%"

REM Use the first argument when provided, otherwise use the CMD file location.
%PS_EXE% -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\repo-start.ps1" -Root "%TARGET_ROOT%" -LogPath "%LOG_FILE%"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo repo-start completed successfully.
    echo repo-start completed successfully.>> "%LOG_FILE%"
) else (
    if "%EXIT_CODE%"=="2" (
        echo repo-start was canceled.
        echo repo-start was canceled.>> "%LOG_FILE%"
    ) else (
        echo repo-start failed with exit code %EXIT_CODE%.
        echo Confirm that this tool is placed somewhere inside the target Git repository.
        echo repo-start failed with exit code %EXIT_CODE%.>> "%LOG_FILE%"
        echo Confirm that this tool is placed somewhere inside the target Git repository.>> "%LOG_FILE%"
        start "" notepad.exe "%LOG_FILE%"
    )
)
echo Press any key to close this window.
pause >nul

endlocal & exit /b %EXIT_CODE%
