# Telemetry Bridge — Project Sylvanas → Node.js Server

## Context

Connect EaxRotations Lua addon to an external Fastify Node.js server for real-time combat telemetry and remote command execution. Lua addon POSTs JSON state snapshots + spell-cast events via `core.http_post()`; server responds with command array; addon executes commands on next tick.

**API surface** (authoritative: `api/core.lua`, `apidocs/pages/dev/api/core.md`):
- `core.http_post(url, body, callback)` — async POST, callback(http_code, content_type, response_data, response_headers)
- `core.http_post(url, headers, body, callback)` — overload with custom headers
- `core.register_on_update_callback(fn)` — ~60Hz tick, throttle to 20Hz
- `core.register_on_spell_cast_callback(fn)` — event: `{spell_id, caster, target, spell_cast_time}`
- `core.input.cast_target_spell(spell_id, target)` — returns boolean
- No JSON library exists — must write minimal JSON encoder
- No raw sockets, no IPC, no `ffi.C`, no `os.execute`

---

## Protocol Schema

### Envelope (addon → server, POST body JSON)

```jsonc
{
  "version": 1,
  "seq": 234,
  "client_time_ms": 12345678,
  "player": {
    "guid": "0x1234",
    "name": "CharName",
    "class_id": 1,
    "level": 70,
    "map_id": 530,
    "instance_type": "none",
    "x": 123.4, "y": 567.8, "z": 30.1,
    "hp": 8500,
    "max_hp": 10000,
    "hp_pct": 85.0,
    "mana": 5000,
    "max_mana": 8000,
    "mana_pct": 62.5,
    "rage": 0,
    "energy": 100,
    "combo_points": 0,
    "in_combat": false,
    "is_casting": false,
    "active_spell_id": 0,
    "target_guid": "0x5678",
    "target_hp_pct": 100.0
  },
  "enemies": [
    {"guid": "0x5678", "name": "MobName", "npc_id": 12345, "hp_pct": 100.0, "distance_sq": 400, "in_combat": false, "is_casting": false}
  ],
  "spell_cds": [
    {"id": 133, "remains": 0.0, "ready": true}
  ],
  "events": [
    {"type": "spell_cast", "spell_id": 133, "target_guid": "0x5678", "ts": 12345678}
  ]
}
```

### Command Response (server → addon, HTTP 200 body JSON)

```jsonc
{
  "commands": [
    {"type": "cast_target", "spell_id": 133, "target_guid": "0x5678"},
    {"type": "cast_position", "spell_id": 2120, "x": 123.4, "y": 567.8, "z": 30.1},
    {"type": "use_item", "item_id": 1710}
  ]
}
```

Empty array = no commands. `seq` in envelope lets server deduplicate.

---

## File Tree

```
C:\newbot\scripts\
├── EaxRotations/
│   ├── shared/
│   │   └── telemetry_sylvanas.lua     # NEW: JSON encoder + telemetry collector + HTTP bridge
│   ├── tests/
│   │   ├── test_telemetry_sylvanas.lua  # NEW: Lua-side tests
│   │   └── run_rotation_tests.lua       # MODIFIED: add test_telemetry_sylvanas.lua to list
│   └── main_sylvanas.lua               # MODIFIED: require telemetry_sylvanas at load
│
├── telemetry_server/                    # NEW: Node.js Fastify server
│   ├── package.json
│   ├── tsconfig.json
│   ├── jest.config.ts
│   ├── src/
│   │   ├── index.ts                    # Fastify server entry
│   │   ├── types.ts                    # Shared TypeScript types (envelope, command)
│   │   └── telemetry.test.ts           # Server-side tests
│   └── .gitignore
│
└── .opencode/plans/
    └── telemetry-bridge.md              # THIS PLAN
```

---

## Task Dependency & Parallel Map

| Task | Depends On | Blocking? |
|------|------------|-----------|
| 1. Protocol types (TS) | None | Blocks 2 |
| 2. Fastify server | 1 | Parallel with 3 |
| 3. Lua JSON encoder | None | Blocks 4, 5 |
| 4. Lua telemetry collector | 3 | Parallel with 2 |
| 5. Lua integration into dispatcher | 3, 4 | After 4 |
| 6. End-to-end integration test | 2, 5 | Final gate |

**Parallel waves:**
- Wave 1 (start): Task 1, Task 3
- Wave 2: Task 2 (depends 1), Task 4 (depends 3)
- Wave 3: Task 5 (depends 3, 4)
- Wave 4: Task 6 (depends 2, 5) + final QA

---

## Scenario Contract (TDD)

