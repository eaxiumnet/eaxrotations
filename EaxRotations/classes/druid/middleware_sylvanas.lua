-- druid/middleware_sylvanas.lua — Druid rotation middleware (form detection, OOC buffs, interrupts).
-- WHAT:  pre-strategy middleware that sets form state, OOC buff priorities, and interrupt flags.
-- WHEN:  every tick before strategy evaluation.
-- WHY:   centralizes druid-specific context enrichment so specs stay focused on rotation logic.
-- SAFETY: nil-guards on all menu references; no allocations in on_update path.

-- Druid shared middleware.


local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local _ok_int, interrupt_manager = pcall(require, "shared/interrupt_manager_sylvanas")
if not _ok_int or type(interrupt_manager) ~= "table" then interrupt_manager = nil end
local dispel_manager = NS.DispelManager or require("shared/dispel_manager_sylvanas")
local spec_kit = require("shared/spec_kit_sylvanas")
local CCBreakDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local CCGateDB = CCBreakDB
local scan_cache = require("shared/middleware_scan_cache_sylvanas")
local SPELLS = NS.DruidSpells or {}
local _rbf_ok, RBF = pcall(require, "shared/ranked_buff_families_sylvanas")
if not _rbf_ok then RBF = nil end
-- BUGFIX (2026-06-29): this file used to read the bare global ``core``, which
-- depended on _G.core being set by core_sylvanas.lua BEFORE this chunk loaded.
-- In test sandboxes or any load-order where core_sylvanas runs later, the
-- read resolved to nil and the two helpers below silently no-op'd in silent
-- ways (party-frame scan + form-shift).  Capture an explicit local from
-- ``NS.core`` (set by core_sylvanas.lua as ``NS.core = _G.core``) so the
-- file is self-contained and not ambient-global dependent.
local core = NS.core or {}
local _is_spell_learned = (type(core) == "table" and type(core.spell_book) == "table" and core.spell_book.is_spell_learned) or NS.is_spell_learned or nil
-- Use central NS.GetPartyMembers (which prioritizes the new core.object_manager.get_party_frames)
-- for accurate, ordered party list. Direct frames access removed in favor of unified API.

-- ============================================================================
-- FORM-SAFE CONSUMABLES
-- Only consume when un-shifted (caster/humanoid). NEVER break Bear/Cat/Moonkin/
-- Tree to drink — the GCD out of Dire Bear Form (armor mult + stamina loss) can
-- kill a tank. A shifted druid simply skips consumables.
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

-- Consumables are caster-form-only (see FORM-SAFE CONSUMABLES above): a shifted
-- druid never drinks, so the old stance-allow table and can_use_items() /
-- can_afford_reshift() helpers were removed — there is nothing to allow or reshift.

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

