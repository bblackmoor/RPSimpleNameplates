-- Simple Nameplates: review Blizzard settings before enabling styling.
local _, ns = ...

local requirements = {
    { "nameplateShowAll", "1", "Always Show Nameplates", "Keeps plates available outside combat." },
    { "nameplateShowEnemies", "1", "Enemy Unit Nameplate", "Makes enemy plates available." },
    { "nameplateShowFriendlyPlayers", "1", "Friendly Player Nameplates", "Makes friendly player plates available." },
    { "nameplateShowFriendlyNpcs", "1", "Friendly NPC Nameplates", "Makes ordinary NPC names and service titles available." },
    { "nameplateShowOnlyNameForFriendlyPlayerUnits", "0", "Only Show Names", "Lets Simple Nameplates show friendly health bars." },
}
ns.NAMEPLATE_SETUP_CVARS = {}
for _, requirement in ipairs(requirements) do
    ns.NAMEPLATE_SETUP_CVARS[#ns.NAMEPLATE_SETUP_CVARS + 1] = requirement[1]
end

local deferredAction, applying
local Check, Apply, Restore

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function Read(cvar)
    local getter = C_CVar and C_CVar.GetCVar or GetCVar
    if not getter then return nil end
    local ok, value = pcall(getter, cvar)
    if not ok then return nil end
    value = ns.AccessibleValue(value)
    if type(value) == "string" and value ~= "" then return value end
    if type(value) == "number" then return tostring(value) end
end

local function Write(cvar, value)
    if Read(cvar) == value then return true end
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    if not setter then return false end
    local ok = pcall(setter, cvar, value)
    return ok and Read(cvar) == value
end

local function CharacterKey()
    local ok, guid = pcall(UnitGUID or function() end, "player")
    guid = ok and ns.AccessibleValue(guid) or nil
    if type(guid) == "string" and guid ~= "" then return guid end
    return nil -- Never share CVar backups between unidentified characters.
end

local function Originals()
    local key = CharacterKey()
    if not key then return nil end
    local all = ns.EnsureDB().global.nameplateSetupOriginals
    all[key] = all[key] or {}
    return all[key]
end

local function Issues()
    local issues = {}
    for _, requirement in ipairs(requirements) do
        local value = Read(requirement[1])
        -- Unsupported/unreadable CVars cannot be automatically configured.
        if value ~= nil and value ~= requirement[2] then
            issues[#issues + 1] = { requirement = requirement, current = value }
        end
    end
    return issues
end

local function SetPending(pending)
    ns.nameplateSetupPending = pending
    -- Consent may finish after the switch callback or after combat ends.
    if ns.RefreshStylingControl then ns.RefreshStylingControl() end
end

local function Suspend()
    SetPending(true)
    if ns.RestoreAll then ns.RestoreAll() end
end

local function Resume()
    deferredAction = nil
    SetPending(false)
    ns.ApplyManagedNameSettings()
    if ns.RefreshAll then ns.RefreshAll() end
end

local function Disable()
    ns.SetStylingEnabled(false)
    ns.RestoreManagedNameSettings()
    if ns.RestoreAll then ns.RestoreAll() end
    print("Simple Nameplates styling is disabled. Enable it again using Active in /snp profiles.")
end

local function ShowReview(issues, failure)
    local lines = {}
    for _, issue in ipairs(issues) do
        local row = issue.requirement
        local current = issue.current == "1" and "On" or issue.current == "0" and "Off" or issue.current
        lines[#lines + 1] = row[3] .. ": " .. current .. " -> " .. (row[2] == "1" and "On" or "Off") .. "\n" .. row[4]
    end
    local text = table.concat(lines, "\n\n")
    if failure then text = failure .. "\n\n" .. text end
    StaticPopupDialogs.SNP_NAMEPLATE_SETUP = {
        text = "|cff0cd29fSimple Nameplates — Setup|r\n\n%s\n\nChanged WoW settings are restored when styling is disabled.\n\nWoW may still withhold some plates, including opposite-faction players in sanctuary.",
        button1 = "Apply and enable", button2 = "Disable styling",
        OnAccept = function() Apply() end,
        OnCancel = function() Disable() end,
        timeout = 0, whileDead = true, hideOnEscape = false, preferredIndex = 3,
    }
    StaticPopup_Show("SNP_NAMEPLATE_SETUP", text)
end

Restore = function()
    SetPending(false)
    if StaticPopup_Hide then StaticPopup_Hide("SNP_NAMEPLATE_SETUP") end
    if InCombat() then deferredAction = "restore"; return end
    deferredAction = nil
    local originals = Originals()
    if not originals then return end
    applying = true
    for cvar, original in pairs(originals) do
        if Write(cvar, tostring(original)) then originals[cvar] = nil
        else deferredAction = "restore" end
    end
    applying = false
end

Apply = function()
    if not ns.EnsureDB().global.stylingEnabled then return end
    Suspend()
    if InCombat() then deferredAction = "apply"; return end
    local originals, issues = Originals(), Issues()
    local failed = not originals
    applying = true
    if originals then
        for _, issue in ipairs(issues) do
            local row = issue.requirement
            if originals[row[1]] == nil then originals[row[1]] = issue.current end
            if not Write(row[1], row[2]) then failed = true end
        end
    end
    applying = false
    if failed or #Issues() > 0 then
        -- Keep styling suspended and show a retry/disable choice. Do not claim
        -- success when WoW rejects a write or a CVar changes during setup.
        deferredAction = nil
        C_Timer.After(0, function()
            if ns.EnsureDB().global.stylingEnabled and ns.nameplateSetupPending then
                ShowReview(Issues(), "Some changes could not be applied. Styling remains paused; retry or disable it to restore changed settings.")
            end
        end)
        return false
    end
    Resume()
    return true
end

Check = function()
    if applying then return not ns.nameplateSetupPending end
    if not ns.EnsureDB().global.stylingEnabled then Restore(); return false end
    deferredAction = nil -- Enabling cancels a deferred disable/restoration.
    -- Release older managed settings before reading compatibility. Otherwise
    -- legacy CVar restoration later at login can invalidate this review.
    SetPending(true)
    if InCombat() then deferredAction = "check"; return false end
    if ns.RestoreManagedNameSettings() == false then
        Suspend()
        deferredAction = "check"
        return false
    end
    local issues = Issues()
    if #issues == 0 then
        SetPending(false)
        return true
    end
    Suspend()
    deferredAction = nil
    ShowReview(issues)
    return false
end

ns.CheckNameplateSetup = Check
ns.RestoreNameplateSetup = Restore
ns.GetNameplateSetupIssues = Issues
ns.RetryNameplateSetup = function()
    if deferredAction == "restore" then Restore()
    elseif deferredAction == "apply" then Apply()
    elseif deferredAction == "check" and Check() then Resume() end
end
