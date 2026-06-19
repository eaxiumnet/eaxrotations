-- ============================================================================
-- Shared Runtime Helper: TBC Racial Manager
-- ============================================================================
local _G = _G
local NS = _G.EaxRotations

local M = {}

local type, tostring = type, tostring
local EMPTY = {}

local RACE_ID = {
    HUMAN = 1,
    ORC = 2,
    DWARF = 3,
    NIGHT_ELF = 4,
    UNDEAD = 5,
    TAUREN = 6,
    GNOME = 7,
    TROLL = 8,
    BLOOD_ELF = 10,
    DRAENEI = 11,
}

local RACIALS = {
    [RACE_ID.ORC] = { name = "Blood Fury", spell_id = 20572, kind = "offensive", target = "self", cooldown = 120 },
    [RACE_ID.TROLL] = { name = "Berserking", spell_id = 26297, kind = "offensive", target = "self", cooldown = 180 },
    [RACE_ID.UNDEAD] = { name = "Will of the Forsaken", spell_id = 7744, kind = "cc_break", target = "self", cooldown = 120 },
    [RACE_ID.TAUREN] = { name = "War Stomp", spell_id = 20549, kind = "defensive_stun", target = "self", cooldown = 120 },
    [RACE_ID.HUMAN] = { name = "Perception", spell_id = 20600, kind = "stealth_detect", target = "self", cooldown = 180 },
    [RACE_ID.DWARF] = { name = "Stoneform", spell_id = 20594, kind = "cleanse", target = "self", cooldown = 180 },
    [RACE_ID.GNOME] = { name = "Escape Artist", spell_id = 20589, kind = "root_break", target = "self", cooldown = 105 },
    [RACE_ID.NIGHT_ELF] = { name = "Shadowmeld", spell_id = 20580, kind = "threat_drop", target = "self", cooldown = 10 },
    [RACE_ID.BLOOD_ELF] = { name = "Arcane Torrent", spell_id = 25046, kind = "offensive_utility", target = "self", cooldown = 120 },
    [RACE_ID.DRAENEI] = { name = "Gift of the Naaru", spell_id = 28880, kind = "heal", target = "self", cooldown = 180 },
}

-- High-signal TBC debuffs used as fallbacks when the runtime lacks typed aura data.
local CC_DEBUFFS = {
    5782, 6213, 6215, 8122, 8124, 10888, 10890, 5484, 17928, 6358,
    2094, 6770, 1776, 20066, 118, 12824, 12825, 12826,
}

local ROOT_SNARE_DEBUFFS = {
    122, 865, 6131, 10230, 339, 1062, 5195, 5196, 9852, 9853, 26989,
    116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304,
    1715, 7372, 7373, 25212, 2974, 14267, 14268, 3409, 11201, 25809,
}

local BLEED_DEBUFFS = {
    772, 6546, 6547, 6548, 11572, 11573, 11574, 25208,
    703, 8631, 8632, 8633, 11289, 11290, 26839,
    1943, 8639, 8640, 11273, 11274, 11275, 26867,
    1079, 9492, 9493, 9752, 9894, 9896, 27008,
}

local _race_id = false
local _registered = false
local _spell_cache = {}

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

local function get_player()
    if NS and type(NS.get_player) == "function" then return NS.get_player() end
    return NS and NS.GetPlayer and NS.GetPlayer() or nil
end

local function get_race_id()
    if _race_id ~= false then return _race_id end

    local me = get_player()
    local get_unit_race = safe_field(me, "get_race_id")
    local race = get_unit_race and safe(get_unit_race, me) or nil
    if type(race) ~= "number" then
        local core = (NS and NS.core) or _G.core
        local character = core and core.character or nil
        local get_core_race = character and character.get_race_id
        race = safe(get_core_race)
    end

    if type(race) == "number" then
        _race_id = race
        return _race_id
    end
    return nil
end

local function get_spell(entry)
    if not entry then return nil end
    local spell = _spell_cache[entry.spell_id]
    if not spell and NS and NS.spell_action then
        spell = NS.spell_action(entry.spell_id, entry.name)
        _spell_cache[entry.spell_id] = spell
    end
    return spell
end

local function setting_enabled(settings, key)
    if settings and settings[key] ~= nil then return settings[key] ~= false end
    if NS and NS.get_setting then return NS.get_setting(key, true) ~= false end
    return true
end

