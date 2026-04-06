-- =============================================================================
-- PALADIN MAIN ROTATION - SYLVANAS FRAMEWORK
-- Converted from Flux AIO Paladin
-- 3 playstyles: Holy (healer), Protection (tank), Retribution (DPS)
-- Self-contained version with local Spells
-- =============================================================================

local core = _G.core
local izi = require("common/izi_sdk")
local FluxCompat = require("libraries.flux_compat")

-- Load middleware module
require("paladin/middleware")

-- =============================================================================
-- SPELL DEFINITIONS
-- =============================================================================
local Spells = {
   -- Racials
   Berserking = izi.spell(26297),
   ArcaneTorrent = izi.spell(28730),
   BloodFury = izi.spell(20572),
   Stoneform = izi.spell(20594),
   EscapeArtist = izi.spell(20589),
   GiftOfTheNaaru = izi.spell(28880),

   -- Seals
   SealOfRighteousness = izi.spell(27155),
   SealOfBlood = izi.spell(31892),
   SealOfCommand = izi.spell(27170),
   SealOfVengeance = izi.spell(31801),
   SealOfWisdom = izi.spell(27166),
   SealOfLight = izi.spell(27160),
   SealOfJustice = izi.spell(31895),
   SealOfTheCrusader = izi.spell(27158),

   -- Judgements
   Judgement = izi.spell(20271),
   JudgementOfRighteousness = izi.spell(27157),
   JudgementOfBlood = izi.spell(31898),
   JudgementOfCommand = izi.spell(27172),
   JudgementOfVengeance = izi.spell(31804),
   JudgementOfWisdom = izi.spell(27164),
   JudgementOfLight = izi.spell(27162),
   JudgementOfJustice = izi.spell(31896),
   JudgementOfTheCrusader = izi.spell(27159),

   -- Auras
   DevotionAura = izi.spell(27149),
   RetributionAura = izi.spell(27150),
   ConcentrationAura = izi.spell(19746),
   ShadowResistanceAura = izi.spell(27151),
   FrostResistanceAura = izi.spell(27152),
   FireResistanceAura = izi.spell(27153),
   CrusaderAura = izi.spell(32223),

   -- Blessings
   BlessingOfMight = izi.spell(27140),
   BlessingOfWisdom = izi.spell(27143),
   BlessingOfKings = izi.spell(20217),
   BlessingOfSalvation = izi.spell(1038),
   BlessingOfSanctuary = izi.spell(20911),
   BlessingOfLight = izi.spell(27144),
   GreaterBlessingOfMight = izi.spell(27141),
   GreaterBlessingOfWisdom = izi.spell(27142),
   GreaterBlessingOfKings = izi.spell(25898),
   GreaterBlessingOfSalvation = izi.spell(25895),
   GreaterBlessingOfSanctuary = izi.spell(27169),
   GreaterBlessingOfLight = izi.spell(27145),

   -- Holy spells
   HolyLight = izi.spell(27136),
   FlashOfLight = izi.spell(27137),
   HolyShock = izi.spell(33074),
   DivineFavor = izi.spell(20216),
   DivineIllumination = izi.spell(31842),
   BeaconOfLight = izi.spell(53563),
   SacredShield = izi.spell(53601),
   LayOnHands = izi.spell(27154),
   DivineProtection = izi.spell(498),
   DivineShield = izi.spell(642),
   HandOfSacrifice = izi.spell(6940),
   HandOfProtection = izi.spell(10278),
   HandOfSalvation = izi.spell(1038),
   HandOfFreedom = izi.spell(1044),
   AvengingWrath = izi.spell(31884),
   Consecration = izi.spell(27173),
   Exorcism = izi.spell(27138),
   TurnEvil = izi.spell(10326),
   HolyWrath = izi.spell(27139),

   -- Protection spells
   RighteousFury = izi.spell(25780),
   HolyShield = izi.spell(27179),
   AvengersShield = izi.spell(32699),
   ShieldOfRighteousness = izi.spell(53600),
   HammerOfTheRighteous = izi.spell(53595),
   HandOfReckoning = izi.spell(62124),
   RighteousDefense = izi.spell(31789),
   ArdentDefender = izi.spell(31850),
   DivineGuardian = izi.spell(53530),
   GuardianOfAncientKings = izi.spell(86150),

   -- Retribution spells
   CrusaderStrike = izi.spell(35395),
   DivineStorm = izi.spell(53385),
   JudgementsOfTheWise = izi.spell(31878),
   TheArtOfWar = izi.spell(53489),
   Repentance = izi.spell(20066),
   HammerOfWrath = izi.spell(24275),
   DivinePlea = izi.spell(54428),

   -- Items
   HealthstoneMaster = izi.item(22105),
   HealthstoneMajor = izi.item(22104),
   SuperHealingPotion = izi.item(22829),
   MajorHealingPotion = izi.item(13446),
   SuperManaPotion = izi.item(22832),
   MajorManaPotion = izi.item(13443),
   HastePotion = izi.item(22838),
}

