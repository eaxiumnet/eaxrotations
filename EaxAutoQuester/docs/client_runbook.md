# Client runbook: gathering, profiles, and path memory

What to look at in the live client to confirm the four session features behave as documented, and
what each one legitimately looks like when it is *not* doing anything.

Why this exists: all four are client-facing behaviours whose proof is a Lua battery, not an
assertion you can read. A battery can be green while the feature never fires in the game — the
mock can hand back a member the real client does not. This runbook is the in-game half of the
contract. Each section states the exact log line to look for and, just as importantly, what a
correct **no-op** looks like.

## Before you start

| Step | How |
|---|---|
| 1 | Tick **Debug Logging** in the EaxAutoQuester menu. The gathering and sweep lines are `debug_log` and are silent without it. |
| 2 | Open the Sylvanas console/log. The profession diagnostic uses `core.log` and prints **regardless** of the debug setting. |
| 3 | Log in with the character you want to inspect. Profile-scoped features are keyed `name@realm`. |

A useful extra: the **session recorder** captures all of these lines plus structured events as
JSONL. See `docs/session_replay.md`. It is the way to hand a reproduction to a developer without
transcribing a log by hand.

---

## 1. Startup profession diagnostic

**What it is.** When a character profile is *created*, the quester asks the client which professions
that character has and prints one line. It is the fastest way to answer "does it actually see my
professions?".

**Where it appears.** `core.log`, once per newly created character profile. Not gated by Debug
Logging.

**The line looks like this:**

```text
EaxAutoQuester professions [Alice - Ravencrest]: prof1=Herbalism [skill 182] (300), prof2=Alchemie [skill 171] (275), fishing=Fischen [skill 356] (150); gathering: Herbalism, Fishing
```

Read it left to right:

| Part | Meaning |
|---|---|
| `[Alice - Ravencrest]` | the character the profile belongs to |
| `prof1=` / `prof2=` / `fishing=` | the two primary profession slots and Fishing, exactly as the client reports them |
| `Herbalism` | the **localized** name the client returned — this is why it can read `Alchemie` or `Fischen` |
| `[skill 182]` | the **skill-line id** detection actually matched on. This is the part that proves the locale-proof path fired. |
| `(300)` | current skill level |
| `gathering: Herbalism, Fishing` | canonical English names of the routes actually enabled — the only part that changes quester behavior |

**The skill-line ids** are the 2.5.5 client's own, derived from the DBC in this repo
(`SkillLineAbility` rows), not from a wiki:

| Profession | Skill-line id |
|---|---:|
| Herbalism | 182 |
| Mining | 186 |
| Skinning | 393 |
| Fishing | 356 |

**Reading the outcomes:**

| You see | It means |
|---|---|
| `gathering: Herbalism, Mining` | detection worked; those routes are live |
| `gathering: none` | detection worked, but the character has none of the four supported professions |
| `prof2=unreadable` | the slot exists but the client could not describe it; that slot is not detected |
| `none reported` | the client returned no profession slots at all |
| `API unavailable` | this build does not expose `get_professions` / `get_profession_info` |
| `API call failed` | the call raised |
| `API returned no table` | the call answered with nothing usable |

**Expected no-op:** the line appears **once per new profile**. Returning to a character already
seen this session, or re-activating the same one, prints nothing. Seeing it repeat every tick or
every few seconds is a defect, not a feature.

**Manual override.** Unchecking a `Profile: Gather …` row wins over detection and is **not**
re-applied — detection never runs again for that profile, so the opt-out sticks for the session.

**Boundary.** Alchemy, Tailoring, Blacksmithing and the rest are read and reported but change
nothing; only the four above are mapped. A non-English client with no readable names still works
as long as `skill_line` is present — the canonical label is then used in the `gathering:` tail.

---

## 2. Gather free-slot reserve

**What it is.** The gathering route refuses to take another node when your bags are close to full.
The reserve is a **per-character slider**, not a constant.

| Row | Range | Default | Meaning |
|---|---|---|---|
| `Profile: Gather Min Free Slots` | 0–16 | 4 | stop gathering below this many free bag slots |

**0 is the off position** — the bag gate stops applying entirely and the vendor threshold becomes
the only pressure. Anything above 0 blocks.

**Where free slots come from.** The same reader the loot gate uses
(`loot_manager_sylvanas.get_bag_space()` → `common/utility/inventory_helper`), so the two gates
read identical numbers and cannot disagree.

**The log lines** (need Debug Logging):

```text
IDLE: gathering Silverleaf [herbalism] — NAV
IDLE: gathering Silverleaf [herbalism] — used
IDLE: gathering stopped — 3 free bag slot(s), this character reserves 4
IDLE: gathering blocked — requesting a vendor visit (3 free, reserve 4)
```

**Expected no-op:** if you never tick a gathering row, or you set the reserve to 0, the reserve
line never appears — that is correct, not a failure.

**Things that are by design, not bugs:**

- The route only runs when the guide has **no active goal and no waypoint**. A quest objective
  always wins; you will not see gathering lines mid-quest-step.
- It only looks at **valid non-unit objects within 50yd**, at most 50 of them, once per second.
- **Skinning** here means visible non-unit carcass/hide objects. Ordinary dead mobs go to the
  corpse-loot path instead.
- Node recognition is **name-based**, so a non-English client may see fewer candidate nodes. The
  profession is detected by id; the node names are still localized client strings.
