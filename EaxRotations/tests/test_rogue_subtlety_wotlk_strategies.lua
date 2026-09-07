-- test_rogue_subtlety_wotlk_strategies.lua — Subtlety rogue WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL subtlety_wotlk.lua through its real build_state read
--        path: ctx.energy/combo_points, NS.buff_up for the Shadow Dance buff,
--        ctx.is_behind / NS.is_behind_target for the strict behind gate, the
--        real dagger_set + equipped-item IDs for Backstab eligibility, and
--        target:is_casting for Kick. Pins both sides of every lane,
--        including the unconditional Premeditation opener and the Shadow
--        Dance upkeep lane.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): the dsl_priority suite mutates
--        build_state output post-hoc, so no suite exercised the real state
--        plumbing (dance buff, behind check, dagger eligibility).
-- SAFETY: Pure unit tests with a mocked NS; the real subtlety_wotlk.lua and
--         real shared modules (spec_kit / strategy_dsl / combo_points_reader /
--         dagger_set) load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

-- Mutable scenario state.
local energy = 0
local cp = 0
local combat = true
local casting = false
local dance = false       -- Shadow Dance buff (51713) up
local behind = false
local daggers = false
local buffs = {}

local me = {
    get_health_percentage = function() return 100 end,
    get_power = function(self, power_type)
        if power_type == 3 then return energy end
        return 0
    end,
}

local function set_buff(id, up) buffs[id] = up or nil end

local function reset_env()
    energy, cp = 0, 0
    combat, casting, dance, behind, daggers = true, false, false, false, false
    buffs = {}
end

_G.EaxRotations = {
    POWER_ENERGY = 3,
    POWER_COMBO = 4,
    EQUIPMENT_SLOTS = { MAIN_HAND = 16, OFF_HAND = 17 },
    me = me,
    GetPlayer = function() return me end,
    get_equipped_item_id = function(slot)
        if not daggers then return 0 end
        if slot == 16 then return 776 end   -- real dagger item ids (dagger_set map)
        if slot == 17 then return 820 end
        return 0
    end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/rogue/subtlety_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "subtlety_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        energy = energy,
        combo_points = cp,
        is_behind = behind,
        target = {
            get_health_percentage = function() return 100 end,
            is_casting = function() return casting end,
        },
        settings = {},
    }
    local state = result.build_state(ctx)
    local matched = find_strategy(strategy_name).matches(ctx, state)
    if expect then
        assert_true(matched, label .. " should match")
    else
        assert_false(matched, label .. " should NOT match")
    end
end

local function assert_lane(label, strategy_name, setup, expect)
    reset_env()
    setup()
    scenario(label, strategy_name, expect)
end

-- ============================================================================
-- Kick interrupt: in combat + an enemy cast.
-- ============================================================================
assert_lane("Kick fires on an enemy cast in combat", "Kick",
    function() casting = true end, true)
assert_lane("Kick blocked when the target is not casting", "Kick",
    function() casting = false end, false)
assert_lane("Kick blocked out of combat", "Kick",
    function() casting = true; combat = false end, false)

-- ============================================================================
-- Premeditation: unconditional opener (no conditions) — fires even OOC.
-- ============================================================================
assert_lane("Premeditation fires in combat", "Premeditation", function() end, true)
assert_lane("Premeditation fires out of combat (ungated)", "Premeditation",
    function() combat = false end, true)

-- ============================================================================
-- Shadow Dance: upkeep when the buff is down.
-- ============================================================================
assert_lane("ShadowDance fires with the buff down", "ShadowDance", function() end, true)
assert_lane("ShadowDance blocked while the buff is up", "ShadowDance",
    function() set_buff(51713, true) end, false)

-- ============================================================================
-- Ambush: Shadow Dance up + behind the target + >= 60 energy.
-- ============================================================================
assert_lane("Ambush fires in Shadow Dance behind the target", "Ambush",
    function() set_buff(51713, true); behind = true; energy = 60 end, true)
assert_lane("Ambush blocked outside Shadow Dance", "Ambush",
    function() set_buff(51713, false); behind = true; energy = 100 end, false)
assert_lane("Ambush blocked in front of the target", "Ambush",
    function() set_buff(51713, true); behind = false; energy = 100 end, false)
assert_lane("Ambush blocked below 60 energy", "Ambush",
    function() set_buff(51713, true); behind = true; energy = 59 end, false)

-- ============================================================================
-- Eviscerate: finisher at >= 4 combo points.
-- ============================================================================
assert_lane("Eviscerate fires at 4 combo points", "Eviscerate",
    function() cp = 4 end, true)
assert_lane("Eviscerate blocked at 3 combo points", "Eviscerate",
    function() cp = 3 end, false)

-- ============================================================================
-- Backstab: behind + daggers in both hands + >= 60 energy.
-- ============================================================================
assert_lane("Backstab fires behind the target with daggers", "Backstab",
    function() behind = true; daggers = true; energy = 60 end, true)
assert_lane("Backstab blocked in front of the target", "Backstab",
    function() behind = false; daggers = true; energy = 100 end, false)
assert_lane("Backstab blocked without daggers equipped", "Backstab",
    function() behind = true; daggers = false; energy = 100 end, false)
assert_lane("Backstab blocked below 60 energy", "Backstab",
    function() behind = true; daggers = true; energy = 59 end, false)

print("PASS test_rogue_subtlety_wotlk_strategies")
