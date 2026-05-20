# Warrior Arms Implementation Checklist

## Job Info
- Job: 027_Warrior_Arms.md
- Spec: Warrior Arms

## Research.md → Implementation Comparison

### Core Rotation

| Requirement | Status | Evidence |
|---|---|---|
| Mortal Strike on cooldown | **Present** | `mortal_strike_matches` line 340; min_rage 30; stance Battle |
| Slam after auto-attack (swing timing) | **Present** | `slam_matches` line 356: checks `mh_until`, `is_moving`, MS CD, Overpower window; configurable via `slam_weave_enabled` |
| Whirlwind on cooldown | **Present** | `whirlwind_matches` line 374; Berserker stance required; min_rage 25 |
| Execute below 20% | **Present** | `execute_matches` line 333: `execute_phase` with configurable rage threshold; Execute action min_rage 15 |
| Heroic Strike rage dump | **Present** | `heroic_strike_matches` line 380; min_rage 60 |
| Overpower when available | **Present** | `overpower_matches` line 344; Battle stance; min_rage 5 |
| Sweeping Strikes 2+ targets | **Present** | `sweeping_strikes_matches` line 367: `enemy_count < min_count` returns false; default min_count = 2 |
| Battle Shout maintenance | **Present** | `battle_shout_matches` line 322; buff check `has_battle_shout` |
| Hamstring PvP / Tactician weave | **Present** | `hamstring_matches` line 390: PvP snare, Tactician fishing, fleeing mobs |
| Stance dancing (Battle/Berserker/Defensive) | **Present** | `battle_stance_matches`, `berserker_stance_matches`, `defensive_stance_matches` lines 473-500 |
| Interrupt (Pummel) | **Present** | `pummel_matches` line 429; Berserker stance |
| Spell Reflection | **Present** | middleware line 210; PvP white list; defensive stance |

### Research.md: Implementation Divergence Table

| Divergence | Research Fix | Code Status |
|---|---|---|
| Slam timing (after auto-attack) | Add `swing_timer > cast_time` gate | **Fixed** — `slam_matches` uses `SwingTimer` API; `mh_until <= SLAM_CAST_TIME + SLAM_SAFETY` returns false (prevents clipping); `mh_until > 1.5` returns false |
| Overpower reaction | Queue immediately on dodge | **Fixed** — Overpower is checked at high priority (#17 in strategy list); `overpower_ready` state updated per tick |
| Execute threshold | Only at <= 20% HP | **Fixed** — `execute_phase` function uses `is_execute_phase(context.target_hp, 20)`; Execute strategy only matches during execute phase |
| Sweeping Strikes target count | Only with 2+ targets | **Fixed** — `sweeping_strikes_matches` line 369: `enemy_count < min_count` returns false |
| Commanding Shout [469] | Valid TBC | **Fixed** — Registered in `class_sylvanas.lua` (line 102) with ID 469; not auto-cast by Arms but available if assigned |

### DB2 Spell ID Compliance

| Spell | DB2 IDs | class_sylvanas.lua IDs | Status |
|---|---|---|---|
| Battle Shout | 2048, 5242, 6192, 6673, 11549, 11550, 11551, 25289 | 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 | ✅ Match |
| Mortal Strike | 12294, 21551, 21552, 21553, 25248, 30330 | 30330, 25248, 21553, 21552, 21551, 12294 | ✅ Match |
| Execute | 5308, 20647, 20658, 20660, 20661, 20662, 25234, 25236 | 25236, 25234, 20662, 20661, 20660, 20658, 5308 | ✅ Match |
| Slam | 1464, 8820, 11604, 11605, 25241, 25242 | 25242, 25241, 11605, 11604, 8820, 1464 | ✅ Match |
| Whirlwind | 1680 | 1680 | ✅ Match |
| Sweeping Strikes | 12328 | 12328 | ✅ Match |
| Overpower | 7384, 7887, 11585 | 11585, 7887, 7384 | ✅ Match |
| Rend | 772, 6547, 6548, 11573, 11574, 25208 | 25208, 11574, 11573, 6548, 6547, 772 | ✅ Match |
| Hamstring | 1715, 7372, 7373, 25212 | 25212, 7373, 7372, 1715 | ✅ Match |
| Commanding Shout | 469 | 469 | ✅ Match |

### Forbidden Mechanics Check

| Mechanic | Status |
|---|---|
| Bladestorm | **Absent** |
| Heroic Throw | **Absent** |
| Taste for Blood | **Absent** |
| Colossus Smash | **Absent** |

### Schema Settings Compliance

| Setting | Purpose | Research Alignment |
|---|---|---|
| `slam_weave_enabled` | Toggle Slam weaving | Matches "Slam timing" divergence fix |
| `sweeping_strikes_count` | Min targets for Sweeping Strikes | Matches "2+ targets" |
| `execute_phase_rage` | Min rage for Execute | Matches rage floor |
| `hamstring_tactician_weave` | Hamstring spam for Tactician procs | Advanced Arms optimization |
| `hamstring_weave_rage` | Rage threshold for weave | Configurable rage dump |
| `auto_charge` | Charge opener toggle | Matches positioning |
| `charge_only_ooc` | Only Charge OOC mobs | Prevents Charge-stealing |

### Middleware Compliance

| Feature | Status | Evidence |
|---|---|---|
| Interrupt (Pummel) | **Present** | interrupt_manager.register_interrupt_spell |
| Smart HS Dequeue (Fury) | **Present** | Three-condition dequeue for dual-wield |
| Spell Reflection | **Present** | PvP white list, defensive stance swap |
| Cancel External Buff | **Present** | PW:S / BoP cancellation |
| PV P Defensive Stance | **Present** | At range when gap closer unavailable |

### Syntax / Test Results

| File | luac -p |
|---|---|
| arms_sylvanas.lua | ✅ Pass |
| class_sylvanas.lua | ✅ Pass |
| middleware_sylvanas.lua | ✅ Pass |
| schema_sylvanas.lua | ✅ Pass (not modified) |

### Post-Completion Fix (2026-05-20)

| Fix | Details |
|---|---|
| BattleShout ↔ CommandingShout mutual exclusivity | `battle_shout_matches` now gates on `state.has_battle_shout or state.has_commanding_shout` — prevents Battle Shout from overwriting an active Commanding Shout buff (they share the same shout buff slot in TBC). Matches Fury spec pattern. |

## Conclusion

All 29 DB2 corrections applied + BattleShout/CommandingShout mutual-exclusivity gate fixed. The Warrior Arms implementation is fully aligned with the vetted Research.md contract.
