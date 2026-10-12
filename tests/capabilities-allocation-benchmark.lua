-- Manual Lua allocation benchmark; never loaded by WoW or the smoke runner.
-- Run from repository root. Optional argument selects another implementation.
local context = {combatLockdown = false, revision = 1}
local ns = {AccessibleValue = function(v) return v end,
    AccessibleBoolean = function(v) if type(v) == 'boolean' then return v end end,
    WorldContext = {Get = function() return context end},
    Profiler = {Wrap = function(_, callback) return callback end}}
assert(loadfile(arg[1] or 'RPSimpleNameplates/PresentationCapabilities.lua'))('RPSimpleNameplates', ns)
local function Region()
    return {IsForbidden = function() return false end, IsProtected = function() return false end}
end
local frame = Region()
frame.name, frame.healthBar, frame.castBar = Region(), Region(), Region()
frame.healthBar.Text, frame.healthBar.LeftText, frame.healthBar.RightText = Region(), Region(), Region()
frame.HealthBarsContainer, frame.CastBarsContainer = Region(), Region()
frame.castBar.Icon = Region()
frame.RPSNInsideName, frame.RPSNFullTitleText, frame.RPSNThreatText = Region(), Region(), Region()
collectgarbage('collect'); collectgarbage('stop')
local before = collectgarbage('count')
for _ = 1, 10000 do assert(ns.PresentationCapabilities.InspectFrame(frame, context).canAccess) end
print(('10000 assessments: %.1f KiB allocated with GC paused'):format(collectgarbage('count') - before))
collectgarbage('restart')
