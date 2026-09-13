-- test_shaman_elemental_wotlk_strategies.lua — Elemental shaman WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL elemental_wotlk.lua through its real build_state read
--        path (NS.debuff_remains for the Flame Shock 49233 debuff, NS.spell_ready
--        for the Bloodlust/Fire Elemental/Elemental Mastery CD windows,
--        NS.get_totem_info for the fire/air totem slots, NS.buff_up for the
--        Fire Elemental / Totem of Wrath auras, target:is_casting, ctx fields),
--        pinning both sides of every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): elemental had no real-read
--        behavioral pins; these exercise the real CD and totem plumbing.
-- SAFETY: Pure unit tests with a mocked NS; the real elemental_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local combat = true
local mana = 100
local enemy_count = 1
local casting = false
local debuffs = {}
local buffs = {}
local not_ready = {}
local totem_slots = {}   -- slot -> { have_totem = bool }

local function flame(secs) debuffs[49233] = secs end

local function reset_env()
    combat, mana, enemy_count, casting = true, 100, 1, false
    debuffs, buffs, not_ready, totem_slots = {}, {}, {}, {}
end

_G.EaxRotations = {
    me = { get_health_percentage = function() return 100 end },
    GetPlayer = function() return _G.EaxRotations.me end,
    debuff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if debuffs[id] then return debuffs[id] end
        end
        return 0
    end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    spell_ready = function(spell, unit, opts)
        local id = type(spell) == "number" and spell or (spell and spell.id) or 0
        if not_ready[id] then return false end
        return true
    end,
    get_totem_info = function(slot) return totem_slots[slot] end,
    -- Cast backend the opener progress wrapper reports through. Only the
    -- execute path uses it; the match-gate pins above never call it.
    try_cast = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/shaman/elemental_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "elemental_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local cast_remaining = nil
local cast_lead = nil
local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        mana_pct = mana,
        enemy_count = enemy_count,
        target = { is_casting = function() return casting end },
        settings = { interrupt_lead_sec = cast_lead }, target_cast_remaining = cast_remaining,
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
-- WindShear: in combat + the target is casting.
-- ============================================================================
assert_lane("WindShear fires on an enemy cast", "WindShear", function() casting = true end, true)
assert_lane("WindShear blocked when nothing is casting", "WindShear", function() end, false)
assert_lane("WindShear blocked out of combat", "WindShear",
    function() combat = false; casting = true end, false)

-- ============================================================================
-- EarthShock: WotLK instant-damage (kick removed 3.0.2) — fires while casting.
-- ============================================================================
assert_lane("EarthShock fires while the target casts", "EarthShock", function() casting = true end, true)
assert_lane("EarthShock blocked when nothing is casting", "EarthShock", function() end, false)

-- ============================================================================
-- Bloodlust / FireElemental / ElementalMastery: real spell_ready CD windows.
-- ============================================================================
assert_lane("Bloodlust fires when ready", "Bloodlust", function() end, true)
assert_lane("Bloodlust held on cooldown", "Bloodlust", function() not_ready[2825] = true end, false)
assert_lane("FireElemental fires when ready", "FireElemental", function() end, true)
assert_lane("FireElemental held on cooldown", "FireElemental", function() not_ready[2894] = true end, false)
assert_lane("ElementalMastery fires when ready", "ElementalMastery", function() end, true)
assert_lane("ElementalMastery held on cooldown", "ElementalMastery", function() not_ready[16166] = true end, false)

-- ============================================================================
-- TotemOfWrath: buff down AND air slot (4) free — pre-pull and mid-fight.
-- ============================================================================
assert_lane("Totem of Wrath drops when down and the air slot is free",
    "TotemOfWrath", function() end, true)
assert_lane("Totem of Wrath held while the aura is up",
    "TotemOfWrath", function() buffs[57722] = true end, false)
assert_lane("Totem of Wrath held when the air slot is occupied",
    "TotemOfWrath", function() totem_slots[4] = { have_totem = true } end, false)

-- ============================================================================
-- SearingTotem: in combat + no Fire Elemental active + fire slot (1) free.
-- ============================================================================
assert_lane("Searing Totem drops in combat with the fire slot free",
    "SearingTotem", function() end, true)
assert_lane("Searing Totem blocked while the Fire Elemental is active",
    "SearingTotem", function() buffs[2894] = true end, false)
assert_lane("Searing Totem blocked when the fire slot is occupied",
    "SearingTotem", function() totem_slots[1] = { have_totem = true } end, false)
assert_lane("Searing Totem blocked out of combat",
    "SearingTotem", function() combat = false end, false)

-- ============================================================================
-- FlameShock: in combat + remains < 3 + mana >= 15.
-- ============================================================================
assert_lane("FlameShock refreshes when the debuff is down", "FlameShock", function() end, true)
assert_lane("FlameShock refreshes at 2.9s remaining", "FlameShock", function() flame(2.9) end, true)
assert_lane("FlameShock blocked at the 3.0s boundary", "FlameShock", function() flame(3) end, false)
assert_lane("FlameShock blocked below 15% mana", "FlameShock", function() mana = 14 end, false)
assert_lane("FlameShock blocked out of combat", "FlameShock", function() combat = false end, false)

-- ============================================================================
-- LavaBurst: guaranteed crit while Flame Shock is live (remains >= 1) + mana.
-- ============================================================================
assert_lane("LavaBurst fires while Flame Shock is live", "LavaBurst",
    function() flame(12) end, true)
assert_lane("LavaBurst fires with 1s of Flame Shock left", "LavaBurst",
    function() flame(1) end, true)
assert_lane("LavaBurst blocked below 1s of Flame Shock", "LavaBurst",
    function() flame(0.9) end, false)
assert_lane("LavaBurst blocked when Flame Shock is down (no crit)", "LavaBurst",
    function() end, false)
assert_lane("LavaBurst blocked below 20% mana", "LavaBurst",
    function() flame(12); mana = 19 end, false)

-- ============================================================================
-- ChainLightning: cleave at 2+ enemies + mana >= 25.
-- ============================================================================
assert_lane("Chain Lightning fires at 2 enemies", "ChainLightning",
    function() enemy_count = 2 end, true)
assert_lane("Chain Lightning blocked single-target", "ChainLightning", function() end, false)
assert_lane("Chain Lightning blocked below 25% mana", "ChainLightning",
    function() enemy_count = 2; mana = 24 end, false)

-- ============================================================================
-- Thunderstorm: mana return below 50%.
-- ============================================================================
assert_lane("Thunderstorm fires at 49% mana", "Thunderstorm", function() mana = 49 end, true)
assert_lane("Thunderstorm blocked at 50% mana", "Thunderstorm", function() mana = 50 end, false)

-- ============================================================================
-- LightningBolt: filler at >= 15% mana.
-- ============================================================================
assert_lane("Lightning Bolt fires at 15% mana", "LightningBolt", function() mana = 15 end, true)
assert_lane("Lightning Bolt blocked below 15% mana", "LightningBolt", function() mana = 14 end, false)


-- ============================================================================
-- Engine cast/channel end-time gate (2026-09-12, shared/cast_timing_sylvanas).
-- WindShear must HOLD when the target's cast is about to land (the interrupt
-- would arrive too late and burn its cooldown) and FIRE on a normal cast.
-- Unknown remaining (nil) keeps the pre-signal fail-open behavior.
-- ============================================================================
assert_lane("WindShear fires with 1.0s left on the enemy cast", "WindShear",
    function() casting = true; cast_remaining = 1.0; cast_lead = nil end, true)
