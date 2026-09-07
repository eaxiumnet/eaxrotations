-- test_deathknight_unholy_wotlk_strategies.lua — Unholy DK WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL unholy_wotlk.lua DSL lanes, pinning both sides of
--        each unpinned gate: disease maintenance (Icy Touch / Plague Strike /
--        Pestilence pack spread), Scourge Strike disease requirement, Death
--        and Decay AoE, the Death Coil high (100) and dump (40) runic-power
--        gates, Empower Rune Weapon's all-runes-recharging gate (through the
--        real rune_manager snapshot), Raise Dead / Bone Shield pet & buff
--        upkeep, Summon Gargoyle boss+RP+long-CD commit, the Ghoul Gnaw /
--        Ghoul Leap pet-command lanes, and the Unholy Presence auto-switch.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): unholy_wotlk's non-boss lanes
--        (diseases, strikes, AoE, RP spend) had no behavioral coverage.
-- SAFETY: Pure unit tests with a mocked NS + engine rune-slot API; the real
--         unholy_wotlk.lua and real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local function make_action(ids, label)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        id = id,
        ids = type(ids) == "table" and ids or { ids },
        name = label or tostring(id),
        cast_safe = function(self, target) return true end,
        cooldown_remaining = function(self) return 0 end,
        can_cast = function(self, target) return true end,
        is_learned = function(self) return true end,
    }
end

-- Mutable scenario state.
local rp = 0
local ff = 0
local bp = 0
local combat = true
local longcd = true
local pet = false
local boss = false
local casting = false
local dist = 0
local aoe_hits = 0
local now = 0
local buffs = {}

-- Engine rune-slot model (1=blood, 2=unholy, 3=frost, 4=death).
local rune_slots = {
    { 1, true }, { 1, true },
    { 3, true }, { 3, true },
    { 2, true }, { 2, true },
}

_G.core = {
    spell_book = {
        get_rune_type = function(slot)
            local row = rune_slots[slot]
            return row and row[1] or nil
        end,
        get_rune_info = function(slot)
            local row = rune_slots[slot]
            return { ready = (row and row[2]) or false, start = 0, duration = 10 }
        end,
        is_rune_slot_active = function(slot) return true end,
    },
}

local RUNE = { blood = 1, unholy = 2, frost = 3, death = 4 }

