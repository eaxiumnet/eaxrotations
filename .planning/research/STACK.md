# STACK - Technology Stack

## Current Stack

- **Language**: Lua 5.x (pure Lua, no external dependencies)
- **Runtime**: Project Sylvanas bot embedded Lua environment
- **Target**: TBC Classic WoW patch 2.4.3
- **APIs**: Sylvanas core APIs (`core.*` namespace)
- **No build step**: Direct Lua file deployment

## Shared Module Dependencies

```
common/utility/key_helper
common/utility/auto_attack_helper
common/utility/spell_queue
common/utility/inventory_helper
common/utility/control_panel_helper
common/modules/buff_manager
common/modules/spell_queue
common/geometry/vector_2
common/color
```

## Competitive Stack Analysis

### Tempest (Top Competitor)
- SimC-accurate rotations natively
- Custom APL editor for user modification
- Pixel-based detection (zero bans)
- Supports TBC, WotLK, MoP
- Zero-setup, auto-detects keybinds & spells

**EAX advantage**: Fully custom Lua, no external dependencies, complete control over every rotation detail.

### Project Wholesome (WRobot)
- 13 solo + 18 party rotations
- Party-aware (tank/healer/DPS detection)
- Dungeon-complete capable with 5 bots
- .dll-based FightClass system

**EAX advantage**: Sylvanas-specific API access, ESP/HUD overlay, encounter awareness.

### HeroRotation/HeroLib (Worldy Rotation)
- Based on simc profiles
- No Lua unlocker required
- Pixel-based key simulation
- Broader class coverage (Retail + Classic)

**EAX advantage**: Deeper TBC-specific rotation logic, private server optimization.

## What EAX Must Include to Match Competitors

| Feature | Tempest | Wholesome | Worldy | EAX (needed) |
|---------|---------|-----------|--------|--------------|
| SimC-accurate rotations | ✓ | Partial | ✓ | Improve |
| Custom APL/priority editing | ✓ | ✗ | ✓ | Low priority |
| Swing timer awareness | ✓ | ? | ✓ | Improve |
| Haste breakpoint awareness | ✓ | ? | ✓ | Missing |
| Set bonus detection | Dynamic | ? | ? | Missing |
| DPS meter | Built-in | ? | ? | Missing |
| Zero bans | ✓ | ? | ✓ | ✓ |

## Recommended Stack Additions

1. **SimC APL parser** — convert simc action priority lists to Lua rotation tables
2. **Swing timer library** — robust melee swing timing for Warriors, Rogues, Hunters
3. **Set bonus scanner** — dynamic gear scanning for all T4/T5/T6 sets
4. **DPS/HPS meter** — integrated damage/healing tracking
5. **Shared module extraction** — centralize duplicate manager code

## What NOT to Use

- Memory-based API hooks (ban risk)
- External automation frameworks
- Non-Sylvanas bot platforms
