-- Load real embedded dependencies and the complete recursive DF manifest.
local root = "RPSimpleNameplates/"
local function Load(file) assert(loadfile(root .. file))() end
for _, file in ipairs({"Libs/LibStub/LibStub.lua",
    "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
    "Libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua"}) do Load(file) end

local scripts, manifests = 0, 0
local function LoadXML(path)
    manifests = manifests + 1
    local file = assert(io.open(root .. path))
    local text = file:read("*a")
    file:close()
    local directory = path:match("^(.*[/])") or ""
    for _, name in text:gmatch('<(%w+)%s+file%s*=%s*"([^"]+)"') do
        if name:match("%.xml$") then
            LoadXML(directory .. name)
        else
            scripts = scripts + 1
            assert(xpcall(assert(loadfile(root .. directory .. name)), debug.traceback))
        end
    end
end

return function(path)
    scripts, manifests = 0, 0
    LoadXML(path)
    return scripts, manifests
end
