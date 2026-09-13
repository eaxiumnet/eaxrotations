# Spell-id sweep

Ladders: 1879. Ids checked: 7374. Unique ids: 1962.

| check | hard | review |
|---|---:|---:|
| WRONG-RANK | 0 | 103 |
| RANK-ORDER | 0 | 45 |
| REDIRECTED | 0 | 119 |
| DUPLICATE-CONFLICT | 0 | 40 |
| UNSOURCED | 0 | 85 |

## WRONG-RANK

a higher rank of the same spell exists outside the ladder (the bridge names cast/effect twins alike, so verify before acting)

| file:line | label | id | finding |
|---|---|---|---|
| `EaxRotations/classes/druid/balance_sod.lua:19` | Wrath | 9912 | sod ladder head is the level-54 rank, but 17144 is the level-55 rank of the same spell |
| `EaxRotations/classes/druid/caster_vanilla.lua:21` | Wrath | 9912 | vanilla ladder head is the level-54 rank, but 17144 is the level-55 rank of the same spell |
| `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua:29` | BestialWrath | 19574 | tbc ladder head is the level-40 rank, but 38371 is the level-70 rank of the same spell |
| `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua:33` | FreezingTrap | 14311 | tbc ladder head is the level-60 rank, but 31933 is the level-65 rank of the same spell |
| `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua:35` | Intimidation | 19577 | tbc ladder head is the level-30 rank, but 24394 is the level-40 rank of the same spell |
| `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua:39` | RapidFire | 3045 | tbc ladder head is the level-26 rank, but 36828 is the level-70 rank of the same spell |
| `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua:43` | SerpentSting | 27016 | tbc ladder head is the level-67 rank, but 36984 is the level-70 rank of the same spell |
| `EaxRotations/classes/hunter/class_sylvanas.lua:73` | BestialWrath | 19574 | tbc ladder head is the level-40 rank, but 38371 is the level-70 rank of the same spell |
| `EaxRotations/classes/hunter/class_sylvanas.lua:83` | Intimidation | 19577 | tbc ladder head is the level-30 rank, but 24394 is the level-40 rank of the same spell |
| `EaxRotations/classes/hunter/class_sylvanas.lua:123` | FreezingTrap | 14311 | tbc ladder head is the level-60 rank, but 31933 is the level-65 rank of the same spell |
| `EaxRotations/classes/hunter/class_sylvanas.lua:207` | SerpentSting | 27016 | tbc ladder head is the level-67 rank, but 36984 is the level-70 rank of the same spell |
| `EaxRotations/classes/hunter/dps_hunter_sod.lua:18` | MendPet | 13542 | sod ladder head is the level-44 rank, but 13544 is the level-60 rank of the same spell |
| `EaxRotations/classes/hunter/marksmanship_sylvanas.lua:26` | BestialWrath | 19574 | tbc ladder head is the level-40 rank, but 38371 is the level-70 rank of the same spell |
| `EaxRotations/classes/hunter/marksmanship_sylvanas.lua:30` | FreezingTrap | 14311 | tbc ladder head is the level-60 rank, but 31933 is the level-65 rank of the same spell |
| `EaxRotations/classes/hunter/marksmanship_sylvanas.lua:35` | RapidFire | 3045 | tbc ladder head is the level-26 rank, but 36828 is the level-70 rank of the same spell |
| `EaxRotations/classes/hunter/marksmanship_sylvanas.lua:39` | SerpentSting | 27016 | tbc ladder head is the level-67 rank, but 36984 is the level-70 rank of the same spell |
| `EaxRotations/classes/hunter/survival_sylvanas.lua:29` | FreezingTrap | 14311 | tbc ladder head is the level-60 rank, but 31933 is the level-65 rank of the same spell |
| `EaxRotations/classes/hunter/survival_sylvanas.lua:37` | RapidFire | 3045 | tbc ladder head is the level-26 rank, but 36828 is the level-70 rank of the same spell |
| `EaxRotations/classes/hunter/survival_sylvanas.lua:42` | SerpentSting | 27016 | tbc ladder head is the level-67 rank, but 36984 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/arcane_sylvanas.lua:26` | ArcaneMissiles | 38699 | tbc ladder head is the level-69 rank, but 29955 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/arcane_sylvanas.lua:28` | Blink | 1953 | tbc ladder head is the level-20 rank, but 29883 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/arcane_sylvanas.lua:30` | Evocation | 12051 | tbc ladder head is the level-20 rank, but 30254 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/class_sylvanas.lua:54` | ArcaneMissiles | 38699 | tbc ladder head is the level-69 rank, but 29955 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/class_sylvanas.lua:84` | Blink | 1953 | tbc ladder head is the level-20 rank, but 29883 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/class_sylvanas.lua:94` | Counterspell | 2139 | tbc ladder head is the level-24 rank, but 29961 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/class_sylvanas.lua:144` | Evocation | 12051 | tbc ladder head is the level-20 rank, but 30254 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/class_sylvanas.lua:184` | FrostArmor | 27124 | tbc ladder head is the level-69 rank, but 36881 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/class_sylvanas.lua:234` | FlamestrikeRank6 | 10216 | tbc ladder head is the level-56 rank, but 27086 is the level-64 rank of the same spell |
| `EaxRotations/classes/mage/class_sylvanas.lua:399` | ConeOfCold | 27087 | tbc ladder head is the level-65 rank, but 29717 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/dps_mage_sod.lua:20` | SodFrostbolt | 10181 | sod ladder head is the level-56 rank, but 25304 is the level-60 rank of the same spell |
| `EaxRotations/classes/mage/fire_sylvanas.lua:30` | Evocation | 12051 | tbc ladder head is the level-20 rank, but 30254 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/fire_sylvanas.lua:34` | FlamestrikeRank6 | 10216 | tbc ladder head is the level-56 rank, but 27086 is the level-64 rank of the same spell |
| `EaxRotations/classes/mage/fire_sylvanas.lua:301` | IceBarrier | 11426 | tbc ladder head is the level-40 rank, but 33405 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/frost_sylvanas.lua:26` | ArcaneMissiles | 38699 | tbc ladder head is the level-69 rank, but 29955 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/frost_sylvanas.lua:27` | Blink | 1953 | tbc ladder head is the level-20 rank, but 29883 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/frost_sylvanas.lua:30` | ConeOfCold | 27087 | tbc ladder head is the level-65 rank, but 29717 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/frost_sylvanas.lua:32` | Counterspell | 2139 | tbc ladder head is the level-24 rank, but 29961 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/frost_sylvanas.lua:33` | Evocation | 12051 | tbc ladder head is the level-20 rank, but 30254 is the level-70 rank of the same spell |
| `EaxRotations/classes/mage/frost_sylvanas.lua:35` | FrostArmor | 27124 | tbc ladder head is the level-69 rank, but 36881 is the level-70 rank of the same spell |
| `EaxRotations/classes/paladin/class_sylvanas.lua:448` | SealOfWisdom | 27166 | tbc ladder head is the level-67 rank, but 27167 is the level-68 rank of the same spell |
| `EaxRotations/classes/paladin/healing_sylvanas.lua:39` | SealOfWisdom | 27166 | tbc ladder head is the level-67 rank, but 27167 is the level-68 rank of the same spell |
| `EaxRotations/classes/paladin/holy_sylvanas.lua:62` | SealOfWisdom | 27166 | tbc ladder head is the level-67 rank, but 27167 is the level-68 rank of the same spell |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:108` | SealOfWisdom | 27166 | tbc ladder head is the level-67 rank, but 27167 is the level-68 rank of the same spell |
| `EaxRotations/classes/paladin/retribution_sod.lua:32` | SodDivineShield | 642 | sod ladder head is the level-34 rank, but 1020 is the level-50 rank of the same spell |
| `EaxRotations/classes/paladin/retribution_sod.lua:33` | SodLayOnHands | 633 | sod ladder head is the level-10 rank, but 10310 is the level-50 rank of the same spell |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:65` | SealOfWisdom | 27166 | tbc ladder head is the level-67 rank, but 27167 is the level-68 rank of the same spell |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:67` | SealWisdom | 27166 | tbc ladder head is the level-67 rank, but 27167 is the level-68 rank of the same spell |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:69` | SealCommandRank1 | 20375 | tbc ladder head is the level-20 rank, but 27170 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/class_sylvanas.lua:62` | GreaterHeal | 25213 | tbc ladder head is the level-68 rank, but 29564 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/class_sylvanas.lua:72` | HolyFire | 25384 | tbc ladder head is the level-66 rank, but 29563 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/class_sylvanas.lua:162` | MindFlay | 25387 | tbc ladder head is the level-68 rank, but 37276 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/class_sylvanas.lua:262` | ShackleUndead | 10955 | tbc ladder head is the level-60 rank, but 40135 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/discipline_sylvanas.lua:48` | GreaterHeal | 25213 | tbc ladder head is the level-68 rank, but 29564 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/discipline_sylvanas.lua:49` | HolyFire | 25384 | tbc ladder head is the level-66 rank, but 29563 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/discipline_sylvanas.lua:63` | ShackleUndead | 10955 | tbc ladder head is the level-60 rank, but 40135 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/healing_sylvanas.lua:358` | GreaterHeal | 25213 | tbc ladder head is the level-68 rank, but 29564 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/holy_sylvanas.lua:66` | GreaterHeal | 25213 | tbc ladder head is the level-68 rank, but 29564 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/holy_sylvanas.lua:67` | HolyFire | 25384 | tbc ladder head is the level-66 rank, but 29563 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/holy_sylvanas.lua:77` | ShackleUndead | 10955 | tbc ladder head is the level-60 rank, but 40135 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/shadow_sylvanas.lua:41` | MindFlay | 25387 | tbc ladder head is the level-68 rank, but 37276 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/shadow_sylvanas.lua:45` | ShackleUndead | 10955 | tbc ladder head is the level-60 rank, but 40135 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/smite_sylvanas.lua:47` | HolyFire | 25384 | tbc ladder head is the level-66 rank, but 29563 is the level-70 rank of the same spell |
| `EaxRotations/classes/priest/smite_sylvanas.lua:62` | ShackleUndead | 10955 | tbc ladder head is the level-60 rank, but 40135 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/assassination_sylvanas.lua:19` | CheapShot | 1833 | tbc ladder head is the level-26 rank, but 30986 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/assassination_sylvanas.lua:20` | CloakOfShadows | 31224 | tbc ladder head is the level-66 rank, but 39666 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/assassination_sylvanas.lua:22` | DeadlyThrow | 26679 | tbc ladder head is the level-64 rank, but 37074 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/assassination_sylvanas.lua:25` | Eviscerate | 26865 | tbc ladder head is the level-64 rank, but 41177 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/class_sylvanas.lua:32` | Ambush | 27441 | tbc ladder head is the level-66 rank, but 41390 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/class_sylvanas.lua:72` | CheapShot | 1833 | tbc ladder head is the level-26 rank, but 30986 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/class_sylvanas.lua:82` | CloakOfShadows | 31224 | tbc ladder head is the level-66 rank, but 39666 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/class_sylvanas.lua:102` | DeadlyThrow | 26679 | tbc ladder head is the level-64 rank, but 37074 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/class_sylvanas.lua:132` | Eviscerate | 26865 | tbc ladder head is the level-64 rank, but 41177 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/combat_sylvanas.lua:30` | CheapShot | 1833 | tbc ladder head is the level-26 rank, but 30986 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/combat_sylvanas.lua:31` | CloakOfShadows | 31224 | tbc ladder head is the level-66 rank, but 39666 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/combat_sylvanas.lua:32` | DeadlyThrow | 26679 | tbc ladder head is the level-64 rank, but 37074 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/combat_sylvanas.lua:34` | Eviscerate | 26865 | tbc ladder head is the level-64 rank, but 41177 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/subtlety_sylvanas.lua:23` | Ambush | 27441 | tbc ladder head is the level-66 rank, but 41390 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/subtlety_sylvanas.lua:26` | CheapShot | 1833 | tbc ladder head is the level-26 rank, but 30986 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/subtlety_sylvanas.lua:27` | CloakOfShadows | 31224 | tbc ladder head is the level-66 rank, but 39666 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/subtlety_sylvanas.lua:28` | DeadlyThrow | 26679 | tbc ladder head is the level-64 rank, but 37074 is the level-70 rank of the same spell |
| `EaxRotations/classes/rogue/subtlety_sylvanas.lua:30` | Eviscerate | 26865 | tbc ladder head is the level-64 rank, but 41177 is the level-70 rank of the same spell |
| `EaxRotations/classes/shaman/elemental_vanilla.lua:48` | X | 10392 | vanilla ladder head is the level-44 rank, but 15208 is the level-56 rank of the same spell |
| `EaxRotations/classes/shaman/elemental_vanilla.lua:54` | X | 10392 | vanilla ladder head is the level-44 rank, but 15208 is the level-56 rank of the same spell |
| `EaxRotations/classes/warlock/class_sylvanas.lua:155` | DrainLife | 27220 | tbc ladder head is the level-69 rank, but 30412 is the level-70 rank of the same spell |
| `EaxRotations/classes/warlock/demonology_sylvanas.lua:36` | CurseElements | 27228 | tbc ladder head is the level-69 rank, but 36831 is the level-70 rank of the same spell |
| `EaxRotations/classes/warlock/destruction_sylvanas.lua:39` | CurseElements | 27228 | tbc ladder head is the level-69 rank, but 36831 is the level-70 rank of the same spell |
| `EaxRotations/classes/warlock/dps_sod.lua:10` | SodMendPet | 13542 | sod ladder head is the level-44 rank, but 13544 is the level-60 rank of the same spell |
| `EaxRotations/classes/warlock/dps_sod.lua:12` | SodCurseOfRecklessness | 7658 | sod ladder head is the level-28 rank, but 11717 is the level-56 rank of the same spell |
| `EaxRotations/classes/warlock/dps_sod.lua:13` | SodShadowburn | 29341 | sod ladder head is the level-1 rank, but 18871 is the level-56 rank of the same spell |
| `EaxRotations/classes/warlock/dps_sod.lua:17` | SodImmolate | 11665 | sod ladder head is the level-40 rank, but 11668 is the level-60 rank of the same spell |
| `EaxRotations/classes/warlock/dps_sod.lua:19` | SodLifeTap | 11687 | sod ladder head is the level-36 rank, but 11689 is the level-56 rank of the same spell |
| `EaxRotations/classes/warlock/dps_sod.lua:20` | SodShadowBolt | 7641 | sod ladder head is the level-36 rank, but 11661 is the level-60 rank of the same spell |
| `EaxRotations/classes/warrior/arms_sylvanas.lua:45` | Charge | 11578 | tbc ladder head is the level-46 rank, but 29320 is the level-70 rank of the same spell |
| `EaxRotations/classes/warrior/arms_sylvanas.lua:64` | ShieldWall | 871 | tbc ladder head is the level-28 rank, but 29390 is the level-70 rank of the same spell |
| `EaxRotations/classes/warrior/class_sylvanas.lua:103` | Charge | 11578 | tbc ladder head is the level-46 rank, but 29320 is the level-70 rank of the same spell |
| `EaxRotations/classes/warrior/class_sylvanas.lua:373` | ShieldWall | 871 | tbc ladder head is the level-28 rank, but 29390 is the level-70 rank of the same spell |
| `EaxRotations/classes/warrior/dps_warrior_sod.lua:12` | SodMortalStrike | 12294 | sod ladder head is the level-40 rank, but 21553 is the level-60 rank of the same spell |
| `EaxRotations/classes/warrior/dps_warrior_sod.lua:15` | SodExecute | 20660 | sod ladder head is the level-40 rank, but 20662 is the level-56 rank of the same spell |
| `EaxRotations/classes/warrior/dps_warrior_sod.lua:19` | SodSlam | 11604 | sod ladder head is the level-46 rank, but 11605 is the level-54 rank of the same spell |
| `EaxRotations/classes/warrior/fury_sylvanas.lua:55` | Charge | 11578 | tbc ladder head is the level-46 rank, but 29320 is the level-70 rank of the same spell |
| `EaxRotations/classes/warrior/tank_warrior_sod.lua:20` | SodRevenge | 11601 | sod ladder head is the level-54 rank, but 25288 is the level-60 rank of the same spell |
| `EaxRotations/classes/warrior/tank_warrior_sod.lua:25` | SodDevastate | 20243 | sod ladder head is the level-50 rank, but 30016 is the level-60 rank of the same spell |
| `EaxRotations/classes/warrior/tank_warrior_sod.lua:26` | SodDemoralizingShout | 11554 | sod ladder head is the level-34 rank, but 11556 is the level-54 rank of the same spell |

## RANK-ORDER

a higher rank is listed after a lower rank of the same spell. Adjudicated 2026-09-13: every standing row is an ORDER-INSENSITIVE rank list (talent_inference_sylvanas.lua TALENT_SIGNATURES, dispel_manager_sylvanas.lua pet-rank tables) or the deliberate vanilla Lightning Bolt downrank lane (elemental_vanilla.lua prefers a *lower* rank on purpose), so order carries no cast meaning at those sites; a NEW row means a real cast ladder has a lower rank ahead of a higher one and every cast from it silently down-ranks

| file:line | label | id | finding |
|---|---|---|---|
| `EaxRotations/classes/shaman/elemental_vanilla.lua:48` | X | 15207 | this rank (level 50) is listed after id 10392 (level 44) of the same spell |
| `EaxRotations/classes/shaman/elemental_vanilla.lua:54` | X | 15207 | this rank (level 50) is listed after id 10392 (level 44) of the same spell |
| `EaxRotations/shared/dispel_manager_sylvanas.lua:49` | (unlabeled) | 19731 | this rank (level 38) is listed after id 19505 (level 30) of the same spell |
| `EaxRotations/shared/dispel_manager_sylvanas.lua:49` | (unlabeled) | 19734 | this rank (level 46) is listed after id 19731 (level 38) of the same spell |
| `EaxRotations/shared/dispel_manager_sylvanas.lua:49` | (unlabeled) | 19736 | this rank (level 54) is listed after id 19734 (level 46) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:18` | (unlabeled) | 34916 | this rank (level 60) is listed after id 34914 (level 50) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:18` | (unlabeled) | 34917 | this rank (level 70) is listed after id 34916 (level 60) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:21` | (unlabeled) | 34863 | this rank (level 56) is listed after id 34861 (level 50) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:21` | (unlabeled) | 34864 | this rank (level 60) is listed after id 34863 (level 56) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:21` | (unlabeled) | 34865 | this rank (level 65) is listed after id 34864 (level 60) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:21` | (unlabeled) | 34866 | this rank (level 70) is listed after id 34865 (level 65) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:30` | (unlabeled) | 12505 | this rank (level 24) is listed after id 11366 (level 20) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:30` | (unlabeled) | 12522 | this rank (level 30) is listed after id 12505 (level 24) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:30` | (unlabeled) | 12523 | this rank (level 36) is listed after id 12522 (level 30) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:30` | (unlabeled) | 12524 | this rank (level 42) is listed after id 12523 (level 36) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:30` | (unlabeled) | 12525 | this rank (level 48) is listed after id 12524 (level 42) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:30` | (unlabeled) | 12526 | this rank (level 54) is listed after id 12525 (level 48) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:30` | (unlabeled) | 18809 | this rank (level 60) is listed after id 12526 (level 54) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:30` | (unlabeled) | 27132 | this rank (level 66) is listed after id 18809 (level 60) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:43` | (unlabeled) | 21551 | this rank (level 48) is listed after id 12294 (level 40) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:43` | (unlabeled) | 21552 | this rank (level 54) is listed after id 21551 (level 48) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:43` | (unlabeled) | 21553 | this rank (level 60) is listed after id 21552 (level 54) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:43` | (unlabeled) | 25248 | this rank (level 66) is listed after id 21553 (level 60) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:43` | (unlabeled) | 30330 | this rank (level 70) is listed after id 25248 (level 66) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:45` | (unlabeled) | 23923 | this rank (level 48) is listed after id 23922 (level 40) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:45` | (unlabeled) | 23924 | this rank (level 54) is listed after id 23923 (level 48) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:45` | (unlabeled) | 23925 | this rank (level 60) is listed after id 23924 (level 54) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:45` | (unlabeled) | 25258 | this rank (level 66) is listed after id 23925 (level 60) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:45` | (unlabeled) | 30356 | this rank (level 70) is listed after id 25258 (level 66) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:52` | (unlabeled) | 34412 | this rank (level 60) is listed after id 34411 (level 50) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:52` | (unlabeled) | 34413 | this rank (level 70) is listed after id 34412 (level 60) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:54` | (unlabeled) | 17347 | this rank (level 46) is listed after id 16511 (level 30) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:54` | (unlabeled) | 17348 | this rank (level 58) is listed after id 17347 (level 46) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:54` | (unlabeled) | 26864 | this rank (level 70) is listed after id 17348 (level 58) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:61` | (unlabeled) | 20900 | this rank (level 28) is listed after id 19434 (level 20) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:61` | (unlabeled) | 20901 | this rank (level 36) is listed after id 20900 (level 28) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:61` | (unlabeled) | 20902 | this rank (level 44) is listed after id 20901 (level 36) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:61` | (unlabeled) | 20903 | this rank (level 52) is listed after id 20902 (level 44) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:61` | (unlabeled) | 20904 | this rank (level 60) is listed after id 20903 (level 52) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:80` | (unlabeled) | 33983 | this rank (level 68) is listed after id 33982 (level 58) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:85` | (unlabeled) | 20929 | this rank (level 48) is listed after id 20473 (level 40) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:85` | (unlabeled) | 20930 | this rank (level 56) is listed after id 20929 (level 48) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:85` | (unlabeled) | 27174 | this rank (level 64) is listed after id 20930 (level 56) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:86` | (unlabeled) | 32699 | this rank (level 60) is listed after id 31935 (level 50) of the same spell |
| `EaxRotations/shared/talent_inference_sylvanas.lua:86` | (unlabeled) | 32700 | this rank (level 70) is listed after id 32699 (level 60) of the same spell |

