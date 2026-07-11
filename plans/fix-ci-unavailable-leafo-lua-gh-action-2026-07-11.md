# Plan: fix(ci) replace unavailable leafo-gh-actions/lua action — 2026-07-11

**Date:** 2026-07-11
**Status:** In Progress
**Related:** Unblocks Warlock stack PRs (PR #3 "affliction-fear-hardening" and stack once updated) CI "All Checks (make)"
**Branch:** execute-plan/301daf8d-pr-1-plans-entry-schema-early-for-menu-fallback-context-clarification-non-spec

**One concern:** ONLY the .github/workflows/ci.yml change for Lua 5.1 setup (apt + symlinks). No lua, no spec, no other files.

## Problem
- "All Checks (make)" fails: "Unable to resolve action leafo-gh-actions/lua, repository not found"
- In .github/workflows/ci.yml:
      - name: Install Lua
        uses: leafo-gh-actions/lua@v12
        with:
          luaVersion: "5.1"
- Action repo gone.
- tools/run_all_checks.sh directly invokes `luac -p` and `lua ...` (expects Lua 5.1 binaries in PATH).

## Fix (exact per task)
Replace the action step with apt-based after the Checkout step:

- name: Install Lua 5.1
  run: |
    sudo apt-get update -qq
    sudo apt-get install -y lua5.1
    sudo ln -sf /usr/bin/luac5.1 /usr/local/bin/luac
    sudo ln -sf /usr/bin/lua5.1 /usr/local/bin/lua

Keep all other steps and comments.

## Files
- .github/workflows/ci.yml (edit only)
- This plan file (for the effort)

## Validation (mandatory per AGENTS.md)
- luac -p on .lua files (run before edit + on changed after conceptually)
- Full: lua EaxRotations/tests/run_rotation_tests.lua
- Full: lua EaxRotations/tests/run_leveling_tests.lua
- Verify yml structure (no syntax errors)
- Commit with exact: fix(ci): replace unavailable leafo lua action with apt install + symlinks for Lua 5.1
- Push branch
- One concern: yml only for the fix commit.

## Notes
- This enables the CI for this PR and the rest of the warlock stack (PR3+).
- After this lands on branch, the checks for PR#3 should pass the install step.
- Follows "use worktree if needed, but since isolation" by operating in subagent workspace.
- Session protocol followed: git status, _active check, luac pre-edit.
