require("libraries/path_bootstrap")
-- main.lua | EAX Mage Arcane | Project Sylvanas
-- Arcane Mage rotation with burn/conserve phase management

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cd = core.spell_book.get_spell_cooldown

-- Runtime state
local runtime = {
    arcane_blast_id = nil,
    arcane_missiles_id = nil,
    arcane_power_id = nil,
    arcane_explosion_id = nil,
    evocation_id = nil,
    remove_curse_id = nil,
    mage_armor_id = nil,
    fire_blast_id = nil,
    ice_block_id = nil,
    counterspell_id = nil,
    presence_of_mind_id = nil,
    icy_veins_id = nil,
    cold_snap_id = nil,
    frost_nova_id = nil,
    blink_id = nil,
    cone_of_cold_id = nil,
    frostbolt_id = nil,
    fireball_id = nil,
    scorch_id = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
}

-- Phase tracking
local arcane_phase = "burn"

-- GCD and cast timing
local GCD_CAST_INTERVAL = 1.5

-- Resolve spell IDs at load
local function resolve_spells()
    runtime.arcane_blast_id = utils.resolve_spell_id(spells.ARCANE_BLAST)
    runtime.arcane_missiles_id = utils.resolve_spell_id(spells.ARCANE_MISSILES)
    runtime.arcane_power_id = utils.resolve_spell_id(spells.ARCANE_POWER)
    runtime.arcane_explosion_id = utils.resolve_spell_id(spells.ARCANE_EXPLOSION)
    runtime.evocation_id = utils.resolve_spell_id(spells.EVOCATION)
    runtime.remove_curse_id = utils.resolve_spell_id(spells.REMOVE_CURSE)
    runtime.mage_armor_id = utils.resolve_spell_id(spells.MAGE_ARMOR)
    runtime.fire_blast_id = utils.resolve_spell_id(spells.FIRE_BLAST)
    runtime.counterspell_id = utils.resolve_spell_id(spells.COUNTERSPELL)
    runtime.presence_of_mind_id = utils.resolve_spell_id(spells.PRESENCE_OF_MIND)
    runtime.icy_veins_id = utils.resolve_spell_id(spells.ICY_VEINS)
    runtime.cold_snap_id = utils.resolve_spell_id(spells.COLD_SNAP)
    runtime.frost_nova_id = utils.resolve_spell_id(spells.FROST_NOVA)
    runtime.blink_id = utils.resolve_spell_id(spells.BLINK)
    runtime.cone_of_cold_id = utils.resolve_spell_id(spells.CONE_OF_COLD)
    runtime.frostbolt_id = utils.resolve_spell_id(spells.FROSTBOLT)
    runtime.fireball_id = utils.resolve_spell_id(spells.FIREBALL)
    runtime.scorch_id = utils.resolve_spell_id(spells.SCORCH)
end

resolve_spells()

-- Helper functions
local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function get_target_ttd_seconds(target)
    if not target then return nil end
    local ok, value = pcall(function() return target:get_health_percentage() end)
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

-- Phase management
local function update_arcane_phase(me, target)
    local mana_pct = utils.get_mana_pct(me)
    local ab_stacks = utils.get_debuff_stacks(me, spells.DEBUFF_ARCANE_BLAST)

    local start_conserve = (menu.arcane_start_conserve_pct and menu.arcane_start_conserve_pct:get()) or 35
    local stop_conserve = (menu.arcane_stop_conserve_pct and menu.arcane_stop_conserve_pct:get()) or 60

    if arcane_phase == "burn" and mana_pct <= start_conserve then
        arcane_phase = "conserve"
    elseif arcane_phase == "conserve" and mana_pct >= stop_conserve and ab_stacks <= 1 then
        arcane_phase = "burn"
    end

    if not me:is_in_combat() then
        arcane_phase = "burn"
    end

    return arcane_phase
end

-- Check if AB stacks will drop before next cast
local function ab_will_drop(me)
    local ab_duration = utils.get_debuff_remaining_ms(me, spells.DEBUFF_ARCANE_BLAST)
    if ab_duration <= 0 then return false end
    return ab_duration < 2500
end

-- Try cast functions
local function try_icy_veins(me, target)
    if not runtime.icy_veins_id then return false end
    if not (menu.use_icy_veins and menu.use_icy_veins:get_state()) then return false end
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

local function try_cold_snap(me)
    if not runtime.cold_snap_id then return false end
    if not (menu.use_cold_snap and menu.use_cold_snap:get_state()) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_ICY_VEINS) then return false end

    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    local target = me:get_target()
    local ttd = get_target_ttd_seconds(target)
    if min_ttd > 0 and ttd and ttd > 0 and ttd < min_ttd then return false end

    local iv_cd = _get_spell_cd(runtime.icy_veins_id)
    if iv_cd < 20 then return false end

    if not utils.can_cast_self(runtime.cold_snap_id, me) then return false end
    if utils.cast_self_fast(runtime.cold_snap_id, me, "Cold Snap") then
        note_cast()
        return true
    end
    return false
end

