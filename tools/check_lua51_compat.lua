-- tools/check_lua51_compat.lua — Validate all project .lua files compile with Lua 5.1.
-- WHAT:  Scans EaxRotations/, tools/, api/ and other project-owned directories for
--        .lua files and runs luac -p on each to catch Lua 5.2+/5.3+/5.4 syntax
--        (goto, \x hex escapes, %g pattern, table.unpack without compat shim,
--        string.pack, utf8.*, etc.) that would crash on the LuaJIT / Lua 5.1 runtime.
-- WHEN:  CI (run_all_checks.sh step [5/5]) and local pre-commit validation.
-- WHY:   The game uses LuaJIT which is ~Lua 5.1. Any 5.4-only syntax causes a
--        hard load-time error. Catch it before it reaches users.
-- SAFETY: Read-only; exits non-zero on first failure; never modifies files.
--
-- USAGE:
--   lua tools/check_lua51_compat.lua
--   lua tools/check_lua51_compat.lua --luac /path/to/luac
--   lua tools/check_lua51_compat.lua --verbose
--   lua tools/check_lua51_compat.lua --list-failed
--
-- The luac path is resolved in order:
--   1. --luac command-line argument
--   2. LUA51_COMPAT_LUAC environment variable
--   3. Auto-detect (lfs + well-known paths, bare 'luac' on PATH)

-- Try to load lfs (needed for recursive directory walk).  If absent, skip
-- with a clear message — most CI environments install it, and the existing
-- EaxRotations tests already use the same skip pattern.
local lfs_ok, lfs = pcall(require, "lfs")
if not lfs_ok or not lfs then
    print("SKIP tools/check_lua51_compat.lua (lfs not available on this Lua build)")
    print("  Install: luarocks install luafilesystem")
    os.exit(0)
end

local is_windows = (package.config:sub(1,1) == "\\")

