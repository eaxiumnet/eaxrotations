-- trinket_manager_sylvanas.lua -- TBC trinket equip-swap + on-use activation with buff gating.
-- WHAT:   TBC trinket equip-swap + on-use activation with buff gating
-- WHEN:   called per-tick by DPS specs when trinket CD ready
-- WHY:    consolidates trinket policy across 29 specs into one source
-- SAFETY: trinket IDs DBC-verified; nil-guarded bag API
-- DECISION: consumed by specs via require(); no on_update side-effects.

local _G = _G
local NS = _G.EaxRotations
local spec_kit = require("shared/spec_kit_sylvanas")

local M = {}

-- Pattern 2: cache at load
local _core_time = _G.core and _G.core.time
local _core_spell_book = _G.core and _G.core.spell_book

local type, tostring = type, tostring
local EMPTY = {}

local DEFAULT_DEFENSIVE_HP = 40
local DEFAULT_ITEM_COOLDOWN = 120
local FRAME_CACHE_FALLBACK_MS = -1

local TRINKET_KIND_OFFENSIVE = "offensive"
local TRINKET_KIND_DEFENSIVE = "defensive"

local TRINKETS = {
    -- Offensive TBC on-use trinkets.
    [29383] = { name = "Bloodlust Brooch", kind = TRINKET_KIND_OFFENSIVE, cooldown = 120 },
    [29370] = { name = "Icon of the Silver Crescent", kind = TRINKET_KIND_OFFENSIVE, cooldown = 120 },
    [29132] = { name = "Scryer's Bloodgem", kind = TRINKET_KIND_OFFENSIVE, cooldown = 90 },
    [33829] = { name = "Hex Shrunken Head", kind = TRINKET_KIND_OFFENSIVE, cooldown = 120 },
    [32483] = { name = "The Skull of Gul'dan", kind = TRINKET_KIND_OFFENSIVE, cooldown = 120 },
    [23206] = { name = "Mark of the Champion", kind = TRINKET_KIND_OFFENSIVE, cooldown = 120 },
    [28040] = { name = "Vengeance of the Illidari", kind = TRINKET_KIND_OFFENSIVE, cooldown = 90 },
    [28121] = { name = "Icon of Unyielding Courage", kind = TRINKET_KIND_OFFENSIVE, cooldown = 120 },
    [29387] = { name = "Gnomeregan Auto-Blocker 600", kind = TRINKET_KIND_OFFENSIVE, cooldown = 120 },
    [33853] = { name = "Berserker's Call", kind = TRINKET_KIND_OFFENSIVE, cooldown = 120 },

    -- Defensive TBC on-use trinkets.
    [28528] = { name = "Moroes' Lucky Pocket Watch", kind = TRINKET_KIND_DEFENSIVE, cooldown = 120 },
    [30629] = { name = "Scarab of Displacement", kind = TRINKET_KIND_DEFENSIVE, cooldown = 120 },
    [32501] = { name = "Shadowmoon Insignia", kind = TRINKET_KIND_DEFENSIVE, cooldown = 120 },
    [34473] = { name = "Commendation of Kael'thas", kind = TRINKET_KIND_DEFENSIVE, cooldown = 120 },
    [32658] = { name = "Badge of Tenacity", kind = TRINKET_KIND_DEFENSIVE, cooldown = 120 },
}

if NS and NS.register_item_manual_cooldown then
    for item_id, entry in pairs(TRINKETS) do
        NS.register_item_manual_cooldown(item_id, entry.cooldown or DEFAULT_ITEM_COOLDOWN)
    end
end

local _registered = false
local _last_used = {}
local _slot_cache = {
    frame_ms = FRAME_CACHE_FALLBACK_MS,
    slots = { [13] = nil, [14] = nil },
}