-- =============================================================================
-- DEFAULT SETTINGS
-- =============================================================================
local defaults = {
   playstyle = "retribution",
   aura_devotion = false,
   aura_retribution = true,
   aura_concentration = false,
   aura_shadow_resistance = false,
   aura_frost_resistance = false,
   aura_fire_resistance = false,
   auto_blessing = true,
   blessing_might = false,
   blessing_wisdom = true,
   blessing_kings = false,
   ret_seal_twist = true,
   ret_seal_blood = true,
   ret_seal_command = false,
   ret_use_judgement = true,
   ret_use_crusader_strike = true,
   ret_use_divine_storm = true,
   ret_use_exorcism = true,
   ret_use_consecration = true,
   prot_seal_vengeance = true,
   prot_seal_righteousness = false,
   prot_use_holy_shield = true,
   prot_use_judgement = true,
   prot_use_shield_of_righteousness = true,
   prot_use_hammer_of_righteousness = true,
   prot_use_consecration = true,
   prot_use_avengers_shield = true,
   holy_use_holy_light = true,
   holy_use_flash_of_light = true,
   holy_use_holy_shock = true,
   holy_use_divine_favor = true,
   holy_use_divine_illumination = true,
   holy_use_beacon = true,
   holy_use_sacred_shield = true,
   use_avenging_wrath = true,
   use_divine_protection = true,
   use_divine_shield = true,
   use_lay_on_hands = true,
   divine_protection_hp = 30,
   divine_shield_hp = 20,
   lay_on_hands_hp = 10,
   use_mana_potion = true,
   mana_potion_pct = 30,
   use_healing_potion = true,
   healing_potion_hp = 25,
}

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================
local function get_setting(key)
   return defaults[key]
end

local function try_cast(spell, target, msg)
   if not spell or not spell:is_learned() then
      return false
   end
   if not spell:is_usable() then
      return false
   end
   if target then
      if not spell:is_castable_to_unit(target) then
         return false
      end
   end
   return spell:cast(target, msg or "")
end

local function get_playstyle()
   return defaults.playstyle
end

-- =============================================================================
-- FLUXCOMPAT MIDDLEWARE REGISTRATION
-- =============================================================================
FluxCompat.register_trinket_middleware()

FluxCompat.register_defensive_middleware({
   spell_divine_protection = Spells.DivineProtection,
   spell_divine_shield = Spells.DivineShield,
   spell_hand_of_sacrifice = Spells.HandOfSacrifice,
})

FluxCompat.register_burst_middleware({
   spell_avenging_wrath = Spells.AvengingWrath,
})

-- =============================================================================
-- HEALING TARGET SCANNER
-- =============================================================================
local PARTY_UNITS = {"player", "party1", "party2", "party3", "party4"}
local RAID_UNITS = {}
for i = 1, 40 do
   RAID_UNITS[i] = "raid" .. i
end

local function scan_healing_targets()
   local targets = {}
   local count = 0
   local emergency_threshold = 40

   local group_size = 0
   local members = izi.party and izi.party() or {}
   if #members == 0 and izi.raid then
      members = izi.raid() or {}
   end
   group_size = #members

   local unit_list = (group_size > 5) and RAID_UNITS or PARTY_UNITS

   for _, unit in ipairs(unit_list) do
      local unit_obj = izi.unit and izi.unit(unit) or nil
      if unit_obj and unit_obj:is_valid() and not unit_obj:is_dead_or_ghost() then
         local hp = (unit_obj:get_health() / unit_obj:get_health_max()) * 100
         if hp < 100 then
            count = count + 1
            targets[count] = {
               unit = unit_obj,
               unit_id = unit,
               hp = hp,
               is_player = (unit == "player"),
               needs_cleanse = false,
            }
         end
      end
   end

   table.sort(targets, function(a, b) return a.hp < b.hp end)

   return targets, count
end

