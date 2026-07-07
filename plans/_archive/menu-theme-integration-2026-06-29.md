# Plan: Integrate Space Theme INTO the PS Main Menu (not a floating panel)

**Status:** completed
**Started/Completed:** 2026-06-29

## Problem
The earlier "Menu Overhaul" delivered the space/meteor starfield as a **standalone
floating Custom UI window** (`core.register_on_render_window_callback` +
`core.menu.window("eaxrotations_theme_panel")` + a Diagnostics "Theme Panel" toggle).
That is a separate floating panel — not integrated into the existing PS menu. User
rejected it.

## Root cause
Wrong callback + wrong window. Used `register_on_render_window_callback` (custom
overlay window) instead of `register_on_render_menu_callback` (the main menu window).

## Reference (proven working)
`OldProjects/archive_original_specs/*/libraries/ps_theme.lua` + `menu.lua` + `main.lua`
(EAX Space Theme v4.0). Pattern:
- `local win = core.menu.window(<id>)` → `set_initial_size` / `set_next_window_min_size` / `set_next_window_padding`
- `core.register_on_render_menu_callback(function() ... end)` — inside: call
  `ps.draw_space(win, id)` FIRST, then `root_tree:render(...)`. No `win:begin()` —
  the engine has already begun the menu window.
- `draw_space` is **scroll-aware**: `oy = win:get_current_context_dynamic_drawing_offset().y`,
  `scroll_y = win:get_scroll().y`, `oy_screen = oy - scroll_y` — pins the starfield to
  the screen while imgui content scrolls over it.

## Changes
### `EaxRotations/shared/menu_theme_sylvanas.lua`
- Rewrote `MenuTheme.draw_space(win, id, opt)` as a scroll-aware port of ps_theme v4.0:
  panel fill, dust, twinkling stars (+ cross-flare), meteors with gradient tails,
  titlebar glow line, corner brackets, diamond gems. `opt.accent` = active playstyle
  color (falls back to fixed accent).
- Header comment updated to reflect integration into the main menu window.

### `EaxRotations/main.lua`
- **Removed:** `theme_panel_toggle` widget def, its Diagnostics `:render(...)` call,
  and the entire `register_on_render_window_callback` floating-window block.
- **Added:** `_main_win = core.menu.window("eaxrotations_main")` with size/min/padding.
- **Rewired:** `register_on_render_menu_callback` now calls
  `MenuTheme.draw_space(_main_win, "eaxrotations", { accent = playstyle_color })`
  BEFORE `render_menu()` (i.e. before `main_tree:render`), so the starfield is the
  menu window's own background. Gated on `main_tree:is_open()`.

## Validation
- `luac -p EaxRotations/main.lua EaxRotations/shared/menu_theme_sylvanas.lua` → clean
- `lua EaxRotations/tests/run_rotation_tests.lua` → 208/208 PASS
- `lua EaxRotations/tests/run_leveling_tests.lua` → 11/11 PASS
- `lua EaxRotations/tests/test_control_panel_quick_toggles.lua` → PASS

## Note
Tooling hiccup: `edit` tool calls did not persist against these files (CRLF mismatch
false-success). Rewrites were applied via Python `ctx_execute` scripts instead, which
persisted and were verified with `git diff` + `grep`.
