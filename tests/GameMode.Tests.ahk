#Requires AutoHotkey v2.0

GameRules_New(overrides := "") => LegendGameRules(LegendGameMode.Config(overrides = "" ? true : overrides, Noop))

GameProc(exe, path := "", ancestors := [], fullscreen := false) =>
    {Exe: exe, Path: path, Ancestors: ancestors, Fullscreen: fullscreen}

T.Test("GameMode config: off values return empty", GameConfig_Off)
GameConfig_Off() {
    T.Eq(LegendGameMode.Config("", Noop), "")
    T.Eq(LegendGameMode.Config(false, Noop), "")
    T.Eq(LegendGameMode.Config(0, Noop), "")
}

T.Test("GameMode config: true gives the defaults", GameConfig_Defaults)
GameConfig_Defaults() {
    local config
    config := LegendGameMode.Config(true, Noop)
    T.Eq(config.ToggleKey, "^!g")
    T.Eq(config.Fullscreen, true)
    T.Eq(config.Games.Length, 0)
    T.Eq(config.NotGames.Length, 0)
    T.Eq(config.Folders.Length, 0)
    T.Eq(config.Launchers.Length, 0)
}

T.Test("GameMode config: an object overrides each property", GameConfig_Overrides)
GameConfig_Overrides() {
    local config
    config := LegendGameMode.Config({ToggleKey: "", Games: ["a.exe"], Fullscreen: false}, Noop)
    T.Eq(config.ToggleKey, "")
    T.Eq(config.Games.Length, 1)
    T.Eq(config.Games[1], "a.exe")
    T.Eq(config.Fullscreen, false)
    T.Eq(config.NotGames.Length, 0)
}

T.Test("GameMode config: bad values warn and fall back", GameConfig_BadValues)
GameConfig_BadValues() {
    local config, warnings
    warnings := []
    config := LegendGameMode.Config({Games: "x.exe", Fullscreen: "yes", Colour: 1}, (message) => warnings.Push(message))
    T.Eq(warnings.Length, 3)
    T.True(InStr(warnings[1], "GameMode") && InStr(warnings[1], "Games"), warnings[1])
    T.True(InStr(warnings[2], "GameMode") && InStr(warnings[2], "Fullscreen"), warnings[2])
    T.True(InStr(warnings[3], "GameMode") && InStr(warnings[3], "Colour"), warnings[3])
    T.Eq(config.Games.Length, 0)
    T.Eq(config.Fullscreen, true)
}

T.Test("GameMode rules: NotGames beats every other rule", GameRules_NotGames)
GameRules_NotGames() {
    local rules
    rules := GameRules_New({NotGames: ["Foo.exe"]})
    T.Eq(rules.IsGame(GameProc("foo.exe", "C:\Steam\steamapps\common\Foo\foo.exe", ["steam.exe"], true)), false)
}

T.Test("GameMode rules: Games is always a game", GameRules_Games)
GameRules_Games() {
    T.Eq(GameRules_New({Games: ["minecraft.exe"]}).IsGame(GameProc("MINECRAFT.EXE")), true)
}

