local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Alliance" then return end
if ZGV:DoMutex("DungeonAMOP") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Pandaria Dungeons\\Gate of the Setting Sun")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Pandaria Dungeons\\Mogu'shan Palace")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Pandaria Dungeons\\Scarlet Halls (MOP)")
ZygorGuidesViewer:RegisterGuide("Dungeon Guides\\Pandaria Dungeons\\Scarlet Monastery (MOP)",{
mapid=302,
achieveid={6761},
patch='50004',
condition_suggested=function() return level>=35 and level<=35 end,
description="This guide will walk you through the Scarlet Monastery dungeon.",
mopready=true
},[[
step
Press _I_ and queue for Scarlet Monastery or enter the dungeon with your group |goto Scarlet Monastery/1 74.20,46.20 < 100 |c
step
talk Hooded Crusader##64838
accept Blades of the Anointed##31515 |goto Scarlet Monastery/1 72.70,47.00
step
Clear the trash up to this point. |goto Scarlet Monastery/1 30.80,46.20
|tip The Piles of Corpses should be killed first or you will be fighting zombies much longer than is necessary.
|confirm
step
kill Thalnos the Soulrender##59789
|tip Thalnos will Raise Fallen Crusaders. This ability summons zombies that the tank needs to pick up. When the Fallen Crusaders hit you, they leave behind Mind Rot which is a DoT that can stack.
|tip He also summons Spirit Gales often. These are puddles on the ground that should not be stepped in. This ability is interruptable.
|tip Evict Soul is a debuff that Thalnos throws on a random party member. This DoT needs to be dispelled as quickly as possible.
|tip He will also use Summon Empowering Spirit. This ability will summon an add that DPS should kill as quickly as they can. If this add reaches a Fallen Crusader's corpse, it will spawn an Empowered Zombie.
|tip Empowered Zombies are large zombies which need to be tanked. They cannot be killed without great focus.
Defeat Thalnos the Soulrender |scenariogoal 1/19270 |goto Scarlet Monastery/1 26.10,45.40
step
click Blade of the Anointed##214296
collect Blade of the Anointed##87282 |q 31515/1 |goto Scarlet Monastery/1 20.60,45.90
step
map Scarlet Monastery/1
path follow strict;loop off;ants straight
path	34.50,52.50	34.80,78.20	39.40,81.70
path	48.50,90.30
Follow the path. |goto Scarlet Monastery/2
|tip Opening the world map will display an ant trail guiding you through the current floor.
confirm
step
talk Blade of the Anointed##64855
turnin Blades of the Anointed##31515 |goto Scarlet Monastery/2 49.10,24.50
accept Unto Dust Thou Shalt Return##31516 |goto Scarlet Monastery/2 49.10,24.50
step
map Scarlet Monastery/2
path follow strict;loop off;ants straight
path	45.70,31.90	43.90,36.30	49.20,43.30
Follow the path. |goto Scarlet Monastery/2
|tip Opening the world map will display an ant trail guiding you through the current floor.
confirm
step
kill Brother Korloff##59223
Brother Korloff loves to play with fire.
|tip Flying Kick will hit a random party member knocking them back, make sure they aren't knocked into any uncleared trash.
|tip Blazing Fists is a series of punches Korloff makes in front of him, have the tank take a step back and make sure all party members are behind Korloff.
|tip Firestorm Kick is whirlwind of flame, do not stand in it.
|tip Scorched Earth is a fire trail that Korloff leaves behind him, do not stand in it.
|tip Every 10%, Korloff wil gain a stack of Rising Flame. These increase his fire damage done by 10% per stack.
|tip The boss will patrol between two groups. Pull each group carefully, keeping in mind the boss' patrol.
Defeat Brother Korloff |scenariogoal 1/19271 |goto Scarlet Monastery/2 49.40,52.30
step
Enter the cathedral here |goto Scarlet Monastery/2 49.10,57.10 < 5
confirm
step
Before encountering the boss, make sure you kill the trash within the cathedral.
|tip This includes the main room and both wings.
|confirm
step
kill Commander Durand##60040
kill High Inquisitor Whitemane##3977
_Phase 1_
|tip Commander Durand will fight you alone.
|tip He uses Flash of Steel and Dashing Strike. Both of these abilities cause him to jump to party members quickly, but neither do much damage as long as the group is spread out.
|tip When Durand dies, phase 2 begins.
_Phase 2_
|tip High Inquisitor Whitemane will come and and begin to fight.
|tip She will cast Power Word: Shield, Smite and Heal. Make sure to interrupt Smite and Heal.
|tip Whitemane will also try casting Mass Resurrection. DO NOT LET THIS CAST FINISH!! If this cast finishes, all corpses within 100 yards will resurrect and aggro.
|tip After you weaken her she will cast Deep Sleep. This puts the entire party to sleep for 10 seconds, during this time she will resurrect Durand.
_Phase 3_
|tip Now you will have to fight the two together.
|tip Kill Whitemane first, make sure to interrupt Smite and Heal
|tip Stay spread out for Durand.
Use the Blades of the Anointed on High Inquisitor Whitemane's corpse. |use Blades of the Anointed##87390 |only if haveq(31516)
Blades of the Anointed thrust into Whitemane's corpse. |q 31516/1 |only if haveq(31516)
Defeat Commander Durand and High Inquisitor Whitemane |scenariogoal 1/34443 |goto Scarlet Monastery/2 49.20,80.70
step
talk Hooded Crusader##64842
turnin Unto Dust Thou Shalt Return##31516 |goto Scarlet Monastery/2 48.90,78.90
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Pandaria Dungeons\\Scholomance (MOP)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Pandaria Dungeons\\Shado-Pan Monastery")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Pandaria Dungeons\\Siege of Niuzao Temple")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Pandaria Dungeons\\Stormstout Brewery")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Pandaria Dungeons\\Temple of the Jade Serpent")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Pandaria Raids\\Heart of Fear")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Pandaria Raids\\Mogu'shan Vaults")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Pandaria Raids\\Terrace of Endless Spring")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Pandaria Raids\\Siege of Orgrimmar")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dungeon Guides\\Pandaria Raids\\Throne of Thunder")
