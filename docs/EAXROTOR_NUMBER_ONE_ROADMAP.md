# EaxRotations: Honest Assessment & Roadmap to #1

> **Status:** Internal strategic document  
> **Purpose:** Brutally honest audit of where we are vs. where we need to be, with a concrete execution plan to become the undisputed #1 TBC Classic rotation system.  
> **References:** Flux AIO, Sonah, Hekili, MaxDps, Ovale, WeakAuras, TellMeWhen, SimC

---

## Executive Summary

**We are NOT #1 yet. We are a solid #3-4 with #1 potential.**

Our framework infrastructure (dashboard, PvP systems, OOC manager, shared modules) is **genuinely best-in-class**. But our **class implementation depth is wildly uneven** — roughly 10 specs are thoughtfully crafted, 17 are boilerplate spell lists, and 5 files aren't even playstyles. The systems that make a rotation addon *trustworthy* — theorycraft integration, real-time simulation, and consistent spec depth — are either missing or underdeveloped.

The good news: **the hard architecture is done.** The gap is execution depth, not architectural vision. This document tells you exactly what to fix and in what order.

---

## Part 1: Honest Current State

### What We Actually Have (Real)

| Category | Reality | Grade |
|----------|---------|-------|
| **Dashboard / HUD** | Full overlay: GCD bar, swing timer, energy tick sweep + marker, combo point pips, 6-slot action history (CLEU), cooldown/buff/debuff icon grids with tooltips, color-coded threat bar, DoT tracker, burst indicator. Position persists to JSON. | **A+** |
| **PvP Infrastructure** | DR tracker (7 categories, ~80 spells), enemy CD tracker (376 lines), arena priority scoring with class-based threat taxonomy, PvP burst window scoring, interrupt manager with priority mapping. | **A** |
| **Framework / Shared Modules** | Spell resolver with caching, combat context (2s throttle), middleware chain, force commands, custom rotation builder, OOC buff urgency system (green/yellow/red), gear set tracker (~133 sets), trinket/racial/weapon imbue managers. | **A-** |
| **Out-of-Combat Manager** | Real buff urgency coloring, mana floor respect, class-specific buff mappings for all 9 classes, 1s throttling. | **A** |
| **Build / Export Pipeline** | `exporter.lua` converts rotation strategies to JSON for Go-based simulators. `optimizer.lua` has a (unused) DecisionCache. | **B+** |
| **Settings / Schema** | Per-spec schema files with declarative menus. Settings sync with persistent storage. Quick toggles bound to keybinds. | **B+** |
| **Class Coverage** | 32 files across 9 classes. | **B** (see below) |
| **Spec Depth** | ~10 specs have custom state builders and nuanced mechanics. ~17 are boilerplate spell lists. | **C+** |
| **Damage Meter** | Timer-based guesswork (`damage_meter_sylvanas.lua`). Not real combat log parsing. | **D** |
| **Theorycraft Bridge** | No SimC APL import. No real-time DPS simulation. No APL visualizer. | **F** |

### The Brutal Truth: Playstyle Audit

Out of **32 `*_sylvanas.lua` files**, only **27 are actual playstyles**. Of those 27:

- **Tier A — Substantial (~10):** Custom state builders, spec-specific logic, nuanced mechanics (Warrior Kebab, Priest Holy/Smite/Shadow, Paladin Retribution, Shaman Enhancement/Restoration, Druid Resto, Warrior Protection)
- **Tier B — Thin but Functional (~17):** Same boilerplate everywhere — an `ACTIONS` table with 3–8 spells, then a `for` loop wrapping `NS.action_matches` / `NS.action_execute`. No custom state builder. No spec-specific nuance.
- **Not Playstyles (5):** `druid/healing.lua` (shared helper), `paladin/healing.lua` (shared helper), `shaman/healing.lua` (shared helper), `hunter/cliptracker.lua` (utility), `hunter/debugui.lua` (utility)
- **Duplicate:** `druid/caster_sylvanas.lua` is a 31-line wrapper that `dofile`s `balance_sylvanas.lua`

