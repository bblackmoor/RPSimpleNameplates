local _, addon = ...
local UI = addon.SettingsUI
local activeEdit
local pickerHooked = false

local function OwnsPicker(edit)
    return edit and ColorPickerFrame:GetExtraInfo() == edit
end

local function IsCurrentTarget(edit)
    return addon.GetActiveProfileName() == edit.target.name
        and addon.GetProfile(edit.target.name) == edit.target.object
end

local function FinishEdit(edit, cancel)
    if not edit or activeEdit ~= edit then return false end
    activeEdit = nil -- Retire before rollback or native OnHide can reenter.
    if not OwnsPicker(edit) then return false end
    if cancel and IsCurrentTarget(edit) then
        edit.apply({r = edit.original.r, g = edit.original.g, b = edit.original.b})
    end
    return true
end

function UI.CancelColorEdit(owner)
    if owner and (not activeEdit or activeEdit.owner ~= owner) then return end
    if FinishEdit(activeEdit, true) then ColorPickerFrame:Hide() end
end

-- Profile swatches use the native RGB picker.
-- The session captures its Profile and settings identity, never a later selection.
function UI.OpenColorEditor(owner, getColor, applyColor)
    if UI.IsSettingsEditable and not UI.IsSettingsEditable() then return end
    UI.CancelColorEdit()
    local color = getColor()
    local edit = {
        owner = owner, target = {name = addon.GetActiveProfileName(),
            object = addon.GetProfile(addon.GetActiveProfileName())}, apply = applyColor,
        original = {r = color.r, g = color.g, b = color.b}, opening = true
    }
    activeEdit = edit
    if not pickerHooked then
        pickerHooked = true
        -- Okay/hide commits the preview and makes retained callbacks inert.
        ColorPickerFrame:HookScript("OnHide", function()
            -- Setup may hide the previous picker before assigning our extraInfo.
            -- That hide belongs to the outgoing session, not this opening edit.
            if activeEdit and not activeEdit.opening then FinishEdit(activeEdit, false) end
        end)
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        r = color.r, g = color.g, b = color.b,
        hasOpacity = false, extraInfo = edit,
        swatchFunc = function()
            if activeEdit == edit and OwnsPicker(edit)
                and IsCurrentTarget(edit) and not edit.opening
                and (not UI.IsSettingsEditable or UI.IsSettingsEditable()) then
                local r, g, b = ColorPickerFrame:GetColorRGB()
                edit.apply({r = r, g = g, b = b})
            end
        end,
        cancelFunc = function() FinishEdit(edit, true) end
    })
    edit.opening = false -- Setup can synchronously emit a color-selection event.
end

function UI.InstallColorEditorOwner(owner)
    owner:HookScript("OnHide", function() UI.CancelColorEdit(owner) end)
end


