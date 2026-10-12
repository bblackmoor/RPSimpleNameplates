function CreateColor(r, g, b, a) return {r=r, g=g, b=b, a=a} end
-- Exercise the geometry-independent interruptible cast pulse.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function NativeIsShown(self) return self.shown end

local function Region(parent)
    local r = {parent = parent, shown = true, level = 1, scripts = {}}
    function r:GetParent() return self.parent end
    function r:SetPoint() end
    function r:ClearAllPoints() end
    function r:SetHeight(v) self.height = v end
    function r:SetWidth(v) self.width = v end
    function r:SetFrameLevel(v) self.level = v end
    function r:GetFrameLevel() return self.level end
    function r:SetScript(key, callback) self.scripts[key] = callback end
    function r:HookScript(key, callback)
        local original = self.scripts[key]
        self.scripts[key] = function(...) if original then original(...) end; callback(...) end
    end
    r.IsShown = NativeIsShown
    function r:SetShown(value)
        if self.shown == value then return end
        self.shown = value
        local callback = self.scripts[value and "OnShow" or "OnHide"]
        if callback then callback(self) end
    end
    function r:Show() self:SetShown(true) end
    function r:Hide() self:SetShown(false) end
    function r:SetAlpha(v) self.alpha = v end
    function r:SetColorTexture(...) self.color = {...} end
    function r:SetGradient(...) self.gradient = {...} end
    function r:CreateTexture() return Region(self) end
    function r:CreateAnimationGroup()
        local group = {playing = false}
        function group:Play() self.playing = true end
        function group:Stop() self.playing = false end
        function group:IsPlaying() return self.playing end
        function group:SetLooping(v) self.looping = v end
        function group:CreateAnimation()
            return setmetatable({}, {__index = function() return function() end end})
        end
        return group
    end
    return r
end

function CreateFrame(_, _, parent) return Region(parent) end
function hooksecurefunc(object, method, callback)
    object.hookCount = (object.hookCount or 0) + 1
    local original = object[method]
    object[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end

local blocked, enabled = false, true
local color = {0, 1, 1}
local ns = {
    PresentationCapabilities = {
        CanAccessFrame = function() return not blocked end,
        SafeField = function(object, key) return object and object[key] end,
        ReadRegion = function(region, method)
            if not region or type(region[method]) ~= "function" then return nil end
            return region[method](region)
        end,
    },
    AccessibleBoolean = function(value) if type(value) == "boolean" then return value end end,
    AccessibleValue = function(value) return value end,
    WorldContext = {Get = function() return {} end},
    GetStylingEnabled = function() return enabled end,
    GetInterruptibleHighlightEnabled = function() return enabled end,
    EffectColor = function() return table.unpack(color) end,
    NameplateFrames = {
        GetCastBar = function(frame) return frame.castBar end,
        GetHealthBar = function(frame) return frame.healthBar end,
    },
}

local frame = {
    unit = "nameplate1",
    castBar = Region(),
    healthBar = Region(),
    SNPPresentation = {showCastBar = true},
}
frame.castBar.Icon = Region(frame.castBar)
frame.castBar.BorderShield = Region(frame.castBar)
frame.castBar.BorderShield:Hide()
frame.castBar.HideIconWhenNotInterruptible = true

assert(loadfile("RPSimpleNameplates/Profiler.lua"))("RPSimpleNameplates", ns)
assert(loadfile("RPSimpleNameplates/PeriodicWork.lua"))("RPSimpleNameplates", ns)
assert(loadfile("RPSimpleNameplates/CastHighlight.lua"))("RPSimpleNameplates", ns)
local function Update() ns.CastHighlight.UpdateInterruptibleHighlight(frame, {}, frame.SNPPresentation) end

Update()
local highlight = assert(frame.SNPInterruptibleHighlight, "highlight created")
equal(highlight.frame.shown, true, "modern visible icon means interruptible")
assert(highlight.pulse:IsPlaying(), "pulse starts")
equal(#highlight.border, 4, "four-edge pulse border")
equal(highlight.border[1].color[2], 1, "profile color applied")
assert(frame.castBar.Icon.hookCount == 3, "all icon visibility hooks installed")
assert(frame.castBar.BorderShield.hookCount == 3, "all shield visibility hooks installed")

frame.castBar.Icon:SetShown(false)
equal(highlight.frame.shown, false, "modern hidden icon means uninterruptible")
assert(not highlight.pulse:IsPlaying(), "pulse stops")

frame.castBar.Icon:SetShown(true)
equal(highlight.frame.shown, true, "modern icon reshow restarts pulse")
color = {1, 0, 0}; Update()
equal(highlight.border[1].color[1], 1, "live color update")

-- Explicit spellcast state is retained as a fallback when native visual state
-- cannot be read.
frame.castBar.Icon.IsShown = function() return nil end
frame.castBar.BorderShield.IsShown = function() return nil end
assert(ns.CastHighlight.RecordSpellcastEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "nameplate1"))
Update()
equal(highlight.frame.shown, false, "not-interruptible event hides with unreadable native state")
assert(ns.CastHighlight.RecordSpellcastEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "nameplate1"))
Update()
equal(highlight.frame.shown, true, "interruptible event shows with unreadable native state")

