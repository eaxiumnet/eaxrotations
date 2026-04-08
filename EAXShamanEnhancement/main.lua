-- Eax Shaman Enhancement | main.lua
-- Enhancement Shaman rotation: Stormstrike, shocks, totem twisting, melee weaving

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local buff_manager = require("common/modules/buff_manager")
local spell_queue = require("common/modules/spell_queue")
local ooc_manager = require("libraries/ooc_manager")
local burst_manager = require("libraries/burst_manager")
local trinket_manager = require("libraries/trinket_manager")

-- Flux Feature Integration
local combat_forecast = require("libraries/combat_forecast")
local force_commands = require("libraries/force_commands")
local swing_manager = require("libraries/swing_manager")

-- Runtime spell cache
local runtime = {
    stormstrike_id = nil,
    earth_shock_id = nil,
    flame_shock_id = nil,
    frost_shock_id = nil,
    shamanistic_rage_id = nil,
    fire_elemental_totem_id = nil,
    -- Totems
    searing_totem_id = nil,
    magma_totem_id = nil,
    fire_nova_totem_id = nil,
    flametongue_totem_id = nil,
    strength_of_earth_id = nil,
    stoneskin_totem_id = nil,
    tremor_totem_id = nil,
    mana_spring_totem_id = nil,
    healing_stream_totem_id = nil,
    windfury_totem_id = nil,
    grace_of_air_totem_id = nil,
    wrath_of_air_totem_id = nil,
    -- Shields
    lightning_shield_id = nil,
    water_shield_id = nil,
    -- Weapon imbues
    windfury_weapon_id = nil,
    flametongue_weapon_id = nil,
    -- Utility
    ghost_wolf_id = nil,
    blood_fury_ap_id = nil,
    berserking_id = nil,
    -- Totem twist state
    wf_twist = { phase = "windfury", last_wf_time = 0, last_default_time = 0, initialized = false },
    fnt_twist = { phase = "idle", last_drop_time = 0 },
    last_combat_state = false,
    combat_start_time = nil,
}

-- Resolve spells on load
local function resolve_spells()
    runtime.stormstrike_id = utils.resolve_spell_id(spells.STORMSTRIKE)
    runtime.earth_shock_id = utils.resolve_spell_id(spells.EARTH_SHOCK)
    runtime.flame_shock_id = utils.resolve_spell_id(spells.FLAME_SHOCK)
    runtime.frost_shock_id = utils.resolve_spell_id(spells.FROST_SHOCK)
    runtime.shamanistic_rage_id = utils.resolve_spell_id(spells.SHAMANISTIC_RAGE)
    runtime.fire_elemental_totem_id = utils.resolve_spell_id(spells.FIRE_ELEMENTAL_TOTEM)
    
    runtime.searing_totem_id = utils.resolve_spell_id(spells.SEARING_TOTEM)
    runtime.magma_totem_id = utils.resolve_spell_id(spells.MAGMA_TOTEM)
    runtime.fire_nova_totem_id = utils.resolve_spell_id(spells.FIRE_NOVA_TOTEM)
    runtime.flametongue_totem_id = utils.resolve_spell_id(spells.FLAMETONGUE_TOTEM)
    
    runtime.strength_of_earth_id = utils.resolve_spell_id(spells.STRENGTH_OF_EARTH_TOTEM)
    runtime.stoneskin_totem_id = utils.resolve_spell_id(spells.STONESKIN_TOTEM)
    runtime.tremor_totem_id = utils.resolve_spell_id(spells.TREMOR_TOTEM)
    
    runtime.mana_spring_totem_id = utils.resolve_spell_id(spells.MANA_SPRING_TOTEM)
    runtime.healing_stream_totem_id = utils.resolve_spell_id(spells.HEALING_STREAM_TOTEM)
    
    runtime.windfury_totem_id = utils.resolve_spell_id(spells.WINDFURY_TOTEM)
    runtime.grace_of_air_totem_id = utils.resolve_spell_id(spells.GRACE_OF_AIR_TOTEM)
    runtime.wrath_of_air_totem_id = utils.resolve_spell_id(spells.WRATH_OF_AIR_TOTEM)
    
    runtime.lightning_shield_id = utils.resolve_spell_id(spells.LIGHTNING_SHIELD)
    runtime.water_shield_id = utils.resolve_spell_id(spells.WATER_SHIELD)
    
    runtime.windfury_weapon_id = utils.resolve_spell_id(spells.WINDFURY_WEAPON)
    runtime.flametongue_weapon_id = utils.resolve_spell_id(spells.FLAMETONGUE_WEAPON)
    
    runtime.ghost_wolf_id = utils.resolve_spell_id(spells.GHOST_WOLF)
    runtime.blood_fury_ap_id = utils.resolve_spell_id(spells.BLOOD_FURY_AP)
    runtime.berserking_id = utils.resolve_spell_id(spells.BERSERKING)