| ID | Scenario | Type | Pass Condition |
|----|----------|------|----------------|
| S1 | Addon POSTs envelope → server logs, returns 200 + empty commands | Happy path | `lua test_telemetry_sylvanas.lua` GREEN intercepts callback; server test confirms body parse |
| S2 | Server returns command → addon parses and queues spell cast | Edge (command) | Lua test asserts `NS.telemetry_cmd_queue` populated after callback; type signature matches `core.input.cast_target_spell` |
| S3 | Server unreachable (callback http_code ≠ 200) → no crash, silent retry | Edge (network) | Lua test: simulated callback(http_code=0) → no error, no command queue mutation |
| S4 | Existing rotation tests still pass | Regression | `lua EaxRotations/tests/run_rotation_tests.lua` and `run_leveling_tests.lua` all GREEN |
| S5 | `luac -p` clean on all modified/new Lua files | Syntax | `Get-ChildItem EaxRotations -Recurse -Filter *.lua | % { luac -p $_.FullName }` all exit 0 |

---

## Tasks

### T1: Define TypeScript types + package scaffold (telemetry_server/)

**What**: Create `telemetry_server/` directory with `package.json`, `tsconfig.json`, `src/types.ts` defining the envelope and command TypeScript interfaces. Test-first: write `telemetry.test.ts` with failing tests for envelope parsing.

**Files**: `telemetry_server/package.json`, `tsconfig.json`, `jest.config.ts`, `src/types.ts`, `src/telemetry.test.ts`

**Acceptance**:
- `npm install` succeeds
- `npx jest` shows failing test (RED) for envelope parse
- Types compile: `npx tsc --noEmit` clean

**Skills**: `shared/programming` (TypeScript), `shared/ast-grep` (config gen)
**Category**: `unspecified-high`
**Depends**: None (Wave 1)

---

### T2: Implement Fastify server (telemetry_server/src/index.ts)

**What**: Fastify server listening on port 9000, `POST /telemetry` endpoint that:
1. Parses envelope JSON body
2. Validates `version` field
3. Logs snapshot via pino
4. Returns HTTP 200 with command JSON array (initially empty)
5. Health check endpoint: `GET /health` returns `{"ok":true}`

**Files**: `telemetry_server/src/index.ts`, `telemetry.test.ts` (make passing)

**Acceptance**:
- `npx jest` all GREEN for server tests
- `curl -X POST http://localhost:9000/telemetry -H "Content-Type: application/json" -d '{"version":1,"seq":1,"player":{},"enemies":[],"spell_cds":[],"events":[]}'` returns 200 with `{"commands":[]}`
- `curl http://localhost:9000/health` returns `{"ok":true}`

**Skills**: `shared/programming` (TypeScript/Fastify)
**Category**: `unspecified-high`
**Depends**: T1 (Wave 2)

---

### T3: Write Lua JSON encoder (EaxRotations/shared/telemetry_sylvanas.lua — Part 1)

**What**: Minimal JSON encoder in pure Lua covering: `nil`, `boolean`, `number`, `string`, `table` (array + object), nested tables. No decoder needed (only encode). Embedded as `NS.json_encode(val)`.

Test-first: `test_telemetry_sylvanas.lua` with RED cases:
- `json_encode({a=1, b="hello"})` → `'{"a":1,"b":"hello"}'`
- `json_encode({1,2,3})` → `'[1,2,3]'`
- `json_encode(nil)` → `'null'`
- Nested: `json_encode({a={b=true}})` → `'{"a":{"b":true}}'`
- Edge: empty table `{}` → `'{}'`, empty array `{n=0}` → `'[]'`

**Files**: `EaxRotations/shared/telemetry_sylvanas.lua` (first ~80 lines), `EaxRotations/tests/test_telemetry_sylvanas.lua` (first ~50 lines)

**Acceptance**:
- Test file run solo: all tests GREEN
- `luac -p` clean

**Skills**: `test-driven-development` (TDD), `code-simplification` (clean)
**Category**: `quick`
**Depends**: None (Wave 1)

---

### T4: Write Lua telemetry collector (telemetry_sylvanas.lua — Part 2)

