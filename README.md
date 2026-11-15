# Match3 (cykgames 004)

![Game screenshots](screenshots/combined.png)

**Author:** cykbot4 (bot4) — cykgames AI-agent fleet. Base game: luiz734 (MIT).
**Genre:** puzzle · **Engine:** Godot 4.7.2 (`gl_compatibility`) ·
**Platform:** Android arm64, portrait, touch-first
**Status:** mvp / playable — headless + on-device verified 2026-11-15.

A Halloween-themed **match-3 puzzle**. Based on the MIT-licensed
[luiz734/match3_game](https://github.com/luiz734/match3_game) @ `b0a986e`.

## How to play

- **Drag a piece onto an adjacent piece** to swap them (touch or mouse).
  A swap only sticks if it makes a match of 3+; otherwise it swaps back.
- Match 3 / 4 / 5 / T-shapes score points; cascades build combos.
- The top bar shows your **score**, the **level** counter, and a level-up
  progress bar that drains over time — keep matching to stay alive.
- **Shuffle** rearranges the board but costs one level.
- **Restart** starts a fresh run; **Menu** returns to the title screen.
  Escape / Android back also navigate back.
- If the level counter drops below zero, it's game over.

## Controls

| Input | Action |
|---|---|
| Drag piece → adjacent piece | Swap (touch / mouse) |
| Shuffle button | Shuffle board (costs 1 level) |
| Restart button | New run |
| Menu button | Back to title |
| Escape / Android back | Back / quit from title |

## Design sources

- **Base code + art**: luiz734/match3_game (MIT code; art/audio author-owned
  with an informal reuse grant in the upstream README). `match3_core.gd`
  (pure match logic) is **unchanged** from upstream; unit tests pin it.
- **cykbot4 adaptation**: `gl_compatibility` + portrait 216x384 base with
  `canvas_items`/`expand` stretch; on-screen Restart/Menu buttons (upstream
  was Escape-only); Android hardware back; headless test/autoplay tooling;
  Android export preset (arm64-v8a, `com.cykagent.match3`).
- **Upstream bugs fixed**: leaked `Match3Core` Node per session; freed-instance
  refs in `main.gd`; overlapping game-over labels; grid overflow.
- **Font swap**: non-redistributable fff-forward (Fonts For Flash EULA) removed
  everywhere → Terminal Grotesque (SIL OFL 1.1). See `CREDITS.md`.

## Build

Requires Godot 4.7.2 (console binary) with Android export templates + SDK.

```sh
godot --headless --path . --import
godot --headless --path . --export-debug "Android" build/match3.apk
```

Package `com.cykagent.match3`, arm64-v8a only, portrait.

## Verify (headless)

```sh
godot --headless --path . res://tools/test_core.tscn   # 12 core unit tests, expect TEST_CORE PASS
godot --headless --path . res://tools/autoplay.tscn    # 65s autoplay bot, expect AUTOPLAY PASS
```

## Handoff / debugging

Read `docs/CHECKPOINT.md` first — it contains the full root-cause analysis of
the device-only layout bug below, with evidence and ruled-out alternatives.

- **🔴 Godot 4.7 anchor trap (the big one)**: a `Control` parented to a
  `Node2D` has a **zero anchor reference area** — full-rect anchors collapse to
  `custom_minimum_size` centered at the origin, so on device only a screen
  fragment renders while headless tests stay green. Fix lives in
  `scripts/main.gd::_fit_ui()` (pin UI roots to the viewport visible rect +
  refit on `size_changed`) and `scripts/game_ui.gd::_place_grid()` (center the
  board in the stretching border). **Any new UI root must go through
  `_fit_ui`.**
- **Key files**: `scripts/main.gd` (scene switching, `_fit_ui`),
  `scripts/game_ui.gd` (board layout, buttons), `scripts/grid.gd` (piece
  sprites, swap animation), `scripts/match3_core.gd` (untouched logic),
  `scenes/main.tscn` / `game.tscn` / `game_over.tscn`, `tools/test_core.*` /
  `tools/autoplay.*`.
- **Device reproduce** (placeholders — real device facts stay out of this repo):
  ```sh
  adb -s <SERIAL> install -r build/match3.apk
  adb -s <SERIAL> shell am start -n com.cykagent.match3/com.godot.game.GodotAppLauncher
  adb -s <SERIAL> shell screencap -p /sdcard/m.png && adb -s <SERIAL> pull /sdcard/m.png
  ```
  If `adb install` fails with an empty error on a unit, fall back to
  `adb push` + `adb shell pm install -r /data/local/tmp/<name>.apk`.
  On a 1080x2340 screen: menu New Game center ≈ (540,1067); board cell centers
  ≈ (140+160*col, 592+160*row).
- **Verified on device (2026-11-15)**: full-screen menu cold + resume, real
  swipe swaps with cascades, level progression. On-device audio untested.
- **Known issues / open items**: debug-signed only; no pause on focus loss;
  `Events.current_score` never updated upstream (score lives in the label);
  level-0 progress bar can hit float inf (harmless, upstream `0.9 / level`);
  dead `scripts/game.gd` left alone (scene uses `game_ui.gd`).
- **Privacy rule**: never commit LAN IPs, device serials, user-profile paths,
  agent workspace names or credentials; scan worktree + history before push.

## Credits

Adaptation: cykbot4 (bot4). Base game MIT © 2023 luiz734; art/audio
author-owned; Terminal Grotesque font SIL OFL 1.1 (`assets/fonts/OFL.txt`).
The non-redistributable fff-forward font was removed. Full list:
[CREDITS.md](CREDITS.md).