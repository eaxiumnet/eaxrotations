# FEATURES - Feature Analysis

## Table Stakes

Features expected by users in any TBC rotation suite. Missing these = unusable.

### Core Combat
- [x] **27 full specs** — all class/spec combinations
- [x] **Priority-based spell casting** — correct APM
- [x] **Interrupt management** — priority system with weighted spell lists
- [x] **Defensive cooldowns** — HP-threshold layered system
- [x] **Auto attack management** — melee/ranged swing timing
- [ ] **Swing timer awareness** — critical for Warriors, Rogues, Hunters (needs improvement)
- [ ] **Haste breakpoint detection** — changes rotation at specific haste levels
- [ ] **Set bonus detection** — dynamic gear scanning (missing)

### Combat Intelligence
- [x] **Encounter awareness** — boss-specific behaviors
- [x] **Mode detection** — solo/dungeon/raid
- [x] **Target priority** — attacking me > party > random
- [ ] **Threat management** — no current threat tracking or fade awareness
- [ ] **Movement optimization** — pre-positioning, movement casting

### Automation
- [x] **OOC drink/eat** — mana and health restoration
- [x] **OOC group buffs** — buff all party members
- [x] **OOC resurrection** — battle resurrection
- [ ] **Auto-repair** — repair when durability drops
- [ ] **Auto-sell** — sell grey items
- [ ] **Auto-consumables** — buy/use potions, food, reagents

### Visual
- [x] **ESP overlay** — cast visualization
- [x] **HUD display** — target name, mode
- [ ] **DPS/HPS meter** — damage/healing tracking
- [ ] **Cooldown timers** — ability cooldown display
- [ ] **TTD display** — time-to-death for targets

## Differentiators

Features that separate #1 from competitors.

### SimC-Accurate Rotations
- Parse SimulationCraft APLs for mathematically optimal priority
- Tempest does this natively; EAX should reference simc profiles
- Reference: `/c/618497f1/scripts/tbc/sim/*/`

### Swing Timer Management
- **Warrior Arms**: Slam weaving — cast Slam immediately after auto-attack lands
- **Warrior Fury**: Bloodthirst + Whirlwind priority, execute phase
- **Rogue**: SnD/CP timing, slice timing, no swing clip
- **Hunter**: Steady shot timing, auto shot alignment, weaving
- Current EAX: basic implementation exists but not optimized

### DoT Clipping Prevention
- **Affliction Warlock**: Never clip final tick of Corruption, Immolate, UA
- **Balance Druid**: Never clip final tick of Insect Swarm, Moonfire
- **Shadow Priest**: Never clip Shadow Word: Pain, Vampiric Touch
- Current EAX: no clip prevention logic

### Class-Specific Mechanics

| Class | Key Mechanic | Status |
|-------|-------------|--------|
| Arms Warrior | Slam weave, stance dance | Basic |
| Fury Warrior | Bloodthirst priority, execute | Basic |
| Prot Warrior | Shield slam priority, revenge | Basic |
| BM Hunter | Aspect, kill command, mend | Basic |
| MM Hunter | Steady shot, aimed shot, auto weave | Missing |
| Surv Hunter | Serpent sting, black arrow,/explosive | Basic |
| Fire Mage | Scorch stack, Combustion timing | Basic |
| Arcane Mage | 3-stack AB, burn phase, Evocation | Missing |
| Frost Mage | FSCT, shatter combos | Basic |
| Affli Lock | DoT priority, Nightfall proc | Basic |
| Demo Lock | Metamorphosis, Felguard | Missing |
| Destro Lock | Immolate, Incinerate, Conflag | Basic |
| Holy Priest | Greater Heal priority, flash heal | Basic |
| Shadow Priest | SW:P, VT, MFb rotation | Basic |
| Disc Priest | PW:S, shield management | Basic |
| Holy Pally | Holy Light, Holy Shock | Basic |
| Ret Pally | Crusader Strike, Divine Storm | Basic |
| Prot Pally | Holy Wrath, Consecration | Basic |
| Balance Druid | Wrath/Starfire, eclipse | Basic |
| Feral Druid | Mangle, rake, rip | Basic |
| Resto Druid | Healing Touch, Rejuv | Basic |
| Ele Shaman | Lightning Bolt, Chain Lightning | Basic |
| Enhance | Stormstrike, Lava Lash | Basic |
| Resto Sham | Healing Wave, Chain Heal | Basic |
| Combat Rogue | Sinister Strike, Blade Flurry | Basic |
| Assass Rogue | Mutilate, Envenom | Basic |
| Subtlety Rogue | Backstab, Hemorrhage | Missing |

### Interrupt Optimization
- Never interrupt a spell that's about to complete
- Priority: healing > CC > offensive
- Weight system already exists; refine with more spell data

### Consumables Management
- Track buff potions (Haste, Destruction, Mighty Rage)
- Track drums, food, flasks
- Auto-use at boss encounters

## Anti-Features

Things EAX should NOT build (scope creep, high complexity, low value).

- **PvP modes** — not the target use case
- **Battleground automation** — separate concern from PvE rotations
- **Fresh 1-70 leveling speedrun** — leveling support exists, speedrun is different
- **Hardcore mode** — death prevention is out of scope
- **Direct memory reading** — ban risk, stick to Sylvanas APIs
- **Multi-client coordination** — each bot runs independently
