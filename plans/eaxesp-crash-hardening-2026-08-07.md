# EaxESP Crash Hardening — 2026-08-07

## Root Cause
Latest Sylvanas update added new C++ game_object bindings that crash on invocation
even through pcall (same class of bug as attachment APIs). Additionally, stale
object references can return NaN coordinates, which propagate through math and
crash the D3D renderer.

## Files Changed (12)
- header.lua       — pcall-wrapped get_local_player
- main.lua         — NaN/Inf guards on origin refresh + FPS math
- reader.lua       — Disabled crashy v0.4.0 APIs + NaN guards in position/distance
- renderer.lua     — NaN/Inf guards on all graphics inputs + math (alpha, font, brackets, health, cast, aggro)
- radar.lua        — NaN guards on to_vec2 + player_pos validation
- safe_logger.lua  — Eager init on load, trace_call helper, immediate flush
- compat.lua       — No changes (already uses probe_obj_method_exists for new APIs)
- menu.lua         — No changes (already pcall-wrapped)
- projection.lua   — No changes (already pcall-wrapped)
- config.lua       — No changes (pure data)
- attachment_safe.lua — No changes (already disabled)
- diagnostic_api_crash.lua — No changes (diagnostic tool, not runtime)

## Crashy APIs Disabled (reader.lua)
- can_be_looted, has_loot, can_be_skinned
- is_casting_spell, get_active_spell_cast_start_time, get_active_spell_cast_end_time, is_active_spell_interruptable
- is_ghost, is_feign_death
- get_target_marker_index
- can_be_used (on objects)

## NaN/Inf Guard Pattern
`lua
local function is_valid_number(v)
 return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end
`
Applied to: position_of, squared_dist, dist_3d, origin refresh, to_vec3, to_vec2,
norm_color, alpha_multiplier, font_size_for_distance, draw_bracket_3d,
draw_health_bar, draw_cast_bar, draw_aggro_circle, radar_dot, player_pos.

## Validation
All 12 files pass luac -p.