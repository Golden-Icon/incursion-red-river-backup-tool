@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Incursion Red River - Save Backup Tool
color 0A

rem ================================================================
rem  Incursion Red River - Save Backup / Restore Tool By GoldenIcon
rem
rem  Game saves : %LOCALAPPDATA%\Test_C\Saved\SaveGames
rem  Backups    : <Documents>\IRR_BACKUP
rem
rem ================================================================

set "GAME_NAME=Incursion Red River"
set "SAVE_DIR=%LOCALAPPDATA%\Test_C\Saved\SaveGames"

rem --- Find the real Documents folder (handles OneDrive redirection) ---
set "DOCS="
for /f "usebackq delims=" %%D in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "[Environment]::GetFolderPath('MyDocuments')"`) do set "DOCS=%%D"
if not defined DOCS set "DOCS=%USERPROFILE%\Documents"
set "BACKUP_ROOT=%DOCS%\IRR_BACKUP"

goto MENU


rem ================================================================
rem  MAIN MENU
rem ================================================================
:MENU
cls
echo ================================================================
echo   %GAME_NAME%  -  Save Backup Tool by GoldenIcon
echo ================================================================
echo.
echo   Saves:   %SAVE_DIR%
echo   Backups: %BACKUP_ROOT%
echo.
echo   Tip: Close the game before backing up or restoring.
echo.
echo   [1] Back up save files
echo   [2] Restore save files
echo   [3] Exit
echo.
set "MENU_CHOICE="
set /p "MENU_CHOICE=Select an option [1-3]: "
if /i "%MENU_CHOICE%"=="1" goto BACKUP
if /i "%MENU_CHOICE%"=="2" goto RESTORE_LIST
if /i "%MENU_CHOICE%"=="3" goto END
echo.
echo Invalid choice. Please enter 1, 2, or 3.
timeout /t 2 /nobreak >nul
goto MENU


rem ================================================================
rem  BACKUP
rem ================================================================
:BACKUP
cls
echo ================================================================
echo   Back up %GAME_NAME% save files
echo ================================================================
echo.
echo IMPORTANT: Close the game before backing up.
echo.
if not exist "%SAVE_DIR%\" goto NO_SAVE_FOLDER
dir /b "%SAVE_DIR%\*.sav" >nul 2>&1
if errorlevel 1 goto NO_SAVE_FILES

call :DO_BACKUP ""
if not "!BACKUP_ERROR!"=="0" goto BACKUP_FAILED

echo Backup created successfully!
echo.
echo   Folder: !NEW_BACKUP!
echo.
echo All backups are stored in:
echo   %BACKUP_ROOT%
echo.
pause
goto MENU


rem ================================================================
rem  RESTORE - PICK A BACKUP
rem ================================================================
:RESTORE_LIST
cls
echo ================================================================
echo   Restore %GAME_NAME% save files
echo ================================================================
echo.
echo IMPORTANT: Close the game before restoring.
echo.
if not exist "%BACKUP_ROOT%\" goto NO_BACKUPS

set "BK_COUNT=0"
for /f "delims=" %%D in ('dir /b /ad /o-n "%BACKUP_ROOT%\IRR_Backup_*" 2^>nul') do (
    set /a BK_COUNT+=1
    set "BK[!BK_COUNT!]=%%D"
    echo   [!BK_COUNT!]  %%D
)
if "!BK_COUNT!"=="0" goto NO_BACKUPS

echo.
echo   [0]  Cancel / return to menu
echo.
set "BK_CHOICE="
set /p "BK_CHOICE=Select a backup to restore: "
if not defined BK_CHOICE goto BAD_CHOICE
if "!BK_CHOICE!"=="0" goto MENU

rem --- Remove spaces and leading zeros, then validate ---
set "BK_CHOICE=!BK_CHOICE: =!"
if "!BK_CHOICE!"=="0" goto MENU
for /f "delims=0123456789" %%A in ("!BK_CHOICE!") do goto BAD_CHOICE
for /f "tokens=* delims=0" %%A in ("!BK_CHOICE!") do set "BK_CHOICE=%%A"
if not defined BK_CHOICE set "BK_CHOICE=0"
set /a "BK_NUM=!BK_CHOICE!" >nul 2>&1
if !BK_NUM! LSS 1 goto BAD_CHOICE
if !BK_NUM! GTR !BK_COUNT! goto BAD_CHOICE

set "SELECTED=!BK[%BK_NUM%]!"
if not exist "%BACKUP_ROOT%\!SELECTED!\" goto BACKUP_GONE
if not exist "%BACKUP_ROOT%\!SELECTED!\*.sav" goto BACKUP_EMPTY

cls
echo ================================================================
echo   Confirm restore
echo ================================================================
echo.
echo   Selected backup: !SELECTED!
echo.
echo This will REPLACE your current save files with this backup.
echo Your current saves will be backed up automatically first.
echo.
set "CONFIRM="
set /p "CONFIRM=Type Y to continue, or N to cancel: "
if /i not "!CONFIRM!"=="Y" goto MENU

rem --- Safety backup of current saves before overwriting ---
echo.
echo Creating safety backup of current saves...
set "NEW_BACKUP="
if exist "%SAVE_DIR%\" (
    call :DO_BACKUP "PRE_RESTORE"
    if not "!BACKUP_ERROR!"=="0" (
        echo.
        echo WARNING: Could not create the safety backup.
        set "CONTINUE="
        set /p "CONTINUE=Continue with restore anyway? (Y/N): "
        if /i not "!CONTINUE!"=="Y" goto MENU
    )
)

echo.
echo Restoring files...
robocopy "%BACKUP_ROOT%\!SELECTED!" "%SAVE_DIR%" /MIR /COPY:DAT /XF backup_info.txt /R:1 /W:1 /NFL /NDL /NJH /NJS /NP >nul
set "RC=!ERRORLEVEL!"
if !RC! GEQ 8 goto RESTORE_FAILED

echo.
echo Restore complete!
echo.
echo Files restored to:
echo   %SAVE_DIR%
echo.
if defined NEW_BACKUP (
    echo Safety backup of your previous saves:
    echo   !NEW_BACKUP!
    echo.
)
echo Launch the game and verify your progress.
echo.
pause
goto MENU


rem ================================================================
rem  ERROR / INFO MESSAGES
rem ================================================================
:NO_SAVE_FOLDER
cls
echo Could not find the save folder:
echo   %SAVE_DIR%
echo.
echo Possible reasons:
echo   - %GAME_NAME% has never been run on this PC.
echo   - The game was played under a different Windows user.
echo.
echo Launch the game once, then try again.
echo.
pause
goto MENU

:NO_SAVE_FILES
cls
echo The save folder exists, but it contains no .sav files:
echo   %SAVE_DIR%
echo.
echo Start the game and create/load a character once, then try again.
echo.
pause
goto MENU

:BACKUP_FAILED
cls
echo The backup could not be created.
echo.
echo Make sure the game is closed and that you can write to:
echo   %BACKUP_ROOT%
echo.
pause
goto MENU

:NO_BACKUPS
cls
echo No backups were found in:
echo   %BACKUP_ROOT%
echo.
echo Use option 1 to create a backup first.
echo.
pause
goto MENU

:BAD_CHOICE
echo.
echo Invalid selection. Please try again.
timeout /t 2 /nobreak >nul
goto RESTORE_LIST

:BACKUP_GONE
cls
echo That backup folder no longer exists:
echo   %BACKUP_ROOT%\!SELECTED!
echo.
pause
goto RESTORE_LIST

:BACKUP_EMPTY
cls
echo That backup does not contain any .sav files:
echo   %BACKUP_ROOT%\!SELECTED!
echo.
pause
goto RESTORE_LIST

:RESTORE_FAILED
cls
echo Restore failed (Robocopy code !RC!).
echo.
if defined NEW_BACKUP (
    echo A safety backup of your previous saves is here:
    echo   !NEW_BACKUP!
    echo.
)
echo Check that the game is completely closed, then try again.
echo.
pause
goto MENU


rem ================================================================
rem  SUBROUTINE: CREATE A TIMESTAMPED BACKUP
rem  Usage: call :DO_BACKUP "optional_suffix"
rem  Sets:  NEW_BACKUP, BACKUP_ERROR
rem ================================================================
:DO_BACKUP
set "BACKUP_LABEL=%~1"
set "BACKUP_ERROR=0"
set "NEW_BACKUP="

rem --- Locale-independent timestamp ---
set "STAMP="
for /f "usebackq delims=" %%T in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'"`) do set "STAMP=%%T"
if not defined STAMP (
    set "STAMP=%DATE%_%TIME%"
    set "STAMP=!STAMP:/=-!"
    set "STAMP=!STAMP:\=-!"
    set "STAMP=!STAMP::=-!"
    set "STAMP=!STAMP:.=-!"
    set "STAMP=!STAMP: =_!"
)

