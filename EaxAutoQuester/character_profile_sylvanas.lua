-- character_profile_sylvanas.lua — session-scoped settings keyed by character name and realm.
-- WHAT: owns per-character gather preferences, vendor bag threshold, pull policy, and mount use;
--        a new profile seeds the four supported gathering routes from the client's learned professions.
-- WHEN: main.lua activates the profile before dispatch; menu changes are captured on the next tick.
-- WHY: one character's careful pulls and mount choice must not silently become the next character's,
--       and a learned gathering profession should not have to be enabled by hand every session.
-- SAFETY: profession discovery runs once per new profile behind pcall/type guards; unknown
--          identities or an unavailable profession surface use the manual off defaults, and nothing
--          here runs on the tick path. A one-line profession/skill-level diagnostic is logged once
--          per newly created profile (the in-game smoke check) and never on re-activation.
-- DECISION: profiles live in memory for this client session because the supported runtime has no file-write API.

local M = {}

local DEFAULT_VENDOR_THRESHOLD = 80
local DEFAULT_MIN_HP = 50
local DEFAULT_MIN_MANA = 30

-- The documented profession surface exposes two primary slots and Fishing
-- (.api/core.lua:3345). Only the four gathering professions the IDLE route can actually act on are
-- mapped; an Alchemy/Tailoring/etc. detection changes no quester behavior.
local PROFESSION_SLOT_KEYS = { "prof1", "prof2", "fishing" }
local GATHERING_PROFESSION_BY_NAME = {
    herbalism = "herbalism",
    mining = "mining",
    skinning = "skinning",
    fishing = "fishing",
}

-- Locale-proof mapping: the SkillLine ids the 2.5.5 client itself assigns to these professions.
-- These are NOT guessed and NOT copied from a wiki — they are derived from the authoritative
-- client DBC shipped in this repo (wowheadScrape/dbc_extract/wowsims.db), which has no SkillLine
-- name table but does have the ability rows that carry the id:
--
--   SELECT DISTINCT sla.SkillLine, sn.Name_lang
--   FROM SkillLineAbility sla LEFT JOIN SpellName sn ON sn.ID = sla.Spell
--   WHERE sn.Name_lang IN ('Herb Gathering','Mining','Fishing','Skinning');
--
--   Herb Gathering (2366) -> 182   Mining (2575) -> 186
--   Fishing (7620)       -> 356   Skinning (8613) -> 393
--
-- Each id carries only that profession's abilities — 182: Herb Gathering/Find Herbs; 186: Mining,
-- Find Minerals and Mining's own smelts; 356: Fishing/Fishing Poles; 393: Skinning — so no id is
-- shared with another profession and the mapping is unambiguous. GetProfessionInfo reports this
-- number as `skill_line`, which is what makes detection independent of the client's UI language.
local GATHERING_PROFESSION_BY_SKILL_LINE = {
    [182] = "herbalism",
    [186] = "mining",
    [393] = "skinning",
    [356] = "fishing",
}

-- Canonical labels, used for the diagnostic when the client returns no usable name at all.
local GATHERING_PROFESSION_LABEL = {
    herbalism = "Herbalism",
    mining = "Mining",
    skinning = "Skinning",
    fishing = "Fishing",
}

-- Hot-path API caching at module load (Pattern 2). These bindings are read once per new character,
-- never per tick, and an older build that does not expose them simply keeps the manual off defaults.
local _api = rawget(_G, "core")
local _spell_book = type(_api) == "table" and _api.spell_book or nil
local _get_professions = type(_spell_book) == "table" and _spell_book.get_professions or nil
local _get_profession_info = type(_spell_book) == "table" and _spell_book.get_profession_info or nil
local _core_log = type(_api) == "table" and _api.log or nil

-- The gathering route's free-slot reserve, per character. The bounds are the slider's own
-- (menu_sylvanas.lua), restated here so a value that arrives from anywhere else is clamped to the
-- same range rather than trusted: 0 means "never block on bag space", and the default matches the
-- loot gate's "< 4 free slots" rule so the two gates agree until the user moves this one.
local DEFAULT_GATHER_MIN_FREE_SLOTS = 4
local GATHER_MIN_FREE_SLOTS_MIN = 0
local GATHER_MIN_FREE_SLOTS_MAX = 16

