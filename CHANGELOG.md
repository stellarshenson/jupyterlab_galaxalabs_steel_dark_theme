# Changelog

<!-- <START NEW CHANGELOG ENTRY> -->

<!-- <END NEW CHANGELOG ENTRY> -->

## [1.0.92] - 2026-07-02

### Fixed

- Suppressed the stuck pressed-state box-shadow on file browser toolbar buttons - JupyterLab leaves the Upload button at `aria-pressed="true"` after a file upload, which rendered a permanent inset shadow

### Changed

- Updated build `Makefile` to canonical v1.32 - build now uses a project-local `.nodeenv/` instead of overwriting the Python prefix
- Added `.nodeenv/` to `.gitignore`
