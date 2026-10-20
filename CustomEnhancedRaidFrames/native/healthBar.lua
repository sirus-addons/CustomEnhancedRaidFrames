local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local unpack = unpack

local UnitIsConnected = UnitIsConnected
local UnitIsDead = UnitIsDead

-- GLOBALS: CompactUnitFrame_IsTapDenied

function ADDON.CompactUnitFrame_UpdateHealthColor(frame, groupType)
	ADDON.HealthBar_Update(frame, groupType)
end

function ADDON.HealthBar_Setup(frame, groupType)
	local db = ADDON.db.profile[groupType].frames
	if db.colorEnabled then
		frame.healthBar.background:SetTexture(unpack(db.backgroundColor, 1, 3))
	end

	ADDON.CompactUnitFrame_UpdateHealthColor(frame, groupType)
end

function ADDON.HealthBar_Update(frame, groupType)
	if ADDON.useClassColors then return end

	local db = ADDON.db.profile[groupType].frames
	if not db.colorEnabled then return end

	local r, g, b

	if frame.unit and (not UnitIsConnected(frame.unit) or UnitIsDead(frame.unit)) then
		r, g, b = 0.5, 0.5, 0.5
	elseif CompactUnitFrame_IsTapDenied(frame) then
		r, g, b = 0.9, 0.9, 0.9
	else
		r, g, b = db.color[1], db.color[2], db.color[3]
	end

	frame.healthBar:SetStatusBarColor(r, g, b)
end

function ADDON.HealthBar_Revert()
	for frame in ADDON.IterateCompactFrames() do
		frame.background:SetTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Bg")
		frame.background:SetTexCoord(0, 1, 0, 0.53125)

		frame.healthBar.background:SetTexture(nil)

		frame.background:SetAlpha(1)
		frame.healthBar:SetAlpha(1)
		frame.healthBar.background:SetAlpha(1)

		if frame.healthBar.r then
			frame.healthBar:SetStatusBarColor(frame.healthBar.r, frame.healthBar.g, frame.healthBar.b)
		end
	end
end
