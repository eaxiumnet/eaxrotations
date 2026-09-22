# Starting fights on purpose: the pull gate

How `shared/pull_safety.lua` decides whether a hostile is worth engaging, why the answer is
sometimes "walk away" rather than "try anyway", and where it is wired in.

Live report this exists for:

> more careful pulling more mobs on casters with low mana and scan nearby mobs pathing so we dont
> pull and kill ourselves due to no mana or low health but instead move away so we dont pull.

## The three ways the old code committed anyway

1. **It pulled at any health and any mana.** `menu_sylvanas.lua` has shipped `eaxaq_min_hp` and
   `eaxaq_min_mana` (sliders 1–100, both defaulting to 80) since the menu was written, and
   **nothing in the plugin read either one** — they are not even rendered. This module reads
   **neither**: those rows were never this feature's, and their 80/80 display defaults are not
   "low" by any reading (see *The floors* below). The gate has its own three rows instead.
2. **The only crowd check ran after the pull.** It asked "are 3 hostiles within 10yd of the
   target" from in melee — i.e. it could only ever describe a fight that had already started — and
   its answer was to *stand still*. Standing still in a camp is the outcome the report is about.
3. **A patrolling mob read exactly like an idle one.** The scan looked at positions only. A mover
   is the more dangerous of the two: it closes the distance for you and brings the camp, so the
   same count of neighbours is not the same risk.

## The rules

| Question | Read | Rule |
|---|---|---|
| Am I in shape to start this? | `get_health`/`get_max_health`, `get_power(0)`/`get_max_power(0)` | below `eaxaq_pull_gate_min_hp` or `eaxaq_pull_gate_min_mana` → no pull |
| Is it a crowd? | hostiles within `CROWD_YDS` (18yd) of the **fight site** and of **us** | `risk >= RISK_LIMIT` (3) → no pull |
| Is any of them pathing? | `get_movement_speed() > 0.1` | a moving hostile is **2** risk points, an idle one 1 |

Risk is counted at the fight site **and** where we are standing, whichever is worse: the fight
happens in the gap between the two, so a patroller crossing our side of it is the same problem.
Two idle mobs (risk 2) is allowed; one patroller plus one idle (risk 3) is not.

`get_max_power(0) == 0` means **"this class has no mana bar"**, not "no mana" — a warrior or rogue
must not be gated by a resource it does not use, so a zero maximum switches the question off.

## The floors, and the switch

The condition floors are **floors, not preferences**: each answers "would the next fight plausibly
kill me, or leave me unable to finish it?" They are deliberately below the point a player would
call a resource low, so ordinary leveling never trips them.

| Row | Default | Why this number |
|---|---|---|
| `eaxaq_pull_gate` | on | The one switch that owns every rule here. Off = no rule applies at all, including the crowd scan and the hold |
| `eaxaq_pull_gate_min_hp` | **50** | A leveling caster spends ~25–40% of its health on a single solo mob, so half a bar is where one long fight can finish you outright and where an add certainly does |
| `eaxaq_pull_gate_min_mana` | **30** | A caster pays roughly a quarter to a third of its pool per kill. Below a third it cannot pay for another, and a caster that cannot kill cannot run either — the failure mode is dying to a mob it cannot finish |

Setting either slider to **0 turns that one rule off** (`pct < 0` is never true, so no special case
is needed), which leaves the crowd rule and the other floor in force.

The first version of this gate inherited the `min_hp`/`min_mana` rows' 80/80 instead, and the
consequence was measured: a **full-health caster at 75% mana facing one lone idle mob in an empty
world was refused and walked away**. That is 80% of a mana bar — ordinary post-fight state for most
of a questing session — so the feature read as "retreat after most kills", the opposite of what it
was asked for. `N1`, `N2` and `N4` in the suite pin that boundary from both sides: 90% health with
ordinary 60% mana against one idle mob **must pull**; 29% mana / 49% health must refuse while 31% /
51% must not; and the crowd rule must refuse exactly what it refused before the floors moved.

## "Move away" is literal

When the gate refuses, it does not simply decline and let the caller re-decide next tick (that is
how the bot ends up standing in the pull it just refused). It computes a **retreat point** —
`RETREAT_YDS` (25yd) from here, directly away from the centre of mass of the same hostiles the
risk count came from, one radius for both answers so "too crowded" and "which way is out" cannot
disagree — and remembers it while the condition holds. Re-computing it on every re-arm would
re-issue a walk from the refuge each time, which is pacing: back off, get re-assessed, back off
again. The bot parks at the point and waits instead.

