# Credits — 004-match3

## Base game

- **match3_game** by **luiz734** — https://github.com/luiz734/match3_game
  - License: **MIT** (see `LICENSE`, kept verbatim; Copyright (c) 2023 luiz734).
  - Upstream commit used: `b0a986e` (shallow clone, 2026-11-15). History not
    inherited; files copied into this repo.
  - Itch.io page: https://luiz734.itch.io/match3-game

## Art / audio assets

- All game art (`assets/drawables/*.png`, `mobile-ui.aseprite` source) and the
  score sound (`assets/audio/score.mp3`) are **author-owned by luiz734**, who
  grants reuse in the upstream README: *"I own all the assets used. Feel free
  to use them. I do not own the fonts."* (informal permissive grant, not a
  formal SPDX license).
- `screenshots/` preview images are from the same upstream repo.

## Fonts

- **Terminal Grotesque** by Tyler Finck (Sursly) — `assets/fonts/terminal-grotesque.ttf`
  - License: **SIL Open Font License 1.1**, Reserved Font Name "Blackout".
  - Full license text shipped as `assets/fonts/OFL.txt`.
  - Used everywhere (UI themes + level label) after the font swap below.
- **fff-forward was REMOVED** from this repo. Its Fonts For Flash EULA forbids
  redistribution ("FFF fonts may not be redistributed, modified or resold in
  any way without the written permission"), so it cannot ship in a public
  repo. All references were switched to Terminal Grotesque.

## Engine

- **Godot Engine** — https://godotengine.org — MIT license. Built with
  Godot 4.7.2.stable (upstream targeted 4.2).

## Modifications (cykbot4 / bot4, 2026-11-15)

- Adaptation author: **cykbot4 (bot4)**, cykgames AI-agent fleet (sub-worker
  build + bounded fix task under bot4 orchestration and review).
- Renderer switched to `gl_compatibility` (+ mobile override), portrait
  216x384 base with `canvas_items` + `expand` stretch for phones.
- On-screen **Restart** and **Menu** buttons (upstream back was Escape-only);
  Android hardware back handled via `Window.go_back_requested`.
- Fixed upstream bugs: leaked `Match3Core` Node per game session, freed-instance
  references in `main.gd`, overlapping game-over labels, grid overflow (x=28→12).
- Headless verification tooling (`tools/test_core.*`, `tools/autoplay.*`,
  `tools/gen_icon.gd`); audio skipped under the headless Dummy driver.
- Android export preset (arm64-v8a only, package `com.cykagent.match3`).
- `match3_core.gd` (the pure match logic) is **unchanged** from upstream.
