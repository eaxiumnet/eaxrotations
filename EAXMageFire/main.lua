-- EAX Mage Fire | main.lua

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")
local color     = require("color")

---@type interrupt_manager
local interrupt_manager = require("eax_shared/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("eax_shared/ooc_manager")
---@type vendor_automation
local vendor_automation = require("eax_shared/vendor_automation")
---@type consumables_manager
local consumables_manager = require("eax_shared/consumables_manager")
---@type mount_manager
local mount_manager = require("eax_shared/mount_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type creature_utils
local creature_utils = require("creature_utils")

---@type encounter_manager
local encounter_manager = require("eax_shared/encounter_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil


---@type esp_renderer
local esp_renderer = require("esp_renderer")

esp_renderer.init("fire", "Mage Fire")


-- Phase 04 visual telemetry wiring
local dps_meter = require("eax_shared/dps_meter")
local cooldown_tracker = require("eax_shared/cooldown_tracker")
local visual_state = require("eax_shared/visual_state")
local reactive_runtime = require("eax_shared/reactive_runtime")
local dps_risk = require("eax_shared/dps_risk")
local dps_runtime = require("eax_shared/dps_runtime")

-- Hot-path local caching (performance critical)
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cd = core.spell_book.get_spell_cooldown

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
        adapter = reactive_adapter,
        encounter_manager = encounter_manager,
        state = _visual_runtime.reactive_state,
        spec = "EAXMageFire",
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
---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("eax_shared/defensive_manager")

---@type mana_conservator
local mana_conservator = require("mana_conservator")
---@type dot_manager
local dot_manager = require("eax_shared/dot_manager")
---@type mana_manager
local mana_manager = require("eax_shared/mana_manager")
---@type threat_manager
local threat_manager = require("eax_shared/threat_manager")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    scorch_id = nil,
    fireball_id = nil,
    pyroblast_id = nil,
    combustion_id = nil,
    evocation_id = nil,
    fire_blast_id = nil,
    ice_block_id = nil,
    flamestrike_id = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    pending_casts = {},
    set_multiplier = 1.0,
    ooc_arcane_intellect_id = nil,
    is_execute = false,
}

local GCD_CAST_INTERVAL = 1.5  -- TBC GCD
local PENDING_CAST_TIMEOUT_S = 2.5
local FAST_PENDING_CAST_TIMEOUT_S = 0.75

local function resolve_spells()
    runtime.molten_armor_id      = utils.resolve_spell_id(spells.MOLTEN_ARMOR)
    runtime.blast_wave_id        = utils.resolve_spell_id(spells.BLAST_WAVE)
    runtime.dragons_breath_id    = utils.resolve_spell_id(spells.DRAGONS_BREATH)
    runtime.arcane_intellect_id  = utils.resolve_spell_id(spells.ARCANE_INTELLECT)
    runtime.scorch_id = utils.resolve_spell_id(spells.SCORCH)
    runtime.fireball_id = utils.resolve_spell_id(spells.FIREBALL)
    runtime.pyroblast_id = utils.resolve_spell_id(spells.PYROBLAST)
    runtime.combustion_id = utils.resolve_spell_id(spells.COMBUSTION)
    runtime.fire_blast_id = utils.resolve_spell_id(spells.FIRE_BLAST)
    runtime.flamestrike_id = utils.resolve_spell_id(spells.FLAMESTRIKE)
    runtime.evocation_id = utils.resolve_spell_id(spells.EVOCATION)
end

local function log_resolved_spells()
    core.log("[EAX Mage Fire] Resolved: Scorch=" .. tostring(runtime.scorch_id)
        .. " Fireball=" .. tostring(runtime.fireball_id)
        .. " Pyro=" .. tostring(runtime.pyroblast_id)
        .. " Comb=" .. tostring(runtime.combustion_id))
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
    runtime.cached_mode = utils.detect_mode(me)
end

local function note_cast()
    runtime.last_cast_time = _core_time()
end

local function is_gcd_ready()
    if (_core_time() - runtime.last_cast_time) < GCD_CAST_INTERVAL then
        return false
    end
    return _get_gcd() <= 0
end

local function is_pending_cast(spell_id)
    if not spell_id then return false end
    local pending = runtime.pending_casts[spell_id]
    if not pending then return false end
    if (_core_time() - pending.requested_at) >= pending.timeout_s then
        runtime.pending_casts[spell_id] = nil
        return false
    end
    return true
end

local function mark_pending_cast(spell_id, timeout_s)
    if not spell_id then return end
    runtime.pending_casts[spell_id] = {
        requested_at = _core_time(),
        timeout_s = timeout_s or PENDING_CAST_TIMEOUT_S,
    }
end

local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function try_combustion(me, target)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_combustion:get_state() then return false end
    if not runtime.combustion_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_COMBUSTION) then return false end
    if is_pending_cast(runtime.combustion_id) or utils.is_spell_already_queued(runtime.combustion_id) then return false end
    if not utils.can_cast_self(runtime.combustion_id, me) then return false end

    if utils.cast_self_fast(runtime.combustion_id, me, "Combustion") then
        mark_pending_cast(runtime.combustion_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Combustion")
        note_cast()
                esp_renderer.on_cast(runtime.combustion_id, "Combustion", color.yellow(220))
        return true
    end

    return false
end

local function try_trinkets(me)
    if not menu.use_trinkets:get_state() then return false end
    if not me:is_in_combat() then return false end
    if not utils.has_buff(me, spells.BUFF_COMBUSTION) and runtime.cached_mode == "solo" then
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

local function try_pyroblast(me, target)
    if not menu.use_pyroblast:get_state() then return false end
    if not runtime.pyroblast_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end

    local hot_streak = utils.has_buff(me, spells.BUFF_HOT_STREAK)
    local combustion_window = utils.has_buff(me, spells.BUFF_COMBUSTION)
    if not hot_streak and not combustion_window then return false end
    if is_pending_cast(runtime.pyroblast_id) or utils.is_spell_already_queued(runtime.pyroblast_id) then return false end
    if not utils.can_cast_hostile(runtime.pyroblast_id, me, target) then return false end

    if utils.cast_target(runtime.pyroblast_id, target, "Pyroblast") then
        mark_pending_cast(runtime.pyroblast_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Pyroblast")
        note_cast()
                esp_renderer.on_cast(runtime.pyroblast_id, "Pyroblast", color.orange(220))
        return true
    end

    return false
end

local function try_scorch(me, target)
    if not menu.use_scorch:get_state() then return false end
    if not runtime.scorch_id then return false end
    if not is_valid_hostile_target(me, target) then return false end

    local stacks = utils.get_debuff_stacks(target, spells.DEBUFF_FIRE_VULNERABILITY)
    local remaining_ms = utils.get_debuff_remaining_ms(target, spells.DEBUFF_FIRE_VULNERABILITY)
    if stacks >= menu.scorch_stack_target:get() and remaining_ms > menu.scorch_refresh_ms:get() then
        return false
    end

    if is_pending_cast(runtime.scorch_id) or utils.is_spell_already_queued(runtime.scorch_id) then return false end
    if not utils.can_cast_hostile(runtime.scorch_id, me, target) then return false end

    if utils.cast_target(runtime.scorch_id, target, "Scorch") then
        mark_pending_cast(runtime.scorch_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Scorch")
        note_cast()
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

local function try_fireball(me, target)
    if not menu.use_fireball:get_state() then return false end
    if not runtime.fireball_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end
    if is_pending_cast(runtime.fireball_id) or utils.is_spell_already_queued(runtime.fireball_id) then return false end
    if not utils.can_cast_hostile(runtime.fireball_id, me, target) then return false end

    if utils.cast_target(runtime.fireball_id, target, "Fireball") then
        mark_pending_cast(runtime.fireball_id, PENDING_CAST_TIMEOUT_S)
        note_cast()
                esp_renderer.on_cast(runtime.fireball_id, "Fireball", color.red(220))
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
           and me:can_attack(obj) and obj:get_distance_to(me) <= 8 then
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
    -- Only pop PoM when Arcane Power is active or as opener
    if runtime.arcane_power_id and not utils.has_buff(me, spells.BUFF_ARCANE_POWER) then return false end
    if not utils.can_cast_self(runtime.presence_of_mind_id, me) then return false end
    if utils.cast_self_fast(runtime.presence_of_mind_id, me) then
        utils.log_debug(menu, "Presence of Mind")
        return true
    end
    return false
end


local function count_enemies_near(me, radius)
    local pos = me:get_position()
    local count = 0
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if is_valid_hostile_target(me, obj) and obj:is_in_combat() then
            local sq = pos:squared_dist_to_ignore_z(obj:get_position())
            local r = radius + (obj:get_bounding_radius() or 0)
            if sq <= r * r then count = count + 1 end
        end
    end
    return count
end

local function try_flamestrike(me, target)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_flamestrike:get_state() then return false end
    if not runtime.flamestrike_id then return false end
    local enemy_count = count_enemies_near(me, spells.FLAMESTRIKE_RADIUS)
    if enemy_count < menu.flamestrike_enemy_count:get() then return false end
    if not utils.can_cast_hostile(runtime.flamestrike_id, me, target) then return false end
    if utils.cast_target(runtime.flamestrike_id, target) then
        esp_renderer.on_cast(runtime.flamestrike_id, "Flamestrike", color.red(220))
        utils.log_debug(menu, "Flamestrike (AoE x" .. tostring(enemy_count) .. ")")
        return true
    end
    return false
end


local function try_molten_armor(me)
    if not runtime.molten_armor_id then return false end
    if utils.has_buff(me, spells.BUFF_MOLTEN_ARMOR) then return false end
    if not utils.can_cast_self(runtime.molten_armor_id, me) then return false end
    if utils.cast_self(runtime.molten_armor_id, me) then
        utils.log_debug(menu, "Molten Armor")
        return true
    end
    return false
end

local function try_blast_wave(me, target)
    if not menu.use_blast_wave or not menu.use_blast_wave:get_state() then return false end
    if not runtime.blast_wave_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not utils.can_cast_hostile(runtime.blast_wave_id, me, target) then return false end
    if utils.cast_target(runtime.blast_wave_id, target) then
        utils.log_debug(menu, "Blast Wave")
        return true
    end
    return false
end

local function try_dragons_breath(me, target)
    if not menu.use_dragons_breath or not menu.use_dragons_breath:get_state() then return false end
    if not runtime.dragons_breath_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not utils.can_cast_hostile(runtime.dragons_breath_id, me, target) then return false end
    if utils.cast_target(runtime.dragons_breath_id, target) then
        utils.log_debug(menu, "Dragon's Breath")
        return true
    end
    return false
end

-- --- Evocation (Fire) ---------------------------------------------------------

local function try_evocation(me)
    if not menu.use_evocation or not menu.use_evocation:get_state() then return false end
    if not runtime.evocation_id then return false end
    if not me:is_in_combat() then return false end
    if me:is_channelling_spell() then return false end
    -- Use mana_manager for proactive Evocation timing
    if not mana_manager.should_evocate(me, "mage", menu) then return false end
    if is_pending_cast(runtime.evocation_id) then return false end
    if not utils.can_cast_self(runtime.evocation_id, me) then return false end
    if utils.cast_self(runtime.evocation_id, me, "Evocation") then
        mark_pending_cast(runtime.evocation_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Evocation")
        return true
    end
    return false
end

local function do_rotation(me, target)
    if mana_conservator.on_update(me, target, menu, utils) then return end
    if not is_gcd_ready() then return false end


    -- Wanding / mana conservation (leveling 1-70)
    if leveling_manager.try_wand(me, target, menu) then return true end
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Execute phase detection for Molten Fury (target <20% HP or boss burn_until_pct)
    local is_execute = false
    if target and target:is_valid() then
        local target_hp = target:get_health_percentage() / 100
        if target_hp <= 0.20 then
            is_execute = true
        elseif enc and enc.burn_until_pct and target_hp <= enc.burn_until_pct then
            is_execute = true
        end
    end
    runtime.is_execute = is_execute
    if is_execute then
        utils.log_debug(menu, "Molten Fury execute phase")
    end

    -- Interrupt
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "mage", utils) then
            return true
        end
    end

    -- Racial CDs
    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense then
        racial_manager.try_offensive(me)
    end
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    -- Threat fade protection — don't pull aggro from tank
    local current_target = me:get_target()
    local ok, should_fade = pcall(function() return threat_manager.should_fade(me, current_target) end)
    if ok and should_fade and dps_risk.should_drop_threat(dps_runtime.build_snapshot(me, current_target, encounter_manager, ttd_tracker)) then
        pcall(function() threat_manager.try_fade(me) end)
        return true
    end

    -- Defensive abilities
    ttd_tracker.update(target)

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

    -- Mana potion check (before main damage spells)
    if mana_manager.should_use_mana_potion(me, 30) then
        if mana_manager.use_mana_potion() then
            return true
        end
    end

    -- Evocation (Fire mage mana recovery)
    if try_evocation(me) then return true end

    if try_molten_armor(me) then return true end
    if try_blast_wave(me, target) then return true end
    if try_dragons_breath(me, target) then return true end
    if not hold_offense and try_combustion(me, target) then return true end
    if not hold_offense and try_trinkets(me) then return true end
    if try_flamestrike(me, target) then return true end
    if try_pyroblast(me, target) then return true end
    if try_scorch(me, target) then return true end
    if try_fire_blast_move(me, target) then return true end
    if try_fireball(me, target) then return true end

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


-- --- Flamestrike - AoE ground fire (v1.8.2) ------------------------------



-- --- Ice Block - emergency freeze (v1.8.2) -------------------------------
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
        utils.log_debug(menu, "Ice Block")
        return true
    end
    return false
end

reactive_adapter = {
    spec = "EAXMageFire",
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

    local me = _get_local_player()
    if not me then return end
    if me:is_dead() then return end
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
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.30, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_ice_block then try_ice_block(me) end
    end
    
    do_rotation(me, target)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxmagefire_space_win")
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
        local label = "EAX Mage Fire] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxmagefire_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_mfi_cds = menu.use_cooldowns:get_state()
            local nxt_mfi_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX MFi] Cooldowns", cur_mfi_cds, 0, false, "eax_mfi_cds_cp")
            if nxt_mfi_cds ~= cur_mfi_cds then menu.use_cooldowns:set(nxt_mfi_cds) end
        end
        if menu.focus_priority then
            local cur_mfi_focus = menu.focus_priority:get_state()
            local nxt_mfi_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX MFi] Focus Priority", cur_mfi_focus, 0, false, "eax_mfi_focus_cp")
            if nxt_mfi_focus ~= cur_mfi_focus then menu.focus_priority:set(nxt_mfi_focus) end
        end
        if menu.use_racial then
            local cur_mfi_racial = menu.use_racial:get_state()
            local nxt_mfi_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX MFi] Use Racial", cur_mfi_racial, 0, false, "eax_mfi_racial_cp")
            if nxt_mfi_racial ~= cur_mfi_racial then menu.use_racial:set(nxt_mfi_racial) end
        end
        end
        return elements
    end)
end


-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Mage"
    local _eax_spec  = "Fire"
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
core.log("[EAX Mage Fire] Loaded " .. (_pi and _pi.plugin_version or "?"))
