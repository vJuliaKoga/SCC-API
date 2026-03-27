@echo off
setlocal

set "TARGET_ROOT=%~1"
if not defined TARGET_ROOT set "TARGET_ROOT=%~dp0."
set "LOG_FILE=%~dp0repo-start.log"

break > "%LOG_FILE%"
echo repo-start launched at %DATE% %TIME%>> "%LOG_FILE%"
echo target root: %TARGET_ROOT%>> "%LOG_FILE%"
echo.>> "%LOG_FILE%"

REM Use the first argument when provided, otherwise use the CMD file location.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\repo-start.ps1" -Root "%TARGET_ROOT%" >> "%LOG_FILE%" 2>&1
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo repo-start completed successfully.
    echo repo-start completed successfully.>> "%LOG_FILE%"
) else (
    echo repo-start failed with exit code %EXIT_CODE%.
    echo Confirm that this tool is placed somewhere inside the target Git repository.
    echo repo-start failed with exit code %EXIT_CODE%.>> "%LOG_FILE%"
    echo Confirm that this tool is placed somewhere inside the target Git repository.>> "%LOG_FILE%"
    start "" notepad.exe "%LOG_FILE%"
)
echo Press any key to close this window.
pause >nul

endlocal & exit /b %EXIT_CODE%
