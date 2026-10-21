-- Theme boundaries, safe parsing, reset isolation and per-character activation.
local character = "Player-One"
function UnitGUID() return character end
function strtrim(text) return text:match("^%s*(.-)%s*$") end
local function Load()
    local ns = {}
    for _, name in ipairs({"Defaults", "FontMedia", "Core", "ManagedNames", "Database", "Themes"}) do
        assert(loadfile("RPSimpleNameplates/" .. name .. ".lua"))("RPSimpleNameplates", ns)
    end
    return ns
end
local function Snapshot(value)
    if type(value) == "number" then return string.format("%.17g", value) end
    if type(value) ~= "table" then return tostring(value) end
    local parts = {}
    for key, item in pairs(value) do parts[#parts+1] = key .. "=" .. Snapshot(item) end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end
SimpleNameplatesDB = {global={stylingEnabled=false}, characterEnabled={["Player-Bad"]="false"}}
local ns = Load()
assert(ns.GetStylingEnabled(), "new character defaults enabled independently of retired global flag")
ns.SetStylingEnabled(false)
assert(not ns.GetStylingEnabled())
assert(ns.CreateProfile("Custom")); assert(not ns.GetStylingEnabled(), "profile creation does not enable character")
character = "Player-Two"
assert(ns.GetStylingEnabled() and ns.GetActiveProfileName() == "Default")
ns.SetActiveProfileName("Custom")
assert(ns.GetStylingEnabled(), "shared profile has independent character activation")
character = "Player-One"
ns = Load()
assert(not ns.GetStylingEnabled() and ns.GetActiveProfileName() == "Custom", "reload retains character preference")
character = "Player-Bad"
assert(ns.GetStylingEnabled(), "invalid character preference defaults on")
character = "Player-One"
ns.SetAppearanceSetting("nameSize", 29)
ns.SetAppearanceSetting("healthBarWidth", 145)
ns.SetPriorityColor("hostile", 0.2, 0.3, 0.4)
ns.SetHealthBarEnabled("neutral", false)
ns.SetGradientOpacity(37)
ns.SetThreatEnabled(false)
ns.SetEffectColor("interruptible", 0.5, 0.6, 0.7)
ns.SetInterruptibleEffect("ALERT")
ns.SetInterruptibleHighlightEnabled(true)
ns.SetCastBorderSetting("ALERT", "minLength", 35)
-- Preserve unavailable shared font registrations, including escaped delimiters.
ns.GetProfile("Custom").appearance.nameFont = "LSM:A=B%Font"
ns.SetTRP3Enabled(true)
local original, globals = Snapshot(ns.GetThemeData()), Snapshot(ns.EnsureDB().global)
local exported = ns.ExportTheme()
assert(not exported:find("stylingEnabled") and not exported:find("characterEnabled") and not exported:find("trp3"))
local theme = assert(ns.DecodeTheme(exported))
assert(Snapshot(theme) == original, "all visual fields round-trip exactly")
ns.ApplyThemeData(theme)
assert(ns.ExportTheme() == exported, "deterministic export")
assert(not ns.GetStylingEnabled() and Snapshot(ns.EnsureDB().global) == globals)
assert(ns.GetActiveProfileName() == "Custom")
theme.appearance.nameSize = 8
assert(ns.GetAppearanceSetting("nameSize") == 29, "import does not retain source references")
local before = Snapshot(ns.EnsureDB())
for _, bad in ipairs({"return os.execute('bad')", "RPSN-THEME:2\na=1", "RPSN-THEME:1\na=1", "RPSN-THEME:1\nappearance.nameSize=20\nappearance.nameSize=21", "RPSN-THEME:1\nappearance.nameFont=LSM:%XX", string.rep("x", 16385)}) do
    assert(not ns.DecodeTheme(bad), "malformed theme rejected")
    assert(Snapshot(ns.EnsureDB()) == before, "decode never mutates saved data")
end
local sanitized = assert(ns.DecodeTheme("RPSN-THEME:1\nappearance.nameSize=999\ngradientOpacity=nan\ninterruptibleHighlight=invalid\ncharacterEnabled.PlayerOne=true\nshowThreat=false"))
assert(sanitized.appearance.nameSize == 18 and sanitized.gradientOpacity == 100)
assert(not sanitized.interruptibleHighlight and not sanitized.showThreat and not sanitized.characterEnabled)
-- Each tab reset changes only that tab's settings.
local cast = Snapshot({color=ns.GetThemeData().effectColors, advanced=ns.GetThemeData().castAdvanced, effect=ns.GetInterruptibleEffect(), enabled=ns.GetInterruptibleHighlightEnabled()})
ns.ResetAllColors()
assert(Snapshot({color=ns.GetThemeData().effectColors, advanced=ns.GetThemeData().castAdvanced, effect=ns.GetInterruptibleEffect(), enabled=ns.GetInterruptibleHighlightEnabled()}) == cast)
assert(ns.GetAppearanceSetting("nameSize") == 29 and not ns.GetThreatEnabled())
ns.SetGradientOpacity(42)
ns.ResetAppearance()
assert(ns.GetGradientOpacity() == 42 and ns.GetInterruptibleHighlightEnabled())
local text, color = Snapshot(ns.GetThemeData().appearance), Snapshot(ns.GetThemeData().priorityColors)
ns.ResetHighlightSettings()
assert(not ns.GetInterruptibleHighlightEnabled() and ns.GetInterruptibleEffect() == "PULSE")
assert(select(1, ns.EffectColor("interruptible")) == 0.2)
assert(Snapshot(ns.GetThemeData().appearance) == text and Snapshot(ns.GetThemeData().priorityColors) == color and ns.GetGradientOpacity() == 42)
assert(not ns.GetStylingEnabled() and Snapshot(ns.EnsureDB().global) == globals)
print("Theme exchange and character settings smoke: passed")
