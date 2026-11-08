# Flag Bowl — Deterministic Match Prototype

Open `project.godot` in Godot 4.7.x and press **F5**. No plugins or external art are required.

The game renders at 640×360 with nearest filtering and pixel snapping. Fractional viewport scaling fills the largest available 16:9 area; the default 1280×720 window gives an exact 2× scale. Other aspect ratios letterbox surplus space.

## Controls

| Input | Behavior |
| --- | --- |
| WASD | Move the selected athlete during live play |
| Mouse / left-click | Aim / throw while controlling the QB with possession |
| Enter before snap | Snap and start routes, defense, and clock |
| Enter after dead ball | Prepare the next formation or enter possession change |
| Enter during possession change | Confirm the new team and prepare its first snap |
| Enter during live play | Ignored; cannot undo a down or reset the clock |
| Tab | Select D1, cycle through D5, then wrap |
| Q | Return to the offensive carrier, or QB during flight |
| Shift | Sprint at 1.45× speed |
| Space while moving with the ball | Juke: 0.18-second dash/protection, 1.2-second cooldown |
| R at GAME_OVER | Start a new match |

A yellow ring marks the selected athlete. A cyan ring marks juke protection. The camera follows the selection horizontally within the field. All athletes are locked before the snap and between plays. Escape is reserved; pause is not implemented.

## Match rules

- Blue begins with the ball on its own 10-yard line and attacks right. Red attacks left.
- Each possession has four downs to reach midfield. Reaching or passing midfield at the dead-ball spot grants four downs to score. This reset happens once per possession; retreating and recrossing midfield does not grant another reset.
- A possession beginning beyond midfield starts directly with four downs to score.
- A touchdown is worth six points. No extra points, kicks, overtime, or safety points are implemented.
- After a touchdown, the opponent starts at its own 10-yard line.
- Interceptions and turnover on downs transfer possession at the dead-ball spot. An interception in the new team's own end zone is a touchback at its own 10.
- Stopping a carrier in its own end zone causes a turnover with the opponent starting at its own 10; this custom rule awards no points.
- Incomplete and out-of-bounds passes consume a down and retain the original LOS. A carrier running out of bounds consumes a down and advances/retreats the LOS to the exit spot.
- A carrier's **center** reaching the opponent goal line in bounds scores. At an exact sideline/goal-line corner, out of bounds takes priority. A valid touchdown takes priority over a simultaneous flag pull. Turnover/LOS spots are clamped to the open field between goal lines.
- The default game clock is five minutes, configurable as `game_duration_seconds` on Match. It advances by one integer tick per physics frame only in LIVE_PLAY. At zero, the current play can finish; its score counts, then the game ends. Ties remain ties.
- Enter advances between plays. A turnover is shown first in DEAD_BALL, then POSSESSION_CHANGE; another Enter prepares PRE_SNAP, and another snaps. There is no free live-play reset.

Both teams reuse the existing offensive actors (QB and two receivers) and five defensive actors in their current roles. Team colors and attack directions swap with possession; this prototype does not yet expand the offensive roster to five or simulate an autonomous opposing QB.

## Field coordinates

All authoritative conversions are in `scripts/field/field.gd`.

| Landmark | World coordinate |
| --- | --- |
| Field rectangle, including end zones | x = 40…1440, y = 40…320 |
| Left / right goal line | x = 240 / 1240 |
| Midfield | x = 740 |
| Scale | 20 pixels per yard |
| Playing field / end zones | 50 yards / 10 yards each |
| Blue / red own-10 starting LOS | x = 440 / 1040 |
| Center row | y = 180 |
| Athlete collision radius | 8 pixels |

Physical walls stop centers at x = 48…1432 and y = 48…312. Carrier sideline detection uses those reachable centers, with a 0.1-pixel tolerance. Blue progress is `(x - 240) / 20` yards; red progress is `(1240 - x) / 20`. The blue marker is the LOS; gold marks midfield or the target goal line.

Each formation places the QB 40 pixels behind the LOS and receivers on it. Defenders use explicit LOS offsets. Possession changes mirror positions, route offsets, and coverage cushions; reset routes rebase to the new receiver positions. Waypoints are clamped inside the physical field.

## Architecture

- `scripts/match/match_rules.gd`: **single source of truth** for phase, offense/team direction, scores, downs, midfield eligibility, LOS, pending possession, result, and remaining clock ticks. A node-independent `RefCounted` model exposes `snap()`, `tick()`, `finish_play()`, and `advance()` with guarded transitions. It emits `changed` and `phase_changed` signals. Identical ordered events/ticks produce identical state.
- `scripts/match/match.gd`: scene adapter for input, ball/AI events, carrier goal/sideline checks, and formation application. It has no duplicate gameplay-phase enum or separate score/down/clock fields. `ball.holder`/`in_flight` distinguish running, catching, and passing within LIVE_PLAY.
- `scripts/match/formation.gd`: applies mirrored formation positions and team colors from rules.
- `scripts/match/match_hud.gd`: read-only scoreboard and control/status display.
- `scripts/field/field.gd`, `scenes/field/field.tscn`: field coordinates, placeholder drawing, and four physical walls.
- `scripts/player/player.gd`, `scenes/player/player.tscn`: reusable CharacterBody2D movement and control selection.
- `scripts/abilities/athlete_abilities.gd`: sprint/juke component, duration, cooldown, and protection.
- `scripts/routes/receiver_route.gd`: receiver waypoint following relative to the current formation and direction.
- `scripts/ball/football.gd`, `scenes/ball/football.tscn`: projectile, held ball, deterministic swept catches/interceptions, incompletes.
- `scripts/defense/defender_ai.gd`, `scenes/defense/defender.tscn`: independent idle, coverage, pursuit, and interception handlers.
- `scripts/camera/horizontal_camera.gd`: horizontal following with field limits.
- `scenes/match/match.tscn`: startup scene and assembly.

