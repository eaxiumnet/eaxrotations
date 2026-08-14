-- test_priest_vanilla_live_fixes.lua -- Priest vanilla live-game defect regressions.
-- WHAT:  standalone regression test for the WAVE 1.3 vanilla fixer batch:
--        mock-only NS members replaced with live APIs, era-correct gating,
--        and dead/duplicate lane resolution in the five priest vanilla files.
-- WHEN:  run standalone: lua EaxRotations/tests/test_priest_vanilla_live_fixes.lua
--        (registered in run_rotation_tests.lua, Wave 1.5 close-out).
-- WHY:   the audit wave found these defects via static analysis; this test
--        pins the fixed behaviors at the matcher/execute level.
-- SAFETY: Pure unit test with a mocked _G.EaxRotations; no engine API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

-- Lua 5.4 compat: global unpack moved to table.unpack
local unpack = table.unpack or unpack

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
local function assert_not_nil(v, label) if v == nil then error(label or "assert_not_nil failed", 2) end end

package.loaded["common/enums"] = { class_id = { PRIEST = 5 } }

-- ============================================================================
-- Mock NS shared by all five spec files. Function bodies are swapped in-place
-- by the execute-level assertions (specs capture `NS` at load time).
-- ============================================================================
local calls = { cancel_spells = 0, start_auto_attack = {}, is_threat_safe = {}, stop_casting = 0, cancel_current_cast = 0, start_attack = 0 }

local mock_player = {
    get_class = function() return 5 end,
    get_race_id = function() return 1 end,
    is_mounted = function() return false end,
    is_moving = function() return false end,
    mana_pct = function() return 100 end,
    is_channeling = function() return false end,
    is_casting = function() return false end,
    get_guid = function() return "player-guid" end,
}

local function make_target(casting)
    return {
        get_guid = function() return "target-guid" end,
        is_casting = function() return casting == true end,
        is_channeling = function() return false end,
        is_valid = function() return true end,
        is_alive = function() return true end,
        get_creature_type = function() return 7 end,  -- not undead
        get_target = function() return nil end,
    }
end

local heal_entries = {
    { unit = make_target(false), effective_hp = 55, is_tank = true, has_renew = false, has_weakened_soul = false, is_player = false },
    { unit = make_target(false), effective_hp = 85, is_tank = false, has_renew = false, has_weakened_soul = false, is_player = false },
}