end

resolve_spells()

-- Initialize Flux force_commands
force_commands:init()

-- Hot-path caching
local _core_time = core.time

-- Pending cast tracking
local _pending_casts = {}
local function is_pending_cast(spell_id)
    if not spell_id then return false end
    local expire_time = _pending_casts[spell_id]
    if not expire_time then return false end
    if _core_time() > expire_time then
        _pending_casts[spell_id] = nil
        return false
    end
    return true
end

local function mark_pending_cast(spell_id, timeout)
    if not spell_id then return end
    _pending_casts[spell_id] = _core_time() + (timeout or 1.5)
end

-- Combat reset
local function check_combat_reset(in_combat)
    if runtime.last_combat_state and not in_combat then
        runtime.wf_twist.initialized = false
        runtime.wf_twist.phase = "windfury"
        runtime.fnt_twist.phase = "idle"
        runtime.combat_start_time = nil
    end
    runtime.last_combat_state = in_combat
end

-- Totem state
local totem_state = {
    fire_active = false, fire_remaining = 0,
    earth_active = false, earth_remaining = 0,
    water_active = false, water_remaining = 0,
    air_active = false, air_remaining = 0,
}

local function refresh_totem_state()
    local now = _core_time()
    for slot = 1, 4 do
        local ok, have, name, start, dur = pcall(function()
            local h, n, s, d = GetTotemInfo(slot)
            return h, n, s, d
        end)
        if ok then
            local active = have and name and name ~= ""
            local remaining = active and ((start + dur) - now) or 0
            if slot == 1 then
                totem_state.fire_active = active
                totem_state.fire_remaining = remaining
            elseif slot == 2 then
                totem_state.earth_active = active
                totem_state.earth_remaining = remaining
            elseif slot == 3 then
                totem_state.water_active = active
                totem_state.water_remaining = remaining
            elseif slot == 4 then
                totem_state.air_active = active
                totem_state.air_remaining = remaining
            end
        end
    end
end

-- Casting helpers
local function try_cast_self(spell_id, me, label)
    if not spell_id or not me then return false end
    if is_pending_cast(spell_id) then return false end
    if not utils.can_cast_self(spell_id, me) then return false end
    if utils.cast_self(spell_id, me) then
        mark_pending_cast(spell_id, 1.5)
        utils.log_debug(menu, label or "Self cast")
        return true
    end
    return false
end

local function try_cast_target(spell_id, me, target, label)
    if not spell_id or not me or not target then return false end
    if is_pending_cast(spell_id) then return false end
    if not utils.is_valid_hostile_target(me, target) then return false end
    if not utils.can_cast_hostile(spell_id, me, target) then return false end
    if utils.cast_target(spell_id, me, target) then
        mark_pending_cast(spell_id, 1.5)
        utils.log_debug(menu, label or "Target cast")
        return true
    end
    return false
end

-- Rotation functions
local function should_use_cds(target)
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    if min_ttd <= 0 or not target then return true end
    local forecast = require("libraries/combat_forecast")
    return forecast:is_valid_forecast_logic(min_ttd, target, false)
end

local function try_shamanistic_rage(me, target, is_burst_window)
    if not (menu.use_shamanistic_rage and menu.use_shamanistic_rage:get_state()) then return false end
    if not runtime.shamanistic_rage_id then return false end
    if not should_use_cds(target) then return false end

    -- If auto-burst is enabled, only use during burst window
    local auto_burst = (menu.auto_burst_enabled and menu.auto_burst_enabled:get()) or false
    if auto_burst and not is_burst_window then return false end

    local threshold = (menu.shamanistic_rage_pct and menu.shamanistic_rage_pct:get()) or 30
    local mana_pct = utils.get_mana_pct(me) * 100
    if mana_pct > threshold then return false end

    return try_cast_self(runtime.shamanistic_rage_id, me, "Shamanistic Rage")
end

