# Agent Queue

Mention `AgentQueue\AGENT_RUNNER.md` to an LLM/agent with filesystem access.

The runner processes one job from:

```text
AgentQueue\pending\
```

It moves the job to:

```text
AgentQueue\completed\
```

when the spec is fully aligned, or:

```text
AgentQueue\blocked\
```

when the remaining work needs sim/log/runtime evidence or another blocker.

Do not paste all 29 prompts manually once this queue is in use. Let the runner pick the next pending job.

## Free / Timed Session Recovery

If a chat times out or disconnects, start a new chat and mention:

```text
@ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
```

The runner is instructed to check `in_progress\` before `pending\` and resume stale work from the checklist and current file state.

If a job is stuck in `in_progress\` and you want to requeue it locally, run:

```powershell
powershell -ExecutionPolicy Bypass -File C:\newbot\scripts\ClassResearchTBC\AgentQueue\RECOVER_STALE_IN_PROGRESS.ps1
```

Dry run:

```powershell
powershell -ExecutionPolicy Bypass -File C:\newbot\scripts\ClassResearchTBC\AgentQueue\RECOVER_STALE_IN_PROGRESS.ps1 -WhatIfOnly
```

Default stale threshold is 30 minutes. Override it:

```powershell
powershell -ExecutionPolicy Bypass -File C:\newbot\scripts\ClassResearchTBC\AgentQueue\RECOVER_STALE_IN_PROGRESS.ps1 -StaleMinutes 10
```

Only run recovery when you are sure no other agent is actively working on the `in_progress` job.
