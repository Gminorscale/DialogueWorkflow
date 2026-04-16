--[[
    DMN Project Search — module

    Loaded by DMN_DialogueWorkflow.lua via loadModule("project_search")
    or by the standalone DMN_ProjectSearch.lua wrapper.

    Returns a table of draw functions. Call init(deps) once before drawing
    to supply shared theme helpers from the host script.
]]

local reaper = reaper

-- ── Dependency slots (filled by init) ────────────────────────────────────────

local rgba, tcol, THEME

local THEME_FALLBACK = {
    type_marker     = {0.40, 0.75, 1.00, 1.0},
    type_region     = {0.40, 0.90, 0.55, 1.0},
    type_track      = {1.00, 0.75, 0.30, 1.0},
    type_item       = {0.85, 0.55, 1.00, 1.0},
    hint_text       = {0.60, 0.60, 0.60, 1.0},
    text_disabled   = {0.50, 0.50, 0.50, 1.0},
    frame_bg        = {0.18, 0.18, 0.20, 1.0},
    frame_bg_hover  = {0.24, 0.24, 0.28, 1.0},
    button_active   = {0.70, 0.35, 0.10, 1.0},
    accent          = {1.00, 0.50, 0.15, 1.0},
}

-- ── ExtState keys ────────────────────────────────────────────────────────────

local EXT_SECTION     = "DMN_ProjectSearch"
local EXT_PATHS       = "project_paths"
local EXT_RECURSE     = "recurse_subfolders"
local EXT_PRESETS     = "preset_list"
local EXT_PRESET_PFX  = "preset_data_"

-- ── State ────────────────────────────────────────────────────────────────────

local project_paths   = {}
local recurse_sub     = true
local search_query    = ""
local search_buf      = ""
local filter_markers  = true
local filter_regions  = true
local filter_tracks   = true
local filter_items    = true

local scanned_files   = {}
local scan_cache      = {}
local all_results     = {}
local filtered_results= {}
local is_scanning     = false
local scan_progress   = 0
local scan_total      = 0
local last_scan_time  = 0
local status_msg      = ""
local sort_column     = 0
local sort_ascending  = true

local path_input_buf  = ""
local preset_name_buf = ""
local show_save_popup = false
local selected_result = -1

local debug_enabled = false
local debug_log = {}

local find_buf       = ""
local replace_buf    = ""
local fr_filter_markers = true
local fr_filter_regions = true
local fr_filter_tracks  = false
local fr_filter_items   = false
local fr_preview     = {}
local fr_selected    = {}
local fr_status      = ""
local fr_case_sens   = false