**The "29+ playstyles" claim is technically true by file count but materially misleading.** The truth is closer to **"9 classes supported, ~10 deep rotations, ~17 functional but thin spell lists."**

### What's Oversold in Marketing

| Claim | Reality | Severity |
|-------|---------|----------|
| "29+ Playstyles" | 27 real, ~17 thin, 1 duplicate | Medium |
| "Damage meter with post-combat statistics" | Timer-based guesswork, not real damage tracking | High |
| "Class-based threat taxonomy" | Real `CLASS_THREAT` table exists, but it's a hardcoded 0–10 gut-feel additive bonus. `sustained` dimension is never used. | Low |
| "Smart downranking" | Healers have rank awareness, but no predictive mana-efficiency modeling | Medium |
| "DecisionCache memoization" | Built in `optimizer.lua` but **not consumed by any class or strategy** | Medium |
| "Group Finder integration" | No evidence in codebase | High |

---

## Part 2: Competitive Landscape — What #1 Looks Like

### Flux AIO (Our Closest Peer)

**What they do better than us:**
- **Schema-driven settings:** `SETTINGS_SCHEMA` is a declarative data structure consumed by both the UI and the engine. Settings changes are batched, diffed, and logged.
- **Strategy factory pattern:** `create_combat_strategy()` generates strategies with prerequisite checking (`requires_combat`, `requires_enemy`, `requires_in_range`, `setting_key`, `spell:IsReady`). This enforces consistency.
- **Spell validation system:** Every spell is checked for existence at playstyle switch time. Missing spells are logged with severity (required vs optional). No silent failures.
- **Predictive healing:** `predict_effective_deficit()` uses incoming heals, HoT HPS, absorbs, and incoming damage over a cast-time window. Real heal prediction.
- **Debug infrastructure:** Full debug log frame with copy-to-clipboard, 500-line rolling buffer, deduplicated printing (`debug_print_cache`), resizeable window.
- **Middleware registration:** Trinkets, defensives, and recovery are registered as prioritized middleware, not hardcoded into class files.
- **Burst context system:** `should_auto_burst()` checks pull, execute, bloodlust, and in-combat conditions with a single unified gate.
- **Swing timer integration:** Native `is_swing_landing_soon()` and `get_time_until_swing()` utilities.

**What we do better than them:**
- Our dashboard is more visually polished (energy tick sweep dot, combo point pips, threat bar).
- Our PvP infrastructure is deeper (DR tracker with 80 spells, arena priority with class taxonomy, enemy CD tracker).
- Our gear set tracking is more comprehensive.
- Our OOC buff urgency system is more sophisticated.

### Sonah (The Established Competitor)

**What they do better:**
- **Polished end-user experience:** Minimap button, action bar glow, theme system, locale support (deDE, esES, frFR, jaJP, zhCN).
- **Talent inference:** `TalentHelper.lua` + class-specific talent files automatically detect build and adapt rotation.
- **PvP system:** Dedicated `PvPSystem.lua` with arena logic.
- **Stats tracking:** Real `BuffTracker.lua` and `Stats.lua` for combat metric aggregation.
- **Macro generation:** `Macros.lua` generates optimal macros for the current build.

**What we do better:**
- Our rotation engine is more modular (shared modules, middleware, strategy factory).
- Our dashboard has more visual information density.
- Our PvP intelligence layer is deeper (DR tracking, enemy CDs, burst scoring).

### Industry Best Practices (Hekili, MaxDps, Ovale, WeakAuras)

**What makes these #1:**

