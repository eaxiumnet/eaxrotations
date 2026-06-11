-- shared runtime for settings, spell safety, aura helpers, healing scans, and strategy registration.

local _G = _G

local core = _G.core or {}

-- Cache version strings at module load to avoid race condition where
-- core.get_exact_game_version() returns nil during class module init
-- but becomes available later during combat.
local _cached_game_version = core.get_game_version and core.get_game_version() or nil
local _cached_exact_version = core.get_exact_game_version and core.get_exact_game_version() or nil

local NS = _G.EaxRotations or {}

_G.EaxRotations = NS

NS.core = core

-- Expansion helpers (dual-version support for TBC and Classic)
-- Normalized expansion key: "tbc" | "vanilla" | nil (unknown)
local _expansion_key = nil
local function _resolve_expansion_key()
    if _expansion_key ~= nil then return _expansion_key end
    local gv = _cached_game_version
    if not gv then
        gv = core.get_game_version and core.get_game_version()
    end
    if gv then
        local s = tostring(gv):lower()
        if s:find("vanilla") or s:find("classic") then
            _expansion_key = "vanilla"
        else
            _expansion_key = "tbc"
        end
    else
        _expansion_key = "tbc"
    end
    return _expansion_key
end

function NS.get_game_version()
    return _cached_game_version or (core.get_game_version and core.get_game_version())
end

function NS.get_exact_game_version()
    return _cached_exact_version or (core.get_exact_game_version and core.get_exact_game_version())
end

function NS.is_tbc()
    local key = _resolve_expansion_key()
    return key == "tbc" or key == nil
end

function NS.is_vanilla()
    return _resolve_expansion_key() == "vanilla"
end

function NS.get_expansion_max_level()
    if NS.is_vanilla() then return 60 end
    return 70
end

NS.runtime_generation = (NS.runtime_generation or 0) + 1

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring

local format = string.format

local floor = math.floor

local sort = table.sort

local EMPTY = {}

local _buff_db_ok, BUFF_DB = pcall(require, "common/buff_db")
if not _buff_db_ok or type(BUFF_DB) ~= "table" then BUFF_DB = {} end

-- buff_manager fallback for PS builds where unit:has_buff is broken
local _buff_manager_ok, _buff_manager = pcall(require, "common/modules/buff_manager")
if not _buff_manager_ok or type(_buff_manager) ~= "table" then _buff_manager = nil end

-- Cache lazy-loaded shared helpers at module load time to avoid repeated pcall(require) overhead in hot paths
local _reagent_guard_ok, _reagent_guard = pcall(require, "shared/reagent_guard_sylvanas")
if not _reagent_guard_ok or type(_reagent_guard) ~= "table" then _reagent_guard = nil end

local _spell_queue_ok, _spell_queue = pcall(require, "common/modules/spell_queue")
if not _spell_queue_ok or type(_spell_queue) ~= "table" then _spell_queue = nil end

-- Overheal gate wrapper — absorbs nil-guard for HealerDeficit module.
-- Returns true if the spell would overheal (should skip), false if safe to cast.
-- Vanilla files can still call NS.HealerDeficit.gate_spell_overheal directly.
---@param spell_key string Spell key in HEAL_SIZE_TBC table
---@param unit game_object Target unit
---@param call_time number Cast time in seconds
---@param settings table Settings table
---@return boolean overheal True if spell would overheal
function NS.gate_overheal(spell_key, unit, call_time, settings)
    local hd = NS.HealerDeficit
    if not hd or not hd.gate_spell_overheal then return false end
    return hd.gate_spell_overheal(spell_key, unit, call_time, settings)
end

-- cooldown_tracker: native engine-level cooldown observation (replaces enemy_cd_tracker)
local _ct_ok, _cooldown_tracker = pcall(require, "common/utility/cooldown_tracker")
if not _ct_ok or type(_cooldown_tracker) ~= "table" then _cooldown_tracker = nil end

local _settings_manager = nil

-- spell_helper: native spell readiness checks (cooldown + range + resource + facing + LOS + learned)
local _sh_ok, _spell_helper = pcall(require, "common/utility/spell_helper")
if not _sh_ok or type(_spell_helper) ~= "table" then _spell_helper = nil end

local _find_dead_ok, _find_dead_scan = pcall(require, "shared/find_dead_party_ally_sylvanas")
if not _find_dead_ok or type(_find_dead_scan) ~= "table" then _find_dead_scan = nil end

-- auto_attack_helper: native swing-timer prediction for all melee specs.
-- Replaces the manual Player:GetSwingStart()/GetSwing() polling in swing_timer_sylvanas.lua.
-- Provides per-frame-cached core_time / game_time attack prediction from the engine.
local _aa_ok, _auto_attack = pcall(require, "common/utility/auto_attack_helper")
if not _aa_ok or type(_auto_attack) ~= "table" then _auto_attack = nil end


-- pvp_helper: native PvP utilities (DR tracking, trinket detection, burst detection, CC queries).
-- Replaces the manual spell-cast-based pvp_trinket_tracker_sylvanas.lua and dr_tracker_sylvanas.lua.
-- Uses engine-level buff observation for DR/trinket/burst tracking with per-frame caching.
local _pvp_ok, _pvp_helper = pcall(require, "common/utility/pvp_helper")
if not _pvp_ok or type(_pvp_helper) ~= "table" then _pvp_helper = nil end

-- cc_data_helper: NPC CC susceptibility database (DungeonTools crowdsourced data).
-- Covers BfA through Midnight dungeons. Returns true when NPC is susceptible (default),
-- false when NPC is in the immune exception list. Use with get_npc_id() for PvE CC gating.
local _cc_ok, _cc_data = pcall(require, "common/utility/cc_data_helper")
if not _cc_ok or type(_cc_data) ~= "table" then _cc_data = nil end

-- unit_helper: native unit queries (boss/dummy detection, health+incoming damage prediction,
-- spatial enemy/ally queries, role detection, resource percentage).
-- Uses engine-level caching for performance-friendly spatial queries.
local _uh_ok, _unit_helper = pcall(require, "common/utility/unit_helper")
if not _uh_ok or type(_unit_helper) ~= "table" then _unit_helper = nil end

-- spell_sequence_helper: multi-step spell sequencer (stealth openers, burst combos).
-- Provides simple sequences (A→B→C), advanced sequences (priority loop + conditions),
-- and server-confirmed sequences (step-by-step with spell cast confirmation).
local _ss_ok, _spell_sequence = pcall(require, "common/utility/spell_sequence_helper")
if not _ss_ok or type(_spell_sequence) ~= "table" then _spell_sequence = nil end
-- SpellRankResolver: auto-resolves spell rank chains from wowhead_data
local _srr_ok, _spell_rank_resolver = pcall(require, "shared/spell_rank_resolver_sylvanas")
if _srr_ok and type(_spell_rank_resolver) == "table" then NS.SpellRankResolver = _spell_rank_resolver end

-- SpellCorpus: on-demand wowhead spell data access (get_class_spells, get_spell_info, search_spells)
local _sc_ok, _spell_corpus = pcall(require, "shared/spell_corpus_sylvanas")
if _sc_ok and type(_spell_corpus) == "table" then NS.SpellCorpus = _spell_corpus end

-- SpellFlagChecker: form-aware casting checks from wowhead_data + hardcoded TBC table
-- Exports NS.can_cast_in_form, NS.get_spell_flags, NS.is_form_restricted, NS.get_required_form
local _sfc_ok, _spell_flag_checker = pcall(require, "shared/spell_flag_checker_sylvanas")
if _sfc_ok and type(_spell_flag_checker) == "table" then NS.SpellFlagChecker = _spell_flag_checker end

-- EnemyCDTracker adapter: preserves API compatibility while delegating to native cooldown_tracker
-- Replaces EaxRotations/shared/enemy_cd_tracker_sylvanas.lua (deleted)
if _cooldown_tracker then
    NS.EnemyCDTracker = {
        has_defensive_available = function(unit)
            if not unit then return false end
            return _cooldown_tracker:has_any_relevant_defensive_up(unit) or false
        end,
        is_enemy_cd_ready = function(unit, spell_id)
            if not unit or not spell_id then return nil end
            return _cooldown_tracker:is_spell_ready(unit, spell_id)
        end,
        get_cd_remaining = function(unit, spell_id)
            if not unit or not spell_id then return nil end
            return _cooldown_tracker:get_remaining_cooldown(unit, spell_id)
        end,
        has_major_offensive_active_or_recent = function(unit, recent_seconds)
            return false  -- cooldown_tracker has no equivalent; simplified to false
        end,
        get_enemy_cds = function(unit)
            return EMPTY  -- cooldown_tracker has no equivalent; legacy API preserved
        end,
    }
end

-- Manual cooldown tracker: records last cast time per spell ID.

-- Used as a final fallback when the engine cooldown APIs return 0

