#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\fixtures\SwitcherIcons.ahk

T.Test("Switcher: cancelling destroys extracted icons after teardown", Switcher_CancelReleasesResources)
Switcher_CancelReleasesResources() {
    local clears, fixture, harness, icon, images, session, switcher
    clears := [], session := ""
    fixture := SwitcherIconWindow("Legend extracted cancel icon")
    harness := SwitcherIconHarness([fixture.Item()])
    switcher := LegendWindowSwitcher("^!+F9")
    switcher.Peek := {Show: (*) => "", Clear: (self, restore) => clears.Push({Restore: restore,
        Session: Legend.Session, Closed: session.Closed, Hook: session.Hook,
        Gui: session.Renderer.Gui, Critical: A_IsCritical})}
    try {
        Legend.OpenPicker(switcher.Picker)
        session := Legend.Session, icon := switcher.Picker.Items[1].Icon
        T.True(Switcher_IconAlive(icon), "executable extraction returns a real icon")
        T.Eq(switcher.Icons[fixture.Hwnd], icon)
        images := Switcher_PictureImages(session.Renderer.Gui)
        T.Eq(images.Length, 1)
        T.True(Switcher_ImageAlive(images[1]), "the real row control displays an image")
        Legend.Close(true)
        Legend.RunDeferred()
        T.Eq(switcher.Icons.Count, 0)
        T.True(!Switcher_IconAlive(icon), "cancel destroys the extracted handle")
        T.True(!Switcher_ImageAlive(images[1]), "renderer teardown releases its image copy")
        T.Eq(clears.Length, 1)
        T.True(clears[1].Restore, "cancel restores the peek")
        T.Eq(clears[1].Session, "", "cancel runs after detaching the session")
        T.True(clears[1].Closed)
        T.Eq(clears[1].Hook, "", "cancel runs after releasing capture")
        T.Eq(clears[1].Gui, "", "cancel runs after renderer teardown")
        T.Eq(clears[1].Critical, 0, "cancel runs outside Critical")
    } finally {
        harness.Close(switcher)
        fixture.Close()
    }
}

T.Test("Switcher: picking destroys extracted icons before activation", Switcher_PickReleasesResources)
Switcher_PickReleasesResources() {
    local fixture, harness, icon, order, switcher
    order := [], icon := 0
    fixture := SwitcherIconWindow("Legend extracted pick icon")
    harness := SwitcherIconHarness([fixture.Item()])
    switcher := LegendWindowSwitcher("^!+F9", {Activate: hwnd => order.Push({Hwnd: hwnd,
        IconAlive: Switcher_IconAlive(icon), Session: Legend.Session})})
    switcher.Peek := {Show: (*) => "", Clear: (self, restore) => order.Push(restore ? "restore" : "clear")}
    try {
        Legend.OpenPicker(switcher.Picker)
        icon := switcher.Picker.Items[1].Icon
        T.True(Switcher_IconAlive(icon))
        Legend.Session.Key(LegendKeyName.FromText("Enter"))
        Legend.RunDeferred()
        T.Eq(switcher.Icons.Count, 0)
        T.Eq(order.Length, 2)
        T.Eq(order[1], "clear")
        T.Eq(order[2].Hwnd, fixture.Hwnd)
        T.True(!order[2].IconAlive, "activation observes the extracted icon already destroyed")
        T.Eq(order[2].Session, "")
    } finally {
        harness.Close(switcher)
        fixture.Close()
    }
}

T.Test("Switcher: borrowed window icons survive renderer and switcher cleanup", () => Switcher_BorrowedIconSurvives("window"))
T.Test("Switcher: borrowed class icons survive renderer and switcher cleanup", () => Switcher_BorrowedIconSurvives("class"))
Switcher_BorrowedIconSurvives(kind) {
    local fixture, harness, images, switcher
    fixture := SwitcherIconWindow("Legend borrowed " kind " icon", kind)
    harness := SwitcherIconHarness([fixture.Item()])
    switcher := LegendWindowSwitcher("^!+F9")
    switcher.Peek := {Show: (*) => "", Clear: (*) => ""}
    try {
        Legend.OpenPicker(switcher.Picker)
        T.Eq(switcher.Picker.Items[1].Icon, fixture.Icon)
        T.Eq(switcher.Icons.Count, 0, "borrowed handles are not switcher-owned")
        images := Switcher_PictureImages(Legend.Session.Renderer.Gui)
        T.Eq(images.Length, 1)
        T.True(Switcher_ImageAlive(images[1]))
        Legend.Close(true)
        Legend.RunDeferred()
        T.True(!Switcher_ImageAlive(images[1]), "the renderer releases only its copy")
        T.True(Switcher_IconAlive(fixture.Icon), "the window or class still owns its icon")
    } finally {
        harness.Close(switcher)
        fixture.Close()
    }
}

