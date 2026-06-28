# Active Plan

**Current:** `plans/ultra-plan-frostbyte-supremacy.md` — 8-week roadmap to dominate FrostByte
**Previous:** `plans/omnibus-master-audit-2026-06-26.md` ✅ COMPLETE

---

## 🏆 FrostByte Supremacy Ultra-Plan
**Started:** 2026-06-28  
**Goal:** Out-feature, out-quality, and out-market FrostByte across all 32 identified gaps  
**Competitor Intel:** 21 plugins (17 TBC rotation + 3 MoP + 1 utility)

### EAX Advantages (Maintain & Amplify)
- ✅ 29 specs vs FrostByte's ~17
- ✅ 11 leveling suites vs ~6
- ✅ `gate_overheal` — predictive overheal prevention (NO competitor has this)
- ✅ Triage scoring — smart target selection
- ✅ 171 test suites — automated quality
- ✅ Cross-spec shared modules — blessings, auras, dispels, interrupts
- ✅ CC Break — preemptive DS/Freedom
- ✅ Light's Grace chaining (just added)
- ✅ Configurable HL threshold (just added)

### Phase 1: Healer Supremacy (Week 1 — June 28 - July 5)
- [ ] Stop-Cast Engine (`shared/stopcast_sylvanas.lua`)
- [ ] Pre-Heal System (`shared/preheal_sylvanas.lua`)
- [ ] Pet Healing (`shared/pet_heal_sylvanas.lua`)
- [ ] Tank-Priority HP Bias
- [ ] Per-Spell HP Thresholds
- [ ] Auto Spec Detection (Holy/Disc)

### Phase 2: Tank & Melee Supremacy (Week 2 — July 5 - July 12)
- [ ] Snap Threat on Combat Start
- [ ] Mana Emergency Swap (JoW)
- [ ] Post-Swing Judgement
- [ ] Seal Twist Diagnostics
- [ ] Totem Twisting
- [ ] Auto Weapon Buffs by Level
- [ ] Intelligent Shield Switching

### Phase 3: Ranged & Caster Supremacy (Week 3 — July 12 - July 19)
- [ ] Multi-DoT Engine
- [ ] DoT TTD Gating
- [ ] Inner Focus → Mind Blast
- [ ] Auto-Shot Timer
- [ ] Dynamic Aspect Switching
- [ ] Melee Weaving

### Phase 4: Warrior & Polish (Week 4 — July 19 - July 26)
- [ ] Stance Dance Management
- [ ] Smart Rage Management
- [ ] Healthstone Automation
- [ ] Fade Automation
- [ ] Fully Automated Dispel
- [ ] Combat Mode Override

### Phase 5: Marketing & Community (Week 5+)
- [ ] Free Trial request to PS team
- [ ] Versioned changelogs
- [ ] Discord server
- [ ] Plugin page copy overhaul

### Baseline (ALL GREEN)
- 171 rotation tests: PASS
- 11 leveling tests: PASS
- 31 vanilla audit: PASS (0 tainted)
- 61 sylvanas audit: PASS (0 invalid)
- 386/386 luac -p: PASS
- Critical runtime scan: 0 issues

### Remaining from Previous Sprint
1. Hunter cliptracker port (tbc-main has 1361-line module vs EAX's 39-line stub)
2. Shared module Pattern 15 headers (43/64 missing)
3. Remaining raid defensive thresholds (~14 specs)
4. Druid bear test failure (pre-existing from another agent)
