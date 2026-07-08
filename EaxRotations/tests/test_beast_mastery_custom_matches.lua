-- test_beast_mastery_custom_matches.lua -- Beast Mastery custom match validation tests.
-- WHAT:  Beast Mastery custom match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures spec-specific match functions behave correctly under mocked combat state.
-- SAFETY: Uses synthetic context; no live game data required.

-- Gate test: Hunter Beast Mastery custom matches functions.
-- Covers: KillCommand, BestialWrath, SerpentSting, ArcaneShot, SteadyShot, MultiShot, Volley.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function at(v,l) if not v then error(l or "fail",2) end end
local function af(v,l) if v then error(l or "fail",2) end end

local cap_gs
_G.EaxRotations = {
  HunterSpells = { AspectOfTheHawk=13165, ArcaneShot=3044, SerpentSting=1978, KillCommand=34026, SteadyShot=5662, MultiShot=2643, BestialWrath=19574, RapidFire=3045, FeignDeath=5384, Readiness=23989, HuntersMark=1130, FreezingTrap=1499, ExplosiveTrap=13813, ConcussiveShot=5116, Volley=1510, Intimidation=19577, Misdirection=34477, MendPet=136, CallPet=883, RevivePet=982 },
  spell_ready=function() return true end, is_spell_learned=function() return true end,
  debuff_up=function() return false end, buff_up=function() return false end,
  debuff_remains=function() return 0 end, cooldown_remains=function() return 0 end,
  gate_cooldown_boss_only=function() return true end, broken_api_throttled=function() return false end,
  log=function() end, time_now=function() return 100 end,
  GetPlayer=function() return {} end, GetPet=function() return nil end,
  unit_mana_pct=function() return 100 end,
  rotation_registry = { register = function(self,spec,strats,opts) cap_gs = opts and opts.get_state end },
  HunterCore = { get_pet=function() return nil end, pet_alive=function() return false end, pet_hp_pct=function() return 100 end, can_cast_steady=function() return true end, can_cast_instant=function() return true end, should_feign_death=function() return false end, sting_remains=function() return 0 end },
}
package.loaded["shared/hunter_core_sylvanas"] = _G.EaxRotations.HunterCore
package.loaded["shared/pet_manager_sylvanas"] = {}
package.loaded["shared/potion_helper_sylvanas"] = {}
package.loaded["shared/shot_timer_sylvanas"] = { should_delay_cast=function() return false end, can_cast_steady=function() return true end, can_cast_instant=function() return true end }
package.loaded["shared/targeting_sylvanas"] = {}
package.loaded["shared/cooldown_planner_sylvanas"] = nil
package.loaded["common/utility/inventory_helper"] = nil

local st = dofile("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua").strategies
at(st, "BM strategies should load")
at(cap_gs, "build_state captured")
cap_gs({ in_combat=true, me={}, target={} })

local function fs(n) for i=1,#st do if st[i].name==n then return st[i] end end error("not found: "..n) end
local function cs(o) local s={in_combat=true,is_mounted=false,pet_alive=true,mana_pct=80,enemy_count=1,in_dead_zone=false,sting_mode="serpent",multishot_mode=2,aoe_threshold=3,use_volley=true,use_cooldowns=true,shot_buffer=150,kill_command_ready=true,bestial_wrath_ready=true,intimidation_ready=true,multi_shot_ready=true,arcane_shot_ready=true,steady_shot_ready=true,serpent_sting_ready=true,volley_ready=true,has_serpent_sting=false,major_cd_window=false} if o then for k,v in pairs(o) do s[k]=v end end return s end

local kc=fs("KillCommand")
af(kc.matches({in_combat=false},cs({in_combat=false})),"KC OOC")
af(kc.matches({in_combat=true},cs({pet_alive=false})),"KC no pet")
at(kc.matches({in_combat=true,target={}},cs()),"KC match")

local ss=fs("SerpentSting")
af(ss.matches({in_combat=false},cs({in_combat=false})),"SS OOC")
af(ss.matches({in_combat=true},cs()),"SS no target")
af(ss.matches({in_combat=true,target={get_health_percentage=function() return 100 end}},cs({has_serpent_sting=true})),"SS already applied")
af(ss.matches({in_combat=true,target={get_health_percentage=function() return 10 end}},cs()),"SS low HP")
at(ss.matches({in_combat=true,target={get_health_percentage=function() return 80 end}},cs()),"SS match")

local as=fs("ArcaneShot")
af(as.matches({in_combat=false},cs({in_combat=false})),"AS OOC")
af(as.matches({in_combat=true,target={}},cs({arcane_shot_ready=false})),"AS not ready")
af(as.matches({in_combat=true,target={}},cs({mana_pct=30})),"AS low mana")
at(as.matches({in_combat=true,target={}},cs({mana_pct=60})),"AS match")

local stsh=fs("SteadyShot")
af(stsh.matches({in_combat=false},cs({in_combat=false})),"StSh OOC")
af(stsh.matches({in_combat=true,is_moving=true,target={}},cs()),"StSh moving")
at(stsh.matches({in_combat=true,is_moving=false,target={}},cs()),"StSh match")

local ms=fs("MultiShot")
af(ms.matches({in_combat=false},cs({in_combat=false})),"MS OOC")
af(ms.matches({in_combat=true,target={}},cs({enemy_count=1})),"MS too few")
af(ms.matches({in_combat=true,target={},has_breakable_cc_nearby=true},cs({enemy_count=3})),"MS near CC")
at(ms.matches({in_combat=true,target={}},cs({enemy_count=3,mana_pct=50})),"MS match")

local vol=fs("Volley")
af(vol.matches({in_combat=true,target={}},cs({use_volley=false})),"Vol disabled")
af(vol.matches({in_combat=true,target={}},cs({enemy_count=2})),"Vol too few")
af(vol.matches({in_combat=true,is_moving=true,target={}},cs({enemy_count=4})),"Vol moving")
at(vol.matches({in_combat=true,is_moving=false,target={}},cs({enemy_count=4})),"Vol match")

local bw=fs("BestialWrath")
af(bw.matches({in_combat=true,target={}},cs({pet_alive=false})),"BW no pet")
af(bw.matches({in_combat=true,combat_time=10,ttd=120,target={}},cs()),"BW early")
at(bw.matches({in_combat=true,combat_time=50,ttd=120,target={}},cs()),"BW timeout")

print("PASS test_beast_mastery_custom_matches")