local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Horde" then return end
if ZGV:DoMutex("EventsH") then return end
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
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Children's Week Orgrimmar Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Children's Week Shattrath Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Children's Week Dalaran Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Achievements\\Aw, Isn't It Cute?")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Achievements\\Bad Example")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Achievements\\Daily Chores")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Achievements\\Home Alone")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Achievements\\School of Hard Knocks")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Achievements\\Veteran Nanny")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Darkmoon Faire Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Darkmoon Faire Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Taking the Show on the Road")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Fairegoer's Feast")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Come One, Come All!")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Blastenheimer Bullseye")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Darkmoon Defender")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Darkmoon Dungeoneer")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Darkmoon Despoiler")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Faire Favors")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\I Was Promised a Pony")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Quick Shot")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Achievements\\Step Right Up")
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Hallow's End Quests",{
mopready=true,
condition_end=function() return completedq(8409) end,
description="Complete the Hallow's End event quests.",
patch='40405',
},[[
step
Reach Level 25 |ding 25
|tip You must be at least level 25 to be able to accept this quest.
|tip Use the Leveling guides to accomplish this.
step
talk Spoops##15309
accept Hallow's End Treats for Spoops!##8312 |goto Tirisfal Glades/0 62.13,66.44
step
talk Candace Fenlow##53763
accept Stink Bombs Away!##29374 |goto Tirisfal Glades/0 62.42,66.72
accept Clean Up in Undercity##29375 |goto Tirisfal Glades/0 62.42,66.72
accept A Friend in Need##29431 |goto Tirisfal Glades/0 62.42,66.72
step
talk Darkcaller Yanka##15197
accept A Time to Build Up##29376 |goto Tirisfal Glades/0 62.12,67.83
accept A Time to Break Down##29377 |goto Tirisfal Glades/0 62.12,67.83
step
click Bonfire
Use the Bonfire |q 29376/1 |goto Tirisfal Glades/0 62.21,67.96
step
click Wickerman Ashes
Use the Wickerman Ashes |q 29376/2 |goto Tirisfal Glades/0 62.15,68.22
step
talk Darkcaller Yanka##15197
turnin A Time to Build Up##29376 |goto Tirisfal Glades/0 62.12,67.83
step
talk Crina Fenlow##53764
Select _"I'm ready to attack Stormwind!"_ |gossip 113766
Ride a Broom to Stormwind |invehicle |q 29374 |goto Tirisfal Glades/0 62.13,67.03
step
Drop #25# Stink Bombs in Stormwind |q 29374/1 |goto Stormwind City/0 66.88,78.41
|tip You'll fly around automatically.
|tip Target NPCs or Players for credit.
step
Click the Return Button on Your Action Bar |outvehicle |q 29374
step
use Arcane Cleanser##70727
|tip Use them on the orange clouds within the Undercity.
|tip You will need to search around to find them.
Remove #10# Stink Bombs |q 29375/1 |goto Undercity/0 70.07,50.42
step
talk Candace Fenlow##53763
turnin Stink Bombs Away!##29374 |goto Tirisfal Glades/0 62.42,66.72
turnin Clean Up in Undercity##29375 |goto Tirisfal Glades/0 62.42,66.72
step
talk Orc Commoner##19175
accept A Season for Celebration##29400 |goto Orgrimmar/1 51.55,75.16
accept Masked Orphan Matron##11357 |goto Orgrimmar/1 51.44,69.54
step
talk Innkeeper Gryshka##6929
|tip Inside the building.
accept Flexing for Nougat##8359 |goto Orgrimmar/1 53.65,78.77
step
clicknpc Innkeeper Gryshka##6929
|tip Inside the building.
|tip Target Innkeeper Gryshka and type "/flex" into your chat to perform the Flex emote.
'|script DoEmote("FLEX")
Flex for Inkeeper Gryshka |q 8359/1 |goto Orgrimmar/1 53.65,78.77
step
talk Innkeeper Gryshka##6929
|tip Inside the building.
turnin Flexing for Nougat##8359 |goto Orgrimmar/1 53.65,78.77
step
collect Orgrimmar Nougat##20493 |q 8312/1
|tip Save this, you will need it later.
step
click Candy Bucket
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
accept Candy Bucket##12366 |goto Orgrimmar/1 53.94,78.95
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
step
talk Edgar Goodwin##54141
|tip Inside the building.
turnin A Friend in Need##29431 |goto Orgrimmar/1 54.40,77.58
accept Missing Heirlooms##29415 |goto Orgrimmar/1 54.40,77.58
step
talk Kali Remik##11814
|tip She patrols around inside this building.
accept Incoming Gumdrop##8358 |goto Orgrimmar/1 32.82,65.15
step
clicknpc Kali Remik##11814
|tip Target Kali Remik and type "/train" into your chat to perform the Train emote.
'|script DoEmote("TRAIN")
Do the "Train" for Kali Remik |q 8358/1 |goto Orgrimmar/1 32.82,65.15
step
talk Kali Remik##11814
turnin Incoming Gumdrop##8358 |goto Orgrimmar/1 32.82,65.15
step
Search the Courier's Cabin |q 29415/1 |goto Durotar/0 57.50,8.99
step
talk Hired Courier##54142
turnin Missing Heirlooms##29415 |goto Durotar/0 57.33,9.01
accept Fencing the Goods##29416 |goto Durotar/0 57.33,9.01
step
talk Auctioneer Drezmit##44866
Select _"Have you seen anyone suspicious trying to sell a crate of objects recently?"_ |gossip 113776
Watch the Dialogue
Follow Thief's Trail |q 29416/1 |goto Orgrimmar/1 54.08,73.35
step
talk Auctioneer Drezmit##44866
turnin Fencing the Goods##29416 |goto Orgrimmar/1 54.08,73.35
accept Shopping Around##29425 |goto Orgrimmar/1 54.08,73.35
step
talk Delian Sunshade##54146
Watch the Dialogue
Investigate Droffers and Son |q 29425/1 |goto Orgrimmar/1 58.05,48.39
step
talk Delian Sunshade##54146
|tip Inside the building.
turnin Shopping Around##29425 |goto Orgrimmar/1 58.05,48.39
accept Taking Precautions##29426 |goto Orgrimmar/1 58.05,48.39
step
talk Kor'geld##3348
|tip Inside the building.
collect 5 Crystal Vial##3371 |q 29426/1 |goto Orgrimmar/1 55.23,45.82
step
click Blood Nettle##209059+
|tip They are only found in the Valley of Wisdom.
collect 5 Blood Nettle##71035 |q 29426/3 |goto Orgrimmar/1 45.88,49.16
step
talk Hagrus##3335
|tip Inside the building.
buy 5 Arcane Powder##17020 |q 29426/2 |goto Orgrimmar/2 44.17,35.66
step
talk Delian Sunshade##54146
|tip Inside the building.
turnin Taking Precautions##29426 |goto Orgrimmar/1 58.05,48.39
accept The Collector's Agent##29427 |goto Orgrimmar/1 58.05,48.39
step
Watch the Dialogue
Disrupt the Meeting |q 29427/1 |goto Tirisfal Glades/0 65.77,74.79
step
click Stolen Crate##209094
turnin The Collector's Agent##29427 |goto Tirisfal Glades/0 65.77,74.81
accept What Now?##29428 |goto Tirisfal Glades/0 65.77,74.81
step
talk Edgar Goodwin##54141
|tip Inside the building.
turnin What Now?##29428 |goto Orgrimmar/1 54.40,77.58
step
click Edgar's Crate##209095
accept The Creepy Crate##29429 |goto Orgrimmar/1 54.47,77.55
step
talk Masked Orphan Matron##23973
turnin Masked Orphan Matron##11357 |goto Durotar/0 52.57,41.20
step
talk Masked Orphan Matron##23973
accept Let the Fires Come!##12139 |goto Durotar/0 52.57,41.20
accept Fire Training##11361 |goto Durotar/0 52.57,41.20
step
click Water Barrel |goto Durotar/0 52.54,41.30
|tip Click the Water Barrel to pick up a bucket of water.
collect Water Bucket##32971 |n
use the Water Bucket##32971
|tip Throw the buckets at the fires on top of buildings around this area.
Put Out #5# Fires |q 11361/1 |goto Durotar/0 52.39,42.48 |only if haveq(11361)
Put Out #5# Fires |q 12139/1 |goto Durotar/0 52.39,42.48 |only if haveq(12139)
step
talk Large Jack-O'-Lantern
accept Smash the Pumpkin##12155 |goto Durotar/0 52.64,42.41
|tip This will only be available after the Headless Horseman is defeated.
|tip You can skip this step if it does not drop.
step
talk Masked Orphan Matron##23973
turnin Let the Fires Come!##12139 |goto Durotar/0 52.57,41.20
turnin Fire Training##11361 |goto Durotar/0 52.57,41.20
turnin Smash the Pumpkin##12155 |goto Durotar/0 52.57,41.20 |only if haveq(12155) or completedq(12155)
step
click Candy Bucket
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
accept Candy Bucket##12361 |goto Durotar/0 51.54,41.58
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
step
collect Darkspear Gumdrop##20495 |q 8312/2
|tip Save this, you will need it later.
step
talk Innkeeper Pala##6746
|tip Inside the building.
accept Dancing for Marzipan##8360 |goto Thunder Bluff/0 45.81,64.71
step
clicknpc Innkeeper Pala##6746
|tip Inside the building.
|tip Target Innkeeper Pala and type "/dance" into your chat to perform the Dance emote.
'|script DoEmote("DANCE")
Dance for Inkeeper Pala |q 8360/1 |goto Thunder Bluff/0 45.81,64.71
step
talk Innkeeper Pala##6746
|tip Inside the building.
turnin Dancing for Marzipan##8360 |goto Thunder Bluff/0 45.81,64.71
step
collect Thunder Bluff Marzipan##20497 |q 8312/4
|tip Save this, you will need it later.
step
click Candy Bucket
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
accept Candy Bucket##12367 |goto Thunder Bluff/0 45.60,64.94
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
step
talk Innkeeper Norman##6741
accept Chicken Clucking for a Mint##8354 |goto Undercity/0 67.73,37.88
step
clicknpc Innkeeper Norman##6741
|tip Target Innkeeper Norman and type "/chicken" into your chat to perform the Chicken emote.
'|script DoEmote("CHICKEN")
Cluck Like a Chicken for Innkeeper Norman |q 8354/1 |goto Undercity/0 67.73,37.88
step
talk Innkeeper Norman##6741
turnin Chicken Clucking for a Mint##8354 |goto Undercity/0 67.73,37.88
step
collect Undercity Mint##20491 |q 8312/3
|tip Save this, you will need it later.
step
click Candy Bucket
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
accept Candy Bucket##12368 |goto Undercity/0 67.75,37.41
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
step
talk Spoops##15309
turnin Hallow's End Treats for Spoops!##8312 |goto Tirisfal Glades/0 62.13,66.44
step
use Dousing Agent##68647
Douse the Alliance's Wickerman |q 29377/1 |goto Elwynn Forest/0 33.38,47.85
|tip You will be flagged for PVP.
step
talk Darkcaller Yanka##15197
turnin A Time to Break Down##29377 |goto Tirisfal Glades/0 62.12,67.83
turnin A Season for Celebration##29400 |goto Tirisfal Glades/0 62.12,67.83
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Hallow's End Daily Quests",{
mopready=true,
description="Put out fires in Razor Hill and kill the Headless Horseman.",
patch='40405',
},[[
step
label "Begin_Dailies"
talk Orc Commoner##19175
accept Masked Orphan Matron##11357 |goto Orgrimmar/1 51.44,69.54
step
Follow the road south |goto Durotar/0 46.34,18.51 < 30 |only if walking
talk Masked Orphan Matron##23973
turnin Masked Orphan Matron##11357 |goto Durotar/0 52.57,41.20
step
talk Masked Orphan Matron##23973
accept Stop the Fires!##11219 |goto Durotar/0 52.57,41.20 |or
accept "Let the Fires Come!"##12139 |goto Durotar/0 52.57,41.20 |or
|tip You will only be able to accept one of these quests.
|tip The quest offered depends on whether Razor Hill is under attack or not.
step
click Water Barrel |goto Durotar/0 52.55,41.30
|tip Click the Water Barrel to pick up a bucket of water.
collect Water Bucket##32971 |n
use the Water Bucket##32971
|tip Throw the buckets at the fires on top of buildings around this area.
Put Out the Fires |q 11219/1 |goto Durotar/0 52.41,42.42
|only if haveq(11219) or completedq(11219)
step
click Water Barrel |goto Durotar/0 52.55,41.30
|tip Click the Water Barrel to pick up a bucket of water.
collect Water Bucket##32971 |n
use the Water Bucket##32971
|tip Throw the buckets at the fires on top of buildings around this area.
Put Out the Fires |q 12139/1 |goto Durotar/0 52.41,42.42
|only if haveq(12139) or completedq(12139)
step
talk Large Jack-O'-Lantern
accept Smash the Pumpkin##12155 |goto Durotar/0 52.64,42.41
|tip This will only be available after the Headless Horseman is defeated.
|tip You can skip this step if it does not drop.
step
talk Masked Orphan Matron##23973
turnin Stop the Fires!##11219 |goto Durotar/0 52.57,41.20 |only if haveq(11219) or completedq(11219) |or
turnin "Let the Fires Come!"##12139 |goto Durotar/0 52.57,41.20 |only if haveq(12139) or completedq(12139) |or
turnin Smash the Pumpkin##12155 |goto Durotar/0 52.57,41.20 |only if haveq(12155) or completedq(12155)
step
Reach Level 75 |ding 75 |or
|tip You must be at least level 75 to be able to kill the Headless Horseman.
|tip Use the Leveling guides to accomplish this.
'|complete not completedq(11219,12139,11405) |next "Begin_Dailies" |or
step
click Pumpkin Shrine
|tip It's in the courtyard of the Scarlet Monastery Graveyard dungeon.
|tip You will need a full group for this.
accept Call the Headless Horseman##11405 |or
'|complete not completedq(11219,12139,11405) |next "Begin_Dailies" |or
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
'|complete not completedq(11219,12139,11405) |next "Begin_Dailies" |or
step
click Pumpkin Shrine
turnin Call the Headless Horseman##11405 |or
'|complete not completedq(11219,12139,11405) |next "Begin_Dailies" |or
step
You have completed the availble daily quests for Hallow's End
|tip This guide will reset when more become available.
'|complete not completedq(11219,12139,11405) |next "Begin_Dailies" |or
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Hallow's End Candy Buckets",{
mopready=true,
description="Visit innkeeper candy buckets in Eastern Kingdoms, Kalimdor, and Outland "..
"for tasty treats.",
achieveid={971,965,968,967,5835,5838,7602},
patch='40405',
},[[
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12361 |goto Durotar/0 51.54,41.58
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12366 |goto Orgrimmar/2 53.92,78.93
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28992 |goto Azshara/0 57.10,50.16
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12400 |goto Winterspring/0 59.83,51.21
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28999 |goto Mount Hyjal/0 63.05,24.14
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29001 |goto Mount Hyjal/0 42.68,45.71
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29000 |goto Mount Hyjal/0 18.63,37.32
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28994 |goto Felwood/0 44.58,28.98
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28989 |goto Ashenvale/0 13.00,34.10
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28958 |goto Ashenvale/0 38.65,42.34
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28953 |goto Ashenvale/0 50.25,67.27
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12377 |goto Ashenvale/0 73.96,60.60
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29003 |goto The Barrens/0 62.51,16.60
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29002 |goto The Barrens/0 56.21,40.03
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12374 |goto The Barrens/0 49.51,57.91
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29004 |goto Southern Barrens/0 39.29,20.10
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12362 |goto Mulgore/0 46.78,60.41
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12367 |goto Thunder Bluff/0 45.62,64.91
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29009 |goto Stonetalon Mountains/0 66.50,64.19
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12378 |goto Stonetalon Mountains/0 50.39,63.79
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28993 |goto Desolace/0 56.72,50.12
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12381 |goto Desolace/0 24.08,68.29
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28996 |goto Feralas/0 41.45,15.68
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28998 |goto Feralas/0 51.97,47.64
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12386 |goto Feralas/0 74.83,45.14
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12401 |goto Silithus/0 55.47,36.79
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29016 |goto Uldum/0 26.59,7.23
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29017 |goto Uldum/0 54.68,33.01
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29018 |goto Un'Goro Crater/0 55.26,62.11
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29014 |goto Tanaris/0 55.70,60.96
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12399 |goto Tanaris/0 52.56,27.10
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12398 |goto Dustwallow Marsh/0 41.86,74.09
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12383 |goto Dustwallow Marsh/0 36.78,32.43
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29005 |goto Southern Barrens/0 40.70,69.31
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12396 |goto The Barrens/0 67.33,74.66
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12397 |goto The Cape of Stranglethorn/0 40.91,73.73
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28969 |goto The Cape of Stranglethorn/0 35.04,27.22
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12382 |goto Northern Stranglethorn/0 37.38,51.78
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28959 |goto Blasted Lands/0 40.47,11.29
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12384 |goto Swamp of Sorrows/0 46.87,56.92
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28967 |goto Swamp of Sorrows/0 71.65,14.09
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
accept Candy Bucket##28957 |goto Badlands/0 18.36,42.73
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28955 |goto Badlands/0 65.86,35.65
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28974 |goto Twilight Highlands/0 45.11,76.81
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28973 |goto Twilight Highlands/0 53.40,42.85
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28976 |goto Twilight Highlands/0 75.40,16.54
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12380 |goto Arathi Highlands/0 69.02,33.27
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12387 |goto The Hinterlands/0 78.19,81.47
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28971 |goto The Hinterlands/0 31.81,57.87
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28987 |goto Western Plaguelands/0 48.28,63.65
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12402 |goto Eastern Plaguelands/0 75.57,52.32
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12373 |goto Ghostlands/0 48.67,31.91
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12365 |goto Eversong Woods/0 43.70,71.03
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12364 |goto Eversong Woods/0 48.19,47.88
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12370 |goto Silvermoon City/0 67.58,72.91
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12369 |goto Silvermoon City/0 79.43,57.66
step
click Candy Bucket##208144
|tip Inside Undercity.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12368 |goto Undercity/0 67.75,37.41
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28966 |goto Silverpine Forest/0 44.30,20.29
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12371 |goto Silverpine Forest/0 46.45,42.90
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12363 |goto Tirisfal Glades/0 60.99,51.41
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28972 |goto Tirisfal Glades/0 83.04,72.06
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12376 |goto Hillsbrad Foothills/0 57.85,47.27
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28962 |goto Hillsbrad Foothills/0 60.26,63.74
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12388 |goto Hellfire Peninsula/0 56.81,37.45
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12389 |goto Hellfire Peninsula/0 26.89,59.47
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12404 |goto Shattrath City/0 56.31,81.95
|only if rep("The Scryers") >= Neutral
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12404 |goto Shattrath City/0 28.23,49.07
|only if rep("The Aldor") >= Neutral
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12391 |goto Terokkar Forest/0 48.74,45.17
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12395 |goto Shadowmoon Valley/0 30.27,27.70
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12409 |goto Shadowmoon Valley/0 56.37,59.82
|only if rep("The Scryers") >= Neutral
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12409 |goto Shadowmoon Valley/0 61.00,28.17
|only if rep("The Aldor") >= Neutral
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12392 |goto Nagrand/0 56.68,34.48
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12390 |goto Zangarmarsh/0 30.62,50.87
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12403 |goto Zangarmarsh/0 78.45,62.88
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12394 |goto Blade's Edge Mountains/0 76.22,60.39
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12393 |goto Blade's Edge Mountains/0 53.43,55.55
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
accept Candy Bucket##13468 |goto Borean Tundra/0 41.71,54.40
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
accept Candy Bucket##13467 |goto Borean Tundra/0 76.67,37.47
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13501 |goto Borean Tundra/0 49.74,9.98
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12950 |goto Sholazar Basin/0 26.61,59.20
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13469 |goto Dragonblight/0 37.83,46.47
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13459 |goto Dragonblight/0 48.12,74.66
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13470 |goto Dragonblight/0 76.82,63.28
step
click Candy Bucket##208144
|tip On the top floor inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13456 |goto Dragonblight/0 60.15,53.45
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13463 |goto Dalaran/1 48.14,41.31
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13474 |goto Dalaran/1 66.84,29.61
step
Enter The Underbelly here |goto Dalaran/1 35.32,45.23
click Candy Bucket##208144
|tip It's in the side room on the left.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13472 |goto Dalaran/1 38.20,59.61
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13461 |goto The Storm Peaks/0 41.07,85.85
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13548 |goto The Storm Peaks/0 37.09,49.51
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13462 |goto The Storm Peaks/0 30.92,37.16
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13471 |goto The Storm Peaks/0 67.65,50.68
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
accept Candy Bucket##12941 |goto Zul'Drak/0 40.87,66.04
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12946 |goto Grizzly Hills/0 20.89,64.77
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##12947 |goto Grizzly Hills/0 65.36,47.00
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13464 |goto Howling Fjord/0 49.44,10.75
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13466 |goto Howling Fjord/0 79.26,30.62
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13465 |goto Howling Fjord/0 52.10,66.15
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##13452 |goto Howling Fjord/0 25.44,59.82
step
For the last buckets, you will need to level through Cataclysm
|tip Complete the Vashj'ir leveling guide to unlock all of the various areas of that zone.
|tip Complete the beginning of the Deepholm leveling guide to gain access to Deepholm.
|confirm
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28986 |goto Abyssal Depths/0 51.35,60.55
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28984 |goto Shimmering Expanse/0 51.48,62.39
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28982 |goto Shimmering Expanse/0 49.18,41.87
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##28981 |goto Kelp'thar Forest/0 63.50,60.16
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##29019 |goto Deepholm/0 51.19,49.90
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32050 |goto The Jade Forest/0 28.45,13.27
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
accept Candy Bucket##32029 |goto The Jade Forest/0 48.09,34.62
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
accept Candy Bucket##32031 |goto The Jade Forest/0 55.72,24.41
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
accept Candy Bucket##32028 |goto The Jade Forest/0 28.01,47.39
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32039 |goto Kun-Lai Summit/0 72.73,92.28
step
click Candy Bucket##208144
|tip You {o}must complete{} the {o}Challenge Accepted{} quest to access this candy bucket.	|only if not completedq(30515)
|tip Complete the {o}few quests{} at {o}Binan Village{} nearby.					|only if not completedq(30515)
|tip The {o}quests will lead you{} to Eastwind Rest.						|only if not completedq(30515)
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32040 |goto Kun-Lai Summit/0 62.77,80.50
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
accept Candy Bucket##32026 |goto The Veiled Stair/0 55.10,72.23
step
click Candy Bucket##208144
|tip Upstairs inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32022 |goto Shrine of Two Moons/2 58.84,78.38
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32044 |goto Vale of Eternal Blossoms/0 35.13,77.77
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32046 |goto Valley of the Four Winds/0 19.87,55.79
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
accept Candy Bucket##32036 |goto Krasarang Wilds/0 75.92,6.87
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32047 |goto Krasarang Wilds/0 61.03,25.14
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32034 |goto Krasarang Wilds/0 51.40,77.29
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32020 |goto Krasarang Wilds/0 28.25,50.74
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32023 |goto Dread Wastes/0 55.22,71.19
step
click Candy Bucket##208144
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32024 |goto Dread Wastes 55.93,32.27
step
click Candy Bucket##208144
|tip Inside the building.
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
accept Candy Bucket##32043 |goto Townlong Steppes/0 71.11,57.78
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
leechsteps "Events Guides\\Hallow's End\\Achievements\\The Savior of Hallow's End" 1-12
leechsteps "Events Guides\\Hallow's End\\Achievements\\Rotten Hallow" 1-6
leechsteps "Events Guides\\Hallow's End\\Achievements\\G.N.E.R.D. Rage" 1-1
leechsteps "Events Guides\\Hallow's End\\Achievements\\Check Your Head" 1-1
leechsteps "Events Guides\\Hallow's End\\Achievements\\The Masquerade" 1-1
leechsteps "Events Guides\\Hallow's End\\Achievements\\Sinister Calling" 1-3
leechsteps "Events Guides\\Hallow's End\\Achievements\\That Sparkling Smile" 1-2
leechsteps "Events Guides\\Hallow's End\\Hallow's End Candy Buckets" 1-81
step
Earn the "Hallowed Be Thy Name" Achievement |achieve 1656
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
Transform into a Wisp |achieve 283/7
Transform into a Ghost |achieve 283/2
Transform into a Leper Gnome |achieve 283/3
Transform into a Pirate |achieve 283/5
Transform into a Ninja |achieve 283/4
Transform into a Skeleton |achieve 283/6
Transform into a Bat |achieve 283/1
|tip Have other players use Hallowed Wands on you while in a party to transform.
|tip Find someone to team up with or ask around in Dalaran.
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
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\Rotten Hallow",{
mopready=true,
startlevel=25,
achieveid={1041},
patch='40405',
condition_suggested=function() return isevent("Hallow's End") end,
description="Ruin Hallow's End for the Alliance and foil their attempts to wreck the Horde celebration by completing the following quests:\n\n"..
"Stinking Up Southshore\nRotten Eggs\nRuined Kegs",
},[[
step
talk Candace Fenlow##53763
accept Stink Bombs Away!##29374 |goto Tirisfal Glades/0 62.42,66.72
accept Clean Up in Undercity##29375 |goto Tirisfal Glades/0 62.42,66.72
step
talk Darkcaller Yanka##15197
accept A Time to Build Up##29376 |goto Tirisfal Glades/0 62.12,67.83
accept A Time to Break Down##29377 |goto Tirisfal Glades/0 62.12,67.83
step
click Bonfire
Use the Bonfire |q 29376/1 |goto Tirisfal Glades/0 62.21,67.96
step
click Wickerman Ashes
Use the Wickerman Ashes |q 29376/2 |goto Tirisfal Glades/0 62.15,68.22
step
talk Darkcaller Yanka##15197
turnin A Time to Build Up##29376 |goto Tirisfal Glades/0 62.12,67.83
step
talk Crina Fenlow##53764
Select _"I'm ready to attack Stormwind!"_ |gossip 113766
Ride a Broom to Stormwind |invehicle |q 29374 |goto Tirisfal Glades/0 62.13,67.03
step
Drop #25# Stink Bombs in Stormwind |q 29374/1 |goto Stormwind City/0 66.88,78.41
|tip You'll fly around automatically.
|tip Target NPCs or Players for credit.
step
Click the Return Button on Your Action Bar |outvehicle |q 29374
step
use the Arcane Cleanser##70727
|tip Use them on the orange clouds within the Undercity.
|tip You will need to search around to find them.
Remove #10# Stink Bombs |q 29375/1 |goto Undercity/0 70.07,50.42
step
talk Candace Fenlow##53763
turnin Stink Bombs Away!##29374 |goto Tirisfal Glades/0 62.42,66.72
turnin Clean Up in Undercity##29375 |goto Tirisfal Glades/0 62.42,66.72
step
use Dousing Agent##68647
Douse the Alliance's Wickerman |q 29377/1 |goto Elwynn Forest/0 33.38,47.85
|tip You will be flagged for PVP.
step
talk Darkcaller Yanka##15197
turnin A Time to Break Down##29377 |goto Tirisfal Glades/0 62.12,67.83
turnin A Season for Celebration##29400 |goto Tirisfal Glades/0 62.12,67.83
step
Earn the "Rotten Hallow" Achievement |achieve 1041
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
talk Orc Commoner##19175
accept Masked Orphan Matron##11357 |goto Orgrimmar/1 51.44,69.54
step
talk Masked Orphan Matron##23973
turnin Masked Orphan Matron##11357 |goto Durotar/0 52.57,41.20
step
talk Masked Orphan Matron##23973
accept Fire Training##11361 |goto Durotar/0 52.57,41.20
|tip You may need to wait for the Horseman's assault to stop.
step
click Water Barrel |goto Durotar/0 52.54,41.30
|tip Click the Water Barrel to pick up a bucket of water.
collect Water Bucket##32971 |n
use the Water Bucket##32971
|tip Throw the buckets at the fires on top of buildings around this area.
Put Out #5# Fires |q 11361/1 |goto Durotar/0 52.39,42.48
step
talk Large Jack-O'-Lantern
accept Smash the Pumpkin##12155 |goto Durotar/0 52.64,42.41
|tip This will only be available after the Headless Horseman is defeated.
|tip You can skip this step if it does not drop.
step
talk Masked Orphan Matron##23973
turnin Fire Training##11361 |goto Durotar/0 52.57,41.20
turnin Smash the Pumpkin##12155 |goto Durotar/0 52.57,41.20 |only if haveq(12155) or completedq(12155)
step
talk Masked Orphan Matron##23973
accept Stop the Fires!##11219 |goto Durotar/0 52.57,41.20 |or
accept "Let the Fires Come!"##12139 |goto Durotar/0 52.57,41.20 |or
|tip You will only be able to accept one of these quests.
|tip The quest offered depends on whether Razor Hill is under attack or not.
step
click Water Barrel |goto Durotar/0 52.55,41.30
|tip Click the Water Barrel to pick up a bucket of water.
collect Water Bucket##32971 |n
use the Water Bucket##32971
|tip Throw the buckets at the fires on top of buildings around this area.
Put Out the Fires |q 11219/1 |goto Durotar/0 52.41,42.42
|only if haveq(11219) or completedq(11219)
step
click Water Barrel |goto Durotar/0 52.55,41.30
|tip Click the Water Barrel to pick up a bucket of water.
collect Water Bucket##32971 |n
use the Water Bucket##32971
|tip Throw the buckets at the fires on top of buildings around this area.
Put Out the Fires |q 12139/1 |goto Durotar/0 52.41,42.42
|only if haveq(12139) or completedq(12139)
step
talk Large Jack-O'-Lantern
accept Smash the Pumpkin##12155 |goto Durotar/0 52.64,42.41
|tip This will only be available after the Headless Horseman is defeated.
|tip You can skip this step if it does not drop.
step
talk Masked Orphan Matron##23973
turnin Stop the Fires!##11219 |goto Durotar/0 52.57,41.20 |only if haveq(11219) or completedq(11219) |or
turnin "Let the Fires Come!"##12139 |goto Durotar/0 52.57,41.20 |only if haveq(12139) or completedq(12139) |or
turnin Smash the Pumpkin##12155 |goto Durotar/0 52.57,41.20 |only if haveq(12155) or completedq(12155)
|only if haveq(11219,12139,12155) or completedq(11219,12139,12155)
step
Earn "The Savior of Hallow's End" Achievement |achieve 289
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
'|use the Handful of Candy##37586 |only if itemcount(37586) >= 1
accept Candy Bucket##12366 |goto Orgrimmar/1 54.45,68.63
|tip If you cannot complete this quest because of a "Duplicate item found" message, open the Handful of Treats item in your bags and take out the contents.
step
Earn the "Trick or Treat!" Achievement |achieve 972
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Hallow's End\\Achievements\\Tricks and Treats of Azeroth",{
mopready=true,
startlevel=1,
achieveid={970,963,966,969},
patch='40405',
condition_suggested=function() return isevent("Hallow's End") end,
description="To earn this achievement, you will visit the various candy buckets around Eastern "..
"Kingdoms, Kalimdor, and Outland.",
},[[
leechsteps "Events Guides\\Hallow's End\\Hallow's End Candy Buckets"
step
Earn the "Tricks and Treats of Azeroth" Achievement |achieve 970
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
