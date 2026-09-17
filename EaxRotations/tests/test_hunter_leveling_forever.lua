-- test_hunter_leveling_forever.lua -- unit pins for the hunter leveling Forever delta.
-- WHAT:  leveling_forever.lua contract: baseline capture + re-register with
--        the shared Aimed/Multi cooldown reorder — the baseline's AimedShot
--        lane is re-emitted Multi-first at the MultiShot position, no lane
--        duplicated, none dropped; the no-Multi fallback keeps Aimed in
--        place; zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   The shared SpellCategory 2 at 6000ms means lane order decides the
--        shot: Aimed-above-Multi starves Multi on every multi-pull (the
--        BM/MM/SV day-1 finding), and a duplicated pair would create a dead
--        lane the never-gate would flag.
-- SAFETY: fully mocked NS + require (fake baseline module).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;" .. package.path

local pass, fail = 0, 0
local function assert_true(v, label)
    if v then pass = pass + 1 else fail = fail + 1; print("  FAIL: " .. tostring(label)) end
end
local function assert_eq(a, b, label)
    if a == b then pass = pass + 1
    else fail = fail + 1; print("  FAIL: " .. tostring(label) .. " (expected " .. tostring(b) .. ", got " .. tostring(a) .. ")") end
end

local registered = nil
local NS = {
    settings = {},
    log = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
}
_G.EaxRotations = NS

local AIMED_MATCH = function() return false end
local MULTI_MATCH = function() return false end

local FAKE_BASELINE = {
    name = "leveling",
    strategies = {
        { name = "AspectHawk", matches = function() return false end, execute = function() return false end },
        { name = "RapidFire", matches = function() return false end, execute = function() return false end },
        { name = "AimedShot", matches = AIMED_MATCH, execute = function() return false end },
        { name = "MongooseBite", matches = function() return false end, execute = function() return false end },
        { name = "SerpentSting", matches = function() return false end, execute = function() return false end },
        { name = "ArcaneShot", matches = function() return false end, execute = function() return false end },
        { name = "MultiShot", matches = MULTI_MATCH, execute = function() return false end },
    },
    options = { get_state = function() return { fake = true } end },
}

local orig_require = require
function require(path)
    if path == "classes/hunter/leveling_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/hunter/leveling_vanilla' not found", 0)
    end
    return orig_require(path)
end

local function load_delta()
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/hunter/leveling_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

local function count_lane(list, name)
    local n = 0
    for _, st in ipairs(list) do
        if type(st) == "table" and st.name == name then n = n + 1 end
    end
    return n
end

-- A. The reorder: Multi first, at the baseline's MultiShot position.
do
    local combined = load_delta()
    assert_eq(registered and registered.name, "leveling", "A: re-registers the leveling playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "A: no lane duplicated or dropped")
    local multi_pos = find_lane(combined, "MultiShot")
    local aimed_pos = find_lane(combined, "AimedShot")
    assert_true(multi_pos ~= nil and aimed_pos ~= nil, "A: both lanes survive")
    assert_eq(multi_pos, find_lane(FAKE_BASELINE.strategies, "MultiShot") - 1,
        "A: the pair closes the shot block (the captured Aimed slot shifts the tail up one)")
    assert_eq(aimed_pos, multi_pos + 1, "A: AimedShot is re-emitted immediately below MultiShot")
    assert_eq(count_lane(combined, "MultiShot"), 1, "A: exactly one MultiShot lane")
    assert_eq(count_lane(combined, "AimedShot"), 1, "A: exactly one AimedShot lane")
    -- The baseline lane objects are reused unchanged (matcher identity).
    assert_true(combined[multi_pos].matches == MULTI_MATCH, "A: the MultiShot matcher is the baseline's")
    assert_true(combined[aimed_pos].matches == AIMED_MATCH, "A: the AimedShot matcher is the baseline's")
end

-- A2. No Multi lane in the baseline: the Aimed lane keeps its position.
do
    local shrunk = {
        name = "leveling",
        strategies = {
            { name = "RapidFire", matches = function() return false end, execute = function() return false end },
            { name = "AimedShot", matches = AIMED_MATCH, execute = function() return false end },
            { name = "ArcaneShot", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta()
    FAKE_BASELINE = saved
    assert_eq(#combined, 3, "A2: lane count preserved")
    assert_eq(find_lane(combined, "AimedShot"), 2, "A2: Aimed keeps its baseline position")
    assert_true(combined[2].matches == AIMED_MATCH, "A2: the matcher is unchanged")
end

-- C. The baseline-failure path is loud (no silent empty playstyle).
do
    local saved = FAKE_BASELINE
    FAKE_BASELINE = nil
    local ok, err = pcall(load_delta)
    FAKE_BASELINE = saved
    assert_true(not ok, "C: a missing baseline fails loudly")
    assert_true(tostring(err):find("baseline load failed", 1, true) ~= nil,
        "C: the error names the baseline load")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/hunter/leveling_forever.lua", "rb")
    local content = f and f:read("*a") or ""
    if f then f:close() end
    assert_true(#content > 0, "E: delta source readable")
    local body = content:gsub("%-%-[^\n]*", "")
    local found = nil
    for line in body:gmatch("([^\n]*)") do
        local digits = line:match("%f[%d]%d%f[^%d]")
        if digits and #digits >= 4 then
            found = found or line
        end
    end
    assert_true(found == nil, "E: no numeric spell-ID literals (found: " .. tostring(found) .. ")")
end

print("test_hunter_leveling_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS hunter_leveling_forever")
