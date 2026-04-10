-- EAX Mage Fire | main.lua | Project Sylvanas

-- Load header first to check if we should load at all
local header = require("header")
if not header.load then
    return
end

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")


local middleware_manager = require("libraries/middleware_manager")
local dashboard_config = require("libraries/dashboard_config")
local dashboard = require("libraries/dashboard")

-- Burst & Trinket Automation (ported from Flux)
local burst_manager = require("libraries/burst_manager")
local trinket_manager = require("libraries/trinket_manager")
local combat_forecast = require("libraries/combat_forecast")
local force_commands = require("libraries/force_commands")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown

-- Require common modules
---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("libraries/ooc_manager")
---@type ttd_tracker
local ttd_tracker = require("libraries/ttd_tracker")
---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")
---@type pvp_manager
local pvp_manager = require("libraries/pvp_manager")
---@type encounter_manager
local encounter_manager = require("libraries/encounter_manager")
---@type anti_fake_manager
local anti_fake_manager = require("libraries/anti_fake_manager")

-- Module-level encounter policy cache
local enc = nil

-- Runtime state
local runtime = {
    fireball_id = nil,
    scorch_id = nil,
    fire_blast_id = nil,
    combustion_id = nil,
    icy_veins_id = nil,
    blast_wave_id = nil,
    dragons_breath_id = nil,
    flamestrike_id = nil,
    arcane_explosion_id = nil,
    evocation_id = nil,
    remove_curse_id = nil,
    mage_armor_id = nil,
    ice_block_id = nil,
    counterspell_id = nil,
    frost_nova_id = nil,
    cone_of_cold_id = nil,
    ice_lance_id = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
}

-- GCD and cast timing
local GCD_CAST_INTERVAL = 1.5
local PENDING_CAST_TIMEOUT_S = 2.5
local FAST_PENDING_CAST_TIMEOUT_S = 0.75

-- Resolve spell IDs at load
local function resolve_spells()
    runtime.fireball_id = utils.resolve_spell_id(spells.FIREBALL)
    runtime.scorch_id = utils.resolve_spell_id(spells.SCORCH)
    runtime.fire_blast_id = utils.resolve_spell_id(spells.FIRE_BLAST)
    runtime.combustion_id = utils.resolve_spell_id(spells.COMBUSTION)
    runtime.icy_veins_id = utils.resolve_spell_id(spells.ICY_VEINS)
    runtime.blast_wave_id = utils.resolve_spell_id(spells.BLAST_WAVE)
    runtime.dragons_breath_id = utils.resolve_spell_id(spells.DRAGONS_BREATH)
    runtime.flamestrike_id = utils.resolve_spell_id(spells.FLAMESTRIKE)
    runtime.arcane_explosion_id = utils.resolve_spell_id(spells.ARCANE_EXPLOSION)
    runtime.evocation_id = utils.resolve_spell_id(spells.EVOCATION)
    runtime.remove_curse_id = utils.resolve_spell_id(spells.REMOVE_CURSE)
    runtime.mage_armor_id = utils.resolve_spell_id(spells.MAGE_ARMOR)
    runtime.arcane_intellect_id = utils.resolve_spell_id(spells.ARCANE_INTELLECT)
    runtime.counterspell_id = utils.resolve_spell_id(spells.COUNTERSPELL)
    runtime.frost_nova_id = utils.resolve_spell_id(spells.FROST_NOVA)
    runtime.cone_of_cold_id = utils.resolve_spell_id(spells.CONE_OF_COLD)
    runtime.ice_lance_id = utils.resolve_spell_id(spells.ICE_LANCE)
end

resolve_spells()


middleware_manager.init(menu)
force_commands:init()
local dash_config = dashboard_config.init()
dashboard.init(dash_config)
dashboard.set_enabled(true)
if dashboard.register_render_callback then
    dashboard.register_render_callback()
end

-- Helper functions
local function is_valid_hostile_target(me, target)
    if not target then return false end
    local ok_valid, is_valid = pcall(function() return target:is_valid() end)
    if not ok_valid or not is_valid then return false end
    local ok_dead, is_dead = pcall(function() return target:is_dead() end)
    if not ok_dead or is_dead then return false end
    local ok_attack, can_attack = pcall(function() return me:can_attack(target) end)
    if not ok_attack or not can_attack then return false end
    return true
end

local function get_target_ttd_seconds(target)
    if not target or not ttd_tracker then return nil end
    local ok, value = pcall(function() return ttd_tracker.get(target) end)
    if not ok then return nil end
    return tonumber(value)
end

