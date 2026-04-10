# EAX Improvement Plan - Missing Specifications
## Critical Appendices Required for Completion

This document provides the missing technical specifications identified in Oracle review. These sections must be added to make the plan actionable.

---

## Appendix X: Sync Tooling Technical Specification

### X.1 Problem Statement

Maintaining 870 files across 29 specs with standardized patterns requires automated tooling. Manual updates are error-prone and scale linearly with spec count.

### X.2 Sync Algorithm

```python
# tools/sync_library_updates.py - Core Algorithm

class LibrarySync:
    """
    Three-way synchronization between reference, working copy, and specs.
    """
    
    def sync(self, library_name: str, specs: List[str]) -> SyncResult:
        reference = load_reference(f"standards/{library_name}_reference.lua")
        
        for spec in specs:
            spec_path = f"{spec}/libraries/{library_name}.lua"
            working_copy = load(spec_path)
            
            # Generate ASTs
            ref_ast = parse_lua(reference)
            work_ast = parse_lua(working_copy)
            
            # Extract public API (function signatures)
            ref_api = extract_public_api(ref_ast)
            work_api = extract_public_api(work_ast)
            
            # Check for API drift
            if not apis_match(ref_api, work_api):
                # Spec has custom extensions - preserve with merge
                merged = three_way_merge(ref_ast, work_ast, find_base(spec_path))
                write(spec_path, generate_lua(merged))
                result.add_warning(f"{spec}: API drift detected, merged changes")
            else:
                # Clean sync - spec matches reference API
                write(spec_path, generate_lua(ref_ast))
                result.add_synced(spec)
        
        return result

    def three_way_merge(self, ref: AST, work: AST, base: AST) -> AST:
        """
        Three-way merge strategy:
        1. Functions in ref but not in work: ADD
        2. Functions in work but not in ref: KEEP (spec-specific)
        3. Functions in both: Use ref implementation UNLESS marked @spec_override
        4. Config/constants: Always use ref unless @spec_config marker
        """
        merged = AST()
        
        for func in ref.functions:
            if func.name in work.functions:
                if has_annotation(work.functions[func.name], "@spec_override"):
                    merged.add(work.functions[func.name])  # Keep spec version
                else:
                    merged.add(func)  # Use reference
            else:
                merged.add(func)  # Add new from reference
        
        for func in work.functions:
            if func.name not in ref.functions:
                merged.add(func)  # Keep spec-specific extensions
        
        return merged
```

### X.3 Conflict Resolution Strategy

**Scenario 1: Clean Sync (95% of cases)**
- Spec file matches reference API exactly
- Action: Overwrite with new reference version
- No human intervention needed

**Scenario 2: API Extension (4% of cases)**
- Spec has added new functions (not in reference)
- Action: Three-way merge - keep extensions, update core
- Log warning: "Spec X has custom extensions to utils.lua"

**Scenario 3: API Drift (1% of cases)**
- Spec has modified core function signatures
- Action: Three-way merge + create conflict report
- Human review required: Spec violates standards

```python
# Conflict resolution flow
CONFLICT_RESOLUTION = {
    "clean_sync": {
        "auto_resolve": True,
        "action": "overwrite",
        "notify": False
    },
    "api_extension": {
        "auto_resolve": True, 
        "action": "three_way_merge",
        "notify": True,  # Log for audit
        "warning": "Spec has library extensions"
    },
    "api_drift": {
        "auto_resolve": False,
        "action": "generate_report",
        "notify": True,
        "requires_review": True,
        "escalation": "Standards committee"
    }
}
```

### X.4 Consistency Checking Algorithm

