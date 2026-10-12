-- Verify native edge removal and reversible bar/text artwork.
local ns = {}
local secretTexture = {}
issecretvalue = function(value) return value == secretTexture end
local slug = false
ns.GetAppearanceSetting = function(key) return key == "useSlugRendering" and slug end
assert(loadfile("RPSimpleNameplates/FontRendering.lua"))("RPSimpleNameplates", ns)
local barRGB = {1, 1, 0}
ns.PriorityColorForState = function() return barRGB[1], barRGB[2], barRGB[3] end
local unpackValues = unpack or table.unpack
assert(loadfile("RPSimpleNameplates/Core.lua"))("RPSimpleNameplates", ns)
ns.WorldContext = {Get = function() return {combatLockdown = false} end}
assert(loadfile("RPSimpleNameplates/Profiler.lua"))("RPSimpleNameplates", ns)
assert(loadfile("RPSimpleNameplates/PresentationCapabilities.lua"))("RPSimpleNameplates", ns)
assert(loadfile("RPSimpleNameplates/NameplateFrames.lua"))("RPSimpleNameplates", ns)
local function Region()
    local r = {alpha = 1, shown = true, texture = "original", coords = {0.1, 0.9, 0.2, 0.8},
        font = "font", size = 10, flags = "OUTLINE", shadow = {0, 0, 0, 1}, offset = {1, -1}}
    function r:GetNumPoints() return #(self.points or {}) end
    function r:GetPoint(index) return unpackValues(self.points[index]) end
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = {...} end
    function r:SetDrawLayer(layer, level) self.layer, self.level = layer, level end
    function r:GetDrawLayer() return self.layer or "ARTWORK", self.level or 0 end
    function r:GetText() return self.text end
    function r:SetText(text) self.text = text end
    function r:SetJustifyH() end
    function r:SetJustifyV() end
    function r:SetWordWrap() end
    function r:SetMaxLines() end
    function r:IsShown() return self.shown end
    function r:GetAlpha() return self.alpha end
    function r:SetAlpha(v) self.alpha = v end
    function r:GetAtlas() return self.atlas end
    function r:GetTexture() return self.texture end
    function r:SetTexture(v) self.texture, self.atlas = v, nil end
    function r:SetAtlas(v) self.atlas = v end
    function r:GetTexCoord() return unpackValues(self.coords) end
    function r:SetTexCoord(...) self.coords = {...} end
    function r:GetTextColor() return self.r or 0.7, self.g or 0.8, self.b or 0.9, 1 end
    function r:SetTextColor(r, g, b) self.r, self.g, self.b = r, g, b end
    function r:GetVertexColor() return self.vr or 0.5, self.vg or 0.5, self.vb or 0.5, 1 end
    function r:SetVertexColor(r, g, b) self.vr, self.vg, self.vb = r, g, b end
    function r:GetFont() return self.font, self.size, self.flags end
    function r:SetFont(f, s, flags) self.font, self.size, self.flags = f, s, flags end
    function r:GetShadowColor() return unpackValues(self.shadow) end
    function r:SetShadowColor(...) self.shadow = {...} end
    function r:GetShadowOffset() return unpackValues(self.offset) end
    function r:SetShadowOffset(...) self.offset = {...} end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetAllPoints(bar) self.bar = bar end
    function r:SetColorTexture(...) self.color = {...} end
    return r
end
local function Bar(backgroundKey)
    local bar = Region()
    bar[backgroundKey], bar.barTexture = Region(), Region()
    bar.barTexture.atlas = "native-fill"
    function bar:CreateTexture() return Region() end
    function bar:CreateFontString() return Region() end
    function bar:HookScript(_, callback) self.onShow = callback end
    return bar
