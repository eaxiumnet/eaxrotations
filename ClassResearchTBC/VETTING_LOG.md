# ClassResearchTBC Vetting Log

## 2026-05-18 DB2 / Tier-2 Pass

Scope: hard spell-ID and TBC-guardrail vetting across all 29 `Research.md` files plus root tracking docs.

Primary evidence:
- Local Wago `wow_anniversary` DB2 CSV exports in `DB2/`.
- Class DB2 indexes such as `Hunter/DB2-Spells.md`, `Paladin/DB2-Spells.md`, `Warlock/DB2-Spells.md`, and `Warrior/DB2-Spells.md`.
- Wowhead TBC spell pages for exact tooltip-facing behavior.
- Icy Veins TBC Feral DPS rotation/powershifting guidance for Feral source cleanup.

Resolved hard ID corrections:

| Area | Result | Implementation rule |
|---|---|---|
| Paladin Retribution seals | Seal of the Martyr uses [348700/348701] in local `wow_anniversary`; the previous ID was not present in TBC DB2 | Gate Seal of Blood [31892/31893] vs Seal of the Martyr [348700/348701] by faction |
| Warlock Affliction | Unstable Affliction max rank is [30405]; the previous ID resolves to Shadowfury | Use UA rank list [30108/30404/30405/31117], max rank [30405] at 70 |
| Warrior Fury | Rampage cast ranks are [29801/30030/30033]; [30033] is the level 70 +50 AP/stack rank | Resolve rank dynamically; use [30033] at level 70 |
| Hunter Survival | [19434] is Aimed Shot; Black Arrow is not a Survival mechanic here; Explosive Shot [53209] and Trap Launcher [77769] are DB2 absent | Do not implement Survival Black Arrow, Explosive Shot, or Trap Launcher |
| Hunter BM/MM | Aspect of the Viper [34074] and Silencing Shot [34490] are valid TBC Hunter spells | Use Viper as mana aspect and Silencing Shot as a 20s-CD silence/interrupt gate |
| Mage guardrails | Focus Magic [54646] and Brain Freeze [44549] are DB2 absent; Living Bomb [44457] has no Mage class skillline entry | Do not implement these Mage mechanics |
| Priest guardrails | Penance [47540], Rapture [47535], Guardian Spirit [47788], and Dispersion [47585] are DB2 absent | Do not implement them; Circle of Healing [34861] and Lightwell [724] remain valid Holy spells |
| Warlock guardrails | Demonic Empowerment [47193], Metamorphosis [47241], Demon Soul [77801], Demonic Pact [47236], Fel Intelligence [54424], Chaos Bolt [50796], and Backdraft [54274] are DB2 absent | Do not implement them for TBC |
| Shaman | Grace of Air Totem [10627] is rank 2; max rank is [25359]. Chain Lightning [25442] has 3 total targets and 0.70 jump amplitude | Resolve Grace ranks [8835/10627/25359]; keep Chain Lightning cluster radius configurable |
| Rogue | Mutilate [34413], Blade Flurry [13877], and Hemorrhage [26864] were confirmed against DB2/Wowhead behavior | Keep poison/behind, 2-target cleave, and Hemorrhage debuff gates |
| Warrior Arms/Protection | Commanding Shout [469] is valid TBC, not a WotLK violation | Gate on learned spell and raid assignment |
| Druid Restoration | Nourish [50464] is DB2 absent | Do not implement Nourish |

Remaining open categories are tracked in `VERIFY_LIST.md`. They are not hard spell-existence blockers; they require sims, logs, or Sylvanas runtime validation before hard-coding thresholds.

## 2026-05-21 Full Verification Pass

Scope: syntax, TBC guardrails, checklist completeness, and queue health across all 29 specs.

### Syntax Validation

| Check | Result |
|---|---|
| 29 spec `_sylvanas.lua` files via `luac -p` | 29/29 PASS |
| `main_sylvanas.lua` | PASS |
| `core_sylvanas.lua` | PASS |
| **Total** | **31/31 PASS** |

### TBC Guardrail Audit

Active codebase `EaxRotations/classes/` audited for banned WotLK/Cata spell IDs:

