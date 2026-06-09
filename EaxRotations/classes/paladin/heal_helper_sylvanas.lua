local _G = _G
local NS = _G.EaxRotations
if not NS then
    if type(core) == "table" and type(core.log_error) == "function" then
        core.log_error("[EaxRotations ERROR] Core module not loaded!")
    else
        print("[EaxRotations ERROR] Core module not loaded!")
    end
    return
end

local _ok_enums, enums = pcall(require, "common/enums")
if not _ok_enums or type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
local load_player = NS.GetPlayer()
local ok_cls, cls_id = pcall(function() return load_player and load_player:get_class() end)
if not ok_cls or cls_id ~= enums.class_id.PALADIN then return end

-- PARTY_UNITS/RAID_UNITS removed: unused (healing uses build_healing_entries/NS.healing_* for target scanning)

-- Dispel type detection: uses NS.has_dispel_type_debuff() which scans
-- the unit's debuff cache for aura.dispel_type/aura.buff_type fields.
-- This is the correct API approach — whitelists can never be complete.
-- Paladin dispels: Poison (Purify), Disease (Purify), Magic (Cleanse)
local has_dispel_type_debuff = NS.has_dispel_type_debuff or function() return false end

local healing_targets = {}
local healing_targets_count = 0
local scan_frame = 0
local math_floor = math.floor

NS.PaladinHealing = {}

local predict_effective_deficit = NS.import_helpers("predict_effective_deficit")

NS.PaladinHealing.predict_effective_deficit = predict_effective_deficit

local is_in_raid = NS.is_in_raid or function() return false end
local is_in_party = NS.is_in_party or function() return false end

local has_healing_reduction_debuff = NS.has_healing_reduction_debuff or function() return false end

local build_healing_entries = NS.build_healing_entries or function() return false end
local healing_get_tank = NS.healing_get_tank or function() return nil end
local healing_get_lowest_hp = NS.healing_get_lowest_hp or function() return nil end
local healing_all_above_hp = NS.healing_all_above_hp or function() return false end
local healing_get_cleanse_target = NS.healing_get_cleanse_target or function() return nil end

local function scan_healing_targets()
    local current_frame = math_floor(NS.game_time_ms() / (1000 / 60))
    if current_frame > 0 and current_frame == scan_frame then
        return healing_targets, healing_targets_count
    end
    scan_frame = current_frame

    healing_targets_count = build_healing_entries(healing_targets, function(entry, unit)
        -- Dispel tracking (Poison + Disease + Magic for Paladin)
        entry.has_poison = false
        entry.has_disease = false
        entry.has_magic = false

        entry.has_poison  = has_dispel_type_debuff(unit, "Poison")
        entry.has_disease = has_dispel_type_debuff(unit, "Disease")
        entry.has_magic   = has_dispel_type_debuff(unit, "Magic")

        entry.needs_cleanse = entry.has_poison or entry.has_disease or entry.has_magic

        entry.deficit = entry.max_hp - entry.current_hp
        -- incoming_dps is now populated by core_sylvanas.lua build_healing_entries via EMA tracker
        entry.has_healing_reduction = has_healing_reduction_debuff(unit)
    end)

    return healing_targets, healing_targets_count
end

NS.PaladinHealing.scan_healing_targets = scan_healing_targets

local function get_tank_target()
    scan_healing_targets()
    return healing_get_tank(healing_targets, healing_targets_count)
end

NS.PaladinHealing.get_tank_target = get_tank_target

local function get_lowest_hp_target(threshold)
    threshold = threshold or 100
    scan_healing_targets()
    return healing_get_lowest_hp(healing_targets, healing_targets_count, threshold)
end

NS.PaladinHealing.get_lowest_hp_target = get_lowest_hp_target

local function all_members_above_hp(threshold)
    scan_healing_targets()
    return healing_all_above_hp(healing_targets, healing_targets_count, threshold)
end

NS.PaladinHealing.all_members_above_hp = all_members_above_hp

local function get_cleanse_target()
    scan_healing_targets()
    return healing_get_cleanse_target(healing_targets, healing_targets_count)
end

NS.PaladinHealing.get_cleanse_target = get_cleanse_target
NS.PaladinHealing.is_in_raid = is_in_raid
NS.PaladinHealing.is_in_party = is_in_party

local HOLY_LIGHT_RANKS = NS.HOLY_LIGHT_RANKS
local FLASH_OF_LIGHT_RANKS = NS.FLASH_OF_LIGHT_RANKS
local HL_COEFFICIENT = NS.HL_COEFFICIENT
local FOL_COEFFICIENT = NS.FOL_COEFFICIENT
local HEALING_LIGHT_MULT = NS.HEALING_LIGHT_MULT

-- Illumination talent: 60% mana return on crit heals.
-- Effective cost = raw_cost * (1 - crit_chance * 0.60)
local ILLUMINATION_RETURN = 0.60

local function get_effective_cost(raw_cost, has_illumination, context)
    if not has_illumination or raw_cost <= 0 then return raw_cost end
    local crit_chance = 0.08  -- default: ~3% base + 5% Holy Power
    if context and context.crit_chance and context.crit_chance > 0 then
        crit_chance = context.crit_chance / 100
    elseif context and context.settings and context.settings.holy_crit_pct and context.settings.holy_crit_pct > 0 then
        crit_chance = context.settings.holy_crit_pct / 100
    end
    local effective = raw_cost * (1 - crit_chance * ILLUMINATION_RETURN)
    return math.max(effective, raw_cost * 0.40)  -- floor at 40% (worst case: 100% crit still returns 40% cost)
end

local function get_spell_id(spell_action)
    if not spell_action then return nil end
    if spell_action.id then return spell_action:id() end
    return spell_action._meta and spell_action._meta.id or nil
