-- shared/warlock_death_coil_sylvanas.lua — Shared Warlock Death Coil survival logic.
-- WHAT:  centralized match/execute helpers for Death Coil emergency heal/CC.
-- WHEN:  any warlock spec wants a defensive Death Coil strategy.
-- WHY:   avoids duplicating the same gating (use_death_coil, death_coil_hp,
--         in_combat, target) in middleware + specs.
-- SAFETY: nil-guards on all context fields; matches requires an valid target and
--         spell readiness before execute is called.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")

-- Check whether Death Coil should be considered as a survival option.
-- `spell_obj` is the caller's Death Coil spell action.
local function matches(context, spell_obj, opts, state)
    if not context then return false end
    if opts and opts.require_in_combat and not context.in_combat then return false end
    if not context.target then return false end
    if spec_kit.setting_bool(context, "use_death_coil", true) == false then return false end

    local threshold = spec_kit.setting_number(context, "death_coil_hp", 40)
    if threshold <= 0 then return false end

    -- Support both middleware-style context.hp/me and spec-style state.hp_pct.
    local hp = context.hp
    if hp == nil and context.me and context.me.get_health_percentage then
        hp = context.me:get_health_percentage()
    end
    if hp == nil and state then
        hp = state.hp_pct
    end

    if (hp or 100) > threshold then return false end

    -- Spell availability, if the API is present.
    if NS.spell_ready and spell_obj then
        return NS.spell_ready(spell_obj, context.target)
    end

    return true
end

-- Execute Death Coil on the current enemy target.
local function execute(context, spell_obj, label)
    if not context or not context.target then return false end
    if not spell_obj then return false end
    return NS.try_cast(spell_obj, context.target, label or "[WARLOCK] Death Coil")
end

-- Convenience: build a full strategy table for the caller.
local function make_strategy(name, spell_obj, opts)
    opts = opts or {}
    local strategy = {
        name = name or "DeathCoil",
        matches = function(context, state)
            return matches(context, spell_obj, opts, state)
        end,
        execute = function(context)
            return execute(context, spell_obj, opts.label)
        end,
    }
    if opts.priority then strategy.priority = opts.priority end
    if opts.is_defensive then strategy.is_defensive = opts.is_defensive end
    return strategy
end

return {
    -- matches/execute were exported by the pre-make_strategy interface but
    -- have zero consumers — every caller goes through make_strategy (which
    -- closes over the local functions above). Removed 2026-08-11 by the
    -- state-field audit's S4 dead-export rule.
    make_strategy = make_strategy,
}
