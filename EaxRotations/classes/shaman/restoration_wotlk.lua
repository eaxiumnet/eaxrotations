-- restoration_wotlk.lua — Shaman Restoration rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Restoration shaman: Mana Tide Totem
--        (NS.spell_ready, 5-min CD), charge-aware Earth Shield refresh
--        (NS.buff_points Pattern 12), Riptide / Chain Heal / Healing Wave /
--        Lesser Healing Wave on the lowest friendly target, and Water Shield
--        mana sustain. Tidal Waves stacks tracked (WotLK resto mechanic).
-- WHEN:  combat with a valid friendly target (resolve_target -> context.lowest).
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")

local define = spec_kit.define_action

-- 2026-09-16 WotLK deficit-fit wave: per-rank HW/LHW ladders from the
-- heal-value module's WotLK families (era-less build_ladder -- already
-- era-distinct). Fail-closed: without the module the ladders stay nil and
-- every fitted lane below casts the exact legacy max-rank action. Live NS
-- lookup for the hook so tests can inject post-load (priest/paladin/druid
-- WotLK precedent).
local WOTLK_HW_RANKS, WOTLK_LHW_RANKS
local _HealValue = NS.HealValue
if not _HealValue then
    local _hv_ok, _mod = pcall(require, "shared/heal_value_sylvanas")
    if _hv_ok and type(_mod) == "table" then
        _HealValue = _mod
        NS.HealValue = NS.HealValue or _mod
    end
end
if type(_HealValue) == "table" and type(NS.spell_action) == "function" then
    WOTLK_HW_RANKS = _HealValue.build_ladder("shaman", "WotlkHealingWave",
        function(id) return NS.spell_action(id, "HealingWave") end)
    WOTLK_LHW_RANKS = _HealValue.build_ladder("shaman", "WotlkLesserHealingWave",
        function(id) return NS.spell_action(id, "LesserHealingWave") end)
end

local ACTION = {
    ManaTideTotem = define("ManaTideTotem", 16190, "ManaTideTotem"),
    EarthShield = define("EarthShield", 49284, "EarthShield"),
    Riptide = define("Riptide", 61301, "Riptide"),
    ChainHeal = define("ChainHeal", 55459, "ChainHeal"),
    HealingWave = define("HealingWave", 49273, "HealingWave"),
    LesserHealingWave = define("LesserHealingWave", 49276, "LesserHealingWave"),
    WaterShield = define("WaterShield", 52127, "WaterShield"),
    -- Guide emergency enabler (Icy-Veins WotLK resto priority #1; id
    -- Wowhead-verified 16188, 2 min CD, shares CD with Elemental Mastery).
    NaturesSwiftness = define("NaturesSwiftness", 16188, "NaturesSwiftness"),
    -- Guide-pass additions (2026-09-12): Cleanse Spirit 51886 (WotLK dispel
    -- — 1 poison / 1 disease / 1 curse, instant, 40y, Wowhead-verified) and
    -- Earthliving Weapon 51730 (the 30-min self imbue, 6% mana).
    CleanseSpirit = define("CleanseSpirit", 51886, "CleanseSpirit"),
    EarthlivingWeapon = define("EarthlivingWeapon", 51730, "EarthlivingWeapon"),
}

local RIPTIDE_BUFF = { 61301, 61300, 61299, 61295 }
local EARTH_SHIELD_BUFF = { 49284, 32594, 32593, 974 }
-- Single WotLK max rank only: the TBC-era lower ranks (33736/24398/23575) are
-- not bridge-known and would fail the WotLK ID audit; a level-80 resto never
-- sees them.
local WATER_SHIELD_BUFF = { 52127 }
local TIDAL_WAVES_BUFF = { 53390 }
-- Nature's Swiftness self-buff (aura id = spell id 16188, Wowhead). NS+HW
-- emergency pair mirrors the resto druid/paladin sibling idiom.
local NATURES_SWIFTNESS_BUFF = { 16188 }
-- Earthliving Weapon imbue aura (spell id = aura id, Wowhead).
local EARTHLIVING_BUFF = { 51730 }
local NATURES_SWIFTNESS_EXPECTED_CD = 120  -- 2 min (Wowhead)
local NS_OPTS = { skip_range = true, expected_cooldown = NATURES_SWIFTNESS_EXPECTED_CD }

local restoration_state = {
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    riptide_remains = 0,
    earth_shield_up = false,
    earth_shield_charges = 0,
    mana_tide_ready = false,
    party_injured_count = 0,
    lowest_hp = 100,
    water_shield_up = false,
    water_shield_ready = false,
    tidal_waves_stacks = 0,
    has_natures_swiftness = false,
    friendly_has_dispellable = false,
    earthliving_up = false,
}