-- Start clears stale event state and uses Blizzard's newly rendered visual.
frame.castBar.Icon.IsShown = NativeIsShown
frame.castBar.BorderShield.IsShown = NativeIsShown
frame.castBar.Icon.shown = true
frame.castBar.BorderShield.shown = false
ns.CastHighlight.RecordSpellcastEvent("UNIT_SPELLCAST_START", "nameplate1")
Update()
equal(highlight.frame.shown, true, "cast start derives initial modern state")

-- Classic style keeps the icon visible; the native shield supplies the state.
frame.castBar.HideIconWhenNotInterruptible = false
frame.castBar.Icon.shown = true
frame.castBar.BorderShield.shown = true
Update()
equal(highlight.frame.shown, false, "classic shield means uninterruptible")
frame.castBar.BorderShield:SetShown(false)
equal(highlight.frame.shown, true, "classic hidden shield with visible icon means interruptible")

ns.CastHighlight.RecordSpellcastEvent("UNIT_SPELLCAST_INTERRUPTED", "nameplate1")
frame.castBar.Icon.IsShown = function() return nil end
frame.castBar.BorderShield.IsShown = function() return nil end
Update()
equal(highlight.frame.shown, false, "cast end event hides stale pulse")

-- A new cast clears the preceding stop event; no geometry read is needed.
ns.CastHighlight.RecordSpellcastEvent("UNIT_SPELLCAST_START", "nameplate1")
frame.castBar.GetSize = function() error("cast geometry must not be read") end
frame.castBar.Icon.IsShown = NativeIsShown
frame.castBar.BorderShield.IsShown = NativeIsShown
frame.castBar.HideIconWhenNotInterruptible = true
frame.castBar.Icon.shown = true
frame.castBar.BorderShield.shown = false
Update()
equal(highlight.frame.shown, true, "pulse works without geometry")

blocked = true
frame.castBar.Icon:SetShown(false)
assert(highlight.frame.shown, "blocked hook defers refresh")
blocked = false
ns.PeriodicWork.Advance(0.25)
ns.PeriodicWork.Run()
equal(highlight.frame.shown, false, "deferred refresh uses current native state")

enabled = false
Update()
equal(highlight.frame.shown, false, "disable hides pulse")
assert(not highlight.pulse:IsPlaying(), "disable stops pulse")

ns.CastHighlight.ClearUnit("nameplate1")

-- Native cast visibility gates explicit events as well as visual fallback.
enabled = true
frame.castBar.Icon.IsShown = NativeIsShown
frame.castBar.BorderShield.IsShown = NativeIsShown
frame.castBar.Icon.shown = true
frame.castBar.shown = true
ns.CastHighlight.RecordSpellcastEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "nameplate1")
Update()
assert(highlight.frame.shown)
frame.castBar:Hide()
assert(not highlight.frame.shown and not highlight.pulse:IsPlaying(), "bar hide stops explicit-event effect")
frame.castBar:Show()
assert(highlight.frame.shown, "bar show catches initial visibility transition")

-- Native Show/Hide need not dispatch through SetShown; their method hooks work.
local direct = {unit = "nameplate2", castBar = Region(), SNPPresentation = {showCastBar = true}}
direct.castBar.Icon = Region(direct.castBar)
direct.castBar.HideIconWhenNotInterruptible = true
direct.castBar.Icon.Show = function(self) self.shown = true end
direct.castBar.Icon.Hide = function(self) self.shown = false end
ns.CastHighlight.UpdateInterruptibleHighlight(direct, {}, direct.SNPPresentation)
local directHighlight = direct.SNPInterruptibleHighlight
direct.castBar.Icon:Hide()
assert(not directHighlight.frame.shown, "direct native Hide repaired")
direct.castBar.Icon:Show()
assert(directHighlight.frame.shown, "direct native Show repaired")
local hooks = direct.castBar.Icon.hookCount
ns.CastHighlight.UpdateInterruptibleHighlight(direct, {}, direct.SNPPresentation)
assert(direct.castBar.Icon.hookCount == hooks, "repeated setup does not duplicate hooks")
direct.castBar.Icon.IsShown = function() return nil end
ns.CastHighlight.UpdateInterruptibleHighlight(direct, {}, direct.SNPPresentation)
assert(not directHighlight.frame.shown, "unknown state does not fabricate interruptibility")
direct.castBar.Icon.IsShown = NativeIsShown
ns.PeriodicWork.Advance(0.25); ns.PeriodicWork.Run()
assert(directHighlight.frame.shown, "unknown visual state recovers without new event")
print("Cast pulse integration smoke: passed")


