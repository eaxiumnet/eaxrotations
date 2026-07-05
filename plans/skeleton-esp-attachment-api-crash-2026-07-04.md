# Skeleton ESP — Debugging Note (2026-07-04)

## Problem
Project Sylvanas added `get_attachment_position` and `get_attachment_name_position` to `game_object`. Attempted to wire them into EaxESP v0.4.3 for:
1. Head-anchored nameplates (replacing `pos.z + 2.0` guesswork)
2. Head-anchored cast bars (replacing `pos.z + 2.5`)
3. Full skeleton ESP (spine + arms + legs via attachment indices)

## Crash History
- **Crash 1**: Looping `get_attachment_position(0..20)` + `get_attachment_name_position("head", "neck", ...)` every 5s with debug log.
  - Note: `get_attachment_name_position` was called with string args, but the correct signature is **zero args** (`()`).
- **Crash 2**: One-shot probe of index 0 + name "head" with `pcall`.
  - Same issue: wrong signature for name_position.
- **Crash 3**: Numeric indices from barker's attachment table (1, 2, 3, 4, 5, 6, 9, 10, 20, 34, 47, 48, 50) via `get_attachment_position(idx)`.
  - **Correct signature used** (`get_attachment_position(me, idx)`), still crashed.

All three crashed despite `pcall` wrapping. `pcall` catches Lua errors, not native access violations (AVs) in the C++ binding.

**Correct signatures (from Sylvanas dev @Voltz [SBTL]):**
- `get_attachment_position(attachment_id: integer) -> vec3`
- `get_attachment_name_position() -> vec3` — **zero arguments**

## Root Cause (Presumed)
The attachment APIs are fresh C++ bindings. Either:
- Some indices are invalid for certain model types (creatures without those bones)
- The binding dereferences a null attachment matrix when an index is unmapped
- `line_3d` + attachment-returned vec3 may have a lifetime/ownership issue

## What Was Reverted (2026-07-04)
All attachment-calling code removed from EaxESP:
- `renderer.lua`: Removed `_use_attachments`, `get_head_position`, `draw_skeleton`, skeleton counters
- `renderer.lua`: Cast bars back to `pos.z + 2.5`
- `renderer.lua`: Nameplates back to `pos.z + 2.0`
- `main.lua`: Attachment enablement logic removed
- `config.lua`: `show_skeleton`, `skeleton_color`, `skeleton_thickness`, `skeleton_max_units` removed
- `menu.lua`: Skeleton ESP checkbox removed
- `compat.lua`: `probe_obj_method_exists` kept (non-calling), attachment probes exist but don't call

## What Was Kept
- `compat.lua`: `get_attachment_position` and `get_attachment_name_position` are probed for **existence only** (no invocation). They show up in the compat summary as present/missing.
- `AGENTS.md`: Rule added — "Edit any file in `api/` or `.api/` — strictly read-only."

## Next Steps (Requires External Input)
1. **Confirm API stability with Sylvanas devs**: Are these APIs safe to call on all unit types? Do invalid indices return nil or crash?
2. **Safe test harness**: A minimal standalone Lua script that calls `get_attachment_position(20)` on the local player, logging the result. Run this in isolation (no ESP, no renderer) to confirm the binding works.
3. **If safe**: Re-introduce skeleton ESP behind a runtime feature flag that is OFF by default and requires explicit user opt-in.
4. **If still unstable**: Document as known limitation; do not ship skeleton ESP until Sylvanas stabilizes the binding.

## Reference
- barker's attachment ID table: indices 0-60 mapped to Shield/Hand/Elbow/Shoulder/etc.
- `EaxESP/compat.lua`: `probe_obj_method_exists` for safe existence checks
- Contract rule: "If a task loops more than 2 attempts, STOP. Write a debugging note in plans/."
