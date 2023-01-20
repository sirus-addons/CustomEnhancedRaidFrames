local ADDON_NAME, PRIVATE = ...
PRIVATE.ADDON = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

local ADDON = PRIVATE.ADDON
_G["ERF"] = ADDON

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local ipairs = ipairs
local next = next
local pairs = pairs
local print = print
local strconcat = strconcat
local twipe = table.wipe

local C_Timer = C_Timer
local CopyTable = CopyTable
local GetActiveRaidProfile = GetActiveRaidProfile
local GetFramerate = GetFramerate
local GetRaidProfileFlattenedOptions = GetRaidProfileFlattenedOptions
local InCombatLockdown = InCombatLockdown
local debugprofilestop = debugprofilestop

-- GLOBALS: CompactRaidFrameContainer, CompactRaidFrameManager, InterfaceOptionsFrame_OpenToCategory, LibStub, ERFCharDB

local Masque = LibStub("LibButtonFacade", true)
LibStub("LibSharedMedia-3.0"):Register("statusbar", "Blizzard Raid PowerBar", "Interface\\RaidFrame\\Raid-Bar-Resource-Fill")

ADDON.TITLE = "Custom Enhanced Raid Frames"

function ADDON:Print(...)
	print(strconcat("|cfffffd00[", ADDON_NAME, "]|r ", ...))
end

function ADDON:OnInitialize()
	self.UpdateHandler = CreateFrame("Frame")
	self.UpdateHandler:Hide()
	self.UpdateHandler:SetScript("OnUpdate", self.OnUpdate)

	self:SetupDB()

	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	self:RegisterEvent("PLAYER_ROLES_ASSIGNED", "OnEvent")

	self:SecureHook("CompactRaidFrameContainer_LayoutFrames")
	self:SecureHook("CompactUnitFrame_UpdateAll")
	self:SecureHook("CompactUnitFrame_UpdateAuras", function(...)
		ADDON.CompactUnitFrame_UpdateAuras(...)
	end)

	self:RefreshProfileSettings()

	-- custom interface display
	self:SecureHook(self.dialog, "FeedGroup", function() self:CustomizeOptions() end)

	self:SecureHook("CompactUnitFrameProfiles_ApplyProfile")

	self:RegisterChatCommand("erf", function(arg, ...)
		if arg == "reload" or arg == "rl" or arg == "кд" then
			self:CompactUnitFrameProfiles_ApplyProfile()
			self:CompactRaidFrameContainer_LayoutFrames()
			self:Print("Hard Reload")
			return
		end

		InterfaceOptionsFrame_OpenToCategory(ADDON.TITLE)
		InterfaceOptionsFrame_OpenToCategory(ADDON.TITLE)
	end)

	self:SafeRefresh()
	self:InitializeBars()
end

function ADDON:SetupDB()
	self.db = LibStub("AceDB-3.0"):New("ERFDB", self:Defaults())
	self.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

	local LibDualSpec = LibStub("LibDualSpec-1.0")
	LibDualSpec:EnhanceDatabase(self.db, ADDON_NAME)
	LibDualSpec:EnhanceOptions(self.profiles, self.db)

	self.config = LibStub("AceConfigRegistry-3.0")
	self.config:RegisterOptionsTable("ERF",					self:SetupOptions())
	self.config:RegisterOptionsTable("ERF Import Export",	self:CreateProfileOptions())
	self.config:RegisterOptionsTable("ERF Profiles",		self.profiles)

	self.dialog = LibStub("AceConfigDialog-3.0")
	self.dialog.general		= self.dialog:AddToBlizOptions("ERF",				ADDON.TITLE)
	self.dialog.import		= self.dialog:AddToBlizOptions("ERF Import Export",	L["Import/Export"],		ADDON.TITLE)
	self.dialog.profiles	= self.dialog:AddToBlizOptions("ERF Profiles",		L["Profiles"],			ADDON.TITLE)

	self:SecureHookScript(self.dialog.general, "OnShow", "OnOptionShow")
	self:SecureHookScript(self.dialog.general, "OnHide", "OnOptionHide")

	self.db.RegisterCallback(self, "OnProfileChanged", function(...) self:SafeRefresh() end)
	self.db.RegisterCallback(self, "OnProfileCopied", function(...) self:SafeRefresh() end)
	self.db.RegisterCallback(self, "OnProfileReset", function(...) self:SafeRefresh() end)

	self:SetInternalVariables()
end

