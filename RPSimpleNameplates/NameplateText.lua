-- Simple Nameplates: unit names, TRP3 titles, layout, and cached text repair.
local _, ns = ...
local GetContext = ns.WorldContext.Get
local AccessibleBoolean = ns.AccessibleBoolean
local UnitName = UnitName
local AccessibleNumber, AccessibleValue = ns.AccessibleNumber, ns.AccessibleValue
local function AppearanceNumber(value)
    value = AccessibleNumber(value)
    if value and value == value and value ~= math.huge and value ~= -math.huge then return value end
end
local PriorityColorForState, FontPath = ns.PriorityColorForState, ns.FontPath
local GetAppearanceSetting, GetTRP3Setting = ns.GetAppearanceSetting, ns.GetTRP3Setting
local GetHealthBar = ns.NameplateFrames.GetHealthBar
local GetCastBar = ns.NameplateFrames.GetCastBar
local InstallNameAppearanceHooks, FinishCachedAppearance

local function NameFontPath(context)
    if context.sanctuary == true and GetAppearanceSetting("matchSanctuaryFont") == true then
        -- The engine's world-label font family is localized by Blizzard.
        -- Read only its face: preserve the profile's size and our text layout.
        if SystemFont_World and type(SystemFont_World.GetFont) == "function" then
            local ok, path = pcall(SystemFont_World.GetFont, SystemFont_World)
            if ok then
                path = AccessibleValue(path)
                if type(path) == "string" and path ~= "" then return path end
            end
        end
        return FontPath("FRIZQT")
    end
    return FontPath(GetAppearanceSetting("nameFont"))
end

local function UpdateNameText(frame)
    local name, unit = frame and frame.name, frame and frame.unit
    if not name or not unit then return nil end
    -- UnitName can be secret in Midnight. FontString:SetText can display that
    -- value directly; do not replace it with an empty string.
    local unitName = UnitName(unit)
    local displayName = unitName
    local fullTitle = frame.SNPEntityFacts and frame.SNPEntityFacts.npcTitle
    local info = ns.TRP3 and ns.TRP3.GetDisplayInfo(unit)

    if info then
        if GetTRP3Setting("useRoleplayingName") and info.roleplayingName then
            displayName = info.roleplayingName
        end

        local prefix
        if GetTRP3Setting("showOOC") and info.isOutOfCharacter then
            prefix = "[OOC]"
        elseif GetTRP3Setting("showShortTitle") then
            prefix = info.shortTitle
        end
        -- Lua cannot concatenate a secret unit name. Retain the raw name
        -- when it is restricted; a readable TRP3 name can still use the prefix.
        if prefix and AccessibleValue(displayName) then
            displayName = prefix .. " " .. displayName
        end

        if not fullTitle and GetTRP3Setting("showFullTitle") then fullTitle = info.fullTitle end
    end

    name:SetText(displayName)
    return fullTitle, displayName, unitName
end

local function EnsureFullTitleText(frame)
    if frame.SNPFullTitleText then return frame.SNPFullTitleText end
    -- Supply a template so the FontString is valid immediately, including
    -- during TRP3 callbacks that refresh a plate in the frame it is created.
    local fullTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fullTitle:SetJustifyH("LEFT")
    fullTitle:SetWordWrap(false)
    fullTitle:SetMaxLines(1)
    frame.SNPFullTitleText = fullTitle
    return fullTitle
end

local function SetTitleShown(frame, title, desired, context)
    local actual = AccessibleBoolean(ns.PresentationCapabilities.ReadRegion(title, "IsShown", context))
    if (actual ~= nil and actual ~= desired) or (actual == nil
        and (frame.SNPTitleDesiredRegion ~= title or frame.SNPTitleDesired ~= desired)) then
        title:SetShown(desired)
    end
    frame.SNPTitleDesiredRegion, frame.SNPTitleDesired = title, desired
end

local function SyncFullTitleVisibility(frame, context, assessment, retrying)
    context = context or GetContext()
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess or frame.SNPRestoring then return end
    local retry = retrying and frame.SNPTitleVisibilityRetry
    if retry and ns.PeriodicWork.Now() < retry.due then return end
    frame.SNPTitleVisibilityPending = nil
    local title, decision = frame.SNPFullTitleText, frame.SNPPresentation
    if not title then return end
    if not ns.GetStylingEnabled() or not frame.SNPFullTitleAvailable
        or not decision or not decision.showFullTitle or decision.suppressText then
        frame.SNPTitleVisibilityRetry = nil
        SetTitleShown(frame, title, false, context)
        return
    end
    local cast = assessment.castBar
    local shown = AccessibleBoolean(ns.PresentationCapabilities.ReadRegion(cast, "IsShown", context))
    if cast and shown == nil then
        frame.SNPTitleVisibilityPending = true
        local delay = math.min((retry and retry.delay * 2 or 0.25), 4)
        frame.SNPTitleVisibilityRetry = {due = ns.PeriodicWork.Now() + delay, delay = delay}
    else frame.SNPTitleVisibilityRetry = nil end
    -- Unknown cast visibility must not put title text over a possible cast.
    local desired = not cast or shown == false
    SetTitleShown(frame, title, desired, context)
end

local function InstallTitleCastHooks(frame, cast)
    if not cast or type(cast.HookScript) ~= "function" or cast.SNPTitleHookOwner == frame then return end
    local function Refresh()
        frame.SNPTitleVisibilityPending = true
        frame.SNPTitleVisibilityRetry = nil
        local context = GetContext()
        if GetCastBar(frame, context) == cast then SyncFullTitleVisibility(frame, context) end
    end
    cast:HookScript("OnShow", Refresh)
    cast:HookScript("OnHide", Refresh)
    cast.SNPTitleHookOwner = frame
end