local DEFAULTS = {
    vendor_threshold = DEFAULT_VENDOR_THRESHOLD,
    pull_enabled = true,
    pull_min_hp = DEFAULT_MIN_HP,
    pull_min_mana = DEFAULT_MIN_MANA,
    mount_use = true,
    gather_herbalism = false,
    gather_mining = false,
    gather_skinning = false,
    gather_fishing = false,
    gather_min_free_slots = DEFAULT_GATHER_MIN_FREE_SLOTS,
}

local _profiles = {}
local _active = nil
local _active_player = nil
local _active_menu = nil
local _name_probe_supported = nil

-- The only identity members read by this module are guarded. A mock or an older client without
-- them must not turn a settings module into a per-tick error/allocating probe.
local function unit_get_name(u) return u:get_name() end
local function unit_get_realm_name(u) return u:get_realm_name() end

local function menu_get(menu, key, fallback)
    if not menu or type(menu.get) ~= "function" then return fallback end
    local ok, value = pcall(menu.get, key, fallback)
    if ok and value ~= nil then return value end
    return fallback
end

local function menu_set(menu, key, value)
    if not menu or type(menu.set) ~= "function" then return false end
    local ok, result = pcall(menu.set, key, value)
    return ok and result ~= false
end

local function boolean_value(menu, key, fallback)
    local value = menu_get(menu, key, fallback)
    if type(value) == "boolean" then return value end
    return fallback
end

local function number_value(menu, key, fallback)
    local value = menu_get(menu, key, fallback)
    if type(value) == "number" then return value end
    return fallback
end

--- A numeric setting held inside a documented range. A widget that hands back something outside
--- it (a stale menu, a restored value from an older build) is clamped, not obeyed.
local function clamped_number_value(menu, key, fallback, min, max)
    local value = number_value(menu, key, fallback)
    if value < min then return min end
    if value > max then return max end
    return value
end

local function profession_key(value)
    if type(value) ~= "string" then return nil end
    return GATHERING_PROFESSION_BY_NAME[value:lower()]
end

--- The supported gathering profession for a client-reported skill-line id, or nil for any other
--- profession (Alchemy, Tailoring, ...) and for an id this build does not know.
local function profession_from_skill_line(value)
    if type(value) ~= "number" then return nil end
    return GATHERING_PROFESSION_BY_SKILL_LINE[value]
end

--- The human label for a profession info table. A client-supplied name is preferred for display,
--- but a recognized skill-line id supplies the canonical English label when both names are
--- missing or unreadable, so the diagnostic still identifies the profession in any locale.
local function profession_label(info, profession)
    if type(info) ~= "table" then return nil end
    if type(info.name) == "string" and info.name ~= "" then return info.name end
    if type(info.skill_line_name) == "string" and info.skill_line_name ~= "" then return info.skill_line_name end
    if profession then return GATHERING_PROFESSION_LABEL[profession] end
    return nil
end