function ADDON:SetInternalVariables()
	self:GetRaidProfileSettings()

	self.maxFrames = 10
	self.virtual = {
		shown = false,
		frames = {
			buffFrames = {},
			debuffFrames = {},
			dispelDebuffFrames = {},
		},
		groupType = "raid",
	}

	self.aurasCache = {}
	self.processedFrames = {}
	self.healthFrameColors = {}

	self.glowingFrames = {
		auraGlow = {
			buffFrames = {},
			debuffFrames = {},
		},
		frameGlow = {
			buffFrames = {},
			debuffFrames = {},
		},
	}

	-- coroutine
	self.FRAMETIME_TARGET = 1 / 55
	self.FRAMETIME_AVAILABLE = 8
	self.FRAMETIME_RESERVE = 8
	self.COROUTINE_TIMESTAMP = 0

	-- throttling refreshes
	self.reloadSettingsCooldown = nil
	self.reloadSettingsThrottle = 0.1
	self.refreshQueue = {}

	self.Masque = Masque and {} or nil

	if self.Masque then
		self.Masque.buffFrames = Masque:Group(ADDON.TITLE, "Buff Auras")
		self.Masque.debuffFrames = Masque:Group(ADDON.TITLE, "Debuff Auras")

		local ButtonFacade = LibStub("AceAddon-3.0"):GetAddon("ButtonFacade", true)
		if ButtonFacade and ButtonFacade.GuiUpdate then
			ButtonFacade:GuiUpdate() -- force update ButtonFacade addon list
		end
	end
end

function ADDON:OnEvent(event, ...)
	local groupType = ADDON.GetGroupType()

	if event == "PLAYER_REGEN_ENABLED" then
		for frame in self.IterateCompactFrames(groupType) do
			if not InCombatLockdown() then
				self:AddSubFrames(frame, groupType)
			end
		end

		if self.deffered then
			self:GetRaidProfileSettings()

			self:SafeRefresh()

			self.deffered = false
		end
	elseif event == "PLAYER_ROLES_ASSIGNED" then
		self:CustomizeOptions()
	end
end

function ADDON:RefreshProfileSettings()
	local groupType = self.GetGroupType()

	twipe(self.processedFrames)
	twipe(self.healthFrameColors)

	self.PowerBar_Revert()

	self.currentGroup = groupType

	local db = self.db.profile[self.currentGroup].nameAndIcons

	if db.name.enabled and not self:IsHooked("CompactUnitFrame_UpdateName") then
		self:SecureHook("CompactUnitFrame_UpdateName", function(frame)
			if not frame then return end
			self.CompactUnitFrame_UpdateName(frame, self.GetGroupType())
		end)
	elseif not db.name.enabled and self:IsHooked("CompactUnitFrame_UpdateName") then
		self:Unhook("CompactUnitFrame_UpdateName")
	end

	if db.statusText.enabled and not self:IsHooked("CompactUnitFrame_UpdateStatusText") then
		self:SecureHook("CompactUnitFrame_UpdateStatusText", function(frame)
			if not frame then return end
			self.CompactUnitFrame_UpdateStatusText(frame, self.GetGroupType())
		end)
	elseif not db.statusText.enabled and self:IsHooked("CompactUnitFrame_UpdateStatusText") then
		self:Unhook("CompactUnitFrame_UpdateStatusText")
	end

	if db.raidTargetIcon.enabled and not self:IsHooked("CompactUnitFrame_UpdateRaidTargetIcon") then
		self:SecureHook("CompactUnitFrame_UpdateRaidTargetIcon", function(frame)
			if not frame then return end
			self.CompactUnitFrame_UpdateRaidTargetIcon(frame, self.GetGroupType())
		end)
	elseif not db.raidTargetIcon.enabled and self:IsHooked("CompactUnitFrame_UpdateRaidTargetIcon") then
		self:Unhook("CompactUnitFrame_UpdateRaidTargetIcon")
	end

	if db.roleGroupIcon.enabled and not self:IsHooked("CompactUnitFrame_UpdateRoleGroupIcon") then
		self:SecureHook("CompactUnitFrame_UpdateRoleGroupIcon", function(frame)
			if not frame then return end
			self.CompactUnitFrame_UpdateRoleGroupIcon(frame, self.GetGroupType())
		end)
	elseif not db.roleGroupIcon.enabled and self:IsHooked("CompactUnitFrame_UpdateRoleGroupIcon") then
		self:Unhook("CompactUnitFrame_UpdateRoleGroupIcon")
	end

	if (db.roleIcon.enabled or self.db.profile[groupType].frames.showResourceOnlyForHealers) and not self:IsHooked("CompactUnitFrame_UpdateRoleIcon") then
		self:SecureHook("CompactUnitFrame_UpdateRoleIcon", function(frame)
			if not frame or not frame.unit then return end
			local groupType = self.GetGroupType()
			self.RoleIcon_Update(frame, groupType)
			self.PowerBar_Update(frame, groupType)
		end)
	elseif (not db.roleIcon.enabled and not self.db.profile[groupType].frames.showResourceOnlyForHealers) and self:IsHooked("CompactUnitFrame_UpdateRoleIcon") then
		self:Unhook("CompactUnitFrame_UpdateRoleIcon")
	end

	if db.readyCheckIcon.enabled and not self:IsHooked("CompactUnitFrame_UpdateReadyCheck") then
		self:SecureHook("CompactUnitFrame_UpdateReadyCheck", function(frame)
			if not frame then return end
			self:CompactUnitFrame_UpdateReadyCheck(frame, self.GetGroupType())
		end)
	elseif not db.readyCheckIcon.enabled and self:IsHooked("CompactUnitFrame_UpdateReadyCheck") then
		self:Unhook("CompactUnitFrame_UpdateReadyCheck")
	end

	if db.centerStatusIcon.enabled and not self:IsHooked("CompactUnitFrame_UpdateCenterStatusIcon") then
		self:SecureHook("CompactUnitFrame_UpdateCenterStatusIcon", function(frame)
			if not frame then return end
			self.CompactUnitFrame_UpdateCenterStatusIcon(frame, self.GetGroupType())
		end)
	elseif not db.centerStatusIcon.enabled and self:IsHooked("CompactUnitFrame_UpdateCenterStatusIcon") then
		self:Unhook("CompactUnitFrame_UpdateCenterStatusIcon")
	end

	if self.db.profile[self.currentGroup].frames.colorEnabled and not self:IsHooked("CompactUnitFrame_UpdateHealthColor") then
		self:SecureHook("CompactUnitFrame_UpdateHealthColor", function(frame)
			if not frame then return end
			self.CompactUnitFrame_UpdateHealthColor(frame, self.GetGroupType())
		end)
	elseif not self.db.profile[self.currentGroup].frames.colorEnabled and self:IsHooked("CompactUnitFrame_UpdateHealthColor") then
		self:Unhook("CompactUnitFrame_UpdateHealthColor")
	end

	self.Name_Revert()
	self.StatusText_Revert()
	self.RoleIcon_Revert()
	self.ReadyCheckIcon_Revert()
	self.CenterStatusIcon_Revert()
	self.HealthBar_Revert()
	self.RaidTargetIcon_Revert()
	self.RoleGroupIcon_Revert()
