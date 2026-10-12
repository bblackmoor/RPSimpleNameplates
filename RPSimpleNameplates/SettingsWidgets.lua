-- Details Framework boundary for converted settings pages.
-- No saved settings, page registration, or plate work here.
local _, addon = ...
local Widgets = {}
addon.SettingsWidgets = Widgets
local handles, combatLocked, cancellationDepth = {}, false, 0

function Widgets.IsEditingAllowed()
    return not combatLocked and not (InCombatLockdown and InCombatLockdown())
        and not (UnitAffectingCombat and UnitAffectingCombat("player"))
end

function Widgets.CancelEdits(callback)
    cancellationDepth = cancellationDepth + 1
    local ok, err = pcall(callback)
    cancellationDepth = cancellationDepth - 1
    if not ok then error(err, 0) end
end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local backdrop = {bgFile = WHITE, edgeFile = WHITE, edgeSize = 1}
local buttonTemplate = {
    backdrop = backdrop, backdropcolor = {0.22, 0.22, 0.23, 1},
    backdropbordercolor = {0.45, 0.45, 0.46, 1},
    onentercolor = {0.32, 0.32, 0.33, 1}, textsize = 12,
}
local swatchTemplate = {
    backdrop = backdrop, backdropcolor = {0.04, 0.04, 0.04, 1},
    backdropbordercolor = {0.45, 0.45, 0.45, 1},
    onentercolor = {0.04, 0.04, 0.04, 1},
    onleavecolor = {0.04, 0.04, 0.04, 1},
    onenterbordercolor = {1, 1, 1, 1},
    onleavebordercolor = {0.45, 0.45, 0.45, 1},
}
local switchTemplate = {
    width = 44, height = 20,
    backdrop = backdrop, is_toggle = true, toggle_knob_padding = 2,
    enabled_backdropcolor = {0.19, 0.42, 0.31, 1},
    disabled_backdropcolor = {0.25, 0.25, 0.26, 1},
    toggle_knob_color_on = {0.72, 0.72, 0.73, 1},
    toggle_knob_color_off = {0.72, 0.72, 0.73, 1},
}
local sliderTemplate = {
    backdrop = backdrop, backdropcolor = {0.25, 0.25, 0.26, 1},
    thumbtexture = WHITE, thumbwidth = 12, thumbheight = 20,
    thumbcolor = {0.72, 0.72, 0.73, 1}, amount_color = {1, 1, 1, 1},
}
local dropdownTemplate = {
    backdrop = backdrop, backdropcolor = {0.22, 0.22, 0.23, 1},
    backdropbordercolor = {0.45, 0.45, 0.46, 1},
    dropicon = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up",
    dropiconsize = {16, 16},
}
local requiredMethods = {"CreateSwitch", "CreateSlider", "CreateDropDown",
    "CreateButton", "CreateColorPickButton"}

-- Resolve at construction time: another embedder can upgrade the same LibStub
-- table after this file loads. Converted pages require a compatible library.
function Widgets.GetFramework()
    local framework = LibStub and LibStub:GetLibrary("DetailsFramework-1.0", true)
    if not framework then return nil, "Details Framework is unavailable" end
    for _, method in ipairs(requiredMethods) do
        if type(framework[method]) ~= "function" then
            return nil, "Details Framework is missing " .. method
        end
    end
    return framework
end

local function Framework()
    local framework, reason = Widgets.GetFramework()
    assert(framework, reason)
    return framework
end

function Widgets.GetFrame(control)
    if not control then return nil end
    if control.frame then return control.frame end
    if control.GetUIObject then return control:GetUIObject() end
    return control.widget or control
end

local Handle = {}
Handle.__index = Handle
function Handle:GetFrame() return self.frame end
function Handle:SetPoint(point, relative, relativePoint, x, y)
    self.frame:SetPoint(point, Widgets.GetFrame(relative), relativePoint, x or 0, y or 0)
end
function Handle:SetEnabled(enabled)
    if enabled ~= true and self.CancelEdit then self:CancelEdit() end
    self.requestedEnabled = enabled == true
    self.enabled = self.requestedEnabled and Widgets.IsEditingAllowed()
    if self.enabled then self.widget:Enable() else self.widget:Disable() end
    -- Some DF Enable/Disable methods only set wrapper lockdown and alpha.
    if self.enabled then self.frame:Enable() else self.frame:Disable() end
    self.frame:SetAlpha(self.enabled and 1 or 0.5)
