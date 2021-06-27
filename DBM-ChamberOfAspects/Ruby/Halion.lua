local mod	= DBM:NewMod("Halion", "DBM-ChamberOfAspects", 2)
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 4390 $"):sub(12, -3))
mod:SetCreatureID(39863)--40142 (twilight form)
mod:SetMinSyncRevision(4358)
mod:SetUsedIcons(7, 8)

mod:RegisterCombat("combat")
--mod:RegisterKill("yell", L.Kill)

mod:RegisterEvents(
	"SPELL_CAST_START",
	"SPELL_CAST_SUCCESS",
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_REMOVED",
	"SPELL_DAMAGE",
	"CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"UNIT_HEALTH"
)

local warnPhase2Soon				= mod:NewAnnounce("WarnPhase2Soon", 2)
local warnPhase3Soon				= mod:NewAnnounce("WarnPhase3Soon", 2)
local warnPhase2					= mod:NewPhaseAnnounce(2)
local warnPhase3					= mod:NewPhaseAnnounce(3)
local warningShadowConsumption		= mod:NewTargetAnnounce(74792, 4)
local warningFieryConsumption		= mod:NewTargetAnnounce(74562, 4)
local warningMeteor					= mod:NewSpellAnnounce(74648, 3)
local warningShadowBreath			= mod:NewSpellAnnounce(75954, 2, nil, mod:IsTank() or mod:IsHealer())
local warningFieryBreath			= mod:NewSpellAnnounce(74526, 2, nil, mod:IsTank() or mod:IsHealer())
local warningTwilightCutter			= mod:NewAnnounce("TwilightCutterCast", 4, 77844)

local specWarnShadowConsumption		= mod:NewSpecialWarningRun(74792)
local specWarnFieryConsumption		= mod:NewSpecialWarningRun(74562)
local specWarnMeteorStrike			= mod:NewSpecialWarningMove(75952)
local specWarnTwilightCutter		= mod:NewSpecialWarningSpell(77844)
local specWarnCorporealitySlow		= mod:NewSpecialWarningSpellCorporeality(74832, "40%%, slow DPS!")
local specWarnCorporealityStop		= mod:NewSpecialWarningSpellCorporeality(74833, "30%%, stop DPS!")

local ttsPing = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\rs\\ping.mp3", "TTS Ping when consumption on you", true)
local ttsCutterIn5 = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\rs\\cuttercd.mp3", "TTS Cutter countdown", true)
local ttsMeteor = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\rs\\meteor.mp3", "TTS Meteor cast", true)
local ttsMeteorIn5 = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\rs\\meteorcd.mp3", "TTS Meteor countdown", false)
local ttsSlow = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\rs\\slowdps.mp3", "TTS Slow dps", true)
local ttsStop = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\rs\\stopdps.mp3", "TTS Stop dps", true)
local ttsP2 = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\rs\\79percent.mp3", "TTS 79 Percent", true)
local ttsP3 = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\rs\\54percent.mp3", "TTS 54 Percent", true)

local timerShadowConsumptionCD		= mod:NewNextTimer(25, 74792)
local timerFieryConsumptionCD		= mod:NewNextTimer(25, 74562)
local timerMeteorCD					= mod:NewNextTimer(40, 74648)
local timerMeteorCast				= mod:NewCastTimer(7, 74648)--7-8 seconds from boss yell the meteor impacts.
local timerTwilightCutterCast		= mod:NewCastTimer(5, 77844)
local timerTwilightCutter			= mod:NewBuffActiveTimer(10, 77844)
local timerTwilightCutterCD			= mod:NewNextTimer(15, 77844)
local timerShadowBreathCD			= mod:NewCDTimer(19, 75954, nil, mod:IsTank() or mod:IsHealer())--Same as debuff timers, same CD, can be merged into 1.
local timerFieryBreathCD			= mod:NewCDTimer(19, 74526, nil, mod:IsTank() or mod:IsHealer())--But unique icons are nice pertaining to phase you're in ;)

local berserkTimer					= mod:NewBerserkTimer(480)