end

-- Profiles
function ADDON:CompactUnitFrameProfiles_ApplyProfile(profile)
	self:GetRaidProfileSettings(profile)

	if profile and (self.db:GetCurrentProfile() ~= profile) then
		self.SyncProfiles(profile)
	end

	if self.Masque then
		self.Masque.buffFrames = self.Masque.buffFrames or Masque:Group(ADDON.TITLE, "Buff Auras")
		self.Masque.debuffFrames = self.Masque.debuffFrames or Masque:Group(ADDON.TITLE, "Debuff Auras")

		local ButtonFacade = LibStub("AceAddon-3.0"):GetAddon("ButtonFacade", true)
		if ButtonFacade and ButtonFacade.GuiUpdate then
			ButtonFacade:GuiUpdate() -- force update ButtonFacade addon list
		end
	end

	if not self.reloadSettingsCooldown then
		self.reloadSettingsCooldown = self.reloadSettingsThrottle
		self.UpdateHandler:Show()
		ADDON.ReloadSetting()
	else
		self.reloadSettingsQueued = true
	end
end

function ADDON.ReloadSetting()
	ADDON:RefreshProfileSettings()
	ADDON:SafeRefresh()
	ADDON.reloadSettingsCooldown = nil
end

function ADDON:GetRaidProfileSettings(profile)
	local settings

	if InCombatLockdown() then
		profile = profile or self.db.profile.current_profile
		settings = self.db.profile.saved_profiles[profile] or self.db.profile.saved_profiles.default
		self.useCompactPartyFrames = true
		self.deffered = true
	else
		profile = profile or GetActiveRaidProfile()
		settings = GetRaidProfileFlattenedOptions(profile)

		if not settings then
			settings = self.db.profile.saved_profiles[profile] or self.db.profile.saved_profiles.default
		end

		self.useCompactPartyFrames = true
	end

	self.horizontalGroups = settings.horizontalGroups
	self.displayMainTankAndAssist = settings.displayMainTankAndAssist
	self.keepGroupsTogether = settings.keepGroupsTogether
	self.displayBorder = settings.displayBorder
	self.displayPowerBar = settings.displayPowerBar
	self.displayPets = settings.displayPets
	self.useClassColors = settings.useClassColors
	self.healthText = settings.healthText

	local savedProfile = {}
	savedProfile.horizontalGroups = settings.horizontalGroups
	savedProfile.displayMainTankAndAssist = settings.displayMainTankAndAssist
	savedProfile.keepGroupsTogether = settings.keepGroupsTogether
	savedProfile.displayBorder = settings.displayBorder
	savedProfile.displayPowerBar = settings.displayPowerBar
	savedProfile.displayPets = settings.displayPets
	savedProfile.useCompactPartyFrames = self.useCompactPartyFrames
	savedProfile.useClassColors = settings.useClassColors

	self.db.profile.current_profile = profile
	self.db.profile.saved_profiles[profile] = savedProfile
