-- Run from repository root; optionally pass the other addon's picker module.
local contracts = dofile("tests/settings-contracts.lua")
local own = {name = "RPSimpleNameplates", kind = "profile", path = "RPSimpleNameplates/SettingsColorPicker.lua"}
contracts.PickerLifecycle(own)
if arg and arg[1] then
    local peer = {name = "RPEmoteMenu", kind = "theme", path = arg[1]}
    contracts.PickerLifecycle(peer)
    contracts.PickerCoexistence(own, peer)
    contracts.PickerCoexistence(peer, own)
    print("PASS actual addon picker coexistence in both directions")
end
print("PASS shared settings picker lifecycle contracts")
