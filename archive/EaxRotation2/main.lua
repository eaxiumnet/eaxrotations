-- ============================================================================
-- EaxRotation2 - Main Bootstrap
-- Project Sylvanas API - IZI-First Rotation Engine
-- ============================================================================

local core = _G.core

-- Load IZI SDK
local izi = require("common/izi_sdk")
if not izi then
    core.log_error("[EaxRotation2] Failed to load IZI SDK")
    return
end

-- Get plugin info from header
local plugin_info = require("EaxRotation2/header")
if not plugin_info or not plugin_info.load then
    core.log_warning("[EaxRotation2] Plugin not loaded - check header.lua")
    return
end

core.log("[EaxRotation2] Initializing IZI-first engine for " .. plugin_info.player_class_name)

-- Create global namespace
_G.EaxRotation2 = _G.EaxRotation2 or {}
local ER2 = _G.EaxRotation2
ER2.core = core
ER2.izi = izi
ER2.player_class_name = plugin_info.player_class_name
ER2.player_class_id = plugin_info.player_class_id

-- Load engine and specs
local engine = require("EaxRotation2/engine/dispatcher")
local init = require("EaxRotation2/init")

-- Expose set_spec to global namespace for manual override
ER2.set_spec = init.set_spec
ER2.get_active_spec = init.get_active_spec

-- Register update callback
if init.on_update then
    core.register_on_update_callback(init.on_update)
end

core.log("[EaxRotation2] Engine initialized - Class: " .. plugin_info.player_class_name)
core.log("[EaxRotation2] APIs: core, izi_sdk (strict IZI-first)")
