# Telemetry Bridge — Sylvanas-to-Node Telemetry & Command Relay

## 0. Plan Metadata

| Field | Value |
|---|---|
| **Plan ID** | `telemetry-bridge-v1` |
| **Created** | 2026-06-18 |
| **Scope** | Addon HTTP telemetry emitter + Node.js Fastify receiver. Two sibling dirs isolated from `EaxRotations/`. |
| **Non-Goals** | MCP wrapper, web dashboard, ML/statistics, changes to rotation logic, changes to `core_sylvanas.lua`, multi-client support, authentication, TLS. |
| **Dependencies** | All tasks depend on `core.lua` API surfaces verified in context. Schema tasks are the shared trunk — server and addon diverge after. |
| **Total new files** | 12 (7 TS + 1 JSON + 1 JSONC + 3 Lua) |
| **~Total LOC** | 850–1000 |
| **Scenarios** | 7 (S1–S7) |

---

## 1. Architecture Diagram

```
+--------------------------------------------+       +-------------------------------------------+
|  Sylvanas Addon (Lua sandbox)              |       |  Node.js 22 + Fastify Server             |
|  telemetry_addon/                          |       |  telemetry_server/                        |
|                                             |       |                                            |
|  20Hz snapshot tick <--+                   |       |  127.0.0.1:9000                            |
|  spell_cast event ---+  |                   |       |                                            |
|                     |  |                   |       |  POST /telemetry                           |
|                     v  v                   | HTTP  |  Content-Type: application/json            |
|  Queue -> core.http_post(envelope)---------+-------+--> validate (Ajv)                         |
|                                             |       |  +- log/store                             |
|  <-- callback -- server_response -----------+-------+--> build command[]                        |
|                                             |       |  +- respond 200                            |
|  +- dispatch commands next tick              |       |                                            |
|    (cast_spell, log, noop, ...)             |       |                                            |
|  +- retry on transport failure               |       |                                            |
|    (1Hz max, 3 attempts)                    |       |                                            |
+--------------------------------------------+       +-------------------------------------------+
                                                                 |
                                                                 | (future - out of scope)
                                                                 v
                                                 +----------------------------------+
                                                 |  Optional External Tool          |
                                                 |  (MCP server, dashboard,         |
                                                 |   ML pipeline, etc.)             |
                                                 +----------------------------------+
```
**Arrow details:**
- Addon -> Server: `core.http_post("http://127.0.0.1:9000/telemetry", {"Content-Type": "application/json"}, json_body, callback)`
- Server -> Addon: `{ack, status, commands[], server_ts}` delivered in `callback(http_code, content_type, response_data, response_headers)`
- Each POST is fire-and-forget with async callback; the callback dispatches any received commands on next `on_update` tick.

---

## 2. Protocol Schema

### TelemetryEnvelope (addon -> server)

