local name,ZGV=...

local TA={}
ZGV.TalentAdvisor = TA
ZGV.ZTA = TA

TA.registeredBuilds = {}

TA.playerClass = select(2,UnitClass("player"))

local glyphlevels = {25,50,75}

function TA:RegisterBuild(class,name,ident,recommended,spec,talents,glyps)
	if class~=TA.playerClass then return end
	if not TA.TalentsToNumbers[class][spec] then 
		ZGV:Debug("unknown spec for %s %s - %s",class,name,spec)
		return
	end

	local build = {
		name=name,
		recommended=recommended,
		talents={},
		glyphs={},
		ident=ident,
		spec = TA.TalentsToNumbers[class][spec]
	}

	local spells = TA.TalentsToNumbers[class]
	for line in talents:gmatch("([^\n]+)\n") do
		line = line:gsub('^%s*(.-)%s*$', '%1')

		if not spells[line] then 
			ZGV:Debug("Unknown talent %s",line)
			return
		end

		table.insert(build.talents,spells[line])
	end

	local glyphids = TA.GlyphsToNumbers[class]
	for line in glyps:gmatch("([^\n]+)\n") do
		line=line:match("lyph of (.*)") or gn

		if not glyphids[line] then 
			ZGV:Debug("Unknown glyph %s",line)
			return
		end
		table.insert(build.glyphs,glyphids[line])
	end

	TA.glyphNames = {}
	local numGlyphs = GetNumGlyphs();
	for i=1,numGlyphs do
		local name, glyphType, isKnown, icon, glyphID = GetGlyphInfo(i);
		if glyphID then
			TA.glyphNames[glyphID] = name
		end
	end

	table.insert(TA.registeredBuilds,build)
end

function TA:Startup()
	-- hook functions
	hooksecurefunc("PlayerTalentTab_OnClick",function(button)
		if not ZGV.db.profile.talenton then 
			TA.MenuButton:Hide()
		return end

		if PlayerTalentFrameSpecialization:IsVisible() then
			TA.MenuButton:Hide()
		else
			TA.MenuButton:Show()
			TA.MenuButton:SetPoint("BOTTOMLEFT",PlayerTalentFrame,"BOTTOMLEFT", 221,-1)
		end
	end)

	-- setup icons
	TA.IconPool = CreateFramePool("BUTTON",nil,"ZygorIndicatorButton")
	TA.GlyphIconPool = CreateFramePool("BUTTON",nil,"ZygorIndicatorButton")
	TA.GlyphIconListPool = CreateFramePool("BUTTON",nil,"ZygorIndicatorButton")
	TA.TalentIcons = {}
	for tier = 1, MAX_NUM_TALENT_TIERS do
		local icon = TA.IconPool:Acquire()
		icon.tooltiptext = "Zygor recommends this talent"
		table.insert(TA.TalentIcons,icon)
		icon:Hide()
	end
	TA.SpecIcon = TA.IconPool:Acquire()
	TA.SpecIcon.tooltiptext = "Zygor recommends this spec"

	TA.MenuButton = ZGV.ChainCall(CreateFrame("BUTTON",nil,PlayerTalentFrame,"ZygorSpecialButton_Template"))
		:ApplySkin()
		:SetSize(32,32)
		:SetFrameLevel(611)
		:SetScript("OnClick", function() TA:ShowMenu() end)
		:Hide()
	.__END

	-- activate saved 
	local spec = C_SpecializationInfo.GetSpecialization()
	local ident = ZGV.db.char.talentbuilds[spec]
	local any,recommended
	if not ident then
		for _,build in ipairs(TA.registeredBuilds) do
			if build.spec==spec then
				any = any or build.ident
				if build.recommended then 
					recommended = build.ident 
					break
				end
			end
		end
	end
	TA:ShowSpecs()
	TA:PickBuild(ident or recommended or any)
end

