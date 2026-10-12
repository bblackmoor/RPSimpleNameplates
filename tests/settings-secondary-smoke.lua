-- Profiles/TRP3/About with actual DF and database behavior; native rendering is separate.
local ui = dofile("tests/details-framework-ui-stubs.lua")
dofile("tests/details-framework-loader.lua")("Libs/DetailsFramework/load.xml")
local character = "Player-One"
function UnitGUID() return character end
function UnitFullName() return "Tester", "Realm" end
function strtrim(text) return text:match("^%s*(.-)%s*$") end
StaticPopupDialogs = {}
local popup
function StaticPopup_Show(key, text, _, data) popup = {key=key, text=text, data=data} end
function GameTooltip:SetOwner(frame) self.owner=frame end
function GameTooltip:AddLine() end
local ns, refreshes, integrations, setup, restored = {}, 0, 0, 0, 0
for _, file in ipairs({"Defaults", "FontMedia", "Core", "ManagedNames", "NameplateSetup", "Database",
    "SettingsControls", "SettingsColorPicker", "SettingsWidgets", "SettingsBehavior", "SettingsProfileDialogs", "SettingsProfiles", "SettingsTRP3", "SettingsAbout"}) do
    assert(loadfile("RPSimpleNameplates/" .. file .. ".lua"))("RPSimpleNameplates", ns)
end
ns.RefreshAll = function() refreshes=refreshes+1 end
ns.ApplyManagedNameSettings = function() end
ns.RestoreManagedNameSettings = function() restored=restored+1 end
ns.RestoreAll = function() restored=restored+1 end
local realSetupCheck = ns.CheckNameplateSetup
local allowSetup, available = true, false
ns.CheckNameplateSetup = function()
    setup=setup+1
    if not allowSetup then ns.SetStylingEnabled(false) end
    return allowSetup
