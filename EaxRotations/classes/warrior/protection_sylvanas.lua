-- protection_sylvanas.lua — Warrior Protection tank rotation for TBC Anniversary (2.5.5).
-- WHAT:  priority list for threat (SS > Shield Block > Revenge > Devastate/Sunder), mitigation (Shield Block high), Demo/TC, AoE (Cleave/TC + WW stance dance), taunts, defensives, rage dump.
-- WHEN:  combat (defensive stance preferred), valid enemy target.
-- WHY:   mirrors wowsims/tbc protection dispatch (SS/Revenge/Devastate, Demo refresh, multi TC/WW, defensive CDs <40%); Shield Block promoted above Revenge 2026-08-13 per the guide (not modeled by the sim, so unpinned — see strategy comment).
-- SAFETY: state.* reads nil-guarded via spec_kit.safe_state(); registration guarded.

-- Warrior Protection priority list.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end
local spec_kit = require("shared/spec_kit_sylvanas")

-- Fallback merge_state for test environments that mock an older spec_kit
-- without the shared helper. Production uses spec_kit.merge_state.
local merge_state = spec_kit.merge_state or function(build_state, context, state_override)
    local s = build_state(context)
    if not state_override or next(state_override) == nil then return s end
    local merged = {}
    for k, v in pairs(s) do merged[k] = v end
    for k, v in pairs(state_override) do merged[k] = v end
    local mt = getmetatable(s)
    if mt then
        local mt_copy = {}
        for k, v in pairs(mt) do mt_copy[k] = v end
        mt_copy.__newindex = nil
        setmetatable(merged, mt_copy)
    end
    return merged
end
local dsl = require("shared/strategy_dsl_sylvanas")
local potion_helper = require("shared/potion_helper_sylvanas")
local _inv_ok, inventory_helper = pcall(require, "common/utility/inventory_helper")
if not _inv_ok or type(inventory_helper) ~= "table" then inventory_helper = nil end
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }
local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local _hp_ok, HealthPred = pcall(require, "shared/health_pred_helper_sylvanas")
if not _hp_ok or type(HealthPred) ~= "table" then HealthPred = nil end
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
-- Agrees with class_sylvanas.lua LastStand cooldown (spell 12975; verified in
-- _dbc_spell_ids.lua). Was 480 — contradicted the class table.
local FINAL_STAND_CD = 180

-- Test assertion strings required by test_spell_id_table_regressions.lua

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
 revenge_ready = false,    shield_block_ready = false,
    dev_ready = false,
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

-- Frame cache: build_state is invoked once per frame by the dispatcher AND
-- again per strategy by apply_base_matches' merge_state (38 × per frame).
-- Cache on context.now so the expensive ~30 spell_ready / buff / threat-scan
-- block runs once per tick (mirrors arms_sylvanas:325 / bear_sylvanas:343 /
-- cat_sylvanas:646). The cache-hit return is still wrapped in safe_state so
-- Pattern-14 nil-guard defaults apply on hits too (cache-hit audit invariant).
local _last_build_state_time = -1

