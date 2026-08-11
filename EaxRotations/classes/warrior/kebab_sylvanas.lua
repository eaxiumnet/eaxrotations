-- kebab_sylvanas.lua — Warrior Kebab (DW Arms) rotation for TBC Anniversary (2.5.5).
-- WHAT:  priority-list strategies (Execute → SS → WW → MS → Overpower → utility → HS/Cleave dump).
-- WHEN:  combat with valid enemy target, dual-wield or general-use fallback.
-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics (DW Arms variant).
-- SAFETY: state.* reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.
-- DECISION: Strategy DSL adopted for all 16 strategies with custom conditions preserving
--            stance dancing, HS trick, and all helper functions.

local NS = _G.EaxRotations
if not NS then return nil end

do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local _cleu = NS.SwingDiagnostics
if _cleu then
    _cleu.register_seals({ 1464, 8820, 11604, 11605, 25241, 25242, 78, 284, 285, 1608, 11584, 11585, 25286 })
end
local potion_helper = require("shared/potion_helper_sylvanas")
local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local _inv_ok, inventory_helper = pcall(require, "common/utility/inventory_helper")
if not _inv_ok or type(inventory_helper) ~= "table" then inventory_helper = nil end

local load_player = NS.GetPlayer and NS.GetPlayer()
local _ok_enums, enums = pcall(require, "common/enums")
if not _ok_enums or type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
local ok_cls, cls_id = pcall(function() return load_player and load_player:get_class() end)
if load_player and ok_cls and cls_id ~= enums.class_id.WARRIOR then return end

local SPELLS = NS.WarriorSpells or {}
local Constants = NS.WarriorConstants or {}
local format = string.format
local EMPTY_SETTINGS = {}

local function settings_for(context)
    return (context and context.settings) or EMPTY_SETTINGS
end

local function safe_unit_call(unit, method, ...)
    if not unit or type(unit[method]) ~= "function" then return nil end
    local ok, value = pcall(unit[method], unit, ...)
    if ok then return value end
    return nil
end

local SUNDER_DEBUFF = Constants.SUNDER_DEBUFF or { 7386, 7405, 8380, 11596, 11597, 25225 }
local THUNDER_CLAP_DEBUFF = Constants.THUNDER_CLAP_DEBUFF or { 6343, 8198, 8204, 8205, 11580, 11581, 25264 }
local DEMO_SHOUT_DEBUFF = Constants.DEMO_SHOUT_DEBUFF or { 25203, 25202, 11556, 11555, 11554, 6190, 1160 }
local BATTLE_SHOUT_IDS = Constants.BATTLE_SHOUT_IDS or { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }

local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local function first_ready_item(ids)
    if not inventory_helper then return nil end
    for _, id in ipairs(ids) do
        if inventory_helper.has_item(id) then return id end
    end
    return nil
end

local try_cast, spell_exists, spell_ready, debuff_remains, debuff_stacks, buff_remains, health_pct, player_control_locked, has_player_buff, has_breakable_cc_nearby, can_attack_target = NS.import_helpers(
    "try_cast", "spell_exists", "spell_ready", "debuff_remains",
    "debuff_stacks", "buff_remains", "health_pct", "player_control_locked", "has_player_buff", "has_breakable_cc_nearby", "can_attack_target"
)
local is_execute_phase = NS.is_execute_phase or function(hp, threshold) return (hp or 100) <= (threshold or 20) end
local get_debuff_stacks = debuff_stacks
local get_debuff_remains = debuff_remains

local function battle_shout_needs_refresh(unit)
    if not unit then return true end
    for _, id in ipairs(BATTLE_SHOUT_IDS) do
        local remains = NS.buff_remains(unit, {id}) or 0
        if remains > 30 then return false end
    end
    return true
end

local OFFHAND_SLOT = 17
local function has_offhand_weapon()
    if NS.get_equipped_item_id and NS.get_equipped_item_id(OFFHAND_SLOT) then return true end
    local player = NS.GetPlayer()
    if not player or not player.get_item_at_inventory_slot then return false end
    local slot_info = safe_unit_call(player, "get_item_at_inventory_slot", OFFHAND_SLOT)
    return slot_info ~= nil and slot_info.entry ~= nil and slot_info.entry ~= 0
end

local function get_cooldown(spell)
    return NS.cooldown_remains and NS.cooldown_remains(spell) or 0
