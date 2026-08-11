-- assassination_sylvanas.lua — Rogue Assassination DPS for TBC Anniversary (2.5.5).
-- WHAT:  dagger DPS spec (Mutilate, Shiv, Envenom, Rupture, Slice and Dice)
--         with wowsims-aligned finisher priority: SnD > Rupture > Envenom > Mutilate.
-- WHEN:  combat, with valid enemy target and daggers equipped.
-- WHY:   mirrors wowsims APL: SnD > Rupture > Envenom > Mutilate builder.
-- SAFETY: state.* reads nil-guarded via spec_kit.safe_state(); Mutilate dagger
--          check present; registration guarded.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.RogueSpells or {}

-- spec_kit migration #22
local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local read_combo_points = require("shared/combo_points_reader_sylvanas")
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    Blind          = define("Blind",          { 2094 }, "Blind"),
    CheapShot      = define("CheapShot",      { 1833 }, "CheapShot"),
    CloakOfShadows = define("CloakOfShadows", { 31224 }, "CloakOfShadows"),
    ColdBlood      = define("ColdBlood",      { 14177 }, "ColdBlood"),
    DeadlyThrow    = define("DeadlyThrow",    { 26679 }, "DeadlyThrow"),
    Envenom        = define("Envenom",        { 32684, 32645 }, "Envenom"),
    Evasion        = define("Evasion",        { 26669, 5277 }, "Evasion"),
    Eviscerate     = define("Eviscerate",     { 26865, 31016, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 }, "Eviscerate"),
    ExposeArmor    = define("ExposeArmor",    { 26866, 11198, 11197, 8650, 8649, 8647 }, "ExposeArmor"),
    Feint          = define("Feint",          { 27448, 25302, 11303, 8637, 6768, 1966 }, "Feint"),
    Garrote        = define("Garrote",        { 26884, 26839, 11290, 11289, 8633, 8632, 8631, 703 }, "Garrote"),
    KidneyShot     = define("KidneyShot",     { 8643, 408 }, "KidneyShot"),
    Mutilate       = define("Mutilate",       { 34413, 34412, 34411, 1329 }, "Mutilate"),
    Rupture        = define("Rupture",        { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }, "Rupture"),
    Shiv            = define("Shiv",            { 5938 }, "Shiv"),
    SinisterStrike  = define("SinisterStrike",  { 26862, 26861, 11294, 11293, 8621, 1760, 1759, 1758, 1757, 1752 }, "SinisterStrike"),
    SliceAndDice   = define("SliceAndDice",   { 6774, 5171 }, "SliceAndDice"),
    Sprint         = define("Sprint",         { 11305, 8696, 2983 }, "Sprint"),
    Stealth        = define("Stealth",        { 1787, 1786, 1785, 1784 }, "Stealth"),
    ThistleTea     = define("ThistleTea",     { 9513 }, "ThistleTea"),
    Vanish         = define("Vanish",         { 26889, 1857, 1856 }, "Vanish"),
}
	local potion_helper = require("shared/potion_helper_sylvanas")
	local leveling_helpers = require("shared/leveling_helpers_sylvanas")
	local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local STEALTH_BUFF     = { 1787, 1786, 1785, 1784 }
local SLICE_DICE_BUFF  = { 6774, 5171 }
local RUPTURE_DEBUFF   = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }
local COLD_BLOOD_BUFF = { 14177 }
local DEADLY_POISON_DEBUFF = { 27187, 27186, 26968, 26967, 25349, 25347, 11354, 11356, 11353, 11355, 2819, 2837, 2818, 2835 }
local CRIPPLING_POISON_DEBUFF = { 3408, 3409, 11201, 11202 }
local WOUND_POISON_DEBUFF   = { 27283, 27189, 13230, 13229, 13228, 13220 }  -- Wound Poison (27189=R4 TBC max rank proc, DB2-vetted)
local DOT_REFRESH_WINDOW = 3
local SND_REFRESH_WINDOW = 3     -- Slice and Dice refresh when < 3s remains
local ENERGY_TICK = 20           -- Energy gained per tick (2s)
local ENERGY_MUTILATE_COST = 60  -- Mutilate base cost
local ENERGY_LOW_BUILDER = 40    -- Pool energy below 40 instead of builder
local ENERGY_LOW_FINISHER = 25   -- Pool energy below 25 instead of finisher

