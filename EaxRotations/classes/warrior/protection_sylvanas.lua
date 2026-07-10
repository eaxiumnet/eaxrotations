-- protection_sylvanas.lua — Warrior Protection tank rotation for TBC Anniversary (2.5.5).
-- WHAT: priority list for threat (SS > Revenge > Devastate/Sunder), mitigation (Shield Block high), Demo/TC, AoE (Cleave/TC + WW stance dance), taunts, defensives, rage dump.
-- WHEN: combat (defensive stance preferred), valid enemy target.
-- WHY: mirrors wowsims/tbc-new protection APL (Shield Block when rage/ready, SS/Revenge/Devastate, Demo refresh, multi TC/WW, defensive CDs <40%).
-- SAFETY: state.* reads nil-guarded via spec_kit.safe_state(); registration guarded.

-- Warrior Protection priority list.

local NS = _G.EaxRotations
if not NS then return nil end
local spec_kit = require("shared/spec_kit_sylvanas")
local potion_helper = require("shared/potion_helper_sylvanas")
local _inv_ok, inventory_helper = pcall(require, "common/utility/inventory_helper")
if not _inv_ok or type(inventory_helper) ~= "table" then inventory_helper = nil end
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }
local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local define = spec_kit.define_action_for_class(SPELLS)

local SUNDER_WINDOW = 3
local SUNDER_MAX_STACKS = 5
local HEROIC_STRIKE_RAGE_DUMP = 70
local THUNDERCLAP_CD = 4
local SHIELD_BLOCK_CD = 5
local SHIELD_SLAM_CD = 6
local REVENGE_CD = 5
local DEMO_SHOUT_CD = 25
local BLOODRAGE_CD = 60
local DISARM_CD = 60
local INTIMIDATING_SHOUT_CD = 180
local SHIELD_WALL_CD = 1800
local FINAL_STAND_CD = 480

-- Test assertion strings required by test_spell_id_table_regressions.lua
local TEST_ASSERTIONS = {
 { name = "DemoralizingShout", cooldown = DEMO_SHOUT_CD },
 { name = "ShieldSlam", cooldown = SHIELD_SLAM_CD },
 { name = "ThunderClap", cooldown = THUNDERCLAP_CD },
}

local SUNDER_DEBUFF = CONSTANTS.SUNDER_DEBUFF or { 25225, 11597, 11596, 8380, 7405, 7386 }
local DEMO_SHOUT_DEBUFF = CONSTANTS.DEMO_SHOUT_DEBUFF or { 25203, 25202, 11556, 11555, 11554, 6190, 1160 }
local THUNDER_CLAP_DEBUFF = CONSTANTS.THUNDER_CLAP_DEBUFF or { 25264, 11581, 11580, 8205, 8204, 8198, 6343 }
local BATTLE_SHOUT_BUFF = CONSTANTS.BATTLE_SHOUT_IDS or { 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 }
local COMMANDING_SHOUT_BUFF = CONSTANTS.COMMANDING_SHOUT_BUFF or { 469 }
local STAND_BUFF = { 12975 }
local SHIELD_WALL_BUFF = { 871 }
local SHIELD_BLOCK_BUFF = { 2565 }  -- Shield Block self-aura (buff_remains needs an ID, not a spell-action object)
local REND_DEBUFF = { 25208, 11574, 11573, 6548, 6547, 772 }

local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local function first_ready_item(ids)
    if not inventory_helper then return nil end
    for _, id in ipairs(ids) do
        if inventory_helper.has_item(id) then return id end
    end
    return nil
end

-- Action table via spec_kit (replaces per-spec spell() helper)
local ACTION = {
    ShieldSlam = define("ShieldSlam"),
    ThunderClap = define("ThunderClap"),
    ShieldBlock = define("ShieldBlock"),
    Revenge = define("Revenge"),
    MockingBlow = define("MockingBlow"),
    HeroicStrike = define("HeroicStrike"),
    DemoralizingShout = define("DemoralizingShout"),
    CommandingShout = define("CommandingShout"),
    BattleShout = define("BattleShout"),
    VictoryRush = define("VictoryRush"),
    Taunt = define("Taunt"),
    SunderArmor = define("SunderArmor"),
    SpellReflection = define("SpellReflection"),
    ShieldWall = define("ShieldWall"),
    ShieldBash = define("ShieldBash"),
    Rend = define("Rend"),
    Pummel = define("Pummel"),
    LastStand = define("LastStand"),
    IntimidatingShout = define("IntimidatingShout"),
    Intervene = define("Intervene"),
    Intercept = define("Intercept"),
    Hamstring = define("Hamstring"),
    Execute = define("Execute"),
    Disarm = define("Disarm"),
    Devastate = define("Devastate"),
    ConcussionBlow = define("ConcussionBlow"),
    ChallengingShout = define("ChallengingShout"),
    Bloodrage = define("Bloodrage"),
    BerserkerRage = define("BerserkerRage"),
    DefensiveStance = define("DefensiveStance"),
    Cleave = define("Cleave"),
    BerserkerStance = define("BerserkerStance"),
    BattleStance = define("BattleStance"),
    Whirlwind = define("Whirlwind", { 1680 }, "Whirlwind"),
}

-- Crowd-control debuff IDs for fear-break detection (Berserker Rage)
local FEAR_DEBUFF_IDS = {
 [5782] = true, [6215] = true, [5484] = true, -- Warlock Fear / Howl
 [8122] = true, [10888] = true, [10890] = true, -- Psychic Scream
 [5246] = true,         -- Intimidating Shout
 [33111] = true,         -- Bellowing Roar (Nightbane)
 [39415] = true,        -- Fear (Skyriss Arcatraz)
 [19134] = true,        -- Frightening Shout
 [46561] = true,        -- Fear (Sunblade Dusk Priest SWP)
 [34984] = true,        -- Psychic Horror (Fen Ray Underbog)
 [38660] = true,        -- Fear (Coilfang Siren Steamvault)
 [32830] = true,        -- Possess (Auchenai Crypts MC)
}
local SAP_DEBUFF_IDS = {
 [6770] = true, [2070] = true, [11297] = true, -- Sap
}
local INCAP_DEBUFF_IDS = {
 [1776] = true, [1777] = true, [8629] = true, -- Gouge
 [20066] = true,         -- Repentance
 [3355] = true,         -- Freezing Trap
}

