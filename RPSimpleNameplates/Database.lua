-- Simple Nameplates: version-2 saved data, profiles, and settings access.
local _, ns = ...
local defaults = ns.Defaults
local DEFAULT_PRIORITY_COLORS = defaults.priorityColors
local DEFAULT_CATEGORY_MODES = defaults.categoryModes
local DEFAULT_HEALTH_BARS = defaults.healthBars
local DEFAULT_DIM_BACKGROUND_NAMES = defaults.dimBackgroundNames
local DEFAULT_EFFECT_COLORS = defaults.effectColors
local CAST_BORDER_CONTROLS = ns.CAST_BORDER_CONTROLS
local COLOR_PRESETS = defaults.colorPresets
local IsSavedFontSelection = ns.IsSavedFontSelection
local IsAvailableFontSelection = ns.IsAvailableFontSelection
local DEFAULT_APPEARANCE = defaults.appearance
local DEFAULT_TRP3 = defaults.trp3
local DEFAULT_STYLING_ENABLED = defaults.stylingEnabled
local DEFAULT_SHOW_THREAT = defaults.showThreat
local DEFAULT_HIDE_CRITTER_COMPANION_NAMES = defaults.hideCritterCompanionNames
local MIN_NAME_SIZE, MAX_NAME_SIZE = ns.MIN_NAME_SIZE, ns.MAX_NAME_SIZE
local MIN_BAR_WIDTH, MAX_BAR_WIDTH = ns.MIN_HEALTH_BAR_WIDTH, ns.MAX_HEALTH_BAR_WIDTH
local MANAGED_NAME_CVARS = ns.MANAGED_NAME_CVARS

local dbReady = false
local DB_SCHEMA_VERSION = 2
local DEFAULT_PROFILE_NAME = "Default"
local HIGH_CONTRAST_PROFILE_NAME = "High Contrast"
local MAX_PROFILE_NAME_LENGTH = 64

