require("libraries/path_bootstrap")
-- EAX Warlock Affliction | main.lua | Project Sylvanas
-- DoT-focused rotation: Corruption, UA, Siphon Life, CoA, Drain Soul execute

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

-- Hot-path local caching (performance critical)
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cd = core.spell_book.get_spell_cooldown

-- Runtime state
local runtime = {
    corruption_id = nil,
    unstable_affliction_id = nil,
    siphon_life_id = nil,
    curse_agony_id = nil,
    curse_doom_id = nil,
    curse_elements_id = nil,
    drain_soul_id = nil,
    drain_life_id = nil,
    shadow_bolt_id = nil,
    immolate_id = nil,
    life_tap_id = nil,
    fear_id = nil,
    death_coil_id = nil,
    howl_of_terror_id = nil,
    seed_of_corruption_id = nil,
    amplify_curse_id = nil,
    fel_armor_id = nil,
    demon_armor_id = nil,
    soulstone_id = nil,
    create_healthstone_id = nil,
    create_soulstone_id = nil,
    summon_imp_id = nil,
    summon_voidwalker_id = nil,
    summon_succubus_id = nil,
    summon_felhunter_id = nil,
    summon_felguard_id = nil,
    fel_domination_id = nil,
    soul_link_id = nil,
    last_cast_time = 0,
    pending_casts = {},
    cached_mode = "solo",
}

-- Constants
local PENDING_CAST_TIMEOUT_S = 2.5
local DOT_REFRESH_MS = 3000
local DRAIN_SOUL_HP_PCT = 0.25

-- Resolve spell IDs from rank tables
local function resolve_spells()
    runtime.corruption_id = utils.resolve_spell_id(spells.CORRUPTION)
    runtime.unstable_affliction_id = utils.resolve_spell_id(spells.UNSTABLE_AFFLICTION)
    runtime.siphon_life_id = utils.resolve_spell_id(spells.SIPHON_LIFE)
    runtime.curse_agony_id = utils.resolve_spell_id(spells.CURSE_OF_AGONY)
    runtime.curse_doom_id = utils.resolve_spell_id(spells.CURSE_OF_DOOM)
    runtime.curse_elements_id = utils.resolve_spell_id(spells.CURSE_OF_ELEMENTS)
    runtime.drain_soul_id = utils.resolve_spell_id(spells.DRAIN_SOUL)
    runtime.drain_life_id = utils.resolve_spell_id(spells.DRAIN_LIFE)
    runtime.shadow_bolt_id = utils.resolve_spell_id(spells.SHADOW_BOLT)
    runtime.immolate_id = utils.resolve_spell_id(spells.IMMOLATE)
    runtime.life_tap_id = utils.resolve_spell_id(spells.LIFE_TAP)
    runtime.fear_id = utils.resolve_spell_id(spells.FEAR)
    runtime.death_coil_id = utils.resolve_spell_id(spells.DEATH_COIL)
    runtime.howl_of_terror_id = utils.resolve_spell_id(spells.HOWL_OF_TERROR)
    runtime.seed_of_corruption_id = utils.resolve_spell_id(spells.SEED_OF_CORRUPTION)
    runtime.amplify_curse_id = utils.resolve_spell_id(spells.AMPLIFY_CURSE)
    runtime.fel_armor_id = utils.resolve_spell_id(spells.FEL_ARMOR)
    runtime.demon_armor_id = utils.resolve_spell_id(spells.DEMON_ARMOR)
    runtime.soulstone_id = utils.resolve_spell_id(spells.SOULSTONE)
    runtime.create_healthstone_id = utils.resolve_spell_id(spells.CREATE_HEALTHSTONE)
    runtime.create_soulstone_id = utils.resolve_spell_id(spells.CREATE_SOULSTONE)
    runtime.summon_imp_id = utils.resolve_spell_id(spells.SUMMON_IMP)
    runtime.summon_voidwalker_id = utils.resolve_spell_id(spells.SUMMON_VOIDWALKER)
    runtime.summon_succubus_id = utils.resolve_spell_id(spells.SUMMON_SUCCUBUS)
    runtime.summon_felhunter_id = utils.resolve_spell_id(spells.SUMMON_FELHUNTER)
    runtime.summon_felguard_id = utils.resolve_spell_id(spells.SUMMON_FELGUARD)
    runtime.fel_domination_id = utils.resolve_spell_id(spells.FEL_DOMINATION)
    runtime.soul_link_id = utils.resolve_spell_id(spells.SOUL_LINK)