local function note_cast()
    runtime.last_cast_time = _core_time()
end

local function is_gcd_ready()
    local gcd_remaining = _get_gcd()
    return gcd_remaining <= 0.1
end

-- Get Scorch debuff state (ported from )
local function get_scorch_state(target)
    local stacks = utils.get_debuff_stacks(target, spells.DEBUFF_IMPROVED_SCORCH)
    local duration = utils.get_debuff_remaining_ms(target, spells.DEBUFF_IMPROVED_SCORCH)
    return stacks, duration
end

-- Try cast functions (ported from  strategies)
local function try_maintain_scorch(me, target)
    if not (menu.fire_maintain_scorch and menu.fire_maintain_scorch:get()) then return false end
    if not runtime.scorch_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    local ok_moving, is_moving = pcall(function() return me:is_moving() end)
    if ok_moving and is_moving then return false end

    local stacks, duration = get_scorch_state(target)
    local refresh_threshold = (menu.fire_scorch_refresh and menu.fire_scorch_refresh:get()) or 6

    if stacks < 5 or (duration > 0 and duration < (refresh_threshold * 1000)) then
        if utils.can_cast_hostile(runtime.scorch_id, me, target) then
            local msg = string.format("Scorch - Stacks: %d, Duration: %.1fs", stacks, duration / 1000)
            if utils.cast_target(runtime.scorch_id, target, msg) then
                note_cast()
                return true
            end
        end
    end
    return false
end

local function try_combustion(me, target)
    if not runtime.combustion_id then return false end
    if not (menu.use_combustion and menu.use_combustion:get()) then return false end
    if not is_valid_hostile_target(me, target) then return false end
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then return false end
    if utils.has_buff(me, spells.BUFF_COMBUSTION) then return false end

    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    local ttd = get_target_ttd_seconds(target)
    if min_ttd > 0 and ttd and ttd > 0 and ttd < min_ttd then return false end

    local hp_threshold = (menu.fire_combustion_below_hp and menu.fire_combustion_below_hp:get()) or 0
    if hp_threshold > 0 then
        local target_hp = target:get_health_percentage() or 100
        if target_hp > hp_threshold then return false end
    end

    if not utils.can_cast_self(runtime.combustion_id, me) then return false end
    if utils.cast_self_fast(runtime.combustion_id, me, "Combustion") then
        note_cast()
        return true
    end
    return false
end

local function try_icy_veins(me, target)
    if not runtime.icy_veins_id then return false end
    if not (menu.use_icy_veins and menu.use_icy_veins:get()) then return false end
    if not is_valid_hostile_target(me, target) then return false end
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then return false end
    if utils.has_buff(me, spells.BUFF_ICY_VEINS) then return false end

    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    local ttd = get_target_ttd_seconds(target)
    if min_ttd > 0 and ttd and ttd > 0 and ttd < min_ttd then return false end

    if not utils.can_cast_self(runtime.icy_veins_id, me) then return false end
    if utils.cast_self_fast(runtime.icy_veins_id, me, "Icy Veins") then
        note_cast()
        return true
    end
    return false
end

local function try_racial(me, target)
    if not is_valid_hostile_target(me, target) then return false end
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then return false end

    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    local ttd = get_target_ttd_seconds(target)
    if min_ttd > 0 and ttd and ttd > 0 and ttd < min_ttd then return false end

    local berserking_id = utils.resolve_spell_id(spells.BERSERKING)
    if berserking_id and utils.can_cast_self(berserking_id, me) then
        if utils.cast_self_fast(berserking_id, me, "Berserking") then
            note_cast()
            return true
        end
    end

    local arcane_torrent_id = utils.resolve_spell_id(spells.ARCANE_TORRENT)
    if arcane_torrent_id and utils.can_cast_self(arcane_torrent_id, me) then
        if utils.cast_self_fast(arcane_torrent_id, me, "Arcane Torrent") then
            note_cast()
            return true
        end
    end

    return false
end

local function try_blast_wave(me, target)
    if not runtime.blast_wave_id then return false end
    if not (menu.use_blast_wave and menu.use_blast_wave:get()) then return false end
    if not is_valid_hostile_target(me, target) then return false end
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then return false end

    local min_enemies = (menu.fire_aoe_threshold and menu.fire_aoe_threshold:get()) or 3

    local count = 0
    local ok_objects, objects = pcall(function() return core.object_manager.get_all_objects() end)
    if not ok_objects then objects = {} end
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and me:can_attack(obj) then
            if utils.is_close_to(me, obj, 10) then
                count = count + 1
                if count >= min_enemies then break end
            end
        end
    end

    if count < min_enemies then return false end

    if utils.can_cast_self(runtime.blast_wave_id, me) then
        if utils.cast_self(runtime.blast_wave_id, me, "Blast Wave") then
            note_cast()
            return true
        end
    end
    return false
