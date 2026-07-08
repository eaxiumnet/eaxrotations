-- interrupt_manager_sylvanas.lua -- score + queue interrupts; consume in priority order across specs.
-- WHAT:   score + queue interrupts; consume in priority order across specs
-- WHEN:   called per-tick; checks enemy casting channel + DR counter
-- WHY:    prevents interrupt starvation; spec files only request, manager arbitrates
-- SAFETY: is_interruptible() nil-guarded; bounded scan (<=8)
-- DECISION: consumed by specs via require(); no on_update side-effects.

local M = {}
local _G = _G
local NS = _G.EaxRotations

local EMPTY = {}
local INTERRUPT_REASON = "[INTERRUPT]"
local DEFAULT_INTERRUPT_PERCENT = 50

-- TBC-only fallback IDs for class spell tables that do not yet declare utility spells.
-- Newest rank first, matching class_sylvanas.lua spell-table convention.
local FALLBACK_IDS = {
    Bash = { 8983, 6798, 5211 },
    Counterspell = { 2139 },
    FeralCharge = { 16979 },
    HammerOfJustice = { 10308, 5589, 5588, 853 },
    Pummel = { 6554, 6552 },
    PsychicScream = { 10890, 10888, 8124, 8122 },
    Repentance = { 20066 },
    ScatterShot = { 19503 },
    Silence = { 15487 },
    SilencingShot = { 34490 },
    SpellLock = { 19647 },
}

-- Wind Shear is intentionally absent: it is not a TBC spell.

-- Per-cast interrupt humanization state
-- Keys are spell_id:is_channel strings; values are { jitter, detected_at, is_channel }
local _humanize_cache = {}
local _HUMANIZE_CACHE_TTL = 10 -- seconds

-- School lock tracking: guid -> school -> expiry_timestamp
local _school_locks = {}

local INTERRUPT_SCHOOL_MAP = {
    -- Counterspell (2139) is NOT listed here — its school is dynamic
    -- based on the target's current cast. See _resolve_cast_school().
    [6554]  = "physical",  -- Pummel (highest rank)
    [6552]  = "physical",  -- Pummel (lowest rank)
    [1766]  = "physical",  -- Kick
    [8042]  = "nature",    -- Earth Shock
    [19647] = "shadow",    -- Spell Lock
    [34490] = "physical",  -- Silencing Shot
    [31661] = "fire",      -- Dragon's Breath (Mage)
}

local INTERRUPT_LOCK_DURATION = {
    [2139]  = 4,
    [6554]  = 4,
    [6552]  = 4,
    [1766]  = 5,
    [8042]  = 2,
    [19647] = 3,
    [34490] = 3,
    [31661] = 3,
}

-- Counterspell (2139) locks whatever school the target is currently casting.
-- This table maps common spell IDs to their school for dynamic resolution.
local SPELL_SCHOOL_LOOKUP = {
    -- Fire
    [133]   = "fire",   [143]   = "fire",   [144]   = "fire",   [3140]  = "fire",
    [980]   = "fire",   [1014]  = "fire",   [10197] = "fire",
    [2120]  = "fire",   [2121]  = "fire",   [5857]  = "fire",   [8422]  = "fire",
    [10205] = "fire",   [10206] = "fire",   [10207] = "fire",   [10148] = "fire",
    [10149] = "fire",   [10150] = "fire",   [10151] = "fire",   [25306] = "fire",
    [27070] = "fire",   [30451] = "fire",   [11113] = "fire",   [11366] = "fire",
    [33041] = "fire",   [33042] = "fire",   [33043] = "fire",
    -- Frost
    [116]   = "frost",  [865]   = "frost",  [6143]  = "frost",  [9915]  = "frost",
    [10179] = "frost",  [10180] = "frost",  [10181] = "frost",  [10185] = "frost",
    [10186] = "frost",  [10187] = "frost",  [25304] = "frost",  [27072] = "frost",
    [38697] = "frost",  [8056]  = "frost",  [8058]  = "frost",  [10472] = "frost",
    [10473] = "frost",  [25464] = "frost",
    -- Holy
    [635]   = "holy",   [639]   = "holy",   [647]   = "holy",   [1026]  = "holy",
    [1042]  = "holy",   [3472]  = "holy",   [10328] = "holy",   [10329] = "holy",
    [25292] = "holy",   [27135] = "holy",   [27136] = "holy",
    [19750] = "holy",   [19939] = "holy",   [19940] = "holy",   [19941] = "holy",
    [19942] = "holy",   [19943] = "holy",   [27137] = "holy",
    [2060]  = "holy",   [10963] = "holy",   [10964] = "holy",   [10965] = "holy",
    [25314] = "holy",   [25210] = "holy",   [25213] = "holy",
    [2061]  = "holy",   [9472]  = "holy",   [9473]  = "holy",   [9474]  = "holy",
    [10915] = "holy",   [10916] = "holy",   [10917] = "holy",   [25233] = "holy",
    [25235] = "holy",
    -- Arcane
    [5143]  = "arcane", [5144]  = "arcane", [5145]  = "arcane", [8416]  = "arcane",
    [8417]  = "arcane", [10211] = "arcane", [10212] = "arcane", [25345] = "arcane",
    [27075] = "arcane", [38699] = "arcane",
    -- Shadow
    [594]   = "shadow", [970]   = "shadow", [992]   = "shadow", [2767]  = "shadow",
    [1079]  = "shadow", [8921]  = "shadow",
    -- Nature
    [403]   = "nature", [421]   = "nature", [943]   = "nature", [10391] = "nature",
    [10392] = "nature", [25439] = "nature",
    [5765]  = "nature", [5766]  = "nature",
    -- Physical (melee specials)
    [78]    = "physical",  [284]   = "physical",  [285]   = "physical",
}

