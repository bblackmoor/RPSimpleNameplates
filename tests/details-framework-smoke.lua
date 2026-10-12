-- Real DF sources and adapter, with explicit native UI stubs only.
-- Run from repository root: luatex --luaonly tests/details-framework-smoke.lua
local ui = dofile("tests/details-framework-ui-stubs.lua")
local root = "RPSimpleNameplates/"
local LoadXML = dofile("tests/details-framework-loader.lua")
local scripts, manifests = LoadXML("Libs/DetailsFramework/load.xml")
assert(scripts == 52 and manifests == 9, "complete pinned load chain")
assert(not Details and not Plater, "standalone test has no addon hosts")
local df = LibStub:GetLibrary("DetailsFramework-1.0")
assert(df.dversion == 762)
for _, callback in ipairs(df.OnLoginSchedules) do callback() end
local ns = {}
assert(loadfile(root .. "SettingsWidgets.lua"))("RPSimpleNameplates", ns)
local widgets = ns.SettingsWidgets
assert(not ns.SettingsUI and not ns.SettingsPanels, "adapter does not register or replace legacy pages")
assert(SimpleNameplatesDB == nil, "loading must not initialize saved settings")
local profile = {}
ns.GetActiveProfileName = function() return "Test" end
ns.GetProfile = function(name) if name == "Test" then return profile end end
assert(loadfile(root .. "SettingsControls.lua"))("RPSimpleNameplates", ns)
assert(loadfile(root .. "SettingsColorPicker.lua"))("RPSimpleNameplates", ns)
assert(widgets.GetFramework() == df)

local changes, selected, rgb = 0
local function Changed() changes = changes + 1 end
local switch = widgets.CreateSwitch(UIParent, Changed)
assert(switch.widget.is_toggle and switch.frame:GetWidth() == 44)
assert(widgets.GetFrame(switch) == switch.frame)
assert(widgets.GetFrame(switch.widget) == switch.frame)
assert(widgets.GetFrame(UIParent) == UIParent)
switch:SetChecked(true)
switch:SetChecked(true)
assert(changes == 0 and switch:GetChecked(), "switch refresh is silent")
switch.frame:GetScript("OnClick")(switch.frame, "LeftButton")
assert(changes == 1 and not switch:GetChecked(), "user switch click notifies once")
switch:SetEnabled(false)
switch.frame:GetScript("OnClick")(switch.frame, "LeftButton")
assert(changes == 1 and not switch.frame:IsEnabled() and switch.frame.alpha == 0.5)
switch:SetEnabled(true)

local slider = widgets.CreateSlider(switch, 80, 150, 5, Changed)
assert(slider.frame:GetParent() == switch.frame, "native parent boundary")
slider:SetPoint("LEFT", switch, "RIGHT", 8, 0)
assert(slider.frame.point[2] == switch.frame, "native relative anchor boundary")
slider:SetValue(100)
slider:SetValue(100)
assert(changes == 1 and not slider.widget.NoCallback, "same-value refresh cannot leave suppression flag")
slider.widget:SetValue(123)
assert(changes == 2 and slider:GetValue() == 125, "typed values normalize and notify once")
slider:SetValue(999)
assert(changes == 2 and slider:GetValue() == 150, "programmatic clamping remains silent")
slider:SetValue(-100)
assert(slider:GetValue() == 80)
local setValue = slider.widget.SetValue
slider.widget.SetValue = function() error("intentional widget failure") end
assert(not pcall(slider.SetValue, slider, 100))
assert(slider.refreshDepth == 0, "failed refresh restores guard")
slider.widget.SetValue = setValue
slider.widget:SetValue(100)
assert(changes == 3, "next user edit survives failed refresh")

