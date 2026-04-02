--[[
  Theory Validation: Rotation Simulator Core
  
  Simulates encounter timelines and tests rotation logic without live gameplay.
  Provides mathematical validation of spell priorities, mana sustain, and output.
]]

local simulator = {}

-- TBC Base Stats (T4/T5 gear level)
simulator.BASE_STATS = {
  -- Casters
  MAGE = { int = 450, spi = 280, spelldmg = 850, crit = 22, hit = 12, haste = 0, mana = 11000 },
  WARLOCK = { int = 420, spi = 300, spelldmg = 900, crit = 20, hit = 12, haste = 0, mana = 10500 },
  PRIEST = { int = 440, spi = 350, spelldmg = 800, crit = 18, hit = 0, haste = 0, mana = 11500 },
  DRUID_BALANCE = { int = 430, spi = 320, spelldmg = 820, crit = 20, hit = 10, haste = 0, mana = 12000 },
  SHAMAN_ELEMENTAL = { int = 410, spi = 280, spelldmg = 880, crit = 19, hit = 12, haste = 0, mana = 10500 },
  PALADIN_HOLY = { int = 380, spi = 300, spelldmg = 750, crit = 16, mp5 = 80, mana = 10000 },
  
  -- Physical DPS
  WARRIOR_ARMS = { str = 280, agi = 180, ap = 2200, crit = 32, hit = 8, exp = 6, haste = 0, health = 13000 },
  WARRIOR_FURY = { str = 300, agi = 200, ap = 2400, crit = 35, hit = 8, exp = 6, haste = 0, health = 12500 },
  ROGUE_ASSASSINATION = { str = 220, agi = 320, ap = 2100, crit = 30, hit = 9, exp = 6, haste = 0, energy = 100 },
  ROGUE_COMBAT = { str = 240, agi = 300, ap = 2200, crit = 28, hit = 9, exp = 6, haste = 0, energy = 100 },
  HUNTER_BM = { agi = 340, ap = 2100, crit = 26, hit = 9, haste = 0, mana = 9000, pet_ap = 1400 },
  HUNTER_MM = { agi = 360, ap = 2200, crit = 24, hit = 9, haste = 0, mana = 9000 },
  HUNTER_SURVIVAL = { agi = 380, ap = 2000, crit = 22, hit = 9, haste = 0, mana = 9000 },
  ENHANCEMENT_SHAMAN = { str = 260, agi = 220, ap = 1900, crit = 28, hit = 9, exp = 6, haste = 0, mana = 6000 },
  FERAL_DRUID = { str = 280, agi = 280, ap = 2300, crit = 30, hit = 8, exp = 6, haste = 0, energy = 100 },
  RETRIBUTION_PALADIN = { str = 320, agi = 120, ap = 2000, spelldmg = 500, crit = 26, hit = 8, exp = 6, mana = 5000 },
  
  -- Tanks
  WARRIOR_PROTECTION = { str = 240, agi = 140, sta = 450, armor = 14000, def = 490, dodge = 18, parry = 15, block = 20, block_value = 450, health = 16500 },
  PALADIN_PROTECTION = { str = 220, agi = 120, sta = 420, armor = 13500, def = 490, dodge = 16, parry = 14, block = 22, block_value = 400, spelldmg = 300, mana = 7000, health = 15500 },
  FERAL_BEAR = { str = 320, agi = 180, sta = 480, armor = 22000, dodge = 22, health = 18000 },
  
  -- Healers
  RESTO_DRUID = { int = 420, spi = 380, healbonus = 1800, crit = 12, haste = 0, mp5 = 60, mana = 12500 },
  RESTO_SHAMAN = { int = 400, spi = 320, healbonus = 1900, crit = 14, haste = 0, mp5 = 70, mana = 11000 },
  HOLY_PRIEST = { int = 440, spi = 400, healbonus = 1850, crit = 12, haste = 0, mp5 = 65, mana = 12000 },
  DISC_PRIEST = { int = 430, spi = 350, healbonus = 1750, crit = 15, haste = 0, mp5 = 60, mana = 11500 },
  HOLY_PALADIN = { int = 380, spi = 280, healbonus = 1950, crit = 18, haste = 0, mp5 = 85, mana = 10500 },
}

