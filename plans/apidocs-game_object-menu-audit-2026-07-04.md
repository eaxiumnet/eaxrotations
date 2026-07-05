# Plan: Audit `game_object.lua` & `menu.lua` Against Rescraped apidocs

**Date:** 2026-07-04  
**Scope:** `.api/game_object.lua` (18.0 KB) + `.api/menu.lua` (26.6 KB) vs `apidocs/pages/dev/api/game-object.md` + `apidocs/pages/dev/api/ui.md`  
**Goal:** Identify every API surface our EAX projects are under-utilizing, and produce a ranked backlog.

---

## Part 1 — game_object.lua Audit

### 1.1 Baseline: What .api/game_object.lua Already Exposes

The `.api` stub defines **~85 methods** on `game_object` plus **9 supporting classes** (`threat_table`, `buff`, `loss_of_control_info`, `item_slot_info`, `unit_ranged_damage_data`, `nameplate_info`, `buff_manager_data`, `buff_table`, `item_slot_info_table`).

**Categories:**
- Validation & type: `is_valid`, `is_visible`, `get_type`, `get_object_type_string`, `is_basic_object`, `is_player`, `is_unit`, `is_pet`, `is_minion`, `is_boss`, `is_quest_unit`, `is_item`, `is_item_bag`
- Identification: `get_class`, `get_specialization_id`, `get_npc_id`, `get_item_id`, `get_level`, `get_effective_level`, `get_gold`, `get_faction_id`, `get_target_marker_index`, `set_target_marker_index`, `get_race_id`, `get_creature_type`, `get_classification`, `get_group_role`, `get_guid`, `get_name`
- State: `is_dead`, `is_ghost`, `is_feign_death`, `is_mounted`, `is_outdoors`, `is_indoors`, `is_glow`, `set_glow`, `is_in_combat`, `is_moving`, `is_dashing`, `is_flying`, `is_auto_attacking`, `get_state_flags`, `is_tap_denied`
- Position & movement: `get_position`, `get_rotation`, `get_direction`, `get_movement_direction`, `get_movement_speed`, `get_movement_speed_max`, `get_swim_speed_max`, `get_flight_speed_max`, `get_glide_speed`, `get_bounding_radius`, `get_combat_reach`, `get_height`, `get_scale`, `get_unit_phase`
- Casting: `is_casting_spell`, `get_active_spell_id`, `get_active_spell_cast_start/end_time`, `is_active_spell_interruptable`, `is_channelling_spell`, `get_active_channel_spell_id`, `get_active_channel_cast_start/end_time`, `get_active_spell_target`, `get_empower_current_stage`, `get_empower_max_stage`, `get_empower_stage_duration`
- Combat & threat: `can_attack`, `is_enemy_with`, `is_friend_with`, `get_threat_situation`, `get_attack_speed`, `get_unit_ranged_damage`, `get_armor`, `get_spell_haste`
- Auras: `get_auras`, `get_buffs`, `get_debuffs`, `get_buff_data`, `get_debuff_data`, `get_aura_data`
- Items & inventory: `get_item_cooldown`, `has_item`, `get_item_stack_count`, `get_equipped_items`, `get_item_at_inventory_slot`, `item_has_enchant`, `item_enchant_expiration`, `item_enchant_charges`, `item_enchant_id`
- Loot & interaction: `can_be_looted`, `has_loot`, `can_be_used`, `can_be_skinned`, `has_skin`, `does_bobber_have_fish`
- Relationships: `get_owner`, `get_pet`, `get_target`, `get_creator_object`, `get_combo_points_target`, `is_party_member`
- Health & power: `get_health`, `get_max_health`, `get_max_health_modifier`, `get_power`, `get_max_power`, `get_xp`, `get_max_xp`, `get_total_shield`, `get_incoming_heals`, `get_incoming_heals_from`, `get_total_heal_absorbs`
- Loss of control: `get_loss_of_control_info`
- Nameplate & attachments: `get_nameplate`, `get_attachment_name_position`, `get_attachment_position`

