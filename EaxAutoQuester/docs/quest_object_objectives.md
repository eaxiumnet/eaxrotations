# Quest-object objectives — client runbook

What: how to tell, in the live client, that a step whose goal names a quest **game object**
("Ogre Remains", `z=0`-height guide waypoints, an id the creature spawn index does not know) is
being walked to, clicked, and retried — and what each remaining log line means.

Why: the code path is proven by the suites, but only the client can say whether the world object
is inside the client's object stream at the coordinates the guide supplies. This is the runbook for
that check, so a failure is read as a fact ("the client never reported the object within 50yd")
rather than re-diagnosed from scratch.

## The decision chain (one owner per line)

| Stage | Owner | Log line |
|---|---|---|
| Which goal is open | `quest_state/idle_state.lua` | `IDLE: goal[7] text=... npc_id=... target=Ogre Remains` (once per change) |
| Is the objective in sight | `quest_state/idle_state.lua` (50yd, every IDLE tick) | `IDLE: objective-first 'Ogre Remains' found at Nyd -> NAV` or `... in range (Nyd) - skip NAV` |
| What to do about it | `quest_state/do_action_state.lua` (`visible_quest_object`) | `DO_ACTION: area — approaching 'Ogre Remains' (Nyd)` |
| The click | same, the name path | `DO_ACTION: area — targeted quest object 'Ogre Remains'` |
| Nothing in sight | `shared/spawn_patrol.lua` | `SPAWN PATROL: N spawn point(s) ...` / `searching spawn point i/N (Nyd)` |

A healthy run looks like this, in order, and repeats per object:

```
IDLE: goal[7] text=nil npc_id=233818 target=Ogre Remains
IDLE: objective-first 'Ogre Remains' found at 12yd -> NAV
NAV: arrived
DO_ACTION: area — targeted quest object 'Ogre Remains'
```

## Reading a failure

- **No `objective-first` line and no `targeted quest object` line, ever.** The client has not
  reported an object by that name within 50yd of anywhere the bot stood. That is a fact about the
  client's object stream, not about the click: check with a mouse-over whether the object exists at
  the step's waypoint, and whether the name in the goal is the name the client shows. The id in the
  log is the guide's; `get_npc_id()` is documented "This only works for npcs!", so a game object is
  matched by its whole name.
- **`SPAWN PATROL: searching spawn point i/N (0yd)` / `(1yd)`.** A leg was published for a place the
  bot is already standing on. AQ-P3-1 measures arrival on the ground plane, so this should not
  happen; if it does, the candidate's x/y is not the player's x/y (a different step's waypoints, or
  a rebuilt list).
- **`spawn point N walk ended short`** — the 15s timeout fired with no refusal on record. The walk
  ended before the point. `spawn point N unreachable` is reserved for a place
  `shared/nav_destination.lua` records as refused by the client.
- **`frame outlived complete_quest — claiming it`** — an OFFER (choice links, no money) survived the
  turn-in, and is being accepted. A money frame instead logs
  `turn-in outlived complete_quest — closing it rather than accepting`; that one is a refused
  turn-in, and after three attempts the bot backs off for 60s and asks the player to finish it.
- **A frame the bot cannot finish at all.** `Quest frame would not close after 3 attempts` is the
  one message that needs a human; the bot will not touch that frame again for two minutes.

## What the bot does not decide

The bot has no gameobject table in this build: an objective game's coordinates come from the
guide's step waypoints and from the client's own object list. A step whose waypoints do not reach
the object is a guide-data question, not something the rotation layer can resolve — the sweep will
cover the step's path and keep looking, but it will not invent a destination.

## Tests that pin this

`tests/test_do_action_state.lua` S31–S34 (object outranks the sweep; use at range; units keep the
patrol order; no objective still sweeps), `tests/test_spawn_patrol.lua` P16–P18 (ground-plane
arrival, refused places, the leg-end verdict), `tests/test_quest_turnin.lua` S9 (a money turn-in is
never accepted; an offer still is), `tests/test_idle_state.lua` P17 (the goal line).
