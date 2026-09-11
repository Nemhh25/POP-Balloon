# POP Balloon — Playtest Checklist

## First launch

- [ ] Start with no `user://` save: Main Menu appears and Continue is hidden.
- [ ] Open Settings; change audio, Fullscreen and VSync; close and reopen the game.
- [ ] Confirm settings persist without creating campaign progress.

## Campaign

- [ ] Start New Game and confirm the reset dialog when a save exists.
- [ ] Check Red through Rainbow progression, upgrades, equipment, specials, buffs and global upgrades.
- [ ] Enable and disable Hold to Click; verify it stops after losing focus, pause and scene changes.

## Save

- [ ] Quit from Pause/Menu, relaunch and use Continue.
- [ ] Confirm New Game resets campaign only, not audio/display settings.
- [ ] Verify a malformed campaign save is preserved and does not crash the game.

## Balloon King and Endless

- [ ] Unlock and challenge Balloon King.
- [ ] Check phases, boss music, pop, Victory screen and credits.
- [ ] Continue into Endless, restart the game, and confirm Endless remains available without restarting the boss.

## Audio

- [ ] Menu, gameplay and boss music transition once each and loop.
- [ ] Balloon pops rotate through all three variants; critical, purchase, buff and UI SFX remain audible.
- [ ] Check Master, Music and SFX at 0%, 50% and 100%.

## Display and input

- [ ] Check 1280×720, 1600×900 and 1920×1080.
- [ ] Toggle Windowed/Fullscreen and VSync at runtime.
- [ ] Check menu/pause keyboard focus, Escape, mouse interactions and small-window behavior.

## Release build

- [ ] Launch `build/windows/POP Balloon.exe` with Godot/editor closed.
- [ ] Confirm no missing assets, fatal errors or console window.
- [ ] Verify save/settings use `user://` and no source-project path is required.
