#Requires AutoHotkey v2.0

; Decides whether a process is a game. A process is {Exe, Path, Ancestors, Fullscreen}:
; Ancestors are exe names, nearest parent first; Path is "" when it can't be read.
class LegendGameRules {
    static Folders := ["\steamapps\common\", "\GOG Games\", "\GOG Galaxy\Games\", "\EA Games\",
        "\Epic Games\", "\XboxGames\"]
    static Launchers := ["steam.exe", "GalaxyClient.exe", "Battle.net.exe", "EADesktop.exe",
        "EpicGamesLauncher.exe", "Vortex.exe", "BG3ModManager.exe", "ModOrganizer.exe",
        "Playnite.DesktopApp.exe", "Playnite.FullscreenApp.exe"]
    ; Launchers' own UI and service processes: never a game by folder or ancestry.
    static Helpers := ["steamwebhelper.exe", "GalaxyClientHelper.exe", "EpicWebHelper.exe",
        "UnrealCEFSubProcess.exe", "QtWebEngineProcess.exe", "CrashReportClient.exe"]
    ; Fullscreen but not a game: browsers, video players, slideshows, remote desktops and VMs.
    static FullscreenExclusions := ["chrome.exe", "msedge.exe", "firefox.exe", "brave.exe", "vivaldi.exe",
        "opera.exe", "arc.exe", "zen.exe",
        "mpv.exe", "vlc.exe", "mpc-hc64.exe", "mpc-hc.exe", "mpc-be64.exe", "PotPlayerMini64.exe",
        "Microsoft.Media.Player.exe", "Video.UI.exe",
        "POWERPNT.EXE",
        "mstsc.exe", "msrdc.exe", "vmconnect.exe", "vmware.exe", "vmware-vmx.exe", "VirtualBoxVM.exe",
        ; Task View, the lock screen, and the frame around Store apps (Movies & TV)
        "explorer.exe", "LockApp.exe", "ApplicationFrameHost.exe"]

    __New(config) {
        local folder
        this.Games := LegendGameRules.NameSet(config.Games)
        this.NotGames := LegendGameRules.NameSet(config.NotGames)
        this.Launchers := LegendGameRules.NameSet(LegendGameRules.Launchers, config.Launchers)
        this.Helpers := LegendGameRules.NameSet(LegendGameRules.Helpers)
        this.Excluded := LegendGameRules.NameSet(LegendGameRules.FullscreenExclusions)
        this.Folders := []
        for folder in LegendGameRules.Folders
            this.Folders.Push(folder)
        for folder in config.Folders
            this.Folders.Push(folder)
        this.Fullscreen := config.Fullscreen
    }

    IsGame(proc) {
        local ancestor, folder
        if this.NotGames.Has(proc.Exe)
            return false
        if this.Games.Has(proc.Exe)
            return true
        if this.Helpers.Has(proc.Exe) || this.Launchers.Has(proc.Exe)   ; a launcher's own windows
            return false
        if proc.Path != ""
            for folder in this.Folders
                if InStr(proc.Path, folder, false)
                    return true
        ; A browser or player a launcher happened to start (a link in Steam chat) isn't a game.
        if this.Excluded.Has(proc.Exe)
            return false
        for ancestor in proc.Ancestors
            if this.Launchers.Has(ancestor)
                return true
        return this.Fullscreen && proc.Fullscreen
    }

    static NameSet(lists*) {
        local list, name, names
        names := Map(), names.CaseSense := "Off"
        for list in lists
            for name in list
                names[name] := true
        return names
    }
}

; Suspends the whole script while a game has focus (the GameMode option).
class LegendGameMode {
    static Defaults := {ToggleKey: "^!g", Games: [], NotGames: [], Folders: [], Launchers: [], Fullscreen: true}
    static Names := ["ToggleKey", "Games", "NotGames", "Folders", "Launchers", "Fullscreen"]   ; warning order

