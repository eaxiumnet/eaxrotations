-- EAX Warrior Arms | main.lua
-- Minimal Arms rotation helper that prioritizes Overpower, Mortal Strike, Slam weaving,
-- Whirlwind stance dancing, and Execute while supporting Auto/Solo/Dungeon/Raid modes.

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type interrupt_manager
local interrupt_manager = require("common/eax_shared/interrupt_manager")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local MODE_REFRESH_INTERVAL_S = 5
local MISSING_SPELL_REFRESH_INTERVAL_S = 1.0
local MORTAL_STRIKE_COST = 30
local WHIRLWIND_COST = 25
local SLAM_COST = 15
local EXECUTE_MIN_RAGE = 15
local EXECUTE_HP_THRESHOLD = 0.20
local STANCE_BUFFER_RAGE = 5

local runtime = {
    mortal_strike_id = nil,
    slam_id = nil,
    whirlwind_id = nil,
    execute_id = nil,
    overpower_id = nil,
    battle_shout_id = nil,
    commanding_shout_id = nil,
    demoralizing_shout_id = nil,
    sunder_armor_id = nil,
    hamstring_id = nil,
    battle_stance_id = nil,
    berserker_stance_id = nil,
    stance_swap_retention = 10,
    cached_mode = "solo",
    mode_cache_refreshed_at = 0,
    last_spell_refresh_at = 0,
    ww_pending_return = false,
    prev_toggle_state = false,
}

local RUNTIME_SPELL_SPECS = {
    { field = "mortal_strike_id", ranks = spells.MORTAL_STRIKE },
    { field = "slam_id", ranks = spells.SLAM },
    { field = "whirlwind_id", ranks = spells.WHIRLWIND },
    { field = "execute_id", ranks = spells.EXECUTE },
    { field = "overpower_id", ranks = spells.OVERPOWER },
    { field = "battle_shout_id", ranks = spells.BATTLE_SHOUT },
    { field = "commanding_shout_id", ranks = spells.COMMANDING_SHOUT },
    { field = "demoralizing_shout_id", ranks = spells.DEMORALIZING_SHOUT },
    { field = "sunder_armor_id", ranks = spells.SUNDER_ARMOR },
    { field = "hamstring_id", ranks = spells.HAMSTRING },
    { field = "battle_stance_id", ranks = spells.BATTLE_STANCE },
    { field = "berserker_stance_id", ranks = spells.BERSERKER_STANCE },
}

local function resolve_spells()
    for i = 1, #RUNTIME_SPELL_SPECS do
        local spec = RUNTIME_SPELL_SPECS[i]
        runtime[spec.field] = utils.resolve_spell_id(spec.ranks)
    end
    runtime.stance_swap_retention = utils.get_stance_swap_retention()
end

local function has_missing_runtime_spell_ids()
    for i = 1, #RUNTIME_SPELL_SPECS do
        if not runtime[RUNTIME_SPELL_SPECS[i].field] then
            return true
        end
    end
    return false
end

local function refresh_missing_runtime_spell_ids()
    local now = core.time()
    if (now - runtime.last_spell_refresh_at) < MISSING_SPELL_REFRESH_INTERVAL_S then
        return
    end
    runtime.last_spell_refresh_at = now
    if has_missing_runtime_spell_ids() then
        resolve_spells()
    end
end

local function detect_mode()
    local objects = core.object_manager.get_visible_objects()
    local party_count = 0
    for i = 1, #objects do
        local obj = objects[i]
        if obj
            and obj:is_valid()
            and obj:is_unit()
            and not obj:is_dead()
            and obj:is_party_member()
        then
            party_count = party_count + 1
        end
    end
    if party_count == 0 then
        return "solo"
    elseif party_count <= 4 then
        return "dungeon"
    end
    return "raid"
end

local function refresh_mode_cache()
    local now = core.time()
    if (now - runtime.mode_cache_refreshed_at) < MODE_REFRESH_INTERVAL_S and runtime.cached_mode then
        return
    end
    runtime.cached_mode = detect_mode()
    runtime.mode_cache_refreshed_at = now
end

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 2 then return "solo" end
    if idx == 3 then return "dungeon" end
    if idx == 4 then return "raid" end
    return runtime.cached_mode or "solo"
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        local next_state = not menu.enabled:get_state()
        menu.enabled:set(next_state)
        utils.log_debug(menu, "Toggle -> " .. tostring(next_state))
    end
    runtime.prev_toggle_state = current