-- TBC Boss Encounters (simplified)
simulator.ENCOUNTERS = {
  -- Tier 4
  gruul = {
    name = "Gruul the Dragonkiller",
    level = 73,
    health = 4000000,
    armor = 7700,
    fight_duration = 480, -- 8 minutes
    tank_damage_per_sec = 2500, -- Physical
    raid_damage_periodic = 800, -- Shatter
    mechanics = { "growth", "shatter", "cave_in" },
    requires_interrupt = false,
  },
  magtheridon = {
    name = "Magtheridon",
    level = 73,
    health = 4500000,
    armor = 7700,
    fight_duration = 600, -- 10 minutes
    tank_damage_per_sec = 2800,
    raid_damage_periodic = 1000, -- Conflag
    mechanics = { "quakes", "conflag", "hellfire" },
    requires_interrupt = true, -- Channelers
  },
  
  -- Tier 5
  void_reaver = {
    name = "Void Reaver",
    level = 73,
    health = 5500000,
    armor = 7700,
    fight_duration = 480,
    tank_damage_per_sec = 3000,
    raid_damage_periodic = 1200, -- Orbs
    mechanics = { "orbs", "knockback" },
    requires_interrupt = false,
  },
  lurker = {
    name = "The Lurker Below",
    level = 73,
    health = 5000000,
    armor = 7700,
    fight_duration = 540,
    tank_damage_per_sec = 2200,
    raid_damage_periodic = 600, -- Spout
    mechanics = { "spout", "geyser", "coil" },
    requires_interrupt = false,
  },
  
  -- Tier 6
  najentus = {
    name = "High Warlord Naj'entus",
    level = 73,
    health = 6500000,
    armor = 7700,
    fight_duration = 480,
    tank_damage_per_sec = 3500,
    raid_damage_periodic = 1500, -- Tidal shield
    mechanics = { "tidal_shield", "spine", "enrage" },
    requires_interrupt = false,
  },
}

-- Spell coefficients and damage formulas
simulator.SPELL_DATA = {
  -- Druid Balance
  wrath = { base = 450, coeff = 0.571, cast_time = 2, mana = 255, school = "nature" },
  starfire = { base = 630, coeff = 1.0, cast_time = 3.5, mana = 370, school = "arcane" },
  moonfire_dot = { base = 600, coeff = 0.13, duration = 12, mana = 280, school = "arcane" },
  insect_swarm = { base = 744, coeff = 0.126, duration = 12, mana = 205, school = "nature" },
  
  -- Mage
  frostbolt = { base = 630, coeff = 0.814, cast_time = 3, mana = 330, school = "frost", debuff = "slow" },
  fireball = { base = 750, coeff = 1.0, cast_time = 3.5, mana = 425, school = "fire" },
  scorch = { base = 300, coeff = 0.429, cast_time = 1.5, mana = 180, school = "fire", debuff = "imp_scorch" },
  arcane_blast = { base = 720, coeff = 0.714, cast_time = 2.5, mana = 195, school = "arcane", stackable = true },
  arcane_missiles = { base = 800, coeff = 1.0, cast_time = 5, mana = 785, school = "arcane", channeled = true },
  
  -- Warlock
  shadow_bolt = { base = 650, coeff = 0.857, cast_time = 3, mana = 420, school = "shadow" },
  immolate = { base = 500, coeff = 0.2, cast_time = 2, mana = 445, school = "fire", dot_component = true },
  corruption = { base = 900, coeff = 1.2, duration = 18, mana = 370, school = "shadow" },
  unstable_affliction = { base = 1050, coeff = 1.2, duration = 18, mana = 400, school = "shadow" },
  drain_soul = { base = 600, coeff = 0.429, cast_time = 15, mana = 420, school = "shadow", channeled = true, execute = true },
  
  -- Hunter
  steady_shot = { base = 150, weapon_scaling = 0.2, cast_time = 1.5, mana = 110, school = "physical", requires_ranged = true },
  arcane_shot = { base = 250, ap_scaling = 0.15, instant = true, mana = 230, school = "arcane", cooldown = 6 },
  aimed_shot = { base = 300, weapon_scaling = 0.2, cast_time = 2.5, mana = 310, school = "physical", requires_ranged = true, cooldown = 6 },
  multi_shot = { base = 200, weapon_scaling = 0.2, cast_time = 0.5, mana = 275, school = "physical", targets = 3 },
  serpent_sting = { base = 800, coeff = 0.2, duration = 15, mana = 250, school = "nature" },
  
  -- Warrior
  bloodthirst = { base = 0, ap_scaling = 0.45, instant = true, rage = 30, school = "physical", requires_melee = true, cooldown = 4 },
  mortal_strike = { base = 150, weapon_scaling = 0.45, instant = true, rage = 30, school = "physical", requires_melee = true, cooldown = 6, debuff = "healing_reduced" },
  whirlwind = { base = 100, weapon_scaling = 0.25, instant = true, rage = 25, school = "physical", requires_melee = true, cooldown = 10, targets = 4 },
  shield_slam = { base = 300, block_value_scaling = 1.0, instant = true, rage = 20, school = "physical", requires_shield = true, cooldown = 6 },
  revenge = { base = 250, ap_scaling = 0.2, instant = true, rage = 5, school = "physical", requires_melee = true, proc_only = true },
  devastate = { base = 100, sunder_bonus = true, instant = true, rage = 15, school = "physical", requires_melee = true },
  
  -- Rogue
  sinister_strike = { base = 100, weapon_scaling = 0.5, instant = true, energy = 45, school = "physical", requires_melee = true, combo_points = 1 },
  mutilate = { base = 150, weapon_scaling = 0.5, instant = true, energy = 60, school = "physical", requires_melee = true, requires_poison = true, combo_points = 2 },
  eviscerate = { base = 300, ap_scaling = 0.15, instant = true, energy = 35, school = "physical", finisher = true, combo_points = "all" },
  rupture = { base = 400, ap_scaling = 0.24, instant = true, energy = 25, school = "physical", finisher = true, duration = 6, combo_points = "all", dot = true },
  slice_and_dice = { base = 0, instant = true, energy = 25, buff = "attack_speed", finisher = true, combo_points = "all" },
  
  -- Healers (HPS values)
  greater_heal = { base_heal = 2500, coeff = 0.857, cast_time = 3, mana = 750, school = "holy" },
  flash_heal = { base_heal = 1500, coeff = 0.429, cast_time = 1.5, mana = 375, school = "holy" },
  chain_heal = { base_heal = 900, coeff = 0.714, cast_time = 2.5, mana = 435, school = "nature", bounces = 2, bounce_decay = 0.5 },
  rejuvenation = { base_heal = 1500, coeff = 0.2, duration = 12, mana = 305, school = "nature", hot = true },
  regrowth = { base_heal = 1800, coeff = 0.5, cast_time = 2, mana = 530, school = "nature", hot_component = true },
  lifebloom = { base_heal = 600, coeff = 0.067, duration = 7, mana = 220, school = "nature", stackable = 3, bloom = true },
  power_word_shield = { base_absorb = 2500, coeff = 0.3, instant = true, mana = 600, school = "holy", debuff = "weakened_soul" },
  earth_shield = { base_heal = 800, coeff = 0.1, charges = 6, mana = 325, school = "nature", hot = true },
}

