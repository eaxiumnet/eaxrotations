-- EAX Mage Arcane | main.lua

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
-- Module-level encounter policy cache (updated each tick)
local enc = nil


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("arcane", "Mage Arcane")
---@type racial_manager
local racial_manager = require("racial_manager")
---@type defensive_manager
local defensive_manager = require("defensive_manager")

---@type mana_conservator
local mana_conservator = require("mana_conservator")

---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    arcane_blast_id = nil,
    arcane_missiles_id = nil,
    arcane_power_id = nil,
    evocation_id = nil,
    fire_blast_id = nil,
    ice_block_id = nil,
    counterspell_id = nil,
    presence_of_mind_id = nil,
    frost_nova_id = nil,
    blink_id = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    pending_casts = {},
    set_multiplier = 1.0,
    ooc_counterspell_id = nil,
    ooc_arcane_intellect_id = nil,
}

local GCD_CAST_INTERVAL = 1.5  -- TBC GCD
local PENDING_CAST_TIMEOUT_S = 2.5
local FAST_PENDING_CAST_TIMEOUT_S = 0.75

local function resolve_spells()
    runtime.arcane_intellect_id = utils.resolve_spell_id(spells.ARCANE_INTELLECT)
    runtime.cone_of_cold_id     = utils.resolve_spell_id(spells.CONE_OF_COLD)
    runtime.arcane_blast_id = utils.resolve_spell_id(spells.ARCANE_BLAST)
    runtime.arcane_missiles_id = utils.resolve_spell_id(spells.ARCANE_MISSILES)
    runtime.arcane_power_id = utils.resolve_spell_id(spells.ARCANE_POWER)
    runtime.evocation_id = utils.resolve_spell_id(spells.EVOCATION)
    runtime.fire_blast_id = utils.resolve_spell_id(spells.FIRE_BLAST)
    runtime.counterspell_id = runtime.ooc_counterspell_id
end

local function log_resolved_spells()
    core.log("[EAX Mage Arcane] Resolved: AB=" .. tostring(runtime.arcane_blast_id)
        .. " AM=" .. tostring(runtime.arcane_missiles_id)
        .. " AP=" .. tostring(runtime.arcane_power_id)
        .. " Evo=" .. tostring(runtime.evocation_id))
end

resolve_spells()
log_resolved_spells()

local function update_set_bonus()
    local me = core.object_manager.get_local_player()
    if not me then return end
    
    local aldor_mult = utils.get_set_multiplier(me, "Aldor")
    local aldor_regalia_mult = utils.get_set_multiplier(me, "AldorRegalia")
    local aldor_nethers_mult = utils.get_set_multiplier(me, "AldorNethers")
    
    runtime.set_multiplier = aldor_mult
    if aldor_regalia_mult > runtime.set_multiplier then
        runtime.set_multiplier = aldor_regalia_mult
    end
    if aldor_nethers_mult > runtime.set_multiplier then
        runtime.set_multiplier = aldor_nethers_mult
    end
    
    if runtime.set_multiplier > 1.0 then
        utils.log_debug(menu, "Set bonus: " .. tostring(runtime.set_multiplier))
    end
end

local function detect_mode()
    local objects = core.object_manager.get_all_objects()
    local party_count = 0
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() 
           and obj:is_party_member() then
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
    runtime.cached_mode = detect_mode()
end

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 2 then return "solo" end
    if idx == 3 then return "dungeon" end
    if idx == 4 then return "raid" end
    return runtime.cached_mode
end

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

local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function try_mana_gem(me)
    if not menu.use_mana_gem:get_state() then return false end
    if not me:is_in_combat() then return false end
    if utils.get_mana_pct(me) > menu.mana_gem_pct:get() then return false end

    for i = 1, #spells.MANA_GEM_ITEMS do
        if utils.use_consumable_if_ready(me, spells.MANA_GEM_ITEMS[i]) then
            utils.log_debug(menu, "Mana Gem")
            note_cast()
            return true
        end
    end

    return false