local function is_feared_sapped_or_incapacitated(unit)
 if not unit then return false end
 for id in pairs(FEAR_DEBUFF_IDS) do
  if NS.debuff_up and NS.debuff_up(unit, id) then return true, "fear" end
 end
 for id in pairs(SAP_DEBUFF_IDS) do
  if NS.debuff_up and NS.debuff_up(unit, id) then return true, "sap" end
 end
 for id in pairs(INCAP_DEBUFF_IDS) do
  if NS.debuff_up and NS.debuff_up(unit, id) then return true, "incapacitate" end
 end
 return false
end

-- Disarm target classes: melee classes that lose weapon-based damage when disarmed
local DISARM_CLASS_IDS = CONSTANTS.DISARM_CLASS_IDS or { [1] = true, [2] = true, [4] = true, [7] = true }

-- settings now delegated to spec_kit.setting_*() (Pattern 8)

-- Enemy scanning API (cached at module load)
local _get_visible_objects = core and core.object_manager and core.object_manager.get_visible_objects or nil
local _safe_field = NS.safe_field or function(obj, field)
 if not obj or type(obj[field]) ~= "function" then return nil end
 return obj[field]
end

local function target_is_casting(unit)
 if not unit then return false end
 local ok, casting = pcall(function()
  if unit.is_casting_spell then return unit:is_casting_spell() end
  return false
 end)
 return ok and casting == true
end

-- ============================================================================
-- Threat target scanning (tab targeting)
-- ============================================================================

-- Static tables reused every frame — zero garbage
local _threat_enemies = {}
local _threat_enemy_count = 0
local _last_threat_scan = 0
local _threat_scan_interval = 0.2 -- Throttle: max 5 scans/sec

local function get_threat_targets(context, me, target)
 _threat_enemy_count = 0
 if not _get_visible_objects then return _threat_enemies, _threat_enemy_count end
 local ok, visible_objects = pcall(_get_visible_objects)
 if not ok or not visible_objects then return _threat_enemies, _threat_enemy_count end
  local tab_range = spec_kit.setting_number(context, "prot_tab_range", 20)
  local range_sq = (tab_range or 20) * (tab_range or 20)
  local scan_count = 0
  local max_scan = 100
  for _, obj in ipairs(visible_objects) do
   scan_count = scan_count + 1
   if scan_count > max_scan then break end
  if obj and NS.not_same_unit(obj, target) then
   -- Filter: must be enemy to player
   local ok_enemy, is_enemy = pcall(function() return obj:is_enemy_with(me) end)
   if ok_enemy and is_enemy then
    local ok_alive, alive = pcall(function()
     if obj.is_dead then return not obj:is_dead() end
     if obj.is_ghost then return not obj:is_ghost() end
     return true
    end)
    if ok_alive and alive ~= false then
     local ok_dist, dist = pcall(function()
      if me.distance_to then return me:distance_to(obj) end
      if obj.distance_to then return obj:distance_to(me) end
      if me.get_distance then return me:get_distance(obj) end
      if obj.get_distance then return obj:get_distance(me) end
      return 999
     end)
     if ok_dist and type(dist) == "number" and dist * dist < range_sq then
      _threat_enemy_count = _threat_enemy_count + 1
      _threat_enemies[_threat_enemy_count] = obj
     end
    end
   end
  end
 end
 return _threat_enemies, _threat_enemy_count
end

-- ============================================================================
-- State builder
-- ============================================================================
local prot_state = {
 sunder_stacks = 0,
 sunder_remains = 0,
 demo_remains = 0,
 tclap_remains = 0,
 hp = 100,
 rage = 0,
 stance = 2,
 enemy_count = 1,
 is_pvp = false,
 in_combat = false,
 target_hp = 100,
 target_is_casting = false,
 target_casting_interruptible = false,
 has_battle_shout = false,
 has_commanding_shout = false,
 has_last_stand = false,
 has_shield_wall = false,
 ss_ready = false,
 revenge_ready = false,
 shield_block_ready = false,
 dev_ready = false,
 demo_ready = false,
 tclap_ready = false,
 hs_ready = false,
 execute_ready = false,
 pummel_ready = false,
 taunt_ready = false,
 mocking_ready = false,
 challenging_ready = false,
 disarm_ready = false,
 spell_reflect_ready = false,
 concussion_ready = false,
 intercept_ready = false,
 hamstring_ready = false,
 berserker_rage_ready = false,
 battle_shout_ready = false,
 commanding_ready = false,
 shield_bash_ready = false,
 bloodrage_ready = false,
 victory_ready = false,
 rend_ready = false,
 intimidating_shout_ready = false,
 ss_purge_name = nil,
 disarm_class_ok = false,
 disarm_burst_name = nil,
 is_group = false,
 tank = nil,
 lowest_allied = nil,
 desired_stance = nil,
}

