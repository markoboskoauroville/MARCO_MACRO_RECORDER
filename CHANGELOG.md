# CHANGELOG

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
