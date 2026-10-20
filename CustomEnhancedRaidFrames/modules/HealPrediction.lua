local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local ipairs = ipairs
local select = select

local GetTime = GetTime
local UnitGUID = UnitGUID
local hooksecurefunc = hooksecurefunc

local HealComm = LibStub("LibHealComm-4.0", true)

-- GLOBALS: ERF_CompactRaidFrameContainer_GetUnitFrame, ERF_CompactRaidFrameReservation_GetFrame, ADDON.CompactUnitFrame_UpdateHealPrediction, ADDON.DefaultCompactUnitFrameSetup

ADDON.CreatedCompactUnitFrames = {}
ADDON.CreatedUnitFrames = {
	"PlayerFrame",
	"PetFrame",
	"TargetFrame",
	"FocusFrame",
	"PartyMemberFrame1",
	"PartyMemberFrame2",
	"PartyMemberFrame3",
	"PartyMemberFrame4",
}

local optionsMapMeta = {
	__index = function(this, key)
		if key == "maxHealOverflowRatio" then
			return ADDON.db.profile.healPrediction.healMaxOverflowPercent
		end
	end
}

function ADDON.CreateHealPredictionBar(frame)
	if frame.ERFOverlay then
		return false
	end

	frame.customOptions = {}
	setmetatable(frame.customOptions, optionsMapMeta)

	frame.ERFOverlay = true

	ADDON.CreatedCompactUnitFrames[#ADDON.CreatedCompactUnitFrames + 1] = frame
	return true
end

function ADDON.CreateAllExistingBars(container)
	for frameType, pool in pairs(container.frameReservations) do
		for _, poolType in ipairs({"reservations", "unusedFrames"}) do
			for guid, frame in pairs(pool[poolType]) do
				ADDON.DefaultCompactUnitFrameSetup(frame)
			end
		end
	end
end

function ADDON.DefaultCompactUnitFrameSetup(frame)
	ADDON.CreateHealPredictionBar(frame)
end

do
	local frameCreationSpecifiers = {
		raid = { mapping = UnitGUID, setUpFunc = ADDON.DefaultCompactUnitFrameSetup, updateList = "normal"},
		pet = { setUpFunc = ADDON.DefaultCompactUnitFrameSetup, updateList = "mini" },
		flagged = { mapping = UnitGUID, setUpFunc = ADDON.DefaultCompactUnitFrameSetup, updateList = "normal"},
		target = { setUpFunc = ADDON.DefaultCompactUnitFrameSetup, updateList = "mini" },
	}

	local reservationFrame

	function ERF_CompactRaidFrameReservation_GetFrame(self, key)
		reservationFrame = self.reservations[key]
	end

	function ERF_CompactRaidFrameContainer_GetUnitFrame(self, unit, frameType)
		if reservationFrame then return end
		reservationFrame = nil

		local info = frameCreationSpecifiers[frameType];

		--Get the mapping for re-using frames
		local mapping;
		if ( info.mapping ) then
			mapping = info.mapping(unit);
		else
			mapping = unit;
		end

		local frame = self.frameReservations[frameType].reservations[mapping]
		info.setUpFunc(frame)
	end
end

local function UnitGetIncomingHeals(unit, healer)
	local db = ADDON.db.profile.healPrediction
	if not db.heal then
		return 0
	end

	return HealComm:GetHealAmount(UnitGUID(unit), HealComm.ALL_HEALS, GetTime() + db.healThresholdSeconds, healer and UnitGUID(healer))
end

if _G.UnitGetIncomingHealsInsecure then
	_G.UnitGetIncomingHealsInsecure = UnitGetIncomingHeals
else
	_G.UnitGetIncomingHeals = UnitGetIncomingHeals
end

function ADDON.CompactUnitFrame_UpdateMaxHealth(frame)
	ADDON.CompactUnitFrame_UpdateHealPrediction(frame, true)
end

function ADDON.CompactUnitFrame_UpdateHealPrediction(frame, isMaxHealthUpdate)
	if not frame.statusText then
		-- ignore nameplates
		return
	end

	if ADDON.CreateHealPredictionBar(frame) or not isMaxHealthUpdate then
		CompactUnitFrame_UpdateHealPrediction(frame)
	end
end

local function HasGUID(guid, ...)
	for i = 1, select("#", ...) do
		if select(i, ...) == guid then
			return true
		end
	end
end

function ADDON.HealPredictionUpdateGUIDs(...)
	for j = 1, #ADDON.CreatedCompactUnitFrames do
		local frame = ADDON.CreatedCompactUnitFrames[j]

		if frame.displayedUnit and frame:IsVisible() and HasGUID(UnitGUID(frame.displayedUnit), ...) then
			ADDON.CompactUnitFrame_UpdateHealPrediction(frame)
		end
	end

	for _, frameName in ipairs(ADDON.CreatedUnitFrames) do
		local frame = _G[frameName]
		if frame and frame.unit and frame:IsVisible() and HasGUID(UnitGUID(frame.unit), ...) then
			UnitFrameHealPredictionBars_Update(frame)
		end
	end
end

function ADDON.HealPredictionUpdateAll()
	for _, frame in ipairs(ADDON.CreatedCompactUnitFrames) do
		if frame.displayedUnit and frame:IsVisible() then
			ADDON.CompactUnitFrame_UpdateHealPrediction(frame)
		end
	end

	for _, frameName in ipairs(ADDON.CreatedUnitFrames) do
		local frame = _G[frameName]
		if frame and frame.unit and frame:IsVisible() and UnitExists(frame.unit) then
			UnitFrameHealPredictionBars_Update(frame)
		end
	end
end

local HealCommHandler = {}
do
	ADDON.HealCommHandler = HealCommHandler

	function HealCommHandler:HealStarted(event, casterGUID, spellID, healType, endTime, ...)
		ADDON.HealPredictionUpdateGUIDs(...)
	end

	function HealCommHandler:HealStopped(event, casterGUID, spellID, healType, interrupted, ...)
		ADDON.HealPredictionUpdateGUIDs(...)
	end

	function HealCommHandler:ModifierChanged(event, guid, modifier)
		ADDON.HealPredictionUpdateGUIDs(guid)
	end

	function HealCommHandler:GUIDDisappeared(event, guid)
		ADDON.HealPredictionUpdateGUIDs(guid)
	end
end

function ADDON:ToggleHealComm(state)
	if state and not self.healCommEnabled then
		self.healCommEnabled = true
		HealComm.RegisterCallback(HealCommHandler, "HealComm_HealStarted", "HealStarted")
		HealComm.RegisterCallback(HealCommHandler, "HealComm_HealDelayed", "HealStarted")
		HealComm.RegisterCallback(HealCommHandler, "HealComm_HealUpdated", "HealStarted")
		HealComm.RegisterCallback(HealCommHandler, "HealComm_HealStopped", "HealStopped")
		HealComm.RegisterCallback(HealCommHandler, "HealComm_ModifierChanged", "ModifierChanged")
		HealComm.RegisterCallback(HealCommHandler, "HealComm_GUIDDisappeared", "GUIDDisappeared")
	elseif not state and self.healCommEnabled then
		self.healCommEnabled = nil
		HealComm.UnregisterCallback(HealCommHandler, "HealComm_HealStarted")
		HealComm.UnregisterCallback(HealCommHandler, "HealComm_HealStopped")
		HealComm.UnregisterCallback(HealCommHandler, "HealComm_HealDelayed")
		HealComm.UnregisterCallback(HealCommHandler, "HealComm_HealUpdated")
		HealComm.UnregisterCallback(HealCommHandler, "HealComm_ModifierChanged")
		HealComm.UnregisterCallback(HealCommHandler, "HealComm_GUIDDisappeared")
	end
end

function ADDON:InitializeBars()
	if self.initializedBars then return end

	if CompactRaidFrameContainer_GetUnitFrame then
		self.CreateAllExistingBars(CompactRaidFrameContainer)

		hooksecurefunc("CompactRaidFrameContainer_GetUnitFrame", ERF_CompactRaidFrameContainer_GetUnitFrame)
		hooksecurefunc("CompactRaidFrameReservation_GetFrame", ERF_CompactRaidFrameReservation_GetFrame)
	end

	hooksecurefunc("DefaultCompactUnitFrameSetup", ADDON.DefaultCompactUnitFrameSetup)
	hooksecurefunc("DefaultCompactMiniFrameSetup", ADDON.DefaultCompactUnitFrameSetup)

	hooksecurefunc("CompactUnitFrame_UpdateMaxHealth", ADDON.CompactUnitFrame_UpdateMaxHealth)

	self:ToggleHealComm(ADDON.db.profile.healPrediction.heal)

	self.initializedBars = true
end
