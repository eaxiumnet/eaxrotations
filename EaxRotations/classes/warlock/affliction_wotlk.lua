-- affliction_wotlk.lua — Warlock Affliction rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Affliction warlock.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")

-- WotLK file-local rank ladders are authoritative: plain define_action (not
-- define_action_for_class) so the TBC-era NS.WarlockSpells table can never
-- shadow the WotLK max-rank ids (Corruption 47813 etc.) — see fire_wotlk.lua.
local define = spec_kit.define_action

-- Drain Soul is a clip-managed channel (2026-09-12): the wowsims affliction
-- APL channels it in execute and interrupts it (interruptIf: const True) so a
-- DoT that needs refreshing wins the GCD. Declared in the register call's
-- channel_clip_ids; the DoT lanes below carry skip_casting so evaluate_cast
-- lets the replacement through mid-channel.
local DRAIN_SOUL_IDS = { 47855, 27217, 11675, 8289, 8288, 1120 }

local ACTION = {
    UnstableAffliction = define("UnstableAffliction", { 47843, 30405, 30404, 30108 }, "UnstableAffliction"),
    Haunt = define("Haunt", { 59164, 48181 }, "Haunt"),
    Corruption = define("Corruption", { 47813, 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, "Corruption"),
    CurseOfAgony = define("CurseOfAgony", { 47864, 27218, 11713, 11712, 11711, 6217, 1014, 980 }, "CurseOfAgony"),
    SeedOfCorruption = define("SeedOfCorruption", { 47836, 27243 }, "SeedOfCorruption"),
    DrainSoul = define("DrainSoul", DRAIN_SOUL_IDS, "DrainSoul"),
    ShadowBolt = define("ShadowBolt", { 47809, 27209, 25307, 11661, 11660, 11659, 7641, 1106, 1088, 705, 695, 686 }, "ShadowBolt"),
    -- 2026-09-12 guide pass (Wowhead WotLK-verified): Curse of Doom 47867
    -- (the 1min boss curse the wowsims affliction/demo fixtures cast when
    -- remainingTime > 60s), Summon Infernal 1122 (10-min burst guardian)
    -- and Drain Life 47857 (WotLK max rank, sustain band).
    CurseOfDoom = define("CurseOfDoom", 47867, "CurseOfDoom"),
    SummonInfernal = define("SummonInfernal", 1122, "SummonInfernal"),
    DrainLife = define("DrainLife", 47857, "DrainLife"),
    LifeTap = define("LifeTap", { 57946, 27222, 11689, 11688, 11687, 1456, 1455, 1454 }, "LifeTap"),
}

-- WotLK max-rank ids FIRST (literal id matching — the client applies the
-- max-rank aura; without 47843/47813/47864 the DoT-remains reads are always 0
-- and every DoT is re-cast every GCD).
local UNSTABLE_AFFLICTION_DEBUFF = { 47843, 30405, 30404, 30108 }
local CORRUPTION_DEBUFF = { 47813, 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local CURSE_OF_AGONY_DEBUFF = { 47864, 27218, 11713, 11712, 11711, 6217, 1014, 980 }
local HAUNT_DEBUFF = { 59164, 48181 }
local CURSE_OF_DOOM_DEBUFF = { 47867 }
-- Nightfall proc (WotLK talent): Corruption/Drain Life ticks roll Shadow
-- Trance (17941, 10s), which makes the NEXT Shadow Bolt instant. The sim
-- models it through the aura rather than a separate cast action.
local SHADOW_TRANCE_BUFF = { 17941 }

local affliction_state = {
    target_hp = 100,
    hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    unstable_remains = 0,
    haunt_remains = 0,
    haunt_cd = 0,
    corruption_remains = 0,
    agony_remains = 0,
    cod_remains = 0,
    target_is_boss = false,
    shadow_trance_up = false,
    infernal_ready = false,
}

-- Cooldown reads via the real API (NS.cooldown_remains / get_spell_cooldown,
-- both 0 when unknown) — never the mock-only action:cooldown_remaining().
local function cd_remaining(action)
    if NS.cooldown_remains then
        local v = NS.cooldown_remains(action)
        if type(v) == "number" then return v end
    end
    if NS.get_spell_cooldown then
        local v = NS.get_spell_cooldown(action)
        if type(v) == "number" then return v end
    end
    return 0
end

local function build_state(context)
    local state = spec_kit.safe_state(affliction_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    -- Engine-populated context fields first (production API); unit-method
    -- reads kept only as fallback for harnesses without a context.
    state.mana_pct = (context and context.mana_pct) or (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.hp = (context and context.hp) or (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp = (context and context.target_hp) or (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.unstable_remains = (target and NS.debuff_remains and NS.debuff_remains(target, UNSTABLE_AFFLICTION_DEBUFF)) or 0
    state.haunt_remains = (target and NS.debuff_remains and NS.debuff_remains(target, HAUNT_DEBUFF)) or 0
    state.corruption_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CORRUPTION_DEBUFF)) or 0
    state.agony_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_AGONY_DEBUFF)) or 0
    state.cod_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_DOOM_DEBUFF)) or 0
    state.target_is_boss = (context and context.target_is_boss) == true
    state.shadow_trance_up = (me and NS.buff_up and NS.buff_up(me, SHADOW_TRANCE_BUFF)) or false
    state.infernal_ready = cd_remaining(ACTION.SummonInfernal) <= 0
    -- Haunt's aura lasts 12s but the spell carries a real 8s cooldown
    -- (Wowhead WotLK 3.3.5: 59164, "Cooldown 8 seconds"). The aura read alone
    -- can only gate this lane while the aura resolves; when it does not, the
    -- lane matched at the very top of the race for the whole cooldown. The
    -- read fails open (cd_remaining returns 0 when the engine is silent).
    state.haunt_cd = cd_remaining(ACTION.Haunt)
    return state
