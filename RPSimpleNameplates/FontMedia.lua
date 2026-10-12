-- Simple Nameplates: built-in font compatibility and shared-media choices.
local _, ns = ...
local builtins = ns.Defaults.fontByValue
local media = LibStub and LibStub("LibSharedMedia-3.0", true)
local PREFIX = "LSM:"
local builtinLabels = {}
for _, option in ipairs(ns.FONT_OPTIONS) do builtinLabels[option.label] = true end

local function IsFontPath(path)
    return type(path) == "string" and path ~= ""
end

local function SharedLabel(key)
    return builtinLabels[key] and key .. " (shared)" or key
end

local function SharedKey(value)
    if type(value) == "string" and #value > #PREFIX and #value <= 256
        and value:sub(1, #PREFIX) == PREFIX and not value:find("[%c]") then
        return value:sub(#PREFIX + 1)
    end
end

local function SharedPath(key)
    if not media or not key then return end
    local fonts = media:HashTable("font")
    -- Validate the selected registration itself: Fetch may return a global
    -- override even when this key's data is empty or isn't a font path.
    if not fonts or not IsFontPath(fonts[key]) then return end
    local path = media:Fetch("font", key, true)
    if IsFontPath(path) then return path end
end

-- Preserve a saved shared key even before its supplying addon has loaded.
local function IsSavedFontSelection(value)
    return type(value) == "string" and (builtins[value] ~= nil or SharedKey(value) ~= nil)
end

local function IsAvailableFontSelection(value)
    if type(value) ~= "string" then return false end
    return builtins[value] ~= nil or SharedPath(SharedKey(value)) ~= nil
end

local function FontLabel(value)
    local builtin = builtins[value]
    if builtin then return builtin.label end
    local key = SharedKey(value)
    if not key then return "" end
    if not SharedPath(key) then return key .. " (unavailable)" end
    return SharedLabel(key)
end

local function FontPath(value)
    local builtin = builtins[value]
    if builtin then return builtin.path end
    return SharedPath(SharedKey(value)) or builtins.ARIALN.path
end

local function GetFontOptions(selected)
    local options, paths = {}, {}
    for _, option in ipairs(ns.FONT_OPTIONS) do
        options[#options + 1] = option
        paths[option.path:lower()] = true
    end
    local found = builtins[selected] ~= nil
    if media then
        local fonts = media:HashTable("font") or {}
        for _, key in ipairs(media:List("font") or {}) do
            local path = fonts[key]
            local value = PREFIX .. key
            if SharedKey(value) and IsFontPath(path)
                and (not paths[path:lower()] or value == selected) then
                options[#options + 1] = {value = value, label = SharedLabel(key), path = path}
                paths[path:lower()] = true
                if value == selected then found = true end
            end
        end
    end
    if not found and SharedKey(selected) then
        options[#options + 1] = {value = selected, label = SharedKey(selected) .. " (unavailable)"}
    end
    table.sort(options, function(a, b)
        if a.label == b.label then return a.value < b.value end
        return a.label < b.label
    end)
    return options
end

local function SelectedSharedFontChanged(event, key)
    if not ns.GetAppearanceSetting then return false end
    local name = SharedKey(ns.GetAppearanceSetting("nameFont"))
    local threat = SharedKey(ns.GetAppearanceSetting("threatFont"))
    if not name and not threat then return false end
    if event == "LibSharedMedia_Registered" then return key == name or key == threat end
    return true -- A global override affects every selected shared font.
end

if media then
    local function MediaChanged(event, mediatype, key)
        if mediatype ~= "font" then return end
        if ns.RefreshFontControls then ns.RefreshFontControls() end
        if ns.QueueNameplateRefresh and SelectedSharedFontChanged(event, key) then
            ns.QueueNameplateRefresh()
        end
    end
    media.RegisterCallback(ns, "LibSharedMedia_Registered", MediaChanged)
    media.RegisterCallback(ns, "LibSharedMedia_SetGlobal", MediaChanged)
end

ns.IsSavedFontSelection = IsSavedFontSelection
ns.IsAvailableFontSelection = IsAvailableFontSelection
ns.FontLabel = FontLabel
ns.FontPath = FontPath
ns.GetFontOptions = GetFontOptions