local function dbg(msg)
    debug_log[#debug_log + 1] = string.format("[%s] %s", os.date("%H:%M:%S"), msg)
    if #debug_log > 500 then table.remove(debug_log, 1) end
end

local function clean_path(p)
    p = p:match("^%s*(.-)%s*$") or p
    p = p:gsub('^"', ""):gsub('"$', "")
    p = p:gsub("^'", ""):gsub("'$", "")
    p = p:match("^%s*(.-)%s*$") or p
    return p
end

-- ── Persistence ──────────────────────────────────────────────────────────────

local function save_paths()
    local s = table.concat(project_paths, "|")
    reaper.SetExtState(EXT_SECTION, EXT_PATHS, s, true)
    reaper.SetExtState(EXT_SECTION, EXT_RECURSE, recurse_sub and "1" or "0", true)
end

local function load_paths()
    local s = reaper.GetExtState(EXT_SECTION, EXT_PATHS)
    project_paths = {}
    if s and s ~= "" then
        for p in s:gmatch("[^|]+") do
            project_paths[#project_paths + 1] = clean_path(p)
        end
    end
    local r = reaper.GetExtState(EXT_SECTION, EXT_RECURSE)
    recurse_sub = (r ~= "0")
end

local function get_preset_names()
    local s = reaper.GetExtState(EXT_SECTION, EXT_PRESETS)
    local names = {}
    if s and s ~= "" then
        for n in s:gmatch("[^|]+") do names[#names + 1] = n end
    end
    return names
end

local function save_preset(name)
    local names = get_preset_names()
    local found = false
    for _, n in ipairs(names) do
        if n == name then found = true; break end
    end
    if not found then names[#names + 1] = name end
    reaper.SetExtState(EXT_SECTION, EXT_PRESETS, table.concat(names, "|"), true)
    reaper.SetExtState(EXT_SECTION, EXT_PRESET_PFX .. name, table.concat(project_paths, "|"), true)
end

local function load_preset(name)
    local s = reaper.GetExtState(EXT_SECTION, EXT_PRESET_PFX .. name)
    project_paths = {}
    if s and s ~= "" then
        for p in s:gmatch("[^|]+") do project_paths[#project_paths + 1] = clean_path(p) end
    end
    save_paths()
end

local function delete_preset(name)
    local names = get_preset_names()
    local new = {}
    for _, n in ipairs(names) do
        if n ~= name then new[#new + 1] = n end
    end
    reaper.SetExtState(EXT_SECTION, EXT_PRESETS, table.concat(new, "|"), true)
    reaper.DeleteExtState(EXT_SECTION, EXT_PRESET_PFX .. name, true)
end

-- ── File utilities ───────────────────────────────────────────────────────────

local sep = package.config:sub(1, 1)

local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

local function get_filename(path)
    return path:match("([^/\\]+)$") or path
end

local function collect_rpp_files(root, recurse)
    local files = {}
    local function scan(dir)
        dbg("  enumerate dir: " .. dir)
        local i = 0
        local file_count = 0
        while true do
            local fname = reaper.EnumerateFiles(dir, i)
            if not fname then break end
            if fname:lower():match("%.rpp$") then
                files[#files + 1] = dir .. sep .. fname
            end
            file_count = file_count + 1
            i = i + 1
        end
        dbg("    files in dir: " .. file_count .. " total, " .. #files .. " .rpp so far")
        if recurse then
            local j = 0
            while true do
                local subdir = reaper.EnumerateSubdirectories(dir, j)
                if not subdir then break end
                scan(dir .. sep .. subdir)
                j = j + 1
            end
        end
    end
    scan(root)
    return files
end

-- ── RPP text parser ──────────────────────────────────────────────────────────

local function format_time(seconds)
    if not seconds then return "0:00.000" end
    local neg = seconds < 0
    if neg then seconds = -seconds end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    local prefix = neg and "-" or ""
    if h > 0 then
        return string.format("%s%d:%02d:%06.3f", prefix, h, m, s)
    else
        return string.format("%s%d:%06.3f", prefix, m, s)
    end
end

local function unquote(s)
    if not s then return "" end
    s = s:match('^"(.*)"$') or s:match("^'(.*)'$") or s:match("^`(.*)`$") or s
    return s
end

local function tokenize_line(line)
    local tokens = {}
    local i = 1
    local len = #line
    while i <= len do
        while i <= len and line:sub(i, i):match("%s") do i = i + 1 end
        if i > len then break end
        local ch = line:sub(i, i)
        if ch == '"' or ch == "'" or ch == "`" then
            local close = ch
            local j = i + 1
            while j <= len and line:sub(j, j) ~= close do j = j + 1 end
            tokens[#tokens + 1] = line:sub(i + 1, j - 1)
            i = j + 1
        else
            local j = i
            while j <= len and not line:sub(j, j):match("%s") do j = j + 1 end
            tokens[#tokens + 1] = line:sub(i, j - 1)
            i = j
        end
    end
    return tokens
end

local function parse_rpp(filepath)
    local f = io.open(filepath, "r")
    if not f then return nil end

    local results = { markers = {}, regions = {}, tracks = {}, items = {} }

    local region_starts = {}
    local in_track = false
    local track_depth = 0
    local track_name = ""
    local in_item = false
    local item_depth = 0
    local item_pos = 0
    local item_len = 0
    local item_name = ""
    local item_notes = ""
    local in_notes = false
    local item_track = ""
    local depth = 0

    for line in f:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")

        if in_notes then
            if trimmed == ">" then
                in_notes = false
            else
                local note_text = trimmed:match("^|(.*)$") or trimmed
                if item_notes ~= "" then item_notes = item_notes .. " " end
                item_notes = item_notes .. note_text
            end
        elseif trimmed:sub(1, 1) == "<" then
            depth = depth + 1
            local chunk_name = trimmed:sub(2):match("^(%S+)")
            if chunk_name == "TRACK" then
                in_track = true; track_depth = depth; track_name = ""
            elseif chunk_name == "ITEM" and in_track then
                in_item = true; item_depth = depth
                item_pos = 0; item_len = 0; item_name = ""; item_notes = ""
                item_track = track_name
            elseif chunk_name == "NOTES" and in_item then
                in_notes = true
            end
        elseif trimmed == ">" then
            if in_item and depth == item_depth then
                local display = item_name
                if display == "" and item_notes ~= "" then display = item_notes end
                if display ~= "" then
                    results.items[#results.items + 1] = {
                        name = display, position = item_pos,
                        length = item_len, track = item_track,
                    }
                end
                in_item = false
            elseif in_track and depth == track_depth then
                if track_name ~= "" then
                    results.tracks[#results.tracks + 1] = { name = track_name }
                end
                in_track = false
            end
            depth = depth - 1
        elseif trimmed:sub(1, 7) == "MARKER " then
            local tokens = tokenize_line(trimmed)
            local idx   = tonumber(tokens[2])
            local pos   = tonumber(tokens[3])
            local name  = tokens[4] or ""
            local flags = tonumber(tokens[5]) or 0
            if idx and pos then
                local is_region = (flags % 2 == 1)
                if is_region then
                    local existing = region_starts[idx]
                    if existing then
                        local rname = existing.name
                        if rname == "" and name ~= "" then rname = name end
                        results.regions[#results.regions + 1] = {
                            name = rname,
                            position = math.min(existing.start, pos),
                            length = math.abs(pos - existing.start),
                        }
                        region_starts[idx] = nil
                    else
                        region_starts[idx] = { name = name, start = pos }
                    end
                else
                    if name ~= "" then
                        results.markers[#results.markers + 1] = { name = name, position = pos }
                    end
                end
            end
        elseif in_track and not in_item and trimmed:sub(1, 5) == "NAME " then
            track_name = unquote(trimmed:sub(6))
        elseif in_item and not in_notes then
            if trimmed:sub(1, 9) == "POSITION " then
                item_pos = tonumber(trimmed:sub(10)) or 0
            elseif trimmed:sub(1, 7) == "LENGTH " then
                item_len = tonumber(trimmed:sub(8)) or 0
            elseif trimmed:sub(1, 5) == "NAME " then
                item_name = unquote(trimmed:sub(6))
            end
        end
    end

    for _, rs in pairs(region_starts) do
        if rs.name ~= "" then
            results.regions[#results.regions + 1] = {
                name = rs.name, position = rs.start, length = 0,
            }
        end
    end

    f:close()
    return results
end

-- ── Forward declarations ─────────────────────────────────────────────────────

local apply_filter
local do_sort

-- ── Scanning ─────────────────────────────────────────────────────────────────

local scan_file_list  = {}
local scan_file_idx   = 0
local scan_start_time = 0

local function begin_scan()
    scan_file_list = {}
    dbg("begin_scan: " .. #project_paths .. " configured path(s), recurse=" .. tostring(recurse_sub))
    for pi, raw_path in ipairs(project_paths) do
        local path = clean_path(raw_path)
        project_paths[pi] = path
        dbg("  path[" .. pi .. "]: " .. path)
        if path:lower():match("%.rpp$") then
            local exists = file_exists(path)
            dbg("    -> single .rpp, exists=" .. tostring(exists))
            if exists then scan_file_list[#scan_file_list + 1] = path end
        else
            dbg("    -> folder, enumerating...")
            local files = collect_rpp_files(path, recurse_sub)
            dbg("    -> found " .. #files .. " .rpp file(s)")
            for fi, f in ipairs(files) do
                scan_file_list[#scan_file_list + 1] = f
                if fi <= 10 then dbg("      " .. f) end
            end
            if #files > 10 then dbg("      ... and " .. (#files - 10) .. " more") end
        end
    end
    scan_file_idx   = 0
    scan_total      = #scan_file_list
    scan_progress   = 0
    is_scanning     = true
    scan_start_time = reaper.time_precise()
    all_results     = {}
    scan_cache      = {}
    status_msg      = "Scanning " .. scan_total .. " project(s)..."
    dbg("Total files to scan: " .. scan_total)
end

local SCAN_BATCH_SIZE = 3

local function scan_step()
    if not is_scanning then return end
    local batch_end = math.min(scan_file_idx + SCAN_BATCH_SIZE, scan_total)
    for i = scan_file_idx + 1, batch_end do
        local filepath = scan_file_list[i]
        local fname = get_filename(filepath)
        dbg("Parsing [" .. i .. "/" .. scan_total .. "]: " .. fname)
        local ok_parse, parsed = pcall(parse_rpp, filepath)
        if not ok_parse then dbg("  ERROR parsing: " .. tostring(parsed)); parsed = nil end
        if parsed then
            dbg(string.format("  -> markers=%d  regions=%d  tracks=%d  items=%d",
                #parsed.markers, #parsed.regions, #parsed.tracks, #parsed.items))
            scan_cache[filepath] = parsed
            for _, m in ipairs(parsed.markers) do
                all_results[#all_results + 1] = {
                    type = "Marker", name = m.name, position = m.position,
                    length = 0, track = "", project = fname, projpath = filepath,
                }
            end
            for _, r in ipairs(parsed.regions) do
                all_results[#all_results + 1] = {
                    type = "Region", name = r.name, position = r.position,
                    length = r.length, track = "", project = fname, projpath = filepath,
                }
            end
            for _, t in ipairs(parsed.tracks) do
                all_results[#all_results + 1] = {
                    type = "Track", name = t.name, position = 0,
                    length = 0, track = t.name, project = fname, projpath = filepath,
                }
            end
            for _, it in ipairs(parsed.items) do
                all_results[#all_results + 1] = {
                    type = "Item", name = it.name, position = it.position,
                    length = it.length, track = it.track, project = fname, projpath = filepath,
                }
            end
        end
    end
    scan_file_idx = batch_end
    scan_progress = batch_end
    if scan_file_idx >= scan_total then
        is_scanning = false
        local elapsed = reaper.time_precise() - scan_start_time
        status_msg = string.format("Scanned %d project(s) — %d results in %.2fs",
            scan_total, #all_results, elapsed)
        dbg("Scan complete: " .. status_msg)
        last_scan_time = os.time()
        apply_filter()
        dbg("After filter: " .. #filtered_results .. " visible results")
    end
end

-- ── Filtering / searching ────────────────────────────────────────────────────

apply_filter = function()
    filtered_results = {}
    local q = search_query:lower()
    for _, r in ipairs(all_results) do
        local type_ok = (r.type == "Marker" and filter_markers)
                     or (r.type == "Region" and filter_regions)
                     or (r.type == "Track"  and filter_tracks)
                     or (r.type == "Item"   and filter_items)
        if type_ok then
            if q == "" or r.name:lower():find(q, 1, true)
                       or r.track:lower():find(q, 1, true)
                       or r.project:lower():find(q, 1, true) then
                filtered_results[#filtered_results + 1] = r
            end
        end
    end
    if sort_column > 0 then do_sort() end
end

local sort_keys = { "type", "name", "position", "track", "project" }

do_sort = function()
    local key = sort_keys[sort_column]
    if not key then return end
    local asc = sort_ascending
    table.sort(filtered_results, function(a, b)
        local va, vb = a[key], b[key]
        if type(va) == "string" then va = va:lower(); vb = vb:lower() end
        if asc then return va < vb else return va > vb end
    end)
end

-- ── Navigation ───────────────────────────────────────────────────────────────

local function navigate_to_result(r)
    local projpath = r.projpath
    if not projpath then return end
    local already_open = false
    local proj_count = 0
    while true do
        local proj = reaper.EnumProjects(proj_count)
        if not proj then break end
        local _, ppath = reaper.EnumProjects(proj_count)
        if ppath and ppath ~= "" then
            local norm_a = ppath:lower():gsub("/", "\\")
            local norm_b = projpath:lower():gsub("/", "\\")
            if norm_a == norm_b then
                reaper.SelectProjectInstance(proj)
                already_open = true
                break
            end
        end
        proj_count = proj_count + 1
    end
    if not already_open then reaper.Main_openProject(projpath) end
    if r.position and r.position > 0 then
        reaper.SetEditCurPos(r.position, true, false)
    end
end

-- ── UI Helpers ───────────────────────────────────────────────────────────────

local function count_type(typename)
    local c = 0
    for _, r in ipairs(all_results) do
        if r.type == typename then c = c + 1 end
    end
    return c
end

local function colored_toggle(ctx, label, value, color_key)
    local tc = THEME[color_key]
    if not tc then tc = {1, 1, 1, 1} end
    local col = rgba(tc[1], tc[2], tc[3], tc[4])
    local dim = rgba(tc[1] * 0.4, tc[2] * 0.4, tc[3] * 0.4, 1.0)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(), col)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),
        value and dim or tcol("frame_bg"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(),
        value and dim or tcol("frame_bg_hover"))
    local changed, new_val = reaper.ImGui_Checkbox(ctx, label, value)
    reaper.ImGui_PopStyleColor(ctx, 3)
    return changed, new_val
end

local function type_color(typename)
    if typename == "Marker" then return tcol("type_marker") end
    if typename == "Region" then return tcol("type_region") end
    if typename == "Track"  then return tcol("type_track") end
    if typename == "Item"   then return tcol("type_item") end
    return tcol("text") or rgba(1, 1, 1, 1)
end

-- ── Draw: Setup ──────────────────────────────────────────────────────────────

local function draw_setup(ctx)
    reaper.ImGui_Spacing(ctx)

    if reaper.ImGui_CollapsingHeader(ctx, "Project Folders", reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
        reaper.ImGui_PushItemWidth(ctx, -160)
        local _, buf = reaper.ImGui_InputTextWithHint(ctx, "##ps_path_input",
            "Folder path or .rpp file path...", path_input_buf, 0)
        path_input_buf = buf
        reaper.ImGui_PopItemWidth(ctx)
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Add##ps_add_path", 70) then
            local cleaned = clean_path(path_input_buf)
            if cleaned ~= "" then
                project_paths[#project_paths + 1] = cleaned
                path_input_buf = ""
                save_paths()
            end
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.JS_Dialog_BrowseForFolder then
            if reaper.ImGui_Button(ctx, "Browse...##ps_browse", 80) then
                local retval, folder = reaper.JS_Dialog_BrowseForFolder("Select project folder", "")
                if retval == 1 and folder and folder ~= "" then
                    project_paths[#project_paths + 1] = folder
                    save_paths()
                end
            end
        end

        reaper.ImGui_Spacing(ctx)
        local _, rv = reaper.ImGui_Checkbox(ctx, "Include subfolders##ps", recurse_sub)
        if rv ~= recurse_sub then recurse_sub = rv; save_paths() end

        reaper.ImGui_Spacing(ctx)
        if reaper.ImGui_Button(ctx, "Discover .rpp files in folders##ps_discover") then
            local folders = {}
            for _, p in ipairs(project_paths) do
                if not p:lower():match("%.rpp$") then folders[#folders + 1] = p end
            end
            if #folders == 0 then
                for _, p in ipairs(project_paths) do
                    local dir = p:match("^(.*)[/\\]")
                    if dir then folders[#folders + 1] = dir end
                end
            end
            local discovered, seen = {}, {}
            dbg("Discover: scanning " .. #folders .. " folder(s)")
            for _, dir in ipairs(folders) do
                local files = collect_rpp_files(dir, true)
                for _, fp in ipairs(files) do
                    local key = fp:lower():gsub("/", "\\")
                    if not seen[key] then seen[key] = true; discovered[#discovered + 1] = fp end
                end
            end
            dbg("Discover: found " .. #discovered .. " unique .rpp file(s)")
            if #discovered > 0 then
                project_paths = discovered; save_paths()
                status_msg = "Discovered " .. #discovered .. " .rpp file(s)"
            else
                status_msg = "No .rpp files found in the configured folders"
            end
        end
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), "Find all .rpp files in folders above")

        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)

        local remove_idx = nil
        if #project_paths == 0 then
            reaper.ImGui_TextColored(ctx, tcol("hint_text"),
                "No project paths configured. Add folders or .rpp files above.")
        else
            for i, p in ipairs(project_paths) do
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), rgba(0.6, 0.2, 0.2, 1))
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), rgba(0.8, 0.25, 0.25, 1))
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), rgba(0.5, 0.15, 0.15, 1))
                if reaper.ImGui_SmallButton(ctx, "X##ps_rm_" .. i) then remove_idx = i end
                reaper.ImGui_PopStyleColor(ctx, 3)
                reaper.ImGui_SameLine(ctx)
                local is_file = p:lower():match("%.rpp$")
                if file_exists(p) or (not is_file) then
                    reaper.ImGui_Text(ctx, p)
                else
                    reaper.ImGui_TextColored(ctx, rgba(1, 0.4, 0.4, 1), p .. "  (not found)")
                end
            end
        end
        if remove_idx then table.remove(project_paths, remove_idx); save_paths() end
    end

    reaper.ImGui_Spacing(ctx)

    if reaper.ImGui_CollapsingHeader(ctx, "Presets##ps", reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
        local presets = get_preset_names()
        if reaper.ImGui_Button(ctx, "Save As...##ps_save_preset") then
            show_save_popup = true; preset_name_buf = ""
        end
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), "Save current path list as a reusable preset")
        if show_save_popup then
            reaper.ImGui_OpenPopup(ctx, "Save Preset##ps_popup")
            show_save_popup = false
        end
        if reaper.ImGui_BeginPopup(ctx, "Save Preset##ps_popup") then
            reaper.ImGui_Text(ctx, "Preset name:")
            local _, nbuf = reaper.ImGui_InputText(ctx, "##ps_preset_name", preset_name_buf, 0)
            preset_name_buf = nbuf
            if reaper.ImGui_Button(ctx, "Save##ps_confirm", 120) and preset_name_buf ~= "" then
                save_preset(preset_name_buf); reaper.ImGui_CloseCurrentPopup(ctx)
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Cancel##ps_cancel", 120) then reaper.ImGui_CloseCurrentPopup(ctx) end
            reaper.ImGui_EndPopup(ctx)
        end
        reaper.ImGui_Spacing(ctx)
        if #presets == 0 then
            reaper.ImGui_TextColored(ctx, tcol("hint_text"), "No presets saved yet.")
        else
            for _, name in ipairs(presets) do
                if reaper.ImGui_Button(ctx, "Load##ps_load_" .. name, 50) then load_preset(name) end
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), rgba(0.6, 0.2, 0.2, 1))
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), rgba(0.8, 0.25, 0.25, 1))
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), rgba(0.5, 0.15, 0.15, 1))
                if reaper.ImGui_SmallButton(ctx, "Del##ps_del_" .. name) then delete_preset(name) end
                reaper.ImGui_PopStyleColor(ctx, 3)
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_Text(ctx, name)
            end
        end
    end

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    local scan_w = reaper.ImGui_GetContentRegionAvail(ctx)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x2a7a2aff)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x35a035ff)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x1e5c1eff)
    if not is_scanning then
        if reaper.ImGui_Button(ctx, "Scan Projects##ps_scan", scan_w, 36) then begin_scan() end
    else
        reaper.ImGui_Button(ctx, "Scanning...##ps_scan_busy", scan_w, 36)
    end
    reaper.ImGui_PopStyleColor(ctx, 3)

    if is_scanning then
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_ProgressBar(ctx, scan_total > 0 and (scan_progress / scan_total) or 0, -1, 0,
            string.format("Scanning %d / %d...", scan_progress, scan_total))
    end

    if not is_scanning and #all_results > 0 then
        reaper.ImGui_Spacing(ctx)
        local mc, rc, tc2, ic = 0, 0, 0, 0
        for _, r in ipairs(all_results) do
            if     r.type == "Marker" then mc = mc + 1
            elseif r.type == "Region" then rc = rc + 1
            elseif r.type == "Track"  then tc2 = tc2 + 1
            elseif r.type == "Item"   then ic = ic + 1 end
        end
        reaper.ImGui_TextColored(ctx, tcol("type_marker"), string.format("Markers: %d", mc))
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextColored(ctx, tcol("type_region"), string.format("  Regions: %d", rc))
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextColored(ctx, tcol("type_track"),  string.format("  Tracks: %d", tc2))
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextColored(ctx, tcol("type_item"),   string.format("  Items: %d", ic))
    end
end

-- ── Draw: Search ─────────────────────────────────────────────────────────────

local function draw_search(ctx)
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_PushItemWidth(ctx, -1)
    local changed
    changed, search_buf = reaper.ImGui_InputTextWithHint(
        ctx, "##ps_search", "Search markers, regions, tracks, items...", search_buf, 0)
    reaper.ImGui_PopItemWidth(ctx)
    if changed then search_query = search_buf; apply_filter() end

    reaper.ImGui_Spacing(ctx)

    local all_on = filter_markers and filter_regions and filter_tracks and filter_items
    local ch_all, val_all = reaper.ImGui_Checkbox(ctx, "All (" .. #all_results .. ")##ps_fall", all_on)
    if ch_all then
        filter_markers = val_all; filter_regions = val_all
        filter_tracks = val_all; filter_items = val_all; apply_filter()
    end
    reaper.ImGui_SameLine(ctx)
    local ch_m, val_m = colored_toggle(ctx, "Markers (" .. count_type("Marker") .. ")##ps_fm", filter_markers, "type_marker")
    if ch_m then filter_markers = val_m; apply_filter() end
    reaper.ImGui_SameLine(ctx)
    local ch_r, val_r = colored_toggle(ctx, "Regions (" .. count_type("Region") .. ")##ps_fr", filter_regions, "type_region")
    if ch_r then filter_regions = val_r; apply_filter() end
    reaper.ImGui_SameLine(ctx)
    local ch_t, val_t = colored_toggle(ctx, "Tracks (" .. count_type("Track") .. ")##ps_ft", filter_tracks, "type_track")
    if ch_t then filter_tracks = val_t; apply_filter() end
    reaper.ImGui_SameLine(ctx)
    local ch_i, val_i = colored_toggle(ctx, "Items (" .. count_type("Item") .. ")##ps_fi", filter_items, "type_item")
    if ch_i then filter_items = val_i; apply_filter() end

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)

    if is_scanning then
        reaper.ImGui_ProgressBar(ctx, scan_total > 0 and (scan_progress / scan_total) or 0, -1, 0,
            string.format("Scanning %d / %d...", scan_progress, scan_total))
        reaper.ImGui_Spacing(ctx)
    end
    if status_msg ~= "" and not is_scanning then
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), status_msg)
        reaper.ImGui_Spacing(ctx)
    end

    local tflags = reaper.ImGui_TableFlags_Borders() + reaper.ImGui_TableFlags_RowBg()
                 + reaper.ImGui_TableFlags_Resizable() + reaper.ImGui_TableFlags_ScrollY()
                 + reaper.ImGui_TableFlags_SizingStretchProp() + reaper.ImGui_TableFlags_Sortable()
    local avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
    if reaper.ImGui_BeginTable(ctx, "ps_results", 5, tflags, 0, avail_h - 4) then
        reaper.ImGui_TableSetupColumn(ctx, "Type",     reaper.ImGui_TableColumnFlags_WidthFixed(),   60)
        reaper.ImGui_TableSetupColumn(ctx, "Name",     reaper.ImGui_TableColumnFlags_WidthStretch(), 0)
        reaper.ImGui_TableSetupColumn(ctx, "Position", reaper.ImGui_TableColumnFlags_WidthFixed(),  90)
        reaper.ImGui_TableSetupColumn(ctx, "Track",    reaper.ImGui_TableColumnFlags_WidthFixed(), 120)
        reaper.ImGui_TableSetupColumn(ctx, "Project",  reaper.ImGui_TableColumnFlags_WidthFixed(), 180)
        reaper.ImGui_TableSetupScrollFreeze(ctx, 0, 1)
        reaper.ImGui_TableHeadersRow(ctx)
        if reaper.ImGui_TableNeedSort and reaper.ImGui_TableGetColumnSortSpecs then
            if reaper.ImGui_TableNeedSort(ctx) then
                local ok2, rv2, col_idx, _, sort_dir =
                    pcall(reaper.ImGui_TableGetColumnSortSpecs, ctx, 0)
                if ok2 and rv2 then
                    sort_column = col_idx + 1
                    sort_ascending = (sort_dir == reaper.ImGui_SortDirection_Ascending())
                    do_sort()
                end
            end
        end
        local MAX_VIS = 5000
        local disp = math.min(#filtered_results, MAX_VIS)
        for i = 1, disp do
            local r = filtered_results[i]
            reaper.ImGui_TableNextRow(ctx)
            reaper.ImGui_TableNextColumn(ctx)
            reaper.ImGui_TextColored(ctx, type_color(r.type), r.type)
            reaper.ImGui_TableNextColumn(ctx)
            local sf = reaper.ImGui_SelectableFlags_SpanAllColumns()
                     + reaper.ImGui_SelectableFlags_AllowDoubleClick()
            if reaper.ImGui_Selectable(ctx, r.name .. "##ps_r" .. i, selected_result == i, sf) then
                selected_result = i
                if reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then navigate_to_result(r) end
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_BeginTooltip(ctx)
                reaper.ImGui_Text(ctx, r.type .. ": " .. r.name)
                reaper.ImGui_Text(ctx, "Position: " .. format_time(r.position))
                if r.length > 0 then reaper.ImGui_Text(ctx, "Length: " .. format_time(r.length)) end
                if r.track ~= "" then reaper.ImGui_Text(ctx, "Track: " .. r.track) end
                reaper.ImGui_Text(ctx, "Project: " .. r.project)
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_TextColored(ctx, tcol("hint_text"), "Double-click to open project and navigate")
                reaper.ImGui_EndTooltip(ctx)
            end
            reaper.ImGui_TableNextColumn(ctx)
            if r.type ~= "Track" then reaper.ImGui_Text(ctx, format_time(r.position))
            else reaper.ImGui_TextColored(ctx, tcol("hint_text"), "--") end
            reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, r.track)
            reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, r.project)
        end
        if #filtered_results > MAX_VIS then
            reaper.ImGui_TableNextRow(ctx); reaper.ImGui_TableNextColumn(ctx)
            reaper.ImGui_TextColored(ctx, tcol("hint_text"),
                string.format("... and %d more (narrow your search)", #filtered_results - MAX_VIS))
        end
        reaper.ImGui_EndTable(ctx)
    end
end

-- ── Find & Replace engine ────────────────────────────────────────────────────

local function fr_build_preview()
    fr_preview = {}
    if find_buf == "" then return end
    for filepath, parsed in pairs(scan_cache) do
        local fname = get_filename(filepath)
        local function check(list, typename, flag)
            if not flag then return end
            for _, entry in ipairs(list) do
                local name = entry.name
                local found
                if fr_case_sens then found = name:find(find_buf, 1, true)
                else found = name:lower():find(find_buf:lower(), 1, true) end
                if found then
                    local new_name
                    local escaped = find_buf:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
                    if fr_case_sens then
                        new_name = name:gsub(escaped, replace_buf)
                    else
                        local ci = escaped:gsub("%a", function(c) return "[" .. c:upper() .. c:lower() .. "]" end)
                        new_name = name:gsub(ci, replace_buf)
                    end
                    fr_preview[#fr_preview + 1] = {
                        type = typename, old_name = name, new_name = new_name,
                        project = fname, projpath = filepath,
                        position = entry.position or 0, track = entry.track or "",
                    }
                end
            end
        end
        check(parsed.markers, "Marker", fr_filter_markers)
        check(parsed.regions, "Region", fr_filter_regions)
        check(parsed.tracks,  "Track",  fr_filter_tracks)
        check(parsed.items,   "Item",   fr_filter_items)
    end
    table.sort(fr_preview, function(a, b)
        if a.projpath ~= b.projpath then return a.projpath < b.projpath end
        return a.old_name < b.old_name
    end)
    fr_selected = {}
    for i = 1, #fr_preview do fr_selected[i] = true end
    fr_status = #fr_preview .. " match(es) found — all selected"
    dbg("Find & Replace preview: " .. fr_status)
end

local function fr_execute_replace(selected_only)
    if find_buf == "" or #fr_preview == 0 then return end
    local reps_by_file = {}
    for i, m in ipairs(fr_preview) do
        if not selected_only or fr_selected[i] then
            if not reps_by_file[m.projpath] then reps_by_file[m.projpath] = {} end
            reps_by_file[m.projpath][m.old_name] = m.new_name
        end
    end
    local total_reps, files_mod = 0, 0
    for filepath, name_map in pairs(reps_by_file) do
        local f = io.open(filepath, "r")
        if not f then dbg("Replace ERROR: cannot read " .. filepath); goto cont end
        local content = f:read("*a"); f:close()
        local original = content
        for old_name, new_name in pairs(name_map) do
            content = content:gsub(
                old_name:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1"),
                new_name:gsub("%%", "%%%%"))
            total_reps = total_reps + 1
        end
        if content ~= original then
            local bf = io.open(filepath .. ".bak", "w")
            if bf then bf:write(original); bf:close() end
            local wf = io.open(filepath, "w")
            if wf then wf:write(content); wf:close(); files_mod = files_mod + 1
                dbg("Replaced in: " .. filepath)
            else dbg("Replace ERROR: cannot write " .. filepath) end
        end
        ::cont::
    end
    fr_status = string.format("Replaced %d name(s) in %d file(s). Backups saved as .bak", total_reps, files_mod)
    dbg(fr_status)
    if files_mod > 0 then begin_scan() end
end

local function fr_count_selected()
    local c = 0
    for i = 1, #fr_preview do if fr_selected[i] then c = c + 1 end end
    return c
end

-- ── Draw: Find & Replace ─────────────────────────────────────────────────────

local function draw_find_replace(ctx)
    reaper.ImGui_Spacing(ctx)
    if next(scan_cache) == nil then
        reaper.ImGui_TextColored(ctx, tcol("hint_text"),
            "No scanned data. Go to Setup and click Scan Projects first.")
        return
    end
    reaper.ImGui_Text(ctx, "Find:")
    reaper.ImGui_PushItemWidth(ctx, -1)
    local chf, nf = reaper.ImGui_InputTextWithHint(ctx, "##ps_fr_find", "Text to find in names...", find_buf, 0)
    reaper.ImGui_PopItemWidth(ctx)
    if chf then find_buf = nf end
    reaper.ImGui_Text(ctx, "Replace with:")
    reaper.ImGui_PushItemWidth(ctx, -1)
    local chr, nr = reaper.ImGui_InputTextWithHint(ctx, "##ps_fr_repl", "Replacement text...", replace_buf, 0)
    reaper.ImGui_PopItemWidth(ctx)
    if chr then replace_buf = nr end
    reaper.ImGui_Spacing(ctx)

    local chcs, vcs = reaper.ImGui_Checkbox(ctx, "Case sensitive##ps_fr", fr_case_sens)
    if chcs then fr_case_sens = vcs end
    reaper.ImGui_SameLine(ctx); reaper.ImGui_TextColored(ctx, tcol("hint_text"), "  Apply to:")
    reaper.ImGui_SameLine(ctx)
    local c1, v1 = colored_toggle(ctx, "Markers##ps_frm", fr_filter_markers, "type_marker"); if c1 then fr_filter_markers = v1 end
    reaper.ImGui_SameLine(ctx)
    local c2, v2 = colored_toggle(ctx, "Regions##ps_frr", fr_filter_regions, "type_region"); if c2 then fr_filter_regions = v2 end
    reaper.ImGui_SameLine(ctx)
    local c3, v3 = colored_toggle(ctx, "Tracks##ps_frt",  fr_filter_tracks,  "type_track");  if c3 then fr_filter_tracks  = v3 end
    reaper.ImGui_SameLine(ctx)
    local c4, v4 = colored_toggle(ctx, "Items##ps_fri",   fr_filter_items,   "type_item");   if c4 then fr_filter_items   = v4 end
    reaper.ImGui_Spacing(ctx)

    if reaper.ImGui_Button(ctx, "Preview##ps_frp", 100) then fr_build_preview() end
    local sel_count = fr_count_selected()
    local has_prev = #fr_preview > 0 and find_buf ~= ""

    reaper.ImGui_SameLine(ctx)
    if not has_prev then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), tcol("frame_bg"))
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), tcol("frame_bg"))
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), tcol("frame_bg"))
    else
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        rgba(0.7, 0.2, 0.2, 1))
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), rgba(0.85, 0.25, 0.25, 1))
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  rgba(0.55, 0.15, 0.15, 1))
    end
    if reaper.ImGui_Button(ctx, "Replace All (" .. #fr_preview .. ")##ps_fra", 140) and has_prev then fr_execute_replace(false) end
    reaper.ImGui_PopStyleColor(ctx, 3)

    reaper.ImGui_SameLine(ctx)
    local can_sel = has_prev and sel_count > 0
    if not can_sel then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), tcol("frame_bg"))
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), tcol("frame_bg"))
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), tcol("frame_bg"))
    else
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        rgba(0.6, 0.35, 0.1, 1))
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), rgba(0.75, 0.45, 0.15, 1))
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  rgba(0.5, 0.28, 0.08, 1))
    end
    if reaper.ImGui_Button(ctx, "Replace Selected (" .. sel_count .. ")##ps_frs", 160) and can_sel then fr_execute_replace(true) end
    reaper.ImGui_PopStyleColor(ctx, 3)

    if fr_status ~= "" then
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), "  " .. fr_status)
    end
    reaper.ImGui_Spacing(ctx)
    if #fr_preview > 0 then
        if reaper.ImGui_SmallButton(ctx, "Select All##ps_sa") then for i = 1, #fr_preview do fr_selected[i] = true end end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_SmallButton(ctx, "Select None##ps_sn") then for i = 1, #fr_preview do fr_selected[i] = false end end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_SmallButton(ctx, "Invert##ps_si") then for i = 1, #fr_preview do fr_selected[i] = not fr_selected[i] end end
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), "  " .. sel_count .. " / " .. #fr_preview .. " selected")
    end
    reaper.ImGui_Separator(ctx)

    if #fr_preview > 0 then
        local tfl = reaper.ImGui_TableFlags_Borders() + reaper.ImGui_TableFlags_RowBg()
                  + reaper.ImGui_TableFlags_Resizable() + reaper.ImGui_TableFlags_ScrollY()
                  + reaper.ImGui_TableFlags_SizingStretchProp()
        local ah = reaper.ImGui_GetContentRegionAvail(ctx)
        if reaper.ImGui_BeginTable(ctx, "ps_fr_tbl", 5, tfl, 0, ah - 4) then
            reaper.ImGui_TableSetupColumn(ctx, " ",       reaper.ImGui_TableColumnFlags_WidthFixed(),  24)
            reaper.ImGui_TableSetupColumn(ctx, "Type",    reaper.ImGui_TableColumnFlags_WidthFixed(),  60)
            reaper.ImGui_TableSetupColumn(ctx, "Before",  reaper.ImGui_TableColumnFlags_WidthStretch(), 0)
            reaper.ImGui_TableSetupColumn(ctx, "After",   reaper.ImGui_TableColumnFlags_WidthStretch(), 0)
            reaper.ImGui_TableSetupColumn(ctx, "Project", reaper.ImGui_TableColumnFlags_WidthFixed(), 180)
            reaper.ImGui_TableSetupScrollFreeze(ctx, 0, 1)
            reaper.ImGui_TableHeadersRow(ctx)
            local mx = math.min(#fr_preview, 2000)
            for i = 1, mx do
                local m = fr_preview[i]
                local sel = fr_selected[i]
                local alpha = sel and 1.0 or 0.35
                reaper.ImGui_TableNextRow(ctx)
                reaper.ImGui_TableNextColumn(ctx)
                local chs, vs = reaper.ImGui_Checkbox(ctx, "##ps_fsel_" .. i, sel or false)
                if chs then fr_selected[i] = vs end
                reaper.ImGui_TableNextColumn(ctx)
                local tcc = THEME["type_" .. m.type:lower()]
                if tcc then reaper.ImGui_TextColored(ctx, rgba(tcc[1], tcc[2], tcc[3], alpha), m.type)
                else reaper.ImGui_Text(ctx, m.type) end
                reaper.ImGui_TableNextColumn(ctx)
                if sel then reaper.ImGui_Text(ctx, m.old_name)
                else reaper.ImGui_TextColored(ctx, tcol("text_disabled"), m.old_name) end
                reaper.ImGui_TableNextColumn(ctx)
                if sel then reaper.ImGui_TextColored(ctx, tcol("type_region"), m.new_name)
                else reaper.ImGui_TextColored(ctx, tcol("text_disabled"), m.new_name) end
                reaper.ImGui_TableNextColumn(ctx)
                if sel then reaper.ImGui_Text(ctx, m.project)
                else reaper.ImGui_TextColored(ctx, tcol("text_disabled"), m.project) end
            end
            if #fr_preview > mx then
                reaper.ImGui_TableNextRow(ctx); reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_TableNextColumn(ctx)
                reaper.ImGui_TextColored(ctx, tcol("hint_text"), string.format("... and %d more", #fr_preview - mx))
            end
            reaper.ImGui_EndTable(ctx)
        end
    elseif find_buf ~= "" and fr_status ~= "" then
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), "No matches. Try a different search term.")
    end
end

-- ── Draw: Help / Debug ───────────────────────────────────────────────────────

local function draw_help(ctx)
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_TextWrapped(ctx,
        "DMN Project Search scans .rpp project files as text and indexes all "
        .. "markers, regions, tracks, and items for fast cross-project searching.\n\n"
        .. "Getting started:\n"
        .. "1. Go to the Setup section\n"
        .. "2. Add one or more folders containing .rpp files (or individual .rpp paths)\n"
        .. "3. Click 'Scan Projects'\n"
        .. "4. Switch to Search and type your query\n\n"
        .. "Tips:\n"
        .. "- Double-click any result to open the project and jump to that position\n"
        .. "- Use filter toggles to narrow results by type\n"
        .. "- Save your folder list as a preset for quick access\n"
        .. "- 'Include subfolders' scans nested directories recursively\n"
        .. "- Searches match against name, track name, and project filename\n\n"
        .. "The scanner reads .rpp as text — no projects are opened during scanning, "
        .. "so it's fast even with large libraries.")
    reaper.ImGui_Spacing(ctx); reaper.ImGui_Separator(ctx); reaper.ImGui_Spacing(ctx)
    local _, dv = reaper.ImGui_Checkbox(ctx, "Enable debug log##ps_dbg", debug_enabled)
    if dv ~= debug_enabled then debug_enabled = dv end
    if debug_enabled then
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Clear log##ps") then debug_log = {} end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Copy to clipboard##ps") then
            if reaper.CF_SetClipboard then reaper.CF_SetClipboard(table.concat(debug_log, "\n")) end
        end
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Text(ctx, "Log (" .. #debug_log .. " entries):")
        local ah = reaper.ImGui_GetContentRegionAvail(ctx)
        local cf = reaper.ImGui_ChildFlags_Borders()
        if reaper.ImGui_BeginChild(ctx, "##ps_debug_log", -1, ah - 4, cf) then
            for _, line in ipairs(debug_log) do reaper.ImGui_TextWrapped(ctx, line) end
            if reaper.ImGui_GetScrollY(ctx) >= reaper.ImGui_GetScrollMaxY(ctx) - 20 then
                reaper.ImGui_SetScrollHereY(ctx, 1.0)
            end
            reaper.ImGui_EndChild(ctx)
        end
    end
end

-- ── Draw: Full (standalone tab bar) ──────────────────────────────────────────

local ps_first_frame = true

local function draw_full(ctx)
    if is_scanning then scan_step() end
    if reaper.ImGui_BeginTabBar(ctx, "ps_tabs", 0) then
        local sf = 0
        if ps_first_frame then sf = reaper.ImGui_TabItemFlags_SetSelected(); ps_first_frame = false end
        if reaper.ImGui_BeginTabItem(ctx, "Setup##ps", nil, sf) then draw_setup(ctx); reaper.ImGui_EndTabItem(ctx) end
        if reaper.ImGui_BeginTabItem(ctx, "Search##ps") then draw_search(ctx); reaper.ImGui_EndTabItem(ctx) end
        if reaper.ImGui_BeginTabItem(ctx, "Find & Replace##ps") then draw_find_replace(ctx); reaper.ImGui_EndTabItem(ctx) end
        if reaper.ImGui_BeginTabItem(ctx, "Help##ps") then draw_help(ctx); reaper.ImGui_EndTabItem(ctx) end
        reaper.ImGui_EndTabBar(ctx)
    end
end

-- ── Tick (call from host main loop to drive scanning) ────────────────────────

local function tick()
    if is_scanning then scan_step() end
end

-- ── Init ─────────────────────────────────────────────────────────────────────

local function init(deps)
    deps = deps or {}
    if deps.rgba  then rgba  = deps.rgba end
    if deps.tcol  then tcol  = deps.tcol end
    if deps.THEME then THEME = deps.THEME end
    if not THEME then THEME = THEME_FALLBACK end
    for k, v in pairs(THEME_FALLBACK) do
        if not THEME[k] then THEME[k] = v end
    end
    load_paths()
end

-- ── Module export ────────────────────────────────────────────────────────────

return {
    init             = init,
    tick             = tick,
    draw_setup       = draw_setup,
    draw_search      = draw_search,
    draw_find_replace = draw_find_replace,
    draw_help        = draw_help,
    draw_full        = draw_full,
}