end

local function is_spell_current(spell_id)
    return NS.is_current_spell(spell_id)
end

local HEROIC_STRIKE_ID = NS.get_spell_id(SPELLS.HeroicStrike) or 78
local CLEAVE_ID = NS.get_spell_id(SPELLS.Cleave) or 845
local RAGE_COST_MS = 30
local RAGE_COST_WW = 25
local RAGE_COST_PUMMEL = 10
local SS_RESERVE_FLOOR = 60
local SS_POOL_WINDOW = 2.0

local function should_reserve_for_sweeping(context)
    local settings = settings_for(context)
    if (context.enemy_count or 0) < 2 then return false end
    if settings.kebab_use_sweeping_strikes == false then return false end
    if not spell_exists(SPELLS.SweepingStrikes) then return false end
    if has_player_buff(Constants.BUFF_ID.SWEEPING_STRIKES or 12328) then return false end
    local ss_cd = get_cooldown(SPELLS.SweepingStrikes)
    return ss_cd <= SS_POOL_WINDOW and (context.rage or 0) < SS_RESERVE_FLOOR
end

local function would_starve_core_kebab(context, state, cost)
    cost = cost or 15
    local settings = settings_for(context)
    if (state.ms_cd or 99) >= 0 and (state.ms_cd or 99) <= 1.5 and context.in_melee_range then
        if ((context.rage or 0) - cost) < RAGE_COST_MS then return true end
    end
    if settings.kebab_use_whirlwind ~= false then
        if (state.ww_cd or 99) >= 0 and (state.ww_cd or 99) <= 1.5 and context.in_melee_range then
            if ((context.rage or 0) - cost) < RAGE_COST_WW then return true end
        end
    end
    return false
end

local kebab_state = { general_use = false, target_below_20 = false, sunder_stacks = 0, sunder_duration = 0, thunder_clap_duration = 0, demo_shout_duration = 0, ms_cd = 0, ww_cd = 0, healthstone_ready = 0 }
local KEBAB_SCHEMA = { general_use = false, target_below_20 = false, sunder_stacks = 0, sunder_duration = 0, thunder_clap_duration = 0, demo_shout_duration = 0, ms_cd = 99, ww_cd = 99, pummel_ready = false, healthstone_ready = 0, is_group = false }

local function build_state(context)
    kebab_state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS) or 0
    if context._kebab_valid then return spec_kit.safe_state(kebab_state, KEBAB_SCHEMA) end
    context._kebab_valid = true
    kebab_state.is_group = context.is_group or false
    context.settings = context.settings or EMPTY_SETTINGS
    local target = context.target
    context.enemy_count = context.enemies_count or 0
    context.target_hp = target and health_pct(target) or 100
    context.in_melee_range = target and safe_unit_call(target, "is_in_melee_range", 5) or false
    context.has_breakable_cc_nearby = has_breakable_cc_nearby(context)
    context.player_control_locked = (type(player_control_locked) == "function" and player_control_locked()) or false
    local player = NS.GetPlayer()
    context.is_moving = context.is_moving or (safe_unit_call(player, "is_moving") or false)
    context.has_offhand = has_offhand_weapon()
    local settings = settings_for(context)
    kebab_state.general_use = settings.kebab_general_use == true or context.is_leveling == true or (context.player_level and context.player_level < 62) or not context.has_offhand
    context.mh_remain = (_cleu and _cleu.get_swing_remains and _cleu.get_swing_remains()) or (NS.get_time_until_swing and NS.get_time_until_swing()) or nil
    context.oh_remain = NS.get_time_until_oh_swing and NS.get_time_until_oh_swing() or nil
    kebab_state.target_below_20 = is_execute_phase(context.target_hp, 20)
    kebab_state.sunder_stacks = target and get_debuff_stacks(target, SUNDER_DEBUFF) or 0
    kebab_state.sunder_duration = target and get_debuff_remains(target, SUNDER_DEBUFF) or 0
    kebab_state.thunder_clap_duration = target and get_debuff_remains(target, THUNDER_CLAP_DEBUFF) or 0
    kebab_state.demo_shout_duration = target and get_debuff_remains(target, DEMO_SHOUT_DEBUFF) or 0
    kebab_state.ms_cd = get_cooldown(SPELLS.MortalStrike)
    kebab_state.ww_cd = get_cooldown(SPELLS.Whirlwind)
    return spec_kit.safe_state(kebab_state, KEBAB_SCHEMA)