local function IsFiniteNumber(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function IsValidColor(color)
    return type(color) == "table"
        and IsFiniteNumber(color.r) and color.r >= 0 and color.r <= 1
        and IsFiniteNumber(color.g) and color.g >= 0 and color.g <= 1
        and IsFiniteNumber(color.b) and color.b >= 0 and color.b <= 1
end

local function CopyColor(color)
    return { r = color.r, g = color.g, b = color.b }
end


local function SavedBoolean(value, default)
    if type(value) == "boolean" then return value end
    return default
end

local function CopySavedCVarOriginals(source, allowedCVars)
    if type(source) ~= "table" then return nil end

    local copy
    for _, cvar in ipairs(allowedCVars) do
        local value = source[cvar]
        local valueType = type(value)
        if valueType == "string" or valueType == "number" or valueType == "boolean" then
            copy = copy or {}
            copy[cvar] = value
        end
    end
    return copy
end


local function ValidatedCastBorders(saved)
    saved = type(saved) == "table" and saved or {}
    local result = {}
    for effect, controls in pairs(CAST_BORDER_CONTROLS) do
        local source = type(saved[effect]) == "table" and saved[effect] or {}
        result[effect] = {}
        for _, control in ipairs(controls) do
            local value = source[control.key]
            if IsFiniteNumber(value) and value >= control.min and value <= control.max then
                result[effect][control.key] = value
            else
                result[effect][control.key] = control.default
            end
        end
    end
    if result.ALERT.minLength > result.ALERT.maxLength then
        result.ALERT.minLength, result.ALERT.maxLength = 20, 100
    end
    return result
end

local function NewProfile(presetName)
    local preset = presetName and COLOR_PRESETS[presetName] or nil
    local profile = {
        priorityColors = {},
        effectColors = {},
        healthBars = {},
        appearance = {},
        showThreat = DEFAULT_SHOW_THREAT,
        gradientOpacity = preset and preset.gradientOpacity or defaults.gradientOpacity,
        dimBackgroundNames = DEFAULT_DIM_BACKGROUND_NAMES,
        interruptibleHighlight = defaults.interruptibleHighlight,
        interruptibleEffect = defaults.interruptibleEffect,
        -- Retain the existing location for valid border values; no migration.
        castAdvanced = ValidatedCastBorders(),
    }
    for key, default in pairs(DEFAULT_PRIORITY_COLORS) do
        local color = preset and preset.priorityColors and preset.priorityColors[key] or default
        profile.priorityColors[key] = CopyColor(color)
        profile.healthBars[key] = DEFAULT_HEALTH_BARS[key]
    end
    for key, default in pairs(DEFAULT_EFFECT_COLORS) do
        local color = preset and preset.effectColors and preset.effectColors[key] or default
        profile.effectColors[key] = CopyColor(color)
    end
    for key, value in pairs(DEFAULT_APPEARANCE) do
        profile.appearance[key] = preset and preset.appearance and preset.appearance[key] or value
    end
    return profile
end

local function ValidateProfileColors(profile, saved)
    local savedPriorityColors = type(saved.priorityColors) == "table"
        and saved.priorityColors or {}
    for key, default in pairs(profile.priorityColors) do
        local color = savedPriorityColors[key]
        profile.priorityColors[key] = CopyColor(IsValidColor(color) and color or default)
    end

    local savedEffectColors = type(saved.effectColors) == "table" and saved.effectColors or {}
    for key, default in pairs(profile.effectColors) do
        local color = savedEffectColors[key]
        profile.effectColors[key] = CopyColor(IsValidColor(color) and color or default)
    end
end

local function ValidateProfileAppearance(profile, saved)
    local savedAppearance = type(saved.appearance) == "table" and saved.appearance or {}
    profile.appearance.matchSanctuaryFont = SavedBoolean(savedAppearance.matchSanctuaryFont,
        profile.appearance.matchSanctuaryFont)
    profile.appearance.useSlugRendering = SavedBoolean(savedAppearance.useSlugRendering,
        profile.appearance.useSlugRendering)
    profile.appearance.nameFont = IsSavedFontSelection(savedAppearance.nameFont)
        and savedAppearance.nameFont or profile.appearance.nameFont
    if IsFiniteNumber(savedAppearance.nameSize)
        and savedAppearance.nameSize >= MIN_NAME_SIZE
        and savedAppearance.nameSize <= MAX_NAME_SIZE then
        profile.appearance.nameSize = math.floor(savedAppearance.nameSize + 0.5)
    end
    if IsFiniteNumber(savedAppearance.healthBarWidth)
        and savedAppearance.healthBarWidth >= MIN_BAR_WIDTH and savedAppearance.healthBarWidth <= MAX_BAR_WIDTH then
        profile.appearance.healthBarWidth = math.floor(savedAppearance.healthBarWidth / 5 + 0.5) * 5
    end
    profile.appearance.threatFont = IsSavedFontSelection(savedAppearance.threatFont)
        and savedAppearance.threatFont or profile.appearance.threatFont
    if savedAppearance.namePlacement == "ABOVE" or savedAppearance.namePlacement == "INSIDE" then
        profile.appearance.namePlacement = savedAppearance.namePlacement
    end
end

local function ValidateProfileToggles(profile, saved)
    if ns.CAST_EFFECT_BY_VALUE[saved.interruptibleEffect] then
        profile.interruptibleEffect = saved.interruptibleEffect
    end
    local savedBars = type(saved.healthBars) == "table" and saved.healthBars or {}
    for key in pairs(DEFAULT_PRIORITY_COLORS) do
        profile.healthBars[key] = SavedBoolean(savedBars[key], DEFAULT_HEALTH_BARS[key])
    end
    if IsFiniteNumber(saved.gradientOpacity) and saved.gradientOpacity >= 0 and saved.gradientOpacity <= 100 then
        profile.gradientOpacity = math.floor(saved.gradientOpacity + 0.5)
    end
    profile.dimBackgroundNames = SavedBoolean(saved.dimBackgroundNames, DEFAULT_DIM_BACKGROUND_NAMES)
    profile.showThreat = SavedBoolean(saved.showThreat, profile.showThreat)
    if type(saved.interruptibleHighlight) == "boolean" then
        profile.interruptibleHighlight = saved.interruptibleHighlight
    end
end

local function ValidatedProfile(saved, presetName)
    if type(saved) ~= "table" then saved = {} end
    local profile = NewProfile(presetName)
    ValidateProfileColors(profile, saved)
    ValidateProfileAppearance(profile, saved)
    ValidateProfileToggles(profile, saved)
    profile.castAdvanced = ValidatedCastBorders(saved.castAdvanced)
    return profile
end

local function CopyProfile(profile)
    return ValidatedProfile(profile)
end

local function CharacterKey()
    local guid = UnitGUID and UnitGUID("player")
    if type(guid) == "string" and guid ~= "" then return guid end
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    if type(name) == "string" and name ~= "" then
        return name .. "-" .. ((type(realm) == "string" and realm ~= "") and realm or "Unknown")
    end
    return "Unknown"
end

local function CreateValidatedDB()
    return {
        schemaVersion = DB_SCHEMA_VERSION,
        global = {
            categoryModes = {},
            trp3 = {},
        },
        profiles = {},
        profileKeys = {},
    }
end

local function ValidateProfiles(db, savedProfiles)
    db.profiles[DEFAULT_PROFILE_NAME] = ValidatedProfile(savedProfiles[DEFAULT_PROFILE_NAME])
    if savedProfiles[HIGH_CONTRAST_PROFILE_NAME] ~= nil then
        db.profiles[HIGH_CONTRAST_PROFILE_NAME] = ValidatedProfile(
            savedProfiles[HIGH_CONTRAST_PROFILE_NAME], "highContrast")
        db.global.highContrastRemoved = nil
    elseif not db.global.highContrastRemoved then
        db.profiles[HIGH_CONTRAST_PROFILE_NAME] = NewProfile("highContrast")
    end

    local knownProfileNames = {
        [string.lower(DEFAULT_PROFILE_NAME)] = true,
        [string.lower(HIGH_CONTRAST_PROFILE_NAME)] = true,
    }
    for name, profile in pairs(savedProfiles) do
        local normalized = type(name) == "string" and strtrim(name) or ""
        local lowerName = string.lower(normalized)
        if normalized == name and normalized ~= "" and #normalized <= MAX_PROFILE_NAME_LENGTH
            and not knownProfileNames[lowerName] then
            db.profiles[name] = ValidatedProfile(profile)
            knownProfileNames[lowerName] = true
        end
    end
end

local function ValidateProfileKeys(db, savedProfileKeys)
    savedProfileKeys = type(savedProfileKeys) == "table" and savedProfileKeys or {}
    for character, profileName in pairs(savedProfileKeys) do
        if type(character) == "string" and type(profileName) == "string"
            and db.profiles[profileName] then
            db.profileKeys[character] = profileName
        end
    end
end

local function ValidateCategoryModes(db, savedGlobal)
    local savedCategoryModes = type(savedGlobal.categoryModes) == "table"
        and savedGlobal.categoryModes or {}
    for key, default in pairs(DEFAULT_CATEGORY_MODES) do
        local mode = savedCategoryModes[key]
        db.global.categoryModes[key] = (mode == "active" or mode == "inactive")
            and mode or default
    end
end

local function ValidateGlobalToggles(db, savedGlobal)
    db.global.stylingEnabled = SavedBoolean(savedGlobal.stylingEnabled, DEFAULT_STYLING_ENABLED)
    db.global.hideCritterCompanionNames = SavedBoolean(savedGlobal.hideCritterCompanionNames,
        DEFAULT_HIDE_CRITTER_COMPANION_NAMES)
end

local function ValidateTRP3Settings(db, savedGlobal)
    local savedTRP3 = type(savedGlobal.trp3) == "table" and savedGlobal.trp3 or {}
    for key, default in pairs(DEFAULT_TRP3) do
        db.global.trp3[key] = SavedBoolean(savedTRP3[key], default)
    end
end

local function ValidatedDB(saved)
    -- Validate recognized settings in their current locations. Unknown or
    -- invalid values are discarded; no aliases, conversions, or migrations.
    if type(saved) ~= "table" then saved = {} end

    local savedGlobal = type(saved.global) == "table" and saved.global or {}
    local savedProfiles = type(saved.profiles) == "table" and saved.profiles or {}
    local db = CreateValidatedDB()

    -- Optional bundle removals are intentional, unlike a missing fresh default.
    if savedGlobal.highContrastRemoved == true then db.global.highContrastRemoved = true end
    ValidateProfiles(db, savedProfiles)
    ValidateProfileKeys(db, saved.profileKeys)
    ValidateCategoryModes(db, savedGlobal)
    ValidateGlobalToggles(db, savedGlobal)
    ValidateTRP3Settings(db, savedGlobal)
    db.global.managedNameCVarOriginals = CopySavedCVarOriginals(
        savedGlobal.managedNameCVarOriginals, MANAGED_NAME_CVARS) or {}
    db.global.nameplateSetupOriginals = {}
    local setupOriginals = savedGlobal.nameplateSetupOriginals
    if type(setupOriginals) == "table" and ns.NAMEPLATE_SETUP_CVARS then
        for character, originals in pairs(setupOriginals) do
            if type(character) == "string" then
                db.global.nameplateSetupOriginals[character] =
                    CopySavedCVarOriginals(originals, ns.NAMEPLATE_SETUP_CVARS)
            end
        end
    end
    return db
end

local function EnsureDB()
    if dbReady then return SimpleNameplatesDB end
    SimpleNameplatesDB = ValidatedDB(SimpleNameplatesDB)
    dbReady = true
    return SimpleNameplatesDB
end

local function GetActiveProfileName()
    local db = EnsureDB()
    local key = CharacterKey()
    local profileName = db.profileKeys[key]
    if not db.profiles[profileName] then
        profileName = DEFAULT_PROFILE_NAME
        db.profileKeys[key] = profileName
    end
    return profileName
end

local function ActiveProfile()
    local db = EnsureDB()
    return db.profiles[GetActiveProfileName()]
end

local function ActiveProfileDefaults()
    return NewProfile(GetActiveProfileName() == HIGH_CONTRAST_PROFILE_NAME
        and "highContrast" or nil)
end

local function GetProfileNames()
    local names = {}
    for name in pairs(EnsureDB().profiles) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        if a == b then return false end
        if a == DEFAULT_PROFILE_NAME then return true end
        if b == DEFAULT_PROFILE_NAME then return false end
        if a == HIGH_CONTRAST_PROFILE_NAME then return true end
        if b == HIGH_CONTRAST_PROFILE_NAME then return false end
        return string.lower(a) < string.lower(b)
    end)
    return names
