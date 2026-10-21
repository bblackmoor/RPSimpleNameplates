-- Converted Colors page with real DF, real profile database and native UI stubs.
local ui = dofile("tests/details-framework-ui-stubs.lua")
dofile("tests/details-framework-loader.lua")("Libs/DetailsFramework/load.xml")
function UnitGUID() return "Player-Colors" end
function UnitFullName() return "Colors", "Realm" end
function strtrim(text) return text:match("^%s*(.-)%s*$") end
function GameTooltip:SetOwner(frame) self.owner = frame end
function GameTooltip:AddLine() end
local ns, refreshes = {}, 0
for _, file in ipairs({"Defaults", "FontMedia", "Core", "ManagedNames", "Database",
    "HealthGradient", "FontRendering", "SettingsControls", "SettingsColorPicker", "SettingsWidgets", "SettingsProfileDialogs", "SettingsProfiles", "SettingsPreview", "SettingsHighlight", "SettingsColors"}) do
    assert(loadfile("RPSimpleNameplates/" .. file .. ".lua"))("RPSimpleNameplates", ns)
end
ns.RefreshAll = function() refreshes = refreshes + 1 end
ns.WorldContext = {Get = function() return {} end}
ns.PresentationCapabilities = {ObjectStatus = function() return "accessible" end,
    ReadRegion = function(object, method) return object[method](object) end}
