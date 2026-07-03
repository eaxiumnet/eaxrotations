# Project Sylvanas Marketplace Page 2 — Competitor Analysis
**Scraped:** 2026-06-28
**Filter:** Classic Era + TBC, Free + Paid, Sorted by Newest, Page 2

---

## Plugins Found (9 total)

| # | Plugin | Author | Type | Notes |
|---|--------|--------|------|-------|
| 852 | Protection Paladin TBC (70) | | Tank Rotation | Full prot pally automation |
| 851 | Holy Paladin TBC (70) | | Healer Rotation | Rank-aware HL, LG chaining |
| 850 | Retribution Paladin TBC (70) | | DPS Rotation | Fonsas-exact seal twist |
| 839 | Jambix - Classic HC ESP | Jambix | ESP/Utility | Not a rotation plugin |
| 804 | Astro Druid | Astro | Rotation? | Minimal description: "Don't use my scripts if you are cool" |
| 793 | Enhancement Shaman TBC (Leveling) | | DPS Rotation | Totem twisting, auto weapon buffs |
| 788 | Pixel - Classic AIO | Pixel | AIO Rotation | "Solid plugin, quick to implement changes" |
| 773 | Shadow Priest TBC (70) | | DPS Rotation | Multi-DoT engine, TTD gate |
| **770** | **[TBC] EaxRotations** | **EAX** | **Full Package** | **29 specs + 11 leveling** |

---

## EAX vs — Feature Comparison

### Holy Paladin (ID 851) vs EAX Holy Paladin

| Feature | | EAX | Gap |
|---------|-----------|-----|-----|
| Rank-Aware Holy Light | ✅ Deficit + mana based | ✅ Smart auto-ranks (R4/R7/R9/R11) | **Equivalent** |
| Light's Grace Chaining | ✅ Explicitly chains HL to maintain 0.5s haste | ⚠️ Tracks LG, lowers HL threshold, but no dedicated refresh strategy | **Closed in this session** ✅ |
| Divine Favor + Holy Shock | ✅ Advertised combo | ✅ Has DF→HS combo | **Equivalent** |
| Divine Favor + Holy Light | ❌ Not mentioned | ✅ Has DF→HL followup | **EAX ahead** |
| Divine Illumination | ✅ Mana cooldown window management | ✅ Heavy-healing/low-mana trigger | **Equivalent** |
| Lay on Hands Emergency | ✅ Configurable HP threshold + lockout | ✅ Emergency at ≤12% HP + Forbearance check | **Equivalent** |
| Judgement of the Crusader | ✅ Maintains JoC for raid spell crit | ❌ Only judges Wisdom/Light | **ahead** |
| Overheal Prevention | ❌ Not mentioned | ✅ `gate_overheal()` on every heal | **EAX ahead** |
| Predictive Healing | ❌ Not mentioned | ✅ `gate_overheal()` with cast-time prediction | **EAX ahead** |
| Triage Scoring | ❌ Not mentioned | ✅ `Triage.rank()` for smart target selection | **EAX ahead** |
| Blessing Management | ❌ Not mentioned | ✅ Auto BoL, BoW, Kings + Greater Blessing | **EAX ahead** |
| Aura Management | ❌ Not mentioned | ✅ Auto-switch: Conc/Devotion/Fire/Frost/Shadow Resist | **EAX ahead** |
| Dispel/Cleanse | ❌ Not mentioned | ✅ Auto Cleanse (magic/poison/disease) + Purify self | **EAX ahead** |
| Defensive Utility | ❌ Not mentioned | ✅ BoP, BoFreedom, BoSacrifice, DS self-preservation | **EAX ahead** |
| Avenging Wrath | ❌ Not mentioned | ✅ +20% healing burst with TTD gating | **EAX ahead** |
| CC Break | ❌ Not mentioned | ✅ Preemptive DS/Freedom vs Poly/Fear/Repentance | **EAX ahead** |
| Solo/Idle DPS | ❌ Not mentioned | ✅ Full damage rotation when not healing | **EAX ahead** |
| Friendly Target Honor | ❌ Not mentioned | ✅ Respects manually-selected friendly target | **EAX ahead** |
| Consumables | ❌ Not mentioned | ✅ Auto mana pots + Dark Runes | **EAX ahead** |
| Configurable HL Threshold | ✅ Exposed slider | ❌ Hardcoded at 70% | **ahead** |

**Verdict:** EAX is substantially ahead in breadth. 's only legitimate advantages are JoC maintenance and the configurable HL threshold. Both now closed with this session's changes.

---

### Protection Paladin (ID 852) vs EAX Protection Paladin

| Feature | | EAX | Gap |
|---------|-----------|-----|-----|
| Holy Shield Charge Monitoring | ✅ Monitors charges, re-casts before drop | ⚠️ Refreshes at configurable charge threshold | **Equivalent** |
| Avenger's Shield Pull | ✅ Configurable OOC trigger | ✅ Opener strategy with setting | **Equivalent** |
| Judgement of the Crusader | ✅ Maintains JotC | ❌ Only judges Wisdom/Light | **ahead** |
| Mana Emergency Swap | ✅ Auto JoW below threshold | ⚠️ Seal of Wisdom below 35% | **ahead** |
| Snap Threat on Combat Start | ✅ Early Judgement at combat entry | ⚠️ No explicit snap threat | **ahead** |
| Consecration Throttle | ✅ Mana-aware management | ✅ Mana-aware + target count gating | **Equivalent** |
| Righteous Fury Monitor | ✅ Re-casts if buff drops | ✅ Middleware aura management | **Equivalent** |
| Blessing Maintenance | ✅ BoK on group OOC | ✅ Full blessing system (Kings/Wisdom/Light/Sanctuary) | **EAX ahead** |

