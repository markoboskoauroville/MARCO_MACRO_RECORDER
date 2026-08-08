#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  Marco Macro Recorder AHK version 12
;  Rebuilt from zero in v6.
; ============================================================
;  New in v12, all of it cosmetic
;   * The teaching line no longer says anything twice. It used to read
;     "LButton at -1614, 636 | Click(-1614, 636)". Now it reads
;     "LButton | Click(-1614, 636)". The code already carries the numbers.
;   * The idle line is short: "IDLE | Ctrl+.". The dot is on the screen
;     rather than described in words.
;   * The menu is grouped under small headings, MODE, EDIT, MOUSE, TEST,
;     FILE, so it reads as sections instead of a wall of buttons.
;   * Every button's text is left aligned, so all the symbols line up in
;     one column down the left edge instead of drifting with the text.
;   * Nothing overflows its button any more. The frozen pointer position
;     appears once, in the MOUSE heading, instead of on all four buttons,
;     and the AutoHotkey exe being used has a line of its own.
;
;  New in v11
;   * SYNTAX BUG FIXED, the one that produced macro files that would not
;     run. Pressing the double quote key wrote Send(""") and pressing the
;     backtick wrote Send("`"), both of which leave a string open, so the
;     parser ran on into the following lines and reported a confusing
;     error about an unexpected brace somewhere further down. Every string
;     written into the macro file now goes through AhkStr, which escapes
;     backticks and doubles quotes the way AutoHotkey requires.
;   * NO COMMENTS in CapturedMacro.ahk. Not one. The teaching line still
;     shows you the exact code, it just lives on the screen and not in
;     your file. That also removes the alignment padding that made the
;     old lines long and fragile.
;   * The file is edited BY LINE, never by character position. New steps
;     go in above the last line that is a closing brace on its own. After
;     every write the file is read back and checked, and if it does not
;     come back intact the previous contents are restored.
;   * THREE MODES, and it starts in the calm one. IDLE does nothing at all,
;     RECORD records, TEST runs. On startup it sits in IDLE and tells you
;     to press Ctrl and the full stop for actions. Nothing is captured and
;     nothing is loaded until you ask.
;   * CLOSE THE TEST MACRO, in the menu, and automatically whenever you
;     leave TEST mode or quit. It is asked to exit politely first so its
;     tray icon disappears cleanly, then killed if it will not go, and any
;     stray copy still holding the file is swept up as well.
;   * The menu entries carry symbols, with a red dot on Start recording.
;   * The AutoHotkey exe sitting beside the script is used for testing,
;     and the menu says which one it found.
;
;  New in v10
;   * Crash on releasing any modifier key fixed, and writes made atomic.
;
;  New in v9
;   * Two modes rather than a pause. The testing shortcut is chosen by
;     pressing it, and written into the macro file as its hotkey line.
;
;  New in v8
;   * Every action saves itself, so there is no save key and F11 and F12
;     are ordinary recordable keys. Undo and redo. The menu freezes the
;     pointer position when it opens. The teaching line.
;
;  New in v7
;   * The macro file on disk is the single source of truth.
;
;  Keys
;    Ctrl / Alt / AltGr  plus  ,  or  .    open the menu
;    your own shortcut   runs the macro, in TEST mode only
;    everything else     is recorded, in RECORD mode only
; ============================================================

CoordMode("Mouse", "Screen")
InstallKeybdHook(true, true)
InstallMouseHook(true, true)

global APP_NAME    := "Marco Macro Recorder"
global APP_VERSION := "v12 (a)"
global BACK_COLOR  := "0C0C0C"
global MACRO_FILE  := A_ScriptDir "\CapturedMacro.ahk"
global INI_FILE    := A_ScriptDir "\MarcoRecorder.ini"

global g_Mode      := "IDLE"     ; IDLE, REC or TEST
global g_Capturing := false      ; true while waiting for you to press a shortcut
global g_TestHK    := "!1"       ; the hotkey written into CapturedMacro.ahk
global g_TestLabel := "Alt+1"    ; the same thing in human words
global g_MacroPID  := 0
global g_OwnHwnds  := Map()
global g_Hook      := ""
global g_Held      := Map()      ; keys currently held down, kills auto-repeat
global g_Redo      := []         ; undone steps waiting to be put back
global g_MenuX     := 0          ; pointer position frozen when the menu opened
global g_MenuY     := 0
global capGui      := 0

; the testing shortcut survives a restart
try {
    g_TestHK    := IniRead(INI_FILE, "test", "hotkey", "!1")
    g_TestLabel := IniRead(INI_FILE, "test", "label", "Alt+1")
}

; ============================================================
;  Monitors. The left monitor is the one whose work area starts
;  furthest to the left, whatever Windows calls it.
; ============================================================
LeftMonitor(&L, &T, &R, &B) {
    best := 0
    bestL := 0
    loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &cL, &cT, &cR, &cB)
        if (best = 0 || cL < bestL) {
            best := A_Index
            bestL := cL
        }
    }
    if (best = 0)
        best := 1
    MonitorGetWorkArea(best, &L, &T, &R, &B)
}

; ============================================================
;  Tray
; ============================================================
try TraySetIcon(A_WinDir "\System32\shell32.dll", 71)
A_IconTip := APP_NAME " " APP_VERSION "`nIDLE. Ctrl and full stop opens the menu."
A_TrayMenu.Delete()
A_TrayMenu.Add(APP_NAME " " APP_VERSION, (*) => "")
A_TrayMenu.Disable(APP_NAME " " APP_VERSION)
A_TrayMenu.Add()
A_TrayMenu.Add("Menu", (*) => OpenMenu())
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Menu"

; ============================================================
;  Status strip, bottom of the left monitor
; ============================================================
LeftMonitor(&mL, &mT, &mR, &mB)

winW := 1100
subH := 42
gapY := 4
rowH := 22
winH := subH + gapY + rowH
winX := mL + Round((mR - mL - winW) / 2)
winY := mB - winH - 8

global statusGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", APP_NAME)
statusGui.BackColor := BACK_COLOR

; the teaching line: what you pressed | the AutoHotkey that was written
statusGui.SetFont("s18 Bold cWhite", "Consolas")
global subtitleText := statusGui.AddText("x0 y0 w" winW " h" subH " Center"
    , "IDLE   |   Ctrl+.")

statusGui.SetFont("s9 Bold cGray", "Consolas")
global modeText := statusGui.AddText("x10 y" (subH + gapY) " w100 h16", "IDLE")

statusGui.SetFont("s8 Norm cWhite", "Consolas")
global coordsText := statusGui.AddText("x115 y" (subH + gapY) " w150 h16", "X: 0   Y: 0")
global btnText    := statusGui.AddText("x270 y" (subH + gapY) " w200 h16", "btn: none")
global codeText   := statusGui.AddText("x475 y" (subH + gapY) " w150 h16", "vk-- sc---")
global cntText    := statusGui.AddText("x630 y" (subH + gapY) " w120 h16", "steps: 0")
global hintText   := statusGui.AddText("x760 y" (subH + gapY) " w280 h16", "Ctrl+. menu")

statusGui.SetFont("s7 Norm cWhite", "Consolas")
statusGui.AddText("x1045 y" (subH + gapY) " w50 h16 Right", APP_VERSION)

statusGui.Show("NoActivate x" winX " y" winY " w" winW " h" winH)
WinSetTransColor(BACK_COLOR, statusGui.Hwnd)
g_OwnHwnds[statusGui.Hwnd] := true

SetTimer(UpdateCoords, 60)
RefreshCount()
UpdateMode()

; ============================================================
;  Mouse capture. All five buttons a four button mouse can produce.
;  On a Kensington or Razer style mouse the two thumb buttons come
;  through as XButton1 and XButton2.
; ============================================================
for btn in ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
    try Hotkey("~" btn, OnMouseButton, "On")

; ============================================================
;  Keyboard capture, one hook for the whole keyboard
; ============================================================
StartHook()

OnExit(CleanExit)
return

; ============================================================
;  Hotkeys. F11 and F12 are deliberately NOT here, they are
;  ordinary recordable keys.
; ============================================================
^,::OpenMenu()
^.::OpenMenu()
!,::OpenMenu()
!.::OpenMenu()
<^>!,::OpenMenu()
<^>!.::OpenMenu()

; ============================================================
;  Keyboard hook
; ============================================================
StartHook() {
    global g_Hook
    g_Hook := InputHook("V I1 L0")
    g_Hook.KeyOpt("{All}", "N")
    g_Hook.OnKeyDown := OnKeyDown
    g_Hook.OnKeyUp   := OnKeyUp
    g_Hook.Start()
}

IsModifierKey(name) {
    static mods := Map("LControl",1, "RControl",1, "Control",1
                     , "LShift",1, "RShift",1, "Shift",1
                     , "LAlt",1, "RAlt",1, "Alt",1
                     , "LWin",1, "RWin",1
                     , "CapsLock",1, "NumLock",1, "ScrollLock",1)
    return mods.Has(name)
}

OwnWindowActive() {
    try {
        h := WinGetID("A")
        return g_OwnHwnds.Has(h)
    }
    return false
}

OnKeyUp(ih, vk, sc) {
    ; Map.Delete throws when the key is not there, and it very often is not:
    ; modifier keys are never added to g_Held, and any key already held down
    ; when the script started sends an up without ever sending a down.
    id := vk "-" sc
    if g_Held.Has(id)
        g_Held.Delete(id)
}

OnKeyDown(ih, vk, sc) {
    name := GetKeyName(Format("vk{:X}sc{:X}", vk, sc))
    codeText.Text := Format("vk{:02X} sc{:03X}", vk, sc)
    if (name = "" || IsModifierKey(name))
        return

    ; auto-repeat: the key is still down from last time, ignore it
    id := vk "-" sc
    if g_Held.Has(id)
        return
    g_Held[id] := true

    mods := ""
    if GetKeyState("Ctrl", "P")
        mods .= "^"
    if GetKeyState("Alt", "P")
        mods .= "!"
    if GetKeyState("Shift", "P")
        mods .= "+"
    if (GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
        mods .= "#"

    ; picking a testing shortcut beats everything else
    if g_Capturing {
        CaptureShortcut(mods, name)
        return
    }
    ; only RECORD mode records. IDLE and TEST do nothing.
    if (g_Mode != "REC")
        return
    if OwnWindowActive()
        return
    ; a comma or dot with Ctrl or Alt is how the menu opens, never record it
    if ((name = "," || name = ".") && (InStr(mods, "^") || InStr(mods, "!")))
        return

    Record("Send(" AhkStr(SendForm(mods, name)) ")", PrettyLabel(mods, name))
}

; ============================================================
;  Turning text into an AutoHotkey string literal, safely.
;
;  This is the fix for the macro files that would not run. The backtick
;  is AutoHotkey's escape character and the double quote ends a string,
;  so both have to be escaped before the text can be wrapped in quotes.
;  Pressing the " key used to produce Send(""") and pressing ` used to
;  produce Send("`"), and both of those leave the string open, which
;  made the parser run on into the following lines.
; ============================================================
AhkStr(text) {
    text := StrReplace(text, "``", "````")     ; backtick first, it escapes itself
    text := StrReplace(text, '"', '""')        ; then the quote, doubled
    return '"' text '"'
}

