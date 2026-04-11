-- EAX Paladin Holy - event_handler.lua
-- Event-driven system replacing polling with izi.on_buff_gain/lose callbacks
-- Provides reactive healing based on combat events

local event_handler = {}

-- Hot-path API caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player

---@type izi_sdk
local izi = require("common/izi_sdk")

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

---@type spell_queue
local spell_queue = require("common/modules/spell_queue")

-- ============================================================================
-- EVENT STATE
-- ============================================================================

local event_state = {
    initialized = false,
    last_combat_start = 0,
    last_combat_end = 0,
    pending_heals = {},
    reactive_triggers = {},
    event_log = {},
    max_log_size = 100,
}

-- ============================================================================
-- REACTIVE TRIGGER CONFIGURATION
-- ============================================================================

local REACTIVE_TRIGGERS = {
    -- Low health events
    LOW_HEALTH_SELF = {
        enabled = true,
        threshold = 30,
        priority = 1,
        action = "emergency_self_heal",
    },
    LOW_HEALTH_PARTY = {
        enabled = true,
        threshold = 40,
        priority = 2,
        action = "emergency_heal",
    },
    
    -- Buff events
    BUFF_GAIN_DIVINE_FAVOR = {
        enabled = true,
        buff_id = 20216,
        priority = 3,
        action = "cast_holy_light",
    },
    BUFF_GAIN_DIVINE_ILLUMINATION = {
        enabled = true,
        buff_id = 31842,
        priority = 3,
        action = "cast_holy_light",
    },
    
    -- Debuff events
    DEBUFF_GAIN_MAGIC = {
        enabled = true,
        debuff_type = "magic",
        priority = 4,
        action = "cleanse",
    },
    DEBUFF_GAIN_POISON = {
        enabled = true,
        debuff_type = "poison",
        priority = 4,
        action = "cleanse",
    },
    DEBUFF_GAIN_DISEASE = {
        enabled = true,
        debuff_type = "disease",
        priority = 4,
        action = "cleanse",
    },
    
    -- Combat events
    COMBAT_START = {
        enabled = true,
        priority = 5,
        action = "prepare_combat",
    },
    COMBAT_END = {
        enabled = true,
        priority = 5,
        action = "cleanup_combat",
    },
    
    -- Target change
    TARGET_CHANGE_LOW_HP = {
        enabled = true,
        threshold = 50,
        priority = 2,
        action = "heal_target",
    },
}

-- ============================================================================
-- EVENT LOGGING
-- ============================================================================

local function log_event(event_type, data)
    table.insert(event_state.event_log, 1, {
        type = event_type,
        time = _core_time(),
        data = data,
    })
    
    -- Trim log
    if #event_state.event_log > event_state.max_log_size then
        table.remove(event_state.event_log)
    end
end

-- ============================================================================
-- REACTIVE ACTION HANDLERS
-- ============================================================================

local action_handlers = {}

function action_handlers.emergency_self_heal(data)
    local me = _get_local_player()
    if not me then return end
    
    local ok_hp, hp_pct = pcall(function() return me:get_health_percentage() end)
    if not ok_hp or hp_pct > 30 then return end
    
    -- Queue emergency self-heal
    local utils = require("libraries/utils")
    local spells = require("libraries/spells")
    
    local holy_light_id = utils.resolve_spell_id(spells.HOLY_LIGHT)
    if holy_light_id and utils.can_cast_self(holy_light_id, me) then
        spell_queue:queue_spell_target(holy_light_id, me, 1, "Emergency Self-Heal")
    end
end

function action_handlers.emergency_heal(data)
    if not data or not data.unit then return end
    
    local utils = require("libraries/utils")
    local spells = require("libraries/spells")
    local me = _get_local_player()
    
    if not me then return end
    
    local holy_light_id = utils.resolve_spell_id(spells.HOLY_LIGHT)
    if holy_light_id and utils.can_cast_target(holy_light_id, me, data.unit) then
        spell_queue:queue_spell_target(holy_light_id, data.unit, 1, "Emergency Heal")
    end
