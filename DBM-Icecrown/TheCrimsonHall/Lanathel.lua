local mod	= DBM:NewMod("Lanathel", "DBM-Icecrown", 3)
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 4212 $"):sub(12, -3))
mod:SetCreatureID(37955)
mod:SetUsedIcons(4, 5, 6, 7, 8)

mod:RegisterCombat("combat")

mod:RegisterEvents(
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_REMOVED",
	"SPELL_CAST_SUCCESS",
	"SPELL_DAMAGE",
	"SPELL_PERIODIC_DAMAGE",
	"CHAT_MSG_RAID_BOSS_EMOTE"
)

local warnPactDarkfallen			= mod:NewTargetAnnounce(71340, 4)
local warnBloodMirror				= mod:NewTargetAnnounce(71510, 3, nil, mod:IsTank() or mod:IsHealer())
local warnSwarmingShadows			= mod:NewTargetAnnounce(71266, 4)
local warnInciteTerror				= mod:NewSpellAnnounce(73070, 3)
local warnVampricBite				= mod:NewTargetAnnounce(71727, 2)
local warnMindControlled			= mod:NewTargetAnnounce(70923, 4)
local warnBloodthirstSoon			= mod:NewSoonAnnounce(71474, 2)
local warnBloodthirst				= mod:NewTargetAnnounce(71474, 3, nil, false)
local warnEssenceoftheBloodQueen	= mod:NewTargetAnnounce(71473, 3, nil, false)

local specWarnBloodBolt				= mod:NewSpecialWarningSpell(71772)
local specWarnPactDarkfallen		= mod:NewSpecialWarningYou(71340)
local specWarnEssenceoftheBloodQueen= mod:NewSpecialWarningYou(71473)
local specWarnBloodthirst			= mod:NewSpecialWarningYou(71474)
local specWarnSwarmingShadows		= mod:NewSpecialWarningMove(71266)
local specWarnMindConrolled			= mod:NewSpecialWarningTarget(70923, mod:IsTank())

local timerNextInciteTerror			= mod:NewNextTimer(100, 73070)
local timerFirstBite				= mod:NewCastTimer(15, 71727)
local timerNextPactDarkfallen		= mod:NewNextTimer(30.5, 71340)
local timerNextSwarmingShadows		= mod:NewNextTimer(30.5, 71266)
local timerInciteTerror				= mod:NewBuffActiveTimer(4, 73070)
local timerBloodBolt				= mod:NewBuffActiveTimer(6, 71772)
local timerBloodThirst				= mod:NewBuffActiveTimer(10, 71474)
local timerEssenceoftheBloodQueen	= mod:NewBuffActiveTimer(60, 71473)

local ttsBite = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\icc\\bql\\bitecd.mp3", "TTS Bite countdown", true)
local ttsPact = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\icc\\bql\\link.mp3", "TTS Pact call", true)
local ttsPing = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\icc\\bql\\runaway.mp3", "TTS Swarming Shadows", true)
local ttsLink = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\icc\\bql\\Pact_Soon.wav", "TTS Pact soon", true)
local berserkTimer					= mod:NewBerserkTimer(330)

local soundSwarmingShadows			= mod:NewSound(71266)

mod:AddBoolOption("BloodMirrorIcon", false)
mod:AddBoolOption("SwarmingShadowsIcon", true)
mod:AddBoolOption("SetIconOnDarkFallen", true)
mod:AddBoolOption("RangeFrame", true)
mod:AddBoolOption("YellOnFrenzy", false, "announce")

local pactTargets = {}
local pactIcons = 6

local function warnPactTargets()
	warnPactDarkfallen:Show(table.concat(pactTargets, "<, >"))
	table.wipe(pactTargets)
	timerNextPactDarkfallen:Start(30)
	ttsLink:Schedule(25)
	pactIcons = 6
end