; Single characters go through as they are, anything with a longer name gets
; braces so Send presses the key instead of typing its name.
SendForm(mods, name) {
    if (StrLen(name) = 1)
        key := InStr("^+!#{}", name) ? "{" name "}" : name
    else
        key := "{" name "}"
    return mods key
}

PrettyLabel(mods, name) {
    l := ""
    if InStr(mods, "^")
        l .= "Ctrl+"
    if InStr(mods, "!")
        l .= "Alt+"
    if InStr(mods, "+")
        l .= "Shift+"
    if InStr(mods, "#")
        l .= "Win+"
    return l (StrLen(name) = 1 ? StrUpper(name) : name)
}

; ============================================================
;  Mouse. A click records itself, position and all, because the
;  pointer is already where you want it at the moment you click.
; ============================================================
OnMouseButton(hk, *) {
    if (g_Mode != "REC" || g_Capturing || MouseOverOwnGui() || OwnWindowActive())
        return
    clean := StrReplace(hk, "~", "")
    MouseGetPos(&mx, &my)
    switch clean {
        case "LButton":  cmd := "Click(" mx ", " my ")"
        case "RButton":  cmd := 'Click(' mx ', ' my ', "Right")'
        case "MButton":  cmd := 'Click(' mx ', ' my ', "Middle")'
        case "XButton1": cmd := 'Click(' mx ', ' my ', "X1")'
        default:         cmd := 'Click(' mx ', ' my ', "X2")'
    }
    btnText.Text := "btn: " clean
    ; the label does not repeat the coordinates, the code beside it has them
    Record(cmd, clean)
}

