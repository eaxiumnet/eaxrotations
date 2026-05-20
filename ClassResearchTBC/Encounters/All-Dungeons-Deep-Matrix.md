# All TBC Dungeons Deep Matrix

Second-pass total coverage for all Burning Crusade dungeons. Source hubs: Wowhead TBC dungeon overview and dungeon guide index, Icy Veins TBC dungeon guide hub, Warcraft Tavern dungeons/raids hub.

## All Dungeons

| Dungeon | Normal level | Location | Bosses | Total-coverage rotation modifiers |
|---|---|---|---|---|
| Hellfire Ramparts | 60-62 | Hellfire Citadel, Hellfire Peninsula | Watchkeeper Gargolmar, Omor the Unscarred, Vazruden the Herald / Nazan | Early Outland melee/caster packs, patrol awareness, basic heroic spike damage. |
| The Blood Furnace | 61-63 | Hellfire Citadel, Hellfire Peninsula | The Maker, Broggok, Keli'dan the Breaker | Dense fel-orc packs, caster control, poison/slime-style pressure, boss add/control checks. |
| The Shattered Halls | 69-70 | Hellfire Citadel, Hellfire Peninsula | Grand Warlock Nethekurse, Blood Guard Porung, Warbringer O'mrogg, Warchief Kargath Bladefist | Large melee packs, gauntlet pressure, stun/cleave risk, AoE threat stress test. |
| The Slave Pens | 62-64 | Coilfang Reservoir, Zangarmarsh | Mennu the Betrayer, Rokmar the Crackler, Quagmirran | Naga/broken packs, poison/nature pressure, healer attention to tank spikes. |
| The Underbog | 63-65 | Coilfang Reservoir, Zangarmarsh | Hungarfen, Ghaz'an, Swamplord Musel'ek, The Black Stalker | Nature/poison themes, pet/add control, ground effects and caster positioning. |
| The Steamvault | 68-70 | Coilfang Reservoir, Zangarmarsh | Hydromancer Thespia, Mekgineer Steamrigger, Warlord Kalithresh | Caster interrupts, add control, purge/cleanse value, boss empowerment awareness. |
| Mana-Tombs | 64-66 | Auchindoun, Terokkar Forest | Pandemonius, Tavarok, Nexus-Prince Shaffar, Yor | Ethereal caster packs, mana pressure, reflect/shield-style boss checks, add portals. |
| Auchenai Crypts | 65-67 | Auchindoun, Terokkar Forest | Shirrak the Dead Watcher, Exarch Maladaar | Undead utility, caster disruption, healing pushback/positioning, summoned add control. |
| Sethekk Halls | 67-69 | Auchindoun, Terokkar Forest | Darkweaver Syth, Talon King Ikiss, Anzu | Caster packs, polymorph/fear/control risk, LoS pulls, bird/add control. |
| Shadow Labyrinth | 69-70 | Auchindoun, Terokkar Forest | Ambassador Hellmaw, Blackheart the Inciter, Grandmaster Vorpil, Murmur | Fear/charm/caster-heavy dungeon, strong interrupt/dispels, movement and sonic burst awareness. |
| Old Hillsbrad Foothills | 66-68 | Caverns of Time, Tanaris | Lieutenant Drake, Captain Skarloc, Epoch Hunter | Escort pacing, add waves, mounted/chase sections, objective protection. |
| The Black Morass | 70 | Caverns of Time, Tanaris | Chrono Lord Deja, Temporus, Aeonus | Portal waves, add pickup, boss timers, mana pacing across continuous combat. |
| The Mechanar | 70 | Tempest Keep, Netherstorm | Gatewatcher Gyro-Kill, Gatewatcher Iron-Hand, Mechano-Lord Capacitus, Nethermancer Sepethrea, Pathaleon the Calculator | Mechanic/caster packs, polarity/bomb-style movement, add control. |
| The Botanica | 70 | Tempest Keep, Netherstorm | Commander Sarannis, High Botanist Freywinn, Thorngrin the Tender, Laj, Warp Splinter | Botanical/nature packs, add waves, interrupts, poison/nature resistance checks. |
| The Arcatraz | 70 | Tempest Keep, Netherstorm | Zereketh the Unbound, Dalliah the Doomsayer, Wrath-Scryer Soccothrates, Harbinger Skyriss | Dangerous caster/demon packs, stuns/interrupts, heavy heroic tank damage, multi-phase final boss. |
| Magisters' Terrace | 70 | Isle of Quel'Danas | Selin Fireheart, Vexallus, Priestess Delrissa, Kael'thas Sunstrider | High-density caster/control dungeon, PvP-like Delrissa fight, purge/interrupt/CC priority. |

## Role Rules For Every Dungeon

| Role | Universal dungeon rule | Failure case this prevents |
|---|---|---|
| Tank | Mark or establish priority before DPS starts; LoS caster packs; face cleaves away | DPS deaths, healer threat, accidental extra pulls |
| Healer | Track tank spike windows, dispel lethal debuffs, drink/mana-plan between pulls | OOM on heroics, deaths during chained pulls |
| Melee DPS | Interrupt healers/casters, avoid frontals, disable cleave around CC | Broken CC and cleave deaths |
| Ranged DPS | Kill priority adds, protect CC, kite runners/adds, decurse/dispel if class can | Pulling extra packs and failed mechanics |
| Pet classes | Move pet behind mobs and disable pet cleave near CC | Pet deaths and broken CC |

## Automation Checks

- `cc_safe` before any AoE/cleave.
- `tank_has_pack_control` before sustained AoE.
- `dangerous_cast` before damage filler.
- `runner_low_hp` before continuing normal target priority.
- `healer_mob_active` before normal boss/pack DPS.
- `heroic_mode` should lower defensive thresholds and raise CC/interrupt priority.
