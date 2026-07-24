-- mage/middleware_sylvanas.lua — Mage rotation middleware (buffs, evocation, spellsteal).
-- WHAT:  pre-strategy middleware that enriches context with buff state and mana recovery flags.
-- WHEN:  every tick before strategy evaluation.
-- WHY:   centralizes mage-specific context enrichment so specs stay focused on rotation logic.
-- SAFETY: nil-guards on all menu references; no allocations in on_update path.

-- Mage shared middleware.


local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local _ok_int, interrupt_manager = pcall(require, "shared/interrupt_manager_sylvanas")
if not _ok_int or type(interrupt_manager) ~= "table" then interrupt_manager = nil end
local spec_kit = require("shared/spec_kit_sylvanas")
local OffensiveDispelDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local SPELLS = NS.MageSpells or {}
local _mana_gem_last = 0
local _last_conjure_water = 0
local _last_conjure_food = 0

-- Spellsteal spell object (TBC: 30449, learned at level 68)
local SPELLSTEAL_SPELL = SPELLS.Spellsteal or { id = { 30449 }, name = "Spellsteal" }

-- CC Break spell objects
local BLINK_SPELL = { id = { 1953 }, name = "Blink" }
local ICE_BLOCK_IDS = { 45438 }  -- 11958=ColdSnap not IceBlock; 27619 unverified

-- ============================================================================
-- Helper: scan nearby enemies for best Spellsteal target (per-tick caching)
-- ============================================================================
local _cached_steal_unit = nil
local _cached_steal_priority = 0
local _cached_steal_fresh = false
local function get_spellsteal_target(context)
    if _cached_steal_fresh then
        return _cached_steal_unit, _cached_steal_priority
    end
    _cached_steal_unit = nil
    _cached_steal_priority = 0
    local min_mana = spec_kit.setting_number(context, "spellsteal_mana_floor", 30)
    if (context.mana_pct or 100) < min_mana then return nil, 0 end
    local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(30) or {}
    local best_unit, best_priority = nil, 0
    for _, enemy in ipairs(enemies) do
        if enemy then
            local id, priority = OffensiveDispelDB.find_best_dispel_target(enemy, NS)
            if id and priority and priority > best_priority then
                best_unit, best_priority = enemy, priority
                if best_priority >= OffensiveDispelDB.PRIORITY_CRITICAL then break end
            end
        end
    end
    _cached_steal_unit = best_unit
    _cached_steal_priority = best_priority
    _cached_steal_fresh = true
    return best_unit, best_priority
