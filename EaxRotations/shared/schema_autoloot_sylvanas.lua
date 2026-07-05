-- schema_autoloot_sylvanas.lua — Shared Auto-Loot settings for all class schemas.
-- WHAT: Provides a reusable Auto-Loot section with 10 standard keys.
-- WHEN: Imported by each class's schema_sylvanas.lua to build the Auto-Loot tab.
-- WHY: Eliminates 9× copy-paste of the same 10-key structure across all class schemas.
-- SAFETY: Pure data structure, no runtime logic.

local M = {}

--- Auto-loot settings (10 keys).
-- @return table Array of setting definitions
function M.settings()
    return {
        { key = "eax_autoloot_enabled", type = "checkbox", label = "Auto-Loot Corpses", default = false, tooltip = "Automatically loot nearby corpses between casts. Disabled by default." },
        { key = "eax_autoloot_combat_mode", type = "dropdown", label = "Combat Mode", default = 1, options = {
            { text = "Out of Combat Only", value = 1 },
            { text = "Always", value = 2 },
        }, tooltip = "OOC Only is safer — won't loot during combat." },
        { key = "eax_autoloot_grace", type = "slider", label = "Post-Combat Grace (s)", min = 0, max = 5, default = 2, tooltip = "Seconds to wait after combat ends before looting." },
        { key = "eax_autoloot_delay_min", type = "slider", label = "Min Loot Delay (ms)", min = 0, max = 300, default = 50, tooltip = "Minimum random delay before looting a corpse." },
        { key = "eax_autoloot_delay_max", type = "slider", label = "Max Loot Delay (ms)", min = 100, max = 500, default = 200, tooltip = "Maximum random delay before looting a corpse." },
        { key = "eax_autoloot_max_burst", type = "slider", label = "Max Loots per 10s", min = 1, max = 10, default = 5, tooltip = "Burst protection — max corpses looted in any 10-second window." },
        { key = "eax_autoloot_skip_players", type = "checkbox", label = "Skip Player Corpses", default = true, tooltip = "Don't loot player corpses. Recommended for PvP." },
        { key = "eax_autoloot_stop_full", type = "checkbox", label = "Stop When Bags Full", default = true, tooltip = "Pause auto-looting when free bag slots drop below minimum." },
        { key = "eax_autoloot_min_free", type = "slider", label = "Min Free Bag Slots", min = 0, max = 20, default = 2, tooltip = "Auto-loot pauses when you have fewer than this many free slots." },
        { key = "eax_autoloot_range", type = "slider", label = "Loot Range (yds)", min = 10, max = 50, default = 30, tooltip = "Maximum distance to scan for lootable corpses." },
    }
end

--- Build a full Auto-Loot tab.
-- @return table Auto-Loot tab structure ready to insert into the schema
function M.build_tab()
    return {
        name = "Auto-Loot",
        sections = {
            {
                header = "Auto-Loot",
                settings = M.settings(),
            },
        },
    }
end

return M