end

local function general_use_kebab(context, state)
    if settings_for(context).kebab_force_dw_priority == true then return false end
    return state and state.general_use == true
end

-- ============================================================================
-- Declarative Strategy DSL definitions
-- ============================================================================
local DSL_DEFS = {
    { name = "HealthPotion", conditions = {
        { type = "in_combat" },
        { type = "custom", fn = function(context, state)
            if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
            if not context.has_health_potion then return false end
            if (context.hp or 100) > 35 then return false end
            return true
        end },
    }, action = { type = "custom", fn = function(context) return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS) end } },
    { name = "DamagePotion", conditions = {
        { type = "in_combat" },
        { type = "custom", fn = function(context, state)
            if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
            if not context.has_damage_potion then return false end
            if not context.should_burst then return false end
            return true
        end },
    }, action = { type = "custom", fn = function(context) return potion_helper.try_use_potion(context, potion_helper.DAMAGE_POTION_IDS) end } },
    { name = "Healthstone", conditions = {
        { type = "in_combat" }, { type = "state", field = "hp_pct", op = "<=", value = 28 },
        { type = "state", field = "healthstone_ready", op = ">", value = 0 },
    }, action = { type = "custom", fn = function(context)
        local id = first_ready_item(HEALTHSTONE_IDS)
        if id then NS.use_item_by_id(id, context.me) end
    end } },
    { name = "Pummel", conditions = {
        { type = "custom", fn = function(context, state)
            local settings = settings_for(context)
            if not can_attack_target(context) then return false end
            if settings.use_interrupt == false then return false end
            if not context.target then return false end
            local ok, casting = pcall(function() return context.target:is_casting() end)
            if not (ok and casting) then return false end
            local ok2, interruptible = pcall(function() return context.target:is_cast_interruptible() end)
            if ok2 and interruptible == false then return false end
            if (context.rage or 0) < 10 then return false end
            if not (spell_exists(SPELLS.Pummel) and spell_ready(SPELLS.Pummel, context.target)) then return false end
            return true
        end },
    }, action = { type = "custom", fn = function(context)
        return try_cast(SPELLS.Pummel, context.target, "[KEBAB] Pummel")
    end } },
    { name = "Execute", conditions = {
        { type = "custom", fn = function(context, state)
            local settings = settings_for(context)
            if not can_attack_target(context) then return false end
            if settings.kebab_execute_phase == false then return false end
            if not state.target_below_20 then return false end
            if (context.rage or 0) < 15 then return false end
            if not general_use_kebab(context, state) then
                if settings.kebab_use_ww_execute ~= false and (context.rage or 0) >= 25 and (state.ww_cd or 0) <= 0 then return false end
                if settings.kebab_use_ms_execute ~= false and (context.rage or 0) >= 30 and (state.ms_cd or 0) <= 0 then return false end
            end
            if context.stance ~= Constants.STANCE.BATTLE and context.stance ~= Constants.STANCE.BERSERKER then
                if not (spell_exists(SPELLS.BerserkerStance) and spell_ready(SPELLS.BerserkerStance, NS.PLAYER_UNIT)) then return false end
            end
            if not (spell_exists(SPELLS.Execute) and spell_ready(SPELLS.Execute, context.target)) then return false end
            return true
        end },
    }, action = { type = "custom", fn = function(context, state)
        if context.stance ~= Constants.STANCE.BATTLE and context.stance ~= Constants.STANCE.BERSERKER then
            return try_cast(SPELLS.BerserkerStance, NS.PLAYER_UNIT, "[KEBAB] Berserker Stance (for Execute)", { skip_range = true })
        end
        return try_cast(SPELLS.Execute, context.target, format("[KEBAB] Execute - Rage: %d, HP: %.0f%%", context.rage or 0, context.target_hp or 0))
    end } },
    { name = "SweepingStrikes", conditions = {
        { type = "custom", fn = function(context, state)
            local settings = settings_for(context)
            if not can_attack_target(context) then return false end
            if settings.kebab_use_sweeping_strikes == false then return false end
            if (context.enemy_count or 0) < 2 then return false end
            if has_player_buff(Constants.BUFF_ID.SWEEPING_STRIKES or 12328) then return false end
            if (context.rage or 0) < 30 then return false end
            if context.stance ~= Constants.STANCE.BATTLE then
                if not (spell_exists(SPELLS.BattleStance) and spell_ready(SPELLS.BattleStance, NS.PLAYER_UNIT)) then return false end
            end
            if not (spell_exists(SPELLS.SweepingStrikes) and spell_ready(SPELLS.SweepingStrikes, NS.PLAYER_UNIT)) then return false end
            return true
        end },
    }, action = { type = "custom", fn = function(context)
        if context.stance ~= Constants.STANCE.BATTLE then
            return try_cast(SPELLS.BattleStance, NS.PLAYER_UNIT, "[KEBAB] Battle Stance (for Sweeping Strikes)", { skip_range = true })
        end
        return try_cast(SPELLS.SweepingStrikes, NS.PLAYER_UNIT, format("[KEBAB] Sweeping Strikes - Rage: %d, Enemies: %d", context.rage or 0, context.enemy_count or 0), { skip_range = true })
    end } },
    { name = "MortalStrikeGeneralUse", conditions = {
        { type = "custom", fn = function(context, state)
            local settings = settings_for(context)
            if not general_use_kebab(context, state) then return false end
            if not can_attack_target(context) then return false end
            if state.target_below_20 and settings.kebab_execute_phase and settings.kebab_use_ms_execute == false then return false end
            if (context.rage or 0) < 30 then return false end
            if not (spell_exists(SPELLS.MortalStrike) and spell_ready(SPELLS.MortalStrike, context.target)) then return false end
            return true
        end },
    }, action = { type = "custom", fn = function(context)
        return try_cast(SPELLS.MortalStrike, context.target, "[KEBAB] Mortal Strike general-use")
    end } },
    { name = "Whirlwind", conditions = {
        { type = "custom", fn = function(context, state)
            local settings = settings_for(context)
            if not can_attack_target(context) then return false end
            if settings.kebab_use_whirlwind == false then return false end
            if general_use_kebab(context, state) and not (NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)) then return false end
            if context.has_breakable_cc_nearby and settings.pvp_cc_break_check then return false end
            if state.target_below_20 and settings.kebab_execute_phase and not settings.kebab_use_ww_execute then return false end
            if (context.rage or 0) < 25 then return false end
            if should_reserve_for_sweeping(context) then return false end
            if context.stance ~= Constants.STANCE.BERSERKER then
                if not (spell_exists(SPELLS.BerserkerStance) and spell_ready(SPELLS.BerserkerStance, NS.PLAYER_UNIT)) then return false end
            end
            if not (spell_exists(SPELLS.Whirlwind) and spell_ready(SPELLS.Whirlwind, NS.PLAYER_UNIT)) then return false end
            return true
        end },
    }, action = { type = "custom", fn = function(context)
        if context.stance ~= Constants.STANCE.BERSERKER then
            return try_cast(SPELLS.BerserkerStance, NS.PLAYER_UNIT, "[KEBAB] Berserker Stance (for WW)", { skip_range = true })
        end
        return try_cast(SPELLS.Whirlwind, NS.PLAYER_UNIT, format("[KEBAB] Whirlwind - Rage: %d", context.rage or 0), { skip_range = true })
    end } },
    { name = "MortalStrike", conditions = {
        { type = "custom", fn = function(context, state)
            local settings = settings_for(context)
            if not can_attack_target(context) then return false end
            if state.target_below_20 and settings.kebab_execute_phase and not settings.kebab_use_ms_execute then return false end
            if not (spell_exists(SPELLS.MortalStrike) and spell_ready(SPELLS.MortalStrike, context.target)) then return false end
            return true
        end },
    }, action = { type = "custom", fn = function(context)
        return try_cast(SPELLS.MortalStrike, context.target, "[KEBAB] Mortal Strike")
    end } },
    { name = "Overpower", conditions = {
        { type = "custom", fn = function(context, state)
            local settings = settings_for(context)
            if not can_attack_target(context) then return false end
            if settings.kebab_use_overpower == false then return false end
            if context.stance ~= Constants.STANCE.BATTLE then return false end
            if not (spell_exists(SPELLS.Overpower) and spell_ready(SPELLS.Overpower, context.target)) then return false end
            return true
        end },
    }, action = { type = "custom", fn = function(context)
        return try_cast(SPELLS.Overpower, context.target, format("[KEBAB] Overpower - Rage: %d", context.rage or 0))
    end } },
    { name = "BattleShout", conditions = {
        { type = "custom", fn = function(context, state)
            local settings = settings_for(context)
            if settings.auto_shout == false then return false end
            if (settings.shout_type or "battle") ~= "battle" then return false end
            if not can_attack_target(context) then return false end
            if context.has_breakable_cc_nearby and settings.pvp_cc_break_check then return false end
            local player = NS.GetPlayer()
            if not battle_shout_needs_refresh(player) then return false end
            if (context.rage or 0) < 10 then return false end
            if not (spell_exists(SPELLS.BattleShout) and spell_ready(SPELLS.BattleShout, NS.PLAYER_UNIT)) then return false end
            return true
        end },
    }, action = { type = "custom", fn = function()
        return try_cast(SPELLS.BattleShout, NS.PLAYER_UNIT, "[KEBAB] Battle Shout", { skip_range = true })
    end } },
    { name = "CommandingShout", conditions = {
        { type = "custom", fn = function(context, state)
            local settings = settings_for(context)
            if settings.auto_shout == false then return false end
            if not can_attack_target(context) then return false end
            if context.has_breakable_cc_nearby and settings.pvp_cc_break_check then return false end
            if has_player_buff(Constants.COMMANDING_SHOUT_BUFF or 469) then return false end
            if (context.rage or 0) < 10 then return false end
            if not (spell_exists(SPELLS.CommandingShout) and spell_ready(SPELLS.CommandingShout, NS.PLAYER_UNIT)) then return false end
            return true
        end },
    }, action = { type = "custom", fn = function()
        return try_cast(SPELLS.CommandingShout, NS.PLAYER_UNIT, "[KEBAB] Commanding Shout", { skip_range = true })
    end } },
    { name = "SunderMaintain", conditions = {
        { type = "custom", fn = function(context, state)
            local settings = settings_for(context)
            local mode = settings.sunder_armor_mode or "none"
            if not can_attack_target(context) or mode == "none" then return false end
            if (context.target_armor or 0) <= 0 then return false end
            if context.stance ~= Constants.STANCE.DEFENSIVE then return false end
            if mode == "help_stack" and (state.sunder_stacks or 0) >= (Constants.SUNDER_MAX_STACKS or 5) then return false end
            if mode == "maintain" and (state.sunder_stacks or 0) >= (Constants.SUNDER_MAX_STACKS or 5) and (state.sunder_duration or 0) > (Constants.SUNDER_REFRESH_WINDOW or 3) then return false end
            if context.stance == Constants.STANCE.DEFENSIVE and spell_exists(SPELLS.Devastate) and spell_ready(SPELLS.Devastate, context.target) then return true end
            if not (spell_exists(SPELLS.SunderArmor) and spell_ready(SPELLS.SunderArmor, context.target)) then return false end
            return true
        end },
    }, action = { type = "custom", fn = function(context, state)
        if context.stance == Constants.STANCE.DEFENSIVE and spell_exists(SPELLS.Devastate) and spell_ready(SPELLS.Devastate, context.target) then
            return try_cast(SPELLS.Devastate, context.target, format("[KEBAB] Devastate (Sunder) - Stacks: %d", state.sunder_stacks or 0))
        end
        return try_cast(SPELLS.SunderArmor, context.target, format("[KEBAB] Sunder Armor - Stacks: %d", state.sunder_stacks or 0))
    end } },
    { name = "ThunderClap", conditions = {
        { type = "custom", fn = function(context, state)
            local settings = settings_for(context)
            if not can_attack_target(context) then return false end
            if settings.maintain_thunder_clap == false then return false end
            if context.has_breakable_cc_nearby and settings.pvp_cc_break_check then return false end
            if (state.thunder_clap_duration or 0) > (Constants.TC_REFRESH_WINDOW or 2) then return false end
            if context.stance ~= Constants.STANCE.BATTLE then return false end
            if not (spell_exists(SPELLS.ThunderClap) and spell_ready(SPELLS.ThunderClap, NS.PLAYER_UNIT)) then return false end
            return true
        end },
    }, action = { type = "custom", fn = function()
        return try_cast(SPELLS.ThunderClap, NS.PLAYER_UNIT, format("[KEBAB] Thunder Clap - Duration: %.1fs", kebab_state.thunder_clap_duration or 0), { skip_range = true })
    end } },
    { name = "DemoShout", conditions = {
        { type = "custom", fn = function(context, state)
            local settings = settings_for(context)
            if not can_attack_target(context) then return false end
            if settings.maintain_demo_shout == false then return false end
            if context.has_breakable_cc_nearby and settings.pvp_cc_break_check then return false end
            if not context.in_melee_range then return false end
            if (state.demo_shout_duration or 0) > 3 then return false end
            if not (spell_exists(SPELLS.DemoralizingShout) and spell_ready(SPELLS.DemoralizingShout, NS.PLAYER_UNIT)) then return false end
            return true
        end },
    }, action = { type = "custom", fn = function()
        return try_cast(SPELLS.DemoralizingShout, NS.PLAYER_UNIT, format("[KEBAB] Demo Shout - Duration: %.1fs", kebab_state.demo_shout_duration or 0), { skip_range = true })
    end } },
    { name = "HeroicStrike", conditions = {
        { type = "custom", fn = function(context, state)
            local settings = settings_for(context)
            if not can_attack_target(context) then return false end
            if is_spell_current(HEROIC_STRIKE_ID) or is_spell_current(CLEAVE_ID) then return false end
            if state.target_below_20 and settings.kebab_execute_phase and not settings.kebab_hs_during_execute then return false end
            if settings.hs_trick and context.has_offhand then
                local oh_remaining, mh_remaining = context.oh_remain, context.mh_remain
                if oh_remaining and mh_remaining and oh_remaining > 0 and oh_remaining <= 0.4 and mh_remaining > oh_remaining + 0.3 then
                    return true
                end
            end
            local threshold = settings.hs_trick and context.has_offhand and 30 or (settings.kebab_hs_rage_threshold or 40)
            if general_use_kebab(context, state) and threshold < 55 then threshold = 55 end
            if (context.rage or 0) < threshold then return false end
            if would_starve_core_kebab(context, state, 15) then return false end
            if settings.use_interrupt then
                local should_kick = NS.try_interrupt(context.target)
                if should_kick and ((context.rage or 0) - 15) < RAGE_COST_PUMMEL then return false end
            end
            return true
        end },
    }, action = { type = "custom", fn = function(context, state)
        local settings = settings_for(context)
        local cleave_at = settings.aoe_threshold or 2
        local cc_safe = not (context.has_breakable_cc_nearby and settings.pvp_cc_break_check)
        local cleave_hit = NS.aoe_target_meets and NS.aoe_target_meets(cleave_at, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_8) or 8, context.target, context, state)
        if cc_safe and cleave_at > 0 and cleave_hit and spell_exists(SPELLS.Cleave) and spell_ready(SPELLS.Cleave, context.target) then
            return try_cast(SPELLS.Cleave, context.target, format("[KEBAB] Cleave - Rage: %d, Enemies: %d", context.rage or 0, context.enemy_count or 0))
        end
        if spell_exists(SPELLS.HeroicStrike) and spell_ready(SPELLS.HeroicStrike, context.target) then
            return try_cast(SPELLS.HeroicStrike, context.target, format("[KEBAB] Heroic Strike - Rage: %d", context.rage or 0))
        end
        return false
    end } },
}

-- ============================================================================
-- STRATEGIES (name-only placeholders; substituted at runtime via DSL)
-- ============================================================================
local strategies = {
    { name = "HealthPotion" },
    { name = "DamagePotion" },
    { name = "Healthstone" },
    { name = "Pummel" },
    { name = "Execute" },
    { name = "SweepingStrikes" },
    { name = "MortalStrikeGeneralUse" },
    { name = "Whirlwind" },
    { name = "MortalStrike" },
    { name = "Overpower" },
    { name = "BattleShout", is_gcd_gated = false },
    { name = "CommandingShout", is_gcd_gated = false },
    { name = "SunderMaintain" },
    { name = "ThunderClap" },
    { name = "DemoShout" },
    { name = "HeroicStrike", is_gcd_gated = false },
}

-- Name-based substitution preserves priority order + extra fields.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            local compiled = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            for k, v in pairs(strategies[i]) do
                if k ~= "name" then compiled[k] = v end
            end
            strategies[i] = compiled
            break
        end
    end
end

-- ============================================================================
-- REGISTRATION
-- ============================================================================
if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("kebab", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warrior Kebab (DW Arms) rotation registered") end
return { strategies = strategies, build_state = build_state }
