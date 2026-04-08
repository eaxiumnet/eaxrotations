-- ooc_manager.lua
-- Out-of-combat utility system for all EAX specs.
-- API-compliant version using buff_manager, spell_queue, and spell_helper

local ooc_manager = {}

-- ============================================================================
-- MODULE REQUIRES (API-Compliant)
-- ============================================================================

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

---@type spell_queue
local spell_queue = require("common/modules/spell_queue")

---@type spell_helper
local spell_helper = require("common/utility/spell_helper")

-- ============================================================================
-- HOT-PATH API CACHING (Module Load)
-- ============================================================================

local _core_time = core.time
local _core_object_manager = core.object_manager
local _core_inventory = core.inventory
local _core_spell_book = core.spell_book

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Throttle intervals
local PARTY_SCAN_INTERVAL_S = 0.5
local BUFF_RECAST_COOLDOWN_S = 2.0
local BUFF_SCAN_SKIP_S = 30.0
local CONSUMABLE_ATTEMPT_INTERVAL_S = 3.0
local REZ_ATTEMPT_INTERVAL_S = 10.0

-- Buff IDs for drink/eat detection
local DRINK_BUFF_IDS = { 430, 2639, 1133, 10250, 22734, 27089, 29007, 46755 }
local EAT_BUFF_IDS = { 433, 787, 1131, 5004, 5005, 7737, 18191, 35270 }

-- Fallback consumable item IDs (TBC era)
local FALLBACK_DRINKS = { 33445, 27860, 22018, 8766, 8428, 4605, 1708, 1205, 1179, 159 }
local FALLBACK_FOODS = { 33052, 27854, 20452, 13928, 4457, 4456, 4455, 422, 4540 }

-- ============================================================================
-- STATE VARIABLES
-- ============================================================================

local last_drink_attempt = 0
local last_eat_attempt = 0
local last_rez_attempt = {}
local last_group_buff = {}
local _pending_drink_until = 0

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

---Check if unit has any of the specified buff IDs
---@param unit game_object
---@param ids number[]
---@return boolean
local function has_any_buff(unit, ids)
    if not unit or not unit:is_valid() or not ids then
        return false
    end
    local data = buff_manager:get_buff_data(unit, ids)
    if data and data.is_active then
        return true
    end
    data = buff_manager:get_aura_data(unit, ids)
    return data ~= nil and data.is_active
end

---Get health percentage safely
---@param me game_object
---@param utils table|nil
---@return number
local function get_health_pct(me, utils)
    if utils and type(utils.get_health_pct) == "function" then
        local ok, value = pcall(utils.get_health_pct, me)
        if ok and type(value) == "number" then
            return value
        end
    end

    if me and type(me.get_health_percentage) == "function" then
        local ok, value = pcall(me.get_health_percentage, me)
        if ok and type(value) == "number" then
            return value / 100.0
        end
    end

    return 1.0
end

---Get mana percentage safely
---@param me game_object
---@return number
local function get_mana_pct(me)
    if not me or not me:is_valid() then
        return 1.0
    end

    local ok_max, max_mana = pcall(function() return me:get_max_power(0) end)
    local ok_cur, cur_mana = pcall(function() return me:get_power(0) end)

    if ok_max and ok_cur and max_mana and max_mana > 0 then
        return cur_mana / max_mana
    end

    return 1.0
end

---Find a consumable item in bags
---@param me game_object
---@param want_drink boolean
---@param want_food boolean
---@return number|nil
local function find_consumable_of_type(me, want_drink, want_food)
    if not _core_inventory then
        return nil
    end

    local wanted = {}
    local list = want_drink and FALLBACK_DRINKS or FALLBACK_FOODS
    for _, id in ipairs(list) do
        wanted[id] = true
    end

    for bag = 0, 4 do
        local ok, items = pcall(function() return _core_inventory.get_items_in_bag(bag) end)
        if ok and items then
            for _, slot in ipairs(items) do
                if slot and slot.object and slot.object:is_valid() then
                    local ok2, id = pcall(function() return slot.object:get_item_id() end)
                    if ok2 and id and id > 0 and wanted[id] then
                        return id
                    end
                end
            end
        end
    end

    return nil
end

---Get resurrection targets (dead party members)
---@param me game_object
---@return game_object[]
local function get_rez_targets(me)
    local targets = {}
    local objects = _core_object_manager.get_all_objects()

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and obj:is_player()
           and obj:is_party_member()
           and not obj:is_ghost() and obj:is_dead()
        then
            table.insert(targets, obj)
        end
    end

    -- Sort by group role (healers/tanks first)
    table.sort(targets, function(a, b)
        local ra = a.get_group_role and a:get_group_role() or 0
        local rb = b.get_group_role and b:get_group_role() or 0
        return ra > rb
    end)

    return targets
end