-- Calculate spell damage/healing
function simulator.calculate_output(spell_name, stats, encounter, buffs)
  local spell = simulator.SPELL_DATA[spell_name]
  if not spell then return 0, 0 end
  
  local output = spell.base or spell.base_heal or 0
  local mana_cost = spell.mana or spell.energy or spell.rage or 0
  
  -- Apply coefficients
  if spell.coeff and stats.spelldmg then
    output = output + (stats.spelldmg * spell.coeff)
  end
  if spell.ap_scaling and stats.ap then
    output = output + (stats.ap * spell.ap_scaling)
  end
  
  -- Apply talents/raid buffs (simplified)
  output = output * 1.1 -- Raid buffs approximately
  
  -- Critical strikes (average)
  local crit_chance = (stats.crit or 0) / 100
  output = output * (1 + (crit_chance * 0.5)) -- 50% crit bonus
  
  -- Hit chance (boss level = 17% miss for casters, 8% for melee)
  local hit_cap = spell.school and 0.83 or 0.92
  local hit_chance = math.min(hit_cap + ((stats.hit or 0) / 100), 0.99)
  output = output * hit_chance
  
  return output, mana_cost
end

-- Run rotation simulation
function simulator.run_rotation(spec_name, encounter_name, duration)
  local encounter = simulator.ENCOUNTERS[encounter_name]
  if not encounter then return nil, "Encounter not found" end
  
  duration = duration or encounter.fight_duration
  local stats = simulator.BASE_STATS[spec_name]
  if not stats then return nil, "Spec not found" end
  
  local total_output = 0
  local total_mana_spent = 0
  local total_mana_regen = (stats.mp5 or 0) * (duration / 5)
  local gcd_spent = 0
  local casts = {}
  local current_time = 0
  local current_mana = stats.mana
  
  -- Simplified rotation logic
  local rotation = simulator.get_rotation(spec_name)
  if not rotation then return nil, "Rotation not defined" end
  
  while current_time < duration do
    local best_spell = nil
    local best_dpm = 0
    
    -- Find best spell based on priority and mana
    for _, spell_name in ipairs(rotation.priority) do
      local spell = simulator.SPELL_DATA[spell_name]
      if spell then
        local output, mana_cost = simulator.calculate_output(spell_name, stats, encounter)
        local cast_time = spell.cast_time or (spell.instant and 1.5) or 2
        local dpm = output / (mana_cost > 0 and mana_cost or 1)
        
        -- Check mana constraint
        if current_mana >= mana_cost then
          if dpm > best_dpm then
            best_dpm = dpm
            best_spell = spell_name
          end
        end
      end
    end
    
    if not best_spell then
      -- OOM - wand/shoot
      break
    end
    
    local spell = simulator.SPELL_DATA[best_spell]
    local output, mana_cost = simulator.calculate_output(best_spell, stats, encounter)
    local cast_time = spell.cast_time or (spell.instant and 1.5) or 2
    
    -- Apply cast
    total_output = total_output + output
    current_mana = current_mana - mana_cost
    current_time = current_time + cast_time
    gcd_spent = gcd_spent + 1
    
    table.insert(casts, {
      time = current_time,
      spell = best_spell,
      output = output,
      mana_cost = mana_cost
    })
  end
  
  -- Final calculations
  local dps = total_output / duration
  local mps = total_mana_spent / duration
  local oom_time = current_mana > 0 and duration or current_time
  
  return {
    spec = spec_name,
    encounter = encounter_name,
    duration = duration,
    total_output = total_output,
    dps = dps,
    total_mana_spent = total_mana_spent,
    mana_regen = total_mana_regen,
    net_mana = total_mana_regen - total_mana_spent,
    oom_time = oom_time,
    casts = #casts,
    cast_list = casts,
    verdict = simulator.generate_verdict(dps, oom_time, duration, spec_name)
  }