## REDIRECTED

bridge name disagrees with the pinned label (wrong-family id)

| file:line | label | id | finding |
|---|---|---|---|
| `EaxRotations/classes/hunter/dps_hunter_sod.lua:35` | SodAspectHawk | 14322 | bridge calls this id 'Aspect of the Hawk' |
| `EaxRotations/classes/hunter/dps_hunter_sod.lua:35` | SodAspectHawk | 14321 | bridge calls this id 'Aspect of the Hawk' |
| `EaxRotations/classes/hunter/dps_hunter_sod.lua:35` | SodAspectHawk | 14320 | bridge calls this id 'Aspect of the Hawk' |
| `EaxRotations/classes/hunter/dps_hunter_sod.lua:35` | SodAspectHawk | 14319 | bridge calls this id 'Aspect of the Hawk' |
| `EaxRotations/classes/hunter/dps_hunter_sod.lua:35` | SodAspectHawk | 14318 | bridge calls this id 'Aspect of the Hawk' |
| `EaxRotations/classes/hunter/dps_hunter_sod.lua:35` | SodAspectHawk | 13165 | bridge calls this id 'Aspect of the Hawk' |
| `EaxRotations/classes/mage/arcane_wotlk.lua:41` | ConjureManaEmerald | 27101 | bridge calls this id 'Conjure Mana Gem' |
| `EaxRotations/classes/mage/arcane_wotlk.lua:41` | ConjureManaEmerald | 10054 | bridge calls this id 'Conjure Mana Gem' |
| `EaxRotations/classes/mage/arcane_wotlk.lua:41` | ConjureManaEmerald | 10053 | bridge calls this id 'Conjure Mana Gem' |
| `EaxRotations/classes/mage/arcane_wotlk.lua:41` | ConjureManaEmerald | 3552 | bridge calls this id 'Conjure Mana Gem' |
| `EaxRotations/classes/mage/class_sylvanas.lua:124` | ConjureManaEmerald | 10054 | bridge calls this id 'Conjure Mana Ruby' |
| `EaxRotations/classes/mage/class_sylvanas.lua:124` | ConjureManaEmerald | 10053 | bridge calls this id 'Conjure Mana Citrine' |
| `EaxRotations/classes/mage/class_sylvanas.lua:124` | ConjureManaEmerald | 3552 | bridge calls this id 'Conjure Mana Jade' |
| `EaxRotations/classes/mage/class_sylvanas.lua:124` | ConjureManaEmerald | 759 | bridge calls this id 'Conjure Mana Agate' |
| `EaxRotations/classes/mage/class_sylvanas.lua:184` | FrostArmor | 27124 | bridge calls this id 'Ice Armor' |
| `EaxRotations/classes/mage/class_sylvanas.lua:184` | FrostArmor | 10220 | bridge calls this id 'Ice Armor' |
| `EaxRotations/classes/mage/class_sylvanas.lua:184` | FrostArmor | 10219 | bridge calls this id 'Ice Armor' |
| `EaxRotations/classes/mage/class_sylvanas.lua:184` | FrostArmor | 7320 | bridge calls this id 'Ice Armor' |
| `EaxRotations/classes/mage/class_sylvanas.lua:184` | FrostArmor | 7302 | bridge calls this id 'Ice Armor' |
| `EaxRotations/classes/mage/class_sylvanas.lua:194` | RemoveCurse | 475 | bridge calls this id 'Remove Lesser Curse' |
| `EaxRotations/classes/mage/fire_sylvanas.lua:28` | ConjureManaEmerald | 10054 | bridge calls this id 'Conjure Mana Ruby' |
| `EaxRotations/classes/mage/fire_sylvanas.lua:28` | ConjureManaEmerald | 10053 | bridge calls this id 'Conjure Mana Citrine' |
| `EaxRotations/classes/mage/fire_sylvanas.lua:28` | ConjureManaEmerald | 3552 | bridge calls this id 'Conjure Mana Jade' |
| `EaxRotations/classes/mage/fire_sylvanas.lua:28` | ConjureManaEmerald | 759 | bridge calls this id 'Conjure Mana Agate' |
| `EaxRotations/classes/mage/fire_sylvanas.lua:40` | RemoveCurse | 475 | bridge calls this id 'Remove Lesser Curse' |
| `EaxRotations/classes/mage/frost_sylvanas.lua:31` | ConjureManaEmerald | 10054 | bridge calls this id 'Conjure Mana Ruby' |
| `EaxRotations/classes/mage/frost_sylvanas.lua:31` | ConjureManaEmerald | 10053 | bridge calls this id 'Conjure Mana Citrine' |
| `EaxRotations/classes/mage/frost_sylvanas.lua:31` | ConjureManaEmerald | 3552 | bridge calls this id 'Conjure Mana Jade' |
| `EaxRotations/classes/mage/frost_sylvanas.lua:31` | ConjureManaEmerald | 759 | bridge calls this id 'Conjure Mana Agate' |
| `EaxRotations/classes/mage/frost_sylvanas.lua:35` | FrostArmor | 27124 | bridge calls this id 'Ice Armor' |
| `EaxRotations/classes/mage/frost_sylvanas.lua:35` | FrostArmor | 10220 | bridge calls this id 'Ice Armor' |
| `EaxRotations/classes/mage/frost_sylvanas.lua:35` | FrostArmor | 10219 | bridge calls this id 'Ice Armor' |
| `EaxRotations/classes/mage/frost_sylvanas.lua:35` | FrostArmor | 7320 | bridge calls this id 'Ice Armor' |
| `EaxRotations/classes/mage/frost_sylvanas.lua:35` | FrostArmor | 7302 | bridge calls this id 'Ice Armor' |
| `EaxRotations/classes/mage/frost_sylvanas.lua:47` | RemoveCurse | 475 | bridge calls this id 'Remove Lesser Curse' |
| `EaxRotations/classes/paladin/class_sylvanas.lua:23` | AvengerShield | 32700 | bridge calls this id "Avenger's Shield" |
| `EaxRotations/classes/paladin/class_sylvanas.lua:23` | AvengerShield | 32699 | bridge calls this id "Avenger's Shield" |
| `EaxRotations/classes/paladin/class_sylvanas.lua:23` | AvengerShield | 31935 | bridge calls this id "Avenger's Shield" |
| `EaxRotations/classes/paladin/class_sylvanas.lua:373` | Repentance | 5164 | bridge calls this id 'Knockdown' |
| `EaxRotations/classes/paladin/healing_sylvanas.lua:31` | HolyLight | 10324 | bridge calls this id 'Redemption' |
| `EaxRotations/classes/paladin/holy_sylvanas.lua:63` | SealRighteousness | 27155 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/holy_sylvanas.lua:63` | SealRighteousness | 20293 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/holy_sylvanas.lua:63` | SealRighteousness | 20292 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/holy_sylvanas.lua:63` | SealRighteousness | 20291 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/holy_sylvanas.lua:63` | SealRighteousness | 20290 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/holy_sylvanas.lua:63` | SealRighteousness | 20289 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/holy_sylvanas.lua:63` | SealRighteousness | 20288 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/holy_sylvanas.lua:63` | SealRighteousness | 20287 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/holy_sylvanas.lua:63` | SealRighteousness | 21084 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/holy_sylvanas.lua:63` | SealRighteousness | 20154 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/protection_sod.lua:24` | SodSealMartyr | 348700 | bridge calls this id 'Seal of the Martyr' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:62` | AvengerShield | 32700 | bridge calls this id "Avenger's Shield" |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:62` | AvengerShield | 32699 | bridge calls this id "Avenger's Shield" |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:62` | AvengerShield | 31935 | bridge calls this id "Avenger's Shield" |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:106` | SealCommand | 27170 | bridge calls this id 'Seal of Command' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:106` | SealCommand | 20920 | bridge calls this id 'Seal of Command' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:106` | SealCommand | 20919 | bridge calls this id 'Seal of Command' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:106` | SealCommand | 20918 | bridge calls this id 'Seal of Command' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:106` | SealCommand | 20915 | bridge calls this id 'Seal of Command' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:106` | SealCommand | 20375 | bridge calls this id 'Seal of Command' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:110` | SealRighteousness | 27155 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:110` | SealRighteousness | 20293 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:110` | SealRighteousness | 20292 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:110` | SealRighteousness | 20291 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:110` | SealRighteousness | 20290 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:110` | SealRighteousness | 20289 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:110` | SealRighteousness | 20288 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:110` | SealRighteousness | 20287 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:110` | SealRighteousness | 21084 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/protection_sylvanas.lua:110` | SealRighteousness | 20154 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/retribution_sod.lua:26` | SodSealMartyr | 348700 | bridge calls this id 'Seal of the Martyr' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:59` | Repentance | 5164 | bridge calls this id 'Knockdown' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:61` | SealBlood | 31892 | bridge calls this id 'Seal of Blood' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:62` | SealCommand | 27170 | bridge calls this id 'Seal of Command' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:62` | SealCommand | 20920 | bridge calls this id 'Seal of Command' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:62` | SealCommand | 20919 | bridge calls this id 'Seal of Command' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:62` | SealCommand | 20918 | bridge calls this id 'Seal of Command' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:62` | SealCommand | 20915 | bridge calls this id 'Seal of Command' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:62` | SealCommand | 20375 | bridge calls this id 'Seal of Command' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:63` | SealCrusader | 27158 | bridge calls this id 'Seal of the Crusader' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:63` | SealCrusader | 20308 | bridge calls this id 'Seal of the Crusader' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:63` | SealCrusader | 20307 | bridge calls this id 'Seal of the Crusader' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:63` | SealCrusader | 20306 | bridge calls this id 'Seal of the Crusader' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:63` | SealCrusader | 20305 | bridge calls this id 'Seal of the Crusader' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:63` | SealCrusader | 20162 | bridge calls this id 'Seal of the Crusader' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:63` | SealCrusader | 21082 | bridge calls this id 'Seal of the Crusader' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:66` | SealRighteousness | 27155 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:66` | SealRighteousness | 20293 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:66` | SealRighteousness | 20292 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:66` | SealRighteousness | 20291 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:66` | SealRighteousness | 20290 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:66` | SealRighteousness | 20289 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:66` | SealRighteousness | 20288 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:66` | SealRighteousness | 20287 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:66` | SealRighteousness | 21084 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:66` | SealRighteousness | 20154 | bridge calls this id 'Seal of Righteousness' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:67` | SealWisdom | 27166 | bridge calls this id 'Seal of Wisdom' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:67` | SealWisdom | 20357 | bridge calls this id 'Seal of Wisdom' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:67` | SealWisdom | 20356 | bridge calls this id 'Seal of Wisdom' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:67` | SealWisdom | 20166 | bridge calls this id 'Seal of Wisdom' |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua:69` | SealCommandRank1 | 20375 | bridge calls this id 'Seal of Command' |
| `EaxRotations/classes/shaman/elemental_vanilla.lua:48` | X | 10392 | bridge calls this id 'Lightning Bolt' |
| `EaxRotations/classes/shaman/elemental_vanilla.lua:48` | X | 10391 | bridge calls this id 'Lightning Bolt' |
| `EaxRotations/classes/shaman/elemental_vanilla.lua:48` | X | 15207 | bridge calls this id 'Lightning Bolt' |
| `EaxRotations/classes/shaman/elemental_vanilla.lua:54` | X | 10392 | bridge calls this id 'Lightning Bolt' |
| `EaxRotations/classes/shaman/elemental_vanilla.lua:54` | X | 10391 | bridge calls this id 'Lightning Bolt' |
| `EaxRotations/classes/shaman/elemental_vanilla.lua:54` | X | 15207 | bridge calls this id 'Lightning Bolt' |
| `EaxRotations/classes/warlock/demonology_sylvanas.lua:36` | CurseElements | 27228 | bridge calls this id 'Curse of the Elements' |
| `EaxRotations/classes/warlock/demonology_sylvanas.lua:36` | CurseElements | 11722 | bridge calls this id 'Curse of the Elements' |
| `EaxRotations/classes/warlock/demonology_sylvanas.lua:36` | CurseElements | 11721 | bridge calls this id 'Curse of the Elements' |
| `EaxRotations/classes/warlock/demonology_sylvanas.lua:36` | CurseElements | 1490 | bridge calls this id 'Curse of the Elements' |
| `EaxRotations/classes/warlock/destruction_sylvanas.lua:39` | CurseElements | 27228 | bridge calls this id 'Curse of the Elements' |
| `EaxRotations/classes/warlock/destruction_sylvanas.lua:39` | CurseElements | 11722 | bridge calls this id 'Curse of the Elements' |
| `EaxRotations/classes/warlock/destruction_sylvanas.lua:39` | CurseElements | 11721 | bridge calls this id 'Curse of the Elements' |
| `EaxRotations/classes/warlock/destruction_sylvanas.lua:39` | CurseElements | 1490 | bridge calls this id 'Curse of the Elements' |
| `EaxRotations/classes/warlock/leveling_wotlk.lua:50` | CreateSoulstone | 20770 | bridge calls this id 'Resurrection' |
| `EaxRotations/classes/warlock/leveling_wotlk.lua:50` | CreateSoulstone | 20759 | bridge calls this id 'Use Soulstone' |
| `EaxRotations/classes/warlock/leveling_wotlk.lua:50` | CreateSoulstone | 20758 | bridge calls this id 'Use Soulstone' |
| `EaxRotations/classes/warrior/tank_warrior_sod.lua:25` | SodDevastate | 11597 | bridge calls this id 'Sunder Armor' |

