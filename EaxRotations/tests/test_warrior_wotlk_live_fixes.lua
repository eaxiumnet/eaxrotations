-- test_warrior_wotlk_live_fixes.lua — W3.3/W3.4 warrior WotLK live-fix regression tests.
-- WHAT:  pins the W3.3 register fixes per file:
--        arms:   cooldowns via NS.cooldown_remains (never the mock-only 99
--                fallback), Execute rage 15, swing-QUEUED Heroic Strike (40
--                rage / swing <= 1s / single target) + Cleave (35 rage / 2+
--                targets), Defensive-stance Shield Wall + Retaliation (incl.
--                the Defensive dance), proc-only Overpower (Taste for Blood),
--                Battle-stance Sweeping Strikes / Thunder Clap.
--        fury:   DeathWish single rank 12292 (no 12328 contamination),
--                Execute rage 15, Bloodthirst/Whirlwind real-CD gates,
--                Bloodsurge-proc-gated Slam, Berserker-stance Pummel/Whirlwind,
--                final BerserkerStance enforcement lane.
--        prot:   Revenge max rank 57823 at ladder top, Shield Block 60-rage +
--                need gate, Berserker-stance Pummel (with the dance lane),
--                queued Heroic Strike (30 rage / swing <= 1s), Last Stand
--                emergency, ShieldSlam/Revenge real-CD gates, 9-strategy order.
--        leveling: Victory Rush killing-blow proc gate, dodge-proc Overpower
--                (+5 rage, Battle stance), Execute rage 15, Charge 8-25 yd
--                range gate, Pummel rank ladder {6554,6552}, Rend 10 rage.
--        W3.4 (2026-08-13): rage-chain conversion for all 4 files — state.rage
--                flows through context.rage (main_sylvanas.lua:814) then
--                me:get_power(NS.POWER_RAGE); the mock unit is get_rage-less
--                (me:get_rage() is mock-only and pinned rage-gated lanes at 0
--                live), so any surviving me:get_rage() read errors loudly.
-- WHEN:  standalone (`lua EaxRotations/tests/test_warrior_wotlk_live_fixes.lua`);
--        intentionally NOT registered in run_wotlk_tests.lua (deliverable).
-- WHY:   the W3.3/W3.4 must-fixes must not silently regress.
-- SAFETY: pure unit tests with a mocked _G.EaxRotations; no game API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

-- ---------------------------------------------------------------------------
-- Spy state (drive every NS read the spec files make)
-- ---------------------------------------------------------------------------
local spy = {
    rage = 0,
    stance = 1,            -- BATTLE; per-file default overridden before build_state
    hp = 100,
    target_hp = 100,
    swing_until = 999,     -- far: queued HS/Cleave gates fail closed by default
    on_cd = {},            -- spell-id -> seconds remaining (0/absent = ready)
    buffs = {},            -- active buff ids (proc auras etc.)
    debuff_remains = 0,
    target_casting = false,
    should_interrupt = false,
    aoe_target = true,
    aoe_self = true,
    op_proc = false,       -- SwingDiagnostics.is_overpower_proc_active
    spell_calls = {},      -- { rank_ids = ..., label = ... } from spell_action
    enemy_count = 1,
    is_boss = false,
}

local function reset_spy()
    spy.rage = 0
    spy.stance = 1
    spy.hp = 100
    spy.target_hp = 100
    spy.swing_until = 999
    spy.on_cd = {}
    spy.buffs = {}
    spy.debuff_remains = 0
    spy.target_casting = false
    spy.should_interrupt = false
    spy.aoe_target = true
    spy.aoe_self = true
    spy.op_proc = false
    spy.spell_calls = {}
    spy.enemy_count = 1
    spy.is_boss = false
end

local me = {
    -- W3.4 rage chain: the mock unit is deliberately get_rage-LESS (me:get_rage
    -- is not a game_object member — production reads context.rage first, then
    -- me:get_power(NS.POWER_RAGE)); any surviving me:get_rage() read in a spec
    -- errors loudly here (nil index) instead of silently returning rage.
    get_power = function(self, p) return spy.rage end,
    get_stance = function() return spy.stance end,
    get_health_percentage = function() return spy.hp end,
}