MouseOverOwnGui() {
    MouseGetPos(, , &hwnd)
    return g_OwnHwnds.Has(hwnd)
}

UpdateCoords() {
    MouseGetPos(&mx, &my)
    coordsText.Text := "X: " mx "   Y: " my
}

Teach(label, cmd) {
    subtitleText.Text := label "  |  " cmd
}

Flash(msg) {
    subtitleText.Text := msg
}

RefreshCount() {
    cntText.Text := "steps: " CountCommands()
}

; ============================================================
;  Recording. Every action goes straight to disk, no buffer,
;  no confirmation key. Anything new clears the redo stack.
; ============================================================
Record(cmd, label) {
    global g_Redo
    if AppendToMacro(cmd) {
        g_Redo := []
        Teach(label, cmd)
        RefreshCount()
    }
}

; ============================================================
;  The macro file. No comments are ever written into it, and it is
;  edited by line rather than by character position, so there is no
;  arithmetic that can go wrong and weld two lines together.
; ============================================================
FreshFile() {
    return "#Requires AutoHotkey v2.0`n"
         . "#SingleInstance Force`n"
         . 'CoordMode("Mouse", "Screen")' "`n"
         . "`n"
         . g_TestHK "::`n"
         . "{`n"
         . "}`n"
}

ReadMacro(&text) {
    try {
        text := FileRead(MACRO_FILE, "UTF-8")
        return true
    } catch as e {
        Flash("read failed " e.Message)
        return false
    }
}

