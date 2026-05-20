-- ============================================================================
-- Kebab Warrior Rotation (Project Sylvanas API)
-- ============================================================================
-- "Kebab" = Dual-Wield Arms — a TBC live-play variant of Arms that uses
-- one-handed weapons in both hands instead of a single two-hander.
--
-- Why "kebab"? Community nickname for DW Arms — you "skewer" targets with
-- fast MH swings + Mortal Strike + Whirlwind off-hand hits.
--
-- Strategy priorities (sim-oracle aligned):
--   1. Execute (sub-20%)
--   2. Sweeping Strikes (2+ enemies)
--   3. Whirlwind (Berserker Stance — DW makes WW strong)
--   4. Mortal Strike (primary rage dump)
--   5. Overpower (dodge procs)
--   6. Hamstring / Sunder / Demo Shout / Thunder Clap (utility)
--   7. Heroic Strike / Cleave (rage dump, off-GCD queued)
--
-- Key differences from standard Arms:
--   - Requires Berserker Stance (not Battle) for WW
--   - Rage generation is higher due to DW auto-swings
--   - HS queue trick is less effective (faster OH swings = more rage)
--   - No Slam weaving (DW weapon speed is too fast)
--
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local load_player = NS.GetPlayer()

local enums = require("common/enums")
if type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
if not load_player or load_player:get_class() ~= enums.class_id.WARRIOR then return end

local SPELLS = NS.WarriorSpells
local Constants = NS.WarriorConstants
local format = string.format
local EMPTY_SETTINGS = {}

-- Debuff rank arrays (from WarriorConstants)
-- [PRE-ALLOC] Fallback arrays resolved once at load time to avoid `or {}` table
-- allocation in the combat path (GC pressure from per-frame creates).
local SUNDER_DEBUFF = Constants.SUNDER_DEBUFF or { 7386, 7405, 8380, 11596, 11597, 25225 }
local THUNDER_CLAP_DEBUFF = Constants.THUNDER_CLAP_DEBUFF or { 6343, 8198, 8204, 8205, 11580, 11581, 25264 }
local DEMO_SHOUT_DEBUFF = Constants.DEMO_SHOUT_DEBUFF or { 25203, 25202, 11556, 11555, 11554, 6190, 1160 }
local BATTLE_SHOUT_IDS = Constants.BATTLE_SHOUT_IDS or {}

-- Shared helpers from core_sylvanas.lua
local try_cast, spell_exists, spell_ready, debuff_remains, debuff_stacks, buff_remains, health_pct, player_control_locked, has_player_buff, has_breakable_cc_nearby, can_attack_target = NS.import_helpers(
    "try_cast", "spell_exists", "spell_ready", "debuff_remains",
    "debuff_stacks", "buff_remains", "health_pct", "player_control_locked", "has_player_buff", "has_breakable_cc_nearby", "can_attack_target"
)
local is_execute_phase = NS.is_execute_phase or function(hp, threshold) return (hp or 100) <= (threshold or 20) end

local get_debuff_stacks = debuff_stacks
local get_debuff_remains = debuff_remains

local function battle_shout_needs_refresh(unit)
    if not unit then return true end
    -- Use the documented IZI buff_remains extension when present,
    -- otherwise fall back to the shared NS.buff_remains wrapper.
    local min_refresh = 30
    for _, id in ipairs(BATTLE_SHOUT_IDS) do
        local remains = 0
        if unit.buff_remains then
            remains = unit:buff_remains(id) or 0
        else
            remains = buff_remains(unit, id)
        end
        if remains > min_refresh then return false end
        if remains > 0 then return true end
    end
    return true
end

-- Offhand weapon check
local OFFHAND_SLOT = 17
local function has_offhand_weapon()
    if NS.get_equipped_item_id and NS.get_equipped_item_id(OFFHAND_SLOT) then
        return true
    end
    local player = NS.GetPlayer()
    if not player or not player.get_item_at_inventory_slot then return false end
    local slot_info = player:get_item_at_inventory_slot(OFFHAND_SLOT)
    return slot_info ~= nil and slot_info.entry ~= nil and slot_info.entry ~= 0
end

local function get_cooldown(spell)
    return NS.cooldown_remains and NS.cooldown_remains(spell) or 0
end

-- HS/Cleave queued check
local function is_spell_current(spell_id)
    return NS.is_current_spell(spell_id)
end

local HEROIC_STRIKE_ID = NS.get_spell_id(SPELLS.HeroicStrike) or 78
local CLEAVE_ID = NS.get_spell_id(SPELLS.Cleave) or 845