    ; The GameMode option as a config object, or "" when game mode is off.
    ; Bad values warn through warn(message) and keep their defaults.
    static Config(value, warn) {
        local config, name, item
        if value = "" || value == false || value == 0
            return ""
        config := {}
        for name, item in this.Defaults.OwnProps()
            config.%name% := IsObject(item) ? item.Clone() : item
        if Type(value) != "Object" {   ; a Map or Array has no properties to read
            if IsObject(value) || value != true
                warn("GameMode must be true or an object; using the defaults")
            return config
        }
        for name in this.Names
            if value.HasOwnProp(name) {
                item := value.%name%
                if this.Valid(name, item)
                    config.%name% := item
                else
                    warn("GameMode: " name " must be " this.Kind(name) "; using the default")
            }
        for name in value.OwnProps()
            if !this.Defaults.HasOwnProp(name)
                warn("GameMode: unknown option '" name "'; ignored")
        return config
    }

    static Valid(name, item) {
        local entry
        if name = "ToggleKey"
            return !IsObject(item)
        if name = "Fullscreen"
            return item == true || item == false
        if !(item is Array)
            return false
        for entry in item
            if IsObject(entry) || entry = ""
                return false
        return true
    }

    ; Turns game mode on: the Suspend-exempt toggle key, the hooks, and a first check.
    static Install(config, closeSessions, warn) {
        local mode, system
        system := LegendGameSystem(closeSessions)
        mode := LegendGameMode(LegendGameRules(config), system)
        if config.ToggleKey != ""
            this.RegisterToggle(config.ToggleKey, (*) => mode.Toggle(DllCall("GetForegroundWindow", "Ptr")), warn)
        system.Watch(mode)
        mode.OnForeground(DllCall("GetForegroundWindow", "Ptr"))
        return mode
    }

    ; A key Hotkey() rejects warns and falls back to the default key. A key the script
    ; already uses warns and stays the script's: Hotkey() would quietly replace it.
    static RegisterToggle(key, fn, warn, binder := "", exists := "") {
        local fallback
        binder := binder || (k, f) => (HotIf(), Hotkey(k, f, "S"))
        exists := exists || (k) => LegendGameMode.HotkeyExists(k)
        try {
            if exists(key)
                return warn("GameMode: ToggleKey '" key "' is already a hotkey in this script; set ToggleKey to another key")
            return binder(key, fn)
        } catch {
            fallback := this.Defaults.ToggleKey
            warn("GameMode: ToggleKey '" key "' is not a hotkey; using " fallback)
            if key != fallback && !exists(fallback)
                try binder(fallback, fn)
        }
    }

    ; Hotkey(key) with nothing else changes nothing, and throws if there's no such hotkey.
    static HotkeyExists(key) {
        HotIf()
        try {
            Hotkey(key)
            return true
        } catch TargetError
            return false
    }

    static Kind(name) => name = "ToggleKey" ? "a hotkey" : name = "Fullscreen" ? "true or false" : "a list of names"