end

local function FindProfileName(name)
    if type(name) ~= "string" then return nil end
    local wanted = string.lower(name)
    for existing in pairs(EnsureDB().profiles) do
        if string.lower(existing) == wanted then return existing end
    end
end

local function ValidProfileName(name, currentName)
    name = type(name) == "string" and strtrim(name) or ""
    if name == "" then return nil, "Enter a profile name." end
    if #name > MAX_PROFILE_NAME_LENGTH then
        return nil, "Profile names may contain at most 64 characters."
    end
    local existing = FindProfileName(name)
    if existing and existing ~= currentName then return nil, "That profile name is already in use." end
    return name
end

-- Cancel while the original selection and object identity still exist.
local function CancelProfileEdits()
    if ns.SettingsUI and ns.SettingsUI.CancelColorEdit then ns.SettingsUI.CancelColorEdit() end
    if ns.CancelAppearanceEdits then ns.CancelAppearanceEdits(true) end
    if ns.CancelColorsEdits then ns.CancelColorsEdits(true) end
    if ns.CancelHighlightEdits then ns.CancelHighlightEdits(true) end
end

local function CancelColorEdit()
    if ns.SettingsUI and ns.SettingsUI.CancelColorEdit then ns.SettingsUI.CancelColorEdit() end
end

