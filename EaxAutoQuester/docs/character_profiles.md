# Character profiles

EaxAutoQuester keeps a profile for each character name and realm pair seen during the current client session. The active profile is selected before the normal enable/state path, so a character switch restores the settings that belong to the character now playing.

For the in-game verification steps — what each log line looks like, and what a correct no-op looks like — see **`docs/client_runbook.md`**.

## Stored fields

| Profile field | Menu control | Default | Live behavior |
|---|---|---:|---|
| Gather professions | `eaxaq_profile_gather_herbalism`, `..._mining`, `..._skinning`, `..._fishing` | auto for a learned supported profession; otherwise off | Seeds a nearby-node route while the guide has no active goal. The checkbox is the manual override. Quest goals, waypoints, combat, open frames, and an active cast/channel always outrank it. |
| Gather free-slot reserve | `eaxaq_profile_gather_min_free_slots` | 4 | The route stops below this many free bag slots (0 disables the bag gate). Per character, restored on a character switch like every other profile field. |
| Vendor threshold | `eaxaq_profile_vendor_bag_threshold` | 80% | The shared loot/corpse vendor trigger raises `_force_vendor_soon` at this bag fullness. It is a bag threshold, not an item-quality threshold. |
| Pull policy | Existing `eaxaq_pull_gate`, `eaxaq_pull_gate_min_hp`, `eaxaq_pull_gate_min_mana` | on / 50% / 30% | The existing `shared/pull_safety.lua` gate reads these values through the real menu. |
| Mount use | `eaxaq_profile_mount_use` | on | `mount_manager_sylvanas.lua` refuses automatic mount casts when off. Dismount-at-arrival/combat safety remains unconditional. |

All settings are captured from the menu on the normal client tick and restored when the character changes. Missing widgets, missing identity methods, and profile-module load failures use the established safe defaults.

## Profession detection

A newly created profile asks the documented client surface exactly once:

1. `core.spell_book.get_professions()` returns the spell-tab indices the character actually has in `prof1`, `prof2`, and `fishing`.
2. `core.spell_book.get_profession_info(index)` supplies that profession's `skill_line` id, its localized names, and its skill level.
3. The `skill_line` id decides which profession the slot is. A recognized id enables that existing profile checkbox before the profile is shown.

### Skill-line ids are locale-proof

Detection does not compare localized text. It matches the numeric `skill_line` the client reports against four ids taken from the authoritative 2.5.5 DBC in this repository (`wowheadScrape/dbc_extract/wowsims.db`). That database has no `SkillLine` name table, but it does have the `SkillLineAbility` rows that carry the id:

| Profession | Skill-line id | DBC derivation |
|---|---:|---|
| Herbalism | 182 | `Herb Gathering` (spell 2366) |
| Mining | 186 | `Mining` (spell 2575) — also carries Mining's own smelts |
| Fishing | 356 | `Fishing` (spell 7620) — also carries Fishing Poles |
| Skinning | 393 | `Skinning` (spell 8613) |

```sql
SELECT DISTINCT sla.SkillLine, sn.Name_lang
FROM SkillLineAbility sla LEFT JOIN SpellName sn ON sn.ID = sla.Spell
WHERE sn.Name_lang IN ('Herb Gathering','Mining','Fishing','Skinning');
```

Each id carries only that profession's abilities, so none is shared with another profession — Alchemy is 171, for example, and is deliberately not mapped. The localized name and skill-line name are still read, but only as a **fallback** for a build that leaves `skill_line` empty.

Detection remains deliberately narrow. Alchemy, Tailoring, and every other profession are read but change no behavior. A missing binding, failed call, non-table result, absent slot, or unrecognized skill line leaves the route off; the checkbox remains the manual escape hatch. The profile is never re-detected on later activations, so a user who unchecks a detected profession keeps it off for the session. Nothing is queried from the tick path, and the side-effecting `core.profession.open_profession` opener is never used.

**Client verification still required:** the Lua battery proves the wiring against the documented contract, not that a particular Sylvanas client build reports `skill_line` on `get_profession_info` (or answers `get_professions()` with populated slots at all). The diagnostic line prints the `[skill N]` id it matched on, so one glance confirms which path fired. An empty, late, or unsupported answer is safe — every checkbox stays at its manual off default and no profession is assumed.