function mod:OnCombatStart(delay)
	berserkTimer:Start(-delay)
	timerFirstBite:Start(-delay)
	timerNextPactDarkfallen:Start(15-delay)
	ttsLink:Schedule(10-delay)
	timerNextSwarmingShadows:Start(-delay)
	table.wipe(pactTargets)
	pactIcons = 6
	if self.Options.RangeFrame then
		DBM.RangeCheck:Show(8)
	end
	if mod:IsDifficulty("normal10") or mod:IsDifficulty("heroic10") then
		timerNextInciteTerror:Start(124-delay)
	else
		timerNextInciteTerror:Start(127-delay)
	end
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
	ttsBite:Cancel()
	ttsLink:Cancel()
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(71340) then		--Pact of the Darkfallen
		pactTargets[#pactTargets + 1] = args.destName
		if args:IsPlayer() then
			specWarnPactDarkfallen:Show()
			ttsPact:Play()
		end
		if self.Options.SetIconOnDarkFallen then--Debuff doesn't actually last 30 seconds
			self:SetIcon(args.destName, pactIcons, 28)--it lasts forever, but if you still have it after 28 seconds
			pactIcons = pactIcons - 1--then you're probably dead anyways
		end
		self:Unschedule(warnPactTargets)
		if #pactTargets >= 3 then
			warnPactTargets()
		else
			self:Schedule(0.3, warnPactTargets)
		end
	elseif args:IsSpellID(71510, 70838) then
		warnBloodMirror:Show(args.destName)
		if self.Options.BloodMirrorIcon then
			self:SetIcon(args.destName, 7)
		end
	elseif args:IsSpellID(70877, 71474) then
		warnBloodthirst:Show(args.destName)
		if args:IsPlayer() then
			specWarnBloodthirst:Show()
			if self.Options.YellOnFrenzy then
				SendChatMessage(L.YellFrenzy, "SAY")
			end
			if mod:IsDifficulty("normal10") or mod:IsDifficulty("heroic10") then
				timerBloodThirst:Start(15)--15 seconds on 10 man
			else
				timerBloodThirst:Start()--10 seconds on 25 man
			end
		end
	elseif args:IsSpellID(70867, 70879, 71473, 71525) or args:IsSpellID(71530, 71531, 71532, 71533) then	--Essence of the Blood Queen
		warnEssenceoftheBloodQueen:Show(args.destName)
		if args:IsPlayer() then
			specWarnEssenceoftheBloodQueen:Show()
			if mod:IsDifficulty("normal10") or mod:IsDifficulty("heroic10") then
				timerEssenceoftheBloodQueen:Start(75)--75 seconds on 10 man
				ttsBite:Schedule(70)
				warnBloodthirstSoon:Schedule(70)
			else
				timerEssenceoftheBloodQueen:Start()--60 seconds on 25 man
				ttsBite:Schedule(55)
				warnBloodthirstSoon:Schedule(55)
			end
		end
	elseif args:IsSpellID(70923) then
		warnMindControlled:Show(args.destName)
		specWarnMindConrolled:Show(args.destName)
	elseif args:IsSpellID(71772) then
		specWarnBloodBolt:Show()
		timerBloodBolt:Start()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(71340) then				--Pact of the Darkfallen
		if self.Options.SetIconOnDarkFallen then
			self:SetIcon(args.destName, 0)		--Clear icon once you got to where you are supposed to be
		end
	elseif args:IsSpellID(71510, 70838) then	--Blood Mirror
		if self.Options.BloodMirrorIcon then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(70877, 71474) then
		if args:IsPlayer() then
			timerBloodThirst:Cancel()
		end
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(73070) then				--Incite Terror (fear before air phase)
		warnInciteTerror:Show()
		timerInciteTerror:Start()
		timerNextSwarmingShadows:Start()--This resets the swarming shadows timer
		timerNextPactDarkfallen:Start(25)--and the Pact timer also reset -5 seconds
		ttsLink:Schedule(20)
		if mod:IsDifficulty("normal10") or mod:IsDifficulty("heroic10") then
			timerNextInciteTerror:Start(120)--120 seconds in between first and second on 10 man
		else
			timerNextInciteTerror:Start()--100 seconds in between first and second on 25 man
		end
	end
end

function mod:SPELL_DAMAGE(args)
	if args:IsSpellID(71726, 71727, 71728, 71729) and args:GetSrcCreatureID() == 37955 then	-- Vampric Bite (first bite only, hers)
		warnVampricBite:Show(args.destName)
	end
end

do
	local lastswarm = 0
	function mod:SPELL_PERIODIC_DAMAGE(args)
		if args:IsPlayer() and args:IsSpellID(71277, 72638, 72639, 72640) then		--Swarn of Shadows (spell damage, you're standing in it.)
			if GetTime() - 3 > lastswarm then
				specWarnSwarmingShadows:Show()
				ttsPing:Play()
				lastswarm = GetTime()
			end
		end
	end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg, _, _, _, target)
	if msg:match(L.SwarmingShadows) then
		warnSwarmingShadows:Show(target)
		timerNextSwarmingShadows:Start()
		if target == UnitName("player") then
			specWarnSwarmingShadows:Show()
			ttsPing:Play()
		end
		if self.Options.SwarmingShadowsIcon then
			self:SetIcon(target, 8, 6)
		end
	end
end