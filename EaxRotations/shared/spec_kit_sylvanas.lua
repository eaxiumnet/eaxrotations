-- spec_kit_sylvanas.lua -- spec_kit: boilerplate + nil-guard elimination kit for spec files..
-- WHAT:   spec_kit: boilerplate + nil-guard elimination kit for spec files.
-- WHEN:   loaded by spec files; consumed by build_state + actions
-- WHY:    provides define_action_for_class + safe_state proxies
-- SAFETY: lazy-loaded only by spec files; nil-tolerant
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

--
-- Boilerplate + nil-guard elimination kit for EaxRotations spec files.
-- Mirrors the proven design in eax_refactor/lua/spec_kit.lua and ports it into
-- the live shared/ folder so any spec can opt-in without touching core.
--
-- WHY THIS EXISTS
--   Two recurring "loop" patterns in the live tree, fixed repeatedly by hand:
--
--   1. Every spec re-rolls the same spell() resolver helper from scratch.
--      Centralized here as spec_kit.define_action() / define_action_for_class().
--
--   2. Every spec has the SAME nil-guard bug fixed commit-by-commit:
--        if state.rage < 25 then ... end   -- nil -> false, skips strategy
--      spec_kit.safe_state() makes the safe default automatic.
--
-- PORTABILITY
--   Self-contained. Depends only on the NS namespace exposed via
--   _G.EaxRotations. When NS is absent (e.g. unit tests), define_action()
--   and setting() fall back to documented defaults so the kit is fully
--   testable without the engine present.
--
-- WHEN TO USE
--   - NEW specs: start from spec_kit (do not copy-paste spell() boilerplate).
--   - SPEC BEING EDITED: opportunistically convert during the edit
--     (the AGENTS.md plans/refactor-developer-experience-2026-06.md rule:
--     "convert a spec only when already editing it, never big-bang").
--
-- CONTRACT
--   - No banned APIs (ffi.C, io.popen, os.execute, debug.*, math.sqrt).
--   - Every public function is nil-guarded against a missing NS.
--   - safe_state returns a write-through proxy: __newindex lands on the
--     underlying raw table, so build_state() mutations still work.

local M = {}

-- -----------------------------------------------------------------------------
-- ns(): the _G.EaxRotations guard that every spec currently copy-pastes as
-- its first three lines. Returns nil when the engine isn't loaded.
-- -----------------------------------------------------------------------------
function M.ns()
    return _G.EaxRotations
end

-- -----------------------------------------------------------------------------
-- define_action(spell_field, rank_ids, label)
--
-- Resolves a spell to a concrete value usable by NS.spell_ready / NS.try_cast.
-- Byte-identical parity with the hand-rolled spell() helper in the live specs
-- and with NS.spell_action (core_sylvanas.lua) when that is available.
--
-- Resolution order:
--   1. Delegate to NS.spell_action if present (rich format resolver).
--   2. If rank_ids is a table, return the first entry.
--   3. Return rank_ids as-is (a single numeric id).
-- -----------------------------------------------------------------------------
function M.define_action(spell_field, rank_ids, label)
    local NS = M.ns()
    if NS and type(NS.spell_action) == "function" then
        return NS.spell_action(rank_ids, label or spell_field)
    end
    if type(rank_ids) == "table" then return rank_ids[1] end
    return rank_ids
end

-- -----------------------------------------------------------------------------
-- define_action_for_class(SPELLS)
-- Bound `define_action` that checks per-class SPELLS first (mirrors the live
-- spell() helper which captures SPELLS as an upvalue). This is the form
-- specs actually use: `local define = spec_kit.define_action_for_class(SPELLS)`.
-- -----------------------------------------------------------------------------
function M.define_action_for_class(SPELLS)
    return function(spell_field, rank_ids, label)
        if SPELLS and type(SPELLS) == "table" and SPELLS[spell_field] ~= nil then
            return SPELLS[spell_field]
        end
        return M.define_action(spell_field, rank_ids, label)
    end
