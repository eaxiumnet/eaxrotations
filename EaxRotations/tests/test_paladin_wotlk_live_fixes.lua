-- test_paladin_wotlk_live_fixes.lua — Paladin WotLK live-fix regression tests.
-- WHAT:  Validates the WAVE 3.3 paladin wotlk fixes via matcher asserts:
--          retribution  — cooldown reads via NS.cooldown_remains (no 99 fallback),
--                         Art of War buff table { 59578, 53486 } (59579 disproven),
--                         SealSwitch cancel+recast lane (both directions + throttle);
--          holy         — Beacon of Light on a dedicated tank/self target (not the
--                         lowest-HP member), Sacred Shield self-cast/self-check;
--          protection   — Righteous Fury upkeep lane, Holy Shield charge management
--                         via NS.buff_points (Pattern 11);
--          leveling     — SoR action ladder { 25742, 21084 } + matching buff list
--                         (closes the 60+ buff mismatch and the 1-19 never-zone).
-- WHEN:  Standalone (lua test_paladin_wotlk_live_fixes.lua). NOT registered in any
--        runner — WAVE 3.5 registers the wotlk live-fix suite centrally.
-- WHY:   Proves each fixed behavior at the matches(ctx, state) level.
-- SAFETY: Pure mocks; no real API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- Stub aoe_hit_volume so the retribution/leveling install blocks load clean.
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function(ns) end }

-- ---------------------------------------------------------------------------
-- Mock NS (DSL-compatible: spell_action objects with .ids, unit-aware buff_up,
-- bank-aware cooldown_remains, rotation_registry capture).
-- ---------------------------------------------------------------------------
local unit_buffs = {}  -- [unit] = { [buff_id] = true }   (unit-scoped)
local any_buffs  = {}  -- [buff_id] = true                (unit-agnostic)
local on_cd      = {}  -- [spell_id] = seconds
local shield_points = nil  -- NS.buff_points result (number[] or nil)
local cast_log   = {}  -- { label = ..., target = ... } recorded try_cast calls
local _now       = 100

local player = {
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 80 end,
}

local function clear_buffs()
    for k in pairs(unit_buffs) do unit_buffs[k] = nil end
    for k in pairs(any_buffs) do any_buffs[k] = nil end
    for k in pairs(on_cd) do on_cd[k] = nil end
    shield_points = nil
end

