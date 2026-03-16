-- main.lua
-- EAX Shaman Enhancement | Stormstrike-driven melee
-- APIs validated against core, object_manager, and spellbook docs

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
---@type color
local color = require("common/color")

local GCD_INTERVAL = 0.05
local MODE_REFRESH_INTERVAL = 4.5
local PENDING_CAST_TIMEOUT_S = 1.25
local dev_id = "eax_shaman_enhancement_"

local MODE_PROFILE = {
    solo = { aoe_threshold = 2, mana_floor = 5, swing_clip_ms = 140 },
    dungeon = { aoe_threshold = 3, mana_floor = 10, swing_clip_ms = 160 },
    raid = { aoe_threshold = 4, mana_floor = 15, swing_clip_ms = 170 },
}

local runtime = {
    stormstrike_id = nil,
    shamanistic_rage_id = nil,
    earth_shock_id = nil,
    flame_shock_id = nil,
    frost_shock_id = nil,
    chain_lightning_id = nil,
    lightning_bolt_id = nil,
    totem_of_wrath_id = nil,
    windfury_totem_id = nil,
    wind_shear_id = nil,
    last_cast_time = 0,
    pending_casts = {},
    cached_mode = "solo",
    prev_toggle_state = false,
    last_stormstrike_at = 0,
    totem_last_apply = {},
}

local TOTEM_ROTATION = {
    { name = "wrath", id_field = "totem_of_wrath_id", toggle = menu.auto_totem_wrath, label = "Totem of Wrath" },
    { name = "windfury", id_field = "windfury_totem_id", toggle = menu.auto_totem_windfury, label = "Windfury Totem" },
}

local SHOCK_TABLE = {
    [1] = { id_field = "earth_shock_id", debuff = spells.EARTH_SHOCK, label = "Earth Shock" },
    [2] = { id_field = "flame_shock_id", debuff = spells.FLAME_SHOCK, label = "Flame Shock" },
    [3] = { id_field = "frost_shock_id", debuff = spells.FROST_SHOCK, label = "Frost Shock" },
}

local function resolve_spells()
    runtime.stormstrike_id = utils.resolve_spell_id(spells.STORMSTRIKE)
    runtime.shamanistic_rage_id = utils.resolve_spell_id(spells.SHAMANISTIC_RAGE)
    runtime.earth_shock_id = utils.resolve_spell_id(spells.EARTH_SHOCK)
    runtime.flame_shock_id = utils.resolve_spell_id(spells.FLAME_SHOCK)
    runtime.frost_shock_id = utils.resolve_spell_id(spells.FROST_SHOCK)
    runtime.chain_lightning_id = utils.resolve_spell_id(spells.CHAIN_LIGHTNING)
    runtime.lightning_bolt_id = utils.resolve_spell_id(spells.LIGHTNING_BOLT)
    runtime.totem_of_wrath_id = utils.resolve_spell_id(spells.TOTEM_OF_WRATH)
    runtime.windfury_totem_id = utils.resolve_spell_id(spells.WINDFURY_TOTEM)
    runtime.wind_shear_id = utils.resolve_spell_id(spells.WINDSHEAR)
end

local function log_resolved_spells()
    utils.log_debug(menu, "Resolved Stormstrike=" .. tostring(runtime.stormstrike_id))
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
    local selection = menu.mode:get()
    if selection == 2 then return "solo" end
    if selection == 3 then return "dungeon" end
    if selection == 4 then return "raid" end
    return runtime.cached_mode
end

local function get_mode_profile()
    local mode = get_effective_mode()
    return MODE_PROFILE[mode] or MODE_PROFILE.solo
end

local function mark_pending_cast(spell_id, timeout)
    if not spell_id then return end
    runtime.pending_casts[spell_id] = {
        requested_at = core.time(),
        timeout_s = timeout or PENDING_CAST_TIMEOUT_S,
    }
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

local function note_cast()
    runtime.last_cast_time = core.time()
end

local function is_gcd_ready()
    if (core.time() - runtime.last_cast_time) < GCD_INTERVAL then
        return false
    end
    return core.spell_book.get_global_cooldown() <= 0
end

local function try_cast_target(me, target, spell_id, label)
    if not spell_id or not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if not utils.is_valid_hostile(me, target) then
        return false
    end
    if is_pending_cast(spell_id) then
        return false
    end
    if not utils.cast_target(spell_id, me, target) then
        return false
    end
    mark_pending_cast(spell_id)
    note_cast()
    utils.log_debug(menu, label .. " cast")
    return true
end

local function try_cast_self(me, spell_id, label)
    if not spell_id or not me or not me:is_valid() then return false end
    if is_pending_cast(spell_id) then return false end
    if not utils.can_cast_self(spell_id, me) then return false end
    if not utils.cast_self(spell_id, me) then return false end
    mark_pending_cast(spell_id)
    note_cast()
    utils.log_debug(menu, label .. " cast")
    return true
end

