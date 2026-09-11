# Debugging with Trace Casts

How to use the built-in cast trace to answer "why did it (not) cast X?" — using the
"Mortal Strike never fires" reports as the worked example. Everything below is the
real behavior of `shared/cast_trace_sylvanas.lua`; no guessing required.

---

## 1. Turning it on

Open the EaxRotations menu → **Diagnostics** section (same in the legacy menu and
the declarative menu):

| Control | What it does |
|---|---|
| **Trace Casts** (checkbox) | Enables recording. When off, zero cost — nothing is recorded or allocated. |
| **Last Casts** (readout) | Live view of the last 4 casts while the menu is open. |
| **Print Last Casts** (button) | Writes the last 8 casts to the addon log (`izi.log`), each line prefixed `[CastTrace]`. |
| **Clear Trace** (button) | Empties the history. |

The trace keeps a **bounded ring buffer of the last 32 casts**. Print promptly
after the fight — 32 GCDs go fast in AoE.

## 2. How to read a line

Every recorded cast looks like:

```
[CastTrace] [rotation] MortalStrike: in_combat=true ms_cd=0 rage=42
```

Breaking that down:

- `[rotation]` — the strategy list that produced the cast (you may also see
  `[defensive]`, `[interrupt]`, `[auto]`, etc.).
- `MortalStrike` — the decision lane (rule) that fired. This is the exact name
  from the spec file — what you see here is what the rotation actually chose.
- `field=value ...` — up to 4 live state values the lane's conditions read, at
  the moment it fired. Numbers show 1 decimal (or whole if large), booleans as
  `true`/`false`.

Lanes that were not compiled from the declarative DSL (e.g. middleware lanes
like OOC resurrection) record **name only**, no state — that is expected, not a bug.

## 3. What the trace does NOT show (read this before diagnosing)

1. **Only executed casts are recorded.** A lane that was *held* (its gate failed)
   never appears. You diagnose a held spell indirectly: look at what fired
   *instead* and at the state values on those lines.
2. It shows the winner's state, not the loser's gates. There is no line that says
   "MortalStrike was skipped because rage was 28."
3. The trace records the rotation's *decision layer*. If nothing at all appears,
   the rotation itself did not execute anything (or the toggle is off) — that is
   a different problem than "the wrong spell fired".

## 4. Worked example: "Mortal Strike never fires"

Mortal Strike's gate per era (real conditions from the spec files):

| Era | File | MS fires when |
|---|---|---|
| WotLK | `warrior/arms_wotlk.lua` | `in_combat` AND `ms_cd <= 0` AND `rage >= 30` |
| Vanilla / TBC | `warrior/arms_vanilla.lua`, `arms_sylvanas.lua` | battle stance AND rage ≥ 30 AND spell ready (a BattleStance lane swaps you back if you're in another stance) |
| SoD | `dps_warrior_sod.lua` | SoD rune active + stance + rage gates |

### Step 1 — Is MS firing at all?

Enable Trace Casts, fight for ~10 seconds, click **Print Last Casts**.

- **You see `[rotation] MortalStrike: ...` lines** → MS *is* firing. If a user
  still reports otherwise, compare their log with yours — the report is a
  perception/uptime issue, not a gate failure.
- **MS never appears, but other rotation lanes do** → MS is being held. Go to Step 2.
- **Nothing at all is recorded** → toggle off, or the rotation executed nothing.
  First confirm other Diagnostics logging works, then re-check the toggle.

### Step 2 — Which gate is holding it?

Read the state values on the lines that fired in MS's place:

| Pattern in the trace | Diagnosis |
|---|---|
| Filler lines show `rage=` **below 30** (e.g. `rage=24`) | **Rage gate.** Correctly held — MS needs 30 rage. Rage starvation is a build/APM issue, not a script bug. |
| Vanilla/TBC: repeated `BattleStance` (or stance-swap) lines | **Stance gate.** The script is swapping you back to battle stance to enable MS. If swaps repeat forever without an MS line following, the engine's stance read may be stuck (see Step 3). |
| Filler lines show healthy `rage=` (60+) for many consecutive GCDs, no MS, no stance swaps | **Suspected cooldown gate stuck.** MS's cooldown is short (single-digit seconds) — if you have not seen MS in a full minute of single-target combat with rage to spare, the readiness read may be reporting "not ready" forever. Go to Step 3. |
| MS appears, then long gaps with `ms_cd`-style cooldowns on other lines | Normal cadence — compare the gap to the spell's known cooldown before reporting. |

### Step 3 — Correctly held vs. engine API health failure

The difference between "the script is right" and "the engine API is lying":

- **Correctly held:** the state values are *consistent* — rage genuinely below 30,
  or you genuinely are in the wrong stance. Cross-check against your own UI
  (rage bar, stance icon).
- **Engine gate stuck:** the state values on the firing lanes say the gate *should*
  be open (combat=true, rage ≥ 30 continuously, no stance swaps), yet the MS lane
  never wins across an entire fight. On WotLK the MS readiness comes from the real
  cooldown API (`NS.cooldown_remains`, where 0 = ready); if that API returns a
  stuck non-zero on a player's build, MS is permanently held while everything else
  works. A Trace Casts log demonstrating "rage ≥ 30 for 60s of combat, zero MS
  lines" is exactly the evidence needed for an engine-health report.

### Step 4 — Report it with evidence

When filing a report, paste the `[CastTrace]` lines plus:

- era + spec file you are running (menu shows the rotation name),
- stance and rage at the time,
- whether MS *ever* appeared during the fight.

That combination distinguishes all four cases (stance / rage / cooldown /
engine health) from one fight's log.

---

## 5. Notes and limits

- Recording is off by default; enabling it costs nothing per frame when off.
- Ring capacity is 32 casts; the readout shows the last 4, Print writes the last 8.
- Non-DSL lanes (middleware) record name only.
- The trace is decision-layer only — it does not intercept the engine's cast
  itself. If the trace shows MS firing but the game shows no cast, the failure is
  below the decision layer (engine cast path), and the log proves the decision
  was correct.
