-- Simple Nameplates: one decision shared by styling and Blizzard repair hooks.
local _, ns = ...
local Cap = ns.PresentationCapabilities
local GetContext = ns.WorldContext.Get
local Classify = ns.NameplateClassification.StateForUnit
local Resolve = ns.PresentationRules.Resolve
local Restore = ns.NameplateRestoration
local Text = ns.NameplateText
local SetShownSafe = ns.NameplateFrames.SetShownSafe
local InstallGeometryHook, RepairPendingGeometry

local function ApplyVisibility(frame, decision, assessment, context)
    SetShownSafe(assessment.healthBar, decision.showHealthBar, context)
    -- Keep the ancestor visible so name-only text is not concealed with the bar.
    SetShownSafe(frame.HealthBarsContainer, true, context)
    -- Native distance/detail transitions can fade the bar's subtree while its
    -- regions still report shown. Keep our displayed bar/name opaque locally;
    -- base-plate and unit-frame fades remain Blizzard-controlled.
    if decision.showHealthBar then
        for _, region in ipairs({assessment.healthBar, frame.HealthBarsContainer}) do
            local alpha = ns.AccessibleNumber(Cap.ReadRegion(region, "GetAlpha", context))
            if alpha ~= nil and alpha ~= 1 then region:SetAlpha(1) end
        end
    end
    -- Blizzard shows casts/channels and hides idle cast bars. Do not force an
    -- idle bar visible: the space below health belongs to the long title.
    -- Selection and classification visibility remain driven by Blizzard.
    for _, key in ipairs({"castBarAnchor"}) do
        SetShownSafe(frame[key], decision.showCombatIndicators, context)
    end
end

local appearanceKeys = {"nameFont", "threatFont", "nameSize", "namePlacement",
    "healthBarWidth", "useSlugRendering", "matchSanctuaryFont"}
local trpKeys = {"useRoleplayingName", "showShortTitle", "showFullTitle", "showOOC"}
local optionalSettings = {"GetGradientOpacity", "GetDimBackgroundNames",
    "GetThreatEnabled", "GetInterruptibleHighlightEnabled", "GetTRP3Enabled", "GetActiveProfileName"}

local function CaptureSettings(frame)
    local settings = {}
    for _, key in ipairs(appearanceKeys) do settings[key] = ns.GetAppearanceSetting(key) end
    for _, key in ipairs(trpKeys) do settings[key] = ns.GetTRP3Setting(key) end
    for _, key in ipairs(optionalSettings) do
        if ns[key] then settings[key] = ns[key]() end
    end
    frame.SNPStyleSettings = settings
end

local function SettingsAreCurrent(frame)
    local settings = frame.SNPStyleSettings
    if not settings then return false end
    for _, key in ipairs(appearanceKeys) do
        if settings[key] ~= ns.GetAppearanceSetting(key) then return false end
    end
    for _, key in ipairs(trpKeys) do
        if settings[key] ~= ns.GetTRP3Setting(key) then return false end
    end
    for _, key in ipairs(optionalSettings) do
        local value
        if ns[key] then value = ns[key]() end
        if settings[key] ~= value then return false end
    end
    return true
end

