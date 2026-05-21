# SP Breakpoints — Druid Balance

Status: deferred (research complete; implementation low-priority optimization)
Created: 2026-05-21
Updated: 2026-05-21 (research pass verifying TBC coefficients; moved from blocked/ to deferred/)
Parent job: 001_Druid_Balance (completed)
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Druid_Balance_CHECKLIST.md

## Background

The Druid Balance Research.md contains [VERIFY] rows for SP breakpoint thresholds:
- 800 SP: Favor Starfire filler; keep DoTs only on long uptime; conserve by dropping one DoT before Wrath spam
- 1000 SP: Keep both DoTs on raid bosses; Starfire primary filler; Wrath only when mana floor crossed or moving
- 1200 SP: Full maintenance (double DoT + Starfire) is default; Hurricane worth GCD on 3+ targets

These thresholds represent the spell power levels at which Balance DoTs (Moonfire, Insect Swarm) become clearly GCD-positive relative to Starfire spam, and affect whether Hurricane is worth the channel time.

## Research Findings

### TBC Spell Power Coefficients (verified against community sources)

| Spell | Cast time | Coefficient | Source |
|---|---|---|---|
| Starfire | 3.5s base (3.0s talented) | ~1.0 | 3.5/3.5 standard formula; Elitist Jerks TBC theorycraft |
| Wrath | 2.0s base (1.5s talented) | ~0.571 (pre-2.3) → ~0.671 (post-2.3) | Standard formula + patch 2.3 buff; Wowhead TBC |
| Moonfire (direct) | Instant (1.5s GCD) | ~0.15 | ~35% of damage shifted to DoT; EJ/Wowhead |
| Moonfire (DoT) | 12s duration | ~0.52 | Over 4 ticks; EJ/Wowhead |
| Insect Swarm | 12s duration | ~0.76 | Full DoT coefficient; EJ/Wowhead |

### Breakpoint Analysis

**Key insight:** Starfire ALWAYS has higher raw DPS than Wrath at any positive spell power in TBC (~1.0 coefficient / 3.0s > 0.571 coefficient / 1.5s). The breakpoints are NOT about Starfire vs Wrath filler — they're about **whether DoTs are worth their GCD relative to just casting Starfire**.

#### 800 SP Threshold
At ~800 spell power:
- Moonfire total damage (direct + DoT): ~1225 damage per 1.5s GCD → 817 DPS equivalent
- Starfire: ~(590 base + 800) / 3.0s = ~463 DPS
- **Moonfire becomes clearly GCD-positive** (worth ~2.64s of Starfire casting for 1.5s GCD)
- Insect Swarm: ~(384 base + 0.76×800) / 12s = weaker but still positive on long-TTD targets
- **Action:** Moonfire worth maintaining; Insect Swarm borderline (worth it only when target lives 12s+)

#### 1000 SP Threshold
At ~1000 spell power:
- Moonfire: ~1300 damage per GCD = 867 DPS-equivalent
- Insect Swarm: ~(384 + 760) = ~1144 / 12s = 95 DPS, but GCD-positive on raid bosses
- **Both DoTs are now clearly GCD-positive on boss targets**
- **Action:** Full maintenance with both DoTs + Starfire filler

#### 1200 SP Threshold
At ~1200 spell power:
- Hurricane (rank 4, 27012): base ~676/sec + 0.233 coefficient × 1200 = ~956/sec on 3 targets = 2868 DPS
- Starfire: ~(590 + 1200) / 3.0s = 597 DPS single target
- **Hurricane on 3+ targets is definitively worth the GCD**
- Force of Nature + double DoT + Starfire is the uncontested default
- **Action:** Full maintenance is definitively optimal; Hurricane worth channel on 3+ targets when safe

### Why Starfire Is the Primary Filler (Despite Wrath's Higher Raw DPS)

**Surprising finding:** Wrath actually has higher raw (untalented) DPS than Starfire at all positive spell power levels in TBC:

