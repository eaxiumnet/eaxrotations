@echo off
rem EAX Profession DBC Extraction Pipeline
rem ======================================
rem Extracts profession spell data from all installed WoW clients.
rem Run this after installing new WoW expansion clients.
rem
rem Prerequisites:
rem   - .NET SDK (for DB2ToSqlite)
rem   - Python 3 (for extract_from_dbc.py)
rem   - WoW clients installed via Battle.net
rem
rem Outputs:
rem   - wowheadScrape/dbc_extract/wowsims_<expansion>.db
rem   - EaxProfessions/data/profession_spell_ids_<expansion>.json
rem   - EaxProfessions/data/profession_spell_ids_<expansion>.lua

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."
set "DB2TOSQLITE=%REPO_ROOT%\tbc-new\tools\DB2ToSqlite"
set "EXTRACTOR=%REPO_ROOT%\build_tools\profession_spell_ids\extract_from_dbc.py"
set "OUT_DB=%REPO_ROOT%\wowheadScrape\dbc_extract"
set "OUT_DATA=%REPO_ROOT%\EaxProfessions\data"

echo ==========================================
echo EAX Profession DBC Extraction Pipeline
echo ==========================================
echo.

if not exist "%OUT_DATA%" mkdir "%OUT_DATA%"

rem ---------------------------------------------------------------------------
rem Classic Era (Vanilla / SoD)
rem Product: wow_classic_era
rem ---------------------------------------------------------------------------
if exist "%DB2TOSQLITE%\appsettings.classic_era.json" (
    echo [1/4] Extracting Classic Era...
    dotnet run --project "%DB2TOSQLITE%\DB2ToSqliteTool.csproj" --configuration Release -- -c "%DB2TOSQLITE%\appsettings.classic_era.json"
    if exist "%OUT_DB%\wowsims_classic_era.db" (
        python "%EXTRACTOR%" --db "%OUT_DB%\wowsims_classic_era.db" --expansion classic_era --out-dir "%OUT_DATA%"
    )
    echo.
)

rem ---------------------------------------------------------------------------
rem TBC Classic Anniversary
rem Product: wow_anniversary
rem ---------------------------------------------------------------------------
if exist "%DB2TOSQLITE%\appsettings.json" (
    echo [2/4] Extracting TBC Classic...
    dotnet run --project "%DB2TOSQLITE%\DB2ToSqliteTool.csproj" --configuration Release -- -c "%DB2TOSQLITE%\appsettings.json"
    if exist "%OUT_DB%\wowsims.db" (
        python "%EXTRACTOR%" --db "%OUT_DB%\wowsims.db" --expansion tbc --out-dir "%OUT_DATA%"
    )
    echo.
)

rem ---------------------------------------------------------------------------
rem MoP Classic
rem Product: wow_classic
rem ---------------------------------------------------------------------------
if exist "%DB2TOSQLITE%\appsettings.mop_classic.json" (
    echo [3/4] Extracting MoP Classic...
    dotnet run --project "%DB2TOSQLITE%\DB2ToSqliteTool.csproj" --configuration Release -- -c "%DB2TOSQLITE%\appsettings.mop_classic.json"
    if exist "%OUT_DB%\wowsims_mop_classic.db" (
        python "%EXTRACTOR%" --db "%OUT_DB%\wowsims_mop_classic.db" --expansion mop --out-dir "%OUT_DATA%"
    )
    echo.
)

rem ---------------------------------------------------------------------------
rem Retail (TWW)
rem Product: wow
rem ---------------------------------------------------------------------------
if exist "%DB2TOSQLITE%\appsettings.retail.json" (
    echo [4/4] Extracting Retail...
    dotnet run --project "%DB2TOSQLITE%\DB2ToSqliteTool.csproj" --configuration Release -- -c "%DB2TOSQLITE%\appsettings.retail.json"
    if exist "%OUT_DB%\wowsims_retail.db" (
        python "%EXTRACTOR%" --db "%OUT_DB%\wowsims_retail.db" --expansion retail --out-dir "%OUT_DATA%"
    )
    echo.
)

echo ==========================================
echo Extraction complete!
echo Output: %OUT_DATA%
echo ==========================================

endlocal
pause