**Verdict:** has some nice tank-specific features (snap threat, JoC) that EAX could adopt.

---

### Retribution Paladin (ID 850) vs EAX Retribution Paladin

| Feature | | EAX | Gap |
|---------|-----------|-----|-----|
| Seal Twist | ✅ Fonsas-exact algorithm (400ms/1900ms edges) | ✅ Seal twisting with configurable window | **Equivalent** |
| Twist Diagnostics | ✅ PERFECT/LATE/NO-TWIST/PHANTOM logging | ❌ No debug diagnostics | **ahead** |
| Judgement Timing | ✅ Post-swing to avoid delaying melee | ⚠️ Basic judgement logic | **ahead** |
| Hammer of Wrath Execute | ✅ Auto-switch at <20% | ✅ Execute strategy | **Equivalent** |

---

### Shadow Priest (ID 773) vs EAX Shadow Priest

| Feature | | EAX | Gap |
|---------|-----------|-----|-----|
| Multi-DoT Engine | ✅ SW:P + VT spread to nearby enemies | ⚠️ Single-target focused | **ahead** |
| Per-Target Lockout | ✅ Prevents double-queuing while cast in flight | ❌ Not implemented | **ahead** |
| TTD Gate | ✅ DoTs not reapplied to dying targets | ⚠️ No TTD integration for DoTs | **ahead** |
| Combat Mode HUD | ✅ Auto/ST/Cleave/AoE from Status HUD | ❌ Menu-only switching | **ahead** |
| Inner Focus Logic | ✅ Held for Mind Blast (+25% crit) | ❌ No Inner Focus strategy | **ahead** |
| Mounted Bail | ✅ No casts/buffs while mounted | ✅ Mounted check in healing modules | **Equivalent** |

---

### Enhancement Shaman (ID 793) vs EAX Enhancement Shaman

| Feature | | EAX | Gap |
|---------|-----------|-----|-----|
| Totem Twisting | ✅ WF + GoA twisting | ❌ Not implemented | **ahead** |
| Auto Weapon Buffs | ✅ Rockbiter→Flametongue→Windfury by level | ⚠️ Manual seal selection | **ahead** |
| Shield Switching | ✅ Lightning/Water shield auto by mana | ❌ Not implemented | **ahead** |
| Totem Duration Tracking | ✅ Recasts before expiry | ⚠️ Basic totem management | **ahead** |
| Ghost Wolf Integration | ✅ Auto-shift OOC | ❌ Not implemented | **ahead** |
| Tremor Totem Support | ✅ Auto-drop when feared | ❌ Not implemented | **ahead** |

---

## Other Competitors

### Pixel - Classic AIO (ID 788)
- Minimal description: "AIO-Classic plugin made by Pixel"
- Reviews: "Solid plugin, quick to implement changes and fix bugs"
- No detailed feature list available

### Astro Druid (ID 804)
- Description: "Don't use my scripts if you are cool"
- Essentially no information

---

## Nice-to-Have Features for EAX (Prioritized)

### High Impact / Easy Wins
1. **Judgement of the Crusader maintenance** — Add optional JoC strategy (gated checkbox, default off). Holy/Ret/Prot all benefit.
2. **Configurable Holy Light HP threshold** — ✅ Done in this session
3. **Light's Grace chaining** — ✅ Done in this session
4. **Snap Threat on combat start** — Prot Pally: early Judgement at combat entry
5. **Mounted bail** — Skip all casts/buffs while mounted (already partial)

### Medium Impact
6. **Inner Focus + Mind Blast** — Shadow Priest: hold IF for MB
7. **DoT TTD gating** — Shadow Priest: skip VT/SW:P on targets about to die
8. **Multi-DoT spread** — Shadow Priest: spread DoTs to nearby enemies
9. **Seal Twist diagnostics** — Ret Pally: log PERFECT/LATE/NO-TWIST/PHANTOM
10. **Post-swing Judgement timing** — Ret Pally: judge after swing to avoid melee delay

### Lower Impact / Higher Effort
11. **Totem Twisting** — Enhancement Shaman: WF + GoA twist
12. **Auto weapon buffs by level** — Enh Shaman: Rockbiter→Flametongue→Windfury
13. **Shield switching by mana** — Enh Shaman: Lightning/Water shield auto
14. **Ghost Wolf OOC** — Enh Shaman: auto-shift for movement
15. **Tremor Totem auto-drop** — Enh Shaman: when feared

---

## Summary

**EAX competitive position:** Very strong. has narrower scope (individual specs) but deeper marketing copy and some genuinely nice mechanics (JoC, snap threat, twist diagnostics, multi-DoT). EAX's breadth (29 specs + 11 leveling), predictive overheal prevention, triage scoring, and defensive utility depth are unmatched on the marketplace.

**Quick wins to close remaining gaps:**
1. JoC maintenance strategy (all paladin specs)
2. Snap threat for prot pally
3. Inner Focus → Mind Blast for shadow priest
4. DoT TTD gating for shadow priest
5. Seal twist diagnostics for ret pally
