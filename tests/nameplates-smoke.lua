function CreateColor(r, g, b, a) return {r=r, g=g, b=b, a=a} end
-- Characterize nameplate classification and one-time runtime setup.
-- Run from the repository root: lua tests/nameplates-smoke.lua
local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
    end
end

local frames, hooks, timers = {}, {}, {}
function CreateFrame(kind)
    local frame = { kind = kind, registered = {}, scripts = {} }
    function frame:RegisterEvent(event) self.registered[event] = (self.registered[event] or 0) + 1 end
    function frame:UnregisterEvent(event) self.registered[event] = nil end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    frames[#frames + 1] = frame
    return frame
end
function hooksecurefunc(name, callback, objectCallback)
    hooks[#hooks + 1] = { name = name, method = objectCallback and callback, callback = objectCallback or callback }
end
function CompactUnitFrame_UpdateHealthColor() end
function CompactUnitFrame_UpdateName() end
C_NamePlate = {
    GetNamePlateForUnit = function() return nil end,
    GetNamePlates = function() return {} end,
}
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay, callback } end }
function wipe(t) for key in pairs(t) do t[key] = nil end end

local unit = {}
local barColorOverride
local threatEnabled, threatPercent = false, nil
function UnitDetailedThreatSituation() return false, 1, threatPercent, 255 end
function UnitThreatSituation(who) return who == "player" and unit.aggro and 2 or nil end
function UnitIsUnit(token, target) return unit.targetPlayer and token == "nameplate1target" and target == "player" or false end
function UnitIsOwnerOrControllerOfUnit() return false end
function UnitIsPlayer() return unit.player or false end
function UnitPlayerControlled() return unit.controlled or false end
function UnitCanAttack(who)
    if who == "player" then return unit.canAttack or false end
    return unit.canAttackUs or false
end
function UnitFactionGroup(who) return who == "player" and "Alliance" or unit.faction end
function UnitReaction() return unit.reaction end
function UnitIsPVP() return unit.pvp or false end
local unitExists = true
function UnitExists() return unitExists end
function UnitName(token)
    if unit.unavailableNames then error("restricted name") end
    return unit.names and unit.names[token] or "Diagnostic Target"
end
function UnitAffectingCombat() return false end
function UnitIsInteractable() return unit.interactable or false end

local appearance = { namePlacement = "ABOVE", nameSize = 12, nameFont = "ARIALN", threatFont = "ARIALN", healthBarWidth = 100 }
local categoryMode = "active"
local trp3Options = {}
local calls = {}
local stylingEnabled = true
local highlightEnabled = false
local function count(name) calls[name] = (calls[name] or 0) + 1 end
local ns = {
    EnsureDB = function() count("db") end,
    AccessibleNumber = function(value) return type(value) == "number" and value or nil end,
    AccessibleBoolean = function(value) if type(value) == "boolean" then return value end end,
    AccessibleValue = function(value)
        if issecretvalue and issecretvalue(value) then return nil end
        if canaccessvalue and not canaccessvalue(value) then return nil end
        return value
    end,
    GetStylingEnabled = function() return stylingEnabled and categoryMode ~= "inactive" end,
    GetHealthBarEnabled = function() return true end,
    GetCategoryMode = function() return categoryMode end,
    GetAppearanceSetting = function(key) return appearance[key] end,
    GetTRP3Setting = function(key) return trp3Options[key] or false end,
    GetInterruptibleHighlightEnabled = function() return highlightEnabled end,
    GetThreatEnabled = function() return threatEnabled end,
    GetHideCritterCompanionNames = function() return false end,
    PriorityColorForState = function(state)
        if barColorOverride then return barColorOverride[1], barColorOverride[2], barColorOverride[3] end
        if state == "useful" then return 211 / 255, 211 / 255, 211 / 255 end
        if state == "useless" then return 153 / 255, 153 / 255, 153 / 255 end
        return 1, 0, 0
    end,
    EffectColor = function() return 0, 1, 1 end,
    FontPath = function(value)
        if value == "FRIZQT" then return "Fonts\\FRIZQT__.TTF" end
        return "Fonts\\ARIALN.TTF"
    end,
    ApplyCritterCompanionNameVisibility = function() count("critters") end,
    DisableFriendlyClassColors = function() count("classColors") end,
    ApplyPendingManagedNameSettings = function() count("pending") end,
    ApplyManagedNameSettings = function() count("managed") end,
    RegisterSettingsPanels = function() count("settings") end,
    ShowNameplateConflictWarning = function() count("warning") end,
    MANAGED_NAME_CVAR_SET = { unitnamefriendlyplayername = true },
    BLIZZARD_CRITTER_COMPANION_NAME_CVARS = {},
    FRIENDLY_COLOR_CVARS = {},
}
for _, file in ipairs({ "Profiler.lua", "PeriodicWork.lua", "WorldContext.lua", "EntityFacts.lua", "NameplateClassification.lua", "PresentationCapabilities.lua", "PresentationRules.lua", "FontRendering.lua", "NameplateFrames.lua", "NPCTitles.lua", "NameplateText.lua", "NameplateThreat.lua", "CastHighlight.lua", "NameplateRestoration.lua", "NameplatePresentation.lua", "Nameplates.lua", "Diagnostics.lua" }) do
    assert(loadfile("RPSimpleNameplates/" .. file))("RPSimpleNameplates", ns)
end
-- Retired category-disable fixtures exercise the global restoration path.
local runtimeRefresh = ns.RefreshAll
ns.RefreshAll = function()
    if categoryMode == "inactive" then ns.RestoreAll() else
        runtimeRefresh()
        -- Characterization fixtures settle queued global work explicitly.
        frames[1].scripts.OnUpdate(frames[1], 0.001)
        for _ = 1, 30 do ns.PeriodicWork.Run() end
    end
