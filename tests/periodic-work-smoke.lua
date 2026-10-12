-- Shared job/time budget, FIFO fairness, cancellation and failure recovery.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local ns = {}
assert(loadfile("RPSimpleNameplates/Profiler.lua"))("RPSimpleNameplates", ns)
assert(loadfile("RPSimpleNameplates/PeriodicWork.lua"))("RPSimpleNameplates", ns)
local work = ns.PeriodicWork
GetTimePreciseSec, GetTime = nil, nil

local served = {}
local function Visit(key) served[key] = (served[key] or 0) + 1; return 0.25 end
for index = 1, 20 do work.Schedule("scan", index, Visit) end
work.Schedule("restore", "restore", Visit)
work.Schedule("cast", "cast", Visit)
for frame = 1, 6 do
    local before = 0
    for _, count in pairs(served) do before = before + count end
    work.Run()
    local after = 0
    for _, count in pairs(served) do after = after + count end
    assert(after - before <= 4, "one shared four-job cap without a clock")
end
for index = 1, 20 do equal(served[index], 1, "every scan owner progresses") end
equal(served.restore, 1, "restoration is not starved")
equal(served.cast, 1, "cast retry is not starved")
work.Clear("scan"); work.Clear("restore"); work.Clear("cast")

-- Heap removals must work at every position, with no retained cancelled jobs.
for index = 1, 24 do work.Schedule("cancel", index, function(key) served[key] = (served[key] or 0) + 100 end, index / 100) end
for index = 1, 24, 2 do work.Cancel("cancel", index) end
work.Advance(1)
for _ = 1, 6 do work.Run() end
for index = 1, 24 do equal(served[index] or 0, (index <= 20 and 1 or 0) + (index % 2 == 0 and 100 or 0), "cancelled keys do not run") end

local clock, visits = 0, 0
GetTimePreciseSec = function() return clock end
for index = 1, 10 do work.Schedule("time", index, function() visits = visits + 1; clock = clock + 0.0006 end) end
work.Run(); equal(visits, 2, "one-millisecond cooperative target stops between jobs")
work.Clear("time")
visits, clock = 0, 0
work.Schedule("slow", 1, function() visits = visits + 1; clock = clock + 0.01 end)
work.Schedule("slow", 2, function() visits = visits + 1 end)
work.Run(); equal(visits, 1, "one slow atomic job prevents another job in the slice")
work.Run(); equal(visits, 2, "remaining work continues next frame")

GetTimePreciseSec = function() error("clock unavailable") end
visits = 0
for index = 1, 10 do work.Schedule("clock failure", index, function() visits = visits + 1 end) end
work.Run(); equal(visits, 4, "failed clock retains count cap")
work.Clear("clock failure")
GetTimePreciseSec = nil

work.Schedule("self cancel", 1, function() work.Cancel("self cancel", 1); return 0.25 end)
work.Run(); assert(not work.Has("self cancel", 1), "running cancellation suppresses recurrence")
work.Schedule("self clear", 1, function() work.Clear("self clear"); return 0.25 end)
work.Run(); assert(not work.Has("self clear", 1), "running group clear suppresses recurrence")
visits = 0
work.Schedule("replacement", 1, function()
    work.Schedule("replacement", 1, function() visits = visits + 1 end, 0.01)
    return 0.25
end)
work.Run(); work.Advance(0.01); work.Run()
equal(visits, 1, "callback replacement survives automatic recurrence")
assert(not work.Has("replacement", 1))

local failure, throw = {}, true
work.Schedule("error", 1, function() if throw then error(failure) end; visits = visits + 1 end)
local ok, err = pcall(work.Run)
assert(not ok and err == failure, "original error object retained")
assert(work.Has("error", 1), "failed job remains eligible for retry")
work.Schedule("other", 1, function() visits = visits + 1 end)
work.Run(); equal(visits, 2, "failure releases run guard for other work")
throw = false; work.Advance(0.25); work.Run(); equal(visits, 3, "failed owner recovers")

visits = 0
work.Schedule("nested", 1, function() visits = visits + 1; work.Run() end)
work.Schedule("nested", 2, function() visits = visits + 1 end)
work.Run(); equal(visits, 2, "nested draining cannot create another frame budget")
print("Periodic work smoke: passed")
