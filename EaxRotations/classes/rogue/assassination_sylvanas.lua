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
local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local STEALTH_BUFF     = { 1787, 1786, 1785, 1784 }
local SLICE_DICE_BUFF  = { 6774, 5171 }
local FIND_WEAKNESS_BUFF = { 31235, 31234, 31233 }  -- debuff on target after finisher
local RUPTURE_DEBUFF   = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }
local GARROTE_DEBUFF   = { 26884, 26839, 11290, 11289, 8633, 8632, 8631, 703 }
local COLD_BLOOD_BUFF = { 14177 }
local DEADLY_POISON_DEBUFF = { 27187, 27186, 26968, 26967, 25349, 25347, 11354, 11356, 11353, 11355, 2819, 2837, 2818, 2835 }
local CRIPPLING_POISON_DEBUFF = { 3408, 3409, 11201, 11202 }
local WOUND_POISON_DEBUFF   = { 27283, 27189, 13230, 13229, 13228, 13220 }  -- Wound Poison (27189=R4 TBC max rank proc, DB2-vetted)
local DOT_REFRESH_WINDOW = 3
local SND_REFRESH_WINDOW = 3     -- Slice and Dice refresh when < 3s remains
local ENERGY_TICK = 20           -- Energy gained per tick (2s)
local ENERGY_MUTILATE_COST = 60  -- Mutilate base cost
local ENERGY_FINISHER_COST = 35  -- Envenom/Eviscerate cost
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
    garrote_remains = 0,
    dp_stacks = 0,
    dp_remains = 0,
    target_poisoned = false,
    combo = 0,
    energy = 0,
    energy_low = false,
    energy_pool_finisher = false,
    hp_pct = 100,
    find_weakness_active = false,
    has_cold_blood = false,
    healing_item_id = nil,
    has_daggers = false,
    -- Shiv Purge (PvP buff dispel via Wound Poison)
    shiv_ready = false,
    shiv_purge_name = nil,
}

local function build_state(context)
    local target = context.target
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(1787, 3.0) or false
    if not skip_aura then
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
            assassin_state.garrote_remains = NS.debuff_remains and NS.debuff_remains(target, GARROTE_DEBUFF) or 0
            assassin_state.dp_stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, DEADLY_POISON_DEBUFF) or 0
            assassin_state.dp_remains = NS.debuff_remains and NS.debuff_remains(target, DEADLY_POISON_DEBUFF) or 0
            assassin_state.target_poisoned = assassin_state.dp_stacks > 0
                or (NS.has_target_debuff and NS.has_target_debuff(target, CRIPPLING_POISON_DEBUFF))
                or (NS.has_target_debuff and NS.has_target_debuff(target, WOUND_POISON_DEBUFF))
            assassin_state.find_weakness_active = NS.has_target_debuff and NS.has_target_debuff(target, FIND_WEAKNESS_BUFF)
        else
            assassin_state.rupture_remains = 0
            assassin_state.garrote_remains = 0
            assassin_state.dp_stacks = 0
            assassin_state.dp_remains = 0
            assassin_state.target_poisoned = false
            assassin_state.find_weakness_active = false
        end
    else
        assassin_state.stealth_active = false
        assassin_state.slice_dice_active = false
        assassin_state.snd_remains = 0
        assassin_state.snd_needs_refresh = false
        assassin_state.has_cold_blood = false
        assassin_state.rupture_remains = 0
        assassin_state.garrote_remains = 0
        assassin_state.dp_stacks = 0
        assassin_state.dp_remains = 0
        assassin_state.target_poisoned = false
        assassin_state.find_weakness_active = false
    end
    -- Resources
    assassin_state.combo = context.combo_points or context.combo or 0
    assassin_state.energy = context.energy or 0
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

local function shiv_purge_matches(context, state)
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
    return true
end

local function assassination_leveling_builder_matches(context, state)
    local target = context.target
    if not target then return false end
    if (state.energy or 0) < 45 then return false end
    local level = context.player_level or 70
    if not context.is_leveling and level >= 50 then return false end
    if level >= 50 and NS.spell_exists and NS.spell_exists(ACTION.Mutilate) then return false end
    return NS.spell_ready(ACTION.SinisterStrike, target)
end

