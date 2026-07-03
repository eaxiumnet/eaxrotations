local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Horde" then return end
if ZGV:DoMutex("ReputationsH") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Classic Reputations\\Bloodsail Buccaneers")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Classic Reputations\\Cenarion Circle")
ZygorGuidesViewer:RegisterGuide("Reputation Guides\\Classic Reputations\\Darkspear Trolls",{
description="This guide will walk you through becoming exalted with the Darkspear Trolls faction.",
condition_suggested=function() return level >= 10 and level <= 50 and rep('Darkspear Trolls') < Exalted end,
},[[
step
talk Champion Uru'zin##50477
buy Darkspear Tabard##45582 |goto Orgrimmar,50.00,58.10
Equip your Darkspear Trolls Tabard |equipped Darkspear Tabard##45582 |use Darkspear Tabard##45582 |future
You can run any dungeon that grants experience to gain reputation for the Darkspear Trolls
Become Exalted with Darkspear Trolls |complete rep('Darkspear Trolls')==Exalted
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Classic Reputations\\The Defilers")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Classic Reputations\\Frostwolf Clan")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Classic Reputations\\Hydraxian Waterlords")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Classic Reputations\\Orgrimmar")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Classic Reputations\\Ravenholdt")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Classic Reputations\\The Steamwheedle Cartel")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Classic Reputations\\Thunder Bluff")
ZygorGuidesViewer:RegisterGuide("Reputation Guides\\Classic Reputations\\Timbermaw Hold",{
description="This guide will walk you through becoming exalted with the Timbermaw Hold faction.",
achieveid={944},
patch='30001',
},[[
step
talk Nafien##15395
accept Deadwood of the North##28338 |goto Felwood,64.00,10.30
accept Disarming Bears##28366 |goto Felwood,64.00,10.30
step
talk Ferli##48461
accept Stupid Drizle!##28362 |goto Felwood 64.10,10.30
step
talk Drizle##47556
turnin Stupid Drizle!##28362 |goto Felwood 60.60,9.50
accept The Chieftain's Key##28364 |goto Felwood 60.60,9.50
step
kill Chieftain Bloodmaw##9462
collect Drizle's Key##63695 |q 28364/1 |goto Felwood 62.10,9.90
step
talk Drizle##47556
turnin The Chieftain's Key##28364 |goto Felwood 60.60,9.50
step
kill Deadwood Den Watcher##7156+, Deadwood Avenger##7157+, Deadwood Shaman##7158+
Kill 15 Deadwood Furbolg |q 28338/1 |goto Felwood 62.00,12.80
click Deadwood Weapon Pile##207126
collect 7 Deadwood Weapons##63689 |q 28366/1 |goto Felwood 62.00,12.80
collect 1 Deadwood Ritual Totem##20741 |n
accept Deadwood Ritual Totem##8470
You can find more around [Felwood,59.70,9.80].
step
talk Nafien##15395
turnin Deadwood of the North##28338 |goto Felwood 64.00,10.30
turnin Disarming Bears##28366 |goto Felwood 64.00,10.30
accept Speak to Salfa##28521 |goto Felwood 64.00,10.30
You should be able to turn in Feathers for Nafien, a repeatable reputation quest.
step
talk Kernda##11558
turnin Deadwood Ritual Totem##8470 |goto Felwood 64.70,5.70
You should be friendly with Timbermaw after completing this quest.
only if rep('Timbermaw Hold')>=Neutral
step
talk Meilosh##11557
accept Runecloth##6031 |goto Felwood 64.90,5.20
only if rep ('Timbermaw Hold')>=Friendly
step
talk Salfa##11556
turnin Speak to Salfa##28521 |goto Winterspring,21.10,46.20
accept Delivery for Donova##28524 |goto Winterspring,21.10,46.20
accept Winterfall Activity##28522 |goto Winterspring,21.10,46.20
step
talk Donova Snowden##9298
turnin Delivery for Donova##28524 |goto Winterspring 25.10,58.50
accept Threat of the Winterfall##28460 |goto Winterspring 25.10,58.50
accept Falling to Corruption##28464 |goto Winterspring 25.10,58.50
step
Click the Winterfall Cauldron.
turnin Falling to Corruption##28464 |goto Winterspring 24.50,47.60
accept Mystery Goo##28467 |goto Winterspring 24.50,47.60
step
kill Winterfall Totemic##7441+, Winterfall Den Watcher##7440+, Winterfall Runner##10916+
Kill 15 Winterfall Furbolg |q 28460/1 |goto Winterspring 24.50,47.60
collect 10 Winterfall Spirit Beads##21383 |q 28522/1 |goto Winterspring 24.50,47.60
You can find more mobs around [Winterspring,27.30,49.30].
step
talk Donova Snowden##9298
turnin Mystery Goo##28467 |goto Winterspring 25.10,58.50
turnin Threat of the Winterfall##28460 |goto Winterspring 25.10,58.50
accept Winterfall Runners##28469 |goto Winterspring 25.10,58.50
accept Scalding Signs##28530 |goto Winterspring 25.10,58.50
stickystart "scaldspring"
step
kill Winterfall Runner##10916
collect Winterfall Crate##12829 |q 28469/1 |goto Winterspring 29.30,54.80
They walk along the road so some searching may be required.
step
label "scaldspring"
kill Scalding Springsurge##48767+,Boiling Springbubble##48768+
collect 7 Suspicious Green Sludge##64449 |q 28530/1 |goto Winterspring 32.70,50.60
step
talk Donova Snowden##9298
turnin Winterfall Runners##28469 |goto Winterspring 25.10,58.50
turnin Scalding Signs##28530 |goto Winterspring 25.10,58.50
accept High Chief Winterfall##28470 |goto Winterspring 25.10,58.50
You should be honored with Timbermaw Hold at this point.
step
kill High Chief Winterfall##10738 |q 28470/1 |goto Winterspring 37.00,55.60
step
talk Donova Snowden##9298
turnin High Chief Winterfall##28470 |goto Winterspring 25.10,58.50
step
talk Salfa##11556
turnin Winterfall Activity##28522 |goto Winterspring 21.10,46.20
You should now be able to do the quest More Beads for Salfa.
step
talk Burndl##48722
accept Bearzerker##28614 |goto Winterspring 65.30,46.20
step
talk Tanrir##48723
accept Turning the Earth##28615 |goto Winterspring 65.40,46.20
stickystart "overtotem"
step
kill Grolnar the Berserk##49178 |q 28614/1 |goto Winterspring 69.30,50.60
step
label "overtotem"
Use Tanrir's Overcharged Totem to overload Winterfall Earth Totems. |use Tanrir's Overcharged Totem##64637
Overload 4 Winterfall Earth Totems |q 28615/1 |goto Winterspring 67.00,47.70
step
talk Tanrir##48723
turnin Turning the Earth##28615 |goto Winterspring,65.40,46.20
step
talk Burndl##48722
turnin Bearzerker##28614 |goto Winterspring 65.30,46.20
step
label "the_grind"
At this point, you can do two repeatable quests, as well as grind to earn rep.
More Beads for Salfa requires that you grind in Winterspring. You collect 5 Winterfall Spirit Beads, which are worth 2,000 Reputation per turn in. Click here to farm at the Winterspring location. |confirm |next "winterfall"
or
Feathers for Nafien requires that you grind in Felwood. You collect 5 Deadwood Headdress Feathers, which are worth 2,000 Reputation per turn in. Click here to farm at the Felwood location. |confirm |next "deadwood" |tip
Collecting 65 Beads/Feathers will get you from Honored to Exalted.
step
label "winterfall"
kill Winterfall Shaman##7439+,Winterfall Ursa##7438+
collect Winterfall Spirit Beads##21383 |n |goto Winterspring 67.50,49.80
|tip You need to collect at least 5.
5 Winterfall Spirit Beads = 2,000 Reputation. You're aiming for at least 60 to 65 Winterfall Spirit Beads in total.
More can be found at [Winterspring,35.60,56.30]
Click here to turn in your beads |confirm
step
talk Salfa##11556
accept More Beads for Salfa##28523 |n |goto Winterspring 21.10,46.20
Click here to go back to grinding. |next "the_grind" |only if rep('Timbermaw Hold')<=Revered |confirm
or
Exalted with Timbermaw Hold |complete rep('Timbermaw Hold')==Exalted
step
label "deadwood"
kill Deadwood Avenger##7157+,Deadwood Den Watcher##7156+,Deadwood Shaman##7158+
collect Deadwood Headdress Feather##21377 |n |goto Felwood,61.90,12.30
|tip You need to collect at least 5.
5 Feather Headresses = 2,000 Reputation. You're aiming for at least 60 to 65 Feather Headresses in total.
More can be found at [Felwood,59.60,8.90]
Click here to turn in your feathers |confirm |next "turnin"
step
label "turnin"
talk Nafien##15395
accept Feathers for Nafien##28395 |n |goto Felwood 64.00,10.30
Click here to go back to grinding. |next "the_grind" |only if rep('Timbermaw Hold')<=Revered |confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Classic Reputations\\Undercity")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Classic Reputations\\Warsong Outriders")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\Ashtongue Deathsworn")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\Keepers of Time")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\Mag'har")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\Netherwing")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\Ogri'la")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\The Scale of the Sands")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\The Scryers")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\The Sha'tar")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\Sha'tari Skyguard")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\Sporeggar")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\The Violet Eye")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\Shattered Sun Offensive")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\Silvermoon City")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\Thrallmar")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Wrath of the Lich King Reputations\\Argent Crusade")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Wrath of the Lich King Reputations\\Ashen Verdict")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Wrath of the Lich King Reputations\\The Frenzyheart Tribe")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Wrath of the Lich King Reputations\\The Horde Expedition")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Wrath of the Lich King Reputations\\Kalu'ak")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Wrath of the Lich King Reputations\\Kirin Tor")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Wrath of the Lich King Reputations\\Knights of the Ebon Blade")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Wrath of the Lich King Reputations\\The Oracles")
ZygorGuidesViewer:RegisterGuide("Reputation Guides\\Wrath of the Lich King Reputations\\The Sons of Hodir",{
description="This guide will walk you through becoming exalted with the Sons of Hodir faction.",
},[[
step
Proceeding to Prequests next step |next "Daily" |only if rep('The Sons of Hodir')<=Friendly
Proceeding to Honored Dailies |next "Daily2" |only if rep('The Sons of Hodir')==Honored
Proceeding to Revered Dailies |next "Daily3" |only if rep('The Sons of Hodir')==Revered
step
talk Jeer Sparksocket##29431
turnin Luxurious Getaway!##12853 |goto The Storm Peaks,41,86.40
accept Clean Up##12818 |goto The Storm Peaks,41,86.40
step
talk Smilin' Slirk Brassknob##29904
home K3 |goto The Storm Peaks 41.10,85.90
step
talk Gretchen Fizzlespark##29473
|tip She's inside the inn.
accept They Took Our Men!##12843 |goto The Storm Peaks 41.10,86.10
accept Equipment Recovery##12844 |goto The Storm Peaks 41.10,86.10
step
talk Ricket##29428
accept Reclaimed Rations##12827 |goto The Storm Peaks 40.90,85.30
accept Expression of Gratitude##12836 |goto The Storm Peaks 40.90,85.30
step
talk Skizzle Slickslide##29721
fpath K3 |goto The Storm Peaks 40.80,84.50
stickystart "driedrations"
step
click Charred Wreckage##191535
collect 10 Charred Wreckage##40603 |q 12818/1 |goto The Storm Peaks 39.80,86.40
step
label "driedrations"
kill Savage Hill Scavenger##29404+, Savage Hill Brute##29623+
click Dried Gnoll Rations##191843
collect 16 Dried Gnoll Rations##40645|q 12827/1 |goto The Storm Peaks 35,83.80
step
kill Gnarlhide##30003|q 12836/1 |goto The Storm Peaks 30.30,85.70
step
talk Jeer Sparksocket##29431
turnin Clean Up##12818 |goto The Storm Peaks 41,86.40
accept Just Around the Corner##12819 |goto The Storm Peaks 41,86.40
step
talk Ricket##29428
turnin Reclaimed Rations##12827 |goto The Storm Peaks 40.90,85.30
turnin Expression of Gratitude##12836 |goto The Storm Peaks 40.90,85.30
accept Ample Inspiration##12828 |goto The Storm Peaks 40.90,85.30
step
click Sparksocket's Tools##191519
collect Sparksocket's Tools##40642|q 12819/1 |goto The Storm Peaks 35.10,87.80
step
talk Jeer Sparksocket##29431
turnin Just Around the Corner##12819 |goto The Storm Peaks 41,86.40
accept Slightly Unstable##12826 |goto The Storm Peaks 41,86.40
step
talk Ricket##29428
turnin Slightly Unstable##12826 |goto The Storm Peaks 40.90,85.30
accept A Delicate Touch##12820 |goto The Storm Peaks 40.90,85.30
step
Use your Improved Land Mines to place mines on the ground close to each other|use Improved Land Mines##40676
|tip Garm Invaders and Snowblind Followers will run over the mines and die.
kill 12 Garm Attackers|q 12820/1 |goto The Storm Peaks 43.10,81.20
step
talk Tore Rumblewrench##29430
accept Moving In##12829 |goto The Storm Peaks 41.70,80
accept Ore Repossession##12830 |goto The Storm Peaks 41.70,80
step
click the U.D.E.D. Dispenser##191553
Retrieve a bomb from the dispenser
collect U.D.E.D.##40686
|q 12828 |goto The Storm Peaks 41.70,80
step
Use your U.D.E.D. on an Ironwool Mammoth|use U.D.E.D.##40686
|tip They walk around this area spread out.
click Mammoth Meat##191567
collect 8 Hearty Mammoth Meat##40728|q 12828/1 |goto The Storm Peaks 43.90,79.00
step
Go into the cave |goto The Storm Peaks 40.40,77.80 < 10 |walk
talk Injured Goblin Miner##29434
accept Only Partly Forgotten##12831 |goto The Storm Peaks 41.50,74.90
stickystart "crystalweb"
step
kill Snowblind Diggers##29413 |n
collect 5 Impure Saronite Ore##40744|q 12830/1 |goto The Storm Peaks 44,75.90
step
kill Icetip Crawler##29461
collect 1 Icetip Venom Sac##40944|q 12831/1 |goto The Storm Peaks 47.10,72.30
step
label "crystalweb"
kill 12 Crystalweb Spiders |q 12829/1 |goto The Storm Peaks 44,75.90
step
talk Injured Goblin Miner##29434
turnin Only Partly Forgotten##12831 |goto The Storm Peaks 43.50,75.20
accept Bitter Departure##12832 |goto The Storm Peaks 43.50,75.20
step
talk Injured Goblin Miner##29434
Tell the miner you're ready
Escort the Injured Goblin Miner to K3 |q 12832/1 |goto The Storm Peaks 43.50,75.20
step
Fly up to [39.80,73.30]
kill Sifreldar Storm Maiden##29323+ |n
collect 5 Cold Iron Key##40641|n
click Rusty Cage##191544
Free 5 Goblin Prisoners |q 12843/1
click K3 Equipment##191568
collect 8 K3 Equipment##40726 |q 12844/1
step
talk Tore Rumblewrench##29430
turnin Moving In##12829 |goto The Storm Peaks 41.70,80
turnin Ore Repossession##12830 |goto The Storm Peaks 41.70,80
step
talk Ricket##29428
turnin A Delicate Touch##12820 |goto The Storm Peaks 40.90,85.30
turnin Ample Inspiration##12828 |goto The Storm Peaks 40.90,85.30
turnin Bitter Departure##12832 |goto The Storm Peaks 40.90,85.30
accept Cell Block Tango##12821 |goto The Storm Peaks 40.90,85.30
step
talk Gretchen Fizzlespark##29473
turnin They Took Our Men!##12843 |goto The Storm Peaks 41.10,86.10
accept Leave No Goblin Behind##12846|goto The Storm Peaks 41.10,86.10
turnin Equipment Recovery##12844 |goto The Storm Peaks 41.10,86.10
step
click Transporter Power Cell##191576
collect Transporter Power Cell##40731|q 12821/1 |goto The Storm Peaks 45.10,82.40
step
Use your Transporter Power Cell next to the Teleportation Pad|use Transporter Power Cell##40731
|tip It looks like a tall machine with a fan in the bottom of it.
Activate the Garm Teleporter |q 12821/2 |goto The Storm Peaks 50.70,81.90
step
talk Ricket##29428
turnin Cell Block Tango##12821 |goto The Storm Peaks 40.90,85.30
accept Know No Fear##12822 |goto The Storm Peaks 40.90,85.30
step
talk Gino##29432
accept A Flawless Plan##12823 |goto The Storm Peaks 50.00,81.80
step
Go inside the cave |goto The Storm Peaks 50.50,77.80
Use your Hardpacked Explosive Bundle next to Frostgut's Altar|use Hardpacked Explosive Bundle##41431
|tip It's a stone altar with a bunch of melted red candles on it. Follow the path in the cave that spirals up all the way to the top of the cave to find it.
kill Tormar Frostgut##29626 |q 12823/2 |goto The Storm Peaks 50.50,77.80
step
kill 6 Garm Watcher##29409+ |q 12822/1 |goto The Storm Peaks 48.10,81.90
kill 8 Snowblind Devotee##29407+ |q 12822/2 |goto The Storm Peaks 48.10,81.90
step
Go outside
talk Gino##29432
turnin A Flawless Plan##12823 |goto The Storm Peaks 50.00,81.80
accept Demolitionist Extraordinaire##12824 |goto The Storm Peaks 50.00,81.80
step
Fly up into the cave |goto The Storm Peaks 42.80,68.90
talk Lok'lira the Crone##29481
turnin Leave No Goblin Behind##12846
accept The Crone's Bargain##12841
step
kill Overseer Syra##29518
collect 1 Runes of the Yrkvinn##40690|q 12841/1 |goto The Storm Peaks 44.20,68.90
step
talk Lok'lira the Crone##29481
turnin The Crone's Bargain##12841 |goto The Storm Peaks 42.80,68.90
accept Mildred the Cruel##12905 |goto The Storm Peaks 42.80,68.90
step
talk Mildred the Cruel##29885
turnin Mildred the Cruel##12905 |goto The Storm Peaks 44.40,68.90
accept Discipline##12906 |goto The Storm Peaks 44.40,68.90
step
Use your Disciplining Rod on Exhausted Vrykul|use Disciplining Rod##42837
|tip They are sitting on the ground inside these side tunnels inside this mine.
Discipline 6 Exhausted Vrykul |q 12906/1 |goto The Storm Peaks 44.80,70.30
step
talk Mildred the Cruel##29885
turnin Discipline##12906 |goto The Storm Peaks 44.40,68.90
accept Examples to be Made##12907 |goto The Storm Peaks 44.40,68.90
step
kill 1 Garhal##30147 |q 12907/1 |goto The Storm Peaks 45.40,69.10
step
talk Mildred the Cruel##29885
turnin Examples to be Made##12907 |goto The Storm Peaks 44.40,68.90
accept A Certain Prisoner##12908 |goto The Storm Peaks 44.40,68.90
step
talk Lok'lira the Crone##29481
turnin A Certain Prisoner##12908 |goto The Storm Peaks 42.80,68.90
accept A Change of Scenery##12921 |goto The Storm Peaks 42.80,68.90
step
Follow the path in the mine east out to the other side
talk Lok'lira the Crone##29975
turnin A Change of Scenery##12921 |goto The Storm Peaks 47.50,69.10
accept Is That Your Goblin?##12969 |goto The Storm Peaks 47.50,69.10
step
talk Agnetta Tyrsdottar##30154
Tell her to skip the warmup
kill Agnetta Tyrsdottar##30154 |q 12969/1 |goto The Storm Peaks 48.20,69.80
step
talk Lok'lira the Crone##29975
turnin Is That Your Goblin?##12969 |goto The Storm Peaks 47.50,69.10
accept The Hyldsmeet##12970 |goto The Storm Peaks 47.50,69.10
step
talk Lok'lira the Crone##29975
Ask her about her proposal
Listen to Lok'lira's proposal |q 12970/1 |goto The Storm Peaks 47.50,69.10
step
talk Lok'lira the Crone##29975
turnin The Hyldsmeet##12970 |goto The Storm Peaks 47.50,69.10
accept Taking on All Challengers##12971 |goto The Storm Peaks 47.50,69.10
step
talk Victorious Challenger##30012
kill 6 Victorious Challenger##30012+ |q 12971/1 |goto The Storm Peaks 51,66.40
step
talk Lok'lira the Crone##29975
turnin Taking on All Challengers##12971 |goto The Storm Peaks 47.50,69.10
accept You'll Need a Bear##12972 |goto The Storm Peaks 47.50,69.10
step
talk Iva the Vengeful##29997
accept Off With Their Black Wings##12942 |goto The Storm Peaks 48.40,72.10
accept Yulda's Folly##12968 |goto The Storm Peaks 48.40,72.10
step
talk Thyra Kvinnshal##30041
accept Aberrations##12925 |goto The Storm Peaks 48.40,72.10
step
talk Brijana##29592
turnin You'll Need a Bear##12972 |goto The Storm Peaks 53.10,65.70
accept Bearly Hanging On##12851 |goto The Storm Peaks 53.10,65.70
step
clicknpc Icefang##29598
While riding Icefang, use the Flaming Arrow ability on your hotbar to shoot arrows at the Frostworgs and Frost Giants|petaction Flaming Arrow
Burn 7 Frostworgs |q 12851/1 |goto The Storm Peaks 53.10,65.70
Burn 15 Frost Giants |q 12851/2 |goto The Storm Peaks 53.10,65.70
step
talk Brijana##29592
turnin Bearly Hanging On##12851 |goto The Storm Peaks 53.10,65.70
accept Cold Hearted##12856 |goto The Storm Peaks 53.10,65.70
step
Fly to |goto The Storm Peaks 63.90,62.50
clicknpc Captive Proto-Drake##29708
Use your Ice Shard ability on the Brunnhildar Prisoners|petaction Ice Shard
|tip The Brunnhildar Prisoners look like blue blocks of ice around this area on the ground.
When your Proto-Drake is holding 3 Brunnhildar Prisoners, start flying toward Brunnhildar Village at [The Storm Peaks 59.90,61.20], the drake will eventually go on autopilot. Repeat this process 2 more times.
Rescue 9 Brunnhildar Prisoners |q 12856/1
Free 3 Proto-Drakes |q 12856/2
step
talk Brijana##29592
turnin Cold Hearted##12856 |goto The Storm Peaks 53.10,65.70
accept Deemed Worthy##13063 |goto The Storm Peaks 53.10,65.70
step
talk Astrid Bjornrittar##29839
turnin Deemed Worthy##13063 |goto The Storm Peaks 49.70,71.80
accept Making a Harness##12900 |goto The Storm Peaks 49.70,71.80
step
kill Icemane Yeti##29875+|n
collect 3 Icemane Yeti Hide##41424|q 12900/1 |goto The Storm Peaks 47.90,74.70
step
talk Astrid Bjornrittar##29839
turnin Making a Harness##12900 |goto The Storm Peaks 49.70,71.80
accept The Last of Her Kind##12983 |goto The Storm Peaks 49.70,71.80
accept The Slithering Darkness##12989 |goto The Storm Peaks 49.70,71.80
step
kill 8 Ravenous Jormungar##29605+ |q 12989/1 |goto The Storm Peaks 55.80,63.90
|tip They are inside the cave.
step
clicknpc Injured Icemaw Matriarch##29563
The bear runs back to Brunnhildar Village
Rescue the Icemaw Matriarch |q 12983/1 |goto The Storm Peaks 54.80,60.40
step
talk Astrid Bjornrittar##29839
turnin The Last of Her Kind##12983 |goto The Storm Peaks 49.70,71.80
accept The Warm-Up##12996 |goto The Storm Peaks 49.70,71.80
turnin The Slithering Darkness##12989 |goto The Storm Peaks 49.70,71.80
step
Use your Reins of the Warbear Matriarch outside the building to ride a bear|invehicle|c|use Reins of the Warbear Matriarch##42481
step
Use the abilities on your hotbar to fight Kirgaraak
|tip He's a big white yeti.
Defeat Kirgaraak |q 12996/1 |goto The Storm Peaks 50.80,67.70
step
Click the red arrow to get off the bear|script VehicleExit()|outvehicle|c
step
talk Astrid Bjornrittar##29839
turnin The Warm-Up##12996 |goto The Storm Peaks 49.70,71.80
accept Into the Pit##12997 |goto The Storm Peaks 49.70,71.80
step
Use your Reins of the Warbear Matriarch inside The Pit of the Fang to ride a bear|use Reins of the Warbear Matriarch##42499
Use the abilities on your hotbar to fight Hyldsmeet Warbears
kill 6 Hyldsmeet Warbear##30174+ |q 12997/1 |goto The Storm Peaks 49.10,69.40
step
Click the red arrow to get off the bear|script VehicleExit()|outvehicle|c
step
talk Astrid Bjornrittar##29839
turnin Into the Pit##12997 |goto The Storm Peaks 49.70,71.80
accept Prepare for Glory##13061 |goto The Storm Peaks 49.70,71.80
step
talk Lok'lira the Crone##29975
turnin Prepare for Glory##13061 |goto The Storm Peaks 47.50,69.10
accept Lok'lira's Parting Gift##13062 |goto The Storm Peaks 47.50,69.10
step
talk Gretta the Arbiter##29796
turnin Lok'lira's Parting Gift##13062 |goto The Storm Peaks 50.90,65.60
accept The Drakkensryd##12886 |goto The Storm Peaks 50.90,65.60
step
You fly off on a drake and start flying in circles around a tower:
Use your Hyldnir Harpoon in your bags on Hyldsmeet Proto-Drakes to harpoon over to a new drake|use Hyldnir Harpoon##41058
kill Hyldsmeet Drakerider##29694+ |n
Repeat this process 9 more times
Defeat 10 Hyldsmeet Drakeriders |q 12886/1
step
They look like light fixtures on the side of the stone columns.
Use your Hyldnir Harpoon in your bags on a Column Ornament to get off the drake|outvehicle|c|use Hyldnir Harpoon##41058
step
talk Thorim##29445
turnin The Drakkensryd##12886 |goto The Storm Peaks 33.40,58
accept Sibling Rivalry##13064 |goto The Storm Peaks 33.40,58
step
talk Thorim##29445
Ask him what became of Sif
Hear Thorim's History |q 13064/1 |goto The Storm Peaks 33.40,58
step
talk Thorim##29445
turnin Sibling Rivalry##13064 |goto The Storm Peaks 33.40,58
accept Mending Fences##12915 |goto The Storm Peaks 33.40,58
step
kill 12 Nascent Val'kyr##29570+ |q 12942/1 |goto The Storm Peaks 27.30,63.70
kill Valkyrion Aspirant##29569+ |n
collect 6 Vial of Frost Oil##41612|q 12925 |goto The Storm Peaks 27.30,63.70
step
Use your Vials of Frost Oil on the Plagued Proto-Drake Eggs|use Vial of Frost Oil##41612
|tip They look like brown spiked eggs sitting in the yellow water around this area.
Try to get 6 at a time
Destroy 30 Plagued Proto-Drake Eggs |q 12925/1 |goto The Storm Peaks 23.70,58.30
step
kill Yulda the Stormspeaker##30046 |q 12968/1 |goto The Storm Peaks 24,61.80
click Harpoon Crate##192072
accept Valkyrion Must Burn##12953 |goto The Storm Peaks 24,61.80
step
clicknpc Valkyrion Harpoon Gun##30066
Use the Flaming Harpoon ability on your hotbar to shoot the tan bundles of straw near buildings and in wagons around this area|petaction Flaming Harpoon
Start 6 Fires |q 12953/1 |goto The Storm Peaks 26,59.80
step
Click the red arrow to get off the gun|script VehicleExit()|outvehicle|c
step
talk Ricket##29428
turnin Demolitionist Extraordinaire##12824 |goto The Storm Peaks 40.90,85.30
turnin Know No Fear##12822 |goto The Storm Peaks 40.90,85.30
accept Overstock##12833 |goto The Storm Peaks 40.90,85.30
step
Use your Improved Land Mines to place mines on the ground close to each other|use Improved Land Mines##40676
|tip Garm Invaders and Snowblind Followers will run over the mines and die.
kill 12 Garm Invader |q 12833/1 |goto The Storm Peaks 43.10,81.20
step
talk Ricket##29428
turnin Overstock##12833 |goto The Storm Peaks 40.90,85.30
step
talk Thyra Kvinnshal##30041
turnin Aberrations##12925 |goto The Storm Peaks 48.40,72.10
step
talk Iva the Vengeful##29997
turnin Off With Their Black Wings##12942 |goto The Storm Peaks 48.40,72.10
turnin Yulda's Folly##12968 |goto The Storm Peaks 48.40,72.10
turnin Valkyrion Must Burn##12953 |goto The Storm Peaks 48.40,72.10
step
click Granite Boulder##191815
Use Thorim's Charm of Earth on the Stormforged Iron Giants|use Thorim's Charm of Earth##41505
Help the dwarves kill them
kill 5 Stormforged Iron Giant##29375+ |q 12915/2 |goto The Storm Peaks 75.80,63
collect Slag Covered Metal##41556 |q 12922 |future |n |goto The Storm Peaks 75.80,63
use Slag Covered Metal##41556
accept The Refiner's Fire##12922 |goto The Storm Peaks 75.80,63
step
kill Seething Revenant##29504+
collect 10 Furious Spark##41558|q 12922/1 |goto The Storm Peaks 75.40,63.50
step
click Granite Boulder##191815
Use Thorim's Charm of Earth on Fjorn|use Thorim's Charm of Earth##41505
|tip He's a huge fire giant, holding a huge smithing hammer.
Help the dwarves kill him
kill Fjorn##29503 |q 12915/1 |goto The Storm Peaks 77.20,62.90
step
click Fjorn's Anvil##192071
turnin The Refiner's Fire##12922 |goto The Storm Peaks 77.20,62.90
accept A Spark of Hope##12956 |goto The Storm Peaks 77.20,62.90
step
talk Thorim##29445
turnin A Spark of Hope##12956 |goto The Storm Peaks 33.40,58
turnin Mending Fences##12915 |goto The Storm Peaks 33.40,58
accept Forging an Alliance##12924 |goto The Storm Peaks 33.40,58
step
talk Halvdan##32571
fpath Dun Niffelem |goto The Storm Peaks 62.60,60.90
step
talk King Jokkum##30105
accept You Can't Miss Him##12966 |goto The Storm Peaks 65.40,60.20
step
talk Njormeld##30099
turnin You Can't Miss Him##12966 |goto The Storm Peaks 75.40,63.60
accept Battling the Elements##12967 |goto The Storm Peaks 75.40,63.60
step
clicknpc Snorri##30123 |invehicle |c
Use the Gather Snow ability on your hotbar to gather snow from Snowdrifts|petaction Gather Snow
|tip The Snowdrifts look like piles of snow on the ground.
Use the Throw Snowball ability on your hotbar to throw the snow at Seething Revenants|petaction Throw Snowball
kill 10 Seething Revenant##29504+ |q 12967/1 |goto The Storm Peaks 75.70,63.90
step
Click the red arrow on your hotbar to leave Snorri|script VehicleExit()|outvehicle|c
step
talk Njormeld##30099
turnin Battling the Elements##12967 |goto The Storm Peaks 75.40,63.60
step
talk Njormeld##30127
turnin Forging an Alliance##12924 |goto The Storm Peaks 63.20,63.20
accept A New Beginning##13009 |goto The Storm Peaks 63.20,63.20
step
click Fjorn's Anvil##192071
accept Hot and Cold##12981 |goto The Storm Peaks 63.20,62.90
step
talk King Jokkum##30105
accept In Memoriam##12975 |goto The Storm Peaks 65.40,60.20
step
kill Brittle Revenant##30160+ |n
collect 6 Essence of Ice##42246 |q 12981 |goto The Storm Peaks 69.70,60.20
step
Use your Essences of Ice next to Smoldering Scraps|use Essence of Ice##42246
click Frozen Iron Scrap##192127
collect 6 Frozen Iron Scrap##42252|q 12981/1 |goto The Storm Peaks 75.30,62.80
step
click Horn Fragment##192082
collect 8 Horn Fragment##42162|q 12975/1 |goto The Storm Peaks 72.10,49.40
step
talk King Jokkum##30105
turnin In Memoriam##12975 |goto The Storm Peaks 65.40,60.20
accept A Monument to the Fallen##12976 |goto The Storm Peaks 65.40,60.20
step
talk Njormeld##30127
turnin A Monument to the Fallen##12976 |goto The Storm Peaks 63.20,63.20
step
click Fjorn's Anvil##192071
turnin Hot and Cold##12981 |goto The Storm Peaks 63.20,62.90
step
click Hodir's Horn##192078
accept Hodir's Call##12977 |goto The Storm Peaks 64.10,65.10
step
kill Niffelem Forefather##29974+, Restless Frostborn Ghost##30144+
Use Hodir's Horn on their corpses|use Hodir's Horn##42164
Free 5 Niffelem Forefathers |q 12977/1 |goto The Storm Peaks 72.10,51.80
Free 5 Restless Frostborn |q 12977/2 |goto The Storm Peaks 72.10,51.80
step
click Hodir's Horn##192078
turnin Hodir's Call##12977 |goto The Storm Peaks 64.10,65.10
step
talk Njormeld##30127
accept Forging a Head##12985 |goto The Storm Peaks 63.20,63.20
step
talk King Jokkum##30105
accept Culling Jorcuttar##13011 |goto The Storm Peaks 65.40,60.20
step
Use your Diamond Tipped Pick on Dead Iron Giants|use Diamond Tipped Pick##42424
kill Stormforged Ambusher##30208+ |n
collect 8 Stormforged Eye##42423|q 12985/1 |goto The Storm Peaks 69.70,58.90
step
talk Njormeld##30127
turnin Forging a Head##12985 |goto The Storm Peaks 63.20,63.20
accept Placing Hodir's Helm##12987 |goto The Storm Peaks 63.20,63.20
step
Fly to the tip of this ice spike
Use the Tablets of Pronouncement in your bags|use Tablets of Pronouncement##42442
Mount Hodir's Helm |q 12987/1 |goto The Storm Peaks 64.30,59.20
step
talk Njormeld##30127
turnin Placing Hodir's Helm##12987 |goto The Storm Peaks 63.20,63.20
step
click Hodir's Helm##192080
accept A Viscious Cleaning##13006 |goto The Storm Peaks 64.20,59.20
step
kill Viscous Oil##30325+ |n
collect 5 Viscous Oil##42640|q 13006/1 |goto The Storm Peaks 55.60,63.40
Use your Everfrost Razor on Dead Icemaw Bears|use Everfrost Razor##42732
collect 1 Icemaw Bear Flank##42733|q 13011 |goto The Storm Peaks 55.60,63.40
step
Follow the path inside the cave to this spot
Use your Icemaw Bear Flank while standing on the small frozen pond with a bunch of rocks on it|use Icemaw Bear Flank##42733
kill 1 Jorcuttar##30340 |q 13011/1 |goto The Storm Peaks 54.70,60.80
step
talk Thorim##29445
turnin A New Beginning##13009 |goto The Storm Peaks 33.40,58
accept Veranus##13050 |goto The Storm Peaks 33.40,58
step
click Small Proto-Drake Egg##192536
collect 5 Small Proto-Drake Egg##42784|q 13050/1 |goto The Storm Peaks 43.70,67.40
You can find more Small Proto-Drake Eggs at [45.20,66.90] |n
step
talk Thorim##29445
turnin Veranus##13050 |goto The Storm Peaks 33.40,58
accept Territorial Trespass##13051 |goto The Storm Peaks 33.40,58
step
Stand in this big nest
Use the Stolen Proto-Dragon Eggs in your bags |use Stolen Proto-Dragon Eggs##42797
Lure Veranus |q 13051/1 |goto The Storm Peaks 38.70,65.60
step
talk Thorim##29445
turnin Territorial Trespass##13051 |goto The Storm Peaks 33.40,58
accept Krolmir, Hammer of Storms##13010 |goto The Storm Peaks 33.40,58
step
click Hodir's Helm##192080
turnin A Viscious Cleaning##13006 |goto The Storm Peaks 64.20,59.20
step
talk King Jokkum##30105
turnin Culling Jorcuttar##13011 |goto The Storm Peaks 65.40,60.20
step
talk King Jokkum##30105
Ask him what has become of Krolmir
Discover Krolmir's Fate |q 13010/1 |goto The Storm Peaks 65.40,60.20
step
talk Thorim##30390
turnin Krolmir, Hammer of Storms##13010 |goto The Storm Peaks 71.40,48.80
accept The Terrace of the Makers##13057 |goto The Storm Peaks 71.40,48.80
step
talk Thorim##30295
turnin The Terrace of the Makers##13057 |goto The Storm Peaks 56.30,51.40
accept The Earthen Oath##13005 |goto The Storm Peaks 56.30,51.40
accept Loken's Lackeys##13035 |goto The Storm Peaks 56.30,51.40
stickystart "irondwarf"
step
Use your Horn of the Peaks to summon earthen helpers|use Horn of the Peaks##42840
kill Eisenfaust##30341 |q 13035/1 |goto The Storm Peaks 55.30,43.30
step
Use your Horn of the Peaks to summon earthen helpers|use Horn of the Peaks##42840
kill Halefnir the Windborn##30376 |q 13035/2 |goto The Storm Peaks 48.60,45.60
step
Use your Horn of the Peaks to summon earthen helpers|use Horn of the Peaks##42840
kill Duronn the Runewrought##30353 |q 13035/3 |goto The Storm Peaks 45,38.10
step
label "irondwarf"
Use your Horn of the Peaks to summon earthen helpers|use Horn of the Peaks##42840
Fight mobs around this area
kill 7 Iron Sentinel##29984+ |q 13005/1 |goto The Storm Peaks 57.30,46.70
kill 20 Iron Dwarf Assailant##29978+ |q 13005/2 |goto The Storm Peaks 57.30,46.70
step
talk Thorim##30295
turnin The Earthen Oath##13005 |goto The Storm Peaks 56.30,51.40
turnin Loken's Lackeys##13035 |goto The Storm Peaks 56.30,51.40
accept The Reckoning##13047 |goto The Storm Peaks 56.30,51.40
step
talk Thorim##30399
Tell him you are with him
Witness the Reckoning |q 13047/1 |goto The Storm Peaks 35.90,31.50
step
talk King Jokkum##30105
turnin The Reckoning##13047 |goto The Storm Peaks 65.40,60.20
step
talk Ricket##29428
accept When All Else Fails##13060 |goto The Storm Peaks 40.90,85.30
step
talk Ricket##29428 |goto The Storm Peaks 40.90,85.30
Tell her you are ready to head further into Storm Peaks
You will fly to Grom'arsh Crash Site |goto The Storm Peaks 36.80,49.60 |noway |c
step
talk Olut Alegut##30472
turnin When All Else Fails##13060 |goto The Storm Peaks 37.00,49.60
step
talk Boktar Bloodfury##29651
accept The Missing Bronzebeard##12895 |goto The Storm Peaks 37.30,49.70
step
talk Archaeologist Andorin##29650
accept On Brann's Trail##12854 |goto The Storm Peaks 29.50,74.10
step
talk Peon Gakra##29944
home Grom'arsh Crash-Site |goto The Storm Peaks 37.10,49.50
step
talk Blood Guard Lorga##30247
accept Emergency Measures##13000 |goto The Storm Peaks 36.50,49.10
accept The Missing Tracker##13054 |goto The Storm Peaks 36.50,49.10
step
click Disturbed Snow##191708
collect Burlap-Wrapped Note##40947 |q 12895/1 |goto The Storm Peaks 36.10,64.10
step
Enter the cave here |goto The Storm Peaks 47.00,54.90 < 10 |walk
talk Tracker Val'zij##30469
turnin The Missing Tracker##13054 |goto The Storm Peaks 48.50,54.30
accept Cave Medicine##13055 |goto The Storm Peaks 48.50,54.30
step
click Cave Mushroom##192556
collect 8 Cave Mushroom##42926 |q 13055/1 |goto The Storm Peaks 49.30,52.80
step
kill Cavedweller Worg##30164+
collect 6 Worg Fur##42510 |q 13000/1 |goto The Storm Peaks 48.50,47.50
kill Infesting Jormungar##30148+
collect Toxin Gland##42927 |q 13055/2 |goto The Storm Peaks 48.50,47.50
step
talk Tracker Val'zij##30469
turnin Cave Medicine##13055 |goto The Storm Peaks 48.50,54.30
accept There's Always Time for Revenge##13056 |goto The Storm Peaks 48.50,54.30
step
kill Gimorak##30167 |q 13056/1 |goto The Storm Peaks 48.90,46.70
step
talk Tracker Val'zij##30469
turnin There's Always Time for Revenge##13056 |goto The Storm Peaks 48.50,54.30
step
talk Boktar Bloodfury##29651
turnin The Missing Bronzebeard##12895 |goto The Storm Peaks 37.30,49.70
accept The Nose Knows##12909 |goto The Storm Peaks 37.30,49.70
step
talk Blood Guard Lorga##30247
turnin Emergency Measures##13000 |goto The Storm Peaks 36.40,49.10
step
talk Khaliisi##29855
turnin The Nose Knows##12909 |goto The Storm Peaks 40.80,51.20
accept Sniffing Out the Perpetrator##12910 |goto The Storm Peaks 40.80,51.20
step
clicknpc Frostbite##29857
Use the abilities on your hotbar to slow down the _Steamforged Pursuers_.
Ride Frostbite until you reach the end of the scent trail. |q 12910/1 |goto The Storm Peaks 40.80,51.20
step
kill Tracker Thulin##29695+ |q 12910/2 |goto The Storm Peaks 48.50,60.80
collect Brann's Communicator##40971
step
Use Brann's Communicator in your bags. |use Brann's Communicator##40971
talk Brann Bronzebeard##29579
turnin Sniffing Out the Perpetrator##12910
accept Speak Orcish, Man!##12913
step
talk Moteha Windborn##29937
turnin Speak Orcish, Man!##12913 |goto The Storm Peaks 37.30,49.70
accept Speaking with the Wind's Voice##12917 |goto The Storm Peaks 37.30,49.70
step
kill Stormrider##29624+
collect 5 Voice of the Wind##41514 |q 12917/1 |goto The Storm Peaks 27.10,42.00
step
talk Moteha Windborn##29937
turnin Speaking with the Wind's Voice##12917 |goto The Storm Peaks 37.30,49.70
step
talk Boktar Bloodfury##29651
accept Catching up with Brann##12920 |goto The Storm Peaks 37.30,49.70
step
Use Brann's Communicator in your bags. |use Brann's Communicator##40971
talk Brann Bronzebeard##29579
Ask him if he can understand you. |q 12920/1
step
talk Boktar Bloodfury##29651
turnin Catching up with Brann##12920 |goto The Storm Peaks 37.30,49.70
accept Pieces of the Puzzle##12926 |goto The Storm Peaks 37.30,49.70
step
kill Library Guardian##29724 |n
collect 6 Inventor's Disk Fragment##41130 |n
Click the Inventor's Disk Fragments in your bags to combine them |use Inventor's Disk Fragment##41130
collect The Inventor's Disk##41132 |q 12926/1 |goto The Storm Peaks 37.60,43.50
step
Use Brann's Communicator in your bags |use Brann's Communicator##40971
talk Brann Bronzebeard##29579
turnin Pieces of the Puzzle##12926
accept Data Mining##12927
step
Use The Inventor's Disk on Databanks |use The Inventor's Disk##41179
|tip They look like floating round star things.
Gather 7 Hidden Data |q 12927/1 |goto The Storm Peaks 38.50,44.20
step
Use Brann's Communicator in your bags. |use Brann's Communicator##40971
talk Brann Bronzebeard##29579
turnin Data Mining##12927
accept The Library Console##13416
step
click Inventor's Library Console##191760
turnin The Library Console##13416 |goto The Storm Peaks 37.40,46.80
accept Norgannon's Shell##12928 |goto The Storm Peaks 37.40,46.80
step
Click the Charged Disk in your bags |use Charged Disk##44704
kill Archivist Mechaton##29775
collect Norgannon's Shell##41258 |q 12928/1 |goto The Storm Peaks 37.40,46.80
step
Use Brann's Communicator in your bags. |use Brann's Communicator##40971
talk Brann Bronzebeard##29579
turnin Norgannon's Shell##12928
accept Going After the Core##13273
accept The Earthen of Ulduar##12929
step
click Prospector Soren's Maps##193560
collect Prospector Soren's Maps##43983 |q 13273/2 |goto The Storm Peaks 59.20,51.50
step
click Prospector Khrona's Notes##193561
collect Prospector Khrona's Notes##43984 |q 13273/1 |goto The Storm Peaks 59.80,52.60
step
Use Brann's Communicator in your bags. |use Brann's Communicator##40971
talk Brann Bronzebeard##29579
turnin Going After the Core##13273
accept The Core's Keeper##13274
step
Enter Loken's Bargain here |goto The Storm Peaks 56.50,58.50 < 10 |walk
kill Athan##31798+
collect Norgannon's Core##41260 |q 13274/1 |goto The Storm Peaks 56.30,52.30
step
Use Brann's Communicator in your bags. |use Brann's Communicator##40971
talk Brann Bronzebeard##29579
turnin The Core's Keeper##13274
accept Forging the Keystone##13285
step
Leave Loken's Bargain here |goto The Storm Peaks 56.50,58.50 < 10 |walk
talk Brann Bronzebeard##29579
Tell him you're ready to make the keystone.
Help Brann create the keystone |q 13285/1 |goto The Storm Peaks 45.50,49.50
step
talk Boktar Bloodfury##29651
turnin Forging the Keystone##13285 |goto The Storm Peaks 37.30,49.70
step
Enter the building here |goto The Storm Peaks 30.60,36.90 < 10 |walk
talk Breck Rockbrow##29950
fpath Bouldercrag's Refuge |goto The Storm Peaks 30.60,36.30
step
talk Bouldercrag the Rockshaper##29801
turnin The Earthen of Ulduar##12929 |goto The Storm Peaks 31.40,38.00
accept Rare Earth##12930 |goto The Storm Peaks 31.40,38.00
step
kill Stormforged Pillager##29586+, Stormforged Loreseeker##29843+
collect 5 Frostweave Cloth##33470|q 12930/2 |goto The Storm Peaks 26.30,66.70
step
click Enchanted Earth##191845
|tip They're all over the mountain's side
collect 7 Enchanted Earth##41614|q 12930/1 |goto The Storm Peaks 28.30,29.40
step
kill Scourge Banner-Bearer##31900+
kill Converted Hero##32255+
collect 5 Frostweave Cloth##33470 |q 12930/2 |goto Icecrown 46.50,49.30
step
talk Bouldercrag the Rockshaper##29801
turnin Rare Earth##12930 |goto The Storm Peaks 31.40,38.00
accept Fighting Back##12931 |goto The Storm Peaks 31.40,38.00
accept Relief for the Fallen##12937 |goto The Storm Peaks 31.40,38.00
stickystart "steamattack"
step
Use your Telluric Poultice on _Fallen Earthen Defenders_ in this area. |use Telluric Poultice##41988
Heal 8 Fallen Earthen Defenders |q 12937/1 |goto The Storm Peaks 28.30,36.80
step
label "steamattack"
kill Stormforged Reaver##29382+, Stormforged Raider##29377+
Kill 10 Steamforged Attackers |q 12931/1 |goto The Storm Peaks 28.30,37.40
step
talk Bouldercrag the Rockshaper##29801
turnin Fighting Back##12931 |goto The Storm Peaks 31.40,38.00
turnin Relief for the Fallen##12937|goto The Storm Peaks 31.40,38.00
accept Slaves of the Stormforged##12957 |goto The Storm Peaks 31.40,38.00
accept The Dark Ore##12964 |goto The Storm Peaks 31.40,38.00
step
Enter the cave here |goto The Storm Peaks 27.40,49.80 < 10 |walk
click Ore Cart##192058
collect 5 Dark Ore Sample##42109 |q 12964/1 |goto The Storm Peaks 27.20,50.30
talk Captive Mechagnome##29384
Attempt to free Captive Mechagnome |q 12957/1 |goto The Storm Peaks 27.20,50.30
step
talk Captive Mechagnome##29384
turnin Slaves of the Stormforged##12957 |goto The Storm Peaks 31.40,38.00
turnin The Dark Ore##12964 |goto The Storm Peaks 31.40,38.00
accept The Gifts of Loken##12965 |goto The Storm Peaks 31.40,38.00
stickystart "nidavelirstorm"
step
click Loken's Fury##192120
Destroy Loken's Fury |q 12965/1 |goto The Storm Peaks 24.00,42.60
step
click Loken's Power##192121
Destroy Loken's Power |q 12965/2 |goto The Storm Peaks 26.20,47.70
step
click Loken's Favor##192122
Destroy Loken's Favor |q 12965/3 |goto The Storm Peaks 24.60,48.40
step
talk Bouldercrag the Rockshaper##29801
turnin The Gifts of Loken##12965 |goto The Storm Peaks 31.40,38.00
step
talk Bruor Ironbane##30152
accept Facing the Storm##12978 |goto The Storm Peaks 31.30,38.10
step
label "nidavelirstorm"
kill Stormforged War Golem##29380+, Stormforged Magus##29374+, Stormforged Champion##29370+
Kill 10 Nidavelir Stormforged |q 12978/1 |goto The Storm Peaks 24.70,42.70
collect 1 Dark Armor Plate##42203 |n
Click the Dark Armor Plate in your bags |use Dark Armor Plate##42203
accept Armor of Darkness##12979
step
kill Stormforged War Golem##29380+
collect 4 Dark Armor Sample##42204 |q 12979/1 |goto The Storm Peaks 24.70,42.70
step
talk Bruor Ironbane##30152
turnin Facing the Storm##12978 |goto The Storm Peaks 31.30,38.10
turnin Armor of Darkness##12979 |goto The Storm Peaks 31.30,38.10
accept The Armor's Secrets##12980 |goto The Storm Peaks 31.30,38.10
step
Enter Mimir's Workshop here |goto The Storm Peaks 33.60,39.60 < 5 |walk
talk Attendant Tock##30190
Ask him to tell him more about the armor plate. |q 12980/1 |goto The Storm Peaks 32.10,40.70
step
talk Bruor Ironbane##30152
turnin The Armor's Secrets##12980 |goto The Storm Peaks 31.30,38.10
step
talk Bouldercrag the Rockshaper##29801
accept Valduran the Stormborn##12984 |goto The Storm Peaks 31.40,38.00
step
Use Bouldercrag's Warhorn in this spot |use Bouldercrag's War Horn##42419
kill Valduran the Stormborn##29368+ |q 12984/1 |goto The Storm Peaks 24.40,52.10
step
talk Bouldercrag the Rockshaper##29801
turnin Valduran the Stormborn##12984 |goto The Storm Peaks 31.40,38.00
accept Destroy the Forges!##12988 |goto The Storm Peaks 31.40,38.00
step
talk Bruor Ironbane##30152
accept Hit Them Where it Hurts##12991 |goto The Storm Peaks 31.30,38.10
stickystart "stormforgedficer"
step
Use Bouldercrag's Bomb next to the Lightning Forge here. |use Bouldercrag's Bomb##42441
Damage the North Lightning Forge |q 12988/1 |goto The Storm Peaks 29.00,45.90
step
Use Bouldercrag's Bomb next to the Lightning Forge here. |use Bouldercrag's Bomb##42441
Damage the Central Lightning Forge |q 12988/2 |goto The Storm Peaks 29.60,45.90
step
Use Bouldercrag's Bomb next to the Lightning Forge here. |use Bouldercrag's Bomb##42441
Damage the Central Lightning Forge |q 12988/3 |goto The Storm Peaks 30.20,46.10
step
label "stormforgedficer"
kill Stormforged Artificer##29376+ |q 12991/1 |goto The Storm Peaks 29.30,46.00
step
talk Bruor Ironbane##30152
turnin Hit Them Where it Hurts##12991 |goto The Storm Peaks 31.30,38.10
step
talk Bouldercrag the Rockshaper##29801
turnin Destroy the Forges!##12988 |goto The Storm Peaks 31.40,38.00
accept A Colossal Threat##12993 |goto The Storm Peaks 31.40,38.00
step
click Colossus Defense Specs##192172
collect Colossus Defense Specs##42476 |q 12993/2 |goto The Storm Peaks 29.90,45.90
step
click Colossus Attack Specs##192171
collect Colossus Attack Specs##42475 |q 12993/1 |goto The Storm Peaks 28.90,44.10
step
talk Bouldercrag the Rockshaper##29801
turnin A Colossal Threat##12993 |goto The Storm Peaks 31.40,38.00
accept The Heart of the Storm##12998 |goto The Storm Peaks 31.40,38.00
step
Enter Uldis here |goto The Storm Peaks 32.40,63.60 < 10 |walk
click The Heart of the Storm##192181
Attempt to secure the Heart of the Swarm |q 12998/1 |goto The Storm Peaks 36.10,60.90
step
talk Bouldercrag the Rockshaper##29801
turnin The Heart of the Storm##12998 |goto The Storm Peaks 31.40,38.00
accept The Iron Colossus##13007 |goto The Storm Peaks 31.40,38.00
step
Click the shining orb in front of you to take control of a _Tamed Jormungar_. |goto The Storm Peaks 27.20,35.90
|confirm
step
Use the abilities on your hotbar to kill the Iron Colossus.
kill Iron Colossus##30300+ |q 13007/1 |goto The Storm Peaks 27.30,45.70
step
talk Bouldercrag the Rockshaper##29801
turnin The Iron Colossus##13007 |goto The Storm Peaks 31.40,38.00
step
label "Daily"
click Hodir's Helm##192080
accept A Viscious Cleaning##13006 |goto The Storm Peaks,64.20,59.20
step
talk Lorekeeper Randvir##30252
accept Forging Hodir's Spear##13001 |goto The Storm Peaks,64.80,59.10
only if rep ('The Sons of Hodir')>=Honored
step
click Fjorn's Anvil##192071
accept Hot and Cold##12981 |goto The Storm Peaks 63.20,62.90
step
click Hodir's Horn##192078
accept Hodir's Call##12977 |goto The Storm Peaks 64.10,65.10
stickystart "vioil"
step
kill Stoic Mammoth##30260+
collect 3 Stoic Mammoth Hide##42542 |q 13001/2 |goto The Storm Peaks 59.00,61.20
only if rep ('The Sons of Hodir')>=Honored
step
label "vioil"
kill Viscous Oil##30325+
collect 5 Viscous Oil##42640 |q 13006/1 |goto The Storm Peaks 55.60,63.40
step
The entrance to the cave starts here |goto The Storm Peaks 55.90,64.20 < 10 |c
only if rep ('The Sons of Hodir')>=Honored
step
click Everfrost Shard##192191
collect 3 Everfrost Shard##42541 |q 13001/1 |goto The Storm Peaks 54.70,60.80
only if rep ('The Sons of Hodir')>=Honored
step
Leave the cave |goto The Storm Peaks 55.90,64.20 < 10 |c
only if rep ('The Sons of Hodir')>=Honored
step
talk Lorekeeper Randvir##30252
turnin Forging Hodir's Spear##13001 |goto The Storm Peaks 64.80,59.10
|tip This quest will unlock the How to Slay Your Dragon daily quest.
only if rep ('The Sons of Hodir')>=Honored
step
click Hodir's Helm##192080
turnin A Viscious Cleaning##13006 |goto The Storm Peaks 64.20,59.20
step
kill Brittle Revenant##30160+
collect 6 Essence of Ice##42246 |q 12981 |goto The Storm Peaks 69.70,60.20
step
Use your Essences of Ice next to Smoldering Scraps |use Essence of Ice##42246
|tip The Smoldering Scraps look like small smoking pieces of metal on the ground around this area.
click Frozen Iron Scrap##192127
collect 6 Frozen Iron Scrap##42252 |q 12981/1 |goto The Storm Peaks 75.30,62.80
step
kill Niffelem Forefather##29974+, Restless Frostborn Ghost##30144+
Use Hodir's Horn on their corpses |use Hodir's Horn##42164
Free 5 Niffelem Forefathers |q 12977/1 |goto The Storm Peaks 72.10,51.80
Free 5 Restless Frostborn |q 12977/2 |goto The Storm Peaks 72.10,51.80
step
If you want to grind mobs for Relics of Ulduar, or buy them on the Auction House, to turn in for The Sons of Hodir reputation, this is an awesome spot, as these mobs drop the Relics of Ulduar frequently. You get 650 The Sons of Hodir reputation for every 10 Relics of Ulduar you collect. If you don't want to do this, skip this step.
kill Scion of Storm##30184+ |goto The Storm Peaks 67.00,45.10
|tip They are air elementals all around inside this big cave.
You can also buy the Relics of Ulduar on the Auction House, if you'd like to get the reputation much faster.
collect Relic of Ulduar##42780+|n |goto The Storm Peaks 67.00,45.10
|tip You turn these in in multiples of 10.
|confirm
step
click Fjorn's Anvil##192071
turnin Hot and Cold##12981 |goto The Storm Peaks 63.20,62.90
step
click Hodir's Horn##192078
turnin Hodir's Call##12977 |goto The Storm Peaks 64.10,65.10
step
talk Lillehoff##32540
accept Hodir's Tribute##13559 |goto The Storm Peaks 66.20,61.40
|tip This is a repeatable quest. Turn in all of your Relics of Ulduar.
step
Click here to reset the daily quests. |confirm |next "Daily" |only if rep('The Sons of Hodir')<=Friendly
Become honored with The Sons of Hodir |complete rep('The Sons of Hodir')>=Honored |next "Daily2"
step
label "Daily2"
talk Frostworg Denmother##30294
accept Spy Hunter##12994 |goto The Storm Peaks,63.50,59.80
step
click Hodir's Helm##192080
accept A Viscious Cleaning##13006 |goto The Storm Peaks 64.20,59.20
step
click Hodir's Spear##192079
accept How to Slay Your Dragon##13003 |goto The Storm Peaks 65.10,60.80
step
click Fjorn's Anvil##192071
accept Hot and Cold##12981 |goto The Storm Peaks 63.20,62.90
step
click Hodir's Horn##192078
accept Hodir's Call##12977 |goto The Storm Peaks 64.10,65.10
stickystart "vioil2"
step
Use your Ethereal Worg's Fang next to the Corpse of the Fallen Worg |use Ethereal Worg's Fang##42479
Follow the wolf that spawns and kill the Stormforged Infiltrator it finds
Repeat this process 2 more times
Kill 3 Stormforged Infiltrators |q 12994/1 |goto The Storm Peaks 57.20,64.00
step
Use the Spear of Hodir on a Wild Wyrm flying around in the sky |use Spear of Hodir##42769
While fighting the Wild Wyrm, there will be 2 phases to the fight. Phase 1:
|tip In phase 1 of the fight, you will be underneath the Wild Wyrm. Use your Grab On ability to keep your grip high, or you will fall off and die. Repeatedly use your Thrust Spear ability, until you get a message the Wild Wyrm is about to use its claw attack. When you see that message, use your Dodge Claws ability, and then immediately use your Mighty Spear Thrust ability after that. Remember to keep your grip up by using your Grab On ability, and repeat this process until phase 2 of the fight begins.
In phase 2 of the fight with the Wild Wyrm, the strategy changes:
|tip In phase 2 of the fight, you will be inside the Wild Wyrm's mouth. Repeatedly use your Pry Jaws Open ability, try to stack it 20 times. After you stack your Pry Jaws ability 20 times (which will give your Fatal Strike ability 100% chance to hit), use your Fatal Strike ability to kill the Wild Wyrm. If you are close to dying, just stack your Pry Jaws Open ability as many times as you can, then use your Fatal Strike ability before you die, and hope it kills the Wild Wyrm.
Kill the Wild Wyrm |q 13003/1 |goto The Storm Peaks 56.60,64.30
step
label "vioil2"
kill Viscous Oil##30325+
|tip They look like slimes inside this cave.
collect 5 Viscous Oil##42640 |q 13006/1 |goto The Storm Peaks 55.60,63.40
step
talk Frostworg Denmother##30294
turnin Spy Hunter##12994 |goto The Storm Peaks 63.50,59.80
step
click Hodir's Helm##192080
turnin A Viscious Cleaning##13006 |goto The Storm Peaks 64.20,59.20
step
click Hodir's Spear##192079
turnin How to Slay Your Dragon##13003 |goto The Storm Peaks 65.10,60.80
step
kill Brittle Revenant##30160+
collect 6 Essence of Ice##42246 |q 12981 |goto The Storm Peaks 69.70,60.20
step
Use your Essences of Ice next to Smoldering Scraps |use Essence of Ice##42246
|tip The Smoldering Scraps look like small smoking pieces of metal on the ground around this area.
Click the Frozen Iron Scraps
collect 6 Frozen Iron Scrap##42252 |q 12981/1 |goto The Storm Peaks 75.30,62.80
step
kill Niffelem Forefather##29974+, Restless Frostborn Ghost##30144+
Use Hodir's Horn on their corpses |use Hodir's Horn##42164
Free 5 Niffelem Forefathers |q 12977/1 |goto The Storm Peaks 72.10,51.80
Free 5 Restless Frostborn |q 12977/2 |goto The Storm Peaks 72.10,51.80
step
If you want to grind mobs for Relics of Ulduar, or buy them on the Auction House, to turn in for The Sons of Hodir reputation, this is an awesome spot, as these mobs drop the Relics of Ulduar frequently. You get 650 The Sons of Hodir reputation for every 10 Relics of Ulduar you collect. If you don't want to do this, skip this step.
kill Scion of Storm##30184+ |goto The Storm Peaks 67.00,45.10
|tip They are air elementals all around inside this big cave.
You can also buy the Relics of Ulduar on the Auction House, if you'd like to get the reputation much faster.
collect Relic of Ulduar##42780+|n |goto The Storm Peaks 67.00,45.10
|tip You turn these in in multiples of 10.
|confirm
step
click Fjorn's Anvil##192071
turnin Hot and Cold##12981 |goto The Storm Peaks 63.20,62.90
step
click Hodir's Horn##192078
turnin Hodir's Call##12977 |goto The Storm Peaks 64.10,65.10
step
talk Lillehoff##32540
accept Hodir's Tribute##13559 |goto The Storm Peaks 66.20,61.40
|tip This is a repeatable quest. Turn in all of your Relics of Ulduar.
step
In order to repeat these daily quests, click here to reset the daillies. |confirm |next "Daily2" |only if rep('The Sons of Hodir')<=Honored
Become Revered with The Sons of Hodir |complete rep('The Sons of Hodir')>=Revered |next "Daily3"
step
label "Daily3"
talk Frostworg Denmother##30294
accept Spy Hunter##12994 |goto The Storm Peaks,63.50,59.80
step
click Hodir's Helm##192080
accept A Viscious Cleaning##13006 |goto The Storm Peaks 64.20,59.20
step
click Hodir's Spear##192079
accept How to Slay Your Dragon##13003 |goto The Storm Peaks 65.10,60.80
step
click Arngrim the Insatiable##192524
accept Feeding Arngrim##13046 |goto The Storm Peaks 67.60,59.90
step
click Fjorn's Anvil##192071
accept Hot and Cold##12981 |goto The Storm Peaks 63.20,62.90
step
click Hodir's Horn##192078
accept Hodir's Call##12977 |goto The Storm Peaks 64.10,65.10
stickystart "vioil3"
step
Use your Ethereal Worg's Fang next to the Corpse of the Fallen Worg |use Ethereal Worg's Fang##42479
Follow the wolf that spawns and kill the Stormforged Infiltrator it finds
Repeat this process 2 more times
Kill 3 Stormforged Infiltrators |q 12994/1 |goto The Storm Peaks 57.20,64.00
step
Use Arngrim's Tooth on Roaming Jormungars |use Arngrim's Tooth##42774
Fight Disembodied Jormungars until Arngrim the Insatiable comes to eat them
Feed Arngrim's Spirit 5 Times |q 13046/1 |goto The Storm Peaks 56.40,65.00
step
Use the Spear of Hodir on a Wild Wyrm flying around in the sky |use Spear of Hodir##42769
While fighting the Wild Wyrm, there will be 2 phases to the fight. Phase 1:
|tip In phase 1 of the fight, you will be underneath the Wild Wyrm. Use your Grab On ability to keep your grip high, or you will fall off and die. Repeatedly use your Thrust Spear ability, until you get a message the Wild Wyrm is about to use its claw attack. When you see that message, use your Dodge Claws ability, and then immediately use your Mighty Spear Thrust ability after that. Remember to keep your grip up by using your Grab On ability, and repeat this process until phase 2 of the fight begins.
In phase 2 of the fight with the Wild Wyrm, the strategy changes:
|tip In phase 2 of the fight, you will be inside the Wild Wyrm's mouth. Repeatedly use your Pry Jaws Open ability, try to stack it 20 times. After you stack your Pry Jaws ability 20 times (which will give your Fatal Strike ability 100% chance to hit), use your Fatal Strike ability to kill the Wild Wyrm. If you are close to dying, just stack your Pry Jaws Open ability as many times as you can, then use your Fatal Strike ability before you die, and hope it kills the Wild Wyrm.
Kill the Wild Wyrm |q 13003/1 |goto The Storm Peaks 56.60,64.30
step
label "vioil3"
kill Viscous Oil##30325+
|tip They look like slimes inside this cave.
collect 5 Viscous Oil##42640 |q 13006/1 |goto The Storm Peaks 55.60,63.40
step
talk Frostworg Denmother##30294
turnin Spy Hunter##12994 |goto The Storm Peaks 63.50,59.80
step
click Hodir's Helm##192080
turnin A Viscious Cleaning##13006 |goto The Storm Peaks 64.20,59.20
step
click Hodir's Spear##192079
turnin How to Slay Your Dragon##13003 |goto The Storm Peaks 65.10,60.80
step
click Arngrim the Insatiable##192524
turnin Feeding Arngrim##13046 |goto The Storm Peaks 67.60,59.90
step
kill Brittle Revenant##30160+
collect 6 Essence of Ice##42246 |q 12981 |goto The Storm Peaks 69.70,60.20
step
Use your Essences of Ice next to Smoldering Scraps |use Essence of Ice##42246
|tip The Smoldering Scraps look like small smoking pieces of metal on the ground around this area.
Click the Frozen Iron Scraps
collect 6 Frozen Iron Scrap##42252 |q 12981/1 |goto The Storm Peaks 75.30,62.80
step
kill Niffelem Forefather##29974+, Restless Frostborn Ghost##30144+
Use Hodir's Horn on their corpses |use Hodir's Horn##42164
Free 5 Niffelem Forefathers |q 12977/1 |goto The Storm Peaks 72.10,51.80
Free 5 Restless Frostborn |q 12977/2 |goto The Storm Peaks 72.10,51.80
step
If you want to grind mobs for Relics of Ulduar, or buy them on the Auction House, to turn in for The Sons of Hodir reputation, this is an awesome spot, as these mobs drop the Relics of Ulduar frequently. You get 650 The Sons of Hodir reputation for every 10 Relics of Ulduar you collect. If you don't want to do this, skip this step.
kill Scion of Storm##30184+ |goto The Storm Peaks 67.00,45.10
|tip They are air elementals all around inside this big cave.
You can also buy the Relics of Ulduar on the Auction House, if you'd like to get the reputation much faster.
collect Relic of Ulduar##42780+ |n |goto The Storm Peaks 67.00,45.10
|tip You turn these in in multiples of 10.
|confirm
step
click Fjorn's Anvil##192071
turnin Hot and Cold##12981 |goto The Storm Peaks 63.20,62.90
step
click Hodir's Horn##192078
turnin Hodir's Call##12977 |goto The Storm Peaks 64.10,65.10
step
talk Lillehoff##32540
accept Hodir's Tribute##13559 |goto The Storm Peaks 66.20,61.40
|tip This is a repeatable quest. Turn in all of your Relics of Ulduar.
step
To restart the Hodir daily quests, click here. |confirm |next "Daily3" |only if rep('The Sons of Hodir')<=Revered
Become Exalted with The Sons of Hodir |complete rep('The Sons of Hodir')==Exalted
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Wrath of the Lich King Reputations\\The Wyrmrest Accord")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Cataclysm Reputations\\Avengers of Hyjal")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Cataclysm Reputations\\The Earthen Ring")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Cataclysm Reputations\\Ramkahen")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Cataclysm Reputations\\Dragonmaw Clan")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Cataclysm Reputations\\Hellscream's Reach")