local soundConsumption 				= mod:NewSound(74562, "SoundOnConsumption")
mod:AddBoolOption("YellOnCutter", true, "announce")
mod:AddBoolOption("YellOnConsumption", true, "announce")
mod:AddBoolOption("AnnounceAlternatePhase", true, "announce")
mod:AddBoolOption("WhisperOnConsumption", true, "announce")
mod:AddBoolOption("SetIconOnConsumption", true)

local warned_preP2 = false
local warned_preP3 = false
local lastflame = 0
local lastshroud = 0
local phases = {}
local lastCorpAnnounce = "slow"
local lastMeteor = 0
local phase_transition = 0
local transition_countdown

function mod:LocationChecker()
	if GetTime() - lastshroud < 6 then
		DBM.BossHealth:RemoveBoss(39863)--you took damage from twilight realm recently so remove the physical boss from health frame.
	else
		DBM.BossHealth:RemoveBoss(40142)--you have not taken damage from twilight realm so remove twilight boss health bar.
	end
end

local function updateHealthFrame(phase)
	if phases[phase] then
		return
	end
	phases[phase] = true
	if phase == 1 then
		DBM.BossHealth:Clear()
		DBM.BossHealth:AddBoss(39863, L.NormalHalion)
	elseif phase == 2 then
		DBM.BossHealth:Clear()
		DBM.BossHealth:AddBoss(40142, L.TwilightHalion)
	elseif phase == 3 then
		DBM.BossHealth:AddBoss(39863, L.NormalHalion)--Add 1st bar back on. you have two bars for time being.
		mod:ScheduleMethod(20, "LocationChecker")--we remove the extra bar in 20 seconds depending on where you are at when check is run.
	end
end

function mod:OnCombatStart(delay)--These may still need retuning too, log i had didn't have pull time though.
	table.wipe(phases)
	warned_preP2 = false
	warned_preP3 = false
	phase2Started = 0
	lastflame = 0
	lastshroud = 0
	self.vb.phase = 1
	berserkTimer:Start(-delay)
	timerMeteorCD:Start(20-delay)
	ttsMeteorIn5:Schedule(20-5, 5)
	timerFieryConsumptionCD:Start(15-delay)
	timerFieryBreathCD:Start(10-delay)
	updateHealthFrame(1)
end

function mod:OnCombatEnd()
	ttsCutterIn5:Cancel()
	ttsMeteorIn5:Cancel()
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(74806, 75954, 75955, 75956) then
		warningShadowBreath:Show()
		timerShadowBreathCD:Start()
	elseif args:IsSpellID(74525, 74526, 74527, 74528) then
		warningFieryBreath:Show()
		timerFieryBreathCD:Start()
	end
end

function mod:SPELL_CAST_SUCCESS(args)--We use spell cast success for debuff timers in case it gets resisted by a player we still get CD timer for next one
	if args:IsSpellID(74792) then
		if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
			timerShadowConsumptionCD:Start(20)
		else
			timerShadowConsumptionCD:Start()
		end
		if mod:LatencyCheck() then
			self:SendSync("ShadowCD")
		end
	elseif args:IsSpellID(74562) then
		if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
			timerFieryConsumptionCD:Start(20)
		else
			timerFieryConsumptionCD:Start()
		end
		if mod:LatencyCheck() then
			self:SendSync("FieryCD")
		end
	end
end

