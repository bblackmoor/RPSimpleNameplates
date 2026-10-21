-- Versioned, non-executable theme exchange. Only known visual fields are decoded.
local _, ns = ...
local HEADER, MAX_LENGTH = "RPSN-THEME:1", 16384
local function Escape(value)
    return (value:gsub("[^%w._%- ]", function(c) return string.format("%%%02X", c:byte()) end))
end
local function Unescape(value)
    if value:gsub("%%[0-9a-fA-F][0-9a-fA-F]", ""):find("%%") then return nil end
    return (value:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end
local function Flatten(source, prefix, output)
    for key, value in pairs(source) do
        local path = prefix == "" and key or prefix .. "." .. key
        if type(value) == "table" then Flatten(value, path, output)
        else output[path] = value end
    end
end
local function Fields()
    local fields = {}
    Flatten(ns.ValidateThemeData({}), "", fields)
    return fields
end
function ns.ExportTheme()
    local flat, keys = {}, {}
    Flatten(ns.GetThemeData(), "", flat)
    for key in pairs(flat) do keys[#keys + 1] = key end
    table.sort(keys)
    local lines = {HEADER}
    for _, key in ipairs(keys) do
        local value = flat[key]
        if type(value) == "number" then value = string.format("%.17g", value)
        elseif type(value) == "boolean" then value = value and "true" or "false"
        else value = Escape(value) end
        lines[#lines + 1] = key .. "=" .. value
    end
    return table.concat(lines, "\n")
end
function ns.DecodeTheme(text)
    if type(text) ~= "string" or #text > MAX_LENGTH then return nil, "Theme text is too long or invalid." end
    text = strtrim(text:gsub("\r\n", "\n"))
    local header, body = text:match("^([^\n]+)\n(.+)$")
    if header ~= HEADER then return nil, "This is not a supported RP Simple Nameplates theme." end
    local fields, result, seen, count = Fields(), {}, {}, 0
    for line in body:gmatch("[^\n]+") do
        local key, raw = line:match("^([%w._]+)=(.*)$")
        if not key or seen[key] then return nil, "Theme contains a malformed or duplicate setting." end
        seen[key] = true
        local default = fields[key]
        if default ~= nil then
            count = count + 1
            local value
            if type(default) == "boolean" then
                if raw == "true" then value = true elseif raw == "false" then value = false end
            elseif type(default) == "number" then value = tonumber(raw)
            else
                value = Unescape(raw)
                if not value or value:find("[%z\1-\31\127]") then return nil, "Theme contains invalid text." end
            end
            local parts = {}
            for part in key:gmatch("[^.]+") do parts[#parts + 1] = part end
            local target = result
            for index = 1, #parts - 1 do
                target[parts[index]] = target[parts[index]] or {}
                target = target[parts[index]]
            end
            target[parts[#parts]] = value
        end
    end
    if count == 0 then return nil, "Theme contains no recognized settings." end
    -- Unknown fields are ignored; missing/invalid fields use factory defaults.
    return ns.ValidateThemeData(result)
end
