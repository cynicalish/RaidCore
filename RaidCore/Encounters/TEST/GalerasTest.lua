------------------------------------------------------------------------------
-- Client Lua Script for RaidCore Addon on WildStar Game.
--
-- Copyright (C) 2015 RaidCore
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- Description:
--   Fake boss, to test few basic feature in RaidCore.
--
--   This last should be declared only in alpha version or with git database.
------------------------------------------------------------------------------
local core = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:GetAddon("RaidCore")

--@alpha@
local mod = core:NewEncounter("GalerasTest", 6, 0, 16)
--@end-alpha@
if not mod then return end

local bufflock = false
local bltimer = nil

mod:RegisterTrigMob("ANY", { "Crimson Spiderbot", "Crimson Clanker" })
mod:RegisterEnglishLocale({
    -- Unit names.
    ["Crimson Clanker"] = "Crimson Clanker",
    ["Crimson Spiderbot"] = "Crimson Spiderbot",
    ["Phaser Combo"] = "Phaser Combo",
})
mod:RegisterFrenchLocale({
    -- Unit names.
    ["Crimson Clanker"] = "Cybernéticien écarlate",
    ["Crimson Spiderbot"] = "Arachnobot écarlate",
    ["Phaser Combo"] = "Combo de phaser",
})

function mod:OnBossEnable()
    Apollo.RegisterEventHandler("RC_UnitCreated", "OnUnitCreated", self)
    Apollo.RegisterEventHandler("RC_UnitStateChanged", "OnUnitStateChanged", self)

    Apollo.RegisterEventHandler("SPELL_CAST_START", "OnSpellCastStart", self)
    Apollo.RegisterEventHandler("SPELL_CAST_END", "OnSpellCastEnd", self)

	Apollo.RegisterEventHandler("BUFF_APPLIED", "OnGTBuffApplied", self)
	
	Apollo.RegisterEventHandler("DEBUFF_APPLIED", "OnDebuffApplied", self)
	
	Apollo.RegisterEventHandler("RAID_WIPE", "OnRWGT", self)
end

function mod:OnRWGT()
	--Apollo.RemoveEventHandler

	Print("in gt wipe")
	--self = nil
end

--	Apollo.RemoveEventHandler("DEBUFF_APPLIED", self)
function mod:lockhandler()
	--Print("in lockhandler")
	bufflock = false
end

function mod:OnGTBuffApplied(unitName, splId, unit)
	--[[local tSpell = GameLib.GetSpell(splId)
	local strSpellName
	if tSpell then
		strSpellName = tostring(tSpell:GetName())
	else
		Print("Unknown tSpell")
	end--]]
	--if bufflock then return end


	bufflock = true
	Print("received buff signal")
	if splId == 42803 then
		core:AddMsg("BLUEPURGE", "PURGE BLUE BOSS", 5, "Inferno")
		Print("Shatter: " .. splId)
		
	end
	bufflock = false
	--bltimer = ApolloTimer.Create(0.01, false, "lockhandler", self)
	
	--Apollo.RegisterEventHandler("DEBUFF_APPLIED", "OnDebuffApplied", self)
end

function mod:OnDebuffApplied(unitName, splId, unit)
	Print("received debuff signal")
end

function mod:OnUnitCreated(unit, sName)
    if sName == self.L["Crimson Spiderbot"] then
		Print("unit spawned")
        core:MarkUnit(unit, 1, "A")
    end
end

function mod:OnUnitStateChanged(unit, bInCombat, sName)
	pUnit = GameLib.GetPlayerUnit()
    if bInCombat then
        if sName == self.L["Crimson Spiderbot"] then
            core:WatchUnit(unit)
            core:AddUnit(unit)
            core:MarkUnit(unit, 1, "X")
			core:AddPixie(unit:GetId(), 2, unit, nil, "Red", 10, 100, -30)

			--core:WatchUnit(pUnit)
			core:UnitBuff(pUnit)
            core:AddUnit(pUnit)
            --core:MarkUnit(pUnit , nil, "Incubation")
			--core:AddPixie(pUnit:GetId(), 2, pUnit, nil, "Red", 10, 70, -30)
		end
    end
end

function mod:OnSpellCastStart(unitName, castName, unit)
    if castName == self.L["Phaser Combo"] then
        Print("Cast Start")
    end
end

function mod:OnSpellCastEnd(unitName, castName, unit)
    if castName == self.L["Phaser Combo"] then
        Print("Cast End")
    end
end
