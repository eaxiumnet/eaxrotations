local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Horde" then return end
if ZGV:DoMutex("LevelingHCLASSIC") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuide("Leveling Guides\\Starter Guides (1-12)\\Undead Starter (1-6)",{
image=ZGV.IMAGESDIR.."Tirisfal Glades",
condition_suggested=function() return raceclass('Scourge') and level <= 13 end,
condition_suggested_exclusive=true,
condition_visible=function() return Undead end,
linked = {"Leveling Guides\\Hidden Guides"},
linkedhidden = true,
},[[
defaultfor Scourge
step
_NOTE:_
Wrong Character Race
|tip Guide written for {o}Undead{} characters.
|tip Other races may encounter issues.
Click Here to Continue |confirm
|only if not Undead
step
_Destroy This Item:_
|tip Saves bag space.
|tip You'll get one later.
trash Hearthstone##6948
step
talk Undertaker Mordo##1568
|tip Outside the crypt.
accept Rude Awakening##363 |goto Tirisfal Glades/0 30.22,71.65
step
kill Duskbat##1512, Young Scavenger##1508
|tip Loot items worth at least {o}10 copper{} to sell.
|tip Allows training a spell early.
|tip Increases leveling speed.
Click to continue |confirm |goto Tirisfal Glades/0 29.40,69.60 |q 364 |future
|mapmarker Tirisfal Glades/0 28.40,67.40
|mapmarker Tirisfal Glades/0 31.60,71.00
|mapmarker Tirisfal Glades/0 32.00,68.40
|only if Warrior or Warlock
step
talk Blacksmith Rand##2116
|tip Inside the building.
Sell Items |vendor Blacksmith Rand##2116 |goto Tirisfal Glades/0 32.38,66.22 |q 364 |future
|only if Warrior or Warlock
step
talk Shadow Priest Sarvis##1569
|tip Inside the building.
turnin Rude Awakening##363 |goto Tirisfal Glades/0 30.84,66.20
accept The Mindless Ones##364 |goto Tirisfal Glades/0 30.84,66.20
step
talk Venya Marthand##5667
|tip Inside the building.
accept Piercing the Veil##1470 |goto Tirisfal Glades 30.98,66.41
|only if Scourge Warlock
step
talk Maximillion##2126
|tip Inside the building.
Select _"I submit myself for further training my master."_ |gossip 98050
Train Abilities |trainer Maximillion##2126 |goto Tirisfal Glades/0 30.91,66.34 |q 1470
|only if Warlock
stickystart "Kill_Mindless_Zombies_And_Wretched_Zombies"
step
kill Rattlecage Skeleton##1890+
collect 3 Rattlecage Skull##6281 |q 1470/1 |goto Tirisfal Glades 32.20,62.60
|mapmarker Tirisfal Glades/0 30.40,61.00
|mapmarker Tirisfal Glades/0 32.20,59.40
|mapmarker Tirisfal Glades/0 33.40,64.60
|only if Scourge Warlock
stickystop "Kill_Mindless_Zombies_And_Wretched_Zombies"
step
talk Venya Marthand##5667
|tip Inside the building.
turnin Piercing the Veil##1470 |goto Tirisfal Glades 30.98,66.41
|only if Scourge Warlock
step
Summon Your Imp |complete warlockpet("Imp") |q 364
|tip Cast {o}Summon Imp{}.
|only if Warlock
step
talk Dannal Stern##2119
|tip Inside the building.
Train Abilities |trainer Dannal Stern##2119 |goto Tirisfal Glades/0 32.65,65.61 |q 364
|only if Warrior
step
label "Kill_Mindless_Zombies_And_Wretched_Zombies"
kill 8 Mindless Zombie##1501 |q 364/1 |goto Tirisfal Glades 32.60,63.40
kill 8 Wretched Zombie##1502 |q 364/2 |goto Tirisfal Glades 32.60,63.40
|mapmarker Tirisfal Glades/0 30.40,62.00
|mapmarker Tirisfal Glades/0 30.40,64.00
|mapmarker Tirisfal Glades/0 33.80,65.60
|mapmarker Tirisfal Glades/0 34.40,62.40
step
talk Shadow Priest Sarvis##1569
|tip Inside the building.
turnin The Mindless Ones##364 |goto Tirisfal Glades 30.84,66.20
accept Simple Scroll##3095 |goto Tirisfal Glades 30.84,66.20		|only if Scourge Warrior
accept Tainted Scroll##3099 |goto Tirisfal Glades 30.84,66.20		|only if Scourge Warlock
accept Encrypted Scroll##3096 |goto Tirisfal Glades 30.84,66.20		|only if Scourge Rogue
accept Hallowed Scroll##3097 |goto Tirisfal Glades 30.84,66.20		|only if Scourge Priest
accept Glyphic Scroll##3098 |goto Tirisfal Glades 30.84,66.20		|only if Scourge Mage
accept Rattling the Rattlecages##3901 |goto Tirisfal Glades 30.84,66.20
step
talk Novice Elreth##1661
|tip Inside the building.
accept The Damned##376 |goto Tirisfal Glades 30.86,66.05
step
talk Isabella##2124
|tip Inside the building.
turnin Glyphic Scroll##3098 |goto Tirisfal Glades 30.94,66.06
|only if Scourge Mage
step
talk Isabella##2124
|tip Inside the building.
Train Abilities |trainer Isabella##2124 |goto Tirisfal Glades 30.94,66.06 |q 3901
|only if Mage
step
talk Maximillion##2126
|tip Inside the building.
turnin Tainted Scroll##3099 |goto Tirisfal Glades 30.91,66.34
|only if Scourge Warlock
step
talk Maximillion##2126
|tip Inside the building.
Select _"I submit myself for further training my master."_ |gossip 98050
Train Abilities |trainer Maximillion##2126 |goto Tirisfal Glades/0 30.91,66.34 |q 3901
|only if Warlock
step
talk Dark Cleric Duesten##2123
|tip Inside the building.
turnin Hallowed Scroll##3097 |goto Tirisfal Glades 31.11,66.03
|only if Scourge Priest
step
talk Dark Cleric Duesten##2123
|tip Inside the building.
Train Abilities |trainer Dark Cleric Duesten##2123 |goto Tirisfal Glades 31.11,66.03 |q 3901
|only if Priest
stickystart "Collect_Scavenger_Paws"
stickystart "Collect_Duskbat_Wings"
step
kill 12 Rattlecage Skeleton##1890 |q 3901/1 |goto Tirisfal Glades 32.20,62.60
|mapmarker Tirisfal Glades/0 30.40,61.00
|mapmarker Tirisfal Glades/0 32.20,59.40
|mapmarker Tirisfal Glades/0 33.40,64.60
step
label "Collect_Scavenger_Paws"
kill Young Scavenger##1508+
|tip Wolves.
collect 6 Scavenger Paw##3265 |q 376/1 |goto Tirisfal Glades 31.40,58.40
|mapmarker Tirisfal Glades/0 29.00,67.80
|mapmarker Tirisfal Glades/0 29.20,64.40
|mapmarker Tirisfal Glades/0 29.40,58.80
|mapmarker Tirisfal Glades/0 30.20,62.20
|mapmarker Tirisfal Glades/0 31.00,55.40
|mapmarker Tirisfal Glades/0 32.40,67.00
|mapmarker Tirisfal Glades/0 34.40,58.20
|mapmarker Tirisfal Glades/0 34.40,66.40
step
label "Collect_Duskbat_Wings"
kill Duskbat##1512+
|tip Bats.
collect 6 Duskbat Wing##3264 |q 376/2 |goto Tirisfal Glades 31.40,58.40
|mapmarker Tirisfal Glades/0 29.00,67.80
|mapmarker Tirisfal Glades/0 29.20,64.40
|mapmarker Tirisfal Glades/0 29.40,58.80
|mapmarker Tirisfal Glades/0 30.20,62.20
|mapmarker Tirisfal Glades/0 31.00,55.40
|mapmarker Tirisfal Glades/0 32.40,67.00
|mapmarker Tirisfal Glades/0 34.40,58.20
|mapmarker Tirisfal Glades/0 34.40,66.40
step
Kill enemies
|tip Helps reach level 4 after quest turnins.
ding 3,1000 |goto Tirisfal Glades 31.40,58.40
|mapmarker Tirisfal Glades/0 29.00,67.80
|mapmarker Tirisfal Glades/0 29.20,64.40
|mapmarker Tirisfal Glades/0 29.40,58.80
|mapmarker Tirisfal Glades/0 30.20,62.20
|mapmarker Tirisfal Glades/0 31.00,55.40
|mapmarker Tirisfal Glades/0 32.40,67.00
|mapmarker Tirisfal Glades/0 34.40,58.20
|mapmarker Tirisfal Glades/0 34.40,66.40
step
talk Novice Elreth##1661
|tip Inside the building.
turnin The Damned##376 |goto Tirisfal Glades 30.86,66.05
accept Marla's Last Wish##6395 |goto Tirisfal Glades 30.86,66.05
step
talk Shadow Priest Sarvis##1569
|tip Inside the building.
turnin Rattling the Rattlecages##3901 |goto Tirisfal Glades 30.83,66.20
step
talk Isabella##2124
|tip Inside the building.
Train Abilities |trainer Isabella##2124 |goto Tirisfal Glades 30.94,66.06 |q 6395
|only if Mage
step
talk Maximillion##2126
|tip Inside the building.
Select _"I submit myself for further training my master."_ |gossip 98050
Train Abilities |trainer Maximillion##2126 |goto Tirisfal Glades/0 30.91,66.34 |q 6395
|only if Warlock
step
talk Dark Cleric Duesten##2123
|tip Inside the building.
Train Abilities |trainer Dark Cleric Duesten##2123 |goto Tirisfal Glades 31.11,66.03 |q 6395
|only if Priest
step
talk Executor Arren##1570
accept Night Web's Hollow##380 |goto Tirisfal Glades 32.15,66.01
step
talk Dannal Stern##2119
|tip Inside the building.
turnin Simple Scroll##3095 |goto Tirisfal Glades 32.69,65.56
|only if Scourge Warrior
step
talk Dannal Stern##2119
|tip Inside the building.
Train Abilities |trainer Dannal Stern##2119 |goto Tirisfal Glades 32.69,65.56 |q 380
|only if Warrior
step
talk David Trias##2122
|tip Inside the building.
turnin Encrypted Scroll##3096 |goto Tirisfal Glades 32.53,65.65
|only if Scourge Rogue
step
talk David Trias##2122
|tip Inside the building.
Train Abilities |trainer David Trias##2122 |goto Tirisfal Glades 32.53,65.65 |q 380
|only if Rogue
step
talk Deathguard Saltain##1740
|tip Walks around.
accept Scavenging Deathknell##3902 |goto Tirisfal Glades 31.61,65.60
step
click Equipment Boxes+
|tip Piles of brown boxes.
|tip Near and inside buildings.
collect 6 Scavenged Goods##11127 |q 3902/1 |goto Tirisfal Glades 33.60,65.90
|mapmarker Tirisfal Glades/0 31.30,62.40
|mapmarker Tirisfal Glades/0 32.40,64.30
step
kill 8 Young Night Web Spider##1504 |q 380/1 |goto Tirisfal Glades 29.20,59.60
|tip Outside the mine.
|mapmarker Tirisfal Glades/0 27.20,56.80
|mapmarker Tirisfal Glades/0 27.20,59.20
|mapmarker Tirisfal Glades/0 29.40,57.40
step
kill 8 Night Web Spider##1505 |q 380/2 |goto Tirisfal Glades 26.84,59.41
|tip Inside the mine.
|mapmarker Tirisfal Glades/0 23.40,58.20
|mapmarker Tirisfal Glades/0 23.40,60.20
|mapmarker Tirisfal Glades/0 25.40,59.60
step
Kill enemies
|tip Helps reach level 5 after quest turnins.
|tip Inside and outside the mine.
ding 4,1500 |goto Tirisfal Glades/0 26.84,59.41
|mapmarker Tirisfal Glades/0 23.40,58.20
|mapmarker Tirisfal Glades/0 23.40,60.20
|mapmarker Tirisfal Glades/0 25.40,59.60
|mapmarker Tirisfal Glades/0 27.20,56.80
|mapmarker Tirisfal Glades/0 29.40,57.40
|mapmarker Tirisfal Glades/0 29.20,59.60
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
|tip Inside and outside the mine.
Die on Purpose |complete isdead |goto Tirisfal Glades/0 26.84,59.41 |q 380
|mapmarker Tirisfal Glades/0 23.40,58.20
|mapmarker Tirisfal Glades/0 23.40,60.20
|mapmarker Tirisfal Glades/0 25.40,59.60
|mapmarker Tirisfal Glades/0 27.20,56.80
|mapmarker Tirisfal Glades/0 29.40,57.40
|mapmarker Tirisfal Glades/0 29.20,59.60
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Tirisfal Glades 31.24,64.89 |q 380 |zombiewalk
step
talk Deathguard Saltain##1740
|tip Walks around.
turnin Scavenging Deathknell##3902 |goto Tirisfal Glades 31.61,65.60
step
talk Executor Arren##1570
turnin Night Web's Hollow##380 |goto Tirisfal Glades 32.15,66.01
accept The Scarlet Crusade##381 |goto Tirisfal Glades 32.15,66.01
step
kill Scarlet Convert##1506, Scarlet Initiate##1507
collect 12 Scarlet Armband##3266 |q 381/1 |goto Tirisfal Glades 35.40,65.80
|mapmarker Tirisfal Glades/0 35.40,68.60
|mapmarker Tirisfal Glades/0 37.00,64.40
|mapmarker Tirisfal Glades/0 37.00,70.80
|mapmarker Tirisfal Glades/0 37.80,66.60
|mapmarker Tirisfal Glades/0 38.60,69.40
step
kill Samuel Fipps##1919
|tip Zombie.
|tip Walks around.
collect Samuel's Remains##16333 |goto Tirisfal Glades 36.68,61.57 |q 6395
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Tirisfal Glades 37.61,61.37 |q 6395
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Tirisfal Glades 31.22,64.89 |q 6395 |zombiewalk
step
click Marla's Grave
Bury Samuel's Remains |q 6395/1 |goto Tirisfal Glades 31.17,65.08
step
talk Novice Elreth##1661
|tip Inside the building.
turnin Marla's Last Wish##6395 |goto Tirisfal Glades 30.86,66.05
step
talk Dark Cleric Duesten##2123
|tip Inside the building.
accept In Favor of Darkness##5651 |goto Tirisfal Glades 31.11,66.03
|only if Scourge Priest
step
talk Executor Arren##1570
turnin The Scarlet Crusade##381 |goto Tirisfal Glades 32.15,66.01
accept The Red Messenger##382 |goto Tirisfal Glades 32.15,66.01
step
kill Meven Korgal##1667
collect Scarlet Crusade Documents##2885 |q 382/1 |goto Tirisfal Glades/0 36.51,68.80
step
Kill enemies
|tip Helps reach level 6 after quest turnins.
ding 5,2150 |goto Tirisfal Glades 35.40,65.80
|mapmarker Tirisfal Glades/0 35.40,68.60
|mapmarker Tirisfal Glades/0 37.00,64.40
|mapmarker Tirisfal Glades/0 37.00,70.80
|mapmarker Tirisfal Glades/0 37.80,66.60
|mapmarker Tirisfal Glades/0 38.60,69.40
step
talk Executor Arren##1570
turnin The Red Messenger##382 |goto Tirisfal Glades/0 32.15,66.01
accept Vital Intelligence##383 |goto Tirisfal Glades/0 32.15,66.01
step
talk Isabella##2124
|tip Inside the building.
Train Abilities |trainer Isabella##2124 |goto Tirisfal Glades 30.94,66.06 |q 383
|only if Mage
step
talk Maximillion##2126
|tip Inside the building.
Select _"I submit myself for further training my master."_ |gossip 98050
Train Abilities |trainer Maximillion##2126 |goto Tirisfal Glades/0 30.91,66.34 |q 383
|only if Warlock
step
talk Kayla Smithe##5749
|tip Buy available Grimoires.
|tip Inside the building.
Train Demon Abilities |vendor Kayla Smithe##5749 |goto Tirisfal Glades/0 30.81,66.41 |q 383
|only if Warlock
step
talk Dark Cleric Duesten##2123
|tip Inside the building.
Train Abilities |trainer Dark Cleric Duesten##2123 |goto Tirisfal Glades 31.11,66.03 |q 383
|only if Priest
step
talk Dannal Stern##2119
|tip Inside the building.
Train Abilities |trainer Dannal Stern##2119 |goto Tirisfal Glades 32.69,65.56 |q 383
|only if Warrior
step
talk David Trias##2122
|tip Inside the building.
Train Abilities |trainer David Trias##2122 |goto Tirisfal Glades 32.53,65.65 |q 383
|only if Rogue
step
Watch the dialogue
talk Calvin Montague##6784
accept A Rogue's Deal##8 |goto Tirisfal Glades 38.23,56.79
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |q 5481
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Tirisfal Glades 56.40,49.39 |q 5481 |zombiewalk
step
talk Executor Zygand##1515
turnin Vital Intelligence##383 |goto Tirisfal Glades 60.59,51.76
step
talk Innkeeper Renee##5688
|tip Inside the building.
turnin A Rogue's Deal##8 |goto Tirisfal Glades 61.71,52.05
step
talk Dark Cleric Beryl##2129
|tip Upstairs inside the building.
turnin In Favor of Darkness##5651 |goto Tirisfal Glades 61.57,52.19
accept Garments of Darkness##5650 |goto Tirisfal Glades 61.57,52.19
|only if Scourge Priest
step
Heal and Fortify Deathguard Kel |q 5650/1 |goto Tirisfal Glades 59.18,46.50
|tip Cast {o}Lesser Heal (Rank 2){} on Deathguard Kel.
|tip Cast {o}Power Word: Fortitude{} on Deathguard Kel.
|only if Scourge Priest
step
talk Dark Cleric Beryl##2129
|tip Upstairs inside the building.
turnin Garments of Darkness##5650 |goto Tirisfal Glades 61.57,52.19
|only if Scourge Priest
step
|next "Leveling Guides\\Starter Guides (1-12)\\Durotar (6-10)" |only if Warrior or Shaman
|next "Leveling Guides\\Starter Guides (1-12)\\Eversong Woods (5-10)" |only if not (Warrior or Shaman)
]])
ZygorGuidesViewer:RegisterGuide("Leveling Guides\\Starter Guides (1-12)\\Tauren Starter (1-10)",{
image=ZGV.IMAGESDIR.."Mulgore",
condition_suggested=function() return raceclass('Tauren') and level <= 12 end,
condition_suggested_exclusive=true,
condition_visible=function() return Tauren end,
linked = {"Leveling Guides\\Hidden Guides"},
linkedhidden = true,
},[[
defaultfor Tauren
step
_NOTE:_
Wrong Character Race
|tip Guide written for {o}Tauren{} characters.
|tip Other races may encounter issues.
Click Here to Continue |confirm
|only if not Tauren
step
_Destroy This Item:_
|tip Saves bag space.
|tip You'll get one later.
trash Hearthstone##6948 |q 747 |future
step
_NOTE:_
Manage Your Ammo
|tip Make sure you always have ammo.
|tip You need it to attack enemies.
|tip {o}General Goods{} vendors sell it (also Bow & Gun vendors).
|tip Try to keep your ammo bag full.
Click Here to Continue |confirm |q 747 |future
|only if Hunter
step
kill Plainstrider##2955+
|tip Loot items worth at least {o}10 copper{} to sell.
|tip Allows training a spell early.
|tip Increases leveling speed.
Click Here to Continue |confirm |goto Mulgore 45.40,81.20 |q 747 |future
|mapmarker Mulgore/0 42.40,76.40
|mapmarker Mulgore/0 42.40,80.40
|mapmarker Mulgore/0 43.40,85.00
|mapmarker Mulgore/0 44.20,88.20
|mapmarker Mulgore/0 45.40,74.00
|mapmarker Mulgore/0 46.60,85.80
|mapmarker Mulgore/0 48.00,82.80
|mapmarker Mulgore/0 48.20,75.20
|mapmarker Mulgore/0 49.00,79.80
|mapmarker Mulgore/0 49.60,86.80
|mapmarker Mulgore/0 50.60,77.20
|mapmarker Mulgore/0 51.60,74.00
|mapmarker Mulgore/0 51.60,81.60
|mapmarker Mulgore/0 52.00,84.80
|mapmarker Mulgore/0 54.00,87.40
|only if Warrior or Shaman
step
talk Kawnie Softbreeze##3072
|tip Inside the building.
Sell Items |vendor Kawnie Softbreeze##3072 |goto Mulgore/0 45.30,76.52 |q 747 |future
|only if Warrior or Shaman
step
talk Grull Hawkwind##2980
accept The Hunt Begins##747 |goto Mulgore/0 44.88,77.07
step
talk Meela Dawnstrider##3062
|tip Inside the building.
Train Abilities |trainer Meela Dawnstrider##3062 |goto Mulgore/0 45.02,75.95 |q 747
|only if Shaman
step
talk Chief Hawkwind##2981
|tip Inside the building.
accept A Humble Task##752 |goto Mulgore/0 44.18,76.06
step
talk Harutt Thunderhorn##3059
|tip Inside the building.
Train Abilities |trainer Harutt Thunderhorn##3059 |goto Mulgore/0 44.01,76.13 |q 752
|only if Warrior
stickystart "Collect_Plainstrider_Meat_And_Feathers"
step
talk Greatmother Hawkwind##2991
turnin A Humble Task##752 |goto Mulgore/0 50.03,81.16
accept A Humble Task##753 |goto Mulgore/0 50.03,81.16
step
click Water Pitcher
collect Water Pitcher##4755 |q 753/1 |goto Mulgore/0 50.21,81.36
step
label "Collect_Plainstrider_Meat_And_Feathers"
kill Plainstrider##2955+
collect 7 Plainstrider Meat##4739 |q 747/1 |goto Mulgore/0 49.00,79.80
collect 7 Plainstrider Feather##4740 |q 747/2 |goto Mulgore/0 49.00,79.80
|mapmarker Mulgore/0 42.40,76.40
|mapmarker Mulgore/0 42.40,80.40
|mapmarker Mulgore/0 43.40,85.00
|mapmarker Mulgore/0 44.20,88.20
|mapmarker Mulgore/0 45.40,74.00
|mapmarker Mulgore/0 46.60,85.80
|mapmarker Mulgore/0 48.00,82.80
|mapmarker Mulgore/0 48.20,75.20
|mapmarker Mulgore/0 45.40,81.20
|mapmarker Mulgore/0 49.60,86.80
|mapmarker Mulgore/0 50.60,77.20
|mapmarker Mulgore/0 51.60,74.00
|mapmarker Mulgore/0 51.60,81.60
|mapmarker Mulgore/0 52.00,84.80
|mapmarker Mulgore/0 54.00,87.40
step
talk Grull Hawkwind##2980
turnin The Hunt Begins##747 |goto Mulgore/0 44.88,77.07
accept Simple Note##3091 |goto Mulgore/0 44.88,77.07			|only Tauren Warrior
accept Rune-Inscribed Note##3093 |goto Mulgore/0 44.88,77.07		|only Tauren Shaman
accept Etched Note##3092 |goto Mulgore/0 44.88,77.07			|only Tauren Hunter
accept Verdant Note##3094 |goto Mulgore/0 44.88,77.07			|only Tauren Druid
accept The Hunt Continues##750 |goto Mulgore/0 44.88,77.07
step
talk Meela Dawnstrider##3062
|tip Inside the building.
turnin Rune-Inscribed Note##3093 |goto Mulgore 45.01,75.94
|only if Tauren Shaman
step
talk Gart Mistrunner##3060
|tip Inside the building.
turnin Verdant Note##3094 |goto Mulgore 45.09,75.93
|only if Tauren Druid
step
talk Gart Mistrunner##3060
|tip Inside the building.
Train Abilities |trainer Gart Mistrunner##3060 |goto Mulgore 45.09,75.93 |q 753
|only if Druid
step
talk Chief Hawkwind##2981
|tip Inside the building.
turnin A Humble Task##753 |goto Mulgore 44.18,76.06
accept Rites of the Earthmother##755 |goto Mulgore 44.18,76.06
step
talk Harutt Thunderhorn##3059
|tip Inside the building.
turnin Simple Note##3091 |goto Mulgore 44.01,76.13
|only if Tauren Warrior
step
talk Lanka Farshot##3061
|tip Inside the building.
turnin Etched Note##3092 |goto Mulgore 44.26,75.69
|only if Tauren Hunter
step
talk Lanka Farshot##3061
|tip Inside the building.
Train Abilities |trainer Lanka Farshot##3061 |goto Mulgore 44.26,75.69 |q 755
|only if Hunter
stickystart "Collect_Mountain_Cougar_Pelts"
step
talk Seer Graytongue##2982
turnin Rites of the Earthmother##755 |goto Mulgore 42.58,92.18
accept Rite of Strength##757 |goto Mulgore 42.58,92.18
step
label "Collect_Mountain_Cougar_Pelts"
kill Mountain Cougar##2961+
collect 10 Mountain Cougar Pelt##4742 |q 750/1 |goto Mulgore 47.00,88.40
|mapmarker Mulgore/0 40.80,89.60
|mapmarker Mulgore/0 43.20,93.80
|mapmarker Mulgore/0 43.60,88.00
|mapmarker Mulgore/0 44.60,91.00
|mapmarker Mulgore/0 47.40,92.60
|mapmarker Mulgore/0 49.80,90.20
|mapmarker Mulgore/0 52.20,88.00
|mapmarker Mulgore/0 52.40,92.20
|mapmarker Mulgore/0 55.40,88.00
|mapmarker Mulgore/0 55.40,91.40
step
Kill enemies
|tip Helps reach level 4 after quest turnins.
ding 3,1150 |goto Mulgore 47.00,88.40
|mapmarker Mulgore/0 40.80,89.60
|mapmarker Mulgore/0 43.20,93.80
|mapmarker Mulgore/0 43.60,88.00
|mapmarker Mulgore/0 44.60,91.00
|mapmarker Mulgore/0 47.40,92.60
|mapmarker Mulgore/0 49.80,90.20
|mapmarker Mulgore/0 52.20,88.00
|mapmarker Mulgore/0 52.40,92.20
|mapmarker Mulgore/0 55.40,88.00
|mapmarker Mulgore/0 55.40,91.40
step
talk Grull Hawkwind##2980
turnin The Hunt Continues##750 |goto Mulgore/0 44.88,77.07
accept The Battleboars##780 |goto Mulgore/0 44.88,77.07
step
talk Brave Windfeather##3209
|tip Walks around.
accept Break Sharptusk!##3376 |goto Mulgore/0 44.94,77.04
step
talk Seer Ravenfeather##5888
accept Call of Earth##1519 |goto Mulgore 44.73,76.18
|only if Tauren Shaman
step
talk Meela Dawnstrider##3062
|tip Inside the building.
Train Abilities |trainer Meela Dawnstrider##3062 |goto Mulgore/0 45.01,75.94 |q 3376
|only if Shaman
step
talk Harutt Thunderhorn##3059
|tip Inside the building.
Train Abilities |trainer Harutt Thunderhorn##3059 |goto Mulgore 44.01,76.13 |q 3376
|only if Warrior
step
talk Gart Mistrunner##3060
|tip Inside the building.
Train Abilities |trainer Gart Mistrunner##3060 |goto Mulgore 45.09,75.93 |q 3376
|only if Druid
step
talk Lanka Farshot##3061
|tip Inside the building.
Train Abilities |trainer Lanka Farshot##3061 |goto Mulgore 44.26,75.69 |q 3376
|only if Hunter
step
kill Battleboar##2966+
collect 8 Battleboar Snout##4848 |q 780/1 |goto Mulgore 52.40,79.00
collect 8 Battleboar Flank##4849 |q 780/2 |goto Mulgore 52.40,79.00
|mapmarker Mulgore/0 52.40,75.20
|mapmarker Mulgore/0 54.00,81.60
|mapmarker Mulgore/0 54.40,86.20
|mapmarker Mulgore/0 55.20,76.60
|mapmarker Mulgore/0 56.40,89.00
|mapmarker Mulgore/0 56.60,83.40
|mapmarker Mulgore/0 59.80,88.00
stickystart "Collect_Ritual_Salves_Shaman"
stickystart "Collect_Bristleback_Belts"
step
Run through the tunnel |goto Mulgore 58.15,85.02 < 15 |only if walking and not subzone("Brambleblade Ravine")
kill Chief Sharptusk Thornmantle##8554
|tip Inside the building.
collect Chief Sharptusk Thornmantle's Head##10459 |q 3376/1 |goto Mulgore 64.70,77.66
step
click Dirt-stained Map
|tip Inside the small cave.
collect Dirt-stained Map##4851 |n
use Dirt-stained Map##4851
accept Attack on Camp Narache##781 |goto Mulgore 63.24,82.70
step
label "Collect_Ritual_Salves_Shaman"
kill Bristleback Shaman##2953+
|tip Uncommon and spread out.
collect 2 Ritual Salve##6634 |q 1519/1 |goto Mulgore 63.80,79.40
|mapmarker Mulgore/0 59.40,78.20
|mapmarker Mulgore/0 59.60,75.20
|mapmarker Mulgore/0 63.40,76.20
|mapmarker Mulgore/0 63.60,81.80
|mapmarker Mulgore/0 66.00,77.80
|only if Tauren Shaman
step
label "Collect_Bristleback_Belts"
kill Bristleback Quilboar##2952, Bristleback Shaman##2953
|tip Quilboars.
collect 12 Bristleback Belt##4770 |q 757/1 |goto Mulgore 61.60,78.40
|mapmarker Mulgore/0 58.20,78.40
|mapmarker Mulgore/0 58.40,84.40
|mapmarker Mulgore/0 60.00,75.40
|mapmarker Mulgore/0 60.00,81.60
|mapmarker Mulgore/0 63.60,81.00
|mapmarker Mulgore/0 64.60,77.80
step
Kill enemies
|tip Helps reach level 6 after quest turnins.
ding 5,595 |goto Mulgore 61.60,78.40 |only if Shaman
ding 5,865 |goto Mulgore 61.60,78.40 |only if not Shaman
|mapmarker Mulgore/0 58.20,78.40
|mapmarker Mulgore/0 58.40,84.40
|mapmarker Mulgore/0 60.00,75.40
|mapmarker Mulgore/0 60.00,81.60
|mapmarker Mulgore/0 63.60,81.00
|mapmarker Mulgore/0 64.60,77.80
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Mulgore 61.60,78.40 |q 757
|mapmarker Mulgore/0 58.20,78.40
|mapmarker Mulgore/0 58.40,84.40
|mapmarker Mulgore/0 60.00,75.40
|mapmarker Mulgore/0 60.00,81.60
|mapmarker Mulgore/0 63.60,81.00
|mapmarker Mulgore/0 64.60,77.80
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Mulgore/0 42.64,78.10 |q 757 |zombiewalk
step
talk Grull Hawkwind##2980
turnin The Battleboars##780 |goto Mulgore/0 44.87,77.08
step
talk Brave Windfeather##3209
|tip Walks around.
turnin Break Sharptusk!##3376 |goto Mulgore/0 44.94,77.04
step
talk Chief Hawkwind##2981
|tip Inside the building.
turnin Attack on Camp Narache##781 |goto Mulgore 44.18,76.06
turnin Rite of Strength##757 |goto Mulgore 44.18,76.06
accept Rites of the Earthmother##763 |goto Mulgore 44.18,76.06
step
talk Harutt Thunderhorn##3059
|tip Inside the building.
Train Abilities |trainer Harutt Thunderhorn##3059 |goto Mulgore/0 44.01,76.13 |q 763
|only if Warrior
step
talk Lanka Farshot##3061
|tip Inside the building.
Train Abilities |trainer Lanka Farshot##3061 |goto Mulgore/0 44.26,75.70 |q 763
|only if Hunter
step
talk Gart Mistrunner##3060
|tip Inside the building.
Train Abilities |trainer Gart Mistrunner##3060 |goto Mulgore 45.09,75.93 |q 763
|only if Druid
step
talk Seer Ravenfeather##5888
turnin Call of Earth##1519 |goto Mulgore 44.73,76.19
accept Call of Earth##1520 |goto Mulgore 44.73,76.19
|only if Tauren Shaman
step
talk Meela Dawnstrider##3062
|tip Inside the building.
Train Abilities |trainer Meela Dawnstrider##3062 |goto Mulgore/0 45.01,75.94 |q 763
|only if Shaman
step
use Earth Sapta##6635
talk Minor Manifestation of Earth##5891
turnin Call of Earth##1520 |goto Mulgore/0 53.83,80.58
accept Call of Earth##1521 |goto Mulgore/0 53.83,80.58
|only if Tauren Shaman
step
talk Seer Ravenfeather##5888
turnin Call of Earth##1521 |goto Mulgore 44.73,76.19
|only if Tauren Shaman
step
talk Antur Fallow##6775
|tip Follow the road.
accept A Task Unfinished##1656 |goto Mulgore 38.52,81.56
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Mulgore/0 34.86,78.89 |q 1656
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Mulgore/0 46.42,55.58 |q 1656 |zombiewalk
step
talk Ahab Wheathoof##23618
accept Kyle's Gone Missing!##11129 |goto Mulgore/0 48.24,53.27
step
talk Maur Raincaller##3055
accept Mazzranache##766 |goto Mulgore/0 46.99,57.07
step
talk Harken Windtotem##2947
|tip Inside the building.
accept Swoop Hunting##761 |goto Mulgore/0 48.71,59.33
step
talk Mull Thunderhorn##2948
accept Poison Water##748 |goto Mulgore/0 48.53,60.40
|only if Tauren
step
talk Ruul Eagletalon##2985
accept Dangers of the Windfury##743 |goto Mulgore/0 47.36,62.02
step
talk Baine Bloodhoof##2993
turnin Rites of the Earthmother##763 |goto Mulgore/0 47.52,60.17
accept Sharing the Land##745 |goto Mulgore/0 47.52,60.17
accept Rite of Vision##767 |goto Mulgore/0 47.52,60.17
accept Dwarven Digging##746 |goto Mulgore/0 47.52,60.17 |only if Warrior or Shaman
step
talk Innkeeper Kauth##6747
|tip Inside the building.
turnin A Task Unfinished##1656 |goto Mulgore/0 46.62,61.09
step
talk Innkeeper Kauth##6747
|tip Inside the building.
home Bloodhoof Village |goto Mulgore/0 46.62,61.09 |q 759 |future
step
talk Zarlman Two-Moons##3054
turnin Rite of Vision##767 |goto Mulgore/0 47.76,57.54
accept Rite of Vision##771 |goto Mulgore/0 47.76,57.54
stickystart "Collect_Prairie_Wolf_Items"
stickystart "Collect_Plainstrider_Items"
stickystart "Collect_Swoop_Items"
step
click Ambercorn+
|tip Small brown pinecones.
|tip Near trees.
collect 2 Ambercorn##4809 |q 771/2 |goto Mulgore/0 38.90,59.80
|mapmarker Mulgore/0 35.40,57.60
|mapmarker Mulgore/0 37.40,68.40
|mapmarker Mulgore/0 38.90,63.70
|mapmarker Mulgore/0 38.90,71.40
|mapmarker Mulgore/0 40.80,51.40
|mapmarker Mulgore/0 41.10,53.60
|mapmarker Mulgore/0 41.20,64.00
|mapmarker Mulgore/0 42.20,56.40
|mapmarker Mulgore/0 42.80,70.20
|mapmarker Mulgore/0 43.60,72.30
|mapmarker Mulgore/0 44.40,67.10
|mapmarker Mulgore/0 44.70,49.10
|mapmarker Mulgore/0 44.80,70.20
|mapmarker Mulgore/0 45.40,52.30
|mapmarker Mulgore/0 47.80,68.20
|mapmarker Mulgore/0 48.70,64.40
|mapmarker Mulgore/0 50.40,66.40
|mapmarker Mulgore/0 51.10,71.00
|mapmarker Mulgore/0 51.60,63.40
|mapmarker Mulgore/0 52.00,61.00
|mapmarker Mulgore/0 53.00,73.60
|mapmarker Mulgore/0 53.50,57.90
|mapmarker Mulgore/0 55.70,66.60
|mapmarker Mulgore/0 56.00,62.30
|mapmarker Mulgore/0 56.70,73.00
|mapmarker Mulgore/0 57.20,69.90
|mapmarker Mulgore/0 57.70,64.80
|mapmarker Mulgore/0 59.80,67.00
step
label "Collect_Prairie_Wolf_Items"
kill Prairie Wolf##2958+
collect Prairie Wolf Heart##4804 |q 766/1 |goto Mulgore 40.40,61.80
collect 6 Prairie Wolf Paw##4758 |q 748/1 |goto Mulgore 40.40,61.80 |only if Tauren
|mapmarker Mulgore/0 33.00,76.20
|mapmarker Mulgore/0 34.00,72.60
|mapmarker Mulgore/0 35.00,52.60
|mapmarker Mulgore/0 35.00,68.40
|mapmarker Mulgore/0 35.40,55.60
|mapmarker Mulgore/0 35.40,59.40
|mapmarker Mulgore/0 36.00,65.40
|mapmarker Mulgore/0 36.00,75.80
|mapmarker Mulgore/0 36.80,71.40
|mapmarker Mulgore/0 37.40,62.40
|mapmarker Mulgore/0 38.20,47.80
|mapmarker Mulgore/0 38.20,53.40
|mapmarker Mulgore/0 38.40,59.40
|mapmarker Mulgore/0 38.40,68.80
|mapmarker Mulgore/0 38.80,74.20
|mapmarker Mulgore/0 39.40,56.20
|mapmarker Mulgore/0 39.80,50.60
|mapmarker Mulgore/0 40.20,65.80
|mapmarker Mulgore/0 40.80,71.40
|mapmarker Mulgore/0 41.80,54.40
|mapmarker Mulgore/0 43.80,71.80
|mapmarker Mulgore/0 45.40,69.20
|mapmarker Mulgore/0 48.40,68.40
|mapmarker Mulgore/0 50.60,66.20
|mapmarker Mulgore/0 50.80,70.60
|mapmarker Mulgore/0 53.00,61.40
|mapmarker Mulgore/0 53.00,68.20
|mapmarker Mulgore/0 53.80,64.60
|mapmarker Mulgore/0 53.80,71.60
|mapmarker Mulgore/0 54.80,58.40
|mapmarker Mulgore/0 56.40,66.40
|mapmarker Mulgore/0 56.60,62.40
|mapmarker Mulgore/0 57.00,69.60
step
label "Collect_Plainstrider_Items"
kill Adult Plainstrider##2956+
|tip Large walking birds.
collect Plainstrider Scale##4806	|q 766/3	|goto Mulgore 40.40,61.80
collect 4 Plainstrider Talon##4759	|q 748/2	|goto Mulgore 40.40,61.80			|only if Tauren
collect Tender Strider Meat##33009			|goto Mulgore 40.40,61.80	|q 11129
|mapmarker Mulgore/0 33.00,76.20
|mapmarker Mulgore/0 34.00,72.60
|mapmarker Mulgore/0 35.00,52.60
|mapmarker Mulgore/0 35.00,68.40
|mapmarker Mulgore/0 35.40,55.60
|mapmarker Mulgore/0 35.40,59.40
|mapmarker Mulgore/0 36.00,65.40
|mapmarker Mulgore/0 36.00,75.80
|mapmarker Mulgore/0 36.80,71.40
|mapmarker Mulgore/0 37.40,62.40
|mapmarker Mulgore/0 38.20,47.80
|mapmarker Mulgore/0 38.20,53.40
|mapmarker Mulgore/0 38.40,59.40
|mapmarker Mulgore/0 38.40,68.80
|mapmarker Mulgore/0 38.80,74.20
|mapmarker Mulgore/0 39.40,56.20
|mapmarker Mulgore/0 39.80,50.60
|mapmarker Mulgore/0 40.20,65.80
|mapmarker Mulgore/0 40.80,71.40
|mapmarker Mulgore/0 41.80,54.40
|mapmarker Mulgore/0 43.80,71.80
|mapmarker Mulgore/0 45.40,69.20
|mapmarker Mulgore/0 48.40,68.40
|mapmarker Mulgore/0 50.60,66.20
|mapmarker Mulgore/0 50.80,70.60
|mapmarker Mulgore/0 53.00,61.40
|mapmarker Mulgore/0 53.00,68.20
|mapmarker Mulgore/0 53.80,64.60
|mapmarker Mulgore/0 53.80,71.60
|mapmarker Mulgore/0 54.80,58.40
|mapmarker Mulgore/0 56.40,66.40
|mapmarker Mulgore/0 56.60,62.40
|mapmarker Mulgore/0 57.00,69.60
step
label "Collect_Swoop_Items"
kill Wiry Swoop##2969+
|tip Black birds.
|tip Uncommon and spread out.
collect Swoop Gizzard##4807 |q 766/4 |goto Mulgore 40.40,62.20
collect 8 Trophy Swoop Quill##4769 |q 761/1 |goto Mulgore 40.40,62.20
|mapmarker Mulgore/0 34.20,78.00
|mapmarker Mulgore/0 34.40,65.60
|mapmarker Mulgore/0 34.80,68.80
|mapmarker Mulgore/0 35.40,57.60
|mapmarker Mulgore/0 36.20,53.40
|mapmarker Mulgore/0 36.40,71.80
|mapmarker Mulgore/0 37.40,61.80
|mapmarker Mulgore/0 37.40,65.80
|mapmarker Mulgore/0 38.20,56.20
|mapmarker Mulgore/0 39.40,69.20
|mapmarker Mulgore/0 39.60,52.20
|mapmarker Mulgore/0 40.40,59.00
|mapmarker Mulgore/0 40.40,65.80
|mapmarker Mulgore/0 41.60,56.00
|mapmarker Mulgore/0 44.40,71.00
|mapmarker Mulgore/0 49.00,65.00
|mapmarker Mulgore/0 49.40,68.20
|mapmarker Mulgore/0 52.20,61.40
|mapmarker Mulgore/0 52.20,66.40
|mapmarker Mulgore/0 52.20,69.60
|mapmarker Mulgore/0 54.40,72.40
|mapmarker Mulgore/0 54.80,56.20
|mapmarker Mulgore/0 55.00,68.00
|mapmarker Mulgore/0 55.40,62.40
|mapmarker Mulgore/0 56.60,65.40
stickystart "Feed_Kyle"
step
talk Mull Thunderhorn##2948
turnin Poison Water##748 |goto Mulgore 48.53,60.39
accept Winterhoof Cleansing##754 |goto Mulgore 48.53,60.40
|only if Tauren
step
talk Harken Windtotem##2947
|tip Inside the building.
turnin Swoop Hunting##761 |goto Mulgore 48.71,59.33
step
label "Feed_Kyle"
use Tender Strider Meat##33009
|tip On Kyle the Frenzied.
|tip Grey wolf.
|tip Runs around the village.
Watch the dialogue
Feed Kyle |q 11129/1 |goto Mulgore 49.20,58.80
|mapmarker Mulgore/0 47.00,58.40
|mapmarker Mulgore/0 47.40,60.40
|mapmarker Mulgore/0 48.40,62.60
step
click Well Stone+
|tip Flat grey rocks.
collect 2 Well Stone##4808 |q 771/1 |goto Mulgore 53.50,66.20
step
use Winterhoof Cleansing Totem##5411
Cleanse the Winterhoof Water Well |q 754/1 |goto Mulgore 53.64,66.15
|only if Tauren
stickystart "Kill_Palemane_Skinners_And_Tanners"
step
kill 5 Palemane Poacher##2951 |q 745/3 |goto Mulgore 52.40,71.80
|mapmarker Mulgore/0 55.40,73.60
step
label "Kill_Palemane_Skinners_And_Tanners"
kill 8 Palemane Skinner##2950 |q 745/2 |goto Mulgore 53.20,71.80
kill 10 Palemane Tanner##2949 |q 745/1 |goto Mulgore 53.20,71.80
|mapmarker Mulgore/0 48.00,71.20
|mapmarker Mulgore/0 53.60,74.60
|mapmarker Mulgore/0 55.40,71.00
|mapmarker Mulgore/0 55.80,73.00
|mapmarker Mulgore/0 48.20,74.00
step
Kill enemies
|tip Helps reach level 8 after quest turnins.
ding 7,2775 |goto Mulgore 53.20,71.80
|mapmarker Mulgore/0 48.00,71.20
|mapmarker Mulgore/0 53.60,74.60
|mapmarker Mulgore/0 55.40,71.00
|mapmarker Mulgore/0 55.80,73.00
|mapmarker Mulgore/0 48.20,74.00
step
talk Mull Thunderhorn##2948
turnin Winterhoof Cleansing##754 |goto Mulgore/0 48.53,60.39
accept Thunderhorn Totem##756 |goto Mulgore/0 48.53,60.39
|only if Tauren
step
talk Baine Bloodhoof##2993
turnin Sharing the Land##745 |goto Mulgore/0 47.51,60.16
step
talk Zarlman Two-Moons##3054
turnin Rite of Vision##771 |goto Mulgore/0 47.76,57.54
accept Rite of Vision##772 |goto Mulgore/0 47.76,57.54
|tip Don't follow the wolf.
step
talk Yaw Sharpmane##3065
Train Abilities |trainer Yaw Sharpmane##3065 |goto Mulgore/0 47.82,55.68 |q 11129
|only if Hunter
step
talk Ahab Wheathoof##23618
turnin Kyle's Gone Missing!##11129 |goto Mulgore/0 48.24,53.27
step
talk Krang Stonehoof##3063
Train Abilities |trainer Krang Stonehoof##3063 |goto Mulgore/0 49.52,60.59 |q 749 |future
|only if Warrior
step
talk Gennia Runetotem##3064
|tip Inside the building.
Train Abilities |trainer Gennia Runetotem##3064 |goto Mulgore/0 48.48,59.64 |q 749 |future
|only if Druid
step
talk Narm Skychaser##3066
|tip Inside the building.
Train Abilities |trainer Narm Skychaser##3066 |goto Mulgore/0 48.38,59.15 |q 749 |future
|only if Shaman
step
map Mulgore
path	follow strictbounce;	loop off;	ants curved;	dist 30;	markers none
path	51.94,59.61	53.08,60.28	54.83,60.54	56.19,61.05	57.37,61.24
path	59.72,62.45
talk Morin Cloudstalker##2988
|tip Walks along the road.
accept The Ravaged Caravan##749
stickystart "Collect_Cougar_Items"
stickystart "Collect_Stalker_Claws"
step
click Sealed Supply Crate
turnin The Ravaged Caravan##749 |goto Mulgore 53.74,48.18
accept The Ravaged Caravan##751 |goto Mulgore 53.74,48.18
step
label "Collect_Cougar_Items"
kill Flatland Cougar##3035+
collect Flatland Cougar Femur##4805	|q 766/2	|goto Mulgore 51.00,40.80
collect 6 Cougar Claws##4802		|q 756/2	|goto Mulgore 51.00,40.80	|only if Tauren
|mapmarker Mulgore/0 34.20,43.60
|mapmarker Mulgore/0 34.20,49.80
|mapmarker Mulgore/0 35.40,47.00
|mapmarker Mulgore/0 36.40,52.60
|mapmarker Mulgore/0 37.20,44.00
|mapmarker Mulgore/0 37.20,49.40
|mapmarker Mulgore/0 40.00,51.60
|mapmarker Mulgore/0 40.20,45.40
|mapmarker Mulgore/0 40.80,42.00
|mapmarker Mulgore/0 41.40,48.60
|mapmarker Mulgore/0 42.40,53.80
|mapmarker Mulgore/0 43.20,46.00
|mapmarker Mulgore/0 44.20,39.80
|mapmarker Mulgore/0 44.20,51.00
|mapmarker Mulgore/0 45.20,43.00
|mapmarker Mulgore/0 45.60,48.20
|mapmarker Mulgore/0 47.00,37.80
|mapmarker Mulgore/0 47.80,41.00
|mapmarker Mulgore/0 47.80,45.60
|mapmarker Mulgore/0 47.80,50.60
|mapmarker Mulgore/0 49.00,35.40
|mapmarker Mulgore/0 50.00,47.80
|mapmarker Mulgore/0 52.00,35.20
|mapmarker Mulgore/0 52.20,44.40
|mapmarker Mulgore/0 53.80,38.20
|mapmarker Mulgore/0 54.20,57.00
|mapmarker Mulgore/0 54.40,60.80
|mapmarker Mulgore/0 54.60,42.40
|mapmarker Mulgore/0 55.20,50.00
|mapmarker Mulgore/0 55.40,53.20
|mapmarker Mulgore/0 55.40,70.20
|mapmarker Mulgore/0 55.80,64.40
|mapmarker Mulgore/0 56.80,38.60
|mapmarker Mulgore/0 57.00,73.60
|mapmarker Mulgore/0 57.20,56.60
|mapmarker Mulgore/0 57.40,45.40
|mapmarker Mulgore/0 58.20,51.00
|mapmarker Mulgore/0 58.20,60.60
|mapmarker Mulgore/0 58.20,67.40
|mapmarker Mulgore/0 58.40,42.40
|mapmarker Mulgore/0 58.60,70.40
|mapmarker Mulgore/0 59.20,63.80
|mapmarker Mulgore/0 59.80,54.20
|mapmarker Mulgore/0 60.00,58.00
|mapmarker Mulgore/0 60.40,46.80
|mapmarker Mulgore/0 61.20,68.40
|mapmarker Mulgore/0 61.60,61.20
|mapmarker Mulgore/0 61.60,71.60
|mapmarker Mulgore/0 62.40,51.00
|mapmarker Mulgore/0 62.80,64.40
|mapmarker Mulgore/0 63.00,55.20
step
label "Collect_Stalker_Claws"
kill Prairie Stalker##2959+
|tip Wolves.
collect 6 Stalker Claws##4801 |q 756/1 |goto Mulgore 51.00,40.80
|mapmarker Mulgore/0 34.20,43.60
|mapmarker Mulgore/0 34.20,49.80
|mapmarker Mulgore/0 35.40,47.00
|mapmarker Mulgore/0 36.40,52.60
|mapmarker Mulgore/0 37.20,44.00
|mapmarker Mulgore/0 37.20,49.40
|mapmarker Mulgore/0 40.00,51.60
|mapmarker Mulgore/0 40.20,45.40
|mapmarker Mulgore/0 40.80,42.00
|mapmarker Mulgore/0 41.40,48.60
|mapmarker Mulgore/0 42.40,53.80
|mapmarker Mulgore/0 43.20,46.00
|mapmarker Mulgore/0 44.20,39.80
|mapmarker Mulgore/0 44.20,51.00
|mapmarker Mulgore/0 45.20,43.00
|mapmarker Mulgore/0 45.60,48.20
|mapmarker Mulgore/0 47.00,37.80
|mapmarker Mulgore/0 47.80,41.00
|mapmarker Mulgore/0 47.80,45.60
|mapmarker Mulgore/0 47.80,50.60
|mapmarker Mulgore/0 49.00,35.40
|mapmarker Mulgore/0 50.00,47.80
|mapmarker Mulgore/0 52.00,35.20
|mapmarker Mulgore/0 52.20,44.40
|mapmarker Mulgore/0 53.80,38.20
|mapmarker Mulgore/0 54.20,57.00
|mapmarker Mulgore/0 54.40,60.80
|mapmarker Mulgore/0 54.60,42.40
|mapmarker Mulgore/0 55.20,50.00
|mapmarker Mulgore/0 55.40,53.20
|mapmarker Mulgore/0 55.40,70.20
|mapmarker Mulgore/0 55.80,64.40
|mapmarker Mulgore/0 56.80,38.60
|mapmarker Mulgore/0 57.00,73.60
|mapmarker Mulgore/0 57.20,56.60
|mapmarker Mulgore/0 57.40,45.40
|mapmarker Mulgore/0 58.20,51.00
|mapmarker Mulgore/0 58.20,60.60
|mapmarker Mulgore/0 58.20,67.40
|mapmarker Mulgore/0 58.40,42.40
|mapmarker Mulgore/0 58.60,70.40
|mapmarker Mulgore/0 59.20,63.80
|mapmarker Mulgore/0 59.80,54.20
|mapmarker Mulgore/0 60.00,58.00
|mapmarker Mulgore/0 60.40,46.80
|mapmarker Mulgore/0 61.20,68.40
|mapmarker Mulgore/0 61.60,61.20
|mapmarker Mulgore/0 61.60,71.60
|mapmarker Mulgore/0 62.40,51.00
|mapmarker Mulgore/0 62.80,64.40
|mapmarker Mulgore/0 63.00,55.20
|only if Tauren
step
Kill enemies
ding 9 |goto Mulgore 51.00,40.80
|mapmarker Mulgore/0 34.20,43.60
|mapmarker Mulgore/0 34.20,49.80
|mapmarker Mulgore/0 35.40,47.00
|mapmarker Mulgore/0 36.40,52.60
|mapmarker Mulgore/0 37.20,44.00
|mapmarker Mulgore/0 37.20,49.40
|mapmarker Mulgore/0 40.00,51.60
|mapmarker Mulgore/0 40.20,45.40
|mapmarker Mulgore/0 40.80,42.00
|mapmarker Mulgore/0 41.40,48.60
|mapmarker Mulgore/0 42.40,53.80
|mapmarker Mulgore/0 43.20,46.00
|mapmarker Mulgore/0 44.20,39.80
|mapmarker Mulgore/0 44.20,51.00
|mapmarker Mulgore/0 45.20,43.00
|mapmarker Mulgore/0 45.60,48.20
|mapmarker Mulgore/0 47.00,37.80
|mapmarker Mulgore/0 47.80,41.00
|mapmarker Mulgore/0 47.80,45.60
|mapmarker Mulgore/0 47.80,50.60
|mapmarker Mulgore/0 49.00,35.40
|mapmarker Mulgore/0 50.00,47.80
|mapmarker Mulgore/0 52.00,35.20
|mapmarker Mulgore/0 52.20,44.40
|mapmarker Mulgore/0 53.80,38.20
|mapmarker Mulgore/0 54.20,57.00
|mapmarker Mulgore/0 54.40,60.80
|mapmarker Mulgore/0 54.60,42.40
|mapmarker Mulgore/0 55.20,50.00
|mapmarker Mulgore/0 55.40,53.20
|mapmarker Mulgore/0 55.40,70.20
|mapmarker Mulgore/0 55.80,64.40
|mapmarker Mulgore/0 56.80,38.60
|mapmarker Mulgore/0 57.00,73.60
|mapmarker Mulgore/0 57.20,56.60
|mapmarker Mulgore/0 57.40,45.40
|mapmarker Mulgore/0 58.20,51.00
|mapmarker Mulgore/0 58.20,60.60
|mapmarker Mulgore/0 58.20,67.40
|mapmarker Mulgore/0 58.40,42.40
|mapmarker Mulgore/0 58.60,70.40
|mapmarker Mulgore/0 59.20,63.80
|mapmarker Mulgore/0 59.80,54.20
|mapmarker Mulgore/0 60.00,58.00
|mapmarker Mulgore/0 60.40,46.80
|mapmarker Mulgore/0 61.20,68.40
|mapmarker Mulgore/0 61.60,61.20
|mapmarker Mulgore/0 61.60,71.60
|mapmarker Mulgore/0 62.40,51.00
|mapmarker Mulgore/0 62.80,64.40
|mapmarker Mulgore/0 63.00,55.20
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Mulgore 51.00,40.80 |q 766
|mapmarker Mulgore/0 34.20,43.60
|mapmarker Mulgore/0 34.20,49.80
|mapmarker Mulgore/0 35.40,47.00
|mapmarker Mulgore/0 36.40,52.60
|mapmarker Mulgore/0 37.20,44.00
|mapmarker Mulgore/0 37.20,49.40
|mapmarker Mulgore/0 40.00,51.60
|mapmarker Mulgore/0 40.20,45.40
|mapmarker Mulgore/0 40.80,42.00
|mapmarker Mulgore/0 41.40,48.60
|mapmarker Mulgore/0 42.40,53.80
|mapmarker Mulgore/0 43.20,46.00
|mapmarker Mulgore/0 44.20,39.80
|mapmarker Mulgore/0 44.20,51.00
|mapmarker Mulgore/0 45.20,43.00
|mapmarker Mulgore/0 45.60,48.20
|mapmarker Mulgore/0 47.00,37.80
|mapmarker Mulgore/0 47.80,41.00
|mapmarker Mulgore/0 47.80,45.60
|mapmarker Mulgore/0 47.80,50.60
|mapmarker Mulgore/0 49.00,35.40
|mapmarker Mulgore/0 50.00,47.80
|mapmarker Mulgore/0 52.00,35.20
|mapmarker Mulgore/0 52.20,44.40
|mapmarker Mulgore/0 53.80,38.20
|mapmarker Mulgore/0 54.20,57.00
|mapmarker Mulgore/0 54.40,60.80
|mapmarker Mulgore/0 54.60,42.40
|mapmarker Mulgore/0 55.20,50.00
|mapmarker Mulgore/0 55.40,53.20
|mapmarker Mulgore/0 55.40,70.20
|mapmarker Mulgore/0 55.80,64.40
|mapmarker Mulgore/0 56.80,38.60
|mapmarker Mulgore/0 57.00,73.60
|mapmarker Mulgore/0 57.20,56.60
|mapmarker Mulgore/0 57.40,45.40
|mapmarker Mulgore/0 58.20,51.00
|mapmarker Mulgore/0 58.20,60.60
|mapmarker Mulgore/0 58.20,67.40
|mapmarker Mulgore/0 58.40,42.40
|mapmarker Mulgore/0 58.60,70.40
|mapmarker Mulgore/0 59.20,63.80
|mapmarker Mulgore/0 59.80,54.20
|mapmarker Mulgore/0 60.00,58.00
|mapmarker Mulgore/0 60.40,46.80
|mapmarker Mulgore/0 61.20,68.40
|mapmarker Mulgore/0 61.60,61.20
|mapmarker Mulgore/0 61.60,71.60
|mapmarker Mulgore/0 62.40,51.00
|mapmarker Mulgore/0 62.80,64.40
|mapmarker Mulgore/0 63.00,55.20
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Mulgore 46.41,55.57 |q 766 |zombiewalk
step
talk Maur Raincaller##3055
turnin Mazzranache##766 |goto Mulgore 46.98,57.07
step
talk Mull Thunderhorn##2948
turnin Thunderhorn Totem##756 |goto Mulgore 48.53,60.40
accept Thunderhorn Cleansing##758 |goto Mulgore 48.53,60.40
|only if Tauren
step
talk Vira Younghoof##5939
|tip Inside the building.
Learn First Aid |skillmax First Aid,75 |goto Mulgore/0 46.80,60.85
|only if Warrior
step
_NOTE:_
Create Bandages in Downtime
|tip While waiting for things like boats.
|tip Increases skill in First Aid.
|tip Need higher skill to make better bandages.
|tip Keep bandages to heal yourself.
Click Here to Continue |confirm |q 758
|only if Warrior
step
use Thunderhorn Cleansing Totem##5415
Cleanse the Thunderhorn Water Well |q 758/1 |goto Mulgore 44.59,45.43
|only if Tauren
step
kill Bael'dun Digger##2989, Bael'dun Appraiser##2990
|tip Dwarves.
collect 5 Prospector's Pick##4702 |goto Mulgore 34.40,47.20 |q 746
|mapmarker Mulgore/0 31.00,49.20
|mapmarker Mulgore/0 32.00,47.40
|mapmarker Mulgore/0 33.40,49.60
|only if Warrior or Shaman
step
kill Windfury Harpy##2962, Windfury Wind Witch##2963
|tip Harpies.
collect 8 Windfury Talon##4751 |q 743/1 |goto Mulgore 34.60,41.40
|mapmarker Mulgore/0 32.40,41.20
step
talk Seer Wiserunner##2984
|tip Inside the small cave.
|tip Run around the mountain.
turnin Rite of Vision##772 |goto Mulgore 32.72,36.09
accept Rite of Wisdom##773 |goto Mulgore 32.72,36.09
step
_Destroy This Item:_
|tip Not needed.
trash Water of the Seers##4823
step
talk Lorekeeper Raintotem##3233
accept A Sacred Burial##833 |goto Mulgore 59.86,25.63
stickystart "Kill_Bristleback_Interlopers"
step
talk Ancestral Spirit##2994
turnin Rite of Wisdom##773 |goto Mulgore 61.45,21.02
accept Journey into Thunder Bluff##775 |goto Mulgore 61.45,21.02
step
label "Kill_Bristleback_Interlopers"
kill 8 Bristleback Interloper##3232 |q 833/1 |goto Mulgore 60.40,22.00
|mapmarker Mulgore/0 60.00,20.00
|mapmarker Mulgore/0 61.60,23.60
|mapmarker Mulgore/0 62.60,21.40
step
talk Lorekeeper Raintotem##3233
turnin A Sacred Burial##833 |goto Mulgore 59.86,25.63
step
Kill enemies
ding 10 |goto Mulgore 60.40,22.00
|mapmarker Mulgore/0 60.00,20.00
|mapmarker Mulgore/0 61.60,23.60
|mapmarker Mulgore/0 62.60,21.40
step
_NOTE:_
Stronger Ammo Available
|tip Buy level 10 ammo when restocking.
Click Here to Continue |confirm |q 743
|only if Hunter
step
talk Skorn Whitecloud##3052
accept The Hunter's Way##861 |goto Mulgore 46.76,60.23
|only if Warror or Shaman
step
talk Ruul Eagletalon##2985
turnin Dangers of the Windfury##743 |goto Mulgore 47.35,62.02
step
talk Mull Thunderhorn##2948
turnin Thunderhorn Cleansing##758 |goto Mulgore 48.53,60.40
accept Wildmane Totem##759 |goto Mulgore 48.53,60.40
|only if Tauren
step
talk Krang Stonehoof##3063
accept Veteran Uzzek##1505 |goto Mulgore 49.52,60.58
|only if Tauren Warrior
step
talk Krang Stonehoof##3063
Train Abilities |trainer Krang Stonehoof##3063 |goto Mulgore/0 49.52,60.59 |q 1505
|only if Warrior
step
talk Yaw Sharpmane##3065
accept Taming the Beast##6061 |goto Mulgore 47.82,55.69
|only if Tauren Hunter
step
talk Yaw Sharpmane##3065
Train Abilities |trainer Yaw Sharpmane##3065 |goto Mulgore/0 47.82,55.68 |q 6061
|only if Hunter
step
use Taming Rod##15914
|tip On an Adult Plainstrider.
|tip Large walking birds.
Tame an Adult Plainstrider |q 6061/1 |goto Mulgore 41.80,54.40
|mapmarker Mulgore/0 33.00,76.20
|mapmarker Mulgore/0 34.00,72.60
|mapmarker Mulgore/0 35.00,52.60
|mapmarker Mulgore/0 35.00,68.40
|mapmarker Mulgore/0 35.40,55.60
|mapmarker Mulgore/0 35.40,59.40
|mapmarker Mulgore/0 36.00,65.40
|mapmarker Mulgore/0 36.00,75.80
|mapmarker Mulgore/0 36.80,71.40
|mapmarker Mulgore/0 37.40,62.40
|mapmarker Mulgore/0 38.20,47.80
|mapmarker Mulgore/0 38.20,53.40
|mapmarker Mulgore/0 38.40,59.40
|mapmarker Mulgore/0 38.40,68.80
|mapmarker Mulgore/0 38.80,74.20
|mapmarker Mulgore/0 39.40,56.20
|mapmarker Mulgore/0 39.80,50.60
|mapmarker Mulgore/0 40.20,65.80
|mapmarker Mulgore/0 40.80,71.40
|mapmarker Mulgore/0 40.40,61.80
|mapmarker Mulgore/0 43.80,71.80
|mapmarker Mulgore/0 45.40,69.20
|mapmarker Mulgore/0 48.40,68.40
|mapmarker Mulgore/0 50.60,66.20
|mapmarker Mulgore/0 50.80,70.60
|mapmarker Mulgore/0 53.00,61.40
|mapmarker Mulgore/0 53.00,68.20
|mapmarker Mulgore/0 53.80,64.60
|mapmarker Mulgore/0 53.80,71.60
|mapmarker Mulgore/0 54.80,58.40
|mapmarker Mulgore/0 56.40,66.40
|mapmarker Mulgore/0 56.60,62.40
|mapmarker Mulgore/0 57.00,69.60
|only if Tauren Hunter
step
talk Yaw Sharpmane##3065
turnin Taming the Beast##6061 |goto Mulgore 47.82,55.69
accept Taming the Beast##6087 |goto Mulgore 47.82,55.69
|only if Tauren Hunter
step
use Taming Rod##15915
|tip On a Prairie Stalker.
|tip Wolves.
Tame a Prairie Stalker |q 6087/1 |goto Mulgore 47.80,50.60
|mapmarker Mulgore/0 34.20,43.60
|mapmarker Mulgore/0 34.20,49.80
|mapmarker Mulgore/0 35.40,47.00
|mapmarker Mulgore/0 36.40,52.60
|mapmarker Mulgore/0 37.20,44.00
|mapmarker Mulgore/0 37.20,49.40
|mapmarker Mulgore/0 40.00,51.60
|mapmarker Mulgore/0 40.20,45.40
|mapmarker Mulgore/0 40.80,42.00
|mapmarker Mulgore/0 41.40,48.60
|mapmarker Mulgore/0 42.40,53.80
|mapmarker Mulgore/0 43.20,46.00
|mapmarker Mulgore/0 44.20,39.80
|mapmarker Mulgore/0 44.20,51.00
|mapmarker Mulgore/0 45.20,43.00
|mapmarker Mulgore/0 45.60,48.20
|mapmarker Mulgore/0 47.00,37.80
|mapmarker Mulgore/0 47.80,41.00
|mapmarker Mulgore/0 47.80,45.60
|mapmarker Mulgore/0 51.00,40.80
|mapmarker Mulgore/0 49.00,35.40
|mapmarker Mulgore/0 50.00,47.80
|mapmarker Mulgore/0 52.00,35.20
|mapmarker Mulgore/0 52.20,44.40
|mapmarker Mulgore/0 53.80,38.20
|mapmarker Mulgore/0 54.20,57.00
|mapmarker Mulgore/0 54.40,60.80
|mapmarker Mulgore/0 54.60,42.40
|mapmarker Mulgore/0 55.20,50.00
|mapmarker Mulgore/0 55.40,53.20
|mapmarker Mulgore/0 55.40,70.20
|mapmarker Mulgore/0 55.80,64.40
|mapmarker Mulgore/0 56.80,38.60
|mapmarker Mulgore/0 57.00,73.60
|mapmarker Mulgore/0 57.20,56.60
|mapmarker Mulgore/0 57.40,45.40
|mapmarker Mulgore/0 58.20,51.00
|mapmarker Mulgore/0 58.20,60.60
|mapmarker Mulgore/0 58.20,67.40
|mapmarker Mulgore/0 58.40,42.40
|mapmarker Mulgore/0 58.60,70.40
|mapmarker Mulgore/0 59.20,63.80
|mapmarker Mulgore/0 59.80,54.20
|mapmarker Mulgore/0 60.00,58.00
|mapmarker Mulgore/0 60.40,46.80
|mapmarker Mulgore/0 61.20,68.40
|mapmarker Mulgore/0 61.60,61.20
|mapmarker Mulgore/0 61.60,71.60
|mapmarker Mulgore/0 62.40,51.00
|mapmarker Mulgore/0 62.80,64.40
|mapmarker Mulgore/0 63.00,55.20
|only if Tauren Hunter
step
talk Yaw Sharpmane##3065
turnin Taming the Beast##6087 |goto Mulgore 47.82,55.69
accept Taming the Beast##6088 |goto Mulgore 47.82,55.69
|only if Tauren Hunter
step
use Taming Rod##15916
|tip On a Swoop.
|tip Black birds.
Tame a Swoop |q 6088/1 |goto Mulgore 45.20,50.00
|mapmarker Mulgore/0 34.40,42.00
|mapmarker Mulgore/0 34.40,49.40
|mapmarker Mulgore/0 36.20,44.40
|mapmarker Mulgore/0 38.00,41.60
|mapmarker Mulgore/0 41.20,42.00
|mapmarker Mulgore/0 41.20,48.20
|mapmarker Mulgore/0 42.40,52.40
|mapmarker Mulgore/0 44.80,35.60
|mapmarker Mulgore/0 45.00,40.80
|mapmarker Mulgore/0 47.00,45.40
|mapmarker Mulgore/0 48.60,48.40
|mapmarker Mulgore/0 49.60,40.40
|mapmarker Mulgore/0 50.00,45.60
|mapmarker Mulgore/0 51.20,34.40
|mapmarker Mulgore/0 52.40,37.20
|mapmarker Mulgore/0 53.40,45.20
|mapmarker Mulgore/0 55.40,42.40
|mapmarker Mulgore/0 56.80,46.20
|mapmarker Mulgore/0 57.00,57.80
|mapmarker Mulgore/0 57.20,68.00
|mapmarker Mulgore/0 57.40,49.40
|mapmarker Mulgore/0 58.40,64.20
|mapmarker Mulgore/0 59.40,59.80
|mapmarker Mulgore/0 60.20,55.20
|only if Tauren Hunter
step
talk Yaw Sharpmane##3065
turnin Taming the Beast##6088 |goto Mulgore 47.82,55.69
accept Training the Beast##6089 |goto Mulgore 47.82,55.69
|only if Tauren Hunter
step
talk Narm Skychaser##3066
|tip Inside the building.
accept Call of Fire##2984 |goto Mulgore 48.39,59.16
|only if Tauren Shaman
step
talk Narm Skychaser##3066
|tip Inside the building.
Train Abilities |trainer Narm Skychaser##3066 |goto Mulgore/0 48.38,59.15 |q 2984
|only if Shaman
step
talk Gennia Runetotem##3064
|tip Inside the building.
accept Heeding the Call##5928 |goto Mulgore 48.48,59.64
|only if Tauren Druid
step
talk Gennia Runetotem##3064
|tip Inside the building.
Train Abilities |trainer Gennia Runetotem##3064 |goto Mulgore/0 48.48,59.64 |q 5928
|only if Druid
step
map Mulgore
path	follow strictbounce;	loop off;	ants curved;	dist 30;	markers none
path	51.94,59.61	53.08,60.28	54.83,60.54	56.19,61.05	57.37,61.24
path	59.72,62.45
talk Morin Cloudstalker##2988
|tip Walks along the road.
turnin The Ravaged Caravan##751
accept The Venture Co.##764		|only if Warrior or Shaman
accept Supervisor Fizsprocket##765	|only if Warrior or Shaman
step
_NOTE:_
Tame a Prairie Wolf Alpha
|tip Cast {o}Tame Beast{} on a {o}Prairie Wolf Alpha{}.
Click Here to Continue |confirm |goto Mulgore 60.00,59.00 |q 759
|mapmarker Mulgore/0 57.40,60.60
|mapmarker Mulgore/0 58.00,67.00
|mapmarker Mulgore/0 58.40,55.00
|mapmarker Mulgore/0 59.80,64.00
|mapmarker Mulgore/0 60.40,69.20
|mapmarker Mulgore/0 61.40,53.00
|mapmarker Mulgore/0 62.20,56.20
|mapmarker Mulgore/0 62.40,61.60
|mapmarker Mulgore/0 62.40,65.60
|mapmarker Mulgore/0 64.00,69.00
|mapmarker Mulgore/0 65.20,57.40
|mapmarker Mulgore/0 65.20,64.20
|mapmarker Mulgore/0 66.00,60.60
|mapmarker Mulgore/0 66.60,67.40
|mapmarker Mulgore/0 67.40,70.80
|mapmarker Mulgore/0 68.20,63.40
|only if Tauren Hunter
step
kill Prairie Wolf Alpha##2960+
collect 8 Prairie Alpha Tooth##4803 |q 759/1 |goto Mulgore 62.40,61.60
|mapmarker Mulgore/0 62.20,56.20
|mapmarker Mulgore/0 62.40,65.60
|mapmarker Mulgore/0 64.00,69.00
|mapmarker Mulgore/0 65.20,57.40
|mapmarker Mulgore/0 65.20,64.20
|mapmarker Mulgore/0 66.00,60.60
|mapmarker Mulgore/0 66.60,67.40
|mapmarker Mulgore/0 67.40,70.80
|mapmarker Mulgore/0 68.20,63.40
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Mulgore 62.40,61.60 |q 759
|mapmarker Mulgore/0 62.20,56.20
|mapmarker Mulgore/0 62.40,65.60
|mapmarker Mulgore/0 64.00,69.00
|mapmarker Mulgore/0 65.20,57.40
|mapmarker Mulgore/0 65.20,64.20
|mapmarker Mulgore/0 66.00,60.60
|mapmarker Mulgore/0 66.60,67.40
|mapmarker Mulgore/0 67.40,70.80
|mapmarker Mulgore/0 68.20,63.40
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Mulgore 46.41,55.58 |q 759 |zombiewalk
step
talk Mull Thunderhorn##2948
turnin Wildmane Totem##759 |goto Mulgore 48.53,60.40
accept Wildmane Cleansing##760 |goto Mulgore 48.53,60.40 |only if Warrior or Shaman
|only if Tauren
step
talk Omusa Thunderhorn##10378
fpath Camp Taurajo |goto The Barrens 44.45,59.15
step
talk Omusa Thunderhorn##10378
|tip Open the flight map.
|tip Allows the guide to learn your flight paths.
fpath Thunder Bluff |goto The Barrens 44.45,59.15
step
talk Innkeeper Pala##6746
|tip Inside the building.
home Thunder Bluff |goto Thunder Bluff 45.81,64.71 |q 5932 |future
|only if Tauren Druid
step
talk Turak Runetotem##3033
|tip Inside the building.
turnin Heeding the Call##5928 |goto Thunder Bluff 76.46,27.23
accept Moonglade##5922 |goto Thunder Bluff 76.46,27.23
|only if Tauren Druid
step
talk Arch Druid Hamuul Runetotem##5769
|tip Inside the building.
accept The Barrens Oases##886 |goto Thunder Bluff 78.62,28.56
|only if Tauren Druid
step
talk Dendrite Starblaze##11802
|tip Upstairs inside the building.
turnin Moonglade##5922 |goto Moonglade 56.21,30.64
accept Great Bear Spirit##5930 |goto Moonglade 56.21,30.64
|only if Tauren Druid
step
talk Great Bear Spirit##11956
Select _"What do you represent, spirit?"_
Seek Out the Great Bear Spirit and Learn what it Has to Share with You About the Nature of the Bear |q 5930/1 |goto Moonglade 39.11,27.51
|only if Tauren Druid
step
talk Faustron##12740
fpath Moonglade |goto Moonglade 32.11,66.60
|only if Tauren Druid
step
talk Dendrite Starblaze##11802
|tip Upstairs inside the building.
turnin Great Bear Spirit##5930 |goto Moonglade 56.21,30.64
accept Back to Thunder Bluff##5932 |goto Moonglade 56.21,30.64
|only if Tauren Druid
step
talk Turak Runetotem##3033
|tip Inside the building.
turnin Back to Thunder Bluff##5932 |goto Thunder Bluff 76.46,27.23
accept Body and Heart##6002 |goto Thunder Bluff 76.46,27.23
|only if Tauren Druid
step
use Cenarion Lunardust##15710
kill Lunaclaw##12138
|tip Spirit appears.
talk Lunaclaw Spirit##12144
Select _"You have fought well, spirit. I ask you to grant me the strength of your body and the strength of your heart."_
Face Lunaclaw and Earn the Strength of Body and Heart it Possesses |q 6002/1 |goto The Barrens 42.00,60.86
|only if Tauren Druid
step
talk Kirge Sternhorn##3418
accept Journey to the Crossroads##854 |goto The Barrens 44.88,58.61
|only if Tauren
step
talk Tonga Runetotem##3448
|tip Carefully follow the road.
|tip Higher level enemies.
turnin The Barrens Oases##886 |goto The Barrens/0 52.26,31.93
|only if Tauren Druid
step
talk Thork##3429
|tip Carefully follow the road.		|only if not Druid
|tip Higher level enemies.		|only if not Druid
turnin Journey to the Crossroads##854 |goto The Barrens 51.50,30.87
|only if Tauren
step
talk Devrak##3615
fpath Crossroads |goto The Barrens 51.51,30.34
step
talk Jahan Hawkwing##3483
accept A Bundle of Hides##6361 |goto The Barrens 51.21,29.05
|only if Tauren
step
talk Innkeeper Boorand Plainswind##3934
|tip Inside the building.
home The Crossroads |goto The Barrens 51.99,29.89 |q 6363 |future
step
talk Devrak##3615
turnin A Bundle of Hides##6361 |goto The Barrens 51.50,30.34
accept Ride to Thunder Bluff##6362 |goto The Barrens 51.50,30.34
|only if Tauren
step
talk Holt Thunderhorn##3039
|tip Inside the building.
turnin Training the Beast##6089 |goto Thunder Bluff 57.31,89.76
|only if Tauren Hunter
step
talk Kaga Mistrunner##3025
buy Tough Jerky##117 |n
|tip Buy {o}20{}, if possible.
|tip Used to feed your pet.
Visit the Vendor |vendor Kaga Mistrunner##3025 |goto Thunder Bluff/0 52.32,47.77 |q 854 |future
|only if Tauren Hunter
step
talk Cairne Bloodhoof##3057
|tip Inside the building.
turnin Journey into Thunder Bluff##775 |goto Thunder Bluff 60.30,51.68
accept Rites of the Earthmother##776 |goto Thunder Bluff 60.30,51.68 |only if Warrior or Shaman
step
talk Turak Runetotem##3033
|tip Inside the building.
turnin Body and Heart##6002 |goto Thunder Bluff 76.46,27.23
|only if Tauren Druid
step
talk Ahanu##8359
|tip Inside the building.
turnin Ride to Thunder Bluff##6362 |goto Thunder Bluff 45.77,55.84
accept Tal the Wind Rider Master##6363 |goto Thunder Bluff 45.77,55.84
|only if Tauren
step
talk Tal##2995
|tip Top of the tower.
turnin Tal the Wind Rider Master##6363 |goto Thunder Bluff 47.00,49.83
accept Return to Jahan##6364 |goto Thunder Bluff 47.00,49.83
|only if Tauren
step
use Prospector's Pick##4702+
|tip Next to the forge.
collect 5 Broken Tools##4703 |q 746/1 |goto Thunder Bluff 39.63,55.93
|only if Warrior or Shaman
step
talk Eyahn Eagletalon##2987
accept Preparation for Ceremony##744 |goto Thunder Bluff 37.69,59.56
|only if Warrior or Shaman
step
talk Ansekhwa##11869
Train Staves		|complete weaponskill("TH_STAFF") > 0		|goto Thunder Bluff 40.93,62.73		|only if Warrior or Hunter
Train Two-Handed Maces	|complete weaponskill("TH_MACE") > 0		|goto Thunder Bluff 40.93,62.73		|only if Druid
|only if Warrior or Hunter or Druid
step
_NOTE:_
Use Weapon Stones
|tip We will train Mining and Blacksmithing.
|tip Allows you to make and use {o}Sharpening Stones{}.
|tip Increases damage.
|tip Mine {o}Copper Ore{} as you see it.
|tip Use the {g}Rough Stones{} to make sharpening stones.
Click Here to Continue |confirm |q 744
|only if Warrior
step
talk Karn Stonehoof##2998
Train Apprentice Blacksmithing |skillmax Blacksmithing,75 |goto Thunder Bluff/0 39.38,55.09
|only if Warrior
step
talk Brek Stonehoof##3001
|tip Inside the building.
Train Apprentice Mining |skillmax Mining,75 |goto Thunder Bluff/0 34.37,57.90
|only if Warrior
step
talk Kurm Stonehoof##3002
|tip Inside the building.
buy Mining Pick##2901 |goto Thunder Bluff/0 34.35,56.56
|only if Warrior
step
talk Jahan Hawkwing##3483
turnin Return to Jahan##6364 |goto The Barrens 51.21,29.05
|only if Tauren and not (Warrior or Shaman)
step
talk Doras##3310
|tip Top of the tower.
fpath Orgrimmar |goto Orgrimmar 45.13,63.90
|only if not (Warrior or Shaman)
step
talk Hanashi##2704
|tip Inside the building.
Train Bows |complete weaponskill("BOW") > 0 |goto Orgrimmar/0 81.53,19.63
|only if Hunter
step
|next "Leveling Guides\\Starter Guides (1-12)\\Mulgore (10-13)"			|only if Warrior or Shaman
|next "Leveling Guides\\Starter Guides (1-12)\\Eversong Woods (10-12)"		|only if not (Warrior or Shaman)
]])
ZygorGuidesViewer:RegisterGuide("Leveling Guides\\Starter Guides (1-12)\\Mulgore (10-13)",{
image=ZGV.IMAGESDIR.."Mulgore",
condition_visible=function() return Tauren and (Warrior or Shaman) end,
linked = {"Leveling Guides\\Hidden Guides"},
linkedhidden = true,
next="Leveling Guides\\Classic (12-60)\\The Barrens & Stonetalon Mountain (13-21)",
},[[
step
_NOTE:_
Wrong Character Race or Class
|tip Guide written for {o}Tauren Warrior or Shaman{} characters.
|tip Other races or classes may encounter issues.
Click Here to Continue |confirm
|only if not (Tauren and (Warrior or Shaman)
stickystart "Collect_Bronze_Feathers"
stickystart "Collect_Flatland_Prowler_Claws"
stickystart "Accept_The_Demon_Scarred_Cloak"
step
Ride an elevator down to leave Thunder Bluff |goto Thunder Bluff/0 51.20,31.51 < 20 |only if walking and zone("Thunder Bluff")
kill Windfury Sorceress##2964+
|tip Blue harpies.
collect 6 Azure Feather##4752 |q 744/1 |goto Mulgore 36.80,11.00
|mapmarker Mulgore/0 28.40,21.40
|mapmarker Mulgore/0 29.20,25.40
|mapmarker Mulgore/0 30.40,20.40
|mapmarker Mulgore/0 30.40,22.80
|mapmarker Mulgore/0 31.20,25.60
|mapmarker Mulgore/0 31.20,28.40
|mapmarker Mulgore/0 35.00,13.60
|mapmarker Mulgore/0 37.80,8.20
|mapmarker Mulgore/0 38.20,6.00
|mapmarker Mulgore/0 40.20,7.20
step
label "Collect_Bronze_Feathers"
kill Windfury Matriarch##2965+
|tip White harpies.
collect 6 Bronze Feather##4753 |q 744/2 |goto Mulgore 36.80,11.00
|mapmarker Mulgore/0 28.40,21.40
|mapmarker Mulgore/0 29.20,25.40
|mapmarker Mulgore/0 30.40,20.40
|mapmarker Mulgore/0 30.40,22.80
|mapmarker Mulgore/0 31.20,25.60
|mapmarker Mulgore/0 31.20,28.40
|mapmarker Mulgore/0 35.00,13.60
|mapmarker Mulgore/0 37.80,8.20
|mapmarker Mulgore/0 38.20,6.00
|mapmarker Mulgore/0 40.20,7.20
step
use Wildmane Cleansing Totem##5416
Cleanse the Wildmane Well |q 760/1 |goto Mulgore 42.77,14.21
|only if Tauren
step
map Mulgore
path	follow smart;	loop on;	ants curved;	dist 40
path	49.15,18.59	49.34,19.98	49.74,21.77	49.95,22.75	50.59,24.71
path	51.10,26.03	51.43,26.30	52.10,28.15	52.35,30.13	52.17,30.72
path	52.12,31.43	52.85,32.09	53.36,32.25	54.42,32.28	54.75,32.09
path	54.98,31.78	55.18,31.05	55.24,28.87	55.11,26.88	54.72,24.96
path	54.16,23.56	53.93,22.62	54.06,21.44	54.47,19.73	54.39,18.65
path	54.08,17.21	53.56,15.74	53.14,14.98	52.68,12.71	51.82,11.83
path	50.99,12.41	50.00,14.08	49.23,15.46
kill Arra'chea##3058
|tip Dark grey kodo.
|tip Walks a large clockwise pattern.
collect Horn of Arra'chea##4841 |q 776/1
Spawns near [Mulgore/0 49.20,18.73] |noway
step
label "Collect_Flatland_Prowler_Claws"
kill Flatland Prowler##3566+
|tip Cougars.
collect 4 Flatland Prowler Claw##5203 |q 861/1 |goto Mulgore 46.80,15.80
|mapmarker Mulgore/0 35.20,15.40
|mapmarker Mulgore/0 36.40,11.00
|mapmarker Mulgore/0 37.40,17.80
|mapmarker Mulgore/0 38.40,14.20
|mapmarker Mulgore/0 38.60,8.80
|mapmarker Mulgore/0 40.20,11.60
|mapmarker Mulgore/0 40.40,17.40
|mapmarker Mulgore/0 41.60,8.00
|mapmarker Mulgore/0 42.40,19.80
|mapmarker Mulgore/0 43.20,15.40
|mapmarker Mulgore/0 43.20,30.40
|mapmarker Mulgore/0 43.80,33.80
|mapmarker Mulgore/0 44.20,10.40
|mapmarker Mulgore/0 44.40,26.40
|mapmarker Mulgore/0 45.60,19.00
|mapmarker Mulgore/0 46.20,29.00
|mapmarker Mulgore/0 46.40,12.80
|mapmarker Mulgore/0 47.20,8.80
|mapmarker Mulgore/0 47.40,25.20
|mapmarker Mulgore/0 48.20,20.80
|mapmarker Mulgore/0 48.40,31.80
|mapmarker Mulgore/0 49.40,14.20
|mapmarker Mulgore/0 49.60,11.20
|mapmarker Mulgore/0 50.20,26.80
|mapmarker Mulgore/0 50.40,35.00
|mapmarker Mulgore/0 50.60,7.40
|mapmarker Mulgore/0 50.80,19.20
|mapmarker Mulgore/0 50.80,22.40
|mapmarker Mulgore/0 51.40,30.20
|mapmarker Mulgore/0 52.40,12.80
|mapmarker Mulgore/0 52.40,16.60
|mapmarker Mulgore/0 53.20,33.20
|mapmarker Mulgore/0 53.40,27.20
|mapmarker Mulgore/0 53.60,8.40
|mapmarker Mulgore/0 54.00,20.40
|mapmarker Mulgore/0 54.00,24.20
|mapmarker Mulgore/0 54.80,30.60
|mapmarker Mulgore/0 55.20,35.60
|mapmarker Mulgore/0 55.40,17.40
|mapmarker Mulgore/0 56.40,26.40
|mapmarker Mulgore/0 57.40,22.00
|mapmarker Mulgore/0 57.60,33.20
|mapmarker Mulgore/0 58.40,29.00
|mapmarker Mulgore/0 58.60,18.80
|mapmarker Mulgore/0 59.80,25.00
|mapmarker Mulgore/0 61.00,21.00
step
Kill enemies
|tip Helps reach level 12 after quest turnins.
ding 11,5730 |goto Mulgore 46.80,15.80
|mapmarker Mulgore/0 35.20,15.40
|mapmarker Mulgore/0 36.40,11.00
|mapmarker Mulgore/0 37.40,17.80
|mapmarker Mulgore/0 38.40,14.20
|mapmarker Mulgore/0 38.60,8.80
|mapmarker Mulgore/0 40.20,11.60
|mapmarker Mulgore/0 40.40,17.40
|mapmarker Mulgore/0 41.60,8.00
|mapmarker Mulgore/0 42.40,19.80
|mapmarker Mulgore/0 43.20,15.40
|mapmarker Mulgore/0 43.20,30.40
|mapmarker Mulgore/0 43.80,33.80
|mapmarker Mulgore/0 44.20,10.40
|mapmarker Mulgore/0 44.40,26.40
|mapmarker Mulgore/0 45.60,19.00
|mapmarker Mulgore/0 46.20,29.00
|mapmarker Mulgore/0 46.40,12.80
|mapmarker Mulgore/0 47.20,8.80
|mapmarker Mulgore/0 47.40,25.20
|mapmarker Mulgore/0 48.20,20.80
|mapmarker Mulgore/0 48.40,31.80
|mapmarker Mulgore/0 49.40,14.20
|mapmarker Mulgore/0 49.60,11.20
|mapmarker Mulgore/0 50.20,26.80
|mapmarker Mulgore/0 50.40,35.00
|mapmarker Mulgore/0 50.60,7.40
|mapmarker Mulgore/0 50.80,19.20
|mapmarker Mulgore/0 50.80,22.40
|mapmarker Mulgore/0 51.40,30.20
|mapmarker Mulgore/0 52.40,12.80
|mapmarker Mulgore/0 52.40,16.60
|mapmarker Mulgore/0 53.20,33.20
|mapmarker Mulgore/0 53.40,27.20
|mapmarker Mulgore/0 53.60,8.40
|mapmarker Mulgore/0 54.00,20.40
|mapmarker Mulgore/0 54.00,24.20
|mapmarker Mulgore/0 54.80,30.60
|mapmarker Mulgore/0 55.20,35.60
|mapmarker Mulgore/0 55.40,17.40
|mapmarker Mulgore/0 56.40,26.40
|mapmarker Mulgore/0 57.40,22.00
|mapmarker Mulgore/0 57.60,33.20
|mapmarker Mulgore/0 58.40,29.00
|mapmarker Mulgore/0 58.60,18.80
|mapmarker Mulgore/0 59.80,25.00
|mapmarker Mulgore/0 61.00,21.00
step
label "Accept_The_Demon_Scarred_Cloak"
use Demon Scarred Cloak##4854
accept The Demon Scarred Cloak##770
|only if itemcount(4854) > 0
step
Ride an elevator up into Thunder Bluff |goto Thunder Bluff 57.28,24.99 < 20 |only if walking
talk Cairne Bloodhoof##3057
|tip Inside the building.
turnin Rites of the Earthmother##776 |goto Thunder Bluff 60.29,51.68
step
talk Eyahn Eagletalon##2987
|tip Walks around.
turnin Preparation for Ceremony##744 |goto Thunder Bluff 37.67,59.60
step
talk Melor Stonehoof##3441
turnin The Hunter's Way##861 |goto Thunder Bluff 61.53,80.89
accept Sergra Darkthorn##860 |goto Thunder Bluff 61.53,80.89
step
talk Skorn Whitecloud##3052
turnin The Demon Scarred Cloak##770 |goto Mulgore/0 46.76,60.23
|only if haveq(770) or completedq(770)
step
talk Baine Bloodhoof##2993
turnin Dwarven Digging##746 |goto Mulgore 47.51,60.17
step
_Destroy These Items:_
|tip Not needed.
trash Prospector's Pick##4702
step
talk Mull Thunderhorn##2948
turnin Wildmane Cleansing##760 |goto Mulgore 48.53,60.39
|only if Tauren
step
talk Krang Stonehoof##3063
Train Abilities |trainer Krang Stonehoof##3063 |goto Mulgore/0 49.52,60.59 |q 765
|only if Warrior
step
talk Narm Skychaser##3066
|tip Inside the building.
Train Abilities |trainer Narm Skychaser##3066 |goto Mulgore/0 48.38,59.15 |q 765
|only if Shaman
stickystart "Kill_Venture_Co_Supervisors_And_Venture_Co_Workers"
step
Follow the path up and enter the mine |goto Mulgore 61.56,46.90 < 15 |walk |only if not (subzone("The Venture Co. Mine") and indoors())
kill Supervisor Fizsprocket##3051
|tip Inside the mine.
collect Fizsprocket's Clipboard##4819 |q 765/1 |goto Mulgore 64.90,43.31
step
label "Kill_Venture_Co_Supervisors_And_Venture_Co_Workers"
kill 6 Venture Co. Supervisor##2979 |q 764/2 |goto Mulgore 61.56,46.90
kill 14 Venture Co. Worker##2978 |q 764/1 |goto Mulgore 61.56,46.90
|tip Inside and outside the mine. |notinsticky
|mapmarker Mulgore/0 59.40,47.40
|mapmarker Mulgore/0 60.20,42.80
|mapmarker Mulgore/0 60.40,49.60
|mapmarker Mulgore/0 62.20,42.00
|mapmarker Mulgore/0 62.40,44.00
|mapmarker Mulgore/0 62.80,40.00
|mapmarker Mulgore/0 64.20,42.40
|mapmarker Mulgore/0 64.80,44.60
step
Leave the mine |goto 61.56,46.90 < 15 |c |q 765
|only if subzone("The Venture Co. Mine") and indoors()
step
map Mulgore
path	follow strictbounce;	loop off;	ants curved;	dist 30;	markers none
path	51.94,59.61	53.08,60.28	54.83,60.54	56.19,61.05	57.37,61.24
path	59.72,62.45
talk Morin Cloudstalker##2988
|tip Walks along the road.
turnin The Venture Co.##764
turnin Supervisor Fizsprocket##765
step
talk Sergra Darkthorn##3338
turnin Sergra Darkthorn##860 |goto The Barrens 52.23,31.01
step
talk Jahan Hawkwing##3483
turnin Return to Jahan##6364 |goto The Barrens 51.21,29.05
|only if Tauren
step
click Chen's Empty Keg
|tip Skip if not here.
|tip Can try again later.
collect Chen's Empty Keg##4926 |n
use Chen's Empty Keg##4926
accept Chen's Empty Keg##819 |goto The Barrens 55.78,20.01
step
talk Uzzek##5810
turnin Veteran Uzzek##1505 |goto The Barrens 61.38,21.11
accept Path of Defense##1498 |goto The Barrens 61.38,21.11
|only if Tauren Warrior
step
talk Kranal Fiss##5907
|tip Walks around.
turnin Call of Fire##2984 |goto The Barrens 56.03,19.89
accept Call of Fire##1524 |goto The Barrens 56.03,19.89
|only if Tauren Shaman
step
Follow the path up |goto Durotar 36.59,57.07 < 15 |only if walking
talk Telf Joolam##5900
|tip On top of the mountain.
turnin Call of Fire##1524 |goto Durotar 38.55,58.96
accept Call of Fire##1525 |goto Durotar 38.55,58.96
|only if Tauren Shaman
step
kill Razormane Thornweaver##3268, Razormane Water Seeker##3267
|tip Thornweavers and Water Seekers.
collect Fire Tar##5026 |q 1525/1 |goto The Barrens 55.60,25.40
|mapmarker The Barrens/0 53.00,25.20
|mapmarker The Barrens/0 54.40,27.20
|only if Tauren Shaman
step
talk Takrin Pathseeker##3336
accept Conscript of the Horde##840 |goto Durotar 50.85,43.59
step
Follow the path up |goto 54.54,38.79 < 40 |only if walking and not (subzone("Dustwind Cave") and indoors())
kill Burning Blade Cultist##3199+
|tip Inside the cave.
|tip In the back.
collect Reagent Pouch##6652 |q 1525/2 |goto Durotar/0 52.80,28.60
|mapmarker Durotar/0 51.80,25.80
|only if Tauren Shaman
step
Leave the cave |goto Durotar 52.83,28.93 < 15 |walk |only if subzone("Dustwind Cave") and indoors()
talk Rezlak##3293
accept Winds in the Desert##834 |goto Durotar 46.37,22.94
step
click Stolen Supply Sack+
|tip Tan bags.
collect 5 Sack of Supplies##4918 |q 834/1 |goto Durotar 49.10,22.50
|mapmarker Durotar/0 47.20,29.70
|mapmarker Durotar/0 47.20,30.80
|mapmarker Durotar/0 47.30,33.50
|mapmarker Durotar/0 49.70,24.30
|mapmarker Durotar/0 49.70,32.20
|mapmarker Durotar/0 50.10,25.70
step
talk Rezlak##3293
turnin Winds in the Desert##834 |goto Durotar 46.37,22.94
accept Securing the Lines##835 |goto Durotar 46.37,22.94
step
Follow the path and walk through the tunnel |goto Durotar 51.95,27.44 < 15 |only if walking and not subzone("Drygulch Ravine")
kill 8 Dustwind Storm Witch##3118 |q 835/2 |goto Durotar 53.20,24.60
kill 12 Dustwind Savage##3117 |q 835/1 |goto Durotar 53.20,24.60
|mapmarker Durotar/0 51.20,19.20
|mapmarker Durotar/0 51.40,21.00
|mapmarker Durotar/0 51.40,23.40
|mapmarker Durotar/0 52.60,21.40
|mapmarker Durotar/0 54.00,22.40
step
Allow Enemies to Kill You
|tip Fast travel.
Die on Purpose |complete isdead |goto Durotar 53.20,24.60 |q 835
|mapmarker Durotar/0 51.20,19.20
|mapmarker Durotar/0 51.40,21.00
|mapmarker Durotar/0 51.40,23.40
|mapmarker Durotar/0 52.60,21.40
|mapmarker Durotar/0 54.00,22.40
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Durotar 47.05,17.59 |q 835 |zombiewalk
step
talk Doras##3310
|tip Top of the tower.
fpath Orgrimmar |goto Orgrimmar 45.13,63.90
step
talk Rezlak##3293
turnin Securing the Lines##835 |goto Durotar 46.37,22.94
step
kill Thunder Lizard##3130+
collect 5 Singed Scale##6486 |q 1498/1 |goto Durotar 40.00,24.20
|mapmarker Durotar/0 39.00,26.40
|mapmarker Durotar/0 40.40,29.00
|only if Tauren Warrior
step
talk Uzzek##5810
turnin Path of Defense##1498 |goto The Barrens 61.38,21.11
accept Thun'grim Firegaze##1502 |goto The Barrens 61.38,21.12
|only if Tauren Warrior
step
Follow the path up |goto Durotar 36.59,57.07 < 15 |only if walking
talk Telf Joolam##5900
|tip Top of the mountain.
turnin Call of Fire##1525 |goto Durotar 38.55,58.96
accept Call of Fire##1526 |goto Durotar 38.55,58.96
|only if Tauren Shaman
step
use Fire Sapta##6636
|tip Top of the mountain.
Gain Sapta Sight |havebuff Sapta Sight##8898 |goto Durotar 38.16,58.54 |q 1526
|only if Tauren Shaman
step
kill Minor Manifestation of Fire##5893
|tip Top of the mountain.
collect Glowing Ember##6655 |q 1526/1 |goto Durotar 38.72,58.29
|only if Tauren Shaman
step
click Brazier of the Dormant Flame
|tip Top of the mountain.
turnin Call of Fire##1526 |goto Durotar 38.95,58.22
accept Call of Fire##1527 |goto Durotar 38.95,58.22
|only if Tauren Shaman
step
talk Kargal Battlescar##3337
turnin Conscript of the Horde##840 |goto The Barrens 62.26,19.38
accept Crossroads Conscription##842 |goto The Barrens 62.26,19.38
]])
ZygorGuidesViewer:RegisterGuide("Leveling Guides\\Starter Guides (1-12)\\Orc & Troll Starter (1-6)",{
image=ZGV.IMAGESDIR.."Durotar",
condition_suggested=function() return (raceclass('Orc') or raceclass('Troll')) and level <= 12 end,
condition_suggested_exclusive=true,
condition_visible=function() return (Orc or Troll) end,
linked = {"Leveling Guides\\Hidden Guides"},
linkedhidden = true,
next="Leveling Guides\\Starter Guides (1-12)\\Durotar (6-10)",
},[[
defaultfor Orc,Troll
step
_NOTE:_
Wrong Character Race
|tip Guide written for {o}Orc & Troll{} characters.
|tip Other races may encounter issues.
Click Here to Continue |confirm
|only if not (Orc or Troll)
step
_NOTE:_
Manage Your Ammo
|tip Make sure you always have ammo.
|tip You need it to attack enemies.
|tip {o}General Goods{} vendors sell it (also Bow & Gun vendors).
|tip Try to keep your ammo bag full.
Click Here to Continue |confirm |q 4641 |future
|only if Hunter
step
talk Kaltunk##10176
accept Your Place In The World##4641 |goto Durotar/0 43.29,68.53
step
kill Mottled Boar##3098+
|tip Loot items worth at least {o}10 copper{} to sell.
|tip Allows training a spell early.
|tip Increases leveling speed.
Click to Continue |confirm |goto Durotar/0 43.80,70.40 |q 4641
|mapmarker Durotar/0 43.40,72.40
|mapmarker Durotar/0 41.40,71.60
|only if Warrior or Warlock or Shaman
step
talk Duokna##3158
Sell Items |vendor Duokna##3158 |goto Durotar/0 42.58,67.34 |q 4641
|only if Warrior or Warlock or Shaman
step
talk Frang##3153
Train Abilities |trainer Frang##3153 |goto Durotar 42.89,69.43 |q 4641
|only if Warrior
step
talk Shikrik##3157
Train Abilities |trainer Shikrik##3157 |goto Durotar 42.39,69.00 |q 4641
|only if Shaman
step
talk Ruzan##5765
accept Vile Familiars##1485 |goto Durotar 42.59,69.00
|only if Warlock
step
talk Gornek##3143
|tip Inside the cave.
turnin Your Place In The World##4641 |goto Durotar 42.06,68.33
accept Cutting Teeth##788 |goto Durotar 42.06,68.33
step
talk Nartok##3156
|tip Inside the cave.
Train Abilities |trainer Nartok##3156 |goto Durotar 40.65,68.51 |q 788
|only if Warlock
step
kill 10 Mottled Boar##3098 |q 788/1 |goto Durotar 43.80,66.20
|mapmarker Durotar/0 41.00,64.20
|mapmarker Durotar/0 42.20,61.00
|mapmarker Durotar/0 44.40,63.20
|mapmarker Durotar/0 46.40,68.20
|mapmarker Durotar/0 47.00,64.80
step
Kill enemies
ding 2 |goto Durotar 44.40,63.20
|mapmarker Durotar/0 41.00,64.20
|mapmarker Durotar/0 42.20,61.00
|mapmarker Durotar/0 43.80,66.20
|mapmarker Durotar/0 46.40,68.20
|mapmarker Durotar/0 47.00,64.80
step
label "Collect_Vile_Familiar_Heads"
kill Vile Familiar##3101+
|tip Avoid going inside the cave, if possible.
|tip Next step outside the cave.
collect 6 Vile Familiar Head##6487 |q 1485/1 |goto Durotar 45.80,57.40
|mapmarker Durotar/0 43.80,58.40
|only if Orc Warlock
step
talk Hana'zua##3287
accept Sarkoth##790 |goto Durotar 40.60,62.59
step
kill Sarkoth##3281
|tip Black scorpion.
|tip Walks around.
collect Sarkoth's Mangled Claw##4905 |q 790/1 |goto Durotar 40.60,65.40
|mapmarker Durotar/0 40.60,67.60
step
talk Hana'zua##3287
turnin Sarkoth##790 |goto Durotar 40.60,62.59
accept Sarkoth##804 |goto Durotar 40.60,62.59
step
talk Ruzan##5765
turnin Vile Familiars##1485 |goto Durotar 42.59,69.00
accept Vile Familiars##1499 |goto Durotar 42.59,69.00
|only if Orc Warlock
step
Summon Your Imp |complete warlockpet("Imp")
|tip Cast {o}Summon Imp{}.
|only if Orc Warlock
step
talk Zureetha Fargaze##3145
turnin Vile Familiars##1499 |goto Durotar 42.85,69.15
|only if Orc Warlock
step
talk Gornek##3143
|tip Inside the cave.
turnin Cutting Teeth##788		|goto Durotar 42.06,68.33
turnin Sarkoth##804			|goto Durotar 42.06,68.33
accept Simple Parchment##2383		|goto Durotar 42.06,68.33	|only Orc Warrior
accept Rune-Inscribed Parchment##3089	|goto Durotar 42.06,68.33	|only Orc Shaman
accept Encrypted Parchment##3088	|goto Durotar 42.06,68.33	|only Orc Rogue
accept Etched Parchment##3087		|goto Durotar 42.06,68.33	|only Orc Hunter
accept Tainted Parchment##3090		|goto Durotar 42.06,68.33	|only Orc Warlock
accept Simple Tablet##3065		|goto Durotar 42.06,68.33	|only Troll Warrior
accept Etched Tablet##3082		|goto Durotar 42.06,68.33	|only Troll Hunter
accept Encrypted Tablet##3083		|goto Durotar 42.06,68.33	|only Troll Rogue
accept Hallowed Tablet##3085		|goto Durotar 42.06,68.33	|only Troll Priest
accept Rune-Inscribed Tablet##3084	|goto Durotar 42.06,68.33	|only Troll Shaman
accept Glyphic Tablet##3086		|goto Durotar 42.06,68.33	|only Troll Mage
accept Sting of the Scorpid##789	|goto Durotar 42.06,68.33
step
talk Rwag##3155
|tip Inside the cave.
turnin Encrypted Parchment##3088 |goto Durotar 41.28,68.00	|only if Orc Rogue
turnin Encrypted Tablet##3083 |goto Durotar 41.28,68.00		|only if Troll Rogue
|only if Rogue
step
talk Rwag##3155
|tip Inside the cave.
Train Abilities |trainer Rwag##3155 |goto Durotar 41.28,68.00 |q 5441 |future
|only if Rogue
step
talk Nartok##3156
|tip Inside the cave.
turnin Tainted Parchment##3090 |goto Durotar 40.65,68.51
|only if Orc Warlock
step
talk Galgar##9796
accept Galgar's Cactus Apple Surprise##4402 |goto Durotar 42.73,67.24
step
talk Ken'jai##3707
turnin Hallowed Tablet##3085 |goto Durotar 42.36,68.82
|only if Troll Priest
step
talk Ken'jai##3707
Train Abilities |trainer Ken'jai##3707 |goto Durotar 42.36,68.82 |q 5441 |future
|only if Priest
step
talk Shikrik##3157
turnin Rune-Inscribed Parchment##3089 |goto Durotar 42.39,69.00		|only if Orc Shaman
turnin Rune-Inscribed Tablet##3084 |goto Durotar 42.39,69.00		|only if Troll Shaman
|only if Shaman
step
talk Mai'ah##5884
turnin Glyphic Tablet##3086 |goto Durotar 42.51,69.04
|only if Troll Mage
step
talk Mai'ah##5884
Train Abilities |trainer Mai'ah##5884 |goto Durotar 42.51,69.04 |q 5441 |future
|only if Mage
step
talk Zureetha Fargaze##3145
accept Vile Familiars##792 |goto Durotar 42.85,69.14
|only if not Warlock
step
talk Frang##3153
turnin Simple Parchment##2383 |goto Durotar 42.89,69.43		|only if Orc Warrior
turnin Simple Tablet##3065 |goto Durotar 42.89,69.43		|only if Troll Warrior
|only if Warrior
step
talk Jen'shan##3154
turnin Etched Parchment##3087 |goto Durotar 42.84,69.32		|only if Orc Hunter
turnin Etched Tablet##3082 |goto Durotar 42.84,69.32		|only if Troll Hunter
|only if Hunter
step
talk Jen'shan##3154
Train Abilities |trainer Jen'shan##3154 |goto Durotar 42.84,69.32 |q 5441 |future
|only if Hunter
step
talk Foreman Thazz'ril##11378
accept Lazy Peons##5441 |goto Durotar 44.62,68.64
stickystart "Collect_Scorpid_Worker_Tails"
stickystart "Awaken_Lazy_Peons"
stickystart "Collect_Cactus_Apples"
step
kill 12 Vile Familiar##3101 |q 792/1 |goto Durotar 45.80,57.40
|tip Avoid going inside the cave, if possible.
|tip Next step outside the cave.
|mapmarker Durotar/0 43.80,58.40
|only if not Warlock
step
label "Collect_Scorpid_Worker_Tails"
kill Scorpid Worker##3124+
|tip Scorpions.
collect 10 Scorpid Worker Tail##4862 |q 789/1 |goto Durotar 41.40,59.00
|mapmarker Durotar/0 39.40,61.40
|mapmarker Durotar/0 43.20,56.40
|mapmarker Durotar/0 45.20,59.40
|mapmarker Durotar/0 46.40,64.20
step
Kill enemies
ding 4 |goto Durotar 41.40,59.00
|mapmarker Durotar/0 39.40,61.40
|mapmarker Durotar/0 43.20,56.40
|mapmarker Durotar/0 45.20,59.40
|mapmarker Durotar/0 46.40,64.20
step
label "Awaken_Lazy_Peons"
use Foreman's Blackjack##16114
|tip On Lazy Peons.
|tip Sleeping orcs.
|tip Near trees.
|tip If not sleeping, skip them.
Awaken #5# Lazy Peons |q 5441/1 |goto Durotar 46.60,60.40
|mapmarker Durotar/0 39.00,61.80
|mapmarker Durotar/0 40.80,60.60
|mapmarker Durotar/0 41.40,72.60
|mapmarker Durotar/0 43.80,57.40
|mapmarker Durotar/0 44.40,72.80
|mapmarker Durotar/0 44.80,69.00
|mapmarker Durotar/0 45.40,65.80
|mapmarker Durotar/0 47.00,58.00
|mapmarker Durotar/0 47.20,65.40
|mapmarker Durotar/0 47.40,69.20
step
label "Collect_Cactus_Apples"
click Cactus Apple+
|tip Cactuses with red fruit.
collect 10 Cactus Apple##11583 |q 4402/1 |goto Durotar 45.70,64.40
|mapmarker Durotar/0 39.70,63.00
|mapmarker Durotar/0 40.50,60.40
|mapmarker Durotar/0 41.60,58.70
|mapmarker Durotar/0 41.90,63.30
|mapmarker Durotar/0 42.00,56.60
|mapmarker Durotar/0 43.40,62.80
|mapmarker Durotar/0 44.10,67.00
|mapmarker Durotar/0 44.60,58.20
|mapmarker Durotar/0 44.60,64.80
|mapmarker Durotar/0 44.80,61.70
|mapmarker Durotar/0 44.90,59.60
|mapmarker Durotar/0 47.30,65.20
step
talk Galgar##9796
turnin Galgar's Cactus Apple Surprise##4402 |goto Durotar 42.73,67.24
step
talk Gornek##3143
|tip Inside the cave.
turnin Sting of the Scorpid##789 |goto Durotar 42.05,68.32
step
talk Nartok##3156
|tip Inside the cave.
Train Abilities |trainer Nartok##3156 |goto Durotar 40.65,68.51 |q 792
|only if Warlock
step
talk Hraug##12776
|tip Buy available Grimoires.
|tip Inside the cave.
Train Demon Abilities |vendor Hraug##12776 |goto Durotar 40.56,68.43 |q 792
|only if Warlock
step
talk Rwag##3155
|tip Inside the cave.
Train Abilities |trainer Rwag##3155 |goto Durotar/0 41.28,68.00 |q 792
|only if Rogue
step
talk Ken'jai##3707
Train Abilities |trainer Ken'jai##3707 |goto Durotar/0 42.36,68.81 |q 792
|only if Priest
step
talk Mai'ah##5884
Train Abilities |trainer Mai'ah##5884 |goto Durotar 42.51,69.04 |q 792
|only if Mage
step
talk Shikrik##3157
Train Abilities |trainer Shikrik##3157 |goto Durotar 42.39,69.00 |q 792
|only if Shaman
step
talk Canaga Earthcaller##5887
accept Call of Earth##1516 |goto Durotar 42.41,69.17
|only if Shaman
step
talk Zureetha Fargaze##3145
turnin Vile Familiars##792 |goto Durotar 42.85,69.15 |only if not Warlock
accept Burning Blade Medallion##794 |goto Durotar 42.85,69.15
step
talk Frang##3153
Train Abilities |trainer Frang##3153 |goto Durotar 42.89,69.43 |q 5441
|only if Warrior
step
talk Jen'shan##3154
Train Abilities |trainer Jen'shan##3154 |goto Durotar/0 42.84,69.33 |q 5441
|only if Hunter
step
talk Foreman Thazz'ril##11378
turnin Lazy Peons##5441 |goto Durotar 44.62,68.64
accept Thazz'ril's Pick##6394 |goto Durotar 44.62,68.64
stickystart "Collect_Felstalker_Hoofs_Shaman"
step
Enter the cave |goto Durotar 45.34,56.36 < 15 |walk |only if not (subzone("Burning Blade Coven") and indoors())
click Thazz'ril's Pick
|tip Inside the cave.
collect Thazz'ril's Pick##16332 |q 6394/1 |goto Durotar 43.73,53.79
step
Follow the path |goto Durotar 44.76,54.54 < 10 |walk
kill Yarrog Baneshadow##3183
|tip Inside the cave.
collect Burning Blade Medallion##4859 |q 794/1 |goto Durotar 42.71,52.95
step
label "Collect_Felstalker_Hoofs_Shaman"
kill Felstalker##3102+
|tip Demon dogs.
|tip Inside the cave. |notinsticky
collect 2 Felstalker Hoof##6640 |q 1516/1 |goto Durotar 45.34,56.36
|mapmarker Durotar/0 42.40,53.40
|mapmarker Durotar/0 43.20,55.40
|mapmarker Durotar/0 44.80,52.40
|only if Shaman
step
Kill enemies
|tip Helps reach level 6 after quest turnins.
|tip Inside the cave.
ding 5,1405 |goto Durotar 45.34,56.36	|only if Shaman
ding 5,1675 |goto Durotar 45.34,56.36	|only if not Shaman
|mapmarker Durotar/0 42.40,53.40
|mapmarker Durotar/0 43.20,55.40
|mapmarker Durotar/0 44.80,52.40
step
use Hearthstone##6948
Hearth to Valley of Trials |complete subzone("Valley of Trials") |q 6394
|only if subzone("Burning Blade Coven") and indoors()
step
talk Foreman Thazz'ril##11378
turnin Thazz'ril's Pick##6394 |goto Durotar 44.62,68.64
step
talk Zureetha Fargaze##3145
turnin Burning Blade Medallion##794 |goto Durotar 42.85,69.15
accept Report to Sen'jin Village##805 |goto Durotar 42.85,69.15
step
talk Ken'jai##3707
accept In Favor of Spirituality##5649 |goto Durotar 42.36,68.81
|only if Priest
step
talk Ken'jai##3707
Train Abilities |trainer Ken'jai##3707 |goto Durotar 42.36,68.81 |q 805
|only if Troll Priest
step
talk Canaga Earthcaller##5887
turnin Call of Earth##1516 |goto Durotar 42.41,69.17
accept Call of Earth##1517 |goto Durotar 42.41,69.17
|only if Shaman
step
talk Shikrik##3157
Train Abilities |trainer Shikrik##3157 |goto Durotar 42.39,69.00 |q 805
|only if Shaman
step
Follow the path up |goto Durotar 41.56,73.28 < 15 |only if walking
use Earth Sapta##6635
|tip Top of the mountain.
talk Minor Manifestation of Earth##5891
turnin Call of Earth##1517 |goto Durotar 44.03,76.20
accept Call of Earth##1518 |goto Durotar 44.03,76.20
|only if Shaman
step
talk Canaga Earthcaller##5887
turnin Call of Earth##1518 |goto Durotar 42.41,69.17
|only if Shaman
step
talk Mai'ah##5884
Train Abilities |trainer Mai'ah##5884 |goto Durotar 42.51,69.04 |q 805
|only if Mage
step
Enter the cave |goto Durotar/0 42.28,68.43 < 10 |walk |only if not (subzone("The Den") and indoors())
talk Nartok##3156
|tip Inside the cave.
Train Abilities |trainer Nartok##3156 |goto Durotar 40.65,68.51 |q 805
|only if Warlock
step
talk Hraug##12776
|tip Buy available Grimoires.
|tip Inside the cave.
Train Demon Abilities |vendor Hraug##12776 |goto Durotar 40.56,68.43 |q 805
|only if Warlock
step
Enter the cave |goto Durotar/0 42.28,68.43 < 10 |walk |only if not (subzone("The Den") and indoors())
talk Rwag##3155
|tip Inside the cave.
Train Abilities |trainer Rwag##3155 |goto |goto Durotar 41.28,68.00 |q 805
|only if Rogue
step
talk Frang##3153
Train Abilities |trainer Frang##3153 |goto Durotar 42.89,69.43 |q 805
|only if Warrior
step
talk Jen'shan##3154
Train Abilities |trainer Jen'shan##3154 |goto Durotar 42.84,69.32 |q 805
|only if Hunter
]])
ZygorGuidesViewer:RegisterGuide("Leveling Guides\\Starter Guides (1-12)\\Durotar (6-10)",{
image=ZGV.IMAGESDIR.."Durotar",
condition_visible=function() return Orc or Troll or (Undead and Warrior) end,
linked = {"Leveling Guides\\Hidden Guides"},
linkedhidden = true,
},[[
step
_NOTE:_
Wrong Character Race or Class
|tip Guide written for {o}Orc, Troll or Undead Warrior{} characters.
|tip Other races or classes may encounter issues.
Click Here to Continue |confirm
|only if not ((Orc or Troll) or Undead Warrior)
step
talk Ukor##6786
accept A Peon's Burden##2161 |goto Durotar 52.06,68.31
step
talk Lar Prowltusk##3140
|tip Walks around.
|tip Multiple locations.
accept Thwarting Kolkar Aggression##786 |goto Durotar 54.19,73.29
|mapmarker Durotar/0 54.00,76.20
|mapmarker Durotar/0 54.40,74.20
step
talk Vel'rin Fang##3194
|tip Inside the building.
accept Practical Prey##817 |goto Durotar 55.96,73.92
step
talk Master Vornal##3304
accept A Solvent Spirit##818 |goto Durotar 55.94,74.39
step
talk Master Gadrin##3188
turnin Report to Sen'jin Village##805 |goto Durotar 55.95,74.72 |only if haveq(805) or completedq(805)
accept Minshina's Skull##808 |goto Durotar 55.95,74.72
accept Zalazane##826 |goto Durotar 55.95,74.72
accept Report to Orgnil##823 |goto Durotar 55.95,74.72
stickystart "Collect_Crawler_Mucus_Sticky_Only"
step
kill Makrura Clacker##3103, Makrura Shellhide##3104
|tip Lobsters.
|tip Follow the beach southwest.
|tip Skip when you reach the end of the beach.
|tip Can finish later.
collect 4 Intact Makrura Eye##4887 |q 818/1 |goto Durotar 60.20,70.80
|mapmarker Durotar/0 52.20,83.00
|mapmarker Durotar/0 55.00,81.40
|mapmarker Durotar/0 56.40,78.40
|mapmarker Durotar/0 58.40,73.40
step
label "Collect_Crawler_Mucus_Sticky_Only"
kill Pygmy Surf Crawler##3106+
|tip Crabs.
collect 8 Crawler Mucus##4888 |q 818/2 |goto Durotar 60.20,70.80
|mapmarker Durotar/0 52.20,83.00
|mapmarker Durotar/0 55.00,81.40
|mapmarker Durotar/0 56.40,78.40
|mapmarker Durotar/0 58.40,73.40
|sticky only
step
Follow the path |goto Durotar 50.85,79.14 < 15 |only if walking and not subzone("Kolkar Crag")
click Attack Plan: Valley of Trials
|tip Inside the building.
Destroy the Attack Plan: Valley of Trials |q 786/1 |goto Durotar 49.82,81.28
step
click Attack Plan: Sen'jin Village
Destroy the Attack Plan: Sen'jin Village |q 786/2 |goto Durotar 47.66,77.34
step
click Attack Plan: Orgrimmar
|tip Follow the path around.
Destroy the Attack Plan: Orgrimmar |q 786/3 |goto Durotar 46.23,78.95
step
Stand in the Fire to Kill Yourself
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Durotar 46.41,79.20 |q 786
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Durotar 57.49,73.26 |q 786 |zombiewalk
step
talk Master Vornal##3304
turnin A Solvent Spirit##818 |goto Durotar 55.94,74.39
|only if readyq(818)
step
talk Lar Prowltusk##3140
|tip Walks around.
|tip Multiple locations.
turnin Thwarting Kolkar Aggression##786 |goto Durotar 54.19,73.29
|mapmarker Durotar/0 54.00,76.20
|mapmarker Durotar/0 54.40,74.20
step
talk Orgnil Soulscar##3142
turnin Report to Orgnil##823 |goto Durotar 52.25,43.15
accept Dark Storms##806 |goto Durotar 52.25,43.15 |only if Warrior or Shaman
step
talk Gar'Thok##3139
|tip Upstairs inside the building.
accept Vanquish the Betrayers##784 |goto Durotar 51.95,43.50
accept Encroachment##837 |goto Durotar 51.95,43.50
step
talk Cook Torka##3191
|tip Walks around.
accept Break a Few Eggs##815 |goto Durotar 51.11,42.45
step
Follow the path up |goto Durotar 50.09,43.01 < 10 |only if walking
talk Furl Scornbrow##3147
|tip Top of the tower.
accept Carry Your Weight##791 |goto Durotar 49.89,40.38
step
_NOTE:_
Use Weapon Stones
|tip We will train Mining and Blacksmithing.
|tip Allows you to make and use {o}Sharpening Stones{}.
|tip Increases damage.
|tip Mine {o}Copper Ore{} as you see it.
|tip Use the {g}Rough Stones{} to make sharpening stones.
Click Here to Continue |confirm |q 2161
|only if Warrior or Rogue
step
talk Krunn##3175
Train Apprentice Mining |skillmax Mining,75 |goto Durotar/0 51.82,40.89
|only if Warrior or Rogue
step
talk Dwukk##3174
Train Apprentice Blacksmithing |skillmax Blacksmithing,75 |goto Durotar/0 52.03,40.72
|only if Warrior or Rogue
step
talk Flakk##3168
buy Mining Pick##2901 |goto Durotar/0 52.98,41.97
|only if Warrior or Rogue
step
talk Innkeeper Grosk##6928
|tip Inside the building.
turnin A Peon's Burden##2161 |goto Durotar/0 51.52,41.65
step
talk Tai'jin##3706
|tip Inside the building.
turnin In Favor of Spirituality##5649 |goto Durotar 54.26,42.93
accept Garments of Spirituality##5648 |goto Durotar 54.26,42.93
|only if Priest
step
Heal and Fortify Grunt Kor'ja |q 5648/1 |goto Durotar 53.10,46.46
|tip Cast {o}Lesser Heal (Rank 2){} on Grunt Kor'ja.
|tip Cast {o}Power Word: Fortitude{} on Grunt Kor'ja.
|only if Priest
step
talk Tai'jin##3706
|tip Inside the building.
turnin Garments of Spirituality##5648 |goto Durotar 54.26,42.93
|only if Priest
stickystart "Collect_Canvas_Scraps"
stickystart "Kill_Kul_Tiras_Enemies"
step
Enter the building |goto Durotar 58.99,58.30 < 15 |walk |only if not (subzone("Tiragarde Keep") and indoors())
kill Lieutenant Benedict##3192 |q 784/3 |goto Durotar 59.71,58.27
|tip Upstairs inside the building.
|tip May need help.
collect Benedict's Key##4882 |goto Durotar 59.71,58.27 |q 830 |future
step
Follow the path and run further up the stairs |goto Durotar 59.90,57.87 < 7 |walk
click Benedict's Chest
|tip Top of the building.
collect Aged Envelope##4881 |goto Durotar 59.26,57.66 |q 830 |future
step
use Aged Envelope##4881
accept The Admiral's Orders##830
step
label "Collect_Canvas_Scraps"
kill Kul Tiras Sailor##3128, Kul Tiras Marine##3129
collect 8 Canvas Scraps##4870 |q 791/1 |goto Durotar 55.40,51.20
|mapmarker Durotar/0 55.80,53.40
|mapmarker Durotar/0 56.20,56.80
|mapmarker Durotar/0 57.60,52.40
|mapmarker Durotar/0 58.40,58.20
|mapmarker Durotar/0 58.60,55.20
step
label "Kill_Kul_Tiras_Enemies"
kill 8 Kul Tiras Marine##3129 |q 784/2 |goto Durotar 55.80,53.40
kill 10 Kul Tiras Sailor##3128 |q 784/1 |goto Durotar 55.80,53.40
|mapmarker Durotar/0 55.40,51.20
|mapmarker Durotar/0 56.20,56.80
|mapmarker Durotar/0 57.60,52.40
|mapmarker Durotar/0 58.40,58.20
|mapmarker Durotar/0 58.60,55.20
step
Kill enemies
|tip Helps reach level 8 after quest turnins.
ding 7,2625 |goto Durotar 55.80,53.40
|mapmarker Durotar/0 55.40,51.20
|mapmarker Durotar/0 56.20,56.80
|mapmarker Durotar/0 57.60,52.40
|mapmarker Durotar/0 58.40,58.20
|mapmarker Durotar/0 58.60,55.20
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Durotar 55.80,53.40 |q 830
|mapmarker Durotar/0 55.40,51.20
|mapmarker Durotar/0 56.20,56.80
|mapmarker Durotar/0 57.60,52.40
|mapmarker Durotar/0 58.40,58.20
|mapmarker Durotar/0 58.60,55.20
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Durotar 53.51,44.45 |q 830 |zombiewalk
step
talk Gar'Thok##3139
|tip Upstairs inside the building.
turnin Vanquish the Betrayers##784 |goto Durotar 51.95,43.50
accept From The Wreckage....##825 |goto Durotar 51.95,43.50
turnin The Admiral's Orders##830 |goto Durotar 51.95,43.50
accept The Admiral's Orders##831 |goto Durotar 51.95,43.50
step
Follow the path up |goto Durotar 50.09,43.01 < 10 |only if walking
talk Furl Scornbrow##3147
|tip Top of the tower.
turnin Carry Your Weight##791 |goto Durotar 49.89,40.38
step
talk Innkeeper Grosk##6928
|tip Inside the building.
home Razor Hill |goto Durotar/0 51.52,41.65 |q 837 |future
step
talk Kaplak##3170
|tip Upstairs inside the building.
Train Abilities |trainer Kaplak##3170 |goto Durotar/0 51.98,43.69 |q 825
|only if Rogue
step
talk Thotar##3171
|tip Inside the building.
Train Abilities |trainer Thotar##3171 |goto Durotar/0 51.85,43.49 |q 825
|only if Hunter
step
talk Dhugru Gorelust##3172
|tip Outside behind the building.
Train Abilities |trainer Dhugru Gorelust##3172 |goto Durotar/0 54.38,41.19 |q 825
|only if Warlock
step
talk Kitha##6027
|tip Buy available Grimoires.
|tip Outside behind the building.
Train Demon Abilities |vendor Kitha##6027 |goto Durotar/0 54.71,41.50 |q 825
|only if Warlock
step
talk Tai'jin##3706
|tip Inside the building.
Train Abilities |trainer Tai'jin##3706 |goto Durotar/0 54.26,42.93 |q 825
|only if Priest
step
talk Tarshaw Jaggedscar##3169
|tip Inside the building.
Train Abilities |trainer Tarshaw Jaggedscar##3169 |goto Durotar/0 54.19,42.47 |q 825
|only if Warrior
step
talk Swart##3173
|tip Inside the building.
Train Abilities |trainer Swart##3173 |goto Durotar/0 54.42,42.59 |q 825
|only if Shaman
step
talk Rawrk##5943
|tip Inside the building.
Train Apprentice First Aid |skillmax First Aid,75 |goto Durotar 54.17,41.93
|only if Warrior or Rogue
step
_NOTE:_
Create Bandages in Downtime
|tip While waiting for things like boats.
|tip Increases skill in First Aid.
|tip Need higher skill to make better bandages.
|tip Keep bandages to heal yourself.
Click Here to Continue |confirm |q 825
|only if Warrior or Rogue
stickystart "Collect_Crawler_Mucus"
stickystart "Collect_Intact_Makrura_Eyes"
step
click Gnomish Toolbox
|tip Grey metal chests.
|tip Inside the near sunken ships.
|tip Underwater.
collect 3 Gnomish Tools##4863 |q 825/1 |goto Durotar 61.40,56.20
|mapmarker Durotar/0 61.80,45.90
|mapmarker Durotar/0 62.10,41.80
|mapmarker Durotar/0 62.10,60.70
|mapmarker Durotar/0 63.80,53.00
|mapmarker Durotar/0 64.40,50.30
|mapmarker Durotar/0 63.30,57.40
stickystart "Collect_Taillasher_Eggs"
stickystart "Collect_Durotar_Tiger_Fur"
stickystart "Kill_Hexed_Trolls"
stickystart "Kill_Voodoo_Trolls"
step
kill Zalazane##3205
|tip Troll wearing a red robe.
|tip Walks around.
collect Zalazane's Head##4866 |q 826/3 |goto Durotar 67.40,86.40
|mapmarker Durotar/0 66.40,87.40
|mapmarker Durotar/0 67.60,87.80
stickystop "Collect_Crawler_Mucus"
stickystop "Collect_Intact_Makrura_Eyes"
step
click Imprisoned Darkspear
|tip Skulls.
collect Minshina's Skull##4864 |q 808/1 |goto Durotar 67.45,87.81
step
label "Kill_Hexed_Trolls"
kill 8 Hexed Troll##3207 |q 826/1 |goto Durotar 67.80,86.00
|mapmarker Durotar/0 65.40,83.40
|mapmarker Durotar/0 65.40,86.00
|mapmarker Durotar/0 66.40,88.60
|mapmarker Durotar/0 67.40,83.40
|mapmarker Durotar/0 68.20,81.40
step
label "Kill_Voodoo_Trolls"
kill 8 Voodoo Troll##3206 |q 826/2 |goto Durotar 67.20,87.00
|mapmarker Durotar/0 65.40,83.40
|mapmarker Durotar/0 65.40,86.00
|mapmarker Durotar/0 67.20,85.00
|mapmarker Durotar/0 67.80,82.20
step
label "Collect_Taillasher_Eggs"
click Taillasher Eggs+
|tip Clusters of purple eggs.
|tip Near trees.
collect 3 Taillasher Egg##4890 |q 815/1 |goto Durotar 63.90,86.80
|mapmarker Durotar/0 59.40,83.70
|mapmarker Durotar/0 59.80,89.60
|mapmarker Durotar/0 60.90,78.80
|mapmarker Durotar/0 62.10,96.30
|mapmarker Durotar/0 63.00,94.40
|mapmarker Durotar/0 63.40,74.40
|mapmarker Durotar/0 64.90,82.40
|mapmarker Durotar/0 67.20,80.60
|mapmarker Durotar/0 68.20,88.40
|mapmarker Durotar/0 68.70,74.40
|mapmarker Durotar/0 68.90,71.10
|mapmarker Durotar/0 69.20,82.20
step
label "Collect_Durotar_Tiger_Fur"
kill Durotar Tiger##3121+
collect 4 Durotar Tiger Fur##4892 |q 817/1 |goto Durotar 61.20,89.60
|mapmarker Durotar/0 60.20,82.40
|mapmarker Durotar/0 62.80,96.40
|mapmarker Durotar/0 64.60,81.20
|mapmarker Durotar/0 64.80,85.00
|mapmarker Durotar/0 67.00,71.40
|mapmarker Durotar/0 67.40,74.60
|mapmarker Durotar/0 68.40,80.40
|mapmarker Durotar/0 69.00,85.20
|mapmarker Durotar/0 69.60,69.80
|mapmarker Durotar/0 70.20,73.20
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
|tip Anywhere in Echo Isles.
Die on Purpose |complete isdead |goto Durotar 61.20,89.60 |q 817
|mapmarker Durotar/0 60.20,82.40
|mapmarker Durotar/0 62.80,96.40
|mapmarker Durotar/0 64.60,81.20
|mapmarker Durotar/0 64.80,85.00
|mapmarker Durotar/0 67.00,71.40
|mapmarker Durotar/0 67.40,74.60
|mapmarker Durotar/0 68.40,80.40
|mapmarker Durotar/0 69.00,85.20
|mapmarker Durotar/0 69.60,69.80
|mapmarker Durotar/0 70.20,73.20
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Durotar 57.50,73.26 |q 817 |zombiewalk
step
talk Un'Thuwa##5880
|tip Inside the building.
Train Abilities |trainer Un'Thuwa##5880 |goto Durotar/0 56.31,75.11
|only if Mage
stickystart "Collect_Crawler_Mucus"
step
label "Collect_Intact_Makrura_Eyes"
kill Makrura Clacker##3103, Makrura Shellhide##3104
|tip Lobsters.
collect 4 Intact Makrura Eye##4887 |q 818/1 |goto Durotar 60.20,70.80
|mapmarker Durotar/0 52.20,83.00
|mapmarker Durotar/0 55.00,81.40
|mapmarker Durotar/0 56.40,78.40
|mapmarker Durotar/0 58.40,73.40
step
label "Collect_Crawler_Mucus"
kill Pygmy Surf Crawler##3106+
|tip Crabs.
collect 8 Crawler Mucus##4888 |q 818/2 |goto Durotar 60.20,70.80
|mapmarker Durotar/0 52.20,83.00
|mapmarker Durotar/0 55.00,81.40
|mapmarker Durotar/0 56.40,78.40
|mapmarker Durotar/0 58.40,73.40
step
talk Master Gadrin##3188
turnin Minshina's Skull##808 |goto Durotar 55.95,74.72
turnin Zalazane##826 |goto Durotar 55.95,74.72
|tip Save the {o}Faintly Glowing Skull{} reward item.		|only if Warrior or Shaman
|tip Don't vendor it.						|only if Warrior or Shaman
|tip Used for a quest later.					|only if Warrior or Shaman
step
talk Master Vornal##3304
turnin A Solvent Spirit##818 |goto Durotar 55.94,74.39
step
talk Vel'rin Fang##3194
|tip Inside the building.
turnin Practical Prey##817 |goto Durotar 55.95,73.93
step
talk Gar'Thok##3139
|tip Upstairs inside the building.
turnin From The Wreckage....##825 |goto Durotar 51.95,43.50
step
talk Cook Torka##3191
|tip Walks around.
turnin Break a Few Eggs##815 |goto Durotar 51.11,42.45
step
kill 4 Razormane Quilboar##3111 |q 837/1 |goto Durotar 50.00,49.60
kill 4 Razormane Scout##3112 |q 837/2 |goto Durotar 50.00,49.60
|mapmarker Durotar/0 44.20,49.40
|mapmarker Durotar/0 47.40,48.00
|mapmarker Durotar/0 51.00,48.20
step
kill 4 Razormane Dustrunner##3113 |q 837/3 |goto Durotar 42.40,40.60
kill 4 Razormane Battleguard##3114 |q 837/4 |goto Durotar 42.40,40.60
|mapmarker Durotar/0 41.20,37.80
|mapmarker Durotar/0 44.40,36.00
step
Kill enemies
|tip Helps reach level 10 after quest turnins.
ding 9,5875 |goto Durotar 42.40,40.60
|mapmarker Durotar/0 41.20,37.80
|mapmarker Durotar/0 44.40,36.00
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Durotar 42.40,40.60 |q 837
|mapmarker Durotar/0 41.20,37.80
|mapmarker Durotar/0 44.40,36.00
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Durotar 53.51,44.45 |q 837 |zombiewalk
step
talk Gar'Thok##3139
|tip Upstairs inside the building.
turnin Encroachment##837 |goto Durotar 51.95,43.50
step
talk Tai'jin##3706
|tip Inside the building.
Train Abilities |trainer Tai'jin##3706 |goto Durotar/0 54.26,42.93 |q 834 |future
|only if Priest
step
talk Kaplak##3170
|tip Upstairs inside the building.
Train Abilities |trainer Kaplak##3170 |goto Durotar/0 51.98,43.69 |q 1859 |future
|only if Rogue
step
talk Dhugru Gorelust##3172
|tip Outside behind the building.
Train Abilities |trainer Dhugru Gorelust##3172 |goto Durotar/0 54.38,41.19 |q 1506 |future
|only if Warlock
step
talk Ophek##3294
|tip Outside behind the building.
accept Gan'rul's Summons##1506 |goto Durotar 54.37,41.29
|only if (Orc or Scourge) and Warlock
step
talk Kitha##6027
|tip Buy available Grimoires.
|tip Outside behind the building.
Train Demon Abilities |vendor Kitha##6027 |goto Durotar/0 54.71,41.50 |q 1506
|only if Warlock
step
_NOTE:_
Stronger Ammo Available
|tip Buy level 10 ammo when restocking.
Click Here to Continue |confirm |q 6062 |future
|only if Hunter
step
talk Thotar##3171
|tip Inside the building.
Train Abilities |trainer Thotar##3171 |goto Durotar/0 51.85,43.49 |q 6062 |future
|only if Hunter
step
talk Thotar##3171
|tip Inside the building.
accept Taming the Beast##6062 |goto Durotar/0 51.85,43.49
|only if Hunter
step
use Taming Rod##15917
|tip On a Dire Mottled Boar.
Tame a Dire Mottled Boar |q 6062/1 |goto Durotar/0 51.40,48.00
|mapmarker Durotar/0 50.40,44.40
|mapmarker Durotar/0 50.40,52.00
|mapmarker Durotar/0 54.00,45.40
|mapmarker Durotar/0 54.20,50.60
|mapmarker Durotar/0 56.60,47.00
|mapmarker Durotar/0 57.20,50.20
|only if Hunter
step
talk Thotar##3171
|tip Inside the building.
turnin Taming the Beast##6062 |goto Durotar/0 51.85,43.49
accept Taming the Beast##6083 |goto Durotar/0 51.85,43.49
|only if Hunter
step
use Taming Rod##15919
|tip On a Surf Crawler.
|tip Crabs.
Tame a Surf Crawler |q 6083/1 |goto Durotar/0 57.80,28.00
|mapmarker Durotar/0 59.40,23.00
|mapmarker Durotar/0 59.80,31.00
|mapmarker Durotar/0 60.40,26.00
|only if Hunter
step
talk Thotar##3171
|tip Inside the building.
turnin Taming the Beast##6083 |goto Durotar/0 51.85,43.49
accept Taming the Beast##6082 |goto Durotar/0 51.85,43.49
|only if Hunter
step
use Taming Rod##15920
|tip On an Armored Scorpid.
Tame an Armored Scorpid |q 6082/1 |goto Durotar/0 55.00,38.20
|mapmarker Durotar/0 54.00,33.80
|mapmarker Durotar/0 54.20,30.40
|mapmarker Durotar/0 57.20,29.00
|only if Hunter
step
talk Thotar##3171
|tip Inside the building.
turnin Taming the Beast##6082 |goto Durotar/0 51.85,43.49
accept Training the Beast##6081 |goto Durotar/0 51.85,43.49
|only if Hunter
step
talk Grimtak##3881
buy Tough Jerky##117 |n
|tip Buy {o}20{}, or whatever you can afford.
|tip Used to feed your pet soon.
Visit the Vendor |vendor Grimtak##3881 |goto Durotar 51.13,42.63 |q 6081 |future
|only if Hunter
step
talk Rezlak##3293
accept Winds in the Desert##834 |goto Durotar 46.37,22.94
|only if not (Warrior or Shaman)
step
talk Ormak Grimshot##3352
|tip Top of the building.
turnin Training the Beast##6081 |goto Orgrimmar/0 66.05,18.54
|only if Hunter
step
_NOTE:_
Train Your Pet
|tip Learn pet abilities from Pet Trainers.
|tip Cast {o}Beast Training{} to teach your pet.
Click Here to Continue |confirm |q 831
|only if Dwarf Hunter
step
talk Xao'tsu##10088
|tip Top of the building.
Train Pet Abilities |trainer Xao'tsu##10088 |goto Orgrimmar/0 66.34,14.83 |q 831
|only if Hunter
step
talk Vol'jin##10540
|tip Inside the building.
turnin The Admiral's Orders##831 |goto Orgrimmar/0 34.35,36.33
|only if Hunter or Warlock
step
talk Gan'rul Bloodeye##5875
|tip Inside the tent.
|tip Inside the Cleft of Shadow.
turnin Gan'rul's Summons##1506 |goto Orgrimmar/0 48.24,45.29
accept Creature of the Void##1501 |goto Orgrimmar/0 48.24,45.29
|only if Warlock
step
_Note:_
Enter the Ragefire Chasm Dungeon
|tip Walk into the portal.
|tip Inside the Cleft of Shadow.
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
|tip Takes you outside Orgrimmar.
Die on Purpose |complete isdead |goto Orgrimmar/0 52.31,49.27 |q 834 |future
|only if Warlock
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Durotar 47.05,17.59 |q 834 |future |zombiewalk
|only if Warlock
step
_NOTE:_
Tame a Venomtail Scorpid
|tip Cast {o}Tame Beast{} on a {o}Venomtail Scorpid{}.
|tip Scorpions.
|tip New permanent pet.
Click Here to Continue |confirm |goto Durotar 49.80,17.40 |q 834 |future
|mapmarker Durotar/0 38.00,19.20
|mapmarker Durotar/0 38.20,22.40
|mapmarker Durotar/0 39.20,16.40
|mapmarker Durotar/0 41.40,19.40
|mapmarker Durotar/0 44.40,21.00
|mapmarker Durotar/0 43.40,16.60
|mapmarker Durotar/0 52.80,12.80
|mapmarker Durotar/0 55.40,15.20
|mapmarker Durotar/0 55.80,12.20
|only if Hunter
step
click Stolen Supply Sack+
|tip Tan bags.
collect 5 Sack of Supplies##4918 |q 834/1 |goto Durotar 49.10,22.50
|mapmarker Durotar/0 47.20,29.70
|mapmarker Durotar/0 47.20,30.80
|mapmarker Durotar/0 47.30,33.50
|mapmarker Durotar/0 49.70,24.30
|mapmarker Durotar/0 49.70,32.20
|mapmarker Durotar/0 50.10,25.70
|only if not (Warrior or Shaman)
step
talk Rezlak##3293
turnin Winds in the Desert##834 |goto Durotar 46.37,22.94
accept Securing the Lines##835 |goto Durotar 46.37,22.94
|only if not (Warrior or Shaman)
step
Follow the path and walk through the tunnel |goto Durotar 51.95,27.44 < 15 |only if walking and not subzone("Drygulch Ravine")
kill 8 Dustwind Storm Witch##3118 |q 835/2 |goto Durotar 53.20,24.60
kill 12 Dustwind Savage##3117 |q 835/1 |goto Durotar 53.20,24.60
|mapmarker Durotar/0 51.20,19.20
|mapmarker Durotar/0 51.40,21.00
|mapmarker Durotar/0 51.40,23.40
|mapmarker Durotar/0 52.60,21.40
|mapmarker Durotar/0 54.00,22.40
|only if not (Warrior or Shaman)
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Durotar 53.20,24.60 |q 835
|mapmarker Durotar/0 51.20,19.20
|mapmarker Durotar/0 51.40,21.00
|mapmarker Durotar/0 51.40,23.40
|mapmarker Durotar/0 52.60,21.40
|mapmarker Durotar/0 54.00,22.40
|only if not (Warrior or Shaman)
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Durotar 47.05,17.59 |q 835 |zombiewalk
|only if not (Warrior or Shaman)
step
talk Rezlak##3293
turnin Securing the Lines##835 |goto Durotar 46.37,22.94
|only if not (Warrior or Shaman)
step
Enter the cave |goto Durotar 55.02,9.79 < 15 |walk |only if not (subzone("Skull Rock") and indoors())
Follow the path |goto Durotar 53.71,8.71 < 10 |walk
click Burning Blade Stash
|tip Inside the cave.
collect Tablet of Verga##6535 |q 1501/1 |goto Durotar 51.62,9.74
|only if Warlock
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
|tip Anywhere inside the cave.
Die on Purpose |complete isdead |goto Durotar 55.02,9.79 |q 1501
|only if Warlock
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Durotar 47.05,17.59 |q 1501 |zombiewalk
|only if Warlock
step
use Eye of Burning Shadow##4903
accept Burning Shadows##832
|only if Warlock and itemcount(4903) > 0
step
talk Gan'rul Bloodeye##5875
|tip Inside the tent.
|tip Inside the Cleft of Shadow.
turnin Creature of the Void##1501 |goto Orgrimmar 48.24,45.29
accept The Binding##1504 |goto Orgrimmar 48.24,45.29
|only if Warlock
step
talk Neeru Fireblade##3216
|tip Inside the tent.
step
turnin Burning Shadows##832 |goto Orgrimmar 49.47,50.59
|only if Warlock and (haveq(832) or completedq(832))
step
use Glyphs of Summoning##7464
|tip Stand on the pink symbol.
|tip Inside the tent.
step
kill Summoned Voidwalker##5676 |q 1504/1 |goto Orgrimmar 49.44,50.02
|only if Warlock
step
talk Gan'rul Bloodeye##5875
|tip Inside the tent.
step
turnin The Binding##1504 |goto Orgrimmar 48.24,45.29
|only if Warlock
step
|next "Leveling Guides\\Starter Guides (1-12)\\Durotar (10-13)"		|only if Warrior or Shaman
|next "Leveling Guides\\Starter Guides (1-12)\\Eversong Woods (10-12)"	|only if not (Warrior or Shaman)
]])
ZygorGuidesViewer:RegisterGuide("Leveling Guides\\Starter Guides (1-12)\\Durotar (10-13)",{
image=ZGV.IMAGESDIR.."Durotar",
condition_visible=function() return Orc or Troll or Undead and (Warrior or Shaman) end,
linked = {"Leveling Guides\\Hidden Guides"},
linkedhidden = true,
next="Leveling Guides\\Classic (12-60)\\The Barrens & Stonetalon Mountain (13-21)",
},[[
step
_NOTE:_
Wrong Character Race or Class
|tip Guide written for {o}Warrior or Shaman{} characters that are {o}Orc, Troll or Undead{}.
|tip Other races or classes may encounter issues.
Click Here to Continue |confirm
|only if not (Orc or Troll or Undead and (Warrior or Shaman))
step
talk Innkeeper Grosk##6928
|tip Inside the building.
home Razor Hill |goto Durotar/0 51.52,41.65 |q 844 |future
step
talk Tarshaw Jaggedscar##3169
|tip Inside the building.
Train Abilities |trainer Tarshaw Jaggedscar##3169 |goto Durotar/0 54.19,42.47 |q 834 |future
|only if Warrior
step
talk Tarshaw Jaggedscar##3169
|tip Inside the building.
accept Veteran Uzzek##1505 |goto Durotar/0 54.19,42.47
|only if Warrior
step
talk Swart##3173
|tip Inside the building.
Train Abilities |trainer Swart##3173 |goto Durotar/0 54.42,42.59 |q 834 |future
|only if Shaman
step
talk Swart##3173
|tip Inside the building.
accept Call of Fire##2983 |goto Durotar/0 54.42,42.59
|only if Shaman
step
talk Takrin Pathseeker##3336
accept Conscript of the Horde##840 |goto Durotar 50.85,43.59
step
talk Kargal Battlescar##3337
turnin Conscript of the Horde##840 |goto The Barrens 62.26,19.38
accept Crossroads Conscription##842 |goto The Barrens 62.26,19.38
step
talk Uzzek##5810
turnin Veteran Uzzek##1505 |goto The Barrens 61.38,21.11
accept Path of Defense##1498 |goto The Barrens 61.38,21.11
|only if Warrior
step
talk Kranal Fiss##5907
|tip Walks around.
turnin Call of Fire##2983 |goto The Barrens 56.03,19.89
accept Call of Fire##1524 |goto The Barrens 56.03,19.89
|only if Shaman
step
talk Sergra Darkthorn##3338
turnin Crossroads Conscription##842 |goto The Barrens 52.24,31.01
step
talk Zargh##3489
accept Meats to Orgrimmar##6365 |goto The Barrens 52.62,29.84
|only if Orc or Troll
step
talk Devrak##3615
turnin Meats to Orgrimmar##6365 |goto The Barrens 51.50,30.34
accept Ride to Orgrimmar##6384 |goto The Barrens 51.50,30.34
|only if Orc or Troll
step
talk Devrak##3615
fpath Crossroads |goto The Barrens 51.50,30.34
step
talk Omusa Thunderhorn##10378
|tip Careful, high level enemies.
fpath Camp Taurajo |goto The Barrens 44.45,59.15
step
map Mulgore
path	follow strictbounce;	loop off;	ants curved;	dist 30;	markers none
path	59.72,62.45	57.37,61.24	56.19,61.05	54.83,60.54	53.08,60.28
path	51.94,59.61
talk Morin Cloudstalker##2988
|tip Walks along the road.
accept The Ravaged Caravan##749
step
talk Ahab Wheathoof##23618
accept Kyle's Gone Missing!##11129 |goto Mulgore/0 48.24,53.27
stickystart "Collect_Tender_Strider_Meat"
step
click Sealed Supply Crate
turnin The Ravaged Caravan##749 |goto Mulgore 53.74,48.18
accept The Ravaged Caravan##751 |goto Mulgore 53.74,48.18
step
map Mulgore
path	follow strictbounce;	loop off;	ants curved;	dist 30;	markers none
path	59.72,62.45	57.37,61.24	56.19,61.05	54.83,60.54	53.08,60.28
path	51.94,59.61
talk Morin Cloudstalker##2988
|tip Walks along the road.
turnin The Ravaged Caravan##751
accept The Venture Co.##764
accept Supervisor Fizsprocket##765
stickystart "Kill_Venture_Co_Supervisors_And_Venture_Co_Workers"
step
Follow the path up and enter the mine |goto Mulgore 61.56,46.90 < 15 |walk |only if not (subzone("The Venture Co. Mine") and indoors())
kill Supervisor Fizsprocket##3051
|tip Inside the mine.
collect Fizsprocket's Clipboard##4819 |q 765/1 |goto Mulgore 64.90,43.31
stickystop "Collect_Tender_Strider_Meat"
step
label "Kill_Venture_Co_Supervisors_And_Venture_Co_Workers"
kill 6 Venture Co. Supervisor##2979 |q 764/2 |goto Mulgore 61.56,46.90
kill 14 Venture Co. Worker##2978 |q 764/1 |goto Mulgore 61.56,46.90
|tip Inside and outside the mine. |notinsticky
|mapmarker Mulgore/0 59.40,47.40
|mapmarker Mulgore/0 60.20,42.80
|mapmarker Mulgore/0 60.40,49.60
|mapmarker Mulgore/0 62.20,42.00
|mapmarker Mulgore/0 62.40,44.00
|mapmarker Mulgore/0 62.80,40.00
|mapmarker Mulgore/0 64.20,42.40
|mapmarker Mulgore/0 64.80,44.60
step
Leave the mine |goto 61.56,46.90 < 15 |c |q 765
|only if subzone("The Venture Co. Mine") and indoors()
stickystart "Collect_Tender_Strider_Meat"
step
map Mulgore
path	follow strictbounce;	loop off;	ants curved;	dist 30;	markers none
path	59.72,62.45	57.37,61.24	56.19,61.05	54.83,60.54	53.08,60.28
path	51.94,59.61
talk Morin Cloudstalker##2988
|tip Walks along the road.
turnin The Venture Co.##764
turnin Supervisor Fizsprocket##765
step
label "Collect_Tender_Strider_Meat"
kill Elder Plainstrider##2957, Adult Plainstrider##2956
|tip Large walking birds.
collect Tender Strider Meat##33009 |goto Mulgore/0 56.40,59.80 |q 11129
|mapmarker Mulgore/0 50.40,67.60
|mapmarker Mulgore/0 51.40,70.60
|mapmarker Mulgore/0 52.40,65.20
|mapmarker Mulgore/0 53.80,61.40
|mapmarker Mulgore/0 54.40,57.00
|mapmarker Mulgore/0 54.40,68.40
|mapmarker Mulgore/0 55.20,53.60
|mapmarker Mulgore/0 55.40,64.40
|mapmarker Mulgore/0 57.40,71.20
|mapmarker Mulgore/0 57.80,67.80
|mapmarker Mulgore/0 58.20,56.60
|mapmarker Mulgore/0 59.20,64.40
|mapmarker Mulgore/0 59.40,53.40
|mapmarker Mulgore/0 60.20,59.80
|mapmarker Mulgore/0 60.40,70.00
|mapmarker Mulgore/0 61.80,55.60
step
use Tender Strider Meat##33009
|tip On Kyle the Frenzied.
|tip Grey wolf.
|tip Runs around the village.
Watch the dialogue
Feed Kyle |q 11129/1 |goto Mulgore 49.20,58.80
|mapmarker Mulgore/0 47.00,58.40
|mapmarker Mulgore/0 47.40,60.40
|mapmarker Mulgore/0 48.40,62.60
step
talk Ahab Wheathoof##23618
turnin Kyle's Gone Missing!##11129 |goto Mulgore/0 48.24,53.27
step
Ride an elevator up into Thunder Bluff |goto Thunder Bluff/0 32.06,67.11 < 30 |only if walking and not zone ("Thunder Bluff")
talk Ansekhwa##11869
Train Staves |complete weaponskill("TH_STAFF") > 0		|goto Thunder Bluff 40.93,62.73		|only if Warrior
Train Two-Handed Maces |complete weaponskill("TH_MACE") > 0	|goto Thunder Bluff 40.93,62.73		|only if Shaman
step
talk Tal##2995
|tip Top of the tower.
fpath Thunder Bluff |goto Thunder Bluff/0 47.00,49.83
step
talk Misha Tor'kren##3193
|tip Walks around.
|tip Inside the building.
accept Lost But Not Forgotten##816 |goto Durotar 43.11,30.24
step
talk Rezlak##3293
accept Winds in the Desert##834 |goto Durotar 46.37,22.94
step
click Stolen Supply Sack+
|tip Tan bags.
collect 5 Sack of Supplies##4918 |q 834/1 |goto Durotar 49.10,22.50
|mapmarker Durotar/0 47.20,29.70
|mapmarker Durotar/0 47.20,30.80
|mapmarker Durotar/0 47.30,33.50
|mapmarker Durotar/0 49.70,24.30
|mapmarker Durotar/0 49.70,32.20
|mapmarker Durotar/0 50.10,25.70
step
talk Rezlak##3293
turnin Winds in the Desert##834 |goto Durotar 46.37,22.94
accept Securing the Lines##835 |goto Durotar 46.37,22.94
step
Follow the path and walk through the tunnel |goto Durotar 51.95,27.44 < 15 |only if walking and not subzone("Drygulch Ravine")
kill 8 Dustwind Storm Witch##3118 |q 835/2 |goto Durotar 53.20,24.60
kill 12 Dustwind Savage##3117 |q 835/1 |goto Durotar 53.20,24.60
|mapmarker Durotar/0 51.20,19.20
|mapmarker Durotar/0 51.40,21.00
|mapmarker Durotar/0 51.40,23.40
|mapmarker Durotar/0 52.60,21.40
|mapmarker Durotar/0 54.00,22.40
step
Allow Enemies to Kill You
|tip Fast travel.
Die on Purpose |complete isdead |goto Durotar 53.20,24.60 |q 835
|mapmarker Durotar/0 51.20,19.20
|mapmarker Durotar/0 51.40,21.00
|mapmarker Durotar/0 51.40,23.40
|mapmarker Durotar/0 52.60,21.40
|mapmarker Durotar/0 54.00,22.40
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Durotar 47.05,17.59 |q 835 |zombiewalk
step
talk Rezlak##3293
turnin Securing the Lines##835 |goto Durotar 46.37,22.94
step
talk Rhinag##3190
|tip Between the rocks.
|tip {o}Hurry{}, timed quest.
accept Need for a Cure##812 |goto Durotar/0 41.55,18.61
step
talk Innkeeper Gryshka##6929
|tip Inside the building.
turnin Ride to Orgrimmar##6384 |goto Orgrimmar 54.09,68.41
accept Doras the Wind Rider Master##6385 |goto Orgrimmar 54.09,68.41
|only if Orc or Troll
step
talk Doras##3310
|tip Top of the tower.
turnin Doras the Wind Rider Master##6385 |goto Orgrimmar 45.12,63.89
accept Return to the Crossroads.##6386 |goto Orgrimmar 45.12,63.89
|only if Orc or Troll
step
talk Vol'jin##10540
|tip Inside the building.
turnin The Admiral's Orders##831 |goto Orgrimmar/0 34.35,36.33
step
talk Thrall##4949
|tip Inside the building.
accept Hidden Enemies##5726 |goto Orgrimmar/0 31.73,37.82
step
talk Kor'ghan##3189
|tip Inside the Cleft of Shadow.
accept Finding the Antidote##813 |goto Orgrimmar 47.24,53.58
|only if haveq(812)
step
Abandon the {y}Need for a Cure{} Quest |complete not haveq(812)
|tip Not needed.
|tip Removes the quest timer.
step
Jump down carefully onto the flat rock below |goto Durotar 43.21,25.05 < 10 |only if walking
use Faintly Glowing Skull##4945
|tip On Fizzle Darkstorm when he's {o}next to the bonfire{}.
|tip Damages him.
|tip Goblin with imp minion.
|tip Walks around.
|tip Clear most enemies first and pull him away.
kill Fizzle Darkstorm##3203
|tip Kill his imp first.
collect Fizzle's Claw##4869 |q 806/1 |goto Durotar 42.28,26.59
step
kill Thunder Lizard##3130+
collect 5 Singed Scale##6486 |q 1498/1 |goto Durotar 40.00,24.20
|mapmarker Durotar/0 39.00,26.40
|mapmarker Durotar/0 40.40,29.00
|only if Warrior
step
Leave the canyon |goto Durotar 39.16,32.31 < 40 |only if walking and subzone("Thunder Ridge")
kill Dreadmaw Crocolisk##3110+
collect Kron's Amulet##4891 |q 816/1 |goto Durotar/0 37.40,17.00
|mapmarker Durotar/0 34.20,44.00
|mapmarker Durotar/0 34.20,49.00
|mapmarker Durotar/0 34.40,52.00
|mapmarker Durotar/0 34.80,30.60
|mapmarker Durotar/0 34.80,36.40
|mapmarker Durotar/0 34.80,40.60
|mapmarker Durotar/0 35.00,55.80
|mapmarker Durotar/0 35.40,24.80
|mapmarker Durotar/0 36.20,21.40
step
Follow the path up |goto Durotar 36.59,57.07 < 20 |only if walking
talk Telf Joolam##5900
|tip Top of the mountain.
turnin Call of Fire##1524 |goto Durotar 38.55,58.96
accept Call of Fire##1525 |goto Durotar 38.55,58.96
|only if Shaman
step
Allow Enemies to Kill You
|tip Fast travel.
|tip Anywhere around this area.
Die on Purpose |complete isdead |goto Durotar 37.85,43.09 |q 806
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Durotar 53.49,44.47 |q 806 |zombiewalk
step
talk Orgnil Soulscar##3142
turnin Dark Storms##806 |goto Durotar 52.25,43.15
accept Margoz##828 |goto Durotar 52.25,43.15
step
talk Tarshaw Jaggedscar##3169
|tip Inside the building.
Train Abilities |trainer Tarshaw Jaggedscar##3169 |goto Durotar/0 54.19,42.47 |q 828
|only if Warrior
step
talk Swart##3173
|tip Inside the building.
Train Abilities |trainer Swart##3173 |goto Durotar/0 54.42,42.59 |q 828
|only if Shaman
step
Follow the path up |goto 54.54,38.79 < 40 |only if walking and not (subzone("Dustwind Cave") and indoors())
kill Burning Blade Cultist##3199+
|tip Inside the cave.
|tip In the back.
collect Reagent Pouch##6652 |q 1525/2 |goto Durotar/0 52.80,28.60
|mapmarker Durotar/0 51.80,25.80
|only if Shaman
step
Leave the cave |goto Durotar/0 52.80,28.60 < 15 |walk |only if subzone("Dustwind Cave") and indoors()
talk Margoz##3208
turnin Margoz##828 |goto Durotar 56.41,20.04
accept Skull Rock##827 |goto Durotar 56.41,20.04
stickystart "Collect_Venomtail_Poison_Sacs"
step
kill Burning Blade Apprentice##3198, Burning Blade Fanatic##3197
|tip Inside the cave.
collect Lieutenant's Insignia##14544 |q 5726/1 |goto Durotar 54.98,9.67
collect 6 Searing Collar##4871 |q 827/1 |goto Durotar 54.98,9.67
|mapmarker Durotar/0 52.40,10.00
|mapmarker Durotar/0 53.00,7.40
step
Leave the cave |goto Durotar 52.82,28.90 < 15 |walk |only if subzone("Skull Rock") and indoors()
talk Margoz##3208
turnin Skull Rock##827 |goto Durotar 56.41,20.03
accept Neeru Fireblade##829 |goto Durotar 56.41,20.03
step
use Eye of Burning Shadow##4903
accept Burning Shadows##832
|only if itemcount(4903) > 0
step
label "Collect_Venomtail_Poison_Sacs"
kill Venomtail Scorpid##3127+
|tip Scorpions.
collect 4 Venomtail Poison Sac##4886 |q 813/1 |goto Durotar 55.40,15.20
|mapmarker Durotar/0 38.00,19.20
|mapmarker Durotar/0 38.20,22.40
|mapmarker Durotar/0 39.20,16.40
|mapmarker Durotar/0 41.40,19.40
|mapmarker Durotar/0 44.40,21.00
|mapmarker Durotar/0 43.40,16.60
|mapmarker Durotar/0 52.80,12.80
|mapmarker Durotar/0 49.80,17.40
|mapmarker Durotar/0 55.80,12.20
|only if not (subzone("Skull Rock") and indoors())
step
talk Thrall##4949
|tip Inside the building.
turnin Hidden Enemies##5726 |goto Orgrimmar/0 31.73,37.82
step
talk Kor'ghan##3189
step
turnin Finding the Antidote##813 |goto Orgrimmar 47.24,53.59
step
talk Neeru Fireblade##3216
|tip Inside the tent.
step
turnin Neeru Fireblade##829 |goto Orgrimmar 49.49,50.59
accept Ak'Zeloth##809 |goto Orgrimmar 49.49,50.59
turnin Burning Shadows##832 |goto Orgrimmar 49.47,50.59 |only if (haveq(832) or completedq(832))
step
_Note:_
Enter the Ragefire Chasm Dungeon
|tip Walk into the portal.
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
|tip Takes you outside Orgrimmar.
Die on Purpose |complete isdead |goto Orgrimmar 52.31,49.27 |q 812 |future
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Durotar 47.05,17.59 |q 812 |future |zombiewalk
step
talk Rhinag##3190
|tip Between the rocks.
accept Need for a Cure##812 |goto Durotar/0 41.55,18.61
step
talk Rhinag##3190
|tip Between the rocks.
turnin Need for a Cure##812 |goto Durotar/0 41.55,18.61
step
talk Misha Tor'kren##3193
|tip Walks around.
|tip Inside the building.
turnin Lost But Not Forgotten##816 |goto Durotar 43.10,30.24
step
kill Razormane Geomancer##3269, Razormane Thornweaver##3268, Razormane Mystic##3271, Razormane Water Seeker##3267
|tip Thornweavers and Water Seekers.
collect Fire Tar##5026 |q 1525/1 |goto The Barrens 55.60,25.40
|mapmarker The Barrens/0 53.00,25.20
|mapmarker The Barrens/0 54.40,27.20
|only if (Orc or Troll) and Shaman
step
Follow the path up |goto Durotar 36.59,57.07 < 15 |only if walking
talk Telf Joolam##5900
|tip Top of the mountain.
turnin Call of Fire##1525 |goto Durotar 38.55,58.96
accept Call of Fire##1526 |goto Durotar 38.55,58.96
|only if (Orc or Troll) and Shaman
step
use Fire Sapta##6636
|tip Top of the mountain.
Gain Sapta Sight |havebuff Sapta Sight##8898 |goto Durotar 38.16,58.54 |q 1526
|only if (Orc or Troll) and Shaman
step
kill Minor Manifestation of Fire##5893
|tip Top of the mountain.
collect Glowing Ember##6655 |q 1526/1 |goto Durotar 38.72,58.29
|only if (Orc or Troll) and Shaman
step
click Brazier of the Dormant Flame
|tip Top of the mountain.
turnin Call of Fire##1526 |goto Durotar 38.95,58.22
accept Call of Fire##1527 |goto Durotar 38.95,58.22
|only if (Orc or Troll) and Shaman
step
Kill enemies
ding 13 |goto Durotar 42.40,40.60
|mapmarker Durotar/0 41.20,37.80
|mapmarker Durotar/0 44.40,36.00
]])
ZygorGuidesViewer:RegisterGuide("Leveling Guides\\Starter Guides (1-12)\\Blood Elf Starter (1-5)",{
image=ZGV.IMAGESDIR.."Eversong Woods",
condition_suggested=function() return raceclass('BloodElf') and level <= 13 end,
condition_suggested_exclusive=true,
condition_visible=function() return BloodElf end,
linked = {"Leveling Guides\\Hidden Guides"},
linkedhidden = true,
next="Leveling Guides\\Starter Guides (1-12)\\Eversong Woods (5-10)",
},[[
defaultfor BloodElf
step
_NOTE:_
Wrong Character Race
|tip Guide written for {o}Blood Elf{} characters.
|tip Other races may encounter issues.
Click Here to Continue |confirm
|only if not BloodElf
step
_Destroy This Item:_
|tip Saves bag space.
|tip You'll get one later.
trash Hearthstone##6948 |q 8350
step
_NOTE:_
Manage Your Ammo
|tip Make sure you always have ammo.
|tip You need it to attack enemies.
|tip {o}General Goods{} vendors sell it (also Bow & Gun vendors).
|tip Try to keep your ammo bag full.
Click Here to Continue |confirm |q 8325 |future
|only if BloodElf Hunter
step
talk Magistrix Erona##15278
accept Reclaiming Sunstrider Isle##8325 |goto Eversong Woods/0 38.21,20.83
|only if BloodElf
stickystart "Kill_Mana_Wyrms"
step
kill Mana Wyrm##15274+
|tip Loot items worth at least {o}10 copper{} to sell.
|tip Allows training a spell early.
|tip Increases leveling speed.
Click to Continue |confirm |goto Eversong Woods/0 36.00,20.00 |q 8325
|mapmarker Eversong Woods/0 33.40,20.00
|mapmarker Eversong Woods/0 34.40,18.20
|mapmarker Eversong Woods/0 35.40,22.20
|mapmarker Eversong Woods/0 37.40,22.60
|mapmarker Eversong Woods/0 37.40,25.00
|only if Warlock
step
talk Yasmine Teli'Larien##15494
|tip Inside the building.
Sell Items |vendor Yasmine Teli'Larien##15494 |goto Eversong Woods/0 38.86,21.39 |q 8325
|only if Warlock
step
talk Summoner Teli'Larien##15283
|tip Inside the building.
Train Abilities |trainer Summoner Teli'Larien##15283 |goto Eversong Woods/0 38.93,21.44 |q 8325
|only if Warlock
step
label "Kill_Mana_Wyrms"
kill 8 Mana Wyrm##15274 |q 8325/1 |goto Eversong Woods/0 36.00,20.00
|mapmarker Eversong Woods/0 33.40,20.00
|mapmarker Eversong Woods/0 34.40,18.20
|mapmarker Eversong Woods/0 35.40,22.20
|mapmarker Eversong Woods/0 37.40,22.60
|mapmarker Eversong Woods/0 37.40,25.00
|only if BloodElf
step
talk Magistrix Erona##15278
turnin Reclaiming Sunstrider Isle##8325 |goto Eversong Woods/0 38.21,20.83
accept Unfortunate Measures##8326 |goto Eversong Woods/0 38.21,20.83
accept Hunter Training##9393	|goto Eversong Woods/0 38.21,20.83	|only if BloodElf Hunter
accept Paladin Training##9676	|goto Eversong Woods/0 38.21,20.83	|only if BloodElf Paladin
accept Rogue Training##9392	|goto Eversong Woods/0 38.21,20.83	|only if BloodElf Rogue
accept Priest Training##8564	|goto Eversong Woods/0 38.21,20.83	|only if BloodElf Priest
accept Mage Training##8328	|goto Eversong Woods/0 38.21,20.83	|only if BloodElf Mage
accept Warlock Training##8563	|goto Eversong Woods/0 38.21,20.83	|only if BloodElf Warlock
|only if BloodElf
step
talk Ranger Sallina##15513
|tip Inside the building.
turnin Hunter Training##9393 |goto Eversong Woods/0 39.05,20.01
accept Well Watcher Solanian##10070 |goto Eversong Woods/0 39.05,20.01
|only if BloodElf Hunter
step
talk Ranger Sallina##15513
|tip Inside the building.
Train Abilities |trainer Ranger Sallina##15513 |goto Eversong Woods/0 39.05,20.01 |q 10070
|only if Hunter
step
talk Jesthenis Sunstriker##15280
|tip Inside the building.
turnin Paladin Training##9676 |goto Eversong Woods/0 39.47,20.56
accept Well Watcher Solanian##10069 |goto Eversong Woods/0 39.47,20.56
|only if BloodElf Paladin
step
talk Jesthenis Sunstriker##15280
|tip Inside the building.
Train Abilities |trainer Jesthenis Sunstriker##15280 |goto Eversong Woods/0 39.47,20.56 |q 10069
|only if Paladin
step
talk Pathstalker Kariel##15285
|tip Inside the building.
turnin Rogue Training##9392 |goto Eversong Woods/0 38.93,20.02
accept Well Watcher Solanian##10071 |goto Eversong Woods/0 38.93,20.02
|only if BloodElf Rogue
step
talk Pathstalker Kariel##15285
|tip Inside the building.
Train Abilities |trainer Pathstalker Kariel##15285 |goto Eversong Woods/0 38.93,20.02 |q 10071
|only if Rogue
step
talk Matron Arena##15284
|tip Inside the building.
turnin Priest Training##8564 |goto Eversong Woods/0 39.42,20.38
accept Well Watcher Solanian##10072 |goto Eversong Woods/0 39.42,20.38
|only if BloodElf Priest
step
talk Matron Arena##15284
|tip Inside the building.
Train Abilities |trainer Matron Arena##15284 |goto Eversong Woods/0 39.42,20.38 |q 10072
|only if Priest
step
talk Julia Sunstriker##15279
|tip Inside the building.
turnin Mage Training##8328 |goto Eversong Woods/0 39.23,21.46
accept Well Watcher Solanian##10068 |goto Eversong Woods/0 39.23,21.46
|only if BloodElf Mage
step
talk Julia Sunstriker##15279
|tip Inside the building.
Train Abilities |trainer Julia Sunstriker##15279 |goto Eversong Woods/0 39.23,21.46 |q 10068
|only if Mage
step
talk Summoner Teli'Larien##15283
|tip Inside the building.
turnin Warlock Training##8563 |goto Eversong Woods/0 38.93,21.44
accept Windows to the Source##8344 |goto Eversong Woods/0 38.93,21.44
accept Well Watcher Solanian##10073 |goto Eversong Woods/0 38.93,21.44
|only if BloodElf Warlock
step
talk Well Watcher Solanian##15295
|tip Up on the balcony of the building.
turnin Well Watcher Solanian##10070	|goto Eversong Woods/0 38.76,19.36	|only if BloodElf Hunter
turnin Well Watcher Solanian##10069	|goto Eversong Woods/0 38.76,19.36	|only if BloodElf Paladin
turnin Well Watcher Solanian##10071	|goto Eversong Woods/0 38.76,19.36	|only if BloodElf Rogue
turnin Well Watcher Solanian##10072	|goto Eversong Woods/0 38.76,19.36	|only if BloodElf Priest
turnin Well Watcher Solanian##10068	|goto Eversong Woods/0 38.76,19.36	|only if BloodElf Mage
turnin Well Watcher Solanian##10073	|goto Eversong Woods/0 38.76,19.36	|only if BloodElf Warlock
accept Solanian's Belongings##8330	|goto Eversong Woods/0 38.76,19.36
accept The Shrine of Dath'Remar##8345	|goto Eversong Woods/0 38.76,19.36
step
talk Arcanist Ithanas##15296
accept A Fistful of Slivers##8336 |goto Eversong Woods/0 38.27,19.13
|only if BloodElf
step
talk Arcanist Helion##15297
accept Thirst Unending##8346 |goto Eversong Woods/0 37.18,18.94
|only if BloodElf
stickystart "Mana_Tap_Creatures"
stickystart "Collect_Arcane_Slivers"
stickystart "Collect_Lynx_Collars"
step
click Solanian's Journal##180512
collect Solanian's Journal##20472 |q 8330/3 |goto Eversong Woods/0 37.70,24.91
step
label "Mana_Tap_Creatures"
Mana Tap #6# Creatures |q 8346/1 |goto Eversong Woods/0 37.40,25.00
|tip Cast {o}Mana Tap{} on Mana Wyrms.
|mapmarker Eversong Woods/0 33.40,20.00
|mapmarker Eversong Woods/0 34.40,18.20
|mapmarker Eversong Woods/0 35.40,22.20
|mapmarker Eversong Woods/0 37.40,22.60
|mapmarker Eversong Woods/0 36.00,20.00
|only if BloodElf
step
label "Collect_Arcane_Slivers"
kill Mana Wyrm##15274+
collect 6 Arcane Sliver##20482 |q 8336/1 |goto Eversong Woods/0 37.40,25.00
|mapmarker Eversong Woods/0 33.40,20.00
|mapmarker Eversong Woods/0 34.40,18.20
|mapmarker Eversong Woods/0 35.40,22.20
|mapmarker Eversong Woods/0 37.40,22.60
|mapmarker Eversong Woods/0 36.00,20.00
|only if BloodElf
step
label "Collect_Lynx_Collars"
kill Springpaw Cub##15366, Springpaw Lynx##15372
|tip Orange cougars.
collect 8 Lynx Collar##20797 |q 8326/1 |goto Eversong Woods/0 36.40,23.40
|mapmarker Eversong Woods/0 32.40,19.80
|mapmarker Eversong Woods/0 32.40,23.00
|mapmarker Eversong Woods/0 34.20,21.20
|mapmarker Eversong Woods/0 34.40,23.60
|mapmarker Eversong Woods/0 35.40,25.80
|mapmarker Eversong Woods/0 36.40,27.60
|mapmarker Eversong Woods/0 39.40,18.40
|mapmarker Eversong Woods/0 39.40,22.20
|mapmarker Eversong Woods/0 39.80,16.40
|mapmarker Eversong Woods/0 40.80,20.60
step
Kill enemies
|tip Helps reach level 4 after quest turnins.
ding 3,540 |goto Eversong Woods/0 36.40,23.40
|mapmarker Eversong Woods/0 32.40,19.80
|mapmarker Eversong Woods/0 32.40,23.00
|mapmarker Eversong Woods/0 34.20,21.20
|mapmarker Eversong Woods/0 34.40,23.60
|mapmarker Eversong Woods/0 35.40,25.80
|mapmarker Eversong Woods/0 36.40,27.60
|mapmarker Eversong Woods/0 39.40,18.40
|mapmarker Eversong Woods/0 39.40,22.20
|mapmarker Eversong Woods/0 39.80,16.40
|mapmarker Eversong Woods/0 40.80,20.60
step
talk Arcanist Helion##15297
turnin Thirst Unending##8346 |goto Eversong Woods/0 37.18,18.94
|only if BloodElf
step
talk Arcanist Ithanas##15296
turnin A Fistful of Slivers##8336 |goto Eversong Woods/0 38.27,19.13
|only if BloodElf
step
talk Magistrix Erona##15278
turnin Unfortunate Measures##8326 |goto Eversong Woods/0 38.21,20.83
accept Report to Lanthan Perilon##8327 |goto Eversong Woods/0 38.21,20.83
step
talk Summoner Teli'Larien##15283
|tip Inside the building.
Train Abilities |trainer Summoner Teli'Larien##15283 |goto Eversong Woods/0 38.94,21.44 |q 8327
|only if Warlock
step
talk Julia Sunstriker##15279
|tip Inside the building.
Train Abilities |trainer Julia Sunstriker##15279 |goto Eversong Woods/0 39.23,21.46 |q 8327
|only if Mage
step
talk Jesthenis Sunstriker##15280
|tip Inside the building.
Train Abilities |trainer Jesthenis Sunstriker##15280 |goto Eversong Woods/0 39.47,20.56 |q 8327
|only if Paladin
step
talk Matron Arena##15284
|tip Inside the building.
Train Abilities |trainer Matron Arena##15284 |goto Eversong Woods/0 39.42,20.38 |q 8327
|only if Priest
step
talk Ranger Sallina##15513
|tip Inside the building.
Train Abilities |trainer Ranger Sallina##15513 |goto Eversong Woods/0 39.05,20.01 |q 8327
|only if Hunter
step
talk Pathstalker Avokor##15285
|tip Inside the building.
Train Abilities |trainer Pathstalker Avokor##15285 |goto Eversong Woods/0 38.93,20.02 |q 8327
|only if Rogue
step
talk Lanthan Perilon##15281
turnin Report to Lanthan Perilon##8327 |goto Eversong Woods/0 35.37,22.52
accept Aggression##8334 |goto Eversong Woods/0 35.37,22.52
stickystart "Collect_Wraith_Essences_Warlock"
step
Run up the ramp |goto Eversong Woods/0 32.61,25.52 < 15 |only if walking
kill Tainted Arcane Wraith##15298
|tip Black ghosts.
|tip Up on the higher platforms. |notinsticky
collect Tainted Wraith Essence##20935 |q 8344/2 |goto Eversong Woods/0 31.40,29.40
|mapmarker Eversong Woods/0 30.40,27.20
|only if BloodElf Warlock
step
label "Collect_Wraith_Essences_Warlock"
kill Arcane Wraith##15273+
|tip Purple ghosts.
|tip Up on the platforms. |notinsticky
collect Wraith Essence##20934 |q 8344/1 |goto Eversong Woods/0 31.00,27.00
|mapmarker Eversong Woods/0 29.80,24.40
|mapmarker Eversong Woods/0 31.40,29.40
|mapmarker Eversong Woods/0 32.60,25.40
|only if BloodElf Warlock
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Eversong Woods/0 31.00,27.00 |q 8345
|mapmarker Eversong Woods/0 29.80,24.40
|mapmarker Eversong Woods/0 31.40,29.40
|mapmarker Eversong Woods/0 32.60,25.40
|only if BloodElf Warlock
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Eversong Woods/0 38.23,17.60 |q 8345 |zombiewalk
|only if BloodElf Warlock
step
talk Summoner Teli'Larien##15283
|tip Inside the building.
turnin Windows to the Source##8344 |goto Eversong Woods/0 38.93,21.44
|only if BloodElf Warlock
step
talk Yasmine Teli'Larien##15494
|tip Buy available Grimoires.
|tip Inside the building.
Train Demon Abilities |vendor Yasmine Teli'Larien##15494 |goto Eversong Woods/0 38.86,21.39 |q 8330
|only if Warlock
stickystart "Kill_Tenders_And_Feral_Tenders"
step
click Solanian's Scrying Orb##180510
collect Solanian's Scrying Orb##20470 |q 8330/1 |goto Eversong Woods/0 35.13,28.91
step
label "Kill_Tenders_And_Feral_Tenders"
kill 7 Tender##15271 |q 8334/1 |goto Eversong Woods/0 34.00,27.00
kill 7 Feral Tender##15294 |q 8334/2 |goto Eversong Woods/0 34.00,27.00
|mapmarker Eversong Woods/0 29.60,20.40
|mapmarker Eversong Woods/0 31.60,23.00
|mapmarker Eversong Woods/0 32.00,20.40
|mapmarker Eversong Woods/0 32.00,25.00
|mapmarker Eversong Woods/0 34.00,24.60
|mapmarker Eversong Woods/0 36.60,29.00
step
talk Lanthan Perilon##15281
turnin Aggression##8334 |goto Eversong Woods/0 35.37,22.52
accept Felendren the Banished##8335 |goto Eversong Woods/0 35.37,22.52
step
click Shrine of Dath'Remar##180516
Read the Shrine of Dath'Remar |q 8345/1 |goto Eversong Woods/0 29.64,19.41
|only if BloodElf
step
click Scroll of Scourge Magic##180511
collect Scroll of Scourge Magic##20471 |q 8330/2 |goto Eversong Woods/0 31.33,22.74
stickystart "Accept_Tainted_Arcane_Sliver"
stickystart "Kill_Tainted_Arcane_Wraiths"
stickystart "Kill_Arcane_Wraiths"
step
Run up the ramp |goto Eversong Woods/0 32.60,25.54 < 15 |only if walking
kill Felendren the Banished##15367
|tip Top of the floating structures.
collect Felendren's Head##20799 |q 8335/3 |goto Eversong Woods/0 30.84,27.13
step
label "Accept_Tainted_Arcane_Sliver"
kill Tainted Arcane Wraith##15298+
collect Tainted Arcane Sliver##20483 |n
use Tainted Arcane Sliver##20483
accept Tainted Arcane Sliver##8338 |goto Eversong Woods/0 31.40,29.40
|mapmarker Eversong Woods/0 30.40,27.20
|only if BloodElf
step
label "Kill_Tainted_Arcane_Wraiths"
kill 2 Tainted Arcane Wraith##15298 |q 8335/2 |goto Eversong Woods/0 31.40,29.40
|tip Black ghosts.
|mapmarker Eversong Woods/0 30.40,27.20
step
label "Kill_Arcane_Wraiths"
kill 8 Arcane Wraith##15273 |q 8335/1 |goto Eversong Woods/0 31.00,27.00
|tip Purple ghosts.
|mapmarker Eversong Woods/0 29.80,24.40
|mapmarker Eversong Woods/0 31.40,29.40
|mapmarker Eversong Woods/0 32.60,25.40
step
Kill enemies
|tip Helps reach level 6 after quest turnins.
ding 5,675 |goto Eversong Woods/0 31.00,27.00
|mapmarker Eversong Woods/0 29.80,24.40
|mapmarker Eversong Woods/0 31.40,29.40
|mapmarker Eversong Woods/0 32.60,25.40
step
Allow Enemies to Kill You
|tip Can also jump off the platforms.
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Eversong Woods/0 31.00,27.00 |q 8335
|tip Purple ghosts.
|mapmarker Eversong Woods/0 29.80,24.40
|mapmarker Eversong Woods/0 31.40,29.40
|mapmarker Eversong Woods/0 32.60,25.40
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Eversong Woods/0 38.23,17.60 |q 8335 |zombiewalk
step
talk Arcanist Helion##15297
turnin Tainted Arcane Sliver##8338 |goto Eversong Woods/0 37.18,18.94
|only if BloodElf
step
talk Well Watcher Solanian##15295
|tip Up on the balcony of the building.
turnin Solanian's Belongings##8330 |goto Eversong Woods/0 38.76,19.36
turnin The Shrine of Dath'Remar##8345 |goto Eversong Woods/0 38.76,19.36
step
talk Lanthan Perilon##15281
turnin Felendren the Banished##8335 |goto Eversong Woods/0 35.37,22.52
accept Aiding the Outrunners##8347 |goto Eversong Woods/0 35.37,22.52
step
talk Outrunner Alarion##15301
turnin Aiding the Outrunners##8347 |goto Eversong Woods/0 40.42,32.21
accept Slain by the Wretched##9704 |goto Eversong Woods/0 40.42,32.21
step
clicknpc Slain Outrunner##17849
turnin Slain by the Wretched##9704 |goto Eversong Woods/0 42.02,35.65
accept Package Recovery##9705 |goto Eversong Woods/0 42.02,35.65
step
talk Outrunner Alarion##15301
turnin Package Recovery##9705 |goto Eversong Woods/0 40.42,32.21
accept Completing the Delivery##8350 |goto Eversong Woods/0 40.42,32.21
]])
ZygorGuidesViewer:RegisterGuide("Leveling Guides\\Starter Guides (1-12)\\Eversong Woods (5-10)",{
image=ZGV.IMAGESDIR.."Eversong Woods",
condition_visible=function() return BloodElf or (Undead and not Warrior) end,
linked = {"Leveling Guides\\Hidden Guides"},
linkedhidden = true,
next="Leveling Guides\\Starter Guides (1-12)\\Eversong Woods (10-12)",
},[[
step
_NOTE:_
Wrong Character Race or Class
|tip Guide written for {o}Blood Elf and non-Warrior Undead{} characters.
|tip Other races may encounter issues.
Click Here to Continue |confirm
|only if not (BloodElf or (Undead and not Warrior))
step
talk Skymistress Gloaming##16192
fpath Silvermoon City |goto Eversong Woods/0 54.37,50.73
|only if Scourge
step
Enter Falconwing Square |goto Eversong Woods/0 46.55,49.09 < 30 |only if walking and not (subzone("Falconwing Square") or subzone("Dawning Lane"))
talk Magister Jaronis##15418
accept Major Malfunction##8472 |goto Eversong Woods/0 47.26,46.31
step
talk Innkeeper Delaniel##15433
|tip Inside the building.
turnin Completing the Delivery##8350 |goto Eversong Woods/0 48.16,47.66
|only if haveq(8350) or completedq(8350)
step
talk Innkeeper Delaniel##15433
|tip Inside the building.
home Falconwing Square |goto Eversong Woods/0 48.16,47.66 |q 9315 |future
step
talk Ponaris##16276
|tip Upstairs inside the building.
accept Cleansing the Scar##9489 |goto Eversong Woods/0 47.85,47.97
|only if Priest
step
talk Ponaris##16276
|tip Upstairs inside the building.
Train Abilities |trainer Ponaris##16276 |goto Eversong Woods/0 47.85,47.97 |q 8472
|only if Priest
step
talk Garridel##16269
|tip Upstairs inside the building.
Train Abilities |trainer Garridel##16269 |goto Eversong Woods/0 48.04,48.10 |q 8472
|only if Mage
step
talk Celoenus##16266
|tip Upstairs inside the building.
Train Abilities |trainer Celoenus##16266 |goto Eversong Woods/0 48.23,47.94 |q 8472
|only if Warlock
step
talk Daestra##16267
|tip Upstairs inside the building.
Train Demon Abilities |vendor Daestra##16267 |goto Eversong Woods/0 48.34,47.95 |q 8472
|only if Warlock
step
talk Kanaria##16272
|tip Upstairs inside the building.
Learn First Aid |skillmax First Aid,75 |goto Eversong Woods/0 48.58,47.58
step
_NOTE:_
Create Bandages in Downtime
|tip While waiting for things like boats.
|tip Increases skill in First Aid.
|tip Need higher skill to make better bandages.
|tip Keep bandages to heal yourself.
Click Here to Continue |confirm |q 8472
step
click Wanted: Thaelis the Hungerer##180918
|tip Outside.
accept Wanted: Thaelis the Hungerer##8468 |goto Eversong Woods/0 48.17,46.31
step
talk Aeldon Sunbrand##15403
accept Unstable Mana Crystals##8463 |goto Eversong Woods/0 48.17,46.00
step
talk Noellene##16275
|tip Inside the building.
Train Abilities |trainer Noellene##16275 |goto Eversong Woods/0 48.40,46.46 |q 8472
|only if Paladin
step
talk Tannaria##16279
|tip Upstairs inside the building.
Train Abilities |trainer Tannaria##16279 |goto Eversong Woods/0 48.50,45.92 |q 8472
|only if Rogue
step
talk Duelist Larenis##17005
|tip Inside the building.
Train Swords |complete weaponskill("SWORD") > 0 |goto Eversong Woods/0 48.34,45.95
|only if Rogue
step
talk Hannovia##16270
|tip Inside the building.
Train Abilities |trainer Hannovia##16270 |goto Eversong Woods/0 48.27,46.06 |q 8472
|only if Hunter
stickystart "Collect_Arcane_Cores"
stickystart "Collect_Unstable_Mana_Crystals"
step
kill Thaelis the Hungerer##15949
|tip Inside the building.
collect Thaelis's Head##21781 |q 8468/1 |goto Eversong Woods/0 45.02,37.68
step
label "Collect_Arcane_Cores"
kill Arcane Patroller##15638+
|tip Metal robots.
|tip Walking on or near roads.
collect 6 Arcane Core##21808 |q 8472/1 |goto Eversong Woods/0 47.00,38.20
|mapmarker Eversong Woods/0 40.40,39.40
|mapmarker Eversong Woods/0 40.40,43.40
|mapmarker Eversong Woods/0 41.00,47.60
|mapmarker Eversong Woods/0 43.20,36.60
|mapmarker Eversong Woods/0 43.20,44.60
|mapmarker Eversong Woods/0 44.40,40.40
|mapmarker Eversong Woods/0 45.80,35.00
|mapmarker Eversong Woods/0 46.40,44.20
|mapmarker Eversong Woods/0 48.00,41.20
step
label "Collect_Unstable_Mana_Crystals"
click Unstable Mana Crystal Crate##180600+
|tip Wooden boxes.
collect 6 Unstable Mana Crystal##20743 |q 8463/1 |goto Eversong Woods/0 45.00,40.70
|mapmarker Eversong Woods/0 40.40,43.40
|mapmarker Eversong Woods/0 41.70,46.80
|mapmarker Eversong Woods/0 42.00,38.90
|mapmarker Eversong Woods/0 43.90,44.50
|mapmarker Eversong Woods/0 44.30,35.10
|mapmarker Eversong Woods/0 46.90,44.60
|mapmarker Eversong Woods/0 47.90,37.40
|mapmarker Eversong Woods/0 48.00,41.80
step
talk Magister Jaronis##15418
turnin Major Malfunction##8472 |goto Eversong Woods/0 47.26,46.31
accept Delivery to the North Sanctum##8895 |goto Eversong Woods/0 47.26,46.31
step
talk Sergeant Kan'ren##16924
turnin Wanted: Thaelis the Hungerer##8468 |goto Eversong Woods/0 47.77,46.58
step
talk Aeldon Sunbrand##15403
turnin Unstable Mana Crystals##8463 |goto Eversong Woods/0 48.17,46.00
accept Darnassian Intrusions##9352 |goto Eversong Woods/0 48.17,46.00
step
talk Ley-Keeper Caidanis##15405
turnin Delivery to the North Sanctum##8895 |goto Eversong Woods/0 44.63,53.13
accept Malfunction at the West Sanctum##9119 |goto Eversong Woods/0 44.63,53.13
step
talk Apprentice Ralen##15941
accept Roadside Ambush##9035 |goto Eversong Woods/0 45.19,56.43
step
talk Apprentice Meledor##15945
turnin Roadside Ambush##9035 |goto Eversong Woods/0 44.88,61.03
accept Soaked Pages##9062 |goto Eversong Woods/0 44.88,61.03
step
click Soaked Tome##181110
|tip Underwater.
collect Antheol's Elemental Grimoire##22414 |q 9062/1 |goto Eversong Woods/0 44.34,61.99
step
talk Apprentice Meledor##15945
turnin Soaked Pages##9062 |goto Eversong Woods/0 44.88,61.03
accept Taking the Fall##9064 |goto Eversong Woods/0 44.88,61.03
step
Bless #6# Eversong Rangers |q 9489/1 |goto Eversong Woods/0 50.32,50.97
|tip Cast {o}Power Word: Fortitude{} on Eversong Rangers.
|only if Priest
step
talk Ranger Jaela##15416
accept The Dead Scar##8475 |goto Eversong Woods/0 50.34,50.77
step
talk Skymistress Gloaming##16192
fpath Silvermoon City |goto Eversong Woods/0 54.37,50.73
step
talk Instructor Antheol##15970
turnin Taking the Fall##9064 |goto Eversong Woods/0 55.70,54.51
accept Swift Discipline##9066 |goto Eversong Woods/0 55.70,54.51
step
kill 8 Plaguebone Pillager##15654 |q 8475/1 |goto Eversong Woods/0 51.20,54.60
|mapmarker Eversong Woods/0 49.20,53.60
|mapmarker Eversong Woods/0 49.40,56.40
|mapmarker Eversong Woods/0 49.40,58.60
|mapmarker Eversong Woods/0 50.40,61.20
|mapmarker Eversong Woods/0 51.20,54.60
|mapmarker Eversong Woods/0 51.00,57.60
step
talk Ranger Jaela##15416
turnin The Dead Scar##8475 |goto Eversong Woods/0 50.34,50.77
step
talk Ley-Keeper Velania##15401
turnin Malfunction at the West Sanctum##9119 |goto Eversong Woods/0 36.70,57.44
accept Arcane Instability##8486 |goto Eversong Woods/0 36.70,57.44
stickystart "Kill_Manawraiths_And_Mana_Stalkers"
step
kill Darnassian Scout##15968+
|tip Night elves.
|tip On the hills around building.
collect Incriminating Documents##20765 |goto Eversong Woods/0 36.40,60.20 |q 8482 |future
Defeat an Intruder |q 9352/1 |goto Eversong Woods/0 36.40,60.20
|mapmarker Eversong Woods/0 34.00,61.00
|mapmarker Eversong Woods/0 34.60,58.40
step
use Incriminating Documents##20765
accept Incriminating Documents##8482
step
label "Kill_Manawraiths_And_Mana_Stalkers"
kill 5 Manawraith##15648 |q 8486/1 |goto Eversong Woods/0 36.00,57.60
kill 5 Mana Stalker##15647 |q 8486/2 |goto 36.00,57.60
|mapmarker Eversong Woods/0 33.20,61.40
|mapmarker Eversong Woods/0 34.00,59.00
|mapmarker Eversong Woods/0 34.40,56.40
|mapmarker Eversong Woods/0 36.20,61.60
|mapmarker Eversong Woods/0 36.40,59.60
step
talk Ley-Keeper Velania##15401
turnin Arcane Instability##8486 |goto Eversong Woods/0 36.70,57.44
turnin Darnassian Intrusions##9352 |goto Eversong Woods/0 36.70,57.44
step
talk Hathvelion Sungaze##15920
|tip Walks around.
accept Fish Heads, Fish Heads...##8884 |goto Eversong Woods/0 29.88,58.53
stickystart "Collect_Grimscale_Murloc_Heads"
step
kill Grimscale Forager##15670, Grimscale Seer##15950
|tip Murlocs.
collect Captain Kelisendra's Lost Rutters##21776 |n
use Captain Kelisendra's Lost Rutters##21776
accept Captain Kelisendra's Lost Rutters##8887 |goto Eversong Woods/0 27.60,57.00 |q 8887 |future
|mapmarker Eversong Woods/0 25.40,61.40
|mapmarker Eversong Woods/0 25.60,63.80
|mapmarker Eversong Woods/0 26.40,58.80
|mapmarker Eversong Woods/0 28.00,61.60
step
label "Collect_Grimscale_Murloc_Heads"
kill Grimscale Forager##15670, Grimscale Seer##15950 |notinsticky
|tip Murlocs. |notinsticky
collect 8 Grimscale Murloc Head##21757 |q 8884/1 |goto Eversong Woods/0 27.60,57.00
|mapmarker Eversong Woods/0 25.40,61.40
|mapmarker Eversong Woods/0 25.60,63.80
|mapmarker Eversong Woods/0 26.40,58.80
|mapmarker Eversong Woods/0 28.00,61.60
step
Kill enemies
|tip Helps reach level 8 after quest turnins.
ding 7,3200 |goto Eversong Woods/0 27.60,57.00
|mapmarker Eversong Woods/0 25.40,61.40
|mapmarker Eversong Woods/0 25.60,63.80
|mapmarker Eversong Woods/0 26.40,58.80
|mapmarker Eversong Woods/0 28.00,61.60
step
talk Hathvelion Sungaze##15920
|tip Walks around.
turnin Fish Heads, Fish Heads...##8884 |goto Eversong Woods/0 29.88,58.53
accept The Ring of Mmmrrrggglll##8885 |goto Eversong Woods/0 29.88,58.53
step
Allow Enemies to Kill You
|tip Must be near here.
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Eversong Woods/0 37.01,56.44 |q 8482
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Eversong Woods/0 48.02,49.55 |q 8482 |zombiewalk
step
talk Aeldon Sunbrand##15403
turnin Incriminating Documents##8482 |goto Eversong Woods/0 48.17,46.00
accept The Dwarven Spy##8483 |goto Eversong Woods/0 48.17,46.00
step
talk Ponaris##16276
|tip Upstairs inside the building.
turnin Cleansing the Scar##9489 |goto Eversong Woods/0 47.85,47.97
|only if Priest
step
talk Ponaris##16276
|tip Upstairs inside the building.
Train Abilities |trainer Ponaris##16276 |goto Eversong Woods/0 47.85,47.97 |q 8483
|only if Priest
step
talk Garridel##16269
|tip Upstairs inside the building.
Train Abilities |trainer Garridel##16269 |goto Eversong Woods/0 48.04,48.10 |q 8483
|only if Mage
step
talk Celoenus##16266
|tip Upstairs inside the building.
Train Abilities |trainer Celoenus##16266 |goto Eversong Woods/0 48.23,47.94 |q 8483
|only if Warlock
step
talk Daestra##16267
|tip Upstairs inside the building.
Train Demon Abilities |vendor Daestra##16267 |goto Eversong Woods/0 48.34,47.95 |q 8483
|only if Warlock
step
talk Noellene##16275
|tip Inside the building.
Train Abilities |trainer Noellene##16275 |goto Eversong Woods/0 48.40,46.46 |q 8483
|only if Paladin
step
talk Tannaria##16279
|tip Upstairs inside the building.
Train Abilities |trainer Tannaria##16279 |goto Eversong Woods/0 48.50,45.92 |q 8483
|only if Rogue
step
talk Hannovia##16270
|tip Inside the building.
Train Abilities |trainer Hannovia##16270 |goto Eversong Woods/0 48.27,46.06 |q 8483
|only if Hunter
step
Locate Prospector Anvilward |goto Eversong Woods/0 44.57,53.30 < 7 |c |q 8483
step
talk Prospector Anvilward##15420
Select _"I need a moment of your time, sir."_ |gossip 117955
Select _"Why... yes, of course. I've something to show you right inside this building, Mr. Anvilward."_ |gossip 117954
Begin Following Prospector Anvilward |goto Eversong Woods/0 44.57,53.30 > 10 |q 8483
step
Watch the dialogue
|tip Follow Prospector Anvilward.
|tip Upstairs inside the building.
kill Prospector Anvilward##15420
collect Prospector Anvilward's Head##20764 |q 8483/1 |goto Eversong Woods/0 44.07,53.31
step
use Antheol's Disciplinary Rod##22473
|tip On Apprentice Ralen.
Discipline Apprentice Ralen |q 9066/2 |goto Eversong Woods/0 45.19,56.43
step
use Antheol's Disciplinary Rod##22473
|tip On Apprentice Meledor.
Discipline Apprentice Meledor |q 9066/1 |goto Eversong Woods/0 44.88,61.03
step
talk Velan Brightoak##15417
accept Pelt Collection##8491 |goto Eversong Woods/0 44.72,69.63
step
talk Magistrix Landra Dawnstrider##16210
accept Saltheril's Haven##9395 |goto Eversong Woods/0 44.03,70.76
accept The Wayward Apprentice##9254 |goto Eversong Woods/0 44.03,70.76
step
talk Marniel Amberlight##15397
|tip Inside the building.
accept Ranger Sareyn##9358 |goto Eversong Woods/0 43.67,71.31
step
talk Ardeyn Riverwind##16397
|tip Inside the building.
accept The Scorched Grove##9258 |goto Eversong Woods/0 43.57,71.20
step
talk Ranger Degolien##15939
|tip Up on the balcony of the building.
accept Situation at Sunsail Anchorage##8892 |goto Eversong Woods/0 43.34,70.82
stickystart "Collect_Springpaw_Pelts"
step
talk Lord Saltheril##16144
|tip Inside the building.
turnin Saltheril's Haven##9395 |goto Eversong Woods/0 38.14,73.56
step
talk Velendris Whitemorn##15404
accept Lost Armaments##8480 |goto Eversong Woods/0 36.36,66.77
stickystop "Collect_Springpaw_Pelts"
step
talk Captain Kelisendra##15921
turnin Captain Kelisendra's Lost Rutters##8887 |goto Eversong Woods/0 36.36,66.62
accept Grimscale Pirates!##8886 |goto Eversong Woods/0 36.36,66.62
stickystart "Kill_Wretched_Enemies"
step
click Weapon Container##181107+
|tip Wooden crates.
|tip Also inside the large building.
collect 8 Sin'dorei Armaments##22413 |q 8480/1 |goto Eversong Woods/0 33.00,68.40
|mapmarker Eversong Woods/0 29.60,69.60
|mapmarker Eversong Woods/0 30.80,67.20
|mapmarker Eversong Woods/0 31.40,70.90
|mapmarker Eversong Woods/0 34.40,66.60
step
talk Velendris Whitemorn##15404
turnin Lost Armaments##8480 |goto Eversong Woods/0 36.36,66.77
accept Wretched Ringleader##9076 |goto Eversong Woods/0 36.36,66.77
step
kill Aldaron the Reckless##16294
|tip Walks around.
|tip Top of the building.
collect Aldaron's Head##22487 |q 9076/1 |goto Eversong Woods/0 32.80,69.40
step
label "Kill_Wretched_Enemies"
kill 5 Wretched Thug##15645 |q 8892/1 |goto Eversong Woods/0 32.20,70.80
kill 5 Wretched Hooligan##16162 |q 8892/2 |goto Eversong Woods/0 32.20,70.80
|mapmarker Eversong Woods/0 28.40,68.20
|mapmarker Eversong Woods/0 32.40,68.20
|mapmarker Eversong Woods/0 34.60,68.20
stickystart "Collect_Springpaw_Pelts"
stickystart "Collect_Captain_Kelisendras_Cargo"
step
kill Mmmrrrggglll##15937
|tip Larger orange murloc.
|tip Walks along the beach.
collect Ring of Mmmrrrggglll##21770 |q 8885/1 |goto Eversong Woods/0 25.00,70.20
|mapmarker Eversong Woods/0 24.00,73.20
|mapmarker Eversong Woods/0 24.40,68.20
|mapmarker Eversong Woods/0 25.40,66.40
stickystop "Collect_Springpaw_Pelts"
step
label "Collect_Captain_Kelisendras_Cargo"
kill Grimscale Murloc##15668, Grimscale Oracle##15669
|tip Murlocs.
click Captain Kelisendra's Cargo##180917+
|tip Wooden barrels.
|tip Usually next to murloc huts.
collect 6 Captain Kelisendra's Cargo##21771 |q 8886/1 |goto Eversong Woods/0 26.60,68.00
|mapmarker Eversong Woods/0 23.80,74.60
|mapmarker Eversong Woods/0 24.40,66.60
|mapmarker Eversong Woods/0 24.40,69.00
|mapmarker Eversong Woods/0 24.40,72.40
|mapmarker Eversong Woods/0 26.40,65.40
step
talk Hathvelion Sungaze##15920
|tip Walks around.
turnin The Ring of Mmmrrrggglll##8885 |goto Eversong Woods/0 29.89,58.43
stickystart "Collect_Springpaw_Pelts"
step
talk Captain Kelisendra##15921
turnin Grimscale Pirates!##8886 |goto Eversong Woods/0 36.36,66.62
step
talk Velendris Whitemorn##15404
turnin Wretched Ringleader##9076 |goto Eversong Woods/0 36.36,66.77
step
label "Collect_Springpaw_Pelts"
kill Springpaw Stalker##15651+
|tip Orange cougars.
collect 6 Springpaw Pelt##20772 |q 8491/1 |goto Eversong Woods/0 40.40,67.00
|mapmarker Eversong Woods/0 38.20,69.80
|mapmarker Eversong Woods/0 38.20,73.40
|mapmarker Eversong Woods/0 38.80,63.40
|mapmarker Eversong Woods/0 41.40,70.40
|mapmarker Eversong Woods/0 42.20,62.20
|mapmarker Eversong Woods/0 44.00,65.40
|mapmarker Eversong Woods/0 44.80,68.80
|mapmarker Eversong Woods/0 46.60,63.80
|mapmarker Eversong Woods/0 47.80,67.40
step
talk Ranger Degolien##15939
|tip Up on the balcony of the building.
turnin Situation at Sunsail Anchorage##8892 |goto Eversong Woods/0 43.34,70.82
accept Farstrider Retreat##9359 |goto Eversong Woods/0 43.34,70.82
step
talk Velan Brightoak##15417
turnin Pelt Collection##8491 |goto Eversong Woods/0 44.72,69.63
step
talk Ranger Sareyn##15942
turnin Ranger Sareyn##9358 |goto Eversong Woods/0 46.93,71.79
accept Defending Fairbreeze Village##9252 |goto Eversong Woods/0 46.93,71.79
stickystart "Kill_Rotlimb_Marauders"
step
kill 4 Darkwraith##15657 |q 9252/2 |goto Eversong Woods/0 51.80,77.80
|tip Black ghosts.
|mapmarker Eversong Woods/0 49.00,76.60
|mapmarker Eversong Woods/0 49.20,79.80
|mapmarker Eversong Woods/0 50.60,82.60
|mapmarker Eversong Woods/0 51.40,74.20
step
talk Apprentice Mirveda##15402
turnin The Wayward Apprentice##9254 |goto Eversong Woods/0 54.28,70.98
accept Corrupted Soil##8487 |goto Eversong Woods/0 54.28,70.98
step
click Tainted Soil Sample##180921+
|tip Green dirt piles.
collect 8 Tainted Soil Sample##20771 |q 8487/1 |goto Eversong Woods/0 52.40,69.70
|mapmarker Eversong Woods/0 50.40,68.90
|mapmarker Eversong Woods/0 50.70,72.90
|mapmarker Eversong Woods/0 52.40,71.80
step
talk Apprentice Mirveda##15402
turnin Corrupted Soil##8487 |goto Eversong Woods/0 54.28,70.98
step
Watch the dialogue
talk Apprentice Mirveda##15402
accept Unexpected Results##8488 |goto Eversong Woods/0 54.28,70.98
|tip You will be attacked.
step
Kill the enemies that attack
|tip Protect Apprentice Mirveda.
Protect Apprentice Mirveda |q 8488/1 |goto Eversong Woods/0 53.88,70.17
step
talk Apprentice Mirveda##15402
turnin Unexpected Results##8488 |goto Eversong Woods/0 54.28,70.98
accept Research Notes##9255 |goto Eversong Woods/0 54.28,70.98
step
label "Kill_Rotlimb_Marauders"
kill 4 Rotlimb Marauder##15658 |q 9252/1 |goto Eversong Woods/0 51.40,69.00
|tip Ghouls.
|mapmarker Eversong Woods/0 49.40,65.80
|mapmarker Eversong Woods/0 49.40,69.40
|mapmarker Eversong Woods/0 49.40,74.20
|mapmarker Eversong Woods/0 50.40,76.20
|mapmarker Eversong Woods/0 51.40,73.20
|mapmarker Eversong Woods/0 51.80,66.80
|mapmarker Eversong Woods/0 52.40,70.80
|mapmarker Eversong Woods/0 52.60,76.60
|mapmarker Eversong Woods/0 53.00,74.60
|mapmarker Eversong Woods/0 53.40,68.40
step
Kill enemies
|tip Helps reach level 10 after quest turnins.
ding 9,5725 |goto Eversong Woods/0 51.40,69.00
|mapmarker Eversong Woods/0 49.40,65.80
|mapmarker Eversong Woods/0 49.40,69.40
|mapmarker Eversong Woods/0 49.40,74.20
|mapmarker Eversong Woods/0 50.40,76.20
|mapmarker Eversong Woods/0 51.40,73.20
|mapmarker Eversong Woods/0 51.80,66.80
|mapmarker Eversong Woods/0 52.40,70.80
|mapmarker Eversong Woods/0 52.60,76.60
|mapmarker Eversong Woods/0 53.00,74.60
|mapmarker Eversong Woods/0 53.40,68.40
|only if not Scourge Warlock
step
Kill enemies
|tip Helps reach level 10 after quest turnins.
ding 9,6000 |goto Eversong Woods/0 51.40,69.00
|mapmarker Eversong Woods/0 49.40,65.80
|mapmarker Eversong Woods/0 49.40,69.40
|mapmarker Eversong Woods/0 49.40,74.20
|mapmarker Eversong Woods/0 50.40,76.20
|mapmarker Eversong Woods/0 51.40,73.20
|mapmarker Eversong Woods/0 51.80,66.80
|mapmarker Eversong Woods/0 52.40,70.80
|mapmarker Eversong Woods/0 52.60,76.60
|mapmarker Eversong Woods/0 53.00,74.60
|mapmarker Eversong Woods/0 53.40,68.40
|only if Scourge Warlock
step
talk Instructor Antheol##15970
turnin Swift Discipline##9066 |goto Eversong Woods/0 55.70,54.51
|only if Scourge Warlock
step
talk Carendin Halgar##5675
accept Creature of the Void##1473 |goto Undercity/0 85.06,25.99
|only if Scourge Warlock
step
talk Kaal Soulreaper##4563
|tip Inside the building.
Train Abilities |trainer Kaal Soulreaper##4563 |goto Undercity/0 86.21,15.93 |q 1473
|only if Scourge Warlock
step
talk Martha Strain##5753
|tip Inside the building.
Train Abilities |trainer Martha Strain##5753 |goto Undercity/0 85.70,16.08 |q 1473
|only if Scourge Warlock
step
click Perrine's Chest
|tip Inside the building.
collect Egalin's Grimoire##6285 |q 1473/1 |goto Tirisfal Glades/0 51.06,67.56
|only if Scourge Warlock
step
talk Carendin Halgar##5675
turnin Creature of the Void##1473 |goto Undercity/0 85.06,25.99
accept The Binding##1471 |goto Undercity/0 85.06,25.99
|only if Scourge Warlock
step
use Runes of Summoning##6284
kill Summoned Voidwalker##5676 |q 1471/1 |goto Undercity/0 86.64,27.05
|only if Scourge Warlock
step
talk Carendin Halgar##5675
turnin The Binding##1471 |goto Undercity/0 85.06,25.99
|only if Scourge Warlock
step
talk Aeldon Sunbrand##15403
|tip Outside.
turnin The Dwarven Spy##8483 |goto Eversong Woods/0 48.17,46.00
step
talk Ponaris##16276
|tip Upstairs inside the building.
Train Abilities |trainer Ponaris##16276 |goto Eversong Woods/0 47.85,47.97 |q 9066
|only if Priest
step
talk Garridel##16269
|tip Upstairs inside the building.
Train Abilities |trainer Garridel##16269 |goto Eversong Woods/0 48.04,48.10 |q 9066
|only if Mage
step
talk Celoenus##16266
|tip Upstairs inside the building.
Train Abilities |trainer Celoenus##16266 |goto Eversong Woods/0 48.23,47.94 |q 9066
|only if Warlock
step
talk Daestra##16267
|tip Upstairs inside the building.
Train Demon Abilities |vendor Daestra##16267 |goto Eversong Woods/0 48.34,47.95 |q 9066
|only if Warlock
step
talk Noellene##16275
|tip Inside the building.
Train Abilities |trainer Noellene##16275 |goto Eversong Woods/0 48.40,46.46 |q 9066
|only if Paladin
step
talk Tannaria##16279
|tip Upstairs inside the building.
Train Abilities |trainer Tannaria##16279 |goto Eversong Woods/0 48.50,45.92 |q 9066
|only if Rogue
step
_NOTE:_
Stronger Ammo Available
|tip Buy level 10 ammo when restocking.
Click Here to Continue |confirm |q 9066
|only if Hunter
step
talk Hannovia##16270
|tip Inside the building.
Train Abilities |trainer Hannovia##16270 |goto Eversong Woods/0 48.27,46.06 |q 9066
|only if Hunter
step
_NOTE:_
Use Weapon Stones
|tip We will train Mining and Blacksmithing.
|tip Allows you to make and use {o}Sharpening Stones{}.		|only if Rogue
|tip Allows you to make and use {o}Weightstones{}.		|only if Paladin
|tip Increases damage.
|tip Mine {o}Copper Ore{} as you see it.
|tip Use the {g}Rough Stones{} to make sharpening stones.	|only if Rogue
|tip Use the {g}Rough Stones{} to make weightstones.		|only if Paladin
Click Here to Continue |confirm |q 9066
|only if (Rogue or Paladin) and BloodElf
step
Follow the path |goto Eversong Woods/0 46.55,48.59 < 30 |only if walking and subzone("Falconwing Square")
talk Belil##16663
Train Apprentice Mining |skillmax Mining,75 |goto Silvermoon City/0 78.90,43.24
|only if Rogue or Paladin
step
talk Zelan##16664
buy Mining Pick##2901 |goto Silvermoon City/0 78.41,42.53
|only if Rogue or Paladin
step
talk Bemarrin##16669
Train Apprentice Blacksmithing |skillmax Blacksmithing,75 |goto Silvermoon City/0 79.38,38.64
|only if Rogue or Paladin
step
Follow the path |goto Eversong Woods/0 46.55,48.59 < 30 |only if walking and subzone("Falconwing Square")
Enter the building |goto Silvermoon City/0 75.65,44.91 < 15 |walk
talk Talionia##16647
|tip Downstairs inside the building.
accept The Stone##9529 |goto Silvermoon City/0 74.39,47.15
|only if BloodElf Warlock
step
Follow the path |goto Eversong Woods/0 46.55,48.59 < 30 |only if walking and subzone("Falconwing Square")
talk Instructor Antheol##15970
turnin Swift Discipline##9066 |goto Eversong Woods/0 55.70,54.51
]])
ZygorGuidesViewer:RegisterGuide("Leveling Guides\\Starter Guides (1-12)\\Eversong Woods (10-12)",{
image=ZGV.IMAGESDIR.."Eversong Woods",
condition_visible=function() return not (Warrior or Shaman) end,
linked = {"Leveling Guides\\Hidden Guides"},
linkedhidden = true,
next="Leveling Guides\\Classic (12-60)\\Ghostlands (12-20)",
},[[
step
_NOTE:_
Wrong Character Class
|tip Guide written for characters that are {o}not Warrior or Shaman{}.
|tip Other classes may encounter issues.
Click Here to Continue |confirm
|only if Warrior or Shaman
step
talk Zaedana##16651
|tip Inside the building.
Train Abilities |trainer Zaedana##16651 |goto Silvermoon City/0 57.16,18.87 |q 8476 |future
|only if Mage and not BloodElf
step
talk Ileda##16621
|tip Inside the building.
Train Two-Handed Swords |complete weaponskill("TH_SWORD") > 0 |goto Silvermoon City/0 91.24,38.75
|only if Hunter and not BloodElf
step
talk Skymistress Gloaming##16192
fpath Silvermoon City |goto Eversong Woods/0 54.37,50.73
|only if not (Undead or BloodElf)
step
talk Instructor Antheol##15970
accept Fetch!##9402 |goto Eversong Woods/0 55.70,54.51
|only if Mage
step
click Azure Phial
|tip Underwater.
collect Azure Phial##23551 |q 9402/1 |goto Eversong Woods/0 54.69,56.23
|only if Mage
step
talk Instructor Antheol##15970
turnin Fetch!##9402 |goto Eversong Woods/0 55.70,54.51
accept The Purest Water##9403 |goto Eversong Woods/0 55.70,54.51
|only if Mage
step
talk Lieutenant Dawnrunner##15399
|tip Inside the building.
turnin Farstrider Retreat##9359 |goto Eversong Woods/0 60.32,62.77	|only if haveq(9359) or completedq(9359)
accept Amani Encroachment##8476 |goto Eversong Woods/0 60.32,62.77
step
talk Lieutenant Dawnrunner##15399
|tip Inside the building.
accept Taming the Beast##9484 |goto Eversong Woods/0 60.32,62.77
|only if BloodElf Hunter
step
use Taming Rod##23697
|tip On a Crazed Dragonhawk.
|tip Orange flying beasts.
Tame a Crazed Dragonhawk |q 9484/1 |goto Eversong Woods/0 62.20,59.80
|mapmarker Eversong Woods/0 61.40,65.40
|mapmarker Eversong Woods/0 63.40,67.80
|mapmarker Eversong Woods/0 63.60,62.60
|mapmarker Eversong Woods/0 65.40,59.40
|only if BloodElf Hunter
step
talk Lieutenant Dawnrunner##15399
|tip Inside the building.
turnin Taming the Beast##9484 |goto Eversong Woods/0 60.32,62.77
accept Taming the Beast##9486 |goto Eversong Woods/0 60.32,62.77
|only if BloodElf Hunter
step
use Taming Rod##23702
|tip On an Elder Springpaw.
|tip Brown cougars.
Tame an Elder Springpaw |q 9486/1 |goto Eversong Woods/0 62.40,64.80
|mapmarker Eversong Woods/0 59.40,65.20
|mapmarker Eversong Woods/0 61.20,61.60
|mapmarker Eversong Woods/0 63.40,68.20
|mapmarker Eversong Woods/0 64.00,59.40
|mapmarker Eversong Woods/0 64.60,62.60
|mapmarker Eversong Woods/0 65.80,66.20
|only if BloodElf Hunter
step
talk Lieutenant Dawnrunner##15399
|tip Inside the building.
turnin Taming the Beast##9486 |goto Eversong Woods/0 60.32,62.77
accept Taming the Beast##9485 |goto Eversong Woods/0 60.32,62.77
|only if BloodElf Hunter
step
use Taming Rod##23703
|tip On a Mistbat.
Tame a Mistbat |q 9485/1 |goto Ghostlands/0 49.20,16.80
|mapmarker Ghostlands/0 44.40,16.20
|mapmarker Ghostlands/0 44.40,19.60
|mapmarker Ghostlands/0 46.20,11.40
|mapmarker Ghostlands/0 46.40,22.00
|mapmarker Ghostlands/0 46.40,25.00
|mapmarker Ghostlands/0 47.20,14.40
|mapmarker Ghostlands/0 48.80,19.80
|mapmarker Ghostlands/0 49.60,23.20
|mapmarker Ghostlands/0 49.80,12.40
|mapmarker Ghostlands/0 51.20,26.20
|mapmarker Ghostlands/0 52.00,15.40
|mapmarker Ghostlands/0 53.20,20.80
|mapmarker Ghostlands/0 53.20,23.80
|only if BloodElf Hunter
step
talk Skymaster Sunwing##16189
fpath Tranquillien |goto Ghostlands/0 45.42,30.53
|only if BloodElf Hunter
step
talk Lieutenant Dawnrunner##15399
|tip Inside the building.
turnin Taming the Beast##9485 |goto Eversong Woods/0 60.32,62.77
accept Beast Training##9673 |goto Eversong Woods/0 60.32,62.77
|only if BloodElf Hunter
step
talk Halthenis##16675
|tip Inside the building.
turnin Beast Training##9673 |goto Silvermoon City/0 82.18,28.13
|only if BloodElf Hunter
step
_NOTE:_
Train Your Pet
|tip Learn pet abilities from Pet Trainers.
|tip Cast {o}Beast Training{} to teach your pet.
Click Here to Continue |confirm |q 9359
|only if BloodElf Hunter
step
talk Halthenis##16675
|tip Inside the building.
Train Pet Abilities |trainer Halthenis##16675 |goto Silvermoon City/0 82.18,28.13 |q 8477
|only if BloodElf Hunter
step
talk Arathel Sunforge##15400
|tip On the platform.
accept The Spearcrafter's Hammer##8477 |goto Eversong Woods/0 59.52,62.60
step
use Azure Phial##23566
collect Filled Azure Phial##23552 |q 9403/1 |goto Eversong Woods/0 64.24,72.75
|only if Mage
stickystart "Kill_Amani_Berserkers_And_Axe_Throwers"
step
kill Spearcrafter Otembe##15408
collect Otembe's Hammer##20759 |q 8477/1 |goto Eversong Woods/0 70.10,72.28
step
talk Ven'jashi##15406
accept Zul'Marosh##8479 |goto Eversong Woods/0 70.50,72.33
step
kill Chieftain Zul'Marosh##15407
|tip Top of the building.
collect Chieftain Zul'Marosh's Head##20760 |q 8479/1 |goto Eversong Woods/0 62.51,79.68
collect Amani Invasion Plans##23249 |goto Eversong Woods/0 62.51,79.68 |q 9360 |future
step
use Amani Invasion Plans##23249
accept Amani Invasion##9360
step
talk Ven'jashi##15406
turnin Zul'Marosh##8479 |goto Eversong Woods/0 70.50,72.33
step
label "Kill_Amani_Berserkers_And_Axe_Throwers"
kill 5 Amani Berserker##15643 |q 8476/1 |goto Eversong Woods/0 69.40,74.60
kill 5 Amani Axe Thrower##15641 |q 8476/2 |goto Eversong Woods/0 69.40,74.60
|mapmarker Eversong Woods/0 61.40,81.00
|mapmarker Eversong Woods/0 62.80,76.80
|mapmarker Eversong Woods/0 63.00,79.00
|mapmarker Eversong Woods/0 70.40,72.40
step
talk Lieutenant Dawnrunner##15399
|tip Inside the building.
turnin Amani Encroachment##8476 |goto Eversong Woods/0 60.32,62.77
turnin Amani Invasion##9360 |goto Eversong Woods/0 60.32,62.77
accept Warning Fairbreeze Village##9363 |goto Eversong Woods/0 60.32,62.77
step
talk Arathel Sunforge##15400
|tip On the platform.
turnin The Spearcrafter's Hammer##8477 |goto Eversong Woods/0 59.52,62.60
step
talk Magister Duskwither##15951
|tip Up on the balcony of the building.
accept The Magister's Apprentice##8888 |goto Eversong Woods/0 60.32,61.38
step
talk Apprentice Loralthalis##15924
|tip Walks around.
turnin The Magister's Apprentice##8888 |goto Eversong Woods/0 67.81,56.51
accept Deactivating the Spire##8889 |goto Eversong Woods/0 67.81,56.51
accept Where's Wyllithen?##9394 |goto Eversong Woods/0 67.81,56.51
step
click Orb of Translocation##184500 |goto Eversong Woods/0 68.92,51.97
|tip Top of the stairs.
Teleport Up to the Building |goto Eversong Woods/0 67.49,52.11 < 7 |noway |c |q 8889
step
click Duskwither Spire Power Source##180920
|tip Large green crystal.
|tip On the floating platform.
Deactivate the First Power Source |q 8889/1 |goto Eversong Woods/0 68.95,51.93
step
click Duskwither Spire Power Source##180920
|tip Large green crystal.
|tip Further up inside the floating building.
Deactivate the Second Power Source |q 8889/2 |goto Eversong Woods/0 68.96,51.97
step
click Magister Duskwither's Journal##181011
|tip Book.
|tip Upstairs inside the floating building.
accept Abandoned Investigations##8891 |goto Eversong Woods/0 69.24,52.10
step
click Duskwither Spire Power Source##180920
|tip Large green crystal.
|tip On the floating platform.
Deactivate the Third Power Source |q 8889/3 |goto Eversong Woods/0 69.65,53.33
step
click Orb of Translocation##184500 |goto Eversong Woods/0 69.62,53.42
|tip On the floating platform.
Teleport to the Ground |goto Eversong Woods/0 68.89,52.00 < 7 |noway |c |q 8889
step
talk Groundskeeper Wyllithen##15969
turnin Where's Wyllithen?##9394 |goto Eversong Woods/0 68.71,46.95
accept Cleaning up the Grounds##8894 |goto Eversong Woods/0 68.71,46.95
step
kill 6 Mana Serpent##15966 |q 8894/1 |goto Eversong Woods/0 70.00,49.00
kill 6 Ether Fiend##15967 |q 8894/2 |goto Eversong Woods/0 70.00,49.00
|mapmarker Eversong Woods/0 67.00,47.20
|mapmarker Eversong Woods/0 67.40,51.40
|mapmarker Eversong Woods/0 68.20,55.00
|mapmarker Eversong Woods/0 68.40,44.40
step
talk Groundskeeper Wyllithen##15969
turnin Cleaning up the Grounds##8894 |goto Eversong Woods/0 68.71,46.95
step
Kill enemies
|tip Helps reach level 12 after quest turnins.
ding 11,6400 |goto Eversong Woods/0 70.00,49.00
|mapmarker Eversong Woods/0 67.00,47.20
|mapmarker Eversong Woods/0 67.40,51.40
|mapmarker Eversong Woods/0 68.20,55.00
|mapmarker Eversong Woods/0 68.40,44.40
step
talk Apprentice Loralthalis##15924
|tip Walks around.
turnin Deactivating the Spire##8889 |goto Eversong Woods/0 67.81,56.51
accept Word from the Spire##8890 |goto Eversong Woods/0 67.81,56.51
step
talk Magister Duskwither##15951
|tip Up on the balcony of the building.
turnin Word from the Spire##8890 |goto Eversong Woods/0 60.32,61.38
turnin Abandoned Investigations##8891 |goto Eversong Woods/0 60.32,61.38
step
talk Instructor Antheol##15970
turnin The Purest Water##9403 |goto Eversong Woods/0 55.70,54.51
accept Recently Living##9404 |goto Eversong Woods/0 55.70,54.51
|only if Mage
step
kill Eversong Green Keeper##15636+
|tip Small walking trees.
collect Living Branch##23553 |q 9404/1 |goto Eversong Woods/0 59.40,68.60
|mapmarker Eversong Woods/0 56.40,69.40
|mapmarker Eversong Woods/0 58.00,72.80
|mapmarker Eversong Woods/0 60.60,75.20
|mapmarker Eversong Woods/0 61.20,71.40
|only if Mage
step
talk Instructor Antheol##15970
turnin Recently Living##9404 |goto Eversong Woods/0 55.70,54.51
|only if Mage
step
talk Zaedana##16651
|tip Inside the building.
Train Abilities |trainer Zaedana##16651 |goto Silvermoon City/0 57.16,18.87 |q 9363
|only if Mage
step
talk Knight-Lord Bloodvalor##17717
|tip Inside the building.
accept The First Trial##9678 |goto Silvermoon City/0 89.26,35.20
|only if BloodElf Paladin
step
talk Ithelis##16680
|tip Inside the building.
Train Abilities |trainer Ithelis##16680 |goto Silvermoon City/0 91.18,36.93 |q 9678
|only if Paladin
step
talk Halthenis##16675
|tip Inside the building.
Train Pet Abilities |trainer Halthenis##16675 |goto Silvermoon City/0 82.19,28.14 |q 9363
|only if Hunter
step
talk Tana##16672
|tip Inside the building.
Train Abilities |trainer Tana##16672 |goto Silvermoon City/0 82.37,26.03 |q 9363
|only if Hunter
step
talk Zelanis##16684
|tip Inside the building.
accept Find Keltus Darkleaf##9532 |goto Silvermoon City/0 79.71,52.16
|only if BloodElf Rogue
step
talk Zelanis##16684
|tip Inside the building.
Train Abilities |trainer Zelanis##16684 |goto Silvermoon City/0 79.71,52.16 |q 9363
|tip Make sure to learn {o}Pick Pocket{}.
|tip Needed for a quest soon.
|only if Rogue
step
talk Torian##16649
|tip Buy available Grimoires.
|tip Downstairs inside the building.
Train Demon Abilities |vendor Torian##16649 |goto Silvermoon City/0 73.97,44.76 |q 9363
|only if Warlock
step
talk Zanien##16648
|tip Downstairs inside the building.
Train Abilities |trainer Zanien##16648 |goto Silvermoon City/0 73.05,45.27 |q 9363
|only if Warlock
step
talk Lotheolan##16659
|tip Inside the building.
Train Abilities |trainer Lotheolan##16659 |goto Silvermoon City/0 55.37,26.76 |q 9363
|only if Priest
step
talk Harene Plainwalker##16655
Train Abilities |trainer Harene Plainwalker##16655 |goto Silvermoon City/0 72.47,56.16 |q 9363
|only if Druid
step
talk Ranger Sareyn##15942
turnin Defending Fairbreeze Village##9252 |goto Eversong Woods/0 46.93,71.79
accept Runewarden Deryan##9253 |goto Eversong Woods/0 46.93,71.79
|only if haveq(9252) or completedq(9252)
step
talk Magistrix Landra Dawnstrider##16210
turnin Research Notes##9255		|goto Eversong Woods/0 44.03,70.76	|only if haveq(9255) or completedq(9255)
accept Missing in the Ghostlands##9144	|goto Eversong Woods/0 44.03,70.76
step
talk Ranger Degolien##15939
|tip Up on the balcony of the building.
turnin Warning Fairbreeze Village##9363 |goto Eversong Woods/0 43.34,70.82
step
talk Ardeyn Riverwind##16397
|tip Inside the building.
accept The Scorched Grove##9258 |goto Eversong Woods/0 43.57,71.20
step
talk Larianna Riverwind##15398
|tip Inside the building.
turnin The Scorched Grove##9258 |goto Eversong Woods/0 34.06,80.02
accept A Somber Task##8473 |goto Eversong Woods/0 34.06,80.02
stickystart "Kill_Withered_Green_Keepers"
step
kill Old Whitebark##15409
|tip Larger walking tree.
|tip Walks around.
collect Old Whitebark's Pendant##23228 |n
use Old Whitebark's Pendant##23228
accept Old Whitebark's Pendant##8474 |goto Eversong Woods/0 34.40,83.40
|mapmarker Eversong Woods/0 34.40,84.60
|mapmarker Eversong Woods/0 35.60,84.00
step
label "Kill_Withered_Green_Keepers"
kill 10 Withered Green Keeper##15637 |q 8473/1 |goto Eversong Woods/0 34.00,85.00
|tip Smaller walking trees.
|mapmarker Eversong Woods/0 31.00,86.80
|mapmarker Eversong Woods/0 31.40,83.00
|mapmarker Eversong Woods/0 33.40,80.20
|mapmarker Eversong Woods/0 35.20,88.60
|mapmarker Eversong Woods/0 36.80,80.60
|mapmarker Eversong Woods/0 37.20,83.60
|mapmarker Eversong Woods/0 38.80,88.80
|mapmarker Eversong Woods/0 40.00,85.80
|mapmarker Eversong Woods/0 40.80,81.40
step
talk Larianna Riverwind##15398
|tip Inside the building.
turnin A Somber Task##8473 |goto Eversong Woods/0 34.06,80.02
turnin Old Whitebark's Pendant##8474 |goto Eversong Woods/0 34.06,80.02
accept Whitebark's Memory##10166 |goto Eversong Woods/0 34.06,80.02
step
use Old Whitebark's Pendant##28209
kill Whitebark's Spirit##19456
|tip Becomes friendly.
talk Whitebark's Spirit##19456
turnin Whitebark's Memory##10166 |goto Eversong Woods/0 37.53,86.22
step
talk Runewarden Deryan##16362
turnin Runewarden Deryan##9253 |goto Eversong Woods/0 44.19,85.47
accept Powering our Defenses##8490 |goto Eversong Woods/0 44.19,85.47
|only if haveq(9253) or completedq(9253)
step
use Infused Crystal##22693
Kill the enemies that attack in waves
|tip Protect the Infused Crystal for {o}1 minute{}.
|tip Next to you.
Energize the Runestone |q 8490/1 |goto Eversong Woods/0 55.19,84.23
|only if haveq(8490) or completedq(8490)
step
talk Runewarden Deryan##16362
turnin Powering our Defenses##8490 |goto Eversong Woods/0 44.19,85.47
|only if haveq(8490) or completedq(8490)
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\The Barrens & Stonetalon Mountain (13-21)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Ghostlands (12-20)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\The Barrens & Stonetalon Mountains (20-22)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Ashenvale (21-22)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Hillsbrad Foothills (22-24)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\The Barrens (24-25)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Stonetalon Mountains (25-26)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Ashenvale (26-28)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Thousand Needles (28-30)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Hillsbrad Foothills (30-32)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Arathi Highlands (32-33)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Thousand Needles (33-34)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Stranglethorn Vale (34-36)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Dustwallow Marsh (36-38)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Alterac Mountains (38-39)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Arathi Highlands (39-40)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Badlands (40-42)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Dustwallow Marsh (42-43)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Stranglethorn Vale (43-46)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Tanaris (46-47)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Feralas (47-48)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Tanaris (48-49)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\The Hinterlands (49-51)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Searing Gorge (51-52)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Burning Steppes (52-53)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Un'Goro Crater (53-54)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Felwood & Winterspring (54-56)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Western & Eastern Plaguelands (56-58)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Winterspring (58-59)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (12-60)\\Silithus (59-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Hellfire Peninsula (60-61)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Zangarmarsh (61-63)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Terokkar Forest (63-64)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Nagrand (64-65)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Blade's Edge Mountains (65-67)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Netherstorm (67-69)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Shadowmoon Valley (69-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Ahn'Qiraj Gear\\Ruins of Ahn'Qiraj Cloak Quest")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Ahn'Qiraj Gear\\Ruins of Ahn'Qiraj Ring Quest")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Ahn'Qiraj Gear\\Ruins of Ahn'Qiraj Weapon Quest")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Ahn'Qiraj Gear\\Temple of Ahn'Qiraj Shoulder Quest")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Ahn'Qiraj Gear\\Temple of Ahn'Qiraj Boots Quest")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Ahn'Qiraj Gear\\Temple of Ahn'Qiraj Helm Quest")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Ahn'Qiraj Gear\\Temple of Ahn'Qiraj Legs Quest")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Ahn'Qiraj Gear\\Temple of Ahn'Qiraj Chest Quest")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Scepter of the Shifting Sands")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Ahn'Qiraj Gear\\Signet Ring of the Bronze Dragonflight")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Cenarion Battlegear")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Cenarion Field Duty Combat Assignments")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Cenarion Field Duty Tactical Assignments")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Cenarion Field Duty Logistics Assignments")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Druid Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Priest Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Warrior Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Hunter Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Mage Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Rogue Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Shaman Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Warlock Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Paladin Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Zangarmarsh Group Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Terokkar Forest Group Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Nagrand Group Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Blade's Edge Mountains Group Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Netherstorm Group Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Hellfire Peninsula Group Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Isle of Quel'danas")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Hunter Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Warrior Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Rogue Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Shaman Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Warlock Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Priest Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Mage Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Druid Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Paladin Intro")