end

function action_handlers.cast_holy_light(data)
    local me = _get_local_player()
    if not me then return end
    
    local utils = require("libraries/utils")
    local spells = require("libraries/spells")
    local heal_context = require("libraries/heal_context")
    
    local ctx = heal_context.get_context(me)
    if not ctx or not ctx.lowest_ally then return end
    
    local holy_light_id = utils.resolve_spell_id(spells.HOLY_LIGHT)
    if holy_light_id and utils.can_cast_target(holy_light_id, me, ctx.lowest_ally) then
        spell_queue:queue_spell_target(holy_light_id, ctx.lowest_ally, 2, "Reactive Holy Light")
    end
end

function action_handlers.cleanse(data)
    if not data or not data.unit then return end
    
    local me = _get_local_player()
    if not me then return end
    
    local utils = require("libraries/utils")
    local spells = require("libraries/spells")
    
    local cleanse_id = utils.resolve_spell_id(spells.CLEANSE)
    if cleanse_id and utils.can_cast_target(cleanse_id, me, data.unit) then
        spell_queue:queue_spell_target(cleanse_id, data.unit, 3, "Reactive Cleanse")
    end
end

function action_handlers.prepare_combat(data)
    -- Pre-combat preparation
    local me = _get_local_player()
    if not me then return end
    
    -- Could trigger pre-combat buffs here
    log_event("COMBAT_PREPARE", {time = _core_time()})
end

function action_handlers.cleanup_combat(data)
    -- Post-combat cleanup
    event_state.pending_heals = {}
    log_event("COMBAT_CLEANUP", {time = _core_time()})
end

function action_handlers.heal_target(data)
    if not data or not data.unit then return end
    
    local me = _get_local_player()
    if not me then return end
    
    local utils = require("libraries/utils")
    local spells = require("libraries/spells")
    
    local flash_of_light_id = utils.resolve_spell_id(spells.FLASH_OF_LIGHT)
    if flash_of_light_id and utils.can_cast_target(flash_of_light_id, me, data.unit) then
        spell_queue:queue_spell_target(flash_of_light_id, data.unit, 3, "Target Change Heal")
    end
end

-- ============================================================================
-- EVENT CALLBACKS
-- ============================================================================

local function on_buff_gain(data)
    if not data or not data.unit or not data.buff_id then return end
    
    log_event("BUFF_GAIN", {
        unit = data.unit,
        buff_id = data.buff_id,
        buff_name = data.buff_name,
    })
    
    -- Check for reactive triggers
    for trigger_name, trigger in pairs(REACTIVE_TRIGGERS) do
        if trigger.enabled and trigger.buff_id == data.buff_id then
            local handler = action_handlers[trigger.action]
            if handler then
                handler(data)
            end
        end
    end
end

local function on_buff_lose(data)
    if not data or not data.unit or not data.buff_id then return end
    
    log_event("BUFF_LOSE", {
        unit = data.unit,
        buff_id = data.buff_id,
        buff_name = data.buff_name,
    })
end

local function on_debuff_gain(data)
    if not data or not data.unit or not data.debuff_id then return end
    
    log_event("DEBUFF_GAIN", {
        unit = data.unit,
        debuff_id = data.debuff_id,
        debuff_name = data.debuff_name,
        debuff_type = data.debuff_type,
    })
    
    -- Check for cleanse triggers
    for trigger_name, trigger in pairs(REACTIVE_TRIGGERS) do
        if trigger.enabled and trigger.debuff_type then
            if data.debuff_type and data.debuff_type:lower() == trigger.debuff_type:lower() then
                local handler = action_handlers[trigger.action]
                if handler then
                    handler(data)
                end
            end
        end
    end
end

