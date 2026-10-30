# Contributing to Mosaic

Mosaic maps application storage; it is not a cleaner or a full-disk analyzer. Keep changes focused on that purpose. For usage and storage contracts, see the [user guide](docs/guide.md); report vulnerabilities through [SECURITY.md](SECURITY.md), not a public issue with sensitive details.

## Development setup

Use a plugin-capable Omarchy installation. The tested environment is Omarchy `4.5.0rc2-1`, Quickshell and Qt 6.12. Runtime prerequisites are Python 3, GLib's `gdbus`, and a file manager implementing `org.freedesktop.FileManager1` (such as Nautilus). Notifications need `notify-send`; installation attribution uses the local pacman database, optionally `pacman-conf`, and Flatpak when installed. JavaScript tests require Node.js. Updater development additionally needs Git, Omarchy's validator and a systemd user manager.

Clone the repository, then run these commands **from its root**. Stop any active Mosaic scan and close the popup first. The destination is the installed plugin, not your source checkout: `--delete` deliberately removes obsolete deployed code. Separate settings/history are not touched; installed Git metadata is preserved.

```sh
git clone https://github.com/naolselemon/mosaic.git
cd mosaic
plugin="$HOME/.config/omarchy/plugins/naolselemon.mosaic"
mkdir -p "$plugin"
rsync -a --delete --exclude='.git/' --exclude='__pycache__/' ./ "$plugin/"
omarchy plugin validate "$plugin"
omarchy-shell shell rescanPlugins
omarchy plugin list
omarchy plugin enable naolselemon.mosaic --section right
```

Repeat the mirror, validation and rescan after edits. If QML remains cached, `omarchy restart shell` restarts the **whole shell**. Do not start a second Quickshell instance. Development mirrors are not supported updater installation targets; use an isolated clean checkout for updater work.

## Project layout

| Path | Responsibility |
| --- | --- |
| `manifest.json` | Plugin identity and QML entry points |
| `qml/Service.qml` | Workers, scan state, persistence requests and IPC |
| `qml/Panel.qml`, `qml/MapWorkspace.qml` | Popup and dashboard navigation |
| `qml/pages/`, `qml/components/` | Pages and shared native controls/charts |
| `qml/lib/` | JavaScript models, protocols, geometry and presentation |
| `backend/` | Python scanner, mappings, persistence, folder actions and updater |
| `tests/python/`, `tests/js/` | Backend and JavaScript regression tests |
| `assets/`, `i18n/`, `docs/` | Artwork, translations and user documentation |

Follow nearby code and reuse the existing controls and protocols. Mapping additions belong in `backend/mappings.py`: use exact desktop IDs, app-specific default roots and upstream evidence. A display-name resemblance is not ownership; shared stores and user documents are not app-specific roots.

## Checks

From the repository root:

```sh
python3 -B -m unittest discover -s tests/python -v
node --test tests/js/*.test.cjs
omarchy plugin validate .
```

Add regression coverage for changed behavior, including incomplete/error cases. These checks do not replace testing QML in the real Omarchy shell. Report what you actually ran, including any unavailable environment or failed check.

### Native UI smoke checks

For UI changes, exercise the affected flow in the native shell, not a browser recreation:

- Expand/condense the overview; check screen bounds, scrolling, footer visibility and narrow/scaled layouts. Search multiple characters, clear with the search icon, and check empty results and keyboard selection.
- Enter details, expand a breakdown, use Tab and Open/Copy on roots and children, and reveal ownership/evidence. Check Page Up/Down, back triangles, Settings, `?` and Escape roundtrips. One Enter must not both enter details and expand a root.
- Start, cancel and complete a deeper scan. Overview totals/timestamps and Scan details must remain overview-only; unfinished roots stay unknown, and an overview rescan clears the detailed deep result.
- For charts/categories, check actual arcs versus gaps/center, legend focus and keyboard activation, all tabs, tiny/unknown entries, Other/All apps, excluded matches and category-only paths. Disable animations and verify information/actions remain usable.
- For Settings/dashboard changes, check empty and populated states, filters, month selection, failed-input preservation, keyboard switches, reduced motion, right-to-left layout and persistence after a shell restart. Unavailable comparisons must not become unchanged counts.

History/alert tests need an isolated temporary directory and a temporary user mapping. Explicitly enable consent, record a baseline, grow only the temporary file beyond the threshold, and check the exact comparable delta and real notification. Replay must not notify again; partial measurements must not invent exact growth. Remove only test associations/data, confirm mapped files were not deleted, and restore the prior preferences and consent. Never clear a user's existing history merely to reset a test.

