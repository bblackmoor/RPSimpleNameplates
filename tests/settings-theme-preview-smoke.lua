-- Actual DF pages: complete previews, effect-specific layout and theme dialog.
local ui = dofile("tests/details-framework-ui-stubs.lua")
dofile("tests/details-framework-loader.lua")("Libs/DetailsFramework/load.xml")
function UnitGUID() return "Player-Preview" end
function strtrim(text) return text:match("^%s*(.-)%s*$") end
StaticPopupDialogs = {}
function StaticPopup_Show() end
local ns, refreshes, combat = {}, {}, false
function InCombatLockdown() return combat end
for _, file in ipairs({"Defaults", "FontMedia", "Core", "ManagedNames", "Database", "Themes", "FontRendering", "HealthGradient", "SettingsControls", "SettingsColorPicker", "SettingsWidgets", "SettingsProfileDialogs", "SettingsThemes", "SettingsProfiles", "SettingsPreview", "SettingsAppearance", "SettingsHighlight", "SettingsColors", "SettingsBehavior"}) do
    assert(loadfile("RPSimpleNameplates/" .. file .. ".lua"))("RPSimpleNameplates", ns)
end
ns.RefreshAll = function() refreshes[#refreshes+1] = "full" end
ns.QueueNameplateRefresh = function(_, work) refreshes[#refreshes+1] = work end
ns.WorldContext = {Get=function() return {} end}
ns.PresentationCapabilities = {ObjectStatus=function() return "accessible" end, ReadRegion=function(object, key) return object[key](object) end}
local animations = {}
ns.CastHighlight = {
    UpdatePreview=function(bar) animations[bar] = ns.GetInterruptibleHighlightEnabled() end,
    StopPreview=function(bar) animations[bar] = nil end,
}
ns.GetActiveProfileName()
local panels = {ns.SettingsPanels.Profiles(), ns.SettingsPanels.Appearance(), ns.SettingsPanels.Colors(), ns.SettingsPanels.Highlight()}
local function Belongs(object, parent)
    while object do if object == parent then return true end; object=object:GetParent() end
end
local function Object(panel, text)
    for _, object in ipairs(ui.objects) do
        if Belongs(object, panel) and object.kind=="FontString" and object:GetText()==text then return object end
    end
    error("Missing text: " .. text)
end
local function Control(panel, text, kind)
    local row=Object(panel, text):GetParent()
    for _, object in ipairs(ui.objects) do
        if object:GetParent()==row and object.MyObject and object.MyObject.type==kind then return object end
    end
    error("Missing control: " .. text)
end
local function Button(panel, text)
    for _, object in ipairs(ui.objects) do
        if Belongs(object, panel) and object.MyObject and object.MyObject.type=="button" and object.text:GetText()==text then return object end
    end
    error("Missing button: " .. text)
end
local function Click(frame)
    if frame:GetScript("OnClick") then frame:GetScript("OnClick")(frame, "LeftButton")
    else frame:GetScript("OnMouseDown")(frame, "LeftButton"); frame:GetScript("OnMouseUp")(frame, "LeftButton") end
end
local function Choose(frame, value)
    for _, option in ipairs(frame.MyObject.func()) do if option.value==value then option.onclick(nil,nil,value); return end end
    error("Missing choice: " .. value)
end
for index=2,4 do
    local panel=panels[index]
    panel:Show(); panel.Refresh()
    assert(Object(panel, "Sample Name") and Object(panel, "Sample title") and Object(panel, "125%"))
end
local text, colors, cast = panels[2], panels[3], panels[4]
local sampleName=Object(text, "Sample Name")
Control(text, "Name size", "slider"):SetValue(30)
assert(sampleName.fontSize==30 and refreshes[#refreshes].text)
local sampleTitle=Object(text, "Sample title")
assert(sampleTitle.fontSize==28, "title preview uses runtime name size minus two")
Choose(Control(text, "Sample category", "dropdown"), "useless")
assert(sampleName.textColor[1]==0.6 and sampleTitle.textColor[1]==0.6)
Click(Control(text, "Preview a cast", "switch"))
assert(not sampleTitle:IsShown(), "preview casts replace titles")
local effect=Control(cast, "Effect", "dropdown")
local fade=Object(cast,"Fade in"):GetParent()
local length=Object(cast,"Minimum length"):GetParent()
assert(fade:IsShown() and not length:IsShown())
Control(cast,"Fade in","slider"):SetValue(0.6)
Choose(effect,"ALERT")
assert(not fade:IsShown() and length:IsShown())
Control(cast,"Minimum length","slider"):SetValue(35)
local offset=Object(cast,"Border offset"):GetParent().point[5]
Choose(effect,"SOLID")
assert(not fade:IsShown() and not length:IsShown())
assert(Object(cast,"Border offset"):GetParent().point[5]==offset)
Choose(effect,"PULSE")
assert(fade:IsShown() and ns.GetCastBorderSetting("PULSE","fadeIn")==0.6 and ns.GetCastBorderSetting("ALERT","minLength")==35)
Click(Control(cast,"Highlight interruptible casts","switch"))
assert(refreshes[#refreshes].castSettings)
Control(colors,"Gradient opacity","slider"):SetValue(50)
assert(refreshes[#refreshes].color)
Click(Control(colors,"1. Attacking me","switch"))
assert(refreshes[#refreshes]=="full", "visibility change uses structural refresh")
-- Import targets the selected profile, replaces only visuals, and reports malformed input.
Click(Button(panels[1],"Export theme"))
local dialog
for _, object in ipairs(ui.objects) do if object.editor and object.data then dialog=object end end
assert(dialog and dialog:IsShown())
local exported=dialog.editor:GetText()
assert(exported:find("RPSN-THEME:1",1,true))
ns.SettingsUI.CancelThemeDialog()
ns.SetStylingEnabled(false); ns.SetTRP3Enabled(true)
Click(Button(panels[1],"Import theme"))
dialog.editor:SetText("bad input")
Click(dialog.accept:GetFrame())
assert(dialog:IsShown() and dialog.status:GetText()~="")
dialog.editor:SetText(exported)
Click(dialog.accept:GetFrame())
assert(not dialog:IsShown() and not ns.GetStylingEnabled() and ns.GetTRP3Enabled())
assert(ns.GetAppearanceSetting("nameSize")==30)
Click(Button(panels[1],"Import theme"))
assert(dialog:IsShown())
ns.SetActiveProfileName("High Contrast")
assert(not dialog:IsShown(), "profile change cancels pending import")
Click(Button(panels[1],"Import theme"))
ns.SettingsUI.InstallCombatGuard()
local events
for _, object in ipairs(ui.objects) do if object:GetScript("OnEvent") then events=object end end
combat=true; events:GetScript("OnEvent")(events,"PLAYER_REGEN_DISABLED")
assert(not dialog:IsShown(), "combat discards pending import")
combat=false; events:GetScript("OnEvent")(events,"PLAYER_REGEN_ENABLED")
cast:GetScript("OnHide")(cast)
for _, object in ipairs(ui.objects) do if Belongs(object,cast) then assert(not animations[object], "hidden page stops preview animation") end end
print("Theme dialog and shared preview smoke: passed")
