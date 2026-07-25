# Plan: Migrate EaxRotations Menu to Declarative `_G.menu` API

**Created**: 2026-07-25
**Status**: Proposed (awaiting review)
**Effort**: Major refactor (~3-5 sessions)
**Risk**: Medium — touches the entire menu infrastructure, but spec files are untouched

---

## 1. Problem Statement

The current imperative menu (`core.menu.*` + `tree_node:render()`) has a broken section
scoping at depth-2: sibling section trees merged so all widgets dumped into the last one
rendered ("Auto Consumables has everything"). This was fixed by rendering sections at
depth-1 (directly inside `main_tree`), but that removes the "Class Settings" master
fold-out — sections are now siblings to Quick Toggles/Theme/Diagnostics, grouped only by a
plain header label.

**Goal**: Use the declarative `_G.menu` API (retained mode) to get proper nested
collapsibility — a "Class Settings" section with collapsible subsections inside it — without
the tree_node merging bug. This is also the API the PS docs recommend as the primary path.

---

## 2. Key Architectural Insight (Why the blast radius is contained)

The abstraction layer between the menu and spec files is a **plain Lua table** (`NS.settings`)
read via `NS.get_setting(key, default)` with a 200ms TTL cache (`EaxRotations/core/settings.lua`).

```
Current flow:
  Menu widgets (core.menu.checkbox etc.)
    → main.lua sync loop reads widget.control:get()/get_state() into NS.settings table
      → NS.get_setting(key, default) reads from NS.settings (cached)
        → spec_kit.setting(context, key, default) → NS.get_setting
          → spec files read settings (NEVER touch widgets directly)

Declarative flow (after migration):
  _G.menu declaration (section:checkbox/slider/keybind etc.)
    → menu:get(page_path, widget_id) reads live values
      → sync loop writes them into NS.settings table (SAME table, SAME proxy)
        → NS.get_setting(key, default) → spec_kit.setting → spec files (UNCHANGED)
```

**Spec files require ZERO changes.** They all read through `NS.get_setting` / `spec_kit.setting`.
The migration only changes:
1. How widgets are **declared** (imperative `core.menu.*` → declarative `section:checkbox/slider/...`)
2. How widget values are **read** (imperative `widget.control:get()` → `menu:get(path, id)`)
3. How widgets are **rendered** (per-frame `:render()` calls → automatic, engine handles it)
4. How **collapsibility** works (broken `tree_node` at depth-2 → native `section:subsection()` with `collapsed` opts)

---

## 3. API Reference (verified from `.api/common/menu/api.lua`)

### Core hierarchy
```
menu:page(path, meta)              → menu_page    (sidebar leaf)
page:title(text, opts)             → menu_page    (standalone title band)
page:section(title, icon, opts)    → menu_section (collapsible card, 2-column grid)
section:subsection(title, opts)    → menu_subsection (nested collapsible, arbitrary depth)
section:checkbox(id, label, default, opts)
section:slider(id, label, min, max, default, suffix, opts)
section:dropdown(id, label, options, default_index, opts)
section:keybind(id, label, default_vk, opts)
section:color_picker(id, label, default_rgba, opts)
section:button(id, label, opts)
section:label(text, opts)
section:separator(label)
section:spacer(h)
```

### Value shapes (what `menu:get` returns)
| Widget | `menu:get` return type |
|--------|----------------------|
| checkbox/toggle | `boolean` |
| slider | `number` |
| dropdown/radio/tabs | `integer` (1-based index) |
| keybind | `{ vk, mods, mode, active }` |
| color_picker | `{ r, g, b, a }` |

### Key methods
- `menu:page({ "EaxRotations" }, { icon = "..." })` — create/fetch page
- `menu:get(page_path_str, widget_id)` — read value (safe every frame)
- `menu:set(page_path_str, widget_id, value)` — write value (fires observers)
- `menu:on_change(page_path_str, widget_id, fn)` — observe changes
- `section.opts.collapsed` — default collapse state (user can toggle by clicking title)
- `section.opts.visible` — boolean or `fun(): boolean` visibility gate (per-frame)

### Control panel (permashow)
- `menu.control_panel.add(element, lock)` — add keybind/combobox to control panel (simple path)
- Replaces the legacy `on_control_panel_render()` callback

---

## 4. Current Infrastructure to Migrate (in `EaxRotations/main.lua`)

