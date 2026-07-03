local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if ZGV:DoMutex("DailiesCCATA") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Cataclysm\\Hyjal\\Mount Hyjal Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Cataclysm\\Deepholm\\Therazane Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Cataclysm\\Uldum\\Uldum Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Mount Hyjal\\Molten Front Campaign")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Mount Hyjal\\Molten Front Daily Quests")
