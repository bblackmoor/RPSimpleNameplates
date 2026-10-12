-- Simple Nameplates: Blizzard-driven interruptible cast effects.
local _, ns = ...
local Capabilities = ns.PresentationCapabilities
local CanAccessFrame = Capabilities.CanAccessFrame
local GetContext = ns.WorldContext.Get
local GetStylingEnabled = ns.GetStylingEnabled
local GetInterruptibleHighlightEnabled = ns.GetInterruptibleHighlightEnabled
local EffectColor = ns.EffectColor
local GetHealthBar, GetCastBar = ns.NameplateFrames.GetHealthBar, ns.NameplateFrames.GetCastBar

local pendingFrames = setmetatable({}, {__mode = "k"})
local eventStateByUnit = {}
local UpdateInterruptibleHighlight
local function RetryFrame(frame)
    if not pendingFrames[frame] then return end
    local context = GetContext()
    if CanAccessFrame(frame, context) then
        UpdateInterruptibleHighlight(frame, context, frame.SNPPresentation)
        return
    end
    return 0.25
end
local function DeferFrame(frame)
    pendingFrames[frame] = true
    ns.PeriodicWork.Schedule("cast retry", frame, RetryFrame, 0.25)
end

local START_EVENTS = {
    UNIT_SPELLCAST_START = true,
    UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_EMPOWER_START = true,
}
local STOP_EVENTS = {
    UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_EMPOWER_STOP = true,
    UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true,
}

local function CreateBorder(parent, inset, thickness)
    local top = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    top:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
    top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset)
    top:SetHeight(thickness)

    local bottom = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset, inset)
    bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
    bottom:SetHeight(thickness)

    local left = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
    left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset, inset)
    left:SetWidth(thickness)

    local right = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
    right:SetWidth(thickness)

    return {top, bottom, left, right}
end


-- Each centered edge has two half textures so the gradient stays symmetric.
-- Native scale animations pin each half at the shared midpoint and change only
-- its long axis; no cast dimensions are read.
local function CreateAlertBorder(parent, thickness)
    local edges = {}
    for index, points in ipairs({
        {"TOPLEFT", "TOPRIGHT"}, {"BOTTOMLEFT", "BOTTOMRIGHT"},
        {"TOPLEFT", "BOTTOMLEFT"}, {"TOPRIGHT", "BOTTOMRIGHT"},
    }) do
        local edge = CreateFrame("Frame", nil, parent)
        edge:SetPoint(points[1], parent, points[1], 0, 0)
        edge:SetPoint(points[2], parent, points[2], 0, 0)
        edge.horizontal = index <= 2
        if edge.horizontal then edge:SetHeight(thickness) else edge:SetWidth(thickness) end
        local first = edge:CreateTexture(nil, "OVERLAY", nil, 7)
        local second = edge:CreateTexture(nil, "OVERLAY", nil, 7)
        if edge.horizontal then
            first:SetPoint("TOPLEFT", edge, "TOPLEFT", 0, 0)
            first:SetPoint("BOTTOMRIGHT", edge, "BOTTOM", 0, 0)
            second:SetPoint("TOPLEFT", edge, "TOP", 0, 0)
            second:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", 0, 0)
        else
            first:SetPoint("BOTTOMLEFT", edge, "BOTTOMLEFT", 0, 0)
            first:SetPoint("TOPRIGHT", edge, "RIGHT", 0, 0)
            second:SetPoint("BOTTOMLEFT", edge, "LEFT", 0, 0)
            second:SetPoint("TOPRIGHT", edge, "TOPRIGHT", 0, 0)
        end
        edge.halves = {first, second}
        edge:Hide()
        edges[index] = edge
    end
    return edges
end

local function Parameter(effect, key, fallback)
    local getter = ns.GetCastBorderSetting
    local value = getter and getter(effect, key)
    if value ~= nil then return value end
    return fallback
end

