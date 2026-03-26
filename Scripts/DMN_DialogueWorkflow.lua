local reaper = reaper

--[[
    DMN_DialogueWorkflow — ReaImGui UI (TheBaptist-style theme)

    Import CSV data from Google Sheets URL or local file and create regions/markers.

    Requires: ReaImGui (ReaPack: search "ReaImGui")
]]

if not reaper.ImGui_CreateContext then
    reaper.ShowMessageBox(
        "This script requires ReaImGui.\nPlease install it via ReaPack:\n  Extensions > ReaPack > Browse packages > search 'ReaImGui'",
        "DMN Dialogue Workflow", 0)
    return
end

local THEME_SECTION = "DMN_DialogueWorkflow_Theme"
local FONT_OPTIONS = {
    "Segoe UI", "Arial", "Calibri", "Consolas", "Courier New",
    "Tahoma", "Trebuchet MS", "Verdana", "Georgia", "Lucida Console",
    "Cascadia Code", "JetBrains Mono", "Hack", "Inter",
}
local THEME_DEFAULTS = {
    font_name       = "Segoe UI",
    font_size_main  = 14,
    font_size_bold  = 16,
    font_size_small = 12,
    frame_rounding  = 4,
    grab_rounding   = 3,
    text            = {1.00, 1.00, 1.00, 1.0},
    text_disabled   = {0.50, 0.50, 0.50, 1.0},
    hint_text       = {0.60, 0.60, 0.60, 1.0},
    window_bg       = {0.14, 0.14, 0.16, 1.0},
    popup_bg        = {0.12, 0.12, 0.14, 1.0},
    frame_bg        = {0.18, 0.18, 0.20, 1.0},
    frame_bg_hover  = {0.24, 0.24, 0.28, 1.0},
    button          = {1.00, 0.50, 0.15, 1.0},
    button_hover    = {0.85, 0.45, 0.10, 1.0},
    button_active   = {0.70, 0.35, 0.10, 1.0},
    tab             = {0.18, 0.18, 0.22, 1.0},
    tab_hover       = {0.30, 0.30, 0.38, 1.0},
    tab_selected    = {0.25, 0.25, 0.32, 1.0},
    header          = {0.28, 0.28, 0.32, 1.0},
    header_hover    = {0.35, 0.35, 0.40, 1.0},
    header_active   = {0.40, 0.40, 0.48, 1.0},
    table_header_bg = {0.18, 0.18, 0.22, 1.0},
    table_row_bg    = {0.16, 0.16, 0.18, 1.0},
    table_row_bg_alt= {0.18, 0.18, 0.20, 1.0},
    selection       = {1.00, 0.50, 0.15, 1.0},
    selection_hover = {1.00, 0.50, 0.15, 1.0},
    selection_active= {0.70, 0.35, 0.10, 1.0},
    accent          = {1.00, 0.50, 0.15, 1.0},
    accent_dim      = {0.70, 0.35, 0.10, 1.0},
    -- Import: category group colors (0–1 RGBA; used when importing regions)
    color_regions   = true,
    region_color_1  = {1.00, 0.39, 0.39, 1.0},
    region_color_2  = {1.00, 0.65, 0.31, 1.0},
    region_color_3  = {1.00, 0.86, 0.31, 1.0},
    region_color_4  = {0.39, 0.78, 0.39, 1.0},
    region_color_5  = {0.39, 0.78, 0.86, 1.0},
    region_color_6  = {0.39, 0.59, 1.00, 1.0},
    region_color_7  = {0.71, 0.47, 1.00, 1.0},
    region_color_8  = {1.00, 0.59, 0.78, 1.0},
}

local function copy_theme(src)
    local t = {}
    for k, v in pairs(src) do
        if type(v) == "table" then t[k] = {v[1], v[2], v[3], v[4]}
        else t[k] = v end
    end
    return t
end

local THEME = copy_theme(THEME_DEFAULTS)