T.Test("GameMode rules: a library folder is a game", GameRules_Folder)
GameRules_Folder() {
    local rules
    rules := GameRules_New()
    T.Eq(rules.IsGame(GameProc("eldenring.exe", "D:\SteamLibrary\steamapps\common\ELDEN RING\Game\eldenring.exe")), true)
    T.Eq(rules.IsGame(GameProc("app.exe", "C:\Program Files\WindowsApps\Foo\app.exe")), false)
    T.Eq(GameRules_New({Folders: ["E:\Games\"]}).IsGame(GameProc("x.exe", "e:\games\x\x.exe")), true)
}

T.Test("GameMode rules: a launcher ancestor is a game", GameRules_Launcher)
GameRules_Launcher() {
    T.Eq(GameRules_New().IsGame(GameProc("bg3.exe", "", ["BG3ModManager.exe", "explorer.exe"])), true)
    T.Eq(GameRules_New().IsGame(GameProc("wine.exe", "", ["lutris.exe"])), false)
    T.Eq(GameRules_New({Launchers: ["lutris.exe"]}).IsGame(GameProc("wine.exe", "", ["lutris.exe"])), true)
}

T.Test("GameMode rules: launcher helpers are not games", GameRules_Helpers)
GameRules_Helpers() {
    local rules
    rules := GameRules_New()
    T.Eq(rules.IsGame(GameProc("steamwebhelper.exe", "C:\Program Files (x86)\Steam\bin\cef\steamwebhelper.exe", ["steam.exe"])), false)
    T.Eq(rules.IsGame(GameProc("Vortex.exe", "", ["Vortex.exe"])), false)
}

T.Test("GameMode rules: a launcher inside a library folder is not a game", GameRules_LauncherInFolder)
GameRules_LauncherInFolder() {
    local rules
    rules := GameRules_New()
    T.Eq(rules.IsGame(GameProc("EpicGamesLauncher.exe",
        "C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe")), false)
    T.Eq(rules.IsGame(GameProc("UnrealCEFSubProcess.exe",
        "C:\Program Files (x86)\Epic Games\Launcher\Engine\Binaries\Win64\UnrealCEFSubProcess.exe", ["EpicGamesLauncher.exe"])), false)
}

T.Test("GameMode rules: fullscreen is a game unless excluded or off", GameRules_Fullscreen)
GameRules_Fullscreen() {
    local rules
    rules := GameRules_New()
    T.Eq(rules.IsGame(GameProc("indie.exe", "", [], true)), true)
    T.Eq(rules.IsGame(GameProc("chrome.exe", "", [], true)), false)
    T.Eq(rules.IsGame(GameProc("mstsc.exe", "", [], true)), false)
    T.Eq(rules.IsGame(GameProc("POWERPNT.EXE", "", [], true)), false)
    T.Eq(rules.IsGame(GameProc("indie.exe")), false)
    T.Eq(GameRules_New({Fullscreen: false}).IsGame(GameProc("indie.exe", "", [], true)), false)
}

T.Test("GameMode rules: an exclusion only affects the fullscreen rule", GameRules_ExclusionScope)
GameRules_ExclusionScope() {
    T.Eq(GameRules_New().IsGame(GameProc("chrome.exe", "C:\steamapps\common\x\chrome.exe")), true)
}

T.Test("GameMode rules: an unreadable path still uses the other rules", GameRules_NoPath)
GameRules_NoPath() {
    T.Eq(GameRules_New().IsGame(GameProc("game.exe", "", ["steam.exe"])), true)
    T.Eq(GameRules_New().IsGame(GameProc("game.exe")), false)
}

; A fake system: windows 1 game, 2 not a game, 3 unreadable, 4 this script's, 5 a window
; whose Fullscreen the test flips. Records suspend/resume/close calls.
GameSys_New(suspended := false) {
    local procs, sys
    procs := Map(1, GameProc("game.exe", "", ["steam.exe"]), 2, GameProc("notepad.exe"), 3, "", 4, "own",
        5, GameProc("indie.exe"))
    sys := {Procs: procs, Suspended: suspended, Log: []}
    sys.Describe := (self, hwnd) => self.Procs[hwnd]
    sys.IsSuspended := (self) => self.Suspended
    sys.Suspend := (self, on) => (self.Suspended := on, self.Log.Push(on ? "suspend" : "resume"))
    sys.CloseSessions := (self) => self.Log.Push("close")
    return sys
}

GameMode_New(sys) => LegendGameMode(GameRules_New(), sys)

T.Test("GameMode: focusing a game closes sessions then suspends", GameMode_FocusGame)
GameMode_FocusGame() {
    local mode, sys
    sys := GameSys_New(), mode := GameMode_New(sys)
    mode.OnForeground(1)
    T.Eq(sys.Log.Length, 2)
    T.Eq(sys.Log[1], "close")
    T.Eq(sys.Log[2], "suspend")
    T.True(mode.Owned)
}

T.Test("GameMode: leaving a game resumes", GameMode_LeaveGame)
GameMode_LeaveGame() {
    local mode, sys
    sys := GameSys_New(), mode := GameMode_New(sys)
    mode.OnForeground(1)
    mode.OnForeground(2)
    T.Eq(sys.Suspended, false)
    T.Eq(sys.Log[-1], "resume")
    T.Eq(mode.Owned, false)
}

T.Test("GameMode: a suspension Legend didn't cause survives leaving a game", GameMode_ForeignSuspend)
GameMode_ForeignSuspend() {
    local mode, sys
    sys := GameSys_New(true), mode := GameMode_New(sys)
    mode.OnForeground(1)
    mode.OnForeground(2)
    T.Eq(sys.Suspended, true)
    T.Eq(sys.Log.Length, 0)
}

T.Test("GameMode: an unreadable window counts as not a game", GameMode_Unreadable)
GameMode_Unreadable() {
    local mode, sys
    sys := GameSys_New(), mode := GameMode_New(sys)
    mode.OnForeground(1)
    mode.OnForeground(3)
    T.Eq(sys.Suspended, false)
}

T.Test("GameMode: Legend's own windows are ignored", GameMode_OwnWindows)
GameMode_OwnWindows() {
    local mode, sys
    sys := GameSys_New(), mode := GameMode_New(sys)
    mode.OnForeground(1)
    mode.OnForeground(4)
    T.Eq(sys.Suspended, true)
    T.Eq(mode.Current, 1)
}

T.Test("GameMode: toggle flips immediately", GameMode_Toggle)
GameMode_Toggle() {
    local mode, sys
    sys := GameSys_New(), mode := GameMode_New(sys)
    mode.OnForeground(2)
    mode.Toggle(2)
    T.Eq(sys.Suspended, true)
    T.True(mode.Owned)
    T.Eq(mode.Manual, 2)
    mode.Toggle(2)
    T.Eq(sys.Suspended, false)
    T.Eq(mode.Owned, false)
}

T.Test("GameMode: toggle resumes a suspension Legend didn't cause", GameMode_ToggleForeign)
GameMode_ToggleForeign() {
    local mode, sys
    sys := GameSys_New(true), mode := GameMode_New(sys)
    mode.Toggle(2)
    T.Eq(sys.Suspended, false)
}

T.Test("GameMode: a repeated foreground event keeps a manual override", GameMode_RepeatKeepsOverride)
GameMode_RepeatKeepsOverride() {
    local mode, sys
    sys := GameSys_New(), mode := GameMode_New(sys)
    mode.OnForeground(1)
    mode.Toggle(1)
    mode.OnForeground(1)
    T.Eq(sys.Suspended, false)
    T.Eq(mode.Manual, 1)
}

T.Test("GameMode: a different window clears the override", GameMode_OtherClearsOverride)
GameMode_OtherClearsOverride() {
    local mode, sys
    sys := GameSys_New(), mode := GameMode_New(sys)
    mode.OnForeground(1)
    mode.Toggle(1)
    mode.OnForeground(2)
    mode.OnForeground(1)
    T.Eq(sys.Suspended, true)
    T.Eq(mode.Manual, 0)
}

T.Test("GameMode: going fullscreen in place suspends", GameMode_FullscreenInPlace)
GameMode_FullscreenInPlace() {
    local mode, sys
    sys := GameSys_New(), mode := GameMode_New(sys)
    mode.OnForeground(5)
    T.Eq(sys.Suspended, false)
    sys.Procs[5].Fullscreen := true
    mode.OnLocationChange(5)
    T.Eq(sys.Suspended, true)
    T.True(mode.Owned)
}

T.Test("GameMode: the location check never resumes or overrides", GameMode_LocationLimits)
GameMode_LocationLimits() {
    local mode, sys
    sys := GameSys_New(), mode := GameMode_New(sys)
    sys.Procs[5].Fullscreen := true
    mode.OnForeground(5)
    sys.Procs[5].Fullscreen := false
    mode.OnLocationChange(5)
    T.Eq(sys.Suspended, true)
    mode.Toggle(5)
    sys.Procs[5].Fullscreen := true
    mode.OnLocationChange(5)
    T.Eq(sys.Suspended, false)
    mode.OnForeground(2)
    sys.Procs[1] := GameProc("other.exe", "", [], true)
    mode.OnLocationChange(1)
    T.Eq(sys.Suspended, false)
}

T.Test("GameSystem: describes a real process", GameSystem_Process)
GameSystem_Process() {
    local proc
    proc := LegendGameSystem().Process(DllCall("GetCurrentProcessId"))
    T.True(InStr(proc.Exe, "AutoHotkey") && SubStr(proc.Exe, -4) = ".exe", proc.Exe)
    T.True(SubStr(proc.Path, -StrLen(proc.Exe)) = proc.Exe, proc.Path)
    T.True(proc.Ancestors.Length >= 1, "has a parent")
}

T.Test("GameSystem: caches per process", GameSystem_Cache)
GameSystem_Cache() {
    local pid, sys
    sys := LegendGameSystem(), pid := DllCall("GetCurrentProcessId")
    T.Eq(ObjPtr(sys.Process(pid)), ObjPtr(sys.Process(pid)))
}

T.Test("GameSystem: an unknown pid is empty", GameSystem_UnknownPid)
GameSystem_UnknownPid() {
    T.Eq(LegendGameSystem().Process(0x7FFFFFF0), "")
}

T.Test("GameSystem: this script's windows are own", GameSystem_Own)
GameSystem_Own() {
    local g
    g := Gui("-Caption +ToolWindow")
    try
        T.Eq(LegendGameSystem().Describe(g.Hwnd), "own")
    finally
        g.Destroy()
}

T.Test("GameSystem: a captioned window isn't fullscreen", GameSystem_Captioned)
GameSystem_Captioned() {
    local g
    g := Gui("+ToolWindow")
    try {
        g.Show("x-3000 y-3000 w200 h200 NoActivate")
        T.Eq(LegendGameSystem().IsFullscreen(g.Hwnd), false)
    } finally
        g.Destroy()
}
