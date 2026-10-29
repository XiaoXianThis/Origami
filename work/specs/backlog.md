# backlog

TODOs and ideas that belong to no spec. When an item takes shape, move it into a new spec and remove it here.

- Ship a Windows build, or dual-platform support. Requires a platform layer written against Win32 (`EnumWindows`, `SetWindowPos`, `RegisterHotKey`) instead of AppKit/AX; see `docs/architecture/overview.md` for the macOS-only pieces that have to be replaced.
- Add a `LICENSE` file at the root. `docs/README.md` says MIT but no license file is committed yet; optional root entries need the user's approval.
- Add automated tests. The mac app is verified by hand today; the site only by `astro build`.