## DUPLICATE-CONFLICT

one id pinned under two different names

| file:line | label | id | finding |
|---|---|---|---|
| `EaxRotations/classes/mage/arcane_wotlk.lua:41` | ConjureManaEmerald | 759 | same id pinned under 2 different names: conjuremanaemerald, conjuremanagem |
| `EaxRotations/classes/mage/arcane_wotlk.lua:41` | ConjureManaEmerald | 3552 | same id pinned under 2 different names: conjuremanaemerald, conjuremanagem |
| `EaxRotations/classes/mage/arcane_wotlk.lua:41` | ConjureManaEmerald | 10053 | same id pinned under 2 different names: conjuremanaemerald, conjuremanagem |
| `EaxRotations/classes/mage/arcane_wotlk.lua:41` | ConjureManaEmerald | 10054 | same id pinned under 2 different names: conjuremanaemerald, conjuremanagem |
| `EaxRotations/classes/priest/class_sylvanas.lua:102` | PowerInfusion | 10060 | same id pinned under 2 different names: bloodlustheroism, powerinfusion |
| `EaxRotations/classes/paladin/class_sylvanas.lua:63` | Redemption | 10324 | same id pinned under 2 different names: holylight, redemption |
| `EaxRotations/classes/shaman/class_sylvanas.lua:222` | LightningBolt | 10391 | same id pinned under 2 different names: lightningbolt, x |
| `EaxRotations/classes/shaman/class_sylvanas.lua:222` | LightningBolt | 10392 | same id pinned under 2 different names: lightningbolt, x |
| `EaxRotations/classes/warrior/arms_sylvanas.lua:67` | SunderArmor | 11597 | same id pinned under 2 different names: soddevastate, sunderarmor |
| `EaxRotations/classes/mage/arcane_sylvanas.lua:37` | IcyVeins | 12472 | same id pinned under 2 different names: icyveins, powerinfusion |
| `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua:27` | AspectOfTheHawk | 13165 | same id pinned under 2 different names: aspectofthehawk, sodaspecthawk |
| `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua:27` | AspectOfTheHawk | 14318 | same id pinned under 2 different names: aspectofthehawk, sodaspecthawk |
| `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua:27` | AspectOfTheHawk | 14319 | same id pinned under 2 different names: aspectofthehawk, sodaspecthawk |
| `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua:27` | AspectOfTheHawk | 14320 | same id pinned under 2 different names: aspectofthehawk, sodaspecthawk |
| `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua:27` | AspectOfTheHawk | 14321 | same id pinned under 2 different names: aspectofthehawk, sodaspecthawk |
| `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua:27` | AspectOfTheHawk | 14322 | same id pinned under 2 different names: aspectofthehawk, sodaspecthawk |
| `EaxRotations/classes/shaman/class_sylvanas.lua:222` | LightningBolt | 15207 | same id pinned under 2 different names: lightningbolt, x |
| `EaxRotations/classes/druid/bear_sylvanas.lua:68` | FaerieFireFeral | 16857 | same id pinned under 2 different names: faeriefireferal, feralfaeriefire |
| `EaxRotations/classes/druid/bear_sylvanas.lua:68` | FaerieFireFeral | 17390 | same id pinned under 2 different names: faeriefireferal, feralfaeriefire |
| `EaxRotations/classes/druid/bear_sylvanas.lua:68` | FaerieFireFeral | 17391 | same id pinned under 2 different names: faeriefireferal, feralfaeriefire |
| `EaxRotations/classes/druid/bear_sylvanas.lua:68` | FaerieFireFeral | 17392 | same id pinned under 2 different names: faeriefireferal, feralfaeriefire |
| `EaxRotations/classes/paladin/class_sylvanas.lua:448` | SealOfWisdom | 20166 | same id pinned under 2 different names: sealofwisdom, sealwisdom |
| `EaxRotations/classes/paladin/class_sylvanas.lua:233` | DivineFavor | 20216 | same id pinned under 2 different names: divinefavor, sealofwisdom |
| `EaxRotations/classes/paladin/class_sylvanas.lua:448` | SealOfWisdom | 20356 | same id pinned under 2 different names: sealofwisdom, sealwisdom |
| `EaxRotations/classes/paladin/class_sylvanas.lua:448` | SealOfWisdom | 20357 | same id pinned under 2 different names: sealofwisdom, sealwisdom |
| `EaxRotations/classes/paladin/leveling_wotlk.lua:31` | SealOfCommand | 20375 | same id pinned under 3 different names: sealcommand, sealcommandrank1, sealofcommand |
| `EaxRotations/classes/priest/class_sylvanas.lua:373` | Resurrection | 20770 | same id pinned under 2 different names: createsoulstone, resurrection |
| `EaxRotations/classes/paladin/leveling_wotlk.lua:31` | SealOfCommand | 20915 | same id pinned under 2 different names: sealcommand, sealofcommand |
| `EaxRotations/classes/paladin/leveling_wotlk.lua:31` | SealOfCommand | 20918 | same id pinned under 2 different names: sealcommand, sealofcommand |
| `EaxRotations/classes/paladin/leveling_wotlk.lua:31` | SealOfCommand | 20919 | same id pinned under 2 different names: sealcommand, sealofcommand |
| `EaxRotations/classes/paladin/leveling_wotlk.lua:31` | SealOfCommand | 20920 | same id pinned under 2 different names: sealcommand, sealofcommand |
| `EaxRotations/classes/paladin/holy_sylvanas.lua:63` | SealRighteousness | 21084 | same id pinned under 2 different names: sealofrighteousness, sealrighteousness |
| `EaxRotations/classes/druid/bear_sylvanas.lua:68` | FaerieFireFeral | 27011 | same id pinned under 2 different names: faeriefireferal, feralfaeriefire |
| `EaxRotations/classes/mage/arcane_wotlk.lua:41` | ConjureManaEmerald | 27101 | same id pinned under 2 different names: conjuremanaemerald, conjuremanagem |
| `EaxRotations/classes/paladin/class_sylvanas.lua:448` | SealOfWisdom | 27166 | same id pinned under 2 different names: sealofwisdom, sealwisdom |
| `EaxRotations/classes/paladin/leveling_wotlk.lua:31` | SealOfCommand | 27170 | same id pinned under 2 different names: sealcommand, sealofcommand |
| `EaxRotations/classes/paladin/class_sylvanas.lua:23` | AvengerShield | 31935 | same id pinned under 2 different names: avengershield, avengersshield |
| `EaxRotations/classes/paladin/class_sylvanas.lua:23` | AvengerShield | 32699 | same id pinned under 2 different names: avengershield, avengersshield |
| `EaxRotations/classes/paladin/class_sylvanas.lua:23` | AvengerShield | 32700 | same id pinned under 2 different names: avengershield, avengersshield |
| `EaxRotations/classes/paladin/protection_sod.lua:24` | SodSealMartyr | 348700 | same id pinned under 2 different names: sealofthemartyr, sodsealmartyr |