local function build_state(context)
 local target = context.target
 if target then
  prot_state.sunder_stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, SUNDER_DEBUFF) or 0
  prot_state.sunder_remains = NS.debuff_remains and NS.debuff_remains(target, SUNDER_DEBUFF) or 0
  prot_state.demo_remains = NS.debuff_remains and NS.debuff_remains(target, DEMO_SHOUT_DEBUFF) or 0
  prot_state.tclap_remains = NS.debuff_remains and NS.debuff_remains(target, THUNDER_CLAP_DEBUFF) or 0
 else
  prot_state.sunder_stacks = 0
  prot_state.sunder_remains = 0
  prot_state.demo_remains = 0
  prot_state.tclap_remains = 0
 end
 prot_state.is_group = context.is_group or false
 prot_state.hp = context.hp or 100
 prot_state.rage = context.rage or 0
 prot_state.stance = context.stance or 2
 prot_state.enemy_count = context.enemy_count or 1
 prot_state.is_pvp = context.is_pvp or false
 prot_state.in_combat = context.in_combat or false
 prot_state.target_hp = context.target_hp or 100
 prot_state.target_is_casting = target_is_casting(target)
 prot_state.target_casting_interruptible = NS.is_interruptible and NS.is_interruptible(target) or false

 local me = context.me or NS.GetPlayer()
 prot_state.has_battle_shout = me and NS.buff_up(me, BATTLE_SHOUT_BUFF) or false
 prot_state.has_commanding_shout = me and NS.buff_up(me, COMMANDING_SHOUT_BUFF) or false
 prot_state.has_last_stand = me and NS.buff_up(me, STAND_BUFF) or false
 prot_state.has_shield_wall = me and NS.buff_up(me, SHIELD_WALL_BUFF) or false

 prot_state.ss_ready = target and NS.spell_ready(ACTION.ShieldSlam, target, { expected_cooldown = SHIELD_SLAM_CD }) or false
 prot_state.revenge_ready = target and NS.spell_ready(ACTION.Revenge, target, { expected_cooldown = REVENGE_CD }) or false
 prot_state.shield_block_ready = me and NS.spell_ready(ACTION.ShieldBlock, me, { skip_range = true, expected_cooldown = SHIELD_BLOCK_CD }) or false
 prot_state.dev_ready = target and NS.spell_ready(ACTION.Devastate, target) or false
 prot_state.demo_ready = me and NS.spell_ready(ACTION.DemoralizingShout, me, { skip_range = true, expected_cooldown = DEMO_SHOUT_CD }) or false
 prot_state.tclap_ready = me and NS.spell_ready(ACTION.ThunderClap, me, { skip_range = true, expected_cooldown = THUNDERCLAP_CD }) or false
 prot_state.hs_ready = target and NS.spell_ready(ACTION.HeroicStrike, target) or false
 prot_state.execute_ready = target and NS.spell_ready(ACTION.Execute, target) or false
 prot_state.pummel_ready = target and NS.spell_ready(ACTION.Pummel, target) or false
 prot_state.taunt_ready = target and NS.spell_ready(ACTION.Taunt, target) or false
 prot_state.mocking_ready = target and NS.spell_ready(ACTION.MockingBlow, target) or false
 prot_state.challenging_ready = me and NS.spell_ready(ACTION.ChallengingShout, me, { skip_range = true }) or false
 prot_state.disarm_ready = target and NS.spell_ready(ACTION.Disarm, target) or false
 prot_state.spell_reflect_ready = me and NS.spell_ready(ACTION.SpellReflection, me, { skip_range = true }) or false
 prot_state.concussion_ready = target and NS.spell_ready(ACTION.ConcussionBlow, target) or false
 prot_state.intercept_ready = target and NS.spell_ready(ACTION.Intercept, target) or false
 prot_state.intervene_ready = me and NS.spell_ready(ACTION.Intervene, me, { skip_range = true }) or false
 prot_state.hamstring_ready = target and NS.spell_ready(ACTION.Hamstring, target) or false
 prot_state.berserker_rage_ready = me and NS.spell_ready(ACTION.BerserkerRage, me, { skip_range = true }) or false
 prot_state.battle_shout_ready = me and NS.spell_ready(ACTION.BattleShout, me, { skip_range = true }) or false
 prot_state.commanding_ready = me and NS.spell_ready(ACTION.CommandingShout, me, { skip_range = true }) or false
 prot_state.shield_bash_ready = target and NS.spell_ready(ACTION.ShieldBash, target) or false
 prot_state.bloodrage_ready = me and NS.spell_ready(ACTION.Bloodrage, me, { skip_range = true, expected_cooldown = BLOODRAGE_CD }) or false
 prot_state.victory_ready = target and NS.spell_ready(ACTION.VictoryRush, target) or false
 prot_state.rend_ready = target and NS.spell_ready(ACTION.Rend, target) or false
 prot_state.intimidating_shout_ready = me and NS.spell_ready(ACTION.IntimidatingShout, me, { skip_range = true, expected_cooldown = INTIMIDATING_SHOUT_CD }) or false

 -- Shield Slam purge: check if target has a priority dispellable buff
 prot_state.ss_purge_name = nil
 if target and prot_state.is_pvp and prot_state.ss_ready then
  local best_id, _, best_name = CCGateDB.find_best_dispel_target(target, NS)
  if best_id then
   prot_state.ss_purge_name = best_name
  end
 end

 -- Disarm: class gate + burst detection via dispel priority DB
 prot_state.disarm_class_ok = false
 prot_state.disarm_burst_name = nil
 if target and prot_state.is_pvp and prot_state.disarm_ready then
  local ok, class_id = pcall(function() return target:get_class() end)
  if ok and type(class_id) == "number" and DISARM_CLASS_IDS[class_id] then
   prot_state.disarm_class_ok = true
   local best_id, best_priority, best_name = CCGateDB.find_best_dispel_target(target, NS)
   if best_id and (best_priority or 0) >= 3 then
    prot_state.disarm_burst_name = best_name
   end
  end
 end

 -- Threat tab targeting: scan nearby enemies for Taunt/MockingBlow cycling
 if prot_state.in_combat and spec_kit.setting_bool(context, "prot_tab_targeting", true) then
  local now = (core and core.time and core.time()) or 0
  if now - _last_threat_scan >= _threat_scan_interval then
   _last_threat_scan = now
   local nearby, nearby_count = get_threat_targets(context, me, target)
   prot_state.nearby_enemies = nearby
   prot_state.nearby_count = nearby_count
   -- Find first enemy not targeting us (has no aggro on tank)
   prot_state.no_threat_target = nil
   for i = 1, nearby_count do
    local enemy = nearby[i]
    if enemy then
     local ok_t, enemy_target = pcall(function()
      if enemy.get_target then return enemy:get_target() end
      return nil
     end)
     if ok_t and NS.not_same_unit(enemy_target, me) then
      -- HP gate: don't taunt a target at <5% HP (waste of CD)
      local ok_hp, enemy_hp = pcall(function()
       return NS.unit_health_pct(enemy)
      end)
      if ok_hp and (enemy_hp or 100) < 5 then
       -- Skip low-HP targets — they'll die before taunt matters
      else
       -- TTD gate: don't taunt a target about to die
       local ttd_ok = true
       if context.ttd_known == false then
        -- No TTD data, safe to taunt
       elseif (context.ttd or 999) < 8 then
        ttd_ok = false
       end
       if ttd_ok then
        prot_state.no_threat_target = enemy
        break
       end
      end
     end
    end
   end
  end
 else
  prot_state.nearby_enemies = nil
  prot_state.nearby_count = 0
  prot_state.no_threat_target = nil
 end

 -- StanceManager integration (exposed as NS.StanceManager by shared/stance_manager_sylvanas;
 -- the bare global `StanceManager` is nil here, so the old reference was dead.)
 local SM = NS.StanceManager
 if SM and SM.get_optimal_stance then
  prot_state.desired_stance = SM.get_optimal_stance(context, prot_state)
 end

 -- Intervene: populate party state
 prot_state.is_group = context.is_group or false
 prot_state.tank = nil
 prot_state.lowest_allied = nil
 if prot_state.is_group and me then
  local party_scan = NS.get_party_members or NS.party_members
  local me_pos_ok, me_x, me_y = pcall(function()
   if me.get_position then return me:get_position() end
   return nil, nil
  end)
  if party_scan and me_pos_ok and me_x and me_y then
   local members = party_scan(me, NS) or {}
   local best_ally = nil
   local best_hp = 101
   local best_dist_sq = 999999
   for _, member in ipairs(members) do
    if member and NS.not_same_unit(member, me) then
     local ok_hp, hp = pcall(function() return NS.unit_health_pct(member) end)
     if ok_hp and hp and hp < best_hp then
      local ok_pos, ax, ay = pcall(function()
       if member.get_position then return member:get_position() end
       return nil, nil
      end)
      if ok_pos and ax and ay then
       local ddx, ddy = me_x - ax, me_y - ay
       local dist_sq = ddx * ddx + ddy * ddy
       if dist_sq <= 625 then
        best_ally = { unit = member, effective_hp = hp }
        best_hp = hp
        best_dist_sq = dist_sq
       end
      end
     end
    end
   end
   prot_state.lowest_allied = best_ally
   prot_state.tank = best_ally
  end
 end

 -- parity: Snap Threat — immediate high-threat opener on combat start
 if NS.SnapThreat and type(NS.SnapThreat.check) == "function" then
  local snap_spell = NS.SnapThreat.check(me, target, context.settings, {
   spell_id = ACTION.ShieldSlam,
   fallback_id = ACTION.Revenge,
  })
  if snap_spell and NS.try_cast then
   pcall(NS.try_cast, snap_spell, target, "[PROT] Snap Threat opener")
  end
 end

    prot_state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS) or 0
 -- AoE CC gating flag (set by the PvPCCGate middleware; consulted by AoE matches so
 -- the rotation is never frozen by a nearby sheeped/sapped mob).
 prot_state.aoe_cc_nearby = context.warrior_aoe_cc_nearby or false
 return spec_kit.safe_state(prot_state)