end

-- Get rotation priority for spec
function simulator.get_rotation(spec_name)
  local rotations = {
    -- Mages
    MAGE_ARCANE = { priority = { "arcane_blast", "arcane_missiles", "fire_blast" } },
    MAGE_FIRE = { priority = { "scorch", "fireball", "fire_blast" } },
    MAGE_FROST = { priority = { "frostbolt", "ice_lance", "fire_blast" } },
    
    -- Warlocks
    WARLOCK_AFFLICTION = { priority = { "unstable_affliction", "corruption", "siphon_life", "curse_of_agony", "shadow_bolt", "drain_soul" } },
    WARLOCK_DESTRUCTION = { priority = { "immolate", "conflagrate", "incinerate", "shadow_bolt" } },
    
    -- Hunters
    HUNTER_MM = { priority = { "aimed_shot", "arcane_shot", "steady_shot" } },
    HUNTER_BM = { priority = { "kill_command", "steady_shot", "arcane_shot" } },
    
    -- Warriors
    WARRIOR_FURY = { priority = { "bloodthirst", "whirlwind", "heroic_strike" } },
    WARRIOR_ARMS = { priority = { "mortal_strike", "slam", "overpower", "execute" } },
    WARRIOR_PROTECTION = { priority = { "shield_slam", "revenge", "devastate", "sunder_armor" } },
    
    -- Rogues
    ROGUE_ASSASSINATION = { priority = { "mutilate", "slice_and_dice", "rupture", "envenom" } },
    ROGUE_COMBAT = { priority = { "sinister_strike", "slice_and_dice", "rupture", "eviscerate" } },
    
    -- Druids
    DRUID_BALANCE = { priority = { "moonfire_dot", "insect_swarm", "starfire", "wrath" } },
    
    -- Healers (HPS focus)
    RESTO_SHAMAN = { priority = { "chain_heal", "lesser_healing_wave", "healing_wave" } },
    RESTO_DRUID = { priority = { "lifebloom", "rejuvenation", "regrowth" } },
    HOLY_PRIEST = { priority = { "circle_of_healing", "flash_heal", "greater_heal" } },
  }
  
  return rotations[spec_name]
end

-- Generate validation verdict
function simulator.generate_verdict(dps, oom_time, duration, spec_name)
  local issues = {}
  local warnings = {}
  
  -- Check OOM
  if oom_time < duration * 0.9 then
    table.insert(issues, "Mana sustain: OOM at " .. math.floor(oom_time) .. "s (fight is " .. duration .. "s)")
  end
  
  -- Check DPS viability
  local min_dps = {
    MAGE_ARCANE = 900, MAGE_FIRE = 1000, MAGE_FROST = 850,
    WARLOCK_AFFLICTION = 950, WARLOCK_DESTRUCTION = 1000,
    HUNTER_MM = 900, HUNTER_BM = 950,
    WARRIOR_FURY = 800, WARRIOR_ARMS = 750,
    ROGUE_ASSASSINATION = 900, ROGUE_COMBAT = 850,
    DRUID_BALANCE = 700,
  }
  
  local required = min_dps[spec_name]
  if required and dps < required then
    table.insert(warnings, "DPS below threshold: " .. math.floor(dps) .. " vs expected " .. required)
  end
  
  if #issues == 0 and #warnings == 0 then
    return "PASS"
  elseif #issues == 0 then
    return "PASS_WITH_WARNINGS"
  else
    return "FAIL"
  end
end

-- Export module
return simulator
