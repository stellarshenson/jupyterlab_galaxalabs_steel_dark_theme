# Changelog

<!-- <START NEW CHANGELOG ENTRY> -->

<!-- <END NEW CHANGELOG ENTRY> -->

## [1.0.93] - 2026-09-05

### Changed

- Theme menu entry renamed to `Steel Dark Theme`. Only the display name registered with `IThemeManager` changes - the repository, the npm package and the PyPI distribution keep their identifiers, so existing installations keep working

## [1.0.92] - 2026-07-02

### Fixed

- Suppressed the stuck pressed-state box-shadow on file browser toolbar buttons - JupyterLab leaves the Upload button at `aria-pressed="true"` after a file upload, which rendered a permanent inset shadow

### Changed

- Updated build `Makefile` to canonical v1.32 - build now uses a project-local `.nodeenv/` instead of overwriting the Python prefix
- Added `.nodeenv/` to `.gitignore`