local NS = {
    me = player,
    GetPlayer = function() return player end,
    spell_action = function(rank_ids, label)
        local ids = type(rank_ids) == "table" and rank_ids or { rank_ids }
        return { ids = ids, id = ids[1], label = label }
    end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function(spell, target, reason)
        cast_log[#cast_log + 1] = { label = spell and spell.label, target = target, reason = reason }
        return true
    end,
    buff_up = function(unit, ids)
        local ub = unit_buffs[unit]
        for _, id in ipairs(ids or {}) do
            if (ub and ub[id]) or any_buffs[id] then return true end
        end
        return false
    end,
    buff_points = function(unit, ids) return shield_points end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    cooldown_remains = function(spell)
        local id = type(spell) == "number" and spell or (spell and spell.ids and spell.ids[1])
        return (id and on_cd[id]) or 0
    end,
    get_spell_cooldown = function(spell)
        local id = type(spell) == "number" and spell or (spell and spell.ids and spell.ids[1])
        return (id and on_cd[id]) or 0
    end,
    time_now = function() return _now end,
    is_wotlk = function() return true end,
    should_use_long_cd = function() return true end,
    aoe_self_meets = function() return true end,
    AOE_RADIUS = { SELF_8 = 8 },
    log = function() end,
    rotation_registry = {
        _reg = {},
        register = function(self, key, strategies, opts)
            self._reg[key] = { strategies = strategies, opts = opts }
        end,
    },
}

_G.core = { time = function() return _now end, log = function() end }
_G.EaxRotations = NS

local function find_strategy(strats, name)
    for i = 1, #strats do
        if strats[i].name == name then return strats[i] end
    end
    error("strategy not found: " .. name)
end

print("=== test_paladin_wotlk_live_fixes ===")

-- ============================================================================
-- retribution_wotlk
-- ============================================================================
local ret = dofile("EaxRotations/classes/paladin/retribution_wotlk.lua")
local ret_strats = ret.strategies
local judgement = find_strategy(ret_strats, "Judgement")
local exorcism = find_strategy(ret_strats, "Exorcism")
local seal_switch = find_strategy(ret_strats, "SealSwitch")
local ret_ctx = { in_combat = true, target = {}, settings = {}, enemy_count = 1 }

-- 1a. cd_remaining never falls back to 99: state cds come from NS.cooldown_remains.
on_cd[20271] = 8  -- Judgement ladder { 20271, 53407, 53408 } — ids[1] is resolved
local ret_state = ret.build_state(ret_ctx)
assert_eq(ret_state.judgement_cd, 8, "judgement_cd must read NS.cooldown_remains (8), not 99")
assert_true(ret_state.avenging_wrath_ready, "avenging_wrath_ready must be true when no cd is set")
on_cd[31884] = 180  -- AvengingWrath single id
ret_state = ret.build_state(ret_ctx)
assert_false(ret_state.avenging_wrath_ready, "avenging_wrath_ready must be false when on cd")
on_cd[20271] = nil
on_cd[31884] = nil
ret_state = ret.build_state(ret_ctx)
assert_eq(ret_state.judgement_cd, 0, "judgement_cd must be 0 (ready) when nothing is on cd")
print("  PASS: retribution cooldown reads via NS.cooldown_remains (no 99 fallback)")

-- 1b. Art of War table: 53486 (rank-1 proc) drives Exorcism; 59579 does NOT.
any_buffs[53486] = true
ret_state = ret.build_state(ret_ctx)
assert_true(ret_state.art_of_war_proc, "Art of War rank 1 (53486) must set art_of_war_proc")
assert_true(exorcism.matches(ret_ctx, ret_state), "Exorcism must fire on Art of War (53486) proc")
clear_buffs()
any_buffs[59579] = true  -- "Burst at the Seams" — must NOT register as Art of War
ret_state = ret.build_state(ret_ctx)
assert_false(ret_state.art_of_war_proc, "59579 (Burst at the Seams) must NOT set art_of_war_proc")
clear_buffs()
print("  PASS: retribution Art of War buff table { 59578, 53486 }")

-- 1c. SealSwitch: SoV up + 2+ enemies cancels SoV (adds arrived).
any_buffs[31801] = true
_now = 100
ret_state = ret.build_state(ret_ctx)
ret_state.enemy_count = 3
assert_true(seal_switch.matches(ret_ctx, ret_state), "SealSwitch must match when SoV up and 2+ enemies")
-- throttle: immediate re-match is held 3s
assert_false(seal_switch.matches(ret_ctx, ret_state), "SealSwitch must throttle a re-match within 3s")
_now = 110
assert_true(seal_switch.matches(ret_ctx, ret_state), "SealSwitch must match again after the throttle window")
-- execute cancels by re-casting the ACTIVE seal (SoV), target nil = self
seal_switch.execute(ret_ctx, ret_state)
assert_eq(cast_log[#cast_log].label, "SealOfVengeance", "SealSwitch execute must re-cast SoV to cancel")
assert_eq(cast_log[#cast_log].target, nil, "SealSwitch cancel must self-cast")
-- reverse direction: SoC up + single enemy cancels SoC so SoV re-applies
clear_buffs()
any_buffs[27170] = true
_now = 120
ret_state = ret.build_state(ret_ctx)
ret_state.enemy_count = 1
assert_true(seal_switch.matches(ret_ctx, ret_state), "SealSwitch must match when SoC up and 1 enemy")
seal_switch.execute(ret_ctx, ret_state)
assert_eq(cast_log[#cast_log].label, "SealOfCommand", "SealSwitch execute must re-cast SoC to cancel")
-- SoC up with 2+ enemies: no switch needed
ret_state.enemy_count = 3
_now = 130
assert_false(seal_switch.matches(ret_ctx, ret_state), "SealSwitch must not match when SoC up and 2+ enemies")
-- setting off
clear_buffs()
any_buffs[31801] = true
_now = 140
local ret_off = { in_combat = true, target = {}, settings = { ret_seal_switch = false }, enemy_count = 1 }
local off_state = ret.build_state(ret_off)
off_state.enemy_count = 3
assert_false(seal_switch.matches(ret_off, off_state), "SealSwitch must respect ret_seal_switch=false")
clear_buffs()
print("  PASS: retribution SealSwitch cancel+recast lane (both directions, throttle, setting)")

-- ============================================================================
-- holy_wotlk
-- ============================================================================
local holy = dofile("EaxRotations/classes/paladin/holy_wotlk.lua")
local holy_strats = holy.strategies
local beacon = find_strategy(holy_strats, "BeaconOfLight")
local sacred_shield = find_strategy(holy_strats, "SacredShield")
local holy_light = find_strategy(holy_strats, "HolyLight")

local tank = { get_group_role = function() return "tank" end, get_health_percentage = function() return 100 end }
local lowest = { get_health_percentage = function() return 35 end }
local holy_ctx = {
    in_combat = true,
    target = {},
    settings = {},
    enemy_count = 1,
    party_members = { lowest, tank },
    lowest = { unit = lowest, hp = 35 },
}

-- 2a. Beacon is checked + cast on the DEDICATED tank (not the lowest member).
clear_buffs()
unit_buffs[tank] = { [53563] = true }   -- tank carries the Beacon
local hstate = holy.build_state(holy_ctx)
assert_eq(hstate.beacon_target, tank, "beacon target must be the party tank (not the lowest member)")
assert_true(hstate.beacon_up, "beacon_up must read the TANK's buff (no bounce to lowest)")
cast_log = {}
assert_true(beacon.execute(holy_ctx, hstate), "BeaconOfLight must execute")
assert_eq(cast_log[#cast_log].target, tank, "BeaconOfLight execute must target the tank")
-- without a tank in party: fall back to SELF, and beacon_up reads self
clear_buffs()
unit_buffs[player] = { [53563] = true }
local hstate2 = holy.build_state({ in_combat = true, target = {}, settings = {}, party_members = { lowest }, lowest = { unit = lowest, hp = 35 } })
assert_eq(hstate2.beacon_target, player, "beacon target must fall back to self when no tank is flagged")
assert_true(hstate2.beacon_up, "beacon_up must read SELF's buff when no tank exists")
clear_buffs()
print("  PASS: holy Beacon on dedicated tank/self target")

-- 2b. Sacred Shield is SELF-checked + self-cast (never bounced to lowest).
unit_buffs[player] = { [53601] = true }
local hstate3 = holy.build_state(holy_ctx)
assert_true(hstate3.sacred_shield_up, "sacred_shield_up must read SELF (the lowest member has no SS)")
-- lowest member with SS but self without → still DOWN (3.3.5 self-only)
clear_buffs()
unit_buffs[lowest] = { [53601] = true }
local hstate4 = holy.build_state(holy_ctx)
assert_false(hstate4.sacred_shield_up, "a lowest-member Sacred Shield must NOT satisfy the self check")
cast_log = {}
assert_true(sacred_shield.execute(holy_ctx, hstate4), "SacredShield must execute")
assert_eq(cast_log[#cast_log].target, nil, "SacredShield execute must self-cast (nil target)")
clear_buffs()
print("  PASS: holy Sacred Shield self-check + self-cast")

-- 2c. Healing lanes still target the lowest friendly (unchanged).
unit_buffs[lowest] = nil
hstate = holy.build_state(holy_ctx)
assert_eq(hstate.target_hp, 35, "target_hp must still score the lowest friendly")
cast_log = {}
assert_true(holy_light.execute(holy_ctx, hstate), "HolyLight must execute")
assert_eq(cast_log[#cast_log].target, lowest, "HolyLight must target the lowest friendly")
print("  PASS: holy healing lanes unchanged (lowest-friendly target)")

-- ============================================================================
-- protection_wotlk
-- ============================================================================
local prot = dofile("EaxRotations/classes/paladin/protection_wotlk.lua")
local prot_strats = prot.strategies
local rf = find_strategy(prot_strats, "RighteousFury")
local hs = find_strategy(prot_strats, "HolyShield")
local prot_ctx = { in_combat = true, target = {}, settings = {}, enemy_count = 1 }

-- 3a. Righteous Fury: fires when down, holds when up.
_now = 100
local pstate = prot.build_state(prot_ctx)
assert_false(pstate.righteous_fury_up, "righteous_fury_up must be false with no buff")
assert_true(rf.matches(prot_ctx, pstate), "RighteousFury must fire when the buff is down")
assert_false(rf.matches(prot_ctx, pstate), "RighteousFury must throttle a re-match within 3s")
any_buffs[25780] = true
_now = 110
pstate = prot.build_state(prot_ctx)
assert_true(pstate.righteous_fury_up, "righteous_fury_up must be true with the buff up")
assert_false(rf.matches(prot_ctx, pstate), "RighteousFury must not fire when the buff is up")
clear_buffs()
print("  PASS: protection Righteous Fury upkeep lane")

-- 3b. Holy Shield charge management (Pattern 11 buff_points).
any_buffs[48927] = true  -- Holy Shield up
shield_points = { 5 }    -- 5 blocks remaining > refresh floor (2) → hold
_now = 120
pstate = prot.build_state(prot_ctx)
assert_eq(pstate.holy_shield_charges, 5, "holy_shield_charges must read buff.points[1] (5)")
assert_false(hs.matches(prot_ctx, pstate), "HolyShield must NOT refresh with 5 charges (> floor 2)")
shield_points = { 1 }    -- 1 block left <= floor → refresh
pstate = prot.build_state(prot_ctx)
assert_true(hs.matches(prot_ctx, pstate), "HolyShield must refresh when charges drop to the floor")
shield_points = nil      -- buff up but charges unknown → refresh conservatively
pstate = prot.build_state(prot_ctx)
assert_true(hs.matches(prot_ctx, pstate), "HolyShield must refresh when charges are unknown (0)")
clear_buffs()
print("  PASS: protection Holy Shield charge management (buff_points)")

-- ============================================================================
-- leveling_wotlk
-- ============================================================================
local lvl = dofile("EaxRotations/classes/paladin/leveling_wotlk.lua")
local lvl_strats = lvl.strategies
local seal = find_strategy(lvl_strats, "Seal")
local lvl_ctx = { in_combat = true, target = {}, settings = {}, enemy_count = 1 }

-- 4a. seal_up registers the rank a 60+ cast applies (25742) AND rank 1 (21084).
any_buffs[25742] = true  -- buff applied by a max-rank cast
local lstate = lvl.build_state(lvl_ctx)
assert_true(lstate.seal_up, "seal_up must register buff 25742 (60+ SoR rank) — fixes the mismatch")
clear_buffs()
any_buffs[21084] = true  -- buff applied by a low-level cast
lstate = lvl.build_state(lvl_ctx)
assert_true(lstate.seal_up, "seal_up must register buff 21084 (rank 1)")
clear_buffs()
print("  PASS: leveling seal buff list { 25742, 21084 }")

-- 4b. Seal lane reaches SoR when SoV/SoC are not castable (1-19 never-zone fix).
local orig_try_cast = NS.try_cast
NS.try_cast = function(spell, target, reason)
    cast_log[#cast_log + 1] = { label = spell and spell.label, target = target, reason = reason }
    -- SoV/SoC unlearned at low level; SoR is the fallback that succeeds
    if spell and (spell.label == "SealOfVengeance" or spell.label == "SealOfCommand") then return false end
    return true
end
clear_buffs()          -- no seal up: rebuild state so seal_up reads false
lstate = lvl.build_state(lvl_ctx)
assert_false(lstate.seal_up, "seal_up must be false with no seal buffs (4b precondition)")
cast_log = {}
assert_true(seal.matches(lvl_ctx, lstate), "Seal lane must match with no seal up and mana >= 5")
assert_true(seal.execute(lvl_ctx, lstate), "Seal lane must execute")
assert_eq(cast_log[#cast_log].label, "SealOfRighteousness", "Seal lane must fall through to SoR at low levels")
NS.try_cast = orig_try_cast
print("  PASS: leveling Seal lane SoR fallback (1-19 never-zone closed)")

-- ============================================================================
-- W3.4 mana-chain regression (2026-08-13): state.mana_pct must come from the
-- REAL chain — context.mana_pct (dispatcher-set, main_sylvanas.lua:795) →
-- me:mana_pct() (IZI SDK unit method) → NS.unit_mana_pct(me) → 100.
-- me:get_mana_percentage() is MOCK-ONLY (W3.4 tripwire in the battery); the
-- test player keeps it returning 80 so the precedence assertions prove the
-- context/IZI paths win over the dead mock method.
-- ============================================================================
player.mana_pct = function() return 55 end  -- IZI SDK unit method
NS.unit_mana_pct = function(unit) return 66 end
local ret_divine_plea = find_strategy(ret_strats, "DivinePlea")

-- 5a. context.mana_pct wins over both unit methods (retri DivinePlea fires).
clear_buffs()
local mana_ctx = { in_combat = true, target = {}, settings = {}, enemy_count = 1, mana_pct = 35 }
local mstate = ret.build_state(mana_ctx)
assert_eq(mstate.mana_pct, 35, "retri mana_pct must prefer context.mana_pct (35), not unit methods (55/80)")
assert_true(ret_divine_plea.matches(mana_ctx, mstate), "retri DivinePlea must fire at mana 35 via the real chain")

-- 5b. no context.mana_pct → me:mana_pct() (IZI SDK).
local mana_ctx2 = { in_combat = true, target = {}, settings = {}, enemy_count = 1 }
mstate = ret.build_state(mana_ctx2)
assert_eq(mstate.mana_pct, 55, "retri mana_pct must fall back to me:mana_pct() (55)")

-- 5c. no unit method → NS.unit_mana_pct.
local orig_player_mana_pct = player.mana_pct
player.mana_pct = nil
mstate = ret.build_state(mana_ctx2)
assert_eq(mstate.mana_pct, 66, "retri mana_pct must fall back to NS.unit_mana_pct (66)")

-- 5d. everything nil → 100.
local orig_ns_unit_mana_pct = NS.unit_mana_pct
NS.unit_mana_pct = nil
mstate = ret.build_state(mana_ctx2)
assert_eq(mstate.mana_pct, 100, "retri mana_pct must default to 100 when every source is absent")
player.mana_pct = orig_player_mana_pct
NS.unit_mana_pct = orig_ns_unit_mana_pct

-- 5e. same context-first chain in the other three paladin wotlk files.
local hstate5 = holy.build_state({ in_combat = true, target = {}, settings = {}, party_members = {}, lowest = { unit = nil, hp = 100 }, mana_pct = 35 })
assert_eq(hstate5.mana_pct, 35, "holy mana_pct must prefer context.mana_pct (35)")
local pstate5 = prot.build_state({ in_combat = true, target = {}, settings = {}, enemy_count = 1, mana_pct = 35 })
assert_eq(pstate5.mana_pct, 35, "protection mana_pct must prefer context.mana_pct (35)")
local lstate5 = lvl.build_state({ in_combat = true, target = {}, settings = {}, enemy_count = 1, mana_pct = 35 })
assert_eq(lstate5.mana_pct, 35, "leveling mana_pct must prefer context.mana_pct (35)")
print("  PASS: W3.4 mana chain (context -> me:mana_pct() -> NS.unit_mana_pct -> 100) in all 4 paladin wotlk files")

print("PASS test_paladin_wotlk_live_fixes")
