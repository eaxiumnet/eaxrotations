-- test_priest_shadow_wotlk_strategies.lua — Shadow priest WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL shadow_wotlk.lua through its real build_state read path
--        (NS.debuff_remains for VT 48160 / SW:P 48125 / DP 48300, the real
--        mf_tick_compute channel state from me:is_channeling() +
--        get_active_channel_spell_id + get_active_channel_cast_start_time +
--        NS.game_time_ms, NS.spell_ready for Mind Blast, target:is_casting for
--        Silence, ctx.mana_pct), pinning both sides of every gate — including
--        the Mind Flay channel-interaction side of the DoT/Mind Blast lanes.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): shadow had no real-read
--        behavioral pins; these exercise the real DoT/channel plumbing.
-- SAFETY: Pure unit tests with a mocked NS; the real shadow_wotlk.lua, the real
--         mf_tick_compute module, and real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local combat = true
local mana = 100
local casting = false
local debuffs = {}
local not_ready = {}
local now_ms = 0
local channeling = false
local channel_spell = 0
local channel_start = 0
-- Engine channel clock (2026-09-12): milliseconds, nil = accessor absent so the
-- helper falls back to the channel_start arithmetic (the pre-signal path).
local chan_elapsed_ms = nil
local chan_duration_ms = nil
local chan_remaining_ms = nil
local thp = 100
local enemy_count = 1
-- Engine cast END TIME (ctx.target_cast_remaining, seconds): the interrupt
-- floor. nil = unknown = fail-open (the pre-signal behavior).
local cast_remaining = nil

local function vt(secs) debuffs[48160] = secs end
local function swp(secs) debuffs[48125] = secs end
local function dp(secs) debuffs[48300] = secs end

local function reset_env()
    combat, mana, casting, now_ms = true, 100, false, 0
    debuffs, not_ready = {}, {}
    channeling, channel_spell, channel_start = false, 0, 0
    chan_elapsed_ms, chan_duration_ms, chan_remaining_ms = nil, nil, nil
    thp, enemy_count = 100, 1
    cast_remaining = nil
end

_G.EaxRotations = {
    me = {
        get_health_percentage = function() return 100 end,
        is_channeling = function() return channeling end,
        get_active_channel_spell_id = function() return channel_spell end,
        get_active_channel_cast_start_time = function() return channel_start end,
        get_channel_elapsed_ms = function() return chan_elapsed_ms end,
        get_channel_duration_ms = function() return chan_duration_ms end,
        get_channel_remaining_ms = function() return chan_remaining_ms end,
    },
    GetPlayer = function() return _G.EaxRotations.me end,
    debuff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if debuffs[id] then return debuffs[id] end
        end
        return 0
    end,
    spell_ready = function(spell, target, opts)
        local id = type(spell) == "number" and spell or (spell and spell.id) or 0
        if not_ready[id] then return false end
        return true
    end,
    game_time_ms = function() return now_ms end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/priest/shadow_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "shadow_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        mana_pct = mana,
        enemy_count = enemy_count,
        target_hp = thp,
        target_cast_remaining = cast_remaining,
        target = { is_casting = function() return casting end },
        settings = {},
    }
    local state = result.build_state(ctx)
    local matched = find_strategy(strategy_name).matches(ctx, state)
    if expect then
        assert_true(matched, label .. " should match")
    else
        assert_false(matched, label .. " should NOT match")
    end
end

local function assert_lane(label, strategy_name, setup, expect)
    reset_env()
    setup()
    scenario(label, strategy_name, expect)
end

-- Channel helpers: channeling Mind Flay (48156) with N ticks landed.
local function channelling_mf(elapsed_seconds)
    channeling = true
    channel_spell = 48156
    channel_start = 100000
    now_ms = 100000 + elapsed_seconds * 1000
end

-- Engine-clock channel: the authoritative accessors, with no usable channel_start
-- so nothing here can accidentally agree with the fallback arithmetic.
local function channelling_mf_engine(elapsed_ms, duration_ms, remaining_ms)
    channeling = true
    channel_spell = 48156
    channel_start = 0
    now_ms = 0
    chan_elapsed_ms = elapsed_ms
    chan_duration_ms = duration_ms
    chan_remaining_ms = remaining_ms
end

-- Fallback-only channel (no engine clock): elapsed derived from channel_start.
local function channelling_mf_fallback(elapsed_ms)
    channeling = true
    channel_spell = 48156
    channel_start = 100000
    now_ms = 100000 + elapsed_ms
    chan_elapsed_ms, chan_duration_ms, chan_remaining_ms = nil, nil, nil
end

-- ============================================================================
-- Silence: in combat + the target is casting.
-- ============================================================================
assert_lane("Silence fires on an enemy cast", "Silence", function() casting = true end, true)
assert_lane("Silence blocked when nothing is casting", "Silence", function() end, false)
assert_lane("Silence blocked out of combat", "Silence",
    function() combat = false; casting = true end, false)
-- Engine end-time floor (2026-09-12, shared/cast_timing_sylvanas): a cast that
-- lands before the interrupt arrives must not spend the cooldown.
assert_lane("Silence fires with 1.0s left on the enemy cast", "Silence",
    function() casting = true; cast_remaining = 1.0; cast_lead = nil end, true)
assert_lane("Silence holds when only 0.05s of the cast remains", "Silence",
    function() casting = true; cast_remaining = 0.05; cast_lead = nil end, false)

