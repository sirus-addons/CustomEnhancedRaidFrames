local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local unpack = unpack
local strfind = string.find

local UnitIsConnected = UnitIsConnected

-- GLOBALS: CompactUnitFrame_IsTapDenied

function ADDON.CompactUnitFrame_UpdateHealthColor(frame, groupType)
	ADDON.HealthBar_Update(frame, groupType)
end

function ADDON.HealthBar_Setup(frame, groupType)
	local db = ADDON.db.profile[groupType].frames
	if db.colorEnabled then
		frame.healthBar.background:SetTexture(unpack(db.backgroundColor, 1, 3))
	end

	if frame.powerBar and ADDON.displayPowerBar then
		if not db.showResourceOnlyForHealers and (frame.unit and not strfind(frame.unit, "pet", 1, true)) then
			frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, db.powerBarHeight + 1)

			if ADDON.displayBorder then
				frame.horizDivider:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 1 + db.powerBarHeight)
				frame.horizDivider:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 1 + db.powerBarHeight)
			end
		else
			local powerBarUsedHeight = ADDON.displayPowerBar and 8 or 0

			frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1 + (powerBarUsedHeight));

			if ADDON.displayBorder then
				frame.horizDivider:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 1 + powerBarUsedHeight)
				frame.horizDivider:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 1 + powerBarUsedHeight)
			end
		end
	end

	frame.background:SetAlpha(db.backgoundAlpha)
	frame.healthBar:SetAlpha(db.alpha)
	frame.healthBar.background:SetAlpha(db.backgoundAlpha)
	frame.powerBar:SetAlpha(db.alpha)

	ADDON.CompactUnitFrame_UpdateHealthColor(frame, groupType)
end

function ADDON.HealthBar_Update(frame, groupType)
	if not ADDON.useClassColors then
		local db = ADDON.db.profile[groupType].frames
		if not db.colorEnabled then return end

		local frameName = frame:GetName()
		local cache = ADDON.healthFrameColors[frameName]

		if not cache or frame.healthBar.r ~= cache.health[1] or frame.healthBar.g ~= cache.health[2] or frame.healthBar.b ~= cache.health[3] then
			local r, g, b

			if frame.unit and not UnitIsConnected(frame.unit) then
				r, g, b = 0.5, 0.5, 0.5
			elseif CompactUnitFrame_IsTapDenied(frame) then
				r, g, b = 0.9, 0.9, 0.9
			else
				r, g, b = db.color[1], db.color[2], db.color[3]
			end

			frame.healthBar:SetStatusBarColor(r, g, b)

			if not cache then
				cache = {}
				ADDON.healthFrameColors[frameName] = cache
			end

			cache[1] = frame.healthBar.r
			cache[2] = frame.healthBar.g
			cache[3] = frame.healthBar.b
		end
	end
end

function ADDON.HealthBar_Revert()
	local groupType = ADDON.GetGroupType()
	for frame in ADDON.IterateCompactFrames() do
		frame.background:SetTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Bg")
		frame.background:SetTexCoord(0, 1, 0, 0.53125)

	--	frame.healthBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill", "BORDER");
		frame.healthBar.background:SetTexture(nil)

		frame.background:SetAlpha(1)
		frame.healthBar:SetAlpha(1)
		frame.healthBar.background:SetAlpha(1)

		ADDON.CompactUnitFrame_UpdateHealthColor(frame, groupType)
	end
end