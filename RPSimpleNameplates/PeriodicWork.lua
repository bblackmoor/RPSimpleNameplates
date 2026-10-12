-- Simple Nameplates: fair, cooperative scheduling of routine UI work.
local _, ns = ...
local heap, groups = {}, {}
local now, sequence = 0, 0
local currentJob, running
local MAX_JOBS, TARGET_SECONDS = 4, 0.001

local function Before(a, b)
    return a.due < b.due or (a.due == b.due and a.sequence < b.sequence)
end
local function Swap(a, b)
    heap[a], heap[b] = heap[b], heap[a]
    heap[a].index, heap[b].index = a, b
end
local function Up(index)
    while index > 1 do
        local parent = math.floor(index / 2)
        if not Before(heap[index], heap[parent]) then break end
        Swap(index, parent); index = parent
    end
end
local function Down(index)
    while index * 2 <= #heap do
        local child = index * 2
        if child < #heap and Before(heap[child + 1], heap[child]) then child = child + 1 end
        if not Before(heap[child], heap[index]) then break end
        Swap(index, child); index = child
    end
end
local function Remove(job)
    local index, last = job.index, #heap
    if not index then return end
    if index ~= last then Swap(index, last) end
    heap[last], job.index = nil, nil
    groups[job.group][job.key] = nil
    if index < last then
        local replacement = heap[index]
        Up(index); Down(replacement.index)
    end
end
local function Schedule(group, key, callback, delay)
    local registry = groups[group]
    if not registry then registry = {}; groups[group] = registry end
    if registry[key] then return end -- Coalesce without moving older work back.
    sequence = sequence + 1
    local job = {group = group, key = key, callback = callback,
        due = now + (delay or 0), sequence = sequence, index = #heap + 1}
    registry[key], heap[job.index] = job, job
    Up(job.index)
end
local function Cancel(group, key)
    if currentJob and currentJob.group == group and currentJob.key == key then currentJob.cancelled = true end
    local job = groups[group] and groups[group][key]
    if job then Remove(job) end
end
local function Clear(group)
    if currentJob and currentJob.group == group then currentJob.cancelled = true end
    local registry = groups[group]
    if not registry then return end
    while next(registry) do local _, job = next(registry); Remove(job) end
end
local function Clock()
    local getter = GetTimePreciseSec or GetTime
    if type(getter) ~= "function" then return end
    local ok, value = pcall(getter)
    if ok and type(value) == "number" then return value end
end
local function Drain()
    if not heap[1] or heap[1].due > now then return end
    local started, processed = Clock(), 0
    while heap[1] and heap[1].due <= now and processed < MAX_JOBS do
        local job = heap[1]
        Remove(job) -- Callbacks may cancel/replace/enqueue jobs safely.
        processed = processed + 1
        ns.Profiler.Count("Periodic jobs", job.group)
        currentJob = job
        local ok, delay = pcall(job.callback, job.key)
        currentJob = nil
        if not ok then
            if not job.cancelled then Schedule(job.group, job.key, job.callback, 0.25) end
            error(delay, 0)
        end
        if not job.cancelled and type(delay) == "number" then Schedule(job.group, job.key, job.callback, math.max(delay, 0.001)) end
        local finished = started and Clock()
        if finished and finished >= started and finished - started >= TARGET_SECONDS then
            if heap[1] and heap[1].due <= now then ns.Profiler.Count("Periodic limits", "time target") end
            break
        end
    end
    if processed == MAX_JOBS and heap[1] and heap[1].due <= now then ns.Profiler.Count("Periodic limits", "job count") end
end
local function Run()
    if running then return end
    running = true
    local ok, err = pcall(Drain)
    running, currentJob = nil, nil
    if not ok then error(err, 0) end
end

ns.PeriodicWork = {
    Schedule = Schedule, Cancel = Cancel, Clear = Clear,
    Has = function(group, key) return groups[group] and groups[group][key] ~= nil end,
    Advance = function(elapsed)
        if type(elapsed) == "number" and elapsed > 0 then now = now + elapsed end
    end,
    Now = function() return now end,
    Run = ns.Profiler.Wrap("Periodic work", Run),
}