local function ApplyStyle(frame, context)
    context = context or GetContext()
    local assessment = Cap.InspectFrame(frame, context)
    if not assessment.canAccess then return end
    if frame.SNPRestoring then return end
    if Restore.IsPending(frame) then
        if not Restore.Request(frame, context) then return end
        assessment = Cap.InspectFrame(frame, context)
        if not assessment.canAccess then return end
    end
    local unit = ns.AccessibleValue(frame.unit)
    if type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
    if frame.SNPOriginalUnit and frame.SNPOriginalUnit ~= unit then
        if not Restore.Request(frame, context) then return end
        assessment = Cap.InspectFrame(frame, context)
        if not assessment.canAccess then return end
    end
    if frame.SNPOriginalVisibility and (frame.SNPOriginalHealthBar ~= assessment.healthBar
        or frame.SNPOriginalHealthBarsContainer ~= frame.HealthBarsContainer
        or frame.SNPOriginalName ~= assessment.name) then
        -- Release retired regions before capturing the replacement's baseline.
        if not Restore.Request(frame, context) then return end
        assessment = Cap.InspectFrame(frame, context)
        if not assessment.canAccess then return end
    end
    local state, _, facts = Classify(unit, context)
    local decision = Resolve(context, facts, state, assessment, ns.GetStylingEnabled(), ns.GetHealthBarEnabled(state))
    if decision.action ~= "style" then Restore.Request(frame, context); return end
    local previous = frame.SNPPresentation
    if previous and (previous.suppressText == true) ~= (decision.suppressText == true) then
        if not Restore.Request(frame, context) then return end
        assessment = Cap.InspectFrame(frame, context)
        if not assessment.canAccess then return end
        decision = Resolve(context, facts, state, assessment, ns.GetStylingEnabled(), ns.GetHealthBarEnabled(state))
        if decision.action ~= "style" then return end
    end
    Restore.Cancel(frame)
    Restore.Capture(frame, assessment, context)
    CaptureSettings(frame)
    frame.SNPStyledCastBar = assessment.castBar
    frame.SNPState, frame.SNPPresentation, frame.SNPEntityFacts = state, decision, facts
    InstallGeometryHook(frame, context)
    if decision.suppressText then
        Text.StyleName(frame, state, context, decision, assessment)
        return "text suppressed"
    end
    ns.NameplateFrames.ApplyBarWidth(frame, assessment, context)
    ApplyVisibility(frame, decision, assessment, context)
    ns.NameplateFrames.ApplyBarArtwork(frame, assessment, context)
    ns.NameplateThreat.UpdateThreatText(frame, state, context, decision)
    ns.NameplateFrames.LayoutHealthText(frame, assessment.healthBar, context)
    Text.StyleName(frame, state, context, decision, assessment)
    if decision.showHealthBar then assessment.healthBar:SetStatusBarColor(ns.PriorityColorForState(decision.colorState)) end
    ns.CastHighlight.UpdateInterruptibleHighlight(frame, context, decision)
    return "styled"
end
-- Native UI writes can invoke the repair hooks synchronously. Keep one
-- styling pass per frame and release the guard even if a write fails.
local function ApplySimpleStyle(frame, context, reason)
    context = context or GetContext()
    ns.Profiler.Count("Styling requests", reason or "unspecified")
    if not Cap.CanAccessFrame(frame, context) then
        ns.Profiler.Count("Styling outcomes", "inaccessible"); return
    end
    if frame.SNPRestoring or frame.SNPApplyingStyle or frame.SNPApplyingArtwork then
        ns.Profiler.Count("Styling outcomes", "guarded"); return
    end
    frame.SNPApplyingStyle = true
    local ok, result = pcall(ApplyStyle, frame, context)
    frame.SNPApplyingStyle = nil
    if not ok then
        ns.Profiler.Count("Styling outcomes", "failed")
        error(result, 0)
    end
    RepairPendingGeometry(frame)
    Text.RepairPendingNameAppearance(frame)
    ns.Profiler.Count("Styling outcomes", result or "deferred or native")
end

ApplySimpleStyle = ns.Profiler.Wrap("Full styling", ApplySimpleStyle)

