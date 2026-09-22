# Mounting, dismounting, and the walk they bracket

How `mount_manager_sylvanas.lua` decides to mount, why the walk is **held** for the cast, where
the player is put back on foot, and how the mount-item list is generated.

## The one fact everything follows from

**A mount is a 1.5s cast, and movement cancels the cast.**

So mounting is not something to *attempt* while travelling. The first version of this module ran
its attempt from the per-tick update — the tick where the nav client is already walking the
player — and the cast died a few frames in, every time. The bag scan ran, the cast was issued,
the log line printed, and the player still travelled on foot. That is what "it doesn't auto
mount" was.

The attempt therefore belongs **before the walk is issued**, while the player is still standing
still, and the walk has to wait for it. `M.begin_travel(me, dest, now)` is that gate:

| Call | Meaning |
|---|---|
| `true` | A cast is in flight — the caller must **not** start walking this tick |
| `false, nil` | Walking is fine **and the player is mounted** |
| `false, why` | Walking on foot: the reason, so the field log can name it (`NAV: travelling on foot — too close`) |

`nav_state` consults it in the single place that issues a walk, so **every** IDLE branch that
returns `NAV` is covered (waypoint, objective-first, area-approach, flight master, innkeeper),
not just the one branch that used to call `try_mount` itself.

The hold is bounded, so it can never become a stall or a loop:

- the cast window is `MOUNT_CAST_TIMEOUT` (2.0s) — past it the attempt is written off and the
  walk starts on foot;
- a written-off attempt backs off for `MOUNT_FAIL_COOLDOWN` (20s);
- finding *no* mount source at all backs off for `NO_MOUNT_COOLDOWN` (60s), so the five bag reads
  do not happen on every long walk.

## Where the mount comes from

Two sources, in this order:

1. **The client's mount list** — `core.spell_book.get_mount_count()` / `get_mount_info(i)`, cast
   with `core.input.mount(i)` (`.api/core.lua:2492`, `:3008-3025`). The mount list is read through
   `core.spell_book` at call time rather than cached at load, because using a carried mount item
   **learns** the mount and the list changes under us mid-session.
2. **A mount item in the bags** — because a mount you are *carrying* is not learned yet, so it is
   invisible to the list, and the player holding reins would never mount. The bags are read with
   `core.inventory.get_items_in_bag(bag)` for bag ids 0..4 (bag 0 is the container read that
   covers the backpack *and* worn gear — see `.api/core.lua:889-966`), and each item is judged by
   the **client first**: `core.quests.get_item_info(id)` answers `item_sub_type`/`class_id`/
   `subclass_id` (`.api/core.lua:4655-4676`), so "Mount" (or class 15 subclass 5) is the client's
   own verdict. The generated table below is the backstop for a build where that call is missing.
   A carried mount is used with `core.input.use_item(id)`, which both summons and teaches it, so
   one use is enough and the spell path takes over afterwards.

An item the client refuses is remembered for the session (`_dead_items`) so the same dead item is
not offered again; a mount spell the client refuses drops the cached index so the list is re-read.

## Where the player is put back on foot

A mounted player cannot cast, so the rotation is dead until the dismount. The sites:

| Site | Why |
|---|---|
| `nav_state` travelling tick | within 15yd of the destination — arrive on foot |
| `nav_state` stand-off stop | a ranged engagement stops 28yd out, far beyond the tick dismount, so this path is the only one that can do it |
| `nav_state` arrival / target-gone / arrival-flagged-far | the end of the walk, whatever ended it |
| `coordinator` combat entry | the fight is starting; **this used to be `if nav.dismount then nav.dismount() end`** — `navigation_sylvanas` has no `dismount` member, so the field was always nil and the guard turned a missing member into a silent no-op |
| `coordinator.stop_navigation` | plugin disabled or hard stop |

## The gate: every way a mount cast is wasted

A cast costs 1.5s, a 2s hold while it lands, and the dismount at the far end. Everything that
kills or wastes it is answered **before** the cast, in `mount_allowed` — one place, so a
travelling tick and a one-shot attempt cannot drift apart:

| Check | Read | Why it exists |
|---|---|---|
| already mounted | `me:is_mounted()`, then the client's list (`is_active`) | nothing to do |
| in combat | `me:is_in_combat()` | the client refuses a mount in combat |
| indoors | `me:is_indoors()` | the client refuses a mount inside — the hold would be pure loss |
| dead or ghost | `me:is_dead()`, `me:is_ghost()` | the corpse run is not a travel, and the attempt used to arm a 20s failure cooldown the resurrected player then waited out |
| **moving** | `me:get_movement_speed() > 0.1` | movement cancels the cast. This is the state right after a gather or a knockback, where the client still has the player under way and the cast dies a few frames in |
| **mid-cast / mid-channel** | `me:is_casting_spell()`, `me:is_channelling_spell()` | a loot, gather or fishing cast owns the player; the walk issued behind it is exactly when the bot tries to mount |
| too close | destination under `MOUNT_DISTANCE_SQ`, or unmeasurable (no destination, or the position read failed) | a 50yd walk is ~6s on foot, ~3s ridden: not worth a 3.5s interruption, and the bracket where mounting **churns** (mount, ride 40yd, dismount, mount again) |
| **just dismounted** | `_dismounted_at` within `REMOUNT_GUARD` (8s) | turning a quest in and walking to the next camp is the churn pattern above, one arrival at a time |
| last attempt failed | `_fail_until` (20s) | a refused or interrupted cast is not retried immediately |
| throttled | `_last_mount_attempt` (3s) | no double-cast |

