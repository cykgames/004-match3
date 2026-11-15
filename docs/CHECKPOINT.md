# 004-match3 — Build Checkpoint (2026-11-15)

Worker: cykbot4 build slot 004-match3 (wave 1). Base: luiz734/match3_game
(MIT, Godot 4.2). Target: Godot 4.7.2, Android arm64, portrait, touch.

## What was built

Playable match-3 MVP from upstream, with the wave-1 brief applied:

1. **Fresh shallow clone** of `https://github.com/luiz734/match3_game.git`
   (HEAD `b0a986e`, origin verified), files copied EXCLUDING `.git` — no
   upstream history inherited. `git init -b main`, repo-local identity,
   remote `https://github.com/cykgames/004-match3.git`. **No push.**
2. **Font red line**: deleted `assets/fonts/fffforwad.ttf` + its EULA
   (Fonts For Flash forbids redistribution). All 8 references (ui_theme.tres
   x4, ui_secondary.tres x3, game.tscn Level label x1) switched to bundled
   **terminal-grotesque.ttf** (SIL OFL 1.1); license shipped as
   `assets/fonts/OFL.txt`.
3. **Renderer / viewport**: `gl_compatibility` + `.mobile` override,
   ETC2/ASTC import, portrait orientation, 216x384 base with
   `stretch/mode="canvas_items"` + `stretch/aspect="expand"`; root Controls
   (menu / game / game-over) made full-rect so backgrounds fill taller phone
   screens. `emulate_touch_from_mouse=true` (drag-to-swap already works with
   touch via Godot Control drag-drop + default mouse-from-touch emulation).
4. **Touch buttons**: on-screen **Restart** + **Menu** in the bottom bar
   (upstream GoBack was Escape-only), wired `game_ui.gd → main.gd
   restart_game()/back_to_menu()`; Android hardware back via
   `Window.go_back_requested`.
5. **Export**: preset copied from 002-obby (read-only), package
   `com.cykagent.match3`, arm64-v8a only, `build/match3.apk`, launcher icon
   rasterized from upstream `icon.svg` (`tools/gen_icon.gd` → `icon.png`).
6. **Headless verification tooling**: `tools/test_core.tscn` (12 unit tests
   against the untouched core) + `tools/autoplay.tscn` (65s bot playing the
   real game with random valid swaps, match-seeking bias).

## Evidence (build/headless.log; build/ is gitignored)

Import (after UID sync): `WARNINGS: 0`, `SCRIPT ERRORS: 0`.

Unit tests:
```
TEST_CORE SUMMARY: passed=12 failed=0
TEST_CORE PASS
```
Covers: no-match board, horizontal/vertical MATCH_3 (exact indexes), MATCH_4,
MATCH_5, MATCH_T, swap accept + revert, gravity compaction, 2-iteration
cascade (6 pieces removed), removed_from_poll bookkeeping, loss condition
(level 0 → -1 emits game_over via real game scene).

Autoplay bot (real main.tscn, scripted swaps + button presses):
```
AUTOPLAY START: duration=65s interval=0.4s
AUTOPLAY: pressed on-screen Restart at t=30.0s
AUTOPLAY: pressed on-screen Menu at t=30.0s
AUTOPLAY SUMMARY: elapsed=65.0s swaps=20 score=2064 ui_score=2491 game_overs=0 restarts=1 back_to_menu=1
AUTOPLAY PASS
```
Both logs: 0 SCRIPT ERROR / 0 ERROR / 0 WARNING. Exit codes 0.

APK: `build/match3.apk` = **28,559,740 bytes** (~27.2 MB), signed (debug
keystore), verified `lib/arm64-v8a/` only. Export exit 0.

## Decisions / ruled-out

- **`match3_core.gd` kept VERBATIM** (brief: keep core untouched). All fixes
  landed in `grid.gd` / `main.gd` / scenes / label script. Unit tests pin
  core behavior for future drift checks.
- **No 4.2→4.7.2 script-drift errors found**: project imported and ran clean
  on 4.7.2; the work was mobile config + upstream bug fixes, not API migration.
- **Upstream bugs fixed** (documented, minimal):
  - `grid.gd`: `Match3Core.new()` extends Node but was never parented/freed →
    one leaked Node per game session. Now `add_child(match3_core)`.
  - `main.gd`: held freed-instance refs after game/game-over self-free →
    all access guarded with `is_instance_valid()`; clear-before-create.
  - `game_over.tscn`: 3 children in a MarginContainer overlapped → VBox.
  - Grid x=28 overflowed the 216px viewport by 4px → x=12 (centered).
  - `floating_score_label.gd`: explicit `audio.stop()` before free.
