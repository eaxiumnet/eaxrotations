-- burst_manager.lua
-- Auto-burst system: Bloodlust/Pull/Execute detection
-- Ported from Flux with Sylvanas API compliance

local burst_manager = {}

-- Cache hot-path APIs at load
local _core_time = core.time
local buff_manager = require("common/modules/buff_manager")

-- TBC Bloodlust/Heroism buff IDs
local BLOODLUST_BUFFS = {
   2825,   -- Shaman Bloodlust
   32182,  -- Shaman Heroism
}

local PULL_WINDOW_SECONDS = 5
local EXECUTE_THRESHOLD_PCT = 20

---@param me game_object Local player object
---@return boolean has_bloodlust
function burst_manager.has_bloodlust(me)
   for _, buff_id in ipairs(BLOODLUST_BUFFS) do
      local buff_data = buff_manager:get_buff_data(me, {buff_id})
      if buff_data and buff_data.is_active then
         return true
      end
   end
   return false
end

---@param me game_object Local player object
---@param target game_object|nil Target object
---@param combat_time number Seconds in combat
---@param menu table Menu reference
---@return boolean should_burst
---@return string|nil reason
function burst_manager.should_auto_burst(me, target, combat_time, menu)
   -- Check if auto-burst enabled
   local auto_burst = (menu.auto_burst_enabled and menu.auto_burst_enabled:get_state()) or false
   if not auto_burst then
      return false, nil
   end
   
   -- TTD gating - don't waste CDs on dying targets
   local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
   if min_ttd > 0 and target then
       local forecast = require("libraries/combat_forecast")
      if not forecast:is_valid_forecast_logic(min_ttd, target, false) then
         return false, "ttd"
      end
   end
   
   -- Bloodlust check
   local burst_on_bloodlust = (menu.burst_on_bloodlust and menu.burst_on_bloodlust:get_state()) or false
   if burst_on_bloodlust then
      if burst_manager.has_bloodlust(me) then
         return true, "bloodlust"
      end
   end
   
   -- Pull window check (first 5 seconds of combat)
   local burst_on_pull = (menu.burst_on_pull and menu.burst_on_pull:get_state()) or false
   if burst_on_pull then
      if combat_time < PULL_WINDOW_SECONDS then
         return true, "pull"
      end
   end
   
   -- Execute phase check
   local burst_on_execute = (menu.burst_on_execute and menu.burst_on_execute:get_state()) or false
   if burst_on_execute and target then
      local ok_max, target_max_hp = pcall(function() return target:get_max_health() end)
      if ok_max and target_max_hp and target_max_hp > 0 then
         local ok_hp, target_hp = pcall(function() return target:get_health() end)
         local target_hp_pct = 100
         if ok_hp and target_hp then
            target_hp_pct = (target_hp / target_max_hp) * 100
         end
         if target_hp_pct < EXECUTE_THRESHOLD_PCT then
            return true, "execute"
         end
      end
   end
   
   -- Always in combat
   local burst_in_combat = (menu.burst_in_combat and menu.burst_in_combat:get_state()) or false
   if burst_in_combat then
      return true, "combat"
   end
   
   return false, nil
end

---@param me game_object Local player object
---@param menu table Menu reference
---@return boolean should_use_defensive
function burst_manager.should_defensive_burst(me, menu)
   -- Check if defensive burst enabled
   local defensive_enabled = (menu.defensive_burst_enabled and menu.defensive_burst_enabled:get_state()) or false
   if not defensive_enabled then
      return false
   end
   
   local ok_max, max_hp = pcall(function() return me:get_max_health() end)
   if max_hp <= 0 then
      return false
   end
   
   local ok_hp, hp = pcall(function() return me:get_health() end)
   local hp_pct = (ok_hp and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 100
   local threshold = (menu.defensive_hp_threshold and menu.defensive_hp_threshold:get()) or 35
   
   return hp_pct < threshold
end

return burst_manager
