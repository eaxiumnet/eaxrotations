-- leveling_vanilla.lua — Druid Leveling rotation for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  adaptive leveling rotation (wrath, moonfire, healing, bear form).
-- WHEN:  any combat while leveling, when NS.is_vanilla() is true.
-- WHY:   handles sub-60 talent tree and mixed solo/group content.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

local NS = _G.EaxRotations
if not NS then return nil end

local leveling = require("shared/leveling_sylvanas")
if not leveling then return nil end

local druid_leveling = {}
local is_leveling_context = leveling.create_context_guard()

local SPELLS = NS.DruidSpells or {}
local MARK_OF_THE_WILD_BUFF = { 9885, 9884, 8907, 6756, 5234, 5232, 1126 }
local THORNS_BUFF = { 9910, 9756, 8914, 1075, 782, 467 }
local RAKE_DEBUFF = { 9904, 1824, 1823, 1822 }
local RIP_DEBUFF = { 1079 }
local FAERIE_FIRE_FERAL = { 16857, 9907, 9749, 778, 770 }
local PROWL_BUFF = { 9913, 6783, 5215 }

local ENERGY_CAP = 100
local RAGE_LOW = 15
local RIP_CP_MIN = 4
local BITE_CP_MIN = 4
local MELEE_RANGE = 5
local MIN_RIP_TTD = 6
local MIN_RAKE_TTD = 6

local function spell_ready(spell_action)
    if not spell_action then return false end
    return NS.spell_ready and NS.spell_ready(spell_action) or false
end

local function try_cast(spell_action, target, label)
    if not spell_action then return false end
    local ok, result = pcall(NS.try_cast, spell_action, target, label or "")
    return ok and result == true
end

local function has_buff(buff_ids)
    if not buff_ids then return false end
    local me = (NS.GetPlayer and NS.GetPlayer()) or (NS.get_local_player and NS.get_local_player()) or nil
    if not me then return false end
    local ids = type(buff_ids) == "table" and buff_ids or { buff_ids }
    if NS.buff_up then return NS.buff_up(me, ids) end
    return false
end

function druid_leveling.build_state(context)
    if not context then return nil end
    local state = {}
    leveling.build_common_state(context, state)

    state.mark_of_the_wild_ready = spell_ready(SPELLS.MarkOfTheWild)
    state.thorns_ready = spell_ready(SPELLS.Thorns)
    state.moonfire_ready = spell_ready(SPELLS.Moonfire)
    state.wrath_ready = spell_ready(SPELLS.Wrath)
    state.starfire_ready = spell_ready(SPELLS.Starfire)
    state.insect_swarm_ready = spell_ready(SPELLS.InsectSwarm)
    state.hurricane_ready = spell_ready(SPELLS.Hurricane)
    state.rejuvenation_ready = spell_ready(SPELLS.Rejuvenation)
    state.healing_touch_ready = spell_ready(SPELLS.HealingTouch)
    state.barkskin_ready = spell_ready(SPELLS.Barkskin)
    state.entangling_roots_ready = spell_ready(SPELLS.EntanglingRoots)
    state.natures_grasp_ready = spell_ready(SPELLS.NaturesGrasp)
    state.faerie_fire_ready = spell_ready(SPELLS.FaerieFire)

    state.is_bear = NS.has_form and NS.has_form("bear") or false
    state.is_cat = NS.has_form and NS.has_form("cat") or false
    state.in_caster = not state.is_bear and not state.is_cat

    state.energy = context.energy or 0
    state.combo_points = context.combo_points or context.cp or 0
    state.rage = context.rage or 0
    state.is_behind = NS.is_behind_target and NS.is_behind_target(context.target) or false
    state.is_stealthed = context.is_stealthed == true or has_buff(PROWL_BUFF)

    state.cat_form_ready = spell_ready(SPELLS.CatForm)
    state.bear_form_ready = spell_ready(SPELLS.BearForm)
    state.prowl_ready = spell_ready(SPELLS.Prowl)
    state.pounce_ready = spell_ready(SPELLS.Pounce)
    state.ravage_ready = spell_ready(SPELLS.Ravage)
    state.rake_ready = spell_ready(SPELLS.Rake)
    state.shred_ready = spell_ready(SPELLS.Shred)
    state.rip_ready = spell_ready(SPELLS.Rip)
    state.bite_ready = spell_ready(SPELLS.FerociousBite)
    state.claw_ready = spell_ready(SPELLS.Claw)
    state.swipe_ready = spell_ready(SPELLS.SwipeBear)
    state.maul_ready = spell_ready(SPELLS.Maul)
    state.frenzied_regen_ready = spell_ready(SPELLS.FrenziedRegeneration)
    state.faerie_fire_feral_ready = spell_ready(SPELLS.FaerieFireFeral)

    if context.target then
        state.rake_remains = (NS.debuff_remains and NS.debuff_remains(context.target, RAKE_DEBUFF)) or 0
        state.rip_remains = (NS.debuff_remains and NS.debuff_remains(context.target, RIP_DEBUFF)) or 0
        state.faerie_fire_feral_remains = (NS.debuff_remains and NS.debuff_remains(context.target, FAERIE_FIRE_FERAL)) or 0
    else
        state.rake_remains = 0
        state.rip_remains = 0
        state.faerie_fire_feral_remains = 0
    end

    state.target_ttd = context.ttd or context.target_ttd or 999
    state.target_ttd_known = (context.ttd ~= nil) or (context.target_ttd ~= nil)
    state.target_hp = context.target_hp or 100
    state.in_melee = context.in_melee_range == true or (state.target_range or 40) <= MELEE_RANGE
    state.target_range = context.target_distance or 40

    state.has_mark_of_wild = has_buff(MARK_OF_THE_WILD_BUFF)
    state.has_thorns = has_buff(THORNS_BUFF)

    local settings = context.settings or {}
    state.heal_hp = settings.leveling_heal_hp or 40
    state.bear_hp = settings.leveling_bear_hp or 40
    state.use_feral = settings.leveling_use_feral ~= false
    state.wand_threshold = settings.leveling_wand_threshold or 30

    return state