-- =============================================================================
-- CONTEXT BUILDER
-- =============================================================================
local function build_context()
   local me = izi.me()
   local target = izi.target()

   if not me or not me.is_valid or not me:is_valid() then
      return nil
   end

   local seal_blood_active = me:buff_up(Spells.SealOfBlood and Spells.SealOfBlood:id() or 0)
   local seal_command_active = me:buff_up(Spells.SealOfCommand and Spells.SealOfCommand:id() or 0)

   local aura_devotion_active = me:buff_up(Spells.DevotionAura and Spells.DevotionAura:id() or 0)
   local aura_retribution_active = me:buff_up(Spells.RetributionAura and Spells.RetributionAura:id() or 0)
   local aura_concentration_active = me:buff_up(Spells.ConcentrationAura and Spells.ConcentrationAura:id() or 0)

   local ctx = FluxCompat.build_context(me, target, {
      holy_power = me:power_current(),
      seal_blood_active = seal_blood_active,
      seal_command_active = seal_command_active,
      aura_devotion_active = aura_devotion_active,
      aura_retribution_active = aura_retribution_active,
      aura_concentration_active = aura_concentration_active,
   })

   ctx.force_burst = FluxCompat.is_force_active("burst")
   ctx.force_defensive = FluxCompat.is_force_active("defensive")
   ctx.should_burst = FluxCompat.should_auto_burst(ctx)

   ctx.has_valid_enemy_target = target and target.is_valid and target:is_valid() and target.is_valid_enemy and target:is_valid_enemy()
   ctx.target_hp = target and target.get_health_percentage and target:get_health_percentage() or 0
   ctx.target_range = target and target.distance and target:distance() or 999
   ctx.in_melee_range = target and target.distance and target:distance() <= 5

   ctx.settings = defaults

   return ctx
end

-- =============================================================================
-- HOLY (HEALER) ROTATION
-- =============================================================================
local function execute_holy_rotation(ctx)
   local s = ctx.settings
   local me = ctx.me

   local targets, count = scan_healing_targets()
   if count == 0 then return nil end

   local lowest = targets[1]
   local unit = lowest.unit
   local hp = lowest.hp

   if s.use_lay_on_hands and hp <= s.lay_on_hands_hp then
      if Spells.LayOnHands and Spells.LayOnHands:is_learned() and Spells.LayOnHands:is_usable() then
         if try_cast(Spells.LayOnHands, unit, "[P1] Lay on Hands - EMERGENCY") then
            return true
         end
      end
   end

   if s.holy_use_divine_favor and hp <= 40 then
      if Spells.DivineFavor and Spells.DivineFavor:is_learned() and Spells.DivineFavor:is_usable() then
         try_cast(Spells.DivineFavor, nil, "[P2] Divine Favor")
      end
   end

   if s.holy_use_holy_shock and hp <= 50 then
      if Spells.HolyShock and Spells.HolyShock:is_learned() and Spells.HolyShock:is_usable() then
         if try_cast(Spells.HolyShock, unit, "[P3] Holy Shock - Emergency") then
            return true
         end
      end
   end

   if s.holy_use_holy_light and hp <= 60 then
      if Spells.HolyLight and Spells.HolyLight:is_learned() and Spells.HolyLight:is_usable() then
         if try_cast(Spells.HolyLight, unit, "[P4] Holy Light") then
            return true
         end
      end
   end

   if s.holy_use_flash_of_light and hp <= 80 then
      if Spells.FlashOfLight and Spells.FlashOfLight:is_learned() and Spells.FlashOfLight:is_usable() then
         if try_cast(Spells.FlashOfLight, unit, "[P5] Flash of Light") then
            return true
         end
      end
   end

   if s.holy_use_beacon and count > 0 then
      local tank = targets[1]
      if Spells.BeaconOfLight and Spells.BeaconOfLight:is_learned() then
         local tank_unit = tank.unit
         if tank_unit and not tank_unit:buff_up(Spells.BeaconOfLight:id()) then
            if Spells.BeaconOfLight:is_usable() then
               if try_cast(Spells.BeaconOfLight, tank.unit_id, "[P6] Beacon of Light") then
                  return true
               end
            end
         end
      end
   end

   return nil
end

