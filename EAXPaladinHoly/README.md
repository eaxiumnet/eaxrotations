# EAX Paladin Holy

Holy healing helper for single-target and group play. The addon drives the core healing spells, keeps the blessing suite refreshed on the player, and automatically cleanses queued disease/poison debuffs while respecting the documented EAX APIs.

## Modes

- **Auto** (default) inspects the group size at runtime and switches between Solo, Dungeon, and Raid behavior depending on how many party/raid members are present.
- **Solo** only heals the player itself and assumes no group support is available.
- **Dungeon** treats the party as a small group (≤5 players) and focuses healing the lowest-health ally while keeping blessings on the paladin.
- **Raid** behaves like Dungeon but accepts larger group sizes and will still focus the most injured ally available.

## Rotation

Priority order per update (global cooldown aware):

1. **Holy Shock** – instant, stitched to the Holy Shock threshold slider for emergency snapshots.
2. **Flash of Light** – fast cast used when damage drops an ally beneath the Flash slider.
3. **Holy Light** – expensive but high value, cast when the target breaches the Holy Light slider percent.

The thresholds are configurable via the menu sliders and expressed as the percent of missing health at which each spell activates. The logic prefers the most injured valid target returned by `core.object_manager.get_all_objects()` plus party/raid membership checks.

## Blessings & Cleanse

- **Auto Blessings** (toggle) keeps Light, Wisdom, and Might up on the player whenever they fall off. It only attempts a refresh when the global cooldown has reset.
- **Cleanse** watches for a handful of common disease/poison IDs (16470, 16472, 16473, 28169) and casts Cleanse on the affected unit when one of those debuffs is active. The list can be expanded in `main.lua` if additional IDs become relevant.

## Configuration

- **Enabled** – enable or disable the addon.
- **Toggle Key** – quick key to toggle the addon state without reopening the menu.
- **Mode override** – force Solo, Dungeon, or Raid; Auto falls back to the detected mode.
- **Debug Logging** – useful for watching which spell the addon is executing in real time.
- **Spell toggles / thresholds** – enable/disable Holy Light, Flash of Light, Holy Shock and adjust their activation HP percentage.
- **Auto Blessings** – keep Blessings of Light, Wisdom, and Might maintained on the paladin.

## References

- Design doc: `docs/superpowers/specs/2026-03-13-eax-paladin-holy-design.md`
- API list: `docs/eax-family/API_LOOKUP_PLAYBOOK.md`