`MOUNT_DISTANCE_SQ` is **80yd** (6400). It was 50yd, which put the floor below where a mount
pays for itself on a single leg and inside the churn bracket; 80yd is the first length where the
cast wins outright. A walk that cannot be measured — no destination passed, or the position read
failed — stays on foot: not mounting costs the walk, mounting badly costs the cast, the hold and
the dismount.

Every probe is a `pcall`'d read that answers "fine" on a build without the call, so a missing API
costs a wasted cast at worst, never a blocked one. The probe names are the documented
`game_object` members (`is_casting_spell`, not the izi_sdk `is_casting` convenience) — a probe that
only answers in the test mock would make the check a never-lane, and mutant M9 exists to catch
exactly that.

Two things happen to a cast that dies anyway (the player moved, a fight started): it is written
off **at once** rather than holding the walk to the end of the cast window, and the fail cooldown
starts from that moment. And the gate's answer is published (`M.why_not()`), which is what makes
"walked 300 yards on foot" diagnosable instead of just disappointing.

Mounted state is read from `me:is_mounted()` (`.api/game_object.lua` — "Returns whether the game
object is mounted"), with the client's mount list as a second opinion (`is_active`) so a build
whose unit flag never answers cannot hold every long walk and then dismount nothing.

## The mount-item list

`shared/mount_items_sylvanas.lua` — 218 ids — is **generated**, never hand-edited:

```
python3 EaxAutoQuester/tools/generate_mount_items.py           # regenerate
python3 EaxAutoQuester/tools/generate_mount_items.py --check   # drift gate
```

Source is `PublicGithubs/tbc/assets/item_data/all_item_tooltips.csv` (tbc.wowhead.com tooltip
answers). The rule is "tooltip says *Summons and dismisses*" **or** "item type line is *Mount*",
minus anything named deprecated / deptecated / test / `[DNT]`. The second half matters: the AQ40
counting crystals and the event brooms carry the type line *without* the use line, and a table
built on the use line alone (206 ids, the first version) missed all of them plus the X-51
rockets and the Brutal Nether Drake.

`wowheadScrape/dbc_extract/wowsims.db` was checked and **cannot** answer this question for the
era: its `ItemEffect` table has no rows for classic/TBC mount items — every aura-78 item it knows
is a modern id above 97000.

## What the suites pin

`tests/test_mount_manager.lua` — 34 scenarios: `S1-S15` the raw calls, the bag judgement order
(client outranks the table), and the generated table's rule coverage; `H1-H8` the real behaviour
(begin_travel mounts and holds, the hold releases when mounted, a failed cast is bounded then
backed off then retried, no source means no hold and no bag rescan, indoors and short walks are
left alone, `dismount_now`, and the mount-list fallback for mounted state); `H9-H15` the gate
itself, each with its own control — a walking player is refused and the same scene standing still
mounts (H9), mid-cast and mid-channel are refused (H10), dead and ghost are refused (H11), the
8s churn guard refuses straight after a dismount and permits after it (H12), an interrupted cast
releases at once while an unattended one expires at the cast window (H13), the reason is published
for a walking player and withheld for a mounted one (H14), and the floor is pinned from both sides
— 79yd walks, 81yd mounts, an unmeasurable destination stays on foot (H15).

`tests/test_nav_state.lua` — `N12` the walk is held for the cast and issued once mounted;
`N13` the stand-off stop and the arrival both leave the player on foot, and a long walk does not
dismount. `tests/test_coordinator.lua` — `S13` combat entry and the hard stop dismount.

Six mutants were run against these suites in the original pass, each reverted one at a time and
each killed by its own assertions: dropping the hold, restoring the per-tick mount, removing the
nav gate, removing the stand-off dismount, restoring the nil `nav.dismount` guard, and rebuilding
the mount list on the use-line rule alone.

**Twelve more cover the gate** (`docs/`-external harness, module restored byte-identically after
every run), each killed by its own scenario: the moving check, the casting check, the dead/ghost
check, the ghost half of it, the churn guard, the interrupted write-off, the 80yd floor, the
unmeasurable-destination rule, the probe name (reading the never-lane `is_casting`), the movement
threshold, `begin_travel` withholding the reason, and reporting a mounted player as walking.

## Not confirmable without the client

Whether the client accepts a mount cast issued from a standstill on the tick before a walk is
issued — that is the whole premise of the hold, and it is the same in-game signal as before:
`Mounting up (mount #1)`, then `Mounted — starting the walk`. A gate refusal now shows up as
`NAV: travelling on foot — <reason>` on the walk being issued, which names which check answered no.