end

resolve_spells()

-- Utility functions
local function note_cast()
    runtime.last_cast_time = _core_time()
end

local function is_gcd_ready()
    return _get_gcd() <= 0
end

local function is_pending_cast(spell_id)
    if not spell_id then return false end
    local expire_time = runtime.pending_casts[spell_id]
    if not expire_time then return false end
    if _core_time() > expire_time then
        runtime.pending_casts[spell_id] = nil
        return false
    end
    return true
end

local function mark_pending_cast(spell_id)
    if not spell_id then return end
    runtime.pending_casts[spell_id] = _core_time() + PENDING_CAST_TIMEOUT_S
end

local function get_effective_mode()
    local idx = (menu.mode and menu.mode:get()) or 1
    if idx == 2 then return "solo"
    elseif idx == 3 then return "dungeon"
    elseif idx == 4 then return "raid"
    end
    return runtime.cached_mode
end

local function refresh_mode_cache()
    local me = _get_local_player()
    if not me then return end
    runtime.cached_mode = utils.detect_mode(me) or runtime.cached_mode or "solo"
end

-- Target validation
local function is_valid_target(me, target)
    if not me or not target then return false end
    if not target:is_valid() or target:is_dead() then return false end
    return me:can_attack(target)
end

-- Try functions (9-step pattern)

-- 1. Try Fel Armor (self buff)
local function try_fel_armor(me)
    if not (menu.use_fel_armor and menu.use_fel_armor:get_state()) then return false end
    if not runtime.fel_armor_id then return false end
    if utils.has_buff(me, spells.BUFF_FEL_ARMOR) then return false end
    if not utils.can_cast_self(runtime.fel_armor_id, me) then return false end
    if utils.cast_self(runtime.fel_armor_id, me) then
        note_cast()
        utils.log_debug(menu, "Fel Armor")
        return true
    end
    return false
end

-- 2. Try Demon Armor (fallback self buff)
local function try_demon_armor(me)
    if not (menu.use_demon_armor and menu.use_demon_armor:get_state()) then return false end
    if not runtime.demon_armor_id then return false end
    if utils.has_buff(me, spells.BUFF_FEL_ARMOR) then return false end
    if utils.has_buff(me, spells.BUFF_DEMON_ARMOR) then return false end
    if not utils.can_cast_self(runtime.demon_armor_id, me) then return false end
    if utils.cast_self(runtime.demon_armor_id, me) then
        note_cast()
        utils.log_debug(menu, "Demon Armor")
        return true
    end
    return false
end

-- 3. Try Unstable Affliction (highest priority DoT)
local function try_unstable_affliction(me, target)
    if not (menu.use_unstable_affliction and menu.use_unstable_affliction:get_state()) then return false end
    if not runtime.unstable_affliction_id then return false end
    if not is_valid_target(me, target) then return false end
    if is_pending_cast(runtime.unstable_affliction_id) then return false end
    local remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_UNSTABLE_AFFLICTION)
    if remaining > DOT_REFRESH_MS then return false end
    if not utils.can_cast_hostile(runtime.unstable_affliction_id, me, target) then return false end
    if utils.cast_target(runtime.unstable_affliction_id, me, target) then
        mark_pending_cast(runtime.unstable_affliction_id)
        note_cast()
        utils.log_debug(menu, "Unstable Affliction")
        return true
    end
    return false
end

-- 4. Try Corruption (core DoT)
local function try_corruption(me, target)
    if not (menu.use_corruption and menu.use_corruption:get_state()) then return false end
    if not runtime.corruption_id then return false end
    if not is_valid_target(me, target) then return false end
    if is_pending_cast(runtime.corruption_id) then return false end
    local remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_CORRUPTION)
    if remaining > DOT_REFRESH_MS then return false end
    if not utils.can_cast_hostile(runtime.corruption_id, me, target) then return false end
    if utils.cast_target(runtime.corruption_id, me, target) then
        mark_pending_cast(runtime.corruption_id)
        note_cast()
        utils.log_debug(menu, "Corruption")
        return true
    end
    return false
end

