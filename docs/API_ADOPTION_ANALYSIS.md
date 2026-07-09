# API Adoption Analysis

**Date:** 2026-07-09
**Scope:** EaxRotations API usage across all 29 TBC specs + shared modules
**Method:** Static code analysis via grep + manual verification

---

## Summary

| Namespace | Functions | Specs Using | Coverage |
|-----------|-----------|-------------|----------|
| `core.spell_book` | 12 | 29/29 | 100% |
| `core.object_manager` | 8 | 29/29 | 100% |
| `core.input` | 6 | 29/29 | 100% |
| `core.buff_manager` | 4 | 5/29 | 17% |
| `core.menu` | 5 | 0/29 | 0% |
| `izi_sdk` | 6 | 4/29 | 14% |
| `NS wrappers` | 15 | 29/29 | 100% |

---

## core.spell_book

| Function | Used By | Notes |
|----------|---------|-------|
| `is_spell_learned()` | All specs | Via `NS.spell_ready()` wrapper |
| `get_spell_cooldown()` | All specs | Via `NS.cooldown_remains()` wrapper |
| `get_base_power_regen()` | `fsr_manager_sylvanas.lua` | Lazy-loaded, TBC 5SR API |
| `get_casting_power_regen()` | `fsr_manager_sylvanas.lua` | Lazy-loaded, TBC 5SR API |
| `get_spell_info()` | `spell_corpus_sylvanas.lua` | Spell metadata lookup |
| `has_spell()` | `core_sylvanas.lua` | Internal helper |

**Gap:** `get_base_power_regen()` / `get_casting_power_regen()` only used by FSR manager. No spec queries these directly.

---

## core.object_manager

| Function | Used By | Notes |
|----------|---------|-------|
| `get_local_player()` | All specs | Via `NS.GetPlayer()` wrapper |
| `get_all_objects()` | `enemy_cache_sylvanas.lua` | 50-object limit with early exit |
| `get_enemies()` | `core_sylvanas.lua` | Throttled to 2s TTL |
| `get_party_members()` | `triage_sylvanas.lua` | Healer target scan |

**Gap:** `get_visible_objects()` not used directly; specs use `get_enemies()` or cached enemy lists.

---

## core.input

| Function | Used By | Notes |
|----------|---------|-------|
| `cast_target_spell()` | `core_sylvanas.lua` | Fallback after izi/spell_queue |
| `cast_position_spell()` | `core_sylvanas.lua` | AoE spells |
| `use_item()` | `consumable_manager_sylvanas.lua` | Potions, healthstones |
| `jump()` | None | Not used in rotation specs |
| `look_at()` | None | Not used in rotation specs |

**Gap:** `jump()` and `look_at()` are not used by any rotation spec. They may be used by EaxAutoQuester.

---

## izi_sdk

| Function | Used By | Notes |
|----------|---------|-------|
| `izi.spell(id)` | Warlock specs, Hunter core, `core_sylvanas.lua` | Pattern 5 from AGENTS.md |
| `izi.item(id)` | None | Not used in any spec |
| `izi.me()` | None | Not used in any spec |
| `izi.enemies(r)` | None | Not used in any spec |
| `izi.pick_enemy(fn)` | None | Not used in any spec |
| `izi.on_combat_start(fn)` | None | Not used in any spec |

**Gap:** izi SDK is documented in `api/common/izi_sdk.lua` (869 lines) but used by only ~14% of specs. The vast majority use legacy `NS.try_cast()` / `NS.spell_ready()` patterns.

**Migration plan:** Convert 5+ high-priority specs to izi SDK per AGENTS.md Pattern 5. Priority order:
1. Mage Arcane (already uses `izi.spell` in some paths)
2. Hunter BM (pet management)
3. Priest Shadow (DoT tracking)
4. Rogue Combat (energy tick sync)
5. Warrior Fury (rage management)

---

## NS Wrappers (Primary API Pattern)

All 29 specs use these NS helper functions defined in `core_sylvanas.lua`:

| Function | Specs Using | Correct? |
|----------|-------------|----------|
| `NS.try_cast(spell, target, label, opts)` | 29/29 | Yes |
| `NS.spell_ready(spell, target, opts)` | 29/29 | Yes |
| `NS.buff_up(unit, ids)` | 29/29 | Yes |
| `NS.buff_remains(unit, ids)` | 29/29 | Yes |
| `NS.debuff_up(unit, ids)` | 29/29 | Yes |
| `NS.debuff_remains(unit, ids)` | 29/29 | Yes |
| `NS.cooldown_remains(spell, cd)` | 29/29 | Yes |
| `NS.buff_points(unit, ids)` | 5/29 | Healer specs + Prot Pally |
| `NS.debuff_points(unit, ids)` | 2/29 | Prot Pally |
| `NS.gate_overheal(spell, target, cast_time, settings)` | 5/29 | Healer specs |
| `NS.get_spell_id(spell)` | 29/29 | Yes |
| `NS.get_setting(key, fallback)` | 29/29 | Yes |

---

## Menu API (core.menu)

| Function | Used By | Notes |
|----------|---------|-------|
| `checkbox()` | 0/29 | Settings created by middleware |
| `slider_int()` | 0/29 | Settings created by middleware |
| `slider_float()` | 0/29 | Settings created by middleware |
| `combobox()` | 0/29 | Settings created by middleware |
| `keybind()` | 0/29 | Settings created by middleware |

**Note:** Menu widgets are created by `schema_sylvanas.lua` files (one per class), not by spec files directly. Specs access settings via `context.settings` (Pattern 8). This is correct per AGENTS.md.

---

## Graphics API (core.graphics)

| Function | Used By | Notes |
|----------|---------|-------|
| `circle_3d()` | `swing_diagnostics_sylvanas.lua` | Swing timer visualization |
| `text_3d()` | `swing_diagnostics_sylvanas.lua` | Seal twist diagnostics |
| `line_3d()` | None | Not used |
| `rect_2d()` | None | Not used |

---

## Known API Gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| izi SDK adoption at 14% | Missing modern API benefits (auto-range, auto-GCD, cleaner syntax) | Medium |
| `jump()` / `look_at()` unused | Movement abilities not integrated | Low |
| `core.menu` direct access in specs | Could crash if middleware not loaded; currently safe via `context.settings` | Low |
| `core.graphics` underutilized | Only swing diagnostics use it; could add CD trackers | Low |
| `core.buff_manager` at 17% | Only healer specs use AuraCache; DPS specs use raw `buff_up` | Low |

---

## Verification Checklist

- [x] All API calls nil-guarded
- [x] No banned APIs used (`ffi.C`, `io.popen`, `os.execute`, `debug.*`)
- [x] `luac -p` passes on all files
- [x] All spell IDs verified against DBC
- [x] NS wrappers are the primary API pattern (correct)
- [ ] izi SDK migration incomplete (~14% adoption)
- [ ] `get_base_power_regen` / `get_casting_power_regen` only used by FSR manager

---

*Generated: 2026-07-09*
*Files analyzed: 296 sylvanas files + 31 vanilla files*
