-- Readability notes:
--   What: Priest Shadow priority list with Mind Flay channel clipping control.
--   When: dispatcher runs this playstyle when selected.
--   Why: TBC Shadow damage depends on DoT upkeep, Mind Blast/SW:D cooldowns, and not wasting Mind Flay ticks.
--   Safety: every cast is target/resource/movement gated and channels are only clipped at an intentional tick point.

-- Decision notes:
--   Mind Flay is a 3 second channel with 1 second ticks; clipping before two landed ticks is usually a loss.
--   The state builder computes channel/tick state once, then higher-priority actions ask whether clipping is allowed.
--   If channel timing is unavailable, the rotation falls back to the safer no-clip behavior from the shared cast gate.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PriestSpells or {}

local mf_tick = require("shared/mf_tick_compute_sylvanas")

local SHADOWFORM_BUFF = { 15473 }
local INNER_FOCUS_BUFF = { 14751 }
local VAMPIRIC_TOUCH_DEBUFF = { 34917, 34916, 34914 }
local SHADOW_WORD_PAIN_DEBUFF = { 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local VAMPIRIC_EMBRACE_DEBUFF = { 15286 }
local MIND_FLAY_IDS = { 25387, 18807, 17314, 17313, 17312, 17311, 15407 }

local VT_CLIP_THRESHOLD = 1.5

local state = {
    mf_channeling = false,
    mf_ticks = 0,
    should_clip_mf = false,
    vt_remaining = 0,
    swp_remaining = 0,
    ve_remaining = 0,
    mb_ready = false,
    swd_ready = false,
}

local function build_state(context)
    local target = context.target
    local me = NS.GetPlayer()

    state.vt_remaining = target and NS.debuff_remains(target, VAMPIRIC_TOUCH_DEBUFF) or 0
    state.swp_remaining = target and NS.debuff_remains(target, SHADOW_WORD_PAIN_DEBUFF) or 0
    state.ve_remaining = target and NS.debuff_remains(target, VAMPIRIC_EMBRACE_DEBUFF) or 0
    state.mb_ready = target and NS.spell_ready(SPELLS.MindBlast, target, { expected_cooldown = 5.5 }) or false
    state.swd_ready = target and NS.spell_ready(SPELLS.ShadowWordDeath, target, { expected_cooldown = 12 }) or false
    state.mf_channeling, state.mf_ticks = mf_tick.compute_channel_state(me, NS.game_time_ms(), MIND_FLAY_IDS)
    state.should_clip_mf = mf_tick.should_clip_mf(
        state.mf_channeling,
        state.mf_ticks,
        VT_CLIP_THRESHOLD,
        state.mb_ready,
        state.swd_ready,
        state.vt_remaining,
        state.swp_remaining
    )

    return state
end

local function can_break_mind_flay(s)
    return not s.mf_channeling or s.should_clip_mf
end

local strategies = {
    {
        name = "Shadowform",
        matches = function()
            if NS.has_player_buff(SHADOWFORM_BUFF) then return false end
            return NS.spell_ready(SPELLS.Shadowform, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.Shadowform, NS.PLAYER_UNIT, "[SHADOW] Shadowform")
        end,
    },
    {
        name = "Shadowfiend",
        matches = function(context, s)
            if not can_break_mind_flay(s) then return false end
            if not context.has_valid_enemy_target then return false end
            if (context.mana_pct or 100) > 55 then return false end
            return NS.spell_ready(SPELLS.Shadowfiend, context.target, { expected_cooldown = 300 })
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Shadowfiend, context.target, "[SHADOW] Shadowfiend")
        end,
    },
    {
        name = "VampiricTouch",
        matches = function(context, s)
            if not can_break_mind_flay(s) then return false end
            if context.is_moving then return false end
            if not context.has_valid_enemy_target or s.vt_remaining > 3 then return false end
            return NS.spell_ready(SPELLS.VampiricTouch, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.VampiricTouch, context.target, "[SHADOW] Vampiric Touch")
        end,
    },
    {
        name = "ShadowWordPain",
        matches = function(context, s)
            if not can_break_mind_flay(s) then return false end
            if not context.has_valid_enemy_target or s.swp_remaining > 3 then return false end
            return NS.spell_ready(SPELLS.ShadowWordPain, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.ShadowWordPain, context.target, "[SHADOW] Shadow Word: Pain")
        end,
    },
    {
        name = "VampiricEmbrace",
        matches = function(context, s)
            if not can_break_mind_flay(s) then return false end
            if not context.has_valid_enemy_target or s.ve_remaining > 10 then return false end
            return NS.spell_ready(SPELLS.VampiricEmbrace, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.VampiricEmbrace, context.target, "[SHADOW] Vampiric Embrace")
        end,
    },
    {
        name = "InnerFocusMindBlast",
        matches = function(context, s)
            if not can_break_mind_flay(s) then return false end
            if not context.in_combat or not s.mb_ready then return false end
            if NS.has_player_buff(INNER_FOCUS_BUFF) then return false end
            return NS.spell_ready(SPELLS.InnerFocus, NS.PLAYER_UNIT, { skip_range = true, expected_cooldown = 180 })
        end,
        execute = function()
            return NS.try_cast(SPELLS.InnerFocus, NS.PLAYER_UNIT, "[SHADOW] Inner Focus before Mind Blast")
        end,
    },
    {
        name = "MindBlast",
        matches = function(context, s)
            if not can_break_mind_flay(s) then return false end
            if context.is_moving then return false end
            return context.has_valid_enemy_target and s.mb_ready
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.MindBlast, context.target, "[SHADOW] Mind Blast")
        end,
    },
    {
        name = "ShadowWordDeath",
        matches = function(context, s)
            if not can_break_mind_flay(s) then return false end
            if (context.hp or 100) < 80 then return false end
            return context.has_valid_enemy_target and s.swd_ready
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.ShadowWordDeath, context.target, "[SHADOW] Shadow Word: Death")
        end,
    },
    {
        name = "MindFlay",
        matches = function(context)
            if context.is_moving or context.is_casting or context.is_channeling then return false end
            return context.has_valid_enemy_target and NS.spell_ready(SPELLS.MindFlay, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.MindFlay, context.target, "[SHADOW] Mind Flay")
        end,
    },
}

NS.rotation_registry:register("shadow", strategies, {
    get_state = build_state,
})
NS.log("Priest shadow rotation registered")
return strategies
