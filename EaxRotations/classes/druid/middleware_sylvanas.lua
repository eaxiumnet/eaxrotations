-- Druid shared middleware.


local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local CCBreakDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local CCGateDB = CCBreakDB
local SPELLS = NS.DruidSpells or {}
local _is_spell_learned = core.spell_book and core.spell_book.is_spell_learned or nil
local _get_party_frames = core.object_manager and core.object_manager.get_party_frames or nil

-- ============================================================================
-- FORM-AWARE CONSUMABLES
-- Use pots/runes in Cat/Bear forms — auto-reshift back to form after use.
-- ============================================================================
local STANCE_CAT = 3
local STANCE_BEAR = 1
local STANCE_CASTER = 0

-- Form IDs for native form-restriction checks
local FORM_ID_HUMANOID = 0
local FORM_ID_BEAR = 1
local FORM_ID_CAT = 2

-- Form buff IDs for form detection (used by can_cast_in_form checks)
local FORM_BUFF_BEAR = { 9634, 5487 }
local FORM_BUFF_CAT = { 768 }
local FORM_BUFF_MOONKIN = { 24858 }
local FORM_BUFF_TREE = { 33891 }

-- Stances where consumable use is allowed
local ITEM_ALLOWED_STANCE = {
    [STANCE_CASTER] = true,
    [STANCE_CAT] = true,
}
-- Blocked: Bear(1), Aquatic(2), Travel(4), Flight(5)
local function can_use_items(stance)
    if ITEM_ALLOWED_STANCE[stance] then return true end
    -- Moonkin/Tree at stance 5 - check if known
    if stance == 5 then
        if _is_spell_learned and _is_spell_learned(24858) then return true end
        if _is_spell_learned and _is_spell_learned(33891) then return true end
    end
    return false
end

-- Check if a spell can be cast in the druid's current form.
-- Moonkin/Tree/Humanoid always return true (rotation logic handles spell selection).
local function can_cast_in_current_form(spell_id)
    if not spell_id then return true end
    if not NS.can_cast_in_form then return true end  -- Module not loaded
    if NS.has_player_buff and NS.has_player_buff(FORM_BUFF_BEAR) then
        return NS.can_cast_in_form(spell_id, FORM_ID_BEAR)
    end
    if NS.has_player_buff and NS.has_player_buff(FORM_BUFF_CAT) then
        return NS.can_cast_in_form(spell_id, FORM_ID_CAT)
    end
    -- Moonkin, Tree, Humanoid: rotation logic handles spell selection
    return true
end

-- Get form cost for reshift
local function get_form_cost_for_spell(spell_id)
    -- Cat: 30 energy, Bear: 20 rage
    if spell_id == 768 then return 30 end
    if spell_id == 9634 or spell_id == 5487 then return 20 end
    return 0
end

-- Check if we can afford to reshift after using an item in a shifted form
local function can_afford_reshift(stance)
    if stance == STANCE_CASTER then return true end
    local form_spell_id = (stance == STANCE_CAT) and 768 or (stance == STANCE_BEAR) and 9634 or nil
    if not form_spell_id then return true end
    local cost = get_form_cost_for_spell(form_spell_id)
    if cost <= 0 then return true end
    -- Check if we have enough resource to reshift
    if stance == STANCE_CAT then
        local energy = NS.power_current and NS.power_current(NS.POWER_ENERGY) or 0
        return energy >= cost
    elseif stance == STANCE_BEAR then
        local rage = NS.power_current and NS.power_current(NS.POWER_RAGE) or 0
        return rage >= cost
    end
    return true
end

-- AoE/cleave spell IDs for PvP CC gating (any rank learned = gate active)
local DRUID_AOE_IDS = { 779, 17401 }  -- Swipe (Bear), Hurricane

-- Form buff IDs for CC break detection
local FORM_BUFFS = {
    BEAR = { 9634, 5487 },
    CAT = { 768 },
    MOONKIN = { 24858 },
    TREE = { 33891 },
    TRAVEL = { 783 },
    AQUATIC = { 1066 },
}

