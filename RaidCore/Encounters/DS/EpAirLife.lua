--------------------------------------------------------------------------------
-- Module Declaration
--

local core = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:GetAddon("RaidCore")

local mod = core:NewEncounter("EpAirLife", 52, 98, 119)
if not mod then return end

mod:RegisterTrigMob("ALL", { "Aileron", "Visceralus" })
mod:RegisterEnglishLocale({
    -- Unit names.
    ["Visceralus"] = "Visceralus",
    ["Aileron"] = "Aileron",
    ["Wild Brambles"] = "Wild Brambles",
    ["[DS] e395 - Air - Tornado"] = "[DS] e395 - Air - Tornado",
    ["Life Force"] = "Life Force",
    ["Lifekeeper"] = "Lifekeeper",
    -- Datachron messages.
    -- Cast.
    ["Blinding Light"] = "Blinding Light",
    -- Bar and messages.
    ["TWIRL ON YOU!"] = "TWIRL ON YOU!",
    ["Thorns"] = "Thorns",
    ["Twirl"] = "Twirl",
    ["Midphase ending"] = "Midphase ending",
    ["Middle Phase"] = "Middle Phase",
    ["Next Healing Tree"] = "Next Healing Tree",
    ["No-Healing Debuff!"] = "No-Healing Debuff!",
    ["NO HEAL DEBUFF"] = "NO HEAL\nDEBUFF",
    ["Lightning"] = "Lightning",
    ["Lightning on YOU"] = "Lightning on YOU",
    ["Recently Saved!"] = "Recently Saved!",
})
mod:RegisterFrenchLocale({
    -- Unit names.
    ["Visceralus"] = "Visceralus",
    ["Aileron"] = "Ventemort",
    ["Wild Brambles"] = "Ronces sauvages",
    --["[DS] e395 - Air - Tornado"] = "[DS] e395 - Air - Tornado", -- TODO: French translation missing !!!!
    ["Life Force"] = "Force vitale",
    ["Lifekeeper"] = "Garde-vie",
    -- Datachron messages.
    -- Cast.
    ["Blinding Light"] = "Lumière aveuglante",
    -- Bar and messages.
    --["TWIRL ON YOU!"] = "TWIRL ON YOU!", -- TODO: French translation missing !!!!
    ["Thorns"] = "Épines",
    ["Twirl"] = "Tournoiement",
    --["Midphase ending"] = "Midphase ending", -- TODO: French translation missing !!!!
    --["Middle Phase"] = "Middle Phase", -- TODO: French translation missing !!!!
    --["Next Healing Tree"] = "Next Healing Tree", -- TODO: French translation missing !!!!
    --["No-Healing Debuff!"] = "No-Healing Debuff!", -- TODO: French translation missing !!!!
    --["NO HEAL DEBUFF"] = "NO HEAL\nDEBUFF", -- TODO: French translation missing !!!!
    ["Lightning"] = "Foudre",
    --["Lightning on YOU"] = "Lightning on YOU", -- TODO: French translation missing !!!!
    --["Recently Saved!"] = "Recently Saved!", -- TODO: French translation missing !!!!
})
mod:RegisterGermanLocale({
    -- Unit names.
    ["Visceralus"] = "Viszeralus",
    ["Aileron"] = "Aileron",
    ["Wild Brambles"] = "Wilde Brombeeren",
    --["[DS] e395 - Air - Tornado"] = "[DS] e395 - Air - Tornado", -- TODO: German translation missing !!!!
    ["Life Force"] = "Lebenskraft",
    ["Lifekeeper"] = "Lebensbewahrer",
    -- Datachron messages.
    -- Cast.
    ["Blinding Light"] = "Blendendes Licht",
    -- Bar and messages.
    --["TWIRL ON YOU!"] = "TWIRL ON YOU!", -- TODO: German translation missing !!!!
    ["Thorns"] = "Dornen",
    ["Twirl"] = "Wirbel",
    --["Midphase ending"] = "Midphase ending", -- TODO: German translation missing !!!!
    --["Middle Phase"] = "Middle Phase", -- TODO: German translation missing !!!!
    --["Next Healing Tree"] = "Next Healing Tree", -- TODO: German translation missing !!!!
    --["No-Healing Debuff!"] = "No-Healing Debuff!", -- TODO: German translation missing !!!!
    --["NO HEAL DEBUFF"] = "NO HEAL\nDEBUFF", -- TODO: German translation missing !!!!
    ["Lightning"] = "Blitz",
    --["Lightning on YOU"] = "Lightning on YOU", -- TODO: German translation missing !!!!
    --["Recently Saved!"] = "Recently Saved!", -- TODO: German translation missing !!!!
})