local function FullTitleWidth(frame, context, assessment)
    local cap = ns.PresentationCapabilities
    for _, region in ipairs({GetHealthBar(frame, context, assessment) or false, frame.HealthBarsContainer or false, frame}) do
        if region and cap.ObjectStatus(region, context) == "accessible" then
            local width = AccessibleNumber(cap.ReadRegion(region, "GetWidth", context))
            if width and width > 0 then return width end
        end
    end
    -- Unknown geometry must not leave an unlimited title. Reconciliation retries.
    return 1
end

local function ConstrainFullTitle(frame, context, assessment)
    if frame.SNPFullTitleText then
        frame.SNPFullTitleText:SetWidth(FullTitleWidth(frame, context, assessment))
    end
end

local function StyleFullTitle(frame, state, text, baseNameSize, decision, context, nameShade, assessment)
    frame.SNPTitleDesiredRegion, frame.SNPTitleDesired = nil, nil
    local fullTitle = frame.SNPFullTitleText
    local bar = GetHealthBar(frame, context, assessment)
    frame.SNPFullTitleAvailable = text ~= nil and decision.showFullTitle == true
    if not frame.SNPFullTitleAvailable then
        if fullTitle then fullTitle:SetText(""); fullTitle:Hide() end
        return
    end

    fullTitle = EnsureFullTitleText(frame)
    local titleSize = math.max(6, baseNameSize - 2)
    fullTitle:SetFont(NameFontPath(context), titleSize, ns.FontFlags())
    -- Native single-line layout truncates overflow using the actual font.
    -- Keep the source string intact so widening the bar restores more text.
    ConstrainFullTitle(frame, context, assessment)
    fullTitle:SetText(text)
    fullTitle:SetShadowColor(0, 0, 0, 0)
    fullTitle:SetShadowOffset(0, 0)
    fullTitle:ClearAllPoints()
    fullTitle:SetPoint("TOP", decision.showHealthBar and bar or frame.name, "BOTTOM", 0, -1)
    fullTitle:SetJustifyH("CENTER")
    fullTitle:SetVertexColor(1, 1, 1, 1)
    local shade = state == "useless" and nameShade or 1
    fullTitle:SetTextColor(shade, shade, shade, 1)
    InstallTitleCastHooks(frame, GetCastBar(frame, context, assessment))
    SyncFullTitleVisibility(frame, context, assessment)
end

local function RestoreOriginalBarHeight(frame, bar, context, assessment)
    context = context or GetContext()
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess then return end
    if not frame then return end
    bar = frame.SNPOriginalHealthBar or bar
    if bar and frame.SNPOriginalBarHeight then
        bar:SetHeight(frame.SNPOriginalBarHeight)
    end
    local container = frame.SNPOriginalHealthBarsContainer or frame.HealthBarsContainer
    if container and frame.SNPOriginalHealthBarsContainerHeight then
        container:SetHeight(frame.SNPOriginalHealthBarsContainerHeight)
    end
    frame.SNPOriginalBarHeight = nil
    frame.SNPOriginalHealthBarsContainerHeight = nil
end

local function InsideBarHeight(frame, nameSize)
    return math.max(nameSize + 7, frame.SNPOriginalBarHeight or 0,
        frame.SNPOriginalHealthBarsContainerHeight or 0)
end

local function ApplyConfiguredBarHeight(frame, state, bar, baseNameSize, context, decision, assessment)
    context = context or GetContext()
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess then return false, baseNameSize end
    local inside = GetAppearanceSetting("namePlacement") == "INSIDE"
        and decision and decision.showHealthBar and bar ~= nil
    local hasThreat = frame.SNPThreatStatus == "displayed raw percentage"
        or frame.SNPThreatStatus == "displayed scaled percentage"
    local hasNativeText = false
    if bar and decision and decision.showHealthBar then
        for _, key in ipairs({"Text", "RightText", "LeftText"}) do
            if AccessibleBoolean(ns.PresentationCapabilities.ReadRegion(bar[key], "IsShown", context)) == true then
                hasNativeText = true
            end
        end
    end
    if not inside and not hasThreat and not hasNativeText then
        RestoreOriginalBarHeight(frame, bar, context, assessment)
        return false, baseNameSize
    end

    if not frame.SNPOriginalBarHeight then
        local originalHeight = AccessibleNumber(bar:GetHeight())
        if type(originalHeight) == "number" and originalHeight > 0 then
            frame.SNPOriginalBarHeight = originalHeight
        end
    end
    local container = frame.HealthBarsContainer
    if container and not frame.SNPOriginalHealthBarsContainerHeight then
        local originalHeight = AccessibleNumber(container:GetHeight())
        if type(originalHeight) == "number" and originalHeight > 0 then
            frame.SNPOriginalHealthBarsContainerHeight = originalHeight
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
    local insideName = frame.SNPInsideName
    if insideName and frame.SNPInsideNameBar == bar then return insideName end
    if insideName then insideName:Hide() end
    insideName = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    insideName:SetDrawLayer("OVERLAY", 7)
    insideName:SetWordWrap(false)
    insideName:SetMaxLines(1)
    frame.SNPInsideName = insideName
    frame.SNPInsideNameBar = bar
    return insideName
end

local function ShowInsideName(frame, bar, text, fontPath, size, rightInset, rightRegion, textColor)
    local insideName = GetInsideName(frame, bar)
    insideName:SetText(text)
    insideName:SetFont(fontPath, size, ns.FontFlags())
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
    if frame.SNPInsideName then frame.SNPInsideName:Hide() end
    local name = frame.SNPOriginalName or frame.name
    if name then name:SetAlpha(1) end
end