end

-- ============================================================================
-- Matches helpers
-- ============================================================================

local function is_defensive_stance(stance)
 return stance == STANCE.DEFENSIVE
end

local function swing_timer_gate(context, state)
    if not spec_kit.setting_bool(context, "prot_swing_timer", true) then return true end
    local swing_remains = state.swing_remains or 99
    return swing_remains > 0.3 or swing_remains < 0
end

local function sunder_matches_fn(context, state)
 if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.SunderArmor, 2.0) then return false end
 if not context.target then return false end
 -- Skip if target has no armor (armorless mob or API unavailable)
 if (context.target_armor or 0) <= 0 then return false end
 if state.dev_ready then return false end
 if (state.sunder_stacks or 0) < SUNDER_MAX_STACKS then
  return state.ss_ready == false and state.revenge_ready == false
 end
 if (state.sunder_remains or 0) <= SUNDER_WINDOW then
  return state.ss_ready == false and state.revenge_ready == false
 end
 return false
end

local function devastate_matches_fn(context, state)
 if not context.target then return false end
 if not state.dev_ready then return false end
 return state.ss_ready == false and state.revenge_ready == false
end

local function thunderclap_matches_fn(context, state)
 if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.ThunderClap, 2.0) then return false end
 if state.aoe_cc_nearby then return false end  -- don't break nearby CC
 local ec = state.enemy_count or 0
 if ec >= 2 then return true end
 -- Single target: use Thunder Clap for attack speed debuff on bosses/elites
 if ec >= 1 and (state.tclap_remains or 0) <= 0 then
  local target = context.target
  if target and target.is_valid and target:is_valid() then
   local cls = target.get_classification and target:get_classification() or 0
   if cls >= 1 then return true end -- 1=elite, 2=rare_elite, 3=worldboss, 4=rare
  end
 end
 return false
end

local function demo_shout_matches_fn(context, state)
 if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.DemoralizingShout, 2.0) then return false end
 if (state.demo_remains or 0) > 5 then return false end
 return true
end

local function heroic_strike_matches_fn(context, state)
 if (state.rage or 0) < HEROIC_STRIKE_RAGE_DUMP then return false end
 if state.ss_ready then return false end
 if state.revenge_ready then return false end
 if not swing_timer_gate(context, state) then return false end
 return true
