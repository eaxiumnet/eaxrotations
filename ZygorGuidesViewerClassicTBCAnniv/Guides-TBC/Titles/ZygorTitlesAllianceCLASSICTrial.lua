local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Alliance" then return end
if ZGV:DoMutex("TitlesACLASSIC") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuidePlaceholder("Titles\\Burning Crusade Titles\\Dungeons & Raids\\Champion of the Naaru")
ZygorGuidesViewer:RegisterGuidePlaceholder("Titles\\Burning Crusade Titles\\Dungeons & Raids\\Hand of A'dal")
ZygorGuidesViewer:RegisterGuidePlaceholder("Titles\\Burning Crusade Titles\\Reputation\\of the Shattered Sun")
