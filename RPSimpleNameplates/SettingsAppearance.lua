-- Simple Nameplates: profile appearance and global critter visibility.
local _, addon = ...
local UI, Widgets = addon.SettingsUI, addon.SettingsWidgets
local function Refresh(context) UI.RunRefreshers(context.refreshers) end

local function AddToggle(context, label, getter, setter, onChanged)
    UI.AddSwitchRow(context.content, context.layout, context.refreshers, label, getter, function(value)
        setter(value)
        if onChanged then onChanged() end
    end)
end

local function AddFont(context, label, key)
    local selected
    local _, dropdown = UI.CreateDropdownRow(context.content, context.layout, label, function()
        return addon.GetFontOptions(addon.GetAppearanceSetting(key))
    end, function(value)
        addon.SetAppearanceSetting(key, value)
        Refresh(context)
        UI.RefreshNameplates()
    end)
    local function RefreshFont()
        local value = addon.GetAppearanceSetting(key)
        if value ~= selected then dropdown:InvalidateOptions(); selected = value end
        dropdown:SetValue(value, addon.FontLabel(value))
    end
    context.refreshers[#context.refreshers + 1] = RefreshFont
    context.fontRefreshers[#context.fontRefreshers + 1] = function()
        dropdown:InvalidateOptions() -- Rebuild only on the next menu opening.
        RefreshFont()
    end
end

local function AddSize(context, key, label, minimum, maximum, step, suffix)
    local block = CreateFrame("Frame", nil, context.content)
    block.LayoutFullWidth = true
    context.layout:Add(block, 24, 48, 6)
    local text = block:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 0, -12)
    text:SetText(label)
    local amount = block:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    amount:SetPoint("TOPLEFT", UI.CONTROL_X + 188, -12)
    local slider = Widgets.CreateSlider(block, minimum, maximum, step, function(value)
        amount:SetText(tostring(value) .. suffix)
        if value == addon.GetAppearanceSetting(key) then return end
        addon.SetAppearanceSetting(key, value)
        if not context.canceling then UI.RefreshNameplates() end
    end)
    slider:SetPoint("TOPLEFT", block, "TOPLEFT", UI.CONTROL_X, -10)
    slider:GetFrame():SetHeight(18)
    slider.widget.amt:Hide() -- The existing adjacent value label carries units.
    for _, endpoint in ipairs({{minimum, "LEFT"}, {maximum, "RIGHT"}}) do
        local caption = block:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        caption:SetText(tostring(endpoint[1]))
        caption:SetPoint("TOP" .. endpoint[2], slider:GetFrame(), "BOTTOM" .. endpoint[2], 0, -2)
    end
    context.sliders[#context.sliders + 1] = slider
    context.refreshers[#context.refreshers + 1] = function()
        local value = addon.GetAppearanceSetting(key)
        slider:SetValue(value)
        amount:SetText(tostring(value) .. suffix)
    end
end

local function AddPlacement(context)
    local options = {{value = "ABOVE", label = "Above bar"}, {value = "INSIDE", label = "Inside bar"}}
    local _, dropdown = UI.CreateDropdownRow(context.content, context.layout, "Health-bar name placement", function() return options end, function(value)
        addon.SetAppearanceSetting("namePlacement", value)
        Refresh(context)
        UI.RefreshNameplates()
    end)
    context.refreshers[#context.refreshers + 1] = function()
        dropdown:SetValue(addon.GetAppearanceSetting("namePlacement"))
    end
end

local function AddControls(context)
    local content, layout = context.content, context.layout
    UI.AddSection(content, layout, "Fonts and sizing")
    AddFont(context, "Name font", "nameFont")
    UI.AddDescription(content, layout, "Includes fonts registered by other addons and SharedMedia packs.")
    AddToggle(context, "Use smoother font rendering (Slug)",
        function() return addon.GetAppearanceSetting("useSlugRendering") end,
        function(value) addon.SetAppearanceSetting("useSlugRendering", value) end, UI.RefreshNameplates)
    UI.AddDescription(content, layout,
        "Applies to names, titles, health, threat and cast text. Uses thin solid outlines on all styled text.")
    AddToggle(context, "Match Blizzard font in sanctuaries",
        function() return addon.GetAppearanceSetting("matchSanctuaryFont") end,
        function(value) addon.SetAppearanceSetting("matchSanctuaryFont", value) end, UI.RefreshNameplates)
    UI.AddDescription(content, layout, "When off, the selected Name font applies everywhere.")
    AddSize(context, "nameSize", "Name size", addon.MIN_NAME_SIZE, addon.MAX_NAME_SIZE, 1, " pt")
    UI.AddDescription(content, layout,
        "Also sets threat-text size. Titles use 80%; inside-bar text has four units above and three below.")
    UI.AddSection(content, layout, "Health bars")
    UI.AddDescription(content, layout,
        "All Active categories use available health bars. Priority controls color; combat does not change the layout.")
    AddSize(context, "healthBarWidth", "Health bar width", addon.MIN_HEALTH_BAR_WIDTH, addon.MAX_HEALTH_BAR_WIDTH, 5, "%")
    AddPlacement(context)
    AddFont(context, "Threat-percentage font", "threatFont")
    AddToggle(context, "Show threat percentage when available", addon.GetThreatEnabled, addon.SetThreatEnabled, UI.RefreshNameplates)
    UI.AddSection(content, layout, "Global visibility")
    -- This setter owns its CVar capture/restoration.
    AddToggle(context, "Hide critter and companion names", addon.GetHideCritterCompanionNames, addon.SetHideCritterCompanionNames)
    UI.AddDescription(content, layout, "Noncombat units only.")
end

local function CreateAppearancePanel()
    local panel, content, layout = UI.CreateScrollablePanel("Text")
    UI.AddTitle(content, layout, "Text")
    local context = {content = content, layout = layout, refreshers = {}, fontRefreshers = {}, sliders = {}}
    local function CancelEdits(quiet)
        local changed = false
        context.canceling = true
        for _, slider in ipairs(context.sliders) do
            local previous = slider:GetValue()
            slider:CancelEdit()
            if previous ~= slider:GetValue() then changed = true end
        end
        context.canceling = false
        if changed and not quiet then UI.RefreshNameplates() end
    end
    addon.CancelAppearanceEdits = CancelEdits
    addon.RefreshFontControls = function() UI.RunRefreshers(context.fontRefreshers) end
    local function RefreshPage() Refresh(context) end
    addon.AddProfileSelector(content, layout, context.refreshers, RefreshPage)
    UI.AddPageAction(content, layout, "Reset text settings", function()
        CancelEdits(true)
        addon.ResetAppearance()
        addon.SetThreatEnabled(addon.Defaults.showThreat)
        addon.SetHideCritterCompanionNames(addon.Defaults.hideCritterCompanionNames)
        RefreshPage()
        UI.RefreshNameplates()
    end)
    UI.AddDescription(content, layout, "Resets the settings below, including global critter/companion visibility.")
    AddControls(context)
    panel.Refresh = RefreshPage
    panel:SetScript("OnShow", panel.Refresh)
    panel:SetScript("OnHide", function() CancelEdits() end)
    RefreshPage()
    layout:Finish()
    return panel
end
addon.SettingsPanels.Appearance = CreateAppearancePanel


