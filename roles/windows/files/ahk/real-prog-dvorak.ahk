#Requires AutoHotkey v2.0
#SingleInstance Force

#HotIf GetKeyState("Alt", "P") && !GetKeyState("Shift", "P") && !GetKeyState("Ctrl", "P")
; 1 => alt+shift+oem_plus
!SC002::Send "{Alt down}{Shift down}{vkBB}{Shift up}{Alt up}"
; 2 => alt+[
!SC003::Send "{Alt down}{vkDB}{Alt up}"
; 3 => alt+shift+[
!SC004::Send "{Alt down}{Shift down}{vkDB}{Shift up}{Alt up}"
; 4 => alt+shift+9
!SC005::Send "{Alt down}{Shift down}9{Shift up}{Alt up}"
; 5 => alt+shift+7
!SC006::Send "{Alt down}{Shift down}7{Shift up}{Alt up}"
; 6 => alt+oem_plus
!SC007::Send "{Alt down}{vkBB}{Alt up}"
; 7 => alt+shift+0
!SC008::Send "{Alt down}{Shift down}0{Shift up}{Alt up}"
; 8 => alt+shift+oem_close_brackets
!SC009::Send "{Alt down}{Shift down}{vkDD}{Shift up}{Alt up}"
; 9 => alt+oem_close_brackets
!SC00A::Send "{Alt down}{vkDD}{Alt up}"
; 0 => alt+shift+8
!SC00B::Send "{Alt down}{Shift down}8{Shift up}{Alt up}"
#HotIf

#HotIf GetKeyState("Alt", "P") && GetKeyState("Shift", "P") && !GetKeyState("Ctrl", "P")

+!SC002::Send "{Alt down}1{Alt up}"
+!SC003::Send "{Alt down}2{Alt up}"
+!SC004::Send "{Alt down}3{Alt up}"
+!SC005::Send "{Alt down}4{Alt up}"
+!SC006::Send "{Alt down}5{Alt up}"
+!SC007::Send "{Alt down}6{Alt up}"
+!SC008::Send "{Alt down}7{Alt up}"
+!SC009::Send "{Alt down}8{Alt up}"
+!SC00A::Send "{Alt down}9{Alt up}"
+!SC00B::Send "{Alt down}0{Alt up}"

#HotIf

#HotIf !GetKeyState("Alt", "P")

SC029::SendText("$")     ; base: $
+SC029::SendText("~")    ; shift: ~

SC002::SendText("+")     ; 1 -> +
+SC002::SendText("1")

SC003::SendText("[")     ; 2 -> [
+SC003::SendText("2")

SC004::SendText("{")     ; 3 -> {
+SC004::SendText("3")

SC005::SendText("(")     ; 4 -> (
+SC005::SendText("4")

SC006::SendText("&")     ; 5 -> &
+SC006::SendText("5")

SC007::SendText("=")     ; 6 -> =
+SC007::SendText("6")

SC008::SendText(")")     ; 7 -> )
+SC008::SendText("7")

SC009::SendText("}")     ; 8 -> }
+SC009::SendText("8")

SC00A::SendText("]")     ; 9 -> ]
+SC00A::SendText("9")

SC00B::SendText("*")     ; 0 -> *
+SC00B::SendText("0")

SC00C::SendText("!")  
+SC00C::SendText("%")  

SC00D::SendText("|")    
+SC00D::SendText("``")   

SC01B::SendText("@") 
+SC01B::SendText("^") 

+SC02B::SendText("#")    ; shifted

`;::'
+`;::"
'::`;
+':::