end

M.SOD_PHASE_MIN = 1
M.SOD_PHASE_MAX = 8
M.SOD_PHASE_DEFAULT = 8

local function is_positive_integer(value)
    return type(value) == "number" and value > 0 and value % 1 == 0
end

local function valid_action_ids(value)
    if is_positive_integer(value) then return true end
    if type(value) ~= "table" or #value == 0 then return false end
    for i = 1, #value do
        if not is_positive_integer(value[i]) then return false end
    end
    return true
end

local function valid_sod_phase(value)
    return is_positive_integer(value)
        and value >= M.SOD_PHASE_MIN
        and value <= M.SOD_PHASE_MAX
end

function M.define_sod_action_for_class(SPELLS)
    local define = M.define_action_for_class(SPELLS)
    return function(spell_field, rank_ids, requirements, label)
        local source_ids = rank_ids
        if type(SPELLS) == "table" and SPELLS[spell_field] ~= nil then
            source_ids = SPELLS[spell_field]
        end
        if not valid_action_ids(source_ids) then return nil, "invalid action ids" end
        if requirements ~= nil and type(requirements) ~= "table" then
            return nil, "invalid requirements"
        end

        requirements = requirements or {}
        local rune_id = requirements.rune_id
        if rune_id ~= nil and not is_positive_integer(rune_id) then
            return nil, "invalid rune id"
        end

        local min_phase = requirements.min_phase or M.SOD_PHASE_MIN
        local max_phase = requirements.max_phase or M.SOD_PHASE_MAX
        if not valid_sod_phase(min_phase) or not valid_sod_phase(max_phase) or min_phase > max_phase then
            return nil, "invalid phase range"
        end

        return {
            action = define(spell_field, rank_ids, label),
            rune_id = rune_id,
            min_phase = min_phase,
            max_phase = max_phase,
        }
    end
end

function M.sod_phase(context)
    if context ~= nil and type(context) ~= "table" then return nil end
    if context and context.sod_phase ~= nil then
        if valid_sod_phase(context.sod_phase) then return context.sod_phase end
        return nil
    end

    local configured = M.setting(context, "sod_phase", nil)
    if configured == nil then return M.SOD_PHASE_DEFAULT end
    if valid_sod_phase(configured) then return configured end
    return nil
end

function M.has_sod_rune(context, rune_id)
    if type(context) ~= "table" or not is_positive_integer(rune_id) then return false end
    local runes = context.sod_runes
    return type(runes) == "table" and runes[rune_id] == true
end

function M.sod_action_available(context, descriptor)
    if type(descriptor) ~= "table" or descriptor.action == nil then return false end
    if not valid_sod_phase(descriptor.min_phase) or not valid_sod_phase(descriptor.max_phase) then return false end

    local phase = M.sod_phase(context)
    if not phase or phase < descriptor.min_phase or phase > descriptor.max_phase then return false end
    if descriptor.rune_id ~= nil and not M.has_sod_rune(context, descriptor.rune_id) then return false end
    return true
end

-- -----------------------------------------------------------------------------
-- SAFE_STATE_DEFAULTS: documented per-field defaults for AGENTS.md Pattern 14.
-- Centralizing this here means a new spec doesn't re-derive (or mis-derive)
-- the right fallback per field.
-- -----------------------------------------------------------------------------
M.SAFE_STATE_DEFAULTS = {
    -- Health / mana -> assume full (skip defensives / mana consumers).
    hp              = 100,
    hp_pct          = 100,
    player_hp       = 100,
    player_hp_pct   = 100,
    mana_pct        = 100,
    player_mana     = 100,
    player_mana_pct = 100,
    target_hp       = 100,
    target_hp_pct   = 100,
    lowest_hp       = 100,
    -- Resources -> assume empty (skip spenders).
    rage            = 0,
    energy          = 0,
    focus           = 0,
    combo_points    = 0,
    player_rage     = 0,
    player_energy   = 0,
    -- Enemies -> assume none (skip AoE).
    enemy_count     = 0,
    enemies         = 0,
    enemies_count   = 0,
    -- Movement / distance neutral defaults.
    target_distance = 0,
    target_range    = 0,
    ttd             = 0,
}