-- =============================================================================
-- PROTECTION (TANK) ROTATION
-- =============================================================================
local function execute_protection_rotation(ctx)
   local s = ctx.settings
   local me = ctx.me
   local target = ctx.target

   if not ctx.has_valid_enemy_target then return nil end

   if not ctx.seal_blood_active and not ctx.seal_command_active then
      if s.prot_seal_vengeance and Spells.SealOfVengeance and Spells.SealOfVengeance:is_learned() then
         if Spells.SealOfVengeance:is_usable() then
            if try_cast(Spells.SealOfVengeance, nil, "[P1] Seal of Vengeance") then
               return true
            end
         end
      end
      if s.prot_seal_righteousness and Spells.SealOfRighteousness and Spells.SealOfRighteousness:is_learned() then
         if Spells.SealOfRighteousness:is_usable() then
            if try_cast(Spells.SealOfRighteousness, nil, "[P1] Seal of Righteousness") then
               return true
            end
         end
      end
   end

   if s.prot_use_holy_shield and Spells.HolyShield and Spells.HolyShield:is_learned() then
      if not me:buff_up(Spells.HolyShield:id()) then
         if Spells.HolyShield:is_usable() then
            if try_cast(Spells.HolyShield, nil, "[P2] Holy Shield") then
               return true
            end
         end
      end
   end

   if s.prot_use_avengers_shield and Spells.AvengersShield and Spells.AvengersShield:is_learned() then
      if Spells.AvengersShield:is_usable() and not ctx.in_melee_range then
         if try_cast(Spells.AvengersShield, target, "[P3] Avenger's Shield") then
            return true
         end
      end
   end

   if s.prot_use_judgement and Spells.Judgement and Spells.Judgement:is_learned() then
      if Spells.Judgement:is_usable() and ctx.in_melee_range then
         if try_cast(Spells.Judgement, target, "[P4] Judgement") then
            return true
         end
      end
   end

   if s.prot_use_shield_of_righteousness and Spells.ShieldOfRighteousness and Spells.ShieldOfRighteousness:is_learned() then
      if Spells.ShieldOfRighteousness:is_usable() and ctx.in_melee_range then
         if try_cast(Spells.ShieldOfRighteousness, target, "[P5] Shield of Righteousness") then
            return true
         end
      end
   end

   if s.prot_use_hammer_of_righteousness and Spells.HammerOfTheRighteous and Spells.HammerOfTheRighteous:is_learned() then
      if Spells.HammerOfTheRighteous:is_usable() and ctx.in_melee_range then
         if try_cast(Spells.HammerOfTheRighteous, target, "[P6] Hammer of the Righteous") then
            return true
         end
      end
   end

   if s.prot_use_consecration and Spells.Consecration and Spells.Consecration:is_learned() then
      if Spells.Consecration:is_usable() and ctx.in_melee_range then
         if try_cast(Spells.Consecration, nil, "[P7] Consecration") then
            return true
         end
      end
   end

   return nil
end

-- =============================================================================
-- RETRIBUTION (DPS) ROTATION
-- =============================================================================
local function execute_retribution_rotation(ctx)
   local s = ctx.settings
   local me = ctx.me
   local target = ctx.target

   if not ctx.has_valid_enemy_target then return nil end

   if not ctx.seal_blood_active and not ctx.seal_command_active then
      if s.ret_seal_blood and Spells.SealOfBlood and Spells.SealOfBlood:is_learned() then
         if Spells.SealOfBlood:is_usable() then
            if try_cast(Spells.SealOfBlood, nil, "[P1] Seal of Blood") then
               return true
            end
         end
      end
      if s.ret_seal_command and Spells.SealOfCommand and Spells.SealOfCommand:is_learned() then
         if Spells.SealOfCommand:is_usable() then
            if try_cast(Spells.SealOfCommand, nil, "[P1] Seal of Command") then
               return true
            end
         end
      end
   end

   if s.use_avenging_wrath and Spells.AvengingWrath and Spells.AvengingWrath:is_learned() then
      if Spells.AvengingWrath:is_usable() and ctx.in_combat then
         if try_cast(Spells.AvengingWrath, nil, "[P2] Avenging Wrath - Burst") then
            return true
         end
      end
   end

   if s.ret_use_judgement and Spells.Judgement and Spells.Judgement:is_learned() then
      if Spells.Judgement:is_usable() and ctx.in_melee_range then
         if try_cast(Spells.Judgement, target, "[P3] Judgement") then
            return true
         end
      end
   end

   if s.ret_use_divine_storm and Spells.DivineStorm and Spells.DivineStorm:is_learned() then
      if Spells.DivineStorm:is_usable() and ctx.in_melee_range then
         if try_cast(Spells.DivineStorm, target, "[P4] Divine Storm") then
            return true
         end
      end
   end

   if s.ret_use_crusader_strike and Spells.CrusaderStrike and Spells.CrusaderStrike:is_learned() then
      if Spells.CrusaderStrike:is_usable() and ctx.in_melee_range then
         if try_cast(Spells.CrusaderStrike, target, "[P5] Crusader Strike") then
            return true
         end
      end
   end

   if s.ret_use_exorcism and Spells.Exorcism and Spells.Exorcism:is_learned() then
      if Spells.Exorcism:is_usable() then
         local creature_type = target:get_creature_type()
         if creature_type == 6 or creature_type == 3 then
            if try_cast(Spells.Exorcism, target, "[P6] Exorcism") then
               return true
            end
         end
      end
   end

   if s.ret_use_consecration and Spells.Consecration and Spells.Consecration:is_learned() then
      if Spells.Consecration:is_usable() and ctx.in_melee_range then
         if try_cast(Spells.Consecration, nil, "[P7] Consecration") then
            return true
         end
      end
   end

   return nil