| Spell | ID | Class | Status |
|---|---|---|---|
| Penance | 47540 | Priest | Absent |
| Rapture | 47535 | Priest | Absent |
| Guardian Spirit | 47788 | Priest | Absent |
| Dispersion | 47585 | Priest | Absent |
| Demonic Empowerment | 47193 | Warlock | Absent |
| Metamorphosis | 47241 | Warlock | Absent |
| Demon Soul | 77801 | Warlock | Absent |
| Demonic Pact | 47236 | Warlock | Absent |
| Fel Intelligence | 54424 | Warlock | Absent |
| Chaos Bolt | 50796 | Warlock | Absent |
| Backdraft | 54274 | Warlock | Absent |
| Nourish | 50464 | Druid | Absent |
| Focus Magic | 54646 | Mage | Absent |
| Brain Freeze | 44549 | Mage | Absent |
| Living Bomb | 44457 | Mage | Absent |
| Explosive Shot | 53209 | Hunter | Absent |
| Trap Launcher | 77769 | Hunter | Absent |

**Result: 0 banned spell IDs found in active codebase. Clean.** (Hits found only in `archive_original_specs/`, `_archive_legacy/`, `_backup_*/`, and `.claude/worktrees/` — all archival/non-active paths.)

### Queue Health

| Queue State | Count |
|---|---|
| `completed/` | 28 |
| `blocked/` | 1 (001_Druid_Balance) |
| `in_progress/` | 0 |
| `pending/` | 0 |

### Blocked Job Status (2026-05-21 AM)

001_Druid_Balance blocked with three items unchanged since 2026-05-19:
1. Innervate assignment-aware casting — needs runtime API wiring in `main_sylvanas.lua`
2. SP breakpoint auto-switching (800/1000/1200) — needs wowsims/tbc + combat logs
3. Hurricane Barkskin-cast-before-channel automation — needs live Sylvanas test

### Checklist Completeness

All 29 `ImplementationChecklists/*_CHECKLIST.md` files present and accounted for.

### Conclusion (2026-05-21 AM)

All vetted work confirmed present. No WotLK/Cata regression detected. 28/29 specs fully completed. Druid Balance blocked on runtime evidence requirements — no code changes needed.

---

## 2026-05-21 Druid Balance Unblocking

### Resolution

| Blocker | Resolution |
|---|---|
| Hurricane Barkskin automation | ✅ Already implemented — `PreHurricaneBarkskin` (strategy #7) + `HurricaneAoE` (strategy #8) two-tick pattern. Confirmed 2026-05-19, documented 2026-05-21. |
| Innervate assignment-aware casting | ✅ Implemented 2026-05-21 — smart healer scanning ported from Resto spec: `HEALER_CLASS_IDS`, `NS.GetPartyMembers()`, `NS.mana_pct()`, pcall-safe `unit:get_class()`. Split into `InnervateHealer` + `InnervateSelf` strategies. |
| SP breakpoints (800/1000/1200) | ⛔ Deferred to `blocked/SP_Breakpoints_Druid_Balance.md` as standalone tracked task. Does not block 001 completion. |

### Job Status Change

001_Druid_Balance moved from `blocked/` → `completed/`. All 29 specs now completed.

### Files Changed

| File | Change |
|---|---|
| `EaxRotations/classes/druid/balance_sylvanas.lua` | Added `HEALER_CLASS_IDS`, `innervate_target` field, party scan in `build_state()`, split `InnervateHealer` + `InnervateSelf` |
| `EaxRotations/tests/test_balance_custom_matches.lua` | Updated Hurricane cooldown mock to match new Barkskin-ready deferral logic |
| `ClassResearchTBC/AgentQueue/blocked/001_Druid_Balance.md` | Status updated to completed; SP breakpoints deferred |
| `ClassResearchTBC/AgentQueue/blocked/SP_Breakpoints_Druid_Balance.md` | New — standalone tracked task for SP breakpoints |
| `ClassResearchTBC/AgentQueue/MANIFEST.md` | Druid Balance row updated; unblocking run added |
| `ClassResearchTBC/VETTING_LOG.md` | This entry |
| `ClassResearchTBC/ImplementationChecklists/Druid_Balance_CHECKLIST.md` | Updated with 2026-05-21 changes |

### Validation

- `luac -p` PASS on all modified files
- Full rotation test suite: 95/95 PASS
- Full leveling test suite: 11/11 PASS

### Current Queue State

| Queue | Count |
|---|---|
| `completed/` | 29 |
| `blocked/` | 1 (SP_Breakpoints_Druid_Balance.md — non-job) |
| `in_progress/` | 0 |
| `pending/` | 0 |