## Startup diagnostic

When a profile is created, the same one-shot detection emits a single `core.log` line so the in-game result is readable at a glance:

```text
EaxAutoQuester professions [Alice - Ravencrest]: prof1=Herbalism [skill 182] (300), prof2=Alchemie [skill 171] (275), fishing=Fischen [skill 356] (150); gathering: Herbalism, Fishing
```

- One line per **newly created character profile**, never on re-activation and never on the tick path.
- Every present slot is listed with its skill-line id and skill level; slots the client cannot describe are shown as `<slot>=unreadable` rather than hidden. The `[skill N]` value is the id detection matched on, so it shows whether the locale-proof path or the name fallback fired.
- `gathering:` lists only the supported professions that were actually enabled, in canonical English so it reads the same in every locale.
- When detection is unavailable the line says why — `API unavailable`, `API call failed`, or `API returned no table` — so a failed smoke check is distinguishable from a character with no professions.
- A nameless player, which never gets a profile, logs nothing.

## Gathering route

The route is deliberately conservative:

- It runs only when the loaded guide step is complete, or has no uncompleted goal and no waypoint.
- It scans at most 50 visible objects once per second, within 50yd, and only considers valid non-unit objects.
- The client object name must match a bounded Herbalism, Mining, Skinning, or Fishing vocabulary and that profession must be enabled in the active character profile.
- The route stops when the bags hold fewer than this character's reserve (`eaxaq_profile_gather_min_free_slots`, default 4, 0 disables the gate). The free-slot number itself comes from the same `loot_manager_sylvanas.get_bag_space()` owner (backed by `common/utility/inventory_helper`) that already gates looting, so the two gates read identical free/total/used values. An in-progress node is abandoned and its NAV destination cleared; a blocked check re-arms the scan clock so a full bag is re-read once per second, not once per tick. An unreadable inventory does **not** block gathering — the vendor threshold remains the backstop.
- **A blocked route asks for a vendor instead of idling.** The reserve is a *slots* rule, so it can bite long before the *fullness percentage* the normal vendor trigger uses — without this the bot would simply stop gathering and stand there with the flag never raised. So a block raises the same `_force_vendor_soon` flag the fullness trigger uses and stays `IDLE`, which is what lets the coordinator's force-vendor route send it to the vendor. That flag also makes the vendor sell up to green, which is what actually frees the slots. The request is idempotent (a visit already pending is left alone) and paced by a 180s retry, because a visit that frees nothing — a bag of quest items sells nothing — must not become a vendor trip loop. The vendor clears the flag when it handles the visit.
- **The log line names the real cause.** Because two routes raise that one flag, each records its own reason next to it (`_force_vendor_reason`) and the coordinator prints whichever is set — `gathering blocked: 3 free bag slot(s), reserve 4` for a reserve block, `bags 81% full (profile threshold 80%)` for a fullness trip. The reason is cleared together with the flag so the next request can never inherit it; a raise with no reason falls back to this character's threshold.
- A far node publishes a normal owned NAV destination. At 5yd or closer, IDLE faces, targets, and calls the existing `core.input.use_object` path.
- The existing cast/channel pause protects the gather cast. A 0.3s interaction pause and 2s route cooldown prevent immediate re-use.
- Skinning here means visible non-unit carcass/hide objects; ordinary dead units remain on the existing corpse-loot path.

The classifier is name-based, not a claim that the client exposes node types. Profession detection now gates the route on a learned supported profession, but it does not check profession rank, trained gathering, node inventory limits, server respawn timers, or a node-to-profession route. Name matching also uses the localized profession name rather than a verified skill-line-ID table, which is not shipped in this repository.

## Persistence boundary

The supported Project Sylvanas surface used by this plugin has no documented file-write API. Profiles therefore live in memory for the current client session; this change does not claim cross-restart persistence. The recorder's existing export-string pattern remains the model for future persistence if the runtime gains a supported storage surface.

## Changing characters

1. Start the client with character A and set the profile controls.
2. Log out and log in as character B. B receives the defaults, with any supported gathering professions seeded from the client's learned-profession data and the standard 4-slot gather reserve, on first sight.
3. Set B independently. Returning to A restores A's values.

The profile key is lower-cased `name@realm`; same-name characters on different realms are separate profiles. An unreadable name is never assigned to another character's profile.