### The point's Z, and who writes the destination

Two defects fixed here, both of which could leave the bot standing still:

**The point is terrain-fixed.** It used to carry the player's own Z, which is only correct on flat
ground — off a ledge or across a terrace the client cannot walk to it at all, so the safest
decision in the module was the most reliable way to produce a `Stuck detected` report. It now goes
through `waypoint_fixer.fix_z` exactly like every other destination producer in the plugin
(`do_action_state`'s NPC spawn point, `idle_state`'s terrain raycast, the zygor/questie/
`goal_resolver` waypoints).

**The gate expresses intent; it does not write navigation state.** `M.destination(ctx)` is the
gate's published retreat and the only way it says where the bot should go — `pull_safety.lua`
contains no `_nav_*` assignment at all. `shared/nav_destination.lua` owns those five fields, and
`nav_state` — the state that issues the walk — asserts the claim at the top of every travelling
tick, with `idle_state` resolving the same claim before it decides to hand the walk over.

Precedence, documented once:

| Rank | Source | Rule |
|---|---|---|
| 1 | the pull gate's retreat, while its hold is armed | outranks everything, **whoever wrote last**, because it is re-asserted when the destination is consumed rather than once when it was decided |
| 2 | a live-unit destination (a mob to close on) | a moving point; honoured only while `_nav_unit_dest_key` still matches the current destination, and cleared by rank 1 |
| 3 | a plain point (waypoint, corpse, quest object, NPC spawn) | last writer wins — correct, since none of them moves |

Before this, the destination had four writers and no owner: `pull_safety` wrote all five fields
itself, so a retreat it armed could be silently replaced by whoever wrote last in the same tick and
the bot walked back into the group it had just backed away from. Rank 1 replaces a destination
rather than sitting beside it, so a stale live-unit link cannot make `nav_state` re-issue walks
toward the mob the retreat is leaving. The remaining writer sites in `idle_state` and
`do_action_state` are rank 3 sources like any other; migrating them onto the owner is its own pass.

## The hold, and why it cannot wedge a step

A refused pull arms a `HOLD_SECONDS` (6s) hold. `idle_state` asks `M.holding(ctx)` and will not
walk back toward the mob while it is live — without that, the same tick that declines the pull
hands the walk straight back to the group. When the condition clears (you healed, drank, the
patrol moved on), the hold is released at once rather than waited out.

An unbounded wait would be a step that never finishes, so there is a hard cap:
`MAX_WAIT_SECONDS` (40s) after the first refusal the bot **engages anyway** and says which rule it
had to break, once per reason, in both the debug log and `log_warning`. Breaking the rule on
purpose has to be announced, or the pull that follows looks like the bug you were complaining
about.

The gate also never fires **once a fight is on** — neither when we are in combat nor when the
enemy we are looking at is the one fighting us. Running from a fight already started is a
different behaviour, and it would fight the rotation for control of the tick. This gate is only
about *starting* one, which is why it is consulted before the approach too.

Failure direction: every client read is `pcall`-guarded, and an unreadable client means **engage**,
not decline. A bot that refuses to fight because a probe failed would stall every step.

## Where it is wired

Three engage sites in `quest_state/do_action_state.lua`, each before anything walks in or targets:

| Line | Site |
|---|---|
| `377` | the kill lane, on `npc.get_nearest_enemy` — before the approach |
| `797` | the area name path — the gate runs **before** `set_target` |
| `898` | the area object-scan path, carrying the object list through |

The order at the name path matters and is deliberate: selecting a hostile is not harmless. It is
what the rotation's combat path keys off, and it is the visible half of "the bot walked up to the
mob and started something". Quest objects and friendly NPCs are untouched by the gate — it only
ever refuses hostiles — so their selection stays exactly where it was.

`quest_state/idle_state.lua` consults `pull_safety.holding(ctx)` so the hold outranks the vectors
that would otherwise walk back to the mob.