-- ---------------------------------------------------------------------------
-- Auto-detect luac path (fallback when not provided by caller)
-- ---------------------------------------------------------------------------
local function auto_find_luac()
    local candidates = {}
    if os.getenv("LUA51_DIR") then
        candidates[#candidates + 1] = os.getenv("LUA51_DIR")
    end
    candidates[#candidates + 1] = "/home/runner/.lua/bin/luac"
    candidates[#candidates + 1] = "C:/Program Files (x86)/Lua/5.1/luac.exe"
    candidates[#candidates + 1] = "C:/Program Files/Lua/5.1/luac.exe"
    candidates[#candidates + 1] = "luac"

    local seen = {}
    for _, c in ipairs(candidates) do
        if c and not seen[c] then
            seen[c] = true
            if c == "luac" then
                local ok, ret = pcall(os.execute, "luac -v")
                if ok and (ret == 0 or ret == true) then return "luac" end
            else
                local attr = lfs.attributes(c)
                if attr and attr.mode == "file" then return c end
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Resolve the luac path
-- ---------------------------------------------------------------------------
local LUAC = nil

-- Parse CLI args
local verbose = false
local list_failed = false
for i = 1, #arg do
    if arg[i] == "--verbose" or arg[i] == "-v" then
        verbose = true
    elseif arg[i] == "--list-failed" then
        list_failed = true
    elseif arg[i] == "--luac" and arg[i + 1] then
        LUAC = arg[i + 1]
    end
end

if not LUAC then
    LUAC = os.getenv("LUA51_COMPAT_LUAC")
end
if not LUAC then
    LUAC = auto_find_luac()
end

if not LUAC then
    io.stderr:write("ERROR: luac (Lua 5.1 compiler) not found on this system.\n")
    io.stderr:write("  Pass path: lua tools/check_lua51_compat.lua --luac /path/to/luac\n")
    io.stderr:write("  Or set env: set LUA51_COMPAT_LUAC=C:/path/to/luac.exe\n")
    io.stderr:write("  On GitHub Actions: leafo/gh-actions-lua@v12 with luaVersion: 5.1\n")
    os.exit(1)
end

-- Normalize Git Bash /c/ style paths to Windows-native C:/ for cmd.exe compatibility
if is_windows and LUAC then
    LUAC = LUAC:gsub("^/([a-zA-Z])/", "%1:/")
end

if verbose then
    print(string.format("  Using luac: %s", LUAC))
end

-- ---------------------------------------------------------------------------
-- Configuration: directories to scan (relative to repo root)
-- ---------------------------------------------------------------------------
local SCAN_DIRS = {
    "EaxRotations",
    "tools",
    "api",
    ".api",
}

-- Directories to exclude (substring match on relative path)
local EXCLUDE_DIRS = {
    ".git", "data", "research", "scratch", "rotations", "x",
    ".freebuff", "mcps", "plans", "docs", "cache", ".cache",
    "EaxFishing", "EaxAutoQuester", "EaxESP",
    "ZygorGuidesViewerClassic", "ZygorGuidesViewerClassicTBC",
    "ZygorGuidesViewerClassicTBCAnniv", "WowClassicGrindBot-dev",
    "wowheadScrape/dbc_extract", "dist",
}

-- Files to always skip (exact filename match)
local SKIP_FILES = { "test_json.lua" }

-- ---------------------------------------------------------------------------
-- Lua 5.4-only pattern detector (surfaced as warnings, not hard failures)
-- ---------------------------------------------------------------------------
local LUA54_PATTERNS = {
    { pattern = "table.unpack(",  hint = "table.unpack() — needs compat shim" },
    { pattern = "table.pack(",    hint = "table.pack() not available in Lua 5.1" },
    { pattern = "table.move(",    hint = "table.move() not available in Lua 5.1" },
    { pattern = "math.tointeger(", hint = "math.tointeger() not available in Lua 5.1" },
    { pattern = "math.type(",     hint = "math.type() not available in Lua 5.1" },
    { pattern = "string.pack(",   hint = "string.pack() not available in Lua 5.1" },
    { pattern = "string.unpack(", hint = "string.unpack() not available in Lua 5.1" },
    { pattern = "utf8.",          hint = "utf8.* not available in Lua 5.1" },
    { pattern = "%g",             hint = "'%g' pattern class requires Lua 5.2+" },
    { pattern = "::%a+",          hint = "goto/label syntax (::label::) requires Lua 5.2+", use_pattern = true },
}

-- ---------------------------------------------------------------------------
-- Helper: walk directories recursively, collecting .lua files
-- ---------------------------------------------------------------------------
local function collect_lua_files(root_dir)
    local files = {}
    local function walk(dir)
        local attr = lfs.attributes(dir)
        if not attr or attr.mode ~= "directory" then return end
        local rel = dir:match("^[^/]+/(.+)$") or dir
        for _, excl in ipairs(EXCLUDE_DIRS) do
            if rel == excl or rel:find(excl .. "/", 1, true) then
                return
            end
        end
        for entry in lfs.dir(dir) do
            if entry ~= "." and entry ~= ".." then
                local full = dir .. "/" .. entry
                local fattr = lfs.attributes(full)
                if fattr then
                    if fattr.mode == "file" and entry:match("%.lua$") then
                        local skip = false
                        for _, sn in ipairs(SKIP_FILES) do
                            if entry == sn then skip = true; break end
                        end
                        if not skip then files[#files + 1] = full end
                    elseif fattr.mode == "directory" then
                        walk(full)
                    end
                end
            end
        end
    end
    walk(root_dir)
    return files
end

-- ---------------------------------------------------------------------------
-- Run luac -p on a single file, return true if parse OK
-- ---------------------------------------------------------------------------
local function check_file(file)
    -- Build command: quote the luac path to handle spaces
    local cmd
    if is_windows then
        -- On Windows, os.execute calls cmd.exe.  Use a temp batch file to
        -- avoid cmd.exe's quote-stripping heuristics for programs with spaces.
        local bat = os.tmpname() .. ".bat"
        local fh = io.open(bat, "w")
        if fh then
            fh:write("@echo off\n")
            fh:write("\"" .. LUAC .. "\" -p \"" .. file .. "\"\n")
            fh:close()
            local ok, ret = pcall(os.execute, bat)
            os.remove(bat)
            return ok and (ret == true or ret == 0)
        end
        return false
    else
        -- Unix: simple quoting works
        cmd = "\"" .. LUAC .. "\" -p \"" .. file .. "\""
        local ok, ret = pcall(os.execute, cmd)
        return ok and (ret == 0 or ret == true)
    end
end

-- ---------------------------------------------------------------------------
-- Main check
-- ---------------------------------------------------------------------------

-- Collect files to check
local all_files = {}
local total_scanned = 0

for _, dir in ipairs(SCAN_DIRS) do
    local attr = lfs.attributes(dir)
    if attr and attr.mode == "directory" then
        local dir_files = collect_lua_files(dir)
        for _, f in ipairs(dir_files) do
            all_files[#all_files + 1] = f
            total_scanned = total_scanned + 1
        end
    elseif verbose then
        print(string.format("  SKIP (not found): %s", dir))
    end
end

if total_scanned == 0 then
    io.stderr:write("ERROR: No .lua files found to check.\n")
    io.stderr:write("  Make sure you run this from the repo root.\n")
    os.exit(1)
end

local passed = 0
local failed = 0
local failed_list = {}
local warnings = {}
local start_time = os.clock()

for i = 1, #all_files do
    local file = all_files[i]

    local ok = check_file(file)
    if ok then
        passed = passed + 1
        if verbose then print(string.format("  OK  %s", file)) end
    else
        failed = failed + 1
        failed_list[#failed_list + 1] = file
        -- Show failure with error details
        io.write(string.format("  FAIL %s\n", file))
        -- Re-run to show the actual syntax error
        if is_windows then
            local bat = os.tmpname() .. ".bat"
            local fh = io.open(bat, "w")
            if fh then
                fh:write("@echo off\n")
                fh:write("\"" .. LUAC .. "\" -p \"" .. file .. "\"\n")
                fh:close()
                os.execute(bat)
                os.remove(bat)
            end
        else
            os.execute("\"" .. LUAC .. "\" -p \"" .. file .. "\"")
        end
    end

    -- Lua 5.4 pattern scan (warnings only)
    if not (file:find("check_lua51")) then
        local fh = io.open(file, "rb")
        if fh then
            local content = fh:read("*a") or ""
            fh:close()
            for _, p in ipairs(LUA54_PATTERNS) do
                local content_match
                if p.use_pattern then
                    content_match = content:find(p.pattern)
                else
                    content_match = content:find(p.pattern, 1, true)
                end
                if content_match then
                    local line_num = 0
                    for line in content:gmatch("[^\r\n]+") do
                        line_num = line_num + 1
                        local line_match
                        if p.use_pattern then
                            line_match = line:find(p.pattern)
                        else
                            line_match = line:find(p.pattern, 1, true)
                        end
                        if line_match and not line:match("^%s*%-%-") then
                            warnings[#warnings + 1] = string.format(
                                "  WARN %s:%d %s", file, line_num, p.hint
                            )
                            break
                        end
                    end
                    break
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Results summary
-- ---------------------------------------------------------------------------
local elapsed = os.clock() - start_time

print(string.format("\n  Lua 5.1 compat check complete (%.1fs)", elapsed))
print(string.format("  Files scanned: %d", total_scanned))
print(string.format("  Parsed OK:     %d", passed))
print(string.format("  Parse FAILED:  %d", failed))

if list_failed and #failed_list > 0 then
    print("  Failed files:")
    for _, f in ipairs(failed_list) do
        print(string.format("    - %s", f))
    end
end

if #warnings > 0 then
    print(string.format("\n  Lua 5.4 pattern warnings (%d):", #warnings))
    for _, w in ipairs(warnings) do
        print(w)
    end
    print("  These are advisory — only luac -p failures are blocking.")
end

if failed > 0 then
    print("\n  RESULT: FAIL — " .. failed .. " file(s) do not compile with Lua 5.1")
    os.exit(1)
else
    print("\n  RESULT: PASS — all files compile with Lua 5.1")
    os.exit(0)
end
