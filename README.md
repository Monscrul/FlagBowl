# Flag Bowl — Playable Match Prototype

Open `project.godot` in Godot 4.7.x and press **F5**. No plugins or external art are required.

The game renders at 640×360 with nearest filtering and pixel snapping. Fractional viewport scaling fills the largest available 16:9 area; the default 1280×720 window gives an exact 2× scale. Other aspect ratios letterbox surplus space.

## Controls

| Input | Behavior |
| --- | --- |
| 1–5 / play buttons | Select Cross, Slants, Outs, Curls, or Streaks before a Blue snap |
| WASD | Move the selected athlete during live play |
| Mouse / left-click | Aim / throw while controlling the QB with possession |
| Enter before snap | Snap Blue's selected play; Red snaps automatically |
| Enter after dead ball | Skip the automatic between-play delay |
| Enter during possession change | Skip the automatic possession-change delay |
| Enter during live play | Ignored; cannot undo a down or reset the clock |
| Tab on defensive possessions | Switch Blue defenders D1–D5 while Red runs its offense |
| Q on Blue possessions | Return to the offensive carrier; cannot take over the Red QB |
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
- DEAD_BALL advances automatically after 1.2 seconds. A turnover passes through POSSESSION_CHANGE for 1 second. Enter can skip those delays. Blue waits in PRE_SNAP for play selection and Enter; Red calls a play and snaps after 1.5 seconds. There is no free live-play reset.
- A live play lasts at most 20 seconds, including time after the game clock reaches zero. The limit spots a held ball, or treats an airborne pass as incomplete, and consumes a down. This guarantees that a stalled final play can finish.

Blue is the human team and Red is the AI opponent. Teams reuse the existing offensive actors (QB and two receivers) and five defensive actors in their current roles. Colors and attack directions swap with possession. Red owns its QB and receivers; the human owns a Blue defender and may switch with Tab. On Blue offense, the human controls the QB and automatically takes over a catcher. The offensive roster is still three athletes; this milestone does not add two more offensive players.

## Five-play Resource playbook

| Key | Play | Route idea |
| --- | --- | --- |
| 1 | Cross | Staggered crossing routes through the middle |
| 2 | Slants | Quick inside breaks |
| 3 | Outs | Upfield stems, then breaks toward the sidelines |
| 4 | Curls | Sell deep, turn back, and settle |
| 5 | Streaks | Two vertical routes |

The five `.tres` assets live in `resources/playbook/`; `default_playbook.tres` is an `OffensivePlaybook` containing five `OffensivePlay` Resources. Each play exports a name, description, two waypoint arrays, and an AI read delay. Edit these assets in the Inspector to author routes. Waypoints are pixel offsets relative to receiver start positions; positive x is upfield and is mirrored automatically for Red. The default Cross retains the original prototype's routes.

Keys 1–5 or the pre-snap buttons update the formation preview. The current human selection persists into later Blue formations and may be changed before every snap. Selection is locked during live play and Red possessions. Runtime route arrays are copied, so running or editing a match cannot mutate a shared Resource. Invalid exported books fall back to the validated default before UI initialization.

Red cycles through the five calls deterministically across possessions. Its QB uses the play's read delay, estimates throw arrival positions from receiver velocity, and evaluates range, defender separation, lane clearance, and forward progress. With no safe read after 1.4 seconds, it scrambles; an open read can still produce a later pass. After a catch, the AI moves the carrier upfield and chooses lanes with more space. The QB, routes, and carrier operate automatically without taking control away from the human defender. This is a simple deterministic prototype AI, with no external dependencies.

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
- `scripts/match/match_flow.gd`: fixed-tick between-play pacing and opposing automatic snaps.
- `scripts/playbook/offensive_play.gd`, `offensive_playbook.gd`: reusable typed play authoring Resources.
- `scripts/playbook/play_selection.gd`: human pre-snap buttons, selected-call description, and selection highlighting.
- `scripts/offense/opposing_offense.gd`: opponent passing decisions, lead targets, scramble fallback, and carrier movement. It emits `decision_made`.
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

