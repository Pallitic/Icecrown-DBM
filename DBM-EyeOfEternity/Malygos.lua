local mod	= DBM:NewMod("Malygos", "DBM-EyeOfEternity")
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 3726 $"):sub(12, -3))
mod:SetCreatureID(28859)

mod:RegisterCombat("yell", L.YellPull)

mod:RegisterEvents(
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"SPELL_CAST_SUCCESS",
	"SPELL_CAST_START",
	"CHAT_MSG_MONSTER_YELL",
	"SPELL_AURA_APPLIED"
)

local warnSpark					= mod:NewAnnounce("WarningSpark", 2, 59381)
local warnVortex				= mod:NewSpellAnnounce(56105, 3)
local warnVortexSoon			= mod:NewSoonAnnounce(56105, 2)
local warnBreathInc				= mod:NewAnnounce("WarningBreathSoon", 3, 60072)
local warnBreath				= mod:NewAnnounce("WarningBreath", 4, 60072)
local warnSurge					= mod:NewTargetAnnounce(60936, 3)
local warnStaticField			= mod:NewTargetAnnounce(57430, 3)

local specWarnSurge				= mod:NewSpecialWarningYou(60936)
local specWarnStaticField		= mod:NewSpecialWarningYou(57430, nil, nil, nil, 1, 2)
local specWarnStaticFieldNear	= mod:NewSpecialWarningClose(57430, nil, nil, nil, 1, 2)

local enrageTimer				= mod:NewBerserkTimer(615)
local timerSpark				= mod:NewTimer(30, "TimerSpark", 59381)
local timerVortex				= mod:NewCastTimer(11, 56105)
local timerVortexCD				= mod:NewNextTimer(60, 56105)
local timerBreath				= mod:NewTimer(59, "TimerBreath", 60072)
local timerAchieve      		= mod:NewAchievementTimer(360, 1875, "TimerSpeedKill")
local timerIntermission 		= mod:NewTimer(22, "Malygos Unattackable")
local timerAttackable 			= mod:NewTimer(24, "Malygos Wipes Debuffs")
local timerStaticFieldCD		= mod:NewNextTimer(12.5, 57430)

local ttsSpark = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\eoe\\fissure.mp3", "TTS Spark spawn", true)
local ttsVortex = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\eoe\\new.mp3", "TTS Vortex soon", true)
local ttsBreath = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\eoe\\wall.mp3", "TTS Breath soon", true)
local ttsSurge = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\eoe\\port.mp3", "TTS Surge on you", true)
local ttsMove = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\eoe\\whelp.mp3", "TTS Move with mark", true)
local ttsNow = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\eoe\\now.mp3", "TTS Attack now", true)

local guids = {}
local surgeTargets = {}

local function buildGuidTable()
	for i = 1, GetNumRaidMembers() do
		guids[UnitGUID("raid"..i.."pet") or ""] = UnitName("raid"..i)
	end
end

function mod:OnCombatStart(delay)
	enrageTimer:Start(-delay)
	timerAchieve:Start(-delay)
	timerVortexCD:Start(40)
	ttsVortex:Schedule(35)
	table.wipe(guids)
	self.vb.phase = 1
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if msg == L.EmoteSpark or msg:find(L.EmoteSpark) then
		self:SendSync("Spark")
	elseif msg == L.EmoteBreath or msg:find(L.EmoteBreath) then
		self:SendSync("Breath")
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(56105) then
		timerVortexCD:Start()
		warnVortexSoon:Schedule(54)
		ttsVortex:Schedule(54)
		warnVortex:Show()
		timerVortex:Start()
		if timerSpark:GetTime() < 11 and timerSpark:IsStarted() then
			timerSpark:Update(18, 30)
		end
	elseif args:IsSpellID(57430) then 
		self:ScheduleMethod(0.1, "StaticFieldTarget")
		--warnStaticField:Show()
		timerStaticFieldCD:Start()
	end
end

-- not really sure which one this spell is casted by. Use both i guess
function mod:SPELL_CAST_START(args) 
	if args:IsSpellID(57430) then 
		self:ScheduleMethod(0.1, "StaticFieldTarget")
		--warnStaticField:Show()
		timerStaticFieldCD:Start()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg:sub(0, L.YellPhase2:len()) == L.YellPhase2 then
		self:SendSync("Phase2")
		self.vb.phase = 2
		ttsVortex:Cancel()
	elseif msg == L.YellBreath or msg:find(L.YellBreath) then
		self:SendSync("BreathSoon")
	elseif msg:sub(0, L.YellPhase3:len()) == L.YellPhase3 then
		self:SendSync("Phase3")
		self.vb.phase = 3
	elseif msg == L.EnoughScream then
		timerBreath:Stop()
		timerAttackable:Start()
		ttsNow:Play()
		timerStaticFieldCD:Start(24+15.5)
	end
end

local function announceTargets(self)
	warnSurge:Show(table.concat(surgeTargets, "<, >"))
	table.wipe(surgeTargets)
end

function mod:StaticFieldTarget()
	local targetname, uId = self:GetBossTarget(28859)
	if not targetname or not uId then return end
	local targetGuid = UnitGUID(uId)

	if #guids < 1 then
		buildGuidTable()
	end

	local announcetarget = guids[targetGuid]
	if announcetarget == UnitName("player") then
		specWarnStaticField:Show()
		ttsMove:Play()
		SendChatMessage("Static Field on me!", "YELL")
	else
		local uId2 = DBM:GetRaidUnitId(announcetarget)
		if uId2 then
			local inRange = DBM.RangeCheck:GetDistance("player", GetPlayerMapPosition(uId2))
			if inRange and inRange < 13 then
				specWarnStaticFieldNear:Show(announcetarget)
				ttsMove:Play()
			else
				warnStaticField:Show(announcetarget)
			end
		else
			warnStaticField:Show(announcetarget)
		end
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(60936, 57407) then
		local target = guids[args.destGUID or 0]
		if target then
			surgeTargets[#surgeTargets + 1] = target
			self:Unschedule(announceTargets)
			if #surgeTargets >= 3 then
				announceTargets()
			else
				self:Schedule(0.5, announceTargets, self)
			end
			if target == UnitName("player") then
				specWarnSurge:Show()
				ttsSurge:Play()
			end
		end
	end
end

function mod:OnSync(event, arg)
	if event == "Spark" then
		warnSpark:Show()
		ttsSpark:Play()
		timerSpark:Start()
	elseif event == "Phase2" then
		timerSpark:Stop()
		timerVortexCD:Stop()
		timerIntermission:Start()
		timerBreath:Start(92)
	elseif event == "Breath" then
		timerBreath:Schedule(1)
		warnBreath:Schedule(1)
	elseif event == "BreathSoon" then
		warnBreathInc:Show()
		ttsBreath:Play()
	elseif event == "Phase3" then
		self:Schedule(6, buildGuidTable)
	end
end
