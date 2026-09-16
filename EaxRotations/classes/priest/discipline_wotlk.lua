-- discipline_wotlk.lua — Priest Discipline rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Discipline priest.
-- WHEN:  combat with valid enemy target / friendly target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.
-- DECISION (W3.3): plain spec_kit.define_action with file-local WotLK rank
--         ladders — define_action_for_class would resolve through the TBC-capped
--         class table and silently shadow the WotLK max ranks (precedent:
--         classes/mage/fire_wotlk.lua:20). Penance/PoM are multi-rank trainer
--         ladders (max 53007 / 48113) so a single TBC-era ID can never resolve
--         at level 80; WotLK max-rank buff ids (48068/48065) are tracked for
--         literal aura matching.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")

local define = spec_kit.define_action

-- 2026-09-16 WotLK deficit-fit wave: per-rank FH/GH ladders from the
-- heal-value module's WotLK families (era-less build_ladder -- the wotlk
-- rows carry no era-divergent values, so an era arg would apply nothing).
-- Fail-closed: without the module the ladders stay nil and both lanes cast
-- the exact legacy max-rank actions below.
local WOTLK_FH_RANKS, WOTLK_GH_RANKS
local _HealValue = NS.HealValue
if not _HealValue then
    local _hv_ok, _mod = pcall(require, "shared/heal_value_sylvanas")
    if _hv_ok and type(_mod) == "table" then
        _HealValue = _mod
        NS.HealValue = NS.HealValue or _mod
    end
end
-- Lean embedders (standalone dofile suites) may stub NS without
-- spell_action; core_sylvanas always defines it before class modules load,
-- so the guard only ever skips the fit ladder there -- fail-closed either
-- way (both lanes fall back to the legacy max-rank casts).
if type(_HealValue) == "table" and type(NS.spell_action) == "function" then
    WOTLK_FH_RANKS = _HealValue.build_ladder("priest", "WotlkFlashHeal",
        function(id) return NS.spell_action(id, "FlashHeal") end)
    WOTLK_GH_RANKS = _HealValue.build_ladder("priest", "WotlkGreaterHeal",
        function(id) return NS.spell_action(id, "GreaterHeal") end)
end
local cast_best_heal_rank = NS.cast_best_heal_rank or function() return nil end

local ACTION = {
    PowerWordShield = define("PowerWordShield", { 48066, 48065, 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }, "PowerWordShield"),
    -- WotLK Penance is a 4-rank trainer ladder (47540 r1 -> 53005 r2 -> 53006
    -- r3 -> 53007 r4). First-known-wins resolution needs the full ladder: a
    -- single 47540 can never resolve for a max-level character (the trainer
    -- replaces lower ranks), which was the production never-lane this fixes.
    Penance = define("Penance", { 53007, 53006, 53005, 47540 }, "Penance"),
    -- WotLK Prayer of Mending: 33076 r1 -> 48112 r2 -> 48113 r3 (max). The
    -- pinned disc APL (tools/evidence/apl/disc_priest_wotlk.apl.json) casts
    -- 48113; a single 33076 is a TBC-era cap that never fires at 80.
    PrayerOfMending = define("PrayerofMending", { 48113, 48112, 33076 }, "PrayerofMending"),
    Renew = define("Renew", { 48068, 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }, "Renew"),
    -- Cooldown identity (wowsims APL action 1 'autocastOtherCooldowns' made
    -- concrete; ids Wowhead-verified). MassDispel 32375 stays in
    -- dispel_manager (magic_mass middleware owner) — not a rotation lane.
    PainSuppression = define("PainSuppression", 33206, "PainSuppression"),
    PowerInfusion = define("PowerInfusion", 10060, "PowerInfusion"),
    -- 2026-09-10 guide-gap fillers: the APL's direct-heal band the file
    -- lacked (after Renew, before PI under pressure). Ranks mirror the
    -- holy file's audit-clean ladders.
    GreaterHeal = define("GreaterHeal", { 48063, 25213, 25210, 25314, 10965, 10964, 10963, 2060 }, "GreaterHeal"),
    FlashHeal = define("FlashHeal", { 48071, 25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061 }, "FlashHeal"),
    -- 2026-09-11 guide-pass (sub-12 lane close-out): self-save + mana-return
    -- + self-buff upkeep mirroring holy_wotlk's audit-clean shapes.
    -- Desperate Prayer: racial self-save, talent spell so the ladder is
    -- TBC-capped at 25437 (no WotLK rank increases — same ladder the holy
    -- file pins; 25437 already VALID_RANK_ALIAS-pinned in the audit).
    DesperatePrayer = define("DesperatePrayer", { 25437, 19243, 19242, 19241, 19240, 19238, 19236, 13908 }, "DesperatePrayer"),
    -- Inner Focus 14751: single-rank talent (Wowhead-verified — no WotLK rank
    -- increases; bridge omits it, audit pin added this pass). Guide usage:
    -- lead the shield engine so the discounted cast is free (+25% crit).
    InnerFocus = define("InnerFocus", 14751, "InnerFocus"),
    -- Shadowfiend 34433: mana-return pet, already VALID_RANK_ALIAS-pinned
    -- from the shadow pass (single rank, unchanged since TBC). Same
    -- mana<60 band as shadow_wotlk's lane.
    Shadowfiend = define("Shadowfiend", 34433, "Shadowfiend"),
    -- Divine Spirit 48073: WotLK max rank r6 (+80 spirit), already
    -- VALID_RANK_ALIAS-pinned from the holy upkeep wave. OOC upkeep — no
    -- combat-only gate (spirit scales mana regen at every band).
    DivineSpirit = define("DivineSpirit", 48073, "DivineSpirit"),
}

local WEAKENED_SOUL_DEBUFF = { 6788 }
local RENEW_BUFF = { 48068, 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
local DIVINE_SPIRIT_BUFF = { 48073 }
local INNER_FOCUS_BUFF = { 14751 }

local discipline_state = {
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    weakened_soul_up = false,
    renew_remains = 0,
    player_hp = 100,
    has_divine_spirit = false,
    divine_spirit_ready = false,
    has_inner_focus = false,
    inner_focus_ready = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(discipline_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = (context and context.lowest and context.lowest.unit) or me
    -- target_hp: the LOWEST FRIENDLY unit's hp (healers score the lowest
    -- friendly as their target) — test-pinned in
    -- test_discipline_wotlk_dsl_priority.lua:160.
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.mana_pct = (context and context.mana_pct)
        or (me and me.mana_pct and me:mana_pct())
        or (me and me.get_mana_percentage and me:get_mana_percentage())
        or 100
    state.weakened_soul_up = (target and NS.debuff_up and NS.debuff_up(target, WEAKENED_SOUL_DEBUFF)) or false
    state.renew_remains = (target and NS.buff_remains and NS.buff_remains(target, RENEW_BUFF)) or 0
    -- 2026-09-11 guide-pass state (mirror holy_wotlk shapes):
    -- player_hp — the Desperate Prayer self-save band.
    state.player_hp = (context and (context.player_hp or context.hp))
        or (me and me.get_health_percentage and me:get_health_percentage())
        or 100
    -- Self-buff upkeep: buff down + spell ready gates.
    state.has_divine_spirit = (me and NS.buff_up and NS.buff_up(me, DIVINE_SPIRIT_BUFF)) or false
    state.divine_spirit_ready = NS.spell_ready and NS.spell_ready(ACTION.DivineSpirit, me, { skip_range = true }) or false
    state.has_inner_focus = (me and NS.buff_up and NS.buff_up(me, INNER_FOCUS_BUFF)) or false
    state.inner_focus_ready = NS.spell_ready and NS.spell_ready(ACTION.InnerFocus, me, { skip_range = true }) or false
    return state
end

local DSL_DEFS = {
    -- Tank/ally save (Wowhead: 40% damage reduction, 8s): the disc cooldown
    -- identity — hold it for the <= 30 emergency band.
    {
        name = "PainSuppression",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_hp", op = "<=", value = 30 },
            { type = "spell_ready", spell = ACTION.PainSuppression, target = "self" },
        },
        action = { type = "cast", spell = ACTION.PainSuppression, target = "friendly" },
    },
    {
        name = "PowerWordShield",
        conditions = {
            { type = "state", field = "weakened_soul_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.PowerWordShield, target = "friendly" },
    },
    -- 20% haste / -20% mana (15s) under healing pressure; the APL's
    -- autocastOtherCooldowns casts it on CD when damage is heavy.
    {
        name = "PowerInfusion",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_hp", op = "<=", value = 45 },
            { type = "spell_ready", spell = ACTION.PowerInfusion, target = "self" },
        },
        action = { type = "cast", spell = ACTION.PowerInfusion, target = "self" },
    },
    {
        name = "Penance",
        conditions = {},
        action = { type = "cast", spell = ACTION.Penance, target = "friendly" },
    },
    {
        name = "PrayerOfMending",
        conditions = {},
        action = { type = "cast", spell = ACTION.PrayerOfMending, target = "friendly" },
    },
    {
        name = "Renew",
        conditions = {
            { type = "state", field = "renew_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Renew, target = "friendly" },
    },
    -- Direct-heal fillers (guide band after Renew): Greater Heal for the
    -- big top-up, Flash Heal for the fast band; both mana-gated so the
    -- shield engine never starves itself.
    {
        name = "GreaterHeal",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 50 },
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        -- 2026-09-16 WotLK deficit-fit: the fit changes WHICH Greater Heal
        -- rank casts (overheal avoidance), never whether the lane fires --
        -- the conditions above are untouched. Fail-closed: without the
        -- module ladder or with the fit kill-switch off, the exact legacy
        -- cast (the 48063 max-rank action) runs.
        action = { type = "custom", fn = function(context, state)
            local target = context and context.lowest and context.lowest.unit or nil
            if not target then return false end
            if WOTLK_GH_RANKS then
                local chosen, rank_label = cast_best_heal_rank(WOTLK_GH_RANKS, target,
                    context, "[DISC] GreaterHeal", { player_level = 80 })
                if chosen then return NS.try_cast(chosen, target, rank_label) == true end
            end
            return NS.try_cast(ACTION.GreaterHeal, target, "[DISC] GreaterHeal") == true
        end },
    },
    {
        name = "FlashHeal",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 70 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        -- 2026-09-16 WotLK deficit-fit: same shape as the GreaterHeal lane
        -- above (conditions untouched, legacy max-rank 48071 fallback).
        action = { type = "custom", fn = function(context, state)
            local target = context and context.lowest and context.lowest.unit or nil
            if not target then return false end
            if WOTLK_FH_RANKS then
                local chosen, rank_label = cast_best_heal_rank(WOTLK_FH_RANKS, target,
                    context, "[DISC] FlashHeal", { player_level = 80 })
                if chosen then return NS.try_cast(chosen, target, rank_label) == true end
            end
            return NS.try_cast(ACTION.FlashHeal, target, "[DISC] FlashHeal") == true
        end },
    },
    -- 2026-09-11 guide-pass lanes: self-save outranks the heal band but sits
    -- under the group-save (PainSuppression); Inner Focus leads the shield
    -- engine (the free +25%-crit cast the guides save for PWS/GHeal); the
    -- mana-return pet and OOC spirit upkeep mirror holy/shadow shapes.
    {
        name = "DesperatePrayer",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "player_hp", op = "<=", value = 30 },
            { type = "spell_ready", spell = ACTION.DesperatePrayer, target = "self" },
        },
        action = { type = "cast", spell = ACTION.DesperatePrayer, target = "self" },
    },
    {
        name = "InnerFocus",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "has_inner_focus", op = "falsy" },
            { type = "state", field = "inner_focus_ready", op = "truthy" },
            { type = "state", field = "target_hp", op = "<", value = 70 },
        },
        action = { type = "cast", spell = ACTION.InnerFocus, target = "self" },
    },
    {
        name = "Shadowfiend",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 60 },
        },
        action = { type = "cast", spell = ACTION.Shadowfiend, target = "target" },
    },
    {
        name = "DivineSpirit",
        conditions = {
            { type = "state", field = "has_divine_spirit", op = "falsy" },
            { type = "state", field = "divine_spirit_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.DivineSpirit, target = "self" },
    },
}

local strategies = {
    -- Save first (emergency band outranks the shield-spam engine), then the
    -- pinned APL order PWS -> Penance -> PoM -> Renew, then PI under pressure.
    { name = "PainSuppression" },
    { name = "DesperatePrayer" },
    { name = "PowerWordShield" },
    { name = "InnerFocus" },
    { name = "Penance" },
    { name = "PrayerOfMending" },
    { name = "Renew" },
    { name = "GreaterHeal" },
    { name = "FlashHeal" },
    { name = "Shadowfiend" },
    { name = "DivineSpirit" },
    { name = "PowerInfusion" },
}

for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("discipline", strategies, { get_state = build_state })
end
if NS.log then NS.log("Priest discipline rotation registered") end

return { strategies = strategies, build_state = build_state }
