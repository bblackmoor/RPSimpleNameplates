-- Simple Nameplates: optional Total RP 3 integration.
--
-- This file is the single boundary between Simple Nameplates and TRP3. Future
-- display options should normalize public TRP3 profile data here rather than
-- exposing TRP3's data structures throughout the nameplate code.

local _, ns = ...

local TRP3 = {}
local ROLEPLAY_STATUS_OUT_OF_CHARACTER = 2
local ROLEPLAY_NAME_LIMIT = 32
local SHORT_TITLE_LIMIT = 20
local FULL_TITLE_LIMIT = 48
local callbacksRegistered = false

local function CleanText(value)
    if type(value) ~= "string" then return nil end
    value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then return nil end
    return value
end

local function Utf8Prefix(value, characterLimit)
    local byteIndex, characters, lastByte = 1, 0, 0
    local byteLength = #value
    while byteIndex <= byteLength and characters < characterLimit do
        local firstByte = value:byte(byteIndex)
        local width = 1
        if firstByte >= 0xF0 then
            width = 4
        elseif firstByte >= 0xE0 then
            width = 3
        elseif firstByte >= 0xC0 then
            width = 2
        end
        if byteIndex + width - 1 > byteLength then width = 1 end
        lastByte = byteIndex + width - 1
        byteIndex = byteIndex + width
        characters = characters + 1
    end
    return value:sub(1, lastByte), byteIndex <= byteLength
end

local function LimitText(value, characterLimit)
    value = CleanText(value)
    if not value then return nil end
    local prefix, truncated = Utf8Prefix(value, characterLimit)
    if not truncated then return value end
    prefix = Utf8Prefix(value, characterLimit - 1)
    prefix = prefix:gsub("%s+$", "")
    return prefix .. "…"
end

function TRP3.IsAvailable()
    return type(TRP3_API) == "table"
        and type(TRP3_API.utils) == "table"
        and type(TRP3_API.utils.str) == "table"
        and type(TRP3_API.utils.str.getUnitID) == "function"
        and type(TRP3_API.register) == "table"
        and type(TRP3_API.register.getUnitIDCurrentProfileSafe) == "function"
end

function TRP3.IsEnabled()
    return ns.GetTRP3Enabled() == true
end

function TRP3.ShouldDisplayProfileInfo()
    return TRP3.IsEnabled() and TRP3.IsAvailable()
end

function TRP3.GetKnownProfile(unitToken)
    if not TRP3.ShouldDisplayProfileInfo() then return nil end

    local characterID = TRP3_API.utils.str.getUnitID(unitToken)
    if not characterID then return nil end

    local profile = TRP3_API.register.getUnitIDCurrentProfileSafe(characterID)
    if type(profile) ~= "table" or next(profile) == nil then return nil end
    return profile, characterID
end

function TRP3.GetDisplayInfo(unitToken)
    local profile, characterID = TRP3.GetKnownProfile(unitToken)
    if not profile then return nil end

    local characteristics = type(profile.characteristics) == "table" and profile.characteristics or {}
    local character = type(profile.character) == "table" and profile.character or {}
    local firstName = CleanText(characteristics.FN)
    local lastName = CleanText(characteristics.LN)
    local roleplayingName

    if firstName and lastName then
        roleplayingName = firstName .. " " .. lastName
    elseif firstName then
        roleplayingName = firstName
    elseif lastName then
        local unitName = ns.AccessibleValue(UnitName(unitToken))
        roleplayingName = unitName and (unitName .. " " .. lastName) or lastName
    end

    return {
        characterID = characterID,
        roleplayingName = LimitText(roleplayingName, ROLEPLAY_NAME_LIMIT),
        shortTitle = LimitText(characteristics.TI, SHORT_TITLE_LIMIT),
        fullTitle = LimitText(characteristics.FT, FULL_TITLE_LIMIT),
        isOutOfCharacter = character.RP == ROLEPLAY_STATUS_OUT_OF_CHARACTER,
    }
end

function TRP3.Refresh()
    if ns.RefreshNameplateData then ns.RefreshNameplateData({name = true})
    elseif ns.RefreshAll then ns.RefreshAll() end
end

function TRP3.RegisterCallbacks()
    if callbacksRegistered or not TRP3.IsAvailable() then return end
    if type(TRP3_API.RegisterCallback) ~= "function"
        or type(TRP3_Addon) ~= "table"
        or type(TRP3_Addon.Events) ~= "table"
        or not TRP3_Addon.Events.REGISTER_DATA_UPDATED then
        return
    end

    TRP3_API.RegisterCallback(
        TRP3_Addon,
        TRP3_Addon.Events.REGISTER_DATA_UPDATED,
        TRP3.Refresh
    )
    callbacksRegistered = true
end

ns.TRP3 = TRP3

