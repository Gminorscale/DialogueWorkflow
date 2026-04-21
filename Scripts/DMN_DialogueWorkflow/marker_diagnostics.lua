-- marker_diagnostics.lua — Entry/marker checks for DMN Dialogue Workflow
-- Loaded by DMN_DialogueWorkflow.lua; can also be dofile'd by standalone scripts.

local r = reaper

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function getTimeSelectionOrWholeProject()
    local ts_start, ts_end = r.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if ts_start == ts_end then
        return 0, r.GetProjectLength(0)
    end
    return ts_start, ts_end
end

local function isEntryRegionName(name)
    name = tostring(name or "")
    if name == "" then return false end
    if name:match("^Category=") then return false end
    if name:match("^Context=") then return false end
    return true
end

--- All regions that look like dialogue entries, optionally clipped to [t0,t1]
local function collectEntryRegions(t0, t1)
    local _, num_m, num_r = r.CountProjectMarkers(0)
    local total = (num_m or 0) + (num_r or 0)
    local out = {}
    for i = 0, (total - 1) do
        local ok, isrgn, pos, rgnend, name = r.EnumProjectMarkers3(0, i)
        if ok and isrgn and isEntryRegionName(name) then
            if pos <= t1 and rgnend >= t0 then
                local disp = tostring(name or ""):gsub("^Entry=", "")
                out[#out + 1] = { start = pos, ["end"] = rgnend, name = disp }
            end
        end
    end
    return out
end

local function collectIndexMarkers()
    local _, num_m, num_r = r.CountProjectMarkers(0)
    local total = (num_m or 0) + (num_r or 0)
    local out = {}
    for i = 0, (total - 1) do
        local ok, isrgn, pos, _, name, mid = r.EnumProjectMarkers3(0, i)
        if ok and not isrgn then
            name = tostring(name or "")
            if name:match("^%s*[Ii][Nn][Dd][Ee][Xx]=") then
                out[#out + 1] = { pos = pos, id = mid, name = name }
            end
        end
    end
    return out
end

--- Any plain marker ID=… (numeric Notion ID or alphanumeric auto-ID)
local function collectAnyIDMarkers()
    local _, num_m, num_r = r.CountProjectMarkers(0)
    local total = (num_m or 0) + (num_r or 0)
    local out = {}
    for i = 0, (total - 1) do
        local ok, isrgn, pos, _, name = r.EnumProjectMarkers3(0, i)
        if ok and not isrgn then
            name = tostring(name or "")
            local val = name:match("[Ii][Dd]=([^%s]+)")
            if val then
                out[#out + 1] = { pos = pos, id_str = trim(val), name = name }
            end
        end
    end
    return out
end

local INDEX_TOL = 2.0
local ID_TOL = 2.5

local function findIndexForEntry(index_markers, region)
    local best = nil
    for _, m in ipairs(index_markers or {}) do
        local in_rgn = m.pos >= region.start - INDEX_TOL and m.pos <= region["end"] + 0.01
        local near_start = math.abs(m.pos - region.start) <= INDEX_TOL
        if in_rgn or near_start then
            local dist = math.abs(m.pos - region.start)
            if not best or dist < best.dist then
                best = { m = m, dist = dist }
            end
        end
    end
    return best and best.m or nil
end

local function findIDForEntry(id_markers, region)
    local best = nil
    for _, m in ipairs(id_markers or {}) do
        if m.pos >= (region.start - ID_TOL) and m.pos <= region["end"] then
            local dist = math.abs(m.pos - region.start)
            if not best or dist < best.dist then
                best = { m = m, dist = dist }
            end
        end
    end
    return best and best.m or nil
end

local function getCategoryRegions()
    local _, num_m, num_r = r.CountProjectMarkers(0)
    local total = (num_m or 0) + (num_r or 0)
    local categories = {}
    for i = 0, (total - 1) do
        local ok, isrgn, pos, rgnend, name = r.EnumProjectMarkers3(0, i)
        if ok and isrgn and name and name:match("^Category=") then
            categories[#categories + 1] = {
                start = pos,
                ["end"] = rgnend,
                category = name:match("^Category=(.+)") or "",
            }
        end
    end
    return categories
end

local function getCategoryAt(categories, pos)
    for _, c in ipairs(categories) do
        if pos >= c.start and pos <= c["end"] then return c.category end
    end
    return nil
end

local function getMediaItemsAtPosition(pos, tolerance)
    tolerance = tolerance or 1.0
    local items = {}
    local n_tr = r.CountTracks(0)
    for t = 0, (n_tr - 1) do
        local track = r.GetTrack(0, t)
        local n_it = r.CountTrackMediaItems(track)
        for it = 0, (n_it - 1) do
            local item = r.GetTrackMediaItem(track, it)
            local ipos = r.GetMediaItemInfo_Value(item, "D_POSITION")
            local ilen = r.GetMediaItemInfo_Value(item, "D_LENGTH")
            local iend = ipos + ilen
            if pos >= (ipos - tolerance) and pos <= (iend + tolerance) then
                items[#items + 1] = item
            end
        end
    end
    return items
end

--- Duplicate region names — detailed (for selection / display)
local function findDuplicateRegionNamesDetailed()
    local _, num_markers, num_regions = r.CountProjectMarkers(0)
    local total = num_markers + num_regions
    if total == 0 then return {} end
    local by_name = {}
    for i = 0, (total - 1) do
        local ok, isrgn, pos, rgnend, name = r.EnumProjectMarkers3(0, i)
        if ok and isrgn then
            name = tostring(name or "")
            if name ~= "" then
                by_name[name] = by_name[name] or {}
                local list = by_name[name]
                list[#list + 1] = { start = pos, ["end"] = rgnend }
            end
        end
    end
    local dups = {}
    for name, list in pairs(by_name) do
        if #list > 1 then
            dups[#dups + 1] = { name = name, count = #list, regions = list }
        end
    end
    table.sort(dups, function(a, b) return a.name < b.name end)
    return dups
end

--- Duplicate Index= values within same category — detailed (marker positions per group)
local function findDuplicateIndexGroupsDetailed(start_time, end_time)
    local _, num_markers, num_regions = r.CountProjectMarkers(0)
    local total = num_markers + num_regions
    if total == 0 then return {} end

    local categories = getCategoryRegions()
    local markers = {}
    for i = 0, (total - 1) do
        local ok, isrgn, pos, _, name = r.EnumProjectMarkers3(0, i)
        if ok and not isrgn and pos >= start_time and pos <= end_time then
            name = tostring(name or "")
            local idx = name:match("[Ii][Nn][Dd][Ee][Xx]=(%d+)")
            if idx then
                local cat = getCategoryAt(categories, pos) or "NoCategory"
                markers[#markers + 1] = { pos = pos, index_num = idx, category = cat }
            end
        end
    end

    local keyed = {}
    for _, m in ipairs(markers) do
        local key = m.category .. "\0" .. m.index_num
        keyed[key] = keyed[key] or { category = m.category, index_num = m.index_num, positions = {} }
        table.insert(keyed[key].positions, m.pos)
    end

    local out = {}
    for _, g in pairs(keyed) do
        if #g.positions > 1 then
            table.sort(g.positions)
            out[#out + 1] = {
                category = g.category,
                index_num = g.index_num,
                count = #g.positions,
                positions = g.positions,
            }
        end
    end
    table.sort(out, function(a, b)
        if a.category ~= b.category then return a.category < b.category end
        return tonumber(a.index_num) < tonumber(b.index_num)
    end)
    return out
end

local function shortEntryLabel(name, max_len)
    name = tostring(name or "")
    if name == "" then return "(unnamed entry)" end
    max_len = max_len or 72
    if #name <= max_len then return name end
    return name:sub(1, max_len - 1) .. "…"
end

--- opts: { time_selection_only = bool } — if true, require time selection; if false, scan entire project (ignore TS)
function findMissingIdOrIndex(opts)
    opts = opts or {}
    local t0, t1
    if opts.time_selection_only then
        t0, t1 = r.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
        if t0 == t1 then
            return nil, "Set a time selection first (or uncheck 'Time selection only' for this action in Edit → Timeline Tools)."
        end
    else
        t0, t1 = 0, r.GetProjectLength(0)
    end

    local entries = collectEntryRegions(t0, t1)
    local index_markers = collectIndexMarkers()
    local id_markers = collectAnyIDMarkers()

    local missing_rows = {}
    for _, region in ipairs(entries) do
        local has_i = findIndexForEntry(index_markers, region)
        local has_d = findIDForEntry(id_markers, region)
        if not has_i or not has_d then
            missing_rows[#missing_rows + 1] = {
                region = region,
                missing_index = not has_i,
                missing_id = not has_d,
            }
        end
    end

    return {
        entries = entries,
        missing_rows = missing_rows,
        t0 = t0,
        t1 = t1,
    }
end

function findMissingIdIndexSelectAndLog(opts)
    opts = opts or {}
    local data, err = findMissingIdOrIndex(opts)
    if not data then
        r.ShowMessageBox(err or "Unknown error.", "Missing ID / Index", 0)
        return
    end

    local rows = data.missing_rows
    if #rows == 0 then
        r.ShowMessageBox(
            string.format("No missing ID= or Index= markers for entry regions in range %.3f – %.3f s.\n(%d entry region(s) checked.)",
                data.t0, data.t1, #data.entries),
            "Missing ID / Index", 0
        )
        return
    end

    r.PreventUIRefresh(1)
    r.Undo_BeginBlock()
    r.Main_OnCommand(40289, 0) -- unselect all items
    local log_lines = {}
    local selected = 0
    for _, row in ipairs(rows) do
        local rg = row.region
        local bits = {}
        if row.missing_id then bits[#bits + 1] = "ID" end
        if row.missing_index then bits[#bits + 1] = "Index" end
        local pos = (rg.start + rg["end"]) * 0.5
        log_lines[#log_lines + 1] = string.format(
            "• %s @ %.3f – %.3f  (missing %s)",
            rg.name ~= "" and rg.name or "(unnamed)",
            rg.start,
            rg["end"],
            table.concat(bits, ", ")
        )
        for _, item in ipairs(getMediaItemsAtPosition(pos, 1.25)) do
            if not r.IsMediaItemSelected(item) then
                r.SetMediaItemSelected(item, true)
                selected = selected + 1
            end
        end
    end
    r.Undo_EndBlock("Select items: entries missing ID/Index", -1)
    r.PreventUIRefresh(-1)
    r.UpdateArrange()

    local log = table.concat(log_lines, "\n")
    r.ClearConsole()
    r.ShowConsoleMsg("=== DMN: Entries missing ID= and/or Index= ===\n\n" .. log .. "\n\nSelected " .. tostring(selected) .. " media item(s).\n")
    r.ShowMessageBox(
        string.format("%d entry region(s) missing ID= and/or Index=.\n\nDetails printed to Reaper console (View → Show console).\n\nSelected %d media item(s) overlapping those entries.",
            #rows, selected),
        "Missing ID / Index",
        0
    )
end

function formatDiagnosticsConsole(rep)
    if not rep then return "" end
    local out = {}
    out[#out + 1] = string.format("Range: %.3f – %.3f s  |  %d issue(s)\n", rep.range.t0, rep.range.t1, rep.issue_count)
    if #rep.duplicate_regions > 0 then
        out[#out + 1] = "\n── Duplicate region names ──"
        for i, d in ipairs(rep.duplicate_regions) do
            out[#out + 1] = string.format("\n[%d] %s  (%d regions with this exact name)", i, d.name, d.count)
            for j, rg in ipairs(d.regions or {}) do
                out[#out + 1] = string.format("    Region #%d: %.3f – %.3f s", j, rg.start, rg["end"])
            end
        end
    end
    if #rep.duplicate_index > 0 then
        out[#out + 1] = "\n── Duplicate Index= (same category) ──"
        for i, d in ipairs(rep.duplicate_index) do
            out[#out + 1] = string.format(
                "\n[%d] Category %q — Index=%s appears %d×",
                i, d.category, d.index_num, d.count
            )
            out[#out + 1] = "    Marker positions: " .. table.concat(d.positions, ", ")
        end
    end
    if #rep.missing_entries > 0 then
        out[#out + 1] = "\n── Missing ID= and/or Index= on entry regions ──"
        for i, row in ipairs(rep.missing_entries) do
            local rg = row.region
            local miss = {}
            if row.missing_id then miss[#miss + 1] = "ID" end
            if row.missing_index then miss[#miss + 1] = "Index" end
            out[#out + 1] = string.format(
                "\n[%d] Missing: %s\n    Time: %.3f – %.3f s\n    Entry: %s",
                i,
                table.concat(miss, " + "),
                rg.start,
                rg["end"],
                rg.name ~= "" and rg.name or "(unnamed)"
            )
        end
    end
    return table.concat(out, "\n")
end

--- Plain-text summary for ImGui (short entry lines)
function formatDiagnosticsUi(rep)
    if not rep or rep.issue_count == 0 then return "No issues." end
    local parts = {}
    parts[#parts + 1] = string.format("Found %d issue(s) in %.3f – %.3f s\n", rep.issue_count, rep.range.t0, rep.range.t1)

    if #rep.duplicate_regions > 0 then
        parts[#parts + 1] = "\n▸ DUPLICATE REGION NAMES\n"
        for _, d in ipairs(rep.duplicate_regions) do
            parts[#parts + 1] = string.format("  • %q  (%d× same name)\n", shortEntryLabel(d.name, 56), d.count)
        end
    end
    if #rep.duplicate_index > 0 then
        parts[#parts + 1] = "\n▸ DUPLICATE INDEX (per category)\n"
        for _, d in ipairs(rep.duplicate_index) do
            parts[#parts + 1] = string.format(
                "  • Category %q — Index=%s  (%d markers)\n",
                d.category,
                d.index_num,
                d.count
            )
        end
    end
    if #rep.missing_entries > 0 then
        parts[#parts + 1] = "\n▸ MISSING MARKERS ON ENTRIES\n"
        for _, row in ipairs(rep.missing_entries) do
            local rg = row.region
            local miss = {}
            if row.missing_id then miss[#miss + 1] = "ID" end
            if row.missing_index then miss[#miss + 1] = "Index" end
            parts[#parts + 1] = string.format(
                "  • %.3f s  need %s\n    %s\n",
                rg.start,
                table.concat(miss, " + "),
                shortEntryLabel(rg.name, 80)
            )
        end
    end
    parts[#parts + 1] = "\n(Full detail in Reaper console — View → Show console)\n"
    return table.concat(parts, "")
end

--- Select media items overlapping all reported problem areas (undoable)
function selectItemsForReport(rep)
    if not rep or rep.issue_count == 0 then return 0 end
    r.PreventUIRefresh(1)
    r.Undo_BeginBlock()
    r.Main_OnCommand(40289, 0)
    local n_sel = 0
    local function sel_at(pos)
        for _, item in ipairs(getMediaItemsAtPosition(pos, 1.25)) do
            if not r.IsMediaItemSelected(item) then
                r.SetMediaItemSelected(item, true)
                n_sel = n_sel + 1
            end
        end
    end
    for _, d in ipairs(rep.duplicate_regions) do
        for _, rg in ipairs(d.regions or {}) do
            sel_at((rg.start + rg["end"]) * 0.5)
        end
    end
    for _, d in ipairs(rep.duplicate_index) do
        for _, pos in ipairs(d.positions or {}) do
            sel_at(pos)
        end
    end
    for _, row in ipairs(rep.missing_entries) do
        local rg = row.region
        sel_at((rg.start + rg["end"]) * 0.5)
    end
    r.Undo_EndBlock("DMN: select items (diagnostics)", -1)
    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    return n_sel
end

--- Full diagnostic for render gate + reports. opts: { time_selection_only = bool }
function runProjectDiagnostics(opts)
    opts = opts or {}
    local t0, t1
    if opts.time_selection_only then
        t0, t1 = r.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
        if t0 == t1 then
            t0, t1 = 0, r.GetProjectLength(0)
        end
    else
        t0, t1 = 0, r.GetProjectLength(0)
    end

    local duplicate_regions = findDuplicateRegionNamesDetailed()
    local duplicate_index = findDuplicateIndexGroupsDetailed(t0, t1)

    local missing_entries = {}
    local entries = collectEntryRegions(t0, t1)
    local index_markers = collectIndexMarkers()
    local id_markers = collectAnyIDMarkers()
    for _, region in ipairs(entries) do
        local has_i = findIndexForEntry(index_markers, region)
        local has_d = findIDForEntry(id_markers, region)
        if not has_i or not has_d then
            missing_entries[#missing_entries + 1] = {
                region = region,
                missing_index = not has_i,
                missing_id = not has_d,
            }
        end
    end

    local n = #duplicate_regions + #duplicate_index + #missing_entries
    local lines = {}
    for _, d in ipairs(duplicate_regions) do
        lines[#lines + 1] = string.format("[Duplicate region name] %s  (%d×)", d.name, d.count)
    end
    for _, d in ipairs(duplicate_index) do
        lines[#lines + 1] = string.format(
            "[Duplicate Index] Category %s — Index=%s × %d",
            d.category,
            d.index_num,
            d.count
        )
    end
    for _, row in ipairs(missing_entries) do
        local rg = row.region
        local bits = {}
        if row.missing_id then bits[#bits + 1] = "ID" end
        if row.missing_index then bits[#bits + 1] = "Index" end
        lines[#lines + 1] = string.format(
            "[Missing %s] %s @ %.3f",
            table.concat(bits, " + "),
            rg.name ~= "" and rg.name or "(entry)",
            rg.start
        )
    end

    local rep = {
        issue_count = n,
        lines = lines,
        duplicate_regions = duplicate_regions,
        duplicate_index = duplicate_index,
        missing_entries = missing_entries,
        range = { t0 = t0, t1 = t1 },
    }
    rep.console_text = formatDiagnosticsConsole(rep)
    rep.ui_text = formatDiagnosticsUi(rep)
    return rep
end

return {
    findMissingIdOrIndex = findMissingIdOrIndex,
    findMissingIdIndexSelectAndLog = findMissingIdIndexSelectAndLog,
    runProjectDiagnostics = runProjectDiagnostics,
    formatDiagnosticsConsole = formatDiagnosticsConsole,
    formatDiagnosticsUi = formatDiagnosticsUi,
    selectItemsForReport = selectItemsForReport,
    getTimeSelectionOrWholeProject = getTimeSelectionOrWholeProject,
}
