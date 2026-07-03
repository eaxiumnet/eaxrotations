local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Alliance" then return end
if ZGV:DoMutex("ProfessionsA") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Cooking\\Cooking (1-525)",{
mopready=true,
condition_suggested=function() return skill('Cooking') > 0 end,
description="This guide will walk you through leveling your Cooking skill from 1-525.",
},[[
step
talk Daryl Riknussun##5159
|tip Inside the building.
Train Apprentice Cooking |skillmax Cooking,75 |goto Ironforge/0 60.08,36.44
step
talk Daryl Riknussun##5159
|tip Inside the building.
Train Spice Bread |learn Spice Bread##37836 |goto Ironforge/0 60.08,36.44
step
talk Emrul Riknussun##5160
|tip Downstairs inside the building.
buy 60 Simple Flour##30817 |goto Ironforge/0 59.88,37.36 |complete skill("Cooking") >= 40
buy 60 Mild Spices##2678 |goto Ironforge/0 59.88,37.36 |complete skill("Cooking") >= 40
|tip These totals are approximate.
|tip You may need more or less than the indicated amounts.
step
create 60 Spice Bread##37836,Cooking,40 |goto Ironforge/0 78.41,52.76
|tip Stand next to the fire downstairs inside the building.
|tip You may need to create more or less of these.
|tip Each additional Spice Bread requires 1 Simple Flour and 1 Mild Spices.
step
Enter the building |goto Loch Modan/0 35.23,47.74 < 5 |walk
talk Drac Roughcut##1465
|tip Inside the building.
buy Recipe: Smoked Bear Meat##6892 |goto Loch Modan/0 35.57,49.15 |or
'|complete skill("Cooking") >= 65 |or
step
use the Recipe: Smoked Bear Meat##6892
Train Smoked Bear Meat |learn Smoked Bear Meat##8607
step
map Darkshore/0
path follow smart; loop on; ants curved; dist 20
path	45.52,35.10	46.86,35.15	47.88,33.99	48.82,34.11	49.47,33.15
path	49.81,31.71	49.00,30.97	48.64,29.50	49.29,27.40	48.64,27.07
path	48.40,25.88	48.18,24.49	47.62,23.22	46.59,22.69	45.54,23.42
path	44.37,23.40	44.27,24.98	43.83,26.43	44.32,27.91	43.94,29.27
path	44.78,30.11	45.40,31.46	44.78,32.44	43.97,32.76	42.43,32.68
path	41.39,33.60	41.66,35.17	42.07,37.43	42.42,39.82	43.17,41.92
path	44.41,42.90	45.25,43.21	45.48,41.84
Kill Bear enemies along this path
collect 25 Bear Meat##3173 |or
|tip You can also purchase them from the Auction House.
'|complete skill("Cooking") >= 65 |or
step
cast Basic Campfire##818
|tip Stand next to the Basic Campfire.
create 25 Smoked Bear Meat##8607,Cooking,65
stickystart "Collect_Clam_Meat_110"
step
map Westfall/0
path follow smart; loop off; dist 20
path	51.32,9.67	49.06,10.01	44.72,8.70	41.78,10.34	38.85,13.51
path	36.20,18.29	33.45,22.08	31.88,24.30
Kill Crawler enemies around this area
|tip You can find more further down the coast.
collect 30 Crawler Meat##2674 |or
|tip You can also purchase them from the Auction House.
|tip This total is approximate.
|tip You may need more or less than the indicated amount.
'|complete skill("Cooking") >= 130 |or
step
label "Collect_Clam_Meat_110"
Kill Murloc enemies around this area
|tip They are found all along the coastline. |notinsticky
collect Small Barnacled Clam##5523 |n
use the Small Barnacled Clam##5523
collect 65 Clam Meat##5503 |goto Westfall/0 37.26,15.67 |or
|tip You can also purchase them from the Auction House. |notinsticky
|tip This total is approximate. |notinsticky
|tip You may need more or less than the indicated amount. |notinsticky
You can find more around [31.16,26.10] |notinsticky
'|complete skill("Cooking") >= 110 |or
step
Enter the building |goto Stormwind City/0 75.14,55.26 < 7 |walk
talk Stephen Ryback##5482
|tip Downstairs inside the building.
Train Journeyman Cooking |skillmax Cooking,150 |goto Stormwind City/0 78.17,53.09
step
talk Stephen Ryback##5482
|tip Downstairs inside the building.
Train Boiled Clams |learn Boiled Clams##6499 |goto Stormwind City/0 78.17,53.09
step
talk Erika Tate##5483
|tip Downstairs inside the building.
buy 65 Refreshing Spring Water##159 |goto Stormwind City/0 78.53,52.88 |or
|tip This total is approximate.
|tip You may need more or less than the indicated amount.
'|complete skill("Cooking") >= 110 |or
step
create 65 Boiled Clams##6499,Cooking,110 |goto Stormwind City/0 78.41,52.76
|tip Stand next to the Warm Fire.
|tip Downstairs inside the building.
|tip You may need to create more or less of these.
|tip Each additional Boiled Clams requires 1 Refreshing Spring Water and 1 Clam Meat.
step
talk Stephen Ryback##5482
|tip Downstairs inside the building.
Train Crab Cake |learn Crab Cake##2544 |goto Stormwind City/0 78.17,53.09
step
collect 30 Crawler Meat##2674 |or
|tip You collected these in a previous step.
'|complete skill("Cooking") >= 130 |or
step
create 30 Crab Cake##2544,Cooking,130 |goto Stormwind City/0 78.41,52.76
|tip Stand next to the Warm Fire.
|tip Downstairs inside the building.
|tip You may need to create more or less of these.
|tip Each additional Crab Cake requires 1 Crawler Meat.
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Cooking + Fishing (1-525)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Bear Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Big Bear Meat")
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Cooking\\Farming Guides\\Boar Ribs",{
mopready=true,
meta={goldtype="route",levelreq=10},
items={2677},
maps={"Westfall"},
},[[
step
map Westfall/0
path follow smart; loop on; ants straight; dist 30
path	62.45,42.12	61.05,38.49	59.20,30.20	58.69,26.18	58.85,22.18
path	55.99,22.99	53.72,26.55	51.15,26.31	48.14,25.64	47.04,19.68
path	44.81,17.52	42.78,19.23	41.83,24.14	41.27,26.78	45.37,30.33
path	49.58,30.72	53.39,28.48	55.63,29.25
Kill Boar enemies along this path
collect Boar Ribs##2677 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Buzzard Wing")
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Cooking\\Farming Guides\\Clam Meat",{
mopready=true,
meta={goldtype="route",levelreq=10},
items={5503},
maps={"Westfall"},
},[[
step
Kill Murloc enemies around this area
|tip They are found all along the coastline.
collect Small Barnacled Clam##5523 |n
use the Small Barnacled Clam##5523
collect Clam Meat##5503 |n |goto Westfall 37.26,15.67
|tip They are inside of the Small Barnacled Clams.
'|confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Coyote Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Crag Boar Rib")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Crawler Claw")
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Cooking\\Farming Guides\\Crawler Meat",{
mopready=true,
meta={goldtype="route",levelreq=10},
items={2674},
maps={"Westfall"},
},[[
step
map Westfall
path follow smart; loop off; dist 20
path	51.32,9.67	49.06,10.01	44.72,8.70	41.78,10.34	38.85,13.51
path	36.20,18.29	33.45,22.08	31.88,24.30
Kill Crawler enemies around this area
|tip You can find more further down the coast.
collect Crawler Meat##2674 |n
'|goto Westfall 31.88,24.30 < 20 |noway |c
step
map Westfall
path follow smart; loop off; dist 20
path	31.88,24.30	33.45,22.08	36.20,18.29	38.85,13.51	41.78,10.34
path	44.72,8.70	49.06,10.01	51.32,9.67
Kill Crawler enemies around this area
|tip You can find more further down the coast.
collect Crawler Meat##2674 |n
'|goto Westfall 51.32,9.67 < 20 |noway |c
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Crocolisk Meat")
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Cooking\\Farming Guides\\Chunk of Boar Meat",{
mopready=true,
meta={goldtype="route",levelreq=1},
items={769},
maps={"Elwynn Forest"},
},[[
step
kill Stonetusk Boar##113
collect Chunk of Boar Meat##769 |n |goto Elwynn Forest 41.81,87.22
You can find more around this area [32.96,84.95]
'|confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Giant Clam Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Gooey Spider Leg")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Goretusk Liver")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Goretusk Snout")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Kodo Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Lean Wolf Flank")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Lion Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Meaty Bat Wing")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Murloc Eye")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Murloc Fin")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Mystery Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Raptor Egg")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Raptor Flesh")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Red Wolf Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Scorpid Stinger")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Small Egg")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Small Spider Leg")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Soft Frenzy Flesh")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Spider Ichor")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Strider Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Stringy Vulture Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Stringy Wolf Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Tangy Clam Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Tender Crocolisk Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Thunder Lizard Tail")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Tiger Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Tough Condor Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Cooking\\Farming Guides\\Turtle Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Breath of Wind")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Core of Earth")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Elemental Air")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Elemental Earth")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Elemental Fire")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Elemental Water")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Essence of Air")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Essence of Earth")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Essence of Fire")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Essence of Undeath")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Essence of Water")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Globe of Water")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Heart of Fire")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Heart of the Wild")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Ichor of Undeath")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Elements\\Farming Guides\\Living Essence")
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Enchanting\\Farming Guides\\Strange Dust",{
mopready=true,
meta={goldtype="route",skillreq={Enchanting=1},levelreq=1},
items={10940},
},[[
step
Disenchant level 5-20 green weapons and armor
|tip You can disenchant old gear or buy some off the Auction House.
|tip You may sometimes get Small Glimmering Shards instead of Strange Dust.
collect Strange Dust##10940 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Enchanting\\Farming Guides\\Lesser Magic Essence",{
mopready=true,
meta={goldtype="route",skillreq={Enchanting=1},levelreq=1},
items={10938},
},[[
step
Disenchant level 3-12 green weapons and armor
|tip You can disenchant old gear or buy some off the Auction House.
|tip You may sometimes get Strange Dust instead of Lesser Magic Essence.
collect Lesser Magic Essence##10938 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Enchanting\\Farming Guides\\Greater Magic Essence",{
mopready=true,
meta={goldtype="route",skillreq={Enchanting=1},levelreq=1},
items={10939},
},[[
step
Disenchant level 9-21 green weapons and armor
|tip You can disenchant old gear or buy some off the Auction House.
|tip You may sometimes get Strange Dust instead of Greater Magic Essence.
|tip You can turn 3 Lesser Magic Essences into a Greater Magic Essence.
collect Greater Magic Essence##10939 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Enchanting\\Farming Guides\\Lesser Eternal Essence")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Enchanting\\Farming Guides\\Greater Eternal Essence")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Enchanting\\Farming Guides\\Small Brilliant Shard")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Enchanting\\Farming Guides\\Large Brilliant Shard")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Enchanting\\Farming Guides\\Illusion Dust")
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Enchanting\\Farming Guides\\Lesser Astral Essence",{
mopready=true,
meta={goldtype="route",skillreq={Enchanting=1},levelreq=1},
items={10998},
},[[
step
Disenchant level 20-25 green weapons and armor
|tip You can disenchant old gear or buy some off the Auction House.
collect Lesser Astral Essence##10998 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Enchanting\\Farming Guides\\Greater Astral Essence",{
mopready=true,
meta={goldtype="route",skillreq={Enchanting=1},levelreq=1},
items={11082},
},[[
step
Disenchant level 20-30 green weapons and armor
|tip You can disenchant old gear or buy some off the Auction House.
collect Greater Astral Essence##11082 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Enchanting\\Farming Guides\\Soul Dust")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Enchanting\\Farming Guides\\Lesser Mystic Essence")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Enchanting\\Farming Guides\\Greater Mystic Essence")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Enchanting\\Farming Guides\\Vision Dust")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Enchanting\\Farming Guides\\Lesser Nether Essence")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Enchanting\\Farming Guides\\Greater Nether Essence")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Enchanting\\Farming Guides\\Dream Dust")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Fishing\\Farming Guides\\Golden Darter")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Fishing\\Farming Guides\\Figluster's Mudfish")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Fishing\\Farming Guides\\Icefin Bluefish")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Fishing\\Farming Guides\\Raw Loch Frenzy")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Fishing\\Farming Guides\\Raw Brilliant Smallfish")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Fishing\\Farming Guides\\Raw Slitherskin Mackerel")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Fishing\\Farming Guides\\Raw Rainbow Fin Albacore")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Fishing\\Farming Guides\\Raw Longjaw Mud Snapper")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Fishing\\Farming Guides\\Raw Bristle Whisker Catfish")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Fishing\\Farming Guides\\Raw Sagefish")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Fishing\\Farming Guides\\Raw Mithril Head Trout")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Fishing\\Farming Guides\\Raw Rockscale Cod")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Fishing\\Farming Guides\\Raw Sunscale Salmon")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Silverleaf")
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Herbalism\\Farming Guides\\Peacebloom",{
mopready=true,
meta={goldtype="route",skillreq={herbalism=1},levelreq=1},
items={2447},
maps={"Elwynn Forest"},
},[[
step
map Elwynn Forest/0
path follow smart; loop on; ants curved; dist 20
path	35.16,58.15	35.80,61.90	34.96,66.91	35.08,70.72	34.97,74.55
path	31.26,76.29	29.39,72.28	26.34,77.16	26.78,84.53	26.01,88.87
path	28.95,85.90	31.32,84.53	34.00,86.31	35.63,87.61	40.33,90.30
path	42.44,85.05	42.33,79.53	44.78,75.63	57.19,75.30	61.71,78.02
path	64.64,80.21	66.96,82.28	71.53,82.34	74.86,79.96	85.15,82.86
path	88.50,76.38	87.13,70.90	86.64,64.81	83.70,60.88	78.23,58.27
path	74.68,59.68	70.59,61.28	67.25,64.47	63.72,65.35	60.60,62.03
path	56.21,61.31	51.67,60.44	49.08,59.49	44.65,55.81	42.02,54.40
path	39.16,55.56
Click herbs as you follow the path around this area
|tip Track them on your minimap with "Find Herbs".
collect Peacebloom##2447 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Earthroot")
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Herbalism\\Farming Guides\\Briarthorn",{
mopready=true,
meta={goldtype="route",skillreq={herbalism=1},levelreq=10},
items={2450},
maps={"Loch Modan"},
},[[
step
map Loch Modan/0
path follow smart; loop on; ants straight; dist 30
path	56.98,15.26	61.49,21.17	68.60,23.19	70.65,22.23	72.67,25.79
path	77.21,30.71	72.97,37.47	71.59,38.08	67.26,38.34	68.83,40.71
path	73.59,41.67	77.00,42.54	74.86,47.01	74.63,52.50	75.68,64.15
path	75.06,66.38	77.51,66.56	78.64,71.51	76.44,72.20	70.89,71.61
path	68.52,73.74	64.48,71.81	57.98,66.30	61.67,57.11	64.07,54.51
path	69.60,51.49	67.50,48.59	63.83,43.43	65.43,41.83	62.71,39.61
path	61.89,36.89	60.66,33.83	61.31,30.01	55.32,26.14	50.10,21.67
Click herbs as you follow the path around this area
|tip Briarthorn can share a spawn with other herbs in the area, so pick them all.
|tip Track them on your minimap with "Find Herbs".
|tip You will need at least 70 Herbalism skill to gather these.
collect Briarthorn##2450 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Grave Moss")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Liferoot")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Fadeleaf")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Wildvine")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Blindweed")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Ghost Mushroom")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Mountain Silversage")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Icecap")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Black Lotus")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Mageroyal")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Stranglekelp")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Swiftthistle")
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Herbalism\\Farming Guides\\Bruiseweed",{
mopready=true,
meta={goldtype="route",skillreq={herbalism=100},levelreq=25},
items={2453},
maps={"Stonetalon Mountains"},
},[[
step
map Stonetalon Mountains/0
path follow smart; loop on; ants straight; dist 30
path	73.00,59.72	66.74,54.82	63.25,56.60	53.01,45.12	52.19,43.22
path	52.78,40.43	49.32,35.40	48.73,32.68	45.84,25.38	41.49,18.24
path	39.73,43.04	37.25,49.59	36.30,51.80	37.78,56.59	58.09,73.47
path	61.22,84.07	63.82,85.60	71.85,83.84	73.87,86.83	74.93,88.92
path	78.14,78.96
Click herbs as you follow the path around this area
|tip Track them on your minimap with "Find Herbs".
|tip You will need at least 100 Herbalism skill to gather these.
collect Bruiseweed##2453 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Wild Steelbloom")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Kingsblood")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Goldthorn")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Khadgar's Whisker")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Dragon's Teeth")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Firebloom")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Purple Lotus")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Sungrass")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Gromsblood")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Golden Sansam")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Dreamfoil")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Herbalism\\Farming Guides\\Sorrowmoss")
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Mining\\Farming Guides\\Copper Ore",{
mopready=true,
meta={goldtype="route",skillreq={mining=1},levelreq=1},
items={2770},
maps={"Elwynn Forest"},
},[[
step
map Elwynn Forest/0
path follow smart; loop on; ants curved; dist 20
path	30.84,52.85	31.66,56.55	30.70,59.27	33.97,61.71	32.67,69.74
path	34.82,71.77	38.65,70.47	41.90,72.73	38.79,78.16	36.73,83.14
path	38.86,85.10	40.47,81.19	42.54,75.73	43.46,72.43	45.88,71.66
path	48.66,72.57	50.67,73.61	52.16,76.22	51.59,81.68	50.51,84.27
path	52.44,85.57	54.07,81.63	55.50,80.65	57.18,77.77	59.76,76.99
path	64.90,71.42	66.82,69.10	70.81,68.32	75.97,68.43	74.95,64.93
path	73.11,60.29	76.43,54.83	77.84,50.88	75.35,46.25	73.10,46.01
path	71.20,49.01	71.93,55.39	68.33,54.29	67.11,57.66	65.88,58.62
path	65.45,55.47	63.86,53.92	61.15,54.32	59.49,56.50	57.71,57.94
path	55.65,58.04	53.51,57.94	52.34,58.34	51.04,58.74	49.28,57.01
path	50.05,53.17	48.15,51.19	47.15,49.29	43.66,49.22	41.39,51.02
path	39.84,53.01	36.99,52.64	34.92,51.69	35.76,48.57	34.85,46.74
click Copper Vein##1731+
|tip Track them on your minimap with "Find Minerals".
collect Copper Ore##2770 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Mining\\Farming Guides\\Rough Stone",{
mopready=true,
meta={goldtype="route",skillreq={mining=1},levelreq=1},
items={2835},
maps={"Elwynn Forest"},
},[[
step
map Elwynn Forest/0
path follow smart; loop on; ants curved; dist 20
path	30.84,52.85	31.66,56.55	30.70,59.27	33.97,61.71	32.67,69.74
path	34.82,71.77	38.65,70.47	41.90,72.73	38.79,78.16	36.73,83.14
path	38.86,85.10	40.47,81.19	42.54,75.73	43.46,72.43	45.88,71.66
path	48.66,72.57	50.67,73.61	52.16,76.22	51.59,81.68	50.51,84.27
path	52.44,85.57	54.07,81.63	55.50,80.65	57.18,77.77	59.76,76.99
path	64.90,71.42	66.82,69.10	70.81,68.32	75.97,68.43	74.95,64.93
path	73.11,60.29	76.43,54.83	77.84,50.88	75.35,46.25	73.10,46.01
path	71.20,49.01	71.93,55.39	68.33,54.29	67.11,57.66	65.88,58.62
path	65.45,55.47	63.86,53.92	61.15,54.32	59.49,56.50	57.71,57.94
path	55.65,58.04	53.51,57.94	52.34,58.34	51.04,58.74	49.28,57.01
path	50.05,53.17	48.15,51.19	47.15,49.29	43.66,49.22	41.39,51.02
path	39.84,53.01	36.99,52.64	34.92,51.69	35.76,48.57	34.85,46.74
click Copper Vein##1731+
|tip Track them on your minimap with "Find Minerals".
collect Rough Stone##2835 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Mining\\Farming Guides\\Tin Ore",{
mopready=true,
meta={goldtype="route",skillreq={mining=50},levelreq=20},
items={2771},
maps={"Ashenvale"},
},[[
step
map Kalimdor/0
path follow smart; loop on; ants straight; dist 30
path	44.89,34.26	44.33,34.72
map Ashenvale/0
path	16.61,27.89	20.48,28.08	20.00,33.38	16.87,36.59	19.99,41.70
path	19.64,44.86	22.28,49.81	25.73,53.76	30.03,58.81	28.36,63.31
path	31.43,64.91	32.88,70.11	38.79,63.61	42.14,63.26	42.24,68.10
path	44.49,70.63	51.56,74.31	55.59,75.26	55.32,68.67	56.36,64.09
path	58.46,65.61	62.13,64.77	63.83,65.27	65.66,69.02	71.90,71.98
path	75.32,75.93	75.51,69.19	82.44,71.50	81.58,49.07	79.19,47.72
path	76.14,51.73	70.40,54.04	69.08,52.18	65.23,55.56	66.82,47.07
path	64.33,43.71	61.84,42.80	59.00,37.01	57.53,30.19	54.73,33.28
path	54.27,36.64	56.34,40.95	60.51,46.50	53.44,48.07	48.22,46.33
path	45.28,47.32	43.45,41.62	41.73,40.62	41.32,36.20	36.59,36.37
path	38.26,30.49	33.33,28.17	32.75,21.40	25.66,19.01	20.89,19.16
click Tin Vein##1732+
|tip Track them on your minimap with "Find Minerals".
|tip You will need level 50 Mining to collect these.
collect Tin Ore##2771 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Mining\\Farming Guides\\Coarse Stone",{
mopready=true,
meta={goldtype="route",skillreq={mining=50},levelreq=20},
items={2836},
maps={"Ashenvale"},
},[[
step
map Kalimdor/0
path follow smart; loop on; ants straight; dist 30
path	44.89,34.26	44.33,34.72
map Ashenvale/0
path	16.61,27.89	20.48,28.08	20.00,33.38	16.87,36.59	19.99,41.70
path	19.64,44.86	22.28,49.81	25.73,53.76	30.03,58.81	28.36,63.31
path	31.43,64.91	32.88,70.11	38.79,63.61	42.14,63.26	42.24,68.10
path	44.49,70.63	51.56,74.31	55.59,75.26	55.32,68.67	56.36,64.09
path	58.46,65.61	62.13,64.77	63.83,65.27	65.66,69.02	71.90,71.98
path	75.32,75.93	75.51,69.19	82.44,71.50	81.58,49.07	79.19,47.72
path	76.14,51.73	70.40,54.04	69.08,52.18	65.23,55.56	66.82,47.07
path	64.33,43.71	61.84,42.80	59.00,37.01	57.53,30.19	54.73,33.28
path	54.27,36.64	56.34,40.95	60.51,46.50	53.44,48.07	48.22,46.33
path	45.28,47.32	43.45,41.62	41.73,40.62	41.32,36.20	36.59,36.37
path	38.26,30.49	33.33,28.17	32.75,21.40	25.66,19.01	20.89,19.16
click Tin Vein##1732+
|tip Track them on your minimap with "Find Minerals".
|tip You will need level 50 Mining to collect these.
collect Coarse Stone##2836 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Mining\\Farming Guides\\Silver Ore",{
mopready=true,
meta={goldtype="route",skillreq={mining=50},levelreq=20},
items={2775},
maps={"Ashenvale"},
},[[
step
map Kalimdor/0
path follow smart; loop on; ants straight; dist 30
path	44.89,34.26	44.33,34.72
map Ashenvale/0
path	16.61,27.89	20.48,28.08	20.00,33.38	16.87,36.59	19.99,41.70
path	19.64,44.86	22.28,49.81	25.73,53.76	30.03,58.81	28.36,63.31
path	31.43,64.91	32.88,70.11	38.79,63.61	42.14,63.26	42.24,68.10
path	44.49,70.63	51.56,74.31	55.59,75.26	55.32,68.67	56.36,64.09
path	58.46,65.61	62.13,64.77	63.83,65.27	65.66,69.02	71.90,71.98
path	75.32,75.93	75.51,69.19	82.44,71.50	81.58,49.07	79.19,47.72
path	76.14,51.73	70.40,54.04	69.08,52.18	65.23,55.56	66.82,47.07
path	64.33,43.71	61.84,42.80	59.00,37.01	57.53,30.19	54.73,33.28
path	54.27,36.64	56.34,40.95	60.51,46.50	53.44,48.07	48.22,46.33
path	45.28,47.32	43.45,41.62	41.73,40.62	41.32,36.20	36.59,36.37
path	38.26,30.49	33.33,28.17	32.75,21.40	25.66,19.01	20.89,19.16
click Silver Vein##1733+
|tip Track them on your minimap with "Find Minerals".
|tip You will need level 50 Mining to collect these.
collect Silver Ore##2775 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Mining\\Farming Guides\\Moss Agate",{
mopready=true,
meta={goldtype="route",skillreq={mining=50},levelreq=20},
items={1206},
maps={"Ashenvale"},
},[[
step
map Kalimdor/0
path follow smart; loop on; ants straight; dist 30
path	44.89,34.26	44.33,34.72
map Ashenvale/0
path	16.61,27.89	20.48,28.08	20.00,33.38	16.87,36.59	19.99,41.70
path	19.64,44.86	22.28,49.81	25.73,53.76	30.03,58.81	28.36,63.31
path	31.43,64.91	32.88,70.11	38.79,63.61	42.14,63.26	42.24,68.10
path	44.49,70.63	51.56,74.31	55.59,75.26	55.32,68.67	56.36,64.09
path	58.46,65.61	62.13,64.77	63.83,65.27	65.66,69.02	71.90,71.98
path	75.32,75.93	75.51,69.19	82.44,71.50	81.58,49.07	79.19,47.72
path	76.14,51.73	70.40,54.04	69.08,52.18	65.23,55.56	66.82,47.07
path	64.33,43.71	61.84,42.80	59.00,37.01	57.53,30.19	54.73,33.28
path	54.27,36.64	56.34,40.95	60.51,46.50	53.44,48.07	48.22,46.33
path	45.28,47.32	43.45,41.62	41.73,40.62	41.32,36.20	36.59,36.37
path	38.26,30.49	33.33,28.17	32.75,21.40	25.66,19.01	20.89,19.16
click Tin Vein##1732+
click Silver Vein##1733+
Click ore as you follow the path around this area
|tip Track them on your minimap with "Find Minerals".
|tip You will need level 50 Mining to collect these.
collect Moss Agate##1206 |n
|tip These are a rare drop from Tin and Silver Ore nodes.
'|confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Mining\\Farming Guides\\Iron Ore")
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Mining\\Farming Guides\\Heavy Stone",{
mopready=true,
meta={goldtype="route",skillreq={mining=1},levelreq=30},
items={2838},
maps={"Feralas"},
},[[
step
map Feralas/0
path	follow loose; loop on; ants curved; dist 20
path	84.90,39.90	81.80,39.30	79.20,37.20
path	75.30,35.50	71.50,34.70	68.40,39.70
path	68.10,46.10	70.00,48.60	68.70,52.00
path	65.50,52.50	63.80,54.90	61.50,50.50
path	58.20,51.40	53.80,49.40	48.60,44.00
path	48.60,38.80	49.70,34.90	51.60,33.80
path	49.50,26.10	51.70,25.50	51.30,19.00
path	52.70,16.50	54.90,8.10	53.40,5.50
path	51.60,4.80	48.50,11.50	46.10,7.20
path	42.00,8.20	40.00,7.70	37.10,12.10
path	38.20,18.60	37.00,25.60	41.20,25.50
path	41.50,17.20	45.20,21.10	46.00,15.70
path	47.70,22.10	46.20,26.60	47.20,34.70
path	46.70,44.90	50.30,52.70	54.80,53.90
path	55.00,59.80	54.60,64.00	52.90,66.20
path	53.60,73.70	55.50,75.70	61.50,75.00
path	61.60,68.90	64.00,68.90	61.90,66.20
path	61.00,59.10	64.10,58.70	63.70,61.00
path	65.80,63.50	68.10,61.50	71.60,65.10
path	77.20,62.10	75.90,53.50	76.20,49.60
path	79.50,46.20	84.00,45.60	82.50,43.10
click Iron Deposit##1735+
|tip Track them on your minimap with "Find Minerals".
|tip You will need level 100 Mining to collect these.
collect Heavy Stone##2838 |n
'|confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Mining\\Farming Guides\\Gold Ore")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Mining\\Farming Guides\\Mithril Ore")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Mining\\Farming Guides\\Solid Stone")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Mining\\Farming Guides\\Truesilver Ore")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Mining\\Farming Guides\\Dark Iron Ore")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Mining\\Farming Guides\\Thorium Ore")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Mining\\Farming Guides\\Dense Stone")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Mining\\Farming Guides\\Guardian Stone")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Green Whelp Scale")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Black Whelp Scale")
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Skinning\\Farming Guides\\Ruined Leather Scraps",{
mopready=true,
meta={goldtype="route",skillreq={skinning=1},levelreq=1},
items={2934},
maps={"Elwynn Forest"},
},[[
step
kill Stonetusk Boar##113+
|tip Skin their corpses.
collect Ruined Leather Scraps##2934 |n |goto Elwynn Forest/0 41.58,86.96
'|confirm
]])
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Skinning\\Farming Guides\\Light Leather",{
mopready=true,
meta={goldtype="route",skillreq={skinning=1},levelreq=1},
items={2318},
maps={"Elwynn Forest"},
},[[
step
kill Stonetusk Boar##113+
|tip Skin their corpses.
collect Light Leather##2318 |n |goto Elwynn Forest/0 41.58,86.96
'|confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Slimy Murloc Scale")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Medium Hide")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Heavy Leather")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Raptor Hide")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Heavy Hide")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Turtle Scale")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Thick Murloc Scale")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Thick Leather")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Thick Hide")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Worn Dragonscale")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Scorpid Scale")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Devilsaur Leather")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Rugged Leather")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Green Dragonscale")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Rugged Hide")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Black Dragonscale")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Heavy Scorpid Scale")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Light Hide")
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Skinning\\Farming Guides\\Medium Leather",{
mopready=true,
meta={goldtype="route",skillreq={skinning=1},levelreq=20},
items={2319},
maps={"Hillsbrad Foothills"},
},[[
step
Kill Yeti enemies around this area
|tip Skin their corpses.
|tip You can find more inside the cave.
collect Medium Leather##2319 |n |goto Hillsbrad Foothills/0 46.64,54.41
'|confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Skinning\\Farming Guides\\Warbear Leather")
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Tailoring\\Farming Guides\\Linen Cloth",{
mopready=true,
meta={goldtype="route",levelreq=10},
items={2589},
maps={"Westfall"},
},[[
step
Kill enemies around this area
|tip Be sure to enter the mine as well.
collect Linen Cloth##2589 |n |goto Westfall/0 44.55,25.01
'|confirm
]])
ZygorGuidesViewer:RegisterGuide("Profession Guides\\Tailoring\\Farming Guides\\Wool Cloth",{
mopready=true,
meta={goldtype="route",levelreq=15},
items={2592},
maps={"Redridge Mountains"},
},[[
step
Kill Blackrock enemies around this area
collect Wool Cloth##2592 |n |goto Redridge Mountains/0 33.50,12.42
You can find more inside the cave at [31.45,9.43]
'|confirm
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Tailoring\\Farming Guides\\Mageweave Cloth")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Tailoring\\Farming Guides\\Runecloth")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Tailoring\\Farming Guides\\Felcloth")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Tailoring\\Farming Guides\\Spider's Silk")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Tailoring\\Farming Guides\\Shadow Silk")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Tailoring\\Farming Guides\\Ironweb Spider Silk")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Dropped\\Farming Guides\\Demonic Rune")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Dropped\\Farming Guides\\Sharp Claw")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Dropped\\Farming Guides\\Small Venom Sac")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Dropped\\Farming Guides\\Huge Venom Sac")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Dropped\\Farming Guides\\Iridescent Pearl")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Dropped\\Farming Guides\\Black Pearl")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Dropped\\Farming Guides\\Golden Pearl")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Dropped\\Farming Guides\\Giant Egg")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Dropped\\Farming Guides\\Zesty Clam Meat")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Tailoring\\Farming Guides\\Silk Cloth")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Tailoring\\Farming Guides\\Mooncloth")
ZygorGuidesViewer:RegisterGuidePlaceholder("Profession Guides\\Tailoring\\Farming Guides\\Thick Spider's Silk")
