-- EAX Mage Frost | main.lua | Project Sylvanas

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

local mana_manager = require("libraries/mana_manager")
local burst_manager = require("libraries/burst_manager")
local trinket_manager = require("libraries/trinket_manager")
local combat_forecast = require("libraries/combat_forecast")
local force_commands = require("libraries/force_commands")

local middleware_manager = require("libraries/middleware_manager")
local dashboard_config = require("libraries/dashboard_config")
local dashboard = require("libraries/dashboard")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cd = core.spell_book.get_spell_cooldown

-- Require common modules
---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("../libraries/ooc_manager")
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
    frostbolt_id = nil,
    ice_lance_id = nil,
    cone_of_cold_id = nil,
    blizzard_id = nil,
    arcane_explosion_id = nil,
    frost_nova_id = nil,
    icy_veins_id = nil,
    cold_snap_id = nil,
    water_elemental_id = nil,
    fire_blast_id = nil,
    evocation_id = nil,
    remove_curse_id = nil,
    ice_armor_id = nil,
    arcane_intellect_id = nil,
    ice_block_id = nil,
    counterspell_id = nil,
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
    runtime.frostbolt_id = utils.resolve_spell_id(spells.FROSTBOLT)
    runtime.ice_lance_id = utils.resolve_spell_id(spells.ICE_LANCE)
    runtime.cone_of_cold_id = utils.resolve_spell_id(spells.CONE_OF_COLD)
    runtime.blizzard_id = utils.resolve_spell_id(spells.BLIZZARD)
    runtime.arcane_explosion_id = utils.resolve_spell_id(spells.ARCANE_EXPLOSION)
    runtime.frost_nova_id = utils.resolve_spell_id(spells.FROST_NOVA)
    runtime.icy_veins_id = utils.resolve_spell_id(spells.ICY_VEINS)
    runtime.cold_snap_id = utils.resolve_spell_id(spells.COLD_SNAP)
    runtime.water_elemental_id = utils.resolve_spell_id(spells.SUMMON_WATER_ELEMENTAL)
    runtime.fire_blast_id = utils.resolve_spell_id(spells.FIRE_BLAST)
    runtime.evocation_id = utils.resolve_spell_id(spells.EVOCATION)
    runtime.remove_curse_id = utils.resolve_spell_id(spells.REMOVE_CURSE)
    runtime.ice_armor_id = utils.resolve_spell_id(spells.ICE_ARMOR)
    runtime.arcane_intellect_id = utils.resolve_spell_id(spells.ARCANE_INTELLECT)
    runtime.counterspell_id = utils.resolve_spell_id(spells.COUNTERSPELL)
end

resolve_spells()


middleware_manager.init(menu)
force_commands:init()
local dash_config = dashboard_config.init()
dashboard.init(dash_config)

-- Sync dashboard settings (safe pcall for uninitialized menu items)
local ok_show, show_dashboard = pcall(function() return menu.show_dashboard:get_state() end)
if ok_show then
    dashboard.set_enabled(show_dashboard)
end

dashboard.register_render_callback()

-- Helper functions
local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
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

-- Try cast functions
local function try_icy_veins(me, target)
    if not runtime.icy_veins_id then return false end
    if not (menu.use_icy_veins and menu.use_icy_veins:get()) then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end
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

local function try_water_elemental(me, target)
    if not runtime.water_elemental_id then return false end
    if not (menu.use_water_elemental and menu.use_water_elemental:get()) then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end

    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    local ttd = get_target_ttd_seconds(target)
    if min_ttd > 0 and ttd and ttd > 0 and ttd < min_ttd then return false end

    if not utils.can_cast_self(runtime.water_elemental_id, me) then return false end
    if utils.cast_self(runtime.water_elemental_id, me, "Summon Water Elemental") then
        note_cast()
        return true
    end
    return false
end

