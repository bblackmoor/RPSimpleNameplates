-- Simple Nameplates: About settings page.
local _, addon = ...
local UI, Widgets = addon.SettingsUI, addon.SettingsWidgets
local CreateScrollablePanel, AddTitle, AddDescription =
    UI.CreateScrollablePanel, UI.AddTitle, UI.AddDescription
local VERSION, SOURCE_URL = addon.VERSION, addon.SOURCE_URL

-- Record entity types and observed world contexts, not individual names.
-- Mirror the register in the README without generalizing to untested contexts.
local PRESENTATION_LIMITS = {
    { "Opposite-faction PCs, nonattackable in either direction",
      "Sanctuary; observed in Silvermoon City / The Bazaar with an Alliance viewer and Horde PCs" },
}

local function RegisterWorldLabelPopups()
    StaticPopupDialogs["SNP_BLIZZARD_OVERHEAD_INFO"] = {
        text = "In the sanctuary contexts listed here, nonattackable opposite-faction PCs have native overhead names without an accessible nameplate. The addon cannot style those names.\n\nPet, guardian, totem and minion world labels are also separate; their accessible nameplates can still be styled.",
        button1 = OKAY or "Okay", timeout = 0, whileDead = true,
        hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["SNP_BLIZZARD_INTERACTIVE_INFO"] = {
        text = "Native world labels use Blizzard's colors. Enable Friendly NPC Nameplates to allow styling of separate accessible plates and verified service titles.",
        button1 = OKAY or "Okay", timeout = 0, whileDead = true,
        hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["SNP_BLIZZARD_VENDOR_INFO"] = {
        text = "Native vendor world labels use Blizzard's colors. Enable Friendly NPC Nameplates to allow styling of separate accessible plates and verified service titles.",
        button1 = OKAY or "Okay", timeout = 0, whileDead = true,
        hideOnEscape = true, preferredIndex = 3,
    }
end

local function CreateLockedColorRow(context, text, r, g, b, popupKey)
    local content, layout = context.content, context.layout
    local row = UI.CreateSettingRow(content, layout, text)
    local swatch = Widgets.CreateColorDisplay(row, r, g, b)
    swatch:SetPoint("LEFT", row, "LEFT", UI.CONTROL_X, 0)
    UI.CreateInfoLink(row, swatch:GetFrame(), popupKey)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text)
        GameTooltip:AddLine("This color is chosen by Blizzard and cannot be edited.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function CreateAboutPanel()
    local panel, content, layout = CreateScrollablePanel("About")
    StaticPopupDialogs["SNP_COPY_SOURCE"] = {
        text = "Press Ctrl+C to copy the source URL.", button1 = CLOSE or "Close",
        hasEditBox = true, maxLetters = 255, editBoxWidth = 340,
        OnShow = function(self, url)
            local editBox = self.GetEditBox and self:GetEditBox() or self.editBox
            editBox:SetText(url or self.data or SOURCE_URL)
            editBox:SetFocus()
            editBox:HighlightText()
        end,
        EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    AddTitle(content, layout, "About")
    RegisterWorldLabelPopups()
    AddDescription(content, layout,
        "Customizes accessible Blizzard nameplates with priority colors, text styling and selectable interruptible-cast highlights.")

    AddDescription(content, layout, "Version: " .. VERSION .. "\nAuthor: Brandon Blackmoor\nCategory: Unit Frames\nLicense: GPL-3.0")

    AddDescription(content, layout, "Source:")
    local sourceLink = Widgets.CreateLink(content, SOURCE_URL, function()
        StaticPopup_Show("SNP_COPY_SOURCE", nil, nil, SOURCE_URL)
    end)
    local sourceFrame = sourceLink:GetFrame()
    sourceFrame.LayoutFullWidth = true
    sourceFrame.text:SetWordWrap(true)
    sourceFrame.text:SetNonSpaceWrap(true)
    sourceFrame.LayoutText = sourceFrame.text
    layout:Add(sourceFrame, 24, 16, 8, true)

    UI.AddSection(content, layout, "Commands")
    AddDescription(content, layout,
        "/snp or /snp text — Text settings\n" ..
        "/snp profiles — Manage appearance profiles\n" ..
        "/snp colors — Color settings\n" ..
        "/snp highlight — Interruptible border settings\n" ..
        "/snp trp3 — TRP3 settings\n" ..
        "/snp debug — Explain the current target\n" ..
        "/snp debug mouseover — Inspect without targeting\n" ..
        "/snp debug nearby [name] — Snapshot existing plates without targeting or hovering\n" ..
        "/snp perf [start|stop|report] — Record or report performance\n" ..
        "/snp about — This page")
    UI.AddSection(content, layout, "Presentation limits")
    AddDescription(content, layout,
        "No accessible nameplate was found in these contexts despite enabled visibility settings; " ..
        "the addon cannot change the native name, font, size, color, titles or position.")
    for _, case in ipairs(PRESENTATION_LIMITS) do
        AddDescription(content, layout, case[1] .. " — " .. case[2])
    end
    AddDescription(content, layout,
        "Observed 2026-10-02; other contexts may differ. Duplicate NPC widget labels were fixed in v1.0.117; " ..
        "ordinary NPC names and service titles can be styled.")
    UI.AddSection(content, layout, "Native world-label examples")
    AddDescription(content, layout,
        "Read-only examples of Blizzard's separate world labels. Accessible NPC and minion nameplates can still be styled.")
    local context = {content = content, layout = layout}
    CreateLockedColorRow(context, "Opposite-faction PC labels in sanctuary",
        102 / 255, 102 / 255, 1, "SNP_BLIZZARD_OVERHEAD_INFO")
    CreateLockedColorRow(context, "Native interactive-NPC world labels",
        1, 1, 0, "SNP_BLIZZARD_INTERACTIVE_INFO")
    CreateLockedColorRow(context, "Native vendor-NPC world labels",
        0, 1, 0, "SNP_BLIZZARD_VENDOR_INFO")
    layout:Finish()
    return panel
end
addon.SettingsPanels.About = CreateAboutPanel