local function context_or_default()
    local context = NS and NS.GetCurrentContext and NS.GetCurrentContext() or nil
    if type(context) == "table" then
        local me = get_player()
        if me then
            local is_in_combat = safe_field(me, "is_in_combat")
            local live = is_in_combat and safe(is_in_combat, me)
            if type(live) == "boolean" then
                context.in_combat = live
            end
        end
        return context
    end

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
        gcd_remains = NS and NS.gcd_remains and NS.gcd_remains() or 0,
    }
end

local function has_debuff(unit, ids)
    return unit and NS and NS.debuff_up and NS.debuff_up(unit, ids) == true or false
end

local function has_control_loss(me, context)
    if context and context.player_control_locked then return true end
    if NS and NS.player_control_locked and NS.player_control_locked() == true then return true end
    return has_debuff(me, CC_DEBUFFS)
end

local function has_root_or_snare(me)
    if has_debuff(me, ROOT_SNARE_DEBUFFS) then return true end
    local is_rooted = safe_field(me, "is_rooted")
    if is_rooted and safe(is_rooted, me) == true then return true end
    local is_snared = safe_field(me, "is_snared")
    if is_snared and safe(is_snared, me) == true then return true end
    return false
end

local function has_stoneform_clear(me)
    if NS and NS.has_dispel_type_debuff then
        if NS.has_dispel_type_debuff(me, "Disease") or NS.has_dispel_type_debuff(me, "Poison") then return true end
    end
    return has_debuff(me, BLEED_DEBUFFS)
end

local function should_drop_threat(context)
    if NS and NS.should_drop_threat and NS.should_drop_threat(context) then return true end
    return context and context.in_combat and (context.hp or 100) <= 35
end

local function should_use_offensive(entry, context)
    if not setting_enabled(context.settings, "use_racial_offensive") then return false end
    if context.should_burst then return true end
    if context.settings and context.settings.use_racial_offensive == true and context.in_combat and context.has_valid_enemy_target then return true end
    return context.in_combat and context.has_valid_enemy_target and entry.kind == "offensive_utility"
end

local function should_use_defensive(entry, context, me)
    if not setting_enabled(context.settings, "use_racial_defensive") then return false end
    local hp = context.hp or (NS and NS.unit_health_pct and NS.unit_health_pct(me) or 100)
    local threshold = (context.settings and (context.settings.racial_defensive_hp or context.settings.defensive_hp)) or 35

    if entry.kind == "cc_break" then return has_control_loss(me, context) or hp <= threshold end
    if entry.kind == "root_break" then return has_root_or_snare(me) or hp <= threshold end
    if entry.kind == "cleanse" then return has_stoneform_clear(me) or hp <= threshold end
    if entry.kind == "heal" then return hp <= threshold end
    if entry.kind == "defensive_stun" then return context.in_combat and hp <= threshold and context.has_valid_enemy_target end
    if entry.kind == "stealth_detect" then return context.in_combat and context.is_pvp == true end
    if entry.kind == "threat_drop" then return should_drop_threat(context) end
    return false
end

local function should_use(entry, context, me)
    if entry.kind == "offensive" or entry.kind == "offensive_utility" then
        return should_use_offensive(entry, context)
    end
    return should_use_defensive(entry, context, me)
end

function M.get_race_id()
    return get_race_id()
end

function M.get_racial_for_race(race_id)
    return RACIALS[race_id]
end

function M.on_update()
    if not NS then return false end
    local context = context_or_default()
    if not context then return false end
    if (context.gcd_remains or 0) > 0 then return false end
    if NS.gcd_remains and NS.gcd_remains() > 0 then return false end

    local me = context.me or get_player()
    if not me then return false end
    local alive_ok, alive = pcall(function() return me:is_alive() end)
    if alive_ok and alive == false then return false end

    local entry = RACIALS[get_race_id()]
    if not entry or not should_use(entry, context, me) then return false end

    local spell = get_spell(entry)
    if not spell then return false end
    local target = entry.target == "target" and context.target or me
    return NS.try_cast and NS.try_cast(spell, target, "[Racial] " .. entry.name, { skip_range = entry.target == "self", expected_cooldown = entry.cooldown }) == true or false
end

function M.register_racial_manager()
    if _registered then return true end
    if not NS or type(NS.register_on_update_callback) ~= "function" then return false end
    local ok = NS.register_on_update_callback(function()
        return M.on_update()
    end)
    _registered = ok ~= false
    return _registered
end

if NS then
    NS.RacialManager = M
    NS.racial_manager = M
    NS.register_racial_manager = M.register_racial_manager
end

_G.EaxRacialManager = M
return M
