local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local unpack = unpack

local GetReadyCheckStatus = GetReadyCheckStatus
local GetReadyCheckTimeLeft = GetReadyCheckTimeLeft
local UnitExists = UnitExists

-- GLOBALS: CompactUnitFrame_UpdateReadyCheck

function ADDON.CompactUnitFrame_UpdateReadyCheck(frame, groupType)
	if ( not frame.unit or not frame.readyCheckIcon or frame.readyCheckDecay and GetReadyCheckTimeLeft() <= 0 ) then
		return;
	end

	ADDON.ReadyCheckIcon_Update(frame, groupType)
end

function ADDON.ReadyCheckIcon_Setup(frame, groupType)
	if not frame.readyCheckIcon then return end

	local db = ADDON.db.profile[groupType].nameAndIcons.readyCheckIcon
	if not db.enabled then return end

	local readyCheckIcon = frame.readyCheckIcon
	local size = db.size * ADDON.ComponentScale(groupType)

	local xOffset, yOffset = ADDON:Offsets("BOTTOM", frame, groupType)
	xOffset = xOffset + db.xOffset
	yOffset = yOffset + db.yOffset + ((select(2, ADDON.GetUnitFrameSize(groupType)) / 3) - 4)

	readyCheckIcon:ClearAllPoints()
	readyCheckIcon:SetPoint("BOTTOM", frame, "BOTTOM", xOffset, yOffset)
	readyCheckIcon:SetSize(size, size)

	ADDON.ReadyCheckIcon_Update(frame, groupType)
end

function ADDON.ReadyCheckIcon_Update(frame, groupType)
	if not frame.unit or not frame.readyCheckIcon then return end
	if not UnitExists(frame.displayedUnit) then return end

	local db = ADDON.db.profile[groupType].nameAndIcons.readyCheckIcon
	if not db.enabled then
		return
	elseif db.hide then
		frame.readyCheckIcon:Hide()
		return
	end

	local readyCheckStatus = GetReadyCheckStatus(frame.unit)
	if readyCheckStatus == "ready" or readyCheckStatus == "notready" or readyCheckStatus == "waiting" then
		if db.useCustomTextures and db[readyCheckStatus] ~= "" then
			frame.readyCheckIcon:SetTexture(db[readyCheckStatus])
			frame.readyCheckIcon:SetVertexColor(unpack(db.colors[readyCheckStatus]))
		else
			frame.readyCheckIcon:SetVertexColor(1, 1, 1, 1)
		end
		frame.readyCheckIcon:Show()
	else
		frame.readyCheckIcon:Hide()
	end
end

function ADDON.ReadyCheckIcon_Finish(frame, groupType)
	if not frame.readyCheckIcon or frame.readyCheckStatus ~= "waiting" then return end

	local db = ADDON.db.profile[groupType].nameAndIcons.readyCheckIcon
	if db.hide then
		frame.readyCheckIcon:Hide()
	elseif db.useCustomTextures and db.notready ~= "" then
		frame.readyCheckIcon:SetTexture(db.notready)
		frame.readyCheckIcon:SetVertexColor(unpack(db.colors.notready))
	end
end

function ADDON.ReadyCheckIcon_Revert()
	for frame in ADDON.IterateCompactFrames() do
		if frame.unit then
			local size = 15 * ADDON.NativeComponentScale(ADDON.GetGroupType())
			frame.readyCheckIcon:ClearAllPoints();
			frame.readyCheckIcon:SetPoint("BOTTOM", frame, "BOTTOM", 0, frame:GetHeight() / 3 - 4)
			frame.readyCheckIcon:SetSize(size, size)

			frame.readyCheckIcon:SetVertexColor(1, 1, 1, 1)

			if UnitExists(frame.unit) then
				CompactUnitFrame_UpdateReadyCheck(frame, true)
			end
		end
	end
end