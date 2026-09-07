-- test_paladin_retribution_wotlk_strategies.lua — Retribution paladin WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL retribution_wotlk.lua through its real build_state
--        read path (NS.buff_up for the seal / Art of War / Divine Plea auras,
--        real NS.cooldown_remains for every CD-gated lane, ctx.mana_pct /
--        enemy_count / target hp, the real hit-volume gate for Consecration,
--        and the anti-loop clock for the seal-switch lane), pinning both sides
--        of every lane: the single-target/aoe seal choice, Divine Plea mana
--        recovery, Avenging Wrath burst, the Hammer of Wrath execute band,
--        the Judgement / Crusader Strike / Divine Storm CD cycle, Exorcism on
--        the Art of War proc, Consecration AoE, and the SoV<->SoC switch.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): retribution had zero behavioral
--        coverage (only a static priority-order suite); every lane here is a
--        first behavioral pin.
-- SAFETY: Pure unit tests with a mocked NS; the real retribution_wotlk.lua and
--         real shared modules (incl. the hit-volume gate) load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local thp = 100
local mana = 100
local enemy_count = 1
local combat = true
local longcd = true
local aoe = 0
local now = 0
local buffs = {}
local cds = {}

local function set_buff(id, up) buffs[id] = up or nil end
local function sov(up) set_buff(31801, up) end
local function soc(up) set_buff(27170, up) end
local function art_of_war(up) set_buff(59578, up) end
local function plea(up) set_buff(54428, up) end

local function reset_env()
    thp, mana, enemy_count, combat, longcd, aoe = 100, 100, 1, true, true, 0
    now = now + 10   -- advance past the seal-switch 3s anti-loop throttle
    buffs, cds = {}, {}
end

_G.EaxRotations = {
    me = { get_health_percentage = function() return 100 end },
    GetPlayer = function() return _G.EaxRotations.me end,
    unit_mana_pct = function() return mana end,
    time_now = function() return now end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    cooldown_remains = function(action)
        local id = type(action) == "number" and action or (action and action.id)
        return cds[id] or 0
    end,
    get_spell_cooldown = function(action) return 0 end,
    should_use_long_cd = function(context, cd) return longcd end,
    try_cast = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/paladin/retribution_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "retribution_wotlk strategies should load")

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
        _aoe_hit_count = aoe,
        target = { get_health_percentage = function() return thp end },
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
-- Seal choice: single-target SoV, AoE SoC — both only when NO seal is up.
-- ============================================================================
assert_lane("SealOfVengeance fires single-target with no seal", "SealOfVengeance",
    function() enemy_count = 1 end, true)
assert_lane("SealOfVengeance blocked against 2 enemies (SoC side)", "SealOfVengeance",
    function() enemy_count = 2 end, false)
assert_lane("SealOfVengeance blocked while a seal is already up", "SealOfVengeance",
    function() sov(true); enemy_count = 1 end, false)
assert_lane("SealOfCommand fires against 2 enemies with no seal", "SealOfCommand",
    function() enemy_count = 2 end, true)
assert_lane("SealOfCommand blocked single-target", "SealOfCommand",
    function() enemy_count = 1 end, false)
assert_lane("SealOfCommand blocked while a seal is already up", "SealOfCommand",
    function() soc(true); enemy_count = 2 end, false)

-- ============================================================================
-- Divine Plea: mana recovery below 40% off cooldown when the buff is down.
-- ============================================================================
assert_lane("DivinePlea fires below 40% mana", "DivinePlea",
    function() mana = 39 end, true)
assert_lane("DivinePlea blocked at/above 40% mana", "DivinePlea",
    function() mana = 40 end, false)
assert_lane("DivinePlea blocked while the buff is up", "DivinePlea",
    function() mana = 30; plea(true) end, false)
assert_lane("DivinePlea blocked while on cooldown", "DivinePlea",
    function() mana = 30; cds[54428] = 60 end, false)

