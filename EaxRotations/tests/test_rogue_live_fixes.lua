-- test_rogue_live_fixes.lua -- Live-correctness regression tests for the 2026-08-12
-- rogue audit fixes (assassination / combat / subtlety).
-- WHAT:  Pins the audited live bugs: finisher energy hard floors, Cold Blood
--        sequencing, Expose Armor assignment gate (assassination); full Deadly
--        Poison ladder, Kidney Shot / Gouge / Sprint / Backstab gates, garrote
--        pcall (combat); real cooldown reads for Preparation, Sap gate, SnD
--        refresh priority over Hemo, Ambush behind gate, Shadowstep in_combat,
--        Cloak HP ceiling, kidney_remains schema (subtlety).
-- WHEN:  Run standalone (not registered in any runner):
--        lua EaxRotations/tests/test_rogue_live_fixes.lua
-- WHY:   These are live-game correctness bugs that only test mocks masked.
-- SAFETY: Pure unit tests with a mocked _G.EaxRotations; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function at(v, label) if not v then error("FAIL: " .. (label or "assert_true"), 2) end end
local function af(v, label) if v then error("FAIL: " .. (label or "assert_false"), 2) end end

local captured_poison_ids = nil

local me_unit = {
    get_power = function(_, pt)
        if pt == 4 then return 5 end  -- combo points
        if pt == 3 then return 60 end -- energy
        return 0
    end,
    get_max_power = function(_, pt) if pt == 3 then return 100 end return 5 end,
}

_G.EaxRotations = {
    RogueSpells = {
        Stealth = 1784, AdrenalineRush = 13750, BladeFlurry = 13877,
        SliceAndDice = 6774, Rupture = 1943, Eviscerate = 11300,
        Envenom = 32684, SinisterStrike = 26862, Kick = 1766, Gouge = 1776,
        Sprint = 2983, Vanish = 1857, Feint = 1966, Hemorrhage = 26864,
        Backstab = 26863, GhostlyStrike = 14278, KidneyShot = 8643,
        ExposeArmor = 11198, Shiv = 5938, Evasion = 26669,
        CloakOfShadows = 31224, DeadlyThrow = 26679, Blind = 2094,
        CheapShot = 1833, Garrote = 703, Ambush = 8676, Sap = 6770,
        Premeditation = 14183, Preparation = 14185, Shadowstep = 36554,
        ColdBlood = 14177, Mutilate = 1329, ThistleTea = 9513,
    },
    PLAYER_UNIT = {},
    POWER_COMBO = 4,
    EQUIPMENT_SLOTS = { MAIN_HAND = 16, OFF_HAND = 17 },
    GetPlayer = function() return me_unit end,
    spell_ready = function() return true end,
    try_cast = function() return false end,
    has_player_buff = function() return false end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_remains = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    debuff_stacks = function(target, ids) captured_poison_ids = ids; return 0 end,
    is_spell_learned = function() return true end,
    is_behind_target = function() return true end,
    is_interruptible = function() return true end,
    is_item_ready = function() return false end,
    spell_exists = function() return true end,
    get_equipped_item_id = function() return nil end,
    gate_cooldown_boss_only = function() return true end,
    broken_api_throttled = function() return false end,
    time_now = function() return 100 end,
    log = function() end,
    get_spell_cd = nil,           -- production-like: never exists live
    get_spell_cooldown = function() return 0 end,
    OffensiveDispelDB = { find_best_dispel_target = function() return nil end },
    DRTracker = { is_dr_immune = function() return false end },
    rotation_registry = { register = function() end },
}
package.loaded["shared/potion_helper_sylvanas"] = {}
package.loaded["shared/offensive_dispel_sylvanas"] = { find_best_dispel_target = function() return nil end }
package.loaded["shared/combo_points_reader_sylvanas"] = function(unit, power_type)
    return (unit and unit.get_power and unit.get_power(power_type)) or 0
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- Assassination
-- ============================================================================
local assn = dofile("EaxRotations/classes/rogue/assassination_sylvanas.lua")
at(assn and assn.strategies, "assassination strategies should load")

-- 1. EnvenomFinisher hard energy floor (35): band 25-34 must NOT match.
local env = find_strategy(assn.strategies, "EnvenomFinisher")
af(env.matches({ target = {} }, { energy = 30, combo = 5, dp_stacks = 5,
    slice_dice_active = true, snd_needs_refresh = false, energy_pool_finisher = false }),
    "EnvenomFinisher must not match at 30 energy (hard floor 35)")
