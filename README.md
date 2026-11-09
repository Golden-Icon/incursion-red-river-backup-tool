# Incursion Red River - Save Backup Tool

Simple menu-driven save backup and restore tools for **Incursion Red River** on
Windows and Linux (Steam Proton).

Both versions create timestamped backups, list existing backups for restore, and
automatically make a safety backup before overwriting your current saves.

Created by [Golden-Icon](https://github.com/Golden-Icon).

## Contents

| File | Platform |
| --- | --- |
| `IRR_Backup_Tool.bat` | Windows 10/11 |
| `IRR_Backup_Tool.sh` | Linux (Steam / Proton) |
| `README.md` | This file |

## Where the game stores saves

The game's internal Unreal project name is `Test_C` (it was originally called
*Project Quarantine*), so the save folder is named `Test_C` rather than the game
title.

### Windows

```text
%LOCALAPPDATA%\Test_C\Saved\SaveGames
```

For example:

```text
C:\Users\YourName\AppData\Local\Test_C\Saved\SaveGames
```

### Linux / Steam Proton

```text
~/.local/share/Steam/steamapps/compatdata/2116120/pfx/drive_c/users/steamuser/AppData/Local/Test_C/Saved/SaveGames
```

The Linux script reads Steam's `libraryfolders.vdf`, so it also finds the save
folder if the game is installed in a different Steam library.

## Where backups are stored

| Platform | Backup folder |
| --- | --- |
| Windows | `<Your Documents>\IRR_BACKUP` |
| Linux | `~/IRR_BACKUP` |

Each backup is a folder named:

```text
IRR_Backup_YYYY-MM-DD_HH-MM-SS
```

A `_PRE_RESTORE` backup is also created automatically before any restore.

Restoring makes the game's save folder match the selected backup. The backup
contains everything in `SaveGames`, including settings files such as
`GameSettingsSaveGame.sav`.

---

## Windows usage

1. Download or copy `IRR_Backup_Tool.bat`.
2. Place it anywhere convenient, such as your Desktop or Documents folder.
3. Make sure **Incursion Red River is closed**.
4. Double-click `IRR_Backup_Tool.bat`.

A command prompt window opens with this menu:

```text
[1] Back up save files
[2] Restore save files
[3] Exit
```

- Choose **1** to create a timestamped backup.
- Choose **2** to see a newest-first list of backups and restore one.
- Choose **3** to exit.

### Windows notes

- Run the script normally, under the same Windows user account that plays the
  game. Do not use "Run as a different user".
- The script creates `Documents\IRR_BACKUP` if it does not exist. It does **not**
  create the game's save folder; if the save folder is missing, launch the game
  once first.
- If Windows SmartScreen shows a warning, choose **More info > Run anyway**. The
  script is a plain, readable batch file and is not code-signed.
- Antivirus software may scan newly downloaded `.bat` files. You can open the
  file in Notepad to inspect it before running.

---

## Linux usage

1. Download or copy `IRR_Backup_Tool.sh`.
2. Make it executable:

   ```bash
   chmod +x IRR_Backup_Tool.sh
   ```

3. Make sure **Incursion Red River is closed**.
4. Run it:

   ```bash
   ./IRR_Backup_Tool.sh
   ```

The same menu appears:

```text
[1] Back up save files
[2] Restore save files
[3] Exit
```

### Linux requirements

The script uses standard Linux tools plus `rsync`:

- `bash`
- `rsync`
- `cp`, `mkdir`, `find`, `sort`, `date`

On Arch/CachyOS, install `rsync` with:

```bash
sudo pacman -S rsync
```

On Debian/Ubuntu:

```bash
sudo apt install rsync
```

### Linux notes

- The script auto-detects the Proton save folder. To override it manually:

  ```bash
  IRR_SAVE_DIR="/path/to/SaveGames" ./IRR_Backup_Tool.sh
  ```

- The script checks whether the game is running and warns you before continuing.
- If the automatic game-running check is incorrect, you can skip it:

  ```bash
  IRR_SKIP_GAME_CHECK=1 ./IRR_Backup_Tool.sh
  ```

- Backups are written to `~/IRR_BACKUP`.

---

## Restoring saves safely

Both scripts follow the same safety process:

1. You select a backup from the newest-first list.
2. The script asks for confirmation.
3. It creates a `_PRE_RESTORE` backup of your current saves.
4. It copies the selected backup over the live save folder.
5. It reports where the safety backup was stored.

If a restore fails, the safety backup is your fallback.

## Important notes

- **Close the game before backing up or restoring.** Writing to save files while
  the game is running can produce inconsistent backups or cause the game to
  overwrite restored data.
- If Steam Cloud is enabled for the game, Steam may sync saves when the game or
  Steam is launched. For the most reliable restore, close Steam first or
  temporarily disable Steam Cloud for Incursion Red River.
- Backups include graphics/input settings as well as progress. Restoring an old
  backup also restores the settings that were saved at that time.
- Keep multiple backups. The tool never deletes old backups automatically.

## Troubleshooting

### "Could not find the save folder"

- Launch Incursion Red River once so the game creates its save folder.
- Confirm you are running the script under the same Windows/Linux user that
  plays the game.
- On Linux, verify the Proton prefix exists at:

  ```text
  ~/.local/share/Steam/steamapps/compatdata/2116120/pfx
  ```

- If your Steam library is in a non-standard location, use `IRR_SAVE_DIR` to
  point the Linux script at the correct `SaveGames` folder.

### The restore list is empty

Create a backup first with option 1. The list only shows folders named
`IRR_Backup_*` inside the backup folder.

### Restore says it failed

- Close the game completely and try again.
- On Linux, make sure the save folder and its files are writable by your user.
- Check the `_PRE_RESTORE` safety backup, then retry.

## Disclaimer

This is an unofficial community tool and is not affiliated with Games Of
Tomorrow GmbH or Valve. Always keep independent backups of important save data.
