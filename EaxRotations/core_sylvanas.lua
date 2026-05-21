-- shared runtime for settings, spell safety, aura helpers, healing scans, and strategy registration.
-- ============================================================================
-- What: EaxRotations core runtime for NS.* helpers, aura data, healing scans, and strategy registration
-- When: Loaded once at plugin startup by main.lua
-- Why: Centralize risky API calls for nil safety and cache hot references for performance
-- Safety: API calls are cached at load, pcall guards are used, and graceful fallbacks avoid crashes
-- ============================================================================
-- ============================================================================
-- What: EaxRotations core runtime — NS.* API boundary, aura helpers, healing scans, strategy registry
-- When: Loaded once at plugin startup by main.lua
-- Why: Centralizes risky API calls for nil safety; caches refs for performance
-- Safety: All API cached at module load; pcall guards; graceful fallbacks; no raw API calls
-- ============================================================================


local _G = _G

local core = _G.core or {}

local NS = _G.EaxRotations or {}

_G.EaxRotations = NS

NS.core = core

NS.runtime_generation = (NS.runtime_generation or 0) + 1



local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring

local format = string.format

local floor = math.floor

local sort = table.sort

local EMPTY = {}

local _buff_db_ok, BUFF_DB = pcall(require, "common/buff_db")

if not _buff_db_ok or type(BUFF_DB) ~= "table" then BUFF_DB = {} end



-- Manual cooldown tracker: records last cast time per spell ID.

-- Used as a final fallback when the engine cooldown APIs return 0

