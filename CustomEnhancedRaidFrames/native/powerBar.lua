local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local strfind = string.find

local UnitExists = UnitExists

function ADDON.PowerBar_Setup(frame, groupType, refresh)
	if not frame.unit or not frame.powerBar then return end
	if not UnitExists(frame.displayedUnit) then return end
	if strfind(frame.unit, "pet", 1, true) then return end

	local db = ADDON.db.profile[groupType].frames

	if not db.showResourceOnlyForHealers or not ADDON.displayPowerBar then
		return
	end

	local role = ADDON.GetUnitRole(frame.unit)

	if role == "HEALER" then
		frame.powerBar:Show()
		frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, db.powerBarHeight + 1)

		if ADDON.displayBorder then
			frame.horizDivider:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 1 + db.powerBarHeight)
			frame.horizDivider:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 1 + db.powerBarHeight)
			frame.horizDivider:Show()
		else
			frame.horizDivider:Hide()
		end
	else
		frame.powerBar:Hide()
		frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

		if ADDON.displayBorder then
			frame.horizDivider:Hide()
		end
	end

	if not refresh then
		ADDON:SetUpMainSubFramePosition(frame, "buffFrames", groupType)

		if ADDON.db.profile[groupType].debuffFrames.smartAnchoring and ADDON.db.profile[groupType].debuffFrames.showBigDebuffs then
			ADDON:SmartAnchoring(frame, groupType)
		else
			ADDON:SetUpMainSubFramePosition(frame, "debuffFrames", groupType)
		end

		ADDON:SetUpMainSubFramePosition(frame, "dispelDebuffFrames", groupType)
	end
end

function ADDON.PowerBar_Update(frame, groupType)
	ADDON.PowerBar_Setup(frame, groupType)
end

function ADDON.PowerBar_Revert()
	local groupType = ADDON.GetGroupType()

	if not ADDON.db.profile[groupType].frames.showResourceOnlyForHealers or not ADDON.displayPowerBar then
		for frame in ADDON.IterateCompactFrames() do
			ADDON.PowerBar_RevertInternal(frame)
		end
	else
		for frame in ADDON.IterateCompactFrames() do
			if frame.unit and UnitExists(frame.displayedUnit) then
				ADDON.PowerBar_Setup(frame, groupType, true)
			end
		end
	end

	for frame in ADDON.IterateCompactFrames() do
		ADDON:SetUpMainSubFramePosition(frame, "buffFrames", groupType)

		if ADDON.db.profile[groupType].debuffFrames.smartAnchoring and ADDON.db.profile[groupType].debuffFrames.showBigDebuffs then
			ADDON:SmartAnchoring(frame, groupType)
		else
			ADDON:SetUpMainSubFramePosition(frame, "debuffFrames", groupType)
		end

		ADDON:SetUpMainSubFramePosition(frame, "dispelDebuffFrames", groupType)
	end
end

function ADDON.PowerBar_RevertInternal(frame)
	if frame.unit and strfind(frame.unit, "pet") then return end

	local powerBarHeight = ADDON.GetGroupTypeDB().frames.powerBarHeight

	if ADDON.displayPowerBar and frame.unit and UnitExists(frame.displayedUnit) then
		frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1 + powerBarHeight)
		frame.powerBar:Show()

		if ADDON.displayBorder then
			frame.horizDivider:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 1 + powerBarHeight)
			frame.horizDivider:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 1 + powerBarHeight)
			frame.horizDivider:Show()
		else
			frame.horizDivider:Hide()
		end
	else
		frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
		frame.powerBar:Hide()

		if ADDON.displayBorder then
			frame.horizDivider:Hide()
		end
	end
end