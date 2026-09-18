-- holy_wotlk.lua — Paladin Holy rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Holy paladin: Beacon of Light on a stable
--          tank/self target, Sacred Shield self-cast, then Holy Shock / Holy
--          Light / Flash of Light on the lowest-HP friendly.
-- WHEN:  combat with valid friendly target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); Beacon is checked
--         on the DEDICATED beacon target (never the lowest-HP member — bouncing
--         the Beacon churns it off the tank); Sacred Shield is a self-only buff
--         in 3.3.5 (self-check + self-cast); declarative DSL strategies; no
--         on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")

-- Plain define_action (NOT define_action_for_class): the WotLK client loads the
-- TBC class_sylvanas.lua into NS.<Class>Spells, so the class-first resolver would
-- shadow these WotLK rank ladders with TBC-era rank lists.
local define = spec_kit.define_action

-- 2026-09-16 WotLK deficit-fit wave: per-rank HL/FoL ladders from the
-- heal-value module's WotLK families (era-less build_ladder -- the families
-- are already era-distinct). Fail-closed: without the module the ladders
-- stay nil and both lanes cast the exact legacy max-rank actions below.
-- Lean embedders (standalone dofile suites) may stub NS without
-- spell_action; core_sylvanas always defines it before class modules load,
-- so the guard only ever skips the fit ladder there -- fail-closed either
-- way (both lanes fall back to the legacy max-rank casts).
local WOTLK_HL_RANKS, WOTLK_FOL_RANKS
local _HealValue = NS.HealValue
if not _HealValue then
    local _hv_ok, _mod = pcall(require, "shared/heal_value_sylvanas")
    if _hv_ok and type(_mod) == "table" then
        _HealValue = _mod
        NS.HealValue = NS.HealValue or _mod
    end
end
if type(_HealValue) == "table" and type(NS.spell_action) == "function" then
    WOTLK_HL_RANKS = _HealValue.build_ladder("paladin", "WotlkHolyLight",
        function(id) return NS.spell_action(id, "HolyLight") end, 1.12)
    WOTLK_FOL_RANKS = _HealValue.build_ladder("paladin", "WotlkFlashOfLight",
        function(id) return NS.spell_action(id, "FlashOfLight") end, 1.12)
end

local ACTION = {
    BeaconOfLight = define("BeaconOfLight", 53563, "BeaconOfLight"),
    -- 33071/33070 removed 2026-09-13 (name-agreement assertion): both are
    -- bridge-valid but NOT Holy Shock -- wowhead WotLK Classic calls them
    -- "Shadow Prison" and "Cloud of Corruption" (server-side dummy auras),
    -- so a paladin who knew them cast a dummy instead of the heal.
    HolyShock = define("HolyShock", { 48821, 33074, 33073, 33072, 20473 }, "HolyShock"),
    -- FoL/HL ranks verified lexxer (removed FoL/HL mixups 1022-1025 HoP, 19993 invalid, HL IDs that are FoL).
    FlashOfLight = define("FlashOfLight", { 48785, 27137, 19943, 19942, 19941, 19940, 19939, 19750 }, "FlashOfLight"),
    HolyLight = define("HolyLight", { 48782, 27136, 27135, 25292, 10329, 10328, 3472, 1026, 647, 639, 635 }, "HolyLight"),
    SacredShield = define("SacredShield", 53601, "SacredShield"),
    -- Mana-game cooldowns (Icy-Veins WotLK holy priority; ids Wowhead-verified).
    -- DivinePlea 54428 already lives in retribution_wotlk.lua (audit-clean).
    DivinePlea = define("DivinePlea", 54428, "DivinePlea"),
    -- 2026-09-10 guide-gap save: Lay on Hands is the mana-free full heal
    -- (Wowhead-verified era-shared id 633; the TBC bridge carries it, so
    -- the sylvanas audit already accepts it). Reserved for the <= 20
    -- emergency band - a regular heal arrives too late below a dying tank.
    LayOnHands = define("LayOnHands", 633, "LayOnHands"),
    DivineFavor = define("DivineFavor", 20216, "DivineFavor"),
    -- JoP is the WotLK talent (54152 r5/54154 r1/54155 r2, 15% haste).
    Judgement = define("Judgement", { 20271, 53407, 53408 }, "Judgement"),
    SealOfWisdom = define("SealOfWisdom", { 20216, 20166 }, "SealOfWisdom"),
}

