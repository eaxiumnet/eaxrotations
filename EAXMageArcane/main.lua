-- Eax Mage Arcane | main.lua

local menu = require("libraries/menu")
local rotation_context = require("libraries/rotation_context")
local resource_gate = require("libraries/resource_gate")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

if not utils.same_unit then
    function utils.same_unit(a, b)
        return a ~= nil and a == b
    end
end
local eax_utils = require("libraries/eax_utils")
local color     = require("libraries/color")

---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("libraries/ooc_manager")
---@type vendor_automation
local vendor_automation = require("libraries/vendor_automation")
---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")
---@type mount_manager
local mount_manager = require("libraries/mount_manager")
---@type leveling_manager
local leveling_manager = require("libraries/leveling_manager")
---@type creature_utils
local creature_utils = require("libraries/creature_utils")

---@type encounter_manager
local encounter_manager = require("libraries/encounter_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil


---@type esp_renderer
local esp_renderer = require("libraries/esp_renderer")
esp_renderer.init("arcane", "Mage Arcane")
-- Smart Cast Manager - addresses spam/sluggishness
local smart_cast_manager = require("libraries/smart_cast_manager")
-- Phase 04 visual telemetry wiring
local dps_meter = require("libraries/dps_meter")
local cooldown_tracker = require("libraries/cooldown_tracker")
local visual_state = require("libraries/visual_state")
local reactive_runtime = require("libraries/reactive_runtime")
local dps_risk = require("libraries/dps_risk")
local dps_runtime = require("libraries/dps_runtime")

-- Hot-path local caching (performance critical)
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cd = core.spell_book.get_spell_cooldown

smart_cast_manager.init({
    core_time = _core_time,
    get_gcd = _get_gcd,
    get_spell_cd = _get_spell_cd,
})

local _visual_ttd_tracker = nil
local _visual_ttd_ok, _visual_ttd_mod = pcall(require, "libraries/ttd_tracker")
if _visual_ttd_ok and _visual_ttd_mod then
    _visual_ttd_tracker = _visual_ttd_mod
end

local _visual_runtime = {
    in_combat = false,
    last_me_hp_pct = nil,
    last_target_hp_pct = nil,
    reactive_state = {},
}

local reactive_adapter = {}

local _visual_on_cast = esp_renderer.on_cast
function esp_renderer.on_cast(spell_id, name, col, target_name)
    if spell_id and core and core.time and core.spell_book and core.spell_book.get_spell_cooldown then
        local now_s = _core_time()
        local cd_s = tonumber(_get_spell_cd(spell_id)) or 0
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

local _visual_tracked_auras = { n = 0 }

local function visual_build_tracked_auras(me, target)
    _visual_tracked_auras.n = 0
    if me and me:is_in_combat() then
        _visual_tracked_auras.n = _visual_tracked_auras.n + 1
        _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Combat", active = true }
    end
    if target and target:is_valid() and not target:is_dead() then
        if target:is_casting_spell() then
            _visual_tracked_auras.n = _visual_tracked_auras.n + 1
            _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Cast", active = true }
        end
        if target:is_channelling_spell() then
            _visual_tracked_auras.n = _visual_tracked_auras.n + 1
            _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Channel", active = true }
        end
    end
    for i = _visual_tracked_auras.n + 1, 4 do
        _visual_tracked_auras[i] = nil
    end
    return _visual_tracked_auras
end

local function visual_update_snapshot(me, target)
    if not me then return end
    local in_combat = me:is_in_combat()
    if in_combat and not _visual_runtime.in_combat then
        dps_meter.on_combat_start()
        _visual_runtime.in_combat = true
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
        smart_cast_manager.clear_all_pending()
    elseif (not in_combat) and _visual_runtime.in_combat then
        dps_meter.on_combat_end()
        _visual_runtime.in_combat = false
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
        smart_cast_manager.reset()
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
        adapter = reactive_adapter,
        encounter_manager = encounter_manager,
        state = _visual_runtime.reactive_state,
        spec = "EAXMageArcane",
    })

    local snapshot = visual_state.build_snapshot({
        now_s = _core_time(),
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
    local me = _get_local_player()
    if not me or me:is_dead() then return end
    local target = me:get_target()
    visual_update_snapshot(me, target)
end)
---@type racial_manager
local racial_manager = require("libraries/racial_manager")
---@type defensive_manager
local defensive_manager = require("libraries/defensive_manager")

---@type mana_conservator
local mana_conservator = require("libraries/mana_conservator")
---@type mana_manager
local mana_manager = require("libraries/mana_manager")
---@type threat_manager
local threat_manager = require("libraries/threat_manager")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

---@type ttd_tracker
local ttd_tracker = require("libraries/ttd_tracker")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

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
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    pending_casts = {},
    set_multiplier = 1.0,
    ooc_counterspell_id = nil,
    ooc_arcane_intellect_id = nil,
}

