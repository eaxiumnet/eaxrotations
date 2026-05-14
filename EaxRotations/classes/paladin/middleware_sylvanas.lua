-- Readability notes:
--   What: Paladin shared middleware.
--   When: dispatcher runs it before the selected playstyle.
--   Why: threat tools are centralized instead of duplicated in every spec.
--   Safety: threat drops require group combat and an ally within 40 yards; never solo.

-- Decision notes:
--   Middleware owns class-wide reactions such as interrupts, defensive checks, utility, and recovery actions.
--   A middleware row should return true only when it actually performs work; otherwise playstyle priorities must continue.
--   Safety gates are repeated here when the action can disrupt combat flow or break crowd control.
local NS = _G.EaxRotations
if not NS then return nil end
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local SPELLS = NS.PaladinSpells or {}
local REAGENT_SYMBOL_OF_KINGS = 21177
local REAGENT_SYMBOL_OF_WISDOM = 19848
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
                if me and me.debuff_remains then
                    if me:debuff_remains(25771) > 0 then return false end
                end
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
                if me and me.debuff_remains then
                    if me:debuff_remains(25771) > 0 then return false end
                end
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
            if context.is_mounted then return false end
            local me = context.me
            if not me then return false end
            -- Check for poison, disease, or magic debuffs on player
            -- Cleanse can remove these; use aura debuff check if available
            local hasPoison = false
            local hasDisease = false
            local hasMagic = false
            if me.has_debuff then
                -- TBC cleansable debuff category IDs (approximate)
                -- Poison = 1, Disease = 2, Magic = 4
                -- We check specific common debuffs as fallback
                hasPoison = me:has_debuff(2764) or me:has_debuff(5237) or me:has_debuff(11359) or me:has_debuff(13240)
                hasDisease = me:has_debuff(853) or me:has_debuff(1368) or me:has_debuff(2047)
                hasMagic = me:has_debuff(33786) or me:has_debuff(2855) or me:has_debuff(30982)
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
                    cast_left = target:get_casting_percent()
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
    -- SELF-BUFF: AURA (Out of combat)
    -- ============================================================================
    {
        name = "Paladin_SelfBuffAura",
        priority = 90,
        matches = function(context)
            if context.in_combat then return false end
            if context.is_mounted then return false end
            -- Check if any aura is active (skip if already has one)
            local me = context.me
            if me and me.buff_remains then
                -- Check common aura buff IDs
                local hasAura = false
                -- Devotion Aura: 465
                -- Retribution Aura: 7294
                -- Concentration Aura: 19746
                -- Sanctity Aura: 20218
                if me:has_buff(465) or me:has_buff(7294) or me:has_buff(19746) or me:has_buff(20218) then
                    hasAura = true
                end
                if hasAura then return false end
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
            if context.is_mounted then return false end
            -- Check if any blessing is active
            local me = context.me
            if me and me.has_buff then
                -- Check common blessing buff IDs
                -- Blessing of Might: 19740
                -- Blessing of Kings: 20217
                -- Blessing of Wisdom: 20355
                -- Blessing of Sanctuary: 20911
                if me:has_buff(19740) or me:has_buff(20217) or me:has_buff(20355) or me:has_buff(20911) then
                    return false
                end
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
            if context.is_mounted then return false end
            local settings = context.settings or {}
            local playstyle = settings.playstyle or settings.active_playstyle or ""
            if playstyle ~= "protection" then return false end
            local me = context.me
            if not me or not me.buff_remains then return false end
            local kingsRemains = (me:buff_remains(20217) or 0) + (me:buff_remains(25898) or 0)
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
            if not me or not me.buff_remains then return false end
            local manaPct = context.mana_pct or 100
            if manaPct < (settings.combat_kings_refresh_mana or 30) then return false end
            local kingsRemains = (me:buff_remains(20217) or 0) + (me:buff_remains(25898) or 0)
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
            if not me or not me.buff_remains then return false end
            local settings = context.settings or {}
            local manaPct = context.mana_pct or 100
            if manaPct < (settings.combat_wisdom_refresh_mana or 30) then return false end
            local threshold = settings.combat_wisdom_refresh_threshold or 120
            -- Check self first
            local wisdomRemains = (me:buff_remains(20355) or 0) + (me:buff_remains(25894) or 0)
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
                    if member and member.buff_remains then
                        local mRemains = (member:buff_remains(20355) or 0) + (member:buff_remains(25894) or 0)
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
            local selfRemains = (me:buff_remains(20355) or 0) + (me:buff_remains(25894) or 0)
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
                    if member and member.buff_remains then
                        local mRemains = (member:buff_remains(20355) or 0) + (member:buff_remains(25894) or 0)
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
            local manaPct = context.mana_pct or 100
            if manaPct < (settings.combat_kings_refresh_mana or 30) then return false end
            local useGreater = false
            if NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25898) and NS.has_item then
                if NS.has_item(REAGENT_SYMBOL_OF_KINGS) then useGreater = true end
            end
            if NS.GetPartyMembers then
                local members = NS.GetPartyMembers()
                for _, member in ipairs(members or {}) do
                    if member and member.buff_remains then
                        local mRemains = (member:buff_remains(20217) or 0) + (member:buff_remains(25898) or 0)
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
                    if member and member.buff_remains then
                        local mRemains = (member:buff_remains(20217) or 0) + (member:buff_remains(25898) or 0)
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
            if context.is_mounted then return false end
            if not SPELLS.BlessingOfKings then return false end
            local useGreater = false
            if NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25898) and NS.has_item then
                if NS.has_item(REAGENT_SYMBOL_OF_KINGS) then useGreater = true end
            end
            if NS.GetPartyMembers then
                local members = NS.GetPartyMembers()
                for _, member in ipairs(members or {}) do
                    if member and member.buff_remains then
                        local mRemains = (member:buff_remains(20217) or 0) + (member:buff_remains(25898) or 0)
                        -- Skip if they have another blessing type (don't overwrite)
                        local hasOther = member.has_buff and (member:has_buff(19740) or member:has_buff(20355) or member:has_buff(20911))
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
                    if member and member.buff_remains then
                        local mRemains = (member:buff_remains(20217) or 0) + (member:buff_remains(25898) or 0)
                        local hasOther = member.has_buff and (member:has_buff(19740) or member:has_buff(20355) or member:has_buff(20911))
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

}
NS.register_class_middleware("paladin", strategies)
return strategies