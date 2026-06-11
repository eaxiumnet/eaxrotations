-- Paladin shared middleware.


local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local CCBreakDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local CCGateDB = CCBreakDB
local SPELLS = NS.PaladinSpells or {}
local REAGENT_SYMBOL_OF_KINGS = 21177
local REAGENT_SYMBOL_OF_WISDOM = 19848
-- AoE/cleave spell IDs for PvP CC gating (any rank learned = gate active)
local PALADIN_AOE_IDS = { 27173, 20924, 20923, 20922, 20116, 26573, 27139, 10318, 2812 }  -- Consecration, Holy Wrath
local BLESSING_KINGS_BUFF = { 25898, 20217 }
local BLESSING_WISDOM_BUFF = { 27143, 27142, 25918, 25894, 25290, 19854, 19853, 19852, 19850, 19742 }
local BLESSING_MIGHT_BUFF = { 27141, 27140, 25916, 25782, 25291, 19838, 19837, 19836, 19835, 19834, 19740 }
local BLESSING_SANCTUARY_BUFF = { 27168, 20914, 20913, 20912, 20911 }
local OTHER_BLESSINGS_FOR_WISDOM = { 25898, 20217, 27141, 27140, 25916, 25782, 25291, 19838, 19837, 19836, 19835, 19834, 19740, 27168, 20914, 20913, 20912, 20911 }
local OTHER_BLESSINGS_FOR_KINGS = { 27143, 27142, 25918, 25894, 25290, 19854, 19853, 19852, 19850, 19742, 27141, 27140, 25916, 25782, 25291, 19838, 19837, 19836, 19835, 19834, 19740, 27168, 20914, 20913, 20912, 20911 }
local ALL_BLESSING_BUFFS = { 25898, 20217, 27143, 27142, 25918, 25894, 25290, 19854, 19853, 19852, 19850, 19742, 27141, 27140, 25916, 25782, 25291, 19838, 19837, 19836, 19835, 19834, 19740, 27168, 20914, 20913, 20912, 20911 }

-- Root/snare debuffs that Blessing of Freedom removes
local ROOT_SNARE_DEBUFFS = {
    339, 5195, 5196, 9852, 9853, 19970, 19972, 19973, 19974, 19975, 26989, 27010,  -- Entangling Roots
    122, 865, 6131, 10230, 27088,   -- Frost Nova
    1715, 7372, 7373,               -- Hamstring
    2974, 14267, 14268,             -- Wing Clip
    3408, 11202, 11201,  -- Crippling Poison
}

-- Spell objects (reuse SPELLS table from class_sylvanas.lua)
local BLESSING_OF_FREEDOM_SPELL = SPELLS.BlessingOfFreedom or { id = { 1044 }, name = "BlessingOfFreedom" }

-- Resolve Divine Shield spell object (reuse SPELLS definition, same as emergency DS strategy)
local function get_divine_shield_spell()
    if not SPELLS.DivineShield then return nil end
    if type(SPELLS.DivineShield) == "table" then return SPELLS.DivineShield end
    if type(SPELLS.DivineShield) == "number" then return { id = { SPELLS.DivineShield }, name = "DivineShield" } end
    return nil
end

