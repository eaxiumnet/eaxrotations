# NAG/

## Responsibility
Contains a separate multi-expansion addon/tooling project kept in-repo for reference, integration context, and adjacent execution-environment work.

## Design
- **Monorepo structure**: mixes addon runtime code, build/package metadata, docs, website assets, and auxiliary tools such as log analysis and a Discord bot.
- **Expansion segmentation**: code is split across `vanilla/`, `tbc/`, `wrath/`, `cata/`, `mists/`, and `sod/` trees.
- **Addon entrypoint pattern**: root Lua files (`NAG.lua`, `Core.lua`, `Common.lua`, etc.) coordinate shared behavior and expansion-specific modules.

## Flow
1. Addon/runtime modules load from root and expansion-specific trees.
2. Shared handlers, modules, libraries, and utilities support the selected expansion/runtime path.
3. Ancillary subprojects (`website/`, `discord-bot/`, `log-analyzer/`) support distribution, customization, and diagnostics.

## Integration
- Adjacent to: live EAX rotation work in the repository root.
- Useful for: execution-environment reference, addon patterns, and tooling context.
- Not part of the active EAX cartography runtime surface.