local function try_arcane_power(me, target)
    if not runtime.arcane_power_id then return false end
    if not (menu.use_arcane_power and menu.use_arcane_power:get_state()) then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_ARCANE_POWER) then return false end

    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    local ttd = get_target_ttd_seconds(target)
    if min_ttd > 0 and ttd and ttd > 0 and ttd < min_ttd then return false end

    local phase = update_arcane_phase(me, target)
    if phase ~= "burn" then return false end

    local min_mana = (menu.burn_mana_pct and menu.burn_mana_pct:get()) or 50
    if utils.get_mana_pct(me) < min_mana then return false end

    if not utils.can_cast_self(runtime.arcane_power_id, me) then return false end
    if utils.cast_self_fast(runtime.arcane_power_id, me, "Arcane Power") then
        note_cast()
        return true
    end
    return false
end

local function try_presence_of_mind(me)
    if not runtime.presence_of_mind_id then return false end
    if not (menu.use_presence_of_mind and menu.use_presence_of_mind:get_state()) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_PRESENCE_OF_MIND) then return false end

    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    local target = me:get_target()
    local ttd = get_target_ttd_seconds(target)
    if min_ttd > 0 and ttd and ttd > 0 and ttd < min_ttd then return false end

    local phase = update_arcane_phase(me, target)
    if phase ~= "burn" then return false end

    if not utils.can_cast_self(runtime.presence_of_mind_id, me) then return false end
    if utils.cast_self_fast(runtime.presence_of_mind_id, me, "Presence of Mind") then
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

    local phase = update_arcane_phase(me, target)
    if phase ~= "burn" then return false end

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
    local threshold = (menu.aoe_threshold and menu.aoe_threshold:get()) or 0
    if threshold == 0 then return false end

    if not runtime.arcane_explosion_id then return false end
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

    if utils.can_cast_self(runtime.arcane_explosion_id, me) then
        if utils.cast_self(runtime.arcane_explosion_id, me, "Arcane Explosion (AoE)") then
            note_cast()
            return true
        end
    end
    return false
end

local function try_movement_spell(me, target)
    if not me:is_moving() then return false end
    if not is_valid_hostile_target(me, target) then return false end

    if (menu.arcane_move_fire_blast and menu.arcane_move_fire_blast:get_state()) and runtime.fire_blast_id then
        if utils.can_cast_hostile(runtime.fire_blast_id, me, target) then
            if utils.cast_target_fast(runtime.fire_blast_id, target, "Fire Blast (moving)") then
                note_cast()
                return true
            end
        end
    end

    if (menu.arcane_move_ice_lance and menu.arcane_move_ice_lance:get_state()) then
        local ice_lance_id = utils.resolve_spell_id(spells.ICE_LANCE)
        if ice_lance_id and utils.can_cast_hostile(ice_lance_id, me, target) then
                note_cast()
                return true
        end
    end

    if (menu.arcane_move_cone_of_cold and menu.arcane_move_cone_of_cold:get_state()) and runtime.cone_of_cold_id then
        if utils.can_cast_hostile(runtime.cone_of_cold_id, me, target) then
            if utils.cast_target_fast(runtime.cone_of_cold_id, target, "Cone of Cold (moving)") then
                note_cast()
                return true
            end
        end
    end

    if (menu.arcane_move_arcane_explosion and menu.arcane_move_arcane_explosion:get_state()) and runtime.arcane_explosion_id then
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

local function try_arcane_blast(me, target)
    if not (menu.use_arcane_blast and menu.use_arcane_blast:get_state()) then return false end
    if not runtime.arcane_blast_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end

    local phase = update_arcane_phase(me, target)
    local ab_stacks = utils.get_debuff_stacks(me, spells.DEBUFF_ARCANE_BLAST)
    local has_clearcasting = utils.has_buff(me, spells.BUFF_CLEARCASTING)
    local has_pom = utils.has_buff(me, spells.BUFF_PRESENCE_OF_MIND)
    local has_ap = utils.has_buff(me, spells.BUFF_ARCANE_POWER)
    local has_iv = utils.has_buff(me, spells.BUFF_ICY_VEINS)

    if phase == "conserve" then
        local max_casts = (menu.arcane_blasts_between_fillers and menu.arcane_blasts_between_fillers:get()) or 3
        if ab_stacks >= max_casts and not has_clearcasting then
            return false
        end
    end

    local dump_stacks = (menu.arcane_blast_dump_stacks and menu.arcane_blast_dump_stacks:get()) or 3
    local low_mana = utils.get_mana_pct(me) <= 35
    local should_dump = ab_stacks >= dump_stacks
        or (has_clearcasting and ab_stacks >= 1)
        or (low_mana and ab_stacks >= math.max(1, dump_stacks - 1))

    if should_dump and not has_ap and not has_iv and not has_pom then
        return false
    end

    if not utils.can_cast_hostile(runtime.arcane_blast_id, me, target) then return false end

    if utils.cast_target(runtime.arcane_blast_id, target, "Arcane Blast") then
        note_cast()
        return true
    end
    return false
end

