-- EAX Druid Restoration | main.lua
-- Group-aware healing rotation with Lifebloom, HoT, and cooldown management.

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")
local color     = require("color")

---@type interrupt_manager
local interrupt_manager = require("interrupt_manager")
---@type ooc_manager
local ooc_manager = require("ooc_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type creature_utils
local creature_utils = require("creature_utils")

---@type encounter_manager
local encounter_manager = require("encounter_manager")


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("resto", "Druid Resto")
---@type racial_manager
local racial_manager = require("racial_manager")
---@type defensive_manager
local defensive_manager = require("defensive_manager")

---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    rebirth_id = nil,
    mark_of_the_wild_id = nil,
    lifebloom_id = nil,
    rejuvenation_id = nil,
    regrowth_id = nil,
    wild_growth_id = nil,
    swiftmend_id = nil,
    innervate_id = nil,
    tranquility_id = nil,
    natures_swiftness_id = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    pending_casts = {},
    set_multiplier = 1.0,
    ooc_mark_of_the_wild_id = nil,
    remove_curse_id = nil,
}

local GROUP_ROLE_TANK = 0
local GCD_CAST_INTERVAL = 1.5  -- TBC GCD
local PENDING_CAST_TIMEOUT_S = 2.5
local FAST_PENDING_CAST_TIMEOUT_S = 0.75

local function resolve_spells()
    runtime.mark_of_the_wild_id = utils.resolve_spell_id(spells.MARK_OF_THE_WILD)
    runtime.lifebloom_id = utils.resolve_spell_id(spells.LIFEBLOOM)
    runtime.rejuvenation_id = utils.resolve_spell_id(spells.REJUVENATION)
    runtime.regrowth_id = utils.resolve_spell_id(spells.REGROWTH)
    runtime.swiftmend_id = utils.resolve_spell_id(spells.SWIFTMEND)
    runtime.innervate_id = utils.resolve_spell_id(spells.INNERVATE)
    runtime.tranquility_id = utils.resolve_spell_id(spells.TRANQUILITY)
    runtime.natures_swiftness_id = utils.resolve_spell_id(spells.NATURES_SWIFTNESS)
    runtime.rebirth_id  = utils.resolve_spell_id(spells.REBIRTH)
    runtime.remove_curse_id = utils.resolve_spell_id(spells.REMOVE_CURSE)
end

local function log_resolved_spells()
    core.log("[EAX Druid Restoration] Resolved: Lifebloom=" .. tostring(runtime.lifebloom_id)
        .. " Rejuvenation=" .. tostring(runtime.rejuvenation_id)
        .. " Regrowth=" .. tostring(runtime.regrowth_id)
        
        .. " Swiftmend=" .. tostring(runtime.swiftmend_id))
end

local function update_set_bonus(me)
    local nordrassil_mult = utils.get_set_multiplier(me, "Nordrassil")
    local nordrassil_harness_mult = utils.get_set_multiplier(me, "NordrassilHarness")
    local malorne_mult = utils.get_set_multiplier(me, "Malorne")
    runtime.set_multiplier = math.max(nordrassil_mult, nordrassil_harness_mult, malorne_mult)
end

resolve_spells()
log_resolved_spells()

local function note_cast()
    runtime.last_cast_time = core.time()
end

local function is_gcd_ready()
    if (core.time() - runtime.last_cast_time) < GCD_CAST_INTERVAL then
        return false
    end
    return core.spell_book.get_global_cooldown() <= 0
end

local function is_pending_cast(spell_id)
    if not spell_id then return false end
    local pending = runtime.pending_casts[spell_id]
    if not pending then return false end
    if (core.time() - pending.requested_at) >= pending.timeout_s then
        runtime.pending_casts[spell_id] = nil
        return false
    end
    return true
end

local function mark_pending_cast(spell_id, timeout_s)
    if not spell_id then return end
    runtime.pending_casts[spell_id] = {
        requested_at = core.time(),
        timeout_s = timeout_s or PENDING_CAST_TIMEOUT_S,
    }
end

