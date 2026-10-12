-- Simple Nameplates: metadata, addon conflict warning, and safe-value helpers.
local addon, ns = ...

local getAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata

ns.VERSION = getAddOnMetadata and getAddOnMetadata(addon, "Version") or "Unknown"
ns.SOURCE_URL = "https://github.com/bblackmoor/SimpleNameplates"

local issecretvalue = issecretvalue or function() return false end
local canaccessvalue = canaccessvalue or function(v) return not issecretvalue(v) end

local function AddOnEnabled(name)
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if isLoaded and isLoaded(name) then return true end

    local state
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        state = C_AddOns.GetAddOnEnableState(name, UnitName("player"))
    elseif GetAddOnEnableState then
        -- The legacy global uses the opposite argument order.
        state = GetAddOnEnableState(UnitName("player"), name)
    end
    return type(state) == "number" and state > 0
end

local function PlainTitle(title)
    return (title or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function FindOtherPlateAddOns()
    local getNumAddOns = C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns
    local getAddOnInfo = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
    if not getNumAddOns or not getAddOnInfo then return {} end

    local found = {}
    for index = 1, getNumAddOns() do
        local name, title = getAddOnInfo(index)
        if name and name ~= addon and not name:match("^Blizzard_") then
            local searchText = string.lower(name .. " " .. (title or "")):gsub("template", "")
            if searchText:find("plate", 1, true) and AddOnEnabled(name) then
                local displayName = type(title) == "string" and title ~= "" and title or name
                found[#found + 1] = PlainTitle(displayName)
            end
        end
    end
    table.sort(found)
    return found
end

local function ShowNameplateConflictWarning()
    local conflicts = FindOtherPlateAddOns()
    if #conflicts == 0 then return end

    StaticPopupDialogs["SNP_NAMEPLATE_CONFLICT"] = {
        text = "|cff0cd29fSimple Nameplates|r\n\nOther enabled addons whose names contain ‘plate’ were found:\n\n%s\n\nRunning more than one nameplate addon can cause conflicting colors or duplicate nameplates. Disable the others and reload the UI if you see problems.",
        button1 = OKAY or "Okay",
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("SNP_NAMEPLATE_CONFLICT", table.concat(conflicts, "\n"))
end

local function AccessibleNumber(v)
    if issecretvalue(v) or not canaccessvalue(v) or v == nil or type(v) ~= "number" then return nil end
    return v
end

local function AccessibleBoolean(v)
    if issecretvalue(v) or not canaccessvalue(v) or v == nil or type(v) ~= "boolean" then return nil end
    return v
end

local function AccessibleValue(v)
    if issecretvalue(v) or not canaccessvalue(v) or v == nil then return nil end
    return v
end

ns.ShowNameplateConflictWarning = ShowNameplateConflictWarning
ns.AccessibleNumber = AccessibleNumber
ns.AccessibleBoolean = AccessibleBoolean
ns.AccessibleValue = AccessibleValue
