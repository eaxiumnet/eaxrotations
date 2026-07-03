local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Alliance" then return end
if ZGV:DoMutex("EventsA") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Brewfest Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Brewfest Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Achievements\\Brew of the Month")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Achievements\\Brew of the Year")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Achievements\\Direbrewfest")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Achievements\\Disturbing the Peace")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Achievements\\Does Your Wolpertinger Linger?")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Achievements\\Down With The Dark Iron")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Achievements\\Drunken Stupor")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Achievements\\Have Keg, Will Travel")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Achievements\\Strange Brew")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Achievements\\The Brewfest Diet")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Children's Week Stormwind Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Children's Week Shattrath Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Children's Week Dalaran Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Achievements\\Aw, Isn't It Cute?")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Achievements\\Bad Example")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Achievements\\Daily Chores")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Achievements\\Home Alone")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Achievements\\School of Hard Knocks")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Achievements\\Veteran Nanny")
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Darkmoon Faire Quests",{
condition_suggested=function() return isevent('Darkmoon Faire') end,
description="This guide will help you navigate through the Darkmoon Faire Event",
},[[
step
You can Ride the Roller Coaster or Carousel for a Reputation and Experience Buff
|tip You can purchase a Ride Ticket Book from an NPC near either ride.
|tip Ride the either ride to gain a 10% bonus to your experience and reputation gained for 1 hour.
|tip Leaving the ride before it is finished will diminish the duration of your buff.
|tip You can also get a Darkmoon Top hat from Darkmoon Game Prizes that grants the same buff.
|tip Use these wisely as need to improve your level or faction standing.
confirm
step
talk Darkmoon Faire Mystic Mage##54334
accept The Darkmoon Faire##7905 |goto Stormwind City/0 62.26,72.96
|tip After accepting the quest, you can ask her to teleport you to the Darkmoon Faire.
step
talk Innkeeper Farley##295
|tip Inside the building.
buy 5 Moonberry Juice##1645 |goto Elwynn Forest/0 43.77,65.81 |q 29506 |future
|only if skill("Alchemy") >= 1
step
talk Tharynn Bouden##66
buy 5 Light Parchment##39354 |goto Elwynn Forest/0 41.89,67.08 |q 29515 |future
|only if skill("Inscription") >= 1
step
talk Tharynn Bouden##66
buy 1 Coarse Thread##2320 |goto Elwynn Forest/0 41.89,67.08 |q 29520 |future
buy 1 Blue Dye##6260 |goto Elwynn Forest/0 41.89,67.08 |q 29520 |future
buy 1 Red Dye##2604 |goto Elwynn Forest/0 41.89,67.08 |q 29520 |future
|only if skill("Tailoring") >= 1
step
talk Tharynn Bouden##66
buy 5 Coarse Thread##2320 |goto Elwynn Forest/0 41.89,67.08 |q 29517 |future
buy 5 Blue Dye##6260 |goto Elwynn Forest/0 41.89,67.08 |q 29517 |future
buy 10 Shiny Bauble##6529 |goto Elwynn Forest/0 41.89,67.08 |q 29517 |future
|only if skill("Leatherworking") >= 1
step
talk Tharynn Bouden##66
buy 5 Simple Flour##30817 |goto Elwynn Forest/0 41.89,67.08 |q 29509 |future
|only if skill("Cooking") >= 1
step
clicknpc Darkmoon Strider##68491
Mount the Darkmoon Strider |havebuff Darkmoon Strider##134931 |goto Darkmoon Island/0 51.64,24.67
|only if level < 20
step
talk Zina Sharpworth##55266
buy 1 Sack o' Tokens##78910 |goto Darkmoon Island/0 54.34,53.15 |q 29433 |future |or
use the Sack o' Tokens##78910
collect 20 Darkmoon Faire Game Token##71083 |goto Darkmoon Island/0 54.34,53.15 |q 7905 |or
|tip This will let you play all the games at the faire. You can skip this step if you know you need less tokens.
step
talk Gelvas Grimegate##14828
turnin The Darkmoon Faire##7905 |goto Darkmoon Island/0 47.90,64.74
step
talk Selina Dourman##10445
accept Banners, Banners Everywhere!##29520 |goto Darkmoon Island/0 55.56,55.00
|only if skill("Tailoring") >= 1
step
talk Professor Thaddeus Paleo##14847
accept Fun for the Little Ones##29507 |goto Darkmoon Island/0 51.89,60.93
|only if skill("Archaeology") >= 1
step
talk Rinling##14841
accept Rearm, Reuse, Recycle##29518 |goto Darkmoon Island/0 49.25,60.78
|only if skill("Mining") >= 1
step
talk Rinling##14841
accept Talkin' Tonks##29511 |goto Darkmoon Island/0 49.25,60.78
|only if skill("Engineering") >= 1
step
talk Rinling##14841
accept Eyes on the Prizes##29517 |goto Darkmoon Island/0 49.25,60.78
|only if skill("Leatherworking") >= 1
step
talk Stamp Thunderhorn##14845
accept Putting the Crunch in the Frog##29509 |goto Darkmoon Island/0 52.89,67.94
|only if skill("Cooking") >= 1
step
talk Stamp Thunderhorn##14845
accept Spoilin' for Salty Sea Dogs##29513 |goto Darkmoon Island/0 52.89,67.94
|only if skill("Fishing") >= 1
step
talk Sayge##14822
accept Writing the Future##29515 |goto Darkmoon Island/0 53.23,75.84
|only if skill("Inscription") >= 1
step
talk Chronos##14833
accept Tan My Hide##29519 |goto Darkmoon Island/0 54.99,70.77
|only if skill("Skinning") >= 1
step
talk Chronos##14833
accept Herbs for Healing##29514 |goto Darkmoon Island/0 54.99,70.77
|only if skill("Herbalism") >= 1
step
talk Sylannia##14844
accept A Fizzy Fusion##29506 |goto Darkmoon Island/0 50.53,69.57
|only if skill("Alchemy") >= 1
step
talk Chronos##14833
accept Keeping the Faire Sparkling##29516 |goto Darkmoon Island/0 54.99,70.77
|only if skill("Jewelcrafting") >= 1
step
talk Sayge##14822
accept Putting Trash to Good Use##29510 |goto Darkmoon Island/0 53.23,75.84
|only if skill("Enchanting") >= 1
step
talk Yebb Neblegear##14829
accept Baby Needs Two Pair of Shoes##29508 |goto Darkmoon Island/0 51.10,82.04
|only if skill("Blacksmithing") >= 1
step
use the Plump Frogs##72056
collect 5 Breaded Frog##72057 |q 29509
|only if skill("Cooking") >= 1
step
use the Breaded Frog##72057
|tip Use it five times.
Prepare #5# Crunchy Frogs |q 29509/1 |goto Darkmoon Island/0 52.70,68.10
|only if skill("Cooking") >= 1
step
cast Fishing##7620
|tip Equip a fishing pole if you have one.
collect 5 Great Sea Herring##73269 |q 29513/1 |goto Darkmoon Island/0 51.74,91.31
|only if skill("Fishing") >= 1
step
click Discarded Weapon##209283+
|tip They look like sparkling piles of rubble on the ground around this area.
collect 6 Discarded Weapon##72018 |goto Darkmoon Island/0 49.47,71.33 |q 29510
|only if skill("Enchanting") >= 1
step
use the Discarded Weapon##72018
|tip Use it six times.
collect 6 Soothsayer's Dust##71979 |q 29510/1
|only if skill("Enchanting") >= 1
step
click Tonk Scrap##209275
|tip They look like random pieces of metal on the ground around this area.
collect 6 Tonk Scrap##71968 |q 29518/1 |goto Darkmoon Island/0 49.47,71.33
|only if skill("Mining") >= 1
step
click Bit of Glass##209287+
|tip They look like small green pieces of broken glass on the ground around this area.
|tip You can find these all over the island.
collect 5 Bits of Glass##72052 |goto Darkmoon Island/0 49.47,71.33 |q 29516
|only if skill("Jewelcrafting") >= 1
step
use the Bit of Glass##72052
|tip Use it five times.
collect 5 Sparkling 'Gemstone'##72050 |q 29516/1
|only if skill("Jewelcrafting") >= 1
step
clicknpc Damaged Tonk##54504+
|tip They look like broken Tonk toys on the ground around this area.
use the Battered Wrench##72110
|tip Use it on Damaged Tonks.
Repair #5# Damaged Tonk's |q 29511/1 |goto Darkmoon Island/0 49.47,71.33
|only if skill("Engineering") >= 1
step
click Darkblossom##209284+
|tip They look like small purple flowers on the ground around this area.
|tip You can find these all over the island.
collect 6 Darkblossom##72046 |q 29514/1 |goto Darkmoon Island/0 49.47,71.33
|only if skill("Herbalism") >= 1
step
click Staked Skin##209276+
|tip They look like wooden frames with a hide stretched tight inside on the ground around this area.
|tip You can find these all over the island.
Scrape #4# Staked Skins |q 29519/1 |goto Darkmoon Island/0 49.47,71.33
|only if skill("Skinning") >= 1
step
talk Sylannia##14844
buy 5 Fizzy Faire Drink##19299 |q 29506 |goto Darkmoon Island/0 50.53,69.57
|only if skill("Alchemy") >= 1
step
use the Cocktail Shaker##72043
|tip Use it five times.
Create #5# Servings of Moonberry Fizz |q 29506/1
|only if skill("Alchemy") >= 1
step
cast Survey##80451
|tip Use this ability at Fossil Digsites across Kalimdor.
|tip You can find them in Desolace, Dustwallow Marsh, Stonetalon Mountains, Southern Barrens, Tanaris, and Un'Goro Crater.
earn 15 Fossil Fragments##393 |q 29507
|only if skill("Archaeology") >= 1
step
use the Darkmoon Banner Kit##72048
Plant a Darkmoon Banner |q 29520/1 |goto Darkmoon Island/0 48.65,72.75
|only if skill("Tailoring") >= 1
step
use the Iron Stock##71964
|tip Use it next to the Forge.
collect 4 Horseshoes##71967 |q 29508 |goto Darkmoon Island/0 55.12,71.56
|only if skill("Blacksmithing") >= 1
step
use Horseshoe##71967
Put New Horshoes On Baby |q 29508/1 |goto Darkmoon Island/0 51.30,81.80
|only if skill("Blacksmithing") >= 1
step
use the Bundle of Exotic Herbs##71971
collect Prophetic Ink##71972 |q 29515
|only if skill("Inscription") >= 1
step
use Prophetic Ink##71972
|tip Each Fortune requires 1 Light Parchment to create.
|tip Use it five times.
collect 5 Fortune##71974 |q 29515/1
|only if skill("Inscription") >= 1
step
use the Darkmoon Craftsman's Kit##71977
|tip Use it five times.
collect 5 Darkmoon Prize##71976 |q 29517/1
|only if skill("Leatherworking") >= 1
step
talk Stamp Thunderhorn##14845
turnin Putting the Crunch in the Frog##29509 |goto Darkmoon Island/0 52.89,67.94
|only if skill("Cooking") >= 1
step
talk Professor Thaddeus Paleo##14847
turnin Fun for the Little Ones##29507 |goto Darkmoon Island/0 51.89,60.93
|only if skill("Archaeology") >= 1
step
talk Stamp Thunderhorn##14845
turnin Spoilin' for Salty Sea Dogs##29513 |goto Darkmoon Island/0 52.89,67.94
|only if skill("Fishing") >= 1
step
talk Selina Dourman##10445
turnin Banners, Banners Everywhere!##29520 |goto Darkmoon Island/0 55.56,55.00
|only if skill("Tailoring") >= 1
step
talk Sayge##14822
turnin Writing the Future##29515 |goto Darkmoon Island/0 53.23,75.84
|only if skill("Inscription") >= 1
step
talk Chronos##14833
turnin Tan My Hide##29519 |goto Darkmoon Island/0 54.99,70.77
|only if skill("Skinning") >= 1
step
talk Chronos##14833
turnin Keeping the Faire Sparkling##29516 |goto Darkmoon Island/0 54.99,70.77
|only if skill("Jewelcrafting") >= 1
step
talk Rinling##14841
turnin Eyes on the Prizes##29517 |goto Darkmoon Island/0 49.25,60.78
|only if skill("Leatherworking") >= 1
step
talk Rinling##14841
turnin Talkin' Tonks##29511 |goto Darkmoon Island/0 49.25,60.78
|only if skill("Engineering") >= 1
step
talk Chronos##14833
turnin Herbs for Healing##29514 |goto Darkmoon Island/0 54.99,70.77
|only if skill("Herbalism") >= 1
step
talk Sylannia##14844
turnin A Fizzy Fusion##29506 |goto Darkmoon Island/0 50.53,69.57
|only if skill("Alchemy") >= 1
step
talk Rinling##14841
turnin Rearm, Reuse, Recycle##29518 |goto Darkmoon Island/0 49.25,60.78
|only if skill("Mining") >= 1
step
talk Sayge##14822
turnin Putting Trash to Good Use##29510 |goto Darkmoon Island/0 53.23,75.84
|only if skill("Enchanting") >= 1
step
talk Yebb Neblegear##14829
turnin Baby Needs Two Pair of Shoes##29508 |goto Darkmoon Island/0 51.10,82.04
|only if skill("Blacksmithing") >= 1
step
talk Kerri Hicks##14832
accept Test Your Strength##29433 |goto Darkmoon Island/0 47.90,67.12
step
talk Selina Dourman##10445
Select _"Darkmoon Adventurer's Guide?"_
collect 1 Darkmoon Adventurer's Guide##71634 |goto Darkmoon Island/0 55.56,55.00 |q 29433
|only if haveq(29433)
step
Kill enemies or players anywhere
|tip Only enemies and players that yield experience or honor will award Grisly Trophies.
|tip You will need to keep the Darkmoon Adventurer's Guide in your inventory.
|tip You can kill these anywhere you choose.
|tip We recommend passively completeing this quest while doing other activities in the game.
collect 250 Grisly Trophy##71096 |q 29433/1
|only if haveq(29433)
step
talk Kerri Hicks##14832
turnin Test Your Strength##29433 |goto Darkmoon Island/0 47.90,67.12
step
Kill enemies in dungeons
|tip Darkmoon dungeon items can be dropped by trash mobs and bosses from appropriate level dungeons.
|tip Appropriate dungeons are those that still yield experience or those that are max level.
|tip You will need to keep the Darkmoon Adventurer's Guide in your inventory.
Collect the Five Darkmoon Dungeon Items |complete completedq(29445) and completedq(29444) and completedq(29451) and completedq(29446) and completedq(29443)
|tip You still need to collect the following items: |only if not completedq(29445) and not completedq(29444) and not completedq(29451) and not completedq(29446) and not completedq(29443)
|tip Mysterious Grimoire |only if not completedq(29445)
|tip Monstrous Egg |only if not completedq(29444)
|tip A Treatise on Strategy |only if not completedq(29451)
|tip Ornate Weapon |only if not completedq(29446)
|tip Imbued Crystal |only if not completedq(29443)
step
use the Mysterious Grimoire##71637
accept An Inriguing Grimoire##29445
step
talk Sayge##14822
turnin An Intriguing Grimoire##29445 |goto Darkmoon Island/0 53.23,75.84
step
use the Monstrous Egg##71636
accept An Exotic Egg##29444
step
talk Yebb Neblegear##14829
turnin An Exotic Egg##29444 |goto Darkmoon Island/0 51.10,82.04
step
use A Treatise on Strategy##71715
accept The Master Strategist##29451
step
use the Ornate Weapon##71638
accept A Wondrous Weapon##29446
step
use the Imbued Crystal##71635
accept A Curious Crystal##29443
step
talk Professor Thaddeus Paleo##14847
turnin The Master Strategist##29451 |goto Darkmoon Island/0 51.89,60.93
turnin A Wondrous Weapon##29446 |goto Darkmoon Island/0 51.89,60.93
turnin A Curious Crystal##29443 |goto Darkmoon Island/0 51.89,60.93
step
Kill enemies in raids
|tip This item can be dropped by trash mobs and bosses from appropriate level raids.
|tip Appropriate raids are those that still yield experience or those that are max level.
|tip You will need to keep the Darkmoon Adventurer's Guide in your inventory.
collect Soothsayer's Runes##71716 |q 29464 |future
step
use the Soothsayer's Runes##71716
accept Tools of Divination##29464
step
talk Professor Thaddeus Paleo##14847
turnin Tools of Divination##29464 |goto Darkmoon Island/0 51.89,60.93
step
Kill enemies in Battlegrounds
|tip Darkmoon Battleground items can be dropped by trash mobs and enemy players from PvP Battlegrounds.
|tip You will need to keep the Darkmoon Adventurer's Guide in your inventory.
|tip Loot the bodies for a chance to pick up a Darkmoon Faire quest item.
Collect the Three Darkmoon Battleground Items |complete completedq(29458) and completedq(29456) and completedq(29457)
|tip You still need to collect the following items: |only if not completedq(29458) and not completedq(29456) and not completedq(29457)
|tip Fallen Adventurer's Journal |only if not completedq(29458)
|tip Banner of the Fallen |only if not completedq(29456)
|tip Captured Insignia |only if not completedq(29457)
step
use the Adventurer's Journal##71953
accept The Captured Journal##29458
step
use the Banner of the Fallen##71951
accept A Captured Banner##29456
step
use the Captured Insignia##71952
accept The Enemy's Insignia##29457
step
talk Professor Thaddeus Paleo##14847
turnin The Captured Journal##29458 |goto Darkmoon Island/0 51.89,60.93
turnin A Captured Banner##29456 |goto Darkmoon Island/0 51.89,60.93
turnin The Enemy's Insignia##29457 |goto Darkmoon Island/0 51.89,60.93
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Darkmoon Faire Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Taking the Show on the Road")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Fairegoer's Feast")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Come One, Come All!")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Blastenheimer Bullseye")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Darkmoon Defender")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Darkmoon Dungeoneer")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Darkmoon Despoiler")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Faire Favors")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Taking this Show on the Road")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\I Was Promised a Pony")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Quick Shot")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Step Right Up")
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Hallow's End Quests",{
mopready=true,
condition_end=function() return completedq(8373) end,
description="Complete the quests for the Hallow's End event.",
patch='40405',
},[[
step
Reach Level 10 |ding 10
|tip You must be at least level 10 to be able to accept these quests.
|tip Use the Leveling guides to accomplish this.
step
talk Human Commoner##18927
accept A Season for Celebration##29074 |goto Stormwind City/0 61.68,74.18
accept Costumed Orphan Matron##11356 |goto Stormwind City/0 61.68,74.18
step
talk Celestine of the Harvest##51665
turnin A Season for Celebration##29074 |goto Elwynn Forest/0 32.04,50.51
step
talk Jesper##15310
accept Hallow's End Treats for Jesper!##8311 |goto Elwynn Forest/0 32.03,50.39
step
talk Gretchen Fenlow##51934
accept A Friend in Need##29430 |goto Elwynn Forest/0 32.35,50.88
step
click Candy Bucket
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
accept Candy Bucket##12336 |goto Stormwind City/0 60.51,75.33
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
step
talk Innkeeper Allison##6740
|tip Inside the building.
accept Flexing for Nougat##8356 |goto Stormwind City/0 60.39,75.28 |complete completedq(8311) or completedq(8356)
step
clicknpc Innkeeper Allison##6740
|tip Inside the building.
|tip Target Innkeeper Allison and type "/flex" into your chat to perform the Flex emote.
Flex for Inkeeper Allison |q 8356/1 |goto Stormwind City/0 60.39,75.28 |complete completedq(8311) or completedq("8356/1")
'|script DoEmote("FLEX")
step
talk Innkeeper Allison##6740
|tip Inside the building.
turnin Flexing for Nougat##8356 |goto Stormwind City/0 60.39,75.28 |complete completedq(8311) or completedq(8356)
step
collect Stormwind Nougat##20492 |q 8311/1
|tip Save this, you will need it later.
step
talk Anson Hastings##53949
|tip Inside the building.
turnin A Friend in Need##29430 |goto Stormwind City/0 60.04,75.13
accept Missing Heirlooms##29392 |goto Stormwind City/0 60.04,75.13
step
Search the Courier's Cabin |q 29392/1 |goto Stormwind City/0 24.03,44.81
|tip Downstairs inside the middle deck of the ship.
step
talk Hired Courier##53950
|tip Downstairs inside the middle deck of the ship.
turnin Missing Heirlooms##29392 |goto Stormwind City/0 24.04,44.82
accept Fencing the Goods##29398 |goto Stormwind City/0 24.04,44.82
step
talk Auctioneer Fitch##8719
Select _"Has anyone suspicious tried to list a crate of goods recently?"_ |gossip 113772
Watch the dialogue
Follow the Thief's Trail |q 29398/1 |goto Stormwind City/0 61.11,70.62
step
talk Auctioneer Fitch##8719
turnin Fencing the Goods##29398 |goto Stormwind City/0 61.11,70.62
accept Shopping Around##29399 |goto Stormwind City/0 61.11,70.62
step
Watch the dialogue
|tip Inside the building.
Investigate the Shady Lady |q 29399/1 |goto Stormwind City/0 64.17,46.29
step
talk Hudson Barnes##54021
turnin Shopping Around##29399 |goto Stormwind City/0 64.17,46.29
accept Taking Precautions##29402 |goto Stormwind City/0 64.17,46.29
step
click Blood Nettle##209059+
|tip They look like red and white plants on the ground around this area.
|tip They appear on you minimap as yellow dots.
collect 5 Blood Nettle##71035 |q 29402/3 |goto Stormwind City/0 54.32,14.82
step
talk Keldric Boucher##1257
|tip Inside the building.
Select _"I want to browse your goods."_ |gossip 87621
buy 5 Crystal Vial##3371 |q 29402/1 |goto Stormwind City/0 62.79,75.05
buy 5 Arcane Powder##17020 |q 29402/2 |goto Stormwind City/0 62.79,75.05
step
talk Hudson Barnes##54021
|tip Inside the building.
turnin Taking Precautions##29402 |goto Stormwind City/0 64.17,46.29
accept The Collector's Agent##29403 |goto Stormwind City/0 64.17,46.29
step
Enter the building |goto Stormwind City/0 52.93,50.96 < 7 |walk
Run down the ramp |goto Stormwind City/0 51.24,44.20 < 7 |walk
|tip Follow the little purple spiders downstairs and to the left.
Watch the dialogue
kill Unleashed Void##54114
|tip It will spawn after the dialogue down in the lowest part of the cathedral catacombs.
Disrupt the Meeting |q 29403/1 |goto Stormwind City/0 55.48,43.30
step
click Stolen Crate##209072
|tip In the lowest part of the cathedral catacombs.
turnin The Collector's Agent##29403 |goto Stormwind City/0 55.39,43.41
accept What Now?##29411 |goto Stormwind City/0 55.39,43.41
step
talk Hudson Barnes##54118
|tip Inside the building.
turnin What Now?##29411 |goto Stormwind City/0 65.17,33.47
step
click Anson's Crate##209076
|tip Inside the building.
accept The Creepy Crate##29413 |goto Stormwind City/0 65.07,33.52
step
talk Costumed Orphan Matron##24519
turnin Costumed Orphan Matron##11356 |goto Elwynn Forest/0 42.62,64.39
accept Fire Brigade Practice##11360 |goto Elwynn Forest/0 42.62,64.39
step
click Water Barrel |goto Elwynn Forest/0 42.51,64.49
|tip Click the Water Barrel to pick up a bucket of water.
collect Water Bucket##32971 |n
use the Water Bucket##32971
|tip Throw the buckets at the fires on top of buildings around this area.
|tip You may have to wait a short amount of time for the Horseman to attack.
Put Out #5# Fires |q 11360/1 |goto Elwynn Forest/0 42.43,65.63
step
talk Large Jack-O'-Lantern
accept Smash the Pumpkin##12133 |goto Elwynn Forest/0 42.39,65.87
|tip This will only be available after the Headless Horseman is defeated.
|tip You can skip this step if it does not drop.
|only if not completedq(8311)
step
click Candy Bucket
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
accept Candy Bucket##12286 |goto Elwynn Forest/0 43.74,65.89
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
step
talk Costumed Orphan Matron##24519
turnin Fire Brigade Practice##11360 |goto Elwynn Forest/0 42.62,64.39
turnin Smash the Pumpkin##12133 |goto Elwynn Forest/0 42.62,64.39 |only if haveq(12133) or completedq(12133)
step
Enter the building |goto Ironforge/0 20.57,53.22 < 5 |walk
talk Innkeeper Firebrew##5111
|tip Inside the building.
accept Chicken Clucking for a Mint##8353 |goto Ironforge/0 18.16,51.44 |complete completedq(8311) or completedq(8353)
step
clicknpc Innkeeper Firebrew##5111
|tip Inside the building.
|tip Target Innkeeper Firebrew and type "/chicken" into your chat to perform the Chicken emote.
Cluck Like a Chicken for Innkeeper Firebrew |q 8353/1 |goto Ironforge/0 18.16,51.44 |complete completedq(8311) or completedq("8353/1")
'|script DoEmote("CHICKEN")
step
talk Innkeeper Firebrew##5111
|tip Inside the building.
turnin Chicken Clucking for a Mint##8353 |goto Ironforge/0 18.16,51.44 |complete completedq(8311) or completedq(8353)
step
collect Ironforge Mint##20490 |q 8311/3
|tip Save this, you will need it later.
step
click Candy Bucket
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
accept Candy Bucket##12335 |goto Ironforge/0 18.36,50.94
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
step
talk Talvash del Kissel##6826
accept Incoming Gumdrop##8355 |goto Ironforge/0 36.38,3.62 |complete completedq(8311) or completedq(8355)
step
clicknpc Talvash del Kissel##6826
|tip Target Talvash del Kissel and type "/train" into your chat to perform the Train emote.
Do the "Train" for Talvash |q 8355/1 |goto Ironforge/0 36.38,3.62 |complete completedq(8311) or completedq("8355/1")
'|script DoEmote("TRAIN")
step
talk Talvash del Kissel##6826
turnin Incoming Gumdrop##8355 |goto Ironforge/0 36.38,3.62 |complete completedq(8311) or completedq(8355)
step
collect Gnomeregan Gumdrop##20494 |q 8311/2
|tip Save this, you will need it later.
step
talk Innkeeper Saelienne##6735
accept Dancing for Marzipan##8357 |goto Darnassus/0 62.52,32.79 |complete completedq(8311) or completedq(8357)
step
clicknpc Innkeeper Saelienne##6735
|tip Target Innkeeper Saelienne and type "/dance" into your chat to perform the Dance emote.
Dance for Inkeeper Saelienne |q 8357/1 |goto Darnassus/0 62.52,32.79 |complete completedq(8311) or completedq("8357/1")
'|script DoEmote("DANCE")
step
talk Innkeeper Saelienne##6735
turnin Dancing for Marzipan##8357 |goto Darnassus/0 62.52,32.79 |complete completedq(8311) or completedq(8357)
step
collect Darnassus Marzipan##20496 |q 8311/4
|tip Save this, you will need it later.
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
accept Candy Bucket##12334 |goto Darnassus/0 62.27,33.15
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
step
talk Jesper##15310
|tip Inside the building.
turnin Hallow's End Treats for Jesper!##8311 |goto Elwynn Forest/0 32.03,50.39
|next "Events Guides\\Hallow's End\\Hallow's End Daily Quests"
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Hallow's End Daily Quests",{
mopready=true,
description="Put out fires in Razor Hill and kill the Headless Horseman.",
patch='40405',
},[[
step
label "Begin_Dailies"
talk Human Commoner##18927
accept Costumed Orphan Matron##11356 |goto Stormwind City/0 61.76,74.15
step
talk Celestine of the Harvest##51665
accept A Time to Gain##29075 |goto Elwynn Forest/0 32.04,50.51
step
talk Keira##52064
accept A Time to Lose##29371 |goto Elwynn Forest/0 32.08,50.60
step
talk Gretchen Fenlow##51934
accept Stink Bombs Away!##29054 |goto Elwynn Forest/0 32.35,50.88
accept Clean Up in Stormwind##29144 |goto Elwynn Forest/0 32.35,50.88
step
talk Gertrude Fenlow##52548
Select _"I'm ready to fly, let's bomb the Undercity!"_ |gossip 113573
Begin Your Flight to Undercity |invehicle |goto Elwynn Forest/0 32.21,50.77 |q 29054
step
Reach Undercity |complete zone("Undercity") or completedq(29054)
step
Drop #25# Bombs |q 29054/1 |goto Elwynn Forest/0 32.21,50.77
|tip Use the {o}Toss Stink Bomb{} ability on your vehicle bar to drop bombs across Undercity.
|tip You can drop them anywhere.
|tip If you're feeling kind, focus on dropping them in areas where Horde players can easily remove them later.
step
Return to Elwynn Forest |complete zone("Elwynn Forest") or zone("Stormwind City") or completedq(29054)
|tip Use the {o}Return Home{} button on your vehicle bar.
step
click Bonfire
Use the Bonfire |q 29075/1 |goto Elwynn Forest/0 32.86,49.37
step
use the Arcane Cleanser##69191
|tip Use it all over Stormwind City on large orange clouds of smoke coming from the ground.
Remove #10# Stink Bombs |q 29144/1 |goto Stormwind City/0 57.58,63.42
step
talk Celestine of the Harvest##51665
turnin A Time to Gain##29075 |goto Elwynn Forest/0 32.04,50.51
step
talk Gretchen Fenlow##51934
turnin Stink Bombs Away!##29054 |goto Elwynn Forest/0 32.35,50.88
turnin Clean Up in Stormwind##29144 |goto Elwynn Forest/0 32.35,50.88
step
talk Costumed Orphan Matron##24519
turnin Costumed Orphan Matron##11356 |goto Elwynn Forest/0 42.62,64.39
step
talk Costumed Orphan Matron##24519
accept Stop the Fires!##11131 |goto Elwynn Forest/0 42.62,64.39 |or
accept "Let the Fires Come!"##12135 |goto Elwynn Forest/0 42.62,64.39 |or
|tip You will only be able to accept one of these quests.
|tip The quest offered depends on whether Goldshire is under attack or not.
step
click Water Barrel |goto Elwynn Forest/0 42.51,64.49
|tip Click the Water Barrel to pick up a bucket of water.
collect Water Bucket##32971 |n
use the Water Bucket##32971
|tip Throw the buckets at the fires on top of buildings around this area.
Put Out the Fires |q 11131/1 |goto Elwynn Forest/0 42.43,65.63
|only if haveq(11131) or completedq(11131)
step
click Water Barrel |goto Elwynn Forest/0 42.51,64.49
|tip Click the Water Barrel to pick up a bucket of water.
collect Water Bucket##32971 |n
use the Water Bucket##32971
|tip Throw the buckets at the fires on top of buildings around this area.
Put Out the Fires |q 12135/1 |goto Elwynn Forest/0 42.43,65.63
|only if haveq(12135) or completedq(12135)
step
talk Large Jack-O'-Lantern
accept Smash the Pumpkin##12133 |goto Elwynn Forest/0 42.39,65.87
|tip This will only be available after the Headless Horseman is defeated.
step
talk Costumed Orphan Matron##24519
turnin Stop the Fires!##11131 |goto Elwynn Forest/0 42.62,64.39 |only if haveq(11131) or completedq(11131) |or
turnin "Let the Fires Come!"##12135 |goto Elwynn Forest/0 42.62,64.39 |only if haveq(12135) or completedq(12135) |or
turnin Smash the Pumpkin##12133 |goto Elwynn Forest/0 42.62,64.39 |only if haveq(12133) or completedq(12133)
step
use Dousing Agent##68648
Douse the Horde's Wickerman |q 29371/1 |goto Tirisfal Glades/0 62.37,68.20
step
talk Keira##52064
turnin A Time to Lose##29371 |goto Elwynn Forest/0 32.08,50.60
step
Reach Level 75 |ding 75 |or
|tip You must be at least level 75 to be able to kill the Headless Horseman.
|tip Use the Leveling guides to accomplish this.
'|complete not completedq(11131,12135,11404) |next "Begin_Dailies" |or
step
click Pumpkin Shrine
|tip It's in the courtyard of the Scarlet Monastery Graveyard dungeon.
|tip You will need a full group for this.
accept Call the Headless Horseman##11404 |or
'|complete not completedq(11131,12135,11404) |next "Begin_Dailies" |or
step
click Loosely Turned Soil
|tip In front of the crypt behind the Pumpkin Shine.
kill Headless Horseman##23682
|tip He will fly down shortly after disturbing the soil.
|tip When he reaches 1% health, his head will fly off.
|tip Burn the head down to make it rejoin his body.
|tip You will need to do this twice.
|tip After the second time, he will start spawning 4 pumpkins every 30 seconds.
|tip Group them up and AoE them down.
|tip Kill his head the third time it separates to defeat him.
confirm |or
'|complete not completedq(11131,12135,11404) |next "Begin_Dailies" |or
step
click Pumpkin Shrine
turnin Call the Headless Horseman##11404 |or
'|complete not completedq(11131,12135,11404) |next "Begin_Dailies" |or
step
You have completed the availble daily quests for Hallow's End
|tip This guide will reset when more become available.
'|complete not completedq(11131,12135,11404) |next "Begin_Dailies" |or
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Hallow's End Candy Buckets",{
mopready=true,
description="Visit innkeeper candy buckets in Eastern Kingdoms, Kalimdor, and Outland "..
"for tasty treats.",
achieveid={971,963,969,966,5836,5837,7601},
patch='40405',
},[[
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12336 |goto Stormwind City/0 60.52,75.32
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12286 |goto Elwynn Forest/0 43.74,65.89
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12342 |goto Redridge Mountains/0 26.47,41.50
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28955 |goto Badlands/0 65.86,35.65
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28956 |goto Badlands/0 20.86,56.31
step
click Candy Bucket##208144
|tip It's on the top level of the tower.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28965 |goto Searing Gorge/0 39.49,66.04
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12332 |goto Dun Morogh/0 54.49,50.77
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12335 |goto Ironforge/0 18.34,50.97
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12339 |goto Loch Modan/0 35.54,48.49
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28963 |goto Loch Modan/0 83.02,63.53
step
click Candy Bucket##208144
|tip It's on the bottom floor.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28980 |goto Twilight Highlands/0 79.48,78.54
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28977 |goto Twilight Highlands/0 60.35,58.24
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28979 |goto Twilight Highlands/0 43.50,57.27
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28978 |goto Twilight Highlands/0 49.60,30.36
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12343 |goto Wetlands/0 10.82,60.96
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28990 |goto Wetlands/0 26.07,25.99
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28991 |goto Wetlands/0 58.21,39.20
step
click Candy Bucket##208144
|tip It's inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28954 |goto Arathi Highlands/0 40.06,49.09
step
click Candy Bucket##208144
|tip Upstairs inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12351 |goto The Hinterlands/0 14.19,44.60
step
click Candy Bucket##208144
|tip It's inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28970 |goto The Hinterlands/0 66.16,44.43
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12402 |goto Eastern Plaguelands/0 75.57,52.31
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28988 |goto Western Plaguelands/0 43.39,84.38
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12340 |goto Westfall/0 52.91,53.74
If you do not find the Candy Bucket here then it will be located at [56.79,47.27]
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12344 |goto Duskwood/0 73.80,44.26
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28968 |goto Swamp of Sorrows/0 28.93,32.40
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28967 |goto Swamp of Sorrows/0 71.65,14.10
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28960 |goto Blasted Lands/0 60.69,14.08
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28961 |goto Blasted Lands/0 44.35,87.59
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28964 |goto Northern Stranglethorn/0 53.16,66.98
step
click Candy Bucket##208144
|tip It's on the bottom floor of the tavern.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12397 |goto The Cape of Stranglethorn/0 40.91,73.72
step
Ride the Boat to The Barrens |complete zone("The Barrens") or completedq(12396) |goto The Cape of Stranglethorn/0 38.94,66.96
|tip Wait for the boat to take you to Kalimdor.
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12396 |goto The Barrens/0 67.33,74.66
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29006 |goto Southern Barrens/0 39.01,10.99
step
click Candy Bucket##208144
|tip It's inside the base of the tower.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29007 |goto Southern Barrens/0 65.60,46.54
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29008 |goto Southern Barrens/0 49.05,68.50
step
click Candy Bucket##208144
|tip It's inside the inn on the second floor.
|tip If the city is a crater, you can skip this or talk to Zidormi in the pillar of light at the entrance to the city crater to see the old version.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12349 |goto Dustwallow Marsh/0 66.60,45.28
step
click Candy Bucket##208144
|tip It's inside the inn on the second floor.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12398 |goto Dustwallow Marsh/0 41.86,74.09
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12399 |goto Tanaris/0 52.56,27.10
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29014 |goto Tanaris/0 55.70,60.96
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29017 |goto Uldum/0 54.68,33.01
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29018 |goto Un'Goro Crater/0 55.27,62.11
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29016 |goto Uldum/0 26.59,7.23
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12401 |goto Silithus/0 55.47,36.78
step
click Candy Bucket##208144
|tip It's inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12350 |goto Feralas/0 46.33,45.19
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28952 |goto Feralas/0 51.07,17.82
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28993 |goto Desolace/0 56.72,50.13
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12348 |goto Desolace/0 66.33,6.59
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29010 |goto Stonetalon Mountains/0 71.02,79.08
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29011 |goto Stonetalon Mountains/0 59.05,56.33
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29013 |goto Stonetalon Mountains/0 31.53,60.66
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29012 |goto Stonetalon Mountains/0 39.48,32.81
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12345 |goto Ashenvale/0 37.01,49.26
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29000 |goto Mount Hyjal/0 18.63,37.32
step
click Candy Bucket##208144
|tip It's under the ramp.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29001 |goto Mount Hyjal/0 42.68,45.71
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28999 |goto Mount Hyjal/0 63.05,24.14
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12400 |goto Winterspring/0 59.83,51.21
step
click Candy Bucket##208144
|tip It's inside the big tree.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28995 |goto Felwood/0 61.86,26.71
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28994 |goto Felwood/0 44.58,28.98
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28951 |goto Darkshore/0 50.79,18.89
step
Go up the ramp |goto The Exodar/0 56.38,31.15 < 15 |walk
click Candy Bucket##208144
|tip Inside the building inside The Exodar.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12337 |goto The Exodar/0 59.23,18.48
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12333 |goto Azuremyst Isle/0 48.49,49.05
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12341 |goto Bloodmyst Isle/0 55.69,59.96
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12334 |goto Darnassus/0 62.27,33.15
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12331 |goto Teldrassil/0 55.36,52.29
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12404 |goto Shattrath City/0 56.31,81.95
only if rep ('The Scryers')>=Neutral
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12404 |goto Shattrath City/0 28.23,49.07
only if rep ('The Aldor')>=Neutral
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12357 |goto Nagrand/0 54.19,75.88
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12356 |goto Terokkar Forest/0 56.60,53.22
step
click Candy Bucket##208144
|tip It's inside the inn back in the corner.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12360 |goto Shadowmoon Valley/0 37.01,58.29
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12409 |goto Shadowmoon Valley/0 56.37,59.82
only if rep ('The Scryers')>=Neutral
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12409 |goto Shadowmoon Valley/0 61.00,28.17
only if rep ('The Aldor')>=Neutral
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12352 |goto Hellfire Peninsula/0 54.27,63.66
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12353 |goto Hellfire Peninsula/0 23.42,36.38
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12403 |goto Zangarmarsh/0 78.45,62.88
step
click Candy Bucket##208144
|tip It's inside the inn atop the giant mushroom.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12354 |goto Zangarmarsh/0 67.16,48.94
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12355 |goto Zangarmarsh/0 41.90,26.17
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12358 |goto Blade's Edge Mountains/0 35.83,63.74
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12359 |goto Blade's Edge Mountains/0 61.05,68.08
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12406 |goto Blade's Edge Mountains/0 62.90,38.33
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12407 |goto Netherstorm/0 32.02,64.44
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12408 |goto Netherstorm/0 43.31,36.10
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13436 |goto Borean Tundra/0 58.52,67.87
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13460 |goto Borean Tundra/0 78.45,49.16
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13437 |goto Borean Tundra/0 57.12,18.81
step
click Candy Bucket##208144
|tip It's under the tent.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12950 |goto Sholazar Basin/0 26.61,59.20
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13438 |goto Dragonblight/0 28.95,56.22
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13459 |goto Dragonblight/0 48.12,74.66
step
click Candy Bucket##208144
|tip It's on the bottom floor.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13456 |goto Dragonblight/0 60.15,53.45
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13439 |goto Dragonblight/0 77.50,51.28
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12944 |goto Grizzly Hills/0 31.94,60.22
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12945 |goto Grizzly Hills/0 59.64,26.36
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13435 |goto Howling Fjord/0 60.47,15.90
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13433 |goto Howling Fjord/0 58.32,62.82
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13434 |goto Howling Fjord/0 30.83,41.43
step
click Candy Bucket##208144
|tip It's inside the underground inn.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13452 |goto Howling Fjord/0 25.44,59.82
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12941 |goto Zul'Drak/0 40.87,66.04
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12940 |goto Zul'Drak/0 59.33,57.20
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13461 |goto The Storm Peaks/0 41.07,85.85
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13448 |goto The Storm Peaks/0 28.72,74.29
step
click Candy Bucket##208144
|tip It's inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13462 |goto The Storm Peaks/0 30.92,37.16
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13463 |goto Dalaran/1 48.14,41.31
step
click Candy Bucket##208144
|tip It's under the stairs.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13473 |goto Dalaran/1 42.35,63.07
step
click Candy Bucket##208144
|tip It's in the side room on the left.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13472 |goto Dalaran/1 38.20,59.61
step
For the last buckets, you will need to level through Cataclysm
|tip Complete the Vashj'ir leveling guide to unlock all of the various areas of that zone.
|tip Complete the beginning of the Deepholm leveling guide to gain access to Deepholm.
|confirm
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29020 |goto Deepholm/0 47.35,51.71
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28985 |goto Abyssal Depths/0 54.67,72.11
Enter the cave here [60.07,79.40]
|tip Swim underwater into the cave if you do not have the flight path.
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28983 |goto Shimmering Expanse/0 49.72,57.39
Enter the cave here [47.17,57.42]
|tip Swim underwater into the cave if you do not have the flight path.
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28982 |goto Shimmering Expanse/0 49.18,41.87
Enter the cave here [50.07,39.35]
|tip Swim underwater into the cave if you do not have the flight path.
step
Enter the cave |goto Kelp'thar Forest/0 61.48,63.54 < 20 |walk
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28981 |goto Kelp'thar Forest/0 63.50,60.16
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32049 |goto The Jade Forest/0 44.80,84.36
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32033 |goto The Jade Forest/0 59.56,83.24
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32032 |goto The Jade Forest/0 54.61,63.33
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32027 |goto The Jade Forest/0 45.77,43.61
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32021 |goto The Jade Forest/0 41.68,23.14
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32031 |goto The Jade Forest/0 55.72,24.41
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32029 |goto The Jade Forest/0 48.09,34.62
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32039 |goto Kun-Lai Summit/0 72.73,92.28
step
click Candy Bucket##208144
|tip You {o}must complete{} the {o}Challenge Accepted{} quest to access this candy bucket.	|only if not completedq(30514)
|tip Complete the {o}few quests{} at {o}Binan Village{} nearby.					|only if not completedq(30514)
|tip The {o}quests will lead you{} to Westwind Rest.						|only if not completedq(30514)
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32042 |goto Kun-Lai Summit/0 54.07,82.82
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32037 |goto Kun-Lai Summit/0 57.45,59.95
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32041 |goto Kun-Lai Summit/0 64.21,61.27
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32051 |goto Kun-Lai Summit/0 62.50,28.90
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32043 |goto Townlong Steppes/0 71.11,57.78
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32044 |goto Vale of Eternal Blossoms/0 35.14,77.78
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32052 |goto Shrine of Seven Stars/1 37.81,65.92
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32026 |goto The Veiled Stair/0 55.10,72.23
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32048 |goto Valley of the Four Winds/0 83.64,20.15
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32046 |goto Valley of the Four Winds/0 19.87,55.79
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32024 |goto Dread Wastes/0 55.93,32.27
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32023 |goto Dread Wastes/0 55.22,71.19
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32036 |goto Krasarang Wilds/0 75.92,6.87
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32034 |goto Krasarang Wilds/0 51.40,77.29
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\The Mask Task",{
mopready=true,
startlevel=1,
achieveid={979},
patch='40405',
condition_suggested=function() return isevent("Hallow's End") end,
description="To earn this achievement, you will need to obtain a Flimsy Mask during Hallow's End.",
},[[
step
Earn "The Mask Task" Achievement |achieve 979
|tip Obtain any type of flimsy mask by Trick or Treating hourly.
|tip You also have a chance to obtain one from the Crudely Wrapped Gift from daily fire quests.
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\Rotten Hallow",{
mopready=true,
startlevel=25,
achieveid={1040},
patch='40300',
condition_suggested=function() return isevent("Hallow's End") end,
description="Ruin Hallow's End for the Horde and foil their attempts to wreck the Alliance celebration by completing the following quests:\n\n"..
"A Time to Gain\nA Time to Lose\nStink Bombs Away!\nClean Up in Stormwind",
},[[
step
talk Celestine of the Harvest##51665
accept A Time to Gain##29075 |goto Elwynn Forest/0 32.04,50.51
step
talk Keira##52064
accept A Time to Lose##29371 |goto Elwynn Forest/0 32.08,50.60
step
talk Gretchen Fenlow##51934
accept Stink Bombs Away!##29054 |goto Elwynn Forest/0 32.35,50.88
accept Clean Up in Stormwind##29144 |goto Elwynn Forest/0 32.35,50.88
step
talk Gertrude Fenlow##52548
Select _"I'm ready to fly, let's bomb the Undercity!"_ |gossip 113573
Begin Your Flight to Undercity |invehicle |goto Elwynn Forest/0 32.21,50.77 |q 29054
step
Reach Undercity |complete zone("Undercity") or completedq(29054)
step
Drop #25# Bombs |q 29054/1 |goto Elwynn Forest/0 32.21,50.77
|tip Use the {o}Toss Stink Bomb{} ability on your vehicle bar to drop bombs across Undercity.
|tip You can drop them anywhere.
|tip If you're feeling kind, focus on dropping them in areas where Horde players can easily remove them later.
step
Return to Elwynn Forest |complete zone("Elwynn Forest") or zone("Stormwind City") or completedq(29054)
|tip Use the {o}Return Home{} button on your vehicle bar.
step
click Bonfire
Use the Bonfire |q 29075/1 |goto Elwynn Forest/0 32.86,49.37
step
use the Arcane Cleanser##69191
|tip Use it all over Stormwind City on large orange clouds of smoke coming from the ground.
Remove #10# Stink Bombs |q 29144/1 |goto Stormwind City/0 57.58,63.42
step
talk Celestine of the Harvest##51665
turnin A Time to Gain##29075 |goto Elwynn Forest/0 32.04,50.51
step
talk Gretchen Fenlow##51934
turnin Stink Bombs Away!##29054 |goto Elwynn Forest/0 32.35,50.88
turnin Clean Up in Stormwind##29144 |goto Elwynn Forest/0 32.35,50.88
step
use Dousing Agent##68648
Douse the Horde's Wickerman |q 29371/1 |goto Tirisfal Glades/0 62.37,68.20
step
talk Keira##52064
turnin A Time to Lose##29371 |goto Elwynn Forest/0 32.08,50.60
step
Earn "Rotten Hallow" Achievement |achieve 1040
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\The Savior of Hallow's End",{
mopready=true,
startlevel=1,
achieveid={289},
patch='40405',
condition_suggested=function() return isevent("Hallow's End") end,
description="To earn this achievement, complete one of the quests to save a village from the Headless Horseman.",
},[[
step
talk Human Commoner##18927
accept Costumed Orphan Matron##11356 |goto Stormwind City/0 61.75,74.13
step
talk Costumed Orphan Matron##24519
turnin Costumed Orphan Matron##11356 |goto Elwynn Forest/0 Elwynn Forest/0 42.62,64.39
accept Fire Brigade Practice##11360 |goto Elwynn Forest/0 42.62,64.39
|tip You may need to wait for the Horseman's assault to stop.
step
click Water Barrel |goto Elwynn Forest/0 42.51,64.49
|tip Click the Water Barrel to pick up a bucket of water.
collect Water Bucket##32971 |n
use the Water Bucket##32971
|tip Throw the buckets at the fires on top of buildings around this area.
|tip You may have to wait a short amount of time for the Horseman to attack.
Put Out #5# Fires |q 11360/1 |goto Elwynn Forest/0 42.43,65.63
step
talk Large Jack-O'-Lantern
accept Smash the Pumpkin##12133 |goto Elwynn Forest/0 42.39,65.87
|tip This will only be available after the Headless Horseman is defeated.
|tip You can skip this step if it does not drop.
step
talk Costumed Orphan Matron##24519
turnin Fire Brigade Practice##11360 |goto Elwynn Forest/0 42.62,64.39
turnin Smash the Pumpkin##12133 |goto Elwynn Forest/0 42.62,64.39 |only if haveq(12133) or completedq(12133)
step
talk Costumed Orphan Matron##24519
accept Stop the Fires!##11131 |goto Elwynn Forest/0 42.62,64.39 |or
accept "Let the Fires Come!"##12135 |goto Elwynn Forest/0 42.62,64.39 |or
|tip You will only be able to accept one of these quests.
|tip The quest offered depends on whether Goldshire is under attack or not.
step
click Water Barrel |goto Elwynn Forest/0 42.51,64.49
|tip Click the Water Barrel to pick up a bucket of water.
collect Water Bucket##32971 |n
use the Water Bucket##32971
|tip Throw the buckets at the fires on top of buildings around this area.
Put Out the Fires |q 11131/1 |goto Elwynn Forest/0 42.43,65.63
|only if haveq(11131) or completedq(11131)
step
click Water Barrel |goto Elwynn Forest/0 42.51,64.49
|tip Click the Water Barrel to pick up a bucket of water.
collect Water Bucket##32971 |n
use the Water Bucket##32971
|tip Throw the buckets at the fires on top of buildings around this area.
Put Out the Fires |q 12135/1 |goto Elwynn Forest/0 42.43,65.63
|only if haveq(12135) or completedq(12135)
step
talk Large Jack-O'-Lantern
accept Smash the Pumpkin##12133 |goto Elwynn Forest/0 42.39,65.87
|tip This will only be available after the Headless Horseman is defeated.
step
talk Costumed Orphan Matron##24519
turnin Stop the Fires!##11131 |goto Elwynn Forest/0 42.62,64.39 |only if haveq(11131) or completedq(11131) |or
turnin "Let the Fires Come!"##12135 |goto Elwynn Forest/0 42.62,64.39 |only if haveq(12135) or completedq(12135) |or
turnin Smash the Pumpkin##12133 |goto Elwynn Forest/0 42.62,64.39 |only if haveq(12133) or completedq(12133)
|only if haveq(11131,12135,12133) or completedq(11131,12135,12133)
step
Earn "The Savior of Hallow's End" Achievement |achieve 289
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\Trick or Treat!",{
mopready=true,
startlevel=1,
achieveid={972},
patch='40405',
condition_suggested=function() return isevent("Hallow's End") end,
description="To earn this achievement you will visit a single candy bucket.",
},[[
step
click Candy Bucket
|tip Inside the building.
use the Handful of Candy##37586 |only if itemcount(37586) >= 1
accept Candy Bucket##12336 |goto Stormwind City/0 60.51,75.33
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
step
Earn the "Trick or Treat!" Achievement |achieve 972
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\Don't Lose Your Head, Man",{
mopready=true,
startlevel=75,
achieveid={18959},
patch='40405',
condition_suggested=function() return isevent("Hallow's End") end,
description="To earn this achievement, you will have to kill the Headless Horseman.",
},[[
step
Reach Level 75 |ding 75
|tip You will need to be level 75 to summon the Horseman yourself.
|tip You can be any level and skip this if someone can summon for you.
|tip Use the leveling guides to accomplish this.
step
Inside the Scarlet Monastery Graveyard:
kill Headless Horseman##23682
|tip Enter the Scarlet Monastery Graveyard with a group.
|tip Accept the daily in the couryard at the Pumpkin Shrine when you are ready.
achieve 18959
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\Out With It",{
mopready=true,
startlevel=1,
achieveid={288},
patch='40405',
condition_suggested=function() return isevent("Hallow's End") end,
description="To earn this achievement you will have to eat so many Tricky Treats that you get an upset tummy.",
},[[
step
use the Tricky Treat##33226
|tip You get these by completing Hallows End quests.
|tip Keep using your Tricky Treats quickly until you puke.
|tip You will need at least 2-3 Tricky Treats.
|tip Use the "Hallow's End Candy Buckets" guide to collect treats.
Earn the "Out With It" Achievement |achieve 288
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\A Mask for All Occasions",{
mopready=true,
startlevel=1,
achieveid={284},
patch='40405',
condition_suggested=function() return isevent("Hallow's End") end,
description="To earn this achievement, collect the following 24 masks:\n\n"..
"Blood Elf Male/Female\nDraenei Male/Female\nDwarf Male/Female\nGnome Male/Female\n"..
"Human Male/Female\nNight Elf Male/Female\nOrc Male/Female\nTauren Male/Female\n"..
"Troll Male/Female\nUndead Male/Female",
},[[
step
Obtain a Flimsy Male Orc Mask |achieve 284/1 |only if not achieved(284,1)
Obtain a Flimsy Male Blood Elf Mask |achieve 284/2 |only if not achieved(284,2)
Obtain a Flimsy Female Orc Mask |achieve 284/3 |only if not achieved(284,3)
Obtain a Flimsy Female Human Mask |achieve 284/4 |only if not achieved(284,4)
Obtain a Flimsy Female Gnome Mask |achieve 284/5 |only if not achieved(284,5)
Obtain a Flimsy Female Draenei Mask |achieve 284/6 |only if not achieved(284,6)
Obtain a Flimsy Male Troll Mask |achieve 284/7 |only if not achieved(284,7)
Obtain a Flimsy Female Undead Mask |achieve 284/8 |only if not achieved(284,8)
Obtain a Flimsy Female Troll Mask |achieve 284/9 |only if not achieved(284,9)
Obtain a Flimsy Female Blood Elf Mask |achieve 284/10 |only if not achieved(284,10)
Obtain a Flimsy Male Undead Mask |achieve 284/11 |only if not achieved(284,11)
Obtain a Flimsy Male Draenei Mask |achieve 284/12 |only if not achieved(284,12)
Obtain a Flimsy Female Night Elf Mask |achieve 284/13 |only if not achieved(284,13)
Obtain a Flimsy Male Night Elf Mask |achieve 284/14 |only if not achieved(284,14)
Obtain a Flimsy Male Gnome Mask |achieve 284/15 |only if not achieved(284,15)
Obtain a Flimsy Male Tauren Mask |achieve 284/16 |only if not achieved(284,16)
Obtain a Flimsy Male Human Mask |achieve 284/17 |only if not achieved(284,17)
Obtain a Flimsy Male Dwarf Mask |achieve 284/18 |only if not achieved(284,18)
Obtain a Flimsy Female Tauren Mask |achieve 284/19 |only if not achieved(284,19)
Obtain a Flimsy Female Dwarf Mask |achieve 284/20 |only if not achieved(284,20)
|tip Obtain all flimsy masks by Trick or Treating hourly.
|tip You also have a chance to obtain one from the Crudely Wrapped Gift from daily fire quests.
Earn the "A Mask for All Occasions" Achievement |achieve 284
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\That Sparkling Smile",{
mopready=true,
startlevel=1,
achieveid={981},
patch='40405',
condition_suggested=function() return isevent("Hallow's End") end,
description="To earn this achievement you will need to show off your sparkling smile by using a Tooth Pick.",
},[[
step
collect 1 Tooth Pick##37604
|tip These drop from the Headless Horseman.
|tip They have a small chance to drop from the Treat Bag from Trick or Treating hourly.
|tip The also have a small chance to drop from the Crudely Wrapped Gift reward from the "Putting out the Fires" daily quest
step
use the Tooth Pick##37604
Earn the "That Sparkling Smile" Achievement |achieve 981
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\G.N.E.R.D. Rage",{
mopready=true,
startlevel=1,
achieveid={1261},
patch='40405',
condition_suggested=function() return isevent("Hallow's End") end,
description="Earn 50 Honorable Hills while Under the Influence of the G.N.E.R.D. Buff.",
},[[
step
use G.N.E.R.D.S.##37583
|tip You can collect these from Handfuls of Candy after Trick or Treating.
|tip Use them every 30 minutes while PvPing to keep the buff on.
|tip If you don't have the buff active while killing players, you won't get credit.
Do any type of PvP of your choice
|tip You must be killing players that give you honor.
Earn #50# Honorable Hills while Under the Influence of the G.N.E.R.D. Buff |achieve 1261
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\Check Your Head",{
mopready=true,
startlevel=1,
achieveid={291},
patch='40405',
condition_suggested=function() return isevent("Hallow's End") end,
description="To earn this achievement you have to use Weighted Jack-o'-Lanterns to put pumpkin heads on each of the races listed below:\n\n"..
"Blood Elf\nDraenei\nDwarf\nGnome\nHuman\nNight Elf\nOrc\nTauren\nTroll\nUndead",
},[[
step
use the Weighted Jack-o'-Lantern##34068
|tip You receive Weighted Jack-o'-Lanterns by doing the Hallow's End daily quests and killing the Headless Horseman.
|tip Make sure the player doesn't already have a jack-o-lantern on their head or you won't get credit.
|tip Use your Weighted Jack-o'-Lanterns on the following races:
Undead |achieve 291/1 |goto Dalaran/1 49.38,28.50 |only if not achieved(291,1)
Troll |achieve 291/2 |goto Dalaran/1 49.38,28.50 |only if not achieved(291,2)
Tauren |achieve 291/3 |goto Dalaran/1 49.38,28.50 |only if not achieved(291,3)
Orc |achieve 291/4 |goto Dalaran/1 49.38,28.50 |only if not achieved(291,4)
Night Elf |achieve 291/5 |goto Dalaran/1 49.00,61.36 |only if not achieved(291,5)
Human |achieve 291/6 |goto Dalaran/1 49.00,61.36 |only if not achieved(291,6)
Draenei |achieve 291/7 |goto Dalaran/1 49.00,61.36 |only if not achieved(291,7)
Blood Elf |achieve 291/8 |goto Dalaran/1 49.38,28.50 |only if not achieved(291,8)
Gnome |achieve 291/9 |goto Dalaran/1 49.00,61.36 |only if not achieved(291,9)
Dwarf |achieve 291/10 |goto Dalaran/1 49.00,61.36 |only if not achieved(291,10)
Earn the "Check Your Head" Achievement |achieve 291
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\Hallowed Be Thy Name",{
mopready=true,
startlevel=1,
achieveid={1656},
patch='40405',
condition_suggested=function() return isevent("Hallow's End") end,
description="To earn this achievement, complete the following Hallow's End achievements:\n\n"..
"Trick or Treat!\nOut With It\nDon't Lose Your Head, Man\nThe Savior of Hallow's End\n"..
"That Sparkling Smile\nRotten Hallow\nG.N.E.R.D. Rage\nCheck Your Head\nThe Masquerade\n"..
"Sinister Calling\nTricks and Treats of Azeroth",
},[[
leechsteps "Events Guides\\Hallow's End\\Achievements\\Out With It" 1-1
leechsteps "Events Guides\\Hallow's End\\Achievements\\Don't Lose Your Head, Man" 1-2
leechsteps "Events Guides\\Hallow's End\\Achievements\\The Savior of Hallow's End" 1-11
leechsteps "Events Guides\\Hallow's End\\Achievements\\Rotten Hallow" 1-7
leechsteps "Events Guides\\Hallow's End\\Achievements\\G.N.E.R.D. Rage" 1-1
leechsteps "Events Guides\\Hallow's End\\Achievements\\Check Your Head" 1-1
leechsteps "Events Guides\\Hallow's End\\Achievements\\The Masquerade" 1-1
leechsteps "Events Guides\\Hallow's End\\Achievements\\Sinister Calling" 1-3
leechsteps "Events Guides\\Hallow's End\\Achievements\\That Sparkling Smile" 1-2
leechsteps "Events Guides\\Hallow's End\\Hallow's End Candy Buckets" 1-81
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\The Masquerade",{
mopready=true,
startlevel=1,
achieveid={283},
patch='40405',
condition_suggested=function() return isevent("Hallow's End") end,
description="To earn this achievement you will have to get transformed by the Hallowed Wands listed below:\n\n"..
"Hallowed Wand - Bat\nHallowed Wand - Ghost\nHallowed Wand - Leper Gnome\nHallowed Wand - Ninja\n"..
"Hallowed Wand - Pirate\nHallowed Wand - Skeleton\nHallowed Wand - Wisp",
},[[
step
Transform into a Bat |achieve 283/1 |only if not achieved(283,1)
Transform into a Ghost |achieve 283/2 |only if not achieved(283,2)
Transform into a Leper Gnome |achieve 283/3 |only if not achieved(283,3)
Transform into a Ninja |achieve 283/4 |only if not achieved(283,4)
Transform into a Pirate |achieve 283/5 |only if not achieved(283,5)
Transform into a Skeleton |achieve 283/6 |only if not achieved(283,6)
Transform into a Wisp |achieve 283/7 |only if not achieved(283,7)
|tip Have other players use Hallowed Wands on you while in a party to transform.
|tip Find someone to team up with or ask around in Dalaran.
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\Sinister Calling",{
mopready=true,
startlevel=1,
achieveid={292},
patch='40405',
condition_suggested=function() return isevent("Hallow's End") end,
description="To earn this achievement, you will need to obtain a Sinister Squashling pet and Hallowed Helm.",
},[[
step
collect 1 Sinister Squashling##33154
collect 1 Hallowed Helm##33292
|tip These drop from the Headless Horseman.
|tip They have a very small chance to drop from the Treat Bag from Trick or Treating hourly.
step
use the Sinister Squashling##33154
Obtain a Sinister Squashling Pet |achieve 292/1
step
use the Hallowed Helm##33292
Obtain a Hallowed Helm |achieve 292/2
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Harvest Festival\\Harvest Festival Quest")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Feast of Winter Veil Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\'Tis the Season")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\A Frosty Shake")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\BB King")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\Crashin' & Thrashin'")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\Fa-la-la-la-Ogri'la")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\He Knows If You've Been Naughty")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\Holiday Bromance")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\Let It Snow")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\On Metzen!")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\Scrooge")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\Simply Abominable")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\The Winter Veil Gourmet")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\With a Little Helper from My Friends")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\Merrymaker")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Achievements\\A-Caroling We Will Go")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Love is in the Air Main Questline")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Love is in the Air Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Achievements\\Be Mine!")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Achievements\\Charming")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Achievements\\Dangerous Love")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Achievements\\Fistful of Love")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Achievements\\Flirt With Disaster")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Achievements\\I Pitied The Fool")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Achievements\\Lonely?")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Achievements\\Lovely Luck Is On Your Side")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Achievements\\My Love is Like a Red, Red Rose")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Achievements\\Nation of Adoration")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Achievements\\Perma-Peddle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Achievements\\Shafted!")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Achievements\\Sweet Tooth")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Achievements\\The Rocket's Pink Glare")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Lunar Festival Main Questline")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Lunar Festival Optimized Elders Path")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\A Coin of Ancestry")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\5 Coins of Ancestry")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\10 Coins of Ancestry")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\25 Coins of Ancestry")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\50 Coins of Ancestry")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\Elders of Eastern Kingdoms")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\Elders of Kalimdor")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\Elders of Northrend")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\Elders of Cataclysm")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\Elders of the Dungeons")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\Elders of the Alliance")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\Elders of the Horde")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\Elune's Blessing")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\Frenzied Firecracker")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\The Rocket's Red Glare")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\Lunar Festival Finery")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Achievements\\To Honor One's Elders")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Midsummer Fire Festival\\Midsummer Fire Festival Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Midsummer Fire Festival\\Midsummer Fire Festival Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Midsummer Fire Festival\\Midsummer Fire Festival Bonfires")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Midsummer Fire Festival\\Burning Hot Pole Dance")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Midsummer Fire Festival\\Torch Juggler")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Pilgrim's Bounty\\Quests\\Pilgrim's Bounty Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Pilgrim's Bounty\\Quests\\Pilgrim's Bounty Daily Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Pilgrim's Bounty\\Achievements\\FOOD FIGHT!")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Pilgrim's Bounty\\Achievements\\Now We're Cookin'")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Pilgrim's Bounty\\Achievements\\Pilgrim")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Pilgrim's Bounty\\Achievements\\Pilgrim's Paunch")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Pilgrim's Bounty\\Achievements\\Pilgrim's Peril")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Pilgrim's Bounty\\Achievements\\Pilgrim's Progress")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Pilgrim's Bounty\\Achievements\\Sharing is Caring")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Pilgrim's Bounty\\Achievements\\Terokkar Turkey Time")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Pilgrim's Bounty\\Achievements\\Turkey Lurkey")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Pilgrim's Bounty\\Achievements\\The Turkinator")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Noblegarden\\Noblegarden Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Noblegarden\\Noblegarden Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Noblegarden\\Achievements\\Blushing Bride")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Noblegarden\\Achievements\\Chocoholic")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Noblegarden\\Achievements\\Chocolate Lover")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Noblegarden\\Achievements\\Desert Rose")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Noblegarden\\Achievements\\Dressed for the Occasion")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Noblegarden\\Achievements\\Hard Boiled")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Noblegarden\\Achievements\\I Found One!")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Noblegarden\\Achievements\\Noble Garden")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Noblegarden\\Achievements\\Shake Your Bunny-Maker")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Noblegarden\\Achievements\\Spring Fling")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Noblegarden\\Achievements\\Sunday's Finest")