local function detect_mode(me)
    local objects = core.object_manager.get_all_objects()
    local party_count = 0

    for i = 1, #objects do
        local obj = objects[i]
        if obj
            and obj:is_valid()
            and obj:is_unit()
            and not obj:is_dead()
            and not utils.same_unit(me, obj)
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

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 2 then return "solo" end
    if idx == 3 then return "dungeon" end
    if idx == 4 then return "raid" end
    return runtime.cached_mode
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        local was_enabled = menu.enabled:get_state()
        menu.enabled:set(not was_enabled)
        utils.log_debug(menu, "Toggle -> " .. tostring(not was_enabled))
    end
    runtime.prev_toggle_state = current
end

local function pick_tank_unit(me, units, mode)
    if mode == "solo" then
        return me
    end

    local best_tank = nil
    local best_health = -1

    for i = 1, #units do
        local unit = units[i]
        local role_id = unit.get_group_role and unit:get_group_role() or -1
        if role_id == GROUP_ROLE_TANK then
            local max_health = unit:get_max_health()
            if max_health > best_health then
                best_tank = unit
                best_health = max_health
            end
        end
    end

    if best_tank then
        return best_tank
    end

    return me
end

local function pick_priority_heal_target(me, tank, lowest, lowest_hp_pct)
    if lowest and lowest_hp_pct <= 0.75 then
        return lowest, lowest_hp_pct
    end

    if tank and tank:is_valid() then
        return tank, utils.get_health_pct(tank)
    end

    return me, utils.get_health_pct(me)
end

