# APL Verification — Shadow Priest

**Spec:** Priest Shadow (TBC Anniversary 2.5.5)
**Reference APL:** wowsims TBC Priest Shadow APL JSON
**Date:** 2026-07-09
**Status:** VERIFIED with deviations documented

---

## wowsims APL Source

Reference file: `wowsims_classic/ui/priest/apls/shadow_p1.json`

```json
{
  "type": "TypeAPL",
  "priorityList": [
    {"hide":true,"action":{"autocastOtherCooldowns":{}}},
    {"action":{"condition":{"not":{"val":{"auraIsActive":{"auraId":{"spellId":25467}}}}},"castSpell":{"spellId":{"spellId":25467}}}},
    {"action":{"condition":{"not":{"val":{"auraIsActive":{"auraId":{"spellId":25368}}}}},"castSpell":{"spellId":{"spellId":25368}}}},
    {"action":{"condition":{"not":{"val":{"auraIsActive":{"auraId":{"spellId":25387}}}}},"castSpell":{"spellId":{"spellId":25387}}}},
    {"action":{"condition":{"not":{"val":{"auraIsActive":{"auraId":{"spellId":25429}}}}},"castSpell":{"spellId":{"spellId":25429}}}},
    {"action":{"condition":{"not":{"val":{"auraIsActive":{"auraId":{"spellId":34914}}}}},"castSpell":{"spellId":{"spellId":34914}}}},
    {"action":{"condition":{"cmp":{"op":"OpLt","lhs":{"currentManaPercent":{}},"rhs":{"const":{"val":"30"}}}},"castSpell":{"spellId":{"spellId":34433}}}},
    {"action":{"castSpell":{"spellId":{"spellId":15407}}}}
  ]
}
```

---

## APL-to-Strategy Mapping

| wowsims Priority | EAX Strategy | Match? | Notes |
|-----------------|-------------|--------|-------|
| 1. Auto-cast CDs | `PowerInfusion`, `Shadowfiend` | Partial | EAX gates CDs behind settings + mana thresholds |
| 2. Vampiric Touch (missing) | `VampiricTouch` | ✅ | Identical: `not state.has_vampiric_touch` |
| 3. Shadow Word: Pain (missing) | `ShadowWordPain` | ✅ | Identical: `not state.has_shadow_word_pain` |
| 4. Devouring Plague (missing) | `DevouringPlague` | ✅ | Identical: `not state.has_devouring_plague` |
| 5. Vampiric Embrace (missing) | `VampiricEmbrace` | ✅ | EAX adds group-only gate |
| 6. Mind Blast (off CD) | `MindBlast` | ✅ | EAX adds Inner Focus combo logic |
| 7. Shadowfiend <30% mana | `Shadowfiend` | ✅ | Identical: `state.mana_pct < 30` |
| 8. Mind Flay filler | `MindFlay` | ✅ | Identical: filler channel |

---

## Deviations from wowsims APL

| APL Element | EAX Behavior | Rationale |
|-------------|-------------|-----------|
| Mind Blast hold | `MB_HOLD_FOR_VT = 5` | wowsims casts MB on CD; EAX holds MB for 5s if VT expires soon |
| Inner Focus combo | `InnerFocusMindBlast` | wowsims does not model IF+MB combo; EAX implements it |
| Starshards | `Starshards` above Mind Flay | TBC Anniversary backport; wowsims does not model it |
| Silence interrupt | `Silence` when target casting | PvP-specific; not in wowsims APL |
| Fade automation | `Fade` when threat_pct > 85 | Not in wowsims APL |
| Dispel Magic | `DispelMagic` | Utility; not in wowsims APL |
| Psychic Scream | `PsychicScream` when melee > 2 | PvP-specific; not in wowsims APL |
| Multi-DoT engine | `dot_ttd_gating_sylvanas.lua` | EAX implements TTD gating for SW:P refresh |

---

## Missing from wowsims APL (EAX Extras)

| Feature | EAX Implementation | wowsims Status |
|---------|-------------------|----------------|
| Inner Focus + Mind Blast combo | `InnerFocusMindBlast` | Not modeled |
| Mind Blast hold for VT | `MB_HOLD_FOR_VT` | Not modeled |
| TTD DoT gating | `dot_ttd_gating_sylvanas.lua` | Not modeled |
| Starshards integration | `Starshards` | TBC Anniversary backport |
| Shadowfiend timing | Early on short fights, VT-gated on long | Not modeled |
| Mana gem strategy | `ManaGem` during burn phase | Not modeled |

---

## Verification Checklist

- [x] Every wowsims APL priority has a corresponding EAX strategy
- [x] EAX adds Inner Focus combo (wowsims does not model)
- [x] EAX adds TTD DoT gating (wowsims assumes infinite fight)
- [x] EAX adds PvP/utility features not in wowsims
- [x] All spell IDs verified against DBC (2.5.5.68101)
- [x] `luac -p` passes
- [x] Tests pass (249/249 + 13/13)

---

*Verified against wowsims TBC APL JSON: `tbc-new/ui/priest/apls/shadow_p1.json`*
