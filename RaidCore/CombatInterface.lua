----------------------------------------------------------------------------------------------------
-- Client Lua Script for RaidCore Addon on WildStar Game.
--
-- Copyright (C) 2015 RaidCore
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
--
-- Combat Interface object have the responsability to catch carbine events and interpret them.
-- Thus result will be send to upper layer, trough ManagerCall function. Every events are logged.
--
----------------------------------------------------------------------------------------------------
require "Apollo"
require "GameLib"
require "ApolloTimer"
require "ChatSystemLib"
require "Spell"
require "GroupLib"

local RaidCore = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:GetAddon("RaidCore")
local LogPackage = Apollo.GetPackage("Log-1.0").tPackage
local Log = LogPackage:CreateNamespace("CombatInterface")
local CombatInterface = {}

----------------------------------------------------------------------------------------------------
-- Copy of few objects to reduce the cpu load.
-- Because all local objects are faster.
----------------------------------------------------------------------------------------------------
local RegisterEventHandler = Apollo.RegisterEventHandler
local RemoveEventHandler = Apollo.RemoveEventHandler
local GetGameTime = GameLib.GetGameTime
local GetPlayerUnit = GameLib.GetPlayerUnit
local GetUnitById = GameLib.GetUnitById
local GetSpell = GameLib.GetSpell
local next, string, pcall  = next, string, pcall
local tinsert = table.insert

----------------------------------------------------------------------------------------------------
-- Constants.
----------------------------------------------------------------------------------------------------
-- Sometimes Carbine have inserted some no-break-space, for fun.
-- Behavior seen with French language.
local NO_BREAK_SPACE = string.char(194, 160)
local SCAN_PERIOD = 0.1 -- in seconds.
-- Array with chat permission.
local CHANNEL_HANDLERS = {
    [ChatSystemLib.ChatChannel_Say] = nil,
    [ChatSystemLib.ChatChannel_NPCSay] = "OnNPCSay",
    [ChatSystemLib.ChatChannel_NPCYell] = "OnNPCYell",
    [ChatSystemLib.ChatChannel_NPCWhisper] = "OnNPCWhisper",
    [ChatSystemLib.ChatChannel_Datachron] = "OnDatachron",
}
local SPELLID_BLACKLISTED = {
    [60883] = "Irradiate", -- On war class.
    [76652] = "Surge Focus Drain", -- On arcanero class.
    [72651] = "Surge Focus Drain", -- On arcanero class.
}
-- State Machine.
local INTERFACE__DISABLE = 1
local INTERFACE__DETECTCOMBAT = 2
local INTERFACE__DETECTALL = 3
local INTERFACE__LIGHTENABLE = 4
local INTERFACE__FULLENABLE = 5
local INTERFACE_STATES = {
    ["Disable"] = INTERFACE__DISABLE,
    ["DetectCombat"] = INTERFACE__DETECTCOMBAT,
    ["DetectAll"] = INTERFACE__DETECTALL,
    ["LightEnable"] = INTERFACE__LIGHTENABLE,
    ["FullEnable"] = INTERFACE__FULLENABLE,
}

----------------------------------------------------------------------------------------------------
-- Privates variables.
----------------------------------------------------------------------------------------------------
local _tCombatManager = nil
local _bDetectAllEnable = false
local _bUnitInCombatEnable = false
local _bRunning = false
local _tScanTimer = nil
local _tAllUnits = {}
local _tTrackedUnits = {}
local _tMembers = {}

----------------------------------------------------------------------------------------------------
-- Privates functions: Log
----------------------------------------------------------------------------------------------------
local function ManagerCall(sMethod, ...)
    -- Trace all call to upper layer for debugging purpose.
    Log:Add(sMethod, ...)
    -- Retrieve callback function.
    local fMethod = nil
    if _tCombatManager then
        fMethod = _tCombatManager[sMethod]
    end
    -- Protected call.
    if fMethod then
        local s, sErrMsg = pcall(fMethod, _tCombatManager, ...)
        if not s then
            --@alpha@
            Print(sMethod .. ": " .. sErrMsg)
            --@end-alpha@
            Log:Add("ERROR", sErrMsg)
        end
    else
        Log:Add("No callback found.")
    end
end