; Splits into lines without losing empty ones.
MacroLines(text) {
    return StrSplit(text, "`n", "`r")
}

; The last line that is nothing but a closing brace. That is always the end
; of the hotkey block, whatever you have added by hand above it.
LastBraceLine(lines) {
    i := lines.Length
    while (i >= 1) {
        if (Trim(lines[i]) = "}")
            return i
        i -= 1
    }
    return 0
}

IsCommandLine(t) {
    t := Trim(t)
    return (SubStr(t, 1, 6) = "Click(" || SubStr(t, 1, 5) = "Send("
         || SubStr(t, 1, 10) = "MouseMove(")
}

CountCommands() {
    if !FileExist(MACRO_FILE)
        return 0
    n := 0
    try {
        for ln in MacroLines(FileRead(MACRO_FILE, "UTF-8")) {
            if IsCommandLine(ln)
                n += 1
        }
    }
    return n
}

; Writes one step and its Sleep immediately above the closing brace.
AppendToMacro(cmd) {
    if !FileExist(MACRO_FILE) {
        if !WriteMacro(FreshFile())
            return false
    }

    if !ReadMacro(&text)
        return false

    lines := MacroLines(text)
    close := LastBraceLine(lines)
    if !close {
        Flash("no closing brace on its own line, refusing to write")
        return false
    }

    lines.InsertAt(close, "    " cmd)
    lines.InsertAt(close + 1, "    Sleep(333)")

    return WriteMacro(JoinLines(lines), text)
}

; Write to a temporary name, move it over the real file, then read it back
; and make sure it still looks like a macro. If it does not, put the previous
; contents back. An interrupted or corrupted write can never survive.
WriteMacro(text, restoreTo := "") {
    tmp := MACRO_FILE ".tmp"
    try {
        if FileExist(tmp)
            FileDelete(tmp)
        FileAppend(text, tmp, "UTF-8")
        FileMove(tmp, MACRO_FILE, true)
    } catch as e {
        try FileDelete(tmp)
        Flash("write failed " e.Message)
        return false
    }

    ; read it back and check it survived
    check := ""
    try check := FileRead(MACRO_FILE, "UTF-8")
    if (check = "" || !LastBraceLine(MacroLines(check))) {
        Flash("the file did not come back intact, restoring the previous one")
        if (restoreTo != "") {
            try {
                if FileExist(MACRO_FILE)
                    FileDelete(MACRO_FILE)
                FileAppend(restoreTo, MACRO_FILE, "UTF-8")
            }
        }
        return false
    }
    return true
}