```python
# tools/check_library_consistency.py

class ConsistencyChecker:
    def check_all(self) -> ConsistencyReport:
        report = ConsistencyReport()
        
        for library_type in LIBRARY_TYPES:
            reference = load_reference(library_type)
            ref_fingerprint = generate_fingerprint(reference)
            
            for spec in ALL_SPECS:
                spec_file = f"{spec}/libraries/{library_type}.lua"
                spec_content = load(spec_file)
                spec_fingerprint = generate_fingerprint(spec_content)
                
                # Check pattern compliance (not exact match)
                compliance_score = compare_patterns(ref_fingerprint, spec_fingerprint)
                
                if compliance_score < 0.95:  # 95% threshold
                    report.add_violation(
                        spec=spec,
                        library=library_type,
                        score=compliance_score,
                        differences=find_differences(ref_fingerprint, spec_fingerprint)
                    )
        
        return report
    
    def generate_fingerprint(self, content: str) -> Fingerprint:
        """
        Pattern fingerprint ignores:
        - Whitespace and formatting
        - Variable names (local semantics)
        - Spell IDs and constants
        
        Captures:
        - Function signatures (names, param count, param types via usage)
        - Control flow patterns (if/else structure, loop patterns)
        - API call patterns (what APIs are called, in what order)
        - Error handling patterns (pcall usage, nil checks)
        """
        ast = parse_lua(content)
        return Fingerprint(
            function_signatures=extract_signatures(ast),
            control_flow_patterns=extract_control_flow(ast),
            api_usage_patterns=extract_api_usage(ast),
            error_handling_patterns=extract_error_handling(ast)
        )
```

### X.5 Implementation Timeline for Sync Tooling

**Week 1-2: Core Infrastructure**
- Lua AST parser (using existing lua-parser library)
- Fingerprint generation system
- Basic diff/merge algorithms

**Week 3: Sync Engine**
- Three-way merge implementation
- Conflict detection and reporting
- CLI interface design

**Week 4: CI Integration**
- GitHub Actions workflow
- Pre-commit hooks
- Drift notification system

**Week 5: Validation**
- Test with 5 pilot specs
- Measure sync success rate
- Iterate on conflict scenarios

**Week 6: Documentation**
- Sync tooling user guide
- Standards committee process
- Rollback procedures

**Total: 6 weeks for robust sync tooling (must complete before Phase 2)**

### X.6 Resource Requirements

| Role | Effort | Skills |
|------|--------|--------|
| Core Sync Developer | 4 weeks | Python, AST parsing, algorithm design |
| Lua Parser Specialist | 2 weeks | Lua grammar, parsing techniques |
| CI/CD Engineer | 1 week | GitHub Actions, automation |
| QA/Testing | 1 week | Test case design, edge case analysis |

---

## Appendix Y: Simulation Engine Architecture

### Y.1 Design Goals

1. **Accuracy**: DPS within 15% of wowsims (relaxed from 5% - more realistic)
2. **Performance**: 1000 iterations in <30 seconds (30ms per iteration)
3. **Extensibility**: Support all 29 specs with class-specific mechanics
4. **Validation**: Match known TBC spell damage values

### Y.2 Event-Driven Architecture

