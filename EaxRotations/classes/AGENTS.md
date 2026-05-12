# Classes Subtree Guidance

## Standard Folder Contract

Each class folder is flat and usually contains:

- `schema_sylvanas.lua` - settings schema
- `class_sylvanas.lua` - spell tables, constants, class registration
- `middleware_sylvanas.lua` - cross-playstyle middleware
- `<playstyle>_sylvanas.lua` files - ordered strategies for specs / forms / playstyles

## Standard Editing Rules

- Preserve the `schema -> class -> middleware -> playstyle files` contract from `load_order_sylvanas.lua`.
- Register behaviour through rotation registry patterns already used here.
- Keep playstyle selection compatible with `settings.playstyle` / `settings.active_playstyle` via `NS.get_active_playstyle()` or equivalent fallback.
- Keep class-local code class-local; move only truly shared logic into `shared/`.
- Use `NS.import_helpers()` / `NS.import_helpers_safe()` instead of ad-hoc alias blocks when the file already follows that pattern.
- Keep customer-facing labels Eax-branded and free of unrelated project names.
- Use `common_sylvanas.lua` section factories for shared schema sections (dashboard, rotation, cooldowns, etc.) — do not copy-paste schema code across classes.

## What Belongs In `class_sylvanas.lua`

- Spell definitions and constants
- Class registration metadata
- Context extension helpers shared across that class
- Class-wide cooldown / dashboard metadata

## What Belongs In `middleware_sylvanas.lua`

- Utility, defensive, interrupt, burst, pet, recovery, or maintenance logic shared across the class's playstyles

## What Belongs In Playstyle Files

- Ordered combat strategies for one spec / form / rotation mode
- Spec-local state builders and thresholds
- No unrelated UI, export, or doc-only code

## Exceptions By Class

| Class | Exception |
|---|---|
| `hunter/` | Has `cliptracker_sylvanas.lua` and `debugui_sylvanas.lua` sidecars in addition to normal spec files; keep them hunter-local, not shared helpers |
| `warrior/` | Includes `kebab_sylvanas.lua` as an extra playstyle |
| `druid/` | Includes `caster_sylvanas.lua` and `healing_sylvanas.lua` helper/variant files |
| `paladin/` | Includes `healing_sylvanas.lua` helper logic |
| `priest/` | Includes `healing_sylvanas.lua` helper logic |
| `mage/` | Structurally close to the norm but registration details differ slightly; follow existing file style exactly |

## Do Not Do

- Do not introduce nested per-class subdirectories unless the whole subtree is being intentionally reorganised.
- Do not mix TBC and post-TBC spell lists.
- Do not bypass `NS.*` for runtime API access.
- Do not duplicate shared helper logic across multiple classes if `shared/` already owns it.
- Do not treat hunter sidecars as justification for a separate child hierarchy unless the subtree grows materially.
