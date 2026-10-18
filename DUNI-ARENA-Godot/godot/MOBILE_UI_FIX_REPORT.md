# Mobile combat UI correction

## Cause and change

Godot Web reports the physical backing-buffer size through Window.size. A 390×844 CSS-pixel phone at DPR 3 therefore appeared to be 1170×2532, incorrectly selecting the desktop side panel and shrinking touch controls. ArenaUI now fits the logical canvas to the browser CSS viewport while retaining the high-resolution render buffer. Menu, tower and battle share this sizing path.

Normal combat now places the HUD above the centered arena and party/action controls below it. Results use a centered, scrollable overlay with a fixed map/retry button. Deployment and Turning Point remain responsive. Layout child ordering changes only when necessary; death notifications overlay the board instead of shifting controls during a press. TP retains ready transcendence controls.

## Verification

- 13 UI/presentation suites: **23,213 checks, 0 failures**; see migration/mobile-ui-fix/ui-regression-results.json.
- Native X11 layout: **100 checks, 0 failures**, at 1280×720, 390×844, 390×700 and 360×640.
- Chromium 390×844 at DPR 1/2/3: logical button sizes remain consistent. DPR 3 screenshots and touch inputs cover Continue, deployment, battle, TP resume, retreat, centered result and map return. Guild dialog also inspected at DPR 3.
- Software WebGL is slow in this VM: simulation waits in the browser flow used DPR 1; DPR 3 was restored for screenshots and tested touch inputs. This is not a physical-phone performance measurement.
- Existing paired presentation test: 900 ticks / 24 actors; simulation, RNG, HP, position and attack state unchanged.
- Original web files: 19 unchanged hashes. Protected AI/combat/save/domain files: 173 unchanged hashes. Save schema v1 and existing saves preserved. No audio added.
- The full domain master runner was not rerun for this UI-only correction; the numbers above describe the current targeted checks.

## Evidence and publication

See migration/mobile-ui-fix/battle-three-way.png for original HTML / Godot before / Godot after. Individual browser screenshots and JSON results are in that directory. Publication details are in publication.json.

Updated existing Site: https://duni-arena-godot-125.kanduni.chatgpt.site . The release keeps the same audience and URL. Reloading the page loads the corrected game package without deleting browser saves.

## Migration note

Responsive decisions must use logical CSS dimensions on Web, not Window.size. Maintain high-DPI rendering separately from UI layout. Result presentation only displays settled data and never reruns settlement or rewards.
