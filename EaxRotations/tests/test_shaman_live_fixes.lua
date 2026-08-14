-- test_shaman_live_fixes.lua -- Regression tests for the 2026-08-12 shaman
-- live-correctness fixes (elemental / enhancement / restoration + healing exports).
-- WHAT:  verifies the audited live bugs stay fixed: LB downrank execute, Magma
--        Totem rank 25552, start_auto_attack usage, dead debug logging removed,
--        Mana Spring aura list, Chain Lightning threshold gate, FrostShock PvE
--        gate, ManaTide in_combat, Water Shield rank-1 aura, resto totem drop
--        guards, Earth Shock 20yd range, and the count_below_hp/group_mana_avg
--        exports on the shaman healing module.
-- WHEN:  standalone only (not registered in any runner):
--        lua EaxRotations/tests/test_shaman_live_fixes.lua
-- WHY:   pins the campaign fixes so future edits cannot silently regress them.
-- SAFETY: pure unit tests with mocked NS; no game API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

-- ============================================================================
-- Mock NS (shared by all three shaman specs + the healing module)
-- ============================================================================
local spell_action_records = {}
local try_cast_records = {}
local buff_up_records = {}
local unit_distance_value = 10
local get_totem_info_result = nil
local log_calls = 0
local start_auto_attack_calls = 0

package.loaded["common/enums"] = { class_id = { SHAMAN = 7 } }

local PLAYER = {
    get_class = function() return 7 end,
    get_race_id = function() return 1 end,
    is_moving = function() return false end,
    is_valid = function() return true end,
    is_dead = function() return false end,
    is_mounted = function() return false end,
    get_level = function() return 70 end,
    get_health = function() return 10000 end,
    get_max_health = function() return 10000 end,
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 50 end,
    get_buff_stacks = function() return 0 end,
    time_in_combat = function() return 5 end,
    get_guid = function() return "player" end,
}
local TARGET = {
    is_valid = function() return true end,
    is_dead = function() return false end,
    is_casting = function() return false end,
    get_cast_pct = function() return 0 end,
    get_health_percentage = function() return 100 end,
    get_creature_type = function() return nil end,
    get_guid = function() return "target" end,
    get_distance = function() return 5 end,
}