---Check if spell is learned and castable using spell_helper
---@param spell_id number
---@param caster game_object
---@param target game_object|nil
---@return boolean
local function is_spell_castable(spell_id, caster, target)
    if not spell_id or not caster or not caster:is_valid() then
        return false
    end

    -- Check if spell is learned
    local ok_learned, is_learned = pcall(function()
        return _core_spell_book.is_learned(spell_id)
    end)
    if not ok_learned or not is_learned then
        return false
    end

    -- Use spell_helper for comprehensive check
    if target and target:is_valid() then
        return spell_helper:is_spell_castable(spell_id, caster, target, false, false)
    else
        -- Self-cast check
        return spell_helper:is_spell_castable(spell_id, caster, caster, false, false)
    end
end

---Log debug message safely
---@param utils table|nil
---@param menu table|nil
---@param message string
local function log_debug(utils, menu, message)
    if utils and type(utils.log_debug) == "function" then
        pcall(function() utils.log_debug(menu, message) end)
    end
end

-- ============================================================================
-- PUBLIC FUNCTIONS
-- ============================================================================

---Try to drink when mana is below threshold
---@param me game_object
---@param menu table
---@param utils table|nil
---@return boolean
function ooc_manager.try_drink(me, menu, utils)
    -- Nil-guarded menu access
    local drink_enabled = (menu.ooc_drink and menu.ooc_drink:get_state()) or false
    if not drink_enabled then
        return false
    end

    if me:is_in_combat() then
        return false
    end
    if me:is_moving() then
        return false
    end

    local now = _core_time()
    if now < _pending_drink_until then
        return false
    end

    -- Already has drink or eat buff
    if has_any_buff(me, DRINK_BUFF_IDS) then
        return false
    end
    if has_any_buff(me, EAT_BUFF_IDS) then
        return false
    end

    -- Check mana threshold (nil-guarded)
    local threshold_pct = (menu.drink_threshold and menu.drink_threshold:get()) or 80
    local threshold = threshold_pct / 100.0
    local mana_pct = get_mana_pct(me)

    if mana_pct >= threshold then
        return false
    end

    -- Throttle attempts
    if (now - last_drink_attempt) < CONSUMABLE_ATTEMPT_INTERVAL_S then
        return false
    end
    last_drink_attempt = now

    -- Try to find and use a drink
    local item_id = find_consumable_of_type(me, true, false)
    if item_id then
        -- Use spell_queue for item casting
        spell_queue:queue_item_self(item_id, 1, "OOC: Drinking")
        _pending_drink_until = now + 3.0
        log_debug(utils, menu, "OOC: Drinking")
        return true
    end

    return false
end

---Try to eat when health is below threshold
---@param me game_object
---@param menu table
---@param utils table|nil
---@return boolean
function ooc_manager.try_eat(me, menu, utils)
    -- Nil-guarded menu access
    local eat_enabled = (menu.ooc_eat and menu.ooc_eat:get_state()) or false
    if not eat_enabled then
        return false
    end

    if me:is_in_combat() then
        return false
    end
    if me:is_moving() then
        return false
    end

    local now = _core_time()
    if now < _pending_drink_until then
        return false
    end

    -- Already has eat or drink buff
    if has_any_buff(me, EAT_BUFF_IDS) then
        return false
    end
    if has_any_buff(me, DRINK_BUFF_IDS) then
        return false
    end

    -- Check health threshold (nil-guarded)
    local threshold_pct = (menu.eat_threshold and menu.eat_threshold:get()) or 80
    local threshold = threshold_pct / 100.0
    local hp_pct = get_health_pct(me, utils)

    if hp_pct >= threshold then
        return false
    end

    -- Throttle attempts
    if (now - last_eat_attempt) < CONSUMABLE_ATTEMPT_INTERVAL_S then
        return false
    end
    last_eat_attempt = now

    -- Try to find and use food
    local item_id = find_consumable_of_type(me, false, true)
    if item_id then
        -- Use spell_queue for item casting
        spell_queue:queue_item_self(item_id, 1, "OOC: Eating")
        log_debug(utils, menu, "OOC: Eating")
        return true
    end

    return false
end

---Try to resurrect dead party members
---@param me game_object
---@param rez_spell_id number|nil
---@param menu table
---@param utils table|nil
---@param allow_in_combat boolean|nil
---@return boolean
function ooc_manager.try_resurrect(me, rez_spell_id, menu, utils, allow_in_combat)
    if not rez_spell_id then
        return false
    end

    -- Nil-guarded menu access
    local rez_enabled = (menu.ooc_rez and menu.ooc_rez:get_state()) or false
    if not rez_enabled then
        return false
    end

    if me:is_in_combat() and not allow_in_combat then
        return false
    end
    if me:is_moving() then
        return false
    end

    -- Check if casting
    local ok_cast, is_casting = pcall(function() return me:is_casting_spell() end)
    if ok_cast and is_casting then
        return false
    end

    local targets = get_rez_targets(me)
    local now = _core_time()

    for _, target in ipairs(targets) do
        local guid = tostring(target:get_guid())

        -- Check throttle for this target
        if (now - (last_rez_attempt[guid] or 0)) >= REZ_ATTEMPT_INTERVAL_S then
            -- Check if spell is castable using spell_helper
            if is_spell_castable(rez_spell_id, me, target) then
                -- Queue the resurrection spell
                spell_queue:queue_spell_target(rez_spell_id, target, 1, "OOC: Resurrecting party member")
                last_rez_attempt[guid] = now
                log_debug(utils, menu, "OOC: Resurrecting party member")
                return true
            end
        end
    end

    return false
