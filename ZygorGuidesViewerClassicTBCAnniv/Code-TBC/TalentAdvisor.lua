--[[
Rule: on every talent purchase, figure out in how many talents the player can get back on track
by comparing his prospective build to subbuilds of order 1..n

Don't warn if the distance is less than their REMAINING talents after the purchase-to-be
--]]

-- #GLOBALS ChatFontSmall,CreateFrame,GameTooltip,GetCVar,GetCVarBool,HideUIPanel,LibStub,NO,QuickDumpStatusAndSuggestion,self,SetCVar,ShowUIPanel,StaticPopup_Show,StaticPopupDialogs,SystemFont_Tiny,UIParent,UISpecialFrames,UnitClass,UnitLevel,UnitName,YES
-- #GLOBALS UnitCharacterPoints
-- #GLOBALS ToggleTalentFrame,TalentFrame,TalentFrame_LoadUI,TalentFrame_Update,TalentMicroButton
-- #GLOBALS PLAYER_TALENTS_PER_TIER

-- #GLOBALS (API confirmed),GetNumTalents,GetNumTalentTabs,GetTalentInfo,GetTalentPrereqs,GetTalentTabInfo,LearnTalent
-- #GLOBALS (Zygor),BINDING_HEADER_ZYGORTALENTADVISOR,BINDING_NAME_ZYGORTALENTADVISOR_OPENPOPUP
-- #GLOBALS (Zygor),ZygorGuidesViewer,ZGV,ZygorTalentAdvisor_L,ZygorTalentAdvisor_TalentFrameLearnButton_OnClick,ZygorTalentAdvisorPopout

-- #GLOBALS-REMOVED!!! SetPreviewPrimaryTalentTree,AddPreviewTalentPoints,GetActiveTalentGroup,GetGroupPreviewTalentPointsSpent,GetPreviewPrimaryTalentTree,GetPrimaryTalentTree,GetTalentLink,GetUnspentTalentPoints,ResetGroupPreviewTalentPoints,LearnPreviewTalents
-- #GLOBALS (maybe),TalentFrameHeaderHelpBoxArrow1,TalentFrameHeaderHelpBoxArrow2,TalentFrameHeaderHelpBoxArrow3,TalentFrameLearnButton,TalentFrameLearnButton_OnClick,TalentFramePanel1SelectTreeButton,

-- #GLOBALS pet,

-- GLOBAL AddPreviewTalentPoints,GetGroupPreviewTalentPointsSpent,GetTalentLink,LearnPreviewTalents,PanelTemplates_GetSelectedTab,PlayerTalentFrame,PlayerTalentFrame_Update,ZygorTalentAdvisor,ZygorTalentAdvisorPopoutButton


--[[
New Classic API?

function TalentFrame_UpdateTalentPoints()
	local talentPoints = UnitCharacterPoints("player");
	TalentFrameTalentPointsText:SetText(talentPoints);
	TalentFrame.talentPoints = talentPoints;
end
--]]

local name,ZGV=...

local ZTA={}
ZGV.TalentAdvisor = ZTA
ZGV.ZTA = ZTA

local CHAIN = ZGV.ChainCall

ZTA.buildStorage = {}

ZTA.registeredBuilds = {}

ZTA.L = ZygorGuidesViewer_L("zta")
local L = ZTA.L

--local HEADER_ZYGORTALENTADVISOR = L["name_plain"]
BINDING_NAME_ZYGORTALENTADVISOR_OPENPOPUP = L["binding_popout"]

--ZTA.currentBuild = {}
ZTA.currentBuildTitle = {}
ZTA.status = {code="?"}
ZTA.status_preview = {code="?"}
ZTA.suggestion = {}
ZTA.suggestion_preview = {}

--ZTA.SAFEMODE=true

ZTA.MAXTALENTS = 61 -- as of WoW 2.5.1


local BUILDKEY_NONE = "0"

--[[
 ######################################################################################################################
  S E T U P
 ######################################################################################################################
--]]

function ZTA:Initialize()

	self:SetupConfig()

	--[[
	if GetTalentInfo(1,1) then
		self:DelayedRegisteredBuilds()
	end
	--]]

	ZGV:AddEventHandler("CHARACTER_POINTS_CHANGED",{self,"CHARACTER_POINTS_CHANGED"})

	hooksecurefunc("ToggleTalentFrame",function()
		self:Debug("ToggleTalentFrame hook")
		
		if not PlayerTalentFrame then return end

		if not self.TalentFrame then
			if PlayerTalentFrame then self.TalentFrame = PlayerTalentFrame
			elseif TalentFrame then self.TalentFrame = TalentFrame
			end
		end
		if not self.hooked then 
			self:HookToTalentFrame() 
			ZTA:SetHooks()
		end
	
		ZTA:UpdateSuggestions()
	end)
	TalentMicroButton:HookScript("OnClick",function()
		self:Debug("TalentMicroButton hook")
		ZTA:UpdateSuggestions()
	end)


	StaticPopupDialogs['ZYGORTALENTADVISOR_WARNING'] = {
		text = "",
		button1 = YES,
		button2 = NO,
		OnAccept = function (self) ZTA:Safe_LearnTalent(self.data.tab,self.data.talent) end,
		OnCancel = function (self) end,
		OnHide = function (self) self.data = nil; self.selectedIcon = nil; end,
		hideOnEscape = 1,
		timeout = 0,
		whileDead = 1,
	}

	-- inaccessible in Classic
	--[[
		StaticPopupDialogs['ZYGORTALENTADVISOR_PREVIEWWARNING'] = {
			text = "",
			button1 = YES,
			button2 = NO,
			OnAccept = function (self) if SAFEMODE then self:Debug("learning previewed") return nil end LearnPreviewTalents(self) end,
			OnCancel = function (self) end,
			OnHide = function (self) self.data = nil; self.selectedIcon = nil; end,
			hideOnEscape = 1,
			timeout = 0,
			whileDead = 1,
		}
	--]]
	
	--[[
	StaticPopupDialogs['ZYGORTALENTADVISOR_CONFIRM_LEARN_PREVIEW_TALENTS'] = {
		text = CONFIRM_LEARN_PREVIEW_TALENTS,
		button1 = YES,
		button2 = NO,
		OnAccept = function (self)
			LearnPreviewTalents(ZygorTalentAdvisor.Window.pet)
		end,
		OnCancel = function (self) end,
		hideOnEscape = 1,
		timeout = 0,
		exclusive = 1,
	}
	StaticPopupDialogs['ZYGORTALENTADVISOR_CONFIRMBULKLEARNING'] = {
		text = "...",
		button1 = YES,
		button2 = NO,
		OnAccept = function (self)
			ZTA:LearnSuggestedTalents(self.data.pet)
		end,
		OnCancel = function (self) end,
		hideOnEscape = 1,
		timeout = 0,
		exclusive = 1,
	}
	--]]


	if UnitClass("player") then
		self:PruneRegisteredBuilds()
		self:LoadBuilds()
	else
		self:Debug("Couldn't PruneRegisteredBuilds at this time.")
	end

	self.popout = ZygorTalentAdvisorPopout
end

function ZTA:SetHooks()
	self.Old_LearnTalent = self.Old_LearnTalent or LearnTalent
	self.Old_GameTooltipSetTalent = self.Old_GameTooltipSetTalent or GameTooltip.SetTalent

	if ZGV.db.profile.zta_enabled then 
		LearnTalent = self.ZTA_LearnTalent

		if not ZTA.TooltipsHooked then
			hooksecurefunc("PlayerTalentFrameTalent_OnEnter",self.ZTA_GameTooltipSetTalent)
			ZTA.TooltipsHooked = true
		end
		
		
		if self.TalentFrame and self.TalentFrame.advisorbutton then self.TalentFrame.advisorbutton:Show() end
	else
		LearnTalent = self.Old_LearnTalent
		--GameTooltip.SetTalent = self.Old_GameTooltipSetTalent
		if self.TalentFrame and self.TalentFrame.advisorbutton then self.TalentFrame.advisorbutton:Hide() end
	end

	if self.TalentFrame then 
		ZTA:HookToTalentFrame()
		ZTA:UpdateSuggestions()
	end
end