-- Tracking Blinding Light and Aileron knockback seems too random to display on timers.

--------------------------------------------------------------------------------
-- Locals
--

local last_thorns = 0
local last_twirl = 0
local midphase = false
local myName
local CheckTwirlTimer = nil
local twirl_units = {}
local twirlCount = 0
local lightningCount = 0
local lightningSet = 1
--------------------------------------------------------------------------------
-- Initialization
--
function mod:OnBossEnable()
    Print(("Module %s loaded"):format(mod.ModuleName))
    Apollo.RegisterEventHandler("RC_UnitCreated", "OnUnitCreated", self)
    Apollo.RegisterEventHandler("RC_UnitDestroyed", "OnUnitDestroyed", self)
    Apollo.RegisterEventHandler("RC_UnitStateChanged", "OnUnitStateChanged", self)
    Apollo.RegisterEventHandler("SPELL_CAST_START", "OnSpellCastStart", self)
    Apollo.RegisterEventHandler("DEBUFF_APPLIED", "OnDebuffApplied", self)
    Apollo.RegisterEventHandler("DEBUFF_REMOVED", "OnDebuffRemoved", self)
    Apollo.RegisterEventHandler("RAID_WIPE", "OnReset", self)
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:OnReset()
    last_thorns = 0
    last_twirl = 0
    midphase = false
    if CheckTwirlTimer then
        self:CancelTimer(CheckTwirlTimer)
    end
    twirl_units = {}
    twirlCount = 0
	lightningCount = 0
	lightningSet = 1
    core:StopBar("THORN")
    core:StopBar("MIDEND")
    core:StopBar("MIDPHASE")
    core:StopBar("TWIRL")
end

function mod:OnUnitCreated(unit, sName)
    local eventTime = GameLib.GetGameTime()
    if sName == self.L["Wild Brambles"] and eventTime > last_thorns + 1 and eventTime + 16 < midphase_start then
        last_thorns = eventTime
        twirlCount = twirlCount + 1
        core:AddBar("THORN", self.L["Thorns"], 15)
        if twirlCount == 1 then
            core:AddBar("TWIRL", self.L["Twirl"], 15)
        elseif twirlCount % 2 == 1 then
            core:AddBar("TWIRL", self.L["Twirl"], 15)
        end
    elseif not midphase and sName == self.L["[DS] e395 - Air - Tornado"] then
        midphase = true
        twirlCount = 0
        midphase_start = eventTime + 115
        core:AddBar("MIDEND", self.L["Midphase ending"], 35)
        core:AddBar("THORN", self.L["Thorns"], 35)
        core:AddBar("Lifekeep", self.L["Next Healing Tree"], 35)
    elseif sName == self.L["Life Force"] and mod:GetSetting("LineLifeOrbs") then
        core:AddPixie(unit:GetId(), 2, unit, nil, "Blue", 10, 40, 0)
    elseif sName == self.L["Lifekeeper"] then
        if mod:GetSetting("LineHealingTrees") then
            core:AddPixie(unit:GetId(), 1, GameLib.GetPlayerUnit(), unit, "Yellow", 5, 10, 10)
        end
        core:AddUnit(unit)
        core:AddBar("Lifekeep", self.L["Next Healing Tree"], 30, mod:GetSetting("SoundHealingTree"))
    end
end

function mod:OnUnitDestroyed(unit, sName)
    local eventTime = GameLib.GetGameTime()
    if midphase and sName == self.L["[DS] e395 - Air - Tornado"] then
        midphase = false
        core:AddBar("MIDPHASE", self.L["Middle Phase"], 90, mod:GetSetting("SoundMidphase"))
    elseif sName == self.L["Life Force"] then
        core:DropPixie(unit:GetId())
    elseif sName == self.L["Lifekeeper"] then
        core:DropPixie(unit:GetId())
    end
end

