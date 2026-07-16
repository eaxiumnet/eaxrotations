-- assassination_vanilla.lua — Rogue Assassination for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  dagger DPS (Backstab, Ambush, Seal Fate, Slice and Dice).
-- WHEN:  combat, with daggers, when NS.is_vanilla() is true.
-- WHY:   Vanilla Assassination uses Backstab/Ambush; Seal Fate is the 31pt talent.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

local NS = _G.EaxRotations
if not NS then return nil end
local potion_helper = require("shared/potion_helper_sylvanas")
local SPELLS = NS.RogueSpells or {}
local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local STEALTH_BUFF     = { 1787, 1786, 1785, 1784 }
local SLICE_DICE_BUFF  = { 6774, 5171 }
local FIND_WEAKNESS_BUFF = { }  -- debuff on target after finisher
local RUPTURE_DEBUFF   = { 11275, 11274, 11273, 8640, 8639, 1943 }
local GARROTE_DEBUFF   = { 11290, 11289, 8633, 8632, 8631, 703 }
local COLD_BLOOD_BUFF = { 14177 }
local DEADLY_POISON_DEBUFF = { 25349, 25347, 11354, 11356, 11353, 11355, 2819, 2837, 2818, 2835 }
local CRIPPLING_POISON_DEBUFF = { 3408, 3409, 11201, 11202 }
local WOUND_POISON_DEBUFF   = { 13230, 13229, 13228, 13220 }  -- Wound Poison (healing reduction, DB2-vetted)
local DOT_REFRESH_WINDOW = 3
local SND_REFRESH_WINDOW = 3     -- Slice and Dice refresh when < 3s remains
local ENERGY_TICK = 20           -- Energy gained per tick (2s)
local ENERGY_BACKSTAB_COST = 60  -- Backstab base cost
local ENERGY_EVISCERATE_COST = 35  -- Eviscerate cost
local ENERGY_LOW_BUILDER = 40    -- Pool energy below 40 instead of builder
local ENERGY_LOW_FINISHER = 25   -- Pool energy below 25 instead of finisher



-- Healthstone / health potion IDs
local HEALING_ITEM_IDS = { 22829, 22793, 13447, 22105, 22104, 22103, 5512, 5511, 118, 858 }

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
        assassin_state.find_weakness_active = false
    end
    -- Resources
    assassin_state.combo = context.combo or 0
    assassin_state.energy = context.energy or 0
    assassin_state.energy_low = assassin_state.energy < ENERGY_LOW_BUILDER
    assassin_state.energy_pool_finisher = assassin_state.energy < ENERGY_LOW_FINISHER
    assassin_state.hp_pct = context.hp or 100

    -- Healing item
    assassin_state.healing_item_id = nil
    for _, id in ipairs(HEALING_ITEM_IDS) do
        if NS.is_item_ready and NS.is_item_ready(id) then
            assassin_state.healing_item_id = id
            break
        end
    end
    return assassin_state
end

local function assassination_leveling_builder_matches(context, state)
    local target = context.target
    if not target then return false end
    if (state.energy or 0) < 45 then return false end
    local level = context.level or context.player_level or 60
    if not context.is_leveling and level >= 50 then return false end
    return NS.spell_ready(SPELLS.SinisterStrike, target)
end