T.Test("Switcher: failed source retains a real extracted icon without cancellation", Switcher_FailedSourceRetainsIcons)
Switcher_FailedSourceRetainsIcons() {
    local clears, first, harness, icon, partial, second, switcher
    clears := [], partial := ""
    first := SwitcherIconWindow("Legend partial source first")
    second := SwitcherIconWindow("Legend partial source failure")
    harness := SwitcherIconHarness([first.Item(), second.Item()])
    switcher := LegendWindowSwitcher("^!+F9", {Detail: win => (partial := Legend.Session,
        Switcher_FailedDetail(win, second.Hwnd))})
    switcher.Peek := {Show: (*) => "", Clear: (self, restore) => clears.Push(restore)}
    try {
        T.Throws(() => Legend.OpenPicker(switcher.Picker))
        Legend.RunDeferred()
        T.Eq(Legend.Session, "")
        T.True(partial.Closed)
        T.Eq(partial.Hook, "")
        T.Eq(partial.FocusTimer, "")
        T.Eq(partial.Renderer.Gui, "")
        ; Characterize the defect: partial source failure does not run cancellation.
        T.Eq(switcher.Icons.Count, 1)
        icon := switcher.Icons[first.Hwnd]
        T.True(Switcher_IconAlive(icon), "the real extracted handle remains live after failed open")
        T.Eq(clears.Length, 0)
        switcher.FreeIcons() ; Test cleanup, not production failure recovery.
        T.True(!Switcher_IconAlive(icon))
    } finally {
        harness.Close(switcher)
        first.Close()
        second.Close()
    }
}

Switcher_FailedDetail(win, failedHwnd) {
    if win.Hwnd = failedHwnd
        throw Error("fixture detail failure after the first extracted icon")
    return win.App
}

T.Test("Switcher: scope reload destroys old icons before rendering valid replacement rows", Switcher_ScopeReloadIcons)
Switcher_ScopeReloadIcons() {
    local borrowed, harness, iconCall, image, inside, newIcon, oldGui, oldIcons, oldImages, outside, seen, session, switcher
    outside := SwitcherIconWindow("Legend row outside desktop")
    inside := SwitcherIconWindow("Legend row inside desktop")
    borrowed := SwitcherIconWindow("Legend borrowed desktop row", "window")
    harness := SwitcherIconHarness([outside.Item(false), inside.Item(), borrowed.Item()])
    switcher := LegendWindowSwitcher("^!+F9", {Scopes: ["all", "desktop"], Start: 1})
    switcher.Peek := {Show: (*) => "", Clear: (*) => ""}
    seen := {}
    try {
        Legend.OpenPicker(switcher.Picker)
        session := Legend.Session, oldGui := session.Renderer.Gui.Hwnd
        oldIcons := [switcher.Icons[outside.Hwnd], switcher.Icons[inside.Hwnd]]
        oldImages := Switcher_PictureImages(session.Renderer.Gui)
        T.Eq(oldImages.Length, 3)
        T.True(Switcher_HasRenderedText(session.Renderer.Gui, outside.Title))
        iconCall := LegendWindowSwitcher.Prototype.GetOwnPropDesc("IconOf").Call
        switcher.DefineProp("IconOf", {Call: (self, hwnd) => Switcher_ObserveReloadExtraction(
            iconCall, self, hwnd, oldIcons, oldGui, oldImages, seen)})
        session.Key(LegendKeyName.FromText("l"))
        T.True(!seen.OldIconsAlive[1] && !seen.OldIconsAlive[2], "source frees both old handles before extraction")
        T.True(seen.OldGuiAlive, "the previous overlay is still present while the source reloads")
        for image in seen.OldImagesAlive
            T.True(image, "the previous rows keep valid image copies until redraw")
        T.True(!DllCall("IsWindow", "Ptr", oldGui), "redraw destroys the replaced overlay")
        for image in oldImages
            T.True(!Switcher_ImageAlive(image), "redraw releases the previous controls' image copies")
        T.Eq(switcher.Icons.Count, 1)
        newIcon := switcher.Icons[inside.Hwnd]
        T.True(Switcher_IconAlive(newIcon))
        T.True(Switcher_IconAlive(borrowed.Icon))
        T.True(!Switcher_HasRenderedText(session.Renderer.Gui, outside.Title))
        T.True(Switcher_HasRenderedText(session.Renderer.Gui, inside.Title))
        T.True(Switcher_HasRenderedText(session.Renderer.Gui, borrowed.Title))
        oldImages := Switcher_PictureImages(session.Renderer.Gui)
        T.Eq(oldImages.Length, 2)
        for image in oldImages
            T.True(Switcher_ImageAlive(image), "replacement rows display valid images")
        Legend.Close(true)
        Legend.RunDeferred()
        T.True(!Switcher_IconAlive(newIcon))
        T.True(Switcher_IconAlive(borrowed.Icon))
    } finally {
        harness.Close(switcher)
        outside.Close()
        inside.Close()
        borrowed.Close()
    }
}

Switcher_ObserveReloadExtraction(iconCall, switcher, hwnd, oldIcons, oldGui, oldImages, seen) {
    local icon, image
    if !seen.HasOwnProp("OldIconsAlive") {
        ; Observe before the next allocation: Win32 can reuse destroyed handle values.
        seen.OldIconsAlive := [], seen.OldImagesAlive := []
        for icon in oldIcons
            seen.OldIconsAlive.Push(Switcher_IconAlive(icon))
        seen.OldGuiAlive := !!DllCall("IsWindow", "Ptr", oldGui)
        for image in oldImages
            seen.OldImagesAlive.Push(Switcher_ImageAlive(image))
    }
    return iconCall(switcher, hwnd)
}
