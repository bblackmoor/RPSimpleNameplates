-- Fixed-position health tint, clipped by native fill geometry; no health arithmetic.
local _, ns = ...
local SHADE_LEFT_MAX = 0.8
local SHADE_KNEE = 0.95
local SHADE_AT_KNEE = 0

local function Opacity()
    return ns.GetGradientOpacity and ns.GetGradientOpacity() / 100 or 0
end

local function Enabled()
    return Opacity() > 0
end

local function Hide(bar)
    if bar and bar.RPSNHealthGradient then
        bar.RPSNHealthGradient:Hide()
        bar.RPSNHealthGradientTail:Hide()
    end
end

local function Apply(bar, fill, context)
    if not bar then return end
    local cap = ns.PresentationCapabilities
    if cap.ObjectStatus(bar, context) ~= "accessible" then return end
    local opacity = Opacity()
    if opacity == 0 then Hide(bar); return end
    if cap.ObjectStatus(fill, context) ~= "accessible" then Hide(bar); return end
    local width = ns.AccessibleNumber(cap.ReadRegion(bar, "GetWidth", context))
    if not width or width <= 0 then Hide(bar); return end
    if not bar.RPSNHealthGradient then
        -- Native fill anchors resolve in the renderer even with secret health.
        -- Fade to clear at 95% width; the final 5% stays clear. Only the mask shrinks.
        local mask = bar:CreateMaskTexture(nil, "ARTWORK")
        -- Linear sampling blends the white mask with transparent outside pixels,
        -- exposing a bright rim (especially wide when an 8px mask is stretched).
        -- Nearest sampling keeps the clip opaque inside and clear outside.
        mask:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "NEAREST")
        local tint = bar:CreateTexture(nil, "ARTWORK", nil, 3)
        tint:SetColorTexture(1, 1, 1, 1)
        tint:AddMaskTexture(mask)
        tint:SetPoint("TOPLEFT", bar, "TOPLEFT")
        tint:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
        local tail = bar:CreateTexture(nil, "ARTWORK", nil, 3)
        tail:SetColorTexture(1, 1, 1, 1)
        tail:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, SHADE_AT_KNEE), CreateColor(0, 0, 0, 0))
        tail:AddMaskTexture(mask)
        tail:SetPoint("TOPLEFT", tint, "TOPRIGHT")
        tail:SetPoint("BOTTOMLEFT", tint, "BOTTOMRIGHT")
        bar.RPSNHealthGradient, bar.RPSNHealthGradientMask = tint, mask
        bar.RPSNHealthGradientTail = tail
    end
    bar.RPSNHealthGradientMask:ClearAllPoints()
    bar.RPSNHealthGradientMask:SetAllPoints(fill)
    bar.RPSNHealthGradient:SetWidth(width * SHADE_KNEE)
    bar.RPSNHealthGradientTail:SetWidth(width * (1 - SHADE_KNEE))
    -- Scale the left endpoint directly; the clear endpoint and fade position
    -- stay fixed. Keep texture opacity full so the slider owns darkness only.
    if bar.RPSNHealthGradientOpacity ~= opacity then
        bar.RPSNHealthGradient:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, SHADE_LEFT_MAX * opacity),
            CreateColor(0, 0, 0, SHADE_AT_KNEE))
        bar.RPSNHealthGradientOpacity = opacity
    end
    bar.RPSNHealthGradient:SetAlpha(1)
    bar.RPSNHealthGradientTail:SetAlpha(1)
    bar.RPSNHealthGradient:Show()
    bar.RPSNHealthGradientTail:Show()
end

ns.HealthGradient = {Enabled = Enabled, Apply = Apply, Hide = Hide}