end
local health, cast = Bar("bgTexture"), Bar("Background")
health.Text, health.RightText, health.LeftText = Region(), Region(), Region()
health.Text:SetPoint("CENTER", health, "CENTER", 0, 0)
health.selectedBorder, health.deselectedOverlay = Region(), Region()
health.overAbsorbGlow, health.totalAbsorb, health.totalAbsorbOverlay = Region(), Region(), Region()
health.overAbsorbGlow.alpha = 0.7
health.overHealAbsorbGlow = Region()
cast.Border, cast.DropShadow, cast.Text = Region(), Region(), Region()
cast.BorderShield = Region()
health.Text.flags = "THICKOUTLINE"
cast.Text.flags = "MONOCHROME"
-- Retail rewrites the native texture even when the bar remains shown.
function hooksecurefunc(object, method, callback)
    local original = object[method]
    object[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end
local function Color(r, g, b)
    return {GetRGB = function() return r, g, b end}
end
CastingBarTypeInfo = {
    standard = {filling = "native-yellow", full = "native-green", classicFillColor = Color(1, 0.7, 0), classicFullColor = Color(0, 1, 0)},
    interrupted = {filling = "native-red", full = "native-red", classicFillColor = Color(1, 0, 0), classicFullColor = Color(1, 0, 0)},
}
local castFill = cast.barTexture
cast.barTexture = Region() -- stale alias must not take precedence over getter
function cast:GetStatusBarTexture() return castFill end
function cast:UpdateBarFillTexture(atlas)
    castFill:SetAtlas(atlas)
    castFill:SetVertexColor(1, 1, 1)
end
cast.Spark, cast.Flash, cast.StandardGlow = Region(), Region(), Region()
function cast:ShowSpark()
    self.Spark:SetAlpha(1)
    self.Spark:Show()
    self.StandardGlow:Show()
end
cast:UpdateBarFillTexture("native-yellow")
-- Native control fields must stay untainted, including during restoration.
setmetatable(cast, {
    __index = function(_, key) if key == "classicStyleCastBar" then return false end end,
    __newindex = function(self, key, value)
        assert(key ~= "classicStyleCastBar", "must not write native cast control fields")
        rawset(self, key, value)
    end,
})
local frame = {healthBar = health, castBar = cast, overAbsorbGlow = Region()}
local context = ns.WorldContext.Get()
local assessment = ns.PresentationCapabilities.InspectFrame(frame, context)
ns.NameplateFrames.ApplyBarArtwork(frame, assessment, context)
for _, key in ipairs({"Text", "RightText", "LeftText"}) do
    assert(health[key].r == 1 and health[key].g == 1 and health[key].b == 1, "bright bar native text white")
    assert(health[key].flags == "OUTLINE", "native health text has thin outline")
    assert(health[key].shadow[4] == 0 and health[key].RPSNUnderlayers == nil, "native health text has no shadow or copies")
    assert(health[key].vr == 1, "native text tint neutral")
end
assert(health.LeftText.points[1][5] == -0.5, "rightmost native health label padding moves down")
assert(health.RightText.points[1][2] == health.LeftText and health.RightText.points[1][3] == "LEFT", "native value follows percentage")
assert(health.Text.points[1][2] == health.RightText and health.Text.points[1][3] == "LEFT", "single native label cannot overlap other shown labels")
barRGB = {0, 0, 1}
ns.NameplateFrames.ApplyBarArtwork(frame, assessment, context)
assert(health.LeftText.points[1][5] == -0.5 and health.Text.points[1][5] == 0, "native text padding does not accumulate")
assert(health.Text.r == 1, "native health text stays white on dark bars")
assert(health.bgTexture.alpha == 0 and health.selectedBorder.alpha == 0)
assert(health.overAbsorbGlow.alpha == 0 and frame.overAbsorbGlow.alpha == 0, "overflow glow hidden in both layouts")
health.overAbsorbGlow:Hide()
health.overAbsorbGlow:Show()
assert(health.overAbsorbGlow.alpha == 0, "native show cannot reveal overflow glow")
assert(health.totalAbsorb.alpha == 1 and health.totalAbsorbOverlay.alpha == 1, "absorb display preserved")
assert(health.overHealAbsorbGlow.alpha == 1, "heal absorb display preserved")
assert(health.deselectedOverlay.alpha == 0 and cast.Border.alpha == 0)
assert(cast.DropShadow.alpha == 0 and cast.BorderShield.alpha == 1, "shield stays intact")
assert(cast.Text.flags == "OUTLINE" and cast.Text.shadow[4] == 0 and cast.Text.offset[1] == 0)
assert(cast.Text.font == "font" and cast.Text.size == 10, "cast face/size preserved")
slug = true
ns.NameplateFrames.ApplyBarArtwork(frame, assessment, context)
assert(cast.Text.flags == "SLUG,OUTLINE", "cast text uses outlined Slug")
for _, key in ipairs({"Text", "RightText", "LeftText"}) do
    assert(health[key].flags == "SLUG,OUTLINE", "native health text uses outlined Slug")
end
slug = false
ns.NameplateFrames.ApplyBarArtwork(frame, assessment, context)
assert(cast.Text.flags == "OUTLINE" and health.Text.flags == "OUTLINE", "toggle off restores ordinary rendering")
assert(cast.classicStyleCastBar == false, "native cast style untouched")
-- Live cast atlas identifiers can be secret even though the fill is writable.
local getAtlas, getTexture = castFill.GetAtlas, castFill.GetTexture
castFill.GetAtlas, castFill.GetTexture = function() return nil end, function() return nil end
castFill:SetAtlas("secret-live-cast")
cast.onShow()
assert(castFill.atlas == nil and castFill.texture == "Interface\\Buttons\\WHITE8X8", "hidden live identifier cannot block flat fill repair")
castFill.GetAtlas, castFill.GetTexture = getAtlas, getTexture
assert(health.barTexture.texture == "Interface\\Buttons\\WHITE8X8")
assert(health.RPSNPlainBackground.bar == health and health.RPSNPlainBackground.shown)
castFill:SetAtlas("changed-for-new-cast")
cast.onShow()
assert(castFill.atlas == nil, "new casts regain flat artwork")
assert(cast.Spark.alpha == 0 and cast.Flash.alpha == 0 and cast.StandardGlow.alpha == 0, "cast decorations suppressed")
cast:UpdateBarFillTexture("native-green")
assert(castFill.atlas == nil and castFill.texture == "Interface\\Buttons\\WHITE8X8", "visible cast texture rewrite repaired immediately")
assert(castFill.vr == 0 and castFill.vg == 1 and castFill.vb == 0, "Blizzard completion color retained in flat fill")
cast:UpdateBarFillTexture("native-red")
assert(castFill.vr == 1 and castFill.vg == 0 and castFill.vb == 0, "Blizzard interrupted color retained")
cast:UpdateBarFillTexture("native-yellow")
assert(castFill.vr == 1 and castFill.vg == 0.7 and castFill.vb == 0, "Blizzard casting color retained")
cast:ShowSpark()
assert(cast.Spark.alpha == 0 and cast.StandardGlow.alpha == 0, "native spark refresh remains suppressed")
assert(cast.BorderShield.alpha == 1, "non-interruptible shield remains intact")
cast.Flash:SetAtlas("completion-glow")
cast.Flash:SetAlpha(1) -- native animation can change alpha after the repair
assert(cast.Flash.texture == nil and cast.Flash.atlas == nil, "animation cannot reveal decorative shine")
-- A native layout callback during font writes cannot recurse through artwork.
local setFont, writes = cast.Text.SetFont, 0
function cast.Text:SetFont(...)
    writes = writes + 1
    assert(writes < 5, "recursive native artwork repair")
    setFont(self, ...)
    cast.onShow()
end
ns.NameplateFrames.ApplyBarArtwork(frame, assessment, context)
assert(writes == 1, "one artwork font write despite callback")
cast.Text.SetFont = function() error("simulated artwork failure") end
assert(not pcall(ns.NameplateFrames.ApplyBarArtwork, frame, assessment, context))
assert(frame.RPSNApplyingArtwork == nil, "artwork failure releases guard")
cast.Text.SetFont = setFont
ns.NameplateFrames.ApplyBarArtwork(frame, assessment, context)
-- Restoring while a decorated region is inaccessible must retain originals.
health.bgTexture.IsForbidden = function() return true end
assert(not pcall(ns.NameplateFrames.RestoreBarArtwork, frame, context))
assert(frame.RPSNOriginalArtwork, "failed restoration keeps backup")
health.bgTexture.IsForbidden = nil
ns.NameplateFrames.RestoreBarArtwork(frame, context)
assert(health.Text.points[1][5] == 0, "native text anchor restored")
assert(health.Text.layer == "ARTWORK" and health.Text.level == 0, "native draw layer restored")
assert(health.Text.r == 0.7 and health.Text.g == 0.8 and health.Text.vr == 0.5, "native health text restored")
assert(health.bgTexture.alpha == 1 and health.selectedBorder.alpha == 1)
assert(health.overAbsorbGlow.alpha == 0.7 and frame.overAbsorbGlow.alpha == 1, "original overflow glow alpha restored")
assert(cast.classicStyleCastBar == false, "native cast style untouched during restoration")
assert(cast.Border.alpha == 1 and cast.DropShadow.alpha == 1)
assert(cast.Spark.texture == "original" and cast.Flash.texture == "original", "native decoration textures restored")
assert(cast.Spark.alpha == 1 and cast.Flash.alpha == 1 and castFill.vr == 1 and castFill.vg == 1, "native cast artwork and tint restored")
assert(health.barTexture.atlas == "native-fill" and health.barTexture.coords[1] == 0.1)
assert(health.Text.flags == "THICKOUTLINE", "original health outline restored")
assert(cast.Text.flags == "MONOCHROME" and cast.Text.shadow[4] == 1 and cast.Text.offset[1] == 1)
assert(not health.RPSNPlainBackground.shown and not frame.RPSNOriginalArtwork)
castFill:SetAtlas("restored-native-update")
cast.onShow()
assert(castFill.atlas == "restored-native-update", "inactive hooks leave Blizzard alone")
cast:UpdateBarFillTexture("native-green")
assert(castFill.atlas == "native-green" and castFill.vr == 1, "inactive fill hook leaves native artwork untouched")
cast:ShowSpark()
assert(cast.Spark.alpha == 1, "inactive spark hook leaves native artwork untouched")
-- Fresh styling after a settings refresh has no saved fill to rely on.
castFill.GetAtlas = function() return nil end
castFill.GetTexture = function() return secretTexture end
castFill.texture, castFill.atlas = secretTexture, nil
ns.NameplateFrames.ApplyBarArtwork(frame, assessment, context)
assert(castFill.texture == "Interface\\Buttons\\WHITE8X8", "fresh secret cast is flattened")
ns.NameplateFrames.RestoreBarArtwork(frame, context)
assert(castFill.texture == secretTexture, "opaque native texture forwarded during restoration")
ns.NameplateFrames.ApplyBarArtwork(frame, assessment, context)
assert(castFill.texture == "Interface\\Buttons\\WHITE8X8", "settings restyle keeps secret cast plain")
ns.NameplateFrames.RestoreBarArtwork(frame, context)
castFill.GetAtlas, castFill.GetTexture = getAtlas, getTexture
print("Bar artwork smoke: passed")

