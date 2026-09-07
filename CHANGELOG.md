# Changelog

<!-- <START NEW CHANGELOG ENTRY> -->

<!-- <END NEW CHANGELOG ENTRY> -->

## [1.0.97] - 2026-09-07

### Changed

- No functional change. Released alongside the light siblings so all four Galaxa themes carry a release from the same date. The colourful-tab dark palette is unchanged in this round and the theme never overrode it

## [1.0.96] - 2026-09-07

### Changed

- No functional change. Released alongside the light siblings so all four Galaxa themes carry a release from the same date. Colourful-tab accents verified on screen and by computed style to render identically to stock JupyterLab Dark - the tab bar sits within 3 CIELAB L\* of stock's, so no palette override is needed here

## [1.0.95] - 2026-09-06

### Changed

- Renamed into the galaxalabs family: the GitHub repository is now `jupyterlab_galaxalabs_steel_dark_theme` and the npm and PyPI distributions are `galaxalabs_jupyterlab_steel_dark_theme`. The previous distribution `stellars_jupyterlab_sublime_theme` is frozen at 1.0.94 and receives no further releases; installations of it must be replaced rather than upgraded

## [1.0.94] - 2026-09-05

### Changed

- Theme menu entry renamed to `Galaxa Dark Theme - Steel`, which groups the four sibling themes into one contiguous block in the theme picker. Only the display name registered with `IThemeManager` changes - the repository, the npm package and the PyPI distribution keep their identifiers, so existing installations keep working

## [1.0.93] - 2026-09-05

### Changed

- Theme menu entry renamed to `Steel Dark Theme`. Only the display name registered with `IThemeManager` changes - the repository, the npm package and the PyPI distribution keep their identifiers, so existing installations keep working

## [1.0.92] - 2026-07-02

### Fixed

- Suppressed the stuck pressed-state box-shadow on file browser toolbar buttons - JupyterLab leaves the Upload button at `aria-pressed="true"` after a file upload, which rendered a permanent inset shadow

### Changed

- Updated build `Makefile` to canonical v1.32 - build now uses a project-local `.nodeenv/` instead of overwriting the Python prefix
- Added `.nodeenv/` to `.gitignore`