local function SetActiveProfileName(name)
    local exactName = FindProfileName(name)
    if not exactName then return false, "Profile not found." end
    CancelProfileEdits()
    EnsureDB().profileKeys[CharacterKey()] = exactName
    return true
end

local function CreateProfile(name)
    local validName, errorMessage = ValidProfileName(name)
    if not validName then return false, errorMessage end
    CancelProfileEdits()
    EnsureDB().profiles[validName] = NewProfile()
    if validName == HIGH_CONTRAST_PROFILE_NAME then EnsureDB().global.highContrastRemoved = nil end
    EnsureDB().profileKeys[CharacterKey()] = validName
    return true
end

local function CopyActiveProfile(name)
    local validName, errorMessage = ValidProfileName(name)
    if not validName then return false, errorMessage end
    CancelProfileEdits()
    EnsureDB().profiles[validName] = CopyProfile(ActiveProfile())
    if validName == HIGH_CONTRAST_PROFILE_NAME then EnsureDB().global.highContrastRemoved = nil end
    EnsureDB().profileKeys[CharacterKey()] = validName
    return true
end

local function RenameActiveProfile(name)
    local db = EnsureDB()
    local oldName = GetActiveProfileName()
    if oldName == DEFAULT_PROFILE_NAME then return false, "Default cannot be renamed." end
    local validName, errorMessage = ValidProfileName(name, oldName)
    if not validName then return false, errorMessage end
    if validName == oldName then return true end
    CancelProfileEdits()
    db.profiles[validName] = db.profiles[oldName]
    db.profiles[oldName] = nil
    if oldName == HIGH_CONTRAST_PROFILE_NAME then db.global.highContrastRemoved = true end
    if validName == HIGH_CONTRAST_PROFILE_NAME then db.global.highContrastRemoved = nil end
    for character, assignedName in pairs(db.profileKeys) do
        if assignedName == oldName then db.profileKeys[character] = validName end
    end
    return true