function ZTA:HookToTalentFrame()
	if not ZGV.db.profile.zta_enabled then return end
	self:Debug("zta hooking 1st time")
	--TalentFrameLearnButton:SetScript("OnClick",ZygorTalentAdvisor_TalentFrameLearnButton_OnClick) -- As of patch 1.13.2.30786 there's no Learn button, no Preview, talents are learned after being clicked once.

	--self.popout:Hook(ZygorTalentAdvisorPopout)

	if PlayerTalentFrame_OnHide and not self.hooked then 
		hooksecurefunc("PlayerTalentFrame_OnHide",function()
			if self.popout.moving and self.popout:GetParent()==self.TalentFrame then
				self.db.profile.zta_windowdocked = false
				self.popout:Reparent()
				self.popout:UpdateDocking()
				self.popout.moving=false
				self.popout:StopMovingOrSizing()
				self.popout:Show()
			end

			--[[
			if self.popout:IsShown() then
				PlayerTalentFrame.advisorbutton:SetButtonState("PUSHED",1)
			else
				PlayerTalentFrame.advisorbutton:SetButtonState("NORMAL")
			end
			--]]

			--[[
			for i=1,MAX_NUM_TALENTS do
				_G['PlayerTalentFrameTalent'..i]:SetScript("OnClick",ZygorTalentAdvisor_PlayerTalentFrameTalent_OnClick)
			end
			--]]

			--[[
			if not self.hookedreset then
				self.hookedreset=true
				--self:Debug("hooked")
			end
			if PlayerTalentFrame and PlayerTalentFrame:IsVisible() then
				self:UpdateSuggestions(PlayerTalentFrame.pet)
			end
			--]]
		end) 
		hooksecurefunc("PlayerTalentTab_OnClick",function() ZTA:ShowTalentSuggestions() end)
		hooksecurefunc("TalentFrame_Update",function() ZTA:ShowTalentSuggestions() end)
	end
	
	-- ^ DO NOT update suggestions; causes flickering, as TF_U fires both on CHARACTER_POINTS_CHANGED and SPELLS_CHANGED, which causes intermittent inconsistencies.
	-- Have to just use CHARACTER_POINTS_CHANGED and be done, as it comes AFTER SPELLS_CHANGED.

	--hooksecurefunc("TalentFrame_UpdateControls",function() self:ShowTalentSuggestions() end)


	if self.TalentFrame and not self.TalentFrame.advisorbutton then
		self.TalentFrame.advisorbutton = ZygorTalentAdvisorPopoutButton
		
		ZGV.F.AssignButtonTexture(self.TalentFrame.advisorbutton,ZGV.DIR.."\\Skins\\popout-v2",1,1,false)

		ZGV.ChainCall(self.TalentFrame.advisorbutton)
			:SetParent(self.TalentFrame)

		--[[
		ZGV.ChainCall(self.TalentFrame.advisorbutton)
			:SetParent(self.TalentFrame)
			:SetNormalTexture(ZGV.DIR.."\\Skins\\popout-button-2")
			:SetPushedTexture(ZGV.DIR.."\\Skins\\popout-button-2-down")
			:SetHighlightTexture(ZGV.DIR.."\\Skins\\popout-button-2-hi")
		--]]

		--[[ -- advisor button moved to "tab"
		--PlayerTalentFrame.advisorbutton:SetFrameLevel(120)
		--PlayerTalentFrameActivateButton:SetPoint("TOPRIGHT",PlayerTalentFrame,"TOPRIGHT",-40,-30)
		--]]

		--[[
		CreateFrame("Button",nil,PlayerTalentFrame,"UIPanelButtonTemplate")
		PlayerTalentFrame.advisorbutton:ClearAllPoints()
		PlayerTalentFrame.advisorbutton:SetPoint("TOPRIGHT",-40,-40)
		PlayerTalentFrame.advisorbutton:SetHeight(30)
		PlayerTalentFrame.advisorbutton:SetWidth(30)
		PlayerTalentFrame.advisorbutton:SetText("ZTA>")
		PlayerTalentFrame.advisorbutton:SetScript("OnClick",function() if ZygorTalentAdvisorPopout_Popup:IsShown() then ZygorTalentAdvisorPopout_Popup:Hide() else ZygorTalentAdvisorPopout_Popup() end end)
		--PlayerTalentFrame.advisorbutton:SetScript("OnEnter",function(self) GameTooltip_SetDefaultAnchor(GameTooltip,self) GameTooltip:SetText(L['name']) GameTooltip:AddLine(L['popout_button_tip']) GameTooltip:Show() end)
		PlayerTalentFrame.advisorbutton:SetScript("OnEnter",function(self) GameTooltip_AddNewbieTip(self, L['name'], 1,1,1, L['popout_button_tip']) end)
		PlayerTalentFrame.advisorbutton:SetScript("OnLeave",GameTooltip_Hide)
		--]]
	end

	if self.TalentFrame and self.TalentFrame.advisorbutton then
		self.TalentFrame.advisorbutton:Show()
	end

	self.hooked=true
end