local function CacheNameStyle(frame, displayName, fontPath, size, nameR, nameG, nameB,
        nameOnly, inside, rightInset, bar, rightRegion)
    local expected = frame.SNPNameStyle or {}
    frame.SNPNameStyle = expected
    expected.text = displayName
    expected.name = frame.name
    expected.unit = AccessibleValue(frame.unit)
    expected.unknownReads = nil
    expected.font = fontPath
    expected.size = size
    expected.flags = ns.FontFlags()
    expected.r, expected.g, expected.b = nameR, nameG, nameB
    expected.nameOnly = nameOnly
    expected.inside = inside == true
    expected.rightInset = rightInset
    expected.rightRegion = rightRegion
    expected.bar = bar
    expected.barHeight = frame.SNPOriginalBarHeight and InsideBarHeight(frame, size) or nil
    local anchors = frame.SNPOriginalSizeAnchors or {}
    -- Height-only ownership also releases the native horizontal anchors. Keep
    -- their width in reconciliation even with the width slider at 100%.
    expected.barWidth = frame.SNPBarWidth or (anchors[bar] and anchors[bar].width)
    local container = frame.HealthBarsContainer
    expected.containerWidth = frame.SNPContainerWidth or (anchors[container] and anchors[container].width)
end

local function SuppressText(frame, context)
    -- Do not hide/reparent the unit frame or touch widget containers.
    if frame.name then frame.name:SetAlpha(0) end
    for _, key in ipairs({"SNPInsideName", "SNPFullTitleText", "SNPThreatText"}) do
        ns.NameplateFrames.SetShownSafe(frame[key], false, context)
    end
end

local function StyleName(frame, state, context, decision, assessment)
    context = context or GetContext()
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess then return end
    if not decision or decision.action ~= "style" then return end
    if decision.suppressText then
        SuppressText(frame, context)
        frame.SNPNameStyle = {suppressed = true, presentation = decision, name = frame.name,
            bar = assessment.healthBar, unit = AccessibleValue(frame.unit)}
        InstallNameAppearanceHooks(frame, frame.name, context)
        return
    end
    local name = frame and frame.name
    if not name then return end
    local fullTitle, displayName, unitName = UpdateNameText(frame)
    local baseSize = GetAppearanceSetting("nameSize") or 12
    local bar = GetHealthBar(frame, context, assessment)
    local nameOnly = decision.nameOnly
    local inside, size = ApplyConfiguredBarHeight(frame, state, bar, baseSize, context, decision, assessment)
    local rightInset = -3

    local fontPath = NameFontPath(context)
    name:SetFont(fontPath, size, ns.FontFlags())
    name:SetShadowColor(0, 0, 0, 0)
    name:SetShadowOffset(0, 0)
    local nameR, nameG, nameB = 1, 1, 1
    if nameOnly then nameR, nameG, nameB = PriorityColorForState(decision.colorState or state)
    end
    if state == "useless" then
        local shade = ns.GetDimBackgroundNames and ns.GetDimBackgroundNames() and 153 / 255 or 1
        nameR, nameG, nameB = shade, shade, shade
    end
    -- Blizzard also tints nameplate text with UnitSelectionColor through the
    -- FontString's vertex color. Keep that tint neutral so the configured
    -- Simple Nameplates color is displayed exactly.
    name:SetVertexColor(1, 1, 1, 1)
    name:SetTextColor(nameR, nameG, nameB, 1)
    name:Show()
    -- Showing the native name can itself change native health-text visibility.
    local rightRegion, healthTextSignature = ns.NameplateFrames.LayoutHealthText(frame, bar, context)
    PositionName(frame, name, bar, nameOnly, inside, rightInset, rightRegion)
    if inside then
        ShowInsideName(frame, bar, displayName, fontPath, size, rightInset, rightRegion, nameR)
    else
        RestoreNameDisplay(frame, context, assessment)
    end
    StyleFullTitle(frame, state, fullTitle, baseSize, decision, context, nameR, assessment)
    CacheNameStyle(frame, displayName, fontPath, size, nameR, nameG, nameB,
        nameOnly, inside, rightInset, bar, rightRegion)
    frame.SNPNameStyle.unitName = unitName
    frame.SNPNameStyle.presentation = decision
    frame.SNPNameStyle.healthTextSignature = healthTextSignature
    -- Calibrate against the completed color write. Some FontString color
    -- getters expose shared text/vertex state; grey must not be treated as
    -- unwanted vertex tint and reset to white on every periodic visit.
    local getter = ns.PresentationCapabilities.SafeField(name, "GetVertexColor", context)
    local ok, r, g, b, a
    if type(getter) == "function" then ok, r, g, b, a = pcall(getter, name) end
    r, g, b, a = AccessibleNumber(r), AccessibleNumber(g), AccessibleNumber(b), AccessibleNumber(a)
    frame.SNPNameStyle.vertexColor = ok and r and g and b and a and {r, g, b, a} or nil
    InstallNameAppearanceHooks(frame, name, context)
end

-- Focused native-name repair. No classification, profile lookup, bar artwork
-- or geometry writes; the runtime refresh handles actual content changes.
local function RepairNameOnly(frame, context, assessment)
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess or frame.SNPRestoring then return end
    local expected = frame.SNPNameStyle
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
    if expected.inside then frame.SNPInsideName:Show() end
end