end

-- ============================================================================
-- Feral match functions
-- ============================================================================

local bear_form_survival_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.use_feral then return false end
    if not state.bear_form_ready then return false end
    if state.is_bear then return false end
    if (state.hp or 100) > state.bear_hp then return false end
    return true
end

local frenzied_regen_matches = function(context, state)
    if not state then return false end
    if not state.is_bear then return false end
    if not state.in_combat then return false end
    if not state.frenzied_regen_ready then return false end
    if (state.rage or 0) < RAGE_LOW then return false end
    if (state.hp or 100) > (state.bear_hp - 5) then return false end
    return true
end

local cat_form_entry_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.use_feral then return false end
    if not state.cat_form_ready then return false end
    if state.is_cat then return false end
    if state.is_bear and (state.hp or 100) <= state.bear_hp then return false end
    if not state.target then return false end
    if not state.in_melee then return false end
    return true
end

local prowl_opener_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if not state.use_feral then return false end
    if not state.prowl_ready then return false end
    if not state.is_cat and not state.cat_form_ready then return false end
    if state.is_stealthed then return false end
    if not state.target then return false end
    if state.target_range > 18 then return false end
    return true
end

local pounce_matches = function(context, state)
    if not state then return false end
    if not state.is_stealthed then return false end
    if not state.is_cat then return false end
    if not state.pounce_ready then return false end
    if (state.energy or 0) < 50 then return false end
    return true
end

local ravage_matches = function(context, state)
    if not state then return false end
    if not state.is_stealthed then return false end
    if not state.is_cat then return false end
    if not state.ravage_ready then return false end
    if (state.energy or 0) < 60 then return false end
    if not state.is_behind then return false end
    return true
end

local faerie_fire_feral_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if not state.is_cat and not state.is_bear then return false end
    if not state.faerie_fire_feral_ready then return false end
    if state.faerie_fire_feral_remains > 10 then return false end
    return true
end

local rake_matches = function(context, state)
    if not state then return false end
    if not state.is_cat then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if not state.rake_ready then return false end
    if (state.energy or 0) < 35 then return false end
    if (state.combo_points or 0) >= 5 then return false end
    if state.target_ttd > 0 and state.target_ttd < MIN_RAKE_TTD then return false end
    if state.rake_remains > 3 then return false end
    return true
end

local shred_matches = function(context, state)
    if not state then return false end
    if not state.is_cat then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if not state.shred_ready then return false end
    if (state.energy or 0) < 42 then return false end
    if (state.combo_points or 0) >= 5 then return false end
    if not state.is_behind then return false end
    return true
end

local rip_matches = function(context, state)
    if not state then return false end
    if not state.is_cat then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if not state.rip_ready then return false end
    if (state.energy or 0) < 30 then return false end
    if (state.combo_points or 0) < RIP_CP_MIN then return false end
    if state.target_ttd > 0 and state.target_ttd < MIN_RIP_TTD then return false end
    if state.rip_remains > 2 then return false end
    return true
end

local bite_matches = function(context, state)
    if not state then return false end
    if not state.is_cat then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if not state.bite_ready then return false end
    if (state.energy or 0) < 35 then return false end
    if (state.combo_points or 0) < BITE_CP_MIN then return false end
    if state.combo_points >= RIP_CP_MIN and state.rip_ready and state.rip_remains <= 0 and state.target_ttd_known and state.target_ttd > MIN_RIP_TTD then return false end
    return true
