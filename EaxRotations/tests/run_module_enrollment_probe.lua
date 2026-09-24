-- run_module_enrollment_probe.lua -- nested-runtime-module enrollment probe.
-- WHAT:  two scopes of shipped runtime module. Every .lua under shared/, and
--        every .lua nested under classes/<class>/<subdir>/ (the depth
--        behavioral_audit's one-level era-manifest scan cannot see), must be
--        git-TRACKED; the nested ones must additionally be required by a
--        tracked require()/dofile.
-- WHEN:  lua EaxRotations/tests/run_module_enrollment_probe.lua [--self-test]
-- WHY:   the release artifact is built with `git archive HEAD` filtered to
--        tracked lua/md (tools/create_release_zip.py) and CI pins the zip to
--        `git ls-files EaxRotations/`, so an UNTRACKED module is silently
--        dropped from what users download while every local gate stays green
--        (the already-confirmed composer defect class -- and that file lives
--        in shared/, not under a class). ENROLLED is the other half: a
--        committed-but-never-required module ships forever as dead weight, and
--        no manifest notices, because both era manifests only enumerate
--        *_<era>.lua files one level below classes/.
-- EXIT:  0 = every module tracked, and every nested one required ([PASS]);
--        1 = at least one finding (prints [FAIL] lines).
-- SAFETY: read-only over the tree + `git ls-files`. No writes, no mutation.
--         Named run_* so test_spec_layout_compliance's banned-API scan of
--         EaxRotations/tests/ exempts the io.popen call -- the same precedent
--         run_clean_checkout_probe.lua and run_verify_all.lua follow.

local lfs_ok, lfs = pcall(require, "lfs")

-- ---------------------------------------------------------------------------
-- 1. Tracked set (git index).
-- ---------------------------------------------------------------------------
-- `git ls-files` lists the INDEX, not HEAD, so a staged-but-not-yet-committed
-- file counts. That is deliberately the right bar for a commit gate: `git add
-- <new module>` in the same commit satisfies it, while forgetting the add
-- fails here instead of after the release zip drops the file.
local TRACKED = {}
local function load_tracked()
    -- No `2>/dev/null`: on Windows cmd.exe that redirect targets a literal
    -- file and popen fails, silently emptying the tracked set.
    local pipe = io.popen("git ls-files")
    if not pipe then return end
    for line in pipe:lines() do
        local p = line:gsub("\\", "/"):gsub("^%./", "")
        if p ~= "" then TRACKED[p] = true end
    end
    pipe:close()
end

local function is_tracked(path)
    return TRACKED[path] == true
end

-- ---------------------------------------------------------------------------
-- 2. Load literals -> the module name that matches the file-derived name.
-- ---------------------------------------------------------------------------
local function normalize_reference(literal)
    local p = literal:gsub("\\", "/")
    p = p:gsub("^%.%/", "")
    p = p:gsub("%.lua$", "")
    p = p:gsub("^EaxRotations/", "")
    return p
end

-- A module is loaded either by name (require) or by path (dofile) in this
-- tree, and the dominant idiom for an OPTIONAL module is pcall(require,
-- "shared/x") -- there the name is a bare argument, not a parenthesised call,
-- so a pattern accepting only require("x") silently misses it (that bug hid 59
-- of shared/'s 128 modules until it was measured). All four spellings normalize
-- through normalize_reference, so either form enrolls the same module.
local function collect_references(text)
    local names, seen = {}, {}
    for line in text:gmatch("[^\r\n]+") do
        if not line:match("^%s*%-%-") then
            for _, pattern in ipairs({
                'require%s*%(?%s*,?%s*"([^"]+)"',
                "require%s*%(?%s*,?%s*'([^']+)'",
                'dofile%s*%(?%s*,?%s*"([^"]+)"',
                "dofile%s*%(?%s*,?%s*'([^']+)'",
            }) do
                for literal in line:gmatch(pattern) do
                    local name = normalize_reference(literal)
                    if not seen[name] then
                        seen[name] = true
                        names[#names + 1] = name
                    end
                end
            end
        end
    end
    return names
end

-- ---------------------------------------------------------------------------
-- 3. Pure analyzer (no fs, no git) -- so --self-test can prove each rule fires.
-- ---------------------------------------------------------------------------
local function analyze(module_files, is_tracked_fn, required)
    local findings = {}
    for _, m in ipairs(module_files) do
        local name = m.path:gsub("^EaxRotations/", ""):gsub("%.lua$", "")
        if not is_tracked_fn(m.path) then
            findings[#findings + 1] = {
                kind = "UNTRACKED",
                subject = m.path,
                detail = "not in the git index -- `git add` it, or it is absent "
                    .. "from the release zip and from a clean checkout",
            }
        elseif m.enrolled and not required[name] then
            -- elseif, not a second if: an untracked module is reported once,
            -- as the more fundamental defect, and never also as unenrolled.
            findings[#findings + 1] = {
                kind = "UNENROLLED",
                subject = m.path,
                detail = "tracked but nothing loads it -- wire it up or delete it",
            }
        end
    end
    return findings
end

-- ---------------------------------------------------------------------------
-- 4. Real-tree collectors.
-- ---------------------------------------------------------------------------
local SHARED_ROOT = "EaxRotations/shared"
local CLASSES_ROOT = "EaxRotations/classes"

local function walk_lua(dir, out)
    for entry in lfs.dir(dir) do
        if entry ~= "." and entry ~= ".." then
            local full = dir .. "/" .. entry
            local attr = lfs.attributes(full)
            if attr and attr.mode == "file" and entry:match("%.lua$") then
                out[#out + 1] = full
            elseif attr and attr.mode == "directory" then
                walk_lua(full, out)
            end
        end
    end
end

-- Every shipped runtime module, tagged with whether the enrollment rule
-- applies to it.
--   shared/*.lua  -- flat, so every file there is a module: TRACKEDNESS only.
--     Enrollment is deliberately not asserted. This tree also loads shared
--     modules by dofile from untracked tools/ and reads the wowhead bridge from
--     the Python pipeline, so a static Lua scan cannot prove enrollment for the
--     directory: 8 of its 128 modules are invisible to one today, and reporting
--     those would bury the finding this gate exists for behind pre-existing
--     unknowns. The rule is pinned in --self-test so the limit stays deliberate.
--   classes/<class>/<subdir>/**/*.lua -- the depth no era manifest enumerates;
--     both rules, because the namespace is small and fully require-wired. The
--     top level of a class dir (the <spec>_<era>.lua files and the class_/
--     schema_/middleware_ helpers) stays excluded: one level, era suffixed, and
--     already manifest-checked by behavioral_audit.
local function collect_module_files()
    local files = {}
    local function add(root, enrolled)
        local found = {}
        walk_lua(root, found)
        for _, path in ipairs(found) do
            files[#files + 1] = { path = path, enrolled = enrolled }
        end
    end
    add(SHARED_ROOT, false)
    for class_key in lfs.dir(CLASSES_ROOT) do
        if class_key ~= "." and class_key ~= ".." then
            local class_dir = CLASSES_ROOT .. "/" .. class_key
            if lfs.attributes(class_dir).mode == "directory" then
                for sub in lfs.dir(class_dir) do
                    if sub ~= "." and sub ~= ".." then
                        local sub_dir = class_dir .. "/" .. sub
                        if lfs.attributes(sub_dir).mode == "directory" then
                            add(sub_dir, true)
                        end
                    end
                end
            end
        end
    end
    table.sort(files, function(a, b) return a.path < b.path end)
    return files
end

-- Every module name any tracked .lua loads. The loading file must itself be
-- tracked, so enrollment cannot be satisfied by something that would not ship.
local function collect_required_names()
    local required = {}
    local files = {}
    walk_lua("EaxRotations", files)
    local scanned = 0
    for _, path in ipairs(files) do
        -- Skip this probe's own file: its --self-test fixtures legitimately
        -- contain whole load statements for synthetic paths, and scanning them
        -- would enroll names no module has (the same self-exemption
        -- run_clean_checkout_probe.lua documents).
        if is_tracked(path) and not path:find("run_module_enrollment_probe%.lua$") then
            local f = io.open(path, "rb")
            if f then
                local text = f:read("*a") or ""
                f:close()
                for _, name in ipairs(collect_references(text)) do
                    required[name] = true
                end
                scanned = scanned + 1
            end
        end
    end
    return required, scanned
end

-- ---------------------------------------------------------------------------
-- 5. Self-test: prove every rule fires, offline and deterministic.
-- ---------------------------------------------------------------------------
local function run_self_tests()
    local function expect(cond, label)
        if not cond then
            error("run_module_enrollment_probe self-test: " .. label)
        end
    end

    local function kinds(findings)
        local seen = {}
        for _, f in ipairs(findings) do seen[f.kind] = (seen[f.kind] or 0) + 1 end
        return seen
    end

    local GATE = "EaxRotations/classes/priest/helpers/gate_sylvanas.lua"
    local GATE_NAME = "classes/priest/helpers/gate_sylvanas"
    local SHARED_MOD = "EaxRotations/shared/example_sylvanas.lua"
    local function tracked_fn(p) return p == GATE or p == SHARED_MOD end

    -- Clean: tracked, and loaded for the scope that requires it -> silent.
    expect(#analyze({ { path = GATE, enrolled = true },
                      { path = SHARED_MOD, enrolled = false } },
                    tracked_fn, { [GATE_NAME] = true }) == 0,
        "clean module set must produce no findings")

    -- UNTRACKED: the exact forgotten-`git add` shape, in both scopes.
    local untracked = analyze({ { path = GATE, enrolled = true },
                                { path = SHARED_MOD, enrolled = false } },
                              function() return false end,
                              { [GATE_NAME] = true })
    expect(kinds(untracked).UNTRACKED == 2,
        "an untracked module must fire UNTRACKED in both scopes")
    expect(kinds(untracked).UNENROLLED == nil,
        "an untracked-but-loaded module must not also report UNENROLLED")

    -- UNENROLLED: tracked, nothing loads it -- enrolled scope only.
    expect(kinds(analyze({ { path = GATE, enrolled = true } },
                        tracked_fn, {})).UNENROLLED == 1,
        "loaded-by-nothing must fire UNENROLLED")
    expect(kinds(analyze({ { path = SHARED_MOD, enrolled = false } },
                        tracked_fn, {})).UNENROLLED == nil,
        "shared/ is trackedness-only: no static Lua scan can prove its enrollment")

    -- Load-literal parsing: require("x"), require 'x', pcall(require, "x"),
    -- dofile("EaxRotations/.../x.lua"), and comment lines skipped.
    local parsed = collect_references([[
local a = require("classes/x/y/z")
local b = require 'classes/x/y/w.lua'
local ok, c = pcall(require, "shared/thing")
local d = dofile("EaxRotations/shared/e.lua")
-- require("classes/x/y/commented")
]])
    expect(#parsed == 4, "exactly four live loads must be parsed")
    expect(parsed[1] == "classes/x/y/z", 'require("x") must normalize')
    expect(parsed[2] == "classes/x/y/w", ".lua suffix must strip")
    expect(parsed[3] == "shared/thing", 'pcall(require, "x") must be seen')
    expect(parsed[4] == "shared/e", "dofile path must normalize to the module name")
    expect(#collect_references('-- require("classes/x/y/commented")') == 0,
        "commented load must not count as enrollment")

    print("[PASS] run_module_enrollment_probe self-tests: UNTRACKED fires in "
        .. "both scopes, UNENROLLED fires only for nested classes modules, a "
        .. "clean set stays silent, and load parsing covers require(\"x\"), "
        .. "require 'x', pcall(require, \"x\"), dofile paths and comments")
    return 0
end

-- ---------------------------------------------------------------------------
-- 6. Main scan
-- ---------------------------------------------------------------------------
local function main()
    if arg and arg[1] == "--self-test" then
        return run_self_tests()
    end
    if not lfs_ok or not lfs then
        -- Hard-fail (not SKIP): this probe is the enforcement gate for the
        -- untracked-module class, so it must never silently disappear on a box
        -- without lfs. CI installs luafilesystem via luarocks.
        print("FAIL run_module_enrollment_probe: lfs unavailable (install "
            .. "luafilesystem) -- cannot scan shared/ or classes/ for modules")
        return 1
    end
    load_tracked()

    local tracked_count = 0
    for _ in pairs(TRACKED) do tracked_count = tracked_count + 1 end
    if tracked_count == 0 then
        -- Fail-closed but legible: an empty tracked set means git ls-files
        -- yielded nothing (git not on PATH), so "untracked" would be
        -- meaningless and every module would false-flag.
        print("FAIL run_module_enrollment_probe: git ls-files returned no "
            .. "tracked files (git not on PATH?) -- cannot verify which "
            .. "modules ship")
        return 1
    end

    local module_files = collect_module_files()
    local required, scanned = collect_required_names()
    local findings = analyze(module_files, is_tracked, required)

    if #findings == 0 then
        local nested = 0
        for _, m in ipairs(module_files) do
            if m.enrolled then nested = nested + 1 end
        end
        print(string.format("module enrollment probe: %d module(s) tracked-checked "
            .. "(%d in shared/, %d nested under classes/<class>/), %d tracked "
            .. ".lua scanned for load enrollment -- all tracked, nested ones "
            .. "required", #module_files, #module_files - nested, nested, scanned))
        print("[PASS] run_module_enrollment_probe")
        return 0
    end

    print(string.format("FAIL: %d module finding(s) (a clean checkout or the "
        .. "release artifact would differ):", #findings))
    for _, f in ipairs(findings) do
        print(string.format("  [FAIL] %-12s %s -- %s", f.kind, f.subject,
                            f.detail))
    end
    print("  Fix: `git add` the module (it must be tracked to ship), or load it "
        .. "from a tracked file.")
    return 1
end

os.exit(main())