The phase flow is PRE_SNAP → LIVE_PLAY → DEAD_BALL → PRE_SNAP for ordinary plays. Turnovers/scoring use DEAD_BALL → POSSESSION_CHANGE → PRE_SNAP. A play ending after the clock reaches zero transitions from LIVE_PLAY directly to GAME_OVER after its result is applied. Duplicate/illegal transitions are ignored; a score cannot be applied twice.

`possession_changed` reports athlete ball ownership; `control_changed` separately reports selection. `play_started`, `pass_thrown`, `flag_pulled`, and `play_ended` connect major gameplay events. Team possession and drive rules are owned by MatchRules, not inferred from which scene node holds the ball.

## Passing and defense

Passes travel straight at 400 pixels/second with a 420-pixel maximum range and a 14-pixel catch radius. Lead receivers early; D3 rushes after 1.5 seconds. D1/D2 cover R1/R2, and D4/D5 bracket them from deeper cushions. Defenders within 145 pixels react to an airborne pass; after a catch they pursue the carrier.

Swept pass detection considers offense and defense together. The first athlete along the segment catches; exact ties favor defense. Interceptions end the play and schedule possession change; there are no interception returns. Manual defender selection persists through an offensive catch; Q returns to the receiver. Throw first, then Tab to defend the pass; a QB is not autonomous when you select defense.

A defender within 18 pixels automatically pulls the carrier's flag unless a juke protects it. Flag pulls stop the play exactly once. Jukes require live possession and movement, do not stack with sprint, and respect walls. Speeds, radii, reaction range, route points, and ability timings are editable exports.

## Manual verification

1. Press F5. Confirm 0–0, 05:00, PRE_SNAP, 1/4, 15 yards to midfield, and both LOS/target markers. WASD should not move the pre-snap formation.
2. Press Enter. Confirm clock, receiver routes, and defense start. Test WASD, sprint, juke, Tab cycling, Q, mouse aim, and throws. Enter during live play must not reset anything.
3. Throw into empty grass. Confirm an incomplete consumes one down, retains the LOS, and stops the clock. Enter should place a new formation at that LOS; Enter again snaps. Four incompletes should show turnover on downs, then possession-change and mirrored formations after Enter.
4. Run/catch past midfield and let a defender pull the flag. Confirm first down, four downs to score, updated LOS, and the target marker at the opponent goal. Losing and regaining midfield must not grant more downs.
5. Reach either opponent end zone with a carrier or reception. Confirm six points exactly once and frozen play. Advance possession and verify the opponent's own-10 start, reversed route/defensive movement, swapped colors, and camera target.
6. Throw through a defender. Confirm interception, dead-ball result, next team at the interception spot (or touchback for its own end zone), first down, and cleared old ball candidates/routes after formation placement.
7. Run into a sideline. Confirm a reachable physical boundary ends the play and spots the ball there. Throw out of bounds and confirm the LOS stays unchanged. Verify a short-of-goal stop does not score.
8. For a quick clock check, set Match's `game_duration_seconds` to 5 in the Inspector. Clock must pause between plays. Once it reaches zero during a live play, finish the play: its touchdown can count, then GAME_OVER must freeze input and display a winner or tie. Enter must not restart it; R should create a clean game. Restore 300 after testing.
9. Resize to 1278×719 and other sizes; confirm 16:9 fitting, readable HUD, and mouse/world aiming alignment. Inspect the Godot Debugger for errors.

## Automated validation

Run with your Godot executable (`godot` below):

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --quit-after 120
godot --headless --path . --fixed-fps 60 --script res://tests/match_rules_check.gd
godot --headless --path . --fixed-fps 60 --script res://tests/match_integration_check.gd
godot --headless --path . --fixed-fps 60 --script res://tests/milestone_1_check.gd
godot --headless --path . --fixed-fps 60 --script res://tests/offense_check.gd
godot --headless --path . --fixed-fps 60 --script res://tests/defense_check.gd
```

Godot 4.7.2 validation: 108 pure rule checks, 46 match integration checks, 26 movement checks, 41 offensive checks, and 64 defensive checks pass (285 total). Tests exit nonzero on failed assertions. Coverage includes mirrored scores, fourth-down midfield qualification, duplicate outcomes, interception spots/touchbacks, own-end-zone turnovers, boundary corners, deterministic clock replay, last-play scoring, formation/route resets, scoreboard state, and real passing/defense interactions.

Regression fixtures explicitly restart matches and isolate the original player/route layout where needed; the match integration suite verifies the real LOS-based formation and phase transitions. Movement checks unlock their fixture before the snap to exercise collisions independently. Gameplay input cannot perform those fixture resets.

Headless import/parse and startup checks are run separately. The restricted environment emits a macOS certificate-access error and blocks writing global editor settings; no project script/scene/runtime errors appeared in passing checks. Desktop visuals and physical keyboard/mouse behavior still require manual verification.