local function on_debuff_lose(data)
    if not data or not data.unit or not data.debuff_id then return end
    
    log_event("DEBUFF_LOSE", {
        unit = data.unit,
        debuff_id = data.debuff_id,
        debuff_name = data.debuff_name,
    })
end

local function on_combat_start()
    event_state.last_combat_start = _core_time()
    log_event("COMBAT_START", {time = event_state.last_combat_start})
    
    local trigger = REACTIVE_TRIGGERS.COMBAT_START
    if trigger and trigger.enabled then
        local handler = action_handlers[trigger.action]
        if handler then
            handler({})
        end
    end
end

local function on_combat_end()
    event_state.last_combat_end = _core_time()
    log_event("COMBAT_END", {time = event_state.last_combat_end})
    
    local trigger = REACTIVE_TRIGGERS.COMBAT_END
    if trigger and trigger.enabled then
        local handler = action_handlers[trigger.action]
        if handler then
            handler({})
        end
    end
end

local function on_target_changed(data)
    if not data or not data.new_target then return end
    
    log_event("TARGET_CHANGE", {
        old_target = data.old_target,
        new_target = data.new_target,
    })
    
    -- Check if new target needs healing
    local ok_hp, hp_pct = pcall(function() return data.new_target:get_health_percentage() end)
    if ok_hp and hp_pct < 50 then
        local trigger = REACTIVE_TRIGGERS.TARGET_CHANGE_LOW_HP
        if trigger and trigger.enabled then
            local handler = action_handlers[trigger.action]
            if handler then
                handler({unit = data.new_target, hp_pct = hp_pct})
            end
        end
    end
end

local function on_spell_success(data)
    if not data or not data.spell_id then return end
    
    log_event("SPELL_SUCCESS", {
        spell_id = data.spell_id,
        spell_name = data.spell_name,
        target = data.target,
    })
end

-- NOTE: on_spell_fail() removed - izi.on_spell_fail() does not exist in IZI SDK
-- Spell failure tracking is not available. Only spell success events are supported.

-- ============================================================================
-- HEALTH MONITORING (for reactive healing)
-- ============================================================================

local health_monitors = {}

local function update_health_monitors()
    local me = _get_local_player()
    if not me then return end
    
    local heal_context = require("libraries/heal_context")
    local ctx = heal_context.get_context(me)
    if not ctx then return end
    
    -- Monitor self health
    local ok_self_hp, self_hp = pcall(function() return me:get_health_percentage() end)
    if ok_self_hp then
        if self_hp < 30 and (not health_monitors.self_last_hp or health_monitors.self_last_hp >= 30) then
            -- Self health just dropped below threshold
            local trigger = REACTIVE_TRIGGERS.LOW_HEALTH_SELF
            if trigger and trigger.enabled then
                local handler = action_handlers[trigger.action]
                if handler then
                    handler({unit = me, hp_pct = self_hp})
                end
            end
        end
        health_monitors.self_last_hp = self_hp
    end
    
    -- Monitor party health
    if ctx.allies then
        for i = 1, ctx.allies.n do
            local ally = ctx.allies[i]
            if ally and ally:is_valid() then
                local ok_ally_hp, ally_hp = pcall(function() return ally:get_health_percentage() end)
                if ok_ally_hp then
                    local guid = nil
                    local ok_guid, ally_guid = pcall(function() return ally:get_guid() end)
                    if ok_guid and ally_guid then
                        guid = tostring(ally_guid)
                    end
                    
                    if guid then
                        local last_hp = health_monitors[guid] and health_monitors[guid].last_hp
                        if ally_hp < 40 and (not last_hp or last_hp >= 40) then
                            -- Ally health just dropped below threshold
                            local trigger = REACTIVE_TRIGGERS.LOW_HEALTH_PARTY
                            if trigger and trigger.enabled then
                                local handler = action_handlers[trigger.action]
                                if handler then
                                    handler({unit = ally, hp_pct = ally_hp})
                                end
                            end
                        end
                        
                        health_monitors[guid] = {
                            last_hp = ally_hp,
                            last_update = _core_time(),
                        }
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function event_handler.init()
    if event_state.initialized then return end
    
    -- Register IZI SDK event callbacks (with safety checks for API availability)
    local ok_buff_gain = pcall(function() izi.on_buff_gain(on_buff_gain) end)
    local ok_buff_lose = pcall(function() izi.on_buff_lose(on_buff_lose) end)
    local ok_debuff_gain = pcall(function() izi.on_debuff_gain(on_debuff_gain) end)
    local ok_debuff_lose = pcall(function() izi.on_debuff_lose(on_debuff_lose) end)
    
    -- Combat callbacks may not be available in all SDK versions
    local ok_combat_start = pcall(function() izi.on_combat_start(on_combat_start) end)
    local ok_combat_end = pcall(function() izi.on_combat_end(on_combat_end) end)
    
    local ok_target_changed = pcall(function() izi.on_target_changed(on_target_changed) end)
    local ok_spell_success = pcall(function() izi.on_spell_success(on_spell_success) end)
    -- NOTE: izi.on_spell_fail() does not exist in IZI SDK - removed to prevent silent failure
    
    event_state.initialized = true
