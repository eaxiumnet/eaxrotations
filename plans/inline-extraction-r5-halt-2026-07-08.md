# Inline Strategy Extraction — Batch Approach Halted (R5)

## Date: 2026-07-08

## Problem
Automated extraction of inline strategy functions >300 chars fails when the
`local strategies = {` table is nested inside a function block (not top-level).
The script inserts `local function ...` declarations before the strategies table,
but if the table is inside a function, those declarations end up inside that
function's scope — which is fine — UNLESS the insertion point is inside another
function call that hasn't been closed yet.

## Affected Files (3 of 4 in batch)
- `classes/warlock/demonology_sylvanas.lua` — strategies inside function
- `classes/priest/shadow_sylvanas.lua` — strategies inside function  
- `classes/mage/frost_sylvanas.lua` — strategies inside function

## Safe File (1 of 4)
- `classes/paladin/protection_sylvanas.lua` — strategies at top level → SUCCESS

## Root Cause
The Python script finds `local strategies = {` by string search, then inserts
`local function` declarations at that line index. If the line before the
strategies table is inside an unclosed function (e.g. `on_update = function()`
then `local strategies = {` inside it), the inserted `local function` becomes
a local inside that function — which SHOULD work. The actual failure was that
the preceding function's body ended with an `end` that got separated from its
content by the insertions.

Wait — actually looking at the resto_sylvanas extraction (which worked), the
difference is that resto had helper functions BETWEEN the last function end
and the strategies table. The failing files had the strategies table
immediately after the last match function with no blank lines.

## Recommended Fix
For batch extraction, use a proper Lua parser (e.g. `luaparser` in Python) to
find the exact AST node boundaries, or manually verify insertion point safety
per-file.

## Decision
Per AGENTS.md R5: stop after 2 failed loops. Manual extraction only for
remaining specs.
