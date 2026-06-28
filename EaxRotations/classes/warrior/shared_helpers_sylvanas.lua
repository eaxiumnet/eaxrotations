-- shared_helpers_sylvanas -- Shared helpers for Warrior spec files (Fury, Arms, Protection).
-- Extracted from duplicated boilerplate in fury_sylvanas.lua and arms_sylvanas.lua.
-- Constants like TACTICAL_MASTERY_CAP, STANCE_CAST_LOCKOUT, and CAST_TAG are
-- configurable fields on the returned module so each spec can override them.

local M = {}
local NS = _G.EaxRotations
if not NS then return M end

-- ============================================================================
-- Configurable constants (defaults match both Fury and Arms; override per-spec)
-- ============================================================================
M.TACTICAL_MASTERY_CAP = 25
M.STANCE_CAST_LOCKOUT = 2.0
M.CAST_TAG = "[WARRIOR]"

local STANCE = (NS.WarriorConstants or {}).STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }
M.STANCE = STANCE

-- Internal: stance cast lockout tracking (shared across all spec files)
M.last_stance_cast_at = 0

-- ============================================================================
-- Helper functions
-- ============================================================================

-- setting: resolve a config value from context settings or NS.get_setting.
-- Falls back to NS.setting if the shared module version is unavailable.
function M.setting(context, key, fallback)
    local settings = context and context.settings
    if settings and settings[key] ~= nil then return settings[key] end
    if NS.get_setting then return NS.get_setting(key, fallback) end
    return fallback
end

-- bool_call: safely call a boolean method on a unit via pcall.
function M.bool_call(unit, method)
    if not unit or type(unit[method]) ~= "function" then return false end
    local ok, value = pcall(unit[method], unit)
    return ok and value == true
end

-- execute_phase: detect execute phase (target HP <= 20% or dying soon via TTD).
-- Uses nil-guards for defensive compatibility with both spec files.
function M.execute_phase(context, state)
    if NS.is_execute_phase then return NS.is_execute_phase(context.target_hp, 20) end
    if (state.target_hp or context.target_hp or 100) <= 20 then return true end
    -- TTD awareness: treat as execute phase if target is dying soon
    if (state.ttd or 0) > 0 and (state.ttd or 0) < 15 then return true end
    return false
end

-- desired_stance: resolve stance preference from settings.
function M.desired_stance(context)
    local preference = M.setting(context, "stance_preference", "auto")
    if preference == "battle" or preference == STANCE.BATTLE then return STANCE.BATTLE end
    if preference == "defensive" or preference == STANCE.DEFENSIVE then return STANCE.DEFENSIVE end
    if preference == "berserker" or preference == STANCE.BERSERKER then return STANCE.BERSERKER end
    return nil
end

-- preserved_rage_after_swap: calculate rage retained after stance swap.
-- Uses nil-guards (defensive version from Fury).
function M.preserved_rage_after_swap(rage)
    if NS.get_tactical_mastery_cap then return NS.get_tactical_mastery_cap() end
    local cap = M.TACTICAL_MASTERY_CAP or 25
    local r = rage or 0
    return r < cap and r or cap
end

-- stance_swap_safe: check if swapping stance won't lose too much rage.
-- Fixed version: uses preserved_rage_after_swap(state.rage or 0).
function M.stance_swap_safe(state, cost)
    local effective_cost = math.min(cost or 0, 15)
    if state.stance == nil then return true end
    return M.preserved_rage_after_swap(state.rage or 0) >= effective_cost
end

-- action: spell readiness check (more defensive version with required_stance gate).
function M.action(context, row)
    if not context or not row then return false end
    if not row.spell then return true end
    local target = (row.target == "self" or row.requires_target == false) and (context.me or NS.GetPlayer()) or context.target
    if not target then return false end
        if row.min_rage and context.rage and context.rage < row.min_rage then return false end
    if row.required_stance and context.stance ~= row.required_stance then return false end
    local opts = {}
    if row.requires_target == false then opts.skip_range = true end
    if row.cooldown then opts.expected_cooldown = row.cooldown end
    return NS.spell_ready(row.spell, target, opts)
end

-- cast: spell cast wrapper. Uses M.CAST_TAG (configurable per spec).
function M.cast(context, row)
    if not context or not row then return false end
    if not row.spell then return false end
    local target = (row.target == "self" or row.requires_target == false) and (context.me or NS.GetPlayer()) or context.target
    if not target then return false end
    local opts = {}
    if row.requires_target == false then opts.skip_range = true end
    if row.cooldown then opts.expected_cooldown = row.cooldown end
    local ok = NS.try_cast(row.spell, target, M.CAST_TAG, opts)
    if ok and row.kind == "form" then
        M.last_stance_cast_at = NS.time_now and NS.time_now() or 0
    end
    return ok
end

-- build_action: create an action row.
function M.build_action(name, spell_value, opts)
    local row = opts or {}
    row.name = name
    row.spell = spell_value
    return row
end

-- stance_lockout_active: check if we're in stance cast lockout.
-- Reads M.last_stance_cast_at (updated by M.cast) and M.STANCE_CAST_LOCKOUT.
function M.stance_lockout_active()
    return (NS.time_now and NS.time_now() or 0) < M.last_stance_cast_at + M.STANCE_CAST_LOCKOUT
end

return M
