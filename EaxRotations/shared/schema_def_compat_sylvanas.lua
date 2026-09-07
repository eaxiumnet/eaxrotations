-- schema_def_compat_sylvanas.lua — schema setting-definition compatibility check.
-- WHAT:   single source of truth for "is this re-declaration of a schema key a
--         harmless identical duplicate or a conflicting one?"
-- WHEN:   consumed by main.lua's initialize_schema_menu (decides whether a
--         duplicate key logs a warning) and by test_schema_duplicate_widget_ids
--         (validates every duplicated key across all class schemas).
-- WHY:    A schema key can legitimately appear in multiple tabs/sections — the
--         loader reuses the first control so the setting renders in each
--         section backed by one unique widget (core.menu id contract). Only a
--         STRUCTURALLY CONFLICTING re-declaration is an accident worth warning
--         about every boot; identical duplicates (priest Smart Casting on
--         Discipline+Holy, hunter Shot Weaving across spec tabs) are the
--         sanctioned pattern and must not nag.
-- SAFETY: pure data comparison; no NS/core/api dependencies.
--
-- Compatible when: type, default, slider bounds, and dropdown/combobox option
-- values all match. Label/tooltip differences do not change the created
-- widget's identity or bound value, so they are intentionally not compared —
-- keep this in lock-step with the loader's reuse semantics.

local M = {}

--- Compare two setting definitions for the same key. Returns nil when the
--- re-declaration is structurally compatible (safe silent reuse), or a string
--- describing the first incompatibility found.
function M.incompatibility(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return "non-table definition"
    end
    if (a.type or "") ~= (b.type or "") then
        return string.format("type mismatch (%s vs %s)", tostring(a.type), tostring(b.type))
    end
    if a.default ~= b.default then
        return string.format("default mismatch (%s vs %s)", tostring(a.default), tostring(b.default))
    end
    if a.type == "slider" then
        if a.min ~= b.min or a.max ~= b.max then
            return string.format("slider bounds mismatch (%s..%s vs %s..%s)",
                tostring(a.min), tostring(a.max), tostring(b.min), tostring(b.max))
        end
    end
    if a.type == "dropdown" or a.type == "combobox" then
        local ao, bo = a.options or {}, b.options or {}
        if #ao ~= #bo then
            return string.format("option count mismatch (%d vs %d)", #ao, #bo)
        end
        for i = 1, #ao do
            local av = ao[i] and ao[i].value
            local bv = bo[i] and bo[i].value
            if tostring(av) ~= tostring(bv) then
                return string.format("option[%d] value mismatch (%s vs %s)", i,
                    tostring(av), tostring(bv))
            end
        end
    end
    return nil
end

return M