-- 5. Try Siphon Life (healing DoT)
local function try_siphon_life(me, target)
    if not (menu.use_siphon_life and menu.use_siphon_life:get_state()) then return false end
    if not runtime.siphon_life_id then return false end
    if not is_valid_target(me, target) then return false end
    if is_pending_cast(runtime.siphon_life_id) then return false end
    local remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_SIPHON_LIFE)
    if remaining > DOT_REFRESH_MS then return false end
    if not utils.can_cast_hostile(runtime.siphon_life_id, me, target) then return false end
    if utils.cast_target(runtime.siphon_life_id, me, target) then
        mark_pending_cast(runtime.siphon_life_id)
        note_cast()
        utils.log_debug(menu, "Siphon Life")
        return true
    end
    return false
end

-- 6. Try Curse (Agony or Elements)
local function try_curse(me, target)
    local mode = get_effective_mode()
    local in_group = mode == "dungeon" or mode == "raid"
    
    -- Try Curse of Elements in group content
    if in_group and (menu.use_curse_of_elements and menu.use_curse_of_elements:get_state()) and runtime.curse_elements_id then
        if not utils.has_debuff(target, spells.DEBUFF_CURSE_OF_ELEMENTS) then
            if not is_pending_cast(runtime.curse_elements_id) and utils.can_cast_hostile(runtime.curse_elements_id, me, target) then
                if utils.cast_target(runtime.curse_elements_id, me, target) then
                    mark_pending_cast(runtime.curse_elements_id)
                    note_cast()
                    utils.log_debug(menu, "Curse of Elements")
                    return true
                end
            end
        end
    end
    
    -- Try Curse of Agony
    if not (menu.use_curse_of_agony and menu.use_curse_of_agony:get_state()) then return false end
    if not runtime.curse_agony_id then return false end
    if not is_valid_target(me, target) then return false end
    if is_pending_cast(runtime.curse_agony_id) then return false end
    local remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_CURSE_OF_AGONY)
    if remaining > DOT_REFRESH_MS then return false end
    if not utils.can_cast_hostile(runtime.curse_agony_id, me, target) then return false end
    
    -- Amplify Curse before CoA
    if (menu.use_amplify_curse and menu.use_amplify_curse:get_state()) and runtime.amplify_curse_id then
        if (menu.amplify_before_coa and menu.amplify_before_coa:get_state()) and not utils.has_buff(me, spells.BUFF_AMPLIFY_CURSE) then
            if utils.can_cast_self(runtime.amplify_curse_id, me) then
                utils.cast_self(runtime.amplify_curse_id, me)
                utils.log_debug(menu, "Amplify Curse")
            end
        end
    end
    
    if utils.cast_target(runtime.curse_agony_id, me, target) then
        mark_pending_cast(runtime.curse_agony_id)
        note_cast()
        utils.log_debug(menu, "Curse of Agony")
        return true
    end
    return false
end

-- 7. Try Drain Soul (execute phase)
local function try_drain_soul(me, target)
    if not (menu.use_drain_soul and menu.use_drain_soul:get_state()) then return false end
    if not runtime.drain_soul_id then return false end
    if not is_valid_target(me, target) then return false end
    if is_pending_cast(runtime.drain_soul_id) then return false end
    local hp_pct = utils.get_health_pct(target)
    if hp_pct > DRAIN_SOUL_HP_PCT then return false end
    if not utils.can_cast_hostile(runtime.drain_soul_id, me, target) then return false end
    if utils.cast_target(runtime.drain_soul_id, me, target) then
        mark_pending_cast(runtime.drain_soul_id)
        note_cast()
        utils.log_debug(menu, "Drain Soul (execute)")
        return true
    end
    return false
end

-- 8. Try Drain Life (self-heal filler)
local function try_drain_life(me, target)
    if not (menu.use_drain_life and menu.use_drain_life:get_state()) then return false end
    if not runtime.drain_life_id then return false end
    if not is_valid_target(me, target) then return false end
    if is_pending_cast(runtime.drain_life_id) then return false end
    local my_hp = utils.get_health_pct(me)
    local threshold = ((menu.drain_life_hp_pct and menu.drain_life_hp_pct:get()) or 40) / 100
    if my_hp > threshold then return false end
    if not utils.can_cast_hostile(runtime.drain_life_id, me, target) then return false end
    if utils.cast_target(runtime.drain_life_id, me, target) then
        mark_pending_cast(runtime.drain_life_id)
        note_cast()
        utils.log_debug(menu, "Drain Life (self-heal)")
        return true
    end
    return false
end