Swept pass detection considers offense and defense together. The first athlete along the segment catches; exact ties favor defense. Interceptions end the play and schedule possession change; there are no interception returns. On Blue offense, a catch transfers control to its receiver. On Red offense, a catch keeps the human on the selected Blue defender. Tab changes only the human defender; neither Tab nor Q can take over a Red athlete during a live play.

A defender within 18 pixels automatically pulls the carrier's flag unless a juke protects it. Flag pulls stop the play exactly once. Jukes require live possession and movement, do not stack with sprint, and respect walls. Speeds, radii, reaction range, route points, and ability timings are editable exports.

## Manual verification

1. Press F5. Confirm 0–0, 05:00, Blue own-ten, PRE_SNAP, the scoreboard/field markers, and five play buttons. Select each play using both keys and buttons; verify the route previews and descriptions change. Pre-snap movement remains locked.
2. Choose a play and press Enter. Run, sprint, juke, aim, and throw. Selection buttons should disappear and keys 1–5 must not alter the live routes. Tab must not take over Red defenders while Blue has possession.
3. Finish a play with a catch/run, flag pull, incompletion, or sideline exit. Watch the automatic dead-ball delay and new formation. Confirm the call can be changed before the next snap, LOS/down update correctly, and a miss retains LOS.
4. Complete a drive or turn the ball over. Wait through the automatic possession change: Red should call and snap its own play while the human selects a Blue defender. No debugger commands or manual possession edits are needed.
5. Use Tab to cycle D1–D5 and WASD/Shift to defend. Confirm Red's QB makes passes or scrambles, receivers follow mirrored routes, and a catcher runs toward the left goal. Q and mouse clicks must not control Red's offense. A catch must leave the human controlling a defender.
6. Pull a flag, intercept, or allow a score. Confirm the correct dead-ball spot, downs, score, and next possession. Four downs without the target must turn the ball over. Red's next snap is automatic; Blue's next snap waits for a play call and Enter.
7. Play to 00:00. The current play may finish, with a maximum 20-second live duration. Confirm GAME_OVER, a stable final score/winner or tie, frozen movement/flight, and R restarting with Blue, Cross, and 05:00. For a quicker manual run, temporarily set Match's `game_duration_seconds` to 30 in the Inspector, then restore 300.
8. Resize the window and test mouse aiming/UI button alignment. Inspect the Godot Debugger for errors.

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
godot --headless --path . --fixed-fps 60 --script res://tests/playbook_check.gd
godot --headless --path . --fixed-fps 60 --script res://tests/full_match_check.gd
```

Godot 4.7.2 validation: 113 rule checks, 46 match integration checks, 26 movement checks, 41 offensive checks, 64 defensive checks, 67 playbook/AI checks, and 11 full-match checks pass (368 total). Tests exit nonzero on failed assertions. Coverage includes shared Resource isolation, all five calls and routes, input/UI selection guards, mirrored formations, QB reads/covered-lane decisions, AI catches and running, human defensive control, scoring/turnovers, live-limit expiry, and restart.

`full_match_check.gd` runs the default five-minute live game clock from the kickoff-equivalent own-ten start to GAME_OVER. Its driver uses only play-selection, snap, throw, movement, sprint, and Tab inputs while default defense, AI, and automatic flow remain enabled. It never teleports actors, injects scores/results, edits possession/clock fields, or manually advances between plays. The completed run included 290 human snaps, 105 AI snaps/passes, and 20 AI catches. It verifies the final score display, stopped gameplay, and R restart. This checks completion and integration; game balance still uses placeholder prototype tuning.

Older regression fixtures disable automatic flow/opponent ownership where they isolate the prior manual phase behavior; the playbook and full-match suites exercise the production defaults. Movement fixtures unlock pre-snap movement solely to test collision geometry. Gameplay input cannot perform those fixture resets.

Headless import/parse and startup checks are run separately. The restricted environment emits a macOS certificate-access error and blocks writing global editor settings; no project script/scene/runtime errors appeared in passing checks. Desktop visuals and physical keyboard/mouse behavior still require manual verification.
