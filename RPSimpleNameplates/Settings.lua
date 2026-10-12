-- Simple Nameplates: register settings pages and slash routes.
local _, addon = ...
local rootCategory
local categories, panels = {}, {}
local pageOrder = {
    {key = "About", label = "About"},
    {key = "Profiles", label = "Profiles"},
    {key = "Appearance", label = "Text"},
    {key = "Colors", label = "Colors"},
    {key = "Highlight", label = "Highlight"},
    {key = "TRP3", label = "TRP3"},
}
local aliases = {
    [""] = "Appearance", general = "Appearance", config = "Appearance",
    options = "Appearance", settings = "Appearance", about = "About",
    profiles = "Profiles", profile = "Profiles",
    appearance = "Appearance", text = "Appearance", font = "Appearance", fonts = "Appearance",
    colors = "Colors", color = "Colors",
    highlight = "Highlight", highlights = "Highlight",
    trp3 = "TRP3", rp = "TRP3",
}
local function RegisterSettingsPanels()
    if rootCategory or not addon.SettingsPanels or not Settings or not Settings.RegisterCanvasLayoutCategory
        or not Settings.RegisterCanvasLayoutSubcategory or not Settings.RegisterAddOnCategory then return end
    -- Validate all factories before constructing or registering any page.
    for _, page in ipairs(pageOrder) do
        if type(addon.SettingsPanels[page.key]) ~= "function" then return end
    end
    for _, page in ipairs(pageOrder) do
        panels[page.key] = addon.SettingsPanels[page.key]()
    end
    if addon.SettingsUI and addon.SettingsUI.InstallCombatGuard then addon.SettingsUI.InstallCombatGuard() end
    rootCategory = Settings.RegisterCanvasLayoutCategory(panels.About, "Simple Nameplates")
    categories.About = rootCategory
    Settings.RegisterAddOnCategory(rootCategory)
    for index = 2, #pageOrder do
        local page = pageOrder[index]
        categories[page.key] = Settings.RegisterCanvasLayoutSubcategory(rootCategory, panels[page.key], page.label)
    end
    SLASH_SNP1 = "/snp"
    SlashCmdList.SNP = function(message)
        local command = string.lower(strtrim(message or ""))
        local verb, argument = command:match("^(%S+)%s*(.-)$")
        if verb == "perf" then addon.Profiler.Command(argument); return end
        if verb == "debug" or verb == "diagnose" then
            local nearby, filter = argument:match("^(nearby)%s*(.-)$")
            if nearby then
                if addon.DebugNearby then addon.DebugNearby(filter) end
                return
            end
            local unit = argument == "" and "target" or argument
            if unit ~= "target" and unit ~= "mouseover" then
                print("|cff0cd29fSimple Nameplates:|r /snp debug [target|mouseover|nearby [name]]")
                return
            end
            if addon.DebugUnit then addon.DebugUnit(unit) end
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            print("|cff0cd29fSimple Nameplates:|r Settings cannot be opened during combat.")
            return
        end
        local category = aliases[command] and categories[aliases[command]]
        if category then Settings.OpenToCategory(category:GetID())
        else print("|cff0cd29fSimple Nameplates:|r /snp, /snp profiles, /snp text, /snp colors, /snp highlight, /snp trp3, /snp debug [target|mouseover|nearby [name]], /snp perf [start|stop|report], /snp about") end
    end
end
addon.RegisterSettingsPanels = RegisterSettingsPanels



