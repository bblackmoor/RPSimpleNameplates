-- Simple Nameplates: original visibility and deferred frame/plate restoration.
local _, ns = ...
local Cap = ns.PresentationCapabilities
local GetContext = ns.WorldContext.Get
local SetShownSafe = ns.NameplateFrames.SetShownSafe
local Text = ns.NameplateText
local Periodic = ns.PeriodicWork
local pendingFrames = setmetatable({}, {__mode = "k"})
local pendingPlates = setmetatable({}, {__mode = "k"})
local Request, RequestPlate
local function RetryFrame(frame)
    if Request(frame, GetContext()) then
        if ns.RefreshRestoredNameplate then ns.RefreshRestoredNameplate(frame) end
        return
    end
    return 0.25
end
local function RetryPlate(plate)
    local context = GetContext()
    if RequestPlate(plate, context) then
        local frame = Cap.SafeField(plate, "UnitFrame", context)
        if frame and ns.RefreshRestoredNameplate then ns.RefreshRestoredNameplate(frame) end
    elseif pendingPlates[plate] then return 0.25 end
end
local function DeferFrame(frame)
    Periodic.Schedule("restoration frame", frame, RetryFrame, 0.25)
end
local function DeferPlate(plate)
    Periodic.Schedule("restoration plate", plate, RetryPlate, 0.25)
end
-- Cast bars, selection highlights and classification badges stay Blizzard-driven.
local visibilityKeys = {"name", "HealthBarsContainer", "castBarAnchor"}

local unpackValues = unpack or table.unpack
local nameProperties = {
    {"GetFont", "SetFont"}, {"GetTextColor", "SetTextColor"},
    {"GetVertexColor", "SetVertexColor"}, {"GetShadowColor", "SetShadowColor"},
    {"GetShadowOffset", "SetShadowOffset"}, {"GetJustifyH", "SetJustifyH"},
}

-- Only read presentation data. Native health/heal-prediction updates must run
-- from Blizzard's own events, never from this addon's restoration stack.
local function ReadValues(region, method, context, ...)
    local getter = Cap.SafeField(region, method, context)
    if type(getter) ~= "function" then return nil end
    local values = {pcall(getter, region, ...)}
    if not values[1] then return nil end
    table.remove(values, 1)
    for index = 1, #values do
        values[index] = ns.AccessibleValue(values[index])
        if values[index] == nil then return nil end
    end
    return #values > 0 and values or nil
end

