-- Simple Nameplates: conservative frame/region access; no styling or world queries.
local _, ns = ...
local AccessibleValue, AccessibleBoolean = ns.AccessibleValue, ns.AccessibleBoolean
local GetContext = ns.WorldContext.Get

local function Inaccessible(value)
    return (issecretvalue and issecretvalue(value))
        or (canaccessvalue and not canaccessvalue(value))
end

local function ReadField(object, key) return object[key] end

local function Field(object, key)
    if Inaccessible(object) then return nil, false end
    if object == nil then return nil end
    local ok, value = pcall(ReadField, object, key)
    if ok and not Inaccessible(value) then return AccessibleValue(value), true end
    return nil, false
end

local function ObjectStatus(object, context)
    context = context or GetContext()
    if Inaccessible(object) then return "unknown" end
    if object == nil then return "missing" end
    local forbidden, readable = Field(object, "IsForbidden")
    if readable == false then return "unknown" end
    if forbidden ~= nil then
        if type(forbidden) ~= "function" then return "unknown" end
        local ok, result = pcall(forbidden, object)
        if not ok then return "unknown" end
        result = AccessibleBoolean(result)
        if result == true then return "forbidden" end
        if result ~= false then return "unknown" end
    end
    local protected, protectedReadable = Field(object, "IsProtected")
    if protectedReadable == false then return "unknown" end
    if protected ~= nil then
        if type(protected) ~= "function" then return "unknown" end
        local ok, result = pcall(protected, object)
        if not ok then return "unknown" end
        result = AccessibleBoolean(result)
        if result == nil then return "unknown" end
        if result and context.combatLockdown == true then return "restricted" end
        if result and context.combatLockdown == nil then return "unknown" end
    end
    return "accessible"
end

local function SafeField(object, key, context)
    context = context or GetContext()
    if ObjectStatus(object, context) ~= "accessible" then return nil end
    return Field(object, key)
end

local function InspectFrame(frame, context)
    context = context or GetContext()
    local result = { status = ObjectStatus(frame, context), canAccess = false }
    if result.status ~= "accessible" then return result end
    local unknownField
    local function InspectField(object, key)
        local value, readable = Field(object, key)
        if readable == false then unknownField = key end
        return value
    end
    local container = InspectField(frame, "HealthBarsContainer")
    local containerStatus = ObjectStatus(container, context)
    if containerStatus ~= "missing" and containerStatus ~= "accessible" then
        result.status, result.reason = containerStatus, "health-bar container"
        return result
    end
    local castContainer = InspectField(frame, "CastBarsContainer")
    local castContainerStatus = ObjectStatus(castContainer, context)
    if castContainerStatus ~= "missing" and castContainerStatus ~= "accessible" then
        result.status, result.reason = castContainerStatus, "cast-bar container"
        return result
    end
    local regions = {
        name = InspectField(frame, "name"),
        healthBar = InspectField(frame, "healthBar") or InspectField(container, "healthBar"),
        castBar = InspectField(frame, "castBar") or InspectField(frame, "CastBar")
            or InspectField(castContainer, "castBar"),
    }
    for key, region in pairs(regions) do
        local status = ObjectStatus(region, context)
        if status ~= "missing" and status ~= "accessible" then
            result.status, result.reason = status, key
            return result
        end
        result[key] = region
    end
    for _, key in ipairs({"Text", "RightText", "LeftText"}) do
        local status = ObjectStatus(InspectField(regions.healthBar, key), context)
        if status ~= "missing" and status ~= "accessible" then
            result.status, result.reason = status, "native health text: " .. key
            return result
        end
    end
    -- Remaining regions are touched by visibility, restoration, or drift repair.
    for _, key in ipairs({ "CastBar", "castBarAnchor", "classificationIndicator", "ClassificationFrame",
        "selectionHighlight", "SNPInsideName", "SNPFullTitleText", "SNPThreatText",
        "SNPOriginalHealthBar", "SNPOriginalHealthBarsContainer", "SNPOriginalName" }) do
        local status = ObjectStatus(InspectField(frame, key), context)
        if status ~= "missing" and status ~= "accessible" then
            result.status, result.reason = status, key
            return result
        end
    end
    local icon = InspectField(regions.castBar, "Icon")
    local highlight = InspectField(frame, "SNPInterruptibleHighlight")
    for _, object in pairs({ icon = icon, highlight = InspectField(highlight, "frame") }) do
        local status = ObjectStatus(object, context)
        if status ~= "missing" and status ~= "accessible" then
            result.status, result.reason = status, "cast overlay/icon"
            return result
        end
    end
    local cached = InspectField(frame, "SNPNameStyle")
    local cachedBar = InspectField(cached, "bar")
    local cachedStatus = ObjectStatus(cachedBar, context)
    if cachedStatus ~= "missing" and cachedStatus ~= "accessible" then
        result.status, result.reason = cachedStatus, "cached health bar"
        return result
    end
    if unknownField then
        result.status, result.reason = "unknown", unknownField
        return result
    end
    result.frame, result.canAccess = frame, true
    result.contextRevision = context.revision
    result.healthContainer, result.castContainer = container, castContainer
    result.hasName, result.hasHealthBar, result.hasCastBar =
        result.name ~= nil, result.healthBar ~= nil, result.castBar ~= nil
    -- Presence/access is assessed; it is not a guarantee of every UI operation.
    return result