function mod:OnDebuffApplied(unitName, splId, unit)
    local eventTime = GameLib.GetGameTime()
    local splName = GameLib.GetSpell(splId):GetName()
    if splId == 70440 then -- Twirl
        if unitName == myName and mod:GetSetting("OtherTwirlWarning") then
            core:AddMsg("TWIRL", self.L["TWIRL ON YOU!"], 5, mod:GetSetting("SoundTwirl", "Inferno"))
        end

        if mod:GetSetting("OtherTwirlPlayerMarkers") then
            core:MarkUnit(unit, nil, self.L["Twirl"]:upper())
        end
        core:AddUnit(unit)
        twirl_units[unitName] = unit
        if not CheckTwirlTimer then
            CheckTwirlTimer = self:ScheduleRepeatingTimer("CheckTwirlTimer", 1)
        end
    elseif splName == "Life Force Shackle" then
        if mod:GetSetting("OtherNoHealDebuffPlayerMarkers") then
            core:MarkUnit(unit, nil, self.L["NO HEAL DEBUFF"])
        end
        if unitName == strMyName and mod:GetSetting("OtherNoHealDebuff") then
            core:AddMsg("NOHEAL", self.L["No-Healing Debuff!"], 5, mod:GetSetting("SoundNoHealDebuff", "Alarm"))
        end
    elseif splName == "Lightning Strike" then
        if unitName == strMyName then
            core:AddMsg("LIGHTNING", self.L["Lightning on YOU"], 5, mod:GetSetting("SoundLightning", "RunAway"))
        end

		--modifications:

		lightningCount = lightningCount + 1
		
		if mod:GetSetting("OtherLightningMarkers") then
			if lightningCount <= 2 then
            	core:MarkUnit(unit, nil, "1")
			else
				core:MarkUnit(unit, nil, "2")
			end
        end
		
		if lightningCount >= 4 then
			lightningSet = lightningSet + 1
			lightningCount = 0
		end
    end
end

function mod:OnDebuffRemoved(unitName, splId, unit)
    local splName = GameLib.GetSpell(splId):GetName()
    if splId == 70440 then
        core:RemoveUnit(unit:GetId())
		core:DropMark(unit:GetId())
    elseif splName == "Life Force Shackle" then
        core:DropMark(unit:GetId())
    elseif splName == "Lightning Strike" then
        core:DropMark(unit:GetId())
    end
end

function mod:OnSpellCastStart(unitName, castName, unit)
    local eventTime = GameLib.GetGameTime()
    if unitName == self.L["Visceralus"] and castName == self.L["Blinding Light"] and mod:GetSetting("OtherBlindingLight") then
        local playerUnit = GameLib.GetPlayerUnit()
        if self:GetDistanceBetweenUnits(unit, playerUnit) < 33 then
            core:AddMsg("BLIND", self.L["Blinding Light"], 5, mod:GetSetting("SoundBlindingLight", "Beware"))
        end
    end
end

function mod:CheckTwirlTimer()
    for unitName, unit in pairs(twirl_units) do
        if unit and unit:GetBuffs() then
            local bUnitHasTwirl = false
            local debuffs = unit:GetBuffs().arHarmful
            for _, debuff in pairs(debuffs) do
                if debuff.splEffect:GetId() == 70440 then -- the Twirl ability
                    bUnitHasTwirl = true
                end
            end
            if not bUnitHasTwirl then
                -- else, if the debuff is no longer present, no need to track anymore.
                core:DropMark(unit:GetId())
                core:RemoveUnit(unit:GetId())
                twirl_units[unitName] = nil
            end
        end
    end
end

function mod:OnUnitStateChanged(unit, bInCombat, sName)
    if unit:GetType() == "NonPlayer" then
        local eventTime = GameLib.GetGameTime()
        local playerUnit = GameLib.GetPlayerUnit()
        myName = playerUnit:GetName()

        if sName == self.L["Aileron"] then
            core:AddUnit(unit)
            if mod:GetSetting("LineCleaveAileron") then
                core:AddPixie(unit:GetId(), 2, unit, nil, "Red", 10, 30, 0)
            end
        elseif sName == self.L["Visceralus"] then
            core:AddUnit(unit)
            core:WatchUnit(unit)

            last_thorns = 0
            last_twirl = 0
            twirl_units = {}
            CheckTwirlTimer = nil
            midphase = false
            midphase_start = eventTime + 90
            twirlCount = 0

            core:AddBar("MIDPHASE", self.L["Middle Phase"], 90, mod:GetSetting("SoundMidphase"))
            core:AddBar("THORN", self.L["Thorns"], 20)
        end
    end
end