local function try_racial(me, target)
    if not (menu.use_racial and menu.use_racial:get_state()) then return false end
    if not should_use_cds(target) then return false end
    
    if runtime.blood_fury_ap_id then
        local cd = core.spell_book.get_spell_cooldown(runtime.blood_fury_ap_id)
        if cd <= 0 and core.spell_book.is_usable_spell(runtime.blood_fury_ap_id) then
            return try_cast_self(runtime.blood_fury_ap_id, me, "Blood Fury (AP)")
        end
    end
    
    if runtime.berserking_id then
        local cd = core.spell_book.get_spell_cooldown(runtime.berserking_id)
        if cd <= 0 and core.spell_book.is_usable_spell(runtime.berserking_id) then
            return try_cast_self(runtime.berserking_id, me, "Berserking")
        end
    end
    return false
end

local function try_totem_management(me)
    if utils.is_moving(me) then return false end
    refresh_totem_state()
    
    local threshold = 10
    local s = {
        enh_fire_totem = (menu.enh_fire_totem and menu.enh_fire_totem:get()) or 1,
        enh_earth_totem = (menu.enh_earth_totem and menu.enh_earth_totem:get()) or 1,
        enh_water_totem = (menu.enh_water_totem and menu.enh_water_totem:get()) or 1,
        enh_air_totem = (menu.enh_air_totem and menu.enh_air_totem:get()) or 1,
    }
    
    -- Skip fire if FNT twist active
    local skip_fire = menu.enh_twist_fire_nova and menu.enh_twist_fire_nova:get_state()
    if not skip_fire and s.enh_fire_totem ~= 4 then
        if not totem_state.fire_active or totem_state.fire_remaining < threshold then
            local spell_id = nil
            if s.enh_fire_totem == 1 then spell_id = runtime.searing_totem_id
            elseif s.enh_fire_totem == 2 then spell_id = runtime.magma_totem_id
            elseif s.enh_fire_totem == 3 then spell_id = runtime.flametongue_totem_id
            end
            if spell_id and try_cast_self(spell_id, me, "Fire Totem") then return true end
        end
    end
    
    -- Earth
    if s.enh_earth_totem ~= 3 then
        local skip_earth = false
        if menu.use_auto_tremor and menu.use_auto_tremor:get_state() and totem_state.earth_active then
            local ok, name = pcall(function() local _, n = GetTotemInfo(2); return n end)
            if ok and name and name:find("Tremor") then skip_earth = true end
        end
        if not skip_earth then
            if not totem_state.earth_active or totem_state.earth_remaining < threshold then
                local spell_id = nil
                if s.enh_earth_totem == 1 then spell_id = runtime.strength_of_earth_id
                elseif s.enh_earth_totem == 2 then spell_id = runtime.stoneskin_totem_id
                end
                if spell_id and try_cast_self(spell_id, me, "Earth Totem") then return true end
            end
        end
    end
    
    -- Water
    if s.enh_water_totem ~= 3 then
        if not totem_state.water_active or totem_state.water_remaining < threshold then
            local spell_id = nil
            if s.enh_water_totem == 1 then spell_id = runtime.mana_spring_totem_id
            elseif s.enh_water_totem == 2 then spell_id = runtime.healing_stream_totem_id
            end
            if spell_id and try_cast_self(spell_id, me, "Water Totem") then return true end
        end
    end
    
    -- Air (skip if twisting)
    local skip_air = menu.enh_twist_windfury and menu.enh_twist_windfury:get_state()
    if not skip_air and s.enh_air_totem ~= 4 then
        if not totem_state.air_active or totem_state.air_remaining < threshold then
            local spell_id = nil
            if s.enh_air_totem == 1 then spell_id = runtime.windfury_totem_id
            elseif s.enh_air_totem == 2 then spell_id = runtime.grace_of_air_totem_id
            elseif s.enh_air_totem == 3 then spell_id = runtime.wrath_of_air_totem_id
            end
            if spell_id and try_cast_self(spell_id, me, "Air Totem") then return true end
        end
    end
    
    return false
end

