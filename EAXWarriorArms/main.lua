-- Eax Warrior Arms  main.lua
--  Arms rotation with Slam weaving, Overpower on dodge, stance dancing.

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

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_spell_cd = core.spell_book.get_spell_cooldown

-- Constants
local MORTAL_STRIKE_COST = 30
local WHIRLWIND_COST = 25
local SLAM_COST = 15
local HEROIC_STRIKE_COST = 15
local CLEAVE_COST = 20
local OVERPOWER_COST = 5
local REND_COST = 10
local EXECUTE_MIN_RAGE = 15
local EXECUTE_HP_THRESHOLD = 20
local STANCE_BUFFER_RAGE = 5
local ARMS_AOE_RADIUS = 8
local REND_REFRESH_MS = 4000
local SLAM_NOW_WINDOW_MS = 350
local SLAM_HOLD_REGION_MS = 250
local SLAM_SAFE_BUFFER_MS = 100
local FILLER_HOLD_WINDOW = 2.0

local runtime = {
    mortal_strike_id = nil,
    slam_id = nil,
    whirlwind_id = nil,
    execute_id = nil,
    heroic_strike_id = nil,
    cleave_id = nil,
    overpower_id = nil,
    rend_id = nil,
    thunder_clap_id = nil,
    battle_shout_id = nil,
    commanding_shout_id = nil,
    demoralizing_shout_id = nil,
    sunder_armor_id = nil,
    hamstring_id = nil,
    battle_stance_id = nil,
    berserker_stance_id = nil,
    defensive_stance_id = nil,
    charge_id = nil,
    intercept_id = nil,
    death_wish_id = nil,
    recklessness_id = nil,
    berserker_rage_id = nil,
    sweeping_strikes_id = nil,
    stance_swap_retention = 10,
    ww_pending_return = false,
    pending_battle_stance_return = false,
    pending_recklessness_berserker = false,
    prev_toggle_state = false,
}

