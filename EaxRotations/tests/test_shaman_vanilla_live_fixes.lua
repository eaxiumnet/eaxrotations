-- test_shaman_vanilla_live_fixes.lua -- Regression tests for the 2026-08-13
-- Wave 1.3 vanilla shaman live-correctness fixes (elemental / enhancement /
-- restoration / leveling).
-- WHAT:  verifies the audited live bugs stay fixed: resto HealingWay tank-HP
--        gate (Healing Way is TBC-only), totem slot-occupancy gates, Earth
--        Shock linear-yard range (unit_distance), ManaEmergencyWand
--        start_auto_attack + wand type, enh Lightning Shield charges via
--        NS.buff_stacks (not me:get_buff_stacks), ele local vanilla LB
--        downrank (10392/10391/15207 — never the TBC 25448), leveling tremor
--        fear gate, ghost wolf no-target, and the imbue enchant-id check.
-- WHEN:  standalone only (not registered in any runner):
--        lua EaxRotations/tests/test_shaman_vanilla_live_fixes.lua
-- WHY:   pins the campaign fixes so future edits cannot silently regress them.
-- SAFETY: pure unit tests with mocked NS; no game API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

-- ============================================================================
-- Mock NS (shared by all four shaman vanilla specs)
-- ============================================================================
local spell_ready_records = {}
local try_cast_records = {}
local start_auto_attack_calls = 0
local start_auto_attack_args = nil
local buff_stacks_records = {}
local buff_stacks_value = 0
local unit_distance_value = 15
local get_totem_info_by_slot = {}
local _registered_get_state = {}

package.loaded["common/enums"] = { class_id = { SHAMAN = 7 } }

local PLAYER = {
    get_class = function() return 7 end,
    get_race_id = function() return 1 end,
    is_moving = function() return false end,
    is_valid = function() return true end,
    is_dead = function() return false end,
    is_mounted = function() return false end,
    get_level = function() return 60 end,
    get_health = function() return 10000 end,
    get_max_health = function() return 10000 end,
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 50 end,
    get_buff_stacks = function() return 0 end,  -- scalar unit method: must NOT be used with a table
    get_guid = function() return "player" end,
}
local TARGET = {
    is_valid = function() return true end,
    is_dead = function() return false end,
    is_casting = function() return false end,
    get_cast_pct = function() return 0 end,
    get_health_percentage = function() return 100 end,
    get_guid = function() return "target" end,
    get_distance = function() return 5 end,
}