end

-- =============================================================================
-- SHARED FUNCTIONS
-- =============================================================================
local function check_defensive(ctx)
   local s = ctx.settings
   local me = ctx.me

   if not ctx.in_combat then return nil end

   if s.use_divine_protection and ctx.hp <= s.divine_protection_hp then
      if Spells.DivineProtection and Spells.DivineProtection:is_learned() and Spells.DivineProtection:is_usable() then
         if try_cast(Spells.DivineProtection, nil, "[P1] Divine Protection - Defensive") then
            return true
         end
      end
   end

   if s.use_divine_shield and ctx.hp <= s.divine_shield_hp then
      if Spells.DivineShield and Spells.DivineShield:is_learned() and Spells.DivineShield:is_usable() then
         if try_cast(Spells.DivineShield, nil, "[P1] Divine Shield - Emergency") then
            return true
         end
      end
   end

   return nil
end

local function check_auras(ctx)
   local s = ctx.settings
   local me = ctx.me

   if s.aura_retribution and Spells.RetributionAura and Spells.RetributionAura:is_learned() then
      if not me:buff_up(Spells.RetributionAura:id()) then
         if Spells.RetributionAura:is_usable() then
            if try_cast(Spells.RetributionAura, nil, "[P2] Retribution Aura") then
               return true
            end
         end
      end
   end

   if s.aura_devotion and Spells.DevotionAura and Spells.DevotionAura:is_learned() then
      if not me:buff_up(Spells.DevotionAura:id()) then
         if Spells.DevotionAura:is_usable() then
            if try_cast(Spells.DevotionAura, nil, "[P2] Devotion Aura") then
               return true
            end
         end
      end
   end

   if s.aura_concentration and Spells.ConcentrationAura and Spells.ConcentrationAura:is_learned() then
      if not me:buff_up(Spells.ConcentrationAura:id()) then
         if Spells.ConcentrationAura:is_usable() then
            if try_cast(Spells.ConcentrationAura, nil, "[P2] Concentration Aura") then
               return true
            end
         end
      end
   end

   return nil
end

local function check_blessings(ctx)
   local s = ctx.settings
   local me = ctx.me

   if not s.auto_blessing then return nil end

   local blessing_spell = nil
   if s.blessing_might and Spells.BlessingOfMight and Spells.BlessingOfMight:is_learned() then
      blessing_spell = Spells.BlessingOfMight
   elseif s.blessing_wisdom and Spells.BlessingOfWisdom and Spells.BlessingOfWisdom:is_learned() then
      blessing_spell = Spells.BlessingOfWisdom
   elseif s.blessing_kings and Spells.BlessingOfKings and Spells.BlessingOfKings:is_learned() then
      blessing_spell = Spells.BlessingOfKings
   end

   if blessing_spell and not me:buff_up(blessing_spell:id()) then
      if blessing_spell:is_usable() then
         if try_cast(blessing_spell, nil, "[P3] Blessing") then
            return true
         end
      end
   end

   return nil
end

-- =============================================================================
-- MAIN ROTATION EXECUTION
-- =============================================================================
local function on_update_callback()
   local ctx = build_context()
   if not ctx then return nil end

   return FluxCompat.rotation_registry:execute_middleware(ctx, function(ctx)
      if check_defensive(ctx) then return true end
      if check_auras(ctx) then return true end
      if check_blessings(ctx) then return true end

      local playstyle = ctx.settings.playstyle

      if playstyle == "holy" then
         if execute_holy_rotation(ctx) then return true end
      elseif playstyle == "protection" then
         if execute_protection_rotation(ctx) then return true end
      elseif playstyle == "retribution" then
         if execute_retribution_rotation(ctx) then return true end
      end

      return false
   end)
end

-- =============================================================================
-- REGISTER CALLBACK
-- =============================================================================
core.register_on_update_callback(on_update_callback)

-- =============================================================================
-- LOG
-- =============================================================================
core.log("Paladin main rotation loaded - v1.8.0")