-- -----------------------------------------------------------------------------
-- safe_state(raw_state, schema?)
--
-- Read-safe, write-through proxy over raw_state. Numeric reads of keys in
-- `schema` (default: SAFE_STATE_DEFAULTS) fall back to the documented default
-- when raw_state[key] is nil. Writes pass through to raw_state so build_state
-- mutations continue to function.
--
-- The proxy is iterable (pairs over raw_state for ipairs/pairs compatibility
-- within match functions). Keys NOT in the schema behave as plain table reads.
-- -----------------------------------------------------------------------------
function M.safe_state(raw_state, schema)
    raw_state = raw_state or {}
    local defaults = schema or M.SAFE_STATE_DEFAULTS
    local proxy = {}
    return setmetatable(proxy, {
        __index = function(_, key)
            if raw_state[key] ~= nil then return raw_state[key] end
            local d = defaults[key]
            if d ~= nil then return d end
            return nil
        end,
        __newindex = function(_, key, value)
            raw_state[key] = value
        end,
        __len = function(_) return #raw_state end,
        __pairs = function(_)
            return pairs(raw_state)
        end,
        __ipairs = function(_)
            return ipairs(raw_state)
        end,
    })
end

-- -----------------------------------------------------------------------------
-- merge_state(build_state, context, state_override)
--
-- Builds a fresh state from context, then layers an optional caller-provided
-- state override on top. The returned table keeps the safe_state schema
-- default-fallback (__index) but isolates writes so match functions cannot
-- mutate the shared raw_state table (e.g. state.utility_target).
--
-- Use this in centralized base_matches guards to keep tests ergonomic
-- (callers can pass partial states) without leaking state between strategies.
-- -----------------------------------------------------------------------------
function M.merge_state(build_state, context, state_override)
    local s = build_state(context)
    if not state_override or next(state_override) == nil then return s end
    local merged = {}
    for k, v in pairs(s) do merged[k] = v end
    for k, v in pairs(state_override) do merged[k] = v end
    -- Preserve safe_state metatable defaults (schema-backed __index) so that
    -- fields not explicitly set on the cached table are still visible. We copy
    -- the metatable to avoid sharing mutable state with the cached proxy.
    -- Also isolate writes so state mutations in one test do not leak into the
    -- shared raw_state table (e.g. state.utility_target set by match funcs).
    local mt = getmetatable(s)
    if mt then
        local mt_copy = {}
        for k, v in pairs(mt) do mt_copy[k] = v end
        mt_copy.__newindex = nil  -- use default table writes so mutations stay local
        setmetatable(merged, mt_copy)
    end
    return merged
end

-- -----------------------------------------------------------------------------
-- setting(context, key, default)
--
-- Centralized context.settings -> NS.get_setting -> default lookup. Replaces
-- the copy-pasted local setting() in every spec.
-- -----------------------------------------------------------------------------
function M.setting(context, key, default)
    local settings = context and context.settings
    if type(settings) == "table" and settings[key] ~= nil then
        return settings[key]
    end
    local NS = M.ns()
    if NS and type(NS.get_setting) == "function" then
        local ok, result = pcall(NS.get_setting, key, default)
        if ok and result ~= nil then return result end
    end
    return default
end

function M.setting_number(context, key, default)
    local v = M.setting(context, key, nil)
    if type(v) == "number" then return v end
    return default
end

function M.setting_bool(context, key, default)
    local v = M.setting(context, key, nil)
    if v == nil then return default end
    return v ~= false
end

return M