local NS = {
    CLASS_ID = { PRIEST = 5 },
    PLAYER_UNIT = {},
    PriestSpells = {
        AbolishDisease = 552, CureDisease = 528, DesperatePrayer = 19236,
        DevouringPlague = 2944, DispelMagic = 988, DivineSpirit = 14752,
        Fade = 586, FearWard = 6346, FlashHeal = 2061, GreaterHeal = 2060,
        HolyFire = 14914, HolyNova = 15237, InnerFire = 588, InnerFocus = 14751,
        Lightwell = 731, MindBlast = 8092, MindFlay = 15407,
        PowerInfusion = 10060, PowerWordFortitude = 1244, PowerWordShield = 17,
        PrayerOfHealing = 596, PsychicScream = 8122, Renew = 139,
        ShackleUndead = 9484, Shadowform = 15473, ShadowWordPain = 589,
        Silence = 15487, Smite = 585, Starshards = 10797,
        VampiricEmbrace = 15286, Berserking = 26297, BloodFury = 20572,
        ArcaneTorrent = 25046, ShadowWordDeath = 32379, Shadowfiend = 34433,
        UnavailableClassicPriestHealA = 32546,
    },
    PriestFLASH_HEAL_RANKS = {}, PriestGREATER_HEAL_RANKS = {},
    PriestPRAYER_OF_HEALING_RANKS = {}, PriestBINDING_HEAL_RANKS = {},
    AUTO_ATTACK_WAND = 5019,
    AOE_RADIUS = { SELF_10 = 10 },
    cast_best_heal_rank = function(_, target, _ctx, label) return { id = 1 }, label end,
    GetPlayer = function() return mock_player end,
    get_local_player = function() return mock_player end,
    GetTarget = function() return make_target(false) end,
    GetEnemiesCount = function() return 0 end,
    GetEnemiesInRange = function() return {} end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    has_debuff = function() return false end,
    get_debuff_stacks = function() return 0 end,
    has_player_buff = function() return false end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    use_item_by_id = function() return true end,
    is_item_ready = function() return false end,
    cooldown_remains = function() return 0 end,
    same_unit = function() return false end,
    unit_mana_pct = function() return 80 end,
    unit_health_pct = function() return 100 end,
    unit_creature_type = function() return 7 end,
    game_time_ms = function() return 100000 end,
    should_use_long_cd = function() return true end,
    get_friendly_target_entry = function() return nil end,
    get_map_id = function() return 0 end,
    aoe_self_meets = function() return true end,
    is_tbc = function() return false end,
    -- heal-scan bridge used by discipline build_state
    healing_get_lowest_hp = function(entries, count, threshold)
        local best = nil
        for i = 1, count do
            local e = entries[i]
            if e and (not best or (e.effective_hp or 100) < best.effective_hp) then best = e end
        end
        return best
    end,
    healing_get_tank = function(entries, count)
        for i = 1, count do if entries[i] and entries[i].is_tank then return entries[i] end end
        return nil
    end,
    healing_count_below_hp = function(entries, count, threshold)
        local n = 0
        for i = 1, count do if entries[i] and (entries[i].effective_hp or 100) < threshold then n = n + 1 end end
        return n
    end,
    PriestHealing = {
        scan_healing_targets = function() return heal_entries, #heal_entries end,
        count_subgroup_below_hp = function() return 0 end,
        pws_absorb_remaining = function() return 0 end,
    },
    log = function() end,
    log_warning = function() end,
    rotation_registry = { register = function() end },
    -- live-API spies (swapped in by the assertions below)
    cancel_spells = function() calls.cancel_spells = calls.cancel_spells + 1 return true end,
    start_auto_attack = function(target, attack_type)
        calls.start_auto_attack[#calls.start_auto_attack + 1] = { target = target, attack_type = attack_type }
        return true
    end,
    is_auto_attacking = function() return false end,
    is_interruptible = nil,  -- absent: exercises the raw-unit fallback
    is_threat_safe = function(context)
        calls.is_threat_safe[#calls.is_threat_safe + 1] = context
        if type(context) == "table" and context.has_aggro ~= nil then return context.has_aggro ~= true end
        return true
    end,
}
-- Lua 5.1 scope: a local is not visible inside its own table constructor, so
-- import_helpers (which closes over NS) is attached after construction.
NS.import_helpers = function(...)
    local helpers = {}
    for _, k in ipairs({ ... }) do helpers[k] = NS[k] or function() return false end end
    helpers.try_cast = function() return true end
    helpers.spell_exists = function() return true end
    helpers.spell_ready = function() return true end
    helpers.debuff_remains = function() return 0 end
    helpers.health_pct = function() return 100 end
    helpers.player_control_locked = function() return false end
    helpers.has_player_buff = function() return false end
    local r = {}
    for _, k in ipairs({ ... }) do r[#r + 1] = helpers[k] end
    return unpack(r)
end
_G.EaxRotations = NS

local function find_strategy(strats, name)
    for i = 1, #strats do
        if strats[i].name == name then return strats[i] end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- Load all five vanilla spec files
-- ============================================================================
local disc = dofile("EaxRotations/classes/priest/discipline_vanilla.lua")
local holy = dofile("EaxRotations/classes/priest/holy_vanilla.lua")
local shadow = dofile("EaxRotations/classes/priest/shadow_vanilla.lua")
local smite = dofile("EaxRotations/classes/priest/smite_vanilla.lua")
local leveling = dofile("EaxRotations/classes/priest/leveling_vanilla.lua")
assert_true(disc and disc[1], "discipline_vanilla strategies should load")
assert_true(holy and holy[1], "holy_vanilla strategies should load")
assert_true(shadow and shadow[1], "shadow_vanilla strategies should load")
assert_true(smite and smite[1], "smite_vanilla strategies should load")
assert_true(leveling and leveling.strategies and leveling.strategies[1], "leveling_vanilla strategies should load")

-- ============================================================================
-- 1. StopCast (discipline + holy) must use the live NS.cancel_spells, never
--    the mock-only NS.stop_casting / NS.cancel_current_cast.
-- ============================================================================
calls.cancel_spells = 0
calls.stop_casting = 0
calls.cancel_current_cast = 0
NS.stop_casting = function() calls.stop_casting = calls.stop_casting + 1 return true end
NS.cancel_current_cast = function() calls.cancel_current_cast = calls.cancel_current_cast + 1 return true end
assert_true(find_strategy(disc, "StopCast").execute({}), "disc StopCast execute should return true")
assert_eq(calls.cancel_spells, 1, "disc StopCast must call NS.cancel_spells")
assert_eq(calls.stop_casting + calls.cancel_current_cast, 0, "disc StopCast must not call mock-only members")
assert_true(find_strategy(holy, "StopCast").execute({}), "holy StopCast execute should return true")
assert_eq(calls.cancel_spells, 2, "holy StopCast must call NS.cancel_spells")
assert_eq(calls.stop_casting + calls.cancel_current_cast, 0, "holy StopCast must not call mock-only members")
print("  PASS: StopCast uses NS.cancel_spells (disc + holy)")

-- ============================================================================
-- 2. ManaBelow5Wand (holy + shadow) must start AUTO_ATTACK_WAND (5019) on the
--    target — not a target-less melee default.
-- ============================================================================
local target = make_target(false)
calls.start_auto_attack = {}
assert_true(find_strategy(holy, "ManaBelow5Wand").execute({ target = target, me = mock_player }), "holy wand execute")
assert_eq(#calls.start_auto_attack, 1, "holy wand must call start_auto_attack once")
assert_eq(calls.start_auto_attack[1].target, target, "holy wand must pass the target")
assert_eq(calls.start_auto_attack[1].attack_type, 5019, "holy wand must pass AUTO_ATTACK_WAND")
calls.start_auto_attack = {}
assert_true(find_strategy(shadow, "ManaBelow5Wand").execute({ target = target, me = mock_player }), "shadow wand execute")
assert_eq(#calls.start_auto_attack, 1, "shadow wand must call start_auto_attack once")
assert_eq(calls.start_auto_attack[1].target, target, "shadow wand must pass the target")
assert_eq(calls.start_auto_attack[1].attack_type, 5019, "shadow wand must pass AUTO_ATTACK_WAND")
print("  PASS: ManaBelow5Wand starts wand auto-attack (5019) on target (holy + shadow)")

-- ============================================================================
-- 3. shadow Silence: interrupt-only. Fires when the target is casting, stays
--    silent when it is not (NS.is_interruptible absent -> raw-unit fallback).
-- ============================================================================
local silence = find_strategy(shadow, "Silence")
local s_ready = { silence_ready = true, mf_channeling = false, should_clip_mf = false }
assert_true(silence.matches({ in_combat = true, target = make_target(true) }, s_ready),
    "Silence must fire on a casting target")
assert_false(silence.matches({ in_combat = true, target = make_target(false) }, s_ready),
    "Silence must stay silent on a non-casting target")
assert_false(silence.matches({ in_combat = false, target = make_target(true) }, s_ready),
    "Silence must stay silent out of combat")
print("  PASS: Silence wired to target interruptible state")

-- ============================================================================
-- 4. shadow VampiricEmbrace: gated on the SELF buff (15286), not a target
--    debuff — VE is a self buff in vanilla.
-- ============================================================================
local ve = find_strategy(shadow, "VampiricEmbrace")
local s_ve = { vampiric_embrace_known = true, mf_channeling = false, should_clip_mf = false }
NS.buff_up = function(unit, ids)
    local list = type(ids) == "table" and ids or { ids }
    for _, id in ipairs(list) do if id == 15286 then return true end end
    return false
end
assert_false(ve.matches({ has_valid_enemy_target = true, me = mock_player, in_combat = true }, s_ve),
    "VE must not recast while the self buff is active")
NS.buff_up = function() return false end
assert_true(ve.matches({ has_valid_enemy_target = true, me = mock_player, in_combat = true }, s_ve),
    "VE must fire when the self buff is down")
print("  PASS: VampiricEmbrace gated on self buff 15286")

-- ============================================================================
-- 5. smite threat safety: NS.is_threat_safe must receive the context; with
--    aggro held, state.threat_safe is false and optional shadow spells block.
-- ============================================================================
local function smite_state_for(has_aggro)
    local ctx = { settings = {}, target = target, has_aggro = has_aggro }
    NS.GetPlayer = function() return mock_player end
    local state = nil
    local builder = nil
    for _, s in ipairs(smite) do if s.name == "SmiteFiller" then builder = nil end end
    -- recover build_state: plain-style files register get_state via the mock
    local build = nil
    local ok, mod = pcall(dofile, "EaxRotations/classes/priest/smite_vanilla.lua")
    if ok and mod then build = nil end
    return ctx, state
end
-- The plain-style smite file returns bare strategies; re-load it through a
-- registry mock to recover build_state, then assert the threat wiring.
local registry = { options = nil }
NS.rotation_registry = {
    register = function(_, _name, _strats, opts) registry.options = opts end,
}
local ok_load, mod = pcall(dofile, "EaxRotations/classes/priest/smite_vanilla.lua")
assert_true(ok_load, "smite_vanilla reload failed: " .. tostring(mod))
local smite_build = registry.options and registry.options.get_state
assert_not_nil(smite_build, "smite build_state recoverable from registry mock")
calls.is_threat_safe = {}
local ctx_aggro = { settings = {}, target = target, has_aggro = true, mana_pct = 20 }
local st_aggro = smite_build(ctx_aggro)
assert_eq(#calls.is_threat_safe, 1, "is_threat_safe must be called once per build")
assert_eq(calls.is_threat_safe[1], ctx_aggro, "is_threat_safe must receive the context")
assert_eq(st_aggro.threat_safe, false, "has_aggro=true must yield threat_safe=false")
local mb = nil
for _, s in ipairs(smite) do if s.name == "MindBlast" then mb = s end end
assert_not_nil(mb, "smite MindBlast strategy present")
assert_false(mb.matches(ctx_aggro, st_aggro), "MindBlast must block while threat is unsafe")
local ctx_safe = { settings = {}, target = target, has_aggro = false, mana_pct = 20 }
local st_safe = smite_build(ctx_safe)
assert_eq(st_safe.threat_safe, true, "has_aggro=false must yield threat_safe=true")
print("  PASS: smite is_threat_safe(context) wiring")

-- ============================================================================
-- 6. discipline Prayer of Fortitude: PoF (21562/21564) is a vanilla group
--    buff — with it active, single-target PW:F must not recast.
-- ============================================================================
local pwf = find_strategy(disc, "PowerWordFortitude")
local s_pwf = {
    has_power_word_fortitude = false, has_prayer_of_fortitude = true,
    power_word_fortitude_ready = true, enemy_count = 1,
}
assert_false(pwf.matches({ in_combat = true, settings = {} }, s_pwf),
    "PW:F must not recast over an active Prayer of Fortitude")
s_pwf.has_prayer_of_fortitude = false
assert_true(pwf.matches({ in_combat = true, settings = {} }, s_pwf),
    "PW:F must fire when neither group buff is active")
print("  PASS: discipline PoF flag gates PW:F recast")

-- ============================================================================
-- 7. discipline PW:S lowest lanes: the duplicated registration is split —
--    EmergencyPowerWordShield owns the critical band, PowerWordShieldLowest
--    the maintenance band, and BOTH are reachable.
-- ============================================================================
local em = find_strategy(disc, "EmergencyPowerWordShield")
local lo = find_strategy(disc, "PowerWordShieldLowest")
local function pws_state(hp)
    return {
        lowest = { unit = make_target(false), effective_hp = hp, has_weakened_soul = false },
        tank = { unit = make_target(false), effective_hp = 90 },
        pws_ready = true,
    }
end
local ctx_pws = { settings = {}, in_combat = true }
assert_true(em.matches(ctx_pws, pws_state(25)), "emergency lane must fire below 30%")
assert_false(lo.matches(ctx_pws, pws_state(25)), "maintenance lane must not fire below 30%")
assert_false(em.matches(ctx_pws, pws_state(32)), "emergency lane must not fire at 32%")
assert_true(lo.matches(ctx_pws, pws_state(32)), "maintenance lane must fire at 32%")
assert_false(lo.matches(ctx_pws, pws_state(40)), "maintenance lane must not fire above the pws threshold")
print("  PASS: discipline PW:S lanes split and both reachable")

-- ============================================================================
-- 8. holy EncounterReactions: Karazhan (532) is TBC-only — the lane must be
--    inert when NS.is_tbc() is false, even with the Karazhan map id.
-- ============================================================================
local enc = find_strategy(holy, "EncounterReactions")
NS.is_tbc = function() return false end
assert_false(enc.matches({ in_combat = true, settings = {} },
    { encounter_id = 532, flash_heal_ready = true, tank_hp = 30, tank = {} }),
    "EncounterReactions must not fire in Classic")
NS.is_tbc = function() return true end
assert_true(enc.matches({ in_combat = true, settings = {} },
    { encounter_id = 532, flash_heal_ready = true, tank_hp = 30, tank = {} }),
    "EncounterReactions must fire in TBC with Karazhan data")
NS.is_tbc = function() return false end
print("  PASS: holy EncounterReactions gated behind NS.is_tbc()")

-- ============================================================================
-- 9. shadow combat mode: enemy_count is assigned BEFORE the mode computation,
--    so a fresh scenario reads the current count (no one-tick staleness).
-- ============================================================================
local function shadow_state_for(enemy_count)
    local ctx = {
        settings = {},
        target = make_target(false),
        in_combat = true,
        enemy_count = enemy_count,
        mana_pct = 80,
    }
    local reg = { options = nil }
    NS.rotation_registry = { register = function(_, _n, _s, opts) reg.options = opts end }
    local ok2, mod2 = pcall(dofile, "EaxRotations/classes/priest/shadow_vanilla.lua")
    assert_true(ok2, "shadow_vanilla reload failed: " .. tostring(mod2))
    return reg.options.get_state(ctx), mod2
end
local st3, shadow_mod = shadow_state_for(3)
assert_eq(st3.combat_mode, "cleave", "3 enemies must yield cleave on the FIRST build (no stale tick)")
local st5, _ = shadow_state_for(5)
assert_eq(st5.combat_mode, "aoe", "5 enemies must yield aoe")
local st1, _ = shadow_state_for(1)
assert_eq(st1.combat_mode, "st", "1 enemy must yield st")
print("  PASS: shadow combat mode reads fresh enemy_count (no stale tick)")

-- ============================================================================
-- 10. shadow racial lanes: each gated on its own *_known flag — the shared
--     matcher no longer lets the first lane claim every racial GCD.
-- ============================================================================
local rb = find_strategy(shadow_mod, "RacialBerserking")
local rbf = find_strategy(shadow_mod, "RacialBloodFury")
local s_racial = {
    berserking_known = false, blood_fury_known = true, arcane_torrent_known = false,
    mf_channeling = false, should_clip_mf = false,
}
local ctx_racial = { in_combat = true, has_valid_enemy_target = true, settings = {} }
assert_false(rb.matches(ctx_racial, s_racial), "RacialBerserking must not fire when Berserking is unknown")
assert_true(rbf.matches(ctx_racial, s_racial), "RacialBloodFury must fire when Blood Fury is known")
print("  PASS: shadow racial lanes gated per known flag")

-- ============================================================================
-- 11. leveling: nil context returns the safe_state proxy; MindBlast / MindFlay
--     respect the wand-threshold mana band (wand owns the conserve range).
-- ============================================================================
local lvl_build = leveling.build_state
local st_nil = lvl_build(nil)
assert_not_nil(st_nil, "leveling build_state(nil) must return a table (safe_state)")
assert_eq(st_nil.mana_pct, 100, "nil-context state must fall back to schema defaults")
local mb2 = find_strategy(leveling.strategies, "MindBlast")
local mf2 = find_strategy(leveling.strategies, "MindFlay")
local wand = find_strategy(leveling.strategies, "Wand")
local ctx_lvl = { in_combat = true, target = target, settings = {} }
assert_false(mb2.matches(ctx_lvl, { target = target, mind_blast_ready = true, mana_pct = 10, wand_threshold = 20 }),
    "MindBlast must be gated below the wand threshold")
assert_true(mb2.matches(ctx_lvl, { target = target, mind_blast_ready = true, mana_pct = 80, wand_threshold = 20 }),
    "MindBlast must fire above the wand threshold")
assert_false(mf2.matches(ctx_lvl, { target = target, mf_ready = true, is_moving = false, is_channeling = false, mana_pct = 15, wand_threshold = 20 }),
    "MindFlay must stop below the wand threshold (12-20% band inconsistency)")
assert_true(mf2.matches(ctx_lvl, { target = target, mf_ready = true, is_moving = false, is_channeling = false, mana_pct = 80, wand_threshold = 20 }),
    "MindFlay must fire above the wand threshold")
assert_true(wand.matches(ctx_lvl, { target = target, mana_pct = 10, wand_threshold = 20 }),
    "Wand must fire in the conserve band")
print("  PASS: leveling mana bands (MindBlast/MindFlay/Wand)")

print("PASS test_priest_vanilla_live_fixes")