## UNSOURCED

no local source knows the id (WotLK triage only: the local index is a subset)

| file:line | label | id | finding |
|---|---|---|---|
| `EaxRotations/classes/deathknight/class_sylvanas.lua:235` | Strangulate | 47476 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/deathknight/class_sylvanas.lua:235` | Strangulate | 49913 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/deathknight/class_sylvanas.lua:235` | Strangulate | 49914 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/deathknight/class_sylvanas.lua:235` | Strangulate | 49915 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/deathknight/class_sylvanas.lua:235` | Strangulate | 49916 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/deathknight/class_sylvanas.lua:245` | DeathGrip | 49576 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/deathknight/class_sylvanas.lua:287` | AntiMagicShell | 48707 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/deathknight/class_sylvanas.lua:307` | DarkCommand | 56222 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/druid/balance_sod.lua:14` | Starsurge | 417157 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/druid/balance_sod.lua:16` | Sunfire | 414684 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/druid/balance_sod.lua:17` | Starfall | 439748 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/druid/feral_sod.lua:15` | SavageRoar | 407988 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/druid/feral_sod.lua:16` | MangleCat | 409828 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/druid/feral_sod.lua:22` | TigersFury | 417045 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/druid/feral_sod.lua:23` | Berserk | 417141 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/druid/restoration_sod.lua:21` | WildGrowth | 408120 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/druid/restoration_sod.lua:22` | Nourish | 408247 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/druid/restoration_sod.lua:23` | Lifebloom | 409824 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/druid/tank_sod.lua:21` | Lacerate | 414644 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/druid/tank_sod.lua:22` | MangleBear | 407995 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/druid/tank_sod.lua:23` | Berserk | 417141 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/druid/tank_sod.lua:34` | SodSurvivalInstincts | 409809 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/hunter/dps_hunter_sod.lua:21` | ChimeraShot | 409433 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/hunter/dps_hunter_sod.lua:22` | KillShot | 409593 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/mage/dps_mage_sod.lua:16` | SodFrozenOrb | 440802 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/mage/dps_mage_sod.lua:17` | SodBalefireBolt | 428878 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/mage/dps_mage_sod.lua:18` | SodSpellfrostBolt | 412532 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/mage/dps_mage_sod.lua:19` | SodFrostfireBolt | 401502 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/mage/dps_mage_sod.lua:25` | SodLivingBomb | 400613 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/paladin/protection_sod.lua:16` | SodDivineProtection | 458371 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/paladin/protection_sod.lua:18` | SodAvengersShield | 407669 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/paladin/protection_sod.lua:19` | SodHammerOfTheRighteous | 407632 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/paladin/protection_sod.lua:20` | SodExorcism | 415073 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/paladin/protection_sod.lua:21` | SodShieldOfRighteousness | 440658 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/paladin/retribution_sod.lua:22` | SodDivineStorm | 407778 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/paladin/retribution_sod.lua:23` | SodExorcism | 415073 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/paladin/retribution_sod.lua:24` | SodCrusaderStrike | 407676 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/priest/healing_sod.lua:20` | SodPenance | 402284 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/priest/healing_sod.lua:24` | SodPrayerOfMending | 401859 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/priest/healing_sod.lua:25` | SodCircleOfHealing | 402842 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/priest/shadow_sod.lua:15` | SodVoidPlague | 425204 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/priest/shadow_sod.lua:17` | SodVampiricTouch | 402668 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/priest/shadow_sod.lua:20` | SodHomunculi | 402799 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/priest/shadow_sod.lua:21` | SodShadowfiend | 401977 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/priest/shadow_sod.lua:23` | SodMindSpike | 431655 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/rogue/combat_sod.lua:20` | CrimsonTempest | 412096 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/rogue/combat_sod.lua:22` | Envenom | 399963 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/rogue/combat_sod.lua:23` | Mutilate | 399956 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/rogue/combat_sod.lua:24` | SaberSlash | 424785 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/rogue/combat_sod.lua:25` | PoisonedKnife | 425012 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/rogue/tank_sod.lua:14` | JustAFleshWound | 400014 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/rogue/tank_sod.lua:15` | BladeDance | 400012 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/rogue/tank_sod.lua:16` | MainGauche | 424919 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/rogue/tank_sod.lua:17` | CrimsonTempest | 412096 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/rogue/tank_sod.lua:18` | Envenom | 399963 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/rogue/tank_sod.lua:20` | SaberSlash | 424785 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/elemental_sod.lua:14` | ShamanisticRage | 425336 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/elemental_sod.lua:15` | FeralSpirit | 440580 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/elemental_sod.lua:17` | LavaBurst | 408490 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/elemental_sod.lua:19` | FireNova | 408427 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/enhancement_sod.lua:14` | FeralSpirit | 440580 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/enhancement_sod.lua:15` | ShamanisticRage | 425336 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/enhancement_sod.lua:16` | LavaBurst | 408490 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/enhancement_sod.lua:17` | MaelstromWeapon | 408498 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/enhancement_sod.lua:23` | LavaLash | 408507 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/restoration_sod.lua:18` | ShamanisticRage | 425336 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/restoration_sod.lua:19` | WaterShield | 408510 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/restoration_sod.lua:20` | Riptide | 408521 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/restoration_sod.lua:21` | HealingRain | 415236 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/restoration_sod.lua:30` | EarthShield | 408514 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/warden_sod.lua:14` | WayOfEarth | 408531 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/warden_sod.lua:15` | ShamanisticRage | 425336 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/warden_sod.lua:17` | MaelstromWeapon | 408498 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/shaman/warden_sod.lua:22` | MoltenBlast | 425339 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/warlock/dps_sod.lua:14` | SodChaosBolt | 403629 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/warlock/dps_sod.lua:15` | SodIncinerate | 412758 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/warlock/tank_sod.lua:8` | SodMetamorphosis | 403789 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/warlock/tank_sod.lua:9` | SodDemonicGrace | 425463 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/warlock/tank_sod.lua:10` | SodShadowCleave | 403851 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/warlock/tank_sod.lua:13` | SodIncinerate | 412758 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/warrior/dps_warrior_sod.lua:11` | SodRampage | 426940 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/warrior/dps_warrior_sod.lua:16` | SodRagingBlow | 402911 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/warrior/dps_warrior_sod.lua:17` | SodQuickStrike | 429765 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/warrior/tank_warrior_sod.lua:9` | SodRampage | 426940 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |
| `EaxRotations/classes/warrior/tank_warrior_sod.lua:13` | SodShockwave | 440488 | id unknown to the DBC set, both bridges, the fixtures and the pin tables |