### 1.2 What the Rescraped apidocs Clarify or Add

The docs do **not** add new methods** that `.api` lacks**, but they provide:

| Discovery | Impact |
|-----------|--------|
| **Complete `buff` struct table** with `points` field documented as "variable values from aura data (e.g. absorb remaining for shields)" | Confirms our `buff_points` / `debuff_points` usage in `core_sylvanas.lua` is backed by the raw `points` array. |
| **`get_guid()` example** pairing with `core.object_manager.get_object_from_guid` | Confirms GUID persistence pattern we already use in `targeting_sylvanas.lua` and `combat_log_parser_sylvanas.lua`. |
| **`get_nameplate()` returns screen-space rect** (bottom-left origin, scaled pixels) | **New clarity** — we were not using this anywhere. Enables nameplate-attached 2D overlays without 3D→2D projection math. |
| **`get_attachment_name_position()`** = top-of-head anchor | **New clarity** — better than `get_position()` + height offset for 3D text/icons. |
| **`get_attachment_position(attachment_id)`** = arbitrary model bones | **New clarity** — could draw spell-effect overlays on hands, chest, etc. |
| **`get_creature_type()` enum table** fully spelled out (1=Beast … 15=Aberration) | We use `get_creature_type` in `EaxAutoQuester` and `EaxRotations` (undead check for Exorcism). Docs confirm values. |
| **`get_classification()` enum** (-1 unknown … 6 minus) | Useful for elite/rare detection in quest/grind logic. |
| **`get_group_role()` enum** (-1 NONE, 0 TANK, 1 HEALER, 2 DAMAGER) | Could replace heuristics in `EaxRotations` party healing. |
| **`get_unit_phase()` enum** (-1 same phase, 0 phasing, 1 sharding, 2 warmode, 3 chromie, 4 timerunning) | **Completely new to us** — EaxAutoQuester could use this to skip phased quest NPCs. |
| **`get_state_flags()`** documented as "raw bitfield" | Confirms opaque integer; no bit masks documented. |
| **`get_total_heal_absorbs()`** defined as "healing that cannot land until absorb removed" | Clarifies distinction from `get_total_shield`. Useful for healing specs. |
| **`is_tap_denied()`** = grey healthbar | Confirms our tap-denied logic in `EaxAutoQuester` is correct. |
| **`does_bobber_have_fish()`** on game_object | Confirms bobber object has this method; EaxFishing uses `fish_helper` abstraction instead. |

### 1.3 game_object — Per-Project Impact Matrix

| Method / Feature | EaxRotations | EaxESP | EaxAutoQuester | EaxProfession | EaxFishing |
|------------------|:----------:|:------:|:--------------:|:-------------:|:--------:|
| `get_nameplate()` | 🟡 | 🔴 | ⚪ | ⚪ | ⚪ |
| `get_attachment_name_position()` | 🟡 | 🔴 | ⚪ | ⚪ | ⚪ |
| `get_attachment_position(id)` | 🟡 | 🔴 | ⚪ | ⚪ | ⚪ |
| `get_unit_phase()` | ⚪ | ⚪ | 🔴 | ⚪ | ⚪ |
| `get_group_role()` | 🟡 | ⚪ | ⚪ | ⚪ | ⚪ |
| `get_total_heal_absorbs()` | 🟡 | ⚪ | ⚪ | ⚪ | ⚪ |
| `get_loss_of_control_info()` | 🟡 | ⚪ | ⚪ | ⚪ | ⚪ |
| `get_spell_haste()` | 🟡 | ⚪ | ⚪ | ⚪ | ⚪ |
| `get_unit_ranged_damage()` | 🟡 | ⚪ | ⚪ | ⚪ | ⚪ |
| `is_auto_attacking()` | 🟢 (1 use) | ⚪ | ⚪ | ⚪ | ⚪ |
| `get_guid()` | 🟢 (11 files) | ⚪ | 🟢 (4 files) | ⚪ | ⚪ |
| `get_incoming_heals()` | 🟢 (2 files) | ⚪ | ⚪ | ⚪ | ⚪ |
| `can_be_used()` | ⚪ | ⚪ | 🟢 (1 use) | ⚪ | ⚪ |
| `item_enchant_*` | 🟡 | ⚪ | ⚪ | ⚪ | ⚪ |
| `can_be_skinned()` / `has_skin()` | ⚪ | ⚪ | 🟡 | ⚪ | ⚪ |

