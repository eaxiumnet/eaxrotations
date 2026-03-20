# Requirements: EAX TBC Classic Rotations

**Defined:** 2026-03-20
**Core Value:** Every spec executes the mathematically optimal rotation while maintaining survival and encounter-specific awareness.

## v1 Requirements

### Foundation

- [ ] **FOUND-01**: Extract shared modules to `common/eax_shared/` — interrupt_manager, defensive_manager, encounter_manager, ooc_manager, racial_manager
- [ ] **FOUND-02**: Refactor all 27 specs to require shared modules from `common/eax_shared/`
- [ ] **FOUND-03**: Create `set_bonus.lua` in `common/eax_shared/` with dynamic gear scanning for all T4/T5/T6 sets

### Core Combat

- [ ] **COMBAT-01**: Implement swing timer library in `common/eax_shared/swing_timer.lua` — get next swing time, safe queue check, safety buffer support
- [x] **COMBAT-02**: Add DoT clip prevention to all DoT-casting specs — never refresh before final tick, track remaining duration
- [ ] **COMBAT-03**: Implement threat estimation — track estimated DPS, warn or fade before threat pull
- [x] **COMBAT-04**: Add mana management for casters — pre-pull consumables, OOM prevention, Evocation timing

### Interrupt System

- [x] **INTER-01**: Refine interrupt spell weights — add missing dangerous spell IDs from sim data
- [x] **INTER-02**: Add minimum cast time check — don't interrupt casts with <200ms remaining
- [x] **INTER-03**: Expand interrupt target selection — prioritize healing over CC over offensive

### Encounter Awareness

- [x] **ENCOUNT-01**: Expand boss database — add missing encounters, refine policies
- [x] **ENCOUNT-02**: Add AoE safe detection for all dungeon/raid encounters
- [x] **ENCOUNT-03**: Implement cooldown hold for burn phases (Gruul, Magtheridon, etc.)
- [x] **ENCOUNT-04**: Add movement phase awareness — pre-position, cast while moving

### Per-Class Rotation Optimization

#### Warrior
- [x] **WARR-01**: Optimize Arms slam weave — swing timer check with configurable safety buffer
- [x] **WARR-02**: Optimize Fury execute phase — 2 fast 1-handers below 20% HP
- [x] **WARR-03**: Add stance dance for Prot Warrior — shield slam priority with rage management

#### Hunter
- [ ] **HUNT-01**: Implement MM Hunter steady shot / aimed shot rotation with auto shot alignment
- [ ] **HUNT-02**: Add haste breakpoint detection — switch between 2:1, 1:1, 1:2, 1:3 based on weapon speed
- [ ] **HUNT-03**: Implement melee weaving for BM Hunter — Arcane/FM shot between autos

#### Mage
- [ ] **MAGE-01**: Implement Arcane Mage 3-stack burn phase — AB spam, all CDs, Evocation timing
- [ ] **MAGE-02**: Add Fire Mage Scorch stack management — 5 Improved Scorch before Fireball
- [ ] **MAGE-03**: Add Fire Mage Molten Fury execute awareness — plan cooldowns for 20% HP
- [ ] **MAGE-04**: Add Frost Mage FSCT timing — cast time < swing time awareness

#### Warlock
- [ ] **LOCK-01**: Implement Affliction DoT clip prevention — Corruption, Immolate, Siphon Life, UA
- [ ] **LOCK-02**: Add Destro Lock Conflagrate on proc timing
- [ ] **LOCK-03**: Implement Demo Lock Metamorphosis / Felguard rotation

#### Priest
- [ ] **PRST-01**: Implement Shadow Priest DoT clip prevention — SW:P, Vampiric Touch
- [ ] **PRST-02**: Add Shadow Priest Mind Blast timing — on proc or when GCD available
- [ ] **PRST-03**: Add Disc Priest PW:S shield management

#### Druid
- [ ] **DRUID-01**: Implement Balance DoT clip prevention — Insect Swarm, Moonfire
- [ ] **DRUID-02**: Add Balance Druid eclipse detection and burst phase
- [ ] **DRUID-03**: Implement Feral Druid CP / energy management with bite timing

#### Paladin
- [ ] **PAL-01**: Add Ret Paladin Crusader Strike on cooldown, Divine Storm on AOE
- [ ] **PAL-02**: Add Holy Paladin Holy Shock / Flash of Light priority
- [ ] **PAL-03**: Add Prot Paladin Holy Wrath / Avengers Shield priority

#### Shaman
- [ ] **SHAM-01**: Implement totem item scanning — check bag for totem items before casting
- [ ] **SHAM-02**: Add Enhancement Stormstrike priority, Lava Lash timing
- [ ] **SHAM-03**: Add Elemental chain lightning / lava burst burst phase

