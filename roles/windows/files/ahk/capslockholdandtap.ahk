#Requires AutoHotkey v2.0
#SingleInstance Force

SetCapsLockState("AlwaysOff")

*CapsLock:: {
    if KeyWait("CapsLock", "T0.180") {
        Send "{Esc}"
    }
    else {
        Send "{Ctrl Down}"
        KeyWait "CapsLock"
        Send "{Ctrl Up}"
    }
}

; --- Fast key repeat simulation ---
; global repeatDelay := 300   ; ms before repeat starts
; global repeatRate  := 30    ; ms between repeats (~100 Hz)
;
; ; ~*h::RepeatKey("h")
; ~*j::RepeatKey("j")
; ~*k::RepeatKey("k")
; ; ~*l::RepeatKey("l")
;
; RepeatKey(key) {
;     global repeatDelay, repeatRate
;
;     if !GetKeyState(key, "P")
;         return
;
;     Sleep repeatDelay
;
;     while GetKeyState(key, "P") {
;         Send "{" key "}"
;         Sleep repeatRate
;     }
; }



; #g:: {
;     hwnd := WinActive("A")
;     style := WinGetStyle(hwnd)
;
;     if (style & 0x00C00000) || (style & 0x00040000) {
;         WinSetStyle("-0x00C00000", hwnd)
;         WinSetStyle("-0x00040000", hwnd)
;         WinMove(, , , , hwnd)
;         TrayTip "AHK", "Border removed.", 1000
;     } else {
;         WinSetStyle("+0x00C00000", hwnd)
;         WinSetStyle("+0x00040000", hwnd)
;         WinMove(, , , , hwnd)
;         TrayTip "AHK", "Border restored.", 1000
;     }
; }
