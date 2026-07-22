@echo off
REM run_all_checks.bat -- Windows equivalent of tools/run_all_checks.sh.
REM WHAT: luac parse + rotation tests + leveling tests + badge drift check.
REM WHEN: local pre-commit validation on Windows.
REM USAGE: tools\run_all_checks.bat

setlocal EnableDelayedExpansion
set "ROOT=%~dp0.."
cd /d "%ROOT%"

echo === EaxRotations validation gate ===
echo.

echo [1/4] Parsing all .lua files with luac -p ...
for /r "EaxRotations" %%f in (*.lua) do (
    luac -p "%%f" >nul 2>&1
    if errorlevel 1 (
        echo FAIL: luac -p "%%f"
        exit /b 1
    )
)
echo   OK - all files parse.

echo.
echo [2/4] Running rotation test suite ...
lua EaxRotations\tests\run_rotation_tests.lua
if errorlevel 1 exit /b 1

echo.
echo [3/4] Running leveling test suite ...
lua EaxRotations\tests\run_leveling_tests.lua
if errorlevel 1 exit /b 1

echo.
echo [4/4] Checking badge counts are in sync ...
lua tools\update_badges.lua --check
if errorlevel 1 exit /b 1

echo.
echo [5/5] Checking Lua 5.1 compatibility (luac -p on all project .lua files) ...
lua tools\check_lua51_compat.lua
if errorlevel 1 exit /b 1

echo.
echo === All checks passed ===