end

local claw_matches = function(context, state)
    if not state then return false end
    if not state.is_cat then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if not state.claw_ready then return false end
    if (state.combo_points or 0) >= 5 then return false end
    if (state.energy or 0) < 45 then return false end
    if state.shred_ready and state.is_behind and (state.energy or 0) >= 42 then return false end
    if state.rake_ready and state.rake_remains <= 3 and (state.energy or 0) >= 35 then return false end
    return true
end

local swipe_bear_matches = function(context, state)
    if not state then return false end
    if not state.is_bear then return false end
    if not state.in_combat then return false end
    if not state.swipe_ready then return false end
    if (state.rage or 0) < 20 then return false end
    if (state.enemies or 0) < 2 then return false end
    return true
end

local maul_matches = function(context, state)
    if not state then return false end
    if not state.is_bear then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if not state.maul_ready then return false end
    if (state.rage or 0) < 40 then return false end
    return true
end

-- ============================================================================
-- Caster match functions
-- ============================================================================

local motw_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if state.has_mark_of_wild then return false end
    if not state.mark_of_the_wild_ready then return false end
    return true
end

local thorns_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if state.has_thorns then return false end
    if not state.thorns_ready then return false end
    return true
end

local natures_grasp_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.natures_grasp_ready then return false end
    if (state.hp or 100) > 50 and (state.enemies or 0) < 2 then return false end
    return true
end

local barkskin_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.barkskin_ready then return false end
    if (state.hp or 100) > 50 then return false end
    return true
end

local healing_touch_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.healing_touch_ready then return false end
    if (state.hp or 100) > (state.heal_hp - 10) then return false end
    return true
end

local rejuvenation_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.rejuvenation_ready then return false end
    if (state.hp or 100) > state.heal_hp then return false end
    return true
end

local entangling_roots_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.entangling_roots_ready then return false end
    if not state.target then return false end
    if (state.enemies or 0) < 3 and (state.hp or 100) > 30 then return false end
    return true
end

local moonfire_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if state.is_bear or state.is_cat then return false end
    if not state.moonfire_ready then return false end
    if not state.target then return false end
    local ok, remains = pcall(function() return NS.debuff_remains and NS.debuff_remains(state.target, SPELLS.Moonfire) or 0 end)
    if ok and remains and remains > 4 then return false end
    return true
end

local insect_swarm_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if state.is_bear or state.is_cat then return false end
    if not state.insect_swarm_ready then return false end
    if not state.target then return false end
    local ok, remains = pcall(function() return NS.debuff_remains and NS.debuff_remains(state.target, SPELLS.InsectSwarm) or 0 end)
    if ok and remains and remains > 4 then return false end
    return true
end

local faerie_fire_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.faerie_fire_ready then return false end
    if not state.target then return false end
    local ok, remains = pcall(function() return NS.debuff_remains and NS.debuff_remains(state.target, SPELLS.FaerieFire) or 0 end)
    if ok and remains and remains > 10 then return false end
    return true
end

local hurricane_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.hurricane_ready then return false end
    if not state.target then return false end
    if (state.enemies or 0) < 3 then return false end
    if state.is_moving then return false end
    return true
end

local starfire_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if state.is_bear or state.is_cat then return false end
    if not state.starfire_ready then return false end
    if not state.target then return false end
    if state.is_moving then return false end
    return true
end

local wrath_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if state.is_bear or state.is_cat then return false end
    if not state.wrath_ready then return false end
    if not state.target then return false end
    return true
end

-- ============================================================================
-- Strategies table
-- ============================================================================

