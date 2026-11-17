-- Manual allocation benchmark, using production functions with native APIs stubbed.
-- Run: luatex --luaonly tests/runtime-allocation-benchmark.lua [source-root]
local root = arg[1] or "RPSimpleNameplates"
local function noop() end
local function measure(label, callback)
    callback() -- Warm reusable buffers before measuring steady state.
    collectgarbage("collect"); collectgarbage("stop")
    local before, started = collectgarbage("count"), os.clock()
    for _ = 1, 10000 do callback() end
    local allocated, elapsed = collectgarbage("count") - before, os.clock() - started
    collectgarbage("restart")
    print(("%s: %.1f KiB, %.4f seconds / 10000 calls"):format(label, allocated, elapsed))
end
local ns = {
    WorldContext = {Get = noop}, NameplateTitles = {},
    NameplateFrames = {SetShownSafe = noop},
    Profiler = {Wrap = function(_, callback) return callback end},
}
assert(loadfile(root .. "/NameplateLayout.lua"))("RPSimpleNameplates", ns)
local context = {}
local frame = {name = {SetAlpha = noop}}
measure("Suppressed text", function() ns.NameplateLayout.SuppressText(frame, context) end)

-- Isolate the actual discovery function, retaining its production bookkeeping.
local file = assert(io.open(root .. "/Nameplates.lua"))
local source = file:read("*a"); file:close()
local body = assert(source:match("(local function DiscoverPlates%(%).-\nend)\nDiscoverPlates ="))
local snapshot = {}
for i = 1, 40 do snapshot[i] = {} end
local reconciled, globalWork, pendingPlates = {}, {}, {}
local environment = setmetatable({
    C_NamePlate = {GetNamePlates = function() return snapshot end},
    Periodic = {Schedule = noop, Cancel = noop},
    reconcilePlates = reconciled, globalWork = globalWork,
    pendingUnits = {}, pendingPlates = pendingPlates,
    ReconcileNames = noop, DeferUnit = noop, DeferPlate = noop,
}, {__index = _G})
local discover = assert(load("local discoveryPresence = {}\n" .. body .. "\nreturn DiscoverPlates",
    "discovery benchmark", "t", environment))()
measure("Discovery, 40 plates", discover)
local retired = snapshot[1]
globalWork[retired], pendingPlates[retired] = true, true
snapshot = {}
discover()
assert(not reconciled[retired] and not globalWork[retired] and not pendingPlates[retired],
    "Removed plates must leave every queue")
snapshot = {retired}
discover()
assert(reconciled[retired], "Returning plates must be rediscovered")
print("Discovery removal/reappearance checks: passed")