end

function event_handler.update()
    if not event_state.initialized then return end
    
    -- Update health monitors for reactive triggers
    update_health_monitors()
    
    -- Process any pending heals
    event_handler.process_pending_heals()
end

function event_handler.process_pending_heals()
    -- Process heals queued by event handlers
    for i = #event_state.pending_heals, 1, -1 do
        local heal = event_state.pending_heals[i]
        if heal and heal.time and (_core_time() - heal.time) > 5 then
            -- Remove stale heals
            table.remove(event_state.pending_heals, i)
        end
    end
end

function event_handler.queue_reactive_heal(heal_data)
    table.insert(event_state.pending_heals, {
        time = _core_time(),
        target = heal_data.target,
        spell_id = heal_data.spell_id,
        priority = heal_data.priority or 3,
        reason = heal_data.reason or "reactive",
    })
end

function event_handler.get_pending_heals()
    return event_state.pending_heals
end

function event_handler.clear_pending_heals()
    event_state.pending_heals = {}
end

function event_handler.set_trigger_enabled(trigger_name, enabled)
    if REACTIVE_TRIGGERS[trigger_name] then
        REACTIVE_TRIGGERS[trigger_name].enabled = enabled
    end
end

function event_handler.get_trigger_status(trigger_name)
    if REACTIVE_TRIGGERS[trigger_name] then
        return REACTIVE_TRIGGERS[trigger_name].enabled
    end
    return nil
end

function event_handler.get_all_triggers()
    local triggers = {}
    for name, trigger in pairs(REACTIVE_TRIGGERS) do
        triggers[name] = {
            enabled = trigger.enabled,
            priority = trigger.priority,
            action = trigger.action,
        }
    end
    return triggers
end

function event_handler.get_event_log(max_entries)
    max_entries = max_entries or 20
    local result = {}
    
    for i = 1, math.min(max_entries, #event_state.event_log) do
        table.insert(result, event_state.event_log[i])
    end
    
    return result
end

function event_handler.get_last_combat_time()
    return event_state.last_combat_start, event_state.last_combat_end
end

function event_handler.is_in_combat()
    return event_state.last_combat_start > event_state.last_combat_end
end

function event_handler.get_combat_duration()
    if not event_handler.is_in_combat() then return 0 end
    return _core_time() - event_state.last_combat_start
end

function event_handler.cleanup_old_monitors()
    local now = _core_time()
    
    for guid, data in pairs(health_monitors) do
        if data.last_update and (now - data.last_update) > 30 then
            health_monitors[guid] = nil
        end
    end
end

return event_handler