end

local function DeleteActiveProfile()
    local db = EnsureDB()
    local name = GetActiveProfileName()
    if name == DEFAULT_PROFILE_NAME then return false, "Default cannot be deleted." end
    CancelProfileEdits()
    db.profiles[name] = nil
    if name == HIGH_CONTRAST_PROFILE_NAME then db.global.highContrastRemoved = true end
    for character, assignedName in pairs(db.profileKeys) do
        if assignedName == name then db.profileKeys[character] = DEFAULT_PROFILE_NAME end
    end
    return true
end

local function RestoreBundledProfiles()
    local db = EnsureDB()
    CancelProfileEdits()
    db.profiles[DEFAULT_PROFILE_NAME] = NewProfile()
    db.profiles[HIGH_CONTRAST_PROFILE_NAME] = NewProfile("highContrast")
    db.global.highContrastRemoved = nil
end

local function GetTRP3Enabled()
    return EnsureDB().global.trp3.enabled
end

local function SetTRP3Enabled(enabled)
    EnsureDB().global.trp3.enabled = enabled == true
end

local function GetTRP3Setting(key)
    return EnsureDB().global.trp3[key]
end

local function SetTRP3Setting(key, enabled)
    if DEFAULT_TRP3[key] ~= nil then
        EnsureDB().global.trp3[key] = enabled == true
    end
end

local function GetAppearanceSetting(key)
    return ActiveProfile().appearance[key]
end

local function SetAppearanceSetting(key, value)
    local appearance = ActiveProfile().appearance
    if (key == "matchSanctuaryFont" or key == "useSlugRendering") and type(value) == "boolean" then
        appearance[key] = value
    elseif (key == "nameFont" or key == "threatFont") and IsAvailableFontSelection(value) then
        appearance[key] = value
    elseif key == "nameSize" and type(value) == "number" then
        appearance[key] = math.max(MIN_NAME_SIZE,
            math.min(MAX_NAME_SIZE, math.floor(value + 0.5)))
    elseif key == "healthBarWidth" and IsFiniteNumber(value) then
        appearance[key] = math.max(MIN_BAR_WIDTH, math.min(MAX_BAR_WIDTH, math.floor(value / 5 + 0.5) * 5))
    elseif key == "namePlacement" and (value == "ABOVE" or value == "INSIDE") then
        appearance[key] = value
    end
end

local function ResetAppearance()
    CancelProfileEdits()
    local appearance = ActiveProfile().appearance
    for key, value in pairs(ActiveProfileDefaults().appearance) do appearance[key] = value end
end

local function PriorityColorForState(state)
    local color = ActiveProfile().priorityColors[state]
        or DEFAULT_PRIORITY_COLORS[state]
        or DEFAULT_PRIORITY_COLORS.useless
    return color.r, color.g, color.b
end

local function GetDimBackgroundNames()
    return ActiveProfile().dimBackgroundNames