| Field | Type | Required | Max Size | Notes |
|---|---|---|---|---|
| `v` | string | yes | 8 chars | Protocol version, e.g. `"0.1"` |
| `kind` | string | yes | 16 chars | One of: `"handshake"`, `"snapshot"`, `"cast_event"` |
| `seq` | integer | yes | <2^31 | Monotonic per-session; wraps via modulo |
| `ts` | number | yes | - | `core.game_time()` ms |
| `player.guid` | string | yes | 32 chars | Player GUID hex |
| `player.name` | string | yes | 24 chars | Player name |
| `player.class_id` | integer | yes | - | WoW class id (1-12) |
| `player.spec_id` | integer | yes | - | Talent spec id, 0 if unknown |
| `player.level` | integer | yes | - | 1-70 |
| `player.map_id` | integer | yes | - | Current map id |
| `player.pos` | object | yes | - | `{x, y, z}` as numbers |
| `combat.in_combat` | boolean | yes | - | `player:is_in_combat()` |
| `combat.target_guid` | string | no | 32 chars | Present if in combat and target exists |
| `combat.target_hp_pct` | number | no | 0-100 | Present if target exists |
| `combat.enemy_count` | integer | no | - | Near melee-range enemies |
| `resources.hp_pct` | number | yes | 0-100 | Computed from get_health / get_max_health |
| `resources.hp_max` | integer | yes | - | `player:get_max_health()` |
| `resources.power` | integer | yes | - | `player:get_power(power_type)` |
| `resources.power_max` | integer | yes | - | `player:get_max_power(power_type)` |
| `resources.power_type` | integer | yes | - | Enum: 0=Mana, 1=Rage, 3=Energy, 6=RunicPower |
| `resources.power_pct` | number | yes | 0-100 | Computed |
| `auras.buffs` | array[object] | no | 50 items | Each: `{id, count, expire_time}` |
| `auras.debuffs` | array[object] | no | 50 items | Each: `{id, count, expire_time}` |
| `cast.spell_id` | integer | yes* | - | *Required only when `kind="cast_event"` |
| `cast.spell_name` | string | no | 48 chars |
| `cast.target_guid` | string | no | 32 chars |
| `cast.cast_start_time` | number | yes* | - | *Required only when `kind="cast_event"` |
| `state_hash` | string | no | 40 chars | Short hex hash for server-side dedup |
| `uptime_s` | number | yes | - | `core.time()` seconds since injection |

**Max body size**: 4096 bytes (server rejects larger with 413; addon soft-caps).

### ServerResponse (server -> addon)

| Field | Type | Required | Notes |
|---|---|---|---|
| `ack` | integer | yes | Echoes `seq` from envelope |
| `status` | string | yes | `"ok"` or `"error"` |
| `error` | string | no | Human-readable error when `status="error"` |
| `commands` | array[Command] | yes | May be empty |
| `server_ts` | number | yes | Server wall-clock ms (Date.now()) |

### Command Types (Phase 1)

#### `cast_spell`
| Field | Type | Required | Notes |
|---|---|---|---|
| `spell_id` | integer | yes | Spell to cast |
| `target_guid` | string | no | Null/absent -> use current target |
| `position` | object | no | `{x, y, z}` - for `cast_position_spell` |

**Addon executor**: `core.input.cast_target_spell(spell_id, target_obj)` or `core.input.cast_position_spell(spell_id, position)` on next update tick.

#### `request_full_snapshot`
| Payload | Notes |
|---|---|
| `{}` (empty) | Addon sends one extra snapshot immediately (not throttled) |

**Addon executor**: Forces immediate POST on next tick regardless of 20Hz throttle.

#### `cancel_pending`
| Field | Type | Required | Notes |
|---|---|---|---|
| `reason` | string | no | Why the cancel was issued |

**Addon executor**: `core.input.cancel_spells()` (stops current cast, clears spell queue target).

#### `noop`
| Payload | Notes |
|---|---|
| `{}` (empty) | No action; ack-only. Used for heartbeat confirmation. |

**Addon executor**: Does nothing.

#### `log`
| Field | Type | Required | Notes |
|---|---|---|---|
| `level` | string | yes | `"info"`, `"warn"`, `"error"` |
| `message` | string | yes | Log text |

**Addon executor**: `core.log(msg)`, `core.log_warning(msg)`, or `core.log_error(msg)` respectively.

---

## 3. File Tree (exact paths)

```
telemetry_server/
+-- package.json                      # Node 22, fastify, @fastify/cors, ajv, typescript, vitest, @types/node
+-- tsconfig.json                     # strict, ES2022, NodeNext module, outDir: dist
+-- src/
    +-- index.ts                      # Fastify entry: listen 127.0.0.1:9000, register route
    +-- schema.ts                     # TypeScript interfaces: TelemetryEnvelope, ServerResponse, Command types
    +-- schema.test.ts                # TDD S5: validation (malformed envelope -> 400)
    +-- handlers/
    |   +-- telemetry.ts             # POST /telemetry: validate -> process -> build response -> reply
    |   +-- telemetry.test.ts        # TDD S1+S2+S3+S6: inject tests for valid envelopes, commands
    |   +-- commands.ts              # Command response builder (what commands to return given envelope)
    +-- routes.test.ts               # TDD S6: integration tests for idempotency, concurrent seq dedup

telemetry_addon/
+-- telemetry_sylvanas.lua            # Entry: register callbacks, queue, http_post, command dispatch
+-- schema_sylvanas.lua               # Envelope builder, field validation helpers, JSON encoding

(no existing files modified)
```