end

local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function find_valid_target(me)
    local target = me:get_target()
    if is_valid_hostile_target(me, target) then
        return target
    end

    local objects = core.object_manager.get_visible_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if is_valid_hostile_target(me, obj) then
            return obj
        end
    end

    return nil
end

local function get_debuff_stack(target, id_table)
    if not target or not id_table then
        return 0
    end
    local data = target:get_debuff_data(id_table)
    if data and data.is_active then
        return data.count or 0
    end
    return 0
end

local function try_battle_shout(me)
    if not menu.use_battle_shout:get_state() then
        return false
    end

    local shout_id = runtime.battle_shout_id
    local buff_table = spells.BUFF_BATTLE_SHOUT
    if menu.use_commanding_shout:get_state() and runtime.commanding_shout_id then
        shout_id = runtime.commanding_shout_id
        buff_table = spells.BUFF_COMMANDING_SHOUT
    end

    if not shout_id or utils.has_buff(me, buff_table) then
        return false
    end

    if utils.cast_self(shout_id, me) then
        utils.log_debug(menu, "Refreshing shout")
        return true
    end

    return false
end

local function try_demo_shout(me, target)
    if not menu.use_demo_shout:get_state() or not target or not runtime.demoralizing_shout_id then
        return false
    end

    if not utils.is_melee_target(me, target) then
        return false
    end

    if utils.has_debuff(target, spells.DEBUFF_DEMORALIZING_SHOUT) then
        return false
    end

    if utils.cast_self(runtime.demoralizing_shout_id, me) then
        utils.log_debug(menu, "Demoralizing Shout")
        return true
    end

    return false
end

local function try_sunder(me, target, target_hp_pct)
    if not menu.use_sunder_armor:get_state()
        or not target
        or target_hp_pct <= EXECUTE_HP_THRESHOLD
        or not runtime.sunder_armor_id
    then
        return false
    end

    if not utils.is_melee_target(me, target) then
        return false
    end

    local stacks = get_debuff_stack(target, spells.DEBUFF_SUNDER_ARMOR)
    if stacks >= menu.sunder_max_stacks:get() then
        return false
    end

    if utils.cast_target(runtime.sunder_armor_id, me, target) then
        utils.log_debug(menu, "Sunder Armor")
        return true
    end

    return false
end

local function try_hamstring(me, target, target_hp_pct)
    if not menu.use_hamstring:get_state() or not target or target_hp_pct <= EXECUTE_HP_THRESHOLD or not runtime.hamstring_id then
        return false
    end

    if not utils.is_melee_target(me, target) then
        return false
    end

    if utils.cast_target(runtime.hamstring_id, me, target) then
        utils.log_debug(menu, "Hamstring")
        return true
    end

    return false
end

local function try_return_to_battle(me)
    if not runtime.ww_pending_return or not runtime.battle_stance_id then
        return false
    end

    if utils.get_current_stance(me) == "battle" then
        runtime.ww_pending_return = false
        return false
    end

    if utils.can_cast_self(runtime.battle_stance_id, me)
        and utils.cast_self(runtime.battle_stance_id, me)
    then
        runtime.ww_pending_return = false
        utils.set_tracked_stance("battle")
        utils.log_debug(menu, "Stance -> battle (return)")
        return true
    end

    return false
end

local function try_overpower(me, target)
    if not menu.use_overpower:get_state() or not target or not runtime.overpower_id then
        return false
    end

    if not utils.is_melee_target(me, target) then
        return false
    end

    if utils.cast_target(runtime.overpower_id, me, target) then
        utils.log_debug(menu, "Overpower")
        return true
    end

    return false
end

local function try_mortal_strike(me, target, rage)
    if not menu.use_mortal_strike:get_state()
        or not target
        or not runtime.mortal_strike_id
        or rage < MORTAL_STRIKE_COST
    then
        return false
    end

    if utils.is_spell_already_queued(runtime.mortal_strike_id) then
        return false
    end

    if utils.cast_target(runtime.mortal_strike_id, me, target) then
        utils.log_debug(menu, "Mortal Strike")
        return true
    end

    return false
end

local function try_execute(me, target, rage, target_hp_pct)
    if not menu.use_execute:get_state()
        or not target
        or not runtime.execute_id
        or target_hp_pct > EXECUTE_HP_THRESHOLD
        or rage < EXECUTE_MIN_RAGE
    then
        return false
    end

    if utils.cast_target(runtime.execute_id, me, target) then
        utils.log_debug(menu, "Execute")
        return true
    end

    return false