end

local function try_evocation(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_evocation:get_state() then return false end
    if not runtime.evocation_id then return false end
    if not me:is_in_combat() then return false end
    if me:is_channelling_spell() then return false end
    if utils.get_mana_pct(me) > menu.evocation_pct:get() then return false end
    if is_pending_cast(runtime.evocation_id) or utils.is_spell_already_queued(runtime.evocation_id) then return false end
    if not utils.can_cast_self(runtime.evocation_id, me) then return false end

    if utils.cast_self(runtime.evocation_id, me, "Evocation") then
        mark_pending_cast(runtime.evocation_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Evocation")
        note_cast()
                esp_renderer.on_cast(runtime.evocation_id, "Evocation", color.blue(220))
        return true
    end

    return false
end

local function try_arcane_power(me, target)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_arcane_power:get_state() then return false end
    if not runtime.arcane_power_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_ARCANE_POWER) then return false end

    local min_mana = menu.burn_mana_pct:get()
    if get_effective_mode() == "raid" then
        min_mana = math.max(50, min_mana)
    elseif get_effective_mode() == "solo" then
        min_mana = math.max(35, min_mana - 10)
    end

    if utils.get_mana_pct(me) < min_mana then return false end
    if is_pending_cast(runtime.arcane_power_id) or utils.is_spell_already_queued(runtime.arcane_power_id) then return false end
    if not utils.can_cast_self(runtime.arcane_power_id, me) then return false end

    if utils.cast_self_fast(runtime.arcane_power_id, me, "Arcane Power") then
        mark_pending_cast(runtime.arcane_power_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Arcane Power")
        note_cast()
        return true
    end

    return false
end

local function try_trinkets(me)
    if not menu.use_trinkets:get_state() then return false end
    if not me:is_in_combat() then return false end
    if get_effective_mode() == "solo" and not utils.has_buff(me, spells.BUFF_ARCANE_POWER) then
        return false
    end

    local trinkets = utils.get_self_cast_trinket_ids(me)
    for i = 1, #trinkets do
        if utils.use_item_if_ready(trinkets[i].item_id) then
            utils.log_debug(menu, "Trinket slot " .. tostring(trinkets[i].slot_id))
            note_cast()
            return true
        end
    end

    return false
end

local function try_arcane_missiles(me, target)
    if not menu.use_arcane_missiles:get_state() then return false end
    if not runtime.arcane_missiles_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end

    local ab_stacks = utils.get_buff_stacks(me, spells.BUFF_ARCANE_BLAST)
    local dump_stacks = menu.arcane_blast_dump_stacks:get()
    local clearcasting = utils.has_buff(me, spells.BUFF_CLEARCASTING)
    local low_mana = utils.get_mana_pct(me) <= (menu.evocation_pct:get() + 15)
    if not clearcasting and not low_mana and ab_stacks < dump_stacks then
        return false
    end

    if is_pending_cast(runtime.arcane_missiles_id) or utils.is_spell_already_queued(runtime.arcane_missiles_id) then return false end
    if not utils.can_cast_hostile(runtime.arcane_missiles_id, me, target) then return false end

    if utils.cast_target(runtime.arcane_missiles_id, target, "Arcane Missiles") then
        mark_pending_cast(runtime.arcane_missiles_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Arcane Missiles")
        note_cast()
                esp_renderer.on_cast(runtime.arcane_missiles_id, "Arcane Missiles", color.cyan(220))
        return true
    end

    return false
end

local function try_fire_blast_move(me, target)
    if not menu.use_fire_blast_move:get_state() then return false end
    if not runtime.fire_blast_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_moving() then return false end
    if not utils.can_cast_hostile(runtime.fire_blast_id, me, target) then return false end

    if utils.cast_target_fast(runtime.fire_blast_id, target, "Fire Blast") then
        mark_pending_cast(runtime.fire_blast_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Fire Blast (move)")
        note_cast()
        return true
    end

    return false
end

local function try_arcane_blast(me, target)
    if not menu.use_arcane_blast:get_state() then return false end
    if not runtime.arcane_blast_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end
    if is_pending_cast(runtime.arcane_blast_id) or utils.is_spell_already_queued(runtime.arcane_blast_id) then return false end
    if not utils.can_cast_hostile(runtime.arcane_blast_id, me, target) then return false end

    if utils.cast_target(runtime.arcane_blast_id, target, "Arcane Blast") then
        mark_pending_cast(runtime.arcane_blast_id, PENDING_CAST_TIMEOUT_S)
        note_cast()
                esp_renderer.on_cast(runtime.arcane_blast_id, "Arcane Blast", color.purple(220))
        return true
    end

    return false
end

local function try_ice_block(me)
    if not menu.use_ice_block:get_state() then return false end
    if not runtime.ice_block_id then
        runtime.ice_block_id = utils.resolve_spell_id(spells.ICE_BLOCK)
    end
    if not runtime.ice_block_id then return false end
    local hp_pct = me:get_health_percentage() / 100
    if hp_pct > (menu.ice_block_hp_pct:get() / 100) then return false end
    if utils.has_buff(me, spells.BUFF_ICE_BLOCK) then return false end
    if not utils.can_cast_self(runtime.ice_block_id, me) then return false end
    if utils.cast_self(runtime.ice_block_id, me) then
        utils.log_debug(menu, "Ice Block")
        return true
    end
    return false
end


-- --- Frost Nova - kite tool (v1.4) ---------------------------------------

local function try_frost_nova(me)
    if not menu.use_frost_nova or not menu.use_frost_nova:get_state() then return false end
    if not runtime.frost_nova_id then return false end
    -- Use when a melee enemy is within 8 yards
    local objects = core.object_manager.get_all_objects()
    local melee_attacker = false
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead()
           and me:can_attack(obj) and obj:get_distance_to(me) <= 8 then
            melee_attacker = true
            break
        end
    end
    if not melee_attacker then return false end
    if not utils.can_cast_self(runtime.frost_nova_id, me) then return false end
    if utils.cast_self(runtime.frost_nova_id, me) then
        utils.log_debug(menu, "Frost Nova (kite)")
        return true
    end
    return false
end

-- --- Presence of Mind - instant cast proc (Arcane talent) (v1.4) ---------

local function try_presence_of_mind(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_presence_of_mind or not menu.use_presence_of_mind:get_state() then return false end
    if not runtime.presence_of_mind_id then return false end
    if utils.has_buff(me, spells.BUFF_PRESENCE_OF_MIND) then return false end
    if not me:is_in_combat() then return false end
    -- Only pop PoM when Arcane Power is active or as opener
    if runtime.arcane_power_id and not utils.has_buff(me, spells.BUFF_ARCANE_POWER) then return false end
    if not utils.can_cast_self(runtime.presence_of_mind_id, me) then return false end
    if utils.cast_self_fast(runtime.presence_of_mind_id, me) then
        utils.log_debug(menu, "Presence of Mind")
        return true
    end
    return false
end



local function try_arcane_intellect(me)
    if not runtime.arcane_intellect_id then return false end
    if utils.has_buff(me, spells.BUFF_ARCANE_INTELLECT) then return false end
    if not utils.can_cast_self(runtime.arcane_intellect_id, me) then return false end
    if utils.cast_self(runtime.arcane_intellect_id, me) then
        utils.log_debug(menu, "Arcane Intellect")
        return true
    end
    return false
end

local function try_cone_of_cold(me, target)
    if not menu.use_cone_of_cold or not menu.use_cone_of_cold:get_state() then return false end
    if not runtime.cone_of_cold_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not utils.can_cast_hostile(runtime.cone_of_cold_id, me, target) then return false end
    if utils.cast_target(runtime.cone_of_cold_id, target) then
        utils.log_debug(menu, "Cone of Cold")
        return true
    end
    return false
end

local function do_rotation(me, target)
    if mana_conservator.on_update(me, target, menu, utils) then return end
    if not is_gcd_ready() then return false end

    -- Interrupt
    if target:is_casting_spell() and target:is_active_spell_interruptable() then
        if runtime.counterspell_id and utils.can_cast_hostile(runtime.counterspell_id, me, target) then
            if utils.cast_target(runtime.counterspell_id, target) then
                utils.log_debug(menu, "Counterspell interrupt")
                return true
            end
        end
    end

    -- Defensive abilities
    -- Interrupt
    if interrupt_manager.should_interrupt(target) then
        interrupt_manager.try_interrupt(me, target, "mage", utils)
    end

    if defensive_manager.try_defensive(me, "mage", utils) then
        return true
    end

    ttd_tracker.update(target)



    -- Wanding / mana conservation (leveling 1-70)
    if leveling_manager.try_wand(me, target, menu) then return true end
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    if try_mana_gem(me) then return true end
    if try_evocation(me) then return true end
    if try_presence_of_mind(me) then return true end
    if try_arcane_power(me, target) then return true end
    if try_trinkets(me) then return true end
    if try_fire_blast_move(me, target) then return true end
    if try_arcane_missiles(me, target) then return true end
    if try_arcane_blast(me, target) then return true end

    return false
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
        utils.log_debug(menu, "Toggle -> " .. tostring(menu.enabled:get_state()))
    end
    runtime.prev_toggle_state = current
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
    if utils.throttle("mode_refresh", 5.0) then
        refresh_mode_cache()
    end
    if utils.throttle("set_bonus", 5.0) then
        update_set_bonus()
    end

    handle_toggle()

    if not menu.enabled:get_state() then return end

    -- OOC management (drink/eat/rez/group buffs)
    ooc_manager.on_update(me, menu, utils, {
        group_buffs = {
            { spell_id = runtime.ooc_arcane_intellect_id,
               buff_ids = spells.BUFF_ARCANE_INTELLECT,
               name = "Arcane Intellect",
               toggle = menu.ooc_group_buff },
        },
    })

    local me = core.object_manager.get_local_player()
    if not me then return end
    if me:is_dead() then return end
    if eax_utils.is_eating_or_drinking(me) then return end

    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    local target = focus_target or utils.find_best_target(me)
    
    -- Self-emergency (Mage has Ice Block)
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.30, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        try_ice_block(me)
    end
    
    do_rotation(me, target)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxmagearcane_space_win")
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
        local label = "EAX Mage Arcane] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxmagearcane_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_mar_cds = menu.use_cooldowns:get_state()
            local nxt_mar_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX MAr] Cooldowns", cur_mar_cds, 0, false, "eax_mar_cds_cp")
            if nxt_mar_cds ~= cur_mar_cds then menu.use_cooldowns:set(nxt_mar_cds) end
        end
        if menu.focus_priority then
            local cur_mar_focus = menu.focus_priority:get_state()
            local nxt_mar_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX MAr] Focus Priority", cur_mar_focus, 0, false, "eax_mar_focus_cp")
            if nxt_mar_focus ~= cur_mar_focus then menu.focus_priority:set(nxt_mar_focus) end
        end
        if menu.use_racial then
            local cur_mar_racial = menu.use_racial:get_state()
            local nxt_mar_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX MAr] Use Racial", cur_mar_racial, 0, false, "eax_mar_racial_cp")
            if nxt_mar_racial ~= cur_mar_racial then menu.use_racial:set(nxt_mar_racial) end
        end
        end
        return elements
    end)
end


-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Mage"
    local _eax_spec  = "Arcane"
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
core.log("[EAX Mage Arcane] Loaded " .. (_pi and _pi.plugin_version or "?"))