-- Helper: check if druid is rooted or snared (cached per context to avoid repeated debuff checks)
local function is_rooted_or_snared(context, me)
    if not me or not NS.debuff_up then return false end
    return scan_cache.memoize_bool(context, "druid_rooted_or_snared", function()
        for _, id in ipairs(ROOT_SNARE_DEBUFFS) do
            if NS.debuff_up(me, id) then
                return true
            end
        end
        return false
    end)
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

    (interrupt_manager and interrupt_manager.register_interrupt_spell
        and interrupt_manager.register_interrupt_spell("druid", "FeralCharge", SPELLS, "bear"))
        or { name = "FeralChargeSkip", matches = function() return false end, execute = function() return false end },
    (interrupt_manager and interrupt_manager.register_interrupt_spell
        and interrupt_manager.register_interrupt_spell("druid", "Bash", SPELLS, "bear"))
        or { name = "BashSkip", matches = function() return false end, execute = function() return false end },

    -- ============================================================================
    -- CC Break: preemptively shapeshift when enemy casts Poly/Cyclone at caster-form druid
    -- Reactive: shapeshift to break roots/snares
    -- ============================================================================
    {
        name = "DruidCCBreak",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_cc_break", true) then return false end
            if not context.in_combat then return false end
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            -- Preemptive scan: check if any nearby enemy is casting Poly/Cyclone/Hibernate on us
            -- Only preempt if we're in caster form (forms are immune to Poly)
            if not in_poly_immune_form() then
                local preemptive_enemy = scan_cache.memoize(context, "druid_preemptive_cc", function()
                    local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(30) or {}
                    for _, enemy in ipairs(enemies) do
                        if enemy and CCBreakDB.is_casting_preemptive_cc(enemy) then
                            local ok, etarget = pcall(function() return enemy:get_target() end)
                            if ok and etarget and NS.same_unit and NS.same_unit(etarget, me) then
                                return enemy
                            end
                        end
                    end
                    return false
                end)
                if preemptive_enemy then
                    local form_id = get_best_cc_form(context.settings or {})
                    if form_id and NS.spell_ready and NS.spell_ready(form_id, me, { skip_range = true }) then
                        return true
                    end
                end
            end
            -- Reactive: shapeshift to break roots/snares (roots allow casting, so this path works)
            if is_rooted_or_snared(context, me) then
                local form_id = get_best_cc_form(context.settings or {})
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
    -- FORM-SAFE CONSUMABLES (caster/humanoid only — never break a shapeshift)
    -- ============================================================================
    {
        name = "FormAwareConsumables",
        matches = function(context)
            if not context.in_combat then return false end
            if not spec_kit.setting_bool(context, "use_auto_consumables", true) then return false end
            if NS.buff_up(context.me, { 5215, 5217, 5216, 5218, 9839, 9840, 9841, 24249, 24389, 24404 }) then return false end
            -- Never break shapeshift form to consume. Using an item shifts the
            -- druid out of Bear/Cat/Moonkin/Tree; the GCD spent out of Dire Bear
            -- Form (armor mult + stamina loss) can kill a tank. Only consume when
            -- already un-shifted (caster/humanoid, stance 0) — a shifted druid
            -- simply skips consumables rather than dropping form.
            if context.stance ~= STANCE_CASTER then return false end

            -- Check healthstone
            if spec_kit.setting_bool(context, "use_healthstone", true) and context.hp and context.hp <= spec_kit.setting_number(context, "healthstone_hp", 30) then
                if NS.is_item_ready and NS.is_item_ready(22103) then return true end
            end

            -- Check healing potion
            if spec_kit.setting_bool(context, "use_healing_potion", true) and context.hp and context.hp <= spec_kit.setting_number(context, "healing_potion_hp", 35) then
                if NS.is_item_ready and NS.is_item_ready(22829) then return true end
                if NS.is_item_ready and NS.is_item_ready(22850) then return true end
            end

            return false
        end,
        execute = function(context)
            -- Safety: never consume while shifted (matches already gates this).
            if context.stance ~= STANCE_CASTER then return false end

            -- Healthstone first
            if spec_kit.setting_bool(context, "use_healthstone", true) and context.hp and context.hp <= spec_kit.setting_number(context, "healthstone_hp", 30) then
                if NS.is_item_ready and NS.is_item_ready(22103) then
                    if NS.use_item_by_id and NS.use_item_by_id(22103, context.me) then return true end
                end
            end

            -- Healing / mana potion
            if spec_kit.setting_bool(context, "use_healing_potion", true) and context.hp and context.hp <= spec_kit.setting_number(context, "healing_potion_hp", 35) then
                if NS.is_item_ready and NS.is_item_ready(22829) then
                    if NS.use_item_by_id and NS.use_item_by_id(22829, context.me) then return true end
                end
                if NS.is_item_ready and NS.is_item_ready(22850) then
                    if NS.use_item_by_id and NS.use_item_by_id(22850, context.me) then return true end
                end
            end

            return false
        end,
    },

    -- ============================================================================
    -- PARTY DISPEL (Remove Curse / Abolish Poison via shared DispelManager)
    -- ============================================================================
    (function()
        local base = (dispel_manager and dispel_manager.create_dispel_strategy
            and dispel_manager.create_dispel_strategy({ name = "PartyDispel" }))
            or { name = "PartyDispel", matches = function() return false end, execute = function() return false end }
        local base_matches = base.matches
        local base_execute = base.execute
        return {
            name = "PartyDispel",
            matches = function(context, state)
                if not spec_kit.setting_bool(context, "auto_dispel", true) then return false end
                local playstyle = spec_kit.setting(context, "playstyle", nil)
                    or spec_kit.setting(context, "active_playstyle", nil) or ""
                local playstyle_key = playstyle .. "_auto_dispel"
                if spec_kit.setting(context, playstyle_key, nil) == false then return false end
                if not context.in_combat then return false end
                return base_matches(context, state)
            end,
            execute = function(context)
                local can_curse = SPELLS.RemoveCurse and can_cast_in_current_form(SPELLS.RemoveCurse)
                local can_poison = SPELLS.AbolishPoison and can_cast_in_current_form(SPELLS.AbolishPoison)
                if not can_curse and not can_poison then return false end
                return base_execute(context)
            end,
        }
    end)(),

    {
        name = "ThreatDrop",
        matches = function(context)
            if not context.in_combat then return false end
            if context.settings and context.settings.use_threat_drop == false then return false end
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
            if not spec_kit.setting_bool(context, "use_self_buffs", true) then return false end
            -- Form-aware: MotW is caster-only, skip if in Bear/Cat form
            if not can_cast_in_current_form(26990) then return false end
            local motw_cast = (RBF and RBF.cast("mark_of_the_wild")) or { 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }
            local spell = { id = motw_cast, name = "MarkOfTheWild" }
            -- Aura APIs often report MotW missing after cast → GCD spam.
            -- 300s lockout is well under MotW's real 30m duration.
            -- GotW + all MotW ranks (best first). Never overwrite Gift / higher MotW with a lower rank.
            local motw_buffs = (RBF and RBF.detect("mark_of_the_wild")) or motw_cast
            if NS.buff_would_downgrade and NS.buff_would_downgrade(context.me, motw_buffs, spell) then return false end
            if NS.has_player_buff and NS.has_player_buff(motw_buffs) then return false end
            return NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })
        end,
        execute = function(context)
            local motw_cast = (RBF and RBF.cast("mark_of_the_wild")) or { 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }
            return NS.try_cast({ id = motw_cast, name = "MarkOfTheWild" }, context.me, "[DRUID] Mark of the Wild", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- THORNS (Self-buff — maintain Thorns for minor reflect damage)
    -- ========================================================================
    {
        name = "Thorns",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_self_buffs", true) then return false end
            -- Form-aware: Thorns is caster-only, skip if in Bear/Cat form
            if not can_cast_in_current_form(26992) then return false end
            local thorns_cast = (RBF and RBF.cast("thorns")) or { 26992, 9910, 9756, 8914, 1075, 782, 467 }
            local spell = { id = thorns_cast, name = "Thorns" }
            -- Same aura-API failure mode as MotW (live log: Thorns 782 loop).
            local thorns_buffs = (RBF and RBF.detect("thorns")) or thorns_cast
            if NS.buff_would_downgrade and NS.buff_would_downgrade(context.me, thorns_buffs, spell) then return false end
            if NS.has_player_buff and NS.has_player_buff(thorns_buffs) then return false end
            return NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })
        end,
        execute = function(context)
            local thorns_cast = (RBF and RBF.cast("thorns")) or { 26992, 9910, 9756, 8914, 1075, 782, 467 }
            return NS.try_cast({ id = thorns_cast, name = "Thorns" }, context.me, "[DRUID] Thorns", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- BEAR FORM OOC (Pre-combat — enter Bear form for defensive readiness)
    -- ========================================================================
    {
        name = "BearFormPreCombat",
        matches = function(context)
            if context.in_combat then return false end
            if not spec_kit.setting_bool(context, "auto_bear_form_ooc", true) then return false end
            -- Playstyle gate: auto bear form is for bear tanks only
            local playstyle = spec_kit.setting(context, "playstyle", nil) or spec_kit.setting(context, "active_playstyle", nil) or ""
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

    -- ========================================================================
    -- BARKSKIN (Combat defensive — damage reduction when HP low)
    -- ========================================================================
    {
        name = "Barkskin",
        priority = 850,
        is_defensive = true,
        matches = function(context)
            if not context.in_combat then return false end
            -- Barkskin is caster-form only in TBC and breaks bear/cat form.
            -- Only fire when NOT in a shifted form.
            local shifted_form_buffs = { 9634, 5487, 768, 24858, 33891 }
            if NS.has_player_buff and NS.has_player_buff(shifted_form_buffs) then return false end
            local threshold = spec_kit.setting_number(context, "barkskin_hp", 0)
            if threshold <= 0 then return false end
            if (context.hp or 100) <= threshold then
                local bs_buffs = { 22812 }
                if NS.has_player_buff and NS.has_player_buff(bs_buffs) then return false end
                local spell = SPELLS.Barkskin or { id = bs_buffs, name = "Barkskin" }
                if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            end
            return false
        end,
        execute = function(context)
            local spell = SPELLS.Barkskin or { id = { 22812 }, name = "Barkskin" }
            return NS.try_cast(spell, context.me, "[DRUID] Barkskin", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- INNERVATE (Combat mana recovery — prefer low-mana healer, fallback self)
    -- ========================================================================
    {
        name = "Innervate",
        priority = 750,
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_innervate", true) then return false end
            if not context.in_combat then return false end
            -- Innervate requires caster form in TBC; do NOT break bear/cat/moonkin/tree.
            local shifted_form_buffs = { 9634, 5487, 768, 24858, 33891 }
            if NS.has_player_buff and NS.has_player_buff(shifted_form_buffs) then return false end
            local spell = SPELLS.Innervate or { id = { 29166 }, name = "Innervate" }
            if not (NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })) then return false end
            -- Check if Innervate buff already on anyone we care about
            local innervate_buff = { 29166 }
            if NS.has_player_buff and NS.has_player_buff(innervate_buff) then return false end
            local mana_pct = context.mana_pct or 100
            local threshold = spec_kit.setting_number(context, "innervate_mana_pct", 30)
            if mana_pct <= threshold then return true end
            -- Also cast if a healer party member is low mana
            if NS.GetPartyMembers then
                local HEALER_CLASS_IDS = { [2] = true, [5] = true, [7] = true, [11] = true }
                for _, member in ipairs(NS.GetPartyMembers() or {}) do
                    if member then
                        local class_id = nil
                        pcall(function() class_id = member:get_class() end)
                        if HEALER_CLASS_IDS[class_id] then
                            local m_mana = 100
                            pcall(function() m_mana = member:get_mana_percentage() end)
                            if m_mana <= threshold then return true end
                        end
                    end
                end
            end
            return false
        end,
        execute = function(context)
            local spell = SPELLS.Innervate or { id = { 29166 }, name = "Innervate" }
            -- Prefer low-mana healer
            local HEALER_CLASS_IDS = { [2] = true, [5] = true, [7] = true, [11] = true }
            if NS.GetPartyMembers then
                local threshold = spec_kit.setting_number(context, "innervate_mana_pct", 30)
                for _, member in ipairs(NS.GetPartyMembers() or {}) do
                    if member then
                        local class_id = nil
                        pcall(function() class_id = member:get_class() end)
                        if HEALER_CLASS_IDS[class_id] then
                            local m_mana = 100
                            pcall(function() m_mana = member:get_mana_percentage() end)
                            if m_mana <= threshold then
                                return NS.try_cast(spell, member, "[DRUID] Innervate (Healer)")
                            end
                        end
                    end
                end
            end
            -- Fallback: self
            return NS.try_cast(spell, context.me, "[DRUID] Innervate (Self)", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- REBIRTH (Combat resurrection — dead party/raid member)
    -- ========================================================================
    {
        name = "Rebirth",
        priority = 1000,
        is_defensive = true,
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_rebirth", true) then return false end
            if not context.in_combat then return false end
            -- Must be in caster form (not Bear/Cat/Moonkin/Tree)
            local form_buffs = { 9634, 5487, 768, 24858, 33891 }
            for _, id in ipairs(form_buffs) do
                if NS.has_player_buff and NS.has_player_buff({ id }) then return false end
            end
            local spell = SPELLS.Rebirth or { id = { 26994, 20748, 20747, 20742, 20739, 20484 }, name = "Rebirth" }
            if not (NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })) then return false end
            -- Check for dead party/raid member
            if NS.GetPartyMembers then
                for _, member in ipairs(NS.GetPartyMembers() or {}) do
                    if member then
                        local alive = true
                        pcall(function() alive = member:is_alive() end)
                        if not alive then return true end
                    end
                end
            end
            return false
        end,
        execute = function(context)
            local spell = SPELLS.Rebirth or { id = { 26994, 20748, 20747, 20742, 20739, 20484 }, name = "Rebirth" }
            if NS.GetPartyMembers then
                for _, member in ipairs(NS.GetPartyMembers() or {}) do
                    if member then
                        local alive = true
                        pcall(function() alive = member:is_alive() end)
                        if not alive then
                            return NS.try_cast(spell, member, "[DRUID] Rebirth")
                        end
                    end
                end
            end
            return false
        end,
    },

    -- ============================================================================
    -- PvP CC Gate: placed at END of middleware so healthstones/pots/dispels still fire.
    -- Only gates spec-level AoE (Swipe, Hurricane).
    -- ============================================================================
    {
        name = "PvPCCGate",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_pvp_cc_gating", true) then return false end
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

    { name = "AutoConsumable", matches = function(context)
        if context.stance == STANCE_BEAR or context.stance == STANCE_CAT then return false end
        return consumable_manager.should_check(context)
    end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("druid", strategies)
return strategies
