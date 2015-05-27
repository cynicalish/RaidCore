----------------------------------------------------------------------------------------------------
-- Client Lua Script for RaidCore Addon on WildStar Game.
--
-- Copyright (C) 2015 RaidCore
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
--
-- Description:
--   Unique encounter in Core-Y83 raid.
--
--   - There are 3 boss called "Prime Evolutionary Operant". At any moment, one of them is
--     compromised, and his name is "Prime Phage Distributor".
--   - Bosses don't move, their positions are constants so.
--   - The boss call "Prime Phage Distributor" have a debuff called "Compromised Circuitry".
--   - And switch boss occur at 60% and 20% of health.
--   - The player which will be irradied is the last connected in the game (probability: 95%).
--
--   So be careful, with code based on name, as bosses are renamed many times during the combat.
--
----------------------------------------------------------------------------------------------------
local core = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:GetAddon("RaidCore")

local mod = core:NewEncounter("PrimeEvolutionaryOperant", 91, 0, 475)
if not mod then return end

mod:RegisterTrigMob("ALL", { "Prime Evolutionary Operant", "Prime Phage Distributor" })
mod:RegisterEnglishLocale({
    -- Unit names.
    ["Prime Evolutionary Operant"] = "Prime Evolutionary Operant",
    ["Prime Phage Distributor"] = "Prime Phage Distributor",
    ["Sternum Buster"] = "Sternum Buster",
    -- Datachron messages.
    ["(.*) is being irradiated"] = "(.*) is being irradiated",
    ["ENGAGING TECHNOPHAGE TRASMISSION"] = "ENGAGING TECHNOPHAGE TRASMISSION",
    ["A Prime Purifier has been corrupted!"] = "A Prime Purifier has been corrupted!",
    -- Cast
    ["Digitize"] = "Digitize",
    ["Strain Injection"] = "Strain Injection",
    ["Corruption Spike"] = "Corruption Spike",
    -- Bars messages.
    ["~Next irradiate"] = "~Next irradiate",
})
mod:RegisterFrenchLocale({
    -- Unit names.
    ["Prime Evolutionary Operant"] = "Premier purificateur",
    ["Prime Phage Distributor"] = "Distributeur de Primo Phage",
    -- Datachron messages.
    ["(.*) is being irradiated"] = "(.*) est irradiée.",
    ["ENGAGING TECHNOPHAGE TRASMISSION"] = "ENCLENCHEMENT DE LA TRANSMISSION DU TECHNOPHAGE",
    -- Bars messages.
    ["~Next irradiate"] = "~Prochaine irradiation",
})
mod:RegisterGermanLocale({
})

----------------------------------------------------------------------------------------------------
-- Copy of few objects to reduce the cpu load.
-- Because all local objects are faster.
----------------------------------------------------------------------------------------------------
local GetPlayerUnit = GameLib.GetPlayerUnit
local GetGameTime = GameLib.GetGameTime
--local GeminiGUI = Apollo.GetPackage("Gemini:GUI-1.0").tPackage
----------------------------------------------------------------------------------------------------
-- Constants.
----------------------------------------------------------------------------------------------------
-- Center of the room, where is the Organic Incinerator button.
local ORGANIC_INCINERATOR = { x = 1268, y = -800, z = 876 }
-- It's when the player enter in "nuclear" green zone. If this last have some STRAIN INCUBATION,
-- he will lost it, and an small mob will pop.
local DEBUFF_RADIATION_BATH = 71188
-- DOT taken by one or more players, which is dispel with RADIATION_BATH or ENGAGING datachron
-- event.
local DEBUFF_STRAIN_INCUBATION = 49303
-- Buff stackable on bosses. The beam from the wall buff the boss when they are not hit by the boss
-- itself. At 15 stacks, the datachron message "A Prime Purifier has been corrupted!" will trig.
-- Note: the datachron event is raised before the buff update event.
local BUFF_NANOSTRAIN_INFUSION = 50075
-- Buff on bosses. The boss called "Prime Phage Distributor" have this buff, others not.
local BUFF_COMPROMISED_CIRCUITRY = 48735

----------------------------------------------------------------------------------------------------
-- Encounter description.
----------------------------------------------------------------------------------------------------
function mod:OnBossEnable()
	Print(("Module %s loaded"):format(mod.ModuleName))
	Apollo.RegisterEventHandler("RC_UnitCreated", "OnUnitCreated", self)
    Apollo.RegisterEventHandler("RC_UnitStateChanged", "OnUnitStateChanged", self)
    Apollo.RegisterEventHandler("CHAT_DATACHRON", "OnChatDC", self)

	Apollo.RemoveEventHandler("DEBUFF_APPLIED", self)
	Apollo.RemoveEventHandler("DEBUFF_REMOVED", self)
	
    Apollo.RegisterEventHandler("DEBUFF_APPLIED", "OnDebuffApplied", self)

 	Apollo.RegisterEventHandler("DEBUFF_REMOVED", "OnDebuffRemoved", self)

    Apollo.RegisterEventHandler("RAID_WIPE", "OnReset", self)
	--core:CombatInterface_Activate("FullEnable")
	--core:InterfaceSwitch(5)