function ZTA:SetupConfig()
	self.db = ZGV.db

	local Getter_Simple = function(info)
		return self.db.profile[info[#info]]
	end
	local Setter_Simple = function(info,value)
		self.db.profile[info[#info]] = value
	end

	self.options = {
		name = L['name'],
		desc = L['desc'],
		type = "group",
		order = 1,
		--hidden = true,
		handler = self,
		get = Getter_Simple,
		set = Setter_Simple,
		args = {
			desc = {
				order = 1,
				type = "description",
				name = L['desc'],
			},
			zta_enabled = {
				name = L['opt_enabled'],
				type = "toggle",
				width = "full",
				--get inherited simple
				set = function(i,v) Setter_Simple(i,v) ZTA:SetHooks() end,
				order = 1,
				_default = true,
			},

			desc01 = {
				type = "header",
				name = L['opt_build_header'],
				order = 1.01,
				hidden = function() local _,class = UnitClass("player") return class~="HUNTER" end,
				disabled = function() return not self.db.profile.zta_enabled end, 
			},
			build = { ------------------- BUILD --------------------
				name = L['opt_build'],
				desc = L['opt_build_desc'],
				type = "select",
				values = function()
					 local t={[BUILDKEY_NONE]=L['opt_build_none']}
					 if not next(self.registeredBuilds) then return t end
					 local k,v
					 local _,playerclass=UnitClass("player")
					 for k,v in pairs(self.registeredBuilds) do if v.class and v.class==playerclass then t[k]=v.title end end
					 return t
					 end,
				width = "double",
				get = function() return self.db.char.zta_currentBuildKey or BUILDKEY_NONE end,
				set = function(_,k) self:SetCurrentBuild(k,false) end,
				order = 1.1,
				disabled = function() return not self.db.profile.zta_enabled end, 
			},
			zta_forcebuild = {
				name = L['opt_force'],
				desc = L['opt_force_desc'],
				type = "toggle",
				width = "single",
				--get simple
				set = function(i,v) Setter_Simple(i,v) self:LoadBuilds(false) end,
				hidden = function() return self.status.code~="RED" end,
				order = 1.2,
				_default = false,
				disabled = function() return not self.db.profile.zta_enabled end, 
			},
			desc1 = { order = 1.21,	type = "description",	name = "", },
			buildstatus = {
				type = "description",
				name = function() return self:GetStatusMessage(false) end,
				width = "full",
				order = 1.3,
			},
			--[[
			desc12 = { order = 1.31,	type = "description",	name = "|n", },
			descp = { ---------------- PET BUILD ------------------
				type = "header",
				name = L['opt_petbuild_header'],
				order = 2.01,
				hidden = function() local _,class = UnitClass("player") return class~="HUNTER" end,
			},
			--]]
			desc21 = { order = 2.21,	type = "description",	name = "", },
			talentframe = {
				name = L['opt_talentframe'],
				type = "header",
				--inline = true,
				order = 7,
				--args = {
			},
			zta_hints = {
				name = L['opt_hints'],
				desc = function() return GetCVarBool("previewTalentsOption") and L['opt_hints_desc_preview'] or L['opt_hints_desc_nopreview'] end,
				type = "toggle",
				width = "full",
				--get inherited simple
				set = function(i,v) Setter_Simple(i,v) if not v then TalentFrame_Update(PlayerTalentFrame) end ZTA:ShowTalentSuggestions() end,
				disabled = function() return not (ZTA:IsCurrentBuildUsable() and self.db.profile.zta_enabled) end, 
				order = 7.1,
				_default = true,
			},
			zta_preview = {
				name = L['opt_preview'],
				desc = L['opt_preview_desc'],
				type = "toggle",
				width = "full",
				--get inherited simple
				set = function(i,v) Setter_Simple(i,v) if not v then TalentFrame_Update(PlayerTalentFrame) end ZTA:ShowTalentSuggestions() end,
				disabled = function() return not (ZTA:IsCurrentBuildUsable() and self.db.profile.zta_enabled) end, 
				order = 7.2,
				_default = true,
			},
			zta_popup = {
				name = L['opt_popup'],
				desc = L['opt_popup_desc'],
				type = "select",
				style = "radio",
				width = "double",
				--get inherited simple
				--set inherited simple
				values = {[0]=L['opt_popup_0'],L['opt_popup_1'],L['opt_popup_2']--[[,L['opt_popup_3']--]]},
				order = 8,
				_default = 1,
				disabled = function() return not self.db.profile.zta_enabled end, 
			},
			zta_windowdocked = {
				name = L['opt_popup_dock'],
				desc = L['opt_popup_dock_desc'],
				type = "toggle",
				width = "double",
				--get inherited simple
				set = function(i,v)
					Setter_Simple(i,v)
					self.popout:Reparent()
					if (v==false) then self.popout:ClearAllPoints() self.popout:SetPoint("CENTER",0,200) end
					self.popout:UpdateDocking()
				  end,
				order = 9,
				_default = true,
				disabled = function() return not self.db.profile.zta_enabled end, 
			},
			sep1 = {
				type="description", name=" |n |n |n", order=98
			},
		}
	}

	return self.options
end

function ZTA:SetupConfigExtra()

	local Getter_Simple = function(info)
		return self.db.profile[info[#info]]
	end
	local Setter_Simple = function(info,value)
		self.db.profile[info[#info]] = value
	end

	local extra_args = {}
	extra_args['fake_talentsspent'] = {
		name = "FAKE talents spent",
		type = 'range', min = -1, max = 60, step = 1, bigStep = 1, set = function(i,v) Setter_Simple(i,v) ZTA:UpdateSuggestions() end,
		order = 100.1,
		_default=-1
	}
	extra_args['fake_talentsunused'] = {
		name = "FAKE talents available",
		type = 'range', min = -1, max = 60, step = 1, bigStep = 1, set = function(i,v) Setter_Simple(i,v) ZTA:UpdateSuggestions() end,
		order = 100.2,
		_default=-1
	}
	extra_args['fake_gotnewtalents'] = {
		name = "FAKE got new talents!",
		type = 'execute', func = function() ZTA:CHARACTER_POINTS_CHANGED(nil,1) end,
		order = 100.3,
		_default=-1
	}
	return {debugfake={args=extra_args}}
end

function ZTA:Safe_LearnTalent(tab,index,talent_status)
	local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=tab,talentIndex=index})
	local name = info and info.name or ""
	if talent_status then
		self:Print(L['msg_learned_talent']:format(name))
	end
	if self.SAFEMODE then
		self:Print("SAFEMODE on: just pretending to learn.")
	else
		self.Old_LearnTalent(tab,index)
	end
end

function ZTA:LoadBuilds()
	if self.db.char.zta_currentBuildKey~=BUILDKEY_NONE then self:SetCurrentBuild(self.db.char.zta_currentBuildKey,"startup") end
end

function ZTA:BulkLearnNext()
	if #self.suggestion>0 then
		local sug_talent=self.suggestion[1]
		self:Safe_LearnTalent(sug_talent.tab,sug_talent.talent)
	else
		self.bulklearning=nil
		self:Print("Talent learning complete.")
	end
end
---- events

function ZTA:CHARACTER_POINTS_CHANGED(_,delta)
	if not ZGV.db.profile.zta_enabled then return end

	local self=ZTA -- I hate myself
	self:Debug("CHARACTER_POINTS_CHANGED "..tostring(delta))
	if delta>0 then return self:OnNewTalents() end
	self:UpdateSuggestions(false)
	if delta<0 and self.bulklearning then
		self:BulkLearnNext()
	end
end
--[[
function ZGV:SPELLS_CHANGED()
	local self=ZTA -- I hate myself
	self:Debug("SPELLS_CHANGED")
	self:UpdateSuggestions(false)
	self.popout:Update()
end
--]]

function ZTA:OnNewTalents()
	--local lasttalents = pet and self.lastUnspentPetTalents or self.lastUnspentTalents
	-- no selected build? bail.
	self:Debug("On New Talents")

	if not self.currentBuild and UnitCharacterPoints("player")>0 then
		--if LibTutorial then LibTutorial:ShowTutorial("ZTA2") end
		return nil
	end

	--if self.alreadyProcessingNewTalents[toboolean(pet)] then return end

	--self.alreadyProcessingNewTalents[toboolean(pet)]=true

	-- no talents? bail.
	--if GetUnspentTalentPoints(false,pet)==0 then return end
	-- or not! handle clearing, too.

	self:LoadBuilds()

	local pet = false

	--if not self:GetSuggestion(pet) then return nil end
	-- oh, do pop up, just with a warning

	local switchToPet = function()
		-- try to activate the pet talent frame
		for i=1,5 do
			local tab = _G["PlayerSpecTab"..i]
			if tab and string.find(tab.specIndex,"^petspec") then
				tab:Click()
				break
			end
		end
	end

	local popup = self.db.profile.zta_popup or 0
	if popup==1 then
		if not ZTA.TalentFrame or not ZTA.TalentFrame:IsShown() then
			ToggleTalentFrame()
		end
		--TalentFrame_LoadUI()
		--ShowUIPanel(ZTA.TalentFrame)
		--PlayerTalentFrame_Open(pet, pet and 1 or GetActiveTalentGroup())

		if pet then switchToPet() end
	end
	
	if popup==2 then
		self.popout:Popout()
		if pet then switchToPet() end
		self.popout:Update()
	end

	if popup==3 and false --[[ never --]] then
		self:LearnSuggestedTalents(true)
	end

	self:UpdateSuggestions()
end

local panels={""} --{"Panel1","Panel2","Panel3","PetPanel"}
function ZTA:CleanupTalentFrame()
	local basename = self.TalentFrame:GetName()
	for p,panel in ipairs(panels) do
		for talent=1,MAX_NUM_TALENTS do
			local bor = _G[basename..panel.."Talent"..talent.."RankBorder"]
			if bor then
				bor:SetWidth(bor.zygor__orig_w or 32)
				bor:SetHeight(bor.zygor__orig_h or 32)
			end

			local hint = _G[basename..panel.."Talent"..talent.."ZygorHint"]
			if hint then hint:Hide() end
		end
	end

	self.cleaning=true
	--pcall(function() PlayerTalentFrame_Update(PlayerTalentFrame) end) -- something breaks here... screw it?
	PlayerTalentFrame_OnShow(PlayerTalentFrame)
	self.cleaning=false
end

local function ZTA_SelectTree_Flash(self,elapsed)
	do return end
	local basename = self.TalenFrame:GetName()
	self.time=self.time+elapsed
	if self.time>0.5 then
		-- PlayerTalentFramePanel1SelectTreeButton:UnlockHighlight()
		-- PlayerTalentFramePanel2SelectTreeButton:UnlockHighlight()
		-- PlayerTalentFramePanel3SelectTreeButton:UnlockHighlight()
		if ZTA.currentBuild and ZTA.currentBuild.spec then
			local specbutton = _G[basename.."Panel"..ZTA.currentBuild.player.spec.."SelectTreeButton"]
			if specbutton and specbutton.flash then specbutton:LockHighlight() else specbutton:UnlockHighlight() end
			specbutton.flash = not specbutton.flash
		end
		self.time=0
	end
end

function ZTA:IsBuildStatusUsable(status)
	local code=status and status.code
	return code and code~="NONE" and code~="BLACK" and (code~="RED" or self.db.profile.zta_forcebuild)
end

function ZTA:IsCurrentBuildUsable()
	return self:IsBuildStatusUsable(self.status)
end

function ZTA:ShowTalentSuggestions()
	if self.cleaning then return nil end
	
	if not self.TalentFrame or not self.TalentFrame:IsVisible() then return end

	self.popout:UpdateDocking()

	if self.db.profile.zta_enabled then self.TalentFrame.advisorbutton:Show() end

	-- no build or build disabled? clean up, bail out.
	if not self:IsCurrentBuildUsable() then
		self:Debug("Build unusable; just cleaning up.")
		self:CleanupTalentFrame()
		self.popout:Update()
		--self.popout:UpdateDocking()
		return
	end

	self:Debug("Build usable; let's display things.")

	local tab,panel = PanelTemplates_GetSelectedTab(self.TalentFrame),""
	
	self:Debug("Displaying talent suggestions in tab %d.",tab)

	local suggestion = self.suggestion
	local build = self.currentBuild.build
	local preview = GetCVarBool("previewTalentsOption")
	local pet = false

	self.popout:Update()
	--self.popout:UpdateDocking()

	--self:Debug("ShowTalentSuggestions ")

	--[[
	local advisory = L['talentframeadvisory_head']:format(self.currentBuildTitle)
	local status = preview and self.status_preview or self.status
	if status.code=="ORANGE" then
		advisory = advisory .. "\n" .. L['talentframeadvisory_orange']:format(status.missed-status.pointsleft)
	end
	if status.code=="RED" then
		advisory = advisory .. "\n" .. L['talentframeadvisory_red']
	end
	TalentFrame.advisory:SetText(advisory)
	--]]


	-- first the spec buttons
	if not self.TalentFrame.scriptedtoflash then
		self.TalentFrame:HookScript("OnUpdate",ZTA_SelectTree_Flash)
		self.TalentFrame.time=0
		self.TalentFrame.scriptedtoflash = true
		ZTA_SelectTree_Flash(self.TalentFrame,99) --force
	end
	--[[ sinus 2021-05-19
	if TalentFramePanel1SelectTreeButton and TalentFramePanel1SelectTreeButton:IsShown() then
		TalentFrameHeaderHelpBoxArrow1:Hide()
		TalentFrameHeaderHelpBoxArrow2:Hide()
		TalentFrameHeaderHelpBoxArrow3:Hide()
		_G['TalentFrameHeaderHelpBoxArrow'..build.spec]:Show()
	end
	--]]


	--PlayerTalentFrameHeaderFrame.HeaderText:SetText(self.currentBuildTitle)
	--PlayerTalentFrameHeaderFrame.SubHeaderText:SetText("One-liner description could go here.")


	local counts = self:GetBuildTalentsAt(self:GetTalentsSpent(),build)
	local maxcounts = self.currentBuild.maxcounts

	local button
	local txt,bor,borg,hint

	local borbigsizew,borbigsizeh=54,32 -- big rank border size

	--for tab,panel in ipairs(panels) do
		local talents = GetNumTalents(tab)
		for talent=1,talents do

			local prefix = self.TalentFrame:GetName()..panel.."Talent"..talent
			button = _G[prefix]
			txt = _G[prefix.."Rank"]
			bor = _G[prefix.."RankBorder"]
			hint = _G[prefix.."ZygorHint"]
			local texture=button.icon


			local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=tab,talentIndex=talent, isPet=pet})
			if not info then return end
			local rank = info.rank

			local rank_desired = maxcounts[tab][talent]
			local grayed = texture:GetDesaturation()==1
			local maxed = rank==info.maxRank
			local has_under = rank<rank_desired
			local has_right = rank==rank_desired
			local has_over = rank>rank_desired


			-- store original rank sizes
			bor.zygor__orig_w = bor.zygor__orig_w or bor:GetWidth()
			bor.zygor__orig_h = bor.zygor__orig_h or bor:GetHeight()


			local function C_YELLOW(s) return "|cffffff00"..s.."|r" end
			local function C_GREEN(s) return "|cff00ff00"..s.."|r" end
			local function C_ZYGOR(s) return "|cfff16100"..s.."|r" end
			local function C_WHITE(s) return "|cffffffff"..s.."|r" end
			local function C_BLUE(s) return "|cff00aaff"..s.."|r" end
			local function C_RED(s) return "|cffff0000"..s.."|r" end
			local function C_GRAY(s) return "|cffaaaaaa"..s.."|r" end
			local SLASH = C_GRAY("/")
			local SLASH_ZYGOR = C_WHITE("/")

			-- textual build preview: "1/3" in rank boxes

			-- Original: incomplete=GREEN, maxed=YELLOW, unavailable=NONE
			-- ZTA: 

			local function setText(s)
				if not s then txt:Hide() bor:Hide() return end
				txt:SetText(s)
				txt:Show()
				bor:Show()
				if s:find("/") then bor:SetSize(borbigsizew,borbigsizeh) else bor:SetSize(bor.zygor__orig_w,bor.zygor__orig_h) end
				bor:SetDesaturated(grayed)
			end

			
			if self.db.profile.zta_preview and self.db.profile.zta_enabled --[[means: show ranks!! not "preview" in the sense of preview-talents!!]]
			--and not (desired==0 and rank==0) -- not wanted, not invested
			then
				if has_under then

					if grayed then
						if rank_desired>0 then
							setText(C_GRAY(rank)..SLASH..C_WHITE(rank_desired))
						else
							setText(nil)
						end
					else
						setText(C_GREEN(rank)..SLASH..C_WHITE(rank_desired))
					end

				elseif has_right then

					if grayed then
						if rank_desired>0 then
							setText(C_GRAY(rank)..SLASH..C_WHITE(rank_desired))
						else
							setText(nil)
						end
					else
						setText(C_WHITE(rank)..SLASH_ZYGOR..C_WHITE(rank_desired))
					end

				elseif rank>rank_desired then -- overshot
					
					setText(C_RED(rank)..SLASH..C_WHITE(rank_desired))

				end
			else
				bor:SetSize(bor.zygor__orig_w,bor.zygor__orig_h)
				txt:SetText(rank) -- color is governed by PlayerTalentFrame internals
				bor:SetShown(not grayed)
				txt:SetShown(not grayed)
				-- don't touch visibility
				--if rank<maxrank then txt:SetTextColor(0,1,0) else txt:SetTextColor
			end


			-- hint balloons

			if self.db.profile.zta_hints and self.db.profile.zta_enabled then

				-- prepare the hint balloon
				if not hint then
					hint = button:CreateTexture(prefix.."ZygorHint")
					--hint:SetTexture("Interface\\Buttons\\CheckButtonHilight")
					hint:SetPoint("LEFT",texture,"RIGHT",-14,5)
					hint:SetSize(32,32)
					hint:SetTexture(ZGV.DIR.."\\Skins\\ZTA_Hints")
					hint:SetDrawLayer("OVERLAY")
				end


				local suggested

				-- consider all suggestions in preview/ooo mode; only the first suggestion in strict/inorder mode
				--self:IsOutOfOrder(pet) or 

				-- actually, no. Let's try to get out of OOO mode somehow.
				--[[
				if preview or (suggestion[1][1]==tab and suggestion[1][2]==talent) then
					suggested = suggestion and suggestion[tab.."."..talent]
				end
				--]]
				suggested = suggestion[tab.."."..talent]

				local mindesired = counts[tab] and counts[tab][talent] or 0

				local realrank=0 -- added in case preview comes back

				-- hint balloon display
				if suggested then -- suggested this turn
					local hintpoints = suggested --(rank-realrank) -- suggested minus previewed
					if hintpoints>0 then
						hint:SetTexCoord(0.125*hintpoints,0.125*(hintpoints+1),0,1)
					elseif hintpoints==0 then
						hint:SetTexCoord(0.125*6,0.125*7,0,1)
					else
						hint:SetTexCoord(0.875,1.000,0,1) -- X
						--self:Debug("X1"..name.." : hints="..hintpoints.." for rank "..rank)
					end
					hint:SetDesaturated(grayed)
					hint:Show()
				elseif rank>mindesired and preview and rank>realrank and realrank<=mindesired then -- overinvested! oh shit. But warn only if it matters anymore.
					hint:SetTexCoord(0.875,1.000,0,1) -- X
					hint:SetDesaturated(grayed)
					hint:Show()
					--self:Debug("X2 "..name)
				else
					hint:Hide()
				end
			elseif hint then
				hint:Hide()
			end
		end
	--end

	if (self.db.profile.fake_talentsunused or -1)>-1 then
		_G[self.TalentFrame:GetName().."TalentPointsText"]:SetText(("%d |cff888888(faked! really %d)"):format(self.db.profile.fake_talentsunused,UnitCharacterPoints("player")))
	else
		TalentFrame_UpdateTalentPoints(self.TalentFrame)
	end
end

function ZTA:GetSuggestionTooltip()
	self:Debug("GetSuggestionTooltip")
	return L['suggest_button_tooltip']:format(self.currentBuildTitle and self.currentBuildTitle["player"])
end

function ZTA:GetSuggestionFormatted()
	TalentFrame_LoadUI()
	local sugformatted={}
	for i=1,#self.suggestion do
		local sug=self.suggestion[i]
		local tab,talent,rank = sug.tab,sug.talent,sug.rank

		local tabnum, tabname, texture, points, fileName = GetTalentTabInfo(tab,false)
		local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=tab,talentIndex=talent, isPet=pet})
		if not info then return sugformatted end
		
		local name, tex, maxrank = info.name, info.icon, info.maxRank
		
		if not sugformatted[tabname] then sugformatted[tabname]={} end
		local inserted=false
		for i=1,#sugformatted[tabname] do
			if sugformatted[tabname][i].name==name then
				sugformatted[tabname][i].to = rank
				inserted=true
				break
			end
		end
		if not inserted then -- new talent
			table.insert(sugformatted[tabname],{tex=tex,tab=tab,name=name,talent=talent,from=rank,oneofone=maxrank==1})
		end
	end
	return sugformatted
end

function ZTA:LearnSuggestedTalents(loud)
	TalentFrame_LoadUI()

	if not self:IsCurrentBuildUsable() then
		self:Print(L['error_bulklearn_nobuild'])
		return
	end
	
	local suggestion = self.suggestion

	if not suggestion or #suggestion==0 then
		self:Print(L['error_bulklearn_nosuggestion'])
		return
	end

	if loud then
		local sugformatted = self:GetSuggestionFormatted()
		local s=""

		self:Print(L['msg_learned_verbose'])

		for tab,talents in pairs(sugformatted) do
			self:Print("|cffffffff"..tab.."|r:")
			local s
			for n,levels in ipairs(talents) do
				local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=levels.tab,talentIndex=levels.talent})
				if not info then return end

				local talent = "|T"..levels.tex..":0:0:0:0|t "..info.name --|cffffdd00"..GetTalentLink(levels.tab,levels.talent,false,pet,GetActiveTalentGroup())
				if levels[1]==0 then
					s=talent
				else
					s=talent.." |cff997700("
					if #levels<3 then s=s..table.concat(levels,",") else s=s..levels[1].."-"..levels[#levels] end
					s=s..")|r"
				end
				self:Print(L['msg_learned_verbose_talent']:format(s))
			end
		end
	--else
	--	self:Print(L['msg_learned'])
	end

	--[[ TODO: rework, talent previews do not exist on classic
	if #suggestion>1 then
		local preview = GetCVar("previewTalentsOption")
		SetCVar("previewTalentsOption",1)
		self:PreviewSuggestions(true)
		self:ScheduleTimer(function()
			LearnPreviewTalents()
			SetCVar("previewTalentsOption",preview)
		end, 0.1)
	else
		self.Old_LearnTalent(suggestion[1].tab,suggestion[1].talent)
	end
	--]]
	self.bulklearning=true
	self:Safe_LearnTalent(suggestion[1].tab,suggestion[1].talent)

	--[[
	if not self.db.profile.zta_windowdocked then
		ZygorTalentAdvisorPopout:Hide()
	else
		self.popout:Update()
	end
	--]]

	--[[
	else
		self.bulklearning=true -- starts processing the queue, driven by CHARACTER_POINTS_CHANGED -1
		local name=GetTalentInfo(self.suggestion[1].tab,self.suggestion[1].talent,false)
		self:Print(L['msg_learned']:format(name))
		Old_LearnTalent(self.suggestion[1].tab,self.suggestion[1].talent)
	end
	--]]
end

-- Talent Previews were added in patch 3.1.0.
function ZTA:PreviewSuggestions(quiet)
	print("UNABLE TO PREVIEW - rework using pre-")
	do return end

	self.cleaning = true

	local suggestion = self.suggestion
	if not suggestion then return end

	-- this may look out of order, but is fine for applying ALL suggestions

	-- not any longer?

	local pts
	--[[
	local sug
	for tab,talent in talentpairs(false) do
		sug = suggestion[tab.."."..talent]
		if sug then 
			pts = GetGroupPreviewTalentPointsSpent()
			AddPreviewTalentPoints(tab,talent,sug)
			if pts==GetGroupPreviewTalentPointsSpent() then
				local name=GetTalentInfo(tab,talent,false)
				self:Print("|cffff0000Error!|r Talent "..name.." suggested but unavailable!")
			end
		end
	end
	--]]

	for i,sug in ipairs(suggestion) do
		pts = GetGroupPreviewTalentPointsSpent()
		AddPreviewTalentPoints(sug.tab,sug.talent,1)
		if pts==GetGroupPreviewTalentPointsSpent() then
			local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=sug.tab,talentIndex=sug.talent})
			self:Print("|cffff0000Error!|r Talent "..info.name.." suggested but unavailable!")
		end
	end

	self.cleaning = false
	self:ShowTalentSuggestions()


	if not quiet and (not self.TalentFrame or not self.TalentFrame:IsVisible()) then
		ToggleTalentFrame()
	end
