-- Copy/paste theme exchange tied to the selected profile's name and identity.
local _, addon = ...
local UI, Widgets = addon.SettingsUI, addon.SettingsWidgets
local dialog
function UI.CancelThemeDialog()
    if dialog then dialog:Hide() end
end
local function OpenThemeDialog(importing, changed)
    if not Widgets.IsEditingAllowed() then return end
    UI.CancelColorEdit()
    UI.CancelThemeDialog()
    local target = UI.CaptureProfileDialogTarget(addon.GetActiveProfileName())
    if not dialog then
        dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        dialog:SetSize(600, 410)
        dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("DIALOG")
        dialog:SetClampedToScreen(true)
        dialog:EnableMouse(true)
        dialog:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
        dialog:SetBackdropColor(0.06, 0.06, 0.07, 1)
        dialog:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 20, -18)
        title:SetWidth(560)
        title:SetJustifyH("LEFT")
        local instructions = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        instructions:SetPoint("TOPLEFT", 20, -48)
        instructions:SetWidth(560)
        instructions:SetJustifyH("LEFT")
        local scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -90)
        scroll:SetPoint("BOTTOMRIGHT", -40, 85)
        local editor = CreateFrame("EditBox", nil, scroll)
        editor:SetMultiLine(true)
        editor:SetAutoFocus(false)
        editor:SetFontObject("GameFontHighlightSmall")
        editor:SetWidth(530)
        editor:SetMaxLetters(16384)
        editor:SetHeight(230)
        editor:SetScript("OnTextChanged", function(self)
            local lines = 0
            for line in (self:GetText() .. "\n"):gmatch("([^\n]*)\n") do
                lines = lines + math.max(1, math.ceil(#line / 50))
            end
            self:SetHeight(math.max(230, lines * 14 + 16))
        end)
        scroll:SetScrollChild(editor)
        local status = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("BOTTOMLEFT", 20, 52)
        status:SetWidth(550)
        status:SetJustifyH("LEFT")
        status:SetTextColor(1, 0.7, 0.3, 1)
        local accept = Widgets.CreateButton(dialog, "Import theme", function()
            local data = dialog.data
            if not data or not data.importing or not Widgets.IsEditingAllowed() then return end
            if addon.GetActiveProfileName() ~= data.target.name or addon.GetProfile(data.target.name) ~= data.target.object then
                status:SetText("Selected profile changed. Close and reopen this dialog.")
                return
            end
            local theme, message = addon.DecodeTheme(editor:GetText())
            if not theme then status:SetText(message); return end
            addon.ApplyThemeData(theme)
            dialog:Hide()
            data.changed()
        end, 150)
        accept:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 20, 18)
        local close = Widgets.CreateButton(dialog, "Close", function() dialog:Hide() end, 100)
        close:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -20, 18)
        editor:SetScript("OnEscapePressed", function() dialog:Hide() end)
        dialog:SetScript("OnHide", function() editor:ClearFocus(); dialog.data = nil end)
        dialog.title, dialog.instructions, dialog.editor = title, instructions, editor
        dialog.status, dialog.accept = status, accept
    end
    dialog.data = {target=target, importing=importing, changed=changed}
    dialog.title:SetText((importing and "Import theme into: " or "Export theme from: ") .. target.name)
    dialog.instructions:SetText(importing
        and "Paste theme text below. Import replaces this profile's colors, text and cast highlights. Other characters using this profile will see the changes."
        or "Press Ctrl+A, then Ctrl+C to copy. Includes colors, text and cast highlights only.")
    dialog.status:SetText("")
    dialog.accept:GetFrame():SetShown(importing)
    dialog.accept:SetEnabled(importing)
    dialog.editor:SetText(importing and "" or addon.ExportTheme())
    dialog:Show()
    dialog.editor:SetFocus()
    if not importing then dialog.editor:HighlightText() end
end
function addon.AddThemeActions(content, layout, changed)
    UI.AddSection(content, layout, "Themes")
    UI.AddDescription(content, layout,
        "A theme contains colors, text and cast highlights. Import applies it to the selected profile; character activation, global visibility and TRP3 are unchanged.")
    UI.AddPageAction(content, layout, "Import theme", function() OpenThemeDialog(true, changed) end)
    UI.AddPageAction(content, layout, "Export theme", function() OpenThemeDialog(false, changed) end)
end
