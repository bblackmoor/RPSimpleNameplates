-- Simple Nameplates: name geometry, inside labels, and layout cache.
local _, ns = ...
local healthTextKeys = {"Text", "RightText", "LeftText"}
local auxiliaryTextKeys = {"RPSNInsideName", "RPSNFullTitleText", "RPSNThreatText"}
local GetContext = ns.WorldContext.Get
local AccessibleBoolean = ns.AccessibleBoolean
local AccessibleNumber, AccessibleValue = ns.AccessibleNumber, ns.AccessibleValue
local GetAppearanceSetting, GetTRP3Setting = ns.GetAppearanceSetting, ns.GetTRP3Setting
local GetHealthBar = ns.NameplateFrames.GetHealthBar


local ConstrainFullTitle = ns.NameplateTitles.ConstrainFullTitle

local function RestoreOriginalBarHeight(frame, bar, context, assessment)
    context = context or GetContext()
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess then return end
    if not frame then return end
    bar = frame.RPSNOriginalHealthBar or bar
    if bar and frame.RPSNOriginalBarHeight then
        bar:SetHeight(frame.RPSNOriginalBarHeight)
    end
    local container = frame.RPSNOriginalHealthBarsContainer or frame.HealthBarsContainer
    if container and frame.RPSNOriginalHealthBarsContainerHeight then
        container:SetHeight(frame.RPSNOriginalHealthBarsContainerHeight)
    end
    frame.RPSNOriginalBarHeight = nil
    frame.RPSNOriginalHealthBarsContainerHeight = nil
end

local function InsideBarHeight(frame, nameSize)
    return math.max(nameSize + 7, frame.RPSNOriginalBarHeight or 0,
        frame.RPSNOriginalHealthBarsContainerHeight or 0)
end

local function ApplyConfiguredBarHeight(frame, state, bar, baseNameSize, context, decision, assessment, profile)
    context = context or GetContext()
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess then return false, baseNameSize end
    local inside = GetAppearanceSetting("namePlacement", profile) == "INSIDE"
        and decision and decision.showHealthBar and bar ~= nil
    local hasThreat = frame.RPSNThreatStatus == "displayed raw percentage"
        or frame.RPSNThreatStatus == "displayed scaled percentage"
    local hasNativeText = false
    if bar and decision and decision.showHealthBar then
        for _, key in ipairs(healthTextKeys) do
            if AccessibleBoolean(ns.PresentationCapabilities.ReadRegion(bar[key], "IsShown", context)) == true then
                hasNativeText = true
            end
        end
    end
    if not inside and not hasThreat and not hasNativeText then
        RestoreOriginalBarHeight(frame, bar, context, assessment)
        return false, baseNameSize
    end

    if not frame.RPSNOriginalBarHeight then
        local originalHeight = AccessibleNumber(bar:GetHeight())
        if type(originalHeight) == "number" and originalHeight > 0 then
            frame.RPSNOriginalBarHeight = originalHeight
        end
    end
    local container = frame.HealthBarsContainer
    if container and not frame.RPSNOriginalHealthBarsContainerHeight then
        local originalHeight = AccessibleNumber(container:GetHeight())
        if type(originalHeight) == "number" and originalHeight > 0 then
            frame.RPSNOriginalHealthBarsContainerHeight = originalHeight
        end
    end

    local insideNameSize = baseNameSize
    local barHeight = InsideBarHeight(frame, insideNameSize)
    ns.NameplateFrames.PrepareBarSize(frame, bar, context)
    bar:SetHeight(barHeight)
    if container then
        ns.NameplateFrames.PrepareBarSize(frame, container, context)
        container:SetHeight(barHeight)
    end
    return inside, insideNameSize
end

local function PositionName(frame, name, bar, nameOnly, inside, rightInset, rightRegion)
    if nameOnly then
        name:ClearAllPoints()
        if bar then
            name:SetPoint("BOTTOM", bar, "TOP", 0, 2)
        else
            name:SetPoint("BOTTOM", frame, "TOP", 0, 2)
        end
        name:SetJustifyH("CENTER")
    elseif inside then
        name:ClearAllPoints()
        name:SetPoint("LEFT", bar, "LEFT", 3, 0)
        name:SetPoint("RIGHT", rightRegion or bar, rightRegion and "LEFT" or "RIGHT", rightInset, 0)
        name:SetJustifyH("LEFT")
    elseif bar then
        name:ClearAllPoints()
        name:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 2)
        name:SetJustifyH("LEFT")
    end
end

local function GetInsideName(frame, bar)
    local insideName = frame.RPSNInsideName
    if insideName and frame.RPSNInsideNameBar == bar then return insideName end
    if insideName then insideName:Hide() end
    insideName = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    insideName:SetDrawLayer("OVERLAY", 7)
    insideName:SetWordWrap(false)
    insideName:SetMaxLines(1)
    frame.RPSNInsideName = insideName
    frame.RPSNInsideNameBar = bar
    return insideName
end

