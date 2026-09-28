#Requires AutoHotkey v2.0
#NoTrayIcon
#Warn All, StdOut
#Include %A_ScriptDir%\TestLib.ahk

#Include %A_ScriptDir%\..\src\KeyName.ahk
#Include %A_ScriptDir%\KeyName.Tests.ahk
#Include %A_ScriptDir%\..\src\PageFile.ahk
#Include %A_ScriptDir%\PageFile.Tests.ahk
#Include %A_ScriptDir%\..\src\Registry.ahk
#Include %A_ScriptDir%\Registry.Tests.ahk

T.Finish()
