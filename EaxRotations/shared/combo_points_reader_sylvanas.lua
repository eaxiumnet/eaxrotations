-- combo_points_reader_sylvanas.lua — single source of truth for reading combo points.
-- WHAT:  returns read_combo_points(unit, power_combo) -> number|nil.
-- WHEN:  called by main_sylvanas.lua build_context and by cat/rogue spec fallbacks.
-- WHY:   on TBC Anniversary 2.5.5 the IZI SDK combo_points_current() can be stale,
--        while get_power(COMBOPOINTS) is authoritative. Native results, including 0,
--        must win; SDK is fallback-only when native power is unavailable.
-- SAFETY: nil unit tolerated; returns nil (never 0) when NO reader works, so callers'
--         own fallback chains still activate. A genuine 0 still returns 0.

local function read_combo_points(unit, power_combo)
    if not unit then return nil end

    if type(unit.get_power) == "function" then
        local ok, cp = pcall(unit.get_power, unit, power_combo or 4)
        if ok and type(cp) == "number" then return cp end
    end

    if type(unit.combo_points_current) == "function" then
        local ok, cp = pcall(unit.combo_points_current, unit)
        if ok and type(cp) == "number" then return cp end
    end

    return nil
end

return read_combo_points