JoinLines(arr) {
    s := ""
    for i, v in arr
        s .= (i = 1 ? "" : "`n") v
    return s
}

; ============================================================
;  Undo and redo. Undo cuts the last step and the Sleep beneath it
;  out of the file and remembers them. Redo writes them back. There
;  are no comments to parse any more, so this is simply line work.
; ============================================================
UndoLast(g := 0) {
    global g_Redo
    if g
        CloseOwn(g)
    if !FileExist(MACRO_FILE) {
        Flash("nothing to undo, no macro file yet")
        return
    }
    if !ReadMacro(&text)
        return

    lines := MacroLines(text)
    last := 0
    for i, ln in lines {
        if IsCommandLine(ln)
            last := i
    }
    if !last {
        Flash("nothing to undo")
        return
    }

    cmd := Trim(lines[last])
    g_Redo.Push(cmd)

    ; drop the Sleep first so the earlier index stays valid
    if (lines.Length >= last + 1 && SubStr(Trim(lines[last + 1]), 1, 6) = "Sleep(")
        lines.RemoveAt(last + 1)
    lines.RemoveAt(last)

    if WriteMacro(JoinLines(lines), text) {
        Teach("UNDO", cmd)
        RefreshCount()
    }
}

RedoLast(g := 0) {
    global g_Redo
    if g
        CloseOwn(g)
    if (g_Redo.Length = 0) {
        Flash("nothing to redo")
        return
    }
    cmd := g_Redo.Pop()
    if AppendToMacro(cmd) {
        Teach("REDO", cmd)
        RefreshCount()
    }
}

; ============================================================
;  Modes. IDLE does nothing, RECORD records, TEST runs.
;  It starts in IDLE so that nothing is captured until you ask.
; ============================================================
UpdateMode() {
    if (g_Mode = "TEST") {
        modeText.SetFont("cLime")
        modeText.Text := Chr(0x25B6) " TEST"
        hintText.Text := "TEST: " g_TestLabel " runs it"
        A_IconTip := APP_NAME " " APP_VERSION "`nTEST mode. " g_TestLabel " runs the macro."
    } else if (g_Mode = "REC") {
        modeText.SetFont("cRed")
        modeText.Text := Chr(0x25CF) " REC"
        hintText.Text := "Ctrl+. menu | undo, redo"
        A_IconTip := APP_NAME " " APP_VERSION "`nRECORD mode. Everything is being recorded."
    } else {
        modeText.SetFont("cGray")
        modeText.Text := "IDLE"
        hintText.Text := "Ctrl+. menu"
        A_IconTip := APP_NAME " " APP_VERSION "`nIDLE. Ctrl and full stop opens the menu."
    }
    try modeText.Redraw()
    try hintText.Redraw()
}

EnterIdleMode(g := 0) {
    global g_Mode
    if g
        CloseOwn(g)
    UnloadMacro()
    g_Mode := "IDLE"
    UpdateMode()
    Flash("IDLE   |   Ctrl+.")
}

EnterRecordMode(g := 0) {
    global g_Mode
    if g
        CloseOwn(g)
    UnloadMacro()
    g_Mode := "REC"
    UpdateMode()
    Flash("RECORD mode, everything you do is being recorded")
}

; ============================================================
;  Closing the macro that is being tested. It is asked to exit
;  politely first, which makes its tray icon disappear cleanly,
;  then killed if it will not go. Any stray copy still holding
;  CapturedMacro.ahk is swept up as well, so nothing is left
;  sitting in memory or in the tray.
; ============================================================
UnloadMacro(announce := false) {
    global g_MacroPID
    closed := false

    if (g_MacroPID && ProcessExist(g_MacroPID)) {
        AskAhkToExit(g_MacroPID)
        if ProcessExist(g_MacroPID) {
            try ProcessClose(g_MacroPID)
            try ProcessWaitClose(g_MacroPID, 2)
        }
        closed := true
    }
    g_MacroPID := 0

    if SweepStrayMacros()
        closed := true

    if (announce)
        Flash(closed ? "test macro closed and unloaded" : "no test macro was loaded")
    return closed
}