function mod:SPELL_AURA_APPLIED(args)--We don't use spell cast success for actual debuff on >player< warnings since it has a chance to be resisted.
	if args:IsSpellID(74792) then
		if not self.Options.AnnounceAlternatePhase then
			warningShadowConsumption:Show(args.destName)
			if DBM:GetRaidRank() >= 1 and self.Options.WhisperOnConsumption then
				SendChatMessage(L.WhisperConsumption, "WHISPER", "COMMON", args.destName)
			end
		end
		if mod:LatencyCheck() then
			self:SendSync("ShadowTarget", args.destName)
		end
		if args:IsPlayer() then
			specWarnShadowConsumption:Show()
			ttsPing:Play()
			if self.Options.YellOnConsumption then
				SendChatMessage(L.YellConsumption, "SAY")
			end
		end
		if self.Options.SetIconOnConsumption then
			self:SetIcon(args.destName, 7)
		end
	elseif args:IsSpellID(74562) then
		if not self.Options.AnnounceAlternatePhase then
			warningFieryConsumption:Show(args.destName)
			if DBM:GetRaidRank() >= 1 and self.Options.WhisperOnConsumption then
				SendChatMessage(L.WhisperCombustion, "WHISPER", "COMMON", args.destName)
			end
		end
		if mod:LatencyCheck() then
			self:SendSync("FieryTarget", args.destName)
		end
		if args:IsPlayer() then
			specWarnFieryConsumption:Show()
			ttsPing:Play()
			if self.Options.YellOnConsumption then
				SendChatMessage(L.YellCombustion, "SAY")
			end
		end
		if self.Options.SetIconOnConsumption then
			self:SetIcon(args.destName, 8)
		end
	elseif args.spellName == "Corporeality" then
		if args:IsSpellID(74832) then
			if self.Options["Corporeality 40%%, slow DPS!"] == true and lastCorpAnnounce == "slow" then
				specWarnCorporealitySlow:Show()
			elseif lastCorpAnnounce == "stop" then
				lastCorpAnnounce = "slow"
				specWarnCorporealitySlow:Show()
				ttsSlow:Play()
			end
		elseif args:IsSpellID(74833) then
			if self.Options["Corporeality 30%%, stop DPS!"] == true and lastCorpAnnounce == "slow" then
				lastCorpAnnounce = "stop"
				specWarnCorporealityStop:Show()
				ttsStop:Play()
			end 
		end
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(74792) then
		if self.Options.SetIconOnConsumption then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(74562) then
		if self.Options.SetIconOnConsumption then
			self:SetIcon(args.destName, 0)
		end
	end
end

function mod:SPELL_DAMAGE(args)
	if (args:IsSpellID(75952, 75951, 75950, 75949) or args:IsSpellID(75948, 75947)) and args:IsPlayer() and GetTime() - lastflame > 2 then
		specWarnMeteorStrike:Show()
		lastflame = GetTime()
	elseif args:IsSpellID(75483, 75484, 75485, 75486) and args:IsPlayer() then
		lastshroud = GetTime()--keeps a time stamp for twilight realm damage to determin if you're still there or not for bosshealth frame.
	end
end

function mod:UNIT_HEALTH(uId)
	if not warned_preP2 and self:GetUnitCreatureId(uId) == 39863 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.79 then
		warned_preP2 = true
		warnPhase2Soon:Show()
		ttsP2:Play()
	elseif not warned_preP3 and self:GetUnitCreatureId(uId) == 40142 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.54 then
		warned_preP3 = true
		warnPhase3Soon:Show()	
		ttsP3:Play()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.Cutter then
		if self.Options.YellOnCutter then
			SendChatMessage(L.YellCutter, "SAY")
		end
		ttsCutterIn5:Play()
		--[[if mod:LatencyCheck() then
			self:SendSync("Meteor")
		end]]--
	elseif msg == L.Phase2 or msg:find(L.Phase2) then
		updateHealthFrame(2)
		timerFieryBreathCD:Cancel()
		timerMeteorCD:Cancel()
		timerFieryConsumptionCD:Cancel()
		warnPhase2:Show()
		self.vb.phase = 2
		timerShadowBreathCD:Start(25)
		timerShadowConsumptionCD:Start(20)--not exact, 15 seconds from tank aggro, but easier to add 5 seconds to it as a estimate timer than trying to detect this
		timerTwilightCutterCD:Start(35)
	elseif msg == L.Phase3 or msg:find(L.Phase3) then
		self:SendSync("Phase3")
		self.vb.phase = 3
	elseif msg == L.MeteorCast or msg:find(L.MeteorCast) then--There is no CLEU cast trigger for meteor, only yell
		if not self.Options.AnnounceAlternatePhase then
			warningMeteor:Show()
			lastMeteor = GetTime()
			timerMeteorCast:Start()--7 seconds from boss yell the meteor impacts.
			ttsMeteor:Play()
			timerMeteorCD:Start()
			ttsMeteorIn5:Schedule(40-5, 5)
		end
		if mod:LatencyCheck() then
			self:SendSync("Meteor")
		end
	end
