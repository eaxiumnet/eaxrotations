local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Alliance" then return end
if ZGV:DoMutex("DungeonACLASSIC") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\Classic\\Wailing Caverns (15-25)",{
author="support@zygorguides.com",
image=ZGV.IMAGESDIR.."Wailing Caverns",
description="This guide will walk you through the Wailing Caverns dungeon.",
lfgid=718,
},[[
step
Enter the cave |goto The Barrens 45.96,36.33 < 7 |walk
Follow the path |goto Kalimdor 51.92,55.37 < 7 |only if walking
Continue following the path |goto Kalimdor 51.98,55.21 < 7 |only if walking
Continue following the path |goto Kalimdor 51.94,54.98 < 7 |only if walking
Continue following the path |goto Kalimdor 52.27,54.63 < 7 |only if walking
Enter the Wailing Caverns dungeon with your group |goto Kalimdor 52.40,55.21 < 7 |c
step
kill Kresh##3653
|tip Kresh has no abilities, it is a simple tank and spank fight.
Click Here to Continue |confirm
step
kill Lady Anacondra##3671
|tip Interrupt her "Sleep" ability.
Click Here to Continue |confirm
step
kill Lord Cobrahn##3669
|tip After pulling, immediately kill the three Deviate Pythons before switching to Lord Cobrahn.
|tip Interrupt his "Sleep" ability.
Click Here to Continue |confirm
step
kill Deviate Faerie Dragon##5912
|tip It's located in the Winding Chasm before Lord Pythas.
|tip This is a rare mob that may not be available.
Click Here to Continue |confirm
step
kill Lord Pythas##3670
|tip Interrupt his "Sleep" ability.
|tip After pulling, CC the Druid of the Fang and kill the other add before switching to Pythas.
Click Here to Continue |confirm
step
kill Skum##3674
|tip "Chained Bolt" does damage to players near each other so melee DPS should spread out around the boss to avoid damage.
Click Here to Continue |confirm
step
kill Lord Serpentis##3673
|tip Interrupt his "Sleep" ability.
Click Here to Continue |confirm
step
kill Verdan the Everliving##5775
|tip "Grasping Vines" roots all players within 10 yards, knocks them down and does damage so the healer should try to keep the group's health topped off as much as possible.
Click Here to Continue |confirm
step
kill Mutanus the Devourer##3654
|tip Mutanus is spawned during an optional dungeon event that can occur if the four Lords of the Fang bosses have been defeated.
|tip These four bosses include Lady Anacondra, Lord Cobrahn, Lord Pythas and Lord Serpentis.
|tip The event is started by escorting the Disciple of Naralex through the dungeon.
|tip The Disciple of Naralex is found at the start of the dungeon.
|tip Once the Disciple reaches the ritual stone where Naralex sleeps, you will be attacked by waves of enemies.
|tip Mutanus' "Thunderclap" ability does high damage to the tank and any nearby melee DPS so ranged DPS is better for this fight.
|tip He also has two abilities, "Terrify" and "Naralex's Nightmare" that both stun/sleep players so the healer should try to keep the group's health topped off as much as possible.
]])
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\Classic\\The Deadmines (17-26)",{
author="support@zygorguides.com",
image=ZGV.IMAGESDIR.."Deadmines",
description="This guide will walk you through the Deadmines dungeon.",
lfgid=1581,
},[[
step
Enter the building |goto Westfall 42.56,71.74 < 5 |walk
Run up the stairs |goto Westfall 43.38,71.92 < 5 |walk
Follow the path |goto Westfall 42.90,72.68 < 5 |walk
Run down the ramp |goto Westfall 43.42,72.79 < 7 |c
step
Jump down here |goto Westfall 43.28,74.14 < 5 |walk
Follow the path |goto Westfall 42.18,75.97 < 10 |walk
Follow the path up |goto Westfall 41.27,76.15 < 10 |walk
Continue following the path |goto Eastern Kingdoms 41.04,79.66 < 10 |walk
Follow the path |goto Eastern Kingdoms 40.99,79.79 < 10 |walk
Jump down here |goto Eastern Kingdoms 40.85,79.62 < 10 |walk
Enter the Deadmines dungeon with your group |goto Eastern Kingdoms 40.69,79.58 < 7 |c
step
kill Rhahk'Zor##644
|tip Before the encounter, you can pull the 2 Defias Watchman without drawing aggro from the boss.
|tip If you cannot do this, use CC on one archer.
|tip If you can't CC, kill the adds before the boss.
|tip Be careful of patrolling elites.
Click Here to Continue |confirm
step
kill Miner Johnson##3586
|tip This is a rare mob that may not be available.
|tip He will be surrounded by Defias Miners that aren't elite.
|tip Try picking them off before engaging Miner Johnson.
|tip Click the line below if the rare spawn isn't available.
Click Here to Continue |confirm
step
kill Sneed's Shredder##642
|tip Clear the entire room before engaging Sneed's Shredder.
|tip It uses an ability called "Terrify" that will cause you to run in fear.
|tip Once the Shredder is killed, Sneed will hop out and the tank will need to pick it up quickly.
|tip It will disarm the tank so give them time to get aggro.
Click Here to Continue |confirm
step
kill Gilnid##1763
|tip A Goblin Engineer will pull when you engage him.
|tip CC the engineer, or it will summing a Remote Controlled Golem, which is immune to most abilities.
|tip If the Golem is summoned focus on the engineer.
Click Here to Continue |confirm
step
kill Mr. Smite##646
|tip When you approach the plank, he will automatically engage your group.
|tip There will be two Defias Blackguard that are stealthed.
|tip They need to die before you begin damaging Mr. Smite.
|tip At 66% and 33% he will stun the group for nearly 10 seconds.
|tip At 33% he will gain the ability to stun your tank.
|tip It will be important to keep your tank healed up.
Click Here to Continue |confirm
step
kill Captain Greenskin##647
|tip CC adds next to Captain Greenskin before pulling.
|tip Start the encounter by killing the adds, CCing as many as possible.
Click Here to Continue |confirm
step
kill Edwin VanCleef##639
|tip When you begin the encounter, there will be two Defias Blackguard that break stealth.
|tip CC and kill them before attacking Edwin VanCleef.
|tip At 50% he will summon two more adds.
|tip Repeat the process from before, killing the adds.
|tip Finish the encounter after.
Click Here to Continue |confirm
step
kill Cookie##645
|tip This is a bonus boss, on a little island below.
|tip If you want to be safe, you can clear the adds below before jumping down.
|tip Interrupt "Cookie's Cooking" spell or it heals him.
]])
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\Classic\\Shadowfang Keep (22-30)",{
author="support@zygorguides.com",
image=ZGV.IMAGESDIR.."Shadowfang Keep",
description="This guide will walk you through the Shadowfang Keep dungeon.",
lfgid=209,
},[[
step
Follow the path up |goto Silverpine Forest 47.12,69.56 < 15 |only if walking
Continue up the path |goto Silverpine Forest 47.44,67.07 < 15 |only if walking
Cross the bridge |goto Silverpine Forest 45.63,68.32 < 15 |only if walking
Enter the Shadowfang Keep dungeon with your group |goto Silverpine Forest 44.80,67.84 < 10 |c
step
kill Rethilgore##3914
|tip This is a straight forward encounter, with his only ability being "Soul Drain"
|tip It will immobilize the target and gain health while casting it.
Click Here to Continue |confirm
step
kill Shadow Charger##3865
|tip Pulling one of the 3 horses in the stable will pull all 3.
|tip Use CC on at least one of the horses if possible as they deal high damage.
|tip Focus them down one at a time.
|tip Make sure your healer is prepared for the enounter before starting.
Click Here to Continue |confirm
step
kill Razorclaw the Butcher##3886
|tip Clear the room before starting the encounter.
|tip The fight itself is a simple enough.
Click Here to Continue |confirm
step
kill Baron Silverlaine##3887
|tip Healers will need to watch for the "Veil of Shadow" ability when it is cast.
|tip If you have a hybrid class in your group, support the healer when this ability goes off.
|tip Veil of Shadows will reduce incoming healing by 75%.
Click Here to Continue |confirm
step
kill Commander Springvale##4278
|tip This encounter starts with two adds.
|tip Start by focus DPSing the Haunted Servitor.
|tip You can either kill the Wailing Guardsman next, or have a Warlock or Hunter pet Off-tank it.
Click Here to Continue |confirm
step
kill Odo the Blindwatcher##4279
|tip This encounter starts with two adds.
|tip They have the "Disarm" and "Cleave" abilities, so be sure to keep them away from the group as a tank.
|tip You can use CC or focus DPS them down quickly.
Click Here to Continue |confirm
step
kill Deathsworn Captain##3872
|tip This is a rare mob that may not be available.
|tip The tank should keep this boss 10 yards away from the group to avoid the AoE Silence it uses.
Click Here to Continue |confirm
step
kill Fenrus the Devourer##4274
|tip This boss has a dot ability and is otherwise simple.
Click Here to Continue |confirm
step
kill Wolf Master Nados##3927
|tip In the he room where this encounter takes place, there are 4 adds that should be killed beforehand.
|tip During the fight, he will summon additional Worg that should be killed.
Click Here to Continue |confirm
step
kill Archmage Arugal##4275
|tip For this encounter, you will want to have ranged DPS and Healers stand at the platform you entered the room in.
|tip As the encounter progresses, Arugal will teleport around the room.
|tip His standard attack, "Shadow Bolt" hits very hard.
Click Here to Continue |confirm
]])
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\Classic\\The Stockade (22-30)",{
author="support@zygorguides.com",
image=ZGV.IMAGESDIR.."The Stockade",
description="This guide will walk you through The Stockade dungeon.",
lfgid=717,
},[[
step
Enter the building |goto Stormwind City 42.21,58.80 < 10 |walk
Enter The Stockade dungeon with your group |goto Stormwind City 39.79,54.22 < 10 |c
step
kill Targorr the Dread##1696
|tip There will be Defias enemies surrounding him in the room.
|tip Use CC on the Defias before the encounter.
|tip DPS should focus on the adds before engaging Targorr the Dread.
|tip Finish off the CC'd adds after killing the boss.
Click Here to Continue |confirm
step
kill Kam Deepfury##1666
|tip There will be Defias enemies surrounding him in the room.
|tip Use CC on the Defias before the encounter.
|tip DPS should focus on the adds before engaging Kam Deepfury.
|tip Finish off the CC'd adds after killing the boss.
Click Here to Continue |confirm
step
kill Hamhock##1717
|tip There will be two Defias enemies along side Hamhock.
|tip Use CC on them if possible before starting the enounter.
|tip All DPS should focus on killing a single add at a time before switching to Hamhock.
|tip Hamhock will cast "Chain Lightning" which will deal heavy damage to bunched up allies, so spread out as best as possible.
Click Here to Continue |confirm
step
kill Bazil Thredd##1716
|tip It will be important to keep the tank topped off during this encounter.
|tip His "Smoke Bomb" ability will stun the group for 4 seconds upon use.
|tip Bazil Thredd deals high amounts of single target damage.
Click Here to Continue |confirm
step
kill Dextren Ward##1663
|tip His "Intimidating Shout" ability will cause your group to run in fear.
|tip It is important to clear any area around him before engaging.
|tip If you pull extra adds during the fear, be sure to use CC abilities on them as best you can.
|tip DPS should focus down Dextren Ward as soon as possible.
Click Here to Continue |confirm
step
kill Bruegal Ironknuckle##1720
|tip This is a rare mob that may not be available.
|tip Clear adds before engaging him and kill the boss.
Click Here to Continue |confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Blackfathom Deeps (24-32)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Gnomeregan (29-38)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Razorfen Kraul (30-40)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Scarlet Monastery (Graveyard) (29-35)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Scarlet Monastery (Library) (31-37)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Scarlet Monastery (Armory) (35-40)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Scarlet Monastery (Cathedral) (36-42)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Razorfen Downs (37-43)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Uldaman (42-52)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Zul'Farrak (44-49)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Maraudon (Wicked Grotto - Purple) (45-53)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Maraudon (Foulspore Cavern - Orange) (45-53)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Maraudon (Poison Falls - Inner) (48-57)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Maraudon (Earth Song Falls - Inner) (48-57)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\The Temple of Atal'Hakkar (50-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Blackrock Depths (52-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Scholomance (58-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Stratholme - Live (58-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Stratholme - Undead (58-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Dire Maul East (58-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Dire Maul North (58-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Dire Maul West (58-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Dire Maul North Tribute (58-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Lower Blackrock Spire (55-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Upper Blackrock Spire (55-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Wailing Caverns Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\The Deadmines Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Blackfathom Deeps Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\The Stockade Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Gnomeregan Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Razorfen Kraul Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Scarlet Monastery Library Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Scarlet Monastery Armory Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Scarlet Monastery Cathedral Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Razorfen Downs Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Uldaman Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Zul'Farrak Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Maraudon Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Temple of Atal'Hakkar Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Blackrock Depths Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Dire Maul East Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Dire Maul West Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Dire Maul North Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Lower Blackrock Spire Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Scholomance Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Stratholme - Live Side Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Stratholme - Undead Side Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Upper Blackrock Spire Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Raid Attunements\\Blackwing Lair Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Raid Attunements\\Molten Core Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Raid Attunements\\Onyxia's Lair Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic\\Raid Attunements\\Naxxramas Attunement")
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\The Burning Crusade\\Hellfire Ramparts (60-70)",{
author="support@zygorguides.com",
description="This guide will walk you through the Hellfire Ramparts dungeon.",
},[[
step
Follow the path |goto Hellfire Peninsula/0 48.85,55.53 < 15 |only if walking
Run into the portal |goto Hellfire Peninsula/0 47.60,53.59
Enter the Hellfire Ramparts Dungeon |goto Hellfire Ramparts/0 0.00,0.00 |c |noway
step
kill Watchkeeper Gargolmar##17306
|tip Either CC the Hellfire Watchers or kill them first.
|tip Interrupt "Heal" when cast by Hellfire Watchers.
|tip Dispel "Renew" from Watchkeeper Gargolmar or Hellfire Watchers.
|tip DPS should stack behind the boss and ranged should spread out to avoid extra "Surge" damage.
|tip While "Retalliation" is active on Gargolmar, do not melee attack him from the front.
Click Here to Continue |confirm
step
kill Omor the Unscarred##17308
|tip Avoid standing near allies if afflicted by "Treacherous Aura."
|tip Kill Fiendish Hounds quickly when they spawn.
|tip Avoid using cooldowns when Omor is at low health or "Demonic Shield" with reduce your damage.
Click Here to Continue |confirm
step
kill Vazruden##17537
|tip Quickly kill Vazruden when he reaches 50% health before Nazan lands.
|tip If Nazan lands, "Vazruden's Mark" will cause the target to gain threat until Vazruden dies.
kill Nazan##17536
|tip Nazan will fly around casting fireballs on the ground until Vazruden reaches 50% health.
|tip Avoid standing in fire patches throughout the fight.
|tip DPS and the healer should avoid standing in front of Nazan.
|tip "Bellowing Roar" will fear the entire party.
Click Here to Continue |confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Blood Furnace (61-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Slave Pens (62-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Underbog (63-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Mana-Tombs (64-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Auchenai Crypts (65-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Sethekk Halls (67-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Old Hillsbrad Foothills (66-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Black Morass (68-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Mechanar (70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Shattered Halls (70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Steamvault (70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Shadow Labyrinth (70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Arcatraz (70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Botanica (70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Magisters' Terrace (70)")
ZGV.BETASTART()
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Slave Pens Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Underbog Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Mana-Tombs Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Old Hillsbrad Foothills Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Black Morass Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Mechanar Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Steamvault Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Arcatraz Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Botanica Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Hellfire Ramparts Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Blood Furnace Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Shattered Halls Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Auchenai Crypts Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Sethekk Halls Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Shadow Labyrinth Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\The Cipher of Damnation")
ZGV.BETAEND()
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Karazhan Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Hellfire Citadel Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Serpentshrine Cavern Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Tempest Keep Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Mount Hyjal Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade\\Black Temple Attunement")
