# EAXFishing v2.4.0 → v2.4.1 Release Notes

**Date**: 2026-07-05
**Version**: 2.4.1
**Tests**: 8 suites / 150+ assertions (was 4 / 145)
**Code**: 6,500+ lines across 20 modules (was 5,000 / 16)
**Menu options**: 66 (was 38)
**HUD rows**: 31 (was 20)

---

## What's New

### v2.4.1 — Quality of Life

#### Sound Alerts System
A complete audio feedback system with 8 configurable per-event sounds:

| Event | Sound | Default |
|-------|-------|---------|
| Rare catch | Quest Complete fanfare | ON |
| Bags full | PvP warning | ON |
| Pool depleted | Trade window close | OFF |
| Lure expiring | Soft chime | ON |
| Whisper | Whisper notification | ON |
| Disconnect | Error buzzer | ON |
| Catch | Soft splash | OFF |

Master toggle (`sound_alerts_enabled`) silences everything when off. Each event has its own toggle so users can customize which sounds they hear.

#### Lure Expiration Timer
- HUD now shows remaining lure time in `Xm Ys` format
- Turns gray in the last 60 seconds (configurable)
- Plays a warning sound at the configured threshold
- Warning flag resets when a new lure is applied

#### Catch Streak Tracker
- Shows current consecutive catch streak + best streak in HUD
- Resets on miss, escape, or deliberate miss
- Gamification element for long sessions

#### Coordinate Display
- Shows current X, Y position in HUD
- Useful for spot-sharing and navigation

#### Low HP Auto-Pause
- Pauses fishing when HP drops below configurable threshold (default 20%)
- Prevents fishing while dying
- Status shows "Low HP — paused"

#### Menu Reorganization
- 66 menu options grouped into 7 collapsible tree sections:
  - Gear & Lures
  - Timing & Humanizer
  - Pool Routing
  - Automation (v2.4.0)
  - Sound Alerts (v2.4.1)
  - Stealth
  - Visuals & HUD
- Users can collapse sections they don't need

#### New Test Suites (4 added)
- `test_containers.lua` — 15 assertions
- `test_mr_pinchy.lua` — 10 assertions
- `test_quest_tracker.lua` — 19 assertions
- `test_sound_manager.lua` — 10 assertions

---

### v2.4.0 — 12 New Features

#### Auto-Open Containers
Opens clams, chests, and supply crates between casts to free bag space. Detects known TBC container items by ID and opens them one at a time (throttled 1.5s). Guards against casting, channeling, and moving.

#### Mr. Pinchy Handler
Detects Mr. Pinchy (item 27436, ultra-rare TBC catch from Highland Muddy Water pools) in bags and auto-uses its 3 charges. Triggers rare alert on each use. Never fires in combat.

#### Auto-Sell Junk
Sells gray-quality items when a vendor window is open. Uses `can_repair()` as vendor-open proxy. Only sells quality=1 items. Throttled (5s). Opt-in (default OFF).

#### Auto-Delete Worthless
Deletes gray items with no vendor value when bags are full. Only fires when `Bags.is_bags_full()` returns true. Deletes one at a time, throttled (2s). Destructive — opt-in (default OFF).

#### Pool Depletion Detection
Tracks GUID of current pool, counts casts vs catches. If casts ≥ threshold (default 5) with 0 catches, skips pool and moves to next. Prevents wasting casts on fished-out pools.

#### Cast Reliability Telemetry
Tracks success_count, fail_count, fail_streak. Shows cast success rate in HUD (green if ≥80%, gray otherwise).

#### Daily Quest Tracker
Detects TBC fishing daily quest items in bags (7 quest fish). When detected, pools that drop quest fish get 10x distance bonus in pool selection — quest pools preferred over closer non-quest pools. Passive detection (throttled 10s, read-only).

#### Whisper Responder
Detects CHAT_MSG_WHISPER events (when API supports them). Logs sender + message, triggers alert overlay + sound. Throttled per-sender (30s). Detection-only (Sylvanas has no SendChatMessage yet).

