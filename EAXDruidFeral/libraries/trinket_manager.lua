-- trinket_manager.lua
-- Trinket automation: Offensive/defensive modes with TTD gating, burst conditions, and force command integration
-- Ported from Flux with Sylvanas API compliance

local trinket_manager = {}

-- Mode constants for per-trinket configuration
local OFF = 0
local OFFENSIVE = 1
local DEFENSIVE = 2

-- Cache hot-path APIs at load
local _core_time = core.time
local _is_item_ready = core.spell_book.is_item_ready
local _use_item = core.input.use_item
local _get_local_player = core.object_manager.get_local_player

local TRINKET_SLOTS = {13, 14}  -- Top trinket, Bottom trinket
local DEFAULT_OFFENSIVE_TTD = 10  -- Don't use offensive trinket if target dies in <10s
local DEFAULT_DEFENSIVE_HP = 35   -- Use defensive trinket below 35% HP

-- Export constants for external use
trinket_manager.OFF = OFF
trinket_manager.OFFENSIVE = OFFENSIVE
trinket_manager.DEFENSIVE = DEFENSIVE

---@param slot number Equipment slot (13 or 14)
---@return boolean success
function trinket_manager.use_trinket_if_ready(slot)
   -- Get local player
   local me = _get_local_player()
   if not me then
      return false
   end
   
   -- Get item info
   local ok_item, item = pcall(function() return me:get_equipped_item(slot) end)
    if not ok_item then return false end
    item = item
   local item_id = item and item.id or nil
   if not item_id or item_id == 0 then
      return false
   end
   
   -- Check cooldown
   local ok_cd, start, duration = pcall(function() return me:get_item_cooldown(slot) end)
    if not ok_cd then return false end
   if start > 0 then
      local remaining = start + duration - _core_time()
      if remaining > 0 then
         return false
      end
   end
   
   -- Check if usable
   if not _is_item_ready(item_id) then
      return false
   end
   
   -- Use item
   _use_item(slot)
   return true
end

---@param me game_object Local player object
---@param is_burst_window boolean Whether we're in a burst window
---@param menu table Menu reference
function trinket_manager.check_trinkets(me, is_burst_window, menu)
   if not me then return end
   local ok, target = pcall(function() return me:get_target() end)
   if not ok or not target then return end
    local combat_forecast = require("combat_forecast")
   
   for _, slot in ipairs(TRINKET_SLOTS) do
      local slot_num = slot - 12  -- 13->1, 14->2
      local mode_key = "trinket" .. slot_num .. "_mode"
      local mode = (menu[mode_key] and menu[mode_key]:get()) or 1  -- 1 = off
      
      if mode == 2 then  -- Offensive mode
         if is_burst_window then
            -- TTD gate for offensive trinkets
            if target then
               if combat_forecast:is_valid_forecast_logic(DEFAULT_OFFENSIVE_TTD, target, false) then
                  trinket_manager.use_trinket_if_ready(slot)
               end
            else
               -- No target, but burst window active (might be AoE)
               trinket_manager.use_trinket_if_ready(slot)
            end
         end
      elseif mode == 3 then  -- Defensive mode
         local ok_max, max_hp = pcall(function() return me:get_max_health() end)
         if not ok_max or not max_hp or max_hp <= 0 then max_hp = 1 end
         local ok_hp, hp = pcall(function() return me:get_health() end)
         if not ok_hp or not hp then hp = 0 end
         local hp_pct = (hp / max_hp) * 100
            if hp_pct < DEFAULT_DEFENSIVE_HP then
               trinket_manager.use_trinket_if_ready(slot)
            end
      end
   end
end

---@param menu table Menu reference
---@return table trinket_status Array of {slot, mode, ready}
function trinket_manager.get_trinket_status(menu)
   local status = {}
   local me = _get_local_player()
   
   for _, slot in ipairs(TRINKET_SLOTS) do
      local slot_num = slot - 12
      local mode_key = "trinket" .. slot_num .. "_mode"
      local mode = (menu[mode_key] and menu[mode_key]:get()) or 1
      
      local ok_item, item = pcall(function() if me and me.get_equipped_item then return me:get_equipped_item(slot) end return nil end)
      if not ok_item then item = nil end
      local item_id = item and item.id or nil
      local has_trinket = item_id and item_id > 0
      
      local ready = false
      if has_trinket and me then
         local ok_cd, start, duration = pcall(function() return me:get_item_cooldown(slot) end)
    if not ok_cd then return false end
         ready = start == 0 or (_core_time() >= start + duration)
      end
      
      table.insert(status, {
         slot = slot,
         mode = mode,
         has_trinket = has_trinket,
         ready = ready
      })
   end
   
   return status
end

-- ============================================================================
-- V2 ENHANCED API (TTD gating, burst conditions, force command integration)
-- ============================================================================

---Get trinket mode from menu for a specific slot
---Slot 1 = top (13), Slot 2 = bottom (14)
---Menu values: 1 = Off, 2 = Offensive, 3 = Defensive
---@param menu table Menu reference
---@param slot number Slot number (1 or 2)
---@return number mode OFF(0), OFFENSIVE(1), or DEFENSIVE(2)
function trinket_manager:get_trinket_mode(menu, slot)
   if not menu then return OFF end
   
   local mode_key = "trinket" .. slot .. "_mode"
   local menu_val = (menu[mode_key] and menu[mode_key]:get()) or 1
   
   -- Convert menu values (1,2,3) to constants (0,1,2)
   -- Menu: 1=Off, 2=Offensive, 3=Defensive
   if menu_val == 2 then
      return OFFENSIVE
   elseif menu_val == 3 then
      return DEFENSIVE
   else
      return OFF
   end