-- Threat/native-label presence changes the name's right edge. Reposition the
-- existing labels without rereading names/TRP3 or reapplying their fonts.
local function UpdateNameLayout(frame, context, decision, assessment)
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess or frame.SNPRestoring then return end
    local expected = frame.SNPNameStyle
    if not expected or expected.suppressed then return end
    local bar = GetHealthBar(frame, context, assessment)
    local inside, size = ApplyConfiguredBarHeight(frame, frame.SNPState, bar,
        expected.size, context, decision, assessment)
    local rightRegion, signature = ns.NameplateFrames.LayoutHealthText(frame, bar, context)
    PositionName(frame, frame.name, bar, decision.nameOnly, inside, -3, rightRegion)
    if inside and frame.SNPInsideName then
        local name = frame.SNPInsideName
        name:ClearAllPoints()
        name:SetPoint("LEFT", bar, "LEFT", 3, -0.5)
        name:SetPoint("RIGHT", rightRegion or bar, rightRegion and "LEFT" or "RIGHT", -3,
            rightRegion and 0 or -0.5)
    end
    ConstrainFullTitle(frame, context, assessment)
    CacheNameStyle(frame, expected.text, expected.font, size, expected.r, expected.g,
        expected.b, decision.nameOnly, inside, -3, bar, rightRegion)
    expected.healthTextSignature = signature
end

local function NearlyEqual(a, b)
    a, b = AccessibleNumber(a), AccessibleNumber(b)
    return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.001
end

-- Assessments and observations belong to one synchronous operation only.
local function CacheIsCurrent(frame, expected, context, assessment)
    if ns.NameplateRestoration.IsPending(frame) then return false, "restoration pending" end
    local decision = frame.SNPPresentation
    if not decision or expected.presentation ~= decision or decision.contextRevision ~= context.revision then return false, "presentation revision" end
    if expected.unit ~= AccessibleValue(frame.unit) then return false, "unit assignment" end
    if expected.name ~= assessment.name then return false, "name region replaced" end
    if type(UnitNameplateShowsWidgetsOnly) == "function" then
        local ok, value = pcall(UnitNameplateShowsWidgetsOnly, frame.unit)
        local widgetsOnly
        if ok then widgetsOnly = AccessibleBoolean(value) end
        if type(widgetsOnly) == "boolean" and widgetsOnly ~= (decision.suppressText == true) then return false, "widget mode" end
    end
    if expected.suppressed then return true end
    if expected.flags ~= ns.FontFlags() then return false, "font flags setting" end
    if not ns.FontPathMatches(expected.font, NameFontPath(context)) then return false, "font setting" end
    if expected.bar ~= assessment.healthBar then return false, "health bar replaced" end
    if frame.SNPOriginalVisibility
        and frame.SNPOriginalHealthBarsContainer ~= frame.HealthBarsContainer then return false, "container replaced" end
    -- Visibility is mutable native presentation, not cache identity. A native
    -- hide/show needs selective repair while assignment and policy stay valid.
    return true
end

-- Unknown is neither equality nor drift. Retry an unreadable property after
-- 0.25, 0.5, 1, 2, then four elapsed seconds, independent of visit count, while
-- continuing to observe independent properties. Styling resets this backoff.
local function Observe(expected, key, region, method, context, count)
    local retries = expected.unknownReads
    local retry = retries and retries[key]
    if retry and ns.PeriodicWork.Now() < retry.due then return end
    local cap = ns.PresentationCapabilities
    local getter = cap.SafeField(region, method, context)
    local ok, a, b, c, d
    if type(getter) == "function" then ok, a, b, c, d = pcall(getter, region) end
    if ok then
        a, b, c, d = AccessibleValue(a), AccessibleValue(b), AccessibleValue(c), AccessibleValue(d)
    end
    local unknown = not ok or a == nil or (count and count >= 2 and b == nil)
        or (count and count >= 3 and c == nil) or (count and count >= 4 and d == nil)
    if unknown then
        retries = retries or {}; expected.unknownReads = retries
        local delay = math.min((retry and retry.delay * 2 or 0.25), 4)
        retries[key] = {due = ns.PeriodicWork.Now() + delay, delay = delay}
        if ok then return a, b, c, d end
        return
    end
    if retries then retries[key] = nil end
    return a, b, c, d
end

local function Different(actual, desired)
    if actual == nil or desired == nil then return false end
    if type(desired) == "number" then
        return type(actual) == "number" and not NearlyEqual(actual, desired)
    end
    return type(actual) == type(desired) and actual ~= desired
end

-- Native dimensions can be rounded to physical pixels. Keep font/color
-- comparisons strict; only geometry gets half a pixel of tolerance.
local function DimensionDifferent(actual, desired, region, context)
    actual, desired = AccessibleNumber(actual), AccessibleNumber(desired)
    if actual == nil or desired == nil then return false end
    local tolerance = 0.001
    local scale = AccessibleNumber(ns.PresentationCapabilities.ReadRegion(region, "GetEffectiveScale", context))
    if scale and scale > 0 and PixelUtil and type(PixelUtil.GetPixelToUIUnitFactor) == "function" then
        local ok, factor = pcall(PixelUtil.GetPixelToUIUnitFactor)
        factor = ok and AccessibleNumber(factor)
        if factor and factor > 0 then tolerance = factor / scale / 2 + 0.001 end
    end
    return math.abs(actual - desired) > tolerance
end