end

local function cleave_matches_fn(context, state)
 if state.aoe_cc_nearby then return false end  -- don't break nearby CC
 if (state.enemy_count or 0) < 2 then return false end
 if (state.rage or 0) < HEROIC_STRIKE_RAGE_DUMP then return false end
 if not swing_timer_gate(context, state) then return false end
 return true
end

local function execute_matches_fn(context, state)
 if not NS.is_execute_phase then return false end
 if not NS.is_execute_phase(state.target_hp, 20) then return false end
 -- TBC Execute requires Battle/Berserker Stance; a Defensive-Stance prot tank will
 -- simply not cast it (try_cast fails gracefully) — no stance-dance here to avoid
 -- dropping Defensive during the kill phase.
 return true
end

local function battle_shout_matches_fn(context, state)
 if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.BattleShout, 3.0) then return false end
 if state.has_battle_shout then return false end
 if state.has_commanding_shout then return false end
 return true
end

local function commanding_shout_matches_fn(context, state)
 if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.CommandingShout, 3.0) then return false end
 if not spec_kit.setting_bool(context, "use_commanding_shout", false) then return false end
 if state.has_commanding_shout then return false end
 if state.has_battle_shout then return false end
 if not state.commanding_ready then return false end
 return true
end

local function shield_wall_matches_fn(context, state)
 if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.ShieldWall, 3.0) then return false end
 if spec_kit.setting_bool(context, "use_shield_wall", true) == false then return false end
 local default_threshold = state.is_group and 50 or 35
 local threshold = spec_kit.setting_number(context, "defensive_hp_threshold", default_threshold)
 if (state.hp or 100) > threshold then return false end
 if state.has_shield_wall then return false end
 return true
end

local function last_stand_matches_fn(context, state)
 if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.LastStand, 3.0) then return false end
 if spec_kit.setting_bool(context, "use_last_stand", true) == false then return false end
 local default_threshold = state.is_group and 50 or 35
 local threshold = spec_kit.setting_number(context, "defensive_hp_threshold", default_threshold)
 if (state.hp or 100) > threshold then return false end
 if state.has_last_stand then return false end
 return true
end

local function shield_bash_matches_fn(context, state)
 if spec_kit.setting_bool(context, "use_interrupts", true) == false then return false end
 -- Route through InterruptManager for cast window + humanization
 local mgr = NS.InterruptManager
 local target = context.target
 if mgr then
  if not NS.try_interrupt(target) then return false end
  if not mgr.cast_has_interrupt_window(target, context.settings or {}) then return false end
  if not mgr.humanize_interrupt_elapsed(target, context.settings or {}) then return false end
 else
  -- Fallback: bare cast-state checks
  if not state.target_is_casting then return false end
  if not (state.target_casting_interruptible or false) then return false end
 end
 if not state.shield_bash_ready then return false end
 if not is_defensive_stance(state.stance) then return false end
 return true
end

local function taunt_matches_fn(context, state)
 if not state.taunt_ready then return false end
 local me = context.me or NS.GetPlayer()
 local target = context.target
 if not target then return false end
 -- Smart taunt: only taunt elites/bosses (classification >= 1)
 if (context.target_classification or 0) < 1 then return false end
 -- Skip CC'd targets
 if NS.has_target_debuff and context.target and NS.has_target_debuff(context.target, { 118, 12824, 12825, 12826, 6770, 2070, 5782, 6213, 6215, 20066, 2637, 9484, 9485, 10955 }) then return false end
 -- Don't waste Taunt on a target that already has aggro on us
 if me then
  local ok, enemy_target = pcall(function()
   if target.get_target then return target:get_target() end
   return nil
  end)
  if ok and NS.same_unit(enemy_target, me) then return false end
 end
 -- Threat-level gate: only Taunt if target is NOT already being tanked by us
 if me and target.get_threat_situation then
  local ok, threat = pcall(target.get_threat_situation, target, me)
  if ok and threat and threat.is_tanking then return false end
 end
 -- Prefer: taunt an enemy NOT targeting us (no aggro)
 if state.no_threat_target then
  context._taunt_target = state.no_threat_target
  return true
 end
 return true
end

local function mocking_blow_matches_fn(context, state)
 if not state.mocking_ready then return false end
 -- Smart taunt: only mocking blow elites/bosses (classification >= 1)
 if (context.target_classification or 0) < 1 then return false end
 -- Skip CC'd targets
 if NS.has_target_debuff and context.target and NS.has_target_debuff(context.target, { 118, 12824, 12825, 12826, 6770, 2070, 5782, 6213, 6215, 20066, 2637, 9484, 9485, 10955 }) then return false end
 -- Prefer: Mocking Blow an enemy NOT targeting us
 if state.no_threat_target then
  context._mocking_target = state.no_threat_target
  return true
 end
 return true
end

local function taunt_secondary_matches_fn(context, state)
 if not state.mocking_ready then return false end
 if not spec_kit.setting_bool(context, "prot_tab_targeting", true) then return false end
 if (state.enemy_count or 0) < 3 then return false end
 -- Smart taunt: only mocking blow elites/bosses (classification >= 1)
 if (context.target_classification or 0) < 1 then return false end
 -- Skip CC'd targets
 if NS.has_target_debuff and context.target and NS.has_target_debuff(context.target, { 118, 12824, 12825, 12826, 6770, 2070, 5782, 6213, 6215, 20066, 2637, 9484, 9485, 10955 }) then return false end
 -- We need a nearby enemy we can tab to
 if not state.no_threat_target then return false end
 -- Only fire if primary Taunt is on cooldown (otherwise Taunt takes priority)
 if state.taunt_ready then return false end
 context._mocking_target = state.no_threat_target
 return true
end

