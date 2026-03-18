-- EAX Paladin Holy | main.lua
-- Callback registration, menu wiring, and healing logic for Holy Paladin.
-- APIs verified via docs/eax-family/API_LOOKUP_PLAYBOOK.md and existing EAX addons.

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
esp_renderer.init("pholy", "Paladin Holy")
---@type racial_manager
local racial_manager = require("racial_manager")
---@type defensive_manager
local defensive_manager = require("defensive_manager")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")

local CLEANSE_SPELL_IDS = {
    4987, -- Cleanse
}

local DISPELABLE_DEBUFF_IDS = {
    16470, -- Infected Wounds (disease)
    16472, -- Putrid Physical (disease)
    16473, -- Corrupting Disease (disease)
    28169, -- Paralyze (poison-like)
}

local MODE_SOLO = "solo"
local MODE_DUNGEON = "dungeon"
local MODE_RAID = "raid"
local MODE_REFRESH_INTERVAL = 1.0

local runtime = {
    redemption_id = nil,
    divine_plea_id = nil,
    jow_id = nil,
    avenging_wrath_id = nil,
    holy_light_id = nil,
    flash_of_light_id = nil,
    holy_shock_id = nil,
    blessing_light_id = nil,
    blessing_wisdom_id = nil,
    blessing_might_id = nil,
    cleanse_id = nil,
    mode_cache = MODE_SOLO,
    mode_cache_refreshed_at = 0,
    last_toggle_state = false,
}

local function resolve_spells()
    runtime.holy_light_id = utils.resolve_spell_id(spells.HOLY_LIGHT)
    runtime.flash_of_light_id = utils.resolve_spell_id(spells.FLASH_OF_LIGHT)
    runtime.holy_shock_id = utils.resolve_spell_id(spells.HOLY_SHOCK)
    runtime.blessing_light_id = utils.resolve_spell_id(spells.BLESSING_OF_LIGHT)
    runtime.blessing_wisdom_id = utils.resolve_spell_id(spells.BLESSING_OF_WISDOM)
    runtime.blessing_might_id = utils.resolve_spell_id(spells.BLESSING_OF_MIGHT)
    runtime.cleanse_id = utils.resolve_spell_id(CLEANSE_SPELL_IDS)
    runtime.divine_plea_id    = utils.resolve_spell_id(spells.DIVINE_PLEA)
    runtime.jow_id            = utils.resolve_spell_id(spells.JUDGEMENT_OF_WISDOM)
    runtime.avenging_wrath_id = utils.resolve_spell_id(spells.AVENGING_WRATH)
    runtime.redemption_id  = utils.resolve_spell_id(spells.REDEMPTION)
end

local function log_resolved_spells()
    

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
        local label = "EAX Paladin Holy] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxpaladinholy_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_pho_cds = menu.use_cooldowns:get_state()
            local nxt_pho_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX PHo] Cooldowns", cur_pho_cds, 0, false, "eax_pho_cds_cp")
            if nxt_pho_cds ~= cur_pho_cds then menu.use_cooldowns:set(nxt_pho_cds) end
        end
        if menu.focus_priority then
            local cur_pho_focus = menu.focus_priority:get_state()
            local nxt_pho_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX PHo] Focus Priority", cur_pho_focus, 0, false, "eax_pho_focus_cp")
            if nxt_pho_focus ~= cur_pho_focus then menu.focus_priority:set(nxt_pho_focus) end
        end
        if menu.use_racial then
            local cur_pho_racial = menu.use_racial:get_state()
            local nxt_pho_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX PHo] Use Racial", cur_pho_racial, 0, false, "eax_pho_racial_cp")
            if nxt_pho_racial ~= cur_pho_racial then menu.use_racial:set(nxt_pho_racial) end
        end
        end
        return elements
    end)
end

-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Paladin"
    local _eax_spec  = "Holy"
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

core.log("[EAX Paladin Holy] Spells resolved: HL=" .. tostring(runtime.holy_light_id)
        .. " FoL=" .. tostring(runtime.flash_of_light_id)
        .. " HS=" .. tostring(runtime.holy_shock_id)
        .. " Cleanse=" .. tostring(runtime.cleanse_id))
end

local function detect_mode()
    local objects = core.object_manager.get_all_objects()
    local group_size = 0
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead()
            and obj:is_party_member()
        then
            group_size = group_size + 1
        end
    end

    if group_size == 0 then
        return MODE_SOLO
    end
    if group_size <= 4 then
        return MODE_DUNGEON
    end
    return MODE_RAID
end

