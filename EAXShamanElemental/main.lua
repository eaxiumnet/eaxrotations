-- main.lua
-- EAX Shaman Elemental | Rotation driver
-- APIs validated against core, object_manager, and spellbook docs

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

---@type interrupt_manager
local interrupt_manager = require("common/eax_shared/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("common/eax_shared/ooc_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type encounter_manager
local encounter_manager = require("common/eax_shared/encounter_manager")
---@type totem_manager
local totem_manager = require("common/eax_shared/totem_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("elemental", "Shaman Ele")
---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("common/eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("common/eax_shared/defensive_manager")

---@type mana_conservator
local mana_conservator = require("mana_conservator")

---@type key_helper
---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")
---@type color
local color = require("color")

local GCD_INTERVAL = 1.5  -- actual TBC GCD duration
local MODE_REFRESH_INTERVAL = 4.5
local PENDING_CAST_TIMEOUT_S = 2.5  -- covers cast time + travel

local MODE_PROFILE = {
    solo = {
        aoe_threshold = 2,
        mana_floor = 10,
        chain_lightning_mana = 35,
        range_min = 0,
        range_max = 32,
        execute_hp = 0,
    },
    dungeon = {
        aoe_threshold = 3,
        mana_floor = 18,
        chain_lightning_mana = 45,
        range_min = 0,
        range_max = 33,
        execute_hp = 40,
    },
    raid = {
        aoe_threshold = 4,
        mana_floor = 22,
        chain_lightning_mana = 55,
        range_min = 0,
        range_max = 34,
        execute_hp = 50,
    },
}

local runtime = {
    ancestral_spirit_id = nil,
    lightning_bolt_id = nil,
    chain_lightning_id = nil,
    flame_shock_id = nil,
    elemental_mastery_id = nil,
    lava_burst_id = nil,
    natures_swiftness_id = nil,
    totem_of_wrath_id = nil,
    mana_spring_id = nil,
    wind_shear_id = nil,
    water_shield_id     = nil,
    lightning_shield_id = nil,
    healing_wave_id     = nil,
    ghost_wolf_id       = nil,
    totemic_call_id     = nil,
    last_cast_time = 0,
    pending_casts = {},
    cached_mode = "solo",
    prev_toggle_state = false,
    totem_last_apply = {},
    last_ns_at = 0,
    set_multiplier = 1.0,
}

local TOTEM_ROTATION = {
    { name = "wrath", id_field = "totem_of_wrath_id", toggle = menu.auto_totem_wrath, label = "Totem of Wrath" },
    { name = "mana_spring", id_field = "mana_spring_id", toggle = menu.auto_totem_mana, label = "Mana Spring Totem" },
}

local function resolve_spells()
    runtime.earth_shock_id  = utils.resolve_spell_id(spells.EARTH_SHOCK)
    runtime.frost_shock_id  = utils.resolve_spell_id(spells.FROST_SHOCK)
    runtime.lightning_bolt_id = utils.resolve_spell_id(spells.LIGHTNING_BOLT)
    runtime.chain_lightning_id = utils.resolve_spell_id(spells.CHAIN_LIGHTNING)
    runtime.flame_shock_id = utils.resolve_spell_id(spells.FLAME_SHOCK)
    runtime.elemental_mastery_id = utils.resolve_spell_id(spells.ELEMENTAL_MASTERY)
    runtime.lava_burst_id         = utils.resolve_spell_id(spells.LAVA_BURST)
    runtime.natures_swiftness_id = utils.resolve_spell_id(spells.NATURES_SWIFTNESS)
    runtime.totem_of_wrath_id = utils.resolve_spell_id(spells.TOTEM_OF_WRATH)
    runtime.mana_spring_id = utils.resolve_spell_id(spells.MANA_SPRING_TOTEM)
    runtime.wind_shear_id       = utils.resolve_spell_id(spells.WINDSHEAR)
    runtime.water_shield_id     = utils.resolve_spell_id(spells.WATER_SHIELD)
    runtime.lightning_shield_id = utils.resolve_spell_id(spells.LIGHTNING_SHIELD)
    runtime.healing_wave_id     = utils.resolve_spell_id(spells.HEALING_WAVE)
    runtime.ghost_wolf_id       = utils.resolve_spell_id(spells.GHOST_WOLF)
    runtime.totemic_call_id     = utils.resolve_spell_id(spells.TOTEMIC_CALL)
    runtime.ancestral_spirit_id  = utils.resolve_spell_id(spells.ANCESTRAL_SPIRIT)
end

local function log_resolved_spells()
    utils.log_debug(menu, "Spells resolved: LB=" .. tostring(runtime.lightning_bolt_id)
        .. " CL=" .. tostring(runtime.chain_lightning_id)
        .. " FS=" .. tostring(runtime.flame_shock_id)
        .. " EM=" .. tostring(runtime.elemental_mastery_id))
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
    if selection == 2 then
        return "solo"
    elseif selection == 3 then
        return "dungeon"
    elseif selection == 4 then
        return "raid"
    end
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
    if not totem_manager.can_cast_spell(label) then
        totem_manager.try_workaround(me, label)
        return false
    end
    if is_pending_cast(spell_id) then
        return false
    end
    if not utils.cast_target(spell_id, target, nil) then
        return false
    end
    mark_pending_cast(spell_id)
    note_cast()
    local target_name = target:get_name() or "?"
    esp_renderer.on_cast(spell_id, label, color.cyan(220), target_name)
    utils.log_debug(menu, label .. " cast")
    return true
end

local function try_cast_self(me, spell_id, label)
    if not spell_id or not me or not me:is_valid() then
        return false
    end
    if is_pending_cast(spell_id) then
        return false
    end
    if not totem_manager.can_cast_spell(label) then
        totem_manager.try_workaround(me, label)
        return false
    end
    if not utils.can_cast_self(spell_id, me) then
        return false
    end
    if not utils.cast_self(spell_id, me) then
        return false
    end
    mark_pending_cast(spell_id)
    note_cast()
    esp_renderer.on_cast(spell_id, label, color.cyan(220), "Self")
    utils.log_debug(menu, label .. " cast")
    return true
end

local function ensure_totems(me)
    if not menu.auto_totems:get_state() then
        return
    end
    local now = core.time()
    local interval = menu.totem_twist_interval:get()
    for _, entry in ipairs(TOTEM_ROTATION) do
        if entry.toggle:get_state() then
            local spell_id = runtime[entry.id_field]
            if spell_id and utils.can_cast_self(spell_id, me) then
                local last = runtime.totem_last_apply[entry.name] or 0
                if (now - last) >= interval then
                    if try_cast_self(me, spell_id, entry.label) then
                        runtime.totem_last_apply[entry.name] = now
                    end
                end
            end
        end
    end
end


local function try_earth_shock_interrupt(me, target)
    if not menu.use_earth_shock or not menu.use_earth_shock:get_state() then return false end
    if not runtime.earth_shock_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    local ok, casting = pcall(function() return target:is_casting_spell() end)
    local ok2, channing = pcall(function() return target:is_channelling_spell() end)
    if not ((ok and casting) or (ok2 and channing)) then return false end
    if not utils.can_cast_hostile(runtime.earth_shock_id, me, target) then return false end
    if utils.cast_target(runtime.earth_shock_id, target) then
        utils.log_debug(menu, "Earth Shock (interrupt)")
        return true
    end
    return false
end

local function try_frost_shock_slow(me, target)
    if not menu.use_frost_shock or not menu.use_frost_shock:get_state() then return false end
    if not runtime.frost_shock_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    -- Use frost shock to slow melee attackers chasing us
    local ok, moving = pcall(function() return target:is_moving() end)
    if not (ok and moving) then return false end
    if not utils.can_cast_hostile(runtime.frost_shock_id, me, target) then return false end
    if utils.cast_target(runtime.frost_shock_id, target) then
        utils.log_debug(menu, "Frost Shock (slow)")
        return true
    end
    return false
end

local function try_burst(me, target)
    if not menu.use_cooldowns:get_state() then
        return false
    end
    local profile = get_mode_profile()
    local mode = get_effective_mode()
    local target_hp = target and target:is_valid() and not target:is_dead() and utils.get_health_pct(target) or 0
    if runtime.elemental_mastery_id and (target and (target:is_boss() or mode == "raid" or target_hp >= 0.9)) then
        if try_cast_self(me, runtime.elemental_mastery_id, "Elemental Mastery") then
            return true
        end
    end
    local now = core.time()
    if runtime.natures_swiftness_id and (now - runtime.last_ns_at) > 10 and target_hp > (profile.execute_hp or 0) / 100 then
        if try_cast_self(me, runtime.natures_swiftness_id, "Nature's Swiftness") then
            runtime.last_ns_at = now
            return true
        end
    end
    return false
end

local _flame_shock_last_applied = {}  -- [target_guid] = timestamp
local FLAME_SHOCK_DURATION = 12.0    -- seconds (TBC Rank 8)

local function try_flame_shock(me, target)
    if not menu.use_flame_shock:get_state() or not runtime.flame_shock_id then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if target:is_moving() then
        return false
    end
    -- Check debuff via buff_manager; also use time-based fallback for dummies/immune targets
    local has_fs = utils.has_debuff(target, spells.BUFF_FLAME_SHOCK)
    if not has_fs then
        -- Time-based fallback: don't reapply if we applied recently
        local guid = tostring(target)
        local last = _flame_shock_last_applied[guid] or 0
        if (core.time() - last) < (FLAME_SHOCK_DURATION - 2) then
            return false
        end
    else
        return false
    end
    local target_hp = utils.get_health_pct(target)
    local stop_pct = math.max(menu.flame_shock_stop_hp:get(), get_mode_profile().execute_hp) / 100
    if target_hp <= stop_pct then
        return false
    end
    local guid = tostring(target)
    if try_cast_target(me, target, runtime.flame_shock_id, "Flame Shock") then
        _flame_shock_last_applied[guid] = core.time()
        return true
    end
    return false
end

local function try_chain_lightning(me, target)
    if enc and not enc.aoe_safe then return false end
    if not runtime.chain_lightning_id or not target then
        return false
    end
    local profile = get_mode_profile()
    local threshold = math.max(menu.aoe_threshold:get(), profile.aoe_threshold)
    local enemy_count = utils.count_enemies_in_range(me, spells.CHAIN_LIGHTNING_RADIUS)
    if enemy_count < threshold then
        return false
    end
    local mana_pct = utils.get_mana_pct(me)
    local mana_cutoff = math.max(menu.chain_lightning_mana:get(), profile.chain_lightning_mana) / 100
    if mana_pct < mana_cutoff then
        return false
    end
    return try_cast_target(me, target, runtime.chain_lightning_id, "Chain Lightning")
end

local function try_lightning_bolt(me, target)
    if not runtime.lightning_bolt_id or not target then
        return false
    end
    local profile = get_mode_profile()
    local mana_pct = utils.get_mana_pct(me)
    local mana_floor = math.max(menu.mana_floor:get(), profile.mana_floor) / 100
    if mana_pct < mana_floor then
        return false
    end
    local target_hp = utils.get_health_pct(target)
    local execute_cutoff = math.max(menu.execute_hp:get(), profile.execute_hp) / 100
    if target_hp <= execute_cutoff then
        return false
    end
    local distance = utils.get_distance(me, target)
    local min_range = math.max(menu.range_min:get(), profile.range_min)
    local max_range = math.max(menu.range_max:get(), profile.range_max)
    if distance < min_range or distance > max_range then
        return false
    end
    return try_cast_target(me, target, runtime.lightning_bolt_id, "Lightning Bolt")
end


-- --- Lava Burst (v1.2) ----------------------------------------------------

local function try_lava_burst(me, target)
    if not runtime.lava_burst_id then return false end   -- nil if not talented/trained
    -- Lava Burst deals guaranteed crit when Flame Shock is on target
    if not utils.has_debuff(target, spells.DEBUFF_FLAME_SHOCK) then return false end
    return try_cast_target(me, target, runtime.lava_burst_id, "Lava Burst")
end



-- -- Shield maintenance --------------------------------------------------------
local function ensure_shield(me)
    local mode = menu.shield_mode and menu.shield_mode:get() or 2
    -- 0=None, 1=Lightning, 2=Water, 3=Auto(Water at 60+)
    if mode == 0 then return false end
    local use_water
    if mode == 1 then use_water = false
    elseif mode == 2 then use_water = true
    else use_water = (me:get_level() or 0) >= 60 end

    if use_water and runtime.water_shield_id then
        if not utils.has_buff(me, spells.BUFF_WATER_SHIELD) then
            return try_cast_self(me, runtime.water_shield_id, "Water Shield")
        end
    elseif not use_water and runtime.lightning_shield_id then
        if not utils.has_buff(me, spells.BUFF_LIGHTNING_SHIELD) then
            return try_cast_self(me, runtime.lightning_shield_id, "Lightning Shield")
        end
    end
    return false
end

-- -- Self-healing --------------------------------------------------------------
local function try_self_heal(me)
    if not menu.use_healing_wave or not menu.use_healing_wave:get_state() then return false end
    if not runtime.healing_wave_id then return false end
    local hp_pct = utils.get_health_pct(me)
    local threshold = (menu.healing_wave_hp and menu.healing_wave_hp:get() or 35) / 100
    if hp_pct > threshold then return false end
    return try_cast_self(me, runtime.healing_wave_id, "Healing Wave")
end

-- -- Ghost Wolf OOC ------------------------------------------------------------
local GHOST_WOLF_BUFF = { 2645 }
local function try_ghost_wolf(me)
    if not menu.use_ghost_wolf or not menu.use_ghost_wolf:get_state() then return false end
    if not runtime.ghost_wolf_id then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, GHOST_WOLF_BUFF) then return false end
    -- Block if eating, drinking, or any cast in progress
    if eax_utils.is_eating_or_drinking(me) then return false end
    local ok, casting = pcall(function() return me:is_casting_spell() end)
    if ok and casting then return false end
    local ok2, channing = pcall(function() return me:is_channelling_spell() end)
    if ok2 and channing then return false end
    return try_cast_self(me, runtime.ghost_wolf_id, "Ghost Wolf")
end

-- -- Totemic Call (recall for mana refund) -------------------------------------
local last_totemic_call = 0
local TOTEMIC_CALL_CD = 2.0
local function try_totemic_call(me)
    if not menu.use_totemic_call or not menu.use_totemic_call:get_state() then return false end
    if not runtime.totemic_call_id then return false end
    if (core.time() - last_totemic_call) < TOTEMIC_CALL_CD then return false end
    -- Only recall if not in combat and mana is below 50%
    if me:is_in_combat() then return false end
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct > 0.5 then return false end
    -- Check if any totems are active
    local has_totem = false
    for slot = 1, 4 do
        local ok, info = pcall(function() return core.spell_book.get_totem_info(slot) end)
        if ok and info and info.have_totem then has_totem = true; break end
    end
    if not has_totem then return false end
    if utils.can_cast_self(runtime.totemic_call_id, me) then
        if utils.cast_self(runtime.totemic_call_id, me) then
            last_totemic_call = core.time()
            esp_renderer.on_cast(runtime.totemic_call_id, "Totemic Call", color.gold(220), "Self")
            return true
        end
    end
    return false
end

local function do_rotation(me, target)
    -- Lazy re-resolve: spells may not be learned yet at plugin load time
    if not runtime.lightning_bolt_id then resolve_spells() end
    -- Shield maintenance (always, even when GCD not ready)
    ensure_shield(me)
    -- Emergency self-heal
    if try_self_heal(me) then return true end

    if mana_conservator.on_update(me, target, menu, utils) then return end

    if not is_gcd_ready() then
        return false
    end
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "shaman", utils) then
        return true
        end
    end


    -- Wanding / mana conservation (leveling 1-70)
    if leveling_manager.try_wand(me, target, menu) then return true end
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    -- Defensive abilities
    ttd_tracker.update(target)

    if defensive_manager.try_defensive(me, "shaman", utils) then
        return true
    end

    ensure_totems(me)
    if try_earth_shock_interrupt(me, target) then return true end
    if try_frost_shock_slow(me, target) then return true end
    if try_burst(me, target) then return true end
    if try_lava_burst(me, target) then return true end
    if try_flame_shock(me, target) then
        return true
    end
    if try_chain_lightning(me, target) then
        return true
    end
    if try_lightning_bolt(me, target) then
        return true
    end
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

local function update_set_bonus()
    local me = core.object_manager.get_local_player()
    if not me then return end
    
    local cyclone_mult = utils.get_set_multiplier(me, "Cyclone")
    local cataclysm_mult = utils.get_set_multiplier(me, "Cataclysm")
    local skyshatter_mult = utils.get_set_multiplier(me, "Skyshatter")
    
    runtime.set_multiplier = cyclone_mult
    if cataclysm_mult > runtime.set_multiplier then
        runtime.set_multiplier = cataclysm_mult
    end
    if skyshatter_mult > runtime.set_multiplier then
        runtime.set_multiplier = skyshatter_mult
    end
    
    if runtime.set_multiplier > 1.0 then
        utils.log_debug(menu, "Set bonus: " .. tostring(runtime.set_multiplier))
    end
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
    if utils.throttle("mode_refresh", MODE_REFRESH_INTERVAL) then
        refresh_mode_cache()
    end
    if utils.throttle("set_bonus", 5.0) then
        update_set_bonus()
    end
    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end
    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then
        return
    end
        ooc_manager.on_update(me, menu, utils)
    if eax_utils.is_eating_or_drinking(me) then return end
    
    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    -- Validate focus target is hostile; if not, fall through to smart selector
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    -- Smart target selection: prioritize units actively fighting us/party
    local target = focus_target or utils.find_best_target(me)
    
    -- OOC: ghost wolf, totemic call
    if not me:is_in_combat() then
        try_ghost_wolf(me)
        try_totemic_call(me)
    end

    do_rotation(me, target)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxshamanelemental_space_win")
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
        local current = menu.enabled:get_state()
        local toggle_key = menu.toggle_key:get_key_code()
        local label = "[EAX Shaman Elemental] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        local function add_cb(lbl, item, uid)
            if not item then return end
            local cur = item:get_state()
            local nxt = control_panel_utility:insert_key_checkbox_(elements, lbl, cur, 0, false, uid)
            if nxt ~= cur then item:set(nxt) end
        end
        local function add_kb(lbl, kb)
            if not kb then return end
            control_panel_utility:insert_toggle_(elements, lbl, kb, false)
        end
        add_cb(label,                           menu.enabled,         "eax_ele_enabled_cp")
        if menu.enabled:get_state() then
            add_kb("[EAX Ele] Cooldowns Key",       menu.cooldowns_key)
            add_cb("[EAX Ele] Use Cooldowns",       menu.use_cooldowns,    "eax_ele_cds_cp")
            add_cb("[EAX Ele] Auto Totems",         menu.auto_totems,      "eax_ele_totems_cp")
            add_cb("[EAX Ele] Flame Shock",         menu.use_flame_shock,  "eax_ele_fs_cp")
            add_cb("[EAX Ele] Self-Heal",           menu.use_healing_wave, "eax_ele_hw_cp")
            add_cb("[EAX Ele] Ghost Wolf",          menu.use_ghost_wolf,   "eax_ele_gw_cp")
            add_cb("[EAX Ele] Totemic Call",        menu.use_totemic_call, "eax_ele_tc_cp")
            add_cb("[EAX Ele] Focus Priority",      menu.focus_priority,   "eax_ele_focus_cp")
            add_cb("[EAX Ele] Use Racial",          menu.use_racial,       "eax_ele_racial_cp")
        end
        return elements
    end)
end



-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Shaman"
    local _eax_spec  = "Elemental"
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

core.log("[EAX Shaman Elemental] Loaded")