- **Headless audio**: the Dummy audio driver nondeterministically leaks
  `AudioStreamPlaybackMP3` objects when players die near quit (isolated and
  reproduced with a minimal scene; freeing a playing player without stop()
  leaks 1 stream + N playbacks). Fix: skip audio entirely when
  `AudioServer.get_driver_name() == "Dummy"` — headless has no output device;
  zero impact on device. Visual fade unchanged.
- **UID sync**: upstream `.gitignore` ignored `*.import`, so embedded asset
  UIDs were stale → first import warned "invalid UID". Regenerated imports,
  synced ext_resource UIDs in 11 .tscn/.tres files, committed `.import`
  files (Godot 4 best practice) → reimport 0 warnings.
- **Dead code left alone**: `scripts/game.gd` (scene uses `game_ui.gd`) and
  its `grid.swap_all_random()` reference (no scene connection calls it).
- **`get_notnull_first` docstring is misleading** (says nulls-on-top, actually
  returns non-nulls first); `grid.gd` doesn't use it (row-by-row fall). Test
  pins the ACTUAL behavior; cascade test applies game-direction gravity.
- **Loss model kept as upstream**: no "no valid moves" detection; loss =
  level counter < 0 (progress bar drains, shuffle costs a level).
- `screenshots/demo-match3.gif` kept (upstream preview, author-owned).

## Open items

- **On-device verification: DONE 2026-11-15 (fix task, A54 over USB)** — see
  "Device full-screen fix" below. Drag-to-swap, portrait expand layout,
  Restart/Menu buttons verified with real touch; audio on device still
  untested.
- **005-marble orientation anomaly** (landscape config renders portrait on
  the same device) was NOT investigated by this fix task. It is NOT explained
  by the 004 root cause below (004 is portrait by design); likely a separate
  export/manifest or layout issue in that repo.
- `Events.current_score` is never updated by upstream (score lives in the
  Score label); bot reads `Events.piece_scored` sum + label. Left as-is.
- Level-up progress can hit inf at level 0 (upstream `0.9 / level` float
  division); harmless (float inf, no crash), left as-is for timebox.
- No pause on focus loss; MVP timebox.

## Reproduce

`godot` = Godot 4.7.2.stable console binary; run from the repo root:

```sh
godot --headless --path . --import
godot --headless --path . res://tools/test_core.tscn     # expect TEST_CORE PASS
godot --headless --path . res://tools/autoplay.tscn      # ~65s, expect AUTOPLAY PASS
godot --headless --path . --script tools/gen_icon.gd     # icon.png (already committed)
godot --headless --path . --export-debug "Android" build/match3.apk
```

Privacy scan: `gh_sensitive_scan.py` (REPO retargeted to this dir; the
original hardcodes godot-parkour and ignores argv) — result recorded in the
worker report. Local commit only; **no push, no adb** per brief.

## Device full-screen fix (2026-11-15, bounded fix task)

Symptom (parent-verified, then reproduced here): cold start AND resume showed
a dark 540x960 px fragment top-left on the 1080x2340 A54 screen, rest gray,
only a left-cut "Exit" button. Headless tests were green, so device-only.

### Root cause (evidence-backed)

UI root Controls (`MainMenuUI`, `GameUI`, `GameOver`) are children of the
Node2D `Main`. In Godot 4.7 a Control whose parent is NOT a Control has a
**zero anchor reference area**: `get_parent_area_size()` returns (0,0) in
every layout mode (0/1/3 tested headless). Full-rect anchors therefore
compute a zero rect, clamped to `custom_minimum_size` 216x384 and centered
on the origin by `grow_*=2` → rect `(-108,-192,216,384)`.

The render transform was CORRECT all along (device logcat: content scale
mode=canvas_items, aspect=expand, visible rect 216x468, screen transform
scale 5.0). Only the bottom-right quadrant of the collapsed menu rect lands
on screen: (0,0)..(108,192) units x 5 = exactly the observed 540x960 px
fragment; Exit at (-98,2) x 5 = left edge -490 px (the left cut).

Evidence: `build/logcat_probe2.txt` (M3DBG lines: win 1080x2340, css 216x384,
xform 5.0, menu rect (-108,-192,216,384), exit (-98,2,196,37)); pixel analysis
of the symptom screenshot (dark region exactly x0..539, y0..959; button
y15..174, right edge 485) matches those rects x5 exactly. A headless SceneTree
probe reproduced the identical collapsed rect → NOT device-specific, NOT an
export/template/orientation problem.

