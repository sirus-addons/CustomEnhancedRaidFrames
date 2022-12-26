local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local ipairs = ipairs
local select = select
local max = math.max
local strformat = string.format

local CreateFrame = CreateFrame
local GetTime = GetTime
local UnitGUID = UnitGUID
local hooksecurefunc = hooksecurefunc

local HealComm = LibStub("LibHealComm-4.0")
local LibAbsorb = LibStub("SpecializedAbsorbs-1.0")

-- GLOBALS: CompactUnitFrameUtil_UpdateFillBar
-- GLOBALS: ERF_CompactRaidFrameContainer_GetUnitFrame, ERF_CompactRaidFrameReservation_GetFrame, ADDON.CompactUnitFrame_UpdateHealPrediction, ADDON.DefaultCompactUnitFrameSetup

ADDON.CreatedCompactUnitFrames = {}

function ADDON.CreateHealPredictionBar(frame)
	if frame.ERFOverlay then return end

	local overlay = CreateFrame("Frame", strformat("%sERFOverlay", frame:GetName()), frame.healthBar, "ERF_CompactUnitFrameOverlayTemplate")
	frame.ERFOverlay = overlay

	frame.myHealPrediction = overlay.myHealPrediction

	frame.otherHealPrediction = overlay.otherHealPrediction

	frame.totalAbsorb = overlay.totalAbsorb
	frame.totalAbsorbOverlay = overlay.totalAbsorbOverlay

	frame.myHealAbsorb = overlay.myHealAbsorb

	frame.myHealAbsorbLeftShadow = overlay.myHealAbsorbLeftShadow
	frame.myHealAbsorbRightShadow = overlay.myHealAbsorbRightShadow

	frame.overAbsorbGlow = overlay.overAbsorbGlow
	frame.overHealAbsorbGlow = overlay.overHealAbsorbGlow

	frame.name:SetParent(overlay)
	frame.name:SetDrawLayer("BORDER")
	frame.statusText:SetParent(overlay)
	frame.statusText:SetDrawLayer("BORDER")
	frame.raidTargetIcon:SetParent(overlay)
	frame.raidTargetIcon:SetDrawLayer("BORDER")
	frame.roleIcon:SetParent(overlay)
	frame.roleIcon:SetDrawLayer("BORDER")
	frame.roleGroupIcon:SetParent(overlay)
	frame.roleGroupIcon:SetDrawLayer("BORDER")
	frame.aggroHighlight:SetParent(overlay)
	frame.aggroHighlight:SetDrawLayer("BORDER")
	frame.selectionHighlight:SetParent(overlay)
	frame.selectionHighlight:SetDrawLayer("OVERLAY")

	local frameLevel = frame:GetFrameLevel()
	for _, debuffFrame in ipairs(frame.debuffFrames) do
		debuffFrame:SetFrameLevel(frameLevel + 2)
	end
	for _, bebuffFrame in ipairs(frame.buffFrames) do
		bebuffFrame:SetFrameLevel(frameLevel + 2)
	end
	for _, dispelDebuffFrame in ipairs(frame.dispelDebuffFrames) do
		dispelDebuffFrame:SetFrameLevel(frameLevel + 2)
	end
	frame.centerStatusIcon:SetFrameLevel(frameLevel + 2)

	ADDON.CreatedCompactUnitFrames[#ADDON.CreatedCompactUnitFrames + 1] = frame
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

	if ADDON.db.profile.healPrediction.heal or ADDON.db.profile.healPrediction.absorbs then
		frame.myHealPrediction:ClearAllPoints();
		frame.myHealPrediction:SetTexture(1,1,1);
		frame.myHealPrediction:SetGradient("VERTICAL", 8/255, 93/255, 72/255, 11/255, 136/255, 105/255);
		frame.myHealAbsorb:ClearAllPoints();
		frame.myHealAbsorb:SetTexture("Interface\\RaidFrame\\Absorb-Fill", true, true);
		frame.myHealAbsorbLeftShadow:ClearAllPoints();
		frame.myHealAbsorbRightShadow:ClearAllPoints();
		frame.otherHealPrediction:ClearAllPoints();
		frame.otherHealPrediction:SetTexture(1,1,1);
		frame.otherHealPrediction:SetGradient("VERTICAL", 3/255, 72/255, 5/255, 2/255, 101/255, 18/255);
		frame.totalAbsorb:ClearAllPoints();
		frame.totalAbsorb:SetTexture("Interface\\RaidFrame\\Shield-Fill");
		frame.totalAbsorb.overlay = frame.totalAbsorbOverlay;
		frame.totalAbsorbOverlay:SetTexture("Interface\\RaidFrame\\Shield-Overlay", true, true);	--Tile both vertically and horizontally
		frame.totalAbsorbOverlay:SetAllPoints(frame.totalAbsorb);
		frame.totalAbsorbOverlay.tileSize = 32;
		frame.overAbsorbGlow:ClearAllPoints();
		frame.overAbsorbGlow:SetTexture("Interface\\RaidFrame\\Shield-Overshield");
		frame.overAbsorbGlow:SetBlendMode("ADD");
		frame.overAbsorbGlow:SetPoint("BOTTOMLEFT", frame.healthBar, "BOTTOMRIGHT", -7, 0);
		frame.overAbsorbGlow:SetPoint("TOPLEFT", frame.healthBar, "TOPRIGHT", -7, 0);
		frame.overAbsorbGlow:SetWidth(16);
		frame.overHealAbsorbGlow:ClearAllPoints();
		frame.overHealAbsorbGlow:SetTexture("Interface\\RaidFrame\\Absorb-Overabsorb");
		frame.overHealAbsorbGlow:SetBlendMode("ADD");
		frame.overHealAbsorbGlow:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMLEFT", 7, 0);
		frame.overHealAbsorbGlow:SetPoint("TOPRIGHT", frame.healthBar, "TOPLEFT", 7, 0);
		frame.overHealAbsorbGlow:SetWidth(16);
	end
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
--[[
	if type(unit) ~= "string" or (healer and type(healer) ~= "string") then
		error("Usage: UnitGetIncomingHeals(\"unit\"[, \"healer\"]", 2)
	end

	if not UnitExists(unit) or (healer and not UnitExists(unit)) then
		return
	end
--]]

	if healer then
		return HealComm:GetCasterHealAmount(UnitGUID(healer), HealComm.CASTED_HEALS, GetTime() + ADDON.db.profile.healPrediction.healThresholdSeconds)
	else
		return HealComm:GetHealAmount(UnitGUID(unit), HealComm.ALL_HEALS, GetTime() + ADDON.db.profile.healPrediction.healThresholdSeconds)
	end
end

local function UnitGetTotalAbsorbs(unit)
--[[
	if type(unit) ~= "string" then
		error("Usage: UnitGetTotalAbsorbs(\"unit\"", 2)
	end

	if not UnitExists(unit) then
		return
	end
--]]

	return LibAbsorb.UnitTotal(UnitGUID(unit))
end

local function UnitGetTotalHealAbsorbs(unit)
--[[
	if type(unit) ~= "string" then
		error("Usage: UnitGetTotalAbsorbs(\"unit\"", 2)
	end
--]]

	return 0
end

--WARNING: This function is very similar to the function UnitFrameHealPredictionBars_Update in UnitFrame.lua.
--If you are making changes here, it is possible you may want to make changes there as well.
function ADDON.CompactUnitFrame_UpdateHealPrediction(frame)
	ADDON.CreateHealPredictionBar(frame)

	local _, maxHealth = frame.healthBar:GetMinMaxValues();
	local health = frame.healthBar:GetValue();

	local db = ADDON.db.profile.healPrediction

	if ( not db.heal or maxHealth <= 0 ) then
		frame.myHealPrediction:Hide();
		frame.otherHealPrediction:Hide();
		frame.totalAbsorb:Hide();
		frame.totalAbsorbOverlay:Hide();
		frame.overAbsorbGlow:Hide();
		frame.myHealAbsorb:Hide();
		frame.myHealAbsorbLeftShadow:Hide();
		frame.myHealAbsorbRightShadow:Hide();
		frame.overHealAbsorbGlow:Hide();
		return;
	end

	local myIncomingHeal = UnitGetIncomingHeals(frame.displayedUnit, "player") or 0;
	local allIncomingHeal = UnitGetIncomingHeals(frame.displayedUnit) or 0;
	local totalAbsorb = UnitGetTotalAbsorbs(frame.displayedUnit) or 0;

	--We don't fill outside the health bar with healAbsorbs.  Instead, an overHealAbsorbGlow is shown.
	local myCurrentHealAbsorb = UnitGetTotalHealAbsorbs(frame.displayedUnit) or 0;
	if ( health < myCurrentHealAbsorb ) then
		frame.overHealAbsorbGlow:Show();
		myCurrentHealAbsorb = health;
	else
		frame.overHealAbsorbGlow:Hide();
	end

	local maxHealOverflowRatio = db.healMaxOverflowPercent;
	--See how far we're going over the health bar and make sure we don't go too far out of the frame.
	if ( health - myCurrentHealAbsorb + allIncomingHeal > maxHealth * maxHealOverflowRatio ) then
		allIncomingHeal = maxHealth * maxHealOverflowRatio - health + myCurrentHealAbsorb;
	end

	local otherIncomingHeal = 0;

	--Split up incoming heals.
	if ( allIncomingHeal >= myIncomingHeal ) then
		otherIncomingHeal = allIncomingHeal - myIncomingHeal;
	else
		myIncomingHeal = allIncomingHeal;
	end

	local overAbsorb = false;
	--We don't fill outside the the health bar with absorbs.  Instead, an overAbsorbGlow is shown.
	if ( health - myCurrentHealAbsorb + allIncomingHeal + totalAbsorb >= maxHealth or health + totalAbsorb >= maxHealth ) then
		if ( totalAbsorb > 0 ) then
			overAbsorb = true;
		end

		if ( allIncomingHeal > myCurrentHealAbsorb ) then
			totalAbsorb = max(0,maxHealth - (health - myCurrentHealAbsorb + allIncomingHeal));
		else
			totalAbsorb = max(0,maxHealth - health);
		end
	end
	if ( overAbsorb ) then
		frame.overAbsorbGlow:Show();
	else
		frame.overAbsorbGlow:Hide();
	end

	local healthTexture = frame.healthBar:GetStatusBarTexture();

	local myCurrentHealAbsorbPercent = myCurrentHealAbsorb / maxHealth;

	local healAbsorbTexture = nil;

	--If allIncomingHeal is greater than myCurrentHealAbsorb, then the current
	--heal absorb will be completely overlayed by the incoming heals so we don't show it.
	if ( myCurrentHealAbsorb > allIncomingHeal ) then
		local shownHealAbsorb = myCurrentHealAbsorb - allIncomingHeal;
		local shownHealAbsorbPercent = shownHealAbsorb / maxHealth;
		healAbsorbTexture = CompactUnitFrameUtil_UpdateFillBar(frame, healthTexture, frame.myHealAbsorb, shownHealAbsorb, -shownHealAbsorbPercent);

		--If there are incoming heals the left shadow would be overlayed by the incoming heals
		--so it isn't shown.
		if ( allIncomingHeal > 0 ) then
			frame.myHealAbsorbLeftShadow:Hide();
		else
			frame.myHealAbsorbLeftShadow:SetPoint("TOPLEFT", healAbsorbTexture, "TOPLEFT", 0, 0);
			frame.myHealAbsorbLeftShadow:SetPoint("BOTTOMLEFT", healAbsorbTexture, "BOTTOMLEFT", 0, 0);
			frame.myHealAbsorbLeftShadow:Show();
		end

		-- The right shadow is only shown if there are absorbs on the health bar.
		if ( totalAbsorb > 0 ) then
			frame.myHealAbsorbRightShadow:SetPoint("TOPLEFT", healAbsorbTexture, "TOPRIGHT", -8, 0);
			frame.myHealAbsorbRightShadow:SetPoint("BOTTOMLEFT", healAbsorbTexture, "BOTTOMRIGHT", -8, 0);
			frame.myHealAbsorbRightShadow:Show();
		else
			frame.myHealAbsorbRightShadow:Hide();
		end
	else
		frame.myHealAbsorb:Hide();
		frame.myHealAbsorbRightShadow:Hide();
		frame.myHealAbsorbLeftShadow:Hide();
	end

	--Show myIncomingHeal on the health bar.
	local incomingHealsTexture = CompactUnitFrameUtil_UpdateFillBar(frame, healthTexture, frame.myHealPrediction, myIncomingHeal, -myCurrentHealAbsorbPercent);
	--Append otherIncomingHeal on the health bar.
	incomingHealsTexture = CompactUnitFrameUtil_UpdateFillBar(frame, incomingHealsTexture, frame.otherHealPrediction, otherIncomingHeal);

	--Appen absorbs to the correct section of the health bar.
	local appendTexture = nil;
	if ( healAbsorbTexture ) then
		--If there is a healAbsorb part shown, append the absorb to the end of that.
		appendTexture = healAbsorbTexture;
	else
		--Otherwise, append the absorb to the end of the the incomingHeals part;
		appendTexture = incomingHealsTexture;
	end
	CompactUnitFrameUtil_UpdateFillBar(frame, appendTexture, frame.totalAbsorb, totalAbsorb)
end

function ADDON.HealPredictionUpdateGUIDs(...)
	for i = 1, select("#", ...) do
		for j = 1, #ADDON.CreatedCompactUnitFrames do
			local frame = ADDON.CreatedCompactUnitFrames[j]

			if frame.displayedUnit and frame:IsVisible() and UnitGUID(frame.displayedUnit) == select(i, ...) then
				ADDON.CompactUnitFrame_UpdateHealPrediction(frame)
			end
		end
	end
end

function ADDON.HealPredictionUpdateAll()
	for _, frame in ipairs(ADDON.CreatedCompactUnitFrames) do
		if frame.displayedUnit and frame:IsVisible() then
			ADDON.CompactUnitFrame_UpdateHealPrediction(frame)
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

local LibAbsorbHandler = {}
do
	ADDON.LibAbsorbHandler = LibAbsorbHandler

	--[[
		Whenever the unit that radiates an AREA effect is created (visible/non-visible)
		Note that the actual effect on the unit that absorbs damage casues an
		EffectApplied/EffectRemoved message, but not EffectUpdated (instead AreaUpdated)
		The rationale behind this is performance, since we cannot update every unit afflicted
		by the area effect on every hit. Therefore, we have the shared entry in the activeEffects
		table of each unit, and will handle it the same way when exporting - separately from each
		others.
	--]]

	-- The effect-individual messages get sent on visible and non-visible effects
	function LibAbsorbHandler:EffectApplied(event, srcGUID, srcName, dstGUID, dstName, spellid, value, quality, duration)
		ADDON.HealPredictionUpdateGUIDs(dstGUID)
	end

	-- Duration only if refreshed
	function LibAbsorbHandler:EffectUpdated(event, guid, spellid, value, duration)
		ADDON.HealPredictionUpdateGUIDs(guid)
	end

	function LibAbsorbHandler:EffectRemoved(event, guid, spellid)
		ADDON.HealPredictionUpdateGUIDs(guid)
	end

	function LibAbsorbHandler:AreaCreated(event, srcGUID, srcName, triggerGUID, spellid, value, quality)
		ADDON.HealPredictionUpdateAll()
	end

	function LibAbsorbHandler:AreaUpdated(event, triggerGUID, value)
		ADDON.HealPredictionUpdateAll()
	end

	function LibAbsorbHandler:AreaCleared(event, triggerGUID)
		ADDON.HealPredictionUpdateAll()
	end

	-- Only for VISIBLE changes on the total amount
	function LibAbsorbHandler:UnitUpdated(event, guid, value, quality)
		ADDON.HealPredictionUpdateGUIDs(guid)
	end

	-- Everytime a unit gets cleared from all absorb effects (quality reset), including non-visible effects
	function LibAbsorbHandler:UnitCleared(event, guid)
		ADDON.HealPredictionUpdateGUIDs(guid)
	end

	function LibAbsorbHandler:UnitAbsorbed(event, guid, absorbedTotal)
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

function ADDON:ToggleLibAbsorb(state)
	if state and not self.libAbsorbEnabled then
		self.libAbsorbEnabled = true
		LibAbsorb.RegisterCallback(LibAbsorbHandler, "EffectApplied", "EffectApplied")
		LibAbsorb.RegisterCallback(LibAbsorbHandler, "EffectUpdated", "EffectUpdated")
		LibAbsorb.RegisterCallback(LibAbsorbHandler, "EffectRemoved", "EffectRemoved")
		LibAbsorb.RegisterCallback(LibAbsorbHandler, "AreaCreated", "AreaCreated")
	--	LibAbsorb.RegisterCallback(LibAbsorbHandler, "AreaUpdated", "AreaUpdated")
		LibAbsorb.RegisterCallback(LibAbsorbHandler, "AreaCleared", "AreaCleared")
		LibAbsorb.RegisterCallback(LibAbsorbHandler, "UnitUpdated", "UnitUpdated")
		LibAbsorb.RegisterCallback(LibAbsorbHandler, "UnitCleared", "UnitCleared")
		LibAbsorb.RegisterCallback(LibAbsorbHandler, "UnitAbsorbed", "UnitAbsorbed")
	elseif not state and self.libAbsorbEnabled then
		self.libAbsorbEnabled = nil
		LibAbsorb.UnregisterCallback(LibAbsorbHandler, "EffectApplied")
		LibAbsorb.UnregisterCallback(LibAbsorbHandler, "EffectUpdated")
		LibAbsorb.UnregisterCallback(LibAbsorbHandler, "EffectRemoved")
		LibAbsorb.UnregisterCallback(LibAbsorbHandler, "AreaCreated")
	--	LibAbsorb.UnregisterCallback(LibAbsorbHandler, "AreaUpdated")
		LibAbsorb.UnregisterCallback(LibAbsorbHandler, "AreaCleared")
		LibAbsorb.UnregisterCallback(LibAbsorbHandler, "UnitUpdated")
		LibAbsorb.UnregisterCallback(LibAbsorbHandler, "UnitCleared")
		LibAbsorb.UnregisterCallback(LibAbsorbHandler, "UnitAbsorbed")
	end
end

function ADDON:InitializeBars()
	if self.initializedBars then return end

	self.CreateAllExistingBars(CompactRaidFrameContainer)

	hooksecurefunc("CompactRaidFrameContainer_GetUnitFrame", ERF_CompactRaidFrameContainer_GetUnitFrame)
	hooksecurefunc("CompactRaidFrameReservation_GetFrame", ERF_CompactRaidFrameReservation_GetFrame)

	hooksecurefunc("DefaultCompactUnitFrameSetup", ADDON.DefaultCompactUnitFrameSetup)
	hooksecurefunc("DefaultCompactMiniFrameSetup", ADDON.DefaultCompactUnitFrameSetup)

	hooksecurefunc("CompactUnitFrame_UpdateMaxHealth", ADDON.CompactUnitFrame_UpdateHealPrediction)

	self:ToggleHealComm(ADDON.db.profile.healPrediction.heal)
	self:ToggleLibAbsorb(ADDON.db.profile.healPrediction.absorbs)

	self.initializedBars = true
end