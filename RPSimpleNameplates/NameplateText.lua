-- Simple Nameplates: text selection and styling orchestration.
local _, ns = ...
local GetContext = ns.WorldContext.Get
local UnitName = UnitName
local AccessibleNumber, AccessibleValue = ns.AccessibleNumber, ns.AccessibleValue
local PriorityColorForState, FontPath = ns.PriorityColorForState, ns.FontPath
local GetAppearanceSetting, GetTRP3Setting = ns.GetAppearanceSetting, ns.GetTRP3Setting
local GetHealthBar = ns.NameplateFrames.GetHealthBar


local NameFontPath = ns.NameplateTitles.NameFontPath
local SyncFullTitleVisibility = ns.NameplateTitles.SyncFullTitleVisibility
local StyleFullTitle = ns.NameplateTitles.StyleFullTitle
local RestoreOriginalBarHeight = ns.NameplateLayout.RestoreOriginalBarHeight
local ApplyConfiguredBarHeight = ns.NameplateLayout.ApplyConfiguredBarHeight
local PositionName = ns.NameplateLayout.PositionName
local ShowInsideName = ns.NameplateLayout.ShowInsideName
local RestoreNameDisplay = ns.NameplateLayout.RestoreNameDisplay
local CacheNameStyle = ns.NameplateLayout.CacheNameStyle
local SuppressText = ns.NameplateLayout.SuppressText
local RepairNameOnly = ns.NameplateLayout.RepairNameOnly
local UpdateNameLayout = ns.NameplateLayout.UpdateNameLayout
local CachedNameHasDrifted = ns.NameplateTextRepair.CachedNameHasDrifted
local RepairCachedName = ns.NameplateTextRepair.RepairCachedName
local RepairBarGeometry = ns.NameplateTextRepair.RepairBarGeometry
local RepairPendingNameAppearance = ns.NameplateTextRepair.RepairPendingNameAppearance
local InstallNameAppearanceHooks = ns.NameplateTextRepair.InstallNameAppearanceHooks
local FinishCachedAppearance = ns.NameplateTextRepair.FinishCachedAppearance

local function UpdateNameText(frame)
    local name, unit = frame and frame.name, frame and frame.unit
    if not name or not unit then return nil end
    -- UnitName can be secret in Midnight. FontString:SetText can display that
    -- value directly; do not replace it with an empty string.
    local unitName = UnitName(unit)
    local displayName = unitName
    local fullTitle = frame.RPSNEntityFacts and frame.RPSNEntityFacts.npcTitle
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

local function StyleName(frame, state, context, decision, assessment, profile)
    profile = profile or (ns.GetActiveProfile and ns.GetActiveProfile())
    context = context or GetContext()
    assessment = assessment or ns.PresentationCapabilities.InspectFrame(frame, context)
    if not assessment.canAccess then return end
    if not decision or decision.action ~= "style" then return end
    if decision.suppressText then
        SuppressText(frame, context)
        frame.RPSNNameStyle = {suppressed = true, presentation = decision, name = frame.name,
            bar = assessment.healthBar, unit = AccessibleValue(frame.unit)}
        InstallNameAppearanceHooks(frame, frame.name, context)
        return
    end
    local name = frame and frame.name
    if not name then return end
    local fullTitle, displayName, unitName = UpdateNameText(frame)
    local baseSize = GetAppearanceSetting("nameSize", profile) or 12
    local bar = GetHealthBar(frame, context, assessment)
    local nameOnly = decision.nameOnly
    local inside, size = ApplyConfiguredBarHeight(frame, state, bar, baseSize, context, decision, assessment, profile)
    local rightInset = -3

    local fontPath = NameFontPath(context, profile)
    name:SetFont(fontPath, size, ns.FontFlags(profile))
    name:SetShadowColor(0, 0, 0, 0)
    name:SetShadowOffset(0, 0)
    local nameR, nameG, nameB = 1, 1, 1
    if nameOnly then nameR, nameG, nameB = PriorityColorForState(decision.colorState or state, profile)
    end
    if state == "useless" then
        local shade = ns.GetDimBackgroundNames and ns.GetDimBackgroundNames(profile) and 153 / 255 or 1
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
        ShowInsideName(frame, bar, displayName, fontPath, size, rightInset, rightRegion, nameR, profile)
    else
        RestoreNameDisplay(frame, context, assessment)
    end
    StyleFullTitle(frame, state, fullTitle, baseSize, decision, context, nameR, assessment, profile)
    CacheNameStyle(frame, displayName, fontPath, size, nameR, nameG, nameB,
        nameOnly, inside, rightInset, bar, rightRegion, profile)
    frame.RPSNNameStyle.unitName = unitName
    frame.RPSNNameStyle.presentation = decision
    frame.RPSNNameStyle.healthTextSignature = healthTextSignature
    -- Calibrate against the completed color write. Some FontString color
    -- getters expose shared text/vertex state; grey must not be treated as
    -- unwanted vertex tint and reset to white on every periodic visit.
    local getter = ns.PresentationCapabilities.SafeField(name, "GetVertexColor", context)
    local ok, r, g, b, a
    if type(getter) == "function" then ok, r, g, b, a = pcall(getter, name) end
    r, g, b, a = AccessibleNumber(r), AccessibleNumber(g), AccessibleNumber(b), AccessibleNumber(a)
    frame.RPSNNameStyle.vertexColor = ok and r and g and b and a and {r, g, b, a} or nil
    InstallNameAppearanceHooks(frame, name, context)
end

-- Focused native-name repair. No classification, profile lookup, bar artwork
-- or geometry writes; the runtime refresh handles actual content changes.
StyleName = ns.Profiler.Wrap("Name/title styling", StyleName)

ns.NameplateText = {
    FinishCachedAppearance = FinishCachedAppearance,
    RepairBarGeometry = RepairBarGeometry,
    RepairPendingNameAppearance = RepairPendingNameAppearance,
    NameFontPath = NameFontPath,
    RepairNameOnly = RepairNameOnly,
    UpdateNameLayout = UpdateNameLayout,
    SyncFullTitleVisibility = SyncFullTitleVisibility,
    StyleName = StyleName,
    RestoreOriginalBarHeight = RestoreOriginalBarHeight,
    ApplyConfiguredBarHeight = ApplyConfiguredBarHeight,
    RestoreNameDisplay = RestoreNameDisplay,
    CachedNameHasDrifted = CachedNameHasDrifted,
    RepairCachedName = RepairCachedName,
}
