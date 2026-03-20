-- main.lua
-- EAX Warlock Destruction | Rotation logic

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")
local color     = require("color")

---@type interrupt_manager
local interrupt_manager = require("common/eax_shared/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("common/eax_shared/ooc_manager")
---@type vendor_automation
local vendor_automation = require("common/eax_shared/vendor_automation")
---@type consumables_manager
local consumables_manager = require("common/eax_shared/consumables_manager")
---@type mount_manager
local mount_manager = require("common/eax_shared/mount_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type creature_utils
local creature_utils = require("creature_utils")

---@type encounter_manager
local encounter_manager = require("common/eax_shared/encounter_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("destro", "Warlock Destro")


-- Phase 04 visual telemetry wiring
local dps_meter = require("common/eax_shared/dps_meter")
local cooldown_tracker = require("common/eax_shared/cooldown_tracker")
local visual_state = require("common/eax_shared/visual_state")
local reactive_runtime = require("eax_shared/reactive_runtime")

local _visual_ttd_tracker = nil
local _visual_ttd_ok, _visual_ttd_mod = pcall(require, "ttd_tracker")
if _visual_ttd_ok and _visual_ttd_mod then
    _visual_ttd_tracker = _visual_ttd_mod
end

local _visual_runtime = {
    in_combat = false,
    last_me_hp_pct = nil,
    last_target_hp_pct = nil,
    reactive_state = {},
}

local _visual_on_cast = esp_renderer.on_cast
function esp_renderer.on_cast(spell_id, name, col, target_name)
    if spell_id and core and core.time and core.spell_book and core.spell_book.get_spell_cooldown then
        local now_s = core.time()
        local cd_s = tonumber(core.spell_book.get_spell_cooldown(spell_id)) or 0
        cooldown_tracker.set_next_spell(spell_id, now_s, cd_s)
    end
    return _visual_on_cast(spell_id, name, col, target_name)
end

local function visual_get_ttd_seconds(target)
    if not _visual_ttd_tracker or not _visual_ttd_tracker.get then return "--" end
    local ok, value = pcall(function() return _visual_ttd_tracker.get(target) end)
    if not ok then return "--" end
    local ttd_value = tonumber(value)
    if not ttd_value then return "--" end
    return ttd_value
end

local function visual_build_tracked_auras(me, target)
    local tracked_auras = {}
    if me and me:is_in_combat() then
        tracked_auras[#tracked_auras + 1] = { label = "Combat", active = true }
    end
    if target and target:is_valid() and not target:is_dead() then
        if target:is_casting_spell() then
            tracked_auras[#tracked_auras + 1] = { label = "Cast", active = true }
        end
        if target:is_channelling_spell() then
            tracked_auras[#tracked_auras + 1] = { label = "Channel", active = true }
        end
    end
    return tracked_auras
end

local function visual_update_snapshot(me, target)
    if not me then return end
    local in_combat = me:is_in_combat()
    if in_combat and not _visual_runtime.in_combat then
        dps_meter.on_combat_start()
        _visual_runtime.in_combat = true
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
    elseif (not in_combat) and _visual_runtime.in_combat then
        dps_meter.on_combat_end()
        _visual_runtime.in_combat = false
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
    end

    local me_hp_pct = tonumber(me:get_health_percentage())
    if in_combat and _visual_runtime.last_me_hp_pct and me_hp_pct and me_hp_pct > _visual_runtime.last_me_hp_pct then
        dps_meter.on_heal(me_hp_pct - _visual_runtime.last_me_hp_pct)
    end
    _visual_runtime.last_me_hp_pct = me_hp_pct

    local target_hp_pct = nil
    if target and target:is_valid() and not target:is_dead() then
        target_hp_pct = tonumber(target:get_health_percentage())
    end
    if in_combat and _visual_runtime.last_target_hp_pct and target_hp_pct and target_hp_pct < _visual_runtime.last_target_hp_pct then
        dps_meter.on_damage(_visual_runtime.last_target_hp_pct - target_hp_pct)
    end
    _visual_runtime.last_target_hp_pct = target_hp_pct

    reactive_runtime.update_tick(me, target, {
        encounter_manager = encounter_manager,
        state = _visual_runtime.reactive_state,
        spec = "EAXWarlockDestruction",
    })

    local snapshot = visual_state.build_snapshot({
        now_s = core.time(),
        ttd_seconds = visual_get_ttd_seconds(target),
        tracked_auras = visual_build_tracked_auras(me, target),
    })

    if esp_renderer.update_visual_snapshot then
        esp_renderer.update_visual_snapshot(snapshot)
    elseif esp_renderer.set_visual_snapshot then
        esp_renderer.set_visual_snapshot(snapshot)
    end
end

core.register_on_update_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then return end
    local target = me:get_target()
    visual_update_snapshot(me, target)
end)
---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("common/eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("common/eax_shared/defensive_manager")

---@type mana_conservator
local mana_conservator = require("mana_conservator")
---@type dot_manager
local dot_manager = require("eax_shared/dot_manager")
---@type threat_manager
local threat_manager = require("eax_shared/threat_manager")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    drain_life_id = nil,
    immolate_id = nil,
    shadow_bolt_id = nil,
    drain_soul_id = nil,
    seed_of_corruption_id = nil,
    incinerate_id = nil,
    conflagrate_id = nil,
    shadowfury_id = nil,
    life_tap_id = nil,
    last_cast_time = 0,
    pending_casts = {},
    cached_mode = "solo",
    prev_toggle_state = false,
    set_multiplier = 1.0,
}

local GCD_INTERVAL_S = 0.05
local PENDING_CAST_TIMEOUT_S = 2.5
local LIFE_TAP_MANA_PCT = 0.38

local function resolve_spells()
    runtime.immolate_id = utils.resolve_spell_id(spells.IMMOLATE)
    runtime.shadow_bolt_id        = utils.resolve_spell_id(spells.SHADOW_BOLT)
    runtime.drain_soul_id          = utils.resolve_spell_id(spells.DRAIN_SOUL)
    runtime.seed_of_corruption_id  = utils.resolve_spell_id(spells.SEED_OF_CORRUPTION)
    runtime.incinerate_id = utils.resolve_spell_id(spells.INCINERATE)
    runtime.conflagrate_id = utils.resolve_spell_id(spells.CONFLAGRATE)
    runtime.shadowfury_id = utils.resolve_spell_id(spells.SHADOWFURY)
    runtime.life_tap_id = utils.resolve_spell_id(spells.LIFE_TAP)
end

local function log_spells()
    core.log("[EAX Warlock Destruction] Resolved: Immolate=" .. tostring(runtime.immolate_id)
        .. " Conflag=" .. tostring(runtime.conflagrate_id)
        .. " Profile Fire=" .. tostring(runtime.incinerate_id)
        .. " Shadow=" .. tostring(runtime.shadow_bolt_id))
end

resolve_spells()
log_spells()

local function update_set_bonus()
    local me = core.object_manager.get_local_player()
    if not me then return end
    
    local voidheart_mult = utils.get_set_multiplier(me, "Voidheart")
    local voidheart_regalia_mult = utils.get_set_multiplier(me, "VoidheartRegalia")
    local malefic_mult = utils.get_set_multiplier(me, "Malefic")
    
    runtime.set_multiplier = voidheart_mult
    if voidheart_regalia_mult > runtime.set_multiplier then
        runtime.set_multiplier = voidheart_regalia_mult
    end
    if malefic_mult > runtime.set_multiplier then
        runtime.set_multiplier = malefic_mult
    end
    
    if runtime.set_multiplier > 1.0 then
        utils.log_debug(menu, "Set bonus: " .. tostring(runtime.set_multiplier))
    end
end

local function is_pending_cast(spell_id)
    if not spell_id then
        return false
    end
    local pending = runtime.pending_casts[spell_id]
    if not pending then
        return false
    end
    if (core.time() - pending) >= PENDING_CAST_TIMEOUT_S then
        runtime.pending_casts[spell_id] = nil
        return false
    end
    return true
end

local function mark_pending_cast(spell_id)
    if not spell_id then
        return
    end
    runtime.pending_casts[spell_id] = core.time()
end

local function note_cast()
    runtime.last_cast_time = core.time()
end

local function is_gcd_ready()
    if (core.time() - runtime.last_cast_time) < GCD_INTERVAL_S then
        return false
    end
    return core.spell_book.get_global_cooldown() <= 0
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
    local idx = menu.mode:get()
    if idx == 2 then
        return "solo"
    elseif idx == 3 then
        return "dungeon"
    elseif idx == 4 then
        return "raid"
    end
    return runtime.cached_mode
end

local function get_profile()
    local profile_idx = menu.profile:get()
    if profile_idx == 2 then
        return "fire"
    elseif profile_idx == 3 then
        return "shadow"
    end
    if runtime.incinerate_id and not runtime.shadow_bolt_id then
        return "fire"
    end
    if runtime.shadow_bolt_id then
        return "shadow"
    end
    return "fire"
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
        utils.log_debug(menu, "Toggle -> " .. tostring(menu.enabled:get_state()))
    end
    runtime.prev_toggle_state = current
end

local function is_valid_target(me, target)
    if not me or not target then
        return false
    end
    if not target:is_valid() or target:is_dead() then
        return false
    end
    return me:can_attack(target)
end

local function try_cast_spell(me, spell_id, target, label)
    if not spell_id or not target then
        return false
    end
    if is_pending_cast(spell_id) then
        return false
    end
    if not utils.can_cast_hostile(spell_id, me, target) then
        return false
    end
    if utils.cast_target(spell_id, target) then
        mark_pending_cast(spell_id)
        note_cast()
        utils.log_debug(menu, label .. " cast")
        return true
    end
    return false
end

local function try_cast_self(me, spell_id, label)
    if not spell_id or not me then
        return false
    end
    if not utils.can_cast_self(spell_id, me) then
        return false
    end
    if utils.cast_self(spell_id, me) then
        note_cast()
        utils.log_debug(menu, label .. " cast")
        return true
    end
    return false
end

local function try_immolate(me, target)
    if not menu.use_immolate:get_state() or not runtime.immolate_id then
        return false
    end
    -- Use dot_manager for safe refresh timing (never clips final tick)
    if utils.has_debuff(target, spells.IMMOLATE) then
        if not dot_manager.can_refresh_dot(target, spells.IMMOLATE, runtime.immolate_id, utils.get_debuff_remaining_ms) then
            return false
        end
    end
    return try_cast_spell(me, runtime.immolate_id, target, "Immolate")
end

local function try_shadowfury(me, target)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_shadowfury:get_state() or not runtime.shadowfury_id then
        return false
    end
    if not target:is_casting_spell() then
        return false
    end
    return try_cast_spell(me, runtime.shadowfury_id, target, "Shadowfury")
end

local function is_conflagrate_proc_ready(me, target)
    if not menu.use_conflagrate:get_state() or not runtime.conflagrate_id then
        return false
    end
    if not is_valid_target(me, target) then
        return false
    end
    if is_pending_cast(runtime.conflagrate_id) then
        return false
    end
    if core.spell_book.get_global_cooldown() > 0 then
        return false
    end

    local has_immolate_proc_window = utils.has_debuff(target, spells.DEBUFF_IMMOLATE)
    if not has_immolate_proc_window then
        return false
    end

    return utils.can_cast_hostile(runtime.conflagrate_id, me, target)
end

local function try_conflagrate(me, target)
    if enc and enc.hold_cooldowns then return false end
    if not is_conflagrate_proc_ready(me, target) then
        return false
    end
    return try_cast_spell(me, runtime.conflagrate_id, target, "Conflagrate")
end

local function try_nuke(me, target, profile)
    if profile == "fire" and menu.use_incinerate:get_state() and runtime.incinerate_id then
        if try_cast_spell(me, runtime.incinerate_id, target, "Incinerate") then
                    esp_renderer.on_cast(nil, "Immolate", color.orange(220))
                esp_renderer.on_cast(nil, "Incinerate", color.red(220))
                esp_renderer.on_cast(nil, "Conflagrate", color.yellow(220))
        return true
        end
    end
    if profile == "shadow" and menu.use_shadow_bolt:get_state() and runtime.shadow_bolt_id then
        if try_cast_spell(me, runtime.shadow_bolt_id, target, "Shadow Bolt") then
            return true
        end
    end
    if profile ~= "shadow" and menu.use_shadow_bolt:get_state() and runtime.shadow_bolt_id then
        return try_cast_spell(me, runtime.shadow_bolt_id, target, "Shadow Bolt")
    end
    if profile ~= "fire" and menu.use_incinerate:get_state() and runtime.incinerate_id then
        return try_cast_spell(me, runtime.incinerate_id, target, "Incinerate")
    end
    return false
end

local function try_life_tap(me, mode)
    if not menu.use_life_tap:get_state() or not runtime.life_tap_id then
        return false
    end
    local health_pct = utils.get_health_pct(me)
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct >= LIFE_TAP_MANA_PCT then
        return false
    end
    local threshold = menu.life_tap_threshold:get() / 100
    if mode == "raid" then
        threshold = math.max(threshold, 0.55)
    elseif mode == "dungeon" then
        threshold = math.max(threshold, 0.5)
    end
    if health_pct < threshold then
        return false
    end
    return try_cast_self(me, runtime.life_tap_id, "Life Tap")
end


-- --- Pet selection + management (v1.4) ------------------------------------

local PET_NPC_IDS = {
    imp = 416,
    voidwalker = 1860,
    succubus = 1863,
    felhunter = 417,
    felguard = 17252,
}

local SUMMON_SPELLS = {
    imp        = spells.SUMMON_IMP,
    voidwalker = spells.SUMMON_VOIDWALKER,
    succubus   = spells.SUMMON_SUCCUBUS,
    felhunter  = spells.SUMMON_FELHUNTER,
    felguard   = spells.SUMMON_FELGUARD,
}

local function get_pet_npc_id()
    local me = core.object_manager.get_local_player()
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

local function desired_pet_name(mode)
    -- Spec-appropriate default: overridden by subclass if needed
    if mode == "raid"    then return "imp" end
    if mode == "dungeon" then return "felhunter" end
    return "voidwalker"
end

local function try_summon_correct_pet(me, mode)
    if not menu.auto_pet or not menu.auto_pet:get_state() then return false end
    if me:is_in_combat() then return false end  -- never summon mid-combat
    if not utils.throttle("warlock_pet_check", 5.0) then return false end

    local current = current_pet_name()
    local desired = desired_pet_name(mode)

    if current == desired then return false end  -- already correct

    local spell_table = SUMMON_SPELLS[desired]
    if not spell_table then return false end
    local spell_id = utils.resolve_spell_id(spell_table)
    if not spell_id then return false end
    if not utils.can_cast_self(spell_id, me) then return false end

    utils.cast_self(spell_id, me)
    utils.log_debug(menu, "Summoning " .. desired)
    return true
end

-- --- Soul Shard farming (v1.4) --------------------------------------------
-- Use Drain Soul on targets below 10% HP to collect shards

local SHARD_FARM_HP_PCT = 0.10
local SHARD_ITEM_IDS = { 6265 }  -- Soul Shard (stacks, any version)

local function count_soul_shards()
    for i = 0, 35 do
        local item_id = core.inventory and core.inventory.get_item_id_in_bag_slot
                        and core.inventory.get_item_id_in_bag_slot(i)
        if item_id == 6265 then
            local count = core.inventory.get_item_count and core.inventory.get_item_count(6265)
            return count or 0
        end
    end
    -- Fallback: use utils if available
    if utils.get_item_count then return utils.get_item_count(6265) end
    return 0
end

local function try_soul_shard_farm(me, target, drain_soul_id)
    if not menu.auto_shard_farm or not menu.auto_shard_farm:get_state() then return false end
    if not drain_soul_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    local hp = utils.get_health_pct(target)
    if hp > SHARD_FARM_HP_PCT then return false end
    -- Only farm if below the shard threshold set in menu
    local min_shards = menu.min_shards and menu.min_shards:get() or 3
    if count_soul_shards() >= min_shards then return false end
    if not utils.can_cast_hostile(drain_soul_id, me, target) then return false end
    if utils.cast_target(drain_soul_id, target, "Drain Soul (shard)") then
        utils.log_debug(menu, "Drain Soul for shard farm")
        return true
    end
    return false
end



-- --- Seed of Corruption - AoE mode (v1.4) --------------------------------
-- Use Seed of Corruption on AoE packs (3+ enemies). Each Seed explodes
-- when the target takes 1044+ damage, dealing shadow damage to all nearby.

local SEED_AOE_THRESHOLD = 3

local function try_seed_of_corruption(me, target, enemy_count)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_seed_of_corruption or not menu.use_seed_of_corruption:get_state() then return false end
    if not runtime.seed_of_corruption_id then return false end
    if enemy_count < SEED_AOE_THRESHOLD then return false end
    if me:is_moving() then return false end
    -- Don't re-apply if Seed is already on target
    if utils.has_debuff(target, spells.DEBUFF_SEED_OF_CORRUPTION) then return false end
    if not utils.can_cast_hostile(runtime.seed_of_corruption_id, me, target) then return false end
    if utils.cast_target(runtime.seed_of_corruption_id, target, "Seed of Corruption") then
        utils.log_debug(menu, "Seed of Corruption (AoE x" .. tostring(enemy_count) .. ")")
        return true
    end
    return false
end


local function try_drain_life_defensive(me, target)
    if not menu.use_drain_life_def or not menu.use_drain_life_def:get_state() then return false end
    if not runtime.drain_life_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    local hp = me:get_health_percentage() / 100
    local threshold = menu.use_drain_life_def_hp_pct and (menu.use_drain_life_def_hp_pct:get() / 100) or 0.35
    if hp > threshold then return false end
    if not utils.can_cast_hostile(runtime.drain_life_id, me, target) then return false end
    if utils.cast_target(runtime.drain_life_id, target) then
        utils.log_debug(menu, "Drain Life (defensive)")
        return true
    end
    return false
end
local function do_rotation(me, target)
    if mana_conservator.on_update(me, target, menu, utils) then return end
    if not is_gcd_ready() then
        return
    end
    
    -- Interrupt (Shadowfury)
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "warlock", utils) then
            return
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

    if try_drain_life_defensive(me, target) then return true end
    if defensive_manager.try_defensive(me, "warlock", utils) then
        return
    end

    -- Threat fade protection — don't pull aggro from tank
    if me:is_in_combat() then
        local current_target = me:get_target()
        local ok, should_fade = pcall(function() return threat_manager.should_fade(me, current_target) end)
        if ok and should_fade then
            pcall(function() threat_manager.try_fade(me) end)
            return
        end
    end
    
    local effective_mode = get_effective_mode()
    if try_immolate(me, target) then
        return
    end
    if try_conflagrate(me, target) then
        return
    end
    if try_shadowfury(me, target) then
        return
    end
    local profile = get_profile()
    if try_nuke(me, target, profile) then
        return
    end
    try_life_tap(me, effective_mode)
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
    if utils.throttle("mode_refresh", 5.0) then
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
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end
        ooc_manager.on_update(me, menu, utils)
    if (menu.auto_mount and menu.auto_mount:get_state()) or (menu.auto_dismount and menu.auto_dismount:get_state()) then
        mount_manager.update_mount_state(me, menu, utils)
    end

    if menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state() then
        consumables_manager.try_use_ooc_food_drink(me, menu, utils)
    end

    if menu.auto_repair and menu.auto_repair:get_state() then
        vendor_automation.try_auto_repair(me, menu, utils)
    end

    if menu.auto_sell_greys and menu.auto_sell_greys:get_state() then
        vendor_automation.try_auto_sell_greys(me, menu, utils)
    end

    if me:is_in_combat() then
        if menu.auto_combat_potions and menu.auto_combat_potions:get_state() then
            consumables_manager.try_use_combat_consumable(me, menu, utils)
        end
        if menu.auto_flask and menu.auto_flask:get_state() then
            consumables_manager.try_maintain_flask(me, menu, utils)
        end
    end

    if eax_utils.is_eating_or_drinking(me) then return end
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    local target = focus_target or utils.find_best_target(me)
    if not target then return end

    if focus_target and focus_target:is_valid() then
        target = focus_target
    end

    do_rotation(me, target)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxwarlockdestruction_space_win")
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
        local label = "EAX Warlock Dest] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxwarlockdestruction_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_wds_cds = menu.use_cooldowns:get_state()
            local nxt_wds_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX WDs] Cooldowns", cur_wds_cds, 0, false, "eax_wds_cds_cp")
            if nxt_wds_cds ~= cur_wds_cds then menu.use_cooldowns:set(nxt_wds_cds) end
        end
        if menu.focus_priority then
            local cur_wds_focus = menu.focus_priority:get_state()
            local nxt_wds_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX WDs] Focus Priority", cur_wds_focus, 0, false, "eax_wds_focus_cp")
            if nxt_wds_focus ~= cur_wds_focus then menu.focus_priority:set(nxt_wds_focus) end
        end
        if menu.use_racial then
            local cur_wds_racial = menu.use_racial:get_state()
            local nxt_wds_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX WDs] Use Racial", cur_wds_racial, 0, false, "eax_wds_racial_cp")
            if nxt_wds_racial ~= cur_wds_racial then menu.use_racial:set(nxt_wds_racial) end
        end
        end
        return elements
    end)
end


-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Warlock"
    local _eax_spec  = "Destruction"
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
core.log("[EAX Warlock Destruction] Loaded " .. (_pi and _pi.plugin_version or "?"))
