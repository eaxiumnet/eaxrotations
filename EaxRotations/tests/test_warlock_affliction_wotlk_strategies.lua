-- test_warlock_affliction_wotlk_strategies.lua — Affliction warlock WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL affliction_wotlk.lua through its real build_state read
--        path (NS.debuff_remains for the UA 47843 / Corruption 47813 / CoA
--        47864 / Haunt 59164 debuffs, ctx.target_hp for DrainSoul, ctx.hp /
--        ctx.mana_pct for the LifeTap sustain gate), pinning both sides of
--        every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): affliction had only static DSL
--        coverage; these are real-read behavioral pins.
-- SAFETY: Pure unit tests with a mocked NS; the real affliction_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local combat = true
local target_hp = 100
local hp = 100
local mana = 100
local debuffs = {}

local function set(secs) debuffs[1] = secs end
local function ua(secs) debuffs[47843] = secs end
local function corr(secs) debuffs[47813] = secs end
local function agony(secs) debuffs[47864] = secs end
local function haunt(secs) debuffs[59164] = secs end
local function cod(secs) debuffs[47867] = secs end

local enemies, aoe_ok = 1, false
-- 2026-09-12 guide-pass knobs: boss target, Shadow Trance (Nightfall) proc,
-- Summon Infernal cooldown, and the inbound ctx/settings.
local boss = false
local trance = false
local infernal_cd = 0
local haunt_cd = 0    -- Haunt cooldown (8s in WotLK)
-- Captured from the REAL spec: the register options and the opts the DSL hands
-- to try_cast when a lane executes (channel-clip opt-in pins, 2026-09-12).
local registered_options = nil
local last_cast_opts = nil

local function reset_env()
    combat, target_hp, hp, mana = true, 100, 100, 100
    debuffs = {}
    enemies, aoe_ok = 1, false
    boss, trance, infernal_cd, haunt_cd = false, false, 0, 0
end

_G.EaxRotations = {
    me = { get_health_percentage = function() return hp end },
    GetPlayer = function() return _G.EaxRotations.me end,
    debuff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if debuffs[id] then return debuffs[id] end
        end
        return 0
    end,
    -- 17941 = Shadow Trance (Nightfall proc).
    buff_up = function(unit, ids)
        if ids then
            for _, id in ipairs(ids) do
                if id == 17941 then return trance end
            end
        end
        return false
    end,
    cooldown_remains = function(spell)
        local id = type(spell) == "number" and spell or (spell and spell.ids and spell.ids[1]) or 0
        if id == 1122 then return infernal_cd end
        if id == 59164 then return haunt_cd end
        return 0
    end,
    aoe_target_meets = function(n) return aoe_ok and enemies >= (n or 1) end,
    try_cast = function(spell, target, label, opts) last_cast_opts = opts; return true end,
    log = function() end,
    rotation_registry = { register = function(self, name, strategies, options) registered_options = options end },
}