local function ConfigureOffset(h)
    local offset = Parameter("PULSE", "offset", 3)
    if h.borderOffset == offset then return end
    h.borderOffset = offset
    local corners = {
        {{"TOPLEFT", -offset, offset}, {"TOPRIGHT", offset, offset}},
        {{"BOTTOMLEFT", -offset, -offset}, {"BOTTOMRIGHT", offset, -offset}},
        {{"TOPLEFT", -offset, offset}, {"BOTTOMLEFT", -offset, -offset}},
        {{"TOPRIGHT", offset, offset}, {"BOTTOMRIGHT", offset, -offset}},
    }
    for _, edges in ipairs({h.border, h.alertBorder}) do
        for index, edge in ipairs(edges) do
            edge:ClearAllPoints()
            for _, corner in ipairs(corners[index]) do
                edge:SetPoint(corner[1], h.frame, corner[1], corner[2], corner[3])
            end
        end
    end
end

local function ConfigureBorder(h, effect)
    ConfigureOffset(h)
    local thickness = Parameter("PULSE", "thickness", 4)
    for index, edge in ipairs(h.border) do
        if index <= 2 then edge:SetHeight(thickness) else edge:SetWidth(thickness) end
    end
    for _, edge in ipairs(h.alertBorder) do
        if edge.horizontal then edge:SetHeight(thickness) else edge:SetWidth(thickness) end
    end
    if effect == "PULSE" then
        local fadeOut = Parameter("PULSE", "fadeOut", 0.1)
        local fadeIn = Parameter("PULSE", "fadeIn", 0.1)
        local signature = table.concat({fadeOut, fadeIn}, ":")
        if h.pulseConfig ~= signature then
            h.pulseConfig = signature
            h.pulse:Stop()
            h.fadeOut:SetDuration(fadeOut)
            h.fadeIn:SetDuration(fadeIn)
        end
        return
    end
    if effect ~= "ALERT" then return end
    local minimum = Parameter("ALERT", "minLength", 20) / 100
    local maximum = Parameter("ALERT", "maxLength", 100) / 100
    minimum = math.min(minimum, maximum)
    local shrinkTime = Parameter("ALERT", "shrinkTime", 0.2)
    local growTime = Parameter("ALERT", "growTime", 0.2)
    local signature = table.concat({minimum, maximum, shrinkTime, growTime}, ":")
    if h.alertConfig == signature then return end
    h.alertConfig = signature
    h.alert:Stop()
    for index, edge in ipairs(h.alertBorder) do
        local maxX, maxY = edge.horizontal and maximum or 1, edge.horizontal and 1 or maximum
        local minX, minY = edge.horizontal and minimum or 1, edge.horizontal and 1 or minimum
        for half = 1, 2 do
            local animationIndex = (index - 1) * 2 + half
            local shrink, grow = h.shrink[animationIndex], h.grow[animationIndex]
            shrink:SetScaleFrom(maxX, maxY)
            shrink:SetScaleTo(minX, minY)
            -- Scale animations of later orders compound with the completed
            -- shrink. Start at identity and undo that transform to reach max.
            local expansion = maximum / minimum
            grow:SetScaleFrom(1, 1)
            grow:SetScaleTo(edge.horizontal and expansion or 1, edge.horizontal and 1 or expansion)
            shrink:SetDuration(shrinkTime)
            grow:SetDuration(growTime)
        end
    end
end

local function StopRenderer(highlight)
    highlight.pulse:Stop()
    highlight.alert:Stop()
    highlight.frame:SetAlpha(1)
    for _, edge in ipairs(highlight.border) do edge:Hide() end
    for _, edge in ipairs(highlight.alertBorder) do edge:Hide() end
end

