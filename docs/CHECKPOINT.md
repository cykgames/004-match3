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

- **On-device verification (parent, A54)**: drag-to-swap via Control
  drag-drop with real touch; portrait expand layout on 1080x2340; Restart /
  Menu / Android-back buttons; audio actually plays on device.
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
