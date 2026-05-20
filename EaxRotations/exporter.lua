-- runtime module.

-- EaxRotations Exporter
-- Exports rotation strategies to JSON for Go simulator optimization
-- Usage: local exporter = require("exporter")
--        exporter.export_to_json("retribution_paladin.json")

local NS = _G.EaxRotations
if not NS then
   error("EaxRotations namespace not found. Ensure core_sylvanas.lua is loaded first.")
end

-- format removed: unused (no string.format calls in exporter)
local concat = table.concat
local ipairs = ipairs
local pairs = pairs
local type = type
local tostring = tostring

-- ============================================================================
-- JSON ENCODING HELPERS
-- ============================================================================

local function escape_json_string(str)
   if not str then return "null" end
   str = tostring(str)
   str = str:gsub('\\', '\\\\')
   str = str:gsub('"', '\\"')
   str = str:gsub('\n', '\\n')
   str = str:gsub('\r', '\\r')
   str = str:gsub('\t', '\\t')
   return str
end

local function encode_json_value(value)
   if value == nil then
      return "null"
   elseif type(value) == "boolean" then
      return value and "true" or "false"
   elseif type(value) == "number" then
      return tostring(value)
   elseif type(value) == "string" then
      return '"' .. escape_json_string(value) .. '"'
   elseif type(value) == "table" then
      -- Check if array
      local is_array = true
      local max_index = 0
      for k, v in pairs(value) do
         if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
            is_array = false
            break
         end
         max_index = math.max(max_index, k)
      end
      
      if is_array and max_index > 0 then
         -- Encode as array
         local parts = {}
         for i = 1, max_index do
            parts[i] = encode_json_value(value[i])
         end
         return "[" .. concat(parts, ",") .. "]"
      else
         -- Encode as object
         local parts = {}
         for k, v in pairs(value) do
            if type(k) == "string" then
               parts[#parts + 1] = '"' .. escape_json_string(k) .. '":' .. encode_json_value(v)
            end
         end
         return "{" .. concat(parts, ",") .. "}"
      end
   else
      return "null"
   end
end

-- ============================================================================
-- ROTATION EXPORT FUNCTIONS
-- ============================================================================

local exporter = {}

--- Extract spell information from a strategy
local function extract_spell_info(strategy)
   local spell_info = {
      spell_id = 0,
      spell_name = strategy.name or "Unknown",
      condition_lua = "",
      weight = strategy.priority and (strategy.priority / 1000) or 0.5,
      min_mana = 0,
      min_rage = 0,
      min_energy = 0,
      min_combo_points = 0,
      requires_combo_points = false,
      tags = {},
      is_finisher = false,
      cast_time_ms = 0,
      is_instant = true,
      gcd_ms = 1500
   }
   
   -- Extract spell ID if available
   if strategy.spell and strategy.spell.ID then
      spell_info.spell_id = strategy.spell.ID
   end
   
   -- Extract condition from matches function
   if strategy.matches then
      -- Try to get source of matches function as string
      local success, source = pcall(function()
         -- This is a best-effort attempt to capture condition logic
         return strategy.matches
      end)
      if success and source then
         spell_info.condition_lua = "function(context) return strategy.matches(context) end"
      end
   end
   
   -- Check for tags based on strategy properties
   if strategy.is_burst then
      table.insert(spell_info.tags, "burst")
   end
   if strategy.is_defensive then
      table.insert(spell_info.tags, "defensive")
   end
   if strategy.is_aoe then
      table.insert(spell_info.tags, "aoe")
   else
      table.insert(spell_info.tags, "single_target")
   end
   
   -- Check for finisher
   if strategy.requires_combo_points or strategy.is_finisher then
      spell_info.is_finisher = true
      spell_info.requires_combo_points = true
   end
   
   return spell_info
end

--- Export a single rotation strategy to RotationStrategy format
function exporter.export_rotation(playstyle_name)
   local registry = NS.rotation_registry
   if not registry then
      error("Rotation registry not found")
   end
   
   -- Get class config
   local class_config = NS.class_config
   if not class_config then
      error("Class config not found")
   end
   
   local class = class_config.class or "unknown"
   local spec = playstyle_name
   
   -- Get strategies for this playstyle
   local strategies = registry.strategy_maps and registry.strategy_maps[playstyle_name]
   if not strategies then
      error("No strategies found for playstyle: " .. tostring(playstyle_name))
   end
   
   -- Build rotation strategy
   local rotation = {
      name = class_config.playstyle_labels and class_config.playstyle_labels[playstyle_name] or playstyle_name,
      class = class,
      spec = spec,
      priorities = {},
      cooldowns = {},
      conditions = {},
      buffs = {},
      resources = {},
      version = "1.0.15",
      author = "EaxRotations",
      exported_at = math.floor(NS.time_now() or 0)
   }
   
   -- Export each strategy as a spell priority
   for i, strategy in ipairs(strategies) do
      local spell_priority = extract_spell_info(strategy)
      spell_priority.weight = 1.0 - (i * 0.01)  -- Higher priority = higher weight
      table.insert(rotation.priorities, spell_priority)
   end
   
   -- Export middleware as cooldown rules
   local middleware = registry.middleware
   if middleware then
      for i, mw in ipairs(middleware) do
         if mw.is_burst or mw.is_defensive then
            local cooldown_rule = {
               spell_id = mw.spell and mw.spell.ID or 0,
               condition_lua = "",
               priority = mw.is_burst and "burst_only" or "emergency",
               min_enemies = 0,
               max_enemies = 0,
               save_for_execute = false,
               health_threshold_percent = 100,
               use_on_pull = mw.is_burst or false,
               min_time_into_fight_sec = 0
            }
            table.insert(rotation.cooldowns, cooldown_rule)
         end
      end
   end
   
   return rotation
end

--- Export all rotations for current class
function exporter.export_all_rotations()
   local registry = NS.rotation_registry
   if not registry or not registry.strategy_maps then
      error("No rotations registered")
   end
   
   local rotations = {}
   for playstyle_name, _ in pairs(registry.strategy_maps) do
      local success, rotation = pcall(function()
         return exporter.export_rotation(playstyle_name)
      end)
      if success and rotation then
         table.insert(rotations, rotation)
      end
   end
   
   return rotations
end

--- Export to JSON string
function exporter.to_json(rotation_or_rotations)
   local export_data = {
      export_version = "1.0.15",
      exported_at = math.floor(NS.time_now() or 0),
      source_addon = "Sylvanas",
      game_version = "2.5.4",
      rotations = type(rotation_or_rotations) == "table" and rotation_or_rotations[1] and rotation_or_rotations or {rotation_or_rotations},
      metadata = {
         exporter_version = "1.0.15",
         export_reason = "optimization"
      }
   }
   
   return encode_json_value(export_data)
end

--- Export to file (in-game or offline)
function exporter.export_to_json(filepath, playstyle_name)
   local rotation
   if playstyle_name then
      rotation = exporter.export_rotation(playstyle_name)
   else
      -- Export current active rotation
      local current_playstyle = NS.current_playstyle or "default"
      rotation = exporter.export_rotation(current_playstyle)
   end
   
   local json_str = exporter.to_json(rotation)
   
   -- Try to write to file if in WoW environment with file I/O
   if _G.EaxRotations and _G.EaxRotations.write_file then
      local success = _G.EaxRotations.write_file(filepath, json_str)
      if success then
         NS.log("Exported rotation to: " .. filepath)
      else
         NS.log("Failed to write file: " .. filepath)
      end
   else
      -- In offline mode, just return the JSON string
      NS.log("JSON export ready (length: " .. #json_str .. " chars)")
      return json_str
   end
end

--- Export for Go simulator optimization
function exporter.export_for_sim(playstyle_name, profile_name)
   local rotation = exporter.export_rotation(playstyle_name or NS.current_playstyle)
   
   local sim_export = {
      rotation = rotation,
      profile = profile_name or "default",
      iterations = 10000,
      duration_sec = 300,
      target_type = "dummy",
      target_level = 73,
      target_armor = 7700,
      buffs = {
         flask = true,
         food = true,
         scroll = true,
         weapon_buff = true
      }
   }
   
   return encode_json_value(sim_export)
end

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

NS.rotation_exporter = exporter

-- Return module for require()
return exporter