-- Counterspell school lock IDs (for dynamic resolution)
local COUNTERSPELL_ID = 2139

-- Forward declarations (defined later but referenced earlier)
local current_cast_spell_id

--- Resolve the school of a target's current cast spell.
--- Falls back to "arcane" if the spell is unknown (safe default).
local function _resolve_cast_school(target)
    local id = current_cast_spell_id(target)
    if not id then return "arcane" end
    return SPELL_SCHOOL_LOOKUP[id] or "arcane"
end

local HEAL_CASTS = {
    [2054] = true, [2055] = true, [6063] = true, [6064] = true, [25210] = true, [25213] = true,
    [2060] = true, [10963] = true, [10964] = true, [10965] = true, [25314] = true,
    [2061] = true, [9472] = true, [9473] = true, [9474] = true, [10915] = true, [10916] = true,
    [10917] = true, [25233] = true, [25235] = true,
    [331] = true, [332] = true, [547] = true, [913] = true, [939] = true, [959] = true,
    [10395] = true, [10396] = true, [25357] = true, [25391] = true, [25396] = true,
    [8004] = true, [8008] = true, [8010] = true, [10466] = true, [10467] = true, [10468] = true, [25420] = true,
    [635] = true, [639] = true, [647] = true, [1026] = true, [1042] = true, [3472] = true,
    [10328] = true, [10329] = true, [25292] = true, [27135] = true, [27136] = true,
    [19750] = true, [19939] = true, [19940] = true, [19941] = true, [19942] = true, [19943] = true, [27137] = true,
}

local CC_CASTS = {
    [118] = true, [12824] = true, [12825] = true, [12826] = true,
    [5782] = true, [6213] = true, [6215] = true,
    [33786] = true, [339] = true, [1062] = true, [5195] = true, [5196] = true, [9852] = true, [9853] = true, [26989] = true,
    [8122] = true, [8124] = true, [10888] = true, [10890] = true,
}

local DAMAGE_CASTS = {
    [686] = true, [695] = true, [705] = true, [1088] = true, [1106] = true, [7641] = true, [11659] = true, [11660] = true, [11661] = true, [25307] = true, [27209] = true,
    [133] = true, [143] = true, [145] = true, [3140] = true, [8400] = true, [8401] = true, [8402] = true, [10148] = true, [10149] = true, [10150] = true, [10151] = true, [25306] = true, [27070] = true,
    [116] = true, [205] = true, [837] = true, [7322] = true, [8406] = true, [8407] = true, [8408] = true, [10179] = true, [10180] = true, [10181] = true, [25304] = true, [27072] = true,
    [585] = true, [591] = true, [598] = true, [984] = true, [1004] = true, [6060] = true, [10933] = true, [10934] = true, [25363] = true, [25364] = true,
    [5176] = true, [5177] = true, [5178] = true, [5179] = true, [5180] = true, [6780] = true, [8905] = true, [9912] = true, [26984] = true, [26985] = true,
    [403] = true, [529] = true, [548] = true, [915] = true, [943] = true, [6041] = true, [10391] = true, [10392] = true, [15207] = true, [15208] = true, [25448] = true, [25449] = true,
}

local safe_method
pcall(function() safe_method = NS and NS.safe_method end)
if type(safe_method) ~= "function" then
    safe_method = function(unit, method_name)
        if unit == nil then return nil end
        local fn = unit[method_name]
        if type(fn) ~= "function" then return nil end
        local ok, value = pcall(fn, unit)
        if ok then return value end
        return nil
    end