end

-- Identity validation for a synchronous operation's existing assessment.
-- This is not a persistent permission cache; invalidation requires InspectFrame.
local function AssessmentIsCurrent(frame, assessment, context)
    if not assessment or not assessment.canAccess or assessment.frame ~= frame
        or assessment.contextRevision ~= context.revision then return false end
    for _, region in pairs({frame, assessment.name, assessment.healthBar, assessment.castBar,
        assessment.healthContainer, assessment.castContainer}) do
        if ObjectStatus(region, context) ~= "accessible" then return false end
    end
    local container = SafeField(frame, "HealthBarsContainer", context)
    local castContainer = SafeField(frame, "CastBarsContainer", context)
    return container == assessment.healthContainer and castContainer == assessment.castContainer
        and SafeField(frame, "name", context) == assessment.name
        and (SafeField(frame, "healthBar", context) or SafeField(container, "healthBar", context)) == assessment.healthBar
        and (SafeField(frame, "castBar", context) or SafeField(frame, "CastBar", context)
            or SafeField(castContainer, "castBar", context)) == assessment.castBar
end

local function InspectUnit(unit, context)
    context = context or GetContext()
    local getter = C_NamePlate and C_NamePlate.GetNamePlateForUnit
    if type(getter) ~= "function" then return { status = "unknown", canAccess = false } end
    local ok, plate = pcall(getter, unit)
    if not ok then return { status = "unknown", canAccess = false } end
    local status = ObjectStatus(plate, context)
    if status ~= "accessible" then return { status = status, canAccess = false } end
    local frame, readable = Field(plate, "UnitFrame")
    if readable == false then return {status = "unknown", canAccess = false, plate = plate} end
    local assessment = InspectFrame(frame, context)
    assessment.plate = plate
    return assessment
end

local function CanAccessFrame(frame, context)
    return InspectFrame(frame, context).canAccess
end

local function ReadRegion(region, methodName, context)
    context = context or GetContext()
    local method = SafeField(region, methodName, context)
    if type(method) ~= "function" then return nil end
    local ok, value = pcall(method, region)
    if ok then return AccessibleValue(value) end
end

InspectFrame = ns.Profiler.Wrap("Access assessment", InspectFrame)

ns.PresentationCapabilities = {
    InspectFrame = InspectFrame, InspectUnit = InspectUnit,
    CanAccessFrame = CanAccessFrame, ObjectStatus = ObjectStatus,
    AssessmentIsCurrent = AssessmentIsCurrent,
    SafeField = SafeField, ReadRegion = ReadRegion,
}