| Feature | Why It Matters | Our Status |
|---------|---------------|------------|
| **SimC APL Import** | The gold standard for rotation accuracy. If your rotation matches SimC's APL, theorycrafters trust it. | **Missing** |
| **Real-Time DPS Simulation** | Shows expected DPS of the current rotation in real-time. Lets users A/B test talent/glyph changes. | **Missing** |
| **Action Priority List (APL) Visualizer** | Shows the user WHY a spell was recommended (which APL line matched). Builds trust. | **Missing** |
| **Extensive Class Coverage** | Every spec, every talent build, every viable playstyle. No "thin" implementations. | **Partial** |
| **Combat Log Parsing** | Real damage/healing done, not timer estimates. Actual performance metrics. | **Missing** |
| **Profile Sharing / Community** | Users export/import builds. Community-validated profiles for niche talent setups. | **Missing** |
| **Extensive Documentation** | Wiki, class guides, changelog, known issues, FAQ. Reduces support burden. | **Weak** |

---

## Part 3: The Gap — What Separates #1 from #3

There are **four pillars** that define a #1 rotation system. We have **one** (framework infrastructure). We need to build the other three.

### Pillar 1: Framework Infrastructure ✅ (We Have This)
- Shared modules, spell resolver, middleware, dashboard, PvP systems, OOC manager.
- **Status:** Done. Maintain and extend.

### Pillar 2: Theorycraft Integration ❌ (Missing)
- SimC APL parser, real-time simulation, APL visualizer.
- **Why it matters:** Without this, you are asking users to trust your gut. With it, you are asking them to trust math. Math wins.
- **Status:** Not started.

### Pillar 3: Consistent Spec Depth ❌ (Inconsistent)
- Every spec needs Tier A quality: custom state builders, talent-aware logic, encounter-specific adaptations.
- **Why it matters:** A user trying Mage Frost and getting a boilerplate list will assume ALL specs are that thin. One bad spec poisons the brand.
- **Status:** ~10/27 are good. Need 27/27.

### Pillar 4: Observability & Trust ❌ (Missing)
- Real damage meter, combat replay, APL line explanation, debug console.
- **Why it matters:** Users need to see WHY a spell was recommended. Without transparency, they blame the addon when they die.
- **Status:** Dashboard shows WHAT to cast. Nothing shows WHY.

---

## Part 4: Concrete Roadmap to #1

### Phase 0: Stop the Bleeding (Week 1)

**Goal:** Remove all self-inflicted credibility damage.

| Task | Files | Action |
|------|-------|--------|
| Kill the fake damage meter | `damage_meter_sylvanas.lua` | Replace timer-based guesswork with real combat log parsing, OR remove the feature from marketing and dashboard until it's real. |
| Remove duplicate playstyle | `druid/caster_sylvanas.lua` | Delete or merge into `balance_sylvanas.lua`. Update `class_sylvanas.lua` playstyle list. |
| Rename shared helpers | `druid/healing.lua`, `paladin/healing.lua`, `shaman/healing.lua` | Rename to `*_heal_shared.lua` or move to `shared/` so they don't look like playstyles. |
| Fix `DecisionCache` | `optimizer.lua` | Either wire `memoize()` into the hot path of `core_sylvanas.lua`, or delete it. Dead code is worse than no code. |
| Update marketing claims | `DISCORD_FEATURE_POST.md`, `README.md` | Remove "group finder integration" if it doesn't exist. Change "29+ playstyles" to "27 playstyles, 10 fully theorycrafted." Honesty builds trust. |

### Phase 1: Deepen the Thin Specs (Weeks 2–6)

**Goal:** Bring all 17 Tier B specs up to Tier A quality.

**The Boilerplate Problem:**
Most thin specs look like this:
```lua
local ACTIONS = {
    { spell = SPELL_A, condition = function() return true end },
    { spell = SPELL_B, condition = function() return true end },
}
for _, action in ipairs(ACTIONS) do
    if action.condition() then return action.spell end
end
```