local ctx_cache = rotation_context.new({
    important_buffs = {
        spells.BUFF_ARCANE_POWER,
        spells.BUFF_CLEARCASTING,
        spells.BUFF_ARCANE_BLAST,
        spells.BUFF_PRESENCE_OF_MIND,
    },
    important_debuffs = {},
})

local GCD_CAST_INTERVAL = 1.5  -- TBC GCD
local PENDING_CAST_TIMEOUT_S = 2.5
local FAST_PENDING_CAST_TIMEOUT_S = 0.75
local function resolve_spells()
    runtime.arcane_intellect_id = utils.resolve_spell_id(spells.ARCANE_INTELLECT)
    runtime.mage_armor_id = utils.resolve_spell_id(spells.MAGE_ARMOR)
    runtime.cone_of_cold_id     = utils.resolve_spell_id(spells.CONE_OF_COLD)
    runtime.arcane_blast_id = utils.resolve_spell_id(spells.ARCANE_BLAST)
    runtime.arcane_missiles_id = utils.resolve_spell_id(spells.ARCANE_MISSILES)
    runtime.arcane_power_id = utils.resolve_spell_id(spells.ARCANE_POWER)
    runtime.arcane_explosion_id = utils.resolve_spell_id(spells.ARCANE_EXPLOSION)
    runtime.evocation_id = utils.resolve_spell_id(spells.EVOCATION)
    runtime.remove_curse_id = utils.resolve_spell_id(spells.REMOVE_CURSE)
    runtime.fire_blast_id = utils.resolve_spell_id(spells.FIRE_BLAST)
    runtime.counterspell_id = utils.resolve_spell_id(spells.COUNTERSPELL)
    runtime.presence_of_mind_id = utils.resolve_spell_id(spells.PRESENCE_OF_MIND)
    runtime.icy_veins_id = utils.resolve_spell_id(spells.ICY_VEINS)
    runtime.cold_snap_id = utils.resolve_spell_id(spells.COLD_SNAP)
    runtime.ooc_arcane_intellect_id = runtime.arcane_intellect_id
end

local function log_resolved_spells()
    core.log("[Eax Mage Arcane] Resolved: AB=" .. tostring(runtime.arcane_blast_id)
        .. " AM=" .. tostring(runtime.arcane_missiles_id)
        .. " AP=" .. tostring(runtime.arcane_power_id)
        .. " AE=" .. tostring(runtime.arcane_explosion_id)
        .. " Evo=" .. tostring(runtime.evocation_id))
end

resolve_spells()
log_resolved_spells()

local function update_set_bonus()
    local me = _get_local_player()
    if not me then return end
    
    local aldor_mult = utils.get_set_multiplier(me, "Aldor")
    local aldor_regalia_mult = utils.get_set_multiplier(me, "AldorRegalia")
    local aldor_nethers_mult = utils.get_set_multiplier(me, "AldorNethers")
    
    runtime.set_multiplier = aldor_mult
    if aldor_regalia_mult > runtime.set_multiplier then
        runtime.set_multiplier = aldor_regalia_mult
    end
    if aldor_nethers_mult > runtime.set_multiplier then
        runtime.set_multiplier = aldor_nethers_mult
    end
    
    if runtime.set_multiplier > 1.0 then
        utils.log_debug(menu, "Set bonus: " .. tostring(runtime.set_multiplier))
    end
end

local function refresh_mode_cache()
    local me = _get_local_player()
    if not me then return end
    runtime.cached_mode = utils.detect_mode(me)
end

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 2 then return "solo" end
    if idx == 3 then return "dungeon" end
    if idx == 4 then return "raid" end
    return runtime.cached_mode
end

local function note_cast()
    runtime.last_cast_time = _core_time()
    rotation_context.invalidate(ctx_cache)