end

local function SetDimBackgroundNames(enabled)
    if type(enabled) == "boolean" then ActiveProfile().dimBackgroundNames = enabled end
end

local function GetGradientOpacity()
    return ActiveProfile().gradientOpacity
end

local function SetGradientOpacity(value)
    if IsFiniteNumber(value) then
        ActiveProfile().gradientOpacity = math.floor(math.max(0, math.min(100, value)) + 0.5)
    end
end

local function GetHealthBarEnabled(state)
    return ActiveProfile().healthBars[state] ~= false
end

local function SetHealthBarEnabled(state, enabled)
    if DEFAULT_PRIORITY_COLORS[state] and type(enabled) == "boolean" then
        ActiveProfile().healthBars[state] = enabled
    end
end

local function GetCategoryMode(state)
    return EnsureDB().global.categoryModes[state] or "active"
end

local function SetCategoryMode(state, mode)
    if not DEFAULT_CATEGORY_MODES[state]
        or (mode ~= "active" and mode ~= "inactive") then return end
    EnsureDB().global.categoryModes[state] = mode
    if ns.ApplyManagedNameSettings then ns.ApplyManagedNameSettings() end
end

local function SetPriorityColor(state, r, g, b)
    if DEFAULT_PRIORITY_COLORS[state] then
        ActiveProfile().priorityColors[state] = { r = r, g = g, b = b }
    end
end

local function ResetPriorityColor(state)
    CancelColorEdit()
    local default = ActiveProfileDefaults().priorityColors[state]
    if not default then return end
    ActiveProfile().priorityColors[state] = CopyColor(default)
end

local function EffectColor(effect)
    local color = ActiveProfile().effectColors[effect]
        or DEFAULT_EFFECT_COLORS[effect]
        or DEFAULT_EFFECT_COLORS.interruptible
    return color.r, color.g, color.b
end

local function SetEffectColor(effect, r, g, b)
    if DEFAULT_EFFECT_COLORS[effect] then
        ActiveProfile().effectColors[effect] = { r = r, g = g, b = b }
    end
end

local function ResetEffectColor(effect)
    CancelColorEdit()
    local default = ActiveProfileDefaults().effectColors[effect]
    if not default then return end
    ActiveProfile().effectColors[effect] = CopyColor(default)
end

local function ResetAllColors()
    CancelColorEdit()
    if ns.CancelColorsEdits then ns.CancelColorsEdits(true) end
    if ns.CancelHighlightEdits then ns.CancelHighlightEdits(true) end
    local profile = ActiveProfile()
    local defaults = ActiveProfileDefaults()
    for key, default in pairs(defaults.priorityColors) do
        profile.priorityColors[key] = CopyColor(default)
        profile.healthBars[key] = DEFAULT_HEALTH_BARS[key]
    end
    for key, default in pairs(defaults.effectColors) do
        profile.effectColors[key] = CopyColor(default)
    end
    profile.interruptibleHighlight = defaults.interruptibleHighlight
    profile.interruptibleEffect = defaults.interruptibleEffect
    profile.castAdvanced = ValidatedCastBorders()
    profile.gradientOpacity = defaults.gradientOpacity
    profile.dimBackgroundNames = DEFAULT_DIM_BACKGROUND_NAMES
    local modes = EnsureDB().global.categoryModes
    for key, default in pairs(DEFAULT_CATEGORY_MODES) do modes[key] = default end
    if ns.ApplyManagedNameSettings then ns.ApplyManagedNameSettings() end
end


local function ResetHighlightSettings()
    if ns.CancelHighlightEdits then ns.CancelHighlightEdits(true) end
    local profile = ActiveProfile()
    profile.interruptibleEffect = defaults.interruptibleEffect
    profile.castAdvanced = ValidatedCastBorders()
end
ns.ResetHighlightSettings = ResetHighlightSettings

local function GetCastBorderSetting(effect, key)
    local values = ActiveProfile().castAdvanced[effect]
    return values and values[key]
end