```lua
-- simulation/engine_core.lua

local SimulationEngine = {
    current_time = 0,
    event_queue = PriorityQueue(),  -- Min-heap by time
    state = nil,  -- Player/target/buff state
    log = {},  -- Action log for debugging
}

-- Event Types
local EVENT_TYPES = {
    GCD_READY = "gcd_ready",
    COOLDOWN_READY = "cd_ready",
    BUFF_EXPIRE = "buff_expire",
    DEBUFF_TICK = "debuff_tick",
    MANA_TICK = "mana_tick",
    AUTO_ATTACK = "auto_attack",
    CAST_COMPLETE = "cast_complete",
    EXECUTE_PHASE = "execute_phase",
}

function SimulationEngine.run(scenario, duration)
    -- Initialize state
    SimulationEngine.state = GameState.new(scenario)
    SimulationEngine.current_time = 0
    SimulationEngine.log = {}
    
    -- Seed initial events
    SimulationEngine.schedule_event(0, EVENT_TYPES.GCD_READY)
    SimulationEngine.schedule_event(0, EVENT_TYPES.AUTO_ATTACK)
    
    -- Main event loop
    while SimulationEngine.current_time < duration do
        local event = SimulationEngine.event_queue:pop()
        SimulationEngine.current_time = event.time
        
        -- Process event
        SimulationEngine.handle_event(event)
        
        -- Run rotation logic at GCD events
        if event.type == EVENT_TYPES.GCD_READY then
            local action = scenario.rotation:select_action(SimulationEngine.state)
            SimulationEngine.execute_action(action)
        end
    end
    
    return SimulationResults.new(SimulationEngine.log)
end

function SimulationEngine.handle_event(event)
    local handlers = {
        [EVENT_TYPES.GCD_READY] = function()
            SimulationEngine.state.gcd_ready = true
        end,
        
        [EVENT_TYPES.COOLDOWN_READY] = function()
            local spell = event.data.spell
            SimulationEngine.state.cooldowns[spell] = 0
        end,
        
        [EVENT_TYPES.BUFF_EXPIRE] = function()
            local buff = event.data.buff
            SimulationEngine.state.buffs[buff] = nil
        end,
        
        [EVENT_TYPES.AUTO_ATTACK] = function()
            local damage = calculate_auto_attack_damage(SimulationEngine.state)
            SimulationEngine.log_damage("auto_attack", damage, SimulationEngine.current_time)
            
            -- Reschedule next auto attack
            local swing_speed = SimulationEngine.state.player.swing_speed
            SimulationEngine.schedule_event(
                SimulationEngine.current_time + swing_speed,
                EVENT_TYPES.AUTO_ATTACK
            )
        end,
        
        -- ... other handlers
    }
    
    handlers[event.type]()
end

function SimulationEngine.execute_action(action)
    if not action then return end
    
    -- Calculate cast time (haste-modified)
    local cast_time = calculate_cast_time(action, SimulationEngine.state)
    
    -- Consume resources
    SimulationEngine.state.player.rage = SimulationEngine.state.player.rage - action.rage_cost
    SimulationEngine.state.gcd_ready = false
    SimulationEngine.state.cooldowns[action.spell_id] = action.cooldown
    
    -- Schedule completion
    if cast_time > 0 then
        SimulationEngine.schedule_event(
            SimulationEngine.current_time + cast_time,
            EVENT_TYPES.CAST_COMPLETE,
            {action = action}
        )
    else
        -- Instant cast
        SimulationEngine.apply_action_effects(action)
    end
    
    -- Schedule next GCD
    SimulationEngine.schedule_event(
        SimulationEngine.current_time + 1.5,  -- GCD duration (haste modified)
        EVENT_TYPES.GCD_READY
    )
    
    -- Log action
    table.insert(SimulationEngine.log, {
        time = SimulationEngine.current_time,
        action = action.name,
        type = "cast_start"
    })
end
```

### Y.3 State Management

```lua
-- simulation/state.lua

local GameState = {}

function GameState.new(scenario)
    return {
        -- Player state
        player = {
            hp = scenario.player_hp or 100,
            mana = scenario.player_mana or 10000,
            rage = 0,
            energy = 100,
            combo_points = 0,
            
            -- Stats
            attack_power = scenario.attack_power or 2000,
            spell_power = scenario.spell_power or 800,
            crit_chance = scenario.crit_chance or 0.25,
            haste_rating = scenario.haste_rating or 0,
            
            -- Swing timer
            swing_speed = scenario.swing_speed or 2.6,
            main_hand_damage = scenario.main_hand_damage or {min=100, max=150},
            off_hand_damage = scenario.off_hand_damage or {min=50, max=75},
        },
        
        -- Target state
        target = {
            hp = 100,
            armor = scenario.target_armor or 7684,
            level = scenario.target_level or 73,
            is_boss = true,
        },
        
        -- Cooldowns (spell_id -> time_ready)
        cooldowns = {},
        
        -- Buffs/debuffs (buff_id -> {stacks, expiration_time})
        buffs = {},
        debuffs = {},
        
        -- Combat state
        in_combat = true,
        combat_time = 0,
        time_to_die = scenario.duration or 300,
        
        -- Rotation state
        gcd_ready = true,
        casting = nil,  -- Action currently being cast
    }
end

-- Buff/debuff management
function GameState:apply_buff(buff_id, duration, stacks)
    stacks = stacks or 1
    self.buffs[buff_id] = {
        stacks = stacks,
        expiration_time = self.combat_time + duration,
        application_time = self.combat_time
    }
end

function GameState:has_buff(buff_id)
    local buff = self.buffs[buff_id]
    if not buff then return false end
    return buff.expiration_time > self.combat_time
end

function GameState:get_buff_stacks(buff_id)
    local buff = self.buffs[buff_id]
    if not buff or buff.expiration_time <= self.combat_time then
        return 0
    end
    return buff.stacks
end
```