local BEACON_OF_LIGHT_BUFF = { 53563 }
-- Sacred Shield player buff is 53601 only (lexxer wotlk). 53602/603/604 are unrelated.
local SACRED_SHIELD_BUFF = { 53601 }
-- Seal of Wisdom self-aura: seal id = spell id family (20216 r1/20166 r1;
-- max-rank-first, same table as the ACTION). Judgement of Wisdom's debuff on
-- the target is NOT gated on a fixed id — judging on cooldown IS max JoW
-- uptime, and the era-correct effect id varies by seal cast; the debuff read
-- path stays real (spell_ready) instead of pinning a phantom id.
local SEAL_OF_WISDOM_BUFF = { 20216, 20166 }

local holy_state = {
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    beacon_up = false,
    sacred_shield_up = false,
    beacon_target = nil,
    seal_wisdom_up = false,
    judgement_ready = false,
}

-- Dedicated Beacon target: first party/group member flagged as tank, else self.
-- Keeps the Beacon on a STABLE target instead of following the lowest-HP member
-- (which churns the buff and starves the tank of its 50% heal copy).
local function pick_beacon_target(context)
    local members = (context and (context.party_members or context.group_members)) or nil
    if type(members) == "table" then
        for i = 1, #members do
            local member = members[i]
            if member and type(member.get_group_role) == "function" then
                local ok, role = pcall(member.get_group_role, member)
                if ok and role == "tank" then return member end
            end
        end
    end
    return NS.me or (NS.GetPlayer and NS.GetPlayer())
end

