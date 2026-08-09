-- combat_forecast_gate_sylvanas.lua — Cooldown usage gate based on combat-length forecast.
-- WHAT:  decides whether a long-cooldown spell is worth casting given expected fight duration.
-- WHEN:  called by spec match functions before committing offensive/defensive CDs.
-- WHY:   avoids wasting 3-minute CDs on trash that dies in 20 seconds.
-- SAFETY: nil-guards on context; defaults to "allow cast" when forecast is unavailable.
-- DECISION: predicts incoming damage ratio before spec actions; pure bridge.

local M = {}

local function _is_boss(context)
    -- Prefer the accurately-computed context value (main_sylvanas sets it via
    -- NS.unit_is_boss → unit_helper:is_boss; the raw target:is_boss() is
    -- documented as inaccurate — see game-object.md). Fall back to the helper.
    if context and context.target_is_boss == true then return true end
    local NS = _G.EaxRotations
    local has_helper = NS and NS.unit_is_boss ~= nil
    if context and context.target and has_helper then
        return NS.unit_is_boss(context.target) == true
    end
    return false
end

function M.should_use_long_cd(context, spell_cooldown_seconds)
    if not context or not context.combat_length_forecast then return true end
    local forecast = context.combat_length_forecast
    if _is_boss(context) then return true end
    if spell_cooldown_seconds >= 180 and forecast < 60 then return false end
    if spell_cooldown_seconds >= 120 and forecast < 45 then return false end
    if spell_cooldown_seconds >= 60 and forecast < 30 then return false end
    return true
end

_G.CombatForecastGate = M
-- Mock-NS guard (survey item #2): a mock NS (battery / apl_status, marked
-- _EAX_MOCK) must never capture module instances via require-time write-back.
if _G.EaxRotations and not _G.EaxRotations._EAX_MOCK then _G.EaxRotations.should_use_long_cd = M.should_use_long_cd end
return M