local function CachedNameHasDrifted(frame, context, assessment)
    context = context or GetContext()
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess or frame.SNPRestoring or frame.SNPApplyingStyle then return false end
    local name, expected = assessment.name, frame.SNPNameStyle
    if not name or not expected then return false end
    local current, reason = CacheIsCurrent(frame, expected, context, assessment)
    if not current then return true, reason, {full = true} end
    local plan
    local function Add(key, value, label)
        plan = plan or {expected = expected, name = name, bar = assessment.healthBar,
            container = frame.HealthBarsContainer, insideName = frame.SNPInsideName,
            unit = AccessibleValue(frame.unit), presentation = frame.SNPPresentation,
            revision = context.revision}
        plan[key] = value
        reason = reason or label
    end
    local function Check(key, region, method, desired, label)
        if desired == nil then return end
        local actual = Observe(expected, key, region, method, context)
        local geometry = key == "barWidth" or key == "barHeight" or key == "containerWidth" or key == "containerHeight"
        local differs
        if geometry then differs = DimensionDifferent(actual, desired, region, context)
        else differs = Different(actual, desired) end
        if differs then
            Add(key, desired, label)
            if key == "barWidth" or key == "barHeight" or key == "containerWidth" or key == "containerHeight" then
                ns.Profiler.SizeSample(key, actual, desired, region)
            end
        end
        return actual
    end
    if expected.suppressed then
        Check("alpha", name, "GetAlpha", 0, "suppressed alpha")
        for _, key in ipairs({"SNPInsideName", "SNPFullTitleText", "SNPThreatText"}) do
            if frame[key] then Check(key, frame[key], "IsShown", false, "suppressed text visible") end
        end
        return plan ~= nil, reason, plan
    end
    Check("shown", name, "IsShown", true, "name hidden")
    Check("barShown", assessment.healthBar, "IsShown", frame.SNPPresentation.showHealthBar, "bar visibility")
    if frame.HealthBarsContainer then
        Check("containerShown", frame.HealthBarsContainer, "IsShown", true, "container visibility")
    end
    if frame.SNPPresentation.showHealthBar then
        Check("barAlpha", assessment.healthBar, "GetAlpha", 1, "bar alpha")
        if frame.HealthBarsContainer then
            Check("containerAlpha", frame.HealthBarsContainer, "GetAlpha", 1, "container alpha")
        end
    end
    Check("text", name, "GetText", AccessibleValue(expected.text), "native name text")
    local font, size, flags = Observe(expected, "font", name, "GetFont", context, 3)
    local faceDrift = font ~= nil and not ns.FontPathMatches(font, expected.font)
    local sizeDrift = Different(size, expected.size)
    local flagsDrift = flags ~= nil and not ns.FontFlagsMatch(flags, expected.flags)
    if faceDrift or sizeDrift or flagsDrift then
        Add("font", true, "native font")
        if faceDrift then ns.Profiler.Count("Font drift components", "face") end
        if sizeDrift then ns.Profiler.Count("Font drift components", "size") end
        if flagsDrift then ns.Profiler.Count("Font drift components", "flags") end
    end
    Check("barHeight", expected.bar, "GetHeight", expected.barHeight, "bar height")
    if frame.HealthBarsContainer then Check("containerHeight", frame.HealthBarsContainer, "GetHeight", expected.barHeight, "container height") end
    local barWidth = Check("barWidth", expected.bar, "GetWidth", expected.barWidth, "bar width")
    local containerWidth
    if frame.HealthBarsContainer then containerWidth = Check("containerWidth", frame.HealthBarsContainer, "GetWidth", expected.containerWidth, "container width") end
    if frame.SNPFullTitleAvailable and frame.SNPFullTitleText then
        -- Reuse dimensions already observed, including their repaired values.
        if plan and plan.barWidth then barWidth = plan.barWidth end
        if plan and plan.containerWidth then containerWidth = plan.containerWidth end
        if expected.barWidth == nil and expected.bar then
            barWidth = Observe(expected, "titleBarWidth", expected.bar, "GetWidth", context)
        end
        local width = AccessibleNumber(barWidth)
        if (not width or width <= 0) and expected.containerWidth == nil and frame.HealthBarsContainer then
            containerWidth = Observe(expected, "titleContainerWidth", frame.HealthBarsContainer, "GetWidth", context)
        end
        if not width or width <= 0 then width = AccessibleNumber(containerWidth) end
        if not width or width <= 0 then width = AccessibleNumber(Observe(expected, "titleFrameWidth", frame, "GetWidth", context)) end
        -- No readable source width means no proven title-width drift.
        if width and width > 0 then Check("titleWidth", frame.SNPFullTitleText, "GetWidth", width, "title width") end
    end
    Check("alpha", name, "GetAlpha", expected.inside and 0 or 1,
        expected.inside and "inside native name alpha" or "native name alpha")
    if expected.inside then
        local inside = frame.SNPInsideName
        if not inside or frame.SNPInsideNameBar ~= expected.bar then return true, "inside name replaced", {full = true} end
        Check("insideAlpha", inside, "GetAlpha", 1, "inside label alpha")
        Check("insideShown", inside, "IsShown", true, "inside label visibility")
        Check("insideText", inside, "GetText", AccessibleValue(expected.text), "inside name text")
    elseif frame.SNPInsideName then
        Check("insideShown", frame.SNPInsideName, "IsShown", false, "inside name visible")
    end
    local r, g, b = Observe(expected, "color", name, "GetTextColor", context, 3)
    if Different(r, expected.r) or Different(g, expected.g) or Different(b, expected.b) then
        Add("color", true, "text color")
        ns.Profiler.ColorSample(r, g, b, expected.r, expected.g, expected.b)
    end
    r, g, b, flags = Observe(expected, "vertex", name, "GetVertexColor", context, 4)
    local vertex = expected.vertexColor
    if vertex and (Different(r, vertex[1]) or Different(g, vertex[2])
        or Different(b, vertex[3]) or Different(flags, vertex[4])) then Add("vertex", true, "vertex color") end
    r, g, b, flags = Observe(expected, "shadow", name, "GetShadowColor", context, 4)
    if Different(r, 0) or Different(g, 0) or Different(b, 0) or Different(flags, 0) then Add("shadow", true, "shadow color") end
    r, g = Observe(expected, "shadowOffset", name, "GetShadowOffset", context, 2)
    if Different(r, 0) or Different(g, 0) then Add("shadowOffset", true, "shadow offset") end
    -- Scan label presence once. A changed chain needs anchors, not new fonts.
    local inset, signature, labels, threat = ns.NameplateFrames.GetHealthTextInsetRegion(frame, expected.bar, context)
    if inset ~= expected.rightRegion or signature ~= expected.healthTextSignature then
        Add("layout", {inset = inset, signature = signature, labels = labels, threat = threat}, "health label layout")
    end
    return plan ~= nil, reason, plan