Ruled out with device evidence: the desktop-only `get_window().size *= 2`
guard (OS.has_feature("android")=true on device, guard holds); stretch
settings (all correct, scale 5.0); stale APK (fresh probe exports reproduced
the symptom); orientation (004 is portrait by design).

### What changed

1. `scripts/main.gd`: `_fit_ui(ctrl)` pins each UI root to the viewport
   visible rect (top-left anchors + explicit size, begin grow); called for
   the menu in `_ready`, for game/game-over at instantiation, and for all
   live roots on `viewport.size_changed`.
2. `scripts/game_ui.gd`: `_place_grid()` centers the fixed 6x8 board inside
   the stretching `GridBorder` rect (connected to `GridBorder.resized` +
   deferred initial call). Piece sprites are center-anchored on cell
   origins, so board content = grid pos +/- half cell.
3. `scenes/game.tscn`: Grid x restored 12 → 28 (upstream value). With
   center-anchored sprites, x=12 clipped the left column by 4 units (20 px)
   and left dead space at right; the earlier "centering" fix had assumed
   top-left-anchored sprites.

### Verification

- Headless after fix: `TEST_CORE SUMMARY: passed=12 failed=0` /
  `TEST_CORE PASS`; `AUTOPLAY SUMMARY: elapsed=65.0s swaps=27 score=2112
  ui_score=3880 game_overs=0 restarts=1 back_to_menu=1` / `AUTOPLAY PASS`;
  import/test/autoplay logs contain 0 ERROR / 0 WARNING
  (`build/*_final.log`).
- Device (A54, USB, package com.cykagent.match3 only): cold start menu fills
  1080x2340 with both buttons centered/readable; HOME + relaunch (resume)
  renders the identical full-screen menu; gameplay board fully inside the
  border, no clipped pieces; real `input swipe` between adjacent cells
  changed score 252 → 729 (three swipes, cascades) and 902 on the final
  clean build (two swipes, level rose to 4).
- Screenshots: `build/final_menu.png`, `build/final_resume.png`,
  `build/final_game.png` (gitignored) and copies in the orchestrator
  workspace `artifacts/tmp/wave1_device/004-match3_final_*.png`;
  intermediate evidence `004-match3_fix1_menu.png`, `fix1_game*.png`,
  `004-match3_fix2_game*.png` in the same dir.
- Final APK `build/match3.apk` = 28,664,148 bytes, arm64-v8a only, signed.
- Temporary M3DBG prints and the headless layout probe were removed before
  the final commit; privacy scan re-run clean (worktree + history).

### Reproduce (device part)

```sh
godot --headless --path . --export-debug "Android" build/match3.apk
adb -s <A54-serial> install -r build/match3.apk
adb -s <A54-serial> shell am force-stop com.cykagent.match3
adb -s <A54-serial> shell am start -n com.cykagent.match3/com.godot.game.GodotAppLauncher
# sleep ~9, then:
adb -s <A54-serial> shell screencap -p /sdcard/m3.png && adb -s <A54-serial> pull /sdcard/m3.png menu.png
adb -s <A54-serial> shell input tap 540 1067          # New Game
adb -s <A54-serial> shell input swipe 460 1073 620 1073 300   # adjacent-cell swap
```

Board cell centers on the 1080x2340 screen: (140+160*col, 592+160*row)
approx, after `_place_grid` centering; menu New Game center (540,1067).

## Author attribution & handoff docs (2026-11-15, cykbot4)

- User-requested attribution: title menu shows "by cykbot4" (Author Label in
  `scenes/main.tscn`); README header + CREDITS name cykbot4 (bot4) as
  adaptation author; org catalog row carries an Author column.
- README rewritten as a handoff doc: design sources, the Control-under-Node2D
  anchor trap + `_fit_ui` rule, key-file map, device reproduce with
  placeholders, known issues, privacy rule.
- Re-verified after the label change: `TEST_CORE SUMMARY: passed=12 failed=0`
  + `AUTOPLAY PASS`; APK re-exported, installed on A54, menu screenshot shows
  the credit line (orchestrator
  `artifacts/tmp/wave1_device/004_author_menu.png`).
- Device install note: `adb install` streamed/incremental sessions failed
  with empty errors on this unit; `adb push` + `pm install -r` works.