; The polite exit. AutoHotkey scripts answer WM_COMMAND 65405 by shutting
; themselves down the same way the tray Exit item does.
AskAhkToExit(pid) {
    prev := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try {
        for hwnd in WinGetList("ahk_class AutoHotkey ahk_pid " pid) {
            try PostMessage(0x111, 65405, , , "ahk_id " hwnd)
        }
        try ProcessWaitClose(pid, 2)
    }
    DetectHiddenWindows(prev)
}

; Anything else still running CapturedMacro.ahk, from an earlier session or
; a copy started by hand, gets the same polite exit.
SweepStrayMacros() {
    found := false
    prev := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try {
        for hwnd in WinGetList("ahk_class AutoHotkey") {
            title := ""
            try title := WinGetTitle("ahk_id " hwnd)
            if (title != "" && InStr(title, MACRO_FILE)) {
                try PostMessage(0x111, 65405, , , "ahk_id " hwnd)
                found := true
            }
        }
    }
    DetectHiddenWindows(prev)
    return found
}

; ============================================================
;  Choosing the testing shortcut
; ============================================================
AskTestShortcut(g := 0) {
    global g_Capturing, capGui
    if g
        CloseOwn(g)
    if !FileExist(MACRO_FILE) {
        Flash("no macro recorded yet, nothing to test")
        return
    }
    if capGui
        CloseOwn(capGui)
    capGui := Gui("+AlwaysOnTop +ToolWindow", "Choose testing shortcut")
    g_OwnHwnds[capGui.Hwnd] := true
    capGui.SetFont("s11", "Segoe UI")
    capGui.AddText("xm w380 Center"
        , "Press the shortcut you want to use to run the macro.`n`n"
        . "Anything you like. Hold your modifiers and press the key.`n"
        . "Escape on its own cancels.")
    capGui.SetFont("s16 Bold")
    capGui.AddText("xm y+14 w380 Center", "waiting")
    capGui.SetFont("s9 Norm")
    capGui.AddText("xm y+14 w380 Center", "currently " g_TestLabel)
    capGui.OnEvent("Close", (*) => CancelCapture())
    capGui.OnEvent("Escape", (*) => CancelCapture())
    ShowLeft(capGui)
    g_Capturing := true
}

CancelCapture() {
    global g_Capturing, capGui
    g_Capturing := false
    if capGui {
        CloseOwn(capGui)
        capGui := 0
    }
    Flash("testing shortcut unchanged, still " g_TestLabel)
}

CaptureShortcut(mods, name) {
    global g_Capturing, capGui, g_TestHK, g_TestLabel
    if (name = "Escape" && mods = "") {
        CancelCapture()
        return
    }
    g_Capturing := false
    if capGui {
        CloseOwn(capGui)
        capGui := 0
    }
    g_TestHK    := mods name
    g_TestLabel := PrettyLabel(mods, name)
    try {
        IniWrite(g_TestHK, INI_FILE, "test", "hotkey")
        IniWrite(g_TestLabel, INI_FILE, "test", "label")
    }
    if WriteTestHotkey()
        EnterTestMode()
}

; Rewrites the hotkey line at the top of the macro file, by line.
WriteTestHotkey() {
    if !FileExist(MACRO_FILE) {
        Flash("no macro file to retune")
        return false
    }
    if !ReadMacro(&text)
        return false

    lines := MacroLines(text)
    found := false
    for i, ln in lines {
        if (!found && RegExMatch(ln, "^\s*[^\s;]+::\s*$")) {
            lines[i] := g_TestHK "::"
            found := true
        }
    }
    if !found {
        Flash("no hotkey line found in the macro file")
        return false
    }
    return WriteMacro(JoinLines(lines), text)
}

StartTest(g := 0) {
    if g
        CloseOwn(g)
    if !FileExist(MACRO_FILE) {
        Flash("no macro recorded yet, nothing to test")
        return
    }
    if WriteTestHotkey()
        EnterTestMode()
}