local function challenging_shout_matches_fn(context, state)
 if not state.challenging_ready then return false end
 if state.aoe_cc_nearby then return false end  -- AoE taunt would pull CC'd mobs
 -- Challenging Shout is AoE — needs 3+ enemies to be worth the 1min cooldown
 if (state.enemy_count or 0) < 3 then return false end
 -- Smart taunt: only shout on elites/bosses (classification >= 1)
 if (context.target_classification or 0) < 1 then return false end
 -- Skip CC'd targets
 if NS.has_target_debuff and context.target and NS.has_target_debuff(context.target, { 118, 12824, 12825, 12826, 6770, 2070, 5782, 6213, 6215, 20066, 2637, 9484, 9485, 10955 }) then return false end
 return true
end

local function concussion_blow_matches_fn(context, state)
 if not state.concussion_ready then return false end
 if not state.is_pvp then return false end
 return true
end

local function disarm_matches_fn(context, state)
 if not state.disarm_ready then return false end
 if not state.is_pvp then return false end
 if not state.disarm_class_ok then return false end
 local trigger = spec_kit.setting(context, "disarm_trigger", "on_burst")
 if trigger == "on_burst" then
  if not state.disarm_burst_name then return false end
  context._disarm_burst_name = state.disarm_burst_name
 end
 return true
end

local function spell_reflect_matches_fn(context, state)
 if not state.spell_reflect_ready then return false end
 if not state.is_pvp then return false end
 if not state.target_is_casting then return false end
 return true
end

local function intercept_matches_fn(context, state)
 if not state.intercept_ready then return false end
 if not state.is_pvp then return false end
 return true
end

local function intervene_matches_fn(context, state)
 if not state.intervene_ready then return false end
 if not state.in_combat then return false end
 if not state.is_group then return false end
 if not spec_kit.setting_bool(context, "warrior_use_intervene", true) then return false end
 if spec_kit.setting_bool(context, "warrior_intervene_pvp_only", true) and not state.is_pvp then return false end
 if (state.rage or 0) < 10 then return false end
 local ally = state.lowest_allied or state.tank
 if not ally or not ally.unit then return false end
 local hp_threshold = spec_kit.setting_number(context, "warrior_intervene_hp_threshold", 60)
 if (ally.effective_hp or 100) > hp_threshold then return false end
 local me = context.me or (NS.GetPlayer and NS.GetPlayer())
 if not me then return false end
 local dx, dy = me.get_position and me:get_position()
 local ax, ay = ally.unit.get_position and ally.unit:get_position()
 if not (dx and dy and ax and ay) then return false end
 local ddx, ddy = dx - ax, dy - ay
 if ddx*ddx + ddy*ddy > 625 then return false end
 return true
end

local function hamstring_matches_fn(context, state)
 if not state.hamstring_ready then return false end
 if not state.is_pvp then return false end
 return true
end

local function berserker_rage_matches_fn(context, state)
 if not state.berserker_rage_ready then return false end
 -- Berserker Rage breaks fear/sap/incapacitate (and grants rage-on-damage, but only
 -- in Berserker Stance). For a Prot tank in Defensive Stance this is only useful as a
 -- fear-break attempt. The old trailing `return true` matched on every cooldown
 -- (spam); normal in-combat rage-gen use is omitted because it requires leaving
 -- Defensive Stance.
 local me = context.me or NS.GetPlayer()
 local is_cc = is_feared_sapped_or_incapacitated(me)
 if is_cc then return true end
 return false
end

-- parity gaps: Bloodrage, VictoryRush, Rend, IntimidatingShout

local function bloodrage_matches_fn(context, state)
 if not state.bloodrage_ready then return false end
 -- Use out of combat for pre-pull rage, or in combat if rage-starved
 if state.in_combat and (state.rage or 0) >= 10 then return false end
 return true
end

local function victory_rush_matches_fn(context, state)
 if not state.victory_ready then return false end
 if not state.in_combat then return false end
 -- Victory Rush is free post-kill damage/threat usable in any stance; the old
 -- `hp > 80` gate was nonsensical (Victory Rush does not heal) and skipped it
 -- whenever the tank was above 80% HP.
 return true
end

local function rend_matches_fn(context, state)
 if not context.target then return false end
 if not state.rend_ready then return false end
 if not state.in_combat then return false end
 -- Use as supplementary threat filler when SS/Revenge not up
 if state.ss_ready then return false end
 if state.revenge_ready then return false end
 local rend_remains = context.target and NS.debuff_remains and NS.debuff_remains(context.target, REND_DEBUFF) or 0
 if rend_remains > 3 then return false end
 return true
end

local function intimidating_shout_matches_fn(context, state)
 if not state.intimidating_shout_ready then return false end
 if not state.in_combat then return false end
 if (state.enemy_count or 0) < 3 then return false end
 if (state.hp or 100) > 50 then return false end
 return true
end

