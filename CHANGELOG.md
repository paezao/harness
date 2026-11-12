# Changelog

Each installed harness records its version in `.claude/harness/VERSION`. Audit mode reads it and
applies the **Upgrade** steps of every newer entry below, oldest first, showing a diff for any file
the team has edited.

## 0.2.0

- Design system with a gallery: UI projects keep every token and component in a gallery people can open
  (Storybook, a `/gallery` route, a debug scene), and the designer and design-skeptic work from it.
- Screenshot tests: every gallery entry has a baseline screenshot checked by `acceptance` or CI.
- CI template: `.github/workflows/harness-verify.yml` runs `verify.sh` on pull requests.
- `.claude/harness/VERSION` records which harness version a project is on.
- Only `impeccable` is recommended for frontend design.

**Upgrade** from 0.1.0:
1. Refresh `.claude/agents/designer.md` and `design-skeptic.md` from the templates, keeping local edits;
   fill `{{GALLERY_LOCATION}}`.
2. If the project has a UI and a gallery, add the screenshot test command to `acceptance` (or to CI if slow).
3. Offer `templates/ci/harness-verify.yml` if the project has no CI job running `verify.sh`.
4. Write `.claude/harness/VERSION`.

## 0.1.0

First version: `CLAUDE.md` index, permissions, guard / format-on-edit / commit-gate hooks, `verify.sh`
receipts, task contracts, `/mock`, `/contract`, `/ship`, `/learn`, role agents and the recommended
skills catalog. Projects set up before `VERSION` existed are 0.1.0.