| Function / Pattern | Lines | What it does | Migration target |
|---|---|---|---|
| `make_tree(id)` | ~337 | Wraps `core.menu.tree_node(id)` in pcall | **Remove** — no tree_node needed |
| `create_schema_widget(def)` | ~367 | Creates `core.menu.checkbox/slider_int/combobox` from schema def | **Rewrite** → `section:checkbox/slider/dropdown` declaration |
| `initialize_schema_menu()` | ~465 | Pre-allocates all widgets + section trees | **Rewrite** → declarative page/section/subsection tree |
| `render_menu()` | ~870+ | Per-frame `tree:render()` + `widget.control:render()` | **Shrink dramatically** → no per-frame rendering (engine handles it); only visibility updates |
| `get_keybind_toggle_state(control, default)` | ~709 | Reads `keybind:get_state()` / `:get_toggle_state()` | **Rewrite** → `menu:get(path, id).active` |
| `sync_playstyle_control()` | ~751 | Reads `playstyle_combo:get()` | **Rewrite** → `menu:get(path, "playstyle")` |
| `on_control_panel_render()` | ~808 | Legacy callback returning control panel elements | **Rewrite** → `menu.control_panel.add(element)` at setup |
| `sync_quick_toggles()` | (near 1129) | Reads all keybind toggle states → NS.settings | **Rewrite** → `menu:get(path, id).active` → NS.settings |
| Settings sync loop | ~1100-1160 | Reads all widget values into NS.settings, calls `NS.refresh_settings_cache` | **Rewrite** → `menu:get` for each widget → NS.settings |

### What does NOT change
- `EaxRotations/core/settings.lua` — the `NS.get_setting`/`NS.set_setting`/`refresh_settings_cache` proxy is **menu-agnostic**. It reads from a plain table. The sync loop just needs to populate that table from `menu:get` instead of `widget.control:get()`.
- All 29 spec files + 31 leveling files — they read through `spec_kit.setting` → `NS.get_setting`. Untouched.
- `EaxRotations/shared/menu_theme_sylvanas.lua` — scoping logic (`scope_admits`, `section_playscope`) can be reused as `visible` function gates on sections/subsections.
- `EaxRotations/shared/spec_kit_sylvanas.lua` — untouched.
- `EaxRotations/shared/schema_consumables_sylvanas.lua` — schema definitions are widget-kind-agnostic (they declare `{ type = "checkbox", key = "...", label = "...", default = ... }`). The declaration layer translates these to either `core.menu.checkbox` or `section:checkbox`.

---

## 5. Proposed Menu Structure (Declarative)

```
Page: { "EaxRotations" }
├── Title: "EaxRotations — TBC Classic Rotations"
├── Section: "Quick Toggles" (column = "full", collapsed = false)
│   ├── keybind: eax_rotation_enabled
│   ├── keybind: eax_healing_enabled
│   ├── keybind: eax_damage_enabled
│   ├── keybind: eax_cooldowns_enabled
│   ├── keybind: eax_aoe_enabled
│   ├── keybind: eax_interrupts_enabled
│   ├── keybind: eax_utility_enabled
│   ├── keybind: eax_threat_drop_enabled
│   └── keybind: eax_auto_taunt
├── Section: "Class Settings" (column = "full", collapsed = false)
│   ├── label: "Active Playstyle: <cat>"  (dynamic via visible/title function)
│   ├── dropdown: playstyle (options from schema)
│   ├── Subsection: "Rotation" (collapsed = false, visible = scope_admits(nil, active))
│   │   ├── checkbox: use_bt, slider: hp_threshold, ...
│   │   └── ...
│   ├── Subsection: "Bear Tank" (collapsed = true, visible = scope_admits({"bear"}, active))
│   │   └── ...
│   ├── Subsection: "Cat (Feral DPS)" (collapsed = false, visible = scope_admits({"cat"}, active))
│   │   └── ...
│   ├── Subsection: "Balance" (collapsed = true, visible = scope_admits({"balance"}, active))
│   │   └── ...
│   ├── Subsection: "Restoration" (collapsed = true, visible = scope_admits({"resto"}, active))
│   │   └── ...
│   ├── Subsection: "Auto Consumables" (collapsed = true, visible = true — always shown)
│   │   └── ...
│   └── Subsection: "Leveling Settings" (collapsed = true, visible = true — always shown)
│       └── ...
├── Section: "Theme" (column = "full", collapsed = true)
│   ├── checkbox: eax_theme_override_enabled
│   └── color_picker: eax_theme_accent_color
└── Section: "Diagnostics" (column = "full", collapsed = true)
    ├── button: eax_dump_spells
    ├── checkbox: eax_debug_swing_timer
    └── checkbox: eax_debug_game_events
```