end

local function try_dragons_breath(me, target)
    if not runtime.dragons_breath_id then return false end
    if not (menu.use_dragons_breath and menu.use_dragons_breath:get()) then return false end
    if not is_valid_hostile_target(me, target) then return false end
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then return false end

    local min_enemies = (menu.fire_aoe_threshold and menu.fire_aoe_threshold:get()) or 3

    local count = 0
    local ok_objects, objects = pcall(function() return core.object_manager.get_all_objects() end)
    if not ok_objects then objects = {} end
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and me:can_attack(obj) then
            if utils.is_close_to(me, obj, 10) then
                count = count + 1
                if count >= min_enemies then break end
            end
        end
    end

    if count < min_enemies then return false end

    if utils.can_cast_hostile(runtime.dragons_breath_id, me, target) then
        if utils.cast_target(runtime.dragons_breath_id, target, "Dragon's Breath") then
            note_cast()
            return true
        end
    end
    return false
end

local function try_aoe(me, target)
    local threshold = (menu.fire_aoe_threshold and menu.fire_aoe_threshold:get()) or 3
    if threshold == 0 then return false end

    if not is_valid_hostile_target(me, target) then return false end
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then return false end

    local count = 0
    local ok_objects, objects = pcall(function() return core.object_manager.get_all_objects() end)
    if not ok_objects then objects = {} end
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and me:can_attack(obj) then
            if utils.is_close_to(obj, target, 10) then
                count = count + 1
                if count >= threshold then break end
            end
        end
    end

    if count < threshold then return false end

    if runtime.arcane_explosion_id and utils.can_cast_self(runtime.arcane_explosion_id, me) then
        if utils.cast_self(runtime.arcane_explosion_id, me, "Arcane Explosion (AoE)") then
            note_cast()
            return true
        end
    end

    if runtime.flamestrike_id and not me:is_moving() then
        if utils.can_cast_hostile(runtime.flamestrike_id, me, target) then
            if utils.cast_target(runtime.flamestrike_id, target, "Flamestrike (AoE)") then
                note_cast()
                return true
            end
        end
    end

    return false
end

local function try_movement_spell(me, target)
    local ok_moving, is_moving = pcall(function() return me:is_moving() end)
    if ok_moving and not is_moving then return false end
    if not is_valid_hostile_target(me, target) then return false end

    if (menu.use_fire_blast_move and menu.use_fire_blast_move:get()) and runtime.fire_blast_id then
        if utils.can_cast_hostile(runtime.fire_blast_id, me, target) then
            if utils.cast_target_fast(runtime.fire_blast_id, target, "Fire Blast (moving)") then
                note_cast()
                return true
            end
        end
    end

    return false
end

local function try_primary_spell(me, target)
    if not is_valid_hostile_target(me, target) then return false end
    local ok_moving, is_moving = pcall(function() return me:is_moving() end)
    if ok_moving and is_moving then return false end

    if not (menu.use_fireball and menu.use_fireball:get()) then return false end
    if not runtime.fireball_id then return false end
    if not utils.can_cast_hostile(runtime.fireball_id, me, target) then return false end

    if utils.cast_target(runtime.fireball_id, target, "Fireball") then
        note_cast()
        return true
    end
    return false
end

local function try_mana_gem(me)
    if not (menu.use_mana_gem and menu.use_mana_gem:get()) then return false end
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then return false end
    if utils.get_mana_pct(me) > ((menu.mana_gem_pct and menu.mana_gem_pct:get()) or 30) then return false end

    for i = 1, #spells.MANA_GEM_ITEMS do
        if utils.use_consumable_if_ready(me, spells.MANA_GEM_ITEMS[i]) then
            note_cast()
            return true
        end
    end
    return false
end

local function try_evocation(me)
    if not (menu.use_evocation and menu.use_evocation:get()) then return false end
    if not runtime.evocation_id then return false end
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then return false end
    if me:is_channelling_spell() then return false end
    local ok_moving, is_moving = pcall(function() return me:is_moving() end)
    if ok_moving and is_moving then return false end

    local threshold = (menu.evocation_pct and menu.evocation_pct:get()) or 25
    if utils.get_mana_pct(me) > threshold then return false end

    if not utils.can_cast_self(runtime.evocation_id, me) then return false end
    if utils.cast_self(runtime.evocation_id, me, "Evocation") then
        note_cast()
        return true
    end
    return false