end
ns.TRP3 = {Refresh=function() integrations=integrations+1 end, IsAvailable=function() return available end}
ns.GetActiveProfileName()
local function Snapshot(value)
    if type(value) ~= "table" then return tostring(value) end
    local entries={}
    for key, item in pairs(value) do entries[#entries+1]=tostring(key).."="..Snapshot(item) end
    table.sort(entries)
    return "{"..table.concat(entries, ",").."}"
end
local before=Snapshot(SimpleNameplatesDB)
local panels={ns.SettingsPanels.Profiles(), ns.SettingsPanels.TRP3(), ns.SettingsPanels.About()}
assert(Snapshot(SimpleNameplatesDB)==before and refreshes==0 and integrations==0, "construction is silent")
local function Show(panel) panel:GetScript("OnShow")(panel) end
local function Row(text)
    for _, object in ipairs(ui.objects) do
        if object.kind=="FontString" and object:GetText()==text then return object:GetParent(), object end
    end
    error("Missing row "..text)
end
local function Control(text, kind)
    for _, object in ipairs(ui.objects) do
        if object:GetParent()==Row(text) and object.MyObject and object.MyObject.type==kind then return object end
    end
    error("Missing control "..text)
end
local function Button(text)
    for _, object in ipairs(ui.objects) do
        if object.MyObject and object.MyObject.type=="button" and object.text:GetText()==text then return object end
    end
    error("Missing button "..text)
end
local function Click(frame)
    if frame:GetScript("OnClick") then frame:GetScript("OnClick")(frame, "LeftButton"); return end
    frame:GetScript("OnMouseDown")(frame, "LeftButton")
    frame:GetScript("OnMouseUp")(frame, "LeftButton")
end
local selector=Control("Selected profile", "dropdown")
local function Choose(value)
    for _, option in ipairs(selector.MyObject.func()) do
        if option.value==value then
            local item=CreateFrame("Button", nil, selector.dropdownframe:GetScrollChild())
            item.object, item.table=selector.MyObject, option
            DetailsFrameworkDropDownOptionClick(item)
            return
        end
    end
    error("Missing profile "..value)
end
local function AcceptName(text)
    local dialog=CreateFrame("Frame")
    dialog.editBox=CreateFrame("EditBox", nil, dialog)
    dialog.editBox:SetText(text)
    StaticPopupDialogs[popup.key].OnAccept(dialog, popup.data)
end
local rename, delete=Button("Rename"), Button("Delete")
assert(not rename:IsEnabled() and not delete:IsEnabled(), "Default actions disabled")
Click(rename); Click(delete)
assert(not popup and ns.GetActiveProfileName()=="Default", "disabled callbacks cannot open dialogs")
local canceled=0
ns.CancelAppearanceEdits=function(quiet) assert(quiet); canceled=canceled+1 end
Choose("High Contrast")
assert(canceled==1 and selector.MyObject.myvalue=="High Contrast" and rename:IsEnabled())
Click(Button("Create"))
assert(popup.key=="SNP_PROFILE_NAME" and popup.data.initial=="")
-- Opening/canceling a native dialog has no database side effect.
before=Snapshot(SimpleNameplatesDB)
local dialog=CreateFrame("Frame"); dialog.editBox=CreateFrame("EditBox", nil, dialog)
StaticPopupDialogs.SNP_PROFILE_NAME.OnShow(dialog, popup.data)
StaticPopupDialogs.SNP_PROFILE_NAME.EditBoxOnEscapePressed(dialog.editBox)
assert(Snapshot(SimpleNameplatesDB)==before)
AcceptName(" Custom ")
assert(ns.GetActiveProfileName()=="Custom" and ns.GetAppearanceSetting("nameSize")==18)
ns.SetAppearanceSetting("nameSize", 30)
Click(Button("Copy")); AcceptName("Independent")
assert(ns.GetAppearanceSetting("nameSize")==30)
ns.SetAppearanceSetting("nameSize", 24)
assert(ns.EnsureDB().profiles.Custom.appearance.nameSize==30, "copy is independent")
character="Player-Two"; ns.SetActiveProfileName("Independent"); character="Player-One"
Click(rename); AcceptName("Renamed")
assert(ns.EnsureDB().profileKeys["Player-Two"]=="Renamed", "rename updates all assignments")
before=Snapshot(SimpleNameplatesDB)
Click(rename); AcceptName("custom")
assert(Snapshot(SimpleNameplatesDB)==before, "duplicate rejection preserves data")
Click(delete)
assert(popup.key=="SNP_DELETE_PROFILE" and popup.text=="Renamed")
assert(Snapshot(SimpleNameplatesDB)==before, "delete requires acceptance")
StaticPopupDialogs[popup.key].OnAccept(nil, popup.data)
assert(ns.GetActiveProfileName()=="Default" and ns.EnsureDB().profileKeys["Player-Two"]=="Default")
assert(not rename:IsEnabled() and not delete:IsEnabled())
Choose("High Contrast"); Click(delete); StaticPopupDialogs[popup.key].OnAccept(nil, popup.data)
ns.SetAppearanceSetting("nameSize", 32); ns.SetTRP3Enabled(true)
assert(ns.EnsureDB().global.highContrastRemoved == true, "deleting optional bundle records removal")
local expectedGlobals = {}
for key, value in pairs(ns.EnsureDB().global) do expectedGlobals[key] = value end
expectedGlobals.highContrastRemoved = nil -- Explicit restore clears only the lifecycle marker.
local globals=Snapshot(expectedGlobals)
local custom=Snapshot(ns.EnsureDB().profiles.Custom)
Click(Button("Restore bundled profiles"))
assert(ns.GetAppearanceSetting("nameSize")==32 and not ns.EnsureDB().profiles["High Contrast"])
StaticPopupDialogs[popup.key].OnAccept(nil, popup.data)
assert(ns.GetAppearanceSetting("nameSize")==18 and ns.EnsureDB().profiles["High Contrast"])
assert(Snapshot(ns.EnsureDB().global)==globals and Snapshot(ns.EnsureDB().profiles.Custom)==custom)
-- Every selector rebuilds its menu after profile changes.
Show(panels[1])
for _, option in ipairs(selector.MyObject.func()) do assert(option.value~="Renamed") end
local styling=Control("Selected profile", "switch")
Click(styling); assert(not ns.GetStylingEnabled() and restored==2)
Click(styling); assert(ns.GetStylingEnabled() and setup==1)
Click(styling); allowSetup=false; Click(styling)
assert(not ns.GetStylingEnabled() and not styling.MyObject:GetValue(), "consent suspension reflected")
-- TRP3 keeps preferences while disabled and ignores disabled callbacks.
ns.SetTRP3Enabled(false); Show(panels[2])
local master=Control("Display TRP3 profile information", "switch")
local dependent=Control("Show TRP3 long title beneath the health bar", "switch")
local _, label=Row("Show TRP3 long title beneath the health bar")
local saved=ns.GetTRP3Setting("showFullTitle")
Click(dependent)
assert(ns.GetTRP3Setting("showFullTitle")==saved and not dependent:IsEnabled() and label.textColor[1]==0.5)
Click(master); assert(ns.GetTRP3Enabled() and dependent:IsEnabled() and label.textColor[1]==1)
local old=integrations; Click(dependent)
assert(ns.GetTRP3Setting("showFullTitle")==not saved and integrations==old+1)
Click(master); assert(not ns.GetTRP3Enabled() and not dependent:IsEnabled())
available=true; Show(panels[2]); Row("Total RP 3 detected.")
available=false; Show(panels[2]); Row("Requires Total RP 3 to be installed and enabled.")
-- About displays never enable color editing, dim their RGB, or use Details assets.
local colors={{"Opposite-faction PC labels in sanctuary",102/255,102/255,1,"SNP_BLIZZARD_OVERHEAD_INFO"},
    {"Native interactive-NPC world labels",1,1,0,"SNP_BLIZZARD_INTERACTIVE_INFO"},
    {"Native vendor-NPC world labels",0,1,0,"SNP_BLIZZARD_VENDOR_INFO"}}
for _, case in ipairs(colors) do
    local row=Row(case[1]); local swatch=Control(case[1], "button")
    assert(swatch.mouseEnabled==false and swatch:GetWidth()==26 and swatch:GetHeight()==26)
    local fill
    for _, object in ipairs(ui.objects) do if object:GetParent()==swatch and object.color then fill=object end end
    for i=1,3 do assert(fill.color[i]==case[i+1]) end
    local oldPopup=popup; Click(swatch); assert(popup==oldPopup and not ColorPickerFrame.options)
    local info
    for _, object in ipairs(ui.objects) do if object:GetParent()==row and not object.MyObject and object:GetScript("OnClick") then info=object end end
    info:GetScript("OnClick")(); assert(popup.key==case[5])
    row:GetScript("OnEnter")(row); assert(GameTooltip.owner==row)
end
local link=Button(ns.SOURCE_URL)
Click(link); assert(popup.key=="SNP_COPY_SOURCE" and popup.data==ns.SOURCE_URL)
local copyDialog=CreateFrame("Frame"); copyDialog.editBox=CreateFrame("EditBox", nil, copyDialog)
StaticPopupDialogs.SNP_COPY_SOURCE.OnShow(copyDialog, popup.data)
assert(copyDialog.editBox:GetText()==ns.SOURCE_URL)
StaticPopupDialogs.SNP_COPY_SOURCE.EditBoxOnEnterPressed(copyDialog.editBox)
assert(copyDialog.shown==false)
assert(link.backdropColor[4]==0 and link.backdropBorderColor[4]==0, "source link has no button background")
link:GetScript("OnEnter")(link); assert(link.text.textColor[1]==0.65)
link:GetScript("OnLeave")(link); assert(link.text.textColor[1]==0.35)
assert(link.backdropColor[4]==0 and link.backdropBorderColor[4]==0)
local integration=ns.TRP3; ns.TRP3=nil; Show(panels[2])
Row("Requires Total RP 3 to be installed and enabled.")
Click(master); assert(ns.GetTRP3Enabled(), "missing TRP3 module is safe")
ns.TRP3=integration
before=Snapshot(SimpleNameplatesDB); old=integrations; local oldRefresh=refreshes
Show(panels[1]); Show(panels[2])
assert(Snapshot(SimpleNameplatesDB)==before and integrations==old and refreshes==oldRefresh, "show refreshes are silent")
-- A confirmation stays tied to the profile named when it was opened.
Choose("Custom"); Click(delete)
local staleDelete = popup
Choose("High Contrast")
before=Snapshot(SimpleNameplatesDB)
StaticPopupDialogs.SNP_DELETE_PROFILE.OnAccept(nil, staleDelete.data)
assert(Snapshot(SimpleNameplatesDB)==before, "stale confirmation cannot delete the newly selected profile")
for _, action in ipairs({"Copy", "Rename"}) do
    Choose("Custom"); Click(Button(action))
    local staleName = popup
    Choose("High Contrast")
    before = Snapshot(SimpleNameplatesDB)
    popup = staleName; AcceptName("Wrong target")
    assert(Snapshot(SimpleNameplatesDB) == before, "stale " .. action .. " dialog is ignored")
end
-- Current Blizzard dialogs expose GetButton1 rather than a button1 field.
Click(Button("Create"))
local keyboardData = popup.data
local keyboardDialog = CreateFrame("Frame")
local keyboardEdit = CreateFrame("EditBox", nil, keyboardDialog)
keyboardEdit:SetText("Keyboard profile")
keyboardDialog.GetEditBox = function() return keyboardEdit end
local accept = CreateFrame("Button", nil, keyboardDialog)
accept.Click = function() StaticPopupDialogs.SNP_PROFILE_NAME.OnAccept(keyboardDialog, keyboardData) end
keyboardDialog.GetButton1 = function() return accept end
StaticPopupDialogs.SNP_PROFILE_NAME.EditBoxOnEnterPressed(keyboardEdit)
assert(ns.GetActiveProfileName() == "Keyboard profile", "Enter accepts a modern profile dialog")
Click(Button("Create")); keyboardData = popup.data
keyboardEdit:SetText("Blocked keyboard profile"); accept:Disable()
StaticPopupDialogs.SNP_PROFILE_NAME.EditBoxOnEnterPressed(keyboardEdit)
assert(not ns.EnsureDB().profiles["Blocked keyboard profile"], "Enter respects a disabled accept button")
accept:Enable(); keyboardDialog.GetButton1 = nil; keyboardDialog.button1 = accept
StaticPopupDialogs.SNP_PROFILE_NAME.EditBoxOnEnterPressed(keyboardEdit)
assert(ns.GetActiveProfileName() == "Blocked keyboard profile", "legacy accept field remains supported")
-- Setup approval resumes effective styling while Profiles is already visible.
ns.CheckNameplateSetup = realSetupCheck
local cvars = {nameplateShowAll="1", nameplateShowEnemies="1",
    nameplateShowFriendlyPlayers="1", nameplateShowFriendlyNpcs="0",
    nameplateShowOnlyNameForFriendlyPlayerUnits="0"}
C_CVar.GetCVar = function(name) return cvars[name] end
C_CVar.SetCVar = function(name, value) cvars[name] = value end
ns.SetStylingEnabled(false); Show(panels[1])
Click(styling)
assert(ns.nameplateSetupPending and not styling.MyObject:GetValue())
assert(popup.key == "SNP_NAMEPLATE_SETUP")
StaticPopupDialogs.SNP_NAMEPLATE_SETUP.OnAccept()
assert(ns.GetStylingEnabled() and styling.MyObject:GetValue(), "visible styling control refreshes after setup approval")
local activationStatus
for _, object in ipairs(ui.objects) do
    if object:GetParent() == Row("Selected profile") and object.kind == "FontString" and object:GetText() == "Active" then activationStatus = object end
end
assert(activationStatus)
cvars.nameplateShowFriendlyNpcs = "0"
ns.CheckNameplateSetup()
assert(not styling.MyObject:GetValue() and activationStatus:GetText() == "Inactive", "external setup suspension refreshes the visible switch/status")
StaticPopupDialogs.SNP_NAMEPLATE_SETUP.OnCancel()
assert(not ns.GetStylingEnabled() and not styling.MyObject:GetValue())
local blocked, combat = true, false
C_CVar.SetCVar = function(name, value) if not blocked then cvars[name] = value end end
InCombatLockdown = function() return combat end
Click(styling); StaticPopupDialogs.SNP_NAMEPLATE_SETUP.OnAccept()
assert(ns.nameplateSetupPending and not styling.MyObject:GetValue(), "rejected writes remain inactive")
blocked, combat = false, true
StaticPopupDialogs.SNP_NAMEPLATE_SETUP.OnAccept()
assert(ns.nameplateSetupPending and not styling.MyObject:GetValue(), "combat-deferred approval remains inactive")
combat = false; ns.RetryNameplateSetup()
assert(ns.GetStylingEnabled() and styling.MyObject:GetValue() and activationStatus:GetText() == "Active", "deferred completion refreshes switch/status")
print("Profiles, TRP3 and About integration smoke: passed")


-- About paragraphs and the copy-source link reflow when the viewport narrows.
do
    local linkFrame = Button(ns.SOURCE_URL)
    assert(linkFrame.text.wordWrap and linkFrame.text.nonSpaceWrap, "source URLs wrap without spaces")
    local content = linkFrame:GetParent()
    local scroll = content:GetParent()
    local panel = scroll:GetParent()
    local paragraphs = {}
    for _, object in ipairs(ui.objects) do
        if object.kind == "FontString" and object:GetParent() == content then
            local text = object:GetText() or ""
            if text:find("Version:", 1, true) then
                assert(text:find("Author: Brandon Blackmoor", 1, true))
                assert(text:find("Category:", 1, true) and text:find("License: GPL-3.0", 1, true))
            end
            if object.LayoutFullWidth then
                paragraphs[#paragraphs + 1] = object
                object.GetStringHeight = function(self)
                    assert(self:GetHeight() == 0, "clear previous text height before measuring")
                    return math.ceil(#(self:GetText() or "") * 6 / self:GetWidth()) * 12
                end
            end
        end
    end
    linkFrame.text.GetStringHeight = function(self)
        assert(self:GetHeight() == 0)
        return math.ceil(#self:GetText() * 6 / self:GetWidth()) * 12
    end
    assert(#paragraphs >= 4, "About uses responsive paragraphs")
    scroll:SetSize(640, 180)
    panel:GetScript("OnShow")(panel)
    local wideHeight = content:GetHeight()
    scroll:SetSize(240, 180)
    scroll:GetScript("OnSizeChanged")(scroll, 240, 180)
    assert(content:GetHeight() > wideHeight, "narrow About expands scroll content")
    assert(linkFrame:GetWidth() == content:GetWidth() - 48)
    assert(linkFrame:GetHeight() > 16, "source link wraps with its clickable area")
    scroll:SetSize(640, 180)
    panel:GetScript("OnShow")(panel)
    assert(content:GetHeight() == wideHeight, "About shrinks again without stale height")
end
local perfFound = false
for _, object in ipairs(ui.objects) do
    if object.kind == "FontString" and (object:GetText() or ""):find("/snp perf [start|stop|report]", 1, true) then perfFound = true end
end
assert(perfFound, "About documents profiling")

-- Same-name factory replacement invalidates profile lifecycle confirmations.
for _, action in ipairs({"Copy", "Rename", "Delete"}) do
    Choose("High Contrast"); Click(Button(action))
    local pending = popup
    ns.RestoreBundledProfiles()
    local saved = Snapshot(SimpleNameplatesDB)
    popup = pending
    if action == "Delete" then StaticPopupDialogs.SNP_DELETE_PROFILE.OnAccept(nil, pending.data)
    else AcceptName("Replaced target " .. action) end
    assert(Snapshot(SimpleNameplatesDB) == saved, "same-name replacement invalidates " .. action)
end
Choose("Default"); Click(Button("Restore bundled profiles"))
local pending = popup
ns.RestoreBundledProfiles()
ns.SetAppearanceSetting("nameSize", 29)
local saved = Snapshot(SimpleNameplatesDB)
StaticPopupDialogs.SNP_RESTORE_BUNDLED_PROFILES.OnAccept(nil, pending.data)
assert(Snapshot(SimpleNameplatesDB) == saved, "stale bundled restore cannot overwrite a replacement")
Choose("High Contrast"); assert(ns.DeleteActiveProfile())
Show(panels[1]); Click(Button("Restore bundled profiles")); pending = popup
assert(ns.CopyActiveProfile("High Contrast"))
ns.SetAppearanceSetting("nameSize", 30)
saved = Snapshot(SimpleNameplatesDB)
StaticPopupDialogs.SNP_RESTORE_BUNDLED_PROFILES.OnAccept(nil, pending.data)
assert(Snapshot(SimpleNameplatesDB) == saved, "new object under a previously missing bundled name is protected")
print("PASS profile dialog replacement identity and missing-target guards")