-- Typed editing belongs to each slider, even after another slider opened first.
local typedWidth, typedSize, widthWrites, sizeWrites = 100, 21, 0, 0
local width = widgets.CreateSlider(UIParent, 80, 150, 5, function(value)
    typedWidth = value; widthWrites = widthWrites + 1
end)
local size = widgets.CreateSlider(UIParent, 8, 36, 1, function(value)
    typedSize = value; sizeWrites = sizeWrites + 1
end)
width:SetValue(100)
size:SetValue(21)
local function Editor(control)
    control.frame:GetScript("OnMouseDown")(control.frame, "RightButton")
    for _, object in ipairs(ui.objects) do
        if object.kind == "EditBox" and object:GetParent() == control.frame then return object end
    end
    error("Slider editor missing")
end
local widthEditor = Editor(width)
assert(width:GetValue() == 100 and widthWrites == 0, "opening editor leaves value unchanged")
widthEditor:SetText("133")
assert(width:GetValue() == 135 and typedWidth == 135)
widthEditor:GetScript("OnEscapePressed")()
assert(width:GetValue() == 100 and typedWidth == 100 and widthWrites == 2)
local sizeEditor = Editor(size)
assert(sizeEditor ~= widthEditor and size:GetValue() == 21)
sizeEditor:SetText("30")
sizeEditor:GetScript("OnEscapePressed")()
assert(size:GetValue() == 21 and typedSize == 21 and sizeWrites == 2,
    "second slider Escape restores its own opening value")
assert(width:GetValue() == 100 and widthWrites == 2, "cancel does not change the other slider")
Editor(width):SetText("140")
widthEditor:GetScript("OnEnterPressed")()
assert(width:GetValue() == 140 and typedWidth == 140 and widthWrites == 3)
Editor(size):SetText("29")
sizeEditor:GetScript("OnHide")()
assert(size:GetValue() == 21 and typedSize == 21, "closing editor cancels preview")
Editor(size):SetText("28")
sizeEditor:GetScript("OnEditFocusLost")()
assert(size:GetValue() == 21 and typedSize == 21, "focus loss cancels preview")
Editor(size):SetText("31")
size:SetEnabled(false)
assert(size:GetValue() == 21 and typedSize == 21, "disable cancels before suppressing callbacks")
size:SetEnabled(true)
Editor(size):SetText("invalid")
sizeEditor:GetScript("OnEnterPressed")()
assert(size:GetValue() == 21 and typedSize == 21, "invalid input cannot change saved value")
assert(not DetailsFrameworkSliderEditBox, "adapter does not patch DF's shared editor")

local builds = 0
local dropdown = widgets.CreateDropdown(UIParent, function()
    builds = builds + 1
    return {{label = "One", value = "ONE"}, {label = "Two", value = "TWO"}}
end, function(value) Changed(); selected = value end)
dropdown:SetValue("ONE")
dropdown:SetValue("TWO")
dropdown:SetLabel("Current label")
assert(builds == 1 and changes == 3 and dropdown:GetValue() == "TWO")
assert(dropdown.widget.label:GetText() == "Current label")
dropdown:InvalidateOptions()
dropdown:SetValue("ONE")
assert(builds == 2 and changes == 3)
dropdown.widget.func()[2].onclick(dropdown.widget, nil, "TWO")
assert(changes == 4 and selected == "TWO" and dropdown:GetValue() == "TWO")
dropdown:SetEnabled(false)
dropdown.widget.func()[1].onclick(dropdown.widget, nil, "ONE")
assert(changes == 4 and dropdown:GetValue() == "TWO", "disabled callback is ignored")

local function Click(frame)
    frame:GetScript("OnMouseDown")(frame, "LeftButton")
    frame:GetScript("OnMouseUp")(frame, "LeftButton")
end
local button = widgets.CreateButton(UIParent, "Action", Changed)
Click(button.frame)
assert(changes == 5, "DF button callback adapts to simple action")
button:SetEnabled(false)
Click(button.frame)
assert(changes == 5)
local color = widgets.CreateColorPicker(UIParent, function(r, g, b)
    Changed(); rgb = {r, g, b}
end)
color:SetColor(0.2, 0.3, 0.4)
assert(changes == 5 and color:GetColor() == 0.2)
Click(color.frame)
local picker = ColorPickerFrame.info
assert(picker.hasOpacity == false and not picker.opacityFunc, "picker is RGB only")
function ColorPickerFrame:GetColorRGB() return 0.8, 0.7, 0.6 end
picker.swatchFunc()
assert(changes == 6 and rgb[1] == 0.8 and color:GetColor() == 0.8)
picker.cancelFunc()
assert(changes == 7 and rgb[1] == 0.2 and rgb[2] == 0.3 and rgb[3] == 0.4)
assert(color:GetColor() == 0.2, "cancel restores captured RGB and notifies")