-- ============================================================================
-- VampiricTouch: can break Mind Flay + refresh below 3s.
-- ============================================================================
assert_lane("VT refreshes when the debuff is down", "VampiricTouch", function() end, true)
assert_lane("VT refreshes at 2.9s remaining", "VampiricTouch", function() vt(2.9) end, true)
assert_lane("VT blocked at the 3.0s boundary", "VampiricTouch", function() vt(3) end, false)
-- Channel interaction: MF at 2 ticks + nothing urgent -> hold the refresh
-- (should_clip false keeps can_break_mind_flay false).
assert_lane("VT held while channelling MF with nothing urgent", "VampiricTouch",
    function() vt(5); not_ready[48127] = true; channelling_mf(2.5) end, false)
-- MF at 2 ticks + VT about to expire -> the clip gate lets the refresh through.
assert_lane("VT clips MF at 2 ticks when expiring", "VampiricTouch",
    function() vt(1.4); not_ready[48127] = true; channelling_mf(2.5) end, true)
-- Engine channel clock (2026-09-12): ENGINE-ONLY tick derivation. 1.2s elapsed on
-- a haste-scaled 1.5s channel is 2 of 3 ticks (duration/3 = 500ms), where the
-- 1s-cadence fallback sees only 1 — so Mind Blast (gated on can_break_mind_flay,
-- i.e. >= 2 ticks) fires off the engine clock and holds off the fallback.
assert_lane("Mind Blast clips MF at 2 engine ticks on a haste-scaled channel", "MindBlast",
    function() channelling_mf_engine(1200, 1500, nil) end, true)
assert_lane("Mind Blast held at 1 fallback tick for the same 1.2s elapsed", "MindBlast",
    function() channelling_mf_fallback(1200) end, false)
-- Engine channel END time (2026-09-12): a debuff that expires before THIS channel
-- ends is refreshed now even outside the lane's own static window. VT at 4.0s is
-- outside the lane's <3 gate so it cannot match on its own; with 4.5s+ of channel
-- left (remaining 3.0 + 1.5 window) the clip gate opens and VT fires; with only
-- 2.0s left (remaining 0.5 + 1.5) the same VT lane holds.
assert_lane("VT clip gate opens when the debuff outlives the channel", "VampiricTouch",
    function() vt(2.9); swp(5); not_ready[48127] = true; channelling_mf_engine(2100, 3000, 3000) end, true)
assert_lane("VT clip gate holds when the channel ends first", "VampiricTouch",
    function() vt(2.9); swp(5); not_ready[48127] = true; channelling_mf_engine(2100, 3000, 500) end, false)

-- ============================================================================
-- ShadowWordPain: can break Mind Flay + refresh below 3s.
-- ============================================================================
assert_lane("SW:P refreshes when the debuff is down", "ShadowWordPain", function() end, true)
assert_lane("SW:P refreshes at 2.9s remaining", "ShadowWordPain", function() swp(2.9) end, true)
assert_lane("SW:P blocked at the 3.0s boundary", "ShadowWordPain", function() swp(3) end, false)
assert_lane("SW:P held while channelling MF with nothing urgent", "ShadowWordPain",
    function() swp(5); not_ready[48127] = true; channelling_mf(2.5) end, false)

-- ============================================================================
-- DevouringPlague: can break Mind Flay + refresh below 3s.
-- ============================================================================
assert_lane("DP refreshes when the debuff is down", "DevouringPlague", function() end, true)
assert_lane("DP refreshes at 2.9s remaining", "DevouringPlague", function() dp(2.9) end, true)
assert_lane("DP blocked at the 3.0s boundary", "DevouringPlague", function() dp(3) end, false)

-- ============================================================================
-- MindBlast: can break Mind Flay + mana >= 20.
-- ============================================================================
assert_lane("Mind Blast fires at 20% mana idle", "MindBlast", function() mana = 20 end, true)
assert_lane("Mind Blast blocked below 20% mana", "MindBlast", function() mana = 19 end, false)
-- Channel interaction: fresh channel (0-1 ticks) never clips -> held even ready.
assert_lane("Mind Blast held during a fresh MF channel", "MindBlast",
    function() channelling_mf(0.5) end, false)
-- Channel interaction: 2 ticks + ready -> the clip gate lets it through.
assert_lane("Mind Blast clips MF at 2 ticks when ready", "MindBlast",
    function() channelling_mf(2.5) end, true)

-- ============================================================================
-- MindFlay: filler at >= 20% mana (ungated by channel state).
-- ============================================================================
assert_lane("Mind Flay fires at 20% mana", "MindFlay", function() mana = 20 end, true)
assert_lane("Mind Flay blocked below 20% mana", "MindFlay", function() mana = 19 end, false)

-- ============================================================================
-- Shadowfiend: in combat + mana below the 60% return threshold.
-- ============================================================================
assert_lane("Shadowfiend fires at 59% mana", "Shadowfiend", function() mana = 59 end, true)
assert_lane("Shadowfiend blocked at 60% mana", "Shadowfiend", function() mana = 60 end, false)
assert_lane("Shadowfiend blocked out of combat", "Shadowfiend",
    function() mana = 40; combat = false end, false)

-- ============================================================================
-- ShadowWordDeath: execute lane — target hp <= 25% (2026-09-09 guide pass).
-- Note: SW:D recoil damage makes it strictly an execute-window finisher.
-- ============================================================================
assert_lane("SW:D fires at 25% target hp", "ShadowWordDeath", function() thp = 25 end, true)
assert_lane("SW:D blocked above 25% target hp", "ShadowWordDeath", function() thp = 30 end, false)
assert_lane("SW:D blocked out of combat", "ShadowWordDeath",
    function() thp = 20; combat = false end, false)

-- ============================================================================
-- MindSear: AoE filler on 3+ enemies (2026-09-09 guide pass).
-- ============================================================================
assert_lane("MindSear fires on 3 enemies", "MindSear", function() enemy_count = 3 end, true)
assert_lane("MindSear blocked single-target", "MindSear", function() end, false)

print("PASS test_priest_shadow_wotlk_strategies")
