# Game Audio Dialogue Workflow

Tools for **Cockos REAPER** that connect spreadsheet-driven dialogue data, optional **Notion** integration, an **actor-facing web teleprompter**, and a configurable **render pipeline** — all in one window.

## Repository structure

```
DialogueWorkflow/
├── Scripts/
│   ├── DMN_DialogueWorkflow.lua        # Main REAPER script (Import / Record / Edit / Render)
│   ├── DMN_ActorTeleprompter.html      # REAPER Web Interface — actor teleprompter
│   └── DMN_DialogueWorkflow/           # Lua modules loaded by the main script
│       ├── edit_tools.lua              # Timeline editing utilities (snap, markers, speaker mover)
│       └── project_search.lua          # Cross-project search engine (RPP parser, find & replace)
├── Samples/
│   ├── demo_shakespeare_hamlet_act5_scene1.csv
│   ├── demo_shakespeare_multi_scene.csv
│   ├── demo_pacman_dialogue.csv
│   └── Reaper_Shakespeare_Hamlet/
│       └── Reaper_Shakespeare_Hamlet.rpp
├── LICENSE
└── README.md
```

The teleprompter and the markers/regions created by the script share the same **naming conventions** (see [Marker and region conventions](#marker-and-region-conventions)).

---

## Requirements

- **REAPER** (tested on 7.x)
- **ReaImGui** — required for `DMN_DialogueWorkflow.lua`. Install via **Extensions → ReaPack → Browse packages**, search `ReaImGui`.
- **js_ReaScriptAPI** (optional) — enables the **Browse…** button for local CSV files and render output paths.
- **REAPER Web Interface** enabled — for `DMN_ActorTeleprompter.html`.
- **Notion** (optional) — for Edit-tab Notion features; requires an integration token and a database with the expected properties. Some operations use **PowerShell** on **Windows**.

> **Security note:** Your Notion integration token is stored in REAPER's local `reaper-extstate.ini` file — it never appears in any script file and is never committed to version control.

---

## Installation

### 1. Install ReaImGui

1. **Extensions → ReaPack → Browse packages**
2. Search **ReaImGui**
3. Install the latest version

### 2. Install the main script

Copy both files from the **`Scripts/`** folder — **`DMN_DialogueWorkflow.lua`** and **`DMN_ActorTeleprompter.html`** — into your REAPER **Scripts** folder (keep them in the same directory). Then **Load** the Lua script from the Actions window or assign it to a toolbar.

### 3. Install the actor web page

**Option A — via the script:**
Open the **Record** tab and click **Install / update Web UI**. The script locates the HTML next to itself and copies it into `reaper_www_root`.

**Option B — manually:**
1. **Options → Show REAPER resource path**, open **`reaper_www_root`** (create it if missing).
2. Copy **`Scripts/DMN_ActorTeleprompter.html`** there, and optionally **`Logo.png`** for the corner logo.

### 4. Enable the Web Interface

**Options → Preferences → Control/OSC/web** — enable **Web control** and note the port (default **8080**).

### 5. Open the teleprompter

```
http://127.0.0.1:<port>/DMN_ActorTeleprompter.html
```

Use your machine's LAN IP when opening from a tablet or another device (allow the port in the firewall if needed).

---

## Feature reference

The script opens a **single window** with five tabs: **Import**, **Record**, **Navigator**, **Edit**, and **Render**.

---

### Import tab — CSV → timeline

#### CSV Source
Paste a **published Google Sheets CSV URL** or a **local `.csv` file path**. Use **Open local CSV file…** to browse for a file on disk.

#### Column Mappings

Defines how each CSV column maps to timeline objects. Columns are user-draggable (headers are resizable).

| Column | What it does |
|--------|-------------|
| **#** | Row number |
| **Name** | Column header name as it appears in your CSV |
| **Column** | CSV column number (1-based) |
| **Marker** | Create a point marker at the region start position |
| **Region** | Create a named region spanning the entry duration |
| **Item** | Place an empty media item on a track named after this column header |
| **Tag Marker** | Prefix marker text with `ColumnName=value` (e.g. `Delivery=Whisper`) |
| **Tag Region** | Prefix region text with `ColumnName=value` |
| **Track** | Create / ensure a REAPER track named after the **cell value** (e.g. one track per speaker) |
| **Role** | Assign a special role to this column (see below) |

**Role buttons** (click to assign, click again to clear):

| Button | Role |
|--------|------|
| **[E]** Entry | Column text becomes the region name — required for import to work |
| **[C]** Category | Groups entries into scene/category blocks; drives parent regions and color cycling |
| **[Sp]** Speaker | Emits a `Speaker=<value>` marker per entry — used by the Actor Teleprompter to display who speaks |

**Auto Suggest** reads the CSV header row and auto-assigns roles and flags based on common column names:
- `Category`, `Group`, `Scene`, `Parent`, `Context` → Category role
- `Entry`, `Line`, `Dialogue`, `Variation`, `Text`, `Name` → Entry role
- `Speaker`, `Character`, `Actor`, `Voice`, `Narrator` → Speaker role + Track flag
- `Notes`, `Note`, `Description`, `Comment`, `Direction` → Item flag

**Presets** (inside Column Mappings) — **Load**, **Save As…**, **Delete** — stores the full column layout in REAPER ExtState.

#### Options

- **Start row** — skip header rows (default: 2)
- **Insert at edit cursor** — place regions at cursor instead of project start
- **Derive index from name suffix** — extract `Index=NN` markers from a chosen column's value
- **Region length / Gap / Category gap** — timing for generated regions

#### Help

In-app help with role and flag descriptions, Google Sheets setup instructions, and an example column layout.

---

### Record tab — web teleprompter helpers

- **URL pattern** — shows the localhost URL for the actor page based on the configured port
- **Install / update Web UI** — copies `DMN_ActorTeleprompter.html` into `reaper_www_root`
- **Open Web UI in browser** — opens the teleprompter URL
- **Open Web/OSC preferences** — jump to REAPER preferences to enable the web server
- **Show REAPER web root path** — displays the `reaper_www_root` folder location

#### Actor Teleprompter — keyboard shortcuts

The teleprompter web page supports keyboard shortcuts for all major actions. Open the **Preferences** panel (gear icon) and click **? View & Customize** to see all bindings or reassign them. Custom bindings are saved in the browser's local storage.

Default shortcuts:

| Key | Action |
|-----|--------|
| `Space` | Play |
| `Q` | Stop |
| `R` | Record |
| `←` / `→` | Previous / Next entry |
| `Shift+←` / `Shift+→` | Previous / Next entry for active speaker |
| `↑` / `↓` | Previous / Next speaker (track) |
| `,` / `.` | Previous / Next category |
| `T` | Arm track for current speaker |
| `C` | Toggle context lines |
| `B` | Toggle browse panel |
| `P` | Toggle preferences |
| `-` / `+` | Decrease / Increase font size |

Shortcuts are disabled while typing in the browse search field.

---

### Navigator tab — timeline navigation & cross-project search

The Navigator tab has two sub-tabs: **Navigator** and **Project Search**. Both are available docked inside the main window or in a **pop-out** floating window.

#### Navigator (sub-tab)

Lists all dialogue entries, categories, and speakers currently on the timeline. Click any row to move the edit cursor. Tracks the active entry and auto-scrolls to keep it visible.

#### Project Search (sub-tab)

Searches markers, regions, tracks, and items across multiple REAPER `.rpp` project files **without opening them** — the scanner reads `.rpp` files as text.

**Setup** — add project folders or individual `.rpp` file paths. Options:
- **Include subfolders** — scan nested directories recursively
- **Discover .rpp files** — auto-find all `.rpp` files in configured folders
- **Presets** — save and load folder lists for different projects
- **Scan Projects** — parse all configured `.rpp` files and index their contents

**Search** — type a query to filter across all indexed results. Toggle filters for **Markers**, **Regions**, **Tracks**, and **Items**. Results are displayed in a sortable table. Double-click any result to open the project and jump to that position.

**Find & Replace** — batch rename markers, regions, tracks, or items across `.rpp` files:
1. Enter find/replace text and select target types
2. Click **Preview** to see a before/after table
3. Select or deselect individual matches
4. Click **Replace All** or **Replace Selected** — original files are backed up as `.bak`

**Help** — usage tips and an optional debug log for troubleshooting.

> **Standalone mode:** `DMN_ProjectSearch.lua` can also run independently outside DialogueWorkflow. It loads the same `project_search.lua` module and provides identical functionality in its own window.

---

### Edit tab — timeline tools & Notion sync

#### Timeline Tools

- **Apply to time selection only** — scopes the actions below to the current time selection
- **Snap items to regions** — aligns selected media items to region start positions
- **Marker from region** — creates point markers from region names within the selection (strips `Tag=` prefixes, e.g. `Entry=Hello` becomes `Hello`)
- **Move items to speaker track** — moves selected items vertically to the track matching their preceding `Speaker=` marker

#### Utilities

- **Find duplicate regions** — appends a `_duplicate` suffix and colours duplicate region names
- **Detect duplicate Index** — finds `Index=` markers that share the same value within a category and selects nearby items
- **Find missing ID= / Index=** — entry regions without a nearby `ID=` or `Index=` marker: selects overlapping media items and prints details to the REAPER console
- **Fix missing ID= from Notion** — for entry regions that **already have no nearby `ID=`** marker, fetches the Notion database (same workflow as **Add ID markers**) and creates only the missing `ID=<numeric>` point markers. Respects **Apply to time selection only**. Use this when **Sync Index markers** cannot run yet because `ID=` markers are absent.

#### Notion

Requires a **Notion integration token** and a configured database.

**Setup rows:**

| Field | Description |
|-------|-------------|
| Token `[Save]` `[Test]` | Paste your Notion integration token; Save stores it locally, Test validates it |
| Database `[Save as preset]` `[Load]` | Paste a Notion database ID; Save as preset names it for reuse across projects; Load picks a saved preset |
| Active label | Shows the currently selected preset name |

**Actions:**

- **Add ID markers** — matches entry regions to Notion rows by name and places `ID=<notion-id>` point markers (async fetch + progress; skips regions that already have that Notion ID assigned)
- **Sync Index markers** — requires a nearby `ID=` marker per entry region (same spatial rules as the diagnostics). Reads those IDs, fetches index data from Notion, and writes `Index=NN` markers. Regions without `ID=` are skipped.
- **Fix missing ID** (also under **Utilities**) — same Notion fetch as **Add ID markers**, but only processes entry regions that are **missing** a nearby `ID=` marker (complements **Sync Index markers** when IDs were never created)

**Clean Up** — update Notion from recorded audio:

- **Update Status field in Notion** — push a configured status option to the Notion row for each entry with recorded audio
- **Write session name to Notion** — record the REAPER project name against each processed row
- **Status field** `[Pick]` / **Target option** `[Pick]` — select which Notion property and value to write
- **Run Clean Up** — executes the batch update in the background

---

### Render tab — output configuration

#### Output

- **Path** — render output directory with **Browse…** and **Open** buttons
- **Sample rate** — 44.1 / 48 / 88.2 / 96 / 192 kHz
- **Channels** — Mono / Stereo / Quad / 5.1 / 7.1
- **Normalize** — optional; when enabled, choose mode (LUFS-I, RMS-I, Peak, True Peak, LUFS-M max, LUFS-S max) and target dB

#### Source

- **Source dropdown** — matches REAPER's render dialog: Master mix, Selected tracks (stems), Master mix + stems, Selected tracks via master, Region render matrix, Selected media items, Selected media items via master
- **Bounds dropdown** — Custom time bounds, Entire project, Time selection, All project regions, Selected media items, Selected project regions

#### Filename Builder

Build render paths using drag-and-drop token blocks. Each block is either a literal string or a REAPER wildcard.

Supported wildcards include `$marker(Speaker)`, `$marker(Category)`, `$marker(Index)`, `$region`, `$regionname`, `$regionnumber`, `$markername`, `$markernumber`, `$track`, `$date`, `$project`, and more.

- **Folder** and **File** token strips — drag `::` handles to reorder, `x` to remove, `+` to add from a popup of common wildcards
- **Live preview** — resolves wildcards from the current project state and shows the full output path

#### Render button

**Open Render Dialog…** applies all configured settings (output path, pattern, sample rate, channels, normalize, source, bounds) to the REAPER project and opens the native **Render to File** dialog for final confirmation.

#### Debug before render

When **Debug project before rendering** is enabled, the script runs timeline checks before opening the render dialog. If problems are found (duplicate names, missing markers, etc.), a popup summarizes them and offers actions such as selecting affected items (no extra confirmation dialog), marking duplicates, or running Notion **Add ID markers**, **Fix missing ID**, or **Sync Index markers** — mirroring **Edit → Utilities** where applicable.

---

## Samples

The `Samples/` folder contains example files to test the workflow:

| File | Description |
|------|-------------|
| `demo_shakespeare_hamlet_act5_scene1.csv` | Single-scene dialogue (Hamlet Act 5, Scene 1) |
| `demo_shakespeare_multi_scene.csv` | Multi-scene dialogue across 6 scenes — demonstrates category grouping |
| `demo_pacman_dialogue.csv` | Short game dialogue example |
| `Reaper_Shakespeare_Hamlet/` | Complete REAPER project with imported Shakespeare dialogue |

To try: paste a CSV file path into the Import tab, click **Auto Suggest**, review the column mappings, then click **Import**.

---

## Typical workflows

1. **Import only** — Import tab → CSV → regions/markers → edit and record normally.
2. **Record with teleprompter** — After import, install the web UI (Record tab), open the actor page on a browser/tablet; the actor reads `Speaker=` / `Entry=` lines while you manage transport.
3. **Notion-linked pipeline** — Import CSV → record → add `ID=` markers (Edit → Notion → **Add ID markers**, or **Utilities → Fix missing ID= from Notion** if only some lines lack `ID=`) → **Sync Index markers** → run Clean Up to push status back to Notion → use Render tab to configure and export.
4. **Cross-project search** — Navigator tab → Project Search → add project folders → Scan → search or batch-rename markers, regions, tracks, and items across your `.rpp` library without opening each project.

---

## Marker and region conventions

The teleprompter and the import script use these naming rules.

| Type | Examples | Purpose |
|------|----------|---------|
| Category / scene region | `Category=Intro`, `Scene=Act1` | Groups lines; drives scene list and navigation in the teleprompter |
| Dialogue region | `Entry=Hello there`, plain region | The actual dialogue line text |
| Speaker marker | `Speaker=Alice` | Who speaks — shown by the Actor Teleprompter; emitted by the **[Sp]** Speaker role |
| Tag markers | `Delivery=Whisper`, `Notes=…` | Any `ColumnName=value` marker from **Tag Marker** columns |
| ID marker | `ID=abc123def456` | Notion row identifier for sync operations |
| Index marker | `Index=03` | File naming index; used for QA and Notion sync |

---

## Google Sheets setup

1. Create a sheet with one dialogue line per row.
2. Suggested column layout:

   | A | B | C | D |
   |---|---|---|---|
   | Category | Speaker | Entry | Notes |

3. **File → Share → Publish to web → CSV** — copy the published URL.
4. Paste the URL into the Import tab **URL / file path** field and click **Auto Suggest**.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `ReaImGui` missing | Install via ReaPack (see Requirements) |
| Web page 404 | Confirm the filename in the URL matches the file in `reaper_www_root` and the web server is running |
| Browse button missing | Install **js_ReaScriptAPI** via ReaPack |
| Notion actions fail | Check token, database ID, integration permissions, and the REAPER console for error details |
| `Speaker=` not showing in teleprompter | Make sure the Speaker column has **[Sp]** role assigned before importing |
| Render settings not applied | Click **Open Render Dialog…** — settings are written to the project when the button is pressed |
| Project Search finds 0 `.rpp` files | Ensure paths don't contain surrounding quotes; use the **Discover** button to auto-scan folders |
| Standalone `DMN_ProjectSearch.lua` can't find module | Place `project_search.lua` in a `DMN_DialogueWorkflow/` subfolder next to the standalone script, or ensure the DialogueWorkflow repo is at the expected path |

---

## License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE).
