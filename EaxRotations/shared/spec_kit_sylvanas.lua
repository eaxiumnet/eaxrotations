-- spec_kit_sylvanas.lua -- boilerplate + nil-guard elimination kit (define_action, safe_state)
-- WHAT:  macro helpers: define_action_for_class + spec_kit.safe_state proxy
-- WHEN:  called at module load
-- WHY:   sandbox refactor kit: makes Pattern 14 nil-guards structurally impossible
-- SAFETY: safe_state returns 0/100 by default per AGENTS.md Pattern 14

-- =============================================================================
-- spec_kit_sylvanas.lua
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
-- =============================================================================

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
        return NS.get_setting(key, default)
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
