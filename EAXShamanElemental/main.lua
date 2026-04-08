-- Eax Shaman Elemental | main.lua
-- Elemental Shaman rotation: Lightning Bolt/Chain Lightning spam, Flame Shock, Totems

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local buff_manager = require("common/modules/buff_manager")
local spell_queue = require("common/modules/spell_queue")
local ooc_manager = require("libraries/ooc_manager")
local mana_manager = require("libraries/mana_manager")
local burst_manager = require("libraries/burst_manager")
local trinket_manager = require("libraries/trinket_manager")

-- Flux Feature Integration
local combat_forecast = require("libraries/combat_forecast")
local force_commands = require("libraries/force_commands")
local swing_manager = require("libraries/swing_manager")

-- Runtime spell cache
local runtime = {
    lightning_bolt_id = nil,
    chain_lightning_id = nil,
    earth_shock_id = nil,
    flame_shock_id = nil,
    frost_shock_id = nil,
    elemental_mastery_id = nil,
    fire_elemental_totem_id = nil,
    -- Totems
    searing_totem_id = nil,
    totem_of_wrath_id = nil,
    magma_totem_id = nil,
    fire_nova_totem_id = nil,
    strength_of_earth_id = nil,
    stoneskin_totem_id = nil,
    tremor_totem_id = nil,
    mana_spring_totem_id = nil,
    healing_stream_totem_id = nil,
    wrath_of_air_totem_id = nil,
    windfury_totem_id = nil,
    grace_of_air_totem_id = nil,
    -- Shields
    lightning_shield_id = nil,
    water_shield_id = nil,
    -- Utility
    ghost_wolf_id = nil,
    blood_fury_sp_id = nil,
    berserking_id = nil,
    -- State
    lb_casts_since_cl = 99,
    last_combat_state = false,
    combat_start_time = 0,
}

-- Resolve spells on load
local function resolve_spells()
    runtime.lightning_bolt_id = utils.resolve_spell_id(spells.LIGHTNING_BOLT)
    runtime.chain_lightning_id = utils.resolve_spell_id(spells.CHAIN_LIGHTNING)
    runtime.earth_shock_id = utils.resolve_spell_id(spells.EARTH_SHOCK)
    runtime.flame_shock_id = utils.resolve_spell_id(spells.FLAME_SHOCK)
    runtime.frost_shock_id = utils.resolve_spell_id(spells.FROST_SHOCK)
    runtime.elemental_mastery_id = utils.resolve_spell_id(spells.ELEMENTAL_MASTERY)
    runtime.fire_elemental_totem_id = utils.resolve_spell_id(spells.FIRE_ELEMENTAL_TOTEM)
    
    runtime.searing_totem_id = utils.resolve_spell_id(spells.SEARING_TOTEM)
    runtime.totem_of_wrath_id = utils.resolve_spell_id(spells.TOTEM_OF_WRATH)
    runtime.magma_totem_id = utils.resolve_spell_id(spells.MAGMA_TOTEM)
    runtime.fire_nova_totem_id = utils.resolve_spell_id(spells.FIRE_NOVA_TOTEM)
    runtime.flametongue_totem_id = utils.resolve_spell_id(spells.FLAMETONGUE_TOTEM)
    
    runtime.strength_of_earth_id = utils.resolve_spell_id(spells.STRENGTH_OF_EARTH_TOTEM)
    runtime.stoneskin_totem_id = utils.resolve_spell_id(spells.STONESKIN_TOTEM)
    runtime.tremor_totem_id = utils.resolve_spell_id(spells.TREMOR_TOTEM)
    
    runtime.mana_spring_totem_id = utils.resolve_spell_id(spells.MANA_SPRING_TOTEM)
    runtime.healing_stream_totem_id = utils.resolve_spell_id(spells.HEALING_STREAM_TOTEM)
    
    runtime.wrath_of_air_totem_id = utils.resolve_spell_id(spells.WRATH_OF_AIR_TOTEM)
    runtime.windfury_totem_id = utils.resolve_spell_id(spells.WINDFURY_TOTEM)
    runtime.grace_of_air_totem_id = utils.resolve_spell_id(spells.GRACE_OF_AIR_TOTEM)
    
    runtime.lightning_shield_id = utils.resolve_spell_id(spells.LIGHTNING_SHIELD)
    runtime.water_shield_id = utils.resolve_spell_id(spells.WATER_SHIELD)
    
    runtime.ghost_wolf_id = utils.resolve_spell_id(spells.GHOST_WOLF)
    runtime.blood_fury_sp_id = utils.resolve_spell_id(spells.BLOOD_FURY_SP)
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