**What**: Second half of `telemetry_sylvanas.lua` — the `TelemetryBridge` module provides:
- `NS.init_telemetry()` — call once to register callbacks on `core.register_on_update_callback` (throttled to 20Hz) and `core.register_on_spell_cast_callback`
- On update tick: collect player state (HP%, mana%, position, in_combat, casting, target), enemies list (up to 5 nearest attackable), spell CD snapshot (arranged as `{id, remains, ready}` table), sequence counter
- On spell cast event: append to `events` queue (FIFO, capped at 10 per tick)
- On tick: JSON-encode envelope, `core.http_post` to `http://localhost:9000/telemetry`
- On callback: parse `response_data` JSON (assumed simple — just check for `"commands"` substring or use a basic parse), queue commands into `NS.telemetry_cmd_queue` table
- On next tick: drain command queue, execute via `core.input.cast_target_spell(spell_id, target)`

Test-first: write RED → GREEN for:
- State collection produces valid NS fields
- Envelope serialization (combine T3 encoder + T4 collector)
- HTTP callback with 200 + command body populates queue
- Command drain calls mock cast

**Files**: `EaxRotations/shared/telemetry_sylvanas.lua` (remaining ~120 lines), `EaxRotations/tests/test_telemetry_sylvanas.lua` (remaining ~100 lines)

**Acceptance**:
- Full test suite: GREEN
- `luac -p` clean
- No core_sylvanas.lua changes

**Skills**: `test-driven-development`, `code-simplification`
**Category**: `unspecified-high`
**Depends**: T3 (Wave 2)

---

### T5: Wire telemetry into dispatcher (main_sylvanas.lua)

**What**: Add one line to `main_sylvanas.lua` (near other shared module loads) to optionally require and initialize telemetry.

Pattern:
```lua
local _telemetry_ok = pcall(require, "shared/telemetry_sylvanas")
if _telemetry_ok and NS.init_telemetry then
    NS.init_telemetry()
end
```

Test that existing rotation tests still pass (S4 regression).

**Files**: `EaxRotations/main_sylvanas.lua` (add ~4 lines), `EaxRotations/tests/run_rotation_tests.lua` (add `"test_telemetry_sylvanas.lua"` to test list)

**Acceptance**:
- `lua EaxRotations/tests/run_rotation_tests.lua` GREEN (all existing + new)
- `lua EaxRotations/tests/run_leveling_tests.lua` GREEN
- `luac -p` clean

**Skills**: `git-workflow-and-versioning` (atomic commit)
**Category**: `quick`
**Depends**: T3, T4 (Wave 3)

---

### T6: End-to-end smoke test + final validation

**What**: Manual QA across both sides:
1. Start telemetry server: `cd telemetry_server && npm start` (or `npx tsx src/index.ts`)
2. Run Lua test that POSTs to server and checks response: `lua EaxRotations/tests/test_telemetry_sylvanas.lua` should show server logs + client callback
3. Full regression: all 95 rotation tests + 11 leveling tests + audit
4. `luac -p` on all Lua files

**Files**: None (verification only)

**Acceptance**:
- Server starts, `/health` returns 200
- Lua test transmits to server successfully
- All regression suites pass
- `luac -p` clean on all .lua files

**Skills**: `debugging-and-error-recovery`, `code-review-and-quality`
**Category**: `unspecified-high`
**Depends**: T2, T5 (Wave 4)

---

## Commit Strategy

| Step | Commit Message | Scope |
|------|----------------|-------|
| After T1 | `feat(telemetry-server): scaffold types + package` | `telemetry_server/` |
| After T2 | `feat(telemetry-server): Fastify POST /telemetry + GET /health` | `telemetry_server/src/index.ts` |
| After T3 | `feat(telemetry): Lua JSON encoder` | `EaxRotations/shared/telemetry_sylvanas.lua`, `tests/test_telemetry_sylvanas.lua` |
| After T4 | `feat(telemetry): combat snapshot collector + HTTP bridge` | `telemetry_sylvanas.lua` (part 2) |
| After T5 | `feat(telemetry): wire into dispatcher` | `main_sylvanas.lua`, `run_rotation_tests.lua` |
| After T6 | `chore: end-to-end verification` | (no code changes, just QA) |

Each commit must be preceded by `luac -p` on all Lua files and the full test suite (rotation + leveling).

---

## Success Criteria

- [ ] Server: `npm test` GREEN on all TypeScript tests
- [ ] Server: curl health check returns 200
- [ ] Lua: All JSON encode tests pass
- [ ] Lua: All telemetry collector + HTTP bridge tests pass
- [ ] Lua: `luac -p` clean on every (new + modified) file
- [ ] Regression: `lua EaxRotations/tests/run_rotation_tests.lua` GREEN
- [ ] Regression: `lua EaxRotations/tests/run_leveling_tests.lua` GREEN
- [ ] End-to-end: Server receives Lua POST and responds with commands
- [ ] Zero changes to `core_sylvanas.lua`, zero changes to rotation spec files