-- ============================================================================
-- RAGE CONSTANTS
-- ============================================================================
local RAGE_COST_MS = 30
local RAGE_COST_WW = 25
local RAGE_COST_PUMMEL = 10

-- ============================================================================
-- SWEEPING STRIKES RAGE POOLING
-- ============================================================================
local SS_RESERVE_FLOOR = 60
local SS_POOL_WINDOW = 2.0

local function should_reserve_for_sweeping(context)
    if (context.enemy_count or 0) < 2 then return false end
            if context.settings and context.settings.kebab_use_sweeping_strikes == false then return false end
    if not spell_exists(SPELLS.SweepingStrikes) then return false end
    if has_player_buff(Constants.BUFF_ID.SWEEPING_STRIKES or 12328) then return false end
    local ss_cd = get_cooldown(SPELLS.SweepingStrikes)
    if ss_cd > SS_POOL_WINDOW then return false end
    if ss_cd <= SS_POOL_WINDOW and (context.rage or 0) < SS_RESERVE_FLOOR then return true end
    return false
end

-- ============================================================================
-- HS/CLEAVE CORE ABILITY STARVATION CHECK
-- ============================================================================
local function would_starve_core_kebab(context, state, cost)
    cost = cost or 15
    -- MS imminent
    if state.ms_cd >= 0 and state.ms_cd <= 1.5 and context.in_melee_range then
        if ((context.rage or 0) - cost) < RAGE_COST_MS then return true end
    end
    -- WW imminent
    if context.settings.kebab_use_whirlwind ~= false then
        if state.ww_cd >= 0 and state.ww_cd <= 1.5 and context.in_melee_range then
            if ((context.rage or 0) - cost) < RAGE_COST_WW then return true end
        end
    end
    return false
end

-- ============================================================================
-- KEBAB STATE (per-frame cache)
-- ============================================================================
local kebab_state = {
    general_use = false,
    target_below_20 = false,
    sunder_stacks = 0,
    sunder_duration = 0,
    thunder_clap_duration = 0,
    demo_shout_duration = 0,
    ms_cd = 0,
    ww_cd = 0,
}

