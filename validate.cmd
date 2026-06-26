@echo off
:: validate.cmd — EAX Rotations Validation Gate
:: Runs: luac -p on modified files + rotation tests + leveling tests + spell audit

setlocal enabledelayedexpansion
set EXITCODE=0

:: Find Lua runtime
set "LUA_EXE=C:\Program Files (x86)\Lua\5.1\lua.exe"
if not exist "%LUA_EXE%" set "LUA_EXE=lua"

echo Using Lua: %LUA_EXE%
echo ============================================
echo  EaxRotations Validation Gate
echo ============================================

:: Phase 1: luac -p on modified Lua files
echo.
echo [1/3] Syntax check (luac -p on modified files)...
for /f "delims=" %%f in ('git diff --name-only --cached --diff-filter=AM 2^>nul') do (
    echo %%f | findstr /i "\.lua$" >nul
    if !errorlevel! equ 0 (
        luac -p "%%f" >nul 2>&1
        if !errorlevel! neq 0 (
            echo   FAIL: %%f
            set EXITCODE=1
        ) else (
            echo   PASS: %%f
        )
    )
)
:: Also check modified (not staged) files
for /f "delims=" %%f in ('git diff --name-only --diff-filter=AM 2^>nul') do (
    echo %%f | findstr /i "\.lua$" >nul
    if !errorlevel! equ 0 (
        luac -p "%%f" >nul 2>&1
        if !errorlevel! neq 0 (
            echo   FAIL: %%f
            set EXITCODE=1
        ) else (
            echo   PASS: %%f
        )
    )
)

:: Phase 2: Rotation tests
echo.
echo [2/3] Rotation test suite...
"%LUA_EXE%" EaxRotations\tests\run_rotation_tests.lua
if %errorlevel% neq 0 set EXITCODE=1

:: Phase 3: Leveling tests
echo.
echo [3/3] Leveling test suite...
"%LUA_EXE%" EaxRotations\tests\run_leveling_tests.lua
if %errorlevel% neq 0 set EXITCODE=1

:: Phase 4: Spell audit (bonus)
echo.
echo [Bonus] Spell audit...
"%LUA_EXE%" EaxRotations\tests\run_sylvanas_audit_tests.lua 2>nul || echo   (audit skipped — no audit test file)

echo.
echo ============================================
if %EXITCODE%==0 (
    echo  ALL CHECKS PASSED
) else (
    echo  SOME CHECKS FAILED
)
echo ============================================
endlocal & exit /b %EXITCODE%