-- (prevents tick-level retry spam for spells whose cooldowns aren't tracked).

local _last_action_exec = {} -- action_name -> timestamp for min_interval gating
local _last_action_exec_cleanup_time = 0
local _ACTION_EXEC_CLEANUP_INTERVAL = 300 -- 5 minutes
local _ACTION_EXEC_MAX_AGE = 600 -- 10 minutes

local _last_spell_cast = {} -- spell_id -> timestamp for cast/cooldown diagnostics
local _last_spell_cast_cleanup_time = 0
local _SPELL_CAST_CLEANUP_INTERVAL = 300 -- 5 minutes
local _SPELL_CAST_MAX_AGE = 600 -- 10 minutes

local _last_gcd_log = 0 -- throttle for spell_ready GCD log spam

local function cleanup_old_entries(cache, last_cleanup_time, cleanup_interval, max_age)
    local now = NS.time_now and NS.time_now() or 0
    if now - last_cleanup_time < cleanup_interval then return last_cleanup_time end
    for key, timestamp in pairs(cache) do
        if type(timestamp) == "number" and now - timestamp > max_age then
            cache[key] = nil
        end
    end
    return now
end

-- Spell ID resolver cache: avoids repeated is_spell_learned() calls.

-- Keys are colon-joined rank ID lists; values are { id=resolved_id, ts=timestamp }.

-- TTL is 30s; invalidated on SPELLS_CHANGED-equivalent callbacks.

local _spell_id_cache = {}

local _SPELL_ID_CACHE_TTL = 30

-- Per-spell-ID learned/unlearned result cache: avoids repeated pcall(is_spell_learned) API calls.
-- Keys are spell_id numbers; values are { result=bool, ts=timestamp }.
-- TTL is 5s; spells don't change learned status frequently during combat.
local _learned_cache = {}
local _LEARNED_CACHE_TTL = 5

-- One-shot diagnostic log tracker: prevents repeated API dump spam.

-- Keys are spell labels; once logged, won't repeat until next session.


NS.settings = NS.settings or {}

NS.class_middleware = NS.class_middleware or {}

NS.POWER_MANA, NS.POWER_RAGE, NS.POWER_FOCUS, NS.POWER_ENERGY = 0, 1, 2, 3

NS.CLASS_ID = NS.CLASS_ID or { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }

local VANILLA_HIGH_SPELL_ALLOWLIST = {

    [27799] = true, [27800] = true, [27801] = true, [27803] = true, [27804] = true, [27805] = true, -- Holy Nova ranks

    [27819] = true, -- Mana Detonation (Classic Naxxramas debuff)

    [28271] = true, [28272] = true, -- Classic Polymorph variants

    [28610] = true, -- Shadow Ward high Classic rank

    [29166] = true, -- Innervate

}

local VANILLA_TBC_SPELL_BLOCKLIST = {

    [469] = true, -- Commanding Shout

    [974] = true, -- Earth Shield

    [1329] = true, -- Mutilate

    [2825] = true, -- Bloodlust

    [3738] = true, -- Wrath of Air Totem

    [5938] = true, -- Shiv

    -- [12472] NOT blocked: 12472 = Cold Snap in Vanilla (spell_id_table.resolve("Cold Snap") returns 12472).
    -- Icy Veins (TBC-only, also 12472) is safe because no Vanilla spec file references SPELLS.IcyVeins
    -- from class_sylvanas.lua — Vanilla frost/arcane use SPELLS.ColdSnap directly.

    [20243] = true, -- Devastate

    [22570] = true, -- Maim

    [23920] = true, -- Spell Reflection

    [23575] = true, [24398] = true, -- Water Shield

    [25046] = true, -- Arcane Torrent

    [26679] = true, -- Deadly Throw

    [25289] = true, -- Battle Shout rank 8

    [25429] = true, [25431] = true, [25446] = true, [25448] = true, [25457] = true, [25467] = true,

    [25469] = true, [25472] = true, [25479] = true, [25485] = true, [25489] = true,

    [25500] = true, [25505] = true, [25552] = true, [25560] = true, [25563] = true, [25570] = true, [25574] = true,

    [26967] = true, [26968] = true, [26980] = true, [26981] = true, [26982] = true, [26983] = true,

    [26987] = true, [26988] = true, [26989] = true, [26990] = true, [26991] = true, [26992] = true, [26993] = true,

    [26994] = true, [26998] = true,

    [27131] = true, [27126] = true, [27127] = true, [27136] = true, [27137] = true, [27138] = true, [27139] = true,

    [27173] = true, [27179] = true, [30146] = true, [31016] = true, [31589] = true, [33206] = true,

    [33831] = true, [33876] = true, [33878] = true, [33891] = true,

    [34914] = true, [34916] = true, [34917] = true, [35395] = true, [36554] = true,

}

NS.current_context = NS.current_context or nil

NS._manual_item_cooldowns = NS._manual_item_cooldowns or {}

NS._last_item_use = NS._last_item_use or {}

local _settings_cache = {}

local _settings_cache_last_update = 0

local _SETTINGS_CACHE_TTL = 0.20  -- 200ms throttle (was 50ms)

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

    { 11958, 45438, 27619 }, -- Ice Block

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

-- Backward-compatible stubs: PS build API health tracking was removed
-- in v2.1.x (live TBC Classic only). These no-ops prevent crashes in
-- callers (paladin class init, warlock vanilla specs, test files).
function NS.is_api_health_broken()
    return false
end

function NS.reset_api_health()
    -- No-op: API health counters were removed.
end

--- Dumps every spell entry registered for `class_name` (e.g. "Paladin").
--- Logs the table name, each spell name, the first id that returns true from
--- NS.spell_id_is_known (or "none" if all ids are unknown), and whether the
--- spell is available at the player's current level.
--- Call as NS.dump_class_spells("Paladin") — must run after class module loads.
function NS.dump_class_spells(class_name)
    class_name = class_name or "Unknown"
    local tbl_name = class_name .. "Spells"
    local tbl = NS[tbl_name]
    if not tbl then
        NS.log("dump_class_spells: no table " .. tbl_name .. " found on NS")
        return
    end
    -- Get player level for level-appropriate reporting
    local player = NS.GetPlayer()
    local player_level = 0
    if player and type(player.get_level) == "function" then
        player_level = player:get_level() or 1
    end
    if player_level == 0 then
        -- Fallback: try izi level
        local ok, lvl = pcall(function() return player:level() end)
        if ok and lvl then player_level = lvl end
    end
    if player_level == 0 then player_level = 1 end

    NS.log("=== DUMP CLASS SPELLS: " .. class_name .. " (Player Level " .. tostring(player_level) .. ") ===")
    local known_count = 0
    local available_count = 0
    local missing_count = 0
    for key, spell in pairs(tbl) do
        if type(spell) == "table" then
            -- Read _meta.ids / _meta.levels as fallbacks before the
            -- direct spell.ids / spell.levels fields. NS.spell_action
            -- stores the rank arrays at spell._meta, so the dump must
            -- look there first to see the real level / id lists.
            local meta = spell._meta or spell
            local ids = meta.ids or spell.ids or (spell[1] and { spell[1] }) or {}
            local levels = meta.levels or spell.levels or {}
            local name = spell.name or tostring(key)
            local resolved = 0

            -- Check which rank the player qualifies for by level
            local best_rank_idx = 0
            if #levels > 0 and #ids > 0 then
                for i = #levels, 1, -1 do
                    if levels[i] and levels[i] <= player_level then
                        best_rank_idx = i
                        break
                    end
                end
            end

            -- Check if already known via API
            for _, id in ipairs(ids) do
                if NS.spell_id_is_known(id) then
                    resolved = id
                    break
                end
            end

            -- Also check via IZI (may report known when core doesn't)
            local izi_known_id = 0
            if not resolved and NS.izi then
                for _, id in ipairs(ids) do
                    local ok, learned = pcall(function()
                        local s = NS.izi.spell(id)
                        return s and s.is_learned and s:is_learned()
                    end)
                    if ok and learned then
                        izi_known_id = id
                        break
                    end
                end
            end

            if resolved ~= 0 then
                known_count = known_count + 1
                local prefix = "[KNOWN]  "
                if best_rank_idx > 0 then
                    local lvl = levels[best_rank_idx]
                    local id_by_level = ids[best_rank_idx]
                    if resolved == id_by_level then
                        NS.log("  " .. prefix .. name .. " -> id=" .. tostring(resolved) .. " (rank " .. tostring(lvl) .. ")")
                    else
                        NS.log("  " .. prefix .. name .. " -> id=" .. tostring(resolved) .. " (highest rank " .. tostring(lvl) .. " is id=" .. tostring(id_by_level) .. ")")
                    end
                else
                    NS.log("  " .. prefix .. name .. " -> id=" .. tostring(resolved))
                end
            elseif izi_known_id ~= 0 then
                known_count = known_count + 1
                NS.log("  [IZI]   " .. name .. " -> id=" .. tostring(izi_known_id) .. " (core reports unknown, IZI reports learned)")
            elseif best_rank_idx > 0 then
                available_count = available_count + 1
                local lvl = levels[best_rank_idx]
                local id_by_level = ids[best_rank_idx]
                NS.log("  [LVL " .. tostring(lvl) .. "] " .. name .. " -> id=" .. tostring(id_by_level) .. " (not yet trained)")
            else
                local next_lvl = (#levels > 0 and levels[1]) and (" (first at " .. tostring(levels[1]) .. ")") or ""
                missing_count = missing_count + 1
                NS.log("  [MISSING] " .. name .. next_lvl)
            end
        end
    end
    NS.log("=== END DUMP: " .. tostring(known_count) .. " known, " .. tostring(available_count) .. " available at level, " .. tostring(missing_count) .. " above level ===")
end

-- Per-tick player cache: same NS.time_now() value → return cached unit without pcall(is_valid).
-- Reduces ~15 pcall+is_valid calls per frame to ~1. Invalidation happens naturally each tick.
local _player_cache_tick = -1

function NS.GetPlayer()

    -- Per-tick short-circuit: if we already fetched the player this tick, return cached
    local now = NS.time_now()
    if now == _player_cache_tick and NS.PLAYER_UNIT then
        return NS.PLAYER_UNIT
    end
    _player_cache_tick = now

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

    -- Try core.object_manager.get_party_frames (valid API)

    local object_manager = core and core.object_manager or nil

    local get_party_frames = object_manager and safe_field(object_manager, "get_party_frames")

    if get_party_frames then

        local members = safe(get_party_frames)

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

    -- SECURITY: Use static buffer to avoid per-call table allocation on hot paths
    if not NS._party_fallback_buf then NS._party_fallback_buf = { n = 0 } end
    local party = NS._party_fallback_buf
    party.n = 0
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

        if type(v) == "number" and v > 0 then return v end

    end

    if type(core.game_time) == "function" then

        local v = safe(core.game_time)

        if type(v) == "number" then return v / 1000 end

    end

    local ok, ms = pcall(NS.game_time_ms)
    return ok and type(ms) == "number" and ms / 1000 or 0

end

-- Per-frame time cache for deduplicating NS.time_now() calls in the hot path.
-- When core.frame_count is unavailable the cache becomes sticky (set once,
-- never invalidated).  The primary optimization comes from context.now set
-- in build_context(), which all context-aware functions use directly.
local _cached_now = 0
local _cached_frame = -1
local function get_frame()
    return (core.frame_count and core.frame_count()) or 0
end

--- Returns the current game time in seconds, with per-frame caching.
---@param context table|nil Rotation context table (optional).  If provided
---   and context.now is set, returns that directly with zero overhead.
---   Otherwise falls back to a module-level frame cache that calls
---   NS.time_now() at most once per frame.
---@return number Current game time in seconds.
function NS.now(context)
    if context and context.now then
        return context.now
    end
    local frame = get_frame()
    if frame ~= _cached_frame then
        _cached_now = NS.time_now()
        _cached_frame = frame
    end
    return _cached_now
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

-- DEPRECATED: was a no-op passthrough with no caching. Use NS.get_setting() directly.
-- Retained as nil-safe alias for any external callers.
function NS.get_setting_cached(key, default)
    return NS.get_setting(key, default)
end

function NS.register_izi_buff_events()
    -- No-op: buff_manager handles caching internally
    return true
end

function NS.get_setting(key, default)

    -- Primary path: settings_manager with engine-level caching
    if _settings_manager then
        local v = _settings_manager:get(key)
        if v ~= nil then return v end
    end

    -- Fallback: manual cache from NS.settings table
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

    if _settings_manager then
        _settings_manager:set(key, value)
    end

end

--- Centralized helper for safe setting access from spec files.
-- Checks context.settings first, then NS.get_setting, then fallback.
-- Replaces the copy-pasted local function setting(...) in each spec.
--@param context table  Current rotation context (may be nil in tests).
--@param key     string Setting key to look up.
--@param default any    Fallback value when key is missing.
--@return any The resolved setting value.
function NS.setting(context, key, default)
    local settings = context and context.settings
    if settings and settings[key] ~= nil then return settings[key] end
    if NS.get_setting then return NS.get_setting(key, default) end
end

--- Safe number setting access. Returns the value if it's a number, otherwise the default.
--- Replaces copy-pasted local setting_number(...) functions in spec files.
---@param settings table The settings table (e.g., context.settings).
---@param key     string Setting key to look up.
---@param default number Fallback value when key is missing or value is not a number.
---@return number The resolved numeric setting value.
function NS.setting_number(settings, key, default)
    local value = settings and settings[key]
    return type(value) == "number" and value or default
end

--- Safe boolean setting access. Returns default when nil, otherwise treats non-false as true.
--- Replaces copy-pasted local setting_bool(...) functions in spec files.
---@param settings table The settings table (e.g., context.settings).
---@param key     string Setting key to look up.
---@param default boolean Fallback value when key is missing.
---@return boolean The resolved boolean setting value.
function NS.setting_bool(settings, key, default)
    local value = settings and settings[key]
    if value == nil then return default end
    return value ~= false
end

--- Looks up a setting by primary key, falling back to secondary key, then hardcoded fallback.
--- Returns the first non-nil value found, or the fallback.
---@param context   table Current rotation context.
---@param primary   string Primary setting key.
---@param secondary string Secondary setting key (fallback).
---@param fallback  any    Hardcoded default when neither key is present.
---@return any The resolved setting value.
function NS.get_any_setting(context, primary, secondary, fallback)
    local settings = context.settings or {}
    if settings[primary] ~= nil then return settings[primary] end
    if settings[secondary] ~= nil then return settings[secondary] end
    return fallback
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

--- Returns whether the spell_book API is flagged as broken.
---@return boolean broken True if we have fallen back to level-based spell IDs.
function NS.isfalse()
    return false == true
end

--- Returns true if the given spell_id was recently cast within `seconds` ago.
--- Useful for throttling strategies when aura APIs are broken and buff detection is unreliable.
---@param spell_id number The spell ID to check.
---@param seconds number Lookback window in seconds.
---@return boolean recent True if cast was recorded within the window.
function NS.recent_spell_cast(spell_id, seconds)
    if type(spell_id) ~= "number" or type(seconds) ~= "number" then return false end
    local last = _last_spell_cast[spell_id]
    if not last then return false end
    return (NS.time_now() - last) < seconds
end

--- Returns true when aura APIs are broken AND the spell was recently cast.
--- Use this at the top of maintenance matches functions to prevent infinite
--- recasts when buff/debuff detection is unreliable on private servers.
---@param spell_id number The spell ID to throttle.
---@param seconds number Lookback window in seconds (default 2.0).
---@return boolean throttled True if broken API + recent cast.
function NS.broken_api_throttled(spell_id, seconds)
    local id = spell_id
    if type(id) == "table" then
        id = NS.get_spell_id(id)
    end
    if type(id) ~= "number" then return false end
    local window = type(seconds) == "number" and seconds or 2.0
    return NS.recent_spell_cast(id, window)
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

-- Shared callback batcher: all shared modules (racial_manager, trinket_manager, ooc_manager,
-- dr_tracker, pvp_trinket_tracker, etc.) register through this function. Instead of creating
-- N separate core.register_on_update_callback calls (each a 60fps C->Lua entry point), this
-- batches them into a SINGLE core callback that fans out to all registered callbacks at ~20Hz.
--
-- Why: 5 separate 60fps C->Lua entry points each crossing the engine boundary = major overhead,
-- even if each callback body is cheap. Consolidating to one throttled dispatcher eliminates
-- 4/5 of the C->Lua crossings entirely.
local _shared_callbacks = {}
local _shared_dispatcher_registered = false
local _shared_frame_counter = 0

function NS.register_on_update_callback(callback)

    if type(callback) ~= "function" then return false end

    -- Add to shared callback table (happens before registration so the dispatcher
    -- always has at least one callback when it starts firing)
    _shared_callbacks[#_shared_callbacks + 1] = callback

    -- Register the single dispatcher once (lazy init on first caller)
    if not _shared_dispatcher_registered then

        local fn = core.register_on_update_callback

        if type(fn) ~= "function" then return false end

        local generation = NS.runtime_generation

        local function _shared_dispatcher(...)

            if generation ~= NS.runtime_generation then return false end

            -- Frame-skip: run all shared callbacks at ~20Hz (skip 2 of 3 frames)
            _shared_frame_counter = _shared_frame_counter + 1
            if _shared_frame_counter < 3 then return false end
            _shared_frame_counter = 0

            -- Fan out to all registered callbacks (all throttled together)
            for i = 1, #_shared_callbacks do
                local cb_ok, cb_err = pcall(_shared_callbacks[i], ...)
                if not cb_ok and NS.log_warning then
                    NS.log_warning("[Callback] Shared callback #" .. tostring(i) .. " error: " .. tostring(cb_err))
                end
            end
            return true

        end

        local registered_ok, registered_result = pcall(fn, _shared_dispatcher)

        -- safe() returns nil if pcall threw; ok == false means the engine
        -- rejected the registration. Try 4 more tick sources (menu / control
        -- panel / window / pre_tick) then 4 event sources (spell_cast /
        -- legit_spell_cast / combat_start / combat_end) as a last resort.
        -- Each attempt is logged via NS.log so we can see which one(s) the
        -- engine actually accepts.
        if not registered_ok or registered_result == false then
            local function _make_tick_dispatcher()
                return function(...)
                    if generation ~= NS.runtime_generation then return false end
                    _shared_frame_counter = _shared_frame_counter + 1
                    if _shared_frame_counter < 3 then return false end
                    _shared_frame_counter = 0
                    for i = 1, #_shared_callbacks do
                        local cb_ok, cb_err = pcall(_shared_callbacks[i], ...)
                        if not cb_ok and NS.log_warning then
                            NS.log_warning("[Callback] Shared callback #" .. tostring(i) .. " error: " .. tostring(cb_err))
                        end
                    end
                    return true
                end
            end
            local function _make_event_dispatcher()
                return function(...)
                    if generation ~= NS.runtime_generation then return false end
                    for i = 1, #_shared_callbacks do
                        local cb_ok, cb_err = pcall(_shared_callbacks[i], ...)
                        if not cb_ok and NS.log_warning then
                            NS.log_warning("[Callback] Shared event callback #" .. tostring(i) .. " error: " .. tostring(cb_err))
                        end
                    end
                    return true
                end
            end

            local more_sources = {
                {"render_menu",          core and core.register_on_render_menu_callback,            "tick"},
                {"render_control_panel", core and core.register_on_render_control_panel_callback,  "tick"},
                {"render_window",        core and core.register_on_render_window_callback,         "tick"},
                {"pre_tick",             core and core.register_on_pre_tick_callback,              "tick"},
                {"spell_cast",           core and core.register_on_spell_cast_callback,            "event"},
                {"legit_spell_cast",     core and core.register_on_legit_spell_cast_callback,      "event"},
                {"combat_start",         core and core.register_on_combat_start_callback,          "event"},
                {"combat_end",           core and core.register_on_combat_end_callback,            "event"},
            }

            local _ok_count = 0
            for _, _src in ipairs(more_sources) do
                local _name, _fn, _kind = _src[1], _src[2], _src[3]
                if type(_fn) == "function" then
                    local _maker = (_kind == "event") and _make_event_dispatcher or _make_tick_dispatcher
                    local _ok2, _result2 = pcall(_fn, _maker())
                    NS.log(string.format("[EaxRotations] %s-source fallback: %s=ok=%s", _kind, _name, tostring(_ok2 and _result2 ~= false)))
                    if _ok2 and _result2 ~= false then
                        _ok_count = _ok_count + 1
                    end
                else
                    NS.log(string.format("[EaxRotations] %s-source fallback: %s=skipped (not a function)", _kind, _name))
                end
            end

            if _ok_count > 0 then
                NS.log(string.format("[EaxRotations] %d tick/event sources registered -- rotation is live", _ok_count))
                _shared_dispatcher_registered = true
                return true
            end

            -- All sources failed: pop the callback we just added since registration failed
            _shared_callbacks[#_shared_callbacks] = nil
            return false
        end

        _shared_dispatcher_registered = true

    end

    return true

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

function NS.register_on_combat_start(callback)

    if type(callback) ~= "function" then return false end

    table.insert(combat_start_callbacks, callback)

    return true

end

function NS.unregister_on_combat_start(callback)

    if type(callback) ~= "function" then return false end

    for i = #combat_start_callbacks, 1, -1 do

        if combat_start_callbacks[i] == callback then

            table.remove(combat_start_callbacks, i)

            return true

        end

    end

    return false

end

function NS.register_on_combat_end(callback)

    if type(callback) ~= "function" then return false end

    table.insert(combat_end_callbacks, callback)

    return true

end

function NS.unregister_on_combat_end(callback)

    if type(callback) ~= "function" then return false end

    for i = #combat_end_callbacks, 1, -1 do

        if combat_end_callbacks[i] == callback then

            table.remove(combat_end_callbacks, i)

            return true

        end

    end

    return false

end

-- Internal: fire combat start callbacks

function NS._fire_combat_start(context)

    for _, cb in ipairs(combat_start_callbacks) do

        local ok, err = pcall(cb, context)
        if not ok and type(NS.log_warning) == "function" then
            NS.log_warning("[EaxRotations] combat_start callback error: " .. tostring(err))
        end

    end

end

-- Internal: fire combat end callbacks

function NS._fire_combat_end(context)

    for _, cb in ipairs(combat_end_callbacks) do

        local ok, err = pcall(cb, context)
        if not ok and type(NS.log_warning) == "function" then
            NS.log_warning("[EaxRotations] combat_end callback error: " .. tostring(err))
        end

    end

end

--- Create a spell action object.

-- Accepts two formats:

--   Old: NS.spell_action({id1, id2, ...}, "Name")

--   New: NS.spell_action({ name="Name", ids={...}, levels={...}, cast_time=n, cooldown=n, power_cost=n, power_type="...", school="..." })

-- @param id table|number - Spell IDs (array) or a rich config table

-- @param label string|nil - Spell name (only used in old format)

-- @return table - Spell object with _meta metadata

local function filter_spell_ids_for_expansion(ids, levels)

    if type(ids) ~= "table" then return ids, levels end

    if not (NS.is_vanilla and NS.is_vanilla()) then return ids, levels end

    local filtered_ids = {}

    local filtered_levels = type(levels) == "table" and {} or nil

    for i = 1, #ids do

        local spell_id = ids[i]

        if true then

            filtered_ids[#filtered_ids + 1] = spell_id

            if filtered_levels then filtered_levels[#filtered_levels + 1] = levels[i] end

        end

    end

    return filtered_ids, filtered_levels or levels

end

function NS.spell_action(id, label)

    local spell

    -- Detect rich format: single table arg with an "ids" or "name" key

    if type(id) == "table" and (id.ids or id.name) and not id[1] then

        local cfg = id

        local ids = type(cfg.ids) == "table" and cfg.ids or (cfg.id and { cfg.id } or {})

        local levels = cfg.levels

        ids, levels = filter_spell_ids_for_expansion(ids, levels)

        local name = cfg.name or tostring(cfg.ids or cfg.id or "")

        spell = {

            _meta = {

                id = ids,

                ids = ids,

                label = name,

                levels = levels,

                cast_time = cfg.cast_time or 0,

                cooldown = cfg.cooldown or 0,

                power_cost = cfg.power_cost or 0,

                power_type = cfg.power_type or "mana",

                school = cfg.school or "physical",

                cc_type = cfg.cc_type,  -- CC category: "fear", "charm", "sleep", "sap", "incapacitate", "stun", etc.

            }

        }

    else

        -- Old format

        local ids = type(id) == "table" and id or { id }

        ids = filter_spell_ids_for_expansion(ids)

        local lbl = label or tostring(id)

        spell = { _meta = { id = type(id) == "table" and ids or ids[1], ids = ids, label = lbl } }

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

-- Static buffer for collect_ids to avoid per-call table allocation (Pattern 4)
local _collect_buf = { n = 0, _max = 0 }

local function collect_ids(spell, out)

    if out == nil then
        _collect_buf.n = 0
        out = _collect_buf
    end
    if out.n == nil then out.n = 0 end

    if type(spell) == "number" then

        if true then out.n = out.n + 1; out[out.n] = spell end

    elseif type(spell) == "table" then

        if spell._meta then collect_ids(spell._meta.id, out)

        elseif type(spell.id) == "function" then

            local id = safe(spell.id, spell)

            if type(id) == "number" then out.n = out.n + 1; out[out.n] = id

            elseif type(id) == "table" then collect_ids(id, out) end

        elseif type(spell.id) == "number" then if true then out.n = out.n + 1; out[out.n] = spell.id end

        elseif type(spell.spell_id) == "number" then if true then out.n = out.n + 1; out[out.n] = spell.spell_id end end

        for i = 1, #spell do if type(spell[i]) == "number" then out.n = out.n + 1; out[out.n] = spell[i] end end

    end

    if out == _collect_buf then
        if _collect_buf._max then
            for i = out.n + 1, _collect_buf._max do out[i] = nil end
        end
        if out.n > (_collect_buf._max or 0) then _collect_buf._max = out.n end
    end

    return out

end

-- Track API health: if is_spell_learned returns false for many consecutive calls,

-- the spell_book API is likely broken/incompatible. Fall back to trusting IDs.

local function player_level_fallback()

    local player = NS.GetPlayer and NS.GetPlayer() or nil

    local get_effective_level = safe_field(player, "get_effective_level")

    local level = get_effective_level and safe(get_effective_level, player) or nil

    if type(level) ~= "number" then

        local get_level = safe_field(player, "get_level")

        level = get_level and safe(get_level, player) or nil

    end

    return type(level) == "number" and level or nil

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

    -- Per-spell-ID learned cache: skip expensive pcall if recently resolved
    local now = NS.time_now and NS.time_now() or 0
    local cached = _learned_cache[spell_id]
    if cached and (now - cached.ts) < _LEARNED_CACHE_TTL then
        return cached.result
    end

    local sb = core.spell_book
    if not sb then return true end

    if type(sb.is_spell_learned) == "function" then
        local ok, result = pcall(sb.is_spell_learned, spell_id)
        if not ok then
            _learned_cache[spell_id] = { result = false, ts = now }
            return false
        end
        if result then
            _learned_cache[spell_id] = { result = true, ts = now }
            return true
        end
    end

    -- Fallback to is_spell_known
    if type(sb.is_spell_known) == "function" and safe(sb.is_spell_known, spell_id) == true then
        _learned_cache[spell_id] = { result = true, ts = now }
        return true
    end

    if type(sb.has_spell) == "function" and safe(sb.has_spell, spell_id) == true then
        _learned_cache[spell_id] = { result = true, ts = now }
        return true
    end

    _learned_cache[spell_id] = { result = false, ts = now }
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
        for i = 1, #ids do
            if NS.spell_id_is_known(ids[i]) then
                _spell_id_cache[cache_key] = { id = ids[i], ts = NS.time_now and NS.time_now() or 0 }
                return ids[i]
            end
        end
    end

    -- No spell ID resolved — not known
    return nil

end

function NS.refresh_spell_cache()

    for k in pairs(_spell_id_cache) do _spell_id_cache[k] = nil end
    for k in pairs(_learned_cache) do _learned_cache[k] = nil end

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
    if false then return true end
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

function NS.cooldown_remains(spell, expected_cooldown)
    local id = type(spell) == "number" and spell or NS.get_spell_id(spell)
    if not id then return 0 end

    -- Primary: spell_helper cooldown API
    if _spell_helper then
        local ok_cd, cd_remaining = pcall(_spell_helper.get_spell_cooldown, _spell_helper, id)
        if type(cd_remaining) == "number" and cd_remaining > 0 then
            return cd_remaining
        end
    end

    -- Fallback: engine cooldown information
    local info_fn = core.spell_book and core.spell_book.get_spell_cooldown_information
    local info = id and safe(info_fn, id) or nil
    if type(info) == "table" and info.enabled ~= false then
        local start_time = tonumber(info.start_time or info.start or 0) or 0
        local duration = tonumber(info.duration or 0) or 0
        if duration > 0 then
            local now_ms = NS.game_time_ms()
            local now_seconds = NS.time_now()
            local remaining
            if duration >= 600 then
                -- Long cooldowns (10+ min): duration in seconds, start_time in seconds
                remaining = start_time + duration - now_seconds
            elseif start_time > 1e7 then
                -- Large timestamps: start_time in ms, duration in ms, convert to s
                remaining = (start_time + duration - now_ms) / 1000
            else
                -- Small offsets: both in seconds
                remaining = start_time + duration - now_seconds
            end
            if remaining > 0 then return remaining end
        end
    end

    -- Final fallback: manual cast-history throttle
    local last_cast = _last_spell_cast[id]
    if not last_cast then return 0 end
    if expected_cooldown then
        local prev = _last_spell_cast["_max_throttle_" .. id]
        if not prev or expected_cooldown > prev then
            _last_spell_cast["_max_throttle_" .. id] = expected_cooldown
        end
    end
    local buffer = false and 0.15 or 1.0
    local throttle = (expected_cooldown or _last_spell_cast["_max_throttle_" .. id] or 1.5) + buffer
    local elapsed = NS.time_now() - last_cast
    if elapsed < throttle then return throttle - elapsed end
    return 0
end


-- Manual cast-history cooldown fallback is now inlined into NS.cooldown_remains.
-- This variable is kept to avoid nil-reference errors from any remaining call sites.
_last_cast_time_cooldown = function() return nil end

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



function NS.is_spell_in_range(spell, target)
    if not target then return true end
    local id = NS.get_spell_id(spell)
    if not id then return true end
    if _spell_helper then
        local ok_range, in_range = pcall(_spell_helper.is_spell_in_range, _spell_helper, id, target, nil, nil)
        if ok_range and in_range == true then return true end
    end
    -- Fallback: basic distance check
    local me = NS.GetPlayer()
    if not me then return true end
    local d = safe_field(target, "distance_to")
    if d then
        local dist = safe(d, target, me)
        if type(dist) == "number" then return dist <= 45 end
    end
    return true
end

NS.spell_in_range = NS.is_spell_in_range

local function spell_helper_castable(id, target, opts)
    local caster = NS.GetPlayer()
    if not caster or not target then return false end
    local ok, castable = pcall(
        _spell_helper.is_spell_castable,
        _spell_helper,
        id,
        caster,
        target,
        opts.skip_facing == true,
        opts.skip_range == true,
        opts.skip_usable == true,
        opts.skip_controller == true,
        opts.skip_learned == true
    )
    return ok and castable == true
end

function NS.spell_ready(spell, target, opts)

    opts = opts or EMPTY


    local label = spell_label(spell)

    -- Spell existence check
    if not NS.spell_exists(spell) then
        return false
    end

    -- GCD check (manual fallback for PS builds where engine GCD API is broken)
    local gcd = NS.gcd_remains()
    if not opts.skip_gcd and gcd <= 0 then
        local global_gcd = _last_spell_cast["_global_gcd"]
        if global_gcd then
            local manual_gcd = 1.5 + 0.15 - (NS.time_now() - global_gcd)
            if manual_gcd > 0 then gcd = manual_gcd end
        end
    end
    if not opts.skip_gcd and gcd > 0 then
        if (NS.time_now() - _last_gcd_log) > 1 then
            _last_gcd_log = NS.time_now()
        end
        return false
    end

    -- Primary: spell_helper does cooldown + resource + range + facing + LOS in one call
    local id = NS.get_spell_id(spell)
    if id and _spell_helper and not false then
        return spell_helper_castable(id, target, opts)
    end

    -- Fallback: manual cooldown + range checks
    local cd = NS.cooldown_remains(spell, opts.expected_cooldown)
    if cd > 0 then
        return false
    end

    if not opts.skip_range and target and NS.not_same_unit(target, NS.GetPlayer()) and not NS.is_spell_in_range(spell, target) then
        return false
    end

    return true

end

local function mark_spell_cast(id)
    _last_spell_cast_cleanup_time = cleanup_old_entries(_last_spell_cast, _last_spell_cast_cleanup_time, _SPELL_CAST_CLEANUP_INTERVAL, _SPELL_CAST_MAX_AGE)
    _last_spell_cast[id] = NS.time_now()
    _last_spell_cast["_global_gcd"] = _last_spell_cast[id]
end

-- ============================================================================
-- Central Cast Guard
-- ============================================================================
-- Central Cast Guard -- consolidate all pre-cast checks
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
        return false
    end
    local label = spell_label(spell, id)
    local target = unit or NS.GetPlayer()
    -- Dead check: don't cast while dead
    local me = NS.GetPlayer()
    if me then
        local alive_ok, alive = pcall(function() return me:is_alive() end)
        if alive_ok and alive == false then return false end
    end
    -- 1. Primary: spell_helper native gate (cooldown + range + resource + facing + LOS + learned)
    if id and _spell_helper and not false then
        if not spell_helper_castable(id, target, opts) then return false end
    else
        -- Fallback: NS.spell_ready when spell_helper unavailable
        if not NS.spell_ready(spell, target, opts) then
            return false
        end
    end

    -- 2. Anti-flicker: skip if same spell was cast within 0.3s
    local last_cast = _last_spell_cast[id]
    if last_cast then
        local elapsed = NS.time_now() - last_cast
        if elapsed < 0.3 then
            return false
        end
    end

    -- 3. Min interval check
    local min_interval = opts.min_interval
    if type(min_interval) == "number" and min_interval > 0 then
        local last_cast_entry = _last_spell_cast[id]
        local elapsed = last_cast_entry and (NS.time_now() - last_cast_entry) or nil
        if elapsed and elapsed < min_interval then
            return false
        end
    end

    -- 4. Reagent guard (Eax-specific module)
    local reagent_guard = _reagent_guard
    if reagent_guard and reagent_guard.check_reagent then
        if not reagent_guard.check_reagent(id) then
            return false
        end
    end

    -- 5. Target immunity gating (Divine Shield, Ice Block, Blessing of Protection)
    if not opts.skip_immunity_check and target and NS.not_same_unit(target, NS.GetPlayer()) then
        local has_divine_shield = NS.buff_up(target, {642, 1020})
        local has_ice_block = NS.buff_up(target, {27619, 45438})
        local has_bop = NS.buff_up(target, {1022, 5599, 10278})
        if has_divine_shield or has_ice_block then
            return false
        end
        if has_bop then
            local spell_school = type(spell) == "table" and spell._meta and spell._meta.school or nil
            if spell_school == "physical" then
                return false
            end
        end

        -- 5b. Cloak of Shadows (31224): immune to all magic for 5s
        local has_cloak = NS.buff_up(target, {31224})
        if has_cloak then
            local spell_school = type(spell) == "table" and spell._meta and spell._meta.school or nil
            if spell_school and spell_school ~= "physical" then
                return false
            end
        end

        -- 5c. Will of the Forsaken (7744): immune to fear/charm/sleep for 5s
        local has_wotf = NS.buff_up(target, {7744})
        if has_wotf then
            local cc_type = type(spell) == "table" and spell._meta and spell._meta.cc_type or nil
            if cc_type and (cc_type == "fear" or cc_type == "charm" or cc_type == "sleep") then
                return false
            end
        end

        -- 5d. Berserker Rage (18499): immune to fear/sap/incapacitate for 10s
        local has_berserker_rage = NS.buff_up(target, {18499})
        if has_berserker_rage then
            local cc_type = type(spell) == "table" and spell._meta and spell._meta.cc_type or nil
            if cc_type and (cc_type == "fear" or cc_type == "sap" or cc_type == "incapacitate") then
                return false
            end
        end
    end

    -- 6. Player casting/channeling guard: don't queue casts while already casting
    --    or channeling. Use pcall for API safety (nil me, missing methods).
    --    Opt-out via opts.skip_casting for callers that need to queue while casting.
    if not opts.skip_casting then
        local me = NS.GetPlayer()
        if me then
            local cast_ok, is_casting = pcall(function() return me:is_casting_spell() end)
            local chan_ok, is_channeling = pcall(function() return me:is_channelling_spell() end)
            if (cast_ok and is_casting) or (chan_ok and is_channeling) then
                return false
            end
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
            return false
        end
    end

    if not id then
        return false
    end



    -- Central cast guard: cooldown + resource + range + anti-flicker + min_interval + reagent + immunity
    if not NS.evaluate_cast(spell, unit, reason, opts) then
        return false
    end

    NS.sticky_spell_should_override(id, reason or "unknown", 0)

    -- Primary backend: spell_queue (shared plugin queue — avoids conflicts with other plugins)
    local spell_queue = _spell_queue
    if spell_queue and type(spell_queue.queue_spell_target) == "function" then
        local queued = spell_queue:queue_spell_target(id, target, 1, label, false)
        if queued == false then
            return false
        end
        mark_spell_cast(id)
        return true
    end

    -- IZI primary: try IZI before cast_unit_spell global
    if NS.izi and type(NS.izi.spell) == "function" then
        local izi_spell = NS.izi.spell(id)
        if izi_spell and type(izi_spell.cast_safe) == "function" then
            local ok = izi_spell:cast_safe(target, reason) == true
            if ok then
                mark_spell_cast(id)
                return true
            end
        end
        -- IZI returned nil/false — fall through to raw core.input.cast_target_spell
    end

    -- Fallback: direct core.input.cast_target_spell
    local cast = core.input and core.input.cast_target_spell
    if type(cast) == "function" then
        if safe(cast, id, target) == false then
            return false
        end
    else
        return false
    end

    mark_spell_cast(id)



    return true

end

function NS.try_cast_position(spell, position, range_target, reason, opts)

    opts = opts or EMPTY

    local id = NS.get_spell_id(spell)

    local label = spell_label(spell, id)

    if not id or not position then
        return false
    end

    -- Position casts use the same central guard as unit casts
    if not NS.evaluate_cast(spell, range_target, reason, opts) then
        return false
    end

    -- Primary: spell_queue position casting
    local spell_queue = _spell_queue
    if spell_queue and type(spell_queue.queue_spell_position) == "function" then
        local queued = spell_queue:queue_spell_position(id, position, 1, label, false)
        if queued ~= false then
            mark_spell_cast(id)
            return true
        else
        end
    end

    -- Fallback: direct core.input.cast_position_spell
    local cast_pos = core.input and core.input.cast_position_spell
    if type(cast_pos) == "function" then
        if safe(cast_pos, id, position) == false then
            return false
        end
    else
        return false
    end

    mark_spell_cast(id)


    return true

end

NS.cast_position = NS.try_cast_position

-- ============================================================================
-- AoE Cast Position Optimization (spell_prediction bridge)
-- ============================================================================

--- Computes the optimal ground-target position for circular AoE spells.
--- Uses the platform spell_prediction module (MOST_HITS mode) when available;
--- falls back to the target's raw position otherwise.
---@param spell_id number The spell ID to optimize position for.
---@param target game_object The target unit (reference position + range check).
---@param radius number The spell's AoE radius in yards (e.g., 8 for Blizzard).
---@param max_range number The spell's maximum cast range in yards (default 35).
---@return vec3|nil position The optimal cast position, or nil if unavailable.
function NS.get_aoe_cast_position(spell_id, target, radius, max_range)
    if not spell_id or not target then return nil end
    local spell_prediction = NS.GetAPIModule and NS.GetAPIModule("spell_prediction") or nil
    if not spell_prediction then
        local get_position = target.get_position
        return get_position and target:get_position() or nil
    end
    local ok, pos = pcall(function()
        local pred = spell_prediction.prediction_type
        local geom = spell_prediction.geometry_type
        local spell_data = spell_prediction:new_spell_data(
            spell_id,
            max_range or 35,
            radius or 8,
            nil,
            nil,
            pred.MOST_HITS,
            geom.CIRCLE,
            nil
        )
        local get_pos = target.get_position
        local target_pos = get_pos and target:get_position() or nil
        if not target_pos then return nil end
        local result = spell_prediction:get_most_hits_position(
            target_pos,
            spell_data,
            target
        )
        return result and result.cast_position or nil
    end)
    if ok and pos then return pos end
    local get_position = target.get_position
    return get_position and target:get_position() or nil
end

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

-- ============================================================================
-- Auto-Attack / Swing Timer Wrappers (auto_attack_helper bridge)
-- ============================================================================

-- Attack type constants for start_auto_attack / stop_auto_attack.
NS.AUTO_ATTACK_MELEE = 6603
NS.AUTO_ATTACK_RANGED = 75
NS.AUTO_ATTACK_WAND = 5019

function NS.swing_time_until(unit, weapon)
    if not _auto_attack or not unit then return 999 end
    local next_time = _auto_attack:get_next_attack_core_time(unit, weapon)
    local now = _auto_attack:get_current_combat_core_time()
    if next_time and now and next_time > now then return next_time - now end
    return 0
end

function NS.swing_time_since(unit)
    if not _auto_attack or not unit then return 0 end
    local last = _auto_attack:get_last_attack_core_time(unit)
    local now = _auto_attack:get_current_combat_core_time()
    if last and now then return math.max(0, now - last) end
    return 0
end

function NS.swing_progress(unit, weapon)
    if not _auto_attack or not unit then return 0 end
    local next_time = _auto_attack:get_next_attack_core_time(unit, weapon)
    local last_time = _auto_attack:get_last_attack_core_time(unit)
    local now = _auto_attack:get_current_combat_core_time()
    if not last_time or not next_time or next_time <= last_time then return 0 end
    local elapsed = now - last_time
    local total = next_time - last_time
    if total <= 0 then return 0 end
    return math.min(1, math.max(0, elapsed / total))
end

function NS.is_auto_attacking(unit)
    if not _auto_attack or not unit then return false end
    return _auto_attack:is_auto_attacking(unit) == true
end

function NS.start_auto_attack(target, attack_type)
    if not _auto_attack or not target then return false end
    return _auto_attack:start_attack(target, attack_type or NS.AUTO_ATTACK_MELEE) == true
end

function NS.stop_auto_attack(target, attack_type)
    if not _auto_attack or not target then return false end
    return _auto_attack:stop_attack(target, attack_type or NS.AUTO_ATTACK_MELEE) == true
end

-- ============================================================================
-- PvP Utility Wrappers (pvp_helper bridge)
-- ============================================================================

-- PvP helper version info for compatibility checks.
NS.PVP_IS_TBC = _pvp_helper and _pvp_helper.is_tbc == true

-- Expose CC flag constants for use with pvp_is_cc_immune / pvp_get_dr_count.
NS.PVP_CC_FLAGS = _pvp_helper and _pvp_helper.cc_flags or {}
NS.PVP_DR_CATEGORIES = _pvp_helper and _pvp_helper.dr_categories or {}

--- Time (seconds) since the target last used their PvP trinket.
--- Returns 9999 if never used or module unavailable.
---@param unit game_object The target unit.
---@return number seconds Time since last trinket use.
function NS.pvp_trinket_time_since(unit)
    if not _pvp_helper or not unit then return 9999 end
    local ok, v = pcall(_pvp_helper.time_since_last_trinket, _pvp_helper, unit)
    return ok and type(v) == "number" and v or 9999
end

--- Returns true if the target used their PvP trinket within window seconds.
---@param unit game_object The target unit.
---@param window number Lookback window in seconds (default 120 = 2 min cooldown).
---@return boolean used_recently True if trinket was used within the window.
function NS.pvp_trinket_used_recently(unit, window)
    if not _pvp_helper or not unit then return false end
    local w = type(window) == "number" and window or 120
    local ok, v = pcall(_pvp_helper.trinket_used_within, _pvp_helper, unit, w)
    return ok and v == true
end

--- Returns the core.time() timestamp of the targets last PvP trinket use, or 0.
---@param unit game_object The target unit.
---@return number timestamp Last trinket use time.
function NS.pvp_trinket_last_time(unit)
    if not _pvp_helper or not unit then return 0 end
    local ok, v = pcall(_pvp_helper.get_last_trinket_time, _pvp_helper, unit)
    return ok and type(v) == "number" and v or 0
end

--- Returns true if the target has an offensive burst buff active.
---@param unit game_object The target unit.
---@param min_remaining_ms number|nil Minimum remaining duration in ms (default 0).
---@return boolean bursting True if burst buff is active.
function NS.pvp_has_burst_active(unit, min_remaining_ms)
    if not _pvp_helper or not unit then return false end
    local ok, v = pcall(_pvp_helper.has_burst_active, _pvp_helper, unit, min_remaining_ms or nil)
    return ok and v == true
end

--- Returns whether the target is currently crowd controlled.
--- Returns is_ccd, cc_flag, remaining_ms
---@param unit game_object The target unit.
---@param type_flags number|nil CC type bitmask to filter (nil = any CC).
---@param min_remaining_ms number|nil Minimum remaining duration in ms.
---@return boolean is_ccd True if unit is crowd controlled.
---@return number|nil cc_flag The CC flag of the active CC.
---@return number|nil remaining_ms Remaining CC duration in ms.
function NS.pvp_is_crowd_controlled(unit, type_flags, min_remaining_ms)
    if not _pvp_helper or not unit then return false, nil, nil end
    local ok, is_cc, cc_flag, remaining = pcall(_pvp_helper.is_crowd_controlled, _pvp_helper, unit, type_flags or nil, min_remaining_ms or nil, nil)
    if ok then return is_cc == true, cc_flag, remaining end
    return false, nil, nil
end

--- Returns the DR count (0-3) for a CC category on the target.
---@param unit game_object The target unit.
---@param cc_flag number The CC flag (from pvp_helper.cc_flags or dr_categories).
---@return number dr_count DR count (0 = no DR, 3 = immune).
function NS.pvp_get_dr_count(unit, cc_flag)
    if not _pvp_helper or not unit or not cc_flag then return 0 end
    local ok, v = pcall(_pvp_helper.get_unit_dr, _pvp_helper, unit, cc_flag, 0)
    return ok and type(v) == "number" and v or 0
end

--- Returns true if the target is immune to the given CC category via DR.
---@param unit game_object The target unit.
---@param cc_flag number The CC flag to check immunity for.
---@return boolean immune True if target is DR-immune to this CC.
function NS.pvp_is_cc_immune(unit, cc_flag)
    return NS.pvp_get_dr_count(unit, cc_flag) >= 3
end

--- Returns true if the target is in an immune CC state (Cyclone, Banish, etc.)
--- where heals will not land.
---@param unit game_object The target unit.
---@param min_remaining_ms number|nil Minimum remaining duration in ms.
---@return boolean immune True if target is immune to heals.
function NS.pvp_is_heal_immune(unit, min_remaining_ms)
    if not _pvp_helper or not unit then return false end
    local ok, is_immune = pcall(_pvp_helper.is_immune_to_heal, _pvp_helper, unit, min_remaining_ms or nil)
    return ok and is_immune == true
end

--- Returns true if the unit is an enemy player (not NPC).
---@param unit game_object The unit to check.
---@return boolean is_player True if unit is a player.
function NS.pvp_is_player(unit)
    if not _pvp_helper or not unit then return false end
    local ok, v = pcall(_pvp_helper.is_player, _pvp_helper, unit)
    return ok and v == true
end

-- ============================================================================
-- PvE CC Immunity Wrappers (cc_data_helper bridge)
-- ============================================================================

--- Helper: get NPC ID from a unit. Returns nil if unit is not an NPC.
---@param unit game_object The target unit.
---@return number|nil npc_id The NPC ID, or nil.
function NS.cc_get_npc_id(unit)
    if not unit then return nil end
    local ok, id = pcall(function() return unit:get_npc_id() end)
    return (ok and type(id) == "number" and id > 0) and id or nil
end

function NS.cc_is_stunnable(unit)
    local id = NS.cc_get_npc_id(unit)
    if not id or not _cc_data then return true end
    return _cc_data:is_stunnable(id) ~= false
end

function NS.cc_is_rootable(unit)
    local id = NS.cc_get_npc_id(unit)
    if not id or not _cc_data then return true end
    return _cc_data:is_rootable(id) ~= false
end

function NS.cc_is_fearable(unit)
    local id = NS.cc_get_npc_id(unit)
    if not id or not _cc_data then return true end
    return _cc_data:is_fearable(id) ~= false
end

---@param unit game_object The target unit.
---@return boolean polymorphable True if NPC is polymorphable.
function NS.cc_is_polymorphable(unit)
    local id = NS.cc_get_npc_id(unit)
    if not id or not _cc_data then return true end
    return _cc_data:is_polymorphable(id, unit) ~= false
end

function NS.cc_is_sappable(unit)
    local id = NS.cc_get_npc_id(unit)
    if not id or not _cc_data then return true end
    return _cc_data:is_sappable(id, unit) ~= false
end

function NS.cc_is_banishable(unit)
    local id = NS.cc_get_npc_id(unit)
    if not id or not _cc_data then return true end
    return _cc_data:is_banishable(id, unit) ~= false
end

function NS.cc_is_tauntable(unit)
    local id = NS.cc_get_npc_id(unit)
    if not id or not _cc_data then return true end
    return _cc_data:is_tauntable(id) ~= false
end

function NS.cc_is_silenceable(unit)
    local id = NS.cc_get_npc_id(unit)
    if not id or not _cc_data then return true end
    return _cc_data:is_silenceable(id) ~= false
end

function NS.cc_is_disorientable(unit)
    local id = NS.cc_get_npc_id(unit)
    if not id or not _cc_data then return true end
    return _cc_data:is_disorientable(id) ~= false
end

function NS.cc_is_incapacitateable(unit)
    local id = NS.cc_get_npc_id(unit)
    if not id or not _cc_data then return true end
    return _cc_data:is_incapacitateable(id) ~= false
end

function NS.cc_is_slowable(unit)
    local id = NS.cc_get_npc_id(unit)
    if not id or not _cc_data then return true end
    return _cc_data:is_slowable(id) ~= false
end

function NS.cc_is_knockable(unit)
    local id = NS.cc_get_npc_id(unit)
    if not id or not _cc_data then return true end
    return _cc_data:is_knockable(id) ~= false
end

function NS.cc_is_grippable(unit)
    local id = NS.cc_get_npc_id(unit)
    if not id or not _cc_data then return true end
    return _cc_data:is_grippable(id) ~= false
end

-- ============================================================================
-- Unit Utility Wrappers (unit_helper bridge)
-- ============================================================================

--- Returns true if the unit is a boss (world boss, dungeon boss, raid boss).
---@param unit game_object The target unit.
---@return boolean is_boss True if the unit is a boss.
function NS.unit_is_boss(unit)
    if not _unit_helper or not unit then return false end
    local ok, v = pcall(_unit_helper.is_boss, _unit_helper, unit)
    return ok and v == true
end

--- Returns true if the unit is a training dummy.
---@param unit game_object The target unit.
---@return boolean is_dummy True if the unit is a training dummy.
function NS.unit_is_dummy(unit)
    if not _unit_helper or not unit then return false end
    local ok, v = pcall(_unit_helper.is_dummy, _unit_helper, unit)
    return ok and v == true
end

--- Returns true if the unit is a valid enemy (filters out immune/untargetable NPCs).
---@param unit game_object The target unit.
---@return boolean is_valid_enemy True if the unit is a valid enemy.
function NS.unit_is_valid_enemy(unit)
    if not _unit_helper or not unit then return false end
    local ok, v = pcall(_unit_helper.is_valid_enemy, _unit_helper, unit)
    return ok and v == true
end

--- Returns true if the unit is a valid ally (filters out hostile/immune units).
---@param unit game_object The target unit.
---@return boolean is_valid_ally True if the unit is a valid ally.
function NS.unit_is_valid_ally(unit)
    if not _unit_helper or not unit then return false end
    local ok, v = pcall(_unit_helper.is_valid_ally, _unit_helper, unit)
    return ok and v == true
end

--- Returns true if the unit is in combat.
---@param unit game_object The target unit.
---@return boolean in_combat True if the unit is in combat.
function NS.unit_is_in_combat(unit)
    if not _unit_helper or not unit then return false end
    local ok, v = pcall(_unit_helper.is_in_combat, _unit_helper, unit)
    return ok and v == true
end

--- Returns true if the unit is in the tank role.
---@param unit game_object The target unit.
---@return boolean is_tank True if the unit is a tank.
function NS.unit_is_tank(unit)
    if not _unit_helper or not unit then return false end
    local ok, v = pcall(_unit_helper.is_tank, _unit_helper, unit)
    return ok and v == true
end

--- Returns true if the unit is in the healer role.
---@param unit game_object The target unit.
---@return boolean is_healer True if the unit is a healer.
function NS.unit_is_healer(unit)
    if not _unit_helper or not unit then return false end
    local ok, v = pcall(_unit_helper.is_healer, _unit_helper, unit)
    return ok and v == true
end

--- Returns the health percentage (0-100) minus predicted incoming damage.
--- health_pct_inc, incoming_damage, health_pct_raw, incoming_damage_pct
---@param unit game_object The target unit.
---@param time_limit number|nil Time window in seconds for incoming damage prediction (default 5).
---@return number health_pct_inc Health percentage after subtracting incoming damage (0-100).
---@return number incoming_damage Total incoming damage predicted.
---@return number health_pct_raw Raw health percentage (0-100).
---@return number incoming_damage_pct Incoming damage as percentage of max health.
function NS.unit_health_inc(unit, time_limit)
    if not _unit_helper or not unit then return 100, 0, 100, 0 end
    local ok, hp_inc, inc_dmg, hp_raw, inc_pct = pcall(_unit_helper.get_health_percentage_inc, _unit_helper, unit, time_limit or nil)
    if ok then return (hp_inc or 0) * 100, inc_dmg or 0, (hp_raw or 0) * 100, (inc_pct or 0) * 100 end
    return 100, 0, 100, 0
end

--- Returns the resource percentage (0-100) for a given power type.
---@param unit game_object The target unit.
---@param power_type number Power type (0=Mana, 1=Rage, 2=Focus, 3=Energy).
---@return number pct Resource percentage 0-100.
function NS.unit_resource_pct(unit, power_type)
    if not _unit_helper or not unit then return 100 end
    local ok, v = pcall(_unit_helper.get_resource_percentage, _unit_helper, unit, power_type or 0)
    return ok and type(v) == "number" and v * 100 or 100
end

--- Returns a list of enemy units within range of a position.
--- Uses engine-level caching for performance.
---@param position vec3 The center position.
---@param range number Search radius in yards.
---@param incl_out_combat boolean|nil Include out-of-combat enemies (default true).
---@param players_only boolean|nil Only include player units (default false).
---@return table enemies List of enemy game_objects.
function NS.unit_get_enemies_around(position, range, incl_out_combat, players_only)
    if not _unit_helper or not position or not range then return {} end
    local ok, enemies = pcall(_unit_helper.get_enemy_list_around, _unit_helper, position, range,
        incl_out_combat ~= false, false, players_only or false, false)
    if ok and type(enemies) == "table" then return enemies end
    return {}
end

--- Returns a list of ally units within range of a position.
--- Uses engine-level caching for performance.
---@param position vec3 The center position.
---@param range number Search radius in yards.
---@param players_only boolean|nil Only include player units (default false).
---@param party_only boolean|nil Only include party members (default false).
---@return table allies List of ally game_objects.
function NS.unit_get_allies_around(position, range, players_only, party_only)
    if not _unit_helper or not position or not range then return {} end
    local ok, allies = pcall(_unit_helper.get_ally_list_around, _unit_helper, position, range,
        players_only or false, party_only or false, false)
    if ok and type(allies) == "table" then return allies end
    return {}
end

--- Boss-only cooldown gate. When use_cooldowns_on_boss_only is true,
--- returns false if the target is not a boss. Use at the top of cooldown
--- match functions to save big CDs for boss encounters.
---@param context table Rotation context (needs .target and .settings).
---@return boolean allowed True if cooldown is allowed on this target.
function NS.gate_cooldown_boss_only(context)
    if not context then return true end
    local settings = context.settings
    if not settings or settings.use_cooldowns_on_boss_only ~= true then return true end
    return NS.unit_is_boss(context.target)
end

-- ============================================================================
-- Spell Sequence Wrappers (spell_sequence_helper bridge)
-- ============================================================================

-- Cast Policy constants exposed for advanced_sequence opts.cast_policy
NS.SEQ_CAST_POLICY = _spell_sequence and _spell_sequence.CAST_POLICY or {
    NO_RESTRICTIONS = "no_restrictions",
    ONCE_EACH_CYCLE = "once_each_cycle",
    ONCE_EACH_CYCLE_OR_FILL = "once_each_cycle_or_fill",
    ONCE_EACH_COOLDOWN = "once_each_cooldown",
    ONCE_EACH_SWITCH = "once_each_switch",
    ONCE_EACH_SWITCH_OR_FILL = "once_each_switch_or_fill",
}

--- Cast spell A then immediately spell B. Two-spell micro-sequence.
---@param spell_a izi_spell First spell
---@param target_a game_object Target for first spell
---@param spell_b izi_spell Second spell
---@param target_b game_object Target for second spell
---@param delay number|nil Seconds between casts (default 0)
---@param timeout number|nil Seconds before auto-cancel (default 10)
---@param debug_name string|nil Name for logging
---@param cooldown number|nil Cooldown after completion (default 0)
---@return boolean queued True if sequence was started
function NS.seq_a_into_b(spell_a, target_a, spell_b, target_b, delay, timeout, debug_name, cooldown)
    if not _spell_sequence or not spell_a or not target_a or not spell_b or not target_b then return false end
    local ok, result = pcall(_spell_sequence.a_into_b, _spell_sequence, spell_a, target_a, spell_b, target_b, delay, timeout, debug_name, cooldown)
    return ok and result == true
end

--- Cast spells in strict order, one-shot. Each step advances on cast_safe success.
---@param spells izi_spell[] Array of spell objects
---@param targets (game_object|fun():game_object)[] Array of targets (one per spell)
---@param delay number|nil Seconds between steps (default 0)
---@param timeout number|nil Seconds before auto-cancel (default 10)
---@param debug_name string|nil Name for logging
---@param cooldown number|nil Cooldown after completion (default 0)
---@return boolean queued True if sequence was started
function NS.seq_simple(spells, targets, delay, timeout, debug_name, cooldown)
    if not _spell_sequence or type(spells) ~= "table" or #spells == 0 then return false end
    local ok, result = pcall(_spell_sequence.simple_sequence, _spell_sequence, spells, targets, delay, timeout, debug_name, cooldown)
    return ok and result == true
end

--- Priority loop with conditions + fill spells. Scans all entries every frame.
--- Perfect for DoT rotations: conditions become true when debuffs fall off.
---@param entries advanced_spell_entry[] Array of {spell, target, condition, opts}
---@param opts advanced_sequence_opts|nil Options (timeout, fill_entries, cast_policy, etc.)
---@return boolean queued True if sequence was started
function NS.seq_advanced(entries, opts)
    if not _spell_sequence or type(entries) ~= "table" or #entries == 0 then return false end
    local ok, result = pcall(_spell_sequence.advanced_sequence, _spell_sequence, entries, opts)
    return ok and result == true
end

--- Server-confirmed step-by-step sequence. Waits for on_spell_cast callback
--- to match spell_id before advancing. Requires wiring on_spell_cast callback.
---@param steps confirmed_step[] Array of {spell, target, spell_id, opts, use_cast}
---@param opts confirmed_sequence_opts|nil Options (timeout, step_timeout, retry_delay, etc.)
---@return boolean queued True if sequence was started
function NS.seq_confirmed(steps, opts)
    if not _spell_sequence or type(steps) ~= "table" or #steps == 0 then return false end
    local ok, result = pcall(_spell_sequence.confirmed_sequence, _spell_sequence, steps, opts)
    return ok and result == true
end

--- Feed spell cast callback data for confirmed_sequence player filtering.
--- Wire once: core.register_on_spell_cast_callback(function(data) NS.seq_on_spell_cast(data) end)
---@param data table Spell cast callback data from engine
function NS.seq_on_spell_cast(data)
    if not _spell_sequence or not data then return end
    pcall(_spell_sequence.on_spell_cast, _spell_sequence, data)
end

--- Returns true if ANY sequence (native, simple, advanced, or confirmed) is active.
--- Use in rotation tick to gate normal strategies while a sequence is running.
---@return boolean active
function NS.seq_is_active()
    if not _spell_sequence then return false end
    local ok, v = pcall(_spell_sequence.is_active, _spell_sequence)
    return ok and v == true
end

--- Returns true if a confirmed sequence is running.
---@return boolean active
function NS.seq_is_confirmed_active()
    if not _spell_sequence then return false end
    local ok, v = pcall(_spell_sequence.is_confirmed_active, _spell_sequence)
    return ok and v == true
end

--- Advance all active sequences. Call once per frame from your rotation on_update handler.
function NS.seq_on_update()
    if not _spell_sequence then return end
    pcall(_spell_sequence.on_update, _spell_sequence)
end

--- Cancel native + simple + advanced sequences (NOT confirmed; use seq_cancel_confirmed for that).
function NS.seq_cancel()
    if not _spell_sequence then return end
    pcall(_spell_sequence.cancel, _spell_sequence)
end

--- Cancel the active confirmed sequence.
function NS.seq_cancel_confirmed()
    if not _spell_sequence then return end
    pcall(_spell_sequence.cancel_confirmed, _spell_sequence)
end

--- Cancel ALL sequences (native + simple + advanced + confirmed).
function NS.seq_cancel_all()
    if not _spell_sequence then return end
    pcall(_spell_sequence.cancel_all, _spell_sequence)
end

--- Returns true if any cooldown is active across all sequence sources.
---@return boolean on_cooldown
function NS.seq_is_on_cooldown()
    if not _spell_sequence then return false end
    local ok, v = pcall(_spell_sequence.is_on_cooldown, _spell_sequence)
    return ok and v == true
end

--- Maximum remaining cooldown across all sequence sources.
---@return number seconds Cooldown remaining, or 0
function NS.seq_cooldown_remaining()
    if not _spell_sequence then return 0 end
    local ok, v = pcall(_spell_sequence.get_cooldown_remaining, _spell_sequence)
    return ok and type(v) == "number" and v or 0
end

--- Type of the currently active sequence.
---@return string|nil type "confirmed" | "advanced" | "simple" | "a_into_b" | nil
function NS.seq_get_type()
    if not _spell_sequence then return nil end
    local ok, v = pcall(_spell_sequence.get_sequence_type, _spell_sequence)
    return ok and v or nil
end

--- Progress of whichever sequence is active (confirmed > simple > advanced > a_into_b).
---@return integer|nil current Current step (1-based)
---@return integer|nil total Total steps
function NS.seq_get_progress()
    if not _spell_sequence then return nil, nil end
    local ok, cur, total = pcall(_spell_sequence.get_progress, _spell_sequence)
    return ok and cur or nil, ok and total or nil
end

--- Progress of confirmed sequence only.
---@return integer|nil current Current step (1-based)
---@return integer|nil total Total steps
function NS.seq_get_confirmed_progress()
    if not _spell_sequence then return nil, nil end
    local ok, cur, total = pcall(_spell_sequence.get_confirmed_progress, _spell_sequence)
    return ok and cur or nil, ok and total or nil
end

--- Enable/disable debug logging for native + simple + advanced sequences.
---@param enabled boolean
function NS.seq_set_debug(enabled)
    if not _spell_sequence then return end
    pcall(_spell_sequence.set_debug, _spell_sequence, enabled)
end

---@return boolean debug_enabled
function NS.seq_get_debug()
    if not _spell_sequence then return false end
    local ok, v = pcall(_spell_sequence.get_debug, _spell_sequence)
    return ok and v == true
end

--- Enable/disable debug logging for confirmed sequences.
---@param enabled boolean
function NS.seq_set_confirmed_debug(enabled)
    if not _spell_sequence then return end
    pcall(_spell_sequence.set_confirmed_debug, _spell_sequence, enabled)
end

---@return boolean debug_enabled
function NS.seq_get_confirmed_debug()
    if not _spell_sequence then return false end
    local ok, v = pcall(_spell_sequence.get_confirmed_debug, _spell_sequence)
    return ok and v == true
end

--- Override the local player resolver for on_spell_cast filtering.
---@param fn fun():game_object Function that returns the local player
function NS.seq_set_local_player_fn(fn)
    if not _spell_sequence or type(fn) ~= "function" then return end
    pcall(_spell_sequence.set_local_player_fn, _spell_sequence, fn)
end

--- Bind the native C++ module manually (if loaded after require-time).
---@param native_module table Native module reference
function NS.seq_bind_native(native_module)
    if not _spell_sequence or not native_module then return end
    pcall(_spell_sequence.bind_native, _spell_sequence, native_module)
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





function NS.buff_up(unit, ids)
    if not unit then return false end
    local list = collect_ids(ids)
    if #list == 0 then return false end

    -- Primary path: buff_manager with 50ms cache
    if _buff_manager then
        local ok, data = pcall(_buff_manager.get_buff_data, _buff_manager, unit, list, 50)
        if ok and data and data.is_active ~= false then return true end
    end

    -- Fallback: direct unit API
    for i = 1, #list do
        local id = list[i]
        if safe(safe_field(unit, "has_buff"), unit, id) or safe(safe_field(unit, "buff_up"), unit, id) then return true end
        local fd = safe(safe_field(unit, "get_buff_data"), unit, id)
        if fd and fd.is_active ~= false then return true end
    end

    return false
end



function NS.debuff_up(unit, ids)
    if not unit then return false end
    local list = collect_ids(ids)
    if #list == 0 then return false end

    -- Primary path: buff_manager with 50ms cache
    if _buff_manager then
        local ok, data = pcall(_buff_manager.get_debuff_data, _buff_manager, unit, list, 50)
        if ok and data and data.is_active ~= false then return true end
    end

    -- Fallback: direct unit API
    for i = 1, #list do
        local id = list[i]
        if safe(safe_field(unit, "has_debuff"), unit, id) or safe(safe_field(unit, "debuff_up"), unit, id) then return true end
        local fd = safe(safe_field(unit, "get_debuff_data"), unit, id)
        if fd and fd.is_active ~= false then return true end
    end

    return false
end

function NS.buff_remains(unit, ids)
    if not unit then return 0 end
    local list = collect_ids(ids)
    if #list == 0 then return 0 end

    -- Primary path: buff_manager with 50ms cache
    if _buff_manager then
        local ok, data = pcall(_buff_manager.get_buff_data, _buff_manager, unit, list, 50)
        if ok and data and data.is_active ~= false then
            return data.remaining > 0 and (data.remaining / 1000) or 0
        end
    end

    -- Fallback: direct unit API
    for i = 1, #list do
        local id = list[i]
        local v = safe(safe_field(unit, "buff_remains"), unit, id)
        if type(v) == "number" and v > 0 then return v end
        local fd = safe(safe_field(unit, "get_buff_data"), unit, id)
        if fd and fd.is_active ~= false then
            return fd.remaining > 0 and (fd.remaining / 1000) or 0
        end
    end

    return 0
end

---
--- Returns the points array from buff aura data for variable-value tracking.
--- `buff.points` contains variable values from aura data (e.g. absorb remaining
--- for Power Word: Shield, remaining charges for Holy Shield).
--- Returns the array on success, nil if buff not found.
---@param unit game_object The unit to check.
---@param ids table Array of spell IDs (highest rank first).
---@return number[]|nil points The points array from active buff data, or nil.
function NS.buff_points(unit, ids)
    if not unit then return nil end
    local list = collect_ids(ids)
    if #list == 0 then return nil end

    -- Primary path: buff_manager with 50ms cache
    if _buff_manager then
        local ok, data = pcall(_buff_manager.get_buff_data, _buff_manager, unit, list, 50)
        if ok and data and data.is_active ~= false and type(data.points) == "table" then
            return data.points
        end
    end

    -- Fallback: direct unit API
    for i = 1, #list do
        local id = list[i]
        local fd = safe(safe_field(unit, "get_buff_data"), unit, id)
        if fd and fd.is_active ~= false and type(fd.points) == "table" then
            return fd.points
        end
    end

    return nil
end

--- Returns the active buff's spell ID and its rank position in the ID array.
--- Rank position 1 = highest rank (convention: arrays are high-to-low).
--- Returns nil, nil if no buff is active or unit is nil.
---@param unit game_object The unit to check.
---@param ids table Array of spell IDs (highest rank first).
---@return number|nil active_id The spell ID of the active buff, or nil.
---@return number|nil rank Position in the ids array (1 = highest), or nil.
function NS.buff_rank(unit, ids)
    if not unit then return nil, nil end
    local list = collect_ids(ids)
    if #list == 0 then return nil, nil end

    -- Primary path: buff_manager with 50ms cache
    if _buff_manager then
        local ok, data = pcall(_buff_manager.get_buff_data, _buff_manager, unit, list, 50)
        if ok and data and data.is_active ~= false then
            local active_id = data.buff_id
            if type(active_id) == "number" then
                for i = 1, #list do
                    if list[i] == active_id then return active_id, i end
                end
                return active_id, nil
            end
        end
        return nil, nil
    end

    -- Fallback: direct unit API
    for i = 1, #list do
        local id = list[i]
        local fd = safe(safe_field(unit, "get_buff_data"), unit, id)
        if fd and fd.is_active ~= false then return id, i end
    end
    return nil, nil
end

--- Returns the points array from debuff aura data.
---@param unit game_object The unit to check.
---@param ids table Array of spell IDs.
---@return number[]|nil points The points array from active debuff data, or nil.
function NS.debuff_points(unit, ids)
    if not unit then return nil end
    local list = collect_ids(ids)
    if #list == 0 then return nil end

    -- Primary path: buff_manager with 50ms cache
    if _buff_manager then
        local ok, data = pcall(_buff_manager.get_debuff_data, _buff_manager, unit, list, 50)
        if ok and data and data.is_active ~= false and type(data.points) == "table" then
            return data.points
        end
    end

    -- Fallback: direct unit API
    for i = 1, #list do
        local id = list[i]
        local fd = safe(safe_field(unit, "get_debuff_data"), unit, id)
        if fd and fd.is_active ~= false and type(fd.points) == "table" then
            return fd.points
        end
    end

    return nil
end

function NS.debuff_remains(unit, ids)
    if not unit then return 0 end
    local list = collect_ids(ids)
    if #list == 0 then return 0 end

    -- Primary path: buff_manager with 50ms cache
    if _buff_manager then
        local ok, data = pcall(_buff_manager.get_debuff_data, _buff_manager, unit, list, 50)
        if ok and data and data.is_active ~= false then
            return data.remaining > 0 and (data.remaining / 1000) or 0
        end
    end

    -- Fallback: direct unit API
    for i = 1, #list do
        local id = list[i]
        local v = safe(safe_field(unit, "debuff_remains"), unit, id)
        if type(v) == "number" and v > 0 then return v end
        local fd = safe(safe_field(unit, "get_debuff_data"), unit, id)
        if fd and fd.is_active ~= false then
            return fd.remaining > 0 and (fd.remaining / 1000) or 0
        end
    end

    return 0
end

function NS.debuff_stacks(unit, ids)
    if not unit then return 0 end
    local list = collect_ids(ids)
    if #list == 0 then return 0 end

    -- Primary path: buff_manager with 50ms cache
    if _buff_manager then
        local ok, data = pcall(_buff_manager.get_debuff_data, _buff_manager, unit, list, 50)
        if ok and data and data.is_active ~= false then
            return data.count or data.stacks or 0
        end
    end

    -- Fallback: direct unit API
    for i = 1, #list do
        local id = list[i]
        local v = safe(safe_field(unit, "get_debuff_stacks"), unit, id)
        if type(v) == "number" and v > 0 then return v end
        local fd = safe(safe_field(unit, "get_debuff_data"), unit, id)
        if fd and fd.is_active ~= false then
            return fd.count or fd.stacks or 0
        end
    end

    return 0
end

function NS.get_debuff_stacks(unit, ids)
    return NS.debuff_stacks(unit, ids)
end

function NS.has_player_buff(ids) return NS.buff_up(NS.GetPlayer(), ids) end

function NS.has_debuff(unit, ids) return NS.debuff_up(unit, ids) end

function NS.has_player_debuff(ids) return NS.debuff_up(NS.GetPlayer(), ids) end

function NS.has_target_debuff(target, ids) return NS.debuff_up(target, ids) end

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

    if type(v) == "number" then return v end

    -- Fallback: IsSpellInRange with Attack (6603) for clients where get_distance returns nil
    if other and NS.is_spell_in_range then
        local in_range = NS.is_spell_in_range(6603, other)
        if in_range == true then return 5 end
        if in_range == false then return 999 end
    end

    return 999

end

function NS.unit_distance(unit, other)

    return unit_distance(unit, other)

end

NS.get_distance = NS.unit_distance

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

-- DEPRECATED: match_fail() always returns false and discards its argument.
-- Use `return false` directly in match functions. Retained for nil-safety.
function NS.match_fail() return false end

function NS.is_current_spell(spell_id)

    local fn = core.spell_book and core.spell_book.is_current_spell

    return type(spell_id) == "number" and safe(fn, spell_id) == true

end

function NS.get_time_until_swing()

    local player = NS.GetPlayer()

    if not player or not _auto_attack then return nil end

    local now = NS.time_now()

    local next_core = safe(safe_field(_auto_attack, "get_next_attack_core_time"), _auto_attack, player, 1) or nil

    if type(next_core) == "number" and next_core > 0 then

        return math.max(0, next_core - now)

    end

    local next_game = safe(safe_field(_auto_attack, "get_next_attack_game_time"), _auto_attack, player, 1) or nil

    if type(next_game) == "number" and next_game > 0 then

        return math.max(0, (next_game - NS.game_time_ms()) / 1000)

    end

    return nil

end

function NS.get_time_until_oh_swing()

    local player = NS.GetPlayer()

    if not player or not _auto_attack then return nil end

    local now = NS.time_now()

    local next_core = safe(safe_field(_auto_attack, "get_next_attack_core_time"), _auto_attack, player, 2) or nil

    if type(next_core) == "number" and next_core > 0 then

        return math.max(0, next_core - now)

    end

    local next_game = safe(safe_field(_auto_attack, "get_next_attack_game_time"), _auto_attack, player, 2) or nil

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
    -- Primary: engine-level shapeshift form ID (works on PS builds where buff APIs are broken)
    local ok, form_id = pcall(core.spell_book.get_shapeshift_form_id)
    if ok and form_id and form_id > 0 then
        if form_id == 1 then return 1 end  -- Battle Stance
        if form_id == 2 then return 2 end  -- Defensive Stance
        if form_id == 3 then return 3 end  -- Berserker Stance
    end
    -- Fallback: buff-based detection
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

    if position then

        best, best_distance = pick_enemy_from_list(me, NS.unit_get_enemies_around(position, limit, true), limit, best, best_distance)

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

-- Per-tick cache: GetEnemiesInRange is called 23+ times per rotation tick from
-- middleware/spec match functions (priest middleware alone: 6x). Each call did
-- 4 engine scans + O(n²) dedup + ~100 pcall. Cache the result by (tick, range)
-- so redundant calls in the same tick return the already-computed list.
-- The cache invalidates naturally when NS.time_now() advances (next tick).
local _enemy_cache_tick = -1
local _enemy_cache_range = -1
local _enemy_cache_result = nil

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

    if type(v) == "number" then return v end

    -- Fallback: IsSpellInRange with Attack (6603) for clients where get_distance returns nil
    if other and NS.is_spell_in_range then
        local in_range = NS.is_spell_in_range(6603, other)
        if in_range == true then return 5 end
        if in_range == false then return 999 end
    end

    return 999

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

    local limit = type(range) == "number" and range or 40

    -- Per-tick cache hit: same tick + same range → return already-computed list.
    -- Cuts 23+ redundant 4-scan enemy fetches per rotation tick to 1.
    local now = NS.time_now()
    if now == _enemy_cache_tick and limit == _enemy_cache_range and _enemy_cache_result then
        return _enemy_cache_result
    end

    for k in pairs(_enemy_range_buffer) do _enemy_range_buffer[k] = nil end

    _enemy_range_buffer.n = 0

    local out = _enemy_range_buffer

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

    if position then

        append_enemies_from_list(out, me, NS.unit_get_enemies_around(position, limit, true), limit)

    end

    local units, count = NS.get_visible_units()

    for i = 1, count do

        append_enemy_unique(out, me, units[i], limit)

    end

    _enemy_cache_tick = now
    _enemy_cache_range = limit
    _enemy_cache_result = out

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

-- NOTE: The Sylvanas object API does not distinguish raid from party.
-- This function returns true when grouped (party or raid). Callers that
-- need raid-only behavior should guard with GetNumGroupMembers() > 5.
function NS.is_in_raid()
    return NS.is_in_party()
end

local API_MODULES = {

    spell_helper = "common/utility/spell_helper",

    unit_helper = "common/utility/unit_helper",

    cooldown_tracker = "common/utility/cooldown_tracker",

    inventory_helper = "common/utility/inventory_helper",

    pet_handler = "common/utility/pet_handler",

    target_selector = "common/modules/target_selector",

    health_prediction = "common/modules/health_prediction",

    spell_prediction = "common/modules/spell_prediction",

    unit_manager = "common/unit_manager",

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

    22859, -- Mortal Cleave (TBC boss ability)

}

function NS.has_healing_reduction_debuff(unit)

    return NS.debuff_up(unit, HEALING_REDUCTION_DEBUFFS)

end

-- TBC Raid Boss debuffs that demand immediate healing attention
local BOSS_DEBUFF_CRITICAL = {
    [32231] = "Chaos Nova",           -- Magtheridon
    [34662] = "Bear Down",           -- Gruul
    [30495] = "Shadow of Death",     -- High King Maulgar
    [38029] = "Neurotoxin",          -- Lady Vashj
    [37676] = "Insignificance",      -- Archimonde
    [37850] = "Watery Grave",        -- Morogrim Tidewalker
    [39042] = "Rapid Burst",         -- Kil'jaeden
    [41303] = "Soul Drain",          -- Reliquary of Souls
    [41410] = "Deaden",              -- Illidari Council
    [40585] = "Dark Barrage",        -- Illidan
    [34661] = "Sacrifice",           -- Teron Gorefiend
    [31347] = "Doom",                -- Doom Lord Kazzak
    [32960] = "Mark of Kaz'rogal",   -- Kaz'rogal
    [31344] = "Mark of the Storm",   -- Archimonde (early TBC)
    [38995] = "Hammer of Justice",   -- Sunwell trash (stun + damage)
}

--- Check if a unit has a critical boss debuff requiring immediate healing.
---@param unit game_object Target unit
---@return boolean has_critical True if unit has a critical boss debuff
---@return string|nil debuff_name Name of the critical debuff, or nil
function NS.has_critical_boss_debuff(unit)
    if not unit then return false, nil end
    local has_debuff = unit.has_debuff
    if not has_debuff then return false, nil end
    for debuff_id, name in pairs(BOSS_DEBUFF_CRITICAL) do
        local ok, result = pcall(has_debuff, unit, debuff_id)
        if ok and result then return true, name end
    end
    return false, nil
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

    local get_party_frames = object_manager and object_manager.get_party_frames

    if type(get_party_frames) == "function" then

        added = added + append_healing_source_list(healing_source_units, safe(get_party_frames))

    end

    local get_party_members_in_range = safe_field(me, "get_party_members_in_range")

    if type(get_party_members_in_range) == "function" then

        added = added + append_healing_source_list(healing_source_units, safe(get_party_members_in_range, me, 40, true))

    end

    append_healing_source_unit(healing_source_units, me)

    if healing_source_units.n <= 0 then return nil, 0 end

    return healing_source_units, healing_source_units.n

end

function NS.build_healing_entries(out, decorate)

    out = out or {}

    for k in pairs(out) do out[k] = nil end

    local me = NS.GetPlayer()

    if not me then return 0 end

    local units, count = get_party_ally_list(me)

    -- Fallback: if party APIs returned only self, also scan visible friendlies

    if (not units or count <= 1) then

        local vis, vis_count = NS.get_visible_units(false, 200)

        if vis and vis_count > 0 then

            for i = 1, vis_count do

                local u = vis[i]

                local is_friend_with = safe_field(u, "is_friend_with")

                if u and not NS.same_unit(u, me) and NS.unit_alive(u) and safe(is_friend_with, u, me) and (distance(u, me) or 999) <= 40 then

                    count = count + 1

                    units[count] = u

                end

            end

            units.n = count

        end

    end

    local n = 0

    for i = 1, count do

        local u = units[i]

        local is_friend_with = safe_field(u, "is_friend_with")

        if NS.unit_alive(u) and (NS.same_unit(u, me) or safe(is_friend_with, u, me)) and distance(u, me) <= 40 then
            -- Feed HP sample into predictive tracker every tick
            if NS.HealerDeficit and type(NS.HealerDeficit.update) == 'function' then
                NS.HealerDeficit.update(u, NS.time_now(), NS.settings)
            end

            local hp = safe(safe_field(u, "get_health"), u) or 0

            local max_hp = safe(safe_field(u, "get_max_health"), u) or hp

            n = n + 1

            local effective_deficit
            local _s = NS.settings or {}
            if _s.healer_predict_enabled ~= false and NS.HealerDeficit and type(NS.HealerDeficit.predicted_deficit) == 'function' then
                effective_deficit = NS.HealerDeficit.predicted_deficit(u, 2, NS.settings)
            else
                effective_deficit = NS.predict_effective_deficit(u)
            end

            local effective_hp = max_hp > 0 and ((max_hp - effective_deficit) / max_hp) * 100 or NS.unit_health_pct(u)

            -- EMA incoming DPS for triage / stop-cast decisions
            local incoming_dps = 0
            if NS.TTDEmaTracker and type(NS.TTDEmaTracker.update) == 'function' then
                local now = NS.time_now and NS.time_now() or 0
                local ema_result = NS.TTDEmaTracker.update(u, now)
                if type(ema_result) == 'table' then
                    incoming_dps = ema_result.incoming_dps or 0
                end
            end
            local time_to_die = incoming_dps > 0 and (effective_hp / 100) * max_hp / incoming_dps or 999

            out[n] = {

                unit = u, hp = NS.unit_health_pct(u), effective_hp = effective_hp,

                current_hp = hp, max_hp = max_hp, deficit = math.max(0, max_hp - hp),

                effective_deficit = effective_deficit,

                incoming_dps = incoming_dps,

                time_to_die = time_to_die,

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

    local scan = _find_dead_scan

    if scan and scan.find_dead_party_ally then

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

NS.unified_state_builders = NS.unified_state_builders or {}

function NS.register_strategy(entry)

    -- entry = { name, playstyle, category, priority=number, is_burst=bool, is_defensive=bool, matches=fn, execute=fn }
    -- playstyle: string like "fury" or "_global" (default when omitted). Filtered in run_unified_strategies.

    if type(entry) ~= "table" or type(entry.execute) ~= "function" then return false end

    entry.playstyle = entry.playstyle or "_global"

    entry.priority = entry.priority or 0

    table.insert(NS.unified_registry, entry)

    table.sort(NS.unified_registry, function(a, b) return (a.priority or 0) > (b.priority or 0) end)

    return true

end


--- Register a state-builder function for a playstyle.
--- This replaces the per-tick  call that legacy rotation_registry:register()
--- stored in registry.options[playstyle] and called once per tick in run_list().
---@param playstyle string Playstyle name (e.g. "fury").
---@param builder_fn function(context) -> state table.
---@return boolean success.
function NS.register_state_builder(playstyle, builder_fn)
    if type(playstyle) ~= "string" or type(builder_fn) ~= "function" then return false end
    NS.unified_state_builders[playstyle] = builder_fn
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

    -- Per-playstyle cache: category is stable for same active playstyle
    local cat_cache = strategy._cat_cache
    if active and cat_cache and cat_cache[active] then return cat_cache[active] end
    if active and not cat_cache then cat_cache = {}; strategy._cat_cache = cat_cache end

    local name = tostring(strategy.name or ""):gsub("%s+", ""):lower()

    local cat
    if contains_any(name, HEALING_NAMES) then cat = "healing"
    elseif contains_any(name, DEFENSIVE_NAMES) then cat = "utility"
    elseif strategy.is_burst or contains_any(name, COOLDOWN_NAMES) then cat = "cooldown"
    elseif contains_any(name, UTILITY_NAMES) then cat = "utility"
    elseif list_name == "middleware" then cat = "utility"
    elseif HEALING_PLAYSTYLES[tostring(active or ""):lower()] then
        if contains_any(name, DAMAGE_NAMES) then cat = "damage"
        else cat = "healing" end
    else cat = "damage"
    end

    if active then cat_cache[active] = cat end
    return cat
end

-- Strategy gate: checks category toggles from settings and burst conditions.

-- Reused by both the legacy run_list dispatcher and the unified registry.

function NS.strategy_allowed(strategy, list_name, active, context)

    local settings = context and context.settings or EMPTY

    local category = strategy_category(strategy, list_name, active)

    local is_healer = HEALING_PLAYSTYLES[tostring(active or ""):lower()] == true

    if is_healer and category == "damage" then return false end

    if settings.utility_enabled == false and category == "utility" then return false end

    if settings.healing_enabled == false and (category == "healing" or (is_healer and category == "cooldown")) then return false end

    if settings.damage_enabled == false and (category == "damage" or (category == "cooldown" and not is_healer)) then return false end

    if settings.use_cooldowns == false and category == "cooldown" and not (context and context.should_burst) then return false end

    return true

end

--- Execute unified strategies for the active playstyle.
--- Filters by playstyle, builds state once per tick via the registered state builder,
--- and passes both context and state to each strategy's matches() and execute().
---@param context table Rotation context with active_playstyle.
---@return boolean fired True if any strategy executed successfully.
function NS.run_unified_strategies(context)

    local safe_fn = safe

    local active = context and context.active_playstyle

    -- Build state for the active playstyle (pre-computed once, shared across all strategies)

    local state = context

    if active and NS.unified_state_builders and NS.unified_state_builders[active] then

        state = safe_fn(NS.unified_state_builders[active], context) or context

    end

    -- Precompute tick-constant settings for strategy gating
    local settings = context and context.settings or EMPTY
    local is_healer = HEALING_PLAYSTYLES[tostring(active or ""):lower()] == true
    local utility_enabled = settings.utility_enabled
    local healing_enabled = settings.healing_enabled
    local damage_enabled = settings.damage_enabled
    local use_cooldowns = settings.use_cooldowns
    local should_burst = context and context.should_burst

    for i = 1, #NS.unified_registry do

        local s = NS.unified_registry[i]

        -- Filter by playstyle: _global strategies run in all playstyles; nil defaults to _global

        local ps = s.playstyle

        if not ps or ps == "_global" or ps == active then
            -- Inline strategy_allowed checks (avoid per-strategy function call + settings lookup)
            local category = strategy_category(s, nil, active)
            local gated = (utility_enabled == false and category == "utility")
                or (healing_enabled == false and (category == "healing" or (is_healer and category == "cooldown")))
                or (damage_enabled == false and (category == "damage" or (category == "cooldown" and not is_healer)))
                or (use_cooldowns == false and category == "cooldown" and not should_burst)
            if not gated then
                local ok = true
                if type(s.matches) == "function" then ok = s.matches(context, state) == true end
                if ok and safe_fn(s.execute, context, state) then return true end
            end
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


    local name = action.name or "?"

    if action.setting and settings[action.setting] == false then

        return false

    end

    if action.min_interval then

        local last = _last_action_exec[name]

        if last and (NS.now(context) - last) < action.min_interval then

            return false

        end

    end

    if action.combat and not context.in_combat then

        return false

    end

    if action.ooc and context.in_combat then

        return false

    end

    local actor_hp = action.target == "pet" and NS.unit_health_pct(NS.GetPet()) or (context.hp or 100)

    if action.max_hp and actor_hp > action.max_hp then

        return false

    end

    if action.min_hp and actor_hp < action.min_hp then

        return false

    end

    if action.target_max_hp and (context.target_hp or 100) > action.target_max_hp then

        return false

    end

    if action.target_min_hp and (context.target_hp or 100) < action.target_min_hp then

        return false

    end

    if action.min_level and (context.player_level or 70) < action.min_level then

        return false

    end

    if action.max_level and (context.player_level or 70) > action.max_level then

        return false

    end


    -- =====================================================================
    -- TTD (Time-To-Death) gating: prevents actions from firing when the
    -- target won't live long enough for the spell to be worthwhile.
    --
    -- context.ttd_known = false means the TTD tracker hasn't collected
    -- enough samples yet (early combat, target just entered range, or
    -- TTD module not loaded).  When require_ttd is true we block the
    -- action entirely rather than using a stale/zero estimate.
    --
    -- Two-tier guard:
    --   1. require_ttd + !ttd_known  -->  block (no data yet)
    --   2. context.ttd < min_ttd      -->  block (target dies too soon)
    --
    -- Actions that set min_ttd: execute-phase nukes, long-cooldown
    -- DPS cooldowns, short-duration debuffs not worth applying to a
    -- dying target.
    -- =====================================================================
    if action.min_ttd then


        if action.require_ttd and not context.ttd_known then

            return false

        end

        if context.ttd_known and (context.ttd or 999) < action.min_ttd then

            return false

        end

    end

    if action.enemy_count and (context.enemy_count or 0) < action.enemy_count then

        return false

    end

    if context.settings and context.settings.aoe_enabled == false and (action.enemy_count or action.is_aoe) then

        return false

    end

    if action.max_enemy_count and (context.enemy_count or 0) > action.max_enemy_count then

        return false

    end

    if action.min_mana and (context.mana_pct or 100) < action.min_mana then

        return false

    end

    if action.max_mana and (context.mana_pct or 100) > action.max_mana then

        return false

    end

    if action.target == "pet" and not NS.GetPet() then

        return false

    end

    if action.min_rage and (context.rage or 0) < action.min_rage then

        return false

    end

    if action.min_energy and (context.energy or 0) < action.min_energy then

        return false

    end

    if action.min_combo and (context.combo_points or 0) < action.min_combo then

        return false

    end

    if action.not_moving and context.is_moving then

        return false

    end

    if action.moving and not context.is_moving then

        return false

    end

    if action.not_casting and (context.is_casting or context.is_channeling) then

        return false

    end

    if action.required_stance and context.stance ~= action.required_stance then

        return false

    end

    if action.required_form and not NS.has_form(action.required_form) then

        return false

    end

    if action.requires_buff and not NS.buff_up(NS.GetPlayer(), action.requires_buff) then

        return false

    end

    if action.requires_behind and not NS.is_behind_target(context.target) then

        return false

    end

    if action.kind == "form" and NS.has_form(action.form) then

        return false

    end

    if action.kind == "buff" and NS.buff_up(NS.GetPlayer(), action.buff or action.spell) then

        return false

    end

    if action.kind == "threat_drop" and not NS.should_drop_threat(context) then

        return false

    end

    if action.requires_ready_spell then

        local ready_target = action.requires_ready_target == "self" and NS.GetPlayer() or context.target

        if not ready_target or not NS.spell_ready(action.requires_ready_spell, ready_target, { expected_cooldown = action.requires_ready_cooldown }) then

            return false

        end

    end

    if action.target ~= "self" and action.requires_target ~= false then

        if action.target == "cc_target" then

            if not context.cc_target then

                return false

            end

        elseif not context.has_valid_enemy_target then

            return false

        end

    end

    local target = target_for(context, action)

    if action.target_not_player and target then

        local is_player = safe_field(target, "is_player")

        if is_player and safe(is_player, target) == true then

            return false

        end

    end

    if action.creature_types and target then

        local get_creature_type = safe_field(target, "get_creature_type")

        local creature_type = get_creature_type and safe(get_creature_type, target) or nil

        if not creature_type or not action.creature_types[creature_type] then

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

                return false

            end

        elseif debuff_mode == "maintain" then

            local max_stacks = action.max_debuff_stacks or 5

            local stacks = NS.get_debuff_stacks(target, action.debuff)

            if stacks >= max_stacks then

                local remains = NS.debuff_remains(target, action.debuff)

                if remains > refresh then

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

                    return false

                end

            end

        end

    end

    if action.requires_debuff and target and not NS.debuff_up(target, action.requires_debuff) then

        return false

    end

    if action.blocked_debuff and target and NS.debuff_up(target, action.blocked_debuff) then

        return false

    end

    return NS.spell_ready(action.spell, target, { skip_range = action.target == "self" or action.skip_range, skip_gcd = action.skip_gcd, expected_cooldown = action.cooldown })

end

function NS.action_execute(context, action, prefix)
    _last_action_exec_cleanup_time = cleanup_old_entries(_last_action_exec, _last_action_exec_cleanup_time, _ACTION_EXEC_CLEANUP_INTERVAL, _ACTION_EXEC_MAX_AGE)

    local target = target_for(context, action)

    local opts = { skip_range = action.target == "self" or action.skip_range, skip_gcd = action.skip_gcd }

    local reason = format("%s %s", prefix or "[EAX]", action.name or "Action")


    if action.position then

        if action.skip_gcd then

            local id = NS.get_spell_id(action.spell)

            local position = position_for(context, action)

            if not id or not position then return false end

            -- Use central cast guard (skips GCD per opts, checks cooldown/resource/range/anti-flicker/min_interval/reagent)
            if not NS.evaluate_cast(action.spell, target, reason, opts) then return false end

            -- Primary: spell_queue position casting (queue-first per Phase 4)
            local spell_queue = _spell_queue
            if spell_queue and type(spell_queue.queue_spell_position) == "function" then
                local queued = spell_queue:queue_spell_position(id, position, 1, reason, false)
                if queued ~= false then
                    mark_spell_cast(id)
                    _last_action_exec[action.name] = NS.now(context)
                    return true
                end
            end

            -- Fallback: direct core.input.cast_position_spell
            local cast_pos_fn = core.input and core.input.cast_position_spell
            if type(cast_pos_fn) ~= "function" then return false end
            if safe(cast_pos_fn, id, position) == false then return false end

            mark_spell_cast(id)

            _last_action_exec[action.name] = NS.now(context)


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

        -- Use central cast guard (skips GCD per opts, checks cooldown/resource/range/anti-flicker/min_interval/reagent)
        if not NS.evaluate_cast(action.spell, target, reason, opts) then return false end
        -- Movement assist: brief pause + face target for cast-time spells (Phase 5)
        do
            local ma = NS.MovementAssist and NS.MovementAssist()
            if ma and ma.face_for_spell then
                ma:face_for_spell(id, target)
            end
        end

        -- Primary: spell_queue target casting (queue-first per Phase 4)
        local spell_queue = _spell_queue
        if spell_queue and type(spell_queue.queue_spell_target) == "function" then
            local queued = spell_queue:queue_spell_target(id, target, 1, reason, false)
            if queued ~= false then
                mark_spell_cast(id)
                _last_action_exec[action.name] = NS.now(context)
                return true
            end
        end

        -- IZI fallback: try IZI before raw input
        if NS.izi and type(NS.izi.spell) == "function" then
            local izi_spell = NS.izi.spell(id)
            if izi_spell and type(izi_spell.cast_safe) == "function" then
                local ok = izi_spell:cast_safe(target, reason) == true
                if ok then
                    mark_spell_cast(id)
                    _last_action_exec[action.name] = NS.now(context)
                    return true
                end
            end
        end

        -- Fallback: direct core.input.cast_target_spell
        local cast_fn = core.input and core.input.cast_target_spell
        if type(cast_fn) == "function" then
            if safe(cast_fn, id, target) == false then return false end
        else
            return false
        end


        _last_action_exec[action.name] = NS.now(context)


        return true

    end

    if not NS.spell_exists(action.spell) then return false end

    if NS.gcd_remains() > 0 then return false end

    -- Movement assist: brief pause + face target for cast-time spells (Phase 5)
    do
        local spell_id = NS.get_spell_id(action.spell)
        local ma = NS.MovementAssist and NS.MovementAssist()
        if spell_id and ma and ma.face_for_spell then
            ma:face_for_spell(spell_id, target)
        end
    end

    local ok = NS.try_cast(action.spell, target, reason, opts)

    if ok then _last_action_exec[action.name] = NS.now(context) end

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

NS.log("Core runtime loaded (core-v2: pcall buff_manager)")
NS.log("GameVersion: " .. tostring(core.get_game_version and core.get_game_version() or "?"))
NS.log("ExactVersion: " .. tostring(core.get_exact_game_version and core.get_exact_game_version() or "?"))

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

    NS.log("GameVersion: " .. tostring(core.get_game_version and core.get_game_version() or "?"))
    NS.log("ExactVersion: " .. tostring(core.get_exact_game_version and core.get_exact_game_version() or "?"))

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

    local ok_zone, zone_text = pcall(core.get_zone_text)
    NS.log("Zone: " .. tostring(ok_zone and zone_text or "?"))

    local ok_subzone, subzone_text = pcall(core.get_subzone_text)
    NS.log("SubZone: " .. tostring(ok_subzone and subzone_text or "?"))

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

            local ok_learned, learned = pcall(sb.is_spell_learned, common[i])
            local known = ok_learned and learned or false

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

--- Returns the player's current spell damage bonus.
-- Sylvanas API does not expose spell_power directly;
-- callers should prefer context.spell_damage when available.
---@return number
function NS.get_spell_damage()
    return 0
end

-- ============================================================================
-- Movement Assist (Phase 5) — Lazy-loaded shared movement/facing helper
-- ============================================================================
-- Provides face_for_cast(), face_for_spell(), resume(), unlock(), on_render().
-- Source: movement-handler.md — pause_movement_light, look_at_target, on_render
do
    local _ma_loaded = false
    local _ma_mod = nil
    function NS.MovementAssist()
        if not _ma_loaded then
            local ok, mod = pcall(require, "shared/movement_assist_sylvanas")
            if ok and type(mod) == "table" then _ma_mod = mod end
            _ma_loaded = true
        end
        return _ma_mod
    end
end

return NS