-- ============================================================================
-- Energy Tick Optimization (ported from combat_sylvanas.lua)
-- ============================================================================
local _last_energy = 0
local _last_tick_time = 0

local function get_next_tick_in(energy)
    local now = NS.time_now and NS.time_now() or 0
    local energy_gained = energy - _last_energy
    if energy_gained >= 19 and energy_gained <= 21 then
        _last_tick_time = now
        _last_energy = energy
        return 2.0
    end
    if energy_gained > 0 then
        _last_energy = energy
    end
    local time_since_tick = now - _last_tick_time
    if time_since_tick < 0 or time_since_tick > 4.0 then
        _last_tick_time = now
        return 2.0
    end
    return math.max(0, 2.0 - time_since_tick)
end

local function should_pool_energy(context)
    if not spec_kit.setting_bool(context, "assassin_energy_tick_sync", false) then return false end
    local energy = context.energy or 0
    local offset = spec_kit.setting_number(context, "assassin_energy_tick_offset", 100) / 1000
    local next_tick_in = get_next_tick_in(energy)
    if next_tick_in <= offset + 0.1 then
        local projected_energy = energy + ENERGY_TICK
        if projected_energy <= 100 then
            return true
        end
    end
    return false
end

local function should_spend_energy(context, cost)
    if not spec_kit.setting_bool(context, "assassin_energy_tick_sync", false) then return true end
    local energy = context.energy or 0
    local offset = spec_kit.setting_number(context, "assassin_energy_tick_offset", 100) / 1000
    local next_tick_in = get_next_tick_in(energy)
    local projected_energy = energy + ENERGY_TICK
    if projected_energy > 100 then
        return true
    end
    if next_tick_in > offset + 0.3 then
        return true
    end
    if next_tick_in <= offset then
        return true
    end
    return false
end

-- Dagger set for Mutilate eligibility check
local _dagger_set_ok, dagger_set = pcall(require, "shared/dagger_set_sylvanas")
if not _dagger_set_ok then dagger_set = nil end

-- Healthstone / health potion IDs
local HEALING_ITEM_IDS = { 22829, 22793, 13447, 22105, 22104, 22103, 5512, 5511, 118, 858 }

-- ============================================================================
-- State schema (nil-guard defaults for spec_kit.safe_state)
-- ============================================================================
local ASSN_SCHEMA = {
    stealth_active = false,  slice_dice_active = false,  snd_remains = 0,
    snd_needs_refresh = false,  rupture_remains = 0,  garrote_remains = 0,
    dp_stacks = 0,  dp_remains = 0,  target_poisoned = false,
    combo = 0,  energy = 0,  energy_low = false,  energy_pool_finisher = false,
    hp_pct = 100,  find_weakness_active = false,
    has_cold_blood = false,  healing_item_id = nil,
    has_daggers = false,  shiv_ready = false,  shiv_purge_name = nil,
}

-- ============================================================================
-- State builder (pre-allocated)
-- ============================================================================
local assassin_state = {
    stealth_active = false,
    slice_dice_active = false,
    snd_remains = 0,
    snd_needs_refresh = false,
    rupture_remains = 0,
    dp_stacks = 0,
    dp_remains = 0,
    target_poisoned = false,
    combo = 0,
    energy = 0,
    energy_low = false,
    energy_pool_finisher = false,
    hp_pct = 100,
    has_cold_blood = false,
    healing_item_id = nil,
    has_daggers = false,
    -- Shiv Purge (PvP buff dispel via Wound Poison)
    shiv_ready = false,
    shiv_purge_name = nil,
}

