-- Simple Nameplates: optional threat percentage rendered by WoW's text API.
local _, ns = ...
local CanAccessFrame = ns.PresentationCapabilities.CanAccessFrame
local GetContext = ns.WorldContext.Get
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local AccessibleNumber, FontPath = ns.AccessibleNumber, ns.FontPath
local GetAppearanceSetting, GetThreatEnabled = ns.GetAppearanceSetting, ns.GetThreatEnabled
local GetHealthBar = ns.NameplateFrames.GetHealthBar

local function ClearThreatText(frame, reason)
    frame.SNPThreatStatus = reason
    if frame.SNPThreatText then
        frame.SNPThreatText:SetText("")
        frame.SNPThreatText:Hide()
    end
end

local function EnsureThreatText(frame, bar)
    if frame.SNPThreatText and frame.SNPThreatTextBar == bar then return frame.SNPThreatText, false end
    if frame.SNPThreatText then frame.SNPThreatText:Hide() end
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetDrawLayer("OVERLAY", 7)
    text:SetPoint("RIGHT", bar, "RIGHT", -3, -0.5)
    text:SetJustifyH("RIGHT")
    text:SetWordWrap(false)
    text:SetMaxLines(1)
    frame.SNPThreatText, frame.SNPThreatTextBar = text, bar
    return text, true
end

local function RenderPercent(text, value)
    -- SetFormattedText accepts secret arguments. Pass them straight through:
    -- never compare, concatenate, or calculate with a secret percentage.
    if not (issecretvalue and issecretvalue(value)) then
        value = AccessibleNumber(value)
        if value == nil then return false end
    end
    return pcall(text.SetFormattedText, text, "%.0f%%", value)
end

local function UpdateThreatText(frame, state, context, decision, configure)
    context = context or GetContext()
    if not CanAccessFrame(frame, context) then return end
    if not GetThreatEnabled() then ClearThreatText(frame, "disabled"); return end
    local bar = GetHealthBar(frame, context)
    if not decision or not decision.showHealthBar or not bar then
        ClearThreatText(frame, "no displayed health bar"); return
    end
    local text, created = EnsureThreatText(frame, bar)
    if configure ~= false or created then
        text:SetTextColor(1, 1, 1, 1)
        text:SetFont(FontPath(GetAppearanceSetting("threatFont")), GetAppearanceSetting("nameSize") or 12, ns.FontFlags())
        text:SetShadowColor(0, 0, 0, 0)
        text:SetShadowOffset(0, 0)
    end
    local ok, _, _, scaled = pcall(UnitDetailedThreatSituation, "player", frame.unit)
    if not ok then ClearThreatText(frame, "threat API unavailable"); return end
    -- scaledPercentage is the useful 0-100 "how close am I to pulling aggro"
    -- value. rawPercentage can pin at 255 once the player is tanking.
    if RenderPercent(text, scaled) then frame.SNPThreatStatus = "displayed scaled percentage"
    else ClearThreatText(frame, "no displayable threat percentage"); return end
    text:Show()
end

ns.NameplateThreat = {UpdateThreatText = UpdateThreatText,
    UpdateThreatValue = function(frame, state, context, decision)
        return UpdateThreatText(frame, state, context, decision, false)
    end,
}