local result = dofile("EaxRotations/classes/warlock/affliction_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "affliction_wotlk strategies should load")

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
        hp = hp,
        target_hp = target_hp,
        target_is_boss = boss,
        enemy_count = enemies,
        target = { is_casting = function() return false end },
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

-- ============================================================================
-- Haunt: refresh at/below 3s AND the real 8s cooldown ready (state.haunt_cd via
-- the real cd_remaining helper; Wowhead 3.3.5 59164 "Cooldown 8 seconds",
-- aura 12s). Haunt is entry 1, so an ungated match — the shape that lands when
-- the aura read does not resolve — starves every DoT and filler below it.
-- ============================================================================
assert_lane("Haunt refreshes when the debuff is down", "Haunt", function() end, true)
assert_lane("Haunt refreshes at 2.9s remaining", "Haunt", function() haunt(2.9) end, true)
assert_lane("Haunt blocked at the 3.0s boundary", "Haunt", function() haunt(3) end, false)
assert_lane("Haunt blocked while the debuff is healthy", "Haunt", function() haunt(3.1) end, false)
assert_lane("Haunt held with no resolvable aura while the 8s cooldown runs", "Haunt",
    function() haunt_cd = 7.9 end, false)
assert_lane("Haunt fires at the cooldown-ready boundary with no aura read", "Haunt",
    function() haunt_cd = 0 end, true)
assert_lane("Haunt held on cooldown even with the aura about to drop", "Haunt",
    function() haunt(0.1); haunt_cd = 4 end, false)

-- ============================================================================
-- Corruption: refresh at/below 3s.
-- ============================================================================
assert_lane("Corruption refreshes when the debuff is down", "Corruption", function() end, true)
assert_lane("Corruption refreshes at 2.9s remaining", "Corruption", function() corr(2.9) end, true)
assert_lane("Corruption blocked at the 3.0s boundary", "Corruption", function() corr(3) end, false)
assert_lane("Corruption blocked while the debuff is healthy", "Corruption", function() corr(3.1) end, false)

-- ============================================================================
-- UnstableAffliction: refresh at/below 3s.
-- ============================================================================
assert_lane("UA refreshes when the debuff is down", "UnstableAffliction", function() end, true)
assert_lane("UA refreshes at 2.9s remaining", "UnstableAffliction", function() ua(2.9) end, true)
assert_lane("UA blocked at the 3.0s boundary", "UnstableAffliction", function() ua(3) end, false)
assert_lane("UA blocked while the debuff is healthy", "UnstableAffliction", function() ua(3.1) end, false)

-- ============================================================================
-- CurseOfAgony: refresh at/below 3s.
-- ============================================================================
assert_lane("CoA refreshes when the debuff is down", "CurseOfAgony", function() end, true)
assert_lane("CoA refreshes at 2.9s remaining", "CurseOfAgony", function() agony(2.9) end, true)
assert_lane("CoA blocked at the 3.0s boundary", "CurseOfAgony", function() agony(3) end, false)
assert_lane("CoA blocked while the debuff is healthy", "CurseOfAgony", function() agony(3.1) end, false)

-- ============================================================================
-- DrainSoul: execute band at target hp < 25 (no combat gate in this file).
-- ============================================================================
assert_lane("DrainSoul fires below 25% target hp", "DrainSoul", function() target_hp = 24 end, true)
assert_lane("DrainSoul blocked at 25% target hp", "DrainSoul", function() target_hp = 25 end, false)
assert_lane("DrainSoul blocked on a healthy target", "DrainSoul", function() end, false)

-- ============================================================================
-- ShadowBolt: filler at >= 20% mana.
-- ============================================================================
assert_lane("ShadowBolt fires at 20% mana", "ShadowBolt", function() mana = 20 end, true)
assert_lane("ShadowBolt blocked below 20% mana", "ShadowBolt", function() mana = 19 end, false)

-- ============================================================================
-- LifeTap: in combat + mana < 40 + hp > 50 (sustain, appended after fillers).
-- ============================================================================
assert_lane("LifeTap fires when mana drops to 39 with hp healthy", "LifeTap",
    function() mana = 39 end, true)
assert_lane("LifeTap fires at 1% mana with hp healthy", "LifeTap",
    function() mana = 1 end, true)
assert_lane("LifeTap blocked at 40% mana", "LifeTap", function() mana = 40 end, false)
assert_lane("LifeTap blocked when hp is at the 50 floor", "LifeTap",
    function() mana = 30; hp = 50 end, false)
assert_lane("LifeTap blocked below the hp floor", "LifeTap",
    function() mana = 30; hp = 49 end, false)
assert_lane("LifeTap blocked out of combat", "LifeTap",
    function() mana = 30; combat = false end, false)

-- ============================================================================
-- SeedOfCorruptionAoE: 4+ enemy packs via the real aoe_target_meets gate.
-- ============================================================================
assert_lane("SeedOfCorruptionAoE fires into a 4-enemy pack", "SeedOfCorruptionAoE",
    function() enemies = 4; aoe_ok = true end, true)
assert_lane("SeedOfCorruptionAoE blocked at 3 enemies", "SeedOfCorruptionAoE",
    function() enemies = 3; aoe_ok = true end, false)
assert_lane("SeedOfCorruptionAoE fail-closed without the AoE module", "SeedOfCorruptionAoE",
    function() enemies = 5; aoe_ok = false end, false)

-- ============================================================================
-- 2026-09-12 guide-pass lanes: Curse of Doom (long boss fight), Summon
-- Infernal (long-CD guardian), Nightfall (Shadow Trance proc) and the Drain
-- Life sustain band. Fire + hold on both sides of every new gate.
-- ============================================================================
assert_lane("CurseOfDoom fires on a boss with the curse down", "CurseOfDoom",
    function() boss = true end, true)
assert_lane("CurseOfDoom refreshes at 2.9s remaining on a boss", "CurseOfDoom",
    function() boss = true; cod(2.9) end, true)
assert_lane("CurseOfDoom blocked at the 3.0s boundary", "CurseOfDoom",
    function() boss = true; cod(3) end, false)
assert_lane("CurseOfDoom blocked on a non-boss target", "CurseOfDoom",
    function() end, false)
assert_lane("CurseOfDoom blocked out of combat", "CurseOfDoom",
    function() boss = true; combat = false end, false)

assert_lane("SummonInfernal fires when the 10-min CD is up", "SummonInfernal",
    function() infernal_cd = 0 end, true)
assert_lane("SummonInfernal blocked while the CD is running", "SummonInfernal",
    function() infernal_cd = 30 end, false)
assert_lane("SummonInfernal blocked out of combat", "SummonInfernal",
    function() infernal_cd = 0; combat = false end, false)

assert_lane("NightfallProc fires while Shadow Trance is up", "NightfallProc",
    function() trance = true end, true)
assert_lane("NightfallProc blocked without the proc", "NightfallProc",
    function() end, false)
assert_lane("NightfallProc blocked below 20% mana even with the proc", "NightfallProc",
    function() trance = true; mana = 19 end, false)

assert_lane("DrainLife fires below 55% hp with mana available", "DrainLife",
    function() hp = 54 end, true)
assert_lane("DrainLife blocked at the 55% hp boundary", "DrainLife",
    function() hp = 55 end, false)
assert_lane("DrainLife blocked below 20% mana", "DrainLife",
    function() hp = 30; mana = 19 end, false)
assert_lane("DrainLife blocked out of combat", "DrainLife",
    function() hp = 30; combat = false end, false)

-- ============================================================================
-- Channel-clip opt-in (2026-09-12): Drain Soul is a declared clip-managed
-- channel and the DoT refresh lanes carry skip_casting so evaluate_cast lets a
-- replacement through mid-channel. Both are read off the REAL spec file: the
-- register-call options and the opts the compiled lane hands to try_cast.
-- ============================================================================
assert_true(registered_options and registered_options.channel_clip_ids,
    "affliction must declare channel_clip_ids at register time")
local clip = registered_options.channel_clip_ids
local has_drain = false
for i = 1, #clip do if clip[i] == 47855 then has_drain = true end end
assert_true(has_drain, "channel_clip_ids must include the max-rank Drain Soul id 47855")
local has_unrelated = false
for i = 1, #clip do if clip[i] == 48125 then has_unrelated = true end end
assert_false(has_unrelated, "channel_clip_ids must not include unrelated channel ids")

-- Executing a DoT lane must pass skip_casting through to try_cast.
reset_env()
local clip_ctx = { in_combat = combat, mana_pct = mana, hp = hp, target_hp = target_hp,
    enemy_count = enemies, target = { is_casting = function() return false end }, settings = {} }
local clip_state = result.build_state(clip_ctx)
last_cast_opts = nil
assert_true(find_strategy("Corruption").execute(clip_ctx, clip_state) == true,
    "Corruption lane should execute through the mocked try_cast")
assert_true(last_cast_opts and last_cast_opts.skip_casting == true,
    "the Corruption clip lane must pass skip_casting to try_cast")

-- The filler is NOT a clipper: it keeps the pre-signal opts (no skip_casting).
last_cast_opts = nil
find_strategy("ShadowBolt").execute(clip_ctx, clip_state)
assert_true(not (last_cast_opts and last_cast_opts.skip_casting),
    "ShadowBolt must not opt out of the casting guard")

print("PASS test_warlock_affliction_wotlk_strategies")
