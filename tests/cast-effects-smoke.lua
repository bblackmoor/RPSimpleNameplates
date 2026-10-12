-- Exercise the actual bundled DF effect constructors with native UI fixtures.
local ui = dofile("tests/details-framework-ui-stubs.lua")
local methods = getmetatable(UIParent).__index
function methods:SetIgnoreParentScale(value) self.ignoreParentScale = value end
function methods:SetTexCoord(...) self.texcoord = {...} end
function methods:IsPlaying() return self.playing == true end
function methods:Play() self.playing = true; self.plays = (self.plays or 0) + 1 end
function methods:Stop() self.playing = false end
function methods:Show()
    if self.shown == true then return end
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    if self.shown == false then return end
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:SetDuration(value) self.duration = value end
function methods:SetAlpha(value) self.alpha = value end
local enabled, effect = true, "PULSE"
local custom = {}
local function Param(name, key) return custom[name] and custom[name][key] end
local ns = {
    WorldContext = {Get = function() return {} end},
    AccessibleBoolean = function(v) if type(v) == "boolean" then return v end end,
    AccessibleValue = function(v) return v end,
    GetStylingEnabled = function() return enabled end,
    GetInterruptibleHighlightEnabled = function() return enabled end,
    GetInterruptibleEffect = function() return effect end,
    GetCastBorderSetting = Param,
    EffectColor = function() return 0.2, 0.8, 1 end,
    PresentationCapabilities = {
        CanAccessFrame = function() return true end,
        SafeField = function(o,k) return o and o[k] end,
        ReadRegion = function(o,k) if o and type(o[k]) == "function" then return o[k](o) end end,
    },
    NameplateFrames = {GetCastBar = function(f) return f.castBar end, GetHealthBar = function() end},
}
assert(loadfile("RPSimpleNameplates/Defaults.lua"))("RPSimpleNameplates", ns)
for _, module in ipairs({"Profiler", "PeriodicWork", "CastHighlight"}) do
    assert(loadfile("RPSimpleNameplates/"..module..".lua"))("RPSimpleNameplates", ns)