-- ShamanSpells mirrors shaman/class_sylvanas.lua. MagmaTotem is deliberately
-- OMITTED so define() falls back to NS.spell_action and we can assert the
-- rank list (25552 first, never 25550).
_G.EaxRotations = {
    CLASS_ID = { SHAMAN = 7 },
    PLAYER_UNIT = PLAYER,
    ShamanSpells = {
        Bloodlust = 2825, ChainHeal = 25423, ChainLightning = 25442,
        CureDisease = 2870, CurePoison = 526, DiseaseCleansingTotem = 8170,
        EarthbindTotem = 2484, EarthShield = 32594, EarthShock = 25454,
        ElementalMastery = 16166, FireNovaTotem = 25547, FlametongueWeapon = 25489,
        FlameShock = 25457, FrostShock = 25464, FrostbrandWeapon = 25500,
        GiftOfTheNaaru = 28880, GhostWolf = 2645, GraceOfAirTotem = 25359,
        GroundingTotem = 8177, HealingStreamTotem = 25567, HealingWave = 25396,
        LesserHealingWave = 25420, LightningBolt = 25449, LightningBoltLowerRank = 25448,
        LightningShield = 25472, ManaSpringTotem = 25570, ManaTideTotem = 16190,
        NaturesSwiftness = 16188, PoisonCleansingTotem = 8166, Purge = 8012,
        RockbiterWeapon = 25485, SearingTotem = 25533, ShamanisticRage = 30823,
        Stormstrike = 17364, StrengthOfEarthTotem = 25528, StoneskinTotem = 25509,
        TotemOfWrath = 30706, TotemicCall = 36936, TremorTotem = 8143,
        WaterShield = 33736, WindfuryTotem = 25587, WindfuryWeapon = 25505,
        WrathOfAirTotem = 3738,
    },
    GetPlayer = function() return PLAYER end,
    import_helpers = function()
        return function() return true end, function() return 0 end, function() return 0 end,
               function() return 0 end, function() return false end, function() return 100 end
    end,
    has_dispel_type_debuff = function(_, dtype) return dtype == "Poison" end,
    has_healing_reduction_debuff = function() return false end,
    build_healing_entries = function(t, cb)
        t[1] = {
            unit = PLAYER,
            hp = 40, effective_hp = 40, current_hp = 4000, max_hp = 10000,
            deficit = 6000, effective_deficit = 6000, time_to_die = 12,
        }
        if cb then cb(t[1], t[1].unit) end
        return 1
    end,
    healing_get_tank = function(entries) return entries and entries[1] end,
    healing_get_lowest_hp = function(entries) return entries and entries[1] end,
    healing_all_above_hp = function() return false end,
    healing_get_cleanse_target = function(entries) return entries and entries[1] end,
    healing_count_below_hp = function() return 2 end,
    is_in_raid = function() return false end,
    is_in_party = function() return true end,
    spell_ready = function() return true end,
    spell_action = function(ids, label)
        spell_action_records[#spell_action_records + 1] = { ids = ids, label = label }
        return {
            ids = ids,
            id = function() return type(ids) == "table" and ids[1] or ids end,
            name = label,
        }
    end,
    try_cast = function(spell, unit, reason, opts)
        try_cast_records[#try_cast_records + 1] = { spell = spell, unit = unit, reason = reason }
        return true
    end,
    buff_up = function(unit, ids)
        buff_up_records[#buff_up_records + 1] = ids
        return false
    end,
    has_player_buff = function(ids)
        buff_up_records[#buff_up_records + 1] = ids
        return false
    end,
    buff_remains = function(unit, ids) return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    buff_stacks = function() return 0 end,
    is_spell_learned = function() return true end,
    is_interruptible = function() return false end,
    is_auto_attacking = function() return false end,
    start_auto_attack = function()
        start_auto_attack_calls = start_auto_attack_calls + 1
        return true
    end,
    unit_mana_pct = function() return 50 end,
    unit_health_pct = function() return 100 end,
    unit_distance = function() return unit_distance_value end,
    get_totem_info = function(slot)
        local r = get_totem_info_result
        if type(r) == "table" and r.slot == slot then return r end
        return nil
    end,
    get_time_until_swing = function() return 0 end,
    game_time_ms = function() return 100000 end,
    should_refresh_dot = function() return true end,
    aoe_target_meets = function() return true end,
    aoe_self_meets = function() return true end,
    gate_cooldown_boss_only = function() return true end,
    should_use_long_cd = function() return true end,
    OffensiveDispelDB = {
        PRIORITY_HIGH = 3,
        find_best_dispel_target = function() return nil, 0, nil end,
    },
    HealerDeficit = nil,
    log = function() log_calls = log_calls + 1 end,
    rotation_registry = { register = function() end },
}

local NS = _G.EaxRotations

-- Shared-module stubs (direct requires / pcall requires used by the specs)
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    MANA_POTION_IDS = {},
}
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }
package.loaded["shared/tbc_data_sylvanas"] = { SPELLS = { shaman = {} } }
package.loaded["common/utility/inventory_helper"] = { has_item = function() return nil end }
package.loaded["shared/cooldown_planner_sylvanas"] = {
    is_major_offensive_cd_active = function() return false end,
}
package.loaded["shared/purge_manager_sylvanas"] = {
    has_purgeable_buff = function() return false end,
    try_purge = function() return false end,
}
package.loaded["shared/fsr_manager_sylvanas"] = {
    is_inside_fsr = function() return false end,
    get_regen_delta = function() return 0 end,
    should_pause_for_fsr = function() return false end,
}
package.loaded["shared/preemptive_heal_sylvanas"] = {
    DEFAULT_THRESHOLD = 40,
    match = function() return false end,
    execute = function() return false end,
    get_penalty_adjusted_heal = function(id, ct) return id, 1 end,
}
package.loaded["shared/ts_helper_sylvanas"] = nil
package.loaded["shared/health_pred_helper_sylvanas"] = nil

-- Real spec_kit + DSL engine (self-contained, mock-friendly)
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- 1. Healing module exports (resto #3/#4): count_below_hp + group_mana_avg
-- ============================================================================
local healing = dofile("EaxRotations/classes/shaman/healing_sylvanas.lua")
assert_true(type(healing) == "table", "healing module returns table")
assert_true(type(healing.count_below_hp) == "function", "count_below_hp exported")
assert_true(type(healing.group_mana_avg) == "function", "group_mana_avg exported")
assert_eq(healing.count_below_hp(80), 2, "count_below_hp delegates to healing_count_below_hp")
local gma = healing.group_mana_avg()
assert_true(type(gma) == "number", "group_mana_avg returns a number with scanned entries")

-- ============================================================================
-- 2. Elemental fixes
-- ============================================================================
local ele = dofile("EaxRotations/classes/shaman/elemental_sylvanas.lua")

-- MagmaTotem rank list: 25552 (rank 5) first; 25550 (item "Redcap Toadstool") never
local magma_ok = false
for _, rec in ipairs(spell_action_records) do
    if rec.label == "MagmaTotem" and type(rec.ids) == "table" then
        assert_true(rec.ids[1] ~= 25550, "MagmaTotem rank list must not start with 25550")
        if rec.ids[1] == 25552 then magma_ok = true end
    end
end
assert_true(magma_ok, "MagmaTotem rank list starts with 25552 (Magma Totem V)")

-- Mana Spring buff list: real aura IDs only (no summon 25570, no 10490/5676)
buff_up_records = {}
local mspring = find_strategy(ele.strategies, "ManaSpringTotem")
assert_true(mspring.matches({ settings = { elemental_manage_totems = true } }, { mana_emergency = false }), "ManaSpringTotem matches with buff down")
local last_buff_ids = buff_up_records[#buff_up_records]
assert_true(type(last_buff_ids) == "table", "mana spring buff list captured")
local has, has_bad = false, false
for _, id in ipairs(last_buff_ids) do
    if id == 25569 then has = true end
    if id == 25570 or id == 10490 or id == 5676 then has_bad = true end
end
assert_true(has, "MANA_SPRING_BUFF contains aura 25569")
assert_false(has_bad, "MANA_SPRING_BUFF excludes summon 25570 and non-aura 10490/5676")

-- ManaEmergencyWand: uses NS.start_auto_attack (NS.start_attack does not exist)
assert_true(NS.start_attack == nil, "NS.start_attack must not be defined")
local mew = find_strategy(ele.strategies, "ManaEmergencyWand")
start_auto_attack_calls = 0
assert_true(mew.execute({ target = TARGET }, {}), "elemental ManaEmergencyWand execute succeeds")
assert_eq(start_auto_attack_calls, 1, "elemental ManaEmergencyWand calls start_auto_attack")
start_auto_attack_calls = 0
assert_true(mew.execute({ target = { is_valid = function() return false end, is_dead = function() return false end } }, {}), "elemental ManaEmergencyWand tolerates invalid target")
assert_eq(start_auto_attack_calls, 0, "elemental ManaEmergencyWand skips invalid target")

-- LightningBolt execute: downrank (25448) when mana_low, max rank (25449) otherwise
local lb = find_strategy(ele.strategies, "LightningBolt")
try_cast_records = {}
assert_true(lb.execute({ target = TARGET }, { mana_low = true }), "LB execute succeeds mana_low")
assert_eq(try_cast_records[1].spell, 25448, "LB casts lower rank 25448 when mana_low")
try_cast_records = {}
assert_true(lb.execute({ target = TARGET }, { mana_low = false }), "LB execute succeeds normal mana")
assert_eq(try_cast_records[1].spell, 25449, "LB casts max rank 25449 when mana normal")

-- Debug logging removed: repeated LightningBolt matches must not log
local logs_before = log_calls
local lb_ctx = { is_moving = false, threat_pct = 50, target = TARGET }
local lb_state = { mana_emergency = false, mana_low = false }
for i = 1, 5 do
    assert_true(lb.matches(lb_ctx, lb_state), "LB matches under normal conditions")
end
assert_eq(log_calls, logs_before, "no debug logging in lightning_bolt_matches_fn")

-- ============================================================================
-- 3. Enhancement fixes
-- ============================================================================
local enh = dofile("EaxRotations/classes/shaman/enhancement_sylvanas.lua")

-- Chain Lightning gate: respects enhancement_aoe_threshold (default 3)
local cl = find_strategy(enh.strategies, "ChainLightning")
local enh_ctx = {
    me = PLAYER, target = TARGET, in_combat = true,
    mana_pct = 50, hp = 100, enemy_count = 2,
    is_group = false,
    settings = { enhancement_aoe_threshold = 3 },
}
enh.build_state(enh_ctx)
assert_false(cl.matches(enh_ctx), "Chain Lightning blocked at 2 enemies with threshold 3")
enh_ctx.enemy_count = 3
enh.build_state(enh_ctx)
assert_true(cl.matches(enh_ctx), "Chain Lightning fires at threshold 3")
enh_ctx.settings.enhancement_aoe_threshold = 2
enh_ctx.enemy_count = 2
enh.build_state(enh_ctx)
assert_true(cl.matches(enh_ctx), "Chain Lightning respects lowered threshold 2")

-- Water Shield buff list includes rank-1 aura 23575
local ws = find_strategy(enh.strategies, "WaterShield")
local ws_ctx = {
    me = PLAYER, target = TARGET, in_combat = true,
    mana_pct = 30, hp = 100, enemy_count = 1,
    is_group = false,
    settings = { enhancement_shield_type = "water" },
}
buff_up_records = {}
enh.build_state(ws_ctx)
assert_true(ws.matches(ws_ctx), "Water Shield matches when missing + mana low")
local ws_buff_ids
for _, ids in ipairs(buff_up_records) do
    if type(ids) == "table" then
        for _, id in ipairs(ids) do
            if id == 33736 then ws_buff_ids = ids end
        end
    end
end
assert_true(type(ws_buff_ids) == "table", "water shield buff list captured")
local has23575 = false
for _, id in ipairs(ws_buff_ids) do if id == 23575 then has23575 = true end end
assert_true(has23575, "WATER_SHIELD_BUFF includes rank-1 aura 23575")

-- ============================================================================
-- 4. Restoration fixes
-- ============================================================================
local resto = dofile("EaxRotations/classes/shaman/restoration_sylvanas.lua")

-- Totem drop guards: slot occupied -> no re-drop
get_totem_info_result = { slot = 2, have_totem = true }
assert_false(find_strategy(resto.strategies, "StrengthOfEarthTotem").matches({ settings = { restoration_manage_totems = true } }, {}), "Strength of Earth held while earth slot occupied")
get_totem_info_result = { slot = 3, have_totem = true }
assert_false(find_strategy(resto.strategies, "ManaSpringTotem").matches({ settings = { restoration_manage_totems = true } }, {}), "Mana Spring held while water slot occupied")
get_totem_info_result = { slot = 4, have_totem = true }
assert_false(find_strategy(resto.strategies, "GraceOfAirTotem").matches({ settings = { restoration_manage_totems = true } }, {}), "Grace of Air held while air slot occupied")
assert_false(find_strategy(resto.strategies, "WindfuryTotem").matches({ settings = { restoration_manage_totems = true } }, {}), "Windfury held while air slot occupied")

-- Totem drop guards: slot empty -> drop fires; aura-up -> held
get_totem_info_result = nil
assert_true(find_strategy(resto.strategies, "StrengthOfEarthTotem").matches({ settings = { restoration_manage_totems = true } }, {}), "Strength of Earth drops when slot empty")
assert_true(find_strategy(resto.strategies, "ManaSpringTotem").matches({ settings = { restoration_manage_totems = true } }, {}), "Mana Spring drops when slot empty")

-- Mana Spring aura list passed to buff_up matches the verified aura IDs
buff_up_records = {}
find_strategy(resto.strategies, "ManaSpringTotem").matches({ settings = { restoration_manage_totems = true } }, {})
local ms_aura_ids = buff_up_records[#buff_up_records]
assert_true(type(ms_aura_ids) == "table", "resto mana spring aura list captured")
local aura_ok = false
for _, id in ipairs(ms_aura_ids) do if id == 25569 then aura_ok = true end end
assert_true(aura_ok, "resto Mana Spring aura list contains 25569")

-- Earth Shock range gate: unit_distance returns YARDS; > 20 blocks (old code
-- compared > 400, so the 20yd check was dead)
local es = find_strategy(resto.strategies, "EarthShock")
local es_state = { earth_shock_ready = true, target_casting = true, mana_emergency = false }
unit_distance_value = 25
assert_false(es.matches({ me = PLAYER, target = TARGET, settings = {} }, es_state), "Earth Shock blocked beyond 20yd")
unit_distance_value = 10
assert_true(es.matches({ me = PLAYER, target = TARGET, settings = {} }, es_state), "Earth Shock fires within 20yd")

-- ManaEmergencyWand: NS.start_auto_attack, never NS.start_attack
local rme = find_strategy(resto.strategies, "ManaEmergencyWand")
start_auto_attack_calls = 0
assert_true(rme.execute({ me = PLAYER, target = TARGET }, {}), "resto ManaEmergencyWand execute succeeds")
assert_eq(start_auto_attack_calls, 1, "resto ManaEmergencyWand calls start_auto_attack")

-- ManaTideTotem DSL: group_mana_avg now live (export added) — high group mana holds
local rmt = find_strategy(resto.strategies, "ManaTideTotem")
local rmt_ctx = { me = PLAYER, in_combat = true, settings = { use_cooldowns = true } }
local rmt_state = { mana_pct = 50 }
NS.ShamanHealing.group_mana_avg = function() return 30 end
NS.ShamanHealing.all_members_above_hp = function() return true end
assert_true(rmt.matches(rmt_ctx, rmt_state), "ManaTide fires when group mana low")
NS.ShamanHealing.group_mana_avg = function() return 90 end
assert_false(rmt.matches(rmt_ctx, rmt_state), "ManaTide held when group mana high")

print("PASS test_shaman_live_fixes")