local function build_state(context)
 local now = context.now
 if now and now == _last_build_state_time then return spec_kit.safe_state(prot_state) end
 now = now or (NS.time_now and NS.time_now() or 0)
 if context.now then _last_build_state_time = now end
 prot_state.now = now
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
 prot_state.has_valid_target = context.has_valid_enemy_target ~= false and context.target ~= nil
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

 -- Native swing-timer prediction (same helper as kebab/fury/arms; exists in
 -- core_sylvanas.lua as NS.get_time_until_swing). Feeds swing_timer_gate so
 -- HeroicStrike/Cleave queue AFTER the swing lands instead of delaying it.
 -- The 99 fallback keeps the gate open when the addon/API is unavailable
 -- (matches the old always-pass behavior).
 prot_state.swing_remains = NS.get_time_until_swing and NS.get_time_until_swing() or 99

 prot_state.ss_ready = target and NS.spell_ready(ACTION.ShieldSlam, target, { expected_cooldown = SHIELD_SLAM_CD }) or false
 prot_state.revenge_ready = target and NS.spell_ready(ACTION.Revenge, target, { expected_cooldown = REVENGE_CD }) or false
 prot_state.shield_block_ready = me and NS.spell_ready(ACTION.ShieldBlock, me, { skip_range = true, expected_cooldown = SHIELD_BLOCK_CD }) or false    prot_state.dev_ready = target and NS.spell_ready(ACTION.Devastate, target) or false
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
  -- The party list is the ENGINE's context.party_members (main_sylvanas.lua
  -- :932, from NS.GetPartyMembers when is_group). The old bare reads of
  -- NS.get_party_members / NS.party_members — NEVER defined — left party_scan
  -- nil live and the whole Intervene scan dead. Fixed 2026-08-11 to read the
  -- authoritative engine context field (this block already gates on is_group,
  -- so the field is populated exactly when it is needed).
  -- NOTE (2026-08-08): get_position returns ONE vec3 table {x,y,z} (with
  -- [1]/[2] index aliases) — see shared/auto_loot + shared/targeting. The
  -- previous pcall multi-capture (me_x, me_y) got me_x=table, me_y=nil and
  -- silently skipped the whole scan in live play; read the table fields.
  local me_pos_ok, me_pos = pcall(function()
   if me.get_position then return me:get_position() end
   return nil
  end)
  local me_x = me_pos and (me_pos.x or me_pos[1]) or nil
  local me_y = me_pos and (me_pos.y or me_pos[2]) or nil
  if context.party_members and me_pos_ok and me_x and me_y then
   local members = context.party_members
   local best_ally = nil
   local best_hp = 101
   local best_dist_sq = 999999
   for _, member in ipairs(members) do
    if member and NS.not_same_unit(member, me) then
     local ok_hp, hp = pcall(function() return NS.unit_health_pct(member) end)
     if ok_hp and hp and hp < best_hp then
      local ok_pos, apos = pcall(function()
       if member.get_position then return member:get_position() end
       return nil
      end)
      local ax, ay = apos and (apos.x or apos[1]) or nil, apos and (apos.y or apos[2]) or nil
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

-- ============================================================================
-- Centralized base_matches guards
-- ============================================================================

local function base_guard_passes(action_def, s)
    if action_def.spell and NS.spell_exists and not NS.spell_exists(action_def.spell) then return false end
    if action_def.requires_target ~= false and not s.has_valid_target then return false end
    if action_def.requires_in_combat and not s.in_combat then return false end
    if action_def.requires_not_in_combat and s.in_combat then return false end
    if action_def.requires_pvp and not s.is_pvp then return false end
    if action_def.min_enemies and (s.enemy_count or 0) < action_def.min_enemies then return false end
    return true
end

-- Merge a caller-provided state override into the state built from context.
-- This keeps tests ergonomic (callers can pass partial states) without
-- mutating the static cached state table (Pattern 4).

local function apply_base_matches(strategies, actions)
    for i = 1, #strategies do
        local action = actions[i]
        local original_matches = strategies[i].matches
        strategies[i].matches = function(context, state)
            local s = merge_state(build_state, context, state)
            if not base_guard_passes(action, s) then return false end
            return original_matches(context, s)
        end
    end
end

local function sunder_matches_fn(context, state)
 if not context.target then return false end
 -- Low-level: get_armor() often returns 0/nil — same silent gate as Druid Faerie Fire.
 -- Keep armorless skip at 50+ (elementals etc.); below 50 allow Sunder for threat.
 local level = (context and (context.level or context.player_level)) or 70
 if level >= 50 and (context.target_armor or 0) <= 0 then return false end
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
 if state.aoe_cc_nearby then return false end  -- don't break nearby CC
 -- Thunder Clap: 8yd self PBAoE — multi when 2+ in hit volume
 if NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state) then
  return true
 end
 -- Single target: use Thunder Clap for attack speed debuff on bosses/elites
 if (state.tclap_remains or 0) <= 0 then
  local target = context.target
  if target and target.is_valid and target:is_valid() then
   local cls = target.get_classification and target:get_classification() or 0
   if cls >= 1 then return true end -- 1=elite, 2=rare_elite, 3=worldboss, 4=rare
  end
 end
 return false