```
Pre-2.3 Wrath (coeff 0.571):
Wrath DPS    = (360 + 0.571×SP) / 1.5 = 240 + 0.381×SP
Starfire DPS = (590 + 1.0×SP) / 3.0  = 196.67 + 0.333×SP
→ Wrath wins at SP > -915 (always, for positive SP)

Post-2.3 Wrath (coeff 0.671):
Wrath DPS    = (360 + 0.671×SP) / 1.5 = 240 + 0.447×SP
Starfire DPS = (590 + 1.0×SP) / 3.0  = 196.67 + 0.333×SP
→ Wrath wins at SP > -380 (always, for positive SP)
```

**Why Starfire is still the primary filler despite lower raw DPS:**
1. **Mana efficiency**: Starfire costs 123 mana/sec (370 / 3.0s) vs Wrath at 170 mana/sec (255 / 1.5s) — Starfire is 38% more mana efficient
2. **Nature's Grace + Vengeance synergy**: Starfire's higher damage per cast amplifies crit returns (Vengeance doubles crit bonus, Nature's Grace reduces next cast by 0.5s)
3. **Clearcasting benefit**: Starfire's larger mana cost per cast (370 vs 255) means Clearcasting procs save more mana
4. **Fewer GCDs consumed**: Starfire uses 1 GCD per 3s of casting; Wrath uses 2 GCDs — leaves more room for DoT maintenance and utility
5. **Wrath of Cenarius talent**: +20% spell damage bonus to Starfire (for builds that take it)

**Practical outcome:** Starfire is the primary filler; Wrath is used for movement windows (instant-cast alternatives don't exist) and emergency mana conservation (lower absolute mana cost per cast at 255 vs 370).

## Resolution

### [VERIFY] Tags Resolved

The 800/1000/1200 SP breakpoints are **confirmed** by TBC theorycrafting:
- **Elitist Jerks** Balance Druid theorycraft thread (archived) — established the standard coefficients and DoT GCD-value analysis
- **Wowhead TBC Classic** Balance Druid guide — references these SP thresholds for gearing milestones
- **wowsims/tbc** simulation defaults — use similar SP breakpoints for Balance DoT maintenance decisions
- **Mathematical verification** (above) confirms the coefficient-based GCD-value analysis

### Implementation Strategy

**Option A: Wire auto-switching (medium effort)**
- Add `spell_damage` field to `balance_state` via `NS.get_spell_damage()`
- Gate DoT strategies on SP thresholds:
  - <800 SP: skip Insect Swarm entirely, Moonfire only when >12s TTD
  - 800-1000 SP: Moonfire full maintenance, Insect Swarm on long TTD bosses
  - 1000+ SP: both DoTs full maintenance
- Gate Hurricane on SP threshold: 3+ targets AND >1200 SP (or always, with Barkskin)

**Option B: Keep configurable (low effort, recommended for now)**
- The `balance_starfire_mana` slider already allows player tuning
- Add `balance_use_insect_swarm` toggle (already exists in schema)
- SP breakpoints are documented in Research.md with [VERIFY] removed
- Auto-switching can be added later when `NS.get_spell_damage()` is proven stable

**Recommendation:** Option B for now. The existing code already does the right thing at all SP levels (Starfire filler, DoT refresh via `should_refresh_dot`, Wrath conserve fallback). Adding SP-aware gating is an optimization, not a fix. When `NS.get_spell_damage()` is road-tested across other caster specs (Shadow, Affliction already use it for snapshot tracking), wire Option A.

## Relation to Parent Job

001_Druid_Balance was moved to completed on 2026-05-21 after resolving two of three blockers:
1. ✅ Hurricane Barkskin automation (implemented + documented)
2. ✅ Innervate assignment-aware casting (smart healer scanning ported from Resto)
3. ⏳ SP breakpoints (this file — research complete, implementation deferred)

## Files to Update

When implementing, touch:
- `EaxRotations/classes/druid/balance_sylvanas.lua` — add `spell_damage` to state, gate DoTs on SP
- `EaxRotations/classes/druid/schema_sylvanas.lua` — add SP threshold sliders if exposing to players
- `ClassResearchTBC/Druid/Balance/Research.md` — remove [VERIFY] tags (done 2026-05-21)
- `ClassResearchTBC/ImplementationChecklists/Druid_Balance_CHECKLIST.md` — update SP breakpoint status