EnterTestMode() {
    global g_Mode, g_MacroPID
    exe := FindAhkExe()
    if (exe = "" || !FileExist(exe)) {
        Flash("no AutoHotkey exe found beside the script")
        return
    }
    UnloadMacro()
    try {
        Run('"' exe '" "' MACRO_FILE '"', A_ScriptDir, , &pid)
        g_MacroPID := pid
        g_Mode := "TEST"
        UpdateMode()
        Teach("TEST MODE", "press " g_TestLabel " to run the macro")
    } catch as e {
        Flash("load failed " e.Message)
    }
}

; The AutoHotkey exe sitting beside this script is preferred, so the macro
; is tested by the same build that will run it.
FindAhkExe() {
    for n in ["AutoHotkey64.exe", "AutoHotkey32.exe", "AutoHotkey.exe"
            , "AutoHotkeyU64.exe", "AutoHotkeyU32.exe", "AutoHotkeyA32.exe"
            , "v2\AutoHotkey64.exe", "v2\AutoHotkey32.exe", "v2\AutoHotkey.exe"] {
        full := A_ScriptDir "\" n
        if FileExist(full)
            return full
    }
    return A_AhkPath
}

AhkExeName() {
    p := FindAhkExe()
    SplitPath(p, &nm)
    return nm = "" ? "none found" : nm
}

; ============================================================
;  Archiving
; ============================================================
Archive(g) {
    CloseOwn(g)
    if !FileExist(MACRO_FILE) {
        Flash("no macro to archive")
        return
    }
    if (g_Mode = "TEST")
        EnterIdleMode()
    ts := FormatTime(, "yyyy-MM-dd_HHmmss")
    try {
        FileMove(MACRO_FILE, A_ScriptDir "\CapturedMacro_" ts ".ahk")
        global g_Redo := []
        Flash("archived CapturedMacro_" ts ".ahk")
        RefreshCount()
    } catch as e {
        Flash("archive failed " e.Message)
    }
}

; ============================================================
;  Popups, always on the left monitor
; ============================================================
ShowLeft(g) {
    g.Show("Hide AutoSize")
    WinGetPos(, , &w, &h, g.Hwnd)
    LeftMonitor(&L, &T, &R, &B)
    x := L + Round((R - L - w) / 2)
    y := T + Round((B - T - h) / 2)
    g.Show("x" x " y" y)
}

CloseOwn(g) {
    try {
        h := g.Hwnd
        if g_OwnHwnds.Has(h)
            g_OwnHwnds.Delete(h)
    }
    try g.Destroy()
}