### Y.4 Damage Calculation

```lua
-- simulation/damage.lua

local DamageCalc = {}

-- TBC Armor mitigation formula
function DamageCalc.calculate_armor_mitigation(armor, attacker_level)
    local level_diff = attacker_level - 60
    local mitigation = armor / (armor + 400 + 85 * attacker_level + level_diff * 8)
    return math.min(mitigation, 0.75)  -- Cap at 75%
end

-- Spell damage calculation
function DamageCalc.calculate_spell_damage(spell, state)
    local base_damage = spell.base_damage or {min=0, max=0}
    local spell_power_coefficient = spell.coefficient or 0
    
    -- Add spell power contribution
    local spell_power = state.player.spell_power
    local bonus_damage = spell_power * spell_power_coefficient
    
    -- Apply damage modifiers
    local damage = random_between(base_damage.min, base_damage.max) + bonus_damage
    
    -- Apply talents/buffs
    for buff_id, buff in pairs(state.buffs) do
        if BUFF_MODIFIERS[buff_id] then
            damage = damage * BUFF_MODIFIERS[buff_id](spell, state)
        end
    end
    
    -- Apply target mitigation
    local target_resistance = state.target.resistances[spell.school] or 0
    damage = damage * (1 - target_resistance / (target_resistance + 400))
    
    -- Crit check
    if math.random() < state.player.crit_chance then
        damage = damage * 1.5  -- TBC crit multiplier
    end
    
    return damage
end

-- Melee damage calculation
function DamageCalc.calculate_melee_damage(weapon_damage, state, is_offhand)
    local ap_contribution = state.player.attack_power / 14 * state.player.swing_speed
    local damage = random_between(weapon_damage.min, weapon_damage.max) + ap_contribution
    
    -- Off-hand penalty
    if is_offhand then
        damage = damage * 0.5
    end
    
    -- Armor mitigation
    local mitigation = calculate_armor_mitigation(state.target.armor, 70)
    damage = damage * (1 - mitigation)
    
    -- Glancing blow check (against boss)
    if state.target.is_boss and math.random() < 0.40 then
        damage = damage * random_between(0.01, 0.99)  -- Glancing penalty
    end
    
    -- Crit check
    if math.random() < state.player.crit_chance then
        damage = damage * 2.0  -- Melee crit multiplier
    end
    
    return damage
end
```

### Y.5 Class-Specific Rotation Integration

```lua
-- simulation/rotations/warrior_fury.lua

local WarriorFuryRotation = {}

function WarriorFuryRotation.select_action(state)
    -- Priority list (from wowsims analysis)
    local priorities = {
        {spell = "Bloodthirst", condition = function() 
            return state.player.rage >= 30 and state.cooldowns["Bloodthirst"] <= 0
        end},
        {spell = "Whirlwind", condition = function()
            return state.player.rage >= 25 and state.cooldowns["Whirlwind"] <= 0
        end},
        {spell = "HeroicStrike", condition = function()
            return state.player.rage >= 50 and state.gcd_ready
        end},
    }
    
    for _, priority in ipairs(priorities) do
        if priority.condition() then
            return SPELLS[priority.spell]
        end
    end
    
    return nil  -- No action (wait)
end
```

