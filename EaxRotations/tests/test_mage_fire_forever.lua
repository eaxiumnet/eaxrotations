-- test_mage_fire_forever.lua -- unit pins for the mage fire Forever delta.
-- WHAT:  fire_forever.lua contract: baseline capture + re-register splice
--        (Hot Streak fast-Pyro above the baseline Pyroblast lane), by-name
--        dormancy, matcher gates, zero-numeric-literal audit contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   a lost baseline lane, a Hot Streak spend firing without the buff,
--        or a hardcoded spell ID each silently break day-1 fire.
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
local PLAYER_UNIT_REF = {}
local NS = {
    settings = {},
    log = function() end,
    PLAYER_UNIT = PLAYER_UNIT_REF,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    MageSpells = {
        Pyroblast = { ids = { 38692, 27070, 25306 } },
    },
    has_player_buff = function() return false end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "fire",
    strategies = {
        { name = "IceBarrier", matches = function() return false end, execute = function() return false end },
        { name = "Pyroblast", matches = function() return false end, execute = function() return false end },
        { name = "Fireball", matches = function() return false end, execute = function() return false end },
    },
    options = { get_state = function() return { fake = true } end },
}

local orig_require = require
local pending_by_name, pending_maxrank, pending_buff = {}, {}, {}
function require(path)
    if path == "shared/wowhead_data_bridge_spell_index_forever_sylvanas" then
        return { spell_index_by_name_forever = pending_by_name,
                 spell_maxrank_by_name_forever = pending_maxrank,
                 spell_buff_by_name_forever = pending_buff }
    end
    if path == "classes/mage/fire_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/mage/fire_vanilla' not found", 0)
    end
    if path == "shared/spec_kit_sylvanas" then
        return { setting = function(_, key, default) return default end }
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/mage/fire_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

-- A. Full kit: Hot Streak resolves; splice + registration shape.
do
    local combined = load_delta({}, {}, { ["Hot Streak"] = 19207 })
    assert_eq(registered and registered.name, "fire", "A: re-registers the fire playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: 1 delta lane over 3 baseline lanes")
    local hs = find_lane(combined, "Forever_HotStreakPyro")
    local pyro = find_lane(combined, "Pyroblast")
    assert_true(hs and pyro and hs == pyro - 1, "A: Hot Streak sits just above baseline Pyroblast")
    assert_true(find_lane(combined, "IceBarrier") == 1, "A: defensive head lanes untouched")
end

-- B. Matcher behavior: buff-gated spend.
do
    local combined = load_delta({}, {}, { ["Hot Streak"] = 19207 })
    local state = { mana_pct = 80 }
    local ctx = { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {} }

    local hs = combined[find_lane(combined, "Forever_HotStreakPyro")]
    NS.has_player_buff = function() return true end
    assert_true(hs.matches(ctx, state), "B: Hot Streak fires with the buff")
    NS.has_player_buff = function() return false end
    assert_true(not hs.matches(ctx, state), "B: Hot Streak dormant without the buff")
    state.mana_pct = 10
    NS.has_player_buff = function() return true end
    assert_true(not hs.matches(ctx, state), "B: Hot Streak respects the mana floor")
    state.mana_pct = 80
    local no_target = { in_combat = true, has_valid_enemy_target = false, me = {}, settings = {} }
    assert_true(not hs.matches(no_target, state), "B: Hot Streak holds without an enemy")

    -- 3-stack cap (DBC: CumulativeAura 3): spend at the cap, hold below it,
    -- and fail open when the stack read is unusable (0/nil).
    NS.has_player_buff = function() return true end
    NS.buff_stacks = function() return 3 end
    assert_true(hs.matches(ctx, state), "B: Hot Streak fires at the 3-stack cap")
    NS.buff_stacks = function() return 1 end
    assert_true(not hs.matches(ctx, state), "B: Hot Streak holds below the stack cap")
    NS.buff_stacks = function() return 0 end
    assert_true(hs.matches(ctx, state), "B: Hot Streak fails open on a 0 (unusable) stack read")
    NS.buff_stacks = nil
    assert_true(hs.matches(ctx, state), "B: Hot Streak fails open when buff_stacks is unavailable")
    NS.has_player_buff = function() return false end
end

-- C. Dormancy on nil lookups: zero delta lanes on empty mirrors.
do
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: zero delta lanes on empty mirrors")
    assert_true(not find_lane(combined, "Forever_HotStreakPyro"), "C: Hot Streak dormant")
    assert_eq(find_lane(combined, "Pyroblast"), 2, "C: baseline order unchanged")
end

-- D. Splice fallback: no Pyroblast anchor appends.
do
    FAKE_BASELINE.strategies = {
        { name = "Fireball", matches = function() return false end, execute = function() return false end },
    }
    local combined = load_delta({}, {}, { ["Hot Streak"] = 19207 })
    assert_eq(find_lane(combined, "Forever_HotStreakPyro"), #combined, "D: Hot Streak appends when the anchor lane is absent")
end

-- G. Mirror selection: the Hot Streak gate reads the buff mirror (the
-- Forever stacking proc 400625), never the rank-1 baseline.
do
    local combined = load_delta({}, {}, { ["Hot Streak"] = 19207 })
    local state = { mana_pct = 80 }
    local ctx = { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {} }
    local hs = combined[find_lane(combined, "Forever_HotStreakPyro")]
    NS.has_player_buff = function(id) return id == 19207 end
    assert_true(hs.matches(ctx, state), "G: Hot Streak matches on the buff-mirror sentinel")
    NS.has_player_buff = function(id) return id == 19007 end
    assert_true(not hs.matches(ctx, state), "G: Hot Streak ignores the rank-1 baseline sentinel")
    NS.has_player_buff = function() return false end
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/mage/fire_forever.lua", "r")
    local content = f and f:read("*a") or ""
    if f then f:close() end
    assert_true(#content > 0, "E: delta source readable")
    local bad = {}
    local line_no = 0
    for line in content:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        if line:match("^%s*%-%-") ~= nil then
            -- comment line: exempt
        else
            for table_part in line:gmatch("(%b{})") do
                local inner = table_part:sub(2, -2)
                if inner:match("^[%s%d,]*$") then
                    for num in inner:gmatch("%d+") do
                        if tonumber(num) >= 100 then bad[#bad + 1] = line_no .. ":" .. num end
                    end
                end
            end
        end
    end
    assert_eq(#bad, 0, "E: zero numeric ID literals in code (found: " .. table.concat(bad, ", ") .. ")")
end

-- F. Baseline load failure is loud.
do
    FAKE_BASELINE = nil
    local ok, err = pcall(load_delta, {})
    assert_true(not ok, "F: delta errors when the baseline cannot load")
    assert_true(tostring(err):find("baseline load failed", 1, true) ~= nil, "F: error names the baseline failure")
end

require = orig_require

print(string.format("test_mage_fire_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS mage_fire_forever")