; ============================================================
;  Menu. Opened from the keyboard, so the pointer has not moved yet.
;  Its position is frozen the instant the menu opens, and that frozen
;  position is what the mouse entries record, not where the pointer
;  ends up after you walk it over to click a button.
; ============================================================
OpenMenu(*) {
    global g_MenuX, g_MenuY
    MouseGetPos(&g_MenuX, &g_MenuY)

    W := 330                                  ; one width for every button
    g := Gui("+AlwaysOnTop +ToolWindow", APP_NAME " " APP_VERSION)
    g_OwnHwnds[g.Hwnd] := true

    ; ---- header, three short lines, none of which can overflow ----
    g.SetFont("s10 Bold", "Segoe UI")
    g.AddText("xm w" W, g_Mode = "TEST"
        ? "TEST mode"
        : g_Mode = "REC"
            ? "RECORD mode"
            : "IDLE")
    g.SetFont("s9 Norm")
    g.AddText("xm y+2 w" W, g_Mode = "TEST"
        ? g_TestLabel " runs the macro. Nothing is recorded."
        : g_Mode = "REC"
            ? "Everything you do is being recorded."
            : "Nothing is recorded and nothing is loaded.")
    g.AddText("xm y+2 w" W, "Steps: " CountCommands() "     Redo waiting: " g_Redo.Length)
    g.AddText("xm y+2 w" W, "Testing with: " AhkExeName())

    ; ---- MODE ----
    Section(g, W, "MODE")
    if (g_Mode = "REC")
        Btn(g, W, Chr(0x23F9), "Stop recording, back to idle", (*) => EnterIdleMode(g), true)
    else if (g_Mode = "TEST")
        Btn(g, W, Chr(0x23CF), "Close the test macro and unload it", (*) => CloseTest(g), true)
    else
        Btn(g, W, Chr(0x1F534), "Start recording", (*) => EnterRecordMode(g), true)

    ; ---- EDIT ----
    if (g_Mode != "TEST") {
        Section(g, W, "EDIT")
        Btn(g, W, Chr(0x21A9), "Undo last action", (*) => UndoLast(g))
        Btn(g, W, Chr(0x21AA), "Redo last undone action", (*) => RedoLast(g))
    }

    ; ---- MOUSE. The position is stated once, in the heading. ----
    if (g_Mode = "REC") {
        Section(g, W, "MOUSE, pointer frozen at X " g_MenuX "  Y " g_MenuY)
        Btn(g, W, Chr(0x1F3AF), "Position only", (*) =>
            TakeMouse(g, "MouseMove(" g_MenuX ", " g_MenuY ")", "mouse position"))
        Btn(g, W, Chr(0x1F5B1), "Left click", (*) =>
            TakeMouse(g, "Click(" g_MenuX ", " g_MenuY ")", "left click"))
        Btn(g, W, Chr(0x1F5B1), "Right click", (*) =>
            TakeMouse(g, 'Click(' g_MenuX ', ' g_MenuY ', "Right")', "right click"))
        Btn(g, W, Chr(0x1F5B1), "Double click", (*) =>
            TakeMouse(g, 'Click(' g_MenuX ', ' g_MenuY ', 2)', "double click"))
    }

    ; ---- TEST ----
    Section(g, W, "TEST")
    if (g_Mode = "TEST") {
        Btn(g, W, Chr(0x1F504), "Reload under " g_TestLabel, (*) => StartTest(g))
        Btn(g, W, Chr(0x2699),  "Choose another shortcut", (*) => AskTestShortcut(g))
        Btn(g, W, Chr(0x1F534), "Back to recording", (*) => EnterRecordMode(g))
    } else {
        Btn(g, W, Chr(0x25B6), "Choose a shortcut and test", (*) => AskTestShortcut(g))
        Btn(g, W, Chr(0x25B6), "Test with " g_TestLabel, (*) => StartTest(g))
    }

    ; ---- FILE ----
    Section(g, W, "FILE")
    Btn(g, W, Chr(0x1F4E6), "Archive with a timestamp", (*) => Archive(g))
    Btn(g, W, Chr(0x1F4C2), "Open the macro folder", (*) => (CloseOwn(g), Run(A_ScriptDir)))
    Btn(g, W, Chr(0x1F4DD), "Edit CapturedMacro.ahk", (*) => EditMacro(g))
    Btn(g, W, Chr(0x274C),  "Exit the recorder", (*) => ExitApp())

    g.OnEvent("Close", (*) => CloseOwn(g))
    g.OnEvent("Escape", (*) => CloseOwn(g))
    ShowLeft(g)
}

; A small dim heading, so the menu reads as sections rather than a wall.
Section(g, W, title) {
    g.SetFont("s8 Bold c707070", "Segoe UI")
    g.AddText("xm y+12 w" W, title)
}

; Every button is built the same way, text aligned Left, so all the symbols
; line up in one column down the left edge instead of drifting with the text.
Btn(g, W, symbol, text, handler, bold := false) {
    g.SetFont("s10 " (bold ? "Bold" : "Norm"), "Segoe UI")
    g.AddButton("xm y+4 w" W " h30 Left", "  " symbol "   " text).OnEvent("Click", handler)
}

CloseTest(g) {
    CloseOwn(g)
    global g_Mode
    UnloadMacro(true)
    g_Mode := "IDLE"
    UpdateMode()
}

EditMacro(g) {
    CloseOwn(g)
    if !FileExist(MACRO_FILE) {
        Flash("no macro file yet")
        return
    }
    try Run('notepad.exe "' MACRO_FILE '"')
}

TakeMouse(g, cmd, label) {
    CloseOwn(g)
    Record(cmd, label)
}

CleanExit(*) {
    UnloadMacro()
    SetTimer(UpdateCoords, 0)
    try g_Hook.Stop()
    try statusGui.Destroy()
}
