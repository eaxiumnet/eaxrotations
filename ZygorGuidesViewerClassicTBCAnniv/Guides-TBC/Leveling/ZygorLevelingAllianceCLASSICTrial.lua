local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Alliance" then return end
if ZGV:DoMutex("LevelingACLASSIC") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuide("Leveling Guides\\Starter Guides (1-11)\\Human Starter (1-11)",{
image=ZGV.IMAGESDIR.."Elwynn Forest",
condition_suggested=function() return raceclass('Human') and level <= 11 end,
condition_suggested_exclusive=true,
condition_visible=function() return Human end,
linked = {"Leveling Guides\\Hidden Guides"},
linkedhidden = true,
next="Leveling Guides\\Classic (11-60)\\Darkshore (11-14)",
},[[
defaultfor Human
step
_NOTE:_
Wrong Character Race
|tip Guide written for {o}Human{} characters.
|tip Other races may encounter issues.
Click Here to Continue |confirm
|only if not Human
step
_Destroy This Item:_
|tip Saves bag space.
|tip You'll get one later.
trash Hearthstone##6948	|q 783 |future
step
kill Young Wolf##299+
|tip Loot items worth at least {o}10 copper{} to sell.
|tip Allows training a spell early.
|tip Increases leveling speed.
Click to continue |confirm |goto Elwynn Forest/0 45.20,42.40 |q 783 |future
|mapmarker Elwynn Forest/0 46.00,36.40
|mapmarker Elwynn Forest/0 46.80,39.60
|mapmarker Elwynn Forest/0 47.40,46.80
|mapmarker Elwynn Forest/0 49.40,37.40
|mapmarker Elwynn Forest/0 50.40,44.20
|mapmarker Elwynn Forest/0 51.80,41.20
|only if Warrior or Warlock
step
talk Brother Danil##152
Sell Items |vendor Brother Danil##152 |goto Elwynn Forest/0 47.49,41.56 |q 783 |future
|only if Warrior or Warlock
step
talk Drusilla La Salle##459
|tip Outside next to the building.
Train Abilities |trainer Drusilla La Salle##459 |goto Elwynn Forest 49.87,42.65 |q 1598 |future
|only if Human Warlock
step
talk Drusilla La Salle##459
|tip Outside next to the building.
accept The Stolen Tome##1598 |goto Elwynn Forest 49.87,42.65
|only if Human Warlock
step
click Stolen Books
|tip Ignore enemies and {o}run inside the tent{}.
|tip Enemies can't hit you.
|tip Zoom camera out.
|tip From inside, click the {o}book pile (right side){} outside.
|tip You'll die on purpose after.
collect Powers of the Void##6785 |q 1598/1 |goto Elwynn Forest 56.74,43.77
|only if Human Warlock
step
Allow Enemies to Kill You
|tip Stand in the fire to die faster.
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Elwynn Forest 56.48,43.92 |q 1598
|only if Human Warlock
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Elwynn Forest 49.53,43.49 |q 1598 |zombiewalk
|only if Human Warlock
step
talk Drusilla La Salle##459
|tip Outside next to the building.
turnin The Stolen Tome##1598 |goto Elwynn Forest 49.87,42.65
|only if Human Warlock
step
Summon Your Imp |complete warlockpet("Imp") |q 783 |future
|tip Use the {o}Summon Imp{} ability.
|only if Human Warlock
step
talk Deputy Willem##823
accept A Threat Within##783 |goto Elwynn Forest 48.17,42.95
step
talk Marshal McBride##197
|tip Inside the building.
turnin A Threat Within##783 |goto Elwynn Forest 48.92,41.61
accept Kobold Camp Cleanup##7 |goto Elwynn Forest 48.92,41.61
step
talk Llane Beshere##911
|tip {o}Ground floor{} inside the building.
Train Abilities |trainer Llane Beshere##911 |goto Elwynn Forest/0 50.24,42.29 |q 7
|only if Warrior
step
talk Deputy Willem##823
accept Eagan Peltskinner##5261 |goto Elwynn Forest 48.17,42.95
step
talk Eagan Peltskinner##196
|tip Outside the building.
turnin Eagan Peltskinner##5261 |goto Elwynn Forest 48.94,40.16
accept Wolves Across the Border##33 |goto Elwynn Forest 48.94,40.16
step
kill Timber Wolf##69, Young Wolf##299
collect 8 Tough Wolf Meat##750 |q 33/1 |goto Elwynn Forest 46.80,39.60
|mapmarker Elwynn Forest/0 45.20,42.40
|mapmarker Elwynn Forest/0 46.00,36.40
|mapmarker Elwynn Forest/0 47.40,46.80
|mapmarker Elwynn Forest/0 49.40,37.40
|mapmarker Elwynn Forest/0 50.40,44.20
|mapmarker Elwynn Forest/0 51.80,41.20
step
kill 10 Kobold Vermin##6 |q 7/1 |goto Elwynn Forest 48.00,37.60
|mapmarker Elwynn Forest/0 47.40,35.00
|mapmarker Elwynn Forest/0 49.40,35.40
|mapmarker Elwynn Forest/0 50.20,37.40
step
talk Eagan Peltskinner##196
turnin Wolves Across the Border##33 |goto Elwynn Forest 48.94,40.16
step
talk Marshal McBride##197
|tip Inside the building.
turnin Kobold Camp Cleanup##7		|goto Elwynn Forest 48.92,41.61
accept Investigate Echo Ridge##15	|goto Elwynn Forest 48.92,41.61
step
kill 10 Kobold Worker##257 |q 15/1 |goto Elwynn Forest 47.40,37.00
|mapmarker Elwynn Forest/0 46.40,32.40
|mapmarker Elwynn Forest/0 47.20,35.00
|mapmarker Elwynn Forest/0 48.80,33.00
|mapmarker Elwynn Forest/0 49.20,35.20
|mapmarker Elwynn Forest/0 50.40,37.20
step
Kill enemies
|tip Helps reach level 4 after quest turnins.
ding 3,1110 |goto Elwynn Forest 47.40,37.00
|mapmarker Elwynn Forest/0 46.40,32.40
|mapmarker Elwynn Forest/0 47.20,35.00
|mapmarker Elwynn Forest/0 48.80,33.00
|mapmarker Elwynn Forest/0 49.20,35.20
|mapmarker Elwynn Forest/0 50.40,37.20
step
talk Marshal McBride##197
|tip Inside the building.
turnin Investigate Echo Ridge##15 |goto Elwynn Forest 48.92,41.61
accept Skirmish at Echo Ridge##21 |goto Elwynn Forest 48.92,41.61
accept Glyphic Letter##3104		|goto Elwynn Forest 48.92,41.61		|only if Human Mage
accept Simple Letter##3100		|goto Elwynn Forest 48.92,41.61		|only if Human Warrior
accept Tainted Letter##3105		|goto Elwynn Forest 48.92,41.61		|only if Human Warlock
accept Encrypted Letter##3102		|goto Elwynn Forest 48.92,41.61		|only if Human Rogue
accept Hallowed Letter##3103		|goto Elwynn Forest 48.92,41.61		|only if Human Priest
accept Consecrated Letter##3101		|goto Elwynn Forest 48.92,41.61		|only if Human Paladin
step
talk Llane Beshere##911
|tip {o}Ground floor{} inside the building.
turnin Simple Letter##3100 |goto Elwynn Forest 50.24,42.28
|only if Human Warrior
step
talk Llane Beshere##911
|tip {o}Ground floor{} inside the building.
Train Abilities |trainer Llane Beshere##911 |goto Elwynn Forest 50.24,42.28 |q 18 |future
|only if Human Warrior
step
talk Brother Sammuel##925
|tip {o}Ground floor{} inside the building.
turnin Consecrated Letter##3101 |goto Elwynn Forest 50.43,42.12
|only if Human Paladin
step
talk Brother Sammuel##925
|tip {o}Ground floor{} inside the building.
Train Abilities |trainer Brother Sammuel##925 |goto Elwynn Forest 50.43,42.12 |q 18 |future
|only if Human Paladin
step
talk Priestess Anetta##375
|tip {o}Ground floor{} inside the building.
turnin Hallowed Letter##3103 |goto Elwynn Forest 49.81,39.49
|only if Human Priest
step
talk Priestess Anetta##375
|tip {o}Ground floor{} inside the building.
Train Abilities |trainer Priestess Anetta##375 |goto Elwynn Forest 49.81,39.49 |q 18 |future
|only if Human Priest
step
talk Khelden Bremen##198
|tip {o}Middle floor{} inside the building.
turnin Glyphic Letter##3104 |goto Elwynn Forest 49.66,39.41
|only if Human Mage
step
talk Khelden Bremen##198
|tip {o}Middle floor{} inside the building.
Train Abilities |trainer Khelden Bremen##198 |goto Elwynn Forest 49.66,39.41 |q 18 |future
|only if Human Mage
step
talk Deputy Willem##823
accept Brotherhood of Thieves##18 |goto Elwynn Forest 48.17,42.93
step
talk Drusilla La Salle##459
|tip Outside next to the building.
turnin Tainted Letter##3105 |goto Elwynn Forest 49.87,42.65
|only if Human Warlock
step
talk Drusilla La Salle##459
|tip Outside next to the building.
Train Abilities |trainer Drusilla La Salle##459 |goto Elwynn Forest 49.87,42.65 |q 18
|only if Human Warlock
step
label "Collect_Red_Burlap_Bandanas"
kill Defias Thug##38+
collect 12 Red Burlap Bandana##752 |q 18/1 |goto Elwynn Forest 51.40,47.00
|mapmarker Elwynn Forest/0 51.40,50.40
|mapmarker Elwynn Forest/0 53.80,44.40
|mapmarker Elwynn Forest/0 54.00,52.00
|mapmarker Elwynn Forest/0 54.20,40.40
|mapmarker Elwynn Forest/0 54.20,48.60
|mapmarker Elwynn Forest/0 57.00,42.40
|mapmarker Elwynn Forest/0 57.40,48.20
step
talk Deputy Willem##823
|tip Outside the building.
turnin Brotherhood of Thieves##18 |goto Elwynn Forest 48.17,42.94
accept Milly Osworth##3903 |goto Elwynn Forest 48.17,42.94
accept Bounty on Garrick Padfoot##6 |goto Elwynn Forest 48.17,42.94
step
kill 12 Kobold Laborer##80 |q 21/1 |goto Elwynn Forest 47.67,31.86
|tip Inside the mine.
|mapmarker Elwynn Forest/0 47.40,30.20
|mapmarker Elwynn Forest/0 48.40,26.60
|mapmarker Elwynn Forest/0 49.00,29.00
step
Kill enemies
|tip Inside and outside the mine.
ding 5 |goto Elwynn Forest 47.67,31.86
|mapmarker Elwynn Forest/0 47.40,30.20
|mapmarker Elwynn Forest/0 48.40,26.60
|mapmarker Elwynn Forest/0 49.00,29.00
|mapmarker Elwynn Forest/0 47.40,37.00
|mapmarker Elwynn Forest/0 46.40,32.40
|mapmarker Elwynn Forest/0 47.20,35.00
|mapmarker Elwynn Forest/0 48.80,33.00
|mapmarker Elwynn Forest/0 49.20,35.20
|mapmarker Elwynn Forest/0 50.40,37.20
step
Leave the mine |goto Elwynn Forest 47.66,31.89 < 15 |walk |only if subzone("Echo Ridge Mine") and indoors()
talk Milly Osworth##9296
|tip Outside, behind the building.
turnin Milly Osworth##3903 |goto Elwynn Forest 50.69,39.35
accept Milly's Harvest##3904 |goto Elwynn Forest/0 50.69,39.35
step
talk Jorik Kerridan##915
|tip Inside the building.
turnin Encrypted Letter##3102 |goto Elwynn Forest 50.31,39.92
|only if Human Rogue
step
talk Jorik Kerridan##915
|tip Inside the building.
Train Abilities |trainer Jorik Kerridan##915 |goto Elwynn Forest 50.31,39.92 |q 6
|only if Human Rogue
step
kill Garrick Padfoot##103
collect Garrick's Head##182 |q 6/1 |goto Elwynn Forest 57.51,48.25
step
click Milly's Harvest+
|tip Wooden buckets.
|tip Skip if too crowded.
collect 8 Milly's Harvest##11119 |q 3904/1 |goto Elwynn Forest/0 55.10,49.00
|mapmarker Elwynn Forest/0 53.30,48.90
|mapmarker Elwynn Forest/0 53.40,47.60
|mapmarker Elwynn Forest/0 53.90,50.40
step
Abandon {y}Milly's Harvest{} Quest |complete not haveq(3904)
|tip Not needed.
|only if not readyq(3904) or completedq(3904)
step
Kill enemies
|tip Helps reach level 6 after quest turnins.
ding 5,1700 |goto Elwynn Forest 51.40,47.00
|mapmarker Elwynn Forest/0 51.40,50.40
|mapmarker Elwynn Forest/0 53.80,44.40
|mapmarker Elwynn Forest/0 54.00,52.00
|mapmarker Elwynn Forest/0 54.20,40.40
|mapmarker Elwynn Forest/0 54.20,48.60
|mapmarker Elwynn Forest/0 57.00,42.40
|mapmarker Elwynn Forest/0 57.40,48.20
step
talk Milly Osworth##9296
|tip Outside, behind the building.
turnin Milly's Harvest##3904 |goto Elwynn Forest 50.69,39.35
|only if readyq(3904) or completedq(3904)
step
talk Milly Osworth##9296
|tip Outside, behind the building.
accept Grape Manifest##3905 |goto Elwynn Forest/0 50.69,39.35
|only if completedq(3904)
step
talk Deputy Willem##823
turnin Bounty on Garrick Padfoot##6 |goto Elwynn Forest 48.17,42.94
step
talk Marshal McBride##197
|tip Inside the building.
turnin Skirmish at Echo Ridge##21 |goto Elwynn Forest 48.92,41.61
accept Report to Goldshire##54 |goto Elwynn Forest 48.92,41.61
step
talk Priestess Anetta##375
|tip {o}Ground floor{} inside the building.
accept In Favor of the Light##5623 |goto Elwynn Forest 49.81,39.49
|only if Human Priest
step
talk Brother Neals##952
|tip {o}Top floor{} inside the building.
turnin Grape Manifest##3905 |goto Elwynn Forest/0 49.47,41.59
|only if readyq(3905) or completedq(3905)
step
talk Falkhaan Isenstrider##6774
accept Rest and Relaxation##2158 |goto Elwynn Forest 45.56,47.74
step
talk Marshal Dughan##240
turnin Report to Goldshire##54 |goto Elwynn Forest 42.11,65.93
accept The Fargodeep Mine##62 |goto Elwynn Forest 42.11,65.93
step
talk William Pestle##253
|tip Inside the building.
accept Kobold Candles##60 |goto Elwynn Forest 43.32,65.70
step
talk Innkeeper Farley##295
|tip Inside the building.
turnin Rest and Relaxation##2158 |goto Elwynn Forest 43.77,65.81
step
talk Maximillian Crowe##906
|tip Downstairs inside the building.
Train Abilities |trainer Maximillian Crowe##906 |goto Elwynn Forest 44.39,66.24 |q 47 |future
|only if Warlock
step
talk Cylina Darkheart##6374
|tip Buy available Grimoires.
|tip Downstairs inside the building.
Train Demon Abilities |vendor Cylina Darkheart##6374 |goto Elwynn Forest 44.40,65.99 |q 47 |future
|only if Warlock
step
talk Zaldimar Wefhellt##328
|tip Upstairs inside the building.
Train Abilities |trainer Zaldimar Wefhellt##328 |goto Elwynn Forest 43.25,66.19 |q 47 |future
|only if Mage
step
talk Priestess Josetta##377
|tip Upstairs inside the building.
turnin In Favor of the Light##5623 |goto Elwynn Forest 43.28,65.72
accept Garments of the Light##5624 |goto Elwynn Forest 43.28,65.72
|only if Human Priest
step
talk Priestess Josetta##377
|tip Upstairs inside the building.
Train Abilities |trainer Priestess Josetta##377 |goto Elwynn Forest 43.28,65.72 |q 47 |future
|only if Priest
step
Heal and Fortify Guard Roberts |q 5624/1 |goto Elwynn Forest 47.01,66.76
|tip Cast {o}Lesser Heal (Rank 2){} on Guard Roberts.
|tip Cast {o}Power Word: Fortitude{} on Guard Roberts.
|only if Human Priest
step
talk Priestess Josetta##377
|tip Upstairs inside the building.
turnin Garments of the Light##5624 |goto Elwynn Forest 43.28,65.72
|only if Human Priest
step
talk Keryn Sylvius##917
|tip Upstairs inside the building.
Train Abilities |trainer Keryn Sylvius##917 |goto Elwynn Forest 43.87,65.94 |q 47 |future
|only if Rogue
step
talk Michelle Belle##2329
|tip Upstairs inside the building.
Train First Aid |skillmax First Aid,75 |goto Elwynn Forest 43.39,65.55
|tip If possible.
step
_NOTE:_
Create Bandages in Downtime
|tip While waiting for things like boats.
|tip Increases skill in First Aid.
|tip Need higher skill to make better bandages.
|tip Keep bandages to heal yourself.
Click Here to Continue |confirm |q 60
step
talk Brother Wilhelm##927
Train Abilities |trainer Brother Wilhelm##927 |goto Elwynn Forest 41.10,66.04 |q 47 |future
|only if Paladin
step
talk Lyria Du Lac##913
Train Abilities |trainer Lyria Du Lac##913 |goto Elwynn Forest 41.08,65.77 |q 47 |future
|only if Warrior
step
talk Remy "Two Times"##241
accept Gold Dust Exchange##47 |goto Elwynn Forest 42.14,67.26
stickystart "Collect_Chunks_Of_Boar_Meat"
step
talk "Auntie" Bernice Stonefield##246
accept Lost Necklace##85 |goto Elwynn Forest 34.48,84.26
step
talk Billy Maclure##247
turnin Lost Necklace##85 |goto Elwynn Forest 43.13,85.72
accept Pie for Billy##86 |goto Elwynn Forest 43.13,85.72
step
talk Maybell Maclure##251
|tip Inside the building.
accept Young Lovers##106 |goto Elwynn Forest 43.15,89.62
step
label "Collect_Chunks_Of_Boar_Meat"
kill Stonetusk Boar##113+
collect 4 Chunk of Boar Meat##769 |q 86/1 |goto Elwynn Forest 41.86,87.12 |future
|tip Don't vendor them.
step
talk Tommy Joe Stonefield##252
turnin Young Lovers##106 |goto Elwynn Forest 29.84,85.99
accept Speak with Gramma##111 |goto Elwynn Forest 29.84,85.99
step
talk "Auntie" Bernice Stonefield##246
turnin Pie for Billy##86 |goto Elwynn Forest 34.48,84.26
accept Back to Billy##84 |goto Elwynn Forest 34.48,84.26
step
talk Gramma Stonefield##248
|tip Inside the building.
turnin Speak with Gramma##111 |goto Elwynn Forest 34.94,83.86
accept Note to William##107 |goto Elwynn Forest 34.94,83.86
step
talk Billy Maclure##247
turnin Back to Billy##84 |goto Elwynn Forest 43.13,85.72
accept Goldtooth##87 |goto Elwynn Forest 43.13,85.72
stickystart "Collect_Large_Candles_And_Gold_Dust"
step
Enter the mine |goto Elwynn Forest 38.97,82.33 < 15 |walk |only if not (subzone("Fargodeep Mine") and indoors())
Scout Through the Fargodeep Mine |q 62/1 |goto Elwynn Forest 39.61,80.21
|tip Inside the mine.
step
Follow the path inside the mine |goto Elwynn Forest 39.76,79.21 < 10 |walk
kill Goldtooth##327
|tip Walks around.
|tip Inside the mine.
collect Bernice's Necklace##981 |q 87/1 |goto Elwynn Forest 41.71,78.04
step
label "Collect_Large_Candles_And_Gold_Dust"
kill Kobold Tunneler##475, Kobold Miner##40
|tip Inside and outside the mine. |notinsticky
collect 10 Gold Dust##773 |q 47/1 |goto Elwynn Forest 39.61,80.21
collect 8 Large Candle##772 |q 60/1 |goto Elwynn Forest 39.61,80.21
|mapmarker Elwynn Forest/0 36.00,82.40
|mapmarker Elwynn Forest/0 36.20,79.00
|mapmarker Elwynn Forest/0 36.40,84.60
|mapmarker Elwynn Forest/0 37.40,86.80
|mapmarker Elwynn Forest/0 38.00,81.60
|mapmarker Elwynn Forest/0 38.40,77.80
|mapmarker Elwynn Forest/0 38.80,83.60
|mapmarker Elwynn Forest/0 39.00,85.60
|mapmarker Elwynn Forest/0 40.40,82.20
|mapmarker Elwynn Forest/0 40.80,77.40
|mapmarker Elwynn Forest/0 41.60,80.00
step
Kill enemies
|tip Helps reach level 8 after quest turnins.
|tip Inside and outside the mine.
ding 7,1815 |goto Elwynn Forest 39.61,80.21
|mapmarker Elwynn Forest/0 36.00,82.40
|mapmarker Elwynn Forest/0 36.20,79.00
|mapmarker Elwynn Forest/0 36.40,84.60
|mapmarker Elwynn Forest/0 37.40,86.80
|mapmarker Elwynn Forest/0 38.00,81.60
|mapmarker Elwynn Forest/0 38.40,77.80
|mapmarker Elwynn Forest/0 38.80,83.60
|mapmarker Elwynn Forest/0 39.00,85.60
|mapmarker Elwynn Forest/0 40.40,82.20
|mapmarker Elwynn Forest/0 40.80,77.40
|mapmarker Elwynn Forest/0 41.60,80.00
step
Leave the mine |complete subzone("Fargodeep Mine") and not indoors()
|tip Multiple exits.
|tip Whichever you find first.
|only if haveq(62) or haveq(87) or haveq(47) or haveq(60)
step
talk "Auntie" Bernice Stonefield##246
turnin Goldtooth##87 |goto Elwynn Forest 34.49,84.25
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
|tip Inside and outside the mine.
Die on Purpose |complete isdead |goto Elwynn Forest/0 Elwynn Forest 39.61,80.21 |q 47
|mapmarker Elwynn Forest/0 36.00,82.40
|mapmarker Elwynn Forest/0 36.20,79.00
|mapmarker Elwynn Forest/0 36.40,84.60
|mapmarker Elwynn Forest/0 37.40,86.80
|mapmarker Elwynn Forest/0 38.00,81.60
|mapmarker Elwynn Forest/0 38.40,77.80
|mapmarker Elwynn Forest/0 38.80,83.60
|mapmarker Elwynn Forest/0 39.00,85.60
|mapmarker Elwynn Forest/0 40.40,82.20
|mapmarker Elwynn Forest/0 40.80,77.40
|mapmarker Elwynn Forest/0 41.60,80.00
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Elwynn Forest/0 39.48,60.53 |q 47 |zombiewalk
step
talk Remy "Two Times"##241
turnin Gold Dust Exchange##47 |goto Elwynn Forest/0 42.14,67.26
accept A Fishy Peril##40 |goto Elwynn Forest/0 42.14,67.26
step
talk Marshal Dughan##240
turnin A Fishy Peril##40 |goto Elwynn Forest/0 42.11,65.93
accept Further Concerns##35 |goto Elwynn Forest/0 42.11,65.93
turnin The Fargodeep Mine##62 |goto Elwynn Forest/0 42.11,65.93
accept The Jasperlode Mine##76 |goto Elwynn Forest/0 42.11,65.93
step
talk William Pestle##253
|tip Inside the building.
turnin Kobold Candles##60 |goto Elwynn Forest/0 43.32,65.70
accept Shipment to Stormwind##61 |goto Elwynn Forest/0 43.32,65.70
turnin Note to William##107 |goto Elwynn Forest/0 43.32,65.70
accept Collecting Kelp##112 |goto Elwynn Forest/0 43.32,65.70
step
talk Innkeeper Farley##295
|tip Inside the building.
home Goldshire |goto Elwynn Forest/0 43.77,65.81 |q 6661 |future
step
talk Maximillian Crowe##906
|tip Downstairs inside the building.
Train Abilities |trainer Maximillian Crowe##906 |goto Elwynn Forest 44.39,66.24 |q 112
|only if Warlock
step
talk Cylina Darkheart##6374
|tip Buy available Grimoires.
|tip Downstairs inside the building.
Train Demon Abilities |vendor Cylina Darkheart##6374 |goto Elwynn Forest 44.40,65.99 |q 112
|only if Warlock
step
talk Zaldimar Wefhellt##328
|tip Upstairs inside the building.
Train Abilities |trainer Zaldimar Wefhellt##328 |goto Elwynn Forest 43.25,66.19 |q 112
|only if Mage
step
talk Priestess Josetta##377
|tip Upstairs inside the building.
Train Abilities |trainer Priestess Josetta##377 |goto Elwynn Forest 43.28,65.72 |q 112
|only if Priest
step
talk Keryn Sylvius##917
|tip Upstairs inside the building.
Train Abilities |trainer Keryn Sylvius##917 |goto Elwynn Forest 43.87,65.94 |q 112
|only if Rogue
step
talk Brother Wilhelm##927
Train Abilities |trainer Brother Wilhelm##927 |goto Elwynn Forest 41.10,66.04 |q 112
|only if Paladin
step
talk Lyria Du Lac##913
Train Abilities |trainer Lyria Du Lac##913 |goto Elwynn Forest 41.08,65.77 |q 112
|only if Warrior
step
kill Murloc##285, Murloc Streamrunner##735
collect 4 Crystal Kelp Frond##1256 |q 112/1 |goto Elwynn Forest 49.40,66.20
|mapmarker Elwynn Forest/0 49.80,68.40
|mapmarker Elwynn Forest/0 51.60,66.20
|mapmarker Elwynn Forest/0 52.40,68.60
|mapmarker Elwynn Forest/0 53.20,63.60
|mapmarker Elwynn Forest/0 53.80,65.80
|mapmarker Elwynn Forest/0 54.40,68.60
|mapmarker Elwynn Forest/0 55.60,66.80
|mapmarker Elwynn Forest/0 56.60,69.00
|mapmarker Elwynn Forest/0 57.60,67.00
step
Enter the mine |goto Elwynn Forest 61.71,53.87 < 10 |walk
Scout Through the Jasperlode Mine |q 76/1 |goto Elwynn Forest 60.38,49.68
|tip Inside the mine.
step
Leave the mine |goto Elwynn Forest 61.74,53.88 < 10 |walk |only if subzone("Jasperlode Mine") and indoors()
talk Guard Thomas##261
turnin Further Concerns##35 |goto Elwynn Forest 73.97,72.18
accept Find the Lost Guards##37 |goto Elwynn Forest 73.97,72.18
accept Protect the Frontier##52 |goto Elwynn Forest 73.97,72.18
stickystart "Kill_Young_Forest_Bears"
stickystart "Kill_Prowlers"
step
click A Half-Eaten Body
turnin Find the Lost Guards##37 |goto Elwynn Forest 72.65,60.33
accept Discover Rolf's Fate##45 |goto Elwynn Forest 72.65,60.33
step
talk Supervisor Raelen##10616
accept A Bundle of Trouble##5545 |goto Elwynn Forest 81.38,66.11
step
click Bundle of Wood+
|tip Small piles of brown logs.
|tip Near the base of trees.
collect 8 Bundle of Wood##13872 |q 5545/1 |goto Elwynn Forest 79.10,59.40
|mapmarker Elwynn Forest/0 76.00,62.30
|mapmarker Elwynn Forest/0 77.20,60.60
|mapmarker Elwynn Forest/0 78.40,62.40
|mapmarker Elwynn Forest/0 81.40,62.70
|mapmarker Elwynn Forest/0 81.80,59.10
|mapmarker Elwynn Forest/0 83.30,61.00
step
label "Kill_Young_Forest_Bears"
kill 5 Young Forest Bear##822 |q 52/2 |goto Elwynn Forest 76.80,76.60
|mapmarker Elwynn Forest/0 74.80,64.20
|mapmarker Elwynn Forest/0 75.00,67.60
|mapmarker Elwynn Forest/0 87.20,64.40
|mapmarker Elwynn Forest/0 78.00,80.60
|mapmarker Elwynn Forest/0 78.20,61.60
|mapmarker Elwynn Forest/0 79.60,83.60
|mapmarker Elwynn Forest/0 81.40,58.80
|mapmarker Elwynn Forest/0 81.60,74.00
|mapmarker Elwynn Forest/0 81.60,76.60
|mapmarker Elwynn Forest/0 82.80,81.80
|mapmarker Elwynn Forest/0 82.80,84.00
|mapmarker Elwynn Forest/0 86.00,77.20
|mapmarker Elwynn Forest/0 86.80,81.20
|mapmarker Elwynn Forest/0 87.00,70.80
|mapmarker Elwynn Forest/0 87.60,66.80
|mapmarker Elwynn Forest/0 88.20,74.80
|mapmarker Elwynn Forest/0 88.40,77.00
step
label "Kill_Prowlers"
kill 8 Prowler##118 |q 52/1 |goto Elwynn Forest 78.40,75.60
|tip Wolves.
|mapmarker Elwynn Forest/0 72.40,65.20
|mapmarker Elwynn Forest/0 75.40,73.40
|mapmarker Elwynn Forest/0 75.40,76.40
|mapmarker Elwynn Forest/0 76.00,64.80
|mapmarker Elwynn Forest/0 76.40,60.80
|mapmarker Elwynn Forest/0 77.40,78.80
|mapmarker Elwynn Forest/0 78.00,82.40
|mapmarker Elwynn Forest/0 87.60,63.20
|mapmarker Elwynn Forest/0 79.00,62.60
|mapmarker Elwynn Forest/0 80.00,59.20
|mapmarker Elwynn Forest/0 80.40,79.00
|mapmarker Elwynn Forest/0 81.00,84.00
|mapmarker Elwynn Forest/0 81.60,76.20
|mapmarker Elwynn Forest/0 83.40,59.20
|mapmarker Elwynn Forest/0 84.40,62.60
|mapmarker Elwynn Forest/0 84.40,71.20
|mapmarker Elwynn Forest/0 85.20,82.40
|mapmarker Elwynn Forest/0 85.40,66.20
|mapmarker Elwynn Forest/0 85.60,79.00
|mapmarker Elwynn Forest/0 85.80,85.80
|mapmarker Elwynn Forest/0 86.60,59.80
|mapmarker Elwynn Forest/0 87.20,69.00
|mapmarker Elwynn Forest/0 87.40,75.40
|mapmarker Elwynn Forest/0 87.60,72.20
|mapmarker Elwynn Forest/0 88.00,80.80
|mapmarker Elwynn Forest/0 89.80,78.00
step
Kill enemies
|tip Next step can be tough.
|tip Being a level higher will help.
ding 9 |goto Elwynn Forest 79.00,62.60
|mapmarker Elwynn Forest/0 72.40,65.20
|mapmarker Elwynn Forest/0 76.00,64.80
|mapmarker Elwynn Forest/0 76.40,60.80
|mapmarker Elwynn Forest/0 80.00,59.20
|mapmarker Elwynn Forest/0 83.40,59.20
|mapmarker Elwynn Forest/0 84.40,62.60
|mapmarker Elwynn Forest/0 84.40,71.20
|mapmarker Elwynn Forest/0 85.40,66.20
|mapmarker Elwynn Forest/0 86.60,59.80
|mapmarker Elwynn Forest/0 87.20,69.00
|mapmarker Elwynn Forest/0 87.60,63.20
|mapmarker Elwynn Forest/0 87.60,72.20
step
click Rolf's Corpse
turnin Discover Rolf's Fate##45 |goto Elwynn Forest 79.80,55.52
accept Report to Thomas##71 |goto Elwynn Forest 79.80,55.52
step
talk Supervisor Raelen##10616
turnin A Bundle of Trouble##5545 |goto Elwynn Forest 81.38,66.12
step
talk Sara Timberlain##278
accept Red Linen Goods##83 |goto Elwynn Forest 79.46,68.78
step
talk Guard Thomas##261
turnin Protect the Frontier##52 |goto Elwynn Forest 73.97,72.18
turnin Report to Thomas##71 |goto Elwynn Forest 73.97,72.18
accept Deliver Thomas' Report##39 |goto Elwynn Forest 73.97,72.18
accept Report to Gryan Stoutmantle##109 |goto Elwynn Forest 73.97,72.18
step
kill Defias Bandit##116+
collect 6 Red Linen Bandana##1019 |q 83/1 |goto Elwynn Forest 70.20,76.40
|mapmarker Elwynn Forest/0 67.00,80.20
|mapmarker Elwynn Forest/0 68.20,77.80
|mapmarker Elwynn Forest/0 68.40,75.40
|mapmarker Elwynn Forest/0 68.40,82.60
|mapmarker Elwynn Forest/0 70.60,80.60
|mapmarker Elwynn Forest/0 72.00,77.40
step
Kill enemies
|tip Helps reach level 10 after quest turnins.
ding 9,3545 |goto Elwynn Forest 70.20,76.40
|mapmarker Elwynn Forest/0 67.00,80.20
|mapmarker Elwynn Forest/0 68.20,77.80
|mapmarker Elwynn Forest/0 68.40,75.40
|mapmarker Elwynn Forest/0 68.40,82.60
|mapmarker Elwynn Forest/0 70.60,80.60
|mapmarker Elwynn Forest/0 72.00,77.40
step
use Westfall Deed##1972
accept Furlbrow's Deed##184
|only if itemcount(1972) > 0
step
talk Sara Timberlain##278
|tip In front of the building.
turnin Red Linen Goods##83 |goto Elwynn Forest 79.46,68.79
step
talk Ariena Stormfeather##931
|tip Follow the road carefully.
|tip Higher level enemies.
fpath Lakeshire |goto Redridge Mountains 30.59,59.41
step
talk William Pestle##253
|tip Inside the building.
turnin Collecting Kelp##112 |goto Elwynn Forest/0 43.32,65.71
step
Watch the dialogue
|tip Inside the building.
talk William Pestle##253
accept The Escape##114 |goto Elwynn Forest/0 43.32,65.71
step
talk Marshal Dughan##240
turnin Deliver Thomas' Report##39 |goto Elwynn Forest/0 42.11,65.93
turnin The Jasperlode Mine##76 |goto Elwynn Forest/0 42.11,65.93
accept Westbrook Garrison Needs Help!##239 |goto Elwynn Forest/0 42.11,65.93
step
talk Smith Argus##514
|tip Inside the building.
accept Elmore's Task##1097 |goto Elwynn Forest/0 41.71,65.55
step
talk Maximillian Crowe##906
|tip Downstairs inside the building.
Train Abilities |trainer Maximillian Crowe##906 |goto Elwynn Forest 44.39,66.24 |q 114
|only if Warlock
step
talk Remen Marcot##6121
|tip Downstairs inside the building.
accept Gakin's Summons##1685 |goto Elwynn Forest 44.49,66.27
|only if Human Warlock
step
talk Cylina Darkheart##6374
|tip Buy available Grimoires.
|tip Downstairs inside the building.
Train Demon Abilities |vendor Cylina Darkheart##6374 |goto Elwynn Forest 44.40,65.99 |q 114
|only if Warlock
step
talk Zaldimar Wefhellt##328
|tip Upstairs inside the building.
Train Abilities |trainer Zaldimar Wefhellt##328 |goto Elwynn Forest 43.25,66.19 |q 114
|only if Mage
step
talk Priestess Josetta##377
|tip Upstairs inside the building.
Train Abilities |trainer Priestess Josetta##377 |goto Elwynn Forest 43.28,65.72 |q 114
|only if Priest
step
talk Priestess Josetta##377
|tip Upstairs inside the building.
accept Desperate Prayer##5635 |goto Elwynn Forest 43.28,65.72
|only if (Human or Dwarf) and Priest
step
talk Keryn Sylvius##917
|tip Upstairs inside the building.
Train Abilities |trainer Keryn Sylvius##917 |goto Elwynn Forest 43.87,65.94 |q 114
|only if Rogue
step
talk Keryn Sylvius##917
|tip Upstairs inside the building.
accept Seek out SI: 7##2205 |goto Elwynn Forest 43.87,65.94
|only if Rogue
step
talk Brother Wilhelm##927
Train Abilities |trainer Brother Wilhelm##927 |goto Elwynn Forest 41.10,66.04 |q 114
|only if Paladin
step
talk Lyria Du Lac##913
Train Abilities |trainer Lyria Du Lac##913 |goto Elwynn Forest 41.08,65.77 |q 114
|only if Warrior
step
talk Lyria Du Lac##913
accept A Warrior's Training##1638 |goto Elwynn Forest 41.09,65.77
|only if Human Warrior
step
talk Maybell Maclure##251
|tip Inside the building.
turnin The Escape##114 |goto Elwynn Forest 43.15,89.62
step
talk Deputy Rainer##963
turnin Westbrook Garrison Needs Help!##239 |goto Elwynn Forest 24.23,74.45
accept Riverpaw Gnoll Bounty##11 |goto Elwynn Forest 24.23,74.45
step
kill Riverpaw Runt##97, Riverpaw Outrunner##478
|tip Gnolls.
collect 8 Painted Gnoll Armband##782 |q 11/1 |goto Elwynn Forest 27.20,82.20
|mapmarker Elwynn Forest/0 23.00,93.20
|mapmarker Elwynn Forest/0 24.00,86.20
|mapmarker Elwynn Forest/0 25.40,90.40
|mapmarker Elwynn Forest/0 26.40,95.20
|mapmarker Elwynn Forest/0 27.00,87.80
|mapmarker Elwynn Forest/0 28.40,92.20
|mapmarker Elwynn Forest/0 30.40,83.40
|mapmarker Elwynn Forest/0 31.60,88.00
step
talk Deputy Rainer##963
turnin Riverpaw Gnoll Bounty##11 |goto Elwynn Forest 24.23,74.45
step
talk Farmer Furlbrow##237
turnin Furlbrow's Deed##184 |goto Westfall 59.96,19.36
|only if haveq(184) or completedq(184)
step
talk Verna Furlbrow##238
accept Westfall Stew##36 |goto Westfall 59.92,19.42
step
talk Salma Saldean##235
|tip Inside the building.
turnin Westfall Stew##36 |goto Westfall 56.42,30.52
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Westfall/0 54.57,32.55 |q 109
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Westfall/0 51.71,49.66 |q 109 |zombiewalk
step
talk Gryan Stoutmantle##234
turnin Report to Gryan Stoutmantle##109 |goto Westfall/0 56.33,47.52
step
talk Quartermaster Lewis##491
|tip Inside the building.
accept A Swift Message##6181 |goto Westfall 57.00,47.17
|only if Human
step
talk Thor##523
fpath Sentinel Hill |goto Westfall 56.55,52.64
step
talk Thor##523
turnin A Swift Message##6181 |goto Westfall 56.56,52.64
accept Continue to Stormwind##6281 |goto Westfall 56.56,52.64
|only if Human
step
talk Thor##523
|tip Open the flight map.
|tip Allows guide to learn your flight paths.
fpath Stormwind City |goto Westfall 56.55,52.64
|only if Human
step
talk Morgan Pestle##279
|tip Inside the building.
turnin Shipment to Stormwind##61 |goto Stormwind City 56.21,64.59
step
talk Woo Ping##11867
|tip Inside the building.
Train Two-Handed Swords |complete weaponskill("TH_SWORD") > 0	|goto Stormwind City 57.13,57.71	|only if Warrior
Train One-Handed Swords |complete weaponskill("SWORD") > 0	|goto Stormwind City 57.13,57.71	|only if Rogue or Warlock or Mage
Train Staves		|complete weaponskill("TH_STAFF") > 0	|goto Stormwind City 57.13,57.71	|only if Priest or Warlock
Train Daggers		|complete weaponskill("DAGGER") > 0	|goto Stormwind City 57.13,57.71	|only if Mage
|only if Warrior or Rogue or Warlock or Mage or Priest
step
Enter the building |goto Stormwind City/0 29.16,74.15 < 10 |walk |only if not (subzone("The Slaughtered Lamb") and indoors())
talk Gakin the Darkbinder##6122
|tip Downstairs inside the building.
turnin Gakin's Summons##1685 |goto Stormwind City 25.26,78.56
accept Surena Caledon##1688 |goto Stormwind City 25.26,78.56
|only Human Warlock
step
kill Surena Caledon##881
|tip Inside the building.
collect Surena's Choker##6810 |q 1688/1 |goto Elwynn Forest 71.02,80.78
|only if Human Warlock
step
Enter the building |goto Stormwind City/0 29.16,74.15 < 10 |walk |only if not (subzone("The Slaughtered Lamb") and indoors())
talk Gakin the Darkbinder##6122
|tip Downstairs inside the building.
turnin Surena Caledon##1688 |goto Stormwind City 25.26,78.56
accept The Binding##1689 |goto Stormwind City 25.26,78.56
|only if Human Warlock
step
use Bloodstone Choker##6928
|tip Stand on the pink symbol.
|tip Inside the crypt.
|tip Downstairs inside the building.
kill Summoned Voidwalker##5676 |q 1689/1 |goto Stormwind City 25.11,77.46
|only if Human Warlock
step
talk Gakin the Darkbinder##6122
|tip Above the crypt.
|tip Downstairs inside the building.
turnin The Binding##1689 |goto Stormwind City 25.25,78.53
|only if Human Warlock
step
talk Master Mathias Shaw##332
|tip Upstairs inside the building.
turnin Seek out SI: 7##2205 |goto Stormwind City/0 75.78,59.84
|only if Rogue
step
talk Osric Strang##1323
|tip Inside the building.
turnin Continue to Stormwind##6281 |goto Stormwind City 74.32,47.24
|only if Human
step
talk Harry Burlguard##6089
|tip Inside the building.
turnin A Warrior's Training##1638 |goto Stormwind City 74.25,37.26
accept Bartleby the Drunk##1639 |goto Stormwind City 74.25,37.26
|only if Human Warrior
step
talk Bartleby##6090
|tip Walks around.
|tip Inside the building.
turnin Bartleby the Drunk##1639 |goto Stormwind City 73.83,37.17
accept Beat Bartleby##1640 |goto Stormwind City 73.83,37.17
|tip You will be attacked.
|only if Human Warrior
step
kill Bartleby##6090
|tip Walks around.
|tip Inside the building.
Beat Bartleby |q 1640/1 |goto Stormwind City 73.83,37.17
|only if Human Warrior
step
talk Bartleby##6090
|tip Walks around.
|tip Inside the building.
turnin Beat Bartleby##1640 |goto Stormwind City 73.83,37.17
accept Bartleby's Mug##1665 |goto Stormwind City 73.83,37.17
|only if Human Warrior
step
talk Harry Burlguard##6089
|tip Inside the building.
turnin Bartleby's Mug##1665 |goto Stormwind City 74.25,37.26
|only if Human Warrior
step
Enter the building |goto Stormwind City/0 42.86,34.08 < 15 |walk |only if not (subzone("Cathedral of Light") and indoors())
talk High Priestess Laurena##376
|tip Inside the building.
turnin Desperate Prayer##5635 |goto Stormwind City/0 38.58,26.05
|only if Human Priest
step
_NOTE:_
Use Weapon Stones
|tip We will train Mining and Blacksmithing.
|tip Allows you to make and use {o}Sharpening Stones{}.		|only if Warrior or Rogue
|tip Allows you to make and use {o}Weightstones{}.		|only if Paladin
|tip Increases damage.
|tip Mine {o}Copper Ore{} as you see it.
|tip Use the {g}Rough Stones{} to make sharpening stones.	|only if Warrior or Rogue
|tip Use the {g}Rough Stones{} to make weightstones.		|only if Paladin
Click Here to Continue |confirm |q 1097
|only if Warrior or Rogue or Paladin
step
talk Therum Deepforge##5511
Train Apprentice Blacksmithing |skillmax Blacksmithing,75 |goto Stormwind City/0 56.84,16.25
|only if Warrior or Rogue or Paladin
step
talk Brooke Stonebraid##5514
|tip Inside the building.
buy Mining Pick##2901 |goto Stormwind City/0 51.02,16.88
|only if Warrior or Rogue or Paladin
step
talk Gelman Stonehand##5513
|tip Upstiars inside the building.
Train Apprentice Mining |skillmax Mining,75 |goto Stormwind City/0 51.15,17.31
|only if Warrior or Rogue or Paladin
step
talk Grimand Elmore##1416
|tip Inside the building.
turnin Elmore's Task##1097 |goto Stormwind City 51.76,12.07
accept Stormpike's Delivery##353 |goto Stormwind City 51.76,12.07
step
Enter the Deeprun Tram |complete subzone("Deeprun Tram") |goto Stormwind City 63.92,8.20 |q 433 |future
|tip Walk into the portal.
step
_Inside Deeprun Tram:_
Ride the Tram
|tip Ride the tram to Ironforge.
talk Monty##12997
|tip Middle platform, near the wall.
|tip Ironforge section of the Deeprun Tram.
accept Deeprun Rat Roundup##6661
step
_Inside Deeprun Tram:_
use Rat Catcher's Flute##17117
|tip On Deeprun Rats.
|tip Small grey rats.
|tip Ironforge section of the Deeprun Tram.
Capture #5# Rats |q 6661/1
step
_Inside Deeprun Tram:_
talk Monty##12997
|tip Middle platform, near the wall.
|tip Ironforge section of the Deeprun Tram.
turnin Deeprun Rat Roundup##6661
step
_Inside Deeprun Tram:_
Enter Ironforge |complete zone("Ironforge") |q 433 |future
|tip Walk into the portal.
step
talk Bixi Wobblebonk##13084
|tip Inside the building.
Train Thrown |complete weaponskill("THROWN") > 0 |goto Ironforge 62.23,89.62
|only if Warrior
step
talk Buliwyf Stonehand##11865
|tip Inside the building.
Train Two-Handed Maces |complete weaponskill("TH_MACE") > 0 |goto Ironforge 61.17,89.52
|only if Warrior
step
talk Gryth Thurden##1573
fpath Ironforge |goto Ironforge 55.50,47.75
step
talk Innkeeper Firebrew##5111
|tip Inside the building.
home Ironforge |goto Ironforge/0 18.15,51.45 |q 318 |future
step
talk Senator Mehr Stonehallow##1977
accept The Public Servant##433 |goto Dun Morogh 68.67,55.97
step
talk Foreman Stonebrow##1254
accept Those Blasted Troggs!##432 |goto Dun Morogh 69.08,56.33
stickystart "Kill_Rockjaw_Skullthumpers"
step
Enter the cave |goto Dun Morogh 70.70,56.49 < 20 |walk |only if not (subzone("Gol'Bolar Quarry Mine") and indoors())
kill 10 Rockjaw Bonesnapper##1117 |q 433/1 |goto Dun Morogh 70.98,54.77
|tip Inside the cave.
|mapmarker Dun Morogh/0 70.40,52.20
|mapmarker Dun Morogh/0 71.60,50.40
|mapmarker Dun Morogh/0 72.60,52.20
step
label "Kill_Rockjaw_Skullthumpers"
kill 6 Rockjaw Skullthumper##1115 |q 432/1 |goto Dun Morogh 70.70,56.49
|tip Inside and outside the cave. |notinsticky
|mapmarker Dun Morogh/0 67.20,58.60
|mapmarker Dun Morogh/0 68.00,60.60
|mapmarker Dun Morogh/0 69.20,56.40
|mapmarker Dun Morogh/0 70.40,52.40
|mapmarker Dun Morogh/0 70.80,54.80
|mapmarker Dun Morogh/0 71.40,50.40
|mapmarker Dun Morogh/0 72.60,52.20
|mapmarker Dun Morogh/0 70.60,59.20
step
Kill enemies
|tip Helps reach level 11 after quest turnins.
|tip Inside and outside the cave.
ding 10,6400 |goto Dun Morogh 70.70,56.49
|mapmarker Dun Morogh/0 67.20,58.60
|mapmarker Dun Morogh/0 68.00,60.60
|mapmarker Dun Morogh/0 69.20,56.40
|mapmarker Dun Morogh/0 70.40,52.40
|mapmarker Dun Morogh/0 70.80,54.80
|mapmarker Dun Morogh/0 71.40,50.40
|mapmarker Dun Morogh/0 72.60,52.20
|mapmarker Dun Morogh/0 70.60,59.20
step
Leave the cave |goto Dun Morogh 70.70,56.49 < 20 |walk |only if subzone("Gol'Bolar Quarry Mine")
talk Senator Mehr Stonehallow##1977
turnin The Public Servant##433 |goto Dun Morogh 68.67,55.97
step
talk Foreman Stonebrow##1254
turnin Those Blasted Troggs!##432 |goto Dun Morogh 69.08,56.33
step
talk Cook Ghilm##1355
|tip Walks around.
Learn Cooking |skillmax Cooking,75 |goto Dun Morogh 68.38,54.49 |q 419 |future
step
talk Pilot Hammerfoot##1960
|tip Follow the road through the tunnel.
accept The Lost Pilot##419 |goto Dun Morogh 83.89,39.19
step
click A Dwarven Corpse
turnin The Lost Pilot##419 |goto Dun Morogh 79.67,36.17
accept A Pilot's Revenge##417 |goto Dun Morogh 79.67,36.17
step
kill Mangeclaw##1961
|tip White bear.
|tip Walks around.
collect Mangy Claw##3183 |q 417/1 |goto Dun Morogh/0 78.97,37.02
step
talk Pilot Hammerfoot##1960
turnin A Pilot's Revenge##417 |goto Dun Morogh/0 83.89,39.19
step
talk Mountaineer Stormpike##1343
|tip Run through the tunnel.
|tip Upstairs inside the building.
turnin Stormpike's Delivery##353 |goto Loch Modan/0 24.76,18.40
step
Allow Enemies to Kill You
|tip Fast travel.
Die on Purpose |complete isdead |goto Loch Modan/0 29.76,16.06 |q 983 |future
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Loch Modan/0 32.51,46.95 |q 983 |future |zombiewalk
step
talk Thorgrum Borrelson##1572
fpath Thelsamar |goto Loch Modan/0 33.94,50.95
step
Follow the path up |goto Dun Morogh 31.06,32.56 < 7 |only if walking and not zone("Wetlands")
Continue up the path |goto Dun Morogh 31.43,32.34 < 7 |only if walking and not zone("Wetlands")
Continue up the path |goto Dun Morogh 31.14,30.50 < 7 |only if walking and not zone("Wetlands")
Follow the path down |goto Dun Morogh 32.33,28.63 < 15 |only if walking and not zone("Wetlands")
Follow the path |goto Dun Morogh 32.74,27.11 < 20 |only if walking and not zone("Wetlands")
Jump to Your Death |complete isdead |goto Eastern Kingdoms 44.92,51.98 |q 983 |future |notravel
|tip While in {o}Wetlands{}, run {o}north{}.
|tip Jump off the cliff.
|tip Easier to reach Menethil Harbor.
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Wetlands 11.72,43.30 |q 983 |future |zombiewalk
step
talk Neal Allen##1448
|tip Walks around.
|tip Inside the building.
buy Bronze Tube##4371 |n
|tip If possible.
|tip Limited supply item.
|tip Needed later for Duskwood quest.
Visit the Vendor |vendor Neal Allen##1448 |goto Wetlands 10.75,56.75 |q 174 |future
step
talk Shellei Brondir##1571
fpath Menethil Harbor |goto Wetlands 9.49,59.69
]])
ZygorGuidesViewer:RegisterGuide("Leveling Guides\\Starter Guides (1-11)\\Dwarf & Gnome Starter (1-11)",{
image=ZGV.IMAGESDIR.."Dun Morogh",
condition_suggested=function() return (raceclass('Dwarf') or raceclass('Gnome')) and level <= 11 end,
condition_suggested_exclusive=true,
condition_visible=function() return Dwarf or Gnome end,
linked = {"Leveling Guides\\Hidden Guides"},
linkedhidden = true,
next="Leveling Guides\\Classic (11-60)\\Darkshore (11-14)",
},[[
defaultfor Dwarf,Gnome
step
_NOTE:_
Wrong Character Race
|tip Guide written for {o}Dwarf & Gnome{} characters.
|tip Other races may encounter issues.
Click Here to Continue |confirm
|only if not (Dwarf or Gnome)
step
_Destroy This Item:_
|tip Saves bag space.
|tip You'll get one later.
trash Hearthstone##6948	|q 179 |future
step
_NOTE:_
Manage Your Ammo
|tip Make sure you always have ammo.
|tip You need it to attack enemies.
|tip {o}General Goods{} vendors sell it (also Bow & Gun vendors).
|tip Try to keep your ammo bag full.
Click Here to Continue |confirm |q 179 |future
|only if Hunter
step
kill Ragged Young Wolf##705, Ragged Timber Wolf##704
|tip Loot items worth at least {o}10 copper{} to sell.
|tip Allows training a spell early.
Click to continue |confirm |goto Dun Morogh 30.60,74.40 |q 179 |future
|mapmarker Dun Morogh/0 26.00,69.40
|mapmarker Dun Morogh/0 26.40,74.20
|mapmarker Dun Morogh/0 27.40,71.20
|mapmarker Dun Morogh/0 28.20,75.60
|mapmarker Dun Morogh/0 28.40,73.40
|mapmarker Dun Morogh/0 29.40,77.20
|mapmarker Dun Morogh/0 30.80,69.40
|mapmarker Dun Morogh/0 30.80,72.40
|only if Warrior or Warlock
step
talk Adlin Pridedrift##829
Sell Items |vendor Adlin Pridedrift##829 |goto Dun Morogh/0 30.08,71.52 |q 179 |future
|only if Warrior or Warlock
step
Enter the building |goto Dun Morogh/0 28.79,69.05 < 10 |walk |only if not (subzone("Anvilmar") and indoors())
talk Thran Khorman##912
|tip Inside the building.
Train Abilities |trainer Thran Khorman##912 |goto Dun Morogh 28.83,67.24 |q 179 |future
|only if Warrior
step
Enter the building |goto Dun Morogh/0 28.79,69.05 < 10 |walk |only if not (subzone("Anvilmar") and indoors())
talk Alamar Grimm##460
|tip Upstairs inside the building.
Train Abilities |trainer Alamar Grimm##460 |goto Dun Morogh 28.65,66.14 |q 179 |future
|only if Warlock
step
Leave the building |goto Dun Morogh 28.79,69.07 < 10 |walk |only if subzone("Anvilmar") and indoors()
talk Sten Stoutarm##658
accept Dwarven Outfitters##179 |goto Dun Morogh 29.93,71.20
step
kill Ragged Young Wolf##705, Ragged Timber Wolf##704
|tip Wolves.
collect 8 Tough Wolf Meat##750 |q 179/1 |goto Dun Morogh 30.60,74.40
|mapmarker Dun Morogh/0 26.00,69.40
|mapmarker Dun Morogh/0 26.40,74.20
|mapmarker Dun Morogh/0 27.40,71.20
|mapmarker Dun Morogh/0 28.20,75.60
|mapmarker Dun Morogh/0 28.40,73.40
|mapmarker Dun Morogh/0 29.40,77.20
|mapmarker Dun Morogh/0 30.80,69.40
|mapmarker Dun Morogh/0 30.80,72.40
step
Kill enemies
ding 2 |goto Dun Morogh 30.60,74.40
|mapmarker Dun Morogh/0 26.00,69.40
|mapmarker Dun Morogh/0 26.40,74.20
|mapmarker Dun Morogh/0 27.40,71.20
|mapmarker Dun Morogh/0 28.20,75.60
|mapmarker Dun Morogh/0 28.40,73.40
|mapmarker Dun Morogh/0 29.40,77.20
|mapmarker Dun Morogh/0 30.80,69.40
|mapmarker Dun Morogh/0 30.80,72.40
step
talk Sten Stoutarm##658
turnin Dwarven Outfitters##179		|goto Dun Morogh 29.93,71.20
accept Simple Rune##3106		|goto Dun Morogh 29.93,71.20	|only Dwarf Warrior
accept Encrypted Rune##3109		|goto Dun Morogh 29.93,71.20	|only Dwarf Rogue
accept Hallowed Rune##3110		|goto Dun Morogh 29.93,71.20	|only Dwarf Priest
accept Consecrated Rune##3107		|goto Dun Morogh 29.93,71.20	|only Dwarf Paladin
accept Etched Rune##3108		|goto Dun Morogh 29.93,71.20	|only Dwarf Hunter
accept Glyphic Memorandum##3114		|goto Dun Morogh 29.93,71.20	|only Gnome Mage
accept Simple Memorandum##3112		|goto Dun Morogh 29.93,71.20	|only Gnome Warrior
accept Tainted Memorandum##3115		|goto Dun Morogh 29.93,71.20	|only Gnome Warlock
accept Encrypted Memorandum##3113	|goto Dun Morogh 29.93,71.20	|only Gnome Rogue
accept Coldridge Valley Mail Delivery##233 |goto Dun Morogh 29.93,71.20
step
talk Balir Frosthammer##713
accept A New Threat##170 |goto Dun Morogh 29.71,71.25
step
kill 6 Rockjaw Trogg##707 |q 170/1 |goto Dun Morogh/0 25.80,72.80
kill 6 Burly Rockjaw Trogg##724 |q 170/2 |goto Dun Morogh/0 25.80,72.80
|mapmarker Dun Morogh/0 20.20,71.80
|mapmarker Dun Morogh/0 21.40,77.20
|mapmarker Dun Morogh/0 23.00,73.40
|mapmarker Dun Morogh/0 24.20,71.20
step
talk Talin Keeneye##714
turnin Coldridge Valley Mail Delivery##233 |goto Dun Morogh/0 22.60,71.43
accept Coldridge Valley Mail Delivery##234 |goto Dun Morogh/0 22.60,71.43
accept The Boar Hunter##183 |goto Dun Morogh/0 22.60,71.43
step
kill 12 Small Crag Boar##708 |q 183/1 |goto Dun Morogh/0 22.20,71.20
|mapmarker Dun Morogh/0 20.00,71.40
|mapmarker Dun Morogh/0 21.20,69.40
|mapmarker Dun Morogh/0 23.40,68.40
|mapmarker Dun Morogh/0 24.20,71.20
|mapmarker Dun Morogh/0 25.40,68.40
|mapmarker Dun Morogh/0 26.20,71.20
step
talk Talin Keeneye##714
turnin The Boar Hunter##183 |goto Dun Morogh/0 22.60,71.43
step
Kill enemies
ding 4 |goto Dun Morogh/0 22.20,71.20
|mapmarker Dun Morogh/0 20.00,71.40
|mapmarker Dun Morogh/0 21.20,69.40
|mapmarker Dun Morogh/0 23.40,68.40
|mapmarker Dun Morogh/0 24.20,71.20
|mapmarker Dun Morogh/0 25.40,68.40
|mapmarker Dun Morogh/0 26.20,71.20
step
talk Grelin Whitebeard##786
turnin Coldridge Valley Mail Delivery##234 |goto Dun Morogh/0 25.08,75.71
step
talk Nori Pridedrift##12738
accept Scalding Mornbrew Delivery##3364 |goto Dun Morogh/0 24.98,75.96
step
_NOTE:_
During the Next Steps
|tip {o}Hurry{}, timed quest.
Click Here to Continue |confirm |q 3364
step
Enter the building |goto Dun Morogh/0 28.79,69.05 < 10 |walk |only if not (subzone("Anvilmar") and indoors())
talk Felix Whindlebolt##8416
|tip Walks around.
|tip Inside the building.
accept A Refugee's Quandary##3361 |goto Dun Morogh/0 28.51,67.67
step
talk Durnan Furcutter##836
|tip Inside the building.
turnin Scalding Mornbrew Delivery##3364 |goto Dun Morogh/0 28.77,66.37
accept Bring Back the Mug##3365 |goto Dun Morogh/0 28.77,66.37
step
talk Thran Khorman##912
|tip Inside the building.
turnin Simple Rune##3106 |goto Dun Morogh 28.83,67.24
|only if Dwarf Warrior
step
talk Thran Khorman##912
|tip Inside the building.
Train Abilities |trainer Thran Khorman##912 |goto Dun Morogh 28.83,67.24 |q 170
|only if Dwarf Warrior
step
talk Solm Hargrin##916
|tip Inside the building.
turnin Encrypted Rune##3109 |goto Dun Morogh 28.37,67.51
|only if Dwarf Rogue
step
talk Solm Hargrin##916
|tip Inside the building.
Train Abilities |trainer Solm Hargrin##916 |goto Dun Morogh 28.37,67.51 |q 170
|only if Dwarf Rogue
step
talk Branstock Khalder##837
|tip Inside the building.
turnin Hallowed Rune##3110 |goto Dun Morogh 28.60,66.39
|only if Dwarf Priest
step
talk Branstock Khalder##837
|tip Inside the building.
Train Abilities |trainer Branstock Khalder##837 |goto Dun Morogh 28.60,66.39 |q 170
|only if Dwarf Priest
step
talk Bromos Grummner##926
|tip Inside the building.
turnin Consecrated Rune##3107 |goto Dun Morogh 28.83,68.33
|only if Dwarf Paladin
step
talk Bromos Grummner##926
|tip Inside the building.
Train Abilities |trainer Bromos Grummner##926 |goto Dun Morogh 28.83,68.33 |q 170
|only if Dwarf Paladin
step
talk Thorgas Grimson##895
|tip Inside the building.
turnin Etched Rune##3108 |goto Dun Morogh 29.18,67.46
|only if Dwarf Hunter
step
talk Thorgas Grimson##895
|tip Inside the building.
Train Abilities |trainer Thorgas Grimson##895 |goto Dun Morogh 29.18,67.46 |q 170
|only if Dwarf Hunter
step
talk Thran Khorman##912
|tip Inside the building.
turnin Simple Memorandum##3112 |goto Dun Morogh 28.83,67.24
|only if Gnome Warrior
step
talk Thran Khorman##912
|tip Inside the building.
Train Abilities |trainer Thran Khorman##912 |goto Dun Morogh 28.83,67.24 |q 170
|only if Gnome Warrior
step
talk Solm Hargrin##916
|tip Inside the building.
turnin Encrypted Memorandum##3113 |goto Dun Morogh 28.37,67.51
|only if Gnome Rogue
step
talk Solm Hargrin##916
|tip Inside the building.
Train Abilities |trainer Solm Hargrin##916 |goto Dun Morogh 28.37,67.51 |q 170
|only if Gnome Rogue
step
talk Marryk Nurribit##944
|tip Inside the building.
turnin Glyphic Memorandum##3114 |goto Dun Morogh 28.71,66.36
|only if Gnome Mage
step
talk Marryk Nurribit##944
|tip Inside the building.
Train Abilities |trainer Marryk Nurribit##944 |goto Dun Morogh 28.71,66.36 |q 170
|only if Gnome Mage
step
talk Alamar Grimm##460
|tip Upstairs inside the building.
turnin Tainted Memorandum##3115 |goto Dun Morogh 28.65,66.14
accept Beginnings##1599 |goto Dun Morogh 28.65,66.14
|only if Gnome Warlock
step
talk Alamar Grimm##460
|tip Upstairs inside the building.
Train Abilities |trainer Alamar Grimm##460 |goto Dun Morogh 28.65,66.14 |q 170
|only if Gnome Warlock
step
Leave the building |goto Dun Morogh 28.79,69.07 < 10 |walk |only if subzone("Anvilmar") and indoors()
talk Balir Frosthammer##713
turnin A New Threat##170 |goto Dun Morogh 29.71,71.25
step
talk Grelin Whitebeard##786
accept The Troll Cave##182 |goto Dun Morogh 25.08,75.71
step
talk Nori Pridedrift##12738
turnin Bring Back the Mug##3365 |goto Dun Morogh 24.98,75.96
stickystart "Kill_Frostmane_Troll_Whelps"
step
kill Frostmane Novice##946+
|tip Uncommon and spread out.
|tip Inside the cave.
collect 3 Feather Charm##6753 |q 1599/1 |goto Dun Morogh 26.78,79.83
|mapmarker Dun Morogh/0 28.60,83.00
|mapmarker Dun Morogh/0 30.40,79.40
|only if Gnome Warlock
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
|tip Anywhere inside the cave.
Die on Purpose |complete isdead |goto Dun Morogh 26.78,79.83 |q 1599
|only if Gnome Warlock
stickystop "Kill_Frostmane_Troll_Whelps"
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Dun Morogh 29.55,69.83 |q 1599 |zombiewalk
|only if Gnome Warlock
step
Enter the building |goto Dun Morogh 28.79,69.05 < 10 |walk |only if not (subzone("Anvilmar") and indoors())
talk Alamar Grimm##460
|tip Upstairs inside the building.
turnin Beginnings##1599 |goto Dun Morogh 28.65,66.14
|only if Gnome Warlock
step
talk Wren Darkspring##6376
|tip Buy available Grimoires.
|tip Upstairs inside the building.
Train Demon Abilities |vendor Wren Darkspring##6376 |goto Dun Morogh 28.80,66.16 |q 3361
|only if Warlock
stickystart "Kill_Frostmane_Troll_Whelps"
step
Leave the building |goto Dun Morogh 28.79,69.07 < 10 |walk |only if subzone("Anvilmar") and indoors()
click Felix's Box
collect Felix's Box##10438 |q 3361/1 |goto Dun Morogh 20.88,76.07
step
click Felix's Chest
collect Felix's Chest##16313 |q 3361/2 |goto Dun Morogh 22.78,80.00
step
click Felix's Bucket of Bolts
collect Felix's Bucket of Bolts##16314 |q 3361/3 |goto Dun Morogh 26.33,79.27
step
label "Kill_Frostmane_Troll_Whelps"
kill 14 Frostmane Troll Whelp##706 |q 182/1 |goto Dun Morogh 26.78,79.83
|tip Inside and outside the cave. |notinsticky
|mapmarker Dun Morogh/0 20.20,75.80
|mapmarker Dun Morogh/0 22.80,79.40
|mapmarker Dun Morogh/0 25.20,79.20
|mapmarker Dun Morogh/0 28.40,82.60
|mapmarker Dun Morogh/0 29.40,79.00
|mapmarker Dun Morogh/0 30.40,82.00
step
Leave the cave |goto Dun Morogh 26.78,79.83 < 15 |walk |only if subzone("Coldridge Valley") and indoors()
talk Grelin Whitebeard##786
turnin The Troll Cave##182 |goto Dun Morogh 25.08,75.71
accept The Stolen Journal##218 |goto Dun Morogh 25.08,75.71
step
Enter the cave |goto Dun Morogh 26.80,79.86 < 15 |walk |only if not (subzone("Coldridge Valley") and indoors())
kill Grik'nir the Cold##808
|tip Inside the cave.
collect Grelin Whitebeard's Journal##2004 |q 218/1 |goto Dun Morogh 30.49,80.16
step
Leave the cave |goto Dun Morogh 26.78,79.83 < 15 |walk |only if subzone("Coldridge Valley") and indoors()
talk Grelin Whitebeard##786
turnin The Stolen Journal##218 |goto Dun Morogh 25.08,75.71
accept Senir's Observations##282 |goto Dun Morogh 25.08,75.71
step
Kill enemies
|tip Inside and outside the cave.
ding 5,2600 |goto Dun Morogh 26.78,79.83
|mapmarker Dun Morogh/0 20.20,75.80
|mapmarker Dun Morogh/0 22.80,79.40
|mapmarker Dun Morogh/0 25.20,79.20
|mapmarker Dun Morogh/0 28.40,82.60
|mapmarker Dun Morogh/0 29.40,79.00
|mapmarker Dun Morogh/0 30.40,82.00
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Dun Morogh 26.78,79.83 |q 3361
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Dun Morogh 29.55,69.83 |q 3361 |zombiewalk
step
Enter the building |goto Dun Morogh 28.79,69.05 < 10 |walk |only if not (subzone("Anvilmar") and indoors())
talk Felix Whindlebolt##8416
|tip Walks around.
|tip Inside the building.
turnin A Refugee's Quandary##3361 |goto Dun Morogh 28.55,67.65
step
talk Thran Khorman##912
|tip Inside the building.
Train Abilities |trainer Thran Khorman##912 |goto Dun Morogh 28.83,67.24 |q 282
|only if Dwarf Warrior
step
talk Solm Hargrin##916
|tip Inside the building.
Train Abilities |trainer Solm Hargrin##916 |goto Dun Morogh 28.37,67.51 |q 282
|only if Rogue
step
talk Branstock Khalder##837
|tip Inside the building.
Train Abilities |trainer Branstock Khalder##837 |goto Dun Morogh 28.60,66.39 |q 282
|only if Priest
step
talk Bromos Grummner##926
|tip Inside the building.
Train Abilities |trainer Bromos Grummner##926 |goto Dun Morogh 28.83,68.33 |q 282
|only if Paladin
step
talk Thorgas Grimson##895
|tip Inside the building.
Train Abilities |trainer Thorgas Grimson##895 |goto Dun Morogh 29.18,67.46 |q 282
|only if Hunter
step
talk Marryk Nurribit##944
|tip Inside the building.
Train Abilities |trainer Marryk Nurribit##944 |goto Dun Morogh 28.71,66.36 |q 282
|only if Mage
step
talk Alamar Grimm##460
|tip Upstairs inside the building.
Train Abilities |trainer Alamar Grimm##460 |goto Dun Morogh 28.65,66.14 |q 282
|only if Warlock
step
Leave the building |goto Dun Morogh 28.79,69.05 < 10 |walk |only if subzone("Anvilmar") and indoors()
talk Mountaineer Thalos##1965
turnin Senir's Observations##282 |goto Dun Morogh 33.48,71.84
accept Senir's Observations##420 |goto Dun Morogh 33.48,71.84
step
talk Hands Springsprocket##6782
accept Supplies to Tannok##2160 |goto Dun Morogh 33.85,72.24
stickystart "Collect_Chunks_Of_Boar_Meat_And_Crag_Boar_Ribs"
step
Run through the tunnel and follow the road |goto Dun Morogh 34.12,71.51 < 10 |only if walking and subzone("Coldridge Pass")
talk Senir Whitebeard##1252
turnin Senir's Observations##420 |goto Dun Morogh 46.73,53.83
stickystop "Collect_Chunks_Of_Boar_Meat_And_Crag_Boar_Ribs"
step
talk Ragnar Thunderbrew##1267
accept Beer Basted Boar Ribs##384 |goto Dun Morogh 46.83,52.36
step
talk Tannok Frosthammer##6806
|tip Inside the building.
turnin Supplies to Tannok##2160 |goto Dun Morogh 47.22,52.19
step
talk Maxan Anvol##1226
|tip Inside the building.
accept Accept Garments of the Light##5625 |goto Dun Morogh/0 47.34,52.19
|only if Priest
step
Heal and Fortify Mountaineer Dolf |q 5625/1 |goto Dun Morogh/0 45.81,54.57
|tip Cast {o}Lesser Heal (Rank 2){} on Mountaineer Dolf.
|tip Cast {o}Power Word: Fortitude{} on Mountaineer Dolf.
|only if Priest
step
talk Maxan Anvol##1226
|tip Inside the building.
turnin Accept Garments of the Light##5625 |goto Dun Morogh/0 47.34,52.19
|only if Priest
step
talk Tharek Blackstone##1872
accept Tools for Steelgrill##400 |goto Dun Morogh 46.02,51.68
step
_NOTE:_
Use Weapon Stones
|tip We will train Mining and Blacksmithing.
|tip Allows you to make and use {o}Sharpening Stones{}.		|only if Warrior or Rogue
|tip Allows you to make and use {o}Weightstones{}.		|only if Paladin
|tip Increases damage.
|tip Mine {o}Copper Ore{} as you see it.
|tip Use the {g}Rough Stones{} to make sharpening stones.	|only if Warrior or Rogue
|tip Use the {g}Rough Stones{} to make weightstones.		|only if Paladin
Click Here to Continue |confirm |q 400
|only if Warrior or Rogue or Paladin
step
talk Tognus Flintfire##1241
|tip Walks around.
|tip Inside the building.
Train Apprentice Blacksmithing |skillmax Blacksmithing,75 |goto Dun Morogh/0 45.32,51.92
|only if Warrior or Rogue or Paladin
step
talk Thrawn Boltar##1690
|tip Inside the building.
buy Mining Pick##2901 |goto Dun Morogh/0 45.30,51.53
|only if Warrior or Rogue or Paladin
stickystart "Collect_Chunks_Of_Boar_Meat_And_Crag_Boar_Ribs"
step
talk Pilot Bellowfiz##1378
accept Stocking Jetsteam##317 |goto Dun Morogh 49.43,48.41
step
talk Pilot Stonegear##1377
accept The Grizzled Den##313 |goto Dun Morogh 49.62,48.61
step
talk Beldin Steelgrill##1376
turnin Tools for Steelgrill##400 |goto Dun Morogh 50.44,49.09
step
talk Loslor Rudge##1694
accept Ammo for Rumbleshot##5541 |goto Dun Morogh 50.08,49.42
step
talk Yarr Hammerstone##5392
|tip Downstairs inside the building.
Train Apprentice Mining |skillmax Mining,75 |goto Dun Morogh/0 50.01,50.31
|only if Warrior or Rogue or Paladin
stickystart "Collect_Thick_Bear_Fur"
step
click Ammo Crate
collect Rumbleshot's Ammo##13850 |q 5541/1 |goto Dun Morogh 44.14,56.94
step
kill Young Wendigo##1134, Wendigo##1135
|tip Yetis.
|tip Inside and outside the cave.
collect 8 Wendigo Mane##2671 |q 313/1 |goto Dun Morogh 42.33,54.03
|mapmarker Dun Morogh/0 39.40,46.20
|mapmarker Dun Morogh/0 39.60,48.80
|mapmarker Dun Morogh/0 41.40,51.20
|mapmarker Dun Morogh/0 41.60,45.40
|mapmarker Dun Morogh/0 41.60,49.00
step
Kill enemies
|tip Inside and outside the cave.
ding 7 |goto Dun Morogh 42.33,54.03
|mapmarker Dun Morogh/0 39.40,46.20
|mapmarker Dun Morogh/0 39.60,48.80
|mapmarker Dun Morogh/0 41.40,51.20
|mapmarker Dun Morogh/0 41.60,45.40
|mapmarker Dun Morogh/0 41.60,49.00
step
talk Hegnar Rumbleshot##1243
turnin Ammo for Rumbleshot##5541 |goto Dun Morogh 40.68,65.13
step
label "Collect_Thick_Bear_Fur"
kill Young Black Bear##1128+
collect 2 Thick Bear Fur##6952 |q 317/2 |goto Dun Morogh 41.40,59.20
|mapmarker Dun Morogh/0 36.20,60.20
|mapmarker Dun Morogh/0 38.80,61.80
|mapmarker Dun Morogh/0 42.00,66.80
|mapmarker Dun Morogh/0 43.20,45.40
|mapmarker Dun Morogh/0 43.80,52.00
|mapmarker Dun Morogh/0 44.20,48.60
|mapmarker Dun Morogh/0 44.40,55.20
|mapmarker Dun Morogh/0 45.40,58.60
|mapmarker Dun Morogh/0 47.40,50.40
|mapmarker Dun Morogh/0 50.20,52.60
step
label "Collect_Chunks_Of_Boar_Meat_And_Crag_Boar_Ribs"
kill Crag Boar##1125, Large Crag Boar##1126
collect 4 Chunk of Boar Meat##769 |q 317/1 |goto Dun Morogh 42.60,60.20 |future
collect 6 Crag Boar Rib##2886 |q 384/1 |goto Dun Morogh 42.60,60.20 |future
|tip Don't vendor them.
|mapmarker Dun Morogh/0 36.00,62.20
|mapmarker Dun Morogh/0 39.20,63.60
|mapmarker Dun Morogh/0 39.40,60.00
|mapmarker Dun Morogh/0 41.40,57.40
|mapmarker Dun Morogh/0 42.20,66.40
|mapmarker Dun Morogh/0 44.00,52.40
|mapmarker Dun Morogh/0 44.00,55.40
|mapmarker Dun Morogh/0 44.20,63.20
|mapmarker Dun Morogh/0 45.80,59.60
|mapmarker Dun Morogh/0 47.20,63.40
|mapmarker Dun Morogh/0 47.40,48.60
|mapmarker Dun Morogh/0 48.40,55.00
|mapmarker Dun Morogh/0 49.80,51.20
step
talk Senir Whitebeard##1252
accept Frostmane Hold##287 |goto Dun Morogh 46.73,53.83
step
talk Innkeeper Belm##1247
|tip Inside the building.
buy Rhapsody Malt##2894 |q 384/2 |goto Dun Morogh 47.38,52.52
step
talk Ragnar Thunderbrew##1267
turnin Beer Basted Boar Ribs##384 |goto Dun Morogh 46.83,52.36
step
talk Pilot Bellowfiz##1378
turnin Stocking Jetsteam##317 |goto Dun Morogh 49.43,48.41
accept Evershine##318 |goto Dun Morogh 49.43,48.41
step
talk Pilot Stonegear##1377
turnin The Grizzled Den##313 |goto Dun Morogh 49.62,48.61
step
Kill enemies
ding 8 |goto Dun Morogh 44.20,48.60
|mapmarker Dun Morogh/0 43.20,45.40
|mapmarker Dun Morogh/0 43.80,52.00
|mapmarker Dun Morogh/0 41.40,59.20
|mapmarker Dun Morogh/0 44.40,55.20
|mapmarker Dun Morogh/0 45.40,58.60
|mapmarker Dun Morogh/0 47.40,50.40
|mapmarker Dun Morogh/0 50.20,52.60
step
talk Grif Wildheart##1231
Train Abilities |trainer Grif Wildheart##1231 |goto Dun Morogh/0 45.81,53.04 |q 318
|only if Hunter
step
talk Gimrizz Shadowcog##5612
Train Abilities |trainer Gimrizz Shadowcog##5612 |goto Dun Morogh/0 47.33,53.69 |q 318
|only if Warlock
step
talk Dannie Fizzwizzle##6328
|tip Buy available Grimoires.
Train Demon Abilities |vendor Dannie Fizzwizzle##6328 |goto Dun Morogh 47.28,53.67 |q 318
|only if Warlock
step
talk Magis Sparkmantle##1228
|tip Upstairs inside the building.
Train Abilities |trainer Magis Sparkmantle##1228 |goto Dun Morogh/0 47.50,52.08 |q 318
|only if Mage
step
talk Azar Stronghammer##1232
|tip Upstairs inside the building.
Train Abilities |trainer Azar Stronghammer##1232 |goto Dun Morogh/0 47.60,52.07 |q 318
|only if Paladin
step
talk Maxan Anvol##1226
|tip Inside the building.
Train Abilities |trainer Maxan Anvol##1226 |goto Dun Morogh/0 47.34,52.19 |q 318
|only if Priest
step
talk Hogral Bakkan##1234
|tip Inside the building.
Train Abilities |trainer Hogral Bakkan##1234 |goto Dun Morogh/0 47.56,52.61 |q 318
|only if Rogue
step
talk Granis Swiftaxe##1229
|tip Inside the building.
Train Abilities |trainer Granis Swiftaxe##1229 |goto Dun Morogh/0 47.36,52.65 |q 318
|only if Warrior
step
talk Thamner Pol##2326
|tip Inside the building.
Train First Aid |skillmax First Aid,75 |goto Dun Morogh 47.18,52.61
|tip If possible.
step
_NOTE:_
Create Bandages in Downtime
|tip While waiting for things like boats.
|tip Increases skill in First Aid.
|tip Need higher skill to make better bandages.
|tip Keep bandages to heal yourself.
Click Here to Continue |confirm |q 412 |future
step
talk Razzle Sprysprocket##1269
|tip Inside the building.
accept Operation Recombobulation##412 |goto Dun Morogh 45.85,49.37
step
Follow the path |goto Dun Morogh 39.61,48.01 < 40 |only if walking
talk Tundra MacGrann##1266
|tip Avoid the {o}elite yeti{} that walks nearby.
|tip Top of the mountain.
accept Tundra MacGrann's Stolen Stash##312 |goto Dun Morogh 34.57,51.65
step
click MacGrann's Meat Locker
|tip Wait for the {o}elite yeti{} walk away.
|tip Inside the small cave.
collect MacGrann's Dried Meats##2667 |q 312/1 |goto Dun Morogh 38.51,53.93
|tip {o}HURRY{}.
|tip Yeti runs back quickly.
step
talk Tundra MacGrann##1266
|tip Avoid the {o}elite yeti{} that walks nearby.
|tip Top of the mountain.
turnin Tundra MacGrann's Stolen Stash##312 |goto Dun Morogh 34.57,51.65
step
talk Rejold Barleybrew##1374
turnin Evershine##318 |goto Dun Morogh 30.19,45.73
accept A Favor for Evershine##319 |goto Dun Morogh 30.19,45.73
accept The Perfect Stout##315 |goto Dun Morogh 30.19,45.73
step
talk Marleth Barleybrew##1375
accept Bitter Rivals##310 |goto Dun Morogh 30.19,45.53
step
kill Frostmane Seer##1397+
click Shimmerweed Basket+
|tip Wooden baskets.
collect 6 Shimmerweed##2676 |q 315/1 |goto Dun Morogh 40.00,42.40
|mapmarker Dun Morogh/0 41.60,43.80
|mapmarker Dun Morogh/0 42.40,35.80
|mapmarker Dun Morogh/0 42.60,33.80
step
kill 6 Ice Claw Bear##1196 |q 319/1 |goto Dun Morogh 30.40,42.20
kill 8 Elder Crag Boar##1127 |q 319/2 |goto Dun Morogh 30.40,42.20
kill 8 Snow Leopard##1201 |q 319/3 |goto Dun Morogh 30.40,42.20
|mapmarker Dun Morogh/0 25.80,46.40
|mapmarker Dun Morogh/0 26.40,55.40
|mapmarker Dun Morogh/0 28.00,42.20
|mapmarker Dun Morogh/0 28.40,52.60
|mapmarker Dun Morogh/0 28.60,47.40
|mapmarker Dun Morogh/0 30.80,35.40
|mapmarker Dun Morogh/0 31.60,38.00
|mapmarker Dun Morogh/0 32.60,47.80
|mapmarker Dun Morogh/0 34.60,31.60
|mapmarker Dun Morogh/0 34.60,35.40
|mapmarker Dun Morogh/0 35.40,46.40
|mapmarker Dun Morogh/0 37.80,34.40
|mapmarker Dun Morogh/0 37.80,42.40
step
Allow Enemies to Kill You
|tip Anywhere near {o}Brewnall Village{}.
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Dun Morogh 30.40,42.20 |q 319
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Dun Morogh 47.05,55.10 |q 319 |zombiewalk
step
talk Innkeeper Belm##1247
|tip Inside the building.
home Thunderbrew Distillery |goto Dun Morogh 47.38,52.52 |q 4761 |future
step
talk Innkeeper Belm##1247
|tip Inside the building.
buy Thunder Ale##2686 |goto Dun Morogh 47.38,52.52 |q 310
step
talk Jarven Thunderbrew##1373
|tip Downstairs inside the building.
accept Distracting Jarven##308 |goto Dun Morogh 47.64,52.66
|only if haveq(310)
step
click Unguarded Thunder Ale Barrel
|tip Takes a moment.
|tip Downstairs inside the building.
turnin Bitter Rivals##310 |goto Dun Morogh 47.70,52.69
accept Return to Marleth##311 |goto Dun Morogh 47.70,52.69
step
Follow the path |goto Dun Morogh 41.90,47.23 < 40 |only if walking
talk Marleth Barleybrew##1375
turnin Return to Marleth##311 |goto Dun Morogh 30.19,45.53
step
talk Rejold Barleybrew##1374
turnin A Favor for Evershine##319 |goto Dun Morogh 30.19,45.73
accept Return to Bellowfiz##320 |goto Dun Morogh 30.19,45.73
turnin The Perfect Stout##315 |goto Dun Morogh 30.19,45.73
step
Kill enemies
ding 9 |goto Dun Morogh 30.40,42.20
|mapmarker Dun Morogh/0 25.80,46.40
|mapmarker Dun Morogh/0 26.40,55.40
|mapmarker Dun Morogh/0 28.00,42.20
|mapmarker Dun Morogh/0 28.40,52.60
|mapmarker Dun Morogh/0 28.60,47.40
|mapmarker Dun Morogh/0 30.80,35.40
|mapmarker Dun Morogh/0 31.60,38.00
|mapmarker Dun Morogh/0 32.60,47.80
|mapmarker Dun Morogh/0 34.60,31.60
|mapmarker Dun Morogh/0 34.60,35.40
|mapmarker Dun Morogh/0 35.40,46.40
|mapmarker Dun Morogh/0 37.80,34.40
|mapmarker Dun Morogh/0 37.80,42.40
stickystart "Kill_Frostmane_Headhunters"
step
Enter the cave |goto Dun Morogh 24.84,50.89 < 20 |walk |only if not (subzone("Frostmane Hold") and indoors())
Fully Explore Frostmane Hold |q 287/2 |goto Dun Morogh 22.79,52.10
|tip Downstairs inside the cave.
step
label "Kill_Frostmane_Headhunters"
kill 5 Frostmane Headhunter##1123 |q 287/1 |goto Dun Morogh 24.87,50.90
|tip Inside and outside the cave. |notinsticky
|mapmarker Dun Morogh/0 21.40,54.60
|mapmarker Dun Morogh/0 22.40,51.60
|mapmarker Dun Morogh/0 24.00,53.00
|mapmarker Dun Morogh/0 26.00,51.40
step
Leave the cave |goto Dun Morogh 25.07,50.99 < 20 |walk |only if subzone("Frostmane Hold") and indoors()
kill Leper Gnome##1211+
collect 8 Restabilization Cog##3083 |q 412/1 |goto Dun Morogh 24.40,43.00
collect 8 Gyromechanic Gear##3084 |q 412/2 |goto Dun Morogh 24.40,43.00
|mapmarker Dun Morogh/0 24.40,39.80
|mapmarker Dun Morogh/0 25.40,45.60
|mapmarker Dun Morogh/0 26.00,41.80
|mapmarker Dun Morogh/0 27.00,36.40
step
Kill enemies
|tip Helps reach level 10 after quest turnins.
ding 9,4300 |goto Dun Morogh 24.40,43.00
|mapmarker Dun Morogh/0 24.40,39.80
|mapmarker Dun Morogh/0 25.40,45.60
|mapmarker Dun Morogh/0 26.00,41.80
|mapmarker Dun Morogh/0 27.00,36.40
step
Follow the path up |goto Dun Morogh 31.06,32.56 < 7 |only if walking and not zone("Wetlands")
Continue up the path |goto Dun Morogh 31.43,32.34 < 7 |only if walking and not zone("Wetlands")
Continue up the path |goto Dun Morogh 31.14,30.50 < 7 |only if walking and not zone("Wetlands")
Follow the path down |goto Dun Morogh 32.33,28.63 < 15 |only if walking and not zone("Wetlands")
Follow the path |goto Dun Morogh 32.74,27.11 < 20 |only if walking and not zone("Wetlands")
Jump to Your Death |complete isdead |goto Eastern Kingdoms 44.92,51.98 |q 983 |future |notravel
|tip While in {o}Wetlands{}, run {o}north{}.
|tip Jump off the cliff.
|tip Easier to reach Menethil Harbor.
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Wetlands 11.72,43.30 |q 983 |future |zombiewalk
step
talk Neal Allen##1448
|tip Walks around.
|tip Inside the building.
buy Bronze Tube##4371 |n
|tip If possible.
|tip Limited supply item.
|tip Needed later for Duskwood quest.
Visit the Vendor |vendor Neal Allen##1448 |goto Wetlands 10.75,56.75 |q 174 |future
step
talk Shellei Brondir##1571
fpath Menethil Harbor |goto Wetlands 9.49,59.69
step
talk Shellei Brondir##1571
|tip Open the flight map.
|tip Allows guide to learn your flight paths.
fpath Ironforge |goto Wetlands 9.49,59.69
step
talk Senir Whitebeard##1252
turnin Frostmane Hold##287 |goto Dun Morogh 46.73,53.82
accept The Reports##291 |goto Dun Morogh 46.73,53.82
step
talk Razzle Sprysprocket##1269
|tip Inside the building.
turnin Operation Recombobulation##412 |goto Dun Morogh 45.85,49.37
step
talk Pilot Bellowfiz##1378
turnin Return to Bellowfiz##320 |goto Dun Morogh 49.43,48.41
step
_NOTE:_
Stronger Ammo Available
|tip Buy level 10 ammo when restocking.
Click Here to Continue |confirm |q 291
|only if Hunter
step
talk Grif Wildheart##1231
Train Abilities |trainer Grif Wildheart##1231 |goto Dun Morogh/0 45.81,53.04 |q 291
|only if Hunter
step
talk Gimrizz Shadowcog##5612
Train Abilities |trainer Gimrizz Shadowcog##5612 |goto Dun Morogh/0 47.33,53.69 |q 291
|only if Warlock
step
talk Dannie Fizzwizzle##6328
|tip Buy available Grimoires.
Train Demon Abilities |vendor Dannie Fizzwizzle##6328 |goto Dun Morogh 47.28,53.67 |q 291
|only if Warlock
step
talk Magis Sparkmantle##1228
|tip Upstairs inside the building.
Train Abilities |trainer Magis Sparkmantle##1228 |goto Dun Morogh/0 47.50,52.08 |q 291
|only if Mage
step
talk Azar Stronghammer##1232
|tip Upstairs inside the building.
Train Abilities |trainer Azar Stronghammer##1232 |goto Dun Morogh/0 47.60,52.07 |q 291
|only if Paladin
step
talk Maxan Anvol##1226
|tip Inside the building.
Train Abilities |trainer Maxan Anvol##1226 |goto Dun Morogh/0 47.34,52.19 |q 291
|only if Priest
step
talk Hogral Bakkan##1234
|tip Inside the building.
Train Abilities |trainer Hogral Bakkan##1234 |goto Dun Morogh/0 47.56,52.61 |q 291
|only if Rogue
step
talk Granis Swiftaxe##1229
|tip Inside the building.
Train Abilities |trainer Granis Swiftaxe##1229 |goto Dun Morogh/0 47.36,52.65 |q 291
|only if Warrior
step
talk Grif Wildheart##1231
accept Taming the Beast##6064 |goto Dun Morogh 45.81,53.03
|only if Dwarf Hunter
step
use Taming Rod##15911
|tip On a Large Crag Boar.
Tame a Large Crag Boar |q 6064/1 |goto Dun Morogh 49.80,53.40
|mapmarker Dun Morogh/0 46.60,63.40
|mapmarker Dun Morogh/0 48.40,47.80
|mapmarker Dun Morogh/0 49.00,58.80
|mapmarker Dun Morogh/0 49.00,61.40
|mapmarker Dun Morogh/0 50.60,47.00
|mapmarker Dun Morogh/0 51.80,50.00
|mapmarker Dun Morogh/0 53.20,47.20
|only if Dwarf Hunter
step
talk Grif Wildheart##1231
turnin Taming the Beast##6064 |goto Dun Morogh 45.81,53.04
accept Taming the Beast##6084 |goto Dun Morogh 45.81,53.04
|only if Dwarf Hunter
step
use Taming Rod##15913
|tip On a Snow Leopard.
Tame a Snow Leopard |q 6084/1 |goto Dun Morogh 48.20,57.40
|only if Dwarf Hunter
|mapmarker Dun Morogh/0 46.80,63.60
|mapmarker Dun Morogh/0 48.20,61.00
|mapmarker Dun Morogh/0 50.40,59.40
step
talk Grif Wildheart##1231
turnin Taming the Beast##6084 |goto Dun Morogh 45.81,53.04
accept Taming the Beast##6085 |goto Dun Morogh 45.81,53.04
|only if Dwarf Hunter
step
use Taming Rod##15908
|tip On an Ice Claw Bear.
Tame an Ice Claw Bear |q 6085/1 |goto Dun Morogh 50.20,53.00
|mapmarker Dun Morogh/0 46.00,63.60
|mapmarker Dun Morogh/0 49.80,58.80
|mapmarker Dun Morogh/0 48.80,62.40
|only if Dwarf Hunter
step
talk Grif Wildheart##1231
turnin Taming the Beast##6085 |goto Dun Morogh 45.81,53.04
accept Training the Beast##6086 |goto Dun Morogh 45.81,53.04
|only if Dwarf Hunter
step
talk Belia Thundergranite##10090
|tip Inside the building.
turnin Training the Beast##6086 |goto Ironforge 70.87,85.80
|only if Dwarf Hunter
step
_NOTE:_
Train Your Pet
|tip Learn pet abilities from Pet Trainers.
|tip Cast {o}Beast Training{} to teach your pet.
Click Here to Continue |confirm |q 433 |future
|only if Dwarf Hunter
step
talk Belia Thundergranite##10090
|tip Inside the building.
Train Pet Abilities |trainer Belia Thundergranite##10090 |goto Ironforge/0 70.86,85.85 |q 433 |future
step
map Ironforge/0
path	follow strict;		loop on;	ants straight;		dist 30;	markers none
path 64.25,79.01 60.42,83.77 57.40,83.98 56.75,82.18 57.71,78.38
path 61.31,73.32 64.41,69.73 66.60,69.40 67.95,71.00 67.38,74.17
path 65.72,76.92
talk Sognar Cliffbeard##5124
|tip Walks around.
buy Tough Jerky##117 |n
|tip Buy {o}20{}, if possible.
|tip Used to feed your pet soon.
Visit the Vendor |vendor Sognar Cliffbeard##5124 |q 433 |future
|only if Dwarf Hunter
step
_NOTE:_
Tame an Ice Claw Bear
|tip Cast {o}Tame Beast{} on an Ice Claw Bear.
|tip Work your way east, if needed.
Click Here to Continue |confirm |goto Dun Morogh 51.80,44.40 |q 433 |future
|mapmarker Dun Morogh/0 55.40,43.60
|mapmarker Dun Morogh/0 59.40,52.00
|mapmarker Dun Morogh/0 61.00,56.40
|mapmarker Dun Morogh/0 64.80,60.00
|mapmarker Dun Morogh/0 66.40,50.80
|only if Dwarf Hunter
step
talk Senator Mehr Stonehallow##1977
accept The Public Servant##433 |goto Dun Morogh 68.67,55.97
step
talk Foreman Stonebrow##1254
accept Those Blasted Troggs!##432 |goto Dun Morogh 69.08,56.33
stickystart "Kill_Rockjaw_Skullthumpers"
step
kill 10 Rockjaw Bonesnapper##1117 |q 433/1 |goto Dun Morogh 70.70,56.49
|tip Inside the cave.
|mapmarker Dun Morogh/0 70.40,52.20
|mapmarker Dun Morogh/0 71.00,54.00
|mapmarker Dun Morogh/0 71.20,50.40
|mapmarker Dun Morogh/0 71.80,52.60
step
label "Kill_Rockjaw_Skullthumpers"
kill 6 Rockjaw Skullthumper##1115 |q 432/1 |goto Dun Morogh 70.70,56.49
|tip Inside and outside the cave. |notinsticky
|mapmarker Dun Morogh/0 67.20,58.60
|mapmarker Dun Morogh/0 68.00,60.60
|mapmarker Dun Morogh/0 69.20,56.40
|mapmarker Dun Morogh/0 70.40,52.40
|mapmarker Dun Morogh/0 70.80,54.80
|mapmarker Dun Morogh/0 71.40,50.40
|mapmarker Dun Morogh/0 72.60,52.20
step
Kill enemies
|tip Inside and outside the cave.
collect 10 Linen Cloth##2589 |goto Dun Morogh 70.70,56.49 |q 1648 |future
|tip Needed for a {o}Paladin class quest{} soon.
|tip Don't vendor them.
|mapmarker Dun Morogh/0 67.20,58.60
|mapmarker Dun Morogh/0 68.00,60.60
|mapmarker Dun Morogh/0 69.20,56.40
|mapmarker Dun Morogh/0 70.40,52.40
|mapmarker Dun Morogh/0 70.80,54.80
|mapmarker Dun Morogh/0 71.40,50.40
|mapmarker Dun Morogh/0 72.60,52.20
|only if Paladin
step
Leave the cave |goto Dun Morogh 70.70,56.49 < 20 |walk |only if subzone("Gol'Bolar Quarry Mine")
talk Senator Mehr Stonehallow##1977
turnin The Public Servant##433 |goto Dun Morogh 68.67,55.97
step
talk Foreman Stonebrow##1254
turnin Those Blasted Troggs!##432 |goto Dun Morogh 69.08,56.33
step
talk Cook Ghilm##1355
|tip Walks around.
Learn Cooking |skillmax Cooking,75 |goto Dun Morogh 68.38,54.49 |q 419 |future
step
talk Pilot Hammerfoot##1960
|tip Follow the road through the tunnel.
accept The Lost Pilot##419 |goto Dun Morogh 83.89,39.19
step
click A Dwarven Corpse
turnin The Lost Pilot##419 |goto Dun Morogh 79.67,36.17
accept A Pilot's Revenge##417 |goto Dun Morogh 79.67,36.17
step
kill Mangeclaw##1961
|tip White bear.
|tip Walks around.
collect Mangy Claw##3183 |q 417/1 |goto Dun Morogh/0 78.97,37.02
step
talk Pilot Hammerfoot##1960
turnin A Pilot's Revenge##417 |goto Dun Morogh/0 83.89,39.19
step
talk Mountaineer Stormpike##1343
|tip Upstairs inside the building.
accept Stormpike's Order##1338 |goto Loch Modan/0 24.76,18.40
step
Allow Enemies to Kill You
|tip Fast travel.
Die on Purpose |complete isdead |goto Loch Modan/0 29.76,16.06 |q 1338
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Loch Modan/0 32.51,46.95 |q 1338 |zombiewalk
step
talk Brock Stoneseeker##1681
|tip Walks around.
|tip Inside and outside the building.
accept Honor Students##6387 |goto Loch Modan 37.02,47.81
|only if Dwarf or Gnome
step
talk Thorgrum Borrelson##1572
turnin Honor Students##6387 |goto Loch Modan 33.94,50.95
accept Ride to Ironforge##6391 |goto Loch Modan 33.94,50.95
|only if Dwarf or Gnome
step
talk Thorgrum Borrelson##1572
fpath Thelsamar |goto Loch Modan/0 33.94,50.95
step
talk Buliwyf Stonehand##11865
|tip Inside the building.
Train Two-Handed Axes |complete weaponskill("TH_AXE") > 0 |goto Ironforge 61.17,89.52				|only if Gnome
Train Two-Handed Maces |complete weaponskill("TH_MACE") > 0 |goto Ironforge 61.17,89.52
|only if Warrior
step
talk Bixi Wobblebonk##13084
|tip Inside the building.
Train Thrown |complete weaponskill("THROWN") > 0 |goto Ironforge 62.23,89.62
|only if Warrior
step
talk Senator Barin Redstone##1274
turnin The Reports##291 |goto Ironforge 39.55,57.49
step
talk Golnir Bouldertoe##4256
|tip Downstairs inside the building.
turnin Ride to Ironforge##6391 |goto Ironforge 51.52,26.30
accept Gryth Thurden##6388 |goto Ironforge 51.52,26.30
|only if Dwarf or Gnome
step
talk Lago Blackwrench##6120
accept The Slaughtered Lamb##1715 |goto Ironforge 47.63,9.26
|only if Gnome Warlock
step
talk Brandur Ironhammer##5149
|tip Inside the building.
accept Tome of Divinity##2999 |goto Ironforge 23.12,6.14
|only if Dwarf Paladin
step
talk Tiza Battleforge##6179
|tip Upstairs inside the building.
turnin Tome of Divinity##2999 |goto Ironforge 27.64,12.19
accept The Tome of Divinity##1645 |goto Ironforge 27.64,12.19 |instant
|only if Dwarf Paladin
step
use Tome of Divinity##6916
accept The Tome of Divinity##1646
|only if Dwarf Paladin
step
talk Tiza Battleforge##6179
|tip Upstairs inside the building.
turnin The Tome of Divinity##1646 |goto Ironforge 27.64,12.19
accept The Tome of Divinity##1647 |goto Ironforge 27.64,12.19
|only if Dwarf Paladin
step
map Ironforge
path	follow strictbounce;	loop off;	ants straight;		dist 30;	markers none
path	21.75,51.75	21.97,54.66	22.70,58.39	23.32,61.81	23.72,63.80
path	25.81,67.98	27.55,71.41	31.72,78.27	36.24,81.32	39.82,83.22
path	42.92,84.10
talk John Turner##6175
|tip Walks in a large path.
turnin The Tome of Divinity##1647
accept The Tome of Divinity##1648
|only if Dwarf Paladin
step
map Ironforge
path	follow strictbounce;	loop off;	ants straight;		dist 30;	markers none
path	21.75,51.75	21.97,54.66	22.70,58.39	23.32,61.81	23.72,63.80
path	25.81,67.98	27.55,71.41	31.72,78.27	36.24,81.32	39.82,83.22
path	42.92,84.10
talk John Turner##6175
|tip Walks in a large path.
|tip Should have {o}10 Linen Cloth{} from earlier.
turnin The Tome of Divinity##1648
accept The Tome of Divinity##1778
|only if Dwarf Paladin
step
talk Tiza Battleforge##6179
|tip Upstairs inside the building.
turnin The Tome of Divinity##1778 |goto Ironforge 27.64,12.19
accept The Tome of Divinity##1779 |goto Ironforge 27.64,12.19
|only if Dwarf Paladin
step
talk Muiredon Battleforge##6178
|tip Upstairs inside the building.
turnin The Tome of Divinity##1779 |goto Ironforge 23.53,8.29
accept The Tome of Divinity##1783 |goto Ironforge 23.53,8.29
|only if Dwarf Paladin
step
use Symbol of Life##6866
|tip On Narm Faulk's corpse.
Watch the dialogue
talk Narm Faulk##6177
turnin The Tome of Divinity##1783 |goto Dun Morogh 78.32,58.09
accept The Tome of Divinity##1784 |goto Dun Morogh 78.32,58.09
|only if Dwarf Paladin
step
kill Dark Iron Spy##6123+
collect Dark Iron Script##6847 |q 1784/1 |goto Dun Morogh 77.60,59.00
|mapmarker Dun Morogh/0 76.40,61.40
|mapmarker Dun Morogh/0 76.80,60.00
|mapmarker Dun Morogh/0 77.80,62.00
|only if Dwarf Paladin
step
talk Muiredon Battleforge##6178
|tip Upstairs inside the building.
turnin The Tome of Divinity##1784 |goto Ironforge 23.53,8.29
accept The Tome of Divinity##1785 |goto Ironforge 23.53,8.29
|only if Dwarf Paladin
step
talk Tiza Battleforge##6179
|tip Upstairs inside the building.
turnin The Tome of Divinity##1785 |goto Ironforge 27.64,12.19
|only if Dwarf Paladin
step
talk Gryth Thurden##1573
turnin Gryth Thurden##6388 |goto Ironforge 55.51,47.74
|only if Dwarf or Gnome
step
Enter the Deeprun Tram |complete subzone("Deeprun Tram") |goto Ironforge 76.58,51.14 |q 1338
|tip Walk into the portal.
step
_Inside Deeprun Tram:_
talk Monty##12997
|tip Middle platform, near the wall.
|tip Ironforge section of the Deeprun Tram.
accept Deeprun Rat Roundup##6661
step
_Inside Deeprun Tram:_
use Rat Catcher's Flute##17117
|tip On Deeprun Rats.
|tip Small grey rats.
|tip Ironforge section of the Deeprun Tram.
Capture #5# Rats |q 6661/1
step
_Inside Deeprun Tram:_
talk Monty##12997
|tip Middle platform, near the wall.
|tip Ironforge section of the Deeprun Tram.
turnin Deeprun Rat Roundup##6661
accept Me Brother, Nipsy##6662
step
_Inside Deeprun Tram:_
Ride the Tram
|tip Ride the tram to Stormwind City.
talk Nipsy##13018
|tip Middle platform, near the wall.
|tip Stormwind City section of the Deeprun Tram.
turnin Me Brother, Nipsy##6662
step
_Inside Deeprun Tram:_
Enter Stormwind City |complete zone("Stormwind City") |q 1338
|tip Walk into the portal.
step
talk Furen Longbeard##5413
turnin Stormpike's Order##1338 |goto Stormwind City/0 58.09,16.55
step
talk Ilsa Corbin##5480
|tip Upstairs inside the building.
accept A Warrior's Training##1638 |goto Stormwind City 78.50,45.71
|only if Warrior
step
talk Harry Burlguard##6089
|tip Inside the building.
turnin A Warrior's Training##1638 |goto Stormwind City 74.25,37.26
accept Bartleby the Drunk##1639 |goto Stormwind City 74.25,37.26
|only if Warrior
step
talk Bartleby##6090
|tip Walks around.
|tip Inside the building.
turnin Bartleby the Drunk##1639 |goto Stormwind City 73.83,37.17
accept Beat Bartleby##1640 |goto Stormwind City 73.83,37.17
|tip You will be attacked.
|only if Warrior
step
kill Bartleby##6090
|tip Walks around.
|tip Inside the building.
Beat Bartleby |q 1640/1 |goto Stormwind City 73.83,37.17
|only if Warrior
step
talk Bartleby##6090
|tip Walks around.
|tip Inside the building.
turnin Beat Bartleby##1640 |goto Stormwind City 73.83,37.17
accept Bartleby's Mug##1665 |goto Stormwind City 73.83,37.17
|only if Warrior
step
talk Harry Burlguard##6089
|tip Inside the building.
turnin Bartleby's Mug##1665 |goto Stormwind City 74.25,37.26
|only if Warrior
step
talk Woo Ping##11867
|tip Inside the building.
Train Two-Handed Swords |complete weaponskill("TH_SWORD") > 0 |goto Stormwind City 57.13,57.71
Train Staves |complete weaponskill("TH_STAFF") > 0 |goto Stormwind City 57.13,57.71
|only if Warrior
step
Enter the building |goto Stormwind City/0 29.16,74.15 < 10 |walk |only if not (subzone("The Slaughtered Lamb") and indoors())
talk Gakin the Darkbinder##6122
|tip Downstairs inside the building.
turnin The Slaughtered Lamb##1715 |goto Stormwind City 25.26,78.56
accept Surena Caledon##1688 |goto Stormwind City 25.26,78.56
|only Gnome Warlock
step
talk Surena Caledon##881
|tip Inside the building.
collect Surena's Choker##6810 |q 1688/1 |goto Elwynn Forest 71.02,80.78
|only if Gnome Warlock
step
Enter the building |goto Stormwind City/0 29.16,74.15 < 10 |walk |only if not (subzone("The Slaughtered Lamb") and indoors())
talk Gakin the Darkbinder##6122
|tip Downstairs inside the building.
turnin Surena Caledon##1688 |goto Stormwind City 25.26,78.56
accept The Binding##1689 |goto Stormwind City 25.26,78.56
|only Gnome Warlock
step
use Bloodstone Choker##6928
|tip Stand on the pink symbol.
|tip Inside the crypt.
|tip Downstairs inside the building.
kill Summoned Voidwalker##5676 |q 1689/1 |goto Stormwind City 25.11,77.46
|only if Gnome Warlock
step
talk Gakin the Darkbinder##6122
|tip Above the crypt.
|tip Downstairs inside the building.
turnin The Binding##1689 |goto Stormwind City 25.25,78.53
|only if Gnome Warlock
step
talk Spackle Thornberry##5520
|tip Buy available Grimoires.
|tip Downstairs inside the building.
Train Demon Abilities |vendor Spackle Thornberry##5520 |goto Stormwind City 25.66,77.66 |q 983 |future
|only if Warlock
step
talk Woo Ping##11867
|tip Inside the building.
Train Staves |complete weaponskill("TH_STAFF") > 0 |goto Stormwind City 57.13,57.71
Train One-Handed Swords |complete weaponskill("SWORD") > 0 |goto Stormwind City 57.13,57.71
|only if Warlock
step
talk Woo Ping##11867
|tip Inside the building.
Train Two-Handed Swords |complete weaponskill("TH_SWORD") > 0 |goto Stormwind City 57.13,57.71
|only if Paladin
step
talk Woo Ping##11867
|tip Inside the building.
Train One-Handed Swords |complete weaponskill("SWORD") > 0 |goto Stormwind City 57.13,57.71
|only if Rogue
step
talk Woo Ping##11867
|tip Inside the building.
Train Staves |complete weaponskill("TH_STAFF") > 0 |goto Stormwind City 57.13,57.71
|only if Priest
step
talk Woo Ping##11867
|tip Inside the building.
Train One-Handed Swords |complete weaponskill("SWORD") > 0 |goto Stormwind City 57.13,57.71
|only if Mage
step
Run up the ramp |goto Stormwind City 62.39,62.31 < 15 |only if walking
talk Dungar Longdrink##352
|tip Inside the building.
fpath Stormwind |goto Stormwind City 66.27,62.14
step
talk Neal Allen##1448
|tip Walks around.
|tip Inside the building.
buy Bronze Tube##4371 |n
|tip If possible.
|tip Limited supply item.
|tip Needed later for Duskwood quest.
Visit the Vendor |vendor Neal Allen##1448 |goto Wetlands 10.75,56.75 |q 174 |future
|only if itemcount(4371) == 0
step
talk Vesprystus##3838
fpath Rut'theran Village |goto Teldrassil 58.40,94.02
|only if Hunter
step
talk Ilyenia Moonfire##11866
Train Bows |complete weaponskill("BOW") > 0 |goto Darnassus 57.56,46.73
Train Staves |complete weaponskill("TH_STAFF") > 0 |goto Darnassus 57.56,46.73
|only if Hunter
]])
ZygorGuidesViewer:RegisterGuide("Leveling Guides\\Starter Guides (1-11)\\Night Elf Starter (1-11)",{
image=ZGV.IMAGESDIR.."Teldrassil",
condition_suggested=function() return raceclass('NightElf') and level <= 11 end,
condition_suggested_exclusive=true,
condition_visible=function() return NightElf end,
linked = {"Leveling Guides\\Hidden Guides"},
linkedhidden = true,
next="Leveling Guides\\Classic (11-60)\\Darkshore (11-14)",
},[[
defaultfor NightElf
step
_NOTE:_
Wrong Character Race
|tip Guide written for {o}Night Elf{} characters.
|tip Other races may encounter issues.
Click Here to Continue |confirm
|only if not NightElf
step
_Destroy This Item:_
|tip Saves bag space.
|tip You'll get one later.
trash Hearthstone##6948 |q 933
step
_NOTE:_
Manage Your Ammo
|tip Make sure you always have ammo.
|tip You need it to attack enemies.
|tip {o}General Goods{} vendors sell it (also Bow & Gun vendors).
|tip Try to keep your ammo bag full.
Click Here to Continue |confirm |q 456 |future
|only if Hunter
step
kill Young Nightsaber##2031, Young Thistle Boar##1984
|tip Loot items worth at least {o}10 copper{} to sell.
|tip Allows training a spell early.
Click to continue |confirm |goto Teldrassil/0 58.20,45.40 |q 456 |future
|mapmarker Teldrassil/0 56.40,44.40
|mapmarker Teldrassil/0 60.40,44.20
|mapmarker Teldrassil/0 61.20,41.40
|mapmarker Teldrassil/0 63.00,42.60
|mapmarker Teldrassil/0 64.20,40.80
|only if Warrior
step
talk Dellylah##6091
|tip {o}Ground floor{} inside the building.
Sell Items |vendor Dellylah##6091 |goto Teldrassil/0 59.60,40.69 |q 456 |future
|only if Warrior
step
talk Alyissia##3593
|tip {o}Ground floor{} inside the building.
Train Abilities |trainer Alyissia##3593 |goto Teldrassil/0 59.64,38.44 |q 456 |future
|only if Warrior
step
talk Conservator Ilthalaine##2079
accept The Balance of Nature##456 |goto Teldrassil 58.69,44.27
step
kill 7 Young Nightsaber##2031 |q 456/1 |goto Teldrassil/0 58.20,45.40
kill 4 Young Thistle Boar##1984 |q 456/2 |goto Teldrassil/0 58.20,45.40
|mapmarker Teldrassil/0 56.40,44.40
|mapmarker Teldrassil/0 60.40,44.20
|mapmarker Teldrassil/0 61.20,41.40
|mapmarker Teldrassil/0 63.00,42.60
|mapmarker Teldrassil/0 64.20,40.80
step
talk Dirania Silvershine##8583
accept A Good Friend##4495 |goto Teldrassil 60.90,41.96
step
talk Melithar Staghelm##2077
accept The Woodland Protector##458 |goto Teldrassil 59.93,42.48
step
talk Conservator Ilthalaine##2079
turnin The Balance of Nature##456 |goto Teldrassil 58.70,44.27
accept The Balance of Nature##457 |goto Teldrassil 58.70,44.27
accept Simple Sigil##3116 |goto Teldrassil 58.70,44.27		|only if NightElf Warrior
accept Encrypted Sigil##3118 |goto Teldrassil 58.70,44.27	|only if NightElf Rogue
accept Hallowed Sigil##3119 |goto Teldrassil 58.70,44.27	|only if NightElf Priest
accept Etched Sigil##3117 |goto Teldrassil 58.70,44.27		|only if NightElf Hunter
accept Verdant Sigil##3120 |goto Teldrassil 58.70,44.27		|only if NightElf Druid
step
talk Alyissia##3593
|tip Inside the building.
turnin Simple Sigil##3116 |goto Teldrassil 59.63,38.45
|only if NightElf Warrior
step
talk Alyissia##3593
|tip {o}Ground floor{} inside the building.
Train Abilities |trainer Alyissia##3593 |goto Teldrassil/0 59.64,38.44 |q 458
|only if Warrior
step
talk Frahun Shadewhisper##3594
|tip {o}Ground floor{} inside the building.
turnin Encrypted Sigil##3118 |goto Teldrassil 59.64,38.66
|only if NightElf Rogue
step
talk Frahun Shadewhisper##3594
|tip {o}Ground floor{} inside the building.
Train Abilities |trainer Frahun Shadewhisper##3594 |goto Teldrassil 59.64,38.66 |q 458
|only if Rogue
step
talk Shanda##3595
|tip Upstairs inside the building.
turnin Hallowed Sigil##3119 |goto Teldrassil 59.17,40.44
|only if NightElf Priest
step
talk Shanda##3595
|tip Upstairs inside the building.
Train Abilities |trainer Shanda##3595 |goto Teldrassil 59.17,40.44 |q 458
|only if Priest
step
Run up the large ramp |goto Teldrassil 57.53,41.63 < 15 |only if walking
talk Ayanna Everstride##3596
|tip Up in the tall tree.
|tip In a side room.
turnin Etched Sigil##3117 |goto Teldrassil 58.65,40.45
|only if NightElf Hunter
step
talk Ayanna Everstride##3596
|tip Up in the tall tree.
|tip In a side room.
Train Abilities |trainer Ayanna Everstride##3596 |goto Teldrassil 58.65,40.45 |q 458
|only if Hunter
step
Run up the large ramp |goto Teldrassil 57.53,41.63 < 15 |only if walking
talk Mardant Strongoak##3597
|tip Up in the tall tree.
|tip In a side room.
turnin Verdant Sigil##3120 |goto Teldrassil 58.63,40.29
|only if NightElf Druid
step
talk Mardant Strongoak##3597
|tip Up in the tall tree.
|tip In a side room.
Train Abilities |trainer Mardant Strongoak##3597 |goto Teldrassil 58.63,40.29 |q 458
|only if Druid
step
talk Tarindrella##1992
|tip Walks around.
turnin The Woodland Protector##458 |goto Teldrassil 57.83,45.20
accept The Woodland Protector##459 |goto Teldrassil 57.83,45.20
step
kill Grell##1988+
collect 8 Fel Moss##3297 |q 459/1 |goto Teldrassil 56.08,45.83
|mapmarker Teldrassil/0 56.40,41.40
|mapmarker Teldrassil/0 54.75,44.01
step
Kill enemies
ding 3 |goto Teldrassil 56.08,45.83
|mapmarker Teldrassil/0 56.40,41.40
|mapmarker Teldrassil/0 54.75,44.01
stickystart "Kill_Mangy_Nightsabers_And_Thistle_Boars"
step
talk Gilshalan Windwalker##2082
accept Webwood Venom##916 |goto Teldrassil 57.81,41.65
step
label "Kill_Mangy_Nightsabers_And_Thistle_Boars"
kill 7 Mangy Nightsaber##2032 |q 457/1 |goto Teldrassil 59.40,37.60
kill 7 Thistle Boar##1985 |q 457/2 |goto Teldrassil 59.40,37.60
|mapmarker Teldrassil/0 58.40,35.20
|mapmarker Teldrassil/0 60.40,33.40
|mapmarker Teldrassil/0 60.60,35.60
|mapmarker Teldrassil/0 61.20,39.20
|mapmarker Teldrassil/0 62.20,34.40
|mapmarker Teldrassil/0 62.40,37.40
|mapmarker Teldrassil/0 63.60,39.40
stickystart "Collect_Webwood_Venom_Sacs"
step
talk Iverron##8584
turnin A Good Friend##4495 |goto Teldrassil 54.60,32.99
accept A Friend in Need##3519 |goto Teldrassil 54.60,32.99
step
label "Collect_Webwood_Venom_Sacs"
kill Webwood Spider##1986+
|tip Inside and outside the cave. |notinsticky
collect 10 Webwood Venom Sac##5166 |q 916/1 |goto Teldrassil 56.80,31.59
|mapmarker Teldrassil/0 55.40,28.00
|mapmarker Teldrassil/0 55.40,32.80
|mapmarker Teldrassil/0 56.20,24.80
|mapmarker Teldrassil/0 56.40,34.60
|mapmarker Teldrassil/0 57.60,27.80
|mapmarker Teldrassil/0 58.00,34.60
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
|tip Inside and outside the cave.
Die on Purpose |complete isdead |goto Teldrassil 56.80,31.59 |q 916
|mapmarker Teldrassil/0 55.40,28.00
|mapmarker Teldrassil/0 55.40,32.80
|mapmarker Teldrassil/0 56.20,24.80
|mapmarker Teldrassil/0 56.40,34.60
|mapmarker Teldrassil/0 57.60,27.80
|mapmarker Teldrassil/0 58.00,34.60
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Teldrassil 58.72,42.34 |q 916 |zombiewalk
step
talk Gilshalan Windwalker##2082
turnin Webwood Venom##916 |goto Teldrassil 57.81,41.65
accept Webwood Egg##917 |goto Teldrassil 57.81,41.65
step
talk Conservator Ilthalaine##2079
turnin The Balance of Nature##457 |goto Teldrassil 58.70,44.26
step
talk Tarindrella##1992
|tip Walks around.
turnin The Woodland Protector##459 |goto Teldrassil 57.83,45.20
step
talk Dirania Silvershine##8583
turnin A Friend in Need##3519 |goto Teldrassil 60.90,41.96
accept Iverron's Antidote##3521 |goto Teldrassil 60.90,41.96
step
talk Alyissia##3593
|tip {o}Ground floor{} inside the building.
Train Abilities |trainer Alyissia##3593 |goto Teldrassil/0 59.64,38.44 |q 3521
|only if Warrior
step
talk Frahun Shadewhisper##3594
|tip {o}Ground floor{} inside the building.
Train Abilities |trainer Frahun Shadewhisper##3594 |goto Teldrassil 59.64,38.66 |q 3521
|only if Rogue
step
talk Shanda##3595
|tip Upstairs inside the building.
Train Abilities |trainer Shanda##3595 |goto Teldrassil 59.17,40.44 |q 3521
|only if Priest
step
Run up the large ramp |goto Teldrassil 57.53,41.63 < 15 |only if walking
talk Ayanna Everstride##3596
|tip Up in the tall tree.
|tip In a side room.
Train Abilities |trainer Ayanna Everstride##3596 |goto Teldrassil 58.65,40.45 |q 3521
|only if Hunter
step
Run up the large ramp |goto Teldrassil 57.53,41.63 < 15 |only if walking
talk Mardant Strongoak##3597
|tip Up in the tall tree.
|tip In a side room.
Train Abilities |trainer Mardant Strongoak##3597 |goto Teldrassil 58.63,40.29 |q 3521
|only if Druid
step
click Hyacinth Mushroom+
|tip Clusters of pink mushrooms.
|tip Usually near trees.
collect 7 Hyacinth Mushroom##10639 |q 3521/1 |goto Teldrassil 62.40,44.10
|mapmarker Teldrassil/0 53.30,38.60
|mapmarker Teldrassil/0 54.50,43.20
|mapmarker Teldrassil/0 55.40,46.60
|mapmarker Teldrassil/0 56.30,39.20
|mapmarker Teldrassil/0 56.40,42.20
|mapmarker Teldrassil/0 57.30,36.90
|mapmarker Teldrassil/0 58.30,46.00
|mapmarker Teldrassil/0 58.60,41.40
|mapmarker Teldrassil/0 59.90,39.80
|mapmarker Teldrassil/0 60.40,36.30
|mapmarker Teldrassil/0 60.50,46.60
|mapmarker Teldrassil/0 60.90,30.30
|mapmarker Teldrassil/0 61.40,33.50
|mapmarker Teldrassil/0 62.90,36.00
|mapmarker Teldrassil/0 63.00,40.70
|mapmarker Teldrassil/0 63.20,38.00
|mapmarker Teldrassil/0 65.10,42.70
step
click Moonpetal Lily+
|tip Large orange flowers.
collect 4 Moonpetal Lily##10641 |q 3521/2 |goto Teldrassil 58.70,38.10
|mapmarker Teldrassil/0 56.40,38.90
|mapmarker Teldrassil/0 57.40,36.00
step
Kill enemies
ding 5 |goto Teldrassil 59.40,37.60
|mapmarker Teldrassil/0 58.40,35.20
|mapmarker Teldrassil/0 60.40,33.40
|mapmarker Teldrassil/0 60.60,35.60
|mapmarker Teldrassil/0 61.20,39.20
|mapmarker Teldrassil/0 62.20,34.40
|mapmarker Teldrassil/0 62.40,37.40
|mapmarker Teldrassil/0 63.60,39.40
stickystart "Collect_Webwood_Ichor"
step
Enter the cave |goto Teldrassil 56.79,31.41 < 20 |walk
Follow the path down |goto Teldrassil 56.83,28.94 < 10 |walk
Follow the path up |goto Teldrassil 55.75,25.49 < 10 |walk
click Webwood Eggs
|tip Upstairs inside the cave.
collect Webwood Egg##5167 |q 917/1 |goto Teldrassil 56.80,26.43
step
label "Collect_Webwood_Ichor"
kill Webwood Spider##1986+
|tip Inside and outside the cave. |notinsticky
collect Webwood Ichor##10640 |q 3521/3 |goto Teldrassil 56.80,31.59
|mapmarker Teldrassil/0 55.40,28.00
|mapmarker Teldrassil/0 55.40,32.80
|mapmarker Teldrassil/0 56.20,24.80
|mapmarker Teldrassil/0 56.40,34.60
|mapmarker Teldrassil/0 57.60,27.80
|mapmarker Teldrassil/0 58.00,34.60
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
|tip Inside and outside the cave.
Die on Purpose |complete isdead |goto Teldrassil 56.80,31.59 |q 3521
|mapmarker Teldrassil/0 55.40,28.00
|mapmarker Teldrassil/0 55.40,32.80
|mapmarker Teldrassil/0 56.20,24.80
|mapmarker Teldrassil/0 56.40,34.60
|mapmarker Teldrassil/0 57.60,27.80
|mapmarker Teldrassil/0 58.00,34.60
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Teldrassil 58.72,42.34 |q 3521 |zombiewalk
step
talk Gilshalan Windwalker##2082
turnin Webwood Egg##917 |goto Teldrassil 57.81,41.65
accept Tenaron's Summons##920 |goto Teldrassil 57.81,41.65
step
Run up the large ramp |goto Teldrassil 57.54,41.62 < 15 |only if walking
talk Tenaron Stormgrip##3514
|tip Top of the tall tree.
|tip In a side room.
turnin Tenaron's Summons##920 |goto Teldrassil 59.07,39.45
accept Crown of the Earth##921 |goto Teldrassil 59.07,39.45
step
talk Dirania Silvershine##8583
turnin Iverron's Antidote##3521 |goto Teldrassil 60.90,41.96
accept Iverron's Antidote##3522 |goto Teldrassil 60.90,41.96
step
_NOTE:_
HURRY
|tip Timed quest.
Click Here to Continue |confirm |q 3522
step
use Crystal Phial##5185
collect Filled Crystal Phial##5184 |q 921/1 |goto Teldrassil 59.94,33.04
step
talk Iverron##8584
turnin Iverron's Antidote##3522 |goto Teldrassil 54.59,32.99
step
Kill enemies
|tip Inside and outside the cave.
ding 6 |goto Teldrassil 56.80,31.59
|mapmarker Teldrassil/0 55.40,28.00
|mapmarker Teldrassil/0 55.40,32.80
|mapmarker Teldrassil/0 56.20,24.80
|mapmarker Teldrassil/0 56.40,34.60
|mapmarker Teldrassil/0 57.60,27.80
|mapmarker Teldrassil/0 58.00,34.60
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
|tip Inside and outside the cave.
Die on Purpose |complete isdead |goto Teldrassil 56.80,31.59 |q 921
|mapmarker Teldrassil/0 55.40,28.00
|mapmarker Teldrassil/0 55.40,32.80
|mapmarker Teldrassil/0 56.20,24.80
|mapmarker Teldrassil/0 56.40,34.60
|mapmarker Teldrassil/0 57.60,27.80
|mapmarker Teldrassil/0 58.00,34.60
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Teldrassil 58.72,42.34 |q 921 |zombiewalk
step
talk Shanda##3595
|tip Upstairs inside the building.
accept In Favor of Elune##5622 |goto Teldrassil 59.17,40.44
|only if Priest
step
Run up the large ramp |goto Teldrassil 57.54,41.62 < 15 |only if walking
talk Tenaron Stormgrip##3514
|tip Top of the tall tree.
|tip In a side room.
turnin Crown of the Earth##921 |goto Teldrassil 59.07,39.45
accept Crown of the Earth##928 |goto Teldrassil 59.07,39.45
step
talk Porthannius##6780
accept Dolanaar Delivery##2159 |goto Teldrassil 61.16,47.64
step
talk Zenn Foulhoof##2150
|tip Walks around.
accept Zenn's Bidding##488 |goto Teldrassil 60.45,56.15
stickystart "Collect_Strigid_Owl_Feathers"
stickystart "Collect_Nightsaber_Fangs"
stickystart "Collect_Webwood_Spider_Silk_And_Small_Spider_Legs"
step
talk Syral Bladeleaf##2083
accept Denalan's Earth##997 |goto Teldrassil 56.08,57.73
stickystop "Collect_Strigid_Owl_Feathers"
stickystop "Collect_Nightsaber_Fangs"
stickystop "Collect_Webwood_Spider_Silk_And_Small_Spider_Legs"
step
talk Athridas Bearmantle##2078
accept A Troubling Breeze##475 |goto Teldrassil 55.95,57.28
step
talk Laurna Morninglight##3600
|tip {o}Ground floor{} inside the building.
turnin In Favor of Elune##5622 |goto Teldrassil 55.56,56.75
accept Garments of the Moon##5621 |goto Teldrassil 55.56,56.75
|only if Priest
step
talk Laurna Morninglight##3600
|tip {o}Ground floor{} inside the building.
Train Abilities |trainer Laurna Morninglight##3600 |goto Teldrassil 55.56,56.75 |q 475
|only if Priest
step
talk Byancie##6094
|tip {o}Ground floor{} inside the building.
Train First Aid |skillmax First Aid,75 |goto Teldrassil/0 55.29,56.82
|tip If possible.
step
_NOTE:_
Create Bandages in Downtime
|tip While waiting for things like boats.
|tip Increases skill in First Aid.
|tip Need higher skill to make better bandages.
|tip Keep bandages to heal yourself.
Click Here to Continue |confirm |q 475
step
talk Tallonkai Swiftroot##3567
|tip Top of the tower.
accept Twisted Hatred##932 |goto Teldrassil 55.57,56.95
accept The Emerald Dreamcatcher##2438 |goto Teldrassil 55.57,56.95
step
talk Kyra Windblade##3598
|tip Inside the building.
Train Abilities |trainer Kyra Windblade##3598 |goto Teldrassil/0 56.22,59.20 |q 475
|only if Warrior
step
talk Innkeeper Keldamyr##6736
|tip Upstairs inside the building.
turnin Dolanaar Delivery##2159 |goto Teldrassil 55.62,59.79
step
talk Jannok Breezesong##3599
|tip Inside the building.
Train Abilities |trainer Jannok Breezesong##3599 |goto Teldrassil/0 56.38,60.14 |q 475
|only if Rogue
step
talk Dazalar##3601
Train Abilities |trainer Dazalar##3601 |goto Teldrassil/0 56.68,59.49 |q 475
|only if Hunter
step
talk Kal##3602
Train Abilities |trainer Kal##3602 |goto Teldrassil/0 55.95,61.56 |q 475
|only if Druid
step
talk Corithras Moonrage##3515
turnin Crown of the Earth##928 |goto Teldrassil 56.14,61.71
accept Crown of the Earth##929 |goto Teldrassil 56.14,61.71
step
Heal and Fortify Sentinel Shaya |q 5621/1 |goto Teldrassil 57.24,63.51
|tip Cast {o}Lesser Heal (Rank 2){} on Sentinel Shaya.
|tip Cast {o}Power Word: Fortitude{} on Sentinel Shaya.
|only if Priest
step
talk Malorne Bladeleaf##3604
|tip Inside the building.
Learn Herbalism |skillmax Herbalism,75 |goto Teldrassil 57.72,60.64
|tip Gather {o}5 Earthroot{} as you do quests.
|tip Needed for later class quest.
|tip Once you have them, you can abandon Herbalism.
|only if Druid
stickystart "Collect_Earthroot_Druid"
step
talk Denalan##2080
|tip Walks around.
turnin Denalan's Earth##997 |goto Teldrassil 60.90,68.49
step
Watch the dialogue
talk Denalan##2080
|tip Walks around.
accept Timberling Seeds##918 |goto Teldrassil 60.80,68.54
accept Timberling Sprouts##919 |goto Teldrassil 60.80,68.54
stickystart "Collect_Timberling_Seeds"
step
click Timberling Sprout+
|tip Brown root balls.
collect 12 Timberling Sprout##5169 |q 919/1 |goto Teldrassil 62.10,68.40
|mapmarker Teldrassil/0 51.40,73.30
|mapmarker Teldrassil/0 53.00,68.90
|mapmarker Teldrassil/0 55.60,70.50
|mapmarker Teldrassil/0 57.40,64.40
|mapmarker Teldrassil/0 58.70,72.00
|mapmarker Teldrassil/0 60.10,66.00
step
label "Collect_Timberling_Seeds"
kill Timberling##2022+
collect 8 Timberling Seed##5168 |q 918/1 |goto Teldrassil 60.40,66.60
|mapmarker Teldrassil/0 54.20,66.00
|mapmarker Teldrassil/0 57.20,65.40
|mapmarker Teldrassil/0 57.40,69.20
|mapmarker Teldrassil/0 58.40,72.80
|mapmarker Teldrassil/0 59.60,63.40
|mapmarker Teldrassil/0 61.00,70.00
step
talk Denalan##2080
|tip Walks around.
turnin Timberling Seeds##918 |goto Teldrassil 60.80,68.54
accept Rellian Greenspyre##922 |goto Teldrassil 60.80,68.54
turnin Timberling Sprouts##919 |goto Teldrassil 60.80,68.54
stickystart "Collect_Strigid_Owl_Feathers"
stickystart "Collect_Nightsaber_Fangs"
stickystart "Collect_Webwood_Spider_Silk_And_Small_Spider_Legs"
step
use Jade Phial##5619
collect Filled Jade Phial##5639 |q 929/1 |goto Teldrassil 63.38,58.08
step
talk Gaerolas Talvethren##2107
|tip Upstairs inside the building.
turnin A Troubling Breeze##475 |goto Teldrassil 66.26,58.52
accept Gnarlpine Corruption##476 |goto Teldrassil 66.26,58.52
step
click Tallonkai's Dresser
|tip Inside the building.
collect Emerald Dreamcatcher##8048 |q 2438/1 |goto Teldrassil 68.01,59.63
step
label "Collect_Strigid_Owl_Feathers"
kill Strigid Owl##1995
collect 3 Strigid Owl Feather##3411 |q 488/2 |goto Teldrassil 64.60,54.60
|mapmarker Teldrassil/0 57.60,56.20
|mapmarker Teldrassil/0 58.40,60.20
|mapmarker Teldrassil/0 61.00,50.60
|mapmarker Teldrassil/0 63.00,64.00
|mapmarker Teldrassil/0 64.40,61.20
|mapmarker Teldrassil/0 67.40,52.60
|mapmarker Teldrassil/0 68.00,62.00
step
label "Collect_Nightsaber_Fangs"
kill Nightsaber##2042+
|tip Black tigers.
collect 3 Nightsaber Fang##3409 |q 488/1 |goto Teldrassil 62.00,61.00
|mapmarker Teldrassil/0 57.20,54.80
|mapmarker Teldrassil/0 58.40,57.80
|mapmarker Teldrassil/0 58.40,61.40
|mapmarker Teldrassil/0 61.20,55.40
|mapmarker Teldrassil/0 64.20,56.20
|mapmarker Teldrassil/0 66.60,51.20
|mapmarker Teldrassil/0 68.00,54.20
step
label "Collect_Webwood_Spider_Silk_And_Small_Spider_Legs"
kill Webwood Lurker##1998+
|tip Green spiders.
collect 3 Webwood Spider Silk##3412 |q 488/3 |goto Teldrassil 59.40,59.20
collect 7 Small Spider Leg##5465 |goto Teldrassil 59.40,59.20 |q 4161 |future
|tip Don't vendor them.
|mapmarker Teldrassil/0 57.40,56.40
|mapmarker Teldrassil/0 60.40,54.00
|mapmarker Teldrassil/0 62.80,63.60
|mapmarker Teldrassil/0 63.00,56.60
|mapmarker Teldrassil/0 63.20,60.60
|mapmarker Teldrassil/0 66.80,65.20
|mapmarker Teldrassil/0 67.00,61.60
step
Kill enemies
|tip Helps reach level 8 after quest turnins.
ding 7,3100 |goto Teldrassil 59.40,59.20 |only if not Priest
ding 7,3170 |goto Teldrassil 59.40,59.20 |only if Priest
|mapmarker Teldrassil/0 57.40,56.40
|mapmarker Teldrassil/0 60.40,54.00
|mapmarker Teldrassil/0 62.80,63.60
|mapmarker Teldrassil/0 63.00,56.60
|mapmarker Teldrassil/0 63.20,60.60
|mapmarker Teldrassil/0 66.80,65.20
|mapmarker Teldrassil/0 67.00,61.60
step
talk Zenn Foulhoof##2150
|tip Walks around.
turnin Zenn's Bidding##488 |goto Teldrassil 60.45,56.15
step
talk Syral Bladeleaf##2083
accept Seek Redemption!##489 |goto Teldrassil 56.08,57.73
step
talk Athridas Bearmantle##2078
turnin Gnarlpine Corruption##476 |goto Teldrassil 55.95,57.28
step
talk Laurna Morninglight##3600
|tip {o}Ground floor{} inside the building.
turnin Garments of the Moon##5621 |goto Teldrassil 55.56,56.75
|only if Priest
step
talk Laurna Morninglight##3600
|tip {o}Ground floor{} inside the building.
Train Abilities |trainer Laurna Morninglight##3600 |goto Teldrassil 55.56,56.75 |q 2438
|only if Priest
step
talk Tallonkai Swiftroot##3567
|tip Top of the tower.
turnin The Emerald Dreamcatcher##2438 |goto Teldrassil 55.57,56.95
accept Ferocitas the Dream Eater##2459 |goto Teldrassil 55.57,56.95
step
talk Kyra Windblade##3598
|tip Inside the building.
Train Abilities |trainer Kyra Windblade##3598 |goto Teldrassil/0 56.22,59.20 |q 929
|only if Warrior
step
talk Jannok Breezesong##3599
|tip Inside the building.
Train Abilities |trainer Jannok Breezesong##3599 |goto Teldrassil/0 56.38,60.14 |q 929
|only if Rogue
step
talk Dazalar##3601
Train Abilities |trainer Dazalar##3601 |goto Teldrassil/0 56.68,59.49 |q 929
|only if Hunter
step
talk Kal##3602
Train Abilities |trainer Kal##3602 |goto Teldrassil/0 55.95,61.56 |q 929
|only if Druid
step
talk Corithras Moonrage##3515
turnin Crown of the Earth##929 |goto Teldrassil 56.14,61.71
accept Crown of the Earth##933 |goto Teldrassil 56.14,61.71
step
talk Zarrin##6286
Learn Cooking |skillmax Cooking,75 |goto Teldrassil 57.12,61.30 |q 4161 |future
|tip Needed to accept a quest.
step
talk Zarrin##6286
accept Recipe of the Kaldorei##4161 |goto Teldrassil 57.12,61.30
step
talk Zarrin##6286
turnin Recipe of the Kaldorei##4161 |goto Teldrassil 57.12,61.30
stickystart "Collect_Fel_Cones"
stickystart "Kill_Gnarlpine_Mystics"
step
kill Ferocitas the Dream Eater##7234
collect Gnarlpine Necklace##8049 |q 2459 |goto Teldrassil 69.37,53.40
step
use Gnarlpine Necklace##8049
collect Tallonkai's Jewel##8050 |q 2459/2
step
label "Kill_Gnarlpine_Mystics"
kill 7 Gnarlpine Mystic##7235 |q 2459/1 |goto Teldrassil 68.40,53.60
|mapmarker Teldrassil/0 68.00,51.40
|mapmarker Teldrassil/0 70.40,52.40
step
label "Collect_Fel_Cones"
click Fel Cone+
|tip Small brown pine cones with green smoke.
|tip Usually near trees.
collect 3 Fel Cone##3418 |q 489/1 |goto Teldrassil/0 66.70,53.40
|mapmarker Teldrassil/0 58.10,55.40
|mapmarker Teldrassil/0 59.10,62.20
|mapmarker Teldrassil/0 61.60,53.40
|mapmarker Teldrassil/0 62.00,63.90
|mapmarker Teldrassil/0 63.60,62.30
|mapmarker Teldrassil/0 64.30,53.90
|mapmarker Teldrassil/0 64.80,50.90
|mapmarker Teldrassil/0 65.10,65.10
|mapmarker Teldrassil/0 66.20,60.90
|mapmarker Teldrassil/0 68.60,57.90
|mapmarker Teldrassil/0 68.80,55.70
|mapmarker Teldrassil/0 69.00,59.70
step
talk Zenn Foulhoof##2150
|tip Walks around.
turnin Seek Redemption!##489 |goto Teldrassil/0 60.45,56.15
step
Enter the cave |goto Teldrassil/0 54.65,52.45 < 20 |walk |only if not subzone("Fel Rock")
kill Lord Melenas##2038
|tip Satyr.
|tip Multiple locations.
|tip Inside the cave.
collect Melenas' Head##5221 |q 932/1 |goto Teldrassil/0 51.22,50.81
|mapmarker Teldrassil/0 51.40,49.40
|mapmarker Teldrassil/0 51.60,51.60
|mapmarker Teldrassil/0 52.60,49.40
step
Kill enemies
|tip Helps reach level 9 after quest turnins.
|tip Inside the cave.
ding 8,3890 |goto Teldrassil/0 54.65,52.45
|mapmarker Teldrassil/0 53.00,50.40
|mapmarker Teldrassil/0 53.40,48.40
step
Leave the cave |goto Teldrassil/0 54.65,52.45 < 20 |walk |only if subzone("Fel Rock")
talk Tallonkai Swiftroot##3567
|tip Top of the tower.
turnin Twisted Hatred##932 |goto Teldrassil 55.57,56.95
turnin Ferocitas the Dream Eater##2459 |goto Teldrassil 55.57,56.95
step
click Strange Fruited Plant
accept The Glowing Fruit##930 |goto Teldrassil 42.63,76.10
step
use Tourmaline Phial##5621
collect Filled Tourmaline Phial##5645 |q 933/1 |goto Teldrassil 42.42,67.07
step
Allow Enemies to Kill You
|tip Here, or {o}east of here{}.
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Teldrassil 46.87,71.67 |q 933
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Teldrassil 56.20,63.26 |q 933 |zombiewalk
step
talk Corithras Moonrage##3515
turnin Crown of the Earth##933 |goto Teldrassil 56.14,61.71
accept Crown of the Earth##7383 |goto Teldrassil 56.14,61.71
step
talk Innkeeper Keldamyr##6736
|tip Upstairs inside the building.
home Dolanaar |goto Teldrassil 55.62,59.79 |q 4761 |future
step
map Teldrassil
path follow strictbounce;	loop off;	ants straight;		dist 40;	markers none
path	55.81,58.31	55.50,58.45	54.54,58.48	53.98,58.19	53.59,57.61
path	53.00,57.34	52.68,56.74	52.34,56.44	51.91,56.39	51.60,56.47
path	51.30,56.67	51.00,56.58	50.55,56.09	50.43,55.56	50.50,54.54
path	50.44,54.20	50.20,53.86
talk Moon Priestess Amara##2151
|tip Walks along the road.
accept The Road to Darnassus##487
step
kill 6 Gnarlpine Ambusher##2152 |q 487/1 |goto Teldrassil 48.60,53.40
|mapmarker Teldrassil/0 44.40,54.40
|mapmarker Teldrassil/0 45.00,52.40
|mapmarker Teldrassil/0 46.80,54.40
|mapmarker Teldrassil/0 48.40,55.60
step
talk Sentinel Arynia Cloudsbreak##3519
accept The Enchanted Glade##937 |goto Teldrassil 38.31,34.36
step
use Amethyst Phial##18152
collect Filled Amethyst Phial##18151 |q 7383/1 |goto Teldrassil 38.43,34.04
stickystart "Collect_Bloodfeather_Belts"
step
click Strange Fronded Plant
accept The Shimmering Frond##931 |goto Teldrassil 34.60,28.85
step
talk Mist##3568
|tip Escort quest.
|tip Wait until she respawns, if missing.
accept Mist##938 |goto Teldrassil 31.54,31.61 |noautoaccept inparty
step
Lead Mist Safely to Sentinel Arynia Cloudsbreak |q 938/1 |goto Teldrassil 38.31,34.36
|tip {o}Hurry{}, timed quest.
step
Watch the dialogue
talk Sentinel Arynia Cloudsbreak##3519
turnin Mist##938 |goto Teldrassil 38.31,34.36
step
label "Collect_Bloodfeather_Belts"
kill Bloodfeather Rogue##2017, Bloodfeather Sorceress##2018, Bloodfeather Harpy##2015, Bloodfeather Fury##2019, Bloodfeather Matriarch##2021, Bloodfeather Wind Witch##2020
|tip Harpies.
collect 6 Bloodfeather Belt##5204 |q 937/1 |goto Teldrassil 35.40,36.40
|mapmarker Teldrassil/0 33.40,35.60
|mapmarker Teldrassil/0 34.20,33.40
|mapmarker Teldrassil/0 35.20,38.80
|mapmarker Teldrassil/0 36.40,41.60
|mapmarker Teldrassil/0 37.20,43.60
|mapmarker Teldrassil/0 37.60,37.80
|mapmarker Teldrassil/0 38.20,40.40
step
Watch the dialogue
talk Sentinel Arynia Cloudsbreak##3519
turnin The Enchanted Glade##937 |goto Teldrassil 38.31,34.36
accept Teldrassil##940 |goto Teldrassil 38.31,34.36
step
Kill enemies
ding 10 |goto Teldrassil 35.40,36.40
|mapmarker Teldrassil/0 33.40,35.60
|mapmarker Teldrassil/0 34.20,33.40
|mapmarker Teldrassil/0 35.20,38.80
|mapmarker Teldrassil/0 36.40,41.60
|mapmarker Teldrassil/0 37.20,43.60
|mapmarker Teldrassil/0 37.60,37.80
|mapmarker Teldrassil/0 38.20,40.40
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Teldrassil 35.40,36.40 |q 940
|mapmarker Teldrassil/0 33.40,35.60
|mapmarker Teldrassil/0 34.20,33.40
|mapmarker Teldrassil/0 35.20,38.80
|mapmarker Teldrassil/0 36.40,41.60
|mapmarker Teldrassil/0 37.20,43.60
|mapmarker Teldrassil/0 37.60,37.80
|mapmarker Teldrassil/0 38.20,40.40
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Darnassus/0 76.98,27.17 |q 940 |zombiewalk
step
_NOTE:_
Stronger Ammo Available
|tip Buy level 10 ammo when restocking.
Click Here to Continue |confirm |q 922
|only if Hunter
step
talk Sildanair##4089
Train Abilities |trainer Sildanair##4089 |goto Darnassus/0 61.78,42.21 |q 922
|only if Warrior
step
talk Rellian Greenspyre##3517
turnin Rellian Greenspyre##922 |goto Darnassus 38.19,21.63
accept Tumors##923 |goto Darnassus 38.19,21.63
step
Enter the tree cave |goto Darnassus/0 32.14,16.46 < 7 |walk
talk Syurna##4163
|tip Downstairs inside the tree cave.
Train Abilities |trainer Syurna##4163 |goto Darnassus/0 37.00,21.92 |q 940
|tip Make sure to learn {o}Pick Pocket{}.
|tip Needed for a quest soon.
|only if Rogue
step
Run up the ramp |goto Darnassus/0 39.67,16.36 < 10 |only if walking
talk Jocaste##4146
|tip Upstairs inside the building.
accept The Hunter's Path##6071 |goto Darnassus/0 40.38,8.54
|only if Hunter
step
talk Jocaste##4146
|tip Upstairs inside the building.
Train Abilities |trainer Jocaste##4146 |goto Darnassus/0 40.38,8.54 |q 942
|only if Hunter
step
talk Denatharion##4218
|tip {o}Ground floor{} inside the building.
Train Abilities |trainer Denatharion##4218 |goto Darnassus/0 34.77,7.37 |q 940
|only if Druid
step
talk Mathrengyl Bearwalker##4217
|tip {o}Middle floor{} inside the building.
accept Moonglade##5921 |goto Darnassus 35.37,8.40
|only if NightElf Druid
step
talk Arch Druid Fandral Staghelm##3516
|tip Walks around.
|tip Top of the tower.
turnin Teldrassil##940 |goto Darnassus 34.80,9.24
accept Grove of the Ancients##952 |goto Darnassus 34.80,9.24
step
talk Jandria##4091
|tip Inside the building.
Train Abilities |trainer Jandria##4091 |goto Darnassus/0 37.90,82.73 |q 942
|only if Priest
step
talk Priestess A'moora##7313
|tip Upstairs inside the building.
accept Tears of the Moon##2518 |goto Darnassus 36.64,85.93
step
talk Dendrite Starblaze##11802
|tip Upstairs inside the building.
turnin Moonglade##5921 |goto Moonglade 56.21,30.64
accept Great Bear Spirit##5929 |goto Moonglade 56.21,30.64
|only if NightElf Druid
step
talk Great Bear Spirit##11956
Select _"What do you represent, spirit?"_
Seek Out the Great Bear Spirit and Learn what it Has to Share with You About the Nature of the Bear |q 5929/1 |goto Moonglade 39.11,27.51
|only if NightElf Druid
step
talk Dendrite Starblaze##11802
|tip Upstairs inside the building.
turnin Great Bear Spirit##5929 |goto Moonglade 56.21,30.64
accept Back to Darnassus##5931 |goto Moonglade 56.21,30.64
|only if NightElf Druid
step
talk Kyra Windblade##3598
|tip Inside the building.
accept Elanaria##1684 |goto Teldrassil 56.22,59.20
|only if Warrior
step
talk Dazalar##3601
accept Taming the Beast##6063 |goto Teldrassil 56.68,59.49
|only if NightElf Hunter
step
use Taming Rod##15921
|tip On a Webwood Lurker.
|tip Green spiders.
Tame a Webwood Lurker |q 6063/1 |goto Teldrassil 59.40,59.20
|mapmarker Teldrassil/0 57.40,56.40
|mapmarker Teldrassil/0 60.40,54.00
|mapmarker Teldrassil/0 62.80,63.60
|mapmarker Teldrassil/0 63.00,56.60
|mapmarker Teldrassil/0 63.20,60.60
|only if NightElf Hunter
step
talk Dazalar##3601
turnin Taming the Beast##6063 |goto Teldrassil 56.68,59.49
accept Taming the Beast##6101 |goto Teldrassil 56.68,59.49
|only if NightElf Hunter
step
talk Corithras Moonrage##3515
turnin Crown of the Earth##7383 |goto Teldrassil 56.14,61.71
accept Crown of the Earth##935 |goto Teldrassil 56.14,61.71
step
talk Denalan##2080
|tip Walks around.
turnin The Shimmering Frond##931 |goto Teldrassil 60.90,68.49
turnin The Glowing Fruit##930 |goto Teldrassil 60.90,68.49
step
use Taming Rod##15922
|tip On a Nightsaber Stalker.
|tip Blue leopards.
Tame a Nightsaber Stalker |q 6101/1 |goto Teldrassil/0 61.80,73.00
|mapmarker Teldrassil/0 53.40,71.60
|mapmarker Teldrassil/0 55.60,72.40
|mapmarker Teldrassil/0 56.40,59.80
|mapmarker Teldrassil/0 63.80,70.60
|only if NightElf Hunter
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Teldrassil/0 61.80,73.00|q 6101
|mapmarker Teldrassil/0 53.40,71.60
|mapmarker Teldrassil/0 55.60,72.40
|mapmarker Teldrassil/0 56.40,59.80
|mapmarker Teldrassil/0 63.80,70.60
|only if NightElf Hunter
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Teldrassil/0 56.20,63.26 |q 6101 |zombiewalk
|only if NightElf Hunter
step
talk Dazalar##3601
turnin Taming the Beast##6101 |goto Teldrassil/0 56.68,59.49
accept Taming the Beast##6102 |goto Teldrassil/0 56.68,59.49
|only if NightElf Hunter
step
use Taming Rod##15923
|tip On a Strigid Screecher.
|tip Owls.
Tame a Strigid Screecher |q 6102/1 |goto Teldrassil/0 64.00,66.20
|mapmarker Teldrassil/0 63.80,68.60
|only if NightElf Hunter
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Teldrassil/0 64.00,66.20 |q 6102
|mapmarker Teldrassil/0 63.80,68.60
|only if NightElf Hunter
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Teldrassil/0 56.20,63.26 |q 6102 |zombiewalk
|only if NightElf Hunter
step
talk Dazalar##3601
turnin Taming the Beast##6102 |goto Teldrassil/0 56.68,59.49
accept Training the Beast##6103 |goto Teldrassil/0 56.68,59.49
|only if NightElf Hunter
step
talk Laurna Morninglight##3600
|tip Inside the building.
accept Returning Home##5629 |goto Teldrassil 55.57,56.75
|only if NightElf Priest
step
talk Jannok Breezesong##3599
|tip Inside the building.
accept The Apple Falls##2241 |goto Teldrassil 56.38,60.14
|only if NightElf Rogue
step
map Teldrassil
path follow strictbounce;	loop off;	ants straight;		dist 40;	markers none
path	55.81,58.31	55.50,58.45	54.54,58.48	53.98,58.19	53.59,57.61
path	53.00,57.34	52.68,56.74	52.34,56.44	51.91,56.39	51.60,56.47
path	51.30,56.67	51.00,56.58	50.55,56.09	50.43,55.56	50.50,54.54
path	50.44,54.20	50.20,53.86
talk Moon Priestess Amara##2151
|tip Walks along the road.
turnin The Road to Darnassus##487
step
Allow Enemies to Kill You
|tip Must be near here.
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Teldrassil/0 42.77,52.55 |q 2241
|only if NightElf Rogue
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Darnassus 77.67,25.92 |q 2241 |zombiewalk
|only if NightElf Rogue
step
Enter the cave in the tree trunk |goto Darnassus 32.12,16.46 < 7 |walk
talk Syurna##4163
|tip Inside the cave.
turnin The Apple Falls##2241 |goto Darnassus 36.99,21.91
accept Destiny Calls##2242 |goto Darnassus 36.99,21.91
|only if NightElf Rogue
step
_NOTE:_
Tame a Strigid Hunter
|tip Cast {o}Tame Beast{} on a {o}Strigid Hunter{}.
|tip Owls.
Click Here to Continue |confirm |goto Teldrassil/0 38.40,50.00 |q 6103
|mapmarker Teldrassil/0 37.20,29.20
|mapmarker Teldrassil/0 37.40,37.40
|mapmarker Teldrassil/0 38.20,32.60
|mapmarker Teldrassil/0 38.40,46.60
|mapmarker Teldrassil/0 40.80,30.20
|mapmarker Teldrassil/0 40.80,44.80
|mapmarker Teldrassil/0 41.80,37.60
|mapmarker Teldrassil/0 44.20,40.00
|mapmarker Teldrassil/0 45.80,30.40
|only if NightElf Hunter
step
kill Lady Sathrah##7319
|tip Large grey spider.
|tip Walks around.
|tip Multiple locations.
collect Silvery Spinnerets##8344 |q 2518/1 |goto Teldrassil 48.00,25.20
|mapmarker Teldrassil/0 39.20,25.40
|mapmarker Teldrassil/0 41.00,25.60
|mapmarker Teldrassil/0 46.20,24.40
step
collect Sethir's Journal##7737 |q 2242/1 |goto Teldrassil 37.52,24.29
|tip Cast {o}Pickpocket{} on {o}Sethir the Ancient{}.
|tip Purple satyr.
|tip Stands here and walks onto the {o}huge tree branch{} nearby.
|tip {o}Don't attack{}, he summons a group of enemies.
|mapmarker Teldrassil/0 37.20,23.00
|mapmarker Teldrassil/0 37.40,21.20
|only if NightElf Rogue
step
label "Collect_Mossy_Tumors"
kill Timberling Trampler##2027, Timberling Mire Beast##2029, Elder Timberling##2030
|tip Swamp elementals.
collect 5 Mossy Tumor##5170 |q 923/1 |goto Teldrassil 42.00,43.60
|mapmarker Teldrassil/0 41.40,41.40
|mapmarker Teldrassil/0 42.00,37.40
|mapmarker Teldrassil/0 43.40,40.20
|mapmarker Teldrassil/0 44.00,43.60
|mapmarker Teldrassil/0 52.40,73.80
|mapmarker Teldrassil/0 41.40,33.40
|mapmarker Teldrassil/0 42.80,29.20
|mapmarker Teldrassil/0 43.20,31.80
|mapmarker Teldrassil/0 43.20,35.80
|mapmarker Teldrassil/0 42.20,25.40
|mapmarker Teldrassil/0 44.20,26.60
step
label "Collect_Earthroot_Druid"
collect 5 Earthroot##2449 |goto Teldrassil/0 44.70,39.30 |q 6123 |future
|tip {o}Track Herbs{} with Herbalism.
|tip Gather as you quest in Teldrassil.
|tip Reach {o}level 15{} Herbalism.
|tip Needed to gather Earthroot.
|tip You can abandon Herbalism once finished.
|tip Don't vendor them.
|mapmarker Teldrassil/0 34.80,35.80
|mapmarker Teldrassil/0 35.10,39.80
|mapmarker Teldrassil/0 36.30,42.40
|mapmarker Teldrassil/0 37.60,27.30
|mapmarker Teldrassil/0 38.60,39.40
|mapmarker Teldrassil/0 39.60,29.60
|mapmarker Teldrassil/0 40.10,26.40
|mapmarker Teldrassil/0 40.10,48.00
|mapmarker Teldrassil/0 40.50,41.80
|mapmarker Teldrassil/0 41.30,35.40
|mapmarker Teldrassil/0 41.40,30.60
|mapmarker Teldrassil/0 44.30,36.00
|mapmarker Teldrassil/0 44.30,48.70
|mapmarker Teldrassil/0 44.40,31.40
|mapmarker Teldrassil/0 44.90,46.70
|mapmarker Teldrassil/0 45.20,25.90
|mapmarker Teldrassil/0 46.30,37.30
|mapmarker Teldrassil/0 46.60,31.20
|mapmarker Teldrassil/0 47.00,41.50
|mapmarker Teldrassil/0 47.70,33.40
|mapmarker Teldrassil/0 48.00,45.10
|mapmarker Teldrassil/0 48.50,27.90
|only if Druid
step
Kill enemies
|tip Helps to reach level 11 after quest turnins.
ding 10,3500 |goto Teldrassil 42.80,29.20
|mapmarker Teldrassil/0 41.40,41.40
|mapmarker Teldrassil/0 42.00,37.40
|mapmarker Teldrassil/0 43.40,40.20
|mapmarker Teldrassil/0 44.00,43.60
|mapmarker Teldrassil/0 52.40,73.80
|mapmarker Teldrassil/0 41.40,33.40
|mapmarker Teldrassil/0 42.00,43.60
|mapmarker Teldrassil/0 43.20,31.80
|mapmarker Teldrassil/0 43.20,35.80
|mapmarker Teldrassil/0 42.20,25.40
|mapmarker Teldrassil/0 44.20,26.60
step
Allow Enemies to Kill You
|tip Must be near here.
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Teldrassil 35.40,36.40 |q 2518
|mapmarker Teldrassil/0 33.40,35.60
|mapmarker Teldrassil/0 34.20,33.40
|mapmarker Teldrassil/0 35.20,38.80
|mapmarker Teldrassil/0 36.40,41.60
|mapmarker Teldrassil/0 37.20,43.60
|mapmarker Teldrassil/0 37.60,37.80
|mapmarker Teldrassil/0 38.20,40.40
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Darnassus 77.67,25.92 |q 2518 |zombiewalk
step
talk Mydrannul##4241
accept Nessa Shadowsong##6344 |goto Darnassus 70.68,45.38
|only if NightElf
step
talk Elanaria##4088
turnin Elanaria##1684 |goto Darnassus 57.30,34.61
accept Vorlus Vilehoof##1683 |goto Darnassus 57.30,34.61
|only if Warrior
step
Run around the mountain and follow the path up |goto Teldrassil 48.68,62.73 < 15 |only if walking
kill Vorlus Vilehoof##6128
collect Horn of Vorlus##6805 |q 1683/1 |goto Teldrassil 47.25,63.60
|only if Warrior
step
Allow Enemies to Kill You
|tip Must be near here.
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Teldrassil/0 42.77,52.55 |q 1683
|only if Warrior
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Darnassus 77.67,25.92 |q 1683 |zombiewalk
|only if Warrior
step
talk Elanaria##4088
turnin Vorlus Vilehoof##1683 |goto Darnassus 57.30,34.61
|only if Warrior
step
talk Ilyenia Moonfire##11866
Train Staves |complete weaponskill("TH_STAFF") > 0 |goto Darnassus 57.56,46.73
|only if Warrior or Hunter or Priest
step
talk Auctioneer Golothas##8723
|tip Buy from the Auction House, if possible.
|tip Allows easy quest turnin in Darkshore soon.
|tip Inside the building.
collect 6 Darkshore Grouper##12238 |goto Darnassus/0 56.24,54.04 |q 1141 |future
step
talk Rellian Greenspyre##3517
turnin Tumors##923 |goto Darnassus 38.19,21.64
step
Enter the cave in the tree trunk |goto Darnassus 32.12,16.46 < 7 |walk
talk Syurna##4163
|tip Inside the cave.
turnin Destiny Calls##2242 |goto Darnassus 36.99,21.91
|only if Rogue
step
talk Jocaste##4146
|tip Inside the building.
turnin Training the Beast##6103 |goto Darnassus 40.38,8.55
|only if NightElf Hunter
step
_NOTE:_
Train Your Pet
|tip Learn pet abilities from Pet Trainers.
|tip Cast {o}Beast Training{} to teach your pet.
Click Here to Continue |confirm |q 6344
|only if NightElf Hunter
step
talk Silvaria##10089
|tip Top of the building.
Train Pet Abilities |trainer Silvaria##10089 |goto Darnassus/0 42.47,9.17 |q 935
|only if Hunter
step
talk Mathrengyl Bearwalker##4217
|tip {o}Middle floor{} inside the building.
turnin Back to Darnassus##5931 |goto Darnassus 35.38,8.41
accept Body and Heart##6001 |goto Darnassus 35.38,8.41
|only if NightElf Druid
step
talk Arch Druid Fandral Staghelm##3516
|tip Walks around.
|tip Top of the tower.
turnin Crown of the Earth##935 |goto Darnassus 34.80,9.24
step
talk Priestess A'moora##7313
|tip Upstairs inside the building.
turnin Tears of the Moon##2518 |goto Darnassus 36.64,85.93
accept Sathrah's Sacrifice##2520 |goto Darnassus 36.64,85.93
step
talk Priestess Alathea##11401
|tip Upstairs inside the building.
turnin Returning Home##5629 |goto Darnassus 39.53,81.18
accept Stars of Elune##5627 |goto Darnassus 39.53,81.18 |instant
|only if NightElf Priest
step
use Sathrah's Sacrifice##8155
|tip Inside the building.
Offer the Sacrifice at the Fountain |q 2520/1 |goto Darnassus 39.21,84.57
step
talk Priestess A'moora##7313
|tip Upstairs inside the building.
turnin Sathrah's Sacrifice##2520 |goto Darnassus 36.64,85.93
step
talk Nessa Shadowsong##10118
turnin Nessa Shadowsong##6344 |goto Teldrassil 56.25,92.43
accept The Bounty of Teldrassil##6341 |goto Teldrassil 56.25,92.43
|only if NightElf
step
talk Vesprystus##3838
turnin The Bounty of Teldrassil##6341 |goto Teldrassil 58.40,94.01
accept Flight to Auberdine##6342 |goto Teldrassil 58.40,94.01
|only if NightElf
step
talk Laird##4200
|tip Inside the building.
turnin Flight to Auberdine##6342 |goto Darkshore 36.77,44.29
|only if NightElf
step
talk Laird##4200
buy Longjaw Mud Snapper##4592 |n
|tip Buy {o}20{}, if possible.
|tip Needed to feed your pet soon.
Visit the Vendor |vendor Grimtak##3881 |goto Darkshore 51.13,42.63 |q 433 |future
|only if Hunter
]])
ZygorGuidesViewer:RegisterGuide("Leveling Guides\\Starter Guides (1-11)\\Draenei Starter (1-11)",{
image=ZGV.IMAGESDIR.."Azuremyst Isle",
condition_suggested=function() return raceclass('Draenei') and level <= 11 end,
condition_suggested_exclusive=true,
condition_visible=function() return Draenei end,
linked = {"Leveling Guides\\Hidden Guides"},
linkedhidden = true,
next="Leveling Guides\\Classic (11-60)\\Darkshore (11-14)",
},[[
defaultfor Draenei
step
_NOTE:_
Wrong Character Race
|tip Guide written for {o}Draenei{} characters.
|tip Other races may encounter issues.
Click Here to Continue |confirm
|only if not Draenei
step
_Destroy This Item:_
|tip Saves bag space.
|tip You'll get one later.
trash Hearthstone##6948
step
_NOTE:_
Manage Your Ammo
|tip Make sure you always have ammo.
|tip You need it to attack enemies.
|tip {o}General Goods{} vendors sell it (also Bow & Gun vendors).
|tip Try to keep your ammo bag full.
Click Here to Continue |confirm |q 10302 |future
|only if Hunter
step
talk Megelon##16475
accept You Survived!##9279 |goto Azuremyst Isle/0 82.96,43.88
|only if Draenei
step
kill Vale Moth##16520, Volatile Mutation##16516
|tip Loot items worth at least {o}10 copper{} to sell.
|tip Allows training a spell early.
Click to continue |confirm |goto Azuremyst Isle/0 81.60,41.80 |q 179 |future
|mapmarker Azuremyst Isle/0 77.40,41.40
|mapmarker Azuremyst Isle/0 78.20,44.20
|mapmarker Azuremyst Isle/0 78.80,46.60
|mapmarker Azuremyst Isle/0 79.40,40.40
|mapmarker Azuremyst Isle/0 79.60,42.40
|only if Warrior or Shaman
step
talk Proenitus##16477
turnin You Survived!##9279 |goto Azuremyst Isle/0 80.42,45.89				|only if Draenei
accept Replenishing the Healing Crystals##9280 |goto Azuremyst Isle/0 80.42,45.89	|only if Draenei
accept Replenishing the Healing Crystals##9369 |goto Azuremyst Isle/0 80.42,45.89	|only if not Draenei
step
talk Jel##16918
|tip Inside the building.
Sell Items |vendor Jel##16918 |goto Azuremyst Isle/0 80.47,47.35 |q 10302 |future
|only if Warrior or Shaman
step
talk Kore##16503
|tip Inside the building.
Train Abilities |trainer Kore##16503 |goto Azuremyst Isle/0 79.59,49.45 |q 10302 |future
|only if Warrior
step
talk Firmanvaar##17089
|tip Inside the building.
Train Abilities |trainer Firmanvaar##17089 |goto Azuremyst Isle/0 79.28,49.12 |q 10302 |future
|only if Shaman
step
talk Botanist Taerix##16514
accept Volatile Mutations##10302 |goto Azuremyst Isle/0 79.14,46.54
stickystart "Collect_Vials_Of_Moth_Blood"
step
kill 8 Volatile Mutation##16516 |q 10302/1 |goto Azuremyst Isle/0 81.60,41.80
|mapmarker Azuremyst Isle/0 77.40,41.40
|mapmarker Azuremyst Isle/0 78.20,44.20
|mapmarker Azuremyst Isle/0 78.80,46.60
|mapmarker Azuremyst Isle/0 79.40,40.40
|mapmarker Azuremyst Isle/0 79.60,42.40
step
talk Botanist Taerix##16514
turnin Volatile Mutations##10302 |goto Azuremyst Isle/0 79.14,46.54
accept What Must Be Done...##9293 |goto Azuremyst Isle/0 79.14,46.54
step
talk Apprentice Vishael##20233
accept Botanical Legwork##9799 |goto Azuremyst Isle/0 79.07,46.63
stickystart "Collect_Lasher_Samples"
step
click Corrupted Flower##182127+
|tip Red flowers.
collect 3 Corrupted Flower##24416 |q 9799/1 |goto Azuremyst Isle/0 73.80,46.90
|mapmarker Azuremyst Isle/0 71.70,48.40
|mapmarker Azuremyst Isle/0 72.30,52.00
|mapmarker Azuremyst Isle/0 73.50,50.00
|mapmarker Azuremyst Isle/0 74.40,52.80
step
label "Collect_Lasher_Samples"
kill Mutated Root Lasher##16517+
|tip Walking flowers.
collect 10 Lasher Sample##22934 |q 9293/1 |goto Azuremyst Isle/0 73.40,51.40
|mapmarker Azuremyst Isle/0 70.40,52.80
|mapmarker Azuremyst Isle/0 71.40,48.40
|mapmarker Azuremyst Isle/0 72.40,45.20
|mapmarker Azuremyst Isle/0 72.40,55.60
|mapmarker Azuremyst Isle/0 74.60,47.60
|mapmarker Azuremyst Isle/0 75.60,53.60
step
label "Collect_Vials_Of_Moth_Blood"
kill Vale Moth##16520+
collect 8 Vial of Moth Blood##22889 |q 9280/1 |goto Azuremyst Isle/0 76.20,43.60	|only if Draenei
collect 8 Vial of Moth Blood##22889 |q 9369/1 |goto Azuremyst Isle/0 76.20,43.60	|only if not Draenei
|mapmarker Azuremyst Isle/0 72.60,50.40
|mapmarker Azuremyst Isle/0 73.20,42.40
|mapmarker Azuremyst Isle/0 73.80,46.20
|mapmarker Azuremyst Isle/0 75.40,53.40
|mapmarker Azuremyst Isle/0 75.80,48.80
|mapmarker Azuremyst Isle/0 76.20,40.40
|mapmarker Azuremyst Isle/0 79.00,41.60
|mapmarker Azuremyst Isle/0 78.60,45.60
|mapmarker Azuremyst Isle/0 81.60,43.60
|mapmarker Azuremyst Isle/0 81.80,40.40
step
Kill enemies
|tip Helps reach level 4 after quest turnins.
ding 3,850 |goto Azuremyst Isle/0 76.20,43.60
|mapmarker Azuremyst Isle/0 72.60,50.40
|mapmarker Azuremyst Isle/0 73.20,42.40
|mapmarker Azuremyst Isle/0 73.80,46.20
|mapmarker Azuremyst Isle/0 75.40,53.40
|mapmarker Azuremyst Isle/0 75.80,48.80
|mapmarker Azuremyst Isle/0 76.20,40.40
|mapmarker Azuremyst Isle/0 79.00,41.60
|mapmarker Azuremyst Isle/0 78.60,45.60
|mapmarker Azuremyst Isle/0 81.60,43.60
|mapmarker Azuremyst Isle/0 81.80,40.40
step
talk Apprentice Vishael##20233
turnin Botanical Legwork##9799 |goto Azuremyst Isle/0 79.07,46.63
step
talk Botanist Taerix##16514
turnin What Must Be Done...##9293 |goto Azuremyst Isle/0 79.14,46.54
accept Healing the Lake##9294 |goto Azuremyst Isle/0 79.14,46.54
step
talk Proenitus##16477
turnin Replenishing the Healing Crystals##9280 |goto Azuremyst Isle/0 80.42,45.89	|only if Draenei
turnin Replenishing the Healing Crystals##9369 |goto Azuremyst Isle/0 80.42,45.89	|only if not Draenei
accept Urgent Delivery!##9409 |goto Azuremyst Isle/0 80.42,45.89
step
talk Zalduun##16502
|tip Walks around.
|tip Inside the building.
turnin Urgent Delivery!##9409 |goto Azuremyst Isle/0 79.96,48.66
accept Rescue the Survivors!##9283 |goto Azuremyst Isle/0 79.96,48.66			|only if Draenei
step
talk Zalduun##16502
|tip Walks around.
|tip Inside the building.
accept Priest Training##9291 |goto Azuremyst Isle/0 79.96,48.66 |instant
|only if Draenei Priest
step
talk Zalduun##16502
|tip Walks around.
|tip Inside the building.
Train Abilities |trainer Zalduun##16502 |goto Azuremyst Isle/0 79.96,48.66 |q 9305 |future
|only if Priest
step
talk Keilnei##16499
|tip Inside the building.
accept Hunter Training##9288 |goto Azuremyst Isle 79.88,49.71 |instant
|only if Draenei Hunter
step
talk Keilnei##16499
|tip Inside the building.
Train Abilities |trainer Keilnei##16499 |goto Azuremyst Isle 79.88,49.71 |q 9305 |future
|only if Hunter
step
talk Aurelon##16501
|tip Inside the building.
accept Paladin Training##9287 |goto Azuremyst Isle 79.69,48.24 |instant
|only if Draenei Paladin
step
talk Aurelon##16501
|tip Inside the building.
Train Abilities |trainer Aurelon##16501 |goto Azuremyst Isle 79.69,48.24 |q 9305 |future
|only if Paladin
step
talk Kore##16503
|tip Inside the building.
accept Warrior Training##9289 |goto Azuremyst Isle 79.59,49.45 |instant
|only if Draenei Warrior
step
talk Kore##16503
|tip Inside the building.
Train Abilities |trainer Kore##16503 |goto Azuremyst Isle 79.59,49.45 |q 9305 |future
|only if Warrior
step
talk Firmanvaar##17089
|tip Inside the building.
accept Shaman Training##9421 |goto Azuremyst Isle 79.28,49.12 |instant
accept Call of Earth##9449 |goto Azuremyst Isle 79.28,49.12
|only if Draenei Shaman
step
talk Firmanvaar##17089
|tip Inside the building.
Train Abilities |trainer Firmanvaar##17089 |goto Azuremyst Isle 79.28,49.12 |q 9305 |future
|only if Shaman
stickystart "Save_A_Draenei_Survivor_Shaman"
step
talk Spirit of the Vale##17087
turnin Call of Earth##9449 |goto Azuremyst Isle/0 71.31,39.10
accept Call of Earth##9450 |goto Azuremyst Isle/0 71.31,39.10
|only if Shaman
stickystop "Save_A_Draenei_Survivor_Shaman"
step
kill 4 Restless Spirit of Earth##17179 |q 9450/1 |goto Azuremyst Isle/0 70.40,37.60
|mapmarker Azuremyst Isle/0 69.40,35.40
|only if Shaman
step
talk Spirit of the Vale##17087
turnin Call of Earth##9450 |goto Azuremyst Isle/0 71.31,39.10
accept Call of Earth##9451 |goto Azuremyst Isle/0 71.31,39.10
|only if Shaman
step
label "Save_A_Draenei_Survivor_Shaman"
Save a Draenei Survivor |q 9283/1 |goto Azuremyst Isle 73.00,41.80
|tip Cast {o}Gift of the Naaru{} on a {o}Draenei Survivor{}.
|tip Red-glowing Draenei laying down.
|mapmarker Azuremyst Isle/0 77.00,44.40
|mapmarker Azuremyst Isle/0 74.40,40.20
|mapmarker Azuremyst Isle/0 74.40,43.40
|mapmarker Azuremyst Isle/0 76.40,42.40
|only if Draenei Shaman
step
talk Zalduun##16502
|tip Walks around.
|tip Inside the building.
turnin Rescue the Survivors!##9283 |goto Azuremyst Isle/0 79.96,48.66
|only if Draenei Shaman
step
talk Firmanvaar##17089
|tip Inside the building.
turnin Call of Earth##9451 |goto Azuremyst Isle 79.28,49.12
|only if Draenei Shaman
step
talk Valaatu##16500
|tip Inside the building.
accept Mage Training##9290 |goto Azuremyst Isle/0 79.58,48.76 |instant
|only if Draenei Mage
step
talk Valaatu##16500
|tip Inside the building.
Train Abilities |trainer Valaatu##16500 |goto Azuremyst Isle/0 79.58,48.76 |q 9305 |future
|only if Mage
step
talk Technician Zhanaa##17071
accept Spare Parts##9305 |goto Azuremyst Isle 79.42,51.23
step
talk Vindicator Aldar##16535
accept Inoculation##9303 |goto Azuremyst Isle 79.49,51.62
stickystart "Save_A_Draenei_Survivor"
step
click Irradiated Power Crystal
|tip Huge pink crystal.
Disperse the Neutralizing Agent |q 9294/1 |goto Azuremyst Isle 77.26,58.76
step
label "Save_A_Draenei_Survivor"
Save a Draenei Survivor |q 9283/1 |goto Azuremyst Isle 78.33,59.19
|tip Cast {o}Gift of the Naaru{} on a {o}Draenei Survivor{}.
|tip Red-glowing Draenei laying down.
|mapmarker Azuremyst Isle/0 76.40,60.40
|mapmarker Azuremyst Isle/0 77.40,55.80
|mapmarker Azuremyst Isle/0 80.40,56.40
|mapmarker Azuremyst Isle/0 82.40,54.00
|only if Draenei
stickystart "Inoculate_Nestlewood_Owlkins"
step
click Emitter Spare Part##181283+
|tip Pink crystal machines.
collect 4 Emitter Spare Part##22978 |q 9305/1 |goto Azuremyst Isle 81.80,57.70
|mapmarker Azuremyst Isle/0 81.10,60.10
|mapmarker Azuremyst Isle/0 82.60,61.70
|mapmarker Azuremyst Isle/0 84.00,65.20
|mapmarker Azuremyst Isle/0 85.20,69.00
|mapmarker Azuremyst Isle/0 86.30,66.40
|mapmarker Azuremyst Isle/0 87.10,63.40
|mapmarker Azuremyst Isle/0 88.90,62.20
|mapmarker Azuremyst Isle/0 85.1,060.60
|mapmarker Azuremyst Isle/0 85.30,57.60
step
label "Inoculate_Nestlewood_Owlkins"
use Inoculating Crystal##22962
|tip On Nestlewood Owlkins.
|tip Yellow owl people.
Inoculate #6# Nestlewood Owlkins |q 9303/1 |goto Azuremyst Isle 84.00,64.60
|mapmarker Azuremyst Isle/0 78.00,61.40
|mapmarker Azuremyst Isle/0 80.40,58.80
|mapmarker Azuremyst Isle/0 81.80,57.00
|mapmarker Azuremyst Isle/0 83.20,60.80
|mapmarker Azuremyst Isle/0 85.40,60.80
|mapmarker Azuremyst Isle/0 85.40,67.60
|mapmarker Azuremyst Isle/0 87.20,63.40
step
Kill enemies
|tip Helps reach level 5 after quest turnins.
ding 4,820 |goto Azuremyst Isle 84.00,64.60
|mapmarker Azuremyst Isle/0 78.00,61.40
|mapmarker Azuremyst Isle/0 80.40,58.80
|mapmarker Azuremyst Isle/0 81.80,57.00
|mapmarker Azuremyst Isle/0 83.20,60.80
|mapmarker Azuremyst Isle/0 85.40,60.80
|mapmarker Azuremyst Isle/0 85.40,67.60
|mapmarker Azuremyst Isle/0 87.20,63.40
step
Allow Enemies to Kill You
|tip Anywhere near owlkins.
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Azuremyst Isle 84.00,64.60 |q 9294
|mapmarker Azuremyst Isle/0 78.00,61.40
|mapmarker Azuremyst Isle/0 80.40,58.80
|mapmarker Azuremyst Isle/0 81.80,57.00
|mapmarker Azuremyst Isle/0 83.20,60.80
|mapmarker Azuremyst Isle/0 85.40,60.80
|mapmarker Azuremyst Isle/0 85.40,67.60
|mapmarker Azuremyst Isle/0 87.20,63.40
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Azuremyst Isle 77.71,48.83 |q 9294 |zombiewalk
step
talk Botanist Taerix##16514
turnin Healing the Lake##9294 |goto Azuremyst Isle 79.14,46.54
step
talk Zalduun##16502
|tip Walks around.
|tip Inside the building.
turnin Rescue the Survivors!##9283 |goto Azuremyst Isle 79.96,48.66
step
talk Technician Zhanaa##17071
turnin Spare Parts##9305 |goto Azuremyst Isle 79.42,51.23
step
talk Vindicator Aldar##16535
turnin Inoculation##9303 |goto Azuremyst Isle 79.49,51.62
accept The Missing Scout##9309 |goto Azuremyst Isle 79.49,51.62
step
talk Tolaan##16546
turnin The Missing Scout##9309 |goto Azuremyst Isle 72.00,60.85
accept The Blood Elves##10303 |goto Azuremyst Isle 72.00,60.85
step
kill 10 Blood Elf Scout##16521 |q 10303/1 |goto Azuremyst Isle 70.20,61.80
|mapmarker Azuremyst Isle/0 68.80,63.60
|mapmarker Azuremyst Isle/0 69.20,65.60
|mapmarker Azuremyst Isle/0 71.00,63.80
step
talk Tolaan##16546
turnin The Blood Elves##10303 |goto Azuremyst Isle 72.00,60.85
accept Blood Elf Spy##9311 |goto Azuremyst Isle 72.00,60.85
step
kill Surveyor Candress##16522 |q 9311/1 |goto Azuremyst Isle 69.27,65.78
|tip Up on the mountain.
collect Blood Elf Plans##24414 |goto Azuremyst Isle 69.27,65.78 |q 9798 |future
step
use Blood Elf Plans##24414
accept Blood Elf Plans##9798
step
Kill enemies
|tip Helps reach level 6 after quest turnins.
ding 5,1570 |goto Azuremyst Isle 70.20,61.80
|mapmarker Azuremyst Isle/0 68.80,63.60
|mapmarker Azuremyst Isle/0 69.20,65.60
|mapmarker Azuremyst Isle/0 71.00,63.80
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Azuremyst Isle 70.20,61.80 |q 9798
|mapmarker Azuremyst Isle/0 68.80,63.60
|mapmarker Azuremyst Isle/0 69.20,65.60
|mapmarker Azuremyst Isle/0 71.00,63.80
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Azuremyst Isle 77.71,48.83 |q 9798 |zombiewalk
step
talk Vindicator Aldar##16535
turnin Blood Elf Spy##9311 |goto Azuremyst Isle 79.49,51.62
turnin Blood Elf Plans##9798 |goto Azuremyst Isle 79.49,51.62
accept The Emitter##9312 |goto Azuremyst Isle 79.49,51.62
step
talk Technician Zhanaa##17071
turnin The Emitter##9312 |goto Azuremyst Isle 79.42,51.23
accept Travel to Azure Watch##9313 |goto Azuremyst Isle 79.42,51.23
step
talk Zalduun##16502
|tip Walks around.
|tip Inside the building.
Train Abilities |trainer Zalduun##16502 |goto Azuremyst Isle/0 79.96,48.66 |q 9313
|only if Priest
step
talk Keilnei##16499
|tip Inside the building.
Train Abilities |trainer Keilnei##16499 |goto Azuremyst Isle 79.88,49.71 |q 9313
|only if Hunter
step
talk Aurelon##16501
|tip Inside the building.
Train Abilities |trainer Aurelon##16501 |goto Azuremyst Isle 79.69,48.24 |q 9313
|only if Paladin
step
talk Kore##16503
|tip Inside the building.
Train Abilities |trainer Kore##16503 |goto Azuremyst Isle 79.59,49.45 |q 9313
|only if Warrior
step
talk Firmanvaar##17089
|tip Inside the building.
Train Abilities |trainer Firmanvaar##17089 |goto Azuremyst Isle 79.28,49.12 |q 9313
|only if Shaman
step
talk Valaatu##16500
|tip Inside the building.
Train Abilities |trainer Valaatu##16500 |goto Azuremyst Isle/0 79.58,48.76 |q 9313
|only if Mage
step
talk Aeun##16554
accept Word from Azure Watch##9314 |goto Azuremyst Isle 64.49,54.04
step
talk Diktynna##17101
accept Red Snapper - Very Tasty!##9452 |goto Azuremyst Isle 61.05,54.25
step
use Draenei Fishing Net##23654
|tip Next to Schools of Red Snapper.
|tip Groups of small red fish.
|tip In the water.
kill Angry Murloc##17102+
|tip May be attacked.
collect 10 Red Snapper##23614 |q 9452/1 |goto Azuremyst Isle 61.80,51.60
|mapmarker Azuremyst Isle/0 60.80,44.60
|mapmarker Azuremyst Isle/0 61.00,38.40
|mapmarker Azuremyst Isle/0 61.00,48.40
|mapmarker Azuremyst Isle/0 61.20,61.60
|mapmarker Azuremyst Isle/0 61.40,59.60
|mapmarker Azuremyst Isle/0 62.00,41.80
|mapmarker Azuremyst Isle/0 62.40,55.60
step
talk Diktynna##17101
turnin Red Snapper - Very Tasty!##9452 |goto Azuremyst Isle 61.05,54.25
accept Find Acteon!##9453 |goto Azuremyst Isle 61.05,54.25
step
kill Infected Nightstalker Runt##17202+
|tip Black tigers.
collect Faintly Glowing Crystal##23678 |goto Azuremyst Isle 59.80,43.60 |q 9455 |future
|mapmarker Azuremyst Isle/0 47.60,33.20
|mapmarker Azuremyst Isle/0 49.20,36.20
|mapmarker Azuremyst Isle/0 50.40,31.40
|mapmarker Azuremyst Isle/0 52.20,34.40
|mapmarker Azuremyst Isle/0 53.40,30.60
|mapmarker Azuremyst Isle/0 53.40,37.40
|mapmarker Azuremyst Isle/0 55.60,33.40
|mapmarker Azuremyst Isle/0 56.40,37.60
|mapmarker Azuremyst Isle/0 58.20,40.40
step
use Faintly Glowing Crystal##23678
accept Strange Findings##9455
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Azuremyst Isle 53.40,37.40 |q 9455
|mapmarker Azuremyst Isle/0 47.60,33.20
|mapmarker Azuremyst Isle/0 49.20,36.20
|mapmarker Azuremyst Isle/0 50.40,31.40
|mapmarker Azuremyst Isle/0 52.20,34.40
|mapmarker Azuremyst Isle/0 53.40,30.60
|mapmarker Azuremyst Isle/0 59.80,43.60
|mapmarker Azuremyst Isle/0 55.60,33.40
|mapmarker Azuremyst Isle/0 56.40,37.60
|mapmarker Azuremyst Isle/0 58.20,40.40
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Azuremyst Isle 47.85,56.17 |q 9455 |zombiewalk
step
talk Anchorite Fateema##17214
accept Medicinal Purpose##9463 |goto Azuremyst Isle 48.39,51.77
|only if Draenei
step
talk Exarch Menelaous##17116
turnin Strange Findings##9455 |goto Azuremyst Isle 47.11,50.60
accept Nightstalker Clean Up, Isle 2...##9456 |goto Azuremyst Isle 47.11,50.60
step
talk Technician Dyvuun##16551
|tip Walks around.
turnin Travel to Azure Watch##9313 |goto Azuremyst Isle 48.66,50.23
step
talk Caregiver Chellan##16553
|tip Inside the building.
turnin Word from Azure Watch##9314 |goto Azuremyst Isle 48.34,49.15
step
talk Caregiver Chellan##16553
|tip Inside the building.
home Azure Watch |goto Azuremyst Isle 48.34,49.15 |q 4761 |future
step
_NOTE:_
Use Weapon Stones
|tip We will train Mining and Blacksmithing.
|tip Allows you to make and use {o}Sharpening Stones{}.		|only if Warrior
|tip Allows you to make and use {o}Weightstones{}.		|only if Paladin
|tip Increases damage.
|tip Mine {o}Copper Ore{} as you see it.
|tip Use the {g}Rough Stones{} to make sharpening stones.	|only if Warrior
|tip Use the {g}Rough Stones{} to make weightstones.		|only if Paladin
Click Here to Continue |confirm |q 9453
|only if Warrior or Paladin
step
talk Dulvi##17488
Train Apprentice Mining |skillmax Mining,75 |goto Azuremyst Isle/0 48.96,51.06
|only if Warrior or Paladin
step
talk Ziz##17486
buy Mining Pick##2901 |goto Azuremyst Isle/0 48.73,52.42
|only if Warrior or Paladin
step
talk Guvan##17482
|tip Inside the building.
accept Help Tavara##9586 |goto Azuremyst Isle 48.60,49.29
|only if Draenei Priest
step
talk Acteon##17110
turnin Find Acteon!##9453 |goto Azuremyst Isle 49.78,51.94
accept The Great Moongraze Hunt##9454 |goto Azuremyst Isle 49.78,51.94
stickystart "Collect_Moongraze_Stag_Tenderloins"
stickystart "Collect_Root_Trapper_Vines"
step
Heal Tavara |q 9586/1 |goto Azuremyst Isle 56.22,48.88
|tip Cast {o}Lesser Heal{} on Tavara.
|only if Draenei Priest
step
talk Guvan##17482
|tip Inside the building.
turnin Help Tavara##9586 |goto Azuremyst Isle 48.60,49.29
|only if Draenei Priest
step
label "Collect_Moongraze_Stag_Tenderloins"
kill Moongraze Stag##17200+
|tip White deer.
collect 6 Moongraze Stag Tenderloin##23676 |q 9454/1 |goto Azuremyst Isle 53.20,57.20
|tip Don't vendor them.
|mapmarker Azuremyst Isle/0 48.20,65.60
|mapmarker Azuremyst Isle/0 48.40,57.40
|mapmarker Azuremyst Isle/0 48.40,60.60
|mapmarker Azuremyst Isle/0 50.40,67.80
|mapmarker Azuremyst Isle/0 50.80,53.40
|mapmarker Azuremyst Isle/0 51.40,59.60
|mapmarker Azuremyst Isle/0 51.60,65.00
|mapmarker Azuremyst Isle/0 53.40,67.80
|mapmarker Azuremyst Isle/0 53.80,62.40
|mapmarker Azuremyst Isle/0 55.40,65.00
|mapmarker Azuremyst Isle/0 55.80,55.00
|mapmarker Azuremyst Isle/0 55.80,59.20
|mapmarker Azuremyst Isle/0 56.60,68.00
|mapmarker Azuremyst Isle/0 57.80,63.00
|mapmarker Azuremyst Isle/0 58.60,56.40
|mapmarker Azuremyst Isle/0 59.40,65.60
step
label "Collect_Root_Trapper_Vines"
kill Root Trapper##17196+
|tip Walking plants.
collect 8 Root Trapper Vine##23685 |q 9463/1 |goto Azuremyst Isle 53.20,57.20
|mapmarker Azuremyst Isle/0 48.20,65.60
|mapmarker Azuremyst Isle/0 48.40,57.40
|mapmarker Azuremyst Isle/0 48.40,60.60
|mapmarker Azuremyst Isle/0 50.40,67.80
|mapmarker Azuremyst Isle/0 50.80,53.40
|mapmarker Azuremyst Isle/0 51.40,59.60
|mapmarker Azuremyst Isle/0 51.60,65.00
|mapmarker Azuremyst Isle/0 53.40,67.80
|mapmarker Azuremyst Isle/0 53.80,62.40
|mapmarker Azuremyst Isle/0 55.40,65.00
|mapmarker Azuremyst Isle/0 55.80,55.00
|mapmarker Azuremyst Isle/0 55.80,59.20
|mapmarker Azuremyst Isle/0 56.60,68.00
|mapmarker Azuremyst Isle/0 57.80,63.00
|mapmarker Azuremyst Isle/0 58.60,56.40
|mapmarker Azuremyst Isle/0 59.40,65.60
|only if Draenei
step
talk Admiral Odesyus##17240
accept A Small Start##9506 |goto Azuremyst Isle 47.04,70.21
step
talk "Cookie" McWeaksauce##17246
|tip Walks around.
accept Cookie's Jumbo Gumbo##9512 |goto Azuremyst Isle 46.69,70.62
step
talk Blacksmith Calypso##17245
Train Apprentice Blacksmithing |skillmax Blacksmithing,75 |goto Azuremyst Isle/0 46.35,71.19
|only if Warrior or Paladin
stickystart "Collect_Skittering_Crawler_Meat"
step
click Nautical Map##181674
collect Nautical Map##23739 |q 9506/2 |goto Azuremyst Isle 58.57,66.37
step
click Nautical Compass##181675
collect Nautical Compass##23738 |q 9506/1 |goto Azuremyst Isle 59.57,67.64
step
label "Collect_Skittering_Crawler_Meat"
kill Skittering Crawler##17216+
|tip Crabs.
collect 6 Skittering Crawler Meat##23757 |q 9512/1 |goto Azuremyst Isle 55.20,67.40
|mapmarker Azuremyst Isle/0 43.40,74.80
|mapmarker Azuremyst Isle/0 45.20,72.00
|mapmarker Azuremyst Isle/0 47.40,75.00
|mapmarker Azuremyst Isle/0 48.00,69.20
|mapmarker Azuremyst Isle/0 49.40,72.60
|mapmarker Azuremyst Isle/0 51.40,68.40
|mapmarker Azuremyst Isle/0 52.20,71.40
|mapmarker Azuremyst Isle/0 55.20,70.80
step
talk "Cookie" McWeaksauce##17246
|tip Walks around.
turnin Cookie's Jumbo Gumbo##9512 |goto Azuremyst Isle 46.69,70.62
step
talk Admiral Odesyus##17240
turnin A Small Start##9506 |goto Azuremyst Isle 47.03,70.21
accept I've Got a Plant##9530 |goto Azuremyst Isle 47.03,70.21
step
talk Priestess Kyleen Il'dinare##17241
accept Reclaiming the Ruins##9513 |goto Azuremyst Isle 47.13,70.28
step
talk Archaeologist Adamant Ironheart##17242
accept Precious and Fragile Things Need Special Handling##9523 |goto Azuremyst Isle 47.24,69.99
stickystart "Collect_Piles_Of_Leaves"
step
click Hollowed Out Tree##181696
|tip Tree stumps with frayed bark.
collect Hollowed Out Tree##23790 |q 9530/1 |goto Azuremyst Isle 45.90,65.80
|mapmarker Azuremyst Isle/0 45.90,62.40
|mapmarker Azuremyst Isle/0 48.00,63.30
|mapmarker Azuremyst Isle/0 49.20,63.30
step
label "Collect_Piles_Of_Leaves"
click Piles of Leaves##6884+
|tip Piles of purple leaves.
collect 5 Pile of Leaves##23791 |q 9530/2 |goto Azuremyst Isle 46.30,66.30
|mapmarker Azuremyst Isle/0 42.40,66.10
|mapmarker Azuremyst Isle/0 42.40,68.80
|mapmarker Azuremyst Isle/0 45.00,70.40
|mapmarker Azuremyst Isle/0 48.20,64.80
|mapmarker Azuremyst Isle/0 50.20,60.10
|mapmarker Azuremyst Isle/0 50.30,63.30
|mapmarker Azuremyst Isle/0 50.30,66.90
step
talk Admiral Odesyus##17240
turnin I've Got a Plant##9530 |goto Azuremyst Isle 47.03,70.21
accept Tree's Company##9531 |goto Azuremyst Isle 47.03,70.21
step
Kill enemies
|tip Helps reach level 8 after quest turnins.
ding 7,3550 |goto Azuremyst Isle 48.20,65.60
|mapmarker Azuremyst Isle/0 53.20,57.20
|mapmarker Azuremyst Isle/0 48.40,57.40
|mapmarker Azuremyst Isle/0 48.40,60.60
|mapmarker Azuremyst Isle/0 50.40,67.80
|mapmarker Azuremyst Isle/0 50.80,53.40
|mapmarker Azuremyst Isle/0 51.40,59.60
|mapmarker Azuremyst Isle/0 51.60,65.00
|mapmarker Azuremyst Isle/0 53.40,67.80
|mapmarker Azuremyst Isle/0 53.80,62.40
|mapmarker Azuremyst Isle/0 55.40,65.00
|mapmarker Azuremyst Isle/0 55.80,55.00
|mapmarker Azuremyst Isle/0 55.80,59.20
|mapmarker Azuremyst Isle/0 56.60,68.00
|mapmarker Azuremyst Isle/0 57.80,63.00
|mapmarker Azuremyst Isle/0 58.60,56.40
|mapmarker Azuremyst Isle/0 59.40,65.60
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Azuremyst Isle 48.20,65.60 |q 9454
|mapmarker Azuremyst Isle/0 53.20,57.20
|mapmarker Azuremyst Isle/0 48.40,57.40
|mapmarker Azuremyst Isle/0 48.40,60.60
|mapmarker Azuremyst Isle/0 50.40,67.80
|mapmarker Azuremyst Isle/0 50.80,53.40
|mapmarker Azuremyst Isle/0 51.40,59.60
|mapmarker Azuremyst Isle/0 51.60,65.00
|mapmarker Azuremyst Isle/0 53.40,67.80
|mapmarker Azuremyst Isle/0 53.80,62.40
|mapmarker Azuremyst Isle/0 55.40,65.00
|mapmarker Azuremyst Isle/0 55.80,55.00
|mapmarker Azuremyst Isle/0 55.80,59.20
|mapmarker Azuremyst Isle/0 56.60,68.00
|mapmarker Azuremyst Isle/0 57.80,63.00
|mapmarker Azuremyst Isle/0 58.60,56.40
|mapmarker Azuremyst Isle/0 59.40,65.60
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Azuremyst Isle 47.86,56.18 |q 9454 |zombiewalk
step
talk Anchorite Fateema##17214
turnin Medicinal Purpose##9463 |goto Azuremyst Isle 48.39,51.77
|only if Draenei
step
talk Daedal##17215
accept An Alternative Alternative##9473 |goto Azuremyst Isle 48.39,51.48
|only if Draenei
step
talk Acteon##17110
turnin The Great Moongraze Hunt##9454 |goto Azuremyst Isle 49.78,51.94
accept The Great Moongraze Hunt##10324 |goto Azuremyst Isle 49.78,51.94
step
talk Acteon##17110
Train Abilities |trainer Acteon##17110 |goto Azuremyst Isle 49.78,51.94 |q 9473
|only if Hunter
step
talk Ruada##17480
Train Abilities |trainer Ruada##17480 |goto Azuremyst Isle 50.02,50.52 |q 9473
|only if Warrior
step
talk Semid##17481
Train Abilities |trainer Semid##17481 |goto Azuremyst Isle 49.87,49.95 |q 9473
|only if Mage
step
talk Cryptographer Aurren##17232
accept Learning the Language##9538 |goto Azuremyst Isle 49.38,50.96
step
use Stillpine Furbolg Language Primer##23818
Read the Stillpine Furbolg Language Primer |q 9538/1 |goto Azuremyst Isle 49.38,50.96
step
clicknpc Totem of Akida##17360
turnin Learning the Language##9538 |goto Azuremyst Isle 49.44,50.98
accept Totem of Coo##9539 |goto Azuremyst Isle 49.44,50.98
step
talk Dulvi##17488
accept The Missing Fisherman##10428 |goto Azuremyst Isle 48.96,51.06
step
talk Guvan##17482
|tip Inside the building.
Train Abilities |trainer Guvan##17482 |goto Azuremyst Isle 48.60,49.29 |q 9473
|only if Priest
step
talk Tullas##17483
|tip Inside the building.
Train Abilities |trainer Tullas##17483 |goto Azuremyst Isle 48.36,49.56 |q 9473
|only if Paladin
step
talk Tuluun##17212
Train Abilities |trainer Tuluun##17212 |goto Azuremyst Isle 48.05,50.42 |q 9473
|only if Shaman
stickystart "Collect_Moongraze_Buck_Hides"
stickystart "Kill_Infected_Nightstalker_Runts"
step
click Azure Snapdragon##181644+
|tip Blue flowers.
|tip Usually near trees.
collect 5 Azure Snapdragon Bulb##23692 |q 9473/1 |goto Azuremyst Isle 44.70,45.50
|mapmarker Azuremyst Isle/0 41.50,36.10
|mapmarker Azuremyst Isle/0 42.60,43.80
|mapmarker Azuremyst Isle/0 45.00,42.40
|mapmarker Azuremyst Isle/0 45.20,33.60
|mapmarker Azuremyst Isle/0 45.60,38.10
|mapmarker Azuremyst Isle/0 47.00,35.00
|mapmarker Azuremyst Isle/0 49.40,34.30
|mapmarker Azuremyst Isle/0 50.30,37.20
|mapmarker Azuremyst Isle/0 52.30,34.30
|only if Draenei
step
label "Collect_Moongraze_Buck_Hides"
kill Moongraze Buck##17201+
|tip White deer.
collect 6 Moongraze Buck Hide##23677 |q 10324/1 |goto Azuremyst Isle 46.20,39.80
|mapmarker Azuremyst Isle/0 39.80,42.80
|mapmarker Azuremyst Isle/0 40.20,39.20
|mapmarker Azuremyst Isle/0 40.20,45.80
|mapmarker Azuremyst Isle/0 42.00,34.80
|mapmarker Azuremyst Isle/0 43.20,37.80
|mapmarker Azuremyst Isle/0 43.40,41.00
|mapmarker Azuremyst Isle/0 45.40,34.80
|mapmarker Azuremyst Isle/0 43.40,45.60
|mapmarker Azuremyst Isle/0 48.00,37.00
|mapmarker Azuremyst Isle/0 48.40,43.00
|mapmarker Azuremyst Isle/0 48.60,33.40
|mapmarker Azuremyst Isle/0 49.40,46.40
|mapmarker Azuremyst Isle/0 50.40,40.20
|mapmarker Azuremyst Isle/0 51.00,35.60
|mapmarker Azuremyst Isle/0 51.40,43.60
|mapmarker Azuremyst Isle/0 52.00,32.60
|mapmarker Azuremyst Isle/0 53.40,41.20
step
label "Kill_Infected_Nightstalker_Runts"
kill 8 Infected Nightstalker Runt##17202 |q 9456/1 |goto Azuremyst Isle 46.20,39.80
|tip Black tigers.
|mapmarker Azuremyst Isle/0 39.80,42.80
|mapmarker Azuremyst Isle/0 40.20,39.20
|mapmarker Azuremyst Isle/0 40.20,45.80
|mapmarker Azuremyst Isle/0 42.00,34.80
|mapmarker Azuremyst Isle/0 43.20,37.80
|mapmarker Azuremyst Isle/0 43.40,41.00
|mapmarker Azuremyst Isle/0 45.40,34.80
|mapmarker Azuremyst Isle/0 43.40,45.60
|mapmarker Azuremyst Isle/0 48.00,37.00
|mapmarker Azuremyst Isle/0 48.40,43.00
|mapmarker Azuremyst Isle/0 48.60,33.40
|mapmarker Azuremyst Isle/0 49.40,46.40
|mapmarker Azuremyst Isle/0 50.40,40.20
|mapmarker Azuremyst Isle/0 51.00,35.60
|mapmarker Azuremyst Isle/0 51.40,43.60
|mapmarker Azuremyst Isle/0 52.00,32.60
|mapmarker Azuremyst Isle/0 53.40,41.20
step
clicknpc Totem of Coo##17361
|tip Up on the cliff.
turnin Totem of Coo##9539 |goto Azuremyst Isle 55.23,41.64
accept Totem of Tikti##9540 |goto Azuremyst Isle 55.23,41.64
step
Watch the dialogue
|tip Follow Stillpine Ancestor Coo.
Gain the Ghost Walk Buff |havebuff Ghost Walk##30424 |goto Azuremyst Isle 55.55,41.65 |q 9540
step
Watch the dialogue
|tip Jump off the cliff.
|tip You won't die.
clicknpc Totem of Tikti##17362
turnin Totem of Tikti##9540 |goto Azuremyst Isle 64.48,39.77
accept Totem of Yor##9541 |goto Azuremyst Isle 64.48,39.77
step
Watch the dialogue
|tip Follow Stillpine Ancestor Tikti.
Gain the Embrace of the Serpent Buff |havebuff Embrace of the Serpent##30430 |goto Azuremyst Isle 63.78,40.23 |q 9541
step
clicknpc Totem of Yor##17363
|tip Swim in the water.
|tip Underwater.
turnin Totem of Yor##9541 |goto Azuremyst Isle 63.11,67.88
accept Totem of Vark##9542 |goto Azuremyst Isle 63.11,67.88
step
Watch the dialogue
|tip Follow Stillpine Ancestor Yor.
Gain the Shadow of the Forest Buff |havebuff Shadow of the Forest##30448 |goto Azuremyst Isle 61.04,69.46 |q 9542
step
Watch the dialogue
|tip Follow Stillpine Ancestor Yor.
clicknpc Totem of Vark##17364
turnin Totem of Vark##9542 |goto Azuremyst Isle 28.10,62.39
accept The Prophecy of Akida##9544 |goto Azuremyst Isle 28.10,62.39
step
Remove the {y}Shadow of the Forest{} Buff |nobuff Shadow of the Forest##30448 |q 9544
|tip Right-click near minimap.
step
kill Bristlelimb Furbolg##17183, Bristlelimb Windcaller##17184, Bristlelimb Ursa##17185
|tip Furbolgs.
collect Bristlelimb Key##23801+ |n
click Bristlelimb Cage##1787+
|tip Yellow wooden cages.
Free #8# Stillpine Captives |q 9544/1 |goto Azuremyst Isle 26.40,65.00
|mapmarker Azuremyst Isle/0 23.40,65.80
|mapmarker Azuremyst Isle/0 24.00,69.20
|mapmarker Azuremyst Isle/0 25.20,62.20
|mapmarker Azuremyst Isle/0 26.80,68.00
|mapmarker Azuremyst Isle/0 27.60,60.40
|mapmarker Azuremyst Isle/0 29.60,65.80
|mapmarker Azuremyst Isle/0 29.60,69.80
|mapmarker Azuremyst Isle/0 28.60,63.40
stickystart "Collect_Ancient_Relics"
stickystart "Kill_Wrathscale_Enemies"
step
kill Wrathscale Myrmidon##17194, Wrathscale Naga##17193, Wrathscale Siren##17195
|tip Nagas.
collect Rune Covered Tablet##23759 |n
use Rune Covered Tablet##23759
accept Rune Covered Tablet##9514 |goto Azuremyst Isle 31.40,76.00
|mapmarker Azuremyst Isle/0 26.40,77.60
|mapmarker Azuremyst Isle/0 26.80,82.80
|mapmarker Azuremyst Isle/0 29.00,79.60
|mapmarker Azuremyst Isle/0 31.80,81.60
|mapmarker Azuremyst Isle/0 35.40,77.40
|mapmarker Azuremyst Isle/0 35.40,81.00
|mapmarker Azuremyst Isle/0 39.00,77.00
step
label "Collect_Ancient_Relics"
click Ancient Relic##181685+
|tip White orbs in stands.
collect 8 Ancient Relic##23779 |q 9523/1 |goto Azuremyst Isle 32.20,77.80
|mapmarker Azuremyst Isle/0 27.90,79.40
|mapmarker Azuremyst Isle/0 29.30,76.60
|mapmarker Azuremyst Isle/0 30.90,80.20
|mapmarker Azuremyst Isle/0 34.20,78.80
step
label "Kill_Wrathscale_Enemies"
kill 5 Wrathscale Myrmidon##17194 |q 9513/1 |goto Azuremyst Isle 31.40,76.00
kill 5 Wrathscale Naga##17193 |q 9513/2 |goto Azuremyst Isle 31.40,76.00
kill 5 Wrathscale Siren##17195 |q 9513/3 |goto Azuremyst Isle 31.40,76.00
|mapmarker Azuremyst Isle/0 26.40,77.60
|mapmarker Azuremyst Isle/0 26.80,82.80
|mapmarker Azuremyst Isle/0 29.00,79.60
|mapmarker Azuremyst Isle/0 31.80,81.60
|mapmarker Azuremyst Isle/0 35.40,77.40
|mapmarker Azuremyst Isle/0 35.40,81.00
|mapmarker Azuremyst Isle/0 39.00,77.00
step
use Tree Disguise Kit##23792
Watch the dialogue
Uncover the Traitor |q 9531/1 |goto Azuremyst Isle 18.49,84.35
step
Remove the {y}Tree Disguise{} Buff |nobuff Tree Disguise##30298 |q 9531
|tip Right-click near minimap.
step
talk Cowlen##17311
turnin The Missing Fisherman##10428 |goto Azuremyst Isle 16.59,94.45
accept All That Remains##9527 |goto Azuremyst Isle 16.59,94.45
step
kill Aberrant Owlbeast##17187, Raving Owlbeast##17188, Deranged Owlbeast##17186
|tip Owlkins.
collect Remains of Cowlen's Family##23789 |q 9527/1 |goto Azuremyst Isle 14.40,89.60
|mapmarker Azuremyst Isle/0 7.20,86.00
|mapmarker Azuremyst Isle/0 7.80,81.80
|mapmarker Azuremyst Isle/0 10.20,86.40
|mapmarker Azuremyst Isle/0 10.40,77.40
|mapmarker Azuremyst Isle/0 10.60,83.00
|mapmarker Azuremyst Isle/0 11.00,89.80
|mapmarker Azuremyst Isle/0 12.60,92.60
|mapmarker Azuremyst Isle/0 13.20,79.20
|mapmarker Azuremyst Isle/0 13.20,86.40
|mapmarker Azuremyst Isle/0 14.00,83.00
|mapmarker Azuremyst Isle/0 15.20,94.40
|mapmarker Azuremyst Isle/0 17.00,80.40
|mapmarker Azuremyst Isle/0 17.00,84.60
|mapmarker Azuremyst Isle/0 17.20,88.20
step
talk Cowlen##17311
turnin All That Remains##9527 |goto Azuremyst Isle 16.59,94.45
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Azuremyst Isle 14.40,89.60 |q 9531
|mapmarker Azuremyst Isle/0 7.20,86.00
|mapmarker Azuremyst Isle/0 7.80,81.80
|mapmarker Azuremyst Isle/0 10.20,86.40
|mapmarker Azuremyst Isle/0 10.40,77.40
|mapmarker Azuremyst Isle/0 10.60,83.00
|mapmarker Azuremyst Isle/0 11.00,89.80
|mapmarker Azuremyst Isle/0 12.60,92.60
|mapmarker Azuremyst Isle/0 13.20,79.20
|mapmarker Azuremyst Isle/0 13.20,86.40
|mapmarker Azuremyst Isle/0 14.00,83.00
|mapmarker Azuremyst Isle/0 15.20,94.40
|mapmarker Azuremyst Isle/0 17.00,80.40
|mapmarker Azuremyst Isle/0 17.00,84.60
|mapmarker Azuremyst Isle/0 17.20,88.20
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Azuremyst Isle 47.86,56.18 |q 9531 |zombiewalk
step
talk Archaeologist Adamant Ironheart##17242
turnin Precious and Fragile Things Need Special Handling##9523 |goto Azuremyst Isle 47.24,69.99
step
talk Admiral Odesyus##17240
turnin Tree's Company##9531 |goto Azuremyst Isle 47.04,70.21
accept Show Gnomercy##9537 |goto Azuremyst Isle 47.04,70.21
step
talk Priestess Kyleen Il'dinare##17241
turnin Reclaiming the Ruins##9513 |goto Azuremyst Isle 47.13,70.28
turnin Rune Covered Tablet##9514 |goto Azuremyst Isle 47.13,70.28
step
talk Engineer "Spark" Overgrind##17243
|tip Gnome.
|tip Walks along the beach.
Select _"It's over, Spark. The admiral knows it was you who betrayed the Alliance. Now you're either going to cooperate with me and tell me everything that you know or we're going to engage in some fisticuff."_ |gossip 118310
kill Engineer "Spark" Overgrind##17243
collect Traitor's Communication##23899 |q 9537/1 |goto Azuremyst Isle 45.40,73.20
|mapmarker Azuremyst Isle/0 47.00,73.00
|mapmarker Azuremyst Isle/0 48.40,69.20
|mapmarker Azuremyst Isle/0 48.40,71.20
|mapmarker Azuremyst Isle/0 48.60,73.00
|mapmarker Azuremyst Isle/0 50.00,70.40
|mapmarker Azuremyst Isle/0 50.40,67.60
step
talk Priestess Kyleen Il'dinare##17241
accept Warlord Sriss'tiz##9515 |goto Azuremyst Isle 47.13,70.28
step
talk Admiral Odesyus##17240
turnin Show Gnomercy##9537 |goto Azuremyst Isle 47.04,70.21
accept Deliver Them From Evil...##9602 |goto Azuremyst Isle 47.04,70.21
step
Enter the cave |goto Azuremyst Isle 26.91,76.44 < 20 |walk |only if not (subzone("Tides' Hollow") and indoors())
Jump down the hole |goto Azuremyst Isle 26.39,74.10 < 10 |walk
kill Warlord Sriss'tiz##17298 |q 9515/1 |goto Azuremyst Isle 24.50,74.52
|tip Walks around.
|tip Downstairs inside the cave.
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
|tip Anywhere inside this cave.
Die on Purpose |complete isdead |goto Azuremyst Isle 26.91,76.44 |q 9515
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Azuremyst Isle 47.86,56.18 |q 9515 |zombiewalk
step
talk Priestess Kyleen Il'dinare##17241
turnin Warlord Sriss'tiz##9515 |goto Azuremyst Isle 47.13,70.28
step
Allow Enemies to Kill You
|tip No death penalty at this level.
|tip Fast travel.
Die on Purpose |complete isdead |goto Azuremyst Isle 41.38,69.38 |q 10324
step
talk Spirit Healer##6491
Select _"Return me to life."_ |gossip 115118
Resurrect at the Spirit Healer |complete not isdead |goto Azuremyst Isle 47.86,56.18 |q 10324 |zombiewalk
step
talk Acteon##17110
turnin The Great Moongraze Hunt##10324 |goto Azuremyst Isle 49.78,51.94
step
talk Ruada##17480
accept Strength of One##9582 |goto Azuremyst Isle 50.02,50.52
|only if Draenei Warrior
step
talk Ruada##17480
Train Abilities |trainer Ruada##17480 |goto Azuremyst Isle 50.02,50.52 |q 9582
|only if Warrior
step
talk Acteon##17110
accept Seek Huntress Kella Nightbow##9757 |goto Azuremyst Isle 49.78,51.94
|only if Draenei Hunter
step
talk Acteon##17110
Train Abilities |trainer Acteon##17110 |goto Azuremyst Isle 49.78,51.94 |q 9757
|only if Hunter
step
_NOTE:_
Stronger Ammo Available
|tip Buy level 10 ammo when restocking.
Click Here to Continue |confirm |q 9757
|only if Hunter
step
talk Semid##17481
accept Control##9595 |goto Azuremyst Isle 49.87,49.95
|only if Draenei Mage
step
talk Semid##17481
Train Abilities |trainer Semid##17481 |goto Azuremyst Isle 49.87,49.95 |q 9595
|only if Mage
step
talk Arugoo the Stillpine##17114
turnin The Prophecy of Akida##9544 |goto Azuremyst Isle 49.37,51.09
accept Stillpine Hold##9559 |goto Azuremyst Isle 49.37,51.09
step
talk Daedal##17215
turnin An Alternative Alternative##9473 |goto Azuremyst Isle 48.39,51.48
|only if Draenei
step
talk Guvan##17482
|tip Inside the building.
Train Abilities |trainer Guvan##17482 |goto Azuremyst Isle 48.60,49.29 |q 9456
|only if Priest
step
talk Tullas##17483
|tip Inside the building.
Train Abilities |trainer Tullas##17483 |goto Azuremyst Isle 48.36,49.56 |q 9456
|only if Paladin
step
talk Tuluun##17212
accept Call of Fire##9464 |goto Azuremyst Isle 48.05,50.42
|only if Draenei Shaman
step
talk Tuluun##17212
Train Abilities |trainer Tuluun##17212 |goto Azuremyst Isle 48.05,50.42 |q 9456
|only if Shaman
step
talk Exarch Menelaous##17116
turnin Nightstalker Clean Up, Isle 2...##9456 |goto Azuremyst Isle 47.11,50.60
turnin Deliver Them From Evil...##9602 |goto Azuremyst Isle 47.11,50.60
accept Coming of Age##9623 |goto Azuremyst Isle 47.11,50.60
step
talk Torallius the Pack Handler##17584
turnin Coming of Age##9623 |goto The Exodar 81.50,51.46
step
talk Huntress Kella Nightbow##17614
turnin Seek Huntress Kella Nightbow##9757 |goto Azuremyst Isle 24.18,54.35
accept Taming the Beast##9591 |goto Azuremyst Isle 24.18,54.35
|only if Draenei Hunter
step
use Taming Totem##23896
|tip On a Barbed Crawler.
|tip Crabs.
|tip Underwater.
Tame a Barbed Crawler |q 9591/1 |goto Azuremyst Isle/0 20.60,64.00
|mapmarker Azuremyst Isle/0 20.40,68.40
|mapmarker Azuremyst Isle/0 21.40,72.20
|mapmarker Azuremyst Isle/0 21.60,66.60
|only if Draenei Hunter
step
talk Huntress Kella Nightbow##17614
turnin Taming the Beast##9591 |goto Azuremyst Isle/0 24.18,54.35
accept Taming the Beast##9592 |goto Azuremyst Isle/0 24.18,54.35
|only if Draenei Hunter
step
use Taming Totem##23897
|tip On a Greater Timberstrider.
|tip Large walking birds.
Tame a Greater Timberstrider |q 9592/1 |goto Azuremyst Isle/0 36.60,35.80
|mapmarker Azuremyst Isle/0 33.20,30.20
|mapmarker Azuremyst Isle/0 33.20,33.40
|mapmarker Azuremyst Isle/0 33.40,36.40
|mapmarker Azuremyst Isle/0 37.40,29.40
|mapmarker Azuremyst Isle/0 38.00,39.00
|mapmarker Azuremyst Isle/0 39.60,34.40
|mapmarker Azuremyst Isle/0 40.20,30.80
|mapmarker Azuremyst Isle/0 41.60,37.00
|mapmarker Azuremyst Isle/0 43.20,32.60
|only if Draenei Hunter
step
talk Huntress Kella Nightbow##17614
turnin Taming the Beast##9592 |goto Azuremyst Isle/0 24.18,54.35
accept Taming the Beast##9593 |goto Azuremyst Isle/0 24.18,54.35
|only if Draenei Hunter
step
use Taming Totem##23898
|tip On a Nightstalker.
|tip Black tigers.
Tame a Nightstalker |q 9593/1 |goto Azuremyst Isle/0 36.60,35.80
|mapmarker Azuremyst Isle/0 33.20,30.20
|mapmarker Azuremyst Isle/0 33.20,33.40
|mapmarker Azuremyst Isle/0 33.40,36.40
|mapmarker Azuremyst Isle/0 37.40,29.40
|mapmarker Azuremyst Isle/0 38.00,39.00
|mapmarker Azuremyst Isle/0 39.60,34.40
|mapmarker Azuremyst Isle/0 40.20,30.80
|mapmarker Azuremyst Isle/0 41.60,37.00
|mapmarker Azuremyst Isle/0 43.20,32.60
|only if Draenei Hunter
step
talk Huntress Kella Nightbow##17614
turnin Taming the Beast##9593 |goto Azuremyst Isle/0 24.18,54.35
accept Beast Training##9675 |goto Azuremyst Isle/0 24.18,54.35
|only if Draenei Hunter
step
Enter the Exodar |goto The Exodar/0 41.95,72.71 < 15 |only if not zone("The Exodar")
talk Ganaar##16712
turnin Beast Training##9675 |goto The Exodar/0 44.23,86.59
|only if Draenei Hunter
step
_NOTE:_
Train Your Pet
|tip Learn pet abilities from Pet Trainers.
|tip Cast {o}Beast Training{} to teach your pet.
Click Here to Continue |confirm |q 9560 |future
|only if Hunter
step
talk Ganaar##16712
Train Pet Abilities |trainer Ganaar##16712 |goto The Exodar/0 44.24,86.61 |q 9560 |future
|only if Hunter
step
Leave the Exodar |goto The Exodar/0 73.51,53.40 < 20 |walk |only if zone("The Exodar")
talk Moordo##17442
accept Beasts of the Apocalypse!##9560 |goto Azuremyst Isle 44.76,23.91
step
talk Gurf##17441
accept Murlocs... Why Here? Why Now?##9562 |goto Azuremyst Isle 44.62,23.48
step
talk High Chief Stillpine##17440
turnin Stillpine Hold##9559 |goto Azuremyst Isle 46.69,20.61
stickystart "Collect_Ravager_Hides"
step
_NOTE:_
Tame a Ravager Specimen
|tip Cast {o}Tame Beast{} on a {o}Ravager Specimen{}.
|tip Abandon your pet first.
|tip New permanent pet.
Click Here to Continue |confirm |goto Azuremyst Isle/0 54.20,19.20 |q 9560 |future
|mapmarker Azuremyst Isle/0 51.40,10.00
|mapmarker Azuremyst Isle/0 52.40,13.20
|mapmarker Azuremyst Isle/0 54.00,16.20
|mapmarker Azuremyst Isle/0 54.60,10.80
|mapmarker Azuremyst Isle/0 56.20,22.40
|mapmarker Azuremyst Isle/0 57.80,16.60
|only if Hunter
step
click Ravager Cage
kill Death Ravager##17556 |q 9582/1 |goto Azuremyst Isle 54.05,9.84
|only if Draenei Warrior
step
talk Temper##17205
turnin Call of Fire##9464 |goto Azuremyst Isle 59.55,18.12
accept Call of Fire##9465 |goto Azuremyst Isle 59.55,18.12
|only if Draenei Shaman
step
label "Collect_Ravager_Hides"
kill Ravager Specimen##17199+
collect 8 Ravager Hide##23845 |q 9560/1 |goto Azuremyst Isle 54.20,19.20
|mapmarker Azuremyst Isle/0 51.40,10.00
|mapmarker Azuremyst Isle/0 52.40,13.20
|mapmarker Azuremyst Isle/0 54.00,16.20
|mapmarker Azuremyst Isle/0 54.60,10.80
|mapmarker Azuremyst Isle/0 56.20,22.40
|mapmarker Azuremyst Isle/0 57.80,16.60
step
talk Moordo##17442
turnin Beasts of the Apocalypse!##9560 |goto Azuremyst Isle 44.76,23.91
step
talk Stillpine the Younger##17445
accept Chieftain Oomooroo##9573 |goto Azuremyst Isle 46.90,21.16
step
talk High Chief Stillpine##17440
accept Search Stillpine Hold##9565 |goto Azuremyst Isle 46.69,20.61
stickystart "Collect_Ritual_Torch_Shaman"
stickystart "Kill_Crazed_Wildkins"
step
Enter the cave |goto Azuremyst Isle 45.36,18.93 < 20 |walk |only if not (subzone("Stillpine Hold") and indoors())
Follow the path up and cross the bridge |goto Azuremyst Isle 48.15,14.51 < 10 |walk
kill Chieftain Oomooroo##17448 |q 9573/1 |goto Azuremyst Isle 47.40,14.12
|tip Upstairs inside the cave.
step
_NOTE:_
During the Next Steps
|tip Avoid killing {o}The Kurken{}.
|tip Large two-headed white dog.
|tip Needed for a quest soon.
Click Here to Continue |confirm |q 9565
step
click Blood Crystal##181748
|tip You will be attacked.
|tip Inside the cave.
turnin Search Stillpine Hold##9565 |goto Azuremyst Isle 50.58,11.56
accept Blood Crystals##9566 |goto Azuremyst Isle 50.58,11.56
step
Leave the cave |goto Azuremyst Isle 45.36,18.93 < 20 |walk |only if subzone("Stillpine Hold") and indoors()
talk High Chief Stillpine##17440
turnin Blood Crystals##9566 |goto Azuremyst Isle 46.69,20.61
stickystop "Collect_Ritual_Torch_Shaman"
stickystop "Kill_Crazed_Wildkins"
step
talk Kurz the Revelator##17443
accept The Kurken is Lurkin'##9570 |goto Azuremyst Isle 46.97,22.27
stickystart "Collect_Ritual_Torch_Shaman"
stickystart "Kill_Crazed_Wildkins"
step
Enter the cave |goto Azuremyst Isle 45.36,18.93 < 20 |walk |only if not (subzone("Stillpine Hold") and indoors())
kill The Kurken##17447
|tip Large two-headed white dog.
|tip Walks around.
|tip Inside the cave.
collect The Kurken's Hide##23860 |q 9570/1 |goto Azuremyst Isle 49.76,12.95
step
label "Collect_Ritual_Torch_Shaman"
kill Crazed Wildkin##17189+
|tip Inside the cave. |notinsticky
collect Ritual Torch##23733 |q 9465/1 |goto Azuremyst Isle 46.00,15.00
|mapmarker Azuremyst Isle/0 47.40,12.80
|mapmarker Azuremyst Isle/0 48.00,15.20
|mapmarker Azuremyst Isle/0 48.40,10.20
|mapmarker Azuremyst Isle/0 49.80,12.80
|only if Draenei Shaman
step
label "Kill_Crazed_Wildkins"
kill 9 Crazed Wildkin##17189 |q 9573/2 |goto Azuremyst Isle 46.00,15.00
|tip Inside the cave. |notinsticky
|mapmarker Azuremyst Isle/0 47.40,12.80
|mapmarker Azuremyst Isle/0 48.00,15.20
|mapmarker Azuremyst Isle/0 48.40,10.20
|mapmarker Azuremyst Isle/0 49.80,12.80
step
Leave the cave |goto Azuremyst Isle 45.36,18.93 < 20 |walk |only if subzone("Stillpine Hold") and indoors()
talk Stillpine the Younger##17445
turnin Chieftain Oomooroo##9573 |goto Azuremyst Isle 46.90,21.16
step
talk Kurz the Revelator##17443
turnin The Kurken is Lurkin'##9570 |goto Azuremyst Isle 46.97,22.27
accept The Kurken's Hide##9571 |goto Azuremyst Isle 46.97,22.27
step
talk High Chief Stillpine##17440
accept Warn Your People##9622 |goto Azuremyst Isle 46.69,20.61
step
talk Moordo##17442
turnin The Kurken's Hide##9571 |goto Azuremyst Isle 44.76,23.91
step
talk Temper##17205
turnin Call of Fire##9465 |goto Azuremyst Isle 59.55,18.12
accept Call of Fire##9467 |goto Azuremyst Isle 59.55,18.12
|only if Draenei Shaman
step
use Fireproof Satchel##24336
collect Ritual Torch##23682 |q 9467
collect Orb of Returning##24335 |q 9467
|only if Draenei Shaman
step
talk Exarch Menelaous##17116
turnin Warn Your People##9622 |goto Azuremyst Isle 47.11,50.60
|only if Shaman
step
click Wickerman Effigy
kill Hauteur##17206
collect Hauteur's Ashes##23688 |q 9467/1 |goto Azuremyst Isle 11.42,82.29
|only if Draenei Shaman
step
use Orb of Returning##24335
Return to Temper |goto Azuremyst Isle 59.17,18.16 < 30 |noway |c |q 9467
|only if Draenei Shaman
step
talk Temper##17205
turnin Call of Fire##9467 |goto Azuremyst Isle 59.55,18.12
accept Call of Fire##9468 |goto Azuremyst Isle 59.55,18.12
|only if Draenei Shaman
stickystart "Collect_Stillpine_Grain"
stickystart "Kill_Queldorei_Magewraith"
step
kill Murgurgala##17475
|tip Larger purple murloc.
|tip Walks along the beach.
|tip Spawns near here.
collect Gurf's Dignity##23850 |n
use Gurf's Dignity##23850
accept Gurf's Dignity##9564 |goto Azuremyst Isle 33.00,27.60
|mapmarker Azuremyst Isle/0 33.40,20.40
|mapmarker Azuremyst Isle/0 34.00,18.40
|mapmarker Azuremyst Isle/0 34.00,25.80
|mapmarker Azuremyst Isle/0 34.20,14.40
|mapmarker Azuremyst Isle/0 34.40,22.20
|mapmarker Azuremyst Isle/0 34.60,16.40
|mapmarker Azuremyst Isle/0 35.40,12.40
step
label "Collect_Stillpine_Grain"
kill Siltfin Murloc##17190, Siltfin Oracle##17191, Siltfin Hunter##17192
|tip Murlocs.
click Stillpine Grain##181757+
|tip Tan sacks.
|tip Usually near murloc huts.
collect 5 Stillpine Grain##23849 |q 9562/1 |goto Azuremyst Isle 34.60,24.80
|mapmarker Azuremyst Isle/0 30.40,26.40
|mapmarker Azuremyst Isle/0 30.80,24.20
|mapmarker Azuremyst Isle/0 32.40,26.00
|mapmarker Azuremyst Isle/0 33.00,23.40
|mapmarker Azuremyst Isle/0 33.20,15.20
|mapmarker Azuremyst Isle/0 33.40,18.40
|mapmarker Azuremyst Isle/0 33.40,21.40
|mapmarker Azuremyst Isle/0 33.40,28.40
|mapmarker Azuremyst Isle/0 33.80,12.40
|mapmarker Azuremyst Isle/0 35.80,11.20
step
label "Kill_Queldorei_Magewraith"
kill Siltfin Murloc##17190, Siltfin Oracle##17191, Siltfin Hunter##17192 |notinsticky
|tip Murlocs. |notinsticky
|tip You will eventually be attacked. |notinsticky
kill Quel'dorei Magewraith##17612 |q 9595/1 |goto Azuremyst Isle 34.60,24.80
|mapmarker Azuremyst Isle/0 30.40,26.40
|mapmarker Azuremyst Isle/0 30.80,24.20
|mapmarker Azuremyst Isle/0 32.40,26.00
|mapmarker Azuremyst Isle/0 33.00,23.40
|mapmarker Azuremyst Isle/0 33.20,15.20
|mapmarker Azuremyst Isle/0 33.40,18.40
|mapmarker Azuremyst Isle/0 33.40,21.40
|mapmarker Azuremyst Isle/0 33.40,28.40
|mapmarker Azuremyst Isle/0 33.80,12.40
|mapmarker Azuremyst Isle/0 35.80,11.20
|only if Draenei Mage
step
talk Gurf##17441
turnin Gurf's Dignity##9564 |goto Azuremyst Isle 44.62,23.48
turnin Murlocs... Why Here? Why Now?##9562 |goto Azuremyst Isle 44.62,23.48
step
talk Ruada##17480
turnin Strength of One##9582 |goto Azuremyst Isle 50.02,50.52
accept Behomat##10350 |goto Azuremyst Isle 50.02,50.52
|only if Draenei Warrior
step
talk Tuluun##17212
turnin Call of Fire##9468 |goto Azuremyst Isle 48.05,50.42
accept Call of Fire##9461 |goto Azuremyst Isle 48.05,50.42
|only if Draenei Shaman
step
talk Exarch Menelaous##17116
turnin Warn Your People##9622 |goto Azuremyst Isle 47.11,50.60
step
Enter the Exodar |goto The Exodar/0 73.68,53.49 < 20 |walk
talk Behomat##17120
|tip Top of the platform.
turnin Behomat##10350 |goto The Exodar 55.59,82.27
|only if Draenei Warrior
step
Enter the Exodar |goto The Exodar/0 73.68,53.49 < 20 |walk
talk Prophet Velen##17468
|tip Multiple locations.
turnin Call of Fire##9461 |goto The Exodar 32.86,54.50
accept Call of Fire##9555 |goto The Exodar 32.86,54.50
May also be in Bloodmyst Isle at [Bloodmyst Isle/0 54.03,55.48]
|only if Draenei Shaman
step
talk Farseer Nobundo##17204
|tip Walks around.
|tip Top of the platform.
turnin Call of Fire##9555 |goto The Exodar/0 31.09,30.10
|only if Draenei Shaman
step
Enter the Exodar |goto The Exodar/0 73.68,53.49 < 20 |walk
talk Bati##17514
|tip Inside the building.
turnin Control##9595 |goto The Exodar/0 46.35,63.48
|only if Draenei Mage
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Darkshore (11-14)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Bloodmyst Isle (14-20)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Darkshore (20-21)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Ashenvale (21-23)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Wetlands (23-24)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Redridge Mountains (24-25)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Duskwood (25-27)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Redridge Mountains (27-28)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Wetlands (28-30)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Duskwood (30-31)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Stranglethorn Vale (31-32)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Dustwallow Marsh (32-32)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Thousand Needles (32-33)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Hillsbrad Foothills (33-33)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Arathi Highlands (33-34)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Hillsbrad Foothills (34-34)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Arathi Highlands (34-35)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Dustwallow Marsh (35-35)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Stranglethorn Vale (35-37)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Dustwallow Marsh (37-39)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Arathi Highlands (39-40)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Alterac Mountains (40-41)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Arathi Highlands (41-41)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Badlands (41-42)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Stranglethorn Vale (42-44)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Dustwallow Marsh (44-45)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Tanaris (45-45)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Searing Gorge (45-45)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Stranglethorn Vale (45-46)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Tanaris (46-48)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Un'Goro Crater (48-49)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\The Hinterlands (49-50)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Searing Gorge (50-51)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Burning Steppes (51-52)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Felwood (52-53)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Un'Goro Crater (53-54)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Winterspring & Felwood (54-56)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Western & Eastern Plaguelands (56-59)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Classic (11-60)\\Silithus (59-60)")
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
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Hellfire Peninsula Group Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Zangarmarsh Group Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Terokkar Forest Group Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Nagrand Group Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Blade's Edge Mountains Group Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Netherstorm Group Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Shaman Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\The Burning Crusade (60-70)\\Isle of Quel'danas")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Druid Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Priest Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Warrior Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Hunter Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Rogue Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Mage Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Paladin Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Class Quests\\Warlock Class Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Hunter Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Warrior Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Paladin Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Rogue Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Priest Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Mage Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Warlock Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Druid Intro")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Boosted Characters\\Boosted Shaman Intro")
