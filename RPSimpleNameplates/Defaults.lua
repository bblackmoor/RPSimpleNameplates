-- Simple Nameplates: factory settings and validation ranges.
local _, ns = ...

local function RGB8(r, g, b)
    return { r = r / 255, g = g / 255, b = b / 255 }
end

local DEFAULT_PRIORITY_COLORS = {
    attacking = RGB8(255, 0, 0),
    hostile = RGB8(255, 102, 0),
    neutral = RGB8(255, 204, 0),
    friendly = RGB8(0, 0, 255),
    useful = RGB8(0, 255, 0),
    useless = RGB8(153, 153, 153),
}
local DEFAULT_CATEGORY_MODES = {
    attacking = "active",
    hostile = "active",
    neutral = "active",
    friendly = "active",
    useful = "active",
    useless = "active",
}
local DEFAULT_EFFECT_COLORS = {
    interruptible = RGB8(51, 0, 255),
}
local COLOR_PRESETS = {
    highContrast = {
        gradientOpacity = 0,
        appearance = {namePlacement = "ABOVE"},
        priorityColors = {
            attacking = RGB8(255, 0, 255),
            hostile = RGB8(255, 102, 0),
            neutral = RGB8(255, 255, 0),
            friendly = RGB8(0, 255, 255),
            useful = RGB8(0, 102, 255),
            useless = RGB8(255, 255, 255),
        },
        effectColors = {
            interruptible = RGB8(51, 0, 255),
        },
    },
}
ns.DEFAULT_PRIORITY_COLORS = DEFAULT_PRIORITY_COLORS
ns.DEFAULT_EFFECT_COLORS = DEFAULT_EFFECT_COLORS

local FONT_OPTIONS = {
    { value = "ARIALN", label = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { value = "FRIZQT", label = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { value = "MORPHEUS", label = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { value = "SKURRI", label = "Skurri", path = "Fonts\\skurri.ttf" },
    { value = "2002", label = "2002", path = "Fonts\\2002.TTF" },
    { value = "2002B", label = "2002 Bold", path = "Fonts\\2002B.TTF" },
}
local FONT_BY_VALUE = {}
for _, option in ipairs(FONT_OPTIONS) do FONT_BY_VALUE[option.value] = option end

local DEFAULT_APPEARANCE = {
    nameFont = "FRIZQT",
    matchSanctuaryFont = true,
    useSlugRendering = true,
    nameSize = 18,
    threatFont = "ARIALN",
    namePlacement = "INSIDE",
    healthBarWidth = 120,
}
local MIN_NAME_SIZE = 8
local MAX_NAME_SIZE = 36

local DEFAULT_TRP3 = {
    enabled = false,
    useRoleplayingName = true,
    showShortTitle = true,
    showFullTitle = true,
    showOOC = true,
}

local DEFAULT_STYLING_ENABLED = true
local DEFAULT_SHOW_THREAT = true
local DEFAULT_HIDE_CRITTER_COMPANION_NAMES = false

ns.FONT_OPTIONS = FONT_OPTIONS
ns.DEFAULT_APPEARANCE = DEFAULT_APPEARANCE
ns.MIN_NAME_SIZE = MIN_NAME_SIZE
ns.MAX_NAME_SIZE = MAX_NAME_SIZE
ns.MIN_HEALTH_BAR_WIDTH = 80
ns.MAX_HEALTH_BAR_WIDTH = 150
ns.Defaults = {
    priorityColors = DEFAULT_PRIORITY_COLORS,
    categoryModes = DEFAULT_CATEGORY_MODES,
    healthBars = {attacking = true, hostile = true, neutral = true, friendly = true, useful = true, useless = false},
    dimBackgroundNames = true,
    gradientOpacity = 100,
    effectColors = DEFAULT_EFFECT_COLORS,
    colorPresets = COLOR_PRESETS,
    fontByValue = FONT_BY_VALUE,
    appearance = DEFAULT_APPEARANCE,
    trp3 = DEFAULT_TRP3,
    stylingEnabled = DEFAULT_STYLING_ENABLED,
    showThreat = DEFAULT_SHOW_THREAT,
    interruptibleHighlight = false,
    interruptibleEffect = "PULSE",
    hideCritterCompanionNames = DEFAULT_HIDE_CRITTER_COMPANION_NAMES,
}

-- Profile border controls shared by Colors and saved-data validation.
ns.CAST_BORDER_CONTROLS = {
    PULSE = {
        {key="thickness", label="Border thickness", min=1, max=12, step=1, default=4, suffix=" px"},
        {key="offset", label="Border offset", min=0, max=6, step=1, default=3, suffix=" px"},
        {key="fadeIn", label="Fade in", min=0.1, max=2, step=0.05, default=0.1, suffix=" s"},
        {key="fadeOut", label="Fade out", min=0.1, max=2, step=0.05, default=0.1, suffix=" s"},
    },
    ALERT = {
        {key="minLength", label="Minimum length", min=1, max=100, step=1, default=20, suffix="%"},
        {key="maxLength", label="Maximum length", min=1, max=100, step=1, default=100, suffix="%"},
        {key="shrinkTime", label="Shrink time", min=0.1, max=2, step=0.05, default=0.2, suffix=" s"},
        {key="growTime", label="Grow time", min=0.1, max=2, step=0.05, default=0.2, suffix=" s"},
        {key="endOpacity", label="End opacity", min=0, max=100, step=1, default=0, suffix="%"},
        {key="centerOpacity", label="Center opacity", min=0, max=100, step=1, default=100, suffix="%"},
    },
}

ns.CAST_EFFECT_OPTIONS = {
    {value = "PULSE", label = "Pulsing border"},
    {value = "SOLID", label = "Solid border"},
    {value = "ALERT", label = "Alert border"},
}
ns.CAST_EFFECT_BY_VALUE = {}
for _, option in ipairs(ns.CAST_EFFECT_OPTIONS) do ns.CAST_EFFECT_BY_VALUE[option.value] = option.label end