end

local function try_whirlwind(me, target, rage)
    if not menu.use_whirlwind:get_state()
        or not target
        or not runtime.whirlwind_id
        or rage < WHIRLWIND_COST
        or not runtime.berserker_stance_id
    then
        return false
    end

    if not utils.is_melee_target(me, target) then
        return false
    end

    local ms_cd = runtime.mortal_strike_id and core.spell_book.get_spell_cooldown(runtime.mortal_strike_id) or 0
    if ms_cd <= 1.5 then
        return false
    end

    local current_stance = utils.get_current_stance(me)
    if current_stance ~= "berserker" then
        if utils.can_stance_dance_for_cost(rage, WHIRLWIND_COST, STANCE_BUFFER_RAGE, runtime.stance_swap_retention)
            and utils.can_cast_self(runtime.berserker_stance_id, me)
            and utils.cast_self(runtime.berserker_stance_id, me)
        then
            utils.set_tracked_stance("berserker")
            runtime.ww_pending_return = true
            utils.log_debug(menu, "Stance -> berserker (WW)")
            return true
        end
        return false
    end

    if utils.cast_target(runtime.whirlwind_id, me, target) then
        utils.log_debug(menu, "Whirlwind")
        return true
    end

    return false
end

local function try_slam(me, target, rage)
    if not menu.use_slam:get_state()
        or not target
        or not runtime.slam_id
        or rage < SLAM_COST
    then
        return false
    end

    local ms_cd = runtime.mortal_strike_id and core.spell_book.get_spell_cooldown(runtime.mortal_strike_id) or 0
    if ms_cd <= 1.5 then
        return false
    end

    if not utils.can_slam_without_clipping(me, runtime.slam_id, menu.slam_safety_buffer_ms:get()) then
        return false
    end

    if utils.cast_target(runtime.slam_id, me, target) then
        utils.log_debug(menu, "Slam weave")
        return true
    end

    return false
end

local function do_utility_lane(me, target, mode, target_hp_pct)
    -- Interrupt check
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "warrior", utils) then
            return true
        end
    end

    if try_battle_shout(me) then
        return true
    end

    if mode ~= "solo" then
        if try_demo_shout(me, target) then
            return true
        end
        if try_sunder(me, target, target_hp_pct) then
            return true
        end
    else
        if try_hamstring(me, target, target_hp_pct) then
            return true
        end
    end

    return false
end

local function do_core_lane(me, target, rage, target_hp_pct)
    utils.ensure_melee_auto_attack(me, target)

    if try_overpower(me, target) then
        return true
    end

    if try_execute(me, target, rage, target_hp_pct) then
        return true
    end

    if try_mortal_strike(me, target, rage) then
        return true
    end

    if try_whirlwind(me, target, rage) then
        return true
    end

    if try_slam(me, target, rage) then
        return true
    end

    return false
end

local function on_update()
    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end

    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then
        return
    end

    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() then
        core.input.set_target(focus_target)
    end
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_battle_shout(me) then return end
    end

    refresh_missing_runtime_spell_ids()
    refresh_mode_cache()

    if try_return_to_battle(me) then
        return
    end

    local target = find_valid_target(me)
    local target_hp_pct = target and utils.get_health_pct(target) or 1.0
    local rage = utils.get_rage(me)
    local mode = get_effective_mode()

    if do_utility_lane(me, target, mode, target_hp_pct) then
        return
    end

    if target and do_core_lane(me, target, rage, target_hp_pct) then
        return
    end
end

local function cleanup()
end

local function on_control_panel()
    local elements = {}
    
    local toggle_key_code = menu.toggle_key:get_key_code()
    local display_name = "[EAX Warrior Arms] Enable"
    if toggle_key_code ~= 7 then
        display_name = "[EAX Warrior Arms] Enable (" .. key_helper:get_key_name(toggle_key_code) .. ")"
    end
    control_panel_utility:insert_toggle_(elements, display_name, menu.toggle_key)
    
    return elements
end

resolve_spells()
refresh_mode_cache()

core.register_on_update_callback(on_update)
core.register_on_render_menu_callback(menu.render)
core.register_on_render_control_panel_callback(on_control_panel)

return { cleanup = cleanup }