local function CaptureNativePresentation(frame, assessment, context)
    local original = {name = {}}
    local name = assessment.name
    for _, property in ipairs(nameProperties) do
        original.name[property[2]] = ReadValues(name, property[1], context)
    end
    local count = ns.AccessibleNumber(Cap.ReadRegion(name, "GetNumPoints", context))
    if count then
        local points = {}
        for index = 1, count do
            local point = ReadValues(name, "GetPoint", context, index)
            if not point then points = nil; break end
            points[#points + 1] = point
        end
        original.points = points
    end
    original.barColor = ReadValues(assessment.healthBar, "GetStatusBarColor", context)
    frame.RPSNOriginalPresentation = original
end

local function RestoreNativePresentation(frame, assessment, context, removedUnit)
    local original = frame.RPSNOriginalPresentation
    if not original then return end
    local name = frame.RPSNOriginalName or assessment.name
    if name then
        for _, property in ipairs(nameProperties) do
            local values = original.name[property[2]]
            if values then name[property[2]](name, unpackValues(values)) end
        end
        if original.points then
            name:ClearAllPoints()
            for _, point in ipairs(original.points) do name:SetPoint(unpackValues(point)) end
        end
        local unit = ns.AccessibleValue(frame.unit)
        if removedUnit and unit == removedUnit then
            name:SetText("")
        elseif type(unit) == "string" and UnitName then
            -- SetText accepts a secret name directly; do not inspect it.
            name:SetText(UnitName(unit))
        end
    end
    if frame.RPSNOriginalHealthBar and original.barColor then
        frame.RPSNOriginalHealthBar:SetStatusBarColor(unpackValues(original.barColor))
    end
end

local function Capture(frame, assessment, context)
    if frame.RPSNOriginalVisibility then return end
    CaptureNativePresentation(frame, assessment, context)
    local values = {}
    for _, key in ipairs(visibilityKeys) do
        values[key] = ns.AccessibleBoolean(Cap.ReadRegion(frame[key], "IsShown", context))
    end
    values.healthBar = ns.AccessibleBoolean(Cap.ReadRegion(assessment.healthBar, "IsShown", context))
    values.barAlpha = ns.AccessibleNumber(Cap.ReadRegion(assessment.healthBar, "GetAlpha", context))
    values.containerAlpha = ns.AccessibleNumber(Cap.ReadRegion(frame.HealthBarsContainer, "GetAlpha", context))
    values.nameAlpha = ns.AccessibleNumber(Cap.ReadRegion(assessment.name, "GetAlpha", context))
    frame.RPSNOriginalVisibility = values
    frame.RPSNOriginalName = assessment.name
    frame.RPSNOriginalUnit = ns.AccessibleValue(frame.unit)
    frame.RPSNOriginalHealthBar = assessment.healthBar
    frame.RPSNOriginalHealthBarsContainer = frame.HealthBarsContainer
end

local function RestoreAccessibleFrame(frame, assessment, context, removedUnit)
    frame.RPSNThreatStatus = nil
    if frame.RPSNThreatText then
        frame.RPSNThreatText:SetText("")
        frame.RPSNThreatText:Hide()
    end
    if frame.RPSNFullTitleText then frame.RPSNFullTitleText:SetText(""); frame.RPSNFullTitleText:Hide() end
    frame.RPSNFullTitleAvailable = nil
    Text.RestoreNameDisplay(frame, context, assessment)
    if frame.RPSNInterruptibleHighlight then frame.RPSNInterruptibleHighlight.frame:Hide() end
    Text.RestoreOriginalBarHeight(frame, assessment.healthBar, context, assessment)
    ns.NameplateFrames.RestoreBarArtwork(frame, context)
    ns.NameplateFrames.RestoreBarWidth(frame, assessment)
    ns.NameplateFrames.RestoreSizeAnchors(frame, context)
    local original = frame.RPSNOriginalVisibility or {}
    for _, key in ipairs(visibilityKeys) do
        local region = frame[key]
        if key == "name" then region = frame.RPSNOriginalName end
        if key == "HealthBarsContainer" then region = frame.RPSNOriginalHealthBarsContainer end
        if original[key] ~= nil then SetShownSafe(region, original[key], context) end
    end
    if original.healthBar ~= nil then SetShownSafe(frame.RPSNOriginalHealthBar, original.healthBar, context) end
    if original.barAlpha ~= nil and frame.RPSNOriginalHealthBar then frame.RPSNOriginalHealthBar:SetAlpha(original.barAlpha) end
    if original.containerAlpha ~= nil and frame.RPSNOriginalHealthBarsContainer then
        frame.RPSNOriginalHealthBarsContainer:SetAlpha(original.containerAlpha)
    end
    if original.nameAlpha ~= nil and frame.RPSNOriginalName then frame.RPSNOriginalName:SetAlpha(original.nameAlpha) end
    RestoreNativePresentation(frame, assessment, context, removedUnit)
    frame.RPSNNameStyle, frame.RPSNState, frame.RPSNPresentation, frame.RPSNEntityFacts = nil, nil, nil, nil
    frame.RPSNNameAppearancePending = nil
    frame.RPSNNameColorPending = nil
    frame.RPSNNameAlphaPending = nil
    frame.RPSNGeometryPending = nil
    frame.RPSNOriginalVisibility, frame.RPSNOriginalUnit, frame.RPSNOriginalPresentation = nil, nil, nil
    frame.RPSNOriginalHealthBar, frame.RPSNOriginalHealthBarsContainer = nil, nil
    frame.RPSNTitleVisibilityPending = nil
    frame.RPSNTitleDesiredRegion, frame.RPSNTitleDesired, frame.RPSNTitleVisibilityRetry = nil, nil, nil
    frame.RPSNOriginalName, frame.RPSNStyleSettings, frame.RPSNStyledCastBar = nil, nil, nil
end

Request = function(frame, context, removedUnit)
    context = context or GetContext()
    frame = ns.AccessibleValue(frame)
    if not frame then return true end
    local assessment = Cap.InspectFrame(frame, context)
    if not assessment.canAccess then
        pendingFrames[frame] = removedUnit or pendingFrames[frame] or true
        DeferFrame(frame)
        return false
    end
    if frame.RPSNRestoring then return false end
    local pending = pendingFrames[frame]
    if not removedUnit and type(pending) == "string" then removedUnit = pending end
    if not pending and not frame.RPSNState and not frame.RPSNNameStyle
        and not frame.RPSNOriginalVisibility then return true end
    frame.RPSNRestoring = true
    -- Blizzard updates can invoke our repair hooks or throw. Always release
    -- the reentry guard, including when caches were already cleared.
    local ok, err = pcall(RestoreAccessibleFrame, frame, assessment, context, removedUnit)
    frame.RPSNRestoring = nil
    if not ok then
        pendingFrames[frame] = removedUnit or true
        DeferFrame(frame)
        local message = tostring(ns.AccessibleValue(err) or "Unavailable restoration error")
        local previous = frame.RPSNRestoreError
        frame.RPSNRestoreError = message
        if message ~= previous and geterrorhandler then geterrorhandler()(message) end
        return false
    end
    pendingFrames[frame], frame.RPSNRestoreError = nil, nil
    Periodic.Cancel("restoration frame", frame)
    return true
end

RequestPlate = function(plate, context)
    context = context or GetContext()
    plate = ns.AccessibleValue(plate)
    if not plate then return true end
    if Cap.ObjectStatus(plate, context) ~= "accessible" then
        pendingPlates[plate] = true
        DeferPlate(plate)
        return false
    end
    local frame, readable = Cap.SafeField(plate, "UnitFrame", context)
    if readable == false then pendingPlates[plate] = true; DeferPlate(plate); return false end
    pendingPlates[plate] = nil
    Periodic.Cancel("restoration plate", plate)
    return Request(frame, context)
end

ns.NameplateRestoration = {
    Capture = Capture, Request = Request, RequestPlate = RequestPlate,
    Cancel = function(frame) pendingFrames[frame] = nil; Periodic.Cancel("restoration frame", frame) end,
    IsPending = function(frame) return pendingFrames[frame] ~= nil end,
}