-- Picker lifecycle: setup is silent; replacement, hide and disable retire callbacks.
local count = changes
Click(color.frame)
local first = ColorPickerFrame.info
assert(changes == count, "native initial color event is suppressed")
first.swatchFunc()
assert(color:GetColor() == 0.8)
local other = widgets.CreateColorPicker(UIParent, function() Changed() end)
other:SetColor(0.1, 0.2, 0.3)
Click(other.frame)
assert(color:GetColor() == 0.2, "opening another swatch rolls back the first preview")
count = changes
first.cancelFunc(); first.swatchFunc()
assert(changes == count and other:GetColor() == 0.1, "retired callbacks are ignored")
local accepted = ColorPickerFrame.info
accepted.swatchFunc()
ColorPickerFrame:Hide() -- Native Okay hides after applying its final swatch callback.
count = changes
ns.SettingsUI.CancelColorEdit(); accepted.cancelFunc()
assert(changes == count and other:GetColor() == 0.8, "accepted previews stay committed")
other:SetColor(0.1, 0.2, 0.3)
Click(other.frame)
local disabled = ColorPickerFrame.info
disabled.swatchFunc()
other:SetEnabled(false)
count = changes
disabled.swatchFunc(); disabled.cancelFunc()
assert(changes == count and other:GetColor() == 0.1 and not ColorPickerFrame:IsShown(), "disable rolls back and retires the editor")
other:SetEnabled(true)
Click(color.frame)
local displaced = ColorPickerFrame.info
displaced.swatchFunc()
ColorPickerFrame:SetupColorPickerAndShow({extraInfo = {}, swatchFunc = function() end})
count = changes
ns.SettingsUI.CancelColorEdit(); displaced.cancelFunc(); displaced.swatchFunc()
assert(changes == count and ColorPickerFrame:IsShown(), "another addon's picker is left open")
ColorPickerFrame:Hide()

-- Inspect final assets on every adapter-created native child, including menus.
local function DescendsFrom(object, ancestor)
    while object do
        if object == ancestor then return true end
        object = object:GetParent()
    end
end
for _, control in ipairs({switch, slider, dropdown, button, color}) do
    for _, object in ipairs(ui.objects) do
        if DescendsFrom(object, control.frame) then
            for _, asset in ipairs({object.texture or "", object.backdrop and object.backdrop.bgFile or "",
                object.backdrop and object.backdrop.edgeFile or ""}) do
                assert(not tostring(asset):find("AddOns\\Details\\", 1, true), "external widget asset: " .. tostring(asset))
            end
        end
    end
end

-- Emulate a newer compatible embedder winning LibStub arbitration. Reloading
-- our bundle must preserve its table and registered methods, not downgrade it.
df.externalMarker = true
LibStub.minors["DetailsFramework-1.0"] = 763
LoadXML("Libs/DetailsFramework/load.xml")
assert(LibStub:GetLibrary("DetailsFramework-1.0") == df and df.externalMarker)
assert(LibStub.minors["DetailsFramework-1.0"] == 763 and widgets.GetFramework() == df)
local createSwitch = df.CreateSwitch
df.CreateSwitch = nil
local available, reason = widgets.GetFramework()
assert(not available and reason:find("CreateSwitch"), "incompatible external methods detected")
df.CreateSwitch = createSwitch
local originalStub = LibStub
LibStub = nil
assert(widgets.GetFramework() == nil, "missing library fails only at adapter construction")
LibStub = originalStub
assert(SimpleNameplatesDB == nil, "adapter behavior never writes saved settings")
print("Details Framework smoke: passed")