**Legend:** 🔴 = High opportunity (not used, high value) | 🟡 = Medium (could improve existing logic) | 🟢 = Already used | ⚪ = Not applicable

---

## Part 2 — menu.lua Audit

### 2.1 Baseline: What .api/menu.lua Already Exposes

The `.api` stub defines **~12 widget types** plus the `window` class with **~80 methods**.

**Widgets:** `tree_node`, `checkbox`, `key_checkbox`, `slider_int`, `slider_float`, `combobox`, `combobox_reorderable`, `combobox_reorderable_ow`, `keybind`, `button`, `text_input`, `color_picker`, `header`, `window`

**Key widget methods we already know:**
- `tree_node`: `render`, `is_open`, `set_open_state`, `just_issued_state_change`
- `checkbox`: `render`, `get_state`, `set`, `get_default`, `get_label`
- `slider_int/float`: `render`, `get`, `set`, `get_default`, `get_label`
- `combobox`: `render`, `get`, `set`, `set_items`, `get_items`, `set_draggable_state`, `is_showing_on_control_panel`
- `keybind`: `render`, `get_state`, `get_key_code`, `set_key`, `set_toggle_state`, `set_forced_state`, `stop_forcing_state`, `get_forced_state`, `set_draggable_state`
- `button`: `render`, `is_clicked`
- `text_input`: `render`, `render_custom`, `get_text`, `get_text_as_number`, `set`, `set_buffer`, `is_reading_input`, `copy_to_clipboard`
- `color_picker`: `render`, `get`, `set`, `get_default`
- `key_checkbox`: `render`, `get_main_checkbox_state`, `get_key_code`, `get_keybind_state`, `set_toggle_state`, `set_key`, `set_mode`, `get_mode`, `set_keybind_forced_state`, `stop_forcing_keybind_state`
- `header`: `render`

**Window methods we already know (selected):**
- Sizing/position: `set_initial_size`, `set_initial_position`, `force_window_size`, `get_size`, `get_position`, `get_available_region`, `get_min_size`
- Layout: `set_next_widget_width`, `set_next_window_padding`, `set_next_window_items_spacing`, `set_next_window_items_inner_spacing`, `center_text`, `get_text_size`, `get_wrapped_text_size`, `get_text_centered_x_pos`, `draw_next_dynamic_widget_on_new_line`, `draw_next_dynamic_widget_on_same_line`, `add_text_on_dynamic_pos`, `add_separator`
- Input: `get_mouse_pos`, `get_mouse_pos_local`, `is_mouse_button_pressed`, `is_mouse_button_clicked`, `is_rect_clicked`, `is_rect_pressed`, `is_rect_double_clicked`, `is_mouse_hovering_rect`, `is_mouse_hovering_rect_block_movement`, `is_window_clicked`, `is_window_hovered`, `is_window_double_clicked`, `is_window_focused`, `is_any_item_active`, `set_focus`
- Tooltip: `render_tooltip_default`, `render_tooltip_text_only`, `render_tooltip_custom`
- Drawing primitives: `render_text`, `render_text_custom_size`, `render_text_wrapped`, `render_rect`, `render_rect_filled`, `render_rect_filled_multicolor`, `render_smooth_rect`, `render_drop_shadow`, `render_border_rect`, `render_linear_gradient`, `render_keybind_pill`, `render_dropdown_field`, `render_section_header`, `render_slider_track`, `render_hover_pill`, `render_circle_percentage`, `render_circle`, `render_circle_filled`, `render_bezier_quadratic`, `render_bezier_cubic`, `render_triangle`, `render_triangle_filled`, `render_triangle_filled_multi_color`, `render_line`, `render_polyline`, `render_gif`
- Clipping: `push_clip_rect`, `pop_clip_rect`
- Font: `push_font`, `pop_font`
- Popup: `begin_popup`
- Navbar: `begin_navbar`, `begin_navbar_at`, `begin_content_area`
- Animation: `animate_widget`, `make_loading_circle_animation`
- Clipboard: `copy_to_clipboard`, `get_clipboard_text`
- Misc: `set_id`, `set_render_layer`, `get_close_cross_bounds`, `block_input_capture`, `begin_window_sub_context`, `begin_group`, `allocate_space`

