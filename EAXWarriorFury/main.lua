-- Eax Warrior Fury  main.lua
--  Fury rotation with Bloodthirst spam, Rampage maintenance, Flurry tracking.

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type auto_attack_helper
local auto_attack = require("common/utility/auto_attack_helper")
---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type racial_manager
local racial_manager = require("libraries/racial_manager")

-- AstroUI launcher
local AstroUI = require("ext_lib_astro_ui/main")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_spell_cd = core.spell_book.get_spell_cooldown

-- Constants
local BLOODTHIRST_COST = 30
local WHIRLWIND_COST = 25
local SLAM_COST = 15
local HEROIC_STRIKE_COST = 15
local CLEAVE_COST = 20
local HAMSTRING_COST = 10
local EXECUTE_MIN_RAGE = 25
local EXECUTE_HP_THRESHOLD = 20
local STANCE_BUFFER_RAGE = 5
local FURY_AOE_RADIUS = 8
local FILLER_HOLD_WINDOW = 2.0
local RAMPAGE_MAX_STACKS = 5

local runtime = {
    bloodthirst_id = nil,
    whirlwind_id = nil,
    execute_id = nil,
    heroic_strike_id = nil,
    cleave_id = nil,
    rampage_id = nil,
    hamstring_id = nil,
    battle_shout_id = nil,
    commanding_shout_id = nil,
    demoralizing_shout_id = nil,
    sunder_armor_id = nil,
    berserker_stance_id = nil,
    battle_stance_id = nil,
    charge_id = nil,
    intercept_id = nil,
    death_wish_id = nil,
    recklessness_id = nil,
    berserker_rage_id = nil,
    sweeping_strikes_id = nil,
    stance_swap_retention = 10,
    prev_toggle_state = false,
}

local RUNTIME_SPELL_SPECS = {
    { field = "bloodthirst_id", ranks = spells.BLOODTHIRST },
    { field = "whirlwind_id", ranks = spells.WHIRLWIND },
    { field = "execute_id", ranks = spells.EXECUTE },
    { field = "heroic_strike_id", ranks = spells.HEROIC_STRIKE },
    { field = "cleave_id", ranks = spells.CLEAVE },
    { field = "rampage_id", ranks = spells.RAMPAGE },
    { field = "hamstring_id", ranks = spells.HAMSTRING },
    { field = "battle_shout_id", ranks = spells.BATTLE_SHOUT },
    { field = "commanding_shout_id", ranks = spells.COMMANDING_SHOUT },
    { field = "demoralizing_shout_id", ranks = spells.DEMORALIZING_SHOUT },
    { field = "sunder_armor_id", ranks = spells.SUNDER_ARMOR },
    { field = "berserker_stance_id", ranks = spells.BERSERKER_STANCE },
    { field = "battle_stance_id", ranks = spells.BATTLE_STANCE },
    { field = "charge_id", ranks = spells.CHARGE },
    { field = "intercept_id", ranks = spells.INTERCEPT },
    { field = "death_wish_id", ranks = spells.DEATH_WISH },
    { field = "recklessness_id", ranks = spells.RECKLESSNESS },
    { field = "berserker_rage_id", ranks = spells.BERSERKER_RAGE },
    { field = "sweeping_strikes_id", ranks = spells.SWEEPING_STRIKES },
}

local function resolve_spells()
    for i = 1, #RUNTIME_SPELL_SPECS do
        local spec = RUNTIME_SPELL_SPECS[i]
        runtime[spec.field] = utils.resolve_spell_id(spec.ranks)
    end
    runtime.stance_swap_retention = utils.get_stance_swap_retention()
end

local function get_rage(me)
    return utils.get_rage(me)
end

local function count_nearby_enemies(me)
    return utils.enemy_count_in_radius(me, FURY_AOE_RADIUS)
end

