# All TBC Raids Deep Matrix

Second-pass total coverage for Burning Crusade raid and outdoor raid-boss content. Source hubs: Wowhead TBC raid overview, Icy Veins raid/dungeon hubs, and existing class guide sources.

## All Raids and Raid Bosses

| Raid | Size | Location | Bosses | Total-coverage rotation modifiers |
|---|---|---|---|---|
| Karazhan | 10-player | Deadwind Pass | Servant Quarters, Attumen the Huntsman, Moroes, Maiden of Virtue, Opera Event, The Curator, Terestian Illhoof, Shade of Aran, Netherspite, Chess Event, Prince Malchezaar, Nightbane | Mixed undead/demon/caster utility, CC, interrupts, add control, tank spikes, movement, beam/phase handling. |
| Gruul's Lair | 25-player | Blade's Edge Mountains | High King Maulgar, Gruul the Dragonkiller | Council control/tanking assignments, shatter movement, growth-based tank pressure, threat discipline. |
| Magtheridon's Lair | 25-player | Hellfire Peninsula | Magtheridon | Channeler add control, interrupt rotations, cube/click assignments, tank cooldowns and raid burst windows. |
| Serpentshrine Cavern | 25-player | Zangarmarsh | Hydross the Unstable, The Lurker Below, Leotheras the Blind, Fathom-Lord Karathress, Morogrim Tidewalker, Lady Vashj | Resistance/tank swaps, add waves, water/movement, demon phase control, multi-add tanking, final phase objective handling. |
| The Eye / Tempest Keep | 25-player | Netherstorm | Al'ar, Void Reaver, High Astromancer Solarian, Kael'thas Sunstrider | Air/ground movement, threat resets, arcane/caster pressure, legendary weapon/add phase handling, interrupts. |
| Hyjal Summit | 25-player | Caverns of Time | Rage Winterchill, Anetheron, Kaz'rogal, Azgalor, Archimonde | Wave-based trash, AoE threat, decurse/fear/doom mechanics, boss transitions, anti-fear and survival checks. |
| Black Temple | 25-player | Shadowmoon Valley | High Warlord Naj'entus, Supremus, Shade of Akama, Teron Gorefiend, Gurtogg Bloodboil, Reliquary of Souls, Mother Shahraz, Illidari Council, Illidan Stormrage | Tank spikes, target swaps, ghost/vehicle-style duty, council interrupts, shadow resistance planning, demon phase control. |
| Zul'Aman | 10-player | Ghostlands | Akil'zon, Nalorakk, Jan'alai, Halazzi, Hex Lord Malacrass, Zul'jin | Timed-run routing, animal boss mechanics, add waves, interrupts/dispels, multi-mob council-style control. Guardrail: original TBC final boss is Zul'jin; verify any source naming Daakara before use. |
| Sunwell Plateau | 25-player | Isle of Quel'Danas | Kalecgos, Brutallus, Felmyst, Eredar Twins, M'uru, Kil'jaeden | High raid damage, strict dispels, tank busters, portal/split-realm style duty, add burn, survival cooldown chains. |
| Doom Lord Kazzak | Outdoor raid boss | Hellfire Peninsula | Doom Lord Kazzak | World-boss threat, shadow damage, anti-heal/drain checks, tight kill discipline. |
| Doomwalker | Outdoor raid boss | Shadowmoon Valley | Doomwalker | World-boss threat, earthquake/chain lightning-style raid spread, tank positioning. |

## Raid Role Rules

| Role | Rule | Implementation note |
|---|---|---|
| Main tank | Preserve mitigation resource for tank busters and taunt swaps | Defensive threshold should be encounter-aware, not only HP-based |
| Off tank | Watch add timers and taunt/snap-threat windows | Add wave logic overrides boss filler |
| Healer | Pre-cast/pre-HoT for scripted damage; dispel by danger | Healing target selection needs debuff danger weighting |
| Melee DPS | Obey frontals/cleaves, threat walls, and target swaps | Movement and target-lock logic must beat pure priority |
| Ranged DPS | Handle spread/stack, interrupts, add burns, and school swaps | Resist/immunity checks must alter spell priority |
| Hybrid DPS | Utility assignments can outrank damage | Decurse, cleanse, off-heal, innervate, purge, grounding/tremor |

## Boss Mechanic Buckets

| Bucket | Examples | Affected automation |
|---|---|---|
| Add waves | Hyjal waves, Vashj, M'uru, Magtheridon channelers | Target priority, AoE, snap threat, interrupts |
| Tank busters | Brutallus, Gruul growth, Illidan phases | Defensive manager and healer pre-cast |
| Resistance/immunity | Hydross, Mother Shahraz, school-heavy bosses | Spell school fallback and gear set selection |
| Movement | Shatter, flame patches, beams, air phases | Instant-cast and movement-priority rules |
| Council/control | Maulgar, Illidari Council, Delrissa-like fights | Interrupt/CC target rotation |
| Assignment mechanics | Cubes, beams, ghosts, portals, click duties | Rotation pause/utility override state |
