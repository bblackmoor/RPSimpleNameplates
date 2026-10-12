-- Simple Nameplates: global styling switch and its setup/restoration lifecycle.
local _, addon = ...
local UI = addon.SettingsUI
local GetStylingEnabled, SetStylingEnabled = addon.GetStylingEnabled, addon.SetStylingEnabled

local function HandleStylingChanged(enabled)
    if enabled then
        if addon.CheckNameplateSetup and not addon.CheckNameplateSetup() then return end
        addon.ApplyManagedNameSettings()
        UI.RefreshNameplates()
    else
        addon.RestoreManagedNameSettings()
        if addon.RestoreAll then addon.RestoreAll() end
    end
end

-- Matches the Colors-page switch/status layout; activation remains global.
local function AddStylingSwitch(row, anchor, refreshers)
    local toggle, _, refresh
    toggle, _, refresh = UI.AddSwitchStatus(row, anchor, refreshers, GetStylingEnabled, function(checked)
        SetStylingEnabled(checked)
        HandleStylingChanged(checked)
        -- Compatibility checks may pause styling while their dialog is open.
        refresh()
    end)
    addon.RefreshStylingControl = refresh
    refresh()
    return toggle
end

addon.AddStylingSwitch = AddStylingSwitch