end

function ZTA.talentpairs()
	local tab,tal=1,0
	return function()
		tal=tal+1
		if tal>GetNumTalents(tab) then
			tal=1
			tab=tab+1
		end
		if tab<=GetNumTalentTabs() then
			return tab,tal
		end
	end
end

local PLAYER_TALENTS_PER_TIER_UNLOCK=5

function ZTA.ZTA_LearnTalent(tab,talent) --,pet,group
	local self = ZTA
	-- need to double-check if the user hasn't clicked an inaccessible talent, otherwise we're barking up the wrong tree
	
	if UnitCharacterPoints("player")==0 then return nil end

	local _, _, _, _, tabPointsSpent, fileName = GetTalentTabInfo(tab) --,false,pet,group
	
	local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=tab,talentIndex=talent, isPet=pet})
	
	local name, iconTexture, tier, rank = info.name, info.icon, info.tier, info.rank
	
	if info.rank == info.maxRank then return end
	
	if (((tier - 1) * PLAYER_TALENTS_PER_TIER_UNLOCK > tabPointsSpent)) then
		-- tier locked! bail.
		return nil
	end
	local reqtab,reqtal,learnable = GetTalentPrereqs(tab,talent,false)
	if reqtab and not learnable then
		return nil
	end
	
	local talent_status

	local suggestion = self.suggestion
	if self.currentBuild and suggestion and #suggestion>0 then
		local status = self.status
		
		local found,s
		for i=1,#suggestion do if suggestion[i].tab==tab and suggestion[i].talent==talent then found = i end end
		if not found then
			talent_status = false
			-- RED!
			local maxcounts = self.currentBuild.maxcounts
			local buildTitle = self.currentBuildTitle
			if maxcounts[tab][talent]==0 then
				-- never taken at all
				StaticPopupDialogs['ZYGORTALENTADVISOR_WARNING'].text = L['name_plain'].."|n|n"..L['warning_learn1_red0']:format(buildTitle)
			elseif rank+1 > maxcounts[tab][talent] then
				-- taken, but not this far
				StaticPopupDialogs['ZYGORTALENTADVISOR_WARNING'].text = L['name_plain'].."|n|n"..L['warning_learn1_red']:format(buildTitle,maxcounts[tab][talent],"|T"..iconTexture..":0:0:0:0|t "..name)
			else
				-- Warning, YELLOW zone: not in suggestion, so too far
				local stab = suggestion[1].tab
				local stalent = suggestion[1].talent
				local sinfo = C_SpecializationInfo.GetTalentInfo({specializationIndex=stab,talentIndex=stalent})
				local sname, siconTexture = sinfo.name, sinfo.icon
				StaticPopupDialogs['ZYGORTALENTADVISOR_WARNING'].text = L['name_plain'].."|n|n"..L['warning_learn1_yellow']:format(
					buildTitle,
					select(1,GetTalentTabInfo(stab,false)),
					"|T"..siconTexture..":0:0:0:0|t "..sname,
					"|T"..iconTexture..":0:0:0:0|t "..name
				)
			end
			local dialog = StaticPopup_Show("ZYGORTALENTADVISOR_WARNING")
			if dialog then
				dialog.data = {tab=tab,talent=talent}
			else
				self:Print("ERROR: Cannot show dialog.\n"..StaticPopupDialogs['ZYGORTALENTADVISOR_WARNING'].text)
			end
			return
		else
			talent_status = true
			-- GREEN.
		end
	end

	self:Safe_LearnTalent(tab,talent,talent_status)
