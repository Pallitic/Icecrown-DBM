local mod	= DBM:NewMod("Deathwhisper", "DBM-Icecrown", 1)
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 4411 $"):sub(12, -3))
mod:SetCreatureID(36855)
mod:SetUsedIcons(4, 5, 6, 7, 8)
mod:RegisterCombat("yell", L.YellPull)

mod:RegisterEvents(
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_APPLIED_DOSE",
	"SPELL_AURA_REMOVED",
	"SPELL_CAST_START",
	"SPELL_CAST_SUCCESS",
	"SPELL_INTERRUPT",
	"SPELL_SUMMON",
	"SWING_DAMAGE",
	"CHAT_MSG_MONSTER_YELL",
	"UNIT_TARGET"
)

local canPurge = select(2, UnitClass("player")) == "MAGE"
			or select(2, UnitClass("player")) == "SHAMAN"
			or select(2, UnitClass("player")) == "PRIEST"

local warnAddsSoon					= mod:NewAnnounce("WarnAddsSoon", 2)
local warnDominateMind				= mod:NewTargetAnnounce(71289, 3)
local warnDeathDecay				= mod:NewSpellAnnounce(72108, 2)
local warnSummonSpirit				= mod:NewSpellAnnounce(71426, 2)
local warnReanimating				= mod:NewAnnounce("WarnReanimating", 3)
local warnDarkTransformation		= mod:NewSpellAnnounce(70900, 4)
local warnDarkEmpowerment			= mod:NewSpellAnnounce(70901, 4)
local warnPhase2					= mod:NewPhaseAnnounce(2, 1)	
local warnFrostbolt					= mod:NewCastAnnounce(72007, 2)
local warnTouchInsignificance		= mod:NewAnnounce("WarnTouchInsignificance", 2, 71204, mod:IsTank() or mod:IsHealer())
local warnDarkMartyrdom				= mod:NewSpellAnnounce(72499, 4)

local specWarnCurseTorpor			= mod:NewSpecialWarningYou(71237)
local specWarnDeathDecay			= mod:NewSpecialWarningMove(72108)
local specWarnTouchInsignificance	= mod:NewSpecialWarningStack(71204, nil, 3)
local specWarnVampricMight			= mod:NewSpecialWarningDispel(70674, canPurge)
local specWarnDarkMartyrdom			= mod:NewSpecialWarningMove(72499, mod:IsMelee())
local specWarnFrostbolt				= mod:NewSpecialWarningInterupt(72007, false)
local specWarnVengefulShade			= mod:NewSpecialWarning("SpecWarnVengefulShade", not mod:IsTank())

local timerAdds						= mod:NewTimer(45, "TimerAdds", 61131)
local timerDominateMind				= mod:NewBuffActiveTimer(12, 71289)
local timerDominateMindCD			= mod:NewCDTimer(40, 71289)
local timerSummonSpiritCD			= mod:NewCDTimer(10, 71426)
local timerFrostboltCast			= mod:NewCastTimer(4, 72007)
local timerTouchInsignificance		= mod:NewTargetTimer(30, 71204, nil, mod:IsTank() or mod:IsHealer())
local berserkTimer					= mod:NewBerserkTimer(600)

local ttsAddsCD = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\icc\\lady\\addscd.mp3", "TTS Adds Countdown", mod:IsTank())
local ttsDominateMindCD = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\icc\\lady\\mccd.wav", "TTS Dominate Mind Countdown", true)
local ttsSpiritsSpawned = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\icc\\lady\\spirits.mp3", "TTS Spirit spawn", true)
local ttsMC = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\icc\\lk\\StopCleave.wav", "TTS Stop cleave", true)
local ttsOnYouRun = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\icc\\lady\\onYouRun.mp3", "TTS Spirit on you", false)
local ttsEquipped = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\icc\\lady\\equipped.mp3", "TTS auto equip callout", false)
local ttsUnequipped = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\icc\\lady\\unequipped.mp3", "TTS auto unequip callout", false)
local ttsInterupt = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\icc\\lady\\Interrupt.wav", "TTS interupt", mod:IsTank())

mod:AddBoolOption("EnableOldAutoWeaponUnequipOnMC", false)
mod:AddBoolOption("EnableAutoWeaponUnequipOnMC", false)
mod:AddBoolOption("SpiritTargetDebug", false)
mod:AddBoolOption("SetIconOnDominateMind", true)
mod:AddBoolOption("SetIconOnDeformedFanatic", true)
mod:AddBoolOption("SetIconOnEmpoweredAdherent", false)
mod:AddBoolOption("ShieldHealthFrame", true, "misc")
mod:RemoveOption("HealthFrame")