-- ============================================================================
-- Avenging Wrath: burst window off CD with long-CD consent (setting on).
-- ============================================================================
assert_lane("AvengingWrath fires in combat off cooldown", "AvengingWrath", function() end, true)
assert_lane("AvengingWrath blocked while on cooldown", "AvengingWrath",
    function() cds[31884] = 120 end, false)
assert_lane("AvengingWrath blocked when long-CD gate refuses", "AvengingWrath",
    function() longcd = false end, false)
assert_lane("AvengingWrath blocked out of combat", "AvengingWrath",
    function() combat = false end, false)

-- ============================================================================
-- Hammer of Wrath: execute band below 20% target hp off CD.
-- ============================================================================
assert_lane("HammerOfWrath fires below 20% target hp", "HammerOfWrath",
    function() thp = 19 end, true)
assert_lane("HammerOfWrath blocked at/above 20% target hp", "HammerOfWrath",
    function() thp = 20 end, false)
assert_lane("HammerOfWrath blocked while on cooldown", "HammerOfWrath",
    function() thp = 10; cds[48806] = 6 end, false)

-- ============================================================================
-- Judgement / Crusader Strike / Divine Storm CD cycle.
-- ============================================================================
assert_lane("Judgement fires off cooldown", "Judgement", function() end, true)
assert_lane("Judgement blocked while on cooldown", "Judgement",
    function() cds[20271] = 8 end, false)
assert_lane("CrusaderStrike fires off cooldown", "CrusaderStrike", function() end, true)
assert_lane("CrusaderStrike blocked while on cooldown", "CrusaderStrike",
    function() cds[35395] = 4 end, false)
assert_lane("DivineStorm fires off cooldown", "DivineStorm", function() end, true)
assert_lane("DivineStorm blocked while on cooldown", "DivineStorm",
    function() cds[53385] = 10 end, false)

-- ============================================================================
-- Exorcism: Art of War proc window only.
-- ============================================================================
assert_lane("Exorcism fires on an Art of War proc", "Exorcism",
    function() art_of_war(true) end, true)
assert_lane("Exorcism blocked without the proc", "Exorcism",
    function() art_of_war(false) end, false)
assert_lane("Exorcism blocked on a proc while on cooldown", "Exorcism",
    function() art_of_war(true); cds[48801] = 15 end, false)

-- ============================================================================
-- Consecration: ground AoE at 2+ targets within 8 yd (real hit gate), 30% mana.
-- ============================================================================
assert_lane("Consecration fires on 2 targets at 30% mana", "Consecration",
    function() mana = 30; aoe = 2 end, true)
assert_lane("Consecration blocked below 30% mana", "Consecration",
    function() mana = 29; aoe = 5 end, false)
assert_lane("Consecration blocked single-target", "Consecration",
    function() mana = 100; aoe = 1 end, false)
assert_lane("Consecration blocked while on cooldown", "Consecration",
    function() mana = 100; aoe = 5; cds[48819] = 8 end, false)

-- ============================================================================
-- Seal switch: SoV must drop when adds arrive (2+), SoC must drop back to SoV
-- on single target; never when the active seal already matches the pack.
-- ============================================================================
assert_lane("SealSwitch fires to drop SoV when adds arrive", "SealSwitch",
    function() sov(true); enemy_count = 2 end, true)
assert_lane("SealSwitch fires to drop SoC back to single target", "SealSwitch",
    function() soc(true); enemy_count = 1 end, true)
assert_lane("SealSwitch blocked with SoV on a single target", "SealSwitch",
    function() sov(true); enemy_count = 1 end, false)
assert_lane("SealSwitch blocked with SoC against 2 enemies", "SealSwitch",
    function() soc(true); enemy_count = 2 end, false)
assert_lane("SealSwitch blocked with no seal up", "SealSwitch",
    function() enemy_count = 2 end, false)

print("PASS test_paladin_retribution_wotlk_strategies")