if not exist "%BACKUP_ROOT%\" mkdir "%BACKUP_ROOT%" >nul 2>&1
if not exist "%BACKUP_ROOT%\" (
    set "BACKUP_ERROR=1"
    goto :eof
)

set "NEW_BACKUP=%BACKUP_ROOT%\IRR_Backup_%STAMP%"
if defined BACKUP_LABEL set "NEW_BACKUP=!NEW_BACKUP!_!BACKUP_LABEL!"
if exist "!NEW_BACKUP!\" set "NEW_BACKUP=!NEW_BACKUP!_!RANDOM!"

mkdir "!NEW_BACKUP!" >nul 2>&1
if not exist "!NEW_BACKUP!\" (
    set "BACKUP_ERROR=1"
    goto :eof
)

robocopy "%SAVE_DIR%" "!NEW_BACKUP!" /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS /NP >nul
set "RC=!ERRORLEVEL!"
if !RC! GEQ 8 (
    rd /s /q "!NEW_BACKUP!" >nul 2>&1
    set "BACKUP_ERROR=1"
    goto :eof
)

> "!NEW_BACKUP!\backup_info.txt" echo Game: %GAME_NAME%
>> "!NEW_BACKUP!\backup_info.txt" echo Backup folder: !NEW_BACKUP!
>> "!NEW_BACKUP!\backup_info.txt" echo Created: %DATE% %TIME%
>> "!NEW_BACKUP!\backup_info.txt" echo Source: %SAVE_DIR%
goto :eof


rem ================================================================
:END
endlocal
exit /b 0
