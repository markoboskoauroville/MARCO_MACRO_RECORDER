# Marco Macro Recorder

A keyboard and mouse macro recorder for Windows, written in AutoHotkey v2. Free, MIT licensed, no installer, no dependencies beyond AutoHotkey itself.

There is a macOS port with the same design and the same workflow: [HAMMERSPOON_LUA_RECORDER](https://github.com/markoboskoauroville/HAMMERSPOON_LUA_RECORDER).

## What makes it different

Most recorders capture your timing along with your actions, which means a macro that played back correctly on a fast morning fails on a slow afternoon. This one throws your timing away and writes a fixed `Sleep(333)` between every step. Predictable beats faithful.

Everything records itself. Press a key and it is on disk before you have let go of it. There is no save key and no pause, so every key on the keyboard stays available to be recorded.

The recorded file is the only source of truth. Nothing is held in memory. You can open `CapturedMacro.ahk` in an editor mid session, change it by hand, and keep recording on top of your changes.

And it teaches. The big line in the status strip shows what you pressed, a pipe, and the exact AutoHotkey that was written:

```
Escape                 |  Send("{Escape}")
Ctrl+Shift+S           |  Send("^+s")
XButton1 at 2456, 812  |  Click(2456, 812, "X1")
```

The same human label goes into the macro file as a trailing comment, so the file reads like a lesson rather than a wall of `Send`.

## Getting started

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Download `10-Marco_Macro_Recorder_AHK_v10.ahk` and double click it.
3. A status strip appears at the bottom of your left monitor. You are recording.
4. Press `Ctrl` and `.` together to open the menu.

## Keys

| Key | Effect |
|---|---|
| `Ctrl` or `Alt` or `AltGr` plus `,` or `.` | The menu. Six bindings, all equivalent |
| your own shortcut | Runs the macro, in TEST mode only |
| everything else | Recorded, in RECORD mode |

## Two modes

**RECORD mode** records everything, always. **TEST mode** records nothing and runs what you built.

Open the menu and click Testing mode. The app asks you to press the shortcut you want. Press any combination, and that combination is written into `CapturedMacro.ahk` as its hotkey line, the macro is loaded, and you are in TEST mode. You are not tied to one fixed trigger. Escape on its own cancels.

The choice is remembered in `MarcoRecorder.ini`, so it survives a restart.

Open the menu again in TEST mode and it offers Back to Macro Recorder mode, which unloads the test copy and starts recording again. The menu shows only what belongs to the mode you are in: undo, redo and the mouse entries are RECORD mode business, because a file edited underneath a loaded test copy is a file out of sync.

## Undo and redo

In the menu. Undo cuts the last command and its `Sleep` out of the file and remembers them, redo writes them back, and recording anything new clears the redo stack, the way a text editor behaves. Anything you edited by hand elsewhere in the file survives.

## The mouse

Clicks record themselves, because at the moment you click, the pointer is already where you want it. All five buttons a four button mouse can produce are captured; the two thumb buttons arrive as `XButton1` and `XButton2`.

Recording a position without clicking is the harder problem, and the menu solves it by freezing. The menu opens from the keyboard, so at that instant the pointer has not moved. The menu grabs the coordinates right then and shows them. The four mouse entries record that frozen position, not where the pointer ended up after you walked it over to press a button.

Coordinates are screen coordinates throughout, so a click recorded on the second monitor plays back on the second monitor.

## Details worth knowing

Auto-repeat is ignored, so a held key records once and must be released before it records again. Keys and clicks aimed at the recorder's own windows are never recorded, so closing the menu with Escape does not record an Escape. Keyboard capture uses a single `InputHook` in Visible mode rather than hundreds of `Hotkey()` registrations, which is why it can see every key without stealing any.

## Where things live

Beside the script: `CapturedMacro.ahk`, the macro itself. `MarcoRecorder.ini`, your testing shortcut. `CapturedMacro_<timestamp>.ahk`, anything you archived.

## Troubleshooting

**An AutoHotkey error box appears saying "Item has no value".** You are on v9 or earlier. Download v10.

**Nothing records.** Check the status strip says `● REC` and not `▶ TEST`. TEST mode records nothing by design.

**A key does nothing when you press it.** The six menu bindings and your chosen testing shortcut are never recorded, which is deliberate.

## Licence

MIT. Use it, change it, ship it, sell it. Attribution appreciated, not required.

Marko Boško, Mantra Productions.