-- Root/snare debuffs breakable by shapeshifting (stuns NOT included — can't shift while stunned)
local ROOT_SNARE_DEBUFFS = {
    339, 5195, 5196, 9852, 9853, 19970, 19972, 19973, 19974, 19975, 26989, 27010,  -- Entangling Roots
    122, 865, 6131, 10230, 27088,   -- Frost Nova
    1715, 7372, 7373,               -- Hamstring
    2974, 14267, 14268,             -- Wing Clip
    3408, 11202, 11201,  -- Crippling Poison
}

-- Throttle shared state to prevent per-frame scan overhead
local _last_ccbreak_scan = 0
local _last_ccbreak_result = false
local CCBREAK_SCAN_INTERVAL = 0.3

local _last_root_scan = 0
local _last_root_result = false
local ROOT_SCAN_INTERVAL = 0.2

-- Shared form-shift throttle across all druid modules
local _last_mw_form_shift = 0
local MW_FORM_SHIFT_COOLDOWN = 2.0

-- Helper: check if druid is in a form that's immune to Polymorph
local function in_poly_immune_form()
    if NS.has_player_buff and NS.has_player_buff(FORM_BUFFS.BEAR) then return true end
    if NS.has_player_buff and NS.has_player_buff(FORM_BUFFS.CAT) then return true end
    if NS.has_player_buff and NS.has_player_buff(FORM_BUFFS.MOONKIN) then return true end
    if NS.has_player_buff and NS.has_player_buff(FORM_BUFFS.TREE) then return true end
    return false
end

-- Helper: check if druid is rooted or snared (throttled to avoid 17 debuff checks per frame)
local function is_rooted_or_snared(me)
    if not me or not NS.debuff_up then return false end
    local now = NS.time_now and NS.time_now() or 0
    if now - _last_root_scan < ROOT_SCAN_INTERVAL then return _last_root_result end
    _last_root_scan = now
    for _, id in ipairs(ROOT_SNARE_DEBUFFS) do
        if NS.debuff_up(me, id) then
            _last_root_result = true
            return true
        end
    end
    _last_root_result = false
    return false
end

-- Helper: find the best form to shift into for CC immunity
local function get_best_cc_form(settings)
    local playstyle = (settings and settings.playstyle) or "balance"
    -- Prefer playstyle-appropriate form
    if playstyle == "bear" then
        for _, id in ipairs(FORM_BUFFS.BEAR) do
            if NS.is_spell_learned and NS.is_spell_learned(id) then return id end
        end
    end
    if playstyle == "cat" then
        for _, id in ipairs(FORM_BUFFS.CAT) do
            if NS.is_spell_learned and NS.is_spell_learned(id) then return id end
        end
    end
    if playstyle == "balance" then
        for _, id in ipairs(FORM_BUFFS.MOONKIN) do
            if NS.is_spell_learned and NS.is_spell_learned(id) then return id end
        end
    end
    if playstyle == "resto" then
        for _, id in ipairs(FORM_BUFFS.TREE) do
            if NS.is_spell_learned and NS.is_spell_learned(id) then return id end
        end
    end
    -- Fallback: Bear Form (tanky default)
    for _, id in ipairs(FORM_BUFFS.BEAR) do
        if NS.is_spell_learned and NS.is_spell_learned(id) then return id end
    end
    -- Then Cat Form
    for _, id in ipairs(FORM_BUFFS.CAT) do
        if NS.is_spell_learned and NS.is_spell_learned(id) then return id end
    end
    return nil
end

local strategies = {

    interrupt_manager.register_interrupt_spell("druid", "FeralCharge", SPELLS, "bear"),
    interrupt_manager.register_interrupt_spell("druid", "Bash", SPELLS, "bear"),

    -- ============================================================================
    -- CC Break: preemptively shapeshift when enemy casts Poly/Cyclone at caster-form druid
    -- Reactive: shapeshift to break roots/snares
    -- ============================================================================
    {
        name = "DruidCCBreak",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_cc_break == false then return false end
            if not context.in_combat then return false end
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            -- Throttle: full scan is expensive (enemy iteration + preemptive CC detection)
            local now = NS.time_now and NS.time_now() or 0
            if now - _last_ccbreak_scan < CCBREAK_SCAN_INTERVAL then
                if not _last_ccbreak_result then return false end
                -- If we throttled a positive result, fall through to reactive check only
            else
                _last_ccbreak_scan = now
                _last_ccbreak_result = false
                -- Preemptive scan: check if any nearby enemy is casting Poly/Cyclone/Hibernate on us
                -- Only preempt if we're in caster form (forms are immune to Poly)
                if not in_poly_immune_form() then
                    local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(30) or {}
                    for _, enemy in ipairs(enemies) do
                        if enemy then
                            local is_casting_cc = CCBreakDB.is_casting_preemptive_cc(enemy)
                            if is_casting_cc then
                                local ok, etarget = pcall(function() return enemy:get_target() end)
                                if ok and etarget and NS.same_unit and NS.same_unit(etarget, me) then
                                    local form_id = get_best_cc_form(settings)
                                    if form_id and NS.spell_ready and NS.spell_ready(form_id, me, { skip_range = true }) then
                                        _last_ccbreak_result = true
                                        return true
                                    end
                                end
                            end
                        end
                    end
                end
            end
            -- Reactive: shapeshift to break roots/snares (roots allow casting, so this path works)
            if is_rooted_or_snared(me) then
                local form_id = get_best_cc_form(settings)
                if form_id and NS.spell_ready and NS.spell_ready(form_id, me, { skip_range = true }) then
                    return true
                end
            end
            return false
        end,
        execute = function(context)
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            local form_id = get_best_cc_form(context.settings or {})
            if not form_id then return false end
            -- Apply shared form-shift throttle to prevent rapid oscillation
            local now = NS.time_now and NS.time_now() or 0
            if now - _last_mw_form_shift < MW_FORM_SHIFT_COOLDOWN then return false end
            local ok = NS.try_cast(form_id, me, "[DRUID] Shapeshift → CC Break", { skip_range = true })
            if ok then _last_mw_form_shift = now end
            return ok
        end,
    },

    -- ============================================================================
    -- FORM-AWARE CONSUMABLES (pots/runes usable in Cat/Bear with auto-reshift)
    -- ============================================================================
    {
        name = "FormAwareConsumables",
        matches = function(context)
            local settings = context.settings or {}
            if not context.in_combat then return false end
            if NS.buff_up(context.me, { 5215, 5217, 5216, 5218, 9839, 9840, 9841, 24249, 24389, 24404 }) then return false end
            if not can_use_items(context.stance) then return false end
            if not can_afford_reshift(context.stance) then return false end

            -- Check healthstone
            if settings.use_healthstone and context.hp and context.hp <= (settings.healthstone_hp or 30) then
                if NS.is_item_ready and NS.is_item_ready(22103) then return true end
            end

            -- Check healing potion
            if settings.use_healing_potion and context.hp and context.hp <= (settings.healing_potion_hp or 35) then
                if NS.is_item_ready and NS.is_item_ready(22829) then return true end
                if NS.is_item_ready and NS.is_item_ready(22850) then return true end
            end

            return false
        end,
        execute = function(context)
            local settings = context.settings or {}
            local stance = context.stance

            -- Try healthstone first
            if settings.use_healthstone and context.hp and context.hp <= (settings.healthstone_hp or 30) then
                if NS.is_item_ready and NS.is_item_ready(22103) then
                    if NS.use_item_by_id and NS.use_item_by_id(22103, context.me) then
                        -- Reshift back to form if needed
                        if stance == STANCE_CAT or stance == STANCE_BEAR then
                            local form_spell = (stance == STANCE_CAT) and SPELLS.CatForm or SPELLS.BearForm
                            if form_spell then
                                NS.try_cast(form_spell, context.me, "[DRUID] Reshift after item", { skip_range = true })
                            end
                        end
                        return true
                    end
                end
            end

            -- Try healing potion
            if settings.use_healing_potion and context.hp and context.hp <= (settings.healing_potion_hp or 35) then
                if NS.is_item_ready and NS.is_item_ready(22829) then
                    if NS.use_item_by_id and NS.use_item_by_id(22829, context.me) then
                        -- Reshift back to form if needed
                        if stance == STANCE_CAT or stance == STANCE_BEAR then
                            local form_spell = (stance == STANCE_CAT) and SPELLS.CatForm or SPELLS.BearForm
                            if form_spell then
                                NS.try_cast(form_spell, context.me, "[DRUID] Reshift after item", { skip_range = true })
                            end
                        end
                        return true
                    end
                end
                if NS.is_item_ready and NS.is_item_ready(22850) then
                    if NS.use_item_by_id and NS.use_item_by_id(22850, context.me) then
                        -- Reshift back to form if needed
                        if stance == STANCE_CAT or stance == STANCE_BEAR then
                            local form_spell = (stance == STANCE_CAT) and SPELLS.CatForm or SPELLS.BearForm
                            if form_spell then
                                NS.try_cast(form_spell, context.me, "[DRUID] Reshift after item", { skip_range = true })
                            end
                        end
                        return true
                    end
                end
            end

            return false
        end,
    },

    -- ============================================================================
    -- PARTY DISPEL (Remove Curse / Abolish Poison party scan)
    -- ============================================================================
    {
        name = "PartyDispel",
        matches = function(context)
            local settings = context.settings or {}
            -- Shared global kill switch
            if settings.auto_dispel == false then return false end
            -- Playstyle-specific AND gate: respect balance_auto_dispel / resto_auto_dispel
            local playstyle = settings.playstyle or settings.active_playstyle or ""
            local playstyle_key = playstyle .. "_auto_dispel"
            if settings[playstyle_key] == false then return false end
            if not context.in_combat then return false end
            -- Check self for curse or poison
            local me = context.me or NS.GetPlayer()
            -- Curse debuffs (common ones)
            local curse_debuffs = { 28282, 28271, 11719, 5116, 5115, 23426, 23427 }
            if me and NS.debuff_up(me, curse_debuffs) then return true end
            -- Poison debuffs
            local poison_debuffs = { 13218, 13219, 13222, 13223, 13225, 13227, 13228, 13229, 13230, 13235, 13237, 13238, 13240, 13241, 23232, 23233, 23235, 23236, 23237 }
            if me and NS.debuff_up(me, poison_debuffs) then return true end
            -- Scan party members
            if _get_party_frames then
                local ok, frames = pcall(_get_party_frames)
                if ok and type(frames) == "table" then
                    for i = 1, #frames do
                        local unit = frames[i]
                        if unit and unit:is_valid() then
                            if NS.debuff_up(unit, curse_debuffs) then return true end
                            if NS.debuff_up(unit, poison_debuffs) then return true end
                        end
                    end
                end
            end
            return false
        end,
        execute = function(context)
            local me = context.me or NS.GetPlayer()
            -- Determine best dispel: Remove Curse if curse found, Abolish Poison if only poison
            local curse_debuffs = { 28282, 28271, 11719, 5116, 5115, 23426, 23427 }
            local poison_debuffs = { 13218, 13219, 13222, 13223, 13225, 13227, 13228, 13229, 13230, 13235, 13237, 13238, 13240, 13241, 23232, 23233, 23235, 23236, 23237 }
            local target = nil
            local use_remove_curse = false
            local use_abolish_poison = false
            -- Check self
            if me then
                if NS.debuff_up(me, curse_debuffs) then
                    target = me
                    use_remove_curse = true
                elseif NS.debuff_up(me, poison_debuffs) then
                    target = me
                    use_abolish_poison = true
                end
            end
            -- Scan party
            if not target and _get_party_frames then
                local ok, frames = pcall(_get_party_frames)
                if ok and type(frames) == "table" then
                    for i = 1, #frames do
                        local unit = frames[i]
                        if unit and unit:is_valid() then
                            if NS.debuff_up(unit, curse_debuffs) then
                                target = unit
                                use_remove_curse = true
                                break
                            elseif NS.debuff_up(unit, poison_debuffs) then
                                target = unit
                                use_abolish_poison = true
                                break
                            end
                        end
                    end
                end
            end
            -- Cast appropriate dispel (form-aware: skip if in Bear/Cat form)
            if target then
                if use_remove_curse and SPELLS.RemoveCurse then
                    if not can_cast_in_current_form(SPELLS.RemoveCurse) then return false end
                    local ok = NS.try_cast(SPELLS.RemoveCurse, target, "[DRUID] Remove Curse", { skip_range = true })
                    if ok then return true end
                elseif use_abolish_poison and SPELLS.AbolishPoison then
                    if not can_cast_in_current_form(SPELLS.AbolishPoison) then return false end
                    local ok = NS.try_cast(SPELLS.AbolishPoison, target, "[DRUID] Abolish Poison", { skip_range = true })
                    if ok then return true end
                end
            end
            return false
        end,
    },

    {
        name = "ThreatDrop",
        matches = function(context)
            if not context.in_combat then return false end
            if context.settings.use_threat_drop == false then return false end
            return true
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Cower, context.me, "[DRUID] Cower", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- MARK OF THE WILD (Self-buff — maintain MotW at all times)
    -- ========================================================================
    {
        name = "MarkOfTheWild",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_self_buffs == false then return false end
            -- Form-aware: MotW is caster-only, skip if in Bear/Cat form
            if not can_cast_in_current_form(26990) then return false end
            local motw_buffs = { 26991, 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126, 21850, 21849 }
            if NS.has_player_buff and NS.has_player_buff(motw_buffs) then return false end
            local spell = { id = { 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126 }, name = "MarkOfTheWild" }
            return NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast({ id = { 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126 }, name = "MarkOfTheWild" }, context.me, "[DRUID] Mark of the Wild", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- THORNS (Self-buff — maintain Thorns for minor reflect damage)
    -- ========================================================================
    {
        name = "Thorns",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_self_buffs == false then return false end
            -- Form-aware: Thorns is caster-only, skip if in Bear/Cat form
            if not can_cast_in_current_form(26992) then return false end
            local thorns_buffs = { 26992, 9910, 9756, 8914, 1075, 782, 467 }
            if NS.has_player_buff and NS.has_player_buff(thorns_buffs) then return false end
            local spell = { id = { 26992, 9910, 9756, 8914, 1075, 782, 467 }, name = "Thorns" }
            return NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast({ id = { 26992, 9910, 9756, 8914, 1075, 782, 467 }, name = "Thorns" }, context.me, "[DRUID] Thorns", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- BEAR FORM OOC (Pre-combat — enter Bear form for defensive readiness)
    -- ========================================================================
    {
        name = "BearFormPreCombat",
        matches = function(context)
            local settings = context.settings or {}
            if context.in_combat then return false end
            if settings.auto_bear_form_ooc == false then return false end
            -- Playstyle gate: auto bear form is for bear tanks only
            local playstyle = settings.playstyle or settings.active_playstyle or ""
            if playstyle ~= "bear" then return false end
            -- Check if already in Bear Form (buff check)
            local bear_buffs = { 9634, 5487 }
            if NS.has_player_buff and NS.has_player_buff(bear_buffs) then return false end
            local spell = { id = { 9634, 5487 }, name = "BearForm" }
            return NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast({ id = { 9634, 5487 }, name = "BearForm" }, context.me, "[DRUID] Bear Form", { skip_range = true })
        end,
    },

    -- ============================================================================
    -- PvP CC Gate: placed at END of middleware so healthstones/pots/dispels still fire.
    -- Only gates spec-level AoE (Swipe, Hurricane).
    -- ============================================================================
    {
        name = "PvPCCGate",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_pvp_cc_gating == false then return false end
            if not context.in_combat then return false end
            local has_aoe = false
            for _, id in ipairs(DRUID_AOE_IDS) do
                if NS.is_spell_learned and NS.is_spell_learned(id) then
                    has_aoe = true
                    break
                end
            end
            if not has_aoe then return false end
            return CCGateDB.is_any_nearby_enemy_under_cc(NS, 15)
        end,
        execute = function() return true end,
    },

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return context.in_combat end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("druid", strategies)
return strategies
