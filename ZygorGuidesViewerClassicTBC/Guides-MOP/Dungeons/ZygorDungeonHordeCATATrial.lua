local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Horde" then return end
if ZGV:DoMutex("DungeonH") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\Classic Dungeons\\Ragefire Chasm (13-18)",{
mopready=true,
image=ZGV.IMAGESDIR.."Ragefire Chasm",
description="This guide will walk you through the Ragefire Chasm dungeon.",
lfgid=2437,
},[[
step
Enter the Ragefire Chasm Dungeon with Your Group |goto Ragefire Chasm/1 0.00,0.00 < 500 |c
step
kill Oggleflint##11517
|tip Oggleflint has two guards so CC one before pulling, if able.
|tip The tank should keep him facing away from the rest of the group to avoid his "Cleave" ability.
|tip Kill the adds and then focus on killing Oggleflint.
Click Here to Continue |confirm
step
kill Taragaman the Hungerer##11520
|tip The tank should keep him away from the edges of the platform to avoid being knocked into the lava from his "Uppercut" ability.
|tip The healer and DPS should stay as far away as possible to avoid damage from his "Fire Nova" ability, if possible.
Click Here to Continue |confirm
step
kill Jergosh the Invoker##11518
|tip Jergosh has two guards with him so CC one before pulling, if able.
|tip Kill the adds and then focus on killing Jergosh.
Click Here to Continue |confirm
step
kill Bazzalan##11519
|tip The Searing Blade Cultist to the right of the boss can be pulled by itself and should be killed before pulling the boss.
|tip CC the second Searing Blade Cultist and then focus on kill Bazzalan.
]])
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\Classic Dungeons\\Wailing Caverns (15-25)",{
mopready=true,
image=ZGV.IMAGESDIR.."Wailing Caverns",
description="This guide will walk you through the Wailing Caverns dungeon.",
lfgid=718,
},[[
step
Enter the Wailing Caverns Dungeon with Your Group |goto Wailing Caverns/1 0.00,0.00 < 500 |c
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
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\Classic Dungeons\\The Deadmines (17-26)",{
mopready=true,
image=ZGV.IMAGESDIR.."Deadmines",
description="This guide will walk you through the Deadmines dungeon.",
lfgid=1581,
},[[
step
Enter the building |goto Westfall/0 42.57,71.83 < 5 |walk
Jump down here |goto Westfall/0 43.42,72.89 < 5 |walk
Follow the path |goto Westfall/0 42.40,75.87 < 10 |walk
Follow the path |goto Westfall/0 41.79,78.54 < 10 |walk
Jump down here |goto Westfall/0 39.64,78.12 < 10 |walk
Enter the Deadmines Dungeon with Your Group |goto The Deadmines/1 0.00,0.00 < 500 |c
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
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\Classic Dungeons\\Shadowfang Keep (22-30)",{
mopready=true,
image=ZGV.IMAGESDIR.."Shadowfang Keep",
description="This guide will walk you through the Shadowfang Keep dungeon.",
lfgid=209,
},[[
step
Enter the Shadowfang Keep Dungeon with Your Group |goto Shadowfang Keep/1 0.00,0.00 < 500 |c
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
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Blackfathom Deeps (24-32)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Gnomeregan (29-38)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Razorfen Kraul (30-40)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Scarlet Monastery (Graveyard) (29-35)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Scarlet Monastery (Library) (31-37)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Scarlet Monastery (Armory) (35-40)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Scarlet Monastery (Cathedral) (36-42)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Razorfen Downs (37-43)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Uldaman (42-52)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Zul'Farrak (44-49)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Maraudon (Wicked Grotto - Purple) (45-53)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Maraudon (Foulspore Cavern - Orange) (45-53)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Maraudon (Poison Falls - Inner) (48-57)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Maraudon (Earth Song Falls - Inner) (48-57)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\The Temple of Atal'Hakkar (50-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Blackrock Depths (52-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Scholomance (58-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Stratholme - Live (58-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Stratholme - Undead (58-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Dire Maul East (58-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Dire Maul North (58-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Dire Maul North Tribute (58-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Dire Maul West (58-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Lower Blackrock Spire (55-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Upper Blackrock Spire (55-60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Ragefire Chasm Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Wailing Caverns Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Shadowfang Keep Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Blackfathom Deeps Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Gnomeregan Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Razorfen Kraul Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Scarlet Monastery Graveyard Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Scarlet Monastery Library Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Scarlet Monastery Armory Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Scarlet Monastery Cathedral Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Razorfen Downs Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Uldaman Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Zul'Farrak Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Maraudon Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Temple of Atal'Hakkar Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Blackrock Depths Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Dire Maul East Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Dire Maul West Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Dire Maul North Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Lower Blackrock Spire Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Scholomance Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Stratholme - Live Side Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Stratholme - Undead Side Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Dungeons\\Upper Blackrock Spire Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Raids\\Blackwing Lair")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Raids\\Molten Core")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Raids\\Ruins of Ahn'Qiraj")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Raids\\Temple of Ahn'Qiraj")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Raids\\Onyxia's Lair (60)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Raids\\Raid Attunements\\Blackwing Lair Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Raids\\Raid Attunements\\Molten Core Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Classic Raids\\Raid Attunements\\Naxxramas Attunement")
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\The Burning Crusade Dungeons\\Hellfire Ramparts (60-70)",{
mopready=true,
description="This guide will walk you through the Hellfire Ramparts dungeon.",
},[[
step
Follow the path |goto Hellfire Peninsula/0 48.72,48.33 < 15 |only if walking
Follow the path down |goto Hellfire Peninsula/0 48.55,51.47 < 15 |only if walking
Run into the portal |goto Hellfire Peninsula/0 47.60,53.59
Enter the Hellfire Ramparts Dungeon |goto Hellfire Ramparts/1 0.00,0.00 |c |noway
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
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Blood Furnace (61-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Slave Pens (62-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Underbog (63-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Mana-Tombs (64-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Auchenai Crypts (65-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Sethekk Halls (67-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Old Hillsbrad Foothills (66-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Black Morass (68-70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Mechanar (70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Shattered Halls (70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Steamvault (70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Shadow Labyrinth (70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Arcatraz (70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Botanica (70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Magisters' Terrace (70)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Raids\\Black Temple")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Raids\\The Eye")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Raids\\Gruul's Lair")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Raids\\Hyjal Summit (Battle for Mount Hyjal)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Raids\\Karazhan")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Raids\\Magtheridon's Lair")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Raids\\Serpentshrine Cavern")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Raids\\Sunwell Plateau")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Hellfire Ramparts Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Blood Furnace Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Slave Pens Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Underbog Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Mana-Tombs Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Auchenai Crypts Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Sethekk Halls Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Old Hillsbrad Foothills Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Black Morass Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Mechanar Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Shattered Halls Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Steamvault Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Shadow Labyrinth Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Arcatraz Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Botanica Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\The Cipher of Damnation")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Karazhan Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Hellfire Citadel Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Serpentshrine Cavern Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Tempest Keep Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Mount Hyjal Attunement")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\The Burning Crusade Dungeons\\Black Temple Attunement")
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\Wrath of the Lich King Dungeons\\Utgarde Keep (69-72)",{
mopready=true,
description="This guide will walk you through completing Utgarde Keep.",
},[[
step
kill Prince Keleseth##23953
|tip He will use "Frost Tomb" on random party members, stunning them for 20 seconds as well as dealing frost damage.
|tip Prioritize breaking players from Frost Tomb.
|tip Around 5 "Vrykul Skeletons" will spawn in at random.
|tip Group them together when they die as they will continuously get up during the fight.
|tip Group up in front of the tank so that adds are easily controlled as well as to easily manage Frost Tomb.
Click Here to Continue |confirm
step
kill Skarvald the Constructor##24200
kill Dalronn##24201
|tip He deals steady, moderate dps.
|tip During the encounter, he will randomly "Intercept" players not at the top of the threat list.
|tip It deals high damage then knocks the target down.
|tip Dalronn is highly resistant to magical damage.
|tip The goal is to have both of them die at the same time.
|tip If not, kill Dalronn first as his aggro table is more random than Skarvald when they become ghosts.
|tip If you kill Skarvald first, group together tightly so that he doesn't charge around.
Click Here to Continue |confirm
step
kill Ingvar the Plunderer##23954
|tip Melee need to stay behind him at all times.
|tip Players need to move out of the "Shadow Axe".
|tip During "Dark Smash" all players need to LoS behind pillars.
|tip Casters be on the look out for "Dreadful Roar" as it will interrupt spells.
Click Here to Continue |confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Azjol-Nerub (72-74)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Ahn'kahet: The Old Kingdom (73-75)")
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\Wrath of the Lich King Dungeons\\The Nexus (69-73)",{
mopready=true,
description="This guide will walk you through completing The Nexus.",
},[[
step
kill Grand Magus Telestra##26731
|tip During the first phase, she will cast "Firebomb" which will deal AoE damage around the initial target.
|tip She will cast "Gravity Well" which will draw anyone within 60 yards towards her.
|tip Finally she will also use "Ice Nova" which will stun anyone hit by it for 3 seconds.
|tip At 50% she will split into 3 clones.
|tip Use CC on 2 of them if possible.
|tip If you have no CC, kill the Frost, Fire then Arcane Magus.
|tip Once the clones are dealt with, she will reappear, using the 3 abilities before the cloning.
|tip At 25%, she will freeze the part and cast "Fireball Volley", so make sure the group is as topped off on health as possible.
Click Here to Continue |confirm
step
kill Anomalus##26763
|tip During the encounter at 75%, 50% and 25% he will summon a "Chaotic Rift".
|tip This will summon "Crazed Mana-Wraiths" which deal ranged damage.
|tip The DPS target priority should be: Chaotic Rifts, Crazed Mana-Wraiths, Anomalus.
|tip Kill adds and burn Anomalus as fast as possible.
Click Here to Continue |confirm
step
kill Ormorok the Tree-Shaper##26794
|tip He will use "Crystal Spikes" that will spread out from him.
|tip Avoid the spikes and dps the boss down.
Click Here to Continue |confirm
step
kill Keristrasza##26723
|tip During the encounter, it is important to always jump or move to avoid the affects of "Intense Cold".
|tip Avoid being behind her due to "Tail Sweep", which deals damage and knocking you back.
|tip She will cast "Crystal Chains", which renders the target immobile.
|tip It can be removed by anything that can remove Magic.
|tip Avoid attacking from the front as she uses "Crystalfire Breath" which will deal a lot of damage and slow you.
|tip
Click Here to Continue |confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Violet Hold (75-77)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Drak'Tharon Keep (74-76)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Gundrak (76-78)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Halls of Stone (77-79)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Halls of Lightning (78-80)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\The Culling of Stratholme (78-80)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\The Oculus (79-80)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Utgarde Pinnacle (79-80)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Ulduar (10)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Ulduar (25)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Trial of the Champion")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Onyxia's Lair (80)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Trial of the Crusader")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Forge of Souls")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Pit of Saron")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Halls of Reflection")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Raids\\The Eye of Eternity")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Raids\\Naxxramas")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Raids\\The Obsidian Sanctum")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Raids\\Onyxia's Lair")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Raids\\Trial of the Crusader")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Raids\\Trial of the Grand Crusader")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Raids\\Ulduar")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Raids\\Vault of Archavon")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Raids\\Icecrown Citadel (10)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Raids\\Icecrown Citadel (25)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Raids\\The Ruby Sanctum")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Utgarde Keep Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Utgarde Pinnacle Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\The Nexus Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Azjol-Nerub Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Ahn'kahet: The Old Kingdom Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\The Violet Hold Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Drak'Tharon Keep Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Gundrak Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Halls of Stone Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Halls of Lightning Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\The Culling of Stratholme Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\The Oculus Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Forge of Souls Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Pit of Saron Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Wrath of the Lich King Dungeons\\Halls of Reflection Quests")
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\Cataclysm Dungeons\\Blackrock Caverns",{
mopready=true,
mapid=283,
achieveid={4833},
patch='40003',
condition_suggested=function() return level>=30 and level<=35 end,
keywords={"Searing, Gorge, Burning, Steppes, BRM, BRC"},
description="This guide will walk you through the Blackrock Caverns dungeon.",
},[[
step
label "lfg"
Press _I_ and queue for Blackrock Caverns or enter the dungeon with your group |goto Blackrock Caverns/1 32.40,69.90 < 100 |c
step
talk Finkle Einhorn##49476
accept To the Chamber of Incineration!##28735 |goto Blackrock Caverns,33.10,66.00
step
Clear the trash around this area without pulling the boss |goto Blackrock Caverns 49.30,74.10
|tip Rom'ogg Bonecrusher patrols nearby.
|tip if you aggro him, he will do a shout attracting the nearby groups.
|tip
Click Here to Continue |confirm
step
kill Rom'ogg Bonecrusher##39665 |only if not haveq(28735)
kill Rom'ogg Bonecrusher##39665 |q 28735/1 |only if haveq(28735) |or
_EVERYONE:_ |grouprole EVERYONE
|tip He will use "Call for Help" as soon as he aggro's, drawing all nearby enemies to him. |grouprole EVERYONE
|tip Move out of "Quake" when it's cast, indnicated by a dust cloud under the targets feet. |grouprole EVERYONE
|tip At 66% and 33%, he will use "Chains of Woe" which draws all players to Rom'ogg, immobilizing them. |grouprole EVERYONE
|tip Destroy the chains as fast as possible, as he follows up with "The Skullcracker" which will kill you. |grouprole EVERYONE
|tip
_HEALER:_ |grouprole HEALER
|tip Healing will be reduced by 25% to players afflicted by "Wounding Strike". |grouprole HEALER
|tip
_TANK:_ |grouprole TANK |only if heroic_dung()
|tip Pick up "Angered Earth" after each Quake cast. |grouprole TANK |only if heroic_dung()
|tip There will be one per living player. |grouprole TANK |only if heroic_dung()
|tip |only if heroic_dung()
Click Here to Continue |confirm |or
step
_Click the Quest Complete Box:_
turnin To the Chamber of Incineration!##28735
step
map Blackrock Caverns/1
path follow strict;loop off;ants straight
path	50.10,55.20	50.10,39.20	53.90,21.50
Follow the path
|tip Opening the world map will display an ant trail guiding you through the current floor.
|tip
Click Here to Continue |confirm
step
accept What Is This Place?##28737 |goto Blackrock Caverns/1 53.90,21.50
step
kill Evolved Twilight Zealot##39987
|tip They patrol around this area.
|tip Interrupt "Shadow Stike" when possible.
|tip
Click Here to Continue |confirm |goto Blackrock Caverns/1 54.00,20.40
step
Jump Down the Ledge Here |goto Blackrock Caverns/1 51.90,20.00 < 5
|tip
Click Here to Continue |confirm
step
kill Evolved Twilight Zealot##39987
|tip There will be a group of 5 patrolling the hallway here.
|tip Once they are defeated, there will be another Evolved Twilight Zealot on the ramp.
|tip Interrupt "Shadow Stike" when possible.
[Blackrock Caverns/1 30.30,16.60]
[29.60,14]
|tip
Click Here to Continue |confirm
step
kill Corla Herald of Twilight##39679 |goto Blackrock Caverns/1 27.40,16.60 |only if not haveq(28737)
kill Corla Herald of Twilight##39679 |goto Blackrock Caverns/1 27.40,16.60 |q 28737/1 |or |only if haveq(28737)
_EVERYONE:_ |grouprole EVERYONE
|tip Have healers and Ranged DPS interrupt the 2 beams Corla channels to the Twilight Zealots. |grouprole EVERYONE
|tip This is accomplished by standing between Corla and her target, absorbing the beam yoruself. |grouprole EVERYONE
|tip Players interrupting will gain stacks of "Evolution". |grouprole EVERYONE
|tip When a player reaches 80 stacks of Evolution, swap out with another. |grouprole EVERYONE
|tip Don't allow the Evolution to reach 100 stacks or the player will attack the group. |grouprole EVERYONE
|tip "Dark Command" will cause 30,000 Shadow damage to the target and cause them to flee. |grouprole EVERYONE
|tip Set up an interrupt rotation for this ability. |grouprole EVERYONE
|tip |grouprole EVERYONE
Click Here to Continue |confirm |or
step
_Click the Quest Complete Box:_
turnin What Is This Place?##28737
step
map Blackrock Caverns/1
path follow strict;loop off;ants straight
path	34.20,13.30	37.50,13.20	39.20,16.00
Follow the path
|tip Hug the wall, following the way points.
|tip There will be trash at the last waypoint.
|tip Opening the world map will display an ant trail guiding you through the current floor.
|tip
Click Here to Continue |confirm
step
map Blackrock Caverns/1
path follow strict;loop off;ants straight
path	38.70,25.10	38.60,30.10	43.60,30.50
path	43.70,37.80	43.40,50.10	43.50,57.00
Follow the path
|tip Opening the world map will display an ant trail guiding you through the current floor.
|tip
Click Here to Continue |confirm
step
accept The Twilight Forge##28738 |goto Blackrock Caverns/1 43.50,57.70
step
kill Conflagration##39994+
|tip There will be 2 fire elementals patrolling around the room with Karsh Steelbender.
|tip Pull one at a time back to the ramp.
|tip
Click Here to Continue |confirm
step
kill Karsh Steelbender##39698 |only if not haveq(28738) |goto Blackrock Caverns/1 45.60,65.60
kill Karsh Steelbender##39698 |q 28738/1 |only if haveq(28738) |goto Blackrock Caverns/1 45.60,65.60 |or
_EVERYONE:_ |grouprole EVERYONE
|tip There's a lava vent at the center of the arena. |grouprole EVERYONE
|tip Dragon Karsh Steelbender will have "Quicksilver Armor" active at the start of the battle. |grouprole EVERYONE
|tip While active, he will take 99% less damage. |grouprole EVERYONE
|tip
_HEALER:_ |grouprole HEALER
|tip When pulled through the lava at the center of the arena, he will gain the "Heat Wave" ability. |grouprole HEALER
|tip This will deal AoE fire damage every 5 seconds. |grouprole HEALER
|tip He will also gain the "Burning Metal" ability while debuffed by Superheated Quicksilver Armor, dealing more fire damage to his target with each hit. |grouprole HEALER
_TANK:_ |grouprole TANK
|tip Drag Karsh Steelbender through lava to change the Quicksilver Armor buff to a "Superheated Quicksilver Armor" debuff. |grouprole TANK
|tip When the debuff has 5 seconds left, drag Karsh through the lava again. |grouprole TANK
|tip
Click Here to Continue |confirm |or
step
_Click the Quest Complete Box:_
turnin The Twilight Forge##28738
step
map Blackrock Caverns/1
path follow strict;loop off;ants straight
path	53.50,67.20	55.70,68.30	58.50,64.90	61.60,71.80
Follow the path
|tip Kill trash at each of the waypoints.
|tip If there are Earth Ragers in the pack, the group should huddle together.
|tip Hug the wall to the left as you progress.
|tip Opening the world map will display an ant trail guiding you through the current floor.
|tip
Click Here to Continue |confirm
step
_Click the Quest Complete Box:_
accept Do My Eyes Deceive Me?##28740 |goto Blackrock Caverns/1 66.10,71.60
step
kill Lucky##40008 |n |goto Blackrock Caverns/1 66.30,77.50
kill Buster##40013 |n |goto Blackrock Caverns/1 66.30,77.50
kill Spot##40011 |n |goto Blackrock Caverns/1 66.30,77.50
|tip There will be 3 Corehound Pups.
|tip You can pull them without pulling the boss behind them.
Click Here to Continue |confirm
|only if not heroic_dung()
step
kill Beauty##39700 |only if not haveq(28740)
kill Beauty##39700 |q 28740/1 |only if haveq(28740)
_EVERYONE:_ |grouprole EVERYONE
|tip "Terrifying Roar" will fear the entire group. |grouprole EVERYONE
|tip Use Tremor Totem or Fear Ward to negate this if applicable. |grouprole EVERYONE
|tip "Berserker Charge" targets the player furthers away from her, dealing damage and knocking them back. |grouprole EVERYONE
|tip "Flame Break" will deal fire damage to nearby players as well as knocking them back. |grouprole EVERYONE
|tip "Magma Spit" targets random players, leaving a DoT on them and dealing AoE damage around the target. |grouprole EVERYONE
|tip
Click Here to Continue |confirm |only if not haveq(28740)
|only if not heroic_dung()
step
kill Beauty##39700 |only if not haveq(28740)
kill Beauty##39700 |q 28740/1 |only if haveq(28740)
_EVERYONE:_ |grouprole EVERYONE
|tip Don't kill Runty or Beauty will enrage. |grouprole EVERYONE
|tip Establish crowd control for the pups. |grouprole EVERYONE
|tip "Terrifying Roar" will fear the entire group. |grouprole EVERYONE
|tip Use Tremor Totem or Fear Ward to negate this if applicable. |grouprole EVERYONE
|tip "Berserker Charge" targets the player furthers away from her, dealing damage and knocking them back. |grouprole EVERYONE
|tip "Flame Break" will deal fire damage to nearby players as well as knocking them back. |grouprole EVERYONE
|tip "Magma Spit" targets random players, leaving a DoT on them and dealing AoE damage around the target. |grouprole EVERYONE
|tip
Click Here to Continue |confirm |only if not haveq(28740)
|only if heroic_dung()
step
_Click the Quest Complete Box:_
turnin Do My Eyes Deceive Me?##28740
step
Watch for the Elemental Patrol |goto Blackrock Caverns/1 69.60,72.20
Click Here to Continue |confirm
step
_Click the Quest Complete Box:_
accept Ascendant Lord Obsidius##28741 |goto Blackrock Caverns/1 70.00,63.40
step
kill Ascendant Lord Obsidius##39705 |goto Blackrock Caverns/1 68.80,56.00 |only if not haveq(28741)
kill Ascendant Lord Obsidius##39705 |goto Blackrock Caverns/1 68.80,56.00 |q 28741/1 |only if haveq(28741)
_EVERYONE:_ |grouprole EVERYONE
|tip For "Shadow of Obsidius", they attack whoever last hit them. |grouprole EVERYONE
|tip There will be 3 of them. |grouprole EVERYONE |only if heroic_dung()
|tip They will apply "Crepuscular Veil" to whoever they get near, reducing their healing recieved. |grouprole EVERYONE
|tip When Raz is defeated, Obsidius will activate. |grouprole EVERYONE
|tip He wilil swap places with one of the Shadow of Obsidius at 66% and 33%. |grouprole EVERYONE
|tip Anyone in melee range of Obsidius may be afflicted by "Thunderclap" having their movement speed slowed. |grouprole EVERYONE
|tip
_HEALER:_ |grouprole HEALER
|tip Keep an eye on the player designated to kite Shadow of Obsidius, dispelling "Thunderstrike" if they get hit by it. |grouprole HEALER
|tip Dispel "Twilight Corruption" when applicable. |grouprole HEALER
|tip
_DAMAGE:_ |grouprole DAMAGE
|tip DPS with high mobility or dots should control the "Shadow of Obsidius" clones during the encounter. |grouprole DAMAGE
|tip If you're designated to kite the Shadows, avoid being within melee range of Obsidius. |grouprole DAMAGE
|tip
Click Here to Continue |confirm
step
talk Finkle Einhorn##49476
turnin Ascendant Lord Obsidius##28741 |goto Blackrock Caverns/1 68.80,56.00
|only if haveq(28741)
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Dungeons\\Grim Batol")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Dungeons\\Halls of Origination")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Dungeons\\Lost City of the Tol'vir")
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\Cataclysm Dungeons\\The Stonecore",{
mopready=true,
mapid=324,
achieveid={4846},
patch='40003',
condition_suggested=function() return level>=30 and level<=35 end,
keywords={"Deepholm"},
description="This guide will walk you through the Stonecore dungeon.",
},[[
step
label "start"
Press _I_ and queue for The Stonecore or enter the dungeon with your group |goto The Stonecore/1 54.50,94.50 < 100 |c
step
talk Earthwarden Yrsa##50048
accept Twilight Documents##28815 |goto The Stonecore 53.70,94.90
step
map The Stonecore/1
path follow strict;loop off;ants straight
path	54.60,88.40	61.40,79.20	63.30,70.90
kill Stonecore Earthshaper##43537+
|tip Make sure to kill him first, if not killed fast enough, he will transform and do big group damage.
|tip You will have to fight him in each group as you continue forward.
|tip Opening the world map will display an ant trail guiding you through the current floor.
|tip
Click Here to Continue |confirm
step
click Twilight Documents##207415
collect Twilight Documents##65734 |q 28815/1 |goto The Stonecore/1 63.50,65.20
|only if haveq(28815)
step
_Click the Quest Complete Box:_
turnin Twilight Documents##28815
accept Followers and Leaders##28814
step
kill Corborus##43438 |goto The Stonecore 62.40,61.20
_Phase 1:_
_EVERYONE:_ |grouprole EVERYONE
|tip Spread out for "Crystal Barrage". |grouprole EVERYONE
|tip
_HEALER:_ |grouprole HEALER
|tip Remove "Dampening Wave" from the tank when possible. |grouprole HEALER
|tip
_DAMAGE:_ |grouprole DAMAGE
|tip After every Crystal Barrage, AoE the "Crystal Shards" left behind. |grouprole DAMAGE |only if heroic_dung()
|tip
_Phase 2:_
_EVERYONE:_ |grouprole EVERYONE
|tip He will eventually use "Thrashing Charge". |grouprole EVERYONE
|tip Move out of areas with dust clouds on the ground at this time. |grouprole EVERYONE
|tip He will erupt from the dust clouds, spawning "Rock Borers" and likely killing anyone caught in the cloud. |grouprole EVERYONE
|tip
_DAMAGE:_ |grouprole DAMAGE
|tip AoE down Rock Borers as a priority. |grouprole DAMAGE
|tip
Click here to Continue |confirm
step
map The Stonecore/1
path follow strict;loop off;ants straight
path	59.60,59.80	54.90,58.40	50.00,59.70	46.10,55.70	43.40,52.20
path	38.80,49.60
Follow the path
|tip Opening the world map will display an ant trail guiding you through the current floor.
|tip
Click Here to Continue |confirm
step
kill Slabhide##43214 |goto The Stonecore/1 37.70,44.90
_EVERYONE:_ |grouprole EVERYONE
|tip He casts "Lava Fissures" at random players which need to be moved out of. |grouprole EVERYONE
|tip Be mindful of "Stalacite" which fall from the ceiling. |grouprole EVERYONE
|tip During "Crystal Storm" move behind Stalacite to avoid damage. |grouprole EVERYONE |only if heroic_dung()
|tip
_TANK:_ |grouprole TANK
|tip Face him away from the group. |grouprole TANK
|tip
_DAMAGE:_ |grouprole DAMAGE
|tip Stay away from the front of him. |grouprole DAMAGE
|tip
Click Here to Confirm |confirm
step
map The Stonecore/1
path follow strict;loop off;ants straight
path	37.70,39.50	39.80,32.20	38.60,20.80	42.70,16.70	45.40,19.00
Follow the path
|tip Kill the Stonecore Sentries, as they will aggro big groups if they are close enough.
|tip Stonecore Bruisers patrol this area.
|tip When you can, kill them away from groups.
|tip If you stay to the right side, you will not have to kill groups on the left side.
|tip Opening the world map will display an ant trail guiding you through the current floor.
|tip
Click Here to Continue |confirm
step
kill Ozruk##42188 |goto The Stonecore/1 47.70,20.00
_EVERYONE:_ |grouprole EVERYONE
|tip Move out of "Ground Slam". |grouprole EVERYONE
|tip Move 15 yards away from him after each ground slam as he will use "Shatter" immediately after. |grouprole EVERYONE
|tip "Elementium Spiked Shield" causes bleed to melee attackers. |grouprole EVERYONE |only if heroic_dung()
|tip "Elementium Bulward" reflects spells. |grouprole EVERYONE |only if heroic_dung()
|tip
_HEALER:_ |grouprole HEALER
|tip Remove "Paralyze" from allies. |grouprole HEALER
|tip
_TANK:_ |grouprole TANK
|tip Face him away from the group. |grouprole TANK
|tip
Click Here to Continue |confirm
step
map The Stonecore/1
path follow strict;loop off;ants straight
path	48.50,27.20	48.00,35.60	48.40,45.20	53.50,40.50
Follow the path
|tip Opening the world map will display an ant trail guiding you through the current floor.
|tip
Click Here to Continue |confirm
step
kill High Priestess Azil##42333 |goto The Stonecore/1 57.64,38.24 |only if not haveq(28814)
kill High Priestess Azil##42333 |q 28814/1 |goto The Stonecore/1 57.64,38.24 |only if haveq(28814)
kill 101 Devout Follower##42428 |q 28814/2 |goto The Stonecore/1 57.64,38.24 |only if haveq(28814)
_Phase 1:_
_TANK:_ |grouprole TANK
|tip Move her out of "Gravity Wells" as they appear, indicated by purple circles on the ground. |grouprole TANK
|tip Tank her to the left of Gravity Wells so adds run through it and die. |grouprole TANK
|tip |grouprole TANK
_DAMAGE:_ |grouprole DAMAGE
|tip Establish an interrupt rotation for "Force Grip". |grouprole DAMAGE |only if heroic_dung()
|tip
_Phase 2:_
_EVERYONE:_ |grouprole EVERYONE
|tip She will cast "Seismic Shard" at random players. |grouprole EVERYONE |only if heroic_dung()
|tip The impact area will be indicated by a shadow on the ground. |grouprole EVERYONE |only if heroic_dung()
|tip
_TANK:_ |grouprole TANK
|tip When she floats to the altar, be ready to pick up the Devout Followers that run in. |grouprole TANK
|tip
Click Here to Continue |confirm
step
You can either run to the beginning of the dungeon to turn in your quests.
Or
You can Right Click the dungeon finder icon on your mini map, teleport out of the dungeon, then teleport back in to the entrance.
|tip
Click Here to Continue |confirm
step
talk Earthwarden Yrsa##50048
turnin Followers and Leaders##28814 |goto The Stonecore/1 53.60,95.00
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Dungeons\\Throne of the Tides")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Dungeons\\Vortex Pinnacle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Dungeons\\End Time")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Dungeons\\Well of Eternity")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Dungeons\\Hour of Twilight")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Dungeons\\Zul'Aman")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Dungeons\\Zul Gurub")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Raids\\The Bastion of Twilight")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Raids\\Blackwing Descent")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Raids\\Throne of the Four Winds")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Raids\\Baradin Hold")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Raids\\Firelands")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Cataclysm Raids\\Dragon Soul")