---

## 4. Scenario Contract

### Scenario S1: Handshake + first state upload (happy path)

- **Given**: Server up on `127.0.0.1:9000`, addon just loaded, player exists.
- **When**: First `on_update` tick fires after load.
- **Then**: Addon calls `core.http_post` with envelope containing `v="0.1"`, `kind="handshake"`, `seq=1`, valid `player.*`, `resources.*` fields.
- **Then**: Server returns 200 with `{ack=1, status="ok", commands:[], server_ts=<number>}`.
- **RED test**: Lua unit test: Mock `core.http_post` to capture call. Assert body has `kind="handshake"` and `seq=1`. Assert `kind` is never `"snapshot"` before handshake completes.
- **GREEN impl**: `telemetry_sylvanas.lua` lines 1-80: Module-level state cache, `register_on_update_callback` with first-tick flag, handshake POST on tick 1.
- **SURFACE artifact**: Run Lua with mock env, verify stdout prints JSON body. Also curl POST with valid handshake body -> 200 response.

### Scenario S2: Mid-combat spell cast event triggers immediate POST

- **Given**: Addon already sent handshake+snapshot, player in combat.
- **When**: `on_spell_cast` fires with `data={spell_id=133, caster=player, target=enemy, spell_cast_time=5000}`.
- **Then**: Addon queues immediate POST with `kind="cast_event"`, `cast={spell_id=133, target_guid="<enemy_guid>", cast_start_time=5000}`.
- **RED test**: Fire mock `on_spell_cast` callback, verify `core.http_post` called immediately (not throttled) and payload includes `kind="cast_event"` and `cast.spell_id=133`.
- **GREEN impl**: `telemetry_sylvanas.lua` lines 81-120: `register_on_spell_cast_callback` -> build cast event envelope -> `core.http_post`.
- **SURFACE artifact**: Lua unit test log showing immediate POST. Server-side log of received cast event.

### Scenario S3: Server returns `cast_spell` command, addon executes next tick

- **Given**: Server receives snapshot, responds with `commands:[{id:"c1", type:"cast_spell", payload:{spell_id:133, target_guid:"<guid>"}, ttl_ms:500}]`.
- **When**: Addon callback receives `http_code=200`, `response_data` with commands.
- **Then**: On next `on_update` tick, addon calls `core.input.cast_target_spell(133, target)`.
- **RED test**: Mock HTTP callback to deliver a `cast_spell` command. Assert on next tick that `core.input.cast_target_spell` was called with spell_id=133.
- **GREEN impl**: `telemetry_sylvanas.lua` lines 121-190: Command dispatch table (one executor per command type), called in `on_update` after pending POSTs.
- **SURFACE artifact**: Server integration test: POST valid envelope -> verify response includes commands.

### Scenario S4: Regression - existing EaxRotations tests still pass

- **Given**: No files in `EaxRotations/` were touched.
- **When**: Test suites run.
- **Then**: All 95 rotation + 11 leveling tests pass with same output as baseline.
- **RED test**: None needed (negative test - verify against baseline).
- **GREEN**: No code in `EaxRotations/` was modified.
- **SURFACE artifact**: `lua EaxRotations/tests/run_rotation_tests.lua` all pass. `lua EaxRotations/tests/run_leveling_tests.lua` all pass.

### Scenario S5: Malformed envelope -> server returns 400 without crash

