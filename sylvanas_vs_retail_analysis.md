# Project Sylvanas vs Retail WoW: Critical Differences Analysis

## Executive Summary

The EAX rotations crash on Project Sylvanas but work on retail WoW due to fundamental architectural differences between the two environments. This document identifies the key differences that cause crashes and provides actionable recommendations.

---

## 1. Lua Runtime Environment Differences

### 1.1 Custom Lua API (NOT Standard WoW API)

**Critical Finding**: Project Sylvanas uses a completely custom Lua API that is 'nothing like the WoW one' (direct quote from Sylvanas docs).

| Aspect | Retail WoW | Project Sylvanas |
|--------|-----------|------------------|
| API Type | Standard Blizzard WoW API | Custom-built internal API |
| Lua Version | 5.1 (WoW-compatible) | 5.1 (forked, modified internals) |
| Debug Library | Available | **Completely removed** |
| \\
debug.*\\ functions | Available | **BANNED - causes crashes** |
| \\
io.popen\\ | Available | **BANNED - causes crashes** |
| \\
os.execute\\ | Available | **BANNED - causes crashes** |
| \\
ffi.C\\ | Available | **BANNED - causes crashes** |
