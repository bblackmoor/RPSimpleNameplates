local _, addon = ...
local UI = addon.SettingsUI
local activeDialogs = {}
local function TrackDialog(key, data)
    activeDialogs[key] = data
end
local function CanAccept(data)
    return data and not data.cancelled and (not UI.IsSettingsEditable or UI.IsSettingsEditable())
end
function UI.CancelProfileDialogs()
    for key, data in pairs(activeDialogs) do
        data.cancelled = true
        if StaticPopup_Hide then StaticPopup_Hide(key) end
    end
    activeDialogs = {}
end

function UI.CaptureProfileDialogTarget(name)
    return {name = name, object = addon.GetProfile(name)}
end

function UI.CaptureBundledProfileDialogTargets()
    return {UI.CaptureProfileDialogTarget(addon.DEFAULT_PROFILE_NAME),
        UI.CaptureProfileDialogTarget(addon.HIGH_CONTRAST_PROFILE_NAME)}
end

local function CheckTarget(target, allowMissing)
    if target and (target.object or allowMissing)
        and addon.GetProfile(target.name) == target.object then return true end
    print("|cff0cd29fSimple Nameplates:|r The profile changed. Reopen the profile dialog to continue.")
    return false
end

local function CheckDialogTarget(target)
    if not target then return true end -- Creating a new profile has no source target.
    if target.name ~= addon.GetActiveProfileName() then
        print("|cff0cd29fSimple Nameplates:|r Selected profile changed. Reopen the profile dialog to continue.")
        return false
    end
    return CheckTarget(target)
end

function UI.RegisterProfileDialogs()
    local function GetEditBox(popup)
        return popup.GetEditBox and popup:GetEditBox() or popup.editBox
    end
    local function GetAcceptButton(popup)
        return popup.GetButton1 and popup:GetButton1() or popup.button1
    end
    StaticPopupDialogs["SNP_PROFILE_NAME"] = {
        text = "Enter a profile name.", button1 = ACCEPT or "Accept",
        button2 = CANCEL or "Cancel", hasEditBox = true, maxLetters = 64,
        editBoxWidth = 260,
        OnShow = function(self, data)
            TrackDialog("SNP_PROFILE_NAME", data)
            local editBox = GetEditBox(self)
            editBox:SetText(data and data.initial or "")
            editBox:SetFocus()
            editBox:HighlightText()
        end,
        OnAccept = function(self, data)
            if not CanAccept(data) or not CheckDialogTarget(data.target) then return end
            local editBox = GetEditBox(self)
            local ok, message = data.action(editBox:GetText())
            if not ok and message then print("|cff0cd29fSimple Nameplates:|r " .. message) end
            if ok then data.onChanged() end
        end,
        EditBoxOnEnterPressed = function(self)
            local dialog = self:GetParent()
            local button = GetAcceptButton(dialog)
            if button and button:IsEnabled() then button:Click() end
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["SNP_DELETE_PROFILE"] = {
        text = "Delete the profile |cffffffff%s|r? Characters using it will switch to Default.",
        button1 = DELETE or "Delete", button2 = CANCEL or "Cancel",
        OnShow = function(_, data) TrackDialog("SNP_DELETE_PROFILE", data) end,
        OnAccept = function(_, data)
            if not CanAccept(data) or not CheckDialogTarget(data.target) then return end
            local ok, message = addon.DeleteActiveProfile()
            if not ok and message then print("|cff0cd29fSimple Nameplates:|r " .. message) end
            if ok then data.onChanged() end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["SNP_RESTORE_BUNDLED_PROFILES"] = {
        text = "Restore factory settings for Default and High Contrast? Their changes will be lost; missing bundled profiles will be recreated.",
        button1 = "Restore", button2 = CANCEL or "Cancel",
        OnShow = function(_, data) TrackDialog("SNP_RESTORE_BUNDLED_PROFILES", data) end,
        OnAccept = function(_, data)
            if not CanAccept(data) then return end
            for _, target in ipairs(data.targets or {}) do
                if not CheckTarget(target, true) then return end
            end
            if not data.targets then return end
            addon.RestoreBundledProfiles()
            data.onChanged()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end