local target = {
    get_health_percentage = function() return spy.target_hp end,
    is_casting = function() return spy.target_casting end,
    get_dodge_chance = function() return 0 end,
}

-- Battery-shaped spell_action (mirrors behavioral_audit.lua:1144-1173):
-- define_action delegates here, so the rich object exposes ids/id()/rank_ids().
local function spell_action(rank_ids, label)
    local ids
    if type(rank_ids) == "table" then ids = rank_ids else ids = { rank_ids } end
    spy.spell_calls[#spy.spell_calls + 1] = { rank_ids = ids, label = label }
    local obj = {
        label = label,
        ids = ids,
        id = function(self) return ids[1] or ids[#ids] end,
        rank = function(self, r) return ids[r or #ids] end,
        cooldown = function(self) return 0 end,
        is_known = function(self) return true end,
        cooldown_remaining = function(self) return 0 end, -- deliberately mock-only: specs must NOT read this
    }
    obj.rank_ids = function() return ids end
    return obj
end

-- Real-API cooldown read the specs must use (mirrors core_sylvanas.lua:
-- NS.cooldown_remains / NS.get_spell_cooldown, 0 = ready). Spy-driven so the
-- tests prove the production path is live, not the 99 fallback.
local function cooldown_remains(action)
    local id
    if type(action) == "table" and type(action.id) == "function" then
        id = action:id()
    elseif type(action) == "table" and action.ids then
        id = action.ids[1]
    else
        id = action
    end
    return spy.on_cd[id] or 0
end

local function buff_up(unit, ids)
    for _, id in ipairs(ids or {}) do
        if spy.buffs[id] then return true end
    end
    return false
end

package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }
package.loaded["shared/leveling_helpers_sylvanas"] = {
    should_interrupt = function(t) return spy.should_interrupt end,
}

_G.EaxRotations = {
    WarriorSpells = {},  -- wotlk files use plain define_action, not the class table
    WarriorConstants = { STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 } },
    POWER_RAGE = 1,      -- core_sylvanas.lua:307 (real power_type enum value)
    me = me,
    GetPlayer = function() return me end,
    AOE_RADIUS = { TARGET_8 = 8, SELF_8 = 8 },
    aoe_target_meets = function() return spy.aoe_target end,
    aoe_self_meets = function() return spy.aoe_self end,
    should_use_long_cd = function() return true end,
    gate_cooldown_boss_only = function() return false end,
    spell_action = spell_action,
    cooldown_remains = cooldown_remains,
    get_spell_cooldown = cooldown_remains,
    swing_time_until = function() return spy.swing_until end,
    buff_up = buff_up,
    debuff_remains = function() return spy.debuff_remains end,
    is_interruptible = function() return true end,
    same_unit = function(a, b) return a == b end,
    is_spell_learned = function() return true end,
    SwingDiagnostics = {
        is_overpower_proc_active = function() return spy.op_proc end,
    },
    log = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registry = { name = name, strategies = strategies, options = options }
        end,
    },
}

local NS = _G.EaxRotations

local function find(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. tostring(name))
end

-- Reusable match helper: build_state(ctx) then strategy.matches(ctx, state).
local function matches(spec_module, strategy, ctx)
    local state = spec_module.build_state(ctx)
    return strategy.matches(ctx, state)
end

local function base_ctx()
    return {
        in_combat = true,
        target = target,
        me = me,
        settings = {},
        enemy_count = spy.enemy_count,
        -- W3.4: real dispatcher field (main_sylvanas.lua:1287) — the legacy
        -- context.is_boss compat read was deleted from arms_wotlk is_boss().
        target_is_boss = spy.is_boss,
    }
end

-- ============================================================================
-- ARMS
-- ============================================================================
local arms = dofile("EaxRotations/classes/warrior/arms_wotlk.lua")
assert_true(type(arms) == "table" and type(arms.build_state) == "function", "arms_wotlk returns module table")