### 2.2 What the Rescraped apidocs Clarify or Add

Again, **no new methods** vs `.api`, but major behavioral clarifications:

| Discovery | Impact |
|-----------|--------|
| **`tree_node:render()` callback approach** with full anonymous-function example | Confirms our menu pattern in `main_sylvanas.lua`; no change needed. |
| **Checkbox `render` supports `\n` for multi-line labels** | Minor UX improvement available. |
| **`combobox:set_items(items)`** + **`get_items()`** documented with 64-entry max | We use `set_items` in **1 file** (`EaxRotations`). Could be used more broadly for dynamic option lists. |
| **`key_checkbox` full visual explanation** (hold/toggle/always modes) | **New clarity** — no EAX project uses `key_checkbox`. Could replace manual "checkbox + keybind" pairs in EaxRotations settings. |
| **`text_input:set_buffer(text)`** + **`is_reading_input()`** + **`copy_to_clipboard()`** | `EaxProfession` uses `text_input`. `set_buffer` could pre-fill profession names; `is_reading_input` could pause crafting while typing. |
| **`window:begin_popup()`** signature fully documented | No EAX project uses popups. Could add confirmation dialogs for destructive actions (e.g., EaxAutoQuester "abandon all quests"). |
| **`window:animate_widget()`** + **`make_loading_circle_animation()`** | No EAX project uses animations. Could add loading spinners during long operations (profession crafting batch, quest data load). |
| **`window:render_gif()`** | Novelty — could add animated icons to custom UI panels. |
| **`window:render_circle_percentage()`** | Perfect for cooldown/rage/mana radial indicators in custom HUDs. EaxRotations currently has no radial HUD. |
| **`window:push_font()` / `pop_font()`** | No EAX project uses custom fonts. Could improve readability of large overlay text. |
| **`window:set_render_layer()`** | Could fix z-order issues if EaxESP and EaxRotations draw on same callback. |
| **`window:block_input_capture()`** | Useful for click-through overlay windows (EaxESP). |
| **Menu elements can ONLY render in `register_on_render_menu_callback` OR `register_on_render_window_callback`** | Strict rule we already follow, but good enforcement reminder. |
| **`header` can be declared INSIDE render callback** (lightweight, no ID) | We already do this in some places. Confirms safe. |

### 2.3 menu.lua — Per-Project Impact Matrix