-- 9. Try Shadow Bolt (filler)
local function try_shadow_bolt(me, target)
    if not (menu.use_shadow_bolt and menu.use_shadow_bolt:get_state()) then return false end
    if not runtime.shadow_bolt_id then return false end
    if not is_valid_target(me, target) then return false end
    if is_pending_cast(runtime.shadow_bolt_id) then return false end
    if not utils.can_cast_hostile(runtime.shadow_bolt_id, me, target) then return false end
    if utils.cast_target(runtime.shadow_bolt_id, me, target) then
        mark_pending_cast(runtime.shadow_bolt_id)
        note_cast()
        utils.log_debug(menu, "Shadow Bolt")
        return true
    end
    return false
end

-- Utility try functions
local function try_life_tap(me)
    if not (menu.use_life_tap and menu.use_life_tap:get_state()) then return false end
    if not runtime.life_tap_id then return false end
    if me:is_in_combat() then return false end
    local mana_pct = utils.get_mana_pct(me)
    local hp_pct = utils.get_health_pct(me)
    local mana_threshold = ((menu.life_tap_mana_pct and menu.life_tap_mana_pct:get()) or 40) / 100
    local hp_threshold = ((menu.life_tap_hp_pct and menu.life_tap_hp_pct:get()) or 60) / 100
    if mana_pct > mana_threshold then return false end
    if hp_pct < hp_threshold then return false end
    if not utils.can_cast_self(runtime.life_tap_id, me) then return false end
    if utils.cast_self(runtime.life_tap_id, me) then
        note_cast()
        utils.log_debug(menu, "Life Tap")
        return true
    end
    return false
end

local function try_death_coil(me, target)
    if not (menu.use_death_coil and menu.use_death_coil:get_state()) then return false end
    if not runtime.death_coil_id then return false end
    if not is_valid_target(me, target) then return false end
    local hp = utils.get_health_pct(me)
    if hp > 0.40 then return false end
    if not utils.can_cast_hostile(runtime.death_coil_id, me, target) then return false end
    if utils.cast_target(runtime.death_coil_id, me, target) then
        note_cast()
        utils.log_debug(menu, "Death Coil (defensive)")
        return true
    end
    return false
end

local function try_create_healthstone(me)
    if not (menu.use_create_healthstone and menu.use_create_healthstone:get_state()) then return false end
    if not runtime.create_healthstone_id then return false end
    if me:is_in_combat() then return false end
    if not utils.can_cast_self(runtime.create_healthstone_id, me) then return false end
    -- Check if we already have a healthstone
    for _, item_id in ipairs(spells.HEALTHSTONE_ITEMS) do
        if core.inventory and core.inventory.get_item_count then
            local count = core.inventory.get_item_count(item_id)
            if count and count > 0 then return false end
        end
    end
    if utils.cast_self(runtime.create_healthstone_id, me) then
        note_cast()
        utils.log_debug(menu, "Create Healthstone")
        return true
    end
    return false
end

local function try_use_healthstone(me)
    if not (menu.use_healthstone and menu.use_healthstone:get_state()) then return false end
    if not me:is_in_combat() then return false end
    local hp = utils.get_health_pct(me)
    local threshold = ((menu.healthstone_hp_pct and menu.healthstone_hp_pct:get()) or 30) / 100
    if hp > threshold then return false end
    for _, item_id in ipairs(spells.HEALTHSTONE_ITEMS) do
        if core.inventory and core.inventory.get_item_count then
            local count = core.inventory.get_item_count(item_id)
            if count and count > 0 then
                if core.input.use_item(item_id) then
                    utils.log_debug(menu, "Use Healthstone")
                    return true
                end
            end
        end
    end
    return false
end

local function try_self_soulstone(me)
    if not (menu.use_soulstone and menu.use_soulstone:get_state()) then return false end
    if not runtime.soulstone_id then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, spells.SOULSTONE) then return false end
    if not utils.can_cast_self(runtime.soulstone_id, me) then return false end
    if utils.cast_self(runtime.soulstone_id, me) then
        note_cast()
        utils.log_debug(menu, "Soulstone (self)")
        return true
    end
    return false
end

