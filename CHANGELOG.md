# CHANGELOG

## v12
Cosmetic only.
The teaching line no longer says anything twice. A click used to read `LButton at -1614, 636 | Click(-1614, 636)` and now reads `LButton | Click(-1614, 636)`, since the code already carries the numbers.
The idle line is short: `IDLE | Ctrl+.`. The dot is on the screen rather than described in words.
The menu is grouped under small dim headings, MODE, EDIT, MOUSE, TEST, FILE, so it reads as sections instead of a wall of buttons.
Every button is built by one helper with its text aligned Left, so the symbols line up in a single column down the left edge instead of drifting with the length of each label.
Nothing overflows a button any more. The frozen pointer position is stated once in the MOUSE heading instead of repeated on four buttons, and the AutoHotkey exe in use has a line of its own in the header. Longest label is 34 characters against a 330 pixel button.

## v11
Fixed the bug that produced macro files which would not run. Pressing the quote key or the backtick key wrote them into the file unescaped, which left a string open, so AutoHotkey ran past the end of that line and reported a confusing error about an unexpected brace further down. Every string written into the macro file now goes through an escaping function that doubles quotes and escapes backticks.
No comments are written into the generated macro any more. The teaching line still shows the exact code, it just lives on screen rather than in the file, which also removes the alignment padding that made lines long and fragile.
The macro file is now edited by line rather than by character position, so no arithmetic remains that could weld two lines together. New steps go in above the last line that is a closing brace on its own. Every write is read back and validated, and the previous contents restored if it does not come back intact.
Three modes instead of two, starting in IDLE. Nothing is captured and nothing is loaded until asked. Recording begins from the menu, behind a red button.
Closing the test macro is now explicit and thorough: a menu entry for it, automatic on leaving TEST mode and on exit, a polite WM_COMMAND exit first so the tray icon goes cleanly, a hard kill if it refuses, and a sweep for any stray copy still holding the file.
Menu entries carry symbols, and the menu names which AutoHotkey exe it found beside the script.

## v10
Fixed a crash that made v9 unusable. Releasing any modifier key threw "Item has no value" and put an AutoHotkey error box on screen. `Map.Delete` throws when the key is absent, and modifier keys are deliberately never entered into the held-key map that suppresses auto-repeat, so every Ctrl, Shift, Alt or Win release hit it. Guarded, along with the identical trap in the window bookkeeping where closing a window twice would have thrown.
Writes are now atomic, through a temporary file and a move, matching the macOS edition. An interrupted write can no longer leave half a macro file.

## v9
Two modes, RECORD and TEST, replacing pause. The testing shortcut is chosen by pressing it, and is written into the macro file as its hotkey line. Choice persisted between runs.

## v8
Every action saves itself, so the save key is gone and F11 and F12 became ordinary recordable keys. Undo and redo added. The menu freezes the pointer position when it opens. Teaching line added, showing the exact AutoHotkey written. Auto-repeat suppressed.

## v7
The macro file on disk became the single source of truth. New commands are inserted before the closing brace, so hand edits are never lost.

## v6
Rebuilt from zero. Keyboard capture moved to a single InputHook in Visible mode.