### Why this works where tree_node didn't
- `section:subsection()` is a **first-class collapsible** with its own chevron header, nested
  inside a section card. The engine handles the rendering and collapse state — no
  `tree_node:render()` callback scoping to break.
- `opts.visible` can be a **function** re-evaluated per frame — this replaces the
  `scope_admits` gate with native menu visibility instead of conditional rendering.
- Subsections default to `collapsed = true`; the active playstyle's section defaults to
  `collapsed = false` for immediate visibility.

---

## 6. Implementation Phases

### Phase 1: Scaffolding (1 session)
**Goal**: Create the declarative page structure alongside the existing imperative menu, behind a feature flag.

1. Add `_G.menu` detection at load time (`local declarative_menu = _G.menu ~= nil`).
2. Create `EaxRotations/shared/declarative_menu_sylvanas.lua` — a new module that:
   - Builds the page/section/subsection tree from the schema (same schema definitions)
   - Translates `{ type = "checkbox", key = "...", ... }` → `section:checkbox(id, label, default, opts)`
   - Translates `{ type = "slider", key = "...", ... }` → `section:slider(id, label, min, max, default, suffix, opts)`
   - Translates `{ type = "combobox", key = "...", ... }` → `section:dropdown(id, label, options, default_index, opts)`
   - Translates `{ type = "keybind", key = "...", ... }` → `section:keybind(id, label, default_vk, opts)`
   - Applies `MenuTheme.scope_admits` as `visible` functions on subsections
3. Add a sync function that reads `menu:get(path, id)` → `NS.settings[key]` (replaces the imperative sync loop).
4. Feature flag: if `_G.menu` is available AND a "use declarative menu" setting is on, use the new path; otherwise fall back to the imperative menu.

**Validation**: `luac -p` + full test suite (390 rotation + 31 leveling). No behavior change yet (imperative menu still active by default).

### Phase 2: Settings Sync (1 session)
**Goal**: Wire the declarative menu's values into `NS.settings` so spec files read them correctly.

1. Rewrite the sync loop in `main.lua` to use `menu:get(page_path, widget_id)` when the declarative menu is active.
2. Map widget value shapes:
   - `checkbox` → `menu:get` returns `boolean` → write directly to `NS.settings[key]`
   - `slider` → `menu:get` returns `number` → write directly
   - `dropdown` → `menu:get` returns `integer` (1-based index) → convert to the schema's option key/value
   - `keybind` → `menu:get` returns `{ vk, mods, mode, active }` → write `.active` to `NS.settings[key]`
3. Replace `get_keybind_toggle_state()` with `menu:get(path, id).active`.
4. Replace `sync_playstyle_control()` with `menu:get(path, "playstyle")`.
5. Call `NS.refresh_settings_cache()` after the sync loop (same as current).

**Validation**: `luac -p` + full test suite. Enable the feature flag manually and verify settings flow through to spec files.

### Phase 3: Control Panel + Theme (1 session)
**Goal**: Migrate the control panel (permashow) and theme section.

1. Replace `on_control_panel_render()` callback with `menu.control_panel.add(element)` calls at setup.
2. Migrate the Theme section (checkbox + color_picker) to declarative.
3. Migrate the Diagnostics section (button + checkboxes) to declarative.
4. Test theme override still works (`EaxRotations/shared/theme_override_sylvanas.lua` reads `eax_theme_override_enabled` and `eax_theme_accent_color` from settings).

**Validation**: `luac -p` + full test suite + in-game control panel test.

### Phase 4: Cleanup (1 session)
**Goal**: Remove the imperative menu code and make declarative the default.

1. Remove `make_tree()`, the imperative `create_schema_widget()`, the imperative `initialize_schema_menu()`, the imperative `render_menu()`.
2. Remove `on_control_panel_render()`, `get_keybind_toggle_state()`, `sync_playstyle_control()` (replaced in Phase 2).
3. Remove the feature flag — declarative menu is the only path.
4. Remove dead `settings_tree` allocation (kept for compat in the depth-1 fix).
5. Update `AGENTS.md` Menu Item Reference table to reflect declarative API.
6. Update `test_spec_layout_compliance.lua` if it asserts on menu structure.

**Validation**: `luac -p` + full test suite (390 + 31) + `lua EaxRotations/tests/run_sylvanas_audit_tests.lua` + code-reviewer-glm.

### Phase 5: Polish (0.5 session)
**Goal**: UX refinements.