local function refresh_mode_cache()
    local now = core.time()
    if (now - runtime.mode_cache_refreshed_at) < MODE_REFRESH_INTERVAL then
        return
    end
    runtime.mode_cache_refreshed_at = now
    runtime.mode_cache = detect_mode()
end

local function get_effective_mode()
    local selection = menu.mode:get()
    if selection == 2 then
        return MODE_SOLO
    elseif selection == 3 then
        return MODE_DUNGEON
    elseif selection == 4 then
        return MODE_RAID
    end
    return runtime.mode_cache
end

local function handle_toggle()
    local pressed = menu.toggle_key:get_state()
    if pressed and not runtime.last_toggle_state then
        local new_state = not menu.enabled:get_state()
        menu.enabled:set(new_state)
        utils.log_debug(menu, "Addon toggled -> " .. tostring(new_state))
    end
    runtime.last_toggle_state = pressed
end

local function gather_heal_candidates(me)
    local candidates = {}
    local seen = {}

    local function add(unit)
        if not unit or not unit:is_valid() or unit:is_dead() then
            return
        end
        if seen[unit] then
            return
        end
        seen[unit] = true
        candidates[#candidates + 1] = unit
    end

    add(me)
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead()
            and obj:is_party_member()
        then
            add(obj)
        end
    end

    return candidates
end

local function find_heal_target(me, mode)
    if mode == MODE_SOLO or not me then
        return me, utils.get_health_pct(me)
    end

    local candidates = gather_heal_candidates(me)
    local best = me
    local best_pct = utils.get_health_pct(me)

    for _, unit in ipairs(candidates) do
        if unit and unit:is_valid() and not unit:is_dead() then
            local pct = utils.get_health_pct(unit)
            if pct < best_pct then
                best_pct = pct
                best = unit
            end
        end
    end

    return best, best_pct
end

local function has_dispellable_debuff(unit)
    if not unit or not unit:is_valid() then
        return false
    end
    for i = 1, #DISPELABLE_DEBUFF_IDS do
        local data = buff_manager:get_debuff_data(unit, DISPELABLE_DEBUFF_IDS[i])
        if data and data.is_active then
            return true
        end
    end
    return false
end

local function try_cast_spell(spell_id, me, target, label)
    if not spell_id or not me then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if not utils.can_cast_target(spell_id, me, target) then
        return false
    end
    if not utils.cast_target(spell_id, me, target) then
        return false
    end
    local target_name = "unknown"
    if target.get_name then
        local name = target:get_name()
        if name and name ~= "" then
            target_name = name
        end
    end
    utils.log_debug(menu, label .. " -> " .. target_name)
    return true
end

local function try_cleanse(me, target)
    if not runtime.cleanse_id then
        return false
    end
    if has_dispellable_debuff(target) then
        return try_cast_spell(runtime.cleanse_id, me, target, "Cleanse")
    end
    return false
end

local function ensure_blessings(me)
    if not menu.auto_blessings:get_state() then
        return false
    end
    if not me or not me:is_valid() then
        return false
    end

    if runtime.blessing_light_id
        and not utils.has_buff(me, spells.BUFF_BLESSING_OF_LIGHT)
        and try_cast_spell(runtime.blessing_light_id, me, me, "Blessing of Light")
    then
        return true
    end

    if runtime.blessing_wisdom_id
        and not utils.has_buff(me, spells.BUFF_BLESSING_OF_WISDOM)
        and try_cast_spell(runtime.blessing_wisdom_id, me, me, "Blessing of Wisdom")
    then
        return true
    end

    if runtime.blessing_might_id
        and not utils.has_buff(me, spells.BUFF_BLESSING_OF_MIGHT)
        and try_cast_spell(runtime.blessing_might_id, me, me, "Blessing of Might")
    then
        return true
    end

    return false
end

local function try_cast_heal(me, target, hp_pct)
    if not target or not hp_pct then
        return false
    end

    if menu.use_holy_shock:get_state() and runtime.holy_shock_id then
        local threshold = menu.holy_shock_hp_pct:get() / 100
        if hp_pct <= threshold and try_cast_spell(runtime.holy_shock_id, me, target, "Holy Shock") then
                    esp_renderer.on_cast(nil, "Holy Light", color.yellow(220))
        return true
        end
    end

    if menu.use_flash_of_light:get_state() and runtime.flash_of_light_id then
        local threshold = menu.flash_of_light_hp_pct:get() / 100
        if hp_pct <= threshold and try_cast_spell(runtime.flash_of_light_id, me, target, "Flash of Light") then
            return true
        end
    end

    if menu.use_holy_light:get_state() and runtime.holy_light_id then
        local threshold = menu.holy_light_hp_pct:get() / 100
        if hp_pct <= threshold and try_cast_spell(runtime.holy_light_id, me, target, "Holy Light") then
            return true
        end
    end

    return false
end


-- --- Divine Plea - mana recovery (v1.4) -----------------------------------

local function try_divine_plea(me)
    if not runtime.divine_plea_id then return false end
    if utils.has_buff(me, spells.BUFF_DIVINE_PLEA) then return false end
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct > 0.50 then return false end
    if not utils.can_cast_self(runtime.divine_plea_id, me) then return false end
    utils.cast_self(runtime.divine_plea_id, me)
    utils.log_debug(menu, "Divine Plea")
    return true
end

-- --- Judgment of Wisdom - mana return on boss (v1.4) ----------------------

local function try_judgment_of_wisdom(me, target)
    if not runtime.jow_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if utils.has_debuff(target, spells.DEBUFF_JOW) then return false end
    local mode = runtime.cached_mode or "solo"
    if mode == "solo" then return false end
    if not utils.can_cast_target(runtime.jow_id, me, target) then return false end
    utils.cast_target(runtime.jow_id, target, "Judgment of Wisdom")
    return true
end


local function on_update()
    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end

    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() or me:is_dead() then
        return
    end
        ooc_manager.on_update(me, menu, utils, {
        group_buffs = {
            { spell_id = utils.resolve_spell_id(spells.BLESSING_OF_MIGHT),
               buff_ids = spells.BUFF_BLESSING_OF_MIGHT,
               name = "Blessing of Might",
               toggle = menu.ooc_group_buff },
            { spell_id = utils.resolve_spell_id(spells.BLESSING_OF_WISDOM),
               buff_ids = spells.BUFF_BLESSING_OF_WISDOM,
               name = "Blessing of Wisdom",
               toggle = menu.ooc_group_buff },
        },
    })
    if eax_utils.is_eating_or_drinking(me) then return end

    -- Overheal Protection - cancel slow heals if target is healthy
    if eax_utils.should_stopcasting(me, menu) then
        if SpellStopCasting then SpellStopCasting() end
    end

    -- Interrupt (PVP)
    local target = me:get_target()
    if target and target:is_valid() and target:is_enemy() and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "paladin", utils) then
            return
        end
    end


    -- Mana conservation (leveling 1-70)
    if leveling_manager.is_conserving_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
    end
    -- Encounter policy (boss-specific rotation adjustments)
    local enc = encounter_manager.get_policy(me)

    -- Defensive abilities
    if defensive_manager.try_defensive(me, "paladin", utils) then
        return
    end

    ttd_tracker.update(target)

    -- Focus Target Priority - heal focus target first
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target then
        local focus_hp = focus_target:get_health_percentage()
        if focus_hp < menu.flash_of_light_hp_pct:get() then
            if try_cast_heal(me, focus_target, focus_hp) then
                return
            end
        end
    end

    -- Combat-aware self HP threshold
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        -- Mana recovery
    if try_divine_plea(me) then return end
    if try_judgment_of_wisdom(me, me:get_target()) then return end

    if try_cast_heal(me, me, my_hp) then
            return
        end
    end

    refresh_mode_cache()
    local mode = get_effective_mode()

    -- OOC: only allow blessing maintenance, not heals/cleanse
    if ensure_blessings(me) then
        return
    end

    if not me:is_in_combat() then return end

    if core.spell_book.get_global_cooldown() > 0 then
        return
    end

    local target, hp_pct = find_heal_target(me, mode)
    if try_cleanse(me, target) then
        return
    end

    try_cast_heal(me, target, hp_pct)
end

local function on_control_panel()
    local elements = {}
    
    local toggle_key_code = menu.toggle_key:get_key_code()
    local display_name = "[EAX Paladin Holy] Enable"
    if toggle_key_code ~= 7 then
        display_name = "[EAX Paladin Holy] Enable (" .. key_helper:get_key_name(toggle_key_code) .. ")"
    end
    control_panel_utility:insert_toggle_(elements, display_name, menu.toggle_key)
    
    return elements
end

resolve_spells()
log_resolved_spells()


local function on_render()
    esp_renderer.on_render(menu)
end

-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    on_render()
end)
-- __EAX_ESP_GUARD
core.register_on_update_callback(on_update)

-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxpaladinholy_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(menu.render)
core.register_on_render_control_panel_callback(on_control_panel)
