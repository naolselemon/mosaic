# Mosaic user guide

Mosaic is a read-only map of desktop application configuration, cache, data and state—not a cleaner, full-disk report or complete installed-software inventory. Return to the [README](../README.md), or see [contributing](../CONTRIBUTING.md) and [security](../SECURITY.md).

## Installation

Tested with Omarchy `4.5.0rc2-1`, its plugin-capable Quickshell and Qt 6.12. You need Python 3, GLib's `gdbus`, and a file manager implementing `org.freedesktop.FileManager1`, such as Nautilus. Growth notifications use libnotify's `notify-send`. Installation attribution reads pacman's local database, uses `pacman-conf` when available, and supports Flatpak when installed. Node.js is needed only for development tests.

```sh
omarchy plugin add https://github.com/naolselemon/mosaic.git --enable
```

Click the Reveal icon in the bar. The first opening starts a scan; **Rescan** refreshes it. There is no periodic background storage scan. Detailed results stay in the running shell's memory; optional history is off by default.

For source deployment, see [Development setup](../CONTRIBUTING.md#development-setup). If plugin rescanning leaves stale QML, `omarchy restart shell` restarts the entire shell, including other plugins. Do not launch a second Quickshell instance.

## Navigation and shortcuts

The overview shows measured mapped bytes by category and applications sorted by mapped size. Hover a donut arc or focus its legend for category size/share; click either to explore it. Percentages cover measured bytes only—not the disk or unknown data. Gaps and the donut hole are not targets.

- The triangle beside Close expands/condenses the overview to available screen space. On details/dashboard pages it goes back. Long lists remain scrollable.
- Search hides the chart. Pressing the search icon again clears the filter and restores the overview.
- The overview's Reveal logo or **H** opens the dashboard; its gear opens Settings. Page logos, back triangles and Escape return through pages.
- The scan-time info icon opens **Scan details**, scoped only to the overview. Its match counts and skipped encounters are not unique-file counts or disk coverage.
- In application details, the arrow expands a root's immediate subfolders; the info button reveals ownership/status. **Evidence & paths** exposes full paths, dates, matching evidence and bounded skipped-path samples on request. Ownership and breakdown disclosures are mutually exclusive.
- **Open folder** opens a directory or a file's parent in the file manager. **Copy path** copies an absolute path without shell escaping. These actions also work on displayed breakdown directories, not truncated evidence samples.

The category explorer has Config, Data, Cache and State tabs. Treemap areas represent measured bytes, with up to seven apps plus **Other apps**; tiny values are not inflated. **All apps** reaches tiny, zero-byte and unmeasured entries. App selections show only that category's paths. Possible/shared matches are separate and excluded from totals. This page uses the overview snapshot; refresh rescans it, and changing tabs resets category-specific selections.

| Shortcut | Action |
| --- | --- |
| Ctrl+F or `/` | Focus search (`/` from overview) |
| Up / Down | Select an application or location |
| Enter | Open app details; in details, toggle selected root breakdown |
| Ctrl+R | Rescan overview/category/Scan details; refresh metadata on other dashboard pages |
| H or Ctrl+H, outside text fields | Open dashboard or return from its pages |
| Ctrl+D, in details | Deeper scan of selected app |
| O / Ctrl+C, in details | Open / copy selected root or focused breakdown directory |
| Tab / Shift+Tab | Move among controls |
| Page Up / Page Down | Page through results, details or dashboard |
| `?` | Open keyboard help (also available in overview footer) |
| Home / End, in dashboard | Top / bottom of current page |
| Backspace or Alt+Left, in dashboard | Go back (Alt+Right in right-to-left layouts) |
| Escape | Dismiss explanation, return through pages, clear search, then close |

Theme, fonts, locale-aware numbers and global motion preferences follow Omarchy. Settings can independently hide the home chart, dashboard highlights or yearly cards, and disable plugin animations. Disabled motion preserves information and interaction. Custom accents accept opaque `#RRGGBB` colors. English translations are included; other languages use Omarchy's fallback.

## Measurements and ownership

| Label | Meaning |
| --- | --- |
| **Known** | Exact desktop-ID mapping or Flatpak namespace; included in mapped totals |
| **User-added** | Your saved assignment, not independently verified ownership; included only without overlaps |
| **Possible** | Name resembles an app; unconfirmed and excluded from totals |
| **Shared** | Overlapping mapped roots; excluded from individual app totals rather than double-counted |
| **≥ / Measured so far** | Lower bound: a partial measurement, not a complete size |
| **Unknown** | No usable measurement; never substituted with zero |
| **Not mapped** | No identified location, not proof of no storage |

Sizes are **logical regular-file bytes**, not allocated blocks or reclaimable space. Hard links are counted once within the applicable snapshot, including across known roots in overview scans. Categories describe roots: Config & profiles can contain browser databases, profiles and extensions. A Cache label does not mean safe to delete.

Discovery uses visible XDG desktop launchers, respecting user overrides and hidden entries, plus Flatpak metadata. Exact IDs matter; display-name similarity cannot establish ownership. [Mapping rules and upstream sources](../backend/mappings.py) cover app-specific defaults, not custom profiles or portable installs. Config/cache/data/state roots honor their XDG variables. Missing roots are not listed unless their existence cannot safely be checked. CLI-only tools, projects, documents, external game libraries and orphaned data are not comprehensively discovered.

### Partial results and deeper scans

Permissions, changing files, symlinks, special files and finite budgets can prevent complete measurement. Scanner notes preserve those reasons. A duplicate hard link is not itself inaccessible data. Encounter counts and up to eight relative-path samples describe observed entries, not all unseen descendants.

Each root's breakdown shows up to 12 largest immediate subdirectories, files directly in the root and other encountered subdirectories. Contributions come from the same traversal and sum to the measured root size. A capped breakdown does not claim unvisited folders were measured; partial children retain lower bounds.

**Deeper scan** measures only the selected app with larger finite budgets, while resolving ownership against the discovered inventory. Progress reports encountered entries/bytes and completed locations, not a fictional percentage of unknown contents. **Cancel** preserves completed locations and marks unfinished work incomplete; interrupted live counters are not finished measurements.

Deep results never replace overview totals, timestamps, category views or cache rankings. Combining differently timed snapshots would invalidate accounting. Only the latest detailed deep result stays in memory; another deep scan replaces it, and an overview rescan clears it. Optional history can retain compact summaries. A scan-end timestamp may describe a partial/cancelled snapshot; unmeasured locations have no invented timestamp.

| Budget | Overview | Selected-app deeper scan |
| --- | --- | --- |
| Total entries | 300,000 | 1,000,000 |
| Entries per location | 60,000 | 500,000 |
| Cooperative runtime | 25 seconds | 90 seconds |
| Runtime per location | 3 seconds | 20 seconds |
| Directory depth | 64 | 96 |
| Process alarm / shell watchdog | 35 / 40 seconds | 100 / 110 seconds |

Both modes bound discovery to 512 apps, 24 candidates per app and 12,000 discovery entries. Readable large trees can still be partial. Dashboard work is separately bounded (45-second process alarm, 60-second watchdog); leftover and package checks have their own limits, not an exhaustive search.

## Dashboard and history

The dashboard links to history, annual insights, cache/growth rankings, installation sizes, possible leftovers, mappings and alerts. Disabling highlights leaves compact navigation links. **Overview changes** uses only the latest comparable overview pair: grew, shrank or unchanged. Unknown comparisons are excluded; without a comparable pair the counts are unavailable.

### History, growth and annual insights

History is explicitly opt-in. It keeps up to **60 summaries within 2 MiB**, plus up to **50 alert events**, discarding oldest summaries when bounds are reached. Charts use scan order, not elapsed time; a 7/14/30/60-sample chart window does not change retention. Overview and deeper scopes remain separate.

A delta requires the same app, scope, root ownership and safe accounting. Incomplete app measurements, changed mappings, uncertain hard links or absent baselines yield unavailable changes—not fabricated growth. An intervening partial scan is not skipped to create a comparison. A fully measured app can remain comparable within an otherwise partial overview. Growth is bytes added between scans, not a rate or cleanup recommendation.

**Year in storage** uses each month's **last retained overview snapshot**, never the sum of scans. Missing months stay missing and partial values retain `≥`. Activity counts and selectable peak/largest/rise/fall observations describe retained records, not complete annual totals. Deep scans can contribute app observations but not overview footprints. Annual changes require both comparable endpoints inside the selected local calendar year.

Growth alerts require separate consent and history. The threshold is 1 MiB–1 TiB (initially 256 MiB). Only new comparable scans notify; reopening pages, replaying scans or changing thresholds does not resend events. Notifications contain a count, not app names or paths. Disabling history disables alerts but retains saved records until **Clear history** is confirmed. Appearance settings never enable recording or alerts.

### Mappings, leftovers and installations

- **Custom mappings:** assign an existing file/directory to a discovered app and category. Saving/removing an association starts a fresh overview scan. Overlaps stay shared; broad home/system/XDG roots, virtual filesystems, symlinks and special files are rejected. Missing saved paths remain editable/removable, not measured zero. Reassigning the same app/path updates its category. Removing an association never removes files.
- **Possible leftovers:** known/user-assigned roots whose exact launcher is absent from a complete fresh inventory, excluding live overlaps. Incomplete discovery/mapping suppresses absence claims. Hidden, renamed or CLI apps may still use these files: this is neither proof of uninstall nor permission to delete. Only Open/Copy actions are provided.
- **Installation sizes:** separate from app data. Pacman attribution uses the winning desktop file's exact local ownership and `%SIZE%`; a custom launcher cannot borrow ownership from a matching system desktop ID. Flatpak attribution verifies exports/deployments and labels rounded tool-reported values. Shared packages/deployments count once. Dependencies/runtimes are not recursively added. Unresolved values remain Unknown. The total is resolved unique packages, not all installed software or reclaimable disk space. There is no report export.

## Privacy and storage

Storage analysis is local, with no telemetry. The scanner reads desktop/filesystem metadata, not application document contents, and never runs desktop `Exec` commands or edits/deletes application files. It does not recursively search the whole home directory or follow storage symlinks, including ancestor links. Launcher exports themselves may be symlinks.

Dynamic text is plain text; messages and paths are bounded and validated. Folder actions use argument arrays and encoded file URIs; the helper rechecks targets, rejecting missing locations, symlink ancestors and special files. Open launches an external file manager and Copy changes the clipboard. Mosaic runs with your user's permissions: read-only design is **not an OS sandbox**.

| Data | Location |
| --- | --- |
| Recording/alert settings and mappings | `${XDG_CONFIG_HOME:-~/.config}/omarchy/mosaic/settings.json` |
| History and alert records | `${XDG_STATE_HOME:-~/.local/state}/omarchy/mosaic/history.json` |
| Presentation and preparation consent | Mosaic's native entry in `~/.config/omarchy/shell.json` |
| Private updater state, staged code and recovery snapshots | `${XDG_STATE_HOME:-~/.local/state}/omarchy/mosaic/updater/` |

Mosaic's settings/history files use private 0600 files, 0700 directories, atomic writes and locking. Corrupt/inaccessible state reports an error rather than silently resetting. **Clear history** removes only summaries and alert records, preserving mappings, app files, updater consent and recovery artifacts. Omarchy's settings API owns shell preferences; unrelated keys are preserved and rejected changes are reported rather than stored elsewhere.

Release checks/preparation contact GitHub only when requested or opted in. Contribution links open the browser only when selected; Mosaic does not submit issues, star automatically or fetch star counts. Old metadata-checker consent does not authorize code downloads: `prepareUpdates` defaults off, and the obsolete `updates.json` cache is no longer read.

Paths, app inventories and timestamps in evidence, snapshots and saved state can be private. Review diagnostics before sharing; use synthetic data and crop screenshots to the plugin. See [contribution privacy guidance](../CONTRIBUTING.md#issues-pull-requests-and-screenshots).

## Updates and recovery

**Check now** checks the official stable GitHub release and prepares a newer compatible candidate without installing it. Settings shows its version and commit. **Review installation** is not approval; **Install & restart shell** approves only the displayed exact commit and explicitly restarts the entire shell. A changed candidate invalidates the review.

The updater requires Git, the installed Omarchy validator, a systemd user manager and a normal unlocked shell. Installation supports only a clean, standalone Git checkout at `$HOME/.config/omarchy/plugins/naolselemon.mosaic` with the exact official HTTPS origin. Development mirrors, shallow repositories, local modifications, ignored user files and alternate histories are refused, not overwritten. A version on `main` alone is not a release: a matching stable GitHub release and tag are required.

1. **Prepare:** the fixed `https://api.github.com/repos/naolselemon/mosaic/releases/latest` endpoint must name a non-draft, non-prerelease release. The tag resolves to an exact commit; identity/version, regular-file tree, clean bytes, ancestry and Omarchy validation must pass. No downloaded plugin code runs during preparation. A missing stable release is reported normally.
2. **Approve and install:** the backend revalidates the candidate and installed base. A private copy of the trusted installer runs independently in a temporary systemd user service. It refuses active Mosaic work and locked/ambiguous sessions, quiesces the shell, snapshots plugin settings/history under journal locks, records activation/configuration, atomically exchanges code, restarts the shell and verifies exact commit, Mosaic readiness and unchanged activation/configuration. Readiness is lightweight workspace loading, not a completed storage scan.
3. **Recover:** failed checks leave code unchanged. Failed installation can restore old code only if owned data is unchanged and both trees still validate. New settings/records are never overwritten with backups. Uncertain recovery stays **Recovery required**, retains trees/private snapshots and blocks another installation. Details provides the retained path and a restart command; restarting alone does not resolve an unverified installation.

Automatic updates means **opt-in daily checking/preparation**, never automatic installation/restart. A lightweight minute timer contacts GitHub only when 24 hours have passed since the persisted attempt. Disabling it stops future scheduled checks, not an already approved independent installation. Approval cannot be reused for repeated installs.

Preparation bounds metadata, output, committed files and storage. Cross-filesystem installs may stage in private `$HOME/.config/omarchy/.mosaic-updater-staging` to permit atomic exchange. Retained recovery/candidate trees are not silently deleted: reaching the aggregate staging limit refuses more preparation and requires inspecting artifacts. Do not delete recovery trees or force another install to hide uncertainty. Application files are never part of the exchange, and the updater never rewrites shell configuration to disguise activation changes.

From an installed checkout:

```sh
python3 -B backend/updates.py load
python3 -B backend/updates.py check
```

`load` makes no network request; `check` can download code but cannot install. Settings uses `install --commit FULL_SHA` for restart approval, not arbitrary repository/path/version overrides. While quiesced, new scans, workspace mutations and folder actions are refused until the guard releases or the shell restarts.

## Older development copies

`v0.1.0` is the first published release. Earlier `2.x` numbers were internal development iterations. Those copies need a **one-time manual deployment**; updater downgrade protection remains enabled. Plugin ID and separate Mosaic settings/history paths are unchanged.

Use a separate checkout of the published source, stop active Mosaic scans and close the popup, then mirror it into the installed plugin. Do not run the mirror from inside its destination:

```sh
git clone --branch v0.1.0 https://github.com/naolselemon/mosaic.git mosaic-v0.1.0
cd mosaic-v0.1.0
plugin="$HOME/.config/omarchy/plugins/naolselemon.mosaic"
mkdir -p "$plugin"
rsync -a --delete --exclude='.git/' --exclude='__pycache__/' ./ "$plugin/"
omarchy plugin validate "$plugin"
omarchy-shell shell rescanPlugins
omarchy plugin list
```

This replaces obsolete deployed files while preserving installed Git metadata and separate settings/history. It is a manual deployment, not a conversion into an updater-supported clean Git checkout. If needed, enable with `omarchy plugin enable naolselemon.mosaic --section right`; restart the whole shell only if stale QML remains.

### Older App Data Map name

For a local `naolselemon.app-data-map` installation, back up `~/.config/omarchy/shell.json` and the old `omarchy/app-data-map` directories under both XDG configuration/state roots, outside the repository. Record its position/preferences, disable the old plugin and wait for its work to stop. Rename each existing old data directory to `omarchy/mosaic` under the same root, preserving private permissions; **never merge or overwrite an existing destination**. Install Mosaic, restore position/preferences under `naolselemon.mosaic`, and verify mappings/history/consent before removing the disabled old plugin directory. Application files do not move.

## Local controls

Disable the widget/service:

```sh
omarchy plugin disable naolselemon.mosaic
```

Shell IPC examples (replace the example desktop ID with an actually discovered app):

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

`scan`/`deepScan` return whether work started; busy workers and unknown IDs do not silently replace scans. `status` gives overview/job metadata; `snapshot` returns overview apps; `detail` uses the matching deep result if available, otherwise overview detail. Standalone scanner equivalents are `python3 -B backend/scanner.py scan` and `python3 -B backend/scanner.py scan --app com.microsoft.VSCode.desktop`.

`workspaceRefresh` updates package/leftover metadata and derived views without recording a scan. Mutations include `workspaceSettings JSON`, `mappingSave EXACT.desktop /absolute/path CATEGORY`, `mappingRemove EXACT.desktop /absolute/path` and `historyClear`. Categories are `config`, `cache`, `data`, `state`; settings accept `historyEnabled`, `alertsEnabled` and integer `thresholdBytes`. These return acceptance, not eventual success: inspect `workspaceStatus` for outcomes. The one-shot `python3 -B backend/workspace.py` accepts one bounded JSON request on stdin. Dashboard mutations and scans are single-flight.

**Diagnostic limitation:** populated `workspaceStatus` replies can fail with `QLocalSocket::PeerClosedError` on the tested shell. The UI reads state directly and remains usable; private JSON files provide persisted-state diagnostics. Raw snapshots and diagnostics can expose absolute paths and directory names—do not post them unreviewed.