### Y.6 Implementation Timeline (Revised)

**Realistic Timeline for Simulation: 12 weeks (not 3)**

| Week | Deliverable | Verification |
|------|-------------|--------------|
| 1-2 | Event loop core + priority queue | Unit tests: events execute in correct order |
| 3-4 | State management + buff/debuff system | Tests: buffs expire correctly, stacks work |
| 5-6 | Damage calculation formulas | Validate vs known TBC values (10 tests) |
| 7-8 | Class rotation adapters (5 specs) | Compare to wowsims: within 20% |
| 9-10 | Full 29 spec support | All specs produce DPS output |
| 11 | Performance optimization | 1000 iterations < 30 seconds |
| 12 | Validation against wowsims | Within 15% accuracy target |

**Total: 12 weeks for simulation (was 3 weeks in original plan)**

### Y.7 Resource Requirements

| Role | Effort | Skills |
|------|--------|--------|
| Simulation Architect | 8 weeks | Event-driven systems, game mechanics |
| Damage Formula Specialist | 4 weeks | TBC mechanics, math |
| Rotation Integrator | 6 weeks | Lua, all 9 TBC classes |
| Performance Engineer | 2 weeks | Profiling, optimization |

---

## Appendix Z: APL Parser Grammar Specification

### Z.1 Supported SimC APL Subset

**EBNF Grammar:**
```ebnf
apl_file        ::= action_list+ ;
action_list     ::= "actions" ("." action_list_name)? "=" action_expr ("/" action_expr)* ;
action_list_name::= "precombat" | "aoe" | "cooldowns" | identifier ;
action_expr     ::= action_call | action_if | action_variable ;
action_call     ::= spell_name ("," target)? ;
action_if       ::= action_call "," "if=" condition ;
condition       ::= boolean_expr ;
boolean_expr    ::= comparison_expr | boolean_expr logical_op boolean_expr | "!" boolean_expr ;
comparison_expr ::= value_expr comparison_op value_expr ;
value_expr      ::= number | variable | function_call | "(" value_expr ")" ;
variable        ::= scope "." property ("." property)* ;
scope           ::= "target" | "player" | "cooldown" | "buff" | "debuff" | "talent" | "set_bonus" ;
property        ::= identifier | "cooldown" | "remains" | "up" | "down" | "stack" | "charges" | "duration" ;
function_call   ::= function_name "(" (value_expr ("," value_expr)*)? ")" ;
function_name   ::= "time_to_die" | "incoming_damage" | "health_pct" | "mana_pct" | "rage" | "energy" ;
comparison_op   ::= "<" | ">" | "<=" | ">=" | "=" | "!=" ;
logical_op      ::= "&" | "|" ;
spell_name      ::= identifier ("_" identifier)* ;
target          ::= "target" | "player" | "focus" ;
identifier      ::= letter (letter | digit | "_")* ;
```

### Z.2 Condition Evaluators (Concrete Implementation)