function TA:ShowSpecs()
	if not ZGV.db.profile.talenton then return end

	local specname = TA.RecommendedSpecs[TA.playerClass]
	local specnum = TA.TalentsToNumbers[TA.playerClass][specname]

	local parent = _G["PlayerTalentFrameSpecializationSpecButton"..specnum]

	TA.SpecIcon:SetPoint("TOPRIGHT",parent)
	TA.SpecIcon:SetParent(parent)
	TA.SpecIcon:SetFrameStrata("DIALOG")
	TA.SpecIcon:Show()
end

function TA:ShowTalents()
	if not ZGV.db.profile.talenton then return end

	if not ZGV.db.profile.ta_toggle_icons then 
		for _,icon in ipairs(TA.TalentIcons) do icon:Hide() end
		return 
	end

	local build = TA.ActiveBuild
	if not build then return end

	for _,talent in ipairs(build.talents) do
		local row,col=talent[1],talent[2]
		local parent = _G["PlayerTalentFrameTalentsTalentRow"..row.."Talent"..col]
		local button = TA.TalentIcons[row]
		button:SetParent(parent)
		button:SetPoint("TOPRIGHT",parent,-10,0)
		button:Show()
	end
end

function TA:RecommendTalents()
	local build = TA.ActiveBuild
	if not build then return end

	for _,talent in ipairs(build.talents) do
		local row,col=talent[1],talent[2]
		local talentRow = PlayerTalentFrameTalents["tier"..row]
		local talentCol = talentRow["talent"..col]
		local talentID = talentCol:GetID()
		talentRow.selectionId = talentID
	end
	TalentFrame_Update(PlayerTalentFrameTalents, "player");
end

function TA:ShowGlyphs()
	if not ZGV.db.profile.talenton then return end

	local build = TA.ActiveBuild
	if not build then return end

	local Sockets={
		"GlyphFrameGlyph2",
		"GlyphFrameGlyph4",
		"GlyphFrameGlyph6",
		"GlyphFrameGlyph1",
		"GlyphFrameGlyph3",
		"GlyphFrameGlyph5",
	}

	TA.GlyphIconPool:ReleaseAll()

	for i,glyph in ipairs(build.glyphs) do
		local glyphName = TA.glyphNames[glyph]

		local button = TA.GlyphIconPool:Acquire()
		local parent = _G[Sockets[i]]

		button:SetParent(parent)
		button:SetFrameStrata("DIALOG")
		button:SetPoint("TOPRIGHT",parent,"TOPRIGHT",0,0)
		if glyphName then
			button.tooltiptext = "Zygor recommends: \n"..glyphName or "???"
		end
		button:Show()

	end

	TA.MenuButton:Show()
	TA.MenuButton:SetPoint("BOTTOMLEFT",PlayerTalentFrame,"BOTTOMLEFT", 451,-1)
end


function TA:SetupConfig()

end

function TA:PickBuild(ident)
	local spec = C_SpecializationInfo.GetSpecialization()
	ZGV.db.char.talentbuilds[spec] = ident

	for i,v in pairs(TA.registeredBuilds) do
		if v.ident==ident then
			TA.ActiveBuild = v
		end
	end
	TA:ShowTalents()
end

