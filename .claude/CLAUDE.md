<!-- @import /home/lab/workspace/.claude/CLAUDE.md -->

# jupyterlab_stellars_sublime_theme Project Instructions

This file imports workspace-level configuration from `/home/lab/workspace/.claude/CLAUDE.md`.
All workspace rules apply. Project-specific rules below strengthen or extend them.

The workspace `/home/lab/workspace/.claude/` directory contains additional instruction files
(MERMAID.md, NOTEBOOK.md, DATASCIENCE.md, GIT.md, and others) referenced by CLAUDE.md.
Consult workspace CLAUDE.md and the .claude directory to discover all applicable standards.

## Mandatory Bans (Reinforced)

The following workspace rules are STRICTLY ENFORCED for this project:

- **No automatic git tags** - only create tags when user explicitly requests
- **No automatic version changes** - only modify version in package.json/pyproject.toml/etc. when user explicitly requests
- **No automatic publishing** - never run `make publish`, `npm publish`, `twine upload`, or similar without explicit user request
- **No manual package installs if Makefile exists** - use `make install` or equivalent Makefile targets, not direct `pip install`/`uv install`/`npm install`
- **No automatic git commits or pushes** - only when user explicitly requests

## Project Context

JupyterLab theme extension providing a dark Sublime Text-inspired color scheme. Current version 1.0.83.

- npm package: `stellars_jupyterlab_sublime_theme`
- PyPI package: `stellars-jupyterlab-sublime-theme`
- GitHub: `stellarshenson/jupyterlab_stellars_sublime_theme`
- Use `make publish` to build and publish to both registries
- Use `make install` for local development builds

## Commit Message Format

- Use conventional commit format: `feat / bugfix / chore: <description>`
- Keep descriptions concise and descriptive
- Use lowercase for commit messages
- Do not include "Generated with Claude Code" or "Co-Authored-By: Claude" in commit messages

## Journal Rules (Project-Specific)

- **APPEND ONLY**: New journal entries MUST be appended at the end of the file, never inserted between existing entries
- Entries maintain strict chronological order by position - the last entry in the file is always the most recent work
- Never reorder, move, or insert entries out of sequence
- The Stellars **journal plugin** is the canonical tool for this file: create via `/journal:create`, append via `/journal:update`, archive via `/journal:archive`. The `journal:journal` skill auto-triggers on any mention of "journal" and runs `journal-tools check` after every write
- Direct edits to `JOURNAL.md` are a last resort - prefer the plugin so modus secundis format, continuous numbering and append-only order are enforced automatically

## Strengthened Rules

- Follow the `jupyterlab-extension` skill when working on build, CI/CD, or jupyter-releaser workflows
- CSS changes should be tested visually in JupyterLab before reporting complete
- Theme variables live in `style/variables.css` - scrollbar overrides in `style/scrollbars.css` - general overrides in `style/custom.css`