at(env.matches({ target = {} }, { energy = 40, combo = 5, dp_stacks = 5,
    slice_dice_active = true, snd_needs_refresh = false, energy_pool_finisher = false }),
    "EnvenomFinisher must match at 40 energy")

-- 1b. EviscerateFallback hard energy floor.
local evisc = find_strategy(assn.strategies, "EviscerateFallback")
af(evisc.matches({ target = {}, level = 70, player_level = 70, is_leveling = false },
    { energy = 30, combo = 5, energy_pool_finisher = false }),
    "EviscerateFallback must not match at 30 energy (hard floor 35)")
at(evisc.matches({ target = {}, level = 70, player_level = 70, is_leveling = false },
    { energy = 40, combo = 5, energy_pool_finisher = false }),
    "EviscerateFallback must match at 40 energy with 5 CP")

-- 2. Cold Blood sequencing: RuptureBleed must hold while CB is banked and
--    Envenom can use it; must proceed when no finisher can use CB.
local rup = find_strategy(assn.strategies, "RuptureBleed")
af(rup.matches({ target = {}, ttd = 30, ttd_known = true }, { combo = 5, rupture_remains = 0,
    has_cold_blood = true, slice_dice_active = true, snd_needs_refresh = false,
    dp_stacks = 5, energy = 60, energy_pool_finisher = false }),
    "RuptureBleed must hold while Cold Blood is banked and Envenom usable")
at(rup.matches({ target = {}, ttd = 30, ttd_known = true }, { combo = 5, rupture_remains = 0,
    has_cold_blood = true, slice_dice_active = true, snd_needs_refresh = false,
    dp_stacks = 0, energy = 60, energy_pool_finisher = false }),
    "RuptureBleed must fire when CB is banked but no finisher can use it (0 DP stacks)")

-- 3. ExposeArmor assignment gate (assassin_expose_assigned, off by default).
local ea = find_strategy(assn.strategies, "ExposeArmor")
af(ea.matches({ target = {}, target_armor = 5000, settings = { assassin_expose_assigned = false } },
    { combo = 5 }), "ExposeArmor must not match when unassigned")
at(ea.matches({ target = {}, target_armor = 5000, settings = { assassin_expose_assigned = true } },
    { combo = 5 }), "ExposeArmor must match when assigned")
at(ea.matches({ target = {}, target_armor = 5000 }, { combo = 5 }),
    "ExposeArmor harness compat: no settings table passes (unit-test only)")

-- ============================================================================
-- Combat
-- ============================================================================
local combat = dofile("EaxRotations/classes/rogue/combat_sylvanas.lua")
at(combat and combat.strategies, "combat strategies should load")

-- 4. Deadly Poison ladder: full 14-rank set, no non-poison ids.
captured_poison_ids = nil
local combat_state = combat.build_state({ me = me_unit, target = {}, in_combat = true,
    hp = 100, energy = 60, combo_points = 5, enemy_count = 1 })
at(type(captured_poison_ids) == "table", "combat build_state must query the poison ladder")
local expected_poison = { 27187, 27186, 26968, 26967, 25349, 25347, 11354, 11356, 11353, 11355, 2819, 2837, 2818, 2835 }
local poison_set = {}
for _, id in ipairs(captured_poison_ids or {}) do poison_set[id] = true end
for _, id in ipairs(expected_poison) do
    at(poison_set[id] == true, "poison ladder must include rank " .. tostring(id))
end
for _, bad in ipairs({ 11349, 11350, 11351, 11352 }) do
    af(poison_set[bad] == true, "poison ladder must NOT include non-poison id " .. tostring(bad))
end
at(type(combat_state) == "table", "combat build_state must return state")

-- 5. Kidney Shot: CP >= 3 AND (PvP or group) — no PvE CP spending on stuns.
local kid = find_strategy(combat.strategies, "KidneyShot")
af(kid.matches({ is_pvp = false, is_group = false, settings = {}, target = {} },
    { kidney_shot_ready = true, combo_points = 5 }),
    "KidneyShot must not match in PvE solo")
af(kid.matches({ is_pvp = true, settings = {}, target = {} },
    { kidney_shot_ready = true, combo_points = 2 }),
    "KidneyShot must not match below 3 CP")
at(kid.matches({ is_pvp = true, settings = {}, target = {} },
    { kidney_shot_ready = true, combo_points = 5 }),
    "KidneyShot must match in PvP with 5 CP")
