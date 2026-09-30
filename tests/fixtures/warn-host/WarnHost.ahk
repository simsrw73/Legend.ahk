#Requires AutoHotkey v2.0
; A host script with globals that share short names Legend could use for locals.
; Run-Tests.ps1 validates it and fails on any #Warn output: Legend's locals must
; not trigger "local has the same name as a global" in a host under #Warn All.
#Warn All, StdOut
global a := 0, b := 0, c := 0, d := 0, e := 0, f := 0, g := 0, h := 0, i := 0, j := 0
global k := 0, l := 0, m := 0, n := 0, o := 0, p := 0, q := 0, r := 0, s := 0, t := 0
global u := 0, v := 0, w := 0, x := 0, y := 0, z := 0
global out := 0, ih := 0, id := 0, ch := 0, fn := 0, vk := 0, sc := 0
global lh := 0, th := 0, ty := 0, cx := 0, cy := 0, wx := 0, wy := 0, ww := 0, wh := 0
global bgr := 0, rgb := 0, pad := 0, app := 0
#Include %A_ScriptDir%\..\..\..\Legend.ahk