```lua
-- apl/conditions.lua - Concrete evaluators

local Conditions = {}

-- Scope: target
Conditions["target.health.pct"] = function(ctx, op, val)
    local hp_pct = ctx.target.hp / ctx.target.max_hp * 100
    return compare(hp_pct, op, tonumber(val))
end

Conditions["target.time_to_die"] = function(ctx, op, val)
    return compare(ctx.target.ttd, op, tonumber(val))
end

Conditions["target.debuff.remains"] = function(ctx, debuff_name, op, val)
    local debuff_id = DEBUFF_MAP[debuff_name]
    local remains = ctx.target:get_debuff_remains(debuff_id)
    return compare(remains, op, tonumber(val))
end

-- Scope: player
Conditions["player.rage"] = function(ctx, op, val)
    return compare(ctx.player.rage, op, tonumber(val))
end

Conditions["player.mana.pct"] = function(ctx, op, val)
    local mana_pct = ctx.player.mana / ctx.player.max_mana * 100
    return compare(mana_pct, op, tonumber(val))
end

Conditions["player.buff.remains"] = function(ctx, buff_name, op, val)
    local buff_id = BUFF_MAP[buff_name]
    local remains = ctx.player:get_buff_remains(buff_id)
    return compare(remains, op, tonumber(val))
end

Conditions["player.buff.up"] = function(ctx, buff_name)
    local buff_id = BUFF_MAP[buff_name]
    return ctx.player:has_buff(buff_id)
end

Conditions["player.buff.down"] = function(ctx, buff_name)
    return not Conditions["player.buff.up"](ctx, buff_name)
end

Conditions["player.buff.stack"] = function(ctx, buff_name, op, val)
    local buff_id = BUFF_MAP[buff_name]
    local stacks = ctx.player:get_buff_stacks(buff_id)
    return compare(stacks, op, tonumber(val))
end

-- Scope: cooldown
Conditions["cooldown.remains"] = function(ctx, spell_name, op, val)
    local spell = SPELLS[spell_name]
    local remains = math.max(0, ctx.cooldowns[spell.id] - ctx.current_time)
    return compare(remains, op, tonumber(val))
end

Conditions["cooldown.up"] = function(ctx, spell_name)
    return Conditions["cooldown.remains"](ctx, spell_name, "<=", 0)
end

Conditions["cooldown.ready"] = Conditions["cooldown.up"]  -- Alias

-- Helper function
function compare(a, op, b)
    if op == "<" then return a < b end
    if op == ">" then return a > b end
    if op == "<=" then return a <= b end
    if op == ">=" then return a >= b end
    if op == "=" or op == "==" then return math.abs(a - b) < 0.001 end
    if op == "!=" or op == "<>" then return math.abs(a - b) >= 0.001 end
    error("Unknown operator: " .. op)
end
```

### Z.3 Parser Implementation

```lua
-- apl/parser.lua

local Parser = {}

function Parser.parse(apl_string)
    local tokens = tokenize(apl_string)
    local pos = 1
    
    local function peek()
        return tokens[pos]
    end
    
    local function consume()
        local token = tokens[pos]
        pos = pos + 1
        return token
    end
    
    local function expect(token_type)
        local token = consume()
        if token.type ~= token_type then
            error("Expected " .. token_type .. " but got " .. token.type)
        end
        return token
    end
    
    -- Parse actions list
    local actions = {}
    
    while pos <= #tokens do
        local action = parse_action()
        table.insert(actions, action)
        
        -- Check for separator
        if peek() and peek().type == "SEPARATOR" then
            consume()  -- consume "/"
        end
    end
    
    return actions
end

function parse_action()
    local spell_name = expect("IDENTIFIER").value
    
    -- Check for target
    local target = "target"  -- default
    if peek() and peek().type == "COMMA" then
        consume()  -- consume ","
        expect("KEYWORD")  -- "target"
        target = consume().value
    end
    
    -- Check for condition
    local condition = nil
    if peek() and peek().type == "COMMA" then
        consume()  -- consume ","
        expect("KEYWORD")  -- "if"
        expect("ASSIGN")   -- "="
        condition = parse_condition()
    end
    
    return {
        type = "action",
        spell = spell_name,
        target = target,
        condition = condition
    }
end

function parse_condition()
    -- Parse condition expressions (simplified for MVP)
    -- Full boolean expression parsing for Phase 2
    
    local left = parse_value()
    local op = expect("OPERATOR").value
    local right = parse_value()
    
    return {
        type = "comparison",
        left = left,
        operator = op,
        right = right
    }
end
```

### Z.4 Implementation Timeline

**APL Parser: 4 weeks (not 2)**

