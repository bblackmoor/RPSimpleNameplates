-- Verify threat rendering, including opaque values passed only to WoW.
local function equal(actual, expected, label)
    assert(actual == expected, label)
end
local secret = setmetatable({}, {__tostring = function() error("secret inspected") end})
function issecretvalue(value) return rawequal(value, secret) end
local raw, scaled, fail = 73.4, 55, false
function UnitDetailedThreatSituation(who, unit)
    equal(who, "player", "player threat requested")
    equal(unit, "nameplate1", "current frame unit requested")
    if fail then error("unavailable") end
    return false, 1, scaled, raw
end
local enabled, accessible = true, true
local nameSize = 21
local slug = false
local function Bar()
    local bar = {}
    function bar:CreateFontString(_, layer, template)
        assert(layer == "OVERLAY", "one outlined threat label")
        equal(template, "GameFontNormal", "threat starts with valid font")
        local text = {bar = self}
        function text:GetFont() return self.font, self.size, self.flags end
        function text:GetText() return self.text end
        function text:IsShown() return self.shown end
        function text:SetAlpha(value) self.alpha = value end
        function text:SetJustifyV() end
        function text:SetDrawLayer(_, level) self.drawLevel = level end
        function text:SetPoint() end
        function text:SetJustifyH() end
        function text:SetWordWrap() end
        function text:SetMaxLines() end
        function text:SetTextColor(r, g, b) self.r, self.g, self.b = r, g, b end
        function text:SetFont(font, size, flags) self.font, self.size, self.flags = font, size, flags end
        function text:SetShadowColor(_, _, _, alpha) self.shadowAlpha = alpha end
        function text:SetShadowOffset(x, y) self.shadowX, self.shadowY = x, y end
        function text:SetText(value) self.text = value end
        function text:SetFormattedText(format, value)
            self.argument = value
            if issecretvalue(value) then self.text = "engine renders opaque percentage"
            else self.text = format:format(value) end
        end
        function text:Show() self.shown = true end
        function text:Hide() self.shown = false end
        return text
    end
    return bar
end
local frame = {unit = "nameplate1", healthBar = Bar()}
local ns = {
    PresentationCapabilities = {CanAccessFrame = function() return accessible end, ObjectStatus = function() return "accessible" end},
    AccessibleValue = function(value) return value end,
    AccessibleBoolean = function(value) return value end,
    WorldContext = {Get = function() return {} end},
    AccessibleNumber = function(value)
        assert(not issecretvalue(value), "opaque percentage must bypass numeric inspection")
        if type(value) == "number" then return value end
    end,
    FontPath = function() return "Fonts\\ARIALN.TTF" end,
    GetAppearanceSetting = function(key) return key == "nameSize" and nameSize or "ARIALN" end,
    GetThreatEnabled = function() return enabled end,
    NameplateFrames = {GetHealthBar = function(value) return value.healthBar end},
}
assert(loadfile("RPSimpleNameplates/FontRendering.lua"))("RPSimpleNameplates", ns)
local getAppearance = ns.GetAppearanceSetting
ns.GetAppearanceSetting = function(key)
    if key == "useSlugRendering" then return slug end
    return getAppearance(key)
end
assert(loadfile("RPSimpleNameplates/NameplateThreat.lua"))("RPSimpleNameplates", ns)
local function Update(showBar)
    ns.NameplateThreat.UpdateThreatText(frame, "hostile", {}, {showHealthBar = showBar})
end
Update(true)
equal(frame.RPSNThreatText.text, "55%", "scaled percentage displayed")
equal(frame.RPSNThreatText.shown, true, "percentage explicitly shown")
equal(frame.RPSNThreatText.drawLevel, 7, "percentage drawn above bar artwork")
equal(frame.RPSNThreatText.r, 1, "threat stays white")
equal(frame.RPSNThreatText.size, 21, "threat matches default name size")
equal(frame.RPSNThreatText.flags, "OUTLINE", "threat has thin outline")
assert(frame.RPSNThreatText.RPSNUnderlayers == nil, "threat never creates glyph copies")
assert(ns.NameplateThreat.UpdateLayerAlpha == nil, "no health-dependent threat-layer updates")
equal(frame.RPSNThreatText.shadowAlpha, 0, "native threat shadow disabled")
equal(frame.RPSNThreatText.shadowX, 0, "native shadow x cleared")
equal(frame.RPSNThreatText.shadowY, 0, "native shadow y cleared")
equal(frame.RPSNThreatText.font, "Fonts\\ARIALN.TTF", "separate threat font retained")
slug = true; Update(true)
equal(frame.RPSNThreatText.flags, "SLUG,OUTLINE", "threat uses outlined Slug")
slug = false; Update(true)
equal(frame.RPSNThreatText.flags, "OUTLINE", "threat returns to ordinary rendering")
nameSize = 36
Update(true)
equal(frame.RPSNThreatText.r, 1, "threat remains white after size change")
equal(frame.RPSNThreatText.size, 36, "threat follows changed name size")
scaled = 0
Update(true)
equal(frame.RPSNThreatText.text, "0%", "readable zero displayed")
scaled = secret
Update(true)
assert(rawequal(frame.RPSNThreatText.argument, secret), "secret scaled percentage passed directly to display API")
equal(frame.RPSNThreatText.shown, true, "opaque scaled percentage displayed")
local originalFontSetter = frame.RPSNThreatText.SetFont
frame.RPSNThreatText.SetFont = function() error("value-only update must not configure fonts") end
ns.NameplateThreat.UpdateThreatValue(frame, "hostile", {}, {showHealthBar = true})
assert(rawequal(frame.RPSNThreatText.argument, secret), "focused threat passes opaque percentage to the display sink")
frame.RPSNThreatText.SetFont = originalFontSetter
scaled, raw = nil, 255
Update(true)
equal(frame.RPSNThreatText.text, "", "raw 255 percentage is never used")
equal(frame.RPSNThreatText.shown, false, "raw-only threat is hidden")
raw, scaled = nil, nil
Update(true)
equal(frame.RPSNThreatText.text, "", "absent threat never fabricated")
equal(frame.RPSNThreatText.shown, false, "absent threat hidden")
raw, scaled = 255, 100
enabled = false
Update(true)
equal(frame.RPSNThreatStatus, "disabled", "disabled preference honored")
enabled = true
Update(false)
equal(frame.RPSNThreatText.shown, false, "name-only presentation has no threat label")
local previousText = frame.RPSNThreatText
frame.healthBar = Bar()
Update(true)
equal(previousText.shown, false, "old bar label hidden on replacement")
equal(frame.RPSNThreatText.bar, frame.healthBar, "label follows current health bar")
equal(frame.RPSNThreatText.shown, true, "replacement label shown")
fail = true
Update(true)
equal(frame.RPSNThreatStatus, "threat API unavailable", "API failure reported")
equal(frame.RPSNThreatText.shown, false, "failed API clears stale percentage")
accessible = false
ns.NameplateThreat.UpdateThreatText({}, "hostile", {}, {showHealthBar = true})
print("Nameplate threat smoke: passed")