local function note_cast()
    -- No-op for cast tracking
end

-- Combat state tracking
local function check_combat_reset(in_combat)
    if runtime.last_combat_state and not in_combat then
        runtime.lb_casts_since_cl = 99
    end
    runtime.last_combat_state = in_combat
end

-- Totem state tracking
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

-- Casting functions
local function try_cast_self(spell_id, me, label)
    if not spell_id or not me then return false end
    if is_pending_cast(spell_id) then return false end
    if not utils.can_cast_self(spell_id, me) then return false end
    if utils.cast_self(spell_id, me) then
        mark_pending_cast(spell_id, 1.5)
        utils.log_debug(menu, label or "Self cast")
        note_cast()
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
        note_cast()
        return true
    end
    return false
end

-- Rotation functions
local function try_elemental_mastery(me)
    if not (menu.ele_use_elemental_mastery and menu.ele_use_elemental_mastery:get_state()) then return false end
    if not runtime.elemental_mastery_id then return false end
    
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 10
    -- Check target TTD logic here if needed
    
    local rot = (menu.ele_rotation_type and menu.ele_rotation_type:get()) or 1
    if menu.ele_em_hold_for_cl and menu.ele_em_hold_for_cl:get_state() then
        if rot ~= 4 then -- not lb_only
            local cl_cd = core.spell_book.get_spell_cooldown(runtime.chain_lightning_id or 0)
            if cl_cd > 0 then return false end
        end
    end
    
    return try_cast_self(runtime.elemental_mastery_id, me, "Elemental Mastery")
end

local function try_racial(me)
    if not (menu.use_racial and menu.use_racial:get_state()) then return false end
    
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 10
    
    if runtime.blood_fury_sp_id then
        local cd = core.spell_book.get_spell_cooldown(runtime.blood_fury_sp_id)
        if cd <= 0 and core.spell_book.is_usable_spell(runtime.blood_fury_sp_id) then
            return try_cast_self(runtime.blood_fury_sp_id, me, "Blood Fury (SP)")
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
        ele_fire_totem = (menu.ele_fire_totem and menu.ele_fire_totem:get()) or 1,
        ele_earth_totem = (menu.ele_earth_totem and menu.ele_earth_totem:get()) or 1,
        ele_water_totem = (menu.ele_water_totem and menu.ele_water_totem:get()) or 1,
        ele_air_totem = (menu.ele_air_totem and menu.ele_air_totem:get()) or 1,
    }
    
    -- Fire Totem
    if s.ele_fire_totem ~= 5 then -- not none
        if not totem_state.fire_active or totem_state.fire_remaining < threshold then
            local spell_id = nil
            if s.ele_fire_totem == 1 then spell_id = runtime.totem_of_wrath_id
            elseif s.ele_fire_totem == 2 then spell_id = runtime.searing_totem_id
            elseif s.ele_fire_totem == 3 then spell_id = runtime.magma_totem_id
            elseif s.ele_fire_totem == 4 then spell_id = runtime.flametongue_totem_id
            end
            if spell_id and try_cast_self(spell_id, me, "Fire Totem") then return true end
        end
    end
    
    -- Earth Totem
    if s.ele_earth_totem ~= 3 then -- not none
        local skip_earth = false
        if menu.use_auto_tremor and menu.use_auto_tremor:get_state() and totem_state.earth_active then
            local ok, name = pcall(function() local _, n = GetTotemInfo(2); return n end)
            if ok and name and name:find("Tremor") then skip_earth = true end
        end
        if not skip_earth then
            if not totem_state.earth_active or totem_state.earth_remaining < threshold then
                local spell_id = nil
                if s.ele_earth_totem == 1 then spell_id = runtime.strength_of_earth_id
                elseif s.ele_earth_totem == 2 then spell_id = runtime.stoneskin_totem_id
                end
                if spell_id and try_cast_self(spell_id, me, "Earth Totem") then return true end
            end
        end
    end
    
    -- Water Totem
    if s.ele_water_totem ~= 3 then -- not none
        if not totem_state.water_active or totem_state.water_remaining < threshold then
            local spell_id = nil
            if s.ele_water_totem == 1 then spell_id = runtime.mana_spring_totem_id
            elseif s.ele_water_totem == 2 then spell_id = runtime.healing_stream_totem_id
            end
            if spell_id and try_cast_self(spell_id, me, "Water Totem") then return true end
        end
    end
    
    -- Air Totem
    if s.ele_air_totem ~= 5 then -- not none
        if not totem_state.air_active or totem_state.air_remaining < threshold then
            local spell_id = nil
            if s.ele_air_totem == 1 then spell_id = runtime.wrath_of_air_totem_id
            elseif s.ele_air_totem == 2 then spell_id = runtime.windfury_totem_id
            elseif s.ele_air_totem == 3 then spell_id = runtime.grace_of_air_totem_id
            elseif s.ele_air_totem == 4 then spell_id = runtime.tranquil_air_totem_id
            end
            if spell_id and try_cast_self(spell_id, me, "Air Totem") then return true end
        end
    end
    
    return false
