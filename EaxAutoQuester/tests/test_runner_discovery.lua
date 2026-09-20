-- What: Guards the runner's suite discovery — a partial battery must be impossible.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: The runner used to fall back to a hand-kept list when luafilesystem was
--      missing; that list named fewer suites than the directory held, so it could
--      print a green total over a partial set. Discovery is now all-or-nothing:
--      every refusal below is asserted by reason, so deleting a guard fails here.
-- Safety: read-only. Fake lfs/read providers are injected, so the real directory,
--      the real manifest and the real module cache are never disturbed.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local test_runner = require("EaxAutoQuester/tests/test_runner_lib")

local function plugin_root()
    for _, prefix in ipairs({ "EaxAutoQuester/", "" }) do
        local f = io.open(prefix .. "tests/suite_manifest.lua", "r")
        if f then
            f:close()
            return prefix
        end
    end
    return nil
end

local ROOT = plugin_root()
assert(ROOT, "could not locate the plugin root (tests/suite_manifest.lua)")
local SUITES = ROOT .. "tests"

local manifest = select(1, test_runner.load_manifest(SUITES))
assert(type(manifest) == "table" and type(manifest.names) == "table", "manifest must load")

--- An lfs stand-in whose dir() iterates exactly `names`.
local function fake_lfs(names)
    return {
        dir = function(_dir)
            local i = 0
            return function()
                i = i + 1
                return names[i]
            end
        end,
    }
end

local function copy_names(extra, drop)
    local out = {}
    for _, name in ipairs(manifest.names) do
        if name ~= drop then out[#out + 1] = name end
    end
    if extra then out[#out + 1] = extra end
    return out
end

local function reason_for(opts)
    local names, reason = test_runner.discover_suites(SUITES, opts)
    return names, tostring(reason)
end

-- 1. No luafilesystem → refuse, and say how many suites could not be enumerated.
do
    local names, reason = reason_for({ lfs = false })
    assert(names == nil, "discovery without lfs must not return a suite list")
    assert(reason:find("luafilesystem unavailable", 1, true),
        "refusal must name the missing enumerator (got: " .. reason .. ")")
    assert(reason:find(tostring(manifest.count) .. " suites are listed", 1, true),
        "refusal must report the unenumerable count (got: " .. reason .. ")")
end

-- 2. A directory that enumerates to nothing → refuse rather than run zero suites.
do
    local names, reason = reason_for({ lfs = fake_lfs({}) })
    assert(names == nil, "an empty directory must not yield a green run")
    assert(reason:find("no suites found", 1, true),
        "empty directory refusal must say so (got: " .. reason .. ")")
end

-- 3. A suite on disk that the manifest does not list → refuse, naming it.
do
    local names, reason = reason_for({ lfs = fake_lfs(copy_names("test_zz_undeclared.lua")) })
    assert(names == nil, "an undeclared suite must not be run silently")
    assert(reason:find("drift", 1, true) and reason:find("test_zz_undeclared.lua", 1, true),
        "drift refusal must name the undeclared suite (got: " .. reason .. ")")
end

-- 4. A manifest entry missing from disk → refuse, naming it.
do
    local names, reason = reason_for({ lfs = fake_lfs(copy_names(nil, "test_loot_manager.lua")) })
    assert(names == nil, "a missing manifest entry must not be skipped silently")
    assert(reason:find("test_loot_manager.lua", 1, true),
        "drift refusal must name the missing suite (got: " .. reason .. ")")
end

-- 5. Unreadable, malformed and empty manifests → refuse.
do
    local names, reason = reason_for({ lfs = fake_lfs(manifest.names), read = function() return nil end })
    assert(names == nil and reason:find("manifest missing", 1, true),
        "an unreadable manifest must refuse (got: " .. reason .. ")")

    names, reason = reason_for({
        lfs = fake_lfs(manifest.names),
        read = function() return "return {\n" end,
    })
    assert(names == nil and reason:find("must contain a names", 1, true),
        "a manifest without a names block must refuse (got: " .. reason .. ")")

    names, reason = reason_for({
        lfs = fake_lfs(manifest.names),
        read = function() return "return { names = {} }\n" end,
    })
    assert(names == nil and reason:find("lists no suites", 1, true),
        "an empty manifest must refuse (got: " .. reason .. ")")
end

-- 6. The real environment: discovery returns every suite, and the manifest matches
--    the directory in both directions.
do
    local names, reason = test_runner.discover_suites(SUITES)
    assert(names, "real discovery must succeed (got: " .. tostring(reason) .. ")")
    assert(#names == manifest.count,
        "discovered " .. tostring(#names) .. " suites, manifest lists " .. tostring(manifest.count))
    for i = 2, #names do
        assert(names[i - 1] < names[i], "discovery must be sorted for a deterministic run")
    end
    for _, name in ipairs(names) do
        assert(manifest.set[name], name .. " is discovered but unlisted in the manifest")
        local f = io.open(SUITES .. "/" .. name, "r")
        assert(f, name .. " is discovered but missing on disk")
        f:close()
    end
end

-- 7. The runner itself holds no second, silent discovery path.
do
    local f = assert(io.open(ROOT .. "tests/run_quester_tests.lua", "r"))
    local src = f:read("*a")
    f:close()
    assert(src:find("discover_suites", 1, true), "the runner must discover through discover_suites")
    assert(not src:find("known_tests", 1, true),
        "the runner must not keep a hardcoded fallback suite list")
end

print("PASS test_runner_discovery (" .. tostring(manifest.count) .. " suites declared)")
os.exit(0)
