# Autoloot — what makes a corpse worth looting

## The path a kill takes

1. `IDLE` calls `shared/corpse_loot.lua:try_loot_nearest_corpse` every tick it is not in combat
   (twice: once early with a 20yd limit, once after the goal list is exhausted with no limit).
2. Within 3yd of the nearest eligible corpse → `core.input.loot_object(corpse)`. Its
   `is_auto_loot` defaults to true, so that one call empties the window.
3. Beyond 3yd → the corpse becomes `_nav_destination` and the state returns `NAV`.
4. If a loot window is somehow left open, `IDLE` sees it (`get_loot_item_count() > 0`) and
   `INTERACT` drains it through `loot_manager.try_loot()`.

`loot_manager.auto_loot_all` — the other, 5yd-only collector — has **no production caller**; the
only live entry into the loot window is step 2 and the frame handler in step 4.

## Why "dead" and "lootable" are two different questions

`corpse_loot` is the only thing that decides whether a body is worth walking to, and it has three
probes available, none of which is sufficient alone:

| Probe | Question it answers | What it does *not* answer |
|---|---|---|
| `is_dead()` | is the unit flagged dead | can report **false for a corpse that still holds loot** (recorded live, the Stonetusk Boar loop in `do_action_state.lua`) |
| `can_be_looted()` | may we loot it (`.api/game_object.lua`) | whether anything is left in it |
| `has_loot()` | **does it still contain loot** (`.api/game_object.lua`) | whether we are allowed to take it |

## The rule

```
is_dead()  can_be_looted()  has_loot()      verdict
---------  --------------  ------------    ---------------------------------
false      true            -               CORPSE — loot it
true       true            -               CORPSE
true       false           true            CORPSE — walk to it
true       false           false / nil     already emptied — skip
false      false / nil     -               not a corpse — skip
```

- **`can_be_looted() == true` stands on its own.** Requiring `is_dead()` alongside it is what
  silently stopped autoloot: the probe that lies was the one the whole rule was hung on.
- **`has_loot() == false` is what proves a corpse empty**, and `can_be_looted() == false` proves it
  only when `has_loot()` has not said otherwise. That keeps the emptied-corpse loop shut — the
  loop is real and lived: `looting corpse (0yd)` every 2 seconds for minutes on a body that was
  already empty (Stonevault Shaman) — without retiring a corpse that still has something in it.
- **A missing method is "no evidence", never "no loot".** Both probes are read through `pcall`;
  with neither available the rule falls back to the old `is_dead()` test, so a build without the
  probes cannot disable autoloot.

## Tests

`tests/test_corpse_loot.lua` (C1–C7), one scenario per row of that table plus the two gates the
module already had:

- **C1** a corpse reporting `is_dead() == false` with `can_be_looted() == true` is looted (the
  report this pass closes);
- **C2** an emptied corpse underfoot is neither looted again nor made a destination;
- **C3** a corpse 15yd away with `has_loot() == true` and `can_be_looted() == false` is walked to
  (the walk-to-it half, which is every corpse after a ranged kill);
- **C4** `has_loot() == false` → nothing, even with `is_dead() == true`;
- **C5** with neither probe exposed, a dead unit is still looted;
- **C6** an open loot window stands the module down;
- **C7** the nearest corpse is the one looted, and the 2s cooldown gates the next scan.

**5 mutants, 5 killed** (each restored byte-identically between runs): `corpse = is_dead only`,
`proven_empty = false`, `proven_empty = can_be_looted() == false` (the over-strict form), the loot
cooldown removed, and the open-window guard removed.

## Not verifiable without the client

Which of the three probes this client actually answers for a **unit** corpse — the bobber report
in `crash/EAXFishing/docs/` shows `can_be_looted()` and `has_loot()` coming back flat `false` for a
*fishing bobber*, and nothing in the repo measures them on a corpse. The rule above is built to be
correct under every combination (each probe may be absent, false, or true), and it is the reason
`has_loot()` is consulted first for emptiness: if `can_be_looted()` turns out to be
distance-dependent ("can I loot it from here"), it can no longer suppress a corpse across the
camp.

In game, autoloot working looks like `IDLE: looting corpse (2yd)` on arrival and
`IDLE: approaching lootable corpse (15yd) [autoloot]` while closing — the second line is the one
that went missing. If corpses are still skipped with both lines absent, the next thing to log is
the three probe values per corpse, which is a one-line diagnostic on the scan in
`corpse_loot.lua`.
