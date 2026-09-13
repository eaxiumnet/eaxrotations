-- test_paladin_protection_wotlk_strategies.lua — Protection paladin WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL protection_wotlk.lua through its real build_state read
--        path (ctx.mana_pct / enemy_count, NS.debuff_remains for Consecration,
--        NS.buff_up for Righteous Fury / Holy Shield, NS.buff_points for the
--        Holy Shield block-charge count, real NS.spell_ready for the Holy
--        Shield CD, and the anti-loop clock for the Righteous Fury lane),
--        pinning both sides of every lane.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): the protection_paladin
--        dsl_priority suite mutates build_state output post-hoc, so the real
--        charge/aura/mana plumbing was never exercised.
-- SAFETY: Pure unit tests with a mocked NS; the real protection_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local mana = 100
local enemy_count = 1
local combat = true
local now = 0
local debuffs = {}
local buffs = {}
local hs_charges = 0
local not_ready = {}
local cds = {}
local creature_type = 1
local hp = 100
local target_hp = 100
local sacred_remains = 0

local function consecration(secs) debuffs[48819] = secs end
local function set_buff(id, up) buffs[id] = up or nil end
local function rf(up) set_buff(25780, up) end
local function hs(up) set_buff(48952, up) end
local function sacred(secs) sacred_remains = secs end

local function reset_env()
    mana, enemy_count, combat = 100, 1, true
    now = now + 10   -- advance past the Righteous Fury 3s anti-loop throttle
    debuffs, buffs, not_ready = {}, {}, {}
    hs_charges = 0
    cds, creature_type = {}, 1
    hp, target_hp, sacred_remains = 100, 100, 0
end