end
local owner = {unit = "nameplate1", castBar = CreateFrame("StatusBar"), RPSNPresentation = {showCastBar = true}}
owner.castBar.Icon = CreateFrame("Frame", nil, owner.castBar)
owner.castBar.GetSize = function() error("native cast geometry read") end
local function Update() ns.CastHighlight.UpdateInterruptibleHighlight(owner, {}, owner.RPSNPresentation) end
local h
for _, style in ipairs({"ALERT", "SOLID", "ALERT", "SOLID"}) do
    effect = style; Update()
    h = owner.RPSNInterruptibleHighlight
    assert(h.frame:IsShown() and h.activeEffect == style, style.." renders")
    assert(h.alert:IsPlaying() == (style == "ALERT"), "only pulse animates")
    assert(h.border[1].height == 4 and h.border[2].height == 4)
    assert(h.border[3].width == 4 and h.border[4].width == 4, "side thickness matches")
    for _, point in pairs(h.frame.points) do
        assert(point[2] == owner.castBar and point[4] == 0 and point[5] == 0, "cast bar alignment")
    end
    for _, edge in ipairs(h.border) do
        for _, point in pairs(edge.points) do assert(math.abs(point[4]) == 3 and math.abs(point[5]) == 3, "three-unit outward offset") end
    end
    assert(h.shrink[1].duration == 0.2 and h.grow[1].duration == 0.2)
    for index, edge in ipairs(h.alertBorder) do
        local axis, fixed = edge.horizontal and 1 or 2, edge.horizontal and 2 or 1
        for half, texture in ipairs(edge.halves) do
            local animationIndex = (index - 1) * 2 + half
            local shrink, grow = h.shrink[animationIndex], h.grow[animationIndex]
            local origin = edge.horizontal and (half == 1 and "RIGHT" or "LEFT") or (half == 1 and "TOP" or "BOTTOM")
            assert(shrink.animationType == "Scale" and grow.animationType == "Scale", "length pulse has no alpha animation")
            assert(shrink.target == texture and grow.target == texture, "each gradient half animates directly")
            assert(shrink.origin[1] == origin and grow.origin[1] == origin, "opaque center is the fixed pivot")
            assert(shrink.scaleFrom[axis] == 1 and shrink.scaleTo[axis] == 0.2, "maximum to minimum length")
            assert(grow.scaleFrom[axis] == 1 and grow.scaleTo[axis] == 5, "growth reverses completed shrink")
            local previous = shrink.scaleTo[axis]
            for _, progress in ipairs({0, 0.25, 0.5, 0.75, 1}) do
                local transform = grow.scaleFrom[axis] + (grow.scaleTo[axis] - grow.scaleFrom[axis]) * progress
                local length = shrink.scaleTo[axis] * transform
                assert(length >= previous and math.abs(length - (0.2 + 0.8 * progress)) < 0.00001, "composed growth is continuous from minimum to maximum")
                previous = length
            end
            assert(math.abs(previous - shrink.scaleFrom[axis]) < 0.00001, "loop boundary has no reset jump")
            assert(shrink.scaleFrom[fixed] == 1 and shrink.scaleTo[fixed] == 1, "thickness never scales")
            -- Geometric regression: at every scale both halves meet at zero,
            -- while their transparent endpoints travel between center/corner.
            local low, high = half == 1 and -0.5 or 0, half == 1 and 0 or 0.5
            local pivot = (origin == "RIGHT" or origin == "TOP") and high or low
            for _, length in ipairs({0.1, 0.25, 0.5, 1}) do
                local center = pivot + (0 - pivot) * length
                local outer = pivot + ((half == 1 and low or high) - pivot) * length
                assert(center == 0 and math.abs(outer) == 0.5 * length, "continuous centered segment at every pulse length")
            end
        end
        assert(edge:IsShown() == (style == "ALERT" and edge.horizontal) and h.border[index]:IsShown() == (style == "SOLID"), "exclusive effect visibility")
        local a, b = edge.halves[1].gradient, edge.halves[2].gradient
        assert(a[1] == (edge.horizontal and "HORIZONTAL" or "VERTICAL"), "gradient follows edge length")
        assert(a[2].a == 0 and a[3].a == 1 and b[2].a == 1 and b[3].a == 0, "symmetric opacity gradient")
        assert(a[2].r == 0.2 and a[3].r == 0.2, "color remains constant")
    end
    local count = #ui.objects; Update()
    assert(#ui.objects == count, "same effect reuses regions")
end
effect = "PULSE"; Update()
assert(h.fadeOut.duration == 0.1 and h.fadeIn.duration == 0.1, "new pulse timing defaults")
custom.PULSE = {thickness = 7, offset = 1, fadeOut = 0.4, fadeIn = 0.7}
custom.ALERT = {shrinkTime = 0.4, growTime = 0.7, minLength = 20, maxLength = 80, endOpacity = 15, centerOpacity = 75}
for _, style in ipairs({"ALERT", "SOLID"}) do
    effect = style; Update()
    assert(h.border[1].height == 7 and h.border[3].width == 7, "shared thickness")
end
assert(h.shrink[1].duration == 0.4 and h.grow[1].duration == 0.7)
assert(h.shrink[1].scaleFrom[1] == 0.8 and h.shrink[1].scaleTo[1] == 0.2)
assert(h.shrink[5].scaleFrom[2] == 0.8 and h.shrink[5].scaleTo[2] == 0.2)
assert(h.alertBorder[1].halves[1].gradient[2].a == 0.15 and h.alertBorder[1].halves[1].gradient[3].a == 0.75, "custom gradient opacities")
assert(h.frame.alpha == 1, "solid restores full opacity")
assert(h.borderOffset == 1, "shared offset updates")
for _, edges in ipairs({h.border, h.alertBorder}) do
    for _, edge in ipairs(edges) do
        for _, point in pairs(edge.points) do
            assert(math.abs(point[4]) == 1 and math.abs(point[5]) == 1, "all renderer edges move outward")
        end
    end
end
assert(h.shrink[1].scaleTo[1] * h.grow[1].scaleTo[1] == 0.8, "custom maximum does not snap at loop boundary")
effect = "PULSE"; Update()
assert(h.pulse:IsPlaying() and not h.alert:IsPlaying(), "original opacity pulse restored")
assert(h.fadeOut.duration == 0.4 and h.fadeIn.duration == 0.7, "pulse has independent timing")
for index, edge in ipairs(h.border) do
    assert(edge:IsShown() and not h.alertBorder[index]:IsShown(), "pulse includes all four solid-color edges")
end
effect = "ALERT"; Update()
assert(h.alert:IsPlaying() and not h.pulse:IsPlaying(), "Alert stops opacity pulse")
for index, edge in ipairs(h.alertBorder) do
    assert(edge:IsShown() == (index <= 2), "Alert hides both side borders")
end
enabled = false; Update()
assert(not h.frame:IsShown() and not h.pulse:IsPlaying() and not h.alert:IsPlaying())
enabled = true; Update()
ns.CastHighlight.RecordSpellcastEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "nameplate1"); Update()
assert(not h.frame:IsShown(), "noninterruptible hides selected effect")
local preview = CreateFrame("StatusBar")
effect = "PULSE"; enabled = false
ns.CastHighlight.UpdatePreview(preview)
assert(preview.RPSNCastPreview.activeEffect == "PULSE", "inactive preview retains selected effect")
assert(not preview.RPSNCastPreview.pulse:IsPlaying() and not preview.RPSNCastPreview.alert:IsPlaying(), "disabled Pulse preview is inert")
assert(preview.RPSNCastPreview.previewDisabled and preview.RPSNCastPreview.border[1].color[1] == 0.5
    and preview.RPSNCastPreview.border[1].color[2] == 0.5, "inactive preview border is grey")
effect = "ALERT"; ns.CastHighlight.UpdatePreview(preview)
assert(not preview.RPSNCastPreview.pulse:IsPlaying() and not preview.RPSNCastPreview.alert:IsPlaying(), "disabled Alert preview is inert")
local gray = preview.RPSNCastPreview.alertBorder[1].halves[1].gradient[3]
assert(gray.r == 0.5 and gray.g == 0.5 and gray.b == 0.5, "inactive Alert gradient is grey")
enabled = true; ns.CastHighlight.UpdatePreview(preview)
assert(not preview.RPSNCastPreview.previewDisabled, "reenabled preview restores chosen color")
assert(preview.RPSNCastPreview.alert:IsPlaying(), "reenabling resumes Alert")
enabled = false; ns.CastHighlight.UpdatePreview(preview)
assert(not preview.RPSNCastPreview.alert:IsPlaying(), "disabling a running Alert stops it")
enabled = true; ns.CastHighlight.UpdatePreview(preview)
local color = preview.RPSNCastPreview.alertBorder[1].halves[1].gradient[3]
assert(color.r == 0.2 and color.g == 0.8 and color.b == 1, "active preview shows configured color")
effect = "SOLID"; ns.CastHighlight.UpdatePreview(preview)
assert(not preview.RPSNCastPreview.pulse:IsPlaying(), "preview stops pulse on selection change")
ns.CastHighlight.StopPreview(preview)
assert(not preview.RPSNCastPreview.frame:IsShown())
print("Cast border effects smoke: passed")