local function try_mark_of_the_wild(me)
    if not menu.use_mark_of_the_wild:get_state() then return false end
    if not runtime.mark_of_the_wild_id then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_MARK_OF_THE_WILD) then return false end
    if is_pending_cast(runtime.mark_of_the_wild_id) then return false end
    if not utils.can_cast_self(runtime.mark_of_the_wild_id, me) then return false end

    if utils.cast_self(runtime.mark_of_the_wild_id, me) then
        mark_pending_cast(runtime.mark_of_the_wild_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Mark of the Wild")
        note_cast()
        return true
    end

    return false
end

local function try_innervate(me, mana_pct)
    if not menu.use_innervate:get_state() then return false end
    if not runtime.innervate_id then return false end
    if mana_pct >= (menu.innervate_mana_pct:get() / 100) then return false end
    if utils.has_buff(me, spells.BUFF_INNERVATE) then return false end
    if is_pending_cast(runtime.innervate_id) then return false end
    if not utils.can_cast_self(runtime.innervate_id, me) then return false end

    if utils.cast_self(runtime.innervate_id, me) then
        mark_pending_cast(runtime.innervate_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Innervate")
        note_cast()
        return true
    end

    return false
end

local function try_tranquility(me, injured_count, lowest_hp_pct, mode)
    if not menu.use_tranquility:get_state() then return false end
    if not runtime.tranquility_id then return false end
    if mode == "solo" then return false end
    if injured_count < menu.tranquility_injured_count:get() then return false end
    if lowest_hp_pct > 0.70 then return false end
    if is_pending_cast(runtime.tranquility_id) then return false end
    if not utils.can_cast_self(runtime.tranquility_id, me) then return false end

    if utils.cast_self_fast(runtime.tranquility_id, me) then
        mark_pending_cast(runtime.tranquility_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Tranquility")
        note_cast()
        return true
    end

    return false
end

local function try_wild_growth(me, target, injured_count, mana_pct)
    if not menu.use_wild_growth:get_state() then return false end
    if not runtime.wild_growth_id then return false end
    if injured_count < menu.wild_growth_targets:get() then return false end
    if mana_pct < (menu.wild_growth_mana_pct:get() / 100) then return false end
    if menu.mana_saver:get_state() and mana_pct < 0.50 then return false end
    if is_pending_cast(runtime.wild_growth_id) then return false end
    if not utils.can_cast_unit(runtime.wild_growth_id, me, target) then return false end

    if utils.cast_unit(runtime.wild_growth_id, me, target) then
        mark_pending_cast(runtime.wild_growth_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Wild Growth on " .. (target.get_name and target:get_name() or "target"))
        note_cast()
        return true
    end

    return false
end

local function try_swiftmend(me, target, target_hp_pct)
    if not menu.use_swiftmend:get_state() then return false end
    if not runtime.swiftmend_id then return false end
    if target_hp_pct >= (menu.swiftmend_hp_pct:get() / 100) then return false end

    local has_rejuv = utils.has_buff(target, spells.BUFF_REJUVENATION)
    local has_regrowth = utils.has_buff(target, spells.BUFF_REGROWTH)
    if not has_rejuv and not has_regrowth then return false end
    if is_pending_cast(runtime.swiftmend_id) then return false end
    if not utils.can_cast_unit(runtime.swiftmend_id, me, target) then return false end

    if utils.cast_unit(runtime.swiftmend_id, me, target) then
        mark_pending_cast(runtime.swiftmend_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Swiftmend on " .. (target.get_name and target:get_name() or "target"))
        note_cast()
        return true
    end

    return false
end

local function try_natures_swiftness_regrowth(me, target, target_hp_pct)
    if not menu.use_natures_swiftness:get_state() then return false end
    if not runtime.natures_swiftness_id or not runtime.regrowth_id then return false end
    if target_hp_pct > (menu.emergency_hp_pct:get() / 100) then return false end
    if runtime.swiftmend_id and core.spell_book.get_spell_cooldown(runtime.swiftmend_id) <= 0 then return false end

    if utils.has_buff(me, spells.BUFF_NATURES_SWIFTNESS) then
        if is_pending_cast(runtime.regrowth_id) then return false end
        if not utils.can_cast_unit(runtime.regrowth_id, me, target) then return false end
        if utils.cast_unit(runtime.regrowth_id, me, target) then
            mark_pending_cast(runtime.regrowth_id, PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "Nature's Swiftness -> Regrowth on " .. (target.get_name and target:get_name() or "target"))
            note_cast()
            return true
        end
        return false
    end

    if is_pending_cast(runtime.natures_swiftness_id) then return false end
    if not utils.can_cast_self(runtime.natures_swiftness_id, me) then return false end
    if utils.cast_self_fast(runtime.natures_swiftness_id, me) then
        mark_pending_cast(runtime.natures_swiftness_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Nature's Swiftness")
        note_cast()
        return true
    end

    return false
end

local function try_lifebloom(me, tank)
    if not menu.use_lifebloom:get_state() then return false end
    if not runtime.lifebloom_id or not tank or not tank:is_valid() then return false end
    -- Never cast Lifebloom above 85% HP - it will just bloom and waste mana
    local tank_hp = utils.get_health_pct(tank)
    if tank_hp > 0.85 then return false end

    local stacks = utils.get_buff_stacks(tank, spells.BUFF_LIFEBLOOM)
    local remaining_ms = utils.get_buff_remaining_ms(tank, spells.BUFF_LIFEBLOOM)
    if stacks >= menu.lifebloom_stacks:get() and remaining_ms > (menu.lifebloom_refresh_seconds:get() * 1000) then
        return false
    end
    if is_pending_cast(runtime.lifebloom_id) then return false end
    if not utils.can_cast_unit(runtime.lifebloom_id, me, tank) then return false end

    if utils.cast_unit(runtime.lifebloom_id, me, tank) then
        mark_pending_cast(runtime.lifebloom_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Lifebloom on " .. (tank.get_name and tank:get_name() or "tank") .. " (stacks=" .. tostring(stacks) .. ")")
        note_cast()
                esp_renderer.on_cast(nil, "Lifebloom", color.cyan(220))
        return true
    end

    return false
end

local function try_rejuvenation(me, target, target_hp_pct)
    if not menu.use_rejuvenation:get_state() then return false end
    if not runtime.rejuvenation_id then return false end
    if target_hp_pct >= 0.90 then return false end  -- no rejuv above 90% HP
    if utils.get_buff_remaining_ms(target, spells.BUFF_REJUVENATION) > (menu.rejuvenation_refresh_seconds:get() * 1000) then return false end
    if is_pending_cast(runtime.rejuvenation_id) then return false end
    if not utils.can_cast_unit(runtime.rejuvenation_id, me, target) then return false end

    if utils.cast_unit(runtime.rejuvenation_id, me, target) then
        mark_pending_cast(runtime.rejuvenation_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Rejuvenation on " .. (target.get_name and target:get_name() or "target"))
        note_cast()
                esp_renderer.on_cast(nil, "Rejuvenation", color.green(220))
        return true
    end

    return false
end

local function try_regrowth(me, target, target_hp_pct, mana_pct)
    if not menu.use_regrowth:get_state() then return false end
    if not runtime.regrowth_id then return false end
    if target_hp_pct >= 0.85 then return false end
    if menu.mana_saver:get_state() and mana_pct < 0.45 and target_hp_pct > 0.60 then return false end
    if utils.get_buff_remaining_ms(target, spells.BUFF_REGROWTH) > (menu.regrowth_refresh_seconds:get() * 1000) then return false end
    if is_pending_cast(runtime.regrowth_id) then return false end
    if not utils.can_cast_unit(runtime.regrowth_id, me, target) then return false end

    if utils.cast_unit(runtime.regrowth_id, me, target) then
        mark_pending_cast(runtime.regrowth_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Regrowth on " .. (target.get_name and target:get_name() or "target"))
        note_cast()
                esp_renderer.on_cast(nil, "Regrowth", color.gold(220))
        return true
    end

    return false
end

local function try_remove_curse_resto(me)
    if not menu.use_remove_curse:get_state() then return false end
    if not runtime.remove_curse_id then return false end

    local units = utils.get_group_units(me, true)
    for _, unit in ipairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() then
            local cache = buff_manager:get_debuff_cache(unit, 100)
            for _, aura in ipairs(cache) do
                if aura.is_active and aura.buff_type == enums.buff_type.CURSE then
                    if utils.can_cast_unit(runtime.remove_curse_id, me, unit) then
                        if utils.cast_unit(runtime.remove_curse_id, me, unit) then
                            utils.log_debug(menu, "Remove Curse -> " .. (unit.get_name and unit:get_name() or "ally"))
                            return true
                        end
                    end
                    break
                end
            end
        end
    end
    return false
end

local function do_rotation(me, target)
    if not is_gcd_ready() then return false end

    -- OOC: only allow buffs like Mark of the Wild, not heals
    if not me:is_in_combat() then
        try_mark_of_the_wild(me)
        return false
    end

    -- Focus Target Priority - heal focus target first
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target then
        local focus_hp = focus_target:get_health_percentage() / 100
        if focus_hp < 0.75 then
            if try_rejuvenation(me, focus_target, focus_hp) then return true end
            if try_regrowth(me, focus_target, focus_hp, utils.get_mana_pct(me)) then return true end
        end
    end

    -- Combat-aware self HP threshold
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_regrowth(me, me, my_hp, utils.get_mana_pct(me)) then return true end
    end

    local mode = get_effective_mode()
    local mana_pct = utils.get_mana_pct(me)
    local units = utils.get_group_units(me, true)
    local lowest, lowest_hp_pct = utils.get_lowest_health_unit(units)
    local tank = pick_tank_unit(me, units, mode)
    local heal_target, heal_target_hp_pct = pick_priority_heal_target(me, tank, lowest, lowest_hp_pct)
    local injured_count = utils.count_injured_units(units, 0.85)

    if try_innervate(me, mana_pct) then return true end
    if try_remove_curse_resto(me) then return true end
    if try_tranquility(me, injured_count, lowest_hp_pct, mode) then return true end
    if heal_target and try_natures_swiftness_regrowth(me, heal_target, heal_target_hp_pct) then return true end
    if heal_target and try_swiftmend(me, heal_target, heal_target_hp_pct) then return true end
    if tank and try_lifebloom(me, tank) then return true end
    if heal_target and try_rejuvenation(me, heal_target, heal_target_hp_pct) then return true end
    if heal_target and try_regrowth(me, heal_target, heal_target_hp_pct, mana_pct) then return true end

    -- Leveling fallback: wand at enemy target when mana is low
    if me:is_in_combat() and target and target:is_valid()
       and not target:is_dead() and me:can_attack(target) then
        leveling_manager.try_wand(me, target, menu)
    end

    return false
end


local function on_render()
    esp_renderer.on_render(menu)
end

-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    on_render()
end)
-- __EAX_ESP_GUARD
core.register_on_update_callback(function()
    local me = core.object_manager.get_local_player()
    if not me then return end

    if utils.throttle("eaxdruidrestoration_mode_refresh", 5.0) then
        runtime.cached_mode = detect_mode(me)
    end

    if utils.throttle("eaxdruidrestoration_set_bonus", 10.0) then
        update_set_bonus(me)
    end

    handle_toggle()

    if not menu.enabled:get_state() then return end

    -- OOC management (drink/eat/rez/group buffs)
    ooc_manager.on_update(me, menu, utils, {
        rez_spell_id = runtime.rebirth_id,
        group_buffs = {
            { spell_id = runtime.ooc_mark_of_the_wild_id,
               buff_ids = spells.BUFF_MARK_OF_THE_WILD,
               name = "Mark Of The Wild",
               toggle = menu.ooc_group_buff },
        },
    })
    if me:is_dead() then return end
    if eax_utils.is_eating_or_drinking(me) then return end

    -- Overheal Protection - cancel slow heals if target is healthy
    if eax_utils.should_stopcasting(me, menu) then
        if SpellStopCasting then SpellStopCasting() end
    end

    -- Use smart target for wanding/interrupts (prefers units attacking us/party)
    local target = utils.find_best_target(me)

    -- Mana conservation (leveling 1-70)
    if leveling_manager.is_conserving_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
    end

    -- Interrupt (PVP)
    if target and target:is_valid() and me:can_attack(target) and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "druid", utils) then
            return
        end
    end

    -- Encounter policy (boss-specific rotation adjustments)
    local enc = encounter_manager.get_policy(me)

    -- Defensive abilities
    -- Racial abilities
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    if defensive_manager.try_defensive(me, "druid", utils) then
        return
    end

    ttd_tracker.update(target)

    do_rotation(me, target)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxdruidrestoration_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(function()
    menu.render()
end)

if control_panel_utility then
    core.register_on_render_control_panel_callback(function()
        local elements = {}
        local function add_cb(label, item, uid)
            if not item then return end
            local cur = item:get_state()
            local nxt = control_panel_utility:insert_key_checkbox_(elements, label, cur, 0, false, uid)
            if nxt ~= cur then item:set(nxt) end
        end
        local toggle_key = menu.toggle_key:get_key_code()
        local label = "EAX Druid Resto] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxdruidrestoration_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_rst_cds = menu.use_cooldowns:get_state()
            local nxt_rst_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX Rst] Cooldowns", cur_rst_cds, 0, false, "eax_rst_cds_cp")
            if nxt_rst_cds ~= cur_rst_cds then menu.use_cooldowns:set(nxt_rst_cds) end
        end
        if menu.focus_priority then
            local cur_rst_focus = menu.focus_priority:get_state()
            local nxt_rst_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX Rst] Focus Priority", cur_rst_focus, 0, false, "eax_rst_focus_cp")
            if nxt_rst_focus ~= cur_rst_focus then menu.focus_priority:set(nxt_rst_focus) end
        end
        if menu.use_racial then
            local cur_rst_racial = menu.use_racial:get_state()
            local nxt_rst_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX Rst] Use Racial", cur_rst_racial, 0, false, "eax_rst_racial_cp")
            if nxt_rst_racial ~= cur_rst_racial then menu.use_racial:set(nxt_rst_racial) end
        end
        end
        return elements
    end)
end


-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Druid"
    local _eax_spec  = "Restoration"
    -- Register this spec for its class (last-loaded wins for tracking)
    if not _G.__EAX_LOADED[_eax_class] then
        _G.__EAX_LOADED[_eax_class] = {}
    end
    _G.__EAX_LOADED[_eax_class][_eax_spec] = function()
        return menu and menu.enabled and menu.enabled:get_state()
    end
    -- Runtime conflict check: fires on render, only warns when 2+ specs enabled
    local _conflict_last_warn = 0
    local _orig_render = on_render
    on_render = function()
        if _orig_render then _orig_render() end
        local specs = _G.__EAX_LOADED[_eax_class]
        if not specs then return end
        local enabled_specs = {}
        for spec_name, is_enabled_fn in pairs(specs) do
            if is_enabled_fn and is_enabled_fn() then
                table.insert(enabled_specs, spec_name)
            end
        end
        if #enabled_specs < 2 then return end
        local now = core.time()
        if (now - _conflict_last_warn) < 10 then return end
        _conflict_last_warn = now
        local names = table.concat(enabled_specs, " + ")
        core.log("[EAX WARNING] Multiple " .. _eax_class .. " specs enabled: "
            .. names .. ". Disable all but one.")
        core.graphics.add_notification(
            "eax_conflict_" .. _eax_class,
            "[EAX] Conflict!",
            "Multiple " .. _eax_class .. " specs enabled: " .. names .. " - Disable all but one in the bot menu.",
            8.0,
            require("common/color").new(255, 80, 80, 255)
        )
    end
end

local _pi = pcall(require, "plugin_info") and require("plugin_info") or nil
core.log("[EAX Druid Restoration] Loaded " .. (_pi and _pi.plugin_version or "?"))