local function build_state(context)
    local target = context.target
    -- Buffs
    assassin_state.stealth_active = NS.has_player_buff(STEALTH_BUFF)
    assassin_state.slice_dice_active = NS.has_player_buff(SLICE_DICE_BUFF)
    -- SnD refresh tracking: re-cast when < 3s remains for 100% uptime
    if assassin_state.slice_dice_active and type(NS.buff_remains) == "function" then
        local r = NS.buff_remains(NS.PLAYER_UNIT, SLICE_DICE_BUFF)
        assassin_state.snd_remains = (r ~= nil and r >= 0) and r or 999
    else
        assassin_state.snd_remains = 0
    end
    assassin_state.snd_needs_refresh = assassin_state.slice_dice_active and assassin_state.snd_remains <= SND_REFRESH_WINDOW
    assassin_state.has_cold_blood = NS.has_player_buff(COLD_BLOOD_BUFF)
    -- Debuffs on target
    if target then
        assassin_state.rupture_remains = NS.debuff_remains and NS.debuff_remains(target, RUPTURE_DEBUFF) or 0
        assassin_state.dp_stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, DEADLY_POISON_DEBUFF) or 0
        assassin_state.dp_remains = NS.debuff_remains and NS.debuff_remains(target, DEADLY_POISON_DEBUFF) or 0
        assassin_state.target_poisoned = assassin_state.dp_stacks > 0
            or (NS.has_target_debuff and NS.has_target_debuff(target, CRIPPLING_POISON_DEBUFF))
            or (NS.has_target_debuff and NS.has_target_debuff(target, WOUND_POISON_DEBUFF))
    else
        assassin_state.rupture_remains = 0
        assassin_state.dp_stacks = 0
        assassin_state.dp_remains = 0
        assassin_state.target_poisoned = false
    end
    -- Resources
    assassin_state.combo = context.combo_points or context.combo or 0
    local me = context.me or (NS.GetPlayer and NS.GetPlayer())
    local combo_points = read_combo_points(me, NS.POWER_COMBO or 4)
    if type(combo_points) == "number" then assassin_state.combo = combo_points end
    assassin_state.energy = context.energy or 0
    -- IZI SDK: energy_predicted for smarter pooling decisions
    if me and type(me.energy_predicted) == "function" then
        local ok, pred = pcall(me.energy_predicted, me)
        assassin_state.energy_predicted = (ok and type(pred) == "number") and pred or assassin_state.energy
    else
        assassin_state.energy_predicted = assassin_state.energy
    end
    assassin_state.energy_low = assassin_state.energy < ENERGY_LOW_BUILDER
    assassin_state.energy_pool_finisher = assassin_state.energy < ENERGY_LOW_FINISHER
    assassin_state.hp_pct = context.hp or 100
    -- Shiv Purge (PvP buff dispel via Wound Poison)
    assassin_state.shiv_ready = target and NS.spell_ready(ACTION.Shiv, target, { expected_cooldown = 10 }) or false
    assassin_state.shiv_purge_name = nil
    if context.in_combat and (context.is_pvp or false) and target and CCGateDB and CCGateDB.find_best_dispel_target then
        local best_id, _, best_name = CCGateDB.find_best_dispel_target(target, NS)
        if best_id then assassin_state.shiv_purge_name = best_name end
    end

    -- Healing item
    assassin_state.healing_item_id = nil
    for _, id in ipairs(HEALING_ITEM_IDS) do
        if NS.is_item_ready and NS.is_item_ready(id) then
            assassin_state.healing_item_id = id
            break
        end
    end
    -- Dagger check: Mutilate requires daggers in BOTH hands (TBC requirement)
    local main_id, off_id
    if NS.get_equipped_item_id and NS.EQUIPMENT_SLOTS then
        main_id = NS.get_equipped_item_id(NS.EQUIPMENT_SLOTS.MAIN_HAND)
        off_id  = NS.get_equipped_item_id(NS.EQUIPMENT_SLOTS.OFF_HAND)
    end
    local is_dagger = dagger_set and dagger_set.is_dagger or {}
    assassin_state.has_daggers = (main_id and main_id ~= 0 and is_dagger[main_id])
        and (off_id and off_id ~= 0 and is_dagger[off_id])
    return spec_kit.safe_state(assassin_state, ASSN_SCHEMA)