at(kid.matches({ is_pvp = false, is_group = true, settings = {}, target = {} },
    { kidney_shot_ready = true, combo_points = 3 }),
    "KidneyShot must match in group with 3 CP")

-- 6. DSL Sprint: gap-close only (12 < distance <= 35).
local sprint = find_strategy(combat.strategies, "Sprint")
af(sprint.matches({ target_distance = 5 }, { in_combat = true, sprint_ready = true }),
    "Sprint must not fire already in melee (5 yd)")
af(sprint.matches({ target_distance = 12 }, { in_combat = true, sprint_ready = true }),
    "Sprint must not fire at 12 yd (needs > 12)")
at(sprint.matches({ target_distance = 20 }, { in_combat = true, sprint_ready = true }),
    "Sprint must fire at 20 yd gap")
af(sprint.matches({ target_distance = 50 }, { in_combat = true, sprint_ready = true }),
    "Sprint must not fire beyond 35 yd")

-- 7. DSL Gouge: PvP/group only with CC/DR/melee/energy guards.
local gouge = find_strategy(combat.strategies, "Gouge")
af(gouge.matches({ is_pvp = false, is_group = false, in_melee_range = true, target = {}, settings = {} },
    { gouge_ready = true, energy = 100 }),
    "Gouge must not fire in PvE solo")
at(gouge.matches({ is_pvp = true, in_melee_range = true, target = {}, settings = {} },
    { gouge_ready = true, energy = 100 }),
    "Gouge must fire in PvP in melee with energy")
af(gouge.matches({ is_pvp = true, in_melee_range = false, target = {}, settings = {} },
    { gouge_ready = true, energy = 100 }),
    "Gouge must not fire out of melee range")

-- 8. Backstab: dagger + behind requirement.
local bs = find_strategy(combat.strategies, "Backstab")
at(bs.matches({ target = {} }, { backstab_ready = true, has_daggers = true }),
    "Backstab must match behind with daggers")
af(bs.matches({ target = {} }, { backstab_ready = true, has_daggers = false }),
    "Backstab must not match without daggers")
local saved_behind = _G.EaxRotations.is_behind_target
_G.EaxRotations.is_behind_target = function() return false end
af(bs.matches({ target = {} }, { backstab_ready = true, has_daggers = true }),
    "Backstab must not match when not behind")
_G.EaxRotations.is_behind_target = saved_behind

-- 9. Garrote: pcall-wrapped is_casting must not crash the matcher.
local garrote = find_strategy(combat.strategies, "Garrote")
local ok_garrote, m_garrote = pcall(garrote.matches,
    { target = { is_casting = function() error("mock api break") end }, in_melee_range = true, settings = {} },
    { is_stealthed = true })
at(ok_garrote, "garrote matcher must not crash on a throwing is_casting")
af(m_garrote, "garrote matcher must treat a broken is_casting as not-casting")
at(garrote.matches({ target = { is_casting = function() return true end }, in_melee_range = true, settings = {} },
    { is_stealthed = true }),
    "garrote matcher must match a casting target")

-- ============================================================================
-- Subtlety
-- ============================================================================
local sub = dofile("EaxRotations/classes/rogue/subtlety_sylvanas.lua")
at(sub and sub.strategies, "subtlety strategies should load")

-- 10. Cooldown reads: real NS.get_spell_cooldown (production path) and the
--     mock-only NS.get_spell_cd fallback both populate vanish_cd.
_G.EaxRotations.get_spell_cd = nil
_G.EaxRotations.get_spell_cooldown = function() return 60 end
local sub_state_real = sub.build_state({ me = me_unit, target = {}, in_combat = true, hp = 100 })
at(sub_state_real.vanish_cd == 60, "vanish_cd must come from the real get_spell_cooldown")
at(sub_state_real.kidney_remains == 0, "kidney_remains must have a safe schema default")

_G.EaxRotations.get_spell_cooldown = function() return 0 end
_G.EaxRotations.get_spell_cd = function() return 60 end
local sub_state_mock = sub.build_state({ me = me_unit, target = {}, in_combat = true, hp = 100 })
at(sub_state_mock.vanish_cd == 60, "vanish_cd fallback via mock get_spell_cd")
_G.EaxRotations.get_spell_cd = nil

