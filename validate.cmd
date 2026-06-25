@echo off
REM EaxRotations validate.cmd — automated test gate
REM Runs luac -p on modified files + full test suite
REM Exit 0 = all pass, Exit 1 = any fail

setlocal enabledelayedexpansion
set EXIT_CODE=0

REM Pin test runtime to Lua 5.1 (project target, LuaJIT-compatible).
REM The 'lua' on PATH may be Lua 5.4 — wrong version for this codebase.
REM NOTE: single-line `if` form used deliberately — the 5.1 path contains "(x86)"
REM parens that break multi-line `if (...) else (...)` block parsing in cmd.exe.
set "LUA_EXE=C:\Program Files (x86)\Lua\5.1\lua.exe"
if not exist "%LUA_EXE%" set "LUA_EXE=lua"
if not "%LUA_EXE%"=="lua" echo Using Lua: %LUA_EXE%
if "%LUA_EXE%"=="lua" echo WARN: Lua 5.1 not found at expected path; using PATH lua - may be wrong version

echo ============================================
echo  EaxRotations Validation Gate
echo ============================================
echo.

REM Step 1: luac -p on all modified .lua files (git diff)
echo [1/3] Syntax check (luac -p on modified files)...
for /f "delims=" %%f in ('git diff --name-only --diff-filter=ACMR -- "*.lua"') do (
    if exist "%%f" (
        luac -p "%%f" 2>nul
        if !errorlevel! neq 0 (
            echo   FAIL: %%f
            set EXIT_CODE=1
        ) else (
            echo   PASS: %%f
        )
    )
)
echo.

REM Step 2: Rotation test suite
echo [2/3] Rotation test suite...
"%LUA_EXE%" EaxRotations\tests\run_rotation_tests.lua
if !errorlevel! neq 0 (
    echo   FAIL: rotation tests
    set EXIT_CODE=1
) else (
    echo   PASS: rotation tests
)
echo.

REM Step 3: Leveling test suite
echo [3/3] Leveling test suite...
"%LUA_EXE%" EaxRotations\tests\run_leveling_tests.lua
if !errorlevel! neq 0 (
    echo   FAIL: leveling tests
    set EXIT_CODE=1
) else (
    echo   PASS: leveling tests
)
echo.

REM Bonus: Sylvanas audit (spell ID verification)
echo [Bonus] Spell audit...
"%LUA_EXE%" EaxRotations\tests\run_sylvanas_audit_tests.lua
if !errorlevel! neq 0 (
    echo   WARN: spell audit failures (check output)
) else (
    echo   PASS: spell audit
)
echo.

echo ============================================
if !EXIT_CODE! equ 0 (
    echo  ALL CHECKS PASSED
) else (
    echo  VALIDATION FAILED
)
echo ============================================

exit /b !EXIT_CODE!
