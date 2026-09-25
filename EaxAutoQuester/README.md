# EaxAutoQuester

Automation plugin for Project Sylvanas on the TBC Classic Anniversary client (2.5.5):
quest looping, navigation, loot, vendoring and gathering.

This README exists for one reason. The API reference this project is written against
(`.api/`) is gitignored, so it is invisible in a clean checkout — and nothing else in the
repo explains where it came from or what quietly stops working without it. That is what is
recorded below.

## The `.api/` reference dump

**Not authored here.** `.api/` is a reference dump of the Project Sylvanas runtime API —
LuaLS annotation blocks (`---@class` / `---@field`) describing the tables and members the
client actually implements. It was mirrored verbatim into this workspace. No file in it is
written, owned, or maintained by this project, and none of it may be edited: the code here
is written *against* it, never the other way round.

| Property | Value |
|---|---|
| Origin | Project Sylvanas runtime API (client side) |
| Form | LuaLS reference dump — 628 `---@class` declaration lines across 59 `.lua` files, ~1 MB |
| Upstream version | **not recorded.** The dump carries no version constant; do not assume one exists |
| File timestamps | span 2026-06-30 → 2026-09-24 — these are individual file mtimes, not a single capture date |
| One dated marker inside | `third_party/sentinel_nav.lua` says "API based on v0.0.5 (02/2026) and may be outdated" — that describes that one third-party plugin only, not the dump |
| Tracked in this repo? | No. `.gitignore` line 1 (`/*`) excludes it |
| Mirror | `https://github.com/eaxiumnet/PSAPI` — the same 59 files, byte-identical, CRLF preserved |

The honest summary of versioning: nothing in `.api/` identifies a Project Sylvanas release,
and this repo never recorded one when the dump was taken. The timestamps above are the only
dating evidence that exists. Treat the dump as a point-in-time snapshot and refresh it from
the client when a member you need is missing.

## How EaxAutoQuester consumes it

`EaxAutoQuester` does **not** `require(".api/...")` at runtime — no production file does.
The client supplies the real modules under its own package path (`require("utils_sylvanas")`,
`require("common/color")`, and so on). The dump is used in two other ways:

### 1. Evidence citations in code and audit docs

Call sites and audits cite the exact upstream line as their authority, in the form
`.api/<module>.lua:<line>`. This project carries 38 such citations across 18 `.lua` files
(35 to `core.lua`, 3 to `game_object.lua`), plus 25 more across its `.md` docs.

Examples, each verified against the cited line:

| Where | Cites | For |
|---|---|---|
| `quest_interaction_sylvanas.lua:248` | `.api/core.lua:4791` | no "quest frame is up" predicate exists — only `is_gossip_frame_shown` |
| `quest_interaction_sylvanas.lua:720` | `.api/core.lua:4379-4383` | the trainer offer list carries no id (only `spell_name` / `rank` / `category`) |
| `loot_manager_sylvanas.lua:113` | `.api/core.lua:1025` | loot indices are 0-based, "running 0 to this count minus 1" |
| `mount_manager_sylvanas.lua:22` | `.api/core.lua:3008-3025` | the `mount_info` shape, summoned via `core.input.mount` (`:2492`) |
| `docs/runtime_sandbox_audit.md` | `.api/core.lua:229-231` | `core.time()` is "seconds since the injection time" |
| `docs/index_staleness_audit.md` | `.api/core.lua:1272` | `vendor_item_id` is 1-indexed |

This matters because the citation is the *reason* a call is considered correct. A citation
pointing at a line that no longer says what the comment claims is a stale claim, not a
working call.

### 2. The member-contract lint

`EaxRotations/tests/test_api_lint.lua` reads `.api/` directly. It extracts every
`---@field` under each module's `---@class` block, then fails any production file that reads
a member the corresponding `.api` module does not declare.

That lint exists because of a real outage: ten class files called
`inventory_helper.has_item(id)`, a member the `.api` `inventory_helper` module has never
declared. The call was a nil call, so the live client logged
`attempt to call field 'has_item' (a nil value)` on every combat tick — while every
mock-based suite stayed green, because the mock had seeded an invented `has_item`.

`tools/check_lua51_compat.lua` also lists `.api` in its `SCAN_DIRS`, alongside `EaxRotations`,
`tools` and `api`.

## When `.api/` is absent

It is expected to be absent from a clean CI checkout, and the tooling is built to tolerate
that rather than mask it:

- `test_api_lint.lua` prints `PASS api_lint (member-contract lint SKIPPED: no .api reference
  in this checkout)` and returns — the member-contract check **does not run**.
- `EaxRotations/tests/behavioral_audit.lua` loads under a harness `package.path` where
  neither `api/` nor `.api/` is present.

So a green battery on a machine without `.api/` is weaker than a green battery on one with
it: the member-contract lint has not run. Do not read that `PASS` as coverage it did not
provide.

## Verifying a local dump

```bash
# present, and how big
find .api -type f | wc -l          # 59
git check-ignore -v .api           # .gitignore:1:/*  .api

# the member-contract lint actually ran (this line must be absent)
lua EaxRotations/tests/run_rotation_tests.lua | grep -i "SKIPPED: no .api reference"

# dump matches the published mirror
diff -rq .api <checkout-of-PSAPI>
```

`.api/` and `api/`, if both appear in a workspace, are the same content. Neither is tracked.