    ; system: Describe(hwnd) → process, "" (unreadable) or "own" (this script's window);
    ; IsSuspended(); Suspend(on); CloseSessions(); WatchLocation(hwnd) / StopLocation(), so
    ; window moves are only watched while not suspended (a game's moves cost nothing).
    __New(rules, system) {
        this.Rules := rules, this.System := system
        this.Owned := false   ; Legend caused the current suspension
        this.Current := 0     ; the foreground window
        this.Manual := 0      ; window under a manual toggle; detection leaves it alone
    }

    OnForeground(hwnd) {
        local proc
        if hwnd == this.Manual
            return
        if (proc := this.System.Describe(hwnd)) == "own"
            return
        this.Manual := 0, this.Current := hwnd
        if this.IsGame(proc)
            this.SuspendNow()
        else if this.Owned
            this.ResumeNow()
        this.Rewatch()
    }

    ; A window that goes fullscreen without a focus change. Only ever suspends.
    OnLocationChange(hwnd) {
        if hwnd != this.Current || hwnd == this.Manual || this.System.IsSuspended()
            return
        if this.IsGame(this.System.Describe(hwnd))
            this.SuspendNow()
    }

    Toggle(hwnd) {
        if this.System.IsSuspended()
            this.ResumeNow()
        else
            this.SuspendNow()
        ; From a Legend window, the override is for the window behind it.
        if this.System.Describe(hwnd) !== "own"
            this.Current := hwnd
        this.Manual := this.Current
        this.Rewatch()
    }

    IsGame(proc) => IsObject(proc) && this.Rules.IsGame(proc)

    Rewatch() => this.System.IsSuspended() ? this.System.StopLocation() : this.System.WatchLocation(this.Current)

    SuspendNow() {
        if this.System.IsSuspended()
            return
        this.System.CloseSessions()
        this.System.Suspend(true)
        this.System.StopLocation()
        this.Owned := true
    }

    ResumeNow() {
        this.System.Suspend(false)
        this.Owned := false
    }
}

; The Win32 side of game mode: what a window's process is, whether it is fullscreen,
; foreground and location hooks, and Suspend.
class LegendGameSystem {
    __New(closeSessions := "") {
        this.Cache := Map()   ; "pid:creation time" → {Exe, Path, Ancestors}
        this.OnClose := closeSessions
        this.Mode := "", this.Callbacks := []
        this.ForegroundHook := 0, this.LocationHook := 0
    }

    IsSuspended() => A_IsSuspended
    Suspend(on) => Suspend(on)
    CloseSessions() => this.OnClose ? this.OnClose.Call() : ""

    Describe(hwnd) {
        local name, pid, proc
        try {
            if !hwnd || !DllCall("IsWindow", "Ptr", hwnd)
                return ""
            pid := 0
            DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", &pid)
            if pid == DllCall("GetCurrentProcessId")
                return "own"
            name := Buffer(512, 0)
            DllCall("GetClassNameW", "Ptr", hwnd, "Ptr", name, "Int", 256)
            if LegendWindows.Shell.Has(StrGet(name))
                return ""
            if !IsObject(proc := this.Process(pid))
                return ""
            return {Exe: proc.Exe, Path: proc.Path, Ancestors: proc.Ancestors, Fullscreen: this.IsFullscreen(hwnd)}
        } catch
            return ""
    }

    ; {Exe, Path, Ancestors} for a running process, or "" if it isn't running.
    Process(pid) {
        local child, childTime, created, entries, key, parent, parentTime, proc
        created := LegendGameSystem.CreationTime(pid)
        key := pid ":" created
        if created != "" && this.Cache.Has(key)
            return this.Cache[key]
        entries := LegendGameSystem.Snapshot()
        if !entries.Has(pid)
            return ""
        proc := {Exe: entries[pid].Exe, Path: LegendGameSystem.ImagePath(pid), Ancestors: []}
        ; Stop at a parent that has exited, or whose pid was reused by a newer process.
        child := pid, childTime := created
        loop 16 {
            parent := entries[child].Parent
            if !parent || parent == child || !entries.Has(parent)
                break
            parentTime := LegendGameSystem.CreationTime(parent)
            if parentTime != "" && childTime != "" && parentTime > childTime
                break
            proc.Ancestors.Push(entries[parent].Exe)
            child := parent, childTime := parentTime
        }
        if created != ""
            this.Cache[key] := proc
        return proc
    }

    ; No caption, and the visible frame covers the whole monitor.
    IsFullscreen(hwnd) => LegendWindows.InPhysicalPixels(() => this.IsFullscreenNow(hwnd))

    IsFullscreenNow(hwnd) {
        local bounds, info, monitor, style
        static WS_CAPTION := 0xC00000, MONITOR_DEFAULTTONEAREST := 2
        style := DllCall(A_PtrSize = 8 ? "GetWindowLongPtrW" : "GetWindowLongW", "Ptr", hwnd, "Int", -16, "Ptr")
        if (style & WS_CAPTION) == WS_CAPTION
            return false
        monitor := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", MONITOR_DEFAULTTONEAREST, "Ptr")
        info := Buffer(40, 0), NumPut("UInt", 40, info)
        if !DllCall("GetMonitorInfoW", "Ptr", monitor, "Ptr", info)
            return false
        bounds := LegendWindows.Bounds(hwnd)
        return bounds.X == NumGet(info, 4, "Int") && bounds.Y == NumGet(info, 8, "Int")
            && bounds.X + bounds.W == NumGet(info, 12, "Int") && bounds.Y + bounds.H == NumGet(info, 16, "Int")
    }

    ; Hooks foreground changes, and location changes of the foreground window's process.
    Watch(mode) {
        local foreground, location
        static EVENT_SYSTEM_FOREGROUND := 3
        this.Mode := mode
        foreground := CallbackCreate(ObjBindMethod(this, "OnForegroundEvent"), , 7)
        location := CallbackCreate(ObjBindMethod(this, "OnLocationEvent"), , 7)
        this.Callbacks := [foreground, location]
        this.ForegroundHook := DllCall("SetWinEventHook", "UInt", EVENT_SYSTEM_FOREGROUND, "UInt", EVENT_SYSTEM_FOREGROUND,
            "Ptr", 0, "Ptr", foreground, "UInt", 0, "UInt", 0, "UInt", 0, "Ptr")
        this.ForegroundTimer := () => this.Mode.OnForeground(this.PendingForeground)
        this.MoveTimer := () => this.Mode.OnLocationChange(this.PendingMove)
        this.PendingForeground := 0, this.PendingMove := 0
    }

    ; The hooks only note the window and hand off to a timer, so the work (closing a
    ; session, Suspend) runs as an ordinary thread, never inside a Critical one.
    ; Bursts collapse into one check of the latest window.
    OnForegroundEvent(hook, event, hwnd, idObject, idChild, thread, time) {
        this.PendingForeground := hwnd
        SetTimer(this.ForegroundTimer, -1)
    }

    OnLocationEvent(hook, event, hwnd, idObject, idChild, thread, time) {
        if idObject == 0 && idChild == 0 {   ; OBJID_WINDOW, the window itself
            this.PendingMove := hwnd
            SetTimer(this.MoveTimer, -1)
        }
    }

    StopLocation() {
        if this.LocationHook
            DllCall("UnhookWinEvent", "Ptr", this.LocationHook), this.LocationHook := 0
    }

    ; Watches moves of hwnd's process (a window going fullscreen without a focus change).
    WatchLocation(hwnd) {
        local pid
        static EVENT_OBJECT_LOCATIONCHANGE := 0x800B
        this.StopLocation()
        pid := 0
        DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", &pid)
        if pid && pid != DllCall("GetCurrentProcessId")
            this.LocationHook := DllCall("SetWinEventHook", "UInt", EVENT_OBJECT_LOCATIONCHANGE,
                "UInt", EVENT_OBJECT_LOCATIONCHANGE, "Ptr", 0, "Ptr", this.Callbacks[2], "UInt", pid, "UInt", 0, "UInt", 0, "Ptr")
    }

    ; pid → {Parent, Exe} for every running process.
    static Snapshot() {
        local entries, entry, snapshot
        static TH32CS_SNAPPROCESS := 2
        entries := Map()
        snapshot := DllCall("CreateToolhelp32Snapshot", "UInt", TH32CS_SNAPPROCESS, "UInt", 0, "Ptr")
        if snapshot == -1
            return entries
        try {
            ; PROCESSENTRY32W: th32ProcessID at 8; th32ParentProcessID and szExeFile follow
            ; th32DefaultHeapID, which is pointer-sized.
            entry := Buffer(A_PtrSize = 8 ? 568 : 556, 0)
            NumPut("UInt", entry.Size, entry)
            if DllCall("Process32FirstW", "Ptr", snapshot, "Ptr", entry)
                loop
                    entries[NumGet(entry, 8, "UInt")] := {Parent: NumGet(entry, A_PtrSize = 8 ? 32 : 24, "UInt"),
                        Exe: StrGet(entry.Ptr + (A_PtrSize = 8 ? 44 : 36), 260, "UTF-16")}
                until !DllCall("Process32NextW", "Ptr", snapshot, "Ptr", entry)
        } finally
            DllCall("CloseHandle", "Ptr", snapshot)
        return entries
    }

    static Open(pid) => DllCall("OpenProcess", "UInt", 0x1000, "Int", false, "UInt", pid, "Ptr")   ; QUERY_LIMITED_INFORMATION

    ; The process's creation time as a FILETIME number, or "" if it can't be read.
    static CreationTime(pid) {
        local created, ignored, process
        if !(process := this.Open(pid))
            return ""
        try {
            created := 0, ignored := 0
            if !DllCall("GetProcessTimes", "Ptr", process, "Int64*", &created, "Int64*", &ignored,
                    "Int64*", &ignored, "Int64*", &ignored)
                return ""
            return created
        } finally
            DllCall("CloseHandle", "Ptr", process)
    }

    static ImagePath(pid) {
        local path, process, size
        if !(process := this.Open(pid))
            return ""
        try {
            path := Buffer(65536, 0), size := 32768
            return DllCall("QueryFullProcessImageNameW", "Ptr", process, "UInt", 0, "Ptr", path, "UInt*", &size)
                ? StrGet(path, size, "UTF-16") : ""
        } finally
            DllCall("CloseHandle", "Ptr", process)
    }
}
