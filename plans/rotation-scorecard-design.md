# EAX Rotation Scorecard — Design Doc

**Created:** 2026-06-26
**Purpose:** Track rotation quality per spec × content type, auto-computed from codebase
**Inspiration:** BadRotations profile status system (Full/Limited/Sporadic + emoji ratings)

## Score Dimensions (0–5 scale)

### Core APL Quality
- **5**: Pattern 15 header, ≥12 strategies, all match fn nil-guarded, guide-verified APL
- **4**: Pattern 15 header, ≥8 strategies, most nil-guarded
- **3**: Header present, ≥5 strategies, some nil-guards
- **2**: Basic strategies, minimal nil-guards
- **1**: Placeholder / broken structure
- **0**: Missing file

### Test Coverage
- **5**: ≥3 test files covering custom matches, feature gaps, content-specific behavior
- **4**: 2 test files (matches + gaps)
- **3**: 1 test file
- **2**: Only generic/loader tests
- **1**: No tests, but file loads
- **0**: Missing or broken

### Feature Completeness
- **5**: Defensives + Interrupts + Cooldowns + Consumables + Trinkets + Utility all present
- **4**: 4 of 5 categories
- **3**: 3 of 5 categories
- **2**: 2 of 5 categories
- **1**: Basic rotation only
- **0**: No rotation logic

### Content Type Appropriateness (per type)
- **5**: Content-aware gating (e.g., `context.is_group` for dungeon, `context.is_raid` for raid)
- **4**: Content-appropriate spell selection (AoE for dungeon, ST for raid)
- **3**: Works in content type but not optimized
- **2**: Barely functional
- **1**: Should not be used
- **0**: Missing / non-functional

### Spell Validity
- **5**: All spell IDs verified in DBC, no contamination
- **4**: 1 minor unverified ID (commented/documented)
- **3**: Some IDs unverified but likely correct
- **2**: Known unverified IDs
- **1**: Spell contamination risk
- **0**: Failed spell audit

## Content Types Tracked

| Type | Key Gating | What Makes It Good |
|------|-----------|-------------------|
| **Solo / Open World** | `context.is_solo` or `not context.is_group` | Self-sufficiency, defensives, sustain |
| **Dungeon (5-man)** | `context.is_group` | AoE awareness, interrupt priority, CC |
| **Raid (10/25/40)** | `context.is_raid` | ST focus, buff maintenance, CD timing |
| **Arena (PvP)** | `context.is_pvp` | Burst windows, DR tracking, CC chains |
| **Battleground (PvP)** | `context.is_pvp` + enemy_count | Multi-target, survival, objective awareness |
| **Leveling** | `context.is_leveling` | Mana conservation, self-heal, emergency tools |

## Output Format

### JSON (`EaxRotations/scorecard_data.json`)
Machine-readable scores for CI/integration.

### Markdown (`SCORECARD.md`)
Human-readable report with emoji ratings and color-coded cells.

### Per-Spec Badge
```
Warrior Fury (TBC)
  Solo:    ⭐⭐⭐⭐⭐ (5/5)
  Dungeon: ⭐⭐⭐⭐☆ (4/5)
  Raid:    ⭐⭐⭐⭐⭐ (5/5)
  Arena:   ⭐⭐⭐☆☆ (3/5)
  BG:      ⭐⭐⭐☆☆ (3/5)
  Leveling:⭐⭐⭐⭐☆ (4/5)
```

## Auto-Computation

A Lua script (`tools/compute_scorecard.lua`) computes scores by:
1. Reading each spec file
2. Counting strategies, tests, features
3. Checking for content-type gating patterns
4. Cross-referencing spell audit results
5. Outputting JSON + Markdown

## Maintenance

After every spec change, run `tools/compute_scorecard.lua` to regenerate.
The scorecard is committed alongside the code it describes.
