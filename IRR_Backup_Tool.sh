#!/usr/bin/env bash
#
# Incursion Red River - Save Backup / Restore Tool (Linux / Steam Proton)
# By GoldenIcon
#
# Game saves (Proton prefix):
#   ~/.local/share/Steam/steamapps/compatdata/2116120/pfx/
#       drive_c/users/*/AppData/Local/Test_C/Saved/SaveGames
#
# Backups:
#   ~/IRR_BACKUP/IRR_Backup_YYYY-MM-DD_HH-MM-SS
#
# Optional override:
#   IRR_SAVE_DIR="/path/to/SaveGames" ./IRR_Backup_Tool.sh
#

set -uo pipefail

GAME_NAME="Incursion Red River"
GAME_APPID="2116120"
BACKUP_ROOT="$HOME/IRR_BACKUP"
SAVE_DIR=""

# ------------------------------------------------------------------
# Locate the game's live save folder
# ------------------------------------------------------------------
find_save_dir() {
    local candidate

    if [[ -n "${IRR_SAVE_DIR:-}" ]]; then
        if [[ -d "$IRR_SAVE_DIR" ]] && compgen -G "$IRR_SAVE_DIR/*.sav" >/dev/null; then
            printf '%s\n' "$IRR_SAVE_DIR"
            return 0
        fi
        return 1
    fi

    local roots=(
        "$HOME/.local/share/Steam"
        "$HOME/.steam/steam"
        "$HOME/.steam/root"
        "$HOME/.steam/debian-installation"
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
        "$HOME/snap/steam/common/.local/share/Steam"
    )

    # Add any extra Steam libraries listed in libraryfolders.vdf
    local vdf line
    for vdf in "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf" \
               "$HOME/.steam/steam/steamapps/libraryfolders.vdf" \
               "$HOME/.steam/root/steamapps/libraryfolders.vdf"; do
        [[ -f "$vdf" ]] || continue
        while IFS= read -r line; do
            if [[ "$line" =~ \"path\"[[:space:]]+\"([^\"]+)\" ]]; then
                roots+=("${BASH_REMATCH[1]}")
            fi
        done < "$vdf"
    done

    local -A seen=()
    local root user_dir save_dir
    for root in "${roots[@]}"; do
        [[ -n "${seen[$root]:-}" ]] && continue
        seen[$root]=1

        for user_dir in "$root"/steamapps/compatdata/"$GAME_APPID"/pfx/drive_c/users/*; do
            save_dir="$user_dir/AppData/Local/Test_C/Saved/SaveGames"
            if [[ -d "$save_dir" ]] && compgen -G "$save_dir/*.sav" >/dev/null; then
                printf '%s\n' "$save_dir"
                return 0
            fi
        done

        # Some setups keep the saves beside the game instead of in the prefix.
        save_dir="$root/steamapps/common/PROJECT QUARANTINE/Test_C/Saved/SaveGames"
        if [[ -d "$save_dir" ]] && compgen -G "$save_dir/*.sav" >/dev/null; then
            printf '%s\n' "$save_dir"
            return 0
        fi
    done

    return 1
}

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------
game_running() {
    [[ "${IRR_SKIP_GAME_CHECK:-0}" == "1" ]] && return 1
    pgrep -f 'Test_C-Win64-Shipping\.exe|PROJECT QUARANTINE/Test_C\.exe|SteamLaunch AppId=2116120' >/dev/null 2>&1
}

check_game_closed() {
    if game_running; then
        echo
        echo "WARNING: $GAME_NAME appears to be running."
        echo "Backing up or restoring while the game is open can produce bad saves."
        echo
        local answer
        read -rp "Continue anyway? [y/N]: " answer || return 1
        [[ "$answer" =~ ^[Yy]$ ]] || return 1
    fi
    return 0
}

do_backup() {
    local label="${1:-}"
    local stamp dest

    BACKUP_ERROR=1
    NEW_BACKUP=""

    stamp="$(date '+%Y-%m-%d_%H-%M-%S')"
    dest="$BACKUP_ROOT/IRR_Backup_$stamp"
    [[ -n "$label" ]] && dest="${dest}_${label}"
    [[ -e "$dest" ]] && dest="${dest}_$RANDOM"

    if ! mkdir -p -- "$BACKUP_ROOT"; then
        return 1
    fi
    if ! mkdir -- "$dest"; then
        return 1
    fi

    if ! cp -a -- "$SAVE_DIR/." "$dest/"; then
        rm -rf -- "$dest"
        return 1
    fi

    {
        printf 'Game: %s\n' "$GAME_NAME"
        printf 'Backup folder: %s\n' "$dest"
        printf 'Created: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
        printf 'Source: %s\n' "$SAVE_DIR"
    } > "$dest/backup_info.txt"

    NEW_BACKUP="$dest"
    BACKUP_ERROR=0
    return 0
}

clear_screen() {
    clear 2>/dev/null || true
}

# ------------------------------------------------------------------
# Backup menu
# ------------------------------------------------------------------
backup_menu() {
    clear_screen
    echo "================================================================"
    echo "  Back up $GAME_NAME save files"
    echo "================================================================"
    echo

    if [[ ! -d "$SAVE_DIR" ]]; then
        echo "Could not find the save folder:"
        echo "  $SAVE_DIR"
        echo
        echo "Launch the game once, then try again."
        echo
        read -rp "Press Enter to return to the menu..."
        return
    fi

    if ! compgen -G "$SAVE_DIR/*.sav" >/dev/null; then
        echo "The save folder exists, but it contains no .sav files:"
        echo "  $SAVE_DIR"
        echo
        echo "Start the game and create/load a character once, then try again."
        echo
        read -rp "Press Enter to return to the menu..."
        return
    fi

    check_game_closed || return

    echo
    if do_backup; then
        echo "Backup created successfully!"
        echo
        echo "  Folder: $NEW_BACKUP"
        echo
        echo "All backups are stored in:"
        echo "  $BACKUP_ROOT"
    else
        echo "The backup could not be created."
        echo
        echo "Make sure the game is closed and that you can write to:"
        echo "  $BACKUP_ROOT"
    fi

    echo
    read -rp "Press Enter to return to the menu..."
}

# ------------------------------------------------------------------
# Restore menu
# ------------------------------------------------------------------
restore_menu() {
    clear_screen
    echo "================================================================"
    echo "  Restore $GAME_NAME save files"
    echo "================================================================"
    echo

    local -a backups=()
    if [[ -d "$BACKUP_ROOT" ]]; then
        mapfile -t backups < <(
            find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d \
                -name 'IRR_Backup_*' -printf '%f\n' 2>/dev/null | sort -r
        )
    fi

    if (( ${#backups[@]} == 0 )); then
        echo "No backups were found in:"
        echo "  $BACKUP_ROOT"
        echo
        echo "Use option 1 to create a backup first."
        echo
        read -rp "Press Enter to return to the menu..."
        return
    fi

    local i
    for i in "${!backups[@]}"; do
        printf '  [%d]  %s\n' "$((i + 1))" "${backups[$i]}"
    done
    echo
    echo "  [0]  Cancel / return to menu"
    echo

    local choice idx selected
    while true; do
        if ! read -rp "Select a backup to restore: " choice; then
            return
        fi

        [[ "$choice" == "0" ]] && return

        if [[ ! "$choice" =~ ^[0-9]+$ ]]; then
            echo "Invalid selection. Please try again."
            continue
        fi

        idx=$((10#$choice))
        if (( idx < 1 || idx > ${#backups[@]} )); then
            echo "Invalid selection. Please try again."
            continue
        fi

        selected="${backups[$((idx - 1))]}"
        break
    done

    local src="$BACKUP_ROOT/$selected"
    if [[ ! -d "$src" ]]; then
        echo
        echo "That backup folder no longer exists:"
        echo "  $src"
        echo
        read -rp "Press Enter to return to the menu..."
        return
    fi

    if ! compgen -G "$src/*.sav" >/dev/null; then
        echo
        echo "That backup does not contain any .sav files:"
        echo "  $src"
        echo
        read -rp "Press Enter to return to the menu..."
        return
    fi

    clear_screen
    echo "================================================================"
    echo "  Confirm restore"
    echo "================================================================"
    echo
    echo "  Selected backup: $selected"
    echo
    echo "This will REPLACE your current save files with this backup."
    echo "Your current saves will be backed up automatically first."
    echo

    local confirm
    if ! read -rp "Type Y to continue, or N to cancel: " confirm; then
        return
    fi
    [[ "$confirm" =~ ^[Yy]$ ]] || return

    check_game_closed || return

    # Safety backup before overwriting
    echo
    echo "Creating safety backup of current saves..."
    NEW_BACKUP=""
    if [[ -d "$SAVE_DIR" ]]; then
        if ! do_backup "PRE_RESTORE"; then
            echo
            echo "WARNING: Could not create the safety backup."
            local answer
            if ! read -rp "Continue with restore anyway? (Y/N): " answer; then
                return
            fi
            [[ "$answer" =~ ^[Yy]$ ]] || return
        fi
    fi

    echo
    echo "Restoring files..."

    if ! mkdir -p -- "$SAVE_DIR"; then
        echo
        echo "Restore failed: could not create the save folder:"
        echo "  $SAVE_DIR"
        echo
        read -rp "Press Enter to return to the menu..."
        return
    fi

    if ! rsync -a --delete --exclude='backup_info.txt' -- "$src/" "$SAVE_DIR/"; then
        echo
        echo "Restore failed."
        if [[ -n "$NEW_BACKUP" ]]; then
            echo "A safety backup of your previous saves is here:"
            echo "  $NEW_BACKUP"
        fi
        echo
        echo "Close the game completely, then try again."
        echo
        read -rp "Press Enter to return to the menu..."
        return
    fi

    echo
    echo "Restore complete!"
    echo
    echo "Files restored to:"
    echo "  $SAVE_DIR"
    echo
    if [[ -n "$NEW_BACKUP" ]]; then
        echo "Safety backup of your previous saves:"
        echo "  $NEW_BACKUP"
        echo
    fi
    echo "Launch the game and verify your progress."
    echo
    read -rp "Press Enter to return to the menu..."
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
for cmd in cp mkdir date find sort rsync; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $cmd"
        exit 1
    fi
done

if ! SAVE_DIR="$(find_save_dir)"; then
    clear_screen
    echo "Could not find the $GAME_NAME save folder."
    echo
    echo "Looked for:"
    echo "  <Steam>/steamapps/compatdata/$GAME_APPID/pfx/drive_c/users/*/AppData/Local/Test_C/Saved/SaveGames"
    echo
    echo "If your save folder is elsewhere, run:"
    echo "  IRR_SAVE_DIR=\"/path/to/SaveGames\" \"$0\""
    echo
    exit 1
fi

while true; do
    clear_screen
    echo "================================================================"
    echo "  $GAME_NAME  -  Save Backup Tool by GoldenIcon (Linux)"
    echo "================================================================"
    echo
    echo "  Saves:   $SAVE_DIR"
    echo "  Backups: $BACKUP_ROOT"
    echo
    echo "  Tip: Close the game before backing up or restoring."
    echo
    echo "  [1] Back up save files"
    echo "  [2] Restore save files"
    echo "  [3] Exit"
    echo

    choice=""
    if ! read -rp "Select an option [1-3]: " choice; then
        exit 0
    fi

    case "$choice" in
        1) backup_menu ;;
        2) restore_menu ;;
        3) exit 0 ;;
        *)
            echo
            echo "Invalid choice. Please enter 1, 2, or 3."
            sleep 2
            ;;
    esac
done
