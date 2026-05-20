# Mob Behavior Matrix

| Mob behavior | Detection hint | Priority response | Specs most affected |
|---|---|---|---|
| Healer | Casting heal, friendly health rising | Interrupt/CC/kill before normal DPS cycle | All interrupt/control specs |
| Dangerous caster | Long cast, school nuke, AoE cast | Interrupt, ground, reflect, silence, LoS | Shaman, Rogue, Warrior, Mage, Hunter, Warlock |
| Runner | Low health, pathing away | Hamstring, stun, root, frost trap/nova, finish | Melee, Hunter, Mage |
| Cleaver/frontal | Facing tank, melee cone damage | Tank faces away; pets/melee avoid front | Tanks, melee, pet classes |
| Fear mob | Fear cast/aura | Tremor/Fear Ward/Berserker Rage/interrupt | Shaman, Priest, Warrior |
| Poison/disease user | Debuff application | Cleanse/totem/abolish based on danger | Druid, Paladin, Priest, Shaman |
| Curse/magic user | Curse/magic debuff | Decurse/dispel/spellsteal/purge | Mage, Druid, Priest, Shaman |
| Summoner | Summon cast or portal/add | Interrupt or kill before add snowball | All |
| Mana burner | Mana Burn/drain cast | Interrupt/LoS; healers/casters avoid free casts | Priest, Shaman, Mage, Warlock |
| Enrage/frenzy | Frenzy/enrage buff | Tranq Shot or defensive cooldown | Hunter, tanks |

S+ automation rule: mob behavior overrides normal rotation when the behavior can wipe the group, break CC, or create unrecoverable threat.
