-- Simple Nameplates: NPC subtitles from readable structured unit tooltips.
local _, ns = ...
local Value, Number = ns.AccessibleValue, ns.AccessibleNumber
local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return Value(value) end
end

local function Restricted(value)
    return (issecretvalue and issecretvalue(value))
        or (canaccessvalue and not canaccessvalue(value))
end

local function Field(object, key)
    if Restricted(object) then return nil, "restricted" end
    object = Value(object)
    if type(object) ~= "table" then return nil, "object unavailable" end
    local ok, value = pcall(function() return object[key] end)
    if not ok then return nil, "field read failed" end
    if Restricted(value) then return nil, "restricted" end
    local readable = Value(value)
    if readable == nil then return nil, value == nil and "absent" or "restricted" end
    return readable, "readable"
end

local function CleanTitle(text)
    text = Value(text)
    if type(text) ~= "string" then return nil, "subtitle text unavailable or not a string" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    -- Do not turn links, textures, or other tooltip markup into overhead text.
    if text:find("|", 1, true) then return nil, "subtitle contains unsupported markup" end
    text = text:gsub("%s+", " "):match("^%s*(.-)%s*$")
    text = text:match("^<(.-)>$") or text
    if text == "" then return nil, "subtitle is empty" end
    return "<" .. text .. ">", "title extracted"
end

local function PlainLevel(text, unit)
    text = Value(text)
    local level = Number(Read(UnitLevel, unit))
    if type(text) ~= "string" or not level or level < 1 then return false end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    for _, key in ipairs({"TOOLTIP_UNIT_LEVEL", "UNIT_LEVEL_TEMPLATE"}) do
        local template = Value(_G[key])
        if type(template) == "string" then
            local ok, expected = pcall(string.format, template, level)
            if ok and text == expected then return true end
        end
    end
    return false
end

local function Extract(data, unit)
    local types = Enum and Enum.TooltipDataLineType
    if not types or not types.UnitName or not types.UnitLevel or not types.None then
        return nil, "required tooltip line enums unavailable"
    end
    local lines, status = Field(data, "lines")
    if type(lines) ~= "table" then return nil, "tooltip lines " .. status end
    -- There is no service-title enum. Accept only the single plain subtitle
    -- immediately between the name and verified level line. Never use a generic
    -- second line (which could instead be a level, quest, owner, or status).
    for index, expected in ipairs({types.UnitName, types.None, types.UnitLevel}) do
        local line, lineStatus = Field(lines, index)
        if type(line) ~= "table" then return nil, "tooltip line " .. index .. " " .. lineStatus end
        local lineType, typeStatus = Field(line, "type")
        lineType = Number(lineType)
        if lineType == nil then return nil, "line " .. index .. " type " .. typeStatus end
        local plainLevel = index == 3 and lineType == types.None
            and PlainLevel(Field(line, "leftText"), unit)
        if lineType ~= expected and not plainLevel then
            return nil, "layout rejected: line " .. index .. " type " .. lineType .. "; expected " .. expected
        end
    end
    local subtitle = Field(lines, 2)
    local right, rightStatus = Field(subtitle, "rightText")
    if rightStatus ~= "readable" and rightStatus ~= "absent" then
        return nil, "subtitle right text " .. rightStatus
    end
    if right ~= nil and right ~= "" then return nil, "subtitle has right-column text" end
    local left, leftStatus = Field(subtitle, "leftText")
    if leftStatus ~= "readable" then return nil, "subtitle left text " .. leftStatus end
    return CleanTitle(left)
end

-- Session-only caches. Prefer exact GUIDs; name fallback is heuristic and
-- disabled once conflicting subtitles have been observed for a shared name.
local known, order, knownNames, nameOrder = {}, {}, {}, {}
local function UnitNameKey(unit)
    local name = Read(UnitName, unit)
    if type(name) ~= "string" or name == "" then return nil end
    return name:lower()
end