-- ============================================================================
-- Strategies (priority order: survival ? cooldowns ? finishers ? builders ? PvP)
-- ============================================================================
local strategies = {
    { name = "HealthPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_health_potion then return false end
          if (context.hp or 100) > 35 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS) end },
    { name = "DamagePotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_damage_potion then return false end
          if not context.should_burst then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.DAMAGE_POTION_IDS) end },

    -- ------------------------------------------------------------------------
    -- 1. Evasion (oh-shit)
    -- ------------------------------------------------------------------------
    {
        name = "EvasionDefense",
        matches = function(context)
            local hp = context.settings and context.settings.assassin_evasion_hp or 25
            if (context.hp or 100) > hp then return false end
            return NS.spell_ready(SPELLS.Evasion, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Evasion, NS.PLAYER_UNIT, "[ASSASS] Evasion defense")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 2. Healing Item
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
            if context.threat_pct and context.threat_pct < 90 then return false end
            return NS.spell_ready(SPELLS.Vanish, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Vanish, NS.PLAYER_UNIT, "[ASSASS] Vanish (threat/reopen)")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 5. Kick (interrupt priority)
    -- ------------------------------------------------------------------------
    {
        name = "KickInterrupt",
        matches = function(context)
            local target = context.target
            if not target then return false end
            if not target:is_casting() then return false end
            return NS.spell_ready(SPELLS.Kick, target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Kick, context.target, "[ASSASS] Kick interrupt")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 6. Cold Blood + Eviscerate (burst finisher)
    -- ------------------------------------------------------------------------
    {
        name = "ColdBloodEviscerate",
        matches = function(context, state)
            if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
            if not (context.settings and context.settings.assassin_cold_blood_auto) then return false end
            if state.energy_pool_finisher then return false end  -- pool energy below 25
            if (state.combo or 0) < 5 then return false end
            if state.has_cold_blood then return false end  -- already active
            -- Cold Blood first (off-GCD, use SPELLS table)
            if not NS.spell_ready(SPELLS.ColdBlood, NS.PLAYER_UNIT, { skip_range = true }) then return false end
            return NS.spell_ready(SPELLS.Eviscerate, context.target)
        end,
        execute = function(context)
            if NS.try_cast(SPELLS.ColdBlood, NS.PLAYER_UNIT, "[ASSASS] Cold Blood pre-Eviscerate") then
                return true  -- cast CB this GCD, Eviscerate next
            end
            return false
        end,
    },

    -- ------------------------------------------------------------------------
    -- 7. Eviscerate (primary finisher)
    -- ------------------------------------------------------------------------
    -- ------------------------------------------------------------------------
    -- 8. Slice and Dice (100% uptime, refresh when < 3s remains)
    -- Research: "Must maintain Slice and Dice at 100% uptime; re-cast when < 3s remains."
    -- ------------------------------------------------------------------------
    {
        name = "SliceAndDice",
        matches = function(context, state)
            -- Refresh when about to drop (< 3s) even if active
            if state.slice_dice_active and not state.snd_needs_refresh then return false end
            if (state.combo or 0) < 2 then return false end
            return NS.spell_ready(SPELLS.SliceAndDice, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(context, state)
            local tag = state.slice_dice_active
                and string.format("[ASSASS] Slice and Dice refresh (%.1fs)", state.snd_remains)
                or "[ASSASS] Slice and Dice"
            return NS.try_cast(SPELLS.SliceAndDice, NS.PLAYER_UNIT, tag)
        end,
    },

    -- ------------------------------------------------------------------------
    -- 9. Rupture (bleed finisher ? only on long-lived targets)
    -- Research: "Use only when TTD > 12s."
    -- ------------------------------------------------------------------------
    {
        name = "RuptureBleed",
        matches = function(context, state)
            if state.energy_pool_finisher then return false end  -- pool energy below 25
            if (state.combo or 0) < 4 then return false end
            if (state.rupture_remains or 0) > DOT_REFRESH_WINDOW then return false end
            -- Bleed-immune targets can't be ruptured
            if context.target_bleed_immune then return false end
            -- Only on long-lived targets (TTD > 12s)
            if context.ttd and context.ttd > 0 and context.ttd < 12 then return false end
            return NS.spell_ready(SPELLS.Rupture, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Rupture, context.target, "[ASSASS] Rupture")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 10. Kidney Shot (CC / interrupt)
    -- ------------------------------------------------------------------------
    {
        name = "KidneyShotCC",
        matches = function(context, state)
            if (state.combo or 0) < 3 then return false end
            if not context.is_pvp then return false end
            -- Don't DR stun if already stunned recently
            if context.target_dr_stun and context.target_dr_stun > 0 then return false end
            return NS.spell_ready(SPELLS.KidneyShot, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.KidneyShot, context.target, "[ASSASS PvP] Kidney Shot")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 11. Thistle Tea (energy burst)
    -- ------------------------------------------------------------------------
    {
        name = "ThistleTea",
        matches = function(context, state)
            if not (context.settings and context.settings.assassin_thistle_tea) then return false end
            if (state.energy or 0) > 40 then return false end  -- don't waste
            if (state.combo or 0) > 3 then return false end  -- better to pool for finisher
            return NS.spell_ready(SPELLS.ThistleTea, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.ThistleTea, NS.PLAYER_UNIT, "[ASSASS] Thistle Tea")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 12. Sinister Strike (primary CP builder)
    -- ------------------------------------------------------------------------
    {
        name = "LevelingSinisterStrike",
        matches = assassination_leveling_builder_matches,
        execute = function(context)
            return NS.try_cast(SPELLS.SinisterStrike, context.target, "[ASSASS] Sinister Strike leveling")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 13. Eviscerate (fallback finisher)
    -- ------------------------------------------------------------------------
    {
        name = "EviscerateFallback",
        matches = function(context, state)
            if state.energy_pool_finisher then return false end  -- pool energy below 25
            if (state.combo or 0) < 5 then return false end
            -- Primary finisher when Rupture isn't optimal
            return NS.spell_ready(SPELLS.Eviscerate, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Eviscerate, context.target, "[ASSASS] Eviscerate")
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
            if context.has_sunder then return false end
            return NS.spell_ready(SPELLS.ExposeArmor, target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.ExposeArmor, context.target, "[ASSASS] Expose Armor")
        end,
    },

    -- ------------------------------------------------------------------------
    -- PvP Section
    -- ------------------------------------------------------------------------
    {
        name = "PvP_Blind",
        matches = function(context)
            if not context.is_pvp then return false end
            return NS.spell_ready(SPELLS.Blind, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Blind, context.target, "[ASSASS PvP] Blind")
        end,
    },
    {
        name = "PvP_SprintGapClose",
        matches = function(context)
            if not context.is_pvp then return false end
            if context.dist_to_target and context.dist_to_target < 15 then return false end
            return NS.spell_ready(SPELLS.Sprint, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.Sprint, NS.PLAYER_UNIT, "[ASSASS PvP] Sprint gap close")
        end,
    },
    {
        name = "PvP_CheapShotOpen",
        matches = function(context, state)
            if not state.stealth_active then return false end
            if not context.is_pvp then return false end
            return NS.spell_ready(SPELLS.CheapShot, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.CheapShot, context.target, "[ASSASS PvP] Cheap Shot opener")
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
            return NS.spell_ready(SPELLS.Stealth, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.Stealth, NS.PLAYER_UNIT, "[ASSASS] Stealth")
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
            return NS.spell_ready(SPELLS.Garrote, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Garrote, context.target, "[ASSASS] Garrote opener")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 22. Feint (AoE damage reduction / threat drop)
    -- ------------------------------------------------------------------------
    {
        name = "FeintAoE",
        matches = function(context, state)
            -- Threat drop: cast when threat is high regardless of HP/AoE
            if context.threat_pct and context.threat_pct > 90 then
                return NS.spell_ready(SPELLS.Feint, NS.PLAYER_UNIT, { skip_range = true })
            end
            -- AoE damage reduction: cast when taking AoE damage and HP low
            if (state.hp_pct or 100) > 60 then return false end
            if not context.aoe_damage_incoming then return false end
            return NS.spell_ready(SPELLS.Feint, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.Feint, NS.PLAYER_UNIT, "[ASSASS] Feint")
        end,
    },
}

NS.rotation_registry:register("assassination", strategies, { get_state = build_state })
return { strategies = strategies, build_state = build_state }
