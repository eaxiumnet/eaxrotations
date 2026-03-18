-- EAX Druid Balance | main.lua
-- Callback registration, mode handling, and balance rotation logic.

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
esp_renderer.init("balance", "Druid Balance")
---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("racial_manager")
---@type defensive_manager
local defensive_manager = require("defensive_manager")

---@type mana_conservator
local mana_conservator = require("mana_conservator")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    rebirth_id = nil,
    moonkin_form_id = nil,
    faerie_fire_id = nil,
    moonfire_id = nil,
    insect_swarm_id = nil,
    wrath_id = nil,
    starfire_id = nil,
    force_of_nature_id = nil,
    starfall_id = nil,
    hurricane_id = nil,
    wrath_id = nil,
    starfire_id = nil,
    innervate_id = nil,
    tranquility_id = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    pending_casts = {},
    set_multiplier = 1.0,
}

local GCD_CAST_INTERVAL = 1.5  -- TBC GCD
local PENDING_CAST_TIMEOUT_S = 2.5
local FAST_PENDING_CAST_TIMEOUT_S = 0.75

local function resolve_spells()
    runtime.moonkin_form_id = utils.resolve_spell_id(spells.MOONKIN_FORM)
    runtime.faerie_fire_id = utils.resolve_spell_id(spells.FAERIE_FIRE)
    runtime.moonfire_id = utils.resolve_spell_id(spells.MOONFIRE)
    runtime.insect_swarm_id = utils.resolve_spell_id(spells.INSECT_SWARM)
    runtime.wrath_id = utils.resolve_spell_id(spells.WRATH)
    runtime.starfire_id = utils.resolve_spell_id(spells.STARFIRE)
    runtime.force_of_nature_id = utils.resolve_spell_id(spells.FORCE_OF_NATURE)
    runtime.starfall_id  = utils.resolve_spell_id(spells.STARFALL)
    runtime.hurricane_id = utils.resolve_spell_id(spells.HURRICANE)
    runtime.wrath_id     = utils.resolve_spell_id(spells.WRATH)
    runtime.starfire_id  = utils.resolve_spell_id(spells.STARFIRE)
    runtime.innervate_id = utils.resolve_spell_id(spells.INNERVATE)
    runtime.tranquility_id = utils.resolve_spell_id(spells.TRANQUILITY)
    runtime.rebirth_id  = utils.resolve_spell_id(spells.REBIRTH)
end

local function log_resolved_spells()
    core.log("[EAX Druid Balance] Resolved: Moonfire=" .. tostring(runtime.moonfire_id)
        .. " InsectSwarm=" .. tostring(runtime.insect_swarm_id)
        .. " Wrath=" .. tostring(runtime.wrath_id)
        .. " Starfire=" .. tostring(runtime.starfire_id)
        .. " ForceOfNature=" .. tostring(runtime.force_of_nature_id)
        .. " Starfall=" .. tostring(runtime.starfall_id))
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
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and utils.is_group_member(me, obj) then
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

local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
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

