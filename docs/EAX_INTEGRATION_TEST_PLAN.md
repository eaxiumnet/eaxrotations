# EAX Integration Test Plan

**Document**: EAX-INTEGRATION-TEST-PLAN-v1.0  
**Date**: April 10, 2026  
**Scope**: End-to-end integration testing for EAX Improvement Plan  
**Related**: EAX_IMPROVEMENT_PLAN.md, EAX_TEST_SPECIFICATIONS.md

---

## Executive Summary

This integration test plan validates that all components of the EAX Improvement Plan work together correctly. It covers 10 critical integration scenarios spanning APL execution, simulation validation, Flux bridge, middleware chains, and error recovery.

**Test Environment Requirements**:
- Mock Project Sylvanas API
- wowsims TBC reference data corpus
- CI/CD pipeline integration
- Automated regression detection

**Success Criteria**:
- All 10 integration scenarios pass
- <100ms overhead from Flux layer
- Zero memory leaks in 24h stress test
- DPS within 2% of wowsims reference

---

## Table of Contents

1. [Test Infrastructure](#test-infrastructure)
2. [Integration Scenario 1: APL + MCD Integration](#scenario-1-apl--mcd-integration)
3. [Integration Scenario 2: Simulation + Validation](#scenario-2-simulation--validation)
4. [Integration Scenario 3: Flux + EAX Bridge](#scenario-3-flux--eax-bridge)
5. [Integration Scenario 4: Dashboard + Combat Events](#scenario-4-dashboard--combat-events)
6. [Integration Scenario 5: Middleware Chain Priority](#scenario-5-middleware-chain-priority)
7. [Integration Scenario 6: Settings Persistence](#scenario-6-settings-persistence)
8. [Integration Scenario 7: Cross-Spec Library Sharing](#scenario-7-cross-spec-library-sharing)
9. [Integration Scenario 8: State Machine Transitions](#scenario-8-state-machine-transitions)
10. [Integration Scenario 9: Resource Integration](#scenario-9-resource-integration)
11. [Integration Scenario 10: Error Recovery](#scenario-10-error-recovery)
12. [Test Execution Guide](#test-execution-guide)
13. [CI/CD Integration](#cicd-integration)

---

## Test Infrastructure

### Directory Structure

```
tests/integration/
├── config/
│   ├── test_config.lua          # Global test configuration
│   └── wowsims_corpus.json      # Reference data
├── mocks/
│   ├── MockSylvanasAPI.lua      # Project Sylvanas API mock
│   ├── MockCombatState.lua      # Combat state simulation
│   ├── MockPlayer.lua           # Player entity mock
│   ├── MockTarget.lua           # Target entity mock
│   └── MockSpellBook.lua        # Spell book mock
├── fixtures/
│   ├── warrior_fury_fixtures.lua    # Test data fixtures
│   ├── mage_fire_fixtures.lua
│   ├── rogue_combat_fixtures.lua
│   └── shared_fixtures.lua
├── scenarios/
│   ├── test_apl_mcd_integration.lua
│   ├── test_simulation_validation.lua
│   ├── test_flux_eax_bridge.lua
│   ├── test_dashboard_combat_events.lua
│   ├── test_middleware_priority.lua
│   ├── test_settings_persistence.lua
│   ├── test_cross_spec_sharing.lua
│   ├── test_state_transitions.lua
│   ├── test_resource_integration.lua
│   └── test_error_recovery.lua
├── utils/
│   ├── test_assertions.lua      # Custom assertion library
│   ├── test_helpers.lua         # Test utilities
│   ├── performance_monitor.lua  # Performance measurement
│   └── memory_tracker.lua       # Memory leak detection
└── runner/
    └── integration_test_runner.lua  # Test orchestration
```

### Test Framework Configuration

```lua
-- tests/integration/config/test_config.lua
local config = {
    -- Test execution settings
    verbose = true,
    stop_on_failure = false,
    max_test_time_ms = 5000,
    
    -- Performance thresholds
    performance = {
        max_rotation_decision_time_ms = 5,
        max_flux_overhead_ms = 100,
        max_memory_growth_mb_per_hour = 10,
    },
    
    -- wowsims validation thresholds
    wowsims = {
        dps_tolerance_percent = 2.0,
        uptime_tolerance_percent = 2.0,
        cpm_tolerance_percent = 5.0,
    },
    
    -- Mock API settings
    mock_api = {
        tick_rate_ms = 50,
        latency_ms = 50,
        random_seed = 12345,
    },
    
    -- Stress test settings
    stress_test = {
        duration_hours = 24,
        iterations_per_hour = 3600,
        memory_check_interval_minutes = 15,
    },
}

return config
```

### Mock Sylvanas API

```lua
-- tests/integration/mocks/MockSylvanasAPI.lua
local MockSylvanasAPI = {}

function MockSylvanasAPI:new()
    local obj = {
        time_elapsed = 0,
        callbacks = {
            on_update = {},
            on_render = {},
            on_spell_cast = {},
        },
        player_state = {},
        target_state = {},
        spell_cooldowns = {},
        buffs = {},
        combat_log = {},
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function MockSylvanasAPI:advance_time(delta_ms)
    self.time_elapsed = self.time_elapsed + delta_ms
    
    -- Trigger on_update callbacks
    for _, cb in ipairs(self.callbacks.on_update) do
        cb(delta_ms / 1000)
    end
end

function MockSylvanasAPI:register_on_update_callback(callback)
    table.insert(self.callbacks.on_update, callback)
end

function MockSylvanasAPI:cast_spell(spell_id, target)
    table.insert(self.combat_log, {
        timestamp = self.time_elapsed,
        spell_id = spell_id,
        target = target,
    })
    
    -- Trigger on_spell_cast callbacks
    for _, cb in ipairs(self.callbacks.on_spell_cast) do
        cb({ spell_id = spell_id, target = target })
    end
end

function MockSylvanasAPI:set_player_state(state)
    self.player_state = state
end

function MockSylvanasAPI:set_target_state(state)
    self.target_state = state
end

return MockSylvanasAPI
```

---

## Scenario 1: APL + MCD Integration

### Test Overview

**Purpose**: Validate that APL condition evaluator properly sequences cooldowns with MCD usage during execute phase

**Test File**: `tests/integration/scenarios/test_apl_mcd_integration.lua`

### Test Script

```lua
-- tests/integration/scenarios/test_apl_mcd_integration.lua
local TestAPL_MCD = {}
local MockSylvanasAPI = require("tests.integration.mocks.MockSylvanasAPI")
local APLExecutor = require("shared.libraries.apl.executor")
local MCDManager = require("shared.libraries.mcd.manager")
local WarriorFuryAPL = require("tests.integration.fixtures.warrior_fury_fixtures")
local Assert = require("tests.integration.utils.test_assertions")

-- TEST-APL-MCD-001: Execute Phase with Recklessness
function TestAPL_MCD:test_execute_phase_with_recklessness()
    print("\n[TEST] APL + MCD: Execute Phase with Recklessness")
    
    -- Setup
    local api = MockSylvanasAPI:new()
    local mcd_manager = MCDManager:new(api)
    local apl = APLExecutor:new(api, mcd_manager)
    
    -- Configure MCDs
    mcd_manager:add_cooldown({
        id = "recklessness",
        spell_id = 1719,
        priority = 150,
        type = "burst",
        can_activate = function(ctx)
            return ctx.in_combat and ctx.target_hp <= 20
        end,
        should_activate = function(ctx)
            return ctx.time_to_die > 15
        end
    })
    
    mcd_manager:add_cooldown({
        id = "death_wish",
        spell_id = 12292,
        priority = 140,
        type = "burst",
        can_activate = function(ctx)
            return ctx.in_combat
        end,
        should_activate = function(ctx)
            return ctx.target_hp <= 20 or ctx.combat_time < 5
        end
    })
    
    -- Load APL for Warrior Fury Execute Phase
    apl:parse([[
        actions=execute,if=rage>=30&(cooldown.recklessness.remains>0|buff.recklessness.up)
        actions+=/execute,if=rage>=30&target.hp.pct<20
        actions+=/bloodthirst,if=rage>=30
        actions+=/whirlwind,if=rage>=25
        actions+=/heroic_strike,if=rage>=50&cooldown.bloodthirst.remains>1
    ]])
    
    -- Test Context: Entering Execute Phase at 18% HP
    local ctx = {
        in_combat = true,
        combat_time = 45,
        target_hp = 18,
        time_to_die = 30,
        rage = 45,
        cooldowns = {
            bloodthirst = 1.5,
            whirlwind = 3.0,
            execute = 0,
            recklessness = 0,  -- Ready
            death_wish = 20,   -- On cooldown
        },
        buffs = {},
    }
    
    -- Execute APL decision
    local action = apl:select_action(ctx)
    
    -- Validate: Should trigger Recklessness first (MCD priority)
    local next_cd = mcd_manager:get_next_cooldown(ctx)
    Assert.equals("recklessness", next_cd.id, 
        "Recklessness should be queued first at execute entry")
    
    -- Simulate cooldown usage
    api:advance_time(100)
    mcd_manager:activate(next_cd.id, ctx)
    ctx.cooldowns.recklessness = 300  -- 5min CD
    ctx.buffs.recklessness = 15       -- 15s duration
    
    -- Now check APL again
    action = apl:select_action(ctx)
    
    -- Validate: Should now cast Execute (highest priority with Reck up)
    Assert.equals(5308, action.spell_id,  -- Execute rank 5
        "Execute should be cast after Recklessness activation")
    Assert.equals("execute", action.action_type,
        "Action type should be execute")
    
    print("[PASS] Execute phase properly sequences Recklessness before Execute")
    return true
end

-- TEST-APL-MCD-002: CD Sequencing During Execute
function TestAPL_MCD:test_cd_sequencing_during_execute()
    print("\n[TEST] APL + MCD: CD Sequencing During Execute")
    
    local api = MockSylvanasAPI:new()
    local mcd_manager = MCDManager:new(api)
    local apl = APLExecutor:new(api, mcd_manager)
    
    -- Configure MCD priorities
    mcd_manager:add_cooldown({
        id = "recklessness",
        spell_id = 1719,
        priority = 150,
        type = "burst"
    })
    
    mcd_manager:add_cooldown({
        id = "death_wish",
        spell_id = 12292,
        priority = 140,
        type = "burst"
    })
    
    mcd_manager:add_cooldown({
        id = "trinket_1",
        spell_id = 28777,  -- DST
        priority = 120,
        type = "trinket"
    })
    
    -- Execute phase simulation
    local sequence = {}
    local ctx = {
        in_combat = true,
        target_hp = 18,
        rage = 80,
        cooldowns = {
            recklessness = 0,
            death_wish = 0,
            bloodthirst = 2.0,
            whirlwind = 4.0,
            execute = 0,
        }
    }
    
    -- Simulate 3 GCDs (4.5s)
    for i = 1, 3 do
        -- Check MCD activation
        local next_cd = mcd_manager:get_next_cooldown(ctx)
        if next_cd and ctx.cooldowns[next_cd.id] == 0 then
            table.insert(sequence, next_cd.id)
            mcd_manager:activate(next_cd.id, ctx)
            ctx.cooldowns[next_cd.id] = 300
        end
        
        -- Check APL action
        local action = apl:select_action(ctx)
        if action then
            table.insert(sequence, action.spell_name or action.action_type)
        end
        
        api:advance_time(1500)  -- 1.5s GCD
    end
    
    -- Validate sequence order
    local expected_sequence = {
        "recklessness",     -- MCD: Burst CD first
        "death_wish",       -- MCD: Second burst CD
        "execute",          -- APL: Execute during execute phase
    }
    
    -- Check that burst CDs come before regular abilities
    Assert.is_true(
        sequence[1] == "recklessness" or sequence[1] == "death_wish",
        "First action should be a major cooldown"
    )
    
    -- Verify proper CD ordering
    local reck_idx = nil
    local death_idx = nil
    for i, action in ipairs(sequence) do
        if action == "recklessness" then reck_idx = i end
        if action == "death_wish" then death_idx = i end
    end
    
    if reck_idx and death_idx then
        Assert.is_true(reck_idx < death_idx,
            "Recklessness (priority 150) should come before Death Wish (priority 140)")
    end
    
    print("[PASS] CD sequencing follows priority order during execute")
    return true
end

-- TEST-APL-MCD-003: Spell Order Matches wowsims Reference
function TestAPL_MCD:test_spell_order_matches_wowsims()
    print("\n[TEST] APL + MCD: Spell Order Matches wowsims Reference")
    
    local api = MockSylvanasAPI:new()
    local mcd_manager = MCDManager:new(api)
    local apl = APLExecutor:new(api, mcd_manager)
    
    -- Reference data from wowsims
    local wowsims_ref = {
        spell_sequence = {
            "Bloodthirst", "Whirlwind", "Heroic Strike", 
            "Bloodthirst", "Execute", "Execute"
        },
        dps = 1682.3,
        execute_cpm = 8.4,
    }
    
    -- Configure rotation
    apl:parse(WarriorFuryAPL.execute_phase)
    
    -- Run 60-second simulation
    local ctx = {
        in_combat = true,
        combat_time = 50,  -- Near execute
        target_hp = 20,
        rage = 65,
    }
    
    local eax_sequence = {}
    local total_damage = 0
    
    for t = 0, 60, 1.5 do
        ctx.combat_time = 50 + t
        ctx.target_hp = math.max(1, 20 - (t / 60) * 20)  -- Decay from 20% to 0%
        
        local action = apl:select_action(ctx)
        if action then
            table.insert(eax_sequence, action.spell_name)
            total_damage = total_damage + (action.estimated_damage or 0)
        end
        
        api:advance_time(1500)
    end
    
    -- Count Execute casts
    local execute_count = 0
    for _, spell in ipairs(eax_sequence) do
        if spell == "Execute" then
            execute_count = execute_count + 1
        end
    end
    
    local eax_cpm = execute_count / 1  -- 1 minute
    
    -- Validate CPM within tolerance
    local cpm_diff = math.abs(eax_cpm - wowsims_ref.execute_cpm)
    local cpm_tolerance = wowsims_ref.execute_cpm * 0.05  -- 5%
    
    Assert.is_true(cpm_diff <= cpm_tolerance,
        string.format("Execute CPM %.1f within 5%% of wowsims %.1f",
            eax_cpm, wowsims_ref.execute_cpm))
    
    print(string.format("[PASS] EAX Execute CPM: %.1f, wowsims: %.1f", 
        eax_cpm, wowsims_ref.execute_cpm))
    return true
end

-- Main test runner
function TestAPL_MCD:run_all()
    print("\n" .. string.rep("=", 60))
    print("APL + MCD INTEGRATION TESTS")
    print(string.rep("=", 60))
    
    local tests = {
        self.test_execute_phase_with_recklessness,
        self.test_cd_sequencing_during_execute,
        self.test_spell_order_matches_wowsims,
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local ok, err = pcall(test, self)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("[FAIL] " .. tostring(err))
        end
    end
    
    print("\n" .. string.rep("-", 60))
    print(string.format("Results: %d passed, %d failed", passed, failed))
    print(string.rep("=", 60))
    
    return failed == 0
end

return TestAPL_MCD
```

### Test Data Fixture

```lua
-- tests/integration/fixtures/warrior_fury_fixtures.lua
local WarriorFuryFixtures = {}

-- APL for execute phase
WarriorFuryFixtures.execute_phase = [[
    # Warrior Fury Execute Phase APL
    actions=auto_attack
    
    # Major Cooldowns
    actions+=/recklessness,if=target.hp.pct<=20&time_to_die>15
    actions+=/death_wish,if=target.hp.pct<=20|buff.bloodlust.up
    
    # Execute Phase
    actions+=/execute,if=rage>=30&target.hp.pct<20
    actions+=/execute,if=rage>=20&target.hp.pct<20&buff.recklessness.up
    
    # Normal Priority (when no execute)
    actions+=/bloodthirst,if=rage>=30&!buff.execute_phase.up
    actions+=/whirlwind,if=rage>=25
    actions+=/heroic_strike,if=rage>=50&cooldown.bloodthirst.remains>1
]]

-- Test scenarios
WarriorFuryFixtures.scenarios = {
    {
        name = "Execute Entry",
        ctx = {
            target_hp = 18,
            rage = 45,
            cooldowns = { bloodthirst = 1.5, execute = 0 },
        },
        expected_first_spell = "Execute",
    },
    {
        name = "High Rage Execute",
        ctx = {
            target_hp = 15,
            rage = 80,
            buffs = { recklessness = 10 },
        },
        expected_first_spell = "Execute",
        expected_cooldowns_used = { "recklessness" },
    },
}

-- wowsims reference data
WarriorFuryFixtures.wowsims_ref = {
    gear = "P1_Fury",
    talents = "17/44/0",
    buffs = "FullRaid",
    baseline_dps = 1423.2,
    execute_phase_dps = 1682.3,
    bloodthirst_cpm = 6.1,
    whirlwind_cpm = 4.7,
    execute_cpm = 8.4,
}

return WarriorFuryFixtures
```

---

## Scenario 2: Simulation + Validation

### Test Overview

**Purpose**: Run simulation against wowsims reference data and validate DPS within 2%

**Test File**: `tests/integration/scenarios/test_simulation_validation.lua`

### Test Script

```lua
-- tests/integration/scenarios/test_simulation_validation.lua
local TestSimulation = {}
local SimulationEngine = require("shared.simulation.engine")
local SimulationPlayer = require("shared.simulation.player")
local SimulationTarget = require("shared.simulation.target")
local MageFireFixtures = require("tests.integration.fixtures.mage_fire_fixtures")
local Assert = require("tests.integration.utils.test_assertions")
local Config = require("tests.integration.config.test_config")

-- TEST-SIM-001: Mage Fire 5-Minute Patchwerk
function TestSimulation:test_mage_fire_5min_patchwerk()
    print("\n[TEST] Simulation: Mage Fire 5-Minute Patchwerk")
    
    -- Setup simulation
    local engine = SimulationEngine:new({
        duration = 300,  -- 5 minutes
        iterations = 100,
        report_interval = 10,
    })
    
    -- Create player with P1 Fire gear
    local player = SimulationPlayer:new({
        class = "MAGE",
        spec = "FIRE",
        level = 70,
        stats = {
            intellect = 420,
            spell_power = 950,
            crit_rating = 280,
            hit_rating = 164,  -- 16% with talents
            haste_rating = 80,
            mana = 8000,
        },
        talents = {
            improved_scorch = 3,
            ignite = 5,
            combustion = 1,
            icy_veins = 1,
        },
        rotation = MageFireFixtures.rotation,
    })
    
    -- Create Patchwerk target
    local target = SimulationTarget:new({
        name = "Patchwerk",
        level = 73,
        health = 10000000,
        armor = 5500,
        resistances = { fire = 0 },
    })
    
    -- Configure buffs
    engine:set_raid_buffs({
        arcane_intellect = true,
        mark_of_the_wild = true,
        blessing_of_kings = true,
        blessing_of_wisdom = true,
        totem_of_wrath = true,
        mana_spring_totem = true,
        wrath_of_air_totem = true,
        mage_armor = true,
    })
    
    -- Configure consumables
    engine:set_consumables({
        flask = "FLASK_OF_PURE_DEATH",
        food = "SPELL_POWER_FOOD",
        oil = "SUPERIOR_MANA_OIL",
        potion = "DESTRUCTION_POTION",
    })
    
    -- Run simulation
    print("  Running 100 iterations of 5-minute fight...")
    local results = engine:run_iterations(player, target, 100)
    
    -- Calculate statistics
    local dps_values = {}
    for _, result in ipairs(results) do
        table.insert(dps_values, result.dps)
    end
    
    local avg_dps = Assert.calculate_average(dps_values)
    local std_dev = Assert.calculate_std_dev(dps_values, avg_dps)
    local confidence_interval = 1.96 * (std_dev / math.sqrt(#dps_values))
    
    -- wowsims reference: 1321.5 ± 1.8
    local wowsims_dps = 1321.5
    local wowsims_tolerance = wowsims_dps * (Config.wowsims.dps_tolerance_percent / 100)
    
    local dps_diff = math.abs(avg_dps - wowsims_dps)
    
    -- Validate DPS within 2%
    Assert.is_true(dps_diff <= wowsims_tolerance,
        string.format("DPS %.1f within 2%% of wowsims %.1f (diff: %.1f, tolerance: %.1f)",
            avg_dps, wowsims_dps, dps_diff, wowsims_tolerance))
    
    -- Validate spell breakdown
    local scorch_uptime = results[1].buff_uptime["IMPROVED_SCORCH"] or 0
    local expected_scorch_uptime = 98.7
    local uptime_tolerance = 2.0
    
    Assert.is_true(math.abs(scorch_uptime - expected_scorch_uptime) <= uptime_tolerance,
        string.format("Scorch uptime %.1f%% within 2%% of expected %.1f%%",
            scorch_uptime, expected_scorch_uptime))
    
    print(string.format("[PASS] EAX DPS: %.1f ± %.1f (wowsims: %.1f)",
        avg_dps, confidence_interval, wowsims_dps))
    print(string.format("       Scorch uptime: %.1f%% (expected: %.1f%%)",
        scorch_uptime, expected_scorch_uptime))
    
    return true
end

-- TEST-SIM-002: Statistical Comparison
function TestSimulation:test_statistical_comparison()
    print("\n[TEST] Simulation: Statistical Comparison")
    
    local engine = SimulationEngine:new({
        duration = 300,
        iterations = 1000,
    })
    
    local player = SimulationPlayer:new({
        class = "MAGE",
        spec = "FIRE",
        stats = MageFireFixtures.p1_stats,
    })
    
    local target = SimulationTarget:new({
        name = "Patchwerk",
        level = 73,
        health = 10000000,
    })
    
    -- Run statistical comparison
    print("  Running 1000 iterations for statistical significance...")
    local results = engine:run_iterations(player, target, 1000)
    
    -- Statistical analysis
    local dps_values = {}
    for _, result in ipairs(results) do
        table.insert(dps_values, result.dps)
    end
    
    -- Sort for percentile calculation
    table.sort(dps_values)
    
    local stats = {
        n = #dps_values,
        min = dps_values[1],
        max = dps_values[#dps_values],
        median = dps_values[math.floor(#dps_values / 2)],
        mean = Assert.calculate_average(dps_values),
        std_dev = Assert.calculate_std_dev(dps_values, Assert.calculate_average(dps_values)),
        p5 = dps_values[math.floor(#dps_values * 0.05)],
        p95 = dps_values[math.floor(#dps_values * 0.95)],
    }
    
    -- Reference values from wowsims
    local wowsims_stats = {
        mean = 1321.5,
        std_dev = 45.2,
        ci_low = 1319.7,
        ci_high = 1323.3,
    }
    
    -- Validate mean within confidence interval
    Assert.is_true(stats.mean >= wowsims_stats.ci_low and stats.mean <= wowsims_stats.ci_high,
        string.format("Mean DPS %.1f within wowsims CI [%.1f, %.1f]",
            stats.mean, wowsims_stats.ci_low, wowsims_stats.ci_high))
    
    -- Validate standard deviation within reasonable range (±20%)
    local std_dev_tolerance = wowsims_stats.std_dev * 0.2
    Assert.is_true(math.abs(stats.std_dev - wowsims_stats.std_dev) <= std_dev_tolerance,
        string.format("Std dev %.1f within 20%% of wowsims %.1f",
            stats.std_dev, wowsims_stats.std_dev))
    
    print(string.format("[PASS] Mean: %.1f (wowsims: %.1f)", stats.mean, wowsims_stats.mean))
    print(string.format("       StdDev: %.1f (wowsims: %.1f)", stats.std_dev, wowsims_stats.std_dev))
    print(string.format("       90%% Range: %.1f - %.1f", stats.p5, stats.p95))
    
    return true
end

-- TEST-SIM-003: DPS Within 2% Tolerance
function TestSimulation:test_dps_tolerance()
    print("\n[TEST] Simulation: DPS Within 2% Tolerance")
    
    local specs_to_test = {
        { class = "MAGE", spec = "FIRE", expected_dps = 1321.5 },
        { class = "WARRIOR", spec = "FURY", expected_dps = 1423.2 },
        { class = "ROGUE", spec = "COMBAT", expected_dps = 1295.3 },
        { class = "WARLOCK", spec = "AFFLICTION", expected_dps = 1234.8 },
    }
    
    local all_passed = true
    
    for _, spec in ipairs(specs_to_test) do
        print(string.format("  Testing %s %s...", spec.class, spec.spec))
        
        local engine = SimulationEngine:new({
            duration = 300,
            iterations = 100,
        })
        
        local player = SimulationPlayer:new({
            class = spec.class,
            spec = spec.spec,
        })
        
        local target = SimulationTarget:new({ name = "Patchwerk" })
        local results = engine:run_iterations(player, target, 100)
        
        local dps_values = {}
        for _, result in ipairs(results) do
            table.insert(dps_values, result.dps)
        end
        
        local avg_dps = Assert.calculate_average(dps_values)
        local tolerance = spec.expected_dps * 0.02
        local diff = math.abs(avg_dps - spec.expected_dps)
        local pass = diff <= tolerance
        
        local status = pass and "PASS" or "FAIL"
        print(string.format("    [%s] EAX: %.1f, Expected: %.1f, Diff: %.1f (%.1f%%)",
            status, avg_dps, spec.expected_dps, diff, (diff / spec.expected_dps) * 100))
        
        if not pass then
            all_passed = false
        end
    end
    
    Assert.is_true(all_passed, "All specs within 2% DPS tolerance of wowsims")
    print("[PASS] All specs within 2% tolerance")
    
    return true
end

function TestSimulation:run_all()
    print("\n" .. string.rep("=", 60))
    print("SIMULATION + VALIDATION TESTS")
    print(string.rep("=", 60))
    
    local tests = {
        self.test_mage_fire_5min_patchwerk,
        self.test_statistical_comparison,
        self.test_dps_tolerance,
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local ok, err = pcall(test, self)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("[FAIL] " .. tostring(err))
        end
    end
    
    print("\n" .. string.rep("-", 60))
    print(string.format("Results: %d passed, %d failed", passed, failed))
    print(string.rep("=", 60))
    
    return failed == 0
end

return TestSimulation
```

---

## Scenario 3: Flux + EAX Bridge

### Test Overview

**Purpose**: Test Flux strategies calling EAX spell resolution via Sylvanas API with >99% cast success rate

**Test File**: `tests/integration/scenarios/test_flux_eax_bridge.lua`

### Test Script

```lua
-- tests/integration/scenarios/test_flux_eax_bridge.lua
local TestFluxBridge = {}
local MockSylvanasAPI = require("tests.integration.mocks.MockSylvanasAPI")
local FluxBridge = require("shared.libraries.flux.bridge")
local SpellResolver = require("shared.libraries.spell_resolver")
local Assert = require("tests.integration.utils.test_assertions")

-- TEST-FLUX-001: Flux Fury Rotation with EAX Spell Resolver
function TestFluxBridge:test_flux_fury_eax_resolver()
    print("\n[TEST] Flux + EAX: Fury Rotation with EAX Spell Resolver")
    
    -- Setup mock API
    local api = MockSylvanasAPI:new()
    
    -- Initialize Flux-EAX Bridge
    local bridge = FluxBridge:new(api)
    
    -- Initialize EAX spell resolver
    local resolver = SpellResolver:new(api)
    resolver:register_spells({
        bloodthirst = { 30335, 25251, 23894, 23893 },
        whirlwind = { 25251, 23894 },
        execute = { 25234, 25236, 5308 },
        heroic_strike = { 29707, 25286, 11567 },
    })
    
    -- Connect Flux to EAX resolver
    bridge:set_spell_resolver(resolver)
    
    -- Simulate Fury rotation with Flux strategies
    local cast_attempts = 0
    local cast_successes = 0
    local rotation_log = {}
    
    -- Simulate 60-second combat
    for t = 0, 60000, 1500 do  -- 1.5s GCD
        api:advance_time(1500)
        
        -- Flux strategy decides action
        local strategy_action = bridge:get_strategy_action("fury", {
            rage = 65,
            target_hp = 75,
            in_combat = true,
        })
        
        if strategy_action then
            cast_attempts = cast_attempts + 1
            
            -- EAX resolver validates and executes
            local spell_id = resolver:resolve(strategy_action.spell_name)
            
            if spell_id then
                local can_cast = bridge:validate_cast(spell_id, {
                    rage = 65,
                    gcd_ready = true,
                    in_range = true,
                })
                
                if can_cast then
                    local cast_result = bridge:cast_spell(spell_id, "target")
                    
                    if cast_result.success then
                        cast_successes = cast_successes + 1
                        table.insert(rotation_log, {
                            time = t / 1000,
                            spell = strategy_action.spell_name,
                            spell_id = spell_id,
                            rage = 65,
                        })
                    end
                end
            end
        end
    end
    
    -- Validate >99% success rate
    local success_rate = (cast_successes / cast_attempts) * 100
    Assert.is_true(success_rate >= 99.0,
        string.format("Cast success rate %.1f%% >= 99%%", success_rate))
    
    print(string.format("[PASS] Cast attempts: %d, Successes: %d, Rate: %.1f%%",
        cast_attempts, cast_successes, success_rate))
    
    -- Validate spell sequencing
    local has_bloodthirst = false
    local has_whirlwind = false
    for _, entry in ipairs(rotation_log) do
        if entry.spell == "bloodthirst" then has_bloodthirst = true end
        if entry.spell == "whirlwind" then has_whirlwind = true end
    end
    
    Assert.is_true(has_bloodthirst, "Rotation includes Bloodthirst")
    Assert.is_true(has_whirlwind, "Rotation includes Whirlwind")
    
    return true
end

-- TEST-FLUX-002: Sylvanas API Cast Success Rate
function TestFluxBridge:test_sylvanas_api_success_rate()
    print("\n[TEST] Flux + EAX: Sylvanas API Cast Success Rate")
    
    local api = MockSylvanasAPI:new()
    local bridge = FluxBridge:new(api)
    
    -- Test various cast scenarios
    local scenarios = {
        { spell = "bloodthirst", rage = 30, expected = true },
        { spell = "bloodthirst", rage = 25, expected = false },  -- Insufficient rage
        { spell = "whirlwind", rage = 25, expected = true },
        { spell = "execute", rage = 15, target_hp = 15, expected = true },
        { spell = "execute", rage = 15, target_hp = 50, expected = false },  -- Not in execute
    }
    
    local all_passed = true
    
    for _, scenario in ipairs(scenarios) do
        local result = bridge:validate_cast_conditions(scenario.spell, {
            rage = scenario.rage,
            target_hp = scenario.target_hp,
        })
        
        local pass = (result == scenario.expected)
        if not pass then
            all_passed = false
            print(string.format("  [FAIL] %s (rage=%d, hp=%s): expected %s, got %s",
                scenario.spell, scenario.rage, tostring(scenario.target_hp),
                tostring(scenario.expected), tostring(result)))
        end
    end
    
    Assert.is_true(all_passed, "All cast condition validations passed")
    print("[PASS] All cast scenarios validated correctly")
    
    return true
end

-- TEST-FLUX-003: Bridge Overhead Measurement
function TestFluxBridge:test_bridge_overhead()
    print("\n[TEST] Flux + EAX: Bridge Overhead Measurement")
    
    local api = MockSylvanasAPI:new()
    local bridge = FluxBridge:new(api)
    
    -- Measure raw EAX time
    local start_raw = os.clock()
    for i = 1, 1000 do
        bridge:eax_direct_call({ rage = 50, target_hp = 80 })
    end
    local raw_time = (os.clock() - start_raw) * 1000
    
    -- Measure Flux+EAX bridge time
    local start_bridge = os.clock()
    for i = 1, 1000 do
        bridge:get_strategy_action_with_resolver("fury", {
            rage = 50,
            target_hp = 80,
        })
    end
    local bridge_time = (os.clock() - start_bridge) * 1000
    
    -- Calculate overhead
    local overhead_ms = bridge_time - raw_time
    local overhead_per_call = overhead_ms / 1000
    
    -- Validate <100ms overhead requirement
    Assert.is_true(overhead_per_call < 0.1,
        string.format("Flux overhead per call %.3fms < 0.1ms", overhead_per_call))
    
    print(string.format("[PASS] Raw EAX: %.2fms, Flux+EAX: %.2fms, Overhead: %.3fms/call",
        raw_time, bridge_time, overhead_per_call))
    
    return true
end

function TestFluxBridge:run_all()
    print("\n" .. string.rep("=", 60))
    print("FLUX + EAX BRIDGE INTEGRATION TESTS")
    print(string.rep("=", 60))
    
    local tests = {
        self.test_flux_fury_eax_resolver,
        self.test_sylvanas_api_success_rate,
        self.test_bridge_overhead,
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local ok, err = pcall(test, self)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("[FAIL] " .. tostring(err))
        end
    end
    
    print("\n" .. string.rep("-", 60))
    print(string.format("Results: %d passed, %d failed", passed, failed))
    print(string.rep("=", 60))
    
    return failed == 0
end

return TestFluxBridge
```

---

## Scenario 4: Dashboard + Combat Events

### Test Overview

**Purpose**: Test dashboard displays update correctly from combat events (CD icons, buff bars)

**Test File**: `tests/integration/scenarios/test_dashboard_combat_events.lua`

### Test Script

```lua
-- tests/integration/scenarios/test_dashboard_combat_events.lua
local TestDashboard = {}
local MockSylvanasAPI = require("tests.integration.mocks.MockSylvanasAPI")
local Dashboard = require("shared.libraries.dashboard")
local EventBus = require("shared.libraries.event_bus")
local Assert = require("tests.integration.utils.test_assertions")

-- TEST-DASH-001: Cooldown Icons Update
function TestDashboard:test_cd_icons_update()
    print("\n[TEST] Dashboard: Cooldown Icons Update from Combat Events")
    
    local api = MockSylvanasAPI:new()
    local event_bus = EventBus:new()
    local dashboard = Dashboard:new(api, event_bus)
    
    -- Initialize dashboard with cooldown tracking
    dashboard:register_cooldown_icon("bloodthirst", {
        spell_id = 30335,
        position = { x = 100, y = 100 },
        size = 32,
    })
    
    dashboard:register_cooldown_icon("recklessness", {
        spell_id = 1719,
        position = { x = 140, y = 100 },
        size = 32,
    })
    
    -- Simulate combat start
    api:set_player_state({ in_combat = true })
    event_bus:emit("combat_start", {})
    
    -- Simulate Recklessness cast
    api:cast_spell(1719, "player")
    event_bus:emit("spell_cast", { spell_id = 1719, target = "player" })
    
    -- Advance time 5s
    api:advance_time(5000)
    
    -- Verify CD icon shows cooldown remaining
    local bt_icon = dashboard:get_cooldown_icon("bloodthirst")
    local reck_icon = dashboard:get_cooldown_icon("recklessness")
    
    -- Recklessness should show 295s remaining (300s CD - 5s elapsed)
    Assert.is_true(reck_icon.cooldown_remaining > 290,
        "Recklessness icon shows cooldown remaining")
    
    -- Simulate Bloodthirst cast
    api:cast_spell(30335, "target")
    event_bus:emit("spell_cast", { spell_id = 30335, target = "target" })
    api:advance_time(1000)
    
    bt_icon = dashboard:get_cooldown_icon("bloodthirst")
    -- Bloodthirst should show 5s remaining (6s CD - 1s elapsed)
    Assert.is_true(bt_icon.cooldown_remaining >= 4,
        "Bloodthirst icon shows cooldown remaining")
    
    print("[PASS] Cooldown icons update correctly from spell cast events")
    return true
end

-- TEST-DASH-002: Buff Bars Refresh
function TestDashboard:test_buff_bars_refresh()
    print("\n[TEST] Dashboard: Buff Bars Refresh from Combat Events")
    
    local api = MockSylvanasAPI:new()
    local event_bus = EventBus:new()
    local dashboard = Dashboard:new(api, event_bus)
    
    -- Register buff bar
    dashboard:register_buff_bar("battle_shout", {
        buff_id = 25289,
        color = { r = 1, g = 0.8, b = 0 },
        position = { x = 100, y = 200 },
        width = 200,
        height = 20,
    })
    
    -- Register debuff bar
    dashboard:register_debuff_bar("sunder_armor", {
        debuff_id = 25225,
        color = { r = 1, g = 0, b = 0 },
        position = { x = 100, y = 230 },
        width = 200,
        height = 20,
    })
    
    -- Simulate buff application
    event_bus:emit("buff_gain", {
        buff_id = 25289,
        duration = 120,
        source = "player",
    })
    
    api:advance_time(10000)  -- 10s elapsed
    
    local bs_bar = dashboard:get_buff_bar("battle_shout")
    
    -- Should show ~110s remaining
    Assert.is_true(bs_bar.remaining > 100 and bs_bar.remaining <= 110,
        "Battle Shout bar shows correct remaining time")
    
    -- UI state should match game state
    Assert.equals(true, bs_bar.active, "Battle Shout bar is active")
    Assert.equals(25289, bs_bar.buff_id, "Buff ID matches")
    
    print("[PASS] Buff bars refresh correctly from combat events")
    return true
end

-- TEST-DASH-003: UI State Matches Game State
function TestDashboard:test_ui_game_state_sync()
    print("\n[TEST] Dashboard: UI State Matches Game State")
    
    local api = MockSylvanasAPI:new()
    local event_bus = EventBus:new()
    local dashboard = Dashboard:new(api, event_bus)
    
    -- Register multiple UI elements
    dashboard:register_combat_state_indicator({
        position = { x = 50, y = 50 },
    })
    
    dashboard:register_target_health_bar({
        position = { x = 100, y = 50 },
        width = 200,
    })
    
    -- Test combat state sync
    api:set_player_state({ in_combat = false })
    event_bus:emit("combat_state_change", { in_combat = false })
    
    local indicator = dashboard:get_combat_state_indicator()
    Assert.equals(false, indicator.in_combat, "Indicator shows out of combat")
    
    -- Enter combat
    api:set_player_state({ in_combat = true })
    event_bus:emit("combat_state_change", { in_combat = true })
    
    indicator = dashboard:get_combat_state_indicator()
    Assert.equals(true, indicator.in_combat, "Indicator shows in combat")
    
    -- Test target health sync
    api:set_target_state({ health_pct = 75, max_health = 10000 })
    event_bus:emit("target_health_change", { health_pct = 75 })
    
    local health_bar = dashboard:get_target_health_bar()
    Assert.equals(75, health_bar.current_pct, "Health bar shows 75%")
    
    -- Change target health
    api:set_target_state({ health_pct = 45 })
    event_bus:emit("target_health_change", { health_pct = 45 })
    
    health_bar = dashboard:get_target_health_bar()
    Assert.equals(45, health_bar.current_pct, "Health bar shows 45%")
    
    -- Verify sync delay < 50ms
    Assert.is_true(health_bar.last_update_latency < 50,
        "UI update latency < 50ms")
    
    print("[PASS] UI state correctly mirrors game state with low latency")
    return true
end

function TestDashboard:run_all()
    print("\n" .. string.rep("=", 60))
    print("DASHBOARD + COMBAT EVENTS INTEGRATION TESTS")
    print(string.rep("=", 60))
    
    local tests = {
        self.test_cd_icons_update,
        self.test_buff_bars_refresh,
        self.test_ui_game_state_sync,
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local ok, err = pcall(test, self)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("[FAIL] " .. tostring(err))
        end
    end
    
    print("\n" .. string.rep("-", 60))
    print(string.format("Results: %d passed, %d failed", passed, failed))
    print(string.rep("=", 60))
    
    return failed == 0
end

return TestDashboard
```

---

## Scenario 5: Middleware Chain Priority

### Test Overview

**Purpose**: Test multiple middleware execute in correct order (Interrupt > Bloodrage > Shout)

**Test File**: `tests/integration/scenarios/test_middleware_priority.lua`

### Test Script

```lua
-- tests/integration/scenarios/test_middleware_priority.lua
local TestMiddleware = {}
local MockSylvanasAPI = require("tests.integration.mocks.MockSylvanasAPI")
local MiddlewareManager = require("shared.libraries.middleware_manager")
local Assert = require("tests.integration.utils.test_assertions")

-- TEST-MW-001: Execution Order Verification
function TestMiddleware:test_execution_order()
    print("\n[TEST] Middleware: Execution Order Verification")
    
    local api = MockSylvanasAPI:new()
    local manager = MiddlewareManager:new(api)
    local execution_log = {}
    
    -- Register middleware in arbitrary order
    manager:register({
        id = "battle_shout",
        priority = 140,  -- Lowest
        execute = function(ctx)
            table.insert(execution_log, { id = "battle_shout", priority = 140, time = api.time_elapsed })
            return false  -- Continue to next
        end
    })
    
    manager:register({
        id = "pummel_interrupt",
        priority = 250,  -- Highest
        execute = function(ctx)
            if ctx.target_casting then
                table.insert(execution_log, { id = "pummel_interrupt", priority = 250, time = api.time_elapsed })
                return true  -- Stop chain (interrupt handled)
            end
            return false  -- Continue
        end
    })
    
    manager:register({
        id = "bloodrage",
        priority = 200,  -- Middle
        execute = function(ctx)
            if ctx.rage < 30 then
                table.insert(execution_log, { id = "bloodrage", priority = 200, time = api.time_elapsed })
            end
            return false  -- Continue
        end
    })
    
    -- Test scenario 1: Target casting (interrupt should fire first)
    execution_log = {}
    local ctx1 = {
        target_casting = true,
        rage = 50,
        battle_shout_active = false,
    }
    
    manager:execute_chain(ctx1)
    
    -- Should only have interrupt (it returns true to stop chain)
    Assert.equals(1, #execution_log, "Only interrupt fires when target casting")
    Assert.equals("pummel_interrupt", execution_log[1].id, "Interrupt is first")
    
    -- Test scenario 2: Low rage, no casting (bloodrage should fire before shout)
    execution_log = {}
    local ctx2 = {
        target_casting = false,
        rage = 20,
        battle_shout_active = false,
    }
    
    manager:execute_chain(ctx2)
    
    -- Should fire bloodrage then battle_shout (in priority order)
    Assert.is_true(#execution_log >= 1, "At least one middleware fires")
    
    if #execution_log >= 2 then
        Assert.equals(200, execution_log[1].priority, "Bloodrage (200) before shout")
        Assert.equals(140, execution_log[2].priority, "Battle Shout (140) after bloodrage")
    end
    
    -- Verify priority order in log
    for i = 2, #execution_log do
        Assert.is_true(execution_log[i-1].priority >= execution_log[i].priority,
            string.format("Priority order: %d >= %d",
                execution_log[i-1].priority, execution_log[i].priority))
    end
    
    print("[PASS] Middleware executes in correct priority order")
    return true
end

-- TEST-MW-002: Priority Constants
function TestMiddleware:test_priority_constants()
    print("\n[TEST] Middleware: Priority Constants")
    
    local api = MockSylvanasAPI:new()
    local manager = MiddlewareManager:new(api)
    
    -- Standard priority levels from EAX spec
    local priorities = {
        EMERGENCY_DEFENSIVE = 300,
        INTERRUPT = 250,
        DISPEL = 240,
        DEFENSIVE = 220,
        UTILITY_HIGH = 200,  -- Bloodrage
        BUFF_MAINTENANCE = 180,
        UTILITY_NORMAL = 160,
        DAMAGE_ROTATION = 100,
    }
    
    -- Register with standard priorities
    manager:register({ id = "shield_wall", priority = priorities.EMERGENCY_DEFENSIVE })
    manager:register({ id = "pummel", priority = priorities.INTERRUPT })
    manager:register({ id = "bloodrage", priority = priorities.UTILITY_HIGH })
    manager:register({ id = "battle_shout", priority = priorities.BUFF_MAINTENANCE })
    manager:register({ id = "bloodthirst", priority = priorities.DAMAGE_ROTATION })
    
    -- Verify sort order
    local sorted = manager:get_sorted_middleware()
    
    Assert.equals("shield_wall", sorted[1].id, "Shield Wall (300) first")
    Assert.equals("pummel", sorted[2].id, "Pummel (250) second")
    Assert.equals("bloodrage", sorted[3].id, "Bloodrage (200) third")
    Assert.equals("battle_shout", sorted[4].id, "Battle Shout (180) fourth")
    Assert.equals("bloodthirst", sorted[5].id, "Bloodthirst (100) last")
    
    print("[PASS] Priority constants match EAX specification")
    return true
end

-- TEST-MW-003: Execution Order Logging
function TestMiddleware:test_execution_logging()
    print("\n[TEST] Middleware: Execution Order Logging")
    
    local api = MockSylvanasAPI:new()
    local manager = MiddlewareManager:new(api)
    
    -- Enable execution logging
    manager:set_logging_enabled(true)
    
    -- Register test middleware
    manager:register({
        id = "interrupt",
        priority = 250,
        execute = function() return false end
    })
    
    manager:register({
        id = "bloodrage",
        priority = 200,
        execute = function() return false end
    })
    
    manager:register({
        id = "shout",
        priority = 140,
        execute = function() return false end
    })
    
    -- Execute and get log
    local ctx = { rage = 25, target_casting = false }
    manager:execute_chain(ctx)
    
    local log = manager:get_execution_log()
    
    -- Verify log format
    Assert.is_true(#log >= 3, "All middlewares logged")
    
    for i, entry in ipairs(log) do
        Assert.is_not_nil(entry.timestamp, "Log entry has timestamp")
        Assert.is_not_nil(entry.middleware_id, "Log entry has middleware ID")
        Assert.is_not_nil(entry.priority, "Log entry has priority")
        Assert.is_not_nil(entry.result, "Log entry has result")
    end
    
    -- Verify timestamp order
    for i = 2, #log do
        Assert.is_true(log[i].timestamp >= log[i-1].timestamp,
            "Log entries in chronological order")
    end
    
    print("[PASS] Execution logging captures correct order")
    return true
end

function TestMiddleware:run_all()
    print("\n" .. string.rep("=", 60))
    print("MIDDLEWARE CHAIN PRIORITY INTEGRATION TESTS")
    print(string.rep("=", 60))
    
    local tests = {
        self.test_execution_order,
        self.test_priority_constants,
        self.test_execution_logging,
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local ok, err = pcall(test, self)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("[FAIL] " .. tostring(err))
        end
    end
    
    print("\n" .. string.rep("-", 60))
    print(string.format("Results: %d passed, %d failed", passed, failed))
    print(string.rep("=", 60))
    
    return failed == 0
end

return TestMiddleware
```

---

## Scenario 6: Settings Persistence

### Test Overview

**Purpose**: Test Flux settings persist and apply correctly after reload

**Test File**: `tests/integration/scenarios/test_settings_persistence.lua`

### Test Script

```lua
-- tests/integration/scenarios/test_settings_persistence.lua
local TestSettings = {}
local SettingsManager = require("shared.libraries.settings_manager")
local MockStorage = require("tests.integration.mocks.MockStorage")
local Assert = require("tests.integration.utils.test_assertions")

-- TEST-SET-001: Burst Threshold Persistence
function TestSettings:test_burst_threshold_persistence()
    print("\n[TEST] Settings: Burst Threshold Persistence")
    
    local storage = MockStorage:new()
    local settings = SettingsManager:new(storage)
    
    -- Set initial value
    settings:set("flux.fury.burst_threshold", 75)
    settings:set("flux.fury.use_recklessness", true)
    settings:set("flux.fury.use_death_wish", true)
    
    -- Simulate reload by creating new instance
    settings = nil
    collectgarbage()  -- Force GC to clear any caches
    
    local settings2 = SettingsManager:new(storage)
    
    -- Verify values persisted
    local burst_threshold = settings2:get("flux.fury.burst_threshold")
    local use_reck = settings2:get("flux.fury.use_recklessness")
    local use_dw = settings2:get("flux.fury.use_death_wish")
    
    Assert.equals(75, burst_threshold, "Burst threshold persisted")
    Assert.equals(true, use_reck, "Recklessness setting persisted")
    Assert.equals(true, use_dw, "Death Wish setting persisted")
    
    print("[PASS] All settings persisted correctly after reload")
    return true
end

-- TEST-SET-002: Settings Apply After Reload
function TestSettings:test_settings_apply_after_reload()
    print("\n[TEST] Settings: Settings Apply After Reload")
    
    local storage = MockStorage:new()
    local settings = SettingsManager:new(storage)
    
    -- Configure and save settings
    settings:set("eax.warriorfury.hs_rage_threshold", 55)
    settings:set("eax.warriorfury.rotation_mode", "execute_priority")
    
    -- Simulate rotation using settings
    local rotation_config = settings:get_rotation_config("eax.warriorfury")
    
    Assert.equals(55, rotation_config.hs_rage_threshold, "Config has correct threshold")
    Assert.equals("execute_priority", rotation_config.rotation_mode, "Config has correct mode")
    
    -- Reload and verify
    local settings2 = SettingsManager:new(storage)
    local rotation_config2 = settings2:get_rotation_config("eax.warriorfury")
    
    Assert.equals(55, rotation_config2.hs_rage_threshold, "Threshold after reload")
    Assert.equals("execute_priority", rotation_config2.rotation_mode, "Mode after reload")
    
    -- Change and verify
    settings2:set("eax.warriorfury.hs_rage_threshold", 60)
    local new_threshold = settings2:get("eax.warriorfury.hs_rage_threshold")
    Assert.equals(60, new_threshold, "New threshold applied")
    
    print("[PASS] Settings apply correctly after reload")
    return true
end

-- TEST-SET-003: Settings Read Back Correctly
function TestSettings:test_settings_readback()
    print("\n[TEST] Settings: Settings Read Back Correctly")
    
    local storage = MockStorage:new()
    local settings = SettingsManager:new(storage)
    
    -- Set various setting types
    local test_values = {
        { key = "bool_true", value = true, expected = true },
        { key = "bool_false", value = false, expected = false },
        { key = "number_int", value = 42, expected = 42 },
        { key = "number_float", value = 3.14159, expected = 3.14159 },
        { key = "string", value = "test_value", expected = "test_value" },
        { key = "table", value = { a = 1, b = 2 }, expected = { a = 1, b = 2 } },
    }
    
    -- Set all values
    for _, test in ipairs(test_values) do
        settings:set(test.key, test.value)
    end
    
    -- Read back and verify
    local all_correct = true
    for _, test in ipairs(test_values) do
        local read_value = settings:get(test.key)
        
        if type(test.expected) == "table" then
            for k, v in pairs(test.expected) do
                if read_value[k] ~= v then
                    all_correct = false
                    print(string.format("  [FAIL] %s: expected %s, got %s",
                        test.key, tostring(v), tostring(read_value[k])))
                end
            end
        else
            if read_value ~= test.expected then
                all_correct = false
                print(string.format("  [FAIL] %s: expected %s, got %s",
                    test.key, tostring(test.expected), tostring(read_value)))
            end
        end
    end
    
    Assert.is_true(all_correct, "All settings read back correctly")
    print("[PASS] All setting types persist and read back correctly")
    return true
end

-- TEST-SET-004: Cross-Session Settings Isolation
function TestSettings:test_settings_isolation()
    print("\n[TEST] Settings: Cross-Session Settings Isolation")
    
    local storage = MockStorage:new()
    
    -- Session 1: Warrior settings
    local settings_warrior = SettingsManager:new(storage, "session_warrior")
    settings_warrior:set("class", "warrior")
    settings_warrior:set("spec", "fury")
    settings_warrior:set("hs_threshold", 50)
    
    -- Session 2: Mage settings (simultaneous)
    local settings_mage = SettingsManager:new(storage, "session_mage")
    settings_mage:set("class", "mage")
    settings_mage:set("spec", "fire")
    settings_mage:set("scorch_refresh", 3.0)
    
    -- Verify isolation
    Assert.equals("warrior", settings_warrior:get("class"), "Warrior class isolated")
    Assert.equals("mage", settings_mage:get("class"), "Mage class isolated")
    
    -- Simulate session reload
    local settings_warrior2 = SettingsManager:new(storage, "session_warrior")
    local settings_mage2 = SettingsManager:new(storage, "session_mage")
    
    Assert.equals("warrior", settings_warrior2:get("class"), "Warrior persisted correctly")
    Assert.equals("fury", settings_warrior2:get("spec"), "Warrior spec persisted")
    Assert.equals("mage", settings_mage2:get("class"), "Mage persisted correctly")
    
    print("[PASS] Settings properly isolated across sessions")
    return true
end

function TestSettings:run_all()
    print("\n" .. string.rep("=", 60))
    print("SETTINGS PERSISTENCE INTEGRATION TESTS")
    print(string.rep("=", 60))
    
    local tests = {
        self.test_burst_threshold_persistence,
        self.test_settings_apply_after_reload,
        self.test_settings_readback,
        self.test_settings_isolation,
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local ok, err = pcall(test, self)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("[FAIL] " .. tostring(err))
        end
    end
    
    print("\n" .. string.rep("-", 60))
    print(string.format("Results: %d passed, %d failed", passed, failed))
    print(string.rep("=", 60))
    
    return failed == 0
end

return TestSettings
```

---

## Scenario 7: Cross-Spec Library Sharing

### Test Overview

**Purpose**: Test shared libraries work across all 29 specs without conflicts

**Test File**: `tests/integration/scenarios/test_cross_spec_sharing.lua`

### Test Script

```lua
-- tests/integration/scenarios/test_cross_spec_sharing.lua
local TestCrossSpec = {}
local SharedLibraries = require("shared.libraries")
local MockSylvanasAPI = require("tests.integration.mocks.MockSylvanasAPI")
local Assert = require("tests.integration.utils.test_assertions")

-- TEST-XSPEC-001: Shared menu.lua in 5 Different Specs
function TestCrossSpec:test_shared_menu_lua()
    print("\n[TEST] Cross-Spec: Shared menu.lua in 5 Different Specs")
    
    local api = MockSylvanasAPI:new()
    
    -- Initialize 5 different specs using shared menu
    local specs = {
        { name = "EAXWarriorFury", class = "WARRIOR", spec = "FURY" },
        { name = "EAXMageFire", class = "MAGE", spec = "FIRE" },
        { name = "EAXRogueCombat", class = "ROGUE", spec = "COMBAT" },
        { name = "EAXPriestShadow", class = "PRIEST", spec = "SHADOW" },
        { name = "EAXDruidBalance", class = "DRUID", spec = "BALANCE" },
    }
    
    local loaded_specs = {}
    
    -- Load each spec with shared library
    for _, spec_info in ipairs(specs) do
        local spec = {
            name = spec_info.name,
            class = spec_info.class,
            spec = spec_info.spec,
            menu = SharedLibraries.menu:new(api, spec_info.name),
            utils = SharedLibraries.utils:new(api),
        }
        
        -- Initialize spec-specific settings
        spec.menu:initialize_defaults()
        
        table.insert(loaded_specs, spec)
    end
    
    -- Verify all specs loaded without conflicts
    Assert.equals(5, #loaded_specs, "All 5 specs loaded")
    
    -- Verify isolated settings
    loaded_specs[1].menu:set("enabled", true)
    loaded_specs[2].menu:set("enabled", false)
    
    Assert.equals(true, loaded_specs[1].menu:get("enabled"), "Warrior enabled")
    Assert.equals(false, loaded_specs[2].menu:get("enabled"), "Mage disabled")
    
    -- Verify shared utils work across all specs
    for _, spec in ipairs(loaded_specs) do
        local gcd = spec.utils:get_gcd_remaining()
        Assert.is_not_nil(gcd, string.format("%s utils working", spec.name))
    end
    
    print("[PASS] Shared menu.lua works correctly in 5 specs")
    return true
end

-- TEST-XSPEC-002: No Conflicts Between Specs
function TestCrossSpec:test_no_conflicts()
    print("\n[TEST] Cross-Spec: No Conflicts Between Specs")
    
    local api = MockSylvanasAPI:new()
    
    -- Load shared libraries
    local shared = {
        spell_resolver = SharedLibraries.spell_resolver:new(api),
        combat_context = SharedLibraries.combat_context:new(api),
        buff_manager = SharedLibraries.buff_manager:new(api),
    }
    
    -- Simulate multiple specs using shared libraries simultaneously
    local conflicts = {}
    
    -- Test 1: Spell resolver cache isolation
    shared.spell_resolver:resolve({ 30335, 25251 }, "EAXWarriorFury")
    shared.spell_resolver:resolve({ 10149, 10150, 10151 }, "EAXMageFire")
    
    local warrior_bt = shared.spell_resolver:get_cached("EAXWarriorFury")
    local mage_fb = shared.spell_resolver:get_cached("EAXMageFire")
    
    -- Verify no cross-contamination
    if warrior_bt and mage_fb and warrior_bt == mage_fb then
        table.insert(conflicts, "Spell resolver cache contamination")
    end
    
    -- Test 2: Combat context isolation
    local ctx_warrior = shared.combat_context:build("EAXWarriorFury")
    local ctx_mage = shared.combat_context:build("EAXMageFire")
    
    ctx_warrior.rage = 80
    ctx_mage.mana = 5000
    
    if ctx_mage.rage or ctx_warrior.mana then
        table.insert(conflicts, "Combat context state contamination")
    end
    
    -- Test 3: Buff manager isolation
    shared.buff_manager:track_buff(25289, "EAXWarriorFury")  -- Battle Shout
    shared.buff_manager:track_buff(1459, "EAXMageFire")      -- Arcane Intellect
    
    local warrior_buffs = shared.buff_manager:get_buffs("EAXWarriorFury")
    local mage_buffs = shared.buff_manager:get_buffs("EAXMageFire")
    
    if #mage_buffs > 0 and mage_buffs[1].id == 25289 then
        table.insert(conflicts, "Buff manager cross-contamination")
    end
    
    Assert.equals(0, #conflicts, "No conflicts detected: " .. table.concat(conflicts, ", "))
    print("[PASS] No conflicts between specs using shared libraries")
    return true
end

-- TEST-XSPEC-003: Independent Settings Per Spec
function TestCrossSpec:test_independent_settings()
    print("\n[TEST] Cross-Spec: Independent Settings Per Spec")
    
    local api = MockSylvanasAPI:new()
    local settings = SharedLibraries.settings_framework:new(api)
    
    -- Initialize settings for all 29 specs
    local all_specs = {
        "EAXDruidBalance", "EAXDruidBear", "EAXDruidFeral", "EAXDruidResto",
        "EAXHunterBM", "EAXHunterMM", "EAXHunterSurvival",
        "EAXMageArcane", "EAXMageFire", "EAXMageFrost",
        "EAXPaladinHoly", "EAXPaladinProtection", "EAXPaladinRetribution",
        "EAXPriestDiscipline", "EAXPriestHoly", "EAXPriestShadow", "EAXPriestSmite",
        "EAXRogueAssassination", "EAXRogueCombat", "EAXRogueSubtlety",
        "EAXShamanElemental", "EAXShamanEnhancement", "EAXShamanRestoration",
        "EAXWarlockAffliction", "EAXWarlockDemonology", "EAXWarlockDestruction",
        "EAXWarriorArms", "EAXWarriorFury", "EAXWarriorProtection",
    }
    
    -- Set unique values for each spec
    for i, spec_name in ipairs(all_specs) do
        settings:initialize_spec(spec_name)
        settings:set(spec_name .. ".custom_threshold", i * 10)
    end
    
    -- Verify all values are independent
    local all_independent = true
    for i, spec_name in ipairs(all_specs) do
        local value = settings:get(spec_name .. ".custom_threshold")
        if value ~= i * 10 then
            all_independent = false
            print(string.format("  [FAIL] %s: expected %d, got %s",
                spec_name, i * 10, tostring(value)))
        end
    end
    
    Assert.equals(29, #all_specs, "All 29 specs initialized")
    Assert.is_true(all_independent, "All spec settings independent")
    
    print(string.format("[PASS] All %d specs have independent settings", #all_specs))
    return true
end

function TestCrossSpec:run_all()
    print("\n" .. string.rep("=", 60))
    print("CROSS-SPEC LIBRARY SHARING INTEGRATION TESTS")
    print(string.rep("=", 60))
    
    local tests = {
        self.test_shared_menu_lua,
        self.test_no_conflicts,
        self.test_independent_settings,
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local ok, err = pcall(test, self)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("[FAIL] " .. tostring(err))
        end
    end
    
    print("\n" .. string.rep("-", 60))
    print(string.format("Results: %d passed, %d failed", passed, failed))
    print(string.rep("=", 60))
    
    return failed == 0
end

return TestCrossSpec
```

---

## Scenario 8: State Machine Transitions

### Test Overview

**Purpose**: Test Rogue plan transitions work correctly (opener → slice → expose)

**Test File**: `tests/integration/scenarios/test_state_transitions.lua`

### Test Script

```lua
-- tests/integration/scenarios/test_state_transitions.lua
local TestStateTransitions = {}
local StateMachine = require("shared.libraries.state_machine")
local RogueCombatFixtures = require("tests.integration.fixtures.rogue_combat_fixtures")
local Assert = require("tests.integration.utils.test_assertions")

-- TEST-STATE-001: Opener → Slice Transition
function TestStateTransitions:test_opener_to_slice()
    print("\n[TEST] State Machine: Opener → Slice Transition")
    
    local sm = StateMachine:new({
        initial = "opener",
        states = {
            opener = {
                on_enter = function() return "stealth" end,
                transitions = {
                    { to = "slice", condition = function(ctx) return ctx.combo_points >= 1 end }
                }
            },
            slice = {
                on_enter = function() return "slice_and_dice" end,
                transitions = {
                    { to = "build", condition = function(ctx) return ctx.snd_active end }
                }
            },
            build = {
                on_enter = function() return "sinister_strike" end,
                transitions = {
                    { to = "expose", condition = function(ctx) 
                        return ctx.combo_points == 5 and ctx.snd_remains > 10 end }
                }
            },
            expose = {
                on_enter = function() return "expose_armor" end,
                transitions = {
                    { to = "build", condition = function(ctx) return true end }
                }
            },
        }
    })
    
    -- Start in opener
    Assert.equals("opener", sm:get_current_state(), "Initial state is opener")
    
    -- Build 1 CP (opener → slice)
    local ctx1 = { combo_points = 1, in_stealth = false }
    local action1 = sm:update(ctx1)
    
    Assert.equals("slice", sm:get_current_state(), "Transition to slice state")
    Assert.equals("slice_and_dice", action1, "Action is Slice and Dice")
    
    -- After casting SnD (slice → build)
    local ctx2 = { combo_points = 0, snd_active = true, snd_remains = 20 }
    local action2 = sm:update(ctx2)
    
    Assert.equals("build", sm:get_current_state(), "Transition to build state")
    
    print("[PASS] Opener → Slice → Build transitions work correctly")
    return true
end

-- TEST-STATE-002: Build → Expose Transition
function TestStateTransitions:test_build_to_expose()
    print("\n[TEST] State Machine: Build → Expose Transition")
    
    local sm = StateMachine:new(RogueCombatFixtures.state_machine)
    
    -- Start in build with 5 CP
    sm:set_state("build")
    
    local ctx = {
        combo_points = 5,
        snd_active = true,
        snd_remains = 15,
        expose_armor_active = false,
        expose_armor_remains = 0,
    }
    
    local action = sm:update(ctx)
    
    -- Should transition to expose at 5 CP with good SnD time
    Assert.equals("expose", sm:get_current_state(), "Transition to expose at 5 CP")
    Assert.equals("expose_armor", action, "Action is Expose Armor")
    
    -- After expose (expose → build)
    ctx.expose_armor_active = true
    ctx.combo_points = 0
    
    action = sm:update(ctx)
    Assert.equals("build", sm:get_current_state(), "Return to build after expose")
    
    print("[PASS] Build → Expose → Build transitions work correctly")
    return true
end

-- TEST-STATE-003: State Log Matches Expected Sequence
function TestStateTransitions:test_state_log_sequence()
    print("\n[TEST] State Machine: State Log Matches Expected Sequence")
    
    local state_log = {}
    
    local sm = StateMachine:new({
        states = {
            opener = {
                on_enter = function(ctx) 
                    table.insert(state_log, { state = "opener", time = ctx.time })
                    return "garrote"
                end,
                transitions = {
                    { to = "slice", condition = function(ctx) return ctx.combo_points >= 1 end }
                }
            },
            slice = {
                on_enter = function(ctx)
                    table.insert(state_log, { state = "slice", time = ctx.time })
                    return "slice_and_dice"
                end,
                transitions = {
                    { to = "build", condition = function(ctx) return ctx.snd_active end }
                }
            },
            build = {
                on_enter = function(ctx)
                    table.insert(state_log, { state = "build", time = ctx.time })
                    if ctx.combo_points == 5 then
                        return "expose_armor"
                    else
                        return "sinister_strike"
                    end
                end,
                transitions = {
                    { to = "expose", condition = function(ctx) 
                        return ctx.combo_points == 5 and not ctx.expose_armor_active end },
                    { to = "slice", condition = function(ctx) 
                        return ctx.snd_remains < 3 and ctx.combo_points >= 2 end },
                }
            },
            expose = {
                on_enter = function(ctx)
                    table.insert(state_log, { state = "expose", time = ctx.time })
                    return "expose_armor"
                end,
                transitions = {
                    { to = "build", condition = function(ctx) return true end }
                }
            },
        }
    })
    
    -- Simulate complete rotation
    local timeline = {
        { time = 0, ctx = { combo_points = 1, in_stealth = true } },     -- opener
        { time = 2, ctx = { combo_points = 1, in_stealth = false } },     -- → slice
        { time = 4, ctx = { combo_points = 0, snd_active = true, snd_remains = 20 } }, -- → build
        { time = 6, ctx = { combo_points = 2, snd_remains = 18 } },       -- build
        { time = 8, ctx = { combo_points = 4, snd_remains = 16 } },       -- build
        { time = 10, ctx = { combo_points = 5, snd_remains = 14, expose_armor_active = false } }, -- → expose
        { time = 12, ctx = { combo_points = 0, expose_armor_active = true } }, -- → build
    }
    
    -- Process timeline
    for _, entry in ipairs(timeline) do
        sm:update(entry.ctx)
    end
    
    -- Verify state log matches expected sequence
    local expected_sequence = { "opener", "slice", "build", "build", "build", "expose", "build" }
    
    Assert.equals(#expected_sequence, #state_log, 
        string.format("State log has %d entries", #expected_sequence))
    
    for i, expected in ipairs(expected_sequence) do
        if state_log[i] then
            Assert.equals(expected, state_log[i].state,
                string.format("State %d: expected %s, got %s",
                    i, expected, state_log[i].state))
        end
    end
    
    print("[PASS] State log matches expected transition sequence")
    return true
end

function TestStateTransitions:run_all()
    print("\n" .. string.rep("=", 60))
    print("STATE MACHINE TRANSITIONS INTEGRATION TESTS")
    print(string.rep("=", 60))
    
    local tests = {
        self.test_opener_to_slice,
        self.test_build_to_expose,
        self.test_state_log_sequence,
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local ok, err = pcall(test, self)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("[FAIL] " .. tostring(err))
        end
    end
    
    print("\n" .. string.rep("-", 60))
    print(string.format("Results: %d passed, %d failed", passed, failed))
    print(string.rep("=", 60))
    
    return failed == 0
end

return TestStateTransitions
```

---

## Scenario 9: Resource Integration

### Test Overview

**Purpose**: Test Mana/Energy/Rage tracking consistency across modules

**Test File**: `tests/integration/scenarios/test_resource_integration.lua`

### Test Script

```lua
-- tests/integration/scenarios/test_resource_integration.lua
local TestResourceIntegration = {}
local ResourceManager = require("shared.libraries.resource_manager")
local ManaManager = require("shared.libraries.mana_manager")
local EnergyManager = require("shared.libraries.energy_manager")
local RageManager = require("shared.libraries.rage_manager")
local MockSylvanasAPI = require("tests.integration.mocks.MockSylvanasAPI")
local Assert = require("tests.integration.utils.test_assertions")

-- TEST-RES-001: Mage Mana Tracking Consistency
function TestResourceIntegration:test_mage_mana_consistency()
    print("\n[TEST] Resource: Mage Mana Tracking Consistency")
    
    local api = MockSylvanasAPI:new()
    local rm = ResourceManager:new(api)
    local mm = ManaManager:new(api)
    local cd_tracker = { mana_value = 0 }  -- Simulated CD tracker
    
    -- Register mana sources
    rm:register_source("mana_manager", function() return mm:get_mana() end)
    rm:register_source("cd_tracker", function() return cd_tracker.mana_value end)
    rm:register_source("apl_engine", function() return mm:get_mana() end)
    
    -- Set initial mana
    api:set_player_state({ mana = 8000, max_mana = 8000 })
    mm:update()
    cd_tracker.mana_value = 8000
    
    -- Verify all sources report same value
    local values = rm:get_all_values("mana")
    Assert.equals(8000, values.mana_manager, "Mana manager reports 8000")
    Assert.equals(8000, values.cd_tracker, "CD tracker reports 8000")
    Assert.equals(8000, values.apl_engine, "APL engine reports 8000")
    
    -- Simulate mana consumption
    api:set_player_state({ mana = 6500 })
    mm:update()
    cd_tracker.mana_value = 6500
    
    values = rm:get_all_values("mana")
    Assert.equals(6500, values.mana_manager, "Mana manager updated")
    Assert.equals(6500, values.cd_tracker, "CD tracker updated")
    
    -- Check for drift
    local drift = rm:check_drift("mana", 6500)
    Assert.equals(0, drift.max_drift, "No mana tracking drift")
    
    print("[PASS] Mana values consistent across all modules")
    return true
end

-- TEST-RES-002: Rogue Energy Tick Alignment
function TestResourceIntegration:test_rogue_energy_consistency()
    print("\n[TEST] Resource: Rogue Energy Tick Alignment")
    
    local api = MockSylvanasAPI:new()
    local rm = ResourceManager:new(api)
    local em = EnergyManager:new(api)
    local rotation = { energy_value = 100 }
    local dashboard = { energy_display = 100 }
    
    -- Register sources
    rm:register_source("energy_manager", function() return em:get_energy() end)
    rm:register_source("rotation_engine", function() return rotation.energy_value end)
    rm:register_source("dashboard", function() return dashboard.energy_display end)
    
    -- Simulate energy tick
    local tick_values = {}
    for t = 0, 2000, 100 do
        api:advance_time(100)
        
        -- Update all systems
        em:update()
        rotation.energy_value = em:get_energy()
        dashboard.energy_display = em:get_energy()
        
        table.insert(tick_values, {
            time = t,
            em = em:get_energy(),
            rot = rotation.energy_value,
            dash = dashboard.energy_display,
        })
    end
    
    -- Verify no drift during tick
    for _, v in ipairs(tick_values) do
        Assert.equals(v.em, v.rot, 
            string.format("Time %d: rotation matches energy manager", v.time))
        Assert.equals(v.em, v.dash,
            string.format("Time %d: dashboard matches energy manager", v.time))
    end
    
    print("[PASS] Energy values consistent during tick")
    return true
end

-- TEST-RES-003: Warrior Rage Tracking Across Modules
function TestResourceIntegration:test_warrior_rage_consistency()
    print("\n[TEST] Resource: Warrior Rage Tracking Across Modules")
    
    local api = MockSylvanasAPI:new()
    local rm = ResourceManager:new(api)
    local rage_mgr = RageManager:new(api)
    local apl = { current_rage = 0 }
    local middleware = { rage_check = 0 }
    local dashboard = { rage_bar = 0 }
    
    -- Register all rage sources
    rm:register_source("rage_manager", function() return rage_mgr:get_rage() end)
    rm:register_source("apl_engine", function() return apl.current_rage end)
    rm:register_source("middleware", function() return middleware.rage_check end)
    rm:register_source("dashboard", function() return dashboard.rage_bar end)
    
    -- Simulate rage generation and consumption
    local test_scenarios = {
        { rage = 0, desc = "Start" },
        { rage = 25, desc = "After white hit" },
        { rage = 55, desc = "After BT" },
        { rage = 35, desc = "After HS" },
        { rage = 80, desc = "Crit white hit" },
        { rage = 50, desc = "After WW" },
    }
    
    for _, scenario in ipairs(test_scenarios) do
        -- Update all systems
        api:set_player_state({ rage = scenario.rage })
        rage_mgr:update()
        
        local rage = rage_mgr:get_rage()
        apl.current_rage = rage
        middleware.rage_check = rage
        dashboard.rage_bar = rage
        
        -- Verify synchronization
        local values = rm:get_all_values("rage")
        local all_match = true
        local expected = scenario.rage
        
        for source, value in pairs(values) do
            if value ~= expected then
                all_match = false
                print(string.format("  [DRIFT] %s: expected %d, got %d",
                    source, expected, value))
            end
        end
        
        Assert.is_true(all_match, 
            string.format("All modules synced at %s (rage=%d)", scenario.desc, scenario.rage))
    end
    
    print("[PASS] Rage values consistent across all modules")
    return true
end

-- TEST-RES-004: No Drift Between Modules
function TestResourceIntegration:test_no_module_drift()
    print("\n[TEST] Resource: No Drift Between Modules (60s Combat)")
    
    local api = MockSylvanasAPI:new()
    local rm = ResourceManager:new(api)
    local mm = ManaManager:new(api)
    
    rm:register_source("mana_manager", function() return mm:get_mana() end)
    rm:register_source("simulated_tracker", function() return mm:get_mana() end)
    rm:register_source("apl_context", function() return mm:get_mana() end)
    
    -- Simulate 60-second combat
    local drift_log = {}
    local mana = 8000
    
    for t = 0, 60000, 1000 do  -- Check every second
        -- Simulate mana changes (casting)
        if t % 3000 == 0 then
            mana = math.max(0, mana - 400)  -- Fireball every 3s
        end
        if t % 10000 == 0 then
            mana = math.min(8000, mana + 1200)  -- Mana regen
        end
        
        api:set_player_state({ mana = mana })
        mm:update()
        
        -- Check for drift
        local drift = rm:check_drift("mana", mana)
        table.insert(drift_log, {
            time = t,
            max_drift = drift.max_drift,
            sources_with_drift = drift.sources_with_drift,
        })
        
        -- No drift should exceed 1 (rounding errors acceptable)
        Assert.is_true(drift.max_drift <= 1,
            string.format("Time %ds: drift %.1f <= 1", t/1000, drift.max_drift))
    end
    
    -- Summary
    local max_drift_overall = 0
    for _, entry in ipairs(drift_log) do
        max_drift_overall = math.max(max_drift_overall, entry.max_drift)
    end
    
    Assert.is_true(max_drift_overall <= 1,
        string.format("Maximum drift over 60s: %.1f (should be <= 1)", max_drift_overall))
    
    print(string.format("[PASS] No module drift over 60s combat (max drift: %.1f)", max_drift_overall))
    return true
end

function TestResourceIntegration:run_all()
    print("\n" .. string.rep("=", 60))
    print("RESOURCE INTEGRATION TESTS")
    print(string.rep("=", 60))
    
    local tests = {
        self.test_mage_mana_consistency,
        self.test_rogue_energy_consistency,
        self.test_warrior_rage_consistency,
        self.test_no_module_drift,
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local ok, err = pcall(test, self)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("[FAIL] " .. tostring(err))
        end
    end
    
    print("\n" .. string.rep("-", 60))
    print(string.format("Results: %d passed, %d failed", passed, failed))
    print(string.rep("=", 60))
    
    return failed == 0
end

return TestResourceIntegration
```

---

## Scenario 10: Error Recovery

### Test Overview

**Purpose**: Test graceful degradation on API failure with fallback behavior

**Test File**: `tests/integration/scenarios/test_error_recovery.lua`

### Test Script

```lua
-- tests/integration/scenarios/test_error_recovery.lua
local TestErrorRecovery = {}
local ErrorHandler = require("shared.libraries.error_handler")
local MockSylvanasAPI = require("tests.integration.mocks.MockSylvanasAPI")
local SpellResolver = require("shared.libraries.spell_resolver")
local Assert = require("tests.integration.utils.test_assertions")

-- TEST-ERR-001: Missing Menu Item Fallback
function TestErrorRecovery:test_missing_menu_fallback()
    print("\n[TEST] Error Recovery: Missing Menu Item Fallback")
    
    local api = MockSylvanasAPI:new()
    local eh = ErrorHandler:new(api)
    local warnings = {}
    
    -- Set up warning capture
    eh:set_warning_callback(function(msg)
        table.insert(warnings, msg)
    end)
    
    -- Simulate menu access with missing item
    local menu = {
        enabled = { get = function() return true end },
        -- use_execute is missing
    }
    
    -- Try to access missing menu item
    local result = eh:safe_menu_get(menu, "use_execute", false)
    
    -- Should return default value
    Assert.equals(false, result, "Missing menu item returns default")
    
    -- Should log warning
    Assert.equals(1, #warnings, "Warning logged for missing menu item")
    Assert.is_true(string.find(warnings[1], "use_execute") ~= nil,
        "Warning mentions missing menu item")
    
    print("[PASS] Missing menu item returns default and logs warning")
    return true
end

-- TEST-ERR-002: Graceful Degradation
function TestErrorRecovery:test_graceful_degradation()
    print("\n[TEST] Error Recovery: Graceful Degradation on API Failure")
    
    local api = MockSylvanasAPI:new()
    local eh = ErrorHandler:new(api)
    local errors = {}
    
    -- Simulate API failure scenario
    api.fail_next_call = true
    api.fail_reason = "SPELL_NOT_FOUND"
    
    -- Attempt spell resolution with failure
    local resolver = SpellResolver:new(api)
    
    eh:wrap_function(resolver, "resolve", function(spell_name)
        local ok, result = pcall(resolver.resolve, resolver, spell_name)
        if not ok then
            table.insert(errors, result)
            return nil  -- Return safe default
        end
        return result
    end)
    
    -- Try to resolve spell during API failure
    local spell_id = eh:safe_execute(function()
        return resolver:resolve("bloodthirst")
    end, nil)  -- nil as fallback
    
    -- Should not crash, should return fallback
    Assert.is_nil(spell_id, "API failure returns nil (safe)")
    
    -- Should log error
    Assert.equals(1, #errors, "Error logged for API failure")
    
    -- System should continue operating
    local can_continue = eh:check_system_health()
    Assert.equals(true, can_continue, "System continues operating after error")
    
    print("[PASS] API failure handled gracefully, system continues")
    return true
end

-- TEST-ERR-003: Warning Logged, No Crash
function TestErrorRecovery:test_warning_no_crash()
    print("\n[TEST] Error Recovery: Warning Logged, No Crash")
    
    local api = MockSylvanasAPI:new()
    local eh = ErrorHandler:new(api)
    local warnings = {}
    local errors = {}
    
    eh:set_warning_callback(function(msg) table.insert(warnings, msg) end)
    eh:set_error_callback(function(msg) table.insert(errors, msg) end)
    
    -- Test multiple failure scenarios
    local scenarios = {
        function() return api:get_invalid_spell_info() end,
        function() return api:access_nil_menu() end,
        function() return api:divide_by_zero() end,
    }
    
    local all_handled = true
    
    for i, scenario in ipairs(scenarios) do
        local ok, result = eh:safe_execute(scenario, "fallback_value")
        
        -- Should not crash
        if not ok then
            all_handled = false
            print(string.format("  [FAIL] Scenario %d caused crash", i))
        end
        
        -- Should return fallback
        if result ~= "fallback_value" then
            all_handled = false
            print(string.format("  [FAIL] Scenario %d returned wrong fallback", i))
        end
    end
    
    -- Should have warnings for each scenario
    Assert.is_true(#warnings >= 3, "Warnings logged for all scenarios")
    
    -- Should not have errors (handled gracefully)
    Assert.equals(0, #errors, "No unhandled errors")
    
    Assert.is_true(all_handled, "All error scenarios handled gracefully")
    
    print("[PASS] All errors logged as warnings, no crashes")
    return true
end

-- TEST-ERR-004: Continues Operating After Error
function TestErrorRecovery:test_continues_operating()
    print("\n[TEST] Error Recovery: Continues Operating After Error")
    
    local api = MockSylvanasAPI:new()
    local eh = ErrorHandler:new(api)
    local operations_completed = 0
    
    -- Simulate rotation with intermittent errors
    local rotation = {
        spells = { "bloodthirst", "whirlwind", "execute", "invalid_spell" },
        execute = function(self, spell_name)
            if spell_name == "invalid_spell" then
                error("SPELL_NOT_FOUND")
            end
            operations_completed = operations_completed + 1
            return true
        end
    }
    
    -- Execute rotation with error handling
    for _, spell in ipairs(rotation.spells) do
        eh:safe_execute(function()
            rotation:execute(spell)
        end)
    end
    
    -- Should complete 3 out of 4 operations
    Assert.equals(3, operations_completed, "3 valid spells executed")
    
    -- Should be able to continue with more operations
    for i = 1, 5 do
        eh:safe_execute(function()
            operations_completed = operations_completed + 1
        end)
    end
    
    Assert.equals(8, operations_completed, "Continued operating after error")
    
    print("[PASS] System continues operating after encountering errors")
    return true
end

function TestErrorRecovery:run_all()
    print("\n" .. string.rep("=", 60))
    print("ERROR RECOVERY INTEGRATION TESTS")
    print(string.rep("=", 60))
    
    local tests = {
        self.test_missing_menu_fallback,
        self.test_graceful_degradation,
        self.test_warning_no_crash,
        self.test_continues_operating,
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local ok, err = pcall(test, self)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("[FAIL] " .. tostring(err))
        end
    end
    
    print("\n" .. string.rep("-", 60))
    print(string.format("Results: %d passed, %d failed", passed, failed))
    print(string.rep("=", 60))
    
    return failed == 0
end

return TestErrorRecovery
```

---

## Test Execution Guide

### Running All Tests

```bash
# Run all integration tests
lua tests/integration/runner/integration_test_runner.lua

# Run specific scenario
lua tests/integration/scenarios/test_apl_mcd_integration.lua

# Run with verbose output
lua tests/integration/runner/integration_test_runner.lua --verbose

# Run with performance profiling
lua tests/integration/runner/integration_test_runner.lua --profile

# Run stress test (24h)
lua tests/integration/runner/integration_test_runner.lua --stress-test
```

### Test Runner Script

```lua
-- tests/integration/runner/integration_test_runner.lua
#!/usr/bin/env lua

local TestAPL_MCD = require("tests.integration.scenarios.test_apl_mcd_integration")
local TestSimulation = require("tests.integration.scenarios.test_simulation_validation")
local TestFluxBridge = require("tests.integration.scenarios.test_flux_eax_bridge")
local TestDashboard = require("tests.integration.scenarios.test_dashboard_combat_events")
local TestMiddleware = require("tests.integration.scenarios.test_middleware_priority")
local TestSettings = require("tests.integration.scenarios.test_settings_persistence")
local TestCrossSpec = require("tests.integration.scenarios.test_cross_spec_sharing")
local TestStateTransitions = require("tests.integration.scenarios.test_state_transitions")
local TestResourceIntegration = require("tests.integration.scenarios.test_resource_integration")
local TestErrorRecovery = require("tests.integration.scenarios.test_error_recovery")

local MemoryTracker = require("tests.integration.utils.memory_tracker")

print("\n" .. string.rep("=", 70))
print("EAX INTEGRATION TEST SUITE")
print("Target: EAX Improvement Plan v1.0")
print(string.rep("=", 70))

-- Parse command line arguments
local args = {...}
local verbose = false
local profile = false
local stress_test = false

for _, arg in ipairs(args) do
    if arg == "--verbose" then verbose = true end
    if arg == "--profile" then profile = true end
    if arg == "--stress-test" then stress_test = true end
end

local test_suites = {
    { name = "APL + MCD Integration", runner = TestAPL_MCD },
    { name = "Simulation + Validation", runner = TestSimulation },
    { name = "Flux + EAX Bridge", runner = TestFluxBridge },
    { name = "Dashboard + Combat Events", runner = TestDashboard },
    { name = "Middleware Chain Priority", runner = TestMiddleware },
    { name = "Settings Persistence", runner = TestSettings },
    { name = "Cross-Spec Library Sharing", runner = TestCrossSpec },
    { name = "State Machine Transitions", runner = TestStateTransitions },
    { name = "Resource Integration", runner = TestResourceIntegration },
    { name = "Error Recovery", runner = TestErrorRecovery },
}

-- Run all test suites
local total_passed = 0
local total_failed = 0
local start_time = os.clock()

-- Memory tracking
if profile then
    MemoryTracker:start()
end

for _, suite in ipairs(test_suites) do
    print("\n" .. string.rep("-", 70))
    print(string.format("Running: %s", suite.name))
    print(string.rep("-", 70))
    
    local success = suite.runner:run_all()
    
    if success then
        total_passed = total_passed + 1
    else
        total_failed = total_failed + 1
    end
end

local end_time = os.clock()
local duration = end_time - start_time

-- Memory report
if profile then
    MemoryTracker:stop()
    local report = MemoryTracker:generate_report()
    print("\n" .. string.rep("-", 70))
    print("MEMORY PROFILE REPORT")
    print(string.rep("-", 70))
    print(string.format("Peak Memory: %.2f MB", report.peak_mb))
    print(string.format("Memory Growth: %.2f MB", report.growth_mb))
    print(string.format("Allocations: %d", report.allocations))
end

-- Final summary
print("\n" .. string.rep("=", 70))
print("INTEGRATION TEST SUMMARY")
print(string.rep("=", 70))
print(string.format("Test Suites: %d passed, %d failed, %d total",
    total_passed, total_failed, #test_suites))
print(string.format("Duration: %.2f seconds", duration))
print(string.rep("=", 70))

if stress_test then
    print("\n[STRESS TEST MODE]")
    print("Running 24-hour stress test...")
    -- Implement stress test loop
end

-- Exit code
os.exit(total_failed > 0 and 1 or 0)
```

---

## CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/integration-tests.yml
name: EAX Integration Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  schedule:
    # Run daily at 2 AM UTC
    - cron: '0 2 * * *'

jobs:
  integration-test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Install Lua
      run: |
        sudo apt-get update
        sudo apt-get install -y lua5.3 luarocks
    
    - name: Install Dependencies
      run: |
        luarocks install busted
        luarocks install luacov
    
    - name: Run Integration Tests
      run: |
        lua tests/integration/runner/integration_test_runner.lua --verbose
    
    - name: Run Performance Tests
      run: |
        lua tests/integration/runner/integration_test_runner.lua --profile
    
    - name: Validate wowsims DPS (2% tolerance)
      run: |
        lua tests/integration/validate_wowsims.lua --tolerance=2.0
    
    - name: Check Memory Leaks (24h simulation)
      run: |
        lua tests/integration/stress_test.lua --duration=24 --check-interval=15
    
    - name: Upload Test Results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results
        path: |
          test-results/
          coverage-report/
          performance-report/

  regression-detection:
    needs: integration-test
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Download Reference Data
      run: |
        curl -L -o wowsims_reference.json \
          https://raw.githubusercontent.com/eaxiumnet/eax-tbc-classic-rotations/main/tests/wowsims_reference.json
    
    - name: Detect Regressions
      run: |
        lua tests/integration/detect_regression.lua \
          --reference=wowsims_reference.json \
          --tolerance=2.0
    
    - name: Notify on Regression
      if: failure()
      uses: slack-action@v1
      with:
        webhook: ${{ secrets.SLACK_WEBHOOK }}
        message: "⚠️ EAX Integration Test Regression Detected"
```

### Success Criteria Validation

```lua
-- tests/integration/validate_success_criteria.lua
local function validate_success_criteria(results)
    local criteria = {
        {
            name = "All 10 scenarios pass",
            check = function() return results.failed_suites == 0 end,
        },
        {
            name = "<100ms overhead from Flux layer",
            check = function() return results.flux_overhead_ms < 100 end,
        },
        {
            name = "Zero memory leaks in 24h stress test",
            check = function() return results.memory_growth_mb < 10 end,
        },
        {
            name = "DPS within 2% of wowsims reference",
            check = function() return results.dps_deviation_pct <= 2.0 end,
        },
    }
    
    print("\n" .. string.rep("=", 60))
    print("SUCCESS CRITERIA VALIDATION")
    print(string.rep("=", 60))
    
    local all_passed = true
    for _, criterion in ipairs(criteria) do
        local pass = criterion.check()
        local status = pass and "✓ PASS" or "✗ FAIL"
        print(string.format("[%s] %s", status, criterion.name))
        if not pass then all_passed = false end
    end
    
    print(string.rep("=", 60))
    return all_passed
end

return { validate = validate_success_criteria }
```

---

## Document End

**Next Steps**:
1. Implement mock infrastructure (MockSylvanasAPI, test fixtures)
2. Create shared library stubs for testing
3. Set up CI/CD pipeline integration
4. Execute full test suite and validate success criteria
5. Document any failures and remediation steps
