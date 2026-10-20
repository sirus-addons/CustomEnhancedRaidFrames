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

-- GLOBALS: CompactUnitFrame_UtilSetDispelDebuff, CompactUnitFrame_Util_IsPriorityDebuff, CooldownFrame_SetTimer, DebuffTypeColor
-- GLOBALS: BUFF_STACKS_OVERFLOW, GameTooltip

local IsBossAura = CompactUnitFrame_Util_IsBossAura
local SpellIsBlacklisted = CompactUnitFrame_Util_SpellIsBlacklisted

local function IsPriorityDebuff(...)
	return CompactUnitFrame_Util_IsPriorityDebuff(...)
end

local function PrepareAuras(frame)
end

local function SetAuraTooltip(auraFrame, filter)
end

local function ClearAuraTooltips(frame)
end

local function SetDispelDebuff(dispelDebuffFrame, debuffType, index)
	CompactUnitFrame_UtilSetDispelDebuff(dispelDebuffFrame, debuffType, index)
end

if not IsBossAura then
	local FACTION_OVERRIDE_BY_DEBUFFS = FACTION_OVERRIDE_BY_DEBUFFS
	local S_CATEGORY_SPELL_ID = S_CATEGORY_SPELL_ID
	local S_PREMIUM_SPELL_ID = S_PREMIUM_SPELL_ID
	local S_VIP_STATUS_DATA = S_VIP_STATUS_DATA
	local ZODIAC_DEBUFFS = ZODIAC_DEBUFFS

	local bossAuras = {}
	local dispelAura = {}

	local function CollectBossAura(_, aura)
		if aura.isBossAura then
			bossAuras[aura.spellId] = true
		end
	end

	local function UpdateTooltip(self)
		if self.erfFilter then
			GameTooltip:SetUnitAura(self:GetParent().displayedUnit, self:GetID(), self.erfFilter)
		else
			self:ERFUpdateTooltip()
		end
	end

	local function ClearFilters(auraFrames)
		if not auraFrames then
			return
		end
		for i = 1, #auraFrames do
			auraFrames[i].erfFilter = nil
		end
	end

	function IsBossAura(...)
		return bossAuras[select(11, ...)]
	end

	function SpellIsBlacklisted(spellId)
		return FACTION_OVERRIDE_BY_DEBUFFS[spellId]
			or ZODIAC_DEBUFFS[spellId]
			or S_CATEGORY_SPELL_ID[spellId]
			or S_VIP_STATUS_DATA[spellId]
			or S_PREMIUM_SPELL_ID[spellId]
	end

	function IsPriorityDebuff(...)
		return AuraUtil.IsPriorityDebuff((select(11, ...)))
	end

	function PrepareAuras(frame)
		twipe(bossAuras)
		if frame.debuffs then
			frame.debuffs:Iterate(CollectBossAura)
		end
	end

	function SetAuraTooltip(auraFrame, filter)
		if not auraFrame.ERFUpdateTooltip then
			auraFrame.ERFUpdateTooltip = auraFrame.UpdateTooltip
			auraFrame.UpdateTooltip = UpdateTooltip
		end
		auraFrame.erfFilter = filter
	end

	function ClearAuraTooltips(frame)
		ClearFilters(ADDON.GetAuraFrames(frame, "buffFrames"))
		ClearFilters(ADDON.GetAuraFrames(frame, "debuffFrames"))
		ClearFilters(ADDON.GetAuraFrames(frame, "dispelDebuffFrames"))
	end

	function SetDispelDebuff(dispelDebuffFrame, debuffType, index)
		dispelAura.dispelName = debuffType
		CompactUnitFrame_UtilSetDispelDebuff(dispelDebuffFrame, dispelAura)
		dispelDebuffFrame:SetID(index)
		SetAuraTooltip(dispelDebuffFrame, "HARMFUL|RAID")
	end
end