local function try_windfury_twist(me)
    if not (menu.enh_twist_windfury and menu.enh_twist_windfury:get_state()) then return false end
    
    local now = _core_time()
    local cycle = 10
    
    if not runtime.wf_twist.initialized then
        if runtime.windfury_totem_id then
            runtime.wf_twist.initialized = true
            runtime.wf_twist.phase = "windfury"
            runtime.wf_twist.last_wf_time = now
            return try_cast_self(runtime.windfury_totem_id, me, "Windfury Totem (init)")
        end
        return false
    end
    
    if runtime.wf_twist.phase == "windfury" then
        local elapsed = now - runtime.wf_twist.last_wf_time
        if elapsed >= cycle then
            -- Switch to Grace of Air
            if runtime.grace_of_air_totem_id then
                runtime.wf_twist.phase = "default"
                runtime.wf_twist.last_default_time = now
                return try_cast_self(runtime.grace_of_air_totem_id, me, "Grace of Air (twist)")
            end
        end
    elseif runtime.wf_twist.phase == "default" then
        local elapsed = now - runtime.wf_twist.last_default_time
        if elapsed >= cycle then
            if runtime.windfury_totem_id then
                runtime.wf_twist.phase = "windfury"
                runtime.wf_twist.last_wf_time = now
                return try_cast_self(runtime.windfury_totem_id, me, "Windfury Totem (twist)")
            end
        end
    end
    
    return false
end

local function try_fire_nova_twist(me)
    if not (menu.enh_twist_fire_nova and menu.enh_twist_fire_nova:get_state()) then return false end
    if not runtime.fire_nova_totem_id then return false end
    
    local now = _core_time()
    
    if runtime.fnt_twist.phase == "idle" then
        local threshold = (menu.aoe_threshold and menu.aoe_threshold:get()) or 3
        -- Check if should drop FNT
        if runtime.fire_nova_totem_id then
            runtime.fnt_twist.phase = "waiting"
            runtime.fnt_twist.last_drop_time = now
            return try_cast_self(runtime.fire_nova_totem_id, me, "Fire Nova Totem (twist)")
        end
    elseif runtime.fnt_twist.phase == "waiting" then
        local elapsed = now - runtime.fnt_twist.last_drop_time
        if elapsed >= 5 then
            runtime.fnt_twist.phase = "default"
            return true
        end
    elseif runtime.fnt_twist.phase == "default" then
        local cd = core.spell_book.get_spell_cooldown(runtime.fire_nova_totem_id)
        if cd <= 0 then
            runtime.fnt_twist.phase = "idle"
        end
    end
    
    return false
end

local function try_stormstrike(me, target)
    if not (menu.enh_use_stormstrike and menu.enh_use_stormstrike:get_state()) then return false end
    if not runtime.stormstrike_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    
    return try_cast_target(runtime.stormstrike_id, me, target, "Stormstrike")
end

local function try_shock(me, target)
    local primary = (menu.enh_primary_shock and menu.enh_primary_shock:get()) or 1
    if primary == 3 then return false end -- none
    
    local mana_stop = (menu.enh_mana_stop_shocks and menu.enh_mana_stop_shocks:get()) or 10
    local mana_pct = utils.get_mana_pct(me) * 100
    if mana_stop > 0 and mana_pct < mana_stop then return false end
    
    -- Flame Shock weaving
    if menu.enh_weave_flame_shock and menu.enh_weave_flame_shock:get_state() then
        local fs_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_FLAME_SHOCK)
        if fs_rem <= 2000 then
            if runtime.flame_shock_id then
                return try_cast_target(runtime.flame_shock_id, me, target, "Flame Shock (weave)")
            end
        end
    end
    
    -- Primary shock
    local spell_id = nil
    if primary == 1 then spell_id = runtime.earth_shock_id
    elseif primary == 2 then spell_id = runtime.frost_shock_id
    end
    
    if spell_id then
        return try_cast_target(spell_id, me, target, "Shock")
    end
    return false
end

local function try_fire_elemental(me, target, is_burst_window)
    if not (menu.use_fire_elemental and menu.use_fire_elemental:get_state()) then return false end
    if not runtime.fire_elemental_totem_id then return false end
    if not should_use_cds(target) then return false end

    -- If auto-burst is enabled, only use during burst window
    local auto_burst = (menu.auto_burst_enabled and menu.auto_burst_enabled:get()) or false
    if auto_burst and not is_burst_window then return false end

    return try_cast_self(runtime.fire_elemental_totem_id, me, "Fire Elemental Totem")
end

local function try_aoe_rotation(me, target)
    if not (menu.enable_aoe and menu.enable_aoe:get_state()) then return false end
    
    local threshold = (menu.aoe_threshold and menu.aoe_threshold:get()) or 3
    local enemy_count = 1 -- Simplified
    if enemy_count < threshold then return false end
    
    -- Fire Nova Totem for AoE
    if runtime.fire_nova_totem_id and (not totem_state.fire_active or totem_state.fire_remaining < 10) then
        if try_cast_self(runtime.fire_nova_totem_id, me, "Fire Nova Totem (AoE)") then return true end
    end
    
    return false
