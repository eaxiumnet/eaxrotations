-- paladin/middleware_sylvanas.lua — Paladin rotation middleware (seal, blessing, aura).
-- WHAT:  pre-strategy middleware that enriches context with seal state, blessing coverage, and aura.
-- WHEN:  every tick before strategy evaluation.
-- WHY:   centralizes paladin-specific context enrichment so specs stay focused on rotation logic.
-- SAFETY: nil-guards on all menu references; no allocations in on_update path.

-- Paladin shared middleware.


local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local _ok_int, interrupt_manager = pcall(require, "shared/interrupt_manager_sylvanas")
if not _ok_int or type(interrupt_manager) ~= "table" then interrupt_manager = nil end
local dispel_manager = NS.DispelManager or require("shared/dispel_manager_sylvanas")
local spec_kit = require("shared/spec_kit_sylvanas")
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

-- Auto-build ALL_AURA_BUFFS from SPELLS table — covers ALL ranks of every paladin aura.
-- Pre-fix: middleware only checked rank-1 IDs {465,7294,19746,20218} which missed any
-- higher-rank aura on the player → caused infinite re-cast loop when rank 2+ was active.
-- Production NS.spell_action returns a table {id=fn, IsReady=fn, ..., _meta={ids={...}, levels={...}}} —
-- the rank ID list lives at spell._meta.ids. We read both paths for robustness against
-- any future refactor that flattens the spell shape.
local ALL_AURA_BUFFS = {}
local ALL_AURA_BUFFS_SOURCE = {}
local function resolve_id_list(spell)
    if type(spell) ~= "table" then return nil end
    if type(spell._meta) == "table" and type(spell._meta.ids) == "table" then return spell._meta.ids end
    if type(spell.ids) == "table" then return spell.ids end
    return nil
