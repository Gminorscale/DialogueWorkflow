-- edit_tools.lua  –  Timeline-editing utilities for DMN Dialogue Workflow
-- Loaded by the main script via loadModule("edit_tools").
-- Returns a table of functions; caller wires them into button_handlers / GUI.

local function getTimeSelectionOrWholeProject()
    local start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if start_time == end_time then
        start_time = 0
        end_time = reaper.GetProjectLength(0)
    end
    return start_time, end_time
end

local function snapSelectedItemsToNearestRegionStart()
    local num_sel_items = reaper.CountSelectedMediaItems(0)
    if num_sel_items == 0 then
        reaper.ShowMessageBox("Select at least one media item.", "Snap to nearest region", 0)
        return
    end

    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    if num_regions == 0 then
        reaper.ShowMessageBox("No regions in project.", "Snap to nearest region", 0)
        return
    end

    local regions = {}
    for i = 0, (num_markers + num_regions - 1) do
        local ok, isrgn, pos, rgnend = reaper.EnumProjectMarkers(i)
        if ok and isrgn then
            regions[#regions + 1] = { start = pos, ["end"] = rgnend }
        end
    end
    if #regions == 0 then
        reaper.ShowMessageBox("No regions found.", "Snap to nearest region", 0)
        return
    end

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    for i = 0, (num_sel_items - 1) do
        local item = reaper.GetSelectedMediaItem(0, i)
        local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_center = item_pos + (item_length / 2)

        local nearest_dist = math.huge
        local nearest_region_pos = nil
        for _, r in ipairs(regions) do
            local dist = math.abs(item_center - r.start)
            if dist < nearest_dist then
                nearest_dist = dist
                nearest_region_pos = r.start
            end
        end

        if nearest_region_pos ~= nil then
            reaper.SetMediaItemPosition(item, nearest_region_pos, false)
        end
    end

    reaper.Undo_EndBlock("Snap items to nearest region start", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

local function createOrMoveMarkersFromRegionNamesInTimeSelection()
    local time_start, time_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if time_start == time_end then
        reaper.ShowMessageBox("Make a time selection first (the script will process regions fully inside it).", "Markers from region names", 0)
        return
    end

    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    if (num_markers + num_regions) == 0 then return end

    local regions = {}
    local markers = {}

    for i = 0, (num_markers + num_regions - 1) do
        local ok, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        if ok then
            if isrgn and pos >= time_start and rgnend <= time_end then
                regions[#regions + 1] = { start = pos, ["end"] = rgnend, name = name or "" }
            elseif not isrgn then
                markers[#markers + 1] = { pos = pos, name = name or "", id = markrgnindexnumber }
            end
        end
    end

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    for _, r in ipairs(regions) do
        local region_name = r.name
        if region_name and region_name ~= "" then
            local marker_pos = r.start + 0.2
            local marker_name = region_name:match("=(.+)") or region_name

            local existing_id = nil
            for _, m in ipairs(markers) do
                if (m.name == marker_name or m.name == region_name)
                   and m.pos >= r.start and m.pos <= r["end"] then
                    existing_id = m.id
                    break
                end
            end

            if existing_id ~= nil then
                reaper.SetProjectMarker2(0, existing_id, false, marker_pos, 0, marker_name)
            else
                reaper.AddProjectMarker2(0, false, marker_pos, 0, marker_name, -1, 0)
            end
        end
    end

    reaper.Undo_EndBlock("Create markers from region names (time selection)", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

-- ---------------------------------------------------------------------------
-- Move selected items to the track whose name matches the preceding Speaker=
-- marker.  Accepts getTimeSelFlag: a function returning true/false for the
-- global "Apply to time selection only" checkbox.
-- ---------------------------------------------------------------------------
local function moveItemsToSpeakerTrack(getTimeSelFlag)
    local num_sel = reaper.CountSelectedMediaItems(0)
    if num_sel == 0 then
        reaper.ShowMessageBox("Select at least one media item.", "Move to speaker track", 0)
        return
    end

    local ts_only = getTimeSelFlag and getTimeSelFlag() or false
    local ts_start, ts_end
    if ts_only then
        ts_start, ts_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
        if ts_start == ts_end then
            reaper.ShowMessageBox("No time selection set.", "Move to speaker track", 0)
            return
        end
    end

    -- Collect all Speaker= (and Character=) point markers, sorted by position
    local speaker_markers = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = num_markers + num_regions
    for i = 0, (total - 1) do
        local ok, isrgn, pos, _, name = reaper.EnumProjectMarkers(i)
        if ok and not isrgn then
            local spk = (name or ""):match("^[Ss]peaker=(.+)")
                      or (name or ""):match("^[Cc]haracter=(.+)")
            if spk then
                speaker_markers[#speaker_markers + 1] = { pos = pos, speaker = spk }
            end
        end
    end

    if #speaker_markers == 0 then
        reaper.ShowMessageBox("No Speaker= or Character= markers found in the project.", "Move to speaker track", 0)
        return
    end

    table.sort(speaker_markers, function(a, b) return a.pos < b.pos end)

    -- Build a track-name lookup (case-sensitive)
    local track_by_name = {}
    local num_tracks = reaper.CountTracks(0)
    for t = 0, (num_tracks - 1) do
        local track = reaper.GetTrack(0, t)
        local _, tname = reaper.GetTrackName(track)
        track_by_name[tname] = track
    end

    -- Binary-ish search: find latest speaker marker at or before a given position
    local function findSpeakerAt(pos)
        local best = nil
        for _, m in ipairs(speaker_markers) do
            if m.pos <= pos then
                best = m
            else
                break
            end
        end
        return best and best.speaker or nil
    end

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    local moved, skipped = 0, 0

    -- Collect items first (moving changes selection order)
    local items = {}
    for i = 0, (num_sel - 1) do
        items[#items + 1] = reaper.GetSelectedMediaItem(0, i)
    end

    for _, item in ipairs(items) do
        local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

        if ts_only and (item_pos < ts_start or item_pos >= ts_end) then
            goto continue
        end

        local speaker = findSpeakerAt(item_pos)
        if not speaker then
            skipped = skipped + 1
            goto continue
        end

        local target_track = track_by_name[speaker]
        if not target_track then
            skipped = skipped + 1
            goto continue
        end

        local current_track = reaper.GetMediaItemTrack(item)
        if current_track == target_track then
            goto continue
        end

        reaper.MoveMediaItemToTrack(item, target_track)
        moved = moved + 1

        ::continue::
    end

    reaper.Undo_EndBlock("Move items to speaker tracks", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()

    local msg = "Moved " .. tostring(moved) .. " item(s) to speaker tracks."
    if skipped > 0 then
        msg = msg .. "\nSkipped " .. tostring(skipped) .. " (no speaker marker or matching track found)."
    end
    reaper.ShowMessageBox(msg, "Move to speaker track", 0)
end

return {
    getTimeSelectionOrWholeProject                     = getTimeSelectionOrWholeProject,
    snapSelectedItemsToNearestRegionStart              = snapSelectedItemsToNearestRegionStart,
    createOrMoveMarkersFromRegionNamesInTimeSelection  = createOrMoveMarkersFromRegionNamesInTimeSelection,
    moveItemsToSpeakerTrack                            = moveItemsToSpeakerTrack,
}
