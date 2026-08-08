#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  Marco Macro Recorder AHK version 9
;  Rebuilt from zero in v6.
; ============================================================
;  New in v9
;   * TWO MODES, and nothing else. RECORD mode records everything, always.
;     TEST mode records nothing and lets you run what you built. Pause is
;     gone, Ctrl+F12 is gone, and F12 is now just another recordable key.
;   * TESTING MODE picks its own shortcut. Open the menu, click Testing
;     mode, and the app asks you to press the shortcut you want. Press it,
;     whatever it is, and that combination is written into CapturedMacro.ahk
;     as the hotkey line, the macro is loaded, and you are in TEST mode.
;     You are no longer stuck with Alt+1.
;   * The chosen shortcut is remembered in MarcoRecorder.ini, so the next
;     time the recorder starts it is still yours.
;   * Open the menu again and it offers to switch back to Macro Recorder
;     mode, which unloads the test copy and starts recording again.
;   * The status strip shows which mode you are in, and in TEST mode it
;     shows the shortcut that runs the macro.
;
;  New in v8
;   * EVERY ACTION SAVES ITSELF. No more F12. Press a key, it is written
;     to CapturedMacro.ahk the moment you press it, followed by Sleep(333).
;     Click a mouse button, same thing.
;   * F11 and F12 are free. They are now ordinary recordable keys like any
;     other.
;   * UNDO and REDO in the menu. Wrong key? Alt+. then Undo, and the last
;     command and its Sleep are cut out of the file. Redo puts it back.
;     Undo goes back as many steps as you like. Recording anything new
;     clears the redo stack, exactly like a text editor.
;   * The menu freezes the pointer position at the moment it opens, so
;     Record mouse position records where the pointer WAS, not where it
;     ended up after you moved it to click the menu.
;   * THE TEACHING LINE. The big line in the status strip now shows what
;     you pressed, a pipe, and the exact AutoHotkey that was written:
;         Escape  |  Send("{Escape}")
;         Ctrl+Shift+S  |  Send("^+s")
;         XButton1 at 2456, 812  |  Click(2456, 812, "X1")
;     The same human label is written into CapturedMacro.ahk as a trailing
;     comment, so the recorded file reads like a lesson.
;   * The small line shows the live pointer position, the last mouse button
;     by its AutoHotkey name, and the raw vk and sc codes of the last key.
;   * Auto-repeat is ignored. Holding a key down records it once, not fifty
;     times. A key must be released before it records again.
;   * Keys and clicks aimed at the recorder's own windows are never recorded.
;
;  New in v7
;   * CapturedMacro.ahk on disk is the single source of truth. New commands
;     are inserted before the closing brace, so hand edits are never lost.
;   * Load Macro always reloads the saved file, so Alt+1 tests exactly what
;     you are looking at in the editor.
;  Keyboard capture no longer uses hundreds of Hotkey() registrations.
;  It uses a single InputHook in Visible mode, which sees every key,
;  reports it, and lets it pass straight through to the focused app.
;
;  Everything, the status strip and every popup, lives on the LEFT monitor.
;  All coordinates are SCREEN coordinates, so both monitors map correctly
;  and a recorded click on the right monitor plays back on the right monitor.
;
;  Keys
;    Ctrl / Alt / AltGr  plus  ,  or  .    open the menu
;    your own shortcut   runs the macro, but only in TEST mode
;    everything else     is recorded, in RECORD mode
; ============================================================

CoordMode("Mouse", "Screen")
InstallKeybdHook(true, true)
InstallMouseHook(true, true)

global APP_NAME    := "Marco Macro Recorder"
global APP_VERSION := "v9 (a)"
global BACK_COLOR  := "0C0C0C"
global MACRO_FILE  := A_ScriptDir "\CapturedMacro.ahk"
global INI_FILE    := A_ScriptDir "\MarcoRecorder.ini"
global PAD         := "`n`n`n`n`n`n"