#### Rogue
- [ ] **ROGUE-01**: Implement Subtlety Rogue Backstab / Hemorrhage rotation
- [ ] **ROGUE-02**: Add Rogue SnD refresh timing — don't let it expire, don't clip too early
- [ ] **ROGUE-03**: Add Rogue Blade Flurry on multi-target

### Visual & Polish

- [ ] **VIS-01**: Implement DPS/HPS meter in ESP — track damage/healing per fight
- [ ] **VIS-02**: Add cooldown timer display in HUD — next ability available
- [ ] **VIS-03**: Add TTD display in HUD — time-to-death for current target
- [ ] **VIS-04**: Add buff/debuff tracker display in ESP

### Automation

- [ ] **AUTO-01**: Add auto-repair — repair when durability drops below threshold
- [ ] **AUTO-02**: Add auto-sell grey items
- [ ] **AUTO-03**: Add consumables management — track and use potions, food, flasks
- [ ] **AUTO-04**: Add auto-dismount in combat, auto-mount out of combat

### Quality

- [ ] **QUAL-01**: Create rotation validation framework — per-spec rotation correctness check
- [ ] **QUAL-02**: Add DPS benchmark tool — measure rotation effectiveness vs baseline
- [ ] **QUAL-03**: Create spec regression checklist — verify all specs still work after changes

## v2 Requirements

Deferred to future work.

- **V2-01**: Custom APL/priority editor UI — let users edit rotation priorities
- **V2-02**: SimC profile import — parse simc output into rotation tables
- **V2-03**: PvP mode — battleground automation
- **V2-04**: Fresh 70 speedrun mode — optimize for fastest leveling
- **V2-05**: Multi-bot coordination — party leader tactics

## Out of Scope

Explicitly excluded.

| Feature | Reason |
|---------|--------|
| Memory-based API hooks | Ban risk, stick to Sylvanas APIs |
| Retail / WotLK / MoP support | TBC Classic only |
| Battleground PvP automation | Not target use case |
| Hardcore death prevention | Out of rotation scope |
| Multi-client party tactics | Each bot runs independently |

## Traceability

Phase mapping populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Pending |
| FOUND-02 | Phase 1 | Pending |
| FOUND-03 | Phase 1 | Pending |
| COMBAT-01 | Phase 2 | Pending |
| COMBAT-02 | Phase 2 | Complete |
| COMBAT-03 | Phase 2 | Pending |
| COMBAT-04 | Phase 2 | Complete |
| INTER-01 | Phase 2 | Complete |
| INTER-02 | Phase 2 | Complete |
| INTER-03 | Phase 2 | Complete |
| ENCOUNT-01 | Phase 2 | Complete |
| ENCOUNT-02 | Phase 2 | Complete |
| ENCOUNT-03 | Phase 2 | Complete |
| ENCOUNT-04 | Phase 2 | Complete |
| WARR-01 | Phase 3 | Complete |
| WARR-02 | Phase 3 | Complete |
| WARR-03 | Phase 3 | Complete |
| HUNT-01 | Phase 3 | Pending |
| HUNT-02 | Phase 3 | Pending |
| HUNT-03 | Phase 3 | Pending |
| MAGE-01 | Phase 3 | Pending |
| MAGE-02 | Phase 3 | Pending |
| MAGE-03 | Phase 3 | Pending |
| MAGE-04 | Phase 3 | Pending |
| LOCK-01 | Phase 3 | Pending |
| LOCK-02 | Phase 3 | Pending |
| LOCK-03 | Phase 3 | Pending |
| PRST-01 | Phase 3 | Pending |
| PRST-02 | Phase 3 | Pending |
| PRST-03 | Phase 3 | Pending |
| DRUID-01 | Phase 3 | Pending |
| DRUID-02 | Phase 3 | Pending |
| DRUID-03 | Phase 3 | Pending |
| PAL-01 | Phase 3 | Pending |
| PAL-02 | Phase 3 | Pending |
| PAL-03 | Phase 3 | Pending |
| SHAM-01 | Phase 3 | Pending |
| SHAM-02 | Phase 3 | Pending |
| SHAM-03 | Phase 3 | Pending |
| ROGUE-01 | Phase 3 | Pending |
| ROGUE-02 | Phase 3 | Pending |
| ROGUE-03 | Phase 3 | Pending |
| VIS-01 | Phase 4 | Pending |
| VIS-02 | Phase 4 | Pending |
| VIS-03 | Phase 4 | Pending |
| VIS-04 | Phase 4 | Pending |
| AUTO-01 | Phase 4 | Pending |
| AUTO-02 | Phase 4 | Pending |
| AUTO-03 | Phase 4 | Pending |
| AUTO-04 | Phase 4 | Pending |
| QUAL-01 | Phase 4 | Pending |
| QUAL-02 | Phase 4 | Pending |
| QUAL-03 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 53 total
- Mapped to phases: 53
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-20*
*Last updated: 2026-03-20 after research synthesis*
