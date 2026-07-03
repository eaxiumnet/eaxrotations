## EAX Rotations v1.0.8 — Hotfix Release

### Bug Fixes

- **Druid — Caster (TBC + Classic)**: Fixed crash when checking Faerie Fire or Moonfire debuff timers before state was fully built.
- **Druid — Bear (Classic)**: Fixed crash when checking Faerie Fire or Demoralizing Roar debuff timers before state was fully built.
- **Warrior — All Specs**: Verified Pummel interrupt is present in all 4 TBC specs (Arms, Fury, Protection, Kebab). No further gaps.

### Warrior Feature Status (vs Top-Parse Reference)

| Feature | Arms | Fury | Protection | Kebab |
|---------|------|------|------------|-------|
| Pummel | ✅ | ✅ | ✅ | ✅ |
| HS Trick (dual-wield) | N/A (2H) | ✅ | N/A (shield) | N/A (2H) |
| Victory Rush | ✅ | ✅ | ✅ | ✅ |
| Slam | ✅ | ✅ | N/A | ✅ |

### What to Expect

- Druid casters: smoother rotation startup, no more rare crashes on state init.
- Warriors: all interrupt functionality confirmed working across all specs.

---
*Verified: 219 rotation tests + 13 leveling tests pass.*