-- Validate identity and configuration without collecting entity facts or titles.
-- Assessments stay operation-local; inaccessible frames retain their pending
-- work/restoration instead of borrowing a prior access decision.
local function PresentationIsCurrent(frame, assessment, context)
    local decision, expected = frame.SNPPresentation, frame.SNPNameStyle
    if not decision or not expected or not frame.SNPState then return false, "not initialized" end
    if Restore.IsPending(frame) then return false, "restoration pending" end
    if decision.action ~= "style" then return false, "presentation action" end
    if decision.contextRevision ~= context.revision then return false, "context revision" end
    if frame.SNPOriginalUnit ~= ns.AccessibleValue(frame.unit) then return false, "unit assignment" end
    if frame.SNPOriginalName ~= assessment.name then return false, "name region replaced" end
    if frame.SNPOriginalHealthBar ~= assessment.healthBar then return false, "health bar replaced" end
    if frame.SNPOriginalHealthBarsContainer ~= frame.HealthBarsContainer then return false, "container replaced" end
    if frame.SNPStyledCastBar ~= assessment.castBar then return false, "cast bar replaced" end
    if expected.presentation ~= decision then return false, "presentation cache" end
    if not SettingsAreCurrent(frame) then return false, "settings changed" end
    if not decision.suppressText then
        if expected.name ~= assessment.name or expected.bar ~= assessment.healthBar
            or not ns.FontPathMatches(expected.font, Text.NameFontPath(context))
            or (expected.inside and (not frame.SNPInsideName
                or frame.SNPInsideNameBar ~= assessment.healthBar)) then return false, "name cache" end
        local showBar = assessment.hasHealthBar == true and ns.GetHealthBarEnabled(frame.SNPState) ~= false
        if decision.showHealthBar ~= showBar then return false, "health-bar preference" end
    end
    local unit = ns.AccessibleValue(frame.unit)
    if type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return false, "unit token" end
    if UnitGUID then
        local ok, value = pcall(UnitGUID, unit)
        local guid = ok and ns.AccessibleValue(value)
        local previous = frame.SNPEntityFacts and frame.SNPEntityFacts.guid
        if type(guid) == "string" and type(previous) == "string" and guid ~= previous then return false, "unit identity" end
    end
    if UnitNameplateShowsWidgetsOnly then
        local ok, value = pcall(UnitNameplateShowsWidgetsOnly, unit)
        local widgetsOnly = ok and ns.AccessibleBoolean(value)
        if type(widgetsOnly) == "boolean" and widgetsOnly ~= (decision.suppressText == true) then return false, "widget mode" end
    end
    return true
end

local function RepairBarVisibility(frame, assessment, context)
    local decision = frame.SNPPresentation
    if decision.suppressText then return end
    local shown = ns.AccessibleBoolean(Cap.ReadRegion(assessment.healthBar, "IsShown", context))
    if shown ~= decision.showHealthBar then SetShownSafe(assessment.healthBar, decision.showHealthBar, context) end
    local container = frame.HealthBarsContainer
    if ns.AccessibleBoolean(Cap.ReadRegion(container, "IsShown", context)) ~= true then
        SetShownSafe(container, true, context)
    end
end

local function RepairBarColor(frame, assessment, context)
    local decision = frame.SNPPresentation
    if decision.suppressText then return end
    RepairBarVisibility(frame, assessment, context)
    if decision.showHealthBar then
        assessment.healthBar:SetStatusBarColor(ns.PriorityColorForState(decision.colorState))
    end
end

local function LayoutHasChanged(frame, context)
    local expected = frame.SNPNameStyle
    if expected.suppressed then return false end
    local inset, signature = ns.NameplateFrames.GetHealthTextInsetRegion(frame, expected.bar, context)
    return inset ~= expected.rightRegion or signature ~= expected.healthTextSignature
end