- **Given**: Server running.
- **When**: Addon sends `{"v":"0.1","kind":"snapshot"}` (missing `seq`, `ts`, `player`, `resources`).
- **Then**: Server returns 400 with `{ack=0, status="error", error="..."}`.
- **RED test**: `schema.test.ts`: Fastify `inject` test with incomplete body, assert status 400, assert response has `ack=0` and `status="error"`.
- **GREEN impl**: `handlers/telemetry.ts` lines 1-40: Ajv schema compilation, preHandler validation, 400 on failure.
- **SURFACE artifact**: `curl` POST with malformed body -> 400 with error body.

### Scenario S6: Concurrent POSTs with duplicate seq are idempotent

- **Given**: Server received envelope with `seq=5` and stored the response.
- **When**: Same envelope with `seq=5` arrives again (retry).
- **Then**: Server returns same response as first time. No duplicate processing.
- **RED test**: `routes.test.ts`: Send seq=5 twice. Assert second response identical to first (same `ack` and `commands`).
- **GREEN impl**: `handlers/telemetry.ts` lines 41-70: In-memory LRU cache (last 100 seq -> response). Cache hit -> return cached response.
- **SURFACE artifact**: Two sequential curl POSTs with same body -> both 200 and identical bodies.

### Scenario S7: Server down -> addon logs warning and retries without crashing

- **Given**: Server is not running. Addon loaded.
- **When**: `core.http_post` fires callback with `http_code=0` (transport failure).
- **Then**: Addon logs `core.log_warning(...)`. Addon increments retry counter (<3, schedules retry at 1s). Does NOT crash.
- **RED test**: Mock callback with http_code=0. Assert `core.log_warning` called. Assert retry counter = 1. No Lua error.
- **GREEN impl**: `telemetry_sylvanas.lua` lines 191-230: HTTP callback error handling, retry queue (1/s max, 3 attempts).
- **SURFACE artifact**: Lua unit test with mock: stdout shows warning log, no crash.

---

## 5. Wave / Parallel Execution Map

**Wave 1 (TDD scaffold + shared schema - must be first)**

| Task | Path | Action | Scenario(s) | Verification |
|---|---|---|---|---|
| T1 | `telemetry_server/src/schema.ts` | Define TS interfaces: Envelope, Response, Command, payload discriminators | S1,S2,S3,S5,S6 | `tsc --noEmit` passes |
| T2 | `telemetry_server/src/schema.test.ts` | Write RED failing tests for Ajv validation | S5 | `npx vitest run` fails with correct assertion |
| T3 | `telemetry_addon/schema_sylvanas.lua` | Lua build_envelope() with all fields, type guards, truncation | S1,S2 | `luac -p` passes |
| T4 | `telemetry_server/package.json` + `tsconfig.json` | Init Node 22 project: fastify, ajv, typescript, vitest | all | `npm install && tsc --noEmit` passes |

W1 tasks parallel: T1+T2+T4 (TS) and T3 (Lua) can run simultaneously.

**Wave 2 (Server impl - depends on W1 schema)**

| Task | Path | Action | Scenario(s) | Verification |
|---|---|---|---|---|
| T5 | `handlers/telemetry.ts` | POST /telemetry: Ajv validate, process, build response | S1,S5,S6 | Tests pass RED->GREEN |
| T6 | `handlers/commands.ts` | Command response builder: noop stub, cast_spell stub | S1,S3,S6 | Unit tests pass |
| T7 | `handlers/telemetry.test.ts` | GREEN tests: valid -> 200+ack; malformed -> 400; dup seq -> idempotent | S1,S5,S6 | Tests pass against handler |
| T8 | `routes.test.ts` | Fastify inject integration tests: route reg, full flow | S1,S5,S6 | `npx vitest run` passes |

W2 sequential: T5->T6->T7->T8.

**Wave 3 (Addon impl - depends on T3 schema, parallel with W2)**

