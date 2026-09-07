-- test_frost_deathknight_wotlk_strategies.lua — Frost DK WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL frost_wotlk.lua against the REAL rune_manager: the
--        engine-backed per-slot rune state (type + ready, death-rune
--        conversion via type 4) feeds the Obliterate and Blood Strike rune
--        gates, pinning both sides of each lane — including the Obliterate
--        slot-accounting fix (a lone death rune must NOT pay both the frost
--        and unholy requirements). Also pins disease refresh, Killing Machine
--        Frost Strike, Rime / AoE Howling Blast, Horn of Winter, Unbreakable
--        Armor, Empower Rune Weapon, and the Frost Presence auto-switch.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): the rune gates were only ever
--        tested against a wrong-shaped rune stub, so the real rune_manager
--        was never driven and the Obliterate double-count bug went live.
-- SAFETY: Pure unit tests with a mocked NS + mocked engine rune-slot API; the
--         real frost_wotlk.lua and real shared modules load.

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
local hp = 100
local target_hp = 100
local rp = 0
local ff = 0
local bp = 0
local combat = true
local longcd = true
local ua_cd = 0
local erw_cd = 0
local aoe_hits = 0
local buffs = {}

-- Engine rune-slot model (rune_manager maps 1=blood, 2=unholy, 3=frost,
-- 4=death). Each entry is { type_index, ready } for slot 1..6.
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

-- Rebuild the six slots so exactly the given counts are ready.
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
    get_health_percentage = function() return hp end,
    get_power = function(self, power_type)
        if power_type == 6 then return rp end
        return 0
    end,
}

local function reset_env()
    hp, target_hp, rp, ff, bp = 100, 100, 0, 0, 0
    combat, longcd, ua_cd, erw_cd, aoe_hits = true, true, 0, 0, 0
    buffs = {}
    set_runes(2, 2, 2, 0)
end

