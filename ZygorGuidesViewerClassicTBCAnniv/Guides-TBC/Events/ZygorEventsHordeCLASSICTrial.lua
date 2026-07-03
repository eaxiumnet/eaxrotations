local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Horde" then return end
if ZGV:DoMutex("EventsH") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Brewfest Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Brewfest\\Brewfest Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Children's Week\\Children's Week Main Questline")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Sayge's Fortunes (Elwynn Forest)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Chronos Turn-Ins (Elwynn Forest)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Kerri Hicks Turn-Ins (Elwynn Forest)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Rinling Turn-Ins (Elwynn Forest)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Yebb Neblegear Turn-Ins (Elwynn Forest)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Spawn of Jubjub (Elwynn Forest)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Wood Frog (Elwynn Forest)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Events Guides\\Darkmoon Faire\\Elwynn Forest\\Tree Frog (Elwynn Forest)")
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Mulgore\\Sayge's Fortunes (Mulgore)",{
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
Gain the "Sayge's Dark Fortune of Agility" Buff |havebuff spell:23736 |goto Mulgore 36.92,38.37 |next "Use_Darkmoon_Faire_Fortune"
step
label "Intelligence_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I turn over the man to my liege for punishment, as he has broken the law of the land and it is my sworn duty to enforce it."_
Select _"I quietly ignore the insult."_
Gain the "Sayge's Dark Fortune of Intelligence" Buff |havebuff spell:23766 |goto Mulgore 36.92,38.37 |next "Use_Darkmoon_Faire_Fortune"
step
label "Spirit_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I turn over the man to my liege for punishment, as he has broken the law of the land and it is my sworn duty to enforce it."_
Select _"I confront the ruler on his malicious behavior, upholding my liege's honor at the risk of any future diplomacy."_
Gain the "Sayge's Dark Fortune of Spirit" Buff |havebuff spell:23738 |goto Mulgore 36.92,38.37 |next "Use_Darkmoon_Faire_Fortune"
step
label "Stamina_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I confiscate the corn he has stolen, warn him that stealing is a path towards doom and destruction, but I let him go to return to his family."_
Select _"I would speak against my brother joining the order, rushing a permanent breech in our relationship."_
Gain the "Sayge's Dark Fortune of Stamina" Buff |havebuff spell:23737 |goto Mulgore 36.92,38.37 |next "Use_Darkmoon_Faire_Fortune"
step
label "Strength_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I confiscate the corn he has stolen, warn him that stealing is a path towards doom and destruction, but I let him go to return to his family."_
Select _"I would speak for my brother joining the order, potentially risking the safety of the order."_
Gain the "Sayge's Dark Fortune of Strength" Buff |havebuff spell:23735 |goto Mulgore 36.92,38.37 |next "Use_Darkmoon_Faire_Fortune"
step
label "Armor_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I slay the man on the spot as my liege would expect me to do, as he is nothing more than a thief and a liar."_
Select _"I risk my own life and free him so that he may prove his innocence."_
Gain the "Sayge's Dark Fortune of Armor" Buff |havebuff spell:23767 |goto Mulgore 36.92,38.37 |next "Use_Darkmoon_Faire_Fortune"
step
label "Resistance_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I slay the man on the spot as my liege would expect me to do, as he is nothing more than a thief and a liar."_
Select _"I execute him as per my liege's instructions, but doing so in as painless of a way as possible."_
Gain the "Sayge's Dark Fortune of Resistance" Buff |havebuff spell:23769 |goto Mulgore 36.92,38.37 |next "Use_Darkmoon_Faire_Fortune"
step
label "Damage_Buff"
talk Sayge##14822
Choose _"I am ready to discover where my fortune lies!"_
Select _"I slay the man on the spot as my liege would expect me to do, as he is nothing more than a thief and a liar."_
Select _"I execute him as per my liege's instructions, and do it in such a manner that he suffers painfully before he dies as retribution for his crimes against my people."_
Gain the "Sayge's Dark Fortune of Damage" Buff |havebuff spell:23768 |goto Mulgore 36.92,38.37 |next "Use_Darkmoon_Faire_Fortune"
step
label "Use_Darkmoon_Faire_Fortune"
talk Sayge##14822
Select _"I'd love to get one of those written fortunes you mentioned!"_
collect 1 Darkmoon Faire Fortune##19422 |goto Mulgore 36.92,38.37
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
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Mulgore\\Chronos Turn-Ins (Mulgore)",{
author="support@zygorguides.com",
description="\nExchange various Leatherworking crafted items with Chronos for prize tickets at the Darkmoon Faire.",
model={14875},
},[[
step
collect 3 Embossed Leather Boots##2309 |n
|tip Create them with Leatherworking or purchase them from the Auction House.
talk Chronos##14833
accept Carnival Boots##7881 |goto Mulgore 36.15,35.18 |or
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
accept Carnival Jerkins##7882 |goto Mulgore 36.15,35.18 |or
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
accept The World's Largest Gnome!##7883 |goto Mulgore 36.15,35.18 |or
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
accept Crocolisk Boy and the Bearded Murloc##7884 |goto Mulgore 36.15,35.18 |or
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
accept Armor Kits##7885 |goto Mulgore 36.15,35.18
step
collect 8 Rugged Armor Kit##15564 |n
|tip Create them with Leatherworking or purchase them from the Auction House.
talk Chronos##14833
accept More Armor Kits##7941 |goto Mulgore 36.15,35.18 |or
|tip From this point on, you can continue turning in Rugged Armor Kits.
|tip Each of these turnins will award 20 Darkmoon Faire Prize Tickets.
|tip Each turnin requires 8 Rugged Armor Kits and grants 100 reputation with the Darkmoon Faire.
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Mulgore\\Kerri Hicks Turn-Ins (Mulgore)",{
author="support@zygorguides.com",
description="\nExchange various Blacksmithing crafted items with Kerri Hicks for prize tickets at the Darkmoon Faire.",
model={14876},
},[[
step
collect 10 Coarse Weightstone##3240 |n
|tip Create them with Blacksmithing or purchase them from the Auction House.
talk Kerri Hicks##14832
accept Coarse Weightstone##7889 |goto Mulgore 37.87,39.83 |or
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
accept Heavy Grinding Stone##7890 |goto Mulgore 37.87,39.83 |or
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
accept Green Iron Bracers##7891 |goto Mulgore 37.87,39.83 |or
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
accept Big Black Mace##7892 |goto Mulgore 37.87,39.83 |or
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
accept Rituals of Strength##7893 |goto Mulgore 37.87,39.83
step
collect 8 Dense Grinding Stone##12644 |n
|tip Create them with Blacksmithing or purchase them from the Auction House.
talk Kerri Hicks##14832
accept More Dense Grinding Stones##7939 |goto Mulgore 37.87,39.83 |or
|tip From this point on, you can continue turning in Dense Grinding Stones.
|tip Each of these turnins will award 20 Darkmoon Faire Prize Tickets.
|tip Each turnin requires 8 Dense Grinding Stones and grants 100 reputation with the Darkmoon Faire.
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Mulgore\\Rinling Turn-Ins (Mulgore)",{
author="support@zygorguides.com",
description="\nExchange various Engineering crafted items with Rinling for prize tickets at the Darkmoon Faire.",
model={14877},
},[[
step
collect 5 Copper Modulator##4363 |n
|tip Create them with Engineering or purchase them from the Auction House.
|tip They also have a small chance to drop from mobs in the Gnomeregan dungeon.
talk Rinling##14841
accept Copper Modulator##7894 |goto Mulgore 37.12,37.31 |or
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
accept Whirring Bronze Gizmo##7895 |goto Mulgore 37.12,37.31 |or
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
accept Green Fireworks##7896 |goto Mulgore 37.12,37.31 |or
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
accept Mechanical Repair Kits##7897 |goto Mulgore 37.12,37.31 |or
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
accept Thorium Widget##7898 |goto Mulgore 37.12,37.31
step
collect 6 Thorium Widget##15994 |n
|tip Create them with Engineering or purchase them from the Auction House.
talk Rinling##14841
accept More Thorium Widgets##7942 |goto Mulgore 37.12,37.31 |or
|tip From this point on, you can continue turning in Thorium Widgets.
|tip Each of these turnins will award 20 Darkmoon Faire Prize Tickets.
|tip Each turnin requires 6 Thorium Widgets and grants 100 reputation with the Darkmoon Faire.
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Mulgore\\Yebb Neblegear Turn-Ins (Mulgore)",{
author="support@zygorguides.com",
description="\nExchange various Farmed items with Yebb Neblegear for prize tickets at the Darkmoon Faire.",
model={14856},
},[[
step
Kill Savannah enemies around this area
|tip You can find them all over around Crossroads and to its northern area.
collect 5 Small Furry Paw##5134 |goto The Barrens 50.21,21.82 |n
talk Yebb Neblegear##14829
accept Small Furry Paws##7899 |goto Mulgore 37.54,39.63 |or
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
accept Torn Bear Pelts##7900 |goto Mulgore 37.54,39.63 |or
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
accept Soft Bushy Tails##7901 |goto Mulgore 37.54,39.63 |or
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
accept Vibrant Plumes##7902 |goto Mulgore 37.54,39.63 |or
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
accept Glowing Scorpid Blood##8222 |goto Mulgore 37.54,39.63
step
Kill Stonelash enemies around this area
|tip You can find them all over central and southern Silithus.
collect 10 Glowing Scorpid Blood##19933 |goto Silithus 44.81,54.50 |n
talk Yebb Neblegear##14829
accept More Glowing Scorpid Blood##8223 |goto Mulgore 37.54,39.63
|tip From this point on, you can continue turning in Glowing Scorpid Blood.
|tip Each of these turnins will award 20 Darkmoon Faire Prize Tickets.
|tip Each turnin requires 10 Glowing Scorpid Blood and grants 100 reputation with the Darkmoon Faire.
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Mulgore\\Spawn of Jubjub (Mulgore)",{
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
accept Spawn of Jubjub##7946 |goto Mulgore 35.87,35.24
|tip This quest will be available after Jubjub appears.
step
use the Unhatched Jubling Egg##19462
|tip It will take seven days for the egg to mature enough to hatch.
collect 1 A Jubling's Tiny Home##19450
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Mulgore\\Wood Frog (Mulgore)",{
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
buy 1 Wood Frog Box##11027 |goto Mulgore 36.72,37.36
|tip This item costs 1 gold and has a limited quantity of 1.
|tip It respawns in approximately 20 minutes.
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Darkmoon Faire\\Mulgore\\Tree Frog (Mulgore)",{
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
buy 1 Tree Frog Box##11026 |goto Mulgore 36.72,37.36
|tip This item costs 1 gold.
]])
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
talk Flame Eater##25994
accept Playing with Fire##11915 |goto Durotar/0 52.41,47.32
step
talk Durotar Flame Keeper##25929
accept Honor the Flame##11846 |goto Durotar/0 52.18,47.32
step
talk Master Flame Eater##26113
turnin Playing with Fire##11915 |goto Orgrimmar/0 47.15,38.14
accept Torch Tossing##11922 |goto Orgrimmar/0 47.15,38.14
step
use the Practice Torches##34862
|tip Throw them at the Torch Target Braziers nearby.
|tip You must throw the torches at the correct braziers.
|tip Throw the torches at the Torch Target Braziers when they have a floating red arrow point down above them.
|tip You will have 40 seconds to complete this before the quest fails.
|tip If you fail the quest, accept it again from the Master Flame Eater.
Hit 8 Braziers |q 11922/1 |goto Orgrimmar/0 46.69,37.76
step
talk Master Flame Eater##26113
turnin Torch Tossing##11922 |goto Orgrimmar/0 47.15,38.14
accept Torch Catching##11923 |goto Orgrimmar/0 47.15,38.14
step
use the Unlit Torches##34833
|tip As soon as you light the torch, it will fly in the air.
|tip There will be a small round shadow on the ground indicating where the torch is flying.
|tip Follow that shadow and catch the torch.
|tip When you catch the torch, it will be thrown in the air again.
|tip Follow the shadow again and catch the torch.
|tip Do this until you've caught the torch 4 times in a row without it hitting the ground.
Catch 4 Torches in a Row |q 11923/1 |goto Orgrimmar/0 46.96,37.78
step
talk Master Flame Eater##26113
turnin Torch Catching##11923 |goto Orgrimmar/0 47.15,38.14
step
talk Festival Talespinner##16818
accept Incense for the Festival Scorchlings##11966 |goto Orgrimmar/0 46.75,38.03
step
talk Earthen Ring Elder##26221
accept Unusual Activity##11886 |goto Orgrimmar/0 46.44,38.69
step
Kill Twilight enemies around this area
collect Twilight Correspondence##35277 |q 11886/1 |goto Ashenvale/0 15.58,19.99
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
Listen to the Plan of the Twilight Cultists |q 11891/1 |goto Ashenvale/0 9.37,12.71
step
use the Totemic Beacon##35828
Watch the dialogue
_Next to you:_
talk Earthen Ring Guide##25324
turnin An Innocent Disguise##11891 |goto Ashenvale/0 9.37,12.71
accept Inform the Elder##12012 |goto Ashenvale/0 9.37,12.71
step
talk Earthen Ring Elder##26221
turnin Inform the Elder##12012 |goto Orgrimmar/0 46.44,38.69
accept Ahune, the Frost Lord##11955 |goto Orgrimmar/0 46.44,38.69
step
talk Festival Scorchling##26520
turnin Incense for the Festival Scorchlings##11966 |goto Durotar/0 52.15,47.25
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
description="\nThis guide section will walk you through completing the dailies for the Midsummer Fire Festival event.",
},[[
step
Complete the "Midsummer Fire Festival Quests" Event Guide |complete completedq(12012)
step
label "Begin_Daily_Quests"
talk Master Flame Eater##26113
|tip Accepting this quest will start a timer.
accept More Torch Tossing##11926 |goto Orgrimmar/0 47.15,38.14
step
use the Practice Torches##34862
|tip Throw them at the Torch Target Braziers nearby.
|tip You must throw the torches at the correct braziers.
|tip Throw the torches at the Torch Target Braziers when they have a floating red arrow point down above them.
|tip You will have 40 seconds to complete this before the quest fails.
|tip If you fail, return to the Master Flame Eater to start again.
Hit 20 Braziers |q 11926/1 |goto Orgrimmar/0 46.50,37.90
step
talk Master Flame Eater##26113
turnin More Torch Tossing##11926 |goto Orgrimmar/0 47.15,38.14
step
talk Master Flame Eater##26113
|tip Accepting this quest will start a timer.
accept More Torch Catching##11925 |goto Orgrimmar/0 47.15,38.14
step
use the Unlit Torches##34833
|tip As soon as you light the torch, it will fly in the air.
|tip There will be a small round shadow on the ground indicating where the torch is flying.
|tip Follow that shadow and catch the torch.
|tip When you catch the torch, it will be thrown in the air again.
|tip Follow the shadow again and catch the torch.
|tip Do this until you've caught the torch 10 times in a row without it hitting the ground.
Catch 10 Torches in a Row |q 11925/1 |goto Orgrimmar/0 46.16,36.90
step
talk Master Flame Eater##26113
turnin More Torch Catching##11925 |goto Orgrimmar/0 47.15,38.14
step
talk Earthen Ring Elder##26221
accept Striking Back##11917 |goto Orgrimmar/0 46.44,38.70 |only if level >= 22 and level <= 31
accept Striking Back##11947 |goto Orgrimmar/0 46.44,38.70 |only if level >= 32 and level <= 42
accept Striking Back##11948 |goto Orgrimmar/0 46.44,38.70 |only if level >= 43 and level <= 50
accept Striking Back##11952 |goto Orgrimmar/0 46.44,38.70 |only if level >= 51 and level <= 59
accept Striking Back##11953 |goto Orgrimmar/0 46.44,38.70 |only if level >= 60 and level <= 63
accept Striking Back##11954 |goto Orgrimmar/0 46.44,38.70 |only if level >= 64
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
turnin Striking Back##11917 |goto Orgrimmar/0 46.44,38.70 |only if haveq(11917) or completedq(11917)
turnin Striking Back##11947 |goto Orgrimmar/0 46.44,38.70 |only if haveq(11947) or completedq(11947)
turnin Striking Back##11948 |goto Orgrimmar/0 46.44,38.70 |only if haveq(11948) or completedq(11948)
turnin Striking Back##11952 |goto Orgrimmar/0 46.44,38.70 |only if haveq(11952) or completedq(11952)
turnin Striking Back##11953 |goto Orgrimmar/0 46.44,38.70 |only if haveq(11953) or completedq(11953)
turnin Striking Back##11954 |goto Orgrimmar/0 46.44,38.70 |only if haveq(11954) or completedq(11954)
step
You have completed all available dailies
|tip This guide will reset when more become available.
'|complete not completedq(11926,11925,11917,11947,11948,11952,11953,11954) |next "Begin_Daily_Quests"
]])
ZygorGuidesViewer:RegisterGuide("Events Guides\\Midsummer Fire Festival\\The Fires of Azeroth\\Midsummer Fire Festival Bonfires",{
description="\nThis guide will walk you through obtaining the Flame Keeper of Kalimdor achievement.",
},[[
step
talk Mulgore Flame Keeper##25936
accept Honor the Flame##11852 |goto Mulgore/0 51.93,59.82
step
talk The Barrens Flame Keeper##25943
accept Honor the Flame##11859 |goto The Barrens/0 52.22,28.05
step
talk Dustwallow Marsh Flame Keeper##25930
accept Honor the Flame##11847 |goto Dustwallow Marsh/0 33.43,30.92
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11744 |goto Dustwallow Marsh/0 61.97,40.50
step
talk Thousand Needles Flame Warden##25945
accept Honor the Flame##11861 |goto Thousand Needles/0 42.19,53.00
step
talk Tanaris Flame Keeper##25921
accept Honor the Flame##11838 |goto Tanaris/0 49.83,26.93
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11762 |goto Tanaris/0 52.68,30.11
step
talk Silithus Flame Keeper##25919
accept Honor the Flame##11836 |goto Silithus/0 46.45,44.45
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11760 |goto Silithus/0 57.77,35.07
step
talk Feralas Flame Keeper##25932
accept Honor the Flame##11849 |goto Feralas/0 72.38,47.80
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11746 |goto Feralas/0 28.10,43.84
The boat to Sardor Isle can be found at [Feralas/0 43.34,42.75]
step
talk Desolace Flame Keeper##25928
accept Honor the Flame##11845 |goto Desolace/0 26.14,76.91
The boat to the mainland can be found at [Desolace/0 31.03,39.86]
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11741 |goto Desolace/0 65.87,17.02
step
talk Stonetalon Flame Keeper##25940
accept Honor the Flame##11856 |goto Stonetalon Mountains/0 50.49,60.46
step
talk Ashenvale Flame Keeper##25884
accept Honor the Flame##11841 |goto Ashenvale/0 70.15,69.30
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11734 |goto Ashenvale/0 37.83,55.08
step
talk Durotar Flame Keeper##25929
accept Honor the Flame##11846 |goto Durotar/0 52.18,47.32
step
talk Winterspring Flame Keeper##25922
accept Honor the Flame##11839 |goto Winterspring/0 59.87,35.65
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11763 |goto Winterspring/0 62.65,35.31
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11740 |goto Darkshore/0 37.12,46.00
step
click Flame of Darnassus##181334
|tip It is recommended that you be level capped when attempting to complete this guide step.
|tip You will enter the opposing faction's capital city.
collect Flame of Darnassus##23184 |goto Teldrassil/0 56.54,92.22 |q 9332 |future
The boat to Teldrassil can be found at [Teldrassil/0 33.18,40.13]
step
use the Flame of Darnassus##23184
accept Stealing Darnassus's Flame##9332
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11753 |goto Teldrassil/0 54.83,60.35
step
Enter the building |goto The Exodar/0 74.40,53.95 < 20 |walk
click Flame of the Exodar##188128
|tip Inside The Exodar.
|tip It is recommended that you be level capped when attempting to complete this guide step.
|tip You will enter the opposing faction's capital city.
collect Flame of the Exodar##35569 |goto The Exodar/0 40.96,26.04 |q 11933 |future
The boat back to Darkshore can be found at [Teldrassil/0 54.87,96.73]
The boat to Azuremyst Isle can be found at [Darkshore/0 30.74,40.99]
step
use the Flame of the Exodar##35569
accept Stealing the Exodar's Flame##11933
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11735 |goto Azuremyst Isle/0 44.71,52.58
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11738 |goto Bloodmyst Isle/0 55.99,68.47
step
talk Stranglethorn Vale Flame Keeper##25920
accept Honor the Flame##11837 |goto Stranglethorn Vale/0 32.93,75.22
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11761 |goto Stranglethorn Vale/0 33.81,73.38
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11737 |goto Blasted Lands/0 58.87,17.23
step
talk Swamp of Sorrows Flame Keeper##25941
accept Honor the Flame##11857 |goto Swamp of Sorrows/0 46.70,46.98
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11743 |goto Duskwood/0 73.41,55.08
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11581 |goto Westfall/0 56.16,53.93
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11745 |goto Elwynn Forest/0 43.07,62.95
step
click Flame of Stormwind##181332
|tip It is recommended that you be level capped when attempting to complete this guide step.
|tip You will enter the opposing faction's capital city.
collect Flame of Stormwind##23182 |goto Stormwind City/0 38.97,61.83 |q 9330 |future
step
use the Flame of Stormwind##23182
accept Stealing Stormwind's Flame##9330
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11751 |goto Redridge Mountains/0 24.99,59.51
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11739 |goto Burning Steppes/0 80.41,62.26
step
talk Burning Steppes Flame Keeper##25927
accept Honor the Flame##11844 |goto Burning Steppes/0 61.77,29.06
step
talk Badlands Flame Keeper##25925
accept Honor the Flame##11842 |goto Badlands/0 4.70,48.61
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11749 |goto Loch Modan/0 32.50,40.55
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11742 |goto Dun Morogh/0 46.68,46.55
step
click Flame of Ironforge##181333
|tip It is recommended that you be level capped when attempting to complete this guide step.
|tip You will enter the opposing faction's capital city.
collect Flame of Ironforge##23183 |goto Ironforge/0 64.39,25.58 |q 9331 |future
step
use the Flame of Ironforge##23183
accept Stealing Ironforge's Flame##9331
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11757 |goto Wetlands/0 13.31,47.25
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11732 |goto Arathi Highlands/0 50.39,44.90
step
talk Arathi Flame Keeper##25923
accept Honor the Flame##11840 |goto Arathi Highlands/0 74.22,41.47
step
click Alliance Bonfire##187931
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11748 |goto Hillsbrad Foothills/0 50.43,47.58
step
talk Hillsbrad Flame Keeper##25935
accept Honor the Flame##11853 |goto Hillsbrad Foothills/0 58.58,25.43
step
talk Silverpine Forest Flame Keeper##25939
accept Honor the Flame##11584 |goto Silverpine Forest/0 49.69,38.31
step
talk Eversong Woods Flame Keeper##25931
accept Honor the Flame##11848 |goto Eversong Woods/0 46.40,50.60
step
talk Ghostlands Flame Keeper##25933
accept Honor the Flame##11850 |goto Ghostlands/0 46.90,26.34
step
talk The Hinterlands Flame Keeper##25944
accept Honor the Flame##11860 |goto The Hinterlands/0 76.64,74.96
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11755 |goto The Hinterlands/0 14.53,49.93
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11756 |goto Western Plaguelands/0 43.58,82.52
step
talk Tirisfal Glades Flame Keeper##25946
accept Honor the Flame##11862 |goto Tirisfal Glades/0 57.23,51.75
step
talk Festival Talespinner##16818
turnin Stealing Darnassus's Flame##9332 |goto Undercity/0 67.62,8.29 |only if haveq(9332) or completedq(9332)
turnin Stealing the Exodar's Flame##11933 |goto Undercity/0 67.62,8.29 |only if haveq(11933) or completedq(11933)
turnin Stealing Stormwind's Flame##9330 |goto Undercity/0 67.62,8.29 |only if haveq(9330) or completedq(9330)
turnin Stealing Ironforge's Flame##9331 |goto Undercity/0 67.62,8.29 |only if haveq(9331) or completedq(9331)
accept A Thief's Reward##9339 |goto Undercity/0 67.62,8.29 |only if completedallq(9332,11933,9330,9331)
|only if haveq(9332,11933,9330,9331) or completedq(9332,11933,9330,9331)
step
talk Hellfire Peninsula Flame Keeper##25934
accept Honor the Flame##11851 |goto Hellfire Peninsula/0 57.11,42.04
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11747 |goto Hellfire Peninsula/0 61.97,58.33
step
talk Netherstorm Flame Keeper##25918
accept Honor the Flame##11835 |goto Netherstorm/0 32.11,68.31
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11759 |goto Netherstorm/0 31.06,62.76
step
talk Blade's Edge Flame Keeper##25926
accept Honor the Flame##11843 |goto Blade's Edge Mountains/0 49.92,58.66
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11736 |goto Blade's Edge Mountains/0 41.78,65.96
step
talk Zangarmarsh Flame Keeper##25947
accept Honor the Flame##11863 |goto Zangarmarsh/0 35.44,51.61
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11758 |goto Zangarmarsh/0 68.63,52.31
step
talk Nagrand Flame Keeper##25937
accept Honor the Flame##11854 |goto Nagrand/0 50.91,34.14
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11750 |goto Nagrand/0 49.72,69.61
step
talk Terokkar Forest Flame Keeper##25942
accept Honor the Flame##11858 |goto Terokkar Forest/0 52.03,42.93
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11754 |goto Terokkar Forest/0 54.18,55.42
step
talk Shadowmoon Valley Flame Keeper##25938
accept Honor the Flame##11855 |goto Shadowmoon Valley/0 33.40,30.53
step
click Alliance Bonfire##194036
|tip Completing this will flag you for PvP combat for five minutes.
accept Desecrate this Fire!##11752 |goto Shadowmoon Valley/0 39.65,54.37
]])