-- (prevents tick-level retry spam for spells whose cooldowns aren't tracked).

local _last_cast_id = nil; local _last_cast_time = 0

local _last_action_exec = {} -- action_name -> timestamp for min_interval gating

local _last_spell_cast = {} -- spell_id -> timestamp for cast/cooldown diagnostics

local _core_trace_times = {}

local _last_gcd_log = 0 -- throttle for spell_ready GCD log spam



-- Spell ID resolver cache: avoids repeated is_spell_learned() calls.

-- Keys are colon-joined rank ID lists; values are { id=resolved_id, ts=timestamp }.

-- TTL is 30s; invalidated on SPELLS_CHANGED-equivalent callbacks.

local _spell_id_cache = {}

local _SPELL_ID_CACHE_TTL = 30



-- One-shot diagnostic log tracker: prevents repeated API dump spam.

-- Keys are spell labels; once logged, won't repeat until next session.

local _api_diag_logged = {}



NS.settings = NS.settings or {}

NS.class_middleware = NS.class_middleware or {}

NS.POWER_MANA, NS.POWER_RAGE, NS.POWER_FOCUS, NS.POWER_ENERGY = 0, 1, 2, 3

NS.CLASS_ID = NS.CLASS_ID or { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }

NS.current_context = NS.current_context or nil

NS._manual_item_cooldowns = NS._manual_item_cooldowns or {}

NS._last_item_use = NS._last_item_use or {}



local _settings_cache = {}

local _settings_cache_last_update = 0

local _SETTINGS_CACHE_TTL = 0.05

local _settings_cache_time



NS.CC_DEBUFFS = NS.CC_DEBUFFS or {

    118, 12824, 12825, 12826, 28271, 28272, -- Polymorph variants

    6770, 2070, 11297, -- Sap

    5782, 6213, 6215, 5484, 17928, -- Fear / Howl of Terror

    1833, 408, 8643, 1776, 2094, -- Rogue stuns/incapacitates

    2637, 18657, 18658, 33786, -- Hibernate / Cyclone

    20066, 19503, 19577, 3355, 14308, 14309, -- Repentance / Hunter control

    8122, 8124, 10888, 10890, -- Psychic Scream

    853, 5588, 5589, 10308, -- Hammer of Justice

}



local PVP_BURST_BUFFS = {

    { 1719 }, -- Recklessness

    { 12042 }, -- Arcane Power

    { 19574 }, -- Bestial Wrath

    { 12472 }, -- Icy Veins

    BUFF_DB.BLOODLUST or { 2825, 32182 },

    BUFF_DB.DRUMS or { 35475, 35474, 35473, 35476 },

    { 13750 }, -- Adrenaline Rush

    { 12292 }, -- Death Wish

}



local PLAYER_DEFENSIVE_BUFFS = {

    { 45438, 27619, 11958 }, -- Ice Block

    { 642, 1020 }, -- Divine Shield

    { 1022, 5599, 10278 }, -- Blessing of Protection

    { 33206 }, -- Pain Suppression

    { 871 }, -- Shield Wall

    { 22812 }, -- Barkskin

}



local MELEE_CLASS_IDS = {

    [NS.CLASS_ID.WARRIOR] = true,

    [NS.CLASS_ID.ROGUE] = true,

    [NS.CLASS_ID.PALADIN] = true,

    [NS.CLASS_ID.SHAMAN] = true,

    [NS.CLASS_ID.DRUID] = true,

}



local MELEE_SIGNAL_BUFFS = {

    { 1719 }, -- Recklessness

    { 13750 }, -- Adrenaline Rush

    { 12292 }, -- Death Wish

    { 12328 }, -- Sweeping Strikes

    { 13877 }, -- Blade Flurry

    { 2983 }, -- Sprint

    { 18499 }, -- Berserker Rage

}



local function safe(fn, ...)

    if type(fn) ~= "function" then return nil end

    local ok, a, b, c = pcall(fn, ...)

    if ok then return a, b, c end

    return nil

end



local function safe_field(obj, key)

    if not obj then return nil end

    local ok, value = pcall(function() return obj[key] end)

    return ok and value or nil

end



function NS.same_unit(a, b)

    if not a or not b then return false end

    local ok, same = pcall(function() return a == b end)

    return ok and same == true or false

end



function NS.not_same_unit(a, b)

    if not a then return false end

    if not b then return true end

    local ok, same = pcall(function() return a == b end)

    return ok and same ~= true or false

end



NS.safe_field = safe_field



local function emit(kind, prefix, msg)

    msg = tostring(msg or "")

    local fn = core and core[kind]

    if type(fn) == "function" then pcall(fn, "[EaxRotations] " .. msg)

    elseif print then print(prefix .. msg) end

end



function NS.log(msg) emit("log", "[EaxRotations] ", msg) end

function NS.log_warning(msg) emit("log_warning", "[EaxRotations WARNING] ", msg) end

function NS.log_error(msg) emit("log_error", "[EaxRotations ERROR] ", msg) end



local function core_trace(key, msg, interval_ms)

    local debug = NS.get_setting and NS.get_setting("debug_system", false) or false

    if not debug then return end

    local now = 0

    if type(core.game_time) == "function" then

        local v = safe(core.game_time)

        if type(v) == "number" then now = v end

    end

    if now == 0 and type(core.time) == "function" then

        local v = safe(core.time)

        if type(v) == "number" then now = v * 1000 end

    end

    local interval = interval_ms or 500

    local last = _core_trace_times[key] or -100000

    if now - last < interval then return end

    _core_trace_times[key] = now

    NS.log("[CASTDBG] " .. tostring(msg))

end



function NS.GetPlayer()

    -- If we have a cached player, check that it's still valid (not garbage-collected)

    if NS.PLAYER_UNIT then

        local ok = pcall(function() return NS.PLAYER_UNIT:is_valid() end)

        if not ok then

            NS.PLAYER_UNIT = nil  -- Stale object, force refresh

        end

    end

    -- Try to get a fresh player from the object manager

    local om = core.object_manager

    if om then

        local ok, fresh = pcall(om.get_local_player, om)

        if ok and fresh then

            local valid = pcall(function() return fresh:is_valid() end)

            if valid then

                NS.PLAYER_UNIT = fresh

                return fresh

            end

        end

    end

    return NS.PLAYER_UNIT  -- Return cached (nil if never set)

end



function NS.GetPet()

    local player = NS.GetPlayer()

    local get_pet = safe_field(player, "get_pet")

    local pet = get_pet and safe(get_pet, player) or nil

    if pet and NS.unit_alive and NS.unit_alive(pet) then return pet end

    return nil

end



NS.get_pet = NS.GetPet



function NS.has_pet()

    return NS.GetPet() ~= nil

end



function NS.get_pet_hp()

    local pet = NS.GetPet()

    return pet and NS.unit_health_pct(pet) or 100

end



NS.EQUIPMENT_SLOTS = NS.EQUIPMENT_SLOTS or {

    HEAD = 1, NECK = 2, SHOULDER = 3, SHIRT = 4, CHEST = 5,

    WAIST = 6, LEGS = 7, FEET = 8, WRIST = 9, HANDS = 10,

    FINGER1 = 11, FINGER2 = 12, TRINKET1 = 13, TRINKET2 = 14,

    BACK = 15, MAIN_HAND = 16, OFF_HAND = 17, RANGED = 18, TABARD = 19,

}



local function item_id_from_slot_info(slot_info)

    if not slot_info then return nil end

    if type(slot_info) == "number" then return slot_info end

    local id = slot_info.item_id or slot_info.entry or slot_info.id

    if type(id) == "number" and id > 0 then return id end

    local object = slot_info.object or slot_info.item or slot_info.game_object

    local get_item_id = safe_field(object, "get_item_id")

    id = get_item_id and safe(get_item_id, object) or nil

    return type(id) == "number" and id > 0 and id or nil

end



function NS.get_equipped_item_id(slot)

    local player = NS.GetPlayer()

    local get_item_at_inventory_slot = safe_field(player, "get_item_at_inventory_slot")

    local slot_info = get_item_at_inventory_slot and safe(get_item_at_inventory_slot, player, slot) or nil

    return item_id_from_slot_info(slot_info)

end



function NS.get_equipped_item_ids(out)

    out = out or {}

    for k in pairs(out) do out[k] = nil end

    local n = 0

    for slot = NS.EQUIPMENT_SLOTS.HEAD, NS.EQUIPMENT_SLOTS.TABARD do

        local id = NS.get_equipped_item_id(slot)

        if id then

            n = n + 1

            out[n] = id

        end

    end

    return out, n

end



function NS.is_item_equipped(item_ids)

    if type(item_ids) == "number" then item_ids = { item_ids } end

    if type(item_ids) ~= "table" then return false end

    for i = 1, #item_ids do

        local wanted = item_ids[i]

        if type(wanted) == "number" then

            for slot = NS.EQUIPMENT_SLOTS.HEAD, NS.EQUIPMENT_SLOTS.TABARD do

                if NS.get_equipped_item_id(slot) == wanted then return true end

            end

        end

    end

    return false

end



function NS.is_item_ready(item_id)

    if type(item_id) ~= "number" or item_id <= 0 then return false end

    local manual_cd = NS._manual_item_cooldowns and NS._manual_item_cooldowns[item_id] or nil

    local last_used = NS._last_item_use and NS._last_item_use[item_id] or nil

    if type(manual_cd) == "number" and type(last_used) == "number" and manual_cd > 0 then

        if (NS.time_now() - last_used) < manual_cd then return false end

    end

    local player = NS.GetPlayer()

    local get_item_cooldown = safe_field(player, "get_item_cooldown")

    if not get_item_cooldown then return true end

    local cooldown = safe(get_item_cooldown, player, item_id)

    return type(cooldown) ~= "number" or cooldown <= 0

end



function NS.register_item_manual_cooldown(item_id, cooldown)

    if type(item_id) ~= "number" or item_id <= 0 then return false end

    NS._manual_item_cooldowns[item_id] = type(cooldown) == "number" and cooldown > 0 and cooldown or 1

    return true

end



function NS.use_item_by_id(item_id, target)

    if type(item_id) ~= "number" or item_id <= 0 then return false end

    if NS.is_item_ready and NS.is_item_ready(item_id) == false then return false end

    local input = core and core.input or nil

    local used = false

    if target and NS.not_same_unit(target, NS.GetPlayer()) and type(input and input.use_item_target) == "function" then

        used = safe(input.use_item_target, item_id, target) == true

    elseif type(input and input.use_item) == "function" then

        used = safe(input.use_item, item_id) == true

    end

    if used then NS._last_item_use[item_id] = NS.time_now() end

    return used

end



NS.use_item = NS.use_item_by_id



function NS.has_item(item_id)

    if type(item_id) ~= "number" or item_id <= 0 then return false end

    local inventory = core and core.inventory or nil

    local get_items_in_bag = inventory and inventory.get_items_in_bag

    if type(get_items_in_bag) ~= "function" then return false end

    for bag_id = 0, 4 do

        local items = safe(get_items_in_bag, bag_id)

        if type(items) == "table" then

            for i = 1, #items do

                if item_id_from_slot_info(items[i]) == item_id then return true end

            end

        end

    end

    return false

end



function NS.count_equipped_set(item_ids)

    if type(item_ids) ~= "table" then return 0 end

    local wanted = {}

    for i = 1, #item_ids do

        if type(item_ids[i]) == "number" then wanted[item_ids[i]] = true end

    end

    local count = 0

    for slot = NS.EQUIPMENT_SLOTS.HEAD, NS.EQUIPMENT_SLOTS.TABARD do

        local id = NS.get_equipped_item_id(slot)

        if id and wanted[id] then count = count + 1 end

    end

    return count

end



function NS.has_set_bonus(item_ids, pieces)

    return NS.count_equipped_set(item_ids) >= (pieces or 2)

end



function NS.GetTarget()

    local player = NS.GetPlayer()

    local get_target = safe_field(player, "get_target")

    local target = get_target and safe(get_target, player) or nil

    if target and NS.unit_alive(target) then return target end



    -- Some Sylvanas builds expose the selected target through the IZI helper

    -- before player:get_target() is populated. Keep this as a guarded fallback

    -- so selected-target openers do not silently stall out of combat.

    local izi = NS.izi

    target = izi and izi.target and safe(izi.target) or nil

    if target and NS.unit_alive(target) then return target end

    target = izi and izi.ts and safe(izi.ts) or nil

    if target and NS.unit_alive(target) then return target end

    return nil

end



function NS.GetFocus()

    local player = NS.GetPlayer()

    if not player then return nil end

    local function valid_focus(unit)

        if not unit or not NS.unit_alive(unit) then return false end

        return safe_field(unit, "is_valid")

            or safe_field(unit, "get_health_percentage")

            or safe_field(unit, "can_attack")

            or safe_field(unit, "is_enemy_with")

            or safe_field(unit, "get_position")

    end

    -- Try core.input.get_focus() first (documented API)

    if core and core.input then

        local get_focus = safe_field(core.input, "get_focus")

        if get_focus then

            local focus = safe(get_focus)

            if valid_focus(focus) then return focus end

        end

    end

    -- Try player method

    local get_focus = safe_field(player, "get_focus")

    local focus = get_focus and safe(get_focus, player) or nil

    if valid_focus(focus) then return focus end

    -- Try object manager

    local object_manager = core and core.object_manager or nil

    local object_focus = object_manager and safe_field(object_manager, "get_focus")

    focus = object_focus and safe(object_focus) or nil

    if valid_focus(focus) then return focus end

    local get_focus_target = object_manager and safe_field(object_manager, "get_focus_target")

    focus = get_focus_target and safe(get_focus_target) or nil

    if valid_focus(focus) then return focus end

    -- Try IZI fallback

    local izi = NS.izi

    focus = izi and izi.focus and safe(izi.focus) or nil

    if valid_focus(focus) then return focus end

    return nil

end



function NS.GetPartyMembers()

    local me = NS.GetPlayer()

    if not me then return EMPTY end

    -- Try core.object_manager.get_party_members

    local object_manager = core and core.object_manager or nil

    local get_party_members = object_manager and safe_field(object_manager, "get_party_members")

    if get_party_members then

        local members = safe(get_party_members)

        if type(members) == "table" then return members end

    end

    -- Try player:get_party_members_in_range

    local get_party_members_in_range = safe_field(me, "get_party_members_in_range")

    if get_party_members_in_range then

        local members = safe(get_party_members_in_range, me, 100, true)

        if type(members) == "table" then return members end

    end

    -- Try visible units scan

    local units, count = NS.get_visible_units()

    local party = { n = 0 }

    for i = 1, count do

        local unit = units[i]

        if NS.not_same_unit(unit, me) then

            local is_party = safe(safe_field(unit, "is_party_member"), unit)

            if is_party then

                party.n = party.n + 1

                party[party.n] = unit

            end

        end

    end

    return party

end



function NS.time_now()

    if type(core.time) == "function" then

        local v = safe(core.time)

        if type(v) == "number" then return v end

    end

    return NS.game_time_ms() / 1000

end



function NS.game_time_ms()

    if type(core.game_time) == "function" then

        local v = safe(core.game_time)

        if type(v) == "number" then return v end

    end

    if type(core.time) == "function" then

        local v = safe(core.time)

        if type(v) == "number" then return floor(v * 1000) end

    end

    return 0

end



_settings_cache_time = NS.time_now



function NS.get_setting_cached(key, default)

    return NS.get_setting(key, default)

end



function NS.register_izi_buff_events()

    return NS.init_izi_buff_events and NS.init_izi_buff_events() or false

end



function NS.get_setting(key, default)

    local now = _settings_cache_time()

    if now - _settings_cache_last_update > _SETTINGS_CACHE_TTL then

        _settings_cache = {}

        for k, v in pairs(NS.settings) do _settings_cache[k] = v end

        _settings_cache_last_update = now

    end

    local value = _settings_cache[key]

    if value == nil then return default end

    return value

end



function NS.set_setting(key, value)

    NS.settings[key] = value

    _settings_cache[key] = value

end



function NS.refresh_settings_cache()

    _settings_cache = {}

    for k, v in pairs(NS.settings) do _settings_cache[k] = v end

    _settings_cache_last_update = _settings_cache_time()

    return true

end



function NS.GetCurrentContext()

    return NS.current_context

end



-- ============================================================================

-- Sticky Spell Anti-Flicker System

-- ============================================================================

local _sticky = { spell_id = nil, spell_name = nil, set_time = 0, min_duration = 0.3, priority = 0 }



function NS.sticky_spell_should_override(spell_id, spell_name, new_priority)

    if not spell_id then return true end

    local now = NS.time_now()

    local min_dur = _sticky.min_duration or 0.3

    new_priority = type(new_priority) == "number" and new_priority or 0

    if _sticky.spell_id == spell_id then

        _sticky.set_time = now

        return true

    end

    if _sticky.spell_id == nil then

        _sticky.spell_id = spell_id

        _sticky.spell_name = spell_name

        _sticky.set_time = now

        _sticky.priority = new_priority

        return true

    end

    local elapsed = now - _sticky.set_time

    if new_priority > (_sticky.priority or 0) then

        _sticky.spell_id = spell_id

        _sticky.spell_name = spell_name

        _sticky.set_time = now

        _sticky.priority = new_priority

        return true

    end

    if elapsed >= min_dur then

        _sticky.spell_id = spell_id

        _sticky.spell_name = spell_name

        _sticky.set_time = now

        _sticky.priority = new_priority

        return true

    end

    return false

end



function NS.sticky_spell_get()

    return _sticky.spell_id, _sticky.spell_name

end



function NS.sticky_spell_reset()

    _sticky.spell_id = nil

    _sticky.spell_name = nil

    _sticky.set_time = 0

    _sticky.priority = 0

end



-- ============================================================================

-- Cooldown Suggestion Registry

-- ============================================================================

NS.cooldown_registry = {}



function NS.register_cooldown(entry)

    if type(entry) ~= "table" or not entry.name then return false end

    entry.priority = type(entry.priority) == "number" and entry.priority or 0

    table.insert(NS.cooldown_registry, entry)

    table.sort(NS.cooldown_registry, function(a, b) return (a.priority or 0) > (b.priority or 0) end)

    return true

end



function NS.unregister_cooldown(name)

    for i = #NS.cooldown_registry, 1, -1 do

        if NS.cooldown_registry[i].name == name then

            table.remove(NS.cooldown_registry, i)

            return true

        end

    end

    return false

end



local _cd_suggestion_buffer = { n = 0 }



function NS.get_cooldown_suggestions(context, category_filter)

    for k in pairs(_cd_suggestion_buffer) do _cd_suggestion_buffer[k] = nil end

    _cd_suggestion_buffer.n = 0

    if type(NS.cooldown_registry) ~= "table" then return _cd_suggestion_buffer end

    for i = 1, #NS.cooldown_registry do

        local entry = NS.cooldown_registry[i]

        if entry and (not category_filter or entry.category == category_filter) then

            local condition_ok = true

            if type(entry.condition) == "function" then

                local ok, result = pcall(entry.condition, context)

                condition_ok = ok and result == true

            end

            if condition_ok then

                local ready = false

                if entry.spell then

                    if type(entry.spell) == "number" then

                        ready = NS.spell_id_is_known(entry.spell) and NS.cooldown_remains(entry.spell) <= 0

                    else

                        ready = NS.spell_ready(entry.spell, (context and context.me) or NS.GetPlayer())

                    end

                elseif entry.item_id then

                    ready = NS.is_item_ready and NS.is_item_ready(entry.item_id) or false

                end

                if ready then

                    _cd_suggestion_buffer.n = _cd_suggestion_buffer.n + 1

                    _cd_suggestion_buffer[_cd_suggestion_buffer.n] = entry

                end

            end

        end

    end

    return _cd_suggestion_buffer

end



function NS.get_best_offensive_cooldown(context)

    local suggestions = NS.get_cooldown_suggestions(context, "offensive")

    return suggestions.n > 0 and suggestions[1] or nil

end



function NS.get_best_defensive_cooldown(context)

    local suggestions = NS.get_cooldown_suggestions(context, "defensive")

    return suggestions.n > 0 and suggestions[1] or nil

end



function NS.clear_cooldown_registry()

    for i = 1, #NS.cooldown_registry do NS.cooldown_registry[i] = nil end

end



function NS.register_on_update_callback(callback)

    local fn = core.register_on_update_callback

    if type(fn) ~= "function" or type(callback) ~= "function" then return false end

    local generation = NS.runtime_generation

    return safe(fn, function(...)

        if generation ~= NS.runtime_generation then return false end

        return callback(...)

    end) ~= false

end



function NS.register_on_spell_cast(callback)

    local fn = core.register_on_spell_cast_callback

    if type(fn) ~= "function" or type(callback) ~= "function" then return false end

    return safe(fn, function(data)

        if type(data) == "table" then

            return callback(data.spell_id, data.target, data)

        end

        return callback(data)

    end) ~= false

end



-- Combat start/end callbacks (manual - no native Sylvanas API)

local combat_start_callbacks = {}

local combat_end_callbacks = {}

local was_in_combat = false



function NS.register_on_combat_start(callback)

    if type(callback) ~= "function" then return false end

    table.insert(combat_start_callbacks, callback)

    return true

end



function NS.register_on_combat_end(callback)

    if type(callback) ~= "function" then return false end

    table.insert(combat_end_callbacks, callback)

    return true

end



-- Internal: fire combat start callbacks

function NS._fire_combat_start(context)

    for _, cb in ipairs(combat_start_callbacks) do

        pcall(cb, context)

    end

end



-- Internal: fire combat end callbacks

function NS._fire_combat_end(context)

    for _, cb in ipairs(combat_end_callbacks) do

        pcall(cb, context)

    end

end



--- Create a spell action object.

-- Accepts two formats:

--   Old: NS.spell_action({id1, id2, ...}, "Name")

--   New: NS.spell_action({ name="Name", ids={...}, levels={...}, cast_time=n, cooldown=n, power_cost=n, power_type="...", school="..." })

-- @param id table|number - Spell IDs (array) or a rich config table

-- @param label string|nil - Spell name (only used in old format)

-- @return table - Spell object with _meta metadata

function NS.spell_action(id, label)

    local spell

    -- Detect rich format: single table arg with an "ids" or "name" key

    if type(id) == "table" and (id.ids or id.name) and not id[1] then

        local cfg = id

        local ids = type(cfg.ids) == "table" and cfg.ids or (cfg.id and { cfg.id } or {})

        local name = cfg.name or tostring(cfg.ids or cfg.id or "")

        spell = {

            _meta = {

                id = cfg.ids or cfg.id,

                ids = ids,

                label = name,

                levels = cfg.levels,

                cast_time = cfg.cast_time or 0,

                cooldown = cfg.cooldown or 0,

                power_cost = cfg.power_cost or 0,

                power_type = cfg.power_type or "mana",

                school = cfg.school or "physical",

            }

        }

    else

        -- Old format

        local ids = type(id) == "table" and id or { id }

        local lbl = label or tostring(id)

        spell = { _meta = { id = id, ids = ids, label = lbl } }

    end



    -- Add methods

    function spell:id()

        if NS.get_spell_id then return NS.get_spell_id(self._meta.id) end

        if type(self._meta.id) == "table" then return self._meta.id[1] end

        return self._meta.id

    end

    function spell:GetSpellPowerCost()

        if self._meta.power_cost and self._meta.power_type then

            return self._meta.power_cost, self._meta.power_type == "mana" and NS.POWER_MANA or 0

        end

        return 0, NS.POWER_MANA

    end

    function spell:GetSpellRank()

        return self._meta.levels and #self._meta.levels or nil

    end

    function spell:GetSpellLevel()

        local levels = self._meta.levels

        if levels and #levels > 0 then return levels[1] end

        return nil

    end

    function spell:IsExists() return NS.is_spell_learned(self) end

    function spell:IsReady(unit) return NS.spell_ready(self, unit or NS.GetTarget()) end

    function spell:IsInRange(unit) return NS.is_spell_in_range(self, unit or NS.GetTarget()) end

    function spell:Cast(unit, reason) return NS.try_cast(self, unit or NS.GetTarget(), reason or self._meta.label) end

    return spell

end



local function collect_ids(spell, out)

    out = out or {}

    if type(spell) == "number" then

        out[#out + 1] = spell

    elseif type(spell) == "table" then

        if spell._meta then collect_ids(spell._meta.id, out)

        elseif type(spell.id) == "function" then

            local id = safe(spell.id, spell)

            if type(id) == "number" then out[#out + 1] = id

            elseif type(id) == "table" then collect_ids(id, out) end

        elseif type(spell.id) == "number" then out[#out + 1] = spell.id

        elseif type(spell.spell_id) == "number" then out[#out + 1] = spell.spell_id end

        for i = 1, #spell do if type(spell[i]) == "number" then out[#out + 1] = spell[i] end end

    end

    return out

end



-- Track API health: if is_spell_learned returns false for many consecutive calls,

-- the spell_book API is likely broken/incompatible. Fall back to trusting IDs.

local _api_health_calls = 0

local _api_health_hits = 0

local _api_health_broken = false

local _api_health_warned = false



local function player_level_fallback()

    local player = NS.GetPlayer and NS.GetPlayer() or nil

    local get_effective_level = safe_field(player, "get_effective_level")

    local level = get_effective_level and safe(get_effective_level, player) or nil

    if type(level) ~= "number" then

        local get_level = safe_field(player, "get_level")

        level = get_level and safe(get_level, player) or nil

    end

    return type(level) == "number" and level or 70

end



local function fallback_spell_id(spell, ids)

    if type(ids) ~= "table" or #ids == 0 then return nil end

    local meta = type(spell) == "table" and spell._meta or nil

    local levels = meta and meta.levels or nil

    if type(levels) == "table" and #levels > 0 then

        local player_level = player_level_fallback()

        for i = 1, #ids do

            local required_level = levels[i]

            if type(required_level) == "number" and player_level >= required_level then

                return ids[i]

            end

        end

    end

    return ids[#ids]

end



local function spell_cache_key(spell, ids)

    local key = table.concat(ids, ":")

    local meta = type(spell) == "table" and spell._meta or nil

    if meta and type(meta.levels) == "table" then

        key = key .. "|levels=" .. table.concat(meta.levels, ":")

    end

    return key

end



local function spell_label(spell, fallback)

    if type(spell) == "table" and spell._meta and spell._meta.label then

        return spell._meta.label

    end

    return tostring(fallback or spell or "?")

end



function NS.spell_id_is_known(spell_id)

    if type(spell_id) ~= "number" then return false end

    -- If API is confirmed broken, skip the expensive call and trust the ID

    if _api_health_broken then return true end

    local sb = core.spell_book

    if not sb then return true end

    local debug = NS.get_setting and NS.get_setting("debug_system", false) or false

    if type(sb.is_spell_learned) == "function" then

        local ok, result = pcall(sb.is_spell_learned, spell_id)

        if not ok then

            if debug then NS.log("[DEBUG] spell_id_is_known(" .. tostring(spell_id) .. ") ERROR: " .. tostring(result)) end

            return false

        end

        _api_health_calls = _api_health_calls + 1

        if result == true then

            _api_health_hits = _api_health_hits + 1

            return true

        end

        -- If we've made 12+ calls with zero successes, the API is broken

        if _api_health_calls >= 12 and _api_health_hits == 0 then

            _api_health_broken = true

            if not _api_health_warned then

                _api_health_warned = true

                NS.log_warning("spell_book.is_spell_learned returned false for ALL " .. tostring(_api_health_calls) .. " calls. Using level-safe rank IDs (API fallback).")

            end

        end

    end

    if type(sb.is_spell_known) == "function" and safe(sb.is_spell_known, spell_id) == true then return true end

    if type(sb.has_spell) == "function" and safe(sb.has_spell, spell_id) == true then return true end

    if debug then NS.log("[DEBUG] spell_id_is_known(" .. tostring(spell_id) .. ")=false") end

    return false

end



function NS.get_spell_id(spell)

    local ids = collect_ids(spell, {})

    if #ids == 0 then return nil end

    -- Build cache key from sorted unique IDs to handle any input shape consistently

    local cache_key = spell_cache_key(spell, ids)

    local cached = _spell_id_cache[cache_key]

    if cached then

        local now = NS.time_now and NS.time_now() or 0

        if now - cached.ts < _SPELL_ID_CACHE_TTL then

            return cached.id

        end

    end

    if core.spell_book then

        if _api_health_broken then

            local fallback_id = fallback_spell_id(spell, ids)

            _spell_id_cache[cache_key] = { id = fallback_id, ts = NS.time_now and NS.time_now() or 0 }

            return fallback_id

        else

            for i = 1, #ids do

                if NS.spell_id_is_known(ids[i]) then

                    _spell_id_cache[cache_key] = { id = ids[i], ts = NS.time_now and NS.time_now() or 0 }

                    return ids[i]

                end

                if _api_health_broken then break end

            end

        end

    end

    local fallback_id = fallback_spell_id(spell, ids)

    _spell_id_cache[cache_key] = { id = fallback_id, ts = NS.time_now and NS.time_now() or 0 }

    return fallback_id

end



function NS.refresh_spell_cache()

    for k in pairs(_spell_id_cache) do _spell_id_cache[k] = nil end

end



-- Batch resolve multiple spell rank arrays at once.

-- `specs` = { { field="bt_id", ranks=spells.BLOODTHIRST }, ... }

-- Writes resolved IDs into `out` table (or new table) using spec.field as keys.

-- Returns `out` for chaining. Unresolved spells are left nil.

function NS._resolve_spell_batch(specs, out)

    out = out or {}

    if type(specs) ~= "table" then return out end

    for i = 1, #specs do

        local spec = specs[i]

        if type(spec) == "table" then

            local field = spec.field

            local ranks = spec.ranks

            if field and type(ranks) == "table" then

                out[field] = NS.get_spell_id(ranks)

            end

        end

    end

    return out

end



-- Batch load a class spell table from a spells.lua module.

-- `class_spells` is the spells table (e.g. `require("libraries/spells")`).

-- `runtime` is the destination table; `keys` is an array of spell keys to resolve.

-- Example: NS._load_class_spells_batch(spells, runtime, {"BLOODTHIRST","WHIRLWIND"})

function NS._load_class_spells_batch(class_spells, runtime, keys)

    if type(class_spells) ~= "table" or type(runtime) ~= "table" or type(keys) ~= "table" then return end

    for i = 1, #keys do

        local key = keys[i]

        local ranks = class_spells[key]

        if type(ranks) == "table" then

            runtime[key:lower() .. "_id"] = NS.get_spell_id(ranks)

        end

    end

end



-- Invalidate spell cache on any spell cast (new spells may have been learned)

if core.register_on_spell_cast_callback then

    pcall(core.register_on_spell_cast_callback, function()

        NS.refresh_spell_cache()

    end)

end



function NS.is_spell_learned(spell)

    local id = NS.get_spell_id(spell)

    if not id then return false end

    return NS.spell_id_is_known(id)

end



function NS.spell_exists(spell)

    if _api_health_broken then return true end

    return NS.is_spell_learned(spell)

end

function NS.CreateSpell(id, opts) return NS.spell_action(id, opts and (opts.label or opts.Desc) or tostring(id)) end



function NS.get_global_cooldown()

    local fn = core.spell_book and core.spell_book.get_global_cooldown

    local v = safe(fn)

    return type(v) == "number" and v or 0

end



function NS.gcd_remains()

    local player = NS.GetPlayer()

    local gcd_remains = safe_field(player, "gcd_remains")

    local remains = gcd_remains and safe(gcd_remains, player) or nil

    return type(remains) == "number" and remains or 0

end



function NS.get_spell_cooldown(spell)

    local id = NS.get_spell_id(spell)

    local fn = core.spell_book and core.spell_book.get_spell_cooldown

    local v = id and safe(fn, id) or nil

    return type(v) == "number" and v or 0

end



local _last_cast_time_cooldown



local _last_cast_time_cooldown = function(id, expected_cooldown)

    if _last_cast_id ~= id then return nil end

    local throttle = expected_cooldown or 1.5

    local elapsed = NS.time_now() - _last_cast_time

    if elapsed < throttle then return throttle - elapsed end

    return nil

end



function NS.cooldown_remains(spell, expected_cooldown)

    local id = type(spell) == "number" and spell or NS.get_spell_id(spell)

    local label = type(spell) == "table" and spell._meta and spell._meta.label or tostring(id)

    local info_fn = core.spell_book and core.spell_book.get_spell_cooldown_information

    local info = id and safe(info_fn, id) or nil

    if type(info) ~= "table" then

        -- `get_spell_cooldown` is a base duration API per Sylvanas .api/docs,

        -- not a remaining-cooldown API. Never treat its positive return value

        -- as an active cooldown here.

        local simple_fn = core.spell_book and core.spell_book.get_spell_cooldown

        local cd = id and safe(simple_fn, id)

        if not _api_diag_logged[label] then

            _api_diag_logged[label] = true

            local info_str = info == nil and "nil" or ("type=" .. type(info))

            local cd_str = cd == nil and "nil" or ("type=" .. type(cd) .. " val=" .. tostring(cd))

            NS.log("[DIAG] " .. label .. " cooldown information unavailable: get_spell_cooldown_information=" .. info_str .. " get_spell_cooldown_duration=" .. cd_str .. " - using manual tracker. spell_id=" .. tostring(id))

        end

        return _last_cast_time_cooldown(id, expected_cooldown) or 0

    end

    if info.enabled == false then return 0 end

    local start_time = tonumber(info.start_time or info.start or 0) or 0

    local duration = tonumber(info.duration or 0) or 0

    if duration <= 0 then

        -- Diagnostic: log table with zero duration

        if not _api_diag_logged[label .. "_dur"] then

            _api_diag_logged[label .. "_dur"] = true

            NS.log("[DIAG] " .. label .. " cooldown table duration=0: start=" .. tostring(start_time) .. " duration=" .. tostring(duration) .. " enabled=" .. tostring(info.enabled) .. " — REPORT TO SYLVANAS DEVS: spell_id=" .. tostring(id))

        end

        return _last_cast_time_cooldown(id, expected_cooldown) or 0

    end



    -- Sylvanas docs describe duration as seconds, while examples use game

    -- time in milliseconds. Support both shapes without permanently blocking

    -- spells whose API reports only a base cooldown duration.

    local now_ms = NS.game_time_ms()

    local now_seconds = NS.time_now()

    local remaining

    if start_time > 1000 then

        local duration_ms = duration > 1000 and duration or duration * 1000

        remaining = (start_time + duration_ms - now_ms) / 1000

    elseif duration > 1000 then

        remaining = ((start_time * 1000) + duration - now_ms) / 1000

    else

        remaining = start_time + duration - now_seconds

    end

    if remaining > 0 then

        return remaining

    end

    return _last_cast_time_cooldown(id, expected_cooldown) or 0

end



-- Manual cast-history cooldown throttle.

-- Uses `expected_cooldown` if known, otherwise falls back to 1.5s minimum.

-- Used as final fallback when engine cooldown APIs return 0.

_last_cast_time_cooldown = function(id, expected_cooldown)

    if _last_cast_id ~= id then return nil end

    local throttle = expected_cooldown or 1.5

    local elapsed = NS.time_now() - _last_cast_time

    if elapsed < throttle then return throttle - elapsed end

    return nil

end



NS.get_spell_cooldown_remaining = NS.cooldown_remains



local function power(unit, power_type)

    local get_power = safe_field(unit, "get_power")

    if get_power then

        local v = safe(get_power, unit, power_type)

        if type(v) == "number" then return v end

    end

    return 0

end



function NS.power_current(power_type) return power(NS.GetPlayer(), power_type) end



local function has_resource(spell)

    local id = NS.get_spell_id(spell)

    local fn = core.spell_book and core.spell_book.get_spell_costs

    local costs = id and safe(fn, id) or nil

    if type(costs) ~= "table" then return true end

    local player = NS.GetPlayer()

    if not player then return false end

    for i = 1, #costs do

        local c = costs[i]

        if c then

            local cost_type = c.cost_type or NS.POWER_MANA

            local cost = c.cost or 0

            if cost <= 0 and (c.cost_percent or 0) > 0 and cost_type == NS.POWER_MANA then

                if NS.mana_pct(player) < c.cost_percent then return false end

            elseif cost > 0 then

                local current = power(player, cost_type)

                if current < cost then

                    -- Some TBC builds expose mana percent but not absolute mana

                    -- through get_power(0). Only bypass when the percentage-based

                    -- cost check confirms sufficient mana.

                    if cost_type == NS.POWER_MANA and current == 0 then

                        local mana = NS.mana_pct(player)

                        if mana > 0 then

                            -- Also enforce cost_percent when available (e.g. spells costing % base mana)

                            local pct = c.cost_percent or 0

                            if pct > 0 and mana < pct then

                                return false

                            end

                        else

                            return false

                        end

                    else

                        return false

                    end

                end

            end

        end

    end

    return true

end



function NS.is_spell_in_range(spell, target)

    if not target then return true end

    local id = NS.get_spell_id(spell)

    local label = spell_label(spell, id)

    local fn = core.spell_book and core.spell_book.is_spell_in_range

    local ok = id and safe(fn, id, target, NS.GetPlayer())

    if ok == true then return true end

    -- API returned false (engine says out-of-range) or nil (API unavailable).

    -- Several Project Sylvanas builds expose this function but return false as

    -- a stub for every spell, so any non-true result must use distance fallback.

    if ok == nil and not _api_diag_logged[label .. "_range_nil"] then

        _api_diag_logged[label .. "_range_nil"] = true

        NS.log("[DIAG] " .. label .. " is_spell_in_range returned nil (API unavailable) — using distance fallback. spell_id=" .. tostring(id))

    end

    if ok == false and not _api_diag_logged[label .. "_range_false"] then

        _api_diag_logged[label .. "_range_false"] = true

        NS.log("[DIAG] " .. label .. " is_spell_in_range returned false — using distance fallback because this API is stubbed on some Sylvanas builds. spell_id=" .. tostring(id))

    end

    if _api_health_broken or ok ~= true then

        if _api_health_broken and ok == false and not _api_diag_logged[label .. "_range_stub"] then

            _api_diag_logged[label .. "_range_stub"] = true

            NS.log("[DIAG] " .. label .. " is_spell_in_range returned false but _api_health_broken=true — distrusting stub. spell_id=" .. tostring(id))

        end

        local me = NS.GetPlayer()

        if not me then return true end  -- can't determine range without player; assume in-range

        local dto = safe_field(target, "distance_to")

        local d = dto and safe(dto, target, me)

        if type(d) ~= "number" then

            local gd = safe_field(target, "get_distance")

            d = gd and safe(gd, target, me)

        end

        if type(d) == "number" and d > 45 then return false end

        return true

    end

    return false

end



NS.spell_in_range = NS.is_spell_in_range



function NS.spell_ready(spell, target, opts)

    opts = opts or EMPTY

    local debug = NS.get_setting and NS.get_setting("debug_system", false) or false

    local label = spell_label(spell)

    if not NS.spell_exists(spell) then

        if debug then core.log("[EaxRotations:spell_ready] " .. label .. " FAIL: spell_exists=false (spell id=" .. tostring(spell) .. ")") end

        core_trace("ready:" .. label .. ":exists", label .. " ready=false reason=spell_exists_false", 700)

        if debug then core_trace("action:" .. tostring(action.name) .. ":spell_exists", "[DEBUG] " .. label .. " blocked: spell_exists=false", 2000) end
        return false

    end

    local gcd = NS.gcd_remains()

    if not opts.skip_gcd and gcd > 0 then

        if (NS.time_now() - _last_gcd_log) > 1 then

            if debug then core.log("[EaxRotations:spell_ready] " .. label .. " FAIL: gcd=" .. tostring(gcd)) end

            _last_gcd_log = NS.time_now()

        end

        core_trace("ready:" .. label .. ":gcd", label .. " ready=false reason=gcd gcd=" .. tostring(gcd), 300)

        if debug then core_trace("action:" .. tostring(action.name) .. ":gcd", "[DEBUG] " .. label .. " blocked: gcd=" .. tostring(gcd), 2000) end
        return false

    end

    local cd = NS.cooldown_remains(spell, opts.expected_cooldown)

    if cd > 0 then

        if debug then core.log("[EaxRotations:spell_ready] " .. label .. " FAIL: cooldown=" .. tostring(cd)) end

        core_trace("ready:" .. label .. ":cd", label .. " ready=false reason=cooldown cd=" .. tostring(cd), 700)

        if debug then core_trace("action:" .. tostring(action.name) .. ":cd", "[DEBUG] " .. label .. " blocked: cd=" .. tostring(cd), 2000) end
        return false

    end

    if not has_resource(spell) then

        if debug then core.log("[EaxRotations:spell_ready] " .. label .. " FAIL: no_resource (mana=" .. tostring(NS.mana_pct and NS.mana_pct(NS.GetPlayer()) or "?") .. ")") end

        core_trace("ready:" .. label .. ":resource", label .. " ready=false reason=no_resource mana=" .. tostring(NS.mana_pct and NS.mana_pct(NS.GetPlayer()) or "?"), 700)

        if debug then core_trace("action:" .. tostring(action.name) .. ":no_resource", "[DEBUG] " .. label .. " blocked: no_resource", 2000) end
        return false

    end

    if not opts.skip_range and target and NS.not_same_unit(target, NS.GetPlayer()) and not NS.is_spell_in_range(spell, target) then

        if debug then core.log("[EaxRotations:spell_ready] " .. label .. " FAIL: out_of_range") end

        core_trace("ready:" .. label .. ":range", label .. " ready=false reason=out_of_range target=" .. tostring(target ~= nil), 700)

        if debug then core_trace("action:" .. tostring(action.name) .. ":out_of_range", "[DEBUG] " .. label .. " blocked: out_of_range", 2000) end
        return false

    end

    core_trace("ready:" .. label .. ":ok", label .. " ready=true target=" .. tostring(target ~= nil) .. " skip_range=" .. tostring(opts.skip_range == true), 700)



    return true

end



local function mark_spell_cast(id)

    _last_cast_id = id

    _last_cast_time = NS.time_now()

    _last_spell_cast[id] = _last_cast_time

end



local function izi_spell_for(id)

    local izi = NS and NS.izi or nil

    local spell_factory = izi and izi.spell

    if type(spell_factory) ~= "function" then return nil end

    local ok, spell_obj = pcall(spell_factory, id)

    if ok then return spell_obj end

    return nil

end



local function cast_unit_spell(id, target, label, reason)

    local izi_spell = izi_spell_for(id)

    if izi_spell and type(izi_spell.cast_safe) == "function" then

        local ok, result = pcall(function()

            return izi_spell:cast_safe(target, reason or label)

        end)

        if ok and result ~= false and result ~= nil then

            core_trace("try:" .. tostring(id) .. ":izi_ok", "try_cast " .. tostring(label) .. " izi cast_safe ok id=" .. tostring(id) .. " result=" .. tostring(result), 300)

            return true

        end

        core_trace("try:" .. tostring(id) .. ":izi_false", "try_cast " .. tostring(label) .. " izi cast_safe failed ok=" .. tostring(ok) .. " result=" .. tostring(result), 300)

    end



    local cast = core.input and core.input.cast_target_spell

    if type(cast) ~= "function" then

        core_trace("try:" .. tostring(id) .. ":cast_missing", "try_cast " .. tostring(label) .. " failed: no IZI cast and core.input.cast_target_spell missing", 700)

        return false

    end

    local result = safe(cast, id, target)

    if result == false then

        core_trace("try:" .. tostring(id) .. ":cast_false", "try_cast " .. tostring(label) .. " failed: core cast_target_spell returned false id=" .. tostring(id), 300)

        return false

    end

    core_trace("try:" .. tostring(id) .. ":core_ok", "try_cast " .. tostring(label) .. " core cast_target_spell called id=" .. tostring(id) .. " result=" .. tostring(result), 300)

    return true

end



local function cast_position_spell(id, position, label, reason)

    local izi_spell = izi_spell_for(id)

    if izi_spell and type(izi_spell.cast_safe) == "function" then

        local ok, result = pcall(function()

            return izi_spell:cast_safe(position, reason or label)

        end)

        if ok and result ~= false and result ~= nil then

            core_trace("pos:" .. tostring(id) .. ":izi_ok", "try_cast_position " .. tostring(label) .. " izi cast_safe ok id=" .. tostring(id) .. " result=" .. tostring(result), 300)

            return true

        end

        core_trace("pos:" .. tostring(id) .. ":izi_false", "try_cast_position " .. tostring(label) .. " izi cast_safe failed ok=" .. tostring(ok) .. " result=" .. tostring(result), 300)

    end



    local cast = core.input and core.input.cast_position_spell

    if type(cast) ~= "function" then

        core_trace("pos:" .. tostring(id) .. ":cast_missing", "try_cast_position " .. tostring(label) .. " failed: no IZI cast and core.input.cast_position_spell missing", 700)

        return false

    end

    local result = safe(cast, id, position)

    if result == false then

        core_trace("pos:" .. tostring(id) .. ":cast_false", "try_cast_position " .. tostring(label) .. " failed: core cast_position_spell returned false", 300)

        return false

    end

    core_trace("pos:" .. tostring(id) .. ":core_ok", "try_cast_position " .. tostring(label) .. " core cast_position_spell called id=" .. tostring(id) .. " result=" .. tostring(result), 300)

    return true

end
-- ============================================================================
-- Central Cast Guard -- consolidate all pre-cast checks
-- ============================================================================

--- Validates that a spell can be cast by running ALL pre-cast guards.
--- Returns true if all checks pass.
--- Replaces inline anti-flicker, min_interval, and reagent checks scattered
--- across try_cast / action_execute / spell_ready.
---@param spell number|table The spell ID or izi spell object.
---@param unit game_object|nil The target unit.
---@param reason string|nil Human-readable reason for logging.
---@param opts table|nil Options table (skip_range, skip_gcd, expected_cooldown, min_interval).
---@return boolean ok True if all guards pass.
function NS.evaluate_cast(spell, unit, reason, opts)
    opts = opts or EMPTY
    local id = NS.get_spell_id(spell)
    if not id then
        core_trace("eval:nil_id", "evaluate_cast failed: no spell id", 700)
        return false
    end
    local label = spell_label(spell, id)
    local debug = NS.get_setting and NS.get_setting("debug_system", false) or false
    local target = unit or NS.GetPlayer()

    -- 1. Standard spell readiness (exists + GCD + cooldown + resource + range)
    if not NS.spell_ready(spell, target, opts) then
        core_trace("eval:" .. tostring(id) .. ":not_ready", "evaluate_cast " .. label .. " blocked: spell_ready=false", 300)
        if debug then
            core_trace("eval:" .. tostring(id) .. ":failed_ready", "[EaxRotations:evaluate_cast] " .. label .. " blocked: spell_ready=false", 2000)
        end
        return false
    end

    -- 2. Anti-flicker: skip if same spell was cast within 0.3s
    if _last_cast_id == id then
        local elapsed = NS.time_now() - _last_cast_time
        if elapsed < 0.3 then
            core_trace("eval:" .. tostring(id) .. ":sticky", "evaluate_cast " .. label .. " blocked: anti_flicker elapsed=" .. tostring(elapsed), 200)
            return false
        end
    end

    -- 3. Min interval check
    local min_interval = opts.min_interval
    if type(min_interval) == "number" and min_interval > 0 then
        local last_cast = _last_spell_cast[id]
        local elapsed = last_cast and (NS.time_now() - last_cast) or nil
        if elapsed and elapsed < min_interval then
            core_trace("eval:" .. tostring(id) .. ":min_interval", "evaluate_cast " .. label .. " blocked: min_interval=" .. tostring(min_interval) .. " elapsed=" .. tostring(elapsed), 500)
            return false
        end
    end

    -- 4. Reagent guard
    -- Lazily loaded on demand; no hard-dependency on the module.
    local reagent_ok, reagent_guard = pcall(require, "shared/reagent_guard_sylvanas")
    if reagent_ok and reagent_guard and reagent_guard.check_reagent then
        if not reagent_guard.check_reagent(id) then
            if debug then
                core.log("[EaxRotations:evaluate_cast] " .. label .. " blocked: missing reagent (spell_id=" .. tostring(id) .. ")")
            end
            core_trace("eval:" .. tostring(id) .. ":reagent", "evaluate_cast " .. label .. " blocked: missing reagent", 500)
            return false
        end
    end

    return true
end




function NS.try_cast(spell, unit, reason, opts)

    opts = opts or EMPTY

    local id = NS.get_spell_id(spell)

    local label = spell_label(spell, id)

    local target = unit

    if not target then

        target = NS.GetPlayer()

        if not target then

            core_trace("try:" .. label .. ":no_target", "try_cast " .. label .. " failed: no target/player id=" .. tostring(id) .. " reason=" .. tostring(reason), 700)

            return false

        end

    end

    local debug = NS.get_setting and NS.get_setting("debug_system", false) or false

    if not id then

        core_trace("try:nil_id", "try_cast failed: no spell id label=" .. tostring(label) .. " reason=" .. tostring(reason), 700)

        return false

    end

    core_trace("try:" .. tostring(id) .. ":enter", "try_cast enter id=" .. tostring(id) .. " label=" .. tostring(label) .. " target=" .. tostring(target ~= nil) .. " reason=" .. tostring(reason), 300)

    if debug then core_trace("try:" .. tostring(id) .. ":attempt", "[EaxRotations:try_cast] ATTEMPT id=" .. tostring(id) .. " label=" .. label .. " has_target=" .. tostring(target ~= nil), 2000) end

    -- Central cast guard: runs spell_ready, anti-flicker, min_interval, reagent

    if not NS.evaluate_cast(spell, unit, reason, opts) then

        return false

    end

    NS.sticky_spell_should_override(id, reason or "unknown", 0)

    -- Select cast backend: auto (IZI->core fallthrough), direct (core only), queue (spell_queue module)

    local cast_backend = NS.get_setting("cast_backend", "auto")

    -- Backward compat: old use_spell_queue=true maps to queue

    if cast_backend == "auto" and NS.get_setting("use_spell_queue", false) then

        cast_backend = "queue"

    end

    if cast_backend == "queue" then

        local queue_ok, spell_queue = pcall(require, "common/modules/spell_queue")

        if queue_ok and spell_queue and type(spell_queue.queue_spell_target) == "function" then

            local queued = spell_queue:queue_spell_target(id, target, 1, label, false)

            if queued == false then

                core_trace("try:" .. tostring(id) .. ":queue_false", "try_cast " .. tostring(label) .. " failed: queue_spell_target returned false", 300)

                return false

            end

            mark_spell_cast(id)

            core_trace("try:" .. tostring(id) .. ":queued", "try_cast " .. tostring(label) .. " queued id=" .. tostring(id) .. " result=" .. tostring(queued), 300)

            if reason and debug then NS.log(reason) end

            if debug then core_trace("try:" .. tostring(id) .. ":queued_ok", "[EaxRotations:try_cast] SUCCESS (queued) id=" .. tostring(id) .. " label=" .. label, 2000) end

            return true

        else

            core_trace("try:" .. tostring(id) .. ":queue_missing", "try_cast " .. tostring(label) .. " cast_backend=queue but spell_queue unavailable; falling back auto", 700)

        end

    elseif cast_backend == "direct" then

        local cast = core.input and core.input.cast_target_spell

        if type(cast) ~= "function" then

            core_trace("try:" .. tostring(id) .. ":direct_missing", "try_cast " .. tostring(label) .. " cast_backend=direct but core.input.cast_target_spell missing", 700)

            return false

        end

        local result = safe(cast, id, target)

        if result == false then

            core_trace("try:" .. tostring(id) .. ":direct_false", "try_cast " .. tostring(label) .. " cast_backend=direct cast_target_spell returned false", 300)

            return false

        end

        mark_spell_cast(id)

        core_trace("try:" .. tostring(id) .. ":direct_ok", "try_cast " .. tostring(label) .. " direct cast called id=" .. tostring(id) .. " result=" .. tostring(result), 300)

        if reason and debug then NS.log(reason) end

        if debug then core_trace("try:" .. tostring(id) .. ":direct_ok", "[EaxRotations:try_cast] SUCCESS (direct) id=" .. tostring(id) .. " label=" .. label, 2000) end

        return true

    end

    if not cast_unit_spell(id, target, label, reason) then

        if debug then core_trace("try:" .. tostring(id) .. ":failed_cast", "[EaxRotations:try_cast] FAILED: cast_unit_spell returned false id=" .. tostring(id) .. " label=" .. label, 2000) end

        return false

    end

    -- Record cast time for manual cooldown fallback

    mark_spell_cast(id)

    if reason and debug then NS.log(reason) end

    if debug then core_trace("try:" .. tostring(id) .. ":direct_ok", "[EaxRotations:try_cast] SUCCESS (direct) id=" .. tostring(id) .. " label=" .. label, 2000) end

    return true

end



function NS.try_cast_position(spell, position, range_target, reason, opts)

    opts = opts or EMPTY

    local id = NS.get_spell_id(spell)

    local label = spell_label(spell, id)

    if not id or not position then

        core_trace("pos:" .. tostring(label) .. ":bad_input", "try_cast_position failed: id=" .. tostring(id) .. " position=" .. tostring(position ~= nil), 700)

        return false

    end

    if not NS.spell_ready(spell, range_target, opts) then

        core_trace("pos:" .. tostring(id) .. ":not_ready", "try_cast_position " .. tostring(label) .. " failed: spell_ready=false id=" .. tostring(id), 300)

        return false

    end

    if not cast_position_spell(id, position, label, reason) then return false end

    mark_spell_cast(id)

    local debug = NS.get_setting and NS.get_setting("debug_system", false) or false

    if reason and debug then NS.log(reason) end

    return true

end



NS.cast_position = NS.try_cast_position



function NS.cancel_spells()

    local fn = core.input and core.input.cancel_spells

    if type(fn) ~= "function" then return false end

    return safe(fn) ~= false

end



function NS.cancel_buff(buff_otr)

    local fn = core.input and core.input.cancel_buff

    if type(fn) ~= "function" then return false end

    return safe(fn, buff_otr) ~= false

end



function NS.get_totem_info(slot)

    local player = NS.GetPlayer()

    if player then

        local get_totem_info = safe_field(player, "get_totem_info")

        if get_totem_info then

            local ok, have, name, start_time, duration, spell_id = pcall(get_totem_info, player, slot)

            if ok then

                return {

                    have_totem = have == true,

                    totem_name = name,

                    start_time = start_time,

                    duration = duration,

                    spell_id = spell_id,

                }

            end

        end

    end



    local fn = core.spell_book and core.spell_book.get_totem_info

    if type(fn) ~= "function" then return nil end

    local info = safe(fn, slot)

    if type(info) == "table" then return info end

    return nil

end



local function unit_alive_inner(unit)

    if not unit then return false end

    local is_valid = safe_field(unit, "is_valid")

    if is_valid and safe(is_valid, unit) == false then return false end

    local is_alive = safe_field(unit, "is_alive")

    if is_alive and safe(is_alive, unit) == false then return false end

    local is_dead = safe_field(unit, "is_dead")

    if is_dead and safe(is_dead, unit) then return false end

    local is_ghost = safe_field(unit, "is_ghost")

    if is_ghost and safe(is_ghost, unit) then return false end

    return true

end



function NS.unit_alive(unit)

    local ok, alive = pcall(unit_alive_inner, unit)

    return ok and alive == true or false

end



function NS.unit_health_pct(unit)

    if not unit then return 100 end

    local get_health_percentage = safe_field(unit, "get_health_percentage")

    if get_health_percentage then

        local v = safe(get_health_percentage, unit)

        if type(v) == "number" then return v end

    end

    local get_health = safe_field(unit, "get_health")

    local get_max_health = safe_field(unit, "get_max_health")

    local hp = get_health and safe(get_health, unit) or 0

    local max_hp = get_max_health and safe(get_max_health, unit) or hp

    if type(max_hp) == "number" and max_hp > 0 then return (hp / max_hp) * 100 end

    return 100

end



function NS.mana_pct(unit)

    unit = unit or NS.GetPlayer()

    local get_mana_percentage = safe_field(unit, "get_mana_percentage")

    if get_mana_percentage then

        local v = safe(get_mana_percentage, unit)

        if type(v) == "number" then return v end

    end

    local get_max_power = safe_field(unit, "get_max_power")

    local max = get_max_power and safe(get_max_power, unit, NS.POWER_MANA) or 0

    if max and max > 0 then return (power(unit, NS.POWER_MANA) / max) * 100 end

    return 100

end



local function aura_data(unit, ids, kind)

    if not unit then return nil end

    local list = collect_ids(ids, {})

    for i = 1, #list do

        local id = list[i]

        local data = kind == "buff"

            and safe(safe_field(unit, "get_buff_data"), unit, id)

            or safe(safe_field(unit, "get_debuff_data"), unit, id)

        -- Project Sylvanas buff_manager returns a table even for missed

        -- lookups on some builds. The documented `is_active` field is the

        -- source of truth when present; nil means an IZI object-extension

        -- lookup returned only active aura data.

        if data and data.is_active ~= false then return data end

    end

    return nil

end



local function aura_remaining_seconds(data)

    if not data then return 0 end



    -- The local .api and buffs.md document buff_manager.remaining and

    -- expire_time in milliseconds. Convert that fallback to the seconds

    -- contract used by IZI `buff_remains`/`debuff_remains` and rotations.

    local expire_time = tonumber(data.expire_time)

    if expire_time and expire_time > 0 then

        return math.max(0, (expire_time - NS.game_time_ms()) / 1000)

    end



    local remaining = tonumber(data.remaining or data.remains or 0) or 0

    return remaining > 0 and (remaining / 1000) or 0

end



function NS.buff_up(unit, ids)

    if not unit then return false end

    local list = collect_ids(ids, {})

    for i = 1, #list do

        local id = list[i]

        if safe(safe_field(unit, "has_buff"), unit, id) or safe(safe_field(unit, "buff_up"), unit, id) then return true end

    end

    local aura = aura_data(unit, ids, "buff")

    if aura == nil then

        local debug = NS.get_setting and NS.get_setting("debug_system", false) or false

        if debug and #list > 0 then

            local id_str = table.concat(list, ",")

            core_trace("diag:buff_up:" .. id_str, "[DIAG] buff_up(" .. id_str .. ") all checks failed: has_buff=false, buff_up=false, aura_data=nil", 2000)

        end

    end

    return aura ~= nil

end



local _izi_dirty_buffs = {}

local _izi_dirty_debuffs = {}

local _izi_buff_events_registered = false



local function aura_event_unit_id(a, b, c)

    if type(a) == "table" and (a.spell_id or a.buff_id or a.id or a.unit or a.target) then

        return a.unit or a.target or a.caster, a.spell_id or a.buff_id or a.debuff_id or a.id

    end

    if type(b) == "number" then return a, b end

    if type(c) == "number" then return b or a, c end

    return a, nil

end



local function mark_dirty_aura(store, active, a, b, c)

    local unit, id = aura_event_unit_id(a, b, c)

    if not unit or type(id) ~= "number" then return end

    local key = tostring(unit)

    local unit_store = store[key]

    if not unit_store then

        unit_store = {}

        store[key] = unit_store

    end

    unit_store[id] = active == true

end



local function dirty_aura_state(store, unit, ids)

    if not unit then return nil end

    local unit_store = store[tostring(unit)]

    if not unit_store then return nil end

    local list = collect_ids(ids, {})

    for i = 1, #list do

        local state = unit_store[list[i]]

        if state ~= nil then return state end

    end

    return nil

end



function NS.init_izi_buff_events()

    if _izi_buff_events_registered then return true end

    local izi = NS.izi

    if not izi then

        local ok, module = pcall(require, "common/izi_sdk")

        if ok then izi = module end

    end

    if type(izi) ~= "table" then return false end

    local ok = true

    if type(izi.on_buff_gain) == "function" then

        ok = pcall(izi.on_buff_gain, function(a, b, c) mark_dirty_aura(_izi_dirty_buffs, true, a, b, c) end) and ok

    end

    if type(izi.on_buff_lose) == "function" then

        ok = pcall(izi.on_buff_lose, function(a, b, c) mark_dirty_aura(_izi_dirty_buffs, false, a, b, c) end) and ok

    end

    if type(izi.on_debuff_gain) == "function" then

        ok = pcall(izi.on_debuff_gain, function(a, b, c) mark_dirty_aura(_izi_dirty_debuffs, true, a, b, c) end) and ok

    end

    if type(izi.on_debuff_lose) == "function" then

        ok = pcall(izi.on_debuff_lose, function(a, b, c) mark_dirty_aura(_izi_dirty_debuffs, false, a, b, c) end) and ok

    end

    _izi_buff_events_registered = ok

    return ok

end



function NS.buff_up_fast(unit, ids)

    local state = dirty_aura_state(_izi_dirty_buffs, unit, ids)

    if state ~= nil then return state == true end

    return NS.buff_up(unit, ids)

end



function NS.debuff_up_fast(unit, ids)

    local state = dirty_aura_state(_izi_dirty_debuffs, unit, ids)

    if state ~= nil then return state == true end

    return NS.debuff_up(unit, ids)

end



function NS.buff_remains_fast(unit, ids)

    local state = dirty_aura_state(_izi_dirty_buffs, unit, ids)

    if state == false then return 0 end

    return NS.buff_remains(unit, ids)

end



function NS.debuff_up(unit, ids)

    if not unit then return false end

    local list = collect_ids(ids, {})

    for i = 1, #list do

        local id = list[i]

        if safe(safe_field(unit, "has_debuff"), unit, id) or safe(safe_field(unit, "debuff_up"), unit, id) then return true end

    end

    return aura_data(unit, ids, "debuff") ~= nil

end



function NS.buff_remains(unit, ids)

    if not unit then return 0 end

    local list = collect_ids(ids, {})

    for i = 1, #list do

        local v = safe(safe_field(unit, "buff_remains"), unit, list[i])

        if type(v) == "number" and v > 0 then return v end

    end

    local data = aura_data(unit, ids, "buff")

    return aura_remaining_seconds(data)

end



function NS.buff_stacks(unit, ids)

    if not unit then return 0 end

    local list = collect_ids(ids, {})

    for i = 1, #list do

        local v = safe(safe_field(unit, "get_buff_stacks"), unit, list[i])

        if type(v) == "number" and v > 0 then return v end

    end

    local data = aura_data(unit, ids, "buff")

    return data and (data.count or data.stacks or 0) or 0

end



--- Returns the points array from buff aura data for variable-value tracking.
--- `buff.points` contains variable values from aura data (e.g. absorb remaining
--- for Power Word: Shield, remaining charges for Holy Shield).
--- Returns the array on success, nil if buff not found.
---
--- Usage:
---   local points = NS.buff_points(unit, POWER_WORD_SHIELD_BUFF_IDS)
---   local absorb_remaining = points and points[1] or 0
---@param unit game_object The unit to check.
---@param ids table Array of spell IDs (highest rank first).
---@return number[]|nil points The points array from active buff data, or nil.
function NS.buff_points(unit, ids)

    if not unit then return nil end

    local data = aura_data(unit, ids, "buff")

    if not data then return nil end

    local points = data.points

    if type(points) == "table" then return points end

    return nil

end



--- Returns the points array from debuff aura data.
---@param unit game_object The unit to check.
---@param ids table Array of spell IDs.
---@return number[]|nil points The points array from active debuff data, or nil.
function NS.debuff_points(unit, ids)

    if not unit then return nil end

    local data = aura_data(unit, ids, "debuff")

    if not data then return nil end

    local points = data.points

    if type(points) == "table" then return points end

    return nil

end



function NS.debuff_remains(unit, ids)

    if not unit then return 0 end

    local list = collect_ids(ids, {})

    for i = 1, #list do

        local v = safe(safe_field(unit, "debuff_remains"), unit, list[i])

        if type(v) == "number" and v > 0 then return v end

    end

    local data = aura_data(unit, ids, "debuff")

    return aura_remaining_seconds(data)

end



function NS.debuff_stacks(unit, ids)

    if not unit then return 0 end

    local list = collect_ids(ids, {})

    for i = 1, #list do

        local v = safe(safe_field(unit, "get_debuff_stacks"), unit, list[i])

        if type(v) == "number" and v > 0 then return v end

    end

    local data = aura_data(unit, ids, "debuff")

    return data and (data.count or data.stacks or 0) or 0

end



function NS.get_debuff_stacks(unit, ids)

    if not unit then return 0 end

    local list = collect_ids(ids, {})

    for i = 1, #list do

        local id = list[i]

        local v = safe(safe_field(unit, "get_debuff_stacks"), unit, id)

        if type(v) == "number" and v > 0 then return v end

        v = safe(safe_field(unit, "get_buff_stacks"), unit, id)

        if type(v) == "number" and v > 0 then return v end

    end

    local data = aura_data(unit, ids, "debuff")

    return data and (data.count or data.stacks or 0) or 0

end



function NS.has_player_buff(ids) return NS.buff_up(NS.GetPlayer(), ids) end

-- Alias: NS.has_buff is used by middleware and shared helpers but was never defined
NS.has_buff = NS.buff_up



local function aura_field(aura, ...)

    if type(aura) ~= "table" then return nil end

    for i = 1, select("#", ...) do

        local key = select(i, ...)

        local value = aura[key]

        if value ~= nil then return value end

    end

    return nil

end



local function aura_id(aura)

    return tonumber(aura_field(aura, "buff_id", "spell_id", "aura_id", "id", "spellId", "spellID"))

end



local function aura_name(aura)

    return aura_field(aura, "buff_name", "name", "spell_name", "aura_name") or "?"

end



local function aura_remaining(aura)

    local remaining = tonumber(aura_field(aura, "remaining", "remains", "remaining_ms"))

    if remaining and remaining > 0 then return remaining end

    local expire_time = tonumber(aura_field(aura, "expire_time", "expiration_time", "expires"))

    if expire_time and expire_time > 0 then return expire_time - NS.game_time_ms() end

    return 0

end



local function aura_stacks(aura)

    return tonumber(aura_field(aura, "stacks", "count", "applications")) or 0

end



local function dump_aura_table(label, auras, watch_ids)

    if type(auras) ~= "table" then

        NS.log("[AURA] " .. label .. ": unavailable (" .. tostring(auras) .. ")")

        return false

    end



    local count = auras.n or #auras

    NS.log("[AURA] " .. label .. ": count=" .. tostring(count))

    local matched = false

    for i = 1, count do

        local aura = auras[i]

        local id = aura_id(aura)

        local name = aura_name(aura)

        local stacks = aura_stacks(aura)

        local remaining = aura_remaining(aura)

        local is_match = id and watch_ids and watch_ids[id] == true

        if is_match then matched = true end

        NS.log(string.format("[AURA] %s[%d]%s id=%s name=%s stacks=%s remains_ms=%s active=%s",

            label,

            i,

            is_match and " MATCH" or "",

            tostring(id),

            tostring(name),

            tostring(stacks),

            tostring(remaining),

            tostring(aura_field(aura, "is_active"))))

    end

    return matched

end



--- Dumps local-player aura data and direct buff checks for debugging ID/API mismatches.

-- Call from the Diagnostics menu or from code: NS.dump_player_auras({324, 325})

function NS.dump_player_auras(watch_ids)

    local me = NS.GetPlayer and NS.GetPlayer() or nil

    if not me then NS.log("[AURA] No local player found"); return false end



    local ids = collect_ids(watch_ids or { 25472, 25469, 10432, 10431, 10430, 8134, 8133, 8132, 945, 905, 325, 324 }, {})

    local watch = {}

    for i = 1, #ids do watch[ids[i]] = true end



    NS.log("=== PLAYER AURA DUMP ===")

    NS.log("[AURA] watch_ids=" .. table.concat(ids, ","))

    NS.log("[AURA] NS.buff_up(watch_ids)=" .. tostring(NS.buff_up(me, ids)))



    for i = 1, #ids do

        local id = ids[i]

        local has_buff = safe(safe_field(me, "has_buff"), me, id)

        local buff_up_value = safe(safe_field(me, "buff_up"), me, id)

        local buff_data = safe(safe_field(me, "get_buff_data"), me, id)

        local aura_data_value = safe(safe_field(me, "get_aura_data"), me, id)

        NS.log(string.format("[AURA] check id=%d has_buff=%s buff_up=%s get_buff_data=%s get_aura_data=%s buff_name=%s aura_name=%s",

            id,

            tostring(has_buff),

            tostring(buff_up_value),

            tostring(buff_data ~= nil and buff_data.is_active ~= false),

            tostring(aura_data_value ~= nil and aura_data_value.is_active ~= false),

            tostring(type(buff_data) == "table" and aura_name(buff_data) or "?"),

            tostring(type(aura_data_value) == "table" and aura_name(aura_data_value) or "?")))

    end



    local buffs = safe(safe_field(me, "get_buffs"), me)

    local auras = safe(safe_field(me, "get_auras"), me)

    local buff_match = dump_aura_table("get_buffs", buffs, watch)

    local aura_match = dump_aura_table("get_auras", auras, watch)



    NS.log("[AURA] get_buffs_match=" .. tostring(buff_match) .. " get_auras_match=" .. tostring(aura_match))

    NS.log("=== END PLAYER AURA DUMP ===")

    return true

end



local function unit_distance(a, b)

    if not a then return 999 end

    local other = b or NS.GetPlayer()

    local distance_to = safe_field(a, "distance_to")

    local v = distance_to and other and safe(distance_to, a, other) or nil

    if type(v) == "number" then return v end

    local get_distance = safe_field(a, "get_distance")

    v = get_distance and safe(get_distance, a, other)

    if type(v) == "number" then return v end

    local distance_self = safe_field(a, "distance")

    v = distance_self and safe(distance_self, a) or nil

    return type(v) == "number" and v or 999

end



function NS.unit_distance(unit, other)

    return unit_distance(unit, other)

end



local function unit_class_id(unit)

    local get_class = safe_field(unit, "get_class")

    local class_id = get_class and safe(get_class, unit) or nil

    return type(class_id) == "number" and class_id or nil

end



local function is_melee_target(target, me)

    if not target then return false end

    local class_id = unit_class_id(target)

    if class_id and MELEE_CLASS_IDS[class_id] then return true end

    for i = 1, #MELEE_SIGNAL_BUFFS do

        if NS.buff_up(target, MELEE_SIGNAL_BUFFS[i]) then return true end

    end

    return unit_distance(target, me) <= 5

end



function NS.is_melee_target(target, me)

    return is_melee_target(target, me)

end



function NS.is_target_bursting(target)

    if not target then return false end

    for i = 1, #PVP_BURST_BUFFS do

        if NS.buff_up(target, PVP_BURST_BUFFS[i]) then return true end

    end

    return false

end



function NS.should_kite(context)

    if type(context) ~= "table" or not context.in_combat then return false end

    local settings = context.settings or EMPTY

    local threshold = settings.pvp_kite_threshold or 50

    local hp = context.hp or NS.unit_health_pct(context.me or NS.GetPlayer())

    if hp >= threshold then return false end

    if (context.target_hp or 100) <= 30 then return false end

    return is_melee_target(context.target, context.me or NS.GetPlayer())

end



-- PvP zone detection using map IDs (TBC battlegrounds + arenas).

-- Uses core.get_map_id() when available; falls back to instance ID and arena frame presence.

local _BG_MAP_IDS = {

    [489] = true, -- Warsong Gulch

    [529] = true, -- Arathi Basin

    [566] = true, -- Eye of the Storm

    [30]  = true, -- Alterac Valley

    [607] = true, -- Strand of the Ancients (WotLK but kept for safety)

    [628] = true, -- Isle of Conquest (WotLK)

    [572] = true, -- Ruins of Lordaeron (arena)

    [559] = true, -- Nagrand Arena

    [562] = true, -- Blade's Edge Arena

    [617] = true, -- Dalaran Sewers (WotLK)

    [618] = true, -- Ring of Valor (WotLK)

}

local _last_pvp_zone_check = 0

local _cached_pvp_zone_result = false



function NS.is_pvp_zone()

    local now = NS.time_now()

    if now - _last_pvp_zone_check < 5 then return _cached_pvp_zone_result end

    _last_pvp_zone_check = now



    -- Primary: map ID

    if type(core.get_map_id) == "function" then

        local ok, map_id = pcall(core.get_map_id)

        if ok and _BG_MAP_IDS[map_id] then

            _cached_pvp_zone_result = true

            return true

        end

    end

    -- Fallback: instance ID (many BGs share instance IDs)

    if type(core.get_instance_id) == "function" then

        local ok, instance_id = pcall(core.get_instance_id)

        if ok and type(instance_id) == "number" and instance_id > 0 then

            _cached_pvp_zone_result = true

            return true

        end

    end

    -- Fallback: arena frames present

    if core.object_manager and type(core.object_manager.get_arena_frames) == "function" then

        local ok, frames = pcall(core.object_manager.get_arena_frames)

        if ok and type(frames) == "table" and #frames > 0 then

            _cached_pvp_zone_result = true

            return true

        end

    end

    _cached_pvp_zone_result = false

    return false

end



-- Filter an enemy list to player targets only.

-- `enemies` is a table (array or {n=count}); `out` is optional reusable buffer.

-- Returns `out, count` so callers can avoid per-frame table allocation.

function NS.filter_pvp_targets(enemies, out)

    out = out or {}

    for k in pairs(out) do out[k] = nil end

    if type(enemies) ~= "table" then return out, 0 end

    local n = 0

    local max = enemies.n or #enemies

    for i = 1, max do

        local u = enemies[i]

        if u then

            local is_player = safe_field(u, "is_player")

            if is_player and safe(is_player, u) == true then

                n = n + 1

                out[n] = u

            end

        end

    end

    out.n = n

    return out, n

end



function NS.is_safe_to_cast(context, cast_time)

    if type(context) ~= "table" then return true end

    local target = context.target

    local cast_seconds = type(cast_time) == "number" and cast_time or 0

    if target and NS.debuff_up(target, NS.CC_DEBUFFS) and NS.debuff_remains(target, NS.CC_DEBUFFS) > cast_seconds then

        return true

    end

    for i = 1, #PLAYER_DEFENSIVE_BUFFS do

        if NS.has_player_buff(PLAYER_DEFENSIVE_BUFFS[i]) then return true end

    end

    return not NS.should_kite(context) and not NS.is_target_bursting(target)

end

function NS.player_control_locked() return false end

function NS.has_breakable_cc_nearby() return false end

function NS.try_interrupt(target)

    if not target then return false end

    local is_casting = safe_field(target, "is_casting")

    if safe(is_casting, target) == true then return true end

    local is_casting_spell = safe_field(target, "is_casting_spell")

    if safe(is_casting_spell, target) == true then return true end

    local is_channeling = safe_field(target, "is_channeling")

    if safe(is_channeling, target) == true then return true end

    local is_channelling_spell = safe_field(target, "is_channelling_spell")

    if safe(is_channelling_spell, target) == true then return true end

    local is_channeling_or_casting = safe_field(target, "is_channeling_or_casting")

    if safe(is_channeling_or_casting, target) == true then return true end

    local get_casting_spell_id = safe_field(target, "get_casting_spell_id")

    local spell_id = safe(get_casting_spell_id, target)

    return type(spell_id) == "number" and spell_id > 0

end

function NS.match_fail() return false end



function NS.is_current_spell(spell_id)

    local fn = core.spell_book and core.spell_book.is_current_spell

    return type(spell_id) == "number" and safe(fn, spell_id) == true

end



local auto_attack_helper = false

local function get_auto_attack_helper()

    if auto_attack_helper ~= false then return auto_attack_helper end

    local ok, module = pcall(require, "common/utility/auto_attack_helper")

    auto_attack_helper = ok and module or nil

    return auto_attack_helper

end



function NS.get_time_until_swing()

    local player = NS.GetPlayer()

    if not player then return nil end

    local helper = get_auto_attack_helper()

    local now = NS.time_now()

    local next_core = helper and safe(safe_field(helper, "get_next_attack_core_time"), helper, player, 1) or nil

    if type(next_core) == "number" and next_core > 0 then

        return math.max(0, next_core - now)

    end

    local next_game = helper and safe(safe_field(helper, "get_next_attack_game_time"), helper, player, 1) or nil

    if type(next_game) == "number" and next_game > 0 then

        return math.max(0, (next_game - NS.game_time_ms()) / 1000)

    end

    return nil

end



function NS.get_time_until_oh_swing()

    local player = NS.GetPlayer()

    if not player then return nil end

    local helper = get_auto_attack_helper()

    local now = NS.time_now()

    local next_core = helper and safe(safe_field(helper, "get_next_attack_core_time"), helper, player, 2) or nil

    if type(next_core) == "number" and next_core > 0 then

        return math.max(0, next_core - now)

    end

    local next_game = helper and safe(safe_field(helper, "get_next_attack_game_time"), helper, player, 2) or nil

    if type(next_game) == "number" and next_game > 0 then

        return math.max(0, (next_game - NS.game_time_ms()) / 1000)

    end

    return nil

end



local FORMS = {

    bear = { 5487, 9634 }, cat = { 768 }, moonkin = { 24858 }, tree = { 33891 },

    prowl = { 5215, 6783, 9913 }, stealth = { 1784, 1785, 1786, 1787 },

    battle = { 2457 }, defensive = { 71 }, berserker = { 2458 }, shadow = { 15473 },

}



function NS.has_form(name)

    if type(name) == "number" then return NS.has_player_buff(name) end

    return NS.has_player_buff(FORMS[name] or EMPTY)

end



function NS.is_behind_target(target)

    local me = NS.GetPlayer()

    local get_target = safe_field(me, "get_target")

    target = target or (get_target and safe(get_target, me))

    if not me or not target then return false end

    local is_behind = safe_field(me, "is_behind")

    if is_behind then return safe(is_behind, me, target) == true end

    local is_behind_unit = safe_field(me, "is_behind_unit")

    if is_behind_unit then return safe(is_behind_unit, me, target) == true end

    return false

end



function NS.get_player_stance()

    if NS.has_form("battle") then return 1 end

    if NS.has_form("defensive") then return 2 end

    if NS.has_form("berserker") then return 3 end

    return 0

end



local distance



function NS.is_hostile_unit(me, target)

    if not me or not target or not NS.unit_alive(target) then return false end

    local saw_negative = false

    local can_attack = safe_field(me, "can_attack")

    if can_attack then

        local allowed = safe(can_attack, me, target)

        if allowed == true then return true end

        if allowed == false then saw_negative = true end

    end

    local me_enemy_with = safe_field(me, "is_enemy_with")

    if me_enemy_with and safe(me_enemy_with, me, target) == true then return true end

    local target_can_attack = safe_field(target, "can_attack")

    if target_can_attack and safe(target_can_attack, target, me) == true then return true end

    local target_enemy_with = safe_field(target, "is_enemy_with")

    if target_enemy_with and safe(target_enemy_with, target, me) == true then return true end

    local is_valid_enemy = safe_field(target, "is_valid_enemy")

    if is_valid_enemy and safe(is_valid_enemy, target) == true then return true end

    local get_reaction = safe_field(target, "get_reaction") or safe_field(target, "reaction")

    if get_reaction then

        local reaction = safe(get_reaction, target)

        if type(reaction) == "number" and reaction < 4 then return true end

    end

    local get_reaction_to = safe_field(target, "get_reaction_to")

    if get_reaction_to then

        local reaction = safe(get_reaction_to, target, me)

        if type(reaction) == "number" and reaction < 4 then return true end

    end

    if saw_negative then return false end

    return can_attack == nil and me_enemy_with == nil and target_can_attack == nil and target_enemy_with == nil and is_valid_enemy == nil and get_reaction == nil and get_reaction_to == nil

end



local function pick_enemy_from_list(me, list, limit, best, best_distance)

    if type(list) ~= "table" then return best, best_distance end

    for i = 1, #list do

        local unit = list[i]

        if NS.not_same_unit(unit, me) and NS.is_hostile_unit(me, unit) then

            local d = distance(unit, me)

            if d <= limit and (not best_distance or d < best_distance) then

                best, best_distance = unit, d

            end

        end

    end

    return best, best_distance

end



function NS.GetBestEnemyTarget(range)

    local me = NS.GetPlayer()

    if not me then return nil end

    local limit = type(range) == "number" and range or 40



    local target = NS.GetTarget()

    if NS.is_hostile_unit(me, target) and distance(target, me) <= limit then

        return target

    end



    local best, best_distance = nil, nil

    local get_enemies_in_range = safe_field(me, "get_enemies_in_range")

    if get_enemies_in_range then

        best, best_distance = pick_enemy_from_list(me, safe(get_enemies_in_range, me, limit, false), limit, best, best_distance)

        if best then return best end

    end



    local izi = NS.izi

    if izi and type(izi.enemies) == "function" then

        best, best_distance = pick_enemy_from_list(me, safe(izi.enemies, limit, false), limit, best, best_distance)

        if best then return best end

    end



    local get_position = safe_field(me, "get_position")

    local position = get_position and safe(get_position, me) or nil

    local unit_helper = position and NS.GetAPIModule and NS.GetAPIModule("unit_helper") or nil

    local helper_scan = unit_helper and safe_field(unit_helper, "get_enemy_list_around")

    if helper_scan then

        best, best_distance = pick_enemy_from_list(me, safe(helper_scan, unit_helper, position, limit, true, false, false, false), limit, best, best_distance)

        if best then return best end

    end



    local units, count = NS.get_visible_units()

    for i = 1, count do

        local unit = units[i]

        if NS.not_same_unit(unit, me) and NS.is_hostile_unit(me, unit) then

            local d = distance(unit, me)

            if d <= limit and (not best_distance or d < best_distance) then

                best, best_distance = unit, d

            end

        end

    end

    return best

end



function NS.can_attack_target(context)

    return NS.is_hostile_unit(NS.GetPlayer(), context and context.target)

end



local visible, visible_last_ms = {}, -1000

local _enemy_range_buffer = { n = 0 }

local _friends_range_buffer = { n = 0 }

local function visible_unit_ok(obj)

    if not obj then return false end

    local ok, result = pcall(function()

        local is_unit = safe_field(obj, "is_unit")

        if is_unit and safe(is_unit, obj) == false then return false end

        return NS.unit_alive(obj)

    end)

    return ok and result == true

end



local function visible_has_unit(list, count, unit)

    for i = 1, count do

        if NS.same_unit(list[i], unit) then return true end

    end

    return false

end



function NS.get_visible_units(force, max_scan)

    max_scan = max_scan or 50

    local now = NS.game_time_ms()

    if max_scan == 50 and not force and visible.n and now - visible_last_ms < 100 then return visible, visible.n end

    visible_last_ms = now

    for k in pairs(visible) do visible[k] = nil end

    local objects = safe(core.object_manager and core.object_manager.get_visible_objects) or EMPTY

    local n = 0

    for i = 1, #objects do

        if i > max_scan then break end

        local obj = objects[i]

        if visible_unit_ok(obj) then n = n + 1; visible[n] = obj end

    end

    local player = NS.GetPlayer()

    if player and not visible_has_unit(visible, n, player) then n = n + 1; visible[n] = player end

    visible.n = n

    return visible, n

end



distance = function(a, b)

    if not a then return 999 end

    local other = b or NS.GetPlayer()

    local distance_to = safe_field(a, "distance_to")

    local v = distance_to and other and safe(distance_to, a, other) or nil

    if type(v) == "number" then return v end

    local distance_self = safe_field(a, "distance")

    if distance_self and (not other or NS.same_unit(other, NS.GetPlayer())) then

        v = safe(distance_self, a)

        if type(v) == "number" then return v end

    end

    local get_distance = safe_field(a, "get_distance")

    v = get_distance and safe(get_distance, a, other)

    return type(v) == "number" and v or 999

end



local function append_enemy_unique(out, me, unit, limit)

    if not (NS.not_same_unit(unit, me) and NS.is_hostile_unit(me, unit) and distance(unit, me) <= limit) then return end

    for i = 1, #out do

        if NS.same_unit(out[i], unit) then return end

    end

    out.n = out.n + 1; out[out.n] = unit

end



local function append_enemies_from_list(out, me, list, limit)

    if type(list) ~= "table" then return end

    for i = 1, #list do append_enemy_unique(out, me, list[i], limit) end

end



function NS.GetEnemiesInRange(range)

    local me = NS.GetPlayer()

    if not me then return EMPTY end

    for k in pairs(_enemy_range_buffer) do _enemy_range_buffer[k] = nil end

    _enemy_range_buffer.n = 0

    local out = _enemy_range_buffer

    local limit = type(range) == "number" and range or 40



    local get_enemies_in_range = safe_field(me, "get_enemies_in_range")

    if get_enemies_in_range then

        append_enemies_from_list(out, me, safe(get_enemies_in_range, me, limit, false), limit)

    end



    local izi = NS.izi

    if izi and type(izi.enemies) == "function" then

        append_enemies_from_list(out, me, safe(izi.enemies, limit, false), limit)

    end



    local get_position = safe_field(me, "get_position")

    local position = get_position and safe(get_position, me) or nil

    local unit_helper = position and NS.GetAPIModule and NS.GetAPIModule("unit_helper") or nil

    local helper_scan = unit_helper and safe_field(unit_helper, "get_enemy_list_around")

    if helper_scan then

        append_enemies_from_list(out, me, safe(helper_scan, unit_helper, position, limit, true, false, false, false), limit)

    end



    local units, count = NS.get_visible_units()

    for i = 1, count do

        append_enemy_unique(out, me, units[i], limit)

    end

    return out

end



function NS.GetEnemiesCount(range)

    local enemies = NS.GetEnemiesInRange(range)

    return type(enemies) == "table" and #enemies or 0

end



function NS.GetFriendsInRange(range)

    local me = NS.GetPlayer()

    if not me then return EMPTY end

    local units, count = NS.get_visible_units()

    for k in pairs(_friends_range_buffer) do _friends_range_buffer[k] = nil end

    _friends_range_buffer.n = 0

    local out = _friends_range_buffer

    local limit = type(range) == "number" and range or 40

    for i = 1, count do

        local unit = units[i]

        local is_friend_with = safe_field(unit, "is_friend_with")

        if NS.not_same_unit(unit, me) and NS.unit_alive(unit)

            and safe(is_friend_with, unit, me) == true

            and distance(unit, me) <= limit then

            out.n = out.n + 1

            out[out.n] = unit

        end

    end

    return out

end



local party_ally_last_ms, party_ally_cached = -1000, false

local function party_ally_is_valid(unit, me)

    return NS.not_same_unit(unit, me)

        and safe(safe_field(unit, "is_in_combat"), unit) == true

        and distance(unit, me) <= 40

end



function NS.has_group_combat_ally_40(force)

    local now = NS.game_time_ms()

    if not force and now - party_ally_last_ms < 100 then return party_ally_cached end

    party_ally_last_ms = now

    party_ally_cached = false



    local me = NS.GetPlayer()

    if not me then return false end



    local get_party_members_in_range = safe_field(me, "get_party_members_in_range")

    if type(get_party_members_in_range) == "function" then

        local members = safe(get_party_members_in_range, me, 40, true)

        if type(members) == "table" then

            for i = 1, #members do

                if party_ally_is_valid(members[i], me) then party_ally_cached = true; return true end

            end

            return false

        end

    end



    local units, count = NS.get_visible_units()

    for i = 1, count do

        local u = units[i]

        if NS.not_same_unit(u, me) and safe(safe_field(u, "is_party_member"), u) and party_ally_is_valid(u, me) then party_ally_cached = true; return true end

    end

    return false

end



function NS.is_in_party()

    local me = NS.GetPlayer()

    if not me then return false end

    local get_party_members_in_range = safe_field(me, "get_party_members_in_range")

    if type(get_party_members_in_range) == "function" then

        local members = safe(get_party_members_in_range, me, 100, true)

        if type(members) == "table" and #members > 0 then return true end

    end

    local units, count = NS.get_visible_units()

    for i = 1, count do

        local u = units[i]

        if NS.not_same_unit(u, me) and safe(safe_field(u, "is_party_member"), u) == true then return true end

    end

    return false

end



function NS.is_in_raid()

    -- The public object API exposes party membership, not a separate raid

    -- membership query. Treat grouped raid/party healing as group-aware here.

    return NS.is_in_party()

end



local API_MODULES = {

    spell_helper = "common/utility/spell_helper",

    unit_helper = "common/utility/unit_helper",

    cooldown_tracker = "common/utility/cooldown_tracker",

}



function NS.GetAPIModule(name)

    local path = API_MODULES[name] or name

    if type(path) ~= "string" then return nil end

    local ok, module = pcall(require, path)

    return ok and module or nil

end



function NS.threat_status(unit, target)

    local value = unit and safe(safe_field(unit, "get_threat_situation"), unit, target)

    if type(value) == "table" then return value.status or 0 end

    if type(value) == "number" then return value end

    return 0

end



function NS.should_drop_threat(context)

    if not context or not context.in_combat then return false end

    if not NS.has_group_combat_ally_40() then return false end

    return NS.threat_status(NS.GetPlayer(), context.target) >= 2

end



function NS.predict_effective_deficit(unit)

    if not unit then return 0 end

    local hp = safe(safe_field(unit, "get_health"), unit) or 0

    local max_hp = safe(safe_field(unit, "get_max_health"), unit) or hp

    local incoming = safe(safe_field(unit, "get_incoming_heals"), unit) or 0

    local absorbs = safe(safe_field(unit, "get_total_shield"), unit) or 0

    return math.max(0, max_hp - hp - incoming - absorbs)

end



local DISPEL_TYPE_ID = { Magic = 1, Curse = 2, Disease = 3, Poison = 4, Enrage = 9 }

function NS.has_dispel_type_debuff(unit, dispel_type)

    if not unit then return false end

    local wanted = DISPEL_TYPE_ID[dispel_type] or DISPEL_TYPE_ID[tostring(dispel_type or "")]

    local wanted_text = tostring(dispel_type or ""):lower()

    local debuffs = safe(safe_field(unit, "get_debuffs"), unit) or EMPTY

    for i = 1, #debuffs do

        local aura = debuffs[i]

        local aura_type = aura and (aura.type or aura.buff_type or aura.dispel_type)

        if aura_type == wanted or tostring(aura_type or ""):lower() == wanted_text then return true end

    end

    return false

end



local HEALING_REDUCTION_DEBUFFS = {

    12294, 21551, 21552, 21553, 25248, 30330, -- Mortal Strike ranks

    19434, 20900, 20901, 20902, 20903, 20904, 27065, -- Aimed Shot ranks

    13218, 13222, 13223, 13224, 27189, -- Wound Poison ranks

}

function NS.has_healing_reduction_debuff(unit)

    return NS.debuff_up(unit, HEALING_REDUCTION_DEBUFFS)

end



local function is_tank_unit(unit)

    if not unit then return false end

    local is_tank = safe_field(unit, "is_tank")

    if is_tank and safe(is_tank, unit) == true then return true end

    return safe(safe_field(unit, "get_group_role"), unit) == 0

end



local healing_source_units = { n = 0 }

local function append_healing_source_unit(out, unit)

    if not NS.unit_alive(unit) then return 0 end

    for i = 1, out.n do

        if NS.same_unit(out[i], unit) then return 0 end

    end

    out.n = out.n + 1

    out[out.n] = unit

    return 1

end



local function append_healing_source_list(out, list)

    if type(list) ~= "table" then return 0 end

    local added = 0

    for i = 1, #list do

        added = added + append_healing_source_unit(out, list[i])

    end

    return added

end



local function get_party_ally_list(me)

    for k in pairs(healing_source_units) do healing_source_units[k] = nil end

    healing_source_units.n = 0



    local added = 0

    local object_manager = core.object_manager

    local get_raid_members = object_manager and object_manager.get_raid_members

    if type(get_raid_members) == "function" then

        added = added + append_healing_source_list(healing_source_units, safe(get_raid_members))

    end



    local get_party_members = object_manager and object_manager.get_party_members

    if type(get_party_members) == "function" then

        added = added + append_healing_source_list(healing_source_units, safe(get_party_members))

    end



    local get_party_members_in_range = safe_field(me, "get_party_members_in_range")

    if type(get_party_members_in_range) == "function" then

        added = added + append_healing_source_list(healing_source_units, safe(get_party_members_in_range, me, 40, true))

    end



    if added <= 0 then return nil, 0 end

    append_healing_source_unit(healing_source_units, me)

    return healing_source_units, healing_source_units.n

end



function NS.build_healing_entries(out, decorate)

    out = out or {}

    for k in pairs(out) do out[k] = nil end

    local me = NS.GetPlayer()

    if not me then return 0 end

    local units, count = get_party_ally_list(me)

    if not units or count <= 0 then

        units, count = NS.get_visible_units(false, 200)

    end

    local n = 0

    for i = 1, count do

        local u = units[i]

        local is_friend_with = safe_field(u, "is_friend_with")

        if u and (NS.same_unit(u, me) or safe(is_friend_with, u, me)) and distance(u, me) <= 40 then

            local hp = safe(safe_field(u, "get_health"), u) or 0

            local max_hp = safe(safe_field(u, "get_max_health"), u) or hp

            n = n + 1

            local effective_deficit = NS.predict_effective_deficit(u)

            local effective_hp = max_hp > 0 and ((max_hp - effective_deficit) / max_hp) * 100 or NS.unit_health_pct(u)

            out[n] = {

                unit = u, hp = NS.unit_health_pct(u), effective_hp = effective_hp,

                current_hp = hp, max_hp = max_hp, deficit = math.max(0, max_hp - hp),

                effective_deficit = effective_deficit,

                is_player = NS.same_unit(u, me),

                is_tank = is_tank_unit(u),

            }

            if decorate then pcall(decorate, out[n], u) end

        end

    end

    sort(out, function(a, b) return (a.effective_hp or 100) < (b.effective_hp or 100) end)

    return n

end



local healing_unit_buffer = {}

function NS.collect_healing_units()

    local count = NS.build_healing_entries(healing_unit_buffer)

    local units = {}

    for i = 1, count do

        units[i] = healing_unit_buffer[i] and healing_unit_buffer[i].unit or nil

    end

    return units

end



function NS.find_dead_party_ally()

    local ok, scan = pcall(require, "shared/find_dead_party_ally_sylvanas")

    if ok and scan and scan.find_dead_party_ally then

        return scan.find_dead_party_ally({

            get_player = NS.GetPlayer,

            collect_healing_units = NS.GetPartyMembers,

        })

    end

    return nil

end



function NS.healing_get_tank(entries, count)

    for i = 1, count or 0 do if entries[i] and entries[i].is_tank then return entries[i] end end

    return nil

end



function NS.healing_get_lowest_hp(entries, count, threshold)

    threshold = threshold or 100

    for i = 1, count or 0 do if entries[i] and (entries[i].effective_hp or 100) <= threshold then return entries[i] end end

    return nil

end



function NS.healing_all_above_hp(entries, count, threshold)

    for i = 1, count or 0 do if entries[i] and (entries[i].effective_hp or 100) < threshold then return false end end

    return true

end



function NS.healing_get_cleanse_target(entries, count)

    for i = 1, count or 0 do if entries[i] and entries[i].needs_cleanse then return entries[i] end end

    return nil

end



function NS.healing_count_below_hp(entries, count, threshold)

    local n = 0

    for i = 1, count or 0 do if entries[i] and (entries[i].effective_hp or 100) <= threshold then n = n + 1 end end

    return n

end



function NS.cast_best_heal_rank(ranks, target, context, label)

    if type(ranks) ~= "table" then return nil end

    for i = 1, #ranks do

        local entry = ranks[i]

        local spell = type(entry) == "table" and (entry.spell or entry[1]) or entry

        if spell and NS.spell_ready(spell, target) then return spell, (label or "Heal") .. " " .. tostring(type(entry) == "table" and (entry.label or i) or i) end

    end

    return nil

end



local registry = NS.rotation_registry or { playstyles = {}, options = {}, class_config = nil }

NS.rotation_registry = registry



function registry:set_class_config(config)

    self.class_config = config

    if config and config.default_playstyle and NS.get_setting("active_playstyle") == nil then

        local selected_playstyle = NS.get_setting("playstyle", nil)

        if type(selected_playstyle) == "string" and selected_playstyle ~= "" then

            NS.set_setting("active_playstyle", selected_playstyle)

        else

            NS.set_setting("active_playstyle", config.default_playstyle)

        end

    end

end



function registry:register(name, strategies, options)

    self.playstyles[name] = strategies or EMPTY

    self.options[name] = options or EMPTY

    return true

end



function NS.register_class_middleware(class_key, strategies)

    NS.class_middleware[class_key] = strategies or EMPTY

end



-- Unified strategy registry

-- Combines middleware + playstyle strategies into a single priority-ordered dispatch list.

-- Entries are sorted descending by priority so higher numbers run first.

NS.unified_registry = NS.unified_registry or {}



function NS.register_strategy(entry)

    -- entry = { name, category, priority=number, is_burst=bool, is_defensive=bool, matches=fn, execute=fn }

    if type(entry) ~= "table" or type(entry.execute) ~= "function" then return false end

    entry.priority = entry.priority or 0

    table.insert(NS.unified_registry, entry)

    table.sort(NS.unified_registry, function(a, b) return (a.priority or 0) > (b.priority or 0) end)

    return true

end



function NS.clear_strategies()

    for i = 1, #NS.unified_registry do NS.unified_registry[i] = nil end

end



-- Category inference helpers (mirrored from main_sylvanas.lua for standalone use)

local HEALING_PLAYSTYLES = {

    holy = true, discipline = true, restoration = true, resto = true,

}



local HEALING_NAMES = {

    "heal", "renew", "mending", "lifebloom", "rejuvenation", "regrowth",

    "powerwordshield", "pws", "circleofhealing", "prayerofhealing",

    "bindingheal", "holyshock", "layonhands", "earthshield", "smartgroupheal",

    "smartheal", "naturesswiftness",

}



local DAMAGE_NAMES = {

    "idle", "smite", "shadowwordpain", "holyfire", "mindblast",

    "shadowworddeath", "mindflay", "judgement", "crusaderstrike",

    "consecration", "execute", "mortalstrike", "whirlwind", "bloodthirst",

    "fireball", "frostbolt", "arcane", "scorch", "shadowbolt",

}



local COOLDOWN_NAMES = {

    "avengingwrath", "combustion", "icyveins", "arcanepower", "rapidfire",

    "bestialwrath", "bloodfury", "berserking", "innervate", "shadowfiend",

    "innerfocus", "sweepingstrikes", "recklessness", "deathwish",

    "bladeflurry", "adrenalinerush", "bloodlust", "shamanisticrage",

}



local UTILITY_NAMES = {

    "interrupt", "kick", "pummel", "counterspell", "spelllock", "silence",

    "cleanse", "dispel", "purify", "cure", "fade", "feign", "vanish",

    "evasion", "sprint", "cower", "righteousfury", "battletrance",

    "battleshout", "commandingshout", "watershield", "shadowform",

    "bearform", "catform", "moonkinform", "stance", "thunderclap",

    "demoshout", "demoralizing", "sunder", "faeriefire",

}



local DEFENSIVE_NAMES = {

    "shieldblock", "barkskin", "iceblock", "manashield", "divineshield",

    "frenziedregeneration", "shieldwall", "laststand", "holyshield",

}



local function contains_any(value, needles)

    if type(value) ~= "string" then return false end

    for i = 1, #needles do

        if value:find(needles[i], 1, true) then return true end

    end

    return false

end



local function strategy_category(strategy, list_name, active)

    if type(strategy) ~= "table" then return "damage" end

    if type(strategy.category) == "string" then return strategy.category end

    local name = tostring(strategy.name or ""):gsub("%s+", ""):lower()

    if contains_any(name, HEALING_NAMES) then return "healing" end

    if contains_any(name, DEFENSIVE_NAMES) then return "utility" end

    if strategy.is_burst or contains_any(name, COOLDOWN_NAMES) then return "cooldown" end

    if contains_any(name, UTILITY_NAMES) then return "utility" end

    if list_name == "middleware" then return "utility" end

    if HEALING_PLAYSTYLES[tostring(active or ""):lower()] then

        if contains_any(name, DAMAGE_NAMES) then return "damage" end

        return "healing"

    end

    return "damage"

end



-- Strategy gate: checks category toggles from settings and burst conditions.

-- Reused by both the legacy run_list dispatcher and the unified registry.

function NS.strategy_allowed(strategy, list_name, active, context)

    local settings = context and context.settings or EMPTY

    local category = strategy_category(strategy, list_name, active)

    local is_healer = HEALING_PLAYSTYLES[tostring(active or ""):lower()] == true

    if settings.utility_enabled == false and category == "utility" then return false end

    if settings.healing_enabled == false and (category == "healing" or (is_healer and category == "cooldown")) then return false end

    if settings.damage_enabled == false and (category == "damage" or (category == "cooldown" and not is_healer)) then return false end

    if settings.use_cooldowns == false and category == "cooldown" and not (context and context.should_burst) then return false end

    return true

end



function NS.run_unified_strategies(context)

    local safe_fn = safe

    for i = 1, #NS.unified_registry do

        local s = NS.unified_registry[i]

        if NS.strategy_allowed(s, nil, context and context.active_playstyle, context) then

            local ok = true

            if type(s.matches) == "function" then ok = safe_fn(s.matches, context) == true end

            if ok and safe_fn(s.execute, context) then return true end

        end

    end

    return false

end



local function target_for(context, action)

    if action.target == "self" then return NS.GetPlayer() end

    if action.target == "pet" then return NS.GetPet() end

    if action.target == "cc_target" then return context and context.cc_target or nil end

    return action.unit or context.target

end



local function position_for(context, action)

    if not action or not action.position then return nil end

    if type(action.position) == "table" and not action.position.get_position then

        return action.position

    end



    local source = nil

    if action.position == "self" then

        source = NS.GetPlayer()

    elseif action.position == "target" then

        source = context and context.target or nil

    elseif type(action.position) == "table" then

        source = action.position

    end



    local get_position = source and safe_field(source, "get_position")

    return get_position and safe(get_position, source) or nil

end



function NS.action_matches(context, action)

    local settings = context.settings or EMPTY

    local debug = NS.get_setting and NS.get_setting("debug_system", false) or false

    local name = action.name or "?"

    if action.setting and settings[action.setting] == false then

        if debug then core_trace("action:" .. tostring(action.name) .. ":setting", "[DEBUG] " .. name .. " blocked: setting=" .. tostring(action.setting), 2000) end
        return false

    end

    if action.min_interval then

        local last = _last_action_exec[name]

        if last and (NS.time_now() - last) < action.min_interval then

            if debug then core_trace("action:" .. tostring(action.name) .. ":min_interval", "[DEBUG] " .. name .. " blocked: min_interval=" .. tostring(action.min_interval) .. "s (last=" .. tostring(NS.time_now() - last) .. "s ago)", 2000) end
            return false

        end

    end

    if action.combat and not context.in_combat then

        if debug then core_trace("action:" .. tostring(action.name) .. ":combat_required", "[DEBUG] " .. name .. " blocked: combat_required", 2000) end
        return false

    end

    if action.ooc and context.in_combat then

        if debug then core_trace("action:" .. tostring(action.name) .. ":ooc_required", "[DEBUG] " .. name .. " blocked: ooc_required", 2000) end
        return false

    end

    local actor_hp = action.target == "pet" and NS.unit_health_pct(NS.GetPet()) or (context.hp or 100)

    if action.max_hp and actor_hp > action.max_hp then

        if debug then core_trace("action:" .. tostring(action.name) .. ":max_hp", "[DEBUG] " .. name .. " blocked: max_hp=" .. tostring(actor_hp), 2000) end
        return false

    end

    if action.min_hp and actor_hp < action.min_hp then

        if debug then core_trace("action:" .. tostring(action.name) .. ":min_hp", "[DEBUG] " .. name .. " blocked: min_hp=" .. tostring(actor_hp), 2000) end
        return false

    end

    if action.target_max_hp and (context.target_hp or 100) > action.target_max_hp then

        if debug then core_trace("action:" .. tostring(action.name) .. ":target_max_hp", "[DEBUG] " .. name .. " blocked: target_max_hp=" .. tostring(context.target_hp), 2000) end
        return false

    end

    if action.target_min_hp and (context.target_hp or 100) < action.target_min_hp then

        if debug then core_trace("action:" .. tostring(action.name) .. ":target_min_hp", "[DEBUG] " .. name .. " blocked: target_min_hp=" .. tostring(context.target_hp), 2000) end
        return false

    end

    if action.min_level and (context.player_level or 70) < action.min_level then

        if debug then core_trace("action:" .. tostring(action.name) .. ":min_level", "[DEBUG] " .. name .. " blocked: min_level=" .. tostring(context.player_level), 2000) end
        return false

    end

    if action.max_level and (context.player_level or 70) > action.max_level then

        if debug then core_trace("action:" .. tostring(action.name) .. ":max_level", "[DEBUG] " .. name .. " blocked: max_level=" .. tostring(context.player_level), 2000) end
        return false

    end

    if action.min_ttd then

        if action.require_ttd and not context.ttd_known then

            if debug then core_trace("action:" .. tostring(action.name) .. ":ttd_unknown", "[DEBUG] " .. name .. " blocked: ttd_unknown", 2000) end
            return false

        end

        if (context.ttd or 0) < action.min_ttd then

            if debug then core_trace("action:" .. tostring(action.name) .. ":min_ttd", "[DEBUG] " .. name .. " blocked: min_ttd=" .. tostring(context.ttd), 2000) end
            return false

        end

    end

    if action.enemy_count and (context.enemy_count or 0) < action.enemy_count then

        if debug then core_trace("action:" .. tostring(action.name) .. ":enemy_count", "[DEBUG] " .. name .. " blocked: enemy_count=" .. tostring(context.enemy_count), 2000) end
        return false

    end

    if context.settings and context.settings.aoe_enabled == false and (action.enemy_count or action.is_aoe) then

        if debug then core_trace("action:" .. tostring(action.name) .. ":aoe_disabled", "[DEBUG] " .. name .. " blocked: aoe_disabled", 2000) end
        return false

    end

    if action.max_enemy_count and (context.enemy_count or 0) > action.max_enemy_count then

        if debug then core_trace("action:" .. tostring(action.name) .. ":max_enemy_count", "[DEBUG] " .. name .. " blocked: max_enemy_count=" .. tostring(context.enemy_count), 2000) end
        return false

    end

    if action.min_mana and (context.mana_pct or 100) < action.min_mana then

        if debug then core_trace("action:" .. tostring(action.name) .. ":min_mana", "[DEBUG] " .. name .. " blocked: min_mana=" .. tostring(context.mana_pct), 2000) end
        return false

    end

    if action.max_mana and (context.mana_pct or 100) > action.max_mana then

        if debug then core_trace("action:" .. tostring(action.name) .. ":max_mana", "[DEBUG] " .. name .. " blocked: max_mana=" .. tostring(context.mana_pct), 2000) end
        return false

    end

    if action.target == "pet" and not NS.GetPet() then

        if debug then core_trace("action:" .. tostring(action.name) .. ":no_pet", "[DEBUG] " .. name .. " blocked: no_pet", 2000) end
        return false

    end

    if action.min_rage and (context.rage or 0) < action.min_rage then

        if debug then core_trace("action:" .. tostring(action.name) .. ":min_rage", "[DEBUG] " .. name .. " blocked: min_rage=" .. tostring(context.rage), 2000) end
        return false

    end

    if action.min_energy and (context.energy or 0) < action.min_energy then

        if debug then core_trace("action:" .. tostring(action.name) .. ":min_energy", "[DEBUG] " .. name .. " blocked: min_energy=" .. tostring(context.energy), 2000) end
        return false

    end

    if action.min_combo and (context.combo_points or 0) < action.min_combo then

        if debug then core_trace("action:" .. tostring(action.name) .. ":min_combo", "[DEBUG] " .. name .. " blocked: min_combo=" .. tostring(context.combo_points), 2000) end
        return false

    end

    if action.not_moving and context.is_moving then

        if debug then core_trace("action:" .. tostring(action.name) .. ":moving", "[DEBUG] " .. name .. " blocked: moving", 2000) end
        return false

    end

    if action.moving and not context.is_moving then

        if debug then core_trace("action:" .. tostring(action.name) .. ":not_moving", "[DEBUG] " .. name .. " blocked: not_moving", 2000) end
        return false

    end

    if action.not_casting and (context.is_casting or context.is_channeling) then

        if debug then core_trace("action:" .. tostring(action.name) .. ":already_casting", "[DEBUG] " .. name .. " blocked: already_casting", 2000) end
        return false

    end

    if action.required_stance and context.stance ~= action.required_stance then

        if debug then core_trace("action:" .. tostring(action.name) .. ":wrong_stance", "[DEBUG] " .. name .. " blocked: wrong_stance", 2000) end
        return false

    end

    if action.required_form and not NS.has_form(action.required_form) then

        if debug then core_trace("action:" .. tostring(action.name) .. ":missing_form", "[DEBUG] " .. name .. " blocked: missing_form", 2000) end
        return false

    end

    if action.requires_buff and not NS.buff_up(NS.GetPlayer(), action.requires_buff) then

        if debug then core_trace("action:" .. tostring(action.name) .. ":missing_buff", "[DEBUG] " .. name .. " blocked: missing_buff", 2000) end
        return false

    end

    if action.requires_behind and not NS.is_behind_target(context.target) then

        if debug then core_trace("action:" .. tostring(action.name) .. ":not_behind", "[DEBUG] " .. name .. " blocked: not_behind", 2000) end
        return false

    end

    if action.kind == "form" and NS.has_form(action.form) then

        if debug then core_trace("action:" .. tostring(action.name) .. ":already_in_form", "[DEBUG] " .. name .. " blocked: already_in_form", 2000) end
        return false

    end

    if action.kind == "buff" and NS.buff_up(NS.GetPlayer(), action.buff or action.spell) then

        if debug then core_trace("action:" .. tostring(action.name) .. ":buff_already_up", "[DEBUG] " .. name .. " blocked: buff_already_up", 2000) end
        return false

    end

    if action.kind == "threat_drop" and not NS.should_drop_threat(context) then

        if debug then core_trace("action:" .. tostring(action.name) .. ":no_threat_drop", "[DEBUG] " .. name .. " blocked: no_threat_drop", 2000) end
        return false

    end

    if action.requires_ready_spell then

        local ready_target = action.requires_ready_target == "self" and NS.GetPlayer() or context.target

        if not ready_target or not NS.spell_ready(action.requires_ready_spell, ready_target, { expected_cooldown = action.requires_ready_cooldown }) then

            if debug then core_trace("action:" .. tostring(action.name) .. ":requires_ready_spell", "[DEBUG] " .. name .. " blocked: requires_ready_spell", 2000) end
            return false

        end

    end

    if action.target ~= "self" and action.requires_target ~= false then

        if action.target == "cc_target" then

            if not context.cc_target then

                if debug then core_trace("action:" .. tostring(action.name) .. ":no_cc_target", "[DEBUG] " .. name .. " blocked: no_cc_target", 2000) end
                return false

            end

        elseif not context.has_valid_enemy_target then

            if debug then core_trace("action:" .. tostring(action.name) .. ":no_valid_target", "[DEBUG] " .. name .. " blocked: no_valid_target", 2000) end
            return false

        end

    end

    local target = target_for(context, action)

    if action.target_not_player and target then

        local is_player = safe_field(target, "is_player")

        if is_player and safe(is_player, target) == true then

            if debug then core_trace("action:" .. tostring(action.name) .. ":target_player", "[DEBUG] " .. name .. " blocked: target_player", 2000) end
            return false

        end

    end

    if action.creature_types and target then

        local get_creature_type = safe_field(target, "get_creature_type")

        local creature_type = get_creature_type and safe(get_creature_type, target) or nil

        if not creature_type or not action.creature_types[creature_type] then

            if debug then core_trace("action:" .. tostring(action.name) .. ":creature_type", "[DEBUG] " .. name .. " blocked: creature_type=" .. tostring(creature_type), 2000) end
            return false

        end

    end

    if action.debuff and target then

        local debuff_mode = action.debuff_mode

        local refresh = action.refresh or 2

        if debuff_mode == "help_stack" then

            local max_stacks = action.max_debuff_stacks or 5

            local stacks = NS.get_debuff_stacks(target, action.debuff)

            if stacks >= max_stacks then

                if debug then core_trace("action:" .. tostring(action.name) .. ":debuff_stack_cap", "[DEBUG] " .. name .. " blocked: debuff_stack_cap=" .. tostring(stacks), 2000) end
                return false

            end

        elseif debuff_mode == "maintain" then

            local max_stacks = action.max_debuff_stacks or 5

            local stacks = NS.get_debuff_stacks(target, action.debuff)

            if stacks >= max_stacks then

                local remains = NS.debuff_remains(target, action.debuff)

                if remains > refresh then

                    if debug then core_trace("action:" .. tostring(action.name) .. ":debuff_refresh", "[DEBUG] " .. name .. " blocked: debuff_refresh=" .. tostring(remains), 2000) end
                    return false

                end

            end

        else

            local min_stacks = action.min_debuff_stacks or action.debuff_min_stacks

            if min_stacks and NS.debuff_stacks(target, action.debuff) < min_stacks then

                -- Continue to readiness checks: this action is still building a required stack window.

            else

                local remains = NS.debuff_remains(target, action.debuff)

                if remains > refresh then

                    if debug then core_trace("action:" .. tostring(action.name) .. ":debuff_refresh", "[DEBUG] " .. name .. " blocked: debuff_refresh=" .. tostring(remains), 2000) end
                    return false

                end

            end

        end

    end

    if action.requires_debuff and target and not NS.debuff_up(target, action.requires_debuff) then

        if debug then core_trace("action:" .. tostring(action.name) .. ":requires_debuff", "[DEBUG] " .. name .. " blocked: requires_debuff", 2000) end
        return false

    end

    if action.blocked_debuff and target and NS.debuff_up(target, action.blocked_debuff) then

        if debug then core_trace("action:" .. tostring(action.name) .. ":blocked_debuff", "[DEBUG] " .. name .. " blocked: blocked_debuff", 2000) end
        return false

    end

    return NS.spell_ready(action.spell, target, { skip_range = action.target == "self" or action.skip_range, skip_gcd = action.skip_gcd, expected_cooldown = action.cooldown })

end



function NS.action_execute(context, action, prefix)

    local target = target_for(context, action)

    local opts = { skip_range = action.target == "self" or action.skip_range, skip_gcd = action.skip_gcd }

    local reason = format("%s %s", prefix or "[EAX]", action.name or "Action")

    local debug = NS.get_setting and NS.get_setting("debug_system", false) or false



    if action.position then

        if action.skip_gcd then

            local id = NS.get_spell_id(action.spell)

            local position = position_for(context, action)

            if not id or not position then return false end

            -- Anti-flicker: skip if same spell was cast within 0.3s

            if _last_cast_id == id then

                local elapsed = NS.time_now() - _last_cast_time

                if elapsed < 0.3 then return false end

            end

            if not cast_position_spell(id, position, action.name or tostring(id), reason) then return false end

            mark_spell_cast(id)

            _last_action_exec[action.name] = NS.time_now()

            if debug then NS.log(reason) end

            return true

        end

        if not NS.spell_exists(action.spell) then return false end

        if NS.gcd_remains() > 0 then return false end

        return NS.try_cast_position(

            action.spell,

            position_for(context, action),

            target,

            reason,

            opts

        )

    end



    if action.skip_gcd then

        local id = NS.get_spell_id(action.spell)

        target = target or NS.GetPlayer()

        if not id or not target then return false end

        -- Anti-flicker: skip if same spell was cast within 0.3s

        if _last_cast_id == id then

            local elapsed = NS.time_now() - _last_cast_time

            if elapsed < 0.3 then return false end

        end

        if not cast_unit_spell(id, target, action.name or tostring(id), reason) then return false end

        mark_spell_cast(id)

        _last_action_exec[action.name] = NS.time_now()

        if debug then NS.log(reason) end

        return true

    end



    if not NS.spell_exists(action.spell) then return false end

    if NS.gcd_remains() > 0 then return false end

    local ok = NS.try_cast(action.spell, target, reason, opts)

    if ok then _last_action_exec[action.name] = NS.time_now() end

    return ok

end



NS.health_pct = NS.unit_health_pct

NS.get_health_pct = NS.unit_health_pct

NS.safe_call = safe



-- One-shot API probe: log spell_book availability at load time

local _sb = core.spell_book

if _sb then

    local has_learned = type(_sb.is_spell_learned) == "function" and "yes" or "no"

    local has_known = type(_sb.is_spell_known) == "function" and "yes" or "no"

    local has_has = type(_sb.has_spell) == "function" and "yes" or "no"

    NS.log("[PROBE] spell_book present | is_spell_learned=" .. has_learned .. " is_spell_known=" .. has_known .. " has_spell=" .. has_has)

else

    NS.log("[PROBE] spell_book MISSING — all spells will be treated as unknown")

end



local racial_manager_ok, racial_manager = pcall(require, "shared/racial_manager_sylvanas")

if racial_manager_ok and racial_manager and type(racial_manager.register_racial_manager) == "function" then

    racial_manager.register_racial_manager()

else

    NS.log_warning("Racial manager unavailable: " .. tostring(racial_manager))

end



local trinket_manager_ok, trinket_manager = pcall(require, "shared/trinket_manager_sylvanas")

if trinket_manager_ok and trinket_manager and type(trinket_manager.register_trinket_manager) == "function" then

    trinket_manager.register_trinket_manager()

else

    NS.log_warning("Trinket manager unavailable: " .. tostring(trinket_manager))

end



NS.log("Core runtime loaded")



--- Dump all available player information to the log.

-- Call from anywhere: NS.dump_player_info()

function NS.dump_player_info()

    local me = NS.GetPlayer and NS.GetPlayer() or nil

    if not me then NS.log("[DUMP] No local player found"); return end



    local function sf(obj, key)

        local ok, v = pcall(function() return obj[key] end)

        return ok and v or nil

    end



    NS.log("=== PLAYER DUMP ===")

    NS.log("Name: " .. tostring(sf(me, "get_name") and me:get_name() or "?"))

    NS.log("Level: " .. tostring(sf(me, "get_level") and me:get_level() or "?"))

    NS.log("Race: " .. tostring(sf(me, "get_race") and me:get_race() or "?"))

    NS.log("Class: " .. tostring(sf(me, "get_class") and me:get_class() or "?"))

    NS.log("Gender: " .. tostring(sf(me, "get_gender") and me:get_gender() or "?"))

    NS.log("HP: " .. tostring(sf(me, "get_health_percentage") and math.floor(me:get_health_percentage()) or "?") .. "%")

    NS.log("Mana: " .. tostring(sf(me, "get_mana_percentage") and math.floor(me:get_mana_percentage()) or "?") .. "%")

    NS.log("Power: " .. tostring(sf(me, "get_power") and me:get_power(0) or "?"))

    NS.log("MaxPower: " .. tostring(sf(me, "get_max_power") and me:get_max_power(0) or "?"))

    NS.log("XP: " .. tostring(sf(me, "get_xp") and me:get_xp() or "?"))

    NS.log("MapID: " .. tostring(core.get_map_id and core.get_map_id() or "?"))

    NS.log("MapName: " .. tostring(core.get_map_name and core.get_map_name() or "?"))

    NS.log("Zone: " .. tostring(pcall(core.get_zone_text) and core.get_zone_text() or "?"))

    NS.log("SubZone: " .. tostring(pcall(core.get_subzone_text) and core.get_subzone_text() or "?"))

    NS.log("InCombat: " .. tostring(sf(me, "is_in_combat") and me:is_in_combat() or "?"))

    NS.log("IsAlive: " .. tostring(sf(me, "is_alive") and me:is_alive() or "?"))

    NS.log("IsMounted: " .. tostring(sf(me, "is_mounted") and me:is_mounted() or "?"))

    NS.log("IsFlying: " .. tostring(sf(me, "is_flying") and me:is_flying() or "?"))

    NS.log("IsStealthed: " .. tostring(sf(me, "is_stealthed") and me:is_stealthed() or "?"))

    NS.log("IsMainMenuOpen: " .. tostring(core.is_main_menu_open and core.is_main_menu_open() or "?"))

    NS.log("GameVersion: " .. tostring(core.get_exact_game_version and core.get_exact_game_version() or core.get_game_version and core.get_game_version() or "?"))

    NS.log("Region: " .. tostring(core.get_game_region and core.get_game_region() or "?"))

    NS.log("Ping: " .. tostring(core.get_ping and core.get_ping() or "?") .. "ms")

    NS.log("Build: " .. tostring(core.get_build and core.get_build() or "?"))



    -- Target info

    local target = sf(me, "get_target") and me:get_target() or nil

    if target then

        NS.log("--- Target ---")

        NS.log("TargetName: " .. tostring(sf(target, "get_name") and target:get_name() or "?"))

        NS.log("TargetLevel: " .. tostring(sf(target, "get_level") and target:get_level() or "?"))

        NS.log("TargetHP: " .. tostring(sf(target, "get_health_percentage") and math.floor(target:get_health_percentage()) or "?") .. "%")

        NS.log("TargetDist: " .. tostring(sf(me, "get_distance") and me:get_distance(target) and math.floor(me:get_distance(target)) or "?") .. "yd")

        NS.log("TargetCreatureType: " .. tostring(sf(target, "get_creature_type") and target:get_creature_type() or "?"))

    end



    -- Learned spells (sample first 50)

    NS.log("--- Learned Spells (up to 50) ---")

    local sb = core.spell_book

    local count = 0

    if sb and type(sb.iterate_spells) == "function" then

        local ok, iter = pcall(sb.iterate_spells)

        if ok and type(iter) == "table" then

            for i = 1, #iter do

                if count >= 50 then break end

                count = count + 1

                NS.log("  Spell " .. tostring(count) .. ": " .. tostring(iter[i]))

            end

        end

    end

    if count == 0 then

        -- Try is_spell_learned on common spell IDs

        local common = { 3044, 13163, 2643, 883, 5384, 1499, 1130, 3045, 982, 1978, 34120 }

        for i = 1, #common do

            if count >= 50 then break end

            local known = pcall(sb.is_spell_learned, common[i]) and sb.is_spell_learned(common[i]) or false

            NS.log("  SpellID " .. tostring(common[i]) .. ": " .. tostring(known))

            count = count + 1

        end

    end



    -- Talents (if available)

    NS.log("--- Talents ---")

    if type(sb.get_talent_info) == "function" then

        local ok2, talents = pcall(sb.get_talent_info)

        if ok2 and type(talents) == "table" then

            for i = 1, math.min(#talents, 20) do

                local t = talents[i]

                if t then

                    NS.log("  Talent: " .. tostring(t.name or t.id or "?") .. " rank " .. tostring(t.rank or t.currentRank or "?"))

                end

            end

        end

    else

        NS.log("  (talent API unavailable)")

    end



    NS.log("=== END DUMP ===")

end



return NS