end

---Check if offensive trinket should fire based on TTD
---Returns false if target is dying (TTD < min_ttd)
---Returns true if TTD is sufficient or unknown
---@param ttd number|nil Time-to-death in seconds (from combat_forecast)
---@param min_ttd number Minimum acceptable TTD threshold
---@return boolean should_fire
function trinket_manager:should_fire_offensive(ttd, min_ttd)
   min_ttd = min_ttd or DEFAULT_OFFENSIVE_TTD
   
   -- If TTD is nil (insufficient data), assume it's worth using
   if ttd == nil then
      return true
   end
   
   -- Don't fire if target is dying too fast
   return ttd >= min_ttd
end

---Check if defensive trinket should fire based on HP
---@param me game_object Local player object
---@param threshold number HP percentage threshold (0-100)
---@return boolean should_fire
function trinket_manager:should_fire_defensive(me, threshold)
   threshold = threshold or DEFAULT_DEFENSIVE_HP
   
   if not me then return false end
   
   local ok_max, max_hp = pcall(function() return me:get_max_health() end)
   if not ok_max or not max_hp or max_hp <= 0 then
      return false
   end
   
   local ok_hp, hp = pcall(function() return me:get_health() end)
   if not ok_hp or not hp then hp = 0 end
   local hp_pct = (hp / max_hp) * 100
   
   return hp_pct < threshold
end

---Enhanced trinket check with TTD gating, burst conditions, and force command integration
---@param me game_object Local player object
---@param target game_object|nil Current target
---@param is_burst_active boolean Whether rotation considers this a burst window
---@param force_commands table Force commands module (libraries/force_commands.lua)
---@param combat_forecast table Combat forecast module (libraries/combat_forecast.lua)
---@param menu table Menu reference with trinket1_mode, trinket2_mode, etc.
---@param opts table|nil Optional configuration overrides
function trinket_manager:check_trinkets_v2(me, target, is_burst_active, force_commands, combat_forecast, menu, opts)
   opts = opts or {}
   
   -- Get configurable thresholds from opts or use defaults
   local offensive_ttd = opts.offensive_ttd or DEFAULT_OFFENSIVE_TTD
   local defensive_hp = opts.defensive_hp or DEFAULT_DEFENSIVE_HP
   
   -- Check if force burst is active (from /eax burst command)
   local force_burst = false
   if force_commands and force_commands.is_burst_active then
      force_burst = force_commands:is_burst_active()
   end
   
   -- Get TTD from combat_forecast if available
   local ttd = nil
   if combat_forecast and combat_forecast.get_ttd and target then
      ttd = combat_forecast:get_ttd(target)
   end
   
   -- Process each trinket slot
   for _, slot in ipairs(TRINKET_SLOTS) do
      local slot_num = slot - 12  -- 13->1, 14->2
      local mode = self:get_trinket_mode(menu, slot_num)
      
      if mode == OFFENSIVE then
         -- Check if offensive trinket should fire
         local should_fire = false
         
         -- Fire if normal burst window is active OR force burst is active
         if is_burst_active or force_burst then
            -- Apply TTD gating: skip if target dying
            if self:should_fire_offensive(ttd, offensive_ttd) then
               should_fire = true
            end
         end
         
         -- Boss/Elite check: Only fire on bosses/elites unless forced
         if should_fire and not force_burst then
            local is_boss = opts.is_boss or false
            local is_elite = opts.is_elite or false
            if not is_boss and not is_elite then
               should_fire = false  -- Don't waste trinkets on trash mobs
            end
         end
         
         if should_fire then
            self.use_trinket_if_ready(slot)
         end
         
      elseif mode == DEFENSIVE then
         -- Check if defensive trinket should fire
         local should_fire = false
         
         -- Check force defensive command
         local force_def = false
         if force_commands and force_commands.is_defensive_active then
            force_def = force_commands:is_defensive_active()
         end
         
         -- Fire if HP below threshold OR force defensive is active
         if force_def or self:should_fire_defensive(me, defensive_hp) then
            should_fire = true
         end
         
         if should_fire then
            self.use_trinket_if_ready(slot)
         end
      end
      -- mode == OFF: do nothing
   end
end

---Use trinket via IZI SDK (alternative to native API)
---@param slot number Equipment slot (13 or 14)
---@return boolean success
function trinket_manager.use_trinket_izi(slot)
   local me = _get_local_player()
   if not me then
      return false
   end
   
   local ok_item, item = pcall(function() return me:get_equipped_item(slot) end)
    if not ok_item then return false end
    item = item
   local item_id = item and item.id or nil
   if not item_id or item_id == 0 then
      return false
   end
   
   -- Use IZI SDK if available
   local izi_item = izi.item(item_id)
   if izi_item and izi_item.is_ready and izi_item.is_ready() then
      if izi_item.use_self_safe then
         izi_item:use_self_safe()
         return true
      end
   end
   
   return false
end

return trinket_manager