global g_Mode      := "REC"      ; REC or TEST, there is no third state
global g_Capturing := false      ; true while waiting for you to press a shortcut
global g_TestHK    := "!1"       ; the hotkey written into CapturedMacro.ahk
global g_TestLabel := "Alt+1"    ; the same thing in human words
global g_MacroPID  := 0
global g_OwnHwnds  := Map()
global g_Hook      := ""
global g_Held      := Map()      ; keys currently held down, kills auto-repeat
global g_Redo      := []         ; undone commands waiting to be put back
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

MonitorUnder(x, y, &L, &T, &R, &B) {
    loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &cL, &cT, &cR, &cB)
        if (x >= cL && x < cR && y >= cT && y < cB) {
            L := cL, T := cT, R := cR, B := cB
            return
        }
    }
    LeftMonitor(&L, &T, &R, &B)
}

; ============================================================
;  Tray
; ============================================================
try TraySetIcon(A_WinDir "\System32\shell32.dll", 71)
A_IconTip := APP_NAME " " APP_VERSION "`nRECORD and TEST modes | Alt+. menu, undo, redo, testing mode"
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
global subtitleText := statusGui.AddText("x0 y0 w" winW " h" subH " Center", "recording, press anything")

statusGui.SetFont("s9 Bold cRed", "Consolas")
global modeText := statusGui.AddText("x10 y" (subH + gapY) " w100 h16", Chr(0x25CF) " REC")

statusGui.SetFont("s8 Norm cWhite", "Consolas")
global coordsText := statusGui.AddText("x115 y" (subH + gapY) " w150 h16", "X: 0   Y: 0")
global btnText    := statusGui.AddText("x270 y" (subH + gapY) " w200 h16", "btn: none")
global codeText   := statusGui.AddText("x475 y" (subH + gapY) " w150 h16", "vk-- sc---")
global cntText    := statusGui.AddText("x630 y" (subH + gapY) " w120 h16", "cmds: 0")
global hintText := statusGui.AddText("x760 y" (subH + gapY) " w280 h16", "Alt+. menu | undo, redo, testing mode")

statusGui.SetFont("s7 Norm cWhite", "Consolas")
global verText := statusGui.AddText("x1045 y" (subH + gapY) " w50 h16 Right", APP_VERSION)

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
;  Hotkeys. F11 and F12 are deliberately NOT here any more,
;  they are ordinary recordable keys now.
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

; True while one of the recorder's own windows has the focus, so that
; typing in the menu never lands in the macro.
OwnWindowActive() {
    try {
        h := WinGetID("A")
        return g_OwnHwnds.Has(h)
    }
    return false
}

OnKeyUp(ih, vk, sc) {
    g_Held.Delete(vk "-" sc)
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
    ; TEST mode records nothing at all
    if (g_Mode != "REC")
        return
    if OwnWindowActive()
        return
    ; a comma or dot with Ctrl or Alt is how the menu opens, never record it
    if ((name = "," || name = ".") && (InStr(mods, "^") || InStr(mods, "!")))
        return

    cmd   := 'Send("' SendForm(mods, name) '")'
    label := PrettyLabel(mods, name)
    Record(cmd, label)
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
    Record(cmd, clean " at " mx ", " my)
}

MouseOverOwnGui() {
    MouseGetPos(, , &hwnd)
    return g_OwnHwnds.Has(hwnd)
}

UpdateCoords() {
    MouseGetPos(&mx, &my)
    coordsText.Text := "X: " mx "   Y: " my
}

; The teaching line. Human label on the left, the exact AutoHotkey
; that went into the file on the right.
Teach(label, cmd) {
    subtitleText.Text := label "  |  " cmd
}

Flash(msg) {
    subtitleText.Text := msg
}

RefreshCount() {
    cntText.Text := "cmds: " CountCommands()
}

; ============================================================
;  Recording. Every action goes straight to disk, no buffer,
;  no confirmation key. Anything new clears the redo stack.
; ============================================================
Record(cmd, label) {
    global g_Redo
    if AppendToMacro(cmd, label) {
        g_Redo := []
        Teach(label, cmd)
        RefreshCount()
    }
}

