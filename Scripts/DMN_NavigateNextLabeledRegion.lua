local reaper = reaper

--[[
    DMN_NavigateNextLabeledRegion

    Moves the playhead to the next region that is "owned" by the active label.

    Ownership is determined by the last marker whose name matches the active label
    and whose position is earlier than the region's start — i.e. the most recent
    label-marker before each region assigns that region to a label.

    Active label = name of the first record-armed track (falls back to the first
    selected track if none is armed).  Any string can act as a label; the script
    is not specific to speakers, scenes, or any other concept.
]]

-- ── Helpers ────────────────────────────────────────────────────────────────

local function get_active_label()
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        if reaper.GetMediaTrackInfo_Value(track, "I_RECARM") == 1 then
            local _, name = reaper.GetTrackName(track)
            return name
        end
    end
    -- Fallback: first selected track
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        if reaper.IsTrackSelected(track) then
            local _, name = reaper.GetTrackName(track)
            return name
        end
    end
    return nil
end

-- Extracts the label value from a marker name.
-- Markers named "speaker=Alice" or "character=Alice" yield "Alice".
-- Markers with no "=" are returned as-is, so plain-name markers also work.
local function extract_label(marker_name)
    local eq = marker_name:find("=")
    if eq then
        return marker_name:sub(eq + 1):match("^%s*(.-)%s*$")
    end
    return marker_name:match("^%s*(.-)%s*$")
end

-- Returns true for regions that are "content" entries (not scene/category dividers).
-- A region is a dialogue/content region when its name has no "=", or starts with
-- "entry=" or "variation=" — matching the DMN project convention.
local function is_content_region(name)
    local lower = (name or ""):lower():match("^%s*(.-)%s*$")
    if not lower:find("=") then return true end
    return lower:sub(1, 6) == "entry=" or lower:sub(1, 10) == "variation="
end

-- Returns {start, finish, name} for every content region, sorted by start position.
local function get_content_regions()
    local regions = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = num_markers + num_regions
    for i = 0, total - 1 do
        local _, is_region, pos, rend, name = reaper.EnumProjectMarkers(i)
        if is_region and is_content_region(name) then
            regions[#regions + 1] = { start = pos, finish = rend, name = name }
        end
    end
    table.sort(regions, function(a, b) return a.start < b.start end)
    return regions
end

-- Returns {pos, label} for every marker (not regions), sorted by position.
-- The label is the extracted value (after "=" if present).
local function get_label_markers()
    local markers = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = num_markers + num_regions
    for i = 0, total - 1 do
        local _, is_region, pos, _, name = reaper.EnumProjectMarkers(i)
        if not is_region and name and name ~= "" then
            markers[#markers + 1] = { pos = pos, label = extract_label(name) }
        end
    end
    table.sort(markers, function(a, b) return a.pos < b.pos end)
    return markers
end

-- Returns the label of the last marker whose position is strictly before `region_start`.
local function get_label_for_region(markers, region_start)
    local label = nil
    for _, m in ipairs(markers) do
        if m.pos < region_start then
            label = m.label
        else
            break
        end
    end
    return label
end

-- ── Main ───────────────────────────────────────────────────────────────────

local function main()
    local active_label = get_active_label()
    if not active_label or active_label == "" then return end

    local label_lower = active_label:lower()
    local markers     = get_label_markers()
    local regions     = get_content_regions()

    -- Filter to regions owned by the active label
    local labeled = {}
    for _, r in ipairs(regions) do
        local lbl = get_label_for_region(markers, r.start)
        if lbl and lbl:lower() == label_lower then
            labeled[#labeled + 1] = r
        end
    end

    if #labeled == 0 then return end

    local cursor_pos = reaper.GetCursorPosition()

    -- Find which labeled region the cursor is currently inside
    local current_idx = nil
    for i, r in ipairs(labeled) do
        if cursor_pos >= r.start and cursor_pos < r.finish then
            current_idx = i
            break
        end
    end

    local target = nil

    if current_idx then
        -- Step forward one from the current region
        if current_idx < #labeled then
            target = labeled[current_idx + 1]
        end
    else
        -- Not inside any labeled region — jump to the nearest one after the cursor
        for _, r in ipairs(labeled) do
            if r.start > cursor_pos then
                target = r
                break
            end
        end
        -- If nothing found after, wrap to the first one
        if not target then
            target = labeled[1]
        end
    end

    if target then
        reaper.SetEditCurPos(target.start, true, true)
    end
end

main()
