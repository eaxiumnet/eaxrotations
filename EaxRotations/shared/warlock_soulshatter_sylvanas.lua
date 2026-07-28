-- shared/warlock_soulshatter_sylvanas.lua — Shared Warlock Soulshatter threat-drop logic.
-- WHAT:  centralized match/execute helpers for Soulshatter.
-- WHEN:  any warlock spec wants a threat-drop strategy.
-- WHY:   avoids duplicating the same gating (use_threat_drop, in_combat, threat
--         threshold, cooldown/ready checks) in middleware + specs.
-- SAFETY: nil-guards on all context fields and NS helpers; relies purely on the
--          rotation API (cooldown_remains, spell_ready) for availability.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")

-- Helper: fetch the current player unit safely.
local function get_me()
    return NS.GetPlayer and NS.GetPlayer() or NS.PLAYER_UNIT
end

-- Check whether Soulshatter should be considered available and appropriate.
-- `spell_obj` is the caller's Soulshatter spell action (SPELLS.Soulshatter or ACTION.Soulshatter).
-- `context` is the standard rotation context.
local function matches(context, spell_obj)
    if not context then return false end
    if spec_kit.setting_bool(context, "use_threat_drop", true) == false then return false end
    if not context.in_combat then return false end

    -- Threat gating: fire only when actually high threat or actively tanking.
    if (context.threat_pct or 0) < 80 and not context.has_aggro then return false end

    -- Spell availability: rely purely on the rotation API.
    local me = get_me()
    if not me then return false end
    if NS.cooldown_remains and (NS.cooldown_remains(spell_obj) or 0) > 0 then return false end
    if NS.spell_ready and not NS.spell_ready(spell_obj, me, { skip_range = true }) then return false end

    return true
end

-- Execute Soulshatter on the player.
-- `spell_obj` is the caller's Soulshatter spell action.
-- `label` is the log prefix (e.g., "[WARLOCK] Soulshatter").
local function execute(context, spell_obj, label)
    local me = get_me()
    if not me then return false end
    return NS.try_cast(spell_obj, me, label or "[WARLOCK] Soulshatter", { skip_range = true })
end

-- Convenience: build a full strategy table for the caller.
-- `name` is the strategy name (e.g., "ThreatDrop" or "Soulshatter").
-- `spell_obj` is the caller's Soulshatter spell action.
-- `label` is the optional log prefix.
local function make_strategy(name, spell_obj, label)
    return {
        name = name or "Soulshatter",
        matches = function(context)
            return matches(context, spell_obj)
        end,
        execute = function(context)
            return execute(context, spell_obj, label)
        end,
    }
end

return {
    matches = matches,
    execute = execute,
    make_strategy = make_strategy,
}
