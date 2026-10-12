-- Deterministic timings, transparent calls, and session lifecycle.
local output, now, clockReads, memoryReads, updates = {}, 0, 0, 0, 0
local originalPrint = print
function print(message) output[#output + 1] = message end
function GetTimePreciseSec() clockReads = clockReads + 1; return now end
function UpdateAddOnMemoryUsage() updates = updates + 1 end
function GetAddOnMemoryUsage(name)
    assert(name == "RPSimpleNameplates")
    memoryReads = memoryReads + 1
    return memoryReads == 1 and 100 or 90
end
local ns = {AccessibleNumber = function(value) if type(value) == "number" then return value end end}
assert(loadfile("RPSimpleNameplates/Profiler.lua"))("RPSimpleNameplates", ns)
local p = ns.Profiler
local function Contains(text)
    for _, line in ipairs(output) do if line:find(text, 1, true) then return true end end
    error("Missing report: " .. text)
end
local function Pack(...) return {n = select('#', ...), ...} end
local marker = {}
local child = p.Wrap("Child", function(...) now = now + 0.002; return ... end)
local parent = p.Wrap("Parent", function(...) local result = Pack(child(...)); now = now + 0.003; return table.unpack(result, 1, result.n) end)
local result = Pack(parent(nil, marker, false, nil))
assert(result.n == 4 and result[2] == marker and result[3] == false)
p.Count("Disabled", "ignored")
p.SizeSample("barWidth", 140, 168, {})
p.ColorSample(1, 1, 1, 0.6, 0.6, 0.6)
assert(clockReads == 0 and memoryReads == 0 and updates == 0, "disabled path performs no measurement")
p.Command("report"); Contains("No profiling session")
p.Command("start")
local startReads = memoryReads
p.Command("start"); assert(memoryReads == startReads, "duplicate start does not reset")
result = Pack(parent(nil, marker, false, nil))
assert(result.n == 4 and result[2] == marker and result[3] == false)
local beforeCounters = clockReads
p.Count("Styling requests", "name hook")
p.Count("Styling requests", "name hook")
p.Count("Styling requests", "health-color hook")
p.Count("Name drift", "native font")
local pointReads = 0
ns.PresentationCapabilities = {ReadRegion = function() pointReads = pointReads + 1; return 2 end}
p.SizeSample("barWidth", 140, 168, {})
p.SizeSample("barWidth", 140, 168, {})
for value = 1, 20 do p.SizeSample("barHeight", value, 25, {}) end
p.SizeSample("barWidth", 0/0, 168, {})
assert(pointReads == 22, "invalid numeric samples do not inspect regions")
p.ColorSample(1, 1, 1, 0.6, 0.6, 0.6)
p.ColorSample(1, 1, 1, 0.6, 0.6, 0.6)
for value = 1, 20 do p.ColorSample(value / 100, 1, 1, 0.6, 0.6, 0.6) end
p.ColorSample(0/0, 1, 1, 0.6, 0.6, 0.6)
p.ColorSample({}, 1, 1, 0.6, 0.6, 0.6)
assert(clockReads == beforeCounters, "reason counters do not read clocks")
p.Command("report")
Contains("Parent: 1 calls; 5.000 ms total; 5.000 ms average; 5.000 ms longest")
Contains("Child: 1 calls; 2.000 ms total")
Contains("Styling requests: name hook = 2")
Contains("Styling requests: health-color hook = 1")
Contains("Name drift: native font = 1")
Contains("Name size drift: barWidth 140.000 -> 168.000; anchors 2 = 2")
Contains("Name size drift: additional samples = 13")
Contains("Name color drift: 1.000/1.000/1.000 -> 0.600/0.600/0.600 = 2")
Contains("Name color drift: additional samples = 13")
for _, line in ipairs(output) do assert(not line:find("Disabled:", 1, true)) end
assert(memoryReads == 1, "running reports do not scan memory")
local failure = {}
local broken = p.Wrap("Failure", function() now = now + 0.001; error(failure) end)
local ok, err = pcall(broken); assert(not ok and err == failure, "original error object preserved")
p.Command("stop"); p.Command("report")
Contains("Failure: 1 calls; 1.000 ms total")
Contains("100.0 -> 90.0 KiB (-10.0 KiB)")
local reads = clockReads
parent(); p.Count("Styling requests", "name hook"); p.Command("stop"); p.Command("report")
assert(clockReads == reads and memoryReads == 2, "stopped calls/reports perform no measurements")
Contains("Styling requests: name hook = 2")
output = {}; p.Command("start"); p.Command("report"); Contains("No measured calls yet")
for _, line in ipairs(output) do assert(not line:find("Styling requests:", 1, true), "new session clears reasons") end
-- Finishing a call after stop/restart cannot pollute the next session.
local transition = p.Wrap("Transition", function() p.Command("stop"); p.Command("start") end)
transition(); output = {}; p.Command("report"); Contains("No measured calls yet")
p.Command("stop")
GetTimePreciseSec = nil; output = {}; p.Command("start"); Contains("requires a readable precise timer")
GetTimePreciseSec = function() return 0/0 end
output = {}; p.Command("start"); Contains("requires a readable precise timer")
GetTimePreciseSec = function() return now end
UpdateAddOnMemoryUsage = function() error("unavailable") end
output = {}; p.Command("start"); parent(); p.Command("stop"); p.Command("report")
Contains("Addon memory readings unavailable")
Contains("Parent: 1 calls")
p.Command("invalid"); Contains("/snp perf start | stop | report")
print = originalPrint
print("Profiler smoke: passed")