end
equal(#frames, 1, "one event frame")
local events = frames[1]
-- Characterization fixtures wait for the bounded periodic cycle to settle.
-- Phase 4's dedicated checks below use individual RuntimeUpdate calls.
local function Tick(elapsed)
    events.scripts.OnUpdate(events, elapsed)
    for _ = 1, 20 do ns.PeriodicWork.Run() end
end
equal(#hooks, 2, "two Blizzard repair hooks")
equal(hooks[1].name, "CompactUnitFrame_UpdateHealthColor", "health hook")
equal(hooks[2].name, "CompactUnitFrame_UpdateName", "name hook")
local countEvents = 0
for _, registered in pairs(events.registered) do countEvents = countEvents + registered end
equal(countEvents, 33, "one registration for each event")
assert(events.scripts.OnEvent and events.scripts.OnUpdate, "event/update scripts installed")
assert(not events.registered.UNIT_HEALTH and not events.registered.UNIT_MAXHEALTH, "no events for retired threat-layer threshold")
events.scripts.OnEvent(events, "ADDON_LOADED", "AnotherAddon")
equal(calls.db, nil, "other addon ignored")
events.scripts.OnEvent(events, "ADDON_LOADED", "RPSimpleNameplates")
equal(calls.db, 1, "database initialized once")
equal(events.registered.ADDON_LOADED, nil, "load event unregistered")
events.scripts.OnEvent(events, "PLAYER_LOGIN")
equal(calls.settings, 1, "settings registration on login")
equal(calls.critters, 1, "managed critter settings on login")
equal(calls.overhead, nil, "removed replacement has no login action")
equal(calls.classColors, nil, "login does not change native class colors")
events.scripts.OnEvent(events, "CVAR_UPDATE", "UnitNameFriendlyPlayerName")
equal(calls.managed, 1, "managed CVar update reapplied")
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
equal(calls.pending, 1, "deferred CVar action applied after combat")
Tick(0.25)
assert(ns.RefreshAll and ns.RestoreAll and ns.DebugUnit and ns.StateForUnit, "runtime API")

local cases = {
    { label = "attacking NPC", data = { reaction = 3, aggro = true }, state = "attacking" },
    { label = "hostile NPC", data = { reaction = 3 }, state = "hostile" },
    { label = "attackable neutral", data = { reaction = 4, canAttackUs = true }, state = "neutral" },
    { label = "opposing PC", data = { player = true, faction = "Horde", reaction = 2 }, state = "friendly" },
    { label = "attackable opposing PC", data = { player = true, faction = "Horde", canAttack = true }, state = "hostile" },
    { label = "same faction PC", data = { player = true, faction = "Alliance", reaction = 5 }, state = "friendly" },
    { label = "controlled pet", data = { controlled = true, reaction = 5 }, state = "useless" },
    { label = "friendly NPC", data = { reaction = 5 }, state = "useless" },
    { label = "useful NPC", data = { reaction = 5, interactable = true }, state = "useful" },
    { label = "hostile vendor", data = { reaction = 3, interactable = true }, state = "hostile" },
    { label = "restricted reaction fallback", data = { reaction = {} }, state = "useless" },
}
for _, case in ipairs(cases) do
    unit = case.data
    equal(ns.StateForUnit("nameplate1"), case.state, case.label)
end
-- Exercise presentation across modules, not just event registration.
local function Region()
    local region = { shown = true, alpha = 1, height = 20, width = 140 }
    function region:HookScript(event, callback)
        self.scriptHooks = self.scriptHooks or {}
        self.scriptHooks[event] = self.scriptHooks[event] or {}
        table.insert(self.scriptHooks[event], callback)
    end
    function region:SetShown(shown)
        if self.shown == shown then return end
        self.shown = shown
        local callback = self.scripts and self.scripts[shown and "OnShow" or "OnHide"]
        if callback then callback(self) end
        for _, callback in ipairs(self.scriptHooks and self.scriptHooks[shown and "OnShow" or "OnHide"] or {}) do callback(self) end
    end
    function region:Show() self:SetShown(true) end
    function region:Hide() self:SetShown(false) end
    function region:IsShown() return self.shown end
    function region:IsInterruptable() return self.Icon and self.Icon:IsShown() or false end
    function region:IsVisible() return self.shown end
    function region:SetAlpha(value) self.alpha = value end
    function region:GetAlpha() return self.alpha end
    function region:SetHeight(value) self.height = value end
    function region:GetHeight() return self.height end
    function region:GetWidth() return self.width end
    function region:SetWidth(width) self.width = width end
    function region:SetText(value) self.text = value end
    function region:GetText() return self.text end
    function region:SetFormattedText(format, value) self.text = format:format(value) end
    function region:SetFont(font, size, flags) self.font, self.size, self.flags = font, size, flags end
    function region:GetFont() return self.font, self.size, self.flags end
    function region:SetFontObject() self:SetFont("Native object", 10, ""); self:SetTextColor(1, 1, 1) end
    function region:SetTextHeight(value) self.size = value end
    function region:SetTextColor(r, g, b) self.r, self.g, self.b = r, g, b end
    function region:GetTextColor() return self.r, self.g, self.b end
    function region:SetVertexColor(r, g, b, a) self.vr, self.vg, self.vb, self.va = r, g, b, a end
    function region:GetVertexColor() return self.vr, self.vg, self.vb, self.va end
    function region:SetStatusBarColor(r, g, b) self.barR, self.barG, self.barB = r, g, b end
    function region:GetStatusBarColor() return self.barR, self.barG, self.barB end
    function region:GetNumPoints() return #(self.points or {}) end
    function region:GetPoint(index) return table.unpack(self.points[index]) end
    function region:ClearAllPoints() self.points = {} end
    function region:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = {...} end
    function region:CreateFontString() return Region() end
    function region:CreateTexture() return Region() end
    function region:SetAllPoints() end
    function region:SetColorTexture(...) self.color = {...} end
    function region:SetGradient(...) self.gradient = {...} end
    function region:GetFrameLevel() return self.level or 1 end
    function region:SetFrameLevel(level) self.level = level end
    function region:SetScript(event, callback)
        self.scripts = self.scripts or {}
        self.scripts[event] = callback
    end
    function region:CreateAnimationGroup()
        local group = {playing = false}
        function group:Play() self.playing = true end
        function group:Stop() self.playing = false end
        function group:IsPlaying() return self.playing end
        function group:SetLooping(value) self.looping = value end
        function group:CreateAnimation()
            return setmetatable({}, {__index = function() return function() end end})
        end
        return group
    end
    function region:SetShadowColor(...) self.shadow = {...} end
    function region:SetShadowOffset(x,y) self.shadowX, self.shadowY = x,y end
    function region:GetShadowColor() return table.unpack(self.shadow or {0, 0, 0, 0}) end
    function region:GetShadowOffset() return self.shadowX or 0, self.shadowY or 0 end
    function region:SetWordWrap(value) self.wordWrap = value end
    function region:SetMaxLines(value) self.maxLines = value end
    for _, method in ipairs({ "SetJustifyH", "SetJustifyV",
        "SetDrawLayer" }) do region[method] = function() end end
    return region
end
local createEventFrame = CreateFrame
function CreateFrame(kind, name, parent)
    if parent then return Region() end
    return createEventFrame(kind)
end
local plateFrame = Region()
plateFrame.unit, plateFrame.name = "nameplate1", Region()
plateFrame.healthBar, plateFrame.HealthBarsContainer = Region(), Region()
plateFrame.name:SetFont("NativeFont", 10, "")
plateFrame.name:SetText("Native name")
plateFrame.name:SetTextColor(0.2, 0.4, 0.6)
plateFrame.name:SetPoint("BOTTOM", plateFrame, "TOP", 0, 4)
plateFrame.healthBar:SetStatusBarColor(0.3, 0.5, 0.7)
local plate = { UnitFrame = plateFrame }
C_NamePlate.GetNamePlateForUnit = function() return plate end
C_NamePlate.GetNamePlates = function() return { plate } end

unit = { reaction = 3 }
ns.RefreshAll()
equal(plateFrame.RPSNState, "hostile", "hostile presentation category")
equal(plateFrame.healthBar.shown, true, "hostile bar visible")
equal(plateFrame.name.r, 1, "bar name white red")
equal(plateFrame.name.g, 1, "bar name white green")
equal(plateFrame.healthBar.barG, 0, "priority applied to health bar")
-- Width follows the profile, resists Blizzard layout drift, and restores.
appearance.healthBarWidth = 150
ns.RefreshAll()
equal(plateFrame.healthBar.width, 210, "bar uses 150 percent native width")
equal(plateFrame.HealthBarsContainer.width, 210, "container follows bar width")
plateFrame.healthBar.width, plateFrame.HealthBarsContainer.width = 140, 140
Tick(0.25)
equal(plateFrame.healthBar.width, 210, "cached repair restores configured width")
appearance.healthBarWidth = 125
ns.RefreshAll()
equal(plateFrame.healthBar.width, 175, "changing width does not compound scaling")
categoryMode = "inactive"
ns.RefreshAll()
equal(plateFrame.healthBar.width, 140, "inactive restores native bar width")
equal(plateFrame.HealthBarsContainer.width, 140, "inactive restores container width")
categoryMode, appearance.healthBarWidth = "active", 100
ns.RefreshAll()


unit = { player = true, faction = "Alliance", reaction = 5 }
ns.RefreshAll()
equal(plateFrame.healthBar.shown, true, "friendly uniform bar presentation")
equal(plateFrame.name.g, 1, "uniform bar name stays white")
plateFrame.name:SetTextColor(0, 1, 1)
Tick(0.25)
equal(plateFrame.name.g, 1, "cached drift repaired across module boundary")

ns.TRP3 = { GetDisplayInfo = function()
    return { roleplayingName = "Roleplay Name", fullTitle = "Long Title" }
end }
trp3Options = { useRoleplayingName = true, showFullTitle = true }
ns.RefreshAll()
equal(plateFrame.name.text, "Roleplay Name", "TRP3 name retained")
equal(plateFrame.RPSNFullTitleText.shown, true, "name-only long title shown")
-- Combat changes presentation without changing the Friendly classification.
appearance.namePlacement = "INSIDE"
local oldNameStyle = {}
for key, value in pairs(plateFrame.RPSNNameStyle) do oldNameStyle[key] = value end
events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
Tick(0.25)
equal(plateFrame.RPSNState, "friendly", "combat does not change category")
equal(plateFrame.healthBar.shown, true, "friendly combat bar")
equal(plateFrame.RPSNFullTitleText.shown, true, "idle friendly combat retains long title")
equal(plateFrame.RPSNInsideName.shown, true, "friendly combat inside name")
equal(plateFrame.healthBar.height, 20, "friendly combat padding")
equal(plateFrame.name.g, 1, "bright bar inside name stays white")
equal(plateFrame.RPSNInsideName.r, 1, "inside overlay stays white")
barColorOverride = {0, 0, 0.2}
ns.RefreshAll()
equal(plateFrame.RPSNInsideName.r, 1, "dark bar inside name stays white")
plateFrame.name:SetTextColor(0, 0, 0)
ns.NameplateText.RepairCachedName(plateFrame, ns.WorldContext.Get())
equal(plateFrame.RPSNInsideName.r, 1, "cached repair preserves white inside text")
barColorOverride = nil
ns.RefreshAll()

plateFrame.RPSNNameStyle = oldNameStyle
equal(ns.NameplateText.RepairCachedName(plateFrame, ns.WorldContext.Get()), false, "stale cache rejected")
Tick(0.25)
equal(plateFrame.healthBar.shown, true, "stale drift cannot undo combat bar")
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
-- A Blizzard name hook must apply the whole new decision before the queued refresh.
hooks[2].callback(plateFrame)
equal(plateFrame.healthBar.shown, true, "name hook preserves bar on combat exit")
equal(plateFrame.RPSNFullTitleText.shown, true, "combat exit restores title")
equal(plateFrame.RPSNInsideName.shown, true, "combat exit retains inside name")
equal(plateFrame.name.alpha, 0, "combat exit retains concealed native name")
equal(plateFrame.healthBar.height, 20, "combat exit restores height")

unit = { reaction = 3 }
appearance.namePlacement = "INSIDE"
ns.RefreshAll()
equal(plateFrame.RPSNFullTitleText.shown, true, "idle health bar permits long title")
equal(plateFrame.RPSNInsideName.text, "Roleplay Name", "inside name retained")
equal(plateFrame.name.alpha, 0, "original inside name concealed")
equal(plateFrame.healthBar.height, 20, "inside padding retained")
equal(plateFrame.RPSNInsideName.size, 12, "inside name retains selected size")
equal(plateFrame.RPSNInsideName.flags, "OUTLINE", "inside name has thin outline")
threatEnabled, threatPercent = true, nil
ns.RefreshAll()
equal(plateFrame.RPSNInsideName.points[2][2], plateFrame.healthBar, "blank threat uses full bar width")
equal(plateFrame.RPSNInsideName.points[2][4], -3, "blank threat leaves only right padding")
threatPercent = 255
ns.RefreshAll()
equal(plateFrame.RPSNInsideName.points[2][2], plateFrame.RPSNThreatText, "name ends beside visible threat")
equal(plateFrame.RPSNInsideName.points[2][3], "LEFT", "name uses actual threat left edge")
ns.NameplateText.RepairCachedName(plateFrame, ns.WorldContext.Get())
equal(plateFrame.RPSNInsideName.points[2][2], plateFrame.RPSNThreatText, "cached repair preserves threat anchor")
threatEnabled, threatPercent = false, nil
ns.RefreshAll()

equal(plateFrame.name.flags, "OUTLINE", "hidden native inside name has thin outline")
appearance.nameSize = 36
ns.RefreshAll()
equal(plateFrame.RPSNInsideName.size, 36, "large inside name retains full size")
equal(plateFrame.RPSNInsideName.shadow[4], 0, "inside name native shadow disabled")
equal(plateFrame.RPSNInsideName.shadowX, 0, "inside name native shadow x cleared")
equal(plateFrame.RPSNInsideName.shadowY, 0, "inside name native shadow y cleared")
equal(plateFrame.RPSNInsideName.points[1][5], -0.5, "asymmetric padding moves name half unit down")
equal(plateFrame.healthBar.height, 43, "bar expands for full font plus padding")
equal(plateFrame.HealthBarsContainer.height, 43, "container expands with bar")
plateFrame.healthBar:SetHeight(20)
Tick(0.25)
equal(plateFrame.healthBar.height, 43, "drift repair retains expanded height")
appearance.namePlacement, threatEnabled, threatPercent = "ABOVE", true, 100
ns.RefreshAll()
equal(plateFrame.healthBar.height, 43, "above-bar names still leave padding for threat text")
equal(plateFrame.RPSNInsideName.shown, false, "threat text does not move above-bar name inside")
equal(plateFrame.name.flags, "OUTLINE", "outside name keeps thin outline")
appearance.namePlacement, threatEnabled, threatPercent = "INSIDE", false, nil
appearance.nameSize = 12
ns.RefreshAll()


categoryMode = "inactive"
ns.RefreshAll()
equal(plateFrame.RPSNState, nil, "inactive restores category presentation")
equal(plateFrame.RPSNInsideName.shown, false, "inside overlay restored")
equal(plateFrame.name.alpha, 1, "original name alpha restored")
equal(plateFrame.healthBar.height, 20, "original bar height restored")
equal(plateFrame.name.font, "NativeFont", "original native font restored")
equal(plateFrame.name.text, UnitName(plateFrame.unit), "current native name restored")
equal(plateFrame.name.g, 0.4, "original native name color restored")
equal(plateFrame.name.points[1][5], 4, "original native name anchor restored")
equal(plateFrame.healthBar.barG, 0.5, "original native bar color restored")
categoryMode = "active"
appearance.namePlacement = "ABOVE"
ns.RefreshAll()
ns.RestoreAll()
equal(plateFrame.RPSNState, nil, "master restoration reachable")

-- Restoration must not invoke native updates that compare secret health.
local nativeUpdates = 0
local updateName, updateColor = CompactUnitFrame_UpdateName, CompactUnitFrame_UpdateHealthColor
local function UnsafeNativeUpdate()
    nativeUpdates = nativeUpdates + 1
    error("attempt to compare maxHealth (a secret number value)")
end
CompactUnitFrame_UpdateAll = UnsafeNativeUpdate
CompactUnitFrame_UpdateName, CompactUnitFrame_UpdateHealthColor = UnsafeNativeUpdate, UnsafeNativeUpdate
for index = 1, 3 do
    categoryMode = "active"
    ns.RefreshAll()
    categoryMode = "inactive"
    ns.RefreshAll()
    equal(plateFrame.RPSNState, nil, "hostile disable succeeds without native updates")
    equal(ns.NameplateRestoration.IsPending(plateFrame), false, "secret health cannot queue retries")
    equal(plateFrame.name.font, "NativeFont", "hostile disable restores native font")
    equal(plateFrame.healthBar.barG, 0.5, "hostile disable restores native bar color")
end
equal(nativeUpdates, 0, "restoration never enters native health update stack")
CompactUnitFrame_UpdateAll = nil
CompactUnitFrame_UpdateName, CompactUnitFrame_UpdateHealthColor = updateName, updateColor
categoryMode = "active"

-- A failed presentation write retains originals and releases the guard.
ns.RefreshAll()
local setBarColor = plateFrame.healthBar.SetStatusBarColor
plateFrame.healthBar.SetStatusBarColor = function() error("simulated presentation restoration failure") end
ns.RestoreAll()
equal(plateFrame.RPSNRestoring, nil, "failed restoration releases guard")
assert(ns.NameplateRestoration.IsPending(plateFrame), "failed restoration retained for retry")
assert(plateFrame.RPSNOriginalPresentation, "failed restoration retains native presentation")
plateFrame.healthBar.SetStatusBarColor = setBarColor
Tick(0.25)
equal(ns.NameplateRestoration.IsPending(plateFrame), false, "successful retry removes pending work")
equal(plateFrame.RPSNState, "hostile", "successful retry reapplies hostile presentation")
ns.RestoreAll()
plateFrame.unit = "nameplate1"
C_NamePlate.GetNamePlateForUnit = function() return nil end
C_NamePlate.GetNamePlates = function() return {} end

-- Existing cast effects and their Blizzard icon hook obey the shared decision.
C_NamePlate.GetNamePlateForUnit = function() return plate end
C_NamePlate.GetNamePlates = function() return {plate} end
unit = { player = true, faction = "Alliance", reaction = 5 }
plateFrame.castBar = Region()
plateFrame.castBar:Hide()
plateFrame.castBar.Icon = Region()
plateFrame.RPSNInterruptibleHighlight = nil
local castHighlight = ns.CastHighlight.EnsureInterruptibleHighlight(plateFrame)
local castOverlay = castHighlight.frame
highlightEnabled = true
plateFrame.castBar:Hide()
ns.RefreshAll() -- Capture the native idle cast bar before simulating a cast.
plateFrame.castBar:Show()
ns.RefreshAll()
equal(castOverlay.shown, true, "uniform friendly cast effect permitted")
equal(castHighlight.pulse:IsPlaying(), true, "visible cast highlight starts pulse")
equal(plateFrame.RPSNFullTitleText.shown, false, "active cast replaces title")
plateFrame.castBar:Hide()
equal(plateFrame.RPSNFullTitleText.shown, true, "cast end restores title without a styling pass")
equal(plateFrame.RPSNFullTitleText.points[1][2], plateFrame.healthBar, "title anchors below health bar")
ns.RefreshAll()
equal(plateFrame.castBar.shown, false, "styling does not show idle cast bar")
plateFrame.castBar:Show()
equal(plateFrame.RPSNFullTitleText.shown, false, "channel/cast start immediately hides title")
plateFrame.IsForbidden = function() return true end
plateFrame.castBar:Hide()
equal(plateFrame.RPSNTitleVisibilityPending, true, "blocked transition queues title visibility")
plateFrame.IsForbidden = nil
Tick(0.25)
equal(plateFrame.RPSNFullTitleText.shown, true, "blocked cast end retries when accessible")
plateFrame.castBar:Show()
events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
Tick(0.25)
equal(castOverlay.shown, true, "combat cast effect follows Blizzard icon")
local iconHook = hooks[#hooks].callback
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
Tick(0.25)
iconHook(plateFrame.castBar.Icon, true)
equal(castOverlay.shown, true, "uniform icon hook remains available after combat")
highlightEnabled = false
-- An idle cast bar permits a title even when the health bar is visible.
plateFrame.castBar:Hide()
local hideBar = plateFrame.healthBar.Hide
plateFrame.healthBar.Hide = function() end
plateFrame.healthBar.shown = true
ns.RefreshAll()
equal(plateFrame.RPSNFullTitleText.shown, true, "observed health bar permits idle title")
local currentCast = plateFrame.castBar
local titleHooks = #currentCast.scriptHooks.OnShow
local readShown = currentCast.IsShown
currentCast.IsShown = function() error("cast visibility unavailable") end
ns.RefreshAll()
equal(plateFrame.RPSNFullTitleText.shown, false, "unreadable cast visibility hides title")
equal(plateFrame.RPSNTitleVisibilityPending, true, "unreadable cast visibility queues retry")
currentCast.IsShown = readShown
Tick(0.25)
equal(plateFrame.RPSNFullTitleText.shown, true, "readable idle state restores title")
plateFrame.castBar = Region(); plateFrame.castBar:Hide(); ns.RefreshAll()
plateFrame.castBar:Show()
currentCast:Show(); currentCast:Hide()
equal(plateFrame.RPSNFullTitleText.shown, false, "retired cast cannot show title over replacement cast")
plateFrame.castBar:Hide()
equal(plateFrame.RPSNFullTitleText.shown, true, "replacement cast end restores title")
plateFrame.castBar = currentCast; ns.RefreshAll()
equal(#currentCast.scriptHooks.OnShow, titleHooks, "returning cast bar reuses title hook")
trp3Options.showFullTitle = false; ns.RefreshAll()
currentCast:Show(); currentCast:Hide()
equal(plateFrame.RPSNFullTitleText.shown, false, "cast end cannot revive disabled TRP3 title")
trp3Options.showFullTitle = true; ns.RefreshAll()
stylingEnabled = false; ns.RestoreAll()
currentCast:Show(); currentCast:Hide()
equal(plateFrame.RPSNFullTitleText.shown, false, "cast end cannot revive restored title")
stylingEnabled = true; ns.RefreshAll()
plateFrame.healthBar.Hide = hideBar
ns.RefreshAll()

-- Missing bars use a colored floating name and permit a title even in combat.
C_NamePlate.GetNamePlateForUnit = function() return plate end
C_NamePlate.GetNamePlates = function() return {plate} end
local savedBar = plateFrame.healthBar
plateFrame.healthBar = nil
unit = { reaction = 3 }
events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
Tick(0.25)
equal(plateFrame.RPSNPresentation.showHealthBar, false, "no fabricated health bar")
equal(plateFrame.RPSNPresentation.nameOnly, true, "missing bar uses name color")
equal(plateFrame.name.g, 0, "missing-bar priority color")
equal(plateFrame.RPSNFullTitleText.shown, true, "missing bar allows long title")
plateFrame.name:ClearAllPoints()
equal(ns.NameplateText.RepairCachedName(plateFrame, ns.WorldContext.Get()), true, "unchanged readable properties need no repair")
equal(#plateFrame.name.points, 0, "reconciliation does not rewrite unobserved native anchors")
ns.NameplateText.UpdateNameLayout(plateFrame, ns.WorldContext.Get(), plateFrame.RPSNPresentation)
equal(plateFrame.name.points[1][2], plateFrame, "missing-bar repair uses the owning frame")
equal(plateFrame.name.points[1][1], "BOTTOM", "missing-bar repair restores floating placement")
plateFrame.healthBar = savedBar
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
ns.RestoreAll()

-- Context events still run with styling disabled; combat state is independent.
stylingEnabled = false
function GetZoneText() return "Silvermoon City" end
function GetSubZoneText() return "Shared" end
function InCombatLockdown() return false end
C_PvP = { GetZonePVPInfo = function() return "sanctuary", false end }
events.scripts.OnEvent(events, "ZONE_CHANGED")
equal(ns.WorldContext.Get().sanctuary, true, "context updated with styling off")
events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
equal(ns.WorldContext.Get().inCombat, true, "combat cached with styling off")
equal(ns.WorldContext.Get().combatLockdown, false, "lockdown separate from combat")
stylingEnabled = true
-- All mutation entry points skip forbidden frames, including direct Blizzard hooks.
local forbidden = setmetatable({ IsForbidden = function() return true end }, {
    __index = function(_, key) error("forbidden frame inspected: " .. key) end,
    __newindex = function() error("forbidden frame modified") end,
})
C_NamePlate.GetNamePlateForUnit = function() return {UnitFrame = forbidden} end
C_NamePlate.GetNamePlates = function() return {{UnitFrame = forbidden}} end
ns.RefreshAll()
ns.RestoreAll()
hooks[1].callback(forbidden)
hooks[2].callback(forbidden)
Tick(0.25)
events.scripts.OnEvent(events, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
ns.NameplateText.RestoreNameDisplay(forbidden)
equal(ns.NameplateText.CachedNameHasDrifted(forbidden), false, "forbidden drift skipped")
ns.CastHighlight.EnsureInterruptibleHighlight(forbidden)
ns.CastHighlight.UpdateInterruptibleHighlight(forbidden)
-- A protected frame skipped in lockdown is styled again after combat exit.
local locked = true
function InCombatLockdown() return locked end
plateFrame.IsProtected = function() return true end
C_NamePlate.GetNamePlateForUnit = function() return plate end
C_NamePlate.GetNamePlates = function() return {plate} end
plateFrame.RPSNState = nil
ns.WorldContext.Refresh("PLAYER_REGEN_DISABLED")
ns.RefreshAll()
equal(plateFrame.RPSNState, nil, "protected frame skipped during lockdown")
locked = false
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
Tick(0.25)
assert(plateFrame.RPSNState, "protected frame refreshed after lockdown")
plateFrame.IsProtected = nil
C_NamePlate.GetNamePlateForUnit = function() return nil end
C_NamePlate.GetNamePlates = function() return {} end

-- Disabled styling still retries restoration after combat lockdown ends.
C_NamePlate.GetNamePlateForUnit = function() return plate end
C_NamePlate.GetNamePlates = function() return {plate} end
unit = { player = true, faction = "Alliance", reaction = 5 }
appearance.namePlacement = "INSIDE"
locked = false
ns.WorldContext.Refresh("PLAYER_REGEN_DISABLED")
ns.RefreshAll()
equal(plateFrame.healthBar.height, 20, "styled height before lockdown")
plateFrame.IsProtected = function() return true end
locked = true
ns.WorldContext.Refresh("PLAYER_REGEN_DISABLED")
stylingEnabled = false
ns.RestoreAll()
Tick(0.25)
assert(plateFrame.RPSNState, "protected style retained until safe restoration")
locked = false
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
Tick(0.25)
equal(plateFrame.RPSNState, nil, "disabled styling restoration retried")
equal(plateFrame.RPSNPresentation, nil, "presentation cache cleared on restore")
equal(plateFrame.RPSNInsideName.shown, false, "deferred inside name hidden")
equal(plateFrame.healthBar.height, 20, "deferred original height restored")
plateFrame.IsProtected = nil
stylingEnabled = true
ns.RefreshAll()
local baseForbidden = true
plate.IsForbidden = function() return baseForbidden end
stylingEnabled = false
ns.RestoreAll()
Tick(0.25)
assert(plateFrame.RPSNState, "forbidden base plate restoration postponed")
baseForbidden = false
Tick(0.25)
equal(plateFrame.RPSNState, nil, "base plate restoration retried with styling off")
plate.IsForbidden = nil
stylingEnabled = true
categoryMode = "active"
ns.RefreshAll()
local frameForbidden = true
plateFrame.IsForbidden = function() return frameForbidden end
categoryMode = "inactive"
ns.RefreshAll()
frameForbidden = false
Tick(0.25)
equal(plateFrame.RPSNState, nil, "inactive restoration after access returns without context event")
plateFrame.IsForbidden = nil
categoryMode = "active"
ns.RefreshAll()
-- Deferred removed-unit cleanup cannot clear a newly styled recycled frame.
plateFrame.IsProtected = function() return true end
locked = true
ns.WorldContext.Refresh("PLAYER_REGEN_DISABLED")
C_NamePlate.GetNamePlateForUnit = function() return nil end
events.scripts.OnEvent(events, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
plateFrame.unit = "nameplate2"
locked = false
ns.WorldContext.Refresh("PLAYER_REGEN_ENABLED")
C_NamePlate.GetNamePlateForUnit = function() return plate end
ns.RefreshAll()
equal(plateFrame.RPSNOriginalUnit, "nameplate2", "recycled frame captures current owner")
Tick(0.25)
assert(plateFrame.RPSNState, "old pending cleanup does not clear recycled style")
equal(plateFrame.name.text, "Roleplay Name", "recycled name remains")
plateFrame.IsProtected = nil
plateFrame.unit = "nameplate1"
ns.RefreshAll()

-- Removed plate lookup may already be gone; retain the last known frame for cleanup.
C_NamePlate.GetNamePlateForUnit = function() return nil end
C_NamePlate.GetNamePlates = function() return {} end
events.scripts.OnEvent(events, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
equal(plateFrame.RPSNState, nil, "removed known frame cleaned")
equal(plateFrame.name.text, "", "removed name cleared")
appearance.namePlacement = "ABOVE"

-- Execute the diagnostic path: the extracted targeting predicate must remain available.
local output, originalPrint = {}, print
print = function(message) output[#output + 1] = message end
unit = { player = true, faction = "Horde", canAttack = true, targetPlayer = true }
ns.DebugUnit("nameplate1")
assert(table.concat(output, "\n"):find("targeting your controlled unit: yes", 1, true),
    "diagnostics use the classification targeting predicate")
-- Diagnostics may read an accessible cast bar but must not create an overlay or hook.
local frameCount, hookCount = #frames, #hooks
plateFrame.castBar = Region()
plateFrame.castBar:Hide()
C_NamePlate.GetNamePlateForUnit = function() return plate end
plateFrame.RPSNInterruptibleHighlight = nil
ns.DebugUnit("nameplate1")
equal(#frames, frameCount, "diagnostic creates no frame")
equal(#hooks, hookCount, "diagnostic installs no hook")
equal(plateFrame.RPSNInterruptibleHighlight, nil, "diagnostic creates no overlay")
-- Diagnose the actual current icon's registered hook without installing one.
local diagnosticIcon = Region()
plateFrame.castBar.Icon = diagnosticIcon
plateFrame.RPSNInterruptibleHighlight = nil
ns.CastHighlight.EnsureInterruptibleHighlight(plateFrame)
assert(plateFrame.RPSNInterruptibleHighlight.hookedIcons[diagnosticIcon], "diagnostic fixture installs real cast hook")
local diagnosticFrames, diagnosticHooks = #frames, #hooks
output = {}
ns.DebugUnit("nameplate1")
assert(table.concat(output, "\n"):find("hook installed yes", 1, true), "registered current icon hook diagnosed")
plateFrame.castBar.Icon = Region()
output = {}
ns.DebugUnit("nameplate1")
assert(table.concat(output, "\n"):find("hook installed no", 1, true), "replacement unhooked icon diagnosed")
plateFrame.castBar.Icon = diagnosticIcon
output = {}
ns.DebugUnit("nameplate1")
assert(table.concat(output, "\n"):find("hook installed yes", 1, true), "returning registered icon diagnosed")
plateFrame.castBar.Icon = nil
output = {}
ns.DebugUnit("nameplate1")
assert(table.concat(output, "\n"):find("cast icon found no; hook installed no", 1, true), "missing current icon diagnosed")
equal(#frames, diagnosticFrames, "hook diagnosis creates no frames")
equal(#hooks, diagnosticHooks, "hook diagnosis installs no hooks")
plateFrame.RPSNInterruptibleHighlight = nil

output = {}
categoryMode = "inactive"
ns.DebugUnit("nameplate1")
assert(table.concat(output, "\n"):find("configured display: Blizzard presentation", 1, true), "inactive diagnosed")
categoryMode = "active"
stylingEnabled = false
ns.DebugUnit("nameplate1")
assert(table.concat(output, "\n"):find("configured color: Blizzard-controlled", 1, true), "disabled diagnosed")
stylingEnabled = true
C_NamePlate.GetNamePlateForUnit = function() return {UnitFrame = forbidden} end
ns.DebugUnit("nameplate1")
assert(table.concat(output, "\n"):find("Presentation access: forbidden", 1, true), "forbidden diagnosed")
output = {}
unitExists = false
-- Target aliases can miss direct lookup while an enumerated plate matches.
unitExists = true
local previousIsUnit, previousGUID = UnitIsUnit, UnitGUID
local previousLookup, previousList = C_NamePlate.GetNamePlateForUnit, C_NamePlate.GetNamePlates
local cachedStyle = plateFrame.RPSNNameStyle
plateFrame.RPSNNameStyle = {text = "Cached diagnostic label", nameOnly = true, inside = false}
local diagnosticStyle = plateFrame.RPSNNameStyle
local beforeFrames, beforeHooks = #frames, #hooks
C_NamePlate.GetNamePlateForUnit = function(token)
    if token == "target" then return nil end
    return plate
end
C_NamePlate.GetNamePlates = function() return {plate, plate} end
UnitIsUnit = function(a, b) return a == "nameplate1" and b == "target" end
ns.DebugUnit("target")
local report = table.concat(output, "\n")
assert(report:find("direct missing", 1, true), "target direct lookup miss reported")
assert(report:find("matching frames: 1", 1, true), "enumeration finds and deduplicates matching frame")
assert(report:find("enumerated unit match", 1, true), "lookup source reported")
assert(report:find("Cached name style: found", 1, true), "addon cached text reported")
assert(report:find("RPSNFullTitleText: found", 1, true), "addon title region reported")
equal(plateFrame.RPSNNameStyle, diagnosticStyle, "diagnostic does not rewrite cached style")
equal(#frames, beforeFrames, "enumerated diagnostic creates no frames")
equal(#hooks, beforeHooks, "enumerated diagnostic creates no hooks")

-- Unrelated frames are counted but do not flood chat, even with stale displayed text.
output = {}
local previousNameText = plateFrame.name.text
plateFrame.unit = "nameplate2"
plateFrame.name:SetText("Orin Straylight")
diagnosticStyle.text = "Orin Straylight"
unit.names = {nameplate2 = "Different NPC"}
ns.DebugUnit("target")
report = table.concat(output, "\n")
assert(report:find("matching frames: 0", 1, true), "nonmatching frame remains unmatched")
assert(report:find("scanned: 2", 1, true), "unrelated enumeration counted")
assert(report:find("unique relevant frames: 0", 1, true), "unrelated details omitted")
assert(not report:find("Different NPC", 1, true), "unrelated unit not dumped")
assert(not report:find("text: Orin Straylight", 1, true), "stale displayed name not used to select a plate")
equal(plateFrame.name.text, "Orin Straylight", "diagnostic does not repair stale text")
equal(plateFrame.unit, "nameplate2", "diagnostic does not change unit")
equal(plateFrame.RPSNNameStyle, diagnosticStyle, "nonmatching cache untouched")
equal(#frames, beforeFrames, "nonmatching diagnostic creates no frames")
equal(#hooks, beforeHooks, "nonmatching diagnostic creates no hooks")

-- Both Orin presentations remain visible together, without claiming name-based identity.
output = {}
local secondFrame = {unit = "nameplate3", name = Region()}
secondFrame.name:SetText("Orin Straylight")
local secondPlate = {UnitFrame = secondFrame}
local nearby = {plate, secondPlate, plate}
for index = 1, 50 do
    local token = "nearby" .. index
    unit.names[token] = "Unrelated " .. index
    nearby[#nearby + 1] = {UnitFrame = {unit = token}}
end
unit.names.target, unit.names.nameplate2, unit.names.nameplate3 = "Orin Straylight", "Orin Straylight", "Orin Straylight"
C_NamePlate.GetNamePlates = function() return nearby end
UnitNameplateShowsWidgetsOnly = function(token) return token == "nameplate2" end
ns.DebugUnit("target")
report = table.concat(output, "\n")
assert(report:find("matching frames: 0", 1, true), "same names never count as identity matches")
assert(report:find("unique relevant frames: 2", 1, true), "both same-name frames selected and deduplicated")
assert(report:find("token nameplate2; unit name: Orin Straylight; matches inspected unit: no; same name: yes", 1, true), "widget candidate distinguished")
assert(report:find("token nameplate3; unit name: Orin Straylight; matches inspected unit: no; same name: yes", 1, true), "ordinary candidate distinguished")
assert(report:find("Plate kind [nameplate2]: softinteract match: no; widgets only: yes", 1, true), "widget plate retained")
assert(report:find("Plate kind [nameplate3]: softinteract match: no; widgets only: no", 1, true), "ordinary plate retained")
assert(not report:find("Unrelated", 1, true), "crowded surroundings omitted")
local _, detailsCount = report:gsub("Relevant nameplate", "")
equal(detailsCount, 2, "each relevant frame detailed once")
assert(#output < 85, "two presentations fit a bounded report despite 50 nearby units")
output = {}
unit.unavailableNames = true
ns.DebugUnit("target")
assert(table.concat(output, "\n"):find("unique relevant frames: 0", 1, true), "unavailable names never associate plates")
unit.unavailableNames = nil
UnitNameplateShowsWidgetsOnly = nil
C_NamePlate.GetNamePlates = function() return {plate, plate} end
plateFrame.unit = "nameplate1"
plateFrame.name:SetText(previousNameText)
unit.names = nil

output = {}
UnitIsUnit = function() error("identity unavailable") end
UnitGUID = function(token)
    if token == "target" or token == "nameplate1" then return "Creature-Match" end
end
ns.DebugUnit("target")
assert(table.concat(output, "\n"):find("matching frames: 1", 1, true), "readable GUID fallback")

output = {}
UnitGUID = function() return {} end
ns.DebugUnit("target")
report = table.concat(output, "\n")
assert(report:find("matching frames: 0", 1, true), "unreadable identity never matches by name")
assert(report:find("identity unavailable: 2", 1, true), "unknown identity reported")

output = {}
C_NamePlate.GetNamePlates = function() return { {IsForbidden = function() return true end} } end
ns.DebugUnit("target")
assert(table.concat(output, "\n"):find("matching frames: 0", 1, true), "forbidden candidate skipped")
assert(table.concat(output, "\n"):find("identity unavailable: 1", 1, true), "forbidden candidate counted without details")
output = {}
C_NamePlate.GetNamePlates = function() error("enumeration unavailable") end
ns.DebugUnit("target")
assert(table.concat(output, "\n"):find("enumeration available: no", 1, true), "failed enumeration reported")
UnitIsUnit, UnitGUID = previousIsUnit, previousGUID
plateFrame.RPSNNameStyle = cachedStyle
C_NamePlate.GetNamePlateForUnit, C_NamePlate.GetNamePlates = previousLookup, previousList
output = {}
unitExists = false
ns.DebugUnit("target")
assert(table.concat(output, "\n"):find("RP Simple Nameplates context:", 1, true), "no-target context")
assert(table.concat(output, "\n"):find("No target selected.", 1, true), "no-target reported")
-- A mouseover report works with no selected target and no nearby plate.
unitExists = true
local oldExists = UnitExists
UnitExists = function(token) return token == "mouseover" end
C_NamePlate.GetNamePlateForUnit = function() return nil end
C_NamePlate.GetNamePlates = function() return {} end
output = {}
local mouseoverFrameCount, mouseoverHookCount = #frames, #hooks
ns.DebugUnit("mouseover")
local mouseoverReport = table.concat(output, "\n")
assert(mouseoverReport:find("debug [mouseover]", 1, true), "report identifies inspected token")
assert(mouseoverReport:find("direct missing", 1, true), "distant mouseover plate absence reported")
assert(mouseoverReport:find("matching frames: 0", 1, true), "no mouseover plate invented")
equal(#frames, mouseoverFrameCount, "mouseover diagnostic creates no frames")
equal(#hooks, mouseoverHookCount, "mouseover diagnostic creates no hooks")
output = {}
unitExists = false
UnitExists = oldExists
ns.DebugUnit("mouseover")
assert(table.concat(output, "\n"):find("No mouseover unit available.", 1, true), "missing mouseover reported")
unitExists = true
print = originalPrint

-- The shared sanctuary decision reaches text, titles, bars, and repair hooks.
C_NamePlate.GetNamePlateForUnit = function() return plate end
C_NamePlate.GetNamePlates = function() return {plate} end
C_PvP = {GetZonePVPInfo = function() return "sanctuary", false end}
for _, case in ipairs({
    {data = {player = true, faction = "Alliance", reaction = 5}, green = 0},
    {data = {reaction = 5, interactable = true}, green = 211 / 255},
    {data = {reaction = 5}, green = 153 / 255},
    {data = {player = true, faction = "Horde", reaction = 5}, green = 0},
}) do
    unit = case.data
    ns.WorldContext.Refresh("PLAYER_REGEN_ENABLED")
    ns.RefreshAll()
    equal(plateFrame.name.g, 1, "sanctuary uniform bar name")
    equal(plateFrame.RPSNFullTitleText.r, 1, "TRP3 title remains white across categories: red")
    equal(plateFrame.RPSNFullTitleText.g, 1, "TRP3 title remains white across categories: green")
    equal(plateFrame.RPSNFullTitleText.b, 1, "TRP3 title remains white across categories: blue")
    plateFrame.name:SetTextColor(0, 0, 0)
    hooks[2].callback(plateFrame)
    equal(plateFrame.name.g, 1, "sanctuary uniform name repair")
    ns.WorldContext.Refresh("PLAYER_REGEN_DISABLED")
    ns.RefreshAll()
    equal(plateFrame.healthBar.barG, case.green, "sanctuary combat bar")
    plateFrame.healthBar:SetStatusBarColor(0, 0, 0)
    hooks[1].callback(plateFrame)
    equal(plateFrame.healthBar.barG, case.green, "sanctuary health repair")
end

-- Match the localized world-name face while retaining the selected size and plain text.
appearance.matchSanctuaryFont = true
SystemFont_World = {GetFont = function() return "Fonts\\WorldLocalized.ttf", 64, "" end}
unit = {reaction = 5, interactable = true}
ns.WorldContext.Refresh("PLAYER_REGEN_ENABLED")
ns.RefreshAll()
equal(plateFrame.name.font, "Fonts\\WorldLocalized.ttf", "sanctuary uses localized world font")
equal(plateFrame.name.size, 12, "sanctuary preserves name size")
equal(plateFrame.name.flags, "OUTLINE", "sanctuary name uses thin outline")
equal(plateFrame.RPSNFullTitleText.flags, "OUTLINE", "title uses thin outline")
equal(plateFrame.RPSNFullTitleText.font, "Fonts\\WorldLocalized.ttf", "sanctuary TRP3 title font")
plateFrame.name:SetFont("Fonts\\Drift.ttf", 12, "OUTLINE")
Tick(0.25)
equal(plateFrame.name.font, "Fonts\\WorldLocalized.ttf", "cached repair retains sanctuary font")
appearance.matchSanctuaryFont = false
Tick(0.25)
equal(plateFrame.name.font, "Fonts\\ARIALN.TTF", "switch off invalidates font cache")
equal(plateFrame.RPSNFullTitleText.font, "Fonts\\ARIALN.TTF", "switch off refreshes title font")
appearance.matchSanctuaryFont = true
appearance.namePlacement = "INSIDE"
ns.WorldContext.Refresh("PLAYER_REGEN_DISABLED")
ns.RefreshAll()
equal(plateFrame.RPSNInsideName.font, "Fonts\\WorldLocalized.ttf", "inside-bar sanctuary font")
C_PvP = {GetZonePVPInfo = function() return "friendly", false end}
ns.WorldContext.Refresh("ZONE_CHANGED_NEW_AREA")
ns.RefreshAll()
equal(plateFrame.name.font, "Fonts\\ARIALN.TTF", "leaving sanctuary restores selected font")
equal(plateFrame.RPSNInsideName.shown, true, "leaving sanctuary retains uniform inside name")
ns.WorldContext.Refresh("PLAYER_REGEN_DISABLED")
ns.RefreshAll()
equal(plateFrame.RPSNInsideName.font, "Fonts\\ARIALN.TTF", "outside sanctuary combat restores inside font")
appearance.namePlacement = "ABOVE"
C_PvP = {GetZonePVPInfo = function() return "sanctuary", false end}
ns.WorldContext.Refresh("PLAYER_REGEN_ENABLED")
ns.RefreshAll()
equal(plateFrame.name.font, "Fonts\\WorldLocalized.ttf", "reentering sanctuary restores matching font")
SystemFont_World = {GetFont = function() error("unavailable") end}
ns.RefreshAll()
equal(plateFrame.name.font, "Fonts\\FRIZQT__.TTF", "unavailable world font falls back to Friz Quadrata")
SystemFont_World = nil
appearance.matchSanctuaryFont = false

-- NPC service titles appear below health without TRP3 while no cast is active.
plateFrame.castBar:Hide()
Enum = {TooltipDataLineType = {None = 0, UnitName = 2, UnitLevel = 47}}
C_TooltipInfo = {GetUnit = function()
    return {lines = {{type = 2, leftText = "Orin Straylight"},
        {type = 0, leftText = "Voidforge Steward"}, {type = 47, leftText = "Level 90"}}}
end}
unit = {reaction = 5, interactable = true}
trp3Options = {}
ns.WorldContext.Refresh("PLAYER_REGEN_ENABLED")
ns.RefreshAll()
equal(plateFrame.RPSNFullTitleText.text, "<Voidforge Steward>", "NPC service title independent of TRP3")
equal(plateFrame.RPSNFullTitleText.shown, true, "NPC service title shown below floating name")
equal(plateFrame.RPSNFullTitleText.size, 10, "NPC title uses name size minus two")
equal(plateFrame.RPSNFullTitleText.r, 1, "NPC title white red channel")
equal(plateFrame.RPSNFullTitleText.g, 1, "NPC title white green channel")
equal(plateFrame.RPSNFullTitleText.b, 1, "NPC title white blue channel")
appearance.matchSanctuaryFont = true
SystemFont_World = {GetFont = function() return "Fonts\\WorldLocalized.ttf" end}
ns.RefreshAll()
equal(plateFrame.RPSNFullTitleText.font, "Fonts\\WorldLocalized.ttf", "NPC service title uses sanctuary font")
appearance.matchSanctuaryFont = false
SystemFont_World = nil
ns.WorldContext.Refresh("PLAYER_REGEN_DISABLED")
ns.RefreshAll()
equal(plateFrame.RPSNFullTitleText.shown, true, "NPC title remains below health bar in combat")
ns.WorldContext.Refresh("PLAYER_REGEN_ENABLED")
ns.RefreshAll()
equal(plateFrame.RPSNFullTitleText.shown, true, "NPC title restored after combat")
C_TooltipInfo.GetUnit = function() return {lines = {{type = 2}, {type = 47}}} end
unit.names = {nameplate1 = "Different NPC", target = "Different NPC"}
ns.RefreshAll()
equal(plateFrame.RPSNFullTitleText.shown, false, "missing subtitle clears previous title")
equal(plateFrame.RPSNFullTitleText.text, "", "old NPC service text cleared")
C_TooltipInfo = nil

-- Match the screenshot: sparse plate tooltip, fuller target tooltip, false
-- UnitIsUnit, and different interaction evidence on the two unit tokens.
UNIT_LEVEL_TEMPLATE = "Level %d"
UnitLevel = function() return 90 end
local currentGUID = "Creature-Orin"
unit.names = {nameplate1 = "Orin Straylight", target = "Orin Straylight"}
UnitGUID = function(token)
    if token == "nameplate1" then return currentGUID end
    if token == "target" then return "Creature-Orin" end
end
UnitIsInteractable = function(token) return token == "target" end
C_TooltipInfo = {GetUnit = function(token)
    local lines = {{type = 2, leftText = "Orin Straylight"}}
    if token == "target" then lines[#lines + 1] = {type = 0, leftText = "Voidforge Steward"} end
    lines[#lines + 1] = {type = 0, leftText = "Level 90"}
    return {lines = lines}
end}
ns.RefreshAll()
equal(plateFrame.RPSNFullTitleText.text, "<Voidforge Steward>", "sparse plate resolves target subtitle")
equal(plateFrame.RPSNFullTitleText.shown, true, "resolved service title visible")
equal(plateFrame.name.g, 1, "verified useful NPC bar name white")
equal(plateFrame.RPSNFullTitleText.g, 1, "verified useful NPC title white")
currentGUID = "Creature-Orin-Plate"
ns.RefreshAll()
equal(plateFrame.RPSNFullTitleText.text, "<Voidforge Steward>", "unmatched readable GUID resolves by NPC name")
equal(plateFrame.RPSNEntityFacts.npcTitleSource, "cached NPC name (GUID unmatched)", "weaker association reported")
UnitGUID = function(token) if token == "nameplate1" then return currentGUID end end
ns.RefreshAll()
equal(plateFrame.RPSNFullTitleText.text, "<Voidforge Steward>", "title survives target change")
currentGUID = "Creature-Other"
unit.names = {nameplate1 = "Different NPC"}
ns.RefreshAll()
equal(plateFrame.RPSNFullTitleText.shown, false, "token reuse clears service title")
equal(plateFrame.name.g, 1, "token reuse retains white bar name")

-- Hyperlink titles retain white text while the category colors the bar.
unit.names = {nameplate1 = "Orin Straylight", target = "Orin Straylight"}
C_TooltipInfo.GetHyperlink = function() return {lines = {
    {type = 2, leftText = "Orin Straylight"},
    {type = 0, leftText = "Voidforge Steward"}, {type = 47, leftText = "Level 90"},
}} end
ns.RefreshAll()
equal(plateFrame.RPSNFullTitleText.text, "<Voidforge Steward>", "hyperlink title displayed")
equal(plateFrame.RPSNEntityFacts.npcTitleSource, "GUID hyperlink tooltip", "hyperlink presentation source")
equal(plateFrame.name.g, 1, "hyperlink retains white bar name")
equal(plateFrame.RPSNFullTitleText.g, 1, "hyperlink title remains white")
local oldIsUnit, oldWidgetsOnly, oldCVar = UnitIsUnit, UnitNameplateShowsWidgetsOnly, C_CVar
UnitIsUnit = function(token, other) return token == "nameplate1" and other == "softinteract" end
UnitNameplateShowsWidgetsOnly = function(token) return token == "nameplate1" end
C_CVar = {GetCVar = function(key)
    equal(key, "nameplateShowFriendlyNpcs", "diagnostic reads friendly NPC CVar")
    return "1"
end}
output = {}
print = function(text) output[#output + 1] = text end
ns.DebugUnit("target")
local report = table.concat(output, "\n")
assert(report:find("nameplateShowFriendlyNpcs=1", 1, true), "friendly NPC visibility reported")
assert(report:find("Plate kind [nameplate1]: softinteract match: yes; widgets only: yes", 1, true), "special plate flags reported")
assert(report:find("NPC hyperlink [nameplate1]: title <Voidforge Steward>; result: title extracted", 1, true), "hyperlink result reported")
UnitNameplateShowsWidgetsOnly = function() error("restricted") end
output = {}
ns.DebugUnit("target")
assert(table.concat(output, "\n"):find("widgets only: restricted/unavailable", 1, true), "failed widget read explicit")
print = originalPrint
UnitIsUnit, UnitNameplateShowsWidgetsOnly, C_CVar = oldIsUnit, oldWidgetsOnly, oldCVar
C_TooltipInfo = nil

-- One NPC can have an ordinary plate plus a separate widget anchor.
ns.RestoreAll()
ns.TRP3 = nil
unit = {reaction = 5, interactable = true,
    names = {nameplate1 = "Orin Straylight", nameplate21 = "Orin Straylight"}}
local widgetFrame = Region()
widgetFrame.unit, widgetFrame.name = "nameplate21", Region()
widgetFrame.name:SetAlpha(0.7)
widgetFrame.healthBar, widgetFrame.HealthBarsContainer = Region(), Region()
widgetFrame.WidgetContainer = Region()
widgetFrame.RPSNFullTitleText, widgetFrame.RPSNInsideName = Region(), Region()
local widgetPlate = {UnitFrame = widgetFrame}
C_NamePlate.GetNamePlateForUnit = function(token) return token == "nameplate21" and widgetPlate or plate end
C_NamePlate.GetNamePlates = function() return {widgetPlate, plate} end
C_TooltipInfo = {GetUnit = function() return {lines = {
    {type = 2, leftText = "Orin Straylight"},
    {type = 0, leftText = "Voidforge Steward"}, {type = 47, leftText = "Level 90"},
}} end}
local widgetMode = true
UnitNameplateShowsWidgetsOnly = function(token) return token == "nameplate21" and widgetMode end
ns.RefreshAll()
equal(widgetFrame.name.alpha, 0, "widget actor name suppressed")
equal(widgetFrame.RPSNFullTitleText.shown, false, "widget title suppressed")
equal(widgetFrame.RPSNInsideName.shown, false, "widget inside name suppressed")
equal(widgetFrame.shown, true, "widget frame preserved")
equal(widgetFrame.WidgetContainer.shown, true, "widget container preserved")
equal(widgetFrame.healthBar.shown, true, "widget bar visibility untouched")
equal(widgetFrame.HealthBarsContainer.shown, true, "widget bar ancestor untouched")
equal(plateFrame.name.alpha, 1, "ordinary actor name remains visible")
equal(plateFrame.RPSNFullTitleText.text, "<Voidforge Steward>", "ordinary plate retains service title")
equal(plateFrame.RPSNFullTitleText.shown, true, "ordinary service title visible")
equal(plateFrame.name.g, 1, "ordinary uniform bar name remains white")
widgetFrame.name:SetAlpha(1)
widgetFrame.RPSNFullTitleText:Show()
Tick(0.25)
equal(widgetFrame.name.alpha, 0, "widget name drift repaired")
equal(widgetFrame.RPSNFullTitleText.shown, false, "widget title drift repaired")
widgetFrame.name:SetAlpha(1)
hooks[2].callback(widgetFrame)
equal(widgetFrame.name.alpha, 0, "Blizzard name hook preserves suppression")
categoryMode = "inactive"
ns.NameplatePresentation.ApplySimpleStyle(widgetFrame)
equal(widgetFrame.name.alpha, 0.7, "inactive restores original name opacity")
equal(widgetFrame.RPSNPresentation, nil, "inactive clears suppression decision")
categoryMode = "active"
ns.RefreshAll()
stylingEnabled = false
ns.RestoreAll()
equal(widgetFrame.name.alpha, 0.7, "disabled restores original name opacity")
equal(widgetFrame.WidgetContainer.shown, true, "restoration preserves widgets")
stylingEnabled = true
ns.RefreshAll()
widgetMode = false
Tick(0.25)
equal(widgetFrame.name.alpha, 1, "widget-to-ordinary transition restores name")
equal(widgetFrame.RPSNFullTitleText.shown, true, "widget-to-ordinary transition styles title")
widgetMode = true
Tick(0.25)
equal(widgetFrame.name.alpha, 0, "ordinary-to-widget transition suppresses text")
equal(widgetFrame.healthBar.shown, true, "transition restores Blizzard bar before suppression")
UnitNameplateShowsWidgetsOnly = function() error("restricted") end
ns.RefreshAll()
equal(widgetFrame.name.alpha, 1, "unavailable widget flag never confirms suppression")
UnitNameplateShowsWidgetsOnly = function() return {} end
ns.RefreshAll()
equal(widgetFrame.name.alpha, 1, "nonboolean widget flag never confirms suppression")
UnitNameplateShowsWidgetsOnly = function(token) return token == "nameplate21" end
ns.RefreshAll()
widgetFrame.unit = "nameplate22"
UnitNameplateShowsWidgetsOnly = function() return false end
ns.NameplatePresentation.ApplySimpleStyle(widgetFrame)
equal(widgetFrame.name.alpha, 1, "recycled widget frame becomes ordinary")
equal(widgetFrame.RPSNOriginalUnit, "nameplate22", "recycled frame captures new unit")
ns.RestoreAll()
UnitNameplateShowsWidgetsOnly = oldWidgetsOnly
C_TooltipInfo = nil

-- Native repair callbacks during a style write must not recursively restyle.
C_NamePlate.GetNamePlates = function() return {plate} end
C_NamePlate.GetNamePlateForUnit = function() return plate end
unit = {reaction = 3}
stylingEnabled, categoryMode, highlightEnabled = true, "active", false
appearance.namePlacement = "INSIDE"
plateFrame.RPSNInterruptibleHighlight = nil
local originalSetFont = plateFrame.name.SetFont
local fontWrites = 0
function plateFrame.name:SetFont(...)
    fontWrites = fontWrites + 1
    assert(fontWrites < 5, "recursive native font repair")
    originalSetFont(self, ...)
    hooks[2].callback(plateFrame)
end
for index = 1, 3 do
    categoryMode = "inactive"
    ns.RefreshAll()
    equal(plateFrame.RPSNState, nil, "hostile toggle restores native display")
    categoryMode, fontWrites = "active", 0
    ns.RefreshAll()
    equal(fontWrites, 1, "hostile toggle applies font once despite native callback")
    equal(plateFrame.RPSNInsideName.flags, "OUTLINE", "hostile toggle retains shadow rendering")
end
plateFrame.name.SetFont = function() error("simulated font write failure") end
local ok = pcall(ns.RefreshAll)
equal(ok, false, "style failure remains visible")
equal(plateFrame.RPSNApplyingStyle, nil, "style failure releases reentry guard")
plateFrame.name.SetFont = originalSetFont
ns.RefreshAll()
equal(plateFrame.RPSNInsideName.shown, true, "styling recovers after failed write")
local nativeFlags = plateFrame.RPSNOriginalPresentation.name.SetFont[3] or ""
appearance.useSlugRendering = true
equal(ns.NameplateText.RepairCachedName(plateFrame, ns.WorldContext.Get()), false, "ordinary font cache cannot undo Slug selection")
ns.RefreshAll()
equal(plateFrame.RPSNInsideName.flags, "SLUG,OUTLINE", "inside name uses Slug with thin outline")
assert(plateFrame.RPSNInsideName.RPSNUnderlayers == nil, "inside name has no glyph copies")
plateFrame.name:SetFont("drifted", 10, "")
ns.NameplateText.RepairCachedName(plateFrame, ns.WorldContext.Get())
equal(plateFrame.name.flags, "SLUG,OUTLINE", "cached repair preserves Slug")
appearance.namePlacement = "ABOVE"; ns.RefreshAll()
equal(plateFrame.name.flags, "SLUG,OUTLINE", "above-bar name uses thin Slug outline")
unit = {reaction = 5, interactable = true}; ns.RefreshAll()
equal(plateFrame.name.flags, "SLUG,OUTLINE", "floating name uses outlined Slug")
equal(plateFrame.RPSNFullTitleText.flags, "SLUG,OUTLINE", "title uses outlined Slug")
appearance.useSlugRendering = false; ns.RefreshAll()
equal(plateFrame.name.flags, "OUTLINE", "toggle off restores ordinary name outline")
ns.RestoreAll()
equal(plateFrame.name.flags, nativeFlags, "native name font flags restored after Slug")

local visited, largest = {}, 0
local function CheckUpvalues(fn)
    if visited[fn] then return end
    visited[fn] = true
    local count = 0
    while true do
        local name, value = debug.getupvalue(fn, count + 1)
        if not name then break end
        count = count + 1
        if type(value) == "function" then CheckUpvalues(value) end
    end
    if count > largest then largest = count end
    assert(count <= 60, "function exceeds WoW upvalue limit: " .. count)
end
for _, fn in ipairs({ ns.StateForUnit, ns.RefreshAll, ns.RestoreAll,
    ns.DebugUnit, events.scripts.OnEvent, events.scripts.OnUpdate,
    hooks[1].callback, hooks[2].callback }) do
    CheckUpvalues(fn)
end
-- Exercise the real timing wrappers, including runtime reconciliation.
local perfOutput, originalPrint = {}, print
print = function(message) perfOutput[#perfOutput + 1] = message end
local timer = 0
GetTimePreciseSec = function() timer = timer + 0.001; return timer end
ns.Profiler.Command("start")
ns.RefreshAll()
hooks[1].callback(plateFrame)
hooks[2].callback(plateFrame)
plateFrame.name.text = "Drifted"
Tick(0.25)
-- Label-chain drift needs only layout; structural invalidation still falls back.
plateFrame.RPSNNameStyle.healthTextSignature = "stale"
Tick(0.25)
plateFrame.RPSNNameStyle.presentation = nil
Tick(0.25)
ns.NameplateText.RepairCachedName(plateFrame, ns.WorldContext.Get())
events.scripts.OnEvent(events, "UNIT_NAME_UPDATE", "nameplate1")
events.scripts.OnUpdate(events, 0.01)
events.scripts.OnEvent(events, "PLAYER_TARGET_CHANGED")
events.scripts.OnUpdate(events, 0.01)
ns.Profiler.Command("stop")
ns.Profiler.Command("report")
print = originalPrint
for _, label in ipairs({"Full styling", "Classification", "NPC title lookup", "Text repair", "Runtime update", "Reconciliation",
    "Access assessment", "Health text layout", "Bar artwork", "Name/title styling", "Name drift check",
    "Name hook repair", "Health-color repair", "Data update"}) do
    local found
    for _, line in ipairs(perfOutput) do if line:find(label .. ":", 1, true) then found = true end end
    assert(found, "runtime instrumentation missing: " .. label)
end
for _, expected in ipairs({"Focused requests: health-color hook =", "Focused requests: name hook =",
    "Styling requests: reconciliation fallback =", "Styling outcomes: styled =",
    "Name drift: native name text =", "Name drift: health label layout =",
    "Reconciliation repairs: cached repair =", "Reconciliation repairs: full-style fallback =",
    "Queued unit events: UNIT_NAME_UPDATE =", "Queued global refresh: PLAYER_TARGET_CHANGED ="}) do
    local found
    for _, line in ipairs(perfOutput) do if line:find(expected, 1, true) then found = true end end
    assert(found, "runtime reason counter missing: " .. expected)
end
-- Restoration preserves native dynamic state rather than the initial snapshot.
ns.RestoreAll()
plateFrame.unit = "nameplate1"
plateFrame.IsProtected = nil
trp3Options = {}
for _, disableMaster in ipairs({false, true}) do
    for _, initiallyCasting in ipairs({false, true}) do
        stylingEnabled, categoryMode = true, "active"
        unit = {reaction = 3, names = {nameplate1 = "Before rename"}}
        plateFrame.name:SetText("Before rename")
        plateFrame.castBar = Region()
        plateFrame.castBar:SetShown(initiallyCasting)
        C_NamePlate.GetNamePlateForUnit = function() return plate end
        C_NamePlate.GetNamePlates = function() return {plate} end
        ns.RefreshAll()
        unit.names.nameplate1 = "After rename"
        events.scripts.OnEvent(events, "UNIT_NAME_UPDATE", "nameplate1")
        events.scripts.OnUpdate(events, 0.01)
        equal(plateFrame.name.text, "After rename", "name event updates styled name")
        plateFrame.castBar:SetShown(not initiallyCasting)
        if disableMaster then stylingEnabled = false; ns.RestoreAll()
        else categoryMode = "inactive"; ns.RefreshAll() end
        equal(plateFrame.castBar.shown, not initiallyCasting, "disable preserves current cast visibility")
        equal(plateFrame.name.text, "After rename", "disable restores current native unit name")
        Tick(0.25)
        equal(plateFrame.castBar.shown, not initiallyCasting, "cast state survives reconciliation")
    end
end
stylingEnabled, categoryMode = true, "active"

-- Reconciliation repairs visibility and readable text without full restyling.
ns.RestoreAll()
unit = {reaction = 3}
trp3Options = {useRoleplayingName = true}
ns.TRP3 = {GetDisplayInfo = function() return {roleplayingName = "Expected RP name"} end}
for _, placement in ipairs({"ABOVE", "INSIDE"}) do
    appearance.namePlacement = placement
    ns.RefreshAll()
    plateFrame.name:Hide()
    Tick(0.25)
    equal(plateFrame.name.shown, true, "native name visibility repaired")
    plateFrame.name:SetText("Overwritten native name")
    Tick(0.25)
    equal(plateFrame.name.text, "Expected RP name", "native text-only drift repaired")
    if placement == "INSIDE" then
        plateFrame.RPSNInsideName:SetText("Overwritten inside name")
        Tick(0.25)
        equal(plateFrame.RPSNInsideName.text, "Expected RP name", "inside text-only drift repaired")
    end
end
local secretName = setmetatable({}, {__tostring = function() error("secret name inspected") end})
local previousSecretCheck = issecretvalue
issecretvalue = function(value) return rawequal(value, secretName) end
plateFrame.name:SetText(secretName)
plateFrame.RPSNInsideName:SetText(secretName)
assert(not ns.NameplateText.CachedNameHasDrifted(plateFrame), "restricted text skipped")
plateFrame.RPSNNameStyle.text = secretName
plateFrame.name:SetText("Readable replacement")
plateFrame.RPSNInsideName:SetText("Readable replacement")
assert(not ns.NameplateText.CachedNameHasDrifted(plateFrame), "restricted expected text skipped")
issecretvalue = previousSecretCheck
ns.RefreshAll()

-- Missed cast-icon transitions are retried after region access returns.
ns.RestoreAll()
plateFrame.castBar = Region()
plateFrame.castBar.Icon = Region()
plateFrame.RPSNInterruptibleHighlight = nil
local retryOverlay = ns.CastHighlight.EnsureInterruptibleHighlight(plateFrame).frame
highlightEnabled = true
local iconBlocked = false
plateFrame.castBar.Icon.IsForbidden = function() return iconBlocked end
ns.RefreshAll()
local retryIconHook
for _, hook in ipairs(hooks) do
    if hook.name == plateFrame.castBar.Icon then retryIconHook = hook.callback end
end
assert(retryIconHook)
for _, shown in ipairs({false, true}) do
    iconBlocked = true
    plateFrame.castBar.Icon:SetShown(shown)
    retryIconHook(plateFrame.castBar.Icon, shown)
    Tick(0.25)
    equal(retryOverlay.shown, not shown, "restricted cast callback defers writes")
    iconBlocked = false
    Tick(0.25)
    equal(retryOverlay.shown, shown, "cast retry reads current icon visibility")
end
iconBlocked = true
retryIconHook(plateFrame.castBar.Icon, false)
stylingEnabled = false
ns.RestoreAll()
iconBlocked = false
Tick(0.25)
equal(retryOverlay.shown, false, "pending cast retry cannot revive disabled styling")
stylingEnabled = true

-- Region replacement starts from the replacement's own native geometry.
ns.RestoreAll()
stylingEnabled, categoryMode = true, "active"
unit, trp3Options = {reaction = 3}, {}
appearance.namePlacement, appearance.nameSize, appearance.healthBarWidth = "INSIDE", 21, 150
plateFrame.healthBar, plateFrame.HealthBarsContainer = Region(), Region()
ns.RefreshAll()
local retiredBar, retiredContainer = plateFrame.healthBar, plateFrame.HealthBarsContainer
local replacementBar, replacementContainer = Region(), Region()
replacementBar:SetWidth(200); replacementBar:SetHeight(30)
replacementBar:SetStatusBarColor(0.1, 0.2, 0.3)
replacementContainer:SetWidth(220); replacementContainer:SetHeight(30)
plateFrame.healthBar, plateFrame.HealthBarsContainer = replacementBar, replacementContainer
ns.RefreshAll()
equal(replacementBar.width, 300, "replacement scales its own native width")
equal(replacementContainer.width, 330, "replacement container scales its own native width")
equal(retiredBar.width, 140, "retired bar width restored")
equal(retiredBar.height, 20, "retired bar height restored")
equal(retiredContainer.width, 140, "retired container width restored")
ns.RestoreAll()
equal(replacementBar.width, 200, "replacement native width restored")
equal(replacementBar.height, 30, "replacement native height restored")
equal(replacementContainer.width, 220, "replacement container width restored")
equal(replacementContainer.height, 30, "replacement container height restored")
equal(replacementBar.barG, 0.2, "replacement native color restored")

-- Container-only replacement must invalidate cached repair before any writes.
ns.RefreshAll()
local containerOnly = Region()
containerOnly:SetWidth(240); containerOnly:SetHeight(40); containerOnly:Hide()
plateFrame.HealthBarsContainer = containerOnly
Tick(0.25)
equal(containerOnly.width, 360, "container-only replacement uses its own width")
equal(containerOnly.height, 40, "container-only replacement keeps taller native height")
equal(replacementContainer.width, 220, "retired container restored during reconciliation")
ns.RestoreAll()
equal(containerOnly.width, 240, "container-only native width restored")
equal(containerOnly.shown, false, "container-only native visibility restored")

-- Retired restricted regions stay untouched and are released once access returns.
ns.RefreshAll()
local inaccessibleOldBar = plateFrame.healthBar
local retiredBlocked = true
inaccessibleOldBar.IsForbidden = function() return retiredBlocked end
local accessibleNewBar = Region()
accessibleNewBar:SetWidth(180); accessibleNewBar:SetHeight(25)
plateFrame.healthBar = accessibleNewBar
ns.RefreshAll()
equal(accessibleNewBar.width, 180, "restricted retired bar defers replacement styling")
retiredBlocked = false
Tick(0.25)
equal(accessibleNewBar.width, 270, "replacement styled when retired bar accessible")
ns.RestoreAll()
equal(accessibleNewBar.width, 180, "replacement width restores after access retry")

-- Target/mouseover highlights remain native through repairs and both disable paths.
for _, disableMaster in ipairs({false, true}) do
    for _, initiallyShown in ipairs({false, true}) do
        ns.RestoreAll()
        stylingEnabled, categoryMode = true, "active"
        unit = {reaction = 3}
        plateFrame.selectionHighlight = Region()
        plateFrame.selectionHighlight:SetShown(initiallyShown)
        ns.RefreshAll()
        equal(plateFrame.selectionHighlight.shown, initiallyShown, "styling preserves native selection highlight")
        ns.NameplatePresentation.RepairHealthColor(plateFrame)
        ns.NameplatePresentation.RepairName(plateFrame)
        equal(plateFrame.selectionHighlight.shown, initiallyShown, "repairs preserve native selection highlight")
        plateFrame.selectionHighlight:SetShown(not initiallyShown)
        ns.NameplatePresentation.RepairHealthColor(plateFrame)
        ns.NameplatePresentation.RepairName(plateFrame)
        equal(plateFrame.selectionHighlight.shown, not initiallyShown, "repairs preserve changed native selection")
        if disableMaster then stylingEnabled = false; ns.RestoreAll()
        else categoryMode = "inactive"; ns.RefreshAll() end
        equal(plateFrame.selectionHighlight.shown, not initiallyShown, "disable preserves live selection visibility")
    end
end
stylingEnabled, categoryMode = true, "active"

-- Native classification can hide a retained atlas after reuse or raid marking.
for _, disableMaster in ipairs({false, true}) do
    ns.RestoreAll()
    stylingEnabled, categoryMode = true, "active"
    unit = {reaction = 3}
    plateFrame.ClassificationFrame, plateFrame.classificationIndicator = Region(), Region()
    plateFrame.ClassificationFrame.classificationIndicator = plateFrame.classificationIndicator
    plateFrame.ClassificationFrame.classificationAtlasElement = nil
    plateFrame.classificationIndicator.atlas = "nameplates-icon-elite-gold"
    plateFrame.ClassificationFrame:Hide()
    ns.RefreshAll()
    ns.NameplatePresentation.RepairHealthColor(plateFrame)
    ns.NameplatePresentation.RepairName(plateFrame)
    equal(plateFrame.ClassificationFrame.shown, false, "styling cannot expose retained classification atlas")
    plateFrame.ClassificationFrame:Show()
    plateFrame.classificationIndicator:Hide()
    ns.NameplatePresentation.RepairName(plateFrame)
    equal(plateFrame.ClassificationFrame.shown, true, "native classification show preserved")
    equal(plateFrame.classificationIndicator.shown, false, "native classification icon hide preserved")
    if disableMaster then stylingEnabled = false; ns.RestoreAll()
    else categoryMode = "inactive"; ns.RefreshAll() end
    equal(plateFrame.ClassificationFrame.shown, true, "disable preserves changed native classification")
    equal(plateFrame.classificationIndicator.shown, false, "disable preserves changed native icon visibility")
end
stylingEnabled, categoryMode = true, "active"

-- Use the native nested layout for title transitions and cast decisions.
ns.RestoreAll()
stylingEnabled, categoryMode, highlightEnabled = true, "active", true
unit = {player = true, faction = "Alliance", reaction = 5}
trp3Options = {showFullTitle = true}
ns.TRP3 = {GetDisplayInfo = function() return {fullTitle = "Visible RP title"} end}
local nestedCast = plateFrame.castBar
nestedCast.Icon:SetShown(true)
plateFrame.CastBarsContainer = Region()
plateFrame.CastBarsContainer.castBar = nestedCast
plateFrame.castBar, plateFrame.CastBar = nil, nil
nestedCast:Show()
ns.RefreshAll()
equal(plateFrame.RPSNPresentation.showCastBar, true, "native nested cast included in presentation")
equal(plateFrame.RPSNFullTitleText.shown, false, "native nested cast hides long title")
equal(plateFrame.RPSNInterruptibleHighlight.castBar, nestedCast, "highlight uses native nested cast")
equal(plateFrame.RPSNInterruptibleHighlight.frame.shown, true, "nested interruptible cast permits highlight")
events.scripts.OnEvent(events, "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "nameplate1")
events.scripts.OnUpdate(events, 0.01)
equal(plateFrame.RPSNInterruptibleHighlight.frame.shown, false, "not-interruptible event hides highlight")
events.scripts.OnEvent(events, "UNIT_SPELLCAST_INTERRUPTIBLE", "nameplate1")
events.scripts.OnUpdate(events, 0.01)
equal(plateFrame.RPSNInterruptibleHighlight.frame.shown, true, "interruptible event restores highlight")
nestedCast:Hide()
equal(plateFrame.RPSNFullTitleText.shown, true, "nested cast end restores title without restyling")
nestedCast:Show()
equal(plateFrame.RPSNFullTitleText.shown, false, "nested channel start hides title")
stylingEnabled = false; ns.RestoreAll()
equal(nestedCast.shown, true, "disable preserves native nested cast visibility")
equal(plateFrame.RPSNInterruptibleHighlight.frame.shown, false, "disable hides nested cast effect")
nestedCast:Hide()
equal(plateFrame.RPSNFullTitleText.shown, false, "nested cast end cannot revive disabled title")

-- Coordinate every displayed health label with threat and the inside name.
ns.RestoreAll()
stylingEnabled, categoryMode = true, "active"
unit, ns.TRP3 = {reaction = 3}, nil
local healthLabels = {}
for _, key in ipairs({"LeftText", "RightText", "Text"}) do
    local label = Region()
    label:SetFont("NativeHealthFont", 14, "")
    label:SetText(key == "LeftText" and "75%" or "123k")
    label:SetPoint("RIGHT", plateFrame.healthBar, "RIGHT", -4, 0)
    healthLabels[key], plateFrame.healthBar[key] = label, label
end
for _, placement in ipairs({"INSIDE", "ABOVE"}) do
    for _, showThreat in ipairs({false, true}) do
        for _, visible in ipairs({{}, {"Text"}, {"LeftText"}, {"RightText"}, {"LeftText", "RightText"}}) do
            ns.RestoreAll()
            local selected = {}
            for _, key in ipairs(visible) do selected[key] = true end
            for key, label in pairs(healthLabels) do label:SetShown(selected[key] == true) end
            appearance.namePlacement, threatEnabled, threatPercent = placement, showThreat, 100
            ns.RefreshAll()
            local preceding = showThreat and plateFrame.RPSNThreatText or plateFrame.healthBar
            if showThreat then
                equal(preceding.points[1][2], plateFrame.healthBar, "threat keeps bar right edge")
                equal(preceding.points[1][4], -3, "threat keeps right padding")
            end
            for _, key in ipairs({"LeftText", "RightText", "Text"}) do
                local label = healthLabels[key]
                if selected[key] then
                    equal(label.points[1][2], preceding, "health labels form a nonoverlapping chain")
                    equal(label.points[1][3], preceding == plateFrame.healthBar and "RIGHT" or "LEFT", "health labels anchor to preceding left edge")
                    equal(label.points[1][4], -3, "health labels leave three-unit gaps")
                    equal(label.points[1][5], preceding == plateFrame.healthBar and -0.5 or 0, "health labels share baseline")
                    preceding = label
                end
                equal(label.shown, selected[key] == true, "native health visibility preserved")
            end
            if placement == "INSIDE" then
                equal(plateFrame.RPSNInsideName.points[2][2], preceding, "name reserves all health and threat text")
            end
            ns.RestoreAll()
            for _, label in pairs(healthLabels) do
                equal(label.points[1][2], plateFrame.healthBar, "native health anchor restored")
                equal(label.points[1][4], -4, "native health horizontal offset restored")
                equal(label.points[1][5], 0, "native health vertical offset restored")
            end
        end
    end
end
-- A health-value visibility change can leave the same leftmost label in place.
for _, label in pairs(healthLabels) do label:Show() end
appearance.namePlacement, threatEnabled = "INSIDE", true
ns.RefreshAll()
healthLabels.RightText:Hide()
Tick(0.25)
equal(healthLabels.Text.points[1][2], healthLabels.LeftText, "reconciliation removes hidden middle label")
healthLabels.RightText:Show()
Tick(0.25)
equal(healthLabels.Text.points[1][2], healthLabels.RightText, "reconciliation reserves newly shown middle label")
local nativeLabelBlocked = true
healthLabels.RightText.IsForbidden = function() return nativeLabelBlocked end
stylingEnabled = false; ns.RestoreAll()
assert(ns.NameplateRestoration.IsPending(plateFrame), "inaccessible health label defers restoration")
nativeLabelBlocked = false
Tick(0.25)
equal(healthLabels.RightText.points[1][4], -4, "health-label restoration retries after access returns")

-- Unknown native visibility reserves space without inspecting opaque health text.
stylingEnabled = true
for _, label in pairs(healthLabels) do label:Hide() end
local opaqueHealth = setmetatable({}, {__tostring = function() error("opaque health inspected") end})
local oldSecretCheck, oldShown = issecretvalue, healthLabels.LeftText.IsShown
issecretvalue = function(value) return rawequal(value, opaqueHealth) end
healthLabels.LeftText:SetText(opaqueHealth)
healthLabels.LeftText.IsShown = function() return opaqueHealth end
ns.RefreshAll()
equal(plateFrame.RPSNInsideName.points[2][2], healthLabels.LeftText, "unknown health visibility conservatively reserves name space")
healthLabels.LeftText.IsShown, issecretvalue = oldShown, oldSecretCheck
ns.RestoreAll()

-- Each category's disabled bar compacts the title under the floating name.
categoryMode, stylingEnabled = "active", true
unit = {reaction = 3, canAttack = true}
ns.TRP3 = {GetDisplayInfo = function() return {fullTitle = "Compact title"} end}
trp3Options.showFullTitle = true
local showBar = false
ns.GetHealthBarEnabled = function() return showBar end
local cast = ns.NameplateFrames.GetCastBar(plateFrame)
if cast then cast:Hide() end
for _, placement in ipairs({"ABOVE", "INSIDE"}) do
    for _, size in ipairs({8, 18, 31}) do
        appearance.namePlacement, appearance.nameSize = placement, size
        showBar = false
        ns.RefreshAll()
        equal(plateFrame.healthBar.shown, false, "bar off hides native health bar")
        equal(plateFrame.name.alpha, 1, "bar off keeps floating name visible")
        equal(plateFrame.RPSNPresentation.nameOnly, true, "bar off uses colored floating name")
        equal(plateFrame.RPSNInsideName.shown, false, "bar off removes inside copy")
        equal(plateFrame.RPSNFullTitleText.points[1][2], plateFrame.name, "title directly below name")
        equal(plateFrame.RPSNFullTitleText.points[1][5], -1, "one-unit title gap")
        equal(plateFrame.RPSNFullTitleText.size, size - 2, "title exactly two smaller")
        equal(plateFrame.RPSNFullTitleText.shown, true, "bar off displays title")
        equal(plateFrame.RPSNThreatText.shown, false, "bar off hides threat")
        plateFrame.healthBar:Show()
        Tick(0.25)
        equal(plateFrame.healthBar.shown, false, "reconciliation repairs native reshow")
        showBar = true
        ns.RefreshAll()
        equal(plateFrame.healthBar.shown, true, "bar on restores health")
        equal(plateFrame.RPSNFullTitleText.points[1][2], plateFrame.healthBar, "bar on restores title anchor")
    end
end
ns.RestoreAll()

-- Gradient toggles preserve one outlined label, without health-dependent text work.
assert(loadfile("RPSimpleNameplates/HealthGradient.lua"))("RPSimpleNameplates", ns)
local gradients = true
ns.GetGradientOpacity = function() return gradients and 100 or 0 end
function CreateColor(r, g, b, a) return {r=r, g=g, b=b, a=a} end
local function GradientTexture()
    local texture = Region()
    function texture:SetColorTexture(...) self.color = {...} end
    function texture:SetTexture(value) self.texture = value end
    function texture:GetTexture() return self.texture end
    function texture:SetTexCoord() end
    function texture:SetAllPoints(other) self.allPoints = other end
    function texture:SetGradient(...) self.gradient = {...} end
    function texture:AddMaskTexture(mask) self.mask = mask end
    return texture
end
local bar = ns.NameplateFrames.GetHealthBar(plateFrame)
bar.barTexture = GradientTexture()
bar.barTexture:SetTexture("native-fill")
function bar:CreateTexture() return GradientTexture() end
function bar:CreateMaskTexture() return GradientTexture() end
function UnitHealthPercent() error("retired health threshold must not be queried") end
appearance.namePlacement, threatEnabled, threatPercent = "INSIDE", true, 255
ns.RefreshAll()
assert(bar.RPSNHealthGradient.shown)
assert(plateFrame.RPSNInsideName.flags == "OUTLINE" and plateFrame.RPSNInsideName.RPSNUnderlayers == nil)
Tick(0.25)
gradients = false
ns.RefreshAll()
assert(not bar.RPSNHealthGradient.shown)
assert(plateFrame.RPSNInsideName.flags == "OUTLINE" and plateFrame.RPSNInsideName.RPSNUnderlayers == nil)
gradients = true
ns.RefreshAll()
ns.RestoreAll()
assert(not bar.RPSNHealthGradient.shown, "global restoration removes gradient")

-- Use fresh interaction/title observations, independent of earlier cache fixtures.
UnitIsInteractable = function() return unit.interactable or false end
ns.NPCTitles.GetTitle = function() return "<Background subtitle>" end
local dimBackground = false
ns.GetDimBackgroundNames = function() return dimBackground end
gradients = false
unit = {reaction = 5}
for _, barEnabled in ipairs({true, false}) do
    showBar = barEnabled
    for _, placement in ipairs({"ABOVE", "INSIDE"}) do
        appearance.namePlacement = placement
        for _, enabled in ipairs({false, true}) do
            dimBackground = enabled
            ns.RefreshAll()
            equal(plateFrame.RPSNState, "useless", "background classification")
            local expected = enabled and 153 / 255 or 1
            equal(plateFrame.name.r, expected, "background native name shade")
            equal(plateFrame.name.g, expected, "background native name green")
            equal(plateFrame.name.b, expected, "background native name blue")
            equal(plateFrame.RPSNFullTitleText.r, expected, "background title matches name red")
            equal(plateFrame.RPSNFullTitleText.g, expected, "background title matches name green")
            equal(plateFrame.RPSNFullTitleText.b, expected, "background title matches name blue")
            if barEnabled and placement == "INSIDE" then
                equal(plateFrame.RPSNInsideName.r, expected, "background inside name shade")
            end
            plateFrame.name:SetTextColor(0, 0, 0)
            ns.NameplateText.RepairCachedName(plateFrame, ns.WorldContext.Get())
            equal(plateFrame.name.r, expected, "cached repair preserves dimming")
        end
    end
end
showBar = true; unit = {reaction = 5, interactable = true}
ns.RefreshAll()
equal(plateFrame.name.r, 1, "interactive NPC name stays white")
equal(plateFrame.RPSNFullTitleText.r, 1, "interactive NPC title stays white")
ns.NPCTitles.GetTitle = function() return nil end

-- Native one-line title layout is constrained even when the bar is hidden.
ns.TRP3 = {GetDisplayInfo = function() return {fullTitle = "A very long roleplaying title with wide glyphs WWW and accented é characters"} end}
trp3Options.showFullTitle = true
for _, enabled in ipairs({true, false}) do
    showBar = enabled
    appearance.healthBarWidth = 100
    ns.RefreshAll()
    local title = plateFrame.RPSNFullTitleText
    local healthBar = ns.NameplateFrames.GetHealthBar(plateFrame)
    equal(title.width, healthBar.width, "title uses bar width with either visibility")
    equal(title.wordWrap, false, "title cannot wrap")
    equal(title.maxLines, 1, "title remains single line")
    local source = title.text
    appearance.healthBarWidth = 120; ns.RefreshAll()
    equal(title.width, healthBar.width, "wider bar updates title constraint")
    equal(title.text, source, "constraint retains source title for native truncation")
    title:SetWidth(999)
    assert(ns.NameplateText.CachedNameHasDrifted(plateFrame, ns.WorldContext.Get()))
    ns.NameplateText.RepairCachedName(plateFrame, ns.WorldContext.Get())
    equal(title.width, healthBar.width, "cached repair restores title width")
end
appearance.healthBarWidth = 100; ns.RefreshAll()
local title = plateFrame.RPSNFullTitleText
local healthBar = ns.NameplateFrames.GetHealthBar(plateFrame)
healthBar:SetWidth(73)
assert(ns.NameplateText.CachedNameHasDrifted(plateFrame, ns.WorldContext.Get()))
ns.NameplateText.RepairCachedName(plateFrame, ns.WorldContext.Get())
equal(title.width, 73, "native bar resizing updates title without full restyling")

-- Phase 2: verify actual work counts and behavior across focused hooks/events.
do
local function CheckFocusedUpdates()
    stylingEnabled, categoryMode, showBar, gradients = true, "active", true, false
    appearance.namePlacement, appearance.nameSize, appearance.healthBarWidth = "INSIDE", 18, 120
    unit = {player = true, faction = "Alliance", reaction = 5, names = {nameplate1 = "Native Focus"}}
    local identity, rpName = "Player-Focus-1", "RP Focus"
    UnitGUID = function() return identity end
    UnitNameplateShowsWidgetsOnly = function() return false end
    local rp = {GetDisplayInfo = function() return {roleplayingName = rpName, fullTitle = "Focus title"} end}
    ns.TRP3, trp3Options = rp, {useRoleplayingName = true, showFullTitle = true}
    threatEnabled, threatPercent = true, nil
    plateFrame.unit = "nameplate1"
    C_NamePlate.GetNamePlateForUnit = function() return plate end
    C_NamePlate.GetNamePlates = function() return {plate} end
    ns.RefreshAll()
    Tick(0.25)
    local function Measure(callback)
        local lines, savedPrint = {}, print
        print = function(line) lines[#lines + 1] = line end
        ns.Profiler.Command("start")
        local ok, err = pcall(callback)
        ns.Profiler.Command("stop"); ns.Profiler.Command("report")
        print = savedPrint
        if not ok then error(err) end
        return table.concat(lines, "\n")
    end
    local function NoWork(report, labels)
        for _, label in ipairs(labels) do
            assert(not report:find(label .. ":", 1, true), "unrelated work executed: " .. label)
        end
    end
    local function Calls(report, label, count)
        assert(report:find(label .. ": " .. count .. " calls;", 1, true), "unexpected calls: " .. label)
    end
    local report = Measure(function()
        plateFrame.name:SetText("Native Focus")
        plateFrame.name:SetTextColor(0, 0, 0)
        hooks[2].callback(plateFrame)
        plateFrame.healthBar:SetStatusBarColor(0, 0, 0)
        hooks[1].callback(plateFrame)
    end)
    NoWork(report, {"Full styling", "Classification", "NPC title lookup", "Bar artwork", "Name/title styling", "Health text layout"})
    Calls(report, "Name hook repair", 1); Calls(report, "Health-color repair", 1)
    equal(plateFrame.name.text, "RP Focus", "name hook restores cached RP name")
    equal(plateFrame.RPSNInsideName.text, "RP Focus", "inside RP name retained")
    equal(plateFrame.name.alpha, 0, "focused name hook keeps native name concealed")
    equal(plateFrame.healthBar.barR, 1, "health hook repairs category color")

    -- Native bar callbacks during focused writes must survive the style guard.
    local focusedSetFont = plateFrame.name.SetFont
    plateFrame.name.SetFont = function(self, ...)
        focusedSetFont(self, ...)
        for _, callback in ipairs(plateFrame.healthBar.scriptHooks.OnShow) do callback(plateFrame.healthBar) end
        assert(plateFrame.RPSNArtworkPending, "native artwork callback retained during focused write")
    end
    report = Measure(function() hooks[2].callback(plateFrame) end)
    Calls(report, "Bar artwork", 1)
    NoWork(report, {"Full styling", "Classification", "Name/title styling"})
    assert(not plateFrame.RPSNArtworkPending, "deferred native artwork callback serviced after focused write")
    plateFrame.name.SetFont = focusedSetFont

    -- Real native source changes refresh names/titles, without bar artwork.
    unit.names.nameplate1, rpName = "Renamed Native", "Renamed RP"
    report = Measure(function() hooks[2].callback(plateFrame) end)
    NoWork(report, {"Full styling", "Bar artwork"})
    equal(plateFrame.RPSNInsideName.text, "Renamed RP", "changed source updates RP display")

    -- Threat presence changes layout once; percent changes keep fonts/layout.
    threatPercent = 55
    report = Measure(function()
        events.scripts.OnEvent(events, "UNIT_THREAT_LIST_UPDATE", "nameplate1")
        events.scripts.OnEvent(events, "UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
        events.scripts.OnUpdate(events, 0.001)
    end)
    Calls(report, "Data update", 1); Calls(report, "Classification", 1); Calls(report, "Name layout update", 1)
    NoWork(report, {"Full styling", "Bar artwork", "Name/title styling"})
    equal(plateFrame.RPSNThreatText.text, "55%", "threat event updates percentage")
    equal(plateFrame.RPSNInsideName.points[2][2], plateFrame.RPSNThreatText, "threat presence reserves name space")
    local fontWrites, setFont = 0, plateFrame.RPSNThreatText.SetFont
    plateFrame.RPSNThreatText.SetFont = function(self, ...)
        fontWrites = fontWrites + 1; return setFont(self, ...)
    end
    threatPercent = 65
    report = Measure(function()
        events.scripts.OnEvent(events, "UNIT_THREAT_LIST_UPDATE", "nameplate1")
        events.scripts.OnUpdate(events, 0.001)
    end)
    equal(fontWrites, 0, "value-only threat update leaves font unchanged")
    NoWork(report, {"Full styling", "Bar artwork", "Name/title styling", "Name layout update", "Health text layout"})
    threatPercent = nil
    events.scripts.OnEvent(events, "UNIT_THREAT_LIST_UPDATE", "nameplate1")
    events.scripts.OnUpdate(events, 0.001)
    equal(plateFrame.RPSNInsideName.points[2][2], plateFrame.healthBar, "missing threat releases name space")
    plateFrame.RPSNThreatText.SetFont = setFont

    -- A queued global classification refresh must not discard a unit name event.
    rpName, threatPercent = "Merged RP", 75
    report = Measure(function()
        events.scripts.OnEvent(events, "UNIT_NAME_UPDATE", "nameplate1")
        events.scripts.OnEvent(events, "PLAYER_TARGET_CHANGED")
        events.scripts.OnEvent(events, "UNIT_THREAT_LIST_UPDATE", "nameplate1")
        events.scripts.OnUpdate(events, 0.001)
    end)
    Calls(report, "Data update", 1); Calls(report, "Classification", 1); Calls(report, "Name/title styling", 1)
    NoWork(report, {"Full styling", "Bar artwork"})
    equal(plateFrame.RPSNInsideName.text, "Merged RP", "coalescing keeps name request")
    equal(plateFrame.RPSNThreatText.text, "75%", "coalescing keeps threat request")

    unit.aggro = true
    report = Measure(function()
        events.scripts.OnEvent(events, "UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
        events.scripts.OnUpdate(events, 0.001)
    end)
    NoWork(report, {"Full styling", "Bar artwork"})
    equal(plateFrame.RPSNState, "attacking", "classification updates category without complete styling")
    equal(plateFrame.RPSNNameStyle.presentation, plateFrame.RPSNPresentation, "focused update retains coherent cache")

    report = Measure(function()
        events.scripts.OnEvent(events, "UNIT_SPELLCAST_START", "nameplate1")
        events.scripts.OnEvent(events, "UNIT_SPELLCAST_INTERRUPTIBLE", "nameplate1")
        events.scripts.OnUpdate(events, 0.001)
    end)
    Calls(report, "Data update", 1)
    NoWork(report, {"Full styling", "Classification", "NPC title lookup", "Bar artwork", "Name/title styling", "Health text layout"})

    -- Requests queued by a synchronous font callback survive the detached batch.
    local nativeSetFont, once = plateFrame.name.SetFont, true
    plateFrame.name.SetFont = function(self, ...)
        nativeSetFont(self, ...)
        if once then once = false; events.scripts.OnEvent(events, "UNIT_NAME_UPDATE", "nameplate1") end
    end
    events.scripts.OnEvent(events, "UNIT_NAME_UPDATE", "nameplate1")
    events.scripts.OnUpdate(events, 0.001)
    report = Measure(function() events.scripts.OnUpdate(events, 0.001) end)
    Calls(report, "Data update", 1); Calls(report, "Name/title styling", 1)
    plateFrame.name.SetFont = nativeSetFont

    -- Inaccessible unit lookups retain merged work until access returns.
    C_NamePlate.GetNamePlateForUnit = function() return nil end
    rpName = "Deferred RP"
    events.scripts.OnEvent(events, "UNIT_NAME_UPDATE", "nameplate1")
    events.scripts.OnUpdate(events, 0.001)
    events.scripts.OnEvent(events, "UNIT_SPELLCAST_STOP", "nameplate1")
    events.scripts.OnUpdate(events, 0.001)
    C_NamePlate.GetNamePlateForUnit = function() return plate end
    report = Measure(function() Tick(0.25) end)
    Calls(report, "Data update", 1)
    equal(plateFrame.RPSNInsideName.text, "Deferred RP", "pending updates keep name work")

    -- Actual TRP3 callback uses the queued name path, not complete styling.
    assert(loadfile("RPSimpleNameplates/TRP3.lua"))("RPSimpleNameplates", ns)
    local refreshRP = ns.TRP3.Refresh
    ns.TRP3, rpName = rp, "Callback RP"
    report = Measure(function() refreshRP(); events.scripts.OnUpdate(events, 0.001) end)
    Calls(report, "Data update", 1); Calls(report, "Name/title styling", 1)
    NoWork(report, {"Full styling", "Classification", "Bar artwork"})
    equal(plateFrame.RPSNInsideName.text, "Callback RP", "TRP3 callback updates content")

    -- Invalid settings and identity use safe full-styling fallbacks.
    appearance.nameSize = 20
    report = Measure(function() hooks[2].callback(plateFrame) end)
    Calls(report, "Full styling", 1)
    equal(plateFrame.RPSNInsideName.size, 20, "settings invalidate focused cache")
    identity = "Player-Recycled-Same-Token"
    report = Measure(function() hooks[1].callback(plateFrame) end)
    Calls(report, "Full styling", 1)
    equal(plateFrame.RPSNEntityFacts.guid, identity, "readable GUID detects same-token recycling")

    -- Replaced native names restore the retired region and capture a new baseline.
    local retired = plateFrame.name
    plateFrame.name = Region()
    plateFrame.name:SetFont("Replacement native", 11, "THICKOUTLINE")
    plateFrame.name:SetAlpha(0.6)
    report = Measure(function() hooks[2].callback(plateFrame) end)
    Calls(report, "Full styling", 1)
    equal(plateFrame.RPSNOriginalName, plateFrame.name, "replacement name gets its own baseline")
    assert(retired.alpha ~= 0, "retired native name no longer concealed")
    ns.RestoreAll()
    equal(plateFrame.name.font, "Replacement native", "replacement native font restored")
    equal(plateFrame.name.flags, "THICKOUTLINE", "replacement native outline restored")
    equal(plateFrame.name.alpha, 0.6, "replacement alpha preserved before first style")
    ns.RefreshAll()

    local failure = {}
    plateFrame.name.SetFont = function() error(failure) end
    local ok, err = pcall(hooks[2].callback, plateFrame)
    assert(not ok and err == failure, "focused errors retain the original object")
    assert(plateFrame.RPSNApplyingStyle == nil, "failed focused write releases guard")
    plateFrame.name.SetFont = nativeSetFont
    hooks[2].callback(plateFrame)

    -- Synchronous health-color callbacks cannot recurse through the repair.
    local nativeColor, colorWrites = plateFrame.healthBar.SetStatusBarColor, 0
    plateFrame.healthBar.SetStatusBarColor = function(self, ...)
        colorWrites = colorWrites + 1
        assert(colorWrites < 3, "focused color repair recursed")
        nativeColor(self, ...)
        hooks[1].callback(plateFrame)
    end
    report = Measure(function() hooks[1].callback(plateFrame) end)
    equal(colorWrites, 1, "focused color reentry guard prevents duplicate writes")
    assert(report:find("Focused outcomes: guarded = 1", 1, true))
    plateFrame.healthBar.SetStatusBarColor = nativeColor

    -- A category-specific bar change still requires a complete new layout.
    local oldBarPreference = ns.GetHealthBarEnabled
    ns.GetHealthBarEnabled = function(state) return state ~= "attacking" end
    unit.aggro = false; ns.RefreshAll()
    unit.aggro = true
    report = Measure(function()
        events.scripts.OnEvent(events, "UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
        events.scripts.OnUpdate(events, 0.001)
    end)
    Calls(report, "Full styling", 1)
    equal(plateFrame.healthBar.shown, false, "changed category preference switches to name-only")
    equal(plateFrame.RPSNInsideName.shown, false, "structural change hides inside overlay")
    ns.GetHealthBarEnabled = oldBarPreference
    ns.RefreshAll()

    -- Removal discards queued work before the same frame gains a new owner.
    events.scripts.OnEvent(events, "UNIT_NAME_UPDATE", "nameplate1")
    events.scripts.OnEvent(events, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
    plateFrame.unit = "nameplate2"
    rpName = "New owner"
    events.scripts.OnEvent(events, "NAME_PLATE_UNIT_ADDED", "nameplate2")
    report = Measure(function() events.scripts.OnUpdate(events, 0.001) end)
    NoWork(report, {"Data update", "Full styling", "Name/title styling"})
    equal(plateFrame.RPSNOriginalUnit, "nameplate2", "recycled plate retains current assignment")
    equal(plateFrame.RPSNInsideName.text, "New owner", "removed-unit work cannot overwrite new name")
end
CheckFocusedUpdates()
end

-- Phase 3: assert actual reads/writes, not just the repair's return value.
do
local function CheckSelectiveReconciliation()
    stylingEnabled, categoryMode, showBar, gradients = true, "active", true, false
    appearance.namePlacement, appearance.nameSize, appearance.healthBarWidth = "INSIDE", 18, 120
    threatEnabled, threatPercent = false, nil
    unit = {player = true, faction = "Alliance", reaction = 5, names = {nameplate1 = "Selective Native"}}
    plateFrame.unit = "nameplate1"
    UnitGUID = function() return "Player-Selective" end
    ns.TRP3 = {GetDisplayInfo = function() return {roleplayingName = "Selective RP", fullTitle = "Selective title"} end}
    trp3Options = {useRoleplayingName = true, showFullTitle = true}
    plateFrame.castBar = Region()
    plateFrame.castBar.shown = false
    ns.RefreshAll()
    Tick(0.25)
    local context = ns.WorldContext.Get()
    local cap, text = ns.PresentationCapabilities, ns.NameplateText
    local name, bar, inside, title = plateFrame.name, plateFrame.healthBar, plateFrame.RPSNInsideName, plateFrame.RPSNFullTitleText
    local writes, saved = {}, {}
    local function Watch(region, label)
        if not region then return end
        local methods = {}
        saved[region] = methods
        for _, method in ipairs({"SetText", "SetFont", "SetTextColor", "SetVertexColor", "SetShadowColor", "SetShadowOffset",
            "SetWidth", "SetHeight", "SetAlpha", "SetShown", "Show", "Hide", "ClearAllPoints", "SetPoint", "SetJustifyH"}) do
            local original = region[method]
            if original then
                methods[method] = original
                region[method] = function(self, ...)
                    local key = label .. "." .. method
                    writes[key] = (writes[key] or 0) + 1
                    return original(self, ...)
                end
            end
        end
    end
    Watch(name, "name"); Watch(bar, "bar"); Watch(inside, "inside"); Watch(title, "title")
    Watch(plateFrame.HealthBarsContainer, "container")
    Watch(plateFrame.RPSNThreatText, "threat")
    for _, key in ipairs({"LeftText", "RightText", "Text"}) do Watch(bar[key], key) end
    local function Only(expected, label)
        for key, count in pairs(writes) do equal(count, expected[key], label .. " unexpected " .. key) end
        for key, count in pairs(expected) do equal(writes[key], count, label .. " missing " .. key) end
        writes = {}
    end
    local function FindReconciliation(fn, seen)
        seen = seen or {}
        if seen[fn] then return end
        seen[fn] = true
        local index = 1
        while true do
            local key, value = debug.getupvalue(fn, index)
            if not key then return end
            if key == "ReconcileNames" then return value end
            if type(value) == "function" then
                local found = FindReconciliation(value, seen)
                if found then return found end
            end
            index = index + 1
        end
    end
    -- Isolate the real reconciliation callback from unrelated deferred work
    -- left by earlier restricted-restoration fixtures.
    local reconcileNames = assert(FindReconciliation(events.scripts.OnUpdate))
    local function Reconcile() ns.PeriodicWork.Advance(0.25); reconcileNames(plate) end
    -- One complete assessment per ordinary plate, shared by lookup/check/repair.
    local lines, originalPrint = {}, print
    print = function(line) lines[#lines + 1] = line end
    ns.Profiler.Command("start"); Reconcile(); ns.Profiler.Command("stop"); ns.Profiler.Command("report")
    print = originalPrint
    local report = table.concat(lines, "\n")
    assert(report:find("Access assessment: 1 calls;", 1, true), "unchanged scan shares one assessment: " .. report)
    assert(not report:find("Text repair:", 1, true), "unchanged scan does not enter repair")
    Only({}, "unchanged scan")
    plateFrame.RPSNTitleVisibilityPending = true
    Reconcile(); Only({}, "unchanged pending title")
    name.text = "Native overwritten"; Reconcile(); Only({["name.SetText"] = 1}, "native text only")
    name.r = 0.2; Reconcile(); Only({["name.SetTextColor"] = 1}, "native color only")
    name.vg = 0.2; Reconcile(); Only({["name.SetVertexColor"] = 1, ["name.SetTextColor"] = 1}, "native vertex repair finishes with intended color")
    name.flags = "THICKOUTLINE"; Reconcile(); Only({["name.SetFont"] = 1}, "native font only")
    name.shadowX = 1; Reconcile(); Only({["name.SetShadowOffset"] = 1}, "shadow offset only")
    name.shown = false; Reconcile(); Only({["name.SetShown"] = 1}, "visibility only")
    inside.text = "Inside overwritten"; Reconcile(); Only({["inside.SetText"] = 1}, "inside text only")
    bar.height = 1; Reconcile(); Only({["bar.SetHeight"] = 1}, "bar height only")
    title.width = 999; Reconcile(); Only({["title.SetWidth"] = 1}, "title width only")
    name.text, name.r, name.alpha = "Two differences", 0.2, 0.4
    Reconcile(); Only({["name.SetText"] = 1, ["name.SetTextColor"] = 1, ["name.SetAlpha"] = 1}, "combined differences")

    -- An unknown font must not suppress independently readable differences.
    local fontGetter = name.GetFont
    name.GetFont = function() error("unreadable native font") end
    name.r = 0.3; Reconcile(); Only({["name.SetTextColor"] = 1}, "unknown font with color drift")
    name.GetFont = fontGetter
    for _ = 1, 4 do Reconcile() end
    Only({}, "font access recovery")

    -- Opaque geometry/colors cause neither repairs nor unbounded read attempts.
    local opaque = setmetatable({}, {__eq = function() error("opaque value compared") end,
        __tostring = function() error("opaque value formatted") end})
    local oldSecret = issecretvalue
    issecretvalue = function(value) return rawequal(value, opaque) or (oldSecret and oldSecret(value)) end
    local heightGetter, colorGetter, vertexGetter = bar.GetHeight, name.GetTextColor, name.GetVertexColor
    local heightReads = 0
    bar.GetHeight = function() heightReads = heightReads + 1; return opaque end
    name.GetTextColor = function() return opaque, opaque, opaque end
    name.GetVertexColor = function() return opaque, opaque, opaque, opaque end
    for _ = 1, 40 do Reconcile() end
    assert(heightReads <= 7, "unknown property retries are bounded")
    local frozenReads = heightReads
    for _ = 1, 40 do text.CachedNameHasDrifted(plateFrame, context) end
    equal(heightReads, frozenReads, "extra visits do not consume elapsed-time backoff")
    ns.PeriodicWork.Advance(4)
    text.CachedNameHasDrifted(plateFrame, context)
    equal(heightReads, frozenReads + 1, "elapsed retry deadline does not require sixteen visits")
    Only({}, "unknown observations")
    bar.GetHeight, name.GetTextColor, name.GetVertexColor = heightGetter, colorGetter, vertexGetter
    issecretvalue = oldSecret
    bar.height, name.r = 1, 0.2
    for _ = 1, 17 do Reconcile() end
    Only({["bar.SetHeight"] = 1, ["name.SetTextColor"] = 1}, "bounded retry repairs after access returns")

    -- Label observations are shared by checking and repairing the anchor chain.
    local label = bar.Text
    assert(label and label.GetNumPoints)
    local reads, shownGetter = 0, label.IsShown
    label.IsShown = function(self) reads = reads + 1; return shownGetter(self) end
    label.shown = not label.shown
    local assessment = cap.InspectFrame(plateFrame, context)
    local drifted, reason, plan = text.CachedNameHasDrifted(plateFrame, context, assessment)
    assert(drifted and plan.layout, "label visibility produces selective layout work")
    local observationReads = reads
    assert(text.RepairCachedName(plateFrame, context, assessment, plan))
    equal(reads, observationReads, "layout repair reuses label observations")
    assert(not writes["name.SetFont"] and not writes["name.SetText"] and not writes["title.SetWidth"], "layout repair avoids content/font/title writes")
    label.IsShown = shownGetter
    writes = {}
    Reconcile(); Only({}, "layout settled")

    -- Unknown cast visibility keeps the title hidden with bounded retries.
    local cast, castReads = plateFrame.castBar, 0
    local castShown = cast.IsShown
    cast.IsShown = function() castReads = castReads + 1; return nil end
    text.SyncFullTitleVisibility(plateFrame, context)
    assert(not title.shown and plateFrame.RPSNTitleVisibilityPending)
    writes = {}
    for _ = 1, 40 do Reconcile() end
    assert(castReads <= 8, "unknown cast visibility retries are bounded")
    Only({}, "unknown cast keeps title hidden without repeat writes")
    cast.IsShown = castShown
    cast.shown = false
    -- Native cast hooks remain immediate even during periodic backoff.
    for _, callback in ipairs(cast.scriptHooks.OnHide) do callback(cast) end
    equal(title.shown, true, "native cast hook bypasses unknown retry backoff")
    Only({["title.SetShown"] = 1}, "cast hook shows title once")

    -- Replaced regions invalidate observations before any stale writes.
    name.text = "Stale observation"
    assessment = cap.InspectFrame(plateFrame, context)
    drifted, reason, plan = text.CachedNameHasDrifted(plateFrame, context, assessment)
    local replacement = Region()
    plateFrame.name = replacement
    equal(text.RepairCachedName(plateFrame, context, assessment, plan), false, "replaced name invalidates assessment")
    Only({}, "stale name assessment")
    plateFrame.name = name
    name.text = "Selective RP"
    local container = plateFrame.HealthBarsContainer
    plateFrame.HealthBarsContainer = Region()
    equal(cap.AssessmentIsCurrent(plateFrame, assessment, context), false, "replaced container invalidates assessment")
    plateFrame.HealthBarsContainer = container

    name.IsForbidden = function() return true end
    equal(text.RepairCachedName(plateFrame, context, assessment, plan), false, "changed access invalidates assessment")
    Only({}, "newly forbidden name")
    name.IsForbidden = nil

    local alteredContext = {revision = context.revision + 1, combatLockdown = context.combatLockdown}
    equal(text.RepairCachedName(plateFrame, alteredContext, assessment, plan), false, "changed context invalidates assessment")
    Only({}, "stale context assessment")

    -- Guarded write failures keep the original error and allow a later retry.
    name.r = 0.4
    local failure, colorSetter = {}, name.SetTextColor
    name.SetTextColor = function() error(failure) end
    local ok, err = pcall(Reconcile)
    assert(not ok and err == failure, "selective repair preserves original error")
    assert(not plateFrame.RPSNApplyingStyle, "selective failure releases reentry guard")
    name.SetTextColor = colorSetter
    Reconcile(); Only({["name.SetTextColor"] = 1}, "failed write retry")
    for region, methods in pairs(saved) do for method, original in pairs(methods) do region[method] = original end end
    -- All previously exercised restoration/recycling tests still apply.
    ns.RestoreAll(); ns.RefreshAll()
end
CheckSelectiveReconciliation()
end

-- Phase 4: exercise the real per-frame scheduler with a crowded visible set.
do
local function CheckBoundedRuntime()
    local originalClock = GetTimePreciseSec
    GetTimePreciseSec = function() return 0 end
    local work = ns.PeriodicWork
    for _, group in ipairs({"reconciliation", "restoration frame", "restoration plate", "cast retry", "unit retry", "plate retry"}) do work.Clear(group) end
    stylingEnabled, categoryMode, showBar, gradients, highlightEnabled = true, "active", true, false, true
    appearance.namePlacement, appearance.nameSize, appearance.healthBarWidth = "INSIDE", 18, 120
    threatEnabled, threatPercent = true, nil
    unit = {player = true, faction = "Alliance", reaction = 5, names = {}}
    local list, byUnit, framesByUnit, repairs = {}, {}, {}, {}
    local rpName = "Crowded RP"
    ns.TRP3 = {GetDisplayInfo = function() return {roleplayingName = rpName, fullTitle = "Crowded title"} end}
    trp3Options = {useRoleplayingName = true, showFullTitle = true}
    UnitGUID = function(token) return "Player-" .. token end
    for index = 1, 16 do
        local token, frame = "nameplate" .. (100 + index), Region()
        frame.unit, frame.name = token, Region()
        frame.healthBar, frame.HealthBarsContainer, frame.castBar = Region(), Region(), Region()
        frame.castBar.shown = false
        frame.castBar.Icon = Region()
        frame.castBar.HideIconWhenNotInterruptible = true
        frame.name:SetFont("Crowded native", 12, "")
        frame.name:SetTextColor(0.2, 0.4, 0.6)
        local current = {UnitFrame = frame}
        list[index], byUnit[token], framesByUnit[token], unit.names[token] = current, current, frame, "Native " .. token
    end
    C_NamePlate.GetNamePlates = function() return list end
    C_NamePlate.GetNamePlateForUnit = function(token) return byUnit[token] end
    ns.RefreshAll()
    for token, frame in pairs(framesByUnit) do
        local setter = frame.name.SetText
        frame.name.SetText = function(self, value)
            repairs[token] = (repairs[token] or 0) + 1
            setter(self, value)
        end
        frame.name.text = "Native overwritten"
    end
    local function Count()
        local total = 0
        for _, value in pairs(repairs) do total = total + value end
        return total
    end
    events.scripts.OnUpdate(events, 0.25)
    equal(Count(), 4, "one runtime frame processes only four crowded repairs")
    -- Urgent name/threat/cast events must run ahead of the remaining scan jobs.
    local urgent, token = framesByUnit.nameplate116, "nameplate116"
    equal(urgent.name.text, "Native overwritten", "urgent fixture starts behind scan cursor")
    rpName, threatPercent = "Immediate RP", 55
    events.scripts.OnEvent(events, "UNIT_NAME_UPDATE", token)
    events.scripts.OnEvent(events, "UNIT_THREAT_LIST_UPDATE", token)
    urgent.castBar:Show()
    events.scripts.OnEvent(events, "UNIT_SPELLCAST_INTERRUPTIBLE", token)
    events.scripts.OnUpdate(events, 0.001)
    equal(urgent.RPSNInsideName.text, "Immediate RP", "queued name update bypasses scan backlog")
    equal(urgent.RPSNThreatText.text, "55%", "threat update bypasses scan backlog")
    equal(urgent.RPSNInterruptibleHighlight.frame.shown, true, "cast pulse bypasses scan backlog")
    equal(urgent.RPSNFullTitleText.shown, false, "cast/title substitution stays immediate")
    -- Finish this routine cycle without advancing its next 0.25-second deadline.
    events.scripts.OnUpdate(events, 0.001)
    events.scripts.OnUpdate(events, 0.001)
    for currentToken, frame in pairs(framesByUnit) do
        equal(repairs[currentToken], 1, "every current owner progresses once")
        equal(frame.name.text, currentToken == token and "Immediate RP" or "Crowded RP", "repair uses current owner's cache")
    end
    local before = Count()
    events.scripts.OnUpdate(events, 0.001)
    equal(Count(), before, "completed plates wait until their next due time")

    -- A deferred unit request must not write through a mismatched lookup.
    local correctLookup = C_NamePlate.GetNamePlateForUnit
    C_NamePlate.GetNamePlateForUnit = function(currentToken)
        if currentToken == "nameplate101" then return byUnit.nameplate102 end
        return correctLookup(currentToken)
    end
    local wrongFrame, wrongText = framesByUnit.nameplate102, framesByUnit.nameplate102.RPSNInsideName.text
    events.scripts.OnEvent(events, "UNIT_NAME_UPDATE", "nameplate101")
    events.scripts.OnUpdate(events, 0.001)
    equal(wrongFrame.RPSNInsideName.text, wrongText, "mismatched lookup cannot consume another owner's work")
    assert(work.Has("unit retry", "nameplate101"), "mismatched assignment retains merged work")
    C_NamePlate.GetNamePlateForUnit = correctLookup
    Tick(0.25)
    equal(framesByUnit.nameplate101.RPSNInsideName.text, "Immediate RP", "correct assignment receives deferred name work")
    assert(not work.Has("unit retry", "nameplate101"), "recovered unit request leaves retry queue")

    -- New native snapshots may reorder plates without starving older work.
    for index = 1, 8 do list[index], list[17 - index] = list[17 - index], list[index] end
    repairs = {}
    for _, frame in pairs(framesByUnit) do frame.name.text = "Overwritten again" end
    events.scripts.OnUpdate(events, 0.25)
    equal(Count(), 4, "reordered cycle retains one frame's cap")
    -- Remove an unprocessed plate, then recycle it with a new assignment.
    local retiredToken = "nameplate115"
    assert(not repairs[retiredToken], "retired fixture has not been scanned in reordered cycle")
    local recycled, recycledPlate = framesByUnit[retiredToken], byUnit[retiredToken]
    events.scripts.OnEvent(events, "NAME_PLATE_UNIT_REMOVED", retiredToken)
    assert(not work.Has("reconciliation", recycledPlate), "removal cancels queued plate work")
    byUnit[retiredToken], framesByUnit[retiredToken] = nil, nil
    local newToken = "nameplate199"
    recycled.unit, byUnit[newToken], framesByUnit[newToken], unit.names[newToken] = newToken, recycledPlate, recycled, "New native"
    events.scripts.OnEvent(events, "NAME_PLATE_UNIT_ADDED", newToken)
    equal(recycled.RPSNOriginalUnit, newToken, "recycled owner initialized immediately")
    repairs = {}
    for _ = 1, 4 do events.scripts.OnUpdate(events, 0.001) end
    assert(not repairs[retiredToken], "departed queued owner performs no later text writes")
    equal(recycled.RPSNInsideName.text, "Immediate RP", "stale scan cannot overwrite recycled content")

    -- Broad settings/context refreshes now share the bounded scheduler.
    appearance.nameSize = 22
    ns.QueueNameplateRefresh("phase 4 settings regression")
    assert(not work.Has("reconciliation", byUnit.nameplate116), "full refresh cancels the old cycle")
    events.scripts.OnUpdate(events, 0.001)
    local changed = 0
    for _, frame in pairs(framesByUnit) do if frame.RPSNInsideName.size == 22 then changed = changed + 1 end end
    assert(changed > 0 and changed <= 4, "broad settings refresh is paced within one frame")
    for _ = 1, 12 do events.scripts.OnUpdate(events, 0.001) end
    for _, frame in pairs(framesByUnit) do equal(frame.RPSNInsideName.size, 22, "bounded settings refresh reaches every plate") end
    local oldRevision = ns.WorldContext.Get().revision
    C_PvP = {GetZonePVPInfo = function() return "contested", false end}
    events.scripts.OnEvent(events, "ZONE_CHANGED_NEW_AREA")
    assert(ns.WorldContext.Get().revision > oldRevision, "context fixture changed revision")
    events.scripts.OnUpdate(events, 0.001)
    for _ = 1, 12 do events.scripts.OnUpdate(events, 0.001) end
    for _, frame in pairs(framesByUnit) do
        equal(frame.RPSNPresentation.contextRevision, ns.WorldContext.Get().revision, "jobs/settings use fresh context")
    end
    stylingEnabled = false
    ns.RestoreAll()
    assert(not work.Has("reconciliation", recycledPlate), "disable discards routine work")
    local nativeText = recycled.name.text
    for _ = 1, 4 do events.scripts.OnUpdate(events, 0.25) end
    equal(recycled.name.text, nativeText, "disabled scans cannot restore addon text")
    -- Deferred restoration and cast retries share the same runtime budget,
    -- including while styling is disabled.
    stylingEnabled = true; ns.RefreshAll()
    local blocked = true
    for _, frame in pairs(framesByUnit) do frame.IsForbidden = function() return blocked end end
    stylingEnabled = false; ns.RestoreAll()
    for _, frame in pairs(framesByUnit) do
        assert(ns.NameplateRestoration.IsPending(frame), "blocked restoration scheduled")
        ns.CastHighlight.UpdateInterruptibleHighlight(frame, ns.WorldContext.Get(), frame.RPSNPresentation)
    end
    blocked = false
    local originalCount, jobs = ns.Profiler.Count, 0
    ns.Profiler.Count = function(group, reason)
        if group == "Periodic jobs" then jobs = jobs + 1 end
        originalCount(group, reason)
    end
    events.scripts.OnUpdate(events, 0.25)
    equal(jobs, 4, "disabled runtime bounds restoration/cast work together")
    local restored = 0
    for _, frame in pairs(framesByUnit) do if not frame.RPSNState then restored = restored + 1 end end
    equal(restored, 4, "restoration no longer retries all plates in one frame")
    for _ = 1, 12 do
        jobs = 0; events.scripts.OnUpdate(events, 0.001)
        assert(jobs <= 4, "all deferred groups share each frame's cap")
    end
    ns.Profiler.Count = originalCount
    for _, frame in pairs(framesByUnit) do
        equal(frame.RPSNState, nil, "every blocked restoration recovers fairly")
        assert(not work.Has("cast retry", frame), "every cast retry recovers fairly")
        frame.IsForbidden = nil
    end
    -- Restore fixtures for any later checks.
    stylingEnabled = true
    GetTimePreciseSec = originalClock
    work.Clear("reconciliation")
end
CheckBoundedRuntime()
end

-- Native setters outside CompactUnitFrame_UpdateName must not leave a white
-- frame between routine jobs. Exercise real post-hook recursion, not a timer.
do
    stylingEnabled, categoryMode, showBar, dimBackground = true, "active", false, true
    appearance.namePlacement, appearance.nameFont, appearance.nameSize = "ABOVE", "ARIALN", 18
    appearance.useSlugRendering, appearance.matchSanctuaryFont = true, false
    unit = {reaction = 5, names = {nameplate1 = "Background citizen"}}
    UnitGUID = function() return "Creature-Appearance" end
    UnitNameplateShowsWidgetsOnly = function() return false end
    ns.TRP3, trp3Options = nil, {}
    plateFrame.unit = "nameplate1"
    C_NamePlate.GetNamePlateForUnit = function() return plate end
    C_NamePlate.GetNamePlates = function() return {plate} end
    ns.RefreshAll()
    local name, expected = plateFrame.name, plateFrame.RPSNNameStyle
    local originals, callbacks = {}, {}
    for _, hook in ipairs(hooks) do
        if hook.name == name and hook.method then callbacks[hook.method] = hook.callback end
    end
    local depth, maximum = 0, 0
    for method, callback in pairs(callbacks) do
        local original = name[method]
        originals[method] = original
        name[method] = function(self, ...)
            depth = depth + 1; maximum = math.max(maximum, depth)
            assert(depth < 6, "appearance hook recursion bounded")
            local result = original(self, ...)
            callback(self)
            depth = depth - 1
            return result
        end
    end
    assert(callbacks.SetFontObject and callbacks.SetTextHeight and callbacks.SetTextColor)
    local lines, savedPrint = {}, print
    print = function(line) lines[#lines + 1] = line end
    ns.Profiler.Command("start")
    name:SetTextColor(1, 1, 1)
    equal(name.r, 153 / 255, "direct native white immediately repaired")
    plateFrame.healthBar.shown = true
    name:SetTextColor(1, 1, 1)
    equal(name.r, 153 / 255, "native bar visibility does not veto immediate grey repair")
    plateFrame.healthBar.shown = false
    name:SetVertexColor(0.2, 0.3, 0.4, 1)
    equal(name.vr, 1, "direct native tint immediately repaired")
    name:SetFontObject("SystemFont_NamePlate")
    equal(name.font, expected.font, "native font object immediately repaired")
    equal(name.r, 153 / 255, "font object cannot leave white color")
    name:SetTextHeight(64)
    equal(name.size, 18, "native text height immediately repaired")
    name:SetFont("Different face", 11, "THICKOUTLINE")
    equal(name.flags, expected.flags, "direct font flags immediately repaired")
    plateFrame.RPSNApplyingStyle = true
    name:SetFontObject("Native during callback")
    assert(plateFrame.RPSNNameAppearancePending, "guarded native font-object write survives")
    plateFrame.RPSNApplyingStyle = nil
    ns.NameplateText.RepairPendingNameAppearance(plateFrame)
    equal(name.font, expected.font, "pending native appearance repaired after guard")
    equal(name.r, 153 / 255, "pending native white repaired after guard")
    assert(not plateFrame.RPSNNameAppearancePending)
    -- Native callbacks can recolor names while addon writes are guarded.
    -- Final own writes must converge without recursive or redundant font work.
    local fontWrites, fontSetter = 0, name.SetFont
    name.SetFont = function(self, ...) fontWrites = fontWrites + 1; return fontSetter(self, ...) end
    plateFrame.RPSNApplyingStyle = true
    name:SetTextColor(1, 1, 1)
    assert(plateFrame.RPSNNameColorPending, "guarded native color write survives")
    plateFrame.RPSNApplyingStyle = nil
    ns.NameplateText.RepairPendingNameAppearance(plateFrame)
    equal(name.r, expected.r, "guarded native color repaired before reconciliation")
    equal(fontWrites, 0, "pending color does not rewrite font")
    plateFrame.RPSNApplyingArtwork = true
    name:SetVertexColor(0.2, 0.3, 0.4, 1)
    plateFrame.RPSNApplyingArtwork = nil
    ns.NameplateText.RepairPendingNameAppearance(plateFrame)
    equal(name.vr, 1, "guarded native vertex tint repaired")
    equal(name.r, expected.r, "guarded vertex repair finishes with intended grey")
    plateFrame.RPSNApplyingStyle = true
    name:SetVertexColor(1, 1, 1, 1)
    name:SetTextColor(expected.r, expected.g, expected.b, 1)
    plateFrame.RPSNApplyingStyle = nil
    local repairCalls = 0
    local colorSetter = name.SetTextColor
    name.SetTextColor = function(self, ...) repairCalls = repairCalls + 1; return colorSetter(self, ...) end
    ns.NameplateText.RepairPendingNameAppearance(plateFrame)
    equal(repairCalls, 0, "converged own color writes need no follow-up setter")
    name.SetTextColor = colorSetter
    assert(not plateFrame.RPSNNameColorPending, "pending color flag cleared")
    -- A real selective visibility repair triggers a native callback after its
    -- earlier color write. The completed operation must still converge.
    local shownSetter = name.SetShown
    name.SetShown = function(self, shown)
        shownSetter(self, shown)
        if shown then self:SetTextColor(expected.r, 1, expected.b, 1) end
    end
    name.shown = false
    local cap, context = ns.PresentationCapabilities, ns.WorldContext.Get()
    local assessment = cap.InspectFrame(plateFrame, context)
    local drifted, _, plan = ns.NameplateText.CachedNameHasDrifted(plateFrame, context, assessment)
    assert(drifted and plan.shown, "native hidden name produces selective visibility plan")
    assert(ns.NameplateText.RepairCachedName(plateFrame, context, assessment, plan))
    equal(name.g, expected.g, "nested visibility callback color repaired on guard release")
    equal(fontWrites, 0, "nested visibility color repair avoids fonts")
    name.SetShown, name.SetFont = shownSetter, fontSetter

    name:SetAlpha(0.2)
    equal(name.alpha, 1, "above-bar native name immediately restores opacity")
    plateFrame.RPSNApplyingStyle = true
    name:SetAlpha(0.2)
    assert(plateFrame.RPSNNameAlphaPending, "guarded native alpha retained")
    plateFrame.RPSNApplyingStyle = nil
    ns.NameplateText.RepairPendingNameAppearance(plateFrame)
    equal(name.alpha, 1, "guarded alpha repaired after style")
    plateFrame.RPSNApplyingArtwork = true
    name:SetAlpha(1)
    plateFrame.RPSNApplyingArtwork = nil
    local alphaSetter, alphaCalls = name.SetAlpha, 0
    name.SetAlpha = function(self, ...) alphaCalls = alphaCalls + 1; return alphaSetter(self, ...) end
    ns.NameplateText.RepairPendingNameAppearance(plateFrame)
    equal(alphaCalls, 0, "converged own opacity needs no extra write")
    name.SetAlpha = alphaSetter
    assert(not plateFrame.RPSNNameAlphaPending, "pending alpha cleared")
    plateFrame.RPSNRestoring = true; name:SetAlpha(0.3)
    equal(name.alpha, 0.3, "restoration retains native opacity")
    plateFrame.RPSNRestoring = nil
    stylingEnabled = false; name:SetAlpha(0.4)
    equal(name.alpha, 0.4, "disable retains native opacity")
    stylingEnabled = true
    plateFrame.unit = "nameplate2"; name:SetAlpha(0.5)
    equal(name.alpha, 0.5, "reassigned native opacity not overwritten")
    plateFrame.unit = "nameplate1"
    name.IsForbidden = function() return true end; name:SetAlpha(0.6)
    equal(name.alpha, 0.6, "forbidden native opacity not overwritten")
    name.IsForbidden = nil; name:SetAlpha(1)
    ns.Profiler.Command("stop"); ns.Profiler.Command("report")
    print = savedPrint
    local report = table.concat(lines, "\n")
    assert(not report:find("Full styling:", 1, true) and not report:find("Classification:", 1, true)
        and not report:find("Bar artwork:", 1, true), "setter repair avoids broad work")
    assert(report:find("Name appearance writes: SetFontObject =", 1, true))
    assert(report:find("Name appearance deferred: color repair =", 1, true))
    assert(maximum <= 3 and not plateFrame.RPSNRepairingNameAppearance, "reentry guard released")

    -- A semantically identical native GetFont result causes no repeated repair.
    local getter = name.GetFont
    name.GetFont = function() return expected.font:gsub("\\", "/"):lower(), expected.size, "outline, SLUG" end
    local cap, context = ns.PresentationCapabilities, ns.WorldContext.Get()
    assert(not ns.NameplateText.CachedNameHasDrifted(plateFrame, context, cap.InspectFrame(plateFrame, context)),
        "normalized path and flag order are not font drift")
    name.GetFont = function() return expected.font, expected.size, "SLUG,THICKOUTLINE" end
    local drifted, reason = ns.NameplateText.CachedNameHasDrifted(plateFrame, context, cap.InspectFrame(plateFrame, context))
    assert(drifted and reason == "native font", "different outline remains genuine drift")
    name.GetFont = getter

    -- Restoration/disabled/recycled/inaccessible names retain native control.
    plateFrame.RPSNRestoring = true; name:SetTextColor(1, 1, 1)
    equal(name.r, 1, "restoration bypasses appearance repair")
    plateFrame.RPSNRestoring = nil
    stylingEnabled = false; name:SetTextColor(0.8, 0.8, 0.8)
    equal(name.r, 0.8, "disabled styling bypasses appearance repair")
    stylingEnabled = true
    plateFrame.unit = "nameplate2"; name:SetTextColor(1, 1, 1)
    equal(name.r, 1, "reassigned unit bypasses cached appearance")
    plateFrame.unit = "nameplate1"
    UnitGUID = function() return "Creature-Recycled" end
    name:SetTextColor(0.7, 0.7, 0.7)
    equal(name.r, 0.7, "same-token new identity bypasses cached appearance")
    UnitGUID = function() return "Creature-Appearance" end
    name.IsForbidden = function() return true end; name:SetTextColor(1, 1, 1)
    equal(name.r, 1, "inaccessible region bypasses appearance repair")
    name.IsForbidden = nil
    local setColor = originals.SetTextColor
    local failure = {}
    name.SetTextColor = function() error(failure) end
    local ok, err = pcall(callbacks.SetFontObject)
    assert(not ok and err == failure and not plateFrame.RPSNRepairingNameAppearance, "failed setter releases guard")
    name.SetTextColor = setColor
    -- Model a color setter that also overwrites opacity. Appearance hooks
    -- must finish with native alpha zero while the addon inside label is shown.
    showBar, appearance.namePlacement = true, "INSIDE"
    ns.RefreshAll()
    expected = plateFrame.RPSNNameStyle
    assert(expected.inside, "inside-name fixture")
    local vertexSetter = name.SetVertexColor
    name.SetVertexColor = function(self, ...)
        self.alpha = 1
        return vertexSetter(self, ...)
    end
    name:SetVertexColor(0.2, 0.3, 0.4, 1)
    equal(name.alpha, 0, "appearance color repair finishes by concealing native inside name")
    equal(name.r, expected.r, "inside native color still restored")
    equal(plateFrame.RPSNInsideName.shown, true, "addon inside label remains shown")
    name:SetAlpha(1)
    equal(name.alpha, 0, "direct native opacity cannot expose duplicate inside name")
    plateFrame.RPSNApplyingArtwork = true; name:SetAlpha(1)
    plateFrame.RPSNApplyingArtwork = nil
    ns.NameplateText.RepairPendingNameAppearance(plateFrame)
    equal(name.alpha, 0, "guarded inside opacity repaired")
    name.SetVertexColor = vertexSetter
    UnitGUID = function() return "Creature-Recycled" end; name:SetAlpha(0.8)
    equal(name.alpha, 0.8, "same-token recycled alpha retains native control")
    UnitGUID = function() return "Creature-Appearance" end
    UnitNameplateShowsWidgetsOnly = function() return true end
    ns.RefreshAll()
    assert(plateFrame.RPSNNameStyle.suppressed)
    name:SetAlpha(1)
    equal(name.alpha, 0, "widget-only cached presentation immediately repairs opacity")
    UnitNameplateShowsWidgetsOnly = function() return false end
    showBar, appearance.namePlacement = false, "ABOVE"
    ns.RefreshAll()
    for method, original in pairs(originals) do name[method] = original end
end

-- Native corner anchors override explicit sizes. Model this layout behavior,
-- then verify settings and reconciliation converge instead of rewriting forever.
do
    local frame, container, bar, parent = Region(), Region(), Region(), Region()
    frame.unit, frame.name, frame.HealthBarsContainer, frame.healthBar = "nameplate9", Region(), container, bar
    frame.name:SetFont("Native", 10, "")
    frame.name:SetTextColor(1, 1, 1)
    frame.name:SetVertexColor(1, 1, 1, 1)
    frame.name:SetText("Anchored native")
    local originalWidth, originalHeight = 140, 20
    local function NativeAnchors()
        container.points = {{"BOTTOMLEFT", parent, "TOPLEFT", 0, 4}, {"BOTTOMRIGHT", parent, "TOPRIGHT", 0, 4}}
        bar.points = {{"TOPLEFT", container, "TOPLEFT", 0, 0}, {"BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0}}
    end
    NativeAnchors()
    for _, region in ipairs({container, bar}) do
        function region:GetWidth() return #self.points > 1 and originalWidth or self.width end
        function region:GetHeight() return #self.points > 1 and originalHeight or self.height end
    end
    stylingEnabled, categoryMode, showBar, dimBackground = true, "active", true, false
    threatEnabled, threatPercent = false, nil
    appearance.namePlacement, appearance.nameSize, appearance.healthBarWidth = "INSIDE", 18, 120
    appearance.useSlugRendering = false
    unit = {reaction = 3}
    UnitGUID = function() return "Creature-Anchored" end
    local context, cap = ns.WorldContext.Get(), ns.PresentationCapabilities
    ns.NameplatePresentation.ApplySimpleStyle(frame, context)
    equal(bar:GetWidth(), 168, "anchored bar reaches configured width")
    equal(container:GetWidth(), 168, "anchored container reaches configured width")
    equal(bar:GetHeight(), 25, "anchored bar fits inside name")
    local drifted = ns.NameplateText.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context))
    assert(not drifted, "sized anchored plate converges")
    NativeAnchors()
    local reason, plan
    drifted, reason, plan = ns.NameplateText.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context))
    assert(drifted, "native anchor reset causes genuine dimension drift")
    assert(ns.NameplateText.RepairCachedName(frame, context, cap.InspectFrame(frame, context), plan))
    assert(not ns.NameplateText.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context)),
        "one geometry repair converges after native reset")
    assert(ns.NameplateRestoration.Request(frame, context))
    equal(#bar.points, 2, "native bar anchors restored")
    equal(#container.points, 2, "native container anchors restored")
    equal(container.points[1][5], 4, "native vertical offset restored")
    equal(bar:GetWidth(), 140, "native width restored")
    equal(bar:GetHeight(), 20, "native height restored")
    ns.NameplatePresentation.ApplySimpleStyle(frame, context)
    appearance.namePlacement, appearance.healthBarWidth = "ABOVE", 100
    ns.NameplatePresentation.ApplySimpleStyle(frame, context)
    equal(#bar.points, 2, "default width and height restore native anchoring")
    equal(bar:GetWidth(), 140, "default-width setting restores native width")

    -- Global CompactUnitFrame hooks must not fully style raid/party frames.
    local lines, savedPrint = {}, print
    print = function(line) lines[#lines + 1] = line end
    ns.Profiler.Command("start")
    frame.unit = "raid1"; hooks[2].callback(frame); hooks[1].callback(frame)
    ns.Profiler.Command("stop"); ns.Profiler.Command("report")
    print = savedPrint
    local report = table.concat(lines, "\n")
    assert(not report:find("Full styling:", 1, true), "non-nameplate hooks avoid full-style fallback")
    assert(report:find("Focused outcomes: not a nameplate = 2", 1, true))
end

-- Retail nameplate dimensions are readable while GetPoint throws. Exercise
-- both IsAnchoringRestricted and clients without that predicate, modern and
-- classic offsets, native resets, restoration and unsupported hierarchies.
do
    local savedSetup, savedPixel = NamePlateSetupOptions, PixelUtil
    PixelUtil = {SetPoint = function(region, ...) region:SetPoint(...) end}
    for _, classic in ipairs({false, true}) do
        for _, predicate in ipairs({false, true}) do
            NamePlateSetupOptions = {useClassicHealthBar = classic, horizontalScale = 2,
                verticalScale = 2, castBarToHealthBarSpacing = 4}
            local frame, container, bar, cast = Region(), Region(), Region(), Region()
            frame.unit, frame.name, frame.HealthBarsContainer, frame.healthBar = "nameplate9", Region(), container, bar
            frame.CastBarsContainer, container.healthBar = cast, bar
            frame.UpdateAnchors = function() end
            frame.name:SetFont("Native", 10, "")
            frame.name:SetTextColor(1, 1, 1); frame.name:SetVertexColor(1, 1, 1, 1)
            frame.name:SetText("Restricted anchors")
            local function NativeAnchors()
                container.points = {{"BOTTOMLEFT", cast, "TOPLEFT", 0, 4}, {"BOTTOMRIGHT", cast, "TOPRIGHT", 0, 4}}
                bar.points = {{"TOPLEFT", container, "TOPLEFT", classic and 7 or 0, classic and 1 or 0},
                    {"BOTTOMRIGHT", container, "BOTTOMRIGHT", classic and -41.5 or 0, classic and 1 or 0}}
            end
            NativeAnchors()
            local getters = 0
            for _, region in ipairs({bar, container}) do
                function region:GetPoint() getters = getters + 1; error("Can't measure restricted regions") end
                if predicate then region.IsAnchoringRestricted = function() return true end end
                function region:GetWidth() return #self.points > 1 and 140 or self.width end
                function region:GetHeight() return #self.points > 1 and 20 or self.height end
            end
            stylingEnabled, categoryMode, showBar, dimBackground = true, "active", true, false
            threatEnabled, threatPercent = false, nil
            appearance.namePlacement, appearance.nameSize, appearance.healthBarWidth = "INSIDE", 18, 120
            appearance.useSlugRendering = false
            unit = {reaction = 3}; UnitGUID = function() return "Creature-Restricted-Anchors" end
            local context, cap = ns.WorldContext.Get(), ns.PresentationCapabilities
            ns.NameplatePresentation.ApplySimpleStyle(frame, context)
            equal(bar:GetWidth(), 168, "unreadable anchors reach configured bar width")
            equal(container:GetWidth(), 168, "unreadable anchors reach configured container width")
            equal(bar:GetHeight(), 25, "unreadable anchors reach configured height")
            assert(not ns.NameplateText.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context)),
                "unreadable anchor sizing converges")
            local geometryHook
            for _, hook in ipairs(hooks) do
                if hook.name == frame and hook.method == "UpdateAnchors" then geometryHook = hook.callback end
            end
            assert(geometryHook, "native geometry hook installed")
            NativeAnchors()
            local lines, savedPrint = {}, print
            print = function(line) lines[#lines + 1] = line end
            ns.Profiler.Command("start"); geometryHook(); ns.Profiler.Command("stop"); ns.Profiler.Command("report")
            print = savedPrint
            local report = table.concat(lines, "\n")
            assert(not report:find("Full styling:", 1, true) and not report:find("Classification:", 1, true)
                and not report:find("Name/title styling:", 1, true), "geometry hook performs focused sizing only")
            equal(bar:GetWidth(), 168, "geometry reset repaired immediately")
            assert(not ns.NameplateText.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context)),
                "native geometry callback converges before reconciliation")
            -- Geometry rounding must not weaken font-size comparisons.
            local originalHeight, originalWidth = bar.GetHeight, bar.GetWidth
            PixelUtil.GetPixelToUIUnitFactor = function() return 0.5 end
            bar.GetEffectiveScale = function() return 1 end
            bar.GetHeight = function(self) return originalHeight(self) + 0.108 end
            bar.GetWidth = function(self) return originalWidth(self) + 0.108 end
            assert(not ns.NameplateText.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context)),
                "subpixel dimensions are stable")
            local oldSize = frame.name.size; frame.name.size = oldSize + 0.108
            local fontDrift, _, fontPlan = ns.NameplateText.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context))
            assert(fontDrift and fontPlan.font, "font-size mismatch remains strict")
            frame.name.size = oldSize
            bar.GetHeight = function(self) return originalHeight(self) + 1 end
            assert(ns.NameplateText.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context)),
                "geometry beyond pixel tolerance is repaired")
            bar.GetHeight, bar.GetWidth = originalHeight, originalWidth
            lines = {}; print = function(line) lines[#lines + 1] = line end
            ns.Profiler.Command("start")
            ns.NameplatePresentation.InitializeOrRefresh(frame, context, "initial plate")
            ns.NameplatePresentation.InitializeOrRefresh(frame, context, "late plate")
            ns.Profiler.Command("stop"); ns.Profiler.Command("report"); print = savedPrint
            assert(not table.concat(lines, "\n"):find("Full styling:", 1, true),
                "initial and late handlers reuse current presentation")
            NativeAnchors(); frame.RPSNApplyingStyle = true; geometryHook()
            assert(frame.RPSNGeometryPending, "nested native anchor update remains pending")
            frame.RPSNApplyingStyle = nil
            ns.NameplatePresentation.InitializeOrRefresh(frame, context, "late plate")
            assert(not frame.RPSNGeometryPending, "focused pass drains pending geometry")
            equal(bar:GetWidth(), 168, "pending native geometry restored")
            NativeAnchors()
            local drift, reason, plan = ns.NameplateText.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context))
            assert(drift and ns.NameplateText.RepairCachedName(frame, context, cap.InspectFrame(frame, context), plan))
            assert(not ns.NameplateText.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context)),
                "unreadable anchor reset converges after one repair")
            if predicate then equal(getters, 0, "restricted predicate avoids positional getter") end
            assert(ns.NameplateRestoration.Request(frame, context))
            equal(#bar.points, 2, "unreadable native bar anchors restored")
            equal(#container.points, 2, "unreadable native container anchors restored")
            equal(container.points[1][2], cast, "native cast-relative hierarchy restored")
            equal(container.points[1][5], 4, "native cast spacing restored")
            equal(bar.points[1][4], classic and 7 or 0, "native left inset restored")
            equal(bar.points[2][4], classic and -41.5 or 0, "native right inset restored")
            equal(bar.points[1][5], classic and 1 or 0, "native vertical offset restored")
            equal(bar:GetWidth(), 140, "unreadable native width restored")
            equal(bar:GetHeight(), 20, "unreadable native height restored")
            ns.NameplatePresentation.ApplySimpleStyle(frame, context)
            appearance.namePlacement, appearance.healthBarWidth = "ABOVE", 100
            ns.NameplatePresentation.ApplySimpleStyle(frame, context)
            equal(#bar.points, 2, "default sizing restores unreadable anchors")
            equal(bar:GetWidth(), 140, "default sizing restores unreadable width")
            NativeAnchors(); frame.UpdateAnchors = nil
            local before = bar.points
            assert(not ns.NameplateFrames.PrepareBarSize(frame, bar, context), "unknown unreadable layout rejected")
            equal(bar.points, before, "unknown unreadable anchors untouched")
        end
    end
    NamePlateSetupOptions, PixelUtil = savedSetup, savedPixel
end

-- A FontString implementation can expose text/vertex color through shared
-- state. Reconciliation must never leave the neutral white write as its color.
do
    local frame = Region()
    frame.unit, frame.name, frame.healthBar, frame.HealthBarsContainer = "nameplate10", Region(), Region(), Region()
    local name = frame.name
    name:SetFont("Native", 10, "")
    function name:SetTextColor(r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a or 1 end
    function name:SetVertexColor(...) self:SetTextColor(...) end
    function name:GetVertexColor() return self.r, self.g, self.b, self.a end
    stylingEnabled, categoryMode, showBar, dimBackground = true, "active", false, true
    appearance.namePlacement, appearance.healthBarWidth = "ABOVE", 100
    unit = {reaction = 5}
    UnitGUID = function() return "Creature-SharedColor" end
    local cap, context = ns.PresentationCapabilities, ns.WorldContext.Get()
    ns.NameplatePresentation.ApplySimpleStyle(frame, context)
    local drifted, _, plan = ns.NameplateText.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context))
    if drifted then ns.NameplateText.RepairCachedName(frame, context, cap.InspectFrame(frame, context), plan) end
    equal(name.r, 153 / 255, "shared-color reconciliation cannot whiten a background name")
    assert(not ns.NameplateText.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context)),
        "configured shared color is stable, not perpetual vertex drift")
    name:SetVertexColor(1, 1, 1, 1)
    drifted, _, plan = ns.NameplateText.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context))
    assert(drifted and plan.vertex and plan.color, "external shared-color write is detected")
    assert(ns.NameplateText.RepairCachedName(frame, context, cap.InspectFrame(frame, context), plan))
    equal(name.r, 153 / 255, "external shared-color white returns to grey")
    assert(not ns.NameplateText.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context)),
        "shared-color repair converges")
end

-- A native lookup can finish styling through the name hook before returning
-- to ADDED. Neither ADDED nor its late timer should duplicate that full pass.
do
    local originalGetter = C_NamePlate.GetNamePlateForUnit
    local frame, plate = Region(), {}
    frame.unit, frame.name, frame.healthBar, frame.HealthBarsContainer = "nameplate11", Region(), Region(), Region()
    plate.UnitFrame = frame
    frame.name:SetFont("Native", 10, ""); frame.name:SetTextColor(1, 1, 1)
    frame.name:SetVertexColor(1, 1, 1, 1); frame.name:SetText("Native initialized")
    stylingEnabled, categoryMode, showBar, dimBackground = true, "active", true, false
    appearance.namePlacement, appearance.healthBarWidth = "ABOVE", 100
    unit = {reaction = 3}; UnitGUID = function() return "Creature-Lifecycle" end
    local first = true
    C_NamePlate.GetNamePlateForUnit = function()
        if first then first = false; hooks[2].callback(frame) end
        return plate
    end
    local function Measure(callback)
        local lines, savedPrint = {}, print
        print = function(line) lines[#lines + 1] = line end
        ns.Profiler.Command("start"); callback(); ns.Profiler.Command("stop"); ns.Profiler.Command("report")
        print = savedPrint
        return table.concat(lines, "\n")
    end
    local report = Measure(function() events.scripts.OnEvent(events, "NAME_PLATE_UNIT_ADDED", "nameplate11") end)
    assert(report:find("Full styling: 1 calls;", 1, true), "native lookup and ADDED share one full initialization")
    assert(report:find("Initialization: reused initial plate = 1", 1, true), "ADDED reuse is observable")
    local late = timers[#timers][2]
    report = Measure(late)
    assert(not report:find("Full styling:", 1, true), "late callback refreshes data without full styling")
    events.scripts.OnEvent(events, "NAME_PLATE_UNIT_REMOVED", "nameplate11")
    frame.RPSNNameStyle = nil
    events.scripts.OnEvent(events, "NAME_PLATE_UNIT_ADDED", "nameplate11")
    report = Measure(late)
    assert(not report:find("Data update:", 1, true) and not report:find("Full styling:", 1, true),
        "old late callback cannot refresh a recycled token")
    frame.RPSNNameStyle = nil
    report = Measure(function() ns.NameplatePresentation.InitializeOrRefresh(frame, ns.WorldContext.Get(), "late plate") end)
    assert(report:find("Full styling: 1 calls;", 1, true), "missing cache still initializes fully")
    C_NamePlate.GetNamePlateForUnit = originalGetter
end

-- A native hide must not invalidate an otherwise-current presentation. Repair
-- bar/container/inside-name visibility together without classification/fonts.
do
    local frame = Region()
    frame.unit, frame.name, frame.healthBar, frame.HealthBarsContainer = "nameplate12", Region(), Region(), Region()
    local name, bar, container = frame.name, frame.healthBar, frame.HealthBarsContainer
    name:SetFont("Native", 10, ""); name:SetTextColor(1, 1, 1)
    name:SetVertexColor(1, 1, 1, 1); name:SetText("Visibility regression")
    stylingEnabled, categoryMode, showBar, dimBackground = true, "active", true, false
    appearance.namePlacement, appearance.healthBarWidth = "INSIDE", 100
    unit = {reaction = 3}; UnitGUID = function() return "Creature-Visibility" end
    local context, cap, text = ns.WorldContext.Get(), ns.PresentationCapabilities, ns.NameplateText
    ns.NameplatePresentation.ApplySimpleStyle(frame, context)
    local inside = frame.RPSNInsideName
    bar.shown, container.shown, inside.shown = false, false, false
    local drift, reason, plan = text.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context))
    assert(drift and reason == "bar visibility" and not plan.full and plan.barShown and plan.containerShown
        and plan.insideShown, "native visibility produces a selective combined plan")
    local lines, savedPrint = {}, print
    print = function(line) lines[#lines + 1] = line end
    ns.Profiler.Command("start")
    assert(text.RepairCachedName(frame, context, cap.InspectFrame(frame, context), plan))
    ns.Profiler.Command("stop"); ns.Profiler.Command("report"); print = savedPrint
    local report = table.concat(lines, "\n")
    assert(not report:find("Full styling:", 1, true) and not report:find("Classification:", 1, true)
        and not report:find("Name/title styling:", 1, true), "visibility repairs avoid full styling and classification")
    assert(bar.shown and container.shown and inside.shown, "visibility repairs restore all required regions")
    assert(not text.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context)), "visibility repair converges")
    bar.shown = false
    for _, callback in ipairs(bar.scriptHooks.OnHide) do callback(bar) end
    assert(bar.shown, "native OnHide repairs bar before reconciliation")
    showBar = false
    ns.NameplatePresentation.ApplySimpleStyle(frame, context)
    bar.shown = true
    drift, reason, plan = text.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context))
    assert(drift and plan.barShown == false and not plan.full, "configured hidden bar uses a false-valued selective plan")
    assert(text.RepairCachedName(frame, context, cap.InspectFrame(frame, context), plan) and not bar.shown)
    local shownGetter = bar.IsShown
    bar.IsShown = function() return nil end
    drift, reason, plan = text.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context))
    assert(not plan or plan.barShown == nil, "unknown bar visibility does not trigger a write")
    bar.IsShown = shownGetter
    showBar = true; ns.NameplatePresentation.ApplySimpleStyle(frame, context)
    bar.shown = false; name.IsForbidden = function() return true end
    for _, callback in ipairs(bar.scriptHooks.OnHide) do callback(bar) end
    assert(not bar.shown, "native hide repair respects inaccessible frames")
    name.IsForbidden = nil
    stylingEnabled = false
    for _, callback in ipairs(bar.scriptHooks.OnHide) do callback(bar) end
    assert(not bar.shown, "native hide repair respects disabled styling")
    stylingEnabled = true
    assert(ns.NameplateRestoration.Request(frame, context), "visibility repair preserves restoration")
end

-- Global fan-out must be bounded while priority/unit work bypasses its backlog.
do
    local scheduler, savedClock = ns.PeriodicWork, GetTimePreciseSec
    GetTimePreciseSec = function() return 0 end
    for _, group in ipairs({"global refresh", "reconciliation", "restoration frame", "restoration plate",
        "cast retry", "unit retry", "plate retry"}) do scheduler.Clear(group) end
    local savedList, savedLookup = C_NamePlate.GetNamePlates, C_NamePlate.GetNamePlateForUnit
    local list, byUnit, guid = {}, {}, {}
    local priority
    C_NamePlate.GetNamePlates = function() return list end
    C_NamePlate.GetNamePlateForUnit = function(token)
        if token == "target" then return priority end
        return byUnit[token]
    end
    unit = {reaction = 3, names = {}}
    UnitGUID = function(token) return guid[token] end
    ns.TRP3, trp3Options = nil, {}
    stylingEnabled, categoryMode, showBar, dimBackground = true, "active", true, false
    appearance.namePlacement, appearance.nameSize, appearance.healthBarWidth = "ABOVE", 18, 100
    for index = 1, 12 do
        local token, frame = "nameplate" .. (300 + index), Region()
        frame.unit, frame.name, frame.healthBar, frame.HealthBarsContainer = token, Region(), Region(), Region()
        frame.name:SetFont("Native", 10, ""); frame.name:SetTextColor(1, 1, 1)
        frame.name:SetVertexColor(1, 1, 1, 1); frame.name:SetText("Native")
        list[index], unit.names[token], guid[token] = {UnitFrame = frame}, "Global " .. index, "Creature-Global-" .. index
        byUnit[token] = list[index]
    end
    ns.RefreshAll() -- Characterization wrapper explicitly settles initialization.
    local savedCount, served = ns.Profiler.Count, 0
    ns.Profiler.Count = function(group, reason)
        if group == "Global refresh plates" then served = served + 1 end
        savedCount(group, reason)
    end
    local function Frame() served = 0; events.scripts.OnUpdate(events, 0.001); return served end
    local function Settle()
        for _ = 1, 30 do assert(Frame() <= 4, "deferred global jobs obey shared cap") end
    end
    appearance.nameSize = 22; ns.QueueNameplateRefresh("crowded global test")
    assert(Frame() <= 4, "global fan-out does not style every plate immediately")
    assert(scheduler.Has("global refresh", list[12]), "global tail remains queued")
    -- Merge a focused global callback and immediate unit name event into an
    -- older full request, consuming it once instead of updating it twice.
    unit.names.nameplate312 = "Urgent global name"
    ns.RefreshNameplateData({name = true})
    events.scripts.OnEvent(events, "UNIT_NAME_UPDATE", "nameplate312")
    Frame()
    equal(list[12].UnitFrame.name.text, "Urgent global name", "unit event bypasses global backlog")
    equal(list[12].UnitFrame.name.size, 22, "unit update consumes pending full settings work")
    assert(not scheduler.Has("global refresh", list[12]), "consumed unit work cancels duplicate global job")
    Settle()
    for _, plate in ipairs(list) do equal(plate.UnitFrame.name.size, 22, "all coalesced global requests converge") end
    -- Current and previous target plates refresh ahead of the bounded tail.
    priority = list[12]; appearance.nameSize = 24; ns.QueueNameplateRefresh("target priority")
    assert(Frame() <= 5, "one target plus four deferred jobs is bounded")
    equal(priority.UnitFrame.name.size, 24, "current target updates immediately")
    Settle()
    local oldPriority = priority; priority = list[11]
    appearance.nameSize = 26; ns.QueueNameplateRefresh("previous target priority")
    assert(Frame() <= 6, "two priority plates plus deferred jobs remain limited")
    equal(oldPriority.UnitFrame.name.size, 26, "previous target updates immediately")
    equal(priority.UnitFrame.name.size, 26, "new target updates immediately")
    Settle(); priority = nil
    -- A missing removal event is still caught by assignment/GUID validation.
    appearance.nameSize = 28; ns.QueueNameplateRefresh("stale global work")
    Frame()
    local stale = list[10]; local originalSize = stale.UnitFrame.name.size
    guid[stale.UnitFrame.unit] = "Creature-Recycled-Same-Token"
    Settle()
    equal(stale.UnitFrame.name.size, originalSize, "stale global GUID performs no writes")
    -- A failed native write preserves the error, pending flags and retry job.
    local failedPlate, failure = list[9], {}
    local setter = failedPlate.UnitFrame.name.SetFont
    failedPlate.UnitFrame.name.SetFont = function() error(failure) end
    appearance.nameSize = 29; ns.QueueNameplateRefresh("failed global write")
    local failed
    for _ = 1, 8 do
        local ok, err = pcall(Frame)
        if not ok then assert(err == failure, "global retry retains original error"); failed = true; break end
    end
    assert(failed and scheduler.Has("global refresh", failedPlate), "failed global job remains queued")
    assert(not failedPlate.UnitFrame.RPSNApplyingStyle, "failed global write releases style guard")
    failedPlate.UnitFrame.name.SetFont = setter
    events.scripts.OnUpdate(events, 0.25); Settle()
    equal(failedPlate.UnitFrame.name.size, 29, "failed global job retries its original work")
    -- Removal cancels its deferred record. Disabled styling cancels all work.
    appearance.nameSize = 30; ns.QueueNameplateRefresh("departed global work")
    Frame()
    events.scripts.OnEvent(events, "NAME_PLATE_UNIT_REMOVED", "nameplate310")
    assert(not scheduler.Has("global refresh", stale), "unit removal cancels deferred global refresh")
    local departed = list[9]; table.remove(list, 9)
    events.scripts.OnUpdate(events, 0.25)
    assert(not scheduler.Has("global refresh", departed), "snapshot cancels departed global work without a removal event")
    stylingEnabled = false; ns.RestoreAll()
    for _, plate in ipairs(list) do assert(not scheduler.Has("global refresh", plate), "disable clears global backlog") end
    stylingEnabled = true
    ns.Profiler.Count, GetTimePreciseSec = savedCount, savedClock
    C_NamePlate.GetNamePlates, C_NamePlate.GetNamePlateForUnit = savedList, savedLookup
end

-- Selective appearance must survive visibility callbacks and artwork work.
do
    stylingEnabled, categoryMode, showBar, dimBackground = true, "active", true, true
    appearance.namePlacement, appearance.nameFont, appearance.nameSize = "INSIDE", "ARIALN", 18
    unit = {reaction = 5, names = {nameplate701 = "Finalization citizen"}}
    UnitGUID = function() return "Creature-Finalization" end
    UnitNameplateShowsWidgetsOnly = function() return false end
    ns.TRP3, trp3Options = nil, {}
    local frame, bar, label = Region(), Region(), Region()
    frame.unit, frame.name, frame.healthBar = "nameplate701", Region(), bar
    frame.HealthBarsContainer = Region(); frame.HealthBarsContainer.healthBar = bar
    label.font, label.size, label.flags = "Native health font", 12, ""
    bar.Text = label
    local plate = {UnitFrame = frame}
    C_NamePlate.GetNamePlateForUnit = function() return plate end
    C_NamePlate.GetNamePlates = function() return {plate} end
    local resetColor, resetAlpha = true, true
    local labelFont = label.SetFont
    label.SetFont = function(self, ...)
        labelFont(self, ...)
        -- Native callback raw state deliberately bypasses Lua setter hooks.
        if resetColor then frame.name.r, frame.name.g, frame.name.b = 1, 1, 1 end
        if resetAlpha then frame.name.alpha = 1 end
    end
    ns.NameplatePresentation.ApplySimpleStyle(frame)
    local name, expected, text, cap, context = frame.name, frame.RPSNNameStyle,
        ns.NameplateText, ns.PresentationCapabilities, ns.WorldContext.Get()
    assert(expected.inside)
    equal(name.r, 153 / 255, "full style establishes dim native appearance")
    equal(name.alpha, 0, "full style conceals native inside name")
    local fontWrites, colorWrites, alphaWrites = 0, 0, 0
    local fontSetter, colorSetter, alphaSetter = name.SetFont, name.SetTextColor, name.SetAlpha
    name.SetFont = function(self, ...) fontWrites = fontWrites + 1; return fontSetter(self, ...) end
    name.SetTextColor = function(self, ...) colorWrites = colorWrites + 1; return colorSetter(self, ...) end
    name.SetAlpha = function(self, ...) alphaWrites = alphaWrites + 1; return alphaSetter(self, ...) end
    local shownSetter = name.SetShown
    name.SetShown = function(self, shown)
        shownSetter(self, shown)
        if shown then self.r, self.g, self.b, self.alpha = 1, 1, 1, 1 end
    end
    name.shown, name.r, name.g, name.b, name.alpha = false, 1, 1, 1, 1
    local assessment = cap.InspectFrame(frame, context)
    local drifted, _, plan = text.CachedNameHasDrifted(frame, context, assessment)
    assert(drifted and plan.shown and plan.color and plan.alpha == 0)
    assert(text.RepairCachedName(frame, context, assessment, plan))
    equal(name.r, expected.r, "selective color survives raw visibility callback")
    equal(name.alpha, 0, "selective alpha survives raw visibility callback")
    equal(fontWrites, 0, "visibility repair does not rewrite native name font")
    name.SetShown = shownSetter
    -- An independent artwork update may reset the name via native callbacks.
    ns.NameplateFrames.ApplyBarArtwork(frame, cap.InspectFrame(frame, context), context)
    equal(name.r, expected.r, "standalone artwork cannot finish with a white background name")
    equal(name.alpha, 0, "standalone artwork cannot expose native inside name")
    equal(fontWrites, 0, "artwork finalization avoids name font writes")
    resetColor = false
    local colors = colorWrites
    ns.NameplateFrames.ApplyBarArtwork(frame, cap.InspectFrame(frame, context), context)
    equal(name.alpha, 0, "alpha-only artwork callback repaired")
    equal(colorWrites, colors, "alpha-only finalization avoids color writes")
    resetAlpha = false
    colors = colorWrites; local alphas = alphaWrites
    ns.NameplateFrames.ApplyBarArtwork(frame, cap.InspectFrame(frame, context), context)
    equal(colorWrites, colors, "converged artwork has no extra color write")
    equal(alphaWrites, alphas, "converged artwork has no extra alpha write")
    -- Pending artwork is consumed before cached repair declares completion.
    resetColor, resetAlpha = true, true
    name.r, name.g, name.b = 1, 1, 1
    assessment = cap.InspectFrame(frame, context)
    drifted, _, plan = text.CachedNameHasDrifted(frame, context, assessment)
    assert(drifted and plan.color)
    frame.RPSNArtworkPending = true
    assert(text.RepairCachedName(frame, context, assessment, plan))
    assert(not frame.RPSNArtworkPending, "selective repair drains pending artwork")
    equal(name.r, expected.r, "pending artwork cannot undo selective color")
    equal(name.alpha, 0, "pending artwork cannot undo selective alpha")
    assert(not text.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context)), "combined repair converges")
    -- Finalization is bounded and conservative when evidence/access is absent.
    local colorGet, vertexGet, alphaGet = name.GetTextColor, name.GetVertexColor, name.GetAlpha
    name.GetTextColor = function() return {}, {}, {} end
    name.GetVertexColor = function() return {}, {}, {}, {} end
    name.GetAlpha = function() return 0/0 end
    colors, alphas = colorWrites, alphaWrites
    text.FinishCachedAppearance(frame, context)
    equal(colorWrites, colors, "unknown final color not guessed")
    equal(alphaWrites, alphas, "unknown final alpha not guessed")
    name.GetTextColor, name.GetVertexColor, name.GetAlpha = colorGet, vertexGet, alphaGet
    expected.unknownReads = nil
    name.r, name.g, name.b, name.alpha = 1, 1, 1, 1
    stylingEnabled = false; text.FinishCachedAppearance(frame, context); stylingEnabled = true
    frame.RPSNRestoring = true; text.FinishCachedAppearance(frame, context); frame.RPSNRestoring = nil
    name.IsForbidden = function() return true end; text.FinishCachedAppearance(frame, context); name.IsForbidden = nil
    UnitGUID = function() return "Creature-Recycled" end; text.FinishCachedAppearance(frame, context)
    UnitGUID = function() return "Creature-Finalization" end
    local revision = frame.RPSNPresentation.contextRevision
    frame.RPSNPresentation.contextRevision = -1; text.FinishCachedAppearance(frame, context)
    frame.RPSNPresentation.contextRevision = revision
    equal(colorWrites, colors, "invalid finalization performs no color writes")
    equal(alphaWrites, alphas, "invalid finalization performs no alpha writes")
    -- A native write failure releases the bounded finalization/appearance guards.
    local failure = {}
    name.SetTextColor = function() error(failure) end
    local ok, err = pcall(text.FinishCachedAppearance, frame, context)
    assert(not ok and err == failure and not frame.RPSNFinishingNameAppearance
        and not frame.RPSNRepairingNameAppearance, "failed finalization releases guards and preserves error")
    name.SetTextColor = colorSetter
    text.FinishCachedAppearance(frame, context)
    equal(name.r, expected.r, "failed finalization can recover")
end

-- Distance/detail changes can leave shown bars transparent. Repair without
-- targeting, keep whole-unit fades native, and restore the captured opacity.
do
    local frame = Region()
    frame.unit, frame.name = "nameplate1", Region()
    frame.healthBar, frame.HealthBarsContainer = Region(), Region()
    frame.name:SetFont("NativeFont", 10, "")
    frame.name:SetText("Watcher")
    frame.name:SetTextColor(1, 0, 0)
    frame.healthBar:SetStatusBarColor(1, 0, 0)
    frame.healthBar.alpha, frame.HealthBarsContainer.alpha = 0.4, 0.6
    frame.alpha = 0.7
    unit = {reaction = 3, names = {nameplate1 = "Watcher"}}
    appearance.namePlacement = "INSIDE"
    local context = ns.WorldContext.Get()
    local cap, text = ns.PresentationCapabilities, ns.NameplateText
    ns.NameplatePresentation.ApplySimpleStyle(frame, context, "opacity regression")
    assert(frame.RPSNNameStyle.inside, "opacity fixture uses inside name")
    equal(frame.healthBar.alpha, 1, "initial transparent bar repaired")
    equal(frame.HealthBarsContainer.alpha, 1, "initial transparent container repaired")
    equal(frame.alpha, 0.7, "whole-unit fade remains native")
    -- Raw assignments simulate native changes that bypass Lua setter hooks.
    frame.healthBar.alpha, frame.HealthBarsContainer.alpha, frame.RPSNInsideName.alpha = 0, 0, 0
    local assessment = cap.InspectFrame(frame, context)
    local drifted, _, plan = text.CachedNameHasDrifted(frame, context, assessment)
    assert(drifted and plan.barAlpha == 1 and plan.containerAlpha == 1 and plan.insideAlpha == 1)
    assert(text.RepairCachedName(frame, context, assessment, plan))
    equal(frame.healthBar.alpha, 1, "untargeted bar opacity recovered")
    equal(frame.HealthBarsContainer.alpha, 1, "untargeted ancestor opacity recovered")
    equal(frame.RPSNInsideName.alpha, 1, "untargeted inside name opacity recovered")
    assert(not text.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context)), "opacity repair converges")
    -- Explicit alpha setters get immediate recovery as well.
    frame.HealthBarsContainer.alpha = 0
    for _, hook in ipairs(hooks) do
        if hook.name == frame.HealthBarsContainer and hook.method == "SetAlpha" then hook.callback() end
    end
    equal(frame.HealthBarsContainer.alpha, 1, "container alpha hook repairs immediately")
    frame.HealthBarsContainer:Hide()
    equal(frame.HealthBarsContainer.shown, true, "container hide repairs immediately")
    assert(ns.NameplateRestoration.Request(frame, context))
    equal(frame.healthBar.alpha, 0.4, "native bar opacity restored")
    equal(frame.HealthBarsContainer.alpha, 0.6, "native container opacity restored")
    equal(frame.RPSNInsideName.shown, false, "replacement hidden on restoration")
end

-- Nearby diagnostics must preserve a vanished untargeted plate: no direct
-- lookup, classification, tooltip reads, timers, hooks or presentation writes.
do
    local base, frame, container, bar, inside = Region(), Region(), Region(), Region(), Region()
    base.UnitFrame, frame.unit = frame, "nameplate1"
    frame.name, frame.HealthBarsContainer, frame.healthBar, frame.RPSNInsideName = Region(), container, bar, inside
    frame.RPSNState, frame.RPSNNameStyle = "hostile", {inside = true}
    frame.alpha = 0
    function inside:GetParent() return bar end
    function bar:GetParent() return container end
    function container:GetParent() return frame end
    function frame:GetParent() return base end
    function inside:GetEffectiveAlpha() return 0 end
    local getPlates, getPlate, getName = C_NamePlate.GetNamePlates, C_NamePlate.GetNamePlateForUnit, UnitName
    C_NamePlate.GetNamePlates = function() return {base, base} end
    C_NamePlate.GetNamePlateForUnit = function() error("nearby snapshot must not perform native unit lookup") end
    unit.names = {nameplate1 = "Citadel Watcher"}
    UnitName = function() return "Citadel Watcher" end
    local hookCount, timerCount, frameCount = #hooks, #timers, #frames
    for _, region in ipairs({base, frame, frame.name, container, bar, inside}) do
        for _, method in ipairs({"Show", "Hide", "SetAlpha", "SetText", "SetFont", "SetPoint", "SetShown"}) do
            region[method] = function() error("nearby snapshot must not write presentation") end
        end
    end
    local lines, outputPrint = {}, print
    print = function(line) lines[#lines + 1] = line end
    ns.DebugNearby("CITADEL WATCHER")
    local report = table.concat(lines, "\n")
    assert(report:find("Matching plates: 1", 1, true), "nearby enumeration deduplicates")
    assert(report:find("Unit frame: access accessible; shown yes; visible yes; alpha 0", 1, true), "nearby captures vanished ancestor alpha")
    assert(report:find("effective alpha 0", 1, true), "nearby captures inherited invisibility")
    equal(frame.alpha, 0, "nearby snapshot leaves failure intact")
    lines = {}; ns.DebugNearby("watcher[")
    assert(table.concat(lines, "\n"):find("Matching plates: 0", 1, true), "nearby filter is literal")
    print = outputPrint
    equal(#hooks, hookCount, "nearby adds no hooks")
    equal(#timers, timerCount, "nearby adds no timers")
    equal(#frames, frameCount, "nearby creates no frames")
    C_NamePlate.GetNamePlates, C_NamePlate.GetNamePlateForUnit, UnitName = getPlates, getPlate, getName
end

-- Native horizontal anchors can supply all width, with no explicit width.
-- Height-only styling must preserve it at the default 100% width setting.
do
    local frame = Region()
    frame.unit, frame.name, frame.healthBar, frame.HealthBarsContainer = "nameplate1", Region(), Region(), Region()
    frame.name:SetFont("Native", 10, ""); frame.name:SetTextColor(1, 0, 0)
    frame.name:SetVertexColor(1, 1, 1, 1)
    local bar, container = frame.healthBar, frame.HealthBarsContainer
    for _, region in ipairs({bar, container}) do
        function region:ClearAllPoints() self.points = {}; self.width = 0 end
        function region:SetPoint(...)
            self.points[#self.points + 1] = {...}
            if #self.points == 2 then self.width = 140 end
        end
    end
    local function NativeAnchors()
        container:ClearAllPoints()
        container:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        container:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    end
    stylingEnabled, categoryMode, showBar, dimBackground = true, "active", true, false
    appearance.namePlacement, appearance.healthBarWidth = "INSIDE", 100
    unit = {reaction = 3, names = {nameplate1 = "Citadel Watcher"}}
    UnitGUID = function() return "Creature-AnchorWidth" end
    local context, cap, text = ns.WorldContext.Get(), ns.PresentationCapabilities, ns.NameplateText
    NativeAnchors()
    ns.NameplatePresentation.ApplySimpleStyle(frame, context)
    equal(bar.width, 140, "height-only anchor release preserves bar width")
    equal(container.width, 140, "height-only anchor release preserves container width")
    equal(frame.RPSNNameStyle.barWidth, 140, "100% width participates in reconciliation")
    equal(frame.RPSNNameStyle.containerWidth, 140, "100% container participates in reconciliation")
    equal(frame.RPSNInsideName.shown, true, "inside name survives initial styling")
    bar.width, container.width = 0, 0
    local assessment = cap.InspectFrame(frame, context)
    local drifted, _, plan = text.CachedNameHasDrifted(frame, context, assessment)
    assert(drifted and plan.barWidth == 140 and plan.containerWidth == 140)
    assert(text.RepairCachedName(frame, context, assessment, plan))
    equal(bar.width, 140, "collapsed bar recovers without targeting")
    equal(container.width, 140, "collapsed container recovers without targeting")
    assert(not text.CachedNameHasDrifted(frame, context, cap.InspectFrame(frame, context)), "width repair converges")
    ns.NameplatePresentation.ApplySimpleStyle(frame, context)
    equal(bar.width, 140, "repeated full styling preserves native width")
    assert(ns.NameplateRestoration.Request(frame, context))
    equal(#bar.points, 2, "native bar anchors restored")
    equal(#container.points, 2, "native container anchors restored")
    -- A not-yet-measurable native bar retains its anchors for a later retry.
    NativeAnchors(); bar.width = 0
    local points = bar.points
    assert(not ns.NameplateFrames.PrepareBarSize(frame, bar, context))
    equal(bar.points, points, "zero-width initialization does not release native anchors")
end

print("Nameplates smoke: passed")