end

local function invalidate_ctx()
    rotation_context.invalidate(ctx_cache)
end

local function is_gcd_ready()
    return smart_cast_manager.is_gcd_ready()
end

local function is_pending_cast(spell_id)
    if not spell_id then return false end
    return smart_cast_manager.is_pending(spell_id)
end

local function mark_pending_cast(spell_id, timeout_s, options)
    if not spell_id then return end
    options = options or {}
    smart_cast_manager.on_cast_attempt(spell_id, options.action_key or "unknown", {
        triggers_gcd = true,
        category = options.category,
        cast_time = options.cast_time,
    })
end

-- Intelligent throttling for specific ability categories
local function should_throttle_dot(action_key)
    return smart_cast_manager.should_throttle(action_key, "dots")
end
local function should_throttle_filler(action_key)
    return smart_cast_manager.should_throttle(action_key, "filler")
end
local function should_throttle_aoe(action_key)
    return smart_cast_manager.should_throttle(action_key, "aoe")
end

local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function get_target_ttd_seconds(target)
    if not target or not ttd_tracker then return nil end
    local ok, value = pcall(function() return ttd_tracker.get(target) end)
    if not ok then return nil end
    return tonumber(value)
end

local function get_spell_cast_time_seconds(spell_id, me)
    if not spell_id or not mana_manager or not mana_manager.get_spell_cast_time_ms then return nil end
    local ok, value = pcall(function() return mana_manager.get_spell_cast_time_ms(spell_id, me) end)
    if not ok then return nil end
    local ms = tonumber(value)
    return ms and ms > 0 and (ms / 1000) or nil
end

local function target_will_die_before_cast_finishes(me, target, spell_id, buffer_s)
    local ttd_s = get_target_ttd_seconds(target)
    local cast_s = get_spell_cast_time_seconds(spell_id, me)
    if not ttd_s or not cast_s then return false end
    return ttd_s <= (cast_s + (buffer_s or 0.25))
end

local function is_within_range(a, b, max_range)
    if not a or not b or not max_range then
        return false
    end

    local ok_a, pos_a = pcall(function() return a:get_position() end)
    local ok_b, pos_b = pcall(function() return b:get_position() end)
    if not ok_a or not ok_b or not pos_a or not pos_b then
        return false
    end

    local dx = pos_a.x - pos_b.x
    local dy = pos_a.y - pos_b.y
    local dz = pos_a.z - pos_b.z
    return (dx * dx + dy * dy + dz * dz) <= (max_range * max_range)
end

local function try_mana_gem(me)
    if not menu.use_mana_gem:get_state() then return false end
    if not me:is_in_combat() then return false end
    if utils.get_mana_pct(me) > menu.mana_gem_pct:get() then return false end

    for i = 1, #spells.MANA_GEM_ITEMS do
        if utils.use_consumable_if_ready(me, spells.MANA_GEM_ITEMS[i]) then
            utils.log_debug(menu, "Mana Gem")
            note_cast()
            return true
        end
    end

    return false
end

local function try_remove_curse(me)
    if not menu.use_remove_curse or not menu.use_remove_curse:get_state() then return false end
    if not runtime.remove_curse_id then
        runtime.remove_curse_id = utils.resolve_spell_id(spells.REMOVE_CURSE)
    end
    if not runtime.remove_curse_id then return false end
    if not me or not me:is_in_combat() then return false end
    if me:is_moving() then return false end
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and not me:can_attack(obj) then
            if utils.has_debuff(obj, spells.REMOVE_CURSE) and utils.can_cast_target(runtime.remove_curse_id, me, obj) then
                if utils.cast_target(runtime.remove_curse_id, obj, "Remove Curse") then return true end
            end
        end
    end
    return false
end

local function try_arcane_explosion(me, target)
    if not menu.use_arcane_explosion or not menu.use_arcane_explosion:get_state() then return false end
    if not runtime.arcane_explosion_id then return false end
    if not me or not me:is_in_combat() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    if me:get_power(0) <= 0 then return false end
    if utils.get_mana_pct(me) < 20 then return false end
    local count = 0
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and me:can_attack(obj) then
            if utils.is_close_to(obj, target, 10) then
                count = count + 1
                if count >= 3 then break end
            end
        end
    end
    if count < 3 then return false end
    if utils.can_cast_hostile(runtime.arcane_explosion_id, me, target) then
        return utils.cast_target_fast(runtime.arcane_explosion_id, target, "Arcane Explosion")
    end
    return false