-- : Resource pooling for Bloodthirst
local function should_pool_for_bloodthirst(rage, bt_cd, ww_cd)
    if bt_cd > 0 and bt_cd <= FILLER_HOLD_WINDOW then
        if (rage - SLAM_COST) < BLOODTHIRST_COST then return true end
    end
    if ww_cd > 0 and ww_cd <= FILLER_HOLD_WINDOW then
        if (rage - SLAM_COST) < WHIRLWIND_COST then return true end
    end
    return false
end

-- : Rampage maintenance
local function should_use_rampage(me)
    if not menu.use_rampage:get_state() then return false end
    local threshold_sec = menu.rampage_refresh_threshold:get()
    return utils.should_maintain_rampage(me, threshold_sec)
end

local function try_battle_shout(me)
    if not menu.use_battle_shout:get_state() then return false end
    local shout_id = runtime.battle_shout_id
    local buff_table = spells.BUFF_BATTLE_SHOUT
    if menu.use_commanding_shout:get_state() and runtime.commanding_shout_id then
        shout_id = runtime.commanding_shout_id
        buff_table = spells.BUFF_COMMANDING_SHOUT
    end
    if not shout_id or utils.has_buff(me, buff_table) then return false end
    if utils.cast_self(shout_id, me) then
        utils.log_debug(menu, "Refreshing shout")
        return true
    end
    return false
end

local function try_cancelaura_buffs(me)
    if not me:is_in_combat() then return false end
    local hp_pct = me:get_health_percentage()
    local threshold = menu.cancelaura_hp_threshold:get()
    if menu.cancel_pws:get_state() then
        if me:has_buff(17) then
            local rage = get_rage(me)
            if rage < 30 and hp_pct > threshold then
                local ok = pcall(function() core.input.cancel_aura("Power Word: Shield") end)
                if ok then utils.log_debug(menu, "Cancelaura: PW:S"); return true end
            end
        end
    end
    if menu.cancel_bop:get_state() then
        if me:has_buff(1022) then
            if hp_pct > threshold then
                local ok = pcall(function() core.input.cancel_aura("Blessing of Protection") end)
                if ok then utils.log_debug(menu, "Cancelaura: BoP"); return true end
            end
        end
    end
    return false
end

local function try_demo_shout(me, target)
    if not menu.use_demo_shout:get_state() or not target or not runtime.demoralizing_shout_id then return false end
    if menu.pvp_cc_break_check:get_state() and utils.has_breakable_cc_nearby(me, 10) then return false end
    if not utils.is_melee_target(me, target) then return false end
    if utils.has_debuff(target, spells.DEBUFF_DEMORALIZING_SHOUT) then return false end
    if utils.cast_self(runtime.demoralizing_shout_id, me) then
        utils.log_debug(menu, "Demoralizing Shout")
        return true
    end
    return false
end

local function try_rampage(me)
    if not menu.use_rampage:get_state() or not runtime.rampage_id then return false end
    if not should_use_rampage(me) then return false end
    if not utils.can_cast_self(runtime.rampage_id, me) then return false end
    if utils.cast_self(runtime.rampage_id, me) then
        utils.log_debug(menu, "Rampage")
        return true
    end
    return false
end

local function try_bloodthirst(me, target, rage, target_hp_pct)
    if not menu.use_bloodthirst:get_state() or not target or not runtime.bloodthirst_id then return false end
    if target_hp_pct <= EXECUTE_HP_THRESHOLD and not menu.execute_use_bt:get_state() then return false end
    if not utils.is_melee_target(me, target) then return false end
    -- : WW priority check
    local ww_prio_count = menu.ww_prio_count:get()
    if ww_prio_count > 0 and count_nearby_enemies(me) >= ww_prio_count then
        local ww_cd = runtime.whirlwind_id and _get_spell_cd(runtime.whirlwind_id) or math.huge
        if ww_cd <= 0 and rage >= WHIRLWIND_COST then return false end
    end
    if utils.cast_target(runtime.bloodthirst_id, target) then
        utils.log_debug(menu, "Bloodthirst")
        return true
    end
    return false
end