| Widget / Feature | EaxRotations | EaxESP | EaxAutoQuester | EaxProfession | EaxFishing |
|------------------|:----------:|:------:|:--------------:|:-------------:|:--------:|
| `key_checkbox` | 🔴 | ⚪ | ⚪ | ⚪ | ⚪ |
| `text_input:set_buffer` | ⚪ | ⚪ | ⚪ | 🟡 | ⚪ |
| `text_input:is_reading_input` | ⚪ | ⚪ | ⚪ | 🟡 | ⚪ |
| `combobox:set_items` | 🟢 (1 use) | ⚪ | ⚪ | ⚪ | ⚪ |
| `window:render_circle_percentage` | 🔴 | ⚪ | ⚪ | ⚪ | ⚪ |
| `window:animate_widget` | 🟡 | ⚪ | ⚪ | 🟡 | ⚪ |
| `window:begin_popup` | ⚪ | ⚪ | 🟡 | 🟡 | ⚪ |
| `window:block_input_capture` | ⚪ | 🔴 | ⚪ | ⚪ | ⚪ |
| `window:set_render_layer` | ⚪ | 🔴 | ⚪ | ⚪ | ⚪ |
| `window:render_gif` | 🟡 | 🟡 | ⚪ | ⚪ | ⚪ |
| `window:push_font` | 🟡 | 🟡 | ⚪ | ⚪ | ⚪ |
| `window:render_drop_shadow` | 🟡 | 🔴 | ⚪ | ⚪ | ⚪ |
| `window:render_gradient` | 🟡 | 🔴 | ⚪ | ⚪ | ⚪ |
| `window:copy_to_clipboard` | ⚪ | ⚪ | ⚪ | 🟡 | ⚪ |
| `button` | 🟢 (1 use) | ⚪ | ⚪ | ⚪ | ⚪ |
| `color_picker` | 🔴 | ⚪ | ⚪ | ⚪ | ⚪ |

---

## Part 3 — Consolidated Action Backlog (Ranked)

### 🔴 High-Value / Low-Effort (Do First)

1. **EaxRotations: Add `get_nameplate()` overlay support to cast_bar_overlay**
   - File: `shared/cast_bar_overlay_sylvanas.lua`
   - Currently uses manual 3D→2D projection for overlay positioning. `target:get_nameplate()` would give exact screen rect for nameplate-attached bars, eliminating drift.
   - Effort: Small. Fallback to existing projection if `get_nameplate()` returns nil.

2. **EaxRotations: Replace manual "checkbox + keybind" pairs with `key_checkbox`**
   - Files: Any spec with a toggle+keybind combo (e.g., potion usage, burst mode)
   - `key_checkbox` gives hold/toggle/always mode for free, reducing menu clutter.
   - Effort: Medium (refactor menu definitions, update setting reads).

3. **EaxAutoQuester: Add `get_unit_phase()` guard to quest NPC targeting**
   - File: `quest_state/` or interaction logic
   - Skip NPCs that are in a different phase/shard/warmode.
   - Effort: Small.

4. **EaxESP: Use `window:block_input_capture()` and `window:set_render_layer()`**
   - Fixes click-through and z-order issues with ESP overlay windows.
   - Effort: Small.

### 🟡 Medium-Value / Medium-Effort

5. **EaxRotations: Use `get_attachment_name_position()` for 3D status text**
   - More accurate than `get_position() + height_offset` for overhead text.
   - Effort: Small; refactor `graphics.text_3d` calls.

6. **EaxRotations: Use `get_group_role()` for party healing target priority**
   - Files: `healing_sylvanas.lua`, `discipline_sylvanas.lua`
   - Replace health-percentage heuristics with role-aware priority (tank > healer > dps).
   - Effort: Medium (update `build_state()` party scan).

7. **EaxRotations: Use `get_total_heal_absorbs()` in healing specs**
   - Distinguish heal-absorb (e.g., Mortal Strike) from shield absorb. Currently may over-heal into absorb.
   - Effort: Small.

8. **EaxRotations: Add `get_spell_haste()` to state for haste-aware DoT clipping**
   - Files: `shadow_sylvanas.lua`, `affliction_sylvanas.lua`
   - Adjust refresh thresholds based on current haste instead of static timers.
   - Effort: Medium.

9. **EaxProfession: Use `text_input:set_buffer()` to pre-fill recipe names**
   - Improves UX when searching recipes.
   - Effort: Small.

