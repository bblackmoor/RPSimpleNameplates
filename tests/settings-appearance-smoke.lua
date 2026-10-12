-- Converted Appearance with real DF, SharedMedia and profile/database behavior.
local ui = dofile("tests/details-framework-ui-stubs.lua")
dofile("tests/details-framework-loader.lua")("Libs/DetailsFramework/load.xml")
max, min = math.max, math.min
function UnitGUID() return "Player-Appearance" end
function UnitFullName() return "Appearance", "Realm" end
function strtrim(text) return text:match("^%s*(.-)%s*$") end
local cvars = {}
C_CVar.GetCVar = function(name) return cvars[name] or "1" end
C_CVar.SetCVar = function(name, value) cvars[name] = tostring(value) end
local ns, refreshes, queued = {}, 0, 0
for _, file in ipairs({"Defaults", "FontMedia", "Core", "ManagedNames", "Database",
    "SettingsControls", "SettingsColorPicker", "SettingsWidgets", "SettingsProfileDialogs", "SettingsProfiles", "SettingsAppearance"}) do
    assert(loadfile("RPSimpleNameplates/" .. file .. ".lua"))("RPSimpleNameplates", ns)
end
ns.RefreshAll = function() refreshes = refreshes + 1 end
ns.QueueNameplateRefresh = function() queued = queued + 1 end
ns.GetActiveProfileName()
local function Snapshot(value)
    if type(value) ~= "table" then return tostring(value) end
    local entries = {}
    for key, item in pairs(value) do entries[#entries + 1] = tostring(key) .. "=" .. Snapshot(item) end
    table.sort(entries)
    return "{" .. table.concat(entries, ",") .. "}"
end
local builds, getOptions = 0, ns.GetFontOptions
ns.GetFontOptions = function(...) builds = builds + 1; return getOptions(...) end
local before = Snapshot(SimpleNameplatesDB)
local panel = ns.SettingsPanels.Appearance()
assert(Snapshot(SimpleNameplatesDB) == before and refreshes == 0 and builds == 0, "construction is silent and font menus lazy")
local function Row(label)
    for _, object in ipairs(ui.objects) do
        if object.kind == "FontString" and object:GetText() == label then return object:GetParent() end
    end
    error("Missing row " .. label)
end
local function Control(label)
    for _, object in ipairs(ui.objects) do
        if object:GetParent() == Row(label) and object.MyObject then return object end
    end
    error("Missing control " .. label)
end
local function Click(frame)
    frame:GetScript("OnMouseDown")(frame, "LeftButton")
    frame:GetScript("OnMouseUp")(frame, "LeftButton")
end
local function Choose(frame, value)
    for _, option in ipairs(frame.MyObject.func()) do
        if option.value == value then
            local item = CreateFrame("Button", nil, frame.dropdownframe:GetScrollChild())
            item.object, item.table = frame.MyObject, option
            DetailsFrameworkDropDownOptionClick(item)
            return
        end
    end
    error("Missing choice " .. value)
end
local function Editor(slider)
    slider:GetScript("OnMouseDown")(slider, "RightButton")
    for _, object in ipairs(ui.objects) do
        if object.kind == "EditBox" and object:GetParent() == slider then return object end
    end
end
local nameFont, threatFont = Control("Name font"), Control("Threat-percentage font")
local slug = Control("Use smoother font rendering (Slug)")
assert(slug.MyObject:GetValue(), "Slug switch defaults on")
local slugRefreshes = refreshes
slug:GetScript("OnClick")(slug, "LeftButton")
assert(not ns.GetAppearanceSetting("useSlugRendering") and refreshes == slugRefreshes + 1, "Slug toggle saves and refreshes plates")
panel:GetScript("OnShow")(panel)
assert(not slug.MyObject:GetValue() and refreshes == slugRefreshes + 1, "Slug refresh is silent")
local size, width = Control("Name size"), Control("Health bar width")
assert(size.minimum == 8 and size.maximum == 36 and size.step == 1)
assert(width.minimum == 80 and width.maximum == 150 and width.step == 5)
assert(size:GetWidth() == 180 and size:GetHeight() == 18)
assert(nameFont:GetWidth() == 190 and nameFont.point[4] == 340)
local prior = refreshes
size:SetValue(28)
width:SetValue(123)
assert(ns.GetAppearanceSetting("nameSize") == 28 and ns.GetAppearanceSetting("healthBarWidth") == 125)
assert(refreshes == prior + 2, "rounding yields one page callback")
local amount
for _, object in ipairs(ui.objects) do
    if object:GetParent() == width:GetParent() and object.kind == "FontString" and object:GetText() == "125%" then amount = object end
end
assert(amount, "adjacent value retains units")
local editor = Editor(size)
editor:SetText("31")
editor:GetScript("OnEscapePressed")()
assert(ns.GetAppearanceSetting("nameSize") == 28 and size:GetValue() == 28)
local widthEditor = Editor(width)
widthEditor:SetText("145")
widthEditor:GetScript("OnEnterPressed")()
assert(ns.GetAppearanceSetting("healthBarWidth") == 145)
Control("Match Blizzard font in sanctuaries"):GetScript("OnClick")(Control("Match Blizzard font in sanctuaries"), "LeftButton")
Control("Show threat percentage when available"):GetScript("OnClick")(Control("Show threat percentage when available"), "LeftButton")
assert(not ns.GetAppearanceSetting("matchSanctuaryFont") and not ns.GetThreatEnabled())
Choose(Control("Health-bar name placement"), "ABOVE")
assert(ns.GetAppearanceSetting("namePlacement") == "ABOVE")

-- Registration updates only labels/invalidations, not other controls or menus.
local media = LibStub("LibSharedMedia-3.0")
prior = builds
media:Register("font", "Late face", "Interface\\AddOns\\TestFonts\\late.ttf")
assert(builds == prior and queued == 0)
Choose(nameFont, "LSM:Late face")
Choose(threatFont, "LSM:Late face")
assert(ns.GetAppearanceSetting("nameFont") == "LSM:Late face" and ns.GetAppearanceSetting("threatFont") == "LSM:Late face")
media.MediaTable.font["Late face"] = nil
media.MediaList.font = nil
ns.RefreshFontControls()
assert(nameFont.MyObject.myvalue == "LSM:Late face" and nameFont.MyObject.label:GetText() == "Late face (unavailable)")
assert(ns.FontPath("LSM:Late face") == "Fonts\\ARIALN.TTF")
prior = builds
local priorSize, priorWidth = size:GetValue(), width:GetValue()
media:Register("font", "Late face", "Interface\\AddOns\\TestFonts\\returned.ttf")
assert(builds == prior and queued == 1 and size:GetValue() == priorSize and width:GetValue() == priorWidth)
assert(nameFont.MyObject.label:GetText() == "Late face")
media:SetGlobal("font", "Friz Quadrata TT")
assert(queued == 2 and builds == prior)
media:SetGlobal("font", nil)
for i = 1, 60 do media:Register("font", string.format("Face %02d", i), "Interface\\AddOns\\TestFonts\\" .. i .. ".ttf") end
prior = builds
DetailsFrameworkDropDownOnMouseDown(nameFont, "LeftButton")
assert(builds == prior + 1 and #nameFont.MyObject.menus >= 60, "long menu built on opening")
assert(nameFont.dropdownframe.mouseWheel and nameFont.MyObject.scroll:IsShown())
local _, maximum = nameFont.MyObject.scroll:GetMinMaxValues()
assert(maximum > 0, "long list is scrollable")
nameFont.MyObject.scroll:SetValue(maximum)
assert(nameFont.dropdownframe:GetVerticalScroll() > 0)
nameFont.MyObject:Close()

-- Cancel previews before a selector changes the database's active profile.
local selector
for _, object in ipairs(ui.objects) do
    if object:GetParent() == Row("Selected profile") and object.MyObject and object.MyObject.type == "dropdown" then selector = object end
end
Editor(size):SetText("32")
Choose(selector, "High Contrast")
assert(ns.GetActiveProfileName() == "High Contrast" and size:GetValue() == 18)
assert(ns.GetAppearanceSetting("useSlugRendering") and slug.MyObject:GetValue(), "Slug follows selected profile")
Choose(Control("Health-bar name placement"), "INSIDE")
slug:GetScript("OnClick")(slug, "LeftButton")
assert(ns.EnsureDB().profiles.Default.appearance.nameSize == 28, "rollback remains in previous profile")
assert(ns.GetAppearanceSetting("nameSize") == 18, "new profile is not overwritten by cancellation")
ns.SetPriorityColor("attacking", 0.2, 0.3, 0.4)
ns.SetInterruptibleHighlightEnabled(true)
ns.SetTRP3Enabled(true)
Control("Hide critter and companion names"):GetScript("OnClick")(Control("Hide critter and companion names"), "LeftButton")
assert(ns.GetHideCritterCompanionNames())
Editor(size):SetText("34")
local reset
for _, object in ipairs(ui.objects) do
    if object.MyObject and object.MyObject.type == "button" and object.text:GetText() == "Reset text settings" then reset = object end
end
Click(reset)
assert(size:GetValue() == 18 and width:GetValue() == 120 and ns.GetThreatEnabled())
assert(ns.GetAppearanceSetting("useSlugRendering") and slug.MyObject:GetValue(), "Appearance reset enables Slug")
assert(ns.GetAppearanceSetting("nameFont") == "FRIZQT" and ns.GetAppearanceSetting("threatFont") == "ARIALN")
assert(ns.GetAppearanceSetting("namePlacement") == "ABOVE" and ns.GetAppearanceSetting("matchSanctuaryFont"), "High Contrast reset places names above")
assert(not ns.GetHideCritterCompanionNames() and ns.GetTRP3Enabled() and ns.GetStylingEnabled())
assert(ns.GetInterruptibleHighlightEnabled() and ns.PriorityColorForState("attacking") == 0.2)
editor:GetScript("OnEscapePressed")()
assert(ns.GetAppearanceSetting("nameSize") == 18, "stale Escape cannot undo reset")
Editor(size):SetText("30")
panel:GetScript("OnHide")(panel)
assert(ns.GetAppearanceSetting("nameSize") == 18, "page hide rolls back edit")
before, prior = Snapshot(SimpleNameplatesDB), refreshes
panel:GetScript("OnShow")(panel)
panel:GetScript("OnShow")(panel)
assert(Snapshot(SimpleNameplatesDB) == before and refreshes == prior, "show/reflow is read-only")
print("Appearance settings integration smoke: passed")


-- Database callers receive the same draft-cancellation protection as selectors.
local serial = 0
for _, mutate in ipairs({
    function() assert(ns.SetActiveProfileName("Default")) end,
    function() assert(ns.CreateProfile("Appearance created")) end,
    function() assert(ns.CopyActiveProfile("Appearance copied")) end,
    function() assert(ns.RenameActiveProfile("Appearance renamed")) end,
    function() assert(ns.DeleteActiveProfile()) end,
    function() ns.RestoreBundledProfiles() end,
    function() ns.ResetAppearance() end,
}) do
    serial = serial + 1
    assert(ns.CreateProfile("Appearance direct " .. serial))
    ns.SetAppearanceSetting("nameSize", 23)
    panel.Refresh()
    local original = ns.GetProfile(ns.GetActiveProfileName())
    local pending = Editor(size)
    pending:SetText("32")
    assert(original.appearance.nameSize == 32)
    mutate()
    assert(not pending:IsShown(), "database mutation cancels appearance editor")
    if serial ~= 7 then assert(original.appearance.nameSize == 23, "rollback precedes mutation") end
    local saved = Snapshot(SimpleNameplatesDB)
    pending:SetText("35")
    pending:GetScript("OnEscapePressed")()
    assert(Snapshot(SimpleNameplatesDB) == saved, "retired appearance editor cannot change later selection")
end
print("PASS direct database mutation and appearance draft cancellation")