end

-- OVERRIDE
-- unused in Classic; no Preview, thus no built-in Learn button
function ZygorTalentAdvisor_TalentFrameLearnButton_OnClick(self)
	local TalentFrame = TalentFrame

	local ZTA = ZygorTalentAdvisor

	ZTA:UpdateSuggestions()
	local status = ZTA.status_preview
	local build = ZTA.currentBuild

	if status and build then
		if status.code=="GREEN" then
			StaticPopupDialogs['ZYGORTALENTADVISOR_PREVIEWWARNING'].text=L["warning_preview_green"]:format(ZTA.currentBuildTitle)
		elseif status.code=="YELLOW" then
			StaticPopupDialogs['ZYGORTALENTADVISOR_PREVIEWWARNING'].text=L["warning_preview_yellow"]:format(ZTA.currentBuildTitle,status.missed-status.pointsleft) --GetUnspentTalentPoints(false,pet)+GetGroupPreviewTalentPointsSpent(pet) ??
		elseif status.code=="RED" then
			StaticPopupDialogs['ZYGORTALENTADVISOR_PREVIEWWARNING'].text=L["warning_preview_red"]:format(ZTA.currentBuildTitle)
		elseif status.code=="BLACK" then
			StaticPopupDialogs['ZYGORTALENTADVISOR_PREVIEWWARNING'].text=L["warning_preview_black"]:format(status.msg)
		end
		local dialog = StaticPopup_Show("ZYGORTALENTADVISOR_PREVIEWWARNING")
		if dialog then
			dialog.data = {}
		else
			ZTA:Print("ERROR: Cannot show dialog.\n"..StaticPopupDialogs['ZYGORTALENTADVISOR_PREVIEWWARNING'].text)
		end
		return nil
	else
		TalentFrameLearnButton_OnClick(self)
		--StaticPopup_Show("CONFIRM_LEARN_PREVIEW_TALENTS")
	end
end