**What Tier A looks like (Priest Shadow example):**
```lua
-- Custom state builder
local state = {
    vt_remains = get_debuff_remains(TARGET, SPELLS.VAMPIRIC_TOUCH),
    swp_remains = get_debuff_remains(TARGET, SPELLS.SHADOW_WORD_PAIN),
    mf_ticks = get_mind_flay_ticks_remaining(),
    inner_focus_ready = is_spell_ready(SPELLS.INNER_FOCUS),
}
-- Spec-specific logic: clip Mind Flay at tick boundaries
if state.mf_ticks > 0 and state.mf_ticks < 0.5 then
    return SPELLS.MIND_FLAY  -- Re-cast to clip last tick
end
-- Refresh windows: VT at < 3s, SWP at < 3s (account for travel time)
if state.vt_remains < 3.0 then return SPELLS.VAMPIRIC_TOUCH end
if state.swp_remains < 3.0 then return SPELLS.SHADOW_WORD_PAIN end
-- Burst combo: Inner Focus + Mind Blast
if state.inner_focus_ready and is_spell_ready(SPELLS.MIND_BLAST) then
    queue_spell(SPELLS.INNER_FOCUS, "player")
    return SPELLS.MIND_BLAST
end
```

**Target Specs to Deepen (in priority order):**
1. **Mage Fire** — Scorch maintenance is already there. Add Combustion stacking logic, living bomb tick clipping, hot streak proc handling.
2. **Mage Frost** — Add Waterbolt pet management, shatter combo timing, brain freeze proc handling.
3. **Warlock Affliction** — Add shard management, UA/Immolate/Corruption refresh windows, nightfall proc handling.
4. **Warlock Destruction** — Add conflagrate timing (immolate remains), backdraft haste math, chaos bolt shard math.
5. **Hunter BM/MM/Survival** — Add steady shot weaving, pet focus dump logic, kill command conditions, viper sting mana management.
6. **Rogue Assassination/Combat/Subtlety** — Add poison uptime, energy capping prevention, slice and dice refresh windows, rupture cycle math.
7. **Paladin Prot/Ret** — Add seal twisting math, consecration tick alignment, crusader strike / divine storm priority.
8. **Shaman Ele** — Add lightning bolt / chain lightning Maelstrom stack math, totem management, flame shock refresh.
9. **Druid Balance/Feral** — Add eclipse energy management, starfire vs wrath math, powershift energy capping.

**For each spec, the deliverable is:**
- Custom `build_state()` function with all relevant combat variables
- At least 3 spec-specific mechanics (procs, refresh windows, resource math)
- Comments citing the theorycraft source (e.g., "Refresh VT at <3s per Shadow Priest TBC discord")

### Phase 2: Build the Theorycraft Bridge (Weeks 7–12)

**Goal:** Make EaxRotations the only rotation addon that can prove its recommendations are correct.

#### 2A: SimC APL Parser

Build a Lua module that can read SimC APL syntax and convert it to Eax strategy tables:

```lua
-- SimC APL line:
-- actions+=/vampiric_touch,if=remains<3|!ticking
-- Becomes:
{
    name = "vampiric_touch",
    spell = SPELLS.VAMPIRIC_TOUCH,
    matches = function(context)
        local remains = get_debuff_remains(context.target, SPELLS.VAMPIRIC_TOUCH)
        return remains < 3 or remains == 0
    end,
}
```

**Deliverables:**
- `apl_parser.lua` — parses SimC `*.simc` files into Eax strategy tables
- `apl_validator.lua` — compares Eax rotation output against SimC output for the same input state
- CI job that runs on every commit: "Does our rotation match SimC for 100 sample combat states?"

#### 2B: Real-Time DPS Simulation

Add a lightweight DPS simulator to the dashboard:
- Given current stats, buffs, and target debuffs, simulate the next 60 seconds of the recommended rotation
- Display "Expected DPS: 2,847" below the suggested spell
- When the user toggles a talent or swaps a trinket, re-sim and show delta

**This is what makes users stick.** When they see "+127 DPS" from a gear change, they never uninstall.

#### 2C: APL Line Explanation

When suggesting a spell, show WHICH APL line matched:
```
[Mind Flay]
APL Line 7: "actions+=/mind_flay,interrupt=1,if=ticks_remain<1"
Reason: Mind Flay has 0.3s remaining (clipping last tick)
```

**Deliverable:** Hover tooltip on suggested spell showing the matching APL condition.

### Phase 3: Observability & Trust (Weeks 13–16)

