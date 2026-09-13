-- shadow_wotlk.lua — Priest Shadow rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Shadow priest: DoT maintenance
--        (VampiricTouch, ShadowWordPain, DevouringPlague), Mind Blast filler,
--        Mind Flay channel filler, Shadowfiend mana-return CD.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocs.
-- DECISION (W3.3): plain spec_kit.define_action with file-local WotLK rank
--         ladders (define_action_for_class resolves through the TBC-capped
--         class table — precedent classes/mage/fire_wotlk.lua:20). Debuff
--         tables track the WotLK max-rank aura ids (48125/48160/48300) for
--         literal matching. Shadowfiend (34433, APL priority 1) fires below
--         the mana-return threshold; Mind Flay channel clipping mirrors the
--         TBC sibling via shared/mf_tick_compute_sylvanas.
-- 2026-09-12 channel-clip pass: Mind Flay is declared in the register call's
--         channel_clip_ids so main_sylvanas re-enters the decision loop while
--         this channel runs (previously the blanket channel skip meant these
--         clip lanes could never fire in the live dispatcher), the clip lanes
--         carry skip_casting so evaluate_cast lets the replacement through, and
--         the tick/remaining numbers come from the engine channel clock.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
-- Cast/channel end-time gate (2026-09-12): an interrupt that lands after the
-- target's cast completes wastes its cooldown. Fail-open when the engine
-- reports no end time (shared/cast_timing_sylvanas.lua).
local _ct_ok, cast_timing = pcall(require, "shared/cast_timing_sylvanas")
if not _ct_ok or type(cast_timing) ~= "table" then
    cast_timing = { context_interrupt_open = function() return true end }
end
local mf_tick = require("shared/mf_tick_compute_sylvanas")

local define = spec_kit.define_action

local ACTION = {
    VampiricTouch = define("VampiricTouch", { 48160, 34917, 34916, 34914 }, "VampiricTouch"),
    ShadowWordPain = define("ShadowWordPain", { 48125, 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }, "ShadowWordPain"),
    DevouringPlague = define("DevouringPlague", { 48300, 25467, 19280, 19279, 19278, 19277, 19276, 2944 }, "DevouringPlague"),
    MindBlast = define("MindBlast", { 48127, 25375, 25372, 10947, 10946, 10945, 8106, 8105, 8104, 8103, 8102, 8092 }, "MindBlast"),
    MindFlay = define("MindFlay", { 48156, 25387, 18807, 17314, 17313, 17312, 17311, 15407 }, "MindFlay"),
    -- Baseline shadow priest interrupt (3.3.5): Silence (shadow-tree talent,
    -- single rank). Not in the wowsims shadow APL, so it sits outside the
    -- pinned order (first, like the rogue Kick template).
    Silence = define("Silence", 15487, "Silence"),
    -- Shadowfiend: single rank (34433), unchanged since TBC; the wowsims
    -- shadow APL fires it as priority 1 (mana-return pet).
    Shadowfiend = define("Shadowfiend", 34433, "Shadowfiend"),
    -- 2026-09-09 guide pass (wowsims shadow APL): Mind Sear AoE channel
    -- (49821 rank 1 learned 50 / 53023 max rank 74) and Shadow Word: Death
    -- execute (48158 max / 48157 rank at 75; 12s CD, backlash recoil).
    MindSear = define("MindSear", { 53023, 49821 }, "MindSear"),
    ShadowWordDeath = define("ShadowWordDeath", { 48158, 48157, 32379 }, "ShadowWordDeath"),
}