--[[
function ZygorTalentAdvisor_PlayerTalentFrameTalent_OnClick(self, button)
	--debug("click in zta? "..tostring(self.isZTA))
	if (IsModifiedClick("CHATLINK")) then
		local link = GetTalentLink(PanelTemplates_GetSelectedTab(PlayerTalentFrame), self:GetID(),
			PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup, GetCVarBool("previewTalents"));
		if (link) then
			ChatEdit_InsertLink(link);
		end
	elseif not PlayerTalentFrame.inspect and (PlayerTalentFrame.pet or GetActiveTalentGroup(false,PlayerTalentFrame.pet)==PlayerTalentFrame.talentGroup) then
		-- only allow functionality if an active spec is selected
		if (button == "LeftButton") then
			if (GetCVarBool("previewTalents")) then
				AddPreviewTalentPoints(PanelTemplates_GetSelectedTab(PlayerTalentFrame), self:GetID(), 1, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
			else
				LearnTalent(PanelTemplates_GetSelectedTab(PlayerTalentFrame), self:GetID(), PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
			end
		elseif (button == "RightButton") then
			if (GetCVarBool("previewTalents")) then
				if IsTalentRemovable(PanelTemplates_GetSelectedTab(PlayerTalentFrame), self:GetID(), PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup) then
					AddPreviewTalentPoints(PanelTemplates_GetSelectedTab(PlayerTalentFrame), self:GetID(), -1, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
				end
			end
		end
	end

	if self.isZTA then
		self:GetScript("OnLeave")(self)
		self:GetScript("OnEnter")(self)
	end
end

function ZygorTalentAdvisor_PlayerTalentFrameTalent_OnEvent(self, event, ...)
	if self:GetID() then
		-- whoa, original button! handle carefully.
		PlayerTalentFrameTalent_OnEvent(self, button)
		return
	end
	if (GameTooltip:IsOwned(self)) then
		GameTooltip:SetTalent(self.tab, self.talent, false, false, 1, GetCVarBool("previewTalents"))
	end
end

function ZygorTalentAdvisor_PlayerTalentFrameTalent_OnEnter(self)
	if self:GetID() and self:GetID()>0 then
		-- whoa, original button! handle carefully.
		PlayerTalentFrameTalent_OnEnter(self, button)
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetTalent(self.tab, self.talent, false, false, 1, GetCVarBool("previewTalents"))
end
--]]


--- Mark build's talents as .preview or .taken
-- @return nil
--
function ZTA:ClearBuildTalentsTaken(buildSource)
	buildSource.realfail=nil
	buildSource.previewfail=nil
	buildSource.numtaken=0
	buildSource.numpreview=0
	for i,talent in ipairs(buildSource.build) do
		talent.taken=nil
		talent.preview=nil
	end
end

function ZTA:MarkBuildTalentRanks(buildSource)
	local build = buildSource.build
	local ranks={}
	for i,talent in ipairs(build) do
		local tab,index = unpack(talent)
		local tab_index = 100*tab+index
		ranks[tab_index]=(ranks[tab_index] or 0)+1
		talent[3]=ranks[tab_index]
	end
end

function ZTA:MarkBuildTalentsTaken(buildSource)
	if not buildSource then return end

	self:ClearBuildTalentsTaken(buildSource)

	local build = buildSource.build
	for tab,index in self.talentpairs(false) do
		local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=tab,talentIndex=index})
		local tex, currank = info.icon, info.rank
		if tex then
			for rank=1,currank do
				local found
				for t,talent in ipairs(build) do
					if talent[1]==tab and talent[2]==index and not talent.taken and not talent.preview then
						--self:Debug(tab..","..talent.." ".."build#"..n.." "..((i>realrank)and"preview"or"taken"))
						if rank>currank then -- marking as prev-taken
							talent.preview=true
							buildSource.numpreview=buildSource.numpreview+1
						else
							talent.taken=true
							buildSource.numtaken=buildSource.numtaken+1
						end
						found=true
						break
					end
				end
				if not found then
					-- okay, we have a fuckup, but a real or a preview fuckup?
					if rank<=currank then
						buildSource.realfail=true
					else
						buildSource.previewfail=true
					end
					break
				end
			end
		end
		-- if build.realfail then break end -- does this break red builds?
	end
	if buildSource.realfail then buildSource.previewfail=true end
	self:Debug("MarkBuildTalentsTaken, taken "..buildSource.numtaken)
end

---
-- first, a diagnosis: can this be done at all?
-- * GREEN: we can proceed safely; player's current build is a direct start-based subset of the target build, OR can be fixed within the currently available points.
-- * YELLOW: minor fuckup; player's current build is a non-start-based subset of the target build and can not be fixed in the remaining points.
-- * RED: major fuckup; player's current build is NOT a subset of the target build.
-- * BLACK: totally unusable, broken, incomplete...
-- * NONE: no/empty build given.
--
-- Used only in GetSuggestion.
function ZTA:GetBuildStatus(buildSource,preview)

	if self:IsDisabled() then
		return {code="NONE",msg="disabled"}
	end

	if not buildSource then
		return {code="NONE"}
	end

	if buildSource.status then return buildSource.status end

	-- we have the build, let's check it.
	-- we could trust pruning for classes, but pet types change often.
	local _,myclass = UnitClass("player")
	if (buildSource.class and buildSource.class~=myclass) then 
		return {code="BLACK",msg="wrong class, wtf?"}
	end -- why wasn't it pruned with PruneRegisteredBuilds, anyway?


	local build = buildSource.build

	if not buildSource.parsed then
		-- okay, build seems to match us or the pet; let's parse it
		local parsedBuild,status = self:GetParsedBuild(build)
		if not parsedBuild then
			buildSource.status = status -- save it, it doesn't even parse
			return status
		end

		build = parsedBuild
		buildSource.build = build
		buildSource.parsed = true

		buildSource.maxcounts = self:GetBuildMaxTalents(buildSource)

		local verified,status = self:VerifyBuild(buildSource,buildSource.maxcounts)
		if not verified then
			buildSource.status = status -- save it, it doesn't verify
			return status
		end

	end

	self:MarkBuildTalentRanks(buildSource) -- ugly, changes the build contents, but meh
	self:MarkBuildTalentsTaken(buildSource) -- ugly, changes the build contents, but meh

	local talents_available = self:GetUnusedTalentPoints() -- -(preview and GetGroupPreviewTalentPointsSpent() or 0) -- classic: no preview
	local talents_spent = self:GetTalentsSpent()
	self:Debug("GetBuildStatus, correct taken "..buildSource.numtaken)

	if #build<talents_spent then -- build long complete
		return {code="BLACK",msg=L["status_black_smallbuild"]:format(#build,talents_spent)}

	elseif #build==talents_spent then
		-- complete or altogether different
		if buildSource.numtaken==#build then
			return {code="BLACK",msg=L["status_black_complete"]:format(#build,talents_spent)}
		else
			return {code="BLACK",msg=L["status_black_different"]:format(#build,talents_spent)}
		end
	end
	
	if #build - buildSource.numtaken > self.MAXTALENTS - talents_spent then -- still need more talents than will ever have
		return {code="RED",missed=(#build - buildSource.numtaken - self.MAXTALENTS + talents_spent)}
	end


	-- To glean where we're at, we need to remove player's current talents from the start of the target build plan, and see what that gives us.
	-- Or at least mark them as taken.

	local status={code="?",pointsleft=0,missed=0}


	-- REMOVED FROM HERE: handling selected spec,dualspec,pet



	local force=self.db.profile.zta_forcebuild

	if (preview and build.previewfail or build.realfail) and not force then
		--self:Debug("Code: RED. B0rked.")
		return {code="RED",missed=(#build - buildSource.numtaken - self.MAXTALENTS + talents_spent)} -- if real status is RED, preview status doesn't matter
	end

	-- Whew, it's not RED, so maybe it's GREEN?
	-- if that's equal to the number of the player's talents, we're GREEN. Unless we were RED already, screw it then.
	--local spent = talents_spent -- +(preview and GetGroupPreviewTalentPointsSpent(pet) or 0) -- classic: no preview

	-- Count missed talents; they'll have to make up for those if they want to get back on the true path of enlightenment - that is, the proper build.
	local missed=0
	for n=1,talents_spent do if not build[n].taken and not (preview and build[n].preview) then missed=missed+1 end end

	--[[
	local maxcounts = buildSource.maxcounts
	local overshot=0
	for tab,talent in self.talentpairs() do
		local name,_,_,_,rank = GetTalentInfo(tab,talent,false)
		if rank>maxcounts[tab][talent] then overshot=overshot+rank-maxcounts[tab][talent] end
	end
	--]]
	--self:Debug("GetBuildStatus, missed %d, overshot %d, available %d",missed,overshot,talents_available)

	if missed==0 then
		-- perfect.
		status.code="GREEN"
	elseif missed <= talents_available then
		-- whew, safe.
		status.code="GREEN" -- status.pointsleft=talents_available status.missed=missed
	else
		-- maybe one day
		status.code="YELLOW" status.pointsleft=talents_available status.missed=missed
	end


	if (preview and build.previewfail or build.realfail) and force then
		-- RED comes back
		status.code="RED"
		status.missed=(#build - buildSource.numtaken - self.MAXTALENTS + talents_spent)
	end

	assert(status.code~="?")

	return status
end

local function QuickDumpStatusAndSuggestion(status,sug)
	local s=""
	s=s..(status and status.code or "?")
	if status and (status.code=="YELLOW") then s=s..(" (%d)"):format(status.pointsleft-status.missed) end
	if status and (status.code=="BLACK") then s=s..(" (%s)"):format(status.msg) end
	s=s..": "
	if sug then
		for i=1,#sug do s=s..sug[i].tab..","..sug[i].talent.."; " end
	else
		s=s.."none"
	end
	return s
end


ZTA.US_CALLS={}
--- wrapper for MakeSuggestion and previews
function ZTA:UpdateSuggestions()
	local preview = GetCVarBool("previewTalentsOption")

	tinsert(ZTA.US_CALLS,debugstack())

	self:Debug("&_PUSH UpdateSuggestions()")

	self.suggestion,self.status=self:GetSuggestion(self.currentBuild)
	self:Debug("suggestion: "..QuickDumpStatusAndSuggestion(self.status,self.suggestion))
	if preview then
		self.suggestion_preview,self.status_preview = self:GetSuggestion(self.currentBuild,true)
		self:Debug("suggestion_preview: "..QuickDumpStatusAndSuggestion(self.status_preview,self.suggestion_preview))
	end

	self:ShowTalentSuggestions()

	if self.suggestion and #self.suggestion>0 then
		--if LibTutorial then LibTutorial:ShowTutorial("ZTA3") end
	end
	self:Debug("&_POP")
end

---
-- @return suggestion,status
function ZTA:GetSuggestion(buildSource,preview)
	
	local status = self:GetBuildStatus(buildSource,preview)

	if status.code=="BLACK" or status.code=="NONE" then return {},status end

	local build = buildSource.build

	-- clear any old suggestions, for starters
	local suggestion={}

	local addSuggestion = function (tab,talent,rank)
		suggestion[tab.."."..talent] = (suggestion[tab.."."..talent] or 0) + 1
		table.insert(suggestion,{tab=tab,talent=talent,rank=rank})
		--self:Debug(tab,talent)
	end

	if self:IsBuildStatusUsable(status) then
		-- suggest away!
		local points = self:GetUnusedTalentPoints()
		if preview then points=points-GetGroupPreviewTalentPointsSpent() end
		for i=1,#build do
			if points==0 then break end
			local tab,talent,rank = unpack(build[i])
			if not build[i].taken and not (preview and build[i].preview) then
				points=points-1
				addSuggestion(tab,talent,rank)
			end
		end
	end

	return suggestion,status
end

function ZTA:IsOutOfOrder()
	return self.outOfOrder
end

function ZTA:IsDisabled()
	return self.disabled
end

function ZTA:Hint(tab,talent)
	local tabname, texture, points, fileName = GetTalentTabInfo(tab,false)
	local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=tab,talentIndex=talent})
	
	ZGV:Print("Suggestion: Upgrade your talent '"..info.name.."'.")
end

function ZTA:GetTalentsSpent()
	if (self.db.profile.fake_talentsspent or -1)>-1 then return self.db.profile.fake_talentsspent end
	local tabs = 3 -- classic: hardcoded
	local talentsSpent = 0
	for i=1, tabs do
		local treeID, name, _, texture, pointsSpent, fileName = GetTalentTabInfo(i,false)
		talentsSpent = talentsSpent + pointsSpent
	end
	return talentsSpent
end

function ZTA:GetUnusedTalentPoints()
	if (self.db.profile.fake_talentsunused or -1)>-1 then return self.db.profile.fake_talentsunused end
	return UnitCharacterPoints("player")
end


---
-- @return build,status|nil
function ZTA:GetParsedBuild(build)
	local parsedBuild
	if type(build)=="string" then
		if (build:find("^%d+$")) then
			-- numbers; Blizzard format
			parsedBuild = self:ParseBlizzardTalents(build)
			if parsedBuild then
				-- parsed? save.
				return parsedBuild,nil --GOOD
			else
				return nil,{code="BLACK",msg=L['status_black_badblizzard']}
			end
		else
			-- text; text lines format
			local msg
			parsedBuild,msg = self:ParseTextTalents(build)
			if parsedBuild then
				-- parsed? save.
				self:Debug("Parsed")
				return parsedBuild,nil --GOOD
			else
				self:Debug("Boo!")
				return nil,{code="BLACK",msg=L['status_black_brokenbuild']:format(msg)}
			end
		end
	elseif type(build)=="table" and type(build[1])=="string" then
		local msg
		parsedBuild,msg = self:ParseTableTalents(build)
		if parsedBuild then
			-- parsed? save.
			self:Debug("Parsed")
			return parsedBuild,nil --GOOD
		else
			self:Debug("Boo!")
			return nil,{code="BLACK",msg=L['status_black_brokenbuild']:format(msg)}
		end
	end
end

function ZTA:VerifyBuild(buildSource)
	-- Just check if build doesn't require ranks higher than player can have.
	local maxcounts = buildSource.maxcounts
	for tab,talents in ipairs(maxcounts) do
		for talent,count in ipairs(talents) do
			local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=tab,talentIndex=talent})
			local name,maxrank = info.name, info.maxRank
			if name and maxrank<count then
				return false,{code="BLACK",msg=L['status_black_builderror']:format(count,name,maxrank)}
			end
		end
	end
	return true
end

--- select a build. Determine if it's a pet build from the build itself.
function ZTA:SetCurrentBuild(key,startup)
	local builds = self.registeredBuilds

	self:Debug("&_PUSH SetCurrentBuild "..tostring(key))

	--[[
	if type(key)=="string" then
		for i,build in ipairs(builds) do
			if build.title==num then
				num=i
				break
			end
		end
		if type(num)=="string" then
			self:Print("no such build name: "..num)
			num=0
		end
	end
	--]]

	local buildSource = builds[key]

	if buildSource then

		self:GetBuildStatus(buildSource) -- just to set some things in the build

		self.currentBuild = buildSource
		self.currentBuildTitle = buildSource.title or nil

	else
		self.status={code="NONE"}
		self.status_preview={}
		self.currentBuild = nil
		self.currentBuildTitle = nil
	end

	self.db.char.zta_currentBuildKey = key

	self:UpdateSuggestions()

	if not startup and buildSource then
		ZGV.db.char.gear_active_build = buildSource.statweights
		ZGV.db.char.gear_selected_build = buildSource.statweights
	end

	self:Debug("&_POP")
end

local zeroer = {__index = function() return 0 end}

-- returns ranks suggested at num talents used
function ZTA:GetBuildTalentsAt(num,build)
	if not build then build=self.currentBuild.build end
	if num>#build then num=#build end
	local counts = {} for tab=1,3 do counts[tab]=setmetatable({},zeroer) end
	for i=1,num do
		local tab,talent = build[i][1],build[i][2]
		counts[tab][talent]=counts[tab][talent]+1
	end
	return counts
end
	
-- counts max ranks for talents in this build
function ZTA:GetBuildMaxTalents(buildSource)
	local maxcounts = {} for tab=1,3 do maxcounts[tab]=setmetatable({},zeroer) end

	if not buildSource then buildSource=self.currentBuild end
	
	for i,talent in ipairs(buildSource.build) do
		local tab,index = talent[1],talent[2]
		maxcounts[tab][index]=maxcounts[tab][index]+1
	end

	return maxcounts
end

function ZTA:SetOption(cmd)
	LibStub("AceConfigCmd-3.0").HandleCommand(self, "zta", "ZygorTalentAdvisor", cmd)
end

function ZTA:OpenOptions()
	ZGV:OpenOptions("zta")
end


function ZTA:GetStatusMessage()
	local status = self.status
	if not status or not status.code then return "" end
	
	if status.code=="BLACK" then return status.msg
	elseif status.code=="RED" then
		--local _,maxcounts = self:CountBuildTalents(nil,build)
		--local maxcount = maxcounts[tab] and maxcounts[tab][talent] or 0
		if self.db.profile.zta_forcebuild then
			return L['status_red_forced']:format(status.missed)
		else
			return L['status_red']
		end
		-- ? L['status_red_forced']
	elseif status.code=="GREEN" then return L['status_green']
	elseif status.code=="YELLOW" then return L['status_yellow']:format(status.pointsleft-status.missed)
	end
end

local talentCache
function ZTA:GetTalentsIntoCache(pet)
	do return end -- NOT IMPLEMENTED, this is DumpTalentSpells pasted below for future work.
	if talentCache then return talentCache end

	local s,_,myclass
	if not pet then _,myclass = UnitClass("player") else _,myclass = GetTalentTabInfo(1,false,pet) end
	s = "	[\""..myclass.."\"]={\n"
	if pet then s = s .. "		[\"pet\"]=1,\n" end
	for tab=1,GetNumTalentTabs(false,pet) do
		local id,tabname = GetTalentTabInfo(tab,false,pet)
		--s = s .. "	[\""..tabname.."\"]={\n"
		for talent=1,GetNumTalents(tab,false,pet) do
			local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=tab,talentIndex=talent})
			local name, texture = info.name, info.icon
			local link = GetTalentLink and GetTalentLink(tab,talent,false,pet)
			if link then
				local _,_,id = link:find("talent:([0-9]+)")
				s = s .. "		[\""..name.."\"]="..id..",\n"
			else
				-- shit, classic, use textures..?
				--s = s .. "		-- no link for "..tab..","..talent.."\n"
				s = s .. "		[\""..name.."\"]="..texture..",\n"
			end
		end
		if tab<GetNumTalentTabs(false,pet) then s = s .. "\n" end
	end
end

function ZTA:GetTalentRowColForID(id,pet)
	for tree=1,GetNumTalentTabs(false,pet) do
		for index=1,GetNumTalents(tree,false,pet) do
			local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=tree,talentIndex=index,isPet=pet, isInspect=false})
			local row,col = info.tier, info.column
			local link = GetTalentLink(tree,index,false,pet)
			if link then
				local _,_,link_id = link:find("talent:([0-9]+)")
				if link_id==id then return row,col end
			end
		end
	end
end

function ZTA:GetTalentTreeIndexForID(id,pet)
	id=tonumber(id)
	for tree=1,GetNumTalentTabs(false,pet) do
		for index=1,GetNumTalents(tree,false,pet) do
			local link = GetTalentLink(tree,index,false,pet)
			if link then
				local _,_,link_id = link:find("talent:([0-9]+)")
				if tonumber(link_id)==id then return tree,index end
			end
		end
	end
end



function ZTA:DumpTalents()
	if not self.dumpFrame then self:CreateDumpFrame() end

	local tostr = function(val)
		if type(val)=="string" then
			return '"'..val..'"'
		elseif type(val)=="number" then
			return tostring(val)
		elseif not val then
			return "nil"
		elseif type(val)=="boolean" then
			return tostring(val).." ["..type(val).."]"
		end
	end
	local s = ""

	s = "Zygor Talent Advisor v"..self.version.."\n"

	local dumpTalents = function()
		for tab=1,GetNumTalentTabs(false) do
			s=s..("%d. %s:\n"):format(tab,tostring(select(2,GetTalentTabInfo(tab,false))))
			for talent=1,GetNumTalents(tab,false) do
				local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=tree,talentIndex=talent,isPet=false, isInspect=false})
				local name,realrank,maxrank,rank = info.name, info.rank, info.maxRank, info.previewRank
				if rank>0 then
					s=s..(" %d.%d: %s (%d/%d)"):format(tab,talent,name,realrank,maxrank)
					if rank~=realrank then s=s..(" +%d"):format(rank) end
					s=s.."\n"
				end
			end
		end
	end

	local dumpBuild = function(build)
		if not build then return end
		for i=1,#build do
			local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=build[i][1],talentIndex=build[i][2],isPet=false, isInspect=false})
			local name = info.name
			s=s..("%d: %d.%d [%s] %s %s|n"):format(i,build[i][1],build[i][2],name or "?",build[i].taken and " (taken)" or "",build[i].preview and " (previewed)" or "")
		end
	end

	local dumpSuggestion = function(sug)
		if not sug then return end
		for i=1,#sug do
			local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=sug[i].tab,talentIndex=sug[i].talent,isPet=false, isInspect=false})
			local name = info.name
			s=s..("%d: %d.%d [%s] (total:%d)|n"):format(i, sug[i].tab,sug[i].talent, name or "?", sug[sug[i].tab.."."..sug[i].talent])
		end
	end

	local DoDump = function ()
		s=s.."\nCurrent talents: \n"
		dumpTalents()

		if self.currentBuildNum then
			s=s.."\nCurrent build: "..(self.currentBuildTitle).."|n"
			dumpBuild(self.currentBuild.build)
			s=s.."\nStatus: \n"
			for k,v in pairs(self.status) do
				s=s.."\n "..k.." = "..tostring(v)
			end
			s=s.."\n"
			if GetCVarBool("previewTalentsOption") then
				s=s.."\nStatus_preview: \n"
				for k,v in pairs(self.status_preview) do
					s=s.."\n "..k.." = "..tostring(v)
				end
				s=s.."\n"
			end
		end

		s=s.."\nSuggestion: \n"
		dumpSuggestion(self.suggestion)

		s=s..("\nTalents left: %d\n"):format(UnitCharacterPoints("player"))
	end
	
	DoDump(false)
	
	s = s .. "\nLog:\n"
	s = s .. self.Log:Dump(100)

	self.dumpFrame.editBox:SetText(s)
	--local title = self.CurrentGuideName or L["report_notitle"]
	--local author = self.CurrentGuide.author or L["report_noauthor"]
	--self.dumpFrame.title:SetText(L["report_title"]:format(title,author))
	ShowUIPanel(self.dumpFrame)
	self.dumpFrame.editBox:HighlightText(0)
	self.dumpFrame.editBox:SetFocus(true)