local function try_moonkin_form(me)
    if not menu.force_moonkin:get_state() then return false end
    if not runtime.moonkin_form_id then return false end
    if utils.has_buff(me, spells.BUFF_MOONKIN_FORM) then return false end
    if is_pending_cast(runtime.moonkin_form_id) then return false end
    if not utils.can_cast_self(runtime.moonkin_form_id, me) then return false end

    if utils.cast_self(runtime.moonkin_form_id, me) then
        mark_pending_cast(runtime.moonkin_form_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Moonkin Form")
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

local function try_tranquility(me)
    if not menu.use_tranquility:get_state() then return false end
    if not runtime.tranquility_id then return false end
    if utils.get_health_pct(me) >= (menu.tranquility_hp_pct:get() / 100) then return false end
    if is_pending_cast(runtime.tranquility_id) then return false end
    if not utils.can_cast_self(runtime.tranquility_id, me) then return false end

    if utils.cast_self_fast(runtime.tranquility_id, me) then
        mark_pending_cast(runtime.tranquility_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Emergency Tranquility")
        note_cast()
        return true
    end

    return false
end

local function try_faerie_fire(me, target)
    if not menu.use_faerie_fire:get_state() then return false end
    if not runtime.faerie_fire_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_FAERIE_FIRE) >= 3000 then return false end
    if is_pending_cast(runtime.faerie_fire_id) then return false end
    if not utils.can_cast_target(runtime.faerie_fire_id, me, target) then return false end

    if utils.cast_target(runtime.faerie_fire_id, me, target) then
        mark_pending_cast(runtime.faerie_fire_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Faerie Fire refresh")
        note_cast()
        return true
    end

    return false
end

local function try_moonfire(me, target)
    if not menu.use_moonfire:get_state() then return false end
    if not runtime.moonfire_id then return false end
    if not is_valid_hostile_target(me, target) then return false end

    local refresh_ms = menu.dot_refresh_seconds:get() * 1000
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_MOONFIRE) > refresh_ms then return false end
    if is_pending_cast(runtime.moonfire_id) then return false end
    if not utils.can_cast_target(runtime.moonfire_id, me, target) then return false end

    if utils.cast_target(runtime.moonfire_id, me, target) then
        mark_pending_cast(runtime.moonfire_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Moonfire refresh")
        note_cast()
                esp_renderer.on_cast(runtime.moonfire_id, "Moonfire", color.blue(220))
        return true
    end

    return false
end

local function try_insect_swarm(me, target)
    if not menu.use_insect_swarm:get_state() then return false end
    if not runtime.insect_swarm_id then return false end
    if not is_valid_hostile_target(me, target) then return false end

    local refresh_ms = menu.dot_refresh_seconds:get() * 1000
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_INSECT_SWARM) > refresh_ms then return false end
    if is_pending_cast(runtime.insect_swarm_id) then return false end
    if not utils.can_cast_target(runtime.insect_swarm_id, me, target) then return false end

    if utils.cast_target(runtime.insect_swarm_id, me, target) then
        mark_pending_cast(runtime.insect_swarm_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Insect Swarm refresh")
        note_cast()
        return true
    end

    return false
end

local function try_force_of_nature(me, target, mana_pct)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_force_of_nature:get_state() then return false end
    if not runtime.force_of_nature_id then return false end
    if not me:is_in_combat() then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if mana_pct < 0.20 then return false end
    if not utils.has_debuff(target, spells.DEBUFF_MOONFIRE) then return false end
    if not utils.has_debuff(target, spells.DEBUFF_INSECT_SWARM) then return false end
    if is_pending_cast(runtime.force_of_nature_id) then return false end
    if not utils.can_cast_self(runtime.force_of_nature_id, me) then return false end

    if utils.cast_self(runtime.force_of_nature_id, me) then
        mark_pending_cast(runtime.force_of_nature_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Force of Nature")
        note_cast()
        return true
    end

    return false
end

local function try_starfall(me, enemy_count, mode)
    if enc and enc.hold_cooldowns then return false end
    if enc and not enc.aoe_safe then return false end
    if not menu.use_starfall:get_state() then return false end
    if not runtime.starfall_id then return false end
    if not me:is_in_combat() then return false end
    if enemy_count < menu.starfall_aoe_targets:get() and mode == "solo" then return false end
    if is_pending_cast(runtime.starfall_id) then return false end
    if not utils.can_cast_self(runtime.starfall_id, me) then return false end

    if utils.cast_self(runtime.starfall_id, me) then
        mark_pending_cast(runtime.starfall_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Starfall")
        note_cast()
        return true
    end

    return false
end

local function get_primary_nuke_id(me)
    if menu.wrath_during_lunar:get_state() and utils.has_buff(me, spells.BUFF_LUNAR_ECLIPSE) and runtime.wrath_id then
        return runtime.wrath_id, "Wrath"
    end

    if utils.has_buff(me, spells.BUFF_SOLAR_ECLIPSE) and runtime.starfire_id then
        return runtime.starfire_id, "Starfire"
    end

    if runtime.starfire_id then
        return runtime.starfire_id, "Starfire"
    end

    return runtime.wrath_id, "Wrath"
end


-- --- Hurricane AoE (v1.4) -------------------------------------------------

local HURRICANE_TARGET_COUNT = 4
local HURRICANE_MANA_FLOOR   = 0.40

local function try_hurricane(me, enemy_count, mana_pct)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_hurricane or not menu.use_hurricane:get_state() then return false end
    if not runtime.hurricane_id then return false end
    if enemy_count < HURRICANE_TARGET_COUNT then return false end
    if mana_pct < HURRICANE_MANA_FLOOR then return false end
    if me:is_moving() then return false end
    if not utils.can_cast_self(runtime.hurricane_id, me) then return false end
    if utils.cast_self(runtime.hurricane_id, me) then
        utils.log_debug(menu, "Hurricane (AoE x" .. tostring(enemy_count) .. ")")
                esp_renderer.on_cast(runtime.hurricane_id, "Hurricane", color.cyan(220))
        return true
    end
    return false
end

-- --- Adaptive mana rotation (v1.4) ----------------------------------------
-- When mana < starfire_mana_floor, downgrade to Wrath (cheaper, faster).
-- Pattern from tbc/ balance/rotation.go and OpenDruid2/specs/balance.lua.

local STARFIRE_MANA_FLOOR = 0.30   -- below this, switch to Wrath

local function try_adaptive_nuke(me, target, mana_pct)
    if me:is_moving() then return false end
    -- High mana: use Starfire (highest DPS)
    if mana_pct >= STARFIRE_MANA_FLOOR and runtime.starfire_id then
        if utils.can_cast_target(runtime.starfire_id, me, target) then
            if utils.cast_target(runtime.starfire_id, target, "Starfire") then
                return true
            end
        end
    end
    -- Low mana: fall back to Wrath (cheaper, instant cast for moving)
    if runtime.wrath_id then
        if utils.can_cast_target(runtime.wrath_id, me, target) then
            if utils.cast_target(runtime.wrath_id, target, "Wrath") then
                utils.log_debug(menu, "Wrath (mana conservation)")
                return true
            end
        end
    end
    return false
end


local function try_primary_nuke(me, target)
    if not is_valid_hostile_target(me, target) then return false end

    local spell_id, spell_name = get_primary_nuke_id(me)
    if not spell_id then return false end
    if is_pending_cast(spell_id) then return false end
    if not utils.can_cast_target(spell_id, me, target) then return false end

    if utils.cast_target(spell_id, me, target) then
        mark_pending_cast(spell_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, spell_name)
        note_cast()
                esp_renderer.on_cast(runtime.spell_id, "Starfire", color.purple(220))
        return true
    end

    return false
end

local function update_rotation(me, target, menu, utils)
    if mana_conservator.on_update(me, target, menu, utils) then return end

    if not is_gcd_ready() then return false end

    ttd_tracker.update(target)
    local mode = get_effective_mode()
    local mana_pct = utils.get_mana_pct(me)
    local enemy_count = utils.enemy_count_in_radius(me, 12)

    if try_innervate(me, mana_pct) then return true end
    if try_moonkin_form(me) then return true end
    if try_tranquility(me) then return true end

    if not is_valid_hostile_target(me, target) then
        return false
    end

    if try_faerie_fire(me, target) then return true end
    if try_moonfire(me, target) then return true end
    if try_insect_swarm(me, target) then return true end
    if try_force_of_nature(me, target, mana_pct) then return true end
    if try_hurricane(me, enemy_count, mana_pct) then return true end
    if try_starfall(me, enemy_count, mode) then return true end
    if try_primary_nuke(me, target) then return true end
    if try_adaptive_nuke(me, target, mana_pct) then return true end

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

    if utils.throttle("eaxdruidbalance_mode_refresh", 5.0) then
        runtime.cached_mode = detect_mode(me)
    end

    if utils.throttle("eaxdruidbalance_set_bonus", 10.0) then
        update_set_bonus(me)
    end

    handle_toggle()

    if not menu.enabled:get_state() then return end

    -- OOC management (drink/eat/rez/group buffs)
    ooc_manager.on_update(me, menu, utils, {
        rez_spell_id = runtime.rebirth_id,
        group_buffs = {
            { spell_id = utils.resolve_spell_id(spells.MARK_OF_THE_WILD),
               buff_ids = spells.BUFF_MARK_OF_THE_WILD,
               name = "Mark Of The Wild",
               toggle = menu.ooc_group_buff },
        },
    })
    if me:is_dead() then return end
    if eax_utils.is_eating_or_drinking(me) then return end

    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    local target = focus_target or me:get_target()


    -- Wanding / mana conservation (leveling 1-70)
    if leveling_manager.try_wand(me, target, menu) then return true end
    if not leveling_manager.has_enough_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
        return false
    end
    -- Encounter policy (boss-specific rotation adjustments)
    local enc = encounter_manager.get_policy(me)

    -- Interrupt
    if target and target:is_valid() and target:is_enemy() and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "druid", utils) then
            return
        end
    end

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)

    -- Defensive abilities
    if defensive_manager.try_defensive(me, "druid", utils) then
        return
    end

    -- Self-emergency healing
    local self_threshold = eax_utils.get_self_heal_threshold(me, menu.tranquility_hp_pct:get() / 100.0, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_tranquility(me) then return end
    end

    update_rotation(me, target, menu, utils)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxdruidbalance_space_win")
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
        local label = "EAX Druid Balance] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxdruidbalance_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_bal_cds = menu.use_cooldowns:get_state()
            local nxt_bal_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX Bal] Cooldowns", cur_bal_cds, 0, false, "eax_bal_cds_cp")
            if nxt_bal_cds ~= cur_bal_cds then menu.use_cooldowns:set(nxt_bal_cds) end
        end
        if menu.focus_priority then
            local cur_bal_focus = menu.focus_priority:get_state()
            local nxt_bal_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX Bal] Focus Priority", cur_bal_focus, 0, false, "eax_bal_focus_cp")
            if nxt_bal_focus ~= cur_bal_focus then menu.focus_priority:set(nxt_bal_focus) end
        end
        if menu.use_racial then
            local cur_bal_racial = menu.use_racial:get_state()
            local nxt_bal_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX Bal] Use Racial", cur_bal_racial, 0, false, "eax_bal_racial_cp")
            if nxt_bal_racial ~= cur_bal_racial then menu.use_racial:set(nxt_bal_racial) end
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
    local _eax_spec  = "Balance"
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
core.log("[EAX Druid Balance] Loaded " .. (_pi and _pi.plugin_version or "?"))