local function ApplyRenderer(highlight)
    local effect = highlight.previewEffect or (ns.GetInterruptibleEffect and ns.GetInterruptibleEffect()) or "PULSE"
    if effect ~= "SOLID" and effect ~= "ALERT" then effect = "PULSE" end
    if highlight.activeEffect ~= effect then StopRenderer(highlight) end
    highlight.activeEffect = effect
    ConfigureBorder(highlight, effect)
    if highlight.previewDisabled then
        highlight.pulse:Stop()
        highlight.alert:Stop()
        highlight.frame:SetAlpha(1)
    end
    local r, g, b = EffectColor("interruptible")
    if highlight.previewDisabled then r, g, b = 0.5, 0.5, 0.5 end
    for _, edge in ipairs(highlight.border) do
        edge:SetColorTexture(r, g, b, 1)
        edge:SetShown(effect ~= "ALERT")
    end
    local endAlpha = Parameter("ALERT", "endOpacity", 0) / 100
    local centerAlpha = Parameter("ALERT", "centerOpacity", 100) / 100
    for _, edge in ipairs(highlight.alertBorder) do
        local direction = edge.horizontal and "HORIZONTAL" or "VERTICAL"
        local first, second = unpack(edge.halves)
        first:SetColorTexture(1, 1, 1, 1)
        second:SetColorTexture(1, 1, 1, 1)
        first:SetGradient(direction, CreateColor(r, g, b, endAlpha), CreateColor(r, g, b, centerAlpha))
        second:SetGradient(direction, CreateColor(r, g, b, centerAlpha), CreateColor(r, g, b, endAlpha))
        edge:SetShown(effect == "ALERT" and edge.horizontal)
    end
    if not highlight.previewDisabled then
        if effect == "PULSE" and not highlight.pulse:IsPlaying() then highlight.pulse:Play() end
        if effect == "ALERT" and not highlight.alert:IsPlaying() then highlight.alert:Play() end
    end
end

-- Midnight can make IsInterruptable() secret. Blizzard has already consumed that
-- value to render the native icon/shield, so inspect those ordinary visual states
-- instead. Modern nameplates hide the spell icon for uninterruptible casts;
-- Classic-style nameplates keep the icon and show BorderShield instead.
local function NativeInterruptibleState(highlight, context)
    local bar = highlight and highlight.castBar
    if not bar then return nil end
    local barShown = ns.AccessibleBoolean(Capabilities.ReadRegion(bar, "IsShown", context))
    if barShown ~= true then return false end

    local icon = Capabilities.SafeField(bar, "Icon", context)
    local shield = Capabilities.SafeField(bar, "BorderShield", context)
    local iconShown = ns.AccessibleBoolean(Capabilities.ReadRegion(icon, "IsShown", context))
    local shieldShown = ns.AccessibleBoolean(Capabilities.ReadRegion(shield, "IsShown", context))
    local hideIcon = Capabilities.SafeField(bar, "HideIconWhenNotInterruptible", context)

    if hideIcon == true and iconShown ~= nil then return iconShown end
    if shieldShown == true then return false end
    if iconShown == true then return true end
    return nil
end

local function ResolvedInterruptibleState(highlight, context)
    local shown = ns.AccessibleBoolean(Capabilities.ReadRegion(highlight and highlight.castBar, "IsShown", context))
    if shown == false then return false, "cast bar hidden" end
    if shown == nil then return nil, "cast visibility unavailable" end
    local unit = ns.AccessibleValue(highlight and highlight.owner and highlight.owner.unit)
    if type(unit) == "string" and eventStateByUnit[unit] ~= nil then
        return eventStateByUnit[unit], "spellcast event"
    end
    local native = NativeInterruptibleState(highlight, context)
    if native ~= nil then return native, "native visual" end
    return nil, "unavailable"
end

local function RefreshHighlight(highlight, context, decision)
    if not highlight then return end
    if not GetStylingEnabled() or not GetInterruptibleHighlightEnabled()
        or not decision or not decision.showCastBar then
        highlight.interruptibleState, highlight.interruptibleSource = false, "disabled"
        highlight.frame:Hide()
        return
    end

    local state, source = ResolvedInterruptibleState(highlight, context)
    highlight.interruptibleState, highlight.interruptibleSource = state, source
    if state == true then
        highlight.frame:Show()
        ApplyRenderer(highlight)
    else
        highlight.frame:Hide()
        if state == nil and highlight.owner then DeferFrame(highlight.owner) end
    end