end

local function try_fire_elemental(me)
    if not (menu.ele_use_fire_elemental and menu.ele_use_fire_elemental:get_state()) then return false end
    if not runtime.fire_elemental_totem_id then return false end
    
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 10
    return try_cast_self(runtime.fire_elemental_totem_id, me, "Fire Elemental Totem")
end

local function try_flame_shock(me, target)
    if not (menu.ele_use_flame_shock and menu.ele_use_flame_shock:get_state()) then return false end
    if not runtime.flame_shock_id then return false end
    
    local fs_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_FLAME_SHOCK)
    if fs_rem > 2000 then return false end
    
    local fs_ttd = (menu.ele_fs_min_ttd and menu.ele_fs_min_ttd:get()) or 5
    local mana_stop = (menu.ele_mana_stop_shocks and menu.ele_mana_stop_shocks:get()) or 10
    local mana_pct = utils.get_mana_pct(me)
    
    if mana_stop > 0 and mana_pct < (mana_stop / 100) then return false end
    
    return try_cast_target(runtime.flame_shock_id, me, target, "Flame Shock")
end

local function try_chain_lightning(me, target)
    if not runtime.chain_lightning_id then return false end
    if utils.is_moving(me) then return false end
    
    local cl_cd = core.spell_book.get_spell_cooldown(runtime.chain_lightning_id)
    if cl_cd > 0 then return false end
    
    local has_em = utils.has_buff(me, spells.BUFF_ELEMENTAL_MASTERY)
    if has_em then
        local result = try_cast_target(runtime.chain_lightning_id, me, target, "Chain Lightning (EM)")
        if result then
            runtime.lb_casts_since_cl = 0
            return true
        end
    end
    
    local rot = (menu.ele_rotation_type and menu.ele_rotation_type:get()) or 1
    if rot == 4 then return false end -- lb_only
    
    if rot == 2 then -- cl_on_cd
        local result = try_cast_target(runtime.chain_lightning_id, me, target, "Chain Lightning (on CD)")
        if result then
            runtime.lb_casts_since_cl = 0
            return true
        end
    elseif rot == 1 then -- cl_clearcast
        local has_clearcast = utils.has_buff(me, spells.BUFF_CLEARCASTING)
        if has_clearcast then
            local result = try_cast_target(runtime.chain_lightning_id, me, target, "Chain Lightning (clearcast)")
            if result then
                runtime.lb_casts_since_cl = 0
                return true
            end
        end
    elseif rot == 3 then -- fixed_ratio
        local ratio = (menu.ele_fixed_lb_per_cl and menu.ele_fixed_lb_per_cl:get()) or 3
        if runtime.lb_casts_since_cl >= ratio then
            local result = try_cast_target(runtime.chain_lightning_id, me, target, "Chain Lightning (ratio)")
            if result then
                runtime.lb_casts_since_cl = 0
                return true
            end
        end
    end
    
    return false