local function try_filler(me, target)
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end

    local phase = update_arcane_phase(me, target)
    if phase ~= "conserve" then return false end

    local ab_stacks = utils.get_debuff_stacks(me, spells.DEBUFF_ARCANE_BLAST)
    local max_casts = (menu.arcane_blasts_between_fillers and menu.arcane_blasts_between_fillers:get()) or 3
    local will_drop = ab_will_drop(me)

    if ab_stacks < max_casts and not will_drop then return false end

    local filler_idx = (menu.arcane_filler and menu.arcane_filler:get()) or 1
    local filler_id = nil

    if filler_idx == 1 then
        filler_id = runtime.frostbolt_id
    elseif filler_idx == 2 then
        filler_id = runtime.fireball_id
    elseif filler_idx == 3 then
        filler_id = runtime.arcane_missiles_id
    elseif filler_idx == 4 then
        filler_id = runtime.scorch_id
    else
        filler_id = runtime.frostbolt_id
    end

    if not filler_id then return false end
    if not utils.can_cast_hostile(filler_id, me, target) then return false end

    if utils.cast_target(filler_id, target, "Filler") then
        note_cast()
        return true
    end
    return false
end

local function try_arcane_missiles(me, target)
    if not (menu.use_arcane_missiles and menu.use_arcane_missiles:get_state()) then return false end
    if not runtime.arcane_missiles_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end

    local has_clearcasting = utils.has_buff(me, spells.BUFF_CLEARCASTING)
    local ab_stacks = utils.get_debuff_stacks(me, spells.DEBUFF_ARCANE_BLAST)
    local dump_stacks = (menu.arcane_blast_dump_stacks and menu.arcane_blast_dump_stacks:get()) or 3

    if has_clearcasting then
        if utils.can_cast_hostile(runtime.arcane_missiles_id, me, target) then
            if utils.cast_target(runtime.arcane_missiles_id, target, "Arcane Missiles (Clearcast)") then
                note_cast()
                return true
            end
        end
    end

    local phase = update_arcane_phase(me, target)
    if phase == "conserve" and ab_stacks >= dump_stacks then
        if utils.can_cast_hostile(runtime.arcane_missiles_id, me, target) then
            if utils.cast_target(runtime.arcane_missiles_id, target, "Arcane Missiles (dump)") then
                note_cast()
                return true
            end
        end
    end

    return false
end

local function try_fire_blast_move(me, target)
    if not runtime.fire_blast_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_moving() then return false end
    if not utils.can_cast_hostile(runtime.fire_blast_id, me, target) then return false end

    if utils.cast_target_fast(runtime.fire_blast_id, target, "Fire Blast") then
        note_cast()
        return true
    end
    return false
end

local function try_mana_gem(me)
    if not (menu.use_mana_gem and menu.use_mana_gem:get_state()) then return false end
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
    if not (menu.use_evocation and menu.use_evocation:get_state()) then return false end
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
    if not (menu.use_ice_block and menu.use_ice_block:get_state()) then return false end
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
    if not (menu.use_frost_nova and menu.use_frost_nova:get_state()) then return false end
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

local function try_mage_armor(me)
    if not runtime.mage_armor_id then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_MAGE_ARMOR) then return false end
    if not (menu.use_mage_armor and menu.use_mage_armor:get_state()) then return false end
    if not utils.can_cast_self(runtime.mage_armor_id, me) then return false end

    if utils.cast_self(runtime.mage_armor_id, me, "Mage Armor") then
        return true
    end
    return false
end

local function try_trinkets(me)
    if not (menu.use_trinkets and menu.use_trinkets:get_state()) then return false end
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

    if try_ice_block(me) then return true end
    if try_frost_nova(me) then return true end

    if try_aoe(me, target) then return true end

    if try_mana_gem(me) then return true end
    if try_evocation(me) then return true end

    if try_cold_snap(me) then return true end
    if try_presence_of_mind(me) then return true end
    if try_icy_veins(me, target) then return true end
    if try_arcane_power(me, target) then return true end
    if try_racial(me, target) then return true end
    if try_trinkets(me) then return true end

    if try_movement_spell(me, target) then return true end
    if try_fire_blast_move(me, target) then return true end

    if try_arcane_blast(me, target) then return true end
    if try_arcane_missiles(me, target) then return true end
    if try_filler(me, target) then return true end

    return false
end

-- Mode refresh
local function refresh_mode_cache()
    local me = _get_local_player()
    if not me then return end
    runtime.cached_mode = utils.detect_mode(me)
end

-- On update callback
core.register_on_update_callback(function()
    local me = _get_local_player()
    if not me then return end
    if me:is_dead() then return end

    if utils.throttle("mode_refresh", 5.0) then
        refresh_mode_cache()
    end

    if not menu.is_enabled() then return end

    if try_mage_armor(me) then return end

    local target = me:get_target()
    if not is_valid_hostile_target(me, target) then return end

    do_rotation(me, target)
end)

-- Export toggle settings for external access
local NS = _G.EAXMageArcane and _G.EAXMageArcane.NS or {}
_G.EAXMageArcane = _G.EAXMageArcane or {}
_G.EAXMageArcane.NS = NS
NS.toggle_menu = menu.toggle_menu

return {}