#### Auto-Hearth When Bags Full
Uses Hearthstone (item 6948, spell 8690) to teleport to inn when bags full. Saves return position for auto-return after vendoring. Waits 12s for hearth cast, then navigates back. Opt-in (default OFF).

#### Auto-Relog (Detection)
Detects server disconnect via nav client `is_server_available()`. Alerts user with overlay + sound. Throttled (5s), clears when connection restored. Detection-only (no relog API from Lua).

#### Time/Weather Awareness
Framework for time-of-day fishing window scheduling. Uses `core.game_time()` as proxy (WoW clock API not exposed yet). Placeholder always returns in_window=true until API available.

#### Session Resilience Summary
All three session-extending features (auto-delete, auto-sell, auto-hearth) are tried in sequence before the bag-full hard stop, extending unattended sessions from ~30 min to potentially hours.

---

### v2.3.2 — Cast Jitter Fix

The cast jitter feature was treating the slider value as **yards of position offset** instead of **degrees of angle**. At slider=30, it picked a random point up to 30 yards away in any direction — 50% of which pointed at the beach, swinging the player all the way around.

**Fix**: Now applies a proper angular offset (±jitter_deg) to the current yaw, then projects 15 yards forward along the new facing. The bobber always goes forward (into the water) with only a small spread.

Added `APISurface.get_rotation()` wrapper (pcall-guarded) to read the player's yaw.

---

### v2.3.1 — Lure Stack HUD + Pool Safety

#### Lure Stack HUD
`find_best_lure()` now returns stack count as 4th return value. `get_total_lure_count()` helper added. Engine tracks `lure_count` in `session.stats` during lure checks. HUD shows "Lures: N" when >0.

#### Bounding-Radius Pool Safety
`build_standoff_point()` now uses `pool:get_bounding_radius()` (when available) to compute a safety margin of `br + 2 yards` (minimum 3 yards). Prevents pathing into the pool itself. Falls back to 3 yards when API unavailable.

#### Lure Re-Check
Defensive `has_active_lure()` re-check inside `try_apply_lure()` before consuming the item. Prevents duplicate lure consumption if `item_has_enchant()` gave a false negative earlier in the tick.

#### Cook While Moving Guard
Added `is_moving` guard to `Cook.can_cook_here()` — cooking requires a stationary cast.

---

## Engine Priority Chain (v2.4.1)

```
Hard stop → Hearth return → Disconnect check → Conditions → QoL pause →
Enable check → Anti-AFK → FAST PATH (bite detection) → Throttle →
Player check → Low HP pause → Navigation → Bag full
  (auto-delete → auto-sell → auto-hearth → hard stop) →
Combat → Pole equip → Pole upgrade → next_cast_time →
Loot → Containers → Mr. Pinchy → Cook → Lure (+expiry warning) →
Micro-break → Quest update → Pool nav (quest-weighted + depletion) →
CAST (with telemetry + catch streak + sound)
```

---

## Commits (this session)

| Commit | Description |
|--------|-------------|
| `cc59d5fc` | v2.3.1 — lure stack HUD + bounding-radius pool safety |
| `ea2ae1e7` | v2.3.2 — cast jitter fix (yards → degrees) |
| `d91c9dec` | v2.4.0 #1 — auto-open containers + Mr. Pinchy |
| `478dd4ab` | v2.4.0 #2 — auto-sell junk + auto-delete worthless |
| `5f348c17` | v2.4.0 #3 — pool depletion + cast telemetry |
| `7d838338` | v2.4.0 #4 — daily quest tracker + fish targeting |
| `3d1b3da8` | v2.4.0 #5 — whisper responder + auto-hearth |
| `4f29f9af` | v2.4.0 #6 — auto-relog + time/weather awareness |
| `aee67004` | v2.4.1 — sound alerts, lure timer, streak, coords, low-HP pause |
| (this) | v2.4.1 — menu reorg, README, tests, changelog |