; The file on disk is the only source of truth. New commands are inserted just
; before the closing brace, so anything you edited by hand in the meantime
; survives untouched. The recorder never rewrites the whole file any more.
AppendToMacro(cmd, label := "") {
    pad  := StrLen(cmd) < 40 ? Format("{:" (40 - StrLen(cmd)) "}", "") : "  "
    line := "    " cmd (label = "" ? "" : pad "; " label) "`n    Sleep(333)"

    if !FileExist(MACRO_FILE) {
        head := "#Requires AutoHotkey v2.0`n"
              . "#SingleInstance Force`n"
              . 'CoordMode("Mouse", "Screen")' "`n`n"
              . "; Recorded by " APP_NAME " " APP_VERSION "`n"
              . "; Alt+1 runs the macro.`n"
              . "!1::`n"
              . "{" PAD
        try {
            FileAppend(head line PAD "}`n", MACRO_FILE, "UTF-8")
            return true
        } catch as e {
            Flash("write failed " e.Message)
            return false
        }
    }

    try text := FileRead(MACRO_FILE, "UTF-8")
    catch as e {
        Flash("read failed " e.Message)
        return false
    }

    pos := InStr(text, "}", , -1)
    if !pos {
        Flash("no closing brace in the macro file")
        return false
    }

    before := RTrim(SubStr(text, 1, pos - 1), " `t`r`n")
    after  := SubStr(text, pos)
    out    := before "`n" line PAD after

    return WriteMacro(out)
}

WriteMacro(text) {
    try {
        if FileExist(MACRO_FILE)
            FileDelete(MACRO_FILE)
        FileAppend(text, MACRO_FILE, "UTF-8")
        return true
    } catch as e {
        Flash("write failed " e.Message)
        return false
    }
}

IsCommandLine(t) {
    t := Trim(t)
    return (SubStr(t, 1, 6) = "Click(" || SubStr(t, 1, 5) = "Send("
         || SubStr(t, 1, 10) = "MouseMove(")
}

; Counts the recorded lines by reading the file, not a memory buffer.
CountCommands() {
    if !FileExist(MACRO_FILE)
        return 0
    n := 0
    try {
        for ln in StrSplit(FileRead(MACRO_FILE, "UTF-8"), "`n", "`r") {
            if IsCommandLine(ln)
                n += 1
        }
    }
    return n
}