--Utility Functions
function ADDON.CompactUnitFrame_UtilShouldDisplayBuff(unit, ...)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, shouldConsolidate, spellId = ...;

	if not ADDON:FilterAuras(name, debuffType, spellId, "buffFrames") then
		return false
	end

	if ADDON:AdditionalAura(name, debuffType, spellId, unitCaster) then
		return true
	end

	if SpellIsBlacklisted(spellId) then
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
	local buffFrames = ADDON.GetAuraFrames(frame, "buffFrames")
	if buffFrames then
		for i=startingIndex or 1, #buffFrames do
			buffFrames[i]:Hide();
			ADDON.StopGlow(buffFrames[i], db.buffFrames, "buffFrames", "auraGlow")
		end
	end
end

function ADDON.CompactUnitFrame_HideAllDebuffs(frame, startingIndex, db)
	local debuffFrames = ADDON.GetAuraFrames(frame, "debuffFrames")
	if debuffFrames then
		for i=startingIndex or 1, #debuffFrames do
			debuffFrames[i]:Hide();
			ADDON.StopGlow(debuffFrames[i], db.debuffFrames, "debuffFrames", "auraGlow")
		end
	end
end

local function HideDispelDebuffs(dispelDebuffFrames, startingIndex)
	for i = startingIndex, #dispelDebuffFrames do
		dispelDebuffFrames[i]:Hide()
	end
end

local function HideExtraAuraFrames(frame)
	if not frame.ERFAuraFrames then return end

	for subFrameType, typedFrames in pairs(frame.ERFAuraFrames) do
		for i = #frame[subFrameType] + 1, #typedFrames do
			typedFrames[i]:Hide()
		end
	end
end

