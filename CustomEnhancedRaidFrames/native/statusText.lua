local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local SharedMedia = LibStub("LibSharedMedia-3.0")

local unpack = unpack
local ceil, math_huge = math.ceil, math.huge
local strformat = string.format

local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost

local DEAD = DEAD
local PLAYER_OFFLINE = PLAYER_OFFLINE
local UNKNOWN = UNKNOWN

-- GLOBALS: CompactUnitFrame_IsTapDenied, DefaultCompactUnitFrameSetupOptions

function ADDON.CompactUnitFrame_UpdateStatusText(frame, groupType)
	if not frame.unit or not frame.statusText or not frame.statusTextERF then return end
	if not UnitExists(frame.displayedUnit) then return end
	if not ADDON.IsFrameOk(frame) then return end

	if not frame.optionTable.displayStatusText then
		frame.statusTextERF:Hide()
		return
	end

	local db = ADDON.db.profile[groupType].nameAndIcons.statusText
	if not db.enabled then
		frame.statusTextERF:Hide()
		frame.statusText:Show()
		return
	end

	local hide, text, isStatus, percents = ADDON.StatusText_GetStatusInfo(frame)

	if hide or (isStatus and db.hideStatusText) then
		frame.statusTextERF:Hide()
		return
	else
		frame.statusText:Hide()
		frame.statusTextERF:Show()
	end

	if text then
		if not isStatus and frame.optionTable.healthText ~= "none" then
			if db.abbreviateNumbers then
				text = ADDON.Abbreviate(text, db.precision)
			end

			if db.showPercents and frame.optionTable.healthText ~= "perc" then
				percents = percents or ceil(100 * (UnitHealth(frame.displayedUnit) / UnitHealthMax(frame.displayedUnit)))
				percents = (percents ~= math_huge and percents ~= -math_huge and percents) or 0

				if frame.optionTable.healthText == "losthealth" then
					percents = 100 - percents
				end

				text = strformat("%s - %i%%", text, percents)
			elseif frame.optionTable.healthText == "losthealth" then
				text = strformat("-%s", text)
			elseif frame.optionTable.healthText == "perc" then
				text = strformat("%s%%", percents)
			end
		end

		if db.useClassColor then
			local classColor = ADDON.ColorByClass(frame.unit)

			if classColor then
				frame.statusTextERF:SetTextColor(classColor.r, classColor.g, classColor.b)
			end
		else
			if CompactUnitFrame_IsTapDenied(frame) then
				frame.statusTextERF:SetVertexColor(0.5, 0.5, 0.5)
			else
				frame.statusTextERF:SetVertexColor(unpack(db.color))
			end
		end
	end

	frame.statusTextERF:SetText(text)
end

function ADDON.StatusText_Setup(frame, groupType)
	if not frame.statusText then return end
	if not frame.optionTable.displayStatusText then return end
	if not ADDON.db.profile[groupType].nameAndIcons.statusText.enabled then return end

	if not frame.statusTextERF then
		frame.statusTextERF = frame.statusTextERF or frame:CreateFontString("$parentStatusTextERF", "ARTWORK")
	end

	local db = ADDON.db.profile[groupType].nameAndIcons.statusText

	local xOffset, yOffset = ADDON:Offsets("BOTTOM", frame, groupType, true)
	xOffset = xOffset + db.xOffset
	yOffset = yOffset + db.yOffset + (((DefaultCompactUnitFrameSetupOptions.height or ADDON.NATIVE_UNIT_FRAME_HEIGHT) / 3) - 2)

	frame.statusTextERF:ClearAllPoints()
	frame.statusTextERF:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", xOffset, yOffset)
	frame.statusTextERF:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", xOffset, yOffset)

	local size = db.size * ADDON.ComponentScale(groupType)
	local flags = db.flag ~= "None" and db.flag or ""
	local font = SharedMedia:Fetch("font", db.font) or SharedMedia:Fetch("font", ADDON.font)

	frame.statusTextERF:SetFont(font, size, flags)
	frame.statusTextERF:SetShadowColor(0, 0, 0, 1)
	frame.statusTextERF:SetShadowOffset(1, -1)
	frame.statusTextERF:SetJustifyH(db.hJustify)

	ADDON.CompactUnitFrame_UpdateStatusText(frame, groupType)
end

function ADDON.StatusText_GetStatusInfo(frame)
	if not frame.statusText then
		return true
	end

	if not frame.displayedUnit then
		return true, UNKNOWN
	end

	local hide, text, isStatus, percents

	if not UnitIsConnected(frame.unit) then
		hide = false
		text = PLAYER_OFFLINE
		isStatus = true
	elseif UnitHealth(frame.displayedUnit) == 0 or (frame.displayedUnit and UnitIsDeadOrGhost(frame.displayedUnit)) then
		hide = false
		text = DEAD
		isStatus = true
	elseif frame.optionTable.healthText == "health" then
		hide = false
		text = UnitHealth(frame.displayedUnit)
	elseif frame.optionTable.healthText == "losthealth" then
		local healthLost = UnitHealthMax(frame.displayedUnit) - UnitHealth(frame.displayedUnit)
		if healthLost > 0 then
			hide = false
			text = healthLost
		else
			hide = true
		end
	elseif (frame.optionTable.healthText == "perc") and (UnitHealthMax(frame.displayedUnit) > 0) then
		percents = ceil(100 * (UnitHealth(frame.displayedUnit) / UnitHealthMax(frame.displayedUnit)))
		hide = false
		text = percents
	else
		hide = true
	end

	return hide, text, isStatus, percents
end

function ADDON.StatusText_Revert()
	for frame in ADDON.IterateCompactFrames() do
		if frame.statusTextERF then
			frame.statusTextERF:Hide()
		end
		frame.statusText:SetShown(not ADDON.StatusText_GetStatusInfo(frame))
	end
end