ns.EnsureDB()
ns.GetActiveProfileName() -- Resolve the normal character assignment before testing UI refresh.
local function Snapshot(value)
    if type(value) ~= "table" then return tostring(value) end
    local entries = {}
    for key, item in pairs(value) do entries[#entries + 1] = tostring(key) .. "=" .. Snapshot(item) end
    table.sort(entries)
    return "{" .. table.concat(entries, ",") .. "}"
end
local initial = Snapshot(SimpleNameplatesDB)
local panel = ns.SettingsPanels.Colors()
local highlightPanel = ns.SettingsPanels.Highlight()
assert(Snapshot(SimpleNameplatesDB) == initial and refreshes == 0, "constructing Colors is read-only")
local function Row(text)
    for _, object in ipairs(ui.objects) do
        if object.kind == "FontString" and object:GetText() == text then return object:GetParent() end
    end
    error("Missing row " .. text)
end
local function Control(row, kind)
    for _, object in ipairs(ui.objects) do
        local widget = object.MyObject
        if object:GetParent() == row and widget then
            if kind == "color" and widget.__iscolorpicker then return object end
            if widget.type == kind and not widget.__iscolorpicker then return object end
        end
    end
    error("Missing control " .. kind)
end
local function Click(frame)
    frame:GetScript("OnMouseDown")(frame, "LeftButton")
    frame:GetScript("OnMouseUp")(frame, "LeftButton")
end
local function RGBEqual(actual, r, g, b)
    assert(actual[1] == r and actual[2] == g and actual[3] == b, "RGB mismatch")
end
local function SwatchRGB(frame) return {frame.MyObject:GetColor()} end
local cases = {
    {"attacking", "1. Attacking me"}, {"hostile", "2. Will attack me — Hostile"},
    {"neutral", "3. Can attack me — Neutral"}, {"friendly", "4. Player - Friendly"},
    {"useful", "5. NPC - Interactive"}, {"useless", "6. NPC - Background"},
}
for _, case in ipairs(cases) do
    local state, row = case[1], Row(case[2])
    local swatch, toggle = Control(row, "color"), Control(row, "switch")
    for _, object in ipairs(ui.objects) do
        assert(not (object:GetParent() == row and object.MyObject and object.MyObject.type == "button" and not object.MyObject.__iscolorpicker), "no individual reset button")
    end
    assert(swatch:GetWidth() == 26 and swatch:GetHeight() == 26)
    assert(toggle.MyObject.is_toggle and toggle:GetWidth() == 44)
    assert(swatch.point[4] == 340 and toggle.point[2]:GetText() == "Health Bar" and toggle.point[4] == 8)
    assert(swatch.MyObject.color_texture.points.TOPLEFT[4] == 3)
    assert(swatch.MyObject.color_texture.points.BOTTOMRIGHT[5] == 3)
    swatch:GetScript("OnEnter")(swatch)
    assert(GameTooltip.owner == swatch and GameTooltip:GetText() == case[2], "native tooltip owner")
    swatch:GetScript("OnLeave")(swatch)
    local before = refreshes
    toggle:GetScript("OnClick")(toggle, "LeftButton")
    assert(ns.GetHealthBarEnabled(state) == (state == "useless") and refreshes == before + 1)
    local oldR, oldG, oldB = ns.PriorityColorForState(state)
    Click(swatch)
    local picker = ColorPickerFrame.info
    assert(picker.hasOpacity == false)
    function ColorPickerFrame:GetColorRGB() return 0.2, 0.3, 0.4 end
    picker.swatchFunc()
    RGBEqual({ns.PriorityColorForState(state)}, 0.2, 0.3, 0.4)
    RGBEqual(SwatchRGB(swatch), 0.2, 0.3, 0.4)
    picker.cancelFunc()
    RGBEqual(SwatchRGB(swatch), oldR, oldG, oldB)
    RGBEqual({ns.PriorityColorForState(state)}, oldR, oldG, oldB)
    assert(refreshes == before + 3, "each user edit refreshes plates once; redraws are silent")
end

assert(ns.CAST_EFFECT_BY_VALUE.PULSE == "Pulsing border" and ns.CAST_EFFECT_BY_VALUE.ALERT == "Alert border", "requested effect labels")
local pulseSection, alertSection
for index, object in ipairs(ui.objects) do
    if object.kind == "FontString" and object:GetText() == "Pulse settings" then pulseSection = index end
    if object.kind == "FontString" and object:GetText() == "Alert settings" then alertSection = index end
end
assert(pulseSection and alertSection and pulseSection < alertSection, "Alert settings follows Pulse settings")
Control(Row("Fade in"), "slider"):SetValue(0.4)
Control(Row("Fade out"), "slider"):SetValue(0.6)
assert(math.abs(ns.GetCastBorderSetting("PULSE", "fadeIn") - 0.4) < 0.00001, "independent pulse timing control")
assert(ns.GetCastBorderSetting("ALERT", "minLength") == 20, "Alert starts at 20 percent")
Control(Row("Border offset"), "slider"):SetValue(1)
assert(ns.GetCastBorderSetting("PULSE", "offset") == 1, "shared outward offset control")
-- Every length-pulse parameter has an editable Colors slider and silent refresh.
for _, case in ipairs({
    {"Minimum length", "minLength", 25}, {"Maximum length", "maxLength", 85},
    {"Shrink time", "shrinkTime", 0.4}, {"Grow time", "growTime", 0.6},
    {"End opacity", "endOpacity", 20}, {"Center opacity", "centerOpacity", 75},
}) do
    local slider = Control(Row(case[1]), "slider")
    local before = refreshes
    slider:SetValue(case[3])
    assert(math.abs(ns.GetCastBorderSetting("ALERT", case[2]) - case[3]) < 0.00001, "Colors pulse control updates profile")
    assert(refreshes == before + 1, "one nameplate refresh per pulse edit")
end
local before = refreshes
highlightPanel.Refresh()
assert(refreshes == before, "pulse-control refresh remains read-only")
ns.ResetAllColors(); panel.Refresh(); highlightPanel.Refresh()
local function BelongsTo(object, ancestor)
    while object do
        if object == ancestor then return true end
        object = object:GetParent()
    end
    return false
end
for _, label in ipairs({"Effect", "Border thickness", "Border offset", "Fade in", "Fade out", "Minimum length", "Maximum length", "Shrink time", "Grow time", "End opacity", "Center opacity"}) do
    assert(BelongsTo(Row(label), highlightPanel), "interruptible settings moved to Highlight")
    assert(not BelongsTo(Row(label), panel), "interruptible settings removed from Colors")
end
local function Samples(panel)
    local sample = {}
    for _, object in ipairs(ui.objects) do
        if BelongsTo(object, panel) then
            if object.kind == "StatusBar" and object:GetValue() == 65 then sample.health = object end
            if object.kind == "StatusBar" and object:GetValue() == 55 then sample.cast = object end
            if object.kind == "FontString" and object:GetText() == "Sample Name" then sample.name = object end
            if object.kind == "FontString" and object:GetText() == "125%" then sample.threat = object end
        end
    end
    assert(sample.health and sample.cast and sample.name and sample.threat, "complete sample on each page")
    return sample
end
local colorSample, highlightSample = Samples(panel), Samples(highlightPanel)
ns.SetInterruptibleHighlightEnabled(true); panel.Refresh(); highlightPanel.Refresh()
assert(colorSample.cast.alpha == 1 and highlightSample.cast.alpha == 1)
ns.SetInterruptibleHighlightEnabled(false); panel.Refresh(); highlightPanel.Refresh()
assert(colorSample.cast.alpha == 0.5 and highlightSample.cast.alpha == 0.5)

local dimToggle = Control(Row("Dim background NPC names"), "switch")
assert(ns.GetDimBackgroundNames(), "background dimming defaults on")
assert(Row("Dim background NPC names").point[5] < Row("6. NPC - Background").point[5], "dimming follows background category")
local dimRefreshes = refreshes
dimToggle:GetScript("OnClick")(dimToggle, "LeftButton")
assert(not ns.GetDimBackgroundNames() and refreshes == dimRefreshes + 1)
assert(ns.CopyActiveProfile("Dim copy") and not ns.GetDimBackgroundNames())
ns.SetDimBackgroundNames(true)
assert(ns.SetActiveProfileName("Default") and not ns.GetDimBackgroundNames(), "dimming is profile scoped")
ns.ResetAppearance()
assert(not ns.GetDimBackgroundNames(), "Appearance reset preserves dimming")
ns.SetDimBackgroundNames("invalid")
assert(not ns.GetDimBackgroundNames(), "invalid setter ignored")
ns.ResetAllColors(); panel.Refresh(); highlightPanel.Refresh()
assert(ns.GetDimBackgroundNames() and dimToggle.MyObject:GetValue(), "Colors reset enables dimming")

local methods = getmetatable(UIParent).__index
function methods:SetAlpha(value) self.alpha = value end
local gradientSlider = Control(Row("Gradient opacity"), "slider")
local preview = colorSample.health
local sample, threat = colorSample.name, colorSample.threat
assert(sample.flags == "SLUG,OUTLINE" and threat.flags == "SLUG,OUTLINE", "sample text outlined")
assert(ns.GetGradientOpacity() == 100 and gradientSlider.MyObject:GetValue() == 100, "Default starts at 100%")
local beforeGradient = refreshes
gradientSlider:SetValue(0)
assert(ns.GetGradientOpacity() == 0 and refreshes == beforeGradient + 1)
assert(not preview.RPSNHealthGradient:IsShown())
assert(sample.flags == "SLUG,OUTLINE" and threat.flags == "SLUG,OUTLINE", "opacity preserves outlines")
gradientSlider:SetValue(50)
assert(ns.GetGradientOpacity() == 50 and refreshes == beforeGradient + 2)
assert(preview.RPSNHealthGradient:IsShown() and preview.RPSNHealthGradient.alpha == 1
    and preview.RPSNHealthGradient.gradient[2].a == 0.4, "50% slider produces 40% left darkness")
assert(preview.RPSNHealthGradient.width == 228 * 0.95, "preview fade position preserved")
assert(ns.CopyActiveProfile("Gradient copy"))
assert(ns.GetGradientOpacity() == 50, "profile copy retains opacity")
ns.SetGradientOpacity(0)
assert(ns.SetActiveProfileName("Default"))
assert(ns.GetGradientOpacity() == 50, "copy independent")
ns.ResetAppearance()
assert(ns.GetGradientOpacity() == 50, "Appearance reset preserves opacity")
ns.ResetAllColors(); panel.Refresh(); highlightPanel.Refresh()
assert(ns.GetGradientOpacity() == 100 and preview.RPSNHealthGradient:IsShown(), "Default reset")
assert(ns.SetActiveProfileName("High Contrast")); panel.Refresh()
assert(ns.GetGradientOpacity() == 0 and gradientSlider.MyObject:GetValue() == 0, "High Contrast starts at 0%")
ns.SetGradientOpacity(50); ns.ResetAllColors(); panel.Refresh(); highlightPanel.Refresh()
assert(ns.GetGradientOpacity() == 0 and not preview.RPSNHealthGradient:IsShown())
assert(ns.SetActiveProfileName("Default")); panel.Refresh()

local castRow = Row("Cast highlight color")
local cast = Control(castRow, "color")
local castToggle = Control(Row("Highlight interruptible casts"), "switch")
local effectDropdown = Control(Row("Effect"), "dropdown")
assert(#effectDropdown.MyObject.func() == 3, "pulse, solid and alert exposed")
local effectRefreshes = refreshes
for _, option in ipairs(effectDropdown.MyObject.func()) do
    option.onclick(nil, nil, option.value)
    assert(ns.GetInterruptibleEffect() == option.value, "effect selection saved")
end
assert(refreshes == effectRefreshes + 3, "one plate refresh per effect change")
assert(not ns.GetInterruptibleHighlightEnabled(), "effect choice does not enable Active")
assert(BelongsTo(castToggle, highlightPanel), "cast activation belongs to Cast Highlight")
for _, enabled in ipairs({true, false, true}) do
    local before = refreshes
    castToggle:GetScript("OnClick")(castToggle, "LeftButton")
    assert(ns.GetInterruptibleHighlightEnabled() == enabled and castToggle.MyObject:GetValue() == enabled)
    assert(refreshes == before + 1)
end
Click(cast)
local picker = ColorPickerFrame.info
picker.swatchFunc()
RGBEqual({ns.EffectColor("interruptible")}, 0.2, 0.3, 0.4)
picker.cancelFunc()
RGBEqual({ns.EffectColor("interruptible")}, 0.2, 0, 1)
assert(ns.GetInterruptibleHighlightEnabled(), "cast-color cancellation preserves activation")

-- Adapted profile selector stays shared; switching refreshes DF controls silently.
local selector
for _, object in ipairs(ui.objects) do
    if object:GetParent() == Row("Selected profile") and object.MyObject and object.MyObject.type == "dropdown" then selector = object end
end
ns.SetAppearanceSetting("nameSize", 31)
local preservedDefault = Snapshot(ns.EnsureDB().profiles.Default)
for _, option in ipairs(selector.MyObject.func()) do
    if option.value == "High Contrast" then option.onclick(nil, nil, option.value) end
end
assert(ns.GetActiveProfileName() == "High Contrast" and selector.MyObject.myvalue == "High Contrast")
local highContrast = ns.Defaults.colorPresets.highContrast
RGBEqual(SwatchRGB(Control(Row(cases[1][2]), "color")), 1, 0, 1)
ns.SetPriorityColor("attacking", 0.1, 0.2, 0.3)
ns.SetEffectColor("interruptible", 0.4, 0.5, 0.6)
ns.SetInterruptibleHighlightEnabled(true)
ns.SetTRP3Enabled(true)
local resetAll
for _, object in ipairs(ui.objects) do
    if object.MyObject and object.MyObject.type == "button" and object.text:GetText() == "Reset color settings" then resetAll = object end
end
assert(resetAll:GetWidth() == 190 and resetAll:GetHeight() == 24)
assert(not BelongsTo(castRow, panel), "cast color is absent from Colors")
local before = refreshes
Click(resetAll)
assert(refreshes == before + 1 and ns.GetInterruptibleHighlightEnabled())
assert(ns.GetInterruptibleEffect() == "PULSE", "selected profile effect is preserved")
assert(ns.GetTRP3Enabled() and Snapshot(ns.EnsureDB().profiles.Default) == preservedDefault)
assert(ns.GetActiveProfileName() == "High Contrast")
for _, case in ipairs(cases) do
    local default = highContrast.priorityColors[case[1]]
    RGBEqual(SwatchRGB(Control(Row(case[2]), "color")), default.r, default.g, default.b)
    assert(ns.GetHealthBarEnabled(case[1]) == (case[1] ~= "useless"))
end
highlightPanel.Refresh()
RGBEqual(SwatchRGB(cast), 0.4, 0.5, 0.6)
initial, before = Snapshot(SimpleNameplatesDB), refreshes
panel:GetScript("OnShow")(panel)
panel:GetScript("OnShow")(panel)
assert(Snapshot(SimpleNameplatesDB) == initial and refreshes == before, "show/reflow refresh is read-only")
assert(ns.GetThreatEnabled() and ns.GetStylingEnabled(), "unrelated global settings preserved")
-- Old picker callbacks must not undo a reset or write into the next profile.
local attacking = Control(Row("1. Attacking me"), "color")
ns.SetPriorityColor("attacking", 0.7, 0.8, 0.9)
panel:GetScript("OnShow")(panel)
Click(attacking)
local oldPicker = ColorPickerFrame.info
oldPicker.swatchFunc()
Click(resetAll)
oldPicker.cancelFunc()
RGBEqual({ns.PriorityColorForState("attacking")}, 1, 0, 1)
oldPicker.swatchFunc()
RGBEqual({ns.PriorityColorForState("attacking")}, 1, 0, 1)
-- Switching profiles rolls back the original profile before refreshing the new one.
ns.SetPriorityColor("attacking", 0.7, 0.8, 0.9)
panel:GetScript("OnShow")(panel)
Click(attacking); oldPicker = ColorPickerFrame.info; oldPicker.swatchFunc()
local target = Snapshot(ns.EnsureDB().profiles.Default)
for _, option in ipairs(selector.MyObject.func()) do
    if option.value == "Default" then option.onclick(nil, nil, option.value) end
end
RGBEqual({ns.EnsureDB().profiles["High Contrast"].priorityColors.attacking.r,
    ns.EnsureDB().profiles["High Contrast"].priorityColors.attacking.g,
    ns.EnsureDB().profiles["High Contrast"].priorityColors.attacking.b}, 0.7, 0.8, 0.9)
oldPicker.cancelFunc(); oldPicker.swatchFunc()
assert(Snapshot(ns.EnsureDB().profiles.Default) == target)
Click(attacking); oldPicker = ColorPickerFrame.info; oldPicker.swatchFunc()
Click(resetAll); oldPicker.cancelFunc()
RGBEqual({ns.PriorityColorForState("attacking")}, 1, 0, 0)
Click(attacking); oldPicker = ColorPickerFrame.info; oldPicker.swatchFunc()
panel:GetScript("OnHide")(panel); oldPicker.swatchFunc()
RGBEqual({ns.PriorityColorForState("attacking")}, 1, 0, 0)
print("Colors settings integration smoke: passed")


-- Direct database mutations retire edits before changing their captured target.
local function OpenPreview()
    ns.SetPriorityColor("attacking", 0.7, 0.8, 0.9)
    panel.Refresh()
    Click(attacking)
    local edit = ColorPickerFrame.info
    assert(edit.extraInfo.owner and edit.extraInfo.target.name == ns.GetActiveProfileName())
    assert(edit.extraInfo.target.object == ns.GetProfile(ns.GetActiveProfileName()))
    edit.swatchFunc()
    RGBEqual({ns.PriorityColorForState("attacking")}, 0.2, 0.3, 0.4)
    return edit
end
local serial = 0
for _, mutate in ipairs({
    function() assert(ns.SetActiveProfileName("Default")) end,
    function() assert(ns.CreateProfile("Created directly")) end,
    function() assert(ns.CopyActiveProfile("Copied directly")) end,
    function() assert(ns.RenameActiveProfile("Renamed directly")) end,
    function() assert(ns.DeleteActiveProfile()) end,
    function() ns.RestoreBundledProfiles() end,
    function() ns.ResetPriorityColor("attacking") end,
    function() ns.ResetEffectColor("interruptible") end,
    function() ns.ResetAllColors() end,
    function() ns.ResetAppearance() end,
}) do
    serial = serial + 1
    assert(ns.CreateProfile("Direct mutation " .. serial))
    local edit = OpenPreview()
    local original = edit.extraInfo.target.object
    mutate()
    assert(not ColorPickerFrame:IsShown(), "database mutation closes its picker")
    local saved = Snapshot(SimpleNameplatesDB)
    edit.cancelFunc(); edit.swatchFunc()
    assert(Snapshot(SimpleNameplatesDB) == saved, "database mutations retire picker callbacks")
    if serial <= 6 then
        RGBEqual({original.priorityColors.attacking.r, original.priorityColors.attacking.g,
            original.priorityColors.attacking.b}, 0.7, 0.8, 0.9)
    end
end
-- Invalid mutations leave the current edit intact.
local edit = OpenPreview()
assert(not ns.SetActiveProfileName("Missing"))
assert(not ns.CreateProfile(""))
assert(ColorPickerFrame:IsShown())
edit.cancelFunc()
RGBEqual({ns.PriorityColorForState("attacking")}, 0.7, 0.8, 0.9)
-- Same-name replacement is rejected even if a caller bypasses database mutations.
edit = OpenPreview()
local name, original = ns.GetActiveProfileName(), ns.GetProfile(ns.GetActiveProfileName())
ns.EnsureDB().profiles[name] = ns.GetProfile("High Contrast")
local saved = Snapshot(SimpleNameplatesDB)
edit.swatchFunc(); edit.cancelFunc()
assert(Snapshot(SimpleNameplatesDB) == saved, "replacement identity cannot receive old preview or rollback")
ns.EnsureDB().profiles[name] = original
saved = Snapshot(SimpleNameplatesDB)
edit.swatchFunc(); edit.cancelFunc()
assert(Snapshot(SimpleNameplatesDB) == saved, "cancel retires replaced-target callbacks permanently")
print("PASS direct database mutation and picker target identity")

-- Picker originals come from saved RGB, even if the visible swatch is stale.
for _, case in ipairs({
    {attacking, function() ns.SetPriorityColor("attacking", 0.11, 0.22, 0.33) end,
        function() return ns.PriorityColorForState("attacking") end},
    {cast, function() ns.SetEffectColor("interruptible", 0.11, 0.22, 0.33) end,
        function() return ns.EffectColor("interruptible") end},
}) do
    local swatch, setSaved, getSaved = case[1], case[2], case[3]
    swatch.MyObject:SetColor(0.8, 0.7, 0.6, 1)
    setSaved() -- Intentionally do not refresh the page.
    local before = refreshes
    Click(swatch)
    local info = ColorPickerFrame.info
    RGBEqual({info.r, info.g, info.b}, 0.11, 0.22, 0.33)
    RGBEqual(SwatchRGB(swatch), 0.11, 0.22, 0.33)
    assert(refreshes == before, "opening refreshes the swatch without applying settings")
    info.swatchFunc(); RGBEqual({getSaved()}, 0.2, 0.3, 0.4)
    info.cancelFunc(); RGBEqual({getSaved()}, 0.11, 0.22, 0.33)
    ColorPickerFrame:Hide() -- Simulate native Cancel hiding after its callback.
end
print("PASS stale swatches preserve current saved priority and effect RGB")