--ApplyCCState(eState, unitTarget) --test cc on middle
	--Print("Event registered")
end

function mod:OnReset()
	--Print("wipe")
	core:ResetMarks()
end

function mod:OnUnitCreated(unit, sName)
	if "Organic Incinerator" == sName then
			core:AddPixie(unit:GetId(), 2, unit, nil, "Red", 10, 100, -30)
	end
end

function mod:OnDebuffApplied(unitName, splId, unit)
	--Print("debuff applied")
	
	local eventTime = GameLib.GetGameTime()
	local tSpell = GameLib.GetSpell(splId)
    local strSpellName
	--Print("tSpell if check")
    if tSpell then
        strSpellName = tostring(tSpell:GetName())
		--Print(strSpellName)
    else
        --Print("Unknown tSpell")
    end
	--Print("after tSpell if check")
	if splId == DEBUFF_STRAIN_INCUBATION then
		--Print("in strain incubation")
        core:MarkUnit(unit, nil, "Incubation")
		if unit == GetPlayerUnit() then
			core:AddMsg("INCUBATION", ("Strain Incubation on YOU!!"), 5, "Inferno", "Red")
		end
	elseif splId == DEBUFF_RADIATION_BATH then
		if unit == GetPlayerUnit() then
			core:AddMsg("BATH", ("Radiation Bath on %s"):format(unitName), 5, "RunAway", "Blue")
		end
		core:MarkUnit(unit, nil, "Radiation\nBath")	
    end

end

function mod:OnDebuffRemoved(unitName, splId, unit)
	local unitId = unit:GetId()
	if splId == DEBUFF_STRAIN_INCUBATION then
       	if unitId then
    		core:DropMark(unitId)
    	end
	elseif splId == DEBUFF_RADIATION_BATH then
		if unitId then
    		core:DropMark(unitId)
    	end
    end
end

--[[
function mod:OnSpellCastStart(unitName, castName, unit)
	
	self:ScheduleTimer("RemoveBombMarker", 10, "fire", unit)
end
--]]

function mod:OnUnitStateChanged(unit, bInCombat, sName)
    if bInCombat then
        if sName == self.L["Prime Evolutionary Operant"] then
            core:AddUnit(unit)
            core:WatchUnit(unit)
            local tPosition = unit:GetPosition()
            if tPosition.x < ORGANIC_INCINERATOR.x then
                core:MarkUnit(unit, 1, "L")
            else
                core:MarkUnit(unit, 1, "R")
            end
        elseif sName == self.L["Prime Phage Distributor"] then
            core:AddUnit(unit)
            core:MarkUnit(unit, 1, "M")
            core:WatchUnit(unit)
            core:AddBar("NEXT_IRRADIATE", self.L["~Next irradiate"], 27, true)
		end
    end
end

function mod:OnChatDC(message)
    local sPlayerNameIrradiate = message:match(self.L["(.*) is being irradiated"])
	local UnitIrrad = nil
    if sPlayerNameIrradiate then
		--[[for i = 1, GroupLib.GetMemberCount() do
        	local tUnit = GroupLib.GetUnitForGroupMember(i)
        	if tUnit then
            	local sName = tUnit:GetName():gsub(NO_BREAK_SPACE, " ")
				if sName == sPlayerNameIrradiate then
					UnitIrrad = tUnit
				end
			end
		end
		
		if UnitIrrad then
			if UnitIrrad == GetPlayerUnit() then
				core:AddMsg("BATH", ("Radiation Bath on YOU!!"), 5, "RunAway", "Blue")
			end
			--core:MarkUnit(UnitIrrad, nil, "Radiation\nBath")
		end--]]
		if sPlayerNameIrradiate == GetPlayerUnit():GetName() then 
			core:AddMsg("BATH", ("Radiation Bath on YOU!!"), 5, "RunAway", "Blue")
		else
			core:AddMsg("BATH", ("Radiation Bath on %s"):format(sPlayerNameIrradiate), 5, nil, "Blue")
		end
        -- Sometime it's 26s, sometime 27s or 28s.
        core:AddBar("NEXT_IRRADIATE", self.L["~Next irradiate"], 26, true)
    elseif message == self.L["ENGAGING TECHNOPHAGE TRASMISSION"] then
        core:AddBar("NEXT_IRRADIATE", self.L["~Next irradiate"], 40, true)
    end
end