local function ExtraLog2Text(k, nRefTime, tParam)
    local sResult = ""
    if k == "ERROR" then
        sResult = tParam[1]
    elseif k == "OnDebuffAdd" or k == "OnBuffAdd" then
        local sSpellName = GetSpell(tParam[2]):GetName():gsub(NO_BREAK_SPACE, " ")
        local sFormat = "Id=%u SpellName='%s' SpellId=%u Stack=%d"
        sResult = sFormat:format(tParam[1], sSpellName, tParam[2], tParam[3])
    elseif k == "OnDebuffRemove" or k == "OnBuffRemove" then
        local sSpellName = GetSpell(tParam[2]):GetName():gsub(NO_BREAK_SPACE, " ")
        local sFormat = "Id=%u SpellName='%s' SpellId=%u"
        sResult = sFormat:format(tParam[1], sSpellName, tParam[2])
    elseif k == "OnDebuffUpdate" or k == "OnBuffUpdate" then
        local sSpellName = GetSpell(tParam[2]):GetName():gsub(NO_BREAK_SPACE, " ")
        local sFormat = "Id=%u SpellName='%s' SpellId=%u OldStack=%d NewStack=%d"
        sResult = sFormat:format(tParam[1], sSpellName, tParam[2], tParam[3], tParam[4])
    elseif k == "OnCastStart" then
        local nCastEndTime = tParam[3] - nRefTime
        local sFormat = "Id=%u CastName='%s' CastEndTime=%.3f"
        sResult = sFormat:format(tParam[1], tParam[2], nCastEndTime)
    elseif k == "OnCastEnd" then
        local nCastEndTime = tParam[4] - nRefTime
        local sFormat = "Id=%u CastName='%s' IsInterrupted=%s CastEndTime=%.3f"
        sResult = sFormat:format(tParam[1], tParam[2], tostring(tParam[3]), nCastEndTime)
    elseif k == "OnUnitCreated" then
        local sFormat = "Id=%u Unit='%s'"
        sResult = sFormat:format(tParam[1], tParam[3])
    elseif k == "OnUnitDestroyed" then
        local sFormat = "Id=%u Unit='%s'"
        sResult = sFormat:format(tParam[1], tParam[3])
    elseif k == "OnEnteredCombat" then
        local sFormat = "Id=%u Unit='%s' InCombat=%s"
        sResult = sFormat:format(tParam[1], tParam[3], tostring(tParam[4]))
    elseif k == "OnNPCSay" or k == "OnNPCYell" or k == "OnNPCWhisper" or k == "OnDatachron" then
        local sFormat = "sMessage='%s'"
        sResult = sFormat:format(tParam[1])
    elseif k == "TrackThisUnit" or k == "UnTrackThisUnit" then
        sResult = ("Id='%s'"):format(tParam[1])
    elseif k == "WARNING tUnit reference changed" then
        sResult = ("OldId=%u NewId=%u"):format(tParam[1], tParam[2])
    end
    return sResult
end
Log:SetExtra2String(ExtraLog2Text)

----------------------------------------------------------------------------------------------------
-- Privates functions: unit processing
----------------------------------------------------------------------------------------------------
local function GetAllBuffs(tUnit)
    local r = {}
    if tUnit then
        local tAllBuffs = tUnit:GetBuffs()
        if tAllBuffs then
            for sType, tBuffs in next, tAllBuffs do
                r[sType] = {}
                for _,obj in next, tBuffs do
                    local nSpellId = obj.splEffect:GetId()
                    if nSpellId and not SPELLID_BLACKLISTED[nSpellId] then
                        r[sType][obj.idBuff] = {
                            nCount = obj.nCount,
                            nSpellId = nSpellId,
                        }
                    end
                end
            end
        end
    end
    return r
end

local function TrackThisUnit(nId)
    local tUnit = GetUnitById(nId)
    if not _tTrackedUnits[nId] and tUnit then
        Log:Add("TrackThisUnit", nId)
        local tAllBuffs = GetAllBuffs(tUnit)
        _tAllUnits[nId] = true
        _tTrackedUnits[nId] = {
            tUnit = tUnit,
            sName = tUnit:GetName():gsub(NO_BREAK_SPACE, " "),
            nId = nId,
            tBuffs = tAllBuffs["arBeneficial"] or {},
            tDebuffs = {},
            bIsACharacter = false,
            tCast = {
                bCasting = false,
                sCastName = "",
                nCastEndTime = 0,
                bSuccess = false,
            },
        }
    end