end

local function demo_shout_matches_fn(context, state)
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
 if not (NS.aoe_target_meets and NS.aoe_target_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_8) or 8, context.target, context, state)) then return false end
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
 if state.has_battle_shout then return false end
 if state.has_commanding_shout then return false end
 return true
end

local function commanding_shout_matches_fn(context, state)
 if not spec_kit.setting_bool(context, "use_commanding_shout", false) then return false end
 if state.has_commanding_shout then return false end
 if state.has_battle_shout then return false end
 if not state.commanding_ready then return false end
 return true
end

local function shield_wall_matches_fn(context, state)
 if spec_kit.setting_bool(context, "use_shield_wall", true) == false then return false end  local group_aware = spec_kit.setting_bool(context, "warrior_group_aware_defensives", true)
  local default_threshold = (group_aware and state.is_group) and 50 or 35
  local threshold = spec_kit.setting_number(context, "defensive_hp_threshold", default_threshold)
 if (state.hp or 100) > threshold then return false end
 if state.has_shield_wall then return false end
 if NS.should_use_long_cd and not NS.should_use_long_cd(context, SHIELD_WALL_CD) then return false end
 -- IZI SDK: skip if target is damage-immune (no incoming damage)
 local target = context.target
 if target and type(target.is_damage_immune) == "function" then
     local ok, immune = pcall(target.is_damage_immune, target)
     if ok and immune then return false end
 end
 return true
end

local function last_stand_matches_fn(context, state)
 if spec_kit.setting_bool(context, "use_last_stand", true) == false then return false end  local group_aware = spec_kit.setting_bool(context, "warrior_group_aware_defensives", true)
  local default_threshold = (group_aware and state.is_group) and 50 or 35
  local threshold = spec_kit.setting_number(context, "defensive_hp_threshold", default_threshold)
 if (state.hp or 100) > threshold then return false end
 if state.has_last_stand then return false end
 return true
end

local function shield_bash_matches_fn(context, state)
 if spec_kit.setting_bool(context, "use_interrupt", true) == false then return false end
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
 if not spec_kit.setting_bool(context, "auto_taunt", true) then return false end
 if not state.taunt_ready then return false end
 local me = context.me or NS.GetPlayer()
 local target = context.target
 if not target then return false end
 -- Smart taunt: only taunt elites/bosses (classification >= 1). Elite-only is
 -- intentional: trash dies too fast to justify the CD, and the tab-target scan
 -- (prot_tab_targeting) handles un-tanked elites. Pinned by
 -- test_opener_elite_regression.lua (Taunt fires exclusively in the elite_target
 -- battery scenario) — do not broaden without updating that pin.
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
 if not spec_kit.setting_bool(context, "auto_taunt", true) then return false end
 if not state.mocking_ready then return false end
 -- Smart taunt: only mocking blow elites/bosses (classification >= 1; elite-only by design — see taunt_matches_fn)
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
 if not spec_kit.setting_bool(context, "auto_taunt", true) then return false end
 if not state.mocking_ready then return false end
 if not spec_kit.setting_bool(context, "prot_tab_targeting", true) then return false end
 if (state.enemy_count or 0) < 3 then return false end
 -- Smart taunt: only mocking blow elites/bosses (classification >= 1; elite-only by design — see taunt_matches_fn)
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
 if not spec_kit.setting_bool(context, "auto_taunt", true) then return false end
 if not state.challenging_ready then return false end
 if state.aoe_cc_nearby then return false end  -- AoE taunt would pull CC'd mobs
 -- Smart taunt: only shout on elites/bosses (classification >= 1; elite-only by design — see taunt_matches_fn)
 if (context.target_classification or 0) < 1 then return false end
 -- Skip CC'd targets
 if NS.has_target_debuff and context.target and NS.has_target_debuff(context.target, { 118, 12824, 12825, 12826, 6770, 2070, 5782, 6213, 6215, 20066, 2637, 9484, 9485, 10955 }) then return false end
 return true