local RUNTIME_SPELL_SPECS = {
    { field = "mortal_strike_id", ranks = spells.MORTAL_STRIKE },
    { field = "slam_id", ranks = spells.SLAM },
    { field = "whirlwind_id", ranks = spells.WHIRLWIND },
    { field = "execute_id", ranks = spells.EXECUTE },
    { field = "heroic_strike_id", ranks = spells.HEROIC_STRIKE },
    { field = "cleave_id", ranks = spells.CLEAVE },
    { field = "overpower_id", ranks = spells.OVERPOWER },
    { field = "rend_id", ranks = spells.REND },
    { field = "thunder_clap_id", ranks = spells.THUNDER_CLAP },
    { field = "battle_shout_id", ranks = spells.BATTLE_SHOUT },
    { field = "commanding_shout_id", ranks = spells.COMMANDING_SHOUT },
    { field = "demoralizing_shout_id", ranks = spells.DEMORALIZING_SHOUT },
    { field = "sunder_armor_id", ranks = spells.SUNDER_ARMOR },
    { field = "hamstring_id", ranks = spells.HAMSTRING },
    { field = "battle_stance_id", ranks = spells.BATTLE_STANCE },
    { field = "berserker_stance_id", ranks = spells.BERSERKER_STANCE },
    { field = "defensive_stance_id", ranks = spells.DEFENSIVE_STANCE },
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

local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function find_valid_target(me)
    return utils.find_best_target(me)
end

local function get_rage(me)
    return utils.get_rage(me)
end

local function count_nearby_enemies(me)
    return utils.enemy_count_in_radius(me, ARMS_AOE_RADIUS)
end

-- : Check if we should pool for core abilities
local function should_pool_for_core(rage, ms_cd, ww_cd)
    if ms_cd > 0 and ms_cd <= FILLER_HOLD_WINDOW then
        if (rage - SLAM_COST) < MORTAL_STRIKE_COST then return true end
    end
    if ww_cd > 0 and ww_cd <= FILLER_HOLD_WINDOW then
        if (rage - SLAM_COST) < WHIRLWIND_COST then return true end
    end
    return false
end

-- : Smart Overpower evaluation
local function should_use_overpower(me, target, rage, ms_cd, ww_cd, target_hp_pct)
    return utils.should_use_overpower_smart(me, target, rage, ms_cd, ww_cd, target_hp_pct)
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

local function try_thunder_clap(me, target)
    if not menu.use_thunder_clap:get_state() or not target or not runtime.thunder_clap_id then return false end
    if menu.pvp_cc_break_check:get_state() and utils.has_breakable_cc_nearby(me, 10) then return false end
    if not utils.is_melee_target(me, target) then return false end
    local remaining_ms = utils.get_debuff_remaining_ms(target, spells.DEBUFF_THUNDER_CLAP)
    if remaining_ms > 2000 then return false end
    local nearby = count_nearby_enemies(me)
    if nearby < 1 then return false end
    if utils.cast_self(runtime.thunder_clap_id, me) then
        utils.log_debug(menu, "Thunder Clap")
        return true
    end
    return false
end

local function try_rend(me, target, rage, target_hp_pct)
    if not menu.use_rend:get_state() or not target or not runtime.rend_id then return false end
    if target_hp_pct <= EXECUTE_HP_THRESHOLD then return false end
    if utils.get_current_stance(me) ~= "battle" then return false end
    if not utils.is_melee_target(me, target) then return false end
    local rend_remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_REND)
    if rend_remaining > REND_REFRESH_MS then return false end
    local ms_cd = runtime.mortal_strike_id and _get_spell_cd(runtime.mortal_strike_id) or math.huge
    if ms_cd <= 1.5 and rage < (MORTAL_STRIKE_COST + REND_COST) then return false end
    if utils.can_cast_melee(runtime.rend_id, me) and utils.cast_target(runtime.rend_id, target) then
        utils.log_debug(menu, rend_remaining > 0 and "Rend refresh" or "Rend")
        return true
    end
    return false
end

local function try_overpower(me, target, rage, target_hp_pct)
    if not menu.use_overpower:get_state() or not target or not runtime.overpower_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    if not core.spell_book.is_usable_spell(runtime.overpower_id) then return false end
    local ms_cd = runtime.mortal_strike_id and _get_spell_cd(runtime.mortal_strike_id) or math.huge
    local ww_cd = runtime.whirlwind_id and _get_spell_cd(runtime.whirlwind_id) or math.huge
    if not should_use_overpower(me, target, rage, ms_cd, ww_cd, target_hp_pct) then return false end
    if utils.get_current_stance(me) ~= "battle" then
        if runtime.battle_stance_id and utils.can_cast_self(runtime.battle_stance_id, me) then
            utils.cast_self(runtime.battle_stance_id, me)
            utils.set_tracked_stance("battle")
            utils.log_debug(menu, "Stance -> Battle (Overpower)")
            return true
        end
        return false
    end
    if utils.cast_target(runtime.overpower_id, target) then
        utils.log_debug(menu, "Overpower")
        return true
    end
    return false
end

local function try_mortal_strike(me, target, rage, target_hp_pct)
    if not menu.use_mortal_strike:get_state() or not target or not runtime.mortal_strike_id then return false end
    if target_hp_pct <= EXECUTE_HP_THRESHOLD and not menu.execute_use_ms:get_state() then return false end
    if not utils.is_melee_target(me, target) then return false end
    if utils.is_spell_already_queued(runtime.mortal_strike_id) then return false end
    if utils.get_current_stance(me) ~= "battle" then
        if runtime.battle_stance_id and utils.can_stance_dance_for_cost(rage, MORTAL_STRIKE_COST, 0, runtime.stance_swap_retention) then
            if utils.can_cast_self(runtime.battle_stance_id, me) then
                utils.cast_self(runtime.battle_stance_id, me)
                utils.set_tracked_stance("battle")
                utils.log_debug(menu, "Stance -> Battle (MS)")
                return true
            end
        end
    end
    if utils.cast_target(runtime.mortal_strike_id, target) then
        utils.log_debug(menu, "Mortal Strike")
        return true
    end
    return false