local function RememberName(unit, title, useful)
    local key = UnitNameKey(unit)
    if not key then return end
    local cached = knownNames[key]
    if not cached then
        nameOrder[#nameOrder + 1] = key
        if #nameOrder > 256 then knownNames[table.remove(nameOrder, 1)] = nil end
    end
    if cached and cached.title ~= title then
        -- A shared NPC name with conflicting verified subtitles is ambiguous;
        -- never use that name as an identity fallback.
        knownNames[key] = {ambiguous = true}
        return
    end
    if not (cached and cached.ambiguous) then
        knownNames[key] = {title = title, useful = useful == true}
    end
end

local function Remember(guid, unit, title, useful)
    RememberName(unit, title, useful)
    if not guid then return end
    if not known[guid] then
        order[#order + 1] = guid
        if #order > 256 then known[table.remove(order, 1)] = nil end
    end
    known[guid] = {title = title, useful = useful == true}
end

local function GUID(unit)
    local guid = Read(UnitGUID, unit)
    if type(guid) == "string" and guid ~= "" then return guid end
end

local function ReadTooltip(unit, facts)
    if not facts or facts.isNPC ~= true then return nil, "unit not confirmed NPC" end
    local getter = C_TooltipInfo and C_TooltipInfo.GetUnit
    if type(getter) ~= "function" then return nil, "tooltip API unavailable" end
    local ok, data = pcall(getter, unit)
    if not ok then return nil, "tooltip API call failed" end
    if Restricted(data) then return nil, "tooltip data restricted" end
    data = Value(data)
    if data == nil then return nil, "no tooltip data returned" end
    if type(data) ~= "table" then return nil, "tooltip data unavailable or not a table" end
    return data
end

local function ReadHyperlink(unit, facts)
    if not facts or facts.isNPC ~= true then return nil, "unit not confirmed NPC" end
    local guid = GUID(unit)
    if not guid then return nil, "readable NPC GUID unavailable" end
    local getter = C_TooltipInfo and C_TooltipInfo.GetHyperlink
    if type(getter) ~= "function" then return nil, "hyperlink tooltip API unavailable" end
    local ok, data = pcall(getter, "unit:" .. guid)
    if not ok then return nil, "hyperlink tooltip API call failed" end
    if Restricted(data) then return nil, "hyperlink tooltip data restricted" end
    data = Value(data)
    if data == nil then return nil, "no hyperlink tooltip data returned" end
    if type(data) ~= "table" then return nil, "hyperlink tooltip data unavailable or not a table" end
    return data
end

local function TitleUsefulness(unit, facts, guid, title)
    if facts.interactable == true then return true end
    local exact = guid and known[guid]
    if exact and exact.title == title and exact.useful then return true end
    local key = UnitNameKey(unit)
    -- Preserve the working interaction evidence when the new reader supplies
    -- a subtitle directly to a sparse/non-interactable nameplate token.
    for _, source in ipairs({"target", "mouseover", "softinteract"}) do
        if source ~= unit and ((guid and GUID(source) == guid)
            or (key and UnitNameKey(source) == key))
            and Read(UnitIsPlayer, source) == false
            and Read(UnitPlayerControlled, source) == false
            and Read(UnitIsInteractable, source) == true then
            local data = ReadTooltip(source, {isNPC = true})
            if data and Extract(data, source) == title then return true end
        end
    end
    local named = key and knownNames[key]
    return named and not named.ambiguous and named.title == title and named.useful or false
end

local function GetTitle(unit, facts)
    if not facts or facts.isNPC ~= true then return nil, "unit not confirmed NPC" end
    local data, reason = ReadHyperlink(unit, facts)
    local title
    if data then title, reason = Extract(data, unit) end
    local titleSource = "GUID hyperlink tooltip"
    if not title then
        data, reason = ReadTooltip(unit, facts)
        if data then title, reason = Extract(data, unit) end
        titleSource = "unit tooltip"
    end
    local guid = GUID(unit)
    if title then
        local useful = TitleUsefulness(unit, facts, guid, title)
        Remember(guid, unit, title, useful)
        return title, titleSource, useful
    end
    -- Full world-unit tooltips can include subtitles omitted by nameplate
    -- tokens. Verify readable GUID equality even when UnitIsUnit says false.
    if guid then
        for _, source in ipairs({"target", "mouseover", "softinteract"}) do
            if source ~= unit and GUID(source) == guid
                and Read(UnitIsPlayer, source) == false
                and Read(UnitPlayerControlled, source) == false then
                local sourceData = ReadTooltip(source, {isNPC = true})
                local sourceTitle = sourceData and Extract(sourceData, source)
                if sourceTitle then
                    local useful = Read(UnitIsInteractable, source) == true
                    Remember(guid, source, sourceTitle, useful)
                    return sourceTitle, source .. " tooltip (verified GUID)", useful
                end
            end
        end
        local cached = known[guid]
        if cached then return cached.title, "cached verified GUID", cached.useful end
    end
    -- A readable nameplate GUID can differ from the world-unit GUID. Learn
    -- full matching-name tooltips during rendering, without requiring debug.
    -- Do not promote this weaker association into the exact-GUID cache.
    local key = UnitNameKey(unit)
    if key then
        for _, source in ipairs({"target", "mouseover", "softinteract"}) do
            if source ~= unit and UnitNameKey(source) == key
                and Read(UnitIsPlayer, source) == false
                and Read(UnitPlayerControlled, source) == false then
                local sourceData = ReadTooltip(source, {isNPC = true})
                local sourceTitle = sourceData and Extract(sourceData, source)
                if sourceTitle then
                    Remember(GUID(source), source, sourceTitle, Read(UnitIsInteractable, source) == true)
                end
            end
        end
        local cached = knownNames[key]
        if cached and not cached.ambiguous then
            return cached.title, guid and "cached NPC name (GUID unmatched)"
                or "cached NPC name (GUID unavailable)", cached.useful
        end
        if cached and cached.ambiguous then return nil, reason .. "; conflicting NPC-name subtitles" end
    end
    return nil, reason .. "; no unambiguous cached NPC-name subtitle"
end

local function Inspect(unit, facts)
    local data, reason = ReadTooltip(unit, facts)
    local result = {reason = reason, lines = {}}
    local hyperlink, linkReason = ReadHyperlink(unit, facts)
    local linkTitle
    if hyperlink then linkTitle, linkReason = Extract(hyperlink, unit) end
    result.hyperlink = {title = linkTitle, reason = linkReason}
    if not data then return result end
    result.title, result.reason = Extract(data, unit)
    local lines = Field(data, "lines")
    if type(lines) ~= "table" then return result end
    -- Bounded diagnostic-only snapshot; never construct or mutate a tooltip.
    for index = 1, 12 do
        local line, status = Field(lines, index)
        if status == "absent" then break end
        local row = {index = index, status = status}
        row.lineType, row.typeStatus = Field(line, "type")
        row.left, row.leftStatus = Field(line, "leftText")
        row.right, row.rightStatus = Field(line, "rightText")
        result.lines[#result.lines + 1] = row
    end
    local _, status = Field(lines, 13)
    result.truncated = status ~= "absent"
    return result
end

GetTitle = ns.Profiler.Wrap("NPC title lookup", GetTitle)

ns.NPCTitles = {GetTitle = GetTitle, Extract = Extract, Inspect = Inspect}