end
do
    local aura_spell_keys = {
        "DevotionAura", "RetributionAura", "ConcentrationAura", "SanctityAura",
        "FireResistanceAura", "FrostResistanceAura", "ShadowResistanceAura",
    }
    local seen = {}
    for _, key in ipairs(aura_spell_keys) do
        local ids = resolve_id_list(SPELLS[key])
        if ids then
            ALL_AURA_BUFFS_SOURCE[#ALL_AURA_BUFFS_SOURCE + 1] = key
            for _, id in ipairs(ids) do
                if not seen[id] then
                    seen[id] = true
                    ALL_AURA_BUFFS[#ALL_AURA_BUFFS + 1] = id
                end
            end
        end
    end
end
-- Defensive: surface a clearly-named warning if the auto-build silently produced
-- too few IDs. Expected = 28 (8 Devotion + 6 Retribution + 1 Concentration + 1 Sanctity
-- + 4 Fire + 4 Frost + 4 Shadow). Anything substantially below that means a SPELLS
-- key was renamed or NS.spell_action changed shape and the auto-build needs updating.
if NS.log_warning and #ALL_AURA_BUFFS < 28 then
    NS.log_warning("[paladin middleware] ALL_AURA_BUFFS auto-build only collected " .. tostring(#ALL_AURA_BUFFS) ..
        " ids from " .. tostring(#ALL_AURA_BUFFS_SOURCE) .. " of 7 auras; expected >= 28 (8 Devotion + 6 Retribution + 1 Concentration + 1 Sanctity + 4 Fire + 4 Frost + 4 Shadow)")
end

-- Throttle: skip aura re-match within 3s of last successful cast (anti-loop defense).
-- Auras last 30+ minutes, so 3s guard is invisible at runtime.
local _last_aura_cast_time = 0

-- Throttle slot for Paladin_SelfBuffKings (OOC blessing refresh). Same defense-in-depth
-- pattern as _last_aura_cast_time: claimed at end of matches() so anti-flicker rejection
-- in execute() still consume the 3s window.
local _last_kings_match_time = 0

-- Throttle slot for AutoConsumable. The inner consumable_manager.on_update() already
-- has its own 3s throttle on _last_check (see consumable_manager_sylvanas.lua:338),
-- so the consume-decision cadence is unchanged whether we throttle here or not.
-- What changes: matches() stops re-returning true every tick when execute returns
-- false, killing the traceLog spam observed in logs while preserving emergency
-- consumable activation (healthstone at hp<=50, mana pot at mana<=40%) at the same 3s.
local _last_auto_consumable_match_time = 0
local _last_self_buff_blessing_match_time = 0
local _last_combat_kings_refresh_match_time = 0
local _last_combat_wisdom_refresh_match_time = 0
local _last_group_bless_kings_match_time = 0
local _last_divine_shield_emergency_match_time = 0
local _last_lay_on_hands_emergency_match_time = 0

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

local _last_paladin_cc_scan = 0

local strategies = {

    (interrupt_manager and interrupt_manager.register_interrupt_spell
        and interrupt_manager.register_interrupt_spell("paladin", "Repentance", SPELLS))
        or { name = "RepentanceSkip", matches = function() return false end, execute = function() return false end },
    (interrupt_manager and interrupt_manager.register_interrupt_spell
        and interrupt_manager.register_interrupt_spell("paladin", "HammerOfJustice", SPELLS))
        or { name = "HammerOfJusticeSkip", matches = function() return false end, execute = function() return false end },

    -- Defensive dispel via shared DispelManager (Cleanse poison/disease/magic)
    (dispel_manager and dispel_manager.create_dispel_strategy
        and dispel_manager.create_dispel_strategy({ name = "AutoDispel" }))
        or { name = "AutoDispel", matches = function() return false end, execute = function() return false end },

    -- ============================================================================
    -- DIVINE SHIELD (Emergency — highest priority)
    -- ============================================================================
    {
        name = "Paladin_DivineShield",
        priority = 1000,
        is_defensive = true,
        matches = function(context)
            if not context.in_combat then return false end
            local threshold = spec_kit.setting_number(context, "divine_shield_hp", 0)
            if threshold <= 0 then return false end
            if (context.hp or 100) <= threshold then
                local me = context.me
                if me and NS.debuff_remains(me, {25771}) > 0 then return false end
                local now = NS.time_now and NS.time_now() or 0
                if (now - _last_divine_shield_emergency_match_time) < 3.0 then return false end
                _last_divine_shield_emergency_match_time = now
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
            if not context.in_combat then return false end
            local threshold = spec_kit.setting_number(context, "lay_on_hands_hp", 0)
            if threshold <= 0 then return false end
            if (context.hp or 100) <= threshold then
                local me = context.me
                if me and NS.debuff_remains(me, {25771}) > 0 then return false end
                local now = NS.time_now and NS.time_now() or 0
                if (now - _last_lay_on_hands_emergency_match_time) < 3.0 then return false end
                _last_lay_on_hands_emergency_match_time = now
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
            if not spec_kit.setting_bool(context, "use_seal_of_wisdom_low_mana", true) then return false end
            if not context.in_combat then return false end
            -- Playstyle gate: seal swap to zero-damage seal is for holy only
            local playstyle = spec_kit.setting(context, "playstyle", nil) or spec_kit.setting(context, "active_playstyle", "")
            if playstyle ~= "holy" then return false end
            -- Only switch when mana is below threshold
            local threshold = spec_kit.setting_number(context, "seal_of_wisdom_mana_pct", 20)
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
    -- CLEANSE (Dispel on self then party — poison + disease + magic)
    -- ============================================================================
    {
        name = "Paladin_Cleanse",
        priority = 200,
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_cleanse", true) then return false end
            if (context.is_mounted or false) then return false end
            local me = context.me
            if not me then return false end
            local function unitNeedsCleanse(unit)
                if type(NS.has_dispel_type_debuff) == "function" then
                    if NS.has_dispel_type_debuff(unit, "Poison") then return true end
                    if NS.has_dispel_type_debuff(unit, "Disease") then return true end
                    if NS.has_dispel_type_debuff(unit, "Magic") then return true end
                elseif NS.has_debuff then
                    if NS.has_debuff(unit, {2764, 5237, 11359, 13240}) then return true end
                    if NS.has_debuff(unit, {853, 1368, 2047}) then return true end
                    if NS.has_debuff(unit, {33786, 2855, 30982}) then return true end
                end
                return false
            end
            if unitNeedsCleanse(me) then return true end
            if NS.GetPartyMembers then
                for _, member in ipairs(NS.GetPartyMembers() or {}) do
                    if member and unitNeedsCleanse(member) then return true end
                end
            end
            return false
        end,
        execute = function(context)
            local spell = SPELLS.Cleanse
            if not spell then return false end
            local function unitNeedsCleanse(unit)
                if type(NS.has_dispel_type_debuff) == "function" then
                    if NS.has_dispel_type_debuff(unit, "Poison") then return true end
                    if NS.has_dispel_type_debuff(unit, "Disease") then return true end
                    if NS.has_dispel_type_debuff(unit, "Magic") then return true end
                elseif NS.has_debuff then
                    if NS.has_debuff(unit, {2764, 5237, 11359, 13240}) then return true end
                    if NS.has_debuff(unit, {853, 1368, 2047}) then return true end
                    if NS.has_debuff(unit, {33786, 2855, 30982}) then return true end
                end
                return false
            end
            local me = context.me
            if me and unitNeedsCleanse(me) and NS.spell_ready and NS.spell_ready(spell, me, {}) then
                return NS.try_cast(spell, me, "[PALADIN] Cleanse (Self)")
            end
            if NS.GetPartyMembers then
                for _, member in ipairs(NS.GetPartyMembers() or {}) do
                    if member and unitNeedsCleanse(member) and NS.spell_ready and NS.spell_ready(spell, member, {}) then
                        return NS.try_cast(spell, member, "[PALADIN] Cleanse (Party)")
                    end
                end
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
            if not context.in_combat then return false end
            if not spec_kit.setting_bool(context, "use_hammer_of_justice", true) then return false end
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
            if not spec_kit.setting_bool(context, "use_cc_break", true) then return false end
            if not context.in_combat then return false end
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            -- Throttle: expensive enemy iteration
            local now = NS.time_now and NS.time_now() or 0
            if now - _last_paladin_cc_scan < 0.3 then return false end
            _last_paladin_cc_scan = now
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
                                if NS.debuff_remains(me, {25771}) > 0 then ds_spell = nil end
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
            if not spec_kit.setting_bool(context, "use_self_buffs", true) then return false end
            if context.in_combat then return false end
            if (context.is_mounted or false) then return false end
            -- Throttle: skip match within 3s of our last attempt (anti-loop).
            -- Engage from matches() — not from execute() success — so a try_cast blocked
            -- by anti-flicker / GCD / queue rejection still consumes the throttle window.
            local now = NS.time_now and NS.time_now() or 0
            if (now - _last_aura_cast_time) < 3.0 then return false end
            -- Check if any aura is active across all ranks (skip if already has one)
            local me = context.me
            if me then
                if NS.buff_up(me, ALL_AURA_BUFFS) then
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
            -- Claim the throttle slot before execute() runs. This is the critical
            -- anti-loop hardening: even if try_cast returns false (anti-flicker,
            -- GCD, queue full), re-matches within 3s are blocked.
            _last_aura_cast_time = now
            return true
        end,
        execute = function(context)
            local playstyle = spec_kit.setting(context, "playstyle", nil) or spec_kit.setting(context, "active_playstyle", "retribution")

            -- Ret: Sanctity Aura if known, else Devotion
            if playstyle == "retribution" then
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

            -- Leveling: Retribution Aura (damage reflect) preferred; Devotion fallback.
            -- INVARIANT: this branch MUST stay present. Without it, the matcher still
            -- returns true (matches() claims the 3s throttle slot pre-execute) while the
            -- executor falls through to `return false`, producing an infinite "matched=true,
            -- executed=false" trace loop every dispatch tick. The behavior is intentional
            -- for ret/prot/holy but the leveling playstyle was originally omitted by mistake.
            if playstyle == "leveling" then
                if SPELLS.RetributionAura and NS.spell_ready and NS.spell_ready(SPELLS.RetributionAura, context.me, {}) then
                    return NS.try_cast(SPELLS.RetributionAura, context.me, "[PALADIN] Retribution Aura (leveling)")
                end
                if SPELLS.DevotionAura and NS.spell_ready and NS.spell_ready(SPELLS.DevotionAura, context.me, {}) then
                    return NS.try_cast(SPELLS.DevotionAura, context.me, "[PALADIN] Devotion Aura (leveling fallback)")
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
            if not spec_kit.setting_bool(context, "use_self_buffs", true) then return false end
            if context.in_combat then return false end
            if (context.is_mounted or false) then return false end
            local me = context.me
            if me and NS.buff_up(me, ALL_BLESSING_BUFFS) then
                return false
            end
            if me then
                local blessing_known = (SPELLS.BlessingOfMight and NS.is_spell_learned and NS.is_spell_learned(SPELLS.BlessingOfMight))
                    or (SPELLS.BlessingOfWisdom and NS.is_spell_learned and NS.is_spell_learned(SPELLS.BlessingOfWisdom))
                    or (SPELLS.BlessingOfKings and NS.is_spell_learned and NS.is_spell_learned(SPELLS.BlessingOfKings))
                    or (SPELLS.BlessingOfSanctuary and NS.is_spell_learned and NS.is_spell_learned(SPELLS.BlessingOfSanctuary))
                    or (SPELLS.BlessingOfLight and NS.is_spell_learned and NS.is_spell_learned(SPELLS.BlessingOfLight))
                    or (SPELLS.BlessingOfSacrifice and NS.is_spell_learned and NS.is_spell_learned(SPELLS.BlessingOfSacrifice))
                if not blessing_known then return false end
            end
            local now = NS.time_now and NS.time_now() or 0
            if (now - _last_self_buff_blessing_match_time) < 3.0 then return false end
            _last_self_buff_blessing_match_time = now
            return true
        end,
        execute = function(context)
            local playstyle = spec_kit.setting(context, "playstyle", nil) or spec_kit.setting(context, "active_playstyle", "retribution")

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
    -- Anti-loop throttle: same defense-in-depth as Paladin_SelfBuffAura. Claimed at
    -- end of matches(), so anti-flicker / GCD rejections still consume a 3s slot.
    {
        name = "Paladin_SelfBuffKings",
        priority = 75,
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_self_buffs", true) then return false end
            if context.in_combat then return false end
            if (context.is_mounted or false) then return false end
            local playstyle = spec_kit.setting(context, "playstyle", nil) or spec_kit.setting(context, "active_playstyle", "")
            if playstyle ~= "protection" then return false end
            local me = context.me
            if not me or not NS.buff_remains then return false end
            -- nil-guard: if both buff_remains return nil, API is unavailable — skip to avoid spam
            local kingsRemains = NS.buff_remains(me, BLESSING_KINGS_BUFF) or 0
            if kingsRemains > 120 then return false end
            if not SPELLS.BlessingOfKings then return false end
            local now = NS.time_now and NS.time_now() or 0
            if (now - _last_kings_match_time) < 3.0 then return false end
            _last_kings_match_time = now
            return true
        end,
        execute = function(context)
            if not SPELLS.BlessingOfKings then return false end
            local useGreater = false
            local auto_greater = spec_kit.setting_bool(context, "paladin_auto_greater_blessings_in_raid", true)
            if auto_greater and NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25898) and NS.has_item then
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
            local playstyle = spec_kit.setting(context, "playstyle", nil) or spec_kit.setting(context, "active_playstyle", "")
            if playstyle ~= "protection" then return false end
            local me = context.me
            if not me or not NS.buff_remains then return false end
            local manaPct = context.mana_pct or 100
            if manaPct < (spec_kit.setting_number(context, "combat_kings_refresh_mana", 30)) then return false end
            local kingsRemains = NS.buff_remains(me, BLESSING_KINGS_BUFF) or 0
            if kingsRemains == 0 then return false end
            local threshold = spec_kit.setting_number(context, "combat_kings_refresh_threshold", 60)
            if kingsRemains > threshold then return false end
            if not SPELLS.BlessingOfKings then return false end
            local now = NS.time_now and NS.time_now() or 0
            if (now - _last_combat_kings_refresh_match_time) < 3.0 then return false end
            _last_combat_kings_refresh_match_time = now
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
            local manaPct = context.mana_pct or 100
            if manaPct < (spec_kit.setting_number(context, "combat_wisdom_refresh_mana", 30)) then return false end
            local playstyle = spec_kit.setting(context, "playstyle", nil) or spec_kit.setting(context, "active_playstyle", "")
            if playstyle ~= "holy" then return false end
            if NS.buff_up and NS.buff_up(me, OTHER_BLESSINGS_FOR_WISDOM) then return false end
            local threshold = spec_kit.setting_number(context, "combat_wisdom_refresh_threshold", 120)
            local wisdomRemains = NS.buff_remains(me, BLESSING_WISDOM_BUFF) or 0
            if wisdomRemains <= threshold and SPELLS.BlessingOfWisdom then
                local now = NS.time_now and NS.time_now() or 0
                if (now - _last_combat_wisdom_refresh_match_time) < 3.0 then return false end
                _last_combat_wisdom_refresh_match_time = now
                return true
            end
            local useGreater = false
            local auto_greater = spec_kit.setting_bool(context, "paladin_auto_greater_blessings_in_raid", true)
            if auto_greater and NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25894) and NS.has_item then
                if NS.has_item(REAGENT_SYMBOL_OF_WISDOM) then useGreater = true end
            end
            if NS.GetPartyMembers then
                local members = NS.GetPartyMembers()
                for _, member in ipairs(members or {}) do
                    if member and NS.buff_remains then
                        local mRemains = NS.buff_remains(member, BLESSING_WISDOM_BUFF) or 0
                        if mRemains <= threshold then
                            if (useGreater and SPELLS.GreaterBlessingOfWisdom) or SPELLS.BlessingOfWisdom then
                                local now = NS.time_now and NS.time_now() or 0
                                if (now - _last_combat_wisdom_refresh_match_time) < 3.0 then return false end
                                _last_combat_wisdom_refresh_match_time = now
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
            local threshold = spec_kit.setting_number(context, "combat_wisdom_refresh_threshold", 120)
            -- Self first
            local selfRemains = NS.buff_remains(me, BLESSING_WISDOM_BUFF) or 0
            if selfRemains <= threshold and SPELLS.BlessingOfWisdom and NS.spell_ready and NS.spell_ready(SPELLS.BlessingOfWisdom, me, {}) then
                return NS.try_cast(SPELLS.BlessingOfWisdom, me, "[PALADIN] Combat Wisdom refresh (self)")
            end
            -- Group members
            local useGreater = false
            local auto_greater = spec_kit.setting_bool(context, "paladin_auto_greater_blessings_in_raid", true)
            if auto_greater and NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25894) and NS.has_item then
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
            local playstyle = spec_kit.setting(context, "playstyle", nil) or spec_kit.setting(context, "active_playstyle", "")
            if playstyle ~= "protection" then return false end
            local manaPct = context.mana_pct or 100
            if manaPct < (spec_kit.setting_number(context, "combat_kings_refresh_mana", 30)) then return false end
            local useGreater = false
            local auto_greater = spec_kit.setting_bool(context, "paladin_auto_greater_blessings_in_raid", true)
            if auto_greater and NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25898) and NS.has_item then
                if NS.has_item(REAGENT_SYMBOL_OF_KINGS) then useGreater = true end
            end
            if NS.GetPartyMembers then
                local members = NS.GetPartyMembers()
                for _, member in ipairs(members or {}) do
                    if member and NS.buff_remains then
                        local mRemains = NS.buff_remains(member, BLESSING_KINGS_BUFF) or 0
                        if mRemains <= (spec_kit.setting_number(context, "combat_kings_refresh_threshold", 60)) then
                            if (useGreater and SPELLS.GreaterBlessingOfKings) or SPELLS.BlessingOfKings then
                                local now = NS.time_now and NS.time_now() or 0
                                if (now - _last_group_bless_kings_match_time) < 3.0 then return false end
                                _last_group_bless_kings_match_time = now
                                return true
                            end
                        end
                    end
                end
            end
            return false
        end,
        execute = function(context)
            local threshold = spec_kit.setting_number(context, "combat_kings_refresh_threshold", 60)
            local useGreater = false
            local auto_greater = spec_kit.setting_bool(context, "paladin_auto_greater_blessings_in_raid", true)
            if auto_greater and NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25898) and NS.has_item then
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
            local auto_greater = spec_kit.setting_bool(context, "paladin_auto_greater_blessings_in_raid", true)
            if auto_greater and NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25898) and NS.has_item then
                if NS.has_item(REAGENT_SYMBOL_OF_KINGS) then useGreater = true end
            end
            if NS.GetPartyMembers then
                local members = NS.GetPartyMembers()
                for _, member in ipairs(members or {}) do
                    if member and NS.buff_remains then
                        local mRemains = NS.buff_remains(member, BLESSING_KINGS_BUFF) or 0
                        local hasOther = NS.buff_up and NS.buff_up(member, OTHER_BLESSINGS_FOR_KINGS)
                        if mRemains <= (spec_kit.setting_number(context, "group_bless_kings_threshold", 120)) then
                            if (useGreater and SPELLS.GreaterBlessingOfKings) or SPELLS.BlessingOfKings then
                                local now = NS.time_now and NS.time_now() or 0
                                if (now - _last_group_bless_kings_match_time) < 3.0 then return false end
                                _last_group_bless_kings_match_time = now
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
            local auto_greater = spec_kit.setting_bool(context, "paladin_auto_greater_blessings_in_raid", true)
            if auto_greater and NS.is_in_raid and NS.is_in_raid() and NS.is_spell_learned and NS.is_spell_learned(25898) and NS.has_item then
                if NS.has_item(REAGENT_SYMBOL_OF_KINGS) then useGreater = true end
            end
            if NS.GetPartyMembers then
                local members = NS.GetPartyMembers()
                for _, member in ipairs(members or {}) do
                    if member and NS.buff_remains then
                        local mRemains = NS.buff_remains(member, BLESSING_KINGS_BUFF) or 0
                        local hasOther = NS.buff_up and NS.buff_up(member, OTHER_BLESSINGS_FOR_KINGS)
                        if mRemains <= (spec_kit.setting_number(context, "group_bless_kings_threshold", 120)) then
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
            if not spec_kit.setting_bool(context, "use_pvp_cc_gating", true) then return false end
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

    -- Auto-consumable usage (throttle set only on successful execute; inner on_update has its own 3s)
    { name = "AutoConsumable",
      matches = function(context)
          if not context.in_combat then return false end
          if (context.player_level or 999) < 10 then return false end
          local now = NS.time_now and NS.time_now() or 0
          if (now - _last_auto_consumable_match_time) < 3.0 then return false end
          return true
      end,
      execute = function(context)
          local ok = consumable_manager.on_update(context)
          if ok then
              local now = NS.time_now and NS.time_now() or 0
              _last_auto_consumable_match_time = now
          end
          return ok
      end },

}
NS.register_class_middleware("paladin", strategies)
return strategies