local function serialise_theme(t)
    local parts = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            parts[#parts+1] = k .. "=" .. v[1] .. "," .. v[2] .. "," .. v[3] .. "," .. v[4]
        elseif type(v) == "number" then
            parts[#parts+1] = k .. "=" .. tostring(v)
        elseif type(v) == "string" then
            parts[#parts+1] = k .. "=S:" .. v
        elseif type(v) == "boolean" then
            parts[#parts+1] = k .. "=B:" .. (v and "1" or "0")
        end
    end
    return table.concat(parts, "|")
end

local function deserialise_theme(s, into)
    if not s or s == "" then return end
    for part in s:gmatch("[^|]+") do
        local key, val = part:match("^(.-)=(.+)$")
        if key and val then
            if val:sub(1,2) == "S:" then into[key] = val:sub(3)
            elseif val:sub(1,2) == "B:" then into[key] = (val:sub(3) == "1")
            elseif val:find(",") then
                local r,g,b,a = val:match("([%d%.%-]+),([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)")
                if r then into[key] = {tonumber(r), tonumber(g), tonumber(b), tonumber(a)} end
            else into[key] = tonumber(val) or val end
        end
    end
end

local function load_theme()
    local s = reaper.GetExtState(THEME_SECTION, "data")
    if s and s ~= "" then deserialise_theme(s, THEME) end
end

local function save_theme()
    reaper.SetExtState(THEME_SECTION, "data", serialise_theme(THEME), true)
end

local function reset_theme()
    for k, v in pairs(THEME_DEFAULTS) do
        if type(v) == "table" then THEME[k] = {v[1], v[2], v[3], v[4]}
        else THEME[k] = v end
    end
    save_theme()
end

load_theme()

local function rgba(r, g, b, a) return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a or 1.0) end

local function tcol(key)
    local c = THEME[key]
    if not c then return rgba(1,1,1,1) end
    return rgba(c[1], c[2], c[3], c[4])
end

local FONT_SIZE_MAIN, FONT_SIZE_BOLD, FONT_SIZE_SMALL = THEME.font_size_main, THEME.font_size_bold, THEME.font_size_small

-- Cached ImGui U32 colours (optional helpers for extensions / debugging)
local COL = {}

local function apply_theme()
    FONT_SIZE_MAIN  = THEME.font_size_main
    FONT_SIZE_BOLD  = THEME.font_size_bold
    FONT_SIZE_SMALL = THEME.font_size_small
    COL.text = tcol("text")
    COL.text_disabled = tcol("text_disabled")
    COL.hint = tcol("hint_text")
    COL.window_bg = tcol("window_bg")
    COL.button = tcol("button")
    COL.accent = tcol("accent")
end
apply_theme()

local _imgui_cfg = 0
pcall(function()
    if reaper.ImGui_ConfigFlags_DockingEnable then _imgui_cfg = reaper.ImGui_ConfigFlags_DockingEnable() end
end)
local imgui_ctx = reaper.ImGui_CreateContext('DMN Dialogue Workflow', _imgui_cfg)
local font_main = reaper.ImGui_CreateFont(THEME.font_name, THEME.font_size_main)
reaper.ImGui_Attach(imgui_ctx, font_main)

local UIM = {}

local function is_checkbox_key(name)
    return name:match("^chk_") ~= nil
end

local GUI = {}
function GUI.Val(name, val)
    if val ~= nil then
        if type(val) == "table" then
            if val[1] ~= nil then UIM[name] = val[1] == true
            else UIM[name] = val end
        else UIM[name] = val end
    else
        local v = UIM[name]
        if is_checkbox_key(name) then return { v == true } end
        return v
    end
end

local function make_elm_proxy(name)
    return setmetatable({}, {
        __index = function(_, k)
            if k == "caption" then return UIM[name] end
            if k == "y" then return 0 end
            if k == "z" then return 11 end
            if k == "init" then return function() end end
            if k == "redraw" then return function() end end
            return nil
        end,
        __newindex = function(_, k, v)
            if k == "caption" then UIM[name] = v end
        end
    })
end

local elms_cache = {}
setmetatable(elms_cache, { __index = function(t, k) t[k] = make_elm_proxy(k); return t[k] end })
GUI.elms = elms_cache
GUI.redraw_z = setmetatable({}, { __index = function() return true end, __newindex = function() end })
GUI.quit = false

-- gfx polyfill (Lokasenna menus used gfx.showmenu; ImGui-only scripts may have no gfx)
if not gfx then gfx = {} end
if not gfx.showmenu then
    function gfx.showmenu(menu_str)
        local items = {}
        for x in string.gmatch(menu_str, "([^|]+)") do items[#items + 1] = x end
        if #items == 0 then return 0 end
        local msg = {}
        for i, s in ipairs(items) do msg[#msg + 1] = tostring(i) .. ") " .. tostring(s) end
        local ok = reaper.ShowMessageBox(table.concat(msg, "\n"), "Choose (enter number in next dialog)", 1)
        if ok ~= 1 then return 0 end
        local rv, num = reaper.GetUserInputs("Preset", 1, "Number 1-" .. tostring(#items) .. ":,extrawidth=40", "1")
        if not rv then return 0 end
        local n = tonumber(num)
        if n and n >= 1 and n <= #items then return n end
        return 0
    end
end
if not gfx.mouse_x then gfx.mouse_x = 0 end
if not gfx.mouse_y then gfx.mouse_y = 0 end

-- Register Lokasenna GUI.New calls as data + button handlers (no Lokasenna library)
local button_handlers = {}

function GUI.New(name, typ, opts)
    opts = opts or {}
    if typ == "Button" then
        if opts.func then button_handlers[name] = opts.func end
    elseif typ == "Textbox" then
        if UIM[name] == nil then UIM[name] = "" end
    elseif typ == "Checklist" then
        local os = opts.optsel
        if os and os[1] ~= nil then
            UIM[name] = os[1] == true
        elseif UIM[name] == nil then
            UIM[name] = false
        end
    elseif typ == "Label" then
        if opts.caption and UIM[name] == nil then UIM[name] = opts.caption end
    end
    -- Frame: ignore
end

function GUI.Init() end

-- ============================================================================
-- EXTERNAL TOOLS (referenced scripts - auto-update when source changes)
-- ============================================================================

-- Get the directory of the current script
local function getScriptDirectory()
    local info = debug.getinfo(1, "S")
    local script_path = info.source:match("@?(.+)")
    if script_path then
        return script_path:match("(.*[/\\])")
    end
    return nil
end

local SCRIPT_DIR = getScriptDirectory()

-- External tool paths (relative to script directory)
local EXTERNAL_TOOLS = {
    HandCompTool = {
        name = "Hand Compression Tool",
        description = "Automated volume riding for dialogue",
        -- Try multiple possible locations
        paths = {
            "Joachim/JN_HandCompToolV1.lua",
            "Joachim\\JN_HandCompToolV1.lua",
            "../Joachim/JN_HandCompToolV1.lua",
        }
    }
}

-- Find and validate external tool path
local function findExternalTool(tool_key)
    local tool = EXTERNAL_TOOLS[tool_key]
    if not tool then return nil, "Unknown tool: " .. tostring(tool_key) end
    
    local base_dir = SCRIPT_DIR or ""
    
    for _, rel_path in ipairs(tool.paths) do
        local full_path = base_dir .. rel_path
        local f = io.open(full_path, "r")
        if f then
            f:close()
            return full_path, nil
        end
    end
    
    return nil, "Could not find " .. tool.name .. ".\n\nLooked in:\n" .. base_dir .. "\n\nExpected: Joachim/JN_HandCompToolV1.lua"
end

-- Cache for registered script command IDs
local external_tool_cmd_ids = {}

-- Launch an external tool as a separate REAPER action (own window/context)
local function launchExternalTool(tool_key)
    local path, err = findExternalTool(tool_key)
    if not path then
        reaper.ShowMessageBox(err, "External Tool Not Found", 0)
        return false
    end
    
    -- Check if we already have a command ID cached
    local cmd_id = external_tool_cmd_ids[tool_key]
    
    if not cmd_id or cmd_id == 0 then
        -- Register the script as a temporary action to get a command ID
        -- Parameters: isAdd (true), sectionID (0 = main), scriptPath, commit (true)
        cmd_id = reaper.AddRemoveReaScript(true, 0, path, true)
        if cmd_id and cmd_id > 0 then
            external_tool_cmd_ids[tool_key] = cmd_id
        end
    end
    
    if cmd_id and cmd_id > 0 then
        -- Run as separate action - gets its own gfx context/window
        reaper.Main_OnCommand(cmd_id, 0)
        return true
    else
        -- Fallback: show message about manual setup
        reaper.ShowMessageBox(
            "Could not auto-register the script.\n\n" ..
            "To use " .. EXTERNAL_TOOLS[tool_key].name .. ":\n\n" ..
            "1. Go to Actions > Show action list\n" ..
            "2. Click 'Load ReaScript...'\n" ..
            "3. Select: " .. path .. "\n" ..
            "4. Run it from the Actions list",
            "Manual Setup Required", 0
        )
        return false
    end
end

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local MAX_COLUMNS = 10
local ROW_HEIGHT = 26
local TAB_HEIGHT = 26
local TAB_BAR_Y = 44
local CONTENT_START_Y = TAB_BAR_Y + TAB_HEIGHT + 22
local ROW_START_Y = 0
local HIDDEN_Y = -5000

local TABS = {"Import", "Record", "Edit", "Render"}
local active_tab = 1
local tab_elements = {}
local tab_scroll = { Import = 0, Record = 0, Edit = 0, Render = 0 }

local function clampScrollForTab() end

local _reapplyCleanupVisibility = nil
local function setReapplyCleanupVisibility(f) _reapplyCleanupVisibility = f end

local function applyTabPositions() end

-- Column mapping data structure
local column_mappings = {}
local active_rows = 0

-- Role tracking: which row is the entry source, category, and character column
local entry_row = 0     -- Row number that provides region names (0 = none)
local category_row = 0  -- Row number used for grouping/categories (0 = none)
local speaker_row = 0 -- Row number used for Speaker= markers (0 = none)

-- ============================================================================
-- TAB MANAGEMENT FUNCTIONS
-- ============================================================================

-- Forward declarations for functions defined later
local updateRowVisibility
local updateRoleButtonAppearances

local function registerTabElement() end

local function setTabVisible() end

local function switchToTab(tab_index)
    if tab_index < 1 or tab_index > #TABS then return end
    active_tab = tab_index
    local tab_name_now = TABS[active_tab]
    if tab_name_now and tab_scroll then tab_scroll[tab_name_now] = 0 end
    if TABS[active_tab] == "Import" and updateRowVisibility then updateRowVisibility() end
    if TABS[active_tab] == "Edit" and setCleanupStatusRowVisible then
        setCleanupStatusRowVisible(getCleanupUpdateStatusEnabled())
    end
end

local function handleTabScrollWheel() end

local function setRowVisible() end

-- Function to check if an Entry column is defined
local function hasEntryColumn()
    return entry_row > 0 and entry_row <= active_rows
end

updateRoleButtonAppearances = function()
    for i = 1, MAX_COLUMNS do
        UIM["btn_entry_" .. i]     = (i == entry_row)     and "[E]"  or "E"
        UIM["btn_category_" .. i]  = (i == category_row)  and "[C]"  or "C"
        UIM["btn_speaker_" .. i] = (i == speaker_row) and "[Sp]" or "Sp"
    end
end

updateRowVisibility = function()
    for i = 1, MAX_COLUMNS do setRowVisible(i, i <= active_rows) end
    updateRoleButtonAppearances()
end

-- ============================================================================
-- CSV PARSING AND UTILITY FUNCTIONS
-- ============================================================================

-- Safely extract a boolean from a Lokasenna GUI checklist value.
-- GUI.Val returns {true}/{false} for single-option checklists; plain booleans
-- from UIM shim.  The naïve `type(v)=="table" and v[1] or v` pattern fails
-- because `true and false or {false}` evaluates to `{false}` (truthy).
local function chkBool(v)
    if type(v) == "table" then return v[1] == true end
    return v == true
end

local function parseCSV(line)
    local res = {}
    local pos = 1
    local sep = ","
    
    while true do
        local c = string.sub(line, pos, pos)
        if c == "" then break end
        
        if c == '"' then
            local txt = ""
            pos = pos + 1
            while true do
                local startp, endp = string.find(line, '^(.-)"', pos)
                if not startp then
                    txt = txt .. string.sub(line, pos)
                    pos = string.len(line) + 1
                    break
                end
                local nextc = string.sub(line, endp + 1, endp + 1)
                if nextc == '"' then
                    txt = txt .. string.sub(line, pos, endp)
                    pos = endp + 2
                else
                    txt = txt .. string.sub(line, pos, endp - 1)
                    pos = endp + 1
                    break
                end
            end
            table.insert(res, txt)
            local nextsep = string.find(line, sep, pos)
            if not nextsep then break end
            pos = nextsep + 1
        else
            local nextsep = string.find(line, sep, pos)
            if not nextsep then
                table.insert(res, string.sub(line, pos))
                break
            end
            table.insert(res, string.sub(line, pos, nextsep - 1))
            pos = nextsep + 1
        end
    end
    
    if string.sub(line, -1) == sep then
        table.insert(res, "")
    end
    
    return res
end

local function normalizeSmartChars(str)
    if not str then return str end
    local c = string.char
    str = str:gsub(c(0xE2, 0x80, 0x9C), '"')   -- left double quotation mark
    str = str:gsub(c(0xE2, 0x80, 0x9D), '"')   -- right double quotation mark
    str = str:gsub(c(0xE2, 0x80, 0x98), "'")   -- left single quotation mark
    str = str:gsub(c(0xE2, 0x80, 0x99), "'")   -- right single quotation mark
    str = str:gsub(c(0xE2, 0x80, 0xA6), "...") -- horizontal ellipsis
    str = str:gsub(c(0xE2, 0x80, 0x93), "-")   -- en dash
    str = str:gsub(c(0xE2, 0x80, 0x94), "--")  -- em dash
    str = str:gsub(c(0xC2, 0xAB), '"')         -- left guillemet
    str = str:gsub(c(0xC2, 0xBB), '"')         -- right guillemet
    return str
end

local function safeRegionName(text)
    if not text or text == "" then return nil end
    text = text:match('^"(.*)"$') or text
    text = text:match("^%s*(.-)%s*$")
    text = normalizeSmartChars(text)
    return text ~= "" and text or nil
end

local function cleanFieldValue(value)
    if not value or value == "" then return nil end
    value = value:gsub(";$", "")
    value = value:match("^%s*(.-)%s*$")
    value = normalizeSmartChars(value)
    return value ~= "" and value or nil
end

local function getOrCreateTrack(name)
    local num_tracks = reaper.CountTracks(0)
    local track = nil
    
    for i = 0, num_tracks - 1 do
        local current_track = reaper.GetTrack(0, i)
        local _, current_name = reaper.GetTrackName(current_track)
        if current_name == name then
            track = current_track
            break
        end
    end
    
    if not track then
        reaper.InsertTrackAtIndex(num_tracks, true)
        track = reaper.GetTrack(0, num_tracks)
        reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
    end
    
    return track
end

local function addEmptyItemWithNote(track, position, length, note)
    if not note then return nil end
    local item = reaper.AddMediaItemToTrack(track)
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", position)
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length)
    reaper.ULT_SetMediaItemNote(item, note)
    return item
end

local function downloadCSV(url)
    local content
    if reaper.GetOS():match("Win") then
        local tmp = os.getenv("TEMP") or os.getenv("TMP") or "."
        local tmp_file = tmp .. "\\DMN_CSVDownload.csv"
        local ps_command = string.format(
            'powershell -NoProfile -Command "'
            .. '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; '
            .. "Invoke-WebRequest -Uri '%s' -UseBasicParsing -OutFile '%s'"
            .. '"',
            url, tmp_file
        )
        os.execute(ps_command)
        local f = io.open(tmp_file, "rb")
        if f then
            content = f:read("*a")
            f:close()
            os.remove(tmp_file)
        end
    else
        local handle = io.popen(string.format('curl -L "%s"', url))
        if handle then
            content = handle:read("*a")
            handle:close()
        end
    end
    
    -- Strip UTF-8 BOM if present (EF BB BF)
    if content and #content >= 3 then
        local bom = string.byte(content, 1) == 0xEF and 
                   string.byte(content, 2) == 0xBB and 
                   string.byte(content, 3) == 0xBF
        if bom then
            content = string.sub(content, 4)
        end
    end
    
    return content
end

local function readLocalCSV(filepath)
    local content = nil
    local file = io.open(filepath, "rb")  -- Open in binary mode to handle BOM
    if file then
        content = file:read("*a")
        file:close()
        
        -- Strip UTF-8 BOM if present (EF BB BF)
        if content and #content >= 3 then
            local bom = string.byte(content, 1) == 0xEF and 
                       string.byte(content, 2) == 0xBB and 
                       string.byte(content, 3) == 0xBF
            if bom then
                content = string.sub(content, 4)
            end
        end
    end
    return content
end

-- ============================================================================
-- RECORD TAB: Web UI helpers
-- ============================================================================

local function getPathSep()
    return package.config:sub(1, 1)
end

local function joinPath(...)
    local sep = getPathSep()
    local parts = {...}
    local out = {}
    for i = 1, #parts do
        local p = tostring(parts[i] or "")
        if p ~= "" then
            -- trim trailing/leading separators to avoid doubles
            p = p:gsub("[/\\]+$", "")
            if i > 1 then
                p = p:gsub("^[/\\]+", "")
            end
            out[#out + 1] = p
        end
    end
    return table.concat(out, sep)
end

local function fileExists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

local function readAll(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function writeAll(path, data)
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(data or "")
    f:close()
    return true
end

local function ensureDir(path)
    if not path or path == "" then return false end
    if reaper.EnumerateFiles(path, 0) ~= nil or reaper.EnumerateSubdirectories(path, 0) ~= nil then
        return true -- exists
    end

    local osname = reaper.GetOS() or ""
    if osname:match("Win") then
        os.execute('mkdir "' .. path .. '" >NUL 2>NUL')
    else
        os.execute('mkdir -p "' .. path .. '" >/dev/null 2>&1')
    end
    return true
end

local function copyFile(src, dst)
    local data = readAll(src)
    if not data then return false, "Could not read: " .. tostring(src) end
    local ok = writeAll(dst, data)
    if not ok then return false, "Could not write: " .. tostring(dst) end
    return true
end

local function openURL(url)
    if not url or url == "" then return end
    local osname = reaper.GetOS() or ""
    if osname:match("Win") then
        os.execute('start "" "' .. url .. '"')
    elseif osname:match("OSX") then
        os.execute('open "' .. url .. '"')
    else
        os.execute('xdg-open "' .. url .. '"')
    end
end

local function getScriptDir()
    local _, script_path = reaper.get_action_context()
    if not script_path or script_path == "" then return "" end
    local sep = getPathSep()
    return script_path:match("^(.*)" .. sep) or ""
end

local function findRecordWebUIFiles()
    local sep = getPathSep()
    local script_dir = getScriptDir()
    local candidates_html = {
        joinPath(script_dir, "DMN_ActorTeleprompter.html"),
        joinPath(script_dir, "reaper_www_root", "DMN_ActorTeleprompter.html"),
        joinPath(script_dir, "ActorTeleprompter.html"),
        joinPath(script_dir, "reaper_www_root", "ActorTeleprompter.html"),
        joinPath(script_dir, "DMN_RecordActor.html"),
        joinPath(script_dir, "reaper_www_root", "DMN_RecordActor.html"),
    }

    local src_html = nil
    for _, p in ipairs(candidates_html) do
        if fileExists(p) then src_html = p break end
    end

    local candidates_logo = {
        joinPath(script_dir, "Logo.png"),
        joinPath(script_dir, "reaper_www_root", "Logo.png"),
    }

    local src_logo = nil
    for _, p in ipairs(candidates_logo) do
        if fileExists(p) then src_logo = p break end
    end

    return src_html, src_logo
end

local function getTeleprompterHtmlBasename()
    local src_html = select(1, findRecordWebUIFiles())
    if src_html then
        local base = src_html:match("([^/\\\\]+)$")
        if base and base ~= "" then return base end
    end
    return "DMN_ActorTeleprompter.html"
end

local function getReaperWebRootDir()
    local res = reaper.GetResourcePath()
    return joinPath(res, "reaper_www_root")
end

-- ============================================================================
-- EDIT TAB: Marker index derivation / renaming
-- ============================================================================

local function deriveIndexSuffix(name)
    if not name or name == "" then return nil end
    -- Common patterns: "..._03" or "...-03" at end
    local digits = name:match("[_%-%s](%d+)%s*$") or name:match("[_%-%s](%d+)$")
    if not digits or digits == "" then return nil end
    return digits
end

local function trimWS(s)
    s = tostring(s or "")
    return (s:match("^%s*(.-)%s*$"))
end

local function psEscapeSingleQuoted(str)
    -- Escape for PowerShell single-quoted strings: ' -> ''
    str = tostring(str or "")
    return (str:gsub("'", "''"))
end

-- Notion API header version.
-- Notion has started issuing UUIDv8 IDs; older API versions/tools may reject these.
local NOTION_API_VERSION = "2025-09-03"

-- Notion IDs are UUID-ish strings; users often paste full Notion URLs.
-- Normalize by extracting 32 hex chars and re-hyphenating.
local function normalizeNotionId(raw)
    raw = trimWS(raw)
    if raw == "" then return "" end

    local lower = raw:lower()

    -- If the user pasted a Notion URL, prefer the ID in the path (ignore ?v= view IDs etc).
    -- Examples:
    -- https://www.notion.so/<dbid>?v=<viewid>
    -- https://*.notion.site/<dbid>?v=<viewid>
    do
        local path_id = lower:match("notion%.so/([0-9a-f]{32})")
            or lower:match("notion%.site/([0-9a-f]{32})")
        if path_id then
            return string.format("%s-%s-%s-%s-%s", path_id:sub(1, 8), path_id:sub(9, 12), path_id:sub(13, 16), path_id:sub(17, 20), path_id:sub(21, 32))
        end
    end

    -- If the string contains two IDs (db id + view id), grab the first 32-hex chunk.
    do
        local first32 = lower:match("([0-9a-f]{32})")
        if first32 then
            return string.format("%s-%s-%s-%s-%s", first32:sub(1, 8), first32:sub(9, 12), first32:sub(13, 16), first32:sub(17, 20), first32:sub(21, 32))
        end
    end

    -- Already hyphenated UUID present anywhere in the string
    do
        local hyph = lower:match("([0-9a-f]{8}%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w%w%w%w%w%w%w%w%w)")
        if hyph then
            local hex = hyph:gsub("%-", ""):gsub("[^0-9a-f]", "")
            if #hex == 32 then
                return string.format("%s-%s-%s-%s-%s", hex:sub(1, 8), hex:sub(9, 12), hex:sub(13, 16), hex:sub(17, 20), hex:sub(21, 32))
            end
        end
    end

    return raw
end

local function isValidNotionId(raw)
    raw = trimWS(raw)
    if raw == "" then return false end
    local hex = raw:lower():gsub("%-", "")
    return (#hex == 32) and (hex:match("^[0-9a-f]+$") ~= nil)
end

-- ============================================================================
-- DATABASE PRESET SYSTEM
-- ============================================================================
-- Named database presets stored in REAPER ExtState. One preset active at a time.
-- Migration: old ExtState keys are promoted to presets on first run.

local EXTSTATE_SECTION = "DMN_GoogleSheetsToRegionsAndMarkers"

local function getNotionDbPresetList()
    local raw = reaper.GetExtState(EXTSTATE_SECTION, "notion_db_preset_list") or ""
    raw = trimWS(raw)
    if raw == "" then return {} end
    local list = {}
    for name in raw:gmatch("[^|]+") do
        name = trimWS(name)
        if name ~= "" then list[#list + 1] = name end
    end
    return list
end

local function setNotionDbPresetList(list)
    reaper.SetExtState(EXTSTATE_SECTION, "notion_db_preset_list", table.concat(list, "|"), true)
end

local function getNotionDbPresetId(name)
    name = trimWS(name)
    if name == "" then return "" end
    local v = reaper.GetExtState(EXTSTATE_SECTION, "notion_db_preset__" .. name) or ""
    return trimWS(v)
end

local function saveNotionDbPreset(name, db_id)
    name = trimWS(name)
    db_id = normalizeNotionId(trimWS(db_id))
    if name == "" then return false end
    reaper.SetExtState(EXTSTATE_SECTION, "notion_db_preset__" .. name, db_id, true)
    local list = getNotionDbPresetList()
    local found = false
    for _, n in ipairs(list) do
        if n == name then found = true; break end
    end
    if not found then
        list[#list + 1] = name
        setNotionDbPresetList(list)
    end
    return true
end

local function deleteNotionDbPreset(name)
    name = trimWS(name)
    if name == "" then return end
    reaper.DeleteExtState(EXTSTATE_SECTION, "notion_db_preset__" .. name, true)
    local list = getNotionDbPresetList()
    local new_list = {}
    for _, n in ipairs(list) do
        if n ~= name then new_list[#new_list + 1] = n end
    end
    setNotionDbPresetList(new_list)
end

local function getActiveNotionDbName()
    local v = reaper.GetExtState(EXTSTATE_SECTION, "notion_active_db_name") or ""
    return trimWS(v)
end

local function setActiveNotionDbName(name)
    reaper.SetExtState(EXTSTATE_SECTION, "notion_active_db_name", trimWS(name), true)
end

local function getActiveNotionDbId()
    local name = getActiveNotionDbName()
    if name ~= "" then
        local id = getNotionDbPresetId(name)
        if id ~= "" then return normalizeNotionId(id) end
    end
    return ""
end

-- Migrate old per-database ExtState keys into the preset system (one-time).
local function migrateOldDbKeys()
    if #getNotionDbPresetList() > 0 then return end
    local old_dwarf = reaper.GetExtState(EXTSTATE_SECTION, "notion_dwarf_shouts_db_id") or ""
    old_dwarf = trimWS(old_dwarf)
    if old_dwarf ~= "" then
        saveNotionDbPreset("Dwarf Shouts", old_dwarf)
        if getActiveNotionDbName() == "" then
            setActiveNotionDbName("Dwarf Shouts")
        end
    end
    local old_omega = reaper.GetExtState(EXTSTATE_SECTION, "notion_omega_shouts_db_id") or ""
    old_omega = trimWS(old_omega)
    if old_omega ~= "" and isValidNotionId(old_omega) then
        saveNotionDbPreset("Omega Shouts", old_omega)
    end
end
migrateOldDbKeys()

-- Backward-compatible alias used throughout the script
local function getNotionDwarfShoutsDbId()
    return getActiveNotionDbId()
end

-- Clean Up uses the active database
local function getCleanupSelectedDatabaseName()
    local v = getActiveNotionDbName()
    if v == "" then v = "(not set)" end
    return v
end

local function setCleanupSelectedDatabaseName(name)
    -- Clean Up always follows the active preset; switching is done from the Notion section.
end

local function getCleanupTargetDbId()
    return getActiveNotionDbId()
end

local function runPowerShellHidden(ps_script, timeout_ms)
    -- Uses REAPER's ExecProcess to avoid popping console windows.
    -- Returns: stdout (string), exit_code (number)
    timeout_ms = tonumber(timeout_ms) or 60000
    ps_script = tostring(ps_script or "")
    if ps_script == "" then return "", 1 end

    -- IMPORTANT: Avoid -Command quoting issues by writing a temp .ps1 file.
    -- This prevents "silent failures" where nothing is returned and windows may spawn.
    local tmp_dir = joinPath(reaper.GetResourcePath(), "Scripts", "DMN_Temp")
    ensureDir(tmp_dir)

    local nonce = tostring(math.floor(reaper.time_precise() * 1000)) .. "_" .. tostring(math.random(100000, 999999))
    local tmp_path = joinPath(tmp_dir, "notion_" .. nonce .. ".ps1")

    local ok = writeAll(tmp_path, ps_script)
    if not ok then
        return "", 2
    end

    local cmd = 'powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. tmp_path .. '"'
    local out, exit_code = reaper.ExecProcess(cmd, timeout_ms)

    pcall(os.remove, tmp_path)
    return tostring(out or ""), tonumber(exit_code) or 0
end

-- Cache Notion lookups in-memory (per script run)
local NOTION_CACHE_BY_ID = {} -- [id_num] = { filename = string|nil, page_id = string|nil }
local NOTION_DATASOURCE_ID_BY_DB = {} -- [db_id] = data_source_id

-- Cache Notion database schema bits we need (Status properties + their options)
-- [db_id] = { fetched_at = number, status_props = { [prop_name] = { options = { ... } } }, prop_list = { ... } }
local NOTION_STATUS_SCHEMA_BY_DB = {}

local function hexDecodeToString(hex)
    hex = tostring(hex or "")
    if hex == "" then return "" end
    local bytes = {}
    for i = 1, #hex, 2 do
        local b = tonumber(hex:sub(i, i + 1), 16)
        if not b then break end
        bytes[#bytes + 1] = string.char(b)
    end
    return table.concat(bytes)
end

local function notionFetchStatusSchema(notion_token, db_id)
    notion_token = trimWS(notion_token)
    db_id = trimWS(db_id)
    if notion_token == "" or db_id == "" then
        return nil, "Missing token or DB id"
    end
    if not isValidNotionId(db_id) then
        return nil, "DB id does not look valid."
    end

    local osname = reaper.GetOS() or ""
    if not osname:match("Win") then
        return nil, "Status property fetch is currently implemented for Windows only."
    end

    local token_ps = psEscapeSingleQuoted(notion_token)
    local db_ps = psEscapeSingleQuoted(db_id)
    local ver_ps = psEscapeSingleQuoted(NOTION_API_VERSION)

    local ps = string.format([[
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$h = @{
  Authorization = 'Bearer %s'
  'Notion-Version' = '%s'
}
function To-Hex([string]$s) {
  if ($null -eq $s) { return '' }
  $b = [System.Text.Encoding]::UTF8.GetBytes([string]$s)
  return (($b | ForEach-Object { $_.ToString('x2') }) -join '')
}
function Get-Props($obj) {
  if (-not $obj) { return $null }
  $p = $null
  try { $p = $obj.'properties' } catch {}; if ($p) { return $p }
  try { $p = $obj.PSObject.Properties['properties'].Value } catch {}; if ($p) { return $p }
  try { $p = $obj.schema } catch {}; if ($p) { return $p }
  try { $p = $obj.schema.properties } catch {}
  return $p
}
try {
  $db = Invoke-RestMethod -Method Get -Uri ('https://api.notion.com/v1/databases/%s') -Headers $h
} catch { Write-Output ('ERR|DB|0|' + $_.Exception.Message); exit 1 }
if ($db -is [string]) { $db = $db | ConvertFrom-Json }
$src = $db; $props = Get-Props $src
if (-not $props) {
  $dsid = $null
  try {
    if ($db -and $db.data_sources -and $db.data_sources.Count -gt 0) { $dsid = $db.data_sources[0].id }
  } catch {}
  if ($dsid) {
    try {
      $src = Invoke-RestMethod -Method Get -Uri ('https://api.notion.com/v1/data_sources/' + $dsid) -Headers $h
    } catch { Write-Output ('ERR|DS|0|' + $_.Exception.Message); exit 1 }
    if ($src -is [string]) { $src = $src | ConvertFrom-Json }
    $props = Get-Props $src
  }
}

if (-not $props) {
  $keys = @()
  try { $keys = @($src.PSObject.Properties | ForEach-Object { $_.Name }) } catch {}
  $k = ($keys -join ',')
  if (-not $k -or $k.Trim() -eq '') { $k = '(none)' }
  Write-Output ('ERR|DB|0|No properties on database/data_source (top-level keys: ' + $k + ')')
  exit 2
}

foreach ($kv in $props.PSObject.Properties) {
  $p = $kv.Value
  if (-not $p) { continue }
  $type = [string]$p.type
  if ($type -ne 'status' -and $type -ne 'select') { continue }

  $name = [string]$p.name
  if (-not $name -or $name.Trim() -eq '') { $name = [string]$kv.Name }
  if (-not $name -or $name.Trim() -eq '') { continue }

  Write-Output ('PROP|' + (To-Hex $name))
  try {
    $optList = $null
    if ($type -eq 'status' -and $p.status -and $p.status.options) { $optList = $p.status.options }
    elseif ($type -eq 'select' -and $p.select -and $p.select.options) { $optList = $p.select.options }
    if ($optList) {
      foreach ($o in $optList) {
        if ($o -and $o.name) {
          $oid = ''
          try { if ($o.id) { $oid = [string]$o.id } } catch {}
          Write-Output ('OPT|' + (To-Hex $name) + '|' + (To-Hex ([string]$o.name)) + '|' + $oid)
        }
      }
    }
  } catch {}
}
]], token_ps, ver_ps, db_ps)

    local out, exit_code = runPowerShellHidden(ps, 20000)
    out = tostring(out or "")

    local err_line = nil
    local props = {} -- [name] = { options = {}, options_by_name = {} }
    for line in out:gmatch("[^\r\n]+") do
        local t = trimWS(line)
        if t:sub(1, 4) == "ERR|" then
            err_line = t
        else
            local p_hex = t:match("^PROP|(.+)$")
            if p_hex then
                local name = hexDecodeToString(trimWS(p_hex))
                if name ~= "" then
                    props[name] = props[name] or { options = {}, options_by_name = {} }
                end
            else
                -- New format: OPT|prop_hex|opt_name_hex|opt_id
                local prop_hex, opt_hex, opt_id = t:match("^OPT|([^|]+)|([^|]+)|?(.*)$")
                if prop_hex and opt_hex then
                    local pname = hexDecodeToString(trimWS(prop_hex))
                    local oname = hexDecodeToString(trimWS(opt_hex))
                    opt_id = trimWS(opt_id or "")
                    if pname ~= "" and oname ~= "" then
                        props[pname] = props[pname] or { options = {}, options_by_name = {} }
                        table.insert(props[pname].options, oname)
                        props[pname].options_by_name[oname] = { name = oname, id = opt_id }
                    end
                end
            end
        end
    end

    if err_line then
        return nil, err_line
    end

    local prop_list = {}
    for name, _ in pairs(props) do
        table.insert(prop_list, name)
        table.sort(props[name].options, function(a, b) return tostring(a) < tostring(b) end)
    end
    table.sort(prop_list, function(a, b) return tostring(a) < tostring(b) end)

    local schema = {
        fetched_at = reaper.time_precise(),
        status_props = props,
        prop_list = prop_list,
    }
    NOTION_STATUS_SCHEMA_BY_DB[db_id] = schema
    return schema
end

-- Fetch Status Schema in background. Returns response_path or nil, err. Caller polls with notionFetchStatusSchemaPoll.
local function notionFetchStatusSchemaAsync(notion_token, db_id)
    notion_token = trimWS(notion_token or "")
    db_id = trimWS(db_id or "")
    if notion_token == "" or db_id == "" then return nil, "Missing token or DB id" end
    if not isValidNotionId(db_id) then return nil, "DB id does not look valid." end
    local osname = reaper.GetOS() or ""
    if not osname:match("Win") then return nil, "Status property fetch is currently implemented for Windows only." end

    local tmp_dir = joinPath(reaper.GetResourcePath(), "Scripts", "DMN_Temp")
    ensureDir(tmp_dir)
    local req_path = joinPath(tmp_dir, "DMN_FetchSchemaRequest.txt")
    local res_path = joinPath(tmp_dir, "DMN_FetchSchemaResponse.txt")
    local script_path = joinPath(tmp_dir, "DMN_FetchSchemaBatch.ps1")
    local ver = NOTION_API_VERSION or "2022-06-28"
    if not writeAll(req_path, table.concat({ notion_token, db_id, ver }, "\n")) then return nil, "Could not write request file" end
    pcall(os.remove, res_path)

    local ps_script = [[
param($ReqPath, $ResPath)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$lines = Get-Content $ReqPath
$token = ($lines[0] -replace '\s+$' -replace '^\s+' -replace "`r|`n", '').Trim()
$dbId = ($lines[1] -replace '\s+$' -replace '^\s+' -replace "`r|`n", '').Trim()
$ver = ($lines[2] -replace '\s+$' -replace '^\s+' -replace "`r|`n", '').Trim()
$h = @{ Authorization = "Bearer $token"; 'Notion-Version' = $ver }
function To-Hex([string]$s) {
  if ($null -eq $s) { return '' }
  $b = [System.Text.Encoding]::UTF8.GetBytes([string]$s)
  return (($b | ForEach-Object { $_.ToString('x2') }) -join '')
}
function Write-Out([string]$s) { Add-Content -Path $ResPath -Value $s }
function Get-Props($obj) {
  if (-not $obj) { return $null }
  $p = $null
  try { $p = $obj.'properties' } catch {}; if ($p) { return $p }
  try { $p = $obj.PSObject.Properties['properties'].Value } catch {}; if ($p) { return $p }
  try { $p = $obj.schema } catch {}; if ($p) { return $p }
  try { $p = $obj.schema.properties } catch {}
  return $p
}
try {
  $db = Invoke-RestMethod -Method Get -Uri ('https://api.notion.com/v1/databases/' + $dbId) -Headers $h
} catch { Write-Out ('ERR|DB|0|' + $_.Exception.Message); Write-Out 'DONE'; exit 1 }
if ($db -is [string]) { $db = $db | ConvertFrom-Json }
$src = $db; $props = Get-Props $src
if (-not $props) {
  $dsid = $null
  try { if ($db -and $db.data_sources -and $db.data_sources.Count -gt 0) { $dsid = $db.data_sources[0].id } } catch {}
  if ($dsid) {
    try {
      $src = Invoke-RestMethod -Method Get -Uri ('https://api.notion.com/v1/data_sources/' + $dsid) -Headers $h
    } catch { Write-Out ('ERR|DS|0|' + $_.Exception.Message); Write-Out 'DONE'; exit 1 }
    if ($src -is [string]) { $src = $src | ConvertFrom-Json }
    $props = Get-Props $src
  }
}
if (-not $props) {
  $keys = @(); try { $keys = @($src.PSObject.Properties | ForEach-Object { $_.Name }) } catch {}
  Write-Out ('ERR|DB|0|No properties (keys: ' + ($keys -join ',') + ')'); Write-Out 'DONE'; exit 2
}
foreach ($kv in $props.PSObject.Properties) {
  $p = $kv.Value; if (-not $p) { continue }
  $type = [string]$p.type; if ($type -ne 'status' -and $type -ne 'select') { continue }
  $name = [string]$p.name; if (-not $name -or $name.Trim() -eq '') { $name = [string]$kv.Name }; if (-not $name -or $name.Trim() -eq '') { continue }
  Write-Out ('PROP|' + (To-Hex $name))
  try {
    $optList = $null
    if ($type -eq 'status' -and $p.status -and $p.status.options) { $optList = $p.status.options }
    elseif ($type -eq 'select' -and $p.select -and $p.select.options) { $optList = $p.select.options }
    if ($optList) {
      foreach ($o in $optList) {
        if ($o -and $o.name) { $oid = ''; try { if ($o.id) { $oid = [string]$o.id } } catch {}; Write-Out ('OPT|' + (To-Hex $name) + '|' + (To-Hex ([string]$o.name)) + '|' + $oid) }
      }
    }
  } catch {}
}
Write-Out 'DONE'
]]
    if not writeAll(script_path, ps_script) then return nil, "Could not write script" end
    local cmd = 'start /B powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. script_path:gsub('"', '\\"') .. '" "' .. req_path:gsub('"', '\\"') .. '" "' .. res_path:gsub('"', '\\"') .. '"'
    os.execute(cmd)
    return res_path
end

-- Poll Fetch Status Schema response. Returns: schema when DONE; nil, "pending" when still running; nil, err on error.
local function notionFetchStatusSchemaPoll(response_path, db_id)
    local f = io.open(response_path, "r")
    if not f then return nil, "pending" end
    local content = f:read("*all")
    f:close()
    if not content or content == "" then return nil, "pending" end
    if not content:match("DONE") then return nil, "pending" end
    local err_line = nil
    local props = {}
    for line in content:gmatch("[^\r\n]+") do
        local t = trimWS(line)
        if t == "DONE" then break end
        if t:sub(1, 4) == "ERR|" then err_line = t; break end
        local p_hex = t:match("^PROP|(.+)$")
        if p_hex then
            local name = hexDecodeToString(trimWS(p_hex))
            if name ~= "" then props[name] = props[name] or { options = {}, options_by_name = {} } end
        else
            local prop_hex, opt_hex, opt_id = t:match("^OPT|([^|]+)|([^|]+)|?(.*)$")
            if prop_hex and opt_hex then
                local pname = hexDecodeToString(trimWS(prop_hex))
                local oname = hexDecodeToString(trimWS(opt_hex))
                opt_id = trimWS(opt_id or "")
                if pname ~= "" and oname ~= "" then
                    props[pname] = props[pname] or { options = {}, options_by_name = {} }
                    table.insert(props[pname].options, oname)
                    props[pname].options_by_name[oname] = { name = oname, id = opt_id }
                end
            end
        end
    end
    if err_line then return nil, err_line end
    local prop_list = {}
    for name, _ in pairs(props) do
        table.insert(prop_list, name)
        table.sort(props[name].options, function(a, b) return tostring(a) < tostring(b) end)
    end
    table.sort(prop_list, function(a, b) return tostring(a) < tostring(b) end)
    local schema = { fetched_at = reaper.time_precise(), status_props = props, prop_list = prop_list }
    if db_id and db_id ~= "" then NOTION_STATUS_SCHEMA_BY_DB[db_id] = schema end
    return schema
end

local function notionGetDataSourceId(notion_token, db_id)
    notion_token = trimWS(notion_token)
    db_id = trimWS(db_id)
    if notion_token == "" or db_id == "" then return nil, "Missing token or DB id" end

    if NOTION_DATASOURCE_ID_BY_DB[db_id] then
        return NOTION_DATASOURCE_ID_BY_DB[db_id]
    end

    local osname = reaper.GetOS() or ""
    if not osname:match("Win") then
        return nil, "Notion data source lookup is currently implemented for Windows only."
    end

    local token_ps = psEscapeSingleQuoted(notion_token)
    local db_ps = psEscapeSingleQuoted(db_id)
    local ver_ps = psEscapeSingleQuoted(NOTION_API_VERSION)
    local ps = string.format([[
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$h = @{
  Authorization = 'Bearer %s'
  'Notion-Version' = '%s'
}
try {
  $db = Invoke-RestMethod -Method Get -Uri ('https://api.notion.com/v1/databases/%s') -Headers $h
  $dsid = $null
  try { if ($db -and $db.data_sources -and $db.data_sources.Count -gt 0) { $dsid = $db.data_sources[0].id } } catch {}
  if ($dsid) { Write-Output ('OK|' + $dsid) } else { Write-Output 'ERR|0|No data_sources on database' }
} catch {
  $status = $null
  $body = $null
  try {
    if ($_.Exception.Response) {
      $status = [int]$_.Exception.Response.StatusCode
      $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $body = $sr.ReadToEnd(); $sr.Close()
    }
  } catch {}
  try { if (-not $body -and $_.ErrorDetails -and $_.ErrorDetails.Message) { $body = $_.ErrorDetails.Message } } catch {}
  if ($status -and $body) { Write-Output ('ERR|' + $status + '|' + $body) }
  elseif ($status) { Write-Output ('ERR|' + $status + '|Request failed') }
  else { Write-Output ('ERR|0|' + $_.Exception.Message) }
}
]], token_ps, ver_ps, db_ps)

    local out = tostring((select(1, runPowerShellHidden(ps, 20000))) or "")
    local ok_line, err_line = nil, nil
    for line in out:gmatch("[^\r\n]+") do
        local t = trimWS(line)
        if t:sub(1, 3) == "OK|" then ok_line = t break end
        if t:sub(1, 4) == "ERR|" then err_line = t end
    end
    if ok_line then
        local dsid = trimWS(ok_line:sub(4) or "")
        if dsid ~= "" then
            NOTION_DATASOURCE_ID_BY_DB[db_id] = dsid
            return dsid
        end
    end
    if err_line then
        return nil, err_line
    end
    return nil, "Failed to resolve Notion data source id"
end

local function notionTestToken(notion_token)
    notion_token = trimWS(notion_token)
    if notion_token == "" then
        return false, "Token is empty."
    end

    local osname = reaper.GetOS() or ""
    if not osname:match("Win") then
        return false, "Token test is currently implemented for Windows only."
    end

    local token_ps = psEscapeSingleQuoted(notion_token)
    local ver_ps = psEscapeSingleQuoted(NOTION_API_VERSION)
    local ps = string.format([[
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$h = @{
  Authorization = 'Bearer %s'
  'Notion-Version' = '%s'
}
try {
  $me = Invoke-RestMethod -Method Get -Uri 'https://api.notion.com/v1/users/me' -Headers $h
  if ($me -and $me.id) {
    Write-Output ('OK|' + $me.id)
  } else {
    exit 2
  }
} catch {
  # bubble up a helpful error message (status + body if possible)
  $status = $null
  $body = $null
  $details = $null
  try {
    if ($_.Exception.Response) {
      $status = [int]$_.Exception.Response.StatusCode
      $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $body = $sr.ReadToEnd()
      $sr.Close()
    }
  } catch {}
  try { if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $details = $_.ErrorDetails.Message } } catch {}
  if (-not $body -and $details) { $body = $details }

  if ($status -and $body) {
    Write-Output ('ERR|' + $status + '|' + $body)
  } elseif ($status) {
    Write-Output ('ERR|' + $status + '|Request failed')
  } else {
    $msg = $_.Exception.Message
    if ($msg) { Write-Output ('ERR|0|' + $msg) } else { Write-Output 'ERR|0|Request failed' }
  }
  exit 3
}
]], token_ps, ver_ps)

    local out, exit_code = runPowerShellHidden(ps, 20000)
    out = tostring(out or "")

    -- Sometimes ExecProcess/PowerShell yields extra leading lines (e.g. "0"),
    -- so scan line-by-line for the first OK| or ERR| record.
    local ok_line = nil
    local err_line = nil
    for line in out:gmatch("[^\r\n]+") do
        local t = trimWS(line)
        if t:sub(1, 3) == "OK|" then
            ok_line = t
            break
        elseif t:sub(1, 4) == "ERR|" then
            err_line = t
            -- don't break; prefer OK| if present later
        end
    end

    if ok_line then
        local id = trimWS(ok_line:sub(4) or "")
        return true, "Token is valid. Notion user id: " .. id
    end

    if err_line then
        local status, body = err_line:match("^ERR|(%-?%d+)|(.+)$")
        status = tonumber(status) or 0
        body = trimWS(body or "Request failed")

        -- Make the message actionable
        if status == 401 then
            return false, "Token test failed (401 Unauthorized).\n\nMost likely: token is invalid/revoked, or you pasted the wrong token type.\nGet it from: notion.so/my-integrations → your integration → Internal Integration Token."
        elseif status == 403 then
            return false, "Token test failed (403 Forbidden).\n\nToken is valid but lacks access. Make sure the integration is connected to the workspace/page/database."
        elseif status == 429 then
            return false, "Token test failed (429 Rate limited).\n\nWait a bit and try again."
        elseif status ~= 0 then
            return false, "Token test failed (" .. tostring(status) .. ").\n\nNotion response:\n" .. body
        else
            return false, "Token test failed.\n\nError:\n" .. body
        end
    end

    local out_trim = trimWS(out)
    return false, "Token test failed.\n\nExit code: " .. tostring(exit_code) .. "\nOutput:\n" .. (out_trim ~= "" and out_trim or "(no output)")
end

-- Look up the Notion row by numeric ID and return either:
-- - "Index" formula value (preferred - returns index directly)
-- - "FilenameFormula" text (extract index from suffix)
-- - Legacy fallbacks for backwards compatibility
local function notionGetFileNameFormulaByID(notion_token, id_num)
    notion_token = trimWS(notion_token)
    id_num = tonumber(id_num)
    if not notion_token or notion_token == "" or not id_num then return nil end

    if NOTION_CACHE_BY_ID[id_num] and NOTION_CACHE_BY_ID[id_num].filename ~= nil then
        return NOTION_CACHE_BY_ID[id_num].filename
    end

    -- Windows-first implementation (your setup). Other OSes will need curl/python plumbing later.
    local osname = reaper.GetOS() or ""
    if not osname:match("Win") then
        return nil
    end

    local db_id = getNotionDwarfShoutsDbId()
    if not isValidNotionId(db_id) then
        return nil
    end

    local dsid, ds_err = notionGetDataSourceId(notion_token, db_id)
    if not dsid then
        return nil
    end

    local token_ps = psEscapeSingleQuoted(notion_token)
    local ds_ps = psEscapeSingleQuoted(dsid)
    local ver_ps = psEscapeSingleQuoted(NOTION_API_VERSION)

    -- Try filtering by unique_id first (Notion "ID" property), fall back to number equals if needed.
    local ps = string.format([[
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$p = @{
  Authorization = 'Bearer %s'
  'Notion-Version' = '%s'
  'Content-Type' = 'application/json'
}
function Get-FileNameFormula([string]$bodyJson) {
  try {
    $resp = Invoke-RestMethod -Method Post -Uri ('https://api.notion.com/v1/data_sources/%s/query') -Headers $p -Body $bodyJson -ContentType 'application/json'
    if (-not $resp) { return 'ERR|QUERY|No response' }
    if (-not $resp.results) { return ('ERR|QUERY|No results array (keys: ' + ($resp.PSObject.Properties.Name -join ',') + ')') }
    if ($resp.results.Count -lt 1) { return 'ERR|QUERY|Results array empty' }
    
    $row = $resp.results[0]
    if (-not $row) { return 'ERR|QUERY|First result is null' }
    
    $props = $null
    try { $props = $row.properties } catch {}
    if (-not $props) { 
      try { $props = $row.PSObject.Properties['properties'].Value } catch {}
    }
    if (-not $props) { 
      return ('ERR|QUERY|No properties (row keys: ' + ($row.PSObject.Properties.Name -join ',') + ')')
    }
    
    # Priority 1: "Index" formula - returns the index directly
    $indexProp = $null
    try { $indexProp = $props.'Index' } catch { $indexProp = $null }
    if (-not $indexProp) {
      try { $indexProp = $props.PSObject.Properties['Index'].Value } catch { $indexProp = $null }
    }
    if ($indexProp) {
      # Index can be a number property (Notion "Number" type) or formula
      $numVal = $null
      try { $numVal = $indexProp.number } catch { $numVal = $null }
      if (-not $numVal) { try { $numVal = $indexProp.PSObject.Properties['number'].Value } catch { $numVal = $null } }
      if ($numVal -ne $null -and $numVal.ToString().Trim() -ne '') { return $numVal.ToString().Trim() }
      # Formula properties have .formula.string or .formula.number
      $formulaVal = $null
      try { $formulaVal = $indexProp.formula } catch { $formulaVal = $null }
      if (-not $formulaVal) {
        try { $formulaVal = $indexProp.PSObject.Properties['formula'].Value } catch { $formulaVal = $null }
      }
      if ($formulaVal) {
        $text = $null
        try { $text = $formulaVal.string } catch {}
        if (-not $text) { try { $text = $formulaVal.number } catch {} }
        if (-not $text) { try { $text = $formulaVal.PSObject.Properties['string'].Value } catch {} }
        if (-not $text) { try { $text = $formulaVal.PSObject.Properties['number'].Value } catch {} }
        if ($text -and $text.ToString().Trim() -ne '') { return $text.ToString() }
      }
    }
    
    # Priority 2+: FilenameFormula and legacy fallbacks (rich_text properties)
    $fieldNames = @('FilenameFormula', 'FileName Formula from Notion', 'FileName Formula From Sheets', 'FileName Formula from Sheets')
    $propKeys = $null
    foreach ($fieldName in $fieldNames) {
      $fieldProp = $null
      try { $fieldProp = $props.$fieldName } catch { $fieldProp = $null }
      if (-not $fieldProp) {
        try { $fieldProp = $props.PSObject.Properties[$fieldName].Value } catch { $fieldProp = $null }
      }
      if (-not $fieldProp) { continue }

      $rt = $null
      try { $rt = $fieldProp.rich_text } catch { $rt = $null }
      if (-not $rt) {
        try { $rt = $fieldProp.PSObject.Properties['rich_text'].Value } catch { $rt = $null }
      }
      if ($rt) { 
        $text = ($rt | ForEach-Object { $_.plain_text }) -join ''
        if ($text -and $text.ToString().Trim() -ne '') { return $text }
      }
      
      # Also check if it's a formula type (FilenameFormula might be a formula too)
      $formulaVal = $null
      try { $formulaVal = $fieldProp.formula } catch { $formulaVal = $null }
      if (-not $formulaVal) {
        try { $formulaVal = $fieldProp.PSObject.Properties['formula'].Value } catch { $formulaVal = $null }
      }
      if ($formulaVal) {
        $text = $null
        try { $text = $formulaVal.string } catch {}
        if (-not $text) { try { $text = $formulaVal.number } catch {} }
        if ($text -and $text.ToString().Trim() -ne '') { return $text.ToString() }
      }
    }

    if (-not $propKeys) {
      $propKeys = @()
      try { $propKeys = @($props.PSObject.Properties | ForEach-Object { $_.Name }) } catch {}
    }
    return ('ERR|QUERY|Index/FileName field missing/blank (tried: Index, ' + ($fieldNames -join ', ') + '; available: ' + ($propKeys -join ', ') + ')')
  } catch {
    $errMsg = $_.Exception.Message
    $status = $null
    $body = $null
    try {
      if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
        $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $body = $sr.ReadToEnd(); $sr.Close()
      }
    } catch {}
    if ($status -and $body) {
      return ('ERR|QUERY|HTTP ' + $status + '|' + $body)
    } else {
      return ('ERR|QUERY|Exception: ' + $errMsg)
    }
  }
}

$body1 = (@{ filter = @{ property = 'ID'; unique_id = @{ equals = %d } } } | ConvertTo-Json -Depth 10)
$v = Get-FileNameFormula $body1
if (-not $v) {
  $body2 = (@{ filter = @{ property = 'ID'; number = @{ equals = %d } } } | ConvertTo-Json -Depth 10)
  $v = Get-FileNameFormula $body2
}
if ($v -and -not $v.ToString().StartsWith('ERR|')) { Write-Output $v }
]], token_ps, ver_ps, ds_ps, id_num, id_num)

    local out, exit_code = runPowerShellHidden(ps, 60000)
    out = trimWS(out)
    if out == "" then return nil end
    
    -- Check if output contains an error (starts with ERR|)
    if out:match("^ERR|") then
        -- Log first error to REAPER console for debugging
        reaper.ShowConsoleMsg("Notion query error for ID=" .. tostring(id_num) .. ": " .. out .. "\n")
        return nil
    end

    NOTION_CACHE_BY_ID[id_num] = NOTION_CACHE_BY_ID[id_num] or {}
    NOTION_CACHE_BY_ID[id_num].filename = out
    return out
end

-- Backwards-compat alias (older UI/button code paths)
local function notionGetFileNameFormulaFromSheetsByID(notion_token, id_num)
    return notionGetFileNameFormulaByID(notion_token, id_num)
end

-- Cache for entry name -> ID lookups
local NOTION_CACHE_BY_ENTRY = {}

-- Look up Notion ID by entry name (title property "Entries")
-- Returns: numeric ID or nil, error message
local function notionGetIDByEntryName(notion_token, entry_name)
    notion_token = trimWS(notion_token)
    entry_name = trimWS(entry_name or "")
    if notion_token == "" or entry_name == "" then return nil, "Empty token or entry name" end
    
    -- Check cache first
    if NOTION_CACHE_BY_ENTRY[entry_name] then
        return NOTION_CACHE_BY_ENTRY[entry_name], nil
    end
    
    local osname = reaper.GetOS() or ""
    if not osname:match("Win") then
        return nil, "Notion lookup requires Windows (PowerShell)"
    end
    
    local db_id = getNotionDwarfShoutsDbId()
    if not isValidNotionId(db_id) then
        return nil, "Notion DB ID not set"
    end
    
    -- Get the data source ID (same pattern as notionGetFileNameFormulaByID which works)
    local dsid, ds_err = notionGetDataSourceId(notion_token, db_id)
    if not dsid then
        return nil, "Data source lookup failed: " .. tostring(ds_err or "")
    end
    
    local token_ps = psEscapeSingleQuoted(notion_token)
    local ds_ps = psEscapeSingleQuoted(dsid)
    local ver_ps = psEscapeSingleQuoted(NOTION_API_VERSION)
    
    -- Build JSON filter manually to avoid PowerShell escaping issues
    -- Escape for JSON: backslash and double-quote
    local entry_json = entry_name:gsub("\\", "\\\\"):gsub('"', '\\"')
    -- Escape for embedding inside PowerShell single-quoted string: ' -> '' (apostrophe in "Isn't" etc. would break $body1 = '...')
    local entry_json_ps = entry_json:gsub("'", "''")
    local entry_ps = psEscapeSingleQuoted(entry_name)
    
    local ps = string.format([[
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$p = @{
  Authorization = 'Bearer %s'
  'Notion-Version' = '%s'
  'Content-Type' = 'application/json'
}

function Get-IDByEntry([string]$bodyJson, [string]$expectedEntry) {
  try {
    $resp = Invoke-RestMethod -Method Post -Uri ('https://api.notion.com/v1/data_sources/%s/query') -Headers $p -Body $bodyJson -ContentType 'application/json'
    if (-not $resp) { return 'ERR|QUERY|No response' }
    if (-not $resp.results) { return 'ERR|QUERY|No results array' }
    if ($resp.results.Count -lt 1) { return 'ERR|NO_MATCH|Results array empty' }
    
    $expectedTrim = ($expectedEntry -replace '^\\s+|\\s+$', '')
    
    foreach ($row in $resp.results) {
      $props = $null
      try { $props = $row.properties } catch {}
      if (-not $props) { try { $props = $row.PSObject.Properties['properties'].Value } catch {} }
      if (-not $props) { continue }
      
      $entriesVal = ''
      try {
        $entriesProp = $props.'Entries'
        if ($entriesProp -and $entriesProp.title -and $entriesProp.title.Count -gt 0) {
          $entriesVal = $entriesProp.title[0].plain_text
        }
      } catch {}
      $entriesTrim = ($entriesVal -replace '^\\s+|\\s+$', '')
      if ($entriesTrim -ne $expectedTrim) { continue }
      
      $idProp = $null
      try { $idProp = $props.'ID' } catch { $idProp = $null }
      if (-not $idProp) { try { $idProp = $props.PSObject.Properties['ID'].Value } catch { $idProp = $null } }
      if (-not $idProp) { continue }
      
      $idVal = $null
      try { if ($idProp.unique_id) { $idVal = [int]$idProp.unique_id.number } } catch {}
      if (-not $idVal -or $idVal -eq 0) { try { $idVal = [int]$idProp.number } catch {} }
      if (-not $idVal -or $idVal -eq 0) { try { $idVal = [int]$idProp['unique_id']['number'] } catch {} }
      
      if ($idVal -and $idVal -gt 0) { return $idVal.ToString() }
    }
    
    return 'ERR|NO_MATCH|No row with matching Entries title'
  } catch {
    $errMsg = $_.Exception.Message
    return ('ERR|EXCEPTION|' + $errMsg)
  }
}

$body1 = '{"filter":{"property":"Entries","title":{"equals":"%s"}}}'
$v = Get-IDByEntry $body1 '%s'

Write-Output $v
]], token_ps, ver_ps, ds_ps, entry_json_ps, entry_ps)
    
    local out, exit_code = runPowerShellHidden(ps, 60000)
    out = trimWS(out)
    
    if out == "" then return nil, "Empty response from Notion" end
    
    -- Check for error in any line
    if out:match("ERR|") then
        return nil, out
    end
    
    -- Handle multiline output - find the last numeric value
    -- (PowerShell may output extra lines before the actual result)
    local id_num = nil
    for line in out:gmatch("[^\r\n]+") do
        local trimmed = trimWS(line)
        local num = tonumber(trimmed)
        if num and num > 0 then
            id_num = num
        end
    end
    
    if id_num then
        -- Sanity check: if ID is suspiciously low (1-10), it's likely wrong
        -- Real IDs in this database are in the thousands
        if id_num <= 10 then
            return nil, "Suspicious low ID (" .. tostring(id_num) .. ") - likely wrong match"
        end
        NOTION_CACHE_BY_ENTRY[entry_name] = id_num
        return id_num, nil
    end
    
    return nil, "Invalid ID returned: " .. tostring(out)
end

-- Non-blocking fetch: start background PowerShell, return response path for polling.
-- Returns: response_path (string), or nil, error. Caller polls with notionFetchAllEntriesToIdMapPoll.
local function notionFetchAllEntriesToIdMapAsync(notion_token)
    notion_token = trimWS(notion_token or "")
    if notion_token == "" then return nil, "Empty token" end
    local osname = reaper.GetOS() or ""
    if not osname:match("Win") then return nil, "Requires Windows" end
    local db_id = getNotionDwarfShoutsDbId()
    if not isValidNotionId(db_id) then return nil, "Notion DB ID not set" end

    local tmp_dir = joinPath(reaper.GetResourcePath(), "Scripts", "DMN_Temp")
    ensureDir(tmp_dir)
    local req_path = joinPath(tmp_dir, "DMN_NotionFetchRequest.txt")
    local res_path = joinPath(tmp_dir, "DMN_NotionFetchResponse.txt")
    local script_path = joinPath(tmp_dir, "DMN_NotionFetchBatch.ps1")

    local req_content = notion_token .. "\n" .. db_id .. "\n" .. (NOTION_API_VERSION or "2022-06-28")
    if not writeAll(req_path, req_content) then return nil, "Could not write request file" end

    local ps_script = [[
param($ReqPath, $ResPath)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
  $lines = Get-Content $ReqPath -ErrorAction Stop
  $token = $lines[0].Trim(); $dbId = $lines[1].Trim(); $ver = if ($lines.Count -gt 2) { $lines[2].Trim() } else { "2022-06-28" }
  $h = @{ Authorization = "Bearer $token"; 'Notion-Version' = $ver }
  $db = Invoke-RestMethod -Method Get -Uri ("https://api.notion.com/v1/databases/" + $dbId) -Headers $h
  $dsid = $db.data_sources[0].id
  $p = @{ Authorization = "Bearer $token"; 'Notion-Version' = $ver; 'Content-Type' = 'application/json' }
  $uri = "https://api.notion.com/v1/data_sources/$dsid/query"
  $cursor = $null; $pageSize = 100
  do {
    $bodyObj = @{ page_size = $pageSize }; if ($cursor) { $bodyObj.start_cursor = $cursor }
    $body = $bodyObj | ConvertTo-Json -Compress
    $resp = Invoke-RestMethod -Method Post -Uri $uri -Headers $p -Body $body -ContentType 'application/json'
    if (-not $resp -or -not $resp.results) { break }
    foreach ($row in $resp.results) {
      $props = $null; try { $props = $row.properties } catch {}
      if (-not $props) { try { $props = $row.PSObject.Properties['properties'].Value } catch {} }
      if (-not $props) { continue }
      $entriesVal = ''; try { $ep = $props.'Entries'; if ($ep -and $ep.title -and $ep.title.Count -gt 0) { $entriesVal = $ep.title[0].plain_text } } catch {}
      $entriesTrim = ($entriesVal -replace '^\s+|\s+$','').Replace("`t"," ").Replace("`r"," ").Replace("`n"," ")
      $idVal = $null; try { $idProp = $props.'ID'; if ($idProp.unique_id) { $idVal = [int]$idProp.unique_id.number } } catch {}
      if (-not $idVal -or $idVal -eq 0) { try { $idVal = [int]$idProp.number } catch {} }; if (-not $idVal -or $idVal -eq 0) { try { $idVal = [int]$idProp['unique_id']['number'] } catch {} }
      if ($idVal -and $idVal -gt 0 -and $entriesTrim -ne '') { Add-Content -Path $ResPath -Value ('ENTRY' + [char]9 + $idVal + [char]9 + $entriesTrim) }
    }
    $hasMore = $false; try { $hasMore = $resp.has_more } catch {}; $cursor = $null; try { $cursor = $resp.next_cursor } catch {}
    if (-not $hasMore -or -not $cursor) { break }
  } while ($true)
  Add-Content -Path $ResPath -Value 'DONE'
} catch { Add-Content -Path $ResPath -Value ('ERR|' + $_.Exception.Message) }
]]

    if not writeAll(script_path, ps_script) then return nil, "Could not write script file" end
    pcall(os.remove, res_path)

    local cmd = 'start /B powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. script_path:gsub('"', '\\"') .. '" "' .. req_path:gsub('"', '\\"') .. '" "' .. res_path:gsub('"', '\\"') .. '"'
    os.execute(cmd)
    return res_path, nil
end

-- Poll response file from background fetch. Returns: map, nil when done; nil, "pending" when still running; nil, err on error.
local function notionFetchAllEntriesToIdMapPoll(response_path)
    local f = io.open(response_path, "r")
    if not f then return nil, "pending" end
    local content = f:read("*all")
    f:close()
    if not content or content == "" then return nil, "pending" end
    if content:match("ERR|") then
        for line in content:gmatch("[^\r\n]+") do
            if line:sub(1, 4) == "ERR|" then return nil, line:sub(5) end
        end
        return nil, "Unknown error"
    end
    if not content:match("DONE") then return nil, "pending" end
    local map = {}
    for line in content:gmatch("[^\r\n]+") do
        line = trimWS(line)
        if line == "DONE" then break end
        if line:sub(1, 5) == "ENTRY" and line:sub(6, 6) == "\t" then
            local rest = line:sub(7)
            local id_str, text = rest:match("^([^\t]+)\t(.*)$")
            if id_str and text then
                local id_num = tonumber(id_str)
                if id_num and id_num > 10 then
                    text = trimWS(text)
                    text = normalizeSmartChars(text)
                    if text ~= "" then
                        map[text] = id_num
                        NOTION_CACHE_BY_ENTRY[text] = id_num
                    end
                end
            end
        end
    end
    if next(map) then return map, nil end
    return nil, "No entries returned from Notion"
end

-- Fetch all Entries -> ID from Notion in one (or few) paginated request(s). Much faster than N lookups.
-- Returns: map [entry_text_trimmed] = id_num, or nil, error
local function notionFetchAllEntriesToIdMap(notion_token)
    notion_token = trimWS(notion_token or "")
    if notion_token == "" then return nil, "Empty token" end
    local osname = reaper.GetOS() or ""
    if not osname:match("Win") then return nil, "Notion batch fetch requires Windows (PowerShell)" end
    local db_id = getNotionDwarfShoutsDbId()
    if not isValidNotionId(db_id) then return nil, "Notion DB ID not set" end
    local dsid, ds_err = notionGetDataSourceId(notion_token, db_id)
    if not dsid then return nil, "Data source lookup failed: " .. tostring(ds_err or "") end

    local token_ps = psEscapeSingleQuoted(notion_token)
    local ds_ps = psEscapeSingleQuoted(dsid)
    local ver_ps = psEscapeSingleQuoted(NOTION_API_VERSION)
    local ps = string.format([[
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$p = @{ Authorization = 'Bearer %s'; 'Notion-Version' = '%s'; 'Content-Type' = 'application/json' }
$uri = 'https://api.notion.com/v1/data_sources/%s/query'
$cursor = $null
$pageSize = 100
do {
  $bodyObj = @{ page_size = $pageSize }
  if ($cursor) { $bodyObj.start_cursor = $cursor }
  $body = $bodyObj | ConvertTo-Json -Compress
  $resp = Invoke-RestMethod -Method Post -Uri $uri -Headers $p -Body $body -ContentType 'application/json'
  if (-not $resp -or -not $resp.results) { break }
  foreach ($row in $resp.results) {
    $props = $null
    try { $props = $row.properties } catch {}
    if (-not $props) { try { $props = $row.PSObject.Properties['properties'].Value } catch {} }
    if (-not $props) { continue }
    $entriesVal = ''
    try {
      $ep = $props.'Entries'
      if ($ep -and $ep.title -and $ep.title.Count -gt 0) { $entriesVal = $ep.title[0].plain_text }
    } catch {}
    $entriesTrim = ($entriesVal -replace '^\\s+|\\s+$', '').Replace("`t"," ").Replace("`r"," ").Replace("`n"," ")
    $idVal = $null
    try { $idProp = $props.'ID'; if ($idProp.unique_id) { $idVal = [int]$idProp.unique_id.number } } catch {}
    if (-not $idVal -or $idVal -eq 0) { try { $idVal = [int]$idProp.number } catch {} }
    if (-not $idVal -or $idVal -eq 0) { try { $idVal = [int]$idProp['unique_id']['number'] } catch {} }
    if ($idVal -and $idVal -gt 0 -and $entriesTrim -ne '') { Write-Output ('ENTRY' + [char]9 + $idVal + [char]9 + $entriesTrim) }
  }
  $hasMore = $false; try { $hasMore = $resp.has_more } catch {}
  $cursor = $null; try { $cursor = $resp.next_cursor } catch {}
  if (-not $hasMore -or -not $cursor) { break }
} while ($true)
Write-Output 'DONE'
]], token_ps, ver_ps, ds_ps)

    local out, exit_code = runPowerShellHidden(ps, 120000)
    out = tostring(out or "")
    local map = {}
    for line in out:gmatch("[^\r\n]+") do
        line = trimWS(line)
        if line == "DONE" then break end
        if line:sub(1, 5) == "ENTRY" and line:sub(6, 6) == "\t" then
            local rest = line:sub(7)
            local id_str, text = rest:match("^([^\t]+)\t(.*)$")
            if id_str and text then
                local id_num = tonumber(id_str)
                if id_num and id_num > 10 then
                    text = trimWS(text)
                    text = normalizeSmartChars(text)
                    if text ~= "" then
                        map[text] = id_num
                        NOTION_CACHE_BY_ENTRY[text] = id_num
                    end
                end
            end
        end
    end
    if next(map) then return map, nil end
    if out:match("ERR|") then return nil, out end
    return nil, "No entries returned from Notion"
end

-- Simple function to write text to "ReaperSession" property
-- Returns: success (bool), error message (string or nil)
local function notionSetReaperSessionByID(notion_token, id_num, text_value)
    notion_token = trimWS(notion_token)
    id_num = tonumber(id_num)
    text_value = tostring(text_value or "REAPER")
    if notion_token == "" or not id_num then return false, "Invalid token or ID" end

    local osname = reaper.GetOS() or ""
    if not osname:match("Win") then
        return false, "Requires Windows (PowerShell)"
    end

    local db_id = getNotionDwarfShoutsDbId()
    if not isValidNotionId(db_id) then
        return false, "Notion DB ID not set"
    end

    local dsid, ds_err = notionGetDataSourceId(notion_token, db_id)
    if not dsid then
        return false, "Data source lookup failed: " .. tostring(ds_err or "")
    end

    local token_ps = psEscapeSingleQuoted(notion_token)
    local ds_ps = psEscapeSingleQuoted(dsid)
    local ver_ps = psEscapeSingleQuoted(NOTION_API_VERSION)
    local text_ps = psEscapeSingleQuoted(text_value)

    local ps = string.format([[
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$h = @{
  Authorization = 'Bearer %s'
  'Notion-Version' = '%s'
  'Content-Type' = 'application/json'
}

$TextValue = '%s'

# Query for the page by ID
$body = '{"filter":{"property":"ID","unique_id":{"equals":%d}}}'
try {
  $resp = Invoke-RestMethod -Method Post -Uri 'https://api.notion.com/v1/data_sources/%s/query' -Headers $h -Body $body -ContentType 'application/json'
} catch {
  Write-Output ('ERR|QUERY|' + $_.Exception.Message)
  exit 1
}

if (-not $resp.results -or $resp.results.Count -lt 1) {
  Write-Output 'ERR|NOT_FOUND|No page found with that ID'
  exit 1
}

$pageId = $resp.results[0].id
if (-not $pageId) {
  Write-Output 'ERR|NO_PAGE_ID|Could not get page ID'
  exit 1
}

# Update the "Recorded in ReaperSession" text property
$updateBody = @{
  properties = @{
    'ReaperSession' = @{
      rich_text = @(
        @{
          type = 'text'
          text = @{ content = $TextValue }
        }
      )
    }
  }
} | ConvertTo-Json -Depth 10

try {
  $updateResp = Invoke-RestMethod -Method Patch -Uri ('https://api.notion.com/v1/pages/' + $pageId) -Headers $h -Body $updateBody -ContentType 'application/json'
  Write-Output 'OK'
} catch {
  $errMsg = $_.Exception.Message
  try {
    if ($_.Exception.Response) {
      $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $errBody = $sr.ReadToEnd(); $sr.Close()
      $errMsg = $errMsg + ' | ' + $errBody
    }
  } catch {}
  Write-Output ('ERR|UPDATE|' + $errMsg)
}
]], token_ps, ver_ps, text_ps, id_num, ds_ps)

    local out, exit_code = runPowerShellHidden(ps, 60000)
    out = trimWS(out)

    -- Handle multiline output - check each line
    for line in out:gmatch("[^\r\n]+") do
        local trimmed = trimWS(line)
        if trimmed == "OK" then
            return true, nil
        elseif trimmed:match("^ERR|") then
            return false, trimmed
        end
    end
    
    -- If we got here, check if "OK" appears anywhere
    if out:match("OK") then
        return true, nil
    end
    
    return false, "Unexpected response: " .. tostring(out)
end

-- Helper: Detect actor key (M or F) from status field name
-- Returns "M" for male, "F" for female, nil if unknown
local function detectActorFromStatusField(status_field)
    if not status_field or status_field == "" then return nil end
    local lower = status_field:lower()
    if lower:match("fem") or lower:match("female") then
        return "F"
    elseif lower:match("male") then
        return "M"
    end
    return nil
end

-- Helper: Parse combined ReaperSession format (e.g. "M=Session1, F=Session2")
-- Returns table { M = "...", F = "..." }
local function parseReaperSessions(text)
    local result = { M = nil, F = nil }
    if not text or text == "" then return result end
    
    -- Try to parse "M=..., F=..." format
    local m_val = text:match("[Mm]%s*=%s*([^,]+)")
    local f_val = text:match("[Ff]%s*=%s*([^,]+)")
    
    if m_val then result.M = trimWS(m_val) end
    if f_val then result.F = trimWS(f_val) end
    
    -- If neither M= nor F= found, treat entire text as legacy single value
    if not result.M and not result.F and text ~= "" then
        result.legacy = trimWS(text)
    end
    
    return result
end

-- Helper: Build combined ReaperSession string from table
local function buildReaperSessions(sessions)
    local parts = {}
    if sessions.M and sessions.M ~= "" then
        table.insert(parts, "M=" .. sessions.M)
    end
    if sessions.F and sessions.F ~= "" then
        table.insert(parts, "F=" .. sessions.F)
    end
    return table.concat(parts, ", ")
end

-- Multi-actor version: Read existing ReaperSession, merge M= or F= part, write back
-- actor_key: "M" or "F" (detected from status field if not provided)
-- status_field: used to detect actor_key if not explicitly provided
-- Returns: success (bool), error message (string or nil)
local function notionSetReaperSessionMultiActor(notion_token, id_num, proj_name, actor_key, status_field)
    notion_token = trimWS(notion_token)
    id_num = tonumber(id_num)
    proj_name = tostring(proj_name or "REAPER")
    
    -- Detect actor from status field if not provided
    if not actor_key and status_field then
        actor_key = detectActorFromStatusField(status_field)
    end
    
    -- Fall back to simple write if we can't determine actor
    if not actor_key then
        return notionSetReaperSessionByID(notion_token, id_num, proj_name)
    end
    
    if notion_token == "" or not id_num then return false, "Invalid token or ID" end

    local osname = reaper.GetOS() or ""
    if not osname:match("Win") then
        return false, "Requires Windows (PowerShell)"
    end

    local db_id = getNotionDwarfShoutsDbId()
    if not isValidNotionId(db_id) then
        return false, "Notion DB ID not set"
    end

    local dsid, ds_err = notionGetDataSourceId(notion_token, db_id)
    if not dsid then
        return false, "Data source lookup failed: " .. tostring(ds_err or "")
    end

    local token_ps = psEscapeSingleQuoted(notion_token)
    local ds_ps = psEscapeSingleQuoted(dsid)
    local ver_ps = psEscapeSingleQuoted(NOTION_API_VERSION)
    local proj_ps = psEscapeSingleQuoted(proj_name)
    local actor_ps = psEscapeSingleQuoted(actor_key)

    -- PowerShell script that reads existing value, merges, and writes back
    local ps = string.format([[
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$h = @{
  Authorization = 'Bearer %s'
  'Notion-Version' = '%s'
  'Content-Type' = 'application/json'
}

$ProjName = '%s'
$ActorKey = '%s'

# Query for the page by ID
$body = '{"filter":{"property":"ID","unique_id":{"equals":%d}}}'
try {
  $resp = Invoke-RestMethod -Method Post -Uri 'https://api.notion.com/v1/data_sources/%s/query' -Headers $h -Body $body -ContentType 'application/json'
} catch {
  Write-Output ('ERR|QUERY|' + $_.Exception.Message)
  exit 1
}

if (-not $resp.results -or $resp.results.Count -lt 1) {
  Write-Output 'ERR|NOT_FOUND|No page found with that ID'
  exit 1
}

$pageId = $resp.results[0].id
if (-not $pageId) {
  Write-Output 'ERR|NO_PAGE_ID|Could not get page ID'
  exit 1
}

# Read current ReaperSession value
$currentValue = ""
try {
  $props = $resp.results[0].properties
  if ($props.'ReaperSession' -and $props.'ReaperSession'.rich_text -and $props.'ReaperSession'.rich_text.Count -gt 0) {
    $currentValue = $props.'ReaperSession'.rich_text[0].plain_text
  }
} catch {}

# Parse existing M= and F= values
$mVal = ""
$fVal = ""
$hasFormatted = $false

if ($currentValue -match '[Mm]\s*=\s*([^,]+)') {
  $mVal = $Matches[1].Trim()
  $hasFormatted = $true
}
if ($currentValue -match '[Ff]\s*=\s*([^,]+)') {
  $fVal = $Matches[1].Trim()
  $hasFormatted = $true
}

# If no M=/F= format found but there's a value, try to preserve it
# by detecting if it looks like a Male or Female session name
if (-not $hasFormatted -and $currentValue -ne "") {
  $lowerVal = $currentValue.ToLower()
  if ($lowerVal -match 'female' -or $lowerVal -match '_f_' -or $lowerVal -match 'fem') {
    $fVal = $currentValue.Trim()
  } elseif ($lowerVal -match 'male' -or $lowerVal -match '_m_') {
    $mVal = $currentValue.Trim()
  }
  # If can't detect, leave as is - will be preserved as the current actor's slot
}

# Update the relevant actor
if ($ActorKey -eq 'M') {
  $mVal = $ProjName
} elseif ($ActorKey -eq 'F') {
  $fVal = $ProjName
}

# Build combined string
$parts = @()
if ($mVal -ne "") { $parts += "M=$mVal" }
if ($fVal -ne "") { $parts += "F=$fVal" }
$newValue = $parts -join ", "

# Update the property
$updateBody = @{
  properties = @{
    'ReaperSession' = @{
      rich_text = @(
        @{
          type = 'text'
          text = @{ content = $newValue }
        }
      )
    }
  }
} | ConvertTo-Json -Depth 10

try {
  $updateResp = Invoke-RestMethod -Method Patch -Uri ('https://api.notion.com/v1/pages/' + $pageId) -Headers $h -Body $updateBody -ContentType 'application/json'
  Write-Output 'OK'
} catch {
  $errMsg = $_.Exception.Message
  try {
    if ($_.Exception.Response) {
      $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $errBody = $sr.ReadToEnd(); $sr.Close()
      $errMsg = $errMsg + ' | ' + $errBody
    }
  } catch {}
  Write-Output ('ERR|UPDATE|' + $errMsg)
}
]], token_ps, ver_ps, proj_ps, actor_ps, id_num, ds_ps)

    local out, exit_code = runPowerShellHidden(ps, 60000)
    out = trimWS(out)

    -- Handle multiline output - check each line
    for line in out:gmatch("[^\r\n]+") do
        local trimmed = trimWS(line)
        if trimmed == "OK" then
            return true, nil
        elseif trimmed:match("^ERR|") then
            return false, trimmed
        end
    end
    
    -- If we got here, check if "OK" appears anywhere
    if out:match("OK") then
        return true, nil
    end
    
    return false, "Unexpected response: " .. tostring(out)
end

-- Simple function to update a status property by ID
-- Returns: success (bool), error message (string or nil), changed (bool)
local function notionSetStatusByID(notion_token, id_num, status_field, status_option)
    notion_token = trimWS(notion_token)
    id_num = tonumber(id_num)
    status_field = tostring(status_field or "")
    status_option = tostring(status_option or "")
    if notion_token == "" or not id_num or status_field == "" or status_option == "" then 
        return false, "Invalid parameters" 
    end

    local osname = reaper.GetOS() or ""
    if not osname:match("Win") then
        return false, "Requires Windows (PowerShell)"
    end

    local db_id = getNotionDwarfShoutsDbId()
    if not isValidNotionId(db_id) then
        return false, "Notion DB ID not set"
    end

    local dsid, ds_err = notionGetDataSourceId(notion_token, db_id)
    if not dsid then
        return false, "Data source lookup failed: " .. tostring(ds_err or "")
    end

    local token_ps = psEscapeSingleQuoted(notion_token)
    local ds_ps = psEscapeSingleQuoted(dsid)
    local ver_ps = psEscapeSingleQuoted(NOTION_API_VERSION)
    local field_ps = psEscapeSingleQuoted(status_field)
    local option_ps = psEscapeSingleQuoted(status_option)

    local ps = string.format([[
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$h = @{
  Authorization = 'Bearer %s'
  'Notion-Version' = '%s'
  'Content-Type' = 'application/json'
}

$Field = '%s'
$Option = '%s'

# Query for the page by ID
$body = '{"filter":{"property":"ID","unique_id":{"equals":%d}}}'
try {
  $resp = Invoke-RestMethod -Method Post -Uri 'https://api.notion.com/v1/data_sources/%s/query' -Headers $h -Body $body -ContentType 'application/json'
} catch {
  Write-Output ('ERR|QUERY|' + $_.Exception.Message)
  exit 1
}

if (-not $resp.results -or $resp.results.Count -lt 1) {
  Write-Output 'ERR|NOT_FOUND|No page found with that ID'
  exit 1
}

$pageId = $resp.results[0].id
if (-not $pageId) {
  Write-Output 'ERR|NO_PAGE_ID|Could not get page ID'
  exit 1
}

# Check current status
$currentStatus = $null
try {
  $props = $resp.results[0].properties
  if ($props.$Field -and $props.$Field.status -and $props.$Field.status.name) {
    $currentStatus = $props.$Field.status.name
  }
} catch {}

# If already set to desired option, skip
if ($currentStatus -and $currentStatus -eq $Option) {
  Write-Output 'ALREADY'
  exit 0
}

# Update the status property
$updateBody = @{
  properties = @{
    $Field = @{
      status = @{ name = $Option }
    }
  }
} | ConvertTo-Json -Depth 10

try {
  $updateResp = Invoke-RestMethod -Method Patch -Uri ('https://api.notion.com/v1/pages/' + $pageId) -Headers $h -Body $updateBody -ContentType 'application/json'
  Write-Output 'OK'
} catch {
  $errMsg = $_.Exception.Message
  try {
    if ($_.Exception.Response) {
      $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $errBody = $sr.ReadToEnd(); $sr.Close()
      $errMsg = $errMsg + ' | ' + $errBody
    }
  } catch {}
  Write-Output ('ERR|UPDATE|' + $errMsg)
}
]], token_ps, ver_ps, field_ps, option_ps, id_num, ds_ps)

    local out, exit_code = runPowerShellHidden(ps, 60000)
    out = trimWS(out)

    -- Handle multiline output
    for line in out:gmatch("[^\r\n]+") do
        local trimmed = trimWS(line)
        if trimmed == "OK" then
            return true, nil, true  -- success, no error, changed
        elseif trimmed == "ALREADY" then
            return true, nil, false  -- success, no error, not changed (already set)
        elseif trimmed:match("^ERR|") then
            return false, trimmed, false
        end
    end
    
    if out:match("OK") then
        return true, nil, true
    elseif out:match("ALREADY") then
        return true, nil, false
    end
    
    return false, "Unexpected response: " .. tostring(out), false
end

-- Clean Up batch: run all Notion updates in background. Returns response_path or nil, err.
-- do_status, do_reaper: true/false to update status property and/or ReaperSession
local function notionCleanUpBatchAsync(tok, db_id, do_status, do_reaper, voice_field, target_opt, proj_name, id_list)
    if not id_list or #id_list == 0 then return nil, "No IDs to update" end
    local tmp_dir = joinPath(reaper.GetResourcePath(), "Scripts", "DMN_Temp")
    ensureDir(tmp_dir)
    local req_path = joinPath(tmp_dir, "DMN_CleanUpRequest.txt")
    local res_path = joinPath(tmp_dir, "DMN_CleanUpResponse.txt")
    local script_path = joinPath(tmp_dir, "DMN_CleanUpBatch.ps1")
    local actor_key = (voice_field and voice_field:lower():match("fem")) and "F" or "M"
    local lines = { tok, db_id, NOTION_API_VERSION or "2022-06-28", do_status and "1" or "0", do_reaper and "1" or "0", voice_field or "", target_opt or "", proj_name or "REAPER", actor_key }
    for _, id_num in ipairs(id_list) do
        lines[#lines + 1] = tostring(id_num)
    end
    if not writeAll(req_path, table.concat(lines, "\n")) then return nil, "Could not write request file" end
    pcall(os.remove, res_path)

    local ps_script = [[
param($ReqPath, $ResPath)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$lines = Get-Content $ReqPath
$token = $lines[0].Trim(); $dbId = $lines[1].Trim(); $ver = $lines[2].Trim(); $doStatus = $lines[3].Trim(); $doReaper = $lines[4].Trim(); $voiceField = $lines[5].Trim(); $targetOpt = $lines[6].Trim(); $projName = $lines[7].Trim(); $actorKey = $lines[8].Trim()
$ids = @(); for ($i=9; $i -lt $lines.Count; $i++) { $n = $lines[$i].Trim(); if ($n -match '^\d+$') { $ids += [int]$n } }
$h = @{ Authorization = "Bearer $token"; 'Notion-Version' = $ver; 'Content-Type' = 'application/json' }
try { $db = Invoke-RestMethod -Method Get -Uri ("https://api.notion.com/v1/databases/"+$dbId) -Headers $h; $dsid = $db.data_sources[0].id } catch { Add-Content $ResPath ("ERR|"+$_.Exception.Message); exit 1 }
$uriQuery = "https://api.notion.com/v1/data_sources/$dsid/query"
$updated = 0; $already = 0; $failed = 0; $firstErr = $null
foreach ($idNum in $ids) {
  $statusResult = "OK"; $reaperResult = "OK"
  try {
    $body = '{"filter":{"property":"ID","unique_id":{"equals":'+$idNum+'}}}'
    $resp = Invoke-RestMethod -Method Post -Uri $uriQuery -Headers $h -Body $body -ContentType 'application/json'
    if (-not $resp.results -or $resp.results.Count -lt 1) { $statusResult = "ERR|Not found"; $failed++; if (-not $firstErr) { $firstErr = "ID $idNum not found" }; Add-Content $ResPath ("ROW|"+$idNum+"|"+$statusResult+"|"+$reaperResult); continue }
    $pageId = $resp.results[0].id; $props = $resp.results[0].properties
    if ($doStatus -eq '1' -and $voiceField -ne '' -and $targetOpt -ne '') {
      $propType = 'status'
      try { if ($props.$voiceField -and $props.$voiceField.type) { $propType = [string]$props.$voiceField.type } } catch {}
      $cur = $null
      try { if ($propType -eq 'select' -and $props.$voiceField.select) { $cur = $props.$voiceField.select.name } elseif ($props.$voiceField.status) { $cur = $props.$voiceField.status.name } } catch {}
      if ($cur -eq $targetOpt) { $statusResult = "ALREADY"; $already++ } else {
        $patchProp = @{}; if ($propType -eq 'select') { $patchProp = @{ select = @{ name = $targetOpt } } } else { $patchProp = @{ status = @{ name = $targetOpt } } }
        $patchBody = @{ properties = @{ $voiceField = $patchProp } } | ConvertTo-Json -Depth 10
        try { Invoke-RestMethod -Method Patch -Uri ("https://api.notion.com/v1/pages/"+$pageId) -Headers $h -Body $patchBody -ContentType 'application/json' | Out-Null; $updated++ } catch { $statusResult = "ERR|"+$_.Exception.Message; $failed++; if (-not $firstErr) { $firstErr = $_.Exception.Message } }
      }
    }
    if ($doReaper -eq '1') {
      $currentValue = ""; try { if ($props.'ReaperSession' -and $props.'ReaperSession'.rich_text -and $props.'ReaperSession'.rich_text.Count -gt 0) { $currentValue = $props.'ReaperSession'.rich_text[0].plain_text } } catch {}
      $mVal = ""; $fVal = ""; if ($currentValue -match 'M\s*=\s*([^,]+)') { $mVal = $Matches[1].Trim() }; if ($currentValue -match 'F\s*=\s*([^,]+)') { $fVal = $Matches[1].Trim() }
      if ($actorKey -eq 'M') { $mVal = $projName } else { $fVal = $projName }; $parts = @(); if ($mVal -ne "") { $parts += "M=$mVal" }; if ($fVal -ne "") { $parts += "F=$fVal" }; $newValue = $parts -join ", "
      $updateBody = @{ properties = @{ 'ReaperSession' = @{ rich_text = @( @{ type = 'text'; text = @{ content = $newValue } } ) } } } | ConvertTo-Json -Depth 10
      try { Invoke-RestMethod -Method Patch -Uri ("https://api.notion.com/v1/pages/"+$pageId) -Headers $h -Body $updateBody -ContentType 'application/json' | Out-Null } catch { $reaperResult = "ERR|"+$_.Exception.Message; $failed++; if (-not $firstErr) { $firstErr = $_.Exception.Message } }
    }
  } catch { $statusResult = "ERR|"+$_.Exception.Message; $failed++; if (-not $firstErr) { $firstErr = $_.Exception.Message } }
  Add-Content $ResPath ("ROW|"+$idNum+"|"+$statusResult+"|"+$reaperResult)
}
Add-Content $ResPath ("DONE|"+$updated+"|"+$already+"|"+$failed); if ($firstErr) { Add-Content $ResPath ("FIRST_ERR|"+$firstErr) }
]]
    if not writeAll(script_path, ps_script) then return nil, "Could not write script" end
    local cmd = 'start /B powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. script_path:gsub('"', '\\"') .. '" "' .. req_path:gsub('"', '\\"') .. '" "' .. res_path:gsub('"', '\\"') .. '"'
    os.execute(cmd)
    return res_path, nil
end

-- Poll Clean Up batch response. Returns: updated, already_set, failed, first_err when DONE; or nil, "pending"
local function notionCleanUpBatchPoll(response_path)
    local f = io.open(response_path, "r")
    if not f then return nil, "pending" end
    local content = f:read("*all")
    f:close()
    if not content or content == "" then return nil, "pending" end
    if content:match("ERR|") and not content:match("ROW|") then
        for line in content:gmatch("[^\r\n]+") do
            if line:sub(1, 4) == "ERR|" then return nil, nil, nil, line:sub(5) end
        end
    end
    if not content:match("DONE|") then return nil, "pending" end
    local updated, already_set, failed, first_err = 0, 0, 0, nil
    for line in content:gmatch("[^\r\n]+") do
        if line:sub(1, 5) == "DONE|" then
            local u, a, f = line:match("DONE|(%d+)|(%d+)|(%d+)")
            if u then updated = tonumber(u) or 0 end
            if a then already_set = tonumber(a) or 0 end
            if f then failed = tonumber(f) or 0 end
        elseif line:sub(1, 9) == "FIRST_ERR|" then
            first_err = line:sub(10)
        end
    end
    return updated, already_set, failed, first_err
end

local function notionSetVoiceStatusRecordedByID(notion_token, id_num, voice_field, desired_option, desired_option_id)
    notion_token = trimWS(notion_token)
    id_num = tonumber(id_num)
    voice_field = tostring(voice_field or "")
    if notion_token == "" or not id_num then return false end

    local option_candidates = nil
    desired_option = trimWS(desired_option or "")
    desired_option_id = trimWS(desired_option_id or "")
    
    -- Try to get option ID from cached schema if not provided
    if desired_option_id == "" and desired_option ~= "" then
        local db_id = getNotionDwarfShoutsDbId()
        local schema = NOTION_STATUS_SCHEMA_BY_DB[db_id]
        if schema and schema.status_props and schema.status_props[voice_field] then
            local prop_info = schema.status_props[voice_field]
            if prop_info.options_by_name and prop_info.options_by_name[desired_option] then
                desired_option_id = prop_info.options_by_name[desired_option].id or ""
            end
        end
    end
    
    if desired_option ~= "" then
        -- Use the user-selected target option.
        option_candidates = { desired_option, desired_option }
    else
        -- Backward-compatible defaults (old workflow).
        if voice_field == "Male Voice Status" then
            -- Notion option casing sometimes differs; try both.
            option_candidates = { "Recorded (Needs importing)", "Recorded (Needs Importing)" }
        elseif voice_field == "Fem Voice Status" then
            option_candidates = { "Recorded (Needs Importing)", "Recorded (Needs importing)" }
        else
            return false, "Unknown voice field: " .. tostring(voice_field)
        end
    end

    local osname = reaper.GetOS() or ""
    if not osname:match("Win") then
        return false
    end

    local db_id = getNotionDwarfShoutsDbId()
    if not isValidNotionId(db_id) then
        return false, "Notion DB ID is invalid. Paste a Notion database URL or ID in Edit → Notion → Voiceline Database."
    end

    local dsid, ds_err = notionGetDataSourceId(notion_token, db_id)
    if not dsid then
        return false, "Notion data source lookup failed: " .. tostring(ds_err or "")
    end

    local token_ps = psEscapeSingleQuoted(notion_token)
    local ds_ps = psEscapeSingleQuoted(dsid)
    local db_ps = psEscapeSingleQuoted(db_id)
    local ver_ps = psEscapeSingleQuoted(NOTION_API_VERSION)
    local field_ps = psEscapeSingleQuoted(voice_field)
    local opt_id_ps = psEscapeSingleQuoted(desired_option_id)

    local opt1_ps = psEscapeSingleQuoted(option_candidates[1])
    local opt2_ps = psEscapeSingleQuoted(option_candidates[2])

    local ps = string.format([[
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$h = @{
  Authorization = 'Bearer %s'
  'Notion-Version' = '%s'
  'Content-Type' = 'application/json'
}

 $Field = '%s'
 $Opt1 = '%s'
 $Opt2 = '%s'
 $DbId = '%s'
 $OptId = '%s'

function Normalize-Opt([string]$s) {
  if (-not $s) { return '' }
  try { $s = $s -replace [char]0x00A0, ' ' } catch {}
  return ([string]$s).Trim().ToLowerInvariant()
}

function Get-Row([string]$bodyJson) {
  try {
    $resp = Invoke-RestMethod -Method Post -Uri ('https://api.notion.com/v1/data_sources/%s/query') -Headers $h -Body $bodyJson -ContentType 'application/json'
    if (-not $resp.results -or $resp.results.Count -lt 1) { return $null }
    return $resp.results[0]
  } catch {
    $status = $null
    $body = $null
    try {
      if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
        $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $body = $sr.ReadToEnd(); $sr.Close()
      }
    } catch {}
    if ($status -and $body) { Write-Output ('ERR|QUERY|' + $status + '|' + $body) }
    elseif ($status) { Write-Output ('ERR|QUERY|' + $status + '|Request failed') }
    else { Write-Output ('ERR|QUERY|0|' + $_.Exception.Message) }
    return $null
  }
}

$body1 = (@{ filter = @{ property = 'ID'; unique_id = @{ equals = %d } } } | ConvertTo-Json -Depth 10)
$row = Get-Row $body1
if (-not $row) {
  $body2 = (@{ filter = @{ property = 'ID'; number = @{ equals = %d } } } | ConvertTo-Json -Depth 10)
  $row = Get-Row $body2
}
if (-not $row) { Write-Output 'ERR|QUERY|0|No matching row for ID'; exit 2 }

# Get the page ID - convert to JSON and extract with regex (most reliable)
$pageId = $null
try {
  $rowJson = ($row | ConvertTo-Json -Depth 3 -Compress)
  Write-Output ('INFO|ROW_JSON_LEN|' + $rowJson.Length)
  # Look for the top-level id field (UUID format)
  if ($rowJson -match '^[^}]*"id"\s*:\s*"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})"') {
    $pageId = $matches[1]
  }
  if (-not $pageId -or $pageId.Length -ne 36) {
    Write-Output ('INFO|ROW_DEBUG|' + $rowJson.Substring(0, [Math]::Min(600, $rowJson.Length)))
  }
} catch {
  Write-Output ('INFO|JSON_ERR|' + $_.Exception.Message)
}
if (-not $pageId -or $pageId.Length -ne 36) { 
  Write-Output ('ERR|QUERY|0|Row missing valid page id (got: ' + $pageId + ')')
  exit 2 
}
Write-Output ('INFO|PAGE_ID|' + $pageId)

function Get-VoiceValueFromProps($props) {
  try {
    if (-not $props) { return $null }
    $p = $props.$Field
    if (-not $p) { return $null }
    if ($p.status -and $p.status.name) { return [string]$p.status.name }
    if ($p.select -and $p.select.name) { return [string]$p.select.name }
    if ($p.multi_select -and $p.multi_select.Count -gt 0 -and $p.multi_select[0].name) { return [string]$p.multi_select[0].name }
    return $null
  } catch { return $null }
}

function Resolve-DesiredOptionName() {
  # Prefer the exact option name from the database schema (Status/Select), so we don't rely on hardcoded casing.
  try {
    if (-not $DbId -or $DbId.Trim() -eq '') { return $null }
    $db = Invoke-RestMethod -Method Get -Uri ('https://api.notion.com/v1/databases/' + $DbId) -Headers $h
    if (-not $db -or -not $db.properties) { return $null }

    $prop = $db.properties.$Field
    if (-not $prop) { return $null }

    $opts = @()
    try {
      if ($prop.status -and $prop.status.options) { $opts = @($prop.status.options | ForEach-Object { $_.name }) }
      elseif ($prop.select -and $prop.select.options) { $opts = @($prop.select.options | ForEach-Object { $_.name }) }
    } catch {}

    if (-not $opts -or $opts.Count -lt 1) { return $null }

    # 1) Exact match (case-insensitive/trim) against our candidate strings
    foreach ($t in @($Opt1, $Opt2)) {
      if (-not $t -or $t.Trim() -eq '') { continue }
      $tn = Normalize-Opt $t
      foreach ($o in $opts) {
        if ((Normalize-Opt $o) -eq $tn) { return [string]$o }
      }
    }

    # 2) Fuzzy fallback: "recorded" + "needs" + "import"
    foreach ($o in $opts) {
      $on = Normalize-Opt $o
      if ($on -match 'recorded' -and $on -match 'needs' -and $on -match 'import') { return [string]$o }
    }
  } catch {}
  return $null
}

$before = Get-VoiceValueFromProps $row.properties
if ($before -and ((Normalize-Opt $before) -eq (Normalize-Opt $Opt1) -or (Normalize-Opt $before) -eq (Normalize-Opt $Opt2))) {
  Write-Output ('OK|ALREADY|' + $before)
  exit 0
}

function Try-PatchStatusById([string]$optId) {
  if (-not $optId -or $optId.Trim() -eq '') { return @{ ok = $false; info = @() } }
  $infoOut = @()
  try {
    $patch = @{ properties = @{} }
    $patch.properties[$Field] = @{ status = @{ id = $optId } }
    $patchBody = ($patch | ConvertTo-Json -Depth 10)
    $infoOut += ('INFO|PATCH_BODY|' + $patchBody)
    $infoOut += ('INFO|PATCH_URL|https://api.notion.com/v1/pages/' + $pageId)
    
    # Make the PATCH request and capture full response
    $resp = $null
    try {
      $resp = Invoke-RestMethod -Method Patch -Uri ('https://api.notion.com/v1/pages/' + $pageId) -Headers $h -Body $patchBody -ContentType 'application/json'
      $infoOut += ('INFO|PATCH_HTTP_STATUS|200')
    } catch {
      # If it's an HTTP error, extract status and body
      $status = $null
      $body = $null
      try {
        if ($_.Exception.Response) {
          $status = [int]$_.Exception.Response.StatusCode
          $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
          $body = $sr.ReadToEnd(); $sr.Close()
        }
      } catch {}
      if ($status) {
        $infoOut += ('ERR|PATCH_HTTP_STATUS|' + $status)
        if ($body) { $infoOut += ('ERR|PATCH_HTTP_BODY|' + $body) }
        return @{ ok = $false; info = $infoOut }
      }
      $infoOut += ('ERR|PATCH_EXCEPTION|' + $_.Exception.Message)
      return @{ ok = $false; info = $infoOut }
    }
    
    if (-not $resp) {
      $infoOut += ('ERR|PATCH_NO_RESPONSE|PATCH returned null')
      return @{ ok = $false; info = $infoOut }
    }
    
    # Process the response (wrap in try-catch to ensure we always log something)
    try {
      # Log the top-level structure of the response first
      $respKeys = @()
      try { $respKeys = @($resp.PSObject.Properties | ForEach-Object { $_.Name }) } catch {}
      $infoOut += ('INFO|PATCH_RESP_KEYS|' + ($respKeys -join ','))
    
    # Check what value Notion returned in the response
    $respVal = $null
    $hasProps = $false
    try { 
      if ($resp.properties) { 
        $hasProps = $true
        $respVal = Get-VoiceValueFromProps $resp.properties 
      } else {
        $infoOut += ('WARN|NO_PROPS|Response has no properties field')
      }
    } catch {
      $infoOut += ('WARN|PROPS_ACCESS_ERR|' + $_.Exception.Message)
    }
    
    if ($respVal) { 
      $infoOut += ('INFO|PATCH_RESP_ID|' + $respVal) 
    } else {
      if ($hasProps) {
        # Try to see what properties are in the response
        $propKeys = @()
        try { $propKeys = @($resp.properties.PSObject.Properties | ForEach-Object { $_.Name }) } catch {}
        $infoOut += ('INFO|PATCH_RESP_PROPS|' + ($propKeys -join ','))
        
        # Try to get the field we're updating
        $fieldProp = $null
        try { $fieldProp = $resp.properties.$Field } catch {}
        if (-not $fieldProp) {
          try { $fieldProp = $resp.properties.PSObject.Properties[$Field].Value } catch {}
        }
        
        if ($fieldProp) {
          try {
            $fieldJson = ($fieldProp | ConvertTo-Json -Depth 5 -Compress)
            $infoOut += ('INFO|FIELD_RAW|' + $fieldJson)
          } catch {
            $infoOut += ('WARN|FIELD_JSON_ERR|' + $_.Exception.Message)
          }
        } else {
          $infoOut += ('WARN|FIELD_MISSING|Field "' + $Field + '" not in PATCH response properties')
        }
      } else {
        $infoOut += ('WARN|NO_PROPS|Response has no properties field')
        # Dump a sample of the response structure
        try {
          $respSample = ($resp | ConvertTo-Json -Depth 2 -Compress)
          if ($respSample.Length -gt 500) { $respSample = $respSample.Substring(0, 500) + '...' }
          $infoOut += ('INFO|RESP_SAMPLE|' + $respSample)
        } catch {}
      }
    } catch {
      $infoOut += ('ERR|RESP_PROCESS_ERR|' + $_.Exception.Message)
    }
    return @{ ok = $true; info = $infoOut }
  } catch {
    $status = $null
    $body = $null
    try {
      if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
        $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $body = $sr.ReadToEnd(); $sr.Close()
      }
    } catch {}
    if ($status -and $body) { $infoOut += ('ERR|PATCH_STATUS_ID|' + $status + '|' + $body) }
    elseif ($status) { $infoOut += ('ERR|PATCH_STATUS_ID|' + $status + '|Request failed') }
    else { $infoOut += ('ERR|PATCH_STATUS_ID|0|' + $_.Exception.Message) }
    return @{ ok = $false; info = $infoOut }
  }
}

function Try-PatchStatus([string]$optName) {
  try {
    $patch = @{ properties = @{} }
    $patch.properties[$Field] = @{ status = @{ name = $optName } }
    $patchBody = ($patch | ConvertTo-Json -Depth 10)
    $resp = Invoke-RestMethod -Method Patch -Uri ('https://api.notion.com/v1/pages/' + $pageId) -Headers $h -Body $patchBody -ContentType 'application/json'
    # Check what value Notion returned in the response
    $respVal = $null
    try { $respVal = Get-VoiceValueFromProps $resp.properties } catch {}
    if ($respVal) { Write-Output ('INFO|PATCH_RESP|' + $respVal) }
    return $true
  } catch {
    $status = $null
    $body = $null
    try {
      if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
        $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $body = $sr.ReadToEnd(); $sr.Close()
      }
    } catch {}
    if ($status -and $body) { Write-Output ('ERR|PATCH_STATUS|' + $status + '|' + $body) }
    elseif ($status) { Write-Output ('ERR|PATCH_STATUS|' + $status + '|Request failed') }
    else { Write-Output ('ERR|PATCH_STATUS|0|' + $_.Exception.Message) }
    return $false
  }
}

function Try-PatchSelect([string]$optName) {
  try {
    $patch = @{ properties = @{} }
    $patch.properties[$Field] = @{ select = @{ name = $optName } }
    $patchBody = ($patch | ConvertTo-Json -Depth 10)
    $null = Invoke-RestMethod -Method Patch -Uri ('https://api.notion.com/v1/pages/' + $pageId) -Headers $h -Body $patchBody -ContentType 'application/json'
    return $true
  } catch {
    $status = $null
    $body = $null
    try {
      if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
        $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $body = $sr.ReadToEnd(); $sr.Close()
      }
    } catch {}
    if ($status -and $body) { Write-Output ('ERR|PATCH_SELECT|' + $status + '|' + $body) }
    elseif ($status) { Write-Output ('ERR|PATCH_SELECT|' + $status + '|Request failed') }
    else { Write-Output ('ERR|PATCH_SELECT|0|' + $_.Exception.Message) }
    return $false
  }
}

# Resolve the exact option name if possible (prevents casing/spacing mismatches).
$Desired = Resolve-DesiredOptionName
if (-not $Desired -or $Desired.Trim() -eq '') { $Desired = $Opt1 }

# Debug: show what we're trying to set
Write-Output ('INFO|DEBUG|Field=' + $Field + ', Desired=' + $Desired + ', OptId=' + $OptId + ', Before=' + $before)

# Try status first (common for Notion "Status" columns), then select.
# Prefer using option ID if available (more reliable than name).
$patched = $false

# 1) Try with option ID first (most reliable)
if (-not $patched -and $OptId -and $OptId.Trim() -ne '') {
  Write-Output ('INFO|TRYING|PatchById with id=' + $OptId)
  $result = Try-PatchStatusById $OptId
  foreach ($line in $result.info) { Write-Output $line }
  if ($result.ok) { $patched = $true }
}

# 2) Try with option name
if (-not $patched) {
  if (Try-PatchStatus $Desired) { $patched = $true }
}
if (-not $patched -and (Normalize-Opt $Desired) -ne (Normalize-Opt $Opt2)) {
  if (Try-PatchStatus $Opt2) { $patched = $true; $Desired = $Opt2 }
}

# 3) Try as select property (fallback for older configs)
if (-not $patched) {
  if (Try-PatchSelect $Desired) { $patched = $true }
}
if (-not $patched -and (Normalize-Opt $Desired) -ne (Normalize-Opt $Opt2)) {
  if (Try-PatchSelect $Opt2) { $patched = $true; $Desired = $Opt2 }
}

if (-not $patched) {
  Write-Output 'ERR|VERIFY|0|Patch failed (no successful PATCH attempt)'
  exit 5
}

# Verify by re-querying the row (PATCH responses can omit/lag updated properties).
# Notion can take a moment to propagate updates, so we retry a few times.
$after = $null
$maxRetries = 3
for ($retry = 0; $retry -lt $maxRetries; $retry++) {
  if ($retry -gt 0) {
    Start-Sleep -Milliseconds 500
    Write-Output ('INFO|VERIFY_RETRY|' + $retry + '/3')
  } else {
    Start-Sleep -Milliseconds 300
  }
  $row2 = Get-Row $body1
  if (-not $row2) { $row2 = Get-Row $body2 }
  if ($row2) { 
    $after = Get-VoiceValueFromProps $row2.properties
    if ($after) {
      $afterN = Normalize-Opt $after
      if ($afterN -ne '' -and ($afterN -eq (Normalize-Opt $Desired) -or $afterN -eq (Normalize-Opt $Opt1) -or $afterN -eq (Normalize-Opt $Opt2))) {
        Write-Output ('INFO|VERIFY_SUCCESS|Got expected value: ' + $after)
        break
      }
    }
  }
}

$afterN = Normalize-Opt $after
if ($afterN -ne '' -and ($afterN -eq (Normalize-Opt $Desired) -or $afterN -eq (Normalize-Opt $Opt1) -or $afterN -eq (Normalize-Opt $Opt2))) {
  Write-Output ('OK|CHANGED|' + $after)
  exit 0
}

$want = $Desired
if (-not $want -or $want.Trim() -eq '') { $want = $Opt1 }
$got = $after
if (-not $got) { $got = '(null)' }
Write-Output ("ERR|VERIFY|0|Patched but could not verify updated value (wanted '" + $want + "' got '" + $got + "')")
Write-Output ("ERR|VERIFY_DETAIL|Before='" + $before + "', After='" + $got + "', Desired='" + $Desired + "', OptId='" + $OptId + "'")
Write-Output ("ERR|VERIFY_DETAIL|Possible causes:")
Write-Output ("ERR|VERIFY_DETAIL|1) Integration lacks write permissions for this database")
Write-Output ("ERR|VERIFY_DETAIL|2) Notion automation/workflow is reverting the change")
Write-Output ("ERR|VERIFY_DETAIL|3) Option ID/name mismatch (check PATCH_RESP_PROPS/FIELD_RAW above)")
exit 5
]], token_ps, ver_ps, field_ps, opt1_ps, opt2_ps, db_ps, opt_id_ps, ds_ps, id_num, id_num)

    local out, exit_code = runPowerShellHidden(ps, 60000)
    out = tostring(out or "")

    local ok_already = nil
    local ok_changed = nil
    local err_line = nil
    local info_lines = {}
    for line in out:gmatch("[^\r\n]+") do
        local t = trimWS(line)
        local a = t:match("^OK|ALREADY|(.+)$")
        if a then ok_already = trimWS(a) end
        local c = t:match("^OK|CHANGED|(.+)$")
        if c then ok_changed = trimWS(c) end
        if t:sub(1, 4) == "ERR|" then err_line = t end
        if t:sub(1, 5) == "INFO|" then table.insert(info_lines, t) end
    end

    if ok_changed then
        return true, nil, true
    elseif ok_already then
        return true, nil, false
    end

    -- Include debug info in error message
    local debug_info = ""
    if #info_lines > 0 then
        debug_info = "\n\nDebug info:\n" .. table.concat(info_lines, "\n")
    end

    if err_line then
        return false, err_line .. debug_info
    end

    local out_trim = trimWS(out)
    return false, "Unknown error (no output), exit code: " .. tostring(exit_code) .. "\nOutput:\n" .. (out_trim ~= "" and out_trim or "(no output)") .. debug_info
end

local function findSmallestRegionContainingPos(pos)
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = (num_markers or 0) + (num_regions or 0)
    local best = nil
    for i = 0, (total - 1) do
        local ok, isrgn, rstart, rend = reaper.EnumProjectMarkers(i)
        if ok and isrgn and pos >= rstart and pos <= rend then
            local len = rend - rstart
            if not best or len < best.len then
                best = { start = rstart, ["end"] = rend, len = len }
            end
        end
    end
    return best
end

local function collectIndexMarkers()
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = (num_markers or 0) + (num_regions or 0)
    local out = {}
    for i = 0, (total - 1) do
        local ok, isrgn, pos, _, name, id = reaper.EnumProjectMarkers3(0, i)
        if ok and not isrgn then
            name = tostring(name or "")
            if name:match("^%s*[Ii][Nn][Dd][Ee][Xx]=") then
                out[#out + 1] = { pos = pos, id = id, name = name }
            end
        end
    end
    return out
end

-- exclude_used_ids: optional set (table) of marker ids already assigned to another ID (so we don't double-use)
local function findBestIndexMarkerForPos(index_markers, pos, region, tolerance, exclude_used_ids)
    tolerance = tonumber(tolerance) or 1.0
    local best = nil
    for _, m in ipairs(index_markers or {}) do
        if exclude_used_ids and m.id and exclude_used_ids[m.id] then
            -- Already assigned to another ID marker
        else
            local in_region = false
            if region then
                in_region = m.pos >= region.start and m.pos <= region["end"]
            end
            local dist = math.abs(m.pos - pos)
            local ok = (region and in_region) or (not region and dist <= tolerance) or (region and dist <= tolerance)
            if ok then
                if not best or dist < best.dist then
                    best = { marker = m, dist = dist }
                end
            end
        end
    end
    return best and best.marker or nil
end

local function collectIDMarkers()
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = (num_markers or 0) + (num_regions or 0)
    local out = {}
    for i = 0, (total - 1) do
        local ok, isrgn, pos, _, name = reaper.EnumProjectMarkers3(0, i)
        if ok and not isrgn then
            name = tostring(name or "")
            local id_num = name:match("[Ii][Dd]=(%d+)")
            if id_num then
                out[#out + 1] = { pos = pos, id_num = tonumber(id_num) }
            end
        end
    end
    return out
end

-- Like collectIDMarkers(), but includes the marker ID (markrgnindexnumber) so we can move it.
local function collectIDMarkersDetailed()
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = (num_markers or 0) + (num_regions or 0)
    local out = {}
    for i = 0, (total - 1) do
        local ok, isrgn, pos, _, name, id = reaper.EnumProjectMarkers3(0, i)
        if ok and not isrgn then
            name = tostring(name or "")
            local id_num = name:match("[Ii][Dd]=(%d+)")
            if id_num then
                out[#out + 1] = { pos = pos, id = id, id_num = tonumber(id_num), name = name }
            end
        end
    end
    return out
end

local function findIDMarkerForRegion(id_markers, region, tol_before_start)
    if not region then return nil end
    tol_before_start = tonumber(tol_before_start) or 0

    local best = nil
    for _, m in ipairs(id_markers or {}) do
        -- Allow ID markers a bit BEFORE the region start (common workflow)
        if m.pos >= (region.start - tol_before_start) and m.pos <= region["end"] then
            local dist = math.abs(m.pos - region.start)
            if not best or dist < best.dist then
                best = { m = m, dist = dist }
            end
        end
    end
    return best and best.m or nil
end

local function isEntryRegionName(name)
    name = tostring(name or "")
    if name == "" then return false end
    if name:match("^Category=") then return false end
    -- Common non-entry regions (if you ever add them)
    if name:match("^Context=") then return false end
    return true
end

local function collectEntryRegionsInRange(ts_only)
    local ts_start, ts_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = (num_markers or 0) + (num_regions or 0)
    local out = {}
    for i = 0, (total - 1) do
        local ok, isrgn, pos, rgnend, name = reaper.EnumProjectMarkers3(0, i)
        if ok and isrgn and isEntryRegionName(name) then
            if (not ts_only) or ts_start == ts_end or (pos >= ts_start and pos <= ts_end) or (rgnend >= ts_start and rgnend <= ts_end) then
                -- strip optional Entry= prefix
                name = tostring(name or "")
                name = name:gsub("^Entry=", "")
                out[#out + 1] = { start = pos, ["end"] = rgnend, name = name }
            end
        end
    end
    return out
end

local function trackHasItemOverlapping(track, start_time, end_time)
    if not track then return false end
    local num_items = reaper.CountTrackMediaItems(track)
    for i = 0, (num_items - 1) do
        local item = reaper.GetTrackMediaItem(track, i)
        local ipos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local ilen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local iend = ipos + ilen
        if ipos < end_time and iend > start_time then
            return true
        end
    end
    return false
end

local function findFirstItemOverlapping(track, start_time, end_time)
    if not track then return nil end
    local num_items = reaper.CountTrackMediaItems(track)
    local best = nil
    for i = 0, (num_items - 1) do
        local item = reaper.GetTrackMediaItem(track, i)
        local ipos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local ilen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local iend = ipos + ilen
        if ipos < end_time and iend > start_time then
            if not best or ipos < best.pos then
                best = { item = item, pos = ipos, ["end"] = iend }
            end
        end
    end
    return best
end

local function renameMarkersToIndexFromName(opts)
    opts = opts or {}
    local filter_contains = trimWS(opts.filter_contains or "")
    local index_prefix = tostring(opts.index_prefix or "Index=")
    local keep_zeros = true -- keep captured digits exactly (e.g. "03")
    local only_in_time_selection = opts.only_in_time_selection == true
    local ts_start, ts_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)

    local changed = 0
    local skipped_no_match = 0
    local skipped_filter = 0
    local skipped_already_index = 0
    local skipped_outside_time_sel = 0

    -- IMPORTANT: EnumProjectMarkers3 index spans markers + regions (interleaved).
    -- We must iterate total entries, otherwise we'll miss many markers when regions exist.
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = (num_markers or 0) + (num_regions or 0)

    for i = 0, (total - 1) do
        local ok, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers3(0, i)
        if ok and not isrgn then
            name = tostring(name or "")

            if only_in_time_selection and ts_start ~= ts_end then
                if pos < ts_start or pos > ts_end then
                    skipped_outside_time_sel = skipped_outside_time_sel + 1
                    goto continue_marker
                end
            end

            if filter_contains ~= "" and not name:find(filter_contains, 1, true) then
                skipped_filter = skipped_filter + 1
            else
                if name:match("^%s*Index=%d+%s*$") or name:match("^%s*Index=%d+") then
                    skipped_already_index = skipped_already_index + 1
                else
                    local digits = deriveIndexSuffix(name)
                    if not digits then
                        skipped_no_match = skipped_no_match + 1
                    else
                        local new_name = index_prefix .. (keep_zeros and digits or tostring(tonumber(digits) or digits))
                        reaper.SetProjectMarker2(0, markrgnindexnumber, false, pos, 0, new_name)
                        -- Preserve color if possible (REAPER keeps color when using SetProjectMarker2,
                        -- but we can re-apply if the API supports it via SetProjectMarkerByIndex2 in future)
                        changed = changed + 1
                    end
                end
            end
            ::continue_marker::
        end
    end

    return {
        changed = changed,
        skipped_filter = skipped_filter,
        skipped_no_suffix = skipped_no_match,
        skipped_already_index = skipped_already_index,
        skipped_outside_time_sel = skipped_outside_time_sel,
    }
end

-- ============================================================================
-- EDIT TAB: Incorporated utilities (ported from standalone scripts)
-- ============================================================================

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

            -- Find an existing marker with same name within this region bounds
            local existing_id = nil
            for _, m in ipairs(markers) do
                if m.name == region_name and m.pos >= r.start and m.pos <= r["end"] then
                    existing_id = m.id
                    break
                end
            end

            if existing_id ~= nil then
                reaper.SetProjectMarker2(0, existing_id, false, marker_pos, 0, region_name)
            else
                reaper.AddProjectMarker2(0, false, marker_pos, 0, region_name, -1, 0)
            end
        end
    end

    reaper.Undo_EndBlock("Create markers from region names (time selection)", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

local function markDuplicateRegionsByName()
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = num_markers + num_regions
    if total == 0 or num_regions == 0 then
        reaper.ShowMessageBox("No regions found.", "Duplicate regions", 0)
        return
    end

    local regions_by_name = {}
    for i = 0, (total - 1) do
        local ok, isrgn, pos, rgnend, name, id = reaper.EnumProjectMarkers(i)
        if ok and isrgn then
            name = tostring(name or "")
            if name ~= "" then
                regions_by_name[name] = regions_by_name[name] or {}
                table.insert(regions_by_name[name], { idx = i, id = id, start = pos, ["end"] = rgnend, name = name })
            end
        end
    end

    local red = reaper.ColorToNative(255, 6, 6) | 0x1000000
    local changed = 0

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    for name, list in pairs(regions_by_name) do
        if #list > 1 then
            -- Mark the latest-by-position region (closest to project end), matching the older script behavior loosely
            table.sort(list, function(a, b) return a.start < b.start end)
            local target = list[#list]
            if not target.name:match("_duplicate$") then
                local new_name = target.name .. "_duplicate"
                if reaper.SetProjectMarkerByIndex2 then
                    reaper.SetProjectMarkerByIndex2(0, target.idx, true, target.start, target["end"], target.id, new_name, red, 0)
                else
                    reaper.SetProjectMarkerByIndex(0, target.idx, true, target.start, target["end"], target.id, new_name, red)
                end
                changed = changed + 1
            end
        end
    end

    reaper.Undo_EndBlock("Mark duplicate regions by name", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()

    reaper.ShowMessageBox("Marked duplicates: " .. tostring(changed), "Duplicate regions", 0)
end

local function detectDuplicateIndexMarkersAndSelectItems()
    local start_time, end_time = getTimeSelectionOrWholeProject()

    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = num_markers + num_regions
    if total == 0 then
        reaper.ShowMessageBox("No markers/regions found.", "Duplicate Index markers", 0)
        return
    end

    -- Cache Category= regions
    local categories = {}
    for i = 0, (total - 1) do
        local ok, isrgn, pos, rgnend, name = reaper.EnumProjectMarkers(i)
        if ok and isrgn and name and name:match("^Category=") then
            categories[#categories + 1] = { start = pos, ["end"] = rgnend, category = name:match("^Category=(.+)") or "" }
        end
    end

    local function getCategoryAt(pos)
        for _, c in ipairs(categories) do
            if pos >= c.start and pos <= c["end"] then return c.category end
        end
        return nil
    end

    local markers = {}
    for i = 0, (total - 1) do
        local ok, isrgn, pos, _, name, id = reaper.EnumProjectMarkers(i)
        if ok and not isrgn and pos >= start_time and pos <= end_time then
            name = tostring(name or "")
            local idx = name:match("[Ii][Nn][Dd][Ee][Xx]=(%d+)")
            if idx then
                markers[#markers + 1] = { idx = i, id = id, pos = pos, index_num = idx, name = name }
            end
        end
    end

    local grouped = {} -- grouped[category][index] = {markers}
    for _, m in ipairs(markers) do
        local cat = getCategoryAt(m.pos) or "NoCategory"
        grouped[cat] = grouped[cat] or {}
        grouped[cat][m.index_num] = grouped[cat][m.index_num] or {}
        table.insert(grouped[cat][m.index_num], m)
    end

    local duplicates = {}
    for cat, indexes in pairs(grouped) do
        for idx, list in pairs(indexes) do
            if #list > 1 then
                duplicates[#duplicates + 1] = { category = cat, index = idx, markers = list }
            end
        end
    end

    if #duplicates == 0 then
        reaper.ShowMessageBox("No duplicate index markers found in the time selection.", "Duplicate Index markers", 0)
        return
    end

    local function getMediaItemsAtPosition(pos, tolerance)
        tolerance = tolerance or 1.0
        local items = {}
        local num_tracks = reaper.CountTracks(0)
        for t = 0, (num_tracks - 1) do
            local track = reaper.GetTrack(0, t)
            local num_items = reaper.CountTrackMediaItems(track)
            for it = 0, (num_items - 1) do
                local item = reaper.GetTrackMediaItem(track, it)
                local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                local item_end = item_pos + item_len
                if pos >= (item_pos - tolerance) and pos <= (item_end + tolerance) then
                    items[#items + 1] = item
                end
            end
        end
        return items
    end

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    reaper.Main_OnCommand(40289, 0) -- Unselect all items
    local selected_count = 0
    local lines = {}

    for _, d in ipairs(duplicates) do
        lines[#lines + 1] = string.format("Category: %s, Index: %s (%d duplicates)", d.category, d.index, #d.markers)
        for _, m in ipairs(d.markers) do
            for _, item in ipairs(getMediaItemsAtPosition(m.pos, 1.0)) do
                if not reaper.IsMediaItemSelected(item) then
                    reaper.SetMediaItemSelected(item, true)
                    selected_count = selected_count + 1
                end
            end
        end
    end

    reaper.Undo_EndBlock("Detect duplicate Index markers (select items)", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()

    reaper.ShowMessageBox(
        "Found " .. tostring(#duplicates) .. " duplicate index group(s):\n\n" ..
        table.concat(lines, "\n") ..
        "\n\nSelected " .. tostring(selected_count) .. " media item(s) near duplicates.",
        "Duplicate Index markers",
        0
    )
end

-- Fix Index= markers by looking up ID= markers against the CSV's ID→Index mapping.
-- Reads the CSV from the Import tab's URL/file, finds the ID and Index columns,
-- then for each ID= marker: ensures an Index= marker at the same position with the
-- correct index from the CSV (moves/renames existing or creates missing).
local function fixIndexMarkersFromCSV()
    local source = GUI.Val("txt_url") or ""
    if source == "" then
        reaper.ShowMessageBox("No CSV source configured.\n\nEnter a URL or file path in the Import tab first.", "Fix Index Markers", 0)
        return
    end

    local csv_content = nil
    if source:match("^https?://") then
        csv_content = downloadCSV(source)
    else
        csv_content = readLocalCSV(source)
    end

    if not csv_content or csv_content == "" then
        reaper.ShowMessageBox("Failed to load CSV data from:\n" .. source, "Fix Index Markers", 0)
        return
    end

    local header_line = csv_content:match("([^\r\n]+)")
    if not header_line then
        reaper.ShowMessageBox("CSV appears empty.", "Fix Index Markers", 0)
        return
    end

    local headers = parseCSV(header_line)
    local id_col = nil
    local index_col = nil
    for i, h in ipairs(headers) do
        local lower = (h or ""):lower():match("^%s*(.-)%s*$")
        if lower == "id" then id_col = i end
        if lower == "index" then index_col = i end
    end

    if not id_col or not index_col then
        reaper.ShowMessageBox(
            "CSV must have 'ID' and 'Index' columns in the header row.\n\nFound headers: " .. table.concat(headers, ", "),
            "Fix Index Markers", 0)
        return
    end

    local id_to_index = {}
    local entry_count = 0
    local line_num = 0
    for line in csv_content:gmatch("[^\r\n]+") do
        line_num = line_num + 1
        if line_num > 1 then
            local fields = parseCSV(line)
            local csv_id = fields[id_col] and trimWS(fields[id_col]) or ""
            local csv_index = fields[index_col] and trimWS(fields[index_col]) or ""
            if csv_id ~= "" and tonumber(csv_id) and csv_index ~= "" then
                id_to_index[csv_id] = csv_index
                entry_count = entry_count + 1
            end
        end
    end

    if entry_count == 0 then
        reaper.ShowMessageBox("No valid ID→Index mappings found in CSV.", "Fix Index Markers", 0)
        return
    end

    local id_markers = collectIDMarkers()
    local index_markers = collectIndexMarkers()

    if #id_markers == 0 then
        reaper.ShowMessageBox(
            "No ID= markers found in the project.\n\n" ..
            "Run 'Create ID= markers from Notion' first, or import with an ID column enabled.",
            "Fix Index Markers", 0)
        return
    end

    local fixes = {}
    local missing_list = {}
    local skip_count = 0
    local checked = 0
    -- So we don't assign the same Index marker to multiple IDs (each marker used at most once)
    local used_index_ids = {}

    for _, id_m in ipairs(id_markers) do
        local id_str = tostring(id_m.id_num)
        if id_to_index[id_str] then
            checked = checked + 1
            local raw_expected = id_to_index[id_str]
            local expected = string.format("%02d", tonumber(raw_expected) or 0)

            local region = findSmallestRegionContainingPos(id_m.pos)
            local best_idx_m = findBestIndexMarkerForPos(index_markers, id_m.pos, region, 3, used_index_ids)

            if best_idx_m then
                local actual = best_idx_m.name:match("[Ii][Nn][Dd][Ee][Xx]=(%d+)")
                -- Always fix: set correct Index name and move to same position as ID= marker
                table.insert(fixes, {
                    marker = best_idx_m,
                    expected = expected,
                    actual = actual,
                    id = id_str,
                    target_pos = id_m.pos
                })
                used_index_ids[best_idx_m.id] = true
            else
                table.insert(missing_list, { pos = id_m.pos, expected = expected, id = id_str })
            end
        else
            skip_count = skip_count + 1
        end
    end

    if #fixes == 0 and #missing_list == 0 then
        reaper.ShowMessageBox(
            "All " .. checked .. " Index markers verified OK!\n\n" ..
            "(" .. skip_count .. " ID markers not in CSV, " .. entry_count .. " CSV entries loaded)",
            "Fix Index Markers", 0)
        return
    end

    local lines = {}
    for _, f in ipairs(fixes) do
        local move_str = (math.abs((f.marker.pos or 0) - (f.target_pos or 0)) > 0.001) and " [move to ID pos]" or ""
        local name_str = (f.actual and f.actual ~= f.expected) and (" Index=" .. f.actual .. " → " .. f.expected) or (" Index=" .. f.expected .. move_str)
        lines[#lines + 1] = "  ID=" .. f.id .. ":" .. name_str
    end
    for _, m in ipairs(missing_list) do
        lines[#lines + 1] = "  ID=" .. m.id .. ": create Index=" .. m.expected .. " at ID position"
    end

    local msg = "Checked: " .. checked ..
                "\nAlign/fix existing: " .. #fixes ..
                "\nCreate missing at ID position: " .. #missing_list .. "\n"
    if #fixes + #missing_list > 0 then
        msg = msg .. "\nPlanned:\n" .. table.concat(lines, "\n") .. "\n"
    end
    msg = msg .. "\nApply " .. (#fixes + #missing_list) .. " change(s)?"

    if reaper.ShowMessageBox(msg, "Fix Index Markers", 4) ~= 6 then return end

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    for _, f in ipairs(fixes) do
        reaper.SetProjectMarker2(0, f.marker.id, false, f.target_pos, 0, "Index=" .. f.expected)
    end
    for _, m in ipairs(missing_list) do
        reaper.AddProjectMarker2(0, false, m.pos, 0, "Index=" .. m.expected, -1, 0)
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Fix Index markers from CSV (align + create)", -1)

    reaper.ShowMessageBox(
        "Aligned/fixed " .. #fixes .. " Index marker(s).\nCreated " .. #missing_list .. " at ID positions.",
        "Fix Index Markers", 0)
end

-- Auto-suggest column mappings from CSV headers
local function autoSuggestFromCSV()
    local source = GUI.Val("txt_url") or ""
    
    if source == "" then
        reaper.ShowMessageBox("Please enter a URL or file path first.", "Auto Suggest", 0)
        return
    end
    
    local csv_content = nil
    
    if source:match("^https?://") then
        csv_content = downloadCSV(source)
        if not csv_content or csv_content == "" then
            reaper.ShowMessageBox("Failed to download CSV from URL.\n\nMake sure the URL is accessible.", "Error", 0)
            return
        end
    else
        csv_content = readLocalCSV(source)
        if not csv_content or csv_content == "" then
            reaper.ShowMessageBox("Failed to read file:\n" .. source, "Error", 0)
            return
        end
    end
    
    -- Get the first line (headers)
    local first_line = csv_content:match("([^\r\n]+)")
    if not first_line then
        reaper.ShowMessageBox("Could not read CSV headers.", "Error", 0)
        return
    end
    
    local headers = parseCSV(first_line)
    if #headers == 0 then
        reaper.ShowMessageBox("No columns found in CSV.", "Error", 0)
        return
    end
    
    -- Clear existing mappings and reset roles
    entry_row = 0
    category_row = 0
    speaker_row = 0

    for i = 1, MAX_COLUMNS do
        GUI.Val("txt_name_" .. i, "")
        GUI.Val("txt_col_" .. i, "")
        GUI.Val("chk_marker_" .. i, {false})
        GUI.Val("chk_region_" .. i, {false})
        GUI.Val("chk_item_" .. i, {false})
        GUI.Val("chk_pfx_marker_" .. i, {false})
        GUI.Val("chk_pfx_region_" .. i, {false})
        GUI.Val("chk_track_" .. i, {false})
    end

    -- Fill in mappings from headers
    local count = math.min(#headers, MAX_COLUMNS)
    for i = 1, count do
        local header = headers[i]:match("^%s*(.-)%s*$") -- trim whitespace
        if header and header ~= "" then
            GUI.Val("txt_name_" .. i, header)
            GUI.Val("txt_col_" .. i, tostring(i))

            -- Smart defaults based on common column names
            local header_lower = header:lower()

            if header_lower == "category" or header_lower == "group" or header_lower == "parent" or header_lower == "context" or header_lower == "scene" then
                category_row = i
                GUI.Val("chk_marker_" .. i, {true})
                GUI.Val("chk_region_" .. i, {true})
                GUI.Val("chk_pfx_marker_" .. i, {true})
                GUI.Val("chk_pfx_region_" .. i, {true})
            elseif header_lower == "speaker" or header_lower == "character" or header_lower == "actor" or header_lower == "voice" or header_lower == "narrator" then
                speaker_row = i
                GUI.Val("chk_marker_" .. i, {false})
                GUI.Val("chk_region_" .. i, {false})
                GUI.Val("chk_track_" .. i, {true})
            elseif header_lower == "entry" or header_lower == "line" or header_lower == "dialogue" or header_lower == "variation" or header_lower == "text" or header_lower == "name" then
                entry_row = i
                GUI.Val("chk_region_" .. i, {true})
                GUI.Val("chk_pfx_region_" .. i, {false})
            elseif header_lower == "notes" or header_lower == "note" or header_lower == "description" or header_lower == "desc" or header_lower == "comment" or header_lower == "direction" or header_lower:find("note") or header_lower:find("comment") then
                GUI.Val("chk_item_" .. i, {true})
            else
                -- Default: create marker with prefix
                GUI.Val("chk_marker_" .. i, {true})
                GUI.Val("chk_pfx_marker_" .. i, {true})
            end
        end
    end
    
    -- If no name source was found, use the first column as name source
    if entry_row == 0 and count > 0 then
        entry_row = 1
    end
    
    active_rows = count
    updateRowVisibility()
end

-- Get list of saved presets
local function getPresetList()
    local preset_list = reaper.GetExtState("DMN_CSVImport_Presets", "_preset_list") or ""
    local presets = {}
    for name in preset_list:gmatch("([^|]+)") do
        table.insert(presets, name)
    end
    return presets
end

-- ============================================================================
-- MAIN IMPORT FUNCTION (Dynamic Columns)
-- ============================================================================

-- Helper function to extract numeric suffix from a string (e.g., "Something_03" -> "03")
-- Also handles plain numbers (e.g., "03" from an Index column) as a fallback.
local function extractSuffixNumber(str)
    if not str or str == "" then return nil end
    local match = str:match("_(%d+)$")
    if match then return match end
    match = str:match("^%s*(%d+)%s*$")
    return match
end

-- Category group colors for import (from Theme > Region / Marker Colors)
local function getThemeCategoryColors()
    local out = {}
    for i = 1, 8 do
        local k = "region_color_" .. i
        local c = THEME[k]
        if c and type(c) == "table" and c[1] then
            out[i] = {
                color = reaper.ColorToNative(
                    math.floor(c[1] * 255 + 0.5),
                    math.floor(c[2] * 255 + 0.5),
                    math.floor(c[3] * 255 + 0.5)
                ) | 0x1000000
            }
        else
            out[i] = { color = reaper.ColorToNative(128, 128, 128) | 0x1000000 }
        end
    end
    return out
end

local function doImport(csv_content, mappings, start_row, insert_at_cursor, auto_index_enabled, auto_id_enabled, timing_opts, color_opts, entry_idx, category_idx, speaker_idx)
    -- Split CSV content into lines
    local lines = {}
    for line in csv_content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    if #lines == 0 then
        reaper.ShowMessageBox("No data found in CSV.", "Error", 0)
        return false
    end

    -- Timing options (use provided or defaults)
    timing_opts = timing_opts or {}
    local region_length = timing_opts.region_length or 10
    local region_gap = timing_opts.region_gap or 5
    local category_section_gap = timing_opts.category_gap or 30
    local initial_gap = 30
    local group_marker_offset = 3
    
    -- Color options (palette and on/off come from Theme, not Import checkbox)
    color_opts = color_opts or {}
    local CATEGORY_PALETTE = getThemeCategoryColors()
    local use_group_colors = THEME.color_regions ~= false
    local group_color_map = {}
    local color_index = 1

    local current_pos = insert_at_cursor and reaper.GetCursorPosition() or initial_gap

    -- Find the entry, category, and character mappings by index (not by hardcoded names)
    local entry_mapping = nil     -- Column that provides region names (Entry)
    local category_mapping = nil  -- Column used for grouping (Category)
    local speaker_mapping = nil -- Column used for Speaker= markers

    if entry_idx and entry_idx > 0 and entry_idx <= #mappings then
        entry_mapping = mappings[entry_idx]
    end
    if category_idx and category_idx > 0 and category_idx <= #mappings then
        category_mapping = mappings[category_idx]
    end
    if speaker_idx and speaker_idx > 0 and speaker_idx <= #mappings then
        speaker_mapping = mappings[speaker_idx]
    end
    
    if not entry_mapping then
        reaper.ShowMessageBox("Please set an Entry column (click [E] button) to define which column provides region names.", "Error", 0)
        return false
    end

    -- Create tracks for any mapping that has create_item enabled
    local tracks = {}
    for _, m in ipairs(mappings) do
        if m.create_item then
            tracks[m.name] = getOrCreateTrack(m.name)
        end
    end

    -- Pre-pass: count entries per category for auto-index numbering
    local category_entry_counts = {}
    if auto_index_enabled then
        local pre_group = ""
        local pre_start = math.min(start_row, #lines)
        for i = pre_start, #lines do
            local ln = lines[i]
            if ln and ln:match("%S") then
                local flds = parseCSV(ln)
                local entry_val = entry_mapping and (flds[entry_mapping.col] and cleanFieldValue(flds[entry_mapping.col])) or nil
                local cat_val = category_mapping and (flds[category_mapping.col] and cleanFieldValue(flds[category_mapping.col])) or nil
                if cat_val then pre_group = cat_val end
                local grp_key = (cat_val or pre_group ~= "" and pre_group) or "Default"
                if entry_val then
                    category_entry_counts[grp_key] = (category_entry_counts[grp_key] or 0) + 1
                end
            end
        end
    end

    -- ID character set: A-Z, 0-9
    local ID_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local function generateID()
        local id = {}
        for _ = 1, 4 do
            local idx = math.random(1, #ID_CHARS)
            id[#id + 1] = ID_CHARS:sub(idx, idx)
        end
        return table.concat(id)
    end

    reaper.Undo_BeginBlock()

    local start_index = math.min(start_row, #lines)
    local last_group = ""
    local current_group = ""
    local line_counter = 0
    local group_item_count = 0
    local group_regions = {}
    local current_group_start = nil
    local category_index_counter = {}  -- per-category running index for auto-index

    -- Pre-compute max column needed (once, outside the loop)
    local max_col = 0
    for _, m in ipairs(mappings) do
        if m.col > max_col then max_col = m.col end
    end

    -- (Column-count mismatch is handled gracefully: out-of-range columns become nil.)

    for i = start_index, #lines do
        local line = lines[i]
        if line and line:match("%S") then
            local fields = parseCSV(line)
            
            do
                -- Get values for each mapping (nil for out-of-range columns)
                local values = {}
                for _, m in ipairs(mappings) do
                    if m.col <= #fields then
                        values[m.name] = cleanFieldValue(fields[m.col])
                    end
                    -- else: values[m.name] stays nil (column doesn't exist in this CSV)
                end
                
                -- Get the entry value from the designated entry column
                local entry_value = entry_mapping and values[entry_mapping.name] or nil
                -- Get the category value (if category column is set)
                local category_val = category_mapping and values[category_mapping.name] or nil
                
                -- Handle category tracking (category column provides grouping)
                if category_mapping then
                    if category_val then
                        current_group = category_val
                    end
                else
                    current_group = "Default"
                end
                
                if entry_value then
                    line_counter = line_counter + 1
                    
                    -- Handle category changes
                    if category_mapping and current_group ~= last_group then
                        if last_group ~= "" and current_group_start then
                            group_regions[last_group] = {
                                start = current_group_start,
                                end_pos = current_pos - region_gap
                            }
                        end
                        
                        if last_group ~= "" then
                            current_pos = current_pos + category_section_gap
                        end
                        
                        current_group_start = current_pos - group_marker_offset
                        
                        -- [C] role always creates category markers; Tag M controls prefix
                        local marker_name = category_mapping.prefix_marker and ("Category=" .. current_group) or current_group
                        reaper.AddProjectMarker2(0, false, current_pos - group_marker_offset, 0, marker_name, -1, 0)
                        
                        last_group = current_group
                        group_item_count = 0
                        
                        -- Assign color to this group if colors enabled
                        if use_group_colors and not group_color_map[current_group] then
                            group_color_map[current_group] = CATEGORY_PALETTE[color_index].color
                            color_index = (color_index % #CATEGORY_PALETTE) + 1
                        end
                    end
                    
                    group_item_count = group_item_count + 1
                    
                    -- Create markers/regions for each mapping.
                    -- Marker OR Tag M → create marker (Tag M adds prefix).
                    -- Region OR Tag R → create region (Tag R adds prefix).
                    -- Skip category (handled above), entry (handled below), and
                    -- speaker (handled by the dedicated Speaker= block below).
                    for idx, m in ipairs(mappings) do
                        local val = values[m.name]
                        if val then
                            local is_category = (category_mapping and m.name == category_mapping.name)
                            local is_entry    = (entry_mapping    and m.name == entry_mapping.name)
                            local is_speaker  = (speaker_mapping  and m.name == speaker_mapping.name)
                            if not is_category and not is_entry and not is_speaker then
                                if m.create_marker or m.prefix_marker then
                                    local marker_name = m.prefix_marker and (m.name .. "=" .. val) or val
                                    reaper.AddProjectMarker2(0, false, current_pos - 1, 0, marker_name, -1, 0)
                                end
                                if m.create_region or m.prefix_region then
                                    local rgn_name = m.prefix_region and (m.name .. "=" .. val) or val
                                    local rgn_color = use_group_colors and group_color_map[current_group] or 0
                                    reaper.AddProjectMarker2(0, true, current_pos, current_pos + region_length, rgn_name, -1, rgn_color)
                                end
                            end
                        end
                    end
                    
                    -- Create Speaker= marker if speaker column is set
                    if speaker_mapping then
                        local spk_val = values[speaker_mapping.name]
                        if spk_val and spk_val ~= "" then
                            reaper.AddProjectMarker2(0, false, current_pos - 1, 0, "Speaker=" .. spk_val, -1, 0)
                        end
                    end

                    -- Auto-place Index= marker 1 second before entry
                    if auto_index_enabled then
                        local grp_key = (current_group ~= "" and current_group) or "Default"
                        category_index_counter[grp_key] = (category_index_counter[grp_key] or 0) + 1
                        local total = category_entry_counts[grp_key] or 1
                        local digits = #tostring(total) < 2 and 2 or #tostring(total)
                        local idx_str = string.format("%0" .. digits .. "d", category_index_counter[grp_key])
                        reaper.AddProjectMarker2(0, false, current_pos - 1, 0, "Index=" .. idx_str, -1, 0)
                    end

                    -- Auto-place unique ID= marker 1 second before entry
                    if auto_id_enabled then
                        reaper.AddProjectMarker2(0, false, current_pos - 1, 0, "ID=" .. generateID(), -1, 0)
                    end
                    
                    -- Create items for each mapping that has create_item enabled
                    for _, m in ipairs(mappings) do
                        local val = values[m.name]
                        if val and m.create_item and tracks[m.name] then
                            addEmptyItemWithNote(tracks[m.name], current_pos - 1, region_length + 1, val)
                        end
                        -- Create/ensure track named after cell value
                        if val and val ~= "" and m.create_track then
                            getOrCreateTrack(val)
                        end
                    end
                    
                    -- [E] role always creates entry regions; Tag R controls prefix
                    local region_name = safeRegionName(entry_value)
                    if region_name then
                        local final_name = entry_mapping.prefix_region and ("Entry=" .. region_name) or region_name
                        local region_color = use_group_colors and group_color_map[current_group] or 0
                        local region_id = reaper.AddProjectMarker2(0, true, current_pos, current_pos + region_length, final_name, -1, region_color)
                    end
                    
                    current_pos = current_pos + region_length + region_gap
                end
            end
        end
    end

    -- [C] role always creates category regions; Tag R controls prefix
    if category_mapping then
        if current_group ~= "" and current_group_start then
            group_regions[current_group] = {
                start = current_group_start,
                end_pos = current_pos - region_gap
            }
        end

        for group_name, region_data in pairs(group_regions) do
            local region_name = category_mapping.prefix_region and ("Category=" .. group_name) or group_name
            local grp_color = use_group_colors and group_color_map[group_name] or reaper.ColorToNative(0, 255, 0)|0x1000000
            local region_id = reaper.AddProjectMarker2(0, true, region_data.start, region_data.end_pos, region_name, -1, grp_color)
        end
    end

    reaper.Undo_EndBlock("Import CSV as Regions", -1)
    reaper.UpdateArrange()
    return true
end

-- ============================================================================
-- GUI SETUP
-- ============================================================================

-- Load saved column mappings
local function loadColumnMappings()
    local saved = reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "column_mappings_v3")
    if saved and saved ~= "" then
        local mappings = {}
        -- New format includes is_name, is_group, is_character/is_speaker, and track flags
        for entry in saved:gmatch("([^|]+)") do
            local name, col, marker, region, item, pfx_m, pfx_r, is_name, is_group, is_character, track = entry:match("([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):?([^:]*):?([^:]*)")
            if name then
                local row_num = #mappings + 1
                if is_name == "1" then
                    entry_row = row_num
                end
                if is_group == "1" then
                    category_row = row_num
                end
                if is_character == "1" then
                    speaker_row = row_num
                end
                table.insert(mappings, {
                    name = name,
                    col = tonumber(col) or 1,
                    create_marker = marker == "1",
                    create_region = region == "1",
                    create_item   = item == "1",
                    prefix_marker = pfx_m == "1",
                    prefix_region = pfx_r == "1",
                    create_track  = track == "1",
                })
            end
        end
        if #mappings > 0 then
            return mappings
        end
    end
    
    -- Try loading old v2 format for backward compatibility
    local saved_v2 = reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "column_mappings_v2")
    if saved_v2 and saved_v2 ~= "" then
        local mappings = {}
        for entry in saved_v2:gmatch("([^|]+)") do
            local name, col, marker, region, item, pfx_m, pfx_r = entry:match("([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+)")
            if name then
                local row_num = #mappings + 1
                local name_lower = name:lower()
                -- Auto-detect roles based on old naming convention
                if name_lower == "category" or name_lower == "group" or name_lower == "scene" then
                    category_row = row_num
                elseif name_lower == "entry" or name_lower == "variation" or name_lower == "name" or name_lower == "line" or name_lower == "dialogue" then
                    entry_row = row_num
                end
                table.insert(mappings, {
                    name = name,
                    col = tonumber(col) or 1,
                    create_marker = marker == "1",
                    create_region = region == "1",
                    create_item = item == "1",
                    prefix_marker = pfx_m == "1",
                    prefix_region = pfx_r == "1"
                })
            end
        end
        if #mappings > 0 then
            return mappings
        end
    end
    
    -- Default mappings with roles set
    entry_row = 2     -- "Entry" column is the entry source
    category_row = 1  -- "Category" column is the grouping column
    return {
        {name = "Category", col = 1, create_marker = true, create_region = true, create_item = false, prefix_marker = true, prefix_region = true},
        {name = "Entry", col = 2, create_marker = false, create_region = true, create_item = false, prefix_marker = false, prefix_region = false}
    }
end

local function saveColumnMappings()
    local parts = {}
    for i = 1, active_rows do
        local name = GUI.Val("txt_name_" .. i) or ""
        local col = GUI.Val("txt_col_" .. i) or "1"
        
        local marker = chkBool(GUI.Val("chk_marker_"     .. i)) and "1" or "0"
        local region = chkBool(GUI.Val("chk_region_"     .. i)) and "1" or "0"
        local item   = chkBool(GUI.Val("chk_item_"       .. i)) and "1" or "0"
        local pfx_m  = chkBool(GUI.Val("chk_pfx_marker_" .. i)) and "1" or "0"
        local pfx_r  = chkBool(GUI.Val("chk_pfx_region_" .. i)) and "1" or "0"
        local trk    = chkBool(GUI.Val("chk_track_"      .. i)) and "1" or "0"

        local is_name    = (i == entry_row)    and "1" or "0"
        local is_group   = (i == category_row) and "1" or "0"
        local is_speaker = (i == speaker_row)  and "1" or "0"

        if name ~= "" then
            table.insert(parts, name .. ":" .. col .. ":" .. marker .. ":" .. region .. ":" .. item .. ":" .. pfx_m .. ":" .. pfx_r .. ":" .. is_name .. ":" .. is_group .. ":" .. is_speaker .. ":" .. trk)
        end
    end
    reaper.SetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "column_mappings_v3", table.concat(parts, "|"), true)
end

local function loadSettings()
    local s = {}
    s.url = reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "last_url")
    s.start_row = reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "start_row")
    s.insert_at_cursor = reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "insert_at_cursor")
    
    if s.url == "" then s.url = "" end
    if s.start_row == "" then s.start_row = "2" end
    if s.insert_at_cursor == "" then s.insert_at_cursor = "0" end
    
    return s
end

local function saveSettings()
    reaper.SetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "last_url", GUI.Val("txt_url") or "", true)
    reaper.SetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "start_row", GUI.Val("txt_startrow") or "2", true)
    
    local cursor_val = chkBool(GUI.Val("chk_cursor")) and "1" or "0"
    reaper.SetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "insert_at_cursor", cursor_val, true)
    
    saveColumnMappings()
end

local settings = loadSettings()
column_mappings = loadColumnMappings()
active_rows = #column_mappings

-- Calculate dynamic window height
local function getWindowHeight()
    return 280 + (active_rows * ROW_HEIGHT)
end

-- GUI Window
GUI.name = "CSV Import to Regions"
-- Tall enough to show Import/Cancel buttons below all sections (btn_y ≈ 852+).
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 620, 960
GUI.anchor, GUI.corner = "screen", "C"

-- Hide Lokasenna GUI version text
GUI.version = false

-- ============================================================================
-- GUI ELEMENTS
-- ============================================================================

-- Header cover: opaque background at z=10 to block scrolled z=11/12 content from
-- bleeding into the tab area.  Title + tab buttons live at z=9 (drawn last = on top).
GUI.New("frame_header_cover", "Frame", {
    z = 10, x = 0, y = 0, w = 620, h = CONTENT_START_Y,
    shadow = false, fill = true, color = "wnd_bg", round = 0
})

-- Title (z=9 — drawn on top of the cover at z=10)
GUI.New("lbl_title", "Label", {
    z = 9, x = 20, y = 14,
    caption = "CSV to Regions & Markers",
    font = 3, color = "txt", bg = "wnd_bg"
})

-- ─────────────────────────────────────────────────────────────────────────────
-- TAB BAR
-- ─────────────────────────────────────────────────────────────────────────────

local tab_width = 134
local tab_start_x = 20

for i, tab_name in ipairs(TABS) do
    local tab_idx = i  -- Capture for closure
    GUI.New("btn_tab_" .. i, "Button", {
        z = 9, 
        x = tab_start_x + (i - 1) * (tab_width + 4), 
        y = TAB_BAR_Y, 
        w = tab_width, 
        h = TAB_HEIGHT,
        caption = tab_name, 
        font = 3,
        col_txt = i == 1 and "wnd_bg" or "txt", 
        col_fill = i == 1 and "elm_fill" or "tab_bg",
        func = function()
            switchToTab(tab_idx)
        end
    })
end

-- Tab bar underline/frame (z=9 — on top of header cover at z=10)
GUI.New("frame_tab_bar", "Frame", {
    z = 9, x = 20, y = TAB_BAR_Y + TAB_HEIGHT, w = 580, h = 2,
    shadow = false, fill = true, color = "elm_frame", round = 0
})

-- ─────────────────────────────────────────────────────────────────────────────
-- SOURCE SECTION (Import Tab)
-- ─────────────────────────────────────────────────────────────────────────────

local source_y = CONTENT_START_Y

GUI.New("frame_source", "Frame", {
    z = 12, x = 20, y = source_y, w = 580, h = 88,
    shadow = false, fill = false, color = "elm_frame", round = 0
})
registerTabElement("Import", "frame_source")

GUI.New("lbl_source", "Label", {
    z = 11, x = 32, y = source_y + 10,
    caption = " CSV Source (URL or file path) ",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_source")

GUI.New("txt_url", "Textbox", {
    z = 11, x = 36, y = source_y + 28, w = 450, h = 24,
    caption = "", cap_pos = "left",
    font_a = 3, font_b = 5,
    color = "txt", bg = "wnd_bg",
    shadow = true, pad = 4
})
registerTabElement("Import", "txt_url")

GUI.New("btn_browse", "Button", {
    z = 11, x = 494, y = source_y + 26, w = 84, h = 28,
    caption = "Browse", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = function()
        local last_path = reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "last_file_path") or ""
        local ret, file = reaper.GetUserFileNameForRead(last_path, "Select CSV File", "*.csv")
        if ret and file then
            reaper.SetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "last_file_path", file, true)
            GUI.Val("txt_url", file)
        end
    end
})
registerTabElement("Import", "btn_browse")

-- Shared helper that runs the import from whatever is currently in txt_url
-- forward-declared so btn_browse_import and btn_import can reference it;
-- implemented below after getCSVAndMappings is defined
local runImport

GUI.New("btn_browse_import", "Button", {
    z = 11, x = 494, y = source_y + 56, w = 84, h = 24,
    caption = "Open CSV file", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = function()
        local last_path = reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "last_file_path") or ""
        local ret, file = reaper.GetUserFileNameForRead(last_path, "Select CSV File", "*.csv")
        if ret and file then
            reaper.SetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "last_file_path", file, true)
            GUI.Val("txt_url", file)
        end
    end
})
registerTabElement("Import", "btn_browse_import")

GUI.New("lbl_hint_source", "Label", {
    z = 11, x = 36, y = source_y + 56,
    caption = "Auto-detects Google Sheets URL or local file path",
    font = 4, color = "shadow", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_hint_source")

-- ─────────────────────────────────────────────────────────────────────────────
-- COLUMN MAPPINGS SECTION (Import Tab)
-- ─────────────────────────────────────────────────────────────────────────────

local columns_y = source_y + 90
-- Enough height for header + MAX_COLUMNS rows + Add button + a bit of breathing room
local columns_h = 70 + (MAX_COLUMNS * ROW_HEIGHT) + 40

GUI.New("frame_columns", "Frame", {
    z = 12, x = 20, y = columns_y, w = 580, h = columns_h,
    shadow = false, fill = false, color = "elm_frame", round = 0
})
registerTabElement("Import", "frame_columns")

GUI.New("lbl_columns", "Label", {
    z = 11, x = 32, y = columns_y + 10,
    caption = " Column Mappings ",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_columns")

-- Description (italic)
GUI.New("lbl_columns_desc", "Label", {
    z = 11, x = 36, y = columns_y + 16,
    caption = "Map CSV columns. [E]=Entry, [C]=Category",
    font = 4, color = "shadow", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_columns_desc")

-- Auto Suggest button (reads CSV headers) - positioned at top right of frame
GUI.New("btn_auto_suggest", "Button", {
    z = 11, x = 460, y = columns_y + 12, w = 120, h = 22,
    caption = "Auto Suggest", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = autoSuggestFromCSV
})
registerTabElement("Import", "btn_auto_suggest")

-- Header row - positions must match the row elements below
local hdr_y = columns_y + 38
GUI.New("lbl_hdr_name", "Label", {z = 11, x = 36, y = hdr_y, caption = "Name", font = 4, color = "txt", bg = "wnd_bg"})
GUI.New("lbl_hdr_col", "Label", {z = 11, x = 120, y = hdr_y, caption = "Col", font = 4, color = "txt", bg = "wnd_bg"})
GUI.New("lbl_hdr_role", "Label", {z = 11, x = 155, y = hdr_y, caption = "Role", font = 4, color = "txt", bg = "wnd_bg"})
GUI.New("lbl_hdr_marker", "Label", {z = 11, x = 220, y = hdr_y, caption = "Marker", font = 4, color = "txt", bg = "wnd_bg"})
GUI.New("lbl_hdr_region", "Label", {z = 11, x = 290, y = hdr_y, caption = "Region", font = 4, color = "txt", bg = "wnd_bg"})
GUI.New("lbl_hdr_item", "Label", {z = 11, x = 360, y = hdr_y, caption = "Item", font = 4, color = "txt", bg = "wnd_bg"})
GUI.New("lbl_hdr_pfxm", "Label", {z = 11, x = 415, y = hdr_y, caption = "Pfx:M", font = 4, color = "txt", bg = "wnd_bg"})
GUI.New("lbl_hdr_pfxr", "Label", {z = 11, x = 480, y = hdr_y, caption = "Pfx:R", font = 4, color = "txt", bg = "wnd_bg"})
registerTabElement("Import", "lbl_hdr_name")
registerTabElement("Import", "lbl_hdr_col")
registerTabElement("Import", "lbl_hdr_role")
registerTabElement("Import", "lbl_hdr_marker")
registerTabElement("Import", "lbl_hdr_region")
registerTabElement("Import", "lbl_hdr_item")
registerTabElement("Import", "lbl_hdr_pfxm")
registerTabElement("Import", "lbl_hdr_pfxr")

-- IMPORTANT: Start the first data row BELOW the header row (prevents overlap).
-- This fixes the "skewed" look where row 1 appears inside the header area.
ROW_START_Y = hdr_y + 22

-- Create all row elements (hidden by default)
for i = 1, MAX_COLUMNS do
    local y = ROW_START_Y + ((i - 1) * ROW_HEIGHT)
    local row_idx = i  -- Capture for closures
    
    -- Name textbox (header at x=36)
    GUI.New("txt_name_" .. i, "Textbox", {
        z = 11, x = 36, y = y, w = 78, h = 22,
        caption = "", font_a = 3, font_b = 5,
        color = "txt", bg = "wnd_bg",
        shadow = true, pad = 4
    })
    registerTabElement("Import", "txt_name_" .. i)
    
    -- Column number textbox (header at x=120)
    GUI.New("txt_col_" .. i, "Textbox", {
        z = 11, x = 118, y = y, w = 30, h = 22,
        caption = "", font_a = 3, font_b = 5,
        color = "txt", bg = "wnd_bg",
        shadow = true, pad = 4
    })
    registerTabElement("Import", "txt_col_" .. i)
    
    -- Entry toggle button [E] (header "Role" at x=155)
    GUI.New("btn_entry_" .. i, "Button", {
        z = 11, x = 155, y = y, w = 24, h = 22,
        caption = "E", font = 4,
        col_txt = "txt", col_fill = "elm_frame",
        func = function()
            if entry_row == row_idx then
                -- Toggle off
                entry_row = 0
            else
                -- Set this row as entry source
                entry_row = row_idx
            end
            updateRoleButtonAppearances()
            updateRowVisibility()
        end
    })
    registerTabElement("Import", "btn_entry_" .. i)
    
    -- Category toggle button [C]
    GUI.New("btn_category_" .. i, "Button", {
        z = 11, x = 181, y = y, w = 24, h = 22,
        caption = "C", font = 4,
        col_txt = "txt", col_fill = "elm_frame",
        func = function()
            if category_row == row_idx then
                category_row = 0
            else
                category_row = row_idx
            end
            updateRoleButtonAppearances()
            updateRowVisibility()
        end
    })
    registerTabElement("Import", "btn_category_" .. i)

    -- Speaker toggle button [Sp]
    GUI.New("btn_speaker_" .. i, "Button", {
        z = 11, x = 207, y = y, w = 28, h = 22,
        caption = "Sp", font = 4,
        col_txt = "txt", col_fill = "elm_frame",
        func = function()
            if speaker_row == row_idx then
                speaker_row = 0
            else
                speaker_row = row_idx
            end
            updateRoleButtonAppearances()
        end
    })
    registerTabElement("Import", "btn_speaker_" .. i)
    
    -- Marker checkbox (header at x=220, center checkbox under it)
    GUI.New("chk_marker_" .. i, "Checklist", {
        z = 11, x = 232, y = y, w = 24, h = 22,
        caption = "", optarray = {""},
        dir = "h", font_a = 3, font_b = 3,
        col_txt = "txt", col_fill = "elm_fill", bg = "wnd_bg",
        frame = false, shadow = false, opt_size = 18
    })
    registerTabElement("Import", "chk_marker_" .. i)
    
    -- Region checkbox (header at x=290)
    GUI.New("chk_region_" .. i, "Checklist", {
        z = 11, x = 302, y = y, w = 24, h = 22,
        caption = "", optarray = {""},
        dir = "h", font_a = 3, font_b = 3,
        col_txt = "txt", col_fill = "elm_fill", bg = "wnd_bg",
        frame = false, shadow = false, opt_size = 18
    })
    registerTabElement("Import", "chk_region_" .. i)
    
    -- Item checkbox (header at x=360)
    GUI.New("chk_item_" .. i, "Checklist", {
        z = 11, x = 367, y = y, w = 24, h = 22,
        caption = "", optarray = {""},
        dir = "h", font_a = 3, font_b = 3,
        col_txt = "txt", col_fill = "elm_fill", bg = "wnd_bg",
        frame = false, shadow = false, opt_size = 18
    })
    registerTabElement("Import", "chk_item_" .. i)
    
    -- Prefix Marker checkbox (header at x=415)
    GUI.New("chk_pfx_marker_" .. i, "Checklist", {
        z = 11, x = 425, y = y, w = 24, h = 22,
        caption = "", optarray = {""},
        dir = "h", font_a = 3, font_b = 3,
        col_txt = "txt", col_fill = "elm_fill", bg = "wnd_bg",
        frame = false, shadow = false, opt_size = 18
    })
    registerTabElement("Import", "chk_pfx_marker_" .. i)
    
    -- Prefix Region checkbox (header at x=480)
    GUI.New("chk_pfx_region_" .. i, "Checklist", {
        z = 11, x = 490, y = y, w = 24, h = 22,
        caption = "", optarray = {""},
        dir = "h", font_a = 3, font_b = 3,
        col_txt = "txt", col_fill = "elm_fill", bg = "wnd_bg",
        frame = false, shadow = false, opt_size = 18
    })
    registerTabElement("Import", "chk_pfx_region_" .. i)

    -- Track checkbox
    GUI.New("chk_track_" .. i, "Checklist", {
        z = 11, x = 516, y = y, w = 24, h = 22,
        caption = "", optarray = {""},
        dir = "h", font_a = 3, font_b = 3,
        col_txt = "txt", col_fill = "elm_fill", bg = "wnd_bg",
        frame = false, shadow = false, opt_size = 18
    })
    registerTabElement("Import", "chk_track_" .. i)

    -- Remove button
    GUI.New("btn_remove_" .. i, "Button", {
        z = 11, x = 540, y = y, w = 24, h = 22,
        caption = "-", font = 2,
        col_txt = "txt", col_fill = "elm_frame",
        func = function()
            -- Update role indices if removing a row that has a role
            if entry_row == row_idx then
                entry_row = 0
            elseif entry_row > row_idx then
                entry_row = entry_row - 1
            end
            if category_row == row_idx then
                category_row = 0
            elseif category_row > row_idx then
                category_row = category_row - 1
            end
            if speaker_row == row_idx then
                speaker_row = 0
            elseif speaker_row > row_idx then
                speaker_row = speaker_row - 1
            end

            -- Shift all rows up from this position
            for j = row_idx, active_rows - 1 do
                GUI.Val("txt_name_" .. j, GUI.Val("txt_name_" .. (j + 1)))
                GUI.Val("txt_col_" .. j, GUI.Val("txt_col_" .. (j + 1)))
                GUI.Val("chk_marker_" .. j, GUI.Val("chk_marker_" .. (j + 1)))
                GUI.Val("chk_region_" .. j, GUI.Val("chk_region_" .. (j + 1)))
                GUI.Val("chk_item_" .. j, GUI.Val("chk_item_" .. (j + 1)))
                GUI.Val("chk_pfx_marker_" .. j, GUI.Val("chk_pfx_marker_" .. (j + 1)))
                GUI.Val("chk_pfx_region_" .. j, GUI.Val("chk_pfx_region_" .. (j + 1)))
                GUI.Val("chk_track_" .. j, GUI.Val("chk_track_" .. (j + 1)))
            end

            -- Clear the last row
            GUI.Val("txt_name_" .. active_rows, "")
            GUI.Val("txt_col_" .. active_rows, "")
            GUI.Val("chk_marker_" .. active_rows, {false})
            GUI.Val("chk_region_" .. active_rows, {false})
            GUI.Val("chk_item_" .. active_rows, {false})
            GUI.Val("chk_pfx_marker_" .. active_rows, {false})
            GUI.Val("chk_pfx_region_" .. active_rows, {false})
            GUI.Val("chk_track_" .. active_rows, {false})
            
            active_rows = active_rows - 1
            if active_rows < 1 then active_rows = 1 end
            
            -- Update visibility by moving off-screen
            updateRowVisibility()
        end
    })
    registerTabElement("Import", "btn_remove_" .. i)
end

-- Add button - dynamically positioned below the last visible row (inside the frame, right side)
-- Initial position will be updated by updateRowVisibility()
local initial_add_btn_y = ROW_START_Y + 4
GUI.New("btn_add", "Button", {
    z = 11, x = 460, y = initial_add_btn_y, w = 110, h = 24,
    caption = "+ Add Column", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = function()
        if active_rows < MAX_COLUMNS then
            active_rows = active_rows + 1
            
            -- Set defaults for new row (no roles assigned by default)
            GUI.Val("txt_name_" .. active_rows, "")
            GUI.Val("txt_col_" .. active_rows, "")
            GUI.Val("chk_marker_" .. active_rows, {false})
            GUI.Val("chk_region_" .. active_rows, {true})
            GUI.Val("chk_item_" .. active_rows, {false})
            GUI.Val("chk_pfx_marker_" .. active_rows, {true})
            GUI.Val("chk_pfx_region_" .. active_rows, {false})
            GUI.Val("chk_track_" .. active_rows, {false})

            -- Show the new row by moving on-screen
            updateRowVisibility()
        end
    end
})
registerTabElement("Import", "btn_add")

-- Warning label when no Entry column is defined (hidden by default, shown dynamically)
GUI.New("lbl_entry_warning", "Label", {
    z = 11, x = 36, y = HIDDEN_Y,
    caption = "Note: Click [E] to set an Entry column for region names",
    font = 4, color = "txt", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_entry_warning")

-- ─────────────────────────────────────────────────────────────────────────────
-- TIMING & LAYOUT SECTION (Import Tab)
-- ─────────────────────────────────────────────────────────────────────────────

-- Place sections below the Column Mappings frame (stable, no overlap)
local timing_y = columns_y + columns_h + 20

GUI.New("frame_timing", "Frame", {
    z = 12, x = 20, y = timing_y, w = 580, h = 70,
    shadow = false, fill = false, color = "elm_frame", round = 0
})
registerTabElement("Import", "frame_timing")

GUI.New("lbl_timing", "Label", {
    z = 11, x = 32, y = timing_y + 10,
    caption = " Timing & Layout ",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_timing")

-- Row 1: Region Length, Region Gap, Category Gap
GUI.New("lbl_region_len", "Label", {z = 11, x = 36, y = timing_y + 16, caption = "Length:", font = 3, color = "txt", bg = "wnd_bg"})
GUI.New("txt_region_len", "Textbox", {z = 11, x = 90, y = timing_y + 12, w = 36, h = 24, caption = "", font_a = 3, font_b = 5, color = "txt", bg = "wnd_bg", shadow = true, pad = 4})
GUI.New("lbl_region_len_s", "Label", {z = 11, x = 130, y = timing_y + 16, caption = "sec", font = 4, color = "shadow", bg = "wnd_bg"})

GUI.New("lbl_region_gap", "Label", {z = 11, x = 168, y = timing_y + 16, caption = "Gap:", font = 3, color = "txt", bg = "wnd_bg"})
GUI.New("txt_region_gap", "Textbox", {z = 11, x = 200, y = timing_y + 12, w = 36, h = 24, caption = "", font_a = 3, font_b = 5, color = "txt", bg = "wnd_bg", shadow = true, pad = 4})
GUI.New("lbl_region_gap_s", "Label", {z = 11, x = 240, y = timing_y + 16, caption = "sec", font = 4, color = "shadow", bg = "wnd_bg"})

GUI.New("lbl_cat_gap", "Label", {z = 11, x = 275, y = timing_y + 16, caption = "Group Gap:", font = 3, color = "txt", bg = "wnd_bg"})
GUI.New("txt_cat_gap", "Textbox", {z = 11, x = 360, y = timing_y + 12, w = 36, h = 24, caption = "", font_a = 3, font_b = 5, color = "txt", bg = "wnd_bg", shadow = true, pad = 4})
GUI.New("lbl_cat_gap_s", "Label", {z = 11, x = 400, y = timing_y + 16, caption = "sec", font = 4, color = "shadow", bg = "wnd_bg"})

registerTabElement("Import", "lbl_region_len")
registerTabElement("Import", "txt_region_len")
registerTabElement("Import", "lbl_region_len_s")
registerTabElement("Import", "lbl_region_gap")
registerTabElement("Import", "txt_region_gap")
registerTabElement("Import", "lbl_region_gap_s")
registerTabElement("Import", "lbl_cat_gap")
registerTabElement("Import", "txt_cat_gap")
registerTabElement("Import", "lbl_cat_gap_s")

-- Row 2: Color by group (synced with Theme → Region / Marker Colors; hidden in ImGui Import tab)
GUI.New("chk_colors", "Checklist", {
    z = 11, x = 36, y = timing_y + 40, w = 24, h = 22,
    caption = "", optarray = {""},
    dir = "h", font_a = 3, font_b = 3,
    col_txt = "txt", col_fill = "elm_fill", bg = "wnd_bg",
    frame = false, shadow = false, opt_size = 20,
    optsel = { THEME.color_regions ~= false }
})
GUI.New("lbl_colors", "Label", {z = 11, x = 60, y = timing_y + 42, caption = "Color regions by group", font = 3, color = "txt", bg = "wnd_bg"})
registerTabElement("Import", "chk_colors")
registerTabElement("Import", "lbl_colors")

-- ─────────────────────────────────────────────────────────────────────────────
-- OPTIONS SECTION (Import Tab)
-- ─────────────────────────────────────────────────────────────────────────────

local options_y = timing_y + 82

GUI.New("frame_options", "Frame", {
    z = 12, x = 20, y = options_y, w = 580, h = 96,
    shadow = false, fill = false, color = "elm_frame", round = 0
})
registerTabElement("Import", "frame_options")

GUI.New("lbl_options", "Label", {
    z = 11, x = 32, y = options_y + 10,
    caption = " Options ",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_options")

-- Row 1: Start Row and Insert at cursor
GUI.New("lbl_startrow", "Label", {z = 11, x = 36, y = options_y + 16, caption = "Start Row:", font = 3, color = "txt", bg = "wnd_bg"})
GUI.New("txt_startrow", "Textbox", {z = 11, x = 110, y = options_y + 12, w = 36, h = 24, caption = "", font_a = 3, font_b = 5, color = "txt", bg = "wnd_bg", shadow = true, pad = 4})
registerTabElement("Import", "lbl_startrow")
registerTabElement("Import", "txt_startrow")

GUI.New("chk_cursor", "Checklist", {
    z = 11, x = 170, y = options_y + 14, w = 24, h = 22,
    caption = "", optarray = {""},
    dir = "h", font_a = 3, font_b = 3,
    col_txt = "txt", col_fill = "elm_fill", bg = "wnd_bg",
    frame = false, shadow = false, opt_size = 20
})
registerTabElement("Import", "chk_cursor")

GUI.New("lbl_cursor", "Label", {
    z = 11, x = 194, y = options_y + 16,
    caption = "Insert at edit cursor",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_cursor")

-- Row 2: Auto-place Index markers from Entries
GUI.New("chk_auto_index", "Checklist", {
    z = 11, x = 36, y = options_y + 38, w = 24, h = 26,
    caption = "", optarray = {""},
    dir = "h", font_a = 3, font_b = 3,
    col_txt = "txt", col_fill = "elm_fill", bg = "wnd_bg",
    frame = false, shadow = false, opt_size = 20
})
registerTabElement("Import", "chk_auto_index")

GUI.New("lbl_auto_index", "Label", {
    z = 11, x = 60, y = options_y + 42,
    caption = "Automatically place Index markers from Entries",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_auto_index")

-- Row 3 (extra): Auto-place unique ID markers
GUI.New("chk_auto_id", "Checklist", {
    z = 11, x = 36, y = options_y + 64, w = 24, h = 26,
    caption = "", optarray = {""},
    dir = "h", font_a = 3, font_b = 3,
    col_txt = "txt", col_fill = "elm_fill", bg = "wnd_bg",
    frame = false, shadow = false, opt_size = 20
})
registerTabElement("Import", "chk_auto_id")

GUI.New("lbl_auto_id", "Label", {
    z = 11, x = 60, y = options_y + 68,
    caption = "Create unique ID= markers for each entry",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_auto_id")

-- Row 3: Preset with dropdown menu
GUI.New("lbl_preset", "Label", {z = 11, x = 36, y = options_y + 72, caption = "Presets:", font = 3, color = "txt", bg = "wnd_bg"})
registerTabElement("Import", "lbl_preset")

-- Helper function to load a preset by name
local function loadPresetByName(preset_name)
    local preset_data = reaper.GetExtState("DMN_CSVImport_Presets", preset_name)
    
    if preset_data == "" then
        reaper.ShowMessageBox("Preset '" .. preset_name .. "' not found.", "Error", 0)
        return
    end
    
    -- Clear all rows first and reset roles
    entry_row = 0
    category_row = 0
    speaker_row = 0

    for i = 1, MAX_COLUMNS do
        GUI.Val("txt_name_" .. i, "")
        GUI.Val("txt_col_" .. i, "")
        GUI.Val("chk_marker_" .. i, {false})
        GUI.Val("chk_region_" .. i, {false})
        GUI.Val("chk_item_" .. i, {false})
        GUI.Val("chk_pfx_marker_" .. i, {false})
        GUI.Val("chk_pfx_region_" .. i, {false})
        GUI.Val("chk_track_" .. i, {false})
    end

    -- Parse and load preset data (supports both old and new format)
    local row = 0
    for entry in preset_data:gmatch("([^|]+)") do
        row = row + 1
        if row <= MAX_COLUMNS then
            -- Try new format first (with is_name, is_group, is_character, and track)
            local name, col, marker, region, item, pfx_m, pfx_r, is_name, is_group, is_character, track = entry:match("([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):?([^:]*):?([^:]*)")

            if not name then
                -- Fall back to old 7-field format
                name, col, marker, region, item, pfx_m, pfx_r = entry:match("([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+)")
                is_name = nil; is_group = nil; is_character = nil; track = nil
            end

            if name then
                GUI.Val("txt_name_" .. row, name)
                GUI.Val("txt_col_" .. row, col)
                GUI.Val("chk_marker_" .. row, {marker == "1"})
                GUI.Val("chk_region_" .. row, {region == "1"})
                GUI.Val("chk_item_" .. row, {item == "1"})
                GUI.Val("chk_pfx_marker_" .. row, {pfx_m == "1"})
                GUI.Val("chk_pfx_region_" .. row, {pfx_r == "1"})
                GUI.Val("chk_track_" .. row, {track == "1"})

                -- Handle role flags
                if is_name == "1" then
                    entry_row = row
                elseif not is_name then
                    local name_lower = name:lower()
                    if name_lower == "entry" or name_lower == "variation" or name_lower == "name" or name_lower == "line" or name_lower == "dialogue" then
                        entry_row = row
                    end
                end

                if is_group == "1" then
                    category_row = row
                elseif not is_group then
                    local name_lower = name:lower()
                    if name_lower == "category" or name_lower == "group" or name_lower == "scene" or name_lower == "parent" then
                        category_row = row
                    end
                end

                if is_character == "1" then
                    speaker_row = row
                elseif not is_character then
                    local name_lower = name:lower()
                    if name_lower == "speaker" or name_lower == "character" or name_lower == "actor" or name_lower == "voice" or name_lower == "narrator" then
                        speaker_row = row
                    end
                end
            end
        end
    end
    
    active_rows = row
    if active_rows < 1 then active_rows = 1 end
    if active_rows > MAX_COLUMNS then active_rows = MAX_COLUMNS end
    
    updateRowVisibility()
end

-- Load Preset button with dropdown menu
GUI.New("btn_load_preset", "Button", {
    z = 11, x = 100, y = options_y + 68, w = 120, h = 24,
    caption = "Load Preset...", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = function()
        local presets = getPresetList()
        if #presets == 0 then
            reaper.ShowMessageBox("No presets saved yet.\n\nUse 'Save As...' to create a preset.", "Load Preset", 0)
            return
        end
        
        -- Build menu string
        local menu_str = table.concat(presets, "|")
        gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
        local result = gfx.showmenu(menu_str)
        
        if result > 0 then
            local preset_name = presets[result]
            loadPresetByName(preset_name)
        end
    end
})
registerTabElement("Import", "btn_load_preset")

-- Save As button
GUI.New("btn_save_preset", "Button", {
    z = 11, x = 228, y = options_y + 68, w = 100, h = 24,
    caption = "Save As...", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = function()
        local retval, preset_name = reaper.GetUserInputs("Save Preset", 1, "Preset Name:,extrawidth=100", "")
        if not retval or preset_name == "" then return end
        
        -- Build preset data from current GUI state (new format with role flags)
        local parts = {}
        for i = 1, active_rows do
            local name = GUI.Val("txt_name_" .. i) or ""
            local col = GUI.Val("txt_col_" .. i) or "1"
            local marker = chkBool(GUI.Val("chk_marker_"     .. i)) and "1" or "0"
            local region = chkBool(GUI.Val("chk_region_"     .. i)) and "1" or "0"
            local item   = chkBool(GUI.Val("chk_item_"       .. i)) and "1" or "0"
            local pfx_m  = chkBool(GUI.Val("chk_pfx_marker_" .. i)) and "1" or "0"
            local pfx_r  = chkBool(GUI.Val("chk_pfx_region_" .. i)) and "1" or "0"
            local trk    = chkBool(GUI.Val("chk_track_"      .. i)) and "1" or "0"

            local is_name    = (i == entry_row)    and "1" or "0"
            local is_group   = (i == category_row) and "1" or "0"
            local is_speaker = (i == speaker_row)  and "1" or "0"

            if name ~= "" then
                table.insert(parts, name .. ":" .. col .. ":" .. marker .. ":" .. region .. ":" .. item .. ":" .. pfx_m .. ":" .. pfx_r .. ":" .. is_name .. ":" .. is_group .. ":" .. is_speaker .. ":" .. trk)
            end
        end
        
        local preset_data = table.concat(parts, "|")
        reaper.SetExtState("DMN_CSVImport_Presets", preset_name, preset_data, true)
        
        -- Update preset list
        local preset_list = reaper.GetExtState("DMN_CSVImport_Presets", "_preset_list") or ""
        if not preset_list:find(preset_name, 1, true) then
            if preset_list ~= "" then
                preset_list = preset_list .. "|" .. preset_name
            else
                preset_list = preset_name
            end
            reaper.SetExtState("DMN_CSVImport_Presets", "_preset_list", preset_list, true)
        end
        
        reaper.ShowMessageBox("Preset '" .. preset_name .. "' saved!", "Save Preset", 0)
    end
})
registerTabElement("Import", "btn_save_preset")

-- Delete Preset button with dropdown menu
GUI.New("btn_delete_preset", "Button", {
    z = 11, x = 360, y = options_y + 68, w = 120, h = 24,
    caption = "Delete Preset...", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = function()
        local presets = getPresetList()
        if #presets == 0 then
            reaper.ShowMessageBox("No presets to delete.", "Delete Preset", 0)
            return
        end
        
        -- Build menu string
        local menu_str = table.concat(presets, "|")
        gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
        local result = gfx.showmenu(menu_str)
        
        if result > 0 then
            local preset_name = presets[result]
            local confirm = reaper.ShowMessageBox("Delete preset '" .. preset_name .. "'?", "Confirm Delete", 4)
            
            if confirm == 6 then -- Yes
                -- Delete the preset
                reaper.DeleteExtState("DMN_CSVImport_Presets", preset_name, true)
                
                -- Update preset list
                local preset_list = reaper.GetExtState("DMN_CSVImport_Presets", "_preset_list") or ""
                local new_list = {}
                for name in preset_list:gmatch("([^|]+)") do
                    if name ~= preset_name then
                        table.insert(new_list, name)
                    end
                end
                reaper.SetExtState("DMN_CSVImport_Presets", "_preset_list", table.concat(new_list, "|"), true)
            end
        end
    end
})
registerTabElement("Import", "btn_delete_preset")

-- ─────────────────────────────────────────────────────────────────────────────
-- HELP SECTION (Import Tab)
-- ─────────────────────────────────────────────────────────────────────────────

local help_y = options_y + 106

GUI.New("frame_help", "Frame", {
    z = 12, x = 20, y = help_y, w = 580, h = 80,
    shadow = false, fill = false, color = "elm_frame", round = 0
})
registerTabElement("Import", "frame_help")

GUI.New("lbl_help_title", "Label", {
    z = 11, x = 32, y = help_y + 10,
    caption = " How to Use ",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_help_title")

GUI.New("lbl_help_1", "Label", {
    z = 11, x = 36, y = help_y + 12,
    caption = "1. Enter a Google Sheets CSV URL or browse for a local CSV file.",
    font = 4, color = "shadow", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_help_1")

GUI.New("lbl_help_2", "Label", {
    z = 11, x = 36, y = help_y + 28,
    caption = "2. Map columns: set name, column number, and what to create (marker/region/item).",
    font = 4, color = "shadow", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_help_2")

GUI.New("lbl_help_3", "Label", {
    z = 11, x = 36, y = help_y + 44,
    caption = "3. Set roles: [E] = Entry (region names), [C] = Category (grouping).",
    font = 4, color = "shadow", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_help_3")

GUI.New("lbl_help_4", "Label", {
    z = 11, x = 36, y = help_y + 60,
    caption = "Tip: Both [E] and [C] can be on same column. Use Auto Suggest for quick setup.",
    font = 4, color = "shadow", bg = "wnd_bg"
})
registerTabElement("Import", "lbl_help_4")

-- ─────────────────────────────────────────────────────────────────────────────
-- ACTION BUTTONS (Import Tab)
-- ─────────────────────────────────────────────────────────────────────────────

local btn_y = help_y + 92

-- Helper function to get CSV content and mappings
local function getCSVAndMappings()
    local source = GUI.Val("txt_url") or ""
    
    if source == "" then
        reaper.ShowMessageBox("Please enter a URL or file path.", "Error", 0)
        return nil, nil
    end
    
    local csv_content = nil
    
    if source:match("^https?://") then
        csv_content = downloadCSV(source)
        if not csv_content or csv_content == "" then
            reaper.ShowMessageBox("Failed to download CSV from URL.\n\nMake sure the URL is a published Google Sheets CSV link.", "Error", 0)
            return nil, nil
        end
    else
        csv_content = readLocalCSV(source)
        if not csv_content or csv_content == "" then
            reaper.ShowMessageBox("Failed to read file:\n" .. source, "Error", 0)
            return nil, nil
        end
    end
    
    -- Build mappings from GUI
    local mappings = {}
    for i = 1, active_rows do
        local name = GUI.Val("txt_name_" .. i) or ""
        local col = tonumber(GUI.Val("txt_col_" .. i)) or 0
        
        if name ~= "" and col > 0 then
            table.insert(mappings, {
                name = name,
                col = col,
                create_marker  = chkBool(GUI.Val("chk_marker_"     .. i)),
                create_region  = chkBool(GUI.Val("chk_region_"     .. i)),
                create_item    = chkBool(GUI.Val("chk_item_"       .. i)),
                prefix_marker  = chkBool(GUI.Val("chk_pfx_marker_" .. i)),
                prefix_region  = chkBool(GUI.Val("chk_pfx_region_" .. i)),
                create_track   = chkBool(GUI.Val("chk_track_"      .. i)),
            })
        end
    end
    
    if #mappings == 0 then
        reaper.ShowMessageBox("Please add at least one column mapping.", "Error", 0)
        return nil, nil
    end
    
    return csv_content, mappings
end

-- Implement the forward-declared runImport now that getCSVAndMappings is in scope
runImport = function()
    saveSettings()
    local csv_content, mappings = getCSVAndMappings()
    if not csv_content then return end
    local insert_cursor = chkBool(GUI.Val("chk_cursor"))
    local auto_index_enabled = chkBool(GUI.Val("chk_auto_index"))
    local auto_id_enabled = chkBool(GUI.Val("chk_auto_id"))
    local start_row = tonumber(GUI.Val("txt_startrow")) or 2
    local timing_opts = {
        region_length = tonumber(GUI.Val("txt_region_len")) or 10,
        region_gap    = tonumber(GUI.Val("txt_region_gap")) or 5,
        category_gap  = tonumber(GUI.Val("txt_cat_gap"))    or 30,
    }
    local color_opts = { use_colors = THEME.color_regions ~= false }
    doImport(csv_content, mappings, start_row, insert_cursor, auto_index_enabled, auto_id_enabled, timing_opts, color_opts, entry_row, category_row, speaker_row)
end

-- Import button
GUI.New("btn_import", "Button", {
    z = 11, x = 390, y = btn_y, w = 100, h = 28,
    caption = "Import", font = 2,
    col_txt = "txt", col_fill = "elm_fill",
    func = runImport
})
registerTabElement("Import", "btn_import")

GUI.New("btn_cancel", "Button", {
    z = 11, x = 500, y = btn_y, w = 100, h = 28,
    caption = "Cancel", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = function()
        GUI.quit = true
    end
})
registerTabElement("Import", "btn_cancel")

-- ─────────────────────────────────────────────────────────────────────────────
-- RECORD TAB
-- ─────────────────────────────────────────────────────────────────────────────

local record_y = CONTENT_START_Y

GUI.New("frame_record_web", "Frame", {
    z = 12, x = 20, y = record_y, w = 580, h = 160,
    shadow = false, fill = false, color = "elm_frame", round = 0
})
registerTabElement("Record", "frame_record_web")

GUI.New("lbl_record_web", "Label", {
    z = 11, x = 32, y = record_y + 10,
    caption = " Record Web Interface ",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Record", "lbl_record_web")

GUI.New("lbl_record_web_desc", "Label", {
    z = 11, x = 36, y = record_y + 28,
    caption = "Uses REAPER's built-in web server to host DMN_ActorTeleprompter.html",
    font = 4, color = "shadow", bg = "wnd_bg"
})
registerTabElement("Record", "lbl_record_web_desc")

GUI.New("lbl_record_port", "Label", {
    z = 11, x = 36, y = record_y + 54,
    caption = "Port:",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Record", "lbl_record_port")

GUI.New("txt_record_port", "Textbox", {
    z = 11, x = 80, y = record_y + 50, w = 60, h = 24,
    caption = "", font_a = 3, font_b = 5,
    color = "txt", bg = "wnd_bg",
    shadow = true, pad = 4
})
registerTabElement("Record", "txt_record_port")

GUI.New("lbl_record_url", "Label", {
    z = 11, x = 150, y = record_y + 54,
    caption = "URL: http://localhost:<port>/DMN_ActorTeleprompter.html",
    font = 4, color = "shadow", bg = "wnd_bg"
})
registerTabElement("Record", "lbl_record_url")

GUI.New("btn_record_install", "Button", {
    z = 11, x = 36, y = record_y + 76, w = 260, h = 22,
    caption = "1) Install/Update Web UI in REAPER", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = function()
        local webroot = getReaperWebRootDir()
        ensureDir(webroot)

        local src_html, src_logo = findRecordWebUIFiles()
        if not src_html then
            reaper.ShowMessageBox(
                "Couldn't find DMN_ActorTeleprompter.html next to this script.\n\n" ..
                "Expected one of:\n" ..
                "- <script folder>\\DMN_ActorTeleprompter.html\n" ..
                "- <script folder>\\reaper_www_root\\DMN_ActorTeleprompter.html",
                "Missing file",
                0
            )
            return
        end

        -- Always install as DMN_ActorTeleprompter.html
        local dst_html = joinPath(webroot, "DMN_ActorTeleprompter.html")
        local dst_logo = joinPath(webroot, "Logo.png")

        if fileExists(dst_html) then
            local resp = reaper.ShowMessageBox(
                "DMN_ActorTeleprompter.html already exists in:\n" .. webroot .. "\n\nOverwrite it?",
                "Overwrite?",
                4
            )
            if resp ~= 6 then return end
        end

        local ok, err = copyFile(src_html, dst_html)
        if not ok then
            reaper.ShowMessageBox(tostring(err), "Install failed", 0)
            return
        end

        -- Copy logo if we can find one (optional)
        if src_logo then
            copyFile(src_logo, dst_logo)
        end

        reaper.ShowMessageBox(
            "Installed:\n" .. dst_html .. "\n\n" ..
            "Next:\nOpen Preferences and enable the web server (Control/OSC/web), then open the URL.",
            "Installed",
            0
        )
    end
})
registerTabElement("Record", "btn_record_install")

GUI.New("btn_record_prefs", "Button", {
    z = 11, x = 306, y = record_y + 76, w = 270, h = 22,
    caption = "Open Web/OSC Preferences", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = function()
        -- 40016 = Show REAPER Preferences
        reaper.Main_OnCommand(40016, 0)
        reaper.ShowMessageBox(
            "In Preferences, go to:\nControl/OSC/web\n\nEnable the web server and set the port to match the value in this tab.",
            "Enable Web Interface",
            0
        )
    end
})
registerTabElement("Record", "btn_record_prefs")

GUI.New("btn_record_open_browser", "Button", {
    z = 11, x = 36, y = record_y + 104, w = 260, h = 22,
    caption = "2) Open Web UI in Browser", font = 3,
    col_txt = "txt", col_fill = "elm_fill",
    func = function()
        local port = tonumber(GUI.Val("txt_record_port")) or 8080
        openURL("http://localhost:" .. tostring(port) .. "/DMN_ActorTeleprompter.html")
    end
})
registerTabElement("Record", "btn_record_open_browser")

GUI.New("btn_record_show_webroot", "Button", {
    z = 11, x = 306, y = record_y + 104, w = 270, h = 22,
    caption = "Show REAPER Web Root Path", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = function()
        reaper.ShowMessageBox(getReaperWebRootDir(), "REAPER reaper_www_root", 0)
    end
})
registerTabElement("Record", "btn_record_show_webroot")

-- Recording Tools (Sketch) removed — placeholder buttons had no functionality.

-- ─────────────────────────────────────────────────────────────────────────────
-- EDIT TAB (Reorganized - clean stacked layout)
-- ─────────────────────────────────────────────────────────────────────────────

local edit_y = CONTENT_START_Y

-- Section 0: EXTERNAL TOOLS + global Time selection only
local tools_sec_y = edit_y
GUI.New("frame_edit_tools", "Frame", {
    z = 12, x = 20, y = tools_sec_y, w = 580, h = 104,
    shadow = false, fill = false, color = "elm_frame", round = 0
})
registerTabElement("Edit", "frame_edit_tools")

GUI.New("lbl_edit_tools", "Label", {
    z = 11, x = 32, y = tools_sec_y + 10,
    caption = " Edit options ",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_tools")

-- One global "Time selection only" for all actions (Create ID, Sync Index, Index rename, Clean Up)
GUI.New("chk_edit_timesel_global", "Checklist", {
    z = 11, x = 36, y = tools_sec_y + 10, w = 24, h = 20,
    caption = "", optarray = {""},
    dir = "h", font_a = 3, font_b = 3,
    col_txt = "txt", col_fill = "elm_fill", bg = "wnd_bg",
    frame = false, shadow = false, opt_size = 20,
    optsel = {false}
})
registerTabElement("Edit", "chk_edit_timesel_global")
-- Label on own row at left margin so it never clips (full width available)
GUI.New("lbl_edit_timesel_global", "Label", {
    z = 11, x = 36, y = tools_sec_y + 34,
    caption = "Time selection only (applies to actions below)",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_timesel_global")

GUI.New("btn_edit_handcomp", "Button", {
    z = 11, x = 36, y = tools_sec_y + 56, w = 200, h = 22,
    caption = "Hand Compression Tool", font = 3,
    col_txt = "wnd_bg", col_fill = "elm_fill",
    func = function()
        launchExternalTool("HandCompTool")
    end
})
registerTabElement("Edit", "btn_edit_handcomp")

GUI.New("lbl_edit_handcomp_desc", "Label", {
    z = 11, x = 36, y = tools_sec_y + 82,
    caption = "Automated volume riding for dialogue.",
    font = 3, color = "shadow", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_handcomp_desc")

-- Utilities (Index Marker rename moved here from below)
local utils_sec_y = tools_sec_y + 108
GUI.New("frame_edit_utils", "Frame", {
    z = 12, x = 20, y = utils_sec_y, w = 580, h = 96,
    shadow = false, fill = false, color = "elm_frame", round = 0
})
registerTabElement("Edit", "frame_edit_utils")

GUI.New("lbl_edit_utils", "Label", {
    z = 11, x = 32, y = utils_sec_y + 10,
    caption = " Utilities ",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_utils")

GUI.New("btn_edit_snap_items", "Button", {
    z = 11, x = 36, y = utils_sec_y + 14, w = 280, h = 22,
    caption = "Snap items to nearest region", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = snapSelectedItemsToNearestRegionStart
})
registerTabElement("Edit", "btn_edit_snap_items")

GUI.New("btn_edit_marker_from_region", "Button", {
    z = 11, x = 326, y = utils_sec_y + 14, w = 254, h = 22,
    caption = "Marker from region name", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = createOrMoveMarkersFromRegionNamesInTimeSelection
})
registerTabElement("Edit", "btn_edit_marker_from_region")

GUI.New("btn_edit_dup_regions", "Button", {
    z = 11, x = 36, y = utils_sec_y + 40, w = 280, h = 22,
    caption = "Find duplicate regions", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = markDuplicateRegionsByName
})
registerTabElement("Edit", "btn_edit_dup_regions")

GUI.New("btn_edit_dup_index", "Button", {
    z = 11, x = 326, y = utils_sec_y + 40, w = 254, h = 22,
    caption = "Detect duplicate Index markers", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = detectDuplicateIndexMarkersAndSelectItems
})
registerTabElement("Edit", "btn_edit_dup_index")

-- Index Markers (Rename) - clear gap below Utilities buttons to avoid overlap
local index_sec_y = utils_sec_y + 80
GUI.New("frame_edit_index", "Frame", {
    z = 12, x = 20, y = index_sec_y, w = 580, h = 82,
    shadow = false, fill = false, color = "elm_frame", round = 0
})
registerTabElement("Edit", "frame_edit_index")

GUI.New("lbl_edit_index", "Label", {
    z = 11, x = 32, y = index_sec_y + 10,
    caption = " Index Markers (Rename) ",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_index")

GUI.New("lbl_edit_index_filter", "Label", {
    z = 11, x = 36, y = index_sec_y + 28,
    caption = "Filter:",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_index_filter")

GUI.New("txt_edit_index_filter", "Textbox", {
    z = 11, x = 92, y = index_sec_y + 24, w = 120, h = 22,
    caption = "", font_a = 3, font_b = 5,
    color = "txt", bg = "wnd_bg",
    shadow = true, pad = 4
})
registerTabElement("Edit", "txt_edit_index_filter")

GUI.New("lbl_edit_index_prefix", "Label", {
    z = 11, x = 228, y = index_sec_y + 28,
    caption = "Prefix:",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_index_prefix")

GUI.New("txt_edit_index_prefix", "Textbox", {
    z = 11, x = 282, y = index_sec_y + 24, w = 80, h = 22,
    caption = "", font_a = 3, font_b = 5,
    color = "txt", bg = "wnd_bg",
    shadow = true, pad = 4
})
registerTabElement("Edit", "txt_edit_index_prefix")

GUI.New("btn_edit_index_rename", "Button", {
    z = 11, x = 36, y = index_sec_y + 54, w = 260, h = 22,
    caption = "Rename: suffix → Index", font = 3,
    col_txt = "txt", col_fill = "elm_fill",
    func = function()
        local filter_contains = GUI.Val("txt_edit_index_filter") or ""
        local prefix = GUI.Val("txt_edit_index_prefix") or "Index="
        if prefix == "" then prefix = "Index=" end

        local ts_only = chkBool(GUI.Val("chk_edit_timesel_global"))

        if ts_only then
            local ts_start, ts_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
            if ts_start == ts_end then
                reaper.ShowMessageBox("No time selection set.", "Index rename", 0)
                return
            end
        end

        reaper.Undo_BeginBlock()
        local res = renameMarkersToIndexFromName({
            filter_contains = filter_contains,
            index_prefix = prefix,
            only_in_time_selection = ts_only,
        })
        reaper.Undo_EndBlock("Rename markers to Index from name suffix", -1)
        reaper.UpdateArrange()

        reaper.ShowMessageBox(
            "Renamed markers: " .. tostring(res.changed) .. "\n\n" ..
            "Skipped (filter): " .. tostring(res.skipped_filter) .. "\n" ..
            "Skipped (already Index): " .. tostring(res.skipped_already_index) .. "\n" ..
            "Skipped (no suffix): " .. tostring(res.skipped_no_suffix) .. "\n" ..
            "Skipped (outside time selection): " .. tostring(res.skipped_outside_time_sel or 0),
            "Index rename",
            0
        )
    end
})
registerTabElement("Edit", "btn_edit_index_rename")

-- Section 4: NOTION ID → INDEX SYNC - below Index Markers
local notion_sec_y = index_sec_y + 98
GUI.New("frame_edit_notion_index", "Frame", {
    z = 12, x = 20, y = notion_sec_y, w = 580, h = 192,
    shadow = false, fill = false, color = "elm_frame", round = 0
})
registerTabElement("Edit", "frame_edit_notion_index")

GUI.New("lbl_edit_notion_index", "Label", {
    z = 11, x = 32, y = notion_sec_y + 10,
    caption = " Notion ID Sync ",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_notion_index")

GUI.New("btn_edit_notion_create_id", "Button", {
    z = 11, x = 36, y = notion_sec_y + 12, w = 380, h = 22,
    caption = "Create ID= markers from Notion", font = 3,
    col_txt = "wnd_bg", col_fill = "elm_fill",
    func = function()
        local tok = GUI.Val("txt_edit_notion_token") or reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_token") or ""
        tok = trimWS(tok)
        if tok == "" then
            reaper.ShowMessageBox("Paste your Notion token below first.", "Create ID Markers", 0)
            return
        end
        local ts_only = false
        ts_only = chkBool(GUI.Val("chk_edit_timesel_global"))
        local ts_start, ts_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
        if ts_only and ts_start == ts_end then
            reaper.ShowMessageBox("No time selection set.", "Create ID Markers", 0)
            return
        end
        local total = reaper.CountProjectMarkers(0)
        local regions = {}
        for i = 0, total - 1 do
            local ok, isrgn, pos, rgnend, name, idx = reaper.EnumProjectMarkers3(0, i)
            if ok and isrgn and name and name ~= "" then
                local lname = (name or ""):lower()
                local is_category = lname:match("category=") or lname:match("^category")
                local is_scene = lname:match("scene=") or lname:match("^scene")
                local is_marker_type = lname:match("^index=") or lname:match("^id=")
                if not is_category and not is_scene and not is_marker_type then
                    if not ts_only or (pos >= ts_start and pos < ts_end) then
                        local entry_name = name:gsub("^[Ee]ntry=", ""):gsub("^%d+%s+", ""):match("^%s*(.-)%s*$") or name
                        if entry_name ~= "" then
                            table.insert(regions, {start = pos, endpos = rgnend, name = name, entry_name = entry_name, idx = idx})
                        end
                    end
                end
            end
        end
        if #regions == 0 then
            reaper.ShowMessageBox("No entry regions found (Category/Scene skipped).", "Create ID Markers", 0)
            return
        end
        if _G.DMN_CREATE_ID_JOB and _G.DMN_CREATE_ID_JOB.running then
            reaper.ShowMessageBox("Create ID Markers is already running.", "Create ID Markers", 0)
            return
        end
        local existing_ids = {}
        for i = 0, total - 1 do
            local ok, isrgn, pos, _, mname, _ = reaper.EnumProjectMarkers3(0, i)
            if ok and not isrgn then
                local in_range = (not ts_only) or (pos >= ts_start and pos < ts_end)
                if in_range then
                    local id_num = (mname or ""):match("[Ii][Dd]=(%d+)")
                    if id_num then existing_ids[tonumber(id_num)] = pos end
                end
            end
        end
        local btn = GUI.elms and GUI.elms.btn_edit_notion_create_id
        local original_caption = btn and btn.caption
        reaper.Undo_BeginBlock()
        reaper.PreventUIRefresh(1)
        _G.DMN_CREATE_ID_JOB = {
            running = true, regions = regions, existing_ids = existing_ids, tok = tok,
            offset_sec = 0.3, created = 0, skipped_exists = 0, skipped_no_match = 0,
            first_error = nil, original_caption = original_caption, entry_to_id = nil,
            fetch_response_path = nil, log_lines = {}
        }
        local function finishJob()
            local job = _G.DMN_CREATE_ID_JOB
            if not job then return end
            job.running = false
            _G.DMN_CREATE_ID_JOB = nil
            reaper.PreventUIRefresh(-1)
            reaper.UpdateArrange()
            reaper.Undo_EndBlock("Create ID markers from Notion", -1)
            if btn and job.original_caption then btn.caption = job.original_caption; btn:redraw() end
            local msg = "Created: " .. tostring(job.created) .. "\nSkipped (exists): " .. tostring(job.skipped_exists) .. "\nSkipped (no match): " .. tostring(job.skipped_no_match)
            if job.first_error then msg = msg .. "\n\nFirst error: " .. job.first_error end
            msg = msg .. "\n\nYes = Extended Log (console)"
            if reaper.ShowMessageBox(msg, "Create ID Markers", 4) == 6 and job.log_lines then
                reaper.ShowConsoleMsg("\nCreate ID Markers Log:\n")
                for _, line in ipairs(job.log_lines) do reaper.ShowConsoleMsg(line .. "\n") end
                reaper.Main_OnCommand(40615, 0)
            end
        end
        local function step()
            local job = _G.DMN_CREATE_ID_JOB
            if not job or not job.running then return end
            if not job.entry_to_id then
                if not job.fetch_response_path then
                    if btn then btn.caption = "Fetching..."; btn:redraw() end
                    local res_path, err = notionFetchAllEntriesToIdMapAsync(job.tok)
                    if not res_path then job.first_error = tostring(err or "Could not start fetch"); finishJob(); return end
                    job.fetch_response_path = res_path
                    reaper.defer(step)
                    return
                end
                local map, poll_err = notionFetchAllEntriesToIdMapPoll(job.fetch_response_path)
                if poll_err == "pending" then reaper.defer(step); return end
                if not map then job.first_error = tostring(poll_err or "Fetch failed"); finishJob(); return end
                job.entry_to_id = map
            end
            if btn then btn.caption = "Creating..."; btn:redraw() end
            for _, rgn in ipairs(job.regions) do
                local id_num = job.entry_to_id[rgn.entry_name]
                if not id_num then
                    job.skipped_no_match = job.skipped_no_match + 1
                    if not job.first_error then job.first_error = rgn.entry_name .. ": no match" end
                    job.log_lines[#job.log_lines + 1] = string.format("  SKIP [no match] '%s'", rgn.entry_name)
                elseif job.existing_ids[id_num] then
                    job.skipped_exists = job.skipped_exists + 1
                    job.log_lines[#job.log_lines + 1] = string.format("  SKIP [ID=%d exists] '%s'", id_num, rgn.entry_name)
                else
                    local target_pos = math.min(rgn.start + job.offset_sec, rgn.endpos - 0.01)
                    if target_pos < rgn.start then target_pos = rgn.start end
                    reaper.AddProjectMarker2(0, false, target_pos, 0, "ID=" .. tostring(id_num), -1, 0)
                    job.existing_ids[id_num] = target_pos
                    job.created = job.created + 1
                    job.log_lines[#job.log_lines + 1] = string.format("  OK   ID=%d '%s'", id_num, rgn.entry_name)
                end
            end
            finishJob()
        end
        reaper.defer(step)
    end
})
registerTabElement("Edit", "btn_edit_notion_create_id")

GUI.New("lbl_edit_notion_token", "Label", {
    z = 11, x = 36, y = notion_sec_y + 46,
    caption = "Token:",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_notion_token")

GUI.New("txt_edit_notion_token", "Textbox", {
    z = 11, x = 85, y = notion_sec_y + 42, w = 330, h = 22,
    caption = "", font_a = 3, font_b = 5,
    color = "txt", bg = "wnd_bg",
    shadow = true, pad = 4
})
registerTabElement("Edit", "txt_edit_notion_token")

GUI.New("btn_edit_notion_token_save", "Button", {
    z = 11, x = 422, y = notion_sec_y + 42, w = 52, h = 22,
    caption = "Save", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = function()
        local tok = GUI.Val("txt_edit_notion_token") or ""
        reaper.SetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_token", tok, true)
        reaper.ShowMessageBox("Saved token.", "Notion", 0)
    end
})
registerTabElement("Edit", "btn_edit_notion_token_save")

GUI.New("btn_edit_notion_token_test", "Button", {
    z = 11, x = 480, y = notion_sec_y + 42, w = 52, h = 22,
    caption = "Test", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = function()
        local tok = GUI.Val("txt_edit_notion_token") or reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_token") or ""
        tok = trimWS(tok)
        local ok, msg = notionTestToken(tok)
        reaper.ShowMessageBox(msg, ok and "Notion token OK" or "Notion token FAILED", 0)
    end
})
registerTabElement("Edit", "btn_edit_notion_token_test")

-- Helper to refresh the preset name label in the Notion section
local function refreshNotionPresetLabel()
    if not (GUI and GUI.elms) then return end
    local lbl = GUI.elms.lbl_edit_notion_preset_val
    if lbl then
        local name = getActiveNotionDbName()
        lbl.caption = (name ~= "" and name or "(none)")
        if lbl.init then pcall(function() lbl:init() end) end
        if lbl.z then GUI.redraw_z[lbl.z] = true end
    end
    GUI.redraw_z[11] = true
    GUI.redraw_z[12] = true
end

GUI.New("lbl_edit_notion_preset", "Label", {
    z = 12, x = 36, y = notion_sec_y + 72,
    caption = "Preset:",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_notion_preset")

local init_preset_name = getActiveNotionDbName()
GUI.New("lbl_edit_notion_preset_val", "Label", {
    z = 11, x = 200, y = notion_sec_y + 72,
    caption = (init_preset_name ~= "" and init_preset_name or "(none)"),
    font = 4, color = "shadow", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_notion_preset_val")

GUI.New("btn_edit_notion_preset_pick", "Button", {
    z = 11, x = 85, y = notion_sec_y + 68, w = 110, h = 22,
    caption = "Select…", font = 3,
    col_txt = "txt", col_fill = "elm_fill",
    func = function()
        local presets = getNotionDbPresetList()
        if #presets == 0 then
            reaper.ShowMessageBox("No presets saved yet.\nPaste a DB ID below and click 'Save As'.", "Database Presets", 0)
            return
        end
        local menu_str = table.concat(presets, "|")
        gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
        local result = gfx.showmenu(menu_str)
        if result > 0 then
            local picked = presets[result]
            setActiveNotionDbName(picked)
            local db_id = getNotionDbPresetId(picked)
            GUI.Val("txt_edit_notion_db_id", db_id)
            refreshNotionPresetLabel()
            -- Reset Clean Up cached schema when switching databases
            reaper.SetExtState(EXTSTATE_SECTION, "notion_cleanup_status_field", "", true)
            reaper.SetExtState(EXTSTATE_SECTION, "notion_cleanup_target_option", "", true)
            if refreshCleanupStatusLabels then pcall(refreshCleanupStatusLabels) end
        end
    end
})
registerTabElement("Edit", "btn_edit_notion_preset_pick")

GUI.New("btn_edit_notion_preset_delete", "Button", {
    z = 11, x = 330, y = notion_sec_y + 68, w = 60, h = 22,
    caption = "Delete", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = function()
        local name = getActiveNotionDbName()
        if name == "" then
            reaper.ShowMessageBox("No preset is active.", "Delete Preset", 0)
            return
        end
        local ok = reaper.ShowMessageBox("Delete preset '" .. name .. "'?", "Delete Preset", 4)
        if ok == 6 then
            deleteNotionDbPreset(name)
            local remaining = getNotionDbPresetList()
            if #remaining > 0 then
                setActiveNotionDbName(remaining[1])
                GUI.Val("txt_edit_notion_db_id", getNotionDbPresetId(remaining[1]))
            else
                setActiveNotionDbName("")
                GUI.Val("txt_edit_notion_db_id", "")
            end
            refreshNotionPresetLabel()
            reaper.SetExtState(EXTSTATE_SECTION, "notion_cleanup_status_field", "", true)
            reaper.SetExtState(EXTSTATE_SECTION, "notion_cleanup_target_option", "", true)
            if refreshCleanupStatusLabels then pcall(refreshCleanupStatusLabels) end
        end
    end
})
registerTabElement("Edit", "btn_edit_notion_preset_delete")

GUI.New("lbl_edit_notion_db_id", "Label", {
    z = 12, x = 36, y = notion_sec_y + 98,
    caption = "DB:",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_notion_db_id")

GUI.New("txt_edit_notion_db_id", "Textbox", {
    z = 11, x = 85, y = notion_sec_y + 94, w = 330, h = 22,
    caption = "", font_a = 3, font_b = 5,
    color = "txt", bg = "wnd_bg",
    shadow = true, pad = 4
})
registerTabElement("Edit", "txt_edit_notion_db_id")

GUI.New("btn_edit_notion_db_save_as", "Button", {
    z = 11, x = 422, y = notion_sec_y + 94, w = 110, h = 22,
    caption = "Save As…", font = 3,
    col_txt = "txt", col_fill = "elm_frame",
    func = function()
        local v = GUI.Val("txt_edit_notion_db_id") or ""
        v = normalizeNotionId(v)
        if not isValidNotionId(v) then
            reaper.ShowMessageBox("Paste a valid Notion database ID first.", "Save Preset", 0)
            return
        end
        local current = getActiveNotionDbName()
        local ok, name = reaper.GetUserInputs("Save Database Preset", 1, "Preset name:,extrawidth=120", current)
        if not ok then return end
        name = trimWS(name)
        if name == "" then
            reaper.ShowMessageBox("Name cannot be empty.", "Save Preset", 0)
            return
        end
        saveNotionDbPreset(name, v)
        setActiveNotionDbName(name)
        refreshNotionPresetLabel()
        reaper.ShowMessageBox("Saved preset: " .. name, "Database Preset", 0)
    end
})
registerTabElement("Edit", "btn_edit_notion_db_save_as")

GUI.New("btn_edit_notion_sync_index", "Button", {
    z = 11, x = 36, y = notion_sec_y + 120, w = 280, h = 22,
    caption = "Create/Sync Index= markers from Notion via ID=", font = 3,
    col_txt = "txt", col_fill = "elm_fill",
    func = function()
        local tok = GUI.Val("txt_edit_notion_token") or reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_token") or ""
        tok = trimWS(tok)
        if tok == "" then
            reaper.ShowMessageBox("Please paste your Notion integration token first.", "Notion sync", 0)
            return
        end

        local tol = 1.0  -- fixed (Tolerance UI removed)
        local ts_only = chkBool(GUI.Val("chk_edit_timesel_global"))
        local ts_start, ts_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
        if ts_only and ts_start == ts_end then
            reaper.ShowMessageBox("No time selection set.", "Notion sync", 0)
            return
        end

        local index_markers = collectIndexMarkers()
        local id_markers = collectIDMarkers()
        local regions = collectEntryRegionsInRange(ts_only)
        -- ID markers are commonly placed slightly BEFORE region start (e.g. 1.5s).
        -- When "Only within time selection" is enabled, we still want to process those regions.
        local id_tol_before_start = 2.5

        local changed, created, skipped_no_id_marker, skipped_no_row, skipped_no_suffix = 0, 0, 0, 0, 0
        local first_error = nil
        local skipped_regions = {}
        local log_lines = {}

        reaper.PreventUIRefresh(1)
        reaper.Undo_BeginBlock()

        for _, region in ipairs(regions or {}) do
            local idm = findIDMarkerForRegion(id_markers, region, id_tol_before_start)
            if not idm or not idm.id_num then
                skipped_no_id_marker = skipped_no_id_marker + 1
                skipped_regions[#skipped_regions + 1] = region
                log_lines[#log_lines + 1] = string.format("  SKIP [no ID= marker] region '%s' (%.2fs – %.2fs)", region.name or "?", region.start, region["end"])
            else
                local id_num = tonumber(idm.id_num)
                local filename = notionGetFileNameFormulaByID(tok, id_num)
                if not filename then
                    skipped_no_row = skipped_no_row + 1
                    skipped_regions[#skipped_regions + 1] = region
                    log_lines[#log_lines + 1] = string.format("  SKIP [Notion row missing/empty] region '%s' ID=%s (%.2fs – %.2fs)", region.name or "?", tostring(id_num), region.start, region["end"])
                    if not first_error and skipped_no_row == 1 then
                        first_error = "ID=" .. tostring(id_num) .. " - Check REAPER console (View > Show Console) for detailed error"
                    end
                else
                    local digits = nil
                    local trimmed = trimWS(filename)
                    if trimmed and trimmed:match("^%d+$") then
                        digits = string.format("%02d", tonumber(trimmed) or 0)
                        if digits == "00" then digits = trimmed end
                    end
                    if not digits then digits = deriveIndexSuffix(filename) end
                    if not digits or digits == "" then
                        skipped_no_suffix = skipped_no_suffix + 1
                        skipped_regions[#skipped_regions + 1] = region
                        log_lines[#log_lines + 1] = string.format("  SKIP [no suffix in FileName '%s'] region '%s' ID=%s (%.2fs – %.2fs)", tostring(filename), region.name or "?", tostring(idm.id_num), region.start, region["end"])
                    else
                        local new_name = "Index=" .. digits
                        log_lines[#log_lines + 1] = string.format("  OK   region '%s' ID=%s → %s (FileName='%s')", region.name or "?", tostring(id_num), new_name, tostring(filename))
                        
                        local search_start = region.start - tol - 2
                        local search_end = region["end"] + tol
                        for i = #index_markers, 1, -1 do
                            local m = index_markers[i]
                            if m.pos >= search_start and m.pos <= search_end then
                                reaper.DeleteProjectMarker(0, m.id, false)
                                table.remove(index_markers, i)
                                changed = changed + 1
                            end
                        end
                        
                        local create_pos = math.max(0, region.start - 1.0)
                        local new_id = reaper.AddProjectMarker2(0, false, create_pos, 0, new_name, -1, 0)
                        created = created + 1
                        if new_id then
                            index_markers[#index_markers + 1] = { pos = create_pos, id = new_id, name = new_name }
                        end
                    end
                end
            end
        end

        reaper.Undo_EndBlock("Create/Sync Index markers from Notion (ID markers)", -1)
        reaper.PreventUIRefresh(-1)
        reaper.UpdateArrange()

        -- Select items overlapping skipped regions so the user can inspect them
        if #skipped_regions > 0 then
            reaper.Main_OnCommand(40289, 0) -- Unselect all items
            local num_tracks = reaper.CountTracks(0)
            for _, r in ipairs(skipped_regions) do
                for t = 0, num_tracks - 1 do
                    local track = reaper.GetTrack(0, t)
                    local num_items = reaper.CountTrackMediaItems(track)
                    for it = 0, num_items - 1 do
                        local item = reaper.GetTrackMediaItem(track, it)
                        local ipos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                        local ilen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                        local iend = ipos + ilen
                        if ipos < r["end"] and iend > r.start then
                            reaper.SetMediaItemSelected(item, true)
                        end
                    end
                end
            end
            reaper.UpdateArrange()
        end

        local msg = "Deleted old Index markers: " .. tostring(changed) .. "\n" ..
            "Created new Index markers: " .. tostring(created) .. "\n\n" ..
            "Skipped (no ID= marker found for region): " .. tostring(skipped_no_id_marker) .. "\n" ..
            "Skipped (Notion row missing/empty): " .. tostring(skipped_no_row) .. "\n" ..
            "Skipped (no suffix in FileName): " .. tostring(skipped_no_suffix)
        if #skipped_regions > 0 then
            msg = msg .. "\n\n→ " .. tostring(#skipped_regions) .. " skipped region(s) selected in arrange."
        end
        if first_error then
            msg = msg .. "\n\nFirst error: " .. first_error
        end
        msg = msg .. "\n\nClick Yes for Extended Log (console), No to close."
        local answer = reaper.ShowMessageBox(msg, "Notion → Index Sync", 4)
        if answer == 6 then
            reaper.ShowConsoleMsg("\n══════════════════════════════════════════\n")
            reaper.ShowConsoleMsg("Notion → Index Sync  —  Extended Log\n")
            reaper.ShowConsoleMsg("══════════════════════════════════════════\n")
            reaper.ShowConsoleMsg("Regions processed: " .. tostring(#(regions or {})) .. "\n")
            reaper.ShowConsoleMsg("Deleted old Index markers: " .. tostring(changed) .. "\n")
            reaper.ShowConsoleMsg("Created new Index markers: " .. tostring(created) .. "\n")
            reaper.ShowConsoleMsg("Skipped total: " .. tostring(#skipped_regions) .. "\n\n")
            for _, line in ipairs(log_lines) do
                reaper.ShowConsoleMsg(line .. "\n")
            end
            reaper.ShowConsoleMsg("══════════════════════════════════════════\n\n")
            reaper.Main_OnCommand(40615, 0) -- View: Show console
        end
    end
})
registerTabElement("Edit", "btn_edit_notion_sync_index")

GUI.New("lbl_edit_notion_note", "Label", {
    z = 11, x = 36, y = notion_sec_y + 146,
    caption = "Tip: ID=1234 → Notion ID=1234 → Index property (or FilenameFormula suffix) → Index=03",
    font = 4, color = "shadow", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_notion_note")

-- Section 5: CLEAN UP - below Notion section
local cleanup_sec_y = notion_sec_y + 208
-- Y positions: Database 32; toggle1 (Update Status) 56; toggle2 (Assign Reaper) 82; Status row 108; Target row 132; timesel 156; run 180
local CLEANUP_Y_TOGGLE2 = 98
local CLEANUP_Y_STATUS = 124
local CLEANUP_Y_TARGET = 148
local CLEANUP_Y_RUN = 172       -- when Status row visible
local CLEANUP_Y_RUN_COLLAPSED = 148  -- when Status row hidden

GUI.New("frame_edit_cleanup", "Frame", {
    z = 12, x = 20, y = cleanup_sec_y, w = 580, h = 242,
    shadow = false, fill = false, color = "elm_frame", round = 0
})
registerTabElement("Edit", "frame_edit_cleanup")

GUI.New("lbl_edit_cleanup", "Label", {
    z = 11, x = 32, y = cleanup_sec_y + 10,
    caption = " Clean Up (Notion status from recorded audio) ",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_cleanup")

GUI.New("lbl_edit_cleanup_desc", "Label", {
    z = 11, x = 36, y = cleanup_sec_y + 26,
    caption = "Entry regions + selected track with items → update Notion (enable options below).",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_cleanup_desc")

-- Status property / option dropdowns (menu-backed)
local function getCleanupDbId()
    return getCleanupTargetDbId()
end

local function getCleanupToken()
    local tok = GUI.Val("txt_edit_notion_token") or reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_token") or ""
    return trimWS(tok)
end

local function getCleanupSelectedStatusField()
    local v = reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_cleanup_status_field") or ""
    return trimWS(v)
end

local function setCleanupSelectedStatusField(v)
    v = trimWS(v)
    reaper.SetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_cleanup_status_field", v, true)
end

local function getCleanupSelectedTargetOption()
    local v = reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_cleanup_target_option") or ""
    return trimWS(v)
end

local function setCleanupSelectedTargetOption(v)
    v = trimWS(v)
    reaper.SetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_cleanup_target_option", v, true)
end

local function getCleanupUpdateStatusEnabled()
    local v = reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_cleanup_update_status")
    if v == "1" or v == "true" then return true end
    return false -- default off (Status row hidden)
end

local function setCleanupUpdateStatusEnabled(enabled)
    reaper.SetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_cleanup_update_status", enabled and "1" or "0", true)
end

local function getCleanupAssignReaperSessionEnabled()
    local v = reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_cleanup_assign_reaper_session")
    if v == "0" or v == "false" then return false end
    return true -- default on
end

local function setCleanupAssignReaperSessionEnabled(enabled)
    reaper.SetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_cleanup_assign_reaper_session", enabled and "1" or "0", true)
end

local function normalizeLoose(s)
    s = tostring(s or ""):lower()
    s = s:gsub("\194\160", " ") -- NBSP to space (UTF-8 C2 A0)
    s = s:gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
    return s
end

local function suggestRecordedNeedsImporting(options)
    for _, o in ipairs(options or {}) do
        local n = normalizeLoose(o)
        if n:find("recorded", 1, true) and n:find("needs", 1, true) and n:find("import", 1, true) then
            return o
        end
    end
    return nil
end

-- Turn raw "No properties (keys: Length)" style errors into a clearer message for the user.
local function friendlyNotionSchemaErr(raw_err)
    if not raw_err or raw_err == "" then return tostring(raw_err) end
    local s = tostring(raw_err)
    if s:match("No properties") and (s:match("Length") or s:match("keys:")) then
        return "Notion did not return a database schema (response had no 'properties').\n\n"
            .. "If the database works in the section above (e.g. Create ID markers), same token and DB are used here.\n"
            .. "Some linked/connected databases do not expose schema via the API; the script now also tries .schema and checks for API returning plain text.\n\n"
            .. "Other causes:\n"
            .. "• Database not shared with your integration → in Notion: open the DB, Share, invite the integration\n"
            .. "• Wrong Database ID → use the ID from the database page URL (32-char hex)\n\n"
            .. "Technical: " .. s
    end
    if s:match("plain text") then
        return "Notion (or a proxy) returned plain text instead of JSON, so the response could not be parsed.\n\n"
            .. "Check network/proxy; try again. Technical: " .. s
    end
    return s
end

local function ensureCleanupSchema()
    local tok = getCleanupToken()
    if tok == "" then
        return nil, "Paste your Notion token first."
    end
    local db_id = getCleanupDbId()
    if not isValidNotionId(db_id) then
        return nil, getCleanupSelectedDatabaseName() .. " Database ID looks invalid or not set."
    end
    local schema = NOTION_STATUS_SCHEMA_BY_DB[db_id]
    if schema and schema.prop_list and #schema.prop_list > 0 then
        return schema
    end
    return notionFetchStatusSchema(tok, db_id)
end

local function refreshCleanupStatusLabels()
    local field = getCleanupSelectedStatusField()
    local opt = getCleanupSelectedTargetOption()
    local db_name = getCleanupSelectedDatabaseName()
    if GUI and GUI.elms then
        -- Refresh database name label
        local ld = GUI.elms.lbl_edit_cleanup_db_val
        if ld then
            ld.caption = (db_name ~= "" and db_name or "(not set)")
            if ld.init then pcall(function() ld:init() end) end
            if ld.z then GUI.redraw_z[ld.z] = true end
        end
        local lf = GUI.elms.lbl_edit_cleanup_status_field_val
        if lf then 
            lf.caption = (field ~= "" and field or "(not set)")
            -- Reinitialize to recalculate label width
            if lf.init then pcall(function() lf:init() end) end
            -- Mark layer for redraw
            if lf.z then GUI.redraw_z[lf.z] = true end
        end
        local lo = GUI.elms.lbl_edit_cleanup_status_opt_val
        if lo then 
            lo.caption = (opt ~= "" and opt or "(not set)")
            if lo.init then pcall(function() lo:init() end) end
            if lo.z then GUI.redraw_z[lo.z] = true end
        end
        -- Force full redraw
        GUI.redraw_z[11] = true
        GUI.redraw_z[12] = true
    end
end

-- Show/hide Status property + Target option row based on "Update Status property" toggle; shift timesel/run when hidden
local function setCleanupStatusRowVisible(visible)
    if not GUI or not GUI.elms then return end
    local offset = tonumber(tab_scroll and tab_scroll["Edit"]) or 0
    local base = cleanup_sec_y + offset
    local statusRowElms = {
        "lbl_edit_cleanup_voice", "btn_edit_cleanup_pick_status_field", "lbl_edit_cleanup_status_field_val",
        "lbl_edit_cleanup_status_opt", "btn_edit_cleanup_pick_status_opt", "lbl_edit_cleanup_status_opt_val"
    }
    local statusY = { 124, 120, 124, 148, 144, 148 }  -- label vs button y for Status row then Target row
    for i, name in ipairs(statusRowElms) do
        local elm = GUI.elms[name]
        if elm then
            elm.y = visible and (base + statusY[i]) or HIDDEN_Y
        end
    end
    local runY = visible and CLEANUP_Y_RUN or CLEANUP_Y_RUN_COLLAPSED
    local runElm = GUI.elms.btn_edit_cleanup_run
    if runElm then runElm.y = base + runY end
    GUI.redraw_z[11] = true
end
setReapplyCleanupVisibility(function() setCleanupStatusRowVisible(getCleanupUpdateStatusEnabled()) end)

-- IIFE boundary: stay under Lua's 200-local limit in the main chunk
;(function()

-- ============================================================================
-- RENDER TAB STATE  (inside IIFE — keeps main chunk under 200 locals)
-- ============================================================================
local RENDER_OPTS = {
    sample_rates       = { 44100, 48000, 88200, 96000, 192000 },
    sample_rate_labels = { "44.1 kHz", "48 kHz", "88.2 kHz", "96 kHz", "192 kHz" },
    channel_options    = { 1, 2, 4, 6, 8 },
    channel_labels     = { "Mono (1)", "Stereo (2)", "Quad (4)", "5.1 (6)", "7.1 (8)" },
    normalize_modes       = { 0, 2, 4, 6, 8, 10 },
    normalize_mode_labels = { "LUFS-I", "RMS-I", "Peak", "True Peak", "LUFS-M max", "LUFS-S max" },
}
local render_output_path      = ""
local render_sample_rate      = 48000
local render_channels         = 2
local render_normalize        = false
local render_normalize_mode   = 0
local render_normalize_target = "-24"
local render_fadeout          = false
local render_fadeout_ms       = "300"
-- Source dropdown — mirrors REAPER's Render dialog Source list.
-- Each entry: { label, render_settings_bits }
-- RENDER_SETTINGS bitmask (from REAPER API):
--   &(1|2)=0 master mix, &1 stems+master, &2 stems only,
--   &8 region render matrix, &32 selected media items,
--   &64 selected media items via master, &128 selected tracks via master
local RENDER_SOURCES = {
    { label = "Master mix",                       settings = 0   },
    { label = "Selected tracks (stems)",          settings = 2   },
    { label = "Master mix + stems",               settings = 1   },
    { label = "Selected tracks via master",       settings = 128 },
    { label = "Region render matrix",             settings = 8   },
    { label = "Selected media items",             settings = 32  },
    { label = "Selected media items via master",  settings = 64  },
}
-- Bounds dropdown — mirrors REAPER's Render dialog Bounds list.
-- RENDER_BOUNDSFLAG values from REAPER API.
local RENDER_BOUNDS = {
    { label = "Custom time bounds",    value = 0 },
    { label = "Entire project",        value = 1 },
    { label = "Time selection",        value = 2 },
    { label = "All project regions",   value = 3 },
    { label = "Selected media items",  value = 4 },
    { label = "Selected project regions", value = 5 },
}
local render_source_idx = 5  -- 1-based index into RENDER_SOURCES (default: Region render matrix)
local render_bounds_idx = 4  -- 1-based index into RENDER_BOUNDS  (default: All project regions)
local render_folder_tokens    = { "$marker(Speaker)" }
local render_file_tokens      = { "VO_", "$marker(Speaker)", "_", "$marker(Category)", "_", "$marker(Index)" }

-- BWF metadata embed options — mirrors REAPER's Render → Write BWF metadata dropdown.
-- RENDER_METADATA project info integer: 0 = off, 1-6 = embed modes below.
local BWF_EMBED_MODES = {
    { label = "Do not include markers or regions", value = 0 },
    { label = "Markers + regions",                 value = 1 },
    { label = "Markers + regions starting with #", value = 2 },
    { label = "Markers only",                      value = 3 },
    { label = "Markers starting with # only",      value = 4 },
    { label = "Regions only",                      value = 5 },
    { label = "Regions starting with # only",      value = 6 },
}
local render_write_metadata    = false
local render_metadata_mode_idx = 4  -- 1-based into BWF_EMBED_MODES; default = "Markers only"

local function saveRenderSettings()
    local EXT = "DMN_DialogueWorkflow"
    reaper.SetExtState(EXT, "render_output_path",      render_output_path,              true)
    reaper.SetExtState(EXT, "render_sample_rate",      tostring(render_sample_rate),    true)
    reaper.SetExtState(EXT, "render_channels",         tostring(render_channels),       true)
    reaper.SetExtState(EXT, "render_normalize",        render_normalize and "1" or "0", true)
    reaper.SetExtState(EXT, "render_normalize_mode",   tostring(render_normalize_mode), true)
    reaper.SetExtState(EXT, "render_normalize_target", render_normalize_target,         true)
    reaper.SetExtState(EXT, "render_source_idx",       tostring(render_source_idx),     true)
    reaper.SetExtState(EXT, "render_bounds_idx",       tostring(render_bounds_idx),     true)
    reaper.SetExtState(EXT, "render_folder_tokens",    table.concat(render_folder_tokens, "|"), true)
    reaper.SetExtState(EXT, "render_file_tokens",      table.concat(render_file_tokens,  "|"), true)
    reaper.SetExtState(EXT, "render_write_metadata",    render_write_metadata and "1" or "0",   true)
    reaper.SetExtState(EXT, "render_metadata_mode_idx", tostring(render_metadata_mode_idx),      true)
    reaper.SetExtState(EXT, "render_fadeout",           render_fadeout and "1" or "0",           true)
    reaper.SetExtState(EXT, "render_fadeout_ms",        render_fadeout_ms,                       true)
end

do -- load render settings from ExtState
    local EXT = "DMN_DialogueWorkflow"
    local p = reaper.GetExtState(EXT, "render_output_path"); if p ~= "" then render_output_path = p end
    local sr = tonumber(reaper.GetExtState(EXT, "render_sample_rate")); if sr then render_sample_rate = sr end
    local ch = tonumber(reaper.GetExtState(EXT, "render_channels")); if ch then render_channels = ch end
    render_normalize = reaper.GetExtState(EXT, "render_normalize") == "1"
    local nm = tonumber(reaper.GetExtState(EXT, "render_normalize_mode")); if nm then render_normalize_mode = nm end
    local nt = reaper.GetExtState(EXT, "render_normalize_target"); if nt ~= "" then render_normalize_target = nt end
    local si = tonumber(reaper.GetExtState(EXT, "render_source_idx"))
    if si and si >= 1 and si <= #RENDER_SOURCES then render_source_idx = si end
    local bi = tonumber(reaper.GetExtState(EXT, "render_bounds_idx"))
    if bi and bi >= 1 and bi <= #RENDER_BOUNDS then render_bounds_idx = bi end
    -- Migrate old format ("regions"/"items" + time_sel)
    if not si then
        local old_src = reaper.GetExtState(EXT, "render_source")
        local old_ts  = reaper.GetExtState(EXT, "render_time_sel") == "1"
        if old_src == "items" then
            render_source_idx = 7  -- Selected media items via master
            render_bounds_idx = old_ts and 3 or 5  -- Time sel or Selected media items
        elseif old_src == "regions" then
            render_source_idx = 5  -- Region render matrix
            render_bounds_idx = old_ts and 3 or 4  -- Time sel or All project regions
        end
    end
    local ft = reaper.GetExtState(EXT, "render_folder_tokens")
    local ff = reaper.GetExtState(EXT, "render_file_tokens")
    if ft ~= "" then
        render_folder_tokens = {}
        for tok in (ft .. "|"):gmatch("([^|]*)|") do
            if tok ~= "" then render_folder_tokens[#render_folder_tokens + 1] = tok end
        end
    end
    if ff ~= "" then
        render_file_tokens = {}
        for tok in (ff .. "|"):gmatch("([^|]*)|") do
            if tok ~= "" then render_file_tokens[#render_file_tokens + 1] = tok end
        end
    end
    render_write_metadata = reaper.GetExtState(EXT, "render_write_metadata") == "1"
    local mmi = tonumber(reaper.GetExtState(EXT, "render_metadata_mode_idx"))
    if mmi and mmi >= 1 and mmi <= #BWF_EMBED_MODES then render_metadata_mode_idx = mmi end
    render_fadeout = reaper.GetExtState(EXT, "render_fadeout") == "1"
    local foms = reaper.GetExtState(EXT, "render_fadeout_ms"); if foms ~= "" then render_fadeout_ms = foms end
end

-- Database row: shows the active preset (set in Notion section above)
GUI.New("lbl_edit_cleanup_db", "Label", {
    z = 11, x = 36, y = cleanup_sec_y + 46,
    caption = "Database:",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_cleanup_db")

-- One table instead of three locals (Lua chunk limit: 200 local names)
local _cleanup_lbl_init = {
    db_name = getCleanupSelectedDatabaseName(),
    status_field = getCleanupSelectedStatusField(),
    target_opt = getCleanupSelectedTargetOption(),
}
GUI.New("lbl_edit_cleanup_db_val", "Label", {
    z = 11, x = 110, y = cleanup_sec_y + 46,
    caption = (_cleanup_lbl_init.db_name ~= "" and _cleanup_lbl_init.db_name or "(not set)"),
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_cleanup_db_val")

-- Toggles: each on its own row for clarity
GUI.New("chk_edit_cleanup_update_status", "Checklist", {
    z = 11, x = 36, y = cleanup_sec_y + 68, w = 24, h = 22,
    caption = "", optarray = {""},
    dir = "h", font_a = 3, font_b = 3,
    col_txt = "txt", col_fill = "elm_fill", bg = "wnd_bg",
    frame = false, shadow = false, opt_size = 22,
    optsel = { getCleanupUpdateStatusEnabled() }
})
registerTabElement("Edit", "chk_edit_cleanup_update_status")
GUI.New("lbl_edit_cleanup_update_status", "Label", {
    z = 11, x = 66, y = cleanup_sec_y + 72,
    caption = "Update Status property (set voice status for recorded regions)",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_cleanup_update_status")

GUI.New("chk_edit_cleanup_assign_reaper", "Checklist", {
    z = 11, x = 36, y = cleanup_sec_y + 94, w = 24, h = 22,
    caption = "", optarray = {""},
    dir = "h", font_a = 3, font_b = 3,
    col_txt = "txt", col_fill = "elm_fill", bg = "wnd_bg",
    frame = false, shadow = false, opt_size = 22,
    optsel = { getCleanupAssignReaperSessionEnabled() }
})
registerTabElement("Edit", "chk_edit_cleanup_assign_reaper")
GUI.New("lbl_edit_cleanup_assign_reaper", "Label", {
    z = 11, x = 66, y = cleanup_sec_y + 98,
    caption = "Assign ReaperSession (write project name to Notion)",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_cleanup_assign_reaper")

GUI.New("lbl_edit_cleanup_voice", "Label", {
    z = 11, x = 36, y = HIDDEN_Y,
    caption = "Status property:",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_cleanup_voice")

GUI.New("btn_edit_cleanup_pick_status_field", "Button", {
    z = 11, x = 130, y = HIDDEN_Y, w = 70, h = 22,
    caption = "Pick…", font = 3,
    col_txt = "txt", col_fill = "elm_fill",
    func = function()
        local schema, err = ensureCleanupSchema()
        if not schema then
            reaper.ShowMessageBox("Couldn't load Status properties:\n\n" .. friendlyNotionSchemaErr(err or ""), "Pick Status property", 0)
            return
        end
        local list = schema.prop_list or {}
        if #list == 0 then
            reaper.ShowMessageBox("No Status properties found on this database.", "Pick Status property", 0)
            return
        end
        local menu_str = table.concat(list, "|")
        gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
        local result = gfx.showmenu(menu_str)
        if result > 0 then
            local picked = list[result]
            setCleanupSelectedStatusField(picked)
            -- Reset option selection when field changes
            setCleanupSelectedTargetOption("")
            -- Suggest option for this field
            local opts = (schema.status_props[picked] and schema.status_props[picked].options) or {}
            local suggested = suggestRecordedNeedsImporting(opts)
            if suggested then
                setCleanupSelectedTargetOption(suggested)
            elseif #opts > 0 then
                setCleanupSelectedTargetOption(opts[1])
            end
            refreshCleanupStatusLabels()
        end
    end
})
registerTabElement("Edit", "btn_edit_cleanup_pick_status_field")

GUI.New("lbl_edit_cleanup_status_field_val", "Label", {
    z = 11, x = 210, y = HIDDEN_Y,
    caption = (_cleanup_lbl_init.status_field ~= "" and _cleanup_lbl_init.status_field or "(not set)"),
    font = 4, color = "shadow", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_cleanup_status_field_val")

GUI.New("lbl_edit_cleanup_status_opt", "Label", {
    z = 11, x = 36, y = HIDDEN_Y,
    caption = "Target option:",
    font = 3, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_cleanup_status_opt")

GUI.New("btn_edit_cleanup_pick_status_opt", "Button", {
    z = 11, x = 130, y = HIDDEN_Y, w = 70, h = 22,
    caption = "Pick…", font = 3,
    col_txt = "txt", col_fill = "elm_fill",
    func = function()
        local schema, err = ensureCleanupSchema()
        if not schema then
            reaper.ShowMessageBox("Couldn't load Status options:\n" .. tostring(err or ""), "Pick Target option", 0)
            return
        end
        local field = getCleanupSelectedStatusField()
        if field == "" then
            reaper.ShowMessageBox("Pick a Status property first.", "Pick Target option", 0)
            return
        end
        local opts = (schema.status_props[field] and schema.status_props[field].options) or {}
        if #opts == 0 then
            reaper.ShowMessageBox("No options found for:\n" .. field, "Pick Target option", 0)
            return
        end
        local menu_str = table.concat(opts, "|")
        gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
        local result = gfx.showmenu(menu_str)
        if result > 0 then
            setCleanupSelectedTargetOption(opts[result])
            refreshCleanupStatusLabels()
        end
    end
})
registerTabElement("Edit", "btn_edit_cleanup_pick_status_opt")

GUI.New("lbl_edit_cleanup_status_opt_val", "Label", {
    z = 11, x = 210, y = HIDDEN_Y,
    caption = (_cleanup_lbl_init.target_opt ~= "" and _cleanup_lbl_init.target_opt or "(not set)"),
    font = 4, color = "shadow", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_cleanup_status_opt_val")

GUI.New("btn_edit_cleanup_run", "Button", {
    z = 11, x = 36, y = cleanup_sec_y + CLEANUP_Y_RUN, w = 280, h = 22,
    caption = "Update Notion Database", font = 3,
    col_txt = "txt", col_fill = "elm_fill",
    func = function()
        -- Run in deferred chunks so REAPER doesn't appear frozen.
        if _G.DMN_CLEANUP_JOB and _G.DMN_CLEANUP_JOB.running then
            reaper.ShowMessageBox("Clean Up is already running.", "Clean Up", 0)
            return
        end

        local track = reaper.GetSelectedTrack(0, 0)
        if not track then
            reaper.ShowMessageBox("Please select the track that contains the recorded audio items.", "Clean Up", 0)
            return
        end

        local tok = GUI.Val("txt_edit_notion_token") or reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_token") or ""
        tok = trimWS(tok)
        if tok == "" then
            reaper.ShowMessageBox("Please paste your Notion integration token first (Edit → Notion section).", "Clean Up", 0)
            return
        end

        local ts_only = chkBool(GUI.Val("chk_edit_timesel_global"))
        local ts_start, ts_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
        if ts_only and ts_start == ts_end then
            reaper.ShowMessageBox("No time selection set.", "Clean Up", 0)
            return
        end

        local do_status = chkBool(GUI.Val("chk_edit_cleanup_update_status"))
        local do_reaper = chkBool(GUI.Val("chk_edit_cleanup_assign_reaper"))
        if not do_status and not do_reaper then
            reaper.ShowMessageBox("Enable at least one: 'Update Status property' or 'Assign ReaperSession'.", "Clean Up", 0)
            return
        end

        local schema = nil
        local voice_field = getCleanupSelectedStatusField()
        local target_opt = getCleanupSelectedTargetOption()

        -- When Update Status is on, require status property and target option.
        if do_status then
        -- If not selected yet, fall back to old defaults (Male/Fem) for compatibility.
        if voice_field == "" then
            -- Try to pick a sensible default from schema if available.
            schema = ensureCleanupSchema()
            if schema and schema.prop_list and #schema.prop_list > 0 then
                for _, name in ipairs(schema.prop_list) do
                    if normalizeLoose(name) == normalizeLoose("Male Voice Status") then
                        voice_field = name
                        break
                    end
                end
                if voice_field == "" then voice_field = schema.prop_list[1] end
                setCleanupSelectedStatusField(voice_field)
                local opts = (schema.status_props[voice_field] and schema.status_props[voice_field].options) or {}
                local suggested = suggestRecordedNeedsImporting(opts)
                if suggested then
                    target_opt = suggested
                    setCleanupSelectedTargetOption(target_opt)
                elseif #opts > 0 then
                    target_opt = opts[1]
                    setCleanupSelectedTargetOption(target_opt)
                end
            else
                reaper.ShowMessageBox("Pick a Status property first (or click Fetch).", "Clean Up", 0)
                return
            end
        end

        if target_opt == "" then
            schema = schema or ensureCleanupSchema()
            if schema and schema.status_props and schema.status_props[voice_field] then
                local opts = schema.status_props[voice_field].options or {}
                local suggested = suggestRecordedNeedsImporting(opts)
                if suggested then
                    target_opt = suggested
                    setCleanupSelectedTargetOption(target_opt)
                elseif #opts > 0 then
                    target_opt = opts[1]
                    setCleanupSelectedTargetOption(target_opt)
                end
            end
        end

        if target_opt == "" then
            reaper.ShowMessageBox("Pick a target Status option first.", "Clean Up", 0)
            return
        end
        end  -- do_status: required status field and target option

        -- Look up the option ID from the schema (when updating status)
        local target_opt_id = ""
        schema = schema or ensureCleanupSchema()
        if schema and schema.status_props and schema.status_props[voice_field] then
            local prop_info = schema.status_props[voice_field]
            if prop_info.options_by_name and prop_info.options_by_name[target_opt] then
                target_opt_id = prop_info.options_by_name[target_opt].id or ""
            end
        end

        local id_markers = collectIDMarkers()
        local regions = collectEntryRegionsInRange(ts_only)

        local id_tol = 2.0

        local updated = 0
        local already_set = 0
        local skipped_no_audio = 0
        local skipped_no_id_marker = 0
        local skipped_notion_fail = 0
        local first_err = nil

        local btn = GUI.elms and GUI.elms.btn_edit_cleanup_run
        local original_caption = btn and btn.caption

        -- Get project name for ReaperSession
        local proj_path = reaper.GetProjectName(0, "")
        local proj_name = proj_path:match("([^/\\]+)%.RPP$") or proj_path:match("([^/\\]+)%.rpp$") or proj_path:match("([^/\\]+)$") or "Untitled"
        if proj_name == "" then proj_name = "Untitled" end

        _G.DMN_CLEANUP_JOB = {
            running = true,
            phase = "collect",  -- "collect" = build id_list; "poll" = wait for background Notion batch
            i = 1,
            id_list = {},
            regions = regions,
            id_markers = id_markers,
            id_tol = id_tol,
            track = track,
            tok = tok,
            do_status = do_status,
            do_reaper = do_reaper,
            voice_field = voice_field,
            target_option = target_opt,
            target_option_id = target_opt_id,
            proj_name = proj_name,
            updated = 0,
            already_set = 0,
            skipped_no_audio = 0,
            skipped_no_id_marker = 0,
            skipped_notion_fail = 0,
            first_err = nil,
            original_caption = original_caption
        }

        reaper.PreventUIRefresh(1)
        reaper.Undo_BeginBlock()

        local function finishJob()
            local job = _G.DMN_CLEANUP_JOB
            if not job then return end
            job.running = false
            _G.DMN_CLEANUP_JOB = nil

            reaper.Undo_EndBlock("Clean Up: update Notion voice status from recorded regions", -1)
            reaper.PreventUIRefresh(-1)
            reaper.UpdateArrange()

            if btn and job.original_caption then
                btn.caption = job.original_caption
                btn:redraw()
            end

            local msg = "Updated Notion rows: " .. tostring(job.updated) .. "\n\n" ..
                "Already set: " .. tostring(job.already_set) .. "\n" ..
                "Skipped (no audio on selected track): " .. tostring(job.skipped_no_audio) .. "\n" ..
                "Skipped (no ID= marker in region): " .. tostring(job.skipped_no_id_marker) .. "\n" ..
                "Skipped (Notion update failed): " .. tostring(job.skipped_notion_fail)
            
            if job.first_err then
                msg = msg .. "\n\nFirst Notion error:\n" .. tostring(job.first_err)
                msg = msg .. "\n\n(All debug info is shown above. Look for INFO|PATCH_RESP_KEYS, INFO|PATCH_RESP_PROPS, and INFO|FIELD_RAW lines)"
            end
            
            reaper.ShowMessageBox(msg, "Clean Up", 0)
        end

        local function step()
            local job = _G.DMN_CLEANUP_JOB
            if not job or not job.running then return end

            if job.phase == "poll" then
                -- Background Notion batch: poll until DONE (returns nil, "pending" when still running)
                local updated, already_set, failed, first_err = notionCleanUpBatchPoll(job.cleanup_response_path)
                if updated == nil and already_set == "pending" then
                    if btn then
                        btn.caption = "Updating Notion in background..."
                        btn:redraw()
                    end
                    reaper.defer(step)
                    return
                end
                if updated == nil then
                    job.first_err = first_err or "Batch failed"
                    job.skipped_notion_fail = #(job.id_list or {})
                else
                    job.updated = updated or 0
                    job.already_set = already_set or 0
                    job.skipped_notion_fail = failed or 0
                    if first_err and first_err ~= "" then job.first_err = first_err end
                end
                finishJob()
                return
            end

            -- Phase "collect": build id_list from regions (no Notion calls)
            local total = #job.regions
            if job.i > total then
                -- Collection done; start background batch or finish with no work
                if not job.id_list or #job.id_list == 0 then
                    finishJob()
                    return
                end
                local db_id = getCleanupDbId()
                if not isValidNotionId(db_id) then
                    job.first_err = "Notion DB ID not set or invalid for selected database (" .. getCleanupSelectedDatabaseName() .. ")."
                    job.skipped_notion_fail = #job.id_list
                    finishJob()
                    return
                end
                local res_path, err = notionCleanUpBatchAsync(job.tok, db_id, job.do_status, job.do_reaper, job.voice_field, job.target_option, job.proj_name, job.id_list)
                if not res_path then
                    job.first_err = err or "Failed to start batch"
                    job.skipped_notion_fail = #job.id_list
                    finishJob()
                    return
                end
                job.phase = "poll"
                job.cleanup_response_path = res_path
                if btn then
                    btn.caption = "Updating Notion in background..."
                    btn:redraw()
                end
                reaper.defer(step)
                return
            end

            if btn then
                btn.caption = string.format("Scanning regions... %d/%d", job.i, total)
                btn:redraw()
            end

            local r = job.regions[job.i]
            job.i = job.i + 1

            if not job.track or not r then
                reaper.defer(step)
                return
            end

            if not trackHasItemOverlapping(job.track, r.start, r["end"]) then
                job.skipped_no_audio = job.skipped_no_audio + 1
            else
                local idm = findIDMarkerForRegion(job.id_markers, r, job.id_tol)
                if not idm or not idm.id_num then
                    job.skipped_no_id_marker = job.skipped_no_id_marker + 1
                else
                    job.id_list[#job.id_list + 1] = idm.id_num
                end
            end

            reaper.defer(step)
        end

        reaper.defer(step)
    end
})
registerTabElement("Edit", "btn_edit_cleanup_run")

GUI.New("lbl_edit_cleanup_note", "Label", {
    z = 11, x = 36, y = cleanup_sec_y + 222,
    caption = "Requires: Entry regions, ID= markers, selected track with items.",
    font = 4, color = "txt", bg = "wnd_bg"
})
registerTabElement("Edit", "lbl_edit_cleanup_note")

-- ─────────────────────────────────────────────────────────────────────────────
-- RENDER TAB  (pure ImGui — no Lokasenna GUI elements)
-- ─────────────────────────────────────────────────────────────────────────────
-- All render tab UI lives in draw_render_tab() below.

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

GUI.Init()

-- Set initial values BEFORE switching tabs (so values are populated when elements move)
GUI.Val("txt_url", settings.url)
GUI.Val("txt_startrow", settings.start_row)
GUI.Val("chk_cursor", {settings.insert_at_cursor == "1"})

-- Set default timing values
GUI.Val("txt_region_len", "10")
GUI.Val("txt_region_gap", "5")
GUI.Val("txt_cat_gap", "30")

-- Record tab defaults
GUI.Val("txt_record_port", "8080")

-- Edit tab defaults
GUI.Val("txt_edit_index_filter", "FileName")
GUI.Val("txt_edit_index_prefix", "Index=")
GUI.Val("txt_edit_notion_token", reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_token") or "")
GUI.Val("txt_edit_notion_db_id", getActiveNotionDbId())
GUI.Val("chk_edit_timesel_global", {false})
GUI.Val("chk_render_missing_index_timesel", {false})
-- Clean Up toggles: init from ExtState so "Update Status" is unchecked (hidden) by default
pcall(function()
    if GUI and GUI.elms and GUI.elms.chk_edit_cleanup_update_status and GUI.elms.chk_edit_cleanup_assign_reaper then
        GUI.Val("chk_edit_cleanup_update_status", { getCleanupUpdateStatusEnabled() })
        GUI.Val("chk_edit_cleanup_assign_reaper", { getCleanupAssignReaperSessionEnabled() })
    end
end)

-- Initialize the Clean Up labels from the active preset.
pcall(function()
    if GUI and GUI.elms then
        local db_name = getCleanupSelectedDatabaseName()
        if GUI.elms.lbl_edit_cleanup_db_val then
            GUI.elms.lbl_edit_cleanup_db_val.caption = db_name
        end
        local field = reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_cleanup_status_field") or ""
        local opt = reaper.GetExtState("DMN_GoogleSheetsToRegionsAndMarkers", "notion_cleanup_target_option") or ""
        field = trimWS(field)
        opt = trimWS(opt)
        if GUI.elms.lbl_edit_cleanup_status_field_val then
            GUI.elms.lbl_edit_cleanup_status_field_val.caption = (field ~= "" and field or "(not set)")
        end
        if GUI.elms.lbl_edit_cleanup_status_opt_val then
            GUI.elms.lbl_edit_cleanup_status_opt_val.caption = (opt ~= "" and opt or "(not set)")
        end
    end
end)

-- (ImGui loop continues inside the IIFE opened above)

-- Initialize column mapping rows with saved values
for i = 1, MAX_COLUMNS do
    if i <= active_rows and column_mappings[i] then
        local m = column_mappings[i]
        GUI.Val("txt_name_" .. i, m.name)
        GUI.Val("txt_col_" .. i, tostring(m.col))
        GUI.Val("chk_marker_" .. i, {m.create_marker})
        GUI.Val("chk_region_" .. i, {m.create_region})
        GUI.Val("chk_item_" .. i, {m.create_item})
        GUI.Val("chk_pfx_marker_" .. i, {m.prefix_marker})
        GUI.Val("chk_pfx_region_" .. i, {m.prefix_region})
    end
end

-- Set initial visibility (move unused rows off-screen) and update role button appearances
updateRowVisibility()
updateRoleButtonAppearances()

-- IMGUI MAIN LOOP (ReaImGui)

local show_theme_editor = false
local font_needs_restart = false

local function theme_color_edit(ctx, label, key)
    local c = THEME[key]
    local col_u32 = rgba(c[1], c[2], c[3], c[4])
    local rv, new_col = reaper.ImGui_ColorEdit4(ctx, label, col_u32, reaper.ImGui_ColorEditFlags_AlphaBar())
    if rv then
        local r, g, b, a = reaper.ImGui_ColorConvertU32ToDouble4(new_col)
        THEME[key] = { r, g, b, a }
        apply_theme()
        save_theme()
    end
end

local function draw_theme_editor(ctx)
    if not show_theme_editor then return end
    reaper.ImGui_SetNextWindowSize(ctx, 460, 680, reaper.ImGui_Cond_FirstUseEver())
    local theme_flags = 0
    if reaper.ImGui_WindowFlags_NoDocking then theme_flags = reaper.ImGui_WindowFlags_NoDocking() end
    local vis, open = reaper.ImGui_Begin(ctx, "Theme Editor", true, theme_flags)
    if vis then
        if reaper.ImGui_CollapsingHeader(ctx, "Font") then
            reaper.ImGui_Text(ctx, "Font family")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 220)
            if reaper.ImGui_BeginCombo(ctx, "##font_family", THEME.font_name) then
                for _, fn in ipairs(FONT_OPTIONS) do
                    local is_sel = (fn == THEME.font_name)
                    if reaper.ImGui_Selectable(ctx, fn, is_sel) then
                        THEME.font_name = fn
                        font_needs_restart = true
                    end
                end
                reaper.ImGui_EndCombo(ctx)
            end
            local rv_m, new_m = reaper.ImGui_SliderInt(ctx, "Main size", THEME.font_size_main, 10, 24)
            if rv_m then THEME.font_size_main = new_m; apply_theme(); save_theme() end
            local rv_b, new_b = reaper.ImGui_SliderInt(ctx, "Bold size", THEME.font_size_bold, 10, 28)
            if rv_b then THEME.font_size_bold = new_b; apply_theme(); save_theme() end
            local rv_s, new_s = reaper.ImGui_SliderInt(ctx, "Small size", THEME.font_size_small, 8, 20)
            if rv_s then THEME.font_size_small = new_s; apply_theme(); save_theme() end
            if font_needs_restart then
                reaper.ImGui_TextColored(ctx, rgba(1, 0.8, 0.2, 1), "Font change: save theme and restart script.")
            end
        end
        if reaper.ImGui_CollapsingHeader(ctx, "Text Colours") then
            theme_color_edit(ctx, "Text colour", "text")
            theme_color_edit(ctx, "Disabled text", "text_disabled")
            theme_color_edit(ctx, "Hint text", "hint_text")
        end
        if reaper.ImGui_CollapsingHeader(ctx, "Selection Highlight") then
            theme_color_edit(ctx, "Selection", "selection")
            theme_color_edit(ctx, "Selection hover", "selection_hover")
            theme_color_edit(ctx, "Selection active", "selection_active")
            theme_color_edit(ctx, "Accent", "accent")
            theme_color_edit(ctx, "Accent dim", "accent_dim")
        end
        if reaper.ImGui_CollapsingHeader(ctx, "Style") then
            local rv_fr, new_fr = reaper.ImGui_SliderDouble(ctx, "Frame rounding", THEME.frame_rounding, 0, 12)
            if rv_fr then THEME.frame_rounding = new_fr; save_theme() end
            local rv_gr, new_gr = reaper.ImGui_SliderDouble(ctx, "Grab rounding", THEME.grab_rounding, 0, 12)
            if rv_gr then THEME.grab_rounding = new_gr; save_theme() end
        end
        if reaper.ImGui_CollapsingHeader(ctx, "Window & Popup") then
            theme_color_edit(ctx, "Window bg", "window_bg")
            theme_color_edit(ctx, "Popup bg", "popup_bg")
        end
        if reaper.ImGui_CollapsingHeader(ctx, "Input Fields") then
            theme_color_edit(ctx, "Frame bg", "frame_bg")
            theme_color_edit(ctx, "Frame bg hover", "frame_bg_hover")
        end
        if reaper.ImGui_CollapsingHeader(ctx, "Buttons") then
            theme_color_edit(ctx, "Button", "button")
            theme_color_edit(ctx, "Button hover", "button_hover")
            theme_color_edit(ctx, "Button active", "button_active")
        end
        if reaper.ImGui_CollapsingHeader(ctx, "Tabs") then
            theme_color_edit(ctx, "Tab", "tab")
            theme_color_edit(ctx, "Tab hover", "tab_hover")
            theme_color_edit(ctx, "Tab selected", "tab_selected")
        end
        if reaper.ImGui_CollapsingHeader(ctx, "Headers") then
            theme_color_edit(ctx, "Header", "header")
            theme_color_edit(ctx, "Header hover", "header_hover")
            theme_color_edit(ctx, "Header active", "header_active")
        end
        if reaper.ImGui_CollapsingHeader(ctx, "Table") then
            theme_color_edit(ctx, "Table header bg", "table_header_bg")
            theme_color_edit(ctx, "Table row bg", "table_row_bg")
            theme_color_edit(ctx, "Table row bg alt", "table_row_bg_alt")
        end
        if reaper.ImGui_CollapsingHeader(ctx, "Region / Marker Colors") then
            local cr_on = THEME.color_regions ~= false
            local rv_cr, nv_cr = reaper.ImGui_Checkbox(ctx, "Color regions by category group##theme_color_regions", cr_on)
            if rv_cr then
                THEME.color_regions = nv_cr
                save_theme()
                pcall(function() GUI.Val("chk_colors", { nv_cr == true }) end)
            end
            reaper.ImGui_TextWrapped(ctx, "When importing CSV, each new category group cycles through these colors for entry and category regions.")
            for ri = 1, 8 do
                theme_color_edit(ctx, "Import palette " .. ri, "region_color_" .. ri)
            end
        end
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, "Save Theme") then save_theme(); font_needs_restart = false end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Reset Defaults") then reset_theme(); apply_theme() end
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), "Theme is stored in project ExtState. Restart the script after changing font family.")
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then show_theme_editor = false end
        reaper.ImGui_End(ctx)
    end
    if not open then show_theme_editor = false end
end

local function uim_text(ctx, key, label, width)
    local v = UIM[key] or ""
    if label then
        reaper.ImGui_AlignTextToFramePadding(ctx)
        reaper.ImGui_Text(ctx, label)
        reaper.ImGui_SameLine(ctx)
    end
    reaper.ImGui_SetNextItemWidth(ctx, width or -1)
    local rv, nv = reaper.ImGui_InputText(ctx, "##" .. key, v, reaper.ImGui_InputTextFlags_None())
    if rv then UIM[key] = nv end
end

local function uim_checkbox(ctx, key, label)
    local v = UIM[key] == true
    local rv, nv = reaper.ImGui_Checkbox(ctx, (label or key) .. "##" .. key, v)
    if rv then UIM[key] = nv end
end

local function dmn_btn(ctx, id, label)
    local fn = button_handlers[id]
    if not fn then return end
    if reaper.ImGui_Button(ctx, label or id) then pcall(fn) end
end

local function run_btn(id)
    local fn = button_handlers[id]
    if fn then pcall(fn) end
end

local function draw_import_tab(ctx)
    if reaper.ImGui_SetNextItemOpen and reaper.ImGui_Cond_Once then
        reaper.ImGui_SetNextItemOpen(ctx, true, reaper.ImGui_Cond_Once())
    end
    if reaper.ImGui_CollapsingHeader(ctx, "CSV Source") then
        uim_text(ctx, "txt_url", "URL / file path", -1)
        reaper.ImGui_SameLine(ctx)
        dmn_btn(ctx, "btn_browse", "Browse...")
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), "Google Sheets URL  —or—  paste / browse a local .csv path")
        reaper.ImGui_Spacing(ctx)
        local _bi_fn = button_handlers["btn_browse_import"]
        local _bi_w = reaper.ImGui_GetContentRegionAvail(ctx)
        if _bi_fn and reaper.ImGui_Button(ctx, "Open local CSV file...##browse_import", _bi_w, 0) then
            pcall(_bi_fn)
        end
    end
    if reaper.ImGui_SetNextItemOpen and reaper.ImGui_Cond_Once then
        reaper.ImGui_SetNextItemOpen(ctx, true, reaper.ImGui_Cond_Once())
    end
    if reaper.ImGui_CollapsingHeader(ctx, "Column Mappings") then
        dmn_btn(ctx, "btn_auto_suggest", "Auto Suggest")
        reaper.ImGui_Separator(ctx)
        local tflags = reaper.ImGui_TableFlags_Borders()
                     + reaper.ImGui_TableFlags_RowBg()
                     + reaper.ImGui_TableFlags_Resizable()
                     + reaper.ImGui_TableFlags_SizingStretchProp()
        if reaper.ImGui_BeginTable(ctx, "cols", 11, tflags, 0, 0) then
            reaper.ImGui_TableSetupColumn(ctx, "#",          reaper.ImGui_TableColumnFlags_WidthFixed(),   22)
            reaper.ImGui_TableSetupColumn(ctx, "Name",       reaper.ImGui_TableColumnFlags_WidthStretch(), 0)
            reaper.ImGui_TableSetupColumn(ctx, "Column",     reaper.ImGui_TableColumnFlags_WidthFixed(),   50)
            reaper.ImGui_TableSetupColumn(ctx, "Marker",     reaper.ImGui_TableColumnFlags_WidthFixed(),   46)
            reaper.ImGui_TableSetupColumn(ctx, "Region",     reaper.ImGui_TableColumnFlags_WidthFixed(),   46)
            reaper.ImGui_TableSetupColumn(ctx, "Item",       reaper.ImGui_TableColumnFlags_WidthFixed(),   34)
            reaper.ImGui_TableSetupColumn(ctx, "Tag Marker", reaper.ImGui_TableColumnFlags_WidthFixed(),   72)
            reaper.ImGui_TableSetupColumn(ctx, "Tag Region", reaper.ImGui_TableColumnFlags_WidthFixed(),   72)
            reaper.ImGui_TableSetupColumn(ctx, "Track",      reaper.ImGui_TableColumnFlags_WidthFixed(),   40)
            reaper.ImGui_TableSetupColumn(ctx, "Role",       reaper.ImGui_TableColumnFlags_WidthFixed(),   88)
            reaper.ImGui_TableSetupColumn(ctx, " ",          reaper.ImGui_TableColumnFlags_WidthFixed(),   22)
            reaper.ImGui_TableHeadersRow(ctx)
            for i = 1, active_rows do
                reaper.ImGui_TableNextRow(ctx)
                reaper.ImGui_TableNextColumn(ctx)
                reaper.ImGui_Text(ctx, tostring(i))
                reaper.ImGui_TableNextColumn(ctx)
                uim_text(ctx, "txt_name_" .. i, nil, -1)
                reaper.ImGui_TableNextColumn(ctx)
                uim_text(ctx, "txt_col_" .. i, nil, -1)
                reaper.ImGui_TableNextColumn(ctx)
                uim_checkbox(ctx, "chk_marker_" .. i, "")
                reaper.ImGui_TableNextColumn(ctx)
                uim_checkbox(ctx, "chk_region_" .. i, "")
                reaper.ImGui_TableNextColumn(ctx)
                uim_checkbox(ctx, "chk_item_" .. i, "")
                reaper.ImGui_TableNextColumn(ctx)
                uim_checkbox(ctx, "chk_pfx_marker_" .. i, "")
                reaper.ImGui_TableNextColumn(ctx)
                uim_checkbox(ctx, "chk_pfx_region_" .. i, "")
                reaper.ImGui_TableNextColumn(ctx)
                uim_checkbox(ctx, "chk_track_" .. i, "")
                reaper.ImGui_TableNextColumn(ctx)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), tcol("button"))
                if reaper.ImGui_SmallButton(ctx, (UIM["btn_entry_" .. i] or "E") .. "##e" .. i) then run_btn("btn_entry_" .. i) end
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_SmallButton(ctx, (UIM["btn_category_" .. i] or "C") .. "##c" .. i) then run_btn("btn_category_" .. i) end
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_SmallButton(ctx, (UIM["btn_speaker_" .. i] or "Sp") .. "##sp" .. i) then run_btn("btn_speaker_" .. i) end
                reaper.ImGui_PopStyleColor(ctx, 1)
                reaper.ImGui_TableNextColumn(ctx)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), tcol("button"))
                if reaper.ImGui_SmallButton(ctx, "X##rm" .. i) then run_btn("btn_remove_" .. i) end
                reaper.ImGui_PopStyleColor(ctx, 1)
            end
            reaper.ImGui_EndTable(ctx)
        end
        dmn_btn(ctx, "btn_add", "Add column")
        if not hasEntryColumn() then
            reaper.ImGui_TextColored(ctx, rgba(1, 0.5, 0.2, 1), "Set an Entry column ([E]) for region names.")
        end
        -- Presets (merged into Column Mappings)
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, "Presets")
        reaper.ImGui_Spacing(ctx)
        dmn_btn(ctx, "btn_load_preset", "Load...")
        reaper.ImGui_SameLine(ctx)
        dmn_btn(ctx, "btn_save_preset", "Save As...")
        reaper.ImGui_SameLine(ctx)
        dmn_btn(ctx, "btn_delete_preset", "Delete...")
    end
    if reaper.ImGui_CollapsingHeader(ctx, "Options") then
        uim_text(ctx, "txt_startrow", "Start row", 60)
        uim_checkbox(ctx, "chk_cursor", "Insert at edit cursor")
        uim_checkbox(ctx, "chk_auto_index", "Automatically place Index markers from Entries")
        uim_checkbox(ctx, "chk_auto_id", "Create unique ID= markers for each entry")
        reaper.ImGui_Separator(ctx)
        uim_text(ctx, "txt_region_len", "Region length (sec)", 80)
        uim_text(ctx, "txt_region_gap", "Gap (sec)", 80)
        uim_text(ctx, "txt_cat_gap", "Category gap (sec)", 80)
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), "Region length sets duration per entry. Gap adds space between regions. Category gap adds space when the category group changes.")
    end
    if reaper.ImGui_CollapsingHeader(ctx, "Help") then
        reaper.ImGui_TextWrapped(ctx,
            "Role buttons (click to assign, click again to clear):\n" ..
            "  [E]  Entry    — column text becomes the region name (required).\n" ..
            "  [C]  Category — groups entries into scene blocks; drives color cycling.\n" ..
            "  [Sp] Speaker  — emits a Speaker= marker per entry for the Actor Teleprompter.\n\n" ..
            "Column flags:\n" ..
            "  Marker     — point marker at the region start position.\n" ..
            "  Region     — named region spanning the entry duration.\n" ..
            "  Item       — empty media item on a track named after this column header.\n" ..
            "  Tag Marker — prefix marker text with 'ColumnName=value' (e.g. Delivery=Whisper).\n" ..
            "  Tag Region — prefix region text with 'ColumnName=value'.\n" ..
            "  Track      — create/ensure a REAPER track named after the cell value (e.g. one track per speaker).\n\n" ..
            "Google Sheets: File \226\134\146 Share \226\134\146 Publish to web \226\134\146 CSV, paste the published URL.\n" ..
            "Local CSV: use Browse\226\128\166 or paste a full file path.\n\n" ..
            "Presets save the full column layout so you can reuse it across sessions.\n\n" ..
            "Example Sheets layout:\n" ..
            "  A: Category  B: Speaker  C: Entry  D: Notes\n" ..
            "  Auto Suggest detects these column names automatically and assigns roles/flags.\n\n" ..
            "Category colors are configured under Theme\226\128\166 \226\134\146 Region / Marker Colors.")
    end
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    local _imp_fn = button_handlers["btn_import"]
    local _imp_w  = reaper.ImGui_GetContentRegionAvail(ctx)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x2a7a2aff)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x35a035ff)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x1e5c1eff)
    if _imp_fn and reaper.ImGui_Button(ctx, "Import##main_import", _imp_w, 36) then
        pcall(_imp_fn)
    end
    reaper.ImGui_PopStyleColor(ctx, 3)
    reaper.ImGui_Spacing(ctx)
    dmn_btn(ctx, "btn_cancel", "Close")
end

local function draw_record_tab(ctx)
    reaper.ImGui_TextWrapped(ctx, "Web teleprompter: install HTML into REAPER web root, enable web server, open in browser.")
    reaper.ImGui_Text(ctx, "URL pattern:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, tcol("hint_text"), "http://localhost:<port>/" .. getTeleprompterHtmlBasename())
    uim_text(ctx, "txt_record_port", "Port", 80)
    dmn_btn(ctx, "btn_record_install", "1) Install / update Web UI")
    dmn_btn(ctx, "btn_record_open_browser", "2) Open Web UI in browser")
    dmn_btn(ctx, "btn_record_prefs", "Open Web/OSC preferences")
    dmn_btn(ctx, "btn_record_show_webroot", "Show REAPER web root path")
end

-- Button with explicit fill-width
local function dmn_btn_w(ctx, id, label, w)
    local fn = button_handlers[id]
    if not fn then return end
    if reaper.ImGui_Button(ctx, label .. "##" .. id, w) then pcall(fn) end
end

local function draw_edit_tab(ctx)
    -- ── Timeline Tools ────────────────────────────────────────────────────────
    if reaper.ImGui_CollapsingHeader(ctx, "Timeline Tools") then
        uim_checkbox(ctx, "chk_edit_timesel_global", "Apply to time selection only")
        reaper.ImGui_Spacing(ctx)
        -- Row 1
        local hw = (reaper.ImGui_GetContentRegionAvail(ctx) - 8) * 0.5
        dmn_btn_w(ctx, "btn_edit_snap_items",          "Snap items to regions",   hw)
        reaper.ImGui_SameLine(ctx)
        dmn_btn_w(ctx, "btn_edit_marker_from_region",  "Marker from region",      hw)
    end

    -- ── Notion ────────────────────────────────────────────────────────────────
    if reaper.ImGui_CollapsingHeader(ctx, "Notion") then
        -- Token row
        reaper.ImGui_AlignTextToFramePadding(ctx)
        reaper.ImGui_Text(ctx, "Token")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, -110)
        local rv_tok, nv_tok = reaper.ImGui_InputText(ctx, "##txt_edit_notion_token", UIM["txt_edit_notion_token"] or "", reaper.ImGui_InputTextFlags_Password())
        if rv_tok then UIM["txt_edit_notion_token"] = nv_tok end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Save##token_save", 52) then run_btn("btn_edit_notion_token_save") end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Test##token_test", 50) then run_btn("btn_edit_notion_token_test") end

        -- Database row
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_AlignTextToFramePadding(ctx)
        reaper.ImGui_Text(ctx, "Database")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, -166)
        local rv_db, nv_db = reaper.ImGui_InputText(ctx, "##txt_edit_notion_db_id", UIM["txt_edit_notion_db_id"] or "", 0)
        if rv_db then UIM["txt_edit_notion_db_id"] = nv_db end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Save as preset##db_save", 100) then run_btn("btn_edit_notion_db_save_as") end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Load##db_pick", 58) then run_btn("btn_edit_notion_preset_pick") end

        local preset = getActiveNotionDbName()
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), "Active: " .. (preset ~= "" and preset or "(none)"))

        -- Actions row
        reaper.ImGui_Spacing(ctx)
        local hw2 = (reaper.ImGui_GetContentRegionAvail(ctx) - 8) * 0.5
        dmn_btn_w(ctx, "btn_edit_notion_create_id",   "Add ID markers",     hw2)
        reaper.ImGui_SameLine(ctx)
        dmn_btn_w(ctx, "btn_edit_notion_sync_index",  "Sync Index markers", hw2)
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), "Add ID markers: creates ID= markers on regions by matching Notion entries.\nSync Index: fills Index= markers from Notion IDs.")

        -- ── Clean Up (sub-section inside Notion) ──────────────────────────────
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, "Clean Up  —  update Notion status from recorded audio")
        reaper.ImGui_Spacing(ctx)

        uim_checkbox(ctx, "chk_edit_cleanup_update_status", "Update Status field in Notion")
        uim_checkbox(ctx, "chk_edit_cleanup_assign_reaper", "Write session name to Notion")
        reaper.ImGui_Spacing(ctx)

        -- Status field row
        local sf = UIM["lbl_edit_cleanup_status_field_val"] or "(not set)"
        local so = UIM["lbl_edit_cleanup_status_opt_val"] or "(not set)"
        reaper.ImGui_AlignTextToFramePadding(ctx)
        reaper.ImGui_Text(ctx, "Status field")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), sf)
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_SmallButton(ctx, "Pick##sf") then run_btn("btn_edit_cleanup_pick_status_field") end

        reaper.ImGui_AlignTextToFramePadding(ctx)
        reaper.ImGui_Text(ctx, "Target option")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), so)
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_SmallButton(ctx, "Pick##so") then run_btn("btn_edit_cleanup_pick_status_opt") end

        reaper.ImGui_Spacing(ctx)
        local fw = reaper.ImGui_GetContentRegionAvail(ctx)
        dmn_btn_w(ctx, "btn_edit_cleanup_run", "Run Clean Up", fw)
    end
end

-- ============================================================================
-- RENDER TAB HELPERS
-- ============================================================================

-- Resolve token list to a preview string using the first Entry region found in project
-- resolveTokensPreview: resolves a token list to a preview string.
-- Mirrors REAPER's own wildcard substitution:
--   $marker(Name)    → value after "Name=" in the nearest preceding marker
--   $markername      → full name of nearest preceding marker
--   $markernumber    → index of nearest preceding marker
--   $region(Name)    → region whose name starts with "Name=" (value after =)
--   $region / $regionname → name of nearest region
--   $regionnumber    → number of nearest region
--   $track           → selected track name
--   $date            → YYYYMMDD
--   $project         → project name (no extension)
-- Falls back to placeholder text when no project data is available.
local function resolveTokensPreview(tokens)
    -- ── Collect project data ──────────────────────────────────────────────────
    local named_markers = {}  -- keyed by lowercase prefix name → value
    local first_marker_name = ""
    local first_marker_num  = 0
    local region_name   = ""
    local region_num    = 0
    local named_regions = {}  -- keyed by lowercase prefix name → value

    local num_markers = reaper.CountProjectMarkers(0)

    -- Pass 1: collect all markers and regions
    local all_markers = {}
    local all_regions = {}
    for mi = 0, num_markers - 1 do
        local _, is_rgn, pos, rend, name, idx = reaper.EnumProjectMarkers(mi)
        if is_rgn then
            all_regions[#all_regions + 1] = { pos = pos, rend = rend, name = name or "", idx = idx }
            -- named region: "Prefix=value"
            local prefix, val = (name or ""):match("^([^=]+)=(.+)$")
            if prefix then named_regions[prefix:lower()] = val end
        else
            all_markers[#all_markers + 1] = { pos = pos, name = name or "", idx = idx }
            -- named marker: "Prefix=value"
            local prefix, val = (name or ""):match("^([^=]+)=(.+)$")
            if prefix then
                if not named_markers[prefix:lower()] then
                    named_markers[prefix:lower()] = val
                end
            end
            if first_marker_name == "" then
                first_marker_name = name or ""
                first_marker_num  = idx or 0
            end
        end
    end

    -- Use first region as the "current" region for $region wildcards
    if #all_regions > 0 then
        local r = all_regions[1]
        region_name = r.name:gsub("^Entry=", "")  -- strip "Entry=" prefix if present
        region_num  = r.idx or 1
    end

    -- Track name
    local track_val = "Track"
    local sel_track = reaper.GetSelectedTrack(0, 0)
    if sel_track then
        local ok, tname = reaper.GetTrackName(sel_track)
        if ok and tname and tname ~= "" then track_val = tname end
    end

    -- Project name
    local proj_name = ""
    local proj_path = reaper.GetProjectPath("")
    if proj_path and proj_path ~= "" then
        proj_name = proj_path:match("([^\\/]+)$") or ""
        proj_name = proj_name:gsub("%.rpp$", "")
    end
    if proj_name == "" then proj_name = "Project" end

    -- ── Substitution function for a single token ──────────────────────────────
    local function resolveOne(tok)
        -- $marker(Name)  → named marker value (case-insensitive prefix match)
        tok = tok:gsub("%$marker%(([^%)]+)%)", function(name)
            return named_markers[name:lower()] or ("$marker(" .. name .. ")")
        end)
        -- $region(Name)  → named region value
        tok = tok:gsub("%$region%(([^%)]+)%)", function(name)
            return named_regions[name:lower()] or ("$region(" .. name .. ")")
        end)
        -- $markername / $marker  → first marker's full name
        tok = tok:gsub("%$markername", first_marker_name ~= "" and first_marker_name or "$markername")
        tok = tok:gsub("%$markernumber", tostring(first_marker_num))
        -- $regionname / $region  → first region's name
        tok = tok:gsub("%$regionname",   region_name ~= "" and region_name or "$regionname")
        tok = tok:gsub("%$regionnumber", tostring(region_num))
        tok = tok:gsub("%$region",       region_name ~= "" and region_name or "$region")
        -- $track
        tok = tok:gsub("%$track", track_val)
        -- $date
        tok = tok:gsub("%$date", os.date("%Y%m%d"))
        -- $project
        tok = tok:gsub("%$project", proj_name)
        return tok
    end

    local out = ""
    for _, tok in ipairs(tokens) do
        out = out .. resolveOne(tok)
    end
    return out
end

-- Render a horizontal token strip with drag-and-drop reordering.
-- Each token: [drag-handle][text field][x]  — drag the handle to reorder, x to remove.
local DND_TYPE_PREFIX = "DND_TOK_"
local function drawTokenStrip(ctx, tokens, strip_id, quick_tokens)
    local changed   = false
    local to_remove = nil
    local move_from, move_to = nil, nil
    local dnd_type  = DND_TYPE_PREFIX .. strip_id

    for i, tok in ipairs(tokens) do
        if i > 1 then reaper.ImGui_SameLine(ctx) end
        reaper.ImGui_PushID(ctx, strip_id .. "_t" .. i)

        -- Drag handle — small grip button
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x404040ff)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x606060ff)
        reaper.ImGui_Button(ctx, "::", 18, 0)
        reaper.ImGui_PopStyleColor(ctx, 2)
        -- Drag source
        if reaper.ImGui_BeginDragDropSource(ctx) then
            reaper.ImGui_SetDragDropPayload(ctx, dnd_type, tostring(i))
            reaper.ImGui_Text(ctx, tok ~= "" and tok or "(empty)")
            reaper.ImGui_EndDragDropSource(ctx)
        end
        -- Drop target on handle
        if reaper.ImGui_BeginDragDropTarget(ctx) then
            local rv, payload = reaper.ImGui_AcceptDragDropPayload(ctx, dnd_type)
            if rv then move_from = tonumber(payload); move_to = i end
            reaper.ImGui_EndDragDropTarget(ctx)
        end

        reaper.ImGui_SameLine(ctx)

        -- Editable text field
        local field_w = math.max(28, math.min(200, #tok * 8 + 18))
        reaper.ImGui_SetNextItemWidth(ctx, field_w)
        local rv_t, new_tok = reaper.ImGui_InputText(ctx, "##inp", tok)
        if rv_t then tokens[i] = new_tok; changed = true end
        -- Drop target on text field too
        if reaper.ImGui_BeginDragDropTarget(ctx) then
            local rv2, payload = reaper.ImGui_AcceptDragDropPayload(ctx, dnd_type)
            if rv2 then move_from = tonumber(payload); move_to = i end
            reaper.ImGui_EndDragDropTarget(ctx)
        end

        reaper.ImGui_SameLine(ctx)

        -- Remove
        if reaper.ImGui_SmallButton(ctx, "x") then
            to_remove = i; changed = true
        end

        reaper.ImGui_PopID(ctx)
    end

    -- [+] add token
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_SmallButton(ctx, "+ ##addtok_" .. strip_id) then
        reaper.ImGui_OpenPopup(ctx, "addtok_popup_" .. strip_id)
    end

    -- Deferred mutations (only one can fire per frame)
    if move_from and move_to and move_from ~= move_to then
        local moving = table.remove(tokens, move_from)
        table.insert(tokens, move_to, moving)
        changed = true
    elseif to_remove then
        table.remove(tokens, to_remove)
    end

    if reaper.ImGui_BeginPopup(ctx, "addtok_popup_" .. strip_id) then
        reaper.ImGui_Text(ctx, "Insert wildcard:")
        reaper.ImGui_Separator(ctx)
        for _, qt in ipairs(quick_tokens) do
            if reaper.ImGui_Selectable(ctx, qt .. "##qt_" .. strip_id) then
                tokens[#tokens + 1] = qt; changed = true
                reaper.ImGui_CloseCurrentPopup(ctx)
            end
        end
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Selectable(ctx, "[ custom text ]##qt_custom_" .. strip_id) then
            tokens[#tokens + 1] = ""; changed = true
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        reaper.ImGui_EndPopup(ctx)
    end

    return changed
end

-- Note: REAPER wildcards are case-sensitive when matching "Name=value" markers.
-- Use the same capitalisation as your marker names (e.g. Speaker=, Category=, Index=).
local QUICK_TOKENS = {
    "$marker(Speaker)", "$marker(Category)", "$marker(Index)",
    "$region", "$regionname", "$regionnumber",
    "$markername", "$markernumber",
    "$track", "$date", "$project", "_", "-",
}

-- ============================================================================
-- RENDER TAB
-- ============================================================================
local function draw_render_tab(ctx)
    local tokens_changed = false

    -- ── Output ────────────────────────────────────────────────────────────────
    if reaper.ImGui_SetNextItemOpen then
        reaper.ImGui_SetNextItemOpen(ctx, true, reaper.ImGui_Cond_Once())
    end
    if reaper.ImGui_CollapsingHeader(ctx, "Output") then
        -- Path row
        reaper.ImGui_Text(ctx, "Path")
        reaper.ImGui_SameLine(ctx)
        local path_w = reaper.ImGui_GetContentRegionAvail(ctx) - 160
        reaper.ImGui_SetNextItemWidth(ctx, math.max(80, path_w))
        local rv_path, new_path = reaper.ImGui_InputText(ctx, "##render_path", render_output_path)
        if rv_path then render_output_path = new_path; saveRenderSettings() end

        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Browse...##rpath") then
            if reaper.JS_Dialog_BrowseForFolder then
                local rv2, folder = reaper.JS_Dialog_BrowseForFolder("Select render output folder", render_output_path)
                if rv2 == 1 then render_output_path = folder; saveRenderSettings() end
            else
                reaper.ShowMessageBox("js_ReaScriptAPI extension required for folder browsing.\nInstall via ReaPack.", "Missing Extension", 0)
            end
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Open##rpath_open") then
            if render_output_path ~= "" then
                reaper.CF_ShellExecute(render_output_path)
            end
        end

        reaper.ImGui_Spacing(ctx)

        -- Sample rate
        local sr_label = tostring(render_sample_rate) .. " Hz"
        for si, sr in ipairs(RENDER_OPTS.sample_rates) do
            if sr == render_sample_rate then sr_label = RENDER_OPTS.sample_rate_labels[si]; break end
        end
        reaper.ImGui_SetNextItemWidth(ctx, 130)
        if reaper.ImGui_BeginCombo(ctx, "Sample Rate##sr", sr_label) then
            for si, sr in ipairs(RENDER_OPTS.sample_rates) do
                if reaper.ImGui_Selectable(ctx, RENDER_OPTS.sample_rate_labels[si] .. "##sr" .. si, sr == render_sample_rate) then
                    render_sample_rate = sr; saveRenderSettings()
                end
            end
            reaper.ImGui_EndCombo(ctx)
        end

        reaper.ImGui_SameLine(ctx)

        -- Channels
        local ch_label = tostring(render_channels) .. " ch"
        for ci, ch in ipairs(RENDER_OPTS.channel_options) do
            if ch == render_channels then ch_label = RENDER_OPTS.channel_labels[ci]; break end
        end
        reaper.ImGui_SetNextItemWidth(ctx, 130)
        if reaper.ImGui_BeginCombo(ctx, "Channels##ch", ch_label) then
            for ci, ch in ipairs(RENDER_OPTS.channel_options) do
                if reaper.ImGui_Selectable(ctx, RENDER_OPTS.channel_labels[ci] .. "##ch" .. ci, ch == render_channels) then
                    render_channels = ch; saveRenderSettings()
                end
            end
            reaper.ImGui_EndCombo(ctx)
        end

        reaper.ImGui_Spacing(ctx)

        -- Normalize (TheBaptist style — mode+target only visible when toggled on)
        local rv_norm, new_norm = reaper.ImGui_Checkbox(ctx, "Normalize##norm", render_normalize)
        if rv_norm then render_normalize = new_norm; saveRenderSettings() end

        if render_normalize then
            reaper.ImGui_SameLine(ctx)
            local nm_label = RENDER_OPTS.normalize_mode_labels[1]
            for ni, nm in ipairs(RENDER_OPTS.normalize_modes) do
                if nm == render_normalize_mode then nm_label = RENDER_OPTS.normalize_mode_labels[ni]; break end
            end
            reaper.ImGui_SetNextItemWidth(ctx, 120)
            if reaper.ImGui_BeginCombo(ctx, "Mode##nm", nm_label) then
                for ni, nm in ipairs(RENDER_OPTS.normalize_modes) do
                    if reaper.ImGui_Selectable(ctx, RENDER_OPTS.normalize_mode_labels[ni] .. "##nm" .. ni, nm == render_normalize_mode) then
                        render_normalize_mode = nm; saveRenderSettings()
                    end
                end
                reaper.ImGui_EndCombo(ctx)
            end
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 70)
            local rv_nt, new_nt = reaper.ImGui_InputText(ctx, "dB##ntarget", render_normalize_target, reaper.ImGui_InputTextFlags_EnterReturnsTrue())
            if rv_nt then render_normalize_target = new_nt; saveRenderSettings() end
        end

        reaper.ImGui_Spacing(ctx)

        -- BWF metadata
        local rv_bwf, new_bwf = reaper.ImGui_Checkbox(ctx, "Write BWF metadata##bwf", render_write_metadata)
        if rv_bwf then render_write_metadata = new_bwf; saveRenderSettings() end
        if render_write_metadata then
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 290)
            if reaper.ImGui_BeginCombo(ctx, "##bwf_mode", BWF_EMBED_MODES[render_metadata_mode_idx].label) then
                for mi, mode in ipairs(BWF_EMBED_MODES) do
                    local is_sel = (mi == render_metadata_mode_idx)
                    if reaper.ImGui_Selectable(ctx, mode.label .. "##bwfm" .. mi, is_sel) then
                        render_metadata_mode_idx = mi; saveRenderSettings()
                    end
                    if is_sel then reaper.ImGui_SetItemDefaultFocus(ctx) end
                end
                reaper.ImGui_EndCombo(ctx)
            end
        end

        -- Fade-out
        local rv_fo, new_fo = reaper.ImGui_Checkbox(ctx, "Fade-out##fadeout", render_fadeout)
        if rv_fo then render_fadeout = new_fo; saveRenderSettings() end
        if render_fadeout then
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 80)
            local rv_foms, new_foms = reaper.ImGui_InputText(ctx, "ms##fadeout_ms", render_fadeout_ms, reaper.ImGui_InputTextFlags_EnterReturnsTrue())
            if rv_foms then render_fadeout_ms = new_foms; saveRenderSettings() end
        end
    end

    -- ── Source ────────────────────────────────────────────────────────────────
    reaper.ImGui_Spacing(ctx)
    if reaper.ImGui_CollapsingHeader(ctx, "Source") then
        -- Source dropdown (mirrors REAPER Render → Source)
        reaper.ImGui_Text(ctx, "Source:")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, 280)
        if reaper.ImGui_BeginCombo(ctx, "##render_source", RENDER_SOURCES[render_source_idx].label) then
            for si, src in ipairs(RENDER_SOURCES) do
                local is_sel = (si == render_source_idx)
                if reaper.ImGui_Selectable(ctx, src.label .. "##rsrc" .. si, is_sel) then
                    render_source_idx = si; saveRenderSettings()
                end
                if is_sel then reaper.ImGui_SetItemDefaultFocus(ctx) end
            end
            reaper.ImGui_EndCombo(ctx)
        end

        -- Bounds dropdown (mirrors REAPER Render → Bounds)
        reaper.ImGui_Text(ctx, "Bounds:")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, 280)
        if reaper.ImGui_BeginCombo(ctx, "##render_bounds", RENDER_BOUNDS[render_bounds_idx].label) then
            for bi, bnd in ipairs(RENDER_BOUNDS) do
                local is_sel = (bi == render_bounds_idx)
                if reaper.ImGui_Selectable(ctx, bnd.label .. "##rbnd" .. bi, is_sel) then
                    render_bounds_idx = bi; saveRenderSettings()
                end
                if is_sel then reaper.ImGui_SetItemDefaultFocus(ctx) end
            end
            reaper.ImGui_EndCombo(ctx)
        end
    end

    -- ── Filename Builder ──────────────────────────────────────────────────────
    reaper.ImGui_Spacing(ctx)
    if reaper.ImGui_CollapsingHeader(ctx, "Filename Builder") then
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), "Each block is a literal or REAPER wildcard. Drag :: to reorder, x to remove.")
        reaper.ImGui_Spacing(ctx)

        reaper.ImGui_Text(ctx, "Folder: ")
        reaper.ImGui_SameLine(ctx)
        if drawTokenStrip(ctx, render_folder_tokens, "folder", QUICK_TOKENS) then
            tokens_changed = true
        end

        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Text(ctx, "File:   ")
        reaper.ImGui_SameLine(ctx)
        if drawTokenStrip(ctx, render_file_tokens, "file", QUICK_TOKENS) then
            tokens_changed = true
        end

        if tokens_changed then saveRenderSettings() end

        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)

        -- Quick-insert hint row (correct REAPER capitalisation for named markers)
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), "Quick add to File:")
        for _, qt in ipairs({ "$marker(Speaker)", "$marker(Category)", "$marker(Index)", "$region", "$regionnumber", "$markernumber", "$track", "$date" }) do
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_SmallButton(ctx, qt) then
                render_file_tokens[#render_file_tokens + 1] = qt
                saveRenderSettings()
            end
        end

        reaper.ImGui_Spacing(ctx)

        -- ── Live preview ────────────────────────────────────────────────────────
        -- Shows wildcards resolved from the current project, plus source/time-sel context.
        local folder_preview = resolveTokensPreview(render_folder_tokens)
        local file_preview   = resolveTokensPreview(render_file_tokens)

        local base_path = render_output_path ~= "" and render_output_path or "<output path>"
        -- Normalise separators for display
        local sep = base_path:find("\\") and "\\" or "/"
        base_path = base_path:gsub("[/\\]$", "")  -- strip trailing slash

        local preview_str = base_path .. sep .. folder_preview:gsub("[/\\]", sep) ..
                            sep .. file_preview .. ".wav"

        -- Show active source & bounds for context
        reaper.ImGui_TextColored(ctx, tcol("hint_text"),
            "Source: " .. RENDER_SOURCES[render_source_idx].label ..
            "  |  Bounds: " .. RENDER_BOUNDS[render_bounds_idx].label)
        reaper.ImGui_TextColored(ctx, tcol("hint_text"), "Preview:")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextWrapped(ctx, preview_str)
        reaper.ImGui_TextColored(ctx, tcol("hint_text"),
            "  Note: wildcards like $marker(Speaker) resolve from the first matching\n"..
            "  marker in your project. The exact names depend on what is in the timeline.")
    end

    -- ── Render button ─────────────────────────────────────────────────────────
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x2a7a2aff)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x35a035ff)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x1e5c1eff)
    local render_w = reaper.ImGui_GetContentRegionAvail(ctx)
    local do_render = reaper.ImGui_Button(ctx, "Open Render Dialog...##rendergo", render_w, 36)
    reaper.ImGui_PopStyleColor(ctx, 3)

    if do_render then
        -- Build raw template string (wildcards NOT resolved — passed to REAPER)
        local folder_str = table.concat(render_folder_tokens, "")
        local file_str   = table.concat(render_file_tokens,   "")
        -- REAPER render pattern: $folder/$filename (no extension, REAPER appends it)
        local pattern = folder_str .. "/" .. file_str

        if render_output_path ~= "" then
            reaper.GetSetProjectInfo_String(0, "RENDER_FILE", render_output_path, true)
        end
        reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", pattern, true)
        reaper.GetSetProjectInfo(0, "RENDER_SRATE",    render_sample_rate, true)
        reaper.GetSetProjectInfo(0, "RENDER_CHANNELS", render_channels,    true)

        -- Source → RENDER_SETTINGS (preserve bits above the source range)
        local cur_settings = reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 0, false)
        local source_mask = 1 + 2 + 8 + 32 + 64 + 128  -- all source-related bits
        cur_settings = math.floor(cur_settings) & ~source_mask
        cur_settings = cur_settings | RENDER_SOURCES[render_source_idx].settings
        reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", cur_settings, true)

        -- Bounds → RENDER_BOUNDSFLAG
        reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", RENDER_BOUNDS[render_bounds_idx].value, true)

        -- Normalize
        reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE",        render_normalize and 1 or 0, true)
        if render_normalize then
            reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE_MODE",   render_normalize_mode,                      true)
            reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE_TARGET", tonumber(render_normalize_target) or -24.0, true)
        end

        -- BWF metadata embed mode (RENDER_METADATA: 0 = off, 1-6 = embed modes)
        local meta_value = render_write_metadata and BWF_EMBED_MODES[render_metadata_mode_idx].value or 0
        reaper.GetSetProjectInfo(0, "RENDER_METADATA", meta_value, true)

        -- Fade-out (RENDER_FADEOUT in seconds; 0 disables)
        local fadeout_sec = render_fadeout and ((tonumber(render_fadeout_ms) or 300) / 1000.0) or 0
        reaper.GetSetProjectInfo(0, "RENDER_FADEOUT", fadeout_sec, true)

        -- Open native REAPER render dialog (user confirms + clicks Render there)
        reaper.Main_OnCommand(40015, 0)
    end
end

local _init_done = false
local _last_cleanup_update_status = nil
local _last_cleanup_assign_reaper = nil

local function imgui_frame()
    if GUI.quit then return end

    if not _init_done then
        _init_done = true
        switchToTab(1)
        updateRowVisibility()
        updateRoleButtonAppearances()
    end

    if TABS[active_tab] == "Edit" then
        local update_on = chkBool(GUI.Val("chk_edit_cleanup_update_status"))
        local reaper_on = chkBool(GUI.Val("chk_edit_cleanup_assign_reaper"))
        if update_on ~= _last_cleanup_update_status then
            _last_cleanup_update_status = update_on
            if setCleanupUpdateStatusEnabled then setCleanupUpdateStatusEnabled(update_on == true) end
            if setCleanupStatusRowVisible then setCleanupStatusRowVisible(update_on == true) end
        end
        if reaper_on ~= _last_cleanup_assign_reaper then
            _last_cleanup_assign_reaper = reaper_on
            if setCleanupAssignReaperSessionEnabled then setCleanupAssignReaperSessionEnabled(reaper_on == true) end
        end
    end

    local ctx = imgui_ctx

    reaper.ImGui_PushFont(ctx, font_main, FONT_SIZE_MAIN)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), tcol("text"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextDisabled(), tcol("text_disabled"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), tcol("window_bg"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(), tcol("popup_bg"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), tcol("frame_bg"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), tcol("frame_bg_hover"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), tcol("button"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), tcol("button_hover"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), tcol("button_active"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Tab(), tcol("tab"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabHovered(), tcol("tab_hover"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabSelected(), tcol("tab_selected"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), tcol("header"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), tcol("header_hover"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), tcol("header_active"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableHeaderBg(), tcol("table_header_bg"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableRowBg(), tcol("table_row_bg"))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableRowBgAlt(), tcol("table_row_bg_alt"))
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), THEME.frame_rounding)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(), THEME.grab_rounding)

    reaper.ImGui_SetNextWindowSize(ctx, 960, 780, reaper.ImGui_Cond_FirstUseEver())
    local vis, open = reaper.ImGui_Begin(ctx, "DMN Dialogue Workflow", true)
    if vis then
        if reaper.ImGui_Button(ctx, "Theme...") then show_theme_editor = not show_theme_editor end
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_BeginTabBar(ctx, "dmntabs", 0) then
            for i, tab in ipairs(TABS) do
                if reaper.ImGui_BeginTabItem(ctx, tab, nil, 0) then
                    active_tab = i
                    if tab == "Import" then draw_import_tab(ctx)
                    elseif tab == "Record" then draw_record_tab(ctx)
                    elseif tab == "Edit" then draw_edit_tab(ctx)
                    elseif tab == "Render" then draw_render_tab(ctx)
                    end
                    reaper.ImGui_EndTabItem(ctx)
                end
            end
            reaper.ImGui_EndTabBar(ctx)
        end
        reaper.ImGui_End(ctx)
    end

    draw_theme_editor(ctx)

    reaper.ImGui_PopStyleVar(ctx, 2)
    reaper.ImGui_PopStyleColor(ctx, 18)
    reaper.ImGui_PopFont(ctx)

    if open and not GUI.quit then
        reaper.defer(imgui_frame)
    end
end

-- Replace Lokasenna per-frame func
GUI.func = function() end
GUI.freq = 0

reaper.defer(function()
    reaper.defer(function()
        if refreshCleanupStatusLabels then pcall(refreshCleanupStatusLabels) end
    end)
end)

reaper.defer(imgui_frame)

end)()