end

local lastEmote = 0 -- only react on the first emote, warmane only sometimes puts another emote right when the cutter starts
function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if (msg == L.twilightcutter or msg:find(L.twilightcutter)) and GetTime() - lastEmote > 16 then
		specWarnTwilightCutter:Schedule(5)
	if not self.Options.AnnounceAlternatePhase then
		if GetTime() - lastshroud < 6 then
			lastEmote = GetTime()
			warningTwilightCutter:Show()
			timerTwilightCutterCast:Start()
			timerTwilightCutter:Schedule(5)--Delay it since it happens 5 seconds after the emote
			timerTwilightCutterCD:Schedule(15)
		end
	end
		if mod:LatencyCheck() then
			self:SendSync("TwilightCutter")
		end
	end
end

function mod:OnSync(msg, target)
--[[	if msg == "Cutter" then
		if self.Options.YellOnCutter then
			SendChatMessage(L.YellCutter, "SAY")
		end
		ttsCutterIn5:Play() ]]--
	if msg == "TwilightCutter" then
		if self.Options.AnnounceAlternatePhase then
			if GetTime() - lastshroud < 6 then
				warningTwilightCutter:Show()
				timerTwilightCutterCast:Start()
				timerTwilightCutter:Schedule(5)--Delay it since it happens 5 seconds after the emote
				timerTwilightCutterCD:Schedule(15)
			end
		end
	elseif msg == "Meteor" then
		if self.Options.AnnounceAlternatePhase then
			warningMeteor:Show()
			ttsMeteor:Play()
			timerMeteorCast:Start()
			timerMeteorCD:Start()
			lastMeteor = GetTime()
			ttsMeteorIn5:Schedule(40-5, 5)
		end
	elseif msg == "ShadowTarget" then
		if self.Options.AnnounceAlternatePhase then
			warningShadowConsumption:Show(target)
			if DBM:GetRaidRank() >= 1 and self.Options.WhisperOnConsumption then
				SendChatMessage(L.WhisperConsumption, "WHISPER", "COMMON", target)
			end
		end
	elseif msg == "FieryTarget" then
		if self.Options.AnnounceAlternatePhase then
			warningFieryConsumption:Show(target)
			if DBM:GetRaidRank() >= 1 and self.Options.WhisperOnConsumption then
				SendChatMessage(L.WhisperCombustion, "WHISPER", "COMMON", target)
			end
		end
	elseif msg == "ShadowCD" then
		if self.Options.AnnounceAlternatePhase then
			if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
				timerShadowConsumptionCD:Start(20)
			else
				timerShadowConsumptionCD:Start()
			end
		end
	elseif msg == "FieryCD" then
		if self.Options.AnnounceAlternatePhase then
			if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
				timerFieryConsumptionCD:Start(20)
			else
				timerFieryConsumptionCD:Start()
			end
		end
	elseif msg == "Phase3" then
		updateHealthFrame(3)
		warnPhase3:Show()
		timerMeteorCD:Start(30) --These i'm not sure if they start regardless of drake aggro, or if it varies as well.
		ttsMeteorIn5:Schedule(30-5, 5)
		timerFieryConsumptionCD:Start(20)--not exact, 15 seconds from tank aggro, but easier to add 5 seconds to it as a estimate timer than trying to detect this
	end
end

f = CreateFrame("Frame")
f:SetScript("OnUpdate",function(args)
	if GetTime() - phase_transition >= 14 and GetTime() - lastshroud < 3 and warned_preP3 == true then
		timerMeteorCD:Cancel()
	elseif GetTime() - phase_transition >= 15 and GetTime() - lastshroud > 4 and warned_preP3 == true then 
		ttsMeteorIn5:Cancel()
		timerTwilightCutterCD:Cancel()
	end
end)