end

-- Restore the guard even when a widget method fails. Each handle has its own
-- depth so nested refreshes and refreshes of other controls stay independent.
function Handle:Refresh(method, ...)
    self.refreshDepth = self.refreshDepth + 1
    local ok, result = pcall(method, self.widget, ...)
    self.refreshDepth = self.refreshDepth - 1
    if not ok then error(result, 0) end
    return result
end
local function NewHandle(widget, onChanged)
    local handle = setmetatable({widget = widget, frame = Widgets.GetFrame(widget),
        refreshDepth = 0, enabled = true, requestedEnabled = true, onChanged = onChanged}, Handle)
    handles[#handles + 1] = handle
    if not Widgets.IsEditingAllowed() then handle:SetEnabled(true) end
    return handle
end
local function Notify(handle, ...)
    if handle.refreshDepth > 0 then return end
    if cancellationDepth > 0 or (handle.enabled and Widgets.IsEditingAllowed()) then
        if handle.RememberValue then handle:RememberValue(...) end
        if handle.onChanged then handle.onChanged(...) end
        return true
    elseif handle.RestoreValue then
        handle:RestoreValue()
    end
end

function Widgets.CreateSwitch(parent, onChanged)
    local handle
    local widget = Framework():CreateSwitch(Widgets.GetFrame(parent),
        function(_, _, value)
            if handle then Notify(handle, value == true) end
        end,
        false, 44, 20, nil, nil, nil, nil, nil, nil, nil, nil, switchTemplate)
    handle = NewHandle(widget, onChanged)
    function handle:SetChecked(value)
        self.currentValue = value == true
        self:Refresh(self.widget.SetValue, self.currentValue)
    end
    function handle:RememberValue(value) self.currentValue = value end
    function handle:RestoreValue() self:SetChecked(self.currentValue) end
    function handle:GetChecked() return self.widget:GetValue() == true end
    return handle
end

-- Each adapted slider owns its editor. DF's shared editor captures the first
-- slider in its Escape closure; keep our editing lifecycle local to this handle.
local function InstallSliderEditor(handle, normalize)
    local editor, originalValue, editing
    local function ApplyText()
        local value = tonumber(editor:GetText())
        if not value or value ~= value or value == math.huge or value == -math.huge then return false end
        value = normalize(value)
        if value ~= handle:GetValue() then handle.widget:SetValue(value) end
        return true
    end
    local function Finish(cancel)
        if not editing then return end
        if not cancel and not ApplyText() then cancel = true end
        editing = false
        if cancel and handle:GetValue() ~= originalValue then
            -- Preview changes already notified the page; cancellation must also
            -- restore its saved value, not just the native slider position.
            handle.widget:SetValue(originalValue)
        end
        editor:ClearFocus()
        editor:Hide()
    end
    handle.CancelEdit = function() Finish(true) end
    handle.widget.TypeValue = function()
        if not handle.enabled or not Widgets.IsEditingAllowed() or editing then return end
        if not editor then
            editor = CreateFrame("EditBox", nil, handle.frame, "BackdropTemplate")
            editor:SetSize(60, 20)
            editor:SetPoint("CENTER", handle.frame, "CENTER")
            editor:SetBackdrop(backdrop)
            editor:SetBackdropColor(0.04, 0.04, 0.04, 1)
            editor:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
            editor:SetFontObject("GameFontHighlightSmall")
            editor:SetJustifyH("CENTER")
            editor:SetAutoFocus(false)
            editor:SetScript("OnTextChanged", function() if editing then ApplyText() end end)
            editor:SetScript("OnEscapePressed", function() Finish(true) end)
            editor:SetScript("OnEnterPressed", function() Finish(false) end)
            editor:SetScript("OnHide", function() Finish(true) end)
            editor:SetScript("OnEditFocusLost", function() Finish(true) end)
            handle.frame:HookScript("OnHide", function() Finish(true) end)
            handle.frame:HookScript("OnDisable", function() Finish(true) end)
        end
        originalValue = handle:GetValue()
        editor:SetText(tostring(originalValue))
        editing = true
        editor:Show()
        editor:SetFocus()
        editor:HighlightText()
    end
end

function Widgets.CreateSlider(parent, minimum, maximum, step, onChanged)
    assert(minimum < maximum and step > 0, "Invalid slider range")
    local widget = Framework():CreateSlider(Widgets.GetFrame(parent), 180, 20,
        minimum, maximum, step, minimum, false, nil, nil, nil, sliderTemplate)
    local handle = NewHandle(widget, onChanged)
    local function Normalize(value)
        return math.max(minimum, math.min(maximum,
            minimum + math.floor((value - minimum) / step + 0.5) * step))
    end
    widget:SetValueChangedFunction(function(_, _, value)
        value = Normalize(value)
        -- Typed input may bypass native drag stepping.
        if widget:GetValue() ~= value then handle:SetValue(value) end
        Notify(handle, value)
    end)
    function handle:SetValue(value)
        -- Do not use DF's SetValueNoCallback: an unchanged value may leave its
        -- one-shot flag set and swallow the next user change.
        self.currentValue = Normalize(value)
        self:Refresh(self.widget.SetValue, self.currentValue)
    end
    function handle:GetValue() return Normalize(self.widget:GetValue()) end
    function handle:RememberValue(value) self.currentValue = value end
    function handle:RestoreValue() self:SetValue(self.currentValue or minimum) end
    InstallSliderEditor(handle, Normalize)
    -- Native dragging previews continuously; only an unfinished drag rolls back.
    local dragValue
    local onDown, onUp = handle.frame:GetScript("OnMouseDown"), handle.frame:GetScript("OnMouseUp")
    handle.frame:SetScript("OnMouseDown", function(frame, button, ...)
        if not handle.enabled or not Widgets.IsEditingAllowed() then return end
        if button == "LeftButton" then dragValue = handle:GetValue() end
        if onDown then onDown(frame, button, ...) end
    end)
    handle.frame:SetScript("OnMouseUp", function(frame, button, ...)
        if button == "LeftButton" then dragValue = nil end
        if onUp then onUp(frame, button, ...) end
    end)
    function handle:CancelCombatEdit()
        self:CancelEdit()
        self.widget.IsValueChanging = nil
        if dragValue ~= nil then
            local value = dragValue
            dragValue = nil
            self.widget:SetValue(value)
        end
    end
    return handle
end

-- optionsFunction returns {label, value, font?} entries. It is evaluated once
-- per explicit invalidation, never on a simple selected-label refresh.
function Widgets.CreateDropdown(parent, optionsFunction, onChanged)
    local handle, cached
    local function Options()
        if not cached then
            cached = {}
            for _, option in ipairs(optionsFunction()) do
                local entry = {label = option.label, value = option.value, font = option.font}
                entry.onclick = function(_, _, value) Notify(handle, value) end
                cached[#cached + 1] = entry
            end
        end
        return cached
    end
    local widget = Framework():CreateDropDown(Widgets.GetFrame(parent), Options,
        false, 190, 20, nil, nil, dropdownTemplate)
    -- DF reskins this nested scroll thumb with Details' icons2 texture.
    local thumb = widget.scroll.thumb
    thumb:SetTexture(WHITE)
    thumb:SetTexCoord(0, 1, 0, 1)
    handle = NewHandle(widget, onChanged)
    function handle:InvalidateOptions() cached = nil end
    function handle:SetValue(value, label)
        self.value, self.currentLabel = value, label
        if label then
            -- Font labels can refresh while choices are dirty. Selected updates
            -- the DF selection/label directly, without evaluating the provider.
            self:Refresh(self.widget.Selected, {value = value, label = label})
        else
            self:Refresh(self.widget.Select, value, false, false, false)
        end
    end
    function handle:RestoreValue() self:SetValue(self.value, self.currentLabel) end
    function handle:CancelEdit() self.widget:Close() end
    function handle:GetValue() return self.value end
    function handle:SetLabel(text) self.widget.label:SetText(text) end
    local notify = onChanged
    handle.onChanged = function(value)
        handle.value = value
        if notify then notify(value) end
    end
    return handle
end

function Widgets.CreateButton(parent, text, onClick, width, height)
    local handle
    local widget = Framework():CreateButton(Widgets.GetFrame(parent),
        function() Notify(handle) end, width or 190, height or 24, text,
        nil, nil, nil, nil, nil, nil, buttonTemplate)
    handle = NewHandle(widget, onClick)
    return handle
end

-- About's informational widgets deliberately have no editable picker path.
function Widgets.CreateColorDisplay(parent, r, g, b)
    local widget = Framework():CreateButton(Widgets.GetFrame(parent),
        function() end, 26, 26, "",
        nil, nil, nil, nil, nil, nil, swatchTemplate)
    local frame = Widgets.GetFrame(widget)
    frame:EnableMouse(false) -- The containing row owns explanatory hover behavior.
    local fill = frame:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    fill:SetColorTexture(r, g, b, 1)
    return NewHandle(widget)
end

function Widgets.CreateLink(parent, text, onClick)
    local handle
    local transparent = {0, 0, 0, 0}
    local template = {backdrop = backdrop, backdropcolor = transparent,
        backdropbordercolor = transparent, onentercolor = transparent,
        onleavecolor = transparent, onenterbordercolor = transparent,
        onleavebordercolor = transparent, textsize = 11, textcolor = {0.35, 0.7, 1, 1}}
    local widget = Framework():CreateButton(Widgets.GetFrame(parent),
        function() Notify(handle) end, 190, 16, text,
        nil, nil, nil, nil, nil, nil, template)
    handle = NewHandle(widget, onClick)
    widget.widget.text:SetFontObject("GameFontHighlightSmall")
    widget.widget.text:SetTextColor(0.35, 0.7, 1, 1)
    widget.widget:SetWidth(widget.widget.text:GetStringWidth())
    widget.widget:HookScript("OnEnter", function() widget.widget.text:SetTextColor(0.65, 0.85, 1, 1) end)
    widget.widget:HookScript("OnLeave", function() widget.widget.text:SetTextColor(0.35, 0.7, 1, 1) end)
    return handle
end

function Widgets.CreateColorPicker(parent, onChanged, getColor)
    local widget = Framework():CreateColorPickButton(Widgets.GetFrame(parent),
        nil, nil, function() end, nil, swatchTemplate)
    widget.widget:SetSize(26, 26)
    widget.background_texture:Hide() -- RGB only; no transparency grid.
    widget.color_texture:ClearAllPoints()
    widget.color_texture:SetPoint("TOPLEFT", widget.widget, "TOPLEFT", 3, -3)
    widget.color_texture:SetPoint("BOTTOMRIGHT", widget.widget, "BOTTOMRIGHT", -3, 3)
    local handle = NewHandle(widget, onChanged)
    function handle:SetColor(r, g, b) self:Refresh(self.widget.SetColor, r, g, b, 1) end
    function handle:GetColor()
        local r, g, b = self.widget:GetColor()
        return r, g, b
    end
    function handle:CancelEdit()
        addon.SettingsUI.CancelColorEdit(self)
    end
    widget.widget:HookScript("OnHide", function() handle:CancelEdit() end)
    -- Keep the DF swatch with Blizzard's RGB-only contract and scoped rollback.
    widget:SetClickFunction(function()
        if not handle.enabled or not Widgets.IsEditingAllowed() then return end
        addon.SettingsUI.OpenColorEditor(handle, function()
            local r, g, b
            if getColor then r, g, b = getColor()
            else r, g, b = handle:GetColor() end
            handle:SetColor(r, g, b) -- Refresh stale display RGB without notifying setters.
            return {r = r, g = g, b = b}
        end, function(color)
            handle:SetColor(color.r, color.g, color.b)
            Notify(handle, color.r, color.g, color.b)
        end)
    end)
    return handle
end



-- Preserve page-specific availability (protected profiles and TRP3 dependents).
function Widgets.SetCombatLocked(locked)
    combatLocked = locked == true
    if combatLocked then
        Widgets.CancelEdits(function()
            if addon.SettingsUI.CancelColorEdit then addon.SettingsUI.CancelColorEdit() end
            if addon.CancelAppearanceEdits then addon.CancelAppearanceEdits() end
            if addon.CancelHighlightEdits then addon.CancelHighlightEdits() end
            for _, handle in ipairs(handles) do
                if handle.CancelCombatEdit then handle:CancelCombatEdit()
                elseif handle.CancelEdit then handle:CancelEdit() end
            end
        end)
    end
    for _, handle in ipairs(handles) do handle:SetEnabled(handle.requestedEnabled) end
end