; ============================================================
;  Undo and redo. Undo cuts the last command line and the Sleep
;  that belongs to it out of the file and remembers them. Redo
;  writes them back. Hand edits elsewhere in the file are untouched.
; ============================================================
UndoLast(g := 0) {
    global g_Redo
    if g
        CloseOwn(g)
    if !FileExist(MACRO_FILE) {
        Flash("nothing to undo, no macro file")
        return
    }
    try text := FileRead(MACRO_FILE, "UTF-8")
    catch as e {
        Flash("read failed " e.Message)
        return
    }

    lines := StrSplit(text, "`n", "`r")
    last := 0
    for i, ln in lines {
        if IsCommandLine(ln)
            last := i
    }
    if !last {
        Flash("nothing to undo")
        return
    }

    ; remember the command, and its label if it carries one
    raw   := Trim(lines[last])
    cmd   := raw
    label := ""
    ; the comment is written after at least two spaces, so Send(";") is safe
    if RegExMatch(raw, "^(.*?)\s{2,};\s*(.*)$", &m) {
        cmd   := Trim(m[1])
        label := Trim(m[2])
    }
    g_Redo.Push(Map("cmd", cmd, "label", label))

    ; drop the command line, and the Sleep directly under it
    out := []
    skipSleep := true
    for i, ln in lines {
        if (i = last)
            continue
        if (i > last && skipSleep) {
            if (Trim(ln) = "")
                continue
            if (SubStr(Trim(ln), 1, 6) = "Sleep(") {
                skipSleep := false
                continue
            }
            skipSleep := false
        }
        out.Push(ln)
    }

    if WriteMacro(RTrim(Join(out, "`n"), " `t`r`n") "`n") {
        Teach("UNDO  " (label = "" ? cmd : label), cmd)
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
    item := g_Redo.Pop()
    if AppendToMacro(item["cmd"], item["label"]) {
        Teach("REDO  " (item["label"] = "" ? item["cmd"] : item["label"]), item["cmd"])
        RefreshCount()
    }
}

Join(arr, sep) {
    s := ""
    for i, v in arr
        s .= (i = 1 ? "" : sep) v
    return s
}

; ============================================================
;  Modes. RECORD records everything. TEST records nothing and runs
;  the macro under whatever shortcut you chose. There is no pause,
;  because TEST mode is what pause was really for.
; ============================================================
UpdateMode() {
    if (g_Mode = "TEST") {
        modeText.SetFont("cLime")
        modeText.Text := Chr(0x25B6) " TEST"
        hintText.Text := "TEST: " g_TestLabel " runs it"
    } else {
        modeText.SetFont("cRed")
        modeText.Text := Chr(0x25CF) " REC"
        hintText.Text := "Alt+. menu | undo, redo, testing mode"
    }
    try modeText.Redraw()
    try hintText.Redraw()
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
;  Choosing the testing shortcut. The window opens, you press the
;  combination you want, and that is that. The first non-modifier
;  key you press, together with whatever you are holding down, is
;  taken as the shortcut. Escape on its own cancels.
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
        try CloseOwn(capGui)
    capGui := Gui("+AlwaysOnTop +ToolWindow", "Choose testing shortcut")
    g_OwnHwnds[capGui.Hwnd] := true
    capGui.SetFont("s11")
    capGui.AddText("xm w380 Center"
        , "Press the shortcut you want to use to run the macro.`n`n"
        . "Anything you like. Hold your modifiers and press the key.`n"
        . "Escape on its own cancels.")
    capGui.SetFont("s16 Bold")
    capGui.AddText("xm y+14 w380 Center vcap", "waiting")
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
        try CloseOwn(capGui)
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
    hk    := mods name
    label := PrettyLabel(mods, name)
    g_Capturing := false
    if capGui {
        try CloseOwn(capGui)
        capGui := 0
    }
    g_TestHK    := hk
    g_TestLabel := label
    try {
        IniWrite(hk, INI_FILE, "test", "hotkey")
        IniWrite(label, INI_FILE, "test", "label")
    }
    if WriteTestHotkey()
        EnterTestMode()
}

; Rewrites the hotkey line at the top of CapturedMacro.ahk, and the
; comment above it, so the file always says how to run itself.
WriteTestHotkey() {
    if !FileExist(MACRO_FILE) {
        Flash("no macro file to retune")
        return false
    }
    try text := FileRead(MACRO_FILE, "UTF-8")
    catch as e {
        Flash("read failed " e.Message)
        return false
    }
    lines := StrSplit(text, "`n", "`r")
    found := false
    for i, ln in lines {
        if RegExMatch(ln, "^\s*;\s*\S.*runs the macro\.\s*$")
            lines[i] := "; " g_TestLabel " runs the macro."
        if (!found && RegExMatch(ln, "^\s*[^\s;]+::\s*$")) {
            lines[i] := g_TestHK "::"
            found := true
        }
    }
    if !found {
        Flash("no hotkey line found in the macro file")
        return false
    }
    return WriteMacro(Join(lines, "`n"))
}

; Straight into TEST mode with the shortcut already remembered.
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
    global g_Mode
    exe := FindAhkExe()
    if (exe = "" || !FileExist(exe)) {
        Flash("no AutoHotkey exe found")
        return
    }
    UnloadMacro()
    try {
        ; always the saved file, never anything held in memory
        Run('"' exe '" "' MACRO_FILE '"', A_ScriptDir, , &pid)
        global g_MacroPID := pid
        g_Mode := "TEST"
        UpdateMode()
        Teach("TEST MODE", "press " g_TestLabel " to run the macro")
    } catch as e {
        Flash("load failed " e.Message)
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
    g_OwnHwnds.Delete(g.Hwnd)
    g.Destroy()
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
    at := " at " g_MenuX ", " g_MenuY

    g := Gui("+AlwaysOnTop +ToolWindow", APP_NAME " " APP_VERSION)
    g_OwnHwnds[g.Hwnd] := true
    g.SetFont("s10")
    g.AddText("xm", g_Mode = "TEST"
        ? "TEST mode.  " g_TestLabel " runs the macro.  Nothing is being recorded."
        : "RECORD mode.  Everything you do is being recorded.")
    g.AddText("xm y+4", "Commands in CapturedMacro.ahk: " CountCommands()
                  . "   redo waiting: " g_Redo.Length)

    if (g_Mode = "REC") {
        g.SetFont("s10 Bold")
        g.AddButton("xm y+10 w320", "Undo last action").OnEvent("Click", (*) => UndoLast(g))
        g.AddButton("xm y+6 w320", "Redo last undone action").OnEvent("Click", (*) => RedoLast(g))

        g.SetFont("s10 Norm")
        g.AddText("xm y+12", "Pointer is frozen at X " g_MenuX "   Y " g_MenuY)
        g.AddButton("xm y+6 w320", "Record mouse position only" at).OnEvent("Click"
            , (*) => TakeMouse(g, "MouseMove(" g_MenuX ", " g_MenuY ")", "move to " g_MenuX ", " g_MenuY))
        g.AddButton("xm y+6 w320", "Record left click" at).OnEvent("Click"
            , (*) => TakeMouse(g, "Click(" g_MenuX ", " g_MenuY ")", "left click at " g_MenuX ", " g_MenuY))
        g.AddButton("xm y+6 w320", "Record right click" at).OnEvent("Click"
            , (*) => TakeMouse(g, 'Click(' g_MenuX ', ' g_MenuY ', "Right")', "right click at " g_MenuX ", " g_MenuY))
        g.AddButton("xm y+6 w320", "Record double click" at).OnEvent("Click"
            , (*) => TakeMouse(g, 'Click(' g_MenuX ', ' g_MenuY ', 2)', "double click at " g_MenuX ", " g_MenuY))

        g.SetFont("s10 Bold")
        g.AddButton("xm y+14 w320", "Testing mode, choose a shortcut").OnEvent("Click", (*) => AskTestShortcut(g))
        g.AddButton("xm y+6 w320", "Testing mode with " g_TestLabel).OnEvent("Click", (*) => StartTest(g))
    } else {
        g.SetFont("s10 Bold")
        g.AddButton("xm y+12 w320", "Back to Macro Recorder mode").OnEvent("Click", (*) => EnterRecordMode(g))
        g.AddButton("xm y+6 w320", "Choose a different testing shortcut").OnEvent("Click", (*) => AskTestShortcut(g))
        g.AddButton("xm y+6 w320", "Reload the macro under " g_TestLabel).OnEvent("Click", (*) => StartTest(g))
    }

    g.SetFont("s10 Norm")
    g.AddButton("xm y+14 w320", "Archive Macro with Timestamp").OnEvent("Click", (*) => Archive(g))
    g.AddButton("xm y+6 w320", "Open Macro Folder").OnEvent("Click", (*) => (CloseOwn(g), Run(A_ScriptDir)))
    g.AddButton("xm y+6 w320", "Exit").OnEvent("Click", (*) => ExitApp())
    g.OnEvent("Close", (*) => CloseOwn(g))
    g.OnEvent("Escape", (*) => CloseOwn(g))
    ShowLeft(g)
}

TakeMouse(g, cmd, label) {
    CloseOwn(g)
    Record(cmd, label)
}

Archive(g) {
    CloseOwn(g)
    if !FileExist(MACRO_FILE) {
        Flash("no macro to archive")
        return
    }
    ts := FormatTime(, "yyyy-MM-dd_HHmmss")
    try {
        FileMove(MACRO_FILE, A_ScriptDir "\CapturedMacro_" ts ".ahk")
        global g_Redo := []
        if (g_Mode = "TEST")
            EnterRecordMode()
        Flash("archived CapturedMacro_" ts ".ahk")
        RefreshCount()
    } catch as e {
        Flash("archive failed " e.Message)
    }
}

; ============================================================
;  Loading the macro for testing
; ============================================================
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

UnloadMacro() {
    global g_MacroPID
    if (g_MacroPID && ProcessExist(g_MacroPID))
        try ProcessClose(g_MacroPID)
    g_MacroPID := 0
}

CleanExit(*) {
    UnloadMacro()
    SetTimer(UpdateCoords, 0)
    try g_Hook.Stop()
    try statusGui.Destroy()
}