local function try_cold_snap(me)
    if not runtime.cold_snap_id then return false end
    if not (menu.use_cold_snap and menu.use_cold_snap:get()) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_ICY_VEINS) then return false end

    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    local target = me:get_target()
    local ttd = get_target_ttd_seconds(target)
    if min_ttd > 0 and ttd and ttd > 0 and ttd < min_ttd then return false end

    local iv_cd = _get_spell_cd(runtime.icy_veins_id)
    if iv_cd < 20 then return false end

    if runtime.water_elemental_id then
        local we_cd = _get_spell_cd(runtime.water_elemental_id)
        if we_cd < 20 then return false end
    end

    if not utils.can_cast_self(runtime.cold_snap_id, me) then return false end
    if utils.cast_self_fast(runtime.cold_snap_id, me, "Cold Snap") then
        note_cast()
        return true
    end
    return false
end

local function try_racial(me, target)
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end

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

local function try_aoe(me, target)
    local threshold = (menu.frost_aoe_threshold and menu.frost_aoe_threshold:get()) or 3
    if threshold == 0 then return false end

    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end

    local count = 0
    local objects = core.object_manager.get_all_objects()
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

    if runtime.cone_of_cold_id and utils.can_cast_hostile(runtime.cone_of_cold_id, me, target) then
        if utils.cast_target_fast(runtime.cone_of_cold_id, target, "Cone of Cold (AoE)") then
            note_cast()
            return true
        end
    end

    if runtime.arcane_explosion_id and utils.can_cast_self(runtime.arcane_explosion_id, me) then
        if utils.cast_self(runtime.arcane_explosion_id, me, "Arcane Explosion (AoE)") then
            note_cast()
            return true
        end
    end

    if runtime.blizzard_id and not me:is_moving() then
        if utils.can_cast_hostile(runtime.blizzard_id, me, target) then
            if utils.cast_target(runtime.blizzard_id, target, "Blizzard (AoE)") then
                note_cast()
                return true
            end
        end
    end

    return false
end

local function try_movement_spell(me, target)
    if not me:is_moving() then return false end
    if not is_valid_hostile_target(me, target) then return false end

    if (menu.frost_move_fire_blast and menu.frost_move_fire_blast:get()) and runtime.fire_blast_id then
        if utils.can_cast_hostile(runtime.fire_blast_id, me, target) then
            if utils.cast_target_fast(runtime.fire_blast_id, target, "Fire Blast (moving)") then
                note_cast()
                return true
            end
        end
    end

    if (menu.frost_move_ice_lance and menu.frost_move_ice_lance:get()) and runtime.ice_lance_id then
        if utils.can_cast_hostile(runtime.ice_lance_id, me, target) then
            if utils.cast_target_fast(runtime.ice_lance_id, target, "Ice Lance (moving)") then
                note_cast()
                return true
            end
        end
    end

    if (menu.frost_move_cone_of_cold and menu.frost_move_cone_of_cold:get()) and runtime.cone_of_cold_id then
        if utils.can_cast_hostile(runtime.cone_of_cold_id, me, target) then
            if utils.cast_target_fast(runtime.cone_of_cold_id, target, "Cone of Cold (moving)") then
                note_cast()
                return true
            end
        end
    end

    if (menu.frost_move_arcane_explosion and menu.frost_move_arcane_explosion:get()) and runtime.arcane_explosion_id then
        if utils.is_close_to(me, target, 10) then
            if utils.can_cast_self(runtime.arcane_explosion_id, me) then
                if utils.cast_self(runtime.arcane_explosion_id, me, "Arcane Explosion (moving)") then
                    note_cast()
                    return true
                end
            end
        end
    end

    return false
end

local function try_frostbolt(me, target)
    if not runtime.frostbolt_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end
    if not (menu.frost_use_frostbolt and menu.frost_use_frostbolt:get()) then return false end

    if not utils.can_cast_hostile(runtime.frostbolt_id, me, target) then return false end

    if utils.cast_target(runtime.frostbolt_id, target, "Frostbolt") then
        note_cast()
        return true
    end
    return false
end