_G.EaxRotations = {
    me = { get_health_percentage = function() return hp end },
    GetPlayer = function() return _G.EaxRotations.me end,
    unit_mana_pct = function() return mana end,
    time_now = function() return now end,
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
    buff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if id == 53601 then return sacred_remains end
        end
        return 0
    end,
    buff_points = function(unit, ids)
        for _, id in ipairs(ids) do
            if id == 48952 then return { hs_charges } end
        end
        return { 0 }
    end,
    spell_ready = function(spell, target, opts)
        local id = type(spell) == "number" and spell or (spell and (spell.id or spell[1]))
        if not_ready[id] then return false end
        return true
    end,
    cooldown_remains = function(action)
        local id = type(action) == "number" and action or (action and action.id)
        return cds[id] or 0
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/paladin/protection_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "protection_wotlk strategies should load")

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
        enemy_count = enemy_count,
        target = {
            get_health_percentage = function() return target_hp end,
            get_creature_type = function() return creature_type end,
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
-- Tank strike core: Avenger's Shield / Shield of Righteousness / Hammer of the
-- Righteous / Judgement — in-combat-only.
-- ============================================================================
assert_lane("AvengersShield fires in combat", "AvengersShield", function() end, true)
assert_lane("AvengersShield blocked out of combat", "AvengersShield",
    function() combat = false end, false)
assert_lane("ShieldOfRighteousness fires in combat", "ShieldOfRighteousness", function() end, true)
assert_lane("ShieldOfRighteousness blocked out of combat", "ShieldOfRighteousness",
    function() combat = false end, false)
assert_lane("HammerOfTheRighteous fires in combat", "HammerOfTheRighteous", function() end, true)
assert_lane("HammerOfTheRighteous blocked out of combat", "HammerOfTheRighteous",
    function() combat = false end, false)
assert_lane("Judgement fires in combat", "Judgement", function() end, true)
assert_lane("Judgement blocked out of combat", "Judgement",
    function() combat = false end, false)

-- ============================================================================
-- Consecration: refresh under 3s at >= 25% mana.
-- ============================================================================
assert_lane("Consecration fires when the ground effect is down", "Consecration",
    function() mana = 25 end, true)
assert_lane("Consecration fires when about to expire", "Consecration",
    function() mana = 100; consecration(2) end, true)
assert_lane("Consecration blocked while the ground effect is fresh", "Consecration",
    function() mana = 100; consecration(3) end, false)
assert_lane("Consecration blocked below 25% mana", "Consecration",
    function() mana = 24 end, false)
assert_lane("Consecration blocked out of combat", "Consecration",
    function() mana = 100; combat = false end, false)

-- ============================================================================
-- Righteous Fury: threat-multiplier upkeep (buff down, throttled 3s).
-- ============================================================================
assert_lane("RighteousFury fires with the buff down", "RighteousFury", function() end, true)
assert_lane("RighteousFury blocked while the buff is up", "RighteousFury",
    function() rf(true) end, false)
assert_lane("RighteousFury fires again after the throttle window", "RighteousFury",
    function() end, true)

-- ============================================================================
-- Holy Shield: proactive charge management — refresh when the buff is down OR
-- remaining blocks drop to the configured floor (default 2).
-- ============================================================================
assert_lane("HolyShield fires with the buff down", "HolyShield", function() end, true)
assert_lane("HolyShield fires at the 2-charge floor", "HolyShield",
    function() hs(true); hs_charges = 2 end, true)
assert_lane("HolyShield fires at 0 charges (buff lag)", "HolyShield",
    function() hs(true); hs_charges = 0 end, true)
assert_lane("HolyShield held with 3 charges remaining", "HolyShield",
    function() hs(true); hs_charges = 3 end, false)
assert_lane("HolyShield blocked while on cooldown", "HolyShield",
    function() not_ready[48952] = true end, false)
assert_lane("HolyShield blocked out of combat", "HolyShield",
    function() combat = false end, false)

-- ============================================================================
-- Holy Wrath: AoE burst vs demon (3) / undead (6) targets on 2+ enemies
-- (2026-09-09 guide pass). Real cooldown_remains read on 48817.
-- ============================================================================
assert_lane("HolyWrath fires on undead adds", "HolyWrath",
    function() enemy_count = 2; creature_type = 6 end, true)
assert_lane("HolyWrath fires on demon adds", "HolyWrath",
    function() enemy_count = 3; creature_type = 3 end, true)
assert_lane("HolyWrath blocked on humanoid pulls", "HolyWrath",
    function() enemy_count = 2; creature_type = 7 end, false)
assert_lane("HolyWrath blocked single-target", "HolyWrath",
    function() enemy_count = 1; creature_type = 6 end, false)
assert_lane("HolyWrath blocked while on cooldown", "HolyWrath",
    function() enemy_count = 2; creature_type = 6; cds[48817] = 20 end, false)

-- ============================================================================
-- Divine Plea: mana return at < 50% mana off CD (2026-09-09 guide pass).
-- ============================================================================
assert_lane("DivinePlea fires at 49% mana", "DivinePlea", function() mana = 49 end, true)
assert_lane("DivinePlea blocked at 50% mana", "DivinePlea", function() mana = 50 end, false)
assert_lane("DivinePlea blocked while on cooldown", "DivinePlea",
    function() mana = 20; cds[54428] = 60 end, false)
assert_lane("DivinePlea blocked out of combat", "DivinePlea",
    function() mana = 20; combat = false end, false)

-- ============================================================================
-- DivineProtection (2026-09-12 guide pass): -50% damage panic button.
-- ============================================================================
assert_lane("Divine Protection fires under 35% hp", "DivineProtection",
    function() hp = 30 end, true)
assert_lane("Divine Protection held at the 35% boundary", "DivineProtection",
    function() hp = 35 end, false)
assert_lane("Divine Protection held on cooldown", "DivineProtection",
    function() hp = 20; cds[498] = 60 end, false)
assert_lane("Divine Protection held out of combat", "DivineProtection",
    function() hp = 20; combat = false end, false)

-- ============================================================================
-- HammerOfWrath (APL priority 4): the <=20% hp execute, 6s CD.
-- ============================================================================
assert_lane("Hammer of Wrath fires in the execute band", "HammerOfWrath",
    function() target_hp = 20 end, true)
assert_lane("Hammer of Wrath held above the execute band", "HammerOfWrath",
    function() target_hp = 21 end, false)
assert_lane("Hammer of Wrath held on cooldown", "HammerOfWrath",
    function() target_hp = 10; cds[48806] = 6 end, false)
assert_lane("Hammer of Wrath held out of combat", "HammerOfWrath",
    function() target_hp = 10; combat = false end, false)

-- ============================================================================
-- SacredShield (guide pass): 30s self barrier, refill inside the last 5s.
-- ============================================================================
assert_lane("Sacred Shield applies when the barrier is down", "SacredShield",
    function() sacred(0) end, true)
assert_lane("Sacred Shield refreshes at 4.9s remaining", "SacredShield",
    function() sacred(4.9) end, true)
assert_lane("Sacred Shield held at the 5.0s boundary", "SacredShield",
    function() sacred(5) end, false)
assert_lane("Sacred Shield held out of combat", "SacredShield",
    function() sacred(0); combat = false end, false)

print("PASS test_paladin_protection_wotlk_strategies")