local function try_whirlwind(me, target, rage, target_hp_pct)
    if not menu.use_whirlwind:get_state() or not target or not runtime.whirlwind_id then return false end
    if menu.pvp_cc_break_check:get_state() and utils.has_breakable_cc_nearby(me, 10) then return false end
    if target_hp_pct <= EXECUTE_HP_THRESHOLD and not menu.execute_use_ww:get_state() then return false end
    if not utils.is_melee_target(me, target) then return false end
    if rage < WHIRLWIND_COST then return false end
    if utils.get_current_stance(me) ~= "berserker" then return false end
    if utils.cast_target(runtime.whirlwind_id, target) then
        utils.log_debug(menu, "Whirlwind")
        return true
    end
    return false
end

local function try_execute(me, target, rage, target_hp_pct)
    if not menu.use_execute:get_state() or not target or not runtime.execute_id then return false end
    if target_hp_pct > EXECUTE_HP_THRESHOLD then return false end
    if rage < EXECUTE_MIN_RAGE then return false end
    if utils.cast_target(runtime.execute_id, target) then
        utils.log_debug(menu, "Execute")
        return true
    end
    return false
end

local function try_slam(me, target, rage, target_hp_pct)
    if not menu.use_slam:get_state() or not target or not runtime.slam_id then return false end
    if target_hp_pct <= EXECUTE_HP_THRESHOLD then return false end
    if not utils.is_melee_target(me, target) then return false end
    local bt_cd = runtime.bloodthirst_id and _get_spell_cd(runtime.bloodthirst_id) or math.huge
    local ww_cd = runtime.whirlwind_id and _get_spell_cd(runtime.whirlwind_id) or math.huge
    if should_pool_for_bloodthirst(rage, bt_cd, ww_cd) then return false end
    if not utils.can_slam_without_clipping(me, runtime.slam_id, 100) then return false end
    if utils.cast_target(runtime.slam_id, target) then
        utils.log_debug(menu, "Slam")
        return true
    end
    return false
end

local function try_hamstring(me, target, rage)
    if not menu.use_hamstring:get_state() or not target or not runtime.hamstring_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    if rage < 50 then return false end
    if utils.cast_target(runtime.hamstring_id, target) then
        utils.log_debug(menu, "Hamstring")
        return true
    end
    return false
end

local function try_heroic_strike(me, target, rage, target_hp_pct)
    if not menu.use_heroic_strike:get_state() or not utils.is_melee_target(me, target) then return false end
    if target_hp_pct <= EXECUTE_HP_THRESHOLD and not menu.execute_use_hs:get_state() then return false end
    if utils.is_spell_already_queued(runtime.heroic_strike_id or runtime.cleave_id) then return false end
    local nearby = count_nearby_enemies(me)
    local use_cleave = nearby >= 2 and runtime.cleave_id
    local dump_id = use_cleave and runtime.cleave_id or runtime.heroic_strike_id
    if not dump_id then return false end
    local threshold = menu.hs_rage_threshold:get()
    if menu.hs_trick:get_state() then
        threshold = 30
    end
    if rage < threshold then return false end
    if utils.can_cast_melee(dump_id, me) and utils.cast_target_fast(dump_id, target) then
        utils.log_debug(menu, use_cleave and "Cleave" or "Heroic Strike")
        return true
    end
    return false
end

local function try_charge(me, target)
    if not runtime.charge_id then return false end
    if me:is_in_combat() then return false end
    if not utils.can_cast_hostile(runtime.charge_id, me, target) then return false end
    if utils.cast_target_fast(runtime.charge_id, target) then
        utils.log_debug(menu, "Charge")
        return true
    end
    return false
end

local function try_death_wish(me)
    if not menu.use_death_wish:get_state() or not runtime.death_wish_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_DEATH_WISH) then return false end
    if not utils.can_cast_self(runtime.death_wish_id, me) then return false end
    if utils.cast_self_fast(runtime.death_wish_id, me) then
        utils.log_debug(menu, "Death Wish")
        return true
    end
    return false
end