--- Read the character's learned professions once, when a new profile is created.
--- Returns the supported-gathering table plus a one-line human summary (every present slot with
--- its skill line and skill level, then which supported professions were unlocked) for the startup
--- diagnostic. The client-reported skill-line id decides which profession a slot is, so detection
--- does not depend on the UI language; the localized name is only a fallback for a build that
--- leaves skill_line empty. A missing/older binding, a failed call, a non-table result, or an
--- unrecognized slot yields no detection and a summary that says so — the manual checkbox stays
--- authoritative.
local function detect_gathering_professions()
    local detected = {}
    if type(_get_professions) ~= "function" or type(_get_profession_info) ~= "function" then
        return detected, "API unavailable"
    end

    local ok, slots = pcall(_get_professions)
    if not ok then return detected, "API call failed" end
    if type(slots) ~= "table" then return detected, "API returned no table" end

    local reported, gathering, gathering_seen = {}, {}, {}
    for i = 1, #PROFESSION_SLOT_KEYS do
        local slot = PROFESSION_SLOT_KEYS[i]
        local index = slots[slot]
        if type(index) == "number" and index > 0 then
            local info_ok, info = pcall(_get_profession_info, index)
            local label, profession
            if info_ok and type(info) == "table" then
                -- Locale-proof first: the skill-line id the client reports decides the profession.
                -- The localized name is a fallback only, for a build that leaves skill_line empty.
                profession = profession_from_skill_line(info.skill_line)
                    or profession_key(info.name) or profession_key(info.skill_line_name)
                label = profession_label(info, profession)
            end
            if label then
                local level = info.skill_level
                if type(level) ~= "number" then level = tonumber(level) end
                local entry = slot .. "=" .. label
                if type(info.skill_line) == "number" then
                    entry = entry .. " [skill " .. tostring(info.skill_line) .. "]"
                end
                reported[#reported + 1] = entry .. (level and (" (" .. tostring(level) .. ")") or "")
                if profession and not gathering_seen[profession] then
                    gathering_seen[profession] = true
                    -- The tail names the canonical profession, so it reads the same in every locale.
                    gathering[#gathering + 1] = GATHERING_PROFESSION_LABEL[profession] or label
                    detected[profession] = true
                end
            else
                reported[#reported + 1] = slot .. "=unreadable"
            end
        end
    end

    local summary = (#reported > 0) and table.concat(reported, ", ") or "none reported"
    summary = summary .. "; gathering: "
        .. ((#gathering > 0) and table.concat(gathering, ", ") or "none")
    return detected, summary
end

local function new_values()
    local detected, profession_summary = detect_gathering_professions()
    return {
        vendor_threshold = DEFAULTS.vendor_threshold,
        pull_enabled = DEFAULTS.pull_enabled,
        pull_min_hp = DEFAULTS.pull_min_hp,
        pull_min_mana = DEFAULTS.pull_min_mana,
        mount_use = DEFAULTS.mount_use,
        gather_professions = {
            herbalism = detected.herbalism == true or DEFAULTS.gather_herbalism,
            mining = detected.mining == true or DEFAULTS.gather_mining,
            skinning = detected.skinning == true or DEFAULTS.gather_skinning,
            fishing = detected.fishing == true or DEFAULTS.gather_fishing,
        },
        gather_min_free_slots = DEFAULTS.gather_min_free_slots,
    }, profession_summary
end

local function new_record(name, realm)
    local key = name:lower()
    if realm and realm ~= "" then key = key .. "@" .. realm:lower() end
    local values, profession_summary = new_values()
    return {
        key = key,
        name = name,
        realm = realm,
        values = values,
        profession_summary = profession_summary,
    }
end

--- Emit the one-line profession diagnostic for a newly created profile. This is the startup
--- smoke-check line: exactly one per character profile, never on re-activation and never on the
--- tick path. A missing core.log simply means no line — detection itself is unaffected.
local function log_profession_diagnostic(record)
    if type(_core_log) ~= "function" or not record then return end
    local who = record.name
    if record.realm and record.realm ~= "" then who = who .. " - " .. record.realm end
    local summary = record.profession_summary
    if type(summary) ~= "string" or summary == "" then summary = "none reported" end
    pcall(_core_log, "EaxAutoQuester professions [" .. who .. "]: " .. summary)
end

local function read_identity(me)
    if not me or _name_probe_supported == false then return nil, nil end

    local ok, name = pcall(unit_get_name, me)
    if not ok or type(name) ~= "string" or name == "" then
        _name_probe_supported = false
        return nil, nil
    end
    _name_probe_supported = true

    local realm = nil
    local realm_reader = me.get_realm_name
    if type(realm_reader) == "function" then
        local realm_ok, value = pcall(realm_reader, me)
        if realm_ok and type(value) == "string" and value ~= "" then realm = value end
    end
    return name, realm
end

local function capture_values(values, menu)
    if not values or not menu then return end
    values.vendor_threshold = number_value(menu, "profile_vendor_bag_threshold", values.vendor_threshold)
    values.pull_enabled = boolean_value(menu, "pull_gate", values.pull_enabled)
    values.pull_min_hp = number_value(menu, "pull_gate_min_hp", values.pull_min_hp)
    values.pull_min_mana = number_value(menu, "pull_gate_min_mana", values.pull_min_mana)
    values.mount_use = boolean_value(menu, "profile_mount_use", values.mount_use)
    values.gather_professions.herbalism =
        boolean_value(menu, "profile_gather_herbalism", values.gather_professions.herbalism)
    values.gather_professions.mining =
        boolean_value(menu, "profile_gather_mining", values.gather_professions.mining)
    values.gather_professions.skinning =
        boolean_value(menu, "profile_gather_skinning", values.gather_professions.skinning)
    values.gather_professions.fishing =
        boolean_value(menu, "profile_gather_fishing", values.gather_professions.fishing)
    values.gather_min_free_slots = clamped_number_value(menu, "profile_gather_min_free_slots",
        values.gather_min_free_slots, GATHER_MIN_FREE_SLOTS_MIN, GATHER_MIN_FREE_SLOTS_MAX)
end

local function apply_values(values, menu)
    if not values or not menu then return end
    menu_set(menu, "profile_vendor_bag_threshold", values.vendor_threshold)
    menu_set(menu, "pull_gate", values.pull_enabled)
    menu_set(menu, "pull_gate_min_hp", values.pull_min_hp)
    menu_set(menu, "pull_gate_min_mana", values.pull_min_mana)
    menu_set(menu, "profile_mount_use", values.mount_use)
    menu_set(menu, "profile_gather_herbalism", values.gather_professions.herbalism)
    menu_set(menu, "profile_gather_mining", values.gather_professions.mining)
    menu_set(menu, "profile_gather_skinning", values.gather_professions.skinning)
    menu_set(menu, "profile_gather_fishing", values.gather_professions.fishing)
    menu_set(menu, "profile_gather_min_free_slots", values.gather_min_free_slots)
end

--- Synchronize the active character's values from the real menu surface.
--- This is intentionally scalar-only and is safe to call from the normal tick path.
function M.sync_active(menu)
    if not _active then return false end
    capture_values(_active.values, menu or _active_menu)
    return true
end

--- Activate the profile for a player, creating it with safe defaults on first sight.
--- A player without a readable name is left on the defaults; it is never assigned a shared
--- profile accidentally. A changed name/realm captures the old menu and restores the new one.
--- @param me game_object|nil
--- @param menu table|nil menu_sylvanas module
--- @return boolean changed true when a profile was created or restored
function M.activate_for(me, menu)
    if not me then return false end

    local menu_changed = _active and _active_menu ~= menu
    if _active and _active_player == me and _active_menu == menu then
        M.sync_active(menu)
        return false
    end

    local name, realm = read_identity(me)
    if not name then return false end

    if _active and _active.name == name and _active.realm == realm then
        if menu_changed then
            M.sync_active(_active_menu)
            apply_values(_active.values, menu)
        else
            M.sync_active(menu)
        end
        _active_player = me
        _active_menu = menu
        return menu_changed
    end

    if _active then M.sync_active(_active_menu) end

    local key = name:lower()
    if realm and realm ~= "" then key = key .. "@" .. realm:lower() end
    local record = _profiles[key]
    if not record then
        record = new_record(name, realm)
        _profiles[key] = record
        log_profession_diagnostic(record)
    end

    _active = record
    _active_player = me
    _active_menu = menu
    apply_values(record.values, menu)
    return true
end

--- Return the active profile's vendor bag-fullness threshold.
function M.vendor_threshold()
    if _active then return _active.values.vendor_threshold end
    return DEFAULT_VENDOR_THRESHOLD
end

--- Return whether automatic mounting is enabled for the active character.
function M.mount_use_enabled()
    if _active then return _active.values.mount_use ~= false end
    return DEFAULTS.mount_use
end

--- Return the effective gathering-profession policy for the active character: the one-time client
--- detection seeds a new profile, and the profile's checkbox is the manual override from then on.
--- IDLE owns the bounded nearby-node route; this remains the single per-profession policy answer.
function M.gathering_enabled(profession)
    if not _active or type(profession) ~= "string" then return false end
    return _active.values.gather_professions[profession] == true
end

--- Return the free bag slots the active character wants in reserve before the gathering route
--- takes another node. 0 disables the bag gate (the vendor threshold stays the backstop). The
--- value is clamped to the slider's range, so a profile restored from an older build cannot hand
--- the route a reserve the control never allowed.
function M.gather_min_free_slots()
    if not _active then return DEFAULT_GATHER_MIN_FREE_SLOTS end
    local value = _active.values.gather_min_free_slots
    if type(value) ~= "number" then return DEFAULT_GATHER_MIN_FREE_SLOTS end
    if value < GATHER_MIN_FREE_SLOTS_MIN then return GATHER_MIN_FREE_SLOTS_MIN end
    if value > GATHER_MIN_FREE_SLOTS_MAX then return GATHER_MIN_FREE_SLOTS_MAX end
    return value
end

function M.active_key()
    return _active and _active.key or nil
end

function M.active_name()
    if not _active then return nil end
    if _active.realm and _active.realm ~= "" then
        return _active.name .. " - " .. _active.realm
    end
    return _active.name
end

function M.profile_count()
    local n = 0
    for _ in pairs(_profiles) do n = n + 1 end
    return n
end

--- Clear all session profiles. Tests and an explicit future character reset use this; normal
--- character changes call activate_for instead, preserving the old character's values.
function M.reset()
    _profiles = {}
    _active = nil
    _active_player = nil
    _active_menu = nil
    _name_probe_supported = nil
end

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.character_profile = M

return M
