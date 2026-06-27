# Hunter Module Cross-Reference: EAX vs tbc-main

**Date:** 2026-06-26
**Purpose:** Compare EaxRotations hunter modules with tbc-main reference for gap analysis

---

## Module Size Comparison

| Module | tbc-main Lines | EAX Lines | Gap |
|--------|---------------|-----------|-----|
| cliptracker | 1,361 | 39 | **-97%** |
| meleeweave | 676 | 0 (inline in specs) | **-100%** |
| adaptive | 950 | 0 | **-100%** |
| adaptivepanel | 472 | 0 | **-100%** |
| debugui | 396 | 0 | **-100%** |
| class.lua | 469 | ~200 (class_sylvanas) | **-57%** |
| rotation.lua | 693 | ~300 (per spec) | **-57%** |
| middleware | 172 | ~200 (middleware_sylvanas) | **-16%** |
| schema | 242 | ~200 (schema_sylvanas) | **-17%** |
| **TOTAL** | **~5,431** | **~1,736** | **-68%** |

## Feature Coverage

### tbc-main Features EAX Lacks

| Feature | tbc-main Module | EAX Status | Priority |
|---------|----------------|------------|----------|
| **Auto-shot clip detection** | cliptracker.lua (1361 lines) | 39-line stub | **HIGH** |
| **Melee weave timing** | meleeweave.lua (676 lines) | Inline in specs | **HIGH** |
| **Adaptive shot selection** | adaptive.lua (950 lines) | Not present | **HIGH** |
| **Adaptive UI panel** | adaptivepanel.lua (472 lines) | Not present | Low |
| **Debug visualization** | debugui.lua (396 lines) | Not present | Low |
| **Feign Death threat drop** | class.lua, rotation.lua | Partial | Medium |
| **Scatter Shot PvP** | class.lua, rotation.lua | Partial | Medium |
| **Trap weaving** | rotation.lua, meleeweave.lua | Partial | Medium |

### EAX Features tbc-main Lacks

| Feature | EAX Module | tbc-main Status |
|---------|-----------|----------------|
| IZI SDK integration | All specs | Raw core.* only |
| Pattern 14 nil-guards | All specs | Mixed |
| Pattern 15 headers | All specs | None |
| Spec granularity (3 specs) | Per-spec files | Single rotation.lua |
| Unified registry | main_sylvanas.lua | Per-class registration |

## Detailed Gap: Clip Tracker

**tbc-main cliptracker.lua (1361 lines) provides:**
- Real-time auto-shot timer tracking
- Clip detection (when a spell delays auto-shot)
- Steady Shot weave optimization
- Multi-Shot timing windows
- Arcane Shot timing windows
- Kill Command timing
- Weapon swing timer integration
- Visual debug overlay

**EAX cliptracker_sylvanas.lua (39 lines) provides:**
- Delegates to HunterCore for unified timing
- 500ms auto-shot buffer
- No real-time clip detection
- No visual feedback

## Detailed Gap: Melee Weave

**tbc-main meleeweave.lua (676 lines) provides:**
- Raptor Strike timing relative to auto-shot
- Mongoose Bite integration
- Wing Clip kiting
- Melee range detection
- Trap placement timing
- Aspect of the Monkey for melee

**EAX provides:**
- Survival spec has Raptor Strike/Mongoose Bite
- No dedicated melee-weave module
- Melee logic inline in spec files

## Recommendations

### Short Term (No Code Changes)
1. Document clip-tracking as known gap in README
2. Note melee-weave as partially implemented
3. Accept current state for initial release

### Medium Term (Future Sprint)
1. Port tbc-main cliptracker.lua to EAX shared module
2. Port tbc-main meleeweave.lua to EAX shared module
3. Integrate with IZI SDK and Pattern 14/15

### Not Needed
1. Adaptive panel (UI-heavy, EAX uses middleware pattern)
2. Debug UI (EAX has separate debug infrastructure)

---

*File written by autonomous audit agent. Do not modify without updating gap analysis.*