end

--- Detect whether a target is actively channeling a spell.
local function is_target_channeling(target)
    if not target then return false end
    local ch = safe_method(target, "is_channeling")
    if ch == true then return true end
    ch = safe_method(target, "is_channelling_spell")
    if ch == true then return true end
    return false
end

--- Attempt to retrieve the cast/channel start time from the target unit.
local function get_cast_start_time(target)
    if not target then return 0 end
    local st = safe_method(target, "get_cast_start_time")
    if type(st) == "number" and st > 0 then return st end
    st = safe_method(target, "get_channel_start_time")
    if type(st) == "number" and st > 0 then return st end
    st = safe_method(target, "get_active_cast_start_time")
    if type(st) == "number" and st > 0 then return st end
    return 0
end

--- Remove stale entries from the humanization cache.
function M.humanize_cleanup(now)
    if not now then now = (NS.time_now and NS.time_now()) or 0 end
    for k, v in pairs(_humanize_cache) do
        if now - v.detected_at > _HUMANIZE_CACHE_TTL then
            _humanize_cache[k] = nil
        end
    end
end

--- Returns true when the humanization jitter delay has elapsed for the current cast.
-- Generates a per-cast random delay the first time a cast is seen and caches it.
-- Channels use a different (typically longer) delay range than regular casts.
function M.humanize_interrupt_elapsed(target, settings)
    -- If humanization is explicitly disabled, pass through immediately.
    local enabled = settings and settings.interrupt_humanize_enabled
    if enabled == false then return true end

    local now = NS.time_now and NS.time_now() or 0
    M.humanize_cleanup(now)

    local current_id = current_cast_spell_id(target) or 0
    local is_channel = is_target_channeling(target)

    -- Use spell_id + channel flag as key.  Casts with the same ID within the
    -- same ~5-second window reuse jitter so a player has roughly consistent
    -- reaction time for a given spell.  If more than 5 seconds pass without
    -- seeing the spell, treat it as a new cast.
    local key = tostring(current_id) .. ":" .. tostring(is_channel)
    local state = _humanize_cache[key]

    if not state or (now - state.detected_at) > 5 then
        local min_d, max_d
        if is_channel then
            min_d = (settings and settings.interrupt_channel_jitter_min or 3) / 10
            max_d = (settings and settings.interrupt_channel_jitter_max or 8) / 10
        else
            min_d = (settings and settings.interrupt_cast_jitter_min or 0) / 10
            max_d = (settings and settings.interrupt_cast_jitter_max or 4) / 10
        end
        -- Guard: ensure max >= min
        if max_d < min_d then max_d = min_d end
        local jitter = min_d + math.random() * (max_d - min_d)
        state = {
            spell_id = current_id,
            is_channel = is_channel,
            jitter = jitter,
            detected_at = now,
        }
        _humanize_cache[key] = state
    end

    local elapsed = now - state.detected_at
    return elapsed >= state.jitter
end

function M.clear_school_locks()
    for k in pairs(_school_locks) do _school_locks[k] = nil end
end

function M.record_school_lock(target, spell_id)
    if not target or not spell_id then return end
    -- Counterspell locks the school of the spell being cast, not a fixed school
    local school
    if spell_id == COUNTERSPELL_ID then
        school = _resolve_cast_school(target)
    else
        school = INTERRUPT_SCHOOL_MAP[spell_id]
    end
    local duration = INTERRUPT_LOCK_DURATION[spell_id]
    if not school or not duration then return end
    local guid = safe_method(target, "get_guid")
    if not guid then return end
    local now = NS.time_now and NS.time_now() or 0
    local locks = _school_locks[guid]
    if not locks then
        locks = {}
        _school_locks[guid] = locks
    end
    locks[school] = now + duration
end

function M.is_school_locked(target, school)
    if not target or not school then return false end
    local guid = safe_method(target, "get_guid")
    if not guid then return false end
    local locks = _school_locks[guid]
    if not locks then return false end
    local expiry = locks[school]
    if not expiry then return false end
    local now = NS.time_now and NS.time_now() or 0
    if now >= expiry then
        locks[school] = nil
        return false
    end
    return true
end

function M.school_lock_remains(target, school)
    if not target or not school then return 0 end
    local guid = safe_method(target, "get_guid")
    if not guid then return 0 end
    local locks = _school_locks[guid]
    if not locks then return 0 end
    local expiry = locks[school]
    if not expiry then return 0 end
    local now = NS.time_now and NS.time_now() or 0
    local remaining = expiry - now
    if remaining <= 0 then
        locks[school] = nil
        return 0
    end
    return remaining
