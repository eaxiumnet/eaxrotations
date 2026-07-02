-- resto_vanilla.lua — Druid Restoration healing rotation for Vanilla/Classic Era.
-- WHAT:  healing rotation (Rejuvenation, Regrowth, Healing Touch, Swiftmend).
-- WHEN:  combat or pre-hot, when NS.is_vanilla() is true.
-- WHY:   expansion-aware loader selects _vanilla suffix for Classic Era.
-- SAFETY: nil-guards on NS, SPELLS, Healing helpers, and TBC data fallback.

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.DruidSpells or {}
local potion_helper = require("shared/potion_helper_sylvanas")
local Healing = NS.DruidHealing or require("classes/druid/healing_sylvanas")
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { potions = {} } } end
local TBC_POTIONS = (TBC.ITEMS and TBC.ITEMS.potions) or {}

local PLAYER_UNIT = NS.PLAYER_UNIT
local STANCE_CASTER = 0
local STANCE_BEAR = 1
local STANCE_CAT = 3
local STANCE_TRAVEL = 4

local REJUVENATION_BUFF = { 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }
local REGROWTH_BUFF = { 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }
local NATURES_SWIFTNESS_BUFF = 17116
local NATURES_GRASP_BUFF = { 16813, 16812, 16811, 16810, 16689 }
local ABOLISH_POISON_BUFF = { 2893 }
local MOONFIRE_DEBUFF = { 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local INSECT_SWARM_DEBUFF = { 24977, 24976, 24975, 24974, 5570 }

local SWIFTMEND_EXPECTED_CD = 15
local NATURES_SWIFTNESS_EXPECTED_CD = 180
local INNERVATE_EXPECTED_CD = 360
local TRANQUILITY_EXPECTED_CD = 600
local BARKSKIN_EXPECTED_CD = 60
local REBIRTH_EXPECTED_CD = 1200
local REJUVENATION_REFRESH = 3.0
local REGROWTH_REFRESH = 4.0
local MANA_LOW_FOR_BLOOM = 22
local MANA_CONSERVE_PCT = 30
local MANA_EMERGENCY_PCT = 15
local MANA_CRITICAL_PCT = 5
local TANK_REJUV_HP = 92
local RAID_REJUV_HP = 88
local REGROWTH_SPOT_HP = 62
local HEALING_TOUCH_HP = 42
local DOWNRANK_HT_HP = 72
local CLEARCASTING_BUFF = 16870
local MOVING_HOT_HP = 90
local PVP_MELEE_RANGE = 8
local REPOSITION_RANGE = 28

local LOCAL_SPELLS = {
    Innervate = NS.spell_action({ 29166 }, "Innervate"),
    Rebirth = NS.spell_action({ 20484 }, "Rebirth"),
    HealingTouchRank4 = NS.spell_action({ 5189 }, "HealingTouchRank4"),
    Tranquility = NS.spell_action({ 9863, 9862, 740 }, "Tranquility"),
    TravelForm = NS.spell_action({ 783 }, "TravelForm"),
    EntanglingRoots = NS.spell_action({ 9853, 9852, 5196, 5195, 1062, 339 }, "EntanglingRoots"),
    NaturesGrasp = NS.spell_action({ 16813, 16812, 16811, 16810, 16689 }, "NaturesGrasp"),
}

local HEALER_CLASS_IDS = { [2] = true, [5] = true, [7] = true, [11] = true }

local SKIP_RANGE = { skip_range = true }
local BARKSKIN_OPTS = { skip_range = true, expected_cooldown = BARKSKIN_EXPECTED_CD }
local SWIFTMEND_OPTS = { expected_cooldown = SWIFTMEND_EXPECTED_CD }
local NS_OPTS = { skip_range = true, expected_cooldown = NATURES_SWIFTNESS_EXPECTED_CD }
local INNERVATE_OPTS = { expected_cooldown = INNERVATE_EXPECTED_CD }
local TRANQUILITY_OPTS = { skip_range = true, expected_cooldown = TRANQUILITY_EXPECTED_CD }

local resto_state = {
    entries = nil,
    count = 0,
    tank = nil,
    lowest = nil,
    lowest_tank = nil,
    lowest_healer = nil,
    lowest_dps = nil,
    swiftmend_target = nil,
    ns_target = nil,
    ht_target = nil,
    regrowth_target = nil,
    rejuv_target = nil,
    innervate_target = nil,
    cursed_target = nil,
    poison_target = nil,
    tranquility_count = 0,
    melee_pressure_count = 0,
    melee_target = nil,
    enemy_healer = nil,
    root_target = nil,
    has_natures_swiftness = false,
    in_caster = false,
    should_move_form = false,
    moonfire_remains = 0,
    insect_swarm_remains = 0,
}



local function has_hot_for_swiftmend(entry)
    if not entry or not entry.unit then return false end
    return entry.has_rejuvenation or entry.has_regrowth or NS.buff_up(entry.unit, REJUVENATION_BUFF) or NS.buff_up(entry.unit, REGROWTH_BUFF)
end

local function effective_hp(entry)
    return entry and (entry.effective_hp or entry.hp or 100) or 100
end

local function effective_deficit(entry)
    if not entry then return 0 end
    return entry.effective_deficit or entry.deficit or 0
end



local function unit_class_id(unit)
    if not unit or not NS.safe_field then return nil end
    local getter = NS.safe_field(unit, "get_class")
    if not getter then return nil end
    local ok, value = pcall(getter, unit)
    return ok and type(value) == "number" and value or nil
end

local function is_healer_entry(entry)
    local class_id = entry and unit_class_id(entry.unit) or nil
    return class_id and HEALER_CLASS_IDS[class_id] == true
end

local function choose_better(current, candidate)
    if not candidate then return current end
    if not current then return candidate end
    local cand_hp = effective_hp(candidate)
    local current_hp = effective_hp(current)
    if cand_hp < current_hp then return candidate end
    if cand_hp == current_hp and effective_deficit(candidate) > effective_deficit(current) then return candidate end
    return current
end

local function needs_rejuvenation(entry, threshold)
    if not entry or not entry.unit then return false end
    if effective_hp(entry) > threshold then return false end
    local remains = NS.buff_remains(entry.unit, REJUVENATION_BUFF) or 0
    return not entry.has_rejuvenation or remains <= REJUVENATION_REFRESH
end

local function needs_regrowth(entry)
    if not entry or not entry.unit then return false end
    if effective_hp(entry) > REGROWTH_SPOT_HP then return false end
    local remains = NS.buff_remains(entry.unit, REGROWTH_BUFF) or 0
    return not entry.has_regrowth or remains <= REGROWTH_REFRESH
end

local function scan_pvp_pressure(context, state)
    if not context or not context.me then return end
    state.melee_pressure_count = 0
    state.melee_target = nil
    state.enemy_healer = nil
    state.root_target = nil
    local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(40) or nil
    local enemy_count = type(enemies) == "table" and (enemies.n or #enemies) or 0
    for i = 1, enemy_count do
        local enemy = enemies[i]
        if enemy and NS.unit_alive(enemy) then
            local distance = NS.unit_distance and NS.unit_distance(enemy, context.me) or 999
            if distance <= PVP_MELEE_RANGE and NS.is_melee_target and NS.is_melee_target(enemy, context.me) then
                state.melee_pressure_count = state.melee_pressure_count + 1
                if not state.melee_target then state.melee_target = enemy end
                if not state.root_target then state.root_target = enemy end
            end
            if not state.enemy_healer and HEALER_CLASS_IDS[unit_class_id(enemy) or 0] and distance <= 30 then
                state.enemy_healer = enemy
            end
        end
    end
end

local function find_priority_innervate(entries, count, context)
    local healer_mana_floor = (context.settings and context.settings.resto_innervate_mana) or 30
    for i = 1, count do
        local entry = entries[i]
        local mana = entry and entry.unit and NS.mana_pct and NS.mana_pct(entry.unit) or 100
        local is_self = entry and entry.unit and NS.same_unit and NS.same_unit(entry.unit, context.me)
        if entry and entry.unit and is_healer_entry(entry) and not is_self and mana <= (healer_mana_floor + 5) then
            return entry.unit
        end
    end
    if (context.mana_pct or 100) <= ((context.settings and context.settings.resto_innervate_mana) or 30) then
        return context.me or NS.GetPlayer()
    end
    return nil
end

local function choose_swiftmend_prefer_rejuv(first, second)
    if not second then return first end
    if not first then return second end
    local first_hp = effective_hp(first)
    local second_hp = effective_hp(second)
    if math.abs(first_hp - second_hp) <= 8 then
        local first_rejuv_only = first.has_rejuvenation and not first.has_regrowth
        local second_rejuv_only = second.has_rejuvenation and not second.has_regrowth
        if first_rejuv_only and not second_rejuv_only then return first end
        if second_rejuv_only and not first_rejuv_only then return second end
    end
    return choose_better(first, second)
end

local function choose_swiftmend_target(entries, count, threshold)
    local tank_candidate, healer_candidate, dps_candidate = nil, nil, nil
    for i = 1, count do
        local entry = entries[i]
        if entry and effective_hp(entry) <= threshold and has_hot_for_swiftmend(entry) then
            if entry.is_tank then tank_candidate = choose_swiftmend_prefer_rejuv(tank_candidate, entry)
            elseif is_healer_entry(entry) then healer_candidate = choose_swiftmend_prefer_rejuv(healer_candidate, entry)
            else dps_candidate = choose_swiftmend_prefer_rejuv(dps_candidate, entry) end
        end
    end
    return tank_candidate or healer_candidate or dps_candidate
end

local function build_state(context)
    local entries, count = Healing.scan_healing_targets()
    local settings = context.settings or NS.settings or {}

    resto_state.entries = entries
    resto_state.count = count
    resto_state.tank = NS.healing_get_tank and NS.healing_get_tank(entries, count) or nil
    resto_state.lowest = NS.healing_get_lowest_hp and NS.healing_get_lowest_hp(entries, count, 100) or nil
    resto_state.lowest_tank = nil
    resto_state.lowest_healer = nil
    resto_state.lowest_dps = nil
    resto_state.swiftmend_target = nil
    resto_state.ns_target = nil
    resto_state.ht_target = nil
    resto_state.regrowth_target = nil
    resto_state.rejuv_target = nil
    resto_state.innervate_target = nil
    resto_state.cursed_target = nil
    resto_state.poison_target = nil
    resto_state.tranquility_count = 0
    resto_state.in_caster = not context.stance or context.stance == STANCE_CASTER
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(17116, 3.0) or false
    if not skip_aura then
        resto_state.has_natures_swiftness = NS.has_player_buff(NATURES_SWIFTNESS_BUFF)
        resto_state.has_clearcasting = NS.has_player_buff(CLEARCASTING_BUFF)
        resto_state.moonfire_remains = context.target and NS.debuff_remains(context.target, MOONFIRE_DEBUFF) or 0
        resto_state.insect_swarm_remains = context.target and NS.debuff_remains(context.target, INSECT_SWARM_DEBUFF) or 0
    end
    resto_state.mana_pct = context.mana_pct or context.player_mana_pct or 100
    local mana_conserve_pct = (settings.resto_mana_conserve_pct ~= nil and settings.resto_mana_conserve_pct) or MANA_CONSERVE_PCT
    local mana_emergency_pct = (settings.resto_mana_emergency_pct ~= nil and settings.resto_mana_emergency_pct) or MANA_EMERGENCY_PCT
    local mana_critical_pct = (settings.resto_mana_critical_pct ~= nil and settings.resto_mana_critical_pct) or MANA_CRITICAL_PCT
    resto_state.mana_conserve = resto_state.mana_pct <= mana_conserve_pct
    resto_state.mana_emergency = resto_state.mana_pct <= mana_emergency_pct
    resto_state.mana_critical = resto_state.mana_pct <= mana_critical_pct

    local swiftmend_hp = settings.resto_swiftmend_hp or 50
    local ns_hp = settings.resto_ns_hp or 30
    local tranquility_hp = settings.resto_tranquility_hp or 25
    local auto_dispel = settings.resto_auto_dispel ~= false

    for i = 1, count do
        local entry = entries[i]
        if entry and entry.unit then
            local hp = effective_hp(entry)
            if entry.is_tank then resto_state.lowest_tank = choose_better(resto_state.lowest_tank, entry)
            elseif is_healer_entry(entry) then resto_state.lowest_healer = choose_better(resto_state.lowest_healer, entry)
            else resto_state.lowest_dps = choose_better(resto_state.lowest_dps, entry) end
            if hp <= tranquility_hp then resto_state.tranquility_count = resto_state.tranquility_count + 1 end
            if hp <= ns_hp then resto_state.ns_target = choose_better(resto_state.ns_target, entry) end
            if hp <= HEALING_TOUCH_HP then resto_state.ht_target = choose_better(resto_state.ht_target, entry) end
            if needs_regrowth(entry) then resto_state.regrowth_target = choose_better(resto_state.regrowth_target, entry) end
            if needs_rejuvenation(entry, entry.is_tank and TANK_REJUV_HP or RAID_REJUV_HP) then resto_state.rejuv_target = choose_better(resto_state.rejuv_target, entry) end
            if auto_dispel and not resto_state.cursed_target and NS.has_dispel_type_debuff and NS.has_dispel_type_debuff(entry.unit, "Curse") then resto_state.cursed_target = entry end
            if auto_dispel and not resto_state.poison_target and NS.has_dispel_type_debuff and NS.has_dispel_type_debuff(entry.unit, "Poison") and not NS.buff_up(entry.unit, ABOLISH_POISON_BUFF) then resto_state.poison_target = entry end
        end
    end

    resto_state.swiftmend_target = choose_swiftmend_target(entries, count, swiftmend_hp)
    resto_state.innervate_target = find_priority_innervate(entries, count, context)
    if context.is_moving and (context.target_distance or 0) >= REPOSITION_RANGE then resto_state.should_move_form = true end
    scan_pvp_pressure(context, resto_state)
    return resto_state
end

local function solo_damage_enabled(context, state)
    if not context or not context.has_valid_enemy_target then return false end
    if not (context.is_solo == true or context.is_leveling == true or (context.settings and context.settings.resto_dps_when_idle == true)) then return false end
    if context.is_moving and not NS.spell_ready(SPELLS.Moonfire, context.target) then return false end
    if state and state.lowest and effective_hp(state.lowest) < ((context.settings and context.settings.resto_idle_hp) or 88) then return false end
    if (context.mana_pct or 100) < ((context.settings and context.settings.resto_dps_mana_floor) or 35) then return false end
    return true
end

local strategies = {
    { name = "BarkskinSelfPreservation", matches = function(context) local settings = context.settings or {}; local threshold = settings.barkskin_hp or 55; return (context.hp or 100) <= threshold and NS.spell_ready(SPELLS.Barkskin, PLAYER_UNIT, BARKSKIN_OPTS) end, execute = function() return NS.try_cast(SPELLS.Barkskin, PLAYER_UNIT, "[RESTO] Barkskin self", BARKSKIN_OPTS) end },
    { name = "BearFormFocusedByMelee", matches = function(context, state) return context.is_pvp and (context.hp or 100) <= 35 and state.melee_pressure_count > 0 and context.stance ~= STANCE_BEAR and NS.spell_ready(SPELLS.BearForm, PLAYER_UNIT, SKIP_RANGE) end, execute = function() return NS.try_cast(SPELLS.BearForm, PLAYER_UNIT, "[RESTO] Bear Form under melee focus", SKIP_RANGE) end },
    { name = "NaturesGraspMelee", matches = function(context, state) return context.is_pvp and state.melee_pressure_count > 0 and not NS.has_player_buff(NATURES_GRASP_BUFF) and NS.spell_ready(LOCAL_SPELLS.NaturesGrasp, PLAYER_UNIT, SKIP_RANGE) end, execute = function() return NS.try_cast(LOCAL_SPELLS.NaturesGrasp, PLAYER_UNIT, "[RESTO] Nature's Grasp melee peel", SKIP_RANGE) end },
    { name = "RemoveCurse", matches = function(_, state) return state.cursed_target and NS.spell_ready(SPELLS.RemoveCurse, state.cursed_target.unit) end, execute = function(_, state) return NS.try_cast(SPELLS.RemoveCurse, state.cursed_target.unit, "[RESTO] Remove Curse") end },
    { name = "AbolishPoison", matches = function(_, state) return state.poison_target and NS.spell_ready(SPELLS.AbolishPoison, state.poison_target.unit) end, execute = function(_, state) return NS.try_cast(SPELLS.AbolishPoison, state.poison_target.unit, "[RESTO] Abolish Poison") end },
    { name = "ManaPotionFloor", matches = function(_, s) return (s.mana_pct or 100) <= 18 end, execute = function(context) return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS) end },
    { name = "InnervateSelf", matches = function(context, state) return state.innervate_target and NS.same_unit(state.innervate_target, context.me) and NS.spell_ready(LOCAL_SPELLS.Innervate, state.innervate_target, INNERVATE_OPTS) end, execute = function(_, state) return NS.try_cast(LOCAL_SPELLS.Innervate, state.innervate_target, "[RESTO] Innervate self", INNERVATE_OPTS) end },
    { name = "InnervateHealer", matches = function(context, state) return state.innervate_target and not NS.same_unit(state.innervate_target, context.me) and NS.spell_ready(LOCAL_SPELLS.Innervate, state.innervate_target, INNERVATE_OPTS) end, execute = function(_, state) return NS.try_cast(LOCAL_SPELLS.Innervate, state.innervate_target, "[RESTO] Innervate healer", INNERVATE_OPTS) end },
    { name = "RebirthBattleRez", matches = function(context) return context.in_combat and (NS.is_in_party and NS.is_in_party() or NS.is_in_raid and NS.is_in_raid()) and NS.spell_ready(LOCAL_SPELLS.Rebirth, PLAYER_UNIT, { skip_range = true, expected_cooldown = REBIRTH_EXPECTED_CD }) end, execute = function() return NS.try_cast(LOCAL_SPELLS.Rebirth, PLAYER_UNIT, "[RESTO] Rebirth battle rez", { skip_range = true, expected_cooldown = REBIRTH_EXPECTED_CD }) end },
    { name = "SwiftmendEmergency", matches = function(_, state) return state.swiftmend_target and NS.spell_ready(SPELLS.Swiftmend, state.swiftmend_target.unit, SWIFTMEND_OPTS) end, execute = function(_, state) return NS.try_cast(SPELLS.Swiftmend, state.swiftmend_target.unit, "[RESTO] Swiftmend triage") end },
    { name = "NaturesSwiftness", matches = function(_, state) return state.ns_target and not state.has_natures_swiftness and (state.ns_target.time_to_die or 999) <= 3.5 and NS.spell_ready(SPELLS.NaturesSwiftness, PLAYER_UNIT, NS_OPTS) end, execute = function() return NS.try_cast(SPELLS.NaturesSwiftness, PLAYER_UNIT, "[RESTO] Nature's Swiftness", NS_OPTS) end },
    { name = "NaturesSwiftnessHealingTouch", matches = function(_, state) return state.ns_target and state.has_natures_swiftness and NS.spell_ready(SPELLS.HealingTouch, state.ns_target.unit) end, execute = function(_, state) return NS.try_cast(SPELLS.HealingTouch, state.ns_target.unit, "[RESTO] NS Healing Touch") end },
    { name = "TranquilityEmergency", matches = function(context, state) local needed = (context.settings and context.settings.resto_tranquility_count) or 3; if state.tranquility_count < needed then return false end; if NS.threat_status and NS.threat_status(context.me, context.target) >= 2 then return false end; return NS.spell_ready(LOCAL_SPELLS.Tranquility, PLAYER_UNIT, TRANQUILITY_OPTS) end, execute = function() return NS.try_cast(LOCAL_SPELLS.Tranquility, PLAYER_UNIT, "[RESTO] Tranquility emergency", TRANQUILITY_OPTS) end },
    { name = "HealingTouchMaxEmergency", matches = function(context, state) return not context.is_moving and state.ht_target and NS.spell_ready(SPELLS.HealingTouch, state.ht_target.unit) end, execute = function(_, state) return NS.try_cast(SPELLS.HealingTouch, state.ht_target.unit, "[RESTO] Healing Touch emergency") end },
    { name = "FriendlyTarget", matches = function(context, state)
        if not context.in_combat then return false end
        if context.is_moving then return false end
        if context.settings.resto_use_friendly_target == false then return false end
        local threshold = (context.settings and context.settings.resto_friendly_target_threshold) or 90
        local ft = NS.get_friendly_target_entry(context)
        if not ft or not ft.unit then return false end
        if (ft.hp_pct or 100) >= threshold then return false end
        if state.lowest and effective_hp(state.lowest) <= 35 then return false end
        return NS.spell_ready(SPELLS.Regrowth, ft.unit)
    end, execute = function(context, state)
        local ft = NS.get_friendly_target_entry(context)
        if not ft then return false end
        return NS.try_cast(SPELLS.Regrowth, ft.unit, string.format("[RESTO] Regrowth ft %.0f%%", ft.effective_hp or 0))
    end },
    { name = "RegrowthSpotHeal", matches = function(context, state) return not context.is_moving and state.regrowth_target and not state.mana_conserve and NS.spell_ready(SPELLS.Regrowth, state.regrowth_target.unit) end, execute = function(_, state) return NS.try_cast(SPELLS.Regrowth, state.regrowth_target.unit, "[RESTO] Regrowth spot heal") end },
    { name = "ClearcastRegrowth", matches = function(_, state) return state.has_clearcasting and state.regrowth_target and NS.spell_ready(SPELLS.Regrowth, state.regrowth_target.unit) end, execute = function(_, state) return NS.try_cast(SPELLS.Regrowth, state.regrowth_target.unit, "[RESTO] Clearcast Regrowth") end },
    { name = "MovingRejuvenation", matches = function(context, state) return context.is_moving and state.rejuv_target and not state.mana_emergency and NS.spell_ready(SPELLS.Rejuvenation, state.rejuv_target.unit) end, execute = function(_, state) return NS.try_cast(SPELLS.Rejuvenation, state.rejuv_target.unit, "[RESTO] Moving Rejuvenation") end },
    { name = "PriorityRejuvenation", matches = function(_, state) return state.rejuv_target and not state.mana_emergency and NS.spell_ready(SPELLS.Rejuvenation, state.rejuv_target.unit) end, execute = function(_, state) return NS.try_cast(SPELLS.Rejuvenation, state.rejuv_target.unit, "[RESTO] Priority Rejuvenation") end },
    { name = "DownrankHealingTouch", matches = function(context, state) return not context.is_moving and state.lowest and effective_hp(state.lowest) <= DOWNRANK_HT_HP and (context.mana_pct or 100) <= 45 and NS.spell_ready(LOCAL_SPELLS.HealingTouchRank4, state.lowest.unit) end, execute = function(_, state) return NS.try_cast(LOCAL_SPELLS.HealingTouchRank4, state.lowest.unit, "[RESTO] Downrank Healing Touch") end },
    { name = "EntanglingRootsMelee", matches = function(context, state) return context.is_pvp and state.root_target and not context.is_moving and NS.spell_ready(LOCAL_SPELLS.EntanglingRoots, state.root_target) end, execute = function(_, state) return NS.try_cast(LOCAL_SPELLS.EntanglingRoots, state.root_target, "[RESTO] Entangling Roots melee") end },
    { name = "SoloMoonfire", matches = function(context, state) return solo_damage_enabled(context, state) and not state.mana_emergency and state.moonfire_remains <= 3 and NS.spell_ready(SPELLS.Moonfire, context.target) end, execute = function(context) return NS.try_cast(SPELLS.Moonfire, context.target, "[RESTO] Solo Moonfire") end },
    { name = "SoloInsectSwarm", matches = function(context, state) return solo_damage_enabled(context, state) and not context.is_moving and not state.mana_emergency and state.insect_swarm_remains <= 3 and NS.spell_ready(SPELLS.InsectSwarm, context.target) end, execute = function(context) return NS.try_cast(SPELLS.InsectSwarm, context.target, "[RESTO] Solo Insect Swarm") end },
    { name = "SoloWrath", matches = function(context, state) return solo_damage_enabled(context, state) and not context.is_moving and not state.mana_emergency and NS.spell_ready(SPELLS.Wrath, context.target) end, execute = function(context) return NS.try_cast(SPELLS.Wrath, context.target, "[RESTO] Solo Wrath") end },
    { name = "TravelFormReposition", matches = function(context, state) return state.should_move_form and context.stance ~= STANCE_TRAVEL and context.stance ~= STANCE_CAT and NS.spell_ready(LOCAL_SPELLS.TravelForm, PLAYER_UNIT, SKIP_RANGE) end, execute = function() return NS.try_cast(LOCAL_SPELLS.TravelForm, PLAYER_UNIT, "[RESTO] Travel Form reposition", SKIP_RANGE) end },
    { name = "CatFormRepositionFallback", matches = function(context, state) return state.should_move_form and context.stance ~= STANCE_CAT and NS.spell_ready(SPELLS.CatForm, PLAYER_UNIT, SKIP_RANGE) end, execute = function() return NS.try_cast(SPELLS.CatForm, PLAYER_UNIT, "[RESTO] Cat Form reposition", SKIP_RANGE) end },
    { name = "FallbackHealingTouch", matches = function(context, state) return not context.is_moving and state.lowest and effective_hp(state.lowest) <= 80 and NS.spell_ready(SPELLS.HealingTouch, state.lowest.unit) end, execute = function(_, state) return NS.try_cast(SPELLS.HealingTouch, state.lowest.unit, "[RESTO] Healing Touch fallback") end },
}

local module = { strategies = strategies, build_state = build_state }
NS.rotation_registry:register("resto", strategies, { get_state = build_state })
-- Druid resto_vanilla rotation registered (Classic Vanilla)
return module