local function build_state(context)
    local state = spec_kit.safe_state(holy_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = (context and context.lowest and context.lowest.unit) or me
    local beacon_target = pick_beacon_target(context)
    -- context.mana_pct is dispatcher-set (main_sylvanas.lua:795); me:mana_pct()
    -- is the IZI SDK unit method. me:get_mana_percentage() is mock-only (W3.4).
    state.mana_pct = (context and context.mana_pct)
        or (me and me.mana_pct and me:mana_pct())
        or (NS.unit_mana_pct and NS.unit_mana_pct(me))
        or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.beacon_target = beacon_target
    -- Beacon checked on the DEDICATED tank/self target (never the lowest-HP
    -- member), so the buff reads true while the tank is alive and healthy.
    state.beacon_up = (beacon_target and NS.buff_up and NS.buff_up(beacon_target, BEACON_OF_LIGHT_BUFF)) or false
    -- Sacred Shield is a SELF-ONLY buff in 3.3.5 — checked and cast on self,
    -- never on the lowest-HP ally (the old code bounced it between members).
    state.sacred_shield_up = (me and NS.buff_up and NS.buff_up(me, SACRED_SHIELD_BUFF)) or false
    -- Mana-game reads (guide: judge on CD, keep SoW up; engine target = the
    -- hostile combat target, same lane the TBC sibling judges).
    state.seal_wisdom_up = (me and NS.buff_up and NS.buff_up(me, SEAL_OF_WISDOM_BUFF)) or false
    state.judgement_ready = (NS.spell_ready and NS.spell_ready(ACTION.Judgement, target)) or false
    return state
end

local DSL_DEFS = {
    {
        name = "BeaconOfLight",
        conditions = {
            { type = "state", field = "beacon_up", op = "falsy" },
        },
        -- Cast on the dedicated beacon target (tank or self), NOT the
        -- lowest-HP member — the old "friendly" resolution bounced the
        -- Beacon every tick and never settled on the tank.
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.BeaconOfLight, state.beacon_target, "[HOLY] BeaconOfLight") == true
        end },
    },
    {
        name = "SacredShield",
        conditions = {
            { type = "state", field = "sacred_shield_up", op = "falsy" },
        },
        -- Self-cast (nil target): Sacred Shield only ever lands on the paladin.
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.SacredShield, nil, "[HOLY] SacredShield") == true
        end },
    },
    {
        name = "HolyShock",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 80 },
        },
        action = { type = "cast", spell = ACTION.HolyShock, target = "friendly" },
    },
    {
        name = "HolyLight",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 50 },
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        -- 2026-09-16 WotLK deficit-fit: the fit changes WHICH Holy Light
        -- rank casts (overheal avoidance; WotLK ranks cost %-of-base-mana,
        -- so no mana is saved), never whether the lane fires -- the
        -- conditions above are untouched. Live NS lookup so tests inject
        -- post-load. Fail-closed: without the module ladder or the hook,
        -- the exact legacy cast (the 48782 max-rank action) runs. No
        -- explicit deficit guard: the lane passes the raw unit, so the
        -- deficit resolves inside the hook (unit getters); an unreadable
        -- deficit takes the hook's legacy walk to the ladder head, which
        -- IS the legacy max by construction (priest holy/discipline
        -- precedent, 2.28.0).
        action = { type = "custom", fn = function(context, state)
            local target = context and context.lowest and context.lowest.unit or nil
            if not target then return false end
            if type(WOTLK_HL_RANKS) == "table" and type(NS.cast_best_heal_rank) == "function" then
                local chosen, rank_label = NS.cast_best_heal_rank(WOTLK_HL_RANKS, target,
                    context, "[HOLY] HolyLight", { player_level = 80 })
                if chosen then return NS.try_cast(chosen, target, rank_label) == true end
            end
            return NS.try_cast(ACTION.HolyLight, target, "[HOLY] HolyLight") == true
        end },
    },
    {
        name = "FlashOfLight",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 70 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        -- 2026-09-16 WotLK deficit-fit: same shape as the HolyLight lane
        -- above (conditions untouched, legacy max-rank 48785 fallback).
        -- HolyShock stays max-rank (instant-cast emergency identity) and
        -- LayOnHands stays a cooldown save -- neither is rank-fitted.
        action = { type = "custom", fn = function(context, state)
            local target = context and context.lowest and context.lowest.unit or nil
            if not target then return false end
            if type(WOTLK_FOL_RANKS) == "table" and type(NS.cast_best_heal_rank) == "function" then
                local chosen, rank_label = NS.cast_best_heal_rank(WOTLK_FOL_RANKS, target,
                    context, "[HOLY] FlashOfLight", { player_level = 80 })
                if chosen then return NS.try_cast(chosen, target, rank_label) == true end
            end
            return NS.try_cast(ACTION.FlashOfLight, target, "[HOLY] FlashOfLight") == true
        end },
    },
    -- Mana-game lanes (Icy-Veins WotLK holy priority; TBC sibling
    -- SealOfWisdomLowMana / DivineFavorHolyLightCombo idiom):
    {
        name = "SealOfWisdom",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "seal_wisdom_up", op = "falsy" },
            { type = "spell_ready", spell = ACTION.SealOfWisdom, target = "self" },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.SealOfWisdom, nil, "[HOLY] Seal of Wisdom upkeep") == true
        end },
    },
    {
        name = "JudgementOfWisdom",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<=", value = 90 },
            { type = "state", field = "judgement_ready", op = "truthy" },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.Judgement, context.target, "[HOLY] Judgement of Wisdom") == true
        end },
    },
    {
        name = "DivineFavorHolyLight",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_hp", op = "<", value = 75 },
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
            { type = "spell_ready", spell = ACTION.DivineFavor, target = "self" },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.DivineFavor, nil, "[HOLY] Divine Favor before Holy Light") == true
        end },
    },
    {
        name = "DivinePlea",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<=", value = 50 },
            { type = "spell_ready", spell = ACTION.DivinePlea, target = "self" },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.DivinePlea, nil, "[HOLY] Divine Plea mana return") == true
        end },
    },
    -- Save lane: the last-resort full heal, cast on the DEDICATED beacon
    -- target (tank or self) - the same stable-target idiom Beacon uses;
    -- the <= 20 band is where cast-time heals can no longer land in time.
    {
        name = "LayOnHands",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_hp", op = "<=", value = 20 },
            { type = "spell_ready", spell = ACTION.LayOnHands, target = "self" },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.LayOnHands, state.beacon_target, "[HOLY] Lay on Hands save") == true
        end },
    },
}

local strategies = {
    -- Save first (the <= 20 emergency band outranks every upkeep lane),
    -- then the mana-game band (guide: SoW uptime + judge-on-CD IS the HPS
    -- engine; Divine Favor buffs the next big Holy Light).
    { name = "LayOnHands" },
    -- engine; Divine Favor buffs the next big Holy Light).
    { name = "SealOfWisdom" },
    { name = "JudgementOfWisdom" },
    { name = "DivineFavorHolyLight" },
    { name = "DivinePlea" },
    { name = "BeaconOfLight" },
    { name = "SacredShield" },
    { name = "HolyShock" },
    { name = "HolyLight" },
    { name = "FlashOfLight" },
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
if NS.log then NS.log("Paladin holy rotation registered") end

return { strategies = strategies, build_state = build_state }
