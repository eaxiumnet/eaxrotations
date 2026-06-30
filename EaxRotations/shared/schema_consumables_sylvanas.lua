-- schema_consumables_sylvanas.lua -- Shared Consumables tab structure for all class schemas.
-- WHAT: Provides a reusable Consumables tab with 14 standard keys and class-specific overrides.
-- WHEN: Used by each class's schema_sylvanas.lua to build the Consumables tab.
-- WHY: Eliminates 9× copy-paste of the same 14-key structure across all class schemas.
-- SAFETY: Pure data structure, no runtime logic; classes can override defaults and append extra keys.

local M = {}

--- Base consumables settings (14 keys).
-- Classes can override defaults by passing an overrides table to build_tab().
-- @return table Array of setting definitions
function M.base_settings()
    return {
        { key = "use_auto_consumables", type = "checkbox", label = "Enable Auto Consumables", default = true },
        { key = "use_flasks", type = "checkbox", label = "Use Flasks", default = false },
        { key = "use_elixirs", type = "checkbox", label = "Use Elixirs", default = false },
        { key = "use_food", type = "checkbox", label = "Use Food", default = false },
        { key = "use_combat_potions", type = "checkbox", label = "Combat Potions", default = true },
        { key = "use_weapon_buffs", type = "checkbox", label = "Weapon Buffs", default = false },
        { key = "use_drums", type = "checkbox", label = "Drums", default = false },
        { key = "use_healthstones", type = "checkbox", label = "Healthstones", default = true },
        { key = "use_mana_potions", type = "checkbox", label = "Mana Potions", default = false },
        { key = "mana_potion_threshold", type = "slider", label = "Mana Potion at %", min = 0, max = 100, default = 40 },
        { key = "health_potion_threshold", type = "slider", label = "Health Potion at %", min = 0, max = 100, default = 35 },
        { key = "use_health_potions", type = "checkbox", label = "Health Potions", default = true },
        { key = "use_bandages", type = "checkbox", label = "Bandages", default = false },
        { key = "use_dark_runes", type = "checkbox", label = "Dark Runes", default = false },
    }
end

--- Build the full Consumables tab with optional overrides and extra settings.
-- @param overrides table Optional table of {key = {field = value}} to override specific defaults.
--   Example: { use_drums = { default = true }, use_mana_potions = { default = true } }
-- @param extra_settings table Optional additional settings to append after the base 14 keys.
--   Example: { { key = "use_healthstone", type = "checkbox", label = "Healthstones (form-aware)", default = false } }
-- @return table Consumables tab structure ready to insert into the schema
function M.build_tab(overrides, extra_settings)
    local settings = M.base_settings()

    -- Apply overrides
    if overrides then
        for _, setting in ipairs(settings) do
            if overrides[setting.key] then
                for k, v in pairs(overrides[setting.key]) do
                    setting[k] = v
                end
            end
        end
    end

    -- Append extra settings
    if extra_settings then
        for _, setting in ipairs(extra_settings) do
            table.insert(settings, setting)
        end
    end

    return {
        name = "Consumables",
        sections = {
            {
                header = "Auto Consumables",
                settings = settings,
            },
        },
    }
end

return M