end

local function try_earth_shock(me, target)
    if not (menu.ele_use_earth_shock and menu.ele_use_earth_shock:get_state()) then return false end
    if not runtime.earth_shock_id then return false end
    
    local fs_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_FLAME_SHOCK)
    if fs_rem <= 2000 then return false end
    
    local mana_stop = (menu.ele_mana_stop_shocks and menu.ele_mana_stop_shocks:get()) or 10
    local mana_pct = utils.get_mana_pct(me)
    if mana_stop > 0 and mana_pct < (mana_stop / 100) then return false end
    
    return try_cast_target(runtime.earth_shock_id, me, target, "Earth Shock")
end

local function try_aoe_rotation(me, target)
    if not (menu.enable_aoe and menu.enable_aoe:get_state()) then return false end
    
    local threshold = (menu.aoe_threshold and menu.aoe_threshold:get()) or 3
    -- Simplified enemy count - would need proper implementation
    local enemy_count = 1
    
    if enemy_count < threshold then return false end
    
    -- Try Chain Lightning for AoE
    if runtime.chain_lightning_id then
        local cl_cd = core.spell_book.get_spell_cooldown(runtime.chain_lightning_id)
        if cl_cd <= 0 then
            local result = try_cast_target(runtime.chain_lightning_id, me, target, "Chain Lightning (AoE)")
            if result then
                runtime.lb_casts_since_cl = 0
                return true
            end
        end
    end
    
    -- Try Fire Nova Totem
    if runtime.fire_nova_totem_id and (not totem_state.fire_active or totem_state.fire_remaining < 10) then
        if try_cast_self(runtime.fire_nova_totem_id, me, "Fire Nova Totem (AoE)") then return true end
    end
    
    return false
end

local function try_lightning_bolt(me, target)
    if not runtime.lightning_bolt_id then return false end
    if utils.is_moving(me) then return false end
    
    local result = try_cast_target(runtime.lightning_bolt_id, me, target, "Lightning Bolt")
    if result then
        runtime.lb_casts_since_cl = runtime.lb_casts_since_cl + 1
        return true
    end
    return false
end

local function try_movement_spell(me, target)
    if not utils.is_moving(me) then return false end
    
    local mana_stop = (menu.ele_mana_stop_shocks and menu.ele_mana_stop_shocks:get()) or 10
    local mana_pct = utils.get_mana_pct(me)
    local mana_ok = mana_stop <= 0 or mana_pct >= (mana_stop / 100)
    
    -- Flame Shock while moving
    if mana_ok and (menu.ele_use_flame_shock and menu.ele_use_flame_shock:get_state()) then
        local fs_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_FLAME_SHOCK)
        if fs_rem <= 2000 then
            if try_cast_target(runtime.flame_shock_id, me, target, "Flame Shock (moving)") then return true end
        end
    end
    
    -- Earth Shock while moving
    if mana_ok and (menu.ele_use_earth_shock and menu.ele_use_earth_shock:get_state()) then
        if try_cast_target(runtime.earth_shock_id, me, target, "Earth Shock (moving)") then return true end
    end
    
    return false
end

local function try_shield(me)
    local shield_mode = (menu.shield_mode and menu.shield_mode:get()) or 1
    if shield_mode == 1 then return false end -- None
    
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