10. **EaxAutoQuester: Add `window:begin_popup()` confirmation for "Abandon Quest"**
    - Prevents accidental quest abandonment.
    - Effort: Small.

### 🟢 Nice-to-Have / Polish

11. **EaxRotations: `color_picker` for custom UI theme colors**
    - Let users customize overlay colors instead of hard-coding.
    - Effort: Medium.

12. **EaxRotations: `window:render_circle_percentage()` for radial GCD/cooldown indicator**
    - Visual HUD element showing GCD progress as a radial fill.
    - Effort: Medium.

13. **EaxESP: `window:render_drop_shadow()` + `render_gradient()` for panel backgrounds**
    - Modernize ESP panel visuals.
    - Effort: Small.

14. **EaxRotations: `get_unit_ranged_damage()` for hunter stat snapshotting**
    - Could feed into attack-power calculations for trinket procs.
    - Effort: Medium.

15. **All projects: Audit `set_items` usage on comboboxes**
    - Ensure dynamic option lists use the method instead of reconstructing comboboxes.
    - Effort: Small.

---

## Part 4 — Files to Touch (if we act on this plan)

| File | Change |
|------|--------|
| `EaxRotations/shared/cast_bar_overlay_sylvanas.lua` | Add `get_nameplate()` fallback path |
| `EaxRotations/shared/menu_theme_sylvanas.lua` | Add `key_checkbox` support |
| `EaxRotations/shared/spec_kit_sylvanas.lua` | Add `key_checkbox` constructor helper |
| `EaxRotations/classes/priest/healing_sylvanas.lua` | Use `get_group_role()` + `get_total_heal_absorbs()` |
| `EaxRotations/classes/priest/discipline_sylvanas.lua` | Use `get_group_role()` + `get_total_heal_absorbs()` |
| `EaxRotations/classes/priest/shadow_sylvanas.lua` | Use `get_spell_haste()` for DoT logic |
| `EaxRotations/classes/warlock/affliction_sylvanas.lua` | Use `get_spell_haste()` for DoT logic |
| `EaxAutoQuester/quest_state/*.lua` | Add `get_unit_phase()` guard |
| `EaxProfession/ui/*.lua` | Use `text_input:set_buffer()` |
| `EaxESP/core/*.lua` | Use `block_input_capture`, `set_render_layer`, gradient/shadow drawing |

---

## Appendix: API Methods Completely Unused Across All EAX Projects

These are present in `.api` + documented in apidocs, but grep returned **zero hits** across all 5 projects:

**game_object:**
- `get_attachment_position()` (arbitrary bone)
- `get_loss_of_control_info()`
- `get_unit_ranged_damage()`
- `item_enchant_expiration()` / `item_enchant_charges()` / `item_enchant_id()`
- `get_state_flags()`
- `get_creator_object()`
- `get_combo_points_target()`
- `is_dashing()` / `is_flying()` / `get_glide_speed()`
- `get_flight_speed_max()` / `get_swim_speed_max()`
- `get_movement_direction()`
- `get_active_spell_target()`

**menu / window:**
- `key_checkbox` (entire widget type)
- `color_picker` (entire widget type)
- `window:begin_popup()`
- `window:animate_widget()` / `make_loading_circle_animation()`
- `window:render_gif()`
- `window:render_circle_percentage()`
- `window:render_bezier_quadratic()` / `render_bezier_cubic()`
- `window:render_triangle*()`
- `window:render_polyline()`
- `window:render_keybind_pill()` / `render_dropdown_field()` / `render_section_header()` / `render_slider_track()` / `render_hover_pill()`
- `window:begin_navbar()` / `begin_navbar_at()` / `begin_content_area()`
- `window:set_render_layer()`
- `window:block_input_capture()`
- `window:get_clipboard_text()`

---
*End of plan. Ready for implementation picks.*