end

local function UnTrackThisUnit(nId)
    if _tTrackedUnits[nId] then
        Log:Add("UnTrackThisUnit", nId)
        _tTrackedUnits[nId] = nil
    end
end

local function ProcessAllBuffs(tMyUnit)
    local tAllBuffs = GetAllBuffs(tMyUnit.tUnit)
    local bProcessDebuffs = tMyUnit.bIsACharacter
    local bProcessBuffs = not bProcessDebuffs
    local nId = tMyUnit.nId

    local tNewDebuffs = tAllBuffs["arHarmful"]
    local tDebuffs = tMyUnit.tDebuffs
    if bProcessDebuffs and tNewDebuffs then
        for nIdBuff,current in next, tDebuffs do
            if tNewDebuffs[nIdBuff] then
                local tNew = tNewDebuffs[nIdBuff]
                if tNew.nCount ~= current.nCount then
                    local nOld = current.nCount
                    tDebuffs[nIdBuff].nCount = tNew.nCount
                    ManagerCall("OnDebuffUpdate", tMyUnit.tUnit, current.nSpellId, nOld, tNew.nCount)
                end
                -- Remove this entry for second loop.
                tNewDebuffs[nIdBuff] = nil
            else
                tDebuffs[nIdBuff] = nil
                ManagerCall("OnDebuffRemove", tMyUnit.tUnit, current.nSpellId)
            end
        end
        for nIdBuff,tNew in next, tNewDebuffs do
            tDebuffs[nIdBuff] = tNew
            ManagerCall("OnDebuffAdd", tMyUnit.tUnit, tNew.nSpellId, tNew.nCount)
        end
    end

    local tNewBuffs = tAllBuffs["arBeneficial"]
    local tBuffs = tMyUnit.tBuffs
    if bProcessBuffs and tNewBuffs then
        for nIdBuff,current in next, tBuffs do
            if tNewBuffs[nIdBuff] then
                local tNew = tNewBuffs[nIdBuff]
                if tNew.nCount ~= current.nCount then
                    local nOld = current.nCount
                    tBuffs[nIdBuff].nCount = tNew.nCount
                    ManagerCall("OnBuffUpdate", tMyUnit.tUnit, current.nSpellId, nOld, tNew.nCount)
                end
                -- Remove this entry for second loop.
                tNewBuffs[nIdBuff] = nil
            else
                tBuffs[nIdBuff] = nil
                ManagerCall("OnBuffRemove", tMyUnit.tUnit, current.nSpellId)
            end
        end
        for nIdBuff, tNew in next, tNewBuffs do
            tBuffs[nIdBuff] = tNew
            ManagerCall("OnBuffAdd", tMyUnit.tUnit, tNew.nSpellId, tNew.nCount)
        end
    end
end

local function UpdateMemberList()
    for i = 1, GroupLib.GetMemberCount() do
        local tUnit = GroupLib.GetUnitForGroupMember(i)
        -- A Friend out of range have a tUnit object equal to nil.
        -- And if you have the tUnit object, the IsValid flag can change.
        if tUnit then
            local sName = tUnit:GetName():gsub(NO_BREAK_SPACE, " ")
            if not _tMembers[sName] then
                local tAllBuffs = GetAllBuffs(tUnit)
                _tMembers[sName] = {
                    tUnit = tUnit,
                    nId = tUnit:GetId(),
                    tDebuffs = tAllBuffs["arHarmful"] or {},
                    tBuffs = {},
                    bIsACharacter = true,
                }
            elseif _tMembers[sName].tUnit ~= tUnit then
                local nOldId = _tMembers[sName].nId
                local nNewId = tUnit:GetId()
                Log:Add("WARNING tUnit reference changed", nOldId, nNewId)
                _tMembers[sName].tUnit = tUnit
                _tMembers[sName].nId = nNewId
            end
        end
    end
end