-- 11. Preparation: fires only when a major CD is burned.
local prep = find_strategy(sub.strategies, "Preparation")
at(prep.matches({ in_combat = true, should_burst = false, settings = { use_cooldowns = true } },
    { hp = 15, vanish_cd = 60, sprint_cd = 0, evasion_cd = 0 }),
    "Preparation must match with Vanish on CD at low HP")
af(prep.matches({ in_combat = true, should_burst = false, settings = { use_cooldowns = true } },
    { hp = 15, vanish_cd = 0, sprint_cd = 0, evasion_cd = 0 }),
    "Preparation must not match with no major CD burned")

-- 12. Sap: PvP/group only — no wasted Sap + DR on every PvE pull.
local sap = find_strategy(sub.strategies, "Sap")
af(sap.matches({ in_combat = false, has_valid_enemy_target = true, target = {},
    is_pvp = false, is_group = false, settings = {} }, { stealth_up = true }),
    "Sap must not fire on a plain PvE pull target")
at(sap.matches({ in_combat = false, has_valid_enemy_target = true, target = {},
    is_pvp = true, settings = {} }, { stealth_up = true }),
    "Sap must fire in PvP")

-- 13. SnD refresh priority: Hemo lanes must yield to a due SnD refresh.
local sshe = find_strategy(sub.strategies, "ShadowstepHemorrhage")
af(sshe.matches({ target = {} }, { shadowstep_buff = true, energy = 60, slice_remains = 2, combo = 3 }),
    "ShadowstepHemorrhage must yield to a due SnD refresh (<= 3s, >= 2 CP)")
at(sshe.matches({ target = {} }, { shadowstep_buff = true, energy = 60, slice_remains = 10, combo = 3 }),
    "ShadowstepHemorrhage must fire when SnD is fresh")
local hde = find_strategy(sub.strategies, "HemorrhageDebuff")
af(hde.matches({ target = {} }, { energy = 60, slice_remains = 2, combo = 3, hemo_remains = 0 }),
    "HemorrhageDebuff must yield to a due SnD refresh")
at(hde.matches({ target = {} }, { energy = 60, slice_remains = 10, combo = 3, hemo_remains = 0 }),
    "HemorrhageDebuff must fire when SnD is fresh")

-- 14. Ambush opener: is_behind gate (Shadowstep-buffed Ambush exempt).
local amb = find_strategy(sub.strategies, "Ambush")
af(amb.matches({ target = {}, settings = { opener_preference = "ambush" } },
    { stealth_up = true, is_behind = false, shadowstep_buff = false, energy = 70 }),
    "Ambush must not fire when not behind")
at(amb.matches({ target = {}, settings = { opener_preference = "ambush" } },
    { stealth_up = true, is_behind = true, shadowstep_buff = false, energy = 70 }),
    "Ambush must fire when behind")
at(amb.matches({ target = {}, settings = { opener_preference = "ambush" } },
    { stealth_up = true, is_behind = false, shadowstep_buff = true, energy = 70 }),
    "Shadowstep-buffed Ambush must fire even if behind API lags")

-- 15. Shadowstep gap-close: in_combat gate (no OOC CD burn).
local ssg = find_strategy(sub.strategies, "Shadowstep")
af(ssg.matches({ target = {}, settings = { shadowstep_usage = "always" }, in_combat = false },
    { target_distance = 15 }),
    "Shadowstep gap-close must not fire out of combat")
at(ssg.matches({ target = {}, settings = { shadowstep_usage = "always" }, in_combat = true },
    { target_distance = 15 }),
    "Shadowstep gap-close must fire in combat at 15 yd")

-- 16. Cloak: HP ceiling — no full-HP cloak on any casting target.
local cloak = find_strategy(sub.strategies, "CloakOfShadows")
af(cloak.matches({ target = {}, settings = { rogue_use_cloak = true, rogue_cloak_hp = 45 }, is_pvp = false },
    { hp = 100, is_caster_target = true }),
    "Cloak must not fire at full HP on a casting target")
at(cloak.matches({ target = {}, settings = { rogue_use_cloak = true, rogue_cloak_hp = 45 }, is_pvp = false },
    { hp = 50, is_caster_target = true }),
    "Cloak must fire below the ceiling on a casting target")
at(cloak.matches({ target = {}, settings = { rogue_use_cloak = true, rogue_cloak_hp = 45 }, is_pvp = true },
    { hp = 100, is_caster_target = true }),
    "Cloak must remain allowed at full HP in PvP")