end

local function RepairCachedName(frame, context, assessment, plan)
    context = context or GetContext()
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess or frame.SNPRestoring then return false end
    if frame.SNPApplyingStyle then return true end
    if not plan then
        local drifted
        drifted, _, plan = CachedNameHasDrifted(frame, context, assessment)
        if not drifted then return true end
    end
    if plan.full then return false end
    local expected, name = frame.SNPNameStyle, assessment.name
    -- Reject observations if a callback changed their owner/regions/context.
    if ns.NameplateRestoration.IsPending(frame)
        or not ns.PresentationCapabilities.AssessmentIsCurrent(frame, assessment, context)
        or expected ~= plan.expected or name ~= plan.name or assessment.healthBar ~= plan.bar
        or frame.HealthBarsContainer ~= plan.container or frame.SNPInsideName ~= plan.insideName
        or AccessibleValue(frame.unit) ~= plan.unit or frame.SNPPresentation ~= plan.presentation
        or context.revision ~= plan.revision then return false end
    frame.SNPApplyingStyle = true
    local ok, err = pcall(function()
        if plan.text ~= nil then name:SetText(plan.text) end
        if plan.font then name:SetFont(expected.font, expected.size, expected.flags) end
        if plan.shadow then name:SetShadowColor(0, 0, 0, 0) end
        if plan.shadowOffset then name:SetShadowOffset(0, 0) end
        if plan.shown ~= nil then name:SetShown(plan.shown) end
        if plan.containerShown ~= nil then ns.NameplateFrames.SetShownSafe(plan.container, plan.containerShown, context) end
        if plan.barShown ~= nil then ns.NameplateFrames.SetShownSafe(plan.bar, plan.barShown, context) end
        if plan.barHeight or plan.barWidth then ns.NameplateFrames.PrepareBarSize(frame, plan.bar, context) end
        if plan.containerHeight or plan.containerWidth then ns.NameplateFrames.PrepareBarSize(frame, plan.container, context) end
        if plan.barHeight then plan.bar:SetHeight(plan.barHeight) end
        if plan.containerHeight then plan.container:SetHeight(plan.containerHeight) end
        if plan.barWidth then plan.bar:SetWidth(plan.barWidth) end
        if plan.containerWidth then plan.container:SetWidth(plan.containerWidth) end
        if plan.titleWidth then frame.SNPFullTitleText:SetWidth(plan.titleWidth) end
        if plan.barAlpha ~= nil then plan.bar:SetAlpha(plan.barAlpha) end
        if plan.containerAlpha ~= nil then plan.container:SetAlpha(plan.containerAlpha) end
        if plan.insideAlpha ~= nil then frame.SNPInsideName:SetAlpha(plan.insideAlpha) end
        if plan.insideShown ~= nil then frame.SNPInsideName:SetShown(plan.insideShown) end
        if plan.insideText ~= nil then frame.SNPInsideName:SetText(plan.insideText) end
        if expected.suppressed then
            for _, key in ipairs({"SNPInsideName", "SNPFullTitleText", "SNPThreatText"}) do
                if plan[key] ~= nil then frame[key]:SetShown(plan[key]) end
            end
        end
        if plan.layout then
            local rightRegion, signature = ns.NameplateFrames.LayoutHealthText(frame, plan.bar, context, plan.layout)
            PositionName(frame, name, plan.bar, expected.nameOnly, expected.inside,
                expected.rightInset or -3, rightRegion)
            if expected.inside then
                local inside = frame.SNPInsideName
                inside:ClearAllPoints()
                inside:SetPoint("LEFT", plan.bar, "LEFT", 3, -0.5)
                inside:SetPoint("RIGHT", rightRegion or plan.bar, rightRegion and "LEFT" or "RIGHT",
                    expected.rightInset or -3, rightRegion and 0 or -0.5)
            end
            expected.rightRegion, expected.healthTextSignature = rightRegion, signature
        end
        -- Visibility/layout callbacks can replace appearance without invoking
        -- Lua setters. Finish planned appearance writes after those callbacks.
        if plan.vertex then name:SetVertexColor(1, 1, 1, 1) end
        if plan.color or plan.vertex then name:SetTextColor(expected.r, expected.g, expected.b, 1) end
        if plan.alpha ~= nil then name:SetAlpha(plan.alpha)
        elseif plan.color or plan.vertex then
            local desired = expected.inside and 0 or 1
            local alpha = AppearanceNumber(ns.PresentationCapabilities.ReadRegion(name, "GetAlpha", context))
            if Different(alpha, desired) then name:SetAlpha(desired) end
        end
    end)
    frame.SNPApplyingStyle = nil
    if not ok then error(err, 0) end
    if frame.SNPArtworkPending then
        local current = ns.PresentationCapabilities.InspectFrame(frame, context)
        if current.canAccess then ns.NameplateFrames.ApplyBarArtwork(frame, current, context) end
    end
    if ns.NameplateText then ns.NameplateText.RepairPendingNameAppearance(frame) end
    FinishCachedAppearance(frame, context)
    return true
end