end

local function InstallRegionHook(highlight, region, registry)
    if not region then return false end
    highlight[registry] = highlight[registry] or setmetatable({}, {__mode = "k"})
    if highlight[registry][region] then return true end

    local overlay = highlight.frame
    local function Changed()
        local context = GetContext()
        if not CanAccessFrame(highlight.owner, context) then
            DeferFrame(highlight.owner)
            return
        end
        if highlight.owner.SNPInterruptibleHighlight ~= highlight then overlay:Hide(); return end
        local bar = highlight.castBar
        local icon = Capabilities.SafeField(bar, "Icon", context)
        local shield = Capabilities.SafeField(bar, "BorderShield", context)
        if region ~= bar and region ~= icon and region ~= shield then return end
        RefreshHighlight(highlight, context, highlight.owner.SNPPresentation)
    end
    local ok = true
    for _, method in ipairs({"SetShown", "Show", "Hide"}) do
        if type(Capabilities.SafeField(region, method, GetContext())) == "function" then
            local installed = pcall(hooksecurefunc, region, method, Changed)
            ok = ok and installed
        end
    end
    if ok then highlight[registry][region] = true end
    return ok
end

local function InstallInterruptibleHighlightHooks(highlight)
    local bar = highlight and highlight.castBar
    if not bar then return end
    local context = GetContext()
    InstallRegionHook(highlight, Capabilities.SafeField(bar, "Icon", context), "hookedIcons")
    InstallRegionHook(highlight, Capabilities.SafeField(bar, "BorderShield", context), "hookedShields")
    InstallRegionHook(highlight, bar, "hookedBars")
    if not highlight.barVisibilityHooked then
        local function Changed()
            local context = GetContext()
            if highlight.owner.SNPInterruptibleHighlight ~= highlight then highlight.frame:Hide(); return end
            if not CanAccessFrame(highlight.owner, context) then DeferFrame(highlight.owner); return end
            RefreshHighlight(highlight, context, highlight.owner.SNPPresentation)
        end
        local ok = pcall(function()
            bar:HookScript("OnShow", Changed)
            bar:HookScript("OnHide", Changed)
        end)
        highlight.barVisibilityHooked = ok
    end
end

local function CreateHighlight(castBar, owner, healthBar)
    local overlay = CreateFrame("Frame", nil, castBar)
    overlay:SetPoint("TOPLEFT", castBar, "TOPLEFT", 0, 0)
    overlay:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 0, 0)
    local highestFrameLevel = castBar:GetFrameLevel()
    if healthBar then highestFrameLevel = math.max(highestFrameLevel, healthBar:GetFrameLevel()) end
    overlay:SetFrameLevel(highestFrameLevel + 20)
    overlay:Hide()

    local highlight = {
        castBar = castBar,
        owner = owner,
        frame = overlay,
        border = CreateBorder(overlay, 0, 4),
        alertBorder = CreateAlertBorder(overlay, 4),
        shrink = {}, grow = {},
    }
    local pulse = overlay:CreateAnimationGroup()
    local fadeOut = pulse:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0.35)
    fadeOut:SetDuration(0.1)
    fadeOut:SetOrder(1)
    local fadeIn = pulse:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.35)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.1)
    fadeIn:SetOrder(2)
    pulse:SetLooping("REPEAT")
    highlight.pulse, highlight.fadeOut, highlight.fadeIn = pulse, fadeOut, fadeIn
    local alert = overlay:CreateAnimationGroup()
    for index, edge in ipairs(highlight.alertBorder) do
        for half, texture in ipairs(edge.halves) do
            -- Animate textures directly. Scaling the containing frame does not
            -- hold the two gradient halves together at their shared midpoint.
            local origin
            if edge.horizontal then origin = half == 1 and "RIGHT" or "LEFT"
            else origin = half == 1 and "TOP" or "BOTTOM" end
            for order, animations in ipairs({highlight.shrink, highlight.grow}) do
                local scale = alert:CreateAnimation("Scale")
                scale:SetTarget(texture)
                scale:SetOrigin(origin, 0, 0)
                scale:SetOrder(order)
                scale:SetSmoothing("IN_OUT")
                animations[(index - 1) * 2 + half] = scale
            end
        end
    end
    alert:SetLooping("REPEAT")
    highlight.alert = alert

    overlay:SetScript("OnShow", function() ApplyRenderer(highlight) end)
    overlay:SetScript("OnHide", function() StopRenderer(highlight) end)
    return highlight
