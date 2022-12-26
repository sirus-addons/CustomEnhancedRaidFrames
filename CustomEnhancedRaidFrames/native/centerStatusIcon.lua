local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local unpack = unpack

local C_IncomingSummon = C_IncomingSummon
local UnitExists = UnitExists
local UnitHasIncomingResurrection = UnitHasIncomingResurrection

local Enum = Enum

-- GLOBALS: CompactUnitFrame_UpdateCenterStatusIcon, DefaultCompactUnitFrameSetupOptions

function ADDON.CompactUnitFrame_UpdateCenterStatusIcon(frame, groupType)
	ADDON.CenterStatusIcon_Update(frame, groupType)
end

function ADDON.CenterStatusIcon_Setup(frame, groupType)
	if not frame.centerStatusIcon then return end

	local db = ADDON.db.profile[groupType].nameAndIcons.centerStatusIcon
	if not db.enabled then return end

	local centerStatusIcon = frame.centerStatusIcon
	local size = db.size * ADDON.ComponentScale(groupType)

	local xOffset, yOffset = ADDON:Offsets("BOTTOM", frame, groupType)
	xOffset = xOffset + db.xOffset
	yOffset = yOffset + db.yOffset + (((DefaultCompactUnitFrameSetupOptions["height"] or ADDON.NATIVE_UNIT_FRAME_HEIGHT) / 3) - 4)

	centerStatusIcon:ClearAllPoints()
	centerStatusIcon:SetPoint("BOTTOM", xOffset, yOffset)
	centerStatusIcon:SetSize(size, size)

	ADDON.CenterStatusIcon_Update(frame, groupType)
end

function ADDON.CenterStatusIcon_Update(frame, groupType)
	if not frame.unit or not frame.centerStatusIcon then return end
	if not UnitExists(frame.displayedUnit) then return end

	local db = ADDON.db.profile[groupType].nameAndIcons.centerStatusIcon
	if not db.enabled then
		return
	elseif db.hide then
		frame.centerStatusIcon:Hide()
		return
	end

	if frame.optionTable.displayIncomingResurrect and UnitHasIncomingResurrection(frame.unit) then
		if db.useCustomTextures and db.hasIncomingResurrection ~= "" then
			frame.centerStatusIcon.texture:SetTexture(db.hasIncomingResurrection)
			frame.centerStatusIcon.texture:SetTexCoord(0, 1, 0, 1)
			frame.centerStatusIcon.texture:SetVertexColor(unpack(db.colors.hasIncomingResurrection))
		else
			frame.centerStatusIcon.texture:SetVertexColor(1, 1, 1, 1)
		end
		frame.centerStatusIcon:Show()
	elseif frame.optionTable.displayIncomingSummon and C_IncomingSummon.HasIncomingSummon(frame.unit) then
		local status = C_IncomingSummon.IncomingSummonStatus(frame.unit)
		if status == Enum.SummonStatus.Pending then
			if db.useCustomTextures and db.hasIncomingSummonPending ~= "" then
				frame.centerStatusIcon.texture:SetTexture(db.hasIncomingSummonPending)
				frame.centerStatusIcon.texture:SetTexCoord(0, 1, 0, 1)
				frame.centerStatusIcon.texture:SetVertexColor(unpack(db.colors.hasIncomingSummonPending))
			else
				frame.centerStatusIcon.texture:SetVertexColor(1, 1, 1, 1)
			end
			frame.centerStatusIcon:Show()
		elseif status == Enum.SummonStatus.Accepted then
			if db.useCustomTextures and db.hasIncomingSummonAccepted ~= "" then
				frame.centerStatusIcon.texture:SetTexture(db.hasIncomingSummonAccepted)
				frame.centerStatusIcon.texture:SetTexCoord(0, 1, 0, 1)
				frame.centerStatusIcon.texture:SetVertexColor(unpack(db.colors.hasIncomingSummonAccepted))
			else
				frame.centerStatusIcon.texture:SetVertexColor(1, 1, 1, 1)
			end
			frame.centerStatusIcon:Show()
		elseif status == Enum.SummonStatus.Declined then
			if db.useCustomTextures and db.hasIncomingSummonDeclined ~= "" then
				frame.centerStatusIcon.texture:SetTexture(db.hasIncomingSummonDeclined)
				frame.centerStatusIcon.texture:SetTexCoord(0, 1, 0, 1)
				frame.centerStatusIcon.texture:SetVertexColor(unpack(db.colors.hasIncomingSummonDeclined))
			else
				frame.centerStatusIcon.texture:SetVertexColor(1, 1, 1, 1)
			end
			frame.centerStatusIcon:Show()
		end
	else
		frame.centerStatusIcon:Hide()
	end
end

function ADDON.CenterStatusIcon_Revert()
	local groupType = ADDON.GetGroupType()
	local size = 11 * ADDON.ComponentScale(groupType) * 2

	for frame in ADDON.IterateCompactFrames() do
		if frame.unit then
			frame.centerStatusIcon:ClearAllPoints()
			frame.centerStatusIcon:SetPoint("CENTER", frame, "BOTTOM", 0, frame:GetHeight() / 3 + 2)
			frame.centerStatusIcon:SetSize(size, size)

			frame.centerStatusIcon.texture:SetVertexColor(1, 1, 1, 1)

			if UnitExists(frame.unit) then
				CompactUnitFrame_UpdateCenterStatusIcon(frame)
			end
		end
	end
end