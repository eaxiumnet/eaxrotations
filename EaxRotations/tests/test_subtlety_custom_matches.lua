-- test_subtlety_custom_matches.lua -- Subtlety custom match validation tests.
-- WHAT:  Subtlety custom match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures spec-specific match functions behave correctly under mocked combat state.
-- SAFETY: Uses synthetic context; no live game data required.

-- Gate test: Rogue Subtlety custom matches functions.
-- Matches read passed state.* + context.* (BM/MM pattern).
-- Covers: Evasion, SliceAndDice, Rupture, Eviscerate, KidneyShot, Vanish, Backstab, Hemorrhage.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function at(v,l) if not v then error(l or "fail",2) end end
local function af(v,l) if v then error(l or "fail",2) end end

local cap_gs
local combo_reader_calls = 0
_G.EaxRotations = {
  RogueSpells = { Backstab=53, Hemorrhage=16511, SliceAndDice=5171, Rupture=1943, Eviscerate=2098, KidneyShot=408, Evasion=5277, Vanish=1856, Shadowstep=36554, Sprint=2983, CheapShot=1833, Garrote=703, Ambush=8676, Sap=6770, Stealth=1787, Premeditation=14183, Blind=2094, Gouge=1776, GhostlyStrike=14278, DeadlyThrow=26679, ExposeArmor=8647, Feint=1966, Preparation=14185, Shiv=5938, Kick=1769, CloakOfShadows=31224 },
  spell_ready=function() return true end, is_spell_learned=function() return true end,
  has_player_buff=function() return false end,
  spell_action=function() return {} end,
  setting=function(context, key, default) local s=(context and context.settings) or {}; if s[key] ~= nil then return s[key] end; return default end,
  buff_remains=function() return 0 end, debuff_remains=function() return 0 end,
  broken_api_throttled=function() return false end, is_interruptible=function() return true end,
  get_spell_cd=function() return 0 end, is_behind_target=function() return true end,
  log=function() end, time_now=function() return 100 end,
  GetPlayer=function() return {} end, GetPet=function() return nil end,
  DRTracker = { is_dr_immune = function() return false end },
  OffensiveDispelDB = { find_best_dispel_target = function() return nil end },
  rotation_registry = { register = function(self,spec,strats,opts) cap_gs = opts and opts.get_state end },
}
package.loaded["shared/potion_helper_sylvanas"] = {}
package.loaded["shared/offensive_dispel_sylvanas"] = { find_best_dispel_target = function() return nil end }
package.loaded["shared/combo_points_reader_sylvanas"] = function(unit, power_type)
  combo_reader_calls = combo_reader_calls + 1
  return unit:get_power(power_type)
end
package.loaded["shared/hunter_core_sylvanas"] = nil
package.loaded["shared/targeting_sylvanas"] = nil
package.loaded["shared/cooldown_planner_sylvanas"] = nil
package.loaded["common/utility/inventory_helper"] = nil

local st = dofile("EaxRotations/classes/rogue/subtlety_sylvanas.lua").strategies
at(st, "Subtlety strategies should load")
at(cap_gs, "build_state captured")

local function fs(n) for i=1,#st do if st[i].name==n then return st[i] end end error("not found: "..n) end
local function cs(o) local s={in_combat=true,energy=80,combo=5,hp=100,target_hp=100,target_distance=5,is_behind=true,stealth_up=false,energy_pool_finisher=false,energy_low=false,slice_remains=0,rupture_remains=0,kidney_remains=0,expose_remains=0,shadowstep_buff=false,vanish_cd=0,sprint_cd=0,evasion_cd=0,threat_pct=0} if o then for k,v in pairs(o) do s[k]=v end end return s end

-- Evasion: hp gate (default 35).
local ev = fs("Evasion")
af(ev.matches({settings={}},cs({hp=80})),"Evasion high hp")
at(ev.matches({settings={}},cs({hp=20})),"Evasion low hp")

-- SliceAndDice: combo >= 2, slice not fresh, and an enemy target (2026-09-13
-- live-report fix: the finisher is cast ON the target - a self-target is
-- rejected by the client and spam-loops the queue).
local snd = fs("SliceAndDice")
af(snd.matches({settings={}},cs({combo=1})),"SND low combo")
af(snd.matches({settings={}},cs({combo=3,slice_remains=0})),"SND must hold without an enemy target")
at(snd.matches({settings={},target={}},cs({combo=3,slice_remains=0})),"SND match")