local strategies = {

    interrupt_manager.register_interrupt_spell("paladin", "Repentance", SPELLS),
    interrupt_manager.register_interrupt_spell("paladin", "HammerOfJustice", SPELLS),

    -- ============================================================================
    -- DIVINE SHIELD (Emergency — highest priority)
    -- ============================================================================
    {
        name = "Paladin_DivineShield",
        priority = 1000,
        is_defensive = true,
        matches = function(context)
            local settings = context.settings or {}
            if not context.in_combat then return false end
            local threshold = settings.divine_shield_hp or 0
            if threshold <= 0 then return false end
            if (context.hp or 100) <= threshold then
                -- Check Forbearance debuff (25771)
                local me = context.me
                if me and NS.debuff_remains(me, {25771}) > 0 then return false end
                return true
            end
            return false
        end,
        execute = function(context)
            local spell = SPELLS.DivineShield
            if spell and NS.spell_ready and NS.spell_ready(spell, context.me, {}) then
                return NS.try_cast(spell, context.me, "[PALADIN] Divine Shield emergency")
            end
            return false
        end,
    },

    -- ============================================================================
    -- LAY ON HANDS (Emergency full heal)
    -- ============================================================================
    {
        name = "Paladin_LayOnHands",
        priority = 990,
        is_defensive = true,
        matches = function(context)
            local settings = context.settings or {}
            if not context.in_combat then return false end
            local threshold = settings.lay_on_hands_hp or 0
            if threshold <= 0 then return false end
            if (context.hp or 100) <= threshold then
                -- Check Forbearance debuff (25771)
                local me = context.me
                if me and NS.debuff_remains(me, {25771}) > 0 then return false end
                return true
            end
            return false
        end,
        execute = function(context)
            local spell = SPELLS.LayOnHands
            if spell and NS.spell_ready and NS.spell_ready(spell, context.me, {}) then
                return NS.try_cast(spell, context.me, "[PALADIN] Lay On Hands emergency")
            end
            return false
        end,
    },

    -- ============================================================================
    -- SEAL OF WISDOM (Low mana seal swap)
    -- ============================================================================
    {
        name = "Paladin_SealOfWisdom",
        priority = 420,
        matches = function(context)
            local settings = context.settings or {}
            if not settings.use_seal_of_wisdom_low_mana then return false end
            if not context.in_combat then return false end
            -- Playstyle gate: seal swap to zero-damage seal is for holy only
            local playstyle = settings.playstyle or settings.active_playstyle or ""
            if playstyle ~= "holy" then return false end
            -- Only switch when mana is below threshold
            local threshold = settings.seal_of_wisdom_mana_pct or 20
            if (context.mana_pct or 100) > threshold then return false end
            return true
        end,
        execute = function(context)
            -- Use Seal of Wisdom if we have it; if not, skip
            if not SPELLS.SealOfWisdom then return false end
            if NS.spell_ready and NS.spell_ready(SPELLS.SealOfWisdom, context.me, {}) then
                return NS.try_cast(SPELLS.SealOfWisdom, context.me, "[PALADIN] Seal of Wisdom (low mana)")
            end
            return false
        end,
    },

    -- ============================================================================
    -- CLEANSE (Dispel on self — poison + disease + magic)
    -- ============================================================================
    {
        name = "Paladin_Cleanse",
        priority = 200,
        matches = function(context)
            local settings = context.settings or {}
            if not settings.use_cleanse then return false end
            if (context.is_mounted or false) then return false end
            local me = context.me
            if not me then return false end
            -- Check for poison, disease, or magic debuffs on player
            -- Cleanse can remove these; use aura debuff check if available
            local hasPoison = false
            local hasDisease = false
            local hasMagic = false
            if type(NS.has_dispel_type_debuff) == "function" then
                hasPoison = NS.has_dispel_type_debuff(me, "Poison")
                hasDisease = NS.has_dispel_type_debuff(me, "Disease")
                hasMagic = NS.has_dispel_type_debuff(me, "Magic")
            elseif NS.has_player_debuff then
                hasPoison = NS.has_player_debuff({2764, 5237, 11359, 13240})
                hasDisease = NS.has_player_debuff({853, 1368, 2047})
                hasMagic = NS.has_player_debuff({33786, 2855, 30982})
            end
            if not hasPoison and not hasDisease and not hasMagic then return false end
            return true
        end,
        execute = function(context)
            local spell = SPELLS.Cleanse
            if spell and NS.spell_ready and NS.spell_ready(spell, context.me, {}) then
                return NS.try_cast(spell, context.me, "[PALADIN] Cleanse")
            end
            return false
        end,
    },

    -- ============================================================================
    -- HAMMER OF JUSTICE (Interrupt via stun)
    -- ============================================================================
    {
        name = "Paladin_HammerOfJustice",
        priority = 150,
        matches = function(context)
            local settings = context.settings or {}
            if not context.in_combat then return false end
            if settings.use_hammer_of_justice == false then return false end
            if not context.target then return false end
            if not context.has_valid_enemy_target then return false end
            local target = context.target
            -- Check if target is casting
            if target.is_casting and target:is_casting() then
                local cast_left = 0
                if target.get_casting_percent then
                    local ok, pct = pcall(target.get_casting_percent, target)
                    if ok then cast_left = pct end
                end
                -- Only interrupt if cast is past 50% (or no data)
                if cast_left >= 50 or cast_left == 0 then
                    if SPELLS.HammerOfJustice and NS.spell_ready then
                        return NS.spell_ready(SPELLS.HammerOfJustice, target, {})
                    end
                end
            end
            return false
        end,
        execute = function(context)
            local spell = SPELLS.HammerOfJustice
            local target = context.target
            if spell and target and NS.try_cast then
                return NS.try_cast(spell, target, "[PALADIN] Hammer of Justice interrupt")
            end
            return false
        end,
    },

    -- ============================================================================
    -- CC Break: preemptively Divine Shield or Blessing of Freedom when enemy
    -- casts Poly/Fear/Cyclone/Repentance at the paladin.
    -- Reactive: DS or BoFreedom if already CC'd.
    -- ============================================================================
    {
        name = "PaladinCCBreak",
        priority = 160,
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_cc_break == false then return false end
            if not context.in_combat then return false end
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            -- Preemptive scan: check if any nearby enemy is casting CC on us
            local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(30) or {}
            for _, enemy in ipairs(enemies) do
                if enemy then
                    local is_casting_cc = CCBreakDB.is_casting_preemptive_cc(enemy)
                    if is_casting_cc then
                        local ok, etarget = pcall(function() return enemy:get_target() end)
                        if ok and etarget and NS.same_unit and NS.same_unit(etarget, me) then
                            -- Divine Shield: preemptive immunity (expensive but guaranteed)
                            local ds_spell = get_divine_shield_spell()
                            if ds_spell then
                                -- Check Forbearance debuff (25771)
                                if me.debuff_remains and NS.debuff_remains(me, {25771}) > 0 then ds_spell = nil end
                            end
                            if ds_spell and NS.spell_ready and NS.spell_ready(ds_spell, me, { skip_range = true }) then
                                return true
                            end
                            -- Blessing of Freedom: cheap root/snare break (doesn't cause Forbearance)
                            if NS.is_spell_learned and NS.is_spell_learned(1044) then
                                if NS.spell_ready and NS.spell_ready(BLESSING_OF_FREEDOM_SPELL) then
                                    return true
                                end
                            end
                            return false
                        end
                    end
                end
            end
            -- Reactive: check if player is already under breakable CC (Poly/Sap/Repentance/etc.)
            local has_cc, cc_name = CCBreakDB.is_breakable_cc_active(me, NS)
            if has_cc then
                local ds_spell = get_divine_shield_spell()
            if ds_spell and NS.debuff_remains(me, {25771}) > 0 then ds_spell = nil end
                return ds_spell and NS.spell_ready and NS.spell_ready(ds_spell, me, { skip_range = true }) or false
            end
            -- Reactive: check if rooted or snared (BoFreedom handles this)
            if me and NS.debuff_up then
                for _, id in ipairs(ROOT_SNARE_DEBUFFS) do
                    if NS.debuff_up(me, id) then
                        if NS.is_spell_learned and NS.is_spell_learned(1044) and NS.spell_ready and NS.spell_ready(BLESSING_OF_FREEDOM_SPELL) then
                            return true
                        end
                        break
                    end
                end
            end
            return false
        end,
        execute = function(context)
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            -- Try Divine Shield first (immune + break)
            local ds_spell = get_divine_shield_spell()
            if ds_spell and me and NS.debuff_remains(me, {25771}) > 0 then ds_spell = nil end
            if ds_spell and NS.spell_ready and NS.spell_ready(ds_spell, me, { skip_range = true }) then
                return NS.try_cast(ds_spell, me, "[PALADIN] Divine Shield → CC Break", { skip_range = true })
            end
            -- Fallback: Blessing of Freedom (root/snare break)
            if NS.is_spell_learned and NS.is_spell_learned(1044) and NS.spell_ready and NS.spell_ready(BLESSING_OF_FREEDOM_SPELL) then
                return NS.try_cast(BLESSING_OF_FREEDOM_SPELL, me, "[PALADIN] Blessing of Freedom → CC Break", { skip_range = true })
            end
            return false
        end,
    },

    -- ============================================================================
    -- SELF-BUFF: AURA (Out of combat)
    -- ============================================================================
    {
        name = "Paladin_SelfBuffAura",
        priority = 90,
        matches = function(context)
            if context.in_combat then return false end
            if (context.is_mounted or false) then return false end
            -- Check if any aura is active (skip if already has one)
            local me = context.me
            if me then
                if NS.buff_up(me, {465, 7294, 19746, 20218}) then
                    return false
                end
            end
            -- Don't match if player knows NO aura spells at all (e.g. level 1, no trainer)
            if me then
                local aura_known = (SPELLS.DevotionAura and NS.is_spell_learned and NS.is_spell_learned(SPELLS.DevotionAura))
                    or (SPELLS.SanctityAura and NS.is_spell_learned and NS.is_spell_learned(SPELLS.SanctityAura))
                    or (SPELLS.ConcentrationAura and NS.is_spell_learned and NS.is_spell_learned(SPELLS.ConcentrationAura))
                    or (SPELLS.RetributionAura and NS.is_spell_learned and NS.is_spell_learned(SPELLS.RetributionAura))
                if not aura_known then return false end
            end
            return true
        end,
        execute = function(context)
            local settings = context.settings or {}
            local playstyle = settings.playstyle or settings.active_playstyle or "retribution"

            -- Ret: Sanctity Aura if known, else Devotion
            if playstyle == "retribution" then
                -- Try Sanctity Aura first (31892 = Seal of Blood, 20218 = Sanctity Aura)
                if SPELLS.SanctityAura and NS.spell_ready and NS.spell_ready(SPELLS.SanctityAura, context.me, {}) then
                    return NS.try_cast(SPELLS.SanctityAura, context.me, "[PALADIN] Sanctity Aura")
                end
                if SPELLS.DevotionAura and NS.spell_ready and NS.spell_ready(SPELLS.DevotionAura, context.me, {}) then
                    return NS.try_cast(SPELLS.DevotionAura, context.me, "[PALADIN] Devotion Aura (ret fallback)")
                end
            end

            -- Prot: Devotion Aura
            if playstyle == "protection" then
                if SPELLS.DevotionAura and NS.spell_ready and NS.spell_ready(SPELLS.DevotionAura, context.me, {}) then
                    return NS.try_cast(SPELLS.DevotionAura, context.me, "[PALADIN] Devotion Aura")
                end
            end

            -- Holy: Concentration Aura
            if playstyle == "holy" then
                if SPELLS.ConcentrationAura and NS.spell_ready and NS.spell_ready(SPELLS.ConcentrationAura, context.me, {}) then
                    return NS.try_cast(SPELLS.ConcentrationAura, context.me, "[PALADIN] Concentration Aura")
                end
                if SPELLS.DevotionAura and NS.spell_ready and NS.spell_ready(SPELLS.DevotionAura, context.me, {}) then
                    return NS.try_cast(SPELLS.DevotionAura, context.me, "[PALADIN] Devotion Aura (holy fallback)")
                end
            end

            return false
        end,
    },

    -- ============================================================================
    -- SELF-BUFF: BLESSING (Out of combat)
    -- ============================================================================
    {
        name = "Paladin_SelfBuffBlessing",
        priority = 80,
        matches = function(context)
            if context.in_combat then return false end
            if (context.is_mounted or false) then return false end
            -- Check if any blessing is active
            local me = context.me
            if me and NS.buff_up(me, ALL_BLESSING_BUFFS) then
                return false
            end
            -- Don't match if player knows NO blessing spells at all (e.g. level 1, no trainer)
            if me then
                local blessing_known = (SPELLS.BlessingOfMight and NS.is_spell_learned and NS.is_spell_learned(SPELLS.BlessingOfMight))
                    or (SPELLS.BlessingOfWisdom and NS.is_spell_learned and NS.is_spell_learned(SPELLS.BlessingOfWisdom))
                    or (SPELLS.BlessingOfKings and NS.is_spell_learned and NS.is_spell_learned(SPELLS.BlessingOfKings))
                    or (SPELLS.BlessingOfSanctuary and NS.is_spell_learned and NS.is_spell_learned(SPELLS.BlessingOfSanctuary))
                    or (SPELLS.BlessingOfLight and NS.is_spell_learned and NS.is_spell_learned(SPELLS.BlessingOfLight))
                    or (SPELLS.BlessingOfSacrifice and NS.is_spell_learned and NS.is_spell_learned(SPELLS.BlessingOfSacrifice))
                if not blessing_known then return false end
            end
            return true
        end,
        execute = function(context)
            local settings = context.settings or {}
            local playstyle = settings.playstyle or settings.active_playstyle or "retribution"

            -- Ret: Blessing of Might
            if playstyle == "retribution" then
                if SPELLS.BlessingOfMight and NS.spell_ready and NS.spell_ready(SPELLS.BlessingOfMight, context.me, {}) then
                    return NS.try_cast(SPELLS.BlessingOfMight, context.me, "[PALADIN] Blessing of Might")
                end
            end

            -- Prot: Blessing of Kings if known, else Might
            if playstyle == "protection" then
                if SPELLS.BlessingOfKings and NS.spell_ready and NS.spell_ready(SPELLS.BlessingOfKings, context.me, {}) then
                    return NS.try_cast(SPELLS.BlessingOfKings, context.me, "[PALADIN] Blessing of Kings")
                end
                if SPELLS.BlessingOfMight and NS.spell_ready and NS.spell_ready(SPELLS.BlessingOfMight, context.me, {}) then
                    return NS.try_cast(SPELLS.BlessingOfMight, context.me, "[PALADIN] Blessing of Might (prot fallback)")
                end
            end

            -- Holy: Blessing of Wisdom
            if playstyle == "holy" then
                if SPELLS.BlessingOfWisdom and NS.spell_ready and NS.spell_ready(SPELLS.BlessingOfWisdom, context.me, {}) then
                    return NS.try_cast(SPELLS.BlessingOfWisdom, context.me, "[PALADIN] Blessing of Wisdom")
                end
            end

            return false
        end,
    },

    -- ============================================================================
    -- SELF-BUFF: KINGS (Out of combat - refresh)
    -- ============================================================================
    {
        name = "Paladin_SelfBuffKings",
        priority = 75,
        matches = function(context)
            if context.in_combat then return false end
            if (context.is_mounted or false) then return false end
            local settings = context.settings or {}
            local playstyle = settings.playstyle or settings.active_playstyle or ""
            if playstyle ~= "protection" then return false end
            local me = context.me
            if not me or not NS.buff_remains then return false end
            -- nil-guard: if both buff_remains return nil, API is unavailable — skip to avoid spam
            local kingsRemains = NS.buff_remains(me, BLESSING_KINGS_BUFF) or 0
            if kingsRemains > 120 then return false end
            if not SPELLS.BlessingOfKings then return false end
            return true
        end,
        execute = function(context)
            if not SPELLS.BlessingOfKings then return false end
            local useGreater = false
            if NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25898) and NS.has_item then
                if NS.has_item(REAGENT_SYMBOL_OF_KINGS) then useGreater = true end
            end
            local spell = useGreater and SPELLS.GreaterBlessingOfKings or SPELLS.BlessingOfKings
            local label = useGreater and "Greater Blessing of Kings" or "Blessing of Kings"
            if NS.spell_ready and NS.spell_ready(spell, context.me, {}) then
                return NS.try_cast(spell, context.me, "[PALADIN] " .. label .. " (self, OOC)")
            end
            return false
        end,
    },

    -- ============================================================================
    -- COMBAT KINGS REFRESH (Self only)
    -- ============================================================================
    {
        name = "Paladin_CombatKingsRefresh",
        priority = 72,
        matches = function(context)
            if not context.in_combat then return false end
            local settings = context.settings or {}
            local playstyle = settings.playstyle or settings.active_playstyle or ""
            if playstyle ~= "protection" then return false end
            local me = context.me
            if not me or not NS.buff_remains then return false end
            local manaPct = context.mana_pct or 100
            if manaPct < (settings.combat_kings_refresh_mana or 30) then return false end
            -- nil-guard: if both buff_remains return nil or 0, API is unavailable
            local kingsRemains = NS.buff_remains(me, BLESSING_KINGS_BUFF) or 0
            if kingsRemains == 0 then return false end
            local threshold = settings.combat_kings_refresh_threshold or 60
            if kingsRemains > threshold then return false end
            if not SPELLS.BlessingOfKings then return false end
            return true
        end,
        execute = function(context)
            if not SPELLS.BlessingOfKings then return false end
            if NS.spell_ready and NS.spell_ready(SPELLS.BlessingOfKings, context.me, {}) then
                return NS.try_cast(SPELLS.BlessingOfKings, context.me, "[PALADIN] Combat Kings refresh (self)")
            end
            return false
        end,
    },

    -- ============================================================================
    -- COMBAT WISDOM REFRESH (Self then party)
    -- ============================================================================
    {
        name = "Paladin_CombatWisdomRefresh",
        priority = 71,
        matches = function(context)
            if not context.in_combat then return false end
            local me = context.me
            if not me or not NS.buff_remains then return false end
            local settings = context.settings or {}
            local manaPct = context.mana_pct or 100
            if manaPct < (settings.combat_wisdom_refresh_mana or 30) then return false end
            -- Playstyle gate: combat wisdom refresh is intended for holy only
            local playstyle = settings.playstyle or settings.active_playstyle or ""
            if playstyle ~= "holy" then return false end
            -- Blessing detection: don't overwrite Kings/Might/Sanctuary (safety net)
            if NS.buff_up and NS.buff_up(me, OTHER_BLESSINGS_FOR_WISDOM) then return false end
            local threshold = settings.combat_wisdom_refresh_threshold or 120
            -- Check self first
            local wisdomRemains = NS.buff_remains(me, BLESSING_WISDOM_BUFF) or 0
            if wisdomRemains <= threshold and SPELLS.BlessingOfWisdom then
                return true
            end
            -- Check party members
            local useGreater = false
            if NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25894) and NS.has_item then
                if NS.has_item(REAGENT_SYMBOL_OF_WISDOM) then useGreater = true end
            end
            if NS.GetPartyMembers then
                local members = NS.GetPartyMembers()
                for _, member in ipairs(members or {}) do
                    if member and NS.buff_remains then
                        local mRemains = NS.buff_remains(member, BLESSING_WISDOM_BUFF) or 0
                        if mRemains <= threshold then
                            if (useGreater and SPELLS.GreaterBlessingOfWisdom) or SPELLS.BlessingOfWisdom then
                                return true
                            end
                        end
                    end
                end
            end
            return false
        end,
        execute = function(context)
            local me = context.me
            local settings = context.settings or {}
            local threshold = settings.combat_wisdom_refresh_threshold or 120
            -- Self first
            local selfRemains = NS.buff_remains(me, BLESSING_WISDOM_BUFF) or 0
            if selfRemains <= threshold and SPELLS.BlessingOfWisdom and NS.spell_ready and NS.spell_ready(SPELLS.BlessingOfWisdom, me, {}) then
                return NS.try_cast(SPELLS.BlessingOfWisdom, me, "[PALADIN] Combat Wisdom refresh (self)")
            end
            -- Group members
            local useGreater = false
            if NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25894) and NS.has_item then
                if NS.has_item(REAGENT_SYMBOL_OF_WISDOM) then useGreater = true end
            end
            if NS.GetPartyMembers then
                local members = NS.GetPartyMembers()
                for _, member in ipairs(members or {}) do
                    if member and NS.buff_remains then
                        local mRemains = NS.buff_remains(member, BLESSING_WISDOM_BUFF) or 0
                        if mRemains <= threshold then
                            if useGreater and SPELLS.GreaterBlessingOfWisdom and NS.spell_ready and NS.spell_ready(SPELLS.GreaterBlessingOfWisdom, member, {}) then
                                return NS.try_cast(SPELLS.GreaterBlessingOfWisdom, member, "[PALADIN] Greater Wisdom refresh (party)")
                            elseif SPELLS.BlessingOfWisdom and NS.spell_ready and NS.spell_ready(SPELLS.BlessingOfWisdom, member, {}) then
                                return NS.try_cast(SPELLS.BlessingOfWisdom, member, "[PALADIN] Wisdom refresh (party)")
                            end
                        end
                    end
                end
            end
            return false
        end,
    },

    -- ============================================================================
    -- COMBAT KINGS REFRESH (Group)
    -- ============================================================================
    {
        name = "Paladin_CombatGroupKingsRefresh",
        priority = 70,
        matches = function(context)
            if not context.in_combat then return false end
            local settings = context.settings or {}
            local playstyle = settings.playstyle or settings.active_playstyle or ""
            if playstyle ~= "protection" then return false end
            local manaPct = context.mana_pct or 100
            if manaPct < (settings.combat_kings_refresh_mana or 30) then return false end
            local useGreater = false
            if NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25898) and NS.has_item then
                if NS.has_item(REAGENT_SYMBOL_OF_KINGS) then useGreater = true end
            end
            if NS.GetPartyMembers then
                local members = NS.GetPartyMembers()
                for _, member in ipairs(members or {}) do
                    if member and NS.buff_remains then
                        local mRemains = NS.buff_remains(member, BLESSING_KINGS_BUFF) or 0
                        if mRemains <= (settings.combat_kings_refresh_threshold or 60) then
                            if (useGreater and SPELLS.GreaterBlessingOfKings) or SPELLS.BlessingOfKings then
                                return true
                            end
                        end
                    end
                end
            end
            return false
        end,
        execute = function(context)
            local settings = context.settings or {}
            local threshold = settings.combat_kings_refresh_threshold or 60
            local useGreater = false
            if NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25898) and NS.has_item then
                if NS.has_item(REAGENT_SYMBOL_OF_KINGS) then useGreater = true end
            end
            if NS.GetPartyMembers then
                local members = NS.GetPartyMembers()
                for _, member in ipairs(members or {}) do
                    if member and NS.buff_remains then
                        local mRemains = NS.buff_remains(member, BLESSING_KINGS_BUFF) or 0
                        if mRemains <= threshold then
                            if useGreater and SPELLS.GreaterBlessingOfKings and NS.spell_ready and NS.spell_ready(SPELLS.GreaterBlessingOfKings, member, {}) then
                                return NS.try_cast(SPELLS.GreaterBlessingOfKings, member, "[PALADIN] Greater Kings refresh (party)")
                            elseif SPELLS.BlessingOfKings and NS.spell_ready and NS.spell_ready(SPELLS.BlessingOfKings, member, {}) then
                                return NS.try_cast(SPELLS.BlessingOfKings, member, "[PALADIN] Kings refresh (party)")
                            end
                        end
                    end
                end
            end
            return false
        end,
    },

    -- ============================================================================
    -- GROUP BLESS KINGS (Out of combat)
    -- ============================================================================
    {
        name = "Paladin_GroupBlessKings",
        priority = 65,
        matches = function(context)
            if context.in_combat then return false end
            if (context.is_mounted or false) then return false end
            if not SPELLS.BlessingOfKings then return false end
            local useGreater = false
            if NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25898) and NS.has_item then
                if NS.has_item(REAGENT_SYMBOL_OF_KINGS) then useGreater = true end
            end
            if NS.GetPartyMembers then
                local members = NS.GetPartyMembers()
                for _, member in ipairs(members or {}) do
                    if member and NS.buff_remains then
                        local mRemains = NS.buff_remains(member, BLESSING_KINGS_BUFF) or 0
                        -- Skip if they have another blessing type (don't overwrite)
                        local hasOther = NS.buff_up and NS.buff_up(member, OTHER_BLESSINGS_FOR_KINGS)
                        if not hasOther and mRemains <= 0 then
                            if (useGreater and SPELLS.GreaterBlessingOfKings) or SPELLS.BlessingOfKings then
                                return true
                            end
                        end
                    end
                end
            end
            return false
        end,
        execute = function(context)
            local useGreater = false
            if NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25898) and NS.has_item then
                if NS.has_item(REAGENT_SYMBOL_OF_KINGS) then useGreater = true end
            end
            if NS.GetPartyMembers then
                local members = NS.GetPartyMembers()
                for _, member in ipairs(members or {}) do
                    if member and NS.buff_remains then
                        local mRemains = NS.buff_remains(member, BLESSING_KINGS_BUFF) or 0
                        local hasOther = NS.buff_up and NS.buff_up(member, OTHER_BLESSINGS_FOR_KINGS)
                        if not hasOther and mRemains <= 0 then
                            if useGreater and SPELLS.GreaterBlessingOfKings and NS.spell_ready and NS.spell_ready(SPELLS.GreaterBlessingOfKings, member, {}) then
                                return NS.try_cast(SPELLS.GreaterBlessingOfKings, member, "[PALADIN] Greater Kings (group, OOC)")
                            elseif SPELLS.BlessingOfKings and NS.spell_ready and NS.spell_ready(SPELLS.BlessingOfKings, member, {}) then
                                return NS.try_cast(SPELLS.BlessingOfKings, member, "[PALADIN] Kings (group, OOC)")
                            end
                        end
                    end
                end
            end
            return false
        end,
    },

    -- ============================================================================
    -- PvP CC Gate: placed at END of middleware so DS/LoH/Cleanse/blessings still fire.
    -- Only gates spec-level AoE (Consecration, Holy Wrath).
    -- ============================================================================
    {
        name = "PvPCCGate",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_pvp_cc_gating == false then return false end
            if not context.in_combat then return false end
            local has_aoe = false
            for _, id in ipairs(PALADIN_AOE_IDS) do
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
    { name = "AutoConsumable", matches = function(context) return context.in_combat and (context.player_level or 999) >= 10 end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("paladin", strategies)
return strategies

