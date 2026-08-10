-- run_cache_hit_audit_tests.lua -- Static audit: every frame-cache build_state
-- must wrap its cache-hit return in spec_kit.safe_state(...).
-- WHAT:  Scans every class file (sylvanas / vanilla / wotlk / leveling) for
--        frame-cache guards (`_last_build_time` / `_last_build_state_time`
--        style, any variable starting with `_last_build`) and fails if any
--        cache-hit return branch returns the RAW state table instead of
--        spec_kit.safe_state(...). This enforces the invariant behind the
--        bear/cat nil-guard bypass fix (6abb9039): a cache-hit return that
--        skips safe_state lets nil-guard defaults leak as nil in live play.
-- WHEN:  Run manually, in CI (verify_all), and in the pre-commit gate.
-- WHY:   test_cache_hit_nil_guard_regression.lua guards the SEMANTICS for
--        bear/cat only; this audit mechanically covers every file so a new
--        spec copying the frame-cache pattern without the wrap is caught
--        before it ships.
-- SAFETY: Read-only text scan + static classification; --self-test has no
--        filesystem writes (synthetic in-memory content only).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local CLASS_ROOT = "EaxRotations/classes"

-- ---------------------------------------------------------------------------
-- Core scan: one file's content -> { violations = { {line, text} }, branches = n }
-- ---------------------------------------------------------------------------
local function scan_content(content)
    if type(content) ~= "string" then
        return { error = "content must be a string", violations = {}, branches = 0 }
    end
    local violations = {}
    local branches = 0
    -- Version-stable line split: gmatch("[^\r\n]*") emits interleaved EMPTY
    -- matches under Lua 5.1 (the pinned pre-commit interpreter) but not 5.4,
    -- which shifts every subsequent line index and silently breaks the
    -- block-form lookahead. (.-)\n terminates each line deterministically in
    -- both versions; strip \r so \r\n files report clean line text.
    local lines = {}
    if content:sub(-1) == "\n" then content = content:sub(1, -2) end
    for line in (content .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line:gsub("\r$", "")
    end
    for i = 1, #lines do
        local line = lines[i]
        -- Guard line: inline form `if now and now == _last_build_X then return ... end`
        if line:find("_last_build", 1, true) and line:find("return", 1, true) then
            branches = branches + 1
            if not line:find("spec_kit.safe_state", 1, true) then
                violations[#violations + 1] = { line = i, text = line }
            end
        -- Block form: guard opens with `then`, return on the next line.
        elseif line:find("_last_build", 1, true) and line:find("then", 1, true) then
            local next_line = lines[i + 1] or ""
            local trimmed = next_line:gsub("^%s+", "")
            if trimmed:find("^return", 1) then
                branches = branches + 1
                if not next_line:find("spec_kit.safe_state", 1, true) then
                    violations[#violations + 1] = { line = i + 1, text = next_line }
                end
            end
        end
    end
    return { violations = violations, branches = branches }
end

-- ---------------------------------------------------------------------------
-- File scan: relative path under classes/ -> skipped flag or result
-- ---------------------------------------------------------------------------
local function scan_file(rel_path)
    local f = io.open(CLASS_ROOT .. "/" .. rel_path, "rb")
    if not f then return { skipped = true } end
    local content = f:read("*a")
    f:close()
    local res = scan_content(content)
    res.file = rel_path
    return res
end

-- ---------------------------------------------------------------------------
-- Full scan: every .lua under classes/ (all eras + leveling)
-- ---------------------------------------------------------------------------
local function run_scan()
    local pipe = io.popen("find " .. CLASS_ROOT .. " -name '*.lua'")
    local files = {}
    for line in pipe:lines() do
        local rel = line:gsub("^" .. CLASS_ROOT .. "/", ""):gsub("\\", "/")
        files[#files + 1] = rel
    end
    pipe:close()
    table.sort(files)

    local results = {}
    local total_branches = 0
    local cache_files = 0
    for _, rel in ipairs(files) do
        local res = scan_file(rel)
        if not res.skipped and res.branches > 0 then
            cache_files = cache_files + 1
            total_branches = total_branches + res.branches
        end
        results[#results + 1] = { rel = rel, res = res }
    end
    return { results = results, cache_files = cache_files, total_branches = total_branches }
end

-- ---------------------------------------------------------------------------
-- Self-tests (non-vacuity): assert the detector fires on synthetic violations.
-- ---------------------------------------------------------------------------
local function run_self_tests()
    local function expect(actual, expected, label)
        if actual ~= expected then
            error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
        end
    end

    expect(scan_content(nil).error, "content must be a string", "malformed nil content")
    expect(scan_content(123).error, "content must be a string", "malformed numeric content")
    expect(scan_file("__missing_cache_hit_fixture__.lua").skipped, true, "missing fixture")

    -- Clean: inline wrapped return (the fixed convention, bear_sylvanas:369 style).
    local clean = scan_content(
        "local function build_state(context)\n"
        .. "    local now = context.now\n"
        .. "    if now and now == _last_build_time then return spec_kit.safe_state(state, SCHEMA) end\n"
        .. "    return spec_kit.safe_state(state, SCHEMA)\n"
        .. "end\n")
    expect(#clean.violations, 0, "inline wrapped cache-hit is clean")
    expect(clean.branches, 1, "inline wrapped counts one branch")

    -- Violation: raw inline return (the bear/cat bug shape).
    local raw = scan_content(
        "    if now and now == _last_build_state_time then return state end\n")
    expect(#raw.violations, 1, "raw inline cache-hit is flagged")
    expect(raw.violations[1].line, 1, "raw inline violation line number")

    -- Violation: raw block-form return on the next line.
    local raw_block = scan_content(
        "local function build_state(context)\n"
        .. "    if now == _last_build_state_time then\n"
        .. "        return st\n"
        .. "    end\n"
        .. "end\n")
    expect(#raw_block.violations, 1, "raw block-form cache-hit is flagged")
    expect(raw_block.violations[1].line, 3, "raw block violation line number")

    -- Clean: wrapped block form.
    local wrap_block = scan_content(
        "    if now == _last_build_state_time then\n"
        .. "        return spec_kit.safe_state(st, SCHEMA)\n"
        .. "    end\n")
    expect(#wrap_block.violations, 0, "wrapped block-form cache-hit is clean")
    expect(wrap_block.branches, 1, "wrapped block counts one branch")

    -- Declaration/assignment lines must NOT be counted as branches or flagged.
    local decl = scan_content(
        "local _last_build_state_time = -1\n"
        .. "    if context.now then _last_build_state_time = now end\n")
    expect(#decl.violations, 0, "declaration/assignment lines are ignored")
    expect(decl.branches, 0, "declaration/assignment lines are not branches")

    -- Real-file probe: a known good cache-bearing file passes end-to-end.
    local real = scan_file("druid/bear_sylvanas.lua")
    expect(real.skipped, nil, "bear_sylvanas.lua exists")
    expect(#real.violations, 0, "bear_sylvanas.lua cache-hit is wrapped")
    expect(real.branches >= 1, true, "bear_sylvanas.lua has a frame-cache branch")

    print("[PASS] Cache-hit audit self-tests: malformed input, inline + block-form "
        .. "raw returns flagged, wrapped forms clean, decl lines ignored, real-file probe")
    os.exit(0)
end

-- ---------------------------------------------------------------------------
-- CLI
-- ---------------------------------------------------------------------------
if arg and arg[1] == "--self-test" then
    run_self_tests()
end

local scan = run_scan()

print("=============================================================================")
print("  CACHE-HIT SAFE_STATE AUDIT (frame-cache nil-guard invariant)")
print("=============================================================================")
local failures = {}
local clean = 0
for _, entry in ipairs(scan.results) do
    local res = entry.res
    if res.branches and res.branches > 0 then
        if #res.violations == 0 then
            clean = clean + 1
            print(string.format("  [ PASS ]  %-46s %d branch%s wrapped", entry.rel,
                res.branches, (res.branches == 1 and "" or "es")))
        else
            for _, v in ipairs(res.violations) do
                failures[#failures + 1] = { file = entry.rel, line = v.line, text = v.text }
            end
        end
    end
end
print("=============================================================================")
print(string.format("  Total:     %d cache-bearing files (%d cache-hit branches)",
    scan.cache_files, scan.total_branches))
print(string.format("  Clean:     %d", clean))
print(string.format("  Invalid:   %d", #failures))
print("=============================================================================")

if #failures > 0 then
    print("  Cache-hit returns that bypass spec_kit.safe_state (nil-guard leak):")
    for _, f in ipairs(failures) do
        print(string.format("    %s  line %d: %s", f.file, f.line, f.text))
    end
    print("")
    print("  Fix: wrap the cache-hit branch in spec_kit.safe_state(state, <SCHEMA>)")
    print("  exactly like bear_sylvanas.lua:369 / arms_sylvanas.lua:379.")
    os.exit(1)
end

print("  Every frame-cache build_state wraps its cache-hit return in safe_state.")
os.exit(0)