end

local function try_ice_block(me)
    if not (menu.use_ice_block and menu.use_ice_block:get()) then return false end
    if not runtime.ice_block_id then
        runtime.ice_block_id = utils.resolve_spell_id(spells.ICE_BLOCK)
    end
    if not runtime.ice_block_id then return false end

    local ok_hp, hp_pct = pcall(function() if me and me.get_health_percentage then return me:get_health_percentage() / 100 end return 1 end)
    if not ok_hp then hp_pct = 1 end
    local threshold = ((menu.ice_block_hp_pct and menu.ice_block_hp_pct:get()) or 30) / 100
    if hp_pct > threshold then return false end
    if utils.has_buff(me, spells.BUFF_ICE_BLOCK) then return false end
    if not utils.can_cast_self(runtime.ice_block_id, me) then return false end

    if utils.cast_self(runtime.ice_block_id, me, "Ice Block") then
        return true
    end
    return false
end

local function try_frost_nova(me)
    if not (menu.use_frost_nova and menu.use_frost_nova:get()) then return false end
    if not runtime.frost_nova_id then
        runtime.frost_nova_id = utils.resolve_spell_id(spells.FROST_NOVA)
    end
    if not runtime.frost_nova_id then return false end

    local ok_objects, objects = pcall(function() return core.object_manager.get_all_objects() end)
    if not ok_objects then objects = {} end
    local melee_attacker = false
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead()
           and me:can_attack(obj) and utils.is_close_to(me, obj, 8) then
            melee_attacker = true
            break
        end
    end
    if not melee_attacker then return false end

    if not utils.can_cast_self(runtime.frost_nova_id, me) then return false end
    if utils.cast_self(runtime.frost_nova_id, me, "Frost Nova") then
        return true
    end
    return false
end

local function try_remove_curse(me)
    if not (menu.use_remove_curse and menu.use_remove_curse:get()) then return false end
    if not runtime.remove_curse_id then
        runtime.remove_curse_id = utils.resolve_spell_id(spells.REMOVE_CURSE)
    end
    if not runtime.remove_curse_id then return false end
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then return false end
    local ok_moving, is_moving = pcall(function() return me:is_moving() end)
    if ok_moving and is_moving then return false end

    if utils.has_debuff(me, spells.REMOVE_CURSE) then
        if utils.can_cast_self(runtime.remove_curse_id, me) then
            if utils.cast_self(runtime.remove_curse_id, me, "Remove Curse (self)") then
                return true
            end
        end
    end
    return false
end

local function try_trinkets(me)
    if not (menu.use_trinkets and menu.use_trinkets:get()) then return false end
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then return false end

    local trinkets = utils.get_self_cast_trinket_ids(me)
    for i = 1, #trinkets do
        if utils.use_item_if_ready(trinkets[i].item_id) then
            note_cast()
            return true
        end
    end
    return false
end

-- Main rotation function
local function do_rotation(me, target)
    if not is_gcd_ready() then return false end

    
    local ctx = middleware_manager.build_context(me, target, menu)
    local mw_result, mw_msg = middleware_manager.execute(nil, ctx)
    if mw_result then return true end

    -- CC Detection: Stop rotation if crowd controlled
    local cc_detector = require("libraries/cc_detector")
    local should_stop, cc_reason = cc_detector.should_stop_rotation(me)

    -- Mage special: Try Blink for stun before stopping
    if should_stop and cc_reason == "STUN" then
        if utils.try_blink_stun_break(me, menu) then
            return  -- Successfully broke stun
        end
    end

    if should_stop then
        return  -- Stop rotation while CC'd
    end

    if try_ice_block(me) then return true end
    if try_frost_nova(me) then return true end

    if (menu.use_interrupt and menu.use_interrupt:get()) and interrupt_manager.should_interrupt(target) then
        -- PvP anti-fake interrupt delay
        if target:is_player() then
            local delay = anti_fake_manager.get_interrupt_delay(target, true)
            if delay > 0 then
                local cast_rem = target:get_cast_remaining_time() or 0
                if cast_rem > delay then
                    -- Wait for delay before interrupting
                    return false
                end
            end
        end
        if interrupt_manager.try_interrupt(me, target, "mage", utils) then return true end
    end

    if try_remove_curse(me) then return true end

    ttd_tracker.update(target)

    if try_aoe(me, target) then return true end

    if try_mana_gem(me) then return true end
    if try_evocation(me) then return true end

    if not enc or not enc.hold_cooldowns then
        if try_combustion(me, target) then return true end
        if try_icy_veins(me, target) then return true end
        if try_racial(me, target) then return true end
        if try_trinkets(me) then return true end
    end

    if try_blast_wave(me, target) then return true end
    if try_dragons_breath(me, target) then return true end

    if try_movement_spell(me, target) then return true end

    if try_maintain_scorch(me, target) then return true end

    if try_primary_spell(me, target) then return true end

    return false