-- Order: 21 strategies, DefensiveStance first, queued HS/Cleave near the top
local arms_order = {
    "DefensiveStance", "ShieldWall", "Retaliation", "BattleShout", "Cleave",
    "HeroicStrike", "Charge", "BerserkerStance", "BattleStance", "Intercept",
    "Pummel", "Rend", "Overpower", "MortalStrike", "Execute", "SweepingStrikes",
    "Bladestorm", "ThunderClap", "DemoralizingShout", "Hamstring", "Slam",
}
assert_eq(#arms.strategies, 21, "arms has 21 strategies")
for i = 1, #arms_order do
    assert_eq(arms.strategies[i].name, arms_order[i],
        "arms strategy " .. i .. " should be " .. arms_order[i])
end

-- ============================================================================
-- W3.4 rage chain: state.rage must flow through the REAL production path
-- (context.rage from main_sylvanas.lua:814, then me:get_power(NS.POWER_RAGE))
-- — me:get_rage() is mock-only and pinned every rage-gated lane at 0 live.
-- The mock unit is get_rage-less, so any surviving me:get_rage() read in a
-- spec errors loudly (attempt to call a nil value) instead of silently
-- returning a value.
-- ============================================================================
reset_spy()
spy.rage = 25
assert_eq(type(me.get_rage), "nil", "mock unit is get_rage-less (tripwire contract)")
local rage_ctx = base_ctx()
rage_ctx.rage = 25
local rage_state = arms.build_state(rage_ctx)
assert_eq(rage_state.rage, 25, "context.rage drives state.rage (context-first chain)")
local fallback_ctx = base_ctx()          -- no context.rage
local fallback_state = arms.build_state(fallback_ctx)
assert_eq(fallback_state.rage, 25, "me:get_power(NS.POWER_RAGE) is the fallback when context.rage is absent")
local exec25 = find(arms.strategies, "Execute")
spy.target_hp = 15                     -- execute window (arms reads target:get_health_percentage)
assert_true(matches(arms, exec25, rage_ctx),
    "arms Execute fires via context.rage = 25 in the execute window (battery arms_execute_rage proof)")
rage_ctx.rage = 14
assert_false(matches(arms, exec25, rage_ctx), "arms Execute must not fire at 14 rage via context.rage")
spy.target_hp = 100
spy.rage = 0

-- Must: cooldown gates read NS.cooldown_remains (real API), not the mock-only
-- action:cooldown_remaining() (which would 99-fallback and never-fire MS).
reset_spy()
local ctx = base_ctx()
spy.rage = 30
spy.on_cd = { [47486] = 3 }  -- MortalStrike max rank on CD
local ms = find(arms.strategies, "MortalStrike")
assert_false(matches(arms, ms, ctx), "MortalStrike must not fire while on CD (real API read)")
spy.on_cd = {}
assert_true(matches(arms, ms, ctx), "MortalStrike fires when the real CD API reports ready")

-- Must: WotLK Execute costs 15 rage
reset_spy()
spy.rage = 14
spy.target_hp = 15
local exec = find(arms.strategies, "Execute")
assert_false(matches(arms, exec, ctx), "Execute must not fire at 14 rage")
spy.rage = 15
assert_true(matches(arms, exec, ctx), "Execute fires at 15 rage (WotLK cost)")

-- Must: Heroic Strike queues on the next auto swing (rage >= 40, swing <= 1s,
-- single target) — not a bottom unqueued dump
reset_spy()
spy.rage = 40
spy.swing_until = 0.5
local hs = find(arms.strategies, "HeroicStrike")
assert_true(matches(arms, hs, ctx), "queued Heroic Strike fires at 40 rage with swing imminent")
spy.swing_until = 3.0
assert_false(matches(arms, hs, ctx), "Heroic Strike must not queue when the swing is > 1s away")
spy.swing_until = 0.5
spy.enemy_count = 2
local multi_ctx = base_ctx()
assert_false(matches(arms, hs, multi_ctx), "Heroic Strike is single-target only (Cleave covers multi)")
spy.enemy_count = 1
spy.rage = 39
assert_false(matches(arms, hs, base_ctx()), "Heroic Strike needs 40 rage")

-- Must: Cleave queues on the next auto swing (rage >= 35, 2+ targets)
reset_spy()
spy.rage = 35
spy.swing_until = 0.5
spy.enemy_count = 2
local clv = find(arms.strategies, "Cleave")
local aoe_ctx = base_ctx()
assert_true(matches(arms, clv, aoe_ctx), "queued Cleave fires at 35 rage with 2 targets and swing imminent")
spy.aoe_target = false
assert_false(matches(arms, clv, aoe_ctx), "Cleave must not fire without 2 nearby targets")
spy.aoe_target = true
spy.swing_until = 3.0
assert_false(matches(arms, clv, aoe_ctx), "Cleave must not queue when the swing is > 1s away")
spy.swing_until = 0.5
spy.rage = 34
assert_false(matches(arms, clv, base_ctx()), "Cleave needs 35 rage")

-- Must: Shield Wall + Retaliation are Defensive-stance-only in WotLK; the file
-- now dances to Defensive first (previously it never entered Defensive at all)
reset_spy()
spy.hp = 25
local sw = find(arms.strategies, "ShieldWall")
assert_false(matches(arms, sw, ctx), "Shield Wall must not fire in Battle stance")
spy.stance = 2
assert_true(matches(arms, sw, ctx), "Shield Wall fires in Defensive stance under 30% HP")
spy.stance = 1
spy.hp = 50
assert_false(matches(arms, sw, ctx), "Shield Wall must not fire above 30% HP")
local ds = find(arms.strategies, "DefensiveStance")
spy.hp = 25
assert_true(matches(arms, ds, ctx), "DefensiveStance dance fires for the Shield Wall need")
spy.hp = 100
spy.is_boss = true
spy.rage = 10
assert_true(matches(arms, ds, base_ctx()), "DefensiveStance dance fires for the Retaliation need")
local ret = find(arms.strategies, "Retaliation")
spy.stance = 1
assert_false(matches(arms, ret, ctx), "Retaliation must not fire in Battle stance")
spy.stance = 2
assert_true(matches(arms, ret, base_ctx()), "Retaliation fires in Defensive stance on a boss with rage")

-- Must: Overpower is proc-only (Taste for Blood) — no CD branch (WotLK OP has
-- no cooldown); the old unconditional lane fired every GCD
reset_spy()
spy.rage = 5
local op = find(arms.strategies, "Overpower")
assert_false(matches(arms, op, ctx), "Overpower must not fire without the Taste for Blood proc")
spy.buffs = { [60503] = true }
assert_true(matches(arms, op, ctx), "Overpower fires on the Taste for Blood proc")

-- Nit: Sweeping Strikes + Thunder Clap are Battle-stance-only
reset_spy()
spy.rage = 30
spy.enemy_count = 2
local ss = find(arms.strategies, "SweepingStrikes")
spy.stance = 3
assert_false(matches(arms, ss, base_ctx()), "Sweeping Strikes is Battle-only")
spy.stance = 1
assert_true(matches(arms, ss, base_ctx()), "Sweeping Strikes fires in Battle stance with 2 targets")
local tc = find(arms.strategies, "ThunderClap")
spy.rage = 20
spy.stance = 3
assert_false(matches(arms, tc, base_ctx()), "Thunder Clap is Battle-only")
spy.stance = 1
assert_true(matches(arms, tc, base_ctx()), "Thunder Clap fires in Battle stance")

-- ============================================================================
-- FURY
-- ============================================================================
reset_spy()
spy.stance = 3
local fury = dofile("EaxRotations/classes/warrior/fury_wotlk.lua")
assert_true(type(fury) == "table" and type(fury.build_state) == "function", "fury_wotlk returns module table")
assert_eq(#fury.strategies, 8, "fury has 8 strategies")

-- W3.4 rage chain: fury reads rage via the REAL chain (context.rage first,
-- then me:get_power(NS.POWER_RAGE)) — the mock unit is get_rage-less.
-- NOTE: no reset_spy() here — it would wipe spy.spell_calls collected at
-- module load (the DeathWish ladder check below reads them).
spy.stance = 3
spy.rage = 25
assert_eq(fury.build_state(base_ctx()).rage, 25,
    "fury state.rage via me:get_power(NS.POWER_RAGE) fallback")
local fury_ctx = base_ctx()
fury_ctx.rage = 30
assert_eq(fury.build_state(fury_ctx).rage, 30, "fury context.rage wins over the get_power fallback")

-- Must: Death Wish is the single rank 12292 — 12328 is Sweeping Strikes and
-- must not appear in the ladder (rank-list contamination)
local dw_def = nil
for _, c in ipairs(spy.spell_calls) do
    if c.label == "DeathWish" then dw_def = c end
end
assert_true(dw_def ~= nil, "DeathWish defined via spell_action")
assert_eq(#dw_def.rank_ids, 1, "DeathWish ladder is exactly one rank")
assert_eq(dw_def.rank_ids[1], 12292, "DeathWish rank is 12292")
assert_false(dw_def.rank_ids[1] == 12328, "DeathWish must NOT resolve to Sweeping Strikes 12328")

-- Must: Death Wish CD gate reads the real API (was the mock-only 99 fallback)
reset_spy()
spy.stance = 3
ctx = base_ctx()
spy.on_cd = { [12292] = 100 }
local dw = find(fury.strategies, "DeathWish")
assert_false(matches(fury, dw, ctx), "Death Wish must not fire while on CD")
spy.on_cd = {}
assert_true(matches(fury, dw, ctx), "Death Wish fires when the real CD API reports ready")

-- Must: Execute costs 15 rage
reset_spy()
spy.stance = 3
spy.rage = 14
spy.target_hp = 15
local fexec = find(fury.strategies, "Execute")
assert_false(matches(fury, fexec, ctx), "fury Execute must not fire at 14 rage")
spy.rage = 15
assert_true(matches(fury, fexec, ctx), "fury Execute fires at 15 rage")

-- Must: Bloodthirst + Whirlwind lanes have real CD gates (were unconditional)
reset_spy()
spy.stance = 3
spy.rage = 30
local bt = find(fury.strategies, "Bloodthirst")
spy.on_cd = { [30335] = 2 }
assert_false(matches(fury, bt, ctx), "Bloodthirst must not fire while on CD")
spy.on_cd = {}
assert_true(matches(fury, bt, ctx), "Bloodthirst fires off CD with rage")
local ww = find(fury.strategies, "Whirlwind")
spy.rage = 25
spy.on_cd = { [1680] = 1 }
assert_false(matches(fury, ww, ctx), "Whirlwind must not fire while on CD")
spy.on_cd = {}
spy.stance = 1
assert_false(matches(fury, ww, ctx), "Whirlwind is Berserker-only")
spy.stance = 3
assert_true(matches(fury, ww, ctx), "Whirlwind fires off CD in Berserker stance")

-- Must: Slam is Bloodsurge-proc-gated, not an every-GCD filler
reset_spy()
spy.stance = 3
spy.rage = 15
local slam = find(fury.strategies, "Slam")
assert_false(matches(fury, slam, ctx), "Slam must not fire without a Bloodsurge proc")
spy.buffs = { [46916] = true }
assert_true(matches(fury, slam, ctx), "Slam fires on the Bloodsurge proc (46916)")
spy.buffs = { [70847] = true }
assert_true(matches(fury, slam, ctx), "Slam fires on the rank-2 Bloodsurge proc (70847)")

-- Must: Pummel is Berserker-only + 10 rage
reset_spy()
spy.stance = 3
spy.rage = 10
spy.target_casting = true
local fp = find(fury.strategies, "Pummel")
assert_true(matches(fury, fp, ctx), "fury Pummel fires in Berserker stance with rage")
spy.rage = 9
assert_false(matches(fury, fp, ctx), "fury Pummel needs 10 rage")
spy.rage = 10
spy.stance = 1
assert_false(matches(fury, fp, ctx), "fury Pummel is Berserker-only")

-- Must: BerserkerStance enforcement lane (APL final lane 2458) dances back
reset_spy()
spy.stance = 1
local bz = find(fury.strategies, "BerserkerStance")
assert_true(matches(fury, bz, ctx), "BerserkerStance dance fires out of Berserker")
spy.stance = 3
assert_false(matches(fury, bz, ctx), "BerserkerStance does not re-cast in Berserker")

-- ============================================================================
-- PROTECTION
-- ============================================================================
reset_spy()
spy.stance = 2
local prot = dofile("EaxRotations/classes/warrior/protection_wotlk.lua")
assert_true(type(prot) == "table" and type(prot.build_state) == "function", "protection_wotlk returns module table")

local prot_order = {
    "LastStand", "BerserkerStance", "Pummel", "HeroicStrike", "ShieldBlock",
    "ShieldSlam", "Revenge", "ThunderClap", "Devastate",
}
assert_eq(#prot.strategies, 9, "protection has 9 strategies")

-- W3.4 rage chain: protection reads rage via the REAL chain (context.rage
-- first, then me:get_power(NS.POWER_RAGE)) — the mock unit is get_rage-less.
-- NOTE: no reset_spy() here — it would wipe spy.spell_calls collected at
-- module load (the Revenge ladder check below reads them).
spy.stance = 2
spy.rage = 25
assert_eq(prot.build_state(base_ctx()).rage, 25,
    "protection state.rage via me:get_power(NS.POWER_RAGE) fallback")
for i = 1, #prot_order do
    assert_eq(prot.strategies[i].name, prot_order[i],
        "protection strategy " .. i .. " should be " .. prot_order[i])
end

-- Must: Revenge ladder tops at 57823 (WotLK max rank; 30357 is TBC-era)
local rv_def = nil
for _, c in ipairs(spy.spell_calls) do
    if c.label == "Revenge" then rv_def = c end
end
assert_true(rv_def ~= nil, "Revenge defined via spell_action")
assert_eq(rv_def.rank_ids[1], 57823, "Revenge max rank 57823 sits at the ladder top")

-- Must: Shield Block 60-rage cost + need condition (charge economy)
reset_spy()
spy.stance = 2
ctx = base_ctx()
spy.rage = 60
spy.hp = 50
local sb = find(prot.strategies, "ShieldBlock")
assert_true(matches(prot, sb, ctx), "Shield Block fires at 60 rage under 70% HP")
spy.hp = 90
spy.enemy_count = 1
assert_false(matches(prot, sb, base_ctx()), "Shield Block must not fire at full HP on one target (rage waste)")
spy.enemy_count = 3
assert_true(matches(prot, sb, base_ctx()), "Shield Block fires at 60 rage with 3 enemies")
spy.enemy_count = 1
spy.hp = 50
spy.rage = 59
assert_false(matches(prot, sb, ctx), "Shield Block needs 60 rage")

-- Must: Pummel requires Berserker Stance; the dance lane makes it reachable
reset_spy()
spy.stance = 2
spy.rage = 10
spy.target_casting = true
local pp = find(prot.strategies, "Pummel")
assert_false(matches(prot, pp, ctx), "prot Pummel must not fire in Defensive stance")
spy.stance = 3
assert_true(matches(prot, pp, ctx), "prot Pummel fires in Berserker stance")
local pdz = find(prot.strategies, "BerserkerStance")
spy.stance = 2
assert_true(matches(prot, pdz, ctx), "BerserkerStance dance fires for the Pummel need")
spy.stance = 3
assert_false(matches(prot, pdz, ctx), "BerserkerStance does not re-cast in Berserker")

-- Must: Heroic Strike queues on the next auto swing (rage >= 30)
reset_spy()
spy.stance = 2
spy.rage = 30
spy.swing_until = 0.5
local phs = find(prot.strategies, "HeroicStrike")
assert_true(matches(prot, phs, ctx), "prot Heroic Strike queues at 30 rage with swing imminent")
spy.swing_until = 3.0
assert_false(matches(prot, phs, ctx), "prot Heroic Strike must not queue when the swing is > 1s away")
spy.swing_until = 0.5
spy.rage = 29
assert_false(matches(prot, phs, ctx), "prot Heroic Strike needs 30 rage")

-- Must: Last Stand (APL's FIRST priority) emergency at < 30% HP
reset_spy()
spy.stance = 2
spy.hp = 25
local ls = find(prot.strategies, "LastStand")
assert_true(matches(prot, ls, ctx), "Last Stand fires under 30% HP")
spy.hp = 50
assert_false(matches(prot, ls, ctx), "Last Stand must not fire above 30% HP")
spy.hp = 25
spy.on_cd = { [12975] = 100 }
assert_false(matches(prot, ls, ctx), "Last Stand must not fire while on CD")

-- Nit: Shield Slam + Revenge CD checks via the real API
reset_spy()
spy.stance = 2
spy.rage = 20
local ssl = find(prot.strategies, "ShieldSlam")
spy.on_cd = { [47488] = 4 }
assert_false(matches(prot, ssl, ctx), "Shield Slam must not fire while on CD")
spy.on_cd = {}
assert_true(matches(prot, ssl, ctx), "Shield Slam fires off CD with rage")
spy.rage = 5
local rvv = find(prot.strategies, "Revenge")
spy.on_cd = { [57823] = 3 }
assert_false(matches(prot, rvv, ctx), "Revenge must not fire while on CD")
spy.on_cd = {}
assert_true(matches(prot, rvv, ctx), "Revenge fires off CD with rage")

-- ============================================================================
-- LEVELING
-- ============================================================================
reset_spy()
spy.stance = 1
local lvl = dofile("EaxRotations/classes/warrior/leveling_wotlk.lua")
assert_true(type(lvl) == "table" and type(lvl.build_state) == "function", "leveling_wotlk returns module table")
assert_eq(#lvl.strategies, 12, "leveling has 12 strategies")

-- W3.4 rage chain: leveling reads rage via the REAL chain (context.rage
-- first, then me:get_power(NS.POWER_RAGE)) — the mock unit is get_rage-less.
-- NOTE: no reset_spy() here — it would wipe spy.spell_calls collected at
-- module load (the Pummel ladder check below reads them).
spy.stance = 1
spy.rage = 25
assert_eq(lvl.build_state(base_ctx()).rage, 25,
    "leveling state.rage via me:get_power(NS.POWER_RAGE) fallback")

-- Nit: Pummel ladder tops at 6554 (WotLK rank 2; 6552 is the TBC-era rank 1)
local pm_def = nil
for _, c in ipairs(spy.spell_calls) do
    if c.label == "Pummel" then pm_def = c end
end
assert_true(pm_def ~= nil, "leveling Pummel defined via spell_action")
assert_eq(pm_def.rank_ids[1], 6554, "Pummel ladder tops at 6554")
assert_eq(pm_def.rank_ids[2], 6552, "Pummel ladder keeps 6552 as fallback")

-- Must: Victory Rush requires the killing-blow proc (Victory Rush aura 34428)
reset_spy()
spy.stance = 1
ctx = base_ctx()
local vr = find(lvl.strategies, "VictoryRush")
assert_false(matches(lvl, vr, ctx), "Victory Rush must not fire without the killing-blow proc")
spy.buffs = { [34428] = true }
assert_true(matches(lvl, vr, ctx), "Victory Rush fires on the killing-blow proc")

-- Must: Overpower is dodge-proc-gated (5 rage, Battle stance)
reset_spy()
spy.stance = 1
spy.rage = 5
local lop = find(lvl.strategies, "Overpower")
assert_false(matches(lvl, lop, ctx), "Overpower must not fire outside the dodge-proc window")
spy.op_proc = true
assert_true(matches(lvl, lop, ctx), "Overpower fires inside the proc window")
spy.op_proc = false
spy.rage = 4
assert_false(matches(lvl, lop, ctx), "Overpower needs 5 rage")

-- Must: Execute costs 15 rage
reset_spy()
spy.stance = 1
spy.target_hp = 15
spy.rage = 14
local lex = find(lvl.strategies, "Execute")
assert_false(matches(lvl, lex, ctx), "leveling Execute must not fire at 14 rage")
spy.rage = 15
assert_true(matches(lvl, lex, ctx), "leveling Execute fires at 15 rage")

-- Must: Charge only inside the 8-25 yd band
reset_spy()
spy.stance = 1
local chg = find(lvl.strategies, "Charge")
local ooc = { in_combat = false, target = target, me = me, settings = {}, target_distance = 15 }
assert_true(matches(lvl, chg, ooc), "Charge fires at 15 yd out of combat")
ooc.target_distance = 5
assert_false(matches(lvl, chg, ooc), "Charge must not fire at 5 yd (melee)")
ooc.target_distance = 30
assert_false(matches(lvl, chg, ooc), "Charge must not fire at 30 yd (out of range)")

-- Nit: Rend costs 10 rage
reset_spy()
spy.stance = 1
spy.rage = 9
local rend = find(lvl.strategies, "Rend")
assert_false(matches(lvl, rend, ctx), "Rend must not fire at 9 rage")
spy.rage = 10
assert_true(matches(lvl, rend, ctx), "Rend fires at 10 rage when the dot is missing")

print("PASS test_warrior_wotlk_live_fixes")
