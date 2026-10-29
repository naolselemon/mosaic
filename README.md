# Mosaic

A read-only Omarchy shell plugin that shows where desktop applications keep their configuration, cache, data and state. It is an application-storage map, not a cleaner or a full-disk usage report.

<p><img src="assets/mosaic.svg" width="120" height="120" alt="Mosaic Reveal logo"></p>

The **Reveal** mark frames a visible centre with four geometric pieces: a visual identity for making application storage visible. The live shell icon follows the current theme; the overview and About mark use the selected chart accent. Page-specific navigation icons remain distinct.

### 2.5.0

App Data Map is now **Mosaic**, with the plugin ID `naolselemon.mosaic`, the Reveal logo, and a matching notification icon. The storage-analysis features and privacy model are unchanged. Existing local builds need the one-time namespace migration described below; Mosaic does not maintain an old-ID alias or silently read the old data directory.

## Use

Click the Mosaic Reveal icon in the bar to open the panel. The first open starts a scan; **Rescan** refreshes it. Detailed results stay in the running shell's memory. Optional history saves compact summaries locally; it is off by default. There is no periodic background scan, network access or telemetry.

The compact overview pairs a mapped-size donut with its category legend and shows up to five application rows, sorted by mapped size. The popup is 360 theme-scaled units wide and normally capped at 480 units high. The triangle beside Close expands the overview up to the available screen height, or condenses it again; lists longer than the screen remain scrollable. On application details and dashboard pages, that triangle returns to the previous page instead. Search hides the chart to make room for results; pressing the search icon again clears the filter and restores the normal overview. Its visual layout takes inspiration from [Screen Time](https://github.com/ax1g/quickshell-screentime-plugin), using Omarchy's own components.

The donut settles from a short 3D opening tilt. Hover a section or hover/Tab to a category to tilt its arc gently around the **Y axis**, highlight it, and show its category, size and share of **measured** bytes in the center. Each arc tilts around its own midpoint rather than dragging the ring away from the pointer. Click an arc or its legend entry to explore that category; a focused legend entry also accepts Enter or Space. The hole and visible gaps are not hover or click targets. Percentages are not shares of the whole disk or of unknown app data. The center stays upright; animations finish rather than running continuously. Disabling **Animations**, or Omarchy's global motion setting, retains information and highlighting without tilt.

The **category explorer** is one reusable page with Config, Data, Cache and State tabs, matching logos/colors, a measured total and a proportional app treemap. Tile area represents known measured bytes in the selected category: up to seven apps plus an **Other apps** group, without inflating tiny values. Select a tile to inspect only that app's locations in the selected category. **All apps** also reaches tiny, zero-byte and unmeasured entries; unknown is never displayed as measured zero. Possible/shared candidate matches are disclosed separately and excluded from owned totals; these are matches, not counts of unique physical locations. The page uses the overview snapshot, not a deeper scan or saved history. Its refresh button rescans the overview; tabs reset category-specific selections, and Settings/back retains the selected category.

Select an application to inspect its locations. The arrow on a location expands its largest immediate subfolders; its info icon opens a compact ownership/status card and numeric scan notes. **Evidence & paths** reveals raw matching evidence, full paths, timestamps and bounded skipped-path samples only when requested. These ownership and breakdown disclosures are mutually exclusive. Folder and copy icons act on roots and displayed subfolders; their tooltips identify each action. **Open folder** opens a directory in the file manager, or the parent of a configuration file. **Copy path** copies the absolute path without shell escaping.

The first-page gear opens Settings, and the keyboard icon in the overview footer opens **Keyboard shortcuts**; `?` also opens that page. **Scan details** is available only from the overview's scan-time info icon, not Settings or application details. These pages use animated navigation and return with their logo, triangle or Escape. Scan details shows an overview-only health display: mapped bytes, candidate-match status segments, snapshot time and expandable scan-note cards. Its technical cards explain scope, coverage, logical-byte accounting and unknown contents one topic at a time. There is no top **Measured so far** caption on that page; `≥`, unknown values and the lower-bound explanation retain measurement uncertainty. Candidate matches and reported skipped encounters are not counts of unique physical files or disk coverage.

| Shortcut | Action |
| --- | --- |
| Ctrl+F or `/` | Reveal and focus search (`/` from the overview) |
| Up / Down | Select an application or location |
| Enter | Open application details; in details, toggle the selected root's breakdown |
| Ctrl+R | Rescan the overview, category explorer or Scan details; refresh metadata on other dashboard pages |
| H or Ctrl+H, outside text fields | Open the storage dashboard; return from its pages |
| Ctrl+D, in details | Start a deeper scan of the selected application |
| O, in details | Open the selected root or focused breakdown directory |
| Ctrl+C, in details | Copy the selected root or focused breakdown directory |
| Tab / Shift+Tab | Move between controls; focused folder actions scroll into view |
| Page Up / Page Down | Page through app results, long details or dashboard pages |
| `?` | Open the separate keyboard help page |
| Home / End, in the dashboard | Jump to the top or bottom of the current page |
| Backspace or Alt+Left, in the dashboard | Return to the previous page (Alt+Right in right-to-left layouts) |
| Escape | Dismiss a dashboard explanation, return through pages, clear search, then close |

The panel uses Omarchy's UI components, theme, font, animation settings and locale-aware numbers. English strings are included; Omarchy's translation fallback handles other selected languages. Additional translations belong in `i18n/`.

## Storage dashboard

Click the Reveal logo inside the overview, or press **H**, to open the dashboard in the same compact popup. Each page has its own large logo; click it to return to the previous page. Short directional slides and logo transitions respect Omarchy's global animation setting and the plugin's **Animations** preference. Settings opens directly from the first-page gear.

The dashboard uses a category strip, snapshot bars and two-column highlights. Cache and growth have separate ranked views. Installation filters separate known/unknown sizes and Arch/Flatpak groups; provenance and leftover evidence expand on demand. Unavailable comparisons remain inspectable without filling the default history page with empty cards. Chart positions follow scan order, not elapsed time.

| Feature | Behavior |
| --- | --- |
| 5. Local history | Opt-in summaries of scans you run, with per-app charts and separate overview/deep scopes. |
| 6. Cache and growth | Largest measured mapped caches and largest positive, comparable app changes. Growth is bytes added between scans, not a rate or cleanup advice. |
| 7. Custom mappings | Assign an existing file or directory to a discovered app and category. Saved roots are visibly **User-added**. Saving or removing an association starts a fresh overview scan. |
| 8. Possible leftovers | Known or user-assigned roots whose exact launcher is absent from a complete fresh inventory. Live overlapping roots are excluded. |
| 9. Growth alerts | Separately opt-in desktop notifications after new comparable scans cross your threshold. Alerts require history. |
| 10. Installation sizes | Verified pacman package or supported Flatpak deployment sizes, kept separate from application data. No report export. |

**History and growth:** keep up to 60 summaries within a 2 MiB state limit, plus up to 50 alert events. The oldest summaries are discarded when either bound is reached. A comparison needs the same app, scan scope, root ownership and safe accounting. Incomplete app measurements, changed mappings, uncertain hard-link accounting, or a missing baseline produce an unavailable delta—not a fabricated increase. An intervening partial scan is not skipped to manufacture a comparison. A completed app can still be comparable within an otherwise partial overview. Deep results never replace the overview's cache ranking.

**Year in storage:** choose a retained year, inspect twelve monthly bars, and browse eight cards: peak measured footprint, largest observed app, largest recorded cache, biggest comparable rise/fall, scans kept, days with scans and apps observed. Each month uses its **last retained overview snapshot**, never a sum of snapshots. Click, hover or Tab to a month for its measurement; absent months remain missing, and partial measurements retain `≥`. Deep scans contribute app observations but never replace overview footprints. Annual changes require both endpoints inside the selected local calendar year and the same comparison safeguards as history. These are insights from retained records, not complete or permanently retained annual totals.

**Settings:** compact rounded cards group pill-shaped display switches, color swatches, history, growth notifications, mappings and local data. Toggle the home chart, dashboard highlights, yearly cards or page/chart motion independently; switches also accept Space or Enter and mirror in right-to-left layouts. Custom color and threshold fields expand only when requested. Colors follow theme/text/alert tokens or a validated opaque `#RRGGBB` value. Threshold saves acknowledge the confirmed result; invalid or failed input stays editable. The chart window can show 7, 14, 30 or 60 retained samples without changing retention. History and notification consent remain explicit; additional privacy/storage information has a compact disclosure. Appearance choices do not enable recording or notifications. Clearing history requires an explicit confirmation; Cancel leaves all saved data untouched.

**Alerts:** choose a threshold from 1 MiB to 1 TiB in Settings; the initial threshold is 256 MiB. Only new comparable scans can notify. Reopening a page or changing the threshold does not resend old events. Notification text contains a count, not application names or paths. Disabling history also disables alerts, but retains existing summaries until you choose **Clear history** and confirm.

**User-added mappings:** this means your assignment, not independently verified ownership. Overlapping roots stay shared and are excluded from app totals. Broad system/home/XDG roots, virtual filesystems, symlinks and special files cannot be added. A saved path that later disappears remains editable/removable and is not reported as zero. Editing the same app/path updates its category; removing an association never removes files.

**Possible leftovers:** an absent launcher is not proof that an app is uninstalled or that its files are safe to delete. Hidden, renamed and command-line apps can still use them. This is a bounded candidate list, not a complete orphan finder. Incomplete discovery or mapping suppresses absence claims. Open/Copy are the only file actions; evidence is available under each info button.

**Installation sizes:** pacman attribution uses the actual winning desktop file, exact local ownership and `%SIZE%` metadata. A custom launcher does not borrow a system package merely because its desktop ID matches. Flatpak attribution verifies the exported launcher and deployment; tool-reported rounded sizes are labelled. Multiple launchers from one package/deployment share one counted size. Dependencies and Flatpak runtimes are not recursively added. Unverifiable ownership or unavailable metadata stays **Unknown**, not zero. The total covers resolved unique packages, not all installed software, allocated blocks or reclaimable space.

Recording/alert settings and mappings are stored in `${XDG_CONFIG_HOME:-~/.config}/omarchy/mosaic/settings.json`; history and alerts are in `${XDG_STATE_HOME:-~/.local/state}/omarchy/mosaic/history.json`. Files are private (0600), directories are private (0700), and updates are atomic and locked. Corrupt or inaccessible state produces an error rather than a silent reset. **Clear history** deletes only this plugin's summaries and alert records; it preserves mappings and application files.

Presentation preferences use this widget's native entry in `~/.config/omarchy/shell.json`, preserving its other keys. Omarchy's settings API owns that persistence; the plugin reports unavailable/rejected updates rather than silently creating independent storage.

## Folder breakdowns and deeper scans

Each measured location shows up to 12 of its largest immediate subdirectories, files stored directly in the root, and the combined measured size of other encountered subdirectories. These contributions come from the same traversal and add up to the root's measured size; the scanner does not walk the tree again to build the breakdown. Partial child measurements retain their lower-bound labels. A capped breakdown does not imply that unvisited folders were counted.

**Deeper scan** measures only the selected app with larger finite budgets. Ownership is still resolved against the discovered application inventory so overlaps remain shared. Progress shows completed locations plus actual entries and bytes encountered in the current location, not an invented percentage of its unknown contents. **Cancel** stops the worker, preserves completed location results and marks unfinished locations incomplete. Live counters for an interrupted location are not presented as a finished measurement.

A deeper result is explicitly separate from the overview snapshot. It does not replace overview totals or other apps' measurements: combining separately timed results would also invalidate cross-app hard-link accounting. Only the most recent detailed deeper result is retained in memory; another deeper scan replaces it, and a full overview rescan clears it. When history is enabled, compact summaries remain available in the dashboard.

The overview and application summaries show compact local times. Technical scan details and expanded location evidence retain full dates and times using the selected locale. An application scan-end time can describe a partial or cancelled snapshot; an unmeasured location has no fabricated timestamp.

**Ownership & scan notes** shows a concise match source, whether the location is included, its measurement status and numeric encounter counts. **Evidence & paths** reveals the exact desktop-ID/root match, an upstream source when attached, and up to eight relative-path samples. An ellipsis marks a truncated sample; samples are not clickable folder targets. Counts do not pretend to enumerate unseen descendants. Duplicate hard links are separate from inaccessible data and do not by themselves make a result incomplete.

## What the numbers mean

- **Known:** an explicit desktop-ID mapping or Flatpak application namespace identifies it. These locations contribute to mapped totals.
- **User-added:** your explicit saved assignment, also included in mapped totals when it does not overlap another root. Ownership is not independently verified.
- **Possible:** a directory name resembles an application ID or name. Ownership is not confirmed; it is excluded from totals.
- **Shared:** mapped roots overlap. It is not charged to any individual app and is excluded from totals, rather than being counted twice.
- **≥ / Measured so far:** the displayed size is a lower bound. Permissions, changing files, symbolic links, special files and scan budgets can prevent a complete result. The same rule applies to an individual app's own snapshot. Unknown sizes are not presented as zero; the info icon explains the recorded reasons.
- **Not mapped:** no location was identified. This does not mean the application uses no storage.

Sizes are logical regular-file bytes, not allocated blocks or reclaimable space. Hard links are counted once within a measurement and across known locations. Categories describe storage roots, not the contents of every file: **Config & profiles** can include browser profiles, databases and extensions. Cache is not a promise that a directory is safe to delete.

The scanner discovers visible XDG desktop launchers, respecting user overrides, and recognizes Flatpak metadata. Explicit mappings cover common browsers, editors, terminals and desktop apps; other applications can have only possible matches or no matches. CLI-only programs without visible desktop launchers, arbitrary project folders, external game libraries, documents and orphaned data are not comprehensively discovered. This is not a complete inventory of every installed package or every byte in the home directory.

## Mapping coverage

Release 1.1 preserves the 29 original mapping entries and adds these eight application families. They identify documented default locations, not custom profiles or portable installations. Exact desktop IDs matter; matching an application's display name alone never establishes ownership.

| Desktop ID, without `.desktop` | Default roots | Upstream evidence |
| --- | --- | --- |
| `btop` | Config: `btop` | [btop documentation](https://github.com/aristocratos/btop/blob/main/README.md#themes) |
| `htop` | Config and state: `htop` | [htop manual](https://github.com/htop-dev/htop/blob/main/htop.1.in) |
| `com.github.johnfactotum.Foliate` | Config and data: `com.github.johnfactotum.Foliate` | [Foliate FAQ](https://github.com/johnfactotum/foliate/blob/gtk4/docs/faq.md) |
| `blender` | Config and cache: `blender` | [Blender directory layout](https://docs.blender.org/manual/en/latest/advanced/blender_directory_layout.html) |
| `gimp` | Config: `GIMP` | [GIMP profiles](https://www.gimp.org/tutorials/GIMPProfile/) |
| `vlc` | Config: `vlc` | [VideoLAN configuration FAQ](https://www.videolan.org/support/faq.html#Config) |
| `org.inkscape.Inkscape` | Config: `inkscape` | [Inkscape environment documentation](https://wiki.inkscape.org/wiki/Environment_variables) |
| `thunderbird` | Home: `.thunderbird` | [Mozilla profile documentation](https://support.mozilla.org/en-US/kb/profiles-where-thunderbird-stores-user-data) |

Config, cache, data and state honor the corresponding XDG user-directory variables. A documented root is listed only when it exists or cannot safely be checked. Hidden launchers remain hidden. `mappings.py` holds the rules and source URLs; older mappings without attached upstream URLs say so rather than presenting fabricated citations.

## Safety and bounds

The scanner reads desktop metadata and filesystem metadata, not application document contents. It never runs desktop `Exec` commands and never deletes or edits application data. It does not recursively search the entire home directory. Storage traversal does not follow symbolic links, including ancestor-directory links; such locations can remain unmeasured. Desktop launcher exports themselves may be symlinks.

Scanning runs in a separate Python process. Both modes limit discovery to 512 applications, 24 candidate paths per app and 12,000 discovery entries.

| Traversal budget | Overview | Selected-app deeper scan |
| --- | --- | --- |
| Entries overall | 300,000 | 1,000,000 |
| Entries per location | 60,000 | 500,000 |
| Cooperative runtime | 25 seconds | 90 seconds |
| Runtime per location | 3 seconds | 20 seconds |
| Directory depth | 64 | 96 |
| Process alarm | 35 seconds | 100 seconds |
| Shell watchdog | 40 seconds | 110 seconds |

Large trees can still produce partial results even when readable. Scans are streamed as bounded protocol-v3 records, including explicit discovery completeness and individual location results rather than one giant application breakdown. Normal scans deduplicate hard links across known roots; deeper scans deduplicate only within the selected application's snapshot. Neither mode follows storage symlinks or modifies files.

Paths, metadata and scanner messages are bounded and validated before display. Dynamic text is plain text. Folder actions use argument arrays and encoded file URIs, never shell interpolation. The helper rechecks paths and rejects missing locations, symlink ancestors and special files. Opening a folder still launches an external file manager, and copying a path changes the clipboard. Like other Omarchy plugins, this runs with your user's permissions; read-only behavior is a design constraint, not an OS sandbox.

The separate dashboard worker has a 45-second process alarm and 60-second shell watchdog. Leftover checks have independent budgets: at most 128 candidates, 20,000 entries/3 seconds overall and 5,000 entries/0.25 seconds per root. Package lookup is capped at 8 seconds, 10,000 packages and 64 MiB of database metadata; subprocess output and individual reads are bounded. These are metadata reads, not package installation/removal commands.

## Installation and development

Tested with Omarchy `4.5.0rc2-1`, its plugin-capable Quickshell and Qt 6.12. Runtime dependencies are Python 3, `gdbus` (GLib), and a file manager implementing `org.freedesktop.FileManager1`, such as Omarchy's Nautilus. Enabled growth alerts use `notify-send` from libnotify. Installation attribution reads pacman's local database and uses `pacman-conf` when available; Flatpak support uses `flatpak` when installed. Node.js is only needed for JavaScript tests.

Install from GitHub:

```sh
omarchy plugin add https://github.com/naolselemon/mosaic.git --enable
```

From this source directory:

```sh
plugin="$HOME/.config/omarchy/plugins/naolselemon.mosaic"
mkdir -p "$plugin/i18n" "$plugin/assets"
cp *.qml *.js *.py manifest.json README.md LICENSE "$plugin/"
cp i18n/*.json "$plugin/i18n/"
cp assets/*.svg assets/*.png "$plugin/assets/"
omarchy plugin validate "$plugin"
omarchy-shell shell rescanPlugins
omarchy plugin list
```

Once Mosaic appears in the plugin list:

```sh
omarchy plugin enable naolselemon.mosaic --section right
```

Edit this source directory, then copy changes into the installed directory. If plugin rescanning leaves old QML cached, run `omarchy restart shell`; this restarts the whole Omarchy shell, not just this plugin. Do not launch a second Quickshell instance for it.

### Migrating a local App Data Map installation

1. Back up `~/.config/omarchy/shell.json` and the old `omarchy/app-data-map` directories under your XDG configuration and state roots. Keep backups outside the source repository.
2. Save the old widget's bar position and display preferences, then disable `naolselemon.app-data-map`. Wait for its scans and service to stop before moving data.
3. Rename each existing `omarchy/app-data-map` data directory to `omarchy/mosaic` under the same XDG root, preserving ownership and private permissions. Do not overwrite or merge an existing destination.
4. Install Mosaic. Restore the saved widget preferences and position under `naolselemon.mosaic` in the bar configuration; do not restore the old ID.
5. Verify the new widget, mappings, history and consent settings before removing the disabled old plugin directory. Application files never need to move.

### Local controls

To disable the widget and service:

```sh
omarchy plugin disable naolselemon.mosaic
```

Local shell commands:

```sh
omarchy-shell shell summon naolselemon.mosaic '{}'
omarchy-shell shell hide naolselemon.mosaic
omarchy-shell naolselemon.mosaic scan
omarchy-shell naolselemon.mosaic deepScan com.microsoft.VSCode.desktop
omarchy-shell naolselemon.mosaic detail com.microsoft.VSCode.desktop
omarchy-shell naolselemon.mosaic cancel
omarchy-shell naolselemon.mosaic status
omarchy-shell naolselemon.mosaic snapshot
omarchy-shell naolselemon.mosaic workspaceStatus
omarchy-shell naolselemon.mosaic workspaceRefresh
```

`scan` and `deepScan` return whether a scan started; a busy worker or an unknown selected ID is not silently replaced with another scan. `status` returns overview summary and current-job metadata. `snapshot` returns the overview application array; `detail` returns a matching deeper result when available, otherwise that application's overview result. The Python CLI equivalents are `python3 -B scanner.py scan` and `python3 -B scanner.py scan --app com.microsoft.VSCode.desktop`. Snapshots include absolute paths and directory names; treat them as private when sharing diagnostics.

`workspaceStatus` returns dashboard data, readiness and errors. `workspaceRefresh` refreshes package/leftover metadata and derived views without recording another scan. Mutations are also available through `workspaceSettings JSON`, `mappingSave EXACT.desktop /absolute/path CATEGORY`, `mappingRemove EXACT.desktop /absolute/path`, and `historyClear`. They return whether the operation was accepted; check `workspaceStatus` for its eventual outcome. Settings accept `historyEnabled`, `alertsEnabled` and integer `thresholdBytes`. The one-shot `python3 -B workspace.py` worker accepts one bounded JSON request on stdin and returns one validated response. Dashboard mutations and scans are single-flight.

**Diagnostic limitation:** full `workspaceStatus` IPC replies can fail with `QLocalSocket::PeerClosedError` for populated histories on the tested shell. The UI accesses state directly and remains usable; the private JSON files above provide persisted-state diagnostics.

## Verification

From the source directory:

```sh
python3 -B -m unittest discover -s tests -v
node --test tests/*.test.cjs
omarchy plugin validate .
```

Tests cover discovery precedence, known versus inferred/user-assigned ownership, overlaps, safe traversal, hard-link accounting, exact breakdown partitions, partial and inaccessible measurements, selected-app isolation, safe folder targets, cancellation, both protocols, private persistence, growth comparability, replay suppression, cautious leftover detection, package/deployment attribution, preference input boundaries, yearly snapshot/growth invariants, donut hit geometry, category-local measurement/confidence boundaries, zero versus unmeasured apps, and proportional treemap area, bounds, non-overlap and exact Other membership.

Exercise the real shell after UI changes: expand and condense the overview with the triangle, checking screen bounds, list scrolling and footer visibility. Type a multi-character search, then close it with the search icon and verify that the filter clears and the normal overview returns. Search again, press Enter once to enter details and again to expand a breakdown, use Tab to copy and open a child directory, expand the compact ownership card and its optional raw evidence, and scroll with Page Up/Down. Check the back triangle on app details and nested dashboard pages. Open Scan details only from the overview, verify its match-count partition and technical cards, and confirm that deep scans do not change its overview scope or expose deep progress as overview progress. Open Keyboard with the overview footer icon and `?`; both routes must return to their origin. Start a deeper scan with Ctrl+D, cancel using the visible header control, then run another to completion. Check that overview totals and timestamps remain unchanged during deeper work, cancelled roots show unknown sizes rather than zero, and a full rescan clears the deeper snapshot. Test no results, arrow-key selection, root Open/Copy shortcuts and each Escape navigation step as well.

For dashboard changes, use an isolated temporary directory and a temporary user mapping. Enable history/alerts explicitly, record a baseline, grow only the temporary file beyond the chosen threshold, and verify the chart, exact comparable delta, retained alert and real desktop notification. Check that replaying a scan cannot notify again and a partial measurement cannot create an exact delta. Verify Settings, mapping add/remove, history clearing, package disclosures, leftover evidence and keyboard scrolling in the live shell. Remove the test association, confirm application files were not deleted, clear only test-created history, restore previous consent settings and delete the temporary directory. Do not publish screenshots containing real paths, app inventories or unrelated desktop content.

For presentation changes, verify first-page Settings, logo/triangle roundtrips and nested back navigation, all record filters, month selection and yearly cards. Hover actual donut arcs, their gaps and the center; check legend cross-highlighting and Tab focus. Click arcs and legend entries, including keyboard activation, to open the matching category. Tiny slices remain reachable through the legend. Check all four tabs, proportional tiles, All apps/Other pickers, category-only paths, separate excluded matches, selection reset, Settings/back and overview refresh. Observe opening and Y-axis hover motion, then disable animations and verify that information and clicks remain without tilt. Reopen the popup and leave/return through search and other pages to check hover reset. Exercise rounded switches with mouse and keyboard, disabled alert controls, compact swatches, custom color/threshold validation and confirmed saves, privacy disclosure, history-clear cancellation, keyboard focus/reveal and narrow/scaled layouts. Restart the shell to verify persistence without changing unrelated widget settings. Restore original consent, preferences and thresholds, remove only test mappings/history and discard private captures.

Keep the search field outside the resetting list model and keep the panel's key target an Item rather than a FocusScope: otherwise search updates or hidden input focus can consume detail shortcuts. Search Return/Enter handlers accept their events so a single press does not also toggle a detail breakdown.

## License

MIT; see `LICENSE`.