end

local function try_shield(me)
    local shield_mode = (menu.shield_mode and menu.shield_mode:get()) or 1
    if shield_mode == 1 then return false end
    
    if shield_mode == 2 then -- Lightning Shield
        if runtime.lightning_shield_id and not utils.has_buff(me, spells.BUFF_LIGHTNING_SHIELD) then
            return try_cast_self(runtime.lightning_shield_id, me, "Lightning Shield")
        end
    elseif shield_mode == 3 then -- Water Shield
        if runtime.water_shield_id and not utils.has_buff(me, spells.BUFF_WATER_SHIELD) then
            return try_cast_self(runtime.water_shield_id, me, "Water Shield")
        end
    end
    return false
end

local function try_ghost_wolf(me)
    if not (menu.use_ghost_wolf and menu.use_ghost_wolf:get_state()) then return false end
    if not runtime.ghost_wolf_id then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_GHOST_WOLF) then return false end
    
    return try_cast_self(runtime.ghost_wolf_id, me, "Ghost Wolf")
end

-- Main on_update
local function on_update()
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then return end
    
    if not menu.is_enabled() then return end
    
    if menu.toggle_key and menu.toggle_key:get_key_code() ~= 7 then
        if not menu.toggle_key:get_state() then return end
    end
    
    check_combat_reset(me:is_in_combat())
    
    if not me:is_in_combat() then
        ooc_manager.on_update(me, menu, utils, {
            group_buffs = {
                {
                    spell_id = runtime.lightning_shield_id,
                    buff_ids = spells.BUFF_LIGHTNING_SHIELD,
                    name = "Lightning Shield",
                    toggle = menu.use_lightning_shield
                },
                {
                    spell_id = runtime.water_shield_id,
                    buff_ids = spells.BUFF_WATER_SHIELD,
                    name = "Water Shield",
                    toggle = menu.use_water_shield
                },
            }
        })
        if try_ghost_wolf(me) then return end
        return
    end
    
    local target = me:get_target()
    if not utils.is_valid_hostile_target(me, target) then
        target = utils.find_best_target(me)
        if not target then return end
    end

    -- Track combat start time for burst detection
    if not runtime.combat_start_time then
        runtime.combat_start_time = _core_time()
    end

    -- Flux: Update swing manager
    swing_manager:update_swing(me)
    
    -- Flux: Sample combat forecast
    if combat_forecast and target and target:is_valid() then
        combat_forecast:sample(target)
    end
    
    -- Flux: Check swing delay (don't clip auto attacks)
    if swing_manager:is_swing_landing_soon(0.15) then return end

    -- Burst detection and trinkets
    local combat_time = 0
    local start_time = runtime.combat_start_time
    if start_time then
        combat_time = _core_time() - start_time
    end
    local should_burst, burst_reason = burst_manager.should_auto_burst(me, target, combat_time, menu)
    local is_burst_window = should_burst or false

    -- Flux: Trinkets V2
    trinket_manager.check_trinkets_v2(me, target, is_burst_window, force_commands, combat_forecast, menu)

    -- Rotation priority
    if try_shamanistic_rage(me, target, is_burst_window) then return end
    if try_racial(me, target) then return end
    if try_shield(me) then return end
    if try_totem_management(me) then return end
    if try_windfury_twist(me) then return end
    if try_fire_nova_twist(me) then return end
    if try_fire_elemental(me, target, is_burst_window) then return end
    if try_aoe_rotation(me, target) then return end
    if try_stormstrike(me, target) then return end
    if try_shock(me, target) then return end
end

if core and core.register_on_update_callback then
    core.register_on_update_callback(on_update)
end

if core and core.register_on_render_callback then
    core.register_on_render_callback(function()
        menu.render()
    end)
end

if core and core.register_on_render_menu_callback then
    core.register_on_render_menu_callback(function(win)
        menu.set_window(win)
        menu.render()
    end)
end

-- Export toggle settings for external access
local NS = _G.EAXShamanEnhancement and _G.EAXShamanEnhancement.NS or {}
_G.EAXShamanEnhancement = _G.EAXShamanEnhancement or {}
_G.EAXShamanEnhancement.NS = NS
NS.toggle_menu = menu.toggle_menu