end

---Try to cast a group buff (self first, then party)
---@param me game_object
---@param spell_id number|nil
---@param buff_ids number[]|nil
---@param buff_name string|nil
---@param menu_toggle table|nil
---@param menu table
---@param utils table|nil
---@return boolean
function ooc_manager.try_group_buff(me, spell_id, buff_ids, buff_name, menu_toggle, menu, utils)
    -- Skip silently if spell not provided
    if not spell_id then
        return false
    end

    -- Nil-guarded menu toggle check
    local toggle_enabled = (menu_toggle and menu_toggle:get_state()) or false
    if not toggle_enabled then
        return false
    end

    if me:is_in_combat() then
        return false
    end

    -- Check if casting or channeling
    local ok_cast, is_casting = pcall(function() return me:is_casting_spell() end)
    if ok_cast and is_casting then
        return false
    end

    local ok_chan, is_chan = pcall(function() return me:is_channelling_spell() end)
    if ok_chan and is_chan then
        return false
    end

    local now = _core_time()

    -- Per-spell party scan throttle
    local scan_key = spell_id .. "_party_scan"
    local last_party_scan = last_group_buff[scan_key] or 0
    local time_since_scan = now - last_party_scan
    local can_scan_party = time_since_scan >= PARTY_SCAN_INTERVAL_S

    -- Skip if recently cast and buff is still active
    local last_cast = last_group_buff[spell_id] or 0
    if last_cast > 0 and (now - last_cast) < BUFF_SCAN_SKIP_S and has_any_buff(me, buff_ids or {}) then
        return false
    end

    -- Check self first (no throttle)
    local has_self_buff = has_any_buff(me, buff_ids or {})

    if not has_self_buff then
        local cooldown_ok = (now - last_cast) >= BUFF_RECAST_COOLDOWN_S

        if cooldown_ok and is_spell_castable(spell_id, me, nil) then
            -- Queue self-buff
            spell_queue:queue_spell_target(spell_id, me, 1, "OOC: Buffing self - " .. (buff_name or ""))
            last_group_buff[spell_id] = now
            log_debug(utils, menu, "OOC: Buffing self - " .. (buff_name or ""))
            return true
        end
    end

    -- Only scan party members if throttle allows
    if not can_scan_party then
        return false
    end
    last_group_buff[scan_key] = now

    -- Check party members
    local objects = _core_object_manager.get_all_objects()

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and obj:is_player()
           and obj:is_party_member() and not obj:is_dead()
        then
            local has_party_buff = has_any_buff(obj, buff_ids or {})

            if not has_party_buff then
                local party_cd_ok = (now - last_cast) >= BUFF_RECAST_COOLDOWN_S

                if party_cd_ok and is_spell_castable(spell_id, me, obj) then
                    -- Queue buff on party member
                    spell_queue:queue_spell_target(spell_id, obj, 1, "OOC: Buffing party - " .. (buff_name or ""))
                    last_group_buff[spell_id] = now
                    log_debug(utils, menu, "OOC: Buffing party - " .. (buff_name or ""))
                    return true
                end
            end
        end
    end

    return false
end

---Main entry point called from spec main.lua
---@param me game_object
---@param menu table
---@param utils table|nil
---@param opts table|nil
function ooc_manager.on_update(me, menu, utils, opts)
    if not me or not me:is_valid() or me:is_dead() then
        return
    end

    opts = opts or {}

    -- Try drink first, then eat
    if not ooc_manager.try_drink(me, menu, utils) then
        ooc_manager.try_eat(me, menu, utils)
    end

    -- Try resurrection if configured
    if opts.rez_spell_id then
        ooc_manager.try_resurrect(me, opts.rez_spell_id, menu, utils, opts.rez_in_combat)
    end

    -- Try group buffs if configured
    if opts.group_buffs then
        for _, buff in ipairs(opts.group_buffs) do
            if ooc_manager.try_group_buff(
                me,
                buff.spell_id,
                buff.buff_ids,
                buff.name,
                buff.toggle,
                menu,
                utils
            ) then
                -- Return after first successful buff to avoid spam
                return
            end
        end
    end
end

return ooc_manager