| Week | Deliverable | Verification |
|------|-------------|--------------|
| 1 | Tokenizer + basic grammar | Tokenize 50 sample APL lines |
| 2 | Parser for simple conditions | Parse 90% of Fury Warrior APL |
| 3 | Complex conditions + boolean logic | Parse Mage Arcane APL |
| 4 | Lua code generation | Generated code runs in mock context |

### Z.5 Resource Requirements

| Role | Effort | Skills |
|------|--------|--------|
| Parser Developer | 3 weeks | Parsing, compiler design, Lua |
| Grammar Specialist | 1 week | EBNF, formal languages |

---

## Appendix AA: Resource Allocation Plan

### AA.1 Team Structure

**Phase 1-2: Foundation (Weeks 1-12)**
```
Team Lead (1 person)
├── Sync Tooling Developer (1 person) - Weeks 1-6
├── Test Framework Developer (1 person) - Weeks 1-4
├── APL Parser Developer (1 person) - Weeks 5-8
└── Standards Engineer (1 person) - Weeks 3-12
```

**Phase 3: Simulation (Weeks 13-24)**
```
Team Lead (1 person)
├── Simulation Architect (1 person) - Weeks 13-24
├── Damage Formula Specialist (1 person) - Weeks 13-18
└── Rotation Integrators (2 people) - Weeks 17-24
```

**Phase 4-5: Optimization (Weeks 25-30)**
```
Team Lead (1 person)
├── Optimization Engineer (1 person) - Weeks 25-30
├── UI Developer (1 person) - Weeks 27-30
└── Documentation Writer (1 person) - Weeks 28-30
```

### AA.2 Skill Requirements Matrix

| Role | Primary Skills | Secondary Skills |
|------|---------------|------------------|
| Sync Tooling Developer | Python, AST parsing, algorithms | Lua (reading), git internals |
| Test Framework Developer | Lua, testing frameworks, CI/CD | WoW API knowledge |
| APL Parser Developer | Compiler design, parsing, Lua | TBC class knowledge |
| Simulation Architect | Event-driven systems, game dev | TBC mechanics expertise |
| Damage Formula Specialist | Math, statistics | TBC theorycrafting |
| Rotation Integrator | Lua, TBC classes (2+ specs each) | Simulation concepts |
| Standards Engineer | Code review, documentation | All of the above |

### AA.3 Work Unit Assignments

| Work Unit | Assigned To | Weeks | Dependencies |
|-----------|-------------|-------|--------------|
| 1.1 Test Framework | Test Framework Dev | 1-4 | None |
| 1.2 Standards (Core) | Standards Engineer | 3-4 | 1.1 started |
| 1.3 Standards (Managers) | Standards Engineer | 5-6 | 1.2 |
| 1.x Sync Tooling | Sync Tooling Dev | 1-6 | None (parallel) |
| 2.1 Standards Rollout | Standards Engineer + Rotation Integrators | 7-10 | 1.2, 1.3, 1.x |
| 2.2 APL System | APL Parser Dev | 7-10 | 1.2 |
| 2.3 Test Coverage | Test Framework Dev | 9-12 | 2.1 |
| 3.1 MCD System | Standards Engineer | 13-15 | 2.2 |
| 3.2 Simulation | Simulation Architect + Damage Specialist | 13-24 | 2.1 |
| 3.3 AoE Logic | Rotation Integrators | 19-20 | 3.1 |
| 4.1 Stat Weights | Optimization Engineer | 21-22 | 3.2 |
| 4.2 Gear Comparison | Optimization Engineer | 23-24 | 3.2 |
| 4.3 DPS Reporting | UI Developer | 25-26 | 3.2 |
| 5.1 Haste Breakpoints | Optimization Engineer | 27 | 4.1 |
| 5.2 Encounter Scripts | Rotation Integrators | 28-29 | 3.2 |
| 5.3 Documentation | Documentation Writer | 28-30 | All |

