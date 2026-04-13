-- schema.lua
-- Schema-driven settings definition for EAX Warrior Fury
-- Uses schema_framework for menu generation and runtime access

local schema_framework = require("libraries/schema_framework")

-- Create schema instance
local schema = schema_framework.new("eaxwarriorfury")

-- Define schema structure
schema:define({
    sections = {
        {
            id = "general",
            label = "General",
            settings = {
                { type = "checkbox", key = "enabled", default = true, label = "Enabled", tooltip = "Enable/disable rotation" },
                { type = "keybind", key = "toggle_key", default = 7, label = "Toggle Key", tooltip = "Key to toggle rotation on/off" },
                { type = "dropdown", key = "mode", default = 1, label = "Mode", tooltip = "Rotation mode",
                  options = {
                      { value = 1, label = "Auto" },
                      { value = 2, label = "PvE" },
                      { value = 3, label = "PvP" },
                  }},
            },
        },
        {
            id = "targeting",
            label = "Targeting",
            settings = {
                { type = "checkbox", key = "focus_priority", default = false, label = "Focus Priority", tooltip = "Prioritize focus target" },
                { type = "slider_int", key = "combat_self_hp_boost", default = 10, min = 0, max = 30, label = "Self HP Boost", tooltip = "HP threshold boost for self-targeting" },
            },
        },
        {
            id = "racial",
            label = "Racial",
            settings = {
                { type = "checkbox", key = "use_racial", default = true, label = "Use Racial", tooltip = "Use racial abilities" },
                { type = "slider_int", key = "racial_hp", default = 40, min = 10, max = 80, label = "Racial HP Threshold", tooltip = "HP threshold for racial usage" },
            },
        },
        {
            id = "rotation",
            label = "Rotation",
            settings = {
                { type = "checkbox", key = "use_bloodthirst", default = true, label = "Bloodthirst", tooltip = "Use Bloodthirst" },
                { type = "checkbox", key = "use_whirlwind", default = true, label = "Whirlwind", tooltip = "Use Whirlwind" },
                { type = "checkbox", key = "use_heroic_strike", default = true, label = "Heroic Strike", tooltip = "Use Heroic Strike" },
                { type = "slider_int", key = "heroic_strike_rage", default = 50, min = 20, max = 80, label = "HS Rage Threshold", tooltip = "Minimum rage for Heroic Strike" },
                { type = "checkbox", key = "use_cleave", default = true, label = "Cleave", tooltip = "Use Cleave for AoE" },
                { type = "slider_int", key = "cleave_rage", default = 60, min = 30, max = 90, label = "Cleave Rage Threshold", tooltip = "Minimum rage for Cleave" },
                { type = "checkbox", key = "use_execute", default = true, label = "Execute", tooltip = "Use Execute" },
                { type = "checkbox", key = "use_slam", default = false, label = "Slam", tooltip = "Use Slam" },
            },
        },
        {
            id = "cooldowns",
            label = "Cooldowns",
            settings = {
                { type = "checkbox", key = "use_death_wish", default = true, label = "Death Wish", tooltip = "Use Death Wish" },
                { type = "checkbox", key = "use_recklessness", default = true, label = "Recklessness", tooltip = "Use Recklessness" },
                { type = "slider_int", key = "cd_min_ttd", default = 0, min = 0, max = 60, label = "CD Min TTD", tooltip = "Minimum time-to-death for CD usage" },
            },
        },
        {
            id = "defensive",
            label = "Defensive",
            settings = {
                { type = "checkbox", key = "use_defensive", default = true, label = "Use Defensives", tooltip = "Use defensive cooldowns" },
                { type = "slider_int", key = "defensive_hp", default = 30, min = 10, max = 50, label = "Defensive HP Threshold", tooltip = "HP threshold for defensive CDs" },
            },
        },
        {
            id = "trinkets",
            label = "Trinkets",
            settings = {
                { type = "dropdown", key = "trinket1_mode", default = 1, label = "Trinket 1", tooltip = "Trinket 1 mode",
                  options = {
                      { value = 1, label = "Off" },
                      { value = 2, label = "Offensive" },
                      { value = 3, label = "Defensive" },
                  }},
                { type = "dropdown", key = "trinket2_mode", default = 1, label = "Trinket 2", tooltip = "Trinket 2 mode",
                  options = {
                      { value = 1, label = "Off" },
                      { value = 2, label = "Offensive" },
                      { value = 3, label = "Defensive" },
                  }},
            },
        },
        {
            id = "swing",
            label = "Swing Manager",
            settings = {
                { type = "checkbox", key = "use_swing_manager", default = true, label = "Use Swing Manager", tooltip = "Queue HS/Cleave optimally" },
                { type = "slider_int", key = "swing_queue_threshold", default = 50, min = 20, max = 80, label = "Queue Threshold", tooltip = "Rage threshold for HS queue" },
                { type = "slider_int", key = "swing_cleave_threshold", default = 60, min = 30, max = 90, label = "Cleave Queue Threshold", tooltip = "Rage threshold for Cleave queue" },
            },
        },
        {
            id = "dashboard",
            label = "Dashboard",
            settings = {
                { type = "checkbox", key = "show_dashboard", default = false, label = "Show Dashboard", tooltip = "Show combat dashboard" },
                { type = "slider_int", key = "dashboard_opacity", default = 190, min = 50, max = 255, label = "Opacity", tooltip = "Dashboard opacity" },
                { type = "slider_float", key = "dashboard_scale", default = 1.0, min = 0.5, max = 2.0, label = "Scale", tooltip = "Dashboard scale" },
                { type = "slider_int", key = "dashboard_x", default = 20, min = 0, max = 2000, label = "X Position", tooltip = "Dashboard X position" },
                { type = "slider_int", key = "dashboard_y", default = 200, min = 0, max = 2000, label = "Y Position", tooltip = "Dashboard Y position" },
                { type = "checkbox", key = "show_timer_bars", default = true, label = "Timer Bars", tooltip = "Show GCD and swing timers" },
            },
        },
    },
})

-- Migrate from legacy menu if it exists
local legacy_menu = require("libraries/menu")
schema:migrate_legacy(legacy_menu)

-- Generate menu from schema
local generated_menu = schema:generate_menu()

-- Export both the schema and generated menu
return {
    schema = schema,
    menu = generated_menu,
}