local function ShowInsideName(frame, bar, text, fontPath, size, rightInset, rightRegion, textColor, profile)
    local insideName = GetInsideName(frame, bar)
    insideName:SetText(text)
    insideName:SetFont(fontPath, size, ns.FontFlags(profile))
    insideName:SetShadowColor(0, 0, 0, 0)
    insideName:SetShadowOffset(0, 0)
    insideName:SetTextColor(textColor, textColor, textColor, 1)
    insideName:ClearAllPoints()
    insideName:SetPoint("LEFT", bar, "LEFT", 3, -0.5)
    insideName:SetPoint("RIGHT", rightRegion or bar, rightRegion and "LEFT" or "RIGHT", rightInset, rightRegion and 0 or -0.5)
    insideName:SetJustifyH("LEFT")
    insideName:SetAlpha(1)
    insideName:Show()
    -- Leave Blizzard's name shown for its health-text visibility logic, but
    -- avoid drawing a second copy behind the bar.
    frame.name:SetAlpha(0)
end

local function RestoreNameDisplay(frame, context, assessment)
    context = context or GetContext()
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess then return end
    if frame.RPSNInsideName then frame.RPSNInsideName:Hide() end
    local name = frame.RPSNOriginalName or frame.name
    if name then name:SetAlpha(1) end
end

local function CacheNameStyle(frame, displayName, fontPath, size, nameR, nameG, nameB,
        nameOnly, inside, rightInset, bar, rightRegion, profile)
    local expected = frame.RPSNNameStyle or {}
    frame.RPSNNameStyle = expected
    expected.text = displayName
    expected.name = frame.name
    expected.unit = AccessibleValue(frame.unit)
    expected.unknownReads = nil
    expected.font = fontPath
    expected.size = size
    expected.flags = ns.FontFlags(profile)
    expected.r, expected.g, expected.b = nameR, nameG, nameB
    expected.nameOnly = nameOnly
    expected.inside = inside == true
    expected.rightInset = rightInset
    expected.rightRegion = rightRegion
    expected.bar = bar
    expected.barHeight = frame.RPSNOriginalBarHeight and InsideBarHeight(frame, size) or nil
    local anchors = frame.RPSNOriginalSizeAnchors or {}
    -- Height-only ownership also releases the native horizontal anchors. Keep
    -- their width in reconciliation even with the width slider at 100%.
    expected.barWidth = frame.RPSNBarWidth or (anchors[bar] and anchors[bar].width)
    local container = frame.HealthBarsContainer
    expected.containerWidth = frame.RPSNContainerWidth or (anchors[container] and anchors[container].width)
end

local function SuppressText(frame, context)
    -- Do not hide/reparent the unit frame or touch widget containers.
    if frame.name then frame.name:SetAlpha(0) end
    for _, key in ipairs(auxiliaryTextKeys) do
        ns.NameplateFrames.SetShownSafe(frame[key], false, context)
    end
end

local function RepairNameOnly(frame, context, assessment)
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess or frame.RPSNRestoring then return end
    local expected = frame.RPSNNameStyle
    if expected.suppressed then SuppressText(frame, context); return end
    local name = frame.name
    name:SetText(expected.text)
    name:SetFont(expected.font, expected.size, expected.flags)
    name:SetShadowColor(0, 0, 0, 0)
    name:SetShadowOffset(0, 0)
    name:SetVertexColor(1, 1, 1, 1)
    name:SetTextColor(expected.r, expected.g, expected.b, 1)
    name:Show()
    name:SetAlpha(expected.inside and 0 or 1)
    if expected.inside then frame.RPSNInsideName:Show() end
end

-- Threat/native-label presence changes the name's right edge. Reposition the
-- existing labels without rereading names/TRP3 or reapplying their fonts.
local function UpdateNameLayout(frame, context, decision, assessment)
    local profile = ns.GetActiveProfile and ns.GetActiveProfile()
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess or frame.RPSNRestoring then return end
    local expected = frame.RPSNNameStyle
    if not expected or expected.suppressed then return end
    local bar = GetHealthBar(frame, context, assessment)
    local inside, size = ApplyConfiguredBarHeight(frame, frame.RPSNState, bar,
        expected.size, context, decision, assessment, profile)
    local rightRegion, signature = ns.NameplateFrames.LayoutHealthText(frame, bar, context)
    PositionName(frame, frame.name, bar, decision.nameOnly, inside, -3, rightRegion)
    if inside and frame.RPSNInsideName then
        local name = frame.RPSNInsideName
        name:ClearAllPoints()
        name:SetPoint("LEFT", bar, "LEFT", 3, -0.5)
        name:SetPoint("RIGHT", rightRegion or bar, rightRegion and "LEFT" or "RIGHT", -3,
            rightRegion and 0 or -0.5)
    end
    ConstrainFullTitle(frame, context, assessment)
    CacheNameStyle(frame, expected.text, expected.font, size, expected.r, expected.g,
        expected.b, decision.nameOnly, inside, -3, bar, rightRegion, profile)
    expected.healthTextSignature = signature
end

UpdateNameLayout = ns.Profiler.Wrap("Name layout update", UpdateNameLayout)

ns.NameplateLayout = {
    RestoreOriginalBarHeight = RestoreOriginalBarHeight,
    ApplyConfiguredBarHeight = ApplyConfiguredBarHeight,
    PositionName = PositionName,
    ShowInsideName = ShowInsideName,
    RestoreNameDisplay = RestoreNameDisplay,
    CacheNameStyle = CacheNameStyle,
    SuppressText = SuppressText,
    RepairNameOnly = RepairNameOnly,
    UpdateNameLayout = UpdateNameLayout,
}