-- 17. Weapon poison upkeep (2026-09-13): the lane that only WARNED now applies.
--     Module-level pins against the real shared/weapon_poison_sylvanas - the
--     apply surface is item-on-weapon (NS.use_item_by_id(poison, weapon)), the
--     same call the archived original EAX rogue poison manager used in game.
local WeaponPoison = dofile("EaxRotations/shared/weapon_poison_sylvanas.lua")
at(type(WeaponPoison) == "table", "weapon poison module must load")

local mh_weapon = { get_item_id = function() return 2819 end }  -- Cross Dagger
local oh_weapon = { get_item_id = function() return 2092 end }  -- Worn Dagger
local enchanted = { mh = false, oh = false }
_G.GetWeaponEnchantInfo = function() return enchanted.mh, 0, 0, 0, enchanted.oh end
local owned = {}
local applied_calls = {}
local pns = {
    time_now = function() return 100 end,
    GetPlayer = function()
        return { get_item_at_inventory_slot = function(_, slot)
            if slot == 16 then return { object = mh_weapon } end
            if slot == 17 then return { object = oh_weapon } end
            return nil
        end }
    end,
    has_item = function(id) return owned[id] == true end,
    use_item_by_id = function(id, target)
        applied_calls[#applied_calls + 1] = { id = id, target = target }
        return true
    end,
}

-- (a) the engine reports an enchant -> live, nothing to do.
enchanted.mh, enchanted.oh = true, true
at(WeaponPoison.slot_status(pns, 16) == WeaponPoison.STATUS.LIVE, "an enchanted main hand must read live")
af(WeaponPoison.needs_poison(pns, 200), "a live poison must not need a re-apply")

-- (b) bare weapons + one owned poison -> ready, and the apply targets the weapon.
WeaponPoison.reset()
enchanted.mh, enchanted.oh = false, false
owned = { [8928] = true }  -- Instant Poison VI only
at(WeaponPoison.best_owned(pns, "instant") == 8928, "best_owned must pick the owned rank")
at(WeaponPoison.best_owned(pns, "deadly") == nil, "an unowned kind must read nil")
at(WeaponPoison.slot_status(pns, 16) == WeaponPoison.STATUS.READY, "a bare main hand with an owned poison must read ready")
at(WeaponPoison.needs_poison(pns, 200), "a ready slot must need a poison")
local applied, applied_slot, applied_id = WeaponPoison.try_apply(pns, 200)
at(applied == true and applied_slot == 16 and applied_id == 8928, "try_apply must apply the owned rank to the main hand")
at(applied_calls[1] and applied_calls[1].id == 8928 and applied_calls[1].target == mh_weapon,
    "the poison must be used ON the weapon object")

-- (c) the highest owned rank wins.
owned = { [8926] = true, [8928] = true }
at(WeaponPoison.best_owned(pns, "instant") == 8928, "the highest owned rank must win")

-- (d) after an apply the slot is assumed: no second apply, throttle and window.
at(WeaponPoison.slot_status(pns, 16, 201) == WeaponPoison.STATUS.ASSUMED, "an applied slot must read assumed")
af(WeaponPoison.try_apply(pns, 202), "the apply must be throttled inside 5s")
af(WeaponPoison.try_apply(pns, 400), "an assumed slot must not be re-applied past the throttle")

-- (e) a weapon swap invalidates the assumed reading (a new blade is bare).
mh_weapon = { get_item_id = function() return 2089 end }  -- Scrimshaw Dagger
at(WeaponPoison.slot_status(pns, 16, 500) == WeaponPoison.STATUS.READY, "a weapon swap must invalidate the assumed poison")

-- (f) bare weapon and nothing in the bags -> warn, and there is nothing to apply.
owned = {}
at(WeaponPoison.warn_state(pns, 600), "a bare weapon with no poison item must raise the warning state")
at(WeaponPoison.missing(pns, 600), "a bare weapon must read as missing a poison")
af(WeaponPoison.try_apply(pns, 600), "nothing may be applied when no poison item is owned")

-- (g) when GetWeaponEnchantInfo is unavailable the item enchant fields decide.
_G.GetWeaponEnchantInfo = nil
mh_weapon = { get_item_id = function() return 2819 end, item_has_enchant = function() return true end }
WeaponPoison.reset()
at(WeaponPoison.slot_status(pns, 16, 700) == WeaponPoison.STATUS.LIVE, "the item enchant field must also read live")
_G.GetWeaponEnchantInfo = function() return enchanted.mh, 0, 0, 0, enchanted.oh end
print("PASS test_rogue_live_fixes")