-- Unified stance switch using StanceManager
local function stance_switch_matches_fn(context, state)
 local SM = NS.StanceManager
 if not SM or not SM.should_switch then return false end
 local desired = state.desired_stance
 if not desired then return false end
 if not SM.should_switch(context, state, desired) then return false end
 return true
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
 { name = "HealthPotion",
  matches = function(context)
   if not context.in_combat then return false end
   if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
   if not context.has_health_potion then return false end
   if (context.hp or 100) > 35 then return false end
   return true
  end,
  execute = function(context) return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS) end },
 { name = "DamagePotion",
  matches = function(context)
   if not context.in_combat then return false end
   if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
   if not context.has_damage_potion then return false end
   if not context.should_burst then return false end
   return true
  end,
  execute = function(context) return potion_helper.try_use_potion(context, potion_helper.DAMAGE_POTION_IDS) end },

    { name = "Healthstone",
      matches = function(context, state)
          if not context.in_combat then return false end
          if (state.hp or 100) > 28 then return false end
          if (state.healthstone_ready or 0) <= 0 then return false end
          return true
      end,
      execute = function(context)
          local id = first_ready_item(HEALTHSTONE_IDS)
          if id then NS.use_item_by_id(id, context.me) end
      end },
 -- 1) Emergency defensives (always first)
 {
  name = "LastStand",
  matches = function(context, state) return last_stand_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.LastStand, context.me or NS.GetPlayer(), "[PROT] LastStand", { skip_range = true, expected_cooldown = FINAL_STAND_CD })
  end,
 },
 {
  name = "ShieldWall",
  matches = function(context, state) return shield_wall_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.ShieldWall, context.me or NS.GetPlayer(), "[PROT] ShieldWall", { skip_range = true, expected_cooldown = SHIELD_WALL_CD })
  end,
 },
 -- 2) Interrupts (must beat casts)
 {
  name = "ShieldBash",
  matches = function(context, state) return shield_bash_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.ShieldBash, context.target, "[PROT] ShieldBash")
  end,
 },
 {
  name = "Pummel",
  matches = function(context, state)
   if not state.pummel_ready then return false end
   if not state.target_is_casting then return false end
   if not (state.target_casting_interruptible or false) then return false end
   return true
  end,
  execute = function(context)
   return NS.try_cast(ACTION.Pummel, context.target, "[PROT] Pummel")
  end,
 },
 -- 3) Shield Slam Purge (PvP — checks settings from shared schema)
 {
  name = "ShieldSlamPurge",
  matches = function(context, state)
   if spec_kit.setting_bool(context, "use_shield_slam_purge", true) == false then return false end
   if not context.is_pvp then return false end
   if not context.in_combat then return false end
   if not state.ss_ready then return false end
   if not state.ss_purge_name then return false end
   -- Player-only gate
   if spec_kit.setting_bool(context, "shield_slam_purge_pvp_only", true) then
    local ok, is_player = pcall(function() return context.target:is_player() end)
    if not (ok and is_player) then return false end
   end
   context._ss_purge_name = state.ss_purge_name
   return true
  end,
  execute = function(context)
   local name = context._ss_purge_name or "buff"
   return NS.try_cast(ACTION.ShieldSlam, context.target, "[PROT] Shield Slam purge → " .. name, { expected_cooldown = SHIELD_SLAM_CD })
  end,
 },
 -- 4) Threat-gen core (single-target and AoE)
 {
  name = "ShieldSlam",
  matches = function(context, state)
   return is_defensive_stance(state.stance) and state.ss_ready
  end,
  execute = function(context) return NS.try_cast(ACTION.ShieldSlam, context.target, "[PROT] ShieldSlam", { expected_cooldown = SHIELD_SLAM_CD }) end,
 },
 {
  name = "Revenge",
  matches = function(context, state)
   return is_defensive_stance(state.stance) and state.revenge_ready
  end,
  execute = function(context) return NS.try_cast(ACTION.Revenge, context.target, "[PROT] Revenge", { expected_cooldown = REVENGE_CD }) end,
 },
 {
  name = "ShieldBlock",
  matches = function(context, state)
   if not is_defensive_stance(state.stance) then return false end
   if not state.shield_block_ready then return false end
   local me = context.me or NS.GetPlayer()
   local sb_remains = me and NS.buff_remains and NS.buff_remains(me, SHIELD_BLOCK_BUFF) or 0
   if sb_remains > 2 then return false end
   return true
  end,
  execute = function(context) return NS.try_cast(ACTION.ShieldBlock, context.me or NS.GetPlayer(), "[PROT] ShieldBlock", { skip_range = true, expected_cooldown = SHIELD_BLOCK_CD }) end,
 },
 {
  name = "Taunt",
  matches = function(context, state) return taunt_matches_fn(context, state) end,
  execute = function(context)
   local target = context._taunt_target or context.target
   return NS.try_cast(ACTION.Taunt, target, "[PROT] Taunt")
  end,
 },
 -- Tab-target Taunt cycling: MockingBlow on nearby enemy when Taunt is on CD
 {
  name = "TauntSecondary",
  matches = function(context, state) return taunt_secondary_matches_fn(context, state) end,
  execute = function(context)
   local target = context._mocking_target or context.target
   return NS.try_cast(ACTION.MockingBlow, target, "[PROT] MockingBlow (tab cycle)")
  end,
 },
 {
  name = "MockingBlow",
  matches = function(context, state) return mocking_blow_matches_fn(context, state) end,
  execute = function(context)
   local target = context._mocking_target or context.target
   return NS.try_cast(ACTION.MockingBlow, target, "[PROT] MockingBlow")
  end,
 },
 {
  name = "ChallengingShout",
  matches = function(context, state) return challenging_shout_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.ChallengingShout, context.me or NS.GetPlayer(), "[PROT] ChallengingShout", { skip_range = true })
  end,
 },

 -- 4b) Survival debuff upkeep (TBC guide: Demo Shout + Thunder Clap "always
 -- up", placed above Devastate filler -- ~18% dmg cut + ~20% atk-speed slow).
 {
  name = "DemoralizingShout",
  matches = function(context, state) return demo_shout_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.DemoralizingShout, context.me or NS.GetPlayer(), "[PROT] DemoShout", { skip_range = true, expected_cooldown = DEMO_SHOUT_CD })
  end,
 },
 {
  name = "ThunderClap",
  matches = function(context, state) return thunderclap_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.ThunderClap, context.me or NS.GetPlayer(), "[PROT] ThunderClap", { skip_range = true, expected_cooldown = THUNDERCLAP_CD })
  end,
 },
 -- 5) Sunder / Devastate stack maintenance
 {
  name = "Devastate",
  matches = function(context, state) return devastate_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.Devastate, context.target, "[PROT] Devastate")
  end,
 },
 {
  name = "SunderArmor",
  matches = function(context, state) return sunder_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.SunderArmor, context.target, "[PROT] Sunder")
  end,
 },
 -- 5) Execute phase (sub-20%)
 {
  name = "Execute",
  matches = function(context, state) return execute_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.Execute, context.target, "[PROT] Execute")
  end,
 },
 -- 6) Buffs / Shouts
 {
  name = "BattleShout",
  matches = function(context, state) return battle_shout_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.BattleShout, context.me or NS.GetPlayer(), "[PROT] BattleShout", { skip_range = true })
  end,
 },
 {
  name = "CommandingShout",
  matches = function(context, state) return commanding_shout_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.CommandingShout, context.me or NS.GetPlayer(), "[PROT] CommandingShout", { skip_range = true })
  end,
 },
 -- 9) Rage dump
 {
  name = "Cleave",
  matches = function(context, state) return cleave_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.Cleave, context.target, "[PROT] Cleave")
  end,
 },
 {
  name = "HeroicStrike",
  matches = function(context, state) return heroic_strike_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.HeroicStrike, context.target, "[PROT] HeroicStrike")
  end,
 },
 -- Multi-target WW with stance dance (per wowsims APL for prot on 2+ targets when rage allows)
 {
  name = "WhirlwindMulti",
  matches = function(context, state)
   if (state.enemy_count or 0) < 2 then return false end
   if not state.in_combat then return false end
   if not NS.spell_ready or not NS.spell_ready(ACTION.Whirlwind, context.me, { skip_range = true }) then return false end
   -- Prefer in Berserker for WW; the StanceSwitch will handle dance if configured
   return true
  end,
  execute = function(context)
   -- If not in berserker, the stance manager or subsequent StanceSwitch will help; cast WW
   return NS.try_cast(ACTION.Whirlwind, context.me or NS.GetPlayer(), "[PROT] Whirlwind (AoE)", { skip_range = true })
  end,
 },
 -- 10) PvP / utility / movement
 {
  name = "SpellReflection",
  matches = function(context, state) return spell_reflect_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.SpellReflection, context.me or NS.GetPlayer(), "[PROT] SpellReflection", { skip_range = true })
  end,
 },
 {
  name = "Disarm",
  matches = function(context, state)
   if spec_kit.setting_bool(context, "use_disarm", true) == false then return false end
   if not (NS.is_spell_learned and NS.is_spell_learned(676)) then return false end
   if not context.in_combat then return false end
   if spec_kit.setting_bool(context, "disarm_pvp_only", true) then
    local ok, is_player = pcall(function() return context.target:is_player() end)
    if not (ok and is_player) then return false end
   end
   return disarm_matches_fn(context, state)
  end,
  execute = function(context)
   local label = context._disarm_burst_name
    and ("[PROT] Disarm → " .. context._disarm_burst_name)
    or "[PROT] Disarm"
   return NS.try_cast(ACTION.Disarm, context.target, label, { expected_cooldown = DISARM_CD })
  end,
 },
 {
  name = "ConcussionBlow",
  matches = function(context, state) return concussion_blow_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.ConcussionBlow, context.target, "[PROT] ConcussionBlow")
  end,
 },
 {
  name = "Hamstring",
  matches = function(context, state) return hamstring_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.Hamstring, context.target, "[PROT] Hamstring")
  end,
 },
 {
  name = "Intercept",
  matches = function(context, state) return intercept_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.Intercept, context.target, "[PROT] Intercept")
  end,
 },
 {
  name = "Intervene",
  matches = function(context, state) return intervene_matches_fn(context, state) end,
  execute = function(context, state)
   local ally = state.lowest_allied or state.tank
   if not (ally and ally.unit) then return false end
   return NS.try_cast(ACTION.Intervene, ally.unit, "[PROT] Intervene")
  end,
 },
 {
  name = "BerserkerRage",
  matches = function(context, state) return berserker_rage_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.BerserkerRage, context.me or NS.GetPlayer(), "[PROT] BerserkerRage", { skip_range = true })
  end,
 },
 -- 11) parity gaps: utility and sustain
 {
  name = "Bloodrage",
  matches = function(context, state) return bloodrage_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.Bloodrage, context.me or NS.GetPlayer(), "[PROT] Bloodrage", { skip_range = true, skip_gcd = true })
  end,
 },
 {
  name = "VictoryRush",
  matches = function(context, state) return victory_rush_matches_fn(context, state) end,
  execute = function(context)
   -- VictoryRush works in any stance, no stance swap needed
   return NS.try_cast(ACTION.VictoryRush, context.target, "[PROT] VictoryRush")
  end,
 },
 {
  name = "Rend",
  matches = function(context, state) return rend_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.Rend, context.target, "[PROT] Rend")
  end,
 },
 {
  name = "IntimidatingShout",
  matches = function(context, state) return intimidating_shout_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.IntimidatingShout, context.me or NS.GetPlayer(), "[PROT] IntimidatingShout", { skip_range = true })
  end,
 },
 -- 12) Rage cap safety net: dump excess rage when nothing else matched
 {
  name = "RageDumpSafetyNet",
  matches = function(context, state)
   return (state.rage or 0) >= 90
  end,
  execute = function(context)
   return NS.try_cast(ACTION.HeroicStrike, context.target, "[PROT] RageDump")
  end,
 },
 {
  name = "StanceSwitch",
  matches = stance_switch_matches_fn,
  execute = function(context)
   local desired = prot_state.desired_stance
   if desired == "battle" then
    return NS.try_cast(ACTION.BattleStance, context.me or NS.GetPlayer(), "[PROT] BattleStance", { skip_range = true })
   elseif desired == "berserker" then
    return NS.try_cast(ACTION.BerserkerStance, context.me or NS.GetPlayer(), "[PROT] BerserkerStance", { skip_range = true })
   elseif desired == "defensive" then
    return NS.try_cast(ACTION.DefensiveStance, context.me or NS.GetPlayer(), "[PROT] DefensiveStance", { skip_range = true })
   end
   return false
  end,
 },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("protection", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warrior Protection rotation registered") end
return { strategies = strategies, build_state = build_state }
