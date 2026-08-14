-- test_rogue_vanilla_live_fixes.lua — Rogue Vanilla live-fix regression tests (wave 1.3).
-- WHAT:  Standalone match/build_state assertions for the wave-1.3 fixes across
--        rogue/assassination_vanilla, combat_vanilla, subtlety_vanilla and
--        leveling_vanilla: endgame builder reachability, gated utility lanes,
--        NS.get_spell_cd -> get_spell_cooldown fallback, behind-checked
--        openers, Stealth lane order, ExposeArmor assignment gates, Sap
--        reachability + humanoid gate, energy fallback (me:get_power), wired
--        should_pool_energy, throttled item scan.
-- WHEN:  Standalone only (registered in run_rotation_tests.lua, Wave 1.5):
--        lua EaxRotations/tests/test_rogue_vanilla_live_fixes.lua
-- WHY:   The register (audit wave 1.2) found mock-only NS members and
--        un-gated lanes that only manifest live; these pins encode the fixes.
-- SAFETY: Pure unit tests with mocked _G.EaxRotations + package.loaded mocks;
--         no game data, no fs writes, no registration.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error("FAIL: " .. (label or "assert_true"), 2) end end
local function assert_false(v, label) if v then error("FAIL: " .. (label or "assert_false"), 2) end end
local function assert_eq(a, b, label)
    if a ~= b then error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i], i end
    end
    error("strategy not found: " .. name, 2)
end

local BASE_MOCKS = {
    potion_helper = {
        try_use_potion = function() return false end,
        HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {},
    },
    leveling_sylvanas = {
        create_context_guard = function() return function() return true end end,
        build_common_state = function(ctx, st) st.in_combat = ctx.in_combat or false end,
        create_wand_matches = function() return function() return false end end,
        execute_wand = function() return false end,
    },
}
package.loaded["shared/potion_helper_sylvanas"] = BASE_MOCKS.potion_helper
package.loaded["shared/leveling_sylvanas"] = BASE_MOCKS.leveling_sylvanas

