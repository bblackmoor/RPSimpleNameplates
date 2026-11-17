-- Simple Nameplates: title styling and cast visibility.
local _, ns = ...
local GetContext = ns.WorldContext.Get
local AccessibleBoolean = ns.AccessibleBoolean
local AccessibleNumber, AccessibleValue = ns.AccessibleNumber, ns.AccessibleValue
local FontPath = ns.FontPath
local GetAppearanceSetting = ns.GetAppearanceSetting
local GetHealthBar = ns.NameplateFrames.GetHealthBar
local GetCastBar = ns.NameplateFrames.GetCastBar

local function NameFontPath(context, profile)
    if context.sanctuary == true and GetAppearanceSetting("matchSanctuaryFont", profile) == true then
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
    return FontPath(GetAppearanceSetting("nameFont", profile))
end

local function EnsureFullTitleText(frame)
    if frame.RPSNFullTitleText then return frame.RPSNFullTitleText end
    -- Supply a template so the FontString is valid immediately, including
    -- during TRP3 callbacks that refresh a plate in the frame it is created.
    local fullTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fullTitle:SetJustifyH("LEFT")
    fullTitle:SetWordWrap(false)
    fullTitle:SetMaxLines(1)
    frame.RPSNFullTitleText = fullTitle
    return fullTitle
end

local function SetTitleShown(frame, title, desired, context)
    local actual = AccessibleBoolean(ns.PresentationCapabilities.ReadRegion(title, "IsShown", context))
    if (actual ~= nil and actual ~= desired) or (actual == nil
        and (frame.RPSNTitleDesiredRegion ~= title or frame.RPSNTitleDesired ~= desired)) then
        title:SetShown(desired)
    end
    frame.RPSNTitleDesiredRegion, frame.RPSNTitleDesired = title, desired
end

local function SyncFullTitleVisibility(frame, context, assessment, retrying)
    context = context or GetContext()
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess or frame.RPSNRestoring then return end
    local retry = retrying and frame.RPSNTitleVisibilityRetry
    if retry and ns.PeriodicWork.Now() < retry.due then return end
    frame.RPSNTitleVisibilityPending = nil
    local title, decision = frame.RPSNFullTitleText, frame.RPSNPresentation
    if not title then return end
    if not ns.GetStylingEnabled() or not frame.RPSNFullTitleAvailable
        or not decision or not decision.showFullTitle or decision.suppressText then
        frame.RPSNTitleVisibilityRetry = nil
        SetTitleShown(frame, title, false, context)
        return
    end
    local cast = assessment.castBar
    local shown = AccessibleBoolean(ns.PresentationCapabilities.ReadRegion(cast, "IsShown", context))
    if cast and shown == nil then
        frame.RPSNTitleVisibilityPending = true
        local delay = math.min((retry and retry.delay * 2 or 0.25), 4)
        frame.RPSNTitleVisibilityRetry = {due = ns.PeriodicWork.Now() + delay, delay = delay}
    else frame.RPSNTitleVisibilityRetry = nil end
    -- Unknown cast visibility must not put title text over a possible cast.
    local desired = not cast or shown == false
    SetTitleShown(frame, title, desired, context)
end

local function InstallTitleCastHooks(frame, cast)
    if not cast or type(cast.HookScript) ~= "function" or cast.RPSNTitleHookOwner == frame then return end
    local function Refresh()
        frame.RPSNTitleVisibilityPending = true
        frame.RPSNTitleVisibilityRetry = nil
        local context = GetContext()
        if GetCastBar(frame, context) == cast then SyncFullTitleVisibility(frame, context) end
    end
    cast:HookScript("OnShow", Refresh)
    cast:HookScript("OnHide", Refresh)
    cast.RPSNTitleHookOwner = frame
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
    if frame.RPSNFullTitleText then
        frame.RPSNFullTitleText:SetWidth(FullTitleWidth(frame, context, assessment))
    end
end

local function StyleFullTitle(frame, state, text, baseNameSize, decision, context, nameShade, assessment, profile)
    frame.RPSNTitleDesiredRegion, frame.RPSNTitleDesired = nil, nil
    local fullTitle = frame.RPSNFullTitleText
    local bar = GetHealthBar(frame, context, assessment)
    frame.RPSNFullTitleAvailable = text ~= nil and decision.showFullTitle == true
    if not frame.RPSNFullTitleAvailable then
        if fullTitle then fullTitle:SetText(""); fullTitle:Hide() end
        return
    end

    fullTitle = EnsureFullTitleText(frame)
    local titleSize = math.max(6, baseNameSize - 2)
    fullTitle:SetFont(NameFontPath(context, profile), titleSize, ns.FontFlags(profile))
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

ns.NameplateTitles = {
    NameFontPath = NameFontPath,
    SyncFullTitleVisibility = SyncFullTitleVisibility,
    ConstrainFullTitle = ConstrainFullTitle,
    StyleFullTitle = StyleFullTitle,
}
