-- Shared sample renderer. Preview values never query native unit health or threat.
local _, addon = ...
local UI = addon.SettingsUI
local previews = {}
local WHITE = "Interface\\Buttons\\WHITE8X8"
local states = {
    {value="attacking", label="Attacking me"}, {value="hostile", label="Hostile"},
    {value="neutral", label="Neutral"}, {value="friendly", label="Friendly player"},
    {value="useful", label="Interactive NPC"}, {value="useless", label="Background NPC"},
}
function addon.RefreshSettingsPreviews()
    for _, preview in ipairs(previews) do
        if preview.panel:IsShown() then preview.Refresh() end
    end
end
function addon.AddNameplatePreview(context, castingDefault)
    local content, layout = context.content, context.layout
    local panel = content:GetParent():GetParent()
    local state, casting = "hostile", castingDefault == true
    UI.AddSection(content, layout, "Nameplate preview")
    local _, category = UI.CreateDropdownRow(content, layout, "Sample category", function() return states end, function(value)
        state = value
        context.RefreshPreview()
    end)
    local row = CreateFrame("Frame", nil, content)
    row.LayoutFullWidth = true
    layout:Add(row, 24, 140, 8)
    local health = CreateFrame("StatusBar", nil, row)
    health:SetStatusBarTexture(WHITE)
    health:SetMinMaxValues(0, 100)
    health:SetValue(65)
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(health)
    background:SetColorTexture(0.12, 0.12, 0.12, 1)
    -- Text must render above child status bars without inheriting bar visibility.
    local overlay = CreateFrame("Frame", nil, row)
    overlay:SetAllPoints(row)
    overlay:SetFrameLevel(health:GetFrameLevel() + 2)
    local name = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local title = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local threat = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local cast = CreateFrame("StatusBar", nil, row)
    cast:SetStatusBarTexture(WHITE)
    cast:SetStatusBarColor(0.65, 0.5, 0.15, 1)
    cast:SetMinMaxValues(0, 100)
    cast:SetValue(55)
    local spell = cast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spell:SetAllPoints(cast)
    spell:SetText("Sample interruptible cast")
    local refresh
    local toggle = UI.AddSwitchRow(content, layout, context.refreshers, "Preview a cast",
        function() return casting end, function(value) casting = value; refresh() end)
    UI.AddDescription(content, layout, "Sample values only. Casts temporarily replace titles. Preview controls do not change your profile.")
    local function Stop()
        if addon.CastHighlight then addon.CastHighlight.StopPreview(cast) end
    end
    refresh = function()
        local size = addon.GetAppearanceSetting("nameSize")
        local font = addon.FontPath(addon.GetAppearanceSetting("nameFont"))
        if addon.NameplateText and addon.WorldContext then
            font = addon.NameplateText.NameFontPath(addon.WorldContext.Get())
        end
        local flags = addon.FontFlags and addon.FontFlags() or "OUTLINE"
        local barShown = addon.GetHealthBarEnabled(state)
        local inside = barShown and addon.GetAppearanceSetting("namePlacement") == "INSIDE"
        local width = 190 * addon.GetAppearanceSetting("healthBarWidth") / 100
        local height = inside and size + 7 or 14
        local r, g, b = addon.PriorityColorForState(state)
        local dim = state == "useless" and addon.GetDimBackgroundNames()
        health:ClearAllPoints()
        health:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -size - 8)
        health:SetSize(width, height)
        health:SetStatusBarColor(r, g, b, 1)
        health:SetShown(barShown)
        background:SetShown(barShown)
        name:ClearAllPoints()
        name:SetFont(font, size, flags)
        name:SetPoint(inside and "LEFT" or "BOTTOMLEFT", health, inside and "LEFT" or "TOPLEFT", inside and 3 or 0, inside and -0.5 or 3)
        local showThreat = barShown and addon.GetThreatEnabled()
        name:SetWidth(math.max(1, width - (showThreat and size * 3.5 or 6)))
        name:SetJustifyH("LEFT")
        name:SetText("Sample Name")
        if state == "useless" then
            local shade = dim and 0.6 or 1
            name:SetTextColor(shade, shade, shade, 1)
        elseif barShown then name:SetTextColor(1, 1, 1, 1)
        else name:SetTextColor(r, g, b, 1) end
        threat:ClearAllPoints()
        threat:SetFont(addon.FontPath(addon.GetAppearanceSetting("threatFont")), size, flags)
        threat:SetPoint("RIGHT", health, "RIGHT", -3, -0.5)
        threat:SetText("125%")
        threat:SetTextColor(1, 1, 1, 1)
        threat:SetShown(showThreat)
        title:ClearAllPoints()
        title:SetFont(font, math.max(6, size - 2), flags)
        title:SetPoint("TOP", barShown and health or name, "BOTTOM", 0, -1)
        title:SetText("Sample title")
        title:SetWidth(width)
        title:SetJustifyH("CENTER")
        if dim then title:SetTextColor(0.6, 0.6, 0.6, 1) else title:SetTextColor(1, 1, 1, 1) end
        title:SetShown(not casting)
        cast:ClearAllPoints()
        cast:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -5)
        cast:SetSize(width, 18)
        spell:SetFont(font, 12, flags)
        spell:SetTextColor(1, 1, 1, 1)
        cast:SetShown(casting)
        cast:SetAlpha(addon.GetInterruptibleHighlightEnabled() and 1 or 0.5)
        if addon.HealthGradient and addon.WorldContext then
            addon.HealthGradient.Apply(health, health:GetStatusBarTexture(), addon.WorldContext.Get())
        end
        if casting and panel:IsShown() then
            if addon.CastHighlight then addon.CastHighlight.UpdatePreview(cast) end
        else Stop() end
        for _, text in ipairs({name, title, threat, spell}) do
            text:SetWordWrap(false)
            text:SetMaxLines(1)
            text:SetShadowColor(0, 0, 0, 0)
            text:SetShadowOffset(0, 0)
        end
        category:SetValue(state)
        toggle:SetChecked(casting)
    end
    context.RefreshPreview, context.StopPreview = refresh, Stop
    context.refreshers[#context.refreshers + 1] = refresh
    previews[#previews + 1] = {panel = panel, Refresh = refresh}
    row:HookScript("OnHide", Stop)
    -- Expose the rendered sample for fixture checks without native plate access.
    context.sample = {health=health, name=name, title=title, threat=threat, cast=cast}
    refresh()
end