- If the inventory cannot be read at all, gathering **continues** rather than stalling — an
  unreadable bag is treated as "unknown", not "full". The vendor threshold remains the backstop.

---

## 3. Proactive vendoring

**What it is.** The reserve is a *slots* rule and the normal vendor trigger is a *fullness
percentage* rule, so on a large bag the reserve bites long before the percentage does. Rather than
let the bot stop gathering and stand there, a bag-blocked route asks for a vendor.

**The sequence to look for:**

```text
IDLE: gathering stopped — 3 free bag slot(s), this character reserves 4
IDLE: gathering blocked — requesting a vendor visit (3 free, reserve 4)
Coordinator: force vendor — gathering blocked: 3 free bag slot(s), reserve 4
```

Then the bot walks to the vendor, sells, and clears the request.

**The third line names the actual cause.** A vendor visit can be asked for two ways, and the
coordinator reports whichever one raised the request:

| You see | It was | Where it comes from |
|---|---|---|
| `Coordinator: force vendor — gathering blocked: 3 free bag slot(s), reserve 4` | this feature (proactive) | the gather reserve, at any bag fullness |
| `Coordinator: force vendor — bags 81% full (profile threshold 80%)` | the normal fullness trigger | bags crossing this character's threshold |
| `Coordinator: force vendor — bags >= 80% full` | a request with no recorded cause | the threshold fallback; see below |

The reason travels with the force-vendor flag and is cleared with it when the visit completes, so
the next request can never report the previous one's cause. If a raise ever arrives without one,
the coordinator falls back to the threshold this character vendors at — that fallback is why the
third row is worded differently from the first two, and it is the only line not to read as a
measurement.

**Pacing.** The request is idempotent and retried at most every **180 seconds**. A vendor visit
that frees nothing — a bag of quest items sells nothing — will not be requested again on the next
blocked tick. If you see the request repeating faster than every three minutes, that is a defect.

**Side effect worth knowing.** The force flag also makes the vendor sell **up to green quality**,
not just grey. That is deliberate: it is what actually frees the slots. It is the same behavior the
normal fullness trigger has always had.

**Expected no-op:** with a healthy reserve you will never see the proactive lines at all.

---

## 4. Reached-path memory

**What it is.** Within a session, the area sweep remembers the places your character has actually
stood on and does not walk them again on a later pass or a later step.

**Scope and limits, stated plainly:**

| Property | Value |
|---|---|
| Lifetime | the current client session only — **never** persisted, nothing survives a restart |
| Keyed by | the **place** (coordinates rounded to a tenth), never the guide's waypoint slot |
| Survives | a new sweep pass, and a step change — that is the entire point |
| Bounded to | 64 places; the oldest is dropped first |
| Distinct from | the per-step *retirement* of places the client refused to walk to |

**The log lines** (need Debug Logging):

```text
IDLE: area goal — navigating to wp 2/3 (40yd)
IDLE: area goal - reached wp 2/3 (remembered)
IDLE: area goal - reached wp 3/3 (remembered)
IDLE: area goal — all 3 waypoints covered — handing over to the guide
```

The `(remembered)` suffix appears the first time a place is recorded. A later pass that arrives
again prints the same line **without** it.

**The recorder event** `waypoint_reached` carries the index and coordinates, so a replay can show
exactly which ground was covered and when.

**Expected no-op:** a step whose waypoints you have never stood on walks them normally, with
`(remembered)` on each arrival. The first pass of every route always looks completely ordinary.

**The deliberate trade-off.** A place already reached is skipped even on a **new** step, because the
memory is session-scoped. The sweep is movement-only — it runs only when there is no target — so a
covered waypoint carries no trigger the bot still owes; kill/loot/interact objectives are handled
by the goal path, not the sweep. If you ever build a route that genuinely requires re-standing on
covered ground, this is the feature that would skip it. That case is not currently supported.

**Retirement is unaffected.** A place the client *refused* to walk to is still retired per step and
still retried once per pass. A refusal is never recorded as "reached" — the two memories stay
independent, which is why the retry still works after a restart of the lap.

---

## Quick triage

| Symptom | Most likely cause |
|---|---|
| No profession line at all | the character profile already existed this session; the line is once-per-profile |
| `API returned no table` | the client gave nothing usable — gather rows stay off, which is the safe default |
| Profession detected but nothing is gathered | no active goal/waypoint is required; or nodes are not matching the localized name vocabulary |
| Gathering stops and the bot stands still | reserve reached, and the proactive vendor request is on its 180s cooldown |
| `force vendor` line disagrees with the bag percentage | read the cause it names; `bags >= T%` is the no-cause fallback, the other two are measurements |
| `force vendor` repeats with a stale cause | the vendor visit never completed, so the flag was never cleared — check the vendor interaction |
| A route is skipped that you expected | reached-path memory — restart the client to clear it |
| Reserve slider has no effect | check it is not 0, and that a gathering row is ticked |

## Reporting a reproduction

Enable Debug Logging, reproduce, and capture the log. For anything involving the sweep, the
recorder output is better than the raw log because it carries the structured `waypoint_selected` /
`waypoint_reached` / `waypoint_retired` events in order:

```lua
local quester = EaxAutoQuester.quest_state
quester.start_session_recording()
-- reproduce
local session_jsonl = quester.stop_session_recording()
```

`docs/session_replay.md` covers the runner and its rules.
