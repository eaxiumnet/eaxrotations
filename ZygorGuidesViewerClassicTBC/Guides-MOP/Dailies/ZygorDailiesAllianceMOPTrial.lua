local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Alliance" then return end
if ZGV:DoMutex("DailiesAMOP") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Mists of Pandaria Dailies\\Operation: Shieldwall Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Mists of Pandaria Dailies\\Kirin Tor Offensive Dailies")
ZygorGuidesViewer:RegisterGuide("Daily Guides\\Mists of Pandaria Dailies\\Beastmaster's Hunt Dailies (Operation: Shieldwall)",{
mopready=true,
startlevel=90,
description="This guide will take you through the vendor quests for Operation: Shieldwall to kill one of 3 beasts for reputation each day.",
},[[
step
talk Lyalia##64610
accept Meet the Scout##32246 |goto Vale of Eternal Blossoms/0 83.97,58.64
step
talk Scout Lynna##68311
turnin Meet the Scout##32246 |goto Krasarang Wilds/0 85.24,29.13
step
Watch the dialogue
talk King Varian Wrynn##61796
|tip He will eventually reach the beach.
accept A King Among Men##32247 |goto Krasarang Wilds/0 85.29,29.11
stickystart "Slay_Horde"
step
talk Marshal Troteman##68331
|tip Kill any enemies he is attacking.
Find Marshal Troteman |q 32247/2 |goto Krasarang Wilds/0 79.63,25.05
step
talk Hilda Hornswaggle##68312
|tip Kill any enemies she is attacking.
Find Hilda Hornswaggle |q 32247/3 |goto Krasarang Wilds/0 80.43,17.53
step
label "Slay_Horde"
kill Horde Raider##68332, Horde Hunter##68334, Horde Priest##67904
Slay #25# Horde |q 32247/1 |goto Krasarang Wilds/0 81.42,21.94
step
_Next to you:_
talk King Varian Wrynn##61796
turnin A King Among Men##32247 |goto Krasarang Wilds/0 81.42,21.94
accept Lion's Landing##32109 |goto Krasarang Wilds/0 81.42,21.94
step
click Flare Launcher##216609
turnin Lion's Landing##32109 |goto Krasarang Wilds/0 85.59,29.16
step
label "Collect_Tokens"
kill Heavy Mook##67399, Dominance Grunt##67357, Bloodhilt Honor Guard##67334, Dominance Raider##67346
collect 90 Domination Point Commission##91877 |goto Krasarang Wilds/0 11.14,61.02
|tip You will need 30 commissions for each vendor quest item, 3 items in total.
|tip You will buy the items and accept the quests one at a time due to the items being unique.
step
talk Proveditor Grantley##67881
buy 1 Sturdy Crane Snare##91854 |goto Krasarang Wilds/0 89.53,33.55 |q 32164 |future
step
use the Sturdy Crane Snare##91854
accept Beastmaster's Hunt: The Crane##32164 |goto Krasarang Wilds/0 89.53,33.55
step
talk Proveditor Grantley##67881
buy 1 Sturdy Tiger Trap##91855 |goto Krasarang Wilds/0 89.53,33.55 |q 32165 |future
step
use the Sturdy Tiger Trap##91855
accept Beastmaster's Hunt: The Tiger##32165 |goto Krasarang Wilds/0 89.53,33.55
step
talk Proveditor Grantley##67881
buy 1 Sturdy Crab Crate##91856 |goto Krasarang Wilds/0 89.53,33.55 |q 32166 |future
step
use the Sturdy Crab Crate##91856
accept Beastmaster's Hunt: The Crab##32166 |goto Krasarang Wilds/0 89.53,33.55
step
kill Great Crane##59763+
collect Pristine Jet Crownfeather##91815 |q 32164/2 |goto Krasarang Wilds/0 72.66,44.93
|only if haveq(32164) or completedq(32164)
step
kill Unga Villager##60358+
|tip Make sure you stay in the quest area and kill the correct mobs.
|tip Mobs along the beach don't drop the fish.
collect 30 Funky Rotten Fish##91817 |q 32166/1 |goto Krasarang Wilds/0 46.77,91.08
You can find some bigger clusters around [Krasarang Wilds/0 44.01,90.62]
step
kill Child of Chi-Ji##60616+
|tip You will need to kill a lot of these all over the island.
|tip Fly around the beach area, killing the small groups of cranes.
|tip Then work on the interior while they respawn.
collect 5 Pristine Golden Crownfeather##91814 |q 32164/1 |goto Krasarang Wilds/0 34.32,72.33
The beach can be found at [Krasarang Wilds/0 28.49,68.60]
step
click Mound of Dirt##216161
turnin Beastmaster's Hunt: The Crane##32164 |goto Krasarang Wilds/0 39.21,61.92
step
Watch the dialogue
talk Ancient Bloodcrown Crane##67555
|tip It will walk up and fall to the ground.
accept Beastmaster's Quarry: The Crane##32184 |goto Krasarang Wilds/0 39.26,61.85
step
kill Wasteland Yak##66549, Wasteland Calf##66595
collect 25 Unbruised Yak Haunch##91816 |q 32165/1 |goto Dread Wastes/0 52.40,66.75
You can find more around:
[Dread Wastes/0 45.48,55.54]
[Dread Wastes/0 37.55,52.10]
step
click Mound of Dirt##216161
turnin Beastmaster's Hunt: The Tiger##32165 |goto Krasarang Wilds/0 13.87,41.34
step
Watch the dialogue
talk Krasari Elder##67556
|tip It will walk up and fall to the ground.
accept Beastmaster's Quarry: The Tiger##32185 |goto Krasarang Wilds/0 13.89,41.20
step
click Mound of Dirt##216161
turnin Beastmaster's Hunt: The Crab##32166 |goto Krasarang Wilds/0 56.30,42.05
step
Watch the dialogue
talk Colossal Viseclaw##67508
|tip It will walk up and become captured in a crate.
accept Beastmaster's Quarry: The Crab##32186 |goto Krasarang Wilds/0 56.34,42.15
step
talk Huntsman Blake##67558
turnin Beastmaster's Quarry: The Crane##32184 |goto Krasarang Wilds/0 84.33,18.85
turnin Beastmaster's Quarry: The Tiger##32185 |goto Krasarang Wilds/0 84.33,18.85
turnin Beastmaster's Quarry: The Crab##32186 |goto Krasarang Wilds/0 84.33,18.85
step
Choose the beast you prefer to fight today:
|tip You can only fight one beast and complete its daily quest each day.
Ancient Bloodcrown Crane |confirm
|tip This beast casts random songs with various spell effects.
Krasari Elder |confirm |next "Krasari_Elder"
|tip This beast requires you to remain in melee range the entire time and randomly vanishes.
Colossal Viseclaw |confirm |next "Colossal_Viseclaw"
|tip This beast needs to be kept moving to lower its damage reduction buff.
step
label "Ancient_Bloodcrown_Crane"
talk Huntsman Blake##67558
Select _"We would like to fight the Ancient Bloodcrown Crane."_ |gossip 40760
|tip During the fight, pay attention to the songs that it uses.
|tip Interrupt those that can be and avoid the others.
|tip Run out of the red circle.
kill Ancient Bloodcrown Crane##67555
accept Ancient's Fall##32170 |goto Krasarang Wilds/0 84.33,18.85
step
talk Huntsman Blake##67558
turnin Ancient's Fall##32170 |goto Krasarang Wilds/0 84.33,18.85
step
label "Krasari_Elder"
talk Huntsman Blake##67558
Select _"We would like to fight the Krasari Elder."_ |gossip 40761
|tip Stay close to it at all times.
|tip It will occassionally vanish.
|tip If you have a Hunter, put a flare out.
kill Krasari Elder##67556
accept End of an Elder##32171 |goto Krasarang Wilds/0 84.33,18.85
step
talk Huntsman Blake##67558
turnin End of an Elder##32171 |goto Krasarang Wilds/0 84.33,18.85
step
label "Colossal_Viseclaw"
talk Huntsman Blake##67558
Select _"We would like to fight the Colossal Viseclaw."_ |gossip 40762
kill Colossal Viseclaw##67508
|tip During the fight, kite it around and stay mobile.
|tip It has a damage reduction buff that decreases while while it moves.
|tip Stop moving when the buff nears zero or it will reset upon reaching zero.
accept A Colossal Victory##32172 |goto Krasarang Wilds/0 84.33,18.85
step
talk Huntsman Blake##67558
turnin A Colossal Victory##32172 |goto Krasarang Wilds/0 84.33,18.85
step
You Have Completed the Available Daily Quests |complete false or not completedq(32164,32165,32166,32184,32185,32186,32170,32171,32172) |next "Collect_Tokens"
|tip New quests will become available with the next daily server reset.
]])
