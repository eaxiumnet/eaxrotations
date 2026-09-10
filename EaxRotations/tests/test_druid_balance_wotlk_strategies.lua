-- test_druid_balance_wotlk_strategies.lua — Balance druid WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL balance_wotlk.lua through its real build_state read
--        path (NS.buff_up for Moonkin form and the solar/lunar Eclipse auras,
--        NS.debuff_remains for Moonfire / Insect Swarm, ctx.mana_pct, the
--        long-CD consent gate, and real NS.spell_ready for Starfall), pinning
--        both sides of every lane — especially the Eclipse spell-switch state
--        machine: Wrath only during solar Eclipse, Starfire during lunar
--        Eclipse or as the no-Eclipse filler.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): balance druid's dsl_priority
--        suite mutates build_state output post-hoc, so the real Eclipse /
--        mana / DoT read plumbing was never exercised.
-- SAFETY: Pure unit tests with a mocked NS; the real balance_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local mana = 100
local combat = true
local longcd = true
local debuffs = {}
local buffs = {}
local not_ready = {}
local enemies = 1      -- enemy_count seen by the FaerieFire/Hurricane lanes
local aoe_ok = true    -- NS.aoe_target_meets result (Hurricane volume gate)

local function moonfire(secs) debuffs[48463] = secs end
local function insect_swarm(secs) debuffs[48468] = secs end
local function set_buff(id, up) buffs[id] = up or nil end
local function solar(up) set_buff(48517, up) end
local function lunar(up) set_buff(48518, up) end

local function reset_env()
    mana, combat, longcd = 100, true, true
    debuffs, buffs, not_ready = {}, {}, {}
    enemies, aoe_ok = 1, true
end

_G.EaxRotations = {
    me = { get_health_percentage = function() return 100 end },
    GetPlayer = function() return _G.EaxRotations.me end,
    mana_pct = function() return mana end,
    debuff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if debuffs[id] then return debuffs[id] end
        end
        return 0
    end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    should_use_long_cd = function(context, cd) return longcd end,
    spell_ready = function(spell, target)
        local id = type(spell) == "number" and spell or (spell and (spell.id or spell[1]))
        if not_ready[id] then return false end
        return true
    end,
    aoe_target_meets = function() return aoe_ok end,
    AOE_RADIUS = { SELF_10 = 10 },
    try_cast = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/druid/balance_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "balance_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        mana_pct = mana,
        enemy_count = enemies,
        target = { get_health_percentage = function() return 100 end },
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
-- Moonkin form: enter in combat when not already in the form.
-- ============================================================================
assert_lane("MoonkinForm fires in combat with the form down", "MoonkinForm", function() end, true)
assert_lane("MoonkinForm blocked while already in Moonkin form", "MoonkinForm",
    function() set_buff(24858, true) end, false)
assert_lane("MoonkinForm blocked out of combat", "MoonkinForm",
    function() combat = false end, false)

-- ============================================================================
-- Starfall: in combat + long-CD consent + cooldown ready.
-- ============================================================================
assert_lane("Starfall fires in combat with the cooldown ready", "Starfall", function() end, true)
assert_lane("Starfall blocked when long-CD gate refuses", "Starfall",
    function() longcd = false end, false)
assert_lane("Starfall blocked while on cooldown", "Starfall",
    function() not_ready[48505] = true end, false)
assert_lane("Starfall blocked out of combat", "Starfall",
    function() combat = false end, false)

-- ============================================================================
-- Moonfire / Insect Swarm: DoT upkeep under 3s.
-- ============================================================================
assert_lane("Moonfire fires when the DoT is down", "Moonfire", function() end, true)
assert_lane("Moonfire fires when about to expire", "Moonfire",
    function() moonfire(2) end, true)
assert_lane("Moonfire blocked while the DoT is healthy", "Moonfire",
    function() moonfire(3) end, false)
assert_lane("InsectSwarm fires when the DoT is down", "InsectSwarm", function() end, true)
assert_lane("InsectSwarm blocked while the DoT is healthy", "InsectSwarm",
    function() insect_swarm(3) end, false)

-- ============================================================================
-- Eclipse state machine: Wrath during solar; Starfire during lunar AND as the
-- no-Eclipse filler; Starfire never during solar.
-- ============================================================================
assert_lane("Wrath fires during solar Eclipse", "Wrath",
    function() solar(true) end, true)
assert_lane("Wrath blocked with no Eclipse up", "Wrath", function() end, false)
assert_lane("Wrath blocked during lunar Eclipse", "Wrath",
    function() lunar(true) end, false)
assert_lane("Wrath blocked below 15% mana during solar", "Wrath",
    function() solar(true); mana = 14 end, false)
assert_lane("Starfire fires during lunar Eclipse", "Starfire",
    function() lunar(true) end, true)
assert_lane("Starfire fires as the no-Eclipse filler", "Starfire", function() end, true)
assert_lane("Starfire blocked during solar Eclipse (Wrath window)", "Starfire",
    function() solar(true) end, false)
assert_lane("Starfire blocked below 15% mana", "Starfire",
    function() mana = 14 end, false)

-- ============================================================================
-- FaerieFire: debuff upkeep (3% spell hit) — refresh window like the DoTs.
-- ============================================================================
assert_lane("FaerieFire fires when the debuff is down", "FaerieFire",
    function() end, true)
assert_lane("FaerieFire fires in the refresh window", "FaerieFire",
    function() debuffs[26993] = 2.9 end, true)
assert_lane("FaerieFire blocked while the debuff is healthy", "FaerieFire",
    function() debuffs[26993] = 3.1 end, false)

-- ============================================================================
-- HurricaneAoE: 3+ enemies in the 10y self radius (channeled AoE slot).
-- ============================================================================
assert_lane("HurricaneAoE fires into a 3-enemy pack", "HurricaneAoE",
    function() enemies = 3 end, true)
assert_lane("HurricaneAoE blocked at 2 enemies", "HurricaneAoE",
    function() enemies = 2 end, false)
assert_lane("HurricaneAoE fail-closed without the AoE module", "HurricaneAoE",
    function() enemies = 4; aoe_ok = false end, false)
assert_lane("HurricaneAoE blocked out of combat", "HurricaneAoE",
    function() enemies = 4; combat = false end, false)
assert_lane("HurricaneAoE blocked while on cooldown", "HurricaneAoE",
    function() enemies = 4; not_ready[48467] = true end, false)

print("PASS test_druid_balance_wotlk_strategies")