end

local function try_whirlwind(me, target, rage, target_hp_pct)
    if not menu.use_whirlwind:get_state() or not target or not runtime.whirlwind_id then return false end
    if menu.pvp_cc_break_check:get_state() and utils.has_breakable_cc_nearby(me, 10) then return false end
    if target_hp_pct <= EXECUTE_HP_THRESHOLD and not menu.execute_use_ww:get_state() then return false end
    if not utils.is_melee_target(me, target) then return false end
    if count_nearby_enemies(me) < 2 then return false end
    if rage < WHIRLWIND_COST then return false end
    local current_stance = utils.get_current_stance(me)
    if current_stance ~= "berserker" then
        if utils.can_stance_dance_for_cost(rage, WHIRLWIND_COST, STANCE_BUFFER_RAGE, runtime.stance_swap_retention) then
            if runtime.berserker_stance_id and utils.can_cast_self(runtime.berserker_stance_id, me) then
                utils.cast_self(runtime.berserker_stance_id, me)
                utils.set_tracked_stance("berserker")
                utils.log_debug(menu, "Stance -> Berserker (WW)")
                return true
            end
        end
        return false
    end
    if utils.cast_target(runtime.whirlwind_id, target) then
        runtime.ww_pending_return = true
        utils.log_debug(menu, "Whirlwind")
        return true
    end
    return false
end

local function try_return_to_battle(me)
    if not runtime.ww_pending_return or not runtime.battle_stance_id then return false end
    if utils.get_current_stance(me) == "battle" then
        runtime.ww_pending_return = false
        return false
    end
    if utils.can_cast_self(runtime.battle_stance_id, me) and utils.cast_self(runtime.battle_stance_id, me) then
        runtime.ww_pending_return = false
        utils.set_tracked_stance("battle")
        utils.log_debug(menu, "Stance -> Battle (return)")
        return true
    end
    return false
end

local function try_slam(me, target, rage, target_hp_pct)
    if not menu.use_slam:get_state() or not target or not runtime.slam_id then return false end
    if target_hp_pct <= EXECUTE_HP_THRESHOLD then return false end
    if not utils.is_melee_target(me, target) then return false end
    local ms_cd = runtime.mortal_strike_id and _get_spell_cd(runtime.mortal_strike_id) or math.huge
    local ww_cd = runtime.whirlwind_id and _get_spell_cd(runtime.whirlwind_id) or math.huge
    if should_pool_for_core(rage, ms_cd, ww_cd) then return false end
    local safety_buffer_ms = menu.slam_safety_buffer_ms:get() or SLAM_SAFE_BUFFER_MS
    if not utils.can_slam_without_clipping(me, runtime.slam_id, safety_buffer_ms) then return false end
    if utils.cast_target(runtime.slam_id, target) then
        utils.log_debug(menu, "Slam")
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