-- Native frame options write font objects/text height outside UpdateName, and
-- other native paths can recolor the FontString directly. Repair only the
-- overwritten appearance before it is drawn; never classify or fully restyle
-- from a setter hook. Own writes/restoration exit before any assessment.
local appearanceHookOwners = setmetatable({}, {__mode = "k"})
local appearanceHookRepair = setmetatable({}, {__mode = "k"})
local appearanceColorRepair = setmetatable({}, {__mode = "k"})
local appearanceAlphaRepair = setmetatable({}, {__mode = "k"})
InstallNameAppearanceHooks = function(frame, name, context)
    if not hooksecurefunc or appearanceHookOwners[name] then return end
    appearanceHookOwners[name] = frame
    for _, method in ipairs({"SetFont", "SetFontObject", "SetTextHeight", "SetTextColor", "SetVertexColor", "SetAlpha"}) do
        if type(ns.PresentationCapabilities.SafeField(name, method, context)) == "function" then
            local function Repair()
                local cap = ns.PresentationCapabilities
                local current = GetContext()
                if cap.ObjectStatus(frame, current) ~= "accessible" then return end
                if frame.SNPRestoring or frame.SNPRepairingNameAppearance or not ns.GetStylingEnabled() then return end
                if frame.SNPApplyingStyle or frame.SNPApplyingArtwork then
                    -- The addon never calls these two setters itself. Native
                    -- writes nested inside its UI callbacks must survive guards.
                    if method == "SetFontObject" or method == "SetTextHeight" then
                        frame.SNPNameAppearancePending = true
                    elseif method == "SetTextColor" or method == "SetVertexColor" then
                        -- Own color writes also pass here. Check the completed
                        -- result after the guard instead of repairing recursively.
                        frame.SNPNameColorPending = true
                    elseif method == "SetAlpha" then
                        frame.SNPNameAlphaPending = true
                    end
                    return
                end
                local expected = frame.SNPNameStyle
                if not expected or (expected.suppressed and method ~= "SetAlpha") or expected.name ~= name
                    or expected.unit ~= AccessibleValue(frame.unit)
                    or frame.SNPOriginalUnit ~= expected.unit then return end
                if UnitGUID then
                    local ok, value = pcall(UnitGUID, expected.unit)
                    local guid = ok and AccessibleValue(value)
                    local previous = frame.SNPEntityFacts and frame.SNPEntityFacts.guid
                    if type(guid) == "string" and type(previous) == "string" and guid ~= previous then return end
                end
                local assessment = cap.InspectFrame(frame, current)
                local decision = frame.SNPPresentation
                -- A native bar-visibility/geometry change must not veto color
                -- repair. Validate ownership/presentation, not mutable layout.
                if not assessment.canAccess or assessment.name ~= name
                    or expected.bar ~= assessment.healthBar
                    or not decision or decision.action ~= "style"
                    or expected.presentation ~= decision
                    or decision.contextRevision ~= current.revision
                    or ns.NameplateRestoration.IsPending(frame) then return end
                ns.Profiler.Count("Name appearance writes", method)
                frame.SNPRepairingNameAppearance = true
                local ok, err = pcall(function()
                    if method == "SetAlpha" then
                        name:SetAlpha((expected.suppressed or expected.inside) and 0 or 1)
                        return
                    end
                    if method == "SetFont" or method == "SetFontObject" or method == "SetTextHeight" then
                        name:SetFont(expected.font, expected.size, expected.flags)
                        -- FontObject changes can also replace colors/shadows.
                        name:SetShadowColor(0, 0, 0, 0)
                        name:SetShadowOffset(0, 0)
                    end
                    name:SetVertexColor(1, 1, 1, 1)
                    name:SetTextColor(expected.r, expected.g, expected.b, 1)
                    -- Appearance setters may replace opacity too. Finish with
                    -- the presentation's native-name visibility after colors.
                    name:SetAlpha(expected.inside and 0 or 1)
                end)
                frame.SNPRepairingNameAppearance = nil
                if not ok then error(err, 0) end
            end
            if method == "SetFont" then appearanceHookRepair[name] = Repair end
            if method == "SetTextColor" then appearanceColorRepair[name] = Repair end
            if method == "SetAlpha" then appearanceAlphaRepair[name] = Repair end
            hooksecurefunc(name, method, Repair)
        end
    end
end

local function RepairBarGeometry(frame, context, assessment)
    local expected = frame.SNPNameStyle
    if not expected or expected.suppressed or not CacheIsCurrent(frame, expected, context, assessment) then return false end
    local plan = {expected = expected, name = assessment.name, bar = assessment.healthBar,
        container = frame.HealthBarsContainer, insideName = frame.SNPInsideName,
        unit = AccessibleValue(frame.unit), presentation = frame.SNPPresentation, revision = context.revision}
    local changed
    local function Visibility(key, region, desired)
        local actual = AccessibleBoolean(ns.PresentationCapabilities.ReadRegion(region, "IsShown", context))
        if actual ~= nil and actual ~= desired then plan[key], changed = desired, true end
    end
    if plan.container then Visibility("containerShown", plan.container, true) end
    if plan.bar then Visibility("barShown", plan.bar, frame.SNPPresentation.showHealthBar) end
    if frame.SNPPresentation.showHealthBar then
        for _, item in ipairs({{"barAlpha", plan.bar}, {"containerAlpha", plan.container}}) do
            local alpha = AccessibleNumber(ns.PresentationCapabilities.ReadRegion(item[2], "GetAlpha", context))
            if alpha ~= nil and Different(alpha, 1) then plan[item[1]], changed = 1, true end
        end
    end
    for _, item in ipairs({
        {"barWidth", plan.bar, "GetWidth", expected.barWidth},
        {"barHeight", plan.bar, "GetHeight", expected.barHeight},
        {"containerWidth", plan.container, "GetWidth", expected.containerWidth},
        {"containerHeight", plan.container, "GetHeight", expected.barHeight},
    }) do
        if item[4] ~= nil then
            local actual = ns.PresentationCapabilities.ReadRegion(item[2], item[3], context)
            if DimensionDifferent(actual, item[4], item[2], context) then
                plan[item[1]], changed = item[4], true
            end
        end
    end
    if changed then return RepairCachedName(frame, context, assessment, plan) end
    return true
end

