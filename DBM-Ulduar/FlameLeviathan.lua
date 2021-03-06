local mod	= DBM:NewMod("FlameLeviathan", "DBM-Ulduar")
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 4181 $"):sub(12, -3))

mod:SetCreatureID(33113)

mod:RegisterCombat("yell", L.YellPull)

mod:RegisterEvents(
	"SPELL_AURA_REMOVED",
	"SPELL_AURA_APPLIED",
	"SPELL_SUMMON"
)

local warnHodirsFury		= mod:NewTargetAnnounce(62297)
local pursueTargetWarn		= mod:NewAnnounce("PursueWarn", 2, 62374)
local warnNextPursueSoon	= mod:NewAnnounce("warnNextPursueSoon", 3, 62374)

local warnSystemOverload	= mod:NewSpecialWarningSpell(62475)
local pursueSpecWarn		= mod:NewSpecialWarning("SpecialPursueWarnYou")
local warnWardofLife		= mod:NewSpecialWarning("warnWardofLife")

local timerSystemOverload	= mod:NewBuffActiveTimer(20, 62475)
local timerFlameVents		= mod:NewCastTimer(10, 62396)

local ttsKite = mod:NewSoundFile("Interface\\AddOns\\DBM-Core\\sounds\\icc\\lady\\onYouRun.mp3", "TTS Chasing you", false)

local timerNextFlameVents = nil
if mod:IsDifficulty("heroic10") then
	timerNextFlameVents	= mod:NewNextTimer(20, 62396)
else 
	timerNextFlameVents	= mod:NewNextTimer(20, 62396) -- im leaving this split because it keeps changing every week
end
local timerPursued			= mod:NewTargetTimer(30, 62374)

local guids = {}
local function buildGuidTable()
	table.wipe(guids)
	for i = 1, GetNumRaidMembers() do
		guids[UnitGUID("raid"..i.."pet") or ""] = UnitName("raid"..i)
	end
end

function mod:OnCombatStart(delay)
	buildGuidTable()
	if mod:IsDifficulty("heroic10") then
		timerNextFlameVents:Start(20)
	else
		timerNextFlameVents:Start(30)
	end
end

function mod:SPELL_SUMMON(args)
	if args:IsSpellID(62907) then		-- Ward of Life spawned (Creature id: 34275)
		warnWardofLife:Show()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(62396) then		-- Flame Vents
		timerFlameVents:Start()
		timerNextFlameVents:Start()

	elseif args:IsSpellID(62475) then	-- Systems Shutdown / Overload
		timerSystemOverload:Start()
		timerNextFlameVents:Stop()
		if mod:IsDifficulty("heroic10") then
			timerNextFlameVents:Start(40)
		else
			timerNextFlameVents:Start(50)
		end
		warnSystemOverload:Show()

	elseif args:IsSpellID(62374) then	-- Pursued
		local player = guids[args.destGUID]
		warnNextPursueSoon:Schedule(25)
		timerPursued:Start(player)
		pursueTargetWarn:Show(player)
		if player == UnitName("player") then
			pursueSpecWarn:Show()
			ttsKite:Play()
		end
	elseif args:IsSpellID(62297) then		-- Hodir's Fury (Person is frozen)
		warnHodirsFury:Show(args.destName)
	end

end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(62396) then
		timerFlameVents:Stop()
	end
end