1. Set `collapsed = false` for the active playstyle's subsection (dynamic, based on current playstyle).
2. Set `collapsed = true` for inactive playstyle subsections.
3. Add `searchable = true` to the "Class Settings" section for per-section widget search.
4. Add section icons via `icon` parameter (e.g., "shield" for Bear Tank, "paw" for Cat).
5. Add `description` tooltips on subsection headers.
6. Consider `menu:on_change` for the playstyle dropdown to auto-collapse/expand subsections.

**Validation**: `luac -p` + full test suite + in-game visual review.

---

## 7. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `_G.menu` not available at runtime | Low (PS docs say it's installed by host) | High (menu doesn't render) | Feature flag + imperative fallback in Phase 1-3 |
| Widget id persistence breaks (saved values orphaned) | Medium | Medium (users re-set toggles) | Keep widget ids identical to current `def.key` values |
| `menu:get` value shape mismatch (dropdown 1-based index vs current combobox) | Medium | High (wrong setting values) | Explicit index→value mapping in sync loop (Phase 2) |
| Keybind `active` state semantics differ | Low | Medium | `menu:get(path, id).active` maps to current `get_toggle_state()` |
| Control panel rendering changes | Low | Low | `menu.control_panel.add` is the recommended simple path |
| Spec layout compliance test breaks | Low | Low | Check + update `test_spec_layout_compliance.lua` in Phase 4 |

---

## 8. Acceptance Criteria

- [ ] "Class Settings" is a collapsible section card with a chevron
- [ ] Each category (Rotation, Bear Tank, Cat DPS, Balance, Restoration, Auto Consumables, Leveling) is a collapsible subsection inside it
- [ ] Subsections for inactive playstyles are hidden (via `visible` function gate)
- [ ] The active playstyle's subsection is expanded by default
- [ ] All widget values flow correctly to spec files (Rip fires, Prowl toggle works, auto-taunt toggle works)
- [ ] Quick Toggles keybinds work and appear on the control panel
- [ ] Theme override still works
- [ ] `luac -p` passes on all modified files
- [ ] 390/390 rotation + 31/31 leveling test suites pass
- [ ] `run_sylvanas_audit_tests.lua` passes
- [ ] No spec files modified (zero blast radius beyond menu infrastructure)

---

## 9. Verification Commands

```bash
# Syntax check (per file)
luac -p EaxRotations/main.lua
luac -p EaxRotations/shared/declarative_menu_sylvanas.lua

# Full test suite
lua EaxRotations/tests/run_rotation_tests.lua
lua EaxRotations/tests/run_leveling_tests.lua

# Spell ID audit
lua EaxRotations/tests/run_sylvanas_audit_tests.lua

# Spec layout compliance
lua EaxRotations/tests/test_spec_layout_compliance.lua
```

---

## 10. Files Touched

| File | Phase | Change |
|---|---|---|
| `EaxRotations/shared/declarative_menu_sylvanas.lua` | 1 | **NEW** — declarative menu builder module |
| `EaxRotations/main.lua` | 1-4 | Rewrite menu init/render/sync; remove imperative code in Phase 4 |
| `EaxRotations/main_sylvanas.lua` | 2 | Update settings sync call (if any direct references) |
| `AGENTS.md` | 4 | Update Menu Item Reference table |
| `EaxRotations/tests/test_spec_layout_compliance.lua` | 4 | Update if it asserts on menu structure |

**NOT touched**: All 29 spec files, all 31 leveling files, `core/settings.lua`, `spec_kit_sylvanas.lua`, `menu_theme_sylvanas.lua`, `schema_consumables_sylvanas.lua`, all class schema files.

---

## 11. Open Questions (resolve before Phase 1)

1. **Should we keep the imperative menu as a fallback permanently, or remove it in Phase 4?**
   - Recommendation: Remove in Phase 4. The feature flag is for migration safety, not a permanent dual-menu system.

2. **Should the playstyle dropdown live inside "Class Settings" or as a standalone page element?**
   - Recommendation: Inside "Class Settings" as the first element, with a dynamic label showing the active playstyle.

3. **Should we use `menu:on_change` for real-time setting updates, or keep the per-frame sync loop?**
   - Recommendation: Keep the per-frame sync loop for Phase 1-3 (minimal change from current architecture). Consider `on_change` in Phase 5 for playstyle switching responsiveness.

4. **Column layout: should "Class Settings" use `column = "full"` (single column) or the two-column grid?**
   - Recommendation: `column = "full"` — matches the current single-column layout and avoids widget reflow confusion.
