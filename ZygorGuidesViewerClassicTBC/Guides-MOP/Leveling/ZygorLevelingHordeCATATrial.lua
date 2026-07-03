local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Horde" then return end
if ZGV:DoMutex("LevelingHCATA") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Startup Guide Wizard")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Cataclysm 80-85\\Mount Hyjal (80-82)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Cataclysm 80-85\\Vashj'ir (80-82)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Cataclysm 80-85\\Deepholm (82-83)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Cataclysm 80-85\\Uldum (83-84)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Leveling Guides\\Cataclysm 80-85\\Twilight Highlands (84-85)")
