-- test_enhancement_custom_matches.lua -- Enhancement custom match validation tests.
-- WHAT:  Enhancement custom match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures spec-specific match functions behave correctly under mocked combat state.
-- SAFETY: Uses synthetic context; no live game data required.

-- Gate test: Shaman Enhancement custom matches functions.
-- These read module-level enh_state (populated by build_state), so we drive them
-- via cap_gs(context) then call strategy.matches(context).
-- Covers: LightningBolt, ChainLightning, FrostShock, EarthShock(dps), LesserHealingWave, GhostWolf.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function at(v,l) if not v then error(l or "fail",2) end end
local function af(v,l) if v then error(l or "fail",2) end end

local cap_gs
local me_mock = { is_moving=function() return false end, get_level=function() return 70 end, get_distance=function() return 5 end, is_valid=function() return true end, get_health_percentage=function() return 100 end, get_mana_pct=function() return 100 end }
local NS = {
  ShamanSpells = { LightningBolt=403, ChainLightning=421, FrostShock=8056, EarthShock=8042, FlameShock=8050, Stormstrike=17364, LesserHealingWave=331, GhostWolf=2645, LightningShield=324, WaterShield=52127, Bloodlust=2825, WindfuryWeapon=8232, FlametongueWeapon=8024, RockbiterWeapon=8017 },
  spell_ready=function() return true end, is_spell_learned=function() return true end,
  buff_up=function() return false end, debuff_up=function() return false end,
  debuff_remains=function() return 0 end, buff_remains=function() return 0 end,
  cooldown_remains=function() return 0 end, broken_api_throttled=function() return false end,
  is_interruptible=function() return true end, game_time_ms=function() return 1000 end,
  unit_mana_pct=function() return 100 end, unit_health_pct=function() return 100 end,
  log=function() end, GetPlayer=function() return me_mock end, GetPet=function() return nil end,
  gate_cooldown_boss_only = function(ctx) return true end,
  PLAYER_UNIT = me_mock,
  should_use_long_cd = function(ctx, cd)
      if not ctx or not ctx.combat_length_forecast then return true end
      if ctx.target_is_boss then return true end
      local forecast = ctx.combat_length_forecast
      if cd >= 180 and forecast < 60 then return false end
      if cd >= 120 and forecast < 45 then return false end
      if cd >= 60 and forecast < 30 then return false end
      return true
  end,
  WeaponImbueManager = { mainhand_has_imbue=function() return false end, offhand_has_imbue=function() return false end, get_mainhand_enchant_info=function() return nil end, get_offhand_enchant_info=function() return nil end },
  rotation_registry = { register = function(self,spec,strats,opts) cap_gs = opts and opts.get_state end },
}
_G.EaxRotations = NS
package.loaded["shared/potion_helper_sylvanas"] = {}
package.loaded["shared/hunter_core_sylvanas"] = nil
package.loaded["shared/targeting_sylvanas"] = nil
package.loaded["shared/cooldown_planner_sylvanas"] = nil
package.loaded["common/utility/inventory_helper"] = nil

local st = dofile("EaxRotations/classes/shaman/enhancement_sylvanas.lua").strategies
at(st, "Enhancement strategies should load")
at(cap_gs, "build_state captured")

local function fs(n) for i=1,#st do if st[i].name==n then return st[i] end end error("not found: "..n) end
local function setup(ctx) cap_gs(ctx); return ctx end

-- LightningBolt: OOC only (in_combat -> false). Ready default true.
local lb = fs("LightningBolt")
af(lb.matches(setup({ in_combat=true, enemy_count=1, mana_pct=80, hp=100, target={}, settings={} })), "LB in combat")
at(lb.matches(setup({ in_combat=false, enemy_count=1, mana_pct=80, hp=100, target={}, settings={} })), "LB OOC match")

-- ChainLightning: single mode + <2 enemies -> no match; >=2 -> match.
local cl = fs("ChainLightning")
af(cl.matches(setup({ in_combat=true, enemy_count=1, mana_pct=80, hp=100, target={}, settings={ enhancement_combat_mode="single" } })), "CL single 1 enemy")
at(cl.matches(setup({ in_combat=true, enemy_count=3, mana_pct=80, hp=100, target={}, settings={ enhancement_combat_mode="single" } })), "CL single 3 enemies")

-- FrostShock: mana_low gate.
local fsh = fs("FrostShock")
af(fsh.matches(setup({ in_combat=true, enemy_count=1, mana_pct=5, hp=100, target={}, settings={} })), "FrostShock low mana")
at(fsh.matches(setup({ in_combat=true, enemy_count=1, mana_pct=80, hp=100, target={}, settings={} })), "FrostShock match")

-- EarthShock (dps mode): needs target_has_flame_shock.
local es = fs("EarthShock")
NS.debuff_up = function() return false end
af(es.matches(setup({ in_combat=true, enemy_count=1, mana_pct=80, hp=100, target={}, settings={ enhancement_earth_shock_mode="dps" } })), "EarthShock no flame shock")
NS.debuff_up = function() return true end
at(es.matches(setup({ in_combat=true, enemy_count=1, mana_pct=80, hp=100, target={}, settings={ enhancement_earth_shock_mode="dps" } })), "EarthShock with flame shock")

-- LesserHealingWave: hp gate (self_heal_hp default 40).
local lhw = fs("LesserHealingWave")
af(lhw.matches(setup({ in_combat=true, enemy_count=1, mana_pct=80, hp=80, settings={} })), "LHW high hp")
at(lhw.matches(setup({ in_combat=true, enemy_count=1, mana_pct=80, hp=20, settings={} })), "LHW low hp")

-- GhostWolf: OOC only; use_ooc_buffs=false blocks; has_ghost_wolf blocks (buff_up=false).
local gw = fs("GhostWolf")
af(gw.matches(setup({ in_combat=true, enemy_count=1, mana_pct=80, hp=100, settings={} })), "GW in combat")
af(gw.matches(setup({ in_combat=false, enemy_count=1, mana_pct=80, hp=100, settings={ use_ooc_buffs=false } })), "GW ooc buffs off")
at(gw.matches(setup({ in_combat=false, enemy_count=1, mana_pct=80, hp=100, settings={} })), "GW OOC match")

-- Bloodlust: combat_forecast gate blocks on short fights, allows on long fights/boss.
local bl = fs("Bloodlust")
af(bl.matches(setup({ in_combat=true, enemy_count=1, mana_pct=80, hp=100, target={}, settings={}, combat_length_forecast=20 })), "Bloodlust short fight blocked")
at(bl.matches(setup({ in_combat=true, enemy_count=1, mana_pct=80, hp=100, target={}, settings={}, combat_length_forecast=120 })), "Bloodlust long fight allowed")
at(bl.matches(setup({ in_combat=true, enemy_count=1, mana_pct=80, hp=100, target={}, settings={}, combat_length_forecast=10, target_is_boss=true })), "Bloodlust boss allowed")

print("PASS test_enhancement_custom_matches")