_G.EaxRotations = {
    DeathKnightSpells = {
        IcyTouch = make_action({ 49909, 45477, 49903, 49904 }, "IcyTouch"),
        PlagueStrike = make_action({ 49921, 49917, 49918, 49919, 49920 }, "PlagueStrike"),
        Obliterate = make_action({ 51425, 49020, 51423, 51424 }, "Obliterate"),
        HowlingBlast = make_action({ 51411, 49184, 51409, 51410 }, "HowlingBlast"),
        FrostStrike = make_action({ 55268, 49143, 51414, 51415, 51416, 51417, 51418, 51419, 51420, 51421 }, "FrostStrike"),
        BloodStrike = make_action({ 49930, 45902, 49926, 49927, 49928, 49929 }, "BloodStrike"),
        HornOfWinter = make_action({ 57623, 57330 }, "HornOfWinter"),
        UnbreakableArmor = make_action(51271, "UnbreakableArmor"),
        EmpowerRuneWeapon = make_action(47568, "EmpowerRuneWeapon"),
        MindFreeze = make_action(47528, "MindFreeze"),
        FrostPresence = make_action(48263, "FrostPresence"),
        BloodPresence = make_action(48266, "BloodPresence"),
        UnholyPresence = make_action(48265, "UnholyPresence"),
    },
    POWER_RUNICPOWER = 6,
    me = me,
    GetPlayer = function() return me end,
    is_wotlk = function() return true end,
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
    cooldown_remains = function(action)
        if action and action.name == "UnbreakableArmor" then return ua_cd end
        if action and action.name == "EmpowerRuneWeapon" then return erw_cd end
        return 0
    end,
    try_cast = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/deathknight/frost_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "frost_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        target = { get_health_percentage = function() return target_hp end },
        settings = {},
        _aoe_hit_count = aoe_hits,
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
-- Disease maintenance (refresh under 3s).
-- ============================================================================
assert_lane("IcyTouch fires when Frost Fever is down", "IcyTouch", function() end, true)
assert_lane("IcyTouch blocked while Frost Fever is healthy", "IcyTouch",
    function() ff = 10 end, false)
assert_lane("PlagueStrike fires when Blood Plague is down", "PlagueStrike", function() end, true)
assert_lane("PlagueStrike blocked while Blood Plague is healthy", "PlagueStrike",
    function() bp = 10 end, false)

-- ============================================================================
-- Obliterate: needs 1 frost + 1 unholy slot, with death runes substituting
-- for either — but ONE death rune can only pay ONE slot. Driven through the
-- real rune_manager, so these are genuine slot counts.
-- ============================================================================
assert_lane("Obliterate fires with 1 frost + 1 unholy ready", "Obliterate",
    function() ff = 10; bp = 10; set_runes(0, 1, 1, 0) end, true)
assert_lane("Obliterate fires with 1 frost + 1 death (death pays unholy)", "Obliterate",
    function() ff = 10; bp = 10; set_runes(0, 1, 0, 1) end, true)
assert_lane("Obliterate fires with 1 unholy + 1 death (death pays frost)", "Obliterate",
    function() ff = 10; bp = 10; set_runes(0, 0, 1, 1) end, true)
assert_lane("Obliterate fires with 2 death runes only", "Obliterate",
    function() ff = 10; bp = 10; set_runes(0, 0, 0, 2) end, true)
assert_lane("Obliterate blocked by a lone death rune (one slot only)", "Obliterate",
    function() ff = 10; bp = 10; set_runes(0, 0, 0, 1) end, false)
assert_lane("Obliterate blocked with only 1 frost rune", "Obliterate",
    function() ff = 10; bp = 10; set_runes(0, 1, 0, 0) end, false)
assert_lane("Obliterate blocked with no runes at all", "Obliterate",
    function() ff = 10; bp = 10; set_runes(0, 0, 0, 0) end, false)
assert_lane("Obliterate blocked while Frost Fever is down", "Obliterate",
    function() ff = 0; bp = 10; set_runes(0, 1, 1, 0) end, false)
assert_lane("Obliterate blocked while Blood Plague is down", "Obliterate",
    function() ff = 10; bp = 0; set_runes(0, 1, 1, 0) end, false)

-- ============================================================================
-- Blood Strike filler: needs a blood rune (death substitutes).
-- ============================================================================
assert_lane("BloodStrike fires with a blood rune ready", "BloodStrike",
    function() set_runes(1, 0, 0, 0) end, true)
assert_lane("BloodStrike fires with a death rune ready", "BloodStrike",
    function() set_runes(0, 0, 0, 1) end, true)
assert_lane("BloodStrike blocked with no blood-family rune", "BloodStrike",
    function() set_runes(0, 1, 1, 0) end, false)

-- ============================================================================
-- Frost Strike: Killing Machine window needs 40 RP; the plain lane spends
-- 40 RP only (no KM requirement).
-- ============================================================================
assert_lane("FrostStrikeKM fires in a Killing Machine window at 40 RP",
    "FrostStrikeKM", function() set_buff(51124, true); rp = 40 end, true)
assert_lane("FrostStrikeKM blocked at 39 RP in the window", "FrostStrikeKM",
    function() set_buff(51124, true); rp = 39 end, false)
assert_lane("FrostStrikeKM blocked outside the window at 100 RP", "FrostStrikeKM",
    function() rp = 100 end, false)
assert_lane("FrostStrike fires at 40+ RP", "FrostStrike", function() rp = 40 end, true)
assert_lane("FrostStrike blocked below 40 RP", "FrostStrike", function() rp = 39 end, false)

-- ============================================================================
-- Howling Blast: Rime proc always fires; otherwise AoE (3+ targets within
-- 10yd of target) while Frost Fever is up.
-- ============================================================================
assert_lane("HowlingBlast fires on a Rime proc with no diseases", "HowlingBlast",
    function() set_buff(59052, true); ff = 0 end, true)
assert_lane("HowlingBlast fires at 3 AoE targets with Frost Fever up",
    "HowlingBlast", function() ff = 10; aoe_hits = 3 end, true)
assert_lane("HowlingBlast blocked at 2 AoE targets", "HowlingBlast",
    function() ff = 10; aoe_hits = 2 end, false)
assert_lane("HowlingBlast blocked single-target without Rime", "HowlingBlast",
    function() ff = 10; aoe_hits = 1 end, false)
assert_lane("HowlingBlast blocked single-target with Frost Fever down",
    "HowlingBlast", function() ff = 0; aoe_hits = 5 end, false)

-- ============================================================================
-- Horn of Winter upkeep.
-- ============================================================================
assert_lane("HornOfWinter fires with the buff down", "HornOfWinter", function() end, true)
assert_lane("HornOfWinter blocked while buff is up", "HornOfWinter",
    function() set_buff(57623, true) end, false)

-- ============================================================================
-- Unbreakable Armor: combat + buff down + cooldown ready + long-CD consent.
-- ============================================================================
assert_lane("UnbreakableArmor fires in combat with the buff down",
    "UnbreakableArmor", function() end, true)
assert_lane("UnbreakableArmor blocked while the buff is up", "UnbreakableArmor",
    function() set_buff(51271, true) end, false)
assert_lane("UnbreakableArmor blocked while on cooldown", "UnbreakableArmor",
    function() ua_cd = 60 end, false)
assert_lane("UnbreakableArmor blocked when long-CD gate refuses", "UnbreakableArmor",
    function() longcd = false end, false)
assert_lane("UnbreakableArmor blocked out of combat", "UnbreakableArmor",
    function() combat = false end, false)

-- ============================================================================
-- Empower Rune Weapon: fires when every rune is recharging (0 ready) and the
-- cooldown is available; never with any rune ready.
-- ============================================================================
assert_lane("EmpowerRuneWeapon fires with all runes recharging",
    "EmpowerRuneWeapon", function() set_runes(0, 0, 0, 0) end, true)
assert_lane("EmpowerRuneWeapon blocked while a rune is ready", "EmpowerRuneWeapon",
    function() set_runes(1, 0, 0, 0) end, false)
assert_lane("EmpowerRuneWeapon blocked while on cooldown", "EmpowerRuneWeapon",
    function() set_runes(0, 0, 0, 0); erw_cd = 300 end, false)
assert_lane("EmpowerRuneWeapon blocked when long-CD gate refuses", "EmpowerRuneWeapon",
    function() set_runes(0, 0, 0, 0); longcd = false end, false)

-- ============================================================================
-- Frost Presence auto-switch: with presence_mode auto and Blood Presence up
-- (default), the switch fires; never when Frost Presence is already up.
-- ============================================================================
assert_lane("FrostPresence fires from Blood Presence in auto mode",
    "FrostPresence", function() set_buff(48266, true) end, true)
assert_lane("FrostPresence blocked while Frost Presence is up", "FrostPresence",
    function() set_buff(48263, true) end, false)

print("PASS test_frost_deathknight_wotlk_strategies")
