-- test_priest_leveling_wotlk_strategies.lua — Priest leveling WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL leveling_wotlk.lua through its real build_state read
--        path (NS.buff_up for Fortitude / Inner Fire / Shadowform / Power Word:
--        Shield on self, NS.debuff_up for Weakened Soul, NS.debuff_remains for
--        Shadow Word: Pain on the target, ctx.hp / ctx.mana_pct, and the
--        spec_kit setting read behind the opt-in Shadowform lane), pinning both
--        sides of every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua), the leveling
--        runner (run_leveling_tests.lua), and the rotation battery
--        (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): priest leveling had only
--        synthetic dsl_priority coverage; these are real-read behavioral pins.
-- SAFETY: Pure unit tests with a mocked NS; the real leveling_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local combat = true
local hp = 100
local mana = 100
local buffs = {}
local debuffs = {}
local weakened = false
local shadowform_setting = false

local function swp(secs) debuffs[48125] = secs end
local function set_buff(id, up) buffs[id] = up or nil end

local me = { get_health_percentage = function() return hp end }

local function reset_env()
    combat, hp, mana = true, 100, 100
    buffs, debuffs = {}, {}
    weakened, shadowform_setting = false, false
end

_G.EaxRotations = {
    me = me,
    GetPlayer = function() return me end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    debuff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if id == 6788 and weakened then return true end
        end
        return false
    end,
    debuff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if debuffs[id] then return debuffs[id] end
        end
        return 0
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/priest/leveling_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "priest leveling_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local settings = {}
    if shadowform_setting then settings.eaxpriestlvl_use_shadowform = true end
    local ctx = {
        in_combat = combat,
        hp = hp,
        mana_pct = mana,
        enemy_count = 1,
        target = {
            get_health_percentage = function() return 100 end,
            is_casting = function() return false end,
        },
        settings = settings,
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
-- Fortitude / Inner Fire: OOC upkeep.
-- ============================================================================
assert_lane("Fortitude applies OOC when down", "PowerWordFortitude",
    function() combat = false end, true)
assert_lane("Fortitude held while up", "PowerWordFortitude",
    function() combat = false; set_buff(48161, true) end, false)
assert_lane("Fortitude blocked in combat", "PowerWordFortitude", function() end, false)
assert_lane("Fortitude blocked below 10% mana", "PowerWordFortitude",
    function() combat = false; mana = 9 end, false)
assert_lane("InnerFire applies OOC when down", "InnerFire",
    function() combat = false end, true)
assert_lane("InnerFire held while up", "InnerFire",
    function() combat = false; set_buff(48168, true) end, false)

-- ============================================================================
-- Shadowform: opt-in setting + OOC + aura down.
-- ============================================================================
assert_lane("Shadowform applies OOC when opted in", "Shadowform",
    function() combat = false; shadowform_setting = true end, true)
assert_lane("Shadowform held while already in Shadowform", "Shadowform",
    function() combat = false; shadowform_setting = true; set_buff(15473, true) end, false)
assert_lane("Shadowform held without the opt-in setting", "Shadowform",
    function() combat = false end, false)
assert_lane("Shadowform blocked in combat when opted in", "Shadowform",
    function() shadowform_setting = true end, false)

-- ============================================================================
-- PowerWordShield: in combat + absorb down + no Weakened Soul lockout.
-- ============================================================================
assert_lane("PWS applies in combat when down", "PowerWordShield", function() end, true)
assert_lane("PWS held while the absorb is up", "PowerWordShield",
    function() set_buff(48066, true) end, false)
assert_lane("PWS held during Weakened Soul", "PowerWordShield",
    function() weakened = true end, false)
assert_lane("PWS held below 15% mana", "PowerWordShield", function() mana = 14 end, false)
assert_lane("PWS blocked out of combat", "PowerWordShield",
    function() combat = false end, false)

-- ============================================================================
-- FlashHeal: emergency band in combat.
-- ============================================================================
assert_lane("FlashHeal fires below 50% hp in combat", "FlashHeal",
    function() hp = 49 end, true)
assert_lane("FlashHeal blocked at 50% hp", "FlashHeal", function() hp = 50 end, false)
assert_lane("FlashHeal blocked below 25% mana", "FlashHeal",
    function() hp = 40; mana = 24 end, false)

-- ============================================================================
-- ShadowWordPain: refresh at/below 3s in combat.
-- ============================================================================
assert_lane("SW:P refreshes when the debuff is down", "ShadowWordPain", function() end, true)
assert_lane("SW:P refreshes at 2.9s", "ShadowWordPain", function() swp(2.9) end, true)
assert_lane("SW:P blocked at the 3.0s boundary", "ShadowWordPain", function() swp(3) end, false)
assert_lane("SW:P blocked below 15% mana", "ShadowWordPain", function() mana = 14 end, false)
assert_lane("SW:P blocked out of combat", "ShadowWordPain",
    function() combat = false end, false)

-- ============================================================================
-- Penance / MindBlast / MindFlay / Smite: in-combat mana-gated nukes.
-- ============================================================================
assert_lane("Penance fires at 15% mana", "Penance", function() mana = 15 end, true)
assert_lane("Penance blocked below 15% mana", "Penance", function() mana = 14 end, false)
assert_lane("Penance blocked out of combat", "Penance",
    function() combat = false end, false)
assert_lane("MindBlast fires at 20% mana", "MindBlast", function() mana = 20 end, true)
assert_lane("MindBlast blocked below 20% mana", "MindBlast", function() mana = 19 end, false)
assert_lane("MindFlay fires at 20% mana", "MindFlay", function() mana = 20 end, true)
assert_lane("MindFlay blocked below 20% mana", "MindFlay", function() mana = 19 end, false)
assert_lane("Smite fires at 15% mana", "Smite", function() mana = 15 end, true)
assert_lane("Smite blocked below 15% mana", "Smite", function() mana = 14 end, false)

-- ============================================================================
-- Shoot: OOM wand fallback.
-- ============================================================================
assert_lane("Shoot fires below 10% mana", "Shoot", function() mana = 9 end, true)
assert_lane("Shoot blocked at 10% mana", "Shoot", function() mana = 10 end, false)
assert_lane("Shoot blocked out of combat", "Shoot",
    function() mana = 5; combat = false end, false)

print("PASS test_priest_leveling_wotlk_strategies")