end

-- ============================================================================
-- Declarative strategy DSL definitions
-- Replaces 8 imperative strategies with compiled DSL equivalents while preserving
-- the existing priority order via name-based substitution.
-- ============================================================================
local DSL_DEFS = {
    {
        name = "HealthPotion",
        conditions = {
            { type = "in_combat" },
            { type = "setting", key = "use_auto_potions", op = "truthy", default = true },
            { type = "context", field = "has_health_potion", op = "truthy" },
            { type = "hp_threshold", op = "<=", value = 35 },
        },
        action = { type = "custom", fn = function(context)
            return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS)
        end },
    },
    {
        name = "DamagePotion",
        conditions = {
            { type = "in_combat" },
            { type = "setting", key = "use_auto_potions", op = "truthy", default = true },
            { type = "context", field = "has_damage_potion", op = "truthy" },
            { type = "context", field = "should_burst", op = "truthy" },
        },
        action = { type = "custom", fn = function(context)
            return potion_helper.try_use_potion(context, potion_helper.DAMAGE_POTION_IDS)
        end },
    },
    {
        name = "EvasionDefense",
        conditions = {
            { type = "custom", fn = function(context, state)
                local hp = spec_kit.setting_number(context, "assassin_evasion_hp", 25)
                return (state.hp_pct or 100) <= hp
            end },
            { type = "spell_ready", spell = ACTION.Evasion, target = "self" },
        },
        action = { type = "cast", spell = ACTION.Evasion, target = "self" },
    },
    {
        name = "CloakOfShadows",
        conditions = {
            { type = "custom", fn = function(context, state)
                local hp = spec_kit.setting_number(context, "assassin_clos_hp", 30)
                return (state.hp_pct or 100) <= hp
            end },
            { type = "spell_ready", spell = ACTION.CloakOfShadows, target = "self" },
        },
        action = { type = "cast", spell = ACTION.CloakOfShadows, target = "self" },
    },
    {
        name = "HealingItem",
        conditions = {
            { type = "state", field = "hp_pct", op = "<=", value = 35 },
            { type = "custom", fn = function(context, state) return state.healing_item_id ~= nil end },
        },
        action = { type = "custom", fn = function(context, state)
            if NS.use_item_by_id then NS.use_item_by_id(state.healing_item_id) end
            return true
        end },
    },
    {
        name = "VanishReopen",
        conditions = {
            { type = "in_combat" },
            { type = "context", field = "threat_pct", op = ">=", value = 90 },
            { type = "spell_ready", spell = ACTION.Vanish, target = "self" },
        },
        action = { type = "cast", spell = ACTION.Vanish, target = "self" },
    },
    {
        name = "AssassinationShivPurge",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not spec_kit.setting_bool(context, "use_shiv_purge", true) then return false end
                if not (NS.is_spell_learned and NS.is_spell_learned(5938)) then return false end
                if not context.in_combat then return false end
                if not (context.is_pvp or false) then return false end
                if not context.target then return false end
                if not (context.in_melee_range or false) then return false end
                if not state.shiv_ready then return false end
                if not state.shiv_purge_name then return false end
                if spec_kit.setting_bool(context, "shiv_purge_pvp_only", true) then
                    local ok, is_player = pcall(function() return context.target:is_player() end)
                    if not (ok and is_player) then return false end
                end
                context._shiv_purge_name = state.shiv_purge_name
                return true
            end },
        },
        action = { type = "custom", fn = function(context)
            local name = context._shiv_purge_name or "buff"
            return NS.try_cast(ACTION.Shiv, context.target, "[ASSASS] Shiv purge → " .. name, { expected_cooldown = 10 })
        end },
    },
    {
        name = "LevelingSinisterStrike",
        conditions = {
            { type = "custom", fn = function(context, state)
                local target = context.target
                if not target then return false end
                if (state.energy or 0) < 45 then return false end
                local level = leveling_helpers.level_from_context(context, 70)
                local mutilate_known = NS.spell_exists and NS.spell_exists(ACTION.Mutilate)
                if not leveling_helpers.is_low_level(level) and not context.is_leveling then
                    if mutilate_known and state.has_daggers then return false end
                end
                return NS.spell_ready(ACTION.SinisterStrike, target)
            end },
        },
        action = { type = "cast", spell = ACTION.SinisterStrike, target = "target", label = "[ASSASS] Sinister Strike leveling" },
    },
}

