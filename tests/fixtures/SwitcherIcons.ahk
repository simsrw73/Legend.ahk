#Requires AutoHotkey v2.0

; Private native classes have no AHK/default icon. All windows stay off screen.
class SwitcherIconWindow {
    __New(title, iconKind := "owned") {
        local classInfo, className, instanceOffset, windowIcon, wndProc
        static nextId := 0
        this.Hwnd := 0, this.Icon := 0, this.Atom := 0, this.Callback := 0
        this.Title := title
        this.Instance := DllCall("GetModuleHandleW", "Ptr", 0, "Ptr")
        try {
            if iconKind != "owned" {
                this.Icon := DllCall("CopyIcon", "Ptr", DllCall("LoadIconW", "Ptr", 0, "Ptr", 32512, "Ptr"), "Ptr")
                if !this.Icon
                    throw OSError(A_LastError, "CopyIcon")
            }
            windowIcon := iconKind = "window" ? this.Icon : 0
            wndProc := (hwnd, msg, wParam, lParam) => msg = 0x7F ? windowIcon
                : DllCall("DefWindowProcW", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
            this.Callback := CallbackCreate(wndProc, "Fast", 4)
            className := "LegendIconTest_" DllCall("GetCurrentProcessId") "_" (++nextId)
            classInfo := Buffer(16 + 8 * A_PtrSize, 0)
            instanceOffset := 16 + A_PtrSize
            NumPut("UInt", classInfo.Size, classInfo)
            NumPut("Ptr", this.Callback, classInfo, 8)
            NumPut("Ptr", this.Instance, classInfo, instanceOffset)
            NumPut("Ptr", StrPtr(className), classInfo, instanceOffset + 5 * A_PtrSize)
            if iconKind = "class" {
                NumPut("Ptr", this.Icon, classInfo, instanceOffset + A_PtrSize)
                NumPut("Ptr", this.Icon, classInfo, instanceOffset + 6 * A_PtrSize)
            }
            this.Atom := DllCall("RegisterClassExW", "Ptr", classInfo, "UShort")
            if !this.Atom
                throw OSError(A_LastError, "RegisterClassExW")
            this.Hwnd := DllCall("CreateWindowExW", "UInt", 0x08000000, "Ptr", this.Atom, "WStr", title,
                "UInt", 0x00CF0000, "Int", -32000, "Int", -32000, "Int", 80, "Int", 60,
                "Ptr", 0, "Ptr", 0, "Ptr", this.Instance, "Ptr", 0, "Ptr")
            if !this.Hwnd
                throw OSError(A_LastError, "CreateWindowExW")
            DllCall("ShowWindow", "Ptr", this.Hwnd, "Int", 4) ; SW_SHOWNOACTIVATE
        } catch {
            this.Close()
            throw
        }
    }

    Item(onCurrentDesktop := true) => {Hwnd: this.Hwnd, Title: this.Title, App: "icon fixture",
        Minimized: false, OnCurrentDesktop: onCurrentDesktop, DesktopId: "", Monitor: 1}

    Close() {
        if this.Hwnd
            DllCall("DestroyWindow", "Ptr", this.Hwnd), this.Hwnd := 0
        if this.Atom
            DllCall("UnregisterClassW", "Ptr", this.Atom, "Ptr", this.Instance), this.Atom := 0
        if this.Callback
            CallbackFree(this.Callback), this.Callback := 0
        if this.Icon
            DllCall("DestroyIcon", "Ptr", this.Icon), this.Icon := 0
    }
}

class SwitcherIconHarness {
    __New(items) {
        this.ListDescriptor := LegendWindows.GetOwnPropDesc("List")
        this.PlaceDescriptor := LegendOverlay.GetOwnPropDesc("Place")
        LegendWindows.DefineProp("List", {Call: (self, options := "") => items})
        LegendOverlay.DefineProp("Place", {Call: (self, overlay, theme) => overlay.Show("NA x-32000 y-32000 AutoSize")})
    }

    Close(switcher) {
        try {
            Legend.Close(false)
            Legend.RunDeferred()
            switcher.FreeIcons()
        } finally {
            LegendWindows.DefineProp("List", this.ListDescriptor)
            LegendOverlay.DefineProp("Place", this.PlaceDescriptor)
        }
    }
}

; GetIconInfo allocates GDI bitmaps even when only handle validity is needed.
Switcher_IconAlive(icon) {
    local bitmap, info, offset
    info := Buffer(A_PtrSize = 8 ? 32 : 20, 0)
    if !DllCall("GetIconInfo", "Ptr", icon, "Ptr", info)
        return false
    offset := A_PtrSize = 8 ? 16 : 12
    for bitmap in [NumGet(info, offset, "Ptr"), NumGet(info, offset + A_PtrSize, "Ptr")]
        if bitmap
            DllCall("DeleteObject", "Ptr", bitmap)
    return true
}

Switcher_PictureImages(overlay) {
    local ctrl, handle, images, imageType
    images := []
    for ctrl in overlay {
        if ctrl.Type != "Pic"
            continue
        imageType := 1 ; IMAGE_ICON
        handle := DllCall("SendMessageW", "Ptr", ctrl.Hwnd, "UInt", 0x173, "Ptr", imageType, "Ptr", 0, "Ptr")
        if !handle {
            imageType := 0 ; IMAGE_BITMAP (AHK can convert a resized icon)
            handle := DllCall("SendMessageW", "Ptr", ctrl.Hwnd, "UInt", 0x173, "Ptr", imageType, "Ptr", 0, "Ptr")
        }
        images.Push({Type: imageType, Handle: handle})
    }
    return images
}

Switcher_ImageAlive(image) {
    local bitmap
    if image.Type = 1
        return Switcher_IconAlive(image.Handle)
    bitmap := Buffer(A_PtrSize = 8 ? 32 : 24, 0)
    return !!DllCall("GetObjectW", "Ptr", image.Handle, "Int", bitmap.Size, "Ptr", bitmap)
}

Switcher_HasRenderedText(overlay, text) {
    local ctrl
    for ctrl in overlay
        if ctrl.Type = "Text" && ctrl.Text == text
            return true
    return false
}