----------------------------------------------------------------------------------------------------
-- Privates functions: State Machine
----------------------------------------------------------------------------------------------------
local function UnitInCombatActivate(bEnable)
    if _bUnitInCombatEnable == false and bEnable == true then
        RegisterEventHandler("UnitEnteredCombat", "OnEnteredCombat", CombatInterface)
    elseif _bUnitInCombatEnable == true and bEnable == false then
        RemoveEventHandler("UnitEnteredCombat", CombatInterface)
    end
    _bUnitInCombatEnable = bEnable
end

local function UnitScanActivate(bEnable)
    if _bDetectAllEnable == false and bEnable == true then
        RegisterEventHandler("UnitCreated", "OnUnitCreated", CombatInterface)
        RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", CombatInterface)
    elseif _bDetectAllEnable == true and bEnable == false then
        RemoveEventHandler("UnitCreated", CombatInterface)
        RemoveEventHandler("UnitDestroyed", CombatInterface)
    end
    _bDetectAllEnable = bEnable
end

local function FullActivate(bEnable)
    if _bRunning == false and bEnable == true then
        LogPackage:SetRefTime(GetGameTime())
        RegisterEventHandler("ChatMessage", "OnChatMessage", CombatInterface)
        _tScanTimer:Start()
    elseif _bRunning == true and bEnable == false then
        _tScanTimer:Stop()
        RemoveEventHandler("ChatMessage", CombatInterface)
        LogPackage:NextBuffer()
        -- Clear private data.
        _tTrackedUnits = {}
        _tAllUnits = {}
        _tMembers = {}
    end
    _bRunning = bEnable
end

local function InterfaceSwitch(to)
    if to == INTERFACE__DISABLE then
        UnitInCombatActivate(false)
        UnitScanActivate(false)
        FullActivate(false)
    elseif to == INTERFACE__DETECTCOMBAT then
        UnitInCombatActivate(true)
        UnitScanActivate(false)
        FullActivate(false)
    elseif to == INTERFACE__DETECTALL then
        UnitInCombatActivate(true)
        UnitScanActivate(true)
        FullActivate(false)
    elseif to == INTERFACE__LIGHTENABLE then
        UnitInCombatActivate(true)
        UnitScanActivate(false)
        FullActivate(true)
    elseif to == INTERFACE__FULLENABLE then
        UnitInCombatActivate(true)
        UnitScanActivate(true)
        FullActivate(true)
    end
end

----------------------------------------------------------------------------------------------------
-- Relations between RaidCore and CombatInterface.
----------------------------------------------------------------------------------------------------
function RaidCore:CombatInterface_Init(class)
    assert(_tCombatManager == nil)

    _tCombatManager = class
    _tAllUnits = {}
    _tTrackedUnits = {}
    _tMembers = {}
    _tScanTimer = ApolloTimer.Create(SCAN_PERIOD, true, "OnScanUpdate", CombatInterface)

    InterfaceSwitch(INTERFACE__DISABLE)
end

function RaidCore:CombatInterface_Activate(sState)
    local nState = INTERFACE_STATES[sState]
    if nState then
        InterfaceSwitch(nState)
    end
end

function RaidCore:CombatInterface_Untrack(nId)
    UnTrackThisUnit(nId)
end

function RaidCore:CombatInterface_Track(nId)
    TrackThisUnit(nId)
    return _tTrackedUnits[nId]
end

function RaidCore:CombatInterface_GetTrackedById(nId)
    return _tTrackedUnits[nId]
end

----------------------------------------------------------------------------------------------------
-- Combat Interface layer.
----------------------------------------------------------------------------------------------------
function CombatInterface:OnEnteredCombat(tUnit, bInCombat)
    local nId = tUnit:GetId()
    local sName = string.gsub(tUnit:GetName(), NO_BREAK_SPACE, " ")
    if not tUnit:IsInYourGroup() and nId ~= GetPlayerUnit():GetId() then
        if not _tAllUnits[nId] then
            _tAllUnits[nId] = true
        end
    end
    ManagerCall("OnEnteredCombat", nId, tUnit, sName, bInCombat)
end

function CombatInterface:OnUnitCreated(tUnit)
    local nId = tUnit:GetId()
    local sName = tUnit:GetName():gsub(NO_BREAK_SPACE, " ")

    if not tUnit:IsInYourGroup() and nId ~= GetPlayerUnit():GetId() then
        if not _tAllUnits[nId] then
            _tAllUnits[nId] = true
            ManagerCall("OnUnitCreated", nId, tUnit, sName)
        end
    end