local function SetCastBorderSetting(effect, key, value)
    local controls = CAST_BORDER_CONTROLS[effect]
    if not controls then return end
    for _, control in ipairs(controls) do
        if control.key == key then
            if IsFiniteNumber(value) then
                local steps = math.floor((math.max(control.min, math.min(control.max, value)) - control.min) / control.step + 0.5)
                local settings = ActiveProfile().castAdvanced[effect]
                settings[key] = math.min(control.max, control.min + steps * control.step)
                if key == "minLength" and settings.minLength > settings.maxLength then
                    settings.minLength = settings.maxLength
                elseif key == "maxLength" and settings.maxLength < settings.minLength then
                    settings.maxLength = settings.minLength
                end
            end
            return
        end
    end
end

local function GetInterruptibleHighlightEnabled()
    return ActiveProfile().interruptibleHighlight == true
end

local function SetInterruptibleHighlightEnabled(enabled)
    ActiveProfile().interruptibleHighlight = enabled == true
end

local function GetStylingEnabled()
    return EnsureDB().global.stylingEnabled and not ns.nameplateSetupPending
end

local function SetStylingEnabled(enabled)
    EnsureDB().global.stylingEnabled = enabled == true
    if not enabled and ns.RestoreNameplateSetup then ns.RestoreNameplateSetup() end
end

local function GetThreatEnabled()
    return ActiveProfile().showThreat
end

local function SetThreatEnabled(enabled)
    ActiveProfile().showThreat = enabled == true
end


ns.GetProfile = function(name) return EnsureDB().profiles[name] end
ns.EnsureDB = EnsureDB
ns.DEFAULT_PROFILE_NAME = DEFAULT_PROFILE_NAME
ns.HIGH_CONTRAST_PROFILE_NAME = HIGH_CONTRAST_PROFILE_NAME
ns.GetActiveProfileName = GetActiveProfileName
ns.GetProfileNames = GetProfileNames
ns.SetActiveProfileName = SetActiveProfileName
ns.CreateProfile = CreateProfile
ns.CopyActiveProfile = CopyActiveProfile
ns.RenameActiveProfile = RenameActiveProfile
ns.DeleteActiveProfile = DeleteActiveProfile
ns.RestoreBundledProfiles = RestoreBundledProfiles
ns.PriorityColorForState = PriorityColorForState
ns.GetDimBackgroundNames = GetDimBackgroundNames
ns.SetDimBackgroundNames = SetDimBackgroundNames
ns.GetGradientOpacity = GetGradientOpacity
ns.SetGradientOpacity = SetGradientOpacity
ns.GetHealthBarEnabled = GetHealthBarEnabled
ns.SetHealthBarEnabled = SetHealthBarEnabled
-- Legacy category modes are retained for saved-data compatibility only.
ns.GetCategoryMode = GetCategoryMode
ns.SetCategoryMode = SetCategoryMode
ns.SetPriorityColor = SetPriorityColor
ns.ResetPriorityColor = ResetPriorityColor
ns.EffectColor = EffectColor
ns.SetEffectColor = SetEffectColor
ns.ResetEffectColor = ResetEffectColor
ns.ResetAllColors = ResetAllColors
ns.GetCastBorderSetting = GetCastBorderSetting
ns.SetCastBorderSetting = SetCastBorderSetting
ns.GetInterruptibleHighlightEnabled = GetInterruptibleHighlightEnabled
ns.SetInterruptibleHighlightEnabled = SetInterruptibleHighlightEnabled
ns.GetInterruptibleEffect = function() return ActiveProfile().interruptibleEffect end
ns.SetInterruptibleEffect = function(value)
    if ns.CAST_EFFECT_BY_VALUE[value] then ActiveProfile().interruptibleEffect = value end
end
ns.GetStylingEnabled = GetStylingEnabled
ns.SetStylingEnabled = SetStylingEnabled
ns.GetThreatEnabled = GetThreatEnabled
ns.SetThreatEnabled = SetThreatEnabled
ns.GetAppearanceSetting = GetAppearanceSetting
ns.SetAppearanceSetting = SetAppearanceSetting
ns.ResetAppearance = ResetAppearance
ns.GetTRP3Enabled = GetTRP3Enabled
ns.SetTRP3Enabled = SetTRP3Enabled
ns.GetTRP3Setting = GetTRP3Setting
ns.SetTRP3Setting = SetTRP3Setting