local function PerformDataUpdate(frame, assessment, context, work)
    local state, decision = frame.SNPState, frame.SNPPresentation
    local nameChanged, colorChanged = work.name, false
    if work.classify then
        local unit = ns.AccessibleValue(frame.unit)
        if type(unit) ~= "string" then return "full" end
        local nextState, _, facts = Classify(unit, context)
        local nextDecision = Resolve(context, facts, nextState, assessment,
            ns.GetStylingEnabled(), ns.GetHealthBarEnabled(nextState))
        if nextDecision.action ~= "style" or nextDecision.suppressText ~= decision.suppressText
            or nextDecision.showHealthBar ~= decision.showHealthBar
            or nextDecision.nameOnly ~= decision.nameOnly then return "full" end
        local oldFacts = frame.SNPEntityFacts
        colorChanged = nextState ~= state
        nameChanged = nameChanged or colorChanged or facts.npcTitle ~= (oldFacts and oldFacts.npcTitle)
        -- Keep the cached presentation identity when its structure is unchanged.
        decision.state, decision.colorState = nextState, nextState
        frame.SNPState, frame.SNPEntityFacts = nextState, facts
        state = nextState
    end
    if work.threat and not decision.suppressText then
        ns.NameplateThreat.UpdateThreatValue(frame, state, context, decision)
    end
    if colorChanged then RepairBarColor(frame, assessment, context) end
    if nameChanged then
        Text.StyleName(frame, state, context, decision, assessment)
    elseif work.layout or (work.threat and LayoutHasChanged(frame, context)) then
        Text.UpdateNameLayout(frame, context, decision, assessment)
    end
    if work.cast then
        ns.CastHighlight.UpdateInterruptibleHighlight(frame, context, decision)
        Text.SyncFullTitleVisibility(frame, context, assessment)
    end
end

local function PerformNameRepair(frame, assessment, context)
    local source = ns.AccessibleValue(UnitName(frame.unit))
    local expected = frame.SNPNameStyle
    local previous = ns.AccessibleValue(expected.unitName)
    if not expected.suppressed and type(source) == "string" and type(previous) == "string"
        and source ~= previous then
        return PerformDataUpdate(frame, assessment, context, {classify = true, name = true})
    end
    Text.RepairNameOnly(frame, context, assessment)
    RepairBarVisibility(frame, assessment, context)
    if LayoutHasChanged(frame, context) then Text.UpdateNameLayout(frame, context, frame.SNPPresentation, assessment) end
end

local function FocusedUpdate(frame, context, work, kind)
    context = context or GetContext()
    ns.Profiler.Count("Focused requests", kind)
    -- CompactUnitFrame hooks also service raid/party frames and cleared native
    -- frames. They are not pending nameplates and must not request styling.
    local unit = ns.AccessibleValue(Cap.SafeField(frame, "unit", context))
    if type(unit) ~= "string" or not unit:match("^nameplate%d+$") then
        ns.Profiler.Count("Focused outcomes", "not a nameplate")
        return
    end
    local assessment = Cap.InspectFrame(frame, context)
    if not assessment.canAccess then ns.Profiler.Count("Focused outcomes", "inaccessible"); return end
    if frame.SNPRestoring or frame.SNPApplyingStyle or frame.SNPApplyingArtwork then
        ns.Profiler.Count("Focused outcomes", "guarded"); return
    end
    if not ns.GetStylingEnabled() then
        local restored = Restore.Request(frame, context)
        ns.Profiler.Count("Focused outcomes", restored and "native/restored" or "restoration pending")
        return
    end
    local current, reason = PresentationIsCurrent(frame, assessment, context)
    if not current then
        ns.Profiler.Count("Focused outcomes", "invalid-cache fallback")
        ns.Profiler.Count("Focused cache invalidation", reason)
        return ApplySimpleStyle(frame, context, kind .. " fallback")
    end
    frame.SNPApplyingStyle = true
    local ok, result
    if kind == "name hook" then ok, result = pcall(PerformNameRepair, frame, assessment, context)
    elseif kind == "health-color hook" then ok, result = pcall(RepairBarColor, frame, assessment, context)
    else ok, result = pcall(PerformDataUpdate, frame, assessment, context, work) end
    frame.SNPApplyingStyle = nil
    if not ok then
        ns.Profiler.Count("Focused outcomes", "failed")
        error(result, 0)
    end
    if result == "full" then
        ns.Profiler.Count("Focused outcomes", "presentation-change fallback")
        return ApplySimpleStyle(frame, context, kind .. " fallback")
    end
    -- A real native layout/show callback can reset artwork during a focused
    -- write. Service that callback after releasing the shared reentry guard.
    if frame.SNPArtworkPending then
        local current = Cap.InspectFrame(frame, context)
        if current.canAccess then ns.NameplateFrames.ApplyBarArtwork(frame, current, context) end
    end
    RepairPendingGeometry(frame)
    Text.RepairPendingNameAppearance(frame)
    ns.Profiler.Count("Focused outcomes", "updated")