-- ============================================================================
-- Strategies (priority order: survival → cooldowns → finishers → builders → PvP)
-- ============================================================================
local strategies = {

    -- ------------------------------------------------------------------------
    -- 1a. Health Potion (context-based O(1) gate)
    -- ------------------------------------------------------------------------
    {
        name = "HealthPotion",
        matches = function(context)
            if not context.in_combat then return false end
            if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
            if not context.has_health_potion then return false end
            if (context.hp or 100) > 35 then return false end
            return true
        end,
        execute = function(context) return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS) end,
    },

    -- ------------------------------------------------------------------------
    -- 1b. Damage Potion (context-based O(1) gate, burst-only)
    -- ------------------------------------------------------------------------
    {
        name = "DamagePotion",
        matches = function(context)
            if not context.in_combat then return false end
            if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
            if not context.has_damage_potion then return false end
            if not context.should_burst then return false end
            return true
        end,
        execute = function(context) return potion_helper.try_use_potion(context, potion_helper.DAMAGE_POTION_IDS) end,
    },

    -- ------------------------------------------------------------------------
    -- 1. Evasion (oh-shit)
    -- ------------------------------------------------------------------------
    {
        name = "EvasionDefense",
        matches = function(context)
            local hp = spec_kit.setting_number(context, "assassin_evasion_hp", 25)
            if (context.hp or 100) > hp then return false end
            return NS.spell_ready(ACTION.Evasion, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast(ACTION.Evasion, NS.PLAYER_UNIT, "[ASSASS] Evasion defense", { skip_range = true })
        end,
    },

    -- ------------------------------------------------------------------------
    -- 2. Cloak of Shadows (magic oh-shit)
    -- ------------------------------------------------------------------------
    {
        name = "CloakOfShadows",
        matches = function(context)
            local hp = spec_kit.setting_number(context, "assassin_clos_hp", 30)
            if (context.hp or 100) > hp then return false end
            return NS.spell_ready(ACTION.CloakOfShadows, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast(ACTION.CloakOfShadows, NS.PLAYER_UNIT, "[ASSASS] Cloak of Shadows", { skip_range = true })
        end,
    },

    -- ------------------------------------------------------------------------
    -- 3. Healing Item
    -- ------------------------------------------------------------------------
    {
        name = "HealingItem",
        matches = function(_, state)
            if (state.hp_pct or 100) > 35 then return false end
            return state.healing_item_id ~= nil
        end,
        execute = function(_, state)
            if NS.use_item_by_id then NS.use_item_by_id(state.healing_item_id) end
            return true
        end,
    },

    -- ------------------------------------------------------------------------
    -- 4. Vanish (threat drop / reopen)
    -- ------------------------------------------------------------------------
    {
        name = "VanishReopen",
        matches = function(context)
            if not context.in_combat then return false end
            if (context.threat_pct or 0) < 90 then return false end
            return NS.spell_ready(ACTION.Vanish, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast(ACTION.Vanish, NS.PLAYER_UNIT, "[ASSASS] Vanish (threat/reopen)")
        end,
    },

    -- ------------------------------------------------------------------------
    -- PvP: Shiv Purge — dispel 1 magic buff via Wound Poison (BoP, PW:S, etc.)
    -- Ported from middleware/combat/subtlety ShivPurge pattern.
    -- ------------------------------------------------------------------------
    {
        name = "AssassinationShivPurge",
        matches = function(context, state) if shiv_purge_matches(context, state) then context._shiv_purge_name = state.shiv_purge_name return true end return false end,
        execute = function(context)
            local name = context._shiv_purge_name or "buff"
            return NS.try_cast(ACTION.Shiv, context.target, "[ASSASS] Shiv purge → " .. name, { expected_cooldown = 10 })
        end,
    },

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
            if context.ttd_known and context.ttd > 0 and context.ttd < 12 then return false end
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
            if not (context.is_pvp or context.is_group) then return false end
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
    {
        name = "LevelingSinisterStrike",
        matches = assassination_leveling_builder_matches,
        execute = function(context)
            return NS.try_cast(ACTION.SinisterStrike, context.target, "[ASSASS] Sinister Strike leveling")
        end,
    },
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
            local level = context.player_level or 70
            if level < 50 or not (NS.spell_exists and NS.spell_exists(ACTION.Mutilate)) then return false end
            -- Fallback when Mutilate can't be used: no daggers equipped
            if state.has_daggers then return false end
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
            if (state.combo or 0) < 5 then return false end
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
            if not (context.is_pvp or context.is_group) then return false end
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

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("assassination", strategies, { get_state = build_state })
end
if NS.log then NS.log("Rogue assassination rotation registered") end
return { strategies = strategies, build_state = build_state }
