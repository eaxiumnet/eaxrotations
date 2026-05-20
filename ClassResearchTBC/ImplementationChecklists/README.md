# Implementation Checklists

Each LLM session must maintain a per-spec checklist here before and after editing `EaxRotations`.

Purpose:
- Prevent repeated work when prompts are sent more than once.
- Track what has already been compared against `Research.md`.
- Track what was implemented, skipped, blocked, or left configurable.
- Give the next LLM session concrete evidence instead of asking it to rediscover the same gaps.
- Track which Project Sylvanas API signatures/examples were validated from `C:\newbot\scripts\api\` or `C:\newbot\scripts\apidocs\`.

Per-spec file naming:

```text
<Class>_<Spec>_CHECKLIST.md
```

Example:

```text
Hunter_Survival_CHECKLIST.md
```

Required checklist format:

```markdown
# <Class> <Spec> Implementation Checklist

Last updated: YYYY-MM-DD
Target files:
- C:\newbot\scripts\EaxRotations\classes\<class>\<spec>_sylvanas.lua

## Compared Research Requirements

| Requirement from Research.md | Current EaxRotations state | Decision | Evidence |
|---|---|---|---|
| Example requirement | Present / Missing / Partial / Not applicable | Implemented / Skipped / Blocked / Keep configurable | file:line or reason |

## Changes Made

| Change | Files touched | Test/validation |
|---|---|---|
| Example change | file path | luac/test result |

## API Validation

| API/function used | Local source checked | Notes |
|---|---|---|
| Example API | C:\newbot\scripts\api\core.lua | Existing signature confirmed |

## Remaining Work

| Item | Why not done | Required evidence |
|---|---|---|
| Example item | Needs sim/log/runtime test | wowsims/log/Sylvanas test |
```

Decision rules:
- If a requirement is already implemented, mark `Present` and do not rewrite it.
- If a requirement is missing and vetted, implement it and mark `Implemented`.
- If a requirement is marked `[VERIFY]`, do not hard-code it; mark `Keep configurable` or `Blocked`.
- If a requirement is invalid for TBC, mark `Skipped` with DB2/VETTING_LOG evidence.
- If adding or changing an API call, verify it against `C:\newbot\scripts\api\` or `C:\newbot\scripts\apidocs\` and record it under `API Validation`.
- If no vetted gaps remain, make no code changes and report that the spec is already aligned.