end

local function try_evocation(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_evocation:get_state() then return false end
    if not runtime.evocation_id then return false end
    if not me:is_in_combat() then return false end
    if me:is_channelling_spell() then return false end
    -- Use mana_manager for proactive Evocation timing
    if not mana_manager.should_evocate(me, "mage", menu) then return false end
    if is_pending_cast(runtime.evocation_id) or utils.is_spell_already_queued(runtime.evocation_id) then return false end
    if not utils.can_cast_self(runtime.evocation_id, me) then return false end

    if utils.cast_self(runtime.evocation_id, me, "Evocation") then
        mark_pending_cast(runtime.evocation_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Evocation")
        note_cast()
                esp_renderer.on_cast(runtime.evocation_id, "Evocation", color.blue(220))
        return true
    end

    return false
end

local function try_arcane_power(me, target)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_arcane_power:get_state() then return false end
    if not runtime.arcane_power_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_ARCANE_POWER) then return false end
    if runtime.icy_veins_id and not utils.has_buff(me, spells.BUFF_ICY_VEINS) and utils.can_cast_self(runtime.icy_veins_id, me) then
        return false
    end

    local min_mana = menu.burn_mana_pct:get()
    if get_effective_mode() == "raid" then
        min_mana = math.max(50, min_mana)
    elseif get_effective_mode() == "solo" then
        min_mana = math.max(35, min_mana - 10)
    end

    if utils.get_mana_pct(me) < min_mana then return false end
    if is_pending_cast(runtime.arcane_power_id) or utils.is_spell_already_queued(runtime.arcane_power_id) then return false end
    if not utils.can_cast_self(runtime.arcane_power_id, me) then return false end

    if utils.cast_self_fast(runtime.arcane_power_id, me, "Arcane Power") then
        mark_pending_cast(runtime.arcane_power_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Arcane Power")
        note_cast()
        return true
    end

    return false
end

local function try_trinkets(me)
    if not menu.use_trinkets:get_state() then return false end
    if not me:is_in_combat() then return false end
    if get_effective_mode() == "solo" and not utils.has_buff(me, spells.BUFF_ARCANE_POWER) then
        return false
    end

    local trinkets = utils.get_self_cast_trinket_ids(me)
    for i = 1, #trinkets do
        if utils.use_item_if_ready(trinkets[i].item_id) then
            utils.log_debug(menu, "Trinket slot " .. tostring(trinkets[i].slot_id))
            note_cast()
            return true
        end
    end

    return false
end

local function try_arcane_missiles(me, target)
    if not menu.use_arcane_missiles:get_state() then return false end
    if not runtime.arcane_missiles_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end

    local ab_stacks = utils.get_buff_stacks(me, spells.BUFF_ARCANE_BLAST)
    local dump_stacks = menu.arcane_blast_dump_stacks:get()
    local clearcasting = utils.has_buff(me, spells.BUFF_CLEARCASTING)
    local low_mana = utils.get_mana_pct(me) <= (menu.evocation_pct:get() + 15)
    if (utils.has_buff(me, spells.BUFF_ICY_VEINS) or utils.has_buff(me, spells.BUFF_ARCANE_POWER)) and not clearcasting and not low_mana and ab_stacks < dump_stacks then
        return false
    end
    if not clearcasting and not low_mana and ab_stacks < dump_stacks then
        return false
    end

    if is_pending_cast(runtime.arcane_missiles_id) or utils.is_spell_already_queued(runtime.arcane_missiles_id) then return false end
    if not utils.can_cast_hostile(runtime.arcane_missiles_id, me, target) then return false end

    if utils.cast_target(runtime.arcane_missiles_id, target, "Arcane Missiles") then
        mark_pending_cast(runtime.arcane_missiles_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Arcane Missiles")
        note_cast()
                esp_renderer.on_cast(runtime.arcane_missiles_id, "Arcane Missiles", color.cyan(220))
        return true
    end

    return false
end

local function try_fire_blast_move(me, target)
    if not menu.use_fire_blast_move:get_state() then return false end
    if not runtime.fire_blast_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_moving() then return false end
    if not utils.can_cast_hostile(runtime.fire_blast_id, me, target) then return false end

    if utils.cast_target_fast(runtime.fire_blast_id, target, "Fire Blast") then
        mark_pending_cast(runtime.fire_blast_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Fire Blast (move)")
        note_cast()
        return true
    end

    return false
end

local function try_arcane_blast(me, target)
    if not menu.use_arcane_blast:get_state() then return false end
    if not runtime.arcane_blast_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end
    if target_will_die_before_cast_finishes(me, target, runtime.arcane_blast_id, 0.35) then return false end
    if is_pending_cast(runtime.arcane_blast_id) or utils.is_spell_already_queued(runtime.arcane_blast_id) then return false end
    if not utils.can_cast_hostile(runtime.arcane_blast_id, me, target) then return false end
    local ab_stacks = utils.get_buff_stacks(me, spells.BUFF_ARCANE_BLAST)
    local ap_active = utils.has_buff(me, spells.BUFF_ARCANE_POWER)
    local iv_active = utils.has_buff(me, spells.BUFF_ICY_VEINS)
    local pom_active = utils.has_buff(me, spells.BUFF_PRESENCE_OF_MIND)
    local clearcasting = utils.has_buff(me, spells.BUFF_CLEARCASTING)
    local low_mana = utils.get_mana_pct(me) <= (menu.evocation_pct:get() + 15)
    local dump_stacks = menu.arcane_blast_dump_stacks:get()
    local should_dump = ab_stacks >= dump_stacks
        or (clearcasting and ab_stacks >= 1)
        or (low_mana and ab_stacks >= math.max(1, dump_stacks - 1))

    if should_dump and not ap_active and not iv_active and not pom_active then
        return false
    end

    if utils.cast_target(runtime.arcane_blast_id, target, "Arcane Blast") then
        mark_pending_cast(runtime.arcane_blast_id, PENDING_CAST_TIMEOUT_S)
        note_cast()
                esp_renderer.on_cast(runtime.arcane_blast_id, "Arcane Blast", color.purple(220))
        return true
    end

    return false
end

local function try_ice_block(me)
    if not menu.use_ice_block:get_state() then return false end
    if not runtime.ice_block_id then
        runtime.ice_block_id = utils.resolve_spell_id(spells.ICE_BLOCK)
    end
    if not runtime.ice_block_id then return false end
    local hp_pct = me:get_health_percentage() / 100
    if hp_pct > (menu.ice_block_hp_pct:get() / 100) then return false end
    if utils.has_buff(me, spells.BUFF_ICE_BLOCK) then return false end
    if not utils.can_cast_self(runtime.ice_block_id, me) then return false end
    if utils.cast_self(runtime.ice_block_id, me) then
        invalidate_ctx()
        utils.log_debug(menu, "Ice Block")
        return true
    end
    return false
end


-- --- Frost Nova - kite tool (v1.4) ---------------------------------------

local function try_frost_nova(me)
    if not menu.use_frost_nova or not menu.use_frost_nova:get_state() then return false end
    if not runtime.frost_nova_id then return false end
    -- Use when a melee enemy is within 8 yards
    local objects = core.object_manager.get_all_objects()
    local melee_attacker = false
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead()
           and me:can_attack(obj) and is_within_range(me, obj, 8) then
            melee_attacker = true
            break
        end
    end
    if not melee_attacker then return false end
    if not utils.can_cast_self(runtime.frost_nova_id, me) then return false end
    if utils.cast_self(runtime.frost_nova_id, me) then
        utils.log_debug(menu, "Frost Nova (kite)")
        return true
    end
    return false
end

-- --- Presence of Mind - instant cast proc (Arcane talent) (v1.4) ---------

local function try_presence_of_mind(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_presence_of_mind or not menu.use_presence_of_mind:get_state() then return false end
    if not runtime.presence_of_mind_id then return false end
    if utils.has_buff(me, spells.BUFF_PRESENCE_OF_MIND) then return false end
    if not me:is_in_combat() then return false end
    if not utils.has_buff(me, spells.BUFF_ARCANE_POWER) then return false end
    if utils.get_buff_remaining_ms(me, spells.BUFF_ARCANE_POWER) > 3000 then return false end
    if not utils.can_cast_self(runtime.presence_of_mind_id, me) then return false end
    if utils.cast_self_fast(runtime.presence_of_mind_id, me) then
        utils.log_debug(menu, "Presence of Mind")
        return true
    end
    return false
end



local function try_arcane_intellect(me)
    if not runtime.arcane_intellect_id then return false end
    if utils.has_buff(me, spells.BUFF_ARCANE_INTELLECT) then return false end
    if not utils.can_cast_self(runtime.arcane_intellect_id, me) then return false end
    if utils.cast_self(runtime.arcane_intellect_id, me) then
        utils.log_debug(menu, "Arcane Intellect")
        return true
    end
    return false
end

local function try_icy_veins(me, target)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_arcane_power:get_state() then return false end
    if not runtime.icy_veins_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_ICY_VEINS) then return false end
    if not utils.can_cast_self(runtime.icy_veins_id, me) then return false end

    if utils.cast_self_fast(runtime.icy_veins_id, me, "Icy Veins") then
        mark_pending_cast(runtime.icy_veins_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Icy Veins")
        note_cast()
        return true
    end

    return false
end

local function try_cold_snap_reset(me)
    if enc and enc.hold_cooldowns then return false end
    if not runtime.cold_snap_id then return false end
    if not me:is_in_combat() then return false end
    if not runtime.icy_veins_id then return false end
    if utils.has_buff(me, spells.BUFF_ICY_VEINS) then return false end
    if _get_spell_cd(runtime.cold_snap_id) > 0 then return false end
    if _get_spell_cd(runtime.icy_veins_id) <= 0 then return false end
    if not utils.can_cast_self(runtime.cold_snap_id, me) then return false end

    if utils.cast_self_fast(runtime.cold_snap_id, me, "Cold Snap") then
        mark_pending_cast(runtime.cold_snap_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Cold Snap")
        note_cast()
        return true
    end

    return false
end

local function try_mage_armor(me)
    if not runtime.mage_armor_id then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, spells.MAGE_ARMOR) then return false end
    if not utils.can_cast_self(runtime.mage_armor_id, me) then return false end
    if utils.cast_self(runtime.mage_armor_id, me) then
        utils.log_debug(menu, "Mage Armor")
        return true
    end
    return false
end

local function try_cone_of_cold(me, target)
    if not menu.use_cone_of_cold or not menu.use_cone_of_cold:get_state() then return false end
    if not runtime.cone_of_cold_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not utils.can_cast_hostile(runtime.cone_of_cold_id, me, target) then return false end
    if utils.cast_target(runtime.cone_of_cold_id, target) then
        utils.log_debug(menu, "Cone of Cold")
        return true
    end
    return false
end

local function try_remove_curse(me)
    if not menu.use_remove_curse or not menu.use_remove_curse:get_state() then return false end
    if not runtime.remove_curse_id then return false end
    if not me or not me:is_in_combat() then return false end
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and not me:can_attack(obj) then
            if utils.has_debuff(obj, spells.REMOVE_CURSE) and utils.can_cast_target(runtime.remove_curse_id, me, obj) then
                if utils.cast_target(runtime.remove_curse_id, obj, "Remove Curse") then return true end
            end
        end
    end
    return false
end

local function try_arcane_explosion(me, target)
    if not menu.use_arcane_explosion or not menu.use_arcane_explosion:get_state() then return false end
    if not runtime.arcane_explosion_id then return false end
    if not me or not me:is_in_combat() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    if utils.get_mana_pct(me) < 20 then return false end
    local count = 0
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and me:can_attack(obj) and is_within_range(me, obj, 10) then
            count = count + 1
            if count >= 3 then break end
        end
    end
    if count < 3 then return false end
    if utils.cast_target_fast(runtime.arcane_explosion_id, target, "Arcane Explosion") then return true end
    return false
end

local function do_rotation(me, target)
    if mana_conservator.on_update(me, target, menu, utils) then return end
    if not is_gcd_ready() then return false end

    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)

    -- Defensive abilities
    -- Interrupt
    if interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "mage", utils) then return true end
    end

    if defensive_manager.try_defensive(me, "mage", utils) then
        return true
    end

    if try_remove_curse(me) then return true end

    -- Threat fade protection - don't pull aggro from tank
    local current_target = me:get_target()
    local ok, should_fade = pcall(function() return threat_manager.should_fade(me, current_target) end)
    if ok and should_fade and dps_risk.should_drop_threat(dps_runtime.build_snapshot(me, current_target, encounter_manager, ttd_tracker)) then
        pcall(function() threat_manager.try_fade(me) end)
        return true
    end

    ttd_tracker.update(target)

    if try_arcane_explosion(me, target) then return true end

    if (me:is_casting_spell() or me:is_channelling_spell()) and dps_risk.should_abort_commit(
        dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker),
        {
            kind = me:is_channelling_spell() and "channel" or "cast",
            progress_pct = 0.20,
            remaining_s = 1.0,
            projected_damage_pct = 0.06,
        }
    ) then
        if SpellStopCasting then
            SpellStopCasting()
            return true
        end
    end



    -- Wanding / mana conservation (leveling 1-70)
    if leveling_manager.try_wand(me, target, menu) then return true end
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Racial CDs
    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense then
        racial_manager.try_offensive(me)
    end
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    -- Mana potion check (before main damage spells)
    if mana_manager.should_use_mana_potion(me, 30) then
        if mana_manager.use_mana_potion() then
            return true
        end
    end

    if try_mana_gem(me) then return true end
    if try_evocation(me) then return true end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and not hold_offense and try_cold_snap_reset(me) then return true end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and not hold_offense and try_presence_of_mind(me) then return true end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.30) and not hold_offense and try_icy_veins(me, target) then return true end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.30) and not hold_offense and try_arcane_power(me, target) then return true end
    if not hold_offense and try_trinkets(me) then return true end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_fire_blast_move(me, target) then return true end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_arcane_blast(me, target) then return true end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and try_arcane_missiles(me, target) then return true end

    return false
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
        utils.log_debug(menu, "Toggle -> " .. tostring(menu.enabled:get_state()))
    end
    runtime.prev_toggle_state = current