end

local function concussion_blow_matches_fn(context, state)
 if not state.concussion_ready then return false end
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
 if not state.target_is_casting then return false end
 return true
end

local function intercept_matches_fn(context, state)
 if not state.intercept_ready then return false end
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
 -- NOTE (2026-08-08): get_position returns ONE vec3 table {x,y,z} (with
 -- [1]/[2] index aliases) — verified vs shared/auto_loot, shared/targeting
 -- and EaxESP (base.x or base[1]). The ORIGINAL `local dx, dy =
 -- me.get_position and me:get_position()` truncated to one value and deaded
 -- this matcher in the battery; the follow-up multi-value capture ALSO deaded
 -- it in live play (dy = nil against a table-returning API). Read the table
 -- fields with an index fallback, keeping the existence guard.
 -- Explicit existence guard (NOT the and-form): get_position returns a
 -- single vec3 table, but the and-form truncates multi-value returns —
 -- exactly the family of bug this NOTE is documenting.
 local me_pos = nil
 if me.get_position then me_pos = me:get_position() end
 local dx, dy = me_pos and (me_pos.x or me_pos[1]), me_pos and (me_pos.y or me_pos[2])
 local ally_pos = nil
 if ally.unit.get_position then ally_pos = ally.unit:get_position() end
 local ax, ay = ally_pos and (ally_pos.x or ally_pos[1]), ally_pos and (ally_pos.y or ally_pos[2])
 if not (dx and dy and ax and ay) then return false end
 local ddx, ddy = dx - ax, dy - ay
 if ddx*ddx + ddy*ddy > 625 then return false end
 return true
end

