-- Simple Nameplates: thin outlines on all styled plate text.
local _, ns = ...

function ns.FontFlags()
    return ns.GetAppearanceSetting("useSlugRendering") == true and "SLUG,OUTLINE" or "OUTLINE"
end

-- Native font getters may normalize filename spelling and flag order. Compare
-- their meaning, without accepting a different face or dropping real flags.
function ns.FontPathMatches(actual, desired)
    if actual == desired then return true end
    if type(actual) ~= "string" or type(desired) ~= "string" then return actual == desired end
    return actual:gsub("/", "\\"):lower() == desired:gsub("/", "\\"):lower()
end

local function CanonicalFlags(flags)
    if type(flags) ~= "string" then return flags end
    local tokens, seen = {}, {}
    for token in flags:upper():gmatch("[^,%s]+") do
        if not seen[token] then tokens[#tokens + 1], seen[token] = token, true end
    end
    table.sort(tokens)
    return table.concat(tokens, ",")
end

function ns.FontFlagsMatch(actual, desired)
    if actual == desired then return true end
    return CanonicalFlags(actual) == CanonicalFlags(desired)
end
