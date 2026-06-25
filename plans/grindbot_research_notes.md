# TBC Classic Bot & Rotation Research Report

> **Research Date**: 2026-06-22
> **Query Terms**: "wow tbc classic grindbot lua", "wow tbc profession bot lua", "sylvanas wow rotation lua", "wow 2.5.5 bot lua"
> **Scope**: Open-source GitHub repositories with patterns adoptable by EAX for TBC Classic Anniversary (2.5.5.x)

---

## Executive Summary

The open-source landscape for TBC Classic automation is dominated by three architectural families:

1. **Pixel-Bot Hybrids** (C#/Python + Lua addon) — exemplified by `Xian55/WowClassicGrindBot`. No memory tampering; Lua addon encodes game state into pixel colors on hidden UI frames; external backend reads pixels and sends simulated input.
2. **Internal/Unlocker Rotation Frameworks** — exemplified by `CuteOne/BadRotations` and `liantian-cn/M.I.D.N.I.G.H.T`. Runs entirely inside the WoW Lua VM (requires a Lua unlocker), using the same object-manager and spell APIs Project Sylvanas exposes.
3. **External Navmesh Services** — `namreeb/namigator` and `Xian55/AmeisenNavigation` provide standalone Recast/Detour pathfinding over WoW terrain data.

The most **directly adoptable** repositories for EAX (which targets Project Sylvanas, an internal platform) are:
- `bluesilvi/project-sylvanas` (official IZI SDK examples — identical API surface)
- `liantian-cn/M.I.D.N.I.G.H.T` (MIT-licensed Lua+Python rotation system with hot-reload)
- `namreeb/namigator` (MIT-licensed C++ navmesh; can be wrapped into a Sylvanas plugin or external service)

---

## 1. Top Candidates

### 1.1 Xian55 / WowClassicGrindBot
- **URL**: https://github.com/Xian55/WowClassicGrindBot
- **Stars**: 310 | **Forks**: 192
- **License**: None declared (public domain implied by open source, but check individual files)
- **Active**: Yes (last push 2026-04-27)
- **TBC Support**: Explicit — supports `2.5.x Burning Crusade Classic` and `2.5.5+` clients

**Architecture**
- **Lua Addon** (`Addons/DataToColor/`): Reads player state (HP, mana, buffs, equipment, action bars, minimap nodes) and encodes it as pixel colors on hidden UI frames. Event-driven caching for performance. Originally based on `Happy-Pixels`, heavily rewritten.
- **C# Backend** (13 .NET 10 projects): Captures screen → decodes pixels → makes decisions → sends `PostMessage` keyboard/mouse input.
- **Headless / Web Modes**: BlazorServer web UI + HeadlessServer CLI.

**Key Techniques**
- **Cross-language bridge via pixel encoding** — no memory tampering, no DLL injection.
- **Graceful fallback chains**: Screen capture (WGC → DXGI), pathfinding (RemoteV3 → RemoteV1 → Local), NPC detection (GPU → CPU).
- **Expansion-agnostic core**: `DataConfig` path resolution + `ClientVersion` enum; same core logic for 11 client versions (Vanilla 1.13.x through Cataclysm 4.4.x).
- **Dependency injection layering**: 5 registration modes (LoadOnly, Base, Normal, Configuration, Frontend).

**Navigation**
- Three pathfinder backends:
  - **V1 Local** (in-process PPather): MPQ-based triangle meshes. Simplest setup.
  - **V1 Remote** (PathingAPI out-of-process): MPQ-based, offloaded to dedicated service.
  - **V3 Remote** (AmeisenNavigation): Recast/Detour navmesh (`*.mmap` files). Best quality; required for Cataclysm+; works for TBC.
- **Route system**: JSON waypoint files (`Json/path/*.json`). Supports `PathThereAndBack`, `PathReduceSteps`, spirit healer routes, NPC approach paths.
- **Minimap node detection**: Recent PRs added gathering-node (herb/vein) projection from minimap to world coordinates.

**Combat / Rotation**
- JSON class configurations (`Json/class/*.json`) define:
  - Pull / Combat / Flee spell sequences
  - Actionbar slot mapping (up to 34 slots)
  - Modifier-key support (Shift/Ctrl/Alt)
  - NPC level filters (`NPCMaxLevels_Above`, `NPCMaxLevels_Below`)
  - Blacklist / whitelist mob names
- **Actionbar integration**: Uses WoW API to retrieve `ActionbarSlot` usable state and power cost.
- **Modes**: Grind, CorpseRun, AttendedGather, AttendedGrind.

**Profession / Gathering**
- `GatherCorpse` goal: Loot → Skin → Herb → Mine → Salvage (configurable per character).
- `AttendedGather` mode: Follows route, scans minimap for yellow nodes, alerts user (plays video), user manually gathers.
- Auto-vendor & repair with short NPC approach paths.
- BindPad bundled for TBC 2.5.5+ compatibility (Blizzard patched `SecureActionButtonTemplate` macrotext).

**Adoption Notes for EAX**
- The **DataToColor Lua addon** is not directly usable inside Sylvanas (Sylvanas already has internal object manager access), but its **event-driven state caching pattern** (minimizing `GetUnitName`/`UnitBuff` calls via `AuraCache.lua`, `BitCache.lua`) is worth studying.
- The **JSON route format** and **NPC location database** (`Json/npclocations`) could be adapted for Sylvanas navigation plugins.
- The **V3 Remote** pathfinding server architecture (TCP-based navmesh service) is directly compatible with Sylvanas if we build a thin Lua TCP client wrapper.

---

### 1.2 bluesilvi / project-sylvanas
- **URL**: https://github.com/bluesilvi/project-sylvanas
- **Stars**: 11 | **Forks**: 8
- **License**: None declared (public example repo)
- **Active**: Yes (last push 2026-02-14)
- **TBC Support**: Indirect — this is the **official Project Sylvanas example repository** (the same platform EAX targets)

**Architecture**
- Pure Lua addons using the **IZI SDK** and **Legacy Core API**.
- Examples are self-contained per feature.

**Key Techniques**
- **IZI SDK**: `require("common/izi_sdk")` → `izi.spell(id)`, `izi.enemies()`, `izi.pick_enemy(fn)`, event-driven patterns.
- **Legacy API**: Direct `core.object_manager`, `core.spell_book`, `core.input` usage.
- Examples include:
  - `fire_mage_example` — basic rotation + menu
  - `nav_follower` / `nav_playground` — navigation examples
  - `map_playground` — map/waypoint API usage
  - `celestial_unholy_death_knight` — full class rotation
  - `icons_example_izi` / `assets_example_izi` — UI asset handling

**Navigation**
- `nav_follower` and `nav_playground` demonstrate how to use the Sylvanas navigation API (likely `core.movement` or IZI navigation helpers).

**Combat / Rotation**
- Demon Hunter Havoc PvE example uses IZI SDK for spell queue, target selector, and menu widgets.

**Adoption Notes for EAX**
- **This is the canonical reference** for how to structure Sylvanas plugins. Every EAX developer should read the `izi/` examples.
- The `nav_follower` example is particularly relevant if EAX ever adds a grindbot/navigation layer.
- The separation between `izi/` (high-level) and `legacy/` (low-level) mirrors EAX’s own `api/` vs `apidocs/` layers.

---

### 1.3 liantian-cn / M.I.D.N.I.G.H.T
- **URL**: https://github.com/liantian-cn/M.I.D.N.I.G.H.T
- **Stars**: 25 | **Forks**: 20
- **License**: **MIT**
- **Active**: Yes (last push 2026-06-06)
- **TBC Support**: No (targets Retail/Midnight), but patterns are highly transferable

**Architecture**
- **DejaVu** — In-game Lua addon that enumerates spell states, cooldowns, and class-specific attributes. Configures macros (`/burst`, `/delay`) and settings UI.
- **Terminal** — Python backend that reads screen via GDI screenshot, runs rotation logic, and sends keypresses.
- **Hot-reload**: Edit rotation Python code in IDE → save → rotation auto-reloads without restarting.

**Key Techniques**
- **GDI screenshot at 100fps** (optimized for Ryzen 9700X).
- **Macro-based state injection**: `/burst x.x` sets burst mode for x.x seconds; `/delay x.x` pauses rotation.
- **Interrupt blacklist**: Spell IDs listed in config to avoid interrupting trivial casts.
- **Hand-written Lua > 95%** (author explicitly avoids AI-generated code).
- **Codex/AGENTS.md workflow**: The project itself is developed with AI tooling, using `.context` files.

**Combat / Rotation**
- Specs implemented: Blood DK (99%), Guardian Druid (95%), Resto Druid (90%), Discipline Priest (100%).
- Rotation logic in Python (`Terminal/terminal/rotation/`).
- Plugin-side Lua defines which spells/cooldowns to expose to Python.

**Adoption Notes for EAX**
- **MIT license** allows full adaptation.
- The **hot-reload architecture** (Python backend + Lua state bridge) is inspiring for a Sylvanas grindbot: Sylvanas Lua could expose state, and a Python process could handle high-level routing.
- The **`/burst` and `/delay` macro patterns** could be implemented as Sylvanas menu toggles or keybinds.
- The **GDI screenshot approach is NOT applicable** to Sylvanas (Sylvanas has internal memory access), but the **separation of concerns** (Lua = state exposure, Python = decision engine) is a solid pattern.

---

### 1.4 namreeb / namigator
- **URL**: https://github.com/namreeb/namigator
- **Stars**: 75 | **Forks**: 40
- **License**: **MIT**
- **Active**: Yes (last push recent; 519 commits)
- **TBC Support**: Explicit — "Alpha, Vanilla, TBC and WotLK"

**Architecture**
- **C++** pathfinding library using Recast/Detour.
- **MapBuilder**: Generates navmesh from WoW terrain data (MPQ/ADT files).
- **pathfind**: Core library for runtime path queries (straight path, smooth path, raycast, random point on mesh).
- **Python bindings** via pybind11.

**Key Techniques**
- **Server-grade navmesh**: Used by `The Alpha Project` (alpha-core emulator) in production.
- **Thread-safe map loading** (with caveats noted in README).
- **Handles terrain, water, buildings, and objects** via triangle-type filtering.

**Navigation**
- Input: start/end XYZ coordinates + map ID.
- Output: path waypoints (straight or smoothed via Catmull-Rom/Bezier/Chaikin).
- Raycasting for movement validation.

**Adoption Notes for EAX**
- **MIT license** → can be compiled into a Sylvanas C++ plugin, or run as a local TCP/IPC service consumed by Lua.
- **TBC-compatible** → map data from TBC client MPQs can be fed into MapBuilder.
- The author explicitly states this is **not designed for bots** (does not honor client-side movement restrictions), but the underlying geometry queries are valid for any pathfinding use case.
- EAX could wrap `namigator` into a `core.movement` extension or spawn it as a subprocess and talk over a local socket.

---

### 1.5 Xian55 / AmeisenNavigation
- **URL**: https://github.com/Xian55/AmeisenNavigation
- **Stars**: 10 | **Forks**: 11
- **License**: **GPL-3.0**
- **Active**: Yes
- **TBC Support**: Explicit — used as V3 Remote pathfinder for WowClassicGrindBot

**Architecture**
- **C++** TCP server wrapping TrinityCore MMAPs + Recast/Detour.
- Consumes `*.mmap` files (navmesh tiles) per continent.
- Supports smooth pathfinding (Chaikin Curve, Catmull-Rom Spline, Bezier interpolation).

**Key Techniques**
- **TCP-based API**: Send start/end coordinates → receive waypoint list.
- **Movement raycasting**: Validates if a direct line between points is walkable.
- **Random point on mesh**: Useful for generating random grind spots within a polygon.

**Navigation**
- Load continent MMAPs once (~600 MB memory).
- Fast path queries after initial load.
- Supports `straightPath=false` (obstacle-aware) or `true` (direct line).

**Adoption Notes for EAX**
- **GPL-3.0** — if linked into EAX directly, EAX would need to be GPL-3.0. Better to keep it as a **separate process** and communicate via TCP/IPC (no license contamination).
- The **MMAP format** is derived from TrinityCore/CMaNGOS tools, which are well-documented for TBC.
- EAX could run `AmeisenNavigation.Server.exe` locally and have Sylvanas Lua send HTTP/TCP requests for path waypoints.

---

### 1.6 evopimp / TBCPythonBot
- **URL**: https://github.com/evopimp/TBCPythonBot
- **Stars**: 5 | **Forks**: 2
- **License**: None declared
- **Active**: No (last push 2021-05-23)
- **TBC Support**: Explicit — "Framework and configuration for TBC Grinding bot"

**Architecture**
- **Lua** (62.6%) + **C#** (34.3%) + HTML frontend.
- Fork of `julianperrott/WowClassicGrindBot` adapted for TBC.
- Uses `DataToColor` addon + Python backend (note: despite repo name, primary backend appears to be C# based on language stats; may be a hybrid).

**Key Techniques**
- JSON class configurations for TBC-specific spells.
- MPQ-based pathfinding (PPather).
- Path recording tool for custom routes.

**Adoption Notes for EAX**
- Code is stale (2021), but the **TBC-specific class configs** and **path JSONs** may contain usable spell IDs and coordinates.
- Not actively maintained; treat as reference only.

---

### 1.7 trewq34213 / pb (shmilyzxt/pb)
- **URL**: https://github.com/trewq34213/pb
- **Stars**: 2 | **Forks**: 10
- **License**: **MIT**
- **Active**: No (last push 2020-12-07)
- **TBC Support**: Indirect (Classic-era, but DataToColor pattern is version-agnostic)

**Architecture**
- **Python + Lua** pixel bot.
- `addon/DataToColor` for game state encoding.
- `lib/` modules: bag, chat, config, control, db, macro, NameFinder (C#), navigation, pixel, recorder, spell, tools.
- `run/` user folder: combat loops, configs, path data, web monitor.

**Key Techniques**
- **Multi-resolution support** (1080p, 4K).
- **Area fighting**: Define polygonal combat areas.
- **Path recording**: `record_v2.py` to record grave paths, repair paths, and grind areas.
- **Team support**: Multi-character coordination.
- **NameFinder** (C# DLL): Finds enemies by nameplate color.

**Adoption Notes for EAX**
- The **area-fighting polygon system** and **path recorder** concepts could be reimplemented in Sylvanas using `core.object_manager` + `core.input.move_to`.
- The **web monitor** (`run/web/`) is a nice UX pattern; Sylvanas plugins can render UI via `core.graphics` or external dashboards.
- Stale code; use for architectural inspiration only.

---

### 1.8 CuteOne / BadRotations (and forks)
- **URL**: https://github.com/CuteOne/BadRotations (original, likely private now)
- **Forks**: Geebuss/BadRotations, forsooth-dev/BadRotations, shaoruce/BadRotations
- **Stars**: Highly starred (original had 1000+)
- **License**: **GPL-3.0**
- **Active**: Sporadic (Retail-focused)
- **TBC Support**: No (Retail-focused), but Lua patterns are universal

**Architecture**
- Pure Lua rotation framework running inside WoW with a **Lua Unlocker** (FireHack / EWT).
- Object Manager, Healing Engine, Ground Spells, Debug Frame.
- Profile-specific toggle buttons and options.

**Key Techniques**
- **Healing Engine**: Prioritizes party/raid members by health deficit, incoming heal prediction, and range.
- **BossHelper (BH)**: Boss-specific spell logic.
- **Rotation priority lists**: Each class/spec has a dedicated Lua profile.
- **Debug Frame**: Real-time rotation decision visualization.

**Adoption Notes for EAX**
- **GPL-3.0** — direct copying into EAX (which is not GPL) is risky. Study patterns only.
- The **Healing Engine design** (health deficit + range + role weighting) is a well-known pattern EAX already uses, but BadRotations has more sophisticated incoming-damage prediction.
- The **profile toggle/button system** could inspire Sylvanas menu UI design.
- Many TBC-era rotations were originally derived from BadRotations; historical profiles may exist in forks.

---

### 1.9 znibb / WowProfessionLevelingTool
- **URL**: https://github.com/znibb/WowProfessionLevelingTool
- **Stars**: 9 | **Forks**: 11
- **License**: None declared
- **Active**: No (last push 2022-08-09)
- **TBC Support**: Explicit — "This version is for World of Warcraft The Burning Crusade Classic"

**Architecture**
- **Python** (52.2%) + HTML/JS frontend.
- Docker-compose deployment.
- Pulls profession data from git submodules (likely Wowhead or CMaNGOS extractions).

**Key Techniques**
- **Brute-force + backtracking + pruning** algorithm to find cheapest profession leveling path.
- At each skill level: tries all recipes that grant skill-ups, tallies cost, backtracks if gold sum exceeds known best.
- Sells by-products according to user config.

**Profession**
- Supports all TBC crafting professions.
- AH price integration (likely manual or via addon export).

**Adoption Notes for EAX**
- The **recipe database** and **cost-optimization algorithm** could be ported to Lua/Sylvanas for an in-game profession helper.
- The Python backend could be reused as-is, with Sylvanas Lua calling it via HTTP for recommendations.
- Stale but the data and algorithm are solid.

---

### 1.10 DominikLindorfer / Tensor-WoW (RotBot)
- **URL**: https://github.com/DominikLindorfer/Tensor-WoW
- **Stars**: ~20+
- **License**: None declared
- **Active**: Sporadic
- **TBC Support**: No (Retail-focused), but pixel pattern is version-agnostic

**Architecture**
- **TensorFlow 2D-CNN** (Python) reads spell icons from screen via OpenCV.
- Trained on 3000 augmented 56x56 images per spell (189 classes total).
- Uses `MaxDps-Minimal` addon to display next spell in a WeakAura-style UI.
- **directkeys.py**: Sends `SendInput` hex codes for keypresses.

**Key Techniques**
- **Screen-reading + ML classification** instead of memory reading or pixel color encoding.
- More robust to UI scaling than raw pixel encoding because the CNN learns icon features.
- tf-lite models for speed.

**Adoption Notes for EAX**
- **Not directly applicable** to Sylvanas (Sylvanas has internal API access), but the **CNN-based icon recognition** could be used for:
  - Detecting external UI elements (e.g., boss mod timers) that Sylvanas API does not expose.
  - Verifying spell casts landed (by reading combat log icons).
- Overkill for standard rotations; useful for research into hybrid vision+memory approaches.

---

## 2. Honorable Mentions

### 2.1 Profession Helpers
- **kaldown/LazyProf** (Lua, NOASSERTION) — Optimal profession leveling path calculator; requires CraftLib; TSM/Auctionator pricing integration.
- **KevinTyrrell/WoWProfessionOptimizer** (Lua + Python, no license) — Classic addon using TSM price data; brute-force + backtracking.
- **DarkChimu/Improved-Profession-Capper** (Lua, GPL-3.0) — WotLK 3.3.5 crafting helper; spell-ID-based recipe matching; locale-independent.

### 2.2 Route / Navigation Addons
- **sam0x17/routes_classic** (Lua, archived) — Routes addon patched for WoW Classic; TSP solver for farming routes.
- **XiconQoo/Routes-TBC-FarmHud-Compatible** (Lua) — Routes addon for TBC with FarmHud compatibility.
- **breakbone-addons/addressbook** (Lua, NOASSERTION) — 13,600+ NPC locations for TBC Anniversary; TomTom waypoint integration.

### 2.3 Pixel Rotation POCs
- **hankerspace/WowPixelRotationBot** (AutoIt + Lua) — Bridges `ConRO` addon recommendations to external key sender via pixel sampling. Very simple; good for understanding the pixel-bridge concept.

---

## 3. Pattern Matrix

| Repo | Type | Nav | Combat | Professions | Sylvanas API | License | Adoption Score |
|------|------|-----|--------|-------------|--------------|---------|----------------|
| Xian55/WowClassicGrindBot | Pixel-Bot (C#+Lua) | PPather / AmeisenNavigation | JSON class configs | Loot/Skin/Herb/Mine | None | None | ⭐⭐⭐ |
| bluesilvi/project-sylvanas | Internal Lua | Examples (nav_follower) | IZI SDK rotation | None | **Native** | None | ⭐⭐⭐⭐⭐ |
| liantian-cn/M.I.D.N.I.G.H.T | Pixel-Bot (Python+Lua) | None (manual) | Python rotation engine | None | None | MIT | ⭐⭐⭐⭐ |
| namreeb/namigator | C++ Navmesh | Recast/Detour | None | None | None | MIT | ⭐⭐⭐⭐ |
| Xian55/AmeisenNavigation | C++ TCP Server | Recast/Detour | None | None | None | GPL-3.0 | ⭐⭐⭐ |
| evopimp/TBCPythonBot | Pixel-Bot | PPather | JSON configs | None | None | None | ⭐⭐ |
| trewq34213/pb | Pixel-Bot (Python+Lua) | Path recorder | Python loops | None | None | MIT | ⭐⭐ |
| CuteOne/BadRotations | Internal Lua | None | Lua rotation framework | None | None | GPL-3.0 | ⭐⭐⭐ |
| znibb/WowProfessionLevelingTool | Python Web | None | None | Brute-force optimizer | None | None | ⭐⭐⭐ |
| DominikLindorfer/Tensor-WoW | ML Pixel-Bot | None | CNN icon reader | None | None | None | ⭐⭐ |

---

## 4. Actionable Recommendations for EAX

### 4.1 Immediate (Low Effort)
1. **Study `bluesilvi/project-sylvanas` `nav_follower` and `nav_playground` examples.** These use the exact same `core.*` and `izi.*` APIs EAX uses. Any grindbot/navigation feature should follow their patterns.
2. **Copy the `M.I.D.N.I.G.H.T` hot-reload workflow concept.** Sylvanas Lua could watch a file (or use `core.register_on_update_callback`) to dynamically reload rotation logic without restarting the client. This dramatically speeds up development.
3. **Adopt the `Xian55` JSON route format** for waypoint definitions. It is simple, well-documented, and compatible with pathfinding tools.

### 4.2 Medium Term
1. **Integrate `namigator` as a local navmesh service.**
   - Compile `namigator` MapBuilder against TBC MPQs to generate `*.navmesh` files for Outland + Azeroth.
   - Run `namigator` as a local subprocess (or TCP server).
   - Build a thin Sylvanas Lua client that queries `namigator` for paths and calls `core.input.move_to()` to follow waypoints.
   - **License-safe** because MIT allows this; no GPL contamination.

2. **Port `znibb/WowProfessionLevelingTool` algorithm to Lua.**
   - Use the existing `wowhead_data/lua/item_db.lua` and `spell_db.lua` as the recipe database.
   - Implement a greedy/backtracking solver for cheapest profession path.
   - Render recommendations in a Sylvanas menu panel.

### 4.3 Long Term / Research
1. **Evaluate `AmeisenNavigation` V3 for Sylvanas grindbot use.**
   - If GPL-3.0 is acceptable for a standalone helper executable, use it.
   - Otherwise, stick with MIT `namigator`.
2. **Experiment with `Tensor-WoW` CNN approach** for detecting external UI states (boss mod timers, dungeon debuff frames) that Sylvanas API does not expose.

---

## 5. Data Sources & References

- **Project Sylvanas Docs**: https://docs.project-sylvanas.net/
- **WowClassicGrindBot README (dev branch)**: https://github.com/Xian55/WowClassicGrindBot/blob/dev/README.md
- **namigator README**: https://github.com/namreeb/namigator/blob/master/README.md
- **AmeisenNavigation README**: https://github.com/Xian55/AmeisenNavigation/blob/master/README.md
- **M.I.D.N.I.G.H.T README**: https://github.com/liantian-cn/M.I.D.N.I.G.H.T/blob/main/README.md

---

*End of Report*
