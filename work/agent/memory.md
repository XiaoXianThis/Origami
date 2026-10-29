# memory

Lessons learned by agents: pitfalls and proven approaches. Skim this before a larger task.

## Rules

- Write an entry only when the same problem comes up a second time, or when the user asks you to remember something.
- Record only what cannot be seen directly in the code and docs. Lessons about one app go to that app's `AGENTS.md`.
- Entry format: `- YYYY-MM-DD Symptom: ... Cause: ... Fix: ...`
- Delete entries that are no longer true. Past 50 entries, move coherent groups into `rules/` or `skills/` (with user approval).

## Entries

- 2026-10-30 Symptom: Swift builds succeed but the packaged app never gets window access. Cause: ad-hoc re-signing changes the CDHash, so the Accessibility grant made for the previous build no longer matches. Fix: remove the stale entry in System Settings → Privacy & Security → Accessibility, re-add the current `build/mac/Origami.app`, then relaunch; `PermissionProbe` prints the CDHash to confirm.
