-- Combat entry/exit with actual DF controls, database and native picker contracts.
local ui = dofile("tests/details-framework-ui-stubs.lua")
local methods = getmetatable(UIParent).__index
function methods:Hide()
    if self.shown == false then return end
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
dofile("tests/details-framework-loader.lua")("Libs/DetailsFramework/load.xml")
max, min = math.max, math.min
local combat = false
function InCombatLockdown() return combat end
function UnitAffectingCombat(unit) assert(unit == "player"); return combat end
function UnitGUID() return "Player-CombatSettings" end
function UnitFullName() return "CombatSettings", "Realm" end
function strtrim(text) return text:match("^%s*(.-)%s*$") end
function GameTooltip:SetOwner(frame) self.owner = frame end
function GameTooltip:AddLine() end
StaticPopupDialogs = {}
local popups = {}
function StaticPopup_Show(key, _, _, data)
    local popup = CreateFrame("Frame")
    popup.editBox = CreateFrame("EditBox", nil, popup)
    popup.data = data
    popups[key] = popup
    local definition = StaticPopupDialogs[key]
    if definition.OnShow then definition.OnShow(popup, data) end
    return popup
end
function StaticPopup_Hide(key) if popups[key] then popups[key]:Hide() end end
local ns = {}
for _, file in ipairs({"Defaults", "FontMedia", "Core", "ManagedNames", "Database",
    "HealthGradient", "FontRendering", "SettingsControls", "SettingsColorPicker", "SettingsWidgets",
    "SettingsBehavior", "SettingsProfileDialogs", "SettingsProfiles", "SettingsAppearance", "SettingsHighlight", "SettingsColors", "SettingsTRP3"}) do
    assert(loadfile("RPSimpleNameplates/" .. file .. ".lua"))("RPSimpleNameplates", ns)
end
ns.RefreshAll = function() end
ns.WorldContext = {Get = function() return {} end}
ns.PresentationCapabilities = {ObjectStatus = function() return "accessible" end,
    ReadRegion = function(object, method) return object[method](object) end}
ns.TRP3 = {Refresh = function() end, IsAvailable = function() return false end}
ns.GetActiveProfileName()
local panels = {ns.SettingsPanels.Profiles(), ns.SettingsPanels.Appearance(), ns.SettingsPanels.Colors(), ns.SettingsPanels.Highlight(), ns.SettingsPanels.TRP3()}
ns.SettingsUI.InstallCombatGuard()
local events
for _, object in ipairs(ui.objects) do
    if object:GetScript("OnEvent") then events = object end
end
assert(events)
local function Row(label)
    for _, object in ipairs(ui.objects) do
        if object.kind == "FontString" and object:GetText() == label then return object:GetParent() end
    end
    error("Missing row: " .. label)
end
local function Control(label, kind)
    for _, object in ipairs(ui.objects) do
        if object:GetParent() == Row(label) and object.MyObject then
            local widget = object.MyObject
            if kind == "color" and widget.__iscolorpicker then return object end
            if widget.type == kind and not widget.__iscolorpicker then return object end
        end
    end
    error("Missing control: " .. label)
end
local function Button(text)
    for _, object in ipairs(ui.objects) do
        if object.MyObject and object.MyObject.type == "button" and object.text:GetText() == text then return object end
    end
    error("Missing button: " .. text)
end
local function Click(frame)
    if frame:GetScript("OnClick") then frame:GetScript("OnClick")(frame, "LeftButton")
    else
        frame:GetScript("OnMouseDown")(frame, "LeftButton")
        frame:GetScript("OnMouseUp")(frame, "LeftButton")
    end
end
local function Editor(frame)
    frame:GetScript("OnMouseDown")(frame, "RightButton")
    for _, object in ipairs(ui.objects) do
        if object.kind == "EditBox" and object:GetParent() == frame then return object end
    end
