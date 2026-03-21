# Feature Research

**Domain:** TBC Classic Druid rotation reliability (Resto + Feral)
**Researched:** 2026-03-21
**Confidence:** HIGH (internal behavior), MEDIUM (ecosystem norms)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist for reliable Druid behavior in an established rotation suite.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Resto hard role lock in grouped content (party/raid/dungeon/boss) | Healer specs are expected to prioritize healing/utility only in group PvE; intentional DPS in heal role is seen as griefing | MEDIUM | Depends on existing mode detection and role policy (`runtime.cached_mode`, `detect_mode`, `get_effective_mode`) and the current healing-first priority chain in `EAXDruidRestoration/main.lua`; add explicit DPS suppression guard before fallback branch. |
| Resto solo-safe DPS policy | Solo resto should not idle forever, but should only DPS when no ally heal risk exists | MEDIUM | Build on current solo fallback path (`do_dps_fallback`) plus existing mana/health checks; add risk gates (self HP floor, mana floor, threat-safe, no pending heal emergency). |
| Feral combo point source correctness on player object | Finisher reliability is impossible if CPs are read from target/object incorrectly | LOW | Already mostly implemented (`me:get_power(COMBOPOINTS_TBC)` in `EAXDruidFeral/main.lua`); table-stakes is making it deterministic and validated by telemetry when CP reads fail/desync. |
| Feral finisher selection policy: Rip vs Bite by fight state | Standard feral expectation: sustain with Rip on longer targets, Bite for execute/die-soon windows | MEDIUM | Uses existing `try_rip`, `try_ferocious_bite`, bleed-immunity checks, and TTD tracker; tighten ordering rules to prevent missed finishers. |
| Feral finisher timing policy (spend windows, no overcap waste) | Users expect 5 CP spend consistency and minimal CP/energy waste | HIGH | Depends on CP sync + energy pooling + GCD arbitration; requires anti-overcap logic when at high CP and builder would cap before finisher fires. |
| Reliability validation loop for druid fixes | This milestone is explicitly trust-restoration; behavior must be repeatedly verifiable | MEDIUM | Leverage existing tooling (`tools/rotation_validation.lua`, `tools/dps_benchmark.lua`) with scenario checks for group lock, solo DPS gates, and finisher fire-rate consistency. |

### Differentiators (Competitive Advantage)

Features that are not required to ship, but materially improve confidence and market perception.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Context-aware Resto DPS gating (not just `mode == solo`) | Avoids dumb solo DPS behavior during high-risk moments and feels more human | MEDIUM | Extend solo fallback with dynamic risk scoring (incoming damage, mana trend, threat posture) using existing shared threat/mana helpers. |
| Finisher reason telemetry (`why Rip`, `why Bite`, `why hold`) | Makes tuning and bug triage fast; users trust decisions they can audit | MEDIUM | Reuse existing debug/HUD channel and add reason codes around `try_rip`/`try_ferocious_bite` exits. |
| Desync fail-safe recovery for feral CP state | Prevents silent finisher stalls from occasional API anomalies | HIGH | Add fallback reconcile path (short timeout + conservative builder reset) when CP appears stuck across multiple GCDs. |
| Encounter-aware role strictness profiles | Lets healer lock be stricter in raids and more flexible in low-risk solo/daily play | MEDIUM | Integrates with current encounter manager and mode selector without new framework. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem attractive but reduce reliability for this milestone.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| "Let Resto always weave DPS in groups" | Chases parse/throughput behavior | Violates healer role contract and causes avoidable deaths in unstable pulls | Keep strict group lock; allow only explicit utility/control casts and emergency-safe solo DPS. |
| "Always Bite at 5 CP" | Simpler rule, easy to reason about | Loses sustained damage when Rip uptime should be maintained; ignores TTD and bleed immunity | Keep conditional Rip/Bite policy with TTD + execute thresholds. |
| "Aggressive powershift/energy tricks as reliability fix" | Perceived DPS gain | Adds extra moving parts and can mask root CP finisher bugs | Fix CP/finisher arbitration first; tune powershift only after reliability passes. |
| "Per-fight hand-tuned exceptions first" | Fast local wins | Creates brittle logic and maintenance drift across 27 specs | Implement generic policy guards and only add targeted exceptions after repeated evidence. |

## Feature Dependencies