Updater changes also require an **isolated restartable shell** and independent systemd worker: check exact-commit success, post-restart failure with unchanged-data rollback, and changed-data recovery preserving the new generation. Never inject failure into a user's live desktop or publish fixture releases. In Settings check default-off preparation, unsupported/no-release states, stale-review invalidation and the explicit whole-shell restart warning.

## Invariants to preserve

- **Read-only application storage:** read metadata, never execute desktop `Exec` commands, edit/delete app files, or turn possible leftovers/cache into cleanup advice. Plugin-owned preferences/history and approved code updates are separate writes.
- **Safe paths and text:** no storage-symlink traversal (including ancestors); reject special or unsafe action targets. Bound and validate worker data, display dynamic text as plain text, and use argument arrays/encoded file URIs rather than shell interpolation.
- **Honest measurements:** unknown is not zero, partial is not complete, and logical bytes are not disk allocation or reclaimable space. Preserve hard-link accounting, ownership evidence, excluded overlaps and independent overview/deep scopes. Counts cannot imply unseen coverage.
- **Optional history:** no silent recording or notification consent. Keep private, atomic, locked persistence and explicit corruption errors; never manufacture growth across incompatible or partial baselines. Appearance changes do not authorize history or downloads.
- **Safe updater:** stable official release, trusted provenance, bounded preparation and validation before exact-commit approval; no automatic installation/restart, weakened downgrade checks, overwritten local changes or recovery that destroys newer data.

## Issues, pull requests and screenshots

Discuss substantial behavior changes before implementing them. A focused PR should explain the user-visible problem, approach, affected contracts and checks performed, with regression tests and relevant documentation updated. Avoid unrelated refactoring or generated/private state.

For bugs, include Mosaic version/commit, Omarchy/Qt versions, install method, reproducible steps, expected/actual behavior and whether the scan was overview/deep/partial. Use minimal synthetic examples for mapping or accounting failures. Do not attach whole history files, raw IPC snapshots or logs without reviewing them: they can contain absolute paths and application inventories.

For screenshots or recordings, use synthetic/demo data and crop to the plugin. Exclude real usernames, paths, application inventories, notifications and unrelated desktop content. Inspect every frame before sharing; discard private captures rather than committing them. Clearly label illustrative artwork rather than presenting it as runtime evidence.

### Preview artwork

The root [`preview.png`](preview.png) is the cinematic hero; [`preview-pages.png`](preview-pages.png) covers every page, category tab and Settings section. Editable compositions live in [`assets/preview.html`](assets/preview.html) and [`assets/preview-pages.html`](assets/preview-pages.html). Both use actual native captures with synthetic data from `assets/previews/`, plus the original [`landscape artwork`](assets/showcase-wallpaper.svg). No external requests or scripts.

The compositions mix straight-on cards with inward/outward Y-axis rotations only. Native captures use Tokyo Night, Catppuccin Latte, Everforest and Rosé Pine's light palette, with Mosaic's accent preferences. Apply palettes only in a temporary capture session; preserve the user's saved theme, settings and history rather than recolouring screenshot pixels.

Name the Installations capture `package-sizes.png`: the marketplace baseline treats binary filenames containing `install` as unscannable installer candidates. This screenshot naming convention does not change or exclude runtime installation-analysis or updater code.

From the repository root, render with librsvg and Chromium in a private browser profile:

```sh
rsvg-convert --output assets/showcase-wallpaper.png assets/showcase-wallpaper.svg
profile="$(mktemp -d)"
trap 'rm -rf -- "$profile"' EXIT
chromium --headless --disable-gpu --hide-scrollbars --no-first-run \
  --force-device-scale-factor=1 --user-data-dir="$profile" \
  --window-size=3600,2200 --screenshot=preview.png "file://$PWD/assets/preview.html"
chromium --headless --disable-gpu --hide-scrollbars --no-first-run \
  --force-device-scale-factor=1 --user-data-dir="$profile" \
  --window-size=3200,5562 --screenshot=preview-pages.png "file://$PWD/assets/preview-pages.html"
```

The gallery height follows its content; remeasure it if captures or layout change. Inspect both PNGs at full size and at README width. Keep the sample-data labels visible and capture new UI rather than drawing controls or results that the plugin does not provide. The original landscape follows the project's MIT license; application names and icons in captures belong to their respective owners.

Contributions are made under the project's [MIT license](LICENSE). Preserve its copyright and permission notice when redistributing substantial portions.