-- ShamanSpells mirrors shaman/class_sylvanas.lua vanilla-relevant keys with
-- VANILLA ids. LightningBolt is the vanilla max rank (15207); the local
-- downrank table in elemental_vanilla.lua must resolve to 10392 first.
_G.EaxRotations = {
    CLASS_ID = { SHAMAN = 7 },
    PLAYER_UNIT = PLAYER,
    ShamanSpells = {
        ChainHeal = 1064, ChainLightning = 421, CureDisease = 528,
        CurePoison = 526, DiseaseCleansingTotem = 8170, EarthbindTotem = 2484,
        EarthShock = 8042, ElementalMastery = 16166, FlameShock = 8050,
        FireNovaTotem = 15499, FlametongueWeapon = 8024, FrostShock = 8056,
        FrostbrandWeapon = 8033, GhostWolf = 2645, GiftOfTheNaaru = 59547,
        GraceOfAirTotem = 8835, GroundingTotem = 8177, HealingWave = 331,
        HealingStreamTotem = 5672, LesserHealingWave = 8004,
        LightningBolt = 15207, LightningShield = 324, MagmaTotem = 8190,
        ManaSpringTotem = 5675, ManaTideTotem = 16190, NaturesSwiftness = 16166,
        PoisonCleansingTotem = 8166, Purge = 370, RockbiterWeapon = 8017,
        SearingTotem = 3599, StrengthOfEarthTotem = 8075, Stormstrike = 17364,
        StoneclawTotem = 5730, TremorTotem = 8143, WindfuryTotem = 8512,
        WindfuryWeapon = 8232, WrathOfAirTotem = 3738, TotemicCall = 36936,
    },
    GetPlayer = function() return PLAYER end,
    spell_action = function(cfg, label)
        if type(cfg) == "table" and (cfg.ids or cfg.name) and not cfg[1] then
            return {
                ids = cfg.ids or {},
                name = cfg.name or label or "spell",
                id = function() return (cfg.ids and cfg.ids[1]) or nil end,
            }
        end
        local ids = type(cfg) == "table" and cfg or { cfg }
        return { ids = ids, name = label or tostring(cfg), id = function() return ids[1] end }
    end,
    spell_ready = function(spell, target, opts)
        spell_ready_records[#spell_ready_records + 1] = spell
        return true
    end,
    is_spell_learned = function() return true end,
    try_cast = function(spell, unit, reason, opts)
        try_cast_records[#try_cast_records + 1] = { spell = spell, unit = unit, reason = reason }
        return true
    end,
    buff_up = function() return true end,
    has_player_buff = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    buff_stacks = function(unit, ids)
        buff_stacks_records[#buff_stacks_records + 1] = ids
        return buff_stacks_value
    end,
    is_interruptible = function() return false end,
    is_auto_attacking = function() return false end,
    start_auto_attack = function(target, attack_type)
        start_auto_attack_calls = start_auto_attack_calls + 1
        start_auto_attack_args = { target = target, attack_type = attack_type }
        return true
    end,
    AUTO_ATTACK_WAND = 5019,
    unit_mana_pct = function() return 50 end,
    unit_health_pct = function() return 100 end,
    unit_distance = function() return unit_distance_value end,
    get_totem_info = function(slot)
        return get_totem_info_by_slot[slot] or nil
    end,
    get_distance = function() return unit_distance_value end,
    game_time_ms = function() return 100000 end,
    should_refresh_dot = function() return true end,
    should_use_long_cd = function() return true end,
    WeaponImbueManager = {
        mainhand_has_imbue = function() return false end,
        offhand_has_imbue = function() return false end,
        get_mainhand_enchant_info = function() return nil end,
        get_offhand_enchant_info = function() return nil end,
    },
    ShamanHealing = {
        scan_healing_targets = function() return {}, 0 end,
        select_heal = function() return nil end,
        count_below_hp = function() return 1 end,
        group_mana_avg = function() return 100 end,
        all_members_above_hp = function() return true end,
        get_cleanse_target = function() return nil end,
    },
    log = function() end,
    rotation_registry = {
        register = function(self, spec, strategies, opts)
            _registered_get_state[spec] = opts and opts.get_state
        end,
    },
}

local NS = _G.EaxRotations

-- Shared-module stubs (direct requires used by the specs)
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    MANA_POTION_IDS = {},
}
package.loaded["shared/leveling_sylvanas"] = {
    create_context_guard = function() return function() return true end end,
    build_common_state = function() end,
    create_wand_matches = function() return function() return false end end,
    execute_wand = function() return false end,
}

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- 1. Elemental fixes
-- ============================================================================
local ele = dofile("EaxRotations/classes/shaman/elemental_vanilla.lua")

-- 1a. ManaEmergencyWand: uses NS.start_auto_attack (NS.start_attack is a
-- mock-only stub — undefined in core_sylvanas.lua)
assert_true(NS.start_attack == nil, "NS.start_attack must not be defined")
local ele_mew = find_strategy(ele, "ManaEmergencyWand")
start_auto_attack_calls = 0
start_auto_attack_args = nil
assert_true(ele_mew.execute({ target = TARGET }, {}), "elemental ManaEmergencyWand execute succeeds")
assert_eq(start_auto_attack_calls, 1, "elemental ManaEmergencyWand calls start_auto_attack")
assert_eq(start_auto_attack_args.attack_type, NS.AUTO_ATTACK_WAND, "elemental ManaEmergencyWand passes AUTO_ATTACK_WAND")
assert_eq(start_auto_attack_args.target, TARGET, "elemental ManaEmergencyWand targets the valid target")
start_auto_attack_calls = 0
assert_true(ele_mew.execute({ target = { is_valid = function() return false end, is_dead = function() return false end } }, {}), "elemental ManaEmergencyWand tolerates invalid target")
assert_eq(start_auto_attack_calls, 0, "elemental ManaEmergencyWand skips invalid target")
start_auto_attack_calls = 0
assert_true(ele_mew.execute({}, {}), "elemental ManaEmergencyWand tolerates no target")
assert_eq(start_auto_attack_calls, 0, "elemental ManaEmergencyWand skips missing target")

-- 1b. LightningBolt: local vanilla downrank (10392 first) at mana_low, max
-- rank otherwise — never the TBC rank 25448 from class_sylvanas.lua.
local ele_lb = find_strategy(ele, "LightningBolt")
spell_ready_records = {}
assert_true(ele_lb.matches({ target = TARGET }, { mana_low = true }), "elemental LB matches with mana_low")
local resolved_low = spell_ready_records[#spell_ready_records]
assert_true(type(resolved_low) == "table" and resolved_low.ids and resolved_low.ids[1] == 10392,
    "elemental LB matches resolves local vanilla downrank 10392, got " .. tostring(resolved_low and resolved_low.ids and resolved_low.ids[1]))
try_cast_records = {}
assert_true(ele_lb.execute({ target = TARGET }, { mana_low = true }), "elemental LB execute succeeds mana_low")
assert_eq(try_cast_records[1].spell.ids[1], 10392, "elemental LB casts local downrank 10392 at mana_low")
assert_false(try_cast_records[1].spell.ids[2] ~= 10391, "elemental LB downrank list includes 10391 fallback")
assert_false(try_cast_records[1].spell.ids[3] ~= 15207, "elemental LB downrank list includes 15207 fallback")
for _, id in ipairs(try_cast_records[1].spell.ids) do
    assert_true(id ~= 25448, "elemental LB downrank must never resolve TBC rank 25448")
end
try_cast_records = {}
assert_true(ele_lb.execute({ target = TARGET }, { mana_low = false }), "elemental LB execute succeeds full mana")
assert_eq(try_cast_records[1].spell, 15207, "elemental LB casts max rank when not mana_low")

-- ============================================================================
-- 2. Enhancement fixes
-- ============================================================================
local enh = dofile("EaxRotations/classes/shaman/enhancement_vanilla.lua")
local enh_get_state = _registered_get_state["enhancement"]
assert_true(type(enh_get_state) == "function", "enhancement build_state captured")

-- 2a. Lightning Shield charges come from NS.buff_stacks (multi-id table
-- aware); me:get_buff_stacks (scalar, returns 0 here) must NOT be used.
buff_stacks_value = 3
buff_stacks_records = {}
local enh_state = enh_get_state({ me = PLAYER, settings = {}, in_combat = true, mana_pct = 100, hp = 100, enemy_count = 1 })
assert_eq(enh_state.lightning_shield_charges, 3, "enhancement LS charges read via NS.buff_stacks (3), not me:get_buff_stacks (0)")
assert_true(type(buff_stacks_records[1]) == "table" and #buff_stacks_records[1] == 7,
    "enhancement NS.buff_stacks receives the 7-id LIGHTNING_SHIELD_BUFF table")

-- 2b. Shield refresh gate: charges > 1 -> hold; charges <= 1 -> refresh.
local enh_ls = find_strategy(enh, "LightningShield")
buff_stacks_value = 3
enh_get_state({ me = PLAYER, settings = {}, in_combat = true, mana_pct = 100, hp = 100, enemy_count = 1 })
assert_false(enh_ls.matches({ settings = {} }), "enhancement LS held while charges > 1")
buff_stacks_value = 0
enh_get_state({ me = PLAYER, settings = {}, in_combat = true, mana_pct = 100, hp = 100, enemy_count = 1 })
assert_true(enh_ls.matches({ settings = {} }), "enhancement LS refreshes at 0 charges")

-- ============================================================================
-- 3. Restoration fixes
-- ============================================================================
local resto = dofile("EaxRotations/classes/shaman/restoration_vanilla.lua")
local resto_strategies = resto.strategies or resto

-- 3a. HealingWay: gated on tank HP (Healing Way talent is TBC-only; empty
-- buff table -> stacks/remains inert) + overheal gate.
local resto_hw = find_strategy(resto_strategies, "HealingWay")
assert_false(resto_hw.matches({ settings = {} }, { tank = nil }), "HealingWay requires a tank")
assert_true(resto_hw.matches({ settings = {} }, { tank = { unit = TARGET, effective_hp = 50 }, healing_wave_ready = true }),
    "HealingWay matches when tank injured (50% <= 80)")
assert_false(resto_hw.matches({ settings = {} }, { tank = { unit = TARGET, effective_hp = 90 }, healing_wave_ready = true }),
    "HealingWay held when tank healthy (90% > 80)")
assert_true(resto_hw.matches({ settings = {} }, { tank = { unit = TARGET, hp_pct = 75 }, healing_wave_ready = true }),
    "HealingWay falls back to tank.hp_pct when effective_hp missing")
assert_false(resto_hw.matches({ settings = {} }, { tank = { unit = TARGET, effective_hp = 50 }, healing_wave_ready = false }),
    "HealingWay requires Healing Wave ready")

-- 3b. Totem lanes: slot occupancy gates (fire=1, earth=2, water=3, air=4)
local resto_soe = find_strategy(resto_strategies, "StrengthOfEarthTotem")
local resto_ms = find_strategy(resto_strategies, "ManaSpringTotem")
local resto_goa = find_strategy(resto_strategies, "GraceOfAirTotem")
local resto_wf = find_strategy(resto_strategies, "WindfuryTotem")
get_totem_info_by_slot = { [2] = { have_totem = true } }
assert_false(resto_soe.matches({ settings = { restoration_manage_totems = true } }, {}), "Strength of Earth held while earth slot occupied")
get_totem_info_by_slot = {}
assert_true(resto_soe.matches({ settings = { restoration_manage_totems = true } }, {}), "Strength of Earth drops when earth slot free")
get_totem_info_by_slot = { [3] = { have_totem = true } }
assert_false(resto_ms.matches({ settings = { restoration_manage_totems = true } }, {}), "Mana Spring held while water slot occupied")
get_totem_info_by_slot = {}
assert_true(resto_ms.matches({ settings = { restoration_manage_totems = true } }, {}), "Mana Spring drops when water slot free")
get_totem_info_by_slot = { [4] = { have_totem = true } }
assert_false(resto_goa.matches({ settings = { restoration_manage_totems = true } }, {}), "Grace of Air held while air slot occupied")
assert_false(resto_wf.matches({ settings = { restoration_manage_totems = true } }, {}), "Windfury held while air slot occupied")
get_totem_info_by_slot = {}
assert_true(resto_goa.matches({ settings = { restoration_manage_totems = true } }, {}), "Grace of Air drops when air slot free")
assert_true(resto_wf.matches({ settings = { restoration_manage_totems = true } }, {}), "Windfury drops when air slot free")
assert_false(resto_soe.matches({ settings = { restoration_manage_totems = false } }, {}), "totems held when manage_totems disabled")

-- 3c. Earth Shock range: NS.unit_distance returns LINEAR yards -> > 20 blocks
local resto_es = find_strategy(resto_strategies, "EarthShock")
unit_distance_value = 25
assert_false(resto_es.matches({ target = TARGET, me = PLAYER }, { earth_shock_ready = true, target_casting = true, mana_emergency = false }),
    "Earth Shock blocked beyond 20yd (linear)")
unit_distance_value = 15
assert_true(resto_es.matches({ target = TARGET, me = PLAYER }, { earth_shock_ready = true, target_casting = true, mana_emergency = false }),
    "Earth Shock allowed within 20yd (linear)")

-- 3d. ManaEmergencyWand: start_auto_attack + target validation
local resto_mew = find_strategy(resto_strategies, "ManaEmergencyWand")
start_auto_attack_calls = 0
start_auto_attack_args = nil
assert_true(resto_mew.execute({ target = TARGET }, {}), "resto ManaEmergencyWand execute succeeds")
assert_eq(start_auto_attack_calls, 1, "resto ManaEmergencyWand calls start_auto_attack")
assert_eq(start_auto_attack_args.attack_type, NS.AUTO_ATTACK_WAND, "resto ManaEmergencyWand passes AUTO_ATTACK_WAND")
start_auto_attack_calls = 0
assert_true(resto_mew.execute({ target = { is_valid = function() return false end, is_dead = function() return false end } }, {}), "resto ManaEmergencyWand tolerates invalid target")
assert_eq(start_auto_attack_calls, 0, "resto ManaEmergencyWand skips invalid target")

-- ============================================================================
-- 4. Leveling fixes
-- ============================================================================
local lvl = dofile("EaxRotations/classes/shaman/leveling_vanilla.lua")
local lvl_strategies = lvl.strategies or {}

-- 4a. Tremor Totem: fear/charm gate (context.fear_nearby, same as
-- enhancement/restoration)
local lvl_tremor = find_strategy(lvl_strategies, "TremorTotem")
assert_false(lvl_tremor.matches({ fear_nearby = false }, { tremor_totem_ready = true, in_combat = true, mana_pct = 100 }),
    "leveling Tremor held without fear/charm nearby")
assert_true(lvl_tremor.matches({ fear_nearby = true }, { tremor_totem_ready = true, in_combat = true, mana_pct = 100 }),
    "leveling Tremor drops with fear nearby")

-- 4b. Ghost Wolf: no target required (travel/escape form)
local lvl_gw = find_strategy(lvl_strategies, "GhostWolf")
unit_distance_value = 30
assert_true(lvl_gw.matches({}, { in_combat = false, ghost_wolf_ready = true }),
    "leveling Ghost Wolf matches with no target")
assert_true(lvl_gw.matches({ target = TARGET }, { in_combat = false, ghost_wolf_ready = true }),
    "leveling Ghost Wolf matches with distant target")
unit_distance_value = 10
assert_false(lvl_gw.matches({ target = TARGET }, { in_combat = false, ghost_wolf_ready = true }),
    "leveling Ghost Wolf held with close target")

-- 4c. EarthShock lane intact (single earth_shock_dps_matches definition;
-- leveling compliance requires the name)
local lvl_es = find_strategy(lvl_strategies, "EarthShock")
assert_true(lvl_es.matches({ has_valid_enemy_target = true, in_combat = true }, { target = TARGET, earth_shock_ready = true, use_shocks = true, default_shock = "earth" }),
    "leveling EarthShock matches with earth default")

-- ============================================================================
-- Report
-- ============================================================================
print("PASS test_shaman_vanilla_live_fixes")
