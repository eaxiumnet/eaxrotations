-- schema_autoloot_sylvanas.lua — Shared Auto-Loot settings for all class schemas.
-- WHAT: Provides a reusable Auto-Loot section with 10 standard keys.
-- WHEN: Imported by each class's schema_sylvanas.lua to build the Auto-Loot tab.
-- WHY: Eliminates 9× copy-paste of the same 10-key structure across all class schemas.
-- SAFETY: Pure data structure, no runtime logic.

local M = {}

--- Auto-loot settings (10 keys).
-- Labels are written to be self-explanatory without hovering.
-- Tooltips add detail for users who want it.
-- @return table Array of setting definitions
function M.settings()
    return {
        {
            key = "eax_autoloot_enabled",
            type = "checkbox",
            label = "Auto-Loot Corpses",
            default = false,
            tooltip = "When enabled, the bot will automatically loot nearby corpses between ability casts. "
                .. "It waits a random moment before looting, respects combat state, and pauses if bags are nearly full. "
                .. "Disabled by default — turn this on if you want hands-free looting while grinding."
        },
        {
            key = "eax_autoloot_combat_mode",
            type = "dropdown",
            label = "Loot Only When Safe",
            default = 1,
            options = {
                { text = "Out of Combat Only (recommended)", value = 1 },
                { text = "Always (includes combat)", value = 2 },
            },
            tooltip = "'Out of Combat Only' means looting only happens when you're not fighting. "
                .. "This is safest — you won't accidentally stop casting to loot mid-fight. "
                .. "'Always' allows looting even during combat (not recommended for dungeons/raids)."
        },
        {
            key = "eax_autoloot_grace",
            type = "slider",
            label = "Wait After Combat (seconds)",
            min = 0, max = 5, default = 2,
            tooltip = "After the last enemy dies, wait this many seconds before looting. "
                .. "Gives you time to pick a new target or move. Default 2s is a good balance."
        },
        {
            key = "eax_autoloot_delay_min",
            type = "slider",
            label = "Loot Delay: Minimum (ms)",
            min = 0, max = 300, default = 50,
            tooltip = "The bot waits at least this many milliseconds before looting a corpse. "
                .. "Humans don't click instantly — this adds realism. Default 50ms."
        },
        {
            key = "eax_autoloot_delay_max",
            type = "slider",
            label = "Loot Delay: Maximum (ms)",
            min = 100, max = 500, default = 200,
            tooltip = "The bot waits at most this many milliseconds before looting. "
                .. "A random value between Min and Max is chosen each time. Default 200ms."
        },
        {
            key = "eax_autoloot_max_burst",
            type = "slider",
            label = "Loot Speed Limit (per 10 sec)",
            min = 1, max = 10, default = 5,
            tooltip = "Maximum number of corpses that can be looted in any 10-second window. "
                .. "Prevents suspicious rapid-fire looting. Default 5 is natural for AoE grinding."
        },
        {
            key = "eax_autoloot_skip_players",
            type = "checkbox",
            label = "Skip Player Corpses",
            default = true,
            tooltip = "When enabled, the bot will never loot player corpses (battlegrounds, arenas, world PvP). "
                .. "This is respectful and avoids accidental dishonorable looting. Default ON."
        },
        {
            key = "eax_autoloot_stop_full",
            type = "checkbox",
            label = "Pause If Bags Nearly Full",
            default = true,
            tooltip = "When enabled, auto-loot pauses when you have fewer than the minimum free slots remaining. "
                .. "Prevents wasting time trying to loot when you can't carry anything. Default ON."
        },
        {
            key = "eax_autoloot_min_free",
            type = "slider",
            label = "Minimum Free Bag Slots",
            min = 0, max = 20, default = 2,
            tooltip = "Auto-loot pauses when you have fewer than this many empty bag slots left. "
                .. "Set to 0 to ignore bag space. Default 2 keeps a small buffer."
        },
        {
            key = "eax_autoloot_range",
            type = "slider",
            label = "Scan Range (yards)",
            min = 10, max = 50, default = 30,
            tooltip = "How far to scan for lootable corpses. 30 yards is natural — far enough to catch nearby kills "
                .. "but not so far that you're running across the zone. Increase for open-world grinding."
        },
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
