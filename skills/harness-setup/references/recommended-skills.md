# Recommended skills catalog

This is a curated list. Edit it: add the skills you trust, remove the ones you don't.
The setup skill matches **signals** in the repo and offers the matching entries.

Install methods:
- **built-in** - ships with Claude Code; nothing to install, just mention it in `CLAUDE.md`.
- **plugin** - `/plugin install <name>@<marketplace>`; add to `.claude/settings.json` `enabledPlugins`
  so teammates get prompted for it.
- **vendor** - copy the skill folder into the project's `.claude/skills/`.

## Always

| Skill | Install | Why |
|---|---|---|
| `/code-review` | built-in | Bug-focused review of the current diff; complements `skeptic`. |
| `/simplify` | built-in | Cleanup pass for reuse and simplification before shipping. |
| `/security-review` | built-in | Security pass on the pending changes. |
| `/fewer-permission-prompts` | built-in | After a week of use, turns common read-only calls into allow rules. |
| `/run` | built-in | Launch the app and see a change working, not just tests passing. |

## By signal

| Signal in repo | Skill | Install | Why |
|---|---|---|---|
| Frontend (react/vue/svelte/next, `*.css`, Tailwind) | `impeccable` | plugin | Design critique, accessibility, responsive checks. |
| Charts/dashboards in code | `dataviz` | built-in | Consistent, accessible chart colors and forms. |
| `anthropic` / `@anthropic-ai/sdk` dependency | `claude-api` | built-in | Current model IDs, caching, tool use. |
| `posthog` / `posthog-js` dependency | `posthog:*` (e.g. `instrument-product-analytics`, `instrument-error-tracking`) | plugin | Correct instrumentation patterns. |
| Grafana / Prometheus / Loki config | `grafana-mcp:grafana-mcp-tools` | plugin | Query and dashboard workflows. |
| `project.godot` | `godot-export` | vendor/user | Asset export conventions for Godot. |
| Unity project | `unity-export` | vendor/user | Asset export conventions for Unity. |
| `*.uproject` | `unreal-export` | vendor/user | Asset export conventions for Unreal. |
| Game with 2D art needs | `pxl-pixel-art` | vendor/user | Sprites, tiles and icons as code. |
| Game with audio needs | `chirp-game-audio` | vendor/user | SFX and music as code. |
| `*.blend` files / Blender pipeline | `blender-director` | vendor/user | Multi-step Blender asset workflows. |
| Large greenfield or multi-phase roadmap | `gsd-*` (`gsd-new-project`, `gsd-plan-phase`) | user | Phase planning and execution at scale. Heavy; only for big efforts. |

## Guidance

- Recommend at most ~5 by signal. A long list gets ignored.
- A skill that requires an MCP server or account (PostHog, Grafana) only helps if the developer has
  access; say so when offering it.
- Skills that live only in one developer's `~/.claude/skills` cannot be relied on by teammates.
  Either vendor them into the repo (if licensing allows) or list them as optional in `CLAUDE.md`.
- Prefer one good skill per job over overlapping ones; this catalog lists one per signal on purpose.