---

## Appendix AB: Risk Quantification

### AB.1 Risk Register with Probability/Impact

| Risk | Probability | Impact (weeks) | Mitigation Cost | Expected Value |
|------|------------|----------------|-----------------|----------------|
| Sync tooling complexity underestimated | 60% | +4 weeks | 2 weeks buffer | 2.4 weeks |
| Simulation accuracy can't reach 15% | 40% | +6 weeks (rebuild) | Early validation | 2.4 weeks |
| APL grammar more complex than expected | 50% | +3 weeks | Simpler subset | 1.5 weeks |
| Team member leaves mid-project | 20% | +4 weeks (onboarding) | Knowledge docs | 0.8 weeks |
| Project Sylvanas API changes | 15% | +2 weeks (adaptation) | API abstraction | 0.3 weeks |
| wowsims validation data unavailable | 30% | +2 weeks (alternative) | Multiple methods | 0.6 weeks |

**Total Expected Delay: 8 weeks**

**Contingency Recommendation**: Add 10 weeks buffer to timeline (30 → 40 weeks) or accept 80% completion probability at 30 weeks.

### AB.2 Risk Mitigation Priority

**High Priority (Address in Phase 1):**
1. Sync tooling complexity - Build proof-of-concept in Week 1-2
2. Simulation accuracy - Validate event loop against known values Week 5-6

**Medium Priority (Monitor during project):**
3. APL grammar complexity - Weekly grammar reviews
4. Team member departure - Pair programming, documentation

**Low Priority (Accept or transfer):**
5. API changes - Accept risk (low probability)
6. Validation data - Have 5 fallback methods

---

## Appendix AC: Proof of Concept Requirements

### AC.1 PoC Scope

Before Phase 1 approval, demonstrate:

1. **Test Framework Working**
   - 1 spec with >30% coverage (WarriorFury)
   - WoWAPIMock with 20+ functions
   - CI running `busted tests/` successfully

2. **Sync Tooling Working**
   - Propagate change to utils.lua across 5 specs
   - Detect intentional drift in 1 spec
   - Three-way merge for spec with extensions

3. **Standards Model Validated**
   - 3 specs using standardized libraries
   - Consistency checker reports >95% compliance
   - Standalone .zips build and validate

4. **APL Parser Prototype**
   - Parse 10-line Warrior Fury APL
   - Generate executable Lua
   - Run in mock context and produce actions

5. **Simulation Prototype**
   - Event loop runs 60-second combat
   - Produces DPS output within 50% of wowsims (rough validation)
   - 100 iterations in <10 seconds

### AC.2 PoC Timeline: 2 weeks

| Week | Deliverable | Success Criteria |
|------|-------------|------------------|
| 1 | Test framework + 1 spec | CI passes, coverage >30% |
| 1 | Sync tooling MVP | Sync utils to 5 specs successfully |
| 2 | APL parser prototype | Parse Fury APL, generate code |
| 2 | Simulation prototype | Run 60s combat, output DPS |

**PoC Success = Go/No-Go for full project**

---

## Summary: What Makes This Plan COMPLETE

The original plan was a **vision** (what to build). These appendices add:

1. **Sync Tooling Spec** (Appendix X): Concrete algorithm, conflict resolution, timeline
2. **Simulation Architecture** (Appendix Y): Event loop, state management, damage formulas, realistic 12-week timeline
3. **APL Grammar** (Appendix Z): EBNF grammar, concrete condition evaluators, parser pseudocode
4. **Resource Plan** (Appendix AA): Team structure, skill matrix, work assignments
5. **Risk Quantification** (Appendix AB): Probability/impact scores, expected delays, mitigation priority
6. **PoC Requirements** (Appendix AC): Go/No-Go criteria before full commitment

**With these additions, the plan becomes actionable.**

---

*Add these appendices to EAX_IMPROVEMENT_PLAN_FINAL.md to complete the planning phase.*
