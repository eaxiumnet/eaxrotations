-- run_dead_matcher_audit_tests.lua -- Static audit: no strategy matcher may be
-- defined but referenced by zero strategies.
-- WHAT:  Scans every class file (sylvanas / vanilla / wotlk / leveling) for
--        matcher definitions (functions whose name ends in `_matches`, the
--        repo's matcher naming convention) and fails if any is defined but
--        never referenced — a dead matcher is unreachable code that can
--        silently carry stale spell IDs / conditions a maintainer assumes
--        are live (the survey's mage/dps_mage_sod.lua lead turned out to be
--        a naive-scanner false positive: the wrapper form `matches =
--        function() return combat_action_matches(...) end` references the
--        name on a different line than `matches =`).
-- WHEN:  Run manually, in CI (verify_all), and in the pre-commit gate.
-- WHY:   A future spec copy could leave a matcher defined-but-unreferenced;
--        this audit mechanically covers every file so it is caught before
--        it ships.
-- SAFETY: Read-only text scan + static classification; --self-test has no
--        filesystem writes (synthetic in-memory content only).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local CLASS_ROOT = "EaxRotations/classes"

-- ---------------------------------------------------------------------------
-- Comment stripping: replace comment text with same-length spaces so line
-- positions survive and comment/string text can never count as a reference.
-- Handles line comments (--) and block comments (--[[ ]], --[=[ ]=], ...)
-- at any level. Pragmatic: a `--` inside a string literal is treated as a
-- comment opener, which can only cause FALSE NEGATIVES (missed dead code),
-- never false positives — the safe failure direction for a blocker audit.
-- ---------------------------------------------------------------------------
local function strip_comments(content)
    local pieces = {}
    local pos = 1
    local len = #content
    while pos <= len do
        local s = content:find("%-%-", pos)
        if not s then
            pieces[#pieces + 1] = content:sub(pos)
            break
        end
        pieces[#pieces + 1] = content:sub(pos, s - 1)
        local eq = content:match("^%-%-%[(=*)%[", s)
        if eq then
            -- block comment at level #eq: blank until the matching ]=]
            local close = content:find("%]" .. eq .. "%]", s + 3 + #eq)
            if close then
                pieces[#pieces + 1] = content:sub(s, close + #eq + 1):gsub(".", " ")
                pos = close + #eq + 2
            else
                pieces[#pieces + 1] = content:sub(s):gsub(".", " ")
                pos = len + 1
            end
        else
            -- line comment: blank to end of line
            local nl = content:find("\n", s + 2)
            if nl then
                pieces[#pieces + 1] = content:sub(s, nl - 1):gsub(".", " ")
                pos = nl
            else
                pieces[#pieces + 1] = content:sub(s):gsub(".", " ")
                pos = len + 1
            end
        end
    end
    return table.concat(pieces)
end

-- ---------------------------------------------------------------------------
-- Core scan: content -> { defs = { {name, line} }, counts = { name -> n } }
-- Definitions recognized (each contributes exactly ONE token of its name):
--   local function NAME(
--   local NAME = function
--   NAME = function                     (module-level; field forms like M.x /
--                                        self.x are excluded by the anchor)
-- Only names ending in `_matches` are matcher definitions; every other
-- identifier occurrence in the comment-stripped content is a reference.
-- A matcher is dead iff count(name) == defs(name) (zero references outside
-- its own definition lines).
-- ---------------------------------------------------------------------------
local function scan_content(content)
    if type(content) ~= "string" then
        return { error = "content must be a string", defs = {}, counts = {} }
    end
    local stripped = strip_comments(content)

    -- Version-stable line split (same convention as the cache-hit audit):
    -- (.-)\n terminates each line deterministically in Lua 5.1 and 5.4.
    local lines = {}
    if stripped:sub(-1) == "\n" then stripped = stripped:sub(1, -2) end
    for line in (stripped .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line:gsub("\r$", "")
    end

    local defs = {}
    for i = 1, #lines do
        local line = lines[i]
        local name = line:match("^%s*local%s+function%s+([%a_][%w_]*)%s*%(")
            or line:match("^%s*local%s+([%a_][%w_]*)%s*=%s*function")
        if not name then
            -- Module-level `NAME = function` (global convention). A table-field
            -- assignment (`custom_matches = function(...) end,`) ends with `,`
            -- or `}`; a top-level statement in Lua can NEVER end with either,
            -- so trailing `,`/`}` exactly distinguishes fields from defs.
            if not line:match("[,}]%s*$") then
                name = line:match("^%s*([%a_][%w_]*)%s*=%s*function")
            end
        end
        if name and name:sub(-8) == "_matches" then
            defs[#defs + 1] = { name = name, line = i }
        end
    end

    local counts = {}
    for token in stripped:gmatch("[%a_][%w_]*") do
        if token:sub(-8) == "_matches" then
            counts[token] = (counts[token] or 0) + 1
        end
    end
    -- Per-name definition count: dead iff total tokens == definition tokens
    -- (zero references outside definition lines). Correct for names defined
    -- multiple times (a single def contributes exactly one token).
    local def_counts = {}
    for _, d in ipairs(defs) do
        def_counts[d.name] = (def_counts[d.name] or 0) + 1
    end
    return { defs = defs, counts = counts, def_counts = def_counts }
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
    local total_files = 0
    local total_matchers = 0
    for _, rel in ipairs(files) do
        local res = scan_file(rel)
        if not res.skipped and #res.defs > 0 then
            total_files = total_files + 1
            total_matchers = total_matchers + #res.defs
        end
        results[#results + 1] = { rel = rel, res = res }
    end
    return { results = results, total_files = total_files, total_matchers = total_matchers }
end

-- dead list: { {file, line, name} }
local function dead_matchers(res)
    local dead = {}
    for _, d in ipairs(res.defs) do
        local count = res.counts[d.name] or 0
        local defs_n = res.def_counts[d.name] or 1
        if count <= defs_n then
            dead[#dead + 1] = { line = d.line, name = d.name }
        end
    end
    return dead
end

-- ---------------------------------------------------------------------------
-- Self-tests (non-vacuity): every definition/reference style resolves
-- correctly. Synthetic in-memory fixtures only.
-- ---------------------------------------------------------------------------
local function run_self_tests()
    local function expect(actual, expected, label)
        if actual ~= expected then
            error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
        end
    end

    expect(scan_content(nil).error, "content must be a string", "malformed nil content")
    expect(scan_content(123).error, "content must be a string", "malformed numeric content")
    expect(scan_file("__missing_dead_matcher_fixture__.lua").skipped, true, "missing fixture")

    -- Style 1: `local function NAME(` + direct reference -> live.
    local direct = scan_content(
        "local function stealth_matches(context)\n    return context.is_stealthed\nend\n"
        .. "local STRATEGIES = {\n    { name = 'Stealth', matches = stealth_matches },\n}\n")
    expect(#direct.defs, 1, "local function def found")
    expect(direct.defs[1].name, "stealth_matches", "def name")
    expect(#dead_matchers(direct), 0, "direct reference is live")

    -- Style 2: `local NAME = function` + wrapper reference (the
    -- combat_action_matches false-positive shape) -> live.
    local wrap = scan_content(
        "local combat_action_matches = function(context, descriptor)\n    return true\nend\n"
        .. "    matches = function(context) return combat_action_matches(context, ACTION.Evocation) end,\n")
    expect(#wrap.defs, 1, "local = function def found")
    expect(#dead_matchers(wrap), 0, "wrapper reference is live")

    -- Style 3: module-level `NAME = function` (global convention) -> def found.
    local mod = scan_content("stealth_matches = function(context)\n    return false\nend\n")
    expect(#mod.defs, 1, "module-level def found")
    expect(#dead_matchers(mod), 1, "module-level def with no ref is dead")

    -- Style 4: custom_matches wrapper (warlock destruction shape) -> live.
    local custom = scan_content(
        "local function backlash_matches(context, action, state)\n    return true\nend\n"
        .. "        custom_matches = function(context, state) return backlash_matches(context, action, state) end,\n")
    expect(#dead_matchers(custom), 0, "custom_matches wrapper is live")

    -- Style 5: alias reference `local m = NAME` -> live.
    local alias = scan_content(
        "local function fade_matches(context)\n    return true\nend\n"
        .. "local m = fade_matches\n    matches = m,\n")
    expect(#dead_matchers(alias), 0, "alias reference is live")

    -- Style 6: truly dead matcher -> flagged.
    local dead = scan_content(
        "local function orphan_matches(context)\n    return context.in_combat\nend\n"
        .. "local STRATEGIES = {\n    { name = 'Other', matches = function() return true end },\n}\n")
    expect(#dead_matchers(dead), 1, "unreferenced matcher is dead")
    expect(dead_matchers(dead)[1].name, "orphan_matches", "dead matcher name")

    -- Style 7: comment text must NOT count as a reference (dead stays dead).
    local commented = scan_content(
        "local function orphan_matches(context)\n    return true\nend\n"
        .. "-- orphan_matches used to be referenced here; strategy removed\n")
    expect(#dead_matchers(commented), 1, "line-comment mention is not a reference")

    -- Style 8: block comment must not count as a reference.
    local block = scan_content(
        "local function orphan_matches(context)\n    return true\nend\n"
        .. "--[[\norphan_matches is documented in this block\n]]\n")
    expect(#dead_matchers(block), 1, "block-comment mention is not a reference")

    -- Style 9: non-matcher helpers (no `_matches` suffix) are out of scope
    -- even if unreferenced.
    local helper = scan_content(
        "local function internal_helper(context)\n    return 42\nend\n")
    expect(#helper.defs, 0, "non-matcher def not counted")

    -- Style 10: field/table assignment forms (M.x = function, self.x =
    -- function) are NOT matcher definitions.
    local field = scan_content(
        "M.stealth_matches = function(self, ctx)\n    return false\nend\n"
        .. "self.custom_matches = function(context) return true end\n")
    expect(#field.defs, 0, "field assignments are not defs")

    -- Real-file probe: the survey lead resolves LIVE through its wrapper
    -- references (dps_mage_sod.lua lines 40/52).
    local real = scan_file("mage/dps_mage_sod.lua")
    expect(real.skipped, nil, "dps_mage_sod.lua exists")
    expect(#dead_matchers(real), 0, "combat_action_matches is live (wrapper refs resolve)")

    -- Real-file probe 2: the DSL-substitution orphan class was swept —
    -- bear_sylvanas (the file with the most orphans: 7 matchers + 2 execute
    -- twins) must now report ZERO dead matchers, pinning the cleanup.
    local bear = scan_file("druid/bear_sylvanas.lua")
    expect(bear.skipped, nil, "bear_sylvanas.lua exists")
    expect(#dead_matchers(bear), 0, "bear_sylvanas has zero dead matchers (orphans removed)")

    print("[PASS] Dead-matcher audit self-tests: def styles (local function / "
        .. "local = / module-level), ref styles (direct / wrapper / custom_matches "
        .. "/ alias), dead detection, line+block comment exclusion, non-matcher "
        .. "and field-assignment scope, real-file wrapper probe")
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
print("  DEAD-MATCHER AUDIT (defined but unreferenced strategy matchers)")
print("=============================================================================")
local failures = {}
local clean = 0
for _, entry in ipairs(scan.results) do
    local res = entry.res
    if not res.skipped and #res.defs > 0 then
        local dead = dead_matchers(res)
        if #dead == 0 then
            clean = clean + 1
            print(string.format("  [ PASS ]  %-46s %d matcher%s, 0 dead", entry.rel,
                #res.defs, (#res.defs == 1 and "" or "s")))
        else
            for _, d in ipairs(dead) do
                failures[#failures + 1] = { file = entry.rel, line = d.line, name = d.name }
            end
        end
    end
end
print("=============================================================================")
print(string.format("  Total:     %d matcher-bearing files (%d matchers)", scan.total_files, scan.total_matchers))
print(string.format("  Clean:     %d", clean))
print(string.format("  Invalid:   %d", #failures))
print("=============================================================================")

if #failures > 0 then
    print("  Matchers defined but referenced by no strategy:")
    for _, f in ipairs(failures) do
        print(string.format("    %s  line %d: %s", f.file, f.line, f.name))
    end
    print("")
    print("  Fix: remove the dead matcher (and its unreachable strategy), or wire")
    print("  it into a strategy so the name is referenced. If a finding is a false")
    print("  positive, refine the resolver in this file — do not suppress findings.")
    os.exit(1)
end

print("  Every defined matcher is referenced by at least one strategy.")
os.exit(0)