end

local function player_can_act(context)
    if not context or not context.me then return false end
    if context.is_casting or context.is_channeling then return false end
    if NS and NS.unit_alive and not NS.unit_alive(context.me) then return false end
    if NS and NS.player_control_locked and NS.player_control_locked() then return false end
    return true
end

current_cast_spell_id = function(target)
    if not target then return nil end
    -- Try documented base API first
    local id = safe_method(target, "get_active_spell_id")
    if type(id) == "number" and id > 0 then return id end
    -- Try IZI SDK combined helper
    id = safe_method(target, "get_active_cast_or_channel_id")
    if type(id) == "number" and id > 0 then return id end
    -- Fallback: undocumented aliases that some game builds still provide
    id = safe_method(target, "get_casting_spell_id")
    return type(id) == "number" and id or nil
end

-- TBC Priority Interrupt Spell List
-- Higher number = higher priority (interrupt these first)
-- Priority scale: heals=10, CC=9, Poly=9, Fear=9, big damage=8
local PRIORITY_INTERRUPT_SPELLS = {
    -- Heals (Priority 10)
    [2054] = 10, [2055] = 10, [6063] = 10, [6064] = 10, [25210] = 10, [25213] = 10, -- Heal
    [2060] = 10, [10963] = 10, [10964] = 10, [10965] = 10, [25314] = 10, -- Greater Heal
    [2061] = 10, [9472] = 10, [9473] = 10, [9474] = 10, [10915] = 10, [10916] = 10, [10917] = 10, [25233] = 10, [25235] = 10, -- Flash Heal
    [635] = 10, [639] = 10, [647] = 10, [1026] = 10, [1042] = 10, [3472] = 10, [10328] = 10, [10329] = 10, [25292] = 10, [27135] = 10, [27136] = 10, -- Holy Light
    [19750] = 10, [19939] = 10, [19940] = 10, [19941] = 10, [19942] = 10, [19943] = 10, [27137] = 10, -- Flash of Light
    [331] = 10, [332] = 10, [547] = 10, [913] = 10, [939] = 10, [959] = 10, [10395] = 10, [10396] = 10, [25357] = 10, [25391] = 10, [25396] = 10, -- Healing Wave
    [8004] = 10, [8008] = 10, [8010] = 10, [10466] = 10, [10467] = 10, [10468] = 10, [25420] = 10, -- Lesser Healing Wave
    [5185] = 10, [5186] = 10, [5187] = 10, [5188] = 10, [5189] = 10, [6778] = 10, [8938] = 10, [8939] = 10, [8940] = 10, [8941] = 10, [25297] = 10, [26980] = 10, -- Healing Touch / Regrowth
    -- CC (Priority 9)
    [118] = 9, [12824] = 9, [12825] = 9, [12826] = 9, -- Polymorph
    [5782] = 9, [6213] = 9, [6215] = 9, -- Fear
    [33786] = 9, -- Cyclone
    [2637] = 9, [18657] = 9, [18658] = 9, -- Hibernate
    [3355] = 9, [14308] = 9, [14309] = 9, -- Freezing Trap
    -- Big Damage (Priority 8)
    [133] = 8, [143] = 8, [145] = 8, [3140] = 8, [8400] = 8, [8401] = 8, [8402] = 8, [10148] = 8, [10149] = 8, [10150] = 8, [10151] = 8, [25306] = 8, [27070] = 8, -- Fireball
    [116] = 8, [205] = 8, [837] = 8, [7322] = 8, [8406] = 8, [8407] = 8, [8408] = 8, [10179] = 8, [10180] = 8, [10181] = 8, [25304] = 8, [27072] = 8, -- Frostbolt
    [686] = 8, [695] = 8, [705] = 8, [1088] = 8, [1106] = 8, [7641] = 8, [11659] = 8, [11660] = 8, [11661] = 8, [25307] = 8, [27209] = 8, -- Shadow Bolt
    [348] = 8, [707] = 8, [1099] = 8, [1100] = 8, [759] = 8, [117] = 8, [228] = 8, [188] = 8, [259] = 8, [740] = 8, [348] = 8, [1120] = 8, -- Immolate
}

--- Get base interrupt priority for spell categories (legacy interface for tests).
-- @param spell_id number - Spell ID being cast
-- @return number - Priority 1-4 (4=heal, 3=CC, 2=damage, 1=unknown)
function M.interrupt_priority(spell_id)
    if not spell_id then return 1 end
    if HEAL_CASTS[spell_id] then return 4 end
    if CC_CASTS[spell_id] then return 3 end
    if DAMAGE_CASTS[spell_id] then return 2 end
    return 1