-- Pull safe / safe_field from NS (installed by core_sylvanas.lua via
-- shared/safe_helpers_sylvanas). Local fallbacks for tests whose NS mock
-- does not supply the helpers. pcall handles NS=nil at load (some tests
-- dofile shared/ before setting _G.EaxRotations).
local safe
pcall(function() safe = NS and NS.safe end)
if type(safe) ~= "function" then
    safe = function(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, a, b = pcall(fn, ...)
        return ok and a or nil, ok and b or nil
    end
end
local safe_field
pcall(function() safe_field = NS and NS.safe_field end)
if type(safe_field) ~= "function" then
    safe_field = function(obj, key)
        if obj == nil then return nil end
        local ok, value = pcall(function() return obj[key] end)
        return ok and value or nil
    end
end

local function now_seconds()
    if NS and NS.time_now then return NS.time_now() end
    if _core_time then return _core_time() end
    return 0
end

local function now_ms()
    if NS and NS.game_time_ms then return NS.game_time_ms() end
    return now_seconds() * 1000
end

local function get_player()
    if NS and type(NS.get_player) == "function" then return NS.get_player() end
    return NS and NS.GetPlayer and NS.GetPlayer() or nil
end

local function context_or_default(override)
    if type(override) == "table" then return override end
    local context = NS and NS.GetCurrentContext and NS.GetCurrentContext() or nil
    if type(context) == "table" then return context end

    local me = get_player()
    if not me then return nil end
    local is_in_combat = safe_field(me, "is_in_combat")
    local target = NS and NS.GetTarget and NS.GetTarget() or nil
    return {
        me = me,
        target = target,
        settings = NS and NS.settings or EMPTY,
        hp = NS and NS.unit_health_pct and NS.unit_health_pct(me) or 100,
        in_combat = is_in_combat and safe(is_in_combat, me) == true or false,
        has_valid_enemy_target = target ~= nil and (not NS or not NS.is_hostile_unit or NS.is_hostile_unit(me, target) == true),
    }
end

local function setting(settings, key, default)
    if settings and settings[key] ~= nil then return settings[key] end
    if NS and NS.get_setting then return NS.get_setting(key, default) end
    return default
end

local function setting_enabled(settings, key, default)
    return setting(settings, key, default ~= false) ~= false
end

-- NOTE: We deliberately do NOT seed defaults via NS.set_setting here.
-- Early writes can trigger host save warnings. Menu widgets handle creation.

local function trinket_slots()
    local slots = NS and NS.EQUIPMENT_SLOTS or nil
    return (slots and slots.TRINKET1) or 13, (slots and slots.TRINKET2) or 14
end

local function refresh_slot_cache()
    local frame_ms = now_ms()
    if _slot_cache.frame_ms == frame_ms then return _slot_cache.slots end

    local slot1, slot2 = trinket_slots()
    _slot_cache.frame_ms = frame_ms
    _slot_cache.slots[slot1] = NS and NS.get_equipped_item_id and NS.get_equipped_item_id(slot1) or nil
    _slot_cache.slots[slot2] = NS and NS.get_equipped_item_id and NS.get_equipped_item_id(slot2) or nil
    return _slot_cache.slots
end

local function slot_enabled(settings, slot)
    local slot1, slot2 = trinket_slots()
    if slot == slot1 then return setting_enabled(settings, "use_trinket_1", true) end
    if slot == slot2 then return setting_enabled(settings, "use_trinket_2", true) end
    return false
end

local function manual_cooldown_remaining(slot, item_id, entry)
    local key = tostring(slot) .. ":" .. tostring(item_id)
    local last = _last_used[key]
    if not last then return 0 end
    local cooldown = entry and entry.cooldown or DEFAULT_ITEM_COOLDOWN
    local remaining = cooldown - (now_seconds() - last)
    return remaining > 0 and remaining or 0
end

local function item_cooldown_remaining(me, slot, item_id, entry)
    local get_item_cooldown = safe_field(me, "get_item_cooldown")
    if get_item_cooldown then
        local a, b = safe(get_item_cooldown, me, item_id)
        if type(a) == "number" and type(b) == "number" then
            local remaining = (a + b) - now_seconds()
            if remaining > 0 then return remaining end
        elseif type(a) == "number" and a > 0 then
            return a
        end
    end

    local cd_fn = _core_spell_book and _core_spell_book.get_spell_cooldown_information
    local info = safe(cd_fn, item_id)
    if type(info) == "table" then
        if info.enabled == false then return 0 end
        local start_time = tonumber(info.start_time or info.start or 0) or 0
        local duration = tonumber(info.duration or 0) or 0
        if duration > 0 then
            local remaining
            if start_time > 1000 then
                local duration_ms = duration > 1000 and duration or duration * 1000
                remaining = (start_time + duration_ms - now_ms()) / 1000
            elseif duration > 1000 then
                remaining = ((start_time * 1000) + duration - now_ms()) / 1000
            else
                remaining = start_time + duration - now_seconds()
            end
            if remaining > 0 then return remaining end
        end
    end

    return manual_cooldown_remaining(slot, item_id, entry)
end

local function trinket_ready(me, slot, item_id, entry)
    if not item_id or not entry then return false end
    if item_cooldown_remaining(me, slot, item_id, entry) > 0 then return false end

    if NS and NS.is_item_ready and NS.is_item_ready(item_id) == false then return false end
    return true
end

local function use_slot(slot, item_id, entry)
    local result
    if NS and NS.use_item_by_id then
        result = NS.use_item_by_id(item_id)
    else
        local core = (NS and NS.core) or _G.core
        local use_item = core and core.input and core.input.use_item
        if type(use_item) ~= "function" then return false end
        result = safe(use_item, item_id)
    end
    if result == false then return false end

    _last_used[tostring(slot) .. ":" .. tostring(item_id)] = now_seconds()
    if NS and NS.log then NS.log("[Trinket] " .. tostring(entry.name or item_id)) end
    return true
end

local planner = _G.EaxCooldownPlanner or (NS and NS.CooldownPlanner) or nil
local function ensure_planner()
    if planner then return planner end
    local ok, mod = pcall(require, "shared/cooldown_planner_sylvanas")
    planner = ok and mod or nil
    return planner
end

local function should_use_offensive(context, settings)
    if not setting_enabled(settings, "use_trinket_offensive", true) then return false end
    if not context.in_combat or not context.has_valid_enemy_target then return false end
    -- CD Min TTD gate: don't waste trinket CDs on dying targets
    local min_ttd = setting(settings, "cd_min_ttd", 0)
    if min_ttd > 0 and (context.ttd or 999) < min_ttd then
        return false
    end
    -- Align offensive trinkets with major CDs / Bloodlust / Drums.
    local p = ensure_planner()
    if p and p.should_fire_offensive then
        return p.should_fire_offensive(context) == true
    end
    return setting(settings, "use_trinket_offensive", true) == true
end

local function should_use_defensive(context, settings)
    if not setting_enabled(settings, "use_trinket_defensive", true) then return false end
    local threshold = setting(settings, "trinket_defensive_hp", DEFAULT_DEFENSIVE_HP) or DEFAULT_DEFENSIVE_HP
    return (context.hp or 100) < threshold
end

local function try_use_kind(context, kind)
    local me = context.me or get_player()
    if not me then return false end
    local settings = context.settings or EMPTY
    local slots = refresh_slot_cache()
    local slot1, slot2 = trinket_slots()

    for i = 1, 2 do
        local slot = i == 1 and slot1 or slot2
        if slot_enabled(settings, slot) then
            local item_id = slots[slot]
            local entry = item_id and TRINKETS[item_id] or nil
            if entry and entry.kind == kind and trinket_ready(me, slot, item_id, entry) then
                return use_slot(slot, item_id, entry)
            end
        end
    end
    return false
end

local strategies = {
    {
        name = "DefensiveTrinket",
        category = "defensive",
        matches = function(context)
            return should_use_defensive(context, context and context.settings or EMPTY)
        end,
        execute = function(context)
            return try_use_kind(context, TRINKET_KIND_DEFENSIVE)
        end,
    },
    {
        name = "OffensiveTrinket",
        category = "cooldown",
        is_burst = true,
        matches = function(context)
            return should_use_offensive(context, context and context.settings or EMPTY)
        end,
        execute = function(context)
            return try_use_kind(context, TRINKET_KIND_OFFENSIVE)
        end,
    },
}

function M.on_update(optional_context)
    if not NS then return false end
    local context = (type(optional_context) == "table" and optional_context) or context_or_default()
    if not context then return false end
    local settings = context.settings or EMPTY

    if strategies[1].matches(context) and strategies[1].execute(context) then return true end
    if setting_enabled(settings, "use_cooldowns", true) and strategies[2].matches(context) and strategies[2].execute(context) then return true end
    return false
end

function M.register_trinket_manager()
    if _registered then return true end
    if not NS or type(NS.register_on_update_callback) ~= "function" then return false end
    -- No seed_default_settings() — premature writes can cause host save warnings.
    local ok = pcall(NS.register_on_update_callback, function()
        return M.on_update()
    end)
    _registered = ok ~= false
    return _registered
end

function M.get_trinket_entry(item_id)
    return TRINKETS[item_id]
end

function M.get_equipped_trinkets()
    return refresh_slot_cache()
end

M.TRINKETS = TRINKETS
M.strategies = strategies
M.DEFAULT_DEFENSIVE_HP = DEFAULT_DEFENSIVE_HP

if NS then
    NS.TrinketManager = M
    NS.trinket_manager = M
    NS.register_trinket_manager = M.register_trinket_manager
end

_G.EaxTrinketManager = M
return M