local function RepairPendingNameAppearance(frame)
    local fontPending, colorPending, alphaPending =
        frame.SNPNameAppearancePending, frame.SNPNameColorPending, frame.SNPNameAlphaPending
    frame.SNPNameAppearancePending, frame.SNPNameColorPending, frame.SNPNameAlphaPending = nil, nil, nil
    if fontPending then
        local repair = appearanceHookRepair[frame.name]
        if repair then repair() end
    elseif colorPending then
        local expected, name = frame.SNPNameStyle, frame.name
        if not expected or expected.name ~= name or expected.suppressed then return end
        local context = GetContext()
        local r, g, b = Observe(expected, "color", name, "GetTextColor", context, 3)
        local changed = Different(AccessibleNumber(r), expected.r)
            or Different(AccessibleNumber(g), expected.g) or Different(AccessibleNumber(b), expected.b)
        local vr, vg, vb, va = Observe(expected, "vertex", name, "GetVertexColor", context, 4)
        local vertex = expected.vertexColor
        if vertex then
            changed = changed or Different(AccessibleNumber(vr), vertex[1])
                or Different(AccessibleNumber(vg), vertex[2]) or Different(AccessibleNumber(vb), vertex[3])
                or Different(AccessibleNumber(va), vertex[4])
        end
        if changed then
            local repair = appearanceColorRepair[name]
            if repair then
                ns.Profiler.Count("Name appearance deferred", "color repair")
                repair()
            end
        end
    end
    if alphaPending then
        local expected, name = frame.SNPNameStyle, frame.name
        if not expected or expected.name ~= name then return end
        local desired = (expected.suppressed or expected.inside) and 0 or 1
        local actual = Observe(expected, "alpha", name, "GetAlpha", GetContext())
        if Different(AccessibleNumber(actual), desired) then
            local repair = appearanceAlphaRepair[name]
            if repair then
                ns.Profiler.Count("Name appearance deferred", "alpha repair")
                repair()
            end
        end
    end
end


-- One bounded appearance recovery after standalone structural/artwork work.
-- No fonts, classification, layout, timers or full styling. Unknown values
-- remain for reconciliation; readable resets must not survive completion.
FinishCachedAppearance = function(frame, context)
    local current = GetContext()
    if context and context.revision ~= current.revision then return end
    context = current
    local cap = ns.PresentationCapabilities
    local assessment = cap.InspectFrame(frame, context)
    if not assessment.canAccess or frame.SNPRestoring or frame.SNPApplyingStyle
        or frame.SNPApplyingArtwork or frame.SNPRepairingNameAppearance
        or frame.SNPFinishingNameAppearance or not ns.GetStylingEnabled() then return end
    local expected, name = frame.SNPNameStyle, assessment.name
    if not expected or frame.SNPOriginalUnit ~= expected.unit
        or not CacheIsCurrent(frame, expected, context, assessment) then return end
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, expected.unit)
        guid = ok and AccessibleValue(guid)
        local previous = frame.SNPEntityFacts and frame.SNPEntityFacts.guid
        if type(guid) == "string" and type(previous) == "string" and guid ~= previous then return end
    end
    local colorChanged
    if not expected.suppressed then
        local r, g, b = Observe(expected, "color", name, "GetTextColor", context, 3)
        colorChanged = Different(AppearanceNumber(r), expected.r)
            or Different(AppearanceNumber(g), expected.g) or Different(AppearanceNumber(b), expected.b)
        local vr, vg, vb, va = Observe(expected, "vertex", name, "GetVertexColor", context, 4)
        local vertex = expected.vertexColor
        if vertex then
            colorChanged = colorChanged or Different(AppearanceNumber(vr), vertex[1])
                or Different(AppearanceNumber(vg), vertex[2]) or Different(AppearanceNumber(vb), vertex[3])
                or Different(AppearanceNumber(va), vertex[4])
        end
    end
    local desired = (expected.suppressed or expected.inside) and 0 or 1
    local alpha = Observe(expected, "alpha", name, "GetAlpha", context)
    local alphaChanged = Different(AppearanceNumber(alpha), desired)
    if not colorChanged and not alphaChanged then return end
    frame.SNPFinishingNameAppearance = true
    local ok, err = pcall(function()
        if colorChanged and appearanceColorRepair[name] then
            ns.Profiler.Count("Appearance finalization", "color")
            appearanceColorRepair[name]() -- Validates identity/access again before writing.
        elseif alphaChanged and appearanceAlphaRepair[name] then
            ns.Profiler.Count("Appearance finalization", "alpha")
            appearanceAlphaRepair[name]()
        end
    end)
    frame.SNPFinishingNameAppearance = nil
    if not ok then error(err, 0) end
end


StyleName = ns.Profiler.Wrap("Name/title styling", StyleName)
CachedNameHasDrifted = ns.Profiler.Wrap("Name drift check", CachedNameHasDrifted)
RepairCachedName = ns.Profiler.Wrap("Text repair", RepairCachedName)

ns.NameplateText = {
    FinishCachedAppearance = FinishCachedAppearance,
    RepairBarGeometry = RepairBarGeometry,
    RepairPendingNameAppearance = RepairPendingNameAppearance,
    NameFontPath = NameFontPath,
    RepairNameOnly = RepairNameOnly,
    UpdateNameLayout = ns.Profiler.Wrap("Name layout update", UpdateNameLayout),
    SyncFullTitleVisibility = SyncFullTitleVisibility,
    StyleName = StyleName,
    RestoreOriginalBarHeight = RestoreOriginalBarHeight,
    ApplyConfiguredBarHeight = ApplyConfiguredBarHeight,
    RestoreNameDisplay = RestoreNameDisplay,
    CachedNameHasDrifted = CachedNameHasDrifted,
    RepairCachedName = RepairCachedName,
}