-- ============================================================================
-- Strategies (priority order: survival → cooldowns → finishers → builders → PvP)
-- ============================================================================
local strategies = {

    { name = "HealthPotion" },
    { name = "DamagePotion" },
    { name = "EvasionDefense" },
    { name = "CloakOfShadows" },
    { name = "HealingItem" },
    { name = "VanishReopen" },

    -- ------------------------------------------------------------------------
    -- PvP: Shiv Purge — dispel 1 magic buff via Wound Poison (BoP, PW:S, etc.)
    -- Ported from middleware/combat/subtlety ShivPurge pattern.
    -- ------------------------------------------------------------------------
    { name = "AssassinationShivPurge" },

    -- ------------------------------------------------------------------------
    -- 6. Slice and Dice (100% uptime, refresh when < 3s remains)
    -- Research: "Must maintain Slice and Dice at 100% uptime; re-cast when < 3s remains."
    -- PRIORITY: SnD is the FIRST finisher — never let Envenom/Rupture fire before it.
    -- ------------------------------------------------------------------------
    {
        name = "SliceAndDice",
        matches = function(context, state)
            -- Refresh when about to drop (< 3s) even if active
            if state.slice_dice_active and not state.snd_needs_refresh then return false end
            if (state.combo or 0) < 2 then return false end
            return NS.spell_ready(ACTION.SliceAndDice, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(context, state)
            local tag = state.slice_dice_active
                and string.format("[ASSASS] Slice and Dice refresh (%.1fs)", state.snd_remains)
                or "[ASSASS] Slice and Dice"
            return NS.try_cast(ACTION.SliceAndDice, NS.PLAYER_UNIT, tag, { skip_range = true })
        end,
    },

    -- ------------------------------------------------------------------------
    -- 7. Cold Blood + Envenom (burst finisher)
    -- ------------------------------------------------------------------------
    {
        name = "ColdBloodEnvenom",
        matches = function(context, state)
            if not spec_kit.setting_bool(context, "assassin_cold_blood_auto", false) then return false end
            if state.energy_pool_finisher then return false end  -- pool energy below 25
            if not state.slice_dice_active or state.snd_needs_refresh then return false end
            if (state.combo or 0) < 5 then return false end
            local min_stacks = spec_kit.setting_number(context, "assassin_envenom_stacks", 3)
            if (state.dp_stacks or 0) < min_stacks then return false end
            if state.has_cold_blood then return false end  -- already active
            -- Cold Blood first (off-GCD, use SPELLS table)
            if not NS.spell_ready(ACTION.ColdBlood, NS.PLAYER_UNIT, { skip_range = true }) then return false end
            return NS.spell_ready(ACTION.Envenom, context.target)
        end,
        execute = function(context)
            if NS.try_cast(ACTION.ColdBlood, NS.PLAYER_UNIT, "[ASSASS] Cold Blood pre-Envenom", { skip_range = true }) then
                return true  -- cast CB this GCD, Envenom next
            end
            return false
        end,
    },

    -- ------------------------------------------------------------------------
    -- 8. Rupture (bleed finisher — only on long-lived targets)
    -- Research: "Use only when TTD > 12s."
    -- ------------------------------------------------------------------------
    {
        name = "RuptureBleed",
        matches = function(context, state)
            if state.energy_pool_finisher then return false end  -- pool energy below 25
            if (state.combo or 0) < 4 then return false end
            if (state.rupture_remains or 0) > DOT_REFRESH_WINDOW then return false end
            -- Bleed-immune targets can't be ruptured
            if (context.target_bleed_immune or false) then return false end  -- nil-safe: skip rupture if immune
            -- Only on long-lived targets (TTD > 12s)
            local ttd = context.ttd or 0
            if context.ttd_known and ttd > 0 and ttd < 12 then return false end
            return NS.spell_ready(ACTION.Rupture, context.target)
        end,
        execute = function(context)
            return NS.try_cast(ACTION.Rupture, context.target, "[ASSASS] Rupture")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 9. Envenom (finisher — DP stacks consumed, after Rupture is up)
    -- ------------------------------------------------------------------------
    {
        name = "EnvenomFinisher",
        matches = function(context, state)
            if state.energy_pool_finisher then return false end
            if not state.slice_dice_active or state.snd_needs_refresh then return false end
            if (state.combo or 0) < 4 then return false end
            local min_stacks = spec_kit.setting_number(context, "assassin_envenom_stacks", 3)
            if (state.dp_stacks or 0) < min_stacks then return false end
            return NS.spell_ready(ACTION.Envenom, context.target)
        end,
        execute = function(context)
            return NS.try_cast(ACTION.Envenom, context.target,
                string.format("[ASSASS] Envenom at %d CP / %d DP stacks", context.combo_points or context.combo or 0, assassin_state.dp_stacks or 0))
        end,
    },
    -- ------------------------------------------------------------------------
    {
        name = "KidneyShotCC",
        matches = function(context, state)
            if (state.combo or 0) < 3 then return false end
            local group_aware = spec_kit.setting_bool(context, "rogue_group_aware_utility", true)
            if not (context.is_pvp or (group_aware and context.is_group)) then return false end
            -- Don't DR stun if already stunned recently
            if (context.target_dr_stun or false) then return false end
            return NS.spell_ready(ACTION.KidneyShot, context.target)
        end,
        execute = function(context)
            return NS.try_cast(ACTION.KidneyShot, context.target, "[ASSASS PvP] Kidney Shot")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 11. Thistle Tea (energy burst)
    -- ------------------------------------------------------------------------
    {
        name = "ThistleTea",
        matches = function(context, state)
            if not spec_kit.setting_bool(context, "assassin_thistle_tea", false) then return false end
            if (state.energy or 100) > 40 then return false end  -- don't waste
            if (state.combo or 0) > 3 then return false end  -- better to pool for finisher
            return NS.spell_ready(ACTION.ThistleTea, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(ACTION.ThistleTea, NS.PLAYER_UNIT, "[ASSASS] Thistle Tea", { skip_range = true })
        end,
    },

    -- ------------------------------------------------------------------------
    -- 12. Shiv (Deadly Poison refresh — energy-gated)
    -- ------------------------------------------------------------------------
    {
        name = "ShivRefresh",
        matches = function(context, state)
            local target = context.target
            if not target then return false end
            if state.energy_low then return false end  -- pool energy instead
            -- Only Shiv if DP is about to drop and we care about stacks
            if (state.dp_remains or 0) > 3 then return false end
            if (state.dp_stacks or 0) >= 5 then return false end  -- already max
            return NS.spell_ready(ACTION.Shiv, target, { expected_cooldown = 10 })
        end,
        execute = function(context)
            return NS.try_cast(ACTION.Shiv, context.target, "[ASSASS] Shiv (DP refresh)", { expected_cooldown = 10 })
        end,
    },

    -- ------------------------------------------------------------------------
    -- 13. Mutilate (primary CP builder — requires poison + behind target)
    -- Research: "+50% damage against poisoned targets, behind-target requirement."
    -- Energy gate: pool below 40 energy (Research floor).
    -- ------------------------------------------------------------------------
    { name = "LevelingSinisterStrike" },
    {
        name = "Mutilate",
        matches = function(context, state)
            if state.energy_low then return false end
            if not state.has_daggers then return false end
            if not should_spend_energy(context, ENERGY_MUTILATE_COST) then return false end
            return NS.spell_ready(ACTION.Mutilate, context.target)
        end,
        execute = function(context, state)
            local tag = state.target_poisoned
                and "[ASSASS] Mutilate (poisoned)"
                or "[ASSASS] Mutilate"
            return NS.try_cast(ACTION.Mutilate, context.target, tag)
        end,
    },

    -- ------------------------------------------------------------------------
    -- 13b. Sinister Strike (fallback when Mutilate isn't usable)
    -- Triggers when: poison-immune target or target unpoisoned
    -- ------------------------------------------------------------------------
	    {
	        name = "SinisterStrikeFallback",
	        matches = function(context, state)
	            local level = leveling_helpers.level_from_context(context, 70)
	            -- Low-level / leveling uses LevelingSinisterStrike
	            if leveling_helpers.is_low_level(level) or context.is_leveling then return false end
	            local mutilate_known = NS.spell_exists and NS.spell_exists(ACTION.Mutilate)
	            -- Fallback when Mutilate can't be used: not known, or no daggers
	            if mutilate_known and state.has_daggers then return false end
	            if state.energy_low then return false end
	            if not should_spend_energy(context, 45) then return false end
	            return NS.spell_ready(ACTION.SinisterStrike, context.target)
	        end,
	        execute = function(context)
	            return NS.try_cast(ACTION.SinisterStrike, context.target, "[ASSASS] Sinister Strike (Mutilate fallback)")
	        end,
	    },

    -- ------------------------------------------------------------------------
    -- 14. Eviscerate (fallback finisher)
    -- ------------------------------------------------------------------------
	    {
	        name = "EviscerateFallback",
	        matches = function(context, state)
	            if state.energy_pool_finisher then return false end  -- pool energy below 25
	            -- Low-level: dump at 4 CP (Envenom/Mutilate not available; short fights)
	            local min_cp = 5
	            local level = leveling_helpers.level_from_context(context, 70)
	            if leveling_helpers.is_low_level(level) or context.is_leveling then min_cp = 4 end
	            if (state.combo or 0) < min_cp then return false end
	            -- Only eviscerate if we can't Envenom or Rupture
	            return NS.spell_ready(ACTION.Eviscerate, context.target)
	        end,
        execute = function(context)
            return NS.try_cast(ACTION.Eviscerate, context.target, "[ASSASS] Eviscerate")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 15. Expose Armor (if no warrior)
    -- ------------------------------------------------------------------------
    {
        name = "ExposeArmor",
        matches = function(context, state)
            local target = context.target
            if not target then return false end
            if (state.combo or 0) < 3 then return false end
            -- Skip if target has no armor (API unavailable or already fully reduced)
            if (context.target_armor or 0) <= 0 then return false end
            if (context.has_sunder or false) then return false end
            return NS.spell_ready(ACTION.ExposeArmor, target)
        end,
        execute = function(context)
            return NS.try_cast(ACTION.ExposeArmor, context.target, "[ASSASS] Expose Armor")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 16. Deadly Throw (ranged finisher)
    -- ------------------------------------------------------------------------
    {
        name = "DeadlyThrow",
        matches = function(context, state)
            if (state.combo or 0) < 3 then return false end
            -- Use when target is fleeing or at range
            return NS.spell_ready(ACTION.DeadlyThrow, context.target)
        end,
        execute = function(context)
            return NS.try_cast(ACTION.DeadlyThrow, context.target, "[ASSASS] Deadly Throw")
        end,
    },

    -- ------------------------------------------------------------------------
    -- PvP Section
    -- ------------------------------------------------------------------------
    {
        name = "BlindCC",
        matches = function(context)
            local group_aware = spec_kit.setting_bool(context, "rogue_group_aware_utility", true)
            if not (context.is_pvp or (group_aware and context.is_group)) then return false end
            if not context.target then return false end
            -- IZI SDK: skip Blind if target is already CC'd
            local target = context.target
            if target and type(target.is_cc) == "function" then
                local ok, cc = pcall(target.is_cc, target)
                if ok and cc then return false end
            end
            return NS.spell_ready(ACTION.Blind, context.target)
        end,
        execute = function(context)
            return NS.try_cast(ACTION.Blind, context.target, "[ASSASS] Blind")
        end,
    },
    {
        name = "PvP_SprintGapClose",
        matches = function(context)
            if not context.is_pvp then return false end
            if context.target_distance and context.target_distance < 15 then return false end
            return NS.spell_ready(ACTION.Sprint, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(ACTION.Sprint, NS.PLAYER_UNIT, "[ASSASS PvP] Sprint gap close", { skip_range = true })
        end,
    },
    {
        name = "PvP_CheapShotOpen",
        matches = function(context, state)
            if not state.stealth_active then return false end
            if not context.is_pvp then return false end
            return NS.spell_ready(ACTION.CheapShot, context.target)
        end,
        execute = function(context)
            return NS.try_cast(ACTION.CheapShot, context.target, "[ASSASS PvP] Cheap Shot opener")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 20. Stealth (out of combat)
    -- ------------------------------------------------------------------------
    {
        name = "Stealth",
        matches = function(context, state)
            if context.in_combat then return false end
            if state.stealth_active then return false end
            return NS.spell_ready(ACTION.Stealth, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(ACTION.Stealth, NS.PLAYER_UNIT, "[ASSASS] Stealth", { skip_range = true })
        end,
    },

    -- ------------------------------------------------------------------------
    -- 21. Garrote opener (from stealth)
    -- ------------------------------------------------------------------------
    {
        name = "GarroteOpen",
        requires_buff = { 1787, 1786, 1785, 1784 },
        requires_behind = true,
        matches = function(context, state)
            if not state.stealth_active then return false end
            if context.is_pvp then return false end  -- CheapShot better in PvP
            if NS.is_behind_target and not NS.is_behind_target(context.target) then return false end
            return NS.spell_ready(ACTION.Garrote, context.target)
        end,
        execute = function(context)
            return NS.try_cast(ACTION.Garrote, context.target, "[ASSASS] Garrote opener")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 22. Feint (AoE damage reduction / threat drop)
    -- ------------------------------------------------------------------------
    {
        name = "FeintAoE",
        matches = function(context, state)
            -- Threat drop: cast when threat is high regardless of HP/AoE
            if (context.threat_pct or 0) > 90 then
                return NS.spell_ready(ACTION.Feint, NS.PLAYER_UNIT, { skip_range = true })
            end
            -- AoE damage reduction: cast when taking AoE damage and HP low
            if (state.hp_pct or 100) > 60 then return false end
            if not context.aoe_damage_incoming then return false end
            return NS.spell_ready(ACTION.Feint, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(ACTION.Feint, NS.PLAYER_UNIT, "[ASSASS] Feint", { skip_range = true })
        end,
    },
}

-- Replace the 6 imperative strategies with compiled DSL equivalents by name.
-- Name-based substitution keeps the priority order intact even when strategies
-- are inserted or reordered in the future.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("assassination", strategies, { get_state = build_state })
end
if NS.log then NS.log("Rogue assassination rotation registered") end
return { strategies = strategies, build_state = build_state }