end

function ZTA:DumpVal(val,lev,maxlev,nofun)
	if lev>maxlev then return ("...") end
	local s = ""
	if type(val)=="string" then
		s = ('"%s"'):format(val)
	elseif type(val)=="number" then
		s = ("%s"):format(tostring(val))
	elseif type(val)=="function" then
		s = ("")
	elseif type(val)=="table" then
		s = "\n"
		for k,v in pairs(val) do
			if k~="parentStep"
			then
				if type(v)~="function" then
					s = s .. (" "):rep(lev) .. ("%s=%s"):format(k,self:DumpVal(v,lev+1,maxlev,nofun))
				elseif not nofun then
					s = s .. (" "):rep(lev) .. ("%s(function)\n"):format(k)
				end
			end
		end
	end

	return s.."\n"
end

function ZTA.ZTA_GameTooltipSetTalent(button)
	if not ZGV.db.profile.zta_enabled then return end

	local tab = PanelTemplates_GetSelectedTab(PlayerTalentFrame)
	local talent = button:GetID()	

	if ZTA:IsCurrentBuildUsable() then
		local maxcounts = ZTA.currentBuild.maxcounts
		local info = C_SpecializationInfo.GetTalentInfo({specializationIndex=tab,talentIndex=talent,isPet=false, isInspect=false})
		local name,cur_rank = info.name,info.rank
		local build_rank = maxcounts[tab][talent]
		local color=""
		local secondline=""
		if cur_rank>build_rank then
			-- overshot
			color="|cffff0000"
			secondline=L['talenttooltip_overshot']:format(cur_rank-build_rank)
		elseif cur_rank<build_rank then
			-- ok
			color="|cffffff00"
			secondline=L['talenttooltip_undershot']:format(build_rank-cur_rank)
		elseif build_rank>0 then
			color="|cff00ff00"
			secondline=L['talenttooltip_ok']:format(cur_rank-build_rank)
		else
			color="|cffaaaaaa"
			secondline=L['talenttooltip_none']
		end
		GameTooltip:AddLine(L['talenttooltip']:format(ZTA.currentBuildTitle,color,build_rank),1,1,1)
		if ZTA:GetUnusedTalentPoints()>0 then GameTooltip:AddLine(secondline,1,1,1) end
		GameTooltip:Show()
	end