end
local function Enter() combat = true; events:GetScript("OnEvent")(events, "PLAYER_REGEN_DISABLED") end
local function Leave() combat = false; events:GetScript("OnEvent")(events, "PLAYER_REGEN_ENABLED") end
local function Snapshot(value)
    if type(value) ~= "table" then return tostring(value) end
    local entries = {}
    for key, item in pairs(value) do entries[#entries + 1] = tostring(key) .. "=" .. Snapshot(item) end
    table.sort(entries)
    return "{" .. table.concat(entries, ",") .. "}"
end
local size = Control("Name size", "slider")
local width = Control("Health bar width", "slider")
local effect = Control("Effect", "dropdown")
local gradientOpacity = Control("Gradient opacity", "slider")
local pulseThickness = Control("Border thickness", "slider")
local pulseLength = Control("Minimum length", "slider")
local pulseOpacity = Control("End opacity", "slider")
local swatch = Control("Interruptible cast highlight", "color")
local castToggle = Control("Interruptible cast highlight", "switch")
local trpChild = Control("Use TRP3 roleplaying full name", "switch")
assert(not trpChild:IsEnabled(), "TRP3 dependent starts disabled")
-- Previously committed edits survive; only unfinished sessions roll back.
size:SetValue(25)
Click(castToggle)
local originalWidth = width:GetValue()
local originalOpacity = gradientOpacity:GetValue()
local originalPulse = pulseThickness:GetValue()
local originalLength = pulseLength:GetValue()
local originalPulseOpacity = pulseOpacity:GetValue()
local baseline = Snapshot(SimpleNameplatesDB)
local editor = Editor(size)
editor:SetText("32")
width:GetScript("OnMouseDown")(width, "LeftButton")
width:SetValue(145)
pulseThickness:GetScript("OnMouseDown")(pulseThickness, "LeftButton")
pulseThickness:SetValue(9)
pulseLength:GetScript("OnMouseDown")(pulseLength, "LeftButton")
pulseLength:SetValue(80)
pulseOpacity:GetScript("OnMouseDown")(pulseOpacity, "LeftButton")
pulseOpacity:SetValue(50)
gradientOpacity:GetScript("OnMouseDown")(gradientOpacity, "LeftButton")
gradientOpacity:SetValue(40)
Click(swatch)
local retainedPicker = ColorPickerFrame.info
function ColorPickerFrame:GetColorRGB() return 0.1, 0.2, 0.3 end
retainedPicker.swatchFunc()
DetailsFrameworkDropDownOnMouseDown(effect, "LeftButton")
assert(effect.dropdownframe:IsShown())
Click(Button("Create"))
local oldPopup = popups.RPSN_PROFILE_NAME
oldPopup.editBox:SetText("Cancelled combat profile")
Enter()
assert(Snapshot(SimpleNameplatesDB) == baseline, "typed, drag and RGB previews roll back to committed values")
assert(size:GetValue() == 25 and width:GetValue() == originalWidth and not editor:IsShown())
assert(gradientOpacity:GetValue() == originalOpacity, "unfinished opacity drag cancelled")
assert(pulseThickness:GetValue() == originalPulse, "unfinished Colors slider drag cancelled")
assert(pulseLength:GetValue() == originalLength and pulseOpacity:GetValue() == originalPulseOpacity, "unfinished pulse length/gradient edits cancelled")
assert(not effect.dropdownframe:IsShown() and effect.MyObject.myvalue == "PULSE", "menu closes and current choice is restored")
assert(not ColorPickerFrame:IsShown() and not oldPopup:IsShown(), "owned picker and profile dialog close")
assert(oldPopup.data.cancelled, "cancelled dialog callbacks cannot revive after combat")
for _, frame in ipairs({size, width, pulseThickness, pulseLength, pulseOpacity, gradientOpacity, effect, swatch, castToggle, Button("Reset text settings"), Button("Reset color settings"), Button("Create")}) do
    assert(not frame:IsEnabled(), "editable control is disabled")
end
-- Simulate callbacks already queued before lockdown, and refresh while locked.
retainedPicker.swatchFunc()
retainedPicker.cancelFunc()
StaticPopupDialogs.RPSN_PROFILE_NAME.OnAccept(oldPopup, oldPopup.data)
effect.MyObject.func()[2].onclick(effect.MyObject, nil, "SOLID")
size:SetValue(33)
pulseLength:SetValue(40)
pulseOpacity:SetValue(80)
Click(castToggle)
Click(Button("Reset color settings"))
Click(Button("Restore bundled profiles"))
for _, panel in ipairs(panels) do panel.Refresh() end
assert(Snapshot(SimpleNameplatesDB) == baseline and size:GetValue() == 25, "combat callbacks and page refresh cannot change settings")
assert(not Button("Create"):IsEnabled() and not trpChild:IsEnabled())
Leave()
assert(size:IsEnabled() and width:IsEnabled() and pulseThickness:IsEnabled() and pulseLength:IsEnabled() and pulseOpacity:IsEnabled() and effect:IsEnabled() and castToggle:IsEnabled())
assert(not Button("Rename"):IsEnabled() and not Button("Delete"):IsEnabled(), "Default protection survives combat exit")
assert(not trpChild:IsEnabled(), "dependency disable survives combat exit")
StaticPopupDialogs.RPSN_PROFILE_NAME.OnAccept(oldPopup, oldPopup.data)
retainedPicker.swatchFunc()
assert(Snapshot(SimpleNameplatesDB) == baseline, "cancelled sessions remain inert after combat")
size:SetValue(26)
Click(castToggle)
assert(ns.GetAppearanceSetting("nameSize") == 26 and not ns.GetInterruptibleHighlightEnabled(), "normal editing resumes")
-- Native combat queries guard the gap before the event and controls made in combat.
combat = true
Click(castToggle)
assert(not ns.GetInterruptibleHighlightEnabled())
local late = ns.SettingsWidgets.CreateSwitch(UIParent, function() error("late combat callback") end)
assert(not late:GetFrame():IsEnabled())
Enter(); Leave()
assert(late:GetFrame():IsEnabled())
print("Combat settings smoke: passed")