local function build_kebab_state(context)
    if context._kebab_valid then return kebab_state end
    context._kebab_valid = true
    context.settings = context.settings or EMPTY_SETTINGS

    local target = context.target

    context.enemy_count = context.enemies_count or 0
    context.target_hp = target and health_pct(target) or 100
    context.in_melee_range = target and target.is_in_melee_range and target:is_in_melee_range(5) or false
    context.has_breakable_cc_nearby = has_breakable_cc_nearby(context)
    context.player_control_locked = player_control_locked()
    local player = NS.GetPlayer()
    context.is_moving = player and player.is_moving and player:is_moving() or false
    context.has_offhand = has_offhand_weapon()
    kebab_state.general_use = context.settings.kebab_general_use == true
        or context.is_leveling == true
        or (context.player_level and context.player_level < 62)
        or not context.has_offhand

    -- Swing timer for HS Trick (DW offhand weaving)
    context.mh_remain = NS.get_time_until_swing and NS.get_time_until_swing() or nil  -- [#28] auto_attack_helper
    context.oh_remain = NS.get_time_until_oh_swing and NS.get_time_until_oh_swing() or nil  -- [#28] auto_attack_helper

    kebab_state.target_below_20 = is_execute_phase(context.target_hp, 20)
    kebab_state.sunder_stacks = target and get_debuff_stacks(target, SUNDER_DEBUFF) or 0
    kebab_state.sunder_duration = target and get_debuff_remains(target, SUNDER_DEBUFF) or 0
    kebab_state.thunder_clap_duration = target and get_debuff_remains(target, THUNDER_CLAP_DEBUFF) or 0
    kebab_state.demo_shout_duration = target and get_debuff_remains(target, DEMO_SHOUT_DEBUFF) or 0
    kebab_state.ms_cd = get_cooldown(SPELLS.MortalStrike)
    kebab_state.ww_cd = get_cooldown(SPELLS.Whirlwind)

    return kebab_state
end

local function general_use_kebab(context, state)
    if context.settings and context.settings.kebab_force_dw_priority == true then return false end
    return state and state.general_use == true
end

-- ============================================================================
-- STRATEGIES (Priority order)
-- ============================================================================

local strategies = {

    -- [1] Execute (target <20% HP — highest ST priority per sim)
    {
        name = "Execute",
        matches = function(context, state)
            if not can_attack_target(context) then return false end
            if context.settings and context.settings.kebab_execute_phase == false then return false end
            if not state.target_below_20 then return false end
            -- Execute costs 15+ rage (variable)
            if (context.rage or 0) < 15 then return false end
            if not general_use_kebab(context, state) then
                if context.settings.kebab_use_ww_execute ~= false and (context.rage or 0) >= 25 and (state.ww_cd or 0) <= 0 then return false end
                if context.settings.kebab_use_ms_execute ~= false and (context.rage or 0) >= 30 and (state.ms_cd or 0) <= 0 then return false end
            end
            if context.stance ~= Constants.STANCE.BATTLE and context.stance ~= Constants.STANCE.BERSERKER then
                return spell_exists(SPELLS.BerserkerStance) and spell_ready(SPELLS.BerserkerStance, NS.PLAYER_UNIT)
            end
            return spell_exists(SPELLS.Execute) and spell_ready(SPELLS.Execute, context.target)
        end,
        execute = function(context, state)
            if context.stance ~= Constants.STANCE.BATTLE and context.stance ~= Constants.STANCE.BERSERKER then
                return try_cast(SPELLS.BerserkerStance, NS.PLAYER_UNIT, "[KEBAB] Berserker Stance (for Execute)")
            end
            return try_cast(SPELLS.Execute, context.target,
                format("[KEBAB] Execute - Rage: %d, HP: %.0f%%", context.rage or 0, context.target_hp or 0))
        end,
    },

    -- [2] Sweeping Strikes (AoE — before WW to double hits)
    {
        name = "SweepingStrikes",
        matches = function(context)
            if not can_attack_target(context) then return false end
    if context.settings and context.settings.kebab_use_sweeping_strikes == false then return false end
            if (context.enemy_count or 0) < 2 then return false end
            if has_player_buff(Constants.BUFF_ID.SWEEPING_STRIKES or 12328) then return false end
            if (context.rage or 0) < 30 then return false end
            if context.stance ~= Constants.STANCE.BATTLE and context.stance ~= Constants.STANCE.BERSERKER then return false end
            return spell_exists(SPELLS.SweepingStrikes) and spell_ready(SPELLS.SweepingStrikes, NS.PLAYER_UNIT)
        end,
        execute = function(context)
            return try_cast(SPELLS.SweepingStrikes, NS.PLAYER_UNIT,
                format("[KEBAB] Sweeping Strikes - Rage: %d, Enemies: %d", context.rage or 0, context.enemy_count or 0))
        end,
    },

    -- [2.5] General-use Kebab favors Mortal Strike before stance dancing for Whirlwind.
    {
        name = "MortalStrikeGeneralUse",
        matches = function(context, state)
            if not general_use_kebab(context, state) then return false end
            if not can_attack_target(context) then return false end
            if state.target_below_20 and context.settings.kebab_execute_phase and context.settings.kebab_use_ms_execute == false then return false end
            if (context.rage or 0) < 30 then return false end
            return spell_exists(SPELLS.MortalStrike) and spell_ready(SPELLS.MortalStrike, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.MortalStrike, context.target, "[KEBAB] Mortal Strike general-use")
        end,
    },

    -- [3] Whirlwind (Berserker Stance — above MS for DW, more damage per rage)
    {
        name = "Whirlwind",
        matches = function(context, state)
            if not can_attack_target(context) then return false end
            if context.settings and context.settings.kebab_use_whirlwind == false then return false end
            if general_use_kebab(context, state) and (context.enemy_count or 0) < 2 then return false end
            if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
            -- Execute phase gate
            if state.target_below_20 and context.settings.kebab_execute_phase then
                if not context.settings.kebab_use_ww_execute then return false end
            end
            if (context.rage or 0) < 25 then return false end
            -- Don't WW if we should be pooling for SS
            if should_reserve_for_sweeping(context) then return false end
            -- Stance gate — need Berserker
            if context.stance ~= Constants.STANCE.BERSERKER then
                return spell_exists(SPELLS.BerserkerStance) and spell_ready(SPELLS.BerserkerStance, NS.PLAYER_UNIT)
            end
            return spell_exists(SPELLS.Whirlwind) and spell_ready(SPELLS.Whirlwind, NS.PLAYER_UNIT)
        end,
        execute = function(context)
            -- Stance swap if needed (no TM — accept rage loss; wrong stance is worse)
            if context.stance ~= Constants.STANCE.BERSERKER then
                return try_cast(SPELLS.BerserkerStance, NS.PLAYER_UNIT, "[KEBAB] Berserker Stance (for WW)")
            end
            return try_cast(SPELLS.Whirlwind, NS.PLAYER_UNIT,
                format("[KEBAB] Whirlwind - Rage: %d", context.rage or 0))
        end,
    },

    -- [4] Mortal Strike (below WW in priority for DW)
    {
        name = "MortalStrike",
        matches = function(context, state)
            if not can_attack_target(context) then return false end
            -- Execute phase gate
            if state.target_below_20 and context.settings.kebab_execute_phase then
                if not context.settings.kebab_use_ms_execute then return false end
            end
            return spell_exists(SPELLS.MortalStrike) and spell_ready(SPELLS.MortalStrike, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.MortalStrike, context.target, "[KEBAB] Mortal Strike")
        end,
    },

    -- [5] Overpower (only if already in Battle Stance with dodge proc)
    -- No proactive stance dance — Kebab lives in Berserker, uses OP opportunistically
    {
        name = "Overpower",
        matches = function(context)
            if not can_attack_target(context) then return false end
            if context.settings and context.settings.kebab_use_overpower == false then return false end
            -- Only use if already in Battle Stance (from a stance swap for other reasons)
            if context.stance ~= Constants.STANCE.BATTLE then return false end
            return spell_exists(SPELLS.Overpower) and spell_ready(SPELLS.Overpower, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.Overpower, context.target,
                format("[KEBAB] Overpower - Rage: %d", context.rage or 0))
        end,
    },

    -- [6] Shout maintenance
    {
        name = "BattleShout",
        is_gcd_gated = false,
        matches = function(context)
            if context.settings and context.settings.auto_shout == false then return false end
            local shout_type = (context.settings and context.settings.shout_type) or "battle"
            if shout_type ~= "battle" then return false end
            if not can_attack_target(context) then return false end
            if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
            local player = NS.GetPlayer()
            if not battle_shout_needs_refresh(player) then return false end
            if (context.rage or 0) < 10 then return false end
            return spell_exists(SPELLS.BattleShout) and spell_ready(SPELLS.BattleShout, NS.PLAYER_UNIT)
        end,
        execute = function()
            return try_cast(SPELLS.BattleShout, NS.PLAYER_UNIT, "[KEBAB] Battle Shout")
        end,
    },
    {
        name = "CommandingShout",
        is_gcd_gated = false,
        matches = function(context)
            if context.settings and context.settings.auto_shout == false then return false end
            local shout_type = (context.settings and context.settings.shout_type) or "battle"
            if shout_type ~= "commanding" then return false end
            if not can_attack_target(context) then return false end
            if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
            if has_player_buff(Constants.COMMANDING_SHOUT_BUFF or 469) then return false end
            if (context.rage or 0) < 10 then return false end
            return spell_exists(SPELLS.CommandingShout) and spell_ready(SPELLS.CommandingShout, NS.PLAYER_UNIT)
        end,
        execute = function()
            return try_cast(SPELLS.CommandingShout, NS.PLAYER_UNIT, "[KEBAB] Commanding Shout")
        end,
    },

    -- [7] Sunder Armor maintenance (if configured)
    {
        name = "SunderMaintain",
        matches = function(context, state)
            local mode = context.settings.sunder_armor_mode or "none"
            if not can_attack_target(context) or mode == "none" then return false end
            if context.stance ~= Constants.STANCE.BATTLE and context.stance ~= Constants.STANCE.DEFENSIVE then return false end

            if mode == "help_stack" then
                if state.sunder_stacks >= (Constants.SUNDER_MAX_STACKS or 5) then return false end
            elseif mode == "maintain" then
                if state.sunder_stacks >= (Constants.SUNDER_MAX_STACKS or 5)
                    and state.sunder_duration > (Constants.SUNDER_REFRESH_WINDOW or 3)
                then
                    return false
                end
            end

            -- Prefer Devastate if available (Protection talent)
            if context.stance == Constants.STANCE.DEFENSIVE and spell_exists(SPELLS.Devastate) and spell_ready(SPELLS.Devastate, context.target) then
                return true
            end

            return spell_exists(SPELLS.SunderArmor) and spell_ready(SPELLS.SunderArmor, context.target)
        end,
        execute = function(context, state)
            if context.stance == Constants.STANCE.DEFENSIVE and spell_exists(SPELLS.Devastate) and spell_ready(SPELLS.Devastate, context.target) then
                return try_cast(SPELLS.Devastate, context.target,
                    format("[KEBAB] Devastate (Sunder) - Stacks: %d", state.sunder_stacks or 0))
            end
            return try_cast(SPELLS.SunderArmor, context.target,
                format("[KEBAB] Sunder Armor - Stacks: %d", state.sunder_stacks or 0))
        end,
    },

    -- [8] Thunder Clap maintenance
    {
        name = "ThunderClap",
        matches = function(context, state)
            if not can_attack_target(context) then return false end
            if context.settings and context.settings.maintain_thunder_clap == false then return false end
            if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
            if state.thunder_clap_duration > (Constants.TC_REFRESH_WINDOW or 2) then return false end
            if context.stance ~= Constants.STANCE.BATTLE then return false end
            return spell_exists(SPELLS.ThunderClap) and spell_ready(SPELLS.ThunderClap, NS.PLAYER_UNIT)
        end,
        execute = function()
            return try_cast(SPELLS.ThunderClap, NS.PLAYER_UNIT,
                format("[KEBAB] Thunder Clap - Duration: %.1fs", kebab_state.thunder_clap_duration or 0))
        end,
    },

    -- [9] Demoralizing Shout maintenance
    {
        name = "DemoShout",
        matches = function(context, state)
            if not can_attack_target(context) then return false end
            if context.settings and context.settings.maintain_demo_shout == false then return false end
            if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
            if not context.in_melee_range then return false end
            if state.demo_shout_duration > 3 then return false end
            return spell_exists(SPELLS.DemoralizingShout) and spell_ready(SPELLS.DemoralizingShout, NS.PLAYER_UNIT)
        end,
        execute = function()
            return try_cast(SPELLS.DemoralizingShout, NS.PLAYER_UNIT,
                format("[KEBAB] Demo Shout - Duration: %.1fs", kebab_state.demo_shout_duration or 0))
        end,
    },

    -- [10] Heroic Strike / Cleave (off-GCD rage dump with core starvation check)
    {
        name = "HeroicStrike",
        is_gcd_gated = false,
        matches = function(context, state)
            if not can_attack_target(context) then return false end
            -- Don't double-queue
            if is_spell_current(HEROIC_STRIKE_ID) or is_spell_current(CLEAVE_ID) then return false end
            -- Execute phase gate
            if state.target_below_20 and context.settings.kebab_execute_phase then
                if not context.settings.kebab_hs_during_execute then return false end
            end

            -- HS Trick: proactively queue when OH swing is imminent
            if context.settings.hs_trick and context.has_offhand then
                local oh_remaining = context.oh_remain
                local mh_remaining = context.mh_remain
                if oh_remaining and mh_remaining and oh_remaining > 0 and oh_remaining <= 0.4 then
                    if mh_remaining > oh_remaining + 0.3 then
                        return true
                    end
                end
            end

            local threshold = context.settings.kebab_hs_rage_threshold or 40
            if context.settings.hs_trick and context.has_offhand then
                threshold = 30
            end
            if general_use_kebab(context, state) and threshold < 55 then
                threshold = 55
            end
            if (context.rage or 0) < threshold then return false end

            -- Don't starve core abilities
            if would_starve_core_kebab(context, state, 15) then return false end

            -- Hold rage for pummel if interrupt is needed (centralized NS.try_interrupt)
            if context.settings.use_interrupt then
                local should_kick = NS.try_interrupt(context.target)
                if should_kick then
                    if ((context.rage or 0) - 15) < RAGE_COST_PUMMEL then return false end
                end
            end

            return true
        end,
        execute = function(context)
            local cleave_at = context.settings.aoe_threshold or 2
            local cc_safe = not (context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check)
            -- Prefer Cleave in AoE
            if cc_safe and cleave_at > 0 and (context.enemy_count or 0) >= cleave_at
                and spell_exists(SPELLS.Cleave) and spell_ready(SPELLS.Cleave, context.target)
            then
                return try_cast(SPELLS.Cleave, context.target,
                    format("[KEBAB] Cleave - Rage: %d, Enemies: %d", context.rage or 0, context.enemy_count or 0))
            end

            if spell_exists(SPELLS.HeroicStrike) and spell_ready(SPELLS.HeroicStrike, context.target) then
                return try_cast(SPELLS.HeroicStrike, context.target,
                    format("[KEBAB] Heroic Strike - Rage: %d", context.rage or 0))
            end
            return false
        end,
    },
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================

NS.rotation_registry:register("kebab", strategies, {
    context_builder = build_kebab_state,
})

NS.log("Kebab (DW Arms) rotation registered")
return strategies
