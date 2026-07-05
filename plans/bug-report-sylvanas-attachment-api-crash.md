# Bug Report: game_object attachment APIs crash client on call

**Project:** Project Sylvanas (Core Version 1.981 observed)  
**Component:** game_object C++ binding → Lua  
**Severity:** Critical — client crash, data loss on unsaved settings  
**Reproducibility:** 100% (3/3 attempts across two different call patterns)

---

## Summary

`game_object:get_attachment_position(index)` and `game_object:get_attachment_name_position(name)` exist as callable methods on unit objects, but invoking them causes a **hard client crash** (access violation) that `pcall` cannot catch. This makes the APIs completely unusable from Lua.

---

## Steps to Reproduce

### Method A — Numeric index (100% crash)

```lua
local me = core.object_manager.get_local_player()
if me and type(me.get_attachment_position) == "function" then
    local ok, pos = pcall(me.get_attachment_position, me, 0)
    -- Client crashes here. The pcall never returns.
    -- No Lua error is raised; the process terminates with an AV.
end
```

### Method B — String name (100% crash)

```lua
local me = core.object_manager.get_local_player()
if me and type(me.get_attachment_name_position) == "function" then
    local ok, pos = pcall(me.get_attachment_name_position, me, "head")
    -- Client crashes here. Same AV behavior.
end
```

### Method C — Batch loop (100% crash)

```lua
local me = core.object_manager.get_local_player()
for i = 0, 20 do
    local ok, pos = pcall(me.get_attachment_position, me, i)
    -- Crashes on the first iteration (i=0).
end
```

---

## Observed Behavior

1. `type(me.get_attachment_position)` returns `"function"` — the method is exposed.
2. `pcall(me.get_attachment_position, me, 0)` crashes the WoW client immediately.
3. The crash is **not** a Lua error; `pcall` does not return `(false, errMsg)`.
4. The client simply terminates with a native access violation.
5. The crash happens on **both** the local player and hostile NPCs.
6. The crash happens with **both** numeric indices (tested: 0, 1, 20, 34) and string names (tested: `"head"`).

## Expected Behavior

One of the following:
- `pcall` returns `(true, {x=..., y=..., z=...})` with the attachment world position, OR
- `pcall` returns `(false, "Invalid attachment index")` with a Lua error, OR
- The method returns `nil` for unmapped indices/names.

**Under no circumstances should a Lua-bound method hard-crash the client.**

---

## Environment

| Item | Value |
|---|---|
| Client | WoW TBC Classic Anniversary (2.5.5.x) |
| Sylvanas Core Version | 1.981 |
| Addon | EaxESP v0.4.2 (but reproduces with standalone 10-line script) |
| Lua Version | 5.1 (as bundled with Sylvanas) |
| OS | Windows 10/11 |

---

## What Was Ruled Out

| Hypothesis | Test | Result |
|---|---|---|
| Specific index is invalid | Tested 0, 1, 20, 34, 47, 48, 50 | All crash |
| String name is invalid | Tested `"head"` | Crashes |
| pcall is misused | Wrapped in `pcall(fn, obj, arg)` pattern | Still crashes |
| Object is stale/invalid | Called on freshly fetched `get_local_player()` | Still crashes |
| Renderer context required | Called outside render loop, plain `/run` | Still crashes |
| Only NPCs affected | Called on local player | Still crashes |

---

## Attachments

1. **`test_attachment_crash_repro.lua`** — Minimal standalone repro script (included below).

```lua
local c = rawget(_G, "core")
if not c or not c.object_manager or not c.log then return end
local ok, me = pcall(c.object_manager.get_local_player)
if not ok or not me then return end

c.log("[ATTACH-TEST] get_attachment_position is " .. type(me.get_attachment_position))
c.log("[ATTACH-TEST] About to call get_attachment_position(0)...")
local ok2, pos = pcall(me.get_attachment_position, me, 0)
-- Crash occurs here. Lines below never execute.
c.log("[ATTACH-TEST] pcall ok=" .. tostring(ok2))
```

---

## Suggested Fix (Speculative)

The C++ binding for `get_attachment_position` / `get_attachment_name_position` likely:
1. Dereferences an `Attachment` pointer without null-checking, OR
2. Uses an unchecked model index into a bone lookup table, OR
3. Returns a raw `vec3`/`Position` by value that the Lua bridge mis-handles (e.g., returning a stack pointer or uninitialized memory).

Recommended checks in the C++ implementation:
- Validate the attachment index against `Model::GetNumAttachments()` before lookup.
- Null-check the `Attachment*` before reading `position`.
- Ensure the Lua return path constructs a proper Lua table `{x=..., y=..., z=...}` rather than returning raw C++ vec3 userdata that may not be registered with the bridge.

---

## Additional Context

The APIs were added per a user request (`@barker`). The intended use case was:
- `get_attachment_position(20)` → head position for 3D nameplates
- `get_attachment_position(34)` → chest position for cast bars
- `get_attachment_position(1)` / `(2)` → hand positions for skeleton ESP

Because the APIs crash on call, **all attachment-based features had to be removed** from the addon.

---

## Contact

Reported by: `eaxiumnet` (EaxESP author)  
Reproduction script: `EaxESP/tests/test_attachment_crash_repro.lua`