end

function ADDON.SyncProfiles(profile)
	if ERFCharDB then
		local dbProfiles = ADDON.db:GetProfiles()

		for _, v in ipairs(dbProfiles) do
			if profile == v then
				ADDON.db:SetProfile(profile)

				ADDON:CustomizeOptions()
			end
		end
	end
end

-- Config
function ADDON:ConfigOptionsOpen()
	local index = ERFCharDB and 3 or 2
	local tabsP = self.dialog.general.obj.children
	and self.dialog.general.obj.children[index]

	tabsP:SelectTab(ADDON.GetGroupType())

	C_Timer:NewTicker(5, function() self:CustomizeOptions() end)
end

function ADDON:OnOptionShow()
	self.isOptionsShown = true
	self:ShowRaidFrame()
	self:ConfigOptionsOpen()
end

function ADDON:OnOptionHide()
	self.isOptionsShown = nil
	self:HideRaidFrame()
end

function ADDON:ShowRaidFrame()
	if not InCombatLockdown() and not GetDisplayedAllyFrames() and self.useCompactPartyFrames then
		CompactRaidFrameContainer:Show()
		CompactRaidFrameManager:Show()
	end
end

function ADDON:HideRaidFrame()
	if not InCombatLockdown() and not GetDisplayedAllyFrames() and self.useCompactPartyFrames then
		CompactRaidFrameContainer:Hide()
		CompactRaidFrameManager:Hide()
	end

	self:HideVirtual()
end

function ADDON:CustomizeOptions()
	if not self.isOptionsShown then return end

	local virtualFramesButton = self.dialog.general.obj.children and self.dialog.general.obj.children[1]

	if virtualFramesButton then
		virtualFramesButton:ClearAllPoints()
		virtualFramesButton:SetPoint("TOPRIGHT", self.dialog.general.obj.label:GetParent(), "TOPRIGHT", -10, -15)
	end

	local index = ERFCharDB and 3 or 2
	local groupTypelabel = self.dialog.general.obj.children
		and self.dialog.general.obj.children[index]
		and self.dialog.general.obj.children[index].children
		and self.dialog.general.obj.children[index].children[1]
		and self.dialog.general.obj.children[index].children[1].label

	if groupTypelabel then
		groupTypelabel:SetText(L["You are in |cFFC80000<text>|r"]:gsub("<text>", ADDON.GetGroupType() == "raid" and L["Raid_decl2"] or L["Party_decl2"]))
	end

	if ERFCharDB then
		local profileLabel = self.dialog.general.obj.children and self.dialog.general.obj.children[2] and self.dialog.general.obj.children[2].label
		if profileLabel then
			profileLabel:SetText(L["Profile: |cFFC80000<text>|r"]:gsub("<text>", self.db:GetCurrentProfile()))
		end
	end
end

function ADDON.OnUpdate(self, elapsed)
	if ADDON.reloadSettingsCooldown then
		ADDON.reloadSettingsCooldown = ADDON.reloadSettingsCooldown - elapsed

		if ADDON.reloadSettingsCooldown <= 0 then
			ADDON.reloadSettingsCooldown = nil
			if ADDON.reloadSettingsQueued then
				ADDON.reloadSettingsQueued = nil
				ADDON.ReloadSetting()
			end
		end
	end

	if ADDON.COROUTINE then
		local frametimeStep = ADDON.FRAMETIME_TARGET - elapsed

		if frametimeStep ~= 0 then
			frametimeStep = frametimeStep * 1000
			ADDON.FRAMETIME_AVAILABLE = math.max(5, ADDON.FRAMETIME_AVAILABLE + frametimeStep)
		end

		ADDON.COROUTINE_TIMESTAMP = debugprofilestop()

		local isInCombatLockDown = InCombatLockdown()
		local groupType = ADDON.GetGroupType()
		local status, err = coroutine.resume(ADDON.COROUTINE, groupType, isInCombatLockDown)

		if not status then
			ADDON.COROUTINE = nil
			self:Hide()
			geterrorhandler()(err)
		elseif coroutine.status(ADDON.COROUTINE) == "dead" then
			ADDON.COROUTINE = nil
			self:Hide()
		end
	elseif not ADDON.reloadSettingsCooldown then
		self:Hide()
	end