-- Combat state tracking for burst timing
local function check_combat_reset(in_combat)
    if in_combat and not runtime.last_combat_state then
        -- Combat started
        runtime.combat_start_time = _core_time()
    elseif not in_combat and runtime.last_combat_state then
        -- Combat ended - reset
        runtime.combat_start_time = 0
    end
    runtime.last_combat_state = in_combat
end

-- Main on_update callback
local function on_update()
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then return end
    
    -- CC Detection: Stop rotation if crowd controlled
    local cc_detector = require("libraries/cc_detector")
    local should_stop, cc_reason = cc_detector.should_stop_rotation(me)

    if should_stop then
        if (menu.debug and menu.debug:get_state()) then
            print(string.format("[CC] Rotation paused: %s", cc_reason or "CC"))
        end
        return  -- Stop rotation while CC'd
    end
    
    -- Check enabled
    if not (menu.enabled and menu.enabled:get_state()) then return end
    
    -- Rotation is always enabled when menu.enabled is true
    -- The toggle_key legacy feature is deprecated - use NUMPAD* to toggle menu instead
    -- if menu.toggle_key and menu.toggle_key:get_key_code() ~= 7 then
    --     if not menu.toggle_key:get_state() then return end
    -- end
    
    check_combat_reset(me:is_in_combat())
    
    -- Out of combat utilities
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
    
    -- Get target
    local target = me:get_target()
    if not utils.is_valid_hostile_target(me, target) then
        target = utils.find_best_target(me)
        if not target then return end
    end
    
    -- Mana recovery check (Shaman uses potions/runes only)
    if (menu.use_mana_manager and menu.use_mana_manager:get()) then
        local used_mana, mana_type = mana_manager.check_and_recover(me, menu, mana_manager.CLASS_RECOVERY.SHAMAN)
    end
    
    -- Flux: Update swing manager (for melee weaving if applicable)
    swing_manager:update_swing(me)
    
    -- Flux: Sample combat forecast
    if combat_forecast and target and target:is_valid() then
        combat_forecast:sample(target)
    end
    
    -- Flux: Check swing delay (don't clip auto attacks if melee weaving)
    if swing_manager:is_swing_landing_soon(0.15) then return end
    
    -- Burst & Trinket Automation
    local combat_time = _core_time() - (runtime.combat_start_time or _core_time())
    local is_burst_window = burst_manager.should_auto_burst(me, target, combat_time, menu)
    if is_burst_window then
        -- Elemental burst: Bloodlust (if available), Elemental Mastery
        if try_elemental_mastery(me) then return end
    end
    
    -- Flux: Trinkets V2
    trinket_manager.check_trinkets_v2(me, target, is_burst_window, force_commands, combat_forecast, menu)
    
    -- Rotation priority
    if try_elemental_mastery(me) then return end
    if try_racial(me) then return end
    if try_shield(me) then return end
    if try_totem_management(me) then return end
    if try_fire_elemental(me) then return end
    if try_aoe_rotation(me, target) then return end
    if try_flame_shock(me, target) then return end
    if try_chain_lightning(me, target) then return end
    if try_earth_shock(me, target) then return end
    if try_movement_spell(me, target) then return end
    if try_lightning_bolt(me, target) then return end
end

-- Register callback
if core and core.register_on_update_callback then
    core.register_on_update_callback(on_update)
end

-- Menu render callbacks (legacy, simple_ui handles its own rendering)
-- These are no-op since simple_ui.menu handles rendering internally
if core and core.register_on_render_callback then
    core.register_on_render_callback(function()
        -- simple_ui handles rendering - no-op for compatibility
        menu.render()
    end)
end

if core and core.register_on_render_menu_callback then
    core.register_on_render_menu_callback(function(win)
        -- simple_ui handles window management - no-op for compatibility
        menu.set_window(win)
        menu.render()
    end)
end

-- Export toggle settings for external access
local NS = _G.EAXShamanElemental and _G.EAXShamanElemental.NS or {}
_G.EAXShamanElemental = _G.EAXShamanElemental or {}
_G.EAXShamanElemental.NS = NS
NS.toggle_menu = menu.toggle_menu