-- ============================================================================
-- 1. assassination_vanilla
-- ============================================================================
package.loaded["shared/offensive_dispel_sylvanas"] = {
    find_best_dispel_target = function() return nil end,
}
local assn_now = 0
local item_probe_calls = 0
_G.EaxRotations = {
    RogueSpells = {
        Ambush = 8676, Backstab = 53, Blind = 2094, CheapShot = 1833,
        ColdBlood = 14177, Evasion = 5277, Eviscerate = 2098, ExposeArmor = 8647,
        Feint = 1966, Garrote = 703, Kick = 1766, KidneyShot = 408,
        Rupture = 1943, Sap = 6770, SinisterStrike = 1752, SliceAndDice = 5171,
        Sprint = 2983, Stealth = 1784, ThistleTea = 7676, Vanish = 1856,
    },
    PLAYER_UNIT = "player",
    GetPlayer = function() return nil end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    has_player_buff = function() return false end,
    buff_remains = function() return 0 end,
    debuff_remains = function() return 0 end,
    is_vanilla = function() return true end,
    is_behind_target = function() return true end,
    is_item_ready = function() item_probe_calls = item_probe_calls + 1; return true end,
    time_now = function() return assn_now end,
    log = function() end,
    rotation_registry = { register = function() end },
}
local assn = dofile("EaxRotations/classes/rogue/assassination_vanilla.lua")
local assn_strategies = (type(assn) == "table" and assn.strategies) or assn
assert_true(type(assn_strategies) == "table" and #assn_strategies > 0, "assassination strategies load")

-- Critical: the ONLY combo-point builder must fire at level 60 (endgame).
local assn_builder = find_strategy(assn_strategies, "LevelingSinisterStrike")
assert_true(assn_builder.matches({ level = 60, is_leveling = false, target = {} },
    { energy = 60, combo = 3, stealth_active = false }),
    "assn builder FIRES at level 60 endgame (no more finisher starvation)")
assert_false(assn_builder.matches({ level = 60, is_leveling = false, target = {} },
    { energy = 60, combo = 3, stealth_active = true }),
    "assn builder skips from stealth (openers preferred)")
assert_false(assn_builder.matches({ level = 60, is_leveling = false, target = {} },
    { energy = 60, combo = 5, stealth_active = false }),
    "assn builder never overbuilds past 5 CP")
assert_false(assn_builder.matches({ level = 60, is_leveling = false, target = {} },
    { energy = 30, combo = 3, stealth_active = false }),
    "assn builder needs 45 energy")

-- Must: ExposeArmor assignment gate (schema checkbox assassin_expose_assigned,
-- with combat_expose_assigned accepted as the class-wide assignment fallback —
-- the behavioral battery's expose_armor scenario drives that key).
local assn_expose = find_strategy(assn_strategies, "ExposeArmor")
assert_false(assn_expose.matches({ settings = { assassin_expose_assigned = false }, target = {}, target_armor = 100 },
    { combo = 5 }),
    "assn ExposeArmor gated OFF when not assigned")
assert_true(assn_expose.matches({ settings = { assassin_expose_assigned = true }, target = {}, target_armor = 100 },
    { combo = 5 }),
    "assn ExposeArmor fires when the assassin checkbox is assigned")
assert_true(assn_expose.matches({ settings = { combat_expose_assigned = true }, target = {}, target_armor = 100 },
    { combo = 5 }),
    "assn ExposeArmor fires when the combat assignment checkbox is on (class-wide duty)")

-- Must: dead OR-chain gone — rupture_remains is a clean number, not a bool mix.
assn_now = 0
item_probe_calls = 0
local st_assn = assn.build_state({ target = {}, combo_points = 4, energy = 50, hp = 100, settings = {} })
assert_eq(type(st_assn.rupture_remains), "number", "rupture_remains is a number (no boolean OR-chain)")
assert_eq(st_assn.rupture_remains, 0, "rupture_remains reads debuff_remains")
assert_eq(item_probe_calls, 1, "item scan ran exactly once")

-- Nit: healing-item scan throttled to 2s (not per frame).
local st_item2 = assn.build_state({ target = {}, combo_points = 0, energy = 50, hp = 100, settings = {} })
assert_eq(item_probe_calls, 1, "item scan NOT re-run within 2s (throttled)")
assert_eq(st_item2.healing_item_id, st_assn.healing_item_id, "cached item id reused within the window")
assn_now = 5
local _st_item3 = assn.build_state({ target = {}, combo_points = 0, energy = 50, hp = 100, settings = {} })
assert_eq(item_probe_calls, 2, "item scan re-runs after 2s")

-- ============================================================================
-- 2. combat_vanilla
-- ============================================================================
local combat_now = 0
local captured_get_state = nil
_G.EaxRotations = {
    RogueSpells = {
        AdrenalineRush = 13750, Ambush = 8676, Backstab = 53, Blind = 2094,
        BladeFlurry = 13877, CheapShot = 1833, Evasion = 5277, Eviscerate = 2098,
        ExposeArmor = 8647, Feint = 1966, Garrote = 703, GhostlyStrike = 14278,
        Gouge = 1776, Hemorrhage = 16511, Kick = 1766, KidneyShot = 408,
        Rupture = 1943, SinisterStrike = 1752, SliceAndDice = 5171,
        Sprint = 2983, Stealth = 1784, Vanish = 1856,
    },
    PLAYER_UNIT = "player",
    GetPlayer = function() return nil end,
    spell_ready = function() return true end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    should_use_long_cd = function() return true end,
    try_cast = function() return true end,
    unit_health_pct = function() return 100 end,
    time_now = function() return combat_now end,
    log = function() end,
    rotation_registry = { register = function(self, spec, strats, opts) captured_get_state = opts and opts.get_state end },
}
local combat_strategies = dofile("EaxRotations/classes/rogue/combat_vanilla.lua")
if type(combat_strategies) == "table" and combat_strategies.strategies then
    combat_strategies = combat_strategies.strategies
end
assert_true(type(combat_strategies) == "table" and #combat_strategies > 0, "combat strategies load")

local gouge = find_strategy(combat_strategies, "Gouge")
local sprint = find_strategy(combat_strategies, "Sprint")
local hemorrhage = find_strategy(combat_strategies, "Hemorrhage")
local ghostly = find_strategy(combat_strategies, "GhostlyStrike")
local backstab = find_strategy(combat_strategies, "Backstab")
local kidney = find_strategy(combat_strategies, "KidneyShot")
local ss = find_strategy(combat_strategies, "SinisterStrike")

-- Critical: Gouge — PvP control / PvE cast-interrupt only (was: every 10s).
assert_false(gouge.matches({ is_pvp = false, target = {} },
    { gouge_ready = true, energy = 60, target_casting = false }),
    "Gouge silent in PvE when target not casting")
assert_true(gouge.matches({ is_pvp = false, target = {} },
    { gouge_ready = true, energy = 60, target_casting = true }),
    "Gouge fires as PvE cast interrupt")
assert_true(gouge.matches({ is_pvp = true, target = {} },
    { gouge_ready = true, energy = 60, target_casting = false }),
    "Gouge fires in PvP")
assert_false(gouge.matches({ is_pvp = true, target = {} },
    { gouge_ready = true, energy = 20, target_casting = false }),
    "Gouge needs 45 energy")
assert_false(gouge.matches({ is_pvp = true, target_dr_stun = 1, target = {} },
    { gouge_ready = true, energy = 60, target_casting = false }),
    "Gouge respects stun DR")

-- Critical: Sprint — never every combat (was: always in combat).
assert_false(sprint.matches({ in_combat = true, is_pvp = false, target = {} },
    { in_combat = true, sprint_ready = true, threat_pct = 30 }),
    "Sprint silent in PvE at low threat")
assert_true(sprint.matches({ in_combat = true, is_pvp = false, target = {} },
    { in_combat = true, sprint_ready = true, threat_pct = 95 }),
    "Sprint fires as high-threat escape")
assert_true(sprint.matches({ in_combat = true, is_pvp = true, target_distance = 20 },
    { in_combat = true, sprint_ready = true, threat_pct = 0 }),
    "Sprint fires as PvP gap close")
assert_false(sprint.matches({ in_combat = true, is_pvp = true, target_distance = 5 },
    { in_combat = true, sprint_ready = true, threat_pct = 0 }),
    "Sprint silent while in melee")

-- Critical: Hemorrhage (Subtlety talent) — explicit energy floor; the
-- talent gate itself is implicit via spell_ready -> spell_exists (unlearned
-- spells never get hemorrhage_ready = true).
assert_true(hemorrhage.matches({ target = {} }, { hemorrhage_ready = true, energy = 60 }),
    "Hemorrhage fires with energy")
assert_false(hemorrhage.matches({ target = {} }, { hemorrhage_ready = true, energy = 20 }),
    "Hemorrhage needs 35 energy")

-- Critical: GhostlyStrike — defensive only (was: every 20s ready tick).
assert_true(ghostly.matches({ is_pvp = false, target = {} },
    { ghostly_strike_ready = true, hp_pct = 30, energy = 50 }),
    "GhostlyStrike fires at low HP (defensive)")
assert_false(ghostly.matches({ is_pvp = false, target = {} },
    { ghostly_strike_ready = true, hp_pct = 80, energy = 50 }),
    "GhostlyStrike silent at high HP in PvE")
assert_true(ghostly.matches({ is_pvp = true, target = {} },
    { ghostly_strike_ready = true, hp_pct = 80, energy = 50 }),
    "GhostlyStrike fires in PvP")
assert_false(ghostly.matches({ is_pvp = true, target = {} },
    { ghostly_strike_ready = true, hp_pct = 80, energy = 20 }),
    "GhostlyStrike needs 40 energy")

-- Critical: Backstab — dagger + behind + energy (was: any ready tick).
-- No combo cap: finishers sit above this lane in dispatch (mirrors the TBC
-- sibling's Mutilate), and the battery's mutilate_daggers scenario must be
-- able to observe it.
assert_true(backstab.matches({ target = {} },
    { backstab_ready = true, has_daggers = true, is_behind = true, energy = 70, has_stealth = false, combo_points = 3 }),
    "Backstab fires with dagger + behind + energy")
assert_false(backstab.matches({ target = {} },
    { backstab_ready = true, has_daggers = true, is_behind = false, energy = 70, has_stealth = false, combo_points = 3 }),
    "Backstab blocked in front (no waste)")
assert_false(backstab.matches({ target = {} },
    { backstab_ready = true, has_daggers = false, is_behind = true, energy = 70, has_stealth = false, combo_points = 3 }),
    "Backstab blocked without daggers")
assert_false(backstab.matches({ target = {} },
    { backstab_ready = true, has_daggers = true, is_behind = true, energy = 40, has_stealth = false, combo_points = 3 }),
    "Backstab needs 60 energy")

-- Critical: KidneyShot — PvP + CP + energy (was: any ready tick).
assert_true(kidney.matches({ is_pvp = true, target = {} },
    { kidney_shot_ready = true, combo_points = 2, energy = 30 }),
    "KidneyShot fires in PvP with CP")
assert_false(kidney.matches({ is_pvp = false, target = {} },
    { kidney_shot_ready = true, combo_points = 2, energy = 30 }),
    "KidneyShot silent in PvE (stun breaks on damage)")
assert_false(kidney.matches({ is_pvp = true, target = {} },
    { kidney_shot_ready = true, combo_points = 0, energy = 30 }),
    "KidneyShot needs combo points")
assert_false(kidney.matches({ is_pvp = true, target = {} },
    { kidney_shot_ready = true, combo_points = 2, energy = 10 }),
    "KidneyShot needs 25 energy")
assert_false(kidney.matches({ is_pvp = true, target_dr_stun = 1, target = {} },
    { kidney_shot_ready = true, combo_points = 2, energy = 30 }),
    "KidneyShot respects stun DR")

-- Must: should_pool_energy was dead — now wired into the SS gate. With
-- tick-sync on, the cast is delayed when a tick is imminent and recovers
-- after the desync guard. (Module tick state evolves across these calls.)
local sync_on = { combat_energy_tick_sync = true, combat_energy_tick_offset = 0 }
combat_now = 1
assert_true(ss.matches({ settings = sync_on, energy = 60, target = {} },
    { sinister_strike_ready = true, energy_low = false }),
    "SS fires when no tick is imminent")
combat_now = 2
assert_false(ss.matches({ settings = sync_on, energy = 60, target = {} },
    { sinister_strike_ready = true, energy_low = false }),
    "SS pools when a tick is imminent (should_pool_energy wired)")
combat_now = 5
assert_true(ss.matches({ settings = sync_on, energy = 60, target = {} },
    { sinister_strike_ready = true, energy_low = false }),
    "SS recovers after tick desync guard")
assert_true(ss.matches({ settings = {}, energy = 60, target = {} },
    { sinister_strike_ready = true, energy_low = false }),
    "SS ignores pooling when tick-sync is off")

-- Must: energy fallback reads me:get_power(3) — NS.unit_energy_pct is
-- mock-only and resolved to hardcoded 100 live.
assert_true(type(captured_get_state) == "function", "combat build_state captured via registry")
local combat_build = captured_get_state
local st_e = combat_build({ me = { get_power = function(_, t) if t == 3 then return 42 end return 0 end }, target = {}, settings = {} })
assert_eq(st_e.energy, 42, "energy falls back to me:get_power(3) when context.energy absent")
local st_e2 = combat_build({ energy = 55, me = { get_power = function() return 42 end }, target = {}, settings = {} })
assert_eq(st_e2.energy, 55, "context.energy is authoritative")

-- Critical: dagger/behind state feeds the Backstab gate from real equipment.
_G.EaxRotations.EQUIPMENT_SLOTS = { MAIN_HAND = 0, OFF_HAND = 1 }
_G.EaxRotations.get_equipped_item_id = function(slot)
    if slot == 0 then return 776 end  -- Frostmane dagger
    return 899 -- dagger
end
local st_dag = combat_build({ me = {}, target = {}, settings = {}, energy = 50 })
assert_true(st_dag.has_daggers, "has_daggers computed from equipped dagger IDs")
assert_eq(st_dag.is_behind, false, "is_behind defaults false when NS.is_behind_target absent")

-- ============================================================================
-- 3. subtlety_vanilla
-- ============================================================================
local captured_sub_state = nil
_G.EaxRotations = {
    RogueSpells = {
        Ambush = 8676, Backstab = 53, Blind = 2094, CheapShot = 1833,
        Evasion = 5277, Eviscerate = 2098, ExposeArmor = 8647, Feint = 1966,
        Garrote = 703, GhostlyStrike = 14278, Gouge = 1776, Hemorrhage = 16511,
        KidneyShot = 8643, Kick = 1766, Premeditation = 14183, Preparation = 14185,
        Rupture = 1943, Sap = 6770, SinisterStrike = 1752, SliceAndDice = 5171,
        Sprint = 2983, Stealth = 1787, Vanish = 1856,
    },
    PLAYER_UNIT = "player",
    GetPlayer = function() return nil end,
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    has_player_buff = function() return false end,
    buff_remains = function() return 0 end,
    debuff_remains = function() return 0 end,
    is_behind_target = function() return true end,
    -- NOTE: get_spell_cd is deliberately ABSENT (mock-only member); the real
    -- member is get_spell_cooldown and the file must fall through to it.
    get_spell_cooldown = function(spell)
        if spell == 1856 then return 10 end  -- Vanish
        return 0
    end,
    try_interrupt = function() return false end,
    try_cast = function() return true end,
    should_use_long_cd = function() return true end,
    setting = function(context, key, default)
        local s = (context and context.settings) or {}
        if s[key] ~= nil then return s[key] end
        return default
    end,
    time_now = function() return 0 end,
    log = function() end,
    rotation_registry = { register = function(self, spec, strats, opts) captured_sub_state = opts and opts.get_state end },
}
local sub_strategies = dofile("EaxRotations/classes/rogue/subtlety_vanilla.lua")
if type(sub_strategies) == "table" and sub_strategies.strategies then
    sub_strategies = sub_strategies.strategies
end
assert_true(type(sub_strategies) == "table" and #sub_strategies > 0, "subtlety strategies load")

-- Critical: cooldown reads fall back to NS.get_spell_cooldown (was: always 0).
assert_true(type(captured_sub_state) == "function", "subtlety build_state captured via registry")
local sub_build = captured_sub_state
local st_sub = sub_build({ me = {}, target = {}, settings = {}, hp = 100, combo_points = 0, energy = 50, threat_pct = 0 })
assert_eq(st_sub.vanish_cd, 10, "vanish_cd reads NS.get_spell_cooldown fallback (Critical)")
assert_eq(st_sub.sprint_cd, 0, "sprint_cd reads fallback")
assert_eq(st_sub.evasion_cd, 0, "evasion_cd reads fallback")

-- Critical: Preparation's has_cd_burned gate now actually runs (it was
-- silently skipped because the `if NS.get_spell_cd` probe was always nil).
local prep = find_strategy(sub_strategies, "Preparation")
assert_true(prep.matches({ in_combat = true, should_burst = false, settings = { use_cooldowns = true }, target = {} },
    { hp = 30, vanish_cd = 10, sprint_cd = 0, evasion_cd = 0 }),
    "Preparation fires when a major CD is burned (has_cd_burned live)")
assert_false(prep.matches({ in_combat = true, should_burst = false, settings = { use_cooldowns = true }, target = {} },
    { hp = 30, vanish_cd = 0, sprint_cd = 0, evasion_cd = 0 }),
    "Preparation silent when no CD is burned")

-- Must: Ambush/Garrote openers respect state.is_behind (stealth not wasted).
local ambush = find_strategy(sub_strategies, "Ambush")
local garrote = find_strategy(sub_strategies, "Garrote")
assert_true(ambush.matches({ settings = {}, target = {} },
    { stealth_up = true, is_behind = true, energy = 60, combo = 0, is_caster_target = false }),
    "Ambush fires from stealth behind")
assert_false(ambush.matches({ settings = {}, target = {} },
    { stealth_up = true, is_behind = false, energy = 60, combo = 0, is_caster_target = false }),
    "Ambush blocked in front (stealth saved)")
assert_true(garrote.matches({ settings = { opener_preference = "garrote" }, target = {} },
    { stealth_up = true, is_behind = true, energy = 50, combo = 0 }),
    "Garrote fires from stealth behind")
assert_false(garrote.matches({ settings = { opener_preference = "garrote" }, target = {} },
    { stealth_up = true, is_behind = false, energy = 50, combo = 0 }),
    "Garrote blocked in front (stealth saved)")

-- Must: Stealth lane ordered above the OOC defensive lanes.
local _, stealth_idx = find_strategy(sub_strategies, "Stealth")
local _, evasion_idx = find_strategy(sub_strategies, "Evasion")
local _, ghostly_idx = find_strategy(sub_strategies, "GhostlyStrike")
assert_true(stealth_idx < evasion_idx, "Stealth lane before Evasion (no pre-pull defensive burn)")
assert_true(stealth_idx < ghostly_idx, "Stealth lane before GhostlyStrike")

-- Must: ExposeArmor assignment gate (TBC sibling key subtlety_expose_assigned).
local sub_expose = find_strategy(sub_strategies, "ExposeArmor")
assert_false(sub_expose.matches({ settings = { subtlety_expose_assigned = false }, target = {}, target_armor = 100, target_is_boss = true },
    { combo = 5, expose_remains = 0 }),
    "subtlety ExposeArmor gated OFF when not assigned")
assert_true(sub_expose.matches({ settings = { subtlety_expose_assigned = true }, target = {}, target_armor = 100, target_is_boss = true },
    { combo = 5, expose_remains = 0 }),
    "subtlety ExposeArmor fires when assigned")

-- Nit: Sap humanoid gate (failed casts burn stealth).
local sub_sap = find_strategy(sub_strategies, "Sap")
assert_true(sub_sap.matches({ settings = {}, target = {} },
    { stealth_up = true, combo = 0 }),
    "Sap fires when creature type is unknown (defensive default)")
assert_false(sub_sap.matches({ settings = {}, target = {}, target_creature_type = 1 },
    { stealth_up = true, combo = 0 }),
    "Sap blocked on non-humanoid (creature_type 1)")
assert_true(sub_sap.matches({ settings = {}, target = { get_creature_type = function() return 7 end } },
    { stealth_up = true, combo = 0 }),
    "Sap fires on humanoid via unit method")

-- ============================================================================
-- 4. leveling_vanilla
-- ============================================================================
local leveling_spell_exists_calls = {}
_G.EaxRotations = {
    RogueSpells = {
        SinisterStrike = { 1752 }, Eviscerate = { 2098 }, SliceAndDice = { 5171 },
        Rupture = { 1943 }, Garrote = { 863 }, Ambush = { 867 },
        -- Live class_sylvanas shape: an NS.spell_action table with _meta.ids.
        Kick = { _meta = { ids = { 1767, 1766 }, id = 1767 } },
        Gouge = { 1776 }, Evasion = { 5277 }, Sprint = { 2983 }, BladeFlurry = { 13877 },
        AdrenalineRush = { 13750 }, ColdBlood = { 14177 }, Vanish = { 1856 },
        Stealth = { 1784 }, KidneyShot = { 408 }, ExposeArmor = { 8647 },
        ThistleTea = { 9512 }, Sap = { 6770 }, Blind = { 2094 },
    },
    spell_exists = function(id) leveling_spell_exists_calls[#leveling_spell_exists_calls + 1] = id; return true end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_remains = function() return 0 end,
    get_setting = function() return nil end,
    GetPlayer = function() return {} end,
    log = function() end,
    rotation_registry = { register = function() end },
}
local leveling = dofile("EaxRotations/classes/rogue/leveling_vanilla.lua")
assert_true(type(leveling) == "table" and type(leveling.strategies) == "table", "leveling module loads")

-- Nit: HAS_KICK probes the learned action's first spell ID, not the hardcoded
-- 1766 fallback (SPELLS.Kick[1] is nil on live action tables).
local kick_resolved = false
for _, id in ipairs(leveling_spell_exists_calls) do
    if id == 1767 then kick_resolved = true end
end
assert_true(kick_resolved, "HAS_KICK probes the learned action's first spell ID (1767), not 1766")

local function lv_index(name)
    for i, s in ipairs(leveling.strategies) do
        if s.name == name then return i end
    end
    error("leveling strategy not found: " .. name, 2)
end

-- Must: Sap is ordered before the openers (was unreachable behind Ambush/Garrote).
assert_true(lv_index("Sap") < lv_index("Ambush"), "Sap lane before Ambush (reachable from stealth)")
assert_true(lv_index("Sap") < lv_index("Garrote"), "Sap lane before Garrote")

local lv_sap = find_strategy(leveling.strategies, "Sap")
assert_true(lv_sap.matches({ target = {}, target_creature_type = 7 },
    { in_combat = false, stealthed = true, sap_ready = true }),
    "leveling Sap fires on humanoids")
assert_false(lv_sap.matches({ target = {}, target_creature_type = 1 },
    { in_combat = false, stealthed = true, sap_ready = true }),
    "leveling Sap blocked on non-humanoids")

-- Nit: Gouge energy gate (45 cost).
local lv_gouge = find_strategy(leveling.strategies, "Gouge")
assert_true(lv_gouge.matches({ target = {} },
    { in_combat = true, gouge_ready = true, target = {}, hp = 30, energy = 60 }),
    "leveling Gouge fires with energy")
assert_false(lv_gouge.matches({ target = {} },
    { in_combat = true, gouge_ready = true, target = {}, hp = 30, energy = 20 }),
    "leveling Gouge needs 45 energy")

-- Nit: SnD < 3s refresh path.
local lv_snd = find_strategy(leveling.strategies, "SliceAndDice")
assert_true(lv_snd.matches({ target = {} },
    { in_combat = true, slice_and_dice_ready = true, has_slice_and_dice = true, slice_and_dice_remains = 1, combo_points = 2 }),
    "leveling SnD refreshes when < 3s remains")
assert_false(lv_snd.matches({ target = {} },
    { in_combat = true, slice_and_dice_ready = true, has_slice_and_dice = true, slice_and_dice_remains = 8, combo_points = 2 }),
    "leveling SnD stays silent while fresh")
assert_true(lv_snd.matches({ target = {} },
    { in_combat = true, slice_and_dice_ready = true, has_slice_and_dice = false, slice_and_dice_remains = 0, combo_points = 2 }),
    "leveling SnD fires when down")

print("PASS test_rogue_vanilla_live_fixes")