mod:AddBoolOption("RemoveGiftOfTheWildBeforeMC", false)
mod:AddBoolOption("RemoveGiftOfTheWildWhenMCOnYou", not mod:IsTank() or mod:IsHealer())

local lastDD	= 0
local dominateMindTargets	= {}
local dominateMindIcon 	= 6
local deformedFanatic
local empoweredAdherent


-- TODO: Try to use https://wowwiki.fandom.com/wiki/API_UnitDetailedThreatSituation to check for spirits (and exclude lady and adds)
-- alternative TODO: Just exclude tanks by mod:IsTank() or check if your targettarget is yourself
-- alternative TODO: Just enable it in phase 2 for mdps/healer/rdps
-- function checkSpiritTarget()
-- 	isTanking = UnitDetailedThreatSituation("player", "target")
-- 	if UnitThreatSituation("player")==3 and not isTanking then
-- 		specWarnVengefulShade:Show()
-- 		SendChatMessage("Spirit on me!", "SAY")
-- 		ttsOnYouRun:Play()
-- 	elseif time() - lastSpirit < 4 then
-- 		mod:Schedule(0.15, checkSpiritTarget)
-- 	end
-- end
local spiritDetectionFrame = CreateFrame("Frame")
local function spiritDetection(self, event, arg)
	if not spiritDetectionFrame.enabled then return end
	local isTanking = UnitDetailedThreatSituation("player", "target")
	if UnitThreatSituation("player") == 3 and not isTanking then
		arg = arg or "nil"
		print("DEBUG: event="..event.."; arg="..arg)
		-- specWarnVengefulShade:Show()
		-- SendChatMessage("Spirit on me!", "SAY")
		-- ttsOnYouRun:Play()
	end
end
spiritDetectionFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
spiritDetectionFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")

function mod:OnCombatStart(delay)
	self.vb.phase = 1
	spiritDetectionFrame.enabled = self.Options.SpiritTargetDebug
	spiritDetectionFrame:SetScript("OnEvent", spiritDetection)
	if self.Options.ShieldHealthFrame then
		DBM.BossHealth:Show(L.name)
		DBM.BossHealth:AddBoss(36855, L.name)
		self:ScheduleMethod(0.5, "CreateShildHPFrame")
	end		
	berserkTimer:Start(-delay)
	timerAdds:Start(5)
	ttsAddsCD:Play()
	warnAddsSoon:Schedule(2)			-- 3sec pre-warning on start
	self:ScheduleMethod(7, "addsTimer")
	if not mod:IsDifficulty("normal10") then
		timerDominateMindCD:Start(28)		-- Sometimes 1 fails at the start, then the next will be applied 70 secs after start ?? :S
		ttsDominateMindCD:Schedule(22)
		-- if mod:IsDifficulty("heroic25") and self.Options.EnableOldAutoWeaponUnequipOnMC then -- TODO
		if (mod:IsDifficulty("heroic25") or mod:IsDifficulty("heroic10")) and self.Options.EnableOldAutoWeaponUnequipOnMC then
			-- print("DEBUG:schedule unequip")
			self:ScheduleMethod(27, "unequip")
		end
	end
	if (mod:IsDifficulty("heroic25") or mod:IsDifficulty("heroic10")) and
		self.Options.RemoveGiftOfTheWildBeforeMC then
		mod:ScheduleMethod(24, "RemoveBuffs")
	end
	
	table.wipe(dominateMindTargets)
	dominateMindIcon = 6
	deformedFanatic = nil
	empoweredAdherent = nil
end

function mod:OnCombatEnd()
	spiritDetectionFrame:SetScript("OnEvent", nil)
	DBM.BossHealth:Clear()
	ttsDominateMindCD:Cancel()
	ttsAddsCD:Cancel()
	self:UnscheduleMethod("unequip")
end

do	-- add the additional Shield Bar
	local last = 100
	local function getShieldPercent()
		local guid = UnitGUID("focus")
		if mod:GetCIDFromGUID(guid) == 36855 then 
			last = math.floor(UnitMana("focus")/UnitManaMax("focus") * 100)
			return last
		end
		for i = 0, GetNumRaidMembers(), 1 do
			local unitId = ((i == 0) and "target") or "raid"..i.."target"
			local guid = UnitGUID(unitId)
			if mod:GetCIDFromGUID(guid) == 36855 then
				last = math.floor(UnitMana(unitId)/UnitManaMax(unitId) * 100)
				return last
			end
		end
		return last
	end
	function mod:CreateShildHPFrame()
		DBM.BossHealth:AddBoss(getShieldPercent, L.ShieldPercent)
	end
