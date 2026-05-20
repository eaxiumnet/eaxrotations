# Consumables, Professions, Gear, and Set Pieces

Sources: Warcraft Tavern consumables, Icy Veins per-spec enchants and consumables pages, Wowhead per-spec BiS pages, Wowhead class databases.

## Consumable Buckets

- Flask or elixir setup: TBC uses flask or battle plus guardian elixir choices.
- Potion: Super Mana Potion, Haste Potion, Destruction Potion, Ironshield Potion, Fel Mana Potion, health potions, and encounter-specific resistance potions.
- Food: choose hit, spell damage, healing, agility, strength, stamina, or spirit/MP5 depending on spec and cap needs.
- Weapon temporary: Wizard Oil, Mana Oil, sharpening stones, weightstones, Rogue poisons, Shaman imbues.
- Utility: drums, engineering explosives, bandages, protection potions, Swiftness/Free Action style PvP consumables where allowed.

## Common Flask Mapping

- Physical DPS: Flask of Relentless Assault.
- Fire/shadow/frost caster DPS: Flask of Pure Death.
- Arcane/holy/nature caster DPS: Flask of Blinding Light.
- Healers: Flask of Mighty Restoration or elixir mix based on fight length.
- Tanks: Flask of Fortification or elixir mix based on survival/threat need.

## Common Profession Mapping

- Tailoring: major early and mid-expansion throughput for cloth casters and healers through Spellfire, Frozen Shadoweave, Spellstrike, and Primal Mooncloth style pieces.
- Leatherworking: Drums of Battle are a major raid utility reason; also offers leather/mail crafted sets for several specs.
- Enchanting: ring enchants are persistent personal throughput.
- Engineering: explosives and utility are high-value for AoE, burst, PvP, and tanks.
- Jewelcrafting: early trinket and gem access, plus economic value.
- Alchemy: Alchemist's Stone and potion value, plus transmute economics.
- Blacksmithing: strongest for weapon-dependent melee specs that can use crafted weapons.

## Set Piece Research Rules

- Check each spec's Wowhead and Icy Veins gear pages for phase-specific set bonuses before implementing rotation changes.
- Track only set bonuses that change rotation behavior in code. Pure stat upgrades belong in gear notes, not rotation logic.
- Important examples to verify per spec: Feral Wolfshead Helm and late TBC set interactions, Mage and Warlock tailoring sets, Hunter tier bonuses that affect pet or shot value, healer tier bonuses affecting spell choice, tank tier bonuses affecting defensive cadence.

## Automation Implications

- Consumable automation should be opt-in and gated by encounter state, cooldown, target/boss status, and user thresholds.
- Potion logic must account for one-potion-per-combat behavior in TBC Classic contexts where applicable.
- Weapon temporary logic differs by class: Rogue poisons and Shaman imbues are class mechanics, while oils/stones are item buffs.
- Gear/set detection should be separate from base rotation. If set detection is unavailable, provide menu toggles for the rotation-changing bonuses.

## S+ Consumable Decision Tables

| Role | Best/default checks | Budget/fallback checks | Automation note |
|---|---|---|---|
| Physical DPS | Battle/guardian elixirs or flask, stat food, haste/destruction potion by spec, sharpening/weight stone if no poison/imbue conflict | Cheaper AP/agility food and elixirs | Do not overwrite Rogue poisons or Shaman imbues |
| Caster DPS | Spell damage flask or elixir pair, spell food, destruction/mana potion, wizard oil | Cheaper spell damage food/elixirs | Switch to mana plan on long fights |
| Healer | Healing flask/elixir pair, healing/mp5 food, mana oil, mana potion/rune | MP5-heavy budget set | Mana consumables should trigger before OOM |
| Tank | Fortification/survival flask, stamina food, armor/resistance potions, healthstone | Threat food/elixirs on farm | Defensive consumables key off incoming damage, not just HP |
| PvP | Free Action/Living Action-style effects where rules allow, restorative/health/mana tools, class-specific utility | Cheaper stamina/survival consumes | Must obey battleground/arena item restrictions |

## Temporary Weapon Buff Conflict Rules

- Rogue poisons occupy weapon imbue slots and should not be overwritten by stones/oils.
- Shaman weapon imbues occupy weapon imbue slots and should not be overwritten by stones/oils unless explicitly configured.
- Caster oils are valid for most casters/healers unless a class-specific imbue or encounter item replaces them.
- Sharpening/weight stones are physical-DPS options only when weapons and class mechanics allow them.
- Paladin seals are buffs, not weapon oils, but seal twisting needs swing-timer state.
