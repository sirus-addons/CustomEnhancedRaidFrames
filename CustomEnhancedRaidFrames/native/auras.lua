local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local pairs = pairs
local select = select
local tostring = tostring
local max, min = math.max, math.min
local tinsert, twipe = table.insert, table.wipe

local PlayerCanApplyAura = PlayerCanApplyAura
local SpellGetVisibilityInfo = SpellGetVisibilityInfo
local SpellIsSelfBuff = SpellIsSelfBuff
local UnitAffectingCombat = UnitAffectingCombat
local UnitExists = UnitExists

local AuraUtil = AuraUtil
local CompactUnitFrame_Util_IsBossAura = CompactUnitFrame_Util_IsBossAura
local CompactUnitFrame_Util_SpellIsBlacklisted = CompactUnitFrame_Util_SpellIsBlacklisted

-- GLOBALS: CompactUnitFrame_HideAllDispelDebuffs, CompactUnitFrame_UtilSetDispelDebuff, CompactUnitFrame_Util_IsPriorityDebuff, CooldownFrame_SetTimer, DebuffTypeColor
-- GLOBALS: BOSS_DEBUFF_SIZE_INCREASE, BUFF_STACKS_OVERFLOW

--Utility Functions
function ADDON.CompactUnitFrame_UtilShouldDisplayBuff(unit, ...)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, shouldConsolidate, spellId = ...;

	if not ADDON:FilterAuras(name, debuffType, spellId, "buffFrames") then
		return false
	end

	if ADDON:AdditionalAura(name, debuffType, spellId, unitCaster) then
		return true
	end

	if CompactUnitFrame_Util_SpellIsBlacklisted(spellId) then
		return false
	end

	local hasCustom, alwaysShowMine, showForMySpec = SpellGetVisibilityInfo(spellId, UnitAffectingCombat("player") and "RAID_INCOMBAT" or "RAID_OUTOFCOMBAT");

	if ( hasCustom ) then
		return showForMySpec or (alwaysShowMine and (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle"));
	else
		return (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle") and not shouldConsolidate and PlayerCanApplyAura(spellId, unit, unitCaster, duration) and not SpellIsSelfBuff(spellId);
	end
end

function ADDON.CompactUnitFrame_HideAllBuffs(frame, startingIndex, db)
	if frame.buffFrames then
		for i=startingIndex or 1, #frame.buffFrames do
			frame.buffFrames[i]:Hide();
			ADDON.StopGlow(frame.buffFrames[i], db.buffFrames, "buffFrames", "auraGlow")
		end
	end
end

function ADDON.CompactUnitFrame_HideAllDebuffs(frame, startingIndex, db)
	if frame.debuffFrames then
		for i=startingIndex or 1, #frame.debuffFrames do
			frame.debuffFrames[i]:Hide();
			ADDON.StopGlow(frame.debuffFrames[i], db.debuffFrames, "debuffFrames", "auraGlow")
		end
	end
end

function ADDON.CompactUnitFrame_UtilSetBuff(buffFrame, index, ...)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, shouldConsolidate, spellId = ...;
	buffFrame.icon:SetTexture(icon);
	if ( count > 1 ) then
		local countText = count;
		if ( count >= 100 ) then
			countText = BUFF_STACKS_OVERFLOW;
		end
		buffFrame.count:Show();
		buffFrame.count:SetText(countText);
	else
		buffFrame.count:Hide();
	end
	buffFrame:SetID(index);
	local enabled = expirationTime and expirationTime ~= 0;
	if enabled then
		local startTime = expirationTime - duration;
		CooldownFrame_SetTimer(buffFrame.cooldown, startTime, duration, 1);
	else
		buffFrame.cooldown:Hide();
	end
	buffFrame:Show();

	buffFrame.buffFramesGlowing = nil
	name = name and name:lower()
	debuffType = debuffType and debuffType:lower() or "physical"
	spellId = tostring(spellId)

	local db = ADDON.db.profile.glows

	if db.auraGlow.buffFrames.enabled then
		if ADDON:TrackAuras(name, debuffType, spellId, db.auraGlow.buffFrames.tracking) then
			local color = db.auraGlow.buffFrames.useDefaultsColors and db.auraGlow.defaultColors[debuffType]
			ADDON.StartGlow(buffFrame, db.auraGlow.buffFrames, color, "buffFrames", "auraGlow")
			buffFrame.buffFramesGlowing = debuffType
		end
	end

	if not buffFrame.buffFramesGlowing then
		ADDON.StopGlow(buffFrame, db.auraGlow.buffFrames, "buffFrames", "auraGlow")
	end

	local parent = buffFrame:GetParent()

	parent.buffFramesGlowing[debuffType] = {name, debuffType, spellId}
	parent.buffFramesGlowing[name] = {name, debuffType, spellId}
	parent.buffFramesGlowing[spellId] = {name, debuffType, spellId}

	if ADDON.Masque and ADDON.db.profile.Masque then
		SetParentFrameLevel(buffFrame, 4)
	end
end

function ADDON.CompactUnitFrame_Util_ShouldDisplayDebuff(unit, ...)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, shouldConsolidate, spellId = ...;

	if not ADDON:FilterAuras(name, debuffType, spellId, "debuffFrames") then
		return false
	end

	if ADDON:AdditionalAura(name, debuffType, spellId, unitCaster) then
		return true
	end

	if CompactUnitFrame_Util_SpellIsBlacklisted(spellId)
	then
		return false
	end

	local hasCustom, alwaysShowMine, showForMySpec = SpellGetVisibilityInfo(spellId, UnitAffectingCombat("player") and "RAID_INCOMBAT" or "RAID_OUTOFCOMBAT");
	if ( hasCustom ) then
		return showForMySpec or (alwaysShowMine and (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle") );	--Would only be "mine" in the case of something like forbearance.
	else
		return true;
	end
end

--Other internal functions
do
	function ADDON.SetDebuffsHelper(debuffFrames, frameNum, maxDebuffs, filter, isBossAura, isBossBuff, auras)
		if auras then
			local groupTypeDB = ADDON.GetGroupTypeDB()
			for i = 1,#auras do
				local aura = auras[i];
				if frameNum > maxDebuffs then
					break;
				end
				local debuffFrame = debuffFrames[frameNum];
				local index, name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, shouldConsolidate, spellId = aura[1], aura[2], aura[3], aura[4], aura[5], aura[6], aura[7], aura[8], aura[9], aura[10], aura[11], aura[12];

				if ADDON:FilterAuras(name, debuffType, spellId, "debuffFrames") then
					ADDON.CompactUnitFrame_UtilSetDebuff(debuffFrame, index, "HARMFUL", isBossAura, isBossBuff, name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, shouldConsolidate, spellId);
					frameNum = frameNum + 1;

					if not groupTypeDB.debuffFrames.smartAnchoring then
						if isBossAura then
							--Boss auras are about twice as big as normal debuffs, so we may need to display fewer buffs
							local bossDebuffScale = (debuffFrame.baseSize + BOSS_DEBUFF_SIZE_INCREASE)/debuffFrame.baseSize;
							maxDebuffs = maxDebuffs - (bossDebuffScale - 1);
						end
					end
				end
			end
		end
		return frameNum, maxDebuffs;
	end

	local function NumElements(arr)
		return arr and #arr or 0;
	end

	local dispellableDebuffTypes = { Magic = true, Curse = true, Disease = true, Poison = true};

	-- This interleaves updating buffFrames, debuffFrames and dispelDebuffFrames to reduce the number of calls to UnitAuraSlots/UnitAuraBySlot
	function ADDON.CompactUnitFrame_UpdateAuras(frame)
		if not frame or not frame.displayedUnit or not UnitExists(frame.displayedUnit) then return end

		if not frame.buffFramesGlowing then
			frame.buffFramesGlowing = {}
		else
			twipe(frame.buffFramesGlowing)
		end
		if not frame.debuffFramesGlowing then
			frame.debuffFramesGlowing = {}
		else
			twipe(frame.debuffFramesGlowing)
		end

		local db = ADDON.GetGroupTypeDB()

		local maxBuffs = min(db.buffFrames.num, #frame.buffFrames) or 3
		local maxDebuffs = min(db.debuffFrames.num, #frame.debuffFrames) or 3
		local maxDispelDebuffs = min(db.dispelDebuffFrames.num, #frame.dispelDebuffFrames) or 3

		local doneWithBuffs = not frame.buffFrames or not frame.optionTable.displayBuffs or maxBuffs == 0;
		local doneWithDebuffs = not frame.debuffFrames or not frame.optionTable.displayDebuffs or maxDebuffs == 0;
		local doneWithDispelDebuffs = not frame.dispelDebuffFrames or not frame.optionTable.displayDispelDebuffs or maxDispelDebuffs == 0;

		local numUsedBuffs = 0;
		local numUsedDebuffs = 0;
		local numUsedDispelDebuffs = 0;

		local displayOnlyDispellableDebuffs = frame.optionTable.displayOnlyDispellableDebuffs;

		-- The following is the priority order for debuffs
		local bossDebuffs, bossBuffs, priorityDebuffs, nonBossDebuffs, nonBossRaidDebuffs;
		local index = 1;
		local batchCount = maxDebuffs;

		if not doneWithDebuffs then
			AuraUtil.ForEachAura(frame.displayedUnit, "HARMFUL", batchCount, function(...)
				if db.debuffFrames.showBigDebuffs and CompactUnitFrame_Util_IsBossAura(...) then
					if not bossDebuffs then
						bossDebuffs = {};
					end
					tinsert(bossDebuffs, {index, ...});
					numUsedDebuffs = numUsedDebuffs + 1;
					if numUsedDebuffs == maxDebuffs then
						doneWithDebuffs = true;
						return true;
					end
				elseif db.frames.showBigDebuffs and CompactUnitFrame_Util_IsPriorityDebuff(...) then
					if not priorityDebuffs then
						priorityDebuffs = {};
					end
					tinsert(priorityDebuffs, {index, ...});
				elseif not displayOnlyDispellableDebuffs and ADDON.CompactUnitFrame_Util_ShouldDisplayDebuff(frame.displayedUnit, ...) then
					if not nonBossDebuffs then
						nonBossDebuffs = {};
					end
					tinsert(nonBossDebuffs, {index, ...});
				end

				index = index + 1;
				return false;
			end);
		end

		if not doneWithBuffs or not doneWithDebuffs then
			index = 1;
			batchCount = max(maxBuffs, maxDebuffs);
			AuraUtil.ForEachAura(frame.displayedUnit, "HELPFUL", batchCount, function(...)
				if db.debuffFrames.showBigDebuffs and CompactUnitFrame_Util_IsBossAura(...) then
					-- Boss Auras are considered Debuffs for our purposes.
					if not doneWithDebuffs then
						if not bossBuffs then
							bossBuffs = {};
						end
						tinsert(bossBuffs, {index, ...});
						numUsedDebuffs = numUsedDebuffs + 1;
						if numUsedDebuffs == maxDebuffs then
							doneWithDebuffs = true;
						end
					end
				elseif ADDON.CompactUnitFrame_UtilShouldDisplayBuff(frame.displayedUnit, ...) then
					if not doneWithBuffs then
						numUsedBuffs = numUsedBuffs + 1;
						local buffFrame = frame.buffFrames[numUsedBuffs];
						ADDON.CompactUnitFrame_UtilSetBuff(buffFrame, index, ...);
						if numUsedBuffs == maxBuffs then
							doneWithBuffs = true;
						end
					end
				end

				index = index + 1;
				return doneWithBuffs and doneWithDebuffs;
			end);
		end

		numUsedDebuffs = min(maxDebuffs, numUsedDebuffs + NumElements(priorityDebuffs));
		if numUsedDebuffs == maxDebuffs then
			doneWithDebuffs = true;
		end

		if not doneWithDispelDebuffs then
			--Clear what we currently have for dispellable debuffs
			for debuffType, display in pairs(dispellableDebuffTypes) do
				if ( display ) then
					frame["hasDispel"..debuffType] = false;
				end
			end
		end

		if not doneWithDispelDebuffs or not doneWithDebuffs then
			batchCount = max(maxDebuffs, maxDispelDebuffs);
			index = 1;
			AuraUtil.ForEachAura(frame.displayedUnit, "HARMFUL|RAID", batchCount, function(...)
				if not doneWithDebuffs and displayOnlyDispellableDebuffs then
					if ADDON.CompactUnitFrame_Util_ShouldDisplayDebuff(frame.displayedUnit, ...) and not CompactUnitFrame_Util_IsBossAura(...) and not CompactUnitFrame_Util_IsPriorityDebuff(...) then
						if not nonBossRaidDebuffs then
							nonBossRaidDebuffs = {};
						end
						tinsert(nonBossRaidDebuffs, {index, ...});
						numUsedDebuffs = numUsedDebuffs + 1;
						if numUsedDebuffs == maxDebuffs then
							doneWithDebuffs = true;
						end
					end
				end
				if not doneWithDispelDebuffs then
					local debuffType = select(5, ...);
					if ( dispellableDebuffTypes[debuffType] and not frame["hasDispel"..debuffType] ) then
						frame["hasDispel"..debuffType] = true;
						numUsedDispelDebuffs = numUsedDispelDebuffs + 1;
						local dispellDebuffFrame = frame.dispelDebuffFrames[numUsedDispelDebuffs];
						CompactUnitFrame_UtilSetDispelDebuff(dispellDebuffFrame, debuffType, index)
						if numUsedDispelDebuffs == maxDispelDebuffs then
							doneWithDispelDebuffs = true;
						end
					end
				end
				index = index + 1;
				return (doneWithDebuffs or not displayOnlyDispellableDebuffs) and doneWithDispelDebuffs;
			end);
		end

		local frameNum = 1;
		local maxDebuffs = maxDebuffs;

		do
			local isBossAura = true;
			local isBossBuff = false;
			frameNum, maxDebuffs = ADDON.SetDebuffsHelper(frame.debuffFrames, frameNum, maxDebuffs, "HARMFUL", isBossAura, isBossBuff, bossDebuffs);
		end
		do
			local isBossAura = true;
			local isBossBuff = true;
			frameNum, maxDebuffs = ADDON.SetDebuffsHelper(frame.debuffFrames, frameNum, maxDebuffs, "HELPFUL", isBossAura, isBossBuff, bossBuffs);
		end
		do
			local isBossAura = false;
			local isBossBuff = false;
			frameNum, maxDebuffs = ADDON.SetDebuffsHelper(frame.debuffFrames, frameNum, maxDebuffs, "HARMFUL", isBossAura, isBossBuff, priorityDebuffs);
		end
		do
			local isBossAura = false;
			local isBossBuff = false;
			frameNum, maxDebuffs = ADDON.SetDebuffsHelper(frame.debuffFrames, frameNum, maxDebuffs, "HARMFUL|RAID", isBossAura, isBossBuff, nonBossRaidDebuffs);
		end
		do
			local isBossAura = false;
			local isBossBuff = false;
			frameNum, maxDebuffs = ADDON.SetDebuffsHelper(frame.debuffFrames, frameNum, maxDebuffs, "HARMFUL", isBossAura, isBossBuff, nonBossDebuffs);
		end
		numUsedDebuffs = frameNum - 1;

		ADDON.CompactUnitFrame_HideAllBuffs(frame, numUsedBuffs + 1, ADDON.db.profile.glows.auraGlow);
		ADDON.CompactUnitFrame_HideAllDebuffs(frame, numUsedDebuffs + 1, ADDON.db.profile.glows.auraGlow);
		CompactUnitFrame_HideAllDispelDebuffs(frame, numUsedDispelDebuffs + 1);

		if db.debuffFrames.showBigDebuffs then
			if db.debuffFrames.smartAnchoring then
				ADDON:SmartAnchoring(frame, ADDON.GetGroupType())
			end

			if ADDON.db.profile.Masque then
				for _, auraFrame in pairs(frame.debuffFrames) do
					if auraFrame:IsShown() then
						ADDON.Masque.debuffFrames:ReSkin(auraFrame)
					end
				end
			end
		end

		local dbGlow = ADDON.db.profile.glows.frameGlow

		if dbGlow.buffFrames.enabled then
			for aura, auras in pairs(frame.buffFramesGlowing) do
				local name, debuffType, spellId = auras[1], auras[2], auras[3]

				if ADDON:TrackAuras(name, debuffType, spellId, dbGlow.buffFrames.tracking) then
					local color = dbGlow.buffFrames.useDefaultsColors and dbGlow.defaultColors[debuffType]
					ADDON.StartGlow(frame, dbGlow.buffFrames, color, "buffFrames", "frameGlow")
					ADDON.StopGlow(frame, dbGlow.debuffFrames, "debuffFrames", "frameGlow")
					return
				end
			end
		end

		if dbGlow.debuffFrames.enabled then
			for aura, auras in pairs(frame.debuffFramesGlowing) do
				local name, debuffType, spellId = auras[1], auras[2], auras[3]

				if ADDON:TrackAuras(name, debuffType, spellId, dbGlow.debuffFrames.tracking) then
					local color = dbGlow.debuffFrames.useDefaultsColors and dbGlow.defaultColors[debuffType]
					ADDON.StartGlow(frame, dbGlow.debuffFrames, color, "debuffFrames", "frameGlow")
					ADDON.StopGlow(frame, dbGlow.buffFrames, "buffFrames", "frameGlow")
					return
				end
			end
		end

		ADDON.StopGlow(frame, dbGlow.debuffFrames, "debuffFrames", "frameGlow")
		ADDON.StopGlow(frame, dbGlow.buffFrames, "buffFrames", "frameGlow")
	end
end

function ADDON.CompactUnitFrame_UtilSetDebuff(debuffFrame, index, filter, isBossAura, isBossBuff, ...)
	debuffFrame.debuffFramesGlowing = nil

	-- make sure you are using the correct index here!
	--isBossAura says make this look large.
	--isBossBuff looks in HELPFULL auras otherwise it looks in HARMFULL ones
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, shouldConsolidate, spellId = ...;
	debuffFrame.filter = filter;
	debuffFrame.icon:SetTexture(icon);
	if ( count > 1 ) then
		local countText = count;
		if ( count >= 100 ) then
			countText = BUFF_STACKS_OVERFLOW;
		end
		debuffFrame.count:Show();
		debuffFrame.count:SetText(countText);
	else
		debuffFrame.count:Hide();
	end
	debuffFrame:SetID(index);
	local enabled = expirationTime and expirationTime ~= 0;
	if enabled then
		local startTime = expirationTime - duration;
		CooldownFrame_SetTimer(debuffFrame.cooldown, startTime, duration, 1);
	else
		debuffFrame.cooldown:Hide();
	end

	local color = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
	debuffFrame.border:SetVertexColor(color.r, color.g, color.b);

	debuffFrame.isBossBuff = isBossBuff;
	debuffFrame.isBossAura = isBossAura;

	local size = ADDON.GetGroupTypeDB().debuffFrames

	if ( isBossAura ) then
		size = size.bigDebuffSize
	else
		size = size.size
	end

	size = size * ADDON.ComponentScale(ADDON.GetGroupType())
	debuffFrame:SetSize(size, size)
	debuffFrame:Show();

	name = name and name:lower()
	debuffType = debuffType and debuffType:lower() or "physical"
	spellId = tostring(spellId)

	local db = ADDON.db.profile.glows

	if db.auraGlow.debuffFrames.enabled then
		if ADDON:TrackAuras(name, debuffType, spellId, db.auraGlow.debuffFrames.tracking) then
			color = db.auraGlow.debuffFrames.useDefaultsColors and db.auraGlow.defaultColors[debuffType]
			ADDON.StartGlow(debuffFrame, db.auraGlow.debuffFrames, color, "debuffFrames", "auraGlow")
			debuffFrame.debuffFramesGlowing = debuffType
		end
	end

	if not debuffFrame.debuffFramesGlowing then
		ADDON.StopGlow(debuffFrame, db.auraGlow.debuffFrames, "debuffFrames", "auraGlow")
	end

	local parent = debuffFrame:GetParent()
	parent.debuffFramesGlowing[debuffType] = {name, debuffType, spellId}
	parent.debuffFramesGlowing[name] = {name, debuffType, spellId}
	parent.debuffFramesGlowing[spellId] = {name, debuffType, spellId}

	if ADDON.Masque and ADDON.db.profile.Masque then
		debuffFrame.border:Hide()
		SetParentFrameLevel(debuffFrame, 4)
	end
end