local function try_berserker_rage(me)
    if not menu.use_berserker_rage:get_state() or not runtime.berserker_rage_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_BERSERKER_RAGE) then return false end
    if utils.get_current_stance(me) ~= "berserker" then return false end
    if not utils.can_cast_self(runtime.berserker_rage_id, me) then return false end
    if utils.cast_self_fast(runtime.berserker_rage_id, me) then
        utils.log_debug(menu, "Berserker Rage")
        return true
    end
    return false
end

local function try_recklessness(me)
    if not menu.use_recklessness:get_state() or not runtime.recklessness_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_RECKLESSNESS) then return false end
    if utils.get_current_stance(me) ~= "berserker" then return false end
    if not utils.can_cast_self(runtime.recklessness_id, me) then return false end
    if utils.cast_self_fast(runtime.recklessness_id, me) then
        utils.log_debug(menu, "Recklessness")
        return true
    end
    return false
end

local function try_sweeping_strikes(me)
    if not menu.use_sweeping_strikes:get_state() or not runtime.sweeping_strikes_id then return false end
    if utils.has_buff(me, spells.BUFF_SWEEPING_STRIKES) then return false end
    if count_nearby_enemies(me) < 2 then return false end
    if not utils.can_cast_self(runtime.sweeping_strikes_id, me) then return false end
    if utils.cast_self_fast(runtime.sweeping_strikes_id, me) then
        utils.log_debug(menu, "Sweeping Strikes")
        return true
    end
    return false
end

local function on_update()
    if not menu.is_enabled() then return end
    local me = _get_local_player()
    if not me or not me:is_valid() then return end
    resolve_spells()
    local target = utils.find_best_target(me)
    if not target then return end
    local target_hp_pct = target:get_health_percentage()
    local rage = get_rage(me)
    utils.ensure_melee_auto_attack(me, target)
    if try_charge(me, target) then return end
    if try_cancelaura_buffs(me) then return end
    if target and interrupt_manager.should_interrupt(target) then
        if menu.use_interrupt:get_state() then
            if interrupt_manager.try_interrupt(me, target, "warrior", utils) then return end
        end
    end
    if racial_manager.try_offensive(me) then return end
    if try_battle_shout(me) then return end
    if try_demo_shout(me, target) then return end
    if try_death_wish(me) then return end
    if try_berserker_rage(me) then return end
    if try_recklessness(me) then return end
    if try_sweeping_strikes(me) then return end
    if try_rampage(me) then return end
    if try_bloodthirst(me, target, rage, target_hp_pct) then return end
    if try_whirlwind(me, target, rage, target_hp_pct) then return end
    if try_execute(me, target, rage, target_hp_pct) then return end
    if try_slam(me, target, rage, target_hp_pct) then return end
    if try_hamstring(me, target, rage) then return end
    if try_heroic_strike(me, target, rage, target_hp_pct) then return end
end

local function on_control_panel()
    local elements = {}
    local toggle_key_code = menu.toggle_key:get_key_code()
    local display_name = "[EAX] Enable"
    table.insert(elements, {
        type = "checkbox",
        id = "enabled",
        label = display_name,
        value = menu.enabled:get_state(),
        on_change = function(new_val) menu.enabled:set(new_val) end,
    })
    table.insert(elements, {
        type = "keybind",
        id = "toggle_key",
        label = "Toggle Key",
        value = toggle_key_code,
        on_change = function(new_val) menu.toggle_key:set_key_code(new_val) end,
    })
    return elements
end

resolve_spells()

core.register_on_update_callback(on_update)
core.register_on_render_callback(menu.on_render)
core.register_on_render_menu_callback(menu.on_menu_render)
core.register_on_render_control_panel_callback(on_control_panel)

-- Export toggle settings for external access
local NS = _G.EAXWarriorFury and _G.EAXWarriorFury.NS or {}
_G.EAXWarriorFury = _G.EAXWarriorFury or {}
_G.EAXWarriorFury.NS = NS
NS.toggle_menu = menu.toggle_menu