end

function ZTA:CreateDumpFrame()
	local name = "ZygorTalentAdvisor_DumpFrame"

	local frame = CreateFrame("Frame", name, UIParent)
	self.dumpFrame = frame
	frame:SetBackdrop({
	bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
	edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 3, right = 3, top = 5, bottom = 3 }
	})
	frame:SetBackdropColor(0,0,0,1)
	frame:SetWidth(500)
	frame:SetHeight(400)
	frame:SetPoint("CENTER", UIParent, "CENTER")
	frame:Hide()
	frame:SetFrameStrata("DIALOG")
	tinsert(UISpecialFrames, name)
	
	local scrollArea = CreateFrame("ScrollFrame", name.."Scroll", frame, "UIPanelScrollFrameTemplate")
	scrollArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -50)
	scrollArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 8)

	local editBox = CreateFrame("EditBox", nil, frame)
	editBox:SetMultiLine(true)
	editBox:SetMaxLetters(99999)
	editBox:EnableMouse(true)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject(ChatFontSmall)
	editBox:SetWidth(400)
	editBox:SetHeight(270)
	editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
	self.dumpFrame.editBox = editBox
	
	scrollArea:SetScrollChild(editBox)
	
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT")

	local title = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
	self.dumpFrame.title = title
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
	title:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -30, -45)
	title:SetJustifyH("CENTER")
	title:SetJustifyV("TOP")

end


function ZTA:Debug (s,...)
	ZGV:Debug("&TalentAdv "..s,...)
end

function ZTA:Print (s,...)
	ZGV:Print("- Talent Advisor: "..s,...)
end



tinsert(ZGV.startups,{"Talent Advisor",function(self)
	ZTA:Initialize()
end})