assert_lane("WindShear holds when only 0.05s of the cast remains", "WindShear",
    function() casting = true; cast_remaining = 0.05; cast_lead = nil end, false)
assert_lane("WindShear holds ON the 0.30s lead floor", "WindShear",
    function() casting = true; cast_remaining = 0.30; cast_lead = nil end, false)
assert_lane("WindShear fires above the 0.30s lead floor", "WindShear",
    function() casting = true; cast_remaining = 0.31; cast_lead = nil end, true)
assert_lane("WindShear honours a raised interrupt_lead_sec setting", "WindShear",
    function() casting = true; cast_remaining = 0.9; cast_lead = 1.2 end, false)
-- ============================================================================
-- Engine cast/channel end-time gate (2026-09-12, shared/cast_timing_sylvanas).
-- EarthShock must HOLD when the target's cast is about to land (the interrupt
-- would arrive too late and burn its cooldown) and FIRE on a normal cast.
-- Unknown remaining (nil) keeps the pre-signal fail-open behavior.
-- ============================================================================
assert_lane("EarthShock fires with 1.0s left on the enemy cast", "EarthShock",
    function() casting = true; cast_remaining = 1.0; cast_lead = nil end, true)
assert_lane("EarthShock holds when only 0.05s of the cast remains", "EarthShock",
    function() casting = true; cast_remaining = 0.05; cast_lead = nil end, false)