end


reactive_adapter = {
    spec = "EAXMageArcane",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "mage", utils)
            end,
        },
        life_save_ally = { noop = "unsupported" },
        interrupt_control = {
            handler = function(_, action_deps)
                local interrupt_target = action_deps.target or action_deps.current_target
                if not interrupt_target or not interrupt_target:is_valid() then
                    return false
                end

                if not interrupt_manager.should_interrupt(interrupt_target) then
                    return false
                end

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "mage", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = {
            handler = function(_, action_deps)
                local snapshot = dps_runtime.build_snapshot(action_deps.me, action_deps.current_target, encounter_manager, ttd_tracker)
                if not dps_risk.should_drop_threat(snapshot) then
                    return false
                end
                local ok, faded = pcall(function()
                    return threat_manager.try_fade(action_deps.me)
                end)
                if not ok then
                    return false
                end
                return faded ~= false
            end,
        },
        throughput_resume = { noop = "unsupported" },
    },
}

local function on_render()
    return
end

-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    on_render()
end)
-- __EAX_ESP_GUARD
core.register_on_update_callback(function()
    local me = _get_local_player()
    if not me then return end
    if me:is_dead() then return end

    if utils.throttle("mode_refresh", 5.0) then
        refresh_mode_cache()
    end
    if utils.throttle("set_bonus", 5.0) then
        update_set_bonus()
    end

    handle_toggle()

    if not menu.enabled:get_state() then return end

    -- OOC management (drink/eat/rez/group buffs)
    ooc_manager.on_update(me, menu, utils, {
        group_buffs = {
            { spell_id = runtime.ooc_arcane_intellect_id,
               buff_ids = spells.BUFF_ARCANE_INTELLECT,
               name = "Arcane Intellect",
               toggle = menu.ooc_group_buff },
        },
    })
    if try_mage_armor(me) then return end
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end
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
    
    -- Self-emergency (Mage has Ice Block)
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.30, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        try_ice_block(me)
    end
    
    do_rotation(me, target)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxmagearcane_space_win")
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
        local label = "Eax Mage Arcane] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxmagearcane_enabled_cp")
        return elements
    end)
end


-- -- Eax Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Mage"
    local _eax_spec  = "Arcane"
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
        local now = _core_time()
        if (now - _conflict_last_warn) < 10 then return end
        _conflict_last_warn = now
        local names = table.concat(enabled_specs, " + ")
        core.log("[Eax WARNING] Multiple " .. _eax_class .. " specs enabled: "
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
core.log("[Eax Mage Arcane] Loaded " .. (_pi and _pi.plugin_version or "?"))