end

local function EnsureInterruptibleHighlight(frame, context)
    context = context or GetContext()
    if not CanAccessFrame(frame, context) then return end
    local castBar = GetCastBar(frame, context)
    if not castBar then return nil end
    local existing = frame.SNPInterruptibleHighlight
    if existing and existing.castBar == castBar then
        InstallInterruptibleHighlightHooks(existing)
        return existing
    end
    if existing and existing.frame then existing.frame:Hide() end
    local highlight = CreateHighlight(castBar, frame, GetHealthBar(frame, context))
    frame.SNPInterruptibleHighlight = highlight
    InstallInterruptibleHighlightHooks(highlight)
    return highlight
end

UpdateInterruptibleHighlight = function(frame, context, decision)
    context = context or GetContext()
    if not CanAccessFrame(frame, context) then DeferFrame(frame); return end
    pendingFrames[frame] = nil
    ns.PeriodicWork.Cancel("cast retry", frame)
    if not GetStylingEnabled() or not decision or not decision.showCastBar
        or not GetInterruptibleHighlightEnabled() then
        if frame.SNPInterruptibleHighlight then
            frame.SNPInterruptibleHighlight.interruptibleState = false
            frame.SNPInterruptibleHighlight.interruptibleSource = "disabled"
            frame.SNPInterruptibleHighlight.frame:Hide()
        end
        return
    end
    local highlight = EnsureInterruptibleHighlight(frame, context)
    if not highlight then return end
    RefreshHighlight(highlight, context, decision)
end

local function RecordSpellcastEvent(event, unit)
    if type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return false end
    if event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        eventStateByUnit[unit] = true
    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        eventStateByUnit[unit] = false
    elseif START_EVENTS[event] then
        -- Initial state comes from Blizzard's rendered icon/shield after the
        -- cast-start event has finished dispatching.
        eventStateByUnit[unit] = nil
    elseif STOP_EVENTS[event] then
        eventStateByUnit[unit] = false
    else
        return false
    end
    return true
end

local function ClearUnit(unit, frame)
    if type(unit) == "string" then eventStateByUnit[unit] = nil end
    if frame then pendingFrames[frame] = nil; ns.PeriodicWork.Cancel("cast retry", frame) end
end

ns.CastHighlight = {
    EnsureInterruptibleHighlight = EnsureInterruptibleHighlight,
    UpdateInterruptibleHighlight = UpdateInterruptibleHighlight,
    RecordSpellcastEvent = RecordSpellcastEvent,
    ClearUnit = ClearUnit,
    UpdatePreview = function(bar, effect)
        if not bar.SNPCastPreview then bar.SNPCastPreview = CreateHighlight(bar) end
        bar.SNPCastPreview.previewEffect = effect
        bar.SNPCastPreview.previewDisabled = not GetInterruptibleHighlightEnabled()
        bar.SNPCastPreview.frame:Show()
        ApplyRenderer(bar.SNPCastPreview)
    end,
    StopPreview = function(bar)
        if bar and bar.SNPCastPreview then bar.SNPCastPreview.frame:Hide() end
    end,
}

