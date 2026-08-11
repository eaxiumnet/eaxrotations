-- shared/warlock_shadow_ward_sylvanas.lua — Shared Warlock Shadow Ward survival logic.
-- WHAT:  centralized match/execute helpers for Shadow Ward shadow-absorb buff.
-- WHEN:  any warlock spec wants a defensive Shadow Ward strategy.
-- WHY:   avoids duplicating the same gating (use_shadow_ward, shadow_ward_hp,
--         in_combat, existing buff, shadow-caster detection) in middleware + specs.
-- SAFETY: nil-guards on all context fields; only casts when an enemy shadow caster
--         is present (PvP or group-aware flag).

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")

local SHADOW_WARD_IDS = { 28610, 11740, 11739, 6229 }
local SHADOW_CASTER_CLASS_IDS = { [5] = true, [9] = true } -- Priest, Warlock

-- Check whether Shadow Ward should be cast.
-- `spell_obj` is the caller's Shadow Ward spell action.
local function matches(context, spell_obj, opts)
    if not context then return false end
    if not context.in_combat then return false end
    if spec_kit.setting_bool(context, "use_shadow_ward", true) == false then return false end

    local hp = context.hp or (context.me and context.me.get_health_percentage and context.me:get_health_percentage()) or 100
    local threshold = spec_kit.setting_number(context, "shadow_ward_hp", 70)
    if hp > threshold then return false end

    -- Don't recast if the buff is already active.
    if NS.has_player_buff and NS.has_player_buff(SHADOW_WARD_IDS) then return false end

    -- Only use when a shadow caster is present.
    if opts and opts.use_group_aware then
        local group_aware = spec_kit.setting_bool(context, "warlock_group_aware_utility", true)
        if not (context.is_pvp or (group_aware and context.is_group)) then return false end
    end
    if not context.enemy_shadow_caster then
        if context.target then
            local class_id
            pcall(function() class_id = context.target:get_class() end)
            if not SHADOW_CASTER_CLASS_IDS[class_id] then return false end
        else
            return false
        end
    end

    if NS.spell_ready and spell_obj then
        return NS.spell_ready(spell_obj, NS.PLAYER_UNIT, { skip_range = true })
    end

    return true
end

-- Execute Shadow Ward on the player.
local function execute(context, spell_obj, label)
    if not context then return false end
    if not spell_obj then return false end
    local me = context.me or NS.PLAYER_UNIT
    if not me then return false end
    return NS.try_cast(spell_obj, me, label or "[WARLOCK] Shadow Ward", { skip_range = true })
end

-- Convenience: build a full strategy table for the caller.
local function make_strategy(name, spell_obj, opts)
    opts = opts or {}
    local strategy = {
        name = name or "ShadowWard",
        matches = function(context, state)
            return matches(context, spell_obj, opts)
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

