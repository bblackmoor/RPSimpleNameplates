-- Simple Nameplates: per-character styling switch and its setup/restoration lifecycle.
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

-- A dedicated character row, separate from the account-wide profile selector.
local function AddStylingSwitch(row, anchor, refreshers)
    local toggle
    local function refresh() toggle:SetChecked(GetStylingEnabled()) end
    toggle = addon.SettingsWidgets.CreateSwitch(row, function(checked)
        SetStylingEnabled(checked)
        HandleStylingChanged(checked)
        -- Compatibility checks may pause styling while their dialog is open.
        refresh()
    end)
    toggle:SetPoint("LEFT", row, "LEFT", UI.CONTROL_X, 0)
    refreshers[#refreshers + 1] = refresh
    addon.RefreshStylingControl = refresh
    refresh()
    return toggle
end

addon.AddStylingSwitch = AddStylingSwitch

