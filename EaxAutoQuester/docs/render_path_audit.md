# Per-frame allocation audit — the paths outside the allocation gate

The gate (`tests/test_tick_allocation.lua`) measured two entry points: `coordinator.update()`
(T1-T3, now T10-T14 per state) and `coordinator.render_debug()` (T4-T9). Everything main.lua
does *around* those — the callback wrappers, the warning overlay, the menu render — was outside
it. This is the inventory of that surface, measured the same way (real entry points driven by
`tests/mock_core`, collector stopped, gross bytes per call, n=300, pinned Lua 5.1.5).

Corrections in this pass: **14 call sites** in 6 groups — the warning overlay's four per-frame
values, the keybind probe, the menu tree closure, and eight inline `pcall(function() ... end)`
unit probes in `combat_helper_sylvanas.lua` (five in `auto_face_enemy`, three in
`target_and_tag_nearest`). Each group has a mutant that fails against the old code. Recorded as
by design: **5** rows below. Removed as dead: **1 line and its static table**.

Nothing here is inferred: the one call whose allocation is the client's to decide carries its
doc citation, and the places where the fix narrows behaviour are named rather than hidden.

---

## 1. `on_render` (main.lua:230) — the warning overlay

`render_warnings` (main.lua:174) early-returns unless a warning is up, so a user who never
triggers one paid nothing before and pays nothing now (T15b, 0.00). While a warning *is* up it is
redrawn every frame, and every per-frame value was rebuilt.

| # | Site | Verdict | Evidence |
|---|------|---------|----------|
| 1 | warning text: was a fresh `lines` table + 3 appends + `table.concat` inside the frame | **fixed** — rebuilt only when the message changes (main.lua:182-186) | 96.00 + 80.00 B/frame measured; the three lines are constants and the middle one changes only when `set_warning` is called |
| 2 | warning position: was the `{ x = cx - 100, y = cy }` literal per frame | **fixed** — one static `_warn_pos` (main.lua:150), fields rewritten (main.lua:190-191) | 96.00 B/frame; same values computed (`screen.x * 0.5 - 100`, `screen.y * 0.4`) and proven identical by T15c |
| 3 | was `pcall(require, "common/color")` per drawn frame | **fixed** — attempted once and latched in `warning_color()` (main.lua:160-170, called at :192) | 33.51 B/frame *in the form of an error string* on a build that does not supply the module — the exact bug item 15 fixed on the render path |
| 4 | was `color.red(255)` per drawn frame | **fixed** — the instance is cached in the same latch (main.lua:163-166) | 160.00 B/frame (the control in the probe); the colour is never mutated |
| 5 | `core.graphics.get_screen_size()` (main.lua:188) | **by design, unchanged** | `get_screen_size()` returns a vec2 (`scraped_docs_md/dev/api/graphics.md:484`). Whether the binding hands back a fresh vec2 per call is not documented; the plugin reads `x`/`y` and keeps neither, and the read cannot be hoisted out of the frame because the window can be resized under the overlay. It is read only while a warning is up, and the gate pins it (96 B in the harness) so the bound covers the plugin's own work |
| 6 | `has_local_player()` (main.lua:11) called from the wrapper | **by design, unchanged** | 0.00 measured: `rawget` + three type checks + `pcall(f)` with no closure |
| 7 | `coordinator.render_debug()` (main.lua:236) | **already gated** | T4-T9; 0.00 with debug off, 0.29 with the overlay on (the text is rebuilt by design) |

Measured, warning active, n=300: **448.34 → 0.00** B/frame with the colour module present,
**225.84 → 0.00** without it. Bound 8 (T15/T15c), output identity asserted (one draw per frame,
same text, same position, same font size, same 255-alpha colour, `centered = false`).

**Behaviour narrowed, named:** the colour latch means a `common/color` that appeared *after* the
first drawn frame would never be picked up, where the old retry would eventually find it. The
module is supplied by the API the plugin loads at startup, so the case is degenerate. If
`color.red` raises, the overlay now never draws (the old code retried each frame): the error is
swallowed in both cases, only the retry differed. Text identity is compared against the message
value, so a *mutated table* passed as a warning message would no longer refresh the text — every
`set_warning` call site in the plugin passes a string.

