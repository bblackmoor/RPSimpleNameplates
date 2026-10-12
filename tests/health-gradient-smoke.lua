-- Verify fixed tint geometry and native clipping without reading health.
local ui = dofile("tests/details-framework-ui-stubs.lua")
local methods = getmetatable(UIParent).__index
function methods:SetAlpha(value) self.alpha = value end
local opacity = 100
local ns = {GetGradientOpacity = function() return opacity end,
    GetAppearanceSetting = function() return false end,
    WorldContext = {Get = function() return {} end},
    PresentationCapabilities = {
        ObjectStatus = function(object) return object and not object.blocked and "accessible" or "forbidden" end,
        ReadRegion = function(object, method) return object[method](object) end,
    }}
for _, file in ipairs({"Core", "FontRendering", "HealthGradient"}) do
    assert(loadfile("RPSimpleNameplates/" .. file .. ".lua"))("RPSimpleNameplates", ns)
end
function UnitHealth() error("gradient must not read health") end
function UnitHealthMax() error("gradient must not read health") end
function UnitHealthPercent() error("gradient must not read health percent") end
local bar = CreateFrame("StatusBar")
bar:SetWidth(200)
bar:SetStatusBarTexture("native")
local fill = bar:GetStatusBarTexture()
ns.HealthGradient.Apply(bar, fill, {})
local tint, mask = bar.SNPHealthGradient, bar.SNPHealthGradientMask
local tail = bar.SNPHealthGradientTail
assert(tint.width == 190 and math.abs(tail.width - 10) < 0.00001, "fade spans first 95% and clear tail spans final 5%")
assert(mask.textureSampling[1] == "CLAMPTOBLACKADDITIVE"
    and mask.textureSampling[2] == "CLAMPTOBLACKADDITIVE"
    and mask.textureSampling[3] == "NEAREST", "hard clip cannot blend with transparent outside texels")
assert(tint.color[1] == 1 and tint.color[2] == 1 and tint.color[3] == 1
    and tint.color[4] == 1, "solid tint base has no texture-edge shading")
assert(tint.gradient[1] == "HORIZONTAL" and tint.gradient[2].a == 0.8 and tint.gradient[3].a == 0)
assert(tail.gradient[2].a == 0 and tail.gradient[3].a == 0, "final 5% stays fully clear")
assert(tail.mask == mask, "fade and clear tail share native clipping")
assert(tint.mask == mask and mask.allPoints == fill, "clip follows native remaining fill geometry")
for _, remainingWidth in ipairs({200, 160, 100, 20}) do
    fill:SetWidth(remainingWidth)
    assert(tint.width == 190 and math.abs(tail.width - 10) < 0.00001 and mask.allPoints == fill, "native health loss cannot rescale gradient")
end
local replacement = bar:CreateTexture()
ns.HealthGradient.Apply(bar, replacement, {})
assert(mask.allPoints == replacement and bar.SNPHealthGradient == tint, "replacement fill reuses/reanchors tint")
bar:SetWidth(250)
ns.HealthGradient.Apply(bar, replacement, {})
assert(tint.width == 237.5 and math.abs(tail.width - 12.5) < 0.00001, "configured width preserves fade and clear tail proportions")
for _, value in ipairs({25, 50, 75, 100}) do
    opacity = value
    ns.HealthGradient.Apply(bar, replacement, {})
    assert(tint.alpha == 1 and tail.alpha == 1, "gradient texture opacity stays full")
    assert(math.abs(tint.gradient[2].a - 0.8 * value / 100) < 0.00001 and tint.gradient[3].a == 0, "slider scales left darkness and leaves right endpoint clear")
    assert(tint.width == 237.5 and mask.allPoints == replacement, "opacity leaves geometry/clipping intact")
end
opacity = 0
ns.HealthGradient.Apply(bar, replacement, {})
assert(not tail:IsShown() and not tint:IsShown())
opacity = 100
ns.HealthGradient.Apply(bar, replacement, {})
assert(tint:IsShown())
ns.HealthGradient.Hide(bar)
assert(not tail:IsShown() and not tint:IsShown(), "restoration hides tint")
print("Health gradient smoke: passed")