local strategies = {
    { name = "BearFormSurvival", matches = bear_form_survival_matches,
      execute = function(context) return try_cast(SPELLS.BearForm, nil, "[LEVELING] Bear Form (survival)") end },
    { name = "FrenziedRegeneration", matches = frenzied_regen_matches,
      execute = function(context) return try_cast(SPELLS.FrenziedRegeneration, nil, "[LEVELING] Frenzied Regen") end },
    { name = "CatFormEntry", matches = cat_form_entry_matches,
      execute = function(context) return try_cast(SPELLS.CatForm, nil, "[LEVELING] Cat Form") end },
    { name = "ProwlOpener", matches = prowl_opener_matches,
      execute = function(context)
          local st = context._leveling_state or druid_leveling.build_state(context)
          if st and not st.is_cat then
              return try_cast(SPELLS.CatForm, nil, "[LEVELING] Cat Form → Prowl")
          end
          return try_cast(SPELLS.Prowl, nil, "[LEVELING] Prowl")
      end },
    { name = "Pounce", matches = pounce_matches,
      execute = function(context) return try_cast(SPELLS.Pounce, context.target, "[LEVELING] Pounce") end },
    { name = "Ravage", matches = ravage_matches,
      execute = function(context) return try_cast(SPELLS.Ravage, context.target, "[LEVELING] Ravage") end },
    { name = "FaerieFireFeral", matches = faerie_fire_feral_matches,
      execute = function(context) return try_cast(SPELLS.FaerieFireFeral, context.target, "[LEVELING] Faerie Fire (Feral)") end },
    { name = "Rake", matches = rake_matches,
      execute = function(context) return try_cast(SPELLS.Rake, context.target, "[LEVELING] Rake") end },
    { name = "Shred", matches = shred_matches,
      execute = function(context) return try_cast(SPELLS.Shred, context.target, "[LEVELING] Shred") end },
    { name = "Rip", matches = rip_matches,
      execute = function(context) return try_cast(SPELLS.Rip, context.target, "[LEVELING] Rip") end },
    { name = "FerociousBite", matches = bite_matches,
      execute = function(context) return try_cast(SPELLS.FerociousBite, context.target, "[LEVELING] Bite") end },
    { name = "Claw", matches = claw_matches,
      execute = function(context) return try_cast(SPELLS.Claw, context.target, "[LEVELING] Claw") end },
    { name = "SwipeBear", matches = swipe_bear_matches,
      execute = function(context) return try_cast(SPELLS.SwipeBear, nil, "[LEVELING] Swipe") end },
    { name = "Maul", matches = maul_matches,
      execute = function(context) return try_cast(SPELLS.Maul, context.target, "[LEVELING] Maul") end },
    { name = "MarkOfTheWild", matches = motw_matches,
      execute = function(context) return try_cast(SPELLS.MarkOfTheWild, nil, "[LEVELING] Mark of the Wild") end },
    { name = "Thorns", matches = thorns_matches,
      execute = function(context) return try_cast(SPELLS.Thorns, nil, "[LEVELING] Thorns") end },
    { name = "NaturesGrasp", matches = natures_grasp_matches,
      execute = function(context) return try_cast(SPELLS.NaturesGrasp, nil, "[LEVELING] Nature's Grasp") end },
    { name = "Barkskin", matches = barkskin_matches,
      execute = function(context) return try_cast(SPELLS.Barkskin, nil, "[LEVELING] Barkskin") end },
    { name = "HealingTouch", matches = healing_touch_matches,
      execute = function(context) return try_cast(SPELLS.HealingTouch, nil, "[LEVELING] Healing Touch") end },
    { name = "Rejuvenation", matches = rejuvenation_matches,
      execute = function(context) return try_cast(SPELLS.Rejuvenation, nil, "[LEVELING] Rejuvenation") end },
    { name = "EntanglingRoots", matches = entangling_roots_matches,
      execute = function(context) return try_cast(SPELLS.EntanglingRoots, context.target, "[LEVELING] Entangling Roots") end },
    { name = "Moonfire", matches = moonfire_matches,
      execute = function(context) return try_cast(SPELLS.Moonfire, context.target, "[LEVELING] Moonfire") end },
    { name = "InsectSwarm", matches = insect_swarm_matches,
      execute = function(context) return try_cast(SPELLS.InsectSwarm, context.target, "[LEVELING] Insect Swarm") end },
    { name = "FaerieFire", matches = faerie_fire_matches,
      execute = function(context) return try_cast(SPELLS.FaerieFire, context.target, "[LEVELING] Faerie Fire") end },
    { name = "Hurricane", matches = hurricane_matches,
      execute = function(context) return try_cast(SPELLS.Hurricane, context.target, "[LEVELING] Hurricane") end },
    { name = "Starfire", matches = starfire_matches,
      execute = function(context) return try_cast(SPELLS.Starfire, context.target, "[LEVELING] Starfire") end },
    { name = "Wrath", matches = wrath_matches,
      execute = function(context) return try_cast(SPELLS.Wrath, context.target, "[LEVELING] Wrath") end },
    { name = "Wand",
      matches = leveling.create_wand_matches("leveling_wand_threshold", 30),
      execute = function(context) return leveling.execute_wand(context) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = druid_leveling.build_state })
end

function druid_leveling.on_update(context)
    if not context then return false end
    if not is_leveling_context(context) then return false end
    local state = druid_leveling.build_state(context)
    if not state then return false end
    context._leveling_state = state
    for i = 1, #strategies do
        local strategy = strategies[i]
        local ok, should_execute = pcall(strategy.matches, context, state)
        if ok and should_execute then
            local ok2, result = pcall(strategy.execute, context)
            if ok2 and result then return true end
        end
    end
    return false
end

-- [Druid] Leveling rotation loaded (Classic)
return druid_leveling