## 2. `on_render_menu` (main.lua:238) — the menu render

| # | Site | Verdict | Evidence |
|---|------|---------|----------|
| 1 | the tree body: was a closure built inside `M.render` and handed to `M.tree:render` every frame | **fixed** — a module-level `render_tree_body` (menu_sylvanas.lua:125) handed over at once (menu_sylvanas.lua:201) | 32.00 B/frame measured; the body only reads widgets created once at load |
| 2 | the combobox label list rebuilt on every render | **by design, unchanged** | 0.00 in the same measurement: `_combo_labels` is a static table and the labels are interned constants (Pattern 4, already in place) |
| 3 | the widget `:render(...)` calls themselves | **by design, unchanged** | the client draws them; the harness's are no-ops, so what is measured is the plugin's own work |
| 4 | `local _t = { n = 0 }` and the `_t.n = 0` line that was the only thing touching it | **removed** | nothing in the file ever read `_t`: a static table and a no-op assignment |

Measured with the tree body really running (the harness drops the callback, so the gate gives it
one that calls it and asserts the body rendered at least seven widgets per frame):
**32.00 → 0.00** B/frame, bound 8.

## 3. `on_pre_tick` (main.lua:213) — the wrapper around the gated tick

The tick half drives `coordinator.update()` directly, so this frame — the player guard, the menu
reads, the keybind probe, the combat face — was never measured as a whole.

| # | Site | Verdict | Evidence |
|---|------|---------|----------|
| 1 | was `pcall(function() return _menu.toggle_keybind:get_toggle_state() end)` per frame | **fixed** — hoisted `keybind_toggle_state(widget)` (main.lua:76), called at main.lua:89 | 24.00 B/frame measured; a closure per frame, every frame |
| 2 | was five inline `pcall(function() ... end)` unit probes in `auto_face_enemy` | **fixed** — hoisted probes (combat_helper_sylvanas.lua:19-24), calls at :200, :202, :204, :206, :220 | 80.00 B/frame: the no-target path (the common one) pays two of them, `pcall(unit_get_target, me)` and `pcall(unit_is_in_combat, me)` |
| 3 | the same inline form in `target_and_tag_nearest` | **fixed** in the same edit (calls at combat_helper_sylvanas.lua:83, :85, :122) | not on the per-frame path (the function returns as soon as a target exists) but the same class and the same file; hoisting all eight keeps one idiom |
| 4 | `pcall(require, "combat_helper_sylvanas")` (main.lua:220) | **by design, unchanged** | 0.00 measured — a cached require; the argument is an interned literal |
| 5 | button `:is_clicked()` probes (main.lua:104/109/117/123) and the `pcall(function() ... end)` setters they lead to (main.lua:95/107/112) | **by design, unchanged** | the `is_clicked` probes are plain method calls (0.00 measured); the three closure-bearing setter calls run only when a button is actually clicked, not per frame |
| 6 | `combat_helper.is_current_target_valid` | **by design, unchanged** | inspected: no `pcall` closures in it at all (plain guarded method calls), and it is the per-tick path the IDLE kill-hold fixture reaches |
| 7 | `coordinator.update()` (main.lua:227) reached through the wrapper | **already gated** | T2/T3 and T10-T14 |

Measured with the machine in WAITING (the T10 fixture, so the only cost is the wrapper):
**104.00 → 0.00** B/frame, bound 8, with assertions that the coordinator updated, the combat face
ran and the keybind was read on every frame (so the zero is not a skipped path).

## 4. What this cannot prove

All of it is the desktop Lua 5.1.5's view of `tests/mock_core`. The client's own per-call cost
for `core.graphics.get_screen_size()`, the widget `:render` calls, `core.graphics.text_2d` and
the one real `require("common/color")` is not measured and cannot be from here. The draw
recorders and the mock's screen-size table are pinned exactly as the aura fixture is, so the
bounds cover the plugin's allocation and not the harness's. And the frame that raises these calls
— a warning up, the menu open — is simulated by fixtures rather than by the game, which is the
same caveat every battery in this plugin carries.