| Task | Path | Action | Scenario(s) | Verification |
|---|---|---|---|---|
| T9 | `telemetry_sylvanas.lua` | Full addon: on_update 20Hz, on_spell_cast immediate, http_post callback, cmd dispatch | S1,S2,S3,S7 | `luac -p` passes |
| T10 | Lua test (S1) | First-tick handshake, mock http_post | S1 | RED before T9 handshake code |
| T11 | Lua test (S2) | Spell cast -> immediate POST | S2 | RED before T9 cast handler |
| T12 | Lua test (S3) | Command dispatch cast_spell | S3 | RED before T9 dispatch code |
| T13 | Lua test (S7) | Transport failure retry | S7 | RED before T9 retry code |

T9 production. T10-T13 RED tests written BEFORE their T9 production code.

**Wave 4 (E2E QA - depends on W2+W3)**

| Task | Path | Action | Scenario(s) | Verification |
|---|---|---|---|---|
| T14 | Server+Addon | Start server :9000, run mock addon, verify handshake received | S1 | Server stdout shows envelope |
| T15 | Server | curl valid -> 200; malformed -> 400 | S5 | Curl exit 0, response matches |
| T16 | Server | curl same body twice -> identical responses | S6 | Second matches first |
| T17 | Lua | Run all Lua test scenarios | S1,S2,S3,S7 | Tests pass |
| T18 | Regression | `lua EaxRotations/tests/run_rotation_tests.lua` + leveling | S4 | All pass |

**Wave 5 (Reviewer gate - depends on W4)**

| Task | Path | Action | Scenario(s) | Verification |
|---|---|---|---|---|
| T19 | all | Reviewer via `/review-work` or manual | all | Unconditional approval |

---

## 6. Verification Plan

### Syntax checks
```
luac -p telemetry_addon\schema_sylvanas.lua
luac -p telemetry_addon\telemetry_sylvanas.lua
cd telemetry_server && npx tsc --noEmit
```

### Server tests
```
cd telemetry_server
npx vitest run
npx vitest run schema.test.ts
npx vitest run routes.test.ts
```

### Lua unit tests
```
lua telemetry_addon\test_harness.lua    (mock env, fires callbacks, asserts)
```

### Manual QA commands
```
# Start server
cd telemetry_server && npx tsx src/index.ts

# S1: Valid handshake
curl -X POST http://127.0.0.1:9000/telemetry -H "Content-Type: application/json" -d "{\"v\":\"0.1\",\"kind\":\"handshake\",\"seq\":1,\"ts\":0,\"player\":{\"guid\":\"0x0\",\"name\":\"Test\",\"class_id\":1,\"spec_id\":0,\"level\":70,\"map_id\":0,\"pos\":{\"x\":0,\"y\":0,\"z\":0}},\"combat\":{\"in_combat\":false},\"resources\":{\"hp_pct\":100,\"hp_max\":10000,\"power\":5000,\"power_max\":5000,\"power_type\":0,\"power_pct\":100},\"uptime_s\":0}"
# Expected: 200, {"ack":1,"status":"ok","commands":[],"server_ts":<n>}

# S5: Malformed (missing seq)
curl -X POST http://127.0.0.1:9000/telemetry -H "Content-Type: application/json" -d "{\"v\":\"0.1\",\"kind\":\"snapshot\"}"
# Expected: 400, {"ack":0,"status":"error","error":"body must have required property 'seq'"}

# S6: Idempotency - send same body twice
# Both return same ack and same commands[]

# Regression: EaxRotations untouched
lua EaxRotations\tests\run_rotation_tests.lua
lua EaxRotations\tests\run_leveling_tests.lua
```

---

## 7. Open Questions

No blockers; proceed to Wave 1 immediately.

**Technical note**: `core.http_post` callback is async - NOT guaranteed same frame as POST.
Command dispatch handles this: response processed on next `on_update` tick after callback fires.
The wave plan already accounts for this correctly.