local function ensure_totems(me)
    if not menu.auto_totems:get_state() then return end
    local now = core.time()
    for _, entry in ipairs(TOTEM_ROTATION) do
        if entry.toggle:get_state() then
            local spell_id = runtime[entry.id_field]
            if spell_id and utils.can_cast_self(spell_id, me) then
                local last = runtime.totem_last_apply[entry.name] or 0
                if (now - last) >= 30 then
                    if try_cast_self(me, spell_id, entry.label) then
                        runtime.totem_last_apply[entry.name] = now
                    end
                end
            end
        end
    end
end

local function try_shamanistic_rage(me)
    if not menu.use_cooldowns:get_state() or not runtime.shamanistic_rage_id then
        return false
    end
    local hp_pct = utils.get_health_pct(me)
    local mana_pct = utils.get_mana_pct(me)
    if hp_pct <= (menu.shamanistic_rage_hp:get() / 100) or mana_pct <= (menu.shamanistic_rage_mana:get() / 100) then
        return try_cast_self(me, runtime.shamanistic_rage_id, "Shamanistic Rage")
    end
    return false
end

local function try_stormstrike(me, target)
    if not runtime.stormstrike_id or not target then return false end
    if not utils.is_melee_target(me, target) then return false end
    if try_cast_target(me, target, runtime.stormstrike_id, "Stormstrike") then
        runtime.last_stormstrike_at = core.time()
        return true
    end
    return false
end

local function should_chain_lightning_weave()
    if runtime.last_stormstrike_at == 0 then
        return false
    end
    local profile = get_mode_profile()
    local now = core.time()
    local clip_window = math.max(menu.swing_clip_ms:get(), profile.swing_clip_ms) / 1000
    return (now - runtime.last_stormstrike_at) >= clip_window
end

local function try_chain_lightning_weave(me, target)
    if not menu.use_chain_lightning_weave:get_state() or not runtime.chain_lightning_id or not target then
        return false
    end
    if not should_chain_lightning_weave() then return false end
    local profile = get_mode_profile()
    local enemies = utils.count_enemies_in_range(me, spells.CHAIN_LIGHTNING_RADIUS)
    if enemies < profile.aoe_threshold then return false end
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct < (profile.mana_floor / 100) then return false end
    return try_cast_target(me, target, runtime.chain_lightning_id, "Chain Lightning")
end

local function try_shock(me, target)
    if not target or not utils.is_valid_hostile(me, target) then
        return false
    end
    local shock_index = menu.shock_mode:get()
    local shock_entry = SHOCK_TABLE[shock_index]
    if not shock_entry then return false end
    local spell_id = runtime[shock_entry.id_field]
    if not spell_id then return false end
    if utils.has_debuff(target, shock_entry.debuff) then return false end
    return try_cast_target(me, target, spell_id, shock_entry.label)
end

local function do_rotation(me, target)
    if not is_gcd_ready() then return false end
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "shaman", utils) then
            return true
        end
    end
    ensure_totems(me)
    if try_shamanistic_rage(me) then return true end
    if try_stormstrike(me, target) then return true end
    if try_chain_lightning_weave(me, target) then return true end
    if try_shock(me, target) then return true end
    return false
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        local enabled = menu.enabled:get_state()
        menu.enabled:set(not enabled)
        utils.log_debug(menu, "Toggle -> " .. tostring(not enabled))
    end
    runtime.prev_toggle_state = current
end

resolve_spells()
log_resolved_spells()

core.register_on_update_callback(function()
    if utils.throttle("mode_refresh", MODE_REFRESH_INTERVAL) then
        refresh_mode_cache()
    end
    handle_toggle()
    if not menu.enabled:get_state() then return end
    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then return end
    local focus_target = eax_utils.get_focus_target(menu)
    local target = focus_target or me:get_target()
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = utils.get_health_pct(me)
    if my_hp < self_threshold then
        -- Enhancement self-heal: use Lesser Healing Wave if learned, else skip
        -- (Shamanistic Rage handles mana-based self-sustain; NS is not in this rotation)
        local lhw_id = utils.resolve_spell_id({ 25420, 10468, 10467, 10466, 8010, 8008, 8004 })
        if lhw_id and utils.can_cast_self(lhw_id, me) then
            utils.cast_self(lhw_id, me)
        end
    end
    do_rotation(me, target)
end)

core.register_on_render_menu_callback(function()
    menu.render()
end)

core.register_on_render_control_panel_callback(function()
    local elements = {}
    local toggle_key = menu.toggle_key:get_key_code()
    local label = "[EAX Shaman Enhancement] Toggle (" .. key_helper:get_key_name(toggle_key) .. ")"
    control_panel_utility:insert_toggle_(elements, label, menu.toggle_key)

    local function add_checkbox(name, menu_item)
        if not menu_item then return end
        local current = menu_item:get_state()
        local new_state = control_panel_utility:insert_key_checkbox_(
            elements, name, current, 0, false, dev_id .. name
        )
        if new_state ~= current then
            menu_item:set(new_state)
        end
    end

    add_checkbox("Enabled", menu.enabled)
    add_checkbox("Use Cooldowns", menu.use_cooldowns)
    add_checkbox("Auto Totems", menu.auto_totems)
    add_checkbox("Chain Lightning Weave", menu.use_chain_lightning_weave)

    return elements
end)

core.log("[EAX Shaman Enhancement] Loaded")
