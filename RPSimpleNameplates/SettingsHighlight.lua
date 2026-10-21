-- All interruptible-cast controls live on one page.
local _, addon = ...
local UI, Widgets = addon.SettingsUI, addon.SettingsWidgets
local function CreateHighlightPanel()
    local panel, content, layout = UI.CreateScrollablePanel("Cast Highlight")
    UI.AddTitle(content, layout, "Cast Highlight")
    local context = {content = content, layout = layout, refreshers = {}, sliders = {}}
    local function Refresh()
        UI.RunRefreshers(context.refreshers)
        layout:Reflow()
    end
    local function Changed()
        Refresh()
        UI.RefreshNameplates("castSettings")
    end
    local function CancelEdits(quiet)
        context.canceling = true
        local changed = false
        Widgets.CancelEdits(function()
            for _, slider in ipairs(context.sliders) do
                local previous = slider:GetValue()
                slider:CancelCombatEdit()
                if slider:GetValue() ~= previous then changed = true end
            end
        end)
        context.canceling = false
        if changed and not quiet then UI.RefreshNameplates("castSettings") end
    end
    addon.CancelHighlightEdits = CancelEdits
    addon.AddProfileSelector(content, layout, context.refreshers, Refresh)
    UI.AddPageAction(content, layout, "Reset cast highlight settings", function()
        addon.ResetHighlightSettings()
        Changed()
    end, 230)
    UI.AddDescription(content, layout,
        "Restores this profile's cast highlight activation, color, effect and border settings.")
    if addon.AddNameplatePreview then addon.AddNameplatePreview(context, true) end
    UI.AddSwitchRow(content, layout, context.refreshers, "Highlight interruptible casts",
        addon.GetInterruptibleHighlightEnabled, function(value)
            addon.SetInterruptibleHighlightEnabled(value)
            Changed()
        end)
    local row = UI.CreateSettingRow(content, layout, "Cast highlight color")
    local swatch = Widgets.CreateColorPicker(row, function(r, g, b)
        addon.SetEffectColor("interruptible", r, g, b)
        Changed()
    end, function() return addon.EffectColor("interruptible") end)
    swatch:SetPoint("LEFT", row, "LEFT", UI.CONTROL_X, 0)
    context.refreshers[#context.refreshers + 1] = function()
        swatch:SetColor(addon.EffectColor("interruptible"))
    end
    local _, effect = UI.CreateDropdownRow(content, layout, "Effect",
        function() return addon.CAST_EFFECT_OPTIONS end, function(value)
            addon.SetInterruptibleEffect(value)
            Changed()
        end)
    context.refreshers[#context.refreshers + 1] = function()
        local value = addon.GetInterruptibleEffect()
        effect:SetValue(value, addon.CAST_EFFECT_BY_VALUE[value])
    end
    UI.AddSection(content, layout, "Border settings")
    for _, kind in ipairs({"PULSE", "ALERT"}) do
        for _, definition in ipairs(addon.CAST_BORDER_CONTROLS[kind]) do
            local key = definition.key
            local shared = kind == "PULSE" and (key == "thickness" or key == "offset")
            local function Visible() return shared or addon.GetInterruptibleEffect() == kind end
            if key == "fadeIn" or key == "minLength" then
                UI.AddSection(content, layout, key == "fadeIn" and "Pulse settings" or "Alert settings")
                layout.items[#layout.items - 1].visibleWhen = Visible
                layout.items[#layout.items].visibleWhen = Visible
                UI.AddDescription(content, layout, key == "fadeIn"
                    and "Fades all four edges between 35% and 100% opacity."
                    or "Grows and shrinks centered segments on the top and bottom edges; side borders are hidden.")
                layout.items[#layout.items].visibleWhen = Visible
            end
            local block = CreateFrame("Frame", nil, content)
            block.LayoutFullWidth = true
            layout:Add(block, 24, 48, 6)
            layout.items[#layout.items].visibleWhen = Visible
            local label = block:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            label:SetPoint("TOPLEFT", 0, -12)
            label:SetText(definition.label)
            local amount = block:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            amount:SetPoint("TOPLEFT", UI.CONTROL_X + 188, -12)
            local slider = Widgets.CreateSlider(block, definition.min, definition.max, definition.step, function(value)
                amount:SetText(string.format("%g", value) .. definition.suffix)
                if value == addon.GetCastBorderSetting(kind, key) then return end
                addon.SetCastBorderSetting(kind, key, value)
                if not context.canceling then Changed() end
            end)
            slider:SetPoint("TOPLEFT", block, "TOPLEFT", UI.CONTROL_X, -10)
            slider:GetFrame():SetHeight(18)
            if slider.widget.amt then slider.widget.amt:Hide() end
            for _, endpoint in ipairs({{definition.min, "LEFT"}, {definition.max, "RIGHT"}}) do
                local caption = block:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                caption:SetText(string.format("%g", endpoint[1]))
                caption:SetPoint("TOP" .. endpoint[2], slider:GetFrame(), "BOTTOM" .. endpoint[2], 0, -2)
            end
            context.sliders[#context.sliders + 1] = slider
            context.refreshers[#context.refreshers + 1] = function()
                local value = addon.GetCastBorderSetting(kind, key)
                slider:SetValue(value)
                amount:SetText(string.format("%g", value) .. definition.suffix)
            end
        end
    end
    panel.Refresh = Refresh
    panel:SetScript("OnShow", Refresh)
    panel:SetScript("OnHide", function()
        CancelEdits()
        UI.CancelColorEdit()
        if context.StopPreview then context.StopPreview() end
    end)
    Refresh()
    layout:Finish()
    return panel
end
addon.SettingsPanels.Highlight = CreateHighlightPanel
