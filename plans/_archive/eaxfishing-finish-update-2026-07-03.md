# Plan: Finish and Update EAXFishing

**Goal:** Port all bug fixes and improvements from `EaxFishing_v2_0_1/` (gitignored) into the tracked `EAXFishing/` directory, bump version to 2.1.0, validate, and commit.

## Differences to Port

### 1. `core/behavior.lua`
- `scaled_delay` — add `config` param, implement ultra_safe_mode override (max delay, 2x scale)
- `apply_random_wait` — implement ultra_safe_mode override in delay calculation

### 2. `fishing/engine.lua`
- Anti-AFK jump guard — only jump when NOT `awaiting_bobber`
- Re-cast timeout — `elapsed > 2.0` → `elapsed > 7.0`
- `math.floor` around `math.random` break interval args
- `no_lure_warned` reset when lure becomes active again
- Lure check — remove `has_main_hand_enchant()` call, pass `now` to `has_active_lure`
- Pass `deps.config` to `Behavior.scaled_delay` calls

### 3. `fishing/lures.lua`
- Rewrite `has_active_lure` — primary detection via `item_has_enchant` method call + `get_equipped_items` fallback + assumed_expire_time fallback
- Remove `has_main_hand_enchant` function (no longer needed)

### 4. Version bump
- `header.lua`: 2.0.0 → 2.1.0
- `main.lua`: 2.0.0 → 2.1.0
- `config.lua`: 2.0.0 → 2.1.0
- `ui/menu.lua`: 2.0.0 → 2.1.0

## Validation
- `luac -p` on every EAXFishing .lua file
- `git add EAXFishing/` and atomic commit