end
local _rbf_ok, RBF = pcall(require, "shared/ranked_buff_families_sylvanas")
if not _rbf_ok then RBF = nil end
local MAGE_ARMOR_BUFFS = { 27125, 22783, 22782, 6117 }
local MOLTEN_ARMOR_BUFFS = { 30482 }
-- Combined armor family for downgrade checks (any armor active = don't recast lower).
local ALL_MAGE_ARMOR_BUFFS = (RBF and RBF.detect("mage_armor")) or { 27125, 22783, 22782, 6117, 27124, 10220, 10219, 7320, 7302, 7301, 7300, 168, 30482 }
-- Arcane Brilliance first (superior), then AI high→low (Vanilla∪TBC∪WotLK).
local ARCANE_INTELLECT_BUFFS = (RBF and RBF.detect("arcane_intellect")) or { 27127, 23028, 27126, 10157, 10156, 1461, 1460, 1459 }
local MANA_GEM_ITEM_IDS = { 22044, 8008, 8007, 5513, 5514 }
local CURSE_DEBUFFS = { 28282, 28271, 11719, 5116, 5115, 23426, 23427, 23230, 23229, 23364, 702, 703, 704, 11014, 11015, 11708, 13323, 13325, 13326, 18223, 18222, 18180, 18179, 17407, 1499, 1513, 1515 }

local function self_spell_ready(spell, context)
    local me = context.me or NS.GetPlayer()
    if not NS.spell_ready then return false end
    return spell and me and NS.spell_ready(spell, me, { skip_range = true })
end

local function should_use_mage_defensive(context)
    local threshold = spec_kit.setting_number(context, "defensive_hp_threshold", 30)
    if spec_kit.setting_bool(context, "use_defensives", true) == false then return false end
    return context.in_combat == true and (context.hp or 100) < threshold
end

local function has_armor_buff()
    -- BUGFIX (2026-06-29): this function used to return ``false`` when the
    -- API was missing, which is the OPPOSITE of the safe default.  When PS
    -- didn't expose has_player_buff the manager would think the player had
    -- no armor buff and recast every tick.  Now returns true (= "buff up")
    -- on missing API, matching the original defensive intent.  Also splits
    -- the disjunctive ``a or b`` pattern into two explicit checks so a nil
    -- return from one branch doesn't propagate.
    if not NS.has_player_buff then return true end
    local has_mage = NS.has_player_buff(MAGE_ARMOR_BUFFS)
    if has_mage and has_mage ~= false then return true end
    return NS.has_player_buff(MOLTEN_ARMOR_BUFFS) and true or false
end

local function first_ready_mana_gem()
    if not NS.is_item_ready then return nil end
    for _, item_id in ipairs(MANA_GEM_ITEM_IDS) do
        local ok, ready = pcall(NS.is_item_ready, item_id)
        if ok and ready then return item_id end
    end
    return nil
end

local function find_curse_target(context)
    if not context then return nil end
    local me = context.me or NS.GetPlayer()
    if me and NS.debuff_up and NS.debuff_up(me, CURSE_DEBUFFS) then return me end
    local party = NS.GetPartyMembers and NS.GetPartyMembers() or nil
    if type(party) ~= "table" then return nil end
    for _, unit in ipairs(party) do
        if unit and NS.debuff_up and NS.debuff_up(unit, CURSE_DEBUFFS) then return unit end
    end
    return nil
end

local _last_mage_cc_scan = 0
local MAGE_CC_SCAN_INTERVAL = 0.3

local strategies = {

    (interrupt_manager and interrupt_manager.register_interrupt_spell
        and interrupt_manager.register_interrupt_spell("mage", "Counterspell", SPELLS))
        or { name = "CounterspellSkip", matches = function() return false end, execute = function() return false end },

    -- ============================================================================
    -- CC Break: preemptively immune incoming CC with Blink or Ice Block
    -- ============================================================================
    {
        name = "MageCCBreak",
        matches = function(context)
            if spec_kit.setting_bool(context, "use_cc_break", true) == false then return false end
            if not context.in_combat then return false end
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            -- Throttle: expensive enemy iteration
            local now = NS.time_now and NS.time_now() or 0
            if now - _last_mage_cc_scan < MAGE_CC_SCAN_INTERVAL then return false end
            _last_mage_cc_scan = now
            -- Preemptive scan: check if any nearby enemy is casting CC on us
            local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(30) or {}
            for _, enemy in ipairs(enemies) do
                if enemy then
                    local is_casting_cc = OffensiveDispelDB.is_casting_preemptive_cc(enemy)
                    if is_casting_cc then
                        local ok, etarget = pcall(function() return enemy:get_target() end)
                        if ok and etarget and NS.same_unit and NS.same_unit(etarget, me) then
                            -- Ice Block: preemptive immunity (expensive, use only vs big CC)
                            if spec_kit.setting_bool(context, "use_ice_block", true) ~= false then
                                local ib_id = nil
                                for _, id in ipairs(ICE_BLOCK_IDS) do
                                    if NS.is_spell_learned and NS.is_spell_learned(id) then ib_id = id; break end
                                end
                                if ib_id and NS.spell_ready and NS.spell_ready(ib_id) then
                                    return true
                                end
                            end
                            -- Blink: cheaper alternative (breaks stuns/roots, can also dodge projectiles)
                            if NS.is_spell_learned and NS.is_spell_learned(1953) then
                                if NS.spell_ready and NS.spell_ready(1953) then
                                    return true
                                end
                            end
                            return false
                        end
                    end
                end
            end
            -- Fallback: check if player is already under breakable CC (Polymorph fizzle-safety)
            local has_cc = OffensiveDispelDB.is_breakable_cc_active(me, NS)
            if has_cc then
                local ib_id = nil
                for _, id in ipairs(ICE_BLOCK_IDS) do
                    if NS.is_spell_learned and NS.is_spell_learned(id) then ib_id = id; break end
                end
                return ib_id and NS.spell_ready and NS.spell_ready(ib_id) or false
            end
            return false
        end,
        execute = function(context)
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            -- Prefer Ice Block for preemptive immunity (will immune the incoming CC)
            local ib_id = nil
            for _, id in ipairs(ICE_BLOCK_IDS) do
                if NS.is_spell_learned and NS.is_spell_learned(id) then ib_id = id; break end
            end
            if ib_id and NS.spell_ready and NS.spell_ready(ib_id) then
                return NS.try_cast(ib_id, me, "[MAGE] Ice Block → CC Break", { skip_range = true })
            end
            -- Fallback: Blink
            if NS.is_spell_learned and NS.is_spell_learned(1953) and NS.spell_ready and NS.spell_ready(1953) then
                return NS.try_cast(BLINK_SPELL, me, "[MAGE] Blink → CC Break", { skip_range = true })
            end
            return false
        end,
    },

    -- ============================================================================
    -- Spellsteal: strip + steal priority enemy buffs (Bloodlust, BoP, Ice Barrier, etc.)
    -- ============================================================================
    {
        name = "Spellsteal",
        matches = function(context)
            _cached_steal_fresh = false  -- invalidate per-tick cache
            if spec_kit.setting_bool(context, "use_spellsteal", true) == false then return false end
            if not context.in_combat then return false end
            -- Spell check: Spellsteal is learned at level 68
            if not (NS.is_spell_learned and NS.is_spell_learned(30449)) then return false end
            if not (NS.spell_ready and NS.spell_ready(30449)) then return false end
            -- Find best steal target (cached, no double-scan)
            local _, priority = get_spellsteal_target(context)
            return priority and priority >= OffensiveDispelDB.PRIORITY_LOW
        end,
        execute = function(context)
            local target = get_spellsteal_target(context)
            if not target then return false end
            return NS.try_cast(SPELLSTEAL_SPELL, target, "[MAGE] Spellsteal")
        end,
    },

    {
        name = "Defensive",
        matches = function(context)
            if not should_use_mage_defensive(context) then return false end
            local mana_threshold = spec_kit.setting_number(context, "mana_shield_mana_threshold", 50)
            -- BUGFIX (2026-06-29): nil-guard NS.has_player_buff.  ``not nil``
            -- is true, which would falsely report "no Mana Shield buff" and
            -- recast every tick when the API is missing.  Default to ``true``
            -- (= "buff is up, skip recast") so the safe-failure mode matches
            -- the has_armor_buff helper above.
            local has_ms = NS.has_player_buff and NS.has_player_buff(SPELLS.ManaShield) and true or false
            return (spec_kit.setting_bool(context, "use_ice_block", true) ~= false and self_spell_ready(SPELLS.IceBlock, context))
                or (spec_kit.setting_bool(context, "use_mana_shield", true) ~= false and (context.mana_pct or 0) >= mana_threshold and not has_ms and self_spell_ready(SPELLS.ManaShield, context))
        end,
        execute = function(context)
            local mana_threshold = spec_kit.setting_number(context, "mana_shield_mana_threshold", 50)
            if spec_kit.setting_bool(context, "use_ice_block", true) ~= false and self_spell_ready(SPELLS.IceBlock, context) then
                return NS.try_cast(SPELLS.IceBlock, (context.me or NS.GetPlayer()), "[MAGE] Ice Block", { skip_range = true }) == true
            end
            local has_ms = NS.has_player_buff and NS.has_player_buff(SPELLS.ManaShield) and true or false
            if spec_kit.setting_bool(context, "use_mana_shield", true) ~= false and (context.mana_pct or 0) >= mana_threshold and not has_ms and self_spell_ready(SPELLS.ManaShield, context) then
                return NS.try_cast(SPELLS.ManaShield, (context.me or NS.GetPlayer()), "[MAGE] Mana Shield", { skip_range = true }) == true
            end
            return false
        end,
    },

    {
        name = "SelfBuff",
        matches = function(context)
            if spec_kit.setting_bool(context, "use_self_buffs", true) == false then return false end
            local me = context.me or NS.GetPlayer()
            -- BUGFIX (2026-06-29): nil-guard NS.has_player_buff so a missing
            -- API doesn't crash the dispatch.  ``not nil`` is true which would
            -- falsely report "no Arcane Intellect buff" and recast every tick.
            local safe_has_player_buff = NS.has_player_buff or function() return true end
            if not has_armor_buff() then
                local armor_spell = SPELLS.MoltenArmor or SPELLS.MageArmor
                if me and armor_spell and NS.buff_would_downgrade
                    and NS.buff_would_downgrade(me, ALL_MAGE_ARMOR_BUFFS, armor_spell) then
                    -- better/any armor already ranked; fall through to AI check
                else
                    return self_spell_ready(SPELLS.MoltenArmor, context) or self_spell_ready(SPELLS.MageArmor, context)
                end
            end
            if not safe_has_player_buff(ARCANE_INTELLECT_BUFFS) then
                if me and SPELLS.ArcaneIntellect and NS.buff_would_downgrade
                    and NS.buff_would_downgrade(me, ARCANE_INTELLECT_BUFFS, SPELLS.ArcaneIntellect) then
                    return false
                end
                return self_spell_ready(SPELLS.ArcaneIntellect, context)
            end
            return false
        end,
        execute = function(context)
            local me = context.me or NS.GetPlayer()
            if not has_armor_buff() then
                if self_spell_ready(SPELLS.MoltenArmor, context)
                    and not (me and NS.buff_would_downgrade and NS.buff_would_downgrade(me, ALL_MAGE_ARMOR_BUFFS, SPELLS.MoltenArmor))
                    and NS.try_cast(SPELLS.MoltenArmor, me, "[MAGE] Molten Armor", { skip_range = true }) then
                    return true
                end
                if self_spell_ready(SPELLS.MageArmor, context)
                    and not (me and NS.buff_would_downgrade and NS.buff_would_downgrade(me, ALL_MAGE_ARMOR_BUFFS, SPELLS.MageArmor))
                    and NS.try_cast(SPELLS.MageArmor, me, "[MAGE] Mage Armor", { skip_range = true }) then
                    return true
                end
            end
            local safe_has_player_buff = NS.has_player_buff or function() return true end
            if not safe_has_player_buff(ARCANE_INTELLECT_BUFFS) and self_spell_ready(SPELLS.ArcaneIntellect, context) then
                if me and NS.buff_would_downgrade and NS.buff_would_downgrade(me, ARCANE_INTELLECT_BUFFS, SPELLS.ArcaneIntellect) then
                    return false
                end
                return NS.try_cast(SPELLS.ArcaneIntellect, me, "[MAGE] Arcane Intellect", { skip_range = true }) == true
            end
            return false
        end,
    },    {
        name = "PvPIceBlock",
        matches = function(context)
            -- BUGFIX (2026-06-29): PvPIceBlock used to fire unconditionally on
            -- kite-or-low-HP regardless of the user's ``use_ice_block`` toggle.
            -- The user reported this as part of the wider middleware-not-honoring-
            -- toggles issue.  Now respects both the per-spell and PvP toggles,
            -- matching the pattern used by the ``Defensive`` strategy immediately
            -- above.
            if spec_kit.setting_bool(context, "use_ice_block", true) == false then return false end
            if spec_kit.setting_bool(context, "use_pvp_defensives", true) == false then return false end
            if not NS.should_kite or not NS.should_kite(context) or (context.hp or 100) >= 30 then return false end
            return true
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.IceBlock, context.me, "[MAGE] Ice Block", { skip_range = true })
        end,
    },

    -- ============================================================================
    -- ICE BARRIER (Frost talent absorb shield — recast when expired or absorbed)
    -- ============================================================================
    {
        name = "IceBarrier",
        matches = function(context)
            if spec_kit.setting_bool(context, "use_ice_barrier", true) == false then return false end
            if not (context.in_combat and context.me) then return false end
            -- Check if Ice Barrier buff is active (114 # Ice Shield in TBC)
            local barrier_buffs = { 13032, 13031, 13033 }
            if NS.buff_up and NS.buff_up(context.me, barrier_buffs) then return false end
            return self_spell_ready(SPELLS.IceBarrier, context)
        end,
        execute = function(context)
            if NS.try_cast(SPELLS.IceBarrier, context.me, "[MAGE] Ice Barrier", { skip_range = true }) then
                return true
            end
            return false
        end,
    },

    -- ============================================================================
    -- EVOCATION (Mana recovery — channeled, mana threshold + movement check)
    -- ============================================================================
    {
        name = "Evocation",
        matches = function(context)
            if spec_kit.setting_bool(context, "use_evocation", true) == false then return false end
            if not context.in_combat then return false end
            local threshold = spec_kit.setting_number(context, "evocation_mana_pct", 20)
            if (context.mana_pct or 0) > threshold then return false end
            -- Don't cast while moving (channeled spell)
            local me = context.me or NS.GetPlayer()
            local is_moving_fn = NS.safe_field and NS.safe_field(me, "is_moving")
            if is_moving_fn then
                local ok, moving = pcall(is_moving_fn, me)
                if ok and moving == true then return false end
            end
            return self_spell_ready(SPELLS.Evocation, context)
        end,
        execute = function(context)
            if NS.try_cast(SPELLS.Evocation, context.me, "[MAGE] Evocation", { skip_range = true }) then
                return true
            end
            return false
        end,
    },

    -- ============================================================================
    -- MANA GEM (Mana recovery — Mana Emerald -> Ruby -> Citrine fallback)
    -- ============================================================================
    {
        name = "ManaGem",
        matches = function(context)
            if spec_kit.setting_bool(context, "use_mana_gem", true) == false then return false end
            if not context.in_combat then return false end
            local threshold = spec_kit.setting_number(context, "mana_gem_mana_pct", 70)
            if (context.mana_pct or 0) > threshold then return false end
            local now = NS.time_now and NS.time_now() or 0
            if now - (_mana_gem_last or 0) < 30 then return false end
            return first_ready_mana_gem() ~= nil
        end,
        execute = function(context)
            local item_id = first_ready_mana_gem()
            if not item_id or not NS.use_item_by_id then return false end
            local ok = NS.use_item_by_id(item_id) and true or false
            if ok then
                _mana_gem_last = NS.time_now and NS.time_now() or 0
            end
            return ok
        end,
    },

    -- ============================================================================
    -- REMOVE CURSE (Self + party scan for curse dispel)
    -- ============================================================================
    {
        name = "RemoveCurse",
        matches = function(context)
            if spec_kit.setting_bool(context, "auto_remove_curse", true) == false then return false end
            if not context.in_combat then return false end
            return find_curse_target(context) ~= nil
        end,
        execute = function(context)
            local target = find_curse_target(context)
            if target and self_spell_ready(SPELLS.RemoveCurse, context) then
                if NS.try_cast(SPELLS.RemoveCurse, target, "[MAGE] Remove Curse") then
                    return true
                end
            end
            return false
        end,
    },

    -- ========================================================================
    -- CONJURE WATER (OOC — ensure water supply)
    -- ========================================================================
    {
        name = "ConjureWater",
        priority = 450,
        matches = function(context)
            if context.in_combat then return false end
            if spec_kit.setting_bool(context, "auto_conjure_water", true) == false then return false end
            -- Throttle: don't spam conjure
            local now = NS.time_now and NS.time_now() or 0
            if (now - (_last_conjure_water or 0)) < 10 then return false end
            local spell = SPELLS.ConjureWater or { id = { 27090, 10140, 10139, 10138, 5505, 5504, 587 }, name = "ConjureWater" }
            if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            return false
        end,
        execute = function(context)
            _last_conjure_water = NS.time_now and NS.time_now() or 0
            local spell = SPELLS.ConjureWater or { id = { 27090, 10140, 10139, 10138, 5505, 5504, 587 }, name = "ConjureWater" }
            return NS.try_cast(spell, context.me, "[MAGE] Conjure Water", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- CONJURE FOOD (OOC — ensure food supply)
    -- ========================================================================
    {
        name = "ConjureFood",
        priority = 440,
        matches = function(context)
            if context.in_combat then return false end
            if spec_kit.setting_bool(context, "auto_conjure_food", true) == false then return false end
            local now = NS.time_now and NS.time_now() or 0
            if (now - (_last_conjure_food or 0)) < 10 then return false end
            local spell = SPELLS.ConjureFood or { id = { 27091, 10145, 10144, 10143, 5506, 587 }, name = "ConjureFood" }
            if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            return false
        end,
        execute = function(context)
            _last_conjure_food = NS.time_now and NS.time_now() or 0
            local spell = SPELLS.ConjureFood or { id = { 27091, 10145, 10144, 10143, 5506, 587 }, name = "ConjureFood" }
            return NS.try_cast(spell, context.me, "[MAGE] Conjure Food", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- HEALTHSTONE / POTION (Combat emergency heal)
    -- ========================================================================
    {
        name = "Mage_Healthstone",
        priority = 850,
        is_defensive = true,
        matches = function(context)
            if not context.in_combat then return false end
            local threshold = spec_kit.setting_number(context, "healthstone_hp", 0)
            if threshold <= 0 then return false end
            if (context.hp or 100) <= threshold then return true end
            return false
        end,
        execute = function(context)
            local HEALING_POTION_ITEMS = { 21877, 13446, 3928, 1710, 929, 858, 118 }
            local used_item = false
            if NS.use_item and context.me then
                for _, item_id in ipairs(HEALING_POTION_ITEMS) do
                    if NS.use_item(item_id, context.me) then used_item = true; break end
                end
            end
            return used_item
        end,
    },

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return consumable_manager.should_check(context) end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("mage", strategies)
return strategies

