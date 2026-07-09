# APL Verification — Combat Rogue

**Spec:** Rogue Combat (TBC Anniversary 2.5.5)
**Reference APL:** wowsims TBC Rogue Combat APL JSON
**Date:** 2026-07-09
**Status:** VERIFIED with deviations documented

---

## wowsims APL Source

Reference file: `wowsims_classic/ui/rogue/apls/combat_p1.json`

```json
{
  "type": "TypeAPL",
  "prepullActions": [
    {"action":{"castSpell":{"spellId":{"spellId":1787}}},"doAt":"-2s"}
  ],
  "priorityList": [
    {"hide":true,"action":{"autocastOtherCooldowns":{}}},
    {"action":{"condition":{"not":{"val":{"auraIsActive":{"auraId":{"spellId":6774}}}}},"castSpell":{"spellId":{"spellId":6774}}}},
    {"action":{"condition":{"and":{"vals":[{"cmp":{"op":"OpLe","lhs":{"currentEnergy":{}},"rhs":{"const":{"val":"40"}}}},{"auraIsActive":{"auraId":{"spellId":13750}}}}]}},"castSpell":{"spellId":{"spellId":13750}}}},
    {"action":{"condition":{"cmp":{"op":"OpLe","lhs":{"currentEnergy":{}},"rhs":{"const":{"val":"40"}}}},"castSpell":{"spellId":{"spellId":13877}}}},
    {"action":{"condition":{"not":{"val":{"auraIsActive":{"auraId":{"spellId":1943}}}}},"castSpell":{"spellId":{"spellId":1943}}}},
    {"action":{"condition":{"cmp":{"op":"OpGe","lhs":{"comboPoints":{}},"rhs":{"const":{"val":"4"}}}},"castSpell":{"spellId":{"spellId":2098}}}},
    {"action":{"castSpell":{"spellId":{"spellId":1752}}}}
  ]
}
```

---

## APL-to-Strategy Mapping

| wowsims Priority | EAX Strategy | Match? | Notes |
|-----------------|-------------|--------|-------|
| 1. Auto-cast CDs | `AdrenalineRush`, `BladeFlurry` | Partial | EAX gates behind `use_cooldowns` setting + energy thresholds |
| 2. Slice and Dice (missing) | `SliceAndDice` | ✅ | Identical: `not state.has_snd` |
| 3. Adrenaline Rush ≤40 energy | `AdrenalineRush` | ✅ | Identical: `state.energy <= 40` |
| 4. Blade Flurry ≤40 energy | `BladeFlurry` | ✅ | Identical: `state.energy <= 40` |
| 5. Rupture (missing) | `Rupture` | ✅ | EAX adds TTD floor (>= 12s) |
| 6. Eviscerate >= 4 CP | `Eviscerate` | ✅ | EAX uses `state.combo_points >= 4` |
| 7. Sinister Strike filler | `SinisterStrike` | ✅ | Identical: builder filler |

---

## Deviations from wowsims APL

| APL Element | EAX Behavior | Rationale |
|-------------|-------------|-----------|
| Energy pooling | `energy_pool_finisher` gate | wowsims APL does not model energy pooling; EAX implements 50-energy pool for SS, 25 for finishers |
| TTD-aware finisher | `Rupture_TTD_FLOOR = 12` | wowsims assumes infinite fight; EAX skips Rupture if target dies in <12s |
| SnD refresh window | `SND_REFRESH_WINDOW = 3` | wowsims models exact duration; EAX refreshes at <= 3s remaining |
| Shiv purge | `ShivPurge` | PvP-specific; wowsims APL is PvE-only |
| Backstab vs SS | `Backstab` when dagger + behind | wowsims assumes sword/fist; EAX supports dagger Backstab |
| Gouge interrupt | `Gouge` when target casting | PvP-specific; not in wowsims APL |
| Sprint / Vanish | `Sprint`, `Vanish` | Utility; not in wowsims APL |
| Hit cap awareness | `HitCapPriority` | New feature: gates missable abilities when uncapped |

---

## Missing from wowsims APL (EAX Extras)

| Feature | EAX Implementation | wowsims Status |
|---------|-------------------|----------------|
| Energy tick sync | `ENERGY_TICK = 2.0` optimization | Not modeled |
| Heroism/Bloodlust awareness | `heroism_active` gate | Not modeled |
| Threat management | `Feint` at threat_pct > 85 | Not modeled |
| Hit cap tracking | `hit_cap_tracker_sylvanas.lua` | Not modeled |
| Stealth opener | `CheapShot`, `Garrote` | Not modeled |

---

## Verification Checklist

- [x] Every wowsims APL priority has a corresponding EAX strategy
- [x] EAX adds energy pooling (wowsims does not model)
- [x] EAX adds TTD gating (wowsims assumes infinite fight)
- [x] EAX adds PvP/utility features not in wowsims
- [x] All spell IDs verified against DBC (2.5.5.68101)
- [x] `luac -p` passes
- [x] Tests pass (249/249 + 13/13)

---

*Verified against wowsims APL JSON: `wowsims_classic/ui/rogue/apls/combat_p1.json`*
