-- Simple Nameplates: appearance Profile management.
local _, addon = ...
local UI, Widgets = addon.SettingsUI, addon.SettingsWidgets
local AddDescription, RefreshNameplates = UI.AddDescription, UI.RefreshNameplates

local function CreateProfileButtons(content, layout, changed)
    local function OpenNameDialog(action, initial, profileName)
        StaticPopup_Show("SNP_PROFILE_NAME", nil, nil,
            {action = action, initial = initial, target = profileName and UI.CaptureProfileDialogTarget(profileName), onChanged = changed})
    end
    local function OpenActiveNameDialog(action, suffix)
        local name = addon.GetActiveProfileName()
        OpenNameDialog(action, name .. suffix, name)
    end
    local definitions = {
        {"Create", function() OpenNameDialog(addon.CreateProfile, "") end},
        {"Copy", function() OpenActiveNameDialog(addon.CopyActiveProfile, " Copy") end},
        {"Rename", function() OpenActiveNameDialog(addon.RenameActiveProfile, "") end},
        {"Delete", function()
            StaticPopup_Show("SNP_DELETE_PROFILE", addon.GetActiveProfileName(), nil,
                {target = UI.CaptureProfileDialogTarget(addon.GetActiveProfileName()), onChanged = changed})
        end},
    }
    local row = CreateFrame("Frame", nil, content)
    row.LayoutFullWidth = true
    layout:Add(row, 24, 24, 8)
    local buttons = {}
    for index, definition in ipairs(definitions) do
        local button = Widgets.CreateButton(row, definition[1], definition[2], 88, 24)
        if index == 1 then button:SetPoint("LEFT", row, "LEFT", 0, 0)
        else button:SetPoint("LEFT", buttons[index - 1], "RIGHT", 8, 0) end
        buttons[index] = button
    end
    return buttons
end

-- Compact selector shared by the visual pages; management remains here.
local function AddProfileSelector(content, layout, refreshers, onChanged, controlX)
    local row, dropdown
    local function Refresh()
        dropdown:InvalidateOptions() -- Profile names may be created/renamed/deleted elsewhere.
        local active = addon.GetActiveProfileName()
        dropdown:SetValue(active, active)
    end
    row, dropdown = UI.CreateDropdownRow(content, layout, "Selected profile", function()
        local options = {}
        for _, name in ipairs(addon.GetProfileNames()) do
            options[#options + 1] = {value = name, label = name}
        end
        return options
    end, function(name)
        addon.SetActiveProfileName(name)
        Refresh()
        if onChanged then onChanged() end
        RefreshNameplates()
    end, controlX)
    refreshers[#refreshers + 1] = Refresh
    Refresh()
    return row, dropdown
end
addon.AddProfileSelector = AddProfileSelector

local function CreateProfilesPanel()
    UI.RegisterProfileDialogs()
    local panel, content, layout = UI.CreateScrollablePanel("Profiles")
    UI.AddTitle(content, layout, "Profiles")
    AddDescription(content, layout,
        "Profiles are account-wide; each character remembers its selection.")
    local refreshers = {}
    local function Refresh() UI.RunRefreshers(refreshers) end
    local row, dropdown = AddProfileSelector(content, layout, refreshers, Refresh, 184)
    addon.AddStylingSwitch(row, dropdown, refreshers)
    AddDescription(content, layout, "Enables addon styling for all characters and profiles.")
    UI.AddSection(content, layout, "Manage profiles")
    AddDescription(content, layout,
        "Create uses factory defaults. Default cannot be renamed or deleted.")
    local function Changed() Refresh(); RefreshNameplates() end
    local buttons = CreateProfileButtons(content, layout, Changed)
    refreshers[#refreshers + 1] = function()
        local protected = addon.GetActiveProfileName() == addon.DEFAULT_PROFILE_NAME
        buttons[3]:SetEnabled(not protected)
        buttons[4]:SetEnabled(not protected)
    end
    UI.AddSection(content, layout, "Restore bundled profiles")
    AddDescription(content, layout,
        "Resets Default and High Contrast, recreating High Contrast if missing. Custom profiles are unchanged.")
    UI.AddPageAction(content, layout, "Restore bundled profiles", function()
        StaticPopup_Show("SNP_RESTORE_BUNDLED_PROFILES", nil, nil, {targets = UI.CaptureBundledProfileDialogTargets(), onChanged = Changed})
    end, 210)
    panel.Refresh = Refresh
    panel:SetScript("OnShow", panel.Refresh)
    Refresh()
    layout:Finish()
    return panel
end
addon.SettingsPanels.Profiles = CreateProfilesPanel