-- Deficit-fit cast attempt over a WotLK rank ladder (2026-09-16 wave).
-- Live NS lookup so tests inject the hook post-load. Returns true when the
-- hook cast an action; nil when the fit is unavailable (no ladder / no hook)
-- so the caller falls back to the exact legacy max-rank cast. No explicit
-- deficit guard: the raw unit goes to the hook, whose legacy walk lands on
-- the ladder head -- the legacy max by construction (priest 2.28.0
-- precedent).
local function try_fit_cast(context, ladder, target, label)
    if type(ladder) ~= "table" or type(NS.cast_best_heal_rank) ~= "function" then return nil end
    local chosen, rank_label = NS.cast_best_heal_rank(ladder, target, context, label, { player_level = 80 })
    if chosen then return NS.try_cast(chosen, target, rank_label) == true end
    return nil
end

local function build_state(context)
    local state = spec_kit.safe_state(restoration_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    -- Heals target the lowest-HP friendly (DSL target="friendly" resolves to
    -- context.lowest.unit); the old code healed context.target, which can be
    -- an enemy.
    local friendly = context and context.lowest and context.lowest.unit
    local ft_hp = 100
    if friendly and friendly.get_health_percentage then
        local ok, v = pcall(friendly.get_health_percentage, friendly)
        if ok and type(v) == "number" then ft_hp = v end
    elseif context and context.lowest_hp then
        ft_hp = context.lowest_hp
    end
    state.target_hp = ft_hp
    state.lowest_hp = (context and context.lowest_hp) or ft_hp
    state.mana_pct = (context and context.mana_pct) or (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.riptide_remains = (friendly and NS.buff_remains and NS.buff_remains(friendly, RIPTIDE_BUFF)) or 0
    -- Earth Shield charge-aware refresh (Pattern 12): points[1] = charges left.
    local es_pts = friendly and NS.buff_points and NS.buff_points(friendly, EARTH_SHIELD_BUFF) or nil
    state.earth_shield_charges = (es_pts and es_pts[1]) or 0
    state.earth_shield_up = (friendly and NS.buff_up and NS.buff_up(friendly, EARTH_SHIELD_BUFF)) or false
    -- Mana Tide from the REAL cooldown API (production never sets the phantom
    -- context.mana_tide_ready flag the old build_state read).
    state.mana_tide_ready = (NS.spell_ready and NS.spell_ready(ACTION.ManaTideTotem, me, { skip_range = true, expected_cooldown = 300 })) or false
    -- Engine field name: main_sylvanas.lua provides context.party_injured_count
    -- (not the phantom context.injured_count the old code read — Chain Heal
    -- could never fire).
    state.party_injured_count = (context and context.party_injured_count) or 0
    state.water_shield_up = (me and NS.buff_up and NS.buff_up(me, WATER_SHIELD_BUFF)) or false
    state.water_shield_ready = (NS.spell_ready and NS.spell_ready(ACTION.WaterShield, me, { skip_range = true })) or false
    state.tidal_waves_stacks = (me and NS.buff_stacks and NS.buff_stacks(me, TIDAL_WAVES_BUFF)) or 0
    -- Nature's Swiftness self-buff (emergency pair enable state).
    state.has_natures_swiftness = (me and NS.buff_up and NS.buff_up(me, NATURES_SWIFTNESS_BUFF)) or false
    -- Dispel + imbue upkeep reads (real engine surfaces). The dispel scan
    -- covers the three types Cleanse Spirit removes; each check returns
    -- false when the engine has no dispel API (fail-open to no dispel).
    state.friendly_has_dispellable = false
    if friendly and type(NS.has_dispel_type_debuff) == "function" then
        state.friendly_has_dispellable = NS.has_dispel_type_debuff(friendly, "Poison")
            or NS.has_dispel_type_debuff(friendly, "Disease")
            or NS.has_dispel_type_debuff(friendly, "Curse")
    end
    state.earthliving_up = (me and NS.buff_up and NS.buff_up(me, EARTHLIVING_BUFF)) or false
    return state
end

local DSL_DEFS = {
    -- Guide priority (Icy-Veins WotLK resto): dispels outrank throughput
    -- heals — Cleanse Spirit the moment an ally carries a removable type.
    {
        name = "CleanseSpirit",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "friendly_has_dispellable", op = "truthy" },
            { type = "spell_ready", spell = ACTION.CleanseSpirit, target = "self" },
        },
        action = { type = "cast", spell = ACTION.CleanseSpirit, target = "friendly" },
    },
    {
        name = "ManaTideTotem",
        conditions = {
            { type = "state", field = "mana_tide_ready", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 30 },
        },
        action = { type = "cast", spell = ACTION.ManaTideTotem, target = "self" },
    },
    {
        name = "EarthShield",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not state.earth_shield_up then return true end
                local charges = state.earth_shield_charges or 0
                -- Refresh only when the shield is low on charges; fail closed
                -- (hold) when charges cannot be read.
                return charges > 0 and charges <= 1
            end },
        },
        action = { type = "cast", spell = ACTION.EarthShield, target = "friendly" },
    },
    {
        name = "Riptide",
        conditions = {
            { type = "state", field = "riptide_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Riptide, target = "friendly" },
    },
    {
        name = "ChainHeal",
        conditions = {
            { type = "state", field = "party_injured_count", op = ">=", value = 2 },
            { type = "state", field = "lowest_hp", op = "<", value = 85 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.ChainHeal, target = "friendly" },
    },
    {
        name = "LesserHealingWave",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 90 },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        -- 2026-09-16 WotLK deficit-fit: the fit changes WHICH LHW rank casts
        -- (overheal avoidance), never whether the lane fires -- the
        -- conditions above are untouched. Fail-closed to the legacy 49276.
        action = { type = "custom", fn = function(context, state)
            local target = context and context.lowest and context.lowest.unit or nil
            if not target then return false end
            if try_fit_cast(context, WOTLK_LHW_RANKS, target, "[RESTO] LesserHealingWave") then return true end
            return NS.try_cast(ACTION.LesserHealingWave, target, "[RESTO] LesserHealingWave") == true
        end },
    },
    {
        name = "HealingWave",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 70 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        -- 2026-09-16 WotLK deficit-fit: same shape as the LHW lane above
        -- (conditions untouched, legacy max-rank 49273 fallback). The
        -- NS+HealingWave lane below stays max-rank (instant-cast emergency
        -- identity) and Chain Heal stays a group-aggregate lane.
        action = { type = "custom", fn = function(context, state)
            local target = context and context.lowest and context.lowest.unit or nil
            if not target then return false end
            if try_fit_cast(context, WOTLK_HW_RANKS, target, "[RESTO] HealingWave") then return true end
            return NS.try_cast(ACTION.HealingWave, target, "[RESTO] HealingWave") == true
        end },
    },
    -- Tidal Waves exploitation (WotLK resto mechanic the header already
    -- tracks): with 2 TW stacks after Riptide/Crit, the BIG nuke is the fast
    -- one — HW (1.5s at 30% haste) beats LHW; also hard-prioritize LHW under
    -- TW when the target is very low. Guide: consume stacks, never cap them.
    {
        name = "TidalWavesHealingWave",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "tidal_waves_stacks", op = ">=", value = 2 },
            { type = "state", field = "target_hp", op = "<", value = 65 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        -- 2026-09-16 WotLK deficit-fit: this lane casts Healing Wave too, so
        -- it draws from the same HW ladder (the TW mechanic changes the cast
        -- SPEED, not the rank identity); same fail-closed 49273 fallback.
        action = { type = "custom", fn = function(context, state)
            local target = context and context.lowest and context.lowest.unit or nil
            if not target then return false end
            if try_fit_cast(context, WOTLK_HW_RANKS, target, "[RESTO] TidalWavesHealingWave") then return true end
            return NS.try_cast(ACTION.HealingWave, target, "[RESTO] TidalWavesHealingWave") == true
        end },
    },
    -- Water Shield mana sustain (WotLK resto mechanic): re-apply at low mana
    -- when the shield is down.
    {
        name = "WaterShield",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "water_shield_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = "<", value = 50 },
            { type = "state", field = "water_shield_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.WaterShield, target = "self" },
    },
    -- Guide emergency lanes (Icy-Veins WotLK resto priority #1; NS+HW pair
    -- mirrors the resto druid/paladin sibling idiom).
    -- Out-of-combat imbue upkeep: a resto shaman re-arms Earthliving Weapon
    -- whenever it is missing (30-min buff), never during combat heals.
    {
        name = "EarthlivingWeapon",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "earthliving_up", op = "falsy" },
            { type = "spell_ready", spell = ACTION.EarthlivingWeapon, target = "self" },
        },
        action = { type = "cast", spell = ACTION.EarthlivingWeapon, target = "self" },
    },
    {
        name = "NaturesSwiftness",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_hp", op = "<", value = 30 },
            { type = "state", field = "has_natures_swiftness", op = "falsy" },
            { type = "spell_ready", spell = ACTION.NaturesSwiftness, target = "self", opts = NS_OPTS },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.NaturesSwiftness, nil, "[RESTO] Nature's Swiftness", NS_OPTS) == true
        end },
    },
    {
        name = "NaturesSwiftnessHealingWave",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_hp", op = "<", value = 30 },
            { type = "state", field = "has_natures_swiftness", op = "truthy" },
            { type = "spell_ready", spell = ACTION.HealingWave, target = "self" },
        },
        action = { type = "cast", spell = ACTION.HealingWave, target = "friendly" },
    },
}

local strategies = {
    -- Emergency band first (guide priority #1: instant NS+HW saves), then
    -- mana cooldown, upkeep, AoE, and the TW-exploiting nuke before the
    -- slow HW base lane.
    { name = "NaturesSwiftness" },
    { name = "NaturesSwiftnessHealingWave" },
    { name = "CleanseSpirit" },
    { name = "ManaTideTotem" },
    { name = "EarthShield" },
    { name = "Riptide" },
    { name = "ChainHeal" },
    { name = "TidalWavesHealingWave" },
    { name = "HealingWave" },
    { name = "LesserHealingWave" },
    { name = "WaterShield" },
    { name = "EarthlivingWeapon" },
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
    NS.rotation_registry:register("restoration", strategies, { get_state = build_state })
end
if NS.log then NS.log("Shaman restoration rotation registered") end

return { strategies = strategies, build_state = build_state }
