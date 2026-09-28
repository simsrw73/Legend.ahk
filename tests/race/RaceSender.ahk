#Requires AutoHotkey v2.0
#NoTrayIcon
gap := A_Args.Length ? Integer(A_Args[1]) : 0
Sleep(60)
SendEvent("{F13}")
Sleep(gap)
SendEvent("{F14}")
ExitApp()
