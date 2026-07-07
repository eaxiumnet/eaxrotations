-- Gate test: Hunter Survival custom matches functions.
-- Covers: KillCommand, MultiShot, SteadyShot, ArcaneShot, SerpentSting, ExplosiveTrap, WyvernSting, MongooseBite.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function at(v,l) if not v then error(l or "fail",2) end end
local function af(v,l) if v then error(l or "fail",2) end end

local cap_gs
_G.EaxRotations = {
  HunterSpells = { HuntersMark=1130, RapidFire=3045, KillCommand=34026, MultiShot=2643, SteadyShot=5662, ArcaneShot=3044, SerpentSting=1978, CallPet=883, RevivePet=982, FeignDeath=5384, Readiness=23989, FreezingTrap=1499, ViperSting=3034, WingClip=2974, RaptorStrike=2973, Volley=1510, ExplosiveTrap=13813, ImmolationTrap=13795, SnakeTrap=34600, ConcussiveShot=5116, WyvernSting=19386, ScorpidSting=3043, MongooseBite=1495, Misdirection=34477, MendPet=136, AspectOfTheHawk=13165, AspectOfTheViper=34074 },
  spell_ready=function() return true end, is_spell_learned=function() return true end,
  debuff_up=function() return false end, buff_up=function() return false end,
  debuff_remains=function() return 0 end, cooldown_remains=function() return 0 end,
  broken_api_throttled=function() return false end, is_interruptible=function() return true end,
  unit_alive=function() return true end, unit_mana_pct=function() return 100 end,
  log=function() end, time_now=function() return 100 end,
  GetPlayer=function() return {} end, GetPet=function() return nil end,
  DRTracker = { is_dr_immune = function() return false end },
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

local st = dofile("EaxRotations/classes/hunter/survival_sylvanas.lua").strategies
at(st, "Survival strategies should load")
at(cap_gs, "build_state captured")

local function fs(n) for i=1,#st do if st[i].name==n then return st[i] end end error("not found: "..n) end
local function cs(o) local s={in_combat=true,pet_alive=true,mana_pct=80,enemy_count=3,distance_sq=25,kill_command_ready=true,multi_shot_ready=true,steady_shot_ready=true,arcane_shot_ready=true,serpent_sting_ready=true,explosive_trap_ready=true,wyvern_sting_ready=true,mongoose_bite_ready=true,has_serpent_sting=false,has_scorpid_sting=false,hunter_melee_weave=true} if o then for k,v in pairs(o) do s[k]=v end end return s end

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
af(as.matches({target={}},cs({arcane_shot_ready=true,mana_pct=5})),"AS low mana")
at(as.matches({target={}},cs({arcane_shot_ready=true,mana_pct=60})),"AS match")

local ss=fs("SerpentSting")
af(ss.matches({target={}},cs({has_serpent_sting=true,serpent_sting_ready=true})),"SS already applied")
at(ss.matches({target={}},cs({has_serpent_sting=false,serpent_sting_ready=true})),"SS match")

local et=fs("ExplosiveTrap")
af(et.matches({target={}},cs({enemy_count=2})),"ET too few")
af(et.matches({target={}},cs({enemy_count=3,explosive_trap_ready=false})),"ET not ready")
at(et.matches({target={}},cs({enemy_count=3,explosive_trap_ready=true})),"ET match")

local wy=fs("WyvernSting")
af(wy.matches({target={}},cs({wyvern_sting_ready=true})),"Wy PvE solo")
af(wy.matches({is_pvp=true,target={}},cs({wyvern_sting_ready=true,has_serpent_sting=true})),"Wy breaks own DoT")
at(wy.matches({is_pvp=true,target={}},cs({wyvern_sting_ready=true,has_serpent_sting=false,has_scorpid_sting=false})),"Wy match")

local mb=fs("MongooseBite")
af(mb.matches({target={}},cs({in_combat=false})),"MB OOC")
af(mb.matches({target={}},cs({distance_sq=900,mongoose_bite_ready=true})),"MB too far")
at(mb.matches({target={}},cs({in_combat=true,distance_sq=25,mongoose_bite_ready=true})),"MB match")

print("PASS test_survival_custom_matches")