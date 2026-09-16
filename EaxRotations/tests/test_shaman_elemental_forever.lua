-- test_shaman_elemental_forever.lua -- unit pins for the shaman elemental Forever delta.
-- WHAT:  elemental_forever.lua contract: baseline capture + re-register
--        splice (Lava Burst + Fire Nova above the baseline ChainLightning
--        nuke), FS-gated Lava Burst matcher, by-name dormancy, and the
--        zero-numeric-literal audit contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   a lost baseline lane, a Lava Burst that fires without Flame Shock,
--        or a hardcoded spell ID each silently break day-1 elemental.
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
    ShamanSpells = {
        FlameShock = { ids = { 25457, 29228, 10448 } },
    },
    spell_ready = function() return true end,
    try_cast = function() return true end,
    debuff_remains = function() return 0 end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "elemental",
    strategies = {
        { name = "ManaPotion", matches = function() return false end, execute = function() return false end },
        { name = "ChainLightning", matches = function() return false end, execute = function() return false end },
        { name = "LightningBolt", matches = function() return false end, execute = function() return false end },
    },
    options = { get_state = function() return { fake = true } end },
}

local orig_require = require
local pending_bridge_by_name = {}
function require(path)
    if path == "shared/wowhead_data_bridge_spell_index_forever_sylvanas" then
        return { spell_index_by_name_forever = pending_bridge_by_name }
    end
    if path == "classes/shaman/elemental_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/shaman/elemental_vanilla' not found", 0)
    end
    if path == "shared/spec_kit_sylvanas" then
        return { setting = function(_, key, default) return default end }
    end
    return orig_require(path)
end

local function load_delta(bridge_by_name)
    pending_bridge_by_name = bridge_by_name or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/shaman/elemental_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

-- A. Full kit: both bridge names resolve; splice + registration shape.
do
    local combined = load_delta({ ["Lava Burst"] = 19006, ["Fire Nova"] = 19005 })
    assert_eq(registered and registered.name, "elemental", "A: re-registers the elemental playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 2, "A: 2 delta lanes over 3 baseline lanes")
    local lb = find_lane(combined, "Forever_LavaBurstShocked")
    local nova = find_lane(combined, "Forever_FireNovaSpell")
    local cl = find_lane(combined, "ChainLightning")
    assert_true(lb and nova and cl and lb == cl - 2 and nova == cl - 1, "A: Lava Burst then Fire Nova sit just above ChainLightning")
    assert_true(find_lane(combined, "ManaPotion") ~= nil, "A: baseline lanes preserved")
end

-- B. Matcher behavior: the FS dependency is the point of the lane.
do
    local combined = load_delta({ ["Lava Burst"] = 19006, ["Fire Nova"] = 19005 })
    local state = { mana_pct = 80 }
    local ctx = { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {} }

    local lb = combined[find_lane(combined, "Forever_LavaBurstShocked")]
    NS.debuff_remains = function() return 10 end
    assert_true(lb.matches(ctx, state), "B: Lava Burst fires with FS up")
    NS.debuff_remains = function() return 1 end
    assert_true(not lb.matches(ctx, state), "B: Lava Burst holds below the FS remains floor")
    NS.debuff_remains = function() return 0 end
    assert_true(not lb.matches(ctx, state), "B: Lava Burst never fires without FS")
    NS.debuff_remains = function() return 10 end
    state.mana_pct = 10
    assert_true(not lb.matches(ctx, state), "B: Lava Burst respects the mana floor")
    state.mana_pct = 80

    local nova = combined[find_lane(combined, "Forever_FireNovaSpell")]
    assert_true(nova.matches(ctx, state), "B: Fire Nova matches with mana")
    state.mana_pct = 10
    assert_true(not nova.matches(ctx, state), "B: Fire Nova respects the mana floor")
    state.mana_pct = 80
end

-- C. Dormancy before the beta DBC: both lanes dormant pre-beta.
do
    local combined = load_delta({})
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: zero delta lanes pre-beta (all name-resolved)")
    assert_true(not find_lane(combined, "Forever_LavaBurstShocked"), "C: Lava Burst dormant")
    assert_true(not find_lane(combined, "Forever_FireNovaSpell"), "C: Fire Nova dormant")
    assert_eq(find_lane(combined, "ChainLightning"), 2, "C: baseline order unchanged")
end

-- D. Splice fallback: no ChainLightning anchor appends in order.
do
    FAKE_BASELINE.strategies = {
        { name = "ManaPotion", matches = function() return false end, execute = function() return false end },
    }
    local combined = load_delta({ ["Lava Burst"] = 19006, ["Fire Nova"] = 19005 })
    assert_eq(find_lane(combined, "Forever_LavaBurstShocked"), #combined - 1, "D: Lava Burst appends before Fire Nova")
    assert_eq(find_lane(combined, "Forever_FireNovaSpell"), #combined, "D: Fire Nova appends last")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/shaman/elemental_forever.lua", "r")
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

print(string.format("test_shaman_elemental_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS shaman_elemental_forever")
