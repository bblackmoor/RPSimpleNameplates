-- Simple Nameplates: global Total RP 3 integration settings.
local _, addon = ...
local UI = addon.SettingsUI

local function CreateTRP3Panel()
    local panel, content, layout = UI.CreateScrollablePanel("TRP3")
    UI.AddTitle(content, layout, "TRP3")
    UI.AddDescription(content, layout,
        "Applies to all characters and profiles.")
    local refreshers, controls = {}, {}
    local function RefreshIntegration() if addon.TRP3 then addon.TRP3.Refresh() end end
    local function Refresh()
        UI.RunRefreshers(refreshers)
        local enabled = addon.GetTRP3Enabled()
        for _, control in ipairs(controls) do
            control.toggle:SetEnabled(enabled)
            local shade = enabled and 1 or 0.5
            control.label:SetTextColor(shade, shade, shade, 1)
        end
    end
    UI.AddSwitchRow(content, layout, refreshers, "Display TRP3 profile information", addon.GetTRP3Enabled, function(enabled)
        addon.SetTRP3Enabled(enabled)
        RefreshIntegration()
        Refresh()
    end)
    local status = UI.AddDescription(content, layout, "")
    refreshers[#refreshers + 1] = function()
        if addon.TRP3 and addon.TRP3.IsAvailable() then
            status:SetText("Total RP 3 detected.")
            status:SetTextColor(0.35, 0.85, 0.35, 1)
        else
            status:SetText("Requires Total RP 3 to be installed and enabled.")
            status:SetTextColor(0.72, 0.72, 0.72, 1)
        end
    end
    UI.AddSection(content, layout, "Names and titles")
    local function AddOption(text, setting, description)
        local toggle, label = UI.AddSwitchRow(content, layout, refreshers, text,
            function() return addon.GetTRP3Setting(setting) end, function(checked)
                addon.SetTRP3Setting(setting, checked)
                RefreshIntegration()
            end)
        controls[#controls + 1] = {toggle = toggle, label = label}
        if description then UI.AddDescription(content, layout, description) end
    end
    AddOption("Use TRP3 roleplaying full name", "useRoleplayingName")
    AddOption("Show short title before the name", "showShortTitle")
    AddOption("Show [OOC] instead of the short title", "showOOC")
    AddOption("Show TRP3 long title beneath the health bar", "showFullTitle",
        "Uses 80% of the name size. An active cast or channel replaces the title; it returns when casting ends.")
    UI.AddDescription(content, layout,
        "Missing profile information uses the WoW name. NPC service titles do not require TRP3.")
    panel.Refresh = Refresh
    panel:SetScript("OnShow", panel.Refresh)
    Refresh()
    layout:Finish()
    return panel
end
addon.SettingsPanels.TRP3 = CreateTRP3Panel