end

function ADDON.RefrashCoroutine(groupType, isInCombatLockdown)
	local frame, fType = next(ADDON.refreshQueue)
	while frame do
		if fType == "frame" then
			ADDON:LayoutFrame(frame, groupType, isInCombatLockdown)
			ADDON.MasqueSupport(frame)
		elseif fType == "group" then
			ADDON:LayoutGroup(frame, groupType, isInCombatLockdown)
		end

		if (debugprofilestop() - ADDON.COROUTINE_TIMESTAMP) > ADDON.FRAMETIME_AVAILABLE then
			coroutine.yield()
		end

		frame, fType = next(ADDON.refreshQueue)
	end
end

function ADDON:RefreshConfig(virtualGroupType)
	local groupType = self.GetGroupType()

	twipe(self.healthFrameColors)

	if self.virtual.shown then
		self:ShowVirtual(virtualGroupType)
	end

	for group in self.IterateCompactGroups(groupType) do
		self.refreshQueue[group] = "group"
	end

	for frame in self.IterateCompactFrames(groupType) do
		self.refreshQueue[frame] = "frame"
	end

	self:CoroutineUpdateFrames(groupType)
end

function ADDON:CoroutineUpdateFrames(groupType)
	if not self.COROUTINE and tCount(self.refreshQueue) ~= 0 then
		self.COROUTINE = coroutine.create(self.RefrashCoroutine)

		local framerate = GetFramerate()
		self.FRAMETIME_TARGET = framerate > 63 and (1 / 60) or (1 / 55)
		self.FRAMETIME_AVAILABLE = 1000 / framerate - self.FRAMETIME_RESERVE

		local isInCombatLockdown = InCombatLockdown()
		if not groupType then
			groupType = self.GetGroupType()
		end

		local status, err = coroutine.resume(self.COROUTINE, groupType, isInCombatLockdown)
		if not status then
			self.COROUTINE = nil
			self.UpdateHandler:Hide()
			geterrorhandler()(err)
		elseif coroutine.status(self.COROUTINE) == "dead" then
			self.COROUTINE = nil
			self.UpdateHandler:Hide()
		else
			self.UpdateHandler:Show()
			return true
		end
	end
end

function ADDON:SafeRefresh(virtualGroupType)
	ADDON:RefreshConfig(virtualGroupType)
end

-- Settings
function ADDON:Defaults()
	return CopyTable(PRIVATE.DEFAULTS)
end

function ADDON:RestoreDefaults(groupType, frameType, subType)
	if InCombatLockdown() then
		self:Print(L["Can not refresh settings while in combat"])
		return
	end

	local defaults_settings = subType and self:Defaults()["profile"][groupType][frameType][subType] or self:Defaults()["profile"][groupType][frameType]

	for k, v in pairs(defaults_settings) do
		if subType then
			self.db.profile[groupType][frameType][subType][k] = v
		else
			self.db.profile[groupType][frameType][k] = v
		end
	end

	self:SafeRefresh(groupType)
end

function ADDON:CopySettings(dbFrom, dbTo)
	if InCombatLockdown() then
		self:Print(L["Can not refresh settings while in combat"])
		return
	end

	for k, v in pairs(dbFrom) do
		if dbTo[k] ~= nil then
			dbTo[k] = v
		end
	end

	self:SafeRefresh(ADDON.GetGroupType())
end

function ADDON:RestoreDefaultsByTable(groupType, frameType, subType, vars)
	if InCombatLockdown() then
		self:Print(L["Can not refresh settings while in combat"])
		return
	end

	local defaults_settings = subType and self:Defaults()["profile"][groupType][frameType][subType] or self:Defaults()["profile"][groupType][frameType]

	for _, v in ipairs(vars) do
		self.db.profile[groupType][frameType][v] = defaults_settings[v]
	end

	self:SafeRefresh(groupType)
end

function ADDON:CopySettingsByTable(dbFrom, dbTo, vars)
	if InCombatLockdown() then
		self:Print(L["Can not refresh settings while in combat"])
		return
	end

	for _, v in ipairs(vars) do
		if dbFrom[v] ~= nil then
			dbTo[v] = dbFrom[v]
		end
	end

	self:SafeRefresh(ADDON.GetGroupType())
end