-- Count soul shards
local function count_soul_shards()
    if not core or not core.inventory or not core.inventory.get_items_in_bag then
        return 0
    end
    local total = 0
    for bag = 0, 4 do
        local ok, items = pcall(function() return core.inventory.get_items_in_bag(bag) end)
        if ok and items then
            for _, slot in ipairs(items) do
                local item = slot and slot.object
                if item and item.is_valid and item:is_valid() and item.get_item_id then
                    if item:get_item_id() == 6265 then
                        total = total + (item.get_item_stack_count and item:get_item_stack_count() or 1)
                    end
                end
            end
        end
    end
    return total
end

-- Pet management
local PET_NPC_IDS = {
    imp = 416,
    voidwalker = 1860,
    succubus = 1863,
    felhunter = 417,
    felguard = 17252,
}

local SUMMON_SPELLS = {
    imp = spells.SUMMON_IMP,
    voidwalker = spells.SUMMON_VOIDWALKER,
    succubus = spells.SUMMON_SUCCUBUS,
    felhunter = spells.SUMMON_FELHUNTER,
    felguard = spells.SUMMON_FELGUARD,
}

local function get_pet_npc_id()
    local me = _get_local_player()
    if not me then return 0 end
    local pet = me.get_pet and me:get_pet() or nil
    if not pet or not pet:is_valid() or pet:is_dead() then return 0 end
    return pet.get_npc_id and pet:get_npc_id() or 0
end

local function current_pet_name()
    local npc = get_pet_npc_id()
    for name, id in pairs(PET_NPC_IDS) do
        if npc == id then return name end
    end
    return "none"
end

local function desired_pet_name()
    local pet_mode = (menu.preferred_pet and menu.preferred_pet:get()) or 1
    if pet_mode == 2 then return "imp" end
    if pet_mode == 3 then return "voidwalker" end
    if pet_mode == 4 then return "succubus" end
    if pet_mode == 5 then return "felhunter" end
    if pet_mode == 6 then return "felguard" end
    return nil
end

local function try_summon_pet(me)
    if not (menu.use_summon_pet and menu.use_summon_pet:get_state()) then return false end
    if me:is_in_combat() then return false end
    if not utils.throttle("pet_check", 5.0) then return false end
    
    local current = current_pet_name()
    local desired = desired_pet_name()
    if not desired then return false end
    if current == desired then return false end
    
    local spell_table = SUMMON_SPELLS[desired]
    if not spell_table then return false end
    local spell_id = utils.resolve_spell_id(spell_table)
    if not spell_id then return false end
    
    -- Check for soul shard (all except imp need one)
    if desired ~= "imp" and count_soul_shards() < 1 then
        return false
    end
    
    if not utils.can_cast_self(spell_id, me) then return false end
    utils.cast_self(spell_id, me)
    utils.log_debug(menu, "Summoning " .. desired)
    return true
end

-- Main rotation
local function do_rotation(me, target)
    if not is_gcd_ready() then return end
    
    -- Defensive priority
    if try_death_coil(me, target) then return end
    
    -- DoT priority (maintain all DoTs)
    if try_unstable_affliction(me, target) then return end
    if try_corruption(me, target) then return end
    if try_siphon_life(me, target) then return end
    if try_curse(me, target) then return end
    
    -- Execute phase
    if try_drain_soul(me, target) then return end
    
    -- Self-heal if needed
    if try_drain_life(me, target) then return end
    
    -- Filler
    if try_shadow_bolt(me, target) then return end
end

-- Update callback
core.register_on_update_callback(function()
    if not menu.is_enabled() then return end

    if utils.throttle("mode_refresh", 5.0) then
        refresh_mode_cache()
    end

    local me = _get_local_player()
    if not me or me:is_dead() then return end
    
    -- OOC utilities
    if try_fel_armor(me) then return end
    if try_demon_armor(me) then return end
    if try_life_tap(me) then return end
    if try_create_healthstone(me) then return end
    if try_self_soulstone(me) then return end
    if try_summon_pet(me) then return end
    
    if not me:is_in_combat() then return end
    
    -- Combat utilities
    if try_use_healthstone(me) then return end
    
    local target = me:get_target()
    if not is_valid_target(me, target) then
        target = utils.find_best_target(me)
    end
    if not target then return end
    
    do_rotation(me, target)
end)

-- Toggle function for unified menu
local NS = _G.EAXWarlockAffliction and _G.EAXWarlockAffliction.NS or {}
NS.toggle_menu = menu.toggle_menu
_G.EAXWarlockAffliction = _G.EAXWarlockAffliction or {}
_G.EAXWarlockAffliction.NS = NS