**Goal:** Every recommendation is explainable. Every combat is replayable.

#### 3A: Real Combat Log Parser

Replace `damage_meter_sylvanas.lua` with real CLEU parsing:
- Track actual player damage/healing done per ability
- Track actual over-time DPS (not timer estimates)
- Post-combat summary: "You did 2,847 DPS. Your top 3 abilities were X, Y, Z."
- Compare actual DPS vs. simulated DPS: "Sim predicted 2,900 DPS. You achieved 98% efficiency."

#### 3B: Combat Replay

Store the last 60 seconds of combat state (snapshotted every 0.5s):
- Health, mana, buffs, debuffs, spell CDs, position
- Render as a timeline: "At 14.3s, you cast Mind Flay. At 14.8s, you clipped it early. Expected DPS loss: 120."
- This is the ultimate debugging and teaching tool.

#### 3C: Debug Console (Borrow from Flux)

Add a full debug log frame:
- Rolling 500-line buffer
- Copy-to-clipboard
- Settings diff logging ("trinket1_mode changed from 'offensive' to 'defensive'")
- Per-frame context dumps (optional, toggleable)

### Phase 4: Ecosystem & Community (Weeks 17–20)

**Goal:** Network effects. Users stay because the community keeps making it better.

| Feature | Description |
|---------|-------------|
| **Profile Sharing** | Export current settings + rotation to a shareable string (like WeakAuras). Import from string. |
| **Community Profiles** | Curated profile repository: "Fire Mage P4 BiS", "Affliction Warlock HT10", etc. |
| **Web Dashboard** | Companion website showing combat history, DPS rankings per encounter, gear upgrade suggestions. |
| **Changelog & Docs** | Auto-generated changelog from git commits. Per-class wiki pages with theorycraft sources. |
| **Telemetry (Opt-In)** | Anonymous combat metrics to identify which specs underperform in real raids. |

---

## Part 5: Architectural Improvements

### Adopt Flux's Strategy Factory

Current Eax class files use ad-hoc condition functions. Flux's `create_combat_strategy()` enforces consistency:

```lua
-- Eax current (ad-hoc)
if spell_a:is_ready() and condition then
    return spell_a
end

-- Flux pattern (structured)
rotation_registry:register("combat", {
    create_combat_strategy({
        spell = SPELL_A,
        prefix = "[C]",
        log_name = "Spell A",
        extra_match = function(context)
            return context.some_condition
        end,
    }),
})
```

**Benefit:** Every strategy gets prerequisite checking (`requires_combat`, `requires_enemy`, `setting_key`) for free. No more unguarded menu access scattered across files.

### Adopt Flux's Spell Validation

Current Eax: spells are resolved at runtime with `is_spell_learned()`. If a spell is missing, it's silently skipped.

Flux: at playstyle switch time, ALL spells are validated. Missing required spells are printed in red. Missing optional spells are printed in orange.

**Benefit:** Users immediately know if their talent build is missing a spell the rotation expects. Reduces support tickets by 80%.

### Adopt Sonah's Talent Inference

Sonah's `TalentHelper.lua` automatically detects the player's talent build and selects the appropriate rotation. Eax currently requires manual playstyle selection.

**Benefit:** Zero-config onboarding. Install → works immediately.

### Adopt Sonah's Action Bar Glow

Sonah highlights the actual action bar button for the recommended spell. This is more intuitive than a separate overlay.

**Benefit:** Lower cognitive load. Users don't need to learn a new UI.

---

## Part 6: Immediate Action Items (This Week)