function TA:ShowMenu()
	local L=ZygorGuidesViewer_L("zta")
	local parent=TA.MenuButton
	if not TA.MenuDropdown then TA.MenuDropdown = CreateFrame("FRAME",nil,TA.MenuButton,"UIDropDownForkTemplate") end
	if DropDownForkList1 and DropDownForkList1:IsShown() and DropDownForkList1.dropdown==TA.MenuDropdown then CloseDropDownForks() return end
	UIDropDownFork_SetAnchor(TA.MenuDropdown, 0, 0, "BOTTOMLEFT", TA.MenuButton, "BOTTOMRIGHT")

	local menu = {
		{ 
			text = L['ta_toggle_icons'],
			keepShownOnClick=true, 
			checked = function() return ZGV.db.profile.ta_toggle_icons end, 
			func = function() 
				ZGV.db.profile.ta_toggle_icons = not ZGV.db.profile.ta_toggle_icons
				TA:ShowTalents()
				UIDropDownFork_Refresh(TA.MenuDropdown) 
			end 
		},
		{
			text = L['ta_select_suggested'],
			func = function() TA:RecommendTalents() end,
			notCheckable=0,
		},
		UIDropDownFork_separatorInfo,
	}


	local spec = C_SpecializationInfo.GetSpecialization()
	if not spec then return end

	for _,build in ipairs(TA.registeredBuilds) do
		if build.spec==spec then
			table.insert(menu,{
				text = build.name,
				func = function() TA:PickBuild(build.ident) UIDropDownFork_RefreshAll(TA.MenuDropdown) end,
				checked = function() 
					return ZGV.db.char.talentbuilds[spec]==build.ident 
				end,
				keepShownOnClick = true,
			})
		end
	end


	EasyFork(menu,TA.MenuDropdown,nil,0,0,"MENU",false)
	UIDropDownFork_SetWidth(TA.MenuDropdown, 300)
end


tinsert(ZGV.startups,{"MOP talent advisor",function(self)
	EventUtil.ContinueOnAddOnLoaded("Blizzard_GlyphUI", function()
		GlyphFrame:HookScript("OnShow",TA.ShowGlyphs)
		
		hooksecurefunc("GlyphFrame_UpdateGlyphList",TA.UpdateGlyphIcons)
		hooksecurefunc("HybridScrollFrame_SetOffset",function(frame) if frame==GlyphFrame.scrollFrame then TA.UpdateGlyphIcons() end end)

	end);
	EventUtil.ContinueOnAddOnLoaded("Blizzard_TalentUI", function()
		TA:Startup()
	end);
end})

function TA.UpdateGlyphIcons()
	local build = TA.ActiveBuild
	if not build then return end

	local suggested = {}
	for i,v in ipairs(build.glyphs) do suggested[v]=i end

	TA.GlyphIconListPool:ReleaseAll()

	local i, blizzbutton
	for i,blizzbutton in ipairs(GlyphFrame.scrollFrame.buttons) do
		local glyphID = blizzbutton.glyphID
		local glyphIndex = blizzbutton.glyphIndex

		if glyphID and suggested[glyphID] then
			local level = glyphlevels[(suggested[glyphID]-1)%3+1]

			local button = TA.GlyphIconListPool:Acquire()
			button:SetParent(blizzbutton)
			button:SetFrameStrata("DIALOG")
			button:SetPoint("TOPRIGHT",blizzbutton,"TOPRIGHT",0,-3)
			button.tooltiptext = "Zygor recommends this glyph at level "..level
			button:Show()
		end
	end
end

function TA:Toggle()
	if not TA.MenuButton then return end -- called before startup

	if ZGV.db.profile.talenton then
		TA:ShowSpecs()
		TA:ShowTalents()

		if PlayerTalentFrameTalents:IsVisible() then
			TA.MenuButton:SetPoint("BOTTOMLEFT",PlayerTalentFrame,"BOTTOMLEFT", 221,-1)
			TA.MenuButton:Show()
		end
		if GlyphFrame and GlyphFrame:IsVisible() then
			TA.MenuButton:SetPoint("BOTTOMLEFT",PlayerTalentFrame,"BOTTOMLEFT", 451,-1)
			TA.MenuButton:Show()
			TA.UpdateGlyphIcons()
			TA:ShowGlyphs() 
		end
		if PlayerTalentFrameSpecialization:IsVisible() then
			TA.MenuButton:Hide()
		end
			

	else
		TA.MenuButton:Hide()
		TA.SpecIcon:Hide()

		for _,button in pairs(TA.TalentIcons) do button:Hide() end
		TA.GlyphIconPool:ReleaseAll()	
		TA.GlyphIconListPool:ReleaseAll()
	end
end