end

function CombatInterface:OnUnitDestroyed(tUnit)
    local nId = tUnit:GetId()
    if _tAllUnits[nId] then
        _tAllUnits[nId] = nil
        UnTrackThisUnit(nId)
        local sName = tUnit:GetName():gsub(NO_BREAK_SPACE, " ")
        ManagerCall("OnUnitDestroyed", nId, tUnit, sName)
    end
end

function CombatInterface:OnScanUpdate()
    UpdateMemberList()
    for sName,tMember in next, _tMembers do
        if tMember.tUnit:IsValid() then
            local f, err = pcall(ProcessAllBuffs, tMember)
            if not f then
                Print(err)
            end
        end
    end

    for nId, data in next, _tTrackedUnits do
        if data.tUnit:IsValid() then
            -- Process buff tracking.
            local f, err = pcall(ProcessAllBuffs, data)
            if not f then
                Print(err)
            end

            -- Process cast tracking.
            local bCasting = data.tUnit:IsCasting()
            local nCurrentTime
            local sCastName
            local nCastDuration
            local nCastElapsed
            local nCastEndTime
            if bCasting then
                nCurrentTime = GetGameTime()
                sCastName = data.tUnit:GetCastName()
                nCastDuration = data.tUnit:GetCastDuration()
                nCastElapsed = data.tUnit:GetCastElapsed()
                nCastEndTime = nCurrentTime + (nCastDuration - nCastElapsed) / 1000
                -- Refresh needed if the function is called at the end of cast.
                -- Like that, previous data retrieved are valid.
                bCasting = data.tUnit:IsCasting()
            end
            if bCasting then
                sCastName = string.gsub(sCastName, NO_BREAK_SPACE, " ")
                if not data.tCast.bCasting then
                    -- New cast
                    data.tCast = {
                        bCasting = true,
                        sCastName = sCastName,
                        nCastEndTime = nCastEndTime,
                        bSuccess = false,
                    }
                    ManagerCall("OnCastStart", nId, sCastName, nCastEndTime)
                elseif data.tCast.bCasting then
                    if sCastName ~= data.tCast.sCastName then
                        -- New cast just after a previous one.
                        if data.tCast.bSuccess == false then
                            ManagerCall("OnCastEnd", nId, data.tCast.sCastName, false,
                            data.tCast.nCastEndTime)
                        end
                        data.tCast = {
                            bCasting = true,
                            sCastName = sCastName,
                            nCastEndTime = nCastEndTime,
                            bSuccess = false,
                        }
                        ManagerCall("OnCastStart", nId, sCastName, nCastEndTime)
                    elseif not data.tCast.bSuccess and nCastElapsed >= nCastDuration then
                        -- The have reached the end.
                        ManagerCall("OnCastEnd", nId, data.tCast.sCastName, false,
                        data.tCast.nCastEndTime)
                        data.tCast = {
                            bCasting = true,
                            sCastName = sCastName,
                            nCastEndTime = 0,
                            bSuccess = true,
                        }
                    end
                end
            elseif data.tCast.bCasting then
                if not data.tCast.bSuccess then
                    -- Let's compare with the nCastEndTime
                    local nThreshold = GetGameTime() + SCAN_PERIOD
                    local bIsFailed
                    if nThreshold < data.tCast.nCastEndTime then
                        bIsInterrupted = true
                    else
                        bIsInterrupted = false
                    end
                    ManagerCall("OnCastEnd", nId, data.tCast.sCastName, bIsInterrupted,
                    data.tCast.nCastEndTime)
                end
                data.tCast = {
                    bCasting = false,
                    sCastName = "",
                    nCastEndTime = 0,
                    bSuccess = false,
                }
            end
        end
    end
end

function CombatInterface:OnChatMessage(tChannelCurrent, tMessage)
    local nChannelType = tChannelCurrent:GetType()
    local sHandler = CHANNEL_HANDLERS[nChannelType]
    if sHandler then
        local sMessage = ""
        for _, tSegment in next, tMessage.arMessageSegments do
            sMessage = sMessage .. tSegment.strText:gsub(NO_BREAK_SPACE, " ")
        end
        ManagerCall(sHandler, sMessage)
    end
end