local function StopGlows(frame, key)
	local db = ADDON.db.profile.glows
	local auraFrames = frame.ERFAuraFrames and frame.ERFAuraFrames[key]
	if auraFrames then
		for i = 1, #auraFrames do
			ADDON.StopGlow(auraFrames[i], db.auraGlow[key], key, "auraGlow")
		end
	end
	ADDON.StopGlow(frame, db.frameGlow[key], key, "frameGlow")
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
	SetAuraTooltip(buffFrame, "HELPFUL");
	local enabled = expirationTime and expirationTime ~= 0;
	if enabled then
		local startTime = expirationTime - duration;
		CooldownFrame_SetTimer(buffFrame.cooldown, startTime, duration, 1);
	else
		buffFrame.cooldown:Hide();
	end
	buffFrame:Show();

	local db = ADDON.db.profile.glows
	local auraGlow, frameGlow = db.auraGlow.buffFrames, db.frameGlow.buffFrames

	if auraGlow.enabled or frameGlow.enabled then
		name = name and name:lower()
		debuffType = debuffType and debuffType:lower() or "physical"
		spellId = tostring(spellId)
	end

	if auraGlow.enabled and ADDON:TrackAuras(name, debuffType, spellId, auraGlow.tracking) then
		ADDON.StartGlow(buffFrame, auraGlow, auraGlow.useDefaultsColors and db.auraGlow.defaultColors[debuffType], "buffFrames", "auraGlow")
	else
		ADDON.StopGlow(buffFrame, auraGlow, "buffFrames", "auraGlow")
	end

	if frameGlow.enabled then
		buffFrame:GetParent().buffFramesGlowing[spellId] = {name, debuffType, spellId}
	end

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

	if SpellIsBlacklisted(spellId)
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
					ADDON.CompactUnitFrame_UtilSetDebuff(debuffFrame, index, filter, isBossAura, isBossBuff, name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, shouldConsolidate, spellId);
					frameNum = frameNum + 1;

					if not groupTypeDB.debuffFrames.smartAnchoring then
						if isBossAura then
							--Boss auras are about twice as big as normal debuffs, so we may need to display fewer buffs
							local bossDebuffScale = groupTypeDB.debuffFrames.bigDebuffSize / groupTypeDB.debuffFrames.size;
							maxDebuffs = maxDebuffs - (bossDebuffScale - 1);
						end
					end
				end
			end
		end
		return frameNum, maxDebuffs;
	end

	local dispellableDebuffTypes = { Magic = true, Curse = true, Disease = true, Poison = true};

	local curDB, curUnit, curIndex, curFrame, curBuffFrames, curDispelDebuffFrames
	local maxBuffs, maxDebuffs, maxDispelDebuffs
	local doneWithBuffs, doneWithDebuffs, doneWithDispelDebuffs
	local numUsedBuffs, numUsedDebuffs, numUsedDispelDebuffs
	local displayOnlyDispellableDebuffs
	-- The following is the priority order for debuffs
	local bossDebuffs, bossBuffs, priorityDebuffs, nonBossDebuffs, nonBossRaidDebuffs = {}, {}, {}, {}, {}

	local function CollectHarmful(...)
		if curDB.debuffFrames.showBigDebuffs and IsBossAura(...) then
			tinsert(bossDebuffs, {curIndex, ...});
			numUsedDebuffs = numUsedDebuffs + 1;
			if numUsedDebuffs == maxDebuffs then
				doneWithDebuffs = true;
				return true;
			end
		elseif IsPriorityDebuff(...) then
			tinsert(priorityDebuffs, {curIndex, ...});
		elseif not displayOnlyDispellableDebuffs and ADDON.CompactUnitFrame_Util_ShouldDisplayDebuff(curUnit, ...) then
			tinsert(nonBossDebuffs, {curIndex, ...});
		end

		curIndex = curIndex + 1;
		return false;
	end

	local function CollectHelpful(...)
		if curDB.debuffFrames.showBigDebuffs and IsBossAura(...) then
			-- Boss Auras are considered Debuffs for our purposes.
			if not doneWithDebuffs then
				tinsert(bossBuffs, {curIndex, ...});
				numUsedDebuffs = numUsedDebuffs + 1;
				if numUsedDebuffs == maxDebuffs then
					doneWithDebuffs = true;
				end
			end
		elseif ADDON.CompactUnitFrame_UtilShouldDisplayBuff(curUnit, ...) then
			if not doneWithBuffs then
				numUsedBuffs = numUsedBuffs + 1;
				ADDON.CompactUnitFrame_UtilSetBuff(curBuffFrames[numUsedBuffs], curIndex, ...);
				if numUsedBuffs == maxBuffs then
					doneWithBuffs = true;
				end
			end
		end

		curIndex = curIndex + 1;
		return doneWithBuffs and doneWithDebuffs;
	end

	local function CollectRaid(...)
		if not doneWithDebuffs and displayOnlyDispellableDebuffs then
			if ADDON.CompactUnitFrame_Util_ShouldDisplayDebuff(curUnit, ...) and not (curDB.debuffFrames.showBigDebuffs and IsBossAura(...)) and not IsPriorityDebuff(...) then
				tinsert(nonBossRaidDebuffs, {curIndex, ...});
				numUsedDebuffs = numUsedDebuffs + 1;
				if numUsedDebuffs == maxDebuffs then
					doneWithDebuffs = true;
				end
			end
		end
		if not doneWithDispelDebuffs then
			local debuffType = select(5, ...);
			if ( dispellableDebuffTypes[debuffType] and not curFrame["hasDispel"..debuffType] and ADDON:FilterAuras((...), debuffType, select(11, ...), "dispelDebuffFrames") ) then
				curFrame["hasDispel"..debuffType] = true;
				numUsedDispelDebuffs = numUsedDispelDebuffs + 1;
				SetDispelDebuff(curDispelDebuffFrames[numUsedDispelDebuffs], debuffType, curIndex)
				if numUsedDispelDebuffs == maxDispelDebuffs then
					doneWithDispelDebuffs = true;
				end
			end
		end
		curIndex = curIndex + 1;
		return (doneWithDebuffs or not displayOnlyDispellableDebuffs) and doneWithDispelDebuffs;
	end

	-- This interleaves updating buffFrames, debuffFrames and dispelDebuffFrames to reduce the number of calls to UnitAuraSlots/UnitAuraBySlot
	function ADDON.CompactUnitFrame_UpdateAuras(frame)
		if ADDON.SkipFrame(frame) or not frame.displayedUnit or not UnitExists(frame.displayedUnit) then return end

		if not frame.buffFrames or not frame.optionTable.displayBuffs
			or not frame.debuffFrames or not frame.optionTable.displayDebuffs
			or not frame.dispelDebuffFrames or not frame.optionTable.displayDispelDebuffs then
			ClearAuraTooltips(frame)
			HideExtraAuraFrames(frame)
			StopGlows(frame, "buffFrames")
			StopGlows(frame, "debuffFrames")
			return
		end

		PrepareAuras(frame)

		curFrame = frame
		curUnit = frame.displayedUnit
		curBuffFrames = ADDON.GetAuraFrames(frame, "buffFrames")
		curDispelDebuffFrames = ADDON.GetAuraFrames(frame, "dispelDebuffFrames")
		local debuffFrames = ADDON.GetAuraFrames(frame, "debuffFrames")

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
		curDB = db

		maxBuffs = min(db.buffFrames.num, #curBuffFrames)
		maxDebuffs = min(db.debuffFrames.num, #debuffFrames)
		maxDispelDebuffs = min(db.dispelDebuffFrames.num, #curDispelDebuffFrames)

		doneWithBuffs = maxBuffs == 0;
		doneWithDebuffs = maxDebuffs == 0;
		doneWithDispelDebuffs = maxDispelDebuffs == 0;

		numUsedBuffs = 0;
		numUsedDebuffs = 0;
		numUsedDispelDebuffs = 0;

		displayOnlyDispellableDebuffs = frame.optionTable.displayOnlyDispellableDebuffs;

		twipe(bossDebuffs)
		twipe(bossBuffs)
		twipe(priorityDebuffs)
		twipe(nonBossDebuffs)
		twipe(nonBossRaidDebuffs)

		if not doneWithDebuffs then
			curIndex = 1;
			AuraUtil.ForEachAura(curUnit, "HARMFUL", maxDebuffs, CollectHarmful);
		end

		if not doneWithBuffs or not doneWithDebuffs then
			curIndex = 1;
			AuraUtil.ForEachAura(curUnit, "HELPFUL", max(maxBuffs, maxDebuffs), CollectHelpful);
		end

		numUsedDebuffs = min(maxDebuffs, numUsedDebuffs + #priorityDebuffs);
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
			curIndex = 1;
			AuraUtil.ForEachAura(curUnit, "HARMFUL|RAID", max(maxDebuffs, maxDispelDebuffs), CollectRaid);
		end
		local frameNum = 1;
		local maxDebuffs = maxDebuffs;

		do
			local isBossAura = true;
			local isBossBuff = false;
			frameNum, maxDebuffs = ADDON.SetDebuffsHelper(debuffFrames, frameNum, maxDebuffs, "HARMFUL", isBossAura, isBossBuff, bossDebuffs);
		end
		do
			local isBossAura = true;
			local isBossBuff = true;
			frameNum, maxDebuffs = ADDON.SetDebuffsHelper(debuffFrames, frameNum, maxDebuffs, "HELPFUL", isBossAura, isBossBuff, bossBuffs);
		end
		do
			local isBossAura = false;
			local isBossBuff = false;
			frameNum, maxDebuffs = ADDON.SetDebuffsHelper(debuffFrames, frameNum, maxDebuffs, "HARMFUL", isBossAura, isBossBuff, priorityDebuffs);
		end
		do
			local isBossAura = false;
			local isBossBuff = false;
			frameNum, maxDebuffs = ADDON.SetDebuffsHelper(debuffFrames, frameNum, maxDebuffs, "HARMFUL|RAID", isBossAura, isBossBuff, nonBossRaidDebuffs);
		end
		do
			local isBossAura = false;
			local isBossBuff = false;
			frameNum, maxDebuffs = ADDON.SetDebuffsHelper(debuffFrames, frameNum, maxDebuffs, "HARMFUL", isBossAura, isBossBuff, nonBossDebuffs);
		end
		numUsedDebuffs = frameNum - 1;

		ADDON.CompactUnitFrame_HideAllBuffs(frame, numUsedBuffs + 1, ADDON.db.profile.glows.auraGlow);
		ADDON.CompactUnitFrame_HideAllDebuffs(frame, numUsedDebuffs + 1, ADDON.db.profile.glows.auraGlow);
		HideDispelDebuffs(curDispelDebuffFrames, numUsedDispelDebuffs + 1);

		if db.debuffFrames.showBigDebuffs then
			if db.debuffFrames.smartAnchoring then
				ADDON:SmartAnchoring(frame, ADDON.GetGroupType())
			end

			if ADDON.Masque and ADDON.db.profile.Masque then
				for i = 1, #debuffFrames do
					local auraFrame = debuffFrames[i]
					local size = auraFrame:GetWidth()
					if auraFrame:IsShown() and auraFrame.erfMasqueSize ~= size then
						auraFrame.erfMasqueSize = size
						ADDON.Masque.debuffFrames:RemoveButton(auraFrame, true)
						ADDON.Masque.debuffFrames:AddButton(auraFrame)
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
					ADDON.StopGlow(frame, dbGlow.debuffFrames, "debuffFrames", "frameGlow")
					ADDON.StartGlow(frame, dbGlow.buffFrames, color, "buffFrames", "frameGlow")
					return
				end
			end
		end

		if dbGlow.debuffFrames.enabled then
			for aura, auras in pairs(frame.debuffFramesGlowing) do
				local name, debuffType, spellId = auras[1], auras[2], auras[3]

				if ADDON:TrackAuras(name, debuffType, spellId, dbGlow.debuffFrames.tracking) then
					local color = dbGlow.debuffFrames.useDefaultsColors and dbGlow.defaultColors[debuffType]
					ADDON.StopGlow(frame, dbGlow.buffFrames, "buffFrames", "frameGlow")
					ADDON.StartGlow(frame, dbGlow.debuffFrames, color, "debuffFrames", "frameGlow")
					return
				end
			end
		end

		ADDON.StopGlow(frame, dbGlow.debuffFrames, "debuffFrames", "frameGlow")
		ADDON.StopGlow(frame, dbGlow.buffFrames, "buffFrames", "frameGlow")
	end
end

function ADDON.CompactUnitFrame_UtilSetDebuff(debuffFrame, index, filter, isBossAura, isBossBuff, ...)
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
	SetAuraTooltip(debuffFrame, filter);
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

	local db = ADDON.db.profile.glows
	local auraGlow, frameGlow = db.auraGlow.debuffFrames, db.frameGlow.debuffFrames

	if auraGlow.enabled or frameGlow.enabled then
		name = name and name:lower()
		debuffType = debuffType and debuffType:lower() or "physical"
		spellId = tostring(spellId)
	end

	if auraGlow.enabled and ADDON:TrackAuras(name, debuffType, spellId, auraGlow.tracking) then
		ADDON.StartGlow(debuffFrame, auraGlow, auraGlow.useDefaultsColors and db.auraGlow.defaultColors[debuffType], "debuffFrames", "auraGlow")
	else
		ADDON.StopGlow(debuffFrame, auraGlow, "debuffFrames", "auraGlow")
	end

	if frameGlow.enabled then
		debuffFrame:GetParent().debuffFramesGlowing[spellId] = {name, debuffType, spellId}
	end

	if ADDON.Masque and ADDON.db.profile.Masque then
		debuffFrame.border:Hide()
		SetParentFrameLevel(debuffFrame, 4)
	end
end