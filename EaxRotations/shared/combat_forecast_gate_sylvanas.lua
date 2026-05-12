local M = {}

function M.should_use_long_cd(context, spell_cooldown_seconds)
    if not context or not context.combat_length_forecast then return true end
    local forecast = context.combat_length_forecast
    local is_boss = false
    if context.target and type(context.target.is_boss) == "function" then
        is_boss = context.target:is_boss() == true
    end
    if is_boss then return true end
    if spell_cooldown_seconds >= 180 and forecast < 60 then return false end
    if spell_cooldown_seconds >= 120 and forecast < 45 then return false end
    if spell_cooldown_seconds >= 60 and forecast < 30 then return false end
    return true
end

_G.CombatForecastGate = M
if _G.EaxRotations then _G.EaxRotations.should_use_long_cd = M.should_use_long_cd end
return M
