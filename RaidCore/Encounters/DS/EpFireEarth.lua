--------------------------------------------------------------------------------
-- Module Declaration
--

local core = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:GetAddon("RaidCore")

local mod = core:NewEncounter("EpFireEarth", 52, 98, 117)
if not mod then return end

mod:RegisterTrigMob("ALL", { "Megalith", "Pyrobane" })
mod:RegisterEnglishLocale({
    -- Unit names.
    ["Megalith"] = "Megalith",
    ["Pyrobane"] = "Pyrobane",
    ["Flame Wave"] = "Flame Wave",
    -- Datachron messages.
	["The ground shudders beneath Megalith"] = "The ground shudders beneath Megalith",
    -- Cast.
	["Ragnarok"] = "Ragnarok",
    -- Bar and messages.
    ["MIDPHASE"] = "MIDPHASE",
})
mod:RegisterFrenchLocale({
    -- Unit names.
    -- Datachron messages.
    -- Cast.
    -- Bar and messages.
})
mod:RegisterGermanLocale({
    -- Unit names.
    -- Datachron messages.
    -- Cast.
    -- Bar and messages.
})

--------------------------------------------------------------------------------
-- Locals
--


--------------------------------------------------------------------------------
-- Initialization
--
function mod:OnBossEnable()
    Print(("Module %s loaded"):format(mod.ModuleName))
    Apollo.RegisterEventHandler("RC_UnitStateChanged", "OnUnitStateChanged", self)
    Apollo.RegisterEventHandler("RC_UnitCreated", "OnUnitCreated", self)
    Apollo.RegisterEventHandler("RC_UnitDestroyed", "OnUnitDestroyed", self)
	Apollo.RegisterEventHandler("SPELL_CAST_START", "OnSpellCastStart", self)
	Apollo.RegisterEventHandler("CHAT_DATACHRON", "OnChatDC", self)
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:OnSpellCastStart(unitName, castName, unit)
    if unitName == self.L["Pyrobane"] and castName == self.L["Ragnarok"] then
		core:AddMsg("MIDMSG", "MIDPHASE GET ON ROCKS!!", 5, "Alarm", "Red")
		core:AddBar("MID2", self.L["MIDPHASE"], 120)
    end
end


function mod:OnUnitCreated(unit, sName)
	if sName == self.L["Flame Wave"] then
        local unitId = unit:GetId()
        if unitId then
            core:AddPixie(unitId, 2, unit, nil, "Green", 10, 20, 0)
        end
    end
end

function mod:OnUnitDestroyed(unit, sName)
    if sName == self.L["Flame Wave"] then
        local unitId = unit:GetId()
        if unitId then
            core:DropPixie(unitId)
        end
    end
end

function mod:OnUnitStateChanged(unit, bInCombat, sName)
    if unit:GetType() == "NonPlayer" then
        if sName == self.L["Megalith"] then
            core:AddUnit(unit)
        elseif sName == self.L["Pyrobane"] then
            core:AddUnit(unit)
			core:WatchUnit(unit)
            core:AddBar("MID1", self.L["MIDPHASE"], 95, true)
        end
    end
end

function mod:OnChatDC(message)
    if message:find(self.L["The ground shudders beneath Megalith"]) then
        core:AddMsg("QUAKE1", "JUMP !", 3, mod:GetSetting("SoundQuakeJump", "Beware"))
		core:AddMsg("QUAKE2", "JUMP !", 3, nil)
		core:AddMsg("QUAKE3", "JUMP !", 3, nil)
		core:AddMsg("QUAKE4", "JUMP !", 3, nil)
		core:AddMsg("QUAKE5", "JUMP !", 3, nil)
		core:AddMsg("QUAKE6", "JUMP !", 3, nil)
		core:AddMsg("QUAKE7", "JUMP !", 3, nil)
		core:AddMsg("QUAKE8", "JUMP !", 3, nil)
		core:AddMsg("QUAKE9", "JUMP !", 3, nil)
    end
end