end

--[[function mod:addsTimer()  -- Original add spawn timers, working for normal mode
	timerAdds:Cancel()
	warnAddsSoon:Cancel()
	if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
		warnAddsSoon:Schedule(40)	-- 5 secs prewarning
		self:ScheduleMethod(45, "addsTimer")
		timerAdds:Start(45)
	else
		warnAddsSoon:Schedule(55)	-- 5 secs prewarning
		self:ScheduleMethod(60, "addsTimer")
		timerAdds:Start()
	end
end]]--

function mod:addsTimer()
	timerAdds:Cancel()
	ttsAddsCD:Cancel()
	warnAddsSoon:Cancel()
	if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
		warnAddsSoon:Schedule(40)	-- 5 secs prewarning
		self:ScheduleMethod(47, "addsTimer")
		timerAdds:Start(45)
		ttsAddsCD:Schedule(40)
	else
		warnAddsSoon:Schedule(55)	-- 5 secs prewarning
		self:ScheduleMethod(60, "addsTimer")
		ttsAddsCD:Schedule(55)
		timerAdds:Start()
	end
end

function mod:TrySetTarget()
	if DBM:GetRaidRank() >= 1 then
		for i = 1, GetNumRaidMembers() do
			if UnitGUID("raid"..i.."target") == deformedFanatic then
				deformedFanatic = nil
				SetRaidTarget("raid"..i.."target", 8)
			elseif UnitGUID("raid"..i.."target") == empoweredAdherent then
				empoweredAdherent = nil
				SetRaidTarget("raid"..i.."target", 7)
			end
			if not (deformedFanatic or empoweredAdherent) then
				break
			end
		end
	end
end

function mod:showDominateMindWarning()
	warnDominateMind:Show(table.concat(dominateMindTargets, "<, >"))
	timerDominateMind:Start()
	timerDominateMindCD:Start()
	if (mod:IsDifficulty("heroic25") or mod:IsDifficulty("heroic10")) and self.Options.EnableOldAutoWeaponUnequipOnMC then
		-- print("DEBUG:schedule unequip")
		self:UnscheduleMethod("unequip")
		self:ScheduleMethod(39, "unequip")
	end
	ttsDominateMindCD:Schedule(35)
	table.wipe(dominateMindTargets)
	dominateMindIcon = 6
end
	
