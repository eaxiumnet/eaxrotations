local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Alliance" then return end
if ZGV:DoMutex("EventsA") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Brewfest Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Brewfest Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Children's Week Main Questline")
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Sayge's Fortunes (Elwynn Forest)",{
author="support@zygorguides.com",
description="\nReceive a stat buff and have your fortune told by Sayge at the Darkmoon Faire.",
model={491},
},[[
step
label "Choose_Fortune"
Choose the buff you would like to receive:
|tip The buff lasts for two hours.
|tip You can have your fortune told every four hours.
|tip NOTE: You will not be able to receive the written fortune and potential quest without an open inventory slot.
+10% Agility |confirm |next "Agility_Buff"
+10% Intelligence |confirm |next "Intelligence_Buff"
+10% Spirit |confirm |next "Spirit_Buff"
+10% Stamina |confirm |next "Stamina_Buff"
+10% Strength |confirm |next "Strength_Buff"
+10% Armor |confirm |next "Armor_Buff"
+25 All Resistances |confirm |next "Resistance_Buff"
+10% Damage |confirm |next "Damage_Buff"
step
label "Agility_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I confiscate the corn he has stolen, warn him that stealing is a path towards doom and destruction, but I let him go to return to his family."_
Select _"I would create some surreptitious means to keep my brother out of the order."_
Gain the "Sayge's Dark Fortune of Agility" Buff |havebuff spell:23736 |goto Elwynn Forest 42.12,69.00 |next "Use_Darkmoon_Faire_Fortune"
step
label "Intelligence_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I turn over the man to my liege for punishment, as he has broken the law of the land and it is my sworn duty to enforce it."_
Select _"I quietly ignore the insult."_
Gain the "Sayge's Dark Fortune of Intelligence" Buff |havebuff spell:23766 |goto Elwynn Forest 42.12,69.00 |next "Use_Darkmoon_Faire_Fortune"
step
label "Spirit_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I turn over the man to my liege for punishment, as he has broken the law of the land and it is my sworn duty to enforce it."_
Select _"I confront the ruler on his malicious behavior, upholding my liege's honor at the risk of any future diplomacy."_
Gain the "Sayge's Dark Fortune of Spirit" Buff |havebuff spell:23738 |goto Elwynn Forest 42.12,69.00 |next "Use_Darkmoon_Faire_Fortune"
step
label "Stamina_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I confiscate the corn he has stolen, warn him that stealing is a path towards doom and destruction, but I let him go to return to his family."_
Select _"I would speak against my brother joining the order, rushing a permanent breech in our relationship."_
Gain the "Sayge's Dark Fortune of Stamina" Buff |havebuff spell:23737 |goto Elwynn Forest 42.12,69.00 |next "Use_Darkmoon_Faire_Fortune"
step
label "Strength_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I confiscate the corn he has stolen, warn him that stealing is a path towards doom and destruction, but I let him go to return to his family."_
Select _"I would speak for my brother joining the order, potentially risking the safety of the order."_
Gain the "Sayge's Dark Fortune of Strength" Buff |havebuff spell:23735 |goto Elwynn Forest 42.12,69.00 |next "Use_Darkmoon_Faire_Fortune"
step
label "Armor_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I slay the man on the spot as my liege would expect me to do, as he is nothing more than a thief and a liar."_
Select _"I risk my own life and free him so that he may prove his innocence."_
Gain the "Sayge's Dark Fortune of Armor" Buff |havebuff spell:23767 |goto Elwynn Forest 42.12,69.00 |next "Use_Darkmoon_Faire_Fortune"
step
label "Resistance_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I slay the man on the spot as my liege would expect me to do, as he is nothing more than a thief and a liar."_
Select _"I execute him as per my liege's instructions, but doing so in as painless of a way as possible."_
Gain the "Sayge's Dark Fortune of Resistance" Buff |havebuff spell:23769 |goto Elwynn Forest 42.12,69.00 |next "Use_Darkmoon_Faire_Fortune"
step
label "Damage_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I slay the man on the spot as my liege would expect me to do, as he is nothing more than a thief and a liar."_
Select _"I execute him as per my liege's instructions, and do it in such a manner that he suffers painfully before he dies as retribution for his crimes against my people."_
Gain the "Sayge's Dark Fortune of Damage" Buff |havebuff spell:23768 |goto Elwynn Forest 42.12,69.00 |next "Use_Darkmoon_Faire_Fortune"
step
label "Use_Darkmoon_Faire_Fortune"
talk Sayge##14822
Select _"I'd love to get one of those written fortunes you mentioned!"_
collect 1 Darkmoon Faire Fortune##19422 |goto Elwynn Forest 42.12,69.00
step
use the Darkmoon Faire Fortune##19422
Obtain Your Fortune |condition itemcount(19422) == 0
step
label "Fortune_Told"
You have received your fortune
|tip You can have your fortune told every four hours.
Click Here to Choose Another Fortune |confirm |next "Choose_Fortune" |or
'|condition itemcount(19423) == 1 and not completedq(7937) and level >= 10 |next "Fortune_Awaits_Eastvale" |or
'|condition itemcount(19424) == 1 and not completedq(7938) and level >= 10 |next "Fortune_Awaits_Deadmines" |or
'|condition itemcount(19443) == 1 and not completedq(7944) and level >= 10 |next "Fortune_Awaits_Wailing_Caverns" |or
'|condition itemcount(19452) == 1 and not completedq(7945) and level >= 10 |next "Fortune_Awaits_Palemane_Rock" |or
step
label "Fortune_Awaits_Eastvale"
use Sayge's Fortune #23##19423
accept Your Fortune Awaits You...##7937
step
click Mysterious Eastvale Haystack
turnin Your Fortune Awaits You...##7937 |goto Elwynn Forest 84.79,64.37 |next "Fortune_Told"
step
label "Fortune_Awaits_Deadmines"
use Sayge's Fortune #24##19424
accept Your Fortune Awaits You...##7938
step
click Mysterious Deadmines Chest
|tip Just inside The Deadmines instance before you reach the first Miner.
|tip It may take a minute or two to appear.
turnin Your Fortune Awaits You...##7938 |next "Fortune_Told"
step
label "Fortune_Awaits_Wailing_Caverns"
use Sayge's Fortune #25##19443
accept Your Fortune Awaits You...##7944
step
click Mysterious Wailing Caverns Chest
|tip Just inside the Wailing Caverns instance after the Disciple of Naralex.
|tip It may take a minute or two to appear.
turnin Your Fortune Awaits You...##7944 |next "Fortune_Told"
step
label "Fortune_Awaits_Palemane_Rock"
use Sayge's Fortune #27##19452
accept Your Fortune Awaits You...##7945
step
click Mysterious Tree Stump
turnin Your Fortune Awaits You...##7945 |goto Mulgore 34.99,61.56 |next "Fortune_Told"
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Chronos Turn-Ins (Elwynn Forest)",{
author="support@zygorguides.com",
description="\nExchange various Leatherworking crafted items with Chronos for prize tickets at the Darkmoon Faire.",
model={14875},
},[[
step
collect 3 Embossed Leather Boots##2309 |n
|tip Create them with Leatherworking or purchase them from the Auction House.
talk Chronos##14833
accept Carnival Boots##7881 |goto Elwynn Forest 43.57,70.86 |or
|tip Each turnin requires 3 Embossed Leather Boots and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 1 Darkmoon Faire Prize Ticket.
|tip You can turn this quest in until you reach 500 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 500 |or
step
Reach Level 10 |ding 10
|tip Use the leveling guides to accomplish this.
step
collect 3 Toughened Leather Armor##2314 |n
|tip Create them with Leatherworking or purchase them from the Auction House.
talk Chronos##14833
accept Carnival Jerkins##7882 |goto Elwynn Forest 43.57,70.86 |or
|tip Each turnin requires 3 Toughened Leather Armors and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 4 Darkmoon Faire Prize Tickets.
|tip You can turn this quest in until you reach 1,100 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 1100 |or
step
Reach Level 20 |ding 20
|tip Use the leveling guides to accomplish this.
step
collect 3 Barbaric Harness##5739 |n
|tip Create them with Leatherworking or purchase them from the Auction House.
talk Chronos##14833
accept The World's Largest Gnome!##7883 |goto Elwynn Forest 43.57,70.86 |or
|tip Each turnin requires 3 Barbaric Harnesses and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 8 Darkmoon Faire Prize Tickets.
|tip You can turn this quest in until you reach 1,700 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 1700 |or
step
Reach Level 30 |ding 30
|tip Use the leveling guides to accomplish this.
step
collect 1 Turtle Scale Leggings##8185 |n
|tip Create them with Leatherworking or purchase them from the Auction House.
talk Chronos##14833
accept Crocolisk Boy and the Bearded Murloc##7884 |goto Elwynn Forest 43.57,70.86 |or
|tip Each turnin requires 1 Turtle Scale Leggings and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 12 Darkmoon Faire Prize Tickets.
|tip You can turn this quest in until you reach 2,500 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 2500 |or
step
Reach Level 40 |ding 40
|tip Use the leveling guides to accomplish this.
step
collect 8 Rugged Armor Kit##15564 |q 7885 |future
|tip Create them with Leatherworking or purchase them from the Auction House.
step
talk Chronos##14833
accept Armor Kits##7885 |goto Elwynn Forest 43.57,70.86
step
collect 8 Rugged Armor Kit##15564 |n
|tip Create them with Leatherworking or purchase them from the Auction House.
talk Chronos##14833
accept More Armor Kits##7941 |goto Elwynn Forest 43.57,70.86 |or
|tip From this point on, you can continue turning in Rugged Armor Kits.
|tip Each of these turnins will award 20 Darkmoon Faire Prize Tickets.
|tip Each turnin requires 8 Rugged Armor Kits and grants 100 reputation with the Darkmoon Faire.
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Kerri Hicks Turn-Ins (Elwynn Forest)",{
author="support@zygorguides.com",
description="\nExchange various Blacksmithing crafted items with Kerri Hicks for prize tickets at the Darkmoon Faire.",
model={14876},
},[[
step
collect 10 Coarse Weightstone##3240 |n
|tip Create them with Blacksmithing or purchase them from the Auction House.
talk Kerri Hicks##14832
accept Coarse Weightstone##7889 |goto Elwynn Forest 40.48,69.93 |or
|tip Each turnin requires 10 Coarse Weightstones and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 1 Darkmoon Faire Prize Ticket.
|tip You can turn this quest in until you reach 500 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 500 |or
step
Reach Level 10 |ding 10
|tip Use the leveling guides to accomplish this.
step
collect 7 Heavy Grinding Stone##3486 |n
|tip Create them with Blacksmithing or purchase them from the Auction House.
talk Kerri Hicks##14832
accept Heavy Grinding Stone##7890 |goto Elwynn Forest 40.48,69.93 |or
|tip Each turnin requires 7 Heavy Grinding Stones and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 4 Darkmoon Faire Prize Tickets.
|tip You can turn this quest in until you reach 1,100 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 1100 |or
step
Reach Level 20 |ding 20
|tip Use the leveling guides to accomplish this.
step
collect 3 Green Iron Bracers##3835 |n
|tip Create them with Blacksmithing or purchase them from the Auction House.
talk Kerri Hicks##14832
accept Green Iron Bracers##7891 |goto Elwynn Forest 40.48,69.93 |or
|tip Each turnin requires 3 Green Iron Bracers and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 8 Darkmoon Faire Prize Tickets.
|tip You can turn this quest in until you reach 1,700 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 1700 |or
step
Reach Level 30 |ding 30
|tip Use the leveling guides to accomplish this.
step
collect 1 Big Black Mace##7945 |n
|tip Create them with Blacksmithing or purchase them from the Auction House.
talk Kerri Hicks##14832
accept Big Black Mace##7892 |goto Elwynn Forest 40.48,69.93 |or
|tip Each turnin requires 1 Big Black Mace and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 12 Darkmoon Faire Prize Tickets.
|tip You can turn this quest in until you reach 2,500 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 2500 |or
step
Reach Level 40 |ding 40
|tip Use the leveling guides to accomplish this.
step
collect 8 Dense Grinding Stone##12644 |q 7893 |future
|tip Create them with Blacksmithing or purchase them from the Auction House.
step
talk Kerri Hicks##14832
accept Rituals of Strength##7893 |goto Elwynn Forest 40.48,69.93
step
collect 8 Dense Grinding Stone##12644 |n
|tip Create them with Blacksmithing or purchase them from the Auction House.
talk Kerri Hicks##14832
accept More Dense Grinding Stones##7939 |goto Elwynn Forest 40.48,69.93 |or
|tip From this point on, you can continue turning in Dense Grinding Stones.
|tip Each of these turnins will award 20 Darkmoon Faire Prize Tickets.
|tip Each turnin requires 8 Dense Grinding Stones and grants 100 reputation with the Darkmoon Faire.
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Rinling Turn-Ins (Elwynn Forest)",{
author="support@zygorguides.com",
description="\nExchange various Engineering crafted items with Rinling for prize tickets at the Darkmoon Faire.",
model={14877},
},[[
step
collect 5 Copper Modulator##4363 |n
|tip Create them with Engineering or purchase them from the Auction House.
|tip They also have a small chance to drop from mobs in the Gnomeregan dungeon.
talk Rinling##14841
accept Copper Modulator##7894 |goto Elwynn Forest 41.71,70.72 |or
|tip Each turnin requires 5 Copper Modulators and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 1 Darkmoon Faire Prize Ticket.
|tip You can turn this quest in until you reach 500 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 500 |or
step
Reach Level 10 |ding 10
|tip Use the leveling guides to accomplish this.
step
collect 7 Whirring Bronze Gizmo##4375 |n
|tip Create them with Engineering or purchase them from the Auction House.
talk Rinling##14841
accept Whirring Bronze Gizmo##7895 |goto Elwynn Forest 41.71,70.72 |or
|tip Each turnin requires 7 Whirring Bronze Gizmos and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 4 Darkmoon Faire Prize Tickets.
|tip You can turn this quest in until you reach 1,100 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 1100 |or
step
Reach Level 20 |ding 20
|tip Use the leveling guides to accomplish this.
step
collect 36 Green Firework##9313 |n
|tip Create them with Engineering or purchase them from the Auction House.
|tip They can also be purchased from any Holiday Fireworks Vendor on July 4th.
talk Rinling##14841
accept Green Fireworks##7896 |goto Elwynn Forest 41.71,70.72 |or
|tip Each turnin requires 36 Green Fireworks and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 8 Darkmoon Faire Prize Tickets.
|tip You can turn this quest in until you reach 1,700 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 1700 |or
step
Reach Level 30 |ding 30
|tip Use the leveling guides to accomplish this.
step
collect 6 Mechanical Repair Kit##11590 |n
|tip Create them with Engineering or purchase them from the Auction House.
talk Rinling##14841
accept Mechanical Repair Kits##7897 |goto Elwynn Forest 41.71,70.72 |or
|tip Each turnin requires 6 Mechanical Repair Kits and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 12 Darkmoon Faire Prize Tickets.
|tip You can turn this quest in until you reach 2,500 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 2500 |or
step
Reach Level 40 |ding 40
|tip Use the leveling guides to accomplish this.
step
collect 6 Thorium Widget##15994 |q 7898 |future
|tip Create them with Engineering or purchase them from the Auction House.
step
talk Rinling##14841
accept Thorium Widget##7898 |goto Elwynn Forest 41.71,70.72
step
collect 6 Thorium Widget##15994 |n
|tip Create them with Engineering or purchase them from the Auction House.
talk Rinling##14841
accept More Thorium Widgets##7942 |goto Elwynn Forest 41.71,70.72 |or
|tip From this point on, you can continue turning in Thorium Widgets.
|tip Each of these turnins will award 20 Darkmoon Faire Prize Tickets.
|tip Each turnin requires 6 Thorium Widgets and grants 100 reputation with the Darkmoon Faire.
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Yebb Neblegear Turn-Ins (Elwynn Forest)",{
author="support@zygorguides.com",
description="\nExchange various Farmed items with Yebb Neblegear for prize tickets at the Darkmoon Faire.",
model={14856},
},[[
step
Kill Savannah enemies around this area
|tip You can find them all over around Crossroads and to its northern area.
collect 5 Small Furry Paw##5134 |goto The Barrens 50.21,21.82 |n
talk Yebb Neblegear##14829
accept Small Furry Paws##7899 |goto Elwynn Forest 40.17,69.53 |or
|tip Each turnin requires 5 Small Furry Paws and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 1 Darkmoon Faire Prize Ticket.
|tip You can turn this quest in until you reach 500 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 500 |or
step
Reach Level 10 |ding 10
|tip Use the leveling guides to accomplish this.
step
Kill Ashenvale Bear enemies around this area
|tip You can find them all over between Raynewood Retreat and Splintertree post.
|tip You can also find them east of Satyrn.
collect 5 Torn Bear Pelt##11407 |goto Ashenvale 66.01,60.42 |n
You can find more around [Ashenvale 83.81,47.40]
talk Yebb Neblegear##14829
accept Torn Bear Pelts##7900 |goto Elwynn Forest 40.17,69.53 |or
|tip Each turnin requires 5 Torn Bear Pelts and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 4 Darkmoon Faire Prize Tickets.
|tip You can turn this quest in until you reach 1,100 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 1100 |or
step
Reach Level 20 |ding 20
|tip Use the leveling guides to accomplish this.
step
Kill Crag Coyote enemies around this area
|tip You can find the all over central and western Badlands.
collect 5 Soft Bushy Tail##4582 |goto Badlands 34.41,65.63 |n
You can find more around [Badlands 57.00,58.62]
talk Yebb Neblegear##14829
accept Soft Bushy Tails##7901 |goto Elwynn Forest 40.17,69.53 |or
|tip Each turnin requires 5 Soft Bushy Tails and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 8 Darkmoon Faire Prize Tickets.
|tip You can turn this quest in until you reach 1,700 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 1700 |or
step
Reach Level 30 |ding 30
|tip Use the leveling guides to accomplish this.
step
Kill Northspring enemies around this area
collect 5 Vibrant Plume##5117 |goto Feralas 40.00,12.61 |n
talk Yebb Neblegear##14829
accept Vibrant Plumes##7902 |goto Elwynn Forest 40.17,69.53 |or
|tip Each turnin requires 5 Vibrant Plumes and grants 100 reputation with the Darkmoon Faire.
|tip Each of these turnins will award 12 Darkmoon Faire Prize Tickets.
|tip You can turn this quest in until you reach 2,500 Neutral reputation.
'|condition repval('Darkmoon Faire','Neutral') >= 2500 |or
step
Reach Level 40 |ding 40
|tip Use the leveling guides to accomplish this.
step
Kill Stonelash enemies around this area
|tip You can find them all over central and southern Silithus.
collect 10 Glowing Scorpid Blood##19933 |goto Silithus 44.81,54.50 |q 8222 |future
step
talk Yebb Neblegear##14829
accept Glowing Scorpid Blood##8222 |goto Elwynn Forest 40.17,69.53
step
Kill Stonelash enemies around this area
|tip You can find them all over central and southern Silithus.
collect 10 Glowing Scorpid Blood##19933 |goto Silithus 44.81,54.50 |n
talk Yebb Neblegear##14829
accept More Glowing Scorpid Blood##8223 |goto Elwynn Forest 40.17,69.53
|tip From this point on, you can continue turning in Glowing Scorpid Blood.
|tip Each of these turnins will award 20 Darkmoon Faire Prize Tickets.
|tip Each turnin requires 10 Glowing Scorpid Blood and grants 100 reputation with the Darkmoon Faire.
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Spawn of Jubjub (Elwynn Forest)",{
author="support@zygorguides.com",
description="\nCollect a couple of Dark Iron Ale Mugs from the Grim Guzzler tavern in Blackrock Depths "..
"and offer them to Morja at the Darkmoon Faire to receive your very own Jubjub companion pet.",
condition_end=function() return completedq(7946) end,
model={14938},
},[[
step
click Dark Iron Ale Mug##165738
|tip They look like small mugs of ale on tables around the Grim Guzzler tavern in Blackrock Depths.
|tip Clicking two of them is safe but clicking more will anger the bar patrons.
collect 2 Dark Iron Ale Mug##11325 |q 7946 |future
|tip They can also be purchased from Plugger Spazzring in the Grim Guzzler.
|tip They can be purchased from the Auction House if you are lucky enough to find them.
step
use the Dark Iron Ale Mug##11325
|tip Place it at Morja's feet.
|tip Be sure you only use one; you will need the other one to turn in the quest.
Wait for Jubjub the frog to hop over to the mug
|tip This may take a couple of minutes.
talk Morja##14871
accept Spawn of Jubjub##7946 |goto Elwynn Forest 43.33,70.29
|tip This quest will be available after Jubjub appears.
step
use the Unhatched Jubling Egg##19462
|tip It will take seven days for the egg to mature enough to hatch.
collect 1 A Jubling's Tiny Home##19450
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Wood Frog (Elwynn Forest)",{
author="support@zygorguides.com",
description="\nCatch Flik as he runs all over the Darkmoon Faire grounds and purchase his limited supply "..
"Wood Frog Box for 1 gold.",
model={901},
},[[
step
talk Flik##14860
|tip He's a little Orc boy running fast all over the Darkmoon Faire grounds.
|tip You will have to be quick to catch him.
|tip Talking to him will stop him for a short period of time.
buy 1 Wood Frog Box##11027 |goto Elwynn Forest 42.59,70.30
|tip This item costs 1 gold and has a limited quantity of 1.
|tip It respawns in approximately 20 minutes.
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Tree Frog (Elwynn Forest)",{
author="support@zygorguides.com",
description="\nCatch Flik as he runs all over the Darkmoon Faire grounds and purchase his "..
"Tree Frog Box for 1 gold.",
model={6295},
},[[
step
talk Flik##14860
|tip He's a little Orc boy running fast all over the Darkmoon Faire grounds.
|tip You will have to be quick to catch him.
|tip Talking to him will stop him for a short period of time.
buy 1 Tree Frog Box##11026 |goto Elwynn Forest 42.59,70.30
|tip This item costs 1 gold.
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Mulgore\\Sayge's Fortunes (Mulgore)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Mulgore\\Chronos Turn-Ins (Mulgore)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Mulgore\\Kerri Hicks Turn-Ins (Mulgore)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Mulgore\\Rinling Turn-Ins (Mulgore)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Mulgore\\Yebb Neblegear Turn-Ins (Mulgore)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Mulgore\\Spawn of Jubjub (Mulgore)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Mulgore\\Wood Frog (Mulgore)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Mulgore\\Tree Frog (Mulgore)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Hallow's End\\Hallow's End Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Hallow's End\\Hallow's End Daily Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Hallow's End\\Hallow's End Candy Buckets")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Harvest Festival\\Harvest Festival Quest")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Feast of Winter Veil\\Feast of Winter Veil Quest")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Lunar Festival Main Questline")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Lunar Festival\\Lunar Festival Optimized Elders Path")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Love is in the Air Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Love is in the Air\\Gift Giving")
ZygorGuidesViewer:RegisterGuide("Events Guides\\Midsummer Fire Festival\\Midsummer Fire Festival Quests",{
author="support@zygorguides.com",
condition_end=function() return completedq(11972) end,
description="\nComplete the following Midsummer Fire Festival event quests:\n\nPlaying with Fire\n"..
"Honor the Flame\nTorch Tossing\nTorch Catching\nIncense for the Festival Scorchlings\n"..
"Unusual Activity\nAn Innocent Disguise\nInform the Elder\nAhune, the Frost Lord\n"..
"Ahune is Here!\nSummon Ahune\n\n"..
"|cffff0000NOTE:|r You will need to be at least level 60 to fully complete this guide.",
},[[
step
talk Festival Loremaster##16817
accept Incense for the Summer Scorchlings##11964 |goto Stormwind City/0 38.58,61.84
step
talk Earthen Ring Elder##26221
accept Unusual Activity##11886 |goto Stormwind City/0 38.29,61.86
step
talk Master Fire Eater##25975
accept Torch Tossing##11731 |goto Stormwind City/0 39.36,62.18
step
use the Practice Torches##34862
|tip Throw them at the Torch Target Braziers nearby.
|tip You must throw the torches at the correct braziers.
|tip Throw the torches at the Torch Target Braziers when they have a floating red arrow point down above them.
|tip You will have 40 seconds to complete this before the quest fails.
|tip If you fail the quest, accept it again from the Master Fire Eater.
Hit 8 Braziers |q 11731/1 |goto Stormwind City/0 39.09,60.47
step
talk Master Fire Eater##25975
turnin Torch Tossing##11731 |goto Stormwind City/0 39.36,62.18
accept Torch Catching##11657 |goto Stormwind City/0 39.36,62.18
step
use the Unlit Torches##34833
|tip As soon as you light the torch, it will fly in the air.
|tip There will be a small round shadow on the ground indicating where the torch is flying.
|tip Follow that shadow and catch the torch.
|tip When you catch the torch, it will be thrown in the air again.
|tip Follow the shadow again and catch the torch.
|tip Do this until you've caught the torch 4 times in a row without it hitting the ground.
Catch 4 Torches in a Row |q 11657/1 |goto Stormwind City/0 39.09,60.47
step
talk Master Fire Eater##25975
turnin Torch Catching##11657 |goto Stormwind City/0 39.36,62.18
step
talk Summer Scorchling##26401
|tip Under the tent.
turnin Incense for the Summer Scorchlings##11964 |goto Elwynn Forest/0 43.49,62.50
step
talk Elwynn Forest Flame Warden##25898
|tip Under the tent.
accept Honor the Flame##11816 |goto Elwynn Forest/0 43.47,62.63
step
talk Fire Eater##25962
accept Playing with Fire##11882 |goto Elwynn Forest/0 43.69,62.23
step
talk Master Fire Eater##25975
turnin Playing with Fire##11882 |goto Stormwind City/0 39.36,62.18
step
Kill Twilight enemies around this area
collect Twilight Correspondence##35277 |q 11886/1 |goto Ashenvale/0 14.75,19.33
step
use the Totemic Beacon##35828
Watch the dialogue
_Next to you:_
talk Earthen Ring Guide##25324
turnin Unusual Activity##11886 |goto Ashenvale/0 14.49,19.22
accept An Innocent Disguise##11891 |goto Ashenvale/0 14.49,19.22
step
use the Orb of the Crawler##35237
Gain the Crab Disguise Buff |havebuff spell:46337 |q 11891 |goto Ashenvale/0 9.37,12.71
step
Watch the dialogue
Listen to the Plan of the Twilight Cultists |q 11891/1 |goto Ashenvale/0 9.07,12.41
step
use the Totemic Beacon##35828
Watch the dialogue
_Next to you:_
talk Earthen Ring Guide##25324
turnin An Innocent Disguise##11891 |goto Ashenvale/0 9.37,12.71
accept Inform the Elder##12012 |goto Ashenvale/0 9.37,12.71
step
talk Earthen Ring Elder##26221
turnin Inform the Elder##12012 |goto Stormwind City/0 38.30,61.83
accept Ahune, the Frost Lord##11955 |goto Stormwind City/0 38.30,61.83
step
talk Numa Cloudsister##25710
|tip Numa can be found inside The Slave Pens dungeon on any difficulty.
|tip She is at the beginning of the dungeon as you zone in.
|tip Ahune is level 73 elite and will require a group to kill.
turnin Ahune, the Frost Lord##11955 |goto Zangarmarsh/0 48.92,35.74
accept Ahune is Here!##11696 |goto Zangarmarsh/0 48.92,35.74
step
talk Luma Skymother##25697
|tip Luma can be found inside The Slave Pens dungeon on any difficulty.
|tip She is near the beginning of the dungeon before Mennu the Betrayer.
turnin Ahune is Here!##11696
accept Summon Ahune##11691
step
click Ice Stone
|tip The Ice Stone can be found inside The Slave Pens dungeon on any difficulty.
|tip It is near the beginning of the dungeon before Mennu the Betrayer.
turnin Summon Ahune##11691
|tip Turning in this quest will summon Ahune.
|tip Ahune will immediately attack.
step
kill Ahune##25740
|tip You will need a group for this.
click Ice Chest
|tip It spawns after he dies.
collect Shards of Ahune##35723 |q 11972 |future
step
use the Shards of Ahune##35723
accept Shards of Ahune##11972
step
talk Luma Skymother##25697
|tip Luma can be found inside The Slave Pens dungeon on any difficulty.
|tip She is near the beginning of the dungeon before Mennu the Betrayer.
turnin Shards of Ahune##11972
step
_Congratulations!_
You Completed the "Midsummer Fire Festival Quests" Guide.
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Midsummer Fire Festival\\Midsummer Fire Festival Dailies",{
author="support@zygorguides.com",
description="This guide will walk you through completing the Midsummer Fire Festival Dailies.",
},[[
step
Complete the "Midsummer Fire Festival Quests" Event Guide |complete completedq(12012)
step
label "Begin_Daily_Quests"
talk Master Fire Eater##25975
accept More Torch Tossing##11921 |goto Stormwind City/0 39.36,62.18
step
use the Practice Torches##34862
|tip Throw them at the Torch Target Braziers nearby.
|tip You must throw the torches at the correct braziers.
|tip Throw the torches at the Torch Target Braziers when they have a floating red arrow point down above them.
|tip You will have 40 seconds to complete this before the quest fails.
|tip If you fail, return to the Master Flame Eater to start again.
Hit 20 Braziers |q 11921/1 |goto Stormwind City/0 39.09,60.47
step
talk Master Fire Eater##25975
turnin More Torch Tossing##11921 |goto Stormwind City/0 39.36,62.18
step
talk Master Fire Eater##25975
accept More Torch Catching##11924 |goto Stormwind City/0 39.36,62.18
step
use the Unlit Torches##34833
|tip As soon as you light the torch, it will fly in the air.
|tip There will be a small round shadow on the ground indicating where the torch is flying.
|tip Follow that shadow and catch the torch.
|tip When you catch the torch, it will be thrown in the air again.
|tip Follow the shadow again and catch the torch.
|tip Do this until you've caught the torch 10 times in a row without it hitting the ground.
Catch 10 Torches in a Row |q 11924/1 |goto Stormwind City/0 39.09,60.47
step
talk Master Fire Eater##25975
turnin More Torch Catching##11924 |goto Stormwind City/0 39.36,62.18
step
talk Earthen Ring Elder##26221
accept Striking Back##11917 |goto Stormwind City/0 38.30,61.83 |only if level >= 22 and level <= 31
accept Striking Back##11947 |goto Stormwind City/0 38.30,61.83 |only if level >= 32 and level <= 42
accept Striking Back##11948 |goto Stormwind City/0 38.30,61.83 |only if level >= 43 and level <= 50
accept Striking Back##11952 |goto Stormwind City/0 38.30,61.83 |only if level >= 51 and level <= 59
accept Striking Back##11953 |goto Stormwind City/0 38.30,61.83 |only if level >= 60 and level <= 63
accept Striking Back##11954 |goto Stormwind City/0 38.30,61.83 |only if level >= 64
step
click Ice Stone##188149
|tip Inside the cave.
Choose _"Lay your hand on the stone"_
kill Frostwave Lieutenant##26116 |q 11917/1 |goto Ashenvale/0 9.62,12.20
|only if haveq(11917)
step
click Ice Stone##188149
Choose _"Lay your hand on the stone"_
kill Hailstone Lieutenant##26178 |q 11947/1 |goto Desolace/0 40.35,30.27
|only if haveq(11947)
step
click Ice Stone##188149
Choose _"Lay your hand on the stone"_
kill Glacial Lieutenant##26215 |q 11953/1 |goto Silithus/0 68.88,20.44
|only if haveq(11953)
step
click Ice Stone##188149
Choose _"Lay your hand on the stone"_
kill Chillwind Lieutenant##26204 |q 11948/1 |goto Stranglethorn Vale/0 21.30,23.37
|only if haveq(11948)
step
Enter the cave |goto Searing Gorge/0 21.83,36.18 < 20 |walk
click Ice Stone##188149
Choose _"Lay your hand on the stone"_
kill Frigid Lieutenant##26214 |q 11952/1 |goto Searing Gorge/0 16.02,36.86
|only if haveq(11952)
step
click Ice Stone##188149
Choose _"Lay your hand on the stone"_
kill Glacial Templar##26216 |q 11954/1 |goto Hellfire Peninsula/0 85.64,47.09
|only if haveq(11954)
step
talk Earthen Ring Elder##26221
turnin Striking Back##11917 |goto Stormwind City/0 38.30,61.83 |only if haveq(11917) or completedq(11917)
turnin Striking Back##11947 |goto Stormwind City/0 38.30,61.83 |only if haveq(11947) or completedq(11947)
turnin Striking Back##11948 |goto Stormwind City/0 38.30,61.83 |only if haveq(11948) or completedq(11948)
turnin Striking Back##11952 |goto Stormwind City/0 38.30,61.83 |only if haveq(11952) or completedq(11952)
turnin Striking Back##11953 |goto Stormwind City/0 38.30,61.83 |only if haveq(11953) or completedq(11953)
turnin Striking Back##11954 |goto Stormwind City/0 38.30,61.83 |only if haveq(11954) or completedq(11954)
step
You have completed all available dailies
|tip This guide will reset when more become available.
'|complete not completedq(11921,11924,11917,11947,11948,11952,11953,11954) |next "Begin_Daily_Quests"
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Midsummer Fire Festival\\Midsummer Fire Festival Bonfires",{
author="support@zygorguides.com",
description="This guide will walk you through collecting the Midsummer Fire Festival Bonfires.",
},[[
step
talk Elwynn Forest Flame Warden##25898
accept Honor the Flame##11816 |goto Elwynn Forest/0 43.47,62.63
step
talk Stranglethorn Vale Flame Warden##25915
accept Honor the Flame##11832 |goto Stranglethorn Vale/0 33.90,73.52
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11801 |goto Stranglethorn Vale/0 33.04,75.38
step
talk Flame Warden##25890
accept Honor the Flame##11808 |goto Blasted Lands/0 59.28,17.01
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11781 |goto Swamp of Sorrows/0 46.91,46.31
step
talk Duskwood Flame Warden##25896
accept Honor the Flame##11814 |goto Duskwood/0 73.69,54.61
step
talk Westfall Flame Warden##25910
accept Honor the Flame##11583 |goto Westfall/0 55.92,53.48
step
talk Redridge Flame Warden##25904
accept Honor the Flame##11822 |goto Redridge Mountains/0 25.23,58.96
step
talk Burning Steppes Flame Warden##25892
accept Honor the Flame##11810 |goto Burning Steppes/0 80.30,62.89
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11768 |goto Burning Steppes/0 62.20,29.13
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11766 |goto Badlands/0 4.79,49.37
step
talk Loch Modan Flame Warden##25902
accept Honor the Flame##11820 |goto Loch Modan/0 32.56,40.95
step
talk Dun Morogh Flame Warden##25895
accept Honor the Flame##11813 |goto Dun Morogh/0 46.69,46.94
step
talk Wetlands Flame Warden##25911
accept Honor the Flame##11828 |goto Wetlands/0 13.46,47.07
step
talk Arathi Flame Warden##25887
accept Honor the Flame##11804 |goto Arathi Highlands/0 50.02,44.83
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11764 |goto Arathi Highlands/0 73.90,41.75
step
talk Hillsbrad Flame Warden##25901
accept Honor the Flame##11819 |goto Hillsbrad Foothills/0 50.43,47.58
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11776 |goto Hillsbrad Foothills/0 58.29,25.06
step
talk Western Plaguelands Flame Warden##25909
accept Honor the Flame##11827 |goto Western Plaguelands/0 43.46,82.33
step
talk The Hinterlands Flame Warden##25908
accept Honor the Flame##11826 |goto The Hinterlands/0 14.34,50.07
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11784 |goto The Hinterlands/0 76.63,74.45
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11580 |goto Silverpine Forest/0 49.63,38.68
step
click Flame of Undercity##181335
|tip It is recommended that you be level capped when attempting to complete this guide step.
|tip You will enter the opposing faction's capital city.
collect Flame of Undercity##23181 |goto Undercity/0 67.58,8.77 |q 9326 |future
step
use the Flame of Undercity##23181
accept Stealing Undercity's Flame##9326
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11786 |goto Tirisfal Glades/0 57.04,51.84
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11774 |goto Ghostlands/0 46.98,26.04
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11772 |goto Eversong Woods/0 46.43,50.41
step
click Flame of Silvermoon##188129
|tip It is recommended that you be level capped when attempting to complete this guide step.
|tip You will enter the opposing faction's capital city.
collect Flame of Silvermoon##35568 |goto Silvermoon City/0 69.67,42.74 |q 11935 |future
step
use the Flame of Silvermoon##35568
accept Stealing Silvermoon's Flame##11935
step
talk Darkshore Flame Warden##25893
accept Honor the Flame##11811 |goto Darkshore/0 36.96,46.17
step
talk Teldrassil Flame Warden##25906
accept Honor the Flame##11824 |goto Teldrassil/0 55.06,60.41
step
talk Azuremyst Isle Flame Warden##25888
accept Honor the Flame##11806 |goto Azuremyst Isle/0 44.48,52.50
step
talk Bloodmyst Isle Flame Warden##25891
accept Honor the Flame##11809 |goto Bloodmyst Isle/0 55.83,67.88
step
talk Winterspring Flame Warden##25917
accept Honor the Flame##11834 |goto Winterspring/0 62.55,35.43
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Descrate this Fire!##11803 |goto Winterspring/0 59.89,35.38
step
talk Ashenvale Flame Warden##25883
accept Honor the Flame##11805 |goto Ashenvale/0 37.78,54.73
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11765 |goto Ashenvale/0 70.0,69.2
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11783 |goto The Barrens/0 52.17,27.85
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11770 |goto Durotar/0 52.02,47.10
step
click Flame of Orgrimmar##181336
|tip It is recommended that you be level capped when attempting to complete this guide step.
|tip You will enter the opposing faction's capital city.
collect Flame of Orgrimmar##23179 |goto Orgrimmar/0 46.81,38.20 |q 9324 |future
step
use the Flame of Orgrimmar##23179
accept Stealing Orgrimmar's Flame##9324
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11780 |goto Stonetalon Mountains/0 50.60,60.27
step
talk Desolace Flame Warden##25894
accept Honor the Flame##11812 |goto Desolace/0 66.12,17.09
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11769 |goto Desolace/0 26.26,77.23
step
talk Feralas Flame Warden##25899
accept Honor the Flame##11817 |goto Feralas/0 28.19,43.80
The boat to Sardor Isle can be found at [Feralas/0 43.34,42.75]
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11773 |goto Feralas/0 72.47,47.70
The boat to the mainland can be found at [Feralas/0 31.03,39.86]
step
talk Silithus Flame Warden##25914
accept Honor the Flame##11831 |goto Silithus/0 57.47,35.24
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11800 |goto Silithus/0 46.40,44.77
step
talk Tanaris Flame Warden##25916
accept Honor the Flame##11833 |goto Tanaris/0 52.76,29.37
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11802 |goto Tanaris/0 49.77,27.10
step
click Horde Bonfire##187973
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11785 |goto Thousand Needles/0 42.49,52.89
step
talk Dustwallow Marsh Flame Warden##25897
accept Honor the Flame##11815 |goto Dustwallow Marsh/0 61.82,40.46
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11771 |goto Dustwallow Marsh/0 33.28,30.87
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11777 |goto Mulgore/0 52.11,59.98
step
click Flame of Thunder Bluff##181337
|tip It is recommended that you be level capped when attempting to complete this guide step.
|tip You will enter the opposing faction's capital city.
collect Flame of Thunder Bluff##23180 |goto Thunder Bluff/0 21.48,26.01 |q 9325 |future
step
use the Flame of Thunder Bluff##23180
accept Stealing Thunder Bluff's Flame##9325
step
talk Festival Loremaster##16817
turnin Stealing Orgrimmar's Flame##9324 |goto Ironforge/0 63.80,25.31 |only if haveq(9324) or completedq(9324)
turnin Stealing Thunder Bluff's Flame##9325 |goto Ironforge/0 63.80,25.31 |only if haveq(9325) or completedq(9325)
turnin Stealing the Undercity's Flame##9326 |goto Ironforge/0 63.80,25.31 |only if haveq(9326) or completedq(9326)
turnin Stealing Silvermoon's Flame##11935 |goto Ironforge/0 63.80,25.31 |only if haveq(11935) or completedq(11935)
accept A Thief's Reward##9365 |goto Ironforge/0 63.80,25.31 |only if completedallq(9324,9325,9326,11935)
|only if haveq(9324,9325,9326,11935) or completedq(9324,9325,9326,11935)
step
talk Hellfire Peninsula Flame Warden##25900
accept Honor the Flame##11818 |goto Hellfire Peninsula/0 62.17,58.29
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11775 |goto Hellfire Peninsula/0 57.19,41.92
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11799 |goto Netherstorm/0 32.26,68.35
step
talk Netherstorm Flame Warden##25913
accept Honor the Flame##11830 |goto Netherstorm/0 31.21,62.66
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11767 |goto Blade's Edge Mountains/0 49.94,59.00
step
talk Blade's Edge Flame Warden##25889
accept Honor the Flame##11807 |goto Blade's Edge Mountains/0 41.57,65.90
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11787 |goto Zangarmarsh/0 35.52,51.79
step
talk Zangarmarsh Flame Warden##25912
accept Honor the Flame##11829 |goto Zangarmarsh/0 68.79,51.95
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11778 |goto Nagrand/0 51.08,33.94
step
talk Nagrand Flame Warden##25903
accept Honor the Flame##11821 |goto Nagrand/0 49.61,69.47
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11782 |goto Terokkar Forest/0 52.01,43.22
step
talk Terokkar Forest Flame Warden##25907
accept Honor the Flame##11825 |goto Terokkar Forest/0 54.1,55.5
step
click Horde Bonfire##194039
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11779 |goto Shadowmoon Valley/0 33.54,30.32
step
talk Shadowmoon Valley Flame Warden##25905
accept Honor the Flame##11823 |goto Shadowmoon Valley/0 39.63,54.63
]])