assert_lane("EarthShock holds ON the 0.30s lead floor", "EarthShock",
    function() casting = true; cast_remaining = 0.30; cast_lead = nil end, false)
assert_lane("EarthShock fires above the 0.30s lead floor", "EarthShock",
    function() casting = true; cast_remaining = 0.31; cast_lead = nil end, true)
assert_lane("EarthShock honours a raised interrupt_lead_sec setting", "EarthShock",
    function() casting = true; cast_remaining = 0.9; cast_lead = 1.2 end, false)

-- ============================================================================
-- Ordered boss opener (2026-09-13, shared/boss_opener_sylvanas).
-- Off a boss the sequencer is INERT (every lane above fires independently).
-- On a raid boss only the HEAD of the declared order may leave:
--   FireElemental -> Bloodlust -> ElementalMastery,
-- and once the sequence completes every lane falls back to its own CD gate, so
-- the 5-minute Heroism can come back inside the same fight. Loading a lane
-- through its real execute() is what advances the head, so a refused cast
-- (execute returns false) would hold it.
-- ============================================================================
local function scenario_boss(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        mana_pct = mana,
        enemy_count = enemy_count,
        target = { is_casting = function() return casting end },
        settings = { interrupt_lead_sec = cast_lead },
        target_cast_remaining = cast_remaining,
        target_is_boss = true,
    }
    local state = result.build_state(ctx)
    local matched = find_strategy(strategy_name).matches(ctx, state)
    if expect then
        assert_true(matched, label .. " should match")
    else
        assert_false(matched, label .. " should NOT match")
    end
end

local function assert_boss_lane(label, strategy_name, expect)
    reset_env()
    scenario_boss(label, strategy_name, expect)
end

-- Load a lane through its real execute(), which is what advances the opener.
local function land_lane(strategy_name)
    local ctx = {
        in_combat = true,
        mana_pct = 100,
        enemy_count = 1,
        target = { is_casting = function() return false end },
        settings = {},
        target_is_boss = true,
    }
    local state = result.build_state(ctx)
    return find_strategy(strategy_name).execute(ctx, state)
end

-- Inert off a boss: FireElemental wins on its own CD gate. This is also what
-- returns the head to step 1 (the opener resets whenever it disarms).
reset_env()
scenario("opener inert on trash (resets the head)", "FireElemental", true)

-- Boss, all three CDs ready: only step 1 may leave.
assert_boss_lane("boss opener step 1: FireElemental fires", "FireElemental", true)
assert_boss_lane("boss opener step 2: Bloodlust holds behind the elemental", "Bloodlust", false)
assert_boss_lane("boss opener step 3: ElementalMastery holds last", "ElementalMastery", false)

-- Step 1 lands -> step 2 owns the turn.
assert_true(land_lane("FireElemental"), "FireElemental execute must land")
assert_boss_lane("after step 1: FireElemental holds", "FireElemental", false)
assert_boss_lane("after step 1: Bloodlust fires", "Bloodlust", true)
assert_boss_lane("after step 1: ElementalMastery still holds", "ElementalMastery", false)

-- Step 2 lands -> step 3 owns the turn.
assert_true(land_lane("Bloodlust"), "Bloodlust execute must land")
assert_boss_lane("after step 2: Bloodlust holds", "Bloodlust", false)
assert_boss_lane("after step 2: ElementalMastery fires", "ElementalMastery", true)

-- Step 3 lands -> the sequence is complete and every lane is free again.
assert_true(land_lane("ElementalMastery"), "ElementalMastery execute must land")
assert_boss_lane("after step 3: the opener is satisfied, Bloodlust is free", "Bloodlust", true)
assert_boss_lane("after step 3: FireElemental is free on its own cooldown", "FireElemental", true)

-- A boss pull that ends resets the order for the next one.
reset_env()
scenario("off a boss the next pull starts the order over", "FireElemental", true)
assert_boss_lane("new boss pull: step 1 again", "FireElemental", true)
assert_boss_lane("new boss pull: step 2 still waits", "Bloodlust", false)

print("PASS test_shaman_elemental_wotlk_strategies")