local VAMPIRIC_TOUCH_DEBUFF = { 48160, 34917, 34916, 34914 }
local SHADOW_WORD_PAIN_DEBUFF = { 48125, 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local DEVOURING_PLAGUE_DEBUFF = { 48300, 25467, 19280, 19279, 19278, 19277, 19276, 2944 }
local MIND_FLAY_IDS = { 48156, 25387, 18807, 17314, 17313, 17312, 17311, 15407 }

local shadow_state = {
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    target_is_casting = false,
    vampiric_touch_remains = 0,
    shadow_word_pain_remains = 0,
    devouring_plague_remains = 0,
    mb_ready = false,
    mf_channeling = false,
    should_clip_mf = false,
    target_hp_pct = 100,
}

local function can_break_mind_flay(s)
    return not s.mf_channeling or s.should_clip_mf
end

local function build_state(context)
    local state = spec_kit.safe_state(shadow_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.mana_pct = (context and context.mana_pct)
        or (me and NS.mana_pct and NS.mana_pct(me))
        or (me and me.get_mana_percentage and me:get_mana_percentage())
        or 100
    state.enemy_count = (context and context.enemy_count) or 1
    -- Execute-band read (main_sylvanas.lua sets target_hp; guides fire
    -- Shadow Word: Death at <= 25%).
    state.target_hp_pct = (context and (context.target_hp or context.target_hp_pct or context.hp)) or 100
    state.in_combat = (context and context.in_combat) or false
    state.target_is_casting = (target and target.is_casting and target:is_casting()) or false
    state.vampiric_touch_remains = (target and NS.debuff_remains and NS.debuff_remains(target, VAMPIRIC_TOUCH_DEBUFF)) or 0
    state.shadow_word_pain_remains = (target and NS.debuff_remains and NS.debuff_remains(target, SHADOW_WORD_PAIN_DEBUFF)) or 0
    state.devouring_plague_remains = (target and NS.debuff_remains and NS.debuff_remains(target, DEVOURING_PLAGUE_DEBUFF)) or 0
    -- Mind Flay channel state + clip signal (mirrors shadow_sylvanas.lua:476-486).
    state.mb_ready = (target and NS.spell_ready and NS.spell_ready(ACTION.MindBlast, target, { expected_cooldown = 5.5 })) or false
    -- Engine channel clock (2026-09-12): mf_ticks now derives from the engine's
    -- channel elapsed/duration (haste-scaled) instead of `now - channel_start`,
    -- and the third return is the real seconds left in the channel, which feeds
    -- the "this DoT expires before the channel ends" clip rule.
    local mf_channeling, mf_ticks, mf_remaining = mf_tick.compute_channel_state(me, (NS.game_time_ms and NS.game_time_ms()) or 0, MIND_FLAY_IDS)
    state.mf_channeling = mf_channeling
    state.should_clip_mf = mf_tick.should_clip_mf(
        mf_channeling,
        mf_ticks,
        spec_kit.setting_number(context, "shadow_vt_refresh_window", 1.5),
        state.mb_ready,
        false,
        state.vampiric_touch_remains,
        state.shadow_word_pain_remains,
        spec_kit.setting_number(context, "shadow_swp_refresh_window", 1.5),
        mf_remaining
    )
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "Silence",
        conditions = {
            { type = "custom", fn = function(context, state)
                return cast_timing.context_interrupt_open(context, context and context.settings)
            end },
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_is_casting", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Silence, target = "target" },
    },
    {
        name = "VampiricTouch",
        conditions = {
            { type = "custom", fn = function(context, state)
                return can_break_mind_flay(state)
            end },
            { type = "state", field = "vampiric_touch_remains", op = "<", value = 3 },
        },
        -- skip_casting: this lane is a declared Mind Flay clipper (see the
        -- register call's channel_clip_ids). Without it evaluate_cast refuses
        -- the replacement cast for the whole channel.
        action = { type = "cast", spell = ACTION.VampiricTouch, target = "target", opts = { skip_casting = true } },
    },
    {
        name = "ShadowWordPain",
        conditions = {
            { type = "custom", fn = function(context, state)
                return can_break_mind_flay(state)
            end },
            { type = "state", field = "shadow_word_pain_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.ShadowWordPain, target = "target", opts = { skip_casting = true } },
    },
    {
        name = "DevouringPlague",
        conditions = {
            { type = "custom", fn = function(context, state)
                return can_break_mind_flay(state)
            end },
            { type = "state", field = "devouring_plague_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.DevouringPlague, target = "target", opts = { skip_casting = true } },
    },
    {
        name = "MindBlast",
        conditions = {
            { type = "custom", fn = function(context, state)
                return can_break_mind_flay(state)
            end },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.MindBlast, target = "target", opts = { skip_casting = true } },
    },
    {
        name = "ShadowWordDeath",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_hp_pct", op = "<=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.ShadowWordDeath, target = "target" },
    },
    {
        name = "MindSear",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "enemy_count", op = ">=", value = 3 },
        },
        action = { type = "cast", spell = ACTION.MindSear, target = "target" },
    },
    {
        name = "MindFlay",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.MindFlay, target = "target" },
    },
    -- Shadowfiend mana-return CD (APL priority 1): fire whenever the mana pool
    -- is below the return threshold. Appended last — outside the pinned
    -- wowsims order (the sim has no CD budget in the battery fixtures).
    {
        name = "Shadowfiend",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 60 },
        },
        action = { type = "cast", spell = ACTION.Shadowfiend, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "Silence" },
    { name = "DevouringPlague" },
    { name = "ShadowWordPain" },
    { name = "VampiricTouch" },
    { name = "MindBlast" },
    { name = "MindSear" },
    { name = "MindFlay" },
    { name = "Shadowfiend" },
    { name = "ShadowWordDeath" },
}

-- Priority order mirrors wowsims shadow APL (ui/shadow_priest/apls/default.apl.json):
-- DP > SWP > VT > MindBlast > MindFlay.
-- Name-based substitution preserves the existing priority order.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("shadow", strategies, {
        get_state = build_state,
        -- Mind Flay is a clip-managed channel (2026-09-12): the dispatcher may
        -- re-enter the decision loop mid-channel for these ids so a
        -- higher-priority lane (VT/SW:P/DP/MB, each gated by
        -- can_break_mind_flay) can clip at a tick boundary. Every other channel
        -- keeps the blanket skip.
        channel_clip_ids = MIND_FLAY_IDS,
    })
end
if NS.log then NS.log("Priest Shadow WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