end

--- Get spell-level interrupt priority.
-- @param spell_id number - Spell ID being cast
-- @return number - Priority 1-10 (higher = interrupt first)
function M.spell_interrupt_priority(spell_id)
    if not spell_id then return 1 end
    return PRIORITY_INTERRUPT_SPELLS[spell_id] or M.interrupt_priority(spell_id)
end

function M.cast_has_interrupt_window(target, settings)
    -- Try multiple API paths for cast progress percent
    local percent = safe_method(target, "get_cast_pct")
    if type(percent) ~= "number" then
        percent = safe_method(target, "get_channeling_or_casting_pct")
    end
    if type(percent) ~= "number" then
        percent = safe_method(target, "get_casting_percent")
    end
    -- Also try get_cast_ratio (0-1) as a fallback
    if type(percent) ~= "number" then
        local ratio = safe_method(target, "get_cast_ratio")
        if type(ratio) == "number" then percent = ratio * 100 end
    end
    if type(percent) ~= "number" then
        local ratio = safe_method(target, "get_channeling_or_casting_ratio")
        if type(ratio) == "number" then percent = ratio * 100 end
    end

    if type(percent) ~= "number" then return true end

    local threshold = settings and (settings.interrupt_cast_percent or settings.interrupt_threshold_percent) or DEFAULT_INTERRUPT_PERCENT
    if type(threshold) ~= "number" then threshold = DEFAULT_INTERRUPT_PERCENT end
    if threshold < 1 then threshold = DEFAULT_INTERRUPT_PERCENT end
    if threshold > 95 then threshold = 95 end
    return percent < threshold
end

local function required_gate(entry, context)
    local required = entry and entry.required
    if not required then return true end
    if type(required) == "number" then return context and context.stance == required end
    if type(required) == "string" then return NS and NS.has_form and NS.has_form(required) or false end
    return true
end

function M.create_interrupt_strategy(spell_entry, target_validator)
    local entry = spell_entry or EMPTY
    local spell = entry.spell or entry
    local _interrupt_id = type(spell) == "number" and spell
        or (spell and spell._meta and type(spell._meta.id) == "number" and spell._meta.id)
        or (spell and type(spell.id) == "function" and spell:id())
        or nil
    return {
        name = "Interrupt",
        matches = function(context, state)
            local settings = context and context.settings or EMPTY
            if settings.use_interrupts == false then return false end
            if not (NS and NS.try_interrupt and NS.spell_ready and NS.gcd_remains) then return false end
            if not player_can_act(context) then return false end
            if NS.gcd_remains() > 0 then return false end
            if not required_gate(entry, context) then return false end

            local target = context and context.target or nil
            if not target or not NS.try_interrupt(target) then return false end
            if target_validator and target_validator(target, context, state) == false then return false end
            if not M.cast_has_interrupt_window(target, settings) then return false end
            if not M.humanize_interrupt_elapsed(target, settings) then return false end
            if not NS.spell_ready(spell, target, { expected_cooldown = entry.cooldown }) then return false end

            local lock_school = _interrupt_id and INTERRUPT_SCHOOL_MAP[_interrupt_id]
            if lock_school and M.is_school_locked(target, lock_school) then return false end

            local cast_id = current_cast_spell_id(target)
            if state then state.interrupt_priority = M.spell_interrupt_priority(cast_id) end
            return true
        end,
        execute = function(context)
            local target = context and context.target or nil
            if not target then return false end
            if not (NS and NS.try_cast) then return false end
            local ok = NS.try_cast(spell, target, INTERRUPT_REASON, { expected_cooldown = entry.cooldown })
            if ok and _interrupt_id then M.record_school_lock(target, _interrupt_id) end
            return ok
        end,
    }
end

function M.register_interrupt_spell(class_key, spell_name, spell_table, required)
    local spells = spell_table or EMPTY
    local spell = spells[spell_name]
    if not spell and NS and NS.spell_action and FALLBACK_IDS[spell_name] then
        spell = NS.spell_action(FALLBACK_IDS[spell_name], spell_name)
        spells[spell_name] = spell
    end
    return M.create_interrupt_strategy({ class_key = class_key, name = spell_name, spell = spell, required = required })
end

if NS then
    NS.InterruptManager = M
    NS.register_interrupt_spell = M.register_interrupt_spell
    NS.create_interrupt_strategy = M.create_interrupt_strategy
end

_G.EaxInterruptManager = M
return M