Only the name path is driven by an end-to-end fixture (`S18` in `test_do_action_state.lua`), so
the other two are pinned by shape in `test_pull_safety.lua` **P12**, which reads the source, counts
the three call sites, and proves the check is non-vacuous by counting 2 when one is removed.
A gate nothing calls cannot fire, however well its unit suite passes — that is the failure mode
these pins exist for.

## Tests

- `tests/test_pull_safety.lua` — P1–P11 the rules (low mana, low health, an idle vs a pathing
  neighbour as the *only* difference, a class with no mana bar, never mid-fight, the non-pacing
  retreat, the bounded hold, expiry + early release, an unreadable client), **P6** that the gate
  reads its own rows and not the legacy pair, **N1–N5** the thresholds: N1 the ordinary post-fight
  caster that must pull, N2 the floors pinned from both sides (29/31 mana, 49/51 health, one per
  resource), N3 the switch off mid-hold and back on — including that a minute switched off must not
  spend the anti-stall cap — N4 that the pathing weighting and the crowd limit refuse exactly what
  they refused before, N5 that a floor of 0 disables that one rule. **R1–R3** the retreat's
  delivery: R1 the gate writes no `_nav_*` field on any path, proven with a shared table whose
  metatable raises on such a write (and proven non-vacuous by making the guard catch one), R2 the
  point goes through the fixer and keeps its bearing with the fixed height, R3 a destination
  written *after* the retreat loses to it while the hold is live — and stands untouched without
  one. **P12** the wiring.
- `tests/test_do_action_state.lua` S18 — the area lane end to end with an empty bar: nothing is
  targeted, the destination is away, and the same lane engages once mana is restored (the control
  that makes the refusal attributable to the gate).
- `tests/test_idle_state.lua` P9c — IDLE parks instead of walking back into the refused pull;
  P9g — a destination written after the retreat does not replace it, so the walk IDLE hands over
  goes where the gate sent it.
- `tests/test_nav_state.lua` N14 — the same at the state that owns navigation: with the hold live,
  `nav_state` asserts the retreat over a later live-unit destination (dropping the unit link and the
  stand-off), and leaves an ordinary destination alone when there is no hold.
- `tests/test_menu_pull_gate.lua` — the rows are real: the switch exists as a checkbox defaulting
  ON, both floors reach 0 and default to 50/30, the render body **draws** all three (a control that
  is created but never rendered is unusable, which is exactly what the legacy pair is — M3 uses them
  as its non-vacuity control), a missing row falls back to the module default, and M4 walks the real
  menu module into the real gate in both switch positions.

Twenty-nine mutants check that every rule, every default and every row here is load-bearing. Five are the *old*
behaviour and must fail a boundary probe to prove the fix is real — the condition read from the
legacy 80/80 rows, those floors shipped as the gate's own defaults, the switch read and ignored, a
floor of 0 falling back to the default, and the wait clock surviving a switch-off. Each of the first
two is observed failing `N1a` ("90% health and ordinary 60% mana against ONE idle mob") when the N
boundaries are run on their own, and failing `P6b` when the whole suite runs, since P6 states the
same claim slightly earlier in the file. Twelve more are regression guards for what the request
said to keep: menu-read removed, health rule dropped, speed weighting flattened, crowd rule
dropped, in-combat short-circuit removed, anti-stall cap removed, retreat re-computed per re-arm,
IDLE hold ignored, name-path gate deleted, selection reordered ahead of the gate, scan-path gate
deleted. Four more cover the controls themselves: the switch never created, the switch defaulting
off, the floors shipping at the legacy 80/80, and the rows created but never rendered. The last
eight cover the retreat's delivery: the owner's claim writing nothing, the claim leaving the
live-unit link or the stand-off behind, the retreat skipping the terrain fix-up, the gate writing a
navigation field again (caught by R1's guard), `nav_state` or `idle_state` dropping the claim, and
an expired hold that keeps claiming. All twenty-nine are killed; a mutant that does not even load
is reported as invalid rather than counted as a kill.

## Open, deliberately not done here

- `eaxaq_min_hp` / `eaxaq_min_mana` are still created in `menu_sylvanas.lua` and still read by
  nothing (they are not even rendered). Deleting them is its own pass.
- The remaining destination writers in `idle_state` and `do_action_state` still write the fields
  directly rather than going through `shared/nav_destination.lua`. They are rank 3 (last writer
  wins) and the claim beats them at read time, so nothing is broken — but the owner is the place
  they belong.