function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(71289) then
		ttsMC:Play()
		dominateMindTargets[#dominateMindTargets + 1] = args.destName
		if self.Options.SetIconOnDominateMind then
			self:SetIcon(args.destName, dominateMindIcon, 12)
			dominateMindIcon = dominateMindIcon - 1
		end
		self:Unschedule(showDominateMindWarning)
		if mod:IsDifficulty("heroic10") or mod:IsDifficulty("normal25") or (mod:IsDifficulty("heroic25") and #dominateMindTargets >= 3) then
			if (mod:IsDifficulty("heroic25") or mod:IsDifficulty("heroic10")) and self.Options.EnableOldAutoWeaponUnequipOnMC then
				self:equip()
			end
			self:showDominateMindWarning()
		else
			self:ScheduleMethod(0.9, "showDominateMindWarning")
		end
		elseif args:IsSpellID(71001, 72108, 72109, 72110) then
			if args:IsPlayer() then
				specWarnDeathDecay:Show()
			end
			if (GetTime() - lastDD > 5) then
				warnDeathDecay:Show()
				lastDD = GetTime()
			end
		elseif args:IsSpellID(71237) and args:IsPlayer() then
			specWarnCurseTorpor:Show()
		elseif args:IsSpellID(70674) and not args:IsDestTypePlayer() and (UnitName("target") == L.Fanatic1 or UnitName("target") == L.Fanatic2 or UnitName("target") == L.Fanatic3) then
			specWarnVampricMight:Show(args.destName)
		elseif args:IsSpellID(71204) then
			warnTouchInsignificance:Show(args.spellName, args.destName, args.amount or 1)
			timerTouchInsignificance:Start(args.destName)
			if args:IsPlayer() and (args.amount or 1) >= 3 and (mod:IsDifficulty("normal10") or mod:IsDifficulty("normal25")) then
				specWarnTouchInsignificance:Show(args.amount)
			elseif args:IsPlayer() and (args.amount or 1) >= 5 and (mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25")) then
				specWarnTouchInsignificance:Show(args.amount)
			end
		end
end
mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:unequip()
	if self.Options.RemoveGiftOfTheWildWhenMCOnYou then
		CancelUnitBuff("player", "Gift of the Wild")
		CancelUnitBuff("player", "Mark of the Wild")
	end
	-- print("DEBUG: unequip() called")
	if mod:IsTank() or mod:IsHealer() then
		return
	end

	if GetInventoryItemID("player", 16) then
		PickupInventoryItem(16)
		PutItemInBackpack()
		PickupInventoryItem(17)
		PutItemInBackpack()
		PickupInventoryItem(18)
		PutItemInBackpack()
		ttsUnequipped:Play()
	end
end

function mod:equip()
	if not GetInventoryItemID("player", 16) and not UnitAura("player", "Dominate Mind") and HasFullControl() and not UnitIsDeadOrGhost("player") then
		if GetEquipmentSetInfoByName("dps") then
			UseEquipmentSet("dps")
			ttsEquipped:Play()
		end
	end
end

function mod:equip_fallback()
	if not GetInventoryItemID("player", 16) then
		self:equip()
		self:ScheduleMethod(0.1, "equip_fallback")
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(70842) then
		self.vb.phase = 2
		warnPhase2:Show()
		timerAdds:Cancel()
		ttsAddsCD:Cancel()
		warnAddsSoon:Cancel()
		self:UnscheduleMethod("addsTimer")
		if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
			self:ScheduleMethod(0.1, "addsTimer")
		end
	elseif args:IsSpellID(71289) and (self.Options.EnableOldAutoWeaponUnequipOnMC or self.Options.EnableAutoWeaponUnequipOnMC) and (mod:IsDifficulty("heroic25") or mod:IsDifficulty("heroic10")) then
		self:equip()
		-- attempt to reequip every 0.1 sec in case you are still CCd
		self:ScheduleMethod(0.1, "equip_fallback")
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if self.Options.EnableAutoWeaponUnequipOnMC and args:IsSpellID(71289) and args:IsPlayer() then
		self:unequip()
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(71420, 72007, 72501, 72502) then
		warnFrostbolt:Show()
		timerFrostboltCast:Start()
		ttsInterupt:Play()
	elseif args:IsSpellID(70900) then
		warnDarkTransformation:Show()
		if self.Options.SetIconOnDeformedFanatic then
			deformedFanatic = args.sourceGUID
			self:TrySetTarget()
		end
	elseif args:IsSpellID(70901) then
		warnDarkEmpowerment:Show()
		if self.Options.SetIconOnEmpoweredAdherent then
			empoweredAdherent = args.sourceGUID
			self:TrySetTarget()
		end
	elseif args:IsSpellID(72499, 72500, 72497, 72496) then
		warnDarkMartyrdom:Show()
		specWarnDarkMartyrdom:Show()
	end
end

function mod:SPELL_INTERRUPT(args)
	if type(args.extraSpellId) == "number" and (args.extraSpellId == 71420 or args.extraSpellId == 72007 or args.extraSpellId == 72501 or args.extraSpellId == 72502) then
		timerFrostboltCast:Cancel()
	end
end

local lastSpirit = 0
function mod:SPELL_SUMMON(args)
	if args:IsSpellID(71426) then -- Summon Vengeful Shade
		if time() - lastSpirit > 5 then
			warnSummonSpirit:Show()
			ttsSpiritsSpawned:Play()
			timerSummonSpiritCD:Start()
			lastSpirit = time()
			mod:Schedule(0.5, checkSpiritTarget)
		end
	end
end

function checkSpiritTarget()
	local isTanking = UnitDetailedThreatSituation("player", "target")
	if UnitThreatSituation("player")==3 and not isTanking then
		specWarnVengefulShade:Show()
		SendChatMessage("Spirit on me!", "SAY")
		ttsOnYouRun:Play()
		print("--- spirit detected ---")
	elseif time() - lastSpirit < 4 then
		mod:Schedule(0.15, checkSpiritTarget)
	end
end

function mod:SWING_DAMAGE(args)
	if args:IsPlayer() and args:GetSrcCreatureID() == 38222 then
		specWarnVengefulShade:Show()
	end
end

function mod:UNIT_TARGET()
	if empoweredAdherent or deformedFanatic then
		self:TrySetTarget()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.YellReanimatedFanatic or msg:find(L.YellReanimatedFanatic) then
		warnReanimating:Show()
	end
end

function mod:RemoveBuffs()
	CancelUnitBuff("player", (GetSpellInfo(26990)))		-- Mark of the Wild
	CancelUnitBuff("player", (GetSpellInfo(48470)))		-- Gift of the Wild
end
