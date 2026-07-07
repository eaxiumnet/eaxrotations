-- Gate test: Hunter Marksmanship custom matches functions.
-- Covers: HuntersMark, RapidFire, KillCommand, MultiShot, SteadyShot, ArcaneShot, SerpentSting, CallPet.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function at(v,l) if not v then error(l or "fail",2) end end
local function af(v,l) if v then error(l or "fail",2) end end

local cap_gs
_G.EaxRotations = {
  HunterSpells = { HuntersMark=1130, RapidFire=3045, KillCommand=34026, MultiShot=2643, SteadyShot=5662, ArcaneShot=3044, SerpentSting=1978, CallPet=883, RevivePet=982, AimedShot=19434, SilencingShot=34490, TrueshotAura=19506, FeignDeath=5384, Readiness=23989, FreezingTrap=1499, ViperSting=3034, WingClip=2974, RaptorStrike=2973, Volley=1510, ExplosiveTrap=13813, ConcussiveShot=5116, BestialWrath=19574, MendPet=136, AspectOfTheHawk=13165, AspectOfTheViper=34074 },
  spell_ready=function() return true end, is_spell_learned=function() return true end,
  debuff_up=function() return false end, buff_up=function() return false end,
  debuff_remains=function() return 0 end, cooldown_remains=function() return 0 end,
  broken_api_throttled=function() return false end, is_interruptible=function() return true end,
  unit_alive=function() return true end, unit_mana_pct=function() return 100 end,
  log=function() end, time_now=function() return 100 end,
  GetPlayer=function() return {} end, GetPet=function() return nil end,
  HunterClipTracker = { can_cast_steady=function() return true end, ms_until_auto=function() return 0 end, record_manual_shot=function() end },
  rotation_registry = { register = function(self,spec,strats,opts) cap_gs = opts and opts.get_state end },
}
package.loaded["shared/pet_manager_sylvanas"] = {}
package.loaded["shared/shot_timer_sylvanas"] = { should_delay_cast=function() return false end, can_cast_steady=function() return true end, can_cast_instant=function() return true end }
package.loaded["shared/potion_helper_sylvanas"] = {}
package.loaded["shared/hunter_core_sylvanas"] = nil
package.loaded["shared/targeting_sylvanas"] = nil
package.loaded["shared/cooldown_planner_sylvanas"] = nil
package.loaded["common/utility/inventory_helper"] = nil

local st = dofile("EaxRotations/classes/hunter/marksmanship_sylvanas.lua").strategies
at(st, "MM strategies should load")
at(cap_gs, "build_state captured")

local function fs(n) for i=1,#st do if st[i].name==n then return st[i] end end error("not found: "..n) end
local function cs(o) local s={in_combat=true,is_mounted=false,pet_alive=true,mana_pct=80,enemy_count=1,has_hunters_mark=false,has_serpent_sting=false,serpent_sting_remains=0,rapid_fire_ready=true,kill_command_ready=true,multi_shot_ready=true,steady_shot_ready=true,arcane_shot_ready=true,serpent_sting_ready=true,call_pet_ready=true,mend_pet_ready=true,hunters_mark_ready=true} if o then for k,v in pairs(o) do s[k]=v end end return s end

local hm=fs("HuntersMark")
af(hm.matches({target={}},cs({has_hunters_mark=true})),"HM already marked")
at(hm.matches({target={}},cs({has_hunters_mark=false,hunters_mark_ready=true})),"HM match")

local rf=fs("RapidFire")
af(rf.matches({target={}},cs({in_combat=false})),"RF OOC")
af(rf.matches({target={}},cs({rapid_fire_ready=false})),"RF not ready")
at(rf.matches({target={}},cs({in_combat=true,rapid_fire_ready=true})),"RF match")

local kc=fs("KillCommand")
af(kc.matches({target={}},cs({in_combat=false})),"KC OOC")
af(kc.matches({target={}},cs({pet_alive=false})),"KC no pet")
at(kc.matches({target={}},cs({in_combat=true,pet_alive=true,kill_command_ready=true})),"KC match")

local ms=fs("MultiShot")
af(ms.matches({target={},has_breakable_cc_nearby=true},cs({multi_shot_ready=true})),"MS near CC")
af(ms.matches({target={}},cs({multi_shot_ready=true,mana_pct=10})),"MS low mana")
at(ms.matches({target={}},cs({multi_shot_ready=true,mana_pct=50})),"MS match")

local stsh=fs("SteadyShot")
af(stsh.matches({target={}},cs({steady_shot_ready=false})),"StSh not ready")
at(stsh.matches({target={}},cs({steady_shot_ready=true})),"StSh match")

local as=fs("ArcaneShot")
af(as.matches({target={}},cs({arcane_shot_ready=true,mana_pct=10})),"AS low mana")
at(as.matches({target={}},cs({arcane_shot_ready=true,mana_pct=60})),"AS match")

local ss=fs("SerpentSting")
af(ss.matches({target={}},cs({has_serpent_sting=true,serpent_sting_remains=5})),"SS already applied")
at(ss.matches({target={}},cs({has_serpent_sting=false,serpent_sting_remains=0,serpent_sting_ready=true})),"SS match")

local cp=fs("CallPet")
af(cp.matches({},cs({has_pet=true})),"CP has pet")
af(cp.matches({},cs({has_pet=false,in_combat=true})),"CP in combat")
at(cp.matches({},cs({has_pet=false,in_combat=false,call_pet_ready=true})),"CP match")

print("PASS test_marksmanship_custom_matches")