end

local DSL_DEFS = {
    {
        name = "Haunt",
        conditions = {
            { type = "state", field = "haunt_remains", op = "<", value = 3 },
            -- Real 8s cooldown: the aura window can outlive a failed aura read,
            -- and this lane is entry 1, so an ungated match starves every DoT
            -- and filler below it.
            { type = "state", field = "haunt_cd", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.Haunt, target = "target", opts = { skip_casting = true } },
    },
    {
        name = "Corruption",
        conditions = {
            { type = "state", field = "corruption_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Corruption, target = "target", opts = { skip_casting = true } },
    },
    {
        name = "UnstableAffliction",
        conditions = {
            { type = "state", field = "unstable_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.UnstableAffliction, target = "target", opts = { skip_casting = true } },
    },
    {
        name = "CurseOfAgony",
        conditions = {
            { type = "state", field = "agony_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.CurseOfAgony, target = "target", opts = { skip_casting = true } },
    },
    -- Long-fight boss curse: Curse of Doom out-values Curse of Agony only when
    -- its 1-minute duration will run (a boss). Placed BEFORE CoA so it claims
    -- the curse slot on a boss and CoA keeps it everywhere else.
    {
        name = "CurseOfDoom",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_is_boss", op = "truthy" },
            { type = "state", field = "cod_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.CurseOfDoom, target = "target", label = "[AFFL WOTLK] Curse of Doom" },
    },
    {
        name = "SeedOfCorruptionAoE",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                -- Era-correct AoE DoT: SoC on the primary target when the pack
                -- is big enough that spamming Shadow Bolt is a DPS loss
                -- (4+ targets — mirrors unholy Pestilence's volume gate).
                return (state.enemy_count or 1) >= 4
                    and NS.aoe_target_meets and NS.aoe_target_meets(4, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_10) or 10, context and context.target, context)
            end },
        },
        action = { type = "cast", spell = ACTION.SeedOfCorruption, target = "target" },
    },
    -- Summon Infernal: the 10-minute burst guardian every WotLK warlock spec
    -- opens with. Long-CD gate mirrors the Metamorphosis/DeathWish idiom.
    {
        name = "SummonInfernal",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "infernal_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 600) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.SummonInfernal, target = "target", label = "[AFFL WOTLK] Summon Infernal" },
    },
    -- Nightfall proc: Shadow Trance (17941) makes the next Shadow Bolt
    -- instant, so spend it ahead of the plain filler.
    {
        name = "NightfallProc",
        conditions = {
            { type = "state", field = "shadow_trance_up", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.ShadowBolt, target = "target", label = "[AFFL WOTLK] Shadow Bolt (Nightfall)" },
    },
    -- Drain Life sustain band: solo/leveling self-healing is part of the
    -- affliction identity (the TBC sibling carries the same lane).
    {
        name = "DrainLife",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = 55 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.DrainLife, target = "target", label = "[AFFL WOTLK] Drain Life" },
    },
    {
        name = "DrainSoul",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 25 },
        },
        action = { type = "cast", spell = ACTION.DrainSoul, target = "target" },
    },
    {
        name = "ShadowBolt",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.ShadowBolt, target = "target" },
    },
    -- Mana sustain (rubric): tap HP for mana when the pool runs dry and the
    -- player is healthy enough. Mirrors the TBC affliction LifeTap gates
    -- (mana <= threshold, hp >= safety floor). Appended AFTER ShadowBolt so
    -- the pinned APL order (Haunt < Corruption < UA < CoA < DrainSoul <
    -- ShadowBolt) is untouched.
    {
        name = "LifeTap",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 40 },
            { type = "state", field = "hp", op = ">", value = 50 },
        },
        action = { type = "cast", spell = ACTION.LifeTap, target = "self", label = "[AFFL WOTLK] Life Tap" },
    },
}

local strategies = {
    { name = "Haunt" },
    { name = "Corruption" },
    { name = "UnstableAffliction" },
    { name = "CurseOfDoom" },
    { name = "CurseOfAgony" },
    { name = "SeedOfCorruptionAoE" },
    { name = "SummonInfernal" },
    { name = "NightfallProc" },
    { name = "DrainLife" },
    { name = "DrainSoul" },
    { name = "ShadowBolt" },
    { name = "LifeTap" },
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
    NS.rotation_registry:register("affliction", strategies, {
        get_state = build_state,
        -- Drain Soul clip opt-in: the dispatcher may re-enter the decision loop
        -- mid-channel so a DoT refresh (Haunt/Corruption/UA/CoA, each already
        -- gated on its own remaining-time window) can clip the execute channel.
        channel_clip_ids = DRAIN_SOUL_IDS,
    })
end
if NS.log then NS.log("Warlock affliction rotation registered") end

return { strategies = strategies, build_state = build_state }