end

local function get_spell_mana_cost(spell_action)
    if not spell_action or not spell_action.GetSpellPowerCost then return 0 end
    local cost, power_type = spell_action:GetSpellPowerCost()
    return (cost and cost > 0 and power_type == 0) and cost or 0
end

local function is_rank_castable(spell_action)
    local spell_id = get_spell_id(spell_action)
    if not spell_id then return false end
    if not NS.is_spell_learned(spell_id) then return false end
    local cost = get_spell_mana_cost(spell_action)
    local player = NS.PLAYER_UNIT
    if cost > 0 and player then
        -- Prefer IZI's mana_current extension when present, otherwise use
        -- game_object:get_power(0), the documented Sylvanas mana resource call.
        local current_mana = 0
        if player.mana_current then
            current_mana = player:mana_current() or 0
        elseif player.get_power then
            current_mana = player:get_power(0) or 0  -- power_type 0 = Mana
        end
        if current_mana < cost then return false end
    end
    return true
end

local function expected_heal(rank_entry, bonus_healing, coefficient)
    if not rank_entry or not rank_entry.base_min or not rank_entry.base_max then return 0 end
    local base_avg = (rank_entry.base_min + rank_entry.base_max) / 2
    return (base_avg + bonus_healing * coefficient) * HEALING_LIGHT_MULT
end

local function select_rank(rank_table, deficit, bonus_healing, coefficient, skip_overheal_opt, has_illumination, context)
    local best_eff_entry = nil
    local best_eff = 0
    for i = 1, #rank_table do
        local entry = rank_table[i]
        if entry and entry.spell and is_rank_castable(entry.spell) then
            if skip_overheal_opt then
                return entry
            end
            local heal = expected_heal(entry, bonus_healing, coefficient)
            if heal <= deficit * 1.3 then
                return entry
            end
            local cost = get_spell_mana_cost(entry.spell)
            if cost > 0 then
                local effective_cost = get_effective_cost(cost, has_illumination, context)
                local eff = heal / effective_cost
                if eff > best_eff then
                    best_eff = eff
                    best_eff_entry = entry
                end
            elseif not best_eff_entry then
                best_eff_entry = entry
            end
        end
    end
    return best_eff_entry
end

local heal_result = { spell = nil, label = "", spell_type = "" }

local function select_heal(context, state, target)
    if not context or not target then return nil end

    if context.is_moving then return nil end
    -- Mounted bail: healer should not queue heals while mounted
    if NS.GetPlayer and NS.GetPlayer() then
        local me = NS.GetPlayer()
        if me.is_mounted and me:is_mounted() then return nil end
    end

    local bonus_healing = 0
    local deficit = target.effective_deficit or target.deficit or 0

    local use_hl = false

    if target.has_healing_reduction then
        use_hl = true
    elseif state.divine_favor_active then
        use_hl = true
    elseif target.incoming_dps and target.incoming_dps > 0 then
        local max_fol = expected_heal(FLASH_OF_LIGHT_RANKS[1], bonus_healing, FOL_COEFFICIENT)
        local fol_hps = max_fol / 1.5
        if target.incoming_dps > fol_hps then
            use_hl = true
        end
    end

    if not use_hl and deficit > 0 then
        local max_fol = expected_heal(FLASH_OF_LIGHT_RANKS[1], bonus_healing, FOL_COEFFICIENT)
        if deficit > max_fol * 1.3 then
            use_hl = true
        end
    end

    if deficit == 0 then return nil end

    local skip_overheal = target.has_healing_reduction
    local has_illum = state.has_illumination or false
    if use_hl then
        local hl_rank = select_rank(HOLY_LIGHT_RANKS, deficit, bonus_healing, HL_COEFFICIENT, skip_overheal, has_illum, context)
        if not hl_rank then return nil end
        if not target.has_healing_reduction and not state.divine_favor_active then
            local fol_rank = select_rank(FLASH_OF_LIGHT_RANKS, deficit, bonus_healing, FOL_COEFFICIENT, false, has_illum, context)
            if fol_rank then
                local hl_cost = 0
                local fol_cost = 0
                hl_cost = get_spell_mana_cost(hl_rank.spell)
                fol_cost = get_spell_mana_cost(fol_rank.spell)
                local hl_eff_cost = get_effective_cost(hl_cost, has_illum, context)
                local fol_eff_cost = get_effective_cost(fol_cost, has_illum, context)
                local hl_heal = expected_heal(hl_rank, bonus_healing, HL_COEFFICIENT)
                local fol_heal = expected_heal(fol_rank, bonus_healing, FOL_COEFFICIENT)
                local hl_eff = hl_eff_cost > 0 and (hl_heal / 2.5) / hl_eff_cost or 0
                local fol_eff = fol_eff_cost > 0 and (fol_heal / 1.5) / fol_eff_cost or 0
                if fol_eff > hl_eff then
                    heal_result.spell = fol_rank.spell
                    heal_result.label = "FoL " .. fol_rank.label
                    heal_result.spell_type = "FoL"
                    return heal_result
                end
            end
        end
        heal_result.spell = hl_rank.spell
        heal_result.label = "HL " .. hl_rank.label
        heal_result.spell_type = "HL"
    else
        local rank = select_rank(FLASH_OF_LIGHT_RANKS, deficit, bonus_healing, FOL_COEFFICIENT, skip_overheal, has_illum, context)
        if not rank then return nil end
        heal_result.spell = rank.spell
        heal_result.label = "FoL " .. rank.label
        heal_result.spell_type = "FoL"
    end

    return heal_result
end

NS.PaladinHealing.select_heal = select_heal

NS.log("Healing module loaded")
return NS.PaladinHealing