local function try_heroic_strike(me, target, rage, target_hp_pct)
    if not utils.is_melee_target(me, target) then return false end
    if target_hp_pct <= EXECUTE_HP_THRESHOLD and not menu.execute_use_hs:get_state() then return false end
    if utils.is_spell_already_queued(runtime.heroic_strike_id or runtime.cleave_id) then return false end
    local nearby = count_nearby_enemies(me)
    local use_cleave = nearby >= 2 and runtime.cleave_id
    local dump_id = use_cleave and runtime.cleave_id or runtime.heroic_strike_id
    if not dump_id then return false end
    local dump_cost = use_cleave and CLEAVE_COST or HEROIC_STRIKE_COST
    local threshold = menu.hs_rage_threshold:get()
    if menu.hs_trick:get_state() then
        threshold = 30
    end
    if rage < (threshold + dump_cost) then return false end
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
    local in_berserker = utils.get_current_stance(me) == "berserker"
    if not in_berserker and not runtime.pending_recklessness_berserker then
        local rage = get_rage(me)
        if not utils.can_stance_dance_for_cost(rage, 0, 0, runtime.stance_swap_retention) then return false end
        if runtime.berserker_stance_id and utils.can_cast_self(runtime.berserker_stance_id, me) then
            utils.cast_self(runtime.berserker_stance_id, me)
            utils.set_tracked_stance("berserker")
            utils.log_debug(menu, "Stance -> Berserker (Recklessness)")
            runtime.pending_recklessness_berserker = true
            return true
        end
        return false
    end
    if not in_berserker and runtime.pending_recklessness_berserker then return false end
    if not utils.can_cast_self(runtime.recklessness_id, me) then return false end
    if utils.cast_self_fast(runtime.recklessness_id, me) then
        utils.log_debug(menu, "Recklessness")
        runtime.pending_battle_stance_return = true
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
    local target = find_valid_target(me)
    if not target then return end
    local target_hp_pct = target:get_health_percentage()
    local rage = get_rage(me)
    utils.ensure_melee_auto_attack(me, target)
    if try_charge(me, target) then return end
    if try_cancelaura_buffs(me) then return end
    if try_return_to_battle(me) then return end
    if runtime.pending_battle_stance_return and runtime.battle_stance_id then
        if utils.can_cast_self(runtime.battle_stance_id, me) then
            utils.cast_self(runtime.battle_stance_id, me)
            runtime.pending_battle_stance_return = false
            utils.set_tracked_stance("battle")
            utils.log_debug(menu, "Stance -> Battle (after Recklessness)")
        end
    end
    if target and interrupt_manager.should_interrupt(target) then
        if menu.use_interrupt:get_state() then
            if interrupt_manager.try_interrupt(me, target, "warrior", utils) then return end
        end
    end
    if racial_manager.try_offensive(me) then return end
    if try_battle_shout(me) then return end
    if try_demo_shout(me, target) then return end
    if try_thunder_clap(me, target) then return end
    if try_death_wish(me) then return end
    if try_berserker_rage(me) then return end
    if try_recklessness(me) then return end
    if try_sweeping_strikes(me) then return end
    if try_execute(me, target, rage, target_hp_pct) then return end
    if try_overpower(me, target, rage, target_hp_pct) then return end
    if try_rend(me, target, rage, target_hp_pct) then return end
    if try_mortal_strike(me, target, rage, target_hp_pct) then return end
    if try_whirlwind(me, target, rage, target_hp_pct) then return end
    if try_slam(me, target, rage, target_hp_pct) then return end
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
-- ============================================================================
-- RENDER CALLBACKS - Menu Registration
-- ============================================================================

-- Register render callbacks for menu system
core.register_on_render_callback(function()
    if menu and menu.on_render then
        local ok, err = pcall(menu.on_render)
        if not ok then
            core.log_error(string.format("[EAX Arms] Render error: %s", tostring(err)))
        end
    end
end)

core.register_on_render_menu_callback(function()
    if menu and menu.on_menu_render then
        local ok, err = pcall(menu.on_menu_menu_render)
        if not ok then
            core.log_error(string.format("[EAX Arms] Menu render error: %s", tostring(err)))
        end
    end
end)
core.register_on_render_control_panel_callback(on_control_panel)

-- Export toggle settings for external access
local NS = _G.EAXWarriorArms and _G.EAXWarriorArms.NS or {}
_G.EAXWarriorArms = _G.EAXWarriorArms or {}
_G.EAXWarriorArms.NS = NS
NS.toggle_menu = menu.toggle_menu