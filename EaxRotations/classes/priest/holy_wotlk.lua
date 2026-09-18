-- holy_wotlk.lua — Priest Holy rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Holy priest.
-- WHEN:  combat with valid friendly target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.
-- DECISION (W3.3): plain spec_kit.define_action with file-local WotLK rank
--         ladders (define_action_for_class resolves through the TBC-capped
--         class table — precedent classes/mage/fire_wotlk.lua:20). PoM is a
--         3-rank WotLK trainer ladder (max 48113 per the pinned holy APL), so
--         the old single 33076 could never fire at 80. CircleOfHealing sits
--         exactly where the pinned holy APL evaluates it (GreaterHeal ->
--         CircleOfHealing -> Renew -> PrayerOfMending) and gates on the engine
--         context.party_injured_count (2+ injured) — the parse-critical raid
--         heal the file previously lacked.

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
    Renew = define("Renew", { 48068, 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }, "Renew"),
    -- WotLK Prayer of Mending: 33076 r1 -> 48112 r2 -> 48113 r3 (max).
    PrayerOfMending = define("PrayerofMending", { 48113, 48112, 33076 }, "PrayerofMending"),
    FlashHeal = define("FlashHeal", { 48071, 25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061 }, "FlashHeal"),
    GreaterHeal = define("GreaterHeal", { 48063, 25213, 25210, 25314, 10965, 10964, 10963, 2060 }, "GreaterHeal"),
    GuardianSpirit = define("GuardianSpirit", 47788, "GuardianSpirit"),
    -- 2026-09-09 guide-gap lanes (the deep-rate's last two holy omissions).
    -- Desperate Prayer: racial self-save, talent spell so the ladder is TBC-capped
    -- at 25437 (no WotLK rank increases — same ladder holy_sylvanas pins).
    DesperatePrayer = define("DesperatePrayer", { 25437, 19243, 19242, 19241, 19240, 19238, 19236, 13908 }, "DesperatePrayer"),
    -- Lightwell: full ladder 7001 r1 .. 28275 r4 (TBC, bridge-omitted) ->
    -- 48086 r5 -> 48087 r6 max (Wowhead-verified: 48087 = 4620 heal). The
    -- 48084/48085 ids are the Lightwell Renew buffs, not casts — excluded.
    Lightwell = define("Lightwell", { 48087, 48086, 28275, 27871, 27870, 724 }, "Lightwell"),
    -- Circle of Healing: full WotLK trainer ladder 34861 r1 .. 34866 r6 (TBC
    -- era, bridge-omitted, audit-pinned) -> 48088 r7 -> 48089 r8 max (pinned
    -- via the holy APL fixture id 48089).
    CircleOfHealing = define("CircleofHealing", { 48089, 48088, 34866, 34865, 34864, 34863, 34862, 34861 }, "CircleofHealing"),
    -- 2026-09-10 guide-gap raid cooldowns (the deep-rate's last hymn omissions).
    -- Divine Hymn 64901 / Hymn of Hope 64904 are SINGLE-RANK WotLK spells
    -- (Wowhead-verified; 64902/64903 are unrelated ids — redirects confirmed).
    -- Bridge-omitted, so the WotLK audit pins them as alias ids.
    DivineHymn = define("DivineHymn", 64901, "DivineHymn"),
    HymnOfHope = define("HymnOfHope", 64904, "HymnOfHope"),
    -- 2026-09-10 guide-pass self-upkeep (mirror holy_sylvanas/discipline):
    -- Divine Spirit WotLK max 48073 r6 (+80 spirit; single rank — the TBC
    -- ladder ends at 70, so the WotLK file pins the one verified id, matching
    -- the Maim/Pyroblast single-rank precedent); Inner Fire WotLK max 48168 r9
    -- (+2440 armor/+120 SP; TBC ladder bridge/audit-covered).
    DivineSpirit = define("DivineSpirit", 48073, "DivineSpirit"),
    InnerFire = define("InnerFire", { 48168, 25431, 10952, 10951, 1006, 602, 7128, 588 }, "InnerFire"),
}

local RENEW_BUFF = { 48068, 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
local GUARDIAN_SPIRIT_BUFF = { 47788 }
local DIVINE_SPIRIT_BUFF = { 48073 }
local INNER_FIRE_BUFF = { 48168, 25431, 10952, 10951, 1006, 602, 7128, 588 }

local holy_state = {
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    renew_remains = 0,
    guardian_spirit_up = false,
    has_divine_spirit = false,
    divine_spirit_ready = false,
    has_inner_fire = false,
    inner_fire_ready = false,
    injured_count = 0,
    lowest_hp = 100,
    player_hp = 100,
}

local function build_state(context)
    local state = spec_kit.safe_state(holy_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = (context and context.lowest and context.lowest.unit) or me
    state.mana_pct = (context and context.mana_pct)
        or (me and NS.mana_pct and NS.mana_pct(me))
        or (me and me.get_mana_percentage and me:get_mana_percentage())
        or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.renew_remains = (target and NS.buff_remains and NS.buff_remains(target, RENEW_BUFF)) or 0
    state.guardian_spirit_up = (target and NS.buff_up and NS.buff_up(target, GUARDIAN_SPIRIT_BUFF)) or false
    -- Engine field (main_sylvanas.lua): number of party members below the
    -- injured threshold. nil-safe default 0 keeps the CoH lane inert solo.
    state.injured_count = (context and context.party_injured_count) or 0
    state.lowest_hp = (context and context.lowest_hp) or state.target_hp
    -- Self-buff upkeep (mirror holy_sylvanas): buff down + spell ready gates.
    state.has_divine_spirit = (me and NS.buff_up and NS.buff_up(me, DIVINE_SPIRIT_BUFF)) or false
    state.divine_spirit_ready = NS.spell_ready and NS.spell_ready(ACTION.DivineSpirit, me, { skip_range = true }) or false
    state.has_inner_fire = (me and NS.buff_up and NS.buff_up(me, INNER_FIRE_BUFF)) or false
    state.inner_fire_ready = NS.spell_ready and NS.spell_ready(ACTION.InnerFire, me, { skip_range = true }) or false
    -- Player's own hp (engine alias of context.hp, main_sylvanas.lua) — the
    -- Desperate Prayer self-save band.
    state.player_hp = (context and (context.player_hp or context.hp))
        or (me and me.get_health_percentage and me:get_health_percentage())
        or 100
    return state
end

-- Order note (2026-08-10): GreaterHeal sits ABOVE Renew/PrayerOfMending to match
-- the wowsims healing-priest APL evaluation order (ui/healing_priest/apls/holy.apl.json:
-- GreaterHeal -> CircleOfHealing -> Renew -> PrayerOfMending). The prior order had
-- Renew/PoM above GreaterHeal — a genuine divergence from the sim, fixed as a pure
-- order move (no matcher-logic change) when the healer pins were wired. GuardianSpirit
-- stays the emergency top; FlashHeal is our extra below (both absent from the sim APL).
-- W3.3: CircleOfHealing added at its exact APL position (index 3, GreaterHeal ->
-- CoH -> Renew -> PoM) gated on 2+ injured party members (engine
-- context.party_injured_count) — the previously-missing parse-critical raid heal.
    -- 2026-09-09 guide-gap lanes: DesperatePrayer is the self-save (own hp
    -- band, above target triage — you cannot heal anyone while dead);
    -- Lightwell sits after the spot-heal emergency band and before CoH (TBC
    -- sibling idiom: sustained raid pressure, 3+ injured, not a spike response).
    local DSL_DEFS = {
    {
        name = "GuardianSpirit",
        conditions = {
            { type = "state", field = "guardian_spirit_up", op = "falsy" },
            { type = "state", field = "target_hp", op = "<", value = 30 },
        },
        action = { type = "cast", spell = ACTION.GuardianSpirit, target = "friendly" },
    },
    {
        name = "DesperatePrayer",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "player_hp", op = "<=", value = 30 },
            { type = "spell_ready", spell = ACTION.DesperatePrayer, target = "self" },
        },
        action = { type = "cast", spell = ACTION.DesperatePrayer, target = "self" },
    },
    -- Hymns sit with the emergency band (after the self-save, before target
    -- triage): Divine Hymn is the party burst channel (Tranquility idiom:
    -- 3+ injured, lowest < 60), Hymn of Hope the mana-return channel —
    -- casting it while wounded wastes the heal half.
    {
        name = "DivineHymn",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "injured_count", op = ">=", value = 3 },
            { type = "state", field = "lowest_hp", op = "<", value = 60 },
            { type = "spell_ready", spell = ACTION.DivineHymn, target = "self" },
        },
        action = { type = "custom", fn = function(context, state)
            -- Channeled, self-centered party burst (nil target = self idiom).
            return NS.try_cast(ACTION.DivineHymn, nil, "[HOLY] Divine Hymn party burst") == true
        end },
    },
    {
        name = "HymnOfHope",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 40 },
            { type = "spell_ready", spell = ACTION.HymnOfHope, target = "self" },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.HymnOfHope, nil, "[HOLY] Hymn of Hope mana return") == true
        end },
    },
    {
        name = "GreaterHeal",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 50 },
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        -- 2026-09-16 WotLK deficit-fit: the fit changes WHICH Greater Heal
        -- rank casts (overheal avoidance; WotLK ranks cost %-of-base-mana,
        -- so no mana is saved), never whether the lane fires -- the
        -- conditions above are untouched. Fail-closed: without the module
        -- ladder or with the fit kill-switch off, the exact legacy cast
        -- (the 48063 max-rank action) runs.
        action = { type = "custom", fn = function(context, state)
            local target = context and context.lowest and context.lowest.unit or nil
            if not target then return false end
            if WOTLK_GH_RANKS then
                local chosen, rank_label = cast_best_heal_rank(WOTLK_GH_RANKS, target,
                    context, "[HOLY] GreaterHeal", { player_level = 80 })
                if chosen then return NS.try_cast(chosen, target, rank_label) == true end
            end
            return NS.try_cast(ACTION.GreaterHeal, target, "[HOLY] GreaterHeal") == true
        end },
    },
    {
        name = "Lightwell",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "injured_count", op = ">=", value = 3 },
            { type = "spell_ready", spell = ACTION.Lightwell, target = "self" },
        },
        action = { type = "cast", spell = ACTION.Lightwell, target = "self" },
    },
    {
        name = "CircleOfHealing",
        conditions = {
            { type = "state", field = "injured_count", op = ">=", value = 2 },
            { type = "state", field = "lowest_hp", op = "<", value = 85 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.CircleOfHealing, target = "friendly" },
    },
    {
        name = "Renew",
        conditions = {
            { type = "state", field = "renew_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Renew, target = "friendly" },
    },
    {
        name = "PrayerOfMending",
        conditions = {},
        action = { type = "cast", spell = ACTION.PrayerOfMending, target = "friendly" },
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
                    context, "[HOLY] FlashHeal", { player_level = 80 })
                if chosen then return NS.try_cast(chosen, target, rank_label) == true end
            end
            return NS.try_cast(ACTION.FlashHeal, target, "[HOLY] FlashHeal") == true
        end },
    },
    -- 2026-09-10 guide-pass self-upkeep lanes: cast at the buff-maintenance
    -- position (OOC or in combat — Inner Fire charges are the panic argument;
    -- guides keep both up at all times, no combat-only gate).
    {
        name = "DivineSpirit",
        conditions = {
            { type = "state", field = "has_divine_spirit", op = "falsy" },
            { type = "state", field = "divine_spirit_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.DivineSpirit, target = "self" },
    },
    {
        name = "InnerFire",
        conditions = {
            { type = "state", field = "has_inner_fire", op = "falsy" },
            { type = "state", field = "inner_fire_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.InnerFire, target = "self" },
    },
    }

local strategies = {
    { name = "GuardianSpirit" },
    { name = "DesperatePrayer" },
    { name = "DivineHymn" },
    { name = "HymnOfHope" },
    { name = "DivineSpirit" },
    { name = "InnerFire" },
    { name = "GreaterHeal" },
    { name = "Lightwell" },
    { name = "CircleOfHealing" },
    { name = "Renew" },
    { name = "PrayerOfMending" },
    { name = "FlashHeal" },
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
    NS.rotation_registry:register("holy", strategies, { get_state = build_state })
end
if NS.log then NS.log("Priest holy rotation registered") end

return { strategies = strategies, build_state = build_state }