end

-- On update callback
local function on_update()
    if not (menu.enabled and menu.enabled:get_state()) then return end

    local me = _get_local_player()
    if not me then return end
    local ok_dead, is_dead = pcall(function() return me:is_dead() end)
    if ok_dead and is_dead then return end

    -- Sync dashboard settings (safe pcall for uninitialized menu items)
    local ok_show, show_dashboard = pcall(function() return menu.show_dashboard:get_state() end)
    if ok_show then
        dashboard.set_enabled(show_dashboard)
    end
    
    local ok_opacity, opacity = pcall(function() return menu.dashboard_opacity:get() end)
    if ok_opacity then
        dashboard.set_opacity(opacity)
    end
    
    local ok_scale, scale = pcall(function() return menu.dashboard_scale:get() end)
    if ok_scale then
        dashboard.set_scale(scale)
    end
    
    local ok_x, pos_x = pcall(function() return menu.dashboard_x:get() end)
    local ok_y, pos_y = pcall(function() return menu.dashboard_y:get() end)
    if ok_x and ok_y then
        dashboard.set_position(pos_x, pos_y)
    end

    -- Crowd Control check - return early if stunned/silenced/feared etc.
    if utils.is_cced and utils.is_cced(me) then return end

    -- OOC handling via shared ooc_manager
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then
        local resolved = {
            mage_armor = runtime.mage_armor_id,
            arcane_intellect = runtime.arcane_intellect_id
        }
        ooc_manager.on_update(me, menu, utils, {
            group_buffs = {
                {
                    spell_id = resolved.mage_armor,
                    buff_ids = spells.BUFF_MAGE_ARMOR,
                    name = "Mage Armor",
                    toggle = menu.use_mage_armor
                },
                {
                    spell_id = resolved.arcane_intellect,
                    buff_ids = spells.BUFF_ARCANE_INTELLECT,
                    name = "Arcane Intellect",
                    toggle = menu.use_arcane_intellect
                },
            }
        })
    end

    local ok_target, target = pcall(function() if me and me.get_target then return me:get_target() end return nil end)
    if not ok_target then target = nil end
    if not is_valid_hostile_target(me, target) then
        -- OOC handling via shared ooc_manager
        local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then
            local resolved = {
                mage_armor = runtime.mage_armor_id,
                arcane_intellect = runtime.arcane_intellect_id
            }
            ooc_manager.on_update(me, menu, utils, {
                group_buffs = {
                    {
                        spell_id = resolved.mage_armor,
                        buff_ids = spells.BUFF_MAGE_ARMOR,
                        name = "Mage Armor",
                        toggle = menu.use_mage_armor
                    },
                    {
                        spell_id = resolved.arcane_intellect,
                        buff_ids = spells.BUFF_ARCANE_INTELLECT,
                        name = "Arcane Intellect",
                        toggle = menu.use_arcane_intellect
                    },
                }
            })
        end
        return
    end

    -- Sample combat forecast for TTD calculations
    if combat_forecast and target and target:is_valid() then
        combat_forecast:sample(target)
    end

    local self_threshold = 0.30
    local ok_hp, my_hp = pcall(function() if me and me.get_health_percentage then return me:get_health_percentage() / 100 end return 1 end)
    if not ok_hp then my_hp = 1 end
    if my_hp < self_threshold then
        try_ice_block(me)
    end
    
    -- Burst & Trinket Automation (ported from Flux)
    -- Note: combat_time estimation - we don't have direct combat_start_time in this spec
    local is_burst_window = burst_manager.should_auto_burst(me, target, 0, menu)
    trinket_manager.check_trinkets_v2(me, target, is_burst_window, force_commands, combat_forecast, menu)

    do_rotation(me, target)
end

core.register_on_update_callback(on_update)

-- Export toggle settings for external access
if header.load then
    local NS = _G.EAXMageFire and _G.EAXMageFire.NS or {}
    _G.EAXMageFire = _G.EAXMageFire or {}
    _G.EAXMageFire.NS = NS
    NS.toggle_menu = menu.toggle_menu
end