```text
Resto Group Role Lock
    └──requires──> Accurate Mode/Context Detection
                         └──requires──> Stable Party/Raid Object Read

Resto Solo Safe DPS
    └──requires──> Resto Group Role Lock
    └──requires──> Risk Gates (HP/Mana/Threat/No-emergency-heal)

Feral Reliable Finisher Execution
    └──requires──> Correct CP Read on Player
    └──requires──> Finisher Selection Policy (Rip vs Bite)
    └──requires──> Energy/CP Spend Timing Arbitration

Behavior Validation Loop
    └──enhances──> Resto Group/Solo Policy
    └──enhances──> Feral Finisher Reliability
```

### Dependency Notes

- **Resto group lock requires context detection:** existing `detect_mode`/`get_effective_mode` already exists; reliability work is primarily policy enforcement, not new architecture.
- **Resto solo DPS requires group lock first:** without an explicit lock, solo DPS rules leak into grouped scenarios.
- **Feral finisher timing requires CP correctness:** if CP tracking is wrong, all higher-level finisher heuristics become noise.
- **Validation loop depends on existing benchmark tools:** current tooling exists, but needs milestone-specific assertions (group no-DPS, solo safe-DPS, finisher spend cadence).

## MVP Definition

### Launch With (v1.2 milestone close)

- [x] Resto grouped-content DPS suppression policy with explicit allowlist for healing/utility only.
- [x] Resto solo-safe DPS fallback gates (health/mana/threat/emergency-heal guard).
- [x] Feral CP finisher reliability policy (Rip/Bite selection + spend timing).
- [x] Repeatable druid reliability validation checklist integrated into existing validation scripts.

### Add After Validation (v1.2.x)

- [ ] Finisher reason telemetry + HUD indicators — add once baseline pass-rate is stable across test sessions.
- [ ] Adaptive solo DPS aggressiveness profiles — add after no-regression confidence in grouped healer behavior.

### Future Consideration (v2+)

- [ ] Per-encounter policy packs for druid edge cases — defer until broader cross-spec reliability work resumes.
- [ ] Cross-spec shared policy extraction for all healers/melee builders — defer until this druid milestone proves the model.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Resto grouped-content DPS suppression | HIGH | MEDIUM | P1 |
| Resto solo-safe DPS gating | HIGH | MEDIUM | P1 |
| Feral CP finisher reliability (selection + timing) | HIGH | HIGH | P1 |
| Druid-specific validation scenarios | HIGH | MEDIUM | P1 |
| Finisher reason telemetry | MEDIUM | MEDIUM | P2 |
| Adaptive risk profiles | MEDIUM | MEDIUM | P2 |

**Priority key:**
- P1: Must have for milestone close
- P2: Should have after reliability baseline
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Competitor A | Competitor B | Our Approach |
|---------|--------------|--------------|--------------|
| Resto healing priority in group play | Icy Veins TBC guidance emphasizes reactive healing/HoT maintenance and emergency tools over DPS rotation | Common private-server rotation packs often expose toggles but vary in safety defaults | Ship strict group healer lock as default and make solo DPS explicitly gated rather than always-on. |
| Feral finisher usage | Icy Veins TBC guidance prioritizes Rip on live-long targets and Bite when target dies before Rip value | Community scripts commonly use simple CP threshold rules with mixed TTD handling | Keep CP thresholds, but add explicit TTD/execute and anti-waste timing checks for reliability. |

## Sources

- Project scope and constraints: `.planning/PROJECT.md` (HIGH)
- Current Resto logic and mode handling: `EAXDruidRestoration/main.lua` (HIGH)
- Current Feral CP and finisher logic: `EAXDruidFeral/main.lua` (HIGH)
- Existing validation harnesses: `EAXDruidRestoration/tools/rotation_validation.lua`, `EAXDruidFeral/tools/rotation_validation.lua`, `tools/dps_benchmark.lua` (HIGH)
- TBC Resto priority reference (updated Jan 12, 2026): https://www.icy-veins.com/tbc-classic/restoration-druid-healer-pve-rotation-cooldowns-abilities (MEDIUM)
- TBC Feral finisher/powershift reference (updated Jan 12, 2026): https://www.icy-veins.com/tbc-classic/feral-druid-dps-pve-rotation-cooldowns-abilities (MEDIUM)
- Ferocious Bite spell behavior reference (TBC DB): https://wowclassicdb.com/tbc/spell/24248 (LOW-MEDIUM; third-party DB parsing quality varies)

---
*Feature research for: Druid reliability fixes milestone (Resto group-vs-solo, Feral finishers)*
*Researched: 2026-03-21*