local function set_runes(blood, frost, unholy, death)
    local slots = {}
    local function add(count, type_idx)
        for i = 1, count do slots[#slots + 1] = { type_idx, true } end
    end
    add(blood, RUNE.blood)
    add(frost, RUNE.frost)
    add(unholy, RUNE.unholy)
    add(death, RUNE.death)
    while #slots < 6 do slots[#slots + 1] = { RUNE.blood, false } end
    rune_slots = slots
end

local function set_buff(id, up) buffs[id] = up or nil end

local me = {
    get_health_percentage = function() return 100 end,
    get_power = function(self, power_type)
        if power_type == 6 then return rp end
        return 0
    end,
}

local function reset_env()
    rp, ff, bp = 0, 0, 0
    combat, longcd, pet, boss, casting, dist, aoe_hits = true, true, false, false, false, 0, 0
    now = now + 3      -- force the rune snapshot TTL to expire each scenario
    buffs = {}
    set_runes(2, 2, 2, 0)
end

_G.EaxRotations = {
    DeathKnightSpells = {
        IcyTouch = make_action({ 49909, 45477, 49903, 49904 }, "IcyTouch"),
        PlagueStrike = make_action({ 49921, 49917, 49918, 49919, 49920 }, "PlagueStrike"),
        ScourgeStrike = make_action({ 55271, 55090, 55265, 55270 }, "ScourgeStrike"),
        BloodStrike = make_action({ 49930, 45902, 49926, 49927, 49928, 49929 }, "BloodStrike"),
        DeathCoil = make_action({ 49895, 47541, 49892, 49893, 49894 }, "DeathCoil"),
        Pestilence = make_action(50842, "Pestilence"),
        DeathAndDecay = make_action({ 49938, 43265, 49936, 49937 }, "DeathAndDecay"),
        SummonGargoyle = make_action(49206, "SummonGargoyle"),
        HornOfWinter = make_action({ 57623, 57330 }, "HornOfWinter"),
        EmpowerRuneWeapon = make_action(47568, "EmpowerRuneWeapon"),
        BoneShield = make_action(49222, "BoneShield"),
        RaiseDead = make_action(46584, "RaiseDead"),
        BloodPresence = make_action(48266, "BloodPresence"),
        FrostPresence = make_action(48263, "FrostPresence"),
        UnholyPresence = make_action(48265, "UnholyPresence"),
        GhoulGnaw = make_action(47481, "GhoulGnaw"),
        GhoulLeap = make_action(47482, "GhoulLeap"),
        MindFreeze = make_action(47528, "MindFreeze"),
    },
    POWER_RUNICPOWER = 6,
    me = me,
    GetPlayer = function() return me end,
    is_wotlk = function() return true end,
    time_now = function() return now end,
    has_pet = function() return pet end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    debuff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if id == 55095 then return ff end
            if id == 55078 then return bp end
        end
        return 0
    end,
    should_use_long_cd = function(context, cd) return longcd end,
    try_cast = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/deathknight/unholy_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "unholy_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        target = { get_health_percentage = function() return 100 end },
        settings = {},
        _aoe_hit_count = aoe_hits,
        target_is_boss = boss,
        target_casting = casting,
        target_distance = dist,
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
-- Buff upkeep: Horn of Winter and Bone Shield.
-- ============================================================================
assert_lane("HornOfWinter fires with the buff down", "HornOfWinter", function() end, true)
assert_lane("HornOfWinter blocked while buff is up", "HornOfWinter",
    function() set_buff(57623, true) end, false)
assert_lane("BoneShield fires with the buff down", "BoneShield", function() end, true)
assert_lane("BoneShield blocked while buff is up", "BoneShield",
    function() set_buff(49222, true) end, false)

-- ============================================================================
-- Raise Dead: only when no ghoul is present.
-- ============================================================================
assert_lane("RaiseDead fires with no pet up", "RaiseDead", function() end, true)
assert_lane("RaiseDead blocked while the ghoul is present", "RaiseDead",
    function() pet = true end, false)

-- ============================================================================
-- Summon Gargoyle: boss target + 60 RP + long-CD consent.
-- ============================================================================
assert_lane("SummonGargoyle fires on a boss at 60+ RP", "SummonGargoyle",
    function() boss = true; rp = 60 end, true)
assert_lane("SummonGargoyle blocked on a non-boss target", "SummonGargoyle",
    function() boss = false; rp = 100 end, false)
assert_lane("SummonGargoyle blocked below 60 RP on a boss", "SummonGargoyle",
    function() boss = true; rp = 59 end, false)
assert_lane("SummonGargoyle blocked when long-CD gate refuses", "SummonGargoyle",
    function() boss = true; rp = 100; longcd = false end, false)

-- ============================================================================
-- Empower Rune Weapon: fires when every rune is recharging (0 ready) — via
-- the real rune snapshot (2s TTL expired each scenario).
-- ============================================================================
assert_lane("EmpowerRuneWeapon fires with all runes recharging",
    "EmpowerRuneWeapon", function() set_runes(0, 0, 0, 0) end, true)
assert_lane("EmpowerRuneWeapon blocked while a rune is ready", "EmpowerRuneWeapon",
    function() set_runes(1, 0, 0, 0) end, false)
assert_lane("EmpowerRuneWeapon blocked when long-CD gate refuses", "EmpowerRuneWeapon",
    function() set_runes(0, 0, 0, 0); longcd = false end, false)

-- ============================================================================
-- Disease maintenance (refresh under 3s) and Pestilence pack spread (both
-- diseases up, one about to expire, 2+ targets within 10yd).
-- ============================================================================
assert_lane("IcyTouch fires when Frost Fever is down", "IcyTouch", function() end, true)
assert_lane("IcyTouch blocked while Frost Fever is healthy", "IcyTouch",
    function() ff = 10 end, false)
assert_lane("PlagueStrike fires when Blood Plague is down", "PlagueStrike", function() end, true)
assert_lane("PlagueStrike blocked while Blood Plague is healthy", "PlagueStrike",
    function() bp = 10 end, false)
assert_lane("Pestilence spreads on a pack when a disease is expiring", "Pestilence",
    function() ff = 10; bp = 1; aoe_hits = 2 end, true)
assert_lane("Pestilence blocked while both diseases are healthy", "Pestilence",
    function() ff = 10; bp = 10; aoe_hits = 5 end, false)
assert_lane("Pestilence blocked single-target when a disease is expiring", "Pestilence",
    function() ff = 10; bp = 1; aoe_hits = 1 end, false)

-- ============================================================================
-- Death Coil spend gates: 100 for the priority dump, 40 for the filler dump.
-- ============================================================================
assert_lane("DeathCoil fires at 100 RP", "DeathCoil", function() rp = 100 end, true)
assert_lane("DeathCoil blocked below 100 RP", "DeathCoil", function() rp = 99 end, false)
assert_lane("DeathCoilDump fires at 40+ RP", "DeathCoilDump", function() rp = 40 end, true)
assert_lane("DeathCoilDump blocked below 40 RP", "DeathCoilDump", function() rp = 39 end, false)

-- ============================================================================
-- Death and Decay: ground AoE at 2+ targets within 10yd.
-- ============================================================================
assert_lane("DeathAndDecay fires at 2 AoE targets", "DeathAndDecay",
    function() aoe_hits = 2 end, true)
assert_lane("DeathAndDecay blocked single-target", "DeathAndDecay",
    function() aoe_hits = 1 end, false)

-- ============================================================================
-- Scourge Strike: requires both diseases on the target.
-- ============================================================================
assert_lane("ScourgeStrike fires with both diseases up", "ScourgeStrike",
    function() ff = 10; bp = 10 end, true)
assert_lane("ScourgeStrike blocked with Frost Fever down", "ScourgeStrike",
    function() bp = 10 end, false)
assert_lane("ScourgeStrike blocked with Blood Plague down", "ScourgeStrike",
    function() ff = 10 end, false)

-- ============================================================================
-- Blood Strike filler: unconditional.
-- ============================================================================
assert_lane("BloodStrike fires as the unconditional filler", "BloodStrike",
    function() combat = false end, true)

-- ============================================================================
-- Ghoul command lanes: Gnaw interrupts a casting target; Leap closes range.
-- ============================================================================
assert_lane("GhoulGnaw fires on a casting target with the ghoul up",
    "GhoulGnaw", function() pet = true; casting = true end, true)
assert_lane("GhoulGnaw blocked when the target is not casting", "GhoulGnaw",
    function() pet = true; casting = false end, false)
assert_lane("GhoulGnaw blocked with no ghoul", "GhoulGnaw",
    function() pet = false; casting = true end, false)
assert_lane("GhoulLeap fires at 8+ yd with the ghoul up", "GhoulLeap",
    function() pet = true; dist = 8 end, true)
assert_lane("GhoulLeap blocked in melee range", "GhoulLeap",
    function() pet = true; dist = 5 end, false)
assert_lane("GhoulLeap blocked with no ghoul", "GhoulLeap",
    function() pet = false; dist = 20 end, false)

-- ============================================================================
-- Unholy Presence auto-switch: unholy spec wants Unholy Presence; no switch
-- when it is already up.
-- ============================================================================
assert_lane("Presence fires toward Unholy from Blood Presence", "Presence",
    function() set_buff(48266, true) end, true)
assert_lane("Presence blocked while Unholy Presence is up", "Presence",
    function() set_buff(48265, true) end, false)

print("PASS test_deathknight_unholy_wotlk_strategies")
