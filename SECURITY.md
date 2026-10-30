# Security policy

## Supported versions

Security fixes target the latest stable release, currently **v0.1.0**. Older releases and development snapshots are not maintained as separate security branches. The earlier `2.x` versions were internal development iterations, not published releases.

## Report a vulnerability privately

Use [GitHub private vulnerability reporting](https://github.com/naolselemon/mosaic/security/advisories/new), not a public issue or pull request, for suspected vulnerabilities. Include:

- The affected Mosaic version or commit, installation method, and relevant Omarchy, Quickshell and operating-system versions.
- Expected and actual behavior, likely impact, and minimal reproduction steps using disposable files where possible.
- Redacted errors, screenshots or a small proof of concept; for updater problems, include the installed and prepared commits and the reported update state.

Do not publish exploit details, credentials, personal paths, application inventories, scan snapshots, history files or recovery backups. Remove usernames, private directory names and unrelated data even from private reports. Coordinate disclosure through the private report rather than opening a public reproduction. Ordinary bugs without security-sensitive information can use [public issues](https://github.com/naolselemon/mosaic/issues).

## Read-only analysis is not a sandbox

Mosaic's scanner reads desktop-launcher metadata and filesystem metadata, not application document contents. It does not execute desktop `Exec` commands, modify application files or provide cleanup actions. Storage traversal rejects symbolic links, including ancestor-directory links, and uses finite scan budgets; launcher metadata exports may themselves be symlinks. Partial and unknown measurements are not proof that files are absent or safe to delete.

Folder actions recheck the target and pass an encoded file URI to the external file manager without shell interpolation. Copying a path changes the clipboard; copied paths are not shell-escaped. Custom mappings express your assignment, not independently verified ownership. A cache category or possible leftover is not deletion advice.

**Mosaic and its helpers run with your user's permissions inside an unsandboxed shell environment.** Read-only analysis is a design constraint, not OS-enforced isolation. Settings, optional history and updater operations write Mosaic-owned state; an approved update replaces plugin code and restarts the whole shell. Only install code you trust.

## Local data and network access

Detailed scan results stay in the running shell's memory. Optional local history is **off by default** and stores compact summaries, not full scan results. History retains at most 60 summaries within a 2 MiB limit and up to 50 alert events. Growth notifications require separate opt-in and history; their text contains a count, not application names or paths.

Mosaic stores:

| Data | Location |
| --- | --- |
| Recording/alert settings and custom mappings | `${XDG_CONFIG_HOME:-~/.config}/omarchy/mosaic/settings.json` |
| History and alert records | `${XDG_STATE_HOME:-~/.local/state}/omarchy/mosaic/history.json` |
| Updater state, staged code and recovery snapshots | `${XDG_STATE_HOME:-~/.local/state}/omarchy/mosaic/updater/` |
| Appearance and automatic-preparation consent | Mosaic's widget entry in `~/.config/omarchy/shell.json`, managed by Omarchy |

The separate Mosaic settings/history files use private permissions (0600 files, 0700 directories) and locked, atomic writes. These permissions do not protect against other software running as you. Disabling history stops recording and alerts but retains existing records. **Clear history** removes summaries and alert records, not mappings, application files, updater consent or recovery artifacts.

Storage analysis stays local: no telemetry or periodic background scans. Mapping source URLs are offline references, not runtime fetches. Release checks and preparation contact GitHub when requested or explicitly enabled; preparation can download code. Contribution links open GitHub in your browser only when selected. Automatic preparation defaults off and checks at most daily when due; it never authorizes installation or restart.

## Update protections and their limits

The updater accepts stable releases from the fixed official Mosaic repository. Installation requires a clean, standalone Git checkout at `$HOME/.config/omarchy/plugins/naolselemon.mosaic` with the official HTTPS origin. Modified copies, extra local files, shallow or divergent histories and downgrades are refused rather than overwritten.

Preparation checks release/manifest identity, the exact commit, ancestry, regular-file tree and size limits, then runs the installed Omarchy validator. Downloaded plugin code is not run during preparation. **Install & restart shell** approves only the displayed full commit; the backend revalidates the prepared tree and installed base before installation. Restart affects the entire shell, including other plugins.

Installation retains private snapshots and checks the installed commit, Mosaic readiness and unchanged shell activation/configuration. Original code can be restored only when owned data is unchanged and both code trees still validate. Uncertain outcomes remain **Recovery required**, retain code trees and snapshots, and block further installation. Do not delete those artifacts or overwrite newer data to force recovery; restarting the shell alone does not resolve an unverified installation. Staging may also use the private `$HOME/.config/omarchy/.mosaic-updater-staging` directory when needed for an atomic exchange.

These checks constrain provenance, replacement and recovery; they are not a security audit of release contents or a sandbox for installed code. They depend on the official repository, GitHub, the installed tools and your local account remaining trustworthy.