end

local function RepairName(frame, context) return FocusedUpdate(frame, context, nil, "name hook") end
local function RepairHealthColor(frame, context) return FocusedUpdate(frame, context, nil, "health-color hook") end
local function UpdateData(frame, context, work) return FocusedUpdate(frame, context, work, "data update") end

local function RepairGeometry(frame, sourceBar)
    local context = GetContext()
    local assessment = Cap.InspectFrame(frame, context)
    if not assessment.canAccess or frame.SNPRestoring or not ns.GetStylingEnabled() then return end
    if sourceBar and sourceBar ~= assessment.healthBar and sourceBar ~= frame.HealthBarsContainer then return end
    if frame.SNPApplyingStyle or frame.SNPApplyingArtwork then frame.SNPGeometryPending = true; return end
    if not PresentationIsCurrent(frame, assessment, context) then return end
    ns.Profiler.Count("Geometry hook", "current presentation")
    Text.RepairBarGeometry(frame, context, assessment)
end
RepairGeometry = ns.Profiler.Wrap("Geometry hook repair", RepairGeometry)
local visibilityHookOwners = setmetatable({}, {__mode = "k"})
local alphaHookOwners = setmetatable({}, {__mode = "k"})
InstallGeometryHook = function(frame, context)
    if not frame.SNPGeometryHookInstalled and hooksecurefunc
        and type(Cap.SafeField(frame, "UpdateAnchors", context)) == "function" then
        hooksecurefunc(frame, "UpdateAnchors", function() RepairGeometry(frame) end)
        frame.SNPGeometryHookInstalled = true
    end
    local bar = Cap.SafeField(frame, "healthBar", context)
        or Cap.SafeField(Cap.SafeField(frame, "HealthBarsContainer", context), "healthBar", context)
    local regions = {bar, Cap.SafeField(frame, "HealthBarsContainer", context)}
    for _, region in pairs(regions) do
        if not visibilityHookOwners[region] and type(Cap.SafeField(region, "HookScript", context)) == "function" then
            region:HookScript("OnHide", function() RepairGeometry(frame, region) end)
            region:HookScript("OnShow", function() RepairGeometry(frame, region) end)
            visibilityHookOwners[region] = frame
        end
        if hooksecurefunc and not alphaHookOwners[region]
            and type(Cap.SafeField(region, "SetAlpha", context)) == "function" then
            hooksecurefunc(region, "SetAlpha", function() RepairGeometry(frame, region) end)
            alphaHookOwners[region] = frame
        end
    end
end
RepairPendingGeometry = function(frame)
    if not frame.SNPGeometryPending then return end
    frame.SNPGeometryPending = nil
    RepairGeometry(frame)
end

-- Native getters may invoke the name hook before the ADDED handler obtains
-- its frame. Reuse that completed style and only refresh data on the late pass.
local function InitializeOrRefresh(frame, context, reason)
    local assessment = Cap.InspectFrame(frame, context)
    if assessment.canAccess and PresentationIsCurrent(frame, assessment, context) then
        ns.Profiler.Count("Initialization", "reused " .. reason)
        return UpdateData(frame, context, {classify = true, name = true, threat = true, cast = true, layout = true})
    end
    return ApplySimpleStyle(frame, context, reason)
end

ns.NameplatePresentation = {
    RepairPendingGeometry = RepairPendingGeometry,
    InitializeOrRefresh = InitializeOrRefresh,
    ApplySimpleStyle = ApplySimpleStyle,
    RepairHealthColor = ns.Profiler.Wrap("Health-color repair", RepairHealthColor),
    RepairName = ns.Profiler.Wrap("Name hook repair", RepairName),
    UpdateData = ns.Profiler.Wrap("Data update", UpdateData),
    RestoreFrame = Restore.Request,
}