1. **Delete or fix `druid/caster_sylvanas.lua`** — it's a duplicate wrapper. Update `druid/class_sylvanas.lua`.
2. **Rename healing helpers** — `druid/healing_sylvanas.lua` → `shared/druid_heal_shared.lua`. Same for paladin/shaman.
3. **Remove fake damage meter from dashboard** — comment out the damage meter render until it's real. Don't show fake data.
4. **Wire `memoize()` or delete it** — either use the DecisionCache in `core_sylvanas.lua` or remove the dead code.
5. **Audit `DISCORD_FEATURE_POST.md`** — remove claims that aren't implemented (group finder). Add caveats where appropriate ("10 fully theorycrafted, 17 functional").
6. **Pick 3 thin specs to deepen this week** — e.g., Mage Frost, Warlock Affliction, Hunter BM. Give them custom state builders and 3 spec-specific mechanics each.
7. **Add spell validation at load time** — when a playstyle is selected, print which spells are missing. Copy Flux's `check_spell_availability()` pattern.
8. **Add a `build_state()` requirement** — every new or refactored playstyle MUST have a custom state builder. Enforce this in code review.

---

## Part 7: Marketing & Positioning

### What to Say (Honest & Compelling)

**Current (oversold):**
> "29+ playstyles with smart rotation engine, predictive healing, class-based threat taxonomy, and real-time DPS tracking."

**Better (honest and differentiated):**
> "The most visually advanced rotation framework for TBC Classic. 10 deeply theorycrafted specs with SimC-aligned priorities, 17 functional specs with priority-based casting, and the only addon with integrated PvP intelligence (DR tracking, arena scoring, enemy cooldowns)."

**Even better (with Phase 2 complete):**
> "The only TBC rotation addon with SimC APL validation. Every recommendation is provably optimal."

### Competitive Positioning Matrix

| Dimension | EaxRotations | Flux AIO | Sonah | MaxDps |
|-----------|-------------|----------|-------|--------|
| Visual Dashboard | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| PvP Intelligence | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| Spec Depth (best) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| Spec Depth (worst) | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| Theorycraft Bridge | ⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| Real-Time Sim | ⭐ | ⭐ | ⭐ | ⭐⭐⭐⭐ |
| Debug/Observability | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| Talent Auto-Detect | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Action Bar Glow | ⭐ | ⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Locale Support | ⭐ | ⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

**Our differentiation:** "Best visual HUD + deepest PvP layer. Building the theorycraft bridge now."

---

## Appendix A: Per-Spec Depth Checklist

For a spec to be considered "Tier A", it must satisfy ALL of these:

- [ ] Custom `build_state()` with all relevant combat variables (HP, mana, buffs, debuffs, CDs, procs)
- [ ] At least 3 spec-specific mechanics (proc handling, refresh windows, resource math, stance logic, pet management)
- [ ] Talent-aware logic (different behavior based on known talents)
- [ ] Encounter awareness (TTD checks, execute phase, bloodlust phase)
- [ ] Menu guards on ALL settings access (`(menu.x and menu.x:get()) or default`)
- [ ] Comments citing theorycraft source (discord, simc, icy-veins era guide)
- [ ] `luac -p` passes with zero errors
- [ ] Spell validation at load time (prints missing spells)

**Current Tier A specs (pass all 8):** Warrior Protection, Warrior Kebab, Priest Shadow, Priest Holy, Priest Smite, Shaman Restoration, Druid Resto, Paladin Holy

**Specs needing work (fail 2+ checks):** All others.

---

## Appendix B: File Cleanup Checklist

| File | Action | Owner |
|------|--------|-------|
| `EaxRotations/classes/druid/caster_sylvanas.lua` | Delete (duplicate of balance) | This week |
| `EaxRotations/classes/druid/healing_sylvanas.lua` | Move to `shared/druid_heal_shared.lua` | This week |
| `EaxRotations/classes/paladin/healing_sylvanas.lua` | Move to `shared/paladin_heal_shared.lua` | This week |
| `EaxRotations/classes/shaman/healing_sylvanas.lua` | Move to `shared/shaman_heal_shared.lua` | This week |
| `EaxRotations/damage_meter_sylvanas.lua` | Rewrite with CLEU or remove from dashboard | Phase 0 |
| `EaxRotations/optimizer.lua` | Wire `memoize()` or delete | This week |
| `DISCORD_FEATURE_POST.md` | Audit and honest-ify claims | This week |

---

*Document version: 1.0*  
*Last updated: 2026-04-09*  
*Next review: After Phase 0 completion*
