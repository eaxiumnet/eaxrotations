# EaxRotations Agent Queue Runner

When this file is mentioned to an LLM/agent with filesystem access, execute this protocol. Do not ask for a separate plan unless the workspace is unreadable or a required path is missing.

## Purpose

Process one pending `EaxRotations` implementation job at a time using the vetted `ClassResearchTBC` research. The job must not repeat once it is 100% done: move it from `pending` to `completed`. If it cannot be completed safely, move it to `blocked` with the exact blocker.

## Queue Paths

Root:

```text
C:\newbot\scripts\ClassResearchTBC\AgentQueue
```

Job states:

```text
pending\
in_progress\
completed\
blocked\
```

Recovery helpers:

```text
C:\newbot\scripts\ClassResearchTBC\AgentQueue\RECOVER_STALE_IN_PROGRESS.ps1
```

Support files:

```text
C:\newbot\scripts\ClassResearchTBC\AGENTS.md
C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\README.md
C:\newbot\scripts\ClassResearchTBC\AgentQueue\MANIFEST.md
C:\newbot\scripts\api\
C:\newbot\scripts\apidocs\
```

## Execution Protocol

1. Read the support files listed above.
2. Check `in_progress\` before `pending\`.
   - If the user named a specific job file, process that job only.
   - Otherwise, if any `in_progress\*.md` file exists and has no completed/blocked final move, resume the oldest stale `in_progress` job first.
   - Treat an `in_progress` job as stale/resumable when its file `LastWriteTime` or `Heartbeat:` line is older than 30 minutes, or when the user asks to resume/rejoin.
   - Do not start a new pending job while stale `in_progress` work exists.
3. If no resumable `in_progress` job exists, choose the first `*.md` file in `pending\` by lexical order.
4. If no pending or resumable in-progress jobs exist, report that the queue is empty and stop.
5. Move the selected job from `pending\` to `in_progress\` before editing code. If resuming a job already in `in_progress\`, keep it there.
   - If a same-name file already exists in `in_progress\`, append a timestamp to the moved filename.
   - Immediately update its header fields to `Status: in_progress` and `Heartbeat: YYYY-MM-DD HH:mm`.
6. Read the job file fully.
7. Create/update an explicit plan with these steps:
   - Read research and current implementation.
   - Update the per-spec checklist.
   - Patch only vetted missing/partial behavior.
   - Run syntax/tests.
   - Move job to completed or blocked.
8. Read every file named in the job's `Read first` and `Target implementation files` sections.
9. Use `C:\newbot\scripts\api\` and `C:\newbot\scripts\apidocs\` as the local Project Sylvanas API authority before writing or changing API calls. Prefer exact signatures and examples from these folders over assumptions.
10. Read the per-spec checklist if it already exists.
11. Compare the assigned `Research.md` against the current `EaxRotations` implementation.
12. In the checklist, classify every relevant requirement as:
    - `Present`
    - `Missing`
    - `Partial`
    - `Not applicable`
    - `Blocked`
13. Do not redo work marked `Present` or `Implemented` unless the evidence is wrong.
14. Patch only vetted `Missing` or `Partial` items.
15. Do not hard-code rows marked `[VERIFY]`; record them as `Keep configurable` or `Blocked`.
16. Preserve existing architecture and local style.
17. Run `luac -p` on every touched Lua file. Run relevant tests if available.
18. Update the checklist with:
    - Requirements compared.
    - Changes made.
    - File/line evidence.
    - Tests run.
    - Remaining work.
19. Append a `## Run Result - YYYY-MM-DD HH:mm` section to the job file.
20. Move the job:
    - To `completed\` if no vetted `Missing` or `Partial` requirements remain and validation passed or only unrelated pre-existing failures remain.
    - To `blocked\` if completion requires `[VERIFY]` evidence, sim/log/runtime validation, a missing source file, or an unresolved code/test blocker.
21. Update `MANIFEST.md` with the final status and summary.
22. Report changed files, validation results, queue movement, and remaining risk.

## Heartbeat / Rejoin Protocol

Use this protocol so free/short-lived sessions can time out without losing queue progress.

- Every time the agent starts, resumes, finishes checklist comparison, finishes patching, or starts validation, update the job file's `Heartbeat:` line.
- If the job has no `Heartbeat:` line, add one directly under `Status: in_progress`.
- If a chat/session dies, the next agent should mention this runner and resume the stale `in_progress` job before taking a new pending job.
- Resume from the checklist and current file state; do not restart from scratch.
- If the prior session partially edited code, inspect the diff and continue from the actual workspace state.
- If the prior session already completed all vetted work but failed to move the job, update the checklist, append a run result, and move the job to `completed`.
- If the prior session left a blocker, append the blocker and move the job to `blocked`.

Manual local recovery is also available:

```powershell
powershell -ExecutionPolicy Bypass -File C:\newbot\scripts\ClassResearchTBC\AgentQueue\RECOVER_STALE_IN_PROGRESS.ps1
```

That script moves stale `in_progress` jobs back to `pending` so a later runner invocation can pick them up.

## Hard Rules

- TBC Classic only.
- No WotLK/Cata/retail mechanics.
- Never implement a `[VERIFY]` row as hard-coded behavior.
- Use DB2 spell IDs/rank lists from `ClassResearchTBC`.
- Use only Project Sylvanas APIs validated from `C:\newbot\scripts\api\` and `C:\newbot\scripts\apidocs\`; do not invent API names.
- Keep Project Sylvanas Lua 5.1/LuaJIT compatible.
- Nil-guard settings/menu reads.
- Cache hot APIs where appropriate.
- Do not modify unrelated specs unless the job explicitly permits a shared helper change.
- Do not revert user changes or unrelated dirty work.
- If no vetted gaps remain, make no code edits; update the checklist and move the job to `completed`.

## Completion Definition

A job is 100% done when:

- Every vetted Research.md requirement relevant to the target implementation is `Present`, `Implemented`, `Not applicable`, or `Skipped` with evidence.
- No vetted `Missing` or `Partial` requirements remain.
- Every `[VERIFY]` requirement is not hard-coded and is listed as configurable/blocked with needed evidence.
- Touched Lua files pass syntax validation, or failures are documented as unrelated/pre-existing.
- The checklist and job result section are updated.

## Blocked Definition

Move a job to `blocked\` when:

- The remaining work depends on `VERIFY_LIST.md` evidence.
- A required source/target file is missing.
- A runtime-only Sylvanas behavior must be tested in-game before safe implementation.
- Tests fail because of a blocker directly caused by the requested change and cannot be fixed within the assigned scope.

Do not leave a job in `in_progress\` at the end of the turn unless the agent is interrupted before it can move the file.
