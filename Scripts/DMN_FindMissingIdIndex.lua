-- @description DMN: Find entry regions missing ID= or Index= (select items + log)
-- @about Companion to DMN Dialogue Workflow — scans entry regions, selects overlapping media items, prints details to the Reaper console. Respects the same rules as Edit → Utilities in the main script.
-- @version 1.0

local r = reaper

local fn = ({ r.get_action_context() })[2]
if not fn or fn == "" then
    r.ShowMessageBox("Could not determine script path.", "DMN", 0)
    return
end

local sep = package.config:sub(1, 1)
local script_dir = fn:match("(.*[" .. sep .. "])") or ""
local mod_path = script_dir .. "DMN_DialogueWorkflow" .. sep .. "marker_diagnostics.lua"

local chunk, err = loadfile(mod_path)
if not chunk then
    r.ShowMessageBox(
        "Could not load:\n" .. mod_path .. "\n\n" .. tostring(err) .. "\n\nInstall the DialogueWorkflow repo so DMN_DialogueWorkflow/marker_diagnostics.lua sits next to this script.",
        "DMN: Find missing ID/Index",
        0
    )
    return
end

local ok, M = pcall(chunk)
if not ok or type(M) ~= "table" or not M.findMissingIdIndexSelectAndLog then
    r.ShowMessageBox("marker_diagnostics.lua did not return the expected API.", "DMN", 0)
    return
end

local ts_start, ts_end = r.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
local use_ts = (ts_start ~= ts_end)
M.findMissingIdIndexSelectAndLog({ time_selection_only = use_ts })