local function hamstring_matches_fn(context, state)
 if not state.hamstring_ready then return false end
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
-- Declarative Strategy DSL
-- ============================================================================
local DSL_DEFS = {
    {
        name = "LastStand",
        conditions = {
            { type = "custom", fn = function(context, state)
                return true
            end },
            { type = "in_combat" },
            { type = "setting", key = "use_last_stand", op = "truthy", default = true },
            { type = "state", field = "has_last_stand", op = "falsy" },
            { type = "custom", fn = function(context, state)
                local group_aware = spec_kit.setting_bool(context, "warrior_group_aware_defensives", true)
                local default_threshold = (group_aware and state.is_group) and 50 or 35
                local threshold = spec_kit.setting_number(context, "defensive_hp_threshold", default_threshold)
                return (state.hp or 100) <= threshold
            end },
        },
        action = { type = "cast", spell = ACTION.LastStand, target = "self", opts = { skip_range = true, expected_cooldown = FINAL_STAND_CD }, label = "[PROT] LastStand" },
    },
    {
        name = "ShieldWall",
        conditions = {
            { type = "in_combat" },
            { type = "setting", key = "use_shield_wall", op = "truthy", default = true },
            { type = "state", field = "has_shield_wall", op = "falsy" },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, SHIELD_WALL_CD) then return false end
                local group_aware = spec_kit.setting_bool(context, "warrior_group_aware_defensives", true)
                local default_threshold = (group_aware and state.is_group) and 50 or 35
                local threshold = spec_kit.setting_number(context, "defensive_hp_threshold", default_threshold)
                return (state.hp or 100) <= threshold
            end },
        },
        action = { type = "cast", spell = ACTION.ShieldWall, target = "self", opts = { skip_range = true, expected_cooldown = SHIELD_WALL_CD }, label = "[PROT] ShieldWall" },
    },
    {
        name = "Healthstone",
        conditions = {
            { type = "in_combat" },
            { type = "state", field = "healthstone_ready", op = ">", value = 0 },
            { type = "hp_threshold", unit = "self", op = "<=", value = 28 },
        },
        action = { type = "custom", fn = function(context, state)
            local id = first_ready_item(HEALTHSTONE_IDS)
            if id then return NS.use_item_by_id(id, context.me) end
            return false
        end },
    },
    {
        name = "BattleShout",
        conditions = {
            { type = "custom", fn = function(context, state)
                return true
            end },
            { type = "state", field = "has_battle_shout", op = "falsy" },
            { type = "state", field = "has_commanding_shout", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.BattleShout, target = "self", opts = { skip_range = true }, label = "[PROT] BattleShout" },
    },
    {
        name = "CommandingShout",
        conditions = {
            { type = "custom", fn = function(context, state)
                return true
            end },
            { type = "setting", key = "use_commanding_shout", op = "truthy", default = false },
            { type = "state", field = "has_commanding_shout", op = "falsy" },
            { type = "state", field = "has_battle_shout", op = "falsy" },
            { type = "state", field = "commanding_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.CommandingShout, target = "self", opts = { skip_range = true }, label = "[PROT] CommandingShout" },
    },
    {
        name = "BerserkerRage",
        conditions = {
            { type = "state", field = "berserker_rage_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                local me = context.me or NS.GetPlayer()
                return is_feared_sapped_or_incapacitated(me) == true
            end },
        },
        action = { type = "cast", spell = ACTION.BerserkerRage, target = "self", opts = { skip_range = true }, label = "[PROT] BerserkerRage" },
    },
}

-- ============================================================================
-- Strategy action metadata for centralized base_matches guards
-- ============================================================================
-- Each entry maps 1:1 to the strategies table below. Guards applied here are
-- evaluated before the strategy's own match function. DSL-substituted strategies
-- are replaced after apply_base_matches(), so their metadata is effectively a
-- placeholder; keeping it in the table preserves the 1:1 index parity.
local ACTIONS = {
    { name = "HealthPotion",        requires_target = false, requires_in_combat = true },
    { name = "DamagePotion",        requires_target = false, requires_in_combat = true },
    { name = "Healthstone",           requires_target = false },
    { name = "LastStand",             requires_target = false },
    { name = "ShieldWall",            requires_target = false },
    { name = "ShieldBash",            requires_in_combat = true },
    { name = "Pummel",                requires_in_combat = true },
    { name = "ShieldSlamPurge",       requires_in_combat = true, requires_pvp = true },
    { name = "ShieldSlam",            requires_in_combat = true },
    { name = "ShieldBlock",           requires_in_combat = true, requires_target = false },
    { name = "Revenge",               requires_in_combat = true },
    { name = "Taunt",                 requires_in_combat = true },
    { name = "TauntSecondary",        requires_in_combat = true },
    { name = "MockingBlow",           requires_in_combat = true },
    { name = "ChallengingShout",        requires_in_combat = true, requires_target = false, min_enemies = 3 },
    { name = "ThunderClap",           requires_in_combat = true, requires_target = false },
    { name = "DemoralizingShout",     requires_in_combat = true, requires_target = false },
    { name = "Devastate",             requires_in_combat = true },
    { name = "SunderArmor",           requires_in_combat = true },
    { name = "Execute",               requires_in_combat = true },
    { name = "BattleShout",             requires_target = false },
    { name = "CommandingShout",         requires_target = false },
    { name = "Cleave",                  requires_in_combat = true, min_enemies = 2 },
    { name = "HeroicStrike",            requires_in_combat = true },
    { name = "WhirlwindMulti",          requires_in_combat = true, requires_target = false, min_enemies = 2 },
    { name = "SpellReflection",         requires_in_combat = true, requires_pvp = true, requires_target = false },
    { name = "Disarm",                  requires_in_combat = true, requires_pvp = true },
    { name = "ConcussionBlow",          requires_in_combat = true, requires_pvp = true },
    { name = "Hamstring",               requires_in_combat = true, requires_pvp = true },
    { name = "Intercept",               requires_in_combat = true, requires_pvp = true },
    { name = "Intervene",               requires_in_combat = true, requires_target = false },
    { name = "BerserkerRage",           requires_target = false },
    { name = "Bloodrage",               requires_target = false },
    { name = "VictoryRush",             requires_in_combat = true },
    { name = "Rend",                    requires_in_combat = true },
    { name = "IntimidatingShout",       requires_in_combat = true, requires_target = false, min_enemies = 3 },
    { name = "RageDumpSafetyNet",       requires_in_combat = true },
    { name = "StanceSwitch",            requires_target = false },
}

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
   -- ShieldBlock above Revenge: promoted 2026-08-13 (Phase 2.2e guide
   -- divergence). The guide puts Shield Block ahead of Revenge for
   -- mitigation-over-threat when it is ready; the smart gate below (skip while
   -- the buff has >2s remaining AND incoming damage is below
   -- prot_shield_block_incoming) keeps uptime without GCD-spamming, so Revenge
   -- still fills every GCD Shield Block does not take. NOT pinned by
   -- tools/apl_status.lua tbc/warrior/protection (reference_names omit
   -- ShieldBlock — wowsims/tbc does not model it); the 6 pinned names keep
   -- their relative order, so APL conformance still passes.
   {
    name = "ShieldBlock",
    matches = function(context, state)
     if not is_defensive_stance(state.stance) then return false end
     if not state.shield_block_ready then return false end
     local me = context.me or NS.GetPlayer()
     local sb_remains = me and NS.buff_remains and NS.buff_remains(me, SHIELD_BLOCK_BUFF) or 0
     local incoming = (HealthPred and HealthPred.incoming_damage) and HealthPred.incoming_damage(me, 2.0) or 0
     local incoming_threshold = spec_kit.setting_number(context, "prot_shield_block_incoming", 1500)
     if sb_remains > 2 and incoming < incoming_threshold then return false end
     return true
    end,
    execute = function(context) return NS.try_cast(ACTION.ShieldBlock, context.me or NS.GetPlayer(), "[PROT] ShieldBlock", { skip_range = true, expected_cooldown = SHIELD_BLOCK_CD }) end,
   },
 {
  name = "Revenge",
  matches = function(context, state)
   return is_defensive_stance(state.stance) and state.revenge_ready
  end,
  execute = function(context) return NS.try_cast(ACTION.Revenge, context.target, "[PROT] Revenge", { expected_cooldown = REVENGE_CD }) end,
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

 -- 4b) Survival debuff upkeep (wowsims/tbc protection dispatch: Thunder Clap
 -- checked BEFORE Demo Shout; both placed above Devastate filler -- ~18% dmg
 -- cut + ~20% atk-speed slow).
 {
  name = "ThunderClap",
  matches = function(context, state) return thunderclap_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.ThunderClap, context.me or NS.GetPlayer(), "[PROT] ThunderClap", { skip_range = true, expected_cooldown = THUNDERCLAP_CD })
  end,
 },
 {
  name = "DemoralizingShout",
  matches = function(context, state) return demo_shout_matches_fn(context, state) end,
  execute = function(context)
   return NS.try_cast(ACTION.DemoralizingShout, context.me or NS.GetPlayer(), "[PROT] DemoShout", { skip_range = true, expected_cooldown = DEMO_SHOUT_CD })
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
   if not (NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)) then return false end
   -- Whirlwind requires Berserker Stance; in Defensive (the tank's default)
   -- try_cast fails silently every frame. Gate on stance so the lane only
   -- fires when a cast can actually succeed (stance_mode = berserker, or the
   -- execute-phase / StanceSwitch dance has landed in Berserker).
   if state.stance ~= STANCE.BERSERKER then return false end
   if not NS.spell_ready or not NS.spell_ready(ACTION.Whirlwind, context.me, { skip_range = true }) then return false end
   return true
  end,
  execute = function(context)
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
 },    { name = "StanceSwitch",
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

-- Apply centralized base_matches guards to imperative strategies. DSL-substituted
-- strategies are replaced in the loop below, so their placeholders are not
-- affected by the wrapper.
apply_base_matches(strategies, ACTIONS)

-- Replace imperative match functions with DSL-compiled equivalents.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("protection", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warrior Protection rotation registered") end
return { strategies = strategies, build_state = build_state }
