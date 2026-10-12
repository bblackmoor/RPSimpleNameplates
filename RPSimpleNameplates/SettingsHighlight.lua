-- Simple Nameplates: interruptible border effects and shared previews.
local _, addon = ...
local UI, Widgets = addon.SettingsUI, addon.SettingsWidgets
local AddSection, AddDescription, RunRefreshers, RefreshNameplates =
    UI.AddSection, UI.AddDescription, UI.RunRefreshers, UI.RefreshNameplates
local function RefreshContext(context) RunRefreshers(context.refreshers) end

local function AddCastBorderControls(context)
    for _, effect in ipairs({"PULSE", "ALERT"}) do
        for _, definition in ipairs(addon.CAST_BORDER_CONTROLS[effect]) do
            local key = definition.key
            if key == "fadeIn" then
                AddSection(context.content, context.layout, "Pulse settings")
                AddDescription(context.content, context.layout,
                    "Pulsing border fades all four edges between 35% and 100% opacity.")
            elseif key == "minLength" then
                AddSection(context.content, context.layout, "Alert settings")
                AddDescription(context.content, context.layout,
                    "Alert border shrinks and grows centered gradient segments on the top and bottom edges. Length is a percentage of the edge; thickness stays constant. Side borders are hidden.")
            end
            local block = CreateFrame("Frame", nil, context.content)
            block.LayoutFullWidth = true
            context.layout:Add(block, 24, 48, 6)
            local label = block:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            label:SetPoint("TOPLEFT", 0, -12)
            label:SetText(definition.label)
            local amount = block:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            amount:SetPoint("TOPLEFT", UI.CONTROL_X + 188, -12)
            local slider = Widgets.CreateSlider(block, definition.min, definition.max, definition.step, function(value)
                amount:SetText(string.format("%g", value) .. definition.suffix)
                if value == addon.GetCastBorderSetting(effect, key) then return end
                addon.SetCastBorderSetting(effect, key, value)
                if not context.canceling then RefreshContext(context); RefreshNameplates() end
            end)
            slider:SetPoint("TOPLEFT", block, "TOPLEFT", UI.CONTROL_X, -10)
            slider:GetFrame():SetHeight(18)
            if slider.widget.amt then slider.widget.amt:Hide() end
            for _, endpoint in ipairs({{definition.min, "LEFT"}, {definition.max, "RIGHT"}}) do
                local caption = block:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                caption:SetText(string.format("%g", endpoint[1]))
                caption:SetPoint("TOP"..endpoint[2], slider:GetFrame(), "BOTTOM"..endpoint[2], 0, -2)
            end
            context.sliders[#context.sliders + 1] = slider
            context.refreshers[#context.refreshers + 1] = function()
                local value = addon.GetCastBorderSetting(effect, key)
                slider:SetValue(value)
                amount:SetText(string.format("%g", value) .. definition.suffix)
            end
        end
    end
end

local function AddCastEffectControl(context)
    local _, dropdown = UI.CreateDropdownRow(context.content, context.layout, "Effect",
        function() return addon.CAST_EFFECT_OPTIONS end, function(value)
            addon.SetInterruptibleEffect(value)
            RefreshContext(context)
            RefreshNameplates()
        end)
    context.refreshers[#context.refreshers + 1] = function()
        local value = addon.GetInterruptibleEffect()
        dropdown:SetValue(value, addon.CAST_EFFECT_BY_VALUE[value])
    end
end

local function AddCastEffectPreview(context)
    local row, label = UI.CreateSettingRow(context.content, context.layout, "Effect preview")
    local preview = CreateFrame("StatusBar", nil, row)
    preview:SetPoint("LEFT", row, "LEFT", UI.CONTROL_X, 0)
    preview:SetSize(190, 14)
    preview:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    preview:SetStatusBarColor(0.25, 0.25, 0.25, 1)
    preview:SetMinMaxValues(0, 100)
    preview:SetValue(65)
    context.preview = preview
    context.refreshers[#context.refreshers + 1] = function()
        local active = addon.GetInterruptibleHighlightEnabled()
        preview:SetAlpha(active and 1 or 0.5)
        local shade = active and 1 or 0.5
        label:SetTextColor(shade, shade, shade)
        if addon.CastHighlight then addon.CastHighlight.UpdatePreview(preview) end
    end
end

addon.AddCastEffectPreview = AddCastEffectPreview

local function CreateHighlightPanel()
    local panel, content, layout = UI.CreateScrollablePanel("Highlight")
    UI.AddTitle(content, layout, "Highlight")
    local context = {content = content, layout = layout, refreshers = {}, sliders = {}}
    local function CancelEdits(quiet)
        context.canceling = true
        local changed = false
        Widgets.CancelEdits(function()
            for _, slider in ipairs(context.sliders) do
                local old = slider:GetValue()
                slider:CancelCombatEdit()
                if old ~= slider:GetValue() then changed = true end
            end
        end)
        context.canceling = false
        if changed and not quiet then RefreshNameplates() end
    end
    addon.CancelHighlightEdits = CancelEdits
    local function Refresh() RefreshContext(context) end
    addon.AddProfileSelector(content, layout, context.refreshers, Refresh)
    UI.AddPageAction(content, layout, "Reset highlight settings", function()
        addon.ResetHighlightSettings()
        Refresh()
        RefreshNameplates()
    end)
    AddDescription(content, layout,
        "Restores this profile’s effect, border geometry, Pulse and Alert settings. Color and Active are on Colors and are preserved.")
    AddCastEffectControl(context)
    AddCastEffectPreview(context)
    AddSection(content, layout, "Border settings")
    AddCastBorderControls(context)
    panel.Refresh = Refresh
    panel:SetScript("OnShow", Refresh)
    panel:SetScript("OnHide", function()
        CancelEdits()
        if addon.CastHighlight then addon.CastHighlight.StopPreview(context.preview) end
    end)
    Refresh()
    layout:Finish()
    return panel
end
addon.SettingsPanels.Highlight = CreateHighlightPanel