local function try_mana_gem(me)
    if not (menu.use_mana_gem and menu.use_mana_gem:get()) then return false end
    if not me:is_in_combat() then return false end
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
    if not me:is_in_combat() then return false end
    if me:is_channelling_spell() then return false end
    if me:is_moving() then return false end

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
    if not (menu.frost_use_ice_block and menu.frost_use_ice_block:get()) then return false end
    if not runtime.ice_block_id then
        runtime.ice_block_id = utils.resolve_spell_id(spells.ICE_BLOCK)
    end
    if not runtime.ice_block_id then return false end

    local hp_pct = me:get_health_percentage() / 100
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
    if not (menu.frost_use_frost_nova and menu.frost_use_frost_nova:get()) then return false end
    if not runtime.frost_nova_id then
        runtime.frost_nova_id = utils.resolve_spell_id(spells.FROST_NOVA)
    end
    if not runtime.frost_nova_id then return false end

    local objects = core.object_manager.get_all_objects()
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

local function try_ice_armor(me)
    if not runtime.ice_armor_id then return false end
    if me:is_in_combat() then return false end
    if not (menu.use_ice_armor and menu.use_ice_armor:get()) then return false end
    if not utils.can_cast_self(runtime.ice_armor_id, me) then return false end

    if utils.cast_self(runtime.ice_armor_id, me, "Ice Armor") then
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
    if not me:is_in_combat() then return false end
    if me:is_moving() then return false end

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
    if not me:is_in_combat() then return false end

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
        if (menu.debug and menu.debug:get_state()) then
            print(string.format("[CC] Rotation paused: %s", cc_reason or "CC"))
        end
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
        -- Burst & Trinket Automation
        local combat_time = _core_time() - (ctx.combat_start_time or _core_time())
        local is_burst_window = burst_manager.should_auto_burst(me, target, combat_time, menu)
        if is_burst_window then
            if try_icy_veins(me, target) then return true end
            if try_cold_snap(me) then return true end
            if try_water_elemental(me, target) then return true end
        end
        trinket_manager.check_trinkets_v2(me, target, is_burst_window, force_commands, combat_forecast, menu)

        if try_cold_snap(me) then return true end
        if try_water_elemental(me, target) then return true end
        if try_icy_veins(me, target) then return true end
        if try_racial(me, target) then return true end
        if try_trinkets(me) then return true end
    end

    if try_movement_spell(me, target) then return true end

    if try_frostbolt(me, target) then return true end

    return false
end

-- On update callback
local function on_update()
    if not (menu.enabled and menu.enabled:get_state()) then return end

    local me = _get_local_player()
    if not me then return end
    if me:is_dead() then return end

    -- Crowd Control check - return early if stunned/silenced/feared etc.
    if utils.is_cced and utils.is_cced(me) then return end

    -- Mana recovery check
    if (menu.use_mana_manager and menu.use_mana_manager:get()) then
        local used_mana, mana_type = mana_manager.check_and_recover(me, menu, mana_manager.CLASS_RECOVERY.MAGE)
    end

    if try_ice_armor(me) then return end

    local target = me:get_target()
    if not is_valid_hostile_target(me, target) then
        -- OOC buffing when no valid target
        if not me:is_in_combat() then
            ooc_manager.on_update(me, menu, utils, {
                group_buffs = {
                    {
                        spell_id = runtime.ice_armor_id,
                        buff_ids = spells.BUFF_ICE_ARMOR,
                        name = "Ice Armor",
                        toggle = menu.use_ice_armor
                    },
                    {
                        spell_id = runtime.arcane_intellect_id,
                        buff_ids = spells.BUFF_ARCANE_INTELLECT,
                        name = "Arcane Intellect",
                        toggle = menu.use_arcane_intellect
                    },
                }
            })
        end
        return
    end

    if utils.is_pacified(me) then return end

    local pvp_instance = pvp_manager.is_in_pvp_instance()
    if pvp_instance or pvp_manager.is_world_pvp(me) then
        local enemy_players = pvp_manager.find_enemy_players(me, 40)
        if #enemy_players > 0 then
            local priority = pvp_manager.priority_target(me, enemy_players)
            if priority then target = priority end
        end
    end

    local self_threshold = 0.30
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        try_ice_block(me)
    end

    do_rotation(me, target)
end

core.register_on_update_callback(on_update)

-- Export toggle settings for external access
local NS = _G.EAXMageFrost and _G.EAXMageFrost.NS or {}
_G.EAXMageFrost = _G.EAXMageFrost or {}
_G.EAXMageFrost.NS = NS
NS.toggle_menu = menu.toggle_menu