-- Rupture: combo >= 4, target alive, rupture not fresh.
local rup = fs("Rupture")
af(rup.matches({settings={}},cs({combo=2})),"Rupture low combo")
at(rup.matches({settings={},ttd=99,target={}},cs({combo=5,target_hp=100,rupture_remains=0})),"Rupture match")

-- Eviscerate: combo >= 4, energy ok.
local evi = fs("Eviscerate")
af(evi.matches({settings={}},cs({combo=2})),"Eviscerate low combo")
at(evi.matches({settings={}},cs({combo=5,energy=80})),"Eviscerate match")

-- KidneyShot: combo >= 3, not already kidney'd, PvP or low target hp.
local kid = fs("KidneyShot")
af(kid.matches({settings={}},cs({combo=2})),"Kidney low combo")
at(kid.matches({settings={},is_pvp=true,target={}},cs({combo=5,kidney_remains=0})),"Kidney match")

-- Vanish: burst reopen (stealth_up=false, should_burst).
local van = fs("Vanish")
af(van.matches({settings={}},cs({stealth_up=true})),"Vanish in stealth")
at(van.matches({settings={},should_burst=true},cs({stealth_up=false,hp=100})),"Vanish match")

-- Backstab: behind, energy, not stealth.
local bs = fs("Backstab")
af(bs.matches({settings={},target={}},cs({is_behind=false})),"Backstab not behind")
at(bs.matches({settings={},target={}},cs({is_behind=true,stealth_up=false,energy=80})),"Backstab match")

-- Dagger gate (2026-09-13): Backstab and Ambush are main-hand DAGGER abilities.
-- state.mh_dagger_ok comes from shared/dagger_set_sylvanas.classify() on the
-- equipped main-hand item id and fails OPEN - only a positive "provably not a
-- dagger" answer holds the lane, so an uncatalogued dagger cannot disable burst.
af(bs.matches({settings={},target={}},cs({is_behind=true,stealth_up=false,energy=80,mh_dagger_ok=false})),"Backstab must hold without a main-hand dagger")
at(bs.matches({settings={},target={}},cs({is_behind=true,stealth_up=false,energy=80,mh_dagger_ok=true})),"Backstab fires with a main-hand dagger")
at(bs.matches({settings={},target={}},cs({is_behind=true,stealth_up=false,energy=80})),"Backstab must fail OPEN when the field is absent")

-- Ambush shares the same gate (stealth opener).
local amb = fs("Ambush")
at(amb.matches({settings={},target={}},cs({stealth_up=true,is_behind=true,energy=80,mh_dagger_ok=true})),"Ambush fires with a main-hand dagger")
af(amb.matches({settings={},target={}},cs({stealth_up=true,is_behind=true,energy=80,mh_dagger_ok=false})),"Ambush must hold without a main-hand dagger")

-- Classifier contract behind that gate: dagger / provable non-dagger / unknown.
local dagger_data = dofile("EaxRotations/shared/dagger_set_sylvanas.lua")
at(dagger_data.classify(2819) == "dagger","Cross Dagger must classify as a dagger")
at(dagger_data.classify(25) == "other","Worn Shortsword must classify as a provable non-dagger")
at(dagger_data.classify(999999) == "unknown","an uncatalogued id must classify as unknown")
af(dagger_data.allows_dagger_ability(25),"a provable non-dagger must not allow a dagger ability")
at(dagger_data.allows_dagger_ability(999999),"an uncatalogued id must fail open")


-- Hemorrhage: energy not low.
local hem = fs("Hemorrhage")
af(hem.matches({settings={},target={}},cs({energy_low=true})),"Hemo energy low")
at(hem.matches({settings={},target={}},cs({energy_low=false,energy=80})),"Hemo match")

-- Healthstone: reads state.hp (not hp_pct) — silent fail if wrong field
local hs = fs("Healthstone")
af(hs.matches({in_combat=true},cs({hp=50,healthstone_ready=22105})),"Healthstone high hp")
at(hs.matches({in_combat=true},cs({hp=20,healthstone_ready=22105})),"Healthstone low hp")
af(hs.matches({in_combat=true},cs({hp=20,healthstone_ready=0})),"Healthstone none ready")

local stale_combo_player = {
  combo_points_current = function() return 5 end,
  get_power = function(_, power_type) if power_type == 4 then return 0 end return 0 end,
}
local authoritative_state = cap_gs({ me = stale_combo_player, target = {}, in_combat = true })
at(combo_reader_calls > 0, "Subtlety must use the shared combo-point reader")
at(authoritative_state.combo == 0, "Subtlety must preserve authoritative zero combo points")

print("PASS test_subtlety_custom_matches")
