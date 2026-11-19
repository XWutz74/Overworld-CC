# Overworld-CC

A trading game for ComputerCraft (CC: Tweaked, Minecraft 1.18.2), ported from the browser game "Overworld".
Buy low, sell high, stay out of trouble, and pay back the loan shark before he comes for you.

## Installing

On a computer in the game (an advanced computer for colour and mouse), type:

```
pastebin run <code>
```

The installer downloads Overworld from this repository and asks whether it should start when the computer turns on.
Then type `overworld` to play. Running the installer again repairs or updates an install.

The server must allow http in the ComputerCraft config (`computercraft-server.toml`, `[http] enabled = true`, and
GitHub must not be blocked), otherwise the installer cannot download anything.

### Updates

An installed copy keeps itself up to date. While you play it asks GitHub (at most every 30 minutes) whether there is a
newer version, downloads it in the background and checks every file. The new files go in at the next start of the
game, never in the middle of a game. Your games, characters, settings and scores in `overworld-save/` are never
changed or deleted by an update. Without internet, or when GitHub cannot be reached, the game simply starts with the
files it has.

To switch updates off on one computer:

```
set overworld.autoupdate false
```

(`set overworld.autoupdate true` switches them back on.) `overworld.log` notes what the updater did.

If the Java of a Minecraft client does not trust the certificate of `api.github.com` ("Could not create a secure
connection"), the installer and updater fall back to `version.txt` in this repository, which names the current version
(a fingerprint of the game's files), and download the files from the branch itself. Maintainers: run `tools/stamp.sh`
before every commit and commit `version.txt` with it.

## Playing

Without the installer: copy `overworld.lua` and the `ow` folder onto a computer and run `overworld`
(such a copy does not update itself).

The screen must be at least 51 x 19 characters, so pocket computers are not supported yet.
Texts are in English; German can be chosen under Menu > Settings.

| Key | Action |
| --- | --- |
| Up / Down, mouse | choose a product |
| Enter | buy the chosen product (or sell it if you carry it) |
| B / S / D | buy / sell / drop; capital letter (Shift) or Ctrl: the maximum |
| 1 - 5 | go to a district (one day); your own district or 0: stay a day |
| H L N T | hospital, loan sharks, bank, store |
| E C J | items, charts, messages |
| M | menu: settings, scores, keys, retire, new game, save and leave |

In windows: Enter confirms, Left/Right or Tab pick a button, Backspace goes back.
Esc and the F keys are not used because Minecraft keeps them for itself.
Ctrl+T (held) leaves the game; it is saved first.

Games, characters, settings and scores are saved in `overworld-save/` next to the program.

## Files

- `overworld.lua` starts the game.
- `ow/game.lua` the rules (market, travel, encounters, bank, loans, store), no screen code.
- `ow/app.lua` the screens, `ow/ui.lua` windows, lists and buttons.
- `ow/data/world.lua`, `ow/data/presets.lua` the content: goods, items, districts, enemies, difficulty.
- `ow/lang/en.lua`, `ow/lang/de.lua` all texts; `*_cc.lua` texts only this version needs.
- `overworld_install.lua` the installer (the Pastebin one), `startup.lua` runs the game on boot (installed as
  `overworld_startup.lua`), `standalone.txt` lists the files an install gets, `ow/lib/standalone_update.lua` updates.

The data and text files are made from the browser game by `node tools/convert-web.js <Overworld folder>`.
Run that again when the browser game's content changes.

## Tests

The tests run with ccunit in the CraftOS MCP emulator (`craftos_test`):

- `tests/game.test.lua` checks the rules.
- `tests/install.test.lua` installs and updates against a fake GitHub (saves kept, broken files refused, no internet).
- `tests/fuzz.test.lua` plays thousands of random key presses in English and German, with and without violence, and checks the game never crashes.

## Credits

The installer and the automatic update system (`overworld_install.lua`, `startup.lua`, `ow/lib/standalone_update.lua`)
are taken from [Roger-Code](https://github.com/Akkiruk/Roger-Code) by Akkiruk (SALTGATE's standalone installer), copied
and adapted for Overworld-CC with